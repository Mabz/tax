-- Populate Default Authorities for SARS and ERS
-- Creates South African Revenue Service and Eswatini Revenue Service

-- First, ensure we have the countries (add Eswatini and Global if missing)
INSERT INTO public.countries (name, country_code, is_active, is_global) VALUES
('Eswatini', 'SZ', true, false),
('Global', 'GLOBAL', true, true)
ON CONFLICT (country_code) DO NOTHING;

-- Create SARS (South African Revenue Service)
INSERT INTO public.authorities (
  id,
  country_id,
  name,
  code,
  authority_type,
  description,
  pass_advance_days,
  default_currency_code,
  is_active,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  (SELECT id FROM public.countries WHERE country_code = 'ZA' LIMIT 1),
  'South African Revenue Service',
  'SARS',
  'revenue_service',
  'South African Revenue Service responsible for tax collection and customs',
  30,
  'ZAR',
  true,
  now(),
  now()
) ON CONFLICT (country_id, code) DO NOTHING;

-- Create ERS (Eswatini Revenue Service)
INSERT INTO public.authorities (
  id,
  country_id,
  name,
  code,
  authority_type,
  description,
  pass_advance_days,
  default_currency_code,
  is_active,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  (SELECT id FROM public.countries WHERE country_code = 'SZ' LIMIT 1),
  'Eswatini Revenue Service',
  'ERS',
  'revenue_service',
  'Eswatini Revenue Service responsible for tax collection and customs',
  30,
  'SZL',
  true,
  now(),
  now()
) ON CONFLICT (country_id, code) DO NOTHING;

-- Create Global Authority for system-wide operations
INSERT INTO public.authorities (
  id,
  country_id,
  name,
  code,
  authority_type,
  description,
  pass_advance_days,
  default_currency_code,
  is_active,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  (SELECT id FROM public.countries WHERE is_global = true LIMIT 1),
  'Global Authority',
  'GLOBAL',
  'global',
  'Global authority for system-wide operations and default user assignments',
  90,
  'USD',
  true,
  now(),
  now()
) ON CONFLICT (country_id, code) DO NOTHING;

-- Verify the insertions
SELECT 
  a.name,
  a.code,
  a.authority_type,
  a.pass_advance_days,
  a.default_currency_code,
  c.name as country_name,
  c.country_code
FROM public.authorities a
JOIN public.countries c ON c.id = a.country_id
WHERE a.code IN ('SARS', 'ERS', 'GLOBAL')
ORDER BY a.code;
