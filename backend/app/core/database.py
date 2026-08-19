from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.core.config import settings

# Create async engine (use asyncpg dialect for async PostgreSQL support)
db_url = settings.DATABASE_URL
if db_url.startswith("postgresql://"):
    db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
elif db_url.startswith("postgresql+pg8000://"):
    db_url = db_url.replace("postgresql+pg8000://", "postgresql+asyncpg://", 1)

engine = create_async_engine(db_url, echo=False)

# Create async sessionmaker
AsyncSessionLocal = async_sessionmaker(autocommit=False, autoflush=False, bind=engine, class_=AsyncSession)

# Base declarative class
Base = declarative_base()

# DB dependency generator (async)
async def get_db():
    async with AsyncSessionLocal() as db:
        try:
            yield db
        finally:
            await db.close()
