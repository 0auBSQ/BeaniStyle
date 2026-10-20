---@diagnostic disable: undefined-global  -- TEXTURE/fps injected by CLuaScript at runtime
-- BeaniStyle's "failed" end animation (per-player text that fades in, flashes, then settles; en/ja art),
-- ported from the 0.6.0 ScriptBG API to the 0.6.1 background module API.

local x = { 499, 499, 499, 499, 499 }
local y = { 0, 0, 0, 0, 0 }

local animeCounter = { 0, 0, 0, 0, 0 }
local speed = 1

local clear_text_offset_x = 373
local clear_text_offset_y = -3

local textLang = "en"

local tx = {}

-- The old API took opacity as 0..255 (the engine truncated and clamped it); LuaTexture takes 0..1.
local function toOpacity(v)
    return math.max(0, math.min(v, 255)) / 255
end

-- Create a texture once; activate runs again on a retry, and must not load it twice.
local function loadTexture(name)
    if tx[name] == nil then
        tx[name] = TEXTURE:CreateTexture(name)
    end
    return tx[name]
end

function clearIn(player)
end

function clearOut(player)
end

-- The old script reset every player's counter here; now only the player whose animation starts is reset,
-- so a player starting later no longer restarts the others.
function playEndAnime(player)
    animeCounter[player + 1] = 0
end

function activate(state)
    if state.playerCount <= 2 then
        y = { 288, 552, 0, 0, 0 }
    elseif state.playerCount == 5 then
        y = { 58, 274, 490, 706, 922 }
    else
        y = { 69, 333, 597, 861, 0 }
    end

    textLang = "en"
    if state.lang == "ja" then
        textLang = "ja"
    end

    loadTexture(textLang .. "/Failed_Text_1.png")
    loadTexture(textLang .. "/Failed_Text_2.png")
    loadTexture(textLang .. "/Failed_Text_3.png")

    -- a fresh start, as the old engine reloaded the script on every play
    animeCounter = { 0, 0, 0, 0, 0 }
end

function update(timestamp, state)
    local pos = state.player + 1

    animeCounter[pos] = animeCounter[pos] + (speed * fps.deltaTime)
end

function draw(state)
    local pos = state.player + 1
    local animeValue = animeCounter[pos]

    local origin_x = x[pos]
    local origin_y = y[pos]

    if animeValue < 0.31 then
    elseif animeValue < 2.28 then
        tx[textLang .. "/Failed_Text_1.png"]:SetOpacity(toOpacity((animeValue - 0.31) * 255 * 4))
        tx[textLang .. "/Failed_Text_1.png"]:Draw(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y)
    elseif animeValue < 2.31 then
        tx[textLang .. "/Failed_Text_2.png"]:Draw(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y)
    else
        tx[textLang .. "/Failed_Text_3.png"]:Draw(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y)
    end
end

function onDestroy()
    for _, t in pairs(tx) do
        if t ~= nil then t:Dispose() end
    end
    tx = {}
end
