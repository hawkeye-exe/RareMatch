# RareMatch

RareMatch is a mobile healthcare app for rare disease diagnosis using symptom timeline matching.

## Project Structure

- **backend/**: Python FastAPI microservices.
  - `user-service`: Profile & Auth.
  - `timeline-service`: Symptom Timeline CRUD.
  - `matching-service`: Vector search engine.
  - `ai-service`: Gemini Pro integration.
  - `export-service`: PDF report generation.
  - `notification-service`: Push notifications.
- **infrastructure/**: Docker Compose and Supabase SQL.
- **lib/**: Flutter mobile application.

## Setup Instructions

### 1. Prerequisites
- Docker & Docker Compose
- Flutter SDK (3.13+)
- Python 3.11+
- Supabase Account

### 2. Environment Setup (.env)
Create a `.env` file in the root directory. You can copy `.env.example` if it exists, or create one with the following keys:

```env
# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Google Gemini API
GEMINI_API_KEY=your_gemini_api_key

# Backend Service URLs (Default Ports)
USER_SERVICE_URL=http://localhost:8001
TIMELINE_SERVICE_URL=http://localhost:8002
MATCHING_SERVICE_URL=http://localhost:8003
AI_SERVICE_URL=http://localhost:8004
EXPORT_SERVICE_URL=http://localhost:8005
```

### 3. Running the Backend
You can use the provided PowerShell script to start all services (Windows):
```powershell
./start_services.ps1
```
*Note: Ensure you have your python virtual environment set up and paths configured in the script if necessary.*

Alternatively, run with Docker Compose:
```bash
docker-compose up --build
```

### 4. Data Seeding (Optional)
To populate the database with training data for the matching engine:

1.  Ensure your `.env` has `SUPABASE_SERVICE_ROLE_KEY`.
2.  Run the upload script:
    ```bash
    python infrastructure/scripts/upload_ml_data.py
    ```

### 5. Running the Frontend
1.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
2.  **Run App**:
    ```bash
    flutter run
    ```

## Features
- **Timeline Builder**: Create detailed symptom timelines.
- **AI Matching**: Find similar cases using vector search.
- **Visualization**: View match confidence scores.
- **Export**: Generate PDF reports for doctors.

## Testing & Verification
We have moved verification scripts to the `test/` folder.

- **Frontend Tests**: `flutter test`
- **Backend/Integration Scripts** (in `test/`):
    - `verify_features.py`: Checks core feature availability.
    - `verify_frontend_build.py`: Verifies frontend build integrity.
    - `test_similarity.py`: Tests the vector matching logic.
