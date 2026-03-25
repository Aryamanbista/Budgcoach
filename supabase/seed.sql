-- =============================================================================
-- seed.sql — Dummy data for local development & testing
-- =============================================================================

-- Seed a test user (password handled by Supabase Auth; this row is for the
-- public.users profile table)
INSERT INTO public.users (id, email, name, financial_score)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'demo@budgcoach.app', 'Demo User', 72.50)
ON CONFLICT (id) DO NOTHING;

-- Seed accounts
INSERT INTO public.accounts (id, user_id, wallet_name, balance)
VALUES
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'eSewa',  12500.00),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Khalti',  3800.00),
    ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'NMB Bank', 45000.00)
ON CONFLICT (id) DO NOTHING;

-- Seed transactions
INSERT INTO public.transactions (user_id, account_id, raw_text, clean_text, amount, type, category_id, date)
SELECT
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'FT-001-ESEWA-MOMO',
    'Momo payment via eSewa',
    350.00,
    'debit',
    c.id,
    '2024-03-01'
FROM public.categories c WHERE c.name = 'Food & Dining'
ON CONFLICT DO NOTHING;

INSERT INTO public.transactions (user_id, account_id, raw_text, clean_text, amount, type, category_id, date)
SELECT
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    'FT-002-KHALTI-PATHAO',
    'Pathao ride via Khalti',
    180.00,
    'debit',
    c.id,
    '2024-03-02'
FROM public.categories c WHERE c.name = 'Transport'
ON CONFLICT DO NOTHING;

-- Seed budgets
INSERT INTO public.budgets (user_id, category_id, limit_amount, spent_amount, month_year)
SELECT
    '00000000-0000-0000-0000-000000000001',
    c.id,
    5000.00,
    2350.00,
    '2024-03'
FROM public.categories c WHERE c.name = 'Food & Dining'
ON CONFLICT DO NOTHING;
