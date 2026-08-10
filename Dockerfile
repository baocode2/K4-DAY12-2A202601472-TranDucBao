FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim AS runtime
COPY --from=builder /install /usr/local

RUN useradd --create-home appuser
WORKDIR /app
COPY --chown=appuser:appuser . .
USER appuser

ENV PORT=8000
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD python -c "import urllib.request,os; urllib.request.urlopen(f'http://localhost:{os.environ.get(\"PORT\",8000)}/healthz')" || exit 1

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port $PORT"]
