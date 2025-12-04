import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://placeholder-project.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "placeholder-key")

def get_supabase_client() -> Client:
    """Returns a Supabase client instance with service role privileges."""
    return create_client(SUPABASE_URL, SUPABASE_KEY)
