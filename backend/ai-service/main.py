import sys
import os
from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel
from typing import List, Optional, Dict
import google.generativeai as genai
import json
import tensorflow as tf
import pandas as pd
import numpy as np

from dotenv import load_dotenv

# Add parent directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from shared.logger import setup_logger

# Load environment variables
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))

app = FastAPI(title="RareMatch AI Service", version="1.0.0")
logger = setup_logger("ai-service")

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
GOOGLE_AI_API_KEY = os.getenv("GOOGLE_AI_API_KEY")
if GOOGLE_AI_API_KEY:
    genai.configure(api_key=GOOGLE_AI_API_KEY)
else:
    logger.warning("GOOGLE_AI_API_KEY not found in environment variables.")

# Load ML Model and Metadata
# Load ML Models
EMBEDDING_MODEL_PATH = os.path.join(os.path.dirname(__file__), "rare_match_embedding_model.h5")
FULL_MODEL_PATH = os.path.join(os.path.dirname(__file__), "rare_match_multilabel_model.h5")
VOCAB_PATH = os.path.join(os.path.dirname(__file__), "symptom_vocab.csv")

embedding_model = None
full_model = None
symptom_to_idx = {}
vocab_size = 0

try:
    if os.path.exists(EMBEDDING_MODEL_PATH) and os.path.exists(FULL_MODEL_PATH) and os.path.exists(VOCAB_PATH):
        logger.info(f"Loading embedding model from {EMBEDDING_MODEL_PATH}")
        embedding_model = tf.keras.models.load_model(EMBEDDING_MODEL_PATH)
        
        logger.info(f"Loading full classification model from {FULL_MODEL_PATH}")
        full_model = tf.keras.models.load_model(FULL_MODEL_PATH)
        
        logger.info(f"Loading vocab from {VOCAB_PATH}")
        vocab_df = pd.read_csv(VOCAB_PATH)
        symptom_vocab = vocab_df["symptom"].tolist()
        symptom_to_idx = {s: i for i, s in enumerate(symptom_vocab)}
        vocab_size = len(symptom_vocab)
        logger.info(f"Models loaded successfully. Vocab size: {vocab_size}")
    else:
        logger.warning("Model or vocab file not found. Using mock embeddings.")
except Exception as e:
    logger.error(f"Failed to load ML models: {e}")

# Load Metadata
METADATA_PATH = os.path.join(os.path.dirname(__file__), "rare_match_metadata.json")
feature_cols = []
label_cols = []

try:
    if os.path.exists(METADATA_PATH):
        with open(METADATA_PATH, "r") as f:
            metadata = json.load(f)
            feature_cols = metadata.get("feature_cols", [])
            label_cols = metadata.get("label_cols", [])
            logger.info(f"Loaded {len(feature_cols)} feature columns and {len(label_cols)} labels from metadata.")
    else:
        logger.warning("Metadata file not found!")
except Exception as e:
    logger.error(f"Failed to load metadata: {e}")

class EmbedRequest(BaseModel):
    text: str # Keeping 'text' for compatibility
    symptoms: Optional[List[str]] = None
    # Add other fields if the frontend sends them, otherwise we use defaults
    age: Optional[int] = 30
    symptom_count: Optional[int] = 1

class DiagnoseRequest(BaseModel):
    symptoms: List[str]
    age: Optional[int] = None
    gender: Optional[str] = None
    history: Optional[str] = None
    
def preprocess_input(text: str, symptoms: List[str] = None, age: int = 30):
    if not feature_cols:
        logger.error("Feature columns not loaded. Cannot preprocess.")
        return None, None

    # 1. Parse Symptoms
    input_symptoms = []
    if symptoms:
        input_symptoms.extend(symptoms)
    if text and not symptoms:
        input_symptoms.extend([s.strip() for s in text.split(',')])
    
    # Normalize input symptoms
    normalized_symptoms = [s.lower().strip().replace(" ", "_") for s in input_symptoms]
    
    # 2. Initialize Feature Vector
    # Create a dictionary for easier mapping, then convert to list
    feature_map = {col: 0.0 for col in feature_cols}
    
    # 3. Map Symptoms to Features (with Fuzzy Matching)
    import difflib
    
    # Pre-compute valid symptom names from feature_cols (stripping 'sym_')
    valid_symptoms = [col.replace("sym_", "") for col in feature_cols if col.startswith("sym_")]
    
    active_features = []
    for s in normalized_symptoms:
        # 1. Try Exact Match
        key = f"sym_{s}"
        if key in feature_map:
            feature_map[key] = 1.0
            active_features.append(key)
            continue
            
        # 2. Try Fuzzy Match
        matches = difflib.get_close_matches(s, valid_symptoms, n=1, cutoff=0.7)
        if matches:
            best_match = matches[0]
            key = f"sym_{best_match}"
            if key in feature_map:
                feature_map[key] = 1.0
                active_features.append(f"{key} (fuzzy: {s})")
                logger.info(f"Fuzzy match: '{s}' -> '{best_match}'")
        else:
            logger.warning(f"No match found for symptom: '{s}'")
            
    # 4. Handle Numeric Fields (Defaults for now as frontend might not send them yet)
    if "age" in feature_map:
        feature_map["age"] = float(age)
    if "symptom_count" in feature_map:
        feature_map["symptom_count"] = float(len(normalized_symptoms))
        
    # 5. Convert to Ordered List
    # STRICTLY follow the order in feature_cols
    input_vector = [feature_map[col] for col in feature_cols]
    
    # 6. Reshape for Model (1, N)
    return np.array([input_vector], dtype=np.float32), active_features

