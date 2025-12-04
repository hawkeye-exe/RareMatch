import sys
import os
from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime

# Add parent directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from shared.auth import get_current_user
from shared.supabase_client import get_supabase_client
from shared.logger import setup_logger

app = FastAPI(title="RareMatch Notification Service", version="1.0.0")
logger = setup_logger("notification-service")

class NotificationRequest(BaseModel):
    user_id: str
    title: str
    body: str
    data: Optional[Dict[str, Any]] = None

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "notification-service"}

def send_fcm_push(token: str, title: str, body: str):
    # Placeholder for FCM logic
    logger.info(f"Sending FCM push to {token}: {title} - {body}")

@app.post("/notifications/send")
async def send_notification(request: NotificationRequest, background_tasks: BackgroundTasks, user: dict = Depends(get_current_user)):
    """
    Send a notification to a user.
    1. Insert into 'notifications' table (for in-app history).
    2. Trigger Realtime event (via table insert).
    3. Send Push Notification (if token exists).
    """
    supabase = get_supabase_client()
    
    # 1. Insert into DB
    notification_data = {
        "user_id": request.user_id,
        "title": request.title,
        "body": request.body,
        "data": request.data,
        "read": False,
        "created_at": datetime.utcnow().isoformat()
    }
    
    try:
        supabase.table("notifications").insert(notification_data).execute()
    except Exception as e:
        logger.error(f"Error saving notification: {e}")
        # Continue to push even if save fails? Maybe.
    
    # 2. Get User's FCM Token (assuming stored in profiles)
    try:
        profile_response = supabase.table("profiles").select("fcm_token").eq("id", request.user_id).single().execute()
        if profile_response.data and profile_response.data.get("fcm_token"):
            fcm_token = profile_response.data.get("fcm_token")
            background_tasks.add_task(send_fcm_push, fcm_token, request.title, request.body)
    except Exception as e:
        logger.warning(f"Could not fetch FCM token: {e}")

    return {"status": "queued"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8006)
