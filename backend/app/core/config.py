from pydantic_settings import BaseSettings
from pydantic import ConfigDict, model_validator

class Settings(BaseSettings):
    PROJECT_NAME: str = "Budgcoach Backend"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    
    # Security Settings
    SECRET_KEY: str = "development-only-secret-change-me"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days (in minutes)
    
    # Database Connection
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/postgres"
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @model_validator(mode="after")
    def validate_production_secrets(self):
        if self.ENVIRONMENT.lower() == "production":
            if self.SECRET_KEY == "development-only-secret-change-me" or len(self.SECRET_KEY) < 32:
                raise ValueError("Production SECRET_KEY must be set to at least 32 characters.")
            if "postgres:postgres@" in self.DATABASE_URL:
                raise ValueError("Production DATABASE_URL must not use the development credentials.")
            if "*" in self.cors_origins:
                raise ValueError("Wildcard CORS origins are not allowed in production.")
        return self

    model_config = ConfigDict(case_sensitive=True)

settings = Settings()
