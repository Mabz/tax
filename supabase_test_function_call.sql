-- Test the exact function call that Flutter is making
SELECT create_pass_template(
    '8ac2d48f-9fec-4c1f-acbe-c234fa2e7615'::UUID,  -- target_authority_id
    'f029133e-39cf-4ac4-a04e-25f7b59ef604'::UUID,  -- creator_profile_id
    '02d4b3f7-b784-4c40-8078-4f0ad36d1590'::UUID,  -- vehicle_type_id
    'Bus pass any entry/exit points - GBP 0.00 per entry, 1 entries allowed, valid for 30 days, starts in 30 days', -- description
    1,                                              -- entry_limit
    30,                                             -- expiration_days
    30,                                             -- pass_advance_days
    0.00,                                           -- tax_amount
    'GBP',                                          -- currency_code
    NULL,                                           -- target_entry_point_id
    NULL,                                           -- target_exit_point_id
    FALSE                                           -- allow_user_selectable_points
) as result;