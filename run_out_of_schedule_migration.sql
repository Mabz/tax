-- Run this migration to add out-of-schedule scanning support
-- Execute this in your Supabase SQL editor or via psql

-- ========== STEP 1: ADD COLUMN TO BORDERS TABLE ==========
ALTER TABLE borders 
ADD COLUMN IF NOT EXISTS allow_out_of_schedule_scans BOOLEAN DEFAULT false;

COMMENT ON COLUMN borders.allow_out_of_schedule_scans IS 'Whether this border allows officials to scan passes outside their scheduled time slots';

-- ========== STEP 2: CREATE AUDIT_LOGS TABLE ==========
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS 'Audit trail for important system actions';
COMMENT ON COLUMN audit_logs.actor_profile_id IS 'Profile ID of the user who performed the action';
COMMENT ON COLUMN audit_logs.action IS 'Type of action performed (e.g., out_of_schedule_scan)';
COMMENT ON COLUMN audit_logs.metadata IS 'Additional context data for the action';

-- ========== STEP 3: CREATE INDEXES ==========
CREATE INDEX IF NOT EXISTS idx_borders_out_of_schedule_setting 
ON borders(id, allow_out_of_schedule_scans) 
WHERE allow_out_of_schedule_scans = true;

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_profile_id ON audit_logs(actor_profile_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_created_at ON audit_logs(action, created_at);

-- ========== STEP 4: ENABLE ROW LEVEL SECURITY ==========
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- ========== STEP 5: CREATE RLS POLICIES ==========
-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view own audit logs" ON audit_logs;
DROP POLICY IF EXISTS "System can insert audit logs" ON audit_logs;
DROP POLICY IF EXISTS "Admins can view all audit logs" ON audit_logs;

-- Create new policies
CREATE POLICY "Users can view own audit logs" ON audit_logs
    FOR SELECT USING (actor_profile_id = auth.uid());

CREATE POLICY "System can insert audit logs" ON audit_logs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can view all audit logs" ON audit_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN roles r ON pr.role_id = r.id
            WHERE pr.profile_id = auth.uid()
            AND r.name IN ('superuser', 'country_admin')
        )
    );

-- ========== STEP 6: VERIFICATION ==========
-- Check if borders column was added
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'borders' 
AND column_name = 'allow_out_of_schedule_scans';

-- Check if audit_logs table was created
SELECT 
    table_name, 
    column_name, 
    data_type 
FROM information_schema.columns 
WHERE table_name = 'audit_logs' 
ORDER BY ordinal_position;

-- Check indexes
SELECT 
    indexname, 
    tablename 
FROM pg_indexes 
WHERE tablename IN ('borders', 'audit_logs') 
AND indexname LIKE '%out_of_schedule%' OR indexname LIKE '%audit_logs%';

-- ========== SUCCESS MESSAGE ==========
SELECT 'Migration completed successfully! Out-of-schedule scanning support has been added.' AS status;