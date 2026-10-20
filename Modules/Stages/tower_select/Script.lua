---@diagnostic disable: undefined-global, undefined-field
-- tower_select (generic): the towers of the song folder "太鼓タワー" in a list; the selected tower's floors,
-- lives and level on the right, with the tower itself drawn by the tower_view ROActivity. Decide on a tower
-- opens a small panel: Challenge (plays it, one player), Settings (the mod dialog), Customize (the customize
-- dialog) or Back. Plain SimpleUI screens (Lib/GenericScreen.lua), no art of its own.

local S = require("GenericScreen")

local DIFF_TOWER = 5
local EXIT_TRANSITION = "tower_gate_back"   -- back to the title

local songList = nil
local towers = {}
local ui, menu = nil, nil
local picked = nil        -- the tower a menu row was chosen for this frame
local ask = nil           -- the confirm panel while it shows
local askNode, askAction = nil, nil
local view, viewFor = nil, nil
local act = {}            -- the dialogs the confirm panel opens

local function buildTowers()
    towers = {}
    if songList == nil then return end
    local found = songList:SearchSongsByPredicate(function(node)
        return node.IsSong and node:GetChart(DIFF_TOWER) ~= nil
    end)
    for i = 0, found.Count - 1 do towers[#towers + 1] = found[i] end
end

local function buildMenu()
    if ui ~= nil then ui:disposeWidgets() end
    ui = S.newUI{ navPlayer = 1 }
    local items = {}
    for i, node in ipairs(towers) do items[i] = { text = node.Title or "?", value = i } end
    local top = S.headerH + 30
    local selected = menu and math.min(menu.selected, math.max(1, #items)) or 1
    menu = ui:menu{ x = S.margin, y = top, w = 700, h = S.H - S.footerH - 30 - top, rowHeight = 72, items = items,
        scrollbar = true, selected = selected,
        onSelect = function(i) picked = towers[i]; return true end }
    ui:focus(menu)
end

local function closeAsk()
    if ask ~= nil then ask:disposeWidgets() end
    ask, askNode, askAction = nil, nil, nil
end

-- the confirm panel for a tower: Challenge first, then Settings, Customize and Back
local function openAsk(node)
    closeAsk()
    askNode = node
    ask = S.newUI{ navPlayer = 1 }
    local PW, PH = 860, 300
    local panel = ask:panel{ x = (S.W - PW) / 2, y = (S.H - PH) / 2, w = PW, h = PH, title = node.Title or "" }
    local cx, cy, cw, ch = panel:content()
    local list = {
        { S.tr("TOWER_CHALLENGE", "Challenge"), "challenge" },
        { S.tr("TOWER_SETTINGS", "Settings"), "settings" },
        { S.tr("TOWER_CUSTOMIZE", "Customize"), "customize" },
        { S.tr("COMMON_BACK", "Back"), "back" },
    }
    local gap = 16
    local bw = (cw - (#list - 1) * gap) / #list
    local first = nil
    for i, b in ipairs(list) do
        local btn = ask:button{ text = b[1], x = cx + (i - 1) * (bw + gap), y = cy + ch - 96, w = bw, h = 76, accent = (i == 1),
            onClick = function() askAction = b[2] end }
        first = first or btn
    end
    ask:focus(first)
end

local function closeView()
    if view ~= nil and view.IsActive then pcall(function() view:Deactivate() end) end
    viewFor = nil
end

-- the tower_view shows the selected tower
local function showView(node)
    if node == viewFor then return end
    closeView()
    view = ROACTIVITY:GetROActivity("tower_view")
    local chart = node and node:GetChart(DIFF_TOWER)
    if view ~= nil and chart ~= nil then
        view:Activate(chart.TowerType, chart.TotalFloorCount or 0)
        viewFor = node
    end
end

function onStart()
end

function activate()
    S.resetKeys()
    CONFIG.PlayerCount = 1
    CONFIG.SongSpeed   = 20   -- reset speed (other modes may have changed it)
    act.mod_select_dialog = ACTIVITY:GetActivity("mod_select_dialog")
    act.customize_dialog = ACTIVITY:GetActivity("customize_dialog")
    picked = nil
    closeAsk()
    buildMenu()
end

function deactivate()
    closeView()
    closeAsk()
    if ui ~= nil then ui:disposeWidgets() end
    ui = nil
end

function afterSongEnum()
    local st = GenerateSongListSettings()
    st.ModuloPagination = false
    st.AppendMainRandomBox = false
    st.AppendSubRandomBoxes = false
    st.FlattenOpenedFolders = false
    st.RootGenreFolder = "太鼓タワー"
    st:SetMandatoryDifficultyList({ DIFF_TOWER })
    songList = RequestSongList(st)
    buildTowers()
    if ui ~= nil then buildMenu() end
end

function update(ts)
    -- a dialog opened from the confirm panel takes the input while it shows
    for _, a in pairs(act) do
        if a ~= nil and a.IsActive then a:Update(); return nil end
    end

    if ask ~= nil then
        askAction = nil
        local r = ask:update(ts)
        if r == "cancel" or askAction == "back" then
            S.sound("Cancel"); closeAsk()
        elseif askAction == "settings" then
            S.sound("Decide")
            if act.mod_select_dialog ~= nil then act.mod_select_dialog:Activate(0) end
        elseif askAction == "customize" then
            S.sound("Decide")
            if act.customize_dialog ~= nil then act.customize_dialog:Activate(0) end
        elseif askAction == "challenge" then
            if askNode:Mount(DIFF_TOWER) then
                S.sound("SongDecide")
                closeAsk()
                return Exit("play", nil)
            end
            S.sound("Error")
        end
        return nil
    end

    picked = nil
    if ui:update(ts) == "cancel" then
        S.sound("Cancel")
        return Exit("title", nil, EXIT_TRANSITION)
    end
    showView(towers[menu.selected])
    if picked ~= nil then
        if picked.IsLocked then S.sound("Error")
        else S.sound("Decide"); openAsk(picked) end
    end
end

local function drawTower(node)
    local chart = node:GetChart(DIFF_TOWER)
    if chart == nil then return end
    local x, y, w, h = 820, S.headerH + 30, S.W - 820 - S.margin, 820
    S.rect(x, y, w, h, S.colors.surface)
    if view ~= nil and view.IsActive then
        GRAPHICS:SetClip(x, y, w, h)
        view:Draw(0.35, 1)
        GRAPHICS:ClearClip()
    end
    S.frame(x, y, w, h, S.colors.line, 2)
    S.rect(x, y + h - 230, w, 230, S.colors.surface, 0.92)
    S.text(node.Title or "", x + 40, y + h - 200, S.font.title, S.colors.text, "topleft", 1, w - 80)
    local line = S.trf("TOWER_INFO", "{floors} floors    {lives} lives    level {level}",
        { floors = chart.TotalFloorCount or 0, lives = chart.Life or 0, level = chart.Level or 0 })
    S.text(line, x + 40, y + h - 110, S.font.body, S.colors.textDim, "topleft", 1, w - 80)
    if node.IsLocked then
        S.text(node.UnlockText or S.tr("SS_LOCKED", "Locked song"), x + 40, y + h - 60, S.font.small, S.colors.bad, "topleft", 1, w - 80)
    end
end

function draw()
    S.clear()
    S.header(S.tr("TOWER_TITLE", "Towers"), S.trf("TOWER_COUNT", "{n} towers", { n = #towers }))
    if IsSongsEnumerating() and #towers == 0 then
        S.text(S.tr("TOWER_LOADING", "Loading songs..."), 960, 540, S.font.label, S.colors.textDim, "center")
    elseif #towers == 0 then
        S.text(S.tr("TOWER_NONE", "No towers found."), 960, 540, S.font.label, S.colors.textDim, "center")
    else
        ui:draw()
        local node = towers[menu.selected]
        if node ~= nil then drawTower(node) end
    end
    S.footer({ { S.key("decide"), S.tr("COMMON_SELECT", "Select") }, { S.key("cancel"), S.tr("COMMON_BACK", "Back") } })
    if ask ~= nil then S.shade(0.45); ask:draw() end
    for _, a in pairs(act) do
        if a ~= nil and a.IsActive then a:Draw() end
    end
end

function onDestroy()
    closeView()
    closeAsk()
    S.dispose()
end
