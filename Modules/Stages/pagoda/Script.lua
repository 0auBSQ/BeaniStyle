---@diagnostic disable: undefined-global, undefined-field
-- pagoda (generic): a climb of dan floors (Pagoda.Run), entered from the dojo (dan_select). Pick a starting
-- floor or practice; each floor shows its songs and exams before the play; a clear grants the floor's rewards
-- (pop-ups) and goes up one floor, a loss ends the run. Practice plays any floor reached so far and saves
-- nothing. Plain SimpleUI screens (Lib/GenericScreen.lua), no art of its own.

local Run = require("Pagoda.Run")
local Floor = require("Pagoda.Floor")
local Levels = require("Pagoda.Levels")
local Progress = require("Pagoda.Progress")
local Rewards = require("Pagoda.Rewards")
local Songs = require("Pagoda.Songs")
local S = require("GenericScreen")

local DIFF_NAMES = { [0] = "Easy", [1] = "Normal", [2] = "Hard", [3] = "Extreme", [4] = "Extra Extreme" }
local POOL_COLORS = { blue = { 70, 120, 200 }, green = { 70, 160, 100 }, red = { 200, 70, 60 }, purple = { 130, 80, 180 } }
local EXAM_TYPES = { g = 0, jp = 1, jg = 2, jb = 3, s = 4, r = 5, h = 6, c = 7, a = 8, ja = 9, jm = 10 }

local EXIT_TRANSITION = "dan_doors_back"   -- back to the dojo

local screen = "menu"        -- "loading", "missing", "menu", "practice", "floor", "result"
local ui = nil
local action = nil
local run = nil              -- the challenge run, kept across the plays
local practiceLevel = nil
local roll = nil
local awaiting = nil         -- "run" or "practice" while a play is under way
local savedSpeed = nil
local result = nil           -- { level, passed, practice }
local rewardQueue = {}
local rewardOn = false
local missing = 0            -- the pagoda's songs that are not installed

local function level() return run and run.level or practiceLevel end
local function diffName(d) return S.tr("SS_DIFF_" .. d, DIFF_NAMES[d] or "") end

local function closeUI()
    if ui ~= nil then ui:disposeWidgets() end
    ui = nil
end

local function newUI()
    closeUI()
    ui = S.newUI{ navPlayer = 1 }
    action = nil
    return ui
end

