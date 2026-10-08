-- ====================================================================
-- EcoSort AI - Smart Waste Collection & Recycling Platform
-- Full PostgreSQL & Supabase Database Schema
-- Includes Core Differentiators:
--   0.1 Prediction-Driven Assignment & Pre-emptive Staffing
--   0.2 Verifiable Per-Item Chain of Custody & Traceability
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES (Extends Supabase Auth)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'collector', 'recycling_center', 'admin')),
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. WASTE CATEGORIES
CREATE TABLE IF NOT EXISTS waste_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT,
    disposal_instructions TEXT,
    recyclable BOOLEAN DEFAULT true NOT NULL,
    icon_type TEXT NOT NULL, -- 3d icon identifier: plastic, paper, glass, metal, organic, ewaste, textile, hazardous, mixed
    color_hex TEXT DEFAULT '#10b981' NOT NULL,
    points_multiplier NUMERIC(5,2) DEFAULT 10.00 NOT NULL,
    co2_savings_kg_per_kg NUMERIC(6,3) DEFAULT 1.250 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. USER ADDRESSES
CREATE TABLE IF NOT EXISTS user_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    label TEXT DEFAULT 'Home',
    address_line TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'Metropolis',
    zone TEXT NOT NULL DEFAULT 'Zone North',
    postal_code TEXT,
    lat NUMERIC(10, 7) NOT NULL DEFAULT 40.7128,
    lng NUMERIC(10, 7) NOT NULL DEFAULT -74.0060,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. AI PREDICTIONS (Original Scan)
CREATE TABLE IF NOT EXISTS ai_predictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    image_url TEXT,
    category_id UUID REFERENCES waste_categories(id) ON DELETE RESTRICT NOT NULL,
    confidence NUMERIC(5, 4) NOT NULL, -- e.g. 0.9425
    is_recyclable BOOLEAN NOT NULL DEFAULT true,
    model_version TEXT DEFAULT 'v1.4-mobilenet-ecosort',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. COLLECTORS
CREATE TABLE IF NOT EXISTS collectors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    vehicle_type TEXT DEFAULT 'Electric Van',
    vehicle_capacity_kg NUMERIC(8,2) DEFAULT 800.00 NOT NULL,
    current_load_kg NUMERIC(8,2) DEFAULT 0.00 NOT NULL,
    service_zones TEXT[] DEFAULT ARRAY['Zone North', 'Zone Central']::TEXT[],
    status TEXT DEFAULT 'available' CHECK (status IN ('available', 'busy', 'offline', 'on_break')),
    current_lat NUMERIC(10, 7) DEFAULT 40.7150,
    current_lng NUMERIC(10, 7) DEFAULT -74.0080,
    rating NUMERIC(3, 2) DEFAULT 4.90,
    completed_pickups_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. RECYCLING CENTERS
CREATE TABLE IF NOT EXISTS recycling_centers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    zone TEXT NOT NULL DEFAULT 'Zone North',
    lat NUMERIC(10, 7) NOT NULL DEFAULT 40.7300,
    lng NUMERIC(10, 7) NOT NULL DEFAULT -74.0150,
    daily_capacity_kg NUMERIC(10, 2) DEFAULT 5000.00 NOT NULL,
    current_intake_kg NUMERIC(10, 2) DEFAULT 0.00 NOT NULL,
    accepted_categories UUID[] DEFAULT ARRAY[]::UUID[],
    contact_phone TEXT,
    operating_hours TEXT DEFAULT 'Mon-Sat: 07:00 - 19:00',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. PICKUP REQUESTS (With link to ai_predictions.id for verifiable chain of custody)
