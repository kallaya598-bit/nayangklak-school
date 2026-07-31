-- ================================================================
-- ล็อตเตอรี่รายวิชา: ครูผู้สอน/ครูร่วมสอนสร้างและจัดการกิจกรรมเอง
-- รันซ้ำได้ ไม่ลบกิจกรรม สลาก ผู้ชนะ หรือยอดเหรียญเดิม
-- ================================================================

alter table lottery_campaigns
  add column if not exists assignment_id integer
  references teaching_assignments(id) on delete restrict;

create index if not exists idx_lottery_campaign_assignment
  on lottery_campaigns(assignment_id, created_at desc);

create or replace function reward_can_manage_assignment(
  p_teacher integer,
  p_assignment integer
) returns boolean as $$
  select exists (
    select 1
    from teaching_assignments ta
    join teachers t on t.id = p_teacher and t.active = true
    where ta.id = p_assignment
      and (
        t.role = 'admin'
        or ta.teacher_id = p_teacher
        or exists (
          select 1
          from assignment_teachers at
          where at.assignment_id = ta.id
            and at.teacher_id = p_teacher
            and at.invite_status = 'accepted'
        )
      )
  );
$$ language sql stable security definer set search_path=public,extensions;

create or replace function lottery_create_subject_campaign(
  p_token uuid,
  p_assignment_id integer,
  p_title text,
  p_description text,
  p_ticket_cost integer,
  p_max_tickets integer,
  p_opens_at timestamptz,
  p_closes_at timestamptz,
  p_prize_name text,
  p_prize_quantity integer,
  p_year integer,
  p_semester integer
) returns bigint as $$
declare
  v_teacher integer;
  v_id bigint;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  v_teacher := reward_staff_actor(p_token);

  if not reward_can_manage_assignment(v_teacher, p_assignment_id) then
    raise exception 'คุณไม่มีสิทธิ์สร้างกิจกรรมในกลุ่มเรียนนี้';
  end if;
  if nullif(trim(p_title),'') is null or nullif(trim(p_prize_name),'') is null then
    raise exception 'กรอกชื่อกิจกรรมและรางวัล';
  end if;
  if p_ticket_cost < 1 or p_max_tickets < 1 or p_prize_quantity < 1 then
    raise exception 'จำนวนเหรียญ สลาก และรางวัลต้องมากกว่า 0';
  end if;
  if p_closes_at <= p_opens_at then
    raise exception 'เวลาปิดรับต้องอยู่หลังเวลาเปิดรับ';
  end if;

  insert into lottery_campaigns(
    assignment_id,title,description,ticket_cost,max_tickets_per_student,
    opens_at,closes_at,created_by,school_year,semester
  ) values (
    p_assignment_id,trim(p_title),nullif(trim(p_description),''),
    p_ticket_cost,p_max_tickets,p_opens_at,p_closes_at,
    v_teacher,p_year,p_semester
  ) returning id into v_id;

  insert into lottery_prizes(campaign_id,prize_name,quantity)
  values(v_id,trim(p_prize_name),p_prize_quantity);

  return v_id;
end;
$$ language plpgsql security definer set search_path=public,extensions;

create or replace function lottery_set_status(
  p_token uuid,p_campaign_id bigint,p_status text
) returns text as $$
declare
  v_teacher integer;
  v_assignment integer;
  v_old text;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  v_teacher := reward_staff_actor(p_token);
  select assignment_id,status into v_assignment,v_old
  from lottery_campaigns where id=p_campaign_id for update;

  if v_old is null then raise exception 'ไม่พบกิจกรรม'; end if;
  if not reward_can_manage_assignment(v_teacher,v_assignment) then
    raise exception 'คุณไม่มีสิทธิ์จัดการกิจกรรมนี้';
  end if;
  if p_status not in ('open','locked','cancelled') then
    raise exception 'สถานะไม่ถูกต้อง';
  end if;
  if v_old='drawn' then raise exception 'กิจกรรมสุ่มรางวัลแล้ว'; end if;

  if p_status='cancelled' then
    with refunded as (
      update lottery_tickets set status='refunded'
      where campaign_id=p_campaign_id and status='active'
      returning id,student_id,coin_transaction_id
    ), tx as (
      insert into coin_transactions(
        student_id,amount,transaction_type,source_type,source_id,
        actor_teacher_id,reason,idempotency_key,reversal_of
      )
      select r.student_id,abs(ct.amount),'refund','lottery',
        p_campaign_id::text,v_teacher,'คืนเหรียญจากการยกเลิกล็อตเตอรี่',
        'lottery-refund:'||r.id,r.coin_transaction_id
      from refunded r
      join coin_transactions ct on ct.id=r.coin_transaction_id
      on conflict(idempotency_key) do nothing
      returning student_id,amount
    )
    update coin_accounts ca
    set balance=ca.balance+x.amount,
        lifetime_earned=ca.lifetime_earned+x.amount,
        updated_at=now()
    from (
      select student_id,sum(amount)::integer amount
      from tx group by student_id
    ) x
    where ca.student_id=x.student_id;
  end if;

  update lottery_campaigns
  set status=p_status,updated_at=now()
  where id=p_campaign_id;
  return p_status;
