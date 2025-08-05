-- =====================================================
-- FRESH DATABASE SCHEMA WITH AUTHORITY-CENTRIC MODEL
-- =====================================================

-- WARNING: This will drop all existing tables and data!
-- Only run this in development environments.

-- Drop all tables in dependency order
DROP TABLE IF EXISTS public.purchased_passes CASCADE;
DROP TABLE IF EXISTS public.pass_templates CASCADE;
DROP TABLE IF EXISTS public.vehicle_tax_rates CASCADE;
DROP TABLE IF EXISTS public.border_official_borders CASCADE;
DROP TABLE IF EXISTS public.profile_roles CASCADE;
DROP TABLE IF EXISTS public.role_invitations CASCADE;
DROP TABLE IF EXISTS public.borders CASCADE;
DROP TABLE IF EXISTS public.authorities CASCADE;
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;
DROP TABLE IF EXISTS public.border_types CASCADE;
DROP TABLE IF EXISTS public.vehicle_types CASCADE;
DROP TABLE IF EXISTS public.currencies CASCADE;
DROP TABLE IF EXISTS public.countries CASCADE;

-- =====================================================
-- REFERENCE TABLES
-- =====================================================

-- Countries table (simplified - no revenue_service_name)
CREATE TABLE public.countries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  country_code character varying NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT false,
  is_global boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT countries_pkey PRIMARY KEY (id)
);

-- Currencies table
CREATE TABLE public.currencies (
  code text NOT NULL,
  name text NOT NULL,
  symbol text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT currencies_pkey PRIMARY KEY (code)
);

-- Vehicle types table
CREATE TABLE public.vehicle_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  label text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT vehicle_types_pkey PRIMARY KEY (id)
);

-- Border types table
CREATE TABLE public.border_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  label text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT border_types_pkey PRIMARY KEY (id)
);

-- Roles table
CREATE TABLE public.roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  display_name text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT roles_pkey PRIMARY KEY (id)
);

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Authorities table (NEW - replaces country-centric model)
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

-- Profiles table
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name text,
  email text UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  require_manual_pass_confirmation boolean DEFAULT false,
  card_holder_name text,
  card_last4 text,
  card_exp_month integer,
  card_exp_year integer,
  payment_provider_token text,
  payment_provider text,
  national_id_number text,
  passport_number text,
  country_of_origin_id uuid,
  pass_confirmation_type text NOT NULL DEFAULT 'none'::text,
  static_confirmation_code text,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT profiles_country_of_origin_id_fkey FOREIGN KEY (country_of_origin_id) REFERENCES public.countries(id)
);

-- Vehicles table
CREATE TABLE public.vehicles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  number_plate text NOT NULL,
  description text,
  vin_number text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT vehicles_pkey PRIMARY KEY (id),
  CONSTRAINT vehicles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);

-- Borders table (NOW REFERENCES AUTHORITY)
CREATE TABLE public.borders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  authority_id uuid NOT NULL,
  name text NOT NULL,
  border_type_id uuid,
  is_active boolean DEFAULT true,
  latitude double precision,
  longitude double precision,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT borders_pkey PRIMARY KEY (id),
  CONSTRAINT borders_authority_id_fkey FOREIGN KEY (authority_id) REFERENCES public.authorities(id),
  CONSTRAINT borders_border_type_id_fkey FOREIGN KEY (border_type_id) REFERENCES public.border_types(id)
);

-- Profile roles table (NOW REFERENCES AUTHORITY)
CREATE TABLE public.profile_roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  role_id uuid NOT NULL,
  authority_id uuid NOT NULL,
  assigned_by_profile_id uuid,
  assigned_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profile_roles_pkey PRIMARY KEY (id),
  CONSTRAINT profile_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id),
  CONSTRAINT profile_roles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id),
  CONSTRAINT profile_roles_assigned_by_profile_id_fkey FOREIGN KEY (assigned_by_profile_id) REFERENCES public.profiles(id),
  CONSTRAINT profile_roles_authority_id_fkey FOREIGN KEY (authority_id) REFERENCES public.authorities(id)
);

