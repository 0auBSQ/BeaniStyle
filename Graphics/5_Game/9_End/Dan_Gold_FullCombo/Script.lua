---@diagnostic disable: undefined-global  -- TEXTURE/fps injected by CLuaScript at runtime
-- BeaniStyle's "full combo" end animation (clear text turning into full combo text, then twinkling stars; en/ja art),
-- ported from the 0.6.0 ScriptBG API to the 0.6.1 background module API.

local x = { 499, 499, 499, 499, 499 }
local y = { 0, 0, 0, 0, 0 }

local animeCounter = { 0, 0, 0, 0, 0 }
local speed = 1

local fc_text_states = { 0, 0, 0, 0, 0 }
local fc_text_values = { 0, 0, 0, 0, 0 }
local starAnimeValue = { 0, 0, 0, 0, 0 }
local fc_effect = { 0, 0, 0, 0, 0 }
local fc_effect_state = { 0, 0, 0, 0, 0 }
local text_fc_move_y = 20

local effect_count = 39

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

local function resetPlayer(pos)
    animeCounter[pos] = 0
    fc_text_states[pos] = 0
    fc_text_values[pos] = 0
    starAnimeValue[pos] = 0
    fc_effect[pos] = 0
    fc_effect_state[pos] = 0
end

function clearIn(player)
end

function clearOut(player)
end

-- The old script reset every player's counters here; now only the player whose animation starts is reset,
-- so a player starting later no longer restarts the others.
function playEndAnime(player)
    resetPlayer(player + 1)
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
    loadTexture(textLang .. "/FullCombo_Text.png")
    loadTexture(textLang .. "/FullCombo_Text_Flash.png")

    -- a fresh start, as the old engine reloaded the script on every play
    for pos = 1, 5 do
        resetPlayer(pos)
    end
end

function update(timestamp, state)
    local pos = state.player + 1

    animeCounter[pos] = animeCounter[pos] + (speed * fps.deltaTime)
    local animeValue = animeCounter[pos]

    if fc_effect_state[pos] == 1 then
        fc_effect[pos] = fc_effect[pos] + (effect_count * 2 * speed * fps.deltaTime)

        if fc_effect[pos] > effect_count then
            fc_effect[pos] = 0
        end
    end

    if fc_effect_state[pos] == 0 and animeValue > 1.98 then
        fc_effect_state[pos] = 1
    end

    if animeValue < 1.10 then
        fc_text_states[pos] = 0
        fc_text_values[pos] = (animeValue - 0) / (1.10 - 0)
    elseif animeValue < 1.50 then
        fc_text_states[pos] = 1
        fc_text_values[pos] = (animeValue - 1.10) / (1.50 - 1.10)
    elseif animeValue < 1.71 then
        fc_text_states[pos] = 2
        fc_text_values[pos] = (animeValue - 1.50) / (1.71 - 1.50)
    elseif animeValue < 1.78 then
        fc_text_states[pos] = 3
        fc_text_values[pos] = (animeValue - 1.71) / (1.78 - 1.71)
    else
        fc_text_states[pos] = 4
        fc_text_values[pos] = 0
    end

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

    local clearText = textLang .. "/Clear_Text.png"
    local clearFlash = textLang .. "/Clear_Text_Flash.png"
    local fcText = textLang .. "/FullCombo_Text.png"
    local fcFlash = textLang .. "/FullCombo_Text_Flash.png"

    if animeValue < 1.23 then
        if animeValue > 0.31 then
            if animeValue > 1.0 then
                tx[clearText]:SetOpacity(toOpacity(255 - ((((animeValue - 1.0) / 0.30)) * 255 * 2)))
            else
                tx[clearText]:SetOpacity(toOpacity((((animeValue - 0.36) / 0.30)) * 255 * 2))
            end
            drawClearText(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y, (animeValue - 0.36) / 0.30, clearText)
        end

        if animeValue > 1.00 then
            local clearFlashOpacity = math.sin(math.min((animeValue - 1.00) * 2.50, 1) * math.pi) * 255
            tx[clearFlash]:SetOpacity(toOpacity(clearFlashOpacity))
            tx[clearFlash]:Draw(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y)
        end
    end

    -- FullCombo_Text keeps the opacity and scale it was last given (stage 3 sets them), as in the old API.
    if fc_text_states[pos] == 0 then
    elseif fc_text_states[pos] == 1 then
        local move_val = math.sin(fc_text_values[pos] * math.pi / 2.0)
        local move_y = move_val * text_fc_move_y
        tx[fcFlash]:SetOpacity(toOpacity(255 * move_val))
        tx[fcFlash]:Draw(origin_x + 365, origin_y - move_y)
    elseif fc_text_states[pos] == 2 then
        local move_val = math.cos(fc_text_values[pos] * math.pi / 2.0)
        local move_y = move_val * text_fc_move_y
        tx[fcText]:Draw(origin_x + 365, origin_y - move_y)
        tx[fcFlash]:SetOpacity(toOpacity(255 * move_val))
        tx[fcFlash]:Draw(origin_x + 365, origin_y - move_y)
    elseif fc_text_states[pos] == 3 then
        local scale = 1.0 - (math.sin(fc_text_values[pos] * math.pi) / 20.0)
        tx[fcText]:SetOpacity(toOpacity(255))
        tx[fcText]:SetScale(1.0, scale)
        tx[fcText]:Draw(origin_x + 365, origin_y - ((scale - 1.0) * 195))
    elseif fc_text_states[pos] == 4 then
        tx[fcText]:Draw(origin_x + 365, origin_y)
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
