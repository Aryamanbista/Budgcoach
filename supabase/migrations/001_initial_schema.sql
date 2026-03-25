-- =============================================================================
-- Migration: 001_initial_schema.sql
-- Description: Initial schema for Budgcoach — users, accounts, transactions,
--              budgets tables plus Row Level Security (RLS) policies.
-- =============================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT NOT NULL UNIQUE,
    name            TEXT NOT NULL,
    financial_score NUMERIC(5, 2) DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.accounts (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    wallet_name TEXT NOT NULL,
    balance     NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.categories (
    id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE
);

INSERT INTO public.categories (name) VALUES
    ('Food & Dining'),
    ('Transport'),
    ('Shopping'),
    ('Entertainment'),
    ('Health'),
    ('Utilities'),
    ('Education'),
    ('Savings'),
    ('Other')
ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.transactions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    account_id  UUID NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
    raw_text    TEXT,
    clean_text  TEXT,
    amount      NUMERIC(12, 2) NOT NULL,
    type        TEXT NOT NULL CHECK (type IN ('debit', 'credit')),
    category_id UUID REFERENCES public.categories(id),
    date        DATE NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.budgets (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    category_id   UUID NOT NULL REFERENCES public.categories(id),
    limit_amount  NUMERIC(12, 2) NOT NULL,
    spent_amount  NUMERIC(12, 2) NOT NULL DEFAULT 0,
    month_year    TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, category_id, month_year)
);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

-- accounts
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY accounts_select ON public.accounts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY accounts_insert ON public.accounts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY accounts_update ON public.accounts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY accounts_delete ON public.accounts
    FOR DELETE USING (auth.uid() = user_id);

-- transactions
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY transactions_select ON public.transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY transactions_insert ON public.transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY transactions_update ON public.transactions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY transactions_delete ON public.transactions
    FOR DELETE USING (auth.uid() = user_id);

-- budgets
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY budgets_select ON public.budgets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY budgets_insert ON public.budgets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY budgets_update ON public.budgets
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY budgets_delete ON public.budgets
    FOR DELETE USING (auth.uid() = user_id);
