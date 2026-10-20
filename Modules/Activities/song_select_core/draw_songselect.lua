---@diagnostic disable: undefined-global, undefined-field, need-check-nil, unused-local
-- draw_songselect.lua  —  Song-select panel drawing for song_select_core.

local CFG = require("sscore_config")   -- Config/layout.json (skinner-editable); values fall back to the defaults below

local M = {}
-- hoisted colors (per-frame COLOR:Create* calls allocate userdata every frame); overridable via config
local SONGLIST_GOLD = CFG.color("colors.songlist_gold", COLOR:CreateColorFromARGB(255, 242, 207, 1))   -- selected-bar title tint
local COL_WHITE = COLOR:CreateColorFromHex("ffffffff")
local COL_BLACK = COLOR:CreateColorFromHex("ff000000")
local COL_VAULT_GRAY = CFG.color("colors.vault_gray", COLOR:CreateColorFromHex("ff808080"))
local COL_TAG_FIRE = CFG.color("colors.tag_fire", COLOR:CreateColorFromHex("ffac0c0c"))
local COL_TAG_STORM = CFG.color("colors.tag_storm", COLOR:CreateColorFromHex("ff83159e"))
local COL_BPM_SLOW = CFG.color("colors.bpm_slow", COLOR:CreateColorFromHex("ff95ccff"))
local COL_BPM_FAST = CFG.color("colors.bpm_fast", COLOR:CreateColorFromHex("ffff9ec3"))

local statsCache = { player = -1, diff = -1 }   -- clear-count queries are save-file scans; key on (player, course)
local G   -- shared state injected by Script.lua

-- ── Layout constants (defaults; overridable via Config/layout.json) ─────────────
local SONGLIST_ORIGIN_X = CFG.num("song_list.origin_x", 650)
local SONGLIST_ORIGIN_Y = CFG.num("song_list.origin_y", 540)
local SONGLIST_OFFSET_X = CFG.num("song_list.offset_x", 15)
local SONGLIST_OFFSET_Y = CFG.num("song_list.offset_y", 82)
local SONGLIST_TEXT_OFFSET_X = CFG.num("song_list.text_offset_x", -40)
local SONGLIST_TEXT_OFFSET_Y = CFG.num("song_list.text_offset_y", 15)
local SONGLIST_TEXT_MWIDTH = CFG.num("song_list.text_max_width", 525)
local SONGLIST_SELECTED_X_DIFF = CFG.num("song_list.selected_x_diff", 75)
local SONGLIST_SELECTED_ARROW_GAP = CFG.num("song_list.selected_arrow_gap", 925)
local SONGBAR_LABEL_X_OFFSET = CFG.num("song_list.label_x_offset", 272)
local SONGBAR_LEVEL_X_OFFSET = CFG.num("song_list.level_x_offset", 12)
local SONGBAR_LEVEL_Y_OFFSET = CFG.num("song_list.level_y_offset", 10)
local BARLEFT_X_OFFSET = CFG.num("song_list.barleft_x_offset", 1) -- pixels left of bar.png topleft

local FAV_ICON_OFFSET_X = CFG.num("song_list.fav_icon_x_offset", 535)
local FAV_ICON_OFFSET_Y = CFG.num("song_list.fav_icon_y_offset", 8)

-- the "[key] - Show shortcuts" line under the header overlay: position and its slow opacity pulse
local HELPER_X           = CFG.num("song_list.shortcuts_helper_x", 44)
local HELPER_Y           = CFG.num("song_list.shortcuts_helper_y", 178)
local HELPER_PULSE_MS    = CFG.num("song_list.shortcuts_helper_pulse_ms", 2400)
local HELPER_OPACITY_MIN = CFG.num("song_list.shortcuts_helper_opacity_min", 0.45)
local HELPER_PAD_X       = CFG.num("song_list.shortcuts_helper_pad_x", 16)       -- the dark box around the line
local HELPER_PAD_Y       = CFG.num("song_list.shortcuts_helper_pad_y", 8)
local HELPER_BOX_ALPHA   = CFG.num("song_list.shortcuts_helper_box_alpha", 150)
local HELPER_BOX_RADIUS  = CFG.num("song_list.shortcuts_helper_box_radius", 10)

-- the clickable part of a song bar (mouse), in Bars/bar.png pixels from its top-left corner
local BAR_HIT_LEFT   = CFG.num("song_list.hit_left", 4)
local BAR_HIT_RIGHT  = CFG.num("song_list.hit_right", 686)
local BAR_HIT_TOP    = CFG.num("song_list.hit_top", 4)
local BAR_HIT_BOTTOM = CFG.num("song_list.hit_bottom", 75)

