script_name("Damage Informer Remastered")
script_author("impachi")

local imgui = require("imgui")
local encoding = require("encoding")
local sampev = require("lib.samp.events")
local inicfg = require("inicfg")
local imguiAddons = require("imgui_addons")
local ffi = require("ffi")

ffi.cdef[[
    void* GetForegroundWindow();
    int MessageBoxA(void* hWnd, const char* lpText, const char* lpCaption, unsigned int uType);
]]

local user32 = ffi.load("user32")

local config_name = "DamageInformerRemastered"

local config = {
    settings = {
        sounds = false,
        logPosX = 425,
        logPosY = 820,
        incomingLogPosX = 1350,
        incomingLogPosY = 820,
        logs = true,
        hitMarkers = true,
        messageOnLaunch = true,
        hitMarkerOutline = true,
        hitMarkerColor = "0.770,0.770,0.770,1.000",
        logOutline = true,
        logColor = "0.770,0.770,0.770,1.000",
        logsLimit = 3,
        lifeTime = 3,
        logLifeTime = 3,
        killFlashColor = "1.000,1.000,1.000,1.000",
        killFlash = true,
        useMainFont = false,
        logWidth = 500,
        logHeight = 200,
        incomingLogWidth = 500,
        incomingLogHeight = 200,
        fastDeletePlayers = false,
        soundVolume = 100
    },
    stats = {
        kills = 0,
        headshots = 0,
        shots = 0,
        hits = 0,
        openMenu = 0,
        loadings = 0
    }
}

local cfg = inicfg.load(config, config_name)
local config_file = getWorkingDirectory().."/config/DamageInformerRemastered.ini"

if not doesFileExist(getWorkingDirectory().."\\config\\" ..config_name.. ".ini") then
    inicfg.save(cfg, config_name)
end

encoding.default = "CP1251"
imgui.Process = true
u8 = encoding.UTF8

local r, g, b, a = config.settings.hitMarkerColor:match("([^,]+),([^,]+),([^,]+),([^,]+)")
local lr, lg, lb, la = config.settings.logColor:match("([^,]+),([^,]+),([^,]+),([^,]+)")
local kr, kg, kb, ka = config.settings.killFlashColor:match("([^,]+),([^,]+),([^,]+),([^,]+)")

local settings = {
    sounds = imgui.ImBool(config.settings.sounds),
    logs = imgui.ImBool(config.settings.logs),
    hitMarkers = imgui.ImBool(config.settings.hitMarkers),
    hitMarkerOutline = imgui.ImBool(config.settings.hitMarkerOutline),
    logOutline = imgui.ImBool(config.settings.logOutline),
    messageOnLaunch = imgui.ImBool(config.settings.messageOnLaunch),
    hitMarkerColor = imgui.ImFloat4(tonumber(r) or 0.77, tonumber(g) or 0.77, tonumber(b) or 0.77, tonumber(a) or 1.0),
    logColor = imgui.ImFloat4(tonumber(lr) or 0.77, tonumber(lg) or 0.77, tonumber(lb) or 0.77, tonumber(la) or 1.0),
    logsLimit = imgui.ImBuffer(tostring(config.settings.logsLimit), 3),
    lifeTime = imgui.ImBuffer(tostring(config.settings.lifeTime), 3),
    logLifeTime = imgui.ImBuffer(tostring(config.settings.logLifeTime), 3),
    killFlashColor = imgui.ImFloat4(tonumber(kr) or 1.0, tonumber(kg) or 1.0, tonumber(kb) or 1.0, tonumber(ka) or 1.0),
    killFlash = imgui.ImBool(config.settings.killFlash),
    useMainFont = imgui.ImBool(config.settings.useMainFont),
    logWidth = imgui.ImBuffer(tostring(config.settings.logWidth), 10),
    logHeight = imgui.ImBuffer(tostring(config.settings.logHeight), 10),
    incomingLogWidth = imgui.ImBuffer(tostring(config.settings.incomingLogWidth), 10),
    incomingLogHeight = imgui.ImBuffer(tostring(config.settings.incomingLogHeight), 10),
    fastDeletePlayers = imgui.ImBool(config.settings.fastDeletePlayers),
    soundVolume = imgui.ImInt(config.settings.soundVolume or 100),
}

local previewLogs = {}
local previewLastHit = 0
local PREVIEW_INTERVAL = 1

local previewIncomingLogs = {}
local previewIncomingLastHit = 0

local window = imgui.ImBool(false)

local debugWindowElements = imgui.ImBool(false)
local incomingDebugWindowElements = imgui.ImBool(false)

local sw, sh = getScreenResolution()

local damages = {}
local hitLogs = {}
local incomingHitLogs = {}

local incomingLogX = config.settings.incomingLogPosX
local incomingLogY = config.settings.incomingLogPosY
local editIncomingDamage = false
local incomingEditDrag = false
local incomingDragX, incomingDragY = 0, 0

local killFlash = false
local killFlashStart = 0
local KILL_FLASH_DURATION = 0.25

local bell = nil
local killedSound = nil
local headshotSound = nil

local mainFont = nil

local editDamage = false
local logX = config.settings.logPosX
local logY = config.settings.logPosY
local editDrag = false
local dragX, dragY = 0, 0

local LIFE_TIME = config.settings.lifeTime
local LOG_LIFE_TIME = config.settings.logLifeTime

local WEAPON_NAMES = {
    [0] = "Кулаки",
    [1] = "Кастет",
    [2] = "Клюшка",
    [3] = "Дубинка",
    [4] = "Нож",
    [5] = "Бита",
    [6] = "Лопата",
    [7] = "Кий",
    [8] = "Катана",
    [9] = "Бензопила",
    [10] = "Дилдо",
    [11] = "Вибратор",
    [12] = "Длинный вибратор",
    [13] = "Белый дилдо",
    [14] = "Цветы",
    [15] = "Трость",
    [16] = "Граната",
    [17] = "Слезоточивый газ",
    [18] = "Коктейль Молотова",

    [22] = "Пистолет 9 мм",
    [23] = "Пистолет с глушителем",
    [24] = "Desert Eagle",
    [25] = "Дробовик",
    [26] = "Обрез",
    [27] = "Боевой дробовик", 
    [28] = "MAC-10",
    [29] = "MP5", 
    [30] = "AK-47", 
    [31] = "M4", 
    [32] = "Tec-9",
    [33] = "Винтовка", 
    [34] = "Снайперская винтовка", 

    [35] = "РПГ",
    [36] = "Ракетница", 
    [37] = "Огнемёт", 
    [38] = "Миниган",

    [39] = "Взрывчатка", 
    [40] = "Детонатор", 
    [41] = "Баллончик с краской",
    [42] = "Огнетушитель", 

    [43] = "Фотоаппарат",
    [44] = "Прибор ночного видения", 
    [45] = "Тепловизор", 
    [46] = "Парашют",

    [49] = "Автомобиль",
    [50] = "Лопасти вертолёта",
    [51] = "Взрыв",
    [53] = "Утопление",
    [54] = "Падение"
}

function addDamageLog(logs, playerId, name, damage, weaponName, afk, bodypart)
    local now = os.clock()
    local isHeadshot = bodypart == 9

    for i = 1, #logs do
        if logs[i].playerId == playerId then
            logs[i].damage = logs[i].damage + damage
            logs[i].name = name
            logs[i].weapon = weaponName
            logs[i].afk = afk
            logs[i].created = now

            if isHeadshot then
                logs[i].headshot = true
            end

            if i ~= 1 then
                local log = logs[i]
                table.remove(logs, i)
                table.insert(logs, 1, log)
            end

            return
        end
    end

    table.insert(logs, 1, {
        playerId = playerId,
        name = name,
        damage = damage,
        weapon = weaponName,
        afk = afk,
        headshot = isHeadshot,
        killed = false,
        created = now
    })

    while #logs > config.settings.logsLimit do
        table.remove(logs)
    end
