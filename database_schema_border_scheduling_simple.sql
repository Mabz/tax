-- Border Officials Scheduling System Database Schema (Simplified Version)
-- This is a simplified version without complex triggers and functions for easier deployment

-- ========== SCHEDULE TEMPLATES TABLE ==========
CREATE TABLE border_schedule_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    border_id UUID NOT NULL REFERENCES borders(id) ON DELETE CASCADE,
    template_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID NOT NULL REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT template_name_not_empty 
        CHECK (LENGTH(TRIM(template_name)) > 0)
);

-- ========== SCHEDULE TIME SLOTS TABLE ==========
CREATE TABLE schedule_time_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES border_schedule_templates(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 1 AND day_of_week <= 7), -- 1=Monday, 7=Sunday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    min_officials INTEGER DEFAULT 1 CHECK (min_officials >= 1),
    max_officials INTEGER DEFAULT 3 CHECK (max_officials >= min_officials),
    is_active BOOLEAN DEFAULT true,
    
    -- Constraints
    CONSTRAINT valid_time_range CHECK (start_time != end_time),
    CONSTRAINT valid_official_range CHECK (max_officials >= min_officials)
);

-- ========== OFFICIAL SCHEDULE ASSIGNMENTS TABLE ==========
CREATE TABLE official_schedule_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    time_slot_id UUID NOT NULL REFERENCES schedule_time_slots(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    effective_from DATE NOT NULL,
    effective_to DATE, -- NULL means indefinite assignment
    assignment_type VARCHAR(50) DEFAULT 'primary' CHECK (assignment_type IN ('primary', 'backup', 'temporary')),
    created_by UUID NOT NULL REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_date_range CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

-- ========== SCHEDULE SNAPSHOTS TABLE ==========
CREATE TABLE schedule_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES border_schedule_templates(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    snapshot_data JSONB NOT NULL,
    reason VARCHAR(255) NOT NULL CHECK (reason IN (
        'schedule_change', 
        'official_reassignment', 
        'template_activation', 
        'template_deactivation', 
        'monthly_archive', 
        'manual_snapshot'
    )),
    created_by UUID NOT NULL REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========== INDEXES FOR PERFORMANCE ==========

-- Border Schedule Templates
CREATE INDEX idx_border_schedule_templates_border_id ON border_schedule_templates(border_id);
CREATE INDEX idx_border_schedule_templates_created_by ON border_schedule_templates(created_by);

-- Unique constraint: only one active template per border
CREATE UNIQUE INDEX idx_unique_active_template_per_border 
    ON border_schedule_templates(border_id) 
    WHERE is_active = true;

-- Schedule Time Slots
CREATE INDEX idx_schedule_time_slots_template_id ON schedule_time_slots(template_id);
CREATE INDEX idx_schedule_time_slots_day_time ON schedule_time_slots(template_id, day_of_week, start_time);
CREATE INDEX idx_schedule_time_slots_active ON schedule_time_slots(template_id) WHERE is_active = true;

-- Official Schedule Assignments
CREATE INDEX idx_official_schedule_assignments_time_slot ON official_schedule_assignments(time_slot_id);
CREATE INDEX idx_official_schedule_assignments_profile ON official_schedule_assignments(profile_id);
CREATE INDEX idx_official_schedule_assignments_dates ON official_schedule_assignments(effective_from, effective_to);
CREATE INDEX idx_official_schedule_assignments_active ON official_schedule_assignments(time_slot_id, profile_id, effective_from, effective_to);

-- Schedule Snapshots
CREATE INDEX idx_schedule_snapshots_template_id ON schedule_snapshots(template_id);
CREATE INDEX idx_schedule_snapshots_date ON schedule_snapshots(template_id, snapshot_date DESC);
CREATE INDEX idx_schedule_snapshots_reason ON schedule_snapshots(reason);

-- ========== ROW LEVEL SECURITY (RLS) POLICIES ==========

-- Enable RLS on all tables
ALTER TABLE border_schedule_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_time_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE official_schedule_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_snapshots ENABLE ROW LEVEL SECURITY;

-- Border Schedule Templates Policies
CREATE POLICY "Border managers can manage their border schedules" ON border_schedule_templates
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM border_manager_borders bmb 
            WHERE bmb.border_id = border_schedule_templates.border_id 
            AND bmb.profile_id = auth.uid() 
            AND bmb.is_active = true
        )
    );

CREATE POLICY "Country administrators can manage all schedules in their country" ON border_schedule_templates
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profile_roles pr
            JOIN roles r ON r.id = pr.role_id
            JOIN borders b ON b.id = border_schedule_templates.border_id
            JOIN authorities a ON a.id = b.authority_id
            WHERE pr.profile_id = auth.uid() 
            AND r.name = 'country_administrator'
            AND pr.is_active = true
            AND (pr.country_id = a.country_id OR pr.country_id IS NULL)
        )
    );

