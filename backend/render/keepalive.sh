#!/bin/sh
# ── 容器内自保活（Render 免费实例）──────────────────────────────────────────
# Render 的休眠判定是「15 分钟没有外部 HTTP 请求」。本脚本在容器里每 4 分钟
# curl 一次自家 Caddy 端口，让 access log 持续产生流量。
#
# 诚实说明：这是社区通用做法，但 Render 官方文档写的是"无流量则休眠"，未明确
# 内部流量是否计入——上线后请看一眼 Render 的 usage 图表验证是否真的不再睡；
# 若无效，此进程无害（只多占一个 curl），删掉即可。
#
# 附带效果：curl 走完整链路 Caddy → /api/health → node → Neon，顺带把 Neon
# compute 也从 scale-to-zero 唤醒，冷启动延迟一并缓解。
#
# 环境变量 KEEPALIVE_INTERVAL_SEC：ping 间隔秒数（默认 240）。
set -u

INTERVAL=${KEEPALIVE_INTERVAL_SEC:-240}
URL="http://127.0.0.1:${PORT:-10000}/api/health"

echo "mailflow-keepalive: self-ping $URL every ${INTERVAL}s"

while :; do
	sleep "$INTERVAL"
	# -s 静默、-m 30 超时、|| true 永不拖垮循环
	curl -s -m 30 -o /dev/null "$URL" 2>/dev/null || true
done
