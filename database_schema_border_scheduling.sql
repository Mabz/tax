-- Border Officials Scheduling System Database Schema
-- This file contains the SQL schema for implementing the border officials scheduling system

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

-- Indexes for performance
CREATE INDEX idx_border_schedule_templates_border_id ON border_schedule_templates(border_id);
CREATE INDEX idx_border_schedule_templates_created_by ON border_schedule_templates(created_by);

-- Unique constraint: only one active template per border
CREATE UNIQUE INDEX idx_unique_active_template_per_border 
    ON border_schedule_templates(border_id) 
    WHERE is_active = true;

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

-- Indexes for performance
CREATE INDEX idx_schedule_time_slots_template_id ON schedule_time_slots(template_id);
CREATE INDEX idx_schedule_time_slots_day_time ON schedule_time_slots(template_id, day_of_week, start_time);
CREATE INDEX idx_schedule_time_slots_active ON schedule_time_slots(template_id, is_active) WHERE is_active = true;

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

-- Indexes for performance
CREATE INDEX idx_official_schedule_assignments_time_slot ON official_schedule_assignments(time_slot_id);
CREATE INDEX idx_official_schedule_assignments_profile ON official_schedule_assignments(profile_id);
CREATE INDEX idx_official_schedule_assignments_dates ON official_schedule_assignments(effective_from, effective_to);
-- Index for active assignments (without date function to avoid IMMUTABLE requirement)
CREATE INDEX idx_official_schedule_assignments_active ON official_schedule_assignments(time_slot_id, profile_id, effective_from, effective_to);

-- Prevent overlapping assignments for the same official and time slot
-- This is handled at the application level in the service layer

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

-- Indexes for performance
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

-- ========== TRIGGERS FOR AUTOMATIC SNAPSHOT CREATION ==========

-- Function to create automatic snapshots
CREATE OR REPLACE FUNCTION create_schedule_snapshot()
RETURNS TRIGGER AS $$
BEGIN
    -- Create snapshot when template is modified
    IF TG_TABLE_NAME = 'border_schedule_templates' AND TG_OP = 'UPDATE' THEN
        IF OLD.is_active != NEW.is_active THEN
            INSERT INTO schedule_snapshots (template_id, snapshot_date, snapshot_data, reason, created_by)
            VALUES (
                NEW.id,
                CURRENT_DATE,
                jsonb_build_object(
                    'template_name', NEW.template_name,
                    'is_active', NEW.is_active,
                    'change_type', 'activation_status'
                ),
                CASE WHEN NEW.is_active THEN 'template_activation' ELSE 'template_deactivation' END,
                NEW.created_by
            );
        END IF;
    END IF;
    
    -- Create snapshot when time slots are modified
    IF TG_TABLE_NAME = 'schedule_time_slots' THEN
        INSERT INTO schedule_snapshots (template_id, snapshot_date, snapshot_data, reason, created_by)
        VALUES (
            COALESCE(NEW.template_id, OLD.template_id),
            CURRENT_DATE,
            jsonb_build_object(
                'operation', TG_OP,
                'slot_data', CASE WHEN NEW IS NOT NULL THEN row_to_json(NEW) ELSE row_to_json(OLD) END
            ),
            'schedule_change',
            auth.uid()
        );
    END IF;
    
    -- Create snapshot when assignments are modified
    IF TG_TABLE_NAME = 'official_schedule_assignments' THEN
        INSERT INTO schedule_snapshots (template_id, snapshot_date, snapshot_data, reason, created_by)
        SELECT 
            sts.template_id,
            CURRENT_DATE,
            jsonb_build_object(
                'operation', TG_OP,
                'assignment_data', CASE WHEN NEW IS NOT NULL THEN row_to_json(NEW) ELSE row_to_json(OLD) END
            ),
            'official_reassignment',
            COALESCE(NEW.created_by, auth.uid())
        FROM schedule_time_slots sts
        WHERE sts.id = COALESCE(NEW.time_slot_id, OLD.time_slot_id);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER trigger_schedule_template_snapshot
    AFTER UPDATE ON border_schedule_templates
    FOR EACH ROW EXECUTE FUNCTION create_schedule_snapshot();

CREATE TRIGGER trigger_time_slot_snapshot
    AFTER INSERT OR UPDATE OR DELETE ON schedule_time_slots
    FOR EACH ROW EXECUTE FUNCTION create_schedule_snapshot();

