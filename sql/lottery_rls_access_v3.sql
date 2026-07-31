-- ================================================================
-- Lottery V3: เปิด RLS policy ให้หน้าเว็บอ่านโมดูลเหรียญ/ล็อตเตอรี่ได้
-- สาเหตุเดิม: RPC บันทึกสำเร็จ แต่ REST SELECT ได้ [] เพราะไม่มี policy
-- รันซ้ำได้ และไม่ลบข้อมูลกิจกรรม/เหรียญ/สลาก
-- ================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'coin_accounts',
    'coin_transactions',
    'lottery_campaigns',
    'lottery_prizes',
    'lottery_tickets',
    'lottery_draws',
    'lottery_winners'
  ]
  loop
    if to_regclass('public.' || t) is null then
      raise exception 'ไม่พบตาราง public.% กรุณารันโมดูลเหรียญ/ล็อตเตอรี่ก่อน', t;
    end if;

    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists app_access on public.%I', t);
    execute format(
      'create policy app_access on public.%I for all using (public.app_authorized()) with check (public.app_authorized())',
      t
    );
  end loop;
end $$;

grant select on table
  coin_accounts,
  coin_transactions,
  lottery_campaigns,
  lottery_prizes,
  lottery_tickets,
  lottery_draws,
  lottery_winners
to anon,authenticated;

notify pgrst,'reload schema';

-- ตรวจผล: ต้องเห็นกิจกรรมที่สร้างไว้ ไม่ควรเป็น []
select id,title,status,assignment_id,created_by,created_at
from lottery_campaigns
order by created_at desc;
