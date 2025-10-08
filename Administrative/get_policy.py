import sys
import requests
import json

def get_headers(api_key):
    return {
        "api-secret-key": api_key,
        "api-version": "v1",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

def get_policy_by_name(policy_name, base_url, api_key):
    url = f"{base_url}/policies"
    resp = requests.get(url, headers=get_headers(api_key))
    if resp.status_code != 200:
        print(f"Failed to list policies: {resp.text}")
        sys.exit(1)
    policies = resp.json().get("policies", [])
    for p in policies:
        if p.get("name") == policy_name:
            return p
    print(f"Policy '{policy_name}' not found.")
    sys.exit(1)

def get_policy_details(policy_id, base_url, api_key):
    url = f"{base_url}/policies/{policy_id}"
    resp = requests.get(url, headers=get_headers(api_key))
    if resp.status_code != 200:
        print(f"Failed to get policy details: {resp.text}")
        sys.exit(1)
    return resp.json()

def main():
    api_key = input("Enter your Cloud One API Key: ").strip()
    region = input("Enter your Cloud One region (e.g. de-1, us-1, eu-1): ").strip()
    policy_name = input("Which Policy you want to retrieve: ").strip()
    base_url = f"https://workload.{region}.cloudone.trendmicro.com/api"
    policy = get_policy_by_name(policy_name, base_url, api_key)
    policy_id = policy.get("ID")
    details = get_policy_details(policy_id, base_url, api_key)
    print(json.dumps(details, indent=2))

if __name__ == "__main__":
    main()
