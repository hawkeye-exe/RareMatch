import sys
import os
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import httpx

# Add parent directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from shared.auth import get_current_user
from shared.supabase_client import get_supabase_client
from shared.logger import setup_logger

app = FastAPI(title="RareMatch Matching Engine", version="1.0.0")
logger = setup_logger("matching-service")

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
AI_SERVICE_URL = os.getenv("AI_SERVICE_URL", "http://127.0.0.1:8004")

class MatchRequest(BaseModel):
    timeline_id: str
    limit: int = 10
    force_refresh: bool = False

class MatchResult(BaseModel):
    match_id: str
    similarity: float
    diagnosis: Optional[str] = None
    symptoms: List[str]
    explanation: Optional[str] = None
    
class DebugRequest(BaseModel):
    timeline_id: Optional[str] = None
    symptoms: Optional[List[str]] = None

class FeedbackRequest(BaseModel):
    timeline_id: str
    match_id: str
    is_helpful: bool

@app.post("/feedback")
async def submit_feedback(request: FeedbackRequest, user: dict = Depends(get_current_user)):
    """
    Submit user feedback for a match.
    """
    try:
        user_id = user.user.id
    except AttributeError:
        user_id = user.get("id")
        
    supabase = get_supabase_client()
    
    try:
        supabase.table("match_feedback").insert({
            "user_id": user_id,
            "timeline_id": request.timeline_id,
            "match_id": request.match_id,
            "is_helpful": request.is_helpful
        }).execute()
        return {"status": "success", "message": "Feedback submitted"}
    except Exception as e:
        logger.error(f"Error submitting feedback: {e}")
        raise HTTPException(status_code=500, detail="Failed to submit feedback")

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "matching-service"}

# Symptom Weights (Default: 1.0, Rare/Severe: 3.0)
SYMPTOM_WEIGHTS = {
    "itching": 1.0, "skin_rash": 1.0, "nodal_skin_eruptions": 2.0,
    "continuous_sneezing": 1.0, "shivering": 1.0, "chills": 1.0,
    "joint_pain": 1.0, "stomach_pain": 1.0, "acidity": 1.0,
    "ulcers_on_tongue": 1.0, "muscle_wasting": 3.0, "vomiting": 1.0,
    "burning_micturition": 1.0, "spotting_ urination": 2.0, "fatigue": 1.0,
    "weight_gain": 1.0, "anxiety": 1.0, "cold_hands_and_feets": 1.0,
    "mood_swings": 1.0, "weight_loss": 1.0, "restlessness": 1.0,
    "lethargy": 1.0, "patches_in_throat": 1.0, "irregular_sugar_level": 2.0,
    "cough": 1.0, "high_fever": 1.0, "sunken_eyes": 1.0,
    "breathlessness": 2.0, "sweating": 1.0, "dehydration": 1.0,
    "indigestion": 1.0, "headache": 1.0, "yellowish_skin": 2.0,
    "dark_urine": 2.0, "nausea": 1.0, "loss_of_appetite": 1.0,
    "pain_behind_the_eyes": 1.0, "back_pain": 1.0, "constipation": 1.0,
    "abdominal_pain": 1.0, "diarrhoea": 1.0, "mild_fever": 1.0,
    "yellow_urine": 1.0, "yellowing_of_eyes": 2.0, "acute_liver_failure": 3.0,
    "fluid_overload": 3.0, "swelling_of_stomach": 2.0, "swelled_lymph_nodes": 2.0,
    "malaise": 1.0, "blurred_and_distorted_vision": 2.0, "phlegm": 1.0,
    "throat_irritation": 1.0, "redness_of_eyes": 1.0, "sinus_pressure": 1.0,
    "runny_nose": 1.0, "congestion": 1.0, "chest_pain": 2.0,
    "weakness_in_limbs": 1.0, "fast_heart_rate": 2.0, "pain_during_bowel_movements": 1.0,
    "pain_in_anal_region": 1.0, "bloody_stool": 3.0, "irritation_in_anus": 1.0,
    "neck_pain": 1.0, "dizziness": 1.0, "cramps": 1.0, "bruising": 2.0,
    "obesity": 1.0, "swollen_legs": 1.0, "swollen_blood_vessels": 2.0,
    "puffy_face_and_eyes": 2.0, "enlarged_thyroid": 2.0, "brittle_nails": 1.0,
    "swollen_extremeties": 2.0, "excessive_hunger": 1.0, "extra_marital_contacts": 1.0,
    "drying_and_tingling_lips": 1.0, "slurred_speech": 3.0, "knee_pain": 1.0,
    "hip_joint_pain": 1.0, "muscle_weakness": 2.0, "stiff_neck": 1.0,
    "swelling_joints": 1.0, "movement_stiffness": 1.0, "spinning_movements": 2.0,
    "loss_of_balance": 2.0, "unsteadiness": 2.0, "weakness_of_one_body_side": 3.0,
    "loss_of_smell": 2.0, "bladder_discomfort": 1.0, "foul_smell_of_urine": 1.0,
    "continuous_feel_of_urine": 1.0, "passage_of_gases": 1.0, "internal_itching": 1.0,
    "toxic_look_(typhos)": 3.0, "depression": 1.0, "irritability": 1.0,
    "muscle_pain": 1.0, "altered_sensorium": 3.0, "red_spots_over_body": 2.0,
    "belly_pain": 1.0, "abnormal_menstruation": 1.0, "dischromic _patches": 1.0,
    "watering_from_eyes": 1.0, "increased_appetite": 1.0, "polyuria": 2.0,
    "family_history": 1.0, "mucoid_sputum": 1.0, "rusty_sputum": 2.0,
    "lack_of_concentration": 1.0, "visual_disturbances": 2.0,
    "receiving_blood_transfusion": 2.0, "receiving_unsterile_injections": 2.0,
    "coma": 3.0, "stomach_bleeding": 3.0, "distention_of_abdomen": 2.0,
    "history_of_alcohol_consumption": 1.0, "fluid_overload": 3.0,
    "blood_in_sputum": 3.0, "prominent_veins_on_calf": 2.0, "palpitations": 2.0,
    "painful_walking": 1.0, "pus_filled_pimples": 1.0, "blackheads": 1.0,
    "scurring": 1.0, "skin_peeling": 1.0, "silver_like_dusting": 1.0,
    "small_dents_in_nails": 1.0, "inflammatory_nails": 1.0, "blister": 1.0,
    "red_sore_around_nose": 1.0, "yellow_crust_ooze": 1.0
}