end;
$$ language plpgsql security definer set search_path=public,extensions;

create or replace function lottery_draw(
  p_token uuid,p_campaign_id bigint
) returns bigint as $$
declare
  v_teacher integer;
  v_assignment integer;
  v_status text;
  v_seed uuid;
  v_draw bigint;
  v_count integer;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  v_teacher := reward_staff_actor(p_token);
  select assignment_id,status into v_assignment,v_status
  from lottery_campaigns where id=p_campaign_id for update;

  if v_status is null then raise exception 'ไม่พบกิจกรรม'; end if;
  if not reward_can_manage_assignment(v_teacher,v_assignment) then
    raise exception 'คุณไม่มีสิทธิ์สุ่มรางวัลกิจกรรมนี้';
  end if;
  if v_status not in ('open','locked') then
    raise exception 'กิจกรรมนี้สุ่มไม่ได้';
  end if;

  select count(*) into v_count
  from lottery_tickets
  where campaign_id=p_campaign_id and status='active';
  if v_count=0 then raise exception 'ยังไม่มีสลาก'; end if;

  v_seed := gen_random_uuid();
  insert into lottery_draws(campaign_id,seed,ticket_count,drawn_by)
  values(p_campaign_id,v_seed,v_count)
  returning id into v_draw;

  with prize_slots as (
    select p.id prize_id,generate_series(1,p.quantity) slot
    from lottery_prizes p where p.campaign_id=p_campaign_id
  ), ranked_prizes as (
    select prize_id,row_number() over(order by prize_id,slot) rn
    from prize_slots
  ), ranked_tickets as (
    select id ticket_id,student_id,
      row_number() over(order by md5(v_seed::text||':'||id::text)) rn
    from lottery_tickets
    where campaign_id=p_campaign_id and status='active'
  ), inserted as (
    insert into lottery_winners(draw_id,prize_id,ticket_id,student_id)
    select v_draw,p.prize_id,t.ticket_id,t.student_id
    from ranked_prizes p
    join ranked_tickets t using(rn)
    returning ticket_id
  )
  update lottery_tickets
  set status='winner'
  where id in(select ticket_id from inserted);

  update lottery_campaigns
  set status='drawn',updated_at=now()
  where id=p_campaign_id;
  return v_draw;
end;
$$ language plpgsql security definer set search_path=public,extensions;

create or replace function lottery_buy_subject_ticket(
  p_token uuid,
  p_campaign_id bigint,
  p_quantity integer
) returns void as $$
declare
  v_student integer;
  v_assignment integer;
begin
  if not public.app_authorized() then raise exception 'unauthorized'; end if;
  v_student := reward_student_actor(p_token);

  select assignment_id into v_assignment
  from lottery_campaigns
  where id=p_campaign_id;
  if v_assignment is null then
    raise exception 'กิจกรรมนี้ไม่ได้ผูกกับกลุ่มเรียนรายวิชา';
  end if;
  if not exists (
    select 1 from enrollments e
    where e.assignment_id=v_assignment
      and e.student_id=v_student
      and e.status='active'
  ) then
    raise exception 'นักเรียนไม่ได้ลงทะเบียนในกลุ่มเรียนของกิจกรรมนี้';
  end if;

  perform lottery_buy_ticket(p_token,p_campaign_id,p_quantity);
end;
$$ language plpgsql security definer set search_path=public,extensions;

grant execute on function reward_can_manage_assignment(integer,integer) to anon,authenticated;
grant execute on function lottery_create_subject_campaign(
  uuid,integer,text,text,integer,integer,timestamptz,timestamptz,
  text,integer,integer,integer
) to anon,authenticated;
grant execute on function lottery_set_status(uuid,bigint,text) to anon,authenticated;
grant execute on function lottery_draw(uuid,bigint) to anon,authenticated;
grant execute on function lottery_buy_subject_ticket(uuid,bigint,integer) to anon,authenticated;

notify pgrst,'reload schema';
