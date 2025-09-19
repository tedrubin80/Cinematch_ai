--
-- PostgreSQL database dump
--

-- Dumped from database version 16.9 (Ubuntu 16.9-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.9 (Ubuntu 16.9-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_audit_logs; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.admin_audit_logs (
    id uuid NOT NULL,
    user_id uuid,
    action character varying(255) NOT NULL,
    details jsonb,
    ip_address character varying(45),
    user_agent character varying(255),
    "timestamp" timestamp without time zone
);


ALTER TABLE public.admin_audit_logs OWNER TO cinematch_user;

--
-- Name: age_verifications; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.age_verifications (
    id uuid NOT NULL,
    session_id character varying(255) NOT NULL,
    ip_address character varying(45),
    age integer,
    is_verified boolean,
    verification_method character varying(50),
    verified_at timestamp without time zone,
    expires_at timestamp without time zone,
    user_agent text,
    verification_token character varying(128),
    attempts integer,
    country_code character varying(2),
    region character varying(100)
);


ALTER TABLE public.age_verifications OWNER TO cinematch_user;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO cinematch_user;

--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.api_keys (
    id uuid NOT NULL,
    service character varying(50) NOT NULL,
    encrypted_key text NOT NULL,
    is_active boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    updated_by uuid
);


ALTER TABLE public.api_keys OWNER TO cinematch_user;

--
-- Name: chat_logs; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.chat_logs (
    id uuid NOT NULL,
    session_id character varying(64),
    user_input text,
    bot_response text,
    llm_used character varying(50),
    content_rating character varying(20),
    response_time_ms integer,
    created_at timestamp without time zone
);


ALTER TABLE public.chat_logs OWNER TO cinematch_user;

--
-- Name: content_filters; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.content_filters (
    id uuid NOT NULL,
    name character varying(100) NOT NULL,
    category character varying(50) NOT NULL,
    filter_type character varying(20) NOT NULL,
    pattern text,
    model_name character varying(100),
    threshold double precision,
    action character varying(50),
    replacement_text character varying(200),
    warning_message character varying(500),
    severity character varying(20),
    description text,
    enabled boolean,
    version character varying(20),
    created_by uuid,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.content_filters OWNER TO cinematch_user;

--
-- Name: content_keywords; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.content_keywords (
    id uuid NOT NULL,
    category character varying(50) NOT NULL,
    keyword character varying(100) NOT NULL,
    weight double precision,
    active boolean,
    created_at timestamp without time zone,
    created_by uuid
);


ALTER TABLE public.content_keywords OWNER TO cinematch_user;

--
-- Name: content_routing_rules; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.content_routing_rules (
    id uuid NOT NULL,
    rule_name character varying(100) NOT NULL,
    condition_type character varying(50),
    condition_value text,
    target_llm character varying(50),
    priority integer,
    active boolean,
    created_at timestamp without time zone,
    created_by uuid
);


ALTER TABLE public.content_routing_rules OWNER TO cinematch_user;

--
-- Name: custom_routes; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.custom_routes (
    id uuid NOT NULL,
    name character varying(100),
    path character varying(255),
    method character varying(10),
    description text,
    action_type character varying(50),
    configuration jsonb,
    requires_auth boolean,
    rate_limit integer,
    active boolean,
    created_at timestamp without time zone,
    created_by uuid
);


ALTER TABLE public.custom_routes OWNER TO cinematch_user;

--
-- Name: indexed_sites; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.indexed_sites (
    id uuid NOT NULL,
    url character varying(500) NOT NULL,
    domain character varying(255) NOT NULL,
    title character varying(500),
    content text,
    site_metadata jsonb,
    last_indexed timestamp without time zone,
    index_frequency integer,
    active boolean,
    created_at timestamp without time zone
);


ALTER TABLE public.indexed_sites OWNER TO cinematch_user;

--
-- Name: movie_documents; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.movie_documents (
    id uuid NOT NULL,
    source_type character varying(50),
    source_id character varying(500),
    title character varying(500) NOT NULL,
    content text,
    doc_metadata jsonb,
    embedding public.vector(1536),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.movie_documents OWNER TO cinematch_user;

--
-- Name: parameter_usage; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.parameter_usage (
    id uuid NOT NULL,
    session_id character varying(255),
    user_id uuid,
    temperature numeric(3,2),
    top_k integer,
    max_tokens integer,
    presence_penalty numeric(3,2),
    frequency_penalty numeric(3,2),
    preset_used character varying(50),
    preset_version character varying(20),
    query_type character varying(50),
    message_count integer,
    conversation_length integer,
    response_time integer,
    token_count integer,
    cost numeric(10,4),
    user_rating integer,
    user_feedback character varying(500),
    "timestamp" timestamp without time zone
);


ALTER TABLE public.parameter_usage OWNER TO cinematch_user;

--
-- Name: payment_methods; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.payment_methods (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    stripe_payment_method_id character varying(100) NOT NULL,
    card_brand character varying(20),
    card_last4 character varying(4),
    card_exp_month integer,
    card_exp_year integer,
    is_default boolean,
    is_active boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.payment_methods OWNER TO cinematch_user;

--
-- Name: rate_limit_logs; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.rate_limit_logs (
    id uuid NOT NULL,
    user_id uuid,
    ip_address character varying(45),
    endpoint character varying(200),
    user_tier character varying(20),
    rate_limit integer,
    current_usage integer,
    user_agent character varying(255),
    referer character varying(255),
    "timestamp" timestamp without time zone
);


ALTER TABLE public.rate_limit_logs OWNER TO cinematch_user;

--
-- Name: routing_configurations; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.routing_configurations (
    id uuid NOT NULL,
    use_claude_threshold double precision,
    use_gemini_threshold double precision,
    content_length_threshold integer,
    enable_cross_validation boolean,
    cross_validation_keywords jsonb,
    updated_at timestamp without time zone,
    updated_by uuid
);


ALTER TABLE public.routing_configurations OWNER TO cinematch_user;

--
-- Name: s3_knowledge_base; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.s3_knowledge_base (
    id uuid NOT NULL,
    s3_key character varying(500) NOT NULL,
    filename character varying(255),
    content_type character varying(100),
    size bigint,
    indexed boolean,
    last_indexed timestamp without time zone,
    created_at timestamp without time zone
);


ALTER TABLE public.s3_knowledge_base OWNER TO cinematch_user;

--
-- Name: safety_logs; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.safety_logs (
    id uuid NOT NULL,
    session_id character varying(64),
    input_hash character varying(64),
    safe boolean,
    reason character varying(255),
    severity character varying(20),
    action character varying(20),
    "timestamp" timestamp without time zone
);


ALTER TABLE public.safety_logs OWNER TO cinematch_user;

--
-- Name: safety_reports; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.safety_reports (
    id uuid NOT NULL,
    report_type character varying(50) NOT NULL,
    period_start timestamp without time zone NOT NULL,
    period_end timestamp without time zone NOT NULL,
    total_interactions integer,
    total_violations integer,
    blocked_content integer,
    warnings_issued integer,
    false_positives integer,
    violations_by_category jsonb,
    violations_by_severity jsonb,
    compliance_score double precision,
    regulatory_notes text,
    generated_at timestamp without time zone,
    generated_by uuid
);


ALTER TABLE public.safety_reports OWNER TO cinematch_user;

--
-- Name: safety_violations; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.safety_violations (
    id uuid NOT NULL,
    session_id character varying(255),
    user_id uuid,
    violation_type character varying(100) NOT NULL,
    severity character varying(20),
    category character varying(50),
    content_sample text,
    content_hash character varying(64),
    input_type character varying(20),
    endpoint character varying(200),
    message_id character varying(100),
    conversation_id character varying(100),
    detection_method character varying(50),
    confidence_score double precision,
    detector_version character varying(20),
    action_taken character varying(100),
    auto_resolved boolean,
    manual_review_required boolean,
    ip_address character varying(45),
    user_agent text,
    "timestamp" timestamp without time zone,
    resolved_at timestamp without time zone
);


ALTER TABLE public.safety_violations OWNER TO cinematch_user;

--
-- Name: security_logs; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.security_logs (
    id uuid NOT NULL,
    event_type character varying(50),
    ip_address character varying(45),
    user_agent character varying(255),
    details jsonb,
    severity character varying(20),
    "timestamp" timestamp without time zone
);


ALTER TABLE public.security_logs OWNER TO cinematch_user;

--
-- Name: sessions; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.sessions (
    id character varying(64) NOT NULL,
    user_id uuid,
    age_verified boolean,
    age_verified_at timestamp without time zone,
    created_at timestamp without time zone,
    last_activity timestamp without time zone,
    ip_address character varying(45),
    user_agent character varying(255)
);


ALTER TABLE public.sessions OWNER TO cinematch_user;

--
-- Name: subscription_events; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.subscription_events (
    id uuid NOT NULL,
    user_id uuid,
    stripe_event_id character varying(100) NOT NULL,
    event_type character varying(50) NOT NULL,
    event_data jsonb,
    processed boolean,
    processing_error text,
    created_at timestamp without time zone,
    processed_at timestamp without time zone
);


ALTER TABLE public.subscription_events OWNER TO cinematch_user;

--
-- Name: usage_tracking; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.usage_tracking (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    query_date date NOT NULL,
    query_count integer,
    query_type character varying(50),
    agents_used jsonb,
    total_tokens integer,
    total_cost numeric(10,4),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.usage_tracking OWNER TO cinematch_user;

--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.user_preferences (
    id uuid NOT NULL,
    user_id uuid,
    theme character varying(50),
    custom_theme jsonb,
    language character varying(10),
    notifications_enabled boolean,
    updated_at timestamp without time zone
);


ALTER TABLE public.user_preferences OWNER TO cinematch_user;

--
-- Name: user_subscriptions; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.user_subscriptions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    tier character varying(20) NOT NULL,
    stripe_customer_id character varying(100),
    stripe_subscription_id character varying(100),
    stripe_price_id character varying(100),
    status character varying(20),
    current_period_start timestamp without time zone,
    current_period_end timestamp without time zone,
    cancel_at_period_end boolean,
    cancelled_at timestamp without time zone,
    trial_start timestamp without time zone,
    trial_end timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


ALTER TABLE public.user_subscriptions OWNER TO cinematch_user;

--
-- Name: users; Type: TABLE; Schema: public; Owner: cinematch_user
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    username character varying(80) NOT NULL,
    email character varying(120) NOT NULL,
    password_hash character varying(255),
    is_admin boolean,
    is_active boolean,
    is_verified boolean,
    verification_token character varying(100),
    verification_token_expiry timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    last_login timestamp without time zone,
    failed_login_attempts integer,
    account_locked_until timestamp without time zone,
    reset_token character varying(100),
    reset_token_expiry timestamp without time zone,
    two_factor_secret character varying(32),
    two_factor_enabled boolean
);


ALTER TABLE public.users OWNER TO cinematch_user;

--
-- Data for Name: admin_audit_logs; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.admin_audit_logs (id, user_id, action, details, ip_address, user_agent, "timestamp") FROM stdin;
\.


--
-- Data for Name: age_verifications; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.age_verifications (id, session_id, ip_address, age, is_verified, verification_method, verified_at, expires_at, user_agent, verification_token, attempts, country_code, region) FROM stdin;
\.


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.alembic_version (version_num) FROM stdin;
a24832406f92
\.


--
-- Data for Name: api_keys; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.api_keys (id, service, encrypted_key, is_active, created_at, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: chat_logs; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.chat_logs (id, session_id, user_input, bot_response, llm_used, content_rating, response_time_ms, created_at) FROM stdin;
\.


--
-- Data for Name: content_filters; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.content_filters (id, name, category, filter_type, pattern, model_name, threshold, action, replacement_text, warning_message, severity, description, enabled, version, created_by, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: content_keywords; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.content_keywords (id, category, keyword, weight, active, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: content_routing_rules; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.content_routing_rules (id, rule_name, condition_type, condition_value, target_llm, priority, active, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: custom_routes; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.custom_routes (id, name, path, method, description, action_type, configuration, requires_auth, rate_limit, active, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: indexed_sites; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.indexed_sites (id, url, domain, title, content, site_metadata, last_indexed, index_frequency, active, created_at) FROM stdin;
\.


--
-- Data for Name: movie_documents; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.movie_documents (id, source_type, source_id, title, content, doc_metadata, embedding, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: parameter_usage; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.parameter_usage (id, session_id, user_id, temperature, top_k, max_tokens, presence_penalty, frequency_penalty, preset_used, preset_version, query_type, message_count, conversation_length, response_time, token_count, cost, user_rating, user_feedback, "timestamp") FROM stdin;
\.


--
-- Data for Name: payment_methods; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.payment_methods (id, user_id, stripe_payment_method_id, card_brand, card_last4, card_exp_month, card_exp_year, is_default, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: rate_limit_logs; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.rate_limit_logs (id, user_id, ip_address, endpoint, user_tier, rate_limit, current_usage, user_agent, referer, "timestamp") FROM stdin;
\.


--
-- Data for Name: routing_configurations; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.routing_configurations (id, use_claude_threshold, use_gemini_threshold, content_length_threshold, enable_cross_validation, cross_validation_keywords, updated_at, updated_by) FROM stdin;
\.


--
-- Data for Name: s3_knowledge_base; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.s3_knowledge_base (id, s3_key, filename, content_type, size, indexed, last_indexed, created_at) FROM stdin;
\.


--
-- Data for Name: safety_logs; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.safety_logs (id, session_id, input_hash, safe, reason, severity, action, "timestamp") FROM stdin;
\.


--
-- Data for Name: safety_reports; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.safety_reports (id, report_type, period_start, period_end, total_interactions, total_violations, blocked_content, warnings_issued, false_positives, violations_by_category, violations_by_severity, compliance_score, regulatory_notes, generated_at, generated_by) FROM stdin;
\.


--
-- Data for Name: safety_violations; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.safety_violations (id, session_id, user_id, violation_type, severity, category, content_sample, content_hash, input_type, endpoint, message_id, conversation_id, detection_method, confidence_score, detector_version, action_taken, auto_resolved, manual_review_required, ip_address, user_agent, "timestamp", resolved_at) FROM stdin;
\.


--
-- Data for Name: security_logs; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.security_logs (id, event_type, ip_address, user_agent, details, severity, "timestamp") FROM stdin;
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.sessions (id, user_id, age_verified, age_verified_at, created_at, last_activity, ip_address, user_agent) FROM stdin;
\.


--
-- Data for Name: subscription_events; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.subscription_events (id, user_id, stripe_event_id, event_type, event_data, processed, processing_error, created_at, processed_at) FROM stdin;
\.


--
-- Data for Name: usage_tracking; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.usage_tracking (id, user_id, query_date, query_count, query_type, agents_used, total_tokens, total_cost, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.user_preferences (id, user_id, theme, custom_theme, language, notifications_enabled, updated_at) FROM stdin;
\.


--
-- Data for Name: user_subscriptions; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.user_subscriptions (id, user_id, tier, stripe_customer_id, stripe_subscription_id, stripe_price_id, status, current_period_start, current_period_end, cancel_at_period_end, cancelled_at, trial_start, trial_end, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: cinematch_user
--

COPY public.users (id, username, email, password_hash, is_admin, is_active, is_verified, verification_token, verification_token_expiry, created_at, updated_at, last_login, failed_login_attempts, account_locked_until, reset_token, reset_token_expiry, two_factor_secret, two_factor_enabled) FROM stdin;
7b6a8e57-e5aa-4bcd-bd55-e0432b2df61e	testuser	testuser@example.com	pbkdf2:sha256:600000$a21Cour1vWu03Lvx$28311ab913dd445b2129507dbfc74b93daa573fe7e593ebee3064a9abd1e632b	f	t	\N	\N	\N	2025-08-26 00:09:13.233206	2025-08-26 00:09:29.212628	2025-08-26 00:09:29.209442	\N	\N	\N	\N	\N	\N
919cc2c5-1333-4815-9fae-6be3d79a2ee1	cinema_admin	admin@example.com	pbkdf2:sha256:600000$ZsLTPe2TFksjuBnL$064f2de7c3594f77a868172a996c50b99321c6206fcd52c233854f246c130f44	t	t	\N	\N	\N	2025-08-25 23:58:58.752502	2025-08-26 00:09:39.134571	2025-08-26 00:09:39.1316	\N	\N	\N	\N	\N	\N
\.


--
-- Name: admin_audit_logs admin_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.admin_audit_logs
    ADD CONSTRAINT admin_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: age_verifications age_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.age_verifications
    ADD CONSTRAINT age_verifications_pkey PRIMARY KEY (id);


--
-- Name: age_verifications age_verifications_session_id_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.age_verifications
    ADD CONSTRAINT age_verifications_session_id_key UNIQUE (session_id);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: chat_logs chat_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.chat_logs
    ADD CONSTRAINT chat_logs_pkey PRIMARY KEY (id);


--
-- Name: content_filters content_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.content_filters
    ADD CONSTRAINT content_filters_pkey PRIMARY KEY (id);


--
-- Name: content_keywords content_keywords_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.content_keywords
    ADD CONSTRAINT content_keywords_pkey PRIMARY KEY (id);


--
-- Name: content_routing_rules content_routing_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.content_routing_rules
    ADD CONSTRAINT content_routing_rules_pkey PRIMARY KEY (id);


--
-- Name: custom_routes custom_routes_name_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.custom_routes
    ADD CONSTRAINT custom_routes_name_key UNIQUE (name);


--
-- Name: custom_routes custom_routes_path_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.custom_routes
    ADD CONSTRAINT custom_routes_path_key UNIQUE (path);


--
-- Name: custom_routes custom_routes_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.custom_routes
    ADD CONSTRAINT custom_routes_pkey PRIMARY KEY (id);


--
-- Name: indexed_sites indexed_sites_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.indexed_sites
    ADD CONSTRAINT indexed_sites_pkey PRIMARY KEY (id);


--
-- Name: indexed_sites indexed_sites_url_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.indexed_sites
    ADD CONSTRAINT indexed_sites_url_key UNIQUE (url);


--
-- Name: movie_documents movie_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.movie_documents
    ADD CONSTRAINT movie_documents_pkey PRIMARY KEY (id);


--
-- Name: parameter_usage parameter_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.parameter_usage
    ADD CONSTRAINT parameter_usage_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_stripe_payment_method_id_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_stripe_payment_method_id_key UNIQUE (stripe_payment_method_id);


--
-- Name: rate_limit_logs rate_limit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.rate_limit_logs
    ADD CONSTRAINT rate_limit_logs_pkey PRIMARY KEY (id);


--
-- Name: routing_configurations routing_configurations_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.routing_configurations
    ADD CONSTRAINT routing_configurations_pkey PRIMARY KEY (id);


--
-- Name: s3_knowledge_base s3_knowledge_base_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.s3_knowledge_base
    ADD CONSTRAINT s3_knowledge_base_pkey PRIMARY KEY (id);


--
-- Name: s3_knowledge_base s3_knowledge_base_s3_key_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.s3_knowledge_base
    ADD CONSTRAINT s3_knowledge_base_s3_key_key UNIQUE (s3_key);


--
-- Name: safety_logs safety_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.safety_logs
    ADD CONSTRAINT safety_logs_pkey PRIMARY KEY (id);


--
-- Name: safety_reports safety_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_pkey PRIMARY KEY (id);


--
-- Name: safety_violations safety_violations_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.safety_violations
    ADD CONSTRAINT safety_violations_pkey PRIMARY KEY (id);


--
-- Name: security_logs security_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.security_logs
    ADD CONSTRAINT security_logs_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: subscription_events subscription_events_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.subscription_events
    ADD CONSTRAINT subscription_events_pkey PRIMARY KEY (id);


--
-- Name: subscription_events subscription_events_stripe_event_id_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.subscription_events
    ADD CONSTRAINT subscription_events_stripe_event_id_key UNIQUE (stripe_event_id);


--
-- Name: usage_tracking unique_user_date; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.usage_tracking
    ADD CONSTRAINT unique_user_date UNIQUE (user_id, query_date);


--
-- Name: usage_tracking usage_tracking_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.usage_tracking
    ADD CONSTRAINT usage_tracking_pkey PRIMARY KEY (id);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (id);


--
-- Name: user_preferences user_preferences_user_id_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_user_id_key UNIQUE (user_id);


--
-- Name: user_subscriptions user_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: user_subscriptions user_subscriptions_stripe_customer_id_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_stripe_customer_id_key UNIQUE (stripe_customer_id);


--
-- Name: user_subscriptions user_subscriptions_stripe_subscription_id_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_stripe_subscription_id_key UNIQUE (stripe_subscription_id);


--
-- Name: user_subscriptions user_subscriptions_user_id_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_key UNIQUE (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_reset_token_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_reset_token_key UNIQUE (reset_token);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: users users_verification_token_key; Type: CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_verification_token_key UNIQUE (verification_token);


--
-- Name: idx_age_verification_ip; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_age_verification_ip ON public.age_verifications USING btree (ip_address);


--
-- Name: idx_age_verification_session; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_age_verification_session ON public.age_verifications USING btree (session_id);


--
-- Name: idx_age_verification_verified_at; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_age_verification_verified_at ON public.age_verifications USING btree (verified_at);


--
-- Name: idx_content_filter_category; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_content_filter_category ON public.content_filters USING btree (category);


--
-- Name: idx_content_filter_enabled; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_content_filter_enabled ON public.content_filters USING btree (enabled);


--
-- Name: idx_parameter_usage_preset; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_parameter_usage_preset ON public.parameter_usage USING btree (preset_used);


--
-- Name: idx_parameter_usage_session; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_parameter_usage_session ON public.parameter_usage USING btree (session_id);


--
-- Name: idx_parameter_usage_timestamp; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_parameter_usage_timestamp ON public.parameter_usage USING btree ("timestamp");


--
-- Name: idx_parameter_usage_user; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_parameter_usage_user ON public.parameter_usage USING btree (user_id);


--
-- Name: idx_payment_method_user_id; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_payment_method_user_id ON public.payment_methods USING btree (user_id);


--
-- Name: idx_rate_limit_log_timestamp; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_rate_limit_log_timestamp ON public.rate_limit_logs USING btree ("timestamp");


--
-- Name: idx_rate_limit_log_user_timestamp; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_rate_limit_log_user_timestamp ON public.rate_limit_logs USING btree (user_id, "timestamp");


--
-- Name: idx_safety_report_period; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_safety_report_period ON public.safety_reports USING btree (period_start, period_end);


--
-- Name: idx_safety_report_type; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_safety_report_type ON public.safety_reports USING btree (report_type);


--
-- Name: idx_safety_violation_session; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_safety_violation_session ON public.safety_violations USING btree (session_id);


--
-- Name: idx_safety_violation_severity; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_safety_violation_severity ON public.safety_violations USING btree (severity);


--
-- Name: idx_safety_violation_timestamp; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_safety_violation_timestamp ON public.safety_violations USING btree ("timestamp");


--
-- Name: idx_safety_violation_type; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_safety_violation_type ON public.safety_violations USING btree (violation_type);


--
-- Name: idx_safety_violation_unresolved; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_safety_violation_unresolved ON public.safety_violations USING btree (manual_review_required);


--
-- Name: idx_safety_violation_user; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_safety_violation_user ON public.safety_violations USING btree (user_id);


--
-- Name: idx_subscription_event_processed; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_subscription_event_processed ON public.subscription_events USING btree (processed);


--
-- Name: idx_subscription_event_type; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_subscription_event_type ON public.subscription_events USING btree (event_type);


--
-- Name: idx_usage_tracking_date; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_usage_tracking_date ON public.usage_tracking USING btree (query_date);


--
-- Name: idx_usage_tracking_user_date; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_usage_tracking_user_date ON public.usage_tracking USING btree (user_id, query_date);


--
-- Name: idx_user_subscription_status; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_user_subscription_status ON public.user_subscriptions USING btree (status);


--
-- Name: idx_user_subscription_stripe_customer; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_user_subscription_stripe_customer ON public.user_subscriptions USING btree (stripe_customer_id);


--
-- Name: idx_user_subscription_user_id; Type: INDEX; Schema: public; Owner: cinematch_user
--

CREATE INDEX idx_user_subscription_user_id ON public.user_subscriptions USING btree (user_id);


--
-- Name: admin_audit_logs admin_audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.admin_audit_logs
    ADD CONSTRAINT admin_audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: api_keys api_keys_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: chat_logs chat_logs_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.chat_logs
    ADD CONSTRAINT chat_logs_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id);


--
-- Name: content_filters content_filters_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.content_filters
    ADD CONSTRAINT content_filters_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: content_keywords content_keywords_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.content_keywords
    ADD CONSTRAINT content_keywords_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: content_routing_rules content_routing_rules_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.content_routing_rules
    ADD CONSTRAINT content_routing_rules_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: custom_routes custom_routes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.custom_routes
    ADD CONSTRAINT custom_routes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: parameter_usage parameter_usage_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.parameter_usage
    ADD CONSTRAINT parameter_usage_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: payment_methods payment_methods_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: rate_limit_logs rate_limit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.rate_limit_logs
    ADD CONSTRAINT rate_limit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: routing_configurations routing_configurations_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.routing_configurations
    ADD CONSTRAINT routing_configurations_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: safety_logs safety_logs_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.safety_logs
    ADD CONSTRAINT safety_logs_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id);


--
-- Name: safety_reports safety_reports_generated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.safety_reports
    ADD CONSTRAINT safety_reports_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES public.users(id);


--
-- Name: safety_violations safety_violations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.safety_violations
    ADD CONSTRAINT safety_violations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: subscription_events subscription_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.subscription_events
    ADD CONSTRAINT subscription_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: usage_tracking usage_tracking_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.usage_tracking
    ADD CONSTRAINT usage_tracking_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_preferences user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_subscriptions user_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cinematch_user
--

ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO cinematch_user;


--
-- PostgreSQL database dump complete
--

