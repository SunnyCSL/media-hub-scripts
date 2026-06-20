#!/usr/bin/env python3
"""Update HA token cache file for robi_voice. Silent on success, loud on failure."""
import json, urllib.request, urllib.parse, sys

try:
    with open('/home/radxa/homeassistant/.storage/auth') as f:
        auth = json.load(f)

    tok = None
    for entry in auth['data'].get('refresh_tokens', []):
        if isinstance(entry, dict) and entry.get('client_name') == 'Robi':
            tok = entry.get('token', '')
            break
    if not tok:
        sys.exit(0)  # No Robi token yet = not an error, just nothing to do
    
    data = urllib.parse.urlencode({'grant_type': 'refresh_token', 'refresh_token': tok}).encode()
    req = urllib.request.Request('http://localhost:8123/auth/token', data=data,
        headers={'Content-Type': 'application/x-www-form-urlencoded'})
    with urllib.request.urlopen(req, timeout=10) as resp:
        token = json.loads(resp.read()).get('access_token', '')
    
    with open('/home/radxa/stackchan-esphome/xvf3800/ha_token.cache', 'w') as f:
        f.write(token)

except Exception as e:
    print(f"❌ HA token refresh FAILED: {e}", flush=True)
    sys.exit(1)