def calculate_weighted_jaccard_similarity(user_symptoms: List[str], match_symptoms: List[str]) -> float:
    if not user_symptoms or not match_symptoms:
        return 0.0
        
    user_set = set([s.lower().strip() for s in user_symptoms])
    match_set = set([s.lower().strip() for s in match_symptoms])
    
    intersection = user_set.intersection(match_set)
    union = user_set.union(match_set)
    
    if not union:
        return 0.0
        
    intersection_weight = sum([SYMPTOM_WEIGHTS.get(s, 1.0) for s in intersection])
    union_weight = sum([SYMPTOM_WEIGHTS.get(s, 1.0) for s in union])
    
    return intersection_weight / union_weight if union_weight > 0 else 0.0

@app.post("/match", response_model=List[MatchResult])
async def find_matches(request: MatchRequest, user: dict = Depends(get_current_user)):
    """
    Find similar cases using Hybrid Scoring (Vector + Jaccard).
    Caches results in 'matches' table.
    """
    try:
        user_id = user.user.id
    except AttributeError:
        user_id = user.get("id")
    supabase = get_supabase_client()
    
    # 0. Check Cache
    if not request.force_refresh:
        try:
            cached = supabase.table("matches").select("match_data").eq("timeline_id", request.timeline_id).maybe_single().execute()
            if cached and cached.data:
                logger.info(f"Returning cached matches for timeline {request.timeline_id}")
                return cached.data["match_data"]
        except Exception as e:
            logger.warning(f"Cache lookup failed: {e}")

    # 1. Fetch Timeline Data
    try:
        timeline_response = supabase.table("timelines").select("*").eq("id", request.timeline_id).single().execute()
        if not timeline_response.data:
            raise HTTPException(status_code=404, detail="Timeline not found")
        timeline = timeline_response.data
    except Exception as e:
        logger.error(f"Error fetching timeline: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch timeline")

    # 2. Generate Embedding
    user_symptoms_list = [s["symptom_name"] for s in timeline.get("symptoms", [])]
    symptoms_text = ", ".join(user_symptoms_list)
    
    embedding = []
    
    async with httpx.AsyncClient() as client:
        try:
            payload = {
                "text": symptoms_text,
                "symptoms": user_symptoms_list,
            }
            response = await client.post(f"{AI_SERVICE_URL}/embed", json=payload)
            if response.status_code == 200:
                data = response.json()
                embedding = data.get("embedding")
            else:
                logger.error(f"AI Service error: {response.text}")
                embedding = [0.1] * 256 
        except Exception as e:
            logger.error(f"Failed to call AI Service: {e}")
            embedding = [0.1] * 256

    # 3. Hybrid Search
    try:
        params = {
            "query_embedding": embedding,
            "match_threshold": 0.1, 
            "match_count": request.limit * 3 
        }
        response = supabase.rpc("match_reference_cases", params).execute()
        
        scored_matches = []
        for item in response.data:
            match_symptoms = item.get("symptoms", [])
            vector_sim = item.get("similarity")
            jaccard_sim = calculate_weighted_jaccard_similarity(user_symptoms_list, match_symptoms)
            hybrid_score = (0.6 * vector_sim) + (0.4 * jaccard_sim)
            
            shared = set([s.lower() for s in user_symptoms_list]).intersection(set([s.lower() for s in match_symptoms]))
            explanation = f"Shared symptoms: {', '.join(list(shared)[:3])}"
            if len(shared) > 3:
                explanation += f" and {len(shared)-3} more."
            scored_matches.append({
                "data": item,
                "score": hybrid_score,
                "explanation": explanation
            })
            
        scored_matches.sort(key=lambda x: x["score"], reverse=True)
        
        final_matches = []
        for m in scored_matches[:request.limit]:
            item = m["data"]
            final_matches.append(MatchResult(
                match_id=str(item.get("id")),
                similarity=m["score"],
                diagnosis=item.get("diagnosis_label", "Unknown"),
                symptoms=item.get("symptoms", []),
                explanation=m["explanation"]
            ))

        # 4. Cache Results
        try:
            # Delete old cache
            supabase.table("matches").delete().eq("timeline_id", request.timeline_id).execute()
            # Insert new cache
            cache_data = [r.model_dump() for r in final_matches]
            supabase.table("matches").insert({
                "timeline_id": request.timeline_id,
                "match_data": cache_data
            }).execute()
            logger.info(f"Cached {len(final_matches)} matches for timeline {request.timeline_id}")
        except Exception as e:
            logger.error(f"Failed to cache results: {e}")
            
        return final_matches

    except Exception as e:
        logger.error(f"Error executing search: {e}")
        return []

