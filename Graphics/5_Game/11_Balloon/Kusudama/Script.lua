---@diagnostic disable: undefined-global  -- TEXTURE/fps injected by CLuaScript at runtime
-- BeaniStyle's kusudama (giant balloon) effect, ported from the old ScriptBG func: API to the background module API.

local kusuState = 0

local origin_x = 960
local origin_y = 322

local animeValue = 0
local openFrame = 0
local effectFrame = 0
local effectOpacity = 255
local brokeOpacity = 255
local bgInOpacity = 0
local kusuInY = 0
local kusuInOverY = 100
local kusuMissY = 0
local kusuIdleScale = 1

local textLang = "en"

local tx = {}

-- the old API took opacities as 0..255 and drew at whole-pixel (truncated) positions
local function opacity(value)
    return math.max(0, math.min(value, 255)) / 255
end

local function px(value)
    if value >= 0 then return math.floor(value) end
    return math.ceil(value)
end

local function drawCenter(name, x, y)
    local t = tx[name]
    if t ~= nil then t:DrawAtAnchor(px(x), px(y), "center") end
end

local function drawTex(name, x, y)
    local t = tx[name]
    if t ~= nil then t:Draw(px(x), px(y)) end
end

local function setOpacity(name, value)
    local t = tx[name]
    if t ~= nil then t:SetOpacity(opacity(value)) end
end

function kusuIn()
    kusuState = 1
    animeValue = 0
end

function kusuBroke()
    kusuState = 3
    animeValue = 0
    brokeOpacity = 255
end

function kusuMiss()
    kusuState = 4
    animeValue = 0
end

function onStart()
    tx["Kusudama_Back.png"] = TEXTURE:CreateTextureSync("Kusudama_Back.png")

    tx["Kusudama_Idle.png"] = TEXTURE:CreateTextureSync("Kusudama_Idle.png")

    tx["Kusudama_Open_0.png"] = TEXTURE:CreateTextureSync("Kusudama_Open_0.png")
    tx["Kusudama_Open_1.png"] = TEXTURE:CreateTextureSync("Kusudama_Open_1.png")
    tx["Kusudama_Open_2.png"] = TEXTURE:CreateTextureSync("Kusudama_Open_2.png")

    tx["Kusudama_Miss.png"] = TEXTURE:CreateTextureSync("Kusudama_Miss.png")

    -- the language only arrives with activate(state), so both texts are loaded here
    tx["Text_en.png"] = TEXTURE:CreateTextureSync("Text_en.png")
    tx["Text_ja.png"] = TEXTURE:CreateTextureSync("Text_ja.png")

    for i = 0, 2 do
        local name = "Effect_" .. tostring(i) .. ".png"
        tx[name] = TEXTURE:CreateTextureSync(name)
        tx[name]:SetBlendMode("add")
    end
end

-- start state (also called by the engine to reset the kusudama on a restart or rewind)
function activate(state)
    kusuState = 0
    animeValue = 0
    openFrame = 0
    effectFrame = 0
    effectOpacity = 255
    brokeOpacity = 255
    bgInOpacity = 0
    kusuInY = 0
    kusuMissY = 0
    kusuIdleScale = 1

    tx["Kusudama_Idle.png"]:SetScale(1, 1)
    for i = 0, 2 do
        tx["Effect_" .. tostring(i) .. ".png"]:SetOpacity(1)
    end
    tx["Kusudama_Back.png"]:SetOpacity(1)
    tx["Kusudama_Open_2.png"]:SetOpacity(1)

    textLang = "en"
    if state.lang == "ja" then
        textLang = "ja"
    end
end

function update(timestamp, state)
    animeValue = animeValue + (1 * fps.deltaTime)

    if animeValue > 10 then
        animeValue = 10
    end

    effectFrame = effectFrame + (15 * fps.deltaTime)
    if effectFrame >= 2 then
        effectFrame = 0
    end

    if kusuState == 0 then
    elseif kusuState == 1 then

        bgInOpacity = math.sin(math.min(animeValue, 1) * 2 * math.pi) * 255
        effectOpacity = math.min(animeValue * 500, 255 / 2)
        local in1 = -700 + (math.sin(math.min(animeValue * 1.8, 0.5) * math.pi) * (700 + kusuInOverY))
        local in2 = ((1 - (math.cos(math.max(math.min((animeValue * 5) - 1.2, 0.5), 0.0) * math.pi))) * kusuInOverY)
        kusuInY = in1 - in2

        if animeValue > 0.35 then
            kusuState = 2
            animeValue = 0
        end
    elseif kusuState == 2 then
        effectOpacity = 255 / 2

        kusuIdleScale = 1.0 + (math.sin(animeValue * 4 * math.pi) / 40.0)
        if animeValue > 0.25 then
            animeValue = 0
        end

    elseif kusuState == 3 then
        openFrame = math.min(math.ceil((animeValue * 20) - 1), 2) -- Kusu open frame count/speed
        brokeOpacity = 255 - (math.max(animeValue - 0.9, 0) * 1000)
        effectOpacity = brokeOpacity / 2

        if brokeOpacity == 0 then
            kusuState = 0
        end

    elseif kusuState == 4 then
        effectOpacity = 0
        kusuMissY = (1.0 - math.cos(math.max(animeValue - 0.15, 0) * math.pi)) * 6000

        if animeValue > 0.5 then
            kusuState = 0
        end

    end
end

function draw(state)
    local effectFile = "Effect_" .. tostring(math.ceil(effectFrame)) .. ".png"

    if kusuState == 0 then
        setOpacity(effectFile, 0)
    elseif kusuState == 1 then
        setOpacity("Kusudama_Back.png", bgInOpacity)
        drawTex("Kusudama_Back.png", 0, 0)
        drawCenter("Kusudama_Idle.png", origin_x, origin_y + kusuInY)
    elseif kusuState == 2 then
        tx["Kusudama_Idle.png"]:SetScale(kusuIdleScale, kusuIdleScale)
        drawCenter("Kusudama_Idle.png", origin_x, origin_y)

        drawTex("Text_" .. textLang .. ".png", 750, 67)

    elseif kusuState == 3 then
        setOpacity("Kusudama_Open_2.png", brokeOpacity)
        drawCenter("Kusudama_Open_" .. tostring(openFrame) .. ".png", origin_x, origin_y)
    elseif kusuState == 4 then
        drawCenter("Kusudama_Miss.png", origin_x, origin_y + kusuMissY)
    end

    if not (kusuState == 0) then
        setOpacity(effectFile, effectOpacity)
        drawTex(effectFile, 0, 0)
    end
end

function onDestroy()
    for _, t in pairs(tx) do
        if t ~= nil then t:Dispose() end
    end
    tx = {}
end
