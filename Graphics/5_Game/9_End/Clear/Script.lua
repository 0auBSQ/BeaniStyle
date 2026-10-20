---@diagnostic disable: undefined-global  -- TEXTURE/fps injected by CLuaScript at runtime
-- BeaniStyle's "clear" end animation (per-player text pop-in, flash and twinkling stars; en/ja art),
-- ported from the 0.6.0 ScriptBG API to the 0.6.1 background module API.

local x = { 499, 499, 499, 499, 499 }
local y = { 0, 0, 0, 0, 0 }

local animeCounter = { 0, 0, 0, 0, 0 }
local speed = 1

local starAnimeValue = { 0, 0, 0, 0, 0 }

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

local function drawClearText(text_x, text_y, value, name)
    local scale = 1.0 + (math.sin(math.min(value, 1) * math.pi) / 10.0)

    tx[name]:SetOpacity(toOpacity(value * 255 * 2))
    tx[name]:SetScale(1.0, scale)
    tx[name]:Draw(text_x, text_y - ((scale - 1.0) * 135))
end

local function drawStar(star_x, star_y, value)
    if value > 0 then
        local opacity = 255 - (math.max(math.min((value / 0.16) - 1.0, 1), 0) * 255)
        local scale = math.min(value / 0.16, 1)

        tx["Star.png"]:SetOpacity(toOpacity(opacity))
        tx["Star.png"]:SetScale(scale, scale)
        tx["Star.png"]:DrawAtAnchor(star_x, star_y, "center")
    end
end

function clearIn(player)
end

function clearOut(player)
end

-- The old script reset every player's counter here; now only the player whose animation starts is reset,
-- so a player starting later no longer restarts the others. (The star loop was never reset here.)
function playEndAnime(player)
    animeCounter[player + 1] = 0
end

function onStart()
    tx["Star.png"] = TEXTURE:CreateTexture("Star.png")
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

    loadTexture(textLang .. "/Clear_Text.png")
    loadTexture(textLang .. "/Clear_Text_Flash.png")

    -- a fresh start, as the old engine reloaded the script on every play
    animeCounter = { 0, 0, 0, 0, 0 }
    starAnimeValue = { 0, 0, 0, 0, 0 }
end

function update(timestamp, state)
    local pos = state.player + 1

    animeCounter[pos] = animeCounter[pos] + (speed * fps.deltaTime)

    if animeCounter[pos] > 1.78 then
        starAnimeValue[pos] = starAnimeValue[pos] + (speed * fps.deltaTime)
        if starAnimeValue[pos] > 1.57 then
            starAnimeValue[pos] = 0
        end
    end
end

function draw(state)
    local pos = state.player + 1
    local animeValue = animeCounter[pos]

    local origin_x = x[pos]
    local origin_y = y[pos]

    if animeValue > 0.31 then
        if animeValue > 1.0 then
        else
            tx[textLang .. "/Clear_Text.png"]:SetOpacity(toOpacity((((animeValue - 0.36) / 0.30)) * 255 * 2))
        end
        drawClearText(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y, (animeValue - 0.36) / 0.30, textLang .. "/Clear_Text.png")
    end

    if animeValue > 1.00 then
        local clearFlashOpacity = math.sin(math.min((animeValue - 1.00) * 2.50, 1) * math.pi) * 255
        tx[textLang .. "/Clear_Text_Flash.png"]:SetOpacity(toOpacity(clearFlashOpacity))
        tx[textLang .. "/Clear_Text_Flash.png"]:Draw(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y)
    end

    if animeValue > 1.78 then
        drawStar(origin_x + 709, origin_y + 24, starAnimeValue[pos])
        drawStar(origin_x + 893, origin_y + 24, starAnimeValue[pos] - 0.1)
        drawStar(origin_x + 526, origin_y + 24, starAnimeValue[pos] - 0.12)

        drawStar(origin_x + 590, origin_y + 169, starAnimeValue[pos] - 0.28)
        drawStar(origin_x + 948, origin_y + 148, starAnimeValue[pos] - 0.33)
        drawStar(origin_x + 466, origin_y + 143, starAnimeValue[pos] - 0.45)
        drawStar(origin_x + 815, origin_y + 170, starAnimeValue[pos] - 0.5)
    end
end

function onDestroy()
    for _, t in pairs(tx) do
        if t ~= nil then t:Dispose() end
    end
    tx = {}
end
