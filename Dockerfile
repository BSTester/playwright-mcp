# 使用指定的 Playwright Docker 镜像版本
FROM mcr.microsoft.com/playwright:v1.51.0-noble

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置默认 VNC 密码
ENV VNC_PASSWORD=vncpassword

# 安装 VNC 和 noVNC 相关依赖，包括 python3-numpy
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    xauth \
    net-tools \
    procps \
    iputils-ping \
    python3-numpy \
    && rm -rf /var/lib/apt/lists/*

# 安装 noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# 创建工作目录和数据目录
WORKDIR /home/pwuser
RUN mkdir -p /data/browser-data && chmod 777 /data/browser-data

# 确保所有浏览器都已安装并验证
RUN npx playwright install
RUN PLAYWRIGHT_BROWSERS_PATH=/ms-playwright npx playwright@1.51.0 install --with-deps && \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright npx playwright@1.51.0 install-deps && \
    ls -la /ms-playwright && \
    find /ms-playwright -type f -name chrome -o -name firefox -o -name webkit | grep -v node_modules

# 安装 playwright-mcp
RUN npm install @playwright/mcp@latest

# 创建启动脚本
RUN echo '#!/bin/bash\n\
# 列出所有已安装的浏览器\n\
echo "Listing installed browsers:"\n\
find /ms-playwright -type f -name chrome -o -name firefox -o -name webkit | grep -v node_modules\n\
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
PLAYWRIGHT_BROWSERS_PATH=/ms-playwright npx -y playwright@1.51.0 run-server --port 3000 --host 0.0.0.0 &\n\
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
# 配置 MCP 环境变量\n\
export PLAYWRIGHT_BROWSERS_PATH=/ms-playwright\n\
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
# 保持容器运行\n\
tail -f /dev/null\n\
' > /home/pwuser/start-services.sh \
    && chmod +x /home/pwuser/start-services.sh

# 设置环境变量
ENV DISPLAY=:99
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# 创建数据卷
VOLUME ["/data/browser-data"]

# 暴露端口
EXPOSE 6080 8931 3000

# 设置入口点
ENTRYPOINT ["/home/pwuser/start-services.sh"]
