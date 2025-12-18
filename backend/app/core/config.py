import os

APP_NAME = os.getenv("APP_NAME", "Dwarf API")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
ENV = os.getenv("ENV", "prod")  # dev|stage|prod

# Comma-separated allow origins. Example:
# ALLOW_ORIGINS="https://your-frontend.onrender.com,https://yourdomain.com"
ALLOW_ORIGINS = [o.strip() for o in os.getenv("ALLOW_ORIGINS", "*").split(",") if o.strip()]

# Rate limit (basic, in-memory)
RATE_LIMIT_RPM = int(os.getenv("RATE_LIMIT_RPM", "180"))  # requests per minute per IP
