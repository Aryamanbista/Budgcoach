# Budgcoach

Budgcoach is a Flutter budgeting and savings app for Nepal. It imports financial
statements, detects duplicates, builds an individual spending baseline, forecasts
the rest of the month, and delivers personalized budget, savings, weekly-spend,
history-readiness, and festival-planning nudges.

## Stack

- Flutter mobile app for Android and iOS
- FastAPI application API
- PostgreSQL with SQLAlchemy and Alembic migrations
- Separate FastAPI ML service using a personal baseline, ARIMA, and gated LSTM
- Tesseract, OpenCV, PyMuPDF, pdfplumber, pandas, and openpyxl for OCR/import
- Docker Compose for the production service topology

## Implemented product flows

- Authenticated accounts, transactions, category budgets, savings goals, health
  score, forecasts, and persistent dismissible nudges
- PDF, XLSX, XLS, CSV, JPG, JPEG, and PNG statement import without selecting a
  provider or statement type
- Content-signature and size validation, multi-layout parsing, review/edit before
  commit, balance reconciliation, exact duplicate blocking, and possible-duplicate
  warnings across overlapping date ranges
- Android and iOS system share-sheet ingestion into the same statement-review flow
- Optional Android financial-SMS ingestion with native sender/content filtering and
  at-least-once delivery until authenticated synchronization succeeds
- A recommended 30-day history baseline and a visible 180-day personal-LSTM
  learning/validation state
- Live Nepal holiday calendar input for festival-aware forecasts and nudges
- Authenticated CSV export with spreadsheet-formula injection protection

## Forecast selection

Forecasts never activate the LSTM merely because enough rows exist. Budgcoach first
backtests a weighted personal baseline and ARIMA on a chronological holdout. At 180
daily observations it fine-tunes an LSTM copy on that user's own history, evaluates
it on a later validation window, and activates it only when its MAE is no worse than
the strongest statistical alternative. Until then, the lower-error baseline remains
active. This makes cold-start behavior honest and prevents a generic model from
overriding a better individual forecast.

Model quality still depends on each user's history and on representative validation
data. The included tests verify selection and data-isolation behavior; production
teams should maintain a consented, de-identified holdout corpus by institution and
statement format before publishing accuracy claims.

## Local services

Requirements: Docker with Compose, or Python 3.11, PostgreSQL 16, Flutter, Android
JDK 17, Xcode/CocoaPods for iOS, and Tesseract when running OCR outside Docker.

```bash
cp .env.example .env
# Replace every placeholder secret in .env.
docker compose up --build
```

The API is available at `http://localhost:8000`; its health endpoint is `/health`.
The database is not published to the host by default. The backend applies Alembic
migrations before starting.

The Compose stack contains three private services and one public entry point:

| Service | Purpose | Default address |
| --- | --- | --- |
| `backend` | Authentication, budgets, imports, nudges and forecasts | `http://localhost:8000` |
| `ml-engine` | Category inference and validated personal forecasting | internal port `8000` |
| `postgres` | Persistent application data | internal port `5432` |

Confirm that the stack is healthy before connecting the app:

```bash
curl http://localhost:8000/health
docker compose ps
```

For backend development:

```bash
cd backend
python3.11 -m venv venv
venv/bin/pip install -r requirements.txt pytest==8.3.5
DATABASE_URL=postgresql://budgcoach:password@localhost:5432/budgcoach \
  venv/bin/alembic upgrade head
venv/bin/uvicorn app.main:app --reload
```

Run the ML service independently when developing forecasting code:

```bash
cd services/ml-engine
python3.10 -m venv .venv
.venv/bin/pip install -r requirements.txt -r requirements-dev.txt
.venv/bin/uvicorn main:app --reload --port 8001
```

For Flutter development and release configuration, see
[`apps/mobile-app/README.md`](apps/mobile-app/README.md). Production mobile builds
must supply an HTTPS API endpoint:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

For a local Android emulator, use the host loopback alias:

```bash
cd apps/mobile-app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For an iOS simulator, use `http://127.0.0.1:8000/api/v1`. Physical devices must
use an address reachable from the device. Release builds reject non-HTTPS API URLs.

## Using the app

1. Register, complete the financial profile, and add or select an account.
2. Import at least the most recent 30 consecutive days from **Upload statement**.
   Budgcoach detects PDF, spreadsheet, CSV, or image structure automatically.
3. Review parsed dates, descriptions, amounts, transaction direction, balance, and
   AI category suggestions. Exact and likely duplicates are excluded by default.
4. Commit the verified rows. The dashboard, history coverage, forecast and nudges
   update from the stored transactions.
5. Continue with manual entries, daily statement imports, the Android financial-SMS
   opt-in, or **Share → Budgcoach** from a wallet/file application.
6. Enable personalized notifications from Profile if desired. Notification taps
   open the authenticated nudge feed.

Thirty days establishes a useful personal baseline; it does not train the LSTM.
The learning card reports progress toward the 180-observation validation threshold.

## Native platform setup

Android release signing reads `apps/mobile-app/android/key.properties`; start from
`key.properties.example` and never commit a keystore or its passwords. Use JDK 17.
The SMS feature is opt-in and only forwards messages that pass the on-device
financial sender, transaction-verb, and amount filters.

For iOS, open `apps/mobile-app/ios/Runner.xcworkspace`, choose the same Apple team
for `Runner` and `ShareExtension`, and enable the existing
`group.com.budgcoach.budgcoach` App Group for both targets. The extension accepts
supported statement files and hands them to the review workflow.

## Production deployment

1. Copy `.env.example` to a secret-managed production environment.
2. Set a strong `SECRET_KEY`, production PostgreSQL credentials, the public CORS
   origins, and the internal ML service URL.
3. Terminate TLS at a load balancer or reverse proxy and expose only the backend.
4. Run `docker compose up -d --build`; migrations execute before the API starts.
5. Add database backups, centralized logs, uptime/error monitoring, resource limits,
   and an incident-recovery procedure.
6. Build mobile binaries with the final HTTPS `API_BASE_URL`, signing identities,
   version numbers, privacy URLs, and store metadata.

The backend deliberately refuses production startup with a weak secret, development
database credentials, or wildcard CORS. Raw uploaded documents are processed
temporarily; parsed and user-approved financial records are stored in PostgreSQL.

## Verification

```bash
backend/venv/bin/pytest -q backend/tests

cd services/ml-engine
../../backend/venv/bin/pytest -q tests

cd ../../apps/mobile-app
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test
```

CI also builds both Docker images. Production configuration fails fast for weak
secrets, development database credentials, or wildcard CORS.

## Release obligations

Code alone cannot complete store publication or infrastructure provisioning. Before
release, configure the Android keystore, Apple signing/team and App Group, production
DNS/TLS and secrets, backups/monitoring, public Privacy Policy and Terms URLs, and
store listing assets. Android distribution with `RECEIVE_SMS` also requires the
Google Play permissions declaration and approval for the SMS-based money-management
use case. Users can leave SMS import disabled and use statements/share-sheet import.

Financial projections are budgeting estimates, not professional financial advice.
