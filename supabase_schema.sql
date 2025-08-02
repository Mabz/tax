-- Create countries table
CREATE TABLE IF NOT EXISTS countries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code VARCHAR(3) UNIQUE NOT NULL, -- ISO 3166-1 alpha-3
    name VARCHAR(100) NOT NULL,
    full_name VARCHAR(200),
    currency_code VARCHAR(3), -- ISO 4217
    timezone VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create revenue_services table
CREATE TABLE IF NOT EXISTS revenue_services (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country_id UUID REFERENCES countries(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(200) NOT NULL,
    official_name VARCHAR(300),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    website_url VARCHAR(500),
    headquarters_address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(country_id) -- One revenue service per country
);

-- Create borders table
CREATE TABLE IF NOT EXISTS borders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country_id UUID REFERENCES countries(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(200) NOT NULL,
    border_type VARCHAR(50) NOT NULL CHECK (border_type IN ('land', 'sea', 'air')),
    neighboring_country_id UUID REFERENCES countries(id),
    location_coordinates POINT, -- Geographic coordinates
    operating_hours TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create vehicle_types table
CREATE TABLE IF NOT EXISTS vehicle_types (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('personal', 'commercial', 'public_transport', 'emergency', 'diplomatic')),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create tax_rates table
CREATE TABLE IF NOT EXISTS tax_rates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country_id UUID REFERENCES countries(id) ON DELETE CASCADE NOT NULL,
    vehicle_type_id UUID REFERENCES vehicle_types(id) ON DELETE CASCADE NOT NULL,
    rate_name VARCHAR(200) NOT NULL,
    base_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    currency_code VARCHAR(3) NOT NULL,
    rate_type VARCHAR(50) NOT NULL CHECK (rate_type IN ('fixed', 'percentage', 'per_day', 'per_km')),
    percentage_rate DECIMAL(5,2), -- For percentage-based rates
    minimum_amount DECIMAL(10,2),
    maximum_amount DECIMAL(10,2),
    effective_from DATE NOT NULL,
    effective_until DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(country_id, vehicle_type_id, effective_from) -- Prevent duplicate rates for same period
);

-- Create roles table to define available roles
CREATE TABLE IF NOT EXISTS roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    requires_country BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Insert default countries
INSERT INTO countries (code, name, full_name, currency_code, timezone) VALUES
    ('USA', 'United States', 'United States of America', 'USD', 'America/New_York'),
    ('CAN', 'Canada', 'Canada', 'CAD', 'America/Toronto'),
    ('MEX', 'Mexico', 'United Mexican States', 'MXN', 'America/Mexico_City'),
    ('GBR', 'United Kingdom', 'United Kingdom of Great Britain and Northern Ireland', 'GBP', 'Europe/London'),
    ('FRA', 'France', 'French Republic', 'EUR', 'Europe/Paris'),
    ('DEU', 'Germany', 'Federal Republic of Germany', 'EUR', 'Europe/Berlin'),
    ('JPN', 'Japan', 'Japan', 'JPY', 'Asia/Tokyo'),
    ('AUS', 'Australia', 'Commonwealth of Australia', 'AUD', 'Australia/Sydney'),
    ('BRA', 'Brazil', 'Federative Republic of Brazil', 'BRL', 'America/Sao_Paulo'),
    ('IND', 'India', 'Republic of India', 'INR', 'Asia/Kolkata')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    full_name = EXCLUDED.full_name,
    currency_code = EXCLUDED.currency_code,
    timezone = EXCLUDED.timezone,
    updated_at = NOW();

-- Insert default vehicle types
INSERT INTO vehicle_types (name, category, description) VALUES
    ('Car', 'personal', 'Standard passenger car'),
    ('Motorcycle', 'personal', 'Two-wheeled motor vehicle'),
    ('SUV', 'personal', 'Sport Utility Vehicle'),
    ('Truck', 'commercial', 'Commercial freight vehicle'),
    ('Van', 'commercial', 'Commercial delivery vehicle'),
    ('Bus', 'public_transport', 'Public passenger transport'),
    ('Taxi', 'public_transport', 'Licensed passenger transport'),
    ('Ambulance', 'emergency', 'Emergency medical vehicle'),
    ('Fire Truck', 'emergency', 'Emergency fire service vehicle'),
    ('Police Car', 'emergency', 'Law enforcement vehicle'),
    ('Diplomatic Vehicle', 'diplomatic', 'Official diplomatic transport')
ON CONFLICT DO NOTHING;

-- Create user_vehicles table
CREATE TABLE IF NOT EXISTS user_vehicles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    vehicle_type_id UUID REFERENCES vehicle_types(id) ON DELETE RESTRICT NOT NULL,
    license_plate VARCHAR(20) NOT NULL,
    vin_number VARCHAR(17), -- Vehicle Identification Number (17 characters standard)
    make VARCHAR(100),
    model VARCHAR(100),
    year INTEGER,
    color VARCHAR(50),
    description TEXT,
    registration_country_id UUID REFERENCES countries(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, license_plate, registration_country_id) -- Prevent duplicate plates per user per country
);

-- Create country_bank_accounts table
CREATE TABLE IF NOT EXISTS country_bank_accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country_id UUID REFERENCES countries(id) ON DELETE CASCADE NOT NULL,
    account_name VARCHAR(200) NOT NULL,
    bank_name VARCHAR(200) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    routing_number VARCHAR(50),
    swift_code VARCHAR(11),
    iban VARCHAR(34),
    currency_code VARCHAR(3) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create pass_templates table
