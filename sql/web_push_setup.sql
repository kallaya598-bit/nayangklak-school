-- =======================================================
-- Web Push Setup — ระบบดูแลนักเรียน
-- รัน SQL นี้ใน Supabase SQL Editor ก่อนใช้งาน Web Push
-- =======================================================

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id         SERIAL PRIMARY KEY,
  teacher_id INTEGER REFERENCES teachers(id) ON DELETE CASCADE,
  endpoint   TEXT UNIQUE NOT NULL,
  p256dh     TEXT NOT NULL,
  auth       TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_teacher ON push_subscriptions(teacher_id);