end

function main()
    repeat wait(0) until isSampAvailable()

    if config.settings.sounds then
        local resourcePath = getWorkingDirectory() .. "\\resource"

        local bellPath = resourcePath .. "\\bell.mp3"
        local headshotPath = resourcePath .. "\\headshot.mp3"
        local killedPath = resourcePath .. "\\killed.mp3"

        if doesFileExist(bellPath) then
            bell = loadAudioStream(bellPath)
        else
            sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Не найден файл {F472B6}bell.mp3{FFFFFF}. Звук при попадании не будет воспроизводиться.", -1)
        end

        if doesFileExist(headshotPath) then
            headshotSound = loadAudioStream(headshotPath)
        else
            sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Не найден файл {F472B6}headshot.mp3{FFFFFF}. Звук при хедшоте не будет воспроизводиться.", -1)
        end

        if doesFileExist(killedPath) then
            killedSound = loadAudioStream(killedPath)
        else
            sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Не найден файл {F472B6}killed.mp3{FFFFFF}. Звук при убийстве не будет воспроизводиться.", -1)
        end
    end

    imgui.ShowCursor = false

    if config.settings.messageOnLaunch then
        sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Скрипт загружен, введите команду {F472B6}/informer {FFFFFF}для открытия меню.", -1)
    end

    config.stats.loadings = config.stats.loadings + 1
    inicfg.save(config, config_name)

    sampRegisterChatCommand("informer", function()
        window.v = not window.v
        imgui.ShowCursor = window.v

        config.stats.openMenu = config.stats.openMenu + 1
        inicfg.save(config, config_name)
    end)

    while true do
        wait(0)

        if config.settings.fastDeletePlayers then
            for _, ped in pairs(getAllChars()) do
                if ped ~= PLAYER_PED and doesCharExist(ped) then
                    if isCharDead(ped) then
                        deleteChar(ped)
                    end
                end
            end
        end

        if config.settings.killFlash then
            renderKillFlash()
        end

        local now = os.clock()

        for i = #damages, 1, -1 do
            if now - damages[i].created >= LIFE_TIME then
                table.remove(damages, i)
            end
        end

        for i = #hitLogs, 1, -1 do
            if now - hitLogs[i].created >= LOG_LIFE_TIME then
                table.remove(hitLogs, i)
            end
        end

        for i = #incomingHitLogs, 1, -1 do
            if now - incomingHitLogs[i].created >= LOG_LIFE_TIME then
                table.remove(incomingHitLogs, i)
            end
        end
    end
end

function sampev.onSendGiveDamage(playerId, damage, weapon, bodypart)
    local result, ped = sampGetCharHandleBySampPlayerId(playerId)
    local afk = sampIsPlayerPaused(playerId)

    if result and doesCharExist(ped) then
        local x, y, z = getCharCoordinates(ped)
        local name = sampGetPlayerNickname(playerId):gsub("_", " ")
        local weaponName = WEAPON_NAMES[weapon] or tostring(weapon)

        table.insert(damages, {
            damage = damage,
            x = x,
            y = y,
            z = z + 0.5,
            created = os.clock()
        })

        addDamageLog(
            hitLogs,
            playerId,
            name,
            damage,
            weaponName,
            afk,
            bodypart
        )
    end

    if bodypart == 9 then
        config.stats.headshots = config.stats.headshots + 1
        inicfg.save(config, config_name)
    else
        config.stats.hits = config.stats.hits + 1
        inicfg.save(config, config_name)
    end

    if config.settings.sounds then
        if bodypart == 9 then
            if headshotSound ~= nil then
                local volume = (config.settings.soundVolume or 100) / 100

                setAudioStreamVolume(bell, volume)
                setAudioStreamState(headshotSound, 1)
            end
        else
            if bell ~= nil then
                local volume = (config.settings.soundVolume or 100) / 100

                setAudioStreamVolume(bell, volume)
                setAudioStreamState(bell, 1)
            end
        end
    end
end

function sampev.onSendTakeDamage(playerId, damage, weapon, bodypart)
    local name = "Неизвестно"

    if sampIsPlayerConnected(playerId) then
        local nickname = sampGetPlayerNickname(playerId)

        if nickname then
            name = nickname:gsub("_", " ")
        end
    end

    addDamageLog(
        incomingHitLogs,
        playerId,
        name,
        damage,
        WEAPON_NAMES[weapon] or tostring(weapon),
        false,
        bodypart
    )
end

function sampev.onPlayerDeathNotification(killerId, killedId, reason)
    local myPlayerId = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))

    if killerId == myPlayerId then
        startKillFlash()

        config.stats.kills = config.stats.kills + 1
        inicfg.save(config, config_name)

        if config.settings.sounds and killedSound ~= nil then
            local volume = (config.settings.soundVolume or 100) / 100

            setAudioStreamVolume(bell, volume)
            setAudioStreamState(killedSound, 1)
        end

        for i = 1, #hitLogs do
            if hitLogs[i].playerId == killedId then
                hitLogs[i].killed = true
                break
            end
        end
    end
end

function sampev.onSendBulletSync(data)
    config.stats.shots = config.stats.shots + 1
    inicfg.save(config, config_name)
end

function startKillFlash()
    killFlash = true
    killFlashStart = os.clock()
end

function renderKillFlash()
    if not killFlash then
        return
    end

    local progress = (os.clock() - killFlashStart) / KILL_FLASH_DURATION

    if progress >= 1 then
        killFlash = false
        return
    end

    local alpha = math.floor((1.0 - progress) * 100 * settings.killFlashColor.v[4])

    local r = math.floor(settings.killFlashColor.v[1] * 255)
    local g = math.floor(settings.killFlashColor.v[2] * 255)
    local b = math.floor(settings.killFlashColor.v[3] * 255)

    local color = bit.bor(
        bit.lshift(alpha, 24),
        bit.lshift(r, 16),
        bit.lshift(g, 8),
        b
    )

    renderDrawBox(0, 0, sw, sh, color)
end

