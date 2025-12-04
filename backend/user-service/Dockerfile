FROM python:3.11-slim

WORKDIR /app

COPY backend/user-service/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy shared modules
COPY backend/shared /app/shared
# Copy service code
COPY backend/user-service /app/user-service

ENV PYTHONPATH=/app

CMD ["uvicorn", "user-service.main:app", "--host", "0.0.0.0", "--port", "8080"]