CREATE TABLE IF NOT EXISTS pass_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country_id UUID REFERENCES countries(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    base_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    currency_code VARCHAR(3) NOT NULL,
    entry_limit INTEGER, -- NULL means unlimited entries
    validity_days INTEGER NOT NULL, -- How many days the pass is valid
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create pass_template_vehicle_types junction table
CREATE TABLE IF NOT EXISTS pass_template_vehicle_types (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pass_template_id UUID REFERENCES pass_templates(id) ON DELETE CASCADE NOT NULL,
    vehicle_type_id UUID REFERENCES vehicle_types(id) ON DELETE CASCADE NOT NULL,
    additional_fee DECIMAL(10,2) DEFAULT 0.00, -- Extra fee for this vehicle type
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(pass_template_id, vehicle_type_id)
);

-- Create user_passes table (purchased passes)
CREATE TABLE IF NOT EXISTS user_passes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    pass_template_id UUID REFERENCES pass_templates(id) ON DELETE RESTRICT NOT NULL,
    vehicle_id UUID REFERENCES user_vehicles(id) ON DELETE RESTRICT NOT NULL,
    qr_code VARCHAR(500) UNIQUE NOT NULL, -- QR code data for scanning
    total_amount_paid DECIMAL(10,2) NOT NULL,
    currency_code VARCHAR(3) NOT NULL,
    entries_used INTEGER DEFAULT 0,
    entries_limit INTEGER, -- Copied from template at purchase time
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
    payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    is_active BOOLEAN DEFAULT TRUE,
    purchased_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create payments table
CREATE TABLE IF NOT EXISTS payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_pass_id UUID REFERENCES user_passes(id) ON DELETE RESTRICT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    country_bank_account_id UUID REFERENCES country_bank_accounts(id) ON DELETE RESTRICT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency_code VARCHAR(3) NOT NULL,
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('credit_card', 'debit_card', 'bank_transfer', 'mobile_payment', 'cash')),
    payment_reference VARCHAR(200), -- External payment system reference
    payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded')),
    payment_date TIMESTAMP WITH TIME ZONE,
    failure_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create pass_usage_log table (for tracking entries)
