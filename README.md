<div align="center">

# ox_lib

A comprehensive FiveM development library that streamlines resource creation through shared utilities, UI components, and common framework abstractions.

[![](https://img.shields.io/github/downloads/overextended/ox_lib/total?style=for-the-badge&logo=github)](https://github.com/overextended/ox_lib/releases/latest/download/ox_lib.zip)
[![](https://img.shields.io/github/downloads/overextended/ox_lib/latest/total?style=for-the-badge&logo=github)](https://github.com/overextended/ox_lib/releases/latest/download/ox_lib.zip)
[![](https://img.shields.io/github/v/release/overextended/ox_lib?style=for-the-badge&logo=github)](https://github.com/overextended/ox_lib/releases/latest/)\
[![](https://badges.5metrics.dev/ox_lib/serverRank.svg?style=for-the-badge)](https://5metrics.dev/resource/ox_lib)
[![](https://badges.5metrics.dev/ox_lib/servers.svg?style=for-the-badge)](https://5metrics.dev/resource/ox_lib)
[![](https://badges.5metrics.dev/ox_lib/players.svg?style=for-the-badge)](https://5metrics.dev/resource/ox_lib)

For guidelines to contributing to the project, and to see our Contributor License Agreement, see [CONTRIBUTING.md](./CONTRIBUTING.md)\
For additional legal notices, refer to [NOTICE.md](./NOTICE.md).

</div>

## 📚 Documentation

https://overextended.dev/ox_lib

## 💾 Download

https://github.com/overextended/ox_lib/releases/latest/download/ox_lib.zip

## 📦 npm package

https://www.npmjs.com/package/@overextended/ox_lib

## 📊 Dashy Integration

This fork includes **native [Dashy](https://github.com/your-org/ec-dashboard) support** as a built-in logging backend — no extra resources needed. Send your FiveM server logs directly to your Dashy dashboard alongside the existing Datadog, FiveManage, and Loki backends.

### Features

- **Batched log ingestion** — Logs buffer and send every 500ms or when the batch size threshold is reached
- **Rate limit handling** — Automatically respects 429 responses from the Dashy API with `Retry-After` cooldown
- **Structured player identity** — Collects player name, license, discord, fivem, and steam identifiers (never IP)
- **Coords metadata** — Attach coordinates to log entries for heatmap widgets on the dashboard
- **Configurable severity** — `info`, `warning`, `error`, `success` (defaults to `info`)
- **Startup health check** — Verifies connectivity to the Dashy API on resource start
- **Anti-tamper security** — Protects ox_lib from being stopped/restarted by cheat menus when Dashy logging is active
- **Debug mode** — Verbose console output for troubleshooting

### Setup

Add the following to your `server.cfg`:

```cfg
# Select Dashy as the logging backend
set ox:logger "dashy"

# Your Dashy API key (generated in the Dashy dashboard under Server Settings > API Keys)
set dashy:apiKey "dashy_your64hexkeyhere"

# Your Dashy API ingest endpoint
set dashy:endpoint "https://your-api.com/api/ingest"

# Optional: enable verbose debug output (default: false)
set dashy:debug "false"

# Optional: max logs per batch before force flush (default: 50)
set dashy:maxBatchSize "50"
```

### Usage

```lua
-- Basic log
lib.logger(source, 'playerJoined', 'Player connected to server')

-- With severity
lib.logger(source, 'bankRobbery', 'Robbery started at Pacific Standard', { severity = 'warning' })

-- With coords for heatmap widgets
lib.logger(source, 'fpsDrop', 'Player FPS dropped below 20', {
    severity = 'warning',
    coords = { x = 215.3, y = -810.5, z = 30.7 }
})

-- With custom tags and options
lib.logger(source, 'addMoney', 'Added $5000 to bank', 'amount:5000', 'type:bank', { severity = 'info' })

-- System event (source = 0)
lib.logger(0, 'serverStart', 'Server started successfully', { severity = 'success' })
```

### Severity Levels

| Level | Use case |
|-------|----------|
| `info` | General events — player joins, job changes, transactions (default) |
| `warning` | Notable events — low FPS, suspicious activity, robberies |
| `error` | Failures — script errors, failed transactions, connection issues |
| `success` | Positive confirmations — server start, successful operations |

### Coords Support

Pass a `coords` table in the options to enable heatmap visualisation on the Dashy dashboard:

```lua
lib.logger(source, 'fpsDrop', 'Low FPS detected', {
    coords = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
})
```

> **Note:** If you were previously using the standalone `dashy-logging` resource, you can remove it — this fork replaces it entirely. Just configure the convars above and you're good to go.

## 🖥️ Lua Language Server

- Install [Lua Language Server](https://luals.github.io/#install) to ease development with annotations, type checking, diagnostics, and more.
- Download [fivem-lls-addon](https://github.com/overextended/fivem-lls-addon) to add support for native declarations and other platform-specific functionality.
