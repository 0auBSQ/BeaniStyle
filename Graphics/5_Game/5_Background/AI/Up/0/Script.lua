---@diagnostic disable: undefined-global  -- TEXTURE/fps injected by CLuaScript at runtime
-- BeaniStyle's AI battle upper background, ported from the old ScriptBG func: API to the background module API.

local inAnimeCounter = -20

local animeCounter = 0

local nowAnimeFrame = 0

local maxAnimeFrame = 5

local tx = {}

-- the old API drew at whole-pixel (truncated) positions
local function px(value)
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

function clearIn(player)
end

function clearOut(player)
end

function onStart()
    tx["Base.png"] = TEXTURE:CreateTextureSync("Base.png")
    tx["Frame.png"] = TEXTURE:CreateTextureSync("Frame.png")
    for i = 0 , 18 do
        tx["Up_1P/"..tostring(i)..".png"] = TEXTURE:CreateTextureSync("Up_1P/"..tostring(i)..".png")
        tx["Up_2P/"..tostring(i)..".png"] = TEXTURE:CreateTextureSync("Up_2P/"..tostring(i)..".png")

        tx["Down_1P/"..tostring(i)..".png"] = TEXTURE:CreateTextureSync("Down_1P/"..tostring(i)..".png")
        tx["Down_2P/"..tostring(i)..".png"] = TEXTURE:CreateTextureSync("Down_2P/"..tostring(i)..".png")
    end

    for i = 0 , maxAnimeFrame do
        tx["Animation/"..tostring(i)..".png"] = TEXTURE:CreateTextureSync("Animation/"..tostring(i)..".png")
    end
end

function activate(state)
    inAnimeCounter = -20
    animeCounter = 0
    nowAnimeFrame = 0
end

function update(timestamp, state)
    inAnimeCounter = inAnimeCounter + (20 * fps.deltaTime)

    animeCounter = animeCounter + (10 * fps.deltaTime)

    nowAnimeFrame = math.floor(animeCounter+0.5)

    if nowAnimeFrame > maxAnimeFrame then
        animeCounter = 0
        nowAnimeFrame = 0
    end
end

function draw(state)
    tx["Base.png"]:Draw(0, 0)

    for i = 0 , 18 do
        local pos = i - 9
        if 9 - math.abs(pos) <= inAnimeCounter then

            local offset1 = -(math.sin((pos / 9.0) * math.pi) * 10)

            local offset2 = 0

            if pos > 0 then
                offset2 = (math.cos((pos / 9.0) * math.pi) * 8)
            elseif pos < 0 then
                offset2 = -(math.cos((pos / 9.0) * math.pi) * 8)
            end

            local up_x = px(756 + (92 * pos) + offset1 + offset2)
            local up_y = 57

            local down_x = -48 + (106 * i)
            local down_y = 804

            if pos <= state.battleState then
                tx["Up_1P/"..tostring(i)..".png"]:Draw(up_x, up_y)
                tx["Down_1P/"..tostring(i)..".png"]:Draw(down_x, down_y)
            else
                tx["Up_2P/"..tostring(i)..".png"]:Draw(up_x, up_y)
                tx["Down_2P/"..tostring(i)..".png"]:Draw(down_x, down_y)
            end
        end
    end

    if inAnimeCounter > 9 then
        tx["Frame.png"]:Draw(0, 0)

        tx["Animation/"..tostring(nowAnimeFrame)..".png"]:Draw(0, 0)
    end
end

function onDestroy()
    for _, t in pairs(tx) do
        if t ~= nil then t:Dispose() end
    end
    tx = {}
end