local SONGINFO_DIFFICULTIES_ORIGIN_X = CFG.num("song_info.difficulties_origin_x", 1798)
local SONGINFO_DIFFICULTIES_ORIGIN_Y = CFG.num("song_info.difficulties_origin_y", 146)
local SONGINFO_DIFFICULTIES_GAP_Y = CFG.num("song_info.difficulties_gap_y", 104)
local SONGINFO_DIFFICULTIES_LEVEL_ORIGIN_X = CFG.num("song_info.difficulties_level_origin_x", 65)
local SONGINFO_DIFFICULTIES_LEVEL_ORIGIN_Y = CFG.num("song_info.difficulties_level_origin_y", 39)
local SONGINFO_HASVIDEO_ORIGIN_X = CFG.num("song_info.has_video_origin_x", 1247)
local SONGINFO_HASVIDEO_ORIGIN_Y = CFG.num("song_info.has_video_origin_y", 815)
local SONGINFO_EXPLICIT_ORIGIN_X = CFG.num("song_info.explicit_origin_x", 1247)
local SONGINFO_EXPLICIT_ORIGIN_Y = CFG.num("song_info.explicit_origin_y", 815)
local SONGINFO_SUBTITLE_ORIGIN_X = CFG.num("song_info.subtitle_origin_x", 1517)
local SONGINFO_SUBTITLE_ORIGIN_Y = CFG.num("song_info.subtitle_origin_y", 697)
local SONGINFO_SUBTITLE_MWIDTH = CFG.num("song_info.subtitle_max_width", 530)
local SONGINFO_BPM_ORIGIN_X = CFG.num("song_info.bpm_origin_x", 1418)
local SONGINFO_BPM_ORIGIN_Y = CFG.num("song_info.bpm_origin_y", 886)
local SONGINFO_BPM_MWIDTH = CFG.num("song_info.bpm_max_width", 300)
local SONGINFO_INFO_ORIGIN_X = CFG.num("song_info.info_origin_x", 1245)
local SONGINFO_INFO_ORIGIN_Y = CFG.num("song_info.info_origin_y", 714)
local SONGINFO_INFO_GAP_Y = CFG.num("song_info.info_gap_y", 30)
local SONGINFO_INFO_MWIDTH = CFG.num("song_info.info_max_width", 540)

local PREIMAGE_ORIGIN_X = CFG.num("preimage.origin_x", 1278)
local PREIMAGE_ORIGIN_Y = CFG.num("preimage.origin_y", 146)
local PREIMAGE_SIZE_X = CFG.num("preimage.size_x", 504)
local PREIMAGE_SIZE_Y = CFG.num("preimage.size_y", 504)

local HEADER_OFFSET_X = CFG.num("header.offset_x", 1876)
local HEADER_BOX_TEXT_OFFSET_X = CFG.num("header.box_text_offset_x", 227)
local HEADER_BOX_TEXT_OFFSET_Y = CFG.num("header.box_text_offset_y", 12)
local HEADER_DIFF_ALPHA = CFG.num("header.diffselect_alpha", 0.4)
local HEADER_ARROW_OFFSET_Y = CFG.num("header.arrow_offset_y", 35)

local NAMEPLATE_BOX_FOLDED_SIZE_Y = CFG.num("nameplate.box_folded_size_y", 182)
local NAMEPLATE_SECONDARY_OFFSET_Y = CFG.num("nameplate.secondary_offset_y", 81)
local NAMEPLATE_BOX_START_X = CFG.num("nameplate.box_start_x", 0)
local NAMEPLATE_BOX_SPACING_X = CFG.num("nameplate.box_spacing_x", 384)
local NAMEPLATE_OFFSET_X = CFG.num("nameplate.offset_x", 27)
local NAMEPLATE_OFFSET_Y = CFG.num("nameplate.offset_y", 37)
local NAMEPLATE_HEIGHT = CFG.num("nameplate.height", 81)
local PUCHI_OFFSET_X = CFG.num("nameplate.puchi_offset_x", 60)

-- ── Init ──────────────────────────────────────────────────────────────────────

function M.init(g)
    G = g
end

-- ── Local utilities ───────────────────────────────────────────────────────────

local function formatDuration(ms)
    if ms <= 0 then return "?:??" end
    local totalSec = math.floor(ms / 1000)
    return string.format("%d:%02d", math.floor(totalSec / 60), totalSec % 60)
end

local function formatNumber(n, decimals)
    local s = string.format("%." .. decimals .. "f", n)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    return s
end

local function formatLevel(str)
    return (str:gsub("%.0$", ""))
end

