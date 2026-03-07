-- =============================================================================
-- HOA ASSISTANT PLATFORM — TEST SEED DATA
-- =============================================================================
-- Run AFTER schema_v2_production.sql
-- Creates realistic US-based test data covering ALL 25 tables
--
-- Data summary:
--   2 Property Management Companies
--   25 communities per PMC (50 total)
--   4 Property Managers + residents + staff
--   Documents, FAQs, Announcements, Emails per community
--   Knowledge chunks with placeholder embeddings
--   Widget configs, sessions, conversations with multi-turn messages
--   Tickets with comments, attachments, status history
--   Analytics, search logs, audit logs, AI suggested FAQs
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. COMPANIES (2 PMCs)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO companies (id, name, slug, email, phone, settings, subscription_tier, max_communities, max_documents_per_community)
VALUES
    (1, 'Pinnacle Property Group', 'pinnacle-property-group', 'admin@pinnaclepg.com', '(404) 555-0100',
     '{"branding": {"primaryColor": "#1a5276", "logo": "pinnacle-logo.png"}, "features": {"ticketing": true, "analytics": true}}',
     'professional', 50, 1000),
    (2, 'Coastal Management Solutions', 'coastal-management', 'hello@coastalmgmt.com', '(305) 555-0200',
     '{"branding": {"primaryColor": "#148f77", "logo": "coastal-logo.png"}, "features": {"ticketing": true, "analytics": true}}',
     'enterprise', 100, 2000);

SELECT setval('companies_id_seq', 2);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. COMMUNITIES (25 per PMC = 50 total)
--    Varied AI settings: models, temperatures, custom prompts
-- ─────────────────────────────────────────────────────────────────────────────

-- Helper arrays for varied settings
-- Models: gpt-4o, gpt-4o-mini, gpt-4-turbo
-- Temperatures: 0.1 to 0.7
-- Some have custom system prompts, some don't

-- ── Pinnacle Property Group Communities (1-25) ──────────────────────────────

INSERT INTO communities (id, company_id, name, slug, address, timezone, ai_system_prompt, ai_temperature, ai_model, welcome_message, settings)
VALUES
    -- Atlanta metro communities
    (1, 1, 'Buckhead Towers Condominiums', 'buckhead-towers', '3400 Peachtree Rd NE, Atlanta, GA 30326', 'America/New_York',
     'You are the AI assistant for Buckhead Towers, a luxury high-rise condominium in Buckhead, Atlanta. Be professional and concise. Refer residents to the concierge for in-person requests.',
     0.2, 'gpt-4o', 'Welcome to Buckhead Towers! How can I assist you today?',
     '{"units": 320, "type": "high-rise", "amenities": ["pool", "gym", "concierge", "rooftop"]}'),

    (2, 1, 'Peachtree Hills Village HOA', 'peachtree-hills', '2100 Peachtree Hills Ave NE, Atlanta, GA 30309', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Hello! How can I help you today?',
     '{"units": 185, "type": "townhome", "amenities": ["clubhouse", "playground", "walking-trails"]}'),

    (3, 1, 'Druid Hills Estates', 'druid-hills-estates', '1580 Ponce de Leon Ave, Atlanta, GA 30307', 'America/New_York',
     'You assist residents of Druid Hills Estates, a historic neighborhood in Atlanta. Many homes are on the National Register. Be mindful of architectural review requirements.',
     0.15, 'gpt-4o', 'Welcome to Druid Hills Estates. How may I help?',
     '{"units": 95, "type": "single-family", "amenities": ["tennis-courts", "garden"]}'),

    (4, 1, 'Sandy Springs Commons', 'sandy-springs-commons', '6500 Roswell Rd, Sandy Springs, GA 30328', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hi there! Ask me anything about Sandy Springs Commons.',
     '{"units": 240, "type": "mixed-use", "amenities": ["pool", "business-center", "dog-park"]}'),

    (5, 1, 'Marietta Square Lofts', 'marietta-square-lofts', '50 N Park Square NE, Marietta, GA 30060', 'America/New_York',
     NULL, 0.4, 'gpt-4o-mini', 'Welcome! How can I help you today?',
     '{"units": 80, "type": "loft", "amenities": ["rooftop-deck", "bike-storage"]}'),

    (6, 1, 'Alpharetta Meadows', 'alpharetta-meadows', '12000 Alpharetta Hwy, Alpharetta, GA 30009', 'America/New_York',
     'You are the friendly AI assistant for Alpharetta Meadows, a family-oriented suburban community. Focus on family-friendly language and community events.',
     0.35, 'gpt-4o', 'Hello! Welcome to Alpharetta Meadows. What can I do for you?',
     '{"units": 450, "type": "single-family", "amenities": ["pool", "playground", "soccer-field", "clubhouse"]}'),

    (7, 1, 'Kennesaw Ridge Townhomes', 'kennesaw-ridge', '1200 Ridge Rd, Kennesaw, GA 30144', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hi! How can I assist you today?',
     '{"units": 120, "type": "townhome", "amenities": ["pool", "gym"]}'),

    (8, 1, 'Decatur Park Place', 'decatur-park-place', '250 E Ponce de Leon Ave, Decatur, GA 30030', 'America/New_York',
     NULL, 0.25, 'gpt-4o', 'Welcome to Decatur Park Place!',
     '{"units": 160, "type": "condo", "amenities": ["courtyard", "grilling-area", "package-room"]}'),

    (9, 1, 'Roswell Creek Landing', 'roswell-creek', '800 Holcomb Bridge Rd, Roswell, GA 30076', 'America/New_York',
     'You help residents at Roswell Creek Landing, a waterfront community. Many questions relate to dock access and kayak storage.',
     0.2, 'gpt-4o', 'Hello! How can I help with your Roswell Creek Landing questions?',
     '{"units": 200, "type": "townhome", "amenities": ["dock", "kayak-storage", "pool", "nature-trail"]}'),

    (10, 1, 'Johns Creek Summit', 'johns-creek-summit', '10500 Medlock Bridge Rd, Johns Creek, GA 30097', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Welcome! What can I help you with?',
     '{"units": 310, "type": "single-family", "amenities": ["pool", "tennis", "clubhouse"]}'),

    (11, 1, 'Vinings Glen', 'vinings-glen', '3200 Paces Ferry Rd, Atlanta, GA 30339', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Hello from Vinings Glen!',
     '{"units": 175, "type": "condo", "amenities": ["pool", "fitness-center"]}'),

    (12, 1, 'Dunwoody Gates', 'dunwoody-gates', '4800 Ashford Dunwoody Rd, Dunwoody, GA 30338', 'America/New_York',
     NULL, 0.35, 'gpt-4o-mini', 'Hi! How can I assist you?',
     '{"units": 280, "type": "mixed-use", "amenities": ["pool", "playground", "walking-paths"]}'),

    (13, 1, 'Brookhaven Heights', 'brookhaven-heights', '1500 N Druid Hills Rd, Brookhaven, GA 30319', 'America/New_York',
     'You assist Brookhaven Heights residents. This is a new construction community — many questions are about punch-list items and builder warranties.',
     0.2, 'gpt-4o', 'Welcome to Brookhaven Heights! How can I help?',
     '{"units": 140, "type": "townhome", "amenities": ["pool", "dog-park", "fire-pit"]}'),

    (14, 1, 'Smyrna Village Green', 'smyrna-village-green', '2800 Atlanta Rd, Smyrna, GA 30080', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hello! Ask me anything about the community.',
     '{"units": 195, "type": "condo", "amenities": ["garden", "grilling-stations"]}'),

    (15, 1, 'Tucker Crossing', 'tucker-crossing', '4200 Lawrenceville Hwy, Tucker, GA 30084', 'America/New_York',
     NULL, 0.4, 'gpt-4o-mini', 'Welcome to Tucker Crossing!',
     '{"units": 110, "type": "townhome", "amenities": ["playground", "picnic-area"]}'),

    (16, 1, 'Woodstock Mill Creek', 'woodstock-mill-creek', '200 Arnold Mill Rd, Woodstock, GA 30188', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Hi there! How can I help?',
     '{"units": 380, "type": "single-family", "amenities": ["pool", "splash-pad", "basketball-court"]}'),

    (17, 1, 'Suwanee Station', 'suwanee-station', '330 Town Center Ave, Suwanee, GA 30024', 'America/New_York',
     NULL, 0.25, 'gpt-4o', 'Welcome to Suwanee Station!',
     '{"units": 220, "type": "mixed-use", "amenities": ["town-green", "amphitheater", "shops"]}'),

    (18, 1, 'Canton Arbors', 'canton-arbors', '150 Marietta Rd, Canton, GA 30114', 'America/New_York',
     NULL, 0.35, 'gpt-4o-mini', 'Hello! How can I assist?',
     '{"units": 165, "type": "townhome", "amenities": ["pool", "clubhouse"]}'),

    (19, 1, 'Cumming Lakeside', 'cumming-lakeside', '5000 Buford Hwy, Cumming, GA 30041', 'America/New_York',
     'You assist residents of Cumming Lakeside, a lakefront community on Lake Lanier. Common questions involve boat dock reservations and lake water levels.',
     0.2, 'gpt-4o', 'Welcome to Cumming Lakeside on beautiful Lake Lanier!',
     '{"units": 150, "type": "single-family", "amenities": ["boat-dock", "beach", "clubhouse", "fishing-pier"]}'),

    (20, 1, 'Lawrenceville Manor', 'lawrenceville-manor', '800 Duluth Hwy, Lawrenceville, GA 30043', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hi! What can I help with?',
     '{"units": 250, "type": "single-family", "amenities": ["pool", "playground"]}'),

    (21, 1, 'Duluth Parkview', 'duluth-parkview', '3400 Buford Hwy, Duluth, GA 30096', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Welcome!',
     '{"units": 190, "type": "condo", "amenities": ["gym", "courtyard"]}'),

    (22, 1, 'Norcross Green', 'norcross-green', '5500 Jimmy Carter Blvd, Norcross, GA 30093', 'America/New_York',
     NULL, 0.4, 'gpt-4o-mini', 'Hello! How can I help you today?',
     '{"units": 130, "type": "townhome", "amenities": ["pool"]}'),

    (23, 1, 'Peachtree City Landing', 'ptc-landing', '100 Kelly Dr, Peachtree City, GA 30269', 'America/New_York',
     'You help residents of Peachtree City Landing. This community has a unique golf cart path system — remind residents about golf cart registration requirements.',
     0.25, 'gpt-4o', 'Welcome to PTC Landing! How can I assist you?',
     '{"units": 340, "type": "single-family", "amenities": ["golf-cart-paths", "lake", "tennis", "pool"]}'),

    (24, 1, 'Fayetteville Oaks', 'fayetteville-oaks', '400 N Glynn St, Fayetteville, GA 30214', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hi! Ask me anything.',
     '{"units": 175, "type": "single-family", "amenities": ["playground", "walking-trail"]}'),

    (25, 1, 'Newnan Crossing', 'newnan-crossing', '600 Bullsboro Dr, Newnan, GA 30263', 'America/New_York',
     NULL, 0.35, 'gpt-4o-mini', 'Welcome to Newnan Crossing!',
     '{"units": 200, "type": "townhome", "amenities": ["pool", "clubhouse", "playground"]}');