CREATE TABLE IF NOT EXISTS pickup_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    address_id UUID REFERENCES user_addresses(id) ON DELETE SET NULL,
    category_id UUID REFERENCES waste_categories(id) ON DELETE RESTRICT NOT NULL,
    ai_prediction_id UUID REFERENCES ai_predictions(id) ON DELETE SET NULL, -- SECTION 0.2 TRACEABILITY
    estimated_weight_kg NUMERIC(6, 2) DEFAULT 3.50 NOT NULL,
    actual_weight_kg NUMERIC(6, 2), -- filled during collector verification
    pickup_date DATE NOT NULL,
    time_slot TEXT NOT NULL, -- e.g. "09:00 - 11:00"
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'assigned', 'on_the_way', 'arrived', 'collected', 'delivered', 'processed', 'cancelled'
    )),
    notes TEXT,
    item_photo_url TEXT,
    collector_id UUID REFERENCES collectors(id) ON DELETE SET NULL,
    recycling_center_id UUID REFERENCES recycling_centers(id) ON DELETE SET NULL,
    delay_risk_score NUMERIC(5, 4) DEFAULT 0.00, -- populated by delay model
    priority_level INT DEFAULT 0, -- elevated dynamically by delay risk (Section 0.1)
    scheduled_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. PICKUP STATUS HISTORY (Granular timestamps for SLA calculation & Chain of Custody)
CREATE TABLE IF NOT EXISTS pickup_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pickup_request_id UUID REFERENCES pickup_requests(id) ON DELETE CASCADE NOT NULL,
    status TEXT NOT NULL,
    collector_id UUID REFERENCES collectors(id) ON DELETE SET NULL,
    notes TEXT,
    lat NUMERIC(10, 7),
    lng NUMERIC(10, 7),
    weight_kg NUMERIC(6, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 9. AI PREDICTION CORRECTIONS (Section 0.1 & 0.2 feedback loop from collector verification)
CREATE TABLE IF NOT EXISTS ai_prediction_corrections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pickup_request_id UUID REFERENCES pickup_requests(id) ON DELETE CASCADE NOT NULL,
    ai_prediction_id UUID REFERENCES ai_predictions(id) ON DELETE CASCADE,
    original_category_id UUID REFERENCES waste_categories(id) NOT NULL,
    corrected_category_id UUID REFERENCES waste_categories(id) NOT NULL,
    collector_id UUID REFERENCES collectors(id) NOT NULL,
    correction_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. COLLECTOR ASSIGNMENTS & QUEUE RANKING (Section 0.1 re-ranked dynamically by delay risk)
CREATE TABLE IF NOT EXISTS collector_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pickup_request_id UUID REFERENCES pickup_requests(id) ON DELETE CASCADE NOT NULL,
    collector_id UUID REFERENCES collectors(id) ON DELETE CASCADE NOT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    queue_rank INT NOT NULL DEFAULT 1, -- dynamically re-ordered by Section 0.1
    delay_risk_score NUMERIC(5, 4) DEFAULT 0.00,
    override_by_admin BOOLEAN DEFAULT false,
    admin_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'reassigned', 'cancelled'))
);

