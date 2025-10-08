import sys
import requests
import json
import os

def get_config(config_path):
    if not os.path.isfile(config_path):
        print(f"Config file '{config_path}' not found. Please run get_policy.py first or create the config file.")
        sys.exit(1)
    with open(config_path, "r") as f:
        return json.load(f)

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

def get_policy_by_path(path_list, base_url, api_key):
    url = f"{base_url}/policies"
    resp = requests.get(url, headers=get_headers(api_key))
    if resp.status_code != 200:
        print(f"Failed to list policies: {resp.text}")
        sys.exit(1)
    policies = resp.json().get("policies", [])
    current = None
    for name in path_list:
        found = None
        for p in policies:
            if p.get("name") == name and (current is None or p.get("parentID") == current.get("ID")):
                found = p
                break
        if not found:
            print(f"Policy path not found: {' -> '.join(path_list)}")
            sys.exit(1)
        current = found
    return current

def update_policy(policy_id, payload, base_url, api_key):
    url = f"{base_url}/policies/{policy_id}"
    resp = requests.post(url, headers=get_headers(api_key), data=json.dumps(payload))
    print(f"Response status: {resp.status_code}")
    print(f"Response text: {resp.text}")
    if resp.status_code == 200:
        print(f"Policy {policy_id} updated successfully.")
    else:
        print(f"Failed to update policy: {resp.text}")
        sys.exit(1)

def main():
    api_key = input("Enter your Cloud One API Key: ").strip()
    region = input("Enter your Cloud One region (e.g. de-1, us-1, eu-1): ").strip()
    source_policy_name = input("Enter the name of the source policy to copy from: ").strip()
    target_policy_name = input("Enter the name of the target policy to update: ").strip()
    
    base_url = f"https://workload.{region}.cloudone.trendmicro.com/api"
    source_policy = get_policy_by_name(source_policy_name, base_url, api_key, True)
    target_policy = get_policy_by_name(target_policy_name, base_url, api_key, False)

if __name__ == "__main__":
    main()
