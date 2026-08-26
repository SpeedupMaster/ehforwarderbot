#!/usr/bin/env bash
# Keep the original telegram-bot-api binary as-is. Before starting it, run a
# gost transparent redirect listener and redirect all outbound TCP from the
# container to a SOCKS5 parent proxy with iptables.
set -e

GOST_PORT="${TGSOCKS_GOST_PORT:-12345}"
PROXY_HOST="${TGSOCKS_PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${TGSOCKS_PROXY_PORT:-7890}"
PROXY_URL="socks5://${TGSOCKS_PROXY_HOST}:${TGSOCKS_PROXY_PORT}}"
CHAIN="TGSOCKS_REDIR"

log() {
  echo "[tgsocks] $*"
}

if ! command -v /usr/local/bin/gost >/dev/null 2>&1; then
  log "gost binary missing"
  exit 1
fi

if ! command -v iptables >/dev/null 2>&1; then
  log "iptables binary missing"
  exit 1
fi

log "starting transparent listener on ${GOST_PORT} via ${PROXY_URL}"
/usr/local/bin/gost -L "redirect://:${GOST_PORT}" -F "${PROXY_URL}" &
GOST_PID=$!

trap 'kill "${GOST_PID}" 2>/dev/null || true' EXIT
sleep 1

log "installing iptables redirect rules"
iptables -t nat -F "${CHAIN}" 2>/dev/null || true
iptables -t nat -N "${CHAIN}" 2>/dev/null || true
iptables -t nat -F "${CHAIN}"
iptables -t nat -A "${CHAIN}" -p tcp -d 127.0.0.0/8 -j RETURN
iptables -t nat -A "${CHAIN}" -p tcp -d 10.0.0.0/8 -j RETURN
iptables -t nat -A "${CHAIN}" -p tcp -d 172.16.0.0/12 -j RETURN
iptables -t nat -A "${CHAIN}" -p tcp -d 192.168.0.0/16 -j RETURN
iptables -t nat -A "${CHAIN}" -p tcp -d "${PROXY_HOST}" --dport "${PROXY_PORT}" -j RETURN
iptables -t nat -A "${CHAIN}" -p tcp -j REDIRECT --to-ports "${GOST_PORT}"

iptables -t nat -D OUTPUT -p tcp -j "${CHAIN}" 2>/dev/null || true
iptables -t nat -A OUTPUT -p tcp -j "${CHAIN}"

log "starting telegram-bot-api with args:"
for arg in "$@"; do
  log "  ${arg}"
done

/usr/local/bin/telegram-bot-api "$@"
