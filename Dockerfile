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

# 创建工作目录
WORKDIR /app

# 安装 playwright-mcp 和所有浏览器
RUN npm install @playwright/mcp@latest \
    && npx playwright install \
    && npx playwright install-deps

# 列出安装的浏览器以便验证
RUN find /ms-playwright -type f -name "*chrome*" | grep -v node_modules

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
# 列出可用的浏览器路径\n\
echo "Available browsers:"\n\
find /ms-playwright -type f -name "chrome" -o -name "chrome.exe" -o -name "firefox" -o -name "msedge" | grep -v node_modules\n\
\n\
# 启动 MCP 服务，使用传入的参数\n\
# 默认使用 chromium 浏览器，除非在命令行参数中指定其他浏览器\n\
if [[ "$*" != *"--browser"* ]]; then\n\
    ARGS="--browser chromium $@"\n\
else\n\
    ARGS="$@"\n\
fi\n\
\n\
echo "Starting MCP with arguments: $ARGS"\n\
npx @playwright/mcp@latest $ARGS &\n\
\n\
# 保持容器运行\n\
tail -f /dev/null\n\
' > /start-vnc.sh \
    && chmod +x /start-vnc.sh

# 设置环境变量
ENV DISPLAY=:99

# 暴露端口
EXPOSE 6080 8931

# 设置入口点
ENTRYPOINT ["/start-vnc.sh"]
