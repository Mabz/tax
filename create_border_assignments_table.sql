-- Create border_official_borders table if it doesn't exist
-- This table manages the assignment of border officials to specific borders

CREATE TABLE IF NOT EXISTS public.border_official_borders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  border_id uuid NOT NULL,
  assigned_by_profile_id uuid,
  assigned_at timestamp with time zone DEFAULT now(),
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT border_official_borders_pkey PRIMARY KEY (id),
  CONSTRAINT border_official_borders_assigned_by_profile_id_fkey FOREIGN KEY (assigned_by_profile_id) REFERENCES public.profiles(id),
  CONSTRAINT border_official_borders_border_id_fkey FOREIGN KEY (border_id) REFERENCES public.borders(id),
  CONSTRAINT border_official_borders_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id),
  CONSTRAINT border_official_borders_unique_assignment UNIQUE (profile_id, border_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_border_official_borders_profile_id ON public.border_official_borders(profile_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_border_id ON public.border_official_borders(border_id);
CREATE INDEX IF NOT EXISTS idx_border_official_borders_active ON public.border_official_borders(is_active) WHERE is_active = true;

-- Enable RLS (Row Level Security)
ALTER TABLE public.border_official_borders ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for border_official_borders table
-- Policy for authenticated users to view assignments
CREATE POLICY "Users can view border assignments" ON public.border_official_borders
  FOR SELECT USING (auth.role() = 'authenticated');

-- Policy for admins to manage assignments
CREATE POLICY "Admins can manage border assignments" ON public.border_official_borders
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profile_roles pr
      JOIN roles r ON r.id = pr.role_id
      WHERE pr.profile_id = auth.uid()
      AND r.name IN ('superuser', 'country_admin')
      AND pr.is_active = true
    )
  );

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.border_official_borders TO authenticated;
GRANT USAGE ON SEQUENCE border_official_borders_id_seq TO authenticated;
