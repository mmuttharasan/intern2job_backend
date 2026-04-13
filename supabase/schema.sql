--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: application_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.application_status AS ENUM (
    'pending',
    'shortlisted',
    'rejected',
    'offered',
    'accepted',
    'withdrawn'
);


--
-- Name: internship_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.internship_status AS ENUM (
    'pre_boarding',
    'in_progress',
    'completed',
    'terminated'
);


--
-- Name: job_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.job_status AS ENUM (
    'draft',
    'published',
    'closed',
    'archived'
);


--
-- Name: milestone_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.milestone_status AS ENUM (
    'pending',
    'in_progress',
    'completed'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'student',
    'recruiter',
    'university_admin',
    'super_admin',
    'company_admin',
    'university'
);


--
-- Name: verification_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.verification_status AS ENUM (
    'unverified',
    'pending',
    'verified',
    'rejected'
);


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_role      public.user_role;
  v_raw_role  text;
begin
  v_raw_role := new.raw_user_meta_data->>'role';

  begin
    if v_raw_role is not null and v_raw_role <> '' then
      v_role := v_raw_role::public.user_role;
    else
      v_role := 'student'::public.user_role;
    end if;
  exception when invalid_text_representation then
    v_role := 'student'::public.user_role;
  end;

  insert into public.profiles (id, full_name, avatar_url, role)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url',
    v_role
  );

  return new;
end;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_application_curation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_application_curation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    application_id uuid NOT NULL,
    curated_by uuid,
    curation_status text DEFAULT 'pending'::text NOT NULL,
    curation_note text,
    forwarded_at timestamp with time zone,
    curated_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT admin_application_curation_curation_status_check CHECK ((curation_status = ANY (ARRAY['pending'::text, 'included'::text, 'excluded'::text])))
);


--
-- Name: admin_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    target_id uuid,
    target_type text,
    metadata jsonb DEFAULT '{}'::jsonb,
    ip_address text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    skill_weight numeric(4,2) DEFAULT 0.40,
    research_weight numeric(4,2) DEFAULT 0.25,
    language_weight numeric(4,2) DEFAULT 0.20,
    trajectory_weight numeric(4,2) DEFAULT 0.15,
    min_score_threshold numeric(4,2) DEFAULT 0.60,
    max_results_per_run integer DEFAULT 50,
    model_version text DEFAULT 'v2.1'::text,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: ai_match_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_match_results (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    job_id uuid,
    student_id uuid,
    score numeric(5,2) NOT NULL,
    explanation jsonb,
    created_at timestamp with time zone DEFAULT now(),
    run_id uuid
);


--
-- Name: ai_matching_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_matching_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid,
    triggered_by uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    total_analyzed integer DEFAULT 0,
    top_score numeric(5,2),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    llm_provider text,
    llm_analyzed_count integer DEFAULT 0
);


--
-- Name: COLUMN ai_matching_runs.llm_provider; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ai_matching_runs.llm_provider IS 'LLM used for deep analysis: ''claude'' | ''gemini'' | NULL (rule-based only)';


--
-- Name: COLUMN ai_matching_runs.llm_analyzed_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ai_matching_runs.llm_analyzed_count IS 'Number of top candidates that received LLM analysis';


--
-- Name: applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applications (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    job_id uuid,
    student_id uuid,
    status public.application_status DEFAULT 'pending'::public.application_status,
    ai_score numeric(5,2),
    cover_letter text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    note text,
    shortlisted_at timestamp with time zone
);


--
-- Name: certificates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.certificates (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    internship_id uuid,
    student_id uuid,
    company_id uuid,
    verification_code text NOT NULL,
    student_name text NOT NULL,
    company_name text NOT NULL,
    job_title text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    skills_demonstrated text[],
    performance_summary text,
    mentor_name text,
    issued_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    evaluation_id uuid
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    logo_url text,
    website text,
    industry text,
    size text,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    name_jp text,
    tagline text,
    location text,
    founded_year integer,
    mission text,
    culture text,
    "values" text[],
    benefits text[],
    status text DEFAULT 'approved'::text NOT NULL,
    CONSTRAINT companies_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: company_landing_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_landing_pages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    headline text,
    subheadline text,
    hero_image_url text,
    sections jsonb DEFAULT '[]'::jsonb,
    cta_text text,
    published boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: content_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_flags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid,
    target_id uuid NOT NULL,
    target_type text NOT NULL,
    reason text NOT NULL,
    details text,
    status text DEFAULT 'open'::text NOT NULL,
    resolved_by uuid,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT content_flags_status_check CHECK ((status = ANY (ARRAY['open'::text, 'resolved'::text, 'dismissed'::text])))
);


