#!/usr/bin/env bash
set -euo pipefail

# Use Render's PORT environment variable (defaults to 10000 if not set)
PORT="${PORT:-10000}"

# Prevent multiple executions
LOCK_FILE="$HERMES_HOME/.entrypoint_ran"

# Function to check if commands are available
check_commands() {
    echo "Checking required commands..."
    
    # Check for python3
    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ python3 not found - trying python..."
        if ! command -v python >/dev/null 2>&1; then
            echo "❌ Neither python3 nor python found!" >&2
            exit 127
        fi
        PYTHON_CMD="python"
    else
        PYTHON_CMD="python3"
    fi
    echo "✅ Using $PYTHON_CMD"
    
    # Check for hermes
    if ! command -v hermes >/dev/null 2>&1; then
        echo "❌ hermes command not found" >&2
        echo "PATH: $PATH" >&2
        ls -la /usr/local/bin/ >&2
        exit 127
    fi
    echo "✅ hermes command found"
}

# Function to start a simple port binder
start_port_binder() {
    echo "Starting port binder on 0.0.0.0:$PORT"
    
    # Create port binder script
    cat > "$HERMES_HOME/port_binder.py" << 'EOF'
import http.server
import socketserver
import os
import subprocess
import sys
import threading
import time

class HealthCheckHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'Hermes Gateway is starting...')
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

def run_health_server():
    port = int(os.environ.get('PORT', '10000'))
    print(f'✅ Port {port} bound to 0.0.0.0 for Render health checks', flush=True)
    with socketserver.TCPServer(("0.0.0.0", port), HealthCheckHandler) as httpd:
        httpd.serve_forever()

# Start health server in background thread
health_thread = threading.Thread(target=run_health_server, daemon=True)
health_thread.start()

# Give health server a moment to start
time.sleep(1)

print('✅ Port binder running, starting Hermes gateway...', flush=True)

# Start the actual Hermes gateway
try:
    result = subprocess.run(['hermes', 'gateway', 'run'])
    sys.exit(result.returncode)
except Exception as e:
    print(f'❌ Hermes gateway exited with error: {e}', flush=True)
    sys.exit(1)
EOF

    # Run the Python script with proper error handling
    if ! $PYTHON_CMD "$HERMES_HOME/port_binder.py"; then
        echo "❌ Port binder failed to start" >&2
        exit 1
    fi
}

# First run - do setup and start everything
if [[ ! -f "$LOCK_FILE" ]]; then
    echo ">>>> ENTRYPOINT STARTING (First Run) <<<<"
    
    # Check commands first
    check_commands
    
    # Make sure we're in the right directory
    mkdir -p "$HERMES_HOME"
    cd "$HERMES_HOME"
    
    echo "✅ hermes command found: $(command -v hermes)"
    
    # Set model (using Nemotron-3-Super 120B - more powerful and still free)
    echo "Setting model provider..."
    hermes config set model.provider openrouter
    hermes config set model.default nvidia/nemotron-3-super-120b-a12b:free
    
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
check_commands
start_port_binder
