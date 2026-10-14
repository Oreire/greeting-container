## Baseline Dockerfile Provided

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


# The following is the Improved Dockerfile with multi-stage builds and caching for dependencies.



# Stage 1 — Build environment


FROM python:3.12-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install build dependencies only for building wheels

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip to minimise potential issues with dependency resolution and wheel building

RUN python -m pip install --upgrade pip

# Copy only requirements first for caching
COPY app/requirements.txt ./requirements.txt

# Build wheels for dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --wheel-dir /wheels -r requirements.txt

# Copy application source code
COPY app/ ./app/


# Stage 2 — Runtime environment


FROM python:3.12-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app

# Installations of only runtime dependencies

RUN python -m pip install --no-cache-dir --upgrade "pip==26.2.1"

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* \
    && pip check

# Creates a non-root user

RUN groupadd --system app \
    && useradd --system --gid app --no-create-home app

# Copy application code from builder stage

COPY --from=builder --chown=app:app /app/app ./app

USER app

EXPOSE 8080

# Healthcheck for orchestration systems

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz')"

# Start Gunicorn

CMD ["sh", "-c", "exec gunicorn --chdir app --bind 0.0.0.0:${PORT:-8080} --workers 2 app:app"]

