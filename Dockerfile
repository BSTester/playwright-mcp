# 使用 Playwright 官方最新版本的 Docker 镜像
FROM mcr.microsoft.com/playwright:latest

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置默认 VNC 密码
ENV VNC_PASSWORD=vncpassword

# 安装 VNC 和 noVNC 相关依赖
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    xauth \
    net-tools \
    procps \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# 安装 noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# 创建工作目录和数据目录
WORKDIR /home/pwuser
RUN mkdir -p /data/browser-data && chmod 777 /data/browser-data

# 获取当前安装的 Playwright 版本并安装所有浏览器
RUN PLAYWRIGHT_VERSION=$(npm list -g playwright | grep playwright | awk '{print $2}' | cut -d@ -f2 || echo "latest") \
    && echo "Installing browsers for Playwright version: $PLAYWRIGHT_VERSION" \
    && npx playwright@${PLAYWRIGHT_VERSION} install --with-deps

# 安装 playwright-mcp
RUN npm install @playwright/mcp@latest

# 创建启动脚本
RUN echo '#!/bin/bash\n\
# 获取当前 Playwright 版本\n\
PLAYWRIGHT_VERSION=$(npm list -g playwright | grep playwright | awk "{print \$2}" | cut -d@ -f2 || echo "latest")\n\
echo "Using Playwright version: $PLAYWRIGHT_VERSION"\n\
\n\
# 创建 VNC 密码文件\n\
mkdir -p /home/pwuser/.vnc\n\
x11vnc -storepasswd $VNC_PASSWORD /home/pwuser/.vnc/passwd\n\
\n\
# 启动虚拟显示器\n\
Xvfb :99 -screen 0 1280x720x24 -ac &\n\
XVFB_PID=$!\n\
sleep 2\n\
\n\
# 设置显示器\n\
export DISPLAY=:99\n\
\n\
# 启动 VNC 服务\n\
x11vnc -display :99 -forever -shared -rfbauth /home/pwuser/.vnc/passwd -rfbport 5900 -noxdamage &\n\
VNC_PID=$!\n\
sleep 1\n\
\n\
# 启动 noVNC 代理\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 &\n\
NOVNC_PID=$!\n\
sleep 1\n\
\n\
# 启动 Playwright 服务器\n\
npx -y playwright@$PLAYWRIGHT_VERSION run-server --port 3000 --host 0.0.0.0 &\n\
PLAYWRIGHT_SERVER_PID=$!\n\
echo "Playwright Server started on port 3000 (PID: $PLAYWRIGHT_SERVER_PID)"\n\
\n\
# 提取 MCP 端口参数\n\
MCP_PORT=8931\n\
if [[ "$*" == *"--port"* ]]; then\n\
  PORT_INDEX=$(($(echo "$*" | tr " " "\n" | grep -n -- "--port" | cut -d: -f1) + 1))\n\
  MCP_PORT=$(echo "$*" | tr " " "\n" | sed -n "${PORT_INDEX}p")\n\
fi\n\
\n\
# 启动 MCP 服务\n\
echo "Starting Playwright MCP with arguments: $@"\n\
npx @playwright/mcp@latest $@ &\n\
MCP_PID=$!\n\
\n\
echo "==================================="\n\
echo "All services started:"\n\
echo "- noVNC: http://localhost:6080"\n\
echo "- Playwright Server: http://localhost:3000"\n\
echo "- Playwright MCP: http://localhost:$MCP_PORT/sse"\n\
echo "==================================="\n\
\n\
# 监控服务进程\n\
while true; do\n\
  # 检查服务状态\n\
  if ! ps -p $XVFB_PID > /dev/null; then\n\
    echo "Xvfb exited, restarting..."\n\
    Xvfb :99 -screen 0 1280x720x24 -ac &\n\
    XVFB_PID=$!\n\
  fi\n\
  \n\
  if ! ps -p $VNC_PID > /dev/null; then\n\
    echo "VNC server exited, restarting..."\n\
    x11vnc -display :99 -forever -shared -rfbauth /home/pwuser/.vnc/passwd -rfbport 5900 -noxdamage &\n\
    VNC_PID=$!\n\
  fi\n\
  \n\
  if ! ps -p $NOVNC_PID > /dev/null; then\n\
    echo "noVNC proxy exited, restarting..."\n\
    /opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 &\n\
    NOVNC_PID=$!\n\
  fi\n\
  \n\
  if ! ps -p $PLAYWRIGHT_SERVER_PID > /dev/null; then\n\
    echo "Playwright Server exited, restarting..."\n\
    npx -y playwright@$PLAYWRIGHT_VERSION run-server --port 3000 --host 0.0.0.0 &\n\
    PLAYWRIGHT_SERVER_PID=$!\n\
  fi\n\
  \n\
  if ! ps -p $MCP_PID > /dev/null; then\n\
    echo "MCP service exited, restarting..."\n\
    npx @playwright/mcp@latest $@ &\n\
    MCP_PID=$!\n\
  fi\n\
  \n\
  echo "[$(date)] Services status: All services running"\n\
  sleep 30\n\
done\n\
' > /home/pwuser/start-services.sh \
    && chmod +x /home/pwuser/start-services.sh

# 设置环境变量
ENV DISPLAY=:99

# 创建数据卷
VOLUME ["/data/browser-data"]

# 暴露端口
EXPOSE 6080 8931 3000

# 设置入口点
ENTRYPOINT ["/home/pwuser/start-services.sh"]
