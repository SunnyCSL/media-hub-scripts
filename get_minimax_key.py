#!/usr/bin/env python3
env = "/home/radxa/.hermes/profiles/home/.env"
for line in open(env):
    line = line.strip()
    if line.startswith("MINIMAX_API_KEY=***        k = line.split("=", 1)[1].strip()
        k = k.strip("'").strip('"')
        print(k)
        break
