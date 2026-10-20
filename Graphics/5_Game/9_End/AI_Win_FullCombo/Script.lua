---@diagnostic disable: undefined-global  -- TEXTURE/fps injected by CLuaScript at runtime
-- BeaniStyle's AI battle end animation (Base.png zooms in from 2x and fades in at the screen centre),
-- ported from the 0.6.0 ScriptBG API to the 0.6.1 background module API.

local animeCounter = 0

local x = 960
local y = 540

local tx = {}

-- The old API took opacity as 0..255 (the engine truncated and clamped it); LuaTexture takes 0..1.
local function toOpacity(v)
    return math.max(0, math.min(v, 255)) / 255
end

function clearIn(player)
end

function clearOut(player)
end

function playEndAnime(player)
    animeCounter = 0
end

function onStart()
    tx["Base.png"] = TEXTURE:CreateTexture("Base.png")
end

function activate(state)
    -- a fresh start, as the old engine reloaded the script on every play
    animeCounter = 0
end

function update(timestamp, state)
    animeCounter = animeCounter + (1.0 * fps.deltaTime)
end

function draw(state)
    local value = math.min(animeCounter * 3, 1)
    local scale = 2 - value

    tx["Base.png"]:SetOpacity(toOpacity(value * 255))
    tx["Base.png"]:SetScale(scale, scale)

    tx["Base.png"]:DrawAtAnchor(x, y, "center")
end

function onDestroy()
    for _, t in pairs(tx) do
        if t ~= nil then t:Dispose() end
    end
    tx = {}
end
