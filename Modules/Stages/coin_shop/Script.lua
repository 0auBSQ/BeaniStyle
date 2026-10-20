---@diagnostic disable: undefined-global, undefined-field
-- coin_shop (generic): today's shop of a save (Shop.Daily) as a grid of cards: the featured item on the left,
-- the normal items on the right, a reroll button under them. Decide on a card buys it (ranged items ask how
-- many first); the purchase pop-up is Shop.Popup's. The title passes the save it picked (Saves.SavePicker).
-- Plain SimpleUI screens (Lib/GenericScreen.lua), no art of its own: furniture shows My Room's thumbnail
-- when My Room made one, nameplates their title plate, anything else its name.
-- Sounds/Buy.ogg is the paying sound of the coin purse (Lib/CoinBox.lua, used by the coin modal).

local Daily = require("Shop.Daily")
local Catalog = require("Shop.Catalog")
local Popup = require("Shop.Popup")
local SavePicker = require("Saves.SavePicker")
local S = require("GenericScreen")

local EXIT_TRANSITION = "newspaper_back"   -- back to the title

local shop = nil
local ui = nil
local coins = nil
local cards = {}          -- { slot, button, x, y, w, h }
local action = nil        -- what a button asked for this frame
local ask = nil           -- the quantity dialog
local askSlot, askResult = nil, nil
local message, messageT = nil, 0
local plateFont = nil     -- the title text of a nameplate item's plate

local BIG = { x = S.margin, y = S.headerH + 40, w = 600, h = 780 }
local GRID = { x = S.margin + 640, y = S.headerH + 40, w = 1152, cols = 3, cardW = 368, cardH = 330, gap = 24 }

-- the texture an item shows: My Room's thumbnail for furniture once My Room made it, nothing otherwise
local function itemPicture(item)
    local fid = Catalog.furnitureId(item.Code)
    if fid then
        local t = SHARED:GetSharedTexture("myroom_thumb_" .. fid)
        if t ~= nil and t.Width > 0 then return t end
    end
    return nil
end

-- what an item without a picture shows in its place
local function itemKind(item)
    if Catalog.furnitureId(item.Code) then return S.tr("SHOP_KIND_FURNITURE", "Furniture") end
    if item.Code:sub(1, 10) == "vault_key_" then return S.tr("SHOP_KIND_KEY", "Key") end
    return S.tr("SHOP_KIND_ITEM", "Item")
end

local function setMessage(s) message, messageT = s, 2.5 end

local function refusalText(why)
    if why == "poor" then return S.tr("SHOP_POOR", "Not enough coins.") end
    if why == "soldout" then return S.tr("SHOP_SOLDOUT", "Sold out.") end
    return S.tr("SHOP_NONE", "Nothing here today.")
end