-- Schedule Time Slots Policies
CREATE POLICY "Border managers can manage time slots for their borders" ON schedule_time_slots
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM border_schedule_templates bst
            JOIN border_manager_borders bmb ON bmb.border_id = bst.border_id
            WHERE bst.id = schedule_time_slots.template_id
            AND bmb.profile_id = auth.uid() 
            AND bmb.is_active = true
        )
    );

CREATE POLICY "Country administrators can manage all time slots in their country" ON schedule_time_slots
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM border_schedule_templates bst
            JOIN borders b ON b.id = bst.border_id
            JOIN authorities a ON a.id = b.authority_id
            JOIN profile_roles pr ON pr.profile_id = auth.uid()
            JOIN roles r ON r.id = pr.role_id
            WHERE bst.id = schedule_time_slots.template_id
            AND r.name = 'country_administrator'
            AND pr.is_active = true
            AND (pr.country_id = a.country_id OR pr.country_id IS NULL)
        )
    );

-- Official Schedule Assignments Policies
CREATE POLICY "Border managers can manage assignments for their borders" ON official_schedule_assignments
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM schedule_time_slots sts
            JOIN border_schedule_templates bst ON bst.id = sts.template_id
            JOIN border_manager_borders bmb ON bmb.border_id = bst.border_id
            WHERE sts.id = official_schedule_assignments.time_slot_id
            AND bmb.profile_id = auth.uid() 
            AND bmb.is_active = true
        )
    );

CREATE POLICY "Officials can view their own assignments" ON official_schedule_assignments
    FOR SELECT USING (profile_id = auth.uid());

-- Schedule Snapshots Policies
CREATE POLICY "Border managers can view snapshots for their borders" ON schedule_snapshots
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM border_schedule_templates bst
            JOIN border_manager_borders bmb ON bmb.border_id = bst.border_id
            WHERE bst.id = schedule_snapshots.template_id
            AND bmb.profile_id = auth.uid() 
            AND bmb.is_active = true
        )
    );

CREATE POLICY "System can create snapshots" ON schedule_snapshots
    FOR INSERT WITH CHECK (created_by = auth.uid());

-- ========== COMMENTS AND DOCUMENTATION ==========

COMMENT ON TABLE border_schedule_templates IS 'Stores reusable schedule templates for border operations';
COMMENT ON TABLE schedule_time_slots IS 'Defines time slots within schedule templates';
COMMENT ON TABLE official_schedule_assignments IS 'Assigns border officials to specific time slots';
COMMENT ON TABLE schedule_snapshots IS 'Historical snapshots of schedule configurations for audit and analysis';

COMMENT ON COLUMN border_schedule_templates.is_active IS 'Only one template per border can be active at a time (enforced by unique index)';
COMMENT ON COLUMN schedule_time_slots.day_of_week IS '1=Monday, 2=Tuesday, ..., 7=Sunday';
COMMENT ON COLUMN official_schedule_assignments.effective_to IS 'NULL means indefinite assignment';
COMMENT ON COLUMN official_schedule_assignments.assignment_type IS 'primary, backup, or temporary assignment';
COMMENT ON COLUMN schedule_snapshots.snapshot_data IS 'JSONB containing complete schedule state at time of snapshot';

-- ========== SAMPLE QUERIES FOR TESTING ==========

-- Get active template for a border
-- SELECT * FROM border_schedule_templates WHERE border_id = 'your-border-id' AND is_active = true;

-- Get time slots for a template
-- SELECT * FROM schedule_time_slots WHERE template_id = 'your-template-id' AND is_active = true ORDER BY day_of_week, start_time;

-- Get active assignments for a time slot
-- SELECT osa.*, p.full_name 
-- FROM official_schedule_assignments osa 
-- JOIN profiles p ON p.id = osa.profile_id 
-- WHERE osa.time_slot_id = 'your-slot-id' 
-- AND osa.effective_from <= CURRENT_DATE 
-- AND (osa.effective_to IS NULL OR osa.effective_to >= CURRENT_DATE);

-- Check for assignment conflicts
-- SELECT osa.*, sts.day_of_week, sts.start_time, sts.end_time
-- FROM official_schedule_assignments osa
-- JOIN schedule_time_slots sts ON sts.id = osa.time_slot_id
-- WHERE osa.profile_id = 'your-profile-id'
-- AND sts.day_of_week = 1  -- Monday
-- AND osa.effective_from <= 'check-date'
-- AND (osa.effective_to IS NULL OR osa.effective_to >= 'check-date');