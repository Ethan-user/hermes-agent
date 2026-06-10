# Hermes Agent Deployment on Render

This guide explains how to deploy Hermes Agent on Render using the provided configuration files.

## Files Created

1. **`Dockerfile.render`** - Custom Dockerfile specifically for Render deployment
2. **`docker-entrypoint.sh`** - Entrypoint script that configures Hermes on startup
3. **`render.yaml`** - Render service configuration

## Deployment Steps

### 1. Prepare Your Render Account

1. Sign up for a [Render account](https://render.com/)
2. Create a new Web Service
3. Connect your GitHub repository containing these files

### 2. Set Up Environment Variables

In the Render Dashboard, go to your service's Environment settings and add:

- **`OPENROUTER_API_KEY`** - Get a free key from [OpenRouter](https://openrouter.ai/keys)
- **`TELEGRAM_BOT_TOKEN`** - Create a bot with [@BotFather](https://t.me/BotFather) and use the token

### 3. Deployment Configuration

The `render.yaml` file contains:
- Service type: `web`
- Dockerfile path: `Dockerfile.render`
- Persistent disk: 1GB mounted at `/opt/data`
- Environment variables for API keys

### 4. What Happens During Deployment

1. Render builds the Docker image from `Dockerfile.render`
2. When the container starts, `docker-entrypoint.sh` runs:
   - Creates the data directory
   - Configures the OpenRouter model provider
   - Enables Telegram and API Server platforms
   - Adds authentication from environment variables
   - Installs the gateway
   - Starts Hermes in the foreground

### 5. Accessing Your Deployment

- The API Server will be available on port 8080
- Telegram bot will connect automatically using the provided token
- All data (skills, memories, configuration) persists in the 1GB disk

## Troubleshooting

If you see the error "Missing OPENROUTER_API_KEY or TELEGRAM_BOT_TOKEN", make sure:
1. Both environment variables are set in Render
2. The variable names are exactly as shown (case-sensitive)
3. The values are correct and don't contain extra spaces

## Notes

- The deployment uses the free OpenRouter model `google/gemma-7b-it:free`
- Telegram uses long-polling, so the API Server provides the required port for Render's health checks
- All configuration is automatic - no manual setup needed after deployment