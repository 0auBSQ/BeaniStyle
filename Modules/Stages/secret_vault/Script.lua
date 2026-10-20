---@diagnostic disable: undefined-global, undefined-field
-- secret_vault (generic): the vault's door, then its three chests.
-- While the vault is shut (trigger .vault_opened unset) the screen lists the three keys of the door and what
-- earns each, read from player 1's save:
--   Key of Greed  bought in the coin shop                   (trigger .vault_key_obtained_greed)
--   Key of Pride  beating Nokon at his own show (Intro Nokon) (trigger .vault_key_obtained_pride)
--   Key of Envy   reaching the 6th door of the pagoda       (counter pagoda_highest_level >= 15)
-- With all three, "Open the vault" sets .vault_opened (from then on other modes give vault keys instead of
-- coins) and the chests show: Vault.Chests, each opened with its own key; decide on a chest spends a key and
-- shows what was inside (a pop-up for coins, nameplates, songs and furniture, a line of text for a broken key
-- or a key to the next chest). Plain SimpleUI screens (Lib/GenericScreen.lua), no art of its own.

local Chests = require("Vault.Chests")
local Keys = require("Vault.Keys")
local S = require("GenericScreen")

local EXIT_OPEN, EXIT_LOCKED = "vault_water_back", "vault_wood"   -- back to the title

local GREED, PRIDE = ".vault_key_obtained_greed", ".vault_key_obtained_pride"
local ENVY_COUNTER, ENVY_LEVEL = "pagoda_highest_level", 15

local CONDITIONS = {
    { name = "VAULT_KEY_GREED", en = "Key of Greed", hint = "VAULT_KEY_GREED_HINT", enHint = "Occasionally available in the General Store for a juicy price",
      owned = function(sf) return sf:GetGlobalTrigger(GREED) == true end },
    { name = "VAULT_KEY_PRIDE", en = "Key of Pride", hint = "VAULT_KEY_PRIDE_HINT", enHint = "Beat Nokon at his own show",
      owned = function(sf) return sf:GetGlobalTrigger(PRIDE) == true end },
    { name = "VAULT_KEY_ENVY", en = "Key of Envy", hint = "VAULT_KEY_ENVY_HINT", enHint = "Reach the 6th door in the Pagoda of the Unknown",
      owned = function(sf) return (tonumber(sf:GetGlobalCounter(ENVY_COUNTER)) or 0) >= ENVY_LEVEL end },
}

local screen = "gate"     -- "gate" (the vault is shut) or "chests"
local ui = nil
local picked = nil        -- the chest a button asked for this frame
local gateAction = nil    -- "open" or "back" from the gate's buttons
local owned = {}          -- per condition, read on entry
local message, messageT = nil, 0
local modalOn = false
local openedAt = {}       -- chest -> seconds left showing it open

local CARD_W, CARD_H, GAP = 520, 640, 40
local CARD_Y = S.headerH + 80

local function cardX(i) return (S.W - (3 * CARD_W + 2 * GAP)) / 2 + (i - 1) * (CARD_W + GAP) end
local function setMessage(s) message, messageT = s, 3 end
local function modal() return ROACTIVITY:GetROActivity("modal") end
local function vaultOpen() return Keys.vaultOpen() end

local function allOwned()
    for i = 1, #CONDITIONS do if not owned[i] then return false end end
    return true
end

local function readConditions()
    local sf = GetSaveFile(0)
    for i, c in ipairs(CONDITIONS) do owned[i] = sf ~= nil and c.owned(sf) or false end
end

local function closeUI()
    if ui ~= nil then ui:disposeWidgets() end
    ui = nil
end

local function buildGate()
    closeUI()
    screen = "gate"
    ui = S.newUI{ navPlayer = 1 }
    local y = S.H - S.footerH - 120
    local open = ui:button{ text = S.tr("VAULT_OPEN_GATE", "Open the vault"), x = S.W - S.margin - 750, y = y, w = 360, h = 80,
        accent = true, onClick = function() gateAction = "open" end }
    local back = ui:button{ text = S.tr("COMMON_BACK", "Back"), x = S.W - S.margin - 360, y = y, w = 360, h = 80,
        onClick = function() gateAction = "back" end }
    if allOwned() then ui:focus(open) else open:setEnabled(false); ui:focus(back) end
end

local function buildChests()
    closeUI()
    screen = "chests"
    ui = S.newUI{ navPlayer = 1, nav = "spatial" }
    local buttons = {}
    for i = 1, 3 do
        buttons[i] = ui:button{ text = "", x = cardX(i), y = CARD_Y, w = CARD_W, h = CARD_H, onClick = function() picked = i end }
    end
    ui:focus(buttons[1])
    if Chests.enter() then
        setMessage(S.trf("VAULT_FIRST_KEY", "A {key} for your first visit.", { key = Keys.name(1) }))
    end
end

local function open(i)
    if Chests.keyCount(i) < 1 then
        S.sound("Error")
        setMessage(S.trf("VAULT_NO_KEY", "You have no {key}.", { key = Keys.name(i) }))
        return
    end
    S.sound("Decide")
    openedAt[i] = 1.2
    local reward = Chests.roll(i)
    if Chests.showReward(reward) then modalOn = true; return end
    if reward.type == "key" then
        setMessage(S.trf("VAULT_GOT_KEY", "Inside: a {key}.", { key = Keys.name(reward.target) }))
    else
        setMessage(S.tr("VAULT_SNAP", "The key broke. The chest was empty."))
    end
