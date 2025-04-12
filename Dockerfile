FROM mcr.microsoft.com/playwright:v1.51.1-noble

# Definir como usuário root para instalações
USER root
WORKDIR /app
# Install system dependencies for browsers
RUN apt-get update && apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libxcursor1 \
    libgtk-3-0 \
    fonts-noto-color-emoji \
    fonts-freefont-ttf \
    libfreetype6 \
    libharfbuzz0b \
    xvfb \
    curl \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*
# Copiar arquivos de configuração
COPY package*.json tsconfig.json ./

# Instalar a versão específica do Playwright mencionada no package.json
RUN npm ci

# Instalar explicitamente os navegadores necessários
RUN npx playwright install chrome
RUN npx playwright install chromium --with-deps 
RUN npx playwright install-deps chromium
RUN npx playwright install firefox

# Copiar código-fonte
COPY . .

# Compilar TypeScript
RUN npm run build

# Limpar dependências de desenvolvimento
RUN npm prune --production

# Adicionar permissões para os navegadores
RUN chmod -R 755 /ms-playwright/

# Configurar usuário não-root para segurança
RUN groupadd -r mcpuser && \
    useradd -r -g mcpuser -G audio,video mcpuser && \
    mkdir -p /home/mcpuser/Downloads && \
    chown -R mcpuser:mcpuser /home/mcpuser && \
    chown -R mcpuser:mcpuser /app

# Configurar variáveis de ambiente
ENV NODE_ENV=production
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV DOCKER_CONTAINER=true

# Entrypoint para o servidor MCP
ENTRYPOINT ["node", "cli.js"]

# Argumentos padrão (headless por padrão)
CMD ["--headless"]