-- ── Coastal Management Solutions Communities (26-50) ────────────────────────

INSERT INTO communities (id, company_id, name, slug, address, timezone, ai_system_prompt, ai_temperature, ai_model, welcome_message, settings)
VALUES
    -- South Florida communities
    (26, 2, 'Brickell Bay Residences', 'brickell-bay', '1200 Brickell Ave, Miami, FL 33131', 'America/New_York',
     'You are the AI concierge for Brickell Bay Residences, a luxury waterfront high-rise in Brickell, Miami. Many residents are international. Be prepared for questions in English and Spanish.',
     0.2, 'gpt-4o', 'Welcome to Brickell Bay! Bienvenido! How can I help?',
     '{"units": 550, "type": "high-rise", "amenities": ["infinity-pool", "spa", "valet", "marina", "concierge"]}'),

    (27, 2, 'Coconut Grove Villas', 'coconut-grove-villas', '3200 Main Hwy, Coconut Grove, FL 33133', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Hello from the Grove! How can I help?',
     '{"units": 90, "type": "villa", "amenities": ["pool", "tropical-garden", "bbq-area"]}'),

    (28, 2, 'Coral Gables Estates', 'coral-gables-estates', '1500 Alhambra Cir, Coral Gables, FL 33134', 'America/New_York',
     'You assist residents of Coral Gables Estates. This is a historic community with strict architectural guidelines. All exterior modifications must go through the Architectural Review Board.',
     0.15, 'gpt-4o', 'Welcome to Coral Gables Estates. How may I assist you?',
     '{"units": 65, "type": "single-family", "amenities": ["tennis-courts", "pool", "guard-gate"]}'),

    (29, 2, 'South Beach Palms', 'south-beach-palms', '800 Ocean Dr, Miami Beach, FL 33139', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hey! Welcome to South Beach Palms. What do you need?',
     '{"units": 180, "type": "condo", "amenities": ["beach-access", "pool", "cabanas"]}'),

    (30, 2, 'Aventura Waterways', 'aventura-waterways', '19500 Turnberry Way, Aventura, FL 33180', 'America/New_York',
     NULL, 0.25, 'gpt-4o', 'Welcome to Aventura Waterways!',
     '{"units": 420, "type": "high-rise", "amenities": ["pool", "gym", "tennis", "marina"]}'),

    (31, 2, 'Key Biscayne Shores', 'key-biscayne-shores', '300 Crandon Blvd, Key Biscayne, FL 33149', 'America/New_York',
     'You assist residents of Key Biscayne Shores. Hurricane preparedness is a frequent topic — be knowledgeable about storm shutters, evacuation routes, and building protocols.',
     0.2, 'gpt-4o', 'Aloha from Key Biscayne Shores! How can I help?',
     '{"units": 200, "type": "condo", "amenities": ["beach-club", "pool", "playground"]}'),

    (32, 2, 'Doral Palms Community', 'doral-palms', '8200 NW 36th St, Doral, FL 33166', 'America/New_York',
     NULL, 0.35, 'gpt-4o-mini', 'Hello! How can I assist you today?',
     '{"units": 350, "type": "single-family", "amenities": ["pool", "playground", "basketball-court"]}'),

    (33, 2, 'Ft. Lauderdale Harbor', 'ft-lauderdale-harbor', '2000 SE 17th St, Fort Lauderdale, FL 33316', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Welcome aboard! How can I help?',
     '{"units": 280, "type": "condo", "amenities": ["marina", "pool", "yacht-club"]}'),

    (34, 2, 'Pompano Surf Club', 'pompano-surf', '1000 N Ocean Blvd, Pompano Beach, FL 33062', 'America/New_York',
     NULL, 0.4, 'gpt-4o-mini', 'Hey there! What can I do for you?',
     '{"units": 150, "type": "condo", "amenities": ["beach-access", "surf-storage", "pool"]}'),

    (35, 2, 'Boca Raton Preserve', 'boca-raton-preserve', '5000 Town Center Cir, Boca Raton, FL 33486', 'America/New_York',
     NULL, 0.25, 'gpt-4o', 'Welcome to Boca Raton Preserve!',
     '{"units": 400, "type": "mixed-use", "amenities": ["pool", "spa", "golf-cart-paths", "dog-park"]}'),

    (36, 2, 'Delray Beach Gardens', 'delray-beach-gardens', '200 Atlantic Ave, Delray Beach, FL 33444', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hello from Delray Beach Gardens!',
     '{"units": 175, "type": "townhome", "amenities": ["pool", "community-garden"]}'),

    (37, 2, 'West Palm Harbor Club', 'west-palm-harbor', '400 Flagler Dr, West Palm Beach, FL 33401', 'America/New_York',
     'You assist members of West Palm Harbor Club. This is a 55+ active adult community. Be respectful and patient. Common topics: social calendar, medical transport, guest policies.',
     0.2, 'gpt-4o', 'Welcome to West Palm Harbor Club! How can I help you today?',
     '{"units": 500, "type": "55-plus", "amenities": ["golf-course", "pool", "ballroom", "library", "shuffleboard"]}'),

    (38, 2, 'Jupiter Inlet Cay', 'jupiter-inlet-cay', '1000 N US Hwy 1, Jupiter, FL 33477', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Hello! How can I help?',
     '{"units": 130, "type": "condo", "amenities": ["pool", "kayak-launch", "fishing-pier"]}'),

    (39, 2, 'Stuart Riverfront', 'stuart-riverfront', '50 SW Flagler Ave, Stuart, FL 34994', 'America/New_York',
     NULL, 0.35, 'gpt-4o-mini', 'Welcome to Stuart Riverfront!',
     '{"units": 100, "type": "townhome", "amenities": ["river-dock", "pool"]}'),

    (40, 2, 'Naples Bay Colony', 'naples-bay-colony', '8100 Bay Colony Dr, Naples, FL 34108', 'America/New_York',
     'You are the concierge assistant for Naples Bay Colony, an ultra-luxury gated community. Residents expect white-glove service. Be formal and attentive.',
     0.1, 'gpt-4o', 'Good day. Welcome to Naples Bay Colony. How may I be of service?',
     '{"units": 85, "type": "single-family", "amenities": ["private-beach", "golf-course", "spa", "tennis", "guard-gate"]}'),

    (41, 2, 'Marco Island Palms', 'marco-island-palms', '600 S Collier Blvd, Marco Island, FL 34145', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hello! How can I assist?',
     '{"units": 200, "type": "condo", "amenities": ["pool", "beach-access", "tiki-bar"]}'),

    (42, 2, 'Sarasota Bayfront', 'sarasota-bayfront', '1500 Main St, Sarasota, FL 34236', 'America/New_York',
     NULL, 0.25, 'gpt-4o', 'Welcome to Sarasota Bayfront!',
     '{"units": 260, "type": "high-rise", "amenities": ["pool", "bay-views", "gym", "concierge"]}'),

    (43, 2, 'Tampa Palms Crossing', 'tampa-palms-crossing', '15000 Amberly Dr, Tampa, FL 33647', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hi! What can I help with?',
     '{"units": 320, "type": "single-family", "amenities": ["pool", "splash-pad", "dog-park"]}'),

    (44, 2, 'St. Petersburg Pier', 'st-pete-pier', '200 2nd Ave NE, St. Petersburg, FL 33701', 'America/New_York',
     NULL, 0.35, 'gpt-4o', 'Welcome to St. Pete Pier Residences!',
     '{"units": 180, "type": "condo", "amenities": ["rooftop-pool", "kayak-storage"]}'),

    (45, 2, 'Clearwater Sands', 'clearwater-sands', '500 Mandalay Ave, Clearwater Beach, FL 33767', 'America/New_York',
     NULL, 0.3, 'gpt-4o-mini', 'Hello from Clearwater Sands!',
     '{"units": 140, "type": "condo", "amenities": ["beach-access", "pool", "hot-tub"]}'),

    (46, 2, 'Orlando Lake Nona', 'orlando-lake-nona', '9000 Narcoossee Rd, Orlando, FL 32827', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Welcome to Lake Nona! How can I help?',
     '{"units": 450, "type": "single-family", "amenities": ["pool", "fitness-center", "lake-access"]}'),

    (47, 2, 'Winter Park Oaks', 'winter-park-oaks', '300 Park Ave S, Winter Park, FL 32789', 'America/New_York',
     NULL, 0.25, 'gpt-4o', 'Hello from Winter Park Oaks!',
     '{"units": 110, "type": "townhome", "amenities": ["pool", "garden"]}'),

    (48, 2, 'Jacksonville Beach Club', 'jax-beach-club', '1 Ocean Blvd, Jacksonville Beach, FL 32250', 'America/New_York',
     NULL, 0.35, 'gpt-4o-mini', 'Hey! Welcome to Jax Beach Club!',
     '{"units": 160, "type": "condo", "amenities": ["beach-access", "pool", "surf-shack"]}'),

    (49, 2, 'Ponte Vedra Preserve', 'ponte-vedra-preserve', '200 Ponte Vedra Blvd, Ponte Vedra Beach, FL 32082', 'America/New_York',
     'You assist residents of Ponte Vedra Preserve, an upscale golf community near TPC Sawgrass. Common topics include golf tee times, clubhouse events, and landscaping standards.',
     0.2, 'gpt-4o', 'Welcome to Ponte Vedra Preserve. How may I assist you?',
     '{"units": 275, "type": "single-family", "amenities": ["golf-course", "pool", "clubhouse", "tennis"]}'),

    (50, 2, 'Amelia Island Plantation', 'amelia-island', '6800 First Coast Hwy, Amelia Island, FL 32034', 'America/New_York',
     NULL, 0.3, 'gpt-4o', 'Welcome to Amelia Island Plantation!',
     '{"units": 190, "type": "mixed-use", "amenities": ["beach-club", "golf", "spa", "nature-center"]}');

