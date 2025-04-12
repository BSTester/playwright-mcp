# 使用 Ubuntu 作为基础镜像
FROM ubuntu:22.04

# 避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置默认 VNC 密码
ENV VNC_PASSWORD=vncpassword

# 安装基础工具和依赖
RUN apt-get update && apt-get install -y \
    wget \
    git \
    curl \
    python3 \
    python3-pip \
    net-tools \
    vim \
    gnupg \
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
    ca-certificates \
    # WebKit 依赖
    libwoff1 \
    libopus0 \
    libwebp7 \
    libwebpdemux2 \
    libenchant-2-2 \
    libgudev-1.0-0 \
    libsecret-1-0 \
    libhyphen0 \
    libgdk-pixbuf-2.0-0 \
    libegl1 \
    libnotify4 \
    libxslt1.1 \
    libevent-2.1-7 \
    libgles2 \
    libvpx7 \
    libxcomposite1 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libepoxy0 \
    libgtk-3-0 \
    libharfbuzz-icu0 \
    # Firefox 依赖
    libdbus-glib-1-2 \
    libxt6 \
    && rm -rf /var/lib/apt/lists/*

# 安装 NVM 和 Node.js
ENV NVM_DIR /root/.nvm
ENV NODE_VERSION 18.19.0

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# 添加 node 和 npm 到 PATH
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# 验证安装
RUN node --version && npm --version

# 安装 Playwright 和所有浏览器
RUN npm init -y \
    && npm install playwright@latest \
    && npx playwright install \
    && npx playwright install-deps

# 安装 playwright-mcp
RUN npm install @playwright/mcp@latest

# 安装 noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# 创建工作目录
WORKDIR /app

# 创建启动脚本
RUN echo '#!/bin/bash\n\
# 加载 NVM\n\
export NVM_DIR="/root/.nvm"\n\
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"\n\
\n\
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
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# 暴露端口
EXPOSE 6080 8931

# 设置入口点
ENTRYPOINT ["/start-vnc.sh"]
