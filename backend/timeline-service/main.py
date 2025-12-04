import sys
import os
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime

# Add parent directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from shared.auth import get_current_user
from shared.supabase_client import get_supabase_client
from shared.logger import setup_logger

app = FastAPI(title="RareMatch Timeline Service", version="1.0.0")
logger = setup_logger("timeline-service")

class SymptomEntry(BaseModel):
    symptom_name: str
    severity: int # 1-10
    start_date: str # YYYY-MM-DD
    end_date: Optional[str] = None
    notes: Optional[str] = None

class TimelineCreate(BaseModel):
    title: str
    description: Optional[str] = None
    symptoms: List[SymptomEntry]

class TimelineUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    symptoms: Optional[List[SymptomEntry]] = None

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "timeline-service"}

@app.post("/timelines")
def create_timeline(timeline: TimelineCreate, user: dict = Depends(get_current_user)):
    user_id = user.get("id")
    supabase = get_supabase_client()
    
    data = timeline.dict()
    data["user_id"] = user_id
    data["created_at"] = datetime.utcnow().isoformat()
    data["updated_at"] = datetime.utcnow().isoformat()
    
    try:
        response = supabase.table("timelines").insert(data).execute()
        return response.data[0]
    except Exception as e:
        logger.error(f"Error creating timeline: {e}")
        # Mock Fallback
        data["id"] = "mock-timeline-id"
        return data

@app.get("/timelines")
def list_timelines(user: dict = Depends(get_current_user)):
    user_id = user.get("id")
    supabase = get_supabase_client()
    
    try:
        response = supabase.table("timelines").select("*").eq("user_id", user_id).execute()
        return response.data
    except Exception as e:
        logger.error(f"Error listing timelines: {e}")
        raise HTTPException(status_code=500, detail="Failed to list timelines")

@app.get("/timelines/{timeline_id}")
def get_timeline(timeline_id: str, user: dict = Depends(get_current_user)):
    user_id = user.get("id")
    supabase = get_supabase_client()
    
    try:
        response = supabase.table("timelines").select("*").eq("id", timeline_id).eq("user_id", user_id).single().execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Timeline not found")
        return response.data
    except Exception as e:
        logger.error(f"Error getting timeline: {e}")
        raise HTTPException(status_code=404, detail="Timeline not found")

@app.put("/timelines/{timeline_id}")
def update_timeline(timeline_id: str, timeline: TimelineUpdate, user: dict = Depends(get_current_user)):
    user_id = user.get("id")
    supabase = get_supabase_client()
    
    data = timeline.dict(exclude_unset=True)
    data["updated_at"] = datetime.utcnow().isoformat()
    
    try:
        response = supabase.table("timelines").update(data).eq("id", timeline_id).eq("user_id", user_id).execute()
        return response.data
    except Exception as e:
        logger.error(f"Error updating timeline: {e}")
        raise HTTPException(status_code=500, detail="Failed to update timeline")

@app.delete("/timelines/{timeline_id}")
def delete_timeline(timeline_id: str, user: dict = Depends(get_current_user)):
    user_id = user.get("id")
    supabase = get_supabase_client()
    
    try:
        supabase.table("timelines").delete().eq("id", timeline_id).eq("user_id", user_id).execute()
        return {"status": "success", "message": "Timeline deleted"}
    except Exception as e:
        logger.error(f"Error deleting timeline: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete timeline")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