@app.post("/debug/similarity")
async def debug_similarity(request: DebugRequest):
    """
    Developer endpoint to inspect the matching process.
    """
    supabase = get_supabase_client()
    
    user_symptoms = []
    if request.symptoms:
        user_symptoms = request.symptoms
    elif request.timeline_id:
        try:
            timeline = supabase.table("timelines").select("*").eq("id", request.timeline_id).single().execute().data
            user_symptoms = [s["symptom_name"] for s in timeline.get("symptoms", [])]
        except Exception as e:
            return {"error": f"Failed to fetch timeline: {e}"}
    else:
        return {"error": "Must provide either timeline_id or symptoms"}
    
    async with httpx.AsyncClient() as client:
        payload = {"text": "", "symptoms": user_symptoms}
        ai_resp = await client.post(f"{AI_SERVICE_URL}/embed", json=payload)
        ai_data = ai_resp.json()
        
    embedding = ai_data.get("embedding")
    
    params = {
        "query_embedding": embedding,
        "match_threshold": 0.1,
        "match_count": 5
    }
    rpc_resp = supabase.rpc("match_reference_cases", params).execute()
    
    debug_results = []
    for item in rpc_resp.data:
        match_symptoms = item.get("symptoms", [])
        vector_sim = item.get("similarity")
        jaccard_sim = calculate_weighted_jaccard_similarity(user_symptoms, match_symptoms)
        hybrid_score = (0.6 * vector_sim) + (0.4 * jaccard_sim)
        
        debug_results.append({
            "diagnosis": item.get("diagnosis_label"),
            "vector_similarity": vector_sim,
            "jaccard_similarity": jaccard_sim,
            "hybrid_score": hybrid_score,
            "symptoms_match": list(set(user_symptoms).intersection(set(match_symptoms)))
        })
        
    return {
        "user_symptoms": user_symptoms,
        "ai_service_debug": ai_data.get("debug_info"),
        "top_candidates": debug_results
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8003)
