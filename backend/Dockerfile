# ─────────────────────────────────────────────────────────────────────────────
# Render 单容器部署（前后端合并，省一个免费服务额度）。
# 仅在 Render 服务里使用（dockerfilePath=backend/Dockerfile，构建上下文=仓库根）。
# Docker Compose / 预构建镜像的部署方式不经过本文件（它们用 frontend/Dockerfile +
# 原 backend/Dockerfile，原版备份在 backend/Dockerfile.orig-backup）。
#
# 运行时拓扑：
#   浏览器 → Render 边缘(TLS) → Caddy :$PORT(10000) ─ 静态 frontend/dist
#                                            └ /api|/oauth|/ws|/carddav → node :3000
# 后端 3000 只绑容器内部，Render 不路由它；对外只有 10000 一个口。
# 所需环境变量与原部署一致（DATABASE_URL/SESSION_SECRET/ENCRYPTION_KEY/APP_URL…），
# 另建议在 Render 上设 TRUST_PROXY_HOPS=2（浏览器→Render 边缘→Caddy 两层代理）。
# ─────────────────────────────────────────────────────────────────────────────

# ── 前端构建（与 frontend/Dockerfile 的 builder 阶段一致）──
FROM --platform=$BUILDPLATFORM node:22-alpine AS fe-builder

WORKDIR /app

COPY frontend/package*.json ./
# electron 只是桌面打包用的 devDependency，跳过 ~100MB 二进制下载。
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1
RUN npm ci

COPY frontend/ ./

ARG VITE_BUILD_SHA
ARG VITE_EMAIL_DIV_RENDER
ENV VITE_BUILD_SHA=${VITE_BUILD_SHA:-dev}
ENV VITE_EMAIL_DIV_RENDER=${VITE_EMAIL_DIV_RENDER:-false}
RUN npm run build

# ── 后端依赖（与原 backend/Dockerfile 的 deps 阶段一致）──
FROM node:22-alpine AS deps

WORKDIR /app

COPY backend/package.json backend/package-lock.json ./
# sharp 的预编译库是原生代码：按目标平台安装。
ARG TARGETARCH
RUN npm ci --omit=dev --os=linux --libc=musl --cpu="$([ "$TARGETARCH" = arm64 ] && echo arm64 || echo x64)"

# ── Caddy 静态二进制来源 ──
FROM caddy:2-alpine AS caddy

# ── 运行时 ──
FROM node:22-alpine AS runtime

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY backend/package.json ./package.json
COPY backend/src ./src
COPY backend/migrations ./migrations

# 前端产物与 Caddy：上游 Caddyfile 原样复用，仅新增 sites-merge.caddy 监听 $PORT。
COPY --from=fe-builder /app/dist /srv
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY frontend/caddy/Caddyfile /etc/caddy/Caddyfile
COPY backend/render/sites-merge.caddy /etc/caddy/sites-merge.caddy
COPY backend/render/start.sh /usr/local/bin/mailflow-render-start

RUN APP_VERSION_VALUE="$(node -p "require('./package.json').version")"; \
    APP_VERSION_VALUE="$(printf '%s' "$APP_VERSION_VALUE" | sed 's/^v[.]//' | sed 's/^v//')"; \
    printf '{"version":"%s"}\n' "$APP_VERSION_VALUE" > ./build-meta.json && \
    mkdir -p /var/cache/mailflow/images && \
    chmod +x /usr/local/bin/mailflow-render-start && \
    chown -R node:node /app /srv /var/cache/mailflow

USER node

EXPOSE 10000

CMD ["/usr/local/bin/mailflow-render-start"]
