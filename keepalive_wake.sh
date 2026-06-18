#!/bin/bash
# Wake word listener keepalive — safe restart
LISTENER_PY="/home/radxa/stackchan-esphome/xvf3800/wake_word_listener.py"
LOG="/tmp/wake_word_listener.log"

# Kill existing instances safely (pgrep first, then kill)
PIDS=$(pgrep -f "wake_word_listener.py" 2>/dev/null)
if [ -n "$PIDS" ]; then
    echo "$PIDS" | xargs -r kill 2>/dev/null
    sleep 0.8
fi

# Free device
fuser -k /dev/snd/pcmC1D0c 2>/dev/null
sleep 0.3

# Start
nohup python3 "$LISTENER_PY" > "$LOG" 2>&1 &
echo "Started PID $!"
