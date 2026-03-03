-- ============================================================
-- HOA Assistant — Full Database Schema (Consolidated)
-- Combines V1 through V5 Flyway migrations into a single file.
-- Run once on a fresh PostgreSQL 16 + pgvector instance.
--
-- Sources merged:
--   V1__baseline_schema.sql
--   V2__multi_tenant_auth.sql
--   V3__document_enhancements.sql
--   V4__add_varchar_to_vector_cast.sql
--   V5__property_management_companies.sql
--
-- Last updated: 2026-03-02
-- ============================================================


-- ============================================================
-- EXTENSIONS
-- ============================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- pgvector registers an implicit cast text→vector but NOT varchar→vector.
-- Hibernate sends Java String as varchar; this cast prevents type errors.
DO $$ BEGIN
    CREATE CAST (varchar AS vector) WITH INOUT AS IMPLICIT;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ============================================================
-- COMMUNITIES
-- ============================================================

CREATE TABLE IF NOT EXISTS communities (
    id                 BIGSERIAL    PRIMARY KEY,
    name               VARCHAR(255) NOT NULL,
    slug               VARCHAR(100) UNIQUE,
    time_zone          VARCHAR(50)  NOT NULL DEFAULT 'America/Los_Angeles',
    office_hours       VARCHAR(255),
    contact_email      VARCHAR(255),
    contact_phone      VARCHAR(50),
    payment_portal_url VARCHAR(500),
    emergency_contact  VARCHAR(255),
    plan_tier          VARCHAR(20)  NOT NULL DEFAULT 'basic',
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    max_admins         INTEGER      NOT NULL DEFAULT 3,
    max_residents      INTEGER      NOT NULL DEFAULT 500,
    created_at         TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS communities_slug_idx ON communities (slug);


-- ============================================================
-- ROLES & USERS (multi-tenant authentication)
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id          BIGSERIAL    PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE,   -- ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_RESIDENT
    description VARCHAR(255),
    created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO roles (name, description) VALUES
    ('ROLE_SUPER_ADMIN', 'Platform super administrator'),
    ('ROLE_ADMIN',       'HOA community administrator'),
    ('ROLE_RESIDENT',    'HOA resident / homeowner')
ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS users (
    id                            BIGSERIAL    PRIMARY KEY,
    community_id                  BIGINT REFERENCES communities(id) ON DELETE CASCADE,
    email                         VARCHAR(255) NOT NULL,
    password_hash                 VARCHAR(255) NOT NULL,
    first_name                    VARCHAR(100),
    last_name                     VARCHAR(100),
    unit_number                   VARCHAR(50),
    phone                         VARCHAR(50),
    is_active                     BOOLEAN      NOT NULL DEFAULT TRUE,
    is_email_verified             BOOLEAN      NOT NULL DEFAULT FALSE,
    email_verification_token      VARCHAR(255),
    email_verification_expires_at TIMESTAMP,
    created_at                    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at                    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    last_login_at                 TIMESTAMP,
    -- Email must be unique within each community (tenant)
    CONSTRAINT uq_user_email_per_community UNIQUE (community_id, email)
);

CREATE INDEX IF NOT EXISTS users_email_idx     ON users (email);
CREATE INDEX IF NOT EXISTS users_community_idx ON users (community_id);

-- User ↔ Role junction
CREATE TABLE IF NOT EXISTS user_roles (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- Password reset tokens
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id         BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP    NOT NULL,
    used       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS prt_token_idx ON password_reset_tokens (token);

-- JWT refresh tokens
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id         BIGSERIAL    PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token      VARCHAR(512) NOT NULL UNIQUE,
    expires_at TIMESTAMP    NOT NULL,
    revoked    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS rt_token_idx ON refresh_tokens (token);


-- ============================================================
-- DOCUMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS documents (
    id                  BIGSERIAL    PRIMARY KEY,
    community_id        BIGINT       NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    filename            VARCHAR(255) NOT NULL,
    document_type       VARCHAR(50)  NOT NULL,
    file_path           VARCHAR(500) NOT NULL,
    source_type         VARCHAR(20)  NOT NULL DEFAULT 'pdf',  -- pdf, url, etc.
    source_url          TEXT,
    category            VARCHAR(50)  NOT NULL DEFAULT 'general',
    description         TEXT,
    version             VARCHAR(50),
    is_archived         BOOLEAN      NOT NULL DEFAULT FALSE,
    uploaded_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    file_size_bytes     BIGINT,
    mime_type           VARCHAR(100),
    upload_date         TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    processed           BOOLEAN      DEFAULT FALSE,
    created_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_community FOREIGN KEY (community_id) REFERENCES communities(id)
);

CREATE INDEX IF NOT EXISTS documents_community_category_idx
    ON documents (community_id, category)
    WHERE is_archived = FALSE;

-- Document categories reference data
CREATE TABLE IF NOT EXISTS document_categories (
    id    SERIAL       PRIMARY KEY,
    code  VARCHAR(50)  NOT NULL UNIQUE,
    label VARCHAR(100) NOT NULL
);

INSERT INTO document_categories (code, label) VALUES
    ('general',    'General'),
    ('cc-rs',      'CC&Rs'),
    ('bylaws',     'Bylaws'),
    ('financials', 'Financial Documents'),
    ('notices',    'Notices & Announcements'),
    ('minutes',    'Meeting Minutes'),
    ('rules',      'Rules & Regulations'),
    ('forms',      'Forms & Applications')
ON CONFLICT (code) DO NOTHING;

-- Document chunks with vector embeddings
CREATE TABLE IF NOT EXISTS document_chunks (
    id                BIGSERIAL    PRIMARY KEY,
    document_id       BIGINT       NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    chunk_text        TEXT         NOT NULL,
    section_reference VARCHAR(255),
    chunk_index       INTEGER      NOT NULL,
    embedding         vector(1536),
    created_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_document FOREIGN KEY (document_id) REFERENCES documents(id)
);

CREATE INDEX IF NOT EXISTS document_chunks_embedding_idx
    ON document_chunks USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);


-- ============================================================
-- TICKETS, CONVERSATIONS, MESSAGES
-- ============================================================

CREATE TABLE IF NOT EXISTS tickets (
    id                   BIGSERIAL   PRIMARY KEY,
    community_id         BIGINT      NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    submitted_by_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    ticket_type          VARCHAR(50) NOT NULL,
    description          TEXT        NOT NULL,
    location             VARCHAR(255),
    priority             VARCHAR(20) NOT NULL DEFAULT 'normal',
    status               VARCHAR(50) NOT NULL DEFAULT 'open',
    resident_info        TEXT,
    created_at           TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    resolved_at          TIMESTAMP,
    CONSTRAINT fk_ticket_community FOREIGN KEY (community_id) REFERENCES communities(id)
);

CREATE TABLE IF NOT EXISTS conversations (
    id              BIGSERIAL    PRIMARY KEY,
    community_id    BIGINT       NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id         BIGINT REFERENCES users(id) ON DELETE SET NULL,
    session_id      VARCHAR(255) NOT NULL UNIQUE,
    language        VARCHAR(10)  DEFAULT 'en',
    started_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    last_message_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_conversation_community FOREIGN KEY (community_id) REFERENCES communities(id)
);

CREATE TABLE IF NOT EXISTS messages (
    id              BIGSERIAL   PRIMARY KEY,
    conversation_id BIGINT      NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role            VARCHAR(20) NOT NULL,
    content         TEXT        NOT NULL,
    created_at      TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_message_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(id)
);


-- ============================================================
-- FAQs & ANNOUNCEMENTS
-- ============================================================

CREATE TABLE IF NOT EXISTS faqs (
    id           BIGSERIAL    PRIMARY KEY,
    community_id BIGINT       NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    question     TEXT         NOT NULL,
    answer       TEXT         NOT NULL,
    category     VARCHAR(100),
    language     VARCHAR(10)  DEFAULT 'en',
    created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_faq_community FOREIGN KEY (community_id) REFERENCES communities(id)
);

CREATE TABLE IF NOT EXISTS announcements (
    id                BIGSERIAL    PRIMARY KEY,
    community_id      BIGINT       NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    title             VARCHAR(255) NOT NULL,
    content           TEXT         NOT NULL,
    announcement_date DATE         NOT NULL,
    active            BOOLEAN      DEFAULT TRUE,
    created_at        TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_announcement_community FOREIGN KEY (community_id) REFERENCES communities(id)
);


-- ============================================================
-- AUDIT LOG & EMAIL LOG
-- ============================================================

CREATE TABLE IF NOT EXISTS admin_audit_log (
    id           BIGSERIAL    PRIMARY KEY,
    community_id BIGINT       NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id      BIGINT REFERENCES users(id) ON DELETE SET NULL,
    action       VARCHAR(100) NOT NULL,  -- e.g. TICKET_STATUS_CHANGED, RESIDENT_DEACTIVATED
    entity_type  VARCHAR(50),            -- ticket, user, document
    entity_id    BIGINT,
    details      TEXT,                   -- JSON or free-text details
    created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS audit_log_community_idx ON admin_audit_log (community_id, created_at DESC);

CREATE TABLE IF NOT EXISTS email_log (
    id            BIGSERIAL    PRIMARY KEY,
    community_id  BIGINT REFERENCES communities(id) ON DELETE CASCADE,
    recipient     VARCHAR(255) NOT NULL,
    subject       VARCHAR(500) NOT NULL,
    email_type    VARCHAR(100),           -- WELCOME, TICKET_CREATED, TICKET_UPDATED, PASSWORD_RESET
    status        VARCHAR(20)  NOT NULL DEFAULT 'sent',  -- sent, failed
    error_message TEXT,
    created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- PROPERTY MANAGEMENT COMPANIES
-- ============================================================

CREATE TABLE IF NOT EXISTS property_management_companies (
    id              BIGSERIAL    PRIMARY KEY,
    company_name    VARCHAR(255) NOT NULL,
    address         VARCHAR(500),
    city            VARCHAR(100),
    state           VARCHAR(100),
    zip             VARCHAR(20),
    website         VARCHAR(500),
    email           VARCHAR(255),       -- general company email

    -- Company-level phone lines
    phone_main      VARCHAR(50),        -- main office line
    phone_secondary VARCHAR(50),        -- secondary / front-desk line
    phone_mobile    VARCHAR(50),        -- company mobile / on-call

    -- Contact person 1 (primary — e.g. Account Manager)
    contact1_name   VARCHAR(100),
    contact1_title  VARCHAR(100),
    contact1_phone  VARCHAR(50),
    contact1_email  VARCHAR(255),

    -- Contact person 2 (secondary — e.g. Operations)
    contact2_name   VARCHAR(100),
    contact2_title  VARCHAR(100),
    contact2_phone  VARCHAR(50),
    contact2_email  VARCHAR(255),

    -- Contact person 3 (tertiary — e.g. Emergency / After-hours)
    contact3_name   VARCHAR(100),
    contact3_title  VARCHAR(100),
    contact3_phone  VARCHAR(50),
    contact3_email  VARCHAR(255),

    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS pmc_company_name_idx ON property_management_companies (company_name);

-- One community can be managed by different PMCs over time,
-- but only ONE is active at any given moment (enforced by partial unique index).
CREATE TABLE IF NOT EXISTS community_pmc_assignments (
    id            BIGSERIAL PRIMARY KEY,
    community_id  BIGINT    NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    pmc_id        BIGINT    NOT NULL REFERENCES property_management_companies(id) ON DELETE CASCADE,
    is_active     BOOLEAN   NOT NULL DEFAULT TRUE,
    assigned_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    unassigned_at TIMESTAMP,
    notes         TEXT,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS community_one_active_pmc_idx
    ON community_pmc_assignments (community_id)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS cpa_pmc_idx       ON community_pmc_assignments (pmc_id);
CREATE INDEX IF NOT EXISTS cpa_community_idx ON community_pmc_assignments (community_id);


-- ============================================================
-- WIDGET CLIENTS (API key + domain allowlisting)
-- ============================================================

CREATE TABLE IF NOT EXISTS widget_clients (
    id              BIGSERIAL    PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    api_key         VARCHAR(255) NOT NULL UNIQUE,
    allowed_domains TEXT         NOT NULL,   -- comma-separated, e.g. "company-a.com,www.company-a.com"
    active          BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- SEED DATA
-- ============================================================

-- Sample community
INSERT INTO communities (name, time_zone, office_hours, contact_email, contact_phone, payment_portal_url, emergency_contact)
VALUES (
    'Grand Vista HOA',
    'America/Central',
    'Monday-Friday 9:00 AM - 5:00 PM',
    'office@GV.hoa',
    '281-555-0100',
    'https://pay.sunsethills.hoa',
    '281-555-0911'
) ON CONFLICT DO NOTHING;

-- Default admin for sample community
-- Password: Admin@123  (bcrypt hash — change in production!)
WITH community AS (
    SELECT id FROM communities WHERE name = 'Grand Vista HOA' LIMIT 1
)
INSERT INTO users (community_id, email, password_hash, first_name, last_name, is_active, is_email_verified)
SELECT c.id,
       'admin@sunsethills.hoa',
       crypt('Admin@123', gen_salt('bf', 12)),
       'Admin',
       'User',
       TRUE,
       TRUE
FROM community c
ON CONFLICT DO NOTHING;

-- Assign admin role to the seeded admin user
WITH new_user AS (
    SELECT id FROM users WHERE email = 'admin@sunsethills.hoa' LIMIT 1
),
admin_role AS (
    SELECT id FROM roles WHERE name = 'ROLE_ADMIN'
)
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM new_user u, admin_role r
ON CONFLICT DO NOTHING;


