# Discord Bot Setup for Substrate

## Overview

Substrate's Discord bot represents Q (Qwen3 8B) in Discord servers. It uses slash commands to let users interact with the local model and get project information.

**Bot name:** substrate
**Prefix:** `!q` or `!substrate` (legacy, for servers that don't support slash commands)

## Prerequisites

- Discord account
- A server where you have "Manage Server" permissions (for testing)
- Stable network connection on the laptop (required for gateway bot)

## Step 1: Create the Application

1. Go to https://discord.com/developers/applications
2. Click "New Application"
3. Name: `substrate`
4. Description: "Sovereign AI workstation — two AIs, one laptop. Talk to Q (Qwen3 8B) running on local hardware."
5. Save the **Application ID** and **Public Key**

## Step 2: Create the Bot User

1. Go to the "Bot" tab in your application
2. Click "Add Bot"
3. Set the bot username: `substrate`
4. Upload avatar (use the substrate logo or a terminal-green themed image)
5. Under "Privileged Gateway Intents":
   - MESSAGE CONTENT INTENT: **ON** (needed for prefix commands)
   - PRESENCE INTENT: OFF
   - SERVER MEMBERS INTENT: OFF
6. Copy the **Bot Token** — store it in `.env` as `DISCORD_BOT_TOKEN`

**SECURITY: Never commit the bot token. Store in `.env` only.**

## Step 3: Set Bot Permissions

Required permissions (use the OAuth2 URL Generator):

| Permission | Why |
|---|---|
| Send Messages | Respond to commands |
| Send Messages in Threads | Support threaded conversations |
| Embed Links | Rich embeds with substrate branding |
| Read Message History | Context for conversations |
| Use Slash Commands | Primary interaction method |
| Add Reactions | React to acknowledge commands |

**Permission integer:** `274877991936`

### OAuth2 Invite URL

```
https://discord.com/api/oauth2/authorize?client_id=YOUR_APP_ID&permissions=274877991936&scope=bot%20applications.commands
```

Replace `YOUR_APP_ID` with the Application ID from Step 1.

## Step 4: Register Slash Commands

Register these globally via the Discord API. Use `scripts/bots/discord_register_commands.sh` (create if needed) or register manually:

```bash
# Register slash commands (run once)
BOT_TOKEN="your-token-here"
APP_ID="your-app-id-here"

curl -X PUT \
  "https://discord.com/api/v10/applications/$APP_ID/commands" \
  -H "Authorization: Bot $BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "name": "q",
      "description": "Ask Q (Qwen3 8B running on local hardware) a question",
      "type": 1,
      "options": [
        {
          "name": "prompt",
          "description": "Your question or prompt for Q",
          "type": 3,
          "required": true
        }
      ]
    },
    {
      "name": "substrate",
      "description": "Get info about the Substrate project",
      "type": 1,
      "options": [
        {
          "name": "topic",
          "description": "What to learn about",
          "type": 3,
          "required": false,
          "choices": [
            {"name": "overview", "value": "overview"},
            {"name": "hardware", "value": "hardware"},
            {"name": "architecture", "value": "architecture"},
            {"name": "blog", "value": "blog"},
            {"name": "funding", "value": "funding"}
          ]
        }
      ]
    },
    {
      "name": "sigterm",
      "description": "Get the daily SIGTERM puzzle link",
      "type": 1
    },
    {
      "name": "news",
      "description": "Get the latest Byte Report (daily project update)",
      "type": 1
    }
  ]'
```

## Step 5: Slash Command Responses

### /q <prompt>

Flow:
1. Receive interaction
2. Respond with deferred message (type 5) — "Q is thinking..."
3. Forward prompt to local Ollama (`scripts/think.py` or direct API)
4. Edit the deferred message with Q's response
5. Include footer: "Qwen3 8B | RTX 4060 | responded in Xs"

Response limits: 2000 characters. If Q's response exceeds this, truncate with "... [truncated, full response on blog]".

### /substrate [topic]

Return a branded embed with project info. Topics:

- **overview** (default): What Substrate is, one-paragraph summary
- **hardware**: Lenovo Legion 5, RTX 4060 8GB, NixOS specs
- **architecture**: Two-brain system (Q local, Claude cloud), systemd services
- **blog**: Link to latest posts at substrate.lol
- **funding**: How to sponsor, current hardware goals

### /sigterm

Return the daily SIGTERM puzzle link:
```
Today's SIGTERM puzzle: https://substrate.lol/sigterm/
Can you find the kill code?
```

### /news

Fetch the latest blog post title and URL. Return as embed with excerpt.

## Step 6: Deployment

### Option A: Gateway Bot (requires stable connection)

Run as a systemd service on the laptop:

```nix
# nix/discord-bot.nix
{ config, pkgs, ... }:
{
  systemd.services.substrate-discord = {
    description = "Substrate Discord Bot";
    after = [ "network-online.target" "ollama.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 /home/operator/substrate/scripts/bots/discord_bot.py";
      Restart = "on-failure";
      RestartSec = "30s";
      EnvironmentFile = "/home/operator/substrate/.env";
      WorkingDirectory = "/home/operator/substrate";
    };
  };
}
```

### Option B: Webhook-only (current approach, no persistent connection needed)

Use `discord_webhook.py` to post announcements, blog notifications, and status updates to Discord channels. No gateway connection required.

Integrate into existing pipelines:
```bash
# In scripts/pipeline.py, after publishing a blog post:
python3 scripts/bots/discord_webhook.py "$DISCORD_WEBHOOK_URL" \
  --title "New Post" --file blog/posts/latest.md --url "https://substrate.lol/..."
```

### Option C: Interactions Endpoint (serverless-style)

If we later deploy a public HTTP endpoint (via Cloudflare Workers, etc.), we can handle slash commands without a gateway connection:

1. Set the Interactions Endpoint URL in the Discord Developer Portal
2. Verify the interaction signature (Ed25519)
3. Respond to interactions via HTTP response

This is the long-term goal once we have a stable public endpoint.

## Environment Variables

Add to `.env`:
```
DISCORD_BOT_TOKEN=<bot token from Step 2>
DISCORD_APP_ID=<application id from Step 1>
DISCORD_PUBLIC_KEY=<public key from Step 1>
DISCORD_WEBHOOK_URL=<webhook url for announcement channels>
```

## Bot Status

Set the bot's status/activity to:
- **Activity type:** Watching
- **Activity name:** "the terminal | substrate.lol"

## Security Notes

- Bot token is equivalent to a password. Never commit it.
- Webhook URLs are semi-secret. Don't commit them either.
- Rate limits: Discord allows 50 requests/second globally. The bot should implement backoff.
- The bot should never execute arbitrary code from Discord messages.
- Q's responses should be sanitized (no @everyone, no @here, strip Discord mentions).
