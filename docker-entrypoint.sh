#!/usr/bin/env bash
set -euo pipefail

# Prevent multiple executions
LOCK_FILE="$HERMES_HOME/.entrypoint_ran"
if [[ -f "$LOCK_FILE" ]]; then
    echo "✅ Entrypoint already ran, skipping setup"
    exec hermes gateway run
fi

echo ">>>> ENTRYPOINT STARTING <<<<"

# Make sure we're in the right directory
mkdir -p "$HERMES_HOME"
cd "$HERMES_HOME"

# Verify hermes command is available
if ! command -v hermes >/dev/null 2>&1; then
    echo "❌ hermes command not found in PATH" >&2
    echo "PATH: $PATH" >&2
    ls -la /usr/local/bin/ >&2
    exit 127
fi

echo "✅ hermes command found: $(command -v hermes)"

# Set model
echo "Setting model provider..."
hermes config set model.provider openrouter
hermes config set model.default google/gemma-7b-it:free

# Enable platforms
echo "Enabling platforms..."
hermes config set gateway.platforms.telegram.enabled true
hermes config set gateway.platforms.api_server.enabled true
hermes config set gateway.platforms.api_server.host 0.0.0.0
hermes config set gateway.platforms.api_server.port 8080

# Add auth from env vars
echo "Adding authentication..."
if [[ -z "${OPENROUTER_API_KEY:-}" || -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    echo "❌ Missing OPENROUTER_API_KEY or TELEGRAM_BOT_TOKEN" >&2
    exit 1
fi

# Add OpenRouter API key to config (Hermes uses OPENROUTER_API_KEY env var directly)
echo "$OPENROUTER_API_KEY" > "$HERMES_HOME/.env.openrouter"
echo "OPENROUTER_API_KEY=$OPENROUTER_API_KEY" >> "$HERMES_HOME/.env"

# Add Telegram bot token to config (Hermes uses TELEGRAM_BOT_TOKEN env var directly)
echo "$TELEGRAM_BOT_TOKEN" > "$HERMES_HOME/.env.telegram"
echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$HERMES_HOME/.env"

# Set Telegram allowed users (replace with your Telegram user ID)
# You can find your user ID by sending /id to @userinfobot in Telegram
TELEGRAM_ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-}"
if [[ -n "$TELEGRAM_ALLOWED_USERS" ]]; then
    echo "Setting Telegram allowed users: $TELEGRAM_ALLOWED_USERS"
    hermes config set gateway.platforms.telegram.allowed_users "$TELEGRAM_ALLOWED_USERS"
else
    echo "⚠️  No TELEGRAM_ALLOWED_USERS set - you should set this env var in Render"
    echo "    Find your Telegram user ID with @userinfobot and set TELEGRAM_ALLOWED_USERS=your_id"
fi

# Mark that we've run
touch "$LOCK_FILE"
echo "✅ Setup complete"

# Start Hermes
echo "Starting Hermes gateway..."
exec hermes gateway run
