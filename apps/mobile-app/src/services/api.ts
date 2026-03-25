// ML Engine API base URL — override via environment variable in .env
const ML_API_URL = process.env.EXPO_PUBLIC_ML_API_URL ?? "http://localhost:8000";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface PredictCategoryRequest {
  raw_text: string;
}

export interface PredictCategoryResponse {
  category: string;
  confidence: number;
  is_mock: boolean;
}

export interface DailySpend {
  date: string;
  amount: number;
}

export interface ForecastRequest {
  history: DailySpend[];
}

export interface ForecastResponse {
  predicted_spend: number;
  budget_breach_warning: boolean;
  days_until_breach: number;
  is_mock: boolean;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function post<TRequest, TResponse>(
  endpoint: string,
  body: TRequest,
): Promise<TResponse> {
  const response = await fetch(`${ML_API_URL}${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`ML API error (${response.status}): ${text}`);
  }

  return response.json() as Promise<TResponse>;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Classifies a raw transaction string into a spending category.
 * POST /api/v1/predict-category
 */
export async function predictCategory(
  raw_text: string,
): Promise<PredictCategoryResponse> {
  return post<PredictCategoryRequest, PredictCategoryResponse>(
    "/api/v1/predict-category",
    { raw_text },
  );
}

/**
 * Forecasts future spending and detects budget breach risk.
 * POST /api/v1/forecast
 */
export async function forecastBudget(
  history: DailySpend[],
): Promise<ForecastResponse> {
  return post<ForecastRequest, ForecastResponse>("/api/v1/forecast", {
    history,
  });
}