-- 11. RECYCLING RECORDS (Section 0.2 Final disposition: Recycled vs. Rejected)
CREATE TABLE IF NOT EXISTS recycling_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pickup_request_id UUID REFERENCES pickup_requests(id) ON DELETE CASCADE NOT NULL,
    recycling_center_id UUID REFERENCES recycling_centers(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES waste_categories(id) NOT NULL,
    total_received_kg NUMERIC(8, 2) NOT NULL,
    recycled_weight_kg NUMERIC(8, 2) NOT NULL,
    rejected_weight_kg NUMERIC(8, 2) DEFAULT 0.00 NOT NULL,
    rejection_reason TEXT, -- e.g. "Contaminated with organic food oils", "Non-recyclable composite"
    processing_status TEXT DEFAULT 'completed' CHECK (processing_status IN ('processing', 'completed', 'quarantined')),
    processed_by_staff TEXT DEFAULT 'Operator #14',
    verified_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 12. COLLECTION CENTERS (Public Drop-Off Points)
CREATE TABLE IF NOT EXISTS collection_centers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    zone TEXT NOT NULL DEFAULT 'Zone North',
    lat NUMERIC(10, 7) NOT NULL,
    lng NUMERIC(10, 7) NOT NULL,
    accepted_categories TEXT[] DEFAULT ARRAY['Plastic', 'Glass', 'Paper', 'Metal']::TEXT[],
    operating_hours TEXT DEFAULT 'Mon-Sun: 08:00 - 20:00',
    contact_phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 13. ECO POINTS & REWARDS (Section 0.2 computed strictly from verified recycled weight)
CREATE TABLE IF NOT EXISTS eco_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
    current_balance INT DEFAULT 0 NOT NULL,
    lifetime_earned INT DEFAULT 0 NOT NULL,
    tier TEXT DEFAULT 'Eco Seed' CHECK (tier IN ('Eco Seed', 'Green Guardian', 'Zero Waste Champion', 'Planet Hero')),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS eco_point_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    pickup_request_id UUID REFERENCES pickup_requests(id) ON DELETE SET NULL,
    points INT NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('earned_pickup', 'bonus_streak', 'reward_redemption', 'adjustment')),
    description TEXT NOT NULL,
    verified_recycled_kg NUMERIC(6, 2), -- real weight from recycling_records
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 14. DELAY PREDICTIONS (Section 0.1)
CREATE TABLE IF NOT EXISTS delay_predictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pickup_request_id UUID REFERENCES pickup_requests(id) ON DELETE CASCADE NOT NULL,
    delay_risk_score NUMERIC(5, 4) NOT NULL, -- 0.0000 to 1.0000
    predicted_delay_minutes INT DEFAULT 0 NOT NULL,
    factors JSONB DEFAULT '{"traffic": "normal", "weather": "clear", "distance_km": 3.4}'::jsonb,
    is_actioned BOOLEAN DEFAULT false,
    action_type TEXT, -- e.g. "queue_reranked", "notified_collector"
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 15. DEMAND PREDICTIONS (Section 0.1)
CREATE TABLE IF NOT EXISTS demand_predictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone TEXT NOT NULL,
    target_date DATE NOT NULL,
    predicted_requests INT NOT NULL,
    predicted_volume_kg NUMERIC(10, 2) NOT NULL,
    capacity_utilization_pct NUMERIC(5, 2) NOT NULL,
    threshold_crossed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 16. STAFFING RECOMMENDATIONS (Section 0.1 Pre-emptive staffing alerts)
CREATE TABLE IF NOT EXISTS staffing_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone TEXT NOT NULL,
    target_date DATE NOT NULL,
    triggering_prediction_id UUID REFERENCES demand_predictions(id) ON DELETE CASCADE NOT NULL,
    recommended_collectors INT NOT NULL,
    current_scheduled_collectors INT NOT NULL,
    surge_multiplier NUMERIC(4, 2) DEFAULT 1.30,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'deployed', 'dismissed')),
    action_taken TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 17. ACTIVITY LOGS (Section 0.1 Full causal chain: prediction -> system action -> outcome)
CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action_type TEXT NOT NULL, -- e.g. 'delay_risk_queue_rerank', 'preemptive_staffing_flag', 'collector_assigned', 'ai_correction_logged'
    description TEXT NOT NULL,
    actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    actor_role TEXT DEFAULT 'system',
    triggering_prediction_id UUID, -- links back to delay_predictions.id or demand_predictions.id
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 18. NOTIFICATIONS
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info' CHECK (type IN ('info', 'alert', 'success', 'warning')),
    link_url TEXT,
    is_read BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ====================================================================
