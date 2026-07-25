FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONPATH=/app/src

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml README.md ./
COPY src ./src
COPY config ./config
COPY docker/entrypoint.sh /entrypoint.sh

RUN pip install --upgrade pip && pip install -e . && chmod +x /entrypoint.sh

RUN mkdir -p /app/data

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
