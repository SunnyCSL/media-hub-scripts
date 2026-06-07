import re, sys
with open(sys.argv[1]) as f:
    m = re.search(r'PlexOnlineToken="([^"]+)"', f.read())
    if m:
        print(m.group(1))