-- lv = the slot's cached { lv, lvDecimal, diff, isPlus, isVault } (nil when the node has no chart)
local function drawLevelTag(lv, x, y)
    if lv == nil then return end
    local labelH = G.bars["levellabels"].Height / 5
    local labelW = G.bars["levellabels"].Width

    if lv.isVault then
        -- Vault songs: animated strip (same frame counter as storm)
        G.bars["levellabelsvault"]:DrawRectAtAnchor(x, y, 0, labelH * G.levelLabelFrame, labelW, labelH, "center")
    elseif lv.diff < 3 or lv.lv <= 10 then
        G.bars["levellabels"]:DrawRectAtAnchor(x, y, 0, labelH * lv.diff, labelW, labelH, "center")
    elseif lv.diff == 3 then
        G.bars["levellabelsfire"]:DrawRectAtAnchor(x, y, 0, labelH * G.levelLabelFrame, labelW, labelH, "center")
    else
        G.bars["levellabelsstorm"]:DrawRectAtAnchor(x, y, 0, labelH * G.levelLabelFrame, labelW, labelH, "center")
    end

    G.textLarge:Draw(formatLevel(tostring(lv.lvDecimal)), x + SONGBAR_LEVEL_X_OFFSET, y + SONGBAR_LEVEL_Y_OFFSET, nil, nil, G.songSelectElemOpacity / 255, 1, 120, "center")
end

-- Draw fav.png at x=39 y=80 relative to bar.png top-left (the favorite flag is cached in the page slot).
local function drawFavIcon(xpos, ypos)
    if G.favoriteicon == nil then return end
    local bar_tl_x = xpos - G.bars["bar"].Width  / 2
    local bar_tl_y = ypos - G.bars["bar"].Height / 2
    G.favoriteicon:Draw(bar_tl_x + FAV_ICON_OFFSET_X, bar_tl_y + FAV_ICON_OFFSET_Y)
end

-- bl = the slot's cached { played, cs, sr } best-score info (nil when the node has no chart)
local function drawBarleft(bl, xpos, ypos)
    local barW = G.bars["bar"].Width
    local barH = G.bars["bar"].Height
    local lx   = xpos - barW / 2 + BARLEFT_X_OFFSET
    local ly   = ypos - barH / 2

    G.bars["barleft"]:Draw(lx, ly)

    if bl == nil then
        G.bars["scorerank_none"]:Draw(lx, ly)
        G.bars["clearstatus_none"]:Draw(lx, ly)
        return
    end

    local played = bl.played
    local cs     = bl.cs
    local sr     = bl.sr

    -- cs stored: 0=never played/failed, 1=assisted, 2=clear, 3=FC, 4=perfect.
    if not played then
        G.bars["clearstatus_none"]:Draw(lx, ly)
        G.bars["scorerank_none"]:Draw(lx, ly)
    elseif cs == 0 then
        -- Played but failed
        G.bars["clearstatus_m1"]:Draw(lx, ly)
        if sr == 0 then
            G.bars["scorerank_m1"]:Draw(lx, ly)
        else
            G.bars["scorerank_" .. (sr - 1)]:Draw(lx, ly)
        end
    else
        G.bars["clearstatus_" .. (cs - 1)]:Draw(lx, ly)
        if sr == 0 then
            G.bars["scorerank_m1"]:Draw(lx, ly)
        else
            G.bars["scorerank_" .. (sr - 1)]:Draw(lx, ly)
        end
    end
end

local function drawPreimage()
    local sel = G.selInfo
    if sel == nil or not sel.isSong or sel.hi >= 2 then return end
    
    if G.activeScreen == "songselect" then
        G.bgtx["load"]:DrawAtAnchor(PREIMAGE_ORIGIN_X + PREIMAGE_SIZE_X / 2, PREIMAGE_ORIGIN_Y + PREIMAGE_SIZE_Y / 2, "center")
        G.bgtx["load"]:SetOpacity(G.songSelectElemOpacity / 255)
    else
        G.bgtx["load"]:SetOpacity(0)
    end

    local tex = SHARED:GetSharedTexture("preimage")
    if tex.Height > 0 and tex.Width > 0 then
        -- Pop-in: scale the jacket around its centre from pop_start_scale up to 1.0 with a short overshoot
        -- when a new one appears (navigation.lua drives G.preimagePopScale). Centre-anchored so it grows in place.
        local pop = G.preimagePopScale or 1
        -- one scale for both axes: a jacket that is not square fits inside the frame, centred
        local fit = math.min(PREIMAGE_SIZE_X / tex.Width, PREIMAGE_SIZE_Y / tex.Height) * pop
        tex:SetScale(fit, fit)
        tex:DrawAtAnchor(PREIMAGE_ORIGIN_X + PREIMAGE_SIZE_X / 2, PREIMAGE_ORIGIN_Y + PREIMAGE_SIZE_Y / 2, "center")
        tex:SetScale(1, 1)
    end
end

