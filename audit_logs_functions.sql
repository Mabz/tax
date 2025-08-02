-- Enhanced audit logs functions with pagination and JSONB search support

-- Create or replace the basic function for getting audit logs by country
create or replace function get_audit_logs_by_country(target_country_id uuid)
returns setof audit_logs
language plpgsql
security definer
stable
as $$
begin
  return query
  select *
  from audit_logs
  where (metadata ->> 'country_id')::uuid = target_country_id
  order by created_at desc;
end;
$$;

-- Enhanced function with pagination and JSONB search support
create or replace function get_audit_logs_paginated(
  target_country_id uuid default null,
  search_metadata jsonb default null,
  search_action text default null,
  limit_count integer default 50,
  offset_count integer default 0,
  order_by text default 'created_at',
  order_direction text default 'DESC'
)
returns table (
  id uuid,
  actor_profile_id uuid,
  target_profile_id uuid,
  action text,
  metadata jsonb,
  created_at timestamptz,
  total_count bigint
)
language plpgsql
security definer
as $$
declare
  total_records bigint;
  valid_order_columns text[] := array['created_at', 'action', 'actor_profile_id', 'target_profile_id'];
  valid_directions text[] := array['ASC', 'DESC'];
  final_query text;
begin
  -- Validate order_by column
  if not (order_by = any(valid_order_columns)) then
    order_by := 'created_at';
  end if;
  
  -- Validate order direction
  if not (upper(order_direction) = any(valid_directions)) then
    order_direction := 'DESC';
  end if;
  
  -- Validate limit and offset
  if limit_count < 1 or limit_count > 1000 then
    limit_count := 50;
  end if;
  
  if offset_count < 0 then
    offset_count := 0;
  end if;
  
  -- Get total count first
  select count(*)
  into total_records
  from audit_logs al
  where 
    (target_country_id is null or (al.metadata ->> 'country_id')::uuid = target_country_id)
    and (search_action is null or al.action ilike '%' || search_action || '%')
    and (search_metadata is null or al.metadata @> search_metadata);
  
  -- Build and execute the main query
  return query execute format('
    select 
      al.id,
      al.actor_profile_id,
      al.target_profile_id,
      al.action,
      al.metadata,
      al.created_at,
      $1::bigint as total_count
    from audit_logs al
    where 
      ($2::uuid is null or (al.metadata ->> ''country_id'')::uuid = $2::uuid)
      and ($3::text is null or al.action ilike ''%%'' || $3 || ''%%'')
      and ($4::jsonb is null or al.metadata @> $4::jsonb)
    order by %I %s
    limit $5
    offset $6
  ', order_by, order_direction)
  using total_records, target_country_id, search_action, search_metadata, limit_count, offset_count;
end;
$$;

-- Function to search audit logs with advanced JSONB queries
create or replace function search_audit_logs_advanced(
  jsonb_path text default null,
  jsonb_value text default null,
  jsonb_operator text default '=',
  target_country_id uuid default null,
  date_from timestamptz default null,
  date_to timestamptz default null,
  limit_count integer default 50,
  offset_count integer default 0
)
returns table (
  id uuid,
  actor_profile_id uuid,
  target_profile_id uuid,
  action text,
  metadata jsonb,
  created_at timestamptz,
  total_count bigint
)
language plpgsql
security definer
as $$
declare
  total_records bigint;
  where_conditions text := 'true';
  count_query text;
  main_query text;
begin
  -- Validate limit and offset
  if limit_count < 1 or limit_count > 1000 then
    limit_count := 50;
  end if;
  
  if offset_count < 0 then
    offset_count := 0;
  end if;
  
  -- Build where conditions
  if target_country_id is not null then
    where_conditions := where_conditions || ' and (al.metadata ->> ''country_id'')::uuid = $1::uuid';
  end if;
  
  if date_from is not null then
    where_conditions := where_conditions || ' and al.created_at >= $2::timestamptz';
  end if;
  
  if date_to is not null then
    where_conditions := where_conditions || ' and al.created_at <= $3::timestamptz';
  end if;
  
  if jsonb_path is not null and jsonb_value is not null then
    case jsonb_operator
      when '=' then
        where_conditions := where_conditions || ' and al.metadata #>> $4::text[] = $5::text';
      when '!=' then
        where_conditions := where_conditions || ' and al.metadata #>> $4::text[] != $5::text';
      when 'like' then
        where_conditions := where_conditions || ' and al.metadata #>> $4::text[] ilike ''%'' || $5::text || ''%''';
      when 'exists' then
        where_conditions := where_conditions || ' and al.metadata ? $5::text';
      else
        where_conditions := where_conditions || ' and al.metadata #>> $4::text[] = $5::text';
    end case;
  end if;
  
  -- Get total count
  count_query := 'select count(*) from audit_logs al where ' || where_conditions;
  
  execute count_query
  into total_records
  using target_country_id, date_from, date_to, string_to_array(jsonb_path, '.'), jsonb_value;
  
  -- Build and execute main query
  main_query := '
    select 
      al.id,
      al.actor_profile_id,
      al.target_profile_id,
      al.action,
      al.metadata,
      al.created_at,
      $6::bigint as total_count
    from audit_logs al
    where ' || where_conditions || '
    order by al.created_at desc
    limit $7
    offset $8
  ';
  
  return query execute main_query
  using target_country_id, date_from, date_to, string_to_array(jsonb_path, '.'), jsonb_value, total_records, limit_count, offset_count;
end;
$$;

-- Function to get audit log statistics for a country
create or replace function get_audit_log_stats(target_country_id uuid default null)
returns table (
  total_logs bigint,
  unique_actions bigint,
  unique_actors bigint,
  logs_last_24h bigint,
  logs_last_7d bigint,
  logs_last_30d bigint,
  most_common_action text,
  most_active_actor uuid
)
language sql
security definer
as $$
with stats as (
  select 
    count(*) as total_logs,
    count(distinct action) as unique_actions,
    count(distinct actor_profile_id) as unique_actors,
    count(*) filter (where created_at >= now() - interval '24 hours') as logs_last_24h,
    count(*) filter (where created_at >= now() - interval '7 days') as logs_last_7d,
    count(*) filter (where created_at >= now() - interval '30 days') as logs_last_30d
  from audit_logs
  where target_country_id is null or (metadata ->> 'country_id')::uuid = target_country_id
),
most_common_action as (
  select action
  from audit_logs
  where target_country_id is null or (metadata ->> 'country_id')::uuid = target_country_id
  group by action
  order by count(*) desc
  limit 1
),
most_active_actor as (
  select actor_profile_id
  from audit_logs
  where target_country_id is null or (metadata ->> 'country_id')::uuid = target_country_id
    and actor_profile_id is not null
  group by actor_profile_id
  order by count(*) desc
  limit 1
)
select 
  s.total_logs,
  s.unique_actions,
  s.unique_actors,
  s.logs_last_24h,
  s.logs_last_7d,
  s.logs_last_30d,
  mca.action as most_common_action,
  maa.actor_profile_id as most_active_actor
from stats s
cross join most_common_action mca
cross join most_active_actor maa;
$$;

-- Create indexes for better performance
create index if not exists idx_audit_logs_country_id on audit_logs using gin ((metadata ->> 'country_id'));
create index if not exists idx_audit_logs_metadata_gin on audit_logs using gin (metadata);
create index if not exists idx_audit_logs_action on audit_logs (action);
create index if not exists idx_audit_logs_created_at on audit_logs (created_at desc);
create index if not exists idx_audit_logs_actor_profile_id on audit_logs (actor_profile_id);
create index if not exists idx_audit_logs_target_profile_id on audit_logs (target_profile_id);

-- Grant necessary permissions
grant execute on function get_audit_logs_for_country(uuid) to authenticated;
grant execute on function get_audit_logs_paginated(uuid, jsonb, text, integer, integer, text, text) to authenticated;
grant execute on function search_audit_logs_advanced(text, text, text, uuid, timestamptz, timestamptz, integer, integer) to authenticated;
grant execute on function get_audit_log_stats(uuid) to authenticated;