local function buildUI()
    if ui ~= nil then ui:disposeWidgets() end
    ui = S.newUI{ navPlayer = 1, nav = "spatial" }
    cards = {}
    local function card(slot, x, y, w, h)
        local item = shop:item(slot)
        local b = ui:button{ text = "", x = x, y = y, w = w, h = h, onClick = function() action = { buy = slot } end }
        if item == nil or item.SoldOut then b:setEnabled(false) end
        cards[#cards + 1] = { slot = slot, button = b, x = x, y = y, w = w, h = h }
    end
    card(Daily.SLOT_BIG, BIG.x, BIG.y, BIG.w, BIG.h)
    local n = 0
    for i = 1, 6 do
        if shop.normals[i] ~= nil or i <= 4 then
            local col, row = n % GRID.cols, math.floor(n / GRID.cols)
            card(i, GRID.x + col * (GRID.cardW + GRID.gap), GRID.y + row * (GRID.cardH + GRID.gap), GRID.cardW, GRID.cardH)
            n = n + 1
        end
    end
    local ry = GRID.y + 2 * (GRID.cardH + GRID.gap)
    local reroll = ui:button{ text = S.trf("SHOP_REROLL", "New stock ({n} coins)", { n = shop:rerollPrice() }),
        x = GRID.x, y = ry, w = GRID.w, h = 76, onClick = function() action = { reroll = true } end }
    coins = ui:coins{ x = S.W - S.margin - 300, y = (S.headerH - 60) / 2, w = 300, h = 60, plain = true, amount = shop.save.Coins }
    -- the keys start on the first card that can be bought
    local first = reroll
    for _, c in ipairs(cards) do if c.button.enabled then first = c.button; break end end
    ui:focus(first)
end

local function buy(slot, qty)
    local item = shop:item(slot)
    local ok, why = shop:buy(slot, qty)
    if not ok then S.sound("Error"); setMessage(refusalText(why)); return end
    S.sound("Decide")
    Popup.show(item, qty)
    buildUI()
end

local function closeAsk()
    if ask ~= nil then ask:disposeWidgets() end
    ask, askSlot, askResult = nil, nil, nil
end

local function openAsk(slot)
    closeAsk()
    local item = shop:item(slot)
    askSlot = slot
    ask = S.newUI{ navPlayer = 1 }
    local PW, PH = 760, 400
    local panel = ask:panel{ x = (S.W - PW) / 2, y = (S.H - PH) / 2, w = PW, h = PH, title = item.LocalizedName or "" }
    local cx, cy, cw, ch = panel:content()
    local opts = {}
    local most = math.max(1, math.min(item.Stock or 1, math.floor(shop.save.Coins / math.max(1, item.Price))))
    for i = 1, most do opts[i] = S.trf("SHOP_QTY", "{n} × {p} coins", { n = i, p = item.Price }) end
    local qty = ask:chooser{ x = cx + (cw - 480) / 2, y = cy + 40, w = 480, h = 72, options = opts, index = 1, wrap = false }
    ask:button{ text = S.tr("SHOP_BUY", "Buy"), x = cx + cw / 2 - 330, y = cy + ch - 90, w = 300, h = 76, accent = true,
        onClick = function() askResult = qty.index end }
    ask:button{ text = S.tr("COMMON_BACK", "Back"), x = cx + cw / 2 + 30, y = cy + ch - 90, w = 300, h = 76,
        onClick = function() askResult = 0 end }
    ask:focus(qty)
end

function onStart()
    plateFont = TEXT:Create(16)
end

function activate()
    S.resetKeys()
    local slot = SavePicker.take() or SavePicker.first() or 0
    shop = Daily.open(slot)
    action, message = nil, nil
    closeAsk()
    buildUI()
end

function deactivate()
    closeAsk()
    Popup.stop()
    if shop ~= nil then shop:close() end
    shop = nil
    if ui ~= nil then ui:disposeWidgets() end
    ui = nil
end

function update(ts)
    if messageT > 0 then messageT = messageT - (fps.deltaTime or 0.016); if messageT <= 0 then message = nil end end
    if Popup.update() then return nil end

    if ask ~= nil then
        local r = ask:update(ts)
        if r == "cancel" or askResult == 0 then S.sound("Cancel"); closeAsk()
        elseif askResult ~= nil then local s, q = askSlot, askResult; closeAsk(); buy(s, q) end
        return nil
    end

    action = nil
    if ui:update(ts) == "cancel" then
        S.sound("Cancel")
        return Exit("title", nil, EXIT_TRANSITION)
    end
    if action == nil then return nil end
    if action.reroll then
        local ok = shop:reroll()
        if ok then S.sound("Decide"); buildUI()
        else S.sound("Error"); setMessage(refusalText("poor")) end
    elseif action.buy then
        local slot = action.buy
        local why = shop:refusal(slot, 1)
        if why ~= nil then S.sound("Error"); setMessage(refusalText(why)); return nil end
        local item = shop:item(slot)
        if (tonumber(item.StockMax) or 0) > 0 and (item.Stock or 1) > 1 then openAsk(slot) else buy(slot, 1) end
    end
end

local function drawCard(c)
    local item = shop:item(c.slot)
    local a = 1
    if item == nil then
        S.text(S.tr("SHOP_EMPTY", "Empty"), c.x + c.w / 2, c.y + c.h / 2, S.font.body, S.colors.textDim, "center")
        return
    end
    if item.SoldOut then a = 0.45 end
    local big = c.slot == Daily.SLOT_BIG
    local psize = big and 360 or 150
    local pcx, pcy = c.x + c.w / 2, c.y + 30 + psize / 2
    local pic = itemPicture(item)
    if pic ~= nil then
        local k = psize / math.max(pic.Width, pic.Height)
        pic:SetScale(k, k)
        pic:SetOpacity(a)
        pic:DrawAtAnchor(pcx, pcy, "center")
        pic:SetScale(1, 1)
        pic:SetOpacity(1)
    elseif item.Type == "nameplate" and plateFont ~= nil then
        -- the title plate (330x81) centred where the picture goes; it draws with its top-left at (x - 180, y + 5)
        pcall(function() NAMEPLATE:DrawNameplateTitleById(tostring(item.RefInt), pcx - 165 + 180, pcy - 40 - 5, math.floor(a * 255), plateFont) end)
    else
        local bw, bh = psize * 0.8, psize * 0.5
        S.rect(pcx - bw / 2, pcy - bh / 2, bw, bh, S.colors.surface2, a)
        S.text(itemKind(item), pcx, pcy, big and S.font.label or S.font.body, S.colors.textDim, "center", a, bw - 20)
    end
    local ty = c.y + psize + 60
    S.text(item.LocalizedName or item.Code, c.x + c.w / 2, ty, big and S.font.label or S.font.body, S.colors.text, "center", a, c.w - 40)
    local price = S.trf("SHOP_PRICE", "{n} coins", { n = item.Price })
    if item.SoldOut then price = S.tr("SHOP_SOLDOUT", "Sold out.") end
    S.text(price, c.x + c.w / 2, ty + (big and 60 or 44), S.font.body, item.SoldOut and S.colors.textDim or S.colors.accent, "center", a)
    if (item.Stock or 1) > 1 and not item.SoldOut then
        S.text(S.trf("SHOP_STOCK", "{n} left", { n = item.Stock }), c.x + c.w - 20, c.y + 30, S.font.small, S.colors.textDim, "topright", a)
    end
    if big then
        S.rect(c.x + 20, c.y + 20, 160, 40, S.colors.gold)
        S.text(S.tr("SHOP_FEATURED", "Featured"), c.x + 100, c.y + 40, S.font.small, S.colors.textOn, "center")
    end
end

function draw()
    S.clear()
    S.header(S.tr("SHOP_TITLE", "Shop"), shop and shop.save.Name or nil)
    if ui ~= nil then
        ui:draw()
        for _, c in ipairs(cards) do drawCard(c) end
    end
    if message then S.message(message, GRID.x, S.H - S.footerH - 66, GRID.w, 56) end
    S.footer({ { S.key("decide"), S.tr("SHOP_BUY", "Buy") }, { S.key("cancel"), S.tr("COMMON_BACK", "Back") } })
    if ask ~= nil then S.shade(0.45); ask:draw() end
    Popup.draw()
end

function onDestroy()
    if plateFont ~= nil then pcall(function() plateFont:Dispose() end) end
    plateFont = nil
    S.dispose()
end
