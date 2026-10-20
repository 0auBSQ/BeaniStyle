---@diagnostic disable: undefined-global, undefined-field, need-check-nil, unused-local
-- diffselect.lua  —  Difficulty-select draw panel and update handler
--                    for song_select_core.

local Replay = require("replaylist")
local CFG    = require("sscore_config") -- Config/layout.json (skinner-editable); values fall back to the defaults below

local M = {}
local G   -- shared state injected by Script.lua

-- ── Layout constants ──────────────────────────────────────────────────────────

local DIFFSELECT_CHARA_ORIG_X_35P = CFG.num("difficulty_select.chara_35p.origin_x", 450)
local DIFFSELECT_CHARA_ORIG_Y_35P = CFG.num("difficulty_select.chara_35p.origin_y", 400)
local DIFFSELECT_CHARA_GAP_X_35P = CFG.num("difficulty_select.chara_35p.gap_x", 375)
local DIFFSELECT_CHARA_GAP_Y_35P = CFG.num("difficulty_select.chara_35p.gap_y", 457)
local DIFFSELECT_CHARA_SCALE_35P = CFG.num("difficulty_select.chara_35p.scale", 0.5)
local DIFFSELECT_CHARA_ORIG_X_12P = CFG.num("difficulty_select.chara_12p.origin_x", 475)
local DIFFSELECT_CHARA_ORIG_Y_12P = CFG.num("difficulty_select.chara_12p.origin_y", 700)
local DIFFSELECT_CHARA_GAP_X_12P = CFG.num("difficulty_select.chara_12p.gap_x", 500)
local DIFFSELECT_CHARA_SCALE_12P = CFG.num("difficulty_select.chara_12p.scale", 0.8)

-- Option bars
local DIFFSELECT_SMALL_BAR_X = CFG.numList("difficulty_select.option_bars.origin_x", {1278, 1492, 1706})
local DIFFSELECT_SMALL_BAR_Y = CFG.numList("difficulty_select.option_bars.origin_y", {234, 234, 234})
local DIFFSELECT_SMALL_BAR_SELECT_RECT_Y_OFFSET = CFG.num("difficulty_select.option_bars.rect_y_offset", 116)
local DIFFSELECT_SMALL_BAR_SELECT_X_OFFSET = CFG.num("difficulty_select.option_bars.select_x_offset", 0)
local DIFFSELECT_SMALL_BAR_SELECT_Y_OFFSET = CFG.num("difficulty_select.option_bars.select_y_offset", 0)

-- Difficulty bars
local DIFFSELECT_BIG_BAR_ORIG_X = CFG.num("difficulty_select.difficulty_bars.origin_x", 1904)
local DIFFSELECT_BIG_BAR_ORIG_Y = CFG.num("difficulty_select.difficulty_bars.origin_y", 366)
local DIFFSELECT_BIG_BAR_GAP_Y = CFG.num("difficulty_select.difficulty_bars.step_y", 132)
local DIFFSELECT_BIG_BAR_SELECT_X_OFFSET = CFG.num("difficulty_select.difficulty_bars.select_x_offset", -626)
local DIFFSELECT_BIG_BAR_SELECT_Y_OFFSET = CFG.num("difficulty_select.difficulty_bars.select_y_offset", 0)
local DIFFSELECT_LEVEL_BAR_X = CFG.num("difficulty_select.difficulty_bars.level_bar_x", 4)
local DIFFSELECT_LEVEL_BAR_Y = CFG.num("difficulty_select.difficulty_bars.level_bar_y", 64)
local DIFFSELECT_LEVEL_NB_OFF_X = CFG.num("difficulty_select.difficulty_bars.level_number_x", -80)
local DIFFSELECT_LEVEL_NB_OFF_Y = CFG.num("difficulty_select.difficulty_bars.level_number_y", -50)
local DIFFSELECT_CHARTER_OFFSET_X = CFG.num("difficulty_select.difficulty_bars.charter_offset_x", -645)
local DIFFSELECT_CHARTER_OFFSET_Y = CFG.num("difficulty_select.difficulty_bars.charter_offset_y", 22)

