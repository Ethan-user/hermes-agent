#!/usr/bin/env bash
set -euo pipefail

# Use Render's PORT environment variable (defaults to 10000 if not set)
PORT="${PORT:-10000}"

# Prevent multiple executions
LOCK_FILE="$HERMES_HOME/.entrypoint_ran"

# Function to start a simple port binder
start_port_binder() {
    echo "Starting port binder on 0.0.0.0:$PORT"
    python3 -c "
import http.server
import socketserver
import os
import subprocess
import sys

class HealthCheckHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'Hermes Gateway is starting...')

port = int(os.environ.get('PORT', '10000'))
print(f'✅ Port {port} bound to 0.0.0.0 for Render health checks')

# Start HTTP server in a thread
from threading import Thread
def run_server():
    with socketserver.TCPServer(("0.0.0.0", port), HealthCheckHandler) as httpd:
        httpd.serve_forever()

server_thread = Thread(target=run_server, daemon=True)
server_thread.start()

print('✅ Port binder running, starting Hermes gateway...')
# Now start the actual Hermes gateway
sys.argv = ['hermes', 'gateway', 'run']
try:
    subprocess.run(['hermes', 'gateway', 'run'], check=True)
except subprocess.CalledProcessError as e:
    print(f'❌ Hermes gateway exited with error: {e}')
    sys.exit(1)
" 
}

# First run - do setup and start everything
if [[ ! -f "$LOCK_FILE" ]]; then
    echo ">>>> ENTRYPOINT STARTING (First Run) <<<<"
    
    # Make sure we're in the right directory
    mkdir -p "$HERMES_HOME"
    cd "$HERMES_HOME"
    
    # Verify hermes command is available
    if ! command -v hermes >/dev/null 2>&1; then
        echo "❌ hermes command not found in PATH" >&2
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
    hermes config set gateway.platforms.api_server.port "$PORT"
    
    # Generate API server key (REQUIRED)
    echo "Generating API server key..."
    API_SERVER_KEY=$(openssl rand -hex 32)
    echo "API_SERVER_KEY=$API_SERVER_KEY" >> "$HERMES_HOME/.env"
    hermes config set gateway.platforms.api_server.key "$API_SERVER_KEY"
    echo "✅ API Server Key: $API_SERVER_KEY"
    
    # Add auth from env vars
    echo "Adding authentication..."
    if [[ -z "${OPENROUTER_API_KEY:-}" || -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
        echo "❌ Missing OPENROUTER_API_KEY or TELEGRAM_BOT_TOKEN" >&2
        exit 1
    fi
    
    echo "$OPENROUTER_API_KEY" > "$HERMES_HOME/.env.openrouter"
    echo "OPENROUTER_API_KEY=$OPENROUTER_API_KEY" >> "$HERMES_HOME/.env"
    echo "$TELEGRAM_BOT_TOKEN" > "$HERMES_HOME/.env.telegram"
    echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$HERMES_HOME/.env"
    
    # Set Telegram allowed users
    if [[ -n "${TELEGRAM_ALLOWED_USERS:-}" ]]; then
        echo "Setting Telegram allowed users: $TELEGRAM_ALLOWED_USERS"
        hermes config set gateway.platforms.telegram.allowed_users "$TELEGRAM_ALLOWED_USERS"
    else
        echo "⚠️  Set TELEGRAM_ALLOWED_USERS env var for security"
    fi
    
    # Configure Telegram session
    hermes config set gateway.platforms.telegram.session_name "render-$(hostname)-$(date +%s)"
    
    # Mark setup complete
    touch "$LOCK_FILE"
    echo "✅ Setup complete"
fi

# Start the port binder which will also start Hermes
echo "Starting combined port binder and Hermes gateway..."
start_port_binder
