local safeZoneCount = 0
local currentNotify = false

local function HexToRGB(hex)
    hex = hex:gsub("#", "")
    return
        tonumber(hex:sub(1, 2), 16),
        tonumber(hex:sub(3, 4), 16),
        tonumber(hex:sub(5, 6), 16)
end

local function PlayUISound()
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

local function ShowSafezoneNotify()
    if currentNotify then return end
    currentNotify = true

    SendNUIMessage({
        action = 'showSafezone',
        show = true
    })

    PlayUISound()
end

local function HideSafezoneNotify()
    if not currentNotify then return end
    currentNotify = false

    SendNUIMessage({
        action = 'showSafezone',
        show = false
    })

    PlayUISound()
end


CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        for _, zone in pairs(Config.Safezones) do
            local distance = #(playerCoords - zone.coords)

            if distance < zone.radius + 50.0 then
                local r, g, b = HexToRGB(zone.color.hex)
                DrawMarker(
                    28,
                    zone.coords.x, zone.coords.y, zone.coords.z,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    zone.radius, zone.radius, zone.radius,
                    r, g, b, zone.color.a,
                    false, false, 2, false, nil, nil, false
                )
            end
        end
    end
end)

CreateThread(function()
    for _, zone in pairs(Config.Safezones) do
        lib.zones.sphere({
            coords = zone.coords,
            radius = zone.radius,
            debug = false,

            onEnter = function()
                safeZoneCount += 1

                local ped = PlayerPedId()
                local playerId = PlayerId()

                SetEntityInvincible(ped, true)
                SetPlayerInvincible(playerId, true)
                SetPedCanRagdoll(ped, false)
                SetEntityAlpha(ped, 150, false)

                if safeZoneCount == 1 then
                    ShowSafezoneNotify()
                end
            end,

            inside = function()
                local ped = PlayerPedId()
                local playerId = PlayerId()


                DisablePlayerFiring(playerId, true)

                DisableControlAction(0, 24, true)  -- Attack
                DisableControlAction(0, 25, true)  -- Aim + Attack (melee)
                DisableControlAction(0, 58, true)  -- Sniper zoom
                DisableControlAction(0, 263, true) -- Melee attack
                DisableControlAction(0, 264, true) -- Melee attack alt


                for _, player in ipairs(GetActivePlayers()) do
                    local otherPed = GetPlayerPed(player)
                    if otherPed ~= ped then
                        SetEntityNoCollisionEntity(ped, otherPed, false)
                    end
                end

                local vehicles = GetGamePool('CVehicle')
                for _, vehicle in ipairs(vehicles) do
                    SetEntityNoCollisionEntity(ped, vehicle, false)
                end
            end,

            onExit = function()
                safeZoneCount -= 1

                if safeZoneCount <= 0 then
                    safeZoneCount = 0

                    local ped = PlayerPedId()
                    local playerId = PlayerId()

                    SetEntityInvincible(ped, false)
                    SetPlayerInvincible(playerId, false)
                    SetPedCanRagdoll(ped, true)
                    ResetEntityAlpha(ped)

                    -- Re-enable collision with other players
                    for _, player in ipairs(GetActivePlayers()) do
                        local otherPed = GetPlayerPed(player)
                        if otherPed ~= ped then
                            SetEntityNoCollisionEntity(ped, otherPed, true)
                        end
                    end

                    -- Re-enable collision with vehicles
                    local vehicles = GetGamePool('CVehicle')
                    for _, vehicle in ipairs(vehicles) do
                        SetEntityNoCollisionEntity(ped, vehicle, true)
                    end

                    HideSafezoneNotify()
                end
            end
        })
    end
end)