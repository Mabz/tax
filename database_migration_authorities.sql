-- =====================================================
-- MIGRATION: Country-Centric to Authority-Centric Model
-- =====================================================

-- Step 1: Create the authorities table
CREATE TABLE public.authorities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  country_id uuid NOT NULL,
  name text NOT NULL,
  code text NOT NULL,
  authority_type text NOT NULL DEFAULT 'revenue_service',
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT authorities_pkey PRIMARY KEY (id),
  CONSTRAINT authorities_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(id),
  CONSTRAINT authorities_country_code_unique UNIQUE (country_id, code)
);

-- Step 2: Migrate existing data - Create default authority for each country
INSERT INTO public.authorities (country_id, name, code, authority_type, description)
SELECT 
  id as country_id,
  COALESCE(revenue_service_name, name || ' Revenue Service') as name,
  UPPER(LEFT(country_code, 3)) || 'RS' as code,
  'revenue_service' as authority_type,
  'Default revenue service authority for ' || name as description
FROM public.countries
WHERE is_active = true;

-- Step 3: Add authority_id columns to affected tables (nullable initially)
ALTER TABLE public.pass_templates ADD COLUMN authority_id uuid;
ALTER TABLE public.borders ADD COLUMN authority_id uuid;
ALTER TABLE public.role_invitations ADD COLUMN authority_id uuid;
ALTER TABLE public.vehicle_tax_rates ADD COLUMN authority_id uuid;
ALTER TABLE public.profile_roles ADD COLUMN authority_id uuid;
ALTER TABLE public.audit_logs ADD COLUMN authority_id uuid;

-- Step 4: Migrate foreign key references
-- For pass_templates
UPDATE public.pass_templates 
SET authority_id = (
  SELECT a.id 
  FROM public.authorities a 
  WHERE a.country_id = pass_templates.country_id 
  LIMIT 1
);

-- For borders
UPDATE public.borders 
SET authority_id = (
  SELECT a.id 
  FROM public.authorities a 
  WHERE a.country_id = borders.country_id 
  LIMIT 1
);

-- For role_invitations
UPDATE public.role_invitations 
SET authority_id = (
  SELECT a.id 
  FROM public.authorities a 
  WHERE a.country_id = role_invitations.country_id 
  LIMIT 1
);

-- For vehicle_tax_rates
UPDATE public.vehicle_tax_rates 
SET authority_id = (
  SELECT a.id 
  FROM public.authorities a 
  WHERE a.country_id = vehicle_tax_rates.country_id 
  LIMIT 1
);

-- For profile_roles
UPDATE public.profile_roles 
SET authority_id = (
  SELECT a.id 
  FROM public.authorities a 
  WHERE a.country_id = profile_roles.country_id 
  LIMIT 1
);

-- Step 5: Make authority_id NOT NULL and add foreign key constraints
ALTER TABLE public.pass_templates ALTER COLUMN authority_id SET NOT NULL;
ALTER TABLE public.borders ALTER COLUMN authority_id SET NOT NULL;
ALTER TABLE public.role_invitations ALTER COLUMN authority_id SET NOT NULL;
ALTER TABLE public.vehicle_tax_rates ALTER COLUMN authority_id SET NOT NULL;
ALTER TABLE public.profile_roles ALTER COLUMN authority_id SET NOT NULL;

-- Add foreign key constraints
ALTER TABLE public.pass_templates 
ADD CONSTRAINT pass_templates_authority_id_fkey 
FOREIGN KEY (authority_id) REFERENCES public.authorities(id);

ALTER TABLE public.borders 
ADD CONSTRAINT borders_authority_id_fkey 
FOREIGN KEY (authority_id) REFERENCES public.authorities(id);

ALTER TABLE public.role_invitations 
ADD CONSTRAINT role_invitations_authority_id_fkey 
FOREIGN KEY (authority_id) REFERENCES public.authorities(id);

ALTER TABLE public.vehicle_tax_rates 
ADD CONSTRAINT vehicle_tax_rates_authority_id_fkey 
FOREIGN KEY (authority_id) REFERENCES public.authorities(id);

ALTER TABLE public.profile_roles 
ADD CONSTRAINT profile_roles_authority_id_fkey 
FOREIGN KEY (authority_id) REFERENCES public.authorities(id);

ALTER TABLE public.audit_logs 
ADD CONSTRAINT audit_logs_authority_id_fkey 
FOREIGN KEY (authority_id) REFERENCES public.authorities(id);

-- Step 6: Drop old country_id columns (except from audit_logs - keep both)
ALTER TABLE public.pass_templates DROP CONSTRAINT pass_templates_country_id_fkey;
ALTER TABLE public.pass_templates DROP COLUMN country_id;

ALTER TABLE public.borders DROP CONSTRAINT borders_country_id_fkey;
ALTER TABLE public.borders DROP COLUMN country_id;

ALTER TABLE public.role_invitations DROP CONSTRAINT role_invitations_country_id_fkey;
ALTER TABLE public.role_invitations DROP COLUMN country_id;

ALTER TABLE public.vehicle_tax_rates DROP CONSTRAINT vehicle_tax_rates_country_id_fkey;
ALTER TABLE public.vehicle_tax_rates DROP COLUMN country_id;

ALTER TABLE public.profile_roles DROP CONSTRAINT profile_roles_country_id_fkey;
ALTER TABLE public.profile_roles DROP COLUMN country_id;

-- Step 7: Remove revenue_service_name from countries table
ALTER TABLE public.countries DROP COLUMN revenue_service_name;

-- Step 8: Create indexes for performance
CREATE INDEX idx_authorities_country_id ON public.authorities(country_id);
CREATE INDEX idx_authorities_active ON public.authorities(is_active);
CREATE INDEX idx_pass_templates_authority_id ON public.pass_templates(authority_id);
CREATE INDEX idx_borders_authority_id ON public.borders(authority_id);
CREATE INDEX idx_role_invitations_authority_id ON public.role_invitations(authority_id);
CREATE INDEX idx_vehicle_tax_rates_authority_id ON public.vehicle_tax_rates(authority_id);
CREATE INDEX idx_profile_roles_authority_id ON public.profile_roles(authority_id);

-- Step 9: Update unique constraints that included country_id
-- For vehicle_tax_rates (if there was a unique constraint)
-- ALTER TABLE public.vehicle_tax_rates DROP CONSTRAINT IF EXISTS vehicle_tax_rates_unique;
-- ALTER TABLE public.vehicle_tax_rates ADD CONSTRAINT vehicle_tax_rates_unique 
-- UNIQUE (authority_id, border_id, vehicle_type_id);

COMMIT;
