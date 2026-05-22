--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local service = GetConvar('ox:logger', 'datadog')

local function removeColorCodes(str)
    -- replace ^[0-9] with nothing
    str = string.gsub(str, "%^%d", "")

    -- replace ^#[0-9A-F]{3,6} with nothing
    str = string.gsub(str, "%^#[%dA-Fa-f]+", "")

    -- replace ~[a-z]~ with nothing
    str = string.gsub(str, "~[%a]~", "")

    return str
end

local hostname = removeColorCodes(GetConvar('ox:logger:hostname', GetConvar('sv_projectName', 'fxserver')))

local function badResponse(endpoint, status, response)
    warn(('unable to submit logs to %s (status: %s)\n%s'):format(endpoint, status, json.encode(response, { indent = true })))
end

local playerData = {}

AddEventHandler('playerDropped', function()
    playerData[source] = nil
end)

local function formatTags(source, tags)
    if type(source) == 'number' and source > 0 then
        local data = playerData[source]

        if not data then
            local _data = {
                ('username:%s'):format(GetPlayerName(source))
            }

            local num = 1

            ---@cast source string
            for i = 0, GetNumPlayerIdentifiers(source) - 1 do
                local identifier = GetPlayerIdentifier(source, i)

                if not identifier:find('ip') then
                    num += 1
                    _data[num] = identifier
                end
            end

            data = table.concat(_data, ',')
            playerData[source] = data
        end

        tags = tags and ('%s,%s'):format(tags, data) or data
    end

    return tags
end

---@class LogContext
---@field hostname string
---@field formatTags fun(source: any, tags: string?): string?

---@class LogProvider
---@field endpoint string
---@field headers table<string, string>
---@field okStatus number
---@field append fun(buffer: table, source: any, event: string, message: string, ...): nil
---@field encode fun(buffer: table): string
---@field parseError fun(status: number, response: any, body: string): any|nil

local KNOWN = { datadog = true, fivemanage = true, loki = true }

if not KNOWN[service] then return lib.logger end

---@type fun(ctx: LogContext): LogProvider?
local providerFactory = lib.require(('imports.logger.providers.%s'):format(service))
if not providerFactory then return lib.logger end

local provider = providerFactory({
    hostname = hostname,
    formatTags = formatTags,
})
if not provider then return lib.logger end

local buffer

function lib.logger(source, event, message, ...)
    if not buffer then
        buffer = {}

        SetTimeout(500, function()
            local body = provider.encode(buffer)
            buffer = nil

            PerformHttpRequest(provider.endpoint, function(status, _, _, response)
                if status == provider.okStatus then return end

                local err = provider.parseError(status, response, body)
                if err == nil then return end

                badResponse(provider.endpoint, status, err)
            end, 'POST', body, provider.headers)
        end)
    end

    provider.append(buffer, source, event, message, ...)
end

if service == 'dashy' then
    local apiKey = GetConvar('dashy:apiKey', '')
    local dashyEndpoint = GetConvar('dashy:endpoint', 'http://localhost:8080/api/ingest')
    local dashyDebug = GetConvar('dashy:debug', 'false') == 'true'
    local maxBatchSize = tonumber(GetConvar('dashy:maxBatchSize', '50')) or 50
    local cooldownUntil = 0

    if apiKey ~= '' then
        local headers = {
            ['Content-Type'] = 'application/json',
            ['Authorization'] = ('Bearer %s'):format(apiKey),
        }

        -- Health check on startup
        local healthEndpoint = dashyEndpoint:gsub('/api/ingest$', '/health')

        PerformHttpRequest(healthEndpoint, function(status)
            if status == 200 then
                if dashyDebug then
                    print(('[dashy] Health check passed (status: %s)'):format(status))
                end
            elseif status == 0 then
                warn('[dashy] Health check failed: endpoint unreachable at ' .. healthEndpoint)
            else
                warn(('[dashy] Health check returned unexpected status: %s'):format(status))
            end
        end, 'GET', '', headers)

        local function flushBuffer()
            if not buffer or bufferSize == 0 then return end

            local payload = buffer
            local count = bufferSize
            buffer = nil
            bufferSize = 0

            if dashyDebug then
                print(('[dashy] Flushing %d log entries'):format(count))
            end

            PerformHttpRequest(dashyEndpoint, function(status, _, responseHeaders)
                if status == 200 or status == 201 or status == 204 then
                    if dashyDebug then
                        print(('[dashy] Successfully sent %d logs'):format(count))
                    end
                elseif status == 429 then
                    local retryAfter = 120
                    if responseHeaders and responseHeaders['Retry-After'] then
                        retryAfter = tonumber(responseHeaders['Retry-After']) or 120
                    end
                    cooldownUntil = os.time() + retryAfter
                    warn(('[dashy] Rate limited. Cooling down for %ds'):format(retryAfter))
                elseif status == 401 then
                    warn('[dashy] Authentication failed: invalid API key')
                elseif status == 0 then
                    warn('[dashy] Failed to send logs: endpoint unreachable at ' .. dashyEndpoint)
                else
                    badResponse(dashyEndpoint, status, { message = 'Unexpected status' })
                end
            end, 'POST', json.encode(payload), headers)
        end

        function lib.logger(source, event, message, ...)
            -- Skip logging during rate-limit cooldown
            if os.time() < cooldownUntil then
                if dashyDebug then
                    print(('[dashy] Skipping log: rate-limit cooldown active for %ds'):format(cooldownUntil - os.time()))
                end
                return
            end

            if not buffer then
                buffer = {}

                SetTimeout(500, function()
                    flushBuffer()
                end)
            end

            -- Parse varargs: string tags + optional trailing options table
            local args = { ... }
            local severity = 'info'
            local coords = nil
            local tagArgs = {}

            if #args > 0 and type(args[#args]) == 'table' then
                local opts = table.remove(args, #args)
                severity = opts.severity or severity
                coords = opts.coords or coords
            end

            for _, arg in ipairs(args) do
                if type(arg) == 'string' then
                    tagArgs[#tagArgs + 1] = arg
                end
            end

            -- Build tags string via formatTags (merges player identifiers + custom tags)
            local customTags = #tagArgs > 0 and table.concat(tagArgs, ',') or nil
            local tags = formatTags(source, customTags)

            -- Collect structured player data
            local playerName = nil
            local identifiers = nil

            if type(source) == 'number' and source > 0 then
                playerName = GetPlayerName(source)

                identifiers = {}
                for i = 0, GetNumPlayerIdentifiers(source) - 1 do
                    local identifier = GetPlayerIdentifier(source, i)
                    if identifier and not identifier:find('ip') then
                        local idType, idValue = string.strsplit(':', identifier)
                        if idType and idValue then
                            identifiers[idType] = identifier
                        end
                    end
                end
            end

            -- Build log entry matching IngestLogEntry format
            local entry = {
                event_type = event,
                message = message,
                source = tostring(source),
                metadata = {
                    hostname = hostname,
                    resource = cache.resource,
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                    severity = severity,
                    player_name = playerName,
                    identifiers = identifiers,
                    tags = tags,
                    coords = coords,
                },
            }

            bufferSize += 1
            buffer[bufferSize] = entry

            -- Force flush if batch size threshold is reached
            if bufferSize >= maxBatchSize then
                flushBuffer()
            end
        end
    end
end

return lib.logger
