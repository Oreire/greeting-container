# FROM python:3.12@sha256:63828510c8b5ccce3bf0d6fabd6f3d17d4effa1ffe690f80a67c8e2d394e03ee

# RUN apt-get update && apt-get install -y \
#     build-essential \
#     gcc \
#     curl \
#     vim

# WORKDIR /app

# COPY . .

# RUN pip install -r app/requirements.txt

# EXPOSE 8080

# # The whole context was copied to /app, so the app package lives in /app/app.
# CMD ["gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
##############################
# Stage 1 — Build environment
##############################
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install build dependencies only for building wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip to remove known vulnerabilities
RUN python -m pip install --upgrade pip

# Copy only requirements first for caching
COPY app/requirements.txt ./requirements.txt

# Build wheels for dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --wheel-dir /wheels -r requirements.txt

# Copy application source code
COPY app/ ./app/


################################
# Stage 2 — Runtime environment
################################
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

# Install only runtime dependencies
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* \
    && pip check

# Copy application code from builder stage
COPY --from=builder --chown=app:app /app/app ./app

# Create non-root user
RUN groupadd --system app \
    && useradd --system --gid app --no-create-home app

USER app

EXPOSE 8080

# Healthcheck for orchestration systems
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz')"

# Start Gunicorn
CMD ["sh", "-c", "exec gunicorn --chdir app --bind 0.0.0.0:${PORT:-8080} --workers 2 app:app"]


# FROM python:3.12-slim AS builder
# RUN apt-get update && apt-get install -y build-essential gcc
# WORKDIR /app
# COPY app/requirements.txt .
# RUN pip wheel --no-cache-dir -r requirements.txt -w /wheels

# FROM python:3.12-slim
# RUN useradd -m appuser
# USER appuser
# WORKDIR /app
# COPY --from=builder /wheels /wheels
# RUN pip install --no-cache-dir /wheels/*
# COPY . .
# EXPOSE 8080
# HEALTHCHECK CMD curl -f http://localhost:8080/ || exit 1
# CMD ["gunicorn", "--chdir", "app", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]

###############################
# Stage 1 — Build environment #
###############################
# FROM python:3.12-slim AS builder

# # Python runtime and pip settings
# ENV PYTHONDONTWRITEBYTECODE=1 \
#     PYTHONUNBUFFERED=1 \
#     PIP_DISABLE_PIP_VERSION_CHECK=1 \
#     PORT=8080

# WORKDIR /app

# # Install build dependencies required for compiling wheels
# RUN apt-get update && apt-get install -y --no-install-recommends \
#         build-essential \
#         gcc \
#         curl \
#     && rm -rf /var/lib/apt/lists/*

# # 🔥 Upgrade pip (fixes all pip CVEs, does NOT affect final image size)
# RUN python -m pip install --upgrade pip

# # Copy only requirements first for layer caching
# COPY app/requirements.txt ./requirements.txt

# # Build wheels using pip cache mount
# RUN --mount=type=cache,target=/root/.cache/pip \
#     python -m pip wheel --wheel-dir /wheels -r requirements.txt

# # Copy application source code
# COPY app/ ./app/


# ################################
# # Stage 2 — Runtime environment #
# ################################
# FROM python:3.12-slim

# # Python runtime settings
# ENV PYTHONDONTWRITEBYTECODE=1 \
#     PYTHONUNBUFFERED=1 \
#     PIP_DISABLE_PIP_VERSION_CHECK=1 \
#     PORT=8080

# WORKDIR /app

# # Install curl for healthcheck
# RUN apt-get update && apt-get install -y --no-install-recommends curl \
#     && rm -rf /var/lib/apt/lists/*

# # Create unprivileged user
# RUN groupadd --system app \
#     && useradd --system --gid app --no-create-home app

# # Install only runtime dependencies from wheels
# COPY --from=builder /wheels /wheels
# RUN python -m pip install --no-cache-dir /wheels/* \
#     && python -m pip check

# # Copy application code from builder stage
# COPY --from=builder --chown=app:app /app/app ./app

# USER app

# EXPOSE 8080

# # Healthcheck using Flask health endpoint
# HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
#   CMD curl -f http://127.0.0.1:${PORT}/healthz || exit 1

# # Start Gunicorn
# CMD ["sh", "-c", "exec gunicorn --chdir app --bind 0.0.0.0:${PORT:-8080} --workers 2 app:app"]