--
-- Name: evaluation_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evaluation_questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid,
    question_text text NOT NULL,
    skill text,
    difficulty text DEFAULT 'medium'::text,
    time_estimate text,
    context text,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT evaluation_questions_difficulty_check CHECK ((difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text])))
);


--
-- Name: evaluation_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evaluation_scores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid,
    question_id uuid,
    score integer NOT NULL,
    max_score integer DEFAULT 5 NOT NULL,
    notes text,
    dimension text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: evaluation_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evaluation_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid,
    student_id uuid,
    recruiter_id uuid,
    interview_type text DEFAULT 'technical'::text NOT NULL,
    scheduled_at timestamp with time zone,
    status text DEFAULT 'scheduled'::text NOT NULL,
    overall_notes text,
    recommendation text,
    total_score numeric(5,2),
    max_score numeric(5,2),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT evaluation_sessions_recommendation_check CHECK ((recommendation = ANY (ARRAY['advance'::text, 'hold'::text, 'reject'::text, NULL::text]))),
    CONSTRAINT evaluation_sessions_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'in_progress'::text, 'completed'::text, 'cancelled'::text])))
);


--
-- Name: internship_evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.internship_evaluations (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    internship_id uuid,
    company_id uuid,
    evaluator_id uuid,
    tech_fit_score smallint,
    cultural_fit_score smallint,
    behavioral_fit_score smallint,
    comment text,
    status text DEFAULT 'requested'::text,
    requested_at timestamp with time zone DEFAULT now(),
    submitted_at timestamp with time zone,
    approved_at timestamp with time zone,
    approved_by uuid,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    internship_start_date date,
    internship_end_date date,
    hire_decision text,
    not_hire_reason text,
    CONSTRAINT internship_evaluations_behavioral_fit_score_check CHECK (((behavioral_fit_score >= 1) AND (behavioral_fit_score <= 10))),
    CONSTRAINT internship_evaluations_cultural_fit_score_check CHECK (((cultural_fit_score >= 1) AND (cultural_fit_score <= 10))),
    CONSTRAINT internship_evaluations_hire_decision_check CHECK ((hire_decision = ANY (ARRAY['hire'::text, 'not_hire'::text]))),
    CONSTRAINT internship_evaluations_status_check CHECK ((status = ANY (ARRAY['requested'::text, 'submitted'::text, 'approved'::text, 'rejected'::text]))),
    CONSTRAINT internship_evaluations_tech_fit_score_check CHECK (((tech_fit_score >= 1) AND (tech_fit_score <= 10)))
);


--
-- Name: internship_milestones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.internship_milestones (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    internship_id uuid,
    title text NOT NULL,
    status public.milestone_status DEFAULT 'pending'::public.milestone_status,
    due_date date,
    completed_at timestamp with time zone,
    student_actionable boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: internships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.internships (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    application_id uuid,
    student_id uuid,
    job_id uuid,
    company_id uuid,
    status public.internship_status DEFAULT 'pre_boarding'::public.internship_status,
    start_date date NOT NULL,
    end_date date NOT NULL,
    mentor_name text,
    team text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    conclusion_type text,
    conclusion_note text,
    concluded_at timestamp with time zone,
    concluded_by uuid,
    extension_end_date date,
    CONSTRAINT internships_conclusion_type_check CHECK ((conclusion_type = ANY (ARRAY['converted_to_employee'::text, 'extended'::text, 'completed_with_certificate'::text])))
);


--
-- Name: interview_rounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interview_rounds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    round_number integer DEFAULT 1 NOT NULL,
    company_slot_note text,
    proposed_slots jsonb DEFAULT '[]'::jsonb,
    scheduled_by uuid,
    results_requested_at timestamp with time zone,
    results_submitted_at timestamp with time zone,
    status text DEFAULT 'pending_slots'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT interview_rounds_status_check CHECK ((status = ANY (ARRAY['pending_slots'::text, 'slots_submitted'::text, 'slots_sent_to_students'::text, 'results_requested'::text, 'results_submitted'::text])))
);


