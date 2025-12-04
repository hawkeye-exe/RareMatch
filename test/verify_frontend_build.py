import subprocess
import sys
import os

def run_command(command, cwd=None):
    print(f"Running: {command}")
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {command}")
        print(e.stderr)
        return False

def verify_flutter_build():
    project_dir = r"c:\Users\alwin\OneDrive\Documents\hackathon\HackSpace\rarematch"
    
    print("--- Verifying Flutter Project ---")
    
    # 1. Check if 'flutter pub get' runs successfully
    print("\n1. Running 'flutter pub get'...")
    if not run_command("flutter pub get", cwd=project_dir):
        return False
        
    # 2. Analyze code for errors
    print("\n2. Running 'flutter analyze'...")
    # We don't fail on analyze warnings, but we want to see them.
    # If there are errors, it usually returns non-zero.
    try:
        subprocess.run(
            "flutter analyze",
            cwd=project_dir,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        print("Analysis passed with no issues.")
    except subprocess.CalledProcessError as e:
        print("Analysis found issues:")
        print(e.stdout)
        # Check if there are actual errors or just info/warnings
        if "error •" in e.stdout:
            print("CRITICAL: Compilation errors found.")
            return False
        else:
            print("Warnings found, but build might still succeed.")

    print("\n--- Verification Complete: SUCCESS ---")
    return True

if __name__ == "__main__":
    if verify_flutter_build():
        sys.exit(0)
    else:
        sys.exit(1)