-- INDEXES FOR HIGH QUERY EFFICIENCY & TRACEABILITY
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_pickup_user ON pickup_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_pickup_status ON pickup_requests(status);
CREATE INDEX IF NOT EXISTS idx_pickup_ai_pred ON pickup_requests(ai_prediction_id);
CREATE INDEX IF NOT EXISTS idx_pickup_history_req ON pickup_status_history(pickup_request_id);
CREATE INDEX IF NOT EXISTS idx_recycling_records_req ON recycling_records(pickup_request_id);
CREATE INDEX IF NOT EXISTS idx_collector_assign_col ON collector_assignments(collector_id, queue_rank);
CREATE INDEX IF NOT EXISTS idx_activity_logs_pred ON activity_logs(triggering_prediction_id);
CREATE INDEX IF NOT EXISTS idx_staffing_rec_pred ON staffing_recommendations(triggering_prediction_id);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE pickup_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE recycling_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE eco_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE eco_point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_prediction_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE staffing_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pickup_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE eco_point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE waste_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE recycling_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE collectors ENABLE ROW LEVEL SECURITY;

-- Profiles: users read/update their own; admins manage all
CREATE POLICY "Users can read own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can manage own addresses" ON user_addresses;
CREATE POLICY "Users can manage own addresses" ON user_addresses
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own AI predictions" ON ai_predictions;
CREATE POLICY "Users can create own AI predictions" ON ai_predictions
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can view own AI predictions" ON ai_predictions;
CREATE POLICY "Users can view own AI predictions" ON ai_predictions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated users manage pickup history" ON pickup_status_history;
CREATE POLICY "Authenticated users manage pickup history" ON pickup_status_history
    FOR ALL USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users view own eco points" ON eco_points;
CREATE POLICY "Users view own eco points" ON eco_points
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users view own point transactions" ON eco_point_transactions;
CREATE POLICY "Users view own point transactions" ON eco_point_transactions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own notifications" ON notifications;
CREATE POLICY "Users view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users update own notifications" ON notifications;
CREATE POLICY "Users update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view waste categories" ON waste_categories;
CREATE POLICY "Anyone can view waste categories" ON waste_categories
    FOR SELECT USING (true);
DROP POLICY IF EXISTS "Anyone can view recycling centers" ON recycling_centers;
CREATE POLICY "Anyone can view recycling centers" ON recycling_centers
    FOR SELECT USING (true);
DROP POLICY IF EXISTS "Authenticated users view collectors" ON collectors;
CREATE POLICY "Authenticated users view collectors" ON collectors
    FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Authenticated users create recycling records" ON recycling_records;
CREATE POLICY "Authenticated users create recycling records" ON recycling_records
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "Authenticated users view recycling records" ON recycling_records;
CREATE POLICY "Authenticated users view recycling records" ON recycling_records
    FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Collectors update pickup requests" ON pickup_requests;
CREATE POLICY "Collectors update pickup requests" ON pickup_requests
    FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Pickup requests: users see their own; collectors see assigned; admin sees all
CREATE POLICY "Users see own pickup requests" ON pickup_requests
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own pickup requests" ON pickup_requests
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- AI Corrections: collectors insert, admins read
CREATE POLICY "Collectors insert AI corrections" ON ai_prediction_corrections
    FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM collectors WHERE user_id = auth.uid()));
CREATE POLICY "All authenticated users view corrections" ON ai_prediction_corrections
    FOR SELECT USING (true);

-- Staffing recommendations: writable by system/admin
CREATE POLICY "Authenticated view staffing recommendations" ON staffing_recommendations
    FOR SELECT USING (true);

-- Activity logs: authenticated view for auditing
CREATE POLICY "Authenticated view activity logs" ON activity_logs
    FOR SELECT USING (true);