local function buttonRow(list, y)
    local w, gap = 360, 30
    local x = S.W - S.margin - (#list * w + (#list - 1) * gap)
    for i, b in ipairs(list) do
        local btn = ui:button{ text = b[1], x = x + (i - 1) * (w + gap), y = y, w = w, h = 80, accent = (i == 1),
            onClick = function() action = b[2] end }
        if i == 1 then ui:focus(btn) end
    end
end

local function floorMenu(items, h, rowHeight)
    ui:focus(ui:menu{ x = S.margin, y = S.headerH + 40, w = 700, h = h, rowHeight = rowHeight, items = items,
        scrollbar = #items * rowHeight > h, onSelect = function(_, it) action = it.value; return true end })
end

local function openWait(kind)
    screen = kind
    newUI()
    buttonRow({ { S.tr("COMMON_BACK", "Back"), "back" } }, S.H - S.footerH - 120)
end

local function openMenu()
    screen = "menu"
    newUI()
    local items = {}
    for _, lv in ipairs(Run.startOptions()) do
        items[#items + 1] = { text = S.trf("PAGODA_START_AT", "Climb from {floor}", { floor = Levels.level_name(lv) }), value = { start = lv } }
    end
    items[#items + 1] = { text = S.tr("PAGODA_PRACTICE", "Practice"), value = { practice = true } }
    floorMenu(items, #items * 76, 76)
end

local function openPractice()
    screen = "practice"
    newUI()
    local items = {}
    for _, lv in ipairs(Run.practiceLevels()) do items[#items + 1] = { text = Levels.level_name(lv), value = { level = lv } } end
    floorMenu(items, S.H - S.footerH - 70 - S.headerH, 72)
end

local function openFloor()
    screen = "floor"
    newUI()
    buttonRow({ { S.tr("COMMON_PLAY", "Play"), "play" }, { S.tr("COMMON_BACK", "Back"), "back" } }, S.H - S.footerH - 120)
end

local function openResult()
    screen = "result"
    newUI()
    local list = {}
    if result.passed and run ~= nil then list[#list + 1] = { S.tr("PAGODA_NEXT", "Next floor"), "next" } end
    list[#list + 1] = { S.tr("PAGODA_TO_MENU", "Back to the pagoda"), "menu" }
    buttonRow(list, S.H - S.footerH - 120)
end

-- the screen to show when nothing is under way: the songs must be listed and installed first
local function openStart()
    if IsSongsEnumerating() then openWait("loading"); return end
    missing = Songs.count_missing_songs() or 0
    if missing > 0 then openWait("missing"); return end
    openMenu()
end

local function startPlay(kind)
    local opts = { genre = S.tr("PAGODA_TITLE", "Pagoda") }
    local ok
    if kind == "run" then
        run:enter()
        ok = run:buildDan(opts)
    else
        ok = Floor.buildDan(practiceLevel, roll, opts)
    end
    if not ok or not DANBUILDER:Mount() then
        if run ~= nil then run.roll = roll end   -- the songs on screen stay this floor's
        S.sound("Error")
        return nil
    end
    savedSpeed = CONFIG.SongSpeed
    CONFIG.SongSpeed = (roll and roll.speed) or Floor.speed(level())
    CONFIG.PlayerCount = 1
    awaiting = kind
    S.sound("SongDecide")
    return Exit("play", nil)
end

-- back from a play: the result of the floor
local function onReturn()
    if savedSpeed ~= nil then CONFIG.SongSpeed = savedSpeed; savedSpeed = nil end
    local passed = PLAYSTATE:IsPass() and not PLAYSTATE:WasPlayAborted()
    local kind = awaiting
    awaiting = nil
    if kind == "run" then
        result = { level = run.level, passed = passed }
        if passed then
            local r = run:clear()
            for _, rw in ipairs(r.rewards) do rewardQueue[#rewardQueue + 1] = rw end
            roll = run:rollFloor()
        else
            run:fail()
            run = nil
        end
    else
        result = { level = practiceLevel, passed = passed, practice = true }
    end
    openResult()
end

function onStart()
end

function activate()
    S.resetKeys()
    Progress.migrate_save()
    rewardOn = false
    if awaiting ~= nil then onReturn() else openStart() end
end

function deactivate()
    Rewards.stop()
    rewardOn = false
    closeUI()
end

function afterSongEnum()
    Songs.clear_cache()
    Levels.clear_pools()
    if screen == "loading" or screen == "missing" then openStart() end
end

local function leave()
    S.sound("Cancel")
    run = nil
    return Exit("stage", "dan_select", EXIT_TRANSITION)
end

function update(ts)
    -- the rewards of a clear, one pop-up after the other
    if rewardOn then
        if Rewards.update() then return nil end
        rewardOn = false
    end
    if #rewardQueue > 0 then
        local r = table.remove(rewardQueue, 1)
        if Rewards.show(r) then rewardOn = true end
        return nil
    end

    action = nil
    local cancel = ui:update(ts) == "cancel"
    if screen == "loading" or screen == "missing" then
        if cancel or action == "back" then return leave() end
    elseif screen == "menu" then
        if cancel then return leave() end
        if action and action.start then
            S.sound("Decide")
            run = Run.new(action.start)
            roll = run:rollFloor()
            openFloor()
        elseif action and action.practice then
            S.sound("Decide"); openPractice()
        end
    elseif screen == "practice" then
        if cancel then S.sound("Cancel"); openMenu()
        elseif action and action.level then
            S.sound("Decide")
            run = nil
            practiceLevel = action.level
            roll = Floor.rollFloor(practiceLevel)
            openFloor()
        end
    elseif screen == "floor" then
        if cancel or action == "back" then
            S.sound("Cancel")
            if run ~= nil then run = nil; openMenu() else openPractice() end
        elseif action == "play" then
            return startPlay(run ~= nil and "run" or "practice")
        end
    elseif screen == "result" then
        if action == "next" and run ~= nil then S.sound("Decide"); openFloor()
        elseif action == "menu" or cancel then
            S.sound(cancel and "Cancel" or "Decide")
            run = nil
            openMenu()
        end
    end
end

-- ── drawing ─────────────────────────────────────────────────────────────────

local function examText(e)
    local name = LANG:GetExamName(EXAM_TYPES[e[1]] or 0) or e[1]
    local cmp = e[4] and "<" or ">="
    return string.format("%s  %s %d  /  %d", name, cmp, e[2], e[3])
end

local function drawNotice(title, line)
    local x, y, w = S.margin, S.headerH + 40, S.W - 2 * S.margin
    S.panel(x, y, w, 300)
    S.text(title, x + 60, y + 80, S.font.label, S.colors.text)
    S.wrapped(line, x + 60, y + 150, w - 120, S.font.body, S.colors.textDim)
end

local function drawProgress()
    local x, y, w = 820, S.headerH + 40, S.W - 820 - S.margin
    S.panel(x, y, w, 300)
    local hi = Progress.highest_level()
    local best = hi > 0 and Levels.level_name(hi) or "-"
    S.text(S.trf("PAGODA_BEST", "Highest floor cleared: {floor}", { floor = best }), x + 40, y + 40, S.font.body, S.colors.text)
    local reach = Progress.highest_reached()
    S.text(S.trf("PAGODA_REACHED", "Highest floor reached: {floor}", { floor = reach > 0 and Levels.level_name(reach) or "-" }),
        x + 40, y + 110, S.font.body, S.colors.text)
    S.text(S.trf("PAGODA_PLAYS", "Runs played: {n}", { n = Progress.plays() }), x + 40, y + 180, S.font.body, S.colors.text)
end

-- ── what a floor tells of its songs ──────────────────────────────────────────
-- The pagoda's songs are unknown until the climb gets past them. Counted from the highest floor cleared:
-- one floor under it the floor tells whether a mystery (purple) song comes; two, three and four floors
-- under it names one, two, then all three base songs, and the mystery song from two under. Above that a
-- mystery row shows only its chance (none when the chance is 0). Floor DESTINY_LEVEL never names its
-- mystery song.
local DESTINY_LEVEL = 20

-- a number from a string, the same for the same string (which base songs get named first)
local function hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
    return h
end

local function nodeId(node)
    local ok, id = pcall(function() return node.UniqueId or node.Title end)
    return (ok and id) or ""
end

-- the rows of a floor, top to bottom: { color, title (nil = unknown), diff (nil = unknown), chance }
local function floorRows(lv, r)
    local rows = {}
    if r == nil then return rows, false end
    local gap = Progress.highest_level() - lv
    local named = math.max(0, math.min(3, gap - 1))
    local base = {}
    for _, it in ipairs(r.songs or {}) do
        local row = { color = it.color, node = it.node, diff = it.entry and it.entry.diff or 3,
                      rank = hash(nodeId(it.node) .. "|" .. lv) }
        rows[#rows + 1] = row
        base[#base + 1] = row
    end
    table.sort(base, function(a, b) return a.rank < b.rank end)
    for i = 1, named do if base[i] ~= nil then base[i].title = base[i].node.Title or "?" end end

    local known = false              -- the floor told whether a mystery song comes
    local chance = math.floor(Levels.purple_prob(lv) * 100 + 0.5)
    if r.purple ~= nil and (lv == DESTINY_LEVEL or gap >= 1) then
        local row = { color = "purple", node = r.purple.node, diff = r.purple.entry and r.purple.entry.diff or 3 }
        if gap >= 2 and lv ~= DESTINY_LEVEL then row.title = row.node.Title or "?" end
        rows[#rows + 1] = row
        known = true
    elseif gap >= 1 then
        known = true                 -- no mystery song this time, and the floor says so
    elseif chance > 0 then
        rows[#rows + 1] = { color = "purple", chance = chance }
    end
    return rows, known
end

local function drawFloor()
    local lv = level()
    local x, y, w = S.margin, S.headerH + 40, S.W - 2 * S.margin
    S.panel(x, y, w, 720)
    local plate = ROACTIVITY:GetROActivity("danplate")
    local tc = Levels.level_tick_color(lv)
    if plate ~= nil then plate:Draw(x + 150, y + 250, 255, Levels.level_tick(lv), tc[1], tc[2], tc[3], Levels.level_name(lv)) end
    S.text(Levels.level_name(lv), x + 300, y + 80, S.font.big, S.colors.text)
    local sub = run and S.tr("PAGODA_CHALLENGE", "Challenge") or S.tr("PAGODA_PRACTICE", "Practice")
    S.text(sub, x + 300, y + 170, S.font.body, S.colors.textDim)

    local yy = y + 320
    S.text(S.tr("DAN_SONGS", "Songs"), x + 300, yy, S.font.label, S.colors.text)
    yy = yy + 60
    local rows, known = floorRows(lv, roll)
    local unknown = S.tr("PAGODA_UNKNOWN", "???")
    for i, row in ipairs(rows) do
        S.rect(x + 300, yy, 12, 48, POOL_COLORS[row.color] or S.colors.primary)
        local title = row.title or unknown
        if row.chance ~= nil then
            title = S.trf("PAGODA_MYSTERY_CHANCE", "??? ({n}% chance of a mystery song)", { n = row.chance })
        end
        S.text(string.format("%d.  %s", i, title), x + 332, yy + 24, S.font.body,
            row.title and S.colors.text or S.colors.textDim, "left", 1, 600)
        if row.diff ~= nil then S.text(diffName(row.diff), x + 960, yy + 24, S.font.body, S.colors.textDim, "left") end
        yy = yy + 60
    end

    local ex, ey = x + 1220, y + 320
    S.text(S.tr("DAN_EXAMS", "Exams"), ex, ey, S.font.label, S.colors.text)
    ey = ey + 60
    -- the mystery song changes the exams only once the floor told it comes
    for _, e in ipairs(Floor.exams(lv, known and roll ~= nil and roll.purple ~= nil)) do
        S.text(examText(e), ex, ey, S.font.body, S.colors.text, "topleft", 1, w - 1220 - 40)
        ey = ey + 54
    end
end

local function drawResult()
    local x, y, w = S.margin, S.headerH + 40, S.W - 2 * S.margin
    S.panel(x, y, w, 520)
    local name = Levels.level_name(result.level)
    local title = result.passed and S.trf("PAGODA_CLEARED", "{floor} cleared", { floor = name })
        or S.trf("PAGODA_FAILED", "{floor} failed", { floor = name })
    S.rect(x, y, 12, 520, result.passed and S.colors.good or S.colors.bad)
    S.text(title, x + 80, y + 80, S.font.big, S.colors.text)
    local line
    if result.practice then line = S.tr("PAGODA_PRACTICE_DONE", "Practice plays save nothing.")
    elseif result.passed then line = S.trf("PAGODA_NEXT_IS", "Next: {floor}", { floor = Levels.level_name(result.level + 1) })
    else line = S.tr("PAGODA_RUN_OVER", "The run is over.") end
    S.text(line, x + 80, y + 200, S.font.label, S.colors.textDim)
end

function draw()
    S.clear()
    S.header(S.tr("PAGODA_TITLE", "Pagoda"))
    if screen == "loading" then
        drawNotice(S.tr("PAGODA_LOADING", "Loading songs..."), S.tr("PAGODA_LOADING_DESC", "The pagoda opens once the song list is ready."))
    elseif screen == "missing" then
        drawNotice(S.tr("PAGODA_MISSING", "Songs are missing"),
            S.trf("PAGODA_MISSING_DESC", "{n} songs of the pagoda are not installed. Install them to climb the pagoda.", { n = missing }))
    elseif screen == "menu" then drawProgress()
    elseif screen == "floor" then drawFloor()
    elseif screen == "result" then drawResult() end
    if ui ~= nil then ui:draw() end
    S.footer({ { S.key("decide"), S.tr("COMMON_SELECT", "Select") }, { S.key("cancel"), S.tr("COMMON_BACK", "Back") } })
    if rewardOn then Rewards.draw() end
end

function onDestroy()
    closeUI()
    S.dispose()
end