CREATE TABLE IF NOT EXISTS pass_usage_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_pass_id UUID REFERENCES user_passes(id) ON DELETE CASCADE NOT NULL,
    border_id UUID REFERENCES borders(id) ON DELETE RESTRICT NOT NULL,
    scanned_by UUID REFERENCES auth.users(id), -- Local authority or customs official who scanned
    entry_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    exit_timestamp TIMESTAMP WITH TIME ZONE,
    scan_result VARCHAR(50) DEFAULT 'valid' CHECK (scan_result IN ('valid', 'expired', 'limit_exceeded', 'invalid', 'blocked')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Insert default roles (including new local_authority role)
INSERT INTO roles (name, display_name, description, requires_country) VALUES
    ('traveller', 'Traveller', 'Regular traveller crossing borders', FALSE),
    ('customs_official', 'Customs Official', 'Official processing border crossings', TRUE),
    ('country_admin', 'Country Administrator', 'Administrator managing country-specific settings', TRUE),
    ('local_authority', 'Local Authority', 'Local official who can scan and validate passes', TRUE),
    ('superuser', 'Superuser', 'System administrator with full access', FALSE)
ON CONFLICT (name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    requires_country = EXCLUDED.requires_country,
    updated_at = NOW();

-- Create user_roles junction table for many-to-many relationship
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role_id UUID REFERENCES roles(id) ON DELETE CASCADE NOT NULL,
    country_id UUID REFERENCES countries(id) ON DELETE CASCADE, -- Required for country-specific roles
    assigned_by UUID REFERENCES auth.users(id), -- Who assigned this role
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE, -- Optional expiration
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, role_id, country_id) -- Prevent duplicate role assignments for same country
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_countries_code ON countries(code);
CREATE INDEX IF NOT EXISTS idx_countries_active ON countries(is_active);
CREATE INDEX IF NOT EXISTS idx_revenue_services_country_id ON revenue_services(country_id);
CREATE INDEX IF NOT EXISTS idx_borders_country_id ON borders(country_id);
CREATE INDEX IF NOT EXISTS idx_borders_neighboring_country ON borders(neighboring_country_id);
CREATE INDEX IF NOT EXISTS idx_borders_type ON borders(border_type);
CREATE INDEX IF NOT EXISTS idx_tax_rates_country_id ON tax_rates(country_id);
CREATE INDEX IF NOT EXISTS idx_tax_rates_vehicle_type ON tax_rates(vehicle_type_id);
CREATE INDEX IF NOT EXISTS idx_tax_rates_effective_dates ON tax_rates(effective_from, effective_until);
CREATE INDEX IF NOT EXISTS idx_tax_rates_active ON tax_rates(is_active);
CREATE INDEX IF NOT EXISTS idx_vehicle_types_category ON vehicle_types(category);
CREATE INDEX IF NOT EXISTS idx_user_vehicles_user_id ON user_vehicles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_vehicles_license_plate ON user_vehicles(license_plate);
CREATE INDEX IF NOT EXISTS idx_user_vehicles_vin ON user_vehicles(vin_number);
CREATE INDEX IF NOT EXISTS idx_country_bank_accounts_country_id ON country_bank_accounts(country_id);
CREATE INDEX IF NOT EXISTS idx_country_bank_accounts_primary ON country_bank_accounts(is_primary);
CREATE INDEX IF NOT EXISTS idx_pass_templates_country_id ON pass_templates(country_id);
CREATE INDEX IF NOT EXISTS idx_pass_templates_active ON pass_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_pass_template_vehicle_types_template ON pass_template_vehicle_types(pass_template_id);
CREATE INDEX IF NOT EXISTS idx_pass_template_vehicle_types_vehicle ON pass_template_vehicle_types(vehicle_type_id);
CREATE INDEX IF NOT EXISTS idx_user_passes_user_id ON user_passes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_passes_template_id ON user_passes(pass_template_id);
CREATE INDEX IF NOT EXISTS idx_user_passes_vehicle_id ON user_passes(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_user_passes_qr_code ON user_passes(qr_code);
CREATE INDEX IF NOT EXISTS idx_user_passes_validity ON user_passes(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_user_passes_status ON user_passes(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_user_pass_id ON payments(user_pass_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_pass_usage_log_user_pass_id ON pass_usage_log(user_pass_id);
CREATE INDEX IF NOT EXISTS idx_pass_usage_log_border_id ON pass_usage_log(border_id);
CREATE INDEX IF NOT EXISTS idx_pass_usage_log_scanned_by ON pass_usage_log(scanned_by);
CREATE INDEX IF NOT EXISTS idx_pass_usage_log_timestamp ON pass_usage_log(entry_timestamp);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_country_id ON user_roles(country_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_active ON user_roles(is_active);
CREATE INDEX IF NOT EXISTS idx_user_roles_expires_at ON user_roles(expires_at);
CREATE INDEX IF NOT EXISTS idx_roles_name ON roles(name);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Create users table to store additional user information
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    email TEXT UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert into users table
    INSERT INTO public.users (id, full_name, email, created_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'),
        NEW.email,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = COALESCE(EXCLUDED.full_name, users.full_name),
        email = EXCLUDED.email,
        updated_at = NOW();
    
    -- Assign default 'traveller' role
    INSERT INTO public.user_roles (user_id, role_id, country_id, assigned_at)
    SELECT 
        NEW.id,
        r.id,
        NULL,  -- country_id is NULL for traveller role
        NOW()
    FROM roles r
    WHERE r.name = 'traveller'
    ON CONFLICT (user_id, role_id, country_id) DO NOTHING;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't fail the signup process
        RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically handle new user signups
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Create function to get user role information
CREATE OR REPLACE FUNCTION get_user_roles(user_uuid UUID DEFAULT auth.uid())
RETURNS TABLE (
    role_name TEXT,
    role_display_name TEXT,
    country_code TEXT,
    country_name TEXT,
    requires_country BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.name,
        r.display_name,
        c.code,
        c.name,
        r.requires_country
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    LEFT JOIN countries c ON ur.country_id = c.id
    WHERE ur.user_id = user_uuid
    AND ur.is_active = TRUE
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable Row Level Security
ALTER TABLE countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE revenue_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE borders ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE country_bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE pass_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE pass_template_vehicle_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_passes ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE pass_usage_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policies for public reference tables (everyone can read)
CREATE POLICY "Anyone can read countries" ON countries
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Anyone can read vehicle types" ON vehicle_types
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Anyone can read roles" ON roles
    FOR SELECT USING (TRUE);

-- Create policies for revenue services (public information)
CREATE POLICY "Anyone can read active revenue services" ON revenue_services
    FOR SELECT USING (is_active = TRUE);

-- Create policies for borders (public information)
CREATE POLICY "Anyone can read active borders" ON borders
    FOR SELECT USING (is_active = TRUE);

-- Create policies for tax rates (public information)
CREATE POLICY "Anyone can read active tax rates" ON tax_rates
    FOR SELECT USING (
        is_active = TRUE 
        AND effective_from <= CURRENT_DATE 
        AND (effective_until IS NULL OR effective_until >= CURRENT_DATE)
    );

-- Create policies for users table
CREATE POLICY "Users can read their own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

-- Superusers can read all user profiles
CREATE POLICY "Superusers can read all user profiles" ON users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'superuser'
            AND ur.is_active = TRUE
        )
    );

-- Create policies for user_roles table

-- Users can read their own role assignments
CREATE POLICY "Users can read own role assignments" ON user_roles
    FOR SELECT USING (auth.uid() = user_id AND is_active = TRUE);

-- Users can insert their own roles (for initial setup only - traveller role)
CREATE POLICY "Users can insert own traveller role" ON user_roles
    FOR INSERT WITH CHECK (
        auth.uid() = user_id 
        AND role_id = (SELECT id FROM roles WHERE name = 'traveller')
        AND country_id IS NULL
    );

-- Superusers can read all role assignments
CREATE POLICY "Superusers can read all role assignments" ON user_roles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'superuser'
            AND ur.is_active = TRUE
        )
    );

-- Superusers can insert/update/delete all role assignments
CREATE POLICY "Superusers can manage all role assignments" ON user_roles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'superuser'
            AND ur.is_active = TRUE
        )
    );

-- Country admins can read role assignments for their country
CREATE POLICY "Country admins can read country role assignments" ON user_roles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.country_id = user_roles.country_id
            AND ur.is_active = TRUE
        )
    );

-- Country admins can manage role assignments for their country (except superuser)
CREATE POLICY "Country admins can manage country role assignments" ON user_roles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.country_id = user_roles.country_id
            AND ur.is_active = TRUE
        )
        AND role_id != (SELECT id FROM roles WHERE name = 'superuser')
    );

-- Superusers and country admins can manage their country's data
CREATE POLICY "Superusers can manage all revenue services" ON revenue_services
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'superuser'
            AND ur.is_active = TRUE
        )
    );

CREATE POLICY "Country admins can manage their revenue service" ON revenue_services
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.country_id = revenue_services.country_id
            AND ur.is_active = TRUE
        )
    );

-- Border management policies
CREATE POLICY "Superusers can manage all borders" ON borders
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'superuser'
            AND ur.is_active = TRUE
        )
    );

CREATE POLICY "Country admins can manage their borders" ON borders
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.country_id = borders.country_id
            AND ur.is_active = TRUE
        )
    );

-- Tax rate management policies
CREATE POLICY "Superusers can manage all tax rates" ON tax_rates
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'superuser'
            AND ur.is_active = TRUE
        )
    );