function imgui.BeforeDrawFrame()
    if mainFont == nil and doesFileExist(getWorkingDirectory().. "\\resource\\mainFont.ttf") then
        mainFont = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory().. "\\resource\\mainFont.ttf", 20.0, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    end

    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2

    style.WindowPadding = ImVec2(14, 12)
    style.WindowRounding = 14.0
    style.FramePadding = ImVec2(10, 7)
    style.FrameRounding = 11.0
    style.ItemSpacing = ImVec2(10, 6)
    style.ItemInnerSpacing = ImVec2(6, 5)
    style.TouchExtraPadding = ImVec2(0, 0)
    style.IndentSpacing = 10.0
    style.ScrollbarSize = 12.0
    style.ScrollbarRounding = 16.0
    style.GrabMinSize = 20.0
    style.GrabRounding = 20.0
    style.ChildWindowRounding = 14.0

    style.WindowTitleAlign = ImVec2(0.5, 0.5)

    colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 1.0)
    colors[clr.ChildWindowBg]         = ImVec4(0.06, 0.06, 0.07, 1.00)
    colors[clr.PopupBg]               = ImVec4(0.08, 0.08, 0.09, 0.98)
    colors[clr.ComboBg]               = colors[clr.PopupBg]
    colors[clr.Text]                  = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.TextDisabled]          = ImVec4(0.55, 0.55, 0.55, 1.00)
    colors[clr.TextSelectedBg]        = ImVec4(0.20, 0.20, 0.22, 0.60)
    colors[clr.FrameBg]               = ImVec4(0.10, 0.10, 0.11, 1.00)
    colors[clr.FrameBgHovered]        = ImVec4(0.14, 0.14, 0.16, 1.00)
    colors[clr.FrameBgActive]         = ImVec4(0.18, 0.18, 0.20, 1.00)
    colors[clr.Button]                = ImVec4(0.10, 0.10, 0.11, 1.00)
    colors[clr.ButtonHovered]         = ImVec4(0.16, 0.16, 0.18, 1.00)
    colors[clr.ButtonActive]          = ImVec4(0.22, 0.22, 0.24, 1.00)
    colors[clr.CloseButton] = ImVec4(0.10, 0.10, 0.11, 0.00)
    colors[clr.CloseButtonHovered] = ImVec4(0.16, 0.16, 0.18, 0.00)
    colors[clr.CloseButtonActive] = ImVec4(0.22, 0.22, 0.24, 0.00)
    colors[clr.TitleBg]               = ImVec4(0.05, 0.05, 0.06, 1.00)
    colors[clr.TitleBgActive]         = ImVec4(0.08, 0.08, 0.10, 1.00)
    colors[clr.TitleBgCollapsed]      = ImVec4(0.03, 0.03, 0.03, 0.80)
    colors[clr.Border]                = ImVec4(0.18, 0.18, 0.20, 0.60)
    colors[clr.BorderShadow]          = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[clr.CheckMark]             = ImVec4(0.90, 0.90, 0.90, 1.00)
    colors[clr.SliderGrab] = ImVec4(0.25, 0.25, 0.27, 1.00)
    colors[clr.SliderGrabActive] = ImVec4(0.35, 0.35, 0.38, 1.00)
    colors[clr.Header]                = ImVec4(0.10, 0.10, 0.11, 1.00)
    colors[clr.HeaderHovered]         = ImVec4(0.16, 0.16, 0.18, 1.00)
    colors[clr.HeaderActive]          = ImVec4(0.22, 0.22, 0.24, 1.00)
    colors[clr.ScrollbarBg]           = ImVec4(0.05, 0.05, 0.06, 1.00)
    colors[clr.ScrollbarGrab]         = ImVec4(0.20, 0.20, 0.22, 1.00)
    colors[clr.ScrollbarGrabHovered]  = ImVec4(0.28, 0.28, 0.30, 1.00)
    colors[clr.ScrollbarGrabActive]   = ImVec4(0.35, 0.35, 0.38, 1.00)
    colors[clr.Separator]             = ImVec4(0.18, 0.18, 0.20, 1.00)
    colors[clr.SeparatorHovered]      = ImVec4(0.25, 0.25, 0.27, 1.00)
    colors[clr.SeparatorActive]       = ImVec4(0.30, 0.30, 0.33, 1.00)
    colors[clr.ResizeGrip]            = ImVec4(0.18, 0.18, 0.20, 0.50)
    colors[clr.ResizeGripHovered]     = ImVec4(0.25, 0.25, 0.28, 0.80)
    colors[clr.ResizeGripActive]      = ImVec4(0.30, 0.30, 0.33, 1.00)
    colors[clr.PlotLines]             = ImVec4(0.60, 0.60, 0.60, 1.00)
    colors[clr.PlotLinesHovered]      = ImVec4(0.90, 0.90, 0.90, 1.00)
    colors[clr.PlotHistogram]         = ImVec4(0.50, 0.50, 0.52, 1.00)
    colors[clr.PlotHistogramHovered]  = ImVec4(0.70, 0.70, 0.72, 1.00)
    colors[clr.ModalWindowDarkening]  = ImVec4(0.00, 0.00, 0.00, 0.60)
end

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowWidth()/2-imgui.CalcTextSize(u8(text)).x/2)
    imgui.Text(text)
end

