# 💰 Budgcoach

> **AI-driven personalized budget optimizer and financial advisor for Nepalese youth.**
> Combating *Spendception* (unconscious digital spending) — one transaction at a time.

---

## 🏗 Project Architecture

```
budgcoach-monorepo/
├── apps/
│   ├── web-admin/          # Next.js 14 — Web Dashboard / Admin
│   └── mobile-app/         # Expo / React Native — User-facing mobile app
├── services/
│   └── ml-engine/          # Python 3.10 + FastAPI — OCR & ML Models
├── supabase/
│   ├── migrations/         # SQL schema & RLS policies
│   └── seed.sql            # Dummy data for local development
├── .gitignore
├── README.md
└── package.json            # Yarn Workspaces root
```

### Key Technologies

| Layer | Technology |
|---|---|
| Mobile App | Expo (React Native) + TypeScript |
| Web Admin | Next.js 14 + TypeScript + Tailwind CSS |
| Backend / DB | Supabase (PostgreSQL + Row Level Security) |
| ML Engine | FastAPI + scikit-learn (Random Forest) + TensorFlow (LSTM) |
| OCR | Tesseract — parses eSewa, Khalti, and local bank PDF statements |

---

## 🚀 Getting Started

### Prerequisites

- Node.js ≥ 18
- Python ≥ 3.10
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- Yarn 1.x (`npm install -g yarn`)
- Expo CLI (`npm install -g expo-cli`)

---

### 1. Install JavaScript dependencies

```bash
# From the monorepo root
yarn install
```

---

### 2. Start the Next.js Web Admin

```bash
# Copy and fill in your environment variables
cp apps/web-admin/.env.local.example apps/web-admin/.env.local

# Start the dev server (http://localhost:3000)
cd apps/web-admin
npm run dev
```

---

### 3. Start the Expo Mobile App

```bash
cd apps/mobile-app

# Start Expo (choose iOS / Android / Web)
npx expo start
```

The mobile app reads `EXPO_PUBLIC_ML_API_URL` from a `.env` file in `apps/mobile-app/`.
Default is `http://localhost:8000`.

---

### 4. Start the FastAPI ML Engine

```bash
cd services/ml-engine

# Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start the server (http://localhost:8000)
uvicorn main:app --reload
```

Interactive API docs are available at `http://localhost:8000/docs`.

#### API Contract (Dummy Endpoints)

These endpoints return mock responses so the frontend team is never blocked:

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/v1/predict-category` | Classifies a raw transaction string |
| POST | `/api/v1/forecast` | Forecasts future spending & budget breach |

---

### 5. Apply Supabase Migrations (Local)

```bash
# Initialize Supabase locally (first time only)
supabase init
supabase start

# Apply the schema migration
supabase db push --local

# Or run the SQL file directly against your local Supabase instance
psql postgresql://postgres:postgres@localhost:54322/postgres \
  -f supabase/migrations/001_initial_schema.sql

# Load seed data
psql postgresql://postgres:postgres@localhost:54322/postgres \
  -f supabase/seed.sql
```

---

## 🔐 Security

- All user data is protected by **Supabase Row Level Security (RLS)**.
- Every table enforces `auth.uid() = user_id` for all CRUD operations.
- Secrets are **never** committed — use `.env.local` / `.env` files (excluded by `.gitignore`).

---

## 🧠 ML Pipeline (Coming Soon)

The ML Engine is scaffolded with dummy endpoints today. The production pipeline will include:

- `services/ml-engine/models/` — trained Random Forest (category) + LSTM (forecast) models
- `services/ml-engine/ocr_patterns/` — regex patterns for eSewa / Khalti / bank statement parsing
- `services/ml-engine/data_prep/` — ETL scripts for cleaning raw Nepali transaction text

---

## 📄 Licence

MIT © Budgcoach Contributors