local DIFFSELECT_LEVEL_COLORS = CFG.colorList("colors.level", {
    COLOR:CreateColorFromHex("FF0057FF"),
    COLOR:CreateColorFromHex("FF1FAA4F"),
    COLOR:CreateColorFromHex("FFFF9500"),
    COLOR:CreateColorFromHex("FFA80027"),
    COLOR:CreateColorFromHex("FF5900A8"),
})

local NAMEPLATE_HEIGHT = CFG.num("difficulty_select.nameplate.height", 81)
local NAMEPLATE_OFFSET_X = CFG.num("difficulty_select.nameplate.offset_x", 27)
local NAMEPLATE_OFFSET_Y = CFG.num("difficulty_select.nameplate.offset_y", 37)
local PUCHI_OFFSET_X = CFG.num("difficulty_select.nameplate.puchi_offset_x", 60)

-- ── Init ──────────────────────────────────────────────────────────────────────

function M.init(g)
    G = g
    Replay.init(g)
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

function M.loadDiffBars(ssn)
    G.diffBars = {}
    local startDiff = 0
    local isVault   = ssn.Genre == "Secret Vault"
    if isVault then startDiff = 3 end
    for i = startDiff, 4 do
        local chart = ssn:GetChart(i)
        if chart ~= nil then
            table.insert(G.diffBars, {
                vault      = isVault,
                level      = chart.Level,
                isplus     = chart.IsPlus,
                charter    = chart.NotesDesigner,
                difficulty = i,
                vaultName  = isVault and chart:GetCustomCommand(".VAULT_NAME") or nil,
            })
        end
    end
end

function M.updateTransitionVisuals(val)
    local opacity    = 255 - (val * (255 / 960))
    G.songSelectElemOpacity      = math.max(0, math.min(255, opacity))
    local diffOpacity = (val - 960) * (255 / 960)
    G.difficultySelectElemOpacity = math.max(0, math.min(255, diffOpacity))
end

function M.resetToSongSelect()
    G.songSelectElemOpacity      = 255
    G.difficultySelectElemOpacity = 0
    G.activeScreen    = "songselect"
    Replay.reset()
end

-- ── Private draw helpers ──────────────────────────────────────────────────────

-- ── Mouse ─────────────────────────────────────────────────────────────────────
-- the screen rectangle of bar `index` (options 0..2, difficulties 3+) as drawn below, or nil
local function barRect(index)
    if index < 3 then
        local tex = G.difftx["smallbar" .. index]
        if tex == nil then return nil end
        local x, y = DIFFSELECT_SMALL_BAR_X[index + 1], DIFFSELECT_SMALL_BAR_Y[index + 1]
        return x, y - tex.Height, tex.Width, tex.Height                       -- drawn "bottomleft"
    end
    local barinfo = G.diffBars[index - 2]
    if barinfo == nil then return nil end
    local tex = G.difftx["difficultybar" .. (barinfo.vault and 5 or barinfo.difficulty)]
    if tex == nil then return nil end
    local x = DIFFSELECT_BIG_BAR_ORIG_X
    local y = DIFFSELECT_BIG_BAR_ORIG_Y + (index - 3) * DIFFSELECT_BIG_BAR_GAP_Y
    return x - tex.Width, y - tex.Height, tex.Width, tex.Height               -- drawn "bottomright"
end

-- the diffIndex under the mouse, or nil; the later-drawn bars win overlaps
local function mouseTarget()
    if not INPUT:IsMouseInside() then return nil end
    local mx, my = INPUT:GetMouseXY()
    for index = 2 + #G.diffBars, 0, -1 do
        local x, y, w, h = barRect(index)
        if x ~= nil and mx >= x and mx <= x + w and my >= y and my <= y + h then return index end
    end
    return nil
end

