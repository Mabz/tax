-- EasyTax Supabase Database Schema
-- Last updated: 2025-08-02

-- Enable UUID extension
create extension if not exists "pgcrypto";

-- ROLES TABLE
create table if not exists roles (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  display_name text not null,
  description text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text unique,
  is_active boolean default true not null,  -- <-- added
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);


-- COUNTRIES TABLE
create table if not exists countries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country_code varchar(3) unique not null, -- ISO 3166-1 alpha-3
  revenue_service_name text not null,
  is_active boolean default false not null, -- <-- added this line
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- PROFILE ROLES TABLE
create table if not exists profile_roles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,  -- must be set
  role_id uuid not null references roles(id) on delete cascade,        -- must be set
  country_id uuid references countries(id) on delete set null,         -- optional
  assigned_by_profile_id uuid references profiles(id) on delete set null,
  assigned_at timestamptz default now(),
  expires_at timestamptz,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(profile_id, role_id, country_id)
);

-- AUDIT LOG TABLE
create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_profile_id uuid references profiles(id) on delete set null, -- preserve history
  target_profile_id uuid references profiles(id) on delete set null,
  action text not null,
  metadata jsonb,
  created_at timestamptz default now()
);

-- BORDER TYPES TABLE
create table if not exists border_types (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,                -- e.g. road, rail, pedestrian, air
  label text not null,                      -- e.g. "Road Border", "Rail Border"
  description text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- BORDERS
create table if not exists borders (
  id uuid primary key default gen_random_uuid(),
  country_id uuid references countries(id) on delete cascade,
  name text not null,
  border_type_id uuid references border_types(id),
  is_active boolean default true,
  latitude double precision,
  longitude double precision,
  description text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);


-- =============================================================================
-- SEED DATA
-- =============================================================================

-- Insert predefined roles
insert into roles (id, name, display_name, description, created_at, updated_at)
values
  (gen_random_uuid(), 'traveller', 'Traveller', 'Can purchase and view passes for their own vehicles.', now(), now()),
  (gen_random_uuid(), 'country_admin', 'Country Administrator', 'Manages tax policies, border settings, and customs officials within a specific country.', now(), now()),
  (gen_random_uuid(), 'customs_official', 'Customs Official', 'Scans and verifies passes at borders. Operates within one country.', now(), now()),
  (gen_random_uuid(), 'local_authority', 'Local Authority', 'Scans and verifies pass codes issued to travellers.', now(), now()),
  (gen_random_uuid(), 'superuser', 'Superuser', 'Full system administrator. Can assign any role and access all country data.', now(), now())
on conflict (name) do nothing;

-- Insert countries and revenue authority names
insert into countries (id, name, country_code, revenue_service_name, created_at, updated_at)
values
  (gen_random_uuid(), 'Eswatini',     'SWZ', 'Eswatini Revenue Authority',          now(), now()),
  (gen_random_uuid(), 'South Africa','ZAF', 'South African Revenue Service',       now(), now()),
  (gen_random_uuid(), 'Kenya',       'KEN', 'Kenya Revenue Authority',             now(), now()),
  (gen_random_uuid(), 'Nigeria',     'NGA', 'Federal Inland Revenue Service',      now(), now()),
  (gen_random_uuid(), 'Namibia',     'NAM', 'Namibia Revenue Agency',              now(), now()),
  (gen_random_uuid(), 'Mozambique',  'MOZ', 'Autoridade Tributária de Moçambique', now(), now()),
  (gen_random_uuid(), 'Botswana',    'BWA', 'Botswana Unified Revenue Service',    now(), now()),
  (gen_random_uuid(), 'Zambia',      'ZMB', 'Zambia Revenue Authority',            now(), now()),
  (gen_random_uuid(), 'Zimbabwe',    'ZWE', 'Zimbabwe Revenue Authority',          now(), now()),
  (gen_random_uuid(), 'Tanzania',    'TZA', 'Tanzania Revenue Authority',          now(), now()),
  (gen_random_uuid(), 'Lesotho',     'LSO', 'Lesotho Revenue Authority',           now(), now()),
  (gen_random_uuid(), 'Angola',      'AGO', 'Administração Geral Tributária',      now(), now())
on conflict (country_code) do nothing;

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Generic function to check if a user has a specific role
-- For superuser: call with role_name='superuser', country_code=null
-- For country-specific roles: call with role_name='country_admin', country_code='ZAF'
-- For checking other users: provide user_id parameter
create or replace function user_has_role(
  role_name text,
  country_code text default null,
  user_id uuid default auth.uid()
)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 
    from profile_roles pr
    join roles r on r.id = pr.role_id
    left join countries c on c.id = pr.country_id
    where pr.profile_id = user_id
      and r.name = role_name
      and pr.is_active = true
      and (pr.expires_at is null or pr.expires_at > now())
      and (
        -- If no country_code provided, match any country assignment (including null)
        country_code is null
        or 
        -- If country_code provided, match exact country or null country (for superuser)
        (c.country_code = country_code or pr.country_id is null)
      )
  );
$$;

-- Convenience function to check if current user is superuser
create or replace function is_superuser()
returns boolean
language sql
security definer
stable
as $$
  select user_has_role('superuser');
$$;
