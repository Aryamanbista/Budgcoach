from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.auth import router as auth_router
from app.api.transactions import router as transactions_router
from app.api.budgets import router as budgets_router
from app.api.goals import router as goals_router
from app.api.upload import router as upload_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# CORS middleware configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth_router, prefix=settings.API_V1_STR, tags=["Authentication"])
app.include_router(transactions_router, prefix=f"{settings.API_V1_STR}/transactions", tags=["Transactions"])
app.include_router(budgets_router, prefix=f"{settings.API_V1_STR}/budgets", tags=["Budgets"])
app.include_router(goals_router, prefix=f"{settings.API_V1_STR}/goals", tags=["Savings Goals"])
app.include_router(upload_router, prefix=f"{settings.API_V1_STR}", tags=["Uploads"])

# Health check route
@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "healthy", "project": settings.PROJECT_NAME}