-- ====================================================================
-- SEED DATA (9 Waste Categories + Sample Roles + Verified Impact Chain)
-- ====================================================================
INSERT INTO waste_categories (id, name, slug, description, disposal_instructions, recyclable, icon_type, color_hex, points_multiplier, co2_savings_kg_per_kg)
VALUES 
    ('11111111-1111-1111-1111-111111111101', 'Plastic', 'plastic', 'PET, HDPE, PP bottles, jugs, containers', 'Rinse food residue, flatten, keep caps on or separate as local guidelines specify.', true, 'plastic', '#10b981', 15.00, 1.820),
    ('11111111-1111-1111-1111-111111111102', 'Paper & Cardboard', 'paper', 'Newspaper, clean cardboard, office paper, magazines', 'Keep completely dry, flatten boxes, remove heavy plastic tape.', true, 'paper', '#3b82f6', 10.00, 0.950),
    ('11111111-1111-1111-1111-111111111103', 'Glass', 'glass', 'Clear, amber, and green glass bottles and jars', 'Rinse clean, do not break, remove metal/plastic lids.', true, 'glass', '#06b6d4', 12.00, 0.315),
    ('11111111-1111-1111-1111-111111111104', 'Metal & Cans', 'metal', 'Aluminum cans, tin food cans, clean foil, scrap metal', 'Rinse thoroughly, crush cans to save space.', true, 'metal', '#f59e0b', 25.00, 4.100),
    ('11111111-1111-1111-1111-111111111105', 'Organic & Compost', 'organic', 'Fruit peels, vegetable trimmings, coffee grounds, garden clippings', 'Place in compostable bio-bin or brown paper bag, no plastic packaging.', true, 'organic', '#84cc16', 8.00, 0.600),
    ('11111111-1111-1111-1111-111111111106', 'E-Waste', 'ewaste', 'Smartphones, cables, circuit boards, batteries, appliances', 'Never toss in standard bins. Wrap lithium battery terminals with tape.', true, 'ewaste', '#8b5cf6', 40.00, 8.500),
    ('11111111-1111-1111-1111-111111111107', 'Textiles', 'textile', 'Clothing, footwear, bedsheets, dry scrap fabric', 'Clean, dry and tied in clear bag for fabric shredding or donation.', true, 'textile', '#ec4899', 18.00, 3.200),
    ('11111111-1111-1111-1111-111111111108', 'Hazardous', 'hazardous', 'Paints, solvents, automotive fluids, pesticides, mercury lamps', 'Must remain in sealed original containers with visible hazard warnings.', false, 'hazardous', '#ef4444', 5.00, 2.000),
    ('11111111-1111-1111-1111-111111111109', 'Mixed / Non-Recyclable', 'mixed', 'Composite wrappers, heavily soiled grease paper, ceramics', 'Minimize use, place in black general waste bin.', false, 'mixed', '#6b7280', 2.00, 0.100)
ON CONFLICT (id) DO NOTHING;

-- Seed Recycling Centers
INSERT INTO recycling_centers (id, name, address, zone, lat, lng, daily_capacity_kg, current_intake_kg, operating_hours)
VALUES
    ('22222222-2222-2222-2222-222222222201', 'EcoSort Hub Alpha - North Metro', '452 Industrial Parkway, Zone North', 'Zone North', 40.7320, -74.0180, 8000.00, 3420.00, 'Mon-Sat: 06:30 - 20:00'),
    ('22222222-2222-2222-2222-222222222202', 'Circular Materials Recovery Facility - Central', '180 Greenway Blvd, Zone Central', 'Zone Central', 40.7180, -74.0020, 12000.00, 6800.00, '24/7 Operations')
ON CONFLICT (id) DO NOTHING;

-- Seed Collection Centers (Drop-offs)
INSERT INTO collection_centers (name, address, zone, lat, lng, accepted_categories, operating_hours, contact_phone)
VALUES
    ('Downtown Green Drop-off Point', '124 Market Square, Zone Central', 'Zone Central', 40.7135, -74.0040, ARRAY['Plastic', 'Glass', 'Paper', 'Metal'], 'Mon-Sun: 07:00 - 21:00', '+1-555-0192'),
    ('Northside Community E-Waste Depot', '88 Highland Ave, Zone North', 'Zone North', 40.7350, -74.0120, ARRAY['E-Waste', 'Hazardous', 'Metal'], 'Tue-Sat: 09:00 - 17:00', '+1-555-0144'),
    ('East River Textile & Glass Pod', '210 Water Street, Zone East', 'Zone East', 40.7090, -73.9980, ARRAY['Textiles', 'Glass', 'Plastic'], '24/7 Access', '+1-555-0188');
