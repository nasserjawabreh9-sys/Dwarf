# --- Backend only (FastAPI) ---
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=10000

WORKDIR /app

# System deps (kept minimal)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
  && rm -rf /var/lib/apt/lists/*

# Copy backend requirements first for caching (if exists)
# If you have requirements in backend/requirements.txt this will work.
COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy the whole repo
COPY . /app

# Start FastAPI (adjust module path if your app is elsewhere)
# Common options: backend.main:app or app.main:app
CMD ["bash","-lc","python -m uvicorn backend.main:app --host 0.0.0.0 --port ${PORT}"]
