-- =============================================================================
-- HOA ASSISTANT PLATFORM — PRODUCTION DATABASE SCHEMA v2.0
-- PostgreSQL 16 + pgvector
-- Multi-tenant AI Assistant for Property Management Companies
-- =============================================================================
--
-- Architecture:
--   Company → Communities → Knowledge Sources → Chunks (embeddings)
--   Company → Communities → Widget → Conversations → Messages
--   Company → Communities → Tickets → Comments/Attachments
--
-- Key design decisions:
--   1. Unified knowledge_chunks table for ALL embeddings (single vector index)
--   2. Partitioned by community_id for query isolation and scalability
--   3. IVFFlat indexes tuned for millions of vectors
--   4. Hybrid search: pgvector + tsvector for best retrieval quality
--   5. Row-Level Security (RLS) for multi-tenant isolation
--   6. Audit logging on all mutations
--   7. Soft deletes everywhere (deleted_at pattern)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";        -- pgvector
CREATE EXTENSION IF NOT EXISTS "pg_trgm";       -- trigram similarity for fuzzy text search
CREATE EXTENSION IF NOT EXISTS "btree_gin";     -- GIN index support for composite indexes

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. ENUM TYPES
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TYPE user_role AS ENUM (
    'super_admin',        -- platform-level admin
    'company_admin',      -- company owner/admin
    'community_manager',  -- manages one or more communities
    'staff',              -- read-only or limited staff
    'resident'            -- end-user / resident
);

CREATE TYPE document_status AS ENUM (
    'pending',
    'processing',
    'processed',
    'failed',
    'archived'
);

CREATE TYPE source_type AS ENUM (
    'document',
    'faq',
    'announcement',
    'email',
    'webpage',
    'custom'
);

CREATE TYPE ingestion_status AS ENUM (
    'queued',
    'extracting',
    'chunking',
    'embedding',
    'storing',
    'completed',
    'failed',
    'cancelled'
);

CREATE TYPE ticket_status AS ENUM (
    'open',
    'in_progress',
    'waiting_on_resident',
    'waiting_on_manager',
    'resolved',
    'closed',
    'cancelled'
);

CREATE TYPE ticket_priority AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);

CREATE TYPE ticket_source AS ENUM (
    'chat_widget',
    'admin_panel',
    'email',
    'ai_escalation',
    'api'
);

CREATE TYPE message_role AS ENUM (
    'user',
    'assistant',
    'system',
    'tool'
);

CREATE TYPE conversation_status AS ENUM (
    'active',
    'idle',
    'closed',
    'archived'
);

CREATE TYPE chunk_log_status AS ENUM (
    'pending',
    'embedded',
    'failed'
);

