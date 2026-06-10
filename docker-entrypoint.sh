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

# Try non-interactive auth add, but don't fail if it's already added
if hermes auth list | grep -q openrouter; then
    echo "✅ OpenRouter auth already exists"
else
    echo "Adding OpenRouter auth..."
    printf "%s\n" "$OPENROUTER_API_KEY" | hermes auth add openrouter || echo "⚠️  OpenRouter auth add failed, might already exist"
fi

if hermes auth list | grep -q telegram; then
    echo "✅ Telegram auth already exists"
else
    echo "Adding Telegram auth..."
    printf "%s\n" "$TELEGRAM_BOT_TOKEN" | hermes auth add telegram || echo "⚠️  Telegram auth add failed, might already exist"
fi

# Install gateway
echo "Installing gateway..."
hermes gateway install || echo "⚠️  Gateway install failed, might already be installed"

# Mark that we've run
touch "$LOCK_FILE"
echo "✅ Setup complete"

# Start Hermes
echo "Starting Hermes gateway..."
exec hermes gateway run