CREATE TRIGGER trigger_assignment_snapshot
    AFTER INSERT OR UPDATE OR DELETE ON official_schedule_assignments
    FOR EACH ROW EXECUTE FUNCTION create_schedule_snapshot();

-- ========== UTILITY FUNCTIONS ==========

-- Function to get active assignments for a time slot on a specific date
CREATE OR REPLACE FUNCTION get_active_assignments_for_slot(
    slot_id UUID,
    check_date DATE
)
RETURNS TABLE (
    assignment_id UUID,
    profile_id UUID,
    full_name TEXT,
    assignment_type VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        osa.id,
        osa.profile_id,
        p.full_name,
        osa.assignment_type
    FROM official_schedule_assignments osa
    JOIN profiles p ON p.id = osa.profile_id
    WHERE osa.time_slot_id = slot_id
    AND osa.effective_from <= check_date
    AND (osa.effective_to IS NULL OR osa.effective_to >= check_date)
    ORDER BY 
        CASE osa.assignment_type 
            WHEN 'primary' THEN 1 
            WHEN 'backup' THEN 2 
            WHEN 'temporary' THEN 3 
        END,
        osa.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check schedule conflicts for an official
CREATE OR REPLACE FUNCTION check_schedule_conflicts(
    check_profile_id UUID,
    check_day_of_week INTEGER,
    check_start_time TIME,
    check_end_time TIME,
    exclude_assignment_id UUID DEFAULT NULL
)
RETURNS TABLE (
    conflict_assignment_id UUID,
    conflict_time_slot_id UUID,
    conflict_start_time TIME,
    conflict_end_time TIME
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        osa.id,
        sts.id,
        sts.start_time,
        sts.end_time
    FROM official_schedule_assignments osa
    JOIN schedule_time_slots sts ON sts.id = osa.time_slot_id
    WHERE osa.profile_id = check_profile_id
    AND sts.day_of_week = check_day_of_week
    AND sts.is_active = true
    AND (osa.effective_to IS NULL OR osa.effective_to >= check_date)
    AND (exclude_assignment_id IS NULL OR osa.id != exclude_assignment_id)
    AND (
        (sts.start_time < check_end_time AND sts.end_time > check_start_time) OR
        (check_start_time < sts.end_time AND check_end_time > sts.start_time)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========== SAMPLE DATA (Optional - for testing) ==========

-- Note: This section would be used for testing purposes only
-- Uncomment and modify as needed for development/testing

/*
-- Sample border schedule template
INSERT INTO border_schedule_templates (border_id, template_name, description, is_active, created_by)
VALUES (
    (SELECT id FROM borders LIMIT 1),
    'Standard Weekday Schedule',
    'Regular Monday-Friday border operations schedule',
    true,
    (SELECT id FROM profiles WHERE role = 'border_manager' LIMIT 1)
);

-- Sample time slots
INSERT INTO schedule_time_slots (template_id, day_of_week, start_time, end_time, min_officials, max_officials)
SELECT 
    bst.id,
    generate_series(1, 5) as day_of_week, -- Monday to Friday
    '08:00'::time,
    '16:00'::time,
    2,
    4
FROM border_schedule_templates bst
WHERE bst.template_name = 'Standard Weekday Schedule';
*/

-- ========== COMMENTS AND DOCUMENTATION ==========

COMMENT ON TABLE border_schedule_templates IS 'Stores reusable schedule templates for border operations';
COMMENT ON TABLE schedule_time_slots IS 'Defines time slots within schedule templates';
COMMENT ON TABLE official_schedule_assignments IS 'Assigns border officials to specific time slots';
COMMENT ON TABLE schedule_snapshots IS 'Historical snapshots of schedule configurations for audit and analysis';

COMMENT ON COLUMN border_schedule_templates.is_active IS 'Only one template per border can be active at a time';
COMMENT ON COLUMN schedule_time_slots.day_of_week IS '1=Monday, 2=Tuesday, ..., 7=Sunday';
COMMENT ON COLUMN official_schedule_assignments.effective_to IS 'NULL means indefinite assignment';
COMMENT ON COLUMN official_schedule_assignments.assignment_type IS 'primary, backup, or temporary assignment';
COMMENT ON COLUMN schedule_snapshots.snapshot_data IS 'JSONB containing complete schedule state at time of snapshot';