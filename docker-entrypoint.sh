#!/usr/bin/env bash
set -euo pipefail

-------------------------------------------------
1️⃣  Wait for HERMES_HOME to exist (Render mounts the disk here)
-------------------------------------------------
mkdir -p "$HERMES_HOME"
cd "$HERMES_HOME"

-------------------------------------------------
2️⃣  Set model (free OpenRouter model)
-------------------------------------------------
hermes config set model.provider openrouter
hermes config set model.default google/gemma-7b-it:free

-------------------------------------------------
3️⃣  Enable Telegram + API Server (API Server gives Render a port)
-------------------------------------------------
hermes config set gateway.platforms.telegram.enabled true
hermes config set gateway.platforms.api_server.enabled true
hermes config set gateway.platforms.api_server.host 0.0.0.0
hermes config set gateway.platforms.api_server.port 8080

-------------------------------------------------
4️⃣  Add auth from Render‑injected env vars (non‑interactive)
-------------------------------------------------
if [[ -z "${OPENROUTER_API_KEY:-}" || -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "❌  Missing OPENROUTER_API_KEY or TELEGRAM_BOT_TOKEN – set them in Render → Environment" >&2
  exit 1
fi

# Non‑interactive auth add (works in Hermes v0.16.0)
echo "$OPENROUTER_API_KEY" | hermes auth add openrouter >/dev/null 2>&1
echo "$TELEGRAM_BOT_TOKEN" | hermes auth add telegram   >/dev/null 2>&1

-------------------------------------------------
5️⃣  Install the gateway (creates default config if missing)
-------------------------------------------------
hermes gateway install

-------------------------------------------------
6️⃣  Finally start Hermes in the foreground (required for s6)
-------------------------------------------------
exec hermes gateway run