SELECT setval('communities_id_seq', 50);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. USERS (4 Property Managers + Staff + Residents)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO users (id, company_id, email, password_hash, full_name, phone, role, is_active, email_verified)
VALUES
    -- Super Admin
    (1, NULL, 'superadmin@hoaassistant.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'System Administrator', '(800) 555-0001', 'super_admin', TRUE, TRUE),

    -- Pinnacle Property Group — Company Admin + 2 Property Managers
    (2, 1, 'sarah.mitchell@pinnaclepg.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Sarah Mitchell', '(404) 555-0101', 'company_admin', TRUE, TRUE),
    (3, 1, 'james.rodriguez@pinnaclepg.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'James Rodriguez', '(404) 555-0102', 'community_manager', TRUE, TRUE),
    (4, 1, 'emily.chen@pinnaclepg.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Emily Chen', '(404) 555-0103', 'community_manager', TRUE, TRUE),

    -- Coastal Management Solutions — Company Admin + 2 Property Managers
    (5, 2, 'david.thompson@coastalmgmt.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'David Thompson', '(305) 555-0201', 'company_admin', TRUE, TRUE),
    (6, 2, 'maria.garcia@coastalmgmt.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Maria Garcia', '(305) 555-0202', 'community_manager', TRUE, TRUE),
    (7, 2, 'robert.williams@coastalmgmt.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Robert Williams', '(305) 555-0203', 'community_manager', TRUE, TRUE),

    -- Staff members
    (8, 1, 'lisa.park@pinnaclepg.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Lisa Park', '(404) 555-0104', 'staff', TRUE, TRUE),
    (9, 2, 'carlos.mendez@coastalmgmt.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Carlos Mendez', '(305) 555-0204', 'staff', TRUE, TRUE),

    -- Residents (Pinnacle communities)
    (10, 1, 'john.smith@gmail.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'John Smith', '(404) 555-1001', 'resident', TRUE, TRUE),
    (11, 1, 'patricia.jones@yahoo.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Patricia Jones', '(404) 555-1002', 'resident', TRUE, TRUE),
    (12, 1, 'michael.brown@outlook.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Michael Brown', '(404) 555-1003', 'resident', TRUE, FALSE),
    (13, 1, 'jennifer.davis@gmail.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Jennifer Davis', '(404) 555-1004', 'resident', TRUE, TRUE),
    (14, 1, 'william.wilson@gmail.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'William Wilson', '(404) 555-1005', 'resident', TRUE, TRUE),

    -- Residents (Coastal communities)
    (15, 2, 'ana.martinez@gmail.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Ana Martinez', '(305) 555-2001', 'resident', TRUE, TRUE),
    (16, 2, 'kevin.nguyen@yahoo.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Kevin Nguyen', '(305) 555-2002', 'resident', TRUE, TRUE),
    (17, 2, 'rachel.taylor@outlook.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Rachel Taylor', '(305) 555-2003', 'resident', TRUE, TRUE),
    (18, 2, 'antonio.lopez@gmail.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Antonio Lopez', '(305) 555-2004', 'resident', TRUE, FALSE),
    (19, 2, 'sophie.anderson@gmail.com', '$2a$12$LJ3m4ys3Kl5bMz.q9XKv7.ABC123placeholder', 'Sophie Anderson', '(305) 555-2005', 'resident', TRUE, TRUE);

SELECT setval('users_id_seq', 19);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. USER ↔ COMMUNITY ASSIGNMENTS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO user_communities (user_id, community_id, role)
VALUES
    -- Pinnacle managers manage multiple communities
    (3, 1, 'community_manager'), (3, 2, 'community_manager'), (3, 3, 'community_manager'),
    (3, 4, 'community_manager'), (3, 5, 'community_manager'), (3, 6, 'community_manager'),
    (3, 7, 'community_manager'), (3, 8, 'community_manager'), (3, 9, 'community_manager'),
    (3, 10, 'community_manager'), (3, 11, 'community_manager'), (3, 12, 'community_manager'),
    (4, 13, 'community_manager'), (4, 14, 'community_manager'), (4, 15, 'community_manager'),
    (4, 16, 'community_manager'), (4, 17, 'community_manager'), (4, 18, 'community_manager'),
    (4, 19, 'community_manager'), (4, 20, 'community_manager'), (4, 21, 'community_manager'),
    (4, 22, 'community_manager'), (4, 23, 'community_manager'), (4, 24, 'community_manager'),
    (4, 25, 'community_manager'),
    -- Staff
    (8, 1, 'staff'), (8, 2, 'staff'), (8, 3, 'staff'),

    -- Coastal managers
    (6, 26, 'community_manager'), (6, 27, 'community_manager'), (6, 28, 'community_manager'),
    (6, 29, 'community_manager'), (6, 30, 'community_manager'), (6, 31, 'community_manager'),
    (6, 32, 'community_manager'), (6, 33, 'community_manager'), (6, 34, 'community_manager'),
    (6, 35, 'community_manager'), (6, 36, 'community_manager'), (6, 37, 'community_manager'),
    (7, 38, 'community_manager'), (7, 39, 'community_manager'), (7, 40, 'community_manager'),
    (7, 41, 'community_manager'), (7, 42, 'community_manager'), (7, 43, 'community_manager'),
    (7, 44, 'community_manager'), (7, 45, 'community_manager'), (7, 46, 'community_manager'),
    (7, 47, 'community_manager'), (7, 48, 'community_manager'), (7, 49, 'community_manager'),
    (7, 50, 'community_manager'),
    -- Staff
    (9, 26, 'staff'), (9, 27, 'staff'), (9, 28, 'staff'),

    -- Residents assigned to communities
    (10, 1, 'resident'), (11, 1, 'resident'), (12, 2, 'resident'),
    (13, 3, 'resident'), (14, 6, 'resident'),
    (15, 26, 'resident'), (16, 26, 'resident'), (17, 28, 'resident'),
    (18, 31, 'resident'), (19, 40, 'resident');


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. DOCUMENTS (sample uploads per community — using first 4 communities)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO documents (id, community_id, uploaded_by, title, description, file_name, file_url, file_size_bytes, mime_type, category, tags, status, page_count, metadata)
VALUES
    -- Buckhead Towers (community 1)
    (1, 1, 3, 'CC&Rs - Buckhead Towers', 'Declaration of Covenants, Conditions & Restrictions', 'buckhead-towers-ccrs-2024.pdf',
     's3://hoa-docs/1/buckhead-towers-ccrs-2024.pdf', 2456000, 'application/pdf', 'rules', ARRAY['ccrs','governing-docs','legal'], 'processed', 45,
     '{"year": 2024, "version": "amended"}'),

    (2, 1, 3, 'Buckhead Towers Bylaws', 'Association bylaws governing board operations', 'buckhead-towers-bylaws.pdf',
     's3://hoa-docs/1/buckhead-towers-bylaws.pdf', 890000, 'application/pdf', 'rules', ARRAY['bylaws','governing-docs'], 'processed', 22,
     '{"year": 2023}'),

    (3, 1, 3, 'Pool & Amenity Rules 2026', 'Updated pool hours, guest policy, and amenity reservation rules', 'pool-rules-2026.pdf',
     's3://hoa-docs/1/pool-rules-2026.pdf', 345000, 'application/pdf', 'rules', ARRAY['pool','amenities','rules'], 'processed', 8,
     '{"effective_date": "2026-03-01"}'),

    (4, 1, 3, 'Annual Budget FY2026', 'Approved annual operating budget for fiscal year 2026', 'fy2026-budget.pdf',
     's3://hoa-docs/1/fy2026-budget.pdf', 1200000, 'application/pdf', 'financials', ARRAY['budget','financials','2026'], 'processed', 15,
     '{"fiscal_year": 2026, "approved_date": "2025-12-15"}'),

    (5, 1, 3, 'Board Meeting Minutes - February 2026', 'Minutes from the February board meeting', 'minutes-feb-2026.pdf',
     's3://hoa-docs/1/minutes-feb-2026.pdf', 567000, 'application/pdf', 'minutes', ARRAY['minutes','board-meeting','february'], 'processed', 12,
     '{"meeting_date": "2026-02-18"}'),

    -- Brickell Bay (community 26)
    (6, 26, 6, 'Brickell Bay Master Rules', 'Comprehensive rules and regulations for Brickell Bay Residences', 'brickell-bay-rules.pdf',
     's3://hoa-docs/26/brickell-bay-rules.pdf', 3100000, 'application/pdf', 'rules', ARRAY['rules','governing-docs'], 'processed', 55,
     '{"year": 2025, "languages": ["en", "es"]}'),

    (7, 26, 6, 'Hurricane Preparedness Guide', 'Building hurricane protocols and evacuation procedures', 'hurricane-prep-guide.pdf',
     's3://hoa-docs/26/hurricane-prep-guide.pdf', 780000, 'application/pdf', 'safety', ARRAY['hurricane','safety','emergency'], 'processed', 18,
     '{"last_updated": "2025-06-01"}'),

    (8, 26, 6, 'Marina Dock Agreement', 'Boat slip rental agreement and marina rules', 'marina-agreement.pdf',
     's3://hoa-docs/26/marina-agreement.pdf', 420000, 'application/pdf', 'amenities', ARRAY['marina','boat','dock'], 'processed', 10,
     '{}'),

    -- Peachtree Hills (community 2) — one doc still processing
    (9, 2, 3, 'Peachtree Hills Design Guidelines', 'Architectural review standards for exterior modifications', 'design-guidelines.pdf',
     's3://hoa-docs/2/design-guidelines.pdf', 2800000, 'application/pdf', 'rules', ARRAY['architecture','design','exterior'], 'processed', 35,
     '{}'),

    (10, 2, 3, 'Landscaping Standards 2026', 'New landscaping requirements effective March 2026', 'landscaping-2026.pdf',
     's3://hoa-docs/2/landscaping-2026.pdf', 600000, 'application/pdf', 'rules', ARRAY['landscaping','maintenance'], 'processing', 14,
     '{}'),

    -- Druid Hills (community 3)
    (11, 3, 3, 'Historic District Compliance Guide', 'Guidelines for modifications in the National Historic District', 'historic-compliance.pdf',
     's3://hoa-docs/3/historic-compliance.pdf', 1900000, 'application/pdf', 'rules', ARRAY['historic','compliance','architecture'], 'processed', 28,
     '{"historic_register": true}');

SELECT setval('documents_id_seq', 11);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. FAQs
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO faqs (id, community_id, created_by, question, answer, category, sort_order, is_published, view_count, helpful_count)
VALUES
    -- Buckhead Towers
    (1, 1, 3, 'What are the pool hours?', 'The pool is open daily from 6:00 AM to 10:00 PM. Lap swim is available from 6:00 AM to 8:00 AM. Guests must be accompanied by a resident at all times. Maximum 2 guests per unit.', 'amenities', 1, TRUE, 245, 198),
    (2, 1, 3, 'How do I reserve the rooftop for a private event?', 'Rooftop reservations can be made through the concierge desk or the resident portal. A $500 refundable deposit is required. Reservations must be made at least 14 days in advance. Maximum capacity is 50 guests.', 'amenities', 2, TRUE, 180, 150),
    (3, 1, 3, 'What is the guest parking policy?', 'Guests may park in designated visitor spots in the P1 level. A visitor pass must be obtained from the concierge. Guest parking is limited to 4 hours unless extended by a resident. Overnight guest parking requires 24-hour advance notice.', 'parking', 3, TRUE, 320, 280),
    (4, 1, 3, 'How do I submit a maintenance request?', 'Maintenance requests can be submitted through the resident portal, by calling the front desk at ext. 100, or by emailing maintenance@buckheadtowers.com. Emergency requests (water leaks, power outage) should call the 24/7 emergency line at (404) 555-0199.', 'maintenance', 4, TRUE, 410, 375),
    (5, 1, 3, 'When are HOA dues paid and how much are they?', 'HOA dues are due on the 1st of each month. Current monthly assessments range from $850 (1BR) to $2,200 (penthouse). Payments can be made via ACH auto-pay, check, or through the resident portal. Late payments incur a $50 fee after the 15th.', 'financials', 5, TRUE, 520, 480),

    -- Brickell Bay
    (6, 26, 6, 'What are the marina slip rates?', 'Marina slip rates vary by boat length: up to 30ft is $800/month, 31-45ft is $1,200/month, and 46-60ft is $1,800/month. Annual contracts receive a 10% discount. Contact the marina office for availability.', 'amenities', 1, TRUE, 150, 120),
    (7, 26, 6, 'How do I get a replacement key fob?', 'Replacement key fobs can be obtained from the management office during business hours (9 AM - 5 PM, Mon-Fri). A $75 replacement fee applies. You must bring a valid photo ID. Fobs are programmed within 24 hours.', 'general', 2, TRUE, 280, 230),
    (8, 26, 6, 'What is the hurricane shutter policy?', 'All residents must install hurricane shutters when a hurricane watch is issued for Miami-Dade County. The building provides accordion shutters for units without permanent installations. Shutters must be removed within 48 hours after the all-clear.', 'safety', 3, TRUE, 190, 170),

    -- Peachtree Hills
    (9, 2, 4, 'Can I paint my front door a different color?', 'All exterior color changes, including front doors, must be approved by the Architectural Review Committee (ARC). Submit a color sample and application form to the management office. The ARC meets monthly on the first Tuesday. Allow 30 days for review.', 'architecture', 1, TRUE, 95, 78),
    (10, 2, 4, 'What are the trash and recycling pickup days?', 'Trash pickup is every Monday and Thursday. Recycling is collected on Wednesdays. Bins must be placed at the curb by 7:00 AM and removed by 8:00 PM on collection days. Bulk item pickup can be scheduled by calling (404) 555-0150.', 'general', 2, TRUE, 175, 160);

SELECT setval('faqs_id_seq', 10);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. ANNOUNCEMENTS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO announcements (id, community_id, created_by, title, body, category, priority, is_published, published_at, expires_at)
VALUES
    (1, 1, 3, 'Pool Resurfacing — Closed March 15-22', 'The main pool will be closed for resurfacing from March 15 through March 22, 2026. The rooftop hot tub will remain open. We apologize for the inconvenience.', 'amenities', 'high', TRUE, '2026-03-01 09:00:00-05', '2026-03-22 23:59:00-05'),
    (2, 1, 3, 'Annual Meeting Notice — April 10', 'The annual homeowners meeting will be held on April 10, 2026 at 7:00 PM in the Grand Ballroom. Proxy forms must be submitted by April 3. Quorum requires 25% of unit owners.', 'governance', 'normal', TRUE, '2026-03-05 10:00:00-05', '2026-04-10 23:59:00-05'),
    (3, 1, 3, 'New Package Locker System', 'We have installed a new smart package locker system in the mail room. You will receive a text notification when a package is delivered. Pick up within 72 hours or it will be returned to the concierge.', 'general', 'normal', TRUE, '2026-02-20 08:00:00-05', NULL),
    (4, 26, 6, 'Hurricane Season Preparation Reminder', 'Hurricane season begins June 1. All residents must update their emergency contact information by May 15. Hurricane shutter inspection will take place the week of May 18. Contact the management office to schedule your inspection.', 'safety', 'urgent', TRUE, '2026-03-01 08:00:00-05', '2026-06-01 00:00:00-05'),
    (5, 26, 6, 'Elevator Modernization — Tower B', 'Tower B elevators 3 and 4 will be out of service for modernization from March 20 to April 15. Please use elevators 1 and 2 during this period. We appreciate your patience.', 'maintenance', 'high', TRUE, '2026-03-07 07:00:00-05', '2026-04-15 23:59:00-05'),
    (6, 2, 4, 'Spring Community Yard Sale — March 28', 'Join us for our annual spring yard sale on March 28 from 8 AM to 2 PM at the clubhouse parking lot. Reserve your spot by March 21. $10 per space, proceeds benefit the community garden fund.', 'events', 'normal', TRUE, '2026-03-06 10:00:00-05', '2026-03-28 23:59:00-05');

SELECT setval('announcements_id_seq', 6);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. EMAILS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO emails (id, community_id, imported_by, subject, sender, recipients, body_text, received_at, category)
VALUES
    (1, 1, 3, 'Water Shut-Off Notice - Unit 1205', 'maintenance@buckheadtowers.com', ARRAY['residents-floor12@buckheadtowers.com'],
     'Dear Floor 12 Residents, Please be advised that water service will be temporarily shut off on March 10, 2026 from 10:00 AM to 2:00 PM for pipe repair in Unit 1205. We recommend filling containers with water in advance. Thank you for your understanding.',
     '2026-03-05 14:30:00-05', 'maintenance'),
    (2, 1, 3, 'Parking Deck Cleaning Schedule', 'management@buckheadtowers.com', ARRAY['all-residents@buckheadtowers.com'],
     'The parking deck will be pressure washed on alternating floors over the next two weeks. P1: March 12, P2: March 14, P3: March 16. Please move your vehicle by 7 AM on your floors scheduled date. Temporary parking is available at the overflow lot on Peachtree.',
     '2026-03-04 09:15:00-05', 'general'),
    (3, 26, 6, 'Updated Valet Service Hours', 'concierge@brickellbay.com', ARRAY['all-residents@brickellbay.com'],
     'Effective March 15, 2026, valet service hours will be extended to 24/7. This change is in response to resident feedback. Monthly valet fee remains $200. Self-park remains available at no additional cost.',
     '2026-03-03 11:00:00-05', 'amenities'),
    (4, 26, 6, 'Fire Alarm Testing - March 12', 'safety@brickellbay.com', ARRAY['all-residents@brickellbay.com'],
     'The fire alarm system will undergo annual testing on March 12 between 9:00 AM and 3:00 PM. Alarms may sound intermittently during this period. No evacuation is necessary. Please do not call 911 for these tests.',
     '2026-03-02 08:00:00-05', 'safety');

SELECT setval('emails_id_seq', 4);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. KNOWLEDGE SOURCES REGISTRY (auto-populated by triggers on INSERT above,
--    but we need to manually add entries since triggers fired with auto IDs)
--    The triggers already fired, so this section is handled.
-- ─────────────────────────────────────────────────────────────────────────────
-- NOTE: The AFTER INSERT triggers on documents, faqs, announcements, and emails
-- have already populated the knowledge_sources table. No manual inserts needed.


-- ─────────────────────────────────────────────────────────────────────────────
-- 10. KNOWLEDGE CHUNKS (sample embeddings — using zero vectors as placeholders)
--     In production, embeddings would come from OpenAI text-embedding-3-small
-- ─────────────────────────────────────────────────────────────────────────────

-- Helper: create a zero vector placeholder (1536 dims)
-- In real usage, replace with actual embeddings from your ingestion pipeline

INSERT INTO knowledge_chunks (id, community_id, source_type, source_id, chunk_index, chunk_title, chunk_text, chunk_hash, embedding, importance_score, token_count, metadata)
VALUES
    -- Document chunks: CC&Rs (doc 1)
    (1, 1, 'document', 1, 0, 'CC&Rs - Article I: Definitions',
     'Article I: Definitions. "Association" means the Buckhead Towers Condominium Association, Inc. "Unit" means each individual condominium unit as defined in the Declaration. "Common Elements" include the lobby, hallways, elevators, parking deck, pool area, rooftop deck, and fitness center. "Limited Common Elements" include balconies, storage units, and assigned parking spaces.',
     'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
     NULL, 1.0, 85,
     '{"document_title": "CC&Rs", "section": "Article I", "page_number": 1}'),

    (2, 1, 'document', 1, 1, 'CC&Rs - Article IV: Use Restrictions',
     'Article IV: Use Restrictions. Units shall be used for residential purposes only. No business activities shall be conducted from any unit except home office work that does not generate foot traffic. Short-term rentals (less than 6 months) are prohibited. Noise levels must not exceed reasonable limits between 10:00 PM and 8:00 AM. Pets are limited to two (2) per unit, not exceeding 50 pounds each. Prohibited pets include reptiles, farm animals, and exotic species.',
     'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3',
     NULL, 1.0, 110,
     '{"document_title": "CC&Rs", "section": "Article IV", "page_number": 8}'),

    (3, 1, 'document', 1, 2, 'CC&Rs - Article VI: Assessments',
     'Article VI: Assessments. Monthly assessments are determined annually by the Board of Directors based on the approved budget. Assessments are due on the first (1st) day of each month. A late fee of $50.00 will be applied to any payment not received by the fifteenth (15th). Accounts more than 90 days past due may be subject to lien. Special assessments may be levied by a two-thirds (2/3) vote of the Board for capital improvements or emergency repairs.',
     'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4',
     NULL, 1.0, 105,
     '{"document_title": "CC&Rs", "section": "Article VI", "page_number": 15}'),

    -- Pool rules chunks (doc 3)
    (4, 1, 'document', 3, 0, 'Pool Rules - Hours and Access',
     'Pool Hours and Access. The main pool is open daily from 6:00 AM to 10:00 PM. Lap swim hours are 6:00 AM to 8:00 AM (lanes 1-3 reserved). The hot tub closes at 9:00 PM. All residents must tap their key fob at the pool gate for entry. Children under 14 must be accompanied by an adult resident. Glass containers are strictly prohibited in the pool area.',
     'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5',
     NULL, 1.0, 90,
     '{"document_title": "Pool & Amenity Rules 2026", "section": "Hours and Access", "page_number": 1}'),

    (5, 1, 'document', 3, 1, 'Pool Rules - Guest Policy',
     'Guest Policy. Each resident may bring a maximum of two (2) guests to the pool. Guests must sign in at the pool attendant station. Guest hours are 10:00 AM to 8:00 PM. Residents are responsible for their guests behavior. Guest passes for extended visits (3+ days) must be arranged through the concierge.',
     'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6',
     NULL, 1.0, 75,
     '{"document_title": "Pool & Amenity Rules 2026", "section": "Guest Policy", "page_number": 3}'),

    -- FAQ chunks (importance 1.5)
    (6, 1, 'faq', 1, 0, 'FAQ: Pool Hours',
     'What are the pool hours? The pool is open daily from 6:00 AM to 10:00 PM. Lap swim is available from 6:00 AM to 8:00 AM. Guests must be accompanied by a resident at all times. Maximum 2 guests per unit.',
     'f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1',
     NULL, 1.5, 55,
     '{"category": "amenities"}'),

    (7, 1, 'faq', 4, 0, 'FAQ: Maintenance Requests',
     'How do I submit a maintenance request? Maintenance requests can be submitted through the resident portal, by calling the front desk at ext. 100, or by emailing maintenance@buckheadtowers.com. Emergency requests (water leaks, power outage) should call the 24/7 emergency line at (404) 555-0199.',
     'a7b8c9d0e1f2a7b8c9d0e1f2a7b8c9d0e1f2a7b8c9d0e1f2a7b8c9d0e1f2a7b8',
     NULL, 1.5, 60,
     '{"category": "maintenance"}'),

    -- Announcement chunks (importance 1.3)
    (8, 1, 'announcement', 1, 0, 'Announcement: Pool Resurfacing',
     'Pool Resurfacing — Closed March 15-22. The main pool will be closed for resurfacing from March 15 through March 22, 2026. The rooftop hot tub will remain open. We apologize for the inconvenience.',
     'b8c9d0e1f2a3b8c9d0e1f2a3b8c9d0e1f2a3b8c9d0e1f2a3b8c9d0e1f2a3b8c9',
     NULL, 1.3, 45,
     '{"priority": "high", "expires_at": "2026-03-22"}'),

    -- Email chunks (importance 0.8)
    (9, 1, 'email', 1, 0, 'Notice: Water Shut-Off Floor 12',
     'Water service will be temporarily shut off on March 10, 2026 from 10:00 AM to 2:00 PM for pipe repair in Unit 1205. We recommend filling containers with water in advance.',
     'c9d0e1f2a3b4c9d0e1f2a3b4c9d0e1f2a3b4c9d0e1f2a3b4c9d0e1f2a3b4c9d0',
     NULL, 0.8, 40,
     '{"category": "maintenance", "date": "2026-03-05"}'),

    -- Brickell Bay chunks
    (10, 26, 'document', 6, 0, 'Brickell Bay Rules - Noise Policy',
     'Noise Policy. Quiet hours are from 10:00 PM to 8:00 AM daily. Construction and renovation work is permitted Monday through Friday, 9:00 AM to 5:00 PM only. Weekend construction requires board approval. Violations may result in fines starting at $250 for the first offense.',
     'd0e1f2a3b4c5d0e1f2a3b4c5d0e1f2a3b4c5d0e1f2a3b4c5d0e1f2a3b4c5d0e1',
     NULL, 1.0, 70,
     '{"document_title": "Brickell Bay Master Rules", "section": "Noise Policy", "page_number": 12}'),

    (11, 26, 'document', 7, 0, 'Hurricane Preparedness - Evacuation',
     'Evacuation Procedures. When a mandatory evacuation order is issued for Miami-Dade County, all residents must evacuate the building. Designated evacuation routes are posted in each elevator lobby. Residents with mobility challenges should register with the management office for evacuation assistance. The building will secure all common areas and activate storm shutters.',
     'e1f2a3b4c5d6e1f2a3b4c5d6e1f2a3b4c5d6e1f2a3b4c5d6e1f2a3b4c5d6e1f2',
     NULL, 1.0, 80,
     '{"document_title": "Hurricane Preparedness Guide", "section": "Evacuation", "page_number": 5}'),

    (12, 26, 'faq', 6, 0, 'FAQ: Marina Slip Rates',
     'What are the marina slip rates? Marina slip rates vary by boat length: up to 30ft is $800/month, 31-45ft is $1,200/month, and 46-60ft is $1,800/month. Annual contracts receive a 10% discount.',
     'f2a3b4c5d6e7f2a3b4c5d6e7f2a3b4c5d6e7f2a3b4c5d6e7f2a3b4c5d6e7f2a3',
     NULL, 1.5, 50,
     '{"category": "amenities"}');

SELECT setval('knowledge_chunks_id_seq', 12);

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. INGESTION JOBS + CHUNK LOGS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO ingestion_jobs (id, community_id, source_type, source_id, status, total_chunks, processed_chunks, total_tokens, embedding_model, started_at, completed_at, api_calls_made, estimated_cost)
VALUES
    (1, 1, 'document', 1, 'completed', 3, 3, 300, 'text-embedding-3-small', '2026-03-01 10:00:00-05', '2026-03-01 10:02:30-05', 3, 0.000060),
    (2, 1, 'document', 3, 'completed', 2, 2, 165, 'text-embedding-3-small', '2026-03-01 10:05:00-05', '2026-03-01 10:06:00-05', 2, 0.000033),
    (3, 26, 'document', 6, 'completed', 1, 1, 70, 'text-embedding-3-small', '2026-03-02 14:00:00-05', '2026-03-02 14:01:00-05', 1, 0.000014),
    (4, 2, 'document', 10, 'embedding', 5, 3, 0, 'text-embedding-3-small', '2026-03-07 08:00:00-05', NULL, 3, 0.000042);

SELECT setval('ingestion_jobs_id_seq', 4);

INSERT INTO ingestion_chunk_log (job_id, chunk_index, status, error_message)
VALUES
    (1, 0, 'embedded', NULL), (1, 1, 'embedded', NULL), (1, 2, 'embedded', NULL),
    (2, 0, 'embedded', NULL), (2, 1, 'embedded', NULL),
    (3, 0, 'embedded', NULL),
    (4, 0, 'embedded', NULL), (4, 1, 'embedded', NULL), (4, 2, 'embedded', NULL),
    (4, 3, 'pending', NULL), (4, 4, 'pending', NULL);


-- ─────────────────────────────────────────────────────────────────────────────
-- 12. WIDGET CONFIGS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO widget_configs (id, community_id, api_key, secret_key, allowed_origins, theme, max_messages_per_session, require_email, enable_tickets)
VALUES
    (1, 1, 'wk_live_buckhead_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', 'ws_secret_buckhead_x9y8z7w6v5u4t3s2r1q0',
     ARRAY['https://buckheadtowers.com', 'https://app.buckheadtowers.com'],
     '{"primaryColor": "#1a5276", "position": "bottom-right", "title": "Buckhead Towers Assistant"}',
     50, FALSE, TRUE),
    (2, 26, 'wk_live_brickell_b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7', 'ws_secret_brickell_y8z7w6v5u4t3s2r1q0p9',
     ARRAY['https://brickellbay.com'],
     '{"primaryColor": "#148f77", "position": "bottom-right", "title": "Brickell Bay Concierge"}',
     100, TRUE, TRUE),
    (3, 2, 'wk_live_peachtree_c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8', 'ws_secret_peachtree_z7w6v5u4t3s2r1q0p9o8',
     ARRAY['https://peachtreehills.org'],
     '{"primaryColor": "#2e86c1", "position": "bottom-right", "title": "Peachtree Hills HOA"}',
     50, FALSE, TRUE);

SELECT setval('widget_configs_id_seq', 3);

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. WIDGET SESSIONS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO widget_sessions (id, widget_config_id, community_id, session_token, visitor_id, user_id, visitor_name, visitor_email, ip_address, user_agent, page_url, message_count)
VALUES
    (1, 1, 1, 'sess_bt_001_a1b2c3d4e5f6g7h8', 'vid_john_001', 10, 'John Smith', 'john.smith@gmail.com', '72.45.120.33', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 'https://buckheadtowers.com/resident-portal', 6),
    (2, 1, 1, 'sess_bt_002_b2c3d4e5f6g7h8i9', 'vid_patricia_001', 11, 'Patricia Jones', 'patricia.jones@yahoo.com', '98.210.45.67', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'https://buckheadtowers.com/faq', 4),
    (3, 1, 1, 'sess_bt_003_c3d4e5f6g7h8i9j0', 'vid_anon_001', NULL, NULL, NULL, '184.56.78.90', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)', 'https://buckheadtowers.com', 2),
    (4, 2, 26, 'sess_bb_001_d4e5f6g7h8i9j0k1', 'vid_ana_001', 15, 'Ana Martinez', 'ana.martinez@gmail.com', '45.123.67.89', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', 'https://brickellbay.com/residents', 8),
    (5, 2, 26, 'sess_bb_002_e5f6g7h8i9j0k1l2', 'vid_kevin_001', 16, 'Kevin Nguyen', 'kevin.nguyen@yahoo.com', '67.89.12.34', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'https://brickellbay.com', 5);

SELECT setval('widget_sessions_id_seq', 5);

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. CONVERSATIONS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO conversations (id, community_id, widget_session_id, user_id, title, status, channel, ai_model_used, total_messages, total_tokens_used, rating, feedback, last_message_at)
VALUES
    (1, 1, 1, 10, 'Pool hours and guest policy', 'closed', 'widget', 'gpt-4o', 6, 1850, 5, 'Very helpful!', '2026-03-06 15:35:00-05'),
    (2, 1, 2, 11, 'Parking deck cleaning question', 'closed', 'widget', 'gpt-4o', 4, 980, 4, NULL, '2026-03-06 10:20:00-05'),
    (3, 1, 3, NULL, 'Anonymous — move-in info', 'active', 'widget', 'gpt-4o', 2, 420, NULL, NULL, '2026-03-07 09:15:00-05'),
    (4, 26, 4, 15, 'Marina dock reservation', 'closed', 'widget', 'gpt-4o', 8, 3200, 5, 'Ana loved the quick response!', '2026-03-05 16:45:00-05'),
    (5, 26, 5, 16, 'Hurricane prep and shutters', 'active', 'widget', 'gpt-4o', 5, 1500, NULL, NULL, '2026-03-07 11:30:00-05'),
    -- Admin panel conversations
    (6, 1, NULL, 3, 'Manager testing knowledge base', 'closed', 'admin', 'gpt-4o', 4, 1100, NULL, NULL, '2026-03-04 14:00:00-05');

SELECT setval('conversations_id_seq', 6);

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. MESSAGES (multi-turn conversations)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO messages (id, conversation_id, role, content, model_used, tokens_prompt, tokens_completion, latency_ms, retrieved_chunks, confidence_score)
VALUES
    -- Conversation 1: Pool hours (John Smith)
    (1, 1, 'user', 'What time does the pool open?', NULL, NULL, NULL, NULL, NULL, NULL),
    (2, 1, 'assistant', 'The pool at Buckhead Towers is open daily from 6:00 AM to 10:00 PM. Lap swim is available from 6:00 AM to 8:00 AM with lanes 1-3 reserved. The hot tub closes at 9:00 PM. You will need to tap your key fob at the pool gate for entry.', 'gpt-4o', 180, 65, 1200,
     '[{"chunk_id": 4, "score": 0.95}, {"chunk_id": 6, "score": 0.92}]', 0.96),
    (3, 1, 'user', 'Can I bring guests?', NULL, NULL, NULL, NULL, NULL, NULL),
    (4, 1, 'assistant', 'Yes! Each resident may bring up to 2 guests to the pool. Guests must sign in at the pool attendant station. Guest hours are 10:00 AM to 8:00 PM. You are responsible for your guests behavior. If you have guests staying for 3 or more days, please arrange extended guest passes through the concierge.', 'gpt-4o', 220, 72, 1350,
     '[{"chunk_id": 5, "score": 0.94}, {"chunk_id": 6, "score": 0.88}]', 0.94),
    (5, 1, 'user', 'Are glass bottles allowed at the pool?', NULL, NULL, NULL, NULL, NULL, NULL),
    (6, 1, 'assistant', 'No, glass containers are strictly prohibited in the pool area. This is for safety reasons to prevent broken glass injuries. You are welcome to bring beverages in plastic or aluminum containers instead.', 'gpt-4o', 250, 48, 980,
     '[{"chunk_id": 4, "score": 0.91}]', 0.93),

    -- Conversation 2: Parking (Patricia Jones)
    (7, 2, 'user', 'When is the parking deck being cleaned? I saw an email about it.', NULL, NULL, NULL, NULL, NULL, NULL),
    (8, 2, 'assistant', 'The parking deck is being pressure washed on the following schedule: P1 on March 12, P2 on March 14, and P3 on March 16. Please move your vehicle by 7:00 AM on your floors scheduled date. Temporary parking is available at the overflow lot on Peachtree.', 'gpt-4o', 200, 60, 1100,
     '[{"chunk_id": 9, "score": 0.88}]', 0.91),
    (9, 2, 'user', 'I park on P2. What if I cant move my car that day?', NULL, NULL, NULL, NULL, NULL, NULL),
    (10, 2, 'assistant', 'If you are unable to move your car on March 14 (P2 cleaning day), please contact the management office at (404) 555-0100 as soon as possible. They may be able to accommodate a reschedule or arrange for valet to move your vehicle. Cars that are not moved may not be cleaned around, so its best to coordinate in advance.', 'gpt-4o', 280, 75, 1400,
     '[]', 0.72),

    -- Conversation 3: Anonymous move-in
    (11, 3, 'user', 'Hi, Im considering buying a unit here. What are the HOA fees?', NULL, NULL, NULL, NULL, NULL, NULL),
    (12, 3, 'assistant', 'Welcome! Monthly HOA assessments at Buckhead Towers range from $850 for a one-bedroom unit to $2,200 for a penthouse. Fees cover common area maintenance, concierge service, pool and gym access, and building insurance. Payments can be made via ACH auto-pay, check, or through the resident portal. Is there anything else youd like to know?', 'gpt-4o', 190, 70, 1250,
     '[{"chunk_id": 3, "score": 0.93}, {"chunk_id": 7, "score": 0.85}]', 0.94),

    -- Conversation 4: Marina (Ana Martinez — longer conversation)
    (13, 4, 'user', 'Id like to rent a marina slip for my boat. Its a 35-foot sailboat.', NULL, NULL, NULL, NULL, NULL, NULL),
    (14, 4, 'assistant', 'Great choice! For a 35-foot vessel, the marina slip rate is $1,200 per month. If you sign an annual contract, you receive a 10% discount, bringing it down to $1,080 per month. Would you like to check availability?', 'gpt-4o', 200, 55, 1100,
     '[{"chunk_id": 12, "score": 0.96}]', 0.97),
    (15, 4, 'user', 'Yes please. Also, is there a waiting list?', NULL, NULL, NULL, NULL, NULL, NULL),
    (16, 4, 'assistant', 'Availability depends on the current season. I recommend contacting the marina office directly at (305) 555-0210 to check real-time availability. As of the last update, there is a short waiting list for slips in the 31-45ft range, typically 2-4 weeks. They can also set you up with the rental agreement paperwork.', 'gpt-4o', 280, 70, 1300,
     '[{"chunk_id": 12, "score": 0.90}]', 0.85),
    (17, 4, 'user', 'What about kayak storage?', NULL, NULL, NULL, NULL, NULL, NULL),
    (18, 4, 'assistant', 'Brickell Bay offers complimentary kayak storage racks on the marina level for residents. Spaces are assigned on a first-come, first-served basis. To reserve a rack, contact the marina office. You will need to provide proof of ownership or rental of the kayak.', 'gpt-4o', 310, 55, 1050,
     '[]', 0.78),
    (19, 4, 'user', 'Perfect, one more question — can I host guests on the dock?', NULL, NULL, NULL, NULL, NULL, NULL),
    (20, 4, 'assistant', 'Yes, residents with marina slips may host guests on the dock and their vessel. Guest access to the marina requires that you notify the dock master in advance. Gatherings of more than 10 people on the dock require prior approval from the marina office. Please review the Marina Dock Agreement for the complete guest policy.', 'gpt-4o', 350, 65, 1200,
     '[{"chunk_id": 10, "score": 0.82}]', 0.83),

    -- Conversation 5: Hurricane prep (Kevin Nguyen)
    (21, 5, 'user', 'When do I need to put up hurricane shutters?', NULL, NULL, NULL, NULL, NULL, NULL),
    (22, 5, 'assistant', 'You must install hurricane shutters when a hurricane watch is issued for Miami-Dade County. The building provides accordion shutters for units without permanent installations. After the all-clear is issued, shutters must be removed within 48 hours. The building will also schedule an annual shutter inspection — this years is the week of May 18.', 'gpt-4o', 220, 68, 1150,
     '[{"chunk_id": 11, "score": 0.94}, {"chunk_id": 8, "score": 0.87}]', 0.95),
    (23, 5, 'user', 'What if I need to evacuate? Where do I go?', NULL, NULL, NULL, NULL, NULL, NULL),
    (24, 5, 'assistant', 'When a mandatory evacuation order is issued for Miami-Dade County, all residents must evacuate the building. Designated evacuation routes are posted in each elevator lobby. If you have mobility challenges, please register with the management office for evacuation assistance. The building will secure all common areas and activate storm shutters automatically. For general county evacuation routes, visit miamidade.gov/emergency.', 'gpt-4o', 290, 80, 1400,
     '[{"chunk_id": 11, "score": 0.97}]', 0.96),
    (25, 5, 'user', 'Should I update my emergency contacts?', NULL, NULL, NULL, NULL, NULL, NULL);

SELECT setval('messages_id_seq', 25);

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. TICKETS (with various statuses)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO tickets (id, community_id, conversation_id, ticket_number, title, description, category, tags, created_by, assigned_to, status, priority, source, due_date, first_response_at, resolved_at, closed_at, resolution_notes, rating)
VALUES
    (1, 1, NULL, 'TKT-2026-00001', 'Water leak in unit 1504 bathroom', 'Resident reports water dripping from the ceiling in the master bathroom. Appears to be coming from the unit above (1604). Urgent — causing water damage to drywall.',
     'maintenance', ARRAY['water-leak','urgent','plumbing'], 10, 3, 'in_progress', 'urgent', 'chat_widget',
     '2026-03-08 12:00:00-05', '2026-03-06 10:30:00-05', NULL, NULL, NULL, NULL),

    (2, 1, 1, 'TKT-2026-00002', 'Pool gate key fob not working', 'Key fob for unit 2201 stopped working at the pool gate. Tested at the gym and it works there. May be a pool gate reader issue.',
     'maintenance', ARRAY['access','key-fob','pool'], 10, 3, 'resolved', 'medium', 'chat_widget',
     '2026-03-10 17:00:00-05', '2026-03-05 14:15:00-05', '2026-03-06 09:00:00-05', '2026-03-06 09:30:00-05',
     'Pool gate reader was recalibrated. Resident key fob now works correctly.', 5),

    (3, 1, NULL, 'TKT-2026-00003', 'Noise complaint - Unit 803', 'Multiple complaints about loud music from unit 803 after 11 PM on weeknights. Three different neighbors have reported the issue over the past two weeks.',
     'noise', ARRAY['noise','complaint','recurring'], 11, 4, 'waiting_on_resident', 'high', 'admin_panel',
     '2026-03-12 17:00:00-05', '2026-03-03 08:45:00-05', NULL, NULL, NULL, NULL),

    (4, 26, 4, 'TKT-2026-00001', 'Marina slip #23 electrical outlet broken', 'The 30-amp electrical outlet at slip #23 is not providing power. Tested with a multimeter — no voltage. Other slips nearby are working fine.',
     'maintenance', ARRAY['marina','electrical','dock'], 15, 6, 'open', 'high', 'chat_widget',
     '2026-03-10 17:00:00-05', NULL, NULL, NULL, NULL, NULL),

    (5, 26, NULL, 'TKT-2026-00002', 'Valet scratched my car', 'Found a scratch on the drivers side door after valet returned my vehicle on March 4. Photos attached. Requesting investigation and repair coverage.',
     'valet', ARRAY['valet','damage','insurance'], 16, 7, 'in_progress', 'high', 'admin_panel',
     '2026-03-15 17:00:00-05', '2026-03-05 11:00:00-05', NULL, NULL, NULL, NULL),

    (6, 1, NULL, 'TKT-2026-00004', 'Request to install EV charger in parking spot', 'Requesting permission to install a Level 2 EV charger in my assigned parking spot P2-145. I have a quote from a licensed electrician.',
     'modification', ARRAY['ev-charger','parking','modification'], 14, 3, 'waiting_on_manager', 'low', 'email',
     '2026-03-20 17:00:00-05', '2026-03-02 16:00:00-05', NULL, NULL, NULL, NULL),

    (7, 1, NULL, 'TKT-2026-00005', 'Elevator stuck on 15th floor — rescued', 'Was stuck in elevator 2 for 15 minutes on March 1 around 6 PM. Emergency phone worked but response was slow. Want to ensure this is documented.',
     'safety', ARRAY['elevator','safety','incident'], 13, 3, 'closed', 'urgent', 'chat_widget',
     NULL, '2026-03-01 18:45:00-05', '2026-03-02 10:00:00-05', '2026-03-02 11:00:00-05',
     'Elevator maintenance company (ThyssenKrupp) dispatched same day. Found faulty door sensor on floor 15. Sensor replaced and all elevators tested. Emergency response protocol reviewed with concierge team.', 4);

SELECT setval('tickets_id_seq', 7);

-- Update community ticket counters to match
UPDATE communities SET ticket_counter = 5 WHERE id = 1;
UPDATE communities SET ticket_counter = 2 WHERE id = 26;

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. TICKET COMMENTS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO ticket_comments (id, ticket_id, user_id, message, is_internal)
VALUES
    -- Ticket 1: Water leak
    (1, 1, 3, 'Dispatched emergency plumber. Will arrive within 2 hours. Asked resident to place towels and a bucket under the leak.', FALSE),
    (2, 1, 3, 'Internal: Contacted unit 1604 owner. They are not home but gave permission for plumber to access. Emergency key used.', TRUE),
    (3, 1, 10, 'The plumber arrived and found a cracked supply line under the bathroom sink in 1604. Temporary fix in place. Full repair scheduled for tomorrow.', FALSE),

    -- Ticket 2: Pool fob
    (4, 2, 3, 'Checked the pool gate reader logs. Multiple residents reported intermittent issues. Scheduling a technician to recalibrate.', FALSE),
    (5, 2, 3, 'Technician recalibrated the pool gate reader. Tested with 5 different fobs — all working. Please try your fob and let us know.', FALSE),
    (6, 2, 10, 'My fob works now. Thank you for the quick fix!', FALSE),

    -- Ticket 3: Noise complaint
    (7, 3, 4, 'First warning letter sent to unit 803 via certified mail on March 3.', FALSE),
    (8, 3, 4, 'Internal: Checked with doorman — unit 803 tenant has had 2 previous noise warnings in 2025. This is the 3rd complaint cycle.', TRUE),
    (9, 3, 4, 'Called unit 803 resident. They acknowledged the issue and agreed to keep music low after 10 PM. Following up in one week.', FALSE),

    -- Ticket 5: Valet scratch
    (10, 5, 7, 'Reviewing security camera footage from March 4 between 5 PM and 7 PM. Will update within 48 hours.', FALSE),
    (11, 5, 7, 'Internal: Camera footage shows the scratch was pre-existing when the car arrived. Comparing with check-in photos.', TRUE);

SELECT setval('ticket_comments_id_seq', 11);

-- ─────────────────────────────────────────────────────────────────────────────
-- 18. TICKET ATTACHMENTS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO ticket_attachments (id, ticket_id, comment_id, file_name, file_url, file_size_bytes, mime_type, uploaded_by)
VALUES
    (1, 1, NULL, 'water-leak-photo-1.jpg', 's3://hoa-tickets/1/water-leak-photo-1.jpg', 2500000, 'image/jpeg', 10),
    (2, 1, NULL, 'water-leak-photo-2.jpg', 's3://hoa-tickets/1/water-leak-photo-2.jpg', 1800000, 'image/jpeg', 10),
    (3, 5, NULL, 'car-scratch-driver-side.jpg', 's3://hoa-tickets/5/car-scratch-driver-side.jpg', 3200000, 'image/jpeg', 16),
    (4, 5, NULL, 'car-scratch-closeup.jpg', 's3://hoa-tickets/5/car-scratch-closeup.jpg', 2900000, 'image/jpeg', 16),
    (5, 6, NULL, 'ev-charger-quote.pdf', 's3://hoa-tickets/6/ev-charger-quote.pdf', 450000, 'application/pdf', 14);

SELECT setval('ticket_attachments_id_seq', 5);

-- ─────────────────────────────────────────────────────────────────────────────
-- 19. TICKET STATUS HISTORY (simulating status transitions)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO ticket_status_history (ticket_id, old_status, new_status, changed_by, notes, created_at)
VALUES
    -- Ticket 1: open → in_progress
    (1, 'open', 'in_progress', 3, 'Emergency plumber dispatched', '2026-03-06 10:30:00-05'),

    -- Ticket 2: open → in_progress → resolved → closed
    (2, 'open', 'in_progress', 3, 'Investigating pool gate reader', '2026-03-05 14:15:00-05'),
    (2, 'in_progress', 'resolved', 3, 'Gate reader recalibrated', '2026-03-06 09:00:00-05'),
    (2, 'resolved', 'closed', 3, 'Confirmed working by resident', '2026-03-06 09:30:00-05'),

    -- Ticket 3: open → in_progress → waiting_on_resident
    (3, 'open', 'in_progress', 4, 'Warning letter sent', '2026-03-03 08:45:00-05'),
    (3, 'in_progress', 'waiting_on_resident', 4, 'Waiting for resident to confirm behavior change', '2026-03-04 10:00:00-05'),

    -- Ticket 5: open → in_progress
    (5, 'open', 'in_progress', 7, 'Reviewing camera footage', '2026-03-05 11:00:00-05'),

    -- Ticket 6: open → waiting_on_manager
    (6, 'open', 'waiting_on_manager', 3, 'Needs board approval for EV charger installation', '2026-03-02 16:00:00-05'),

    -- Ticket 7: open → in_progress → resolved → closed
    (7, 'open', 'in_progress', 3, 'Elevator company dispatched', '2026-03-01 18:45:00-05'),
    (7, 'in_progress', 'resolved', 3, 'Faulty sensor replaced, all elevators tested', '2026-03-02 10:00:00-05'),
    (7, 'resolved', 'closed', 3, 'Documented and filed with elevator maintenance company', '2026-03-02 11:00:00-05');


-- ─────────────────────────────────────────────────────────────────────────────
-- 20. SEARCH LOGS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO search_logs (community_id, conversation_id, query_text, results_count, top_score, avg_score, chunk_ids, search_time_ms, total_time_ms, was_helpful, confidence)
VALUES
    (1, 1, 'pool hours open close', 3, 0.95, 0.89, ARRAY[4, 6, 5], 45, 1200, TRUE, 0.96),
    (1, 1, 'guest policy pool visitors', 3, 0.94, 0.87, ARRAY[5, 6, 4], 52, 1350, TRUE, 0.94),
    (1, 1, 'glass bottles pool', 2, 0.91, 0.85, ARRAY[4, 5], 38, 980, TRUE, 0.93),
    (1, 2, 'parking deck cleaning pressure wash schedule', 2, 0.88, 0.82, ARRAY[9, 2], 55, 1100, TRUE, 0.91),
    (1, 3, 'HOA fees monthly assessment cost', 3, 0.93, 0.88, ARRAY[3, 7, 2], 48, 1250, TRUE, 0.94),
    (26, 4, 'marina slip rental boat 35 feet', 2, 0.96, 0.90, ARRAY[12, 10], 42, 1100, TRUE, 0.97),
    (26, 4, 'kayak storage dock', 1, 0.78, 0.78, ARRAY[12], 35, 1050, TRUE, 0.78),
    (26, 5, 'hurricane shutters when install', 3, 0.94, 0.88, ARRAY[11, 8, 10], 50, 1150, TRUE, 0.95),
    (26, 5, 'evacuation mandatory hurricane route', 2, 0.97, 0.92, ARRAY[11, 8], 40, 1400, TRUE, 0.96),
    (1, 6, 'test query from admin panel', 0, NULL, NULL, ARRAY[]::BIGINT[], 30, 500, FALSE, 0.20);


-- ─────────────────────────────────────────────────────────────────────────────
-- 21. COMMUNITY ANALYTICS (past 7 days)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO community_analytics (community_id, date, total_conversations, total_messages, total_searches, total_tickets, avg_confidence, avg_response_time_ms, helpful_pct, total_chunks, total_documents)
VALUES
    -- Buckhead Towers
    (1, '2026-03-01', 3, 12, 8, 2, 0.91, 1180, 0.88, 9, 5),
    (1, '2026-03-02', 5, 22, 15, 1, 0.89, 1220, 0.85, 9, 5),
    (1, '2026-03-03', 4, 18, 12, 1, 0.92, 1150, 0.90, 9, 5),
    (1, '2026-03-04', 6, 30, 20, 0, 0.90, 1200, 0.87, 9, 5),
    (1, '2026-03-05', 8, 35, 25, 1, 0.93, 1100, 0.92, 9, 5),
    (1, '2026-03-06', 7, 28, 18, 1, 0.91, 1180, 0.89, 9, 5),
    (1, '2026-03-07', 4, 15, 10, 0, 0.94, 1050, 0.91, 9, 5),

    -- Brickell Bay
    (26, '2026-03-01', 5, 20, 14, 1, 0.88, 1250, 0.82, 3, 3),
    (26, '2026-03-02', 8, 40, 28, 0, 0.90, 1200, 0.86, 3, 3),
    (26, '2026-03-03', 6, 25, 18, 1, 0.87, 1300, 0.80, 3, 3),
    (26, '2026-03-04', 10, 50, 35, 0, 0.92, 1150, 0.90, 3, 3),
    (26, '2026-03-05', 7, 30, 22, 1, 0.89, 1220, 0.85, 3, 3),
    (26, '2026-03-06', 9, 42, 30, 0, 0.91, 1180, 0.88, 3, 3),
    (26, '2026-03-07', 6, 24, 16, 0, 0.93, 1100, 0.91, 3, 3);


-- ─────────────────────────────────────────────────────────────────────────────
-- 22. AUDIT LOG
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO audit_log (user_id, company_id, community_id, action, resource_type, resource_id, old_values, new_values, ip_address)
VALUES
    (3, 1, 1, 'create', 'document', 1, NULL, '{"title": "CC&Rs - Buckhead Towers"}', '10.0.1.50'),
    (3, 1, 1, 'create', 'document', 3, NULL, '{"title": "Pool & Amenity Rules 2026"}', '10.0.1.50'),
    (3, 1, 1, 'create', 'faq', 1, NULL, '{"question": "What are the pool hours?"}', '10.0.1.50'),
    (6, 2, 26, 'create', 'document', 6, NULL, '{"title": "Brickell Bay Master Rules"}', '10.0.2.50'),
    (3, 1, 1, 'update', 'ticket', 1, '{"status": "open"}', '{"status": "in_progress"}', '10.0.1.50'),
    (3, 1, 1, 'update', 'ticket', 2, '{"status": "in_progress"}', '{"status": "resolved"}', '10.0.1.50'),
    (10, 1, 1, 'create', 'ticket', 1, NULL, '{"title": "Water leak in unit 1504 bathroom"}', '72.45.120.33'),
    (15, 2, 26, 'create', 'ticket', 4, NULL, '{"title": "Marina slip #23 electrical outlet broken"}', '45.123.67.89'),
    (2, 1, NULL, 'login', 'user', 2, NULL, '{"method": "password"}', '10.0.1.100'),
    (5, 2, NULL, 'login', 'user', 5, NULL, '{"method": "password"}', '10.0.2.100');


-- ─────────────────────────────────────────────────────────────────────────────
-- 23. AI SUGGESTED FAQs
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO ai_suggested_faqs (community_id, question, suggested_answer, source_chunks, frequency, status, approved_by)
VALUES
    (1, 'What is the penalty for late HOA payments?', 'A late fee of $50.00 is applied to any payment not received by the 15th of the month. Accounts more than 90 days past due may be subject to lien.', ARRAY[3]::BIGINT[], 8, 'approved', 3),
    (1, 'Can I have a dog over 50 pounds?', 'Per the CC&Rs, pets are limited to two per unit and must not exceed 50 pounds each. If your pet exceeds this limit, you may apply for a waiver from the board.', ARRAY[2]::BIGINT[], 5, 'pending', NULL),
    (1, 'How do I get a new parking decal?', 'Contact the management office with your vehicle registration and unit number. A new parking decal costs $15 and is issued within 24 hours.', ARRAY[]::BIGINT[], 12, 'pending', NULL),
    (26, 'Is there a gym in the building?', 'Yes, the fitness center is located on the 3rd floor and is open 24/7 for residents. Key fob access is required.', ARRAY[]::BIGINT[], 15, 'approved', 6),
    (26, 'Can I rent my unit on Airbnb?', 'Short-term rentals under 6 months are prohibited per the building rules. All leases must be for a minimum of 6 months and require board approval.', ARRAY[10]::BIGINT[], 22, 'rejected', 6);


-- ─────────────────────────────────────────────────────────────────────────────
-- 24. DOCUMENT SUMMARIES
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO document_summaries (document_id, summary_short, summary_long, key_topics)
VALUES
    (1, 'Declaration of Covenants, Conditions & Restrictions for Buckhead Towers covering unit ownership, common elements, and assessment obligations.',
     'The CC&Rs establish the legal framework for Buckhead Towers Condominium Association. Key provisions include: unit use restrictions (residential only, no short-term rentals), pet policy (2 pets max, 50 lbs each), assessment structure (monthly dues with late fees after the 15th), common element maintenance responsibilities, architectural modification requirements, and dispute resolution procedures. The document was last amended in 2024.',
     ARRAY['covenants', 'use-restrictions', 'assessments', 'pets', 'common-elements', 'modifications']),

    (3, 'Updated pool and amenity rules for 2026 covering hours, guest policies, and reservation procedures.',
     'The 2026 Pool & Amenity Rules outline operating hours (6 AM - 10 PM daily), lap swim schedules, guest policies (2 guests per unit, sign-in required), safety rules (no glass, children under 14 supervised), and rooftop reservation procedures ($500 deposit, 50 person max, 14 day advance booking).',
     ARRAY['pool-hours', 'guest-policy', 'safety', 'reservations', 'amenities']),

    (6, 'Comprehensive rules and regulations for Brickell Bay Residences covering all aspects of community living.',
     'The Brickell Bay Master Rules cover noise policies (quiet hours 10 PM - 8 AM), construction rules (weekdays only, 9-5), move-in/out procedures, pet policies, common area usage, marina rules, valet service terms, hurricane protocols, and violation enforcement including a fine schedule starting at $250 for first offenses.',
     ARRAY['noise-policy', 'construction', 'pets', 'marina', 'hurricane', 'violations']),

    (7, 'Building hurricane protocols and evacuation procedures for Brickell Bay.',
     'The Hurricane Preparedness Guide covers pre-storm checklist, shutter installation requirements, evacuation procedures, emergency contacts, post-storm re-entry protocols, and insurance documentation guidelines. Includes specific instructions for mobility-challenged residents and pet evacuation plans.',
     ARRAY['hurricane', 'evacuation', 'emergency', 'shutters', 'safety']);


-- ─────────────────────────────────────────────────────────────────────────────
-- DONE — Verify counts
-- ─────────────────────────────────────────────────────────────────────────────

COMMIT;

-- Quick verification queries (run after the transaction commits)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT 'companies' AS tbl, COUNT(*) AS cnt FROM companies
        UNION ALL SELECT 'communities', COUNT(*) FROM communities
        UNION ALL SELECT 'users', COUNT(*) FROM users
        UNION ALL SELECT 'user_communities', COUNT(*) FROM user_communities
        UNION ALL SELECT 'documents', COUNT(*) FROM documents
        UNION ALL SELECT 'faqs', COUNT(*) FROM faqs
        UNION ALL SELECT 'announcements', COUNT(*) FROM announcements
        UNION ALL SELECT 'emails', COUNT(*) FROM emails
        UNION ALL SELECT 'knowledge_sources', COUNT(*) FROM knowledge_sources
        UNION ALL SELECT 'knowledge_chunks', COUNT(*) FROM knowledge_chunks
        UNION ALL SELECT 'ingestion_jobs', COUNT(*) FROM ingestion_jobs
        UNION ALL SELECT 'ingestion_chunk_log', COUNT(*) FROM ingestion_chunk_log
        UNION ALL SELECT 'conversations', COUNT(*) FROM conversations
        UNION ALL SELECT 'messages', COUNT(*) FROM messages
        UNION ALL SELECT 'tickets', COUNT(*) FROM tickets
        UNION ALL SELECT 'ticket_comments', COUNT(*) FROM ticket_comments
        UNION ALL SELECT 'ticket_attachments', COUNT(*) FROM ticket_attachments
        UNION ALL SELECT 'ticket_status_history', COUNT(*) FROM ticket_status_history
        UNION ALL SELECT 'widget_configs', COUNT(*) FROM widget_configs
        UNION ALL SELECT 'widget_sessions', COUNT(*) FROM widget_sessions
        UNION ALL SELECT 'search_logs', COUNT(*) FROM search_logs
        UNION ALL SELECT 'community_analytics', COUNT(*) FROM community_analytics
        UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log
        UNION ALL SELECT 'ai_suggested_faqs', COUNT(*) FROM ai_suggested_faqs
        UNION ALL SELECT 'document_summaries', COUNT(*) FROM document_summaries
        ORDER BY 1
    LOOP
        RAISE NOTICE '% : % rows', RPAD(r.tbl, 25), r.cnt;
    END LOOP;
END $$;
