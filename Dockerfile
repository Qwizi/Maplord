FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY . .

RUN SECRET_KEY=build-placeholder uv run python manage.py collectstatic --noinput

RUN addgroup --system --gid 1001 django && \
    adduser --system --uid 1001 --ingroup django django
USER django

EXPOSE 8000

CMD ["uv", "run", "gunicorn", "config.wsgi:application", "-b", "0.0.0.0:8000"]
