---@diagnostic disable: undefined-global  -- TEXTURE/fps injected by CLuaScript at runtime
-- BeaniStyle's AI battle result background, ported from the old ScriptBG func: API to the background module API.

local tx = {}

function clearIn(player)
end

function clearOut(player)
end

function onStart()
    tx["Background_1.png"] = TEXTURE:CreateTextureSync("Background_1.png")
    tx["Background_2.png"] = TEXTURE:CreateTextureSync("Background_2.png")
    tx["Header.png"] = TEXTURE:CreateTextureSync("Header.png")
end

function update(timestamp, state)
end

function draw(state)
    if state.battleWin then
        tx["Background_1.png"]:Draw(0, 0)
    else
        tx["Background_2.png"]:Draw(0, 0)
    end

    tx["Header.png"]:Draw(0, 0)
end

function onDestroy()
    for _, t in pairs(tx) do
        if t ~= nil then t:Dispose() end
    end
    tx = {}
end