local function drawDifficultyBar(index, barinfo)
    local tex    = G.difftx["difficultybar5"]   -- the vault bar
    if barinfo.vault == false then
        tex = G.difftx["difficultybar" .. (barinfo.difficulty)]
    end
    local xpos = DIFFSELECT_BIG_BAR_ORIG_X
    local ypos = DIFFSELECT_BIG_BAR_ORIG_Y + (index - 3) * DIFFSELECT_BIG_BAR_GAP_Y
    for i = 1, CONFIG.PlayerCount do
        if G.diffIndex[i] == index and not (G.activeConfig.mountAISlotToP2 and i == 2) then
            G.difftx["difficultybarselect" .. i]:DrawRectAtAnchor(
                xpos - G.difftx["difficultybar2"].Width, ypos, 0, 0,
                G.difftx["difficultybarselect" .. i].Width,
                DIFFSELECT_SMALL_BAR_SELECT_RECT_Y_OFFSET,
            "bottomleft")
        end
    end
    tex:DrawAtAnchor(xpos, ypos, "bottomright")

    G.textCharter:Draw(
        "Charter - " .. barinfo.charter,
        xpos + DIFFSELECT_CHARTER_OFFSET_X, ypos + DIFFSELECT_CHARTER_OFFSET_Y,
        nil, nil, G.difficultySelectElemOpacity / 255, 1, 472, "bottomleft"
    )

    -- Vault chart: custom name (.VAULT_NAME) centered at (316, 216) from the bar's top-left
    if barinfo.vault and barinfo.vaultName ~= nil and barinfo.vaultName ~= "" then
        G.textCharter:Draw(
            barinfo.vaultName,
            xpos - tex.Width + 316, ypos - tex.Height + 216,
            nil, nil, G.difficultySelectElemOpacity / 255, 1, 472, "center"
        )
    end

    local xbar = xpos - tex.Width + DIFFSELECT_LEVEL_BAR_X
    local ybar = ypos - tex.Height + DIFFSELECT_LEVEL_BAR_Y
    local bartx = G.difftx["difficultybarlevel5"]
    if barinfo.vault == false then
        bartx = G.difftx["difficultybarlevel" .. (barinfo.difficulty)]
    end
    bartx:DrawRect(xbar, ybar, 0, 0, bartx.Width * (math.min(10, barinfo.level) / 10), bartx.Height)
    if barinfo.level > 10 then
        local anim = G.difftx["difficultybarlevel6"]
        anim:DrawRect(xbar, ybar, 0, bartx.Height * G.levelLabelFrame,
            bartx.Width * (math.min(3, barinfo.level - 10) / 3), bartx.Height)
    end

    local lvnbcol = COLOR:CreateColorFromHex("FF434343")
    if barinfo.vault == false then lvnbcol = DIFFSELECT_LEVEL_COLORS[barinfo.difficulty + 1] end

    G.textXL:Draw(
        tostring(barinfo.level),
        xpos + DIFFSELECT_LEVEL_NB_OFF_X, ypos + DIFFSELECT_LEVEL_NB_OFF_Y,
        nil, nil, G.difficultySelectElemOpacity / 255, 1, 150, "center"
    )
end

local function drawDiffSelectBar(index, barinfo)
    if index < 3 then
        local xpos = DIFFSELECT_SMALL_BAR_X[index + 1]
        local ypos = DIFFSELECT_SMALL_BAR_Y[index + 1]
        for i = 1, CONFIG.PlayerCount do
            if G.diffIndex[i] == index and not (G.activeConfig.mountAISlotToP2 and i == 2) then
                G.difftx["difficultybarselect" .. i]:DrawRectAtAnchor(
                    xpos, ypos, 0,
                    DIFFSELECT_SMALL_BAR_SELECT_RECT_Y_OFFSET,
                    G.difftx["difficultybarselect" .. i].Width,
                    G.difftx["difficultybarselect" .. i].Height - DIFFSELECT_SMALL_BAR_SELECT_RECT_Y_OFFSET,
                "bottomleft")
            end
        end
        G.difftx["smallbar" .. index]:DrawAtAnchor(xpos, ypos, "bottomleft")
    else
        drawDifficultyBar(index, barinfo)
    end
end

-- ── Draw panel ────────────────────────────────────────────────────────────────

