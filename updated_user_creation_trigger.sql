-- Updated user creation trigger function for authority-centric model
-- Uses default authorities approach for clean data integrity
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
declare
  -- Variable to store the UUID of the default 'traveller' role
  traveller_role_id uuid;
  
  -- Variable to store the UUID of the global authority
  global_authority_id uuid;
begin
  -- SECTION 1: ROLE VALIDATION
  -- Retrieve the traveller role ID from the roles table
  -- This is the default role assigned to all new users
  select id into traveller_role_id 
  from public.roles 
  where name = 'traveller' 
  limit 1;
  
  -- Fail explicitly if the traveller role doesn't exist
  if traveller_role_id is null then
    raise exception 'Role "traveller" not found in roles table.';
  end if;

  -- SECTION 2: AUTHORITY VALIDATION
  -- Retrieve the global authority ID for system-wide user assignments
  select a.id into global_authority_id 
  from public.authorities a
  join public.countries c on c.id = a.country_id
  where c.is_global = true 
    and a.authority_type = 'global'
    and a.is_active = true
  limit 1;
  
  -- Fail explicitly if the global authority record doesn't exist
  if global_authority_id is null then
    raise exception 'Global authority not found. Please ensure a global authority exists.';
  end if;

  -- SECTION 3: PROFILE CREATION
  -- Create the user profile in our public.profiles table
  -- Uses data from the auth.users record (NEW)
  insert into public.profiles (
    id,                      -- Matches auth.users.id
    full_name,               -- Extracted from raw_user_meta_data
    email,                   -- Copied from auth record
    created_at,
    updated_at
  )
  values (
    NEW.id,
    NEW.raw_user_meta_data ->> 'full_name',  -- Extract from JSON metadata
    NEW.email,
    now(),
    now()
  );

  -- SECTION 4: ROLE ASSIGNMENT
  -- Assign the default traveller role with global authority scope
  insert into public.profile_roles (
    id,
    profile_id,             -- Links to the new profile
    role_id,               -- The traveller role UUID
    authority_id,          -- Global authority scope
    assigned_by_profile_id, -- Null for system-assigned roles
    assigned_at,
    is_active,             -- Immediately active
    created_at,
    updated_at
  )
  values (
    gen_random_uuid(),     -- Generate new UUID for this role assignment
    NEW.id,
    traveller_role_id,
    global_authority_id,   -- Use global authority for clean data model
    null,                  -- System-assigned (no specific admin)
    now(),
    true,                  -- Active by default
    now(),
    now()
  );

  -- Return the NEW record to continue trigger execution
  return NEW;
end;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;

-- Ensure the trigger is properly set up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();