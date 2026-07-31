// Coin + Number Lottery V2 maintenance
// เรียกวันละครั้งหลังเที่ยงคืนเวลาไทย และเรียกเพิ่มทุก 1 นาทีได้เพื่อเคลียร์ hold
// Required secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, REWARD_CRON_SECRET

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const CRON_SECRET = Deno.env.get('REWARD_CRON_SECRET')!;

function thaiDate(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Bangkok', year: 'numeric', month: '2-digit', day: '2-digit'
  }).format(new Date());
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });
  if (!CRON_SECRET || req.headers.get('x-cron-secret') !== CRON_SECRET) {
    return new Response(JSON.stringify({ ok: false, error: 'unauthorized' }), {
      status: 401, headers: { 'Content-Type': 'application/json' }
    });
  }

  try {
    const payload = await req.json().catch(() => ({})) as { date?: string };
    const runDate = /^\d{4}-\d{2}-\d{2}$/.test(payload.date || '') ? payload.date! : thaiDate();
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/reward_v2_maintenance`, {
      method: 'POST',
      headers: {
        apikey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ p_run_date: runDate })
    });
    const body = await response.text();
    return new Response(body, {
      status: response.status,
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    console.error('reward-maintenance', error instanceof Error ? error.message : String(error));
    return new Response(JSON.stringify({ ok: false, error: 'maintenance_failed' }), {
      status: 500, headers: { 'Content-Type': 'application/json' }
    });
  }
});