@app.post("/embed")
def generate_embedding(request: EmbedRequest):
    """Generate embedding and disease probabilities using custom TensorFlow models."""
    if embedding_model and full_model and feature_cols:
        try:
            input_vec, active_features = preprocess_input(request.text, request.symptoms, request.age)
            if input_vec is not None:
                # Verify shape
                expected_shape = embedding_model.input_shape[1]
                if input_vec.shape[1] != expected_shape:
                    logger.error(f"Shape mismatch! Model expects {expected_shape}, got {input_vec.shape[1]}")
                    return {"embedding": [0.0] * 256, "probabilities": [], "debug_info": {"error": "Shape mismatch"}}

                # 1. Generate Embedding
                embedding = embedding_model.predict(input_vec)
                
                # 2. Generate Disease Probabilities
                predictions = full_model.predict(input_vec)[0] # Get first batch
                
                # Get top 5 predictions
                top_indices = predictions.argsort()[-5:][::-1]
                top_diseases = []
                for idx in top_indices:
                    if idx < len(label_cols):
                        disease_name = label_cols[idx].replace("label_", "")
                        score = float(predictions[idx])
                        top_diseases.append({"disease": disease_name, "probability": score})

                return {
                    "embedding": embedding[0].tolist(),
                    "probabilities": top_diseases,
                    "debug_info": {
                        "active_features": active_features,
                        "vector_sum": float(np.sum(input_vec)),
                        "input_shape": input_vec.shape
                    }
                }
        except Exception as e:
            logger.error(f"Error generating embedding with model: {e}")
            return {"embedding": [0.0] * 256, "probabilities": [], "debug_info": {"error": str(e)}}
    
    # Fallback
    logger.warning("Using fallback embedding (zeros)")
    return {"embedding": [0.0] * 256, "probabilities": [], "debug_info": {"status": "fallback"}}

@app.post("/diagnose")
async def diagnose_symptoms(request: DiagnoseRequest):
    """Generate differential diagnosis using Gemini Pro (keeping this as is)."""
    if not GOOGLE_AI_API_KEY:
        return {
            "diagnosis": "Mock Diagnosis: Rare Disease X",
            "confidence": 0.85,
            "reasoning": "Symptoms match typical presentation.",
            "next_steps": ["Consult a specialist", "Genetic testing"]
        }

    try:
        model = genai.GenerativeModel('gemini-2.0-flash')
        prompt = f"""
        Act as an expert medical diagnostician for rare diseases.
        Patient Profile: Age {request.age}, Gender {request.gender}
        Medical History: {request.history}
        Symptoms: {', '.join(request.symptoms)}
        
        Provide a differential diagnosis with top 3 potential rare diseases.
        For each, provide:
        1. Disease Name
        2. Confidence Level (Low/Medium/High)
        3. Reasoning based on symptoms
        4. Recommended next steps (tests/specialists)
        
        Format as JSON.
        """
        
        response = model.generate_content(prompt)
        return {"result": response.text}
    except Exception as e:
        logger.error(f"Error generating diagnosis: {e}")
        # Mock Fallback
        return {
            "result": json.dumps({
                "diagnosis": [
                    {
                        "name": "Ehlers-Danlos Syndrome",
                        "confidence": "High",
                        "reasoning": "Joint hypermobility and skin elasticity match symptoms.",
                        "next_steps": ["Genetic testing", "Rheumatology consult"]
                    },
                    {
                        "name": "Marfan Syndrome",
                        "confidence": "Medium",
                        "reasoning": "Tall stature and heart murmur are indicative.",
                        "next_steps": ["Echocardiogram", "Eye exam"]
                    }
                ]
            })
        }

class ChatRequest(BaseModel):
    message: str
    history: List[Dict[str, str]] = [] # [{"role": "user", "parts": ["msg"]}, {"role": "model", "parts": ["msg"]}]

@app.post("/chat")
async def chat_with_ai(request: ChatRequest):
    """
    Conversational endpoint using Gemini Pro.
    """
    if not GOOGLE_AI_API_KEY:
        return {"response": "I'm sorry, but I can't chat right now because my API key is missing."}

    try:
        model = genai.GenerativeModel('gemini-2.0-flash')
        
        # Convert history to Gemini format if needed, or use start_chat
        # Simple stateless approach for now:
        chat = model.start_chat(history=request.history)
        
        response = chat.send_message(request.message)
        return {"response": response.text}
    except Exception as e:
        logger.error(f"Error in chat: {e}")
        return {"response": "I'm having trouble connecting to my brain right now. Please try again later."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8004)
