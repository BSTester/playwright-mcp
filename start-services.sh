#!/bin/bash
mkdir -p /home/${USERNAME}/.vnc
x11vnc -storepasswd $VNC_PASSWORD /home/${USERNAME}/.vnc/passwd
Xvfb :99 -screen 0 1920x1080x24 -ac 2>/dev/null &
sleep 1
export DISPLAY=:99

# 启动 xfce4 桌面环境, 并将输出重定向到 /dev/null
startxfce4 > /dev/null 2>&1 &
sleep 2  # 等待桌面启动

# 启动 VNC 和 noVNC 服务
x11vnc -display :99 -forever -shared -rfbauth /home/${USERNAME}/.vnc/passwd -rfbport 5900 -noxdamage -ncache 10 -ncache_cr > /dev/null 2>&1 &
sleep 1
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 > /dev/null 2>&1 &
sleep 1

# 启动 Playwright MCP 服务
export PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
echo "Starting Playwright MCP service..." # Added for clarity
node cli.js "$@" > /tmp/mcp_service.log 2>&1 &

echo "All services should be starting. MCP logs in /tmp/mcp_service.log. VNC on port 5900, noVNC on 6080."
# 保持容器运行
tail -f /dev/null 