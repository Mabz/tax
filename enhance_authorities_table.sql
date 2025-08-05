-- Enhance authorities table with additional business logic fields
-- Adds pass advance booking days and default currency support

-- Add new columns to authorities table
ALTER TABLE public.authorities 
ADD COLUMN IF NOT EXISTS pass_advance_days integer DEFAULT 30,
ADD COLUMN IF NOT EXISTS default_currency_code text REFERENCES public.currencies(code);

-- Add comments for documentation
COMMENT ON COLUMN public.authorities.pass_advance_days IS 'Maximum number of days in advance that passes can be created for this authority';
COMMENT ON COLUMN public.authorities.default_currency_code IS 'Default currency code for this authority (references currencies table)';

-- Add constraints for data validation
ALTER TABLE public.authorities 
ADD CONSTRAINT check_pass_advance_days_positive 
CHECK (pass_advance_days > 0 AND pass_advance_days <= 365);

-- Add index for performance on currency lookups
CREATE INDEX IF NOT EXISTS idx_authorities_default_currency 
ON public.authorities(default_currency_code);

-- Update the authorities table structure comment
COMMENT ON TABLE public.authorities IS 'Governmental authorities within countries that can issue passes and manage borders. Each authority has specific business rules for pass creation and default currency.';

-- Example: Set reasonable defaults for existing authorities (optional)
-- UPDATE public.authorities 
-- SET 
--   pass_advance_days = CASE 
--     WHEN authority_type = 'global' THEN 90
--     WHEN authority_type = 'revenue_service' THEN 30
--     WHEN authority_type = 'customs' THEN 14
--     WHEN authority_type = 'immigration' THEN 60
--     ELSE 30
--   END,
--   default_currency_code = (
--     SELECT c.currency_code 
--     FROM countries c 
--     WHERE c.id = authorities.country_id
--   )
-- WHERE pass_advance_days IS NULL OR default_currency_code IS NULL;