--
-- Name: interview_schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interview_schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    round_id uuid NOT NULL,
    application_id uuid NOT NULL,
    student_id uuid NOT NULL,
    scheduled_slot jsonb,
    scheduled_by uuid,
    result text DEFAULT 'pending'::text,
    result_note text,
    offer_decision text,
    result_submitted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    student_selected_slot jsonb,
    slot_selected_at timestamp with time zone,
    CONSTRAINT interview_schedules_offer_decision_check CHECK ((offer_decision = ANY (ARRAY['offer'::text, 'no_offer'::text, 'waitlist'::text]))),
    CONSTRAINT interview_schedules_result_check CHECK ((result = ANY (ARRAY['pass'::text, 'fail'::text, 'no_show'::text, 'pending'::text])))
);


--
-- Name: job_university_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_university_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    university_id uuid NOT NULL,
    assigned_by uuid,
    assigned_at timestamp with time zone DEFAULT now(),
    notified_at timestamp with time zone,
    acknowledged_at timestamp with time zone,
    student_ids uuid[] DEFAULT '{}'::uuid[],
    department_ids uuid[] DEFAULT '{}'::uuid[],
    apply_on_behalf boolean DEFAULT false
);


--
-- Name: jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jobs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    company_id uuid,
    recruiter_id uuid,
    title text NOT NULL,
    description text,
    requirements text[],
    location text,
    is_remote boolean DEFAULT false,
    salary_min integer,
    salary_max integer,
    status public.job_status DEFAULT 'draft'::public.job_status,
    deadline date,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    department text,
    responsibilities text[],
    qualifications text[],
    skills text[],
    job_benefits text[],
    employment_type text,
    experience_level text,
    openings integer DEFAULT 1,
    required_language text,
    ai_matching_enabled boolean DEFAULT false,
    target_universities uuid[],
    priority text DEFAULT 'medium'::text,
    closed_at timestamp with time zone,
    lifecycle_stage text DEFAULT 'draft'::text NOT NULL,
    approval_status text DEFAULT 'not_submitted'::text,
    approval_note text,
    approved_by uuid,
    approved_at timestamp with time zone,
    submitted_for_approval_at timestamp with time zone,
    CONSTRAINT jobs_lifecycle_stage_check CHECK ((lifecycle_stage = ANY (ARRAY['draft'::text, 'pending_approval'::text, 'approved_assigning'::text, 'university_assigned'::text, 'collecting_applications'::text, 'forwarded_to_company'::text, 'interview_scheduling'::text, 'awaiting_slot_acceptance'::text, 'results_pending'::text, 'offer_stage'::text, 'completed'::text])))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    sender_id uuid,
    receiver_id uuid,
    body text NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    body text,
    entity_type text,
    entity_id uuid,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: offers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_id uuid NOT NULL,
    application_id uuid NOT NULL,
    student_id uuid NOT NULL,
    company_id uuid,
    issued_by uuid,
    offer_details jsonb DEFAULT '{}'::jsonb,
    status text DEFAULT 'pending'::text NOT NULL,
    sent_at timestamp with time zone,
    response_deadline date,
    responded_at timestamp with time zone,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT offers_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'accepted'::text, 'rejected'::text, 'expired'::text, 'withdrawn'::text])))
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    role public.user_role DEFAULT 'student'::public.user_role NOT NULL,
    full_name text,
    avatar_url text,
    university_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'active'::text NOT NULL,
    CONSTRAINT profiles_status_check CHECK ((status = ANY (ARRAY['active'::text, 'suspended'::text])))
);


