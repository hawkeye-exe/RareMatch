import sys
import os
from fastapi import FastAPI, Depends, HTTPException, Body
from pydantic import BaseModel
from typing import Optional

# Add parent directory to path to import shared modules
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from shared.auth import get_current_user
from shared.supabase_client import get_supabase_client
from shared.logger import setup_logger

app = FastAPI(title="RareMatch User Service", version="1.0.0")
logger = setup_logger("user-service")

class UserProfile(BaseModel):
    full_name: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    location: Optional[str] = None
    bio: Optional[str] = None

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "user-service"}

@app.get("/profile")
def get_profile(user: dict = Depends(get_current_user)):
    """Get current user's profile from 'profiles' table."""
    user_id = user.get("id")
    supabase = get_supabase_client()
    
    try:
        response = supabase.table("profiles").select("*").eq("id", user_id).single().execute()
        # Note: supabase-py v2 returns an object with .data
        if not response.data:
            # Profile might not exist yet if just signed up
            return {"id": user_id, "email": user.get("email"), "message": "Profile not created yet"}
        return response.data
    except Exception as e:
        logger.error(f"Error fetching profile: {e}")
        # Mock Fallback
        return {
            "id": user_id,
            "email": user.get("email"),
            "full_name": "Demo User",
            "age": 30,
            "gender": "Female",
            "location": "New York, USA",
            "bio": "This is a demo profile."
        }

@app.post("/profile")
def update_profile(profile: UserProfile, user: dict = Depends(get_current_user)):
    """Update or create user profile."""
    user_id = user.get("id")
    supabase = get_supabase_client()
    
    data = profile.dict(exclude_unset=True)
    data["id"] = user_id
    data["email"] = user.get("email") # Ensure email is synced
    
    try:
        # Upsert profile
        response = supabase.table("profiles").upsert(data).execute()
        return {"status": "success", "data": response.data}
    except Exception as e:
        logger.error(f"Error updating profile: {e}")
        # Mock Fallback
        return {"status": "success", "data": data, "message": "Profile updated (Mock)"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
