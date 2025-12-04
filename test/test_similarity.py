import requests
import json

try:
    response = requests.post(
        'http://localhost:8003/debug/similarity', 
        json={'symptoms': ['high_fever', 'headache']},
        timeout=30
    )
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print(f"Error: {e}")
