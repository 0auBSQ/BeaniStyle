---@diagnostic disable: undefined-global  -- TEXTURE/fps injected by CLuaScript at runtime
-- Up background 3: parallax (bg + cloud + note layers) with infinite horizontal scroll + per-player clear fade.
-- Ported from the old ScriptBG func: API to the ROActivity LuaTexture API.
-- Code from "Open-World Memories V2: Gleaming Sky".

local scrollLoopWidth = 1800

local bg1_ScrollX = 0
local bg2_ScrollX = 0
local bg3_ScrollX = 0

local tx = {}

function clearIn(player)
end

function clearOut(player)
end

function onStart()
    tx["BG.png"] = TEXTURE:CreateTextureSync("BG.png")
    tx["Scroll_1.png"] = TEXTURE:CreateTextureSync("Scroll_1.png")
    tx["Scroll_2.png"] = TEXTURE:CreateTextureSync("Scroll_2.png")

    -- random values to create initial depth
    bg1_ScrollX = 500
    bg2_ScrollX = 250
    bg3_ScrollX = 314
end

function update(timestamp, state)
    bg1_ScrollX = (bg1_ScrollX + (fps.deltaTime * 20)) % scrollLoopWidth
    bg2_ScrollX = (bg2_ScrollX + (fps.deltaTime * 27)) % scrollLoopWidth
    bg3_ScrollX = (bg3_ScrollX + (fps.deltaTime * 59)) % scrollLoopWidth
end

function draw(state)
    tx["BG.png"]:DrawRect(0, 0, bg1_ScrollX, 0, 1920, 288)
    tx["Scroll_1.png"]:DrawRect(0, 0, bg2_ScrollX, 0, 1920, 288)
    tx["Scroll_2.png"]:DrawRect(0, 0, bg3_ScrollX, 0, 1920, 288)
end

function onDestroy()
    for _, t in pairs(tx) do
        if t ~= nil then t:Dispose() end
    end
    tx = {}
end