# Budgcoach testing strategy

The repository contains tests at the layers that currently have executable
behavior.

| Layer | Location | What it proves |
|---|---|---|
| Flutter unit | `apps/mobile-app/test/unit/` | NPR/date formatting, domain models, state notifiers, category mapping |
| Flutter widget | `apps/mobile-app/test/widget_test.dart` | App launch, splash-to-dashboard transition, statement selection behavior |
| Flutter integration/E2E | `apps/mobile-app/integration_test/app_flow_test.dart` | Native macOS app launch and navigation through dashboard, transactions, upload, budget, and profile |
| Backend unit | `backend/tests/test_security_and_schemas.py` | Password/JWT security and Pydantic validation rules |
| Backend API integration | `backend/tests/test_api_integration.py` | Auth, protected routes, transactions, balances, budgets, and savings goals using an isolated SQLite database |
| Supabase security | `backend/tests/test_supabase_rls.py` | RLS enablement and user-scoped CRUD policies in the migration |
| ML contract | `services/ml-engine/tests/test_api.py` | Health, category, forecast, and invalid-input API contracts |
| Static/build checks | `flutter analyze`, `npm run build` | Compile-time and framework-level regressions |

Run the available layers together from the repository root:

```bash
bash ./scripts/run_test_suite.sh
```

The ML endpoints are currently mock contracts, so these tests verify their API
shape and validation behavior; they do not claim trained-model accuracy. A live
Supabase/PostgreSQL test environment is required for runtime RLS enforcement
tests, while the current suite verifies the committed policy definitions.

The Flutter widget and E2E tests disable Google Fonts runtime downloads so
execution is deterministic and does not depend on internet access. Poppins is
bundled in the app assets, and the E2E suite exercises the same screens and
navigation using the native macOS runner.

The combined runner keeps analyzer warnings visible but only fails on analyzer
errors. At the time this suite was added, Flutter reported 76 non-fatal migration
and style findings, mostly deprecations introduced by newer Flutter releases;
these are recorded as a cleanup backlog rather than hidden.