--
-- Name: recruiters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recruiters (
    id uuid NOT NULL,
    company_id uuid,
    title text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    department text,
    phone text,
    notification_preferences jsonb DEFAULT '{"messages": true, "match_alerts": true, "platform_updates": false, "evaluation_reminders": true}'::jsonb,
    ai_matching_weights jsonb DEFAULT '{"growth": 15, "skills": 40, "language": 20, "research": 25}'::jsonb
);


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    id uuid NOT NULL,
    university_id uuid,
    department text,
    graduation_year integer,
    gpa numeric(3,2),
    resume_url text,
    skills text[],
    verification_status public.verification_status DEFAULT 'unverified'::public.verification_status,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    bio text,
    jp_level text,
    linkedin text,
    github text,
    portfolio text,
    phone text,
    location text,
    strengths text[] DEFAULT '{}'::text[],
    awards text[] DEFAULT '{}'::text[],
    profile_completeness numeric DEFAULT 0,
    research_title text,
    experiences jsonb DEFAULT '[]'::jsonb,
    badges text[],
    CONSTRAINT students_jp_level_check CHECK ((jp_level = ANY (ARRAY['N1'::text, 'N2'::text, 'N3'::text, 'N4'::text, 'N5'::text, 'None'::text])))
);


--
-- Name: universities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.universities (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    domain text,
    logo_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'approved'::text NOT NULL,
    contact_email text,
    country text,
    location text,
    CONSTRAINT universities_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: university_departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.university_departments (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    university_id uuid NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    head text,
    students_count integer DEFAULT 0 NOT NULL,
    placed_count integer DEFAULT 0 NOT NULL,
    faculty_count integer DEFAULT 0 NOT NULL,
    labs_count integer DEFAULT 0 NOT NULL,
    avg_package text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: verification_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.verification_requests (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    university_id uuid NOT NULL,
    student_id uuid,
    student_name text,
    roll_no text,
    department text,
    type text NOT NULL,
    urgency text DEFAULT 'Medium'::text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    submitted_date date DEFAULT CURRENT_DATE,
    documents jsonb DEFAULT '[]'::jsonb NOT NULL,
    review_note text,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: admin_application_curation admin_application_curation_job_id_application_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_application_curation
    ADD CONSTRAINT admin_application_curation_job_id_application_id_key UNIQUE (job_id, application_id);


--
-- Name: admin_application_curation admin_application_curation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_application_curation
    ADD CONSTRAINT admin_application_curation_pkey PRIMARY KEY (id);


--
-- Name: admin_audit_log admin_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_log
    ADD CONSTRAINT admin_audit_log_pkey PRIMARY KEY (id);


--
-- Name: ai_config ai_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_config
    ADD CONSTRAINT ai_config_pkey PRIMARY KEY (id);


--
-- Name: ai_match_results ai_match_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_match_results
    ADD CONSTRAINT ai_match_results_pkey PRIMARY KEY (id);


--
-- Name: ai_matching_runs ai_matching_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_matching_runs
    ADD CONSTRAINT ai_matching_runs_pkey PRIMARY KEY (id);


--
-- Name: applications applications_job_id_student_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_job_id_student_id_key UNIQUE (job_id, student_id);


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: certificates certificates_internship_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_internship_id_key UNIQUE (internship_id);


--
-- Name: certificates certificates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_pkey PRIMARY KEY (id);


--
-- Name: certificates certificates_verification_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_verification_code_key UNIQUE (verification_code);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_landing_pages company_landing_pages_company_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_landing_pages
    ADD CONSTRAINT company_landing_pages_company_id_key UNIQUE (company_id);


--
-- Name: company_landing_pages company_landing_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_landing_pages
    ADD CONSTRAINT company_landing_pages_pkey PRIMARY KEY (id);


--
-- Name: content_flags content_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_flags
    ADD CONSTRAINT content_flags_pkey PRIMARY KEY (id);


--
-- Name: evaluation_questions evaluation_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_questions
    ADD CONSTRAINT evaluation_questions_pkey PRIMARY KEY (id);


--
-- Name: evaluation_scores evaluation_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_scores
    ADD CONSTRAINT evaluation_scores_pkey PRIMARY KEY (id);


--
-- Name: evaluation_scores evaluation_scores_session_id_question_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_scores
    ADD CONSTRAINT evaluation_scores_session_id_question_id_key UNIQUE (session_id, question_id);


--
-- Name: evaluation_sessions evaluation_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_sessions
    ADD CONSTRAINT evaluation_sessions_pkey PRIMARY KEY (id);


--
-- Name: internship_evaluations internship_evaluations_internship_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internship_evaluations
    ADD CONSTRAINT internship_evaluations_internship_id_key UNIQUE (internship_id);


--
-- Name: internship_evaluations internship_evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internship_evaluations
    ADD CONSTRAINT internship_evaluations_pkey PRIMARY KEY (id);


--
-- Name: internship_milestones internship_milestones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internship_milestones
    ADD CONSTRAINT internship_milestones_pkey PRIMARY KEY (id);


--
-- Name: internships internships_application_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT internships_application_id_key UNIQUE (application_id);


--
-- Name: internships internships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT internships_pkey PRIMARY KEY (id);


--
-- Name: interview_rounds interview_rounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_rounds
    ADD CONSTRAINT interview_rounds_pkey PRIMARY KEY (id);


--
-- Name: interview_schedules interview_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_schedules
    ADD CONSTRAINT interview_schedules_pkey PRIMARY KEY (id);


--
-- Name: job_university_assignments job_university_assignments_job_id_university_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_university_assignments
    ADD CONSTRAINT job_university_assignments_job_id_university_id_key UNIQUE (job_id, university_id);


--
-- Name: job_university_assignments job_university_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_university_assignments
    ADD CONSTRAINT job_university_assignments_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: offers offers_application_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_application_id_key UNIQUE (application_id);


--
-- Name: offers offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: recruiters recruiters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recruiters
    ADD CONSTRAINT recruiters_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: universities universities_domain_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.universities
    ADD CONSTRAINT universities_domain_key UNIQUE (domain);


--
-- Name: universities universities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.universities
    ADD CONSTRAINT universities_pkey PRIMARY KEY (id);


--
-- Name: university_departments university_departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.university_departments
    ADD CONSTRAINT university_departments_pkey PRIMARY KEY (id);


--
-- Name: verification_requests verification_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_requests
    ADD CONSTRAINT verification_requests_pkey PRIMARY KEY (id);


--
-- Name: idx_admin_audit_log_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_audit_log_actor ON public.admin_audit_log USING btree (actor_id);


--
-- Name: idx_admin_audit_log_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_audit_log_created ON public.admin_audit_log USING btree (created_at DESC);


--
-- Name: idx_ai_match_results_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_match_results_run ON public.ai_match_results USING btree (run_id, score DESC);


--
-- Name: idx_ai_match_run_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_match_run_job ON public.ai_matching_runs USING btree (job_id);


--
-- Name: idx_applications_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_applications_job ON public.applications USING btree (job_id, status);


--
-- Name: idx_certificates_student; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_certificates_student ON public.certificates USING btree (student_id);


--
-- Name: idx_certificates_verification; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_certificates_verification ON public.certificates USING btree (verification_code);


--
-- Name: idx_companies_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_companies_status ON public.companies USING btree (status);


--
-- Name: idx_content_flags_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_content_flags_status ON public.content_flags USING btree (status);


--
-- Name: idx_content_flags_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_content_flags_target ON public.content_flags USING btree (target_id);


--
-- Name: idx_curation_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_curation_job ON public.admin_application_curation USING btree (job_id);


--
-- Name: idx_evaluations_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evaluations_company ON public.internship_evaluations USING btree (company_id);


--
-- Name: idx_evaluations_internship; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evaluations_internship ON public.internship_evaluations USING btree (internship_id);


--
-- Name: idx_evaluations_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evaluations_status ON public.internship_evaluations USING btree (status);


--
-- Name: idx_internships_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_internships_company ON public.internships USING btree (company_id);


--
-- Name: idx_internships_student; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_internships_student ON public.internships USING btree (student_id);


--
-- Name: idx_interview_rounds_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interview_rounds_job ON public.interview_rounds USING btree (job_id);


--
-- Name: idx_interview_schedules_round; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interview_schedules_round ON public.interview_schedules USING btree (round_id);


--
-- Name: idx_interview_schedules_student; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interview_schedules_student ON public.interview_schedules USING btree (student_id);


--
-- Name: idx_jobs_approval_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_approval_status ON public.jobs USING btree (approval_status);


--
-- Name: idx_jobs_company_deadline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_company_deadline ON public.jobs USING btree (company_id, deadline);


--
-- Name: idx_jobs_company_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_company_status ON public.jobs USING btree (company_id, status);


--
-- Name: idx_jobs_lifecycle_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jobs_lifecycle_stage ON public.jobs USING btree (lifecycle_stage);


--
-- Name: idx_jua_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jua_job ON public.job_university_assignments USING btree (job_id);


--
-- Name: idx_jua_university; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jua_university ON public.job_university_assignments USING btree (university_id);


--
-- Name: idx_milestones_internship; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_milestones_internship ON public.internship_milestones USING btree (internship_id);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id, created_at DESC);


--
-- Name: idx_notifications_user_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_unread ON public.notifications USING btree (user_id, created_at DESC) WHERE (read_at IS NULL);


--
-- Name: idx_offers_job; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offers_job ON public.offers USING btree (job_id);


--
-- Name: idx_offers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offers_status ON public.offers USING btree (status);


--
-- Name: idx_offers_student; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_offers_student ON public.offers USING btree (student_id);


--
-- Name: idx_profiles_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_profiles_status ON public.profiles USING btree (status);


--
-- Name: idx_students_grad_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_students_grad_year ON public.students USING btree (graduation_year);


--
-- Name: idx_students_jp_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_students_jp_level ON public.students USING btree (jp_level);


--
-- Name: idx_students_verification; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_students_verification ON public.students USING btree (verification_status);


--
-- Name: idx_university_departments_uni; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_university_departments_uni ON public.university_departments USING btree (university_id);


--
-- Name: idx_verification_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_verification_requests_status ON public.verification_requests USING btree (status);


--
-- Name: idx_verification_requests_uni; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_verification_requests_uni ON public.verification_requests USING btree (university_id);


--
-- Name: ai_config trg_ai_config_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ai_config_updated_at BEFORE UPDATE ON public.ai_config FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ai_matching_runs trg_ai_matching_runs_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ai_matching_runs_updated_at BEFORE UPDATE ON public.ai_matching_runs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: applications trg_applications_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_applications_updated_at BEFORE UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: companies trg_companies_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_companies_updated_at BEFORE UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: company_landing_pages trg_company_landing_pages_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_company_landing_pages_updated_at BEFORE UPDATE ON public.company_landing_pages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: content_flags trg_content_flags_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_content_flags_updated_at BEFORE UPDATE ON public.content_flags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: admin_application_curation trg_curation_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_curation_updated_at BEFORE UPDATE ON public.admin_application_curation FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: evaluation_sessions trg_eval_sessions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_eval_sessions_updated_at BEFORE UPDATE ON public.evaluation_sessions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: internships trg_internships_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_internships_updated_at BEFORE UPDATE ON public.internships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: interview_rounds trg_interview_rounds_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_interview_rounds_updated_at BEFORE UPDATE ON public.interview_rounds FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: interview_schedules trg_interview_schedules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_interview_schedules_updated_at BEFORE UPDATE ON public.interview_schedules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: jobs trg_jobs_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_jobs_updated_at BEFORE UPDATE ON public.jobs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offers trg_offers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_offers_updated_at BEFORE UPDATE ON public.offers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: profiles trg_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: recruiters trg_recruiters_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_recruiters_updated_at BEFORE UPDATE ON public.recruiters FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: students trg_students_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_students_updated_at BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: universities trg_universities_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_universities_updated_at BEFORE UPDATE ON public.universities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: university_departments trg_university_departments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_university_departments_updated_at BEFORE UPDATE ON public.university_departments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: verification_requests trg_verification_requests_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_verification_requests_updated_at BEFORE UPDATE ON public.verification_requests FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: admin_application_curation admin_application_curation_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_application_curation
    ADD CONSTRAINT admin_application_curation_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: admin_application_curation admin_application_curation_curated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_application_curation
    ADD CONSTRAINT admin_application_curation_curated_by_fkey FOREIGN KEY (curated_by) REFERENCES public.profiles(id);


--
-- Name: admin_application_curation admin_application_curation_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_application_curation
    ADD CONSTRAINT admin_application_curation_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: admin_audit_log admin_audit_log_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_log
    ADD CONSTRAINT admin_audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: ai_config ai_config_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_config
    ADD CONSTRAINT ai_config_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: ai_match_results ai_match_results_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_match_results
    ADD CONSTRAINT ai_match_results_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: ai_match_results ai_match_results_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_match_results
    ADD CONSTRAINT ai_match_results_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.ai_matching_runs(id) ON DELETE CASCADE;


--
-- Name: ai_match_results ai_match_results_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_match_results
    ADD CONSTRAINT ai_match_results_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: ai_matching_runs ai_matching_runs_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_matching_runs
    ADD CONSTRAINT ai_matching_runs_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: ai_matching_runs ai_matching_runs_triggered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_matching_runs
    ADD CONSTRAINT ai_matching_runs_triggered_by_fkey FOREIGN KEY (triggered_by) REFERENCES public.profiles(id);


--
-- Name: applications applications_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: applications applications_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: certificates certificates_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: certificates certificates_evaluation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_evaluation_id_fkey FOREIGN KEY (evaluation_id) REFERENCES public.internship_evaluations(id);


--
-- Name: certificates certificates_internship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_internship_id_fkey FOREIGN KEY (internship_id) REFERENCES public.internships(id) ON DELETE CASCADE;


--
-- Name: certificates certificates_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certificates
    ADD CONSTRAINT certificates_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: company_landing_pages company_landing_pages_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_landing_pages
    ADD CONSTRAINT company_landing_pages_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: content_flags content_flags_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_flags
    ADD CONSTRAINT content_flags_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: content_flags content_flags_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_flags
    ADD CONSTRAINT content_flags_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: evaluation_questions evaluation_questions_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_questions
    ADD CONSTRAINT evaluation_questions_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.evaluation_sessions(id) ON DELETE CASCADE;


--
-- Name: evaluation_scores evaluation_scores_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_scores
    ADD CONSTRAINT evaluation_scores_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.evaluation_questions(id) ON DELETE CASCADE;


--
-- Name: evaluation_scores evaluation_scores_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_scores
    ADD CONSTRAINT evaluation_scores_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.evaluation_sessions(id) ON DELETE CASCADE;


--
-- Name: evaluation_sessions evaluation_sessions_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_sessions
    ADD CONSTRAINT evaluation_sessions_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: evaluation_sessions evaluation_sessions_recruiter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_sessions
    ADD CONSTRAINT evaluation_sessions_recruiter_id_fkey FOREIGN KEY (recruiter_id) REFERENCES public.recruiters(id) ON DELETE SET NULL;


--
-- Name: evaluation_sessions evaluation_sessions_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evaluation_sessions
    ADD CONSTRAINT evaluation_sessions_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: internship_evaluations internship_evaluations_internship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internship_evaluations
    ADD CONSTRAINT internship_evaluations_internship_id_fkey FOREIGN KEY (internship_id) REFERENCES public.internships(id) ON DELETE CASCADE;


--
-- Name: internship_milestones internship_milestones_internship_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internship_milestones
    ADD CONSTRAINT internship_milestones_internship_id_fkey FOREIGN KEY (internship_id) REFERENCES public.internships(id) ON DELETE CASCADE;


--
-- Name: internships internships_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT internships_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: internships internships_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT internships_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: internships internships_concluded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT internships_concluded_by_fkey FOREIGN KEY (concluded_by) REFERENCES public.profiles(id);


--
-- Name: internships internships_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT internships_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- Name: internships internships_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.internships
    ADD CONSTRAINT internships_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: interview_rounds interview_rounds_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_rounds
    ADD CONSTRAINT interview_rounds_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: interview_rounds interview_rounds_scheduled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_rounds
    ADD CONSTRAINT interview_rounds_scheduled_by_fkey FOREIGN KEY (scheduled_by) REFERENCES public.profiles(id);


--
-- Name: interview_schedules interview_schedules_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_schedules
    ADD CONSTRAINT interview_schedules_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: interview_schedules interview_schedules_round_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_schedules
    ADD CONSTRAINT interview_schedules_round_id_fkey FOREIGN KEY (round_id) REFERENCES public.interview_rounds(id) ON DELETE CASCADE;


--
-- Name: interview_schedules interview_schedules_scheduled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_schedules
    ADD CONSTRAINT interview_schedules_scheduled_by_fkey FOREIGN KEY (scheduled_by) REFERENCES public.profiles(id);


--
-- Name: interview_schedules interview_schedules_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_schedules
    ADD CONSTRAINT interview_schedules_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: job_university_assignments job_university_assignments_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_university_assignments
    ADD CONSTRAINT job_university_assignments_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.profiles(id);


--
-- Name: job_university_assignments job_university_assignments_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_university_assignments
    ADD CONSTRAINT job_university_assignments_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: job_university_assignments job_university_assignments_university_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_university_assignments
    ADD CONSTRAINT job_university_assignments_university_id_fkey FOREIGN KEY (university_id) REFERENCES public.universities(id) ON DELETE CASCADE;


--
-- Name: jobs jobs_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.profiles(id);


--
-- Name: jobs jobs_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: jobs jobs_recruiter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_recruiter_id_fkey FOREIGN KEY (recruiter_id) REFERENCES public.recruiters(id);


--
-- Name: messages messages_receiver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.profiles(id);


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(id);


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: offers offers_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(id) ON DELETE CASCADE;


--
-- Name: offers offers_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: offers offers_issued_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_issued_by_fkey FOREIGN KEY (issued_by) REFERENCES public.profiles(id);


--
-- Name: offers offers_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- Name: offers offers_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_university_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_university_id_fkey FOREIGN KEY (university_id) REFERENCES public.universities(id);


--
-- Name: recruiters recruiters_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recruiters
    ADD CONSTRAINT recruiters_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);


--
-- Name: recruiters recruiters_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recruiters
    ADD CONSTRAINT recruiters_id_fkey FOREIGN KEY (id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: students students_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_id_fkey FOREIGN KEY (id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: students students_university_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_university_id_fkey FOREIGN KEY (university_id) REFERENCES public.universities(id);


--
-- Name: university_departments university_departments_university_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.university_departments
    ADD CONSTRAINT university_departments_university_id_fkey FOREIGN KEY (university_id) REFERENCES public.universities(id) ON DELETE CASCADE;


--
-- Name: verification_requests verification_requests_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_requests
    ADD CONSTRAINT verification_requests_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: verification_requests verification_requests_university_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.verification_requests
    ADD CONSTRAINT verification_requests_university_id_fkey FOREIGN KEY (university_id) REFERENCES public.universities(id) ON DELETE CASCADE;


--
-- Name: certificates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;

--
-- Name: internship_milestones; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.internship_milestones ENABLE ROW LEVEL SECURITY;

--
-- Name: internships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.internships ENABLE ROW LEVEL SECURITY;

--
-- Name: certificates public_certificate_verify; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_certificate_verify ON public.certificates FOR SELECT USING (true);


--
-- Name: internships recruiters_company_internships; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recruiters_company_internships ON public.internships USING ((company_id IN ( SELECT recruiters.company_id
   FROM public.recruiters
  WHERE (recruiters.id = auth.uid()))));


--
-- Name: certificates recruiters_issue_certificates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY recruiters_issue_certificates ON public.certificates FOR INSERT WITH CHECK ((company_id IN ( SELECT recruiters.company_id
   FROM public.recruiters
  WHERE (recruiters.id = auth.uid()))));


--
-- Name: interview_schedules student_select_slot; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY student_select_slot ON public.interview_schedules FOR UPDATE USING ((student_id IN ( SELECT s.id
   FROM (public.students s
     JOIN public.profiles p ON ((p.id = s.id)))
  WHERE (p.id = auth.uid())))) WITH CHECK ((student_id IN ( SELECT s.id
   FROM (public.students s
     JOIN public.profiles p ON ((p.id = s.id)))
  WHERE (p.id = auth.uid()))));


--
-- Name: certificates students_own_certificates; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_own_certificates ON public.certificates FOR SELECT USING ((student_id = auth.uid()));


--
-- Name: internships students_own_internships; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_own_internships ON public.internships FOR SELECT USING ((student_id = auth.uid()));


--
-- Name: internship_milestones students_own_milestones; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_own_milestones ON public.internship_milestones FOR SELECT USING ((internship_id IN ( SELECT internships.id
   FROM public.internships
  WHERE (internships.student_id = auth.uid()))));


--
-- Name: internship_milestones students_update_milestones; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_update_milestones ON public.internship_milestones FOR UPDATE USING (((student_actionable = true) AND (internship_id IN ( SELECT internships.id
   FROM public.internships
  WHERE (internships.student_id = auth.uid())))));


--
-- PostgreSQL database dump complete
--

\unrestrict nX5fMV3b413zf9m29RJ7wwGyEZEh2PtWQZygu9jkp7ZzknSuffKlyAktFnzIafr