-- ── Song-list bar drawing (shared by the normal list + the folder open/close animation) ─────
local function drawBarTitle(pt, x, y)
    G.text:Draw(pt.text, x, y, pt.gold and SONGLIST_GOLD or nil, nil, G.songSelectElemOpacity / 255, 1, SONGLIST_TEXT_MWIDTH, "center")
end

-- Draw one song-list bar's full visuals (bar art + overlays + title + level tag) at (xpos, ypos).
local function drawBar(tx, xpos, ypos)
    if tx == nil then return end
    if tx.isSong or tx.isFolder then
        if tx.isSong and tx.vaultLocked then
            G.bars["vault_bar"]:DrawAtAnchor(xpos, ypos, "center")
            if G.bars[tx.vaultLockKey] then
                G.bars[tx.vaultLockKey]:DrawAtAnchor(xpos - G.bars["bar"].Width / 2, ypos, "left")
            end
        elseif tx.isFolder and tx.vaultFolder then
            G.bars["bar"]:SetColor(tx.boxColor)
            G.bars["bar"]:DrawAtAnchor(xpos, ypos, "center")
            G.unlocks.drawBluredStatic(xpos, ypos)
            if G.bars["vault_lockF"] then G.bars["vault_lockF"]:DrawAtAnchor(xpos, ypos, "center") end
        elseif tx.isLocked then
            if tx.lockedBarOverride then
                G.bars["bar_1"]:DrawAtAnchor(xpos, ypos, "center")
            else
                G.bars["bar"]:SetColor(tx.boxColor)
                G.bars["bar"]:DrawAtAnchor(xpos, ypos, "center")
                G.genre_overlays[tx.genre]:DrawAtAnchor(xpos, ypos, "center")
            end
            if tx.hi == 2 then
                G.unlocks.drawBluredStatic(xpos, ypos)
            else
                drawBarTitle(tx, xpos + SONGLIST_TEXT_OFFSET_X, ypos + SONGLIST_TEXT_OFFSET_Y)
            end
            if tx.lockKey and G.bars[tx.lockKey] then
                G.bars[tx.lockKey]:DrawAtAnchor(xpos - G.bars["bar"].Width / 2, ypos, "left")
            end
            if tx.isSong and tx.hi == 0 then
                drawLevelTag(tx.level, xpos + SONGBAR_LABEL_X_OFFSET, ypos)
            end
        else
            G.bars["bar"]:SetColor(tx.boxColor)
            G.bars["bar"]:DrawAtAnchor(xpos, ypos, "center")
            G.genre_overlays[tx.genre]:DrawAtAnchor(xpos, ypos, "center")
            if tx.fav then drawFavIcon(xpos, ypos) end
            if tx.isSong then drawBarleft(tx.barleft, xpos, ypos) end
            drawLevelTag(tx.level, xpos + SONGBAR_LABEL_X_OFFSET, ypos)
            drawBarTitle(tx, xpos + SONGLIST_TEXT_OFFSET_X, ypos + SONGLIST_TEXT_OFFSET_Y)
        end
    elseif tx.isRandom then
        G.bars["random"]:DrawAtAnchor(xpos, ypos, "center")
        drawBarTitle(tx, xpos + SONGLIST_TEXT_OFFSET_X, ypos + SONGLIST_TEXT_OFFSET_Y)
    elseif tx.isReturn then
        G.bars["back"]:DrawAtAnchor(xpos, ypos, "center")
        drawBarTitle(tx, xpos + SONGLIST_TEXT_OFFSET_X, ypos + SONGLIST_TEXT_OFFSET_Y)
    end
end
M.drawBar = drawBar

-- Rest position of the bar at page offset i (dist = the in-flight scroll amount, 0 at rest).
function M.barPos(i, dist)
    dist = dist or 0
    local xpos = SONGLIST_ORIGIN_X + (i + dist) * SONGLIST_OFFSET_X
    local ypos = SONGLIST_ORIGIN_Y + (i + dist) * SONGLIST_OFFSET_Y
    if i == 0 then xpos = xpos + SONGLIST_SELECTED_X_DIFF end
    return xpos, ypos
end

-- the list slot (-7..7) whose bar is under (mx, my), or nil (mouse support)
function M.hitTest(mx, my)
    local tex = G.bars["bar"]
    if tex == nil or G.pageTexts == nil then return nil end
    local hw, hh = tex.Width / 2, tex.Height / 2
    for i = -7, 7 do
        if G.pageTexts[i] ~= nil then
            local cx, cy = M.barPos(i, G.selectBoxDist)
            local lx, ly = mx - (cx - hw), my - (cy - hh)
            if lx >= BAR_HIT_LEFT and lx <= BAR_HIT_RIGHT and ly >= BAR_HIT_TOP and ly <= BAR_HIT_BOTTOM then return i end
        end
    end
    return nil
end

