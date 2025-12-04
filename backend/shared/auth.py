from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import Client
from .supabase_client import get_supabase_client

security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """
    Verifies the Supabase JWT token.
    In a real scenario, Supabase Auth handles this, but for microservices,
    we might want to verify the token is valid and extract the user ID.
    """
    token = credentials.credentials
    supabase = get_supabase_client()
    
    try:
        # Supabase-py doesn't expose a direct 'verify_jwt' easily without gotrue, 
        # but we can get the user from the token if we use the client.
        # For microservices, we often trust the Gateway or verify signature.
        # Here we will assume the token is passed to Supabase calls or validated.
        
        # Simple mock validation for now or use supabase.auth.get_user(token)
        user_response = supabase.auth.get_user(token)
        if not user_response:
             raise HTTPException(status_code=401, detail="Invalid token")
        
        # Extract user from UserResponse and return as dict
        # UserResponse usually has a 'user' attribute
        user = user_response.user
        return {"id": user.id, "email": user.email}
    except Exception as e:
        # Fallback for mock/dev if Supabase is not reachable
        if token == "mock-token":
            return {"id": "mock-user-id", "email": "test@example.com"}
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")

def get_current_user(user: dict = Depends(verify_token)):
    return user
