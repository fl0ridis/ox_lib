--[[
    ox_lib — Dashy Anti-Tamper Security Layer

    Protections against cheat menus and unauthorized manipulation:
    1. Block resource stop/restart when Dashy logging is active
    2. Block rcon commands targeting ox_lib
    3. Block client-triggered internal events
    4. Periodic integrity verification
    5. Read-only security global

    This file MUST load before the logger module.
    Only activates when ox:logger convar is set to 'dashy'.
]]

-- ── Guard: only activate when Dashy logging is enabled ───────────────
if GetConvar('ox:logger', 'datadog') ~= 'dashy' then return end

local resourceName = GetCurrentResourceName()

-- ── 1. Block resource stop/restart via server events ─────────────────
-- Cheat menus often trigger "stop <resource>" or "restart <resource>"
-- We intercept and cancel any attempt targeting this resource

AddEventHandler('onResourceStop', function(resource)
    if resource == resourceName then
        warn(('[ox_lib:dashy] Blocked attempt to stop %s!'):format(resourceName))
        CancelEvent()
    end
end)

AddEventHandler('onResourceStart', function(resource)
    -- Only block if someone is trying to restart us (we're already running)
    if resource == resourceName and GetResourceState(resourceName) == 'started' then
        warn(('[ox_lib:dashy] Blocked attempt to restart %s!'):format(resourceName))
        CancelEvent()
    end
end)

-- ── 2. Block rcon command abuse ──────────────────────────────────────
-- Some cheat menus trigger server commands via client exploits

local blockedCommands = {
    'stop ' .. resourceName,
    'restart ' .. resourceName,
    'ensure ' .. resourceName,
    'refresh',
}

AddEventHandler('rconCommand', function(commandName, args)
    local fullCmd = commandName
    if args and #args > 0 then
        fullCmd = commandName .. ' ' .. table.concat(args, ' ')
    end

    local lowerCmd = string.lower(fullCmd)
    for _, blocked in ipairs(blockedCommands) do
        if lowerCmd == string.lower(blocked) then
            print('^1[ox_lib:dashy] ^3WARNING: Blocked rcon command: ' .. fullCmd .. '^0')
            CancelEvent()
            return
        end
    end
end)

-- ── 3. Protect against client-side triggers ──────────────────────────
-- Block any client attempting to trigger server events that could
-- manipulate the logging system

RegisterNetEvent('ox_lib:_internal_dashy')
AddEventHandler('ox_lib:_internal_dashy', function()
    local src = source
    print('^1[ox_lib:dashy] ^3WARNING: Player ' .. GetPlayerName(src) ..
          ' (ID: ' .. src .. ') attempted to trigger internal dashy event!^0')
    -- Optionally: DropPlayer(src, 'Unauthorized action')
end)

-- ── 4. Integrity check — verify we haven't been tampered with ────────
-- Periodically verify the resource is still functioning correctly

local integrityToken = tostring(math.random(100000, 999999))
local lastIntegrityCheck = 0

CreateThread(function()
    while true do
        Wait(60000) -- Check every 60 seconds

        -- Verify our resource is still running
        if GetResourceState(resourceName) ~= 'started' then
            print('^1[ox_lib:dashy] CRITICAL: Resource state is not started!^0')
        end

        -- Verify our integrity token hasn't been overwritten
        if integrityToken == nil then
            print('^1[ox_lib:dashy] CRITICAL: Integrity token was wiped!^0')
        end

        -- Verify the security table is still intact
        if not OxDashySecurity or OxDashySecurity.token ~= integrityToken then
            print('^1[ox_lib:dashy] CRITICAL: Security table has been tampered with!^0')
        end

        lastIntegrityCheck = os.time()
    end
end)

-- ── 5. Read-only security global ─────────────────────────────────────
-- Store references that the logger module will use, preventing cheat
-- menus from nil-ing out our functions

local securityData = {
    token = integrityToken,
    verified = true,
    startTime = os.time(),
}

-- Create a proxy table with read-only access
OxDashySecurity = setmetatable({}, {
    __index = securityData,
    __newindex = function(_, key, _)
        print('^1[ox_lib:dashy] ^3WARNING: Attempt to modify OxDashySecurity.' .. key .. ' blocked!^0')
    end,
    __metatable = false, -- Prevent getmetatable from exposing internals
})

print('^2[ox_lib:dashy] ^7Security layer initialized — anti-tamper protections active^0')
