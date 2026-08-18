# Release Notes: Dashy Ingestion & Anti-Tamper Security Integration

This custom release adds native, high-performance support for the **Dashy Dashboard** directly into the `ox_lib` logging suite, alongside a dedicated anti-tamper security layer. 

With this integration, the separate `dashy-logging` resource is no longer required. You can route all `lib.logger` calls directly to your Dashy instance natively via `ox_lib` configuration.

---

## 🚀 Key Features

### 1. Native Dashy Log Ingestion
- **Batched Sending:** Buffers log entries and flushes them every `500ms` or immediately when the batch size hits the limit (default `50`), optimizing network overhead.
- **Smart Rate Limiting:** Seamlessly respects `429 Too Many Requests` responses from the Dashy API. It parses the `Retry-After` header and pauses transmission during the cooldown period to prevent log spam and API blocks.
- **Structured Player Identity:** Automatically resolves and attaches player identifiers (`license`, `discord`, `fivem`, `steam`) and names for player-sourced logs, while strictly ignoring and scrubbing player IP addresses.
- **Coords & Heatmaps:** Supports passing a `coords` table within log metadata to feed heatmap widgets on the Dashy front-end.
- **Configurable Severity:** Introduces support for specific log severities (`info`, `warning`, `error`, `success`) to color-code and filter logs on the dashboard.
- **Startup Health Checks:** Performs an automatic ping to the Dashy `/health` endpoint during startup to verify connection status.

### 2. Built-in Anti-Tamper Security Layer
Only activates when the logger is set to `"dashy"` to safeguard server logging integrity:
- **Resource Protection:** Cancels and blocks unauthorized resource `stop` or `restart` events targeted at `ox_lib`.
- **RCON Protection:** Intercepts and blocks malicious console/RCON commands trying to stop, restart, ensure, or refresh `ox_lib`.
- **Client Exploit Protection:** Blocks and logs any client-side attempts to trigger internal logging events (`ox_lib:_internal_dashy`).
- **Integrity Loops:** Performs a periodic 60-second validation of the resource state, internal integrity token, and read-only metatables.

### 3. Upstream Maintenance Tooling
- Includes `sync_upstream.ps1` to easily rebase these custom Dashy changes on top of future official Overextended releases.

---

## ⚙️ Configuration (`server.cfg`)

Activate Dashy by adding the following convars:

```cfg
# Enable the Dashy logging service backend
set ox:logger "dashy"

# Your Dashy server API key
set dashy:apiKey "dashy_your_secret_api_key_here"

# The ingest endpoint of your Dashy API
set dashy:endpoint "https://your-dashy-instance.com/api/ingest"

# Optional: Enable verbose logging for debugging (true/false)
set dashy:debug "false"

# Optional: Max batch size before forcing a flush (default: 50)
set dashy:maxBatchSize "50"
```

---

## 💻 Code Examples

### Standard Log
```lua
lib.logger(source, 'playerJoined', 'Player connected to the server')
```

### Log with Severity Level
```lua
lib.logger(source, 'bankRobbery', 'Pacific Standard Vault has been breached!', { severity = 'warning' })
```

### Log with Coordinates (Heatmap Support)
```lua
lib.logger(source, 'fpsDrop', 'Low FPS detected', {
    severity = 'warning',
    coords = { x = 215.3, y = -810.5, z = 30.7 }
})
```

### Log with Custom Tags & Options
```lua
lib.logger(source, 'addMoney', 'Player received payout', 'amount:5000', 'type:cash', { severity = 'info' })
```

---

## 🛠️ Files Modified

- **`imports/logger/server.lua`**: Added `'dashy'` service backend handler, buffer flush logic, parser helper, and metadata formatting.
- **`resource/dashy_security/server.lua`** [NEW]: Integrated anti-tamper security suite.
- **`fxmanifest.lua`**: Updated to load the security layer prior to initialization.
- **`README.md`**: Appended documentation on configuration, usage, and severity mapping.
