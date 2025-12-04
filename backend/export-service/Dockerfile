FROM python:3.11-slim

WORKDIR /app

COPY backend/export-service/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy shared modules
COPY backend/shared /app/shared
# Copy service code
COPY backend/export-service /app/export-service

ENV PYTHONPATH=/app

CMD ["uvicorn", "export-service.main:app", "--host", "0.0.0.0", "--port", "8080"]
