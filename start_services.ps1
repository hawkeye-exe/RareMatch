# Configuration
# TODO: Update this path to your local python executable (in venv)
$VENV_PYTHON = "python" 
# If you have a specific venv, uncomment and set it:
# $VENV_PYTHON = "C:\path\to\venv\Scripts\python.exe"

$BASE_DIR = "$PSScriptRoot\backend"

function Start-Service {
    param (
        [string]$Name,
        [string]$Path,
        [int]$Port
    )
    Write-Host "Starting $Name on port $Port..."
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$Path'; & '$VENV_PYTHON' main.py"
}

# 1. User Service (8001)
Start-Service -Name "User Service" -Path "$BASE_DIR\user-service" -Port 8001

# 2. Timeline Service (8002)
Start-Service -Name "Timeline Service" -Path "$BASE_DIR\timeline-service" -Port 8002

# 3. Matching Service (8003)
Start-Service -Name "Matching Service" -Path "$BASE_DIR\matching-service" -Port 8003

# 4. AI Service (8004)
Start-Service -Name "AI Service" -Path "$BASE_DIR\ai-service" -Port 8004

# 5. Export Service (8005)
Start-Service -Name "Export Service" -Path "$BASE_DIR\export-service" -Port 8005

Write-Host "All services launched! Check the new windows for logs."