function M.drawPanel()
    local opacityNorm = G.difficultySelectElemOpacity / 255

    if G.difftx ~= nil then
        for _, diffSelect in pairs(G.difftx) do diffSelect:SetOpacity(opacityNorm) end
    end

    if G.activeScreen == "difficultyselect" then
        G.bgtx["header"]:Draw(0, 0)
    end

    G.bgtx["header_overlay_difficulty"]:DrawAtAnchor(1880, 0, "topright")

    if G.selectedSongNode ~= nil then
        G.textLarge:Draw(G.selectedSongNode.Title, 0, 5, nil, nil, opacityNorm, 1, 1280)
        G.text:Draw(G.selectedSongNode.Subtitle, 0, 60, nil, nil, opacityNorm, 1, 1280)

        for i = 0, 2 + #G.diffBars do
            local barinfo = nil
            if i >= 3 then barinfo = G.diffBars[i - 2] end
            drawDiffSelectBar(i, barinfo)
        end
    end

    -- Characters and nameplates
    do
        local p     = CONFIG.PlayerCount
        local is35  = p > 2
        local ox    = is35 and DIFFSELECT_CHARA_ORIG_X_35P or DIFFSELECT_CHARA_ORIG_X_12P
        local oy    = is35 and DIFFSELECT_CHARA_ORIG_Y_35P or DIFFSELECT_CHARA_ORIG_Y_12P
        local gx    = is35 and DIFFSELECT_CHARA_GAP_X_35P  or DIFFSELECT_CHARA_GAP_X_12P
        local gy    = is35 and DIFFSELECT_CHARA_GAP_Y_35P  or 0
        local s     = is35 and DIFFSELECT_CHARA_SCALE_35P  or DIFFSELECT_CHARA_SCALE_12P
        local r1Count = (p == 5 and 3) or (p > 2 and 2) or p

        -- single-player performance mode shows the best-plays cards down the right edge;
        -- nudge the character/nameplate/mod-icons left so the two don't overlap. Any mode without the
        -- strip (training, AI battle, lobby, multiplayer) keeps the base layout.
        if Replay.isActive() then ox = ox - 200 end

        for i = 0, p - 1 do
            local isRow2 = i >= r1Count
            local r      = isRow2 and 1 or 0
            local cols   = isRow2 and (p - r1Count) or r1Count
            local colIdx = isRow2 and (i - r1Count) or i
            local x      = ox + (colIdx - (cols - 1) / 2) * gx
            local y      = oy + r * gy
            G.drawCharaWithNameplate(i, x, y, s, s, opacityNorm, false)
            local charaX = x + G.bgtx["nameplate_info"].Width / 2 - NAMEPLATE_OFFSET_X
            G.drawPlayerPuchi(i, charaX - PUCHI_OFFSET_X * s, y + G.puchiSineY * s, s, s, opacityNorm, false, G.puchiIdxFrame)
            if G.modicons_ro ~= nil then
                G.modicons_ro:Draw(x, y + NAMEPLATE_HEIGHT + 4, i, nil, G.difficultySelectElemOpacity)
            end
        end
    end

    -- AI level slider (AI battle only)
    if G.activeConfig.mountAISlotToP2 then
        local cx      = 1490
        G.textSmall:Draw("Starting AI Level", cx, 940, nil, nil, opacityNorm, 1, 400, "center")
        G.text:Draw(tostring(CONFIG.AILevel), cx, 980, nil, nil, opacityNorm, 1, 200, "center")
        local ax = G.arrowsDistance
        if CONFIG.AILevel > 1 then
            G.textSmall:Draw("◀", cx - 55 - ax, 980, nil, nil, opacityNorm, 1, 60, "right")
        end
        if CONFIG.AILevel < 10 then
            G.textSmall:Draw("▶", cx + 55 + ax, 980, nil, nil, opacityNorm, 1, 60, "left")
        end
    end

    Replay.draw()
end

-- ── Update handler ────────────────────────────────────────────────────────────
-- Returns "play", "cancel" (unused here; cancel goes back to songselect), or nil.