CREATE POLICY "Country admins can manage their tax rates" ON tax_rates
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.country_id = tax_rates.country_id
            AND ur.is_active = TRUE
        )
    );

-- User vehicles policies
CREATE POLICY "Users can manage their own vehicles" ON user_vehicles
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Country admins can view vehicles in their country" ON user_vehicles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name IN ('country_admin', 'customs_official', 'local_authority')
            AND ur.country_id = user_vehicles.registration_country_id
            AND ur.is_active = TRUE
        )
    );

-- Country bank accounts policies
CREATE POLICY "Country admins can manage their bank accounts" ON country_bank_accounts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.country_id = country_bank_accounts.country_id
            AND ur.is_active = TRUE
        )
    );

CREATE POLICY "Superusers can manage all bank accounts" ON country_bank_accounts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'superuser'
            AND ur.is_active = TRUE
        )
    );

-- Pass templates policies
CREATE POLICY "Anyone can read active pass templates" ON pass_templates
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Country admins can manage their pass templates" ON pass_templates
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.country_id = pass_templates.country_id
            AND ur.is_active = TRUE
        )
    );

-- Pass template vehicle types policies
CREATE POLICY "Anyone can read pass template vehicle types" ON pass_template_vehicle_types
    FOR SELECT USING (TRUE);

CREATE POLICY "Country admins can manage their pass template vehicle types" ON pass_template_vehicle_types
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM pass_templates pt
            JOIN user_roles ur ON pt.country_id = ur.country_id
            JOIN roles r ON ur.role_id = r.id
            WHERE pt.id = pass_template_vehicle_types.pass_template_id
            AND ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.is_active = TRUE
        )
    );

-- User passes policies
CREATE POLICY "Users can manage their own passes" ON user_passes
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Country officials can view passes for their country" ON user_passes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM pass_templates pt
            JOIN user_roles ur ON pt.country_id = ur.country_id
            JOIN roles r ON ur.role_id = r.id
            WHERE pt.id = user_passes.pass_template_id
            AND ur.user_id = auth.uid() 
            AND r.name IN ('country_admin', 'customs_official', 'local_authority')
            AND ur.is_active = TRUE
        )
    );

-- Payments policies
CREATE POLICY "Users can view their own payments" ON payments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Country admins can view payments to their accounts" ON payments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM country_bank_accounts cba
            JOIN user_roles ur ON cba.country_id = ur.country_id
            JOIN roles r ON ur.role_id = r.id
            WHERE cba.id = payments.country_bank_account_id
            AND ur.user_id = auth.uid() 
            AND r.name = 'country_admin'
            AND ur.is_active = TRUE
        )
    );

-- Pass usage log policies
CREATE POLICY "Users can view their own pass usage" ON pass_usage_log
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_passes up
            WHERE up.id = pass_usage_log.user_pass_id
            AND up.user_id = auth.uid()
        )
    );

CREATE POLICY "Officials can view and create usage logs for their borders" ON pass_usage_log
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM borders b
            JOIN user_roles ur ON b.country_id = ur.country_id
            JOIN roles r ON ur.role_id = r.id
            WHERE b.id = pass_usage_log.border_id
            AND ur.user_id = auth.uid() 
            AND r.name IN ('country_admin', 'customs_official', 'local_authority')
            AND ur.is_active = TRUE
        )
    );

-- Function to automatically assign traveller role when a user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    traveller_role_id UUID;
BEGIN
    -- Get the traveller role ID
    SELECT id INTO traveller_role_id FROM roles WHERE name = 'traveller';
    
    -- Insert the default traveller role for the new user
    INSERT INTO user_roles (user_id, role_id, assigned_at, created_at, updated_at)
    VALUES (NEW.id, traveller_role_id, NOW(), NOW(), NOW());
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function when a new user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_user_roles_updated_at ON user_roles;
CREATE TRIGGER update_user_roles_updated_at
    BEFORE UPDATE ON user_roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();



