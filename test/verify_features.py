import requests
import json
import time

BASE_URL = "http://localhost"
PORTS = {
    "user": 8001,
    "timeline": 8002,
    "matching": 8003,
    "ai": 8004,
    "export": 8005,
    "notification": 8006
}

HEADERS = {
    "Authorization": "Bearer mock-token",
    "Content-Type": "application/json"
}

def print_result(feature, status, details=""):
    icon = "✅" if status == "Working" else "❌"
    print(f"{icon} **{feature}**: {status} {details}")

def test_user_service():
    url = f"{BASE_URL}:{PORTS['user']}/profile"
    
    # 1. Update Profile
    profile_data = {
        "full_name": "Test User",
        "age": 30,
        "gender": "Male",
        "bio": "Test bio"
    }
    try:
        res = requests.post(url, headers=HEADERS, json=profile_data)
        if res.status_code == 200:
            print_result("User Profile Update", "Working")
        else:
            print_result("User Profile Update", "Failed", f"Status: {res.status_code}, Body: {res.text}")
    except Exception as e:
        print_result("User Profile Update", "Failed", str(e))

    # 2. Get Profile
    try:
        res = requests.get(url, headers=HEADERS)
        if res.status_code == 200:
            print_result("User Profile Retrieval", "Working")
        else:
            print_result("User Profile Retrieval", "Failed", f"Status: {res.status_code}")
    except Exception as e:
        print_result("User Profile Retrieval", "Failed", str(e))

def test_timeline_service():
    url = f"{BASE_URL}:{PORTS['timeline']}/timelines"
    
    # 1. Create Timeline
    timeline_data = {
        "title": "My Symptoms",
        "description": "Started last week",
        "symptoms": [
            {"symptom_name": "Headache", "severity": 7, "start_date": "2023-10-01"},
            {"symptom_name": "Fever", "severity": 5, "start_date": "2023-10-02"}
        ]
    }
    timeline_id = None
    try:
        res = requests.post(url, headers=HEADERS, json=timeline_data)
        if res.status_code == 200:
            print_result("Timeline Creation", "Working")
            timeline_id = res.json().get("id")
        else:
            print_result("Timeline Creation", "Failed", f"Status: {res.status_code}, Body: {res.text}")
    except Exception as e:
        print_result("Timeline Creation", "Failed", str(e))
        
    return timeline_id

def test_ai_service():
    # 1. Diagnose
    url = f"{BASE_URL}:{PORTS['ai']}/diagnose"
    data = {
        "symptoms": ["Headache", "Fever", "Rash"],
        "age": 30,
        "gender": "Male",
        "history": "None"
    }
    try:
        res = requests.post(url, headers=HEADERS, json=data)
        if res.status_code == 200:
            print_result("AI Diagnosis", "Working")
        else:
            print_result("AI Diagnosis", "Failed", f"Status: {res.status_code}, Body: {res.text}")
    except Exception as e:
        print_result("AI Diagnosis", "Failed", str(e))

def test_matching_service(timeline_id):
    if not timeline_id:
        print_result("Matching Service", "Skipped", "(No timeline created)")
        return

    url = f"{BASE_URL}:{PORTS['matching']}/match"
    data = {"timeline_id": timeline_id, "limit": 5}
    try:
        res = requests.post(url, headers=HEADERS, json=data)
        if res.status_code == 200:
            print_result("Patient Matching", "Working")
        else:
            print_result("Patient Matching", "Failed", f"Status: {res.status_code}, Body: {res.text}")
    except Exception as e:
        print_result("Patient Matching", "Failed", str(e))

def test_export_service(timeline_id):
    if not timeline_id:
        print_result("PDF Export", "Skipped", "(No timeline created)")
        return

    url = f"{BASE_URL}:{PORTS['export']}/export/pdf"
    data = {"timeline_id": timeline_id}
    try:
        res = requests.post(url, headers=HEADERS, json=data)
        if res.status_code == 200:
            print_result("PDF Export", "Working")
        else:
            print_result("PDF Export", "Failed", f"Status: {res.status_code}, Body: {res.text}")
    except Exception as e:
        print_result("PDF Export", "Failed", str(e))

if __name__ == "__main__":
    print("Starting Feature Verification...\n")
    test_user_service()
    timeline_id = test_timeline_service()
    test_ai_service()
    test_matching_service(timeline_id)
    test_export_service(timeline_id)
    print("\nVerification Complete.")
