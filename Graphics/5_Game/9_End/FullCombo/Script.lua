--func:DrawText(x, y, text)
--func:DrawNum(x, y, num)
--func:AddGraph("filename")
--func:DrawGraph(x, y, filename)
--func:DrawRectGraph(x, y, rect_x, rect_y, rect_width, rect_height, filename)
--func:SetOpacity(opacity, "filename")
--func:SetScale(xscale, yscale, "filename")
--func:SetColor(r, g, b, "filename")

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
local left_origin_offset_x = 544
local left_origin_offset_y = -21
local right_origin_offset_x = 592
local right_origin_offset_y = -21

local clear_text_offset_x = 373
local clear_text_offset_y = -3

local textLang = "en"

function drawClearText(text_x, text_y, value, name)
    scale = 1.0 + (math.sin(math.min(value, 1) * math.pi) / 10.0)

    func:SetOpacity(value * 255 * 2, name)
    func:SetScale(1.0, scale, name)
    func:DrawGraph(text_x, text_y - ((scale - 1.0) * 135), name)
end

function drawStar(star_x, star_y, value)
    if value > 0 then
        opacity = 255 - (math.max(math.min((value / 0.16) - 1.0, 1), 0) * 255)
        scale = math.min(value / 0.16, 1)

        func:SetOpacity(opacity, "Star.png")
        func:SetScale(scale, scale, "Star.png")
        func:DrawGraphCenter(star_x, star_y, "Star.png")
    end
end

function clearIn(player)
end

function clearOut(player)
end

function playEndAnime(player)
    animeCounter = { 0, 0, 0, 0, 0 }
    fc_text_states = { 0, 0, 0, 0, 0 }
    fc_text_values = { 0, 0, 0, 0, 0 }
    starAnimeValue = { 0, 0, 0, 0, 0 }
    fc_effect = { 0, 0, 0, 0, 0 }
    fc_effect_state = { 0, 0, 0, 0, 0 }
end

function init()
    if playerCount <= 2 then
        y = { 288, 552, 0, 0, 0 }
    elseif playerCount == 5 then
        y = { 58, 274, 490, 706, 922 }
    else
        y = { 69, 333, 597, 861, 0 }
    end

    if lang == "ja" then
        textLang = "ja"
    end

    func:AddGraph(textLang.."/Clear_Text.png")
    func:AddGraph(textLang.."/Clear_Text_Flash.png")
    func:AddGraph(textLang.."/FullCombo_Text.png")
    func:AddGraph(textLang.."/FullCombo_Text_Flash.png")

    func:AddGraph("Star.png")
end

function update(player)
    pos = player + 1

    animeCounter[pos] = animeCounter[pos] + (speed * deltaTime)
    animeValue = animeCounter[pos]

    if fc_effect_state[pos] == 1 then
        fc_effect[pos] = fc_effect[pos] + (effect_count * 2 * speed * deltaTime)
        
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
        starAnimeValue[pos] = starAnimeValue[pos] + (speed * deltaTime)
        if starAnimeValue[pos] > 1.57 then
            starAnimeValue[pos] = 0
        end
    end
end

function draw(player)
    pos = player + 1
    animeValue = animeCounter[pos]

    origin_x = x[pos]
    origin_y = y[pos]

    left_x = origin_x + left_origin_offset_x
    left_y = origin_y + left_origin_offset_y

    right_x = origin_x + right_origin_offset_x
    right_y = origin_y + right_origin_offset_y
    
    if animeValue < 1.23 then
        if animeValue > 0.31 then
            if animeValue > 1.0 then
                func:SetOpacity(255 - ((((animeValue - 1.0) / 0.30)) * 255 * 2), textLang.."/Clear_Text.png")
            else
                func:SetOpacity((((animeValue - 0.36) / 0.30)) * 255 * 2, textLang.."/Clear_Text.png")
            end
            drawClearText(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y, (animeValue - 0.36) / 0.30, textLang.."/Clear_Text.png")
        end

        if animeValue > 1.00 then
            clearFlashOpacity = math.sin(math.min((animeValue - 1.00) * 2.50, 1) * math.pi) * 255
            func:SetOpacity(clearFlashOpacity, textLang.."/Clear_Text_Flash.png")
            func:DrawGraph(origin_x + clear_text_offset_x, origin_y + clear_text_offset_y, textLang.."/Clear_Text_Flash.png")
        end
    end

    if fc_text_states[pos] == 0 then
    elseif fc_text_states[pos] == 1 then
        move_val = math.sin(fc_text_values[pos] * math.pi / 2.0)
        move_y = move_val * text_fc_move_y
        func:SetOpacity(255 * move_val, textLang.."/FullCombo_Text_Flash.png")
        func:DrawGraph(origin_x + 365, origin_y - move_y, textLang.."/FullCombo_Text_Flash.png")
    elseif fc_text_states[pos] == 2 then
        move_val = math.cos(fc_text_values[pos] * math.pi / 2.0)
        move_y = move_val * text_fc_move_y
        func:DrawGraph(origin_x + 365, origin_y - move_y, textLang.."/FullCombo_Text.png")
        func:SetOpacity(255 * move_val, textLang.."/FullCombo_Text_Flash.png")
        func:DrawGraph(origin_x + 365, origin_y - move_y, textLang.."/FullCombo_Text_Flash.png")
    elseif fc_text_states[pos] == 3 then
        scale = 1.0 - (math.sin(fc_text_values[pos] * math.pi) / 20.0)
        func:SetOpacity(255, textLang.."/FullCombo_Text.png")
        func:SetScale(1.0, scale, textLang.."/FullCombo_Text.png")
        func:DrawGraph(origin_x + 365, origin_y - ((scale - 1.0) * 195), textLang.."/FullCombo_Text.png")
    elseif fc_text_states[pos] == 4 then
        func:DrawGraph(origin_x + 365, origin_y, textLang.."/FullCombo_Text.png")
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
