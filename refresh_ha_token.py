#!/usr/bin/env python3
"""Update HA token cache file for robi_voice. Silent on success, loud on failure."""
import json, urllib.request, urllib.parse, sys, subprocess

try:
    # HA auth file is root-owned (0600), need sudo
    result = subprocess.run(
        ["sudo", "cat", "/home/radxa/homeassistant/.storage/auth"],
        capture_output=True, text=True, timeout=10
    )
    if result.returncode != 0:
        raise PermissionError(f"sudo cat failed: {result.stderr.strip()}")
    
    auth = json.loads(result.stdout)

    tok = None
    for entry in auth['data'].get('refresh_tokens', []):
        if isinstance(entry, dict) and entry.get('client_name') == 'Robi':
            tok = entry.get('token', '')
            break
    if not tok:
        print("⚠️ No Robi token found in HA auth (first-time setup?)", flush=True)
        sys.exit(0)  # Not an error, just nothing to do
    
    data = urllib.parse.urlencode({'grant_type': 'refresh_token', 'refresh_token': tok}).encode()
    req = urllib.request.Request('http://localhost:8123/auth/token', data=data,
        headers={'Content-Type': 'application/x-www-form-urlencoded'})
    with urllib.request.urlopen(req, timeout=10) as resp:
        token = json.loads(resp.read()).get('access_token', '')
    if not token:
        raise ValueError("Empty access_token in response")
    
    with open('/home/radxa/stackchan-esphome/xvf3800/ha_token.cache', 'w') as f:
        f.write(token)

except Exception as e:
    print(f"❌ HA token refresh FAILED: {e}", flush=True)
    sys.exit(1)