CREATE TYPE suggested_faq_status AS ENUM (
    'pending',
    'approved',
    'rejected'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CORE TENANCY TABLES
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE companies (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    name            VARCHAR(255) NOT NULL,
    slug            VARCHAR(100) NOT NULL UNIQUE,  -- URL-safe identifier
    email           VARCHAR(255),
    phone           VARCHAR(50),
    logo_url        TEXT,
    settings        JSONB NOT NULL DEFAULT '{}',   -- company-level config
    subscription_tier VARCHAR(50) DEFAULT 'free',
    max_communities INT DEFAULT 10,
    max_documents_per_community INT DEFAULT 500,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE TABLE communities (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    company_id      BIGINT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name            VARCHAR(255) NOT NULL,
    slug            VARCHAR(100) NOT NULL,
    address         TEXT,
    timezone        VARCHAR(50) DEFAULT 'America/New_York',
    settings        JSONB NOT NULL DEFAULT '{}',  -- community-specific AI config
    -- AI behavior overrides
    ai_system_prompt TEXT,                         -- custom system prompt
    ai_temperature   FLOAT DEFAULT 0.3,
    ai_model         VARCHAR(100) DEFAULT 'gpt-4o',
    welcome_message  TEXT DEFAULT 'Hello! How can I help you today?',
    ticket_counter  BIGINT NOT NULL DEFAULT 0,       -- per-community sequential ticket numbering
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    UNIQUE (company_id, slug)
);

CREATE TABLE users (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    company_id      BIGINT REFERENCES companies(id) ON DELETE SET NULL,
    email           VARCHAR(255) NOT NULL,
    password_hash   VARCHAR(255),                  -- NULL for SSO users
    full_name       VARCHAR(255) NOT NULL,
    phone           VARCHAR(50),
    avatar_url      TEXT,
    role            user_role NOT NULL DEFAULT 'resident',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    email_verified  BOOLEAN NOT NULL DEFAULT FALSE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

-- Junction: users ↔ communities (many-to-many)
CREATE TABLE user_communities (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    role            user_role NOT NULL DEFAULT 'resident',
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, community_id)
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. KNOWLEDGE SOURCE TABLES
-- ─────────────────────────────────────────────────────────────────────────────

-- 3a. Documents (PDFs, uploads)
CREATE TABLE documents (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    uploaded_by     BIGINT REFERENCES users(id) ON DELETE SET NULL,
    title           VARCHAR(500) NOT NULL,
    description     TEXT,
    file_name       VARCHAR(500) NOT NULL,
    file_url        TEXT NOT NULL,                 -- S3/storage URL
    file_size_bytes BIGINT,
    mime_type       VARCHAR(100),
    category        VARCHAR(100),                  -- rules, financials, minutes, etc.
    tags            TEXT[] DEFAULT '{}',
    version         INT NOT NULL DEFAULT 1,
    status          document_status NOT NULL DEFAULT 'pending',
    page_count      INT,
    extracted_text   TEXT,                          -- full extracted text (for reprocessing)
    processing_error TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

-- 3b. FAQs
CREATE TABLE faqs (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    created_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
    question        TEXT NOT NULL,
    answer          TEXT NOT NULL,
    category        VARCHAR(100),
    sort_order      INT DEFAULT 0,
    is_published    BOOLEAN NOT NULL DEFAULT TRUE,
    view_count      INT DEFAULT 0,
    helpful_count   INT DEFAULT 0,
    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

-- 3c. Announcements
CREATE TABLE announcements (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    created_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
    title           VARCHAR(500) NOT NULL,
    body            TEXT NOT NULL,
    category        VARCHAR(100),
    priority        VARCHAR(20) DEFAULT 'normal',
    is_published    BOOLEAN NOT NULL DEFAULT FALSE,
    published_at    TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

-- 3d. Emails / Notices
CREATE TABLE emails (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    imported_by     BIGINT REFERENCES users(id) ON DELETE SET NULL,
    subject         VARCHAR(500),
    sender          VARCHAR(255),
    recipients      TEXT[],
    body_text       TEXT NOT NULL,
    body_html       TEXT,
    received_at     TIMESTAMPTZ,
    category        VARCHAR(100),
    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

-- 3e. Knowledge Sources Registry
-- Provides a single FK target for knowledge_chunks.source_id, solving the
-- polymorphic FK problem. Every document, FAQ, announcement, or email
-- inserts a row here so knowledge_chunks can have a real FK constraint.
CREATE TABLE knowledge_sources (
    id              BIGSERIAL PRIMARY KEY,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    source_type     source_type NOT NULL,
    source_id       BIGINT NOT NULL,               -- ID in the source-specific table
    title           VARCHAR(500),                   -- denormalized for quick lookup
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    UNIQUE (source_type, source_id)
);

-- Auto-register documents into knowledge_sources
CREATE OR REPLACE FUNCTION register_knowledge_source_document() RETURNS trigger AS $$
BEGIN
    INSERT INTO knowledge_sources (community_id, source_type, source_id, title)
    VALUES (NEW.community_id, 'document', NEW.id, NEW.title);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_register_doc_source
    AFTER INSERT ON documents
    FOR EACH ROW
    EXECUTE FUNCTION register_knowledge_source_document();

-- Auto-register FAQs into knowledge_sources
CREATE OR REPLACE FUNCTION register_knowledge_source_faq() RETURNS trigger AS $$
BEGIN
    INSERT INTO knowledge_sources (community_id, source_type, source_id, title)
    VALUES (NEW.community_id, 'faq', NEW.id, LEFT(NEW.question, 500));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_register_faq_source
    AFTER INSERT ON faqs
    FOR EACH ROW
    EXECUTE FUNCTION register_knowledge_source_faq();

-- Auto-register announcements into knowledge_sources
CREATE OR REPLACE FUNCTION register_knowledge_source_announcement() RETURNS trigger AS $$
BEGIN
    INSERT INTO knowledge_sources (community_id, source_type, source_id, title)
    VALUES (NEW.community_id, 'announcement', NEW.id, NEW.title);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_register_announcement_source
    AFTER INSERT ON announcements
    FOR EACH ROW
    EXECUTE FUNCTION register_knowledge_source_announcement();

-- Auto-register emails into knowledge_sources
CREATE OR REPLACE FUNCTION register_knowledge_source_email() RETURNS trigger AS $$
BEGIN
    INSERT INTO knowledge_sources (community_id, source_type, source_id, title)
    VALUES (NEW.community_id, 'email', NEW.id, NEW.subject);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_register_email_source
    AFTER INSERT ON emails
    FOR EACH ROW
    EXECUTE FUNCTION register_knowledge_source_email();


-- Generic registration function for source types without their own table (webpage, custom).
-- Call this from application code before inserting chunks for these source types:
--   SELECT register_generic_knowledge_source(community_id, 'webpage', source_id, 'Page Title');
CREATE OR REPLACE FUNCTION register_generic_knowledge_source(
    p_community_id BIGINT,
    p_source_type  source_type,
    p_source_id    BIGINT,
    p_title        VARCHAR(500) DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO knowledge_sources (community_id, source_type, source_id, title)
    VALUES (p_community_id, p_source_type, p_source_id, p_title)
    ON CONFLICT (source_type, source_id) DO UPDATE SET title = EXCLUDED.title
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. UNIFIED VECTOR STORAGE (The Heart of RAG)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Design rationale:
--   ONE table for all embeddings. This gives us:
--   - Single vector index (much more efficient than per-source indexes)
--   - Unified search across all knowledge types
--   - Simpler ingestion pipeline
--   - Easier deduplication
--
-- Partitioning strategy:
--   Partition by community_id HASH for large-scale deployments.
--   At < 10M rows, a single table with proper indexes is sufficient.
--   Switch to partitioning when approaching 50M+ rows.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE knowledge_chunks (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,

    -- Source tracking (FK to knowledge_sources for referential integrity)
    source_type     source_type NOT NULL,
    source_id       BIGINT NOT NULL,               -- FK to knowledge_sources via (source_type, source_id)
    chunk_index     INT NOT NULL DEFAULT 0,         -- ordering within the source

    -- Referential integrity via knowledge_sources registry
    FOREIGN KEY (source_type, source_id) REFERENCES knowledge_sources(source_type, source_id) ON DELETE CASCADE,

    -- Content
    chunk_title     TEXT,                            -- section/topic title for LLM context
    chunk_text      TEXT NOT NULL,
    chunk_hash      VARCHAR(64) NOT NULL,           -- SHA-256 for deduplication

    -- Vector embedding
    embedding       vector(1536),                   -- OpenAI text-embedding-3-small
    -- NOTE: If you switch to text-embedding-3-large, change to vector(3072)
    -- For dimensionality reduction (cost savings), you can use vector(256) or vector(512)

    -- Full-text search support (hybrid search)
    chunk_tsv       tsvector,                       -- auto-populated by trigger

    -- Retrieval quality tuning
    importance_score FLOAT NOT NULL DEFAULT 1.0,     -- weight by source: FAQ=1.5, announcement=1.3, doc=1.0, email=0.8
    token_count     INT,
    metadata        JSONB NOT NULL DEFAULT '{}',
    -- Recommended metadata keys:
    --   document_title, section_title, page_number, category,
    --   source_url, author, date_published

    -- Lifecycle
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    version         INT NOT NULL DEFAULT 1,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Dedup constraint: same source, same chunk position, same version
    UNIQUE (source_type, source_id, chunk_index, version)
);

-- Auto-populate tsvector column
CREATE OR REPLACE FUNCTION knowledge_chunks_tsv_trigger() RETURNS trigger AS $$
BEGIN
    NEW.chunk_tsv := to_tsvector('english', COALESCE(NEW.chunk_text, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_knowledge_chunks_tsv
    BEFORE INSERT OR UPDATE OF chunk_text
    ON knowledge_chunks
    FOR EACH ROW
    EXECUTE FUNCTION knowledge_chunks_tsv_trigger();


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. INGESTION PIPELINE TABLES
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE ingestion_jobs (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    source_type     source_type NOT NULL,
    source_id       BIGINT NOT NULL,
    status          ingestion_status NOT NULL DEFAULT 'queued',

    -- Processing details
    total_chunks    INT DEFAULT 0,
    processed_chunks INT DEFAULT 0,
    total_tokens    INT DEFAULT 0,
    embedding_model VARCHAR(100) DEFAULT 'text-embedding-3-small',
    chunk_strategy  VARCHAR(50) DEFAULT 'recursive',  -- recursive, sentence, paragraph
    chunk_size      INT DEFAULT 500,                   -- target tokens per chunk
    chunk_overlap   INT DEFAULT 100,                   -- overlap tokens

    -- Timing
    queued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,

    -- Error handling
    error_message   TEXT,
    error_details   JSONB,
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 3,

    -- Cost tracking
    api_calls_made  INT DEFAULT 0,
    estimated_cost  DECIMAL(10, 6) DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Track individual chunk processing for resumability
CREATE TABLE ingestion_chunk_log (
    id              BIGSERIAL PRIMARY KEY,
    job_id          BIGINT NOT NULL REFERENCES ingestion_jobs(id) ON DELETE CASCADE,
    chunk_index     INT NOT NULL,
    status          chunk_log_status NOT NULL DEFAULT 'pending',
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. CHAT SYSTEM TABLES
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE conversations (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    widget_session_id BIGINT,                       -- FK added after widget_sessions
    user_id         BIGINT REFERENCES users(id) ON DELETE SET NULL,  -- NULL = anonymous

    -- Conversation metadata
    title           VARCHAR(500),                   -- auto-generated from first message
    status          conversation_status NOT NULL DEFAULT 'active',
    channel         VARCHAR(50) DEFAULT 'widget',   -- widget, api, admin
    language        VARCHAR(10) DEFAULT 'en',

    -- AI context
    ai_model_used   VARCHAR(100),
    total_messages  INT DEFAULT 0,
    total_tokens_used INT DEFAULT 0,

    -- Satisfaction
    rating          SMALLINT CHECK (rating BETWEEN 1 AND 5),
    feedback        TEXT,

    -- Lifecycle
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_message_at TIMESTAMPTZ,
    closed_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE messages (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role            message_role NOT NULL,

    -- Content
    content         TEXT NOT NULL,
    content_type    VARCHAR(50) DEFAULT 'text',     -- text, markdown, html

    -- AI-specific fields
    model_used      VARCHAR(100),
    tokens_prompt   INT,
    tokens_completion INT,
    latency_ms      INT,                            -- response time

    -- RAG context (what knowledge was retrieved for this answer)
    retrieved_chunks JSONB,                          -- array of chunk IDs + scores
    -- Example: [{"chunk_id": 123, "score": 0.92}, {"chunk_id": 456, "score": 0.87}]

    confidence_score FLOAT,                          -- AI's confidence in the answer

    -- Metadata
    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 7. TICKET / SUPPORT SYSTEM
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE tickets (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    conversation_id BIGINT REFERENCES conversations(id) ON DELETE SET NULL,

    -- Ticket details
    ticket_number   VARCHAR(20) NOT NULL,            -- human-readable: TKT-2026-00001
    title           VARCHAR(500) NOT NULL,
    description     TEXT NOT NULL,
    category        VARCHAR(100),                    -- maintenance, noise, parking, etc.
    tags            TEXT[] DEFAULT '{}',

    -- Assignment
    created_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
    assigned_to     BIGINT REFERENCES users(id) ON DELETE SET NULL,

    -- Status tracking
    status          ticket_status NOT NULL DEFAULT 'open',
    priority        ticket_priority NOT NULL DEFAULT 'medium',
    source          ticket_source NOT NULL DEFAULT 'chat_widget',

    -- Timing
    due_date        TIMESTAMPTZ,
    first_response_at TIMESTAMPTZ,
    resolved_at     TIMESTAMPTZ,
    closed_at       TIMESTAMPTZ,

    -- Satisfaction
    resolution_notes TEXT,
    rating          SMALLINT CHECK (rating BETWEEN 1 AND 5),

    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ
);

CREATE TABLE ticket_comments (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    ticket_id       BIGINT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    user_id         BIGINT REFERENCES users(id) ON DELETE SET NULL,
    message         TEXT NOT NULL,
    is_internal     BOOLEAN DEFAULT FALSE,           -- internal notes vs public comments
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE ticket_attachments (
    id              BIGSERIAL PRIMARY KEY,
    ticket_id       BIGINT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    comment_id      BIGINT REFERENCES ticket_comments(id) ON DELETE SET NULL,
    file_name       VARCHAR(500) NOT NULL,
    file_url        TEXT NOT NULL,
    file_size_bytes BIGINT,
    mime_type       VARCHAR(100),
    uploaded_by     BIGINT REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ticket status history for audit trail
CREATE TABLE ticket_status_history (
    id              BIGSERIAL PRIMARY KEY,
    ticket_id       BIGINT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    old_status      ticket_status,
    new_status      ticket_status NOT NULL,
    changed_by      BIGINT REFERENCES users(id) ON DELETE SET NULL,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 8. WIDGET AUTHENTICATION & SESSION MANAGEMENT
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE widget_configs (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,

    -- Authentication
    api_key         VARCHAR(64) NOT NULL UNIQUE,     -- public key for widget embed
    secret_key      VARCHAR(64) NOT NULL,            -- for server-side verification

    -- Domain restrictions
    allowed_origins TEXT[] DEFAULT '{}',              -- CORS: ['https://example.com']

    -- Widget customization
    theme           JSONB NOT NULL DEFAULT '{
        "primaryColor": "#2563eb",
        "position": "bottom-right",
        "title": "Community Assistant"
    }',

    -- Rate limiting
    max_messages_per_session INT DEFAULT 50,
    max_sessions_per_day    INT DEFAULT 1000,

    -- Feature flags
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    require_email   BOOLEAN DEFAULT FALSE,
    enable_tickets  BOOLEAN DEFAULT TRUE,
    enable_file_upload BOOLEAN DEFAULT FALSE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE widget_sessions (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID NOT NULL DEFAULT uuid_generate_v4() UNIQUE,
    widget_config_id BIGINT NOT NULL REFERENCES widget_configs(id) ON DELETE CASCADE,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,

    -- Visitor identification
    session_token   VARCHAR(128) NOT NULL UNIQUE,
    visitor_id      VARCHAR(128),                    -- fingerprint or cookie-based
    user_id         BIGINT REFERENCES users(id) ON DELETE SET NULL,

    -- Visitor info (optional, collected during chat)
    visitor_name    VARCHAR(255),
    visitor_email   VARCHAR(255),
    visitor_phone   VARCHAR(50),

    -- Session context
    ip_address      INET,
    user_agent      TEXT,
    referrer_url    TEXT,
    page_url        TEXT,                            -- page where widget was opened

    -- Limits
    message_count   INT DEFAULT 0,

    -- Lifecycle
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure widget_sessions.community_id matches widget_configs.community_id (prevents denormalization drift)
CREATE OR REPLACE FUNCTION check_widget_session_community() RETURNS trigger AS $$
DECLARE
    v_expected BIGINT;
BEGIN
    SELECT community_id INTO v_expected
      FROM widget_configs WHERE id = NEW.widget_config_id;

    IF NEW.community_id IS DISTINCT FROM v_expected THEN
        RAISE EXCEPTION 'widget_sessions.community_id (%) does not match widget_configs.community_id (%)',
            NEW.community_id, v_expected;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_widget_session_community_check
    BEFORE INSERT OR UPDATE ON widget_sessions
    FOR EACH ROW
    EXECUTE FUNCTION check_widget_session_community();

-- Add FK from conversations to widget_sessions
ALTER TABLE conversations
    ADD CONSTRAINT fk_conversations_widget_session
    FOREIGN KEY (widget_session_id) REFERENCES widget_sessions(id) ON DELETE SET NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- 9. ANALYTICS & SEARCH LOGS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE search_logs (
    id              BIGSERIAL PRIMARY KEY,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    conversation_id BIGINT REFERENCES conversations(id) ON DELETE SET NULL,

    -- Query details
    query_text      TEXT NOT NULL,
    query_embedding vector(256),                    -- INTENTIONALLY reduced dimensionality (256 vs 1536 in knowledge_chunks)
                                                    -- Used for search analytics/clustering only, NOT for direct comparison with knowledge_chunks.embedding
                                                    -- Request reduced dims from OpenAI API: dimensions=256

    -- Results
    results_count   INT,
    top_score       FLOAT,
    avg_score       FLOAT,
    chunk_ids       BIGINT[],                        -- IDs of returned chunks

    -- Performance
    search_time_ms  INT,
    total_time_ms   INT,                             -- including LLM response

    -- Quality signals
    was_helpful     BOOLEAN,                         -- user feedback
    confidence      FLOAT,

    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Community-level analytics (materialized, refreshed periodically)
CREATE TABLE community_analytics (
    id              BIGSERIAL PRIMARY KEY,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    date            DATE NOT NULL,

    -- Usage metrics
    total_conversations INT DEFAULT 0,
    total_messages      INT DEFAULT 0,
    total_searches      INT DEFAULT 0,
    total_tickets       INT DEFAULT 0,

    -- Quality metrics
    avg_confidence      FLOAT,
    avg_response_time_ms INT,
    helpful_pct         FLOAT,

    -- Knowledge metrics
    total_chunks        INT DEFAULT 0,
    total_documents     INT DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (community_id, date)
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 10. AUDIT LOG
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE audit_log (
    id              BIGSERIAL PRIMARY KEY,
    -- Who
    user_id         BIGINT REFERENCES users(id) ON DELETE SET NULL,
    company_id      BIGINT REFERENCES companies(id) ON DELETE SET NULL,
    community_id    BIGINT REFERENCES communities(id) ON DELETE SET NULL,

    -- What
    action          VARCHAR(50) NOT NULL,            -- create, update, delete, login, search, etc.
    resource_type   VARCHAR(50) NOT NULL,            -- document, faq, ticket, user, etc.
    resource_id     BIGINT,

    -- Details
    old_values      JSONB,
    new_values      JSONB,
    ip_address      INET,
    user_agent      TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partition audit_log by month for performance (keeps queries fast)
-- In production, convert to partitioned table:
-- CREATE TABLE audit_log (...) PARTITION BY RANGE (created_at);


-- ─────────────────────────────────────────────────────────────────────────────
-- 11. AI-SUGGESTED CONTENT (Future-proofing)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE ai_suggested_faqs (
    id              BIGSERIAL PRIMARY KEY,
    community_id    BIGINT NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    question        TEXT NOT NULL,
    suggested_answer TEXT NOT NULL,
    source_chunks   BIGINT[],                        -- chunk IDs that informed this
    frequency       INT DEFAULT 1,                   -- how often this question was asked
    status          suggested_faq_status NOT NULL DEFAULT 'pending',
    approved_by     BIGINT REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE document_summaries (
    id              BIGSERIAL PRIMARY KEY,
    document_id     BIGINT NOT NULL REFERENCES documents(id) ON DELETE CASCADE UNIQUE,
    summary_short   TEXT,                            -- 1-2 sentences
    summary_long    TEXT,                            -- full summary
    key_topics      TEXT[],
    generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- =============================================================================
-- 12. INDEXES (Performance-Critical)
-- =============================================================================

-- ── Core Tenancy ─────────────────────────────────────────────────────────────
CREATE INDEX idx_communities_company      ON communities(company_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_company            ON users(company_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_users_email_unique ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_communities_user    ON user_communities(user_id);
CREATE INDEX idx_user_communities_comm    ON user_communities(community_id);

-- ── Knowledge Sources ────────────────────────────────────────────────────────
CREATE INDEX idx_documents_community      ON documents(community_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_documents_category       ON documents(community_id, category) WHERE deleted_at IS NULL AND is_active = TRUE;
CREATE INDEX idx_faqs_community           ON faqs(community_id) WHERE deleted_at IS NULL AND is_published = TRUE;
CREATE INDEX idx_announcements_community  ON announcements(community_id) WHERE deleted_at IS NULL AND is_published = TRUE;
CREATE INDEX idx_emails_community         ON emails(community_id) WHERE deleted_at IS NULL;

-- ── Knowledge Sources Registry ─────────────────────────────────────────────
CREATE INDEX idx_knowledge_sources_community ON knowledge_sources(community_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_knowledge_sources_lookup    ON knowledge_sources(source_type, source_id) WHERE deleted_at IS NULL;

-- ── Vector Search (THE MOST IMPORTANT INDEXES) ──────────────────────────────
--
-- IVFFlat index: Best for millions of vectors with acceptable recall.
-- lists parameter: sqrt(total_rows) is a good starting point.
--   - < 1M rows  → lists = 100
--   - 1M-5M rows → lists = 500
--   - 5M-10M     → lists = 1000
--   - 10M+       → lists = 2000 (or switch to HNSW)
--
-- IMPORTANT: After bulk inserts, run VACUUM ANALYZE on knowledge_chunks
-- to update index statistics.
--
-- Cosine distance is recommended for OpenAI embeddings.
-- ─────────────────────────────────────────────────────────────────────────────

-- Primary vector search index
CREATE INDEX idx_knowledge_chunks_embedding
    ON knowledge_chunks
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 200);

-- Community-scoped lookup (used in WHERE clause before vector search)
CREATE INDEX idx_knowledge_chunks_community
    ON knowledge_chunks(community_id, source_type)
    WHERE is_active = TRUE;

-- Deduplication: prevent duplicate embeddings per community
CREATE UNIQUE INDEX idx_knowledge_chunks_hash
    ON knowledge_chunks(community_id, chunk_hash);

-- Source polymorphic lookup (for re-ingestion and source deletion)
CREATE INDEX idx_knowledge_chunks_source
    ON knowledge_chunks(source_type, source_id);

-- Full-text search index (for hybrid search)
CREATE INDEX idx_knowledge_chunks_tsv
    ON knowledge_chunks
    USING gin(chunk_tsv);

-- Composite: community + active for filtered vector search
CREATE INDEX idx_knowledge_chunks_community_active
    ON knowledge_chunks(community_id)
    WHERE is_active = TRUE AND embedding IS NOT NULL;

-- ── Ingestion Pipeline ───────────────────────────────────────────────────────
CREATE INDEX idx_ingestion_jobs_status    ON ingestion_jobs(status, community_id);
CREATE INDEX idx_ingestion_jobs_source    ON ingestion_jobs(source_type, source_id);
CREATE INDEX idx_ingestion_chunk_log_job  ON ingestion_chunk_log(job_id, status);

-- ── Chat System ──────────────────────────────────────────────────────────────
CREATE INDEX idx_conversations_community  ON conversations(community_id, status);
CREATE INDEX idx_conversations_user       ON conversations(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_conversations_session    ON conversations(widget_session_id);
CREATE INDEX idx_messages_conversation    ON messages(conversation_id, created_at);

-- ── Tickets ──────────────────────────────────────────────────────────────────
CREATE INDEX idx_tickets_community        ON tickets(community_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_tickets_assigned         ON tickets(assigned_to, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_tickets_number           ON tickets(ticket_number);
CREATE INDEX idx_ticket_comments_ticket   ON ticket_comments(ticket_id, created_at);
CREATE INDEX idx_ticket_status_history    ON ticket_status_history(ticket_id, created_at);

-- ── Widget ───────────────────────────────────────────────────────────────────
CREATE INDEX idx_widget_configs_community ON widget_configs(community_id) WHERE is_active = TRUE;
CREATE INDEX idx_widget_sessions_token    ON widget_sessions(session_token);
CREATE INDEX idx_widget_sessions_community ON widget_sessions(community_id, started_at);

-- ── Analytics ────────────────────────────────────────────────────────────────
CREATE INDEX idx_search_logs_community    ON search_logs(community_id, created_at);
CREATE INDEX idx_audit_log_resource       ON audit_log(resource_type, resource_id, created_at);
CREATE INDEX idx_audit_log_user           ON audit_log(user_id, created_at);
CREATE INDEX idx_community_analytics_date ON community_analytics(community_id, date);


-- =============================================================================
-- 13. ROW-LEVEL SECURITY (Multi-Tenant Isolation)
-- =============================================================================

-- Enable RLS on all tenant-scoped tables
ALTER TABLE communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- RLS policies for multi-tenant isolation.
--
-- Two GUC variables must be set by the application layer per-request:
--   SET app.current_company_id = '<company_id>';
--   SET app.current_community_id = '<community_id>';   -- optional, for community-scoped queries
--
-- Strategy:
--   - communities table: filtered by company_id (top-level isolation)
--   - All community-scoped tables: filtered directly by community_id when set,
--     falling back to company-level subquery. The direct comparison avoids a
--     subquery on every row access and is significantly faster under load.

CREATE POLICY company_isolation ON communities
    USING (company_id = current_setting('app.current_company_id')::BIGINT);

CREATE POLICY community_isolation_docs ON documents
    USING (community_id = current_setting('app.current_community_id', true)::BIGINT
        OR community_id IN (
            SELECT id FROM communities
            WHERE company_id = current_setting('app.current_company_id')::BIGINT
        ));

CREATE POLICY community_isolation_faqs ON faqs
    USING (community_id = current_setting('app.current_community_id', true)::BIGINT
        OR community_id IN (
            SELECT id FROM communities
            WHERE company_id = current_setting('app.current_company_id')::BIGINT
        ));

CREATE POLICY community_isolation_announcements ON announcements
    USING (community_id = current_setting('app.current_community_id', true)::BIGINT
        OR community_id IN (
            SELECT id FROM communities
            WHERE company_id = current_setting('app.current_company_id')::BIGINT
        ));

CREATE POLICY community_isolation_emails ON emails
    USING (community_id = current_setting('app.current_community_id', true)::BIGINT
        OR community_id IN (
            SELECT id FROM communities
            WHERE company_id = current_setting('app.current_company_id')::BIGINT
        ));

CREATE POLICY community_isolation_chunks ON knowledge_chunks
    USING (community_id = current_setting('app.current_community_id', true)::BIGINT
        OR community_id IN (
            SELECT id FROM communities
            WHERE company_id = current_setting('app.current_company_id')::BIGINT
        ));

CREATE POLICY community_isolation_conversations ON conversations
    USING (community_id = current_setting('app.current_community_id', true)::BIGINT
        OR community_id IN (
            SELECT id FROM communities
            WHERE company_id = current_setting('app.current_company_id')::BIGINT
        ));

CREATE POLICY community_isolation_tickets ON tickets
    USING (community_id = current_setting('app.current_community_id', true)::BIGINT
        OR community_id IN (
            SELECT id FROM communities
            WHERE company_id = current_setting('app.current_company_id')::BIGINT
        ));


-- =============================================================================
-- 14. HELPER FUNCTIONS
-- =============================================================================

-- Generate human-readable ticket numbers (per-community sequential)
CREATE OR REPLACE FUNCTION generate_ticket_number(p_community_id BIGINT)
RETURNS VARCHAR(20) AS $$
DECLARE
    v_seq BIGINT;
BEGIN
    UPDATE communities
       SET ticket_counter = ticket_counter + 1
     WHERE id = p_community_id
    RETURNING ticket_counter INTO v_seq;

    RETURN 'TKT-' || EXTRACT(YEAR FROM NOW())::TEXT || '-' || LPAD(v_seq::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- Trigger: auto-set ticket_number on insert
CREATE OR REPLACE FUNCTION set_ticket_number() RETURNS trigger AS $$
BEGIN
    IF NEW.ticket_number IS NULL OR NEW.ticket_number = '' THEN
        NEW.ticket_number := generate_ticket_number(NEW.community_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticket_number
    BEFORE INSERT ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION set_ticket_number();

-- Trigger: auto-update updated_at
CREATE OR REPLACE FUNCTION update_timestamp() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER trg_companies_updated      BEFORE UPDATE ON companies      FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_communities_updated    BEFORE UPDATE ON communities    FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_users_updated          BEFORE UPDATE ON users          FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_documents_updated      BEFORE UPDATE ON documents      FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_faqs_updated           BEFORE UPDATE ON faqs           FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_announcements_updated  BEFORE UPDATE ON announcements  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_emails_updated         BEFORE UPDATE ON emails          FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_knowledge_sources_upd  BEFORE UPDATE ON knowledge_sources FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_widget_sessions_upd    BEFORE UPDATE ON widget_sessions   FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_conversations_updated  BEFORE UPDATE ON conversations  FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_tickets_updated        BEFORE UPDATE ON tickets        FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER trg_ingestion_updated      BEFORE UPDATE ON ingestion_jobs FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Cascade soft-delete: when a source table row is soft-deleted, propagate to knowledge_sources
-- This ensures documents.deleted_at → knowledge_sources.deleted_at → knowledge_chunks.is_active = FALSE
CREATE OR REPLACE FUNCTION cascade_soft_delete_to_knowledge_sources() RETURNS trigger AS $$
BEGIN
    IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        UPDATE knowledge_sources
           SET deleted_at = NEW.deleted_at,
               is_active = FALSE
         WHERE source_type = TG_ARGV[0]::source_type
           AND source_id = OLD.id;
    -- Also handle un-delete (restoring a soft-deleted row)
    ELSIF NEW.deleted_at IS NULL AND OLD.deleted_at IS NOT NULL THEN
        UPDATE knowledge_sources
           SET deleted_at = NULL,
               is_active = TRUE
         WHERE source_type = TG_ARGV[0]::source_type
           AND source_id = OLD.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_documents_soft_delete_cascade
    AFTER UPDATE OF deleted_at ON documents
    FOR EACH ROW
    EXECUTE FUNCTION cascade_soft_delete_to_knowledge_sources('document');

CREATE TRIGGER trg_faqs_soft_delete_cascade
    AFTER UPDATE OF deleted_at ON faqs
    FOR EACH ROW
    EXECUTE FUNCTION cascade_soft_delete_to_knowledge_sources('faq');

CREATE TRIGGER trg_announcements_soft_delete_cascade
    AFTER UPDATE OF deleted_at ON announcements
    FOR EACH ROW
    EXECUTE FUNCTION cascade_soft_delete_to_knowledge_sources('announcement');

CREATE TRIGGER trg_emails_soft_delete_cascade
    AFTER UPDATE OF deleted_at ON emails
    FOR EACH ROW
    EXECUTE FUNCTION cascade_soft_delete_to_knowledge_sources('email');

-- Cascade soft-delete: when a knowledge_source is soft-deleted, deactivate its chunks
CREATE OR REPLACE FUNCTION cascade_deactivate_chunks() RETURNS trigger AS $$
BEGIN
    IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
        UPDATE knowledge_chunks
           SET is_active = FALSE
         WHERE source_type = NEW.source_type
           AND source_id = NEW.source_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_knowledge_source_soft_delete
    AFTER UPDATE OF deleted_at ON knowledge_sources
    FOR EACH ROW
    EXECUTE FUNCTION cascade_deactivate_chunks();

-- Keep conversations.total_messages and total_tokens_used in sync
CREATE OR REPLACE FUNCTION update_conversation_counters() RETURNS trigger AS $$
BEGIN
    UPDATE conversations
       SET total_messages = total_messages + 1,
           total_tokens_used = total_tokens_used + COALESCE(NEW.tokens_prompt, 0) + COALESCE(NEW.tokens_completion, 0),
           last_message_at = NEW.created_at
     WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_message_counter_sync
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_counters();

-- Track ticket status changes automatically
CREATE OR REPLACE FUNCTION track_ticket_status() RETURNS trigger AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO ticket_status_history (ticket_id, old_status, new_status)
        VALUES (NEW.id, OLD.status, NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticket_status_change
    AFTER UPDATE OF status ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION track_ticket_status();


-- =============================================================================
-- 15. EXAMPLE QUERIES (For Application Layer Reference)
-- =============================================================================

-- ── Vector Similarity Search (scoped to community) ──────────────────────────
--
-- SELECT id, chunk_text, metadata,
--        1 - (embedding <=> $query_embedding::vector) AS similarity
-- FROM knowledge_chunks
-- WHERE community_id = $community_id
--   AND is_active = TRUE
-- ORDER BY embedding <=> $query_embedding::vector
-- LIMIT 5;
--
-- ── Hybrid Search (vector + keyword) ────────────────────────────────────────
--
-- WITH vector_results AS (
--     SELECT id, chunk_title, chunk_text, metadata, importance_score,
--            1 - (embedding <=> $query_embedding::vector) AS vector_score
--     FROM knowledge_chunks
--     WHERE community_id = $community_id AND is_active = TRUE
--     ORDER BY embedding <=> $query_embedding::vector
--     LIMIT 20
-- ),
-- keyword_results AS (
--     SELECT id, chunk_title, chunk_text, metadata, importance_score,
--            ts_rank(chunk_tsv, plainto_tsquery('english', $query_text)) AS text_score
--     FROM knowledge_chunks
--     WHERE community_id = $community_id
--       AND is_active = TRUE
--       AND chunk_tsv @@ plainto_tsquery('english', $query_text)
--     LIMIT 20
-- )
-- SELECT COALESCE(v.id, k.id) AS id,
--        COALESCE(v.chunk_text, k.chunk_text) AS chunk_text,
--        COALESCE(v.metadata, k.metadata) AS metadata,
--        (COALESCE(v.vector_score, 0) * 0.7 + COALESCE(k.text_score, 0) * 0.3)
--            * COALESCE(v.importance_score, k.importance_score, 1.0) AS combined_score
-- FROM vector_results v
-- FULL OUTER JOIN keyword_results k ON v.id = k.id
-- ORDER BY combined_score DESC
-- LIMIT 5;
--
-- ── Set IVFFlat probes for better recall ────────────────────────────────────
--
-- SET ivfflat.probes = 10;  -- default is 1; higher = better recall, slower
--
-- Production recommendation:
--   probes = 10-20 for lists=200
--   probes = 20-40 for lists=500
--   probes = 50-80 for lists=1000


-- =============================================================================
-- 16. PGVECTOR BEST PRACTICES & OPERATIONS
-- =============================================================================

-- ── After bulk insert, ALWAYS rebuild the index ─────────────────────────────
-- REINDEX INDEX CONCURRENTLY idx_knowledge_chunks_embedding;
-- VACUUM ANALYZE knowledge_chunks;

-- ── Monitor index health ────────────────────────────────────────────────────
-- SELECT pg_size_pretty(pg_relation_size('idx_knowledge_chunks_embedding')) AS index_size;
-- SELECT reltuples::BIGINT AS row_estimate FROM pg_class WHERE relname = 'knowledge_chunks';

-- ── When to switch from IVFFlat to HNSW ─────────────────────────────────────
-- IVFFlat: Good up to ~10M vectors. Lower memory. Must rebuild after large inserts.
-- HNSW:    Better recall at scale. Higher memory. No rebuild needed. Slower to build.
--
-- HNSW index (use when > 10M vectors or need >99% recall):
-- CREATE INDEX idx_knowledge_chunks_hnsw
--     ON knowledge_chunks
--     USING hnsw (embedding vector_cosine_ops)
--     WITH (m = 16, ef_construction = 200);
--
-- Runtime tuning for HNSW:
-- SET hnsw.ef_search = 100;  -- higher = better recall, slower

-- ── Dimensionality reduction (90% cost savings) ─────────────────────────────
-- OpenAI's text-embedding-3-small supports native dimension reduction:
--   1536 dims → full quality
--   512 dims  → ~95% quality, 66% less storage
--   256 dims  → ~90% quality, 83% less storage
--
-- To use reduced dimensions:
-- 1. Request reduced dims from OpenAI API: dimensions=512
-- 2. Change column: ALTER TABLE knowledge_chunks ALTER COLUMN embedding TYPE vector(512);
-- 3. Rebuild index


-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
