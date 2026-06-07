#!/usr/bin/env python3
"""Generate media-hub-safety-net.sh - uses chr() to avoid bash quoting hell"""
import os

BSD = chr(36)  # bash dollar sign
BBT = chr(96)  # bash backtick
BSQ = chr(39)  # bash single quote

def line(s):
    return s + '\n'

# Command substitution function
def cmd_subst(cmd):
    return BSD + '(' + cmd + ')'

def backtick(cmd):
    return BBT + cmd + BBT

out = []

out.append(line('#!/bin/bash'))
out.append(line('# Media Hub Safety Net - weekly deep checks'))
out.append(line('set -euo pipefail'))
out.append(line(''))
out.append(line(f'ZURG_CONFIG="{BSD}HOME/radxa/zurg/config.yml"'))
out.append(line(f'ZURG_BIN="{BSD}HOME/radxa/zurg/zurg"'))
out.append(line(f'PLEX_URL="http://192.168.1.145:32400"'))
out.append(line(f'PLEX_PREFS="{BSD}HOME/radxa/plex/config/Library/Application Support/Plex Media Server/Preferences.xml"'))
out.append(line(f'RD_API="https://api.real-debrid.com/rest/1.0"'))
out.append(line(f'TOKEN_EXTRACTER={BSD}HOME/radxa/.hermes/profiles/home/scripts/plex-token-extract.py'))
out.append(line(''))

# Token loading
rd_token_cmd = f'python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))[{BSQ}token{BSQ}])" "{BSD}ZURG_CONFIG" 2>/dev/null'
out.append(line(f'RD_TOKEN={cmd_subst(rd_token_cmd)}'))
out.append(line(f'PLEX_TOKEN={cmd_subst(f"python3 {BSD}TOKEN_EXTRACTER {BSD}PLEX_PREFS 2>/dev/null")}'))
out.append(line(''))
out.append(line('if [ -z "$RD_TOKEN" ] || [ -z "$PLEX_TOKEN" ]; then'))
out.append(line('  echo "CRITICAL: Cannot load tokens"'))
out.append(line('  exit 1'))
out.append(line('fi'))
out.append(line(''))
out.append(line(f'ALERT_FILE={cmd_subst("mktemp")}'))
out.append(line('trap "rm -f $ALERT_FILE" EXIT'))
out.append(line(''))
out.append(line('# 1. RD API health'))
out.append(line('echo "-> RD API health ..."'))
out.append(line(f'AUTH_HEADER="{cmd_subst(f\'printf "Authorization: Bearer %s" "{BSD}RD_TOKEN"\')}"'))
out.append(line(f'RD_RESP={cmd_subst(f\'curl -sf --connect-timeout 10 -H "{BSD}AUTH_HEADER" "{BSD}RD_API/user" 2>/dev/null\')}'))
out.append(line(''))

script_content = '\n'.join(out)

# Write it
with open('/home/radxa/.hermes/profiles/home/scripts/write_safety.py', 'w') as f:
    f.write(script_content)