function imgui.OnDrawFrame()
    if window.v then
        local previewNow = os.clock()

        local logsLimit = tonumber(config.settings.logsLimit) or 3

        while #previewLogs > logsLimit do
            table.remove(previewLogs)
        end

        while #previewIncomingLogs > logsLimit do
            table.remove(previewIncomingLogs)
        end

        if previewNow - previewIncomingLastHit >= PREVIEW_INTERVAL then
            previewIncomingLastHit = previewNow

            table.insert(previewIncomingLogs, 1, {
                name = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))):gsub("_", " "),
                damage = math.random(1, 100),
                weapon = WEAPON_NAMES[math.random(0, 46)] or "Неизвестно",
                afk = false,
                created = previewNow
            })
        end

        for i = #previewIncomingLogs, 1, -1 do
            if previewNow - previewIncomingLogs[i].created >= LOG_LIFE_TIME then
                table.remove(previewIncomingLogs, i)
            end
        end

        if previewNow - previewLastHit >= PREVIEW_INTERVAL then
            previewLastHit = previewNow

            table.insert(previewLogs, 1, {
                name = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))):gsub("_", " "),
                damage = math.random(1, 100),
                weapon = WEAPON_NAMES[math.random(0, 46)] or "Неизвестно",
                afk = math.random(0, 1) == 1,
                created = previewNow
            })
        end

        for i = #previewLogs, 1, -1 do
            if previewNow - previewLogs[i].created >= LOG_LIFE_TIME then
                table.remove(previewLogs, i)
            end
        end

        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(470, 450), imgui.Cond.Always)
        imgui.Begin(u8("Damage Informer Remastered"), window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse)

        imgui.SetWindowFontScale(1.3)

        if mainFont and config.settings.useMainFont then
            imgui.PushFont(mainFont)
            imgui.Text(u8("Настройки"))
            imgui.PopFont()
        else
            imgui.Text(u8("Настройки"))
        end

        imgui.SetWindowFontScale(1.0)

        imgui.BeginChild("Settings", imgui.ImVec2(443, 372), true, imgui.WindowFlags.NoScrollbar)
            imgui.Text(u8("Звуки"))

            imgui.SameLine()

            if imguiAddons.ToggleButton(u8"##settings.sounds", settings.sounds) then
                if settings.sounds.v then
                    if doesFileExist(getWorkingDirectory().. "\\resource\\bell.mp3") then
                        config.settings.sounds = true
                        inicfg.save(config, config_name)
                    else
                        settings.sounds.v = false
                        config.settings.sounds = false
                        inicfg.save(config, config_name)
                        imgui.OpenPopup(u8("Отсутствие нужных файлов - звуки"))
                    end
                else
                    config.settings.sounds = false
                    inicfg.save(config, config_name)
                end
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("При попадании, попадании в голову, и при убийстве будут воспроизводиться звуки."))
                imgui.EndTooltip()
            end

            if config.settings.sounds then
                imgui.SameLine()
                
                if doesFileExist(getWorkingDirectory().. "\\resource\\bell.mp3") then
                    if imgui.Button(u8("Звук 1")) and bell ~= nil then
                        local volume = (config.settings.soundVolume or 100) / 100

                        setAudioStreamVolume(bell, volume)
                        setAudioStreamState(bell, 1)
                    end

                    if imgui.IsItemHovered() then
                        imgui.BeginTooltip()
                            imgui.Text(u8("Звук попадания"))
                        imgui.EndTooltip()
                    end

                    imgui.SameLine()
                end

                if doesFileExist(getWorkingDirectory().. "\\resource\\headshot.mp3") then
                    if imgui.Button(u8("Звук 2")) and headshotSound ~= nil then
                        local volume = (config.settings.soundVolume or 100) / 100

                        setAudioStreamVolume(bell, volume)
                        setAudioStreamState(headshotSound, 1)
                    end

                    if imgui.IsItemHovered() then
                        imgui.BeginTooltip()
                            imgui.Text(u8("Звук попадания по голове"))
                        imgui.EndTooltip()
                    end

                    imgui.SameLine()
                end

                if doesFileExist(getWorkingDirectory().. "\\resource\\killed.mp3") then
                    if imgui.Button(u8("Звук 3")) and killedSound ~= nil then
                        local volume = (config.settings.soundVolume or 100) / 100

                        setAudioStreamVolume(bell, volume)
                        setAudioStreamState(killedSound, 1)
                    end

                    if imgui.IsItemHovered() then
                        imgui.BeginTooltip()
                            imgui.Text(u8("Звук убийства"))
                        imgui.EndTooltip()
                    end
                end

                imgui.Text(u8("Громкость"))

                imgui.SameLine()

                imgui.PushItemWidth(205)

                if imgui.SliderInt(
                    u8("##settings.soundVolume"),
                    settings.soundVolume,
                    0,
                    100,
                    ""
                ) then
                    config.settings.soundVolume = settings.soundVolume.v
                    inicfg.save(config, config_name)
                end

                imgui.PopItemWidth()
            end

            imgui.Text(u8("Сообщение в чат при старте скрипта"))

            imgui.SameLine()

            if imguiAddons.ToggleButton(u8"##settings.messageOnLaunch", settings.messageOnLaunch) then
                config.settings.messageOnLaunch = settings.messageOnLaunch.v
                inicfg.save(cfg, config_name)
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("Сообщение в чат об успешной загрузке скрипта при его старте."))
                imgui.EndTooltip()
            end

            imgui.Text(u8("Моментальное удаление игроков"))

            imgui.SameLine()

            if imguiAddons.ToggleButton(u8"##settings.fastDeletePlayers", settings.fastDeletePlayers) then
                config.settings.fastDeletePlayers = settings.fastDeletePlayers.v
                inicfg.save(cfg, config_name)
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("После смерти, игроки сразу же удаляются, а не лежат несколько секунд на полу."))
                imgui.EndTooltip()
            end

            imgui.Text(u8("Другой шрифт в элементах интерфейса"))

            imgui.SameLine()

            if imguiAddons.ToggleButton(u8"##settings.useMainFont", settings.useMainFont) then
                if settings.useMainFont.v then
                    if doesFileExist(getWorkingDirectory().. "\\resource\\mainFont.ttf") then
                        config.settings.useMainFont = true
                        inicfg.save(config, config_name)
                    else
                        settings.useMainFont.v = false
                        config.settings.useMainFont = false
                        inicfg.save(config, config_name)
                        imgui.OpenPopup(u8("Отсутствие нужного файла - шрифт"))
                    end
                else
                    config.settings.useMainFont = false
                    inicfg.save(config, config_name)
                end
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("В логах, хит-маркерах будет использоваться другой шрифт."))
                imgui.EndTooltip()
            end

            imgui.Text(u8("Вспышка при убийстве"))

            imgui.SameLine()

            if imguiAddons.ToggleButton(u8"##settings.killFlash", settings.killFlash) then
                config.settings.killFlash = settings.killFlash.v
                inicfg.save(cfg, config_name)
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("Когда вы убьёте кого-нибудь, на экране появится вспышка."))
                imgui.EndTooltip()
            end

            if config.settings.killFlash then
                imgui.Text(u8("Цвет вспышки при убийстве"))

                imgui.SameLine()

                if imgui.ColorEdit4(u8("##settings.killFlashColor"), settings.killFlashColor, imgui.ColorEditFlags.NoInputs) then
                    config.settings.killFlashColor = string.format("%.3f,%.3f,%.3f,%.3f", settings.killFlashColor.v[1], settings.killFlashColor.v[2], settings.killFlashColor.v[3], settings.killFlashColor.v[4])
                    inicfg.save(config, config_name)
                end

                imgui.SameLine()

                if imgui.Button(u8("Вызвать")) then
                    startKillFlash()
                end

                imgui.SameLine()

                if imgui.Button(u8("Сбросить##settings.killFlashColor")) then
                    settings.killFlashColor.v[1] = 1.0
                    settings.killFlashColor.v[2] = 1.0
                    settings.killFlashColor.v[3] = 1.0
                    settings.killFlashColor.v[4] = 1.0
                    config.settings.killFlashColor = "1.000,1.000,1.000,1.000"
                    inicfg.save(config, config_name)
                end
            end

            imgui.Text(u8("Хит-маркеры"))

            imgui.SameLine()

            if imguiAddons.ToggleButton(u8"##settings.hitMarkers", settings.hitMarkers) then
                config.settings.hitMarkers = settings.hitMarkers.v
                inicfg.save(cfg, config_name)
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("Создавать ли текст на месте попадания в формате -Число"))
                imgui.EndTooltip()
            end

            if config.settings.hitMarkers then
                imgui.Text(u8("Цвет хит-маркеров"))

                imgui.SameLine()

                if imgui.ColorEdit4(u8("##settings.hitMarkerColor"), settings.hitMarkerColor, imgui.ColorEditFlags.NoInputs) then
                    config.settings.hitMarkerColor = string.format("%.3f,%.3f,%.3f,%.3f", settings.hitMarkerColor.v[1], settings.hitMarkerColor.v[2], settings.hitMarkerColor.v[3], settings.hitMarkerColor.v[4])
                    inicfg.save(config, config_name)
                end

                imgui.SameLine()

                if imgui.Button(u8("Сбросить##settings.hitMarkerColor")) then
                    settings.hitMarkerColor.v[1] = 0.77
                    settings.hitMarkerColor.v[2] = 0.77
                    settings.hitMarkerColor.v[3] = 0.77
                    settings.hitMarkerColor.v[4] = 1.0
                    config.settings.hitMarkerColor = "0.770,0.770,0.770,1.000"
                    inicfg.save(config, config_name)
                end

                imgui.Text(u8("Обводка хит-маркеров"))

                imgui.SameLine()

                if imguiAddons.ToggleButton(u8"##settings.hitMarkerOutline", settings.hitMarkerOutline) then
                    config.settings.hitMarkerOutline = settings.hitMarkerOutline.v
                    inicfg.save(config, config_name)
                end

                imgui.Text(u8("Время показа хит-маркеров"))

                imgui.SameLine()

                imgui.PushItemWidth(27)
                    if imgui.InputText(u8'##settings.lifeTime', settings.lifeTime, imgui.InputTextFlags.AutoSelectAll) then
                        config.settings.lifeTime = tonumber(settings.lifeTime.v) or 3
                        LIFE_TIME = config.settings.lifeTime
                        inicfg.save(config, config_name)
                    end
                imgui.PopItemWidth()
            end

            imgui.Text(u8("Логи"))

            imgui.SameLine()

            if imguiAddons.ToggleButton(u8"##settings.logs", settings.logs) then
                config.settings.logs = settings.logs.v
                inicfg.save(cfg, config_name)
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("Вывод попаданий на указанную позицию в формате Имя - Урон - Оружие"))
                imgui.EndTooltip()
            end

            if config.settings.logs then
                imgui.Text(u8("Цвет логов"))

                imgui.SameLine()

                if imgui.ColorEdit4(u8("##settings.logColor"), settings.logColor, imgui.ColorEditFlags.NoInputs) then
                    config.settings.logColor = string.format("%.3f,%.3f,%.3f,%.3f", settings.logColor.v[1], settings.logColor.v[2], settings.logColor.v[3], settings.logColor.v[4])
                    inicfg.save(config, config_name)
                end

                imgui.SameLine()

                if imgui.Button(u8("Сбросить##settings.logColor")) then
                    settings.logColor.v[1] = 0.77
                    settings.logColor.v[2] = 0.77
                    settings.logColor.v[3] = 0.77
                    settings.logColor.v[4] = 1.0
                    config.settings.logColor = "0.770,0.770,0.770,1.000"
                    inicfg.save(config, config_name)
                end

                imgui.Text(u8("Обводка логов"))

                imgui.SameLine()

                if imguiAddons.ToggleButton(u8"##settings.logOutline", settings.logOutline) then
                    config.settings.logOutline = settings.logOutline.v
                    inicfg.save(config, config_name)
                end

                imgui.Text(u8("Лимит строк логов"))

                imgui.SameLine()

                imgui.PushItemWidth(27)
                    if imgui.InputText(u8'##settings.logsLimit', settings.logsLimit, imgui.InputTextFlags.AutoSelectAll) then
                        config.settings.logsLimit = tonumber(settings.logsLimit.v) or 3
                        inicfg.save(config, config_name)
                    end
                imgui.PopItemWidth()

                imgui.Text(u8("Время показа логов"))

                imgui.SameLine()

                imgui.PushItemWidth(27)
                    if imgui.InputText(u8'##settings.logLifeTime', settings.logLifeTime, imgui.InputTextFlags.AutoSelectAll) then
                        config.settings.logLifeTime = tonumber(settings.logLifeTime.v) or 3
                        LOG_LIFE_TIME = config.settings.logLifeTime
                        inicfg.save(config, config_name)
                    end
                imgui.PopItemWidth()

                if imgui.Button(u8("Редактировать позицию логов"), imgui.ImVec2(419, 35)) then
                    lua_thread.create(function()
                        window.v = false
                        wait(50)
                        editDamage = true
                        debugWindowElements.v = true
                        imgui.ShowCursor = editDamage
                    end)
                end

                if imgui.Button(u8("Редактировать позицию входящих логов"), imgui.ImVec2(419, 35)) then
                    lua_thread.create(function()
                        window.v = false
                        wait(50)
                        editIncomingDamage = true
                        incomingDebugWindowElements.v = true
                        imgui.ShowCursor = editIncomingDamage
                    end)
                end
            end

            if imgui.Button(u8("Статистика"), imgui.ImVec2(419, 35)) then
                imgui.OpenPopup(u8("Статистика"))
            end

            if imgui.Button(u8("Перезагрузить"), imgui.ImVec2(132, 35)) then
                lua_thread.create(function()
                    window.v = false
                    imgui.ShowCursor = false
                    wait(50)
                    thisScript():reload()
                end)
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("Кнопка перезагрузит скрипт"))
                imgui.EndTooltip()
            end

            imgui.SameLine()

            if imgui.Button(u8("Выгрузить"), imgui.ImVec2(133, 35)) then
                lua_thread.create(function()
                    window.v = false
                    imgui.ShowCursor = false
                    wait(50)
                    thisScript():unload()
                end)
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("Кнопка выгрузит скрипт из памяти. Используйте для полного отключения или замены bell.mp3"))
                imgui.EndTooltip()
            end

            imgui.SameLine()

            if imgui.Button(u8("Сбросить"), imgui.ImVec2(132, 35)) then
                lua_thread.create(function()
                    wait(50)
                    os.remove(config_file)
                    thisScript():reload()
                end)
            end

            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                    imgui.Text(u8("Кнопка сбросит ваши настройки"))
                imgui.EndTooltip()
            end

            imgui.Dummy(imgui.ImVec2(5, 0))

            if imgui.BeginPopupModal(u8("Отсутствие нужных файлов - звуки"), nil, imgui.WindowFlags.AlwaysAutoResize) then
                local resourcePath = getWorkingDirectory() .. "\\resource"

                local sounds = {
                    {
                        name = "bell.mp3",
                        url = "https://github.com/impachi9-rgb/damageInformerSound/raw/refs/heads/main/bell.mp3"
                    },
                    {
                        name = "headshot.mp3",
                        url = "https://github.com/impachi9-rgb/damageInformerSound/raw/refs/heads/main/headshot.mp3"
                    },
                    {
                        name = "killed.mp3",
                        url = "https://github.com/impachi9-rgb/damageInformerSound/raw/refs/heads/main/killed.mp3"
                    }
                }

                imgui.Text(u8("Мы не смогли найти необходимые для работы функции"))
                imgui.Text(u8("Звуковые файлы. Вы можете скачать их прямо здесь."))

                imgui.Dummy(imgui.ImVec2(5, 0))

                for _, sound in ipairs(sounds) do
                    local soundPath = resourcePath .. "\\" .. sound.name

                    if not doesFileExist(soundPath) then
                        imgui.Text(u8("• " .. sound.name))
                    end
                end

                imgui.Dummy(imgui.ImVec2(5, 0))

                if imgui.Button(u8("Скачать файлы"), imgui.ImVec2(210, 35)) then
                    if not doesDirectoryExist(resourcePath) then
                        createDirectory(resourcePath)
                    end

                    local missing = {}

                    for _, sound in ipairs(sounds) do
                        local soundPath = resourcePath .. "\\" .. sound.name

                        if not doesFileExist(soundPath) then
                            table.insert(missing, {
                                name = sound.name,
                                url = sound.url,
                                path = soundPath
                            })
                        end
                    end

                    if #missing > 0 then
                        local completed = 0

                        for _, sound in ipairs(missing) do
                            downloadUrlToFile(sound.url, sound.path, function(id, status, p1, p2)
                                if status == 6 and doesFileExist(sound.path) then
                                    completed = completed + 1

                                    if completed == #missing then
                                        lua_thread.create(function()
                                            sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Все необходимые звуковые файлы успешно скачаны. Перезагружаемся...", -1)
                                            window.v = false
                                            imgui.ShowCursor = false
                                            wait(200)
                                            thisScript():reload()
                                        end)
                                    end
                                end
                            end)
                        end
                    else
                        thisScript():reload()
                    end
                end

                imgui.SameLine()

                if imgui.Button(u8("Закрыть"), imgui.ImVec2(210, 35)) then
                    imgui.CloseCurrentPopup()
                end

                imgui.EndPopup()
            end

            if imgui.BeginPopupModal(u8("Отсутствие нужного файла - шрифт"), nil, imgui.WindowFlags.AlwaysAutoResize) then
                imgui.Text(u8("Мы не смогли найти нужный для работы этой функции файл - mainFont.ttf."))
                imgui.Text(u8("Обратите внимание! Вам нужно будет перезайти в игру после скачивания."))
                imgui.Text(u8("Вы можете скачать его прямо здесь. Просто нажмите на кнопку ниже."))

                imgui.Dummy(imgui.ImVec2(5, 0))

                if imgui.Button(u8("Скачать файл"), imgui.ImVec2(220, 35)) then
                    local resourcePath = getWorkingDirectory() .. "\\resource"
                    local fontPath = resourcePath .. "\\mainFont.ttf"

                    if not doesDirectoryExist(resourcePath) then
                        createDirectory(resourcePath)
                    end

                    downloadUrlToFile("https://github.com/impachi9-rgb/damageInformerSound/raw/refs/heads/main/mainFont.ttf", fontPath, function(id, status, p1, p2)
                        if status == 6 and doesFileExist(fontPath) then
                            lua_thread.create(function()
                                sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Файл {F472B6}mainFont.ttf{FFFFFF} успешно скачан. Перезайдите в игру...", -1)
                                local gtaWindow = user32.GetForegroundWindow()
                                user32.MessageBoxA(gtaWindow,"Файл mainFont.ttf успешно скачан и установлен.\nПерезайдите в игру после чего снова активируйте функцию, это нужно для корректной загрузки шрифта.", "Damage Informer Remastered by impachi", 0)
                                os.exit(0)
                            end)
                        end
                    end)
                end

                imgui.SameLine()

                if imgui.Button(u8("Закрыть"), imgui.ImVec2(220, 35)) then
                    imgui.CloseCurrentPopup()
                end

                imgui.EndPopup()
            end

            if imgui.BeginPopupModal(u8("Статистика"), nil, imgui.WindowFlags.AlwaysAutoResize) then
                imgui.Text(u8("Всего запусков скрипта: " ..config.stats.loadings))
                imgui.Text(u8("Всего открытий меню: " ..config.stats.openMenu))

                imgui.Dummy(imgui.ImVec2(0, 5))

                imgui.Text(u8("Всего попаданий: " ..config.stats.hits))
                imgui.Text(u8("Всего выстрелов: " ..config.stats.shots))
                imgui.Text(u8("Всего выстрелов в голову: " ..config.stats.headshots))
                imgui.Text(u8("Всего убийств: " ..config.stats.kills))

                imgui.Dummy(imgui.ImVec2(0, 5))

                if imgui.Button(u8("Закрыть"), imgui.ImVec2(300, 50)) then
                    imgui.CloseCurrentPopup()
                end

                imgui.EndPopup()
            end
        imgui.EndChild()

        if not window.v then imgui.ShowCursor = false end
        imgui.End()

        if config.settings.hitMarkers then
            local previewX, previewY = sw / 2 - 350, sh / 2

            imgui.SetNextWindowPos(imgui.ImVec2(previewX, previewY), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
            imgui.SetNextWindowSize(imgui.ImVec2(100, 35), imgui.Cond.Always)
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))

            imgui.Begin("##previewDamage", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoScrollbar)

            imgui.SetWindowFontScale(1.3)

            local text = "-50"
            local drawList = imgui.GetWindowDrawList()
            local pos = imgui.GetCursorScreenPos()

            local shadow = imgui.GetColorU32(imgui.ImVec4(0, 0, 0, 0.45))
            local outline = imgui.GetColorU32(imgui.ImVec4(0, 0, 0, 1.0))
            local textColor = imgui.GetColorU32(imgui.ImVec4(settings.hitMarkerColor.v[1], settings.hitMarkerColor.v[2], settings.hitMarkerColor.v[3], 1.0))

            if mainFont and config.settings.useMainFont then
                imgui.PushFont(mainFont)
                drawList:AddText(imgui.ImVec2(pos.x + 2, pos.y + 2), shadow, text)
                imgui.PopFont()
            else
                drawList:AddText(imgui.ImVec2(pos.x + 2, pos.y + 2), shadow, text)
            end

            if settings.hitMarkerOutline.v then
                for _, offset in ipairs({{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}}) do
                    if mainFont and config.settings.useMainFont then
                        imgui.PushFont(mainFont)
                        drawList:AddText(imgui.ImVec2(pos.x + offset[1], pos.y + offset[2]), outline, text)
                        imgui.PopFont()
                    else
                        drawList:AddText(imgui.ImVec2(pos.x + offset[1], pos.y + offset[2]), outline, text)
                    end
                end
            end

            if mainFont and config.settings.useMainFont then
                imgui.PushFont(mainFont)
                drawList:AddText(pos, textColor, text)
                imgui.PopFont()
            else
                drawList:AddText(pos, textColor, text)
            end

            imgui.End()
            imgui.PopStyleColor()
        end

        if config.settings.logs then
            imgui.SetNextWindowPos(imgui.ImVec2(logX, logY), imgui.Cond.Always)
            imgui.SetNextWindowSize(imgui.ImVec2(tonumber(settings.logWidth.v) or 500, tonumber(settings.logHeight.v) or 200), imgui.Cond.Always)
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))

            imgui.Begin("##previewDamageLog", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoScrollbar)

            imgui.SetWindowFontScale(1.3)

            local drawList = imgui.GetWindowDrawList()
            local pos = imgui.GetCursorScreenPos()

            for i = 1, #previewLogs do
                local log = previewLogs[i]
                local progress = (previewNow - log.created) / LOG_LIFE_TIME
                local alpha = 1.0 - progress

                if alpha < 0 then
                    alpha = 0
                end

                local prefix = log.afk and "[AFK] " or ""
                local prefix = log.afk and "[AFK] " or ""
                local headshot = log.headshot and " - HEADSHOT" or ""
                local killed = log.killed and " - KILLED" or ""

                local text = string.format(
                    "%s%s - %.0f - %s%s%s",
                    prefix,
                    log.name,
                    log.damage,
                    log.weapon,
                    headshot,
                    killed
                )
                local textPos = imgui.ImVec2(pos.x, pos.y + ((i - 1) * 19))

                local outline = imgui.GetColorU32(imgui.ImVec4(0, 0, 0, alpha))
                local shadow = imgui.GetColorU32(imgui.ImVec4(0, 0, 0, alpha * 0.5))
                local color = imgui.GetColorU32(imgui.ImVec4(
                    settings.logColor.v[1],
                    settings.logColor.v[2],
                    settings.logColor.v[3],
                    alpha
                ))

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(
                        imgui.ImVec2(textPos.x + 2, textPos.y + 2),
                        shadow,
                        u8(text)
                    )
                    imgui.PopFont()
                else
                    drawList:AddText(
                        imgui.ImVec2(textPos.x + 2, textPos.y + 2),
                        shadow,
                        u8(text)
                    )
                end

                if settings.logOutline.v then
                    for _, offset in ipairs({
                        {-1, -1},
                        {0, -1},
                        {1, -1},
                        {-1, 0},
                        {1, 0},
                        {-1, 1},
                        {0, 1},
                        {1, 1}
                    }) do
                        if mainFont and config.settings.useMainFont then
                            imgui.PushFont(mainFont)
                            drawList:AddText(
                                imgui.ImVec2(
                                    textPos.x + offset[1],
                                    textPos.y + offset[2]
                                ),
                                outline,
                                u8(text)
                            )
                            imgui.PopFont()
                        else
                            drawList:AddText(
                                imgui.ImVec2(
                                    textPos.x + offset[1],
                                    textPos.y + offset[2]
                                ),
                                outline,
                                u8(text)
                            )
                        end
                    end
                end

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(textPos, color, u8(text))
                    imgui.PopFont()
                else
                    drawList:AddText(textPos, color, u8(text))
                end
            end

            imgui.End()
            imgui.PopStyleColor()
        end

        if config.settings.logs then
            imgui.SetNextWindowPos(imgui.ImVec2(incomingLogX, incomingLogY), imgui.Cond.Always)
            imgui.SetNextWindowSize(imgui.ImVec2(tonumber(settings.incomingLogWidth.v) or 500, tonumber(settings.incomingLogHeight.v) or 200), imgui.Cond.Always)
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))

            imgui.Begin("##previewIncomingDamageLog", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoScrollbar)

            imgui.SetWindowFontScale(1.3)

            local drawList = imgui.GetWindowDrawList()
            local pos = imgui.GetCursorScreenPos()

            for i = 1, #previewIncomingLogs do
                local log = previewIncomingLogs[i]
                local progress = (previewNow - log.created) / LOG_LIFE_TIME
                local alpha = 1.0 - progress

                if alpha < 0 then
                    alpha = 0
                end

                local text = string.format("%s - %.0f - %s", log.name, log.damage, log.weapon)
                local textPos = imgui.ImVec2(pos.x, pos.y + ((i - 1) * 19))

                local outline = imgui.GetColorU32(imgui.ImVec4(0, 0, 0, alpha))
                local shadow = imgui.GetColorU32(imgui.ImVec4(0, 0, 0, alpha * 0.5))
                local color = imgui.GetColorU32(imgui.ImVec4(
                    settings.logColor.v[1],
                    settings.logColor.v[2],
                    settings.logColor.v[3],
                    alpha
                ))

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(
                        imgui.ImVec2(textPos.x + 2, textPos.y + 2),
                        shadow,
                        u8(text)
                    )
                    imgui.PopFont()
                else
                    drawList:AddText(
                        imgui.ImVec2(textPos.x + 2, textPos.y + 2),
                        shadow,
                        u8(text)
                    )
                end

                if settings.logOutline.v then
                    for _, offset in ipairs({
                        {-1, -1},
                        {0, -1},
                        {1, -1},
                        {-1, 0},
                        {1, 0},
                        {-1, 1},
                        {0, 1},
                        {1, 1}
                    }) do
                        if mainFont and config.settings.useMainFont then
                            imgui.PushFont(mainFont)
                            drawList:AddText(
                                imgui.ImVec2(
                                    textPos.x + offset[1],
                                    textPos.y + offset[2]
                                ),
                                outline,
                                u8(text)
                            )
                            imgui.PopFont()
                        else
                            drawList:AddText(
                                imgui.ImVec2(
                                    textPos.x + offset[1],
                                    textPos.y + offset[2]
                                ),
                                outline,
                                u8(text)
                            )
                        end
                    end
                end

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(textPos, color, u8(text))
                    imgui.PopFont()
                else
                    drawList:AddText(textPos, color, u8(text))
                end
            end

            imgui.End()
            imgui.PopStyleColor()
        end
    end

    if debugWindowElements.v then
        imgui.SetNextWindowPos(imgui.ImVec2(logX, logY - 95), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(500, 85), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0.35))

        imgui.Begin(u8("Debug"), debugWindowElements, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar)

        imgui.PushItemWidth(50)

        imgui.InputText(u8("Ширина окна"), settings.logWidth, imgui.InputTextFlags.CharsDecimal)
        imgui.InputText(u8("Высота окна"), settings.logHeight, imgui.InputTextFlags.CharsDecimal)

        imgui.PopItemWidth()

        imgui.SameLine(282)

        if imgui.Button(u8("Сбросить"), imgui.ImVec2(100, 33)) then
            config.settings.logPosX = 425
            config.settings.logPosY = 820
            config.settings.logWidth = 500
            config.settings.logHeight = 200

            logX = 425
            logY = 820
            settings.logWidth.v = "500"
            settings.logHeight.v = "200"

            inicfg.save(config, config_name)

            sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Настройки сброшены до стандартных.", -1)

            editDamage = false
            debugWindowElements.v = false
            window.v = true
            imgui.ShowCursor = window.v
        end

        imgui.SameLine()

        if imgui.Button(u8("Сохранить"), imgui.ImVec2(100, 33)) then
            local width = tonumber(settings.logWidth.v)
            local height = tonumber(settings.logHeight.v)

            if not width or width < 1 then width = 500 end
            if not height or height < 1 then height = 200 end

            config.settings.logPosX = math.floor(logX)
            config.settings.logPosY = math.floor(logY)
            config.settings.logWidth = width
            config.settings.logHeight = height

            settings.logWidth.v = tostring(width)
            settings.logHeight.v = tostring(height)

            inicfg.save(config, config_name)

            sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Сохранено!", -1)

            editDamage = false
            debugWindowElements.v = false
            window.v = true
            imgui.ShowCursor = window.v
        end

        imgui.End()
        imgui.PopStyleColor()
    end

    if incomingDebugWindowElements.v then
        imgui.SetNextWindowPos(imgui.ImVec2(incomingLogX, incomingLogY - 95), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(500, 85), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0.35))

        imgui.Begin(u8("Incoming Debug"), incomingDebugWindowElements, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar)

        imgui.PushItemWidth(50)

        imgui.InputText(u8("Ширина окна"), settings.incomingLogWidth, imgui.InputTextFlags.CharsDecimal)
        imgui.InputText(u8("Высота окна"), settings.incomingLogHeight, imgui.InputTextFlags.CharsDecimal)

        imgui.PopItemWidth()

        imgui.SameLine(282)

        if imgui.Button(u8("Сбросить"), imgui.ImVec2(100, 33)) then
            config.settings.incomingLogPosX = 1350
            config.settings.incomingLogPosY = 820
            config.settings.incomingLogWidth = 500
            config.settings.incomingLogHeight = 200

            incomingLogX = 1350
            incomingLogY = 820
            settings.incomingLogWidth.v = "500"
            settings.incomingLogHeight.v = "200"

            inicfg.save(config, config_name)

            sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Настройки сброшены до стандартных.", -1)

            editIncomingDamage = false
            incomingDebugWindowElements.v = false
            window.v = true
            imgui.ShowCursor = window.v
        end

        imgui.SameLine()

        if imgui.Button(u8("Сохранить"), imgui.ImVec2(100, 33)) then
            local width = tonumber(settings.incomingLogWidth.v)
            local height = tonumber(settings.incomingLogHeight.v)

            if not width or width < 1 then width = 500 end
            if not height or height < 1 then height = 200 end

            config.settings.incomingLogPosX = math.floor(incomingLogX)
            config.settings.incomingLogPosY = math.floor(incomingLogY)
            config.settings.incomingLogWidth = width
            config.settings.incomingLogHeight = height

            settings.incomingLogWidth.v = tostring(width)
            settings.incomingLogHeight.v = tostring(height)

            inicfg.save(config, config_name)

            sampAddChatMessage("{F472B6}[Damage Informer Remastered] {FFFFFF}Сохранено!", -1)

            editIncomingDamage = false
            incomingDebugWindowElements.v = false
            window.v = true
            imgui.ShowCursor = window.v
        end

        imgui.End()
        imgui.PopStyleColor()
    end

    local now = os.clock()

    if config.settings.hitMarkers then
        for i = 1, #damages do
            local dmg = damages[i]
            local progress = (now - dmg.created) / LIFE_TIME
            local sx, sy = convert3DCoordsToScreen(dmg.x, dmg.y, dmg.z)

            if sx and sy then
                local alpha = 1.0 - progress
                local yOffset = progress * 70

                if alpha < 0 then
                    alpha = 0
                end

                imgui.SetNextWindowPos(imgui.ImVec2(sx, sy - yOffset), imgui.Cond.Always)
                imgui.SetNextWindowSize(imgui.ImVec2(100, 35), imgui.Cond.Always)
                imgui.PushStyleVar(imgui.StyleVar.Alpha, alpha)
                imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))

                imgui.Begin("##damage" .. i, nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoScrollbar)

                imgui.SetWindowFontScale(1.3)

                local text = string.format("-%.0f", dmg.damage)
                local drawList = imgui.GetWindowDrawList()
                local pos = imgui.GetCursorScreenPos()

                local shadow = imgui.GetColorU32(imgui.ImVec4(0, 0, 0, alpha * 0.45))
                local outline = imgui.GetColorU32(imgui.ImVec4(0, 0, 0, alpha))
                local textColor = imgui.GetColorU32(imgui.ImVec4(
                    settings.hitMarkerColor.v[1],
                    settings.hitMarkerColor.v[2],
                    settings.hitMarkerColor.v[3],
                    alpha
                ))

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(imgui.ImVec2(pos.x + 2, pos.y + 2), shadow, text)
                    imgui.PopFont()
                else
                    drawList:AddText(imgui.ImVec2(pos.x + 2, pos.y + 2), shadow, text)
                end

                if settings.hitMarkerOutline.v then
                    for _, offset in ipairs({
                        {-1, -1},
                        {0, -1},
                        {1, -1},
                        {-1, 0},
                        {1, 0},
                        {-1, 1},
                        {0, 1},
                        {1, 1}
                    }) do
                        if mainFont and config.settings.useMainFont then
                            imgui.PushFont(mainFont)
                            drawList:AddText(
                                imgui.ImVec2(pos.x + offset[1], pos.y + offset[2]),
                                outline,
                                text
                            )
                            imgui.PopFont()
                        else
                            drawList:AddText(
                                imgui.ImVec2(pos.x + offset[1], pos.y + offset[2]),
                                outline,
                                text
                            )
                        end
                    end
                end

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(pos, textColor, text)
                    imgui.PopFont()
                else
                    drawList:AddText(pos, textColor, text)
                end

                imgui.End()
                imgui.PopStyleColor()
                imgui.PopStyleVar()
            end
        end
    end

    if not window.v and settings.logs.v then
        if #hitLogs > 0 or editDamage then
            if logY == 0 then
                logY = sh - 175
            end

            if editDamage then
                local mx, my = imgui.GetMousePos().x, imgui.GetMousePos().y
                local width = tonumber(settings.logWidth.v) or 500
                local height = tonumber(settings.logHeight.v) or 200

                if imgui.IsMouseClicked(0)
                    and mx >= logX
                    and mx <= logX + width
                    and my >= logY
                    and my <= logY + height then

                    editDrag = true
                    dragX = mx - logX
                    dragY = my - logY
                end

                if not imgui.IsMouseDown(0) then
                    editDrag = false
                end

                if editDrag then
                    logX = mx - dragX
                    logY = my - dragY
                end
            end

            imgui.SetNextWindowPos(imgui.ImVec2(logX, logY), imgui.Cond.Always)

            imgui.SetNextWindowSize(
                imgui.ImVec2(
                    tonumber(settings.logWidth.v) or 500,
                    tonumber(settings.logHeight.v) or 200
                ),
                imgui.Cond.Always
            )

            imgui.PushStyleColor(
                imgui.Col.WindowBg,
                imgui.ImVec4(0, 0, 0, editDamage and 0.35 or 0)
            )

            imgui.Begin(
                "##damageLog",
                nil,
                imgui.WindowFlags.NoTitleBar +
                imgui.WindowFlags.NoResize +
                imgui.WindowFlags.NoMove +
                imgui.WindowFlags.NoScrollbar
            )

            imgui.SetWindowFontScale(1.3)

            local drawList = imgui.GetWindowDrawList()
            local pos = imgui.GetCursorScreenPos()

            for i = 1, #hitLogs do
                local log = hitLogs[i]
                local progress = (now - log.created) / LOG_LIFE_TIME
                local alpha = 1.0 - progress

                if alpha < 0 then
                    alpha = 0
                end

                local prefix = log.afk and "[AFK] " or ""
                local headshot = log.headshot and " - HEADSHOT" or ""
                local killed = log.killed and " - KILLED" or ""

                local text = string.format(
                    "%s%s - %.0f - %s%s%s",
                    prefix,
                    log.name,
                    log.damage,
                    log.weapon,
                    headshot,
                    killed
                )

                local textPos = imgui.ImVec2(
                    pos.x,
                    pos.y + ((i - 1) * 19)
                )

                local outline = imgui.GetColorU32(
                    imgui.ImVec4(0, 0, 0, alpha)
                )

                local shadow = imgui.GetColorU32(
                    imgui.ImVec4(0, 0, 0, alpha * 0.5)
                )

                local color = imgui.GetColorU32(
                    imgui.ImVec4(
                        settings.logColor.v[1],
                        settings.logColor.v[2],
                        settings.logColor.v[3],
                        alpha
                    )
                )

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(
                        imgui.ImVec2(textPos.x + 2, textPos.y + 2),
                        shadow,
                        u8(text)
                    )
                    imgui.PopFont()
                else
                    drawList:AddText(
                        imgui.ImVec2(textPos.x + 2, textPos.y + 2),
                        shadow,
                        u8(text)
                    )
                end

                if settings.logOutline.v then
                    for _, offset in ipairs({
                        {-1, -1},
                        {0, -1},
                        {1, -1},
                        {-1, 0},
                        {1, 0},
                        {-1, 1},
                        {0, 1},
                        {1, 1}
                    }) do
                        if mainFont and config.settings.useMainFont then
                            imgui.PushFont(mainFont)
                            drawList:AddText(
                                imgui.ImVec2(
                                    textPos.x + offset[1],
                                    textPos.y + offset[2]
                                ),
                                outline,
                                u8(text)
                            )
                            imgui.PopFont()
                        else
                            drawList:AddText(
                                imgui.ImVec2(
                                    textPos.x + offset[1],
                                    textPos.y + offset[2]
                                ),
                                outline,
                                u8(text)
                            )
                        end
                    end
                end

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(textPos, color, u8(text))
                    imgui.PopFont()
                else
                    drawList:AddText(textPos, color, u8(text))
                end
            end

            imgui.End()
            imgui.PopStyleColor()
        end
    end

    if not window.v and settings.logs.v then
        if #incomingHitLogs > 0 or editIncomingDamage then
            if incomingLogY == 0 then
                incomingLogY = sh - 375
            end

            if editIncomingDamage then
                local mx, my = imgui.GetMousePos().x, imgui.GetMousePos().y
                local width = tonumber(settings.incomingLogWidth.v) or 500
                local height = tonumber(settings.incomingLogHeight.v) or 200

                if imgui.IsMouseClicked(0)
                    and mx >= incomingLogX
                    and mx <= incomingLogX + width
                    and my >= incomingLogY
                    and my <= incomingLogY + height then

                    incomingEditDrag = true
                    incomingDragX = mx - incomingLogX
                    incomingDragY = my - incomingLogY
                end

                if not imgui.IsMouseDown(0) then
                    incomingEditDrag = false
                end

                if incomingEditDrag then
                    incomingLogX = mx - incomingDragX
                    incomingLogY = my - incomingDragY
                end
            end

            imgui.SetNextWindowPos(
                imgui.ImVec2(incomingLogX, incomingLogY),
                imgui.Cond.Always
            )

            imgui.SetNextWindowSize(
                imgui.ImVec2(
                    tonumber(settings.incomingLogWidth.v) or 500,
                    tonumber(settings.incomingLogHeight.v) or 200
                ),
                imgui.Cond.Always
            )

            imgui.PushStyleColor(
                imgui.Col.WindowBg,
                imgui.ImVec4(0, 0, 0, editIncomingDamage and 0.35 or 0)
            )

            imgui.Begin(
                "##incomingDamageLog",
                nil,
                imgui.WindowFlags.NoTitleBar +
                imgui.WindowFlags.NoResize +
                imgui.WindowFlags.NoMove +
                imgui.WindowFlags.NoScrollbar
            )

            imgui.SetWindowFontScale(1.3)

            local drawList = imgui.GetWindowDrawList()
            local pos = imgui.GetCursorScreenPos()

            for i = 1, #incomingHitLogs do
                local log = incomingHitLogs[i]
                local progress = (now - log.created) / LOG_LIFE_TIME
                local alpha = 1.0 - progress

                if alpha < 0 then
                    alpha = 0
                end

                local text = string.format(
                    "%s - %.0f - %s",
                    log.name,
                    log.damage,
                    log.weapon
                )

                local textPos = imgui.ImVec2(
                    pos.x,
                    pos.y + ((i - 1) * 19)
                )

                local outline = imgui.GetColorU32(
                    imgui.ImVec4(0, 0, 0, alpha)
                )

                local shadow = imgui.GetColorU32(
                    imgui.ImVec4(0, 0, 0, alpha * 0.5)
                )

                local color = imgui.GetColorU32(
                    imgui.ImVec4(
                        settings.logColor.v[1],
                        settings.logColor.v[2],
                        settings.logColor.v[3],
                        alpha
                    )
                )

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(
                        imgui.ImVec2(textPos.x + 2, textPos.y + 2),
                        shadow,
                        u8(text)
                    )
                    imgui.PopFont()
                else
                    drawList:AddText(
                        imgui.ImVec2(textPos.x + 2, textPos.y + 2),
                        shadow,
                        u8(text)
                    )
                end

                if settings.logOutline.v then
                    for _, offset in ipairs({
                        {-1, -1},
                        {0, -1},
                        {1, -1},
                        {-1, 0},
                        {1, 0},
                        {-1, 1},
                        {0, 1},
                        {1, 1}
                    }) do
                        if mainFont and config.settings.useMainFont then
                            imgui.PushFont(mainFont)
                            drawList:AddText(
                                imgui.ImVec2(
                                    textPos.x + offset[1],
                                    textPos.y + offset[2]
                                ),
                                outline,
                                u8(text)
                            )
                            imgui.PopFont()
                        else
                            drawList:AddText(
                                imgui.ImVec2(
                                    textPos.x + offset[1],
                                    textPos.y + offset[2]
                                ),
                                outline,
                                u8(text)
                            )
                        end
                    end
                end

                if mainFont and config.settings.useMainFont then
                    imgui.PushFont(mainFont)
                    drawList:AddText(textPos, color, u8(text))
                    imgui.PopFont()
                else
                    drawList:AddText(textPos, color, u8(text))
                end
            end

            imgui.End()
            imgui.PopStyleColor()
        end
    end
end