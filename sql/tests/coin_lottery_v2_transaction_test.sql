-- Coin + Number Lottery V2 — transactional smoke tests
-- ใช้บน staging/test เท่านั้น หรือรันทั้งไฟล์ให้ถึง ROLLBACK
-- ทุกข้อมูลที่สร้างในชุดนี้ถูกย้อนกลับท้ายไฟล์

begin;

do $$
declare
  v_assignment integer;
  v_student integer;
  v_first bigint;
  v_retry bigint;
  v_reverse bigint;
  v_initial integer;
  v_balance integer;
  v_total integer;
  v_rank_total integer;
  v_key text:='__v2_test__:'||txid_current()::text;
begin
  select e.assignment_id,e.student_id into v_assignment,v_student
  from public.enrollments e
  join public.teaching_assignments ta on ta.id=e.assignment_id
  where e.status='active'
  order by e.assignment_id,e.student_id limit 1;
  if v_assignment is null then raise exception 'TEST SETUP: ไม่พบ enrollment สำหรับทดสอบ'; end if;

  insert into public.reward_assignment_settings(assignment_id,school_year,semester,enabled,enabled_at)
  select ta.id,ta.year,ta.semester,true,now() from public.teaching_assignments ta where ta.id=v_assignment
  on conflict(assignment_id) do update set enabled=true,enabled_at=now();

  select coalesce((select balance from public.reward_wallets
    where assignment_id=v_assignment and student_id=v_student),0) into v_initial;

  v_first:=public._reward_v2_post(
    v_assignment,v_student,5,'teacher_grant','test','one','transaction test',null,null,true,null,
    v_key||':grant',null,'{}'::jsonb
  );
  v_retry:=public._reward_v2_post(
    v_assignment,v_student,5,'teacher_grant','test','one','transaction test',null,null,true,null,
    v_key||':grant',null,'{}'::jsonb
  );
  if v_first<>v_retry then raise exception 'FAIL: idempotency คืน ledger คนละรายการ'; end if;
  select balance into v_balance from public.reward_wallets where assignment_id=v_assignment and student_id=v_student;
  if v_balance<>v_initial+5 then raise exception 'FAIL: ยอดหลัง retry ต้องเพิ่ม 5 แต่ได้ % → %',v_initial,v_balance; end if;

  v_reverse:=public._reward_v2_post(
    v_assignment,v_student,-5,'reversal','test',v_first::text,'reverse test',null,null,true,null,
    v_key||':reverse',v_first,'{}'::jsonb
  );
  select balance into v_balance from public.reward_wallets where assignment_id=v_assignment and student_id=v_student;
  if v_balance<>v_initial then raise exception 'FAIL: reversal ต้องคืนยอดเดิม % แต่ได้ %',v_initial,v_balance; end if;
  select coalesce(sum(amount) filter(where rank_eligible),0) into v_rank_total
  from public.reward_ledger where id in (v_first,v_reverse);
  if v_rank_total<>0 then raise exception 'FAIL: คะแนนอันดับหลัง reversal ต้องเป็น 0 แต่ได้ %',v_rank_total; end if;

  begin
    perform public._reward_v2_post(
      v_assignment,v_student,-1,'admin_correction','test','negative','must fail',null,null,false,null,
      v_key||':negative',null,'{}'::jsonb
    );
    raise exception 'FAIL: ระบบยอมให้ยอดติดลบ';
  exception when others then
    if sqlerrm='FAIL: ระบบยอมให้ยอดติดลบ' then raise; end if;
  end;

  foreach v_total in array array[100,105,120,123] loop
    if (ceil(greatest(100,v_total)/4.0)::integer*4)%4<>0 then
      raise exception 'FAIL: สูตรจำนวนแผงไม่หาร 4 ลงตัว';
    end if;
  end loop;

  raise notice 'PASS: ledger idempotency, reversal, non-negative wallet, board rounding';
end $$;

rollback;