-- ── The shortcuts helper line: white glyph text on a rounded dark box sized to it ─────────
local helperBox = nil          -- { canvas, w, h, text }: rebaked when the text changes (language, binding)
local function drawHelperLine(text, opacity)
    local gf = G.textStats
    local inkH = math.ceil(gf.LineHeight)
    local pad = gf.BoxHeight - inkH            -- the glyph box's padding around the ink
    if helperBox == nil or helperBox.text ~= text then
        if helperBox ~= nil then helperBox.canvas:Dispose() end
        local w = math.ceil(gf:Measure(text)) + 2 * HELPER_PAD_X
        local h = inkH + 2 * HELPER_PAD_Y
        local cv = CANVAS:CreateCanvas(w, h)
        cv:ClearTransparent()
        local r = math.max(0, math.min(HELPER_BOX_RADIUS, math.floor(h / 2)))
        cv:FillRect(r, 0, w - 2 * r, h, 0, 0, 0, HELPER_BOX_ALPHA)
        cv:FillRect(0, r, w, h - 2 * r, 0, 0, 0, HELPER_BOX_ALPHA)
        for _, c in ipairs({ { r, r }, { w - r - 1, r }, { r, h - r - 1 }, { w - r - 1, h - r - 1 } }) do
            cv:FillCircle(c[1], c[2], r, 0, 0, 0, HELPER_BOX_ALPHA)
        end
        cv:Upload()
        helperBox = { canvas = cv, w = w, h = h, text = text }
    end
    helperBox.canvas:SetOpacity(opacity)
    helperBox.canvas:Draw(HELPER_X, HELPER_Y)
    helperBox.canvas:SetOpacity(1)
    gf:Draw(text, HELPER_X + HELPER_PAD_X - pad, HELPER_Y + HELPER_PAD_Y, COL_WHITE, COL_BLACK, opacity, 1, 0, "topleft")
end