end

function onStart()
end

function activate()
    S.resetKeys()
    picked, gateAction, message, modalOn = nil, nil, nil, false
    openedAt = {}
    readConditions()
    if vaultOpen() then buildChests() else buildGate() end
end

function deactivate()
    local m = modal()
    if m ~= nil and m.IsActive then pcall(function() m:Deactivate() end) end
    closeUI()
end

function update(ts)
    local dt = fps.deltaTime or 0.016
    for i, t in pairs(openedAt) do openedAt[i] = (t > dt) and (t - dt) or nil end
    if messageT > 0 then messageT = messageT - dt; if messageT <= 0 then message = nil end end

    if modalOn then
        local m = modal()
        if m ~= nil and m.IsActive then m:Update(); return nil end
        modalOn = false
    end

    picked, gateAction = nil, nil
    local cancel = ui:update(ts) == "cancel"

    if screen == "gate" then
        if cancel or gateAction == "back" then
            S.sound("Cancel")
            return Exit("title", nil, EXIT_LOCKED)
        end
        if gateAction == "open" then
            if not allOwned() then S.sound("Error"); return nil end
            local sf = GetSaveFile(0)
            if sf ~= nil then sf:SetGlobalTrigger(Keys.OPENED, true) end
            S.sound("Decide")
            buildChests()
        end
        return nil
    end

    if cancel then
        S.sound("Cancel")
        return Exit("title", nil, EXIT_OPEN)
    end
    if picked ~= nil then open(picked) end
end

-- ── drawing ─────────────────────────────────────────────────────────────────

local function drawGate()
    local x, y, w = S.margin, S.headerH + 40, S.W - 2 * S.margin
    S.panel(x, y, w, 720)
    S.text(S.tr("VAULT_GATE_TITLE", "The vault's door has three locks."), x + 60, y + 50, S.font.label, S.colors.text)
    local line = allOwned() and S.tr("VAULT_GATE_READY_GENERIC", "All three keys are here: the vault can open!")
        or S.tr("VAULT_GATE_MISSING_GENERIC", "The door won't budge... Some keys are still missing.")
    S.text(line, x + 60, y + 110, S.font.body, S.colors.textDim)

    local rowY, rowH = y + 190, 160
    for i, c in ipairs(CONDITIONS) do
        local ry = rowY + (i - 1) * rowH
        local done = owned[i]
        S.rect(x + 60, ry, 12, rowH - 30, done and S.colors.good or S.colors.line)
        S.text(S.tr(c.name, c.en), x + 100, ry + 10, S.font.label, S.colors.text)
        S.text(S.tr(c.hint, c.enHint), x + 100, ry + 62, S.font.body, S.colors.textDim, "topleft", 1, w - 560)
        local state = done and S.tr("VAULT_COND_DONE", "Obtained") or S.tr("VAULT_COND_TODO", "Not yet")
        local sw = 220
        S.rect(x + w - 60 - sw, ry + 24, sw, 56, done and S.colors.good or S.colors.surface2)
        S.text(state, x + w - 60 - sw / 2, ry + 52, S.font.body, done and S.colors.textOn or S.colors.textDim, "center", 1, sw - 20)
    end
end

local function drawCard(i)
    local x = cardX(i)
    local isOpen = openedAt[i] ~= nil
    if isOpen then S.frame(x, CARD_Y, CARD_W, CARD_H, S.colors.accent, 6) end
    -- the chest: a plain box, lid up while it shows open
    local bw, bh = 300, 180
    local bx, by = x + (CARD_W - bw) / 2, CARD_Y + 110
    S.rect(bx, by, bw, bh, S.colors.surface2)
    S.frame(bx, by, bw, bh, S.colors.primary, 4)
    S.rect(bx - 10, by - (isOpen and 70 or 30), bw + 20, 30, S.colors.primary)
    S.text(Chests.name(i), x + CARD_W / 2, CARD_Y + 360, S.font.label, S.colors.text, "center", 1, CARD_W - 40)
    local n = math.floor(Chests.keyCount(i))
    S.text(S.trf("VAULT_KEYS", "{key}: {n}", { key = Keys.name(i), n = n }), x + CARD_W / 2, CARD_Y + 450, S.font.body,
        n > 0 and S.colors.text or S.colors.textDim, "center", 1, CARD_W - 40)
    local left, total = Chests.stock(i)
    S.text(S.trf("VAULT_STOCK", "{left} of {total} rewards left", { left = left, total = total }),
        x + CARD_W / 2, CARD_Y + 560, S.font.small, S.colors.textDim, "center", 1, CARD_W - 40)
end

function draw()
    S.clear()
    S.header(S.tr("VAULT_TITLE", "Secret Vault"))
    if screen == "gate" then
        drawGate()
        if ui ~= nil then ui:draw() end
        S.footer({ { S.key("decide"), S.tr("COMMON_SELECT", "Select") }, { S.key("cancel"), S.tr("COMMON_BACK", "Back") } })
        return
    end
    if ui ~= nil then ui:draw() end
    for i = 1, 3 do drawCard(i) end
    if message then S.message(message, 460, S.H - S.footerH - 110, 1000, 72) end
    S.footer({ { S.key("decide"), S.tr("VAULT_OPEN", "Open") }, { S.key("cancel"), S.tr("COMMON_BACK", "Back") } })
    local m = modal()
    if modalOn and m ~= nil and m.IsActive then m:Draw() end
end

function onDestroy()
    closeUI()
    S.dispose()
end
