#!/bin/sh
# 单容器跑 MailFlow 前后端（Render 免费额度合并部署）：
#   node 后端 → 127.0.0.1:3000（仅供本机 Caddy 反代，Render 不会路由它）
#   caddy     → $PORT（Render 注入，默认 10000），提供前端静态文件并反代后端路径
# 任一进程退出 → 整个容器退出，让 Render 重启并计入部署失败，而不是半死不活。
set -u

BACKEND_PORT=${BACKEND_PORT:-3000}
RENDER_PORT=${PORT:-10000}
export RENDER_PORT
export MAILFLOW_BACKEND=127.0.0.1:$BACKEND_PORT
export MAILFLOW_SITES=merge

PORT=$BACKEND_PORT node src/index.js &
NODE_PID=$!

XDG_DATA_HOME=${XDG_DATA_HOME:-/tmp/caddy-data} caddy run \
	--config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!

echo "mailflow-merge: backend=$NODE_PID caddy=$CADDY_PID (public :$RENDER_PORT -> backend :$BACKEND_PORT)"

while :; do
	if ! kill -0 "$NODE_PID" 2>/dev/null; then
		echo "mailflow-merge: backend exited — stopping container"
		kill "$CADDY_PID" 2>/dev/null; exit 1
	fi
	if ! kill -0 "$CADDY_PID" 2>/dev/null; then
		echo "mailflow-merge: caddy exited — stopping container"
		kill "$NODE_PID" 2>/dev/null; exit 1
	fi
	sleep 1
done
