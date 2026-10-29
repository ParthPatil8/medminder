import os


def _db_url() -> str:
    url = os.environ.get("DATABASE_URL", "sqlite:///medminder.db")
    # Hosts often give "postgres://..."; SQLAlchemy needs a driver name.
    if url.startswith("postgres://"):
        url = "postgresql+psycopg://" + url[len("postgres://"):]
    elif url.startswith("postgresql://"):
        url = "postgresql+psycopg://" + url[len("postgresql://"):]
    return url


class Config:
    SQLALCHEMY_DATABASE_URI = _db_url()
    TIMEZONE = os.environ.get("APP_TIMEZONE", "Asia/Kolkata")
    # "*" is convenient for local demos. For deployment set an explicit,
    # comma-separated list, e.g. https://your-web-app.example.com
    CORS_ORIGINS = os.environ.get("CORS_ORIGINS", "*")