-- ── Folder open/close animation ─────────────────────────────────────────────────
-- Driven by G.folderAnim (set up in navigation.lua): { mode="open"/"close", phase=1/2, t=0..1,
-- oldBars/newBars = { {i, pt}, ... } sorted outer-first, folderPt = the folder's own bar }.
-- t is the phase counter's value, already EASED by the counter (navigation sets SetEasing per phase),
-- so drawing is a plain lerp between the bars' rest slots (M.barPos) and the off-screen / centre point.
local ANIM_OFFLEFT_X = CFG.num("folder_anim.offscreen_left_x", -1000)  -- where bars slide out to / in from
local function lerp(a, b, t) return a + (b - a) * t end

local function drawFolderAnim()
    local fa = G.folderAnim
    local cx, cy = M.barPos(0, 0)
    local t = fa.t or 0
    if fa.mode == "open" then
        if fa.phase == 1 then
            -- slide the parent siblings out to the left; the opened folder bar stays centred
            for _, b in ipairs(fa.oldBars) do
                local bx, by = M.barPos(b.i, 0)
                drawBar(b.pt, lerp(bx, ANIM_OFFLEFT_X, t), by)
            end
            drawBar(fa.folderPt, cx, cy)
        else
            -- fan the folder's contents out from the centre into their slots ("opening a book")
            for _, b in ipairs(fa.newBars) do
                local bx, by = M.barPos(b.i, 0)
                drawBar(b.pt, lerp(cx, bx, t), lerp(cy, by, t))
            end
        end
    else
        if fa.phase == 1 then
            -- group the folder's contents back toward the focused spot
            for _, b in ipairs(fa.oldBars) do
                local bx, by = M.barPos(b.i, 0)
                drawBar(b.pt, lerp(bx, cx, t), lerp(by, cy, t))
            end
        else
            -- the folder bar sits at the focus; the parent siblings slide back in from the left
            drawBar(fa.folderPt, cx, cy)
            for _, b in ipairs(fa.newBars) do
                local bx, by = M.barPos(b.i, 0)
                drawBar(b.pt, lerp(ANIM_OFFLEFT_X, bx, t), by)
            end
        end
    end
end
M.drawFolderAnim = drawFolderAnim

-- ── Header breadcrumb (shared by the normal draw + the folder open/close animation) ──
-- Draw one crumb: its box + title, right edge at xRight, with alpha; plus its connecting arrow (to the left).
local function drawCrumb(title, xRight, alpha, drawArrow)
    local boxW = G.bgtx["header-box"].Width
    local boxH = G.bgtx["header-box"].Height
    G.bgtx["header-box"]:SetOpacity(alpha)
    G.bgtx["header-box"]:DrawAtAnchor(xRight, 0, "topright")
    G.text:Draw(title, xRight - boxW + HEADER_BOX_TEXT_OFFSET_X,
        HEADER_BOX_TEXT_OFFSET_Y + boxH / 2, nil, nil, alpha, 1, 270, "center")
    if drawArrow then
        G.bgtx["header-arrow"]:SetOpacity(alpha)
        G.bgtx["header-arrow"]:DrawAtAnchor(xRight - boxW, HEADER_ARROW_OFFSET_Y, "topright")
    end
    G.bgtx["header-box"]:SetOpacity(1)
    G.bgtx["header-arrow"]:SetOpacity(1)
end

-- Header path animation, synced to G.folderAnim (same mode/phase/t as the song-list animation).
-- Opening: existing crumbs slide left (phase 1), the new folder crumb fades in (phase 2).
-- Closing: the innermost crumb fades out (phase 1), the remaining crumbs slide right (phase 2).
local function drawHeaderCrumbsAnim(opacityNorm)
    local fa  = G.folderAnim
    local old = fa.oldCrumbs or {}
    local new = (G.selInfo and G.selInfo.crumbs) or {}
    local SLOT = G.bgtx["header-box"].Width + G.bgtx["header-arrow"].Width
    local X0   = HEADER_OFFSET_X
    local t    = fa.t or 0
    local function slotX(s) return X0 - s * SLOT end

    if fa.mode == "open" then
        local N = #old                     -- new path = { opened folder } ++ old
        for j = 1, N do                    -- existing crumbs move from slot (j-1) to slot j
            local x = (fa.phase == 1) and slotX(lerp(j - 1, j, t)) or slotX(j)
            drawCrumb(old[j], x, opacityNorm, j < N)
        end
        if fa.phase == 2 and new[1] ~= nil then
            drawCrumb(new[1], slotX(0), opacityNorm * t, #new > 1)   -- new folder crumb fades in
        end
    else
        local N = #old                     -- old path = { closed folder } ++ new
        for k = 2, N do                    -- remaining crumbs slide from slot (k-1) to slot (k-2)
            local x = (fa.phase == 1) and slotX(k - 1) or slotX(lerp(k - 1, k - 2, t))
            drawCrumb(old[k], x, opacityNorm, k < N)
        end
        if fa.phase == 1 and old[1] ~= nil then
            drawCrumb(old[1], slotX(0), opacityNorm * (1 - t), N > 1)   -- innermost crumb fades out
        end
    end
end
M.drawHeaderCrumbsAnim = drawHeaderCrumbsAnim

-- ── Draw panel ────────────────────────────────────────────────────────────────

function M.drawPanel()
    local opacityNorm = G.songSelectElemOpacity / 255
    local sel = G.selInfo

    -- Random / song info panels (all node-derived data comes from the selection cache — see navigation.lua)
    if sel ~= nil and sel.isRandom then
        G.bgtx["randominfo"]:DrawAtAnchor(1920, 0, "topright")
    end

    if sel ~= nil and sel.isSong then
        -- BLURED / vault locked: skip the song info panel entirely
        if sel.hi < 2 then
            G.bgtx["songinfo"]:DrawAtAnchor(1920, 0, "topright")
            if sel.hasVideo then
                G.bgtx["sinfo_video"]:Draw(SONGINFO_HASVIDEO_ORIGIN_X, SONGINFO_HASVIDEO_ORIGIN_Y)
            end
            if sel.explicit then
                G.bgtx["sinfo_explicit"]:DrawAtAnchor(
                    SONGINFO_EXPLICIT_ORIGIN_X, SONGINFO_EXPLICIT_ORIGIN_Y, "topright")
            end

            -- Difficulty icons: hidden for GRAYED and above
            if sel.hi == 0 then
                local isVaultSong = sel.isVault
                    
                for i = 0, 4 do
                    local chart = sel.diffs[i]
                    local xpos  = SONGINFO_DIFFICULTIES_ORIGIN_X
                    local ypos  = SONGINFO_DIFFICULTIES_ORIGIN_Y + SONGINFO_DIFFICULTIES_GAP_Y * math.min(i, 4)
                        
                    if chart ~= nil then
                        local difftx = isVaultSong and G.bgtx["sinfo_difficulties_vault"] or G.bgtx["sinfo_difficulties_" .. i]
                        difftx:Draw(xpos, ypos)
                        difftx:SetOpacity(opacityNorm)

                        G.textLarge:Draw(
                            formatLevel(tostring(chart.levelDecimal)),
                            xpos + SONGINFO_DIFFICULTIES_LEVEL_ORIGIN_X, ypos + SONGINFO_DIFFICULTIES_LEVEL_ORIGIN_Y, 
                            nil, nil, opacityNorm, 1, 115, "center"
                        )
                    elseif chart == nil then
                        -- Vault songs: never show the "missing" indicator
                        if not isVaultSong then
                            G.bgtx["sinfo_difficulties_missing"]:Draw(xpos, ypos)
                            G.bgtx["sinfo_difficulties_missing"]:SetOpacity(opacityNorm)
                        end
                    end
                end
            end

            G.textSmall:Draw(sel.subtitle, SONGINFO_SUBTITLE_ORIGIN_X, SONGINFO_SUBTITLE_ORIGIN_Y,
                nil, nil, 1, 1, SONGINFO_SUBTITLE_MWIDTH, "center")
            G.textSmall:Draw(sel.charter, SONGINFO_INFO_ORIGIN_X, SONGINFO_INFO_ORIGIN_Y,
                nil, nil, 1, 1, SONGINFO_INFO_MWIDTH)
            -- rebuild the length string only when the async preview load lands a new duration
            if sel.lenMs ~= G.previewDurationMs then
                sel.lenMs   = G.previewDurationMs
                sel.lenText = "Length - " .. formatDuration(sel.lenMs)
            end
            G.textSmall:Draw(sel.lenText, SONGINFO_INFO_ORIGIN_X, SONGINFO_INFO_ORIGIN_Y + SONGINFO_INFO_GAP_Y,
                nil, nil, 1, 1, SONGINFO_INFO_MWIDTH)

            if sel.bpmBase ~= nil then
                -- rebuild the BPM string/color only when the song-speed multiplier changes
                local mult = CONFIG.SONGSPEED:ToActual(CONFIG.SongSpeed)
                if sel.bpmMult ~= mult then
                    sel.bpmMult = mult
                    local bpmText = formatNumber(sel.bpmBase * mult, 3)
                    if sel.bpmBase ~= sel.bpmMin or sel.bpmBase ~= sel.bpmMax then
                        bpmText = bpmText .. " (" .. formatNumber(sel.bpmMin * mult, 3)
                               .. "-" .. formatNumber(sel.bpmMax * mult, 3) .. ")"
                    end
                    sel.bpmText  = bpmText
                    sel.bpmColor = (mult < 1) and COL_BPM_SLOW or (mult > 1) and COL_BPM_FAST or COL_WHITE
                end
                G.textSmall:Draw("BPM - " .. sel.bpmText, SONGINFO_BPM_ORIGIN_X, SONGINFO_BPM_ORIGIN_Y,
                    sel.bpmColor, nil, 1, 1, SONGINFO_BPM_MWIDTH, "center", 0, 0)
            end
        end
    end

    drawPreimage()

    if G.bars ~= nil then
        for _, bar in pairs(G.bars) do bar:SetOpacity(opacityNorm) end
    end
    if G.genre_overlays ~= nil then
        for _, overlay in pairs(G.genre_overlays) do overlay:SetOpacity(opacityNorm) end
    end

    -- Song list bars. While a folder is opening/closing, the animation owns the list (and hides the
    -- selected-bar frame + arrows); otherwise draw the normal diagonal list.
    if G.folderAnim ~= nil then
        drawFolderAnim()
    elseif G.pageTexts ~= nil then
        for i, tx in pairs(G.pageTexts) do
            local xpos, ypos = M.barPos(i, G.selectBoxDist)
            drawBar(tx, xpos, ypos)
        end

        -- Selected bar + animated arrows
        local x0     = SONGLIST_ORIGIN_X + SONGLIST_SELECTED_X_DIFF
        local y0     = SONGLIST_ORIGIN_Y
        local ax     = G.arrowsDistance
        local xlshift = ax * math.cos(7 * math.pi / 12)
        local ylshift = ax * math.sin(7 * math.pi / 12)
        -- local isUnlockedSong = sel ~= nil and sel.isSong and sel.isUnlockedSong
        G.bars["selected"]:DrawAtAnchor(x0, y0, "center")

        -- Left arrow shifts 67px further left when an unlocked song is selected to clear barleft
        local arrowLOffset = isUnlockedSong and BARLEFT_X_OFFSET or 0
        G.bars["selected-arrow-l"]:DrawAtAnchor(x0 - SONGLIST_SELECTED_ARROW_GAP/2 + xlshift + arrowLOffset, y0 - ylshift, "left")
        G.bars["selected-arrow-r"]:DrawAtAnchor(x0 + SONGLIST_SELECTED_ARROW_GAP/2 - xlshift, y0 + ylshift, "right")
    end

    -- Header breadcrumb
    G.bgtx["header"]:Draw(0, 0)
    G.bgtx["header"]:SetOpacity(1)
    -- Breadcrumbs: the folder open/close animation drives them (in sync with the list) while it runs.
    if G.folderAnim ~= nil then
        drawHeaderCrumbsAnim(opacityNorm)
    elseif sel ~= nil then
        local SLOT = G.bgtx["header-box"].Width + G.bgtx["header-arrow"].Width
        local X0   = HEADER_OFFSET_X
        for i, title in ipairs(sel.crumbs) do
            drawCrumb(title, X0 - (i - 1) * SLOT, opacityNorm, i ~= #sel.crumbs)
        end
    end

    SHARED:GetSharedTexture("header_overlay"):SetOpacity(opacityNorm)
    SHARED:GetSharedTexture("header_overlay"):Draw(0, 0)
    -- the shortcuts helper line under the overlay (song select only: it fades with the panel)
    local helper = G.shortcuts and G.shortcuts.helperText()
    if helper ~= nil and opacityNorm > 0 then
        local pulse = 0.5 + 0.5 * math.sin(2 * math.pi * (G.nowMs or 0) / HELPER_PULSE_MS)
        drawHelperLine(helper, opacityNorm * (HELPER_OPACITY_MIN + (1 - HELPER_OPACITY_MIN) * pulse))
    end

    -- Unlock conditions panel (shown when a locked song is highlighted)
    G.unlocks.drawCondsPanel()
    G.unlocks.drawVaultCondsPanel()

    -- Nameplates (the online lobby shows its players itself)
    if G.activeConfig.songOnly then return end
    local playerCount = CONFIG.PlayerCount
    G.highlightedPlayer = G.highlightedPlayer % playerCount

    G.bgtx["nameplate_info"]:SetOpacity(opacityNorm)
    do
        local x0       = NAMEPLATE_BOX_START_X
        local y0       = 1080 - NAMEPLATE_BOX_FOLDED_SIZE_Y
        local ssCharaX = x0 + G.bgtx["nameplate_info"].Width / 2
        G.bgtx["nameplate_info"]:Draw(x0, y0)
        G.drawPlayerChara(G.highlightedPlayer, ssCharaX, y0 + NAMEPLATE_OFFSET_Y, 1, 1, opacityNorm, false)
        G.drawPlayerPuchi(G.highlightedPlayer, ssCharaX - PUCHI_OFFSET_X, y0 + NAMEPLATE_OFFSET_Y + G.puchiSineY, 1, 1, opacityNorm, false, G.puchiIdxFrame)
        NAMEPLATE:DrawPlayerNameplate(x0 + NAMEPLATE_OFFSET_X, y0 + NAMEPLATE_OFFSET_Y, G.songSelectElemOpacity, G.highlightedPlayer)

        -- Perfect / FC / Clear counts for the highlighted player at the displayed difficulty
        -- (queried only when the player/course key changes — the counts are save-file scans)
        if G.textStats ~= nil then
            local diff = math.min(4, CONFIG:GetDefaultCourse(0))
            local sc = statsCache
            if sc.player ~= G.highlightedPlayer or sc.diff ~= diff then
                local sav = GetSaveFile(G.highlightedPlayer)
                sc.player, sc.diff = G.highlightedPlayer, diff
                sc.perfect = tostring(sav:GetClearStatusCount(diff, 4))
                sc.fc      = tostring(sav:GetClearStatusCount(diff, 3))
                sc.clear   = tostring(sav:GetClearStatusCount(diff, 2))
            end
            local function drawStat(n, x)
                G.textStats:Draw(n, x, 1058, COL_WHITE, nil, opacityNorm, 1, 0, "center")
            end
            drawStat(sc.perfect, 95)
            drawStat(sc.fc,     212)
            drawStat(sc.clear,  329)
        end
    end

    for i = 1, playerCount - 1 do
        local j    = i
        if j - 1 >= G.highlightedPlayer then j = j + 1 end
        local xpos    = NAMEPLATE_BOX_START_X + i * NAMEPLATE_BOX_SPACING_X
        local ypos    = 1080 - NAMEPLATE_SECONDARY_OFFSET_Y
        local portCx  = xpos + G.bgtx["nameplate_info"].Width / 2
        G.bgtx["placeholder_portrait"]:SetOpacity(opacityNorm)
        G.bgtx["placeholder_portrait"]:DrawAtAnchor(portCx, ypos, "bottom")
        G.bgtx["placeholder_portrait"]:SetOpacity(1)
        -- Draw Portrait.png over the placeholder if it loaded for this player slot
        local portrait = G.portraits ~= nil and G.portraits[j - 1]
        if portrait ~= nil and portrait.Loaded then
            local gm = CHARACTER:GetPlayerGradientMap(j - 1)
            if gm ~= nil then GRADIENT:SetActive(gm) end
            portrait:SetOpacity(opacityNorm)
            portrait:DrawAtAnchor(portCx, ypos, "bottom")
            portrait:SetOpacity(1)
            if gm ~= nil then GRADIENT:ClearActive() end
        end
        NAMEPLATE:DrawPlayerNameplate(xpos + NAMEPLATE_OFFSET_X, ypos, G.songSelectElemOpacity, j - 1)
    end
end

return M
