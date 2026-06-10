#!/usr/bin/env bash
set -euo pipefail

# Prevent multiple executions
if [[ -f "$HERMES_HOME/.entrypoint_ran" ]]; then
    echo "✅ Entrypoint already ran, skipping setup"
else
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
    
    echo "$OPENROUTER_API_KEY" | hermes auth add openrouter >/dev/null 2>&1
    echo "$TELEGRAM_BOT_TOKEN" | hermes auth add telegram >/dev/null 2>&1
    
    # Install gateway
    echo "Installing gateway..."
    hermes gateway install
    
    # Mark that we've run
    touch "$HERMES_HOME/.entrypoint_ran"
    echo "✅ Setup complete"
fi

# Start Hermes
echo "Starting Hermes gateway..."
exec hermes gateway run
