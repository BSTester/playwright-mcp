# 使用 Node.js 官方镜像作为基础
FROM node:18-bullseye

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置默认 VNC 密码
ENV VNC_PASSWORD=vncpassword

# 安装 X11 和 VNC 相关依赖
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    x11-xkb-utils \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    xfonts-cyrillic \
    x11-apps \
    xauth \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-thai-tlwg \
    fonts-kacst \
    fonts-symbola \
    fonts-noto-color-emoji \
    fonts-freefont-ttf \
    && rm -rf /var/lib/apt/lists/*

# 安装 noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# 创建工作目录
WORKDIR /app

# 安装 Playwright
RUN npm init -y \
    && npm install playwright@latest \
    && npm install @playwright/mcp@latest

# 安装浏览器（只安装 Chromium 以减少镜像大小）
RUN npx playwright install chromium \
    && npx playwright install-deps chromium

# 创建启动脚本
RUN echo '#!/bin/bash\n\
# 创建 VNC 密码文件\n\
mkdir -p /root/.vnc\n\
x11vnc -storepasswd $VNC_PASSWORD /root/.vnc/passwd\n\
\n\
# 启动虚拟显示器\n\
Xvfb :99 -screen 0 1280x720x24 &\n\
sleep 1\n\
\n\
# 设置显示器\n\
export DISPLAY=:99\n\
\n\
# 启动 VNC 服务（使用密码文件）\n\
x11vnc -display :99 -forever -shared -rfbauth /root/.vnc/passwd &\n\
\n\
# 启动 noVNC\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080 &\n\
\n\
# 启动 MCP 服务，使用传入的参数\n\
npx @playwright/mcp@latest $@ &\n\
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