-- Helper function to assign role to user
CREATE OR REPLACE FUNCTION assign_role_to_user(
    p_user_id UUID,
    p_role_name TEXT,
    p_country_code TEXT DEFAULT NULL,
    p_assigned_by UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    role_record RECORD;
    country_id_val UUID;
BEGIN
    -- Get role information
    SELECT id, requires_country INTO role_record 
    FROM roles WHERE name = p_role_name;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Role % not found', p_role_name;
    END IF;
    
    -- Get country ID if country code is provided
    IF p_country_code IS NOT NULL THEN
        SELECT id INTO country_id_val FROM countries WHERE code = p_country_code;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Country % not found', p_country_code;
        END IF;
    END IF;
    
    -- Check if country is required but not provided
    IF role_record.requires_country AND country_id_val IS NULL THEN
        RAISE EXCEPTION 'Country is required for role %', p_role_name;
    END IF;
    
    -- Insert the role assignment
    INSERT INTO user_roles (user_id, role_id, country_id, assigned_by, assigned_at, created_at, updated_at)
    VALUES (p_user_id, role_record.id, country_id_val, p_assigned_by, NOW(), NOW(), NOW())
    ON CONFLICT (user_id, role_id, country_id) 
    DO UPDATE SET 
        is_active = TRUE,
        assigned_by = p_assigned_by,
        assigned_at = NOW(),
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to remove role from user
CREATE OR REPLACE FUNCTION remove_role_from_user(
    p_user_id UUID,
    p_role_name TEXT,
    p_country_code TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    role_id_val UUID;
    country_id_val UUID;
BEGIN
    -- Get role ID
    SELECT id INTO role_id_val FROM roles WHERE name = p_role_name;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Role % not found', p_role_name;
    END IF;
    
    -- Get country ID if country code is provided
    IF p_country_code IS NOT NULL THEN
        SELECT id INTO country_id_val FROM countries WHERE code = p_country_code;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Country % not found', p_country_code;
        END IF;
    END IF;
    
    -- Deactivate the role assignment
    UPDATE user_roles 
    SET is_active = FALSE, updated_at = NOW()
    WHERE user_id = p_user_id 
      AND role_id = role_id_val 
      AND (country_id_val IS NULL OR country_id = country_id_val);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current tax rate for a vehicle type in a country
CREATE OR REPLACE FUNCTION get_current_tax_rate(
    p_country_code TEXT,
    p_vehicle_type_name TEXT
)
RETURNS TABLE (
    rate_id UUID,
    rate_name TEXT,
    base_amount DECIMAL,
    currency_code TEXT,
    rate_type TEXT,
    percentage_rate DECIMAL,
    minimum_amount DECIMAL,
    maximum_amount DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tr.id,
        tr.rate_name,
        tr.base_amount,
        tr.currency_code,
        tr.rate_type,
        tr.percentage_rate,
        tr.minimum_amount,
        tr.maximum_amount
    FROM tax_rates tr
    JOIN countries c ON tr.country_id = c.id
    JOIN vehicle_types vt ON tr.vehicle_type_id = vt.id
    WHERE c.code = p_country_code
      AND vt.name = p_vehicle_type_name
      AND tr.is_active = TRUE
      AND tr.effective_from <= CURRENT_DATE
      AND (tr.effective_until IS NULL OR tr.effective_until >= CURRENT_DATE)
    ORDER BY tr.effective_from DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to calculate pass total cost
CREATE OR REPLACE FUNCTION calculate_pass_cost(
    p_pass_template_id UUID,
    p_vehicle_type_id UUID
)
RETURNS DECIMAL AS $$
DECLARE
    base_fee DECIMAL;
    additional_fee DECIMAL;
    total_cost DECIMAL;
BEGIN
    -- Get base fee from pass template
    SELECT pt.base_fee INTO base_fee
    FROM pass_templates pt
    WHERE pt.id = p_pass_template_id AND pt.is_active = TRUE;
    
    IF base_fee IS NULL THEN
        RAISE EXCEPTION 'Pass template not found or inactive';
    END IF;
    
    -- Get additional fee for vehicle type
    SELECT COALESCE(ptvt.additional_fee, 0) INTO additional_fee
    FROM pass_template_vehicle_types ptvt
    WHERE ptvt.pass_template_id = p_pass_template_id 
      AND ptvt.vehicle_type_id = p_vehicle_type_id;
    
    IF additional_fee IS NULL THEN
        RAISE EXCEPTION 'Vehicle type not allowed for this pass template';
    END IF;
    
    total_cost := base_fee + additional_fee;
    RETURN total_cost;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to validate QR code and get pass details
CREATE OR REPLACE FUNCTION validate_qr_code(p_qr_code TEXT)
RETURNS TABLE (
    pass_id UUID,
    user_id UUID,
    vehicle_license_plate TEXT,
    vehicle_make TEXT,
    vehicle_model TEXT,
    pass_name TEXT,
    entries_used INTEGER,
    entries_limit INTEGER,
    valid_until TIMESTAMP WITH TIME ZONE,
    is_valid BOOLEAN,
    validation_message TEXT
) AS $$
DECLARE
    pass_record RECORD;
    validation_msg TEXT;
    is_pass_valid BOOLEAN;
BEGIN
    -- Get pass details
    SELECT 
        up.id,
        up.user_id,
        uv.license_plate,
        uv.make,
        uv.model,
        pt.name,
        up.entries_used,
        up.entries_limit,
        up.valid_until,
        up.is_active,
        up.payment_status
    INTO pass_record
    FROM user_passes up
    JOIN user_vehicles uv ON up.vehicle_id = uv.id
    JOIN pass_templates pt ON up.pass_template_id = pt.id
    WHERE up.qr_code = p_qr_code;
    
    IF NOT FOUND THEN
        validation_msg := 'Invalid QR code';
        is_pass_valid := FALSE;
    ELSIF pass_record.payment_status != 'completed' THEN
        validation_msg := 'Payment not completed';
        is_pass_valid := FALSE;
    ELSIF NOT pass_record.is_active THEN
        validation_msg := 'Pass is inactive';
        is_pass_valid := FALSE;
    ELSIF pass_record.valid_until < NOW() THEN
        validation_msg := 'Pass has expired';
        is_pass_valid := FALSE;
    ELSIF pass_record.entries_limit IS NOT NULL AND pass_record.entries_used >= pass_record.entries_limit THEN
        validation_msg := 'Entry limit exceeded';
        is_pass_valid := FALSE;
    ELSE
        validation_msg := 'Valid pass';
        is_pass_valid := TRUE;
    END IF;
    
    RETURN QUERY SELECT 
        pass_record.id,
        pass_record.user_id,
        pass_record.license_plate,
        pass_record.make,
        pass_record.model,
        pass_record.name,
        pass_record.entries_used,
        pass_record.entries_limit,
        pass_record.valid_until,
        is_pass_valid,
        validation_msg;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to record pass usage
CREATE OR REPLACE FUNCTION record_pass_usage(
    p_qr_code TEXT,
    p_border_id UUID,
    p_scanned_by UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    pass_id UUID;
    current_entries INTEGER;
BEGIN
    -- Validate the pass first
    SELECT up.id, up.entries_used INTO pass_id, current_entries
    FROM user_passes up
    WHERE up.qr_code = p_qr_code
      AND up.is_active = TRUE
      AND up.payment_status = 'completed'
      AND up.valid_until > NOW()
      AND (up.entries_limit IS NULL OR up.entries_used < up.entries_limit);
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired pass';
    END IF;
    
    -- Record the usage
    INSERT INTO pass_usage_log (user_pass_id, border_id, scanned_by, entry_timestamp, scan_result)
    VALUES (pass_id, p_border_id, p_scanned_by, NOW(), 'valid');
    
    -- Increment usage counter
    UPDATE user_passes 
    SET entries_used = entries_used + 1, updated_at = NOW()
    WHERE id = pass_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert sample revenue services
INSERT INTO revenue_services (country_id, name, official_name, contact_email, website_url) 
SELECT 
    c.id,
    CASE c.code
        WHEN 'USA' THEN 'IRS'
        WHEN 'CAN' THEN 'CRA'
        WHEN 'MEX' THEN 'SAT'
        WHEN 'GBR' THEN 'HMRC'
        WHEN 'FRA' THEN 'DGFiP'
        WHEN 'DEU' THEN 'Bundesfinanzministerium'
        WHEN 'JPN' THEN 'NTA'
        WHEN 'AUS' THEN 'ATO'
        WHEN 'BRA' THEN 'RFB'
        WHEN 'IND' THEN 'CBDT'
    END,
    CASE c.code
        WHEN 'USA' THEN 'Internal Revenue Service'
        WHEN 'CAN' THEN 'Canada Revenue Agency'
        WHEN 'MEX' THEN 'Servicio de Administración Tributaria'
        WHEN 'GBR' THEN 'HM Revenue and Customs'
        WHEN 'FRA' THEN 'Direction Générale des Finances Publiques'
        WHEN 'DEU' THEN 'Federal Ministry of Finance'
        WHEN 'JPN' THEN 'National Tax Agency'
        WHEN 'AUS' THEN 'Australian Taxation Office'
        WHEN 'BRA' THEN 'Receita Federal do Brasil'
        WHEN 'IND' THEN 'Central Board of Direct Taxes'
    END,
    CASE c.code
        WHEN 'USA' THEN 'contact@irs.gov'
        WHEN 'CAN' THEN 'contact@cra-arc.gc.ca'
        WHEN 'MEX' THEN 'contacto@sat.gob.mx'
        WHEN 'GBR' THEN 'contact@hmrc.gov.uk'
        WHEN 'FRA' THEN 'contact@dgfip.finances.gouv.fr'
        WHEN 'DEU' THEN 'contact@bundesfinanzministerium.de'
        WHEN 'JPN' THEN 'contact@nta.go.jp'
        WHEN 'AUS' THEN 'contact@ato.gov.au'
        WHEN 'BRA' THEN 'contato@rfb.gov.br'
        WHEN 'IND' THEN 'contact@cbdt.gov.in'
    END,
    CASE c.code
        WHEN 'USA' THEN 'https://www.irs.gov'
        WHEN 'CAN' THEN 'https://www.canada.ca/en/revenue-agency.html'
        WHEN 'MEX' THEN 'https://www.sat.gob.mx'
        WHEN 'GBR' THEN 'https://www.gov.uk/government/organisations/hm-revenue-customs'
        WHEN 'FRA' THEN 'https://www.impots.gouv.fr'
        WHEN 'DEU' THEN 'https://www.bundesfinanzministerium.de'
        WHEN 'JPN' THEN 'https://www.nta.go.jp'
        WHEN 'AUS' THEN 'https://www.ato.gov.au'
        WHEN 'BRA' THEN 'https://www.gov.br/receitafederal'
        WHEN 'IND' THEN 'https://www.incometax.gov.in'
    END
FROM countries c
ON CONFLICT (country_id) DO NOTHING;

-- Insert sample borders (focusing on major land borders)
INSERT INTO borders (country_id, name, border_type, neighboring_country_id) 
SELECT 
    c1.id,
    border_name,
    'land',
    c2.id
FROM (VALUES
    ('USA', 'Peace Arch Border Crossing', 'CAN'),
    ('USA', 'Rainbow Bridge', 'CAN'),
    ('USA', 'San Ysidro Port of Entry', 'MEX'),
    ('USA', 'Tijuana Border Crossing', 'MEX'),
    ('CAN', 'Peace Arch Border Crossing', 'USA'),
    ('CAN', 'Rainbow Bridge', 'USA'),
    ('MEX', 'San Ysidro Port of Entry', 'USA'),
    ('MEX', 'Tijuana Border Crossing', 'USA'),
    ('FRA', 'Calais Port', 'GBR'),
    ('GBR', 'Dover Port', 'FRA'),
    ('FRA', 'Strasbourg Border', 'DEU'),
    ('DEU', 'Strasbourg Border', 'FRA')
) AS border_data(country_code, border_name, neighbor_code)
JOIN countries c1 ON c1.code = border_data.country_code
JOIN countries c2 ON c2.code = border_data.neighbor_code
ON CONFLICT DO NOTHING;

-- Insert sample tax rates for different vehicle types
INSERT INTO tax_rates (country_id, vehicle_type_id, rate_name, base_amount, currency_code, rate_type, effective_from)
SELECT 
    c.id,
    vt.id,
    c.code || ' ' || vt.name || ' Border Tax',
    CASE 
        WHEN vt.category = 'personal' THEN 
            CASE c.code
                WHEN 'USA' THEN 25.00
                WHEN 'CAN' THEN 30.00
                WHEN 'MEX' THEN 15.00
                WHEN 'GBR' THEN 20.00
                WHEN 'FRA' THEN 22.00
                WHEN 'DEU' THEN 25.00
                ELSE 20.00
            END
        WHEN vt.category = 'commercial' THEN
            CASE c.code
                WHEN 'USA' THEN 75.00
                WHEN 'CAN' THEN 85.00
                WHEN 'MEX' THEN 45.00
                WHEN 'GBR' THEN 65.00
                WHEN 'FRA' THEN 70.00
                WHEN 'DEU' THEN 80.00
                ELSE 60.00
            END
        WHEN vt.category = 'public_transport' THEN
            CASE c.code
                WHEN 'USA' THEN 50.00
                WHEN 'CAN' THEN 55.00
                WHEN 'MEX' THEN 30.00
                WHEN 'GBR' THEN 45.00
                WHEN 'FRA' THEN 48.00
                WHEN 'DEU' THEN 52.00
                ELSE 40.00
            END
        WHEN vt.category = 'emergency' THEN 0.00
        WHEN vt.category = 'diplomatic' THEN 0.00
        ELSE 25.00
    END,
    c.currency_code,
    'fixed',
    CURRENT_DATE
FROM countries c
CROSS JOIN vehicle_types vt
WHERE c.is_active = TRUE AND vt.is_active = TRUE
ON CONFLICT (country_id, vehicle_type_id, effective_from) DO NOTHING;

-- Insert sample bank accounts for countries
INSERT INTO country_bank_accounts (country_id, account_name, bank_name, account_number, currency_code, is_primary)
SELECT 
    c.id,
    c.name || ' Revenue Service Account',
    CASE c.code
        WHEN 'USA' THEN 'Federal Reserve Bank'
        WHEN 'CAN' THEN 'Bank of Canada'
        WHEN 'MEX' THEN 'Banco de México'
        WHEN 'GBR' THEN 'Bank of England'
        WHEN 'FRA' THEN 'Banque de France'
        WHEN 'DEU' THEN 'Deutsche Bundesbank'
        WHEN 'JPN' THEN 'Bank of Japan'
        WHEN 'AUS' THEN 'Reserve Bank of Australia'
        WHEN 'BRA' THEN 'Banco Central do Brasil'
        WHEN 'IND' THEN 'Reserve Bank of India'
    END,
    CASE c.code
        WHEN 'USA' THEN '1234567890'
        WHEN 'CAN' THEN '2345678901'
        WHEN 'MEX' THEN '3456789012'
        WHEN 'GBR' THEN '4567890123'
        WHEN 'FRA' THEN '5678901234'
        WHEN 'DEU' THEN '6789012345'
        WHEN 'JPN' THEN '7890123456'
        WHEN 'AUS' THEN '8901234567'
        WHEN 'BRA' THEN '9012345678'
        WHEN 'IND' THEN '0123456789'
    END,
    c.currency_code,
    TRUE
FROM countries c
WHERE c.is_active = TRUE
ON CONFLICT DO NOTHING;

-- Insert sample pass templates
INSERT INTO pass_templates (country_id, name, description, base_fee, currency_code, entry_limit, validity_days)
SELECT 
    c.id,
    c.name || ' Tourist Pass',
    'Standard tourist vehicle pass for ' || c.name,
    CASE c.code
        WHEN 'USA' THEN 50.00
        WHEN 'CAN' THEN 60.00
        WHEN 'MEX' THEN 30.00
        WHEN 'GBR' THEN 45.00
        WHEN 'FRA' THEN 48.00
        WHEN 'DEU' THEN 52.00
        WHEN 'JPN' THEN 5500.00
        WHEN 'AUS' THEN 70.00
        WHEN 'BRA' THEN 120.00
        WHEN 'IND' THEN 2000.00
    END,
    c.currency_code,
    10, -- 10 entries allowed
    30  -- Valid for 30 days
FROM countries c
WHERE c.is_active = TRUE

UNION ALL

SELECT 
    c.id,
    c.name || ' Business Pass',
    'Commercial vehicle pass for ' || c.name,
    CASE c.code
        WHEN 'USA' THEN 150.00
        WHEN 'CAN' THEN 180.00
        WHEN 'MEX' THEN 90.00
        WHEN 'GBR' THEN 135.00
        WHEN 'FRA' THEN 144.00
        WHEN 'DEU' THEN 156.00
        WHEN 'JPN' THEN 16500.00
        WHEN 'AUS' THEN 210.00
        WHEN 'BRA' THEN 360.00
        WHEN 'IND' THEN 6000.00
    END,
    c.currency_code,
    NULL, -- Unlimited entries
    90    -- Valid for 90 days
FROM countries c
WHERE c.is_active = TRUE;

-- Link pass templates with vehicle types
INSERT INTO pass_template_vehicle_types (pass_template_id, vehicle_type_id, additional_fee)
SELECT 
    pt.id,
    vt.id,
    CASE 
        WHEN pt.name LIKE '%Tourist%' AND vt.category = 'personal' THEN 0.00
        WHEN pt.name LIKE '%Tourist%' AND vt.category = 'commercial' THEN 25.00
        WHEN pt.name LIKE '%Business%' AND vt.category = 'personal' THEN 0.00
        WHEN pt.name LIKE '%Business%' AND vt.category = 'commercial' THEN 0.00
        WHEN pt.name LIKE '%Business%' AND vt.category = 'public_transport' THEN 50.00
        ELSE 0.00
    END
FROM pass_templates pt
CROSS JOIN vehicle_types vt
WHERE (
    (pt.name LIKE '%Tourist%' AND vt.category IN ('personal', 'commercial')) OR
    (pt.name LIKE '%Business%' AND vt.category IN ('personal', 'commercial', 'public_transport'))
)
AND vt.is_active = TRUE
ON CONFLICT (pass_template_id, vehicle_type_id) DO NOTHING;

-- Insert a default superuser (replace with your actual user ID after first login)
-- You'll need to update this with your actual user ID after you first authenticate
-- SELECT assign_role_to_user('YOUR_USER_ID_HERE', 'superuser');

-- Table comments
COMMENT ON TABLE countries IS 'Master list of countries participating in the cross-border tax platform';
COMMENT ON TABLE revenue_services IS 'Revenue/tax collection agencies for each country';
COMMENT ON TABLE borders IS 'Border crossing points between countries';
COMMENT ON TABLE vehicle_types IS 'Types of vehicles that can cross borders';
COMMENT ON TABLE tax_rates IS 'Tax rates for different vehicle types by country';
COMMENT ON TABLE user_vehicles IS 'User-owned vehicles registered in the system';
COMMENT ON TABLE country_bank_accounts IS 'Bank accounts where payments are deposited for each country';
COMMENT ON TABLE pass_templates IS 'Pass templates defined by country administrators';
COMMENT ON TABLE pass_template_vehicle_types IS 'Junction table linking pass templates to allowed vehicle types';
COMMENT ON TABLE user_passes IS 'Purchased passes by users for specific vehicles (contains QR codes)';
COMMENT ON TABLE payments IS 'Payment transactions for purchased passes';
COMMENT ON TABLE pass_usage_log IS 'Log of pass scans and border crossings';
COMMENT ON TABLE roles IS 'Defines available roles in the cross-border tax platform';
COMMENT ON TABLE user_roles IS 'Junction table storing user role assignments with country-specific context';

-- Column comments
COMMENT ON COLUMN user_vehicles.vin_number IS 'Vehicle Identification Number (17 characters standard)';
COMMENT ON COLUMN user_vehicles.license_plate IS 'Vehicle license plate number';
COMMENT ON COLUMN pass_templates.entry_limit IS 'Maximum number of entries allowed (NULL for unlimited)';
COMMENT ON COLUMN pass_templates.validity_days IS 'Number of days the pass remains valid after purchase';
COMMENT ON COLUMN user_passes.qr_code IS 'Unique QR code for scanning at borders';
COMMENT ON COLUMN user_passes.entries_used IS 'Number of times this pass has been used for border crossing';
COMMENT ON COLUMN user_passes.entries_limit IS 'Maximum entries allowed (copied from template at purchase)';
COMMENT ON COLUMN payments.payment_method IS 'Method used for payment: credit_card, debit_card, bank_transfer, mobile_payment, cash';
COMMENT ON COLUMN pass_usage_log.scan_result IS 'Result of QR code scan: valid, expired, limit_exceeded, invalid, blocked';
COMMENT ON COLUMN user_roles.country_id IS 'Country assignment for country-specific roles';
COMMENT ON COLUMN user_roles.expires_at IS 'Optional expiration date for temporary role assignments';
COMMENT ON COLUMN user_roles.is_active IS 'Whether this role assignment is currently active';
COMMENT ON COLUMN tax_rates.rate_type IS 'Type of tax calculation: fixed, percentage, per_day, per_km';
COMMENT ON COLUMN tax_rates.effective_from IS 'Date when this tax rate becomes effective';
COMMENT ON COLUMN tax_rates.effective_until IS 'Date when this tax rate expires (NULL for indefinite)';
COMMENT ON COLUMN borders.border_type IS 'Type of border crossing: land, sea, air';
COMMENT ON COLUMN vehicle_types.category IS 'Vehicle category: personal, commercial, public_transport, emergency, diplomatic';

-- Create public.users table for public profile information
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL PRIMARY KEY,
    display_name TEXT,
    avatar_url TEXT,
    billing_address TEXT,
    payment_method TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

COMMENT ON TABLE public.users IS 'Public profile information for users, extending auth.users';

-- Create user_role_view for simplified role queries
CREATE OR REPLACE VIEW user_role_view AS
SELECT 
    u.id as user_id,
    u.full_name,
    u.email,
    COALESCE(
        ARRAY_AGG(
            DISTINCT r.name 
            ORDER BY r.name
        ) FILTER (WHERE r.name IS NOT NULL), 
        ARRAY[]::TEXT[]
    ) as roles,
    COALESCE(
        ARRAY_AGG(
            DISTINCT ur.country_code 
            ORDER BY ur.country_code
        ) FILTER (WHERE ur.country_code IS NOT NULL), 
        ARRAY[]::TEXT[]
    ) as country_codes,
    COUNT(ur.id) as role_count
FROM public.users u
LEFT JOIN user_roles ur ON u.id = ur.user_id AND ur.is_active = true
LEFT JOIN roles r ON ur.role_id = r.id
GROUP BY u.id, u.full_name, u.email;

COMMENT ON VIEW user_role_view IS 'Simplified view for querying user roles and country assignments';

-- Grant access to the view
GRANT SELECT ON user_role_view TO authenticated;

-- Enable RLS on the view
ALTER VIEW user_role_view SET (security_barrier = true);

-- Create RLS policy for the view
CREATE POLICY "Users can read their own role view" ON user_role_view
    FOR SELECT USING (
        auth.uid() = user_id OR
        EXISTS (
            SELECT 1 FROM user_roles ur 
            JOIN roles r ON ur.role_id = r.id
            WHERE ur.user_id = auth.uid() 
            AND r.name IN ('superuser', 'country_admin')
            AND ur.is_active = TRUE
        )
    );

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  traveller_role_id UUID;
BEGIN
  -- Insert into public.users
  INSERT INTO public.users (id, display_name, avatar_url)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'avatar_url');

  -- Get the ID of the 'traveller' role
  SELECT id INTO traveller_role_id FROM roles WHERE name = 'traveller';

  -- Insert into user_roles
  IF traveller_role_id IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role_id, is_active)
    VALUES (NEW.id, traveller_role_id, TRUE);
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger to call handle_new_user on new user signup
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

COMMENT ON TRIGGER on_auth_user_created ON auth.users IS 'When a new user signs up, create a public profile and assign the default traveller role.';