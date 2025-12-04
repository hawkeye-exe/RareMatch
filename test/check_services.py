import requests
import sys

SERVICES = {
    "User Service": "http://127.0.0.1:8001/health",
    "Timeline Service": "http://127.0.0.1:8002/health",
    "Matching Service": "http://127.0.0.1:8003/health",
    "AI Service": "http://127.0.0.1:8004/health",
    "Export Service": "http://127.0.0.1:8005/health",
}

def check_services():
    print("Checking services...")
    all_healthy = True
    for name, url in SERVICES.items():
        try:
            response = requests.get(url, timeout=2)
            if response.status_code == 200:
                print(f"✅ {name}: Healthy")
            else:
                print(f"❌ {name}: Error {response.status_code}")
                all_healthy = False
        except requests.exceptions.ConnectionError:
            print(f"❌ {name}: Connection Refused (Not Running?)")
            all_healthy = False
        except Exception as e:
            print(f"❌ {name}: Failed ({e})")
            all_healthy = False
            
    if all_healthy:
        print("\nAll services are running correctly!")
        sys.exit(0)
    else:
        print("\nSome services are down.")
        sys.exit(1)

if __name__ == "__main__":
    check_services()
