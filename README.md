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
*Note: You may need to edit `start_services.ps1` to point `$VENV_PYTHON` to your local python executable.*

Alternatively, run with Docker Compose:
```bash
docker-compose up --build
```

## Data Pipeline & Seeding

To power the AI Matching Engine, you need to seed the database with reference cases.

### 1. Dataset Requirements
Prepare a CSV file (e.g., `dataset.csv`) with the following columns:
- `diagnosis`: The name of the disease.
- `symptoms`: A string or list of symptoms (e.g., "fever, rash, joint pain").
- `patient_id` (Optional): Unique identifier.

### 2. Upload Process
We provide a script to clean and upload this data to Supabase.

1.  **Configure**: Ensure your `.env` file has `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
2.  **Run Script**:
    ```bash
    # Usage: python infrastructure/scripts/upload_ml_data.py <path_to_csv>
    python infrastructure/scripts/upload_ml_data.py data/dataset.csv
    ```
    *The script will automatically generate embeddings using the AI Service and store them in the `reference_cases` table.*

## Testing & Verification

We have organized all testing and debugging scripts in the `test/` folder.

### Automated Tests
- **Frontend**: `flutter test`
- **Backend Health**: `python test/check_services.py` (Checks if all microservices are up)

### Debugging Scripts
Use these scripts to verify specific components if you encounter issues:

- `test/verify_features.py`: Checks if core features (Timeline, Matching) are accessible.
- `test/test_similarity.py`: **Critical for AI**. Tests the vector matching logic to ensure embeddings are working.
- `test/verify_frontend_build.py`: Verifies the Flutter build process.

### SQL Debugging
If you need to debug database issues or understand the schema, check `test/sql_debug/`.
- `schema.sql`: The master schema file (in `infrastructure/supabase/`).
- `test/sql_debug/`: Contains individual setup scripts for specific features (e.g., `setup_feedback.sql`, `fix_realtime.sql`) which can be run individually to patch or reset specific parts of the DB.