-- Role invitations table (NOW REFERENCES AUTHORITY)
CREATE TABLE public.role_invitations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  email text NOT NULL,
  role_id uuid NOT NULL,
  authority_id uuid NOT NULL,
  invited_by_profile_id uuid,
  status text NOT NULL DEFAULT 'pending'::text,
  invited_at timestamp with time zone NOT NULL DEFAULT now(),
  responded_at timestamp with time zone,
  expires_at timestamp with time zone,
  CONSTRAINT role_invitations_pkey PRIMARY KEY (id),
  CONSTRAINT role_invitations_invited_by_profile_id_fkey FOREIGN KEY (invited_by_profile_id) REFERENCES public.profiles(id),
  CONSTRAINT role_invitations_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id),
  CONSTRAINT role_invitations_authority_id_fkey FOREIGN KEY (authority_id) REFERENCES public.authorities(id)
);

-- Border official borders table
CREATE TABLE public.border_official_borders (
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
  CONSTRAINT border_official_borders_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);

-- Vehicle tax rates table (NOW REFERENCES AUTHORITY)
CREATE TABLE public.vehicle_tax_rates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  authority_id uuid NOT NULL,
  border_id uuid,
  vehicle_type_id uuid NOT NULL,
  tax_amount numeric NOT NULL,
  currency text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT vehicle_tax_rates_pkey PRIMARY KEY (id),
  CONSTRAINT vehicle_tax_rates_vehicle_type_id_fkey FOREIGN KEY (vehicle_type_id) REFERENCES public.vehicle_types(id),
  CONSTRAINT vehicle_tax_rates_currency_fkey FOREIGN KEY (currency) REFERENCES public.currencies(code),
  CONSTRAINT vehicle_tax_rates_authority_id_fkey FOREIGN KEY (authority_id) REFERENCES public.authorities(id),
  CONSTRAINT vehicle_tax_rates_border_id_fkey FOREIGN KEY (border_id) REFERENCES public.borders(id)
);

-- Pass templates table (NOW REFERENCES AUTHORITY)
CREATE TABLE public.pass_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  authority_id uuid NOT NULL,
  border_id uuid,
  created_by_profile_id uuid NOT NULL,
  vehicle_type_id uuid NOT NULL,
  description text NOT NULL,
  entry_limit integer NOT NULL CHECK (entry_limit > 0),
  expiration_days integer NOT NULL CHECK (expiration_days > 0),
  tax_amount numeric NOT NULL CHECK (tax_amount >= 0::numeric),
  currency_code text NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pass_templates_pkey PRIMARY KEY (id),
  CONSTRAINT pass_templates_vehicle_type_id_fkey FOREIGN KEY (vehicle_type_id) REFERENCES public.vehicle_types(id),
  CONSTRAINT pass_templates_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES public.currencies(code),
  CONSTRAINT pass_templates_created_by_profile_id_fkey FOREIGN KEY (created_by_profile_id) REFERENCES public.profiles(id),
  CONSTRAINT pass_templates_border_id_fkey FOREIGN KEY (border_id) REFERENCES public.borders(id),
  CONSTRAINT pass_templates_authority_id_fkey FOREIGN KEY (authority_id) REFERENCES public.authorities(id)
);

-- Purchased passes table
CREATE TABLE public.purchased_passes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  vehicle_id uuid NOT NULL,
  pass_template_id uuid NOT NULL,
  issued_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone,
  entries_remaining integer,
  status text DEFAULT 'active'::text,
  pass_hash text UNIQUE,
  short_code text UNIQUE,
  qr_data jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT purchased_passes_pkey PRIMARY KEY (id),
  CONSTRAINT purchased_passes_pass_template_id_fkey FOREIGN KEY (pass_template_id) REFERENCES public.pass_templates(id),
  CONSTRAINT purchased_passes_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id),
  CONSTRAINT purchased_passes_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);

