# 使用 Playwright 官方最新版本的 Docker 镜像
FROM mcr.microsoft.com/playwright:latest

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置默认 VNC 密码
ENV VNC_PASSWORD=vncpassword

# 安装 VNC 和 noVNC 相关依赖，添加调试工具
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    xauth \
    net-tools \
    procps \
    iputils-ping \
    telnet \
    && rm -rf /var/lib/apt/lists/*

# 安装 noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# 创建工作目录
WORKDIR /app

# 安装 playwright-mcp
RUN npm install @playwright/mcp@latest

# 创建启动脚本，添加更多调试输出
RUN echo '#!/bin/bash\n\
set -x\n\
\n\
# 创建 VNC 密码文件\n\
mkdir -p /root/.vnc\n\
x11vnc -storepasswd $VNC_PASSWORD /root/.vnc/passwd\n\
\n\
# 启动虚拟显示器，增加日志输出\n\
Xvfb :99 -screen 0 1280x720x24 -ac &\n\
XVFB_PID=$!\n\
sleep 2\n\
\n\
# 检查 Xvfb 是否运行\n\
if ! ps -p $XVFB_PID > /dev/null; then\n\
    echo "Xvfb failed to start!"\n\
    exit 1\n\
fi\n\
\n\
# 设置显示器并确认环境\n\
export DISPLAY=:99\n\
echo "DISPLAY set to $DISPLAY"\n\
\n\
# 确保 /tmp/.X11-unix 目录存在且有正确权限\n\
mkdir -p /tmp/.X11-unix\n\
chmod 1777 /tmp/.X11-unix\n\
\n\
# 启动简单的窗口管理器以显示窗口\n\
export DISPLAY=:99 && xterm -e "echo Window Manager Started; sleep 5" &\n\
\n\
# 启动 VNC 服务，使用更多参数以便调试\n\
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5900 -noxdamage -verbose &\n\
VNC_PID=$!\n\
sleep 2\n\
\n\
# 检查 x11vnc 是否运行\n\
if ! ps -p $VNC_PID > /dev/null; then\n\
    echo "x11vnc failed to start!"\n\
    exit 1\n\
fi\n\
\n\
# 检查 VNC 端口是否打开\n\
if ! netstat -tuln | grep -q ":5900"; then\n\
    echo "VNC port 5900 is not open!"\n\
    netstat -tuln\n\
    exit 1\n\
fi\n\
\n\
# 启动 noVNC 代理，增加更多的调试选项\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 --verbose &\n\
NOVNC_PID=$!\n\
sleep 2\n\
\n\
# 检查 noVNC 是否运行\n\
if ! ps -p $NOVNC_PID > /dev/null; then\n\
    echo "noVNC proxy failed to start!"\n\
    exit 1\n\
fi\n\
\n\
# 检查 noVNC 端口是否打开\n\
if ! netstat -tuln | grep -q ":6080"; then\n\
    echo "noVNC port 6080 is not open!"\n\
    netstat -tuln\n\
    exit 1\n\
fi\n\
\n\
echo "VNC and noVNC setup completed successfully"\n\
\n\
# 启动 MCP 服务，使用传入的参数\n\
npx @playwright/mcp@latest $@ &\n\
MCP_PID=$!\n\
\n\
echo "All services started. Logs follow:"\n\
\n\
# 保持容器运行，同时显示各服务状态\n\
while true; do\n\
    echo "===== Service Status =====" \n\
    echo "Xvfb: $(ps -p $XVFB_PID -o comm= || echo "NOT RUNNING")" \n\
    echo "x11vnc: $(ps -p $VNC_PID -o comm= || echo "NOT RUNNING")" \n\
    echo "noVNC: $(ps -p $NOVNC_PID -o comm= || echo "NOT RUNNING")" \n\
    echo "MCP: $(ps -p $MCP_PID -o comm= || echo "NOT RUNNING")" \n\
    echo "=========================" \n\
    sleep 30\n\
done\n\
' > /start-vnc.sh \
    && chmod +x /start-vnc.sh

# 设置环境变量
ENV DISPLAY=:99

# 暴露端口
EXPOSE 5900 6080 8931

# 设置入口点
ENTRYPOINT ["/start-vnc.sh"]
