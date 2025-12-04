import os
import sys
import json
import numpy as np
import pandas as pd
from supabase import create_client, Client
from dotenv import load_dotenv
import time

# Load env vars
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") # Or SERVICE_ROLE_KEY if RLS blocks insert

if not SUPABASE_URL or not SUPABASE_KEY:
    print("Error: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env")
    sys.exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Paths
BASE_DIR = os.path.join(os.path.dirname(__file__), "Dataset-training")
EMBEDDINGS_PATH = os.path.join(BASE_DIR, "patient_embeddings.npy")
MASTER_CSV_PATH = os.path.join(BASE_DIR, "ml_master_patients.csv")
METADATA_PATH = os.path.join(BASE_DIR, "rare_match_metadata.json")

def upload_data():
    print("Loading data...")
    
    if not os.path.exists(EMBEDDINGS_PATH):
        print(f"Error: {EMBEDDINGS_PATH} not found.")
        return

    # Load Embeddings
    embeddings = np.load(EMBEDDINGS_PATH)
    print(f"Loaded embeddings shape: {embeddings.shape}")

    # Load Master CSV for metadata (diagnosis, symptoms)
    df = pd.read_csv(MASTER_CSV_PATH)
    print(f"Loaded master CSV shape: {df.shape}")

    # Load Metadata to know label columns
    with open(METADATA_PATH, "r") as f:
        metadata = json.load(f)
        label_cols = metadata.get("label_cols", [])

    # Prepare batch
    records = []
    batch_size = 100
    total_records = len(df)

    # Check existing count
    try:
        count_response = supabase.table("reference_cases").select("id", count="exact").execute()
        existing_count = count_response.count
        print(f"Found {existing_count} existing records.")
    except Exception as e:
        print(f"Error checking count: {e}")
        existing_count = 0

    print(f"Preparing to upload {total_records} records (skipping first {existing_count})...")

    for i, row in df.iterrows():
        if i < existing_count:
            continue
            
        # Extract Diagnosis (Label)
        # Find which label column is 1
        diagnosis = "Unknown"
        for label in label_cols:
            if row.get(label) == 1:
                diagnosis = label.replace("label_", "")
                break
        
        # Extract Symptoms (Features that are 1)
        # We can iterate over columns starting with 'sym_'
        symptoms = []
        for col in df.columns:
            if col.startswith("sym_") and row[col] == 1:
                symptoms.append(col.replace("sym_", ""))

        record = {
            "patient_id": f"pat_{i}", # Generate a simple ID or use one if exists
            "diagnosis_label": diagnosis,
            "symptoms": symptoms, # Store as JSON array
            "embedding": embeddings[i].tolist()
        }
        records.append(record)

        if len(records) >= batch_size:
            try:
                supabase.table("reference_cases").insert(records).execute()
                print(f"Uploaded batch {i+1}/{total_records}")
            except Exception as e:
                print(f"Error uploading batch: {e}")
            records = []
            time.sleep(0.1) # Rate limiting

    # Upload remaining
    if records:
        try:
            supabase.table("reference_cases").insert(records).execute()
            print(f"Uploaded final batch.")
        except Exception as e:
            print(f"Error uploading final batch: {e}")

    print("Upload complete!")

if __name__ == "__main__":
    upload_data()
