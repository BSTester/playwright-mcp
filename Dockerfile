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
WORKDIR /app
RUN mkdir -p /data/browser-data && chmod 777 /data/browser-data

# 安装 playwright-mcp 和所有浏览器
RUN npm install @playwright/mcp@latest \
    && npx playwright install \
    && npx playwright install-deps

# 创建启动脚本
RUN echo '#!/bin/bash\n\
# 创建 VNC 密码文件\n\
mkdir -p /root/.vnc\n\
x11vnc -storepasswd $VNC_PASSWORD /root/.vnc/passwd\n\
\n\
# 启动虚拟显示器\n\
Xvfb :99 -screen 0 1280x720x24 -ac &\n\
sleep 2\n\
\n\
# 设置显示器\n\
export DISPLAY=:99\n\
\n\
# 启动 VNC 服务\n\
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5900 -noxdamage &\n\
sleep 1\n\
\n\
# 启动 noVNC 代理\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 &\n\
sleep 1\n\
\n\
# 打印启动命令\n\
echo "Starting Playwright MCP with arguments: $@"\n\
\n\
# 启动 MCP 服务，直接传递所有命令行参数\n\
npx @playwright/mcp@latest $@ &\n\
MCP_PID=$!\n\
\n\
# 等待 MCP 进程\n\
wait $MCP_PID || {\n\
  echo "Playwright MCP exited with status $?"\n\
  # 即使 MCP 进程结束，也保持容器运行\n\
  tail -f /dev/null\n\
}\n\
\n\
# 保持容器运行\n\
tail -f /dev/null\n\
' > /start-vnc.sh \
    && chmod +x /start-vnc.sh

# 设置环境变量
ENV DISPLAY=:99

# 创建数据卷
VOLUME ["/data/browser-data"]

# 暴露端口
EXPOSE 6080 8931

# 设置入口点
ENTRYPOINT ["/start-vnc.sh"]
