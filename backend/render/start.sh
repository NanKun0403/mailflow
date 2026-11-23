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

# 容器内自保活：每 4 分钟 curl 自家 /api/health，让 Render 看到持续流量。
# （内部流量是否阻止免费实例休眠未经官方确认——见 keepalive.sh 头部说明；
#   无效也无害，想关掉把 KEEPALIVE_ENABLED=false 加进 Render 环境变量。）
KEEPALIVE_PID=""
if [ "${KEEPALIVE_ENABLED:-true}" = "true" ]; then
	sh /usr/local/bin/mailflow-keepalive &
	KEEPALIVE_PID=$!
fi

echo "mailflow-merge: backend=$NODE_PID caddy=$CADDY_PID keepalive=${KEEPALIVE_PID:-off} (public :$RENDER_PORT -> backend :$BACKEND_PORT)"

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
