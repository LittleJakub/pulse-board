#!/usr/bin/env bash
# Pulse Board — deliver.sh
# Sends a composed digest to the configured channel.
# Called by digest-agent.sh — not meant for direct use.
# Writes delivered message to last-delivered.md. Never touches last-digest.md.
# Supported channels: telegram, discord, feishu, log
# No sudo. No root.

set -euo pipefail

PULSE_HOME="${PULSE_HOME:-$HOME/.pulse-board}"
CONFIG_FILE="$PULSE_HOME/config/pulse.yaml"

[[ -f "$HOME/.openclaw/shared/secrets/openclaw-secrets.env" ]] && \
  { set +u; set -a; source "$HOME/.openclaw/shared/secrets/openclaw-secrets.env"; set +a; set -u; }

# ── Helpers ───────────────────────────────────────────────────────────────────
g() { printf "\033[0;32m%s\033[0m\n" "$*" >&2; }
y() { printf "\033[0;33m%s\033[0m\n" "$*" >&2; }
r() { printf "\033[0;31m%s\033[0m\n" "$*" >&2; }

cfg()       { grep -E "^[[:space:]]*${1}[[:space:]]*:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | sed "s/^[\"']\(.*\)[\"']$/\1/"; }
cfg_under() { awk "/^[[:space:]]*${1}:/{f=1} f && /^[[:space:]]*${2}:/{ sub(/.*:[[:space:]]*/,\"\"); gsub(/[\"' ]/,\"\"); print; exit }" "$CONFIG_FILE" 2>/dev/null; }
expand()    { echo "${1/#\~/$HOME}"; }
json_str()  { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<< "$1"; }

# ── Read message ──────────────────────────────────────────────────────────────
MESSAGE_FILE="${1:-}"
[[ -z "$MESSAGE_FILE" || ! -f "$MESSAGE_FILE" ]] && { r "deliver.sh: message file required."; exit 1; }
MESSAGE="$(cat "$MESSAGE_FILE")"
[[ -z "$MESSAGE" ]] && { y "deliver.sh: empty message — skipping."; exit 0; }

# ── Audit trail ───────────────────────────────────────────────────────────────
LAST_DELIVERED="$(expand "$PULSE_HOME/logs/last-delivered.md")"
mkdir -p "$(dirname "$LAST_DELIVERED")"
echo "$MESSAGE" > "$LAST_DELIVERED"

# ── Deliver ───────────────────────────────────────────────────────────────────
CHANNEL="$(cfg 'channel')"; CHANNEL="${CHANNEL:-log}"
TEXT="$(json_str "$MESSAGE")"

case "$CHANNEL" in
  telegram)
    BOT_TOKEN="$(cfg_under 'telegram' 'bot_token')"
    [[ -z "$BOT_TOKEN" ]] && BOT_TOKEN="${PULSE_TELEGRAM_BOT_TOKEN:-}"
    CHAT_ID="$(cfg_under 'telegram' 'chat_id')"
    THREAD_ID="$(cfg_under 'telegram' 'thread_id')"
    [[ -z "$BOT_TOKEN" ]] && { r "Telegram: bot_token not set."; exit 1; }
    [[ -z "$CHAT_ID"   ]] && { r "Telegram: chat_id not set.";   exit 1; }
    PAYLOAD="{\"chat_id\":\"$CHAT_ID\",\"text\":$TEXT,\"parse_mode\":\"Markdown\"}"
    [[ -n "$THREAD_ID" ]] && \
      PAYLOAD="{\"chat_id\":\"$CHAT_ID\",\"message_thread_id\":$THREAD_ID,\"text\":$TEXT,\"parse_mode\":\"Markdown\"}"
    curl -sf -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" -d "$PAYLOAD" --max-time 15 > /dev/null \
      && g "✓ Delivered to Telegram" || { r "Telegram delivery failed."; exit 1; }
    ;;
  discord)
    WEBHOOK="$(cfg_under 'discord' 'webhook_url')"
    [[ -z "$WEBHOOK" ]] && WEBHOOK="${PULSE_DISCORD_WEBHOOK_URL:-}"
    [[ -z "$WEBHOOK" ]] && { r "Discord: webhook_url not set."; exit 1; }
    curl -sf -X POST "$WEBHOOK" \
      -H "Content-Type: application/json" \
      -d "{\"content\":$TEXT}" --max-time 15 > /dev/null \
      && g "✓ Delivered to Discord" || { r "Discord delivery failed."; exit 1; }
    ;;
  feishu)
    APP_ID="$(cfg_under 'feishu' 'app_id')"
    APP_SECRET="$(cfg_under 'feishu' 'app_secret')"
    CHAT_ID="$(cfg_under 'feishu' 'chat_id')"
    THREAD_ID="$(cfg_under 'feishu' 'thread_id')"
    [[ -z "$APP_ID" ]]     && { r "Feishu: app_id not set.";     exit 1; }
    [[ -z "$APP_SECRET" ]] && { r "Feishu: app_secret not set."; exit 1; }
    [[ -z "$CHAT_ID" ]]    && { r "Feishu: chat_id not set.";    exit 1; }
    # Get tenant access token
    TOKEN_RESPONSE="$(curl -sf -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
      -H "Content-Type: application/json" \
      -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" --max-time 15)"
    TENANT_TOKEN="$(echo "$TOKEN_RESPONSE" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tenant_access_token",""))' 2>/dev/null)"
    [[ -z "$TENANT_TOKEN" ]] && { r "Feishu: failed to get tenant access token."; exit 1; }
    # Feishu content must be a JSON-encoded string: {"text":"..."}
    FEISHU_CONTENT="$(python3 -c 'import json,sys; print(json.dumps(json.dumps({"text":sys.stdin.read()})))' <<< "$MESSAGE")"
    if [[ -n "$THREAD_ID" ]]; then
      # Reply to thread root message (om_xxx) — posts into the thread
      # thread_id here is the message_id (om_xxx) of the thread's root message
      FEISHU_PAYLOAD="{\"msg_type\":\"text\",\"content\":$FEISHU_CONTENT,\"uuid\":\"$(date +%s%N)\"}"
      FEISHU_URL="https://open.feishu.cn/open-apis/im/v1/messages/$THREAD_ID/reply"
    else
      # Send to group chat directly
      FEISHU_PAYLOAD="{\"receive_id\":\"$CHAT_ID\",\"msg_type\":\"text\",\"content\":$FEISHU_CONTENT,\"uuid\":\"$(date +%s%N)\"}"
      FEISHU_URL="https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id"
    fi
    curl -sf -X POST "$FEISHU_URL" \
      -H "Authorization: Bearer $TENANT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$FEISHU_PAYLOAD" --max-time 15 > /dev/null \
      && g "✓ Delivered to Feishu" || { r "Feishu delivery failed."; exit 1; }
    ;;
  log|none)
    g "✓ Digest written to last-delivered.md"
    ;;
  *)
    y "Unknown channel '$CHANNEL' — saved to last-delivered.md only."
    ;;
esac
