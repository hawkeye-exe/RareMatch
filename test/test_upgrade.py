import requests
import json

BASE_URL = "http://127.0.0.1:8003"
TIMELINE_ID = "test-timeline-id" # You might need a real ID if the service checks DB

def test_debug_endpoint():
    print("\n--- Testing Debug Endpoint ---")
    try:
        # We need a valid timeline ID for this to work fully, 
        # but let's see if we can trigger it or mock it.
        # If the service requires a real ID, we might get a 500 or 404.
        # Let's try to create a dummy timeline first if we had access, 
        # but for now let's just try the endpoint.
        
        payload = {
            "symptoms": ["headache", "fever", "nausea"] 
        }
        response = requests.post(f"{BASE_URL}/debug/similarity", json=payload)
        
        if response.status_code == 200:
            print("Success!")
            data = response.json()
            print(json.dumps(data, indent=2))
        else:
            print(f"Failed: {response.status_code}")
            print(response.text)
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_debug_endpoint()
