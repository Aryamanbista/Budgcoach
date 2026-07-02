from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import settings

# Create engine (auto-use pg8000 dialect for PostgreSQL support on Python 3.14)
db_url = settings.DATABASE_URL
if db_url.startswith("postgresql://"):
    db_url = db_url.replace("postgresql://", "postgresql+pg8000://", 1)

engine = create_engine(db_url)

# Create sessionmaker
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base declarative class
Base = declarative_base()

# DB dependency generator
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
