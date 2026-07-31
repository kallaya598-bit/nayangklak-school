-- Coin + Number Lottery V2 — ตรวจ installation แบบอ่านอย่างเดียว

select jsonb_pretty(jsonb_build_object(
  'settings',       (select count(*) from public.reward_assignment_settings),
  'enabled',        (select count(*) from public.reward_assignment_settings where enabled),
  'wallets',        (select count(*) from public.reward_wallets),
  'ledger_rows',    (select count(*) from public.reward_ledger),
  'sessions',       (select count(*) from public.reward_subject_sessions),
  'rounds',         (select count(*) from public.lottery_rounds_v2),
  'tickets',        (select count(*) from public.lottery_ticket_inventory),
  'purchases',      (select count(*) from public.lottery_purchases),
  'draws',          (select count(*) from public.lottery_draws_v2),
  'coupons',        (select count(*) from public.reward_coupons),
  'ranking_prizes', (select count(*) from public.reward_ranking_prizes),
  'ranking_awards', (select count(*) from public.reward_ranking_awards),
  'expired_holds',  (select count(*) from public.lottery_ticket_inventory where sold_to is null and reserved_until<=now()),
  'negative_wallets',(select count(*) from public.reward_wallets where balance<0),
  'orphan_ledger',  (select count(*) from public.reward_ledger l left join public.reward_wallets w on w.id=l.wallet_id where w.id is null),
  'duplicate_board',(select count(*) from (
    select round_id,ticket_type,number_text,copy_code,count(*)
    from public.lottery_ticket_inventory
    group by round_id,ticket_type,number_text,copy_code having count(*)>1
  ) x),
  'rpc',(
    select jsonb_object_agg(proname,true)
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and proname in (
      'reward_v2_set_assignment','reward_v2_grant','reward_v2_save_attendance',
      'reward_v2_save_ranking_prize',
      'reward_v2_teacher_dashboard','reward_v2_student_dashboard',
      'lottery_v2_create_round','lottery_v2_generate_board','lottery_v2_confirm_board',
      'lottery_v2_hold_numbers','lottery_v2_purchase_cart','lottery_v2_draw_step',
      'lottery_v2_trial_draw','lottery_v2_confirm_results','lottery_v2_trial_wheel',
      'lottery_v2_spin_wheel'
    )
  )
)) as verification;

select c.relname as table_name,c.relrowsecurity as rls_enabled,
  coalesce(string_agg(p.policyname,',' order by p.policyname),'(no direct policy)') as policies
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
left join pg_policies p on p.schemaname=n.nspname and p.tablename=c.relname
where n.nspname='public' and c.relname in (
  'reward_wallets','reward_ledger','lottery_rounds_v2','lottery_ticket_inventory',
  'lottery_purchases','lottery_draws_v2','reward_coupons'
)
group by c.relname,c.relrowsecurity order by c.relname;