-- Audit logs table (INCLUDES BOTH AUTHORITY AND COUNTRY FOR FLEXIBILITY)
CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_profile_id uuid,
  target_profile_id uuid,
  authority_id uuid,
  action text NOT NULL,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT audit_logs_actor_profile_id_fkey FOREIGN KEY (actor_profile_id) REFERENCES public.profiles(id),
  CONSTRAINT audit_logs_target_profile_id_fkey FOREIGN KEY (target_profile_id) REFERENCES public.profiles(id),
  CONSTRAINT audit_logs_authority_id_fkey FOREIGN KEY (authority_id) REFERENCES public.authorities(id)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX idx_authorities_country_id ON public.authorities(country_id);
CREATE INDEX idx_authorities_active ON public.authorities(is_active);
CREATE INDEX idx_borders_authority_id ON public.borders(authority_id);
CREATE INDEX idx_profile_roles_authority_id ON public.profile_roles(authority_id);
CREATE INDEX idx_profile_roles_profile_id ON public.profile_roles(profile_id);
CREATE INDEX idx_role_invitations_authority_id ON public.role_invitations(authority_id);
CREATE INDEX idx_vehicle_tax_rates_authority_id ON public.vehicle_tax_rates(authority_id);
CREATE INDEX idx_pass_templates_authority_id ON public.pass_templates(authority_id);
CREATE INDEX idx_purchased_passes_profile_id ON public.purchased_passes(profile_id);
CREATE INDEX idx_purchased_passes_pass_hash ON public.purchased_passes(pass_hash);
CREATE INDEX idx_purchased_passes_short_code ON public.purchased_passes(short_code);
CREATE INDEX idx_purchased_passes_qr_data_gin ON public.purchased_passes USING GIN (qr_data);
CREATE INDEX idx_audit_logs_authority_id ON public.audit_logs(authority_id);

-- =====================================================
-- INSERT INITIAL DATA
-- =====================================================

-- Insert basic roles
INSERT INTO public.roles (name, display_name, description) VALUES
('superuser', 'Superuser', 'Full system access'),
('country_admin', 'Country Administrator', 'Manages country/authority operations'),
('border_official', 'Border Official', 'Manages border crossings and pass verification'),
('auditor', 'Auditor', 'Read-only access for compliance and auditing');

-- Insert basic currencies
INSERT INTO public.currencies (code, name, symbol, is_active) VALUES
('USD', 'US Dollar', '$', true),
('EUR', 'Euro', '€', true),
('GBP', 'British Pound', '£', true),
('ZAR', 'South African Rand', 'R', true),
('KES', 'Kenyan Shilling', 'KSh', true),
('NGN', 'Nigerian Naira', '₦', true);

-- Insert basic vehicle types
INSERT INTO public.vehicle_types (code, label, description) VALUES
('CAR', 'Car', 'Personal passenger vehicle'),
('TRUCK', 'Truck', 'Commercial freight vehicle'),
('BUS', 'Bus', 'Passenger transport vehicle'),
('MOTORCYCLE', 'Motorcycle', 'Two-wheeled motor vehicle'),
('TRAILER', 'Trailer', 'Towed cargo vehicle');

-- Insert basic border types
INSERT INTO public.border_types (code, label, description) VALUES
('LAND', 'Land Border', 'Road border crossing'),
('AIRPORT', 'Airport', 'Air border crossing'),
('SEAPORT', 'Seaport', 'Maritime border crossing'),
('RAILWAY', 'Railway', 'Rail border crossing');

-- Insert sample countries
INSERT INTO public.countries (name, country_code, is_active, is_global) VALUES
('South Africa', 'ZA', true, false),
('Kenya', 'KE', true, false),
('Nigeria', 'NG', true, false),
('United States', 'US', true, false),
('United Kingdom', 'GB', true, false);

-- Insert sample authorities (one per country initially)
INSERT INTO public.authorities (country_id, name, code, authority_type, description)
SELECT 
  c.id,
  c.name || ' Revenue Service',
  UPPER(LEFT(c.country_code, 3)) || 'RS',
  'revenue_service',
  'Primary revenue service authority for ' || c.name
FROM public.countries c
WHERE c.is_active = true;

COMMIT;
