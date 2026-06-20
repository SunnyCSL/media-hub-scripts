#!/usr/bin/env python3
"""Robi System Watchdog — health check + auto-restart for all services.
Silent on success, reports only on failures/actions taken."""
import subprocess, sys, json, os, time, socket, urllib.request

SERVICES = {
    "sticks3-voice": {"type": "systemd", "port_check": 0, "mic_check": False},
}

FAILURES = []

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def is_active(name):
    r = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True)
    return r.stdout.strip() == "active"

def get_main_pid(name):
    r = subprocess.run(["systemctl", "show", "-p", "MainPID", name], capture_output=True, text=True)
    if r.returncode == 0:
        pid = r.stdout.strip().replace("MainPID=", "")
        return int(pid) if pid.isdigit() and int(pid) > 1 else None
    return None

def restart(name):
    log(f"🔄 Restarting {name}...")
    # If service is still alive, stop it cleanly first
    if is_active(name):
        subprocess.run(["systemctl", "stop", name], capture_output=True, timeout=10)
        time.sleep(1)
    # Start fresh (handles already-dead services without hanging)
    subprocess.run(["systemctl", "start", name], capture_output=True, timeout=15)
    time.sleep(2)
    if is_active(name):
        log(f"✅ {name} restarted")
        FAILURES.append(f"🔄 {name} was dead/hung, auto-restarted")
    else:
        FAILURES.append(f"❌ {name}: restart FAILED")

def check_port(port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(3)
        r = s.connect_ex(("127.0.0.1", port))
        s.close()
        return r == 0
    except:
        return False

def check_mic(service_pid):
    """Check if mic is held by the service's own arecord (normal)."""
    r = subprocess.run(
        ["timeout", "2", "arecord", "-D", "hw:1,0", "-d", "1", "-f", "S16_LE", "-r", "16000", "-c", "1", "/dev/null"],
        capture_output=True, text=True, timeout=5
    )
    if r.returncode == 0:
        # Mic is free — if service is running, its arecord died
        return "free_unexpected" if service_pid else "free_ok"
    
    err = r.stderr.strip()[:100]
    if "Device or resource busy" in err:
        # Mic is busy — check if it's our arecord
        if service_pid:
            ps = subprocess.run(["ps", "--ppid", str(service_pid), "-o", "comm="], capture_output=True, text=True)
            if "arecord" in ps.stdout:
                return "ok"  # Our arecord has it — normal
        return "stale"  # Someone else has it — stale
    return "error"

# ── Check each service ──────────────────────────────────────
for name, cfg in SERVICES.items():
    pid = get_main_pid(name)
    alive = pid is not None
    
    if not alive:
        restart(name)
        continue
    
    # Port check
    if cfg["port_check"] and not check_port(cfg["port_check"]):
        FAILURES.append(f"⚠️ {name}: port {cfg['port_check']} not responding — restarting")
        restart(name)
        continue
    
    # Mic check (robi-voice only)
    if cfg["mic_check"]:
        mic_status = check_mic(pid)
        if mic_status == "free_unexpected":
            FAILURES.append(f"🔊 {name}: mic free but service running — arecord died, restarting")
            restart(name)
        elif mic_status == "stale":
            FAILURES.append(f"🔊 {name}: stale arecord holding mic — killing")
            subprocess.run(["pkill", "-f", "arecord.*hw:1,0"], capture_output=True, timeout=5)
            restart(name)
        elif mic_status == "error":
            FAILURES.append(f"⚠️ {name}: mic check error, will retry")

# ── HA token health ─────────────────────────────────────────
token_file = "/home/radxa/stackchan-esphome/xvf3800/ha_token.cache"
ha_ok = False

if os.path.exists(token_file):
    tok = open(token_file).read().strip()
    if len(tok) < 20:
        FAILURES.append("⚠️ HA token cache too short, will auto-refresh")
    else:
        # Verify token works — call HA API
        try:
            req = urllib.request.Request(
                "http://localhost:8123/api/config",
                headers={"Authorization": f"Bearer {tok}"}
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                ha_ok = resp.status == 200
        except Exception:
            pass  # Token might be stale
        
        if not ha_ok:
            log("🔑 HA token stale — auto-refreshing")
            r = subprocess.run(
                ["python3", "/home/radxa/.hermes/profiles/home/scripts/refresh_ha_token.py"],
                capture_output=True, text=True, timeout=15
            )
            if r.returncode == 0:
                log("✅ HA token refreshed")
                FAILURES.append("🔄 HA token was stale, auto-refreshed")
            else:
                FAILURES.append(f"❌ HA token refresh FAILED (auto-heal attempted): {r.stdout.strip()}")
else:
    FAILURES.append("❌ HA token cache missing")

# ── Report (only on failures) ───────────────────────────────
if FAILURES:
    print("=" * 40)
    for f in FAILURES:
        print(f)
    sys.exit(1)
