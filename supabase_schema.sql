-- ============================================================
--  HOSTEL MANAGEMENT SYSTEM — SUPABASE SQL SCHEMA
--  Paste this entire file into Supabase → SQL Editor → Run
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- EXTENSIONS
-- ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────
-- TABLE: colleges
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colleges (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  college_name  TEXT NOT NULL,
  college_code  TEXT NOT NULL UNIQUE,
  email         TEXT NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: admins (linked to Supabase Auth)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admins (
  id          UUID PRIMARY KEY,  -- matches auth.users.id
  college_id  UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  email       TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: hostels
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hostels (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  college_id  UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  block       TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: wardens
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS wardens (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  college_id     UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  hostel_id      UUID NOT NULL REFERENCES hostels(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  warden_code    TEXT NOT NULL,
  password_hash  TEXT NOT NULL,
  fcm_token      TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(college_id, warden_code)
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: students
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS students (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  college_id       UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  hostel_id        UUID NOT NULL REFERENCES hostels(id) ON DELETE SET NULL,
  register_number  TEXT NOT NULL,
  name             TEXT NOT NULL,
  phone            TEXT,
  email            TEXT,
  year             INT CHECK (year BETWEEN 1 AND 5),
  department       TEXT,
  block            TEXT,
  room_number      TEXT,
  password_hash    TEXT NOT NULL,
  fcm_token        TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(college_id, register_number)
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: complaints
-- ─────────────────────────────────────────────────────────────
CREATE TYPE complaint_category AS ENUM ('Hostel', 'Room', 'Mess');
CREATE TYPE complaint_priority AS ENUM ('Low', 'Medium', 'High', 'Emergency');
CREATE TYPE complaint_status   AS ENUM ('Pending', 'In Progress', 'Resolved', 'Rejected');

CREATE TABLE IF NOT EXISTS complaints (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  college_id   UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  hostel_id    UUID NOT NULL REFERENCES hostels(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  description  TEXT NOT NULL,
  category     complaint_category NOT NULL DEFAULT 'Hostel',
  priority     complaint_priority NOT NULL DEFAULT 'Low',
  status       complaint_status   NOT NULL DEFAULT 'Pending',
  image_url    TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: complaint_history (timeline)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS complaint_history (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  complaint_id     UUID NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
  changed_by_role  TEXT NOT NULL CHECK (changed_by_role IN ('admin','warden','student')),
  changed_by_id    UUID NOT NULL,
  old_status       complaint_status,
  new_status       complaint_status NOT NULL,
  note             TEXT,
  changed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: attendance
-- ─────────────────────────────────────────────────────────────
CREATE TYPE attendance_status AS ENUM ('Present', 'Absent');

CREATE TABLE IF NOT EXISTS attendance (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  college_id  UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  student_id  UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  hostel_id   UUID NOT NULL REFERENCES hostels(id) ON DELETE CASCADE,
  date        DATE NOT NULL,
  status      attendance_status NOT NULL DEFAULT 'Present',
  marked_by   UUID REFERENCES wardens(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(student_id, date)
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: notices
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notices (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  college_id       UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  hostel_id        UUID REFERENCES hostels(id) ON DELETE SET NULL,  -- NULL = whole college
  created_by_role  TEXT NOT NULL CHECK (created_by_role IN ('admin','warden')),
  created_by_id    UUID NOT NULL,
  title            TEXT NOT NULL,
  description      TEXT NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: outpasses
-- ─────────────────────────────────────────────────────────────
CREATE TYPE outpass_status AS ENUM ('Pending', 'Approved', 'Rejected');

CREATE TABLE IF NOT EXISTS outpasses (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  college_id   UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  hostel_id    UUID NOT NULL REFERENCES hostels(id) ON DELETE CASCADE,
  reason       TEXT NOT NULL,
  status       outpass_status NOT NULL DEFAULT 'Pending',
  out_time     TIMESTAMPTZ,
  in_time      TIMESTAMPTZ,
  approved_by  UUID REFERENCES wardens(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- TABLE: device_tokens (for FCM push notifications)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS device_tokens (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('admin','warden','student')),
  college_id  UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
  fcm_token   TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, role)
);

-- ─────────────────────────────────────────────────────────────
-- INDEXES (performance)
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_students_college    ON students(college_id);
CREATE INDEX IF NOT EXISTS idx_students_hostel     ON students(hostel_id);
CREATE INDEX IF NOT EXISTS idx_complaints_college  ON complaints(college_id);
CREATE INDEX IF NOT EXISTS idx_complaints_student  ON complaints(student_id);
CREATE INDEX IF NOT EXISTS idx_complaints_hostel   ON complaints(hostel_id);
CREATE INDEX IF NOT EXISTS idx_complaints_status   ON complaints(status);
CREATE INDEX IF NOT EXISTS idx_attendance_student  ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_date     ON attendance(date);
CREATE INDEX IF NOT EXISTS idx_attendance_hostel   ON attendance(hostel_id);
CREATE INDEX IF NOT EXISTS idx_outpasses_student   ON outpasses(student_id);
CREATE INDEX IF NOT EXISTS idx_outpasses_status    ON outpasses(status);
CREATE INDEX IF NOT EXISTS idx_notices_college     ON notices(college_id);
CREATE INDEX IF NOT EXISTS idx_notices_hostel      ON notices(hostel_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user  ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_wardens_college     ON wardens(college_id);
CREATE INDEX IF NOT EXISTS idx_wardens_hostel      ON wardens(hostel_id);

-- ─────────────────────────────────────────────────────────────
-- TRIGGERS: auto-update updated_at
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER complaints_updated_at
  BEFORE UPDATE ON complaints
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER notices_updated_at
  BEFORE UPDATE ON notices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER outpasses_updated_at
  BEFORE UPDATE ON outpasses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────────────────────
-- Enable RLS on all tables
ALTER TABLE colleges         ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins           ENABLE ROW LEVEL SECURITY;
ALTER TABLE hostels          ENABLE ROW LEVEL SECURITY;
ALTER TABLE wardens          ENABLE ROW LEVEL SECURITY;
ALTER TABLE students         ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints       ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance       ENABLE ROW LEVEL SECURITY;
ALTER TABLE notices          ENABLE ROW LEVEL SECURITY;
ALTER TABLE outpasses        ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens    ENABLE ROW LEVEL SECURITY;

-- NOTE: Since Warden & Student use custom auth (not Supabase Auth),
-- we use the service role key on the backend for those queries, or
-- use anon key with policies set to allow based on app-level logic.
-- For simplicity in development, grant anon full access (restrict in production).

-- DEVELOPMENT POLICIES (replace with stricter policies before production launch)
CREATE POLICY "Allow all for anon" ON colleges         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON admins           FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON hostels          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON wardens          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON students         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON complaints       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON complaint_history FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON attendance       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON notices          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON outpasses        FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON device_tokens    FOR ALL TO anon USING (true) WITH CHECK (true);

-- Also allow authenticated users
CREATE POLICY "Allow all for authenticated" ON colleges         FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON admins           FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON hostels          FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON wardens          FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON students         FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON complaints       FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON complaint_history FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON attendance       FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON notices          FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON outpasses        FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON device_tokens    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────
-- STORAGE BUCKET (run separately if needed via Storage UI)
-- ─────────────────────────────────────────────────────────────
-- Go to Supabase → Storage → New bucket
-- Name: complaints
-- Public: true
-- Max file size: 10485760 (10MB)
-- Allowed MIME types: image/jpeg, image/png, image/webp

-- ─────────────────────────────────────────────────────────────
-- DONE ✅
-- ─────────────────────────────────────────────────────────────
SELECT 'Schema created successfully!' AS result;
