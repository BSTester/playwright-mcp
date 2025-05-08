#!/bin/bash
mkdir -p /home/${USERNAME}/.vnc
x11vnc -storepasswd $VNC_PASSWORD /home/${USERNAME}/.vnc/passwd
Xvfb :99 -screen 0 1920x1080x24 -ac 2>/dev/null &
sleep 1
export DISPLAY=:99
x11vnc -display :99 -forever -shared -rfbauth /home/${USERNAME}/.vnc/passwd -rfbport 5900 -noxdamage -ncache 10 -ncache_cr 2>/dev/null &
sleep 1
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 2>/dev/null &
sleep 1
export PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
node cli.js "$@"
tail -f /dev/null 