function M.handleUpdate(ts)
    -- best-plays cards: confirm prompt + mouse hover/scroll/click (single-player performance mode only).
    -- "play" launches a replay; "consume" means the confirm prompt ate this frame's input.
    local rsig = Replay.handleUpdate(ts)
    if rsig == "play" then return "play" end
    if rsig == "consume" then return nil end

    local allDiffsSelected = true
    local canceled         = false
    local decided          = false
    local uniNavPlayer = 1

    for i = 1, CONFIG.PlayerCount do
        if i == uniNavPlayer and G.diffSelected[i] then
            uniNavPlayer = i + 1
        end
        local navPn = G.NavInput.p[i]

        if G.activeConfig.mountAISlotToP2 and i == 2 then
            -- AI mirrors P1
            G.diffIndex[2]   = G.diffIndex[1]
            G.diffSelected[2] = G.diffSelected[1]

            -- AI level slider (AI battle only)
            if navPn.left(i == uniNavPlayer) and CONFIG.AILevel > 1 then
                CONFIG.AILevel = CONFIG.AILevel - 1; G.sounds.Skip:Play()
            elseif navPn.right(i == uniNavPlayer) and CONFIG.AILevel < 10 then
                CONFIG.AILevel = CONFIG.AILevel + 1; G.sounds.Skip:Play()
            end
        elseif G.diffSelected[i] == false then
            -- one human player: moving the mouse over a bar selects it, a click on it decides
            local click = false
            if i == 1 and G.mouseAllowed() then
                local target = mouseTarget()
                local mdx, mdy = INPUT:GetMouseDelta()
                if target ~= nil and target ~= G.diffIndex[1] and (mdx ~= 0 or mdy ~= 0) then
                    G.sounds.Skip:Play(); G.diffIndex[1] = target
                end
                click = target ~= nil and target == G.diffIndex[1] and INPUT:MousePressed("Left")
            end
            if navPn.right(i == uniNavPlayer) then
                G.sounds.Skip:Play()
                G.diffIndex[i] = (G.diffIndex[i] + 1) % (3 + #G.diffBars)
            elseif navPn.left(i == uniNavPlayer) then
                G.sounds.Skip:Play()
                G.diffIndex[i] = (G.diffIndex[i] - 1) % (3 + #G.diffBars)
            elseif navPn.decide(i == uniNavPlayer) or click then
                if G.diffIndex[i] == 0 then
                    canceled = true
                elseif G.diffIndex[i] == 1 then
                    G.sounds.Decide:Play()
                    G.act_inner["mod_select_dialog"]:Activate(i - 1); return nil
                elseif G.diffIndex[i] == 2 then
                    G.sounds.Decide:Play()
                    G.act_inner["customize_dialog"]:Activate(i - 1); return nil
                else
                    decided = true; G.diffSelected[i] = true
                end
            elseif navPn.cancel(i == uniNavPlayer) then
                if G.diffSelected[i] then G.diffSelected[i] = false; G.sounds.Cancel:Play()
                else canceled = true end
            end
                
            if i <= 2 and G.shortcuts.pressed("auto_p" .. i) then
                G.sounds.Decide:Play(); CONFIG:SetAutoStatus(i - 1, not CONFIG:GetAutoStatus(i - 1))
            end
        end

        if G.diffSelected[i] == false then allDiffsSelected = false end
    end

    if canceled or G.NavInput.cancel() then
        G.sounds.Cancel:Play()
        G.activeScreen = "transition"
        G.startCounter("screen_transition", 1920, 0, -0.1/1000, "none", M.updateTransitionVisuals, function()
            M.resetToSongSelect()
        end)
    elseif allDiffsSelected then
        local success = G.selectedSongNode:Mount(
            (G.diffIndex[1] >= 3) and G.diffBars[G.diffIndex[1] - 2].difficulty or 0,
            (G.diffIndex[2] >= 3) and G.diffBars[G.diffIndex[2] - 2].difficulty or 0,
            (G.diffIndex[3] >= 3) and G.diffBars[G.diffIndex[3] - 2].difficulty or 0,
            (G.diffIndex[4] >= 3) and G.diffBars[G.diffIndex[4] - 2].difficulty or 0,
            (G.diffIndex[5] >= 3) and G.diffBars[G.diffIndex[5] - 2].difficulty or 0
        )
        if success then
            G.sounds.SongDecide:Play()
            G.lastSignal = "play"; return "play"
        else
            G.sounds.Error:Play()
            G.diffSelected = {false, false, false, false, false}
        end
    elseif decided then
        G.sounds.Decide:Play()
    end

    return nil
end

return M
