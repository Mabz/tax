-- ============================================================================
-- FUNCTION: delete_vehicle_tax_type
-- PURPOSE: Deletes a vehicle type (soft delete by setting is_active = false)
-- NOTE: Authorization is handled by table policies
-- ============================================================================
create or replace function delete_vehicle_tax_type(
  target_vehicle_type_id uuid
)
returns void
language plpgsql
security definer
as $$
begin
  -- Soft delete by setting is_active to false instead of hard delete
  -- This preserves referential integrity with existing tax rates
  update vehicle_types
  set is_active = false,
      updated_at = now()
  where id = target_vehicle_type_id;
  
  -- If you prefer hard delete (will fail if there are existing tax rates):
  -- delete from vehicle_types
  -- where id = target_vehicle_type_id;
end;
$$;
