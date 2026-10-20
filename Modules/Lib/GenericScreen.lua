---@diagnostic disable: undefined-global, undefined-field
-- GenericScreen.lua — the plain look shared by BeaniStyle's generic screens (pagoda, coin shop, secret vault).
-- Everything is drawn flat with SimpleUI (no texture of its own): a header bar, a footer with key hints,
-- panels and text. Restyle all of these screens here (S.colors, S.font, the bar sizes and S.theme for the
-- SimpleUI widgets).
--
--   local S = require("GenericScreen")
--   local ui = S.newUI{ navPlayer = 1 }           -- a SimpleUI manager in this look
--   S.clear(); S.header("Pagoda"); S.panel(x, y, w, h)
--   S.text("Hello", 960, 540, S.font.body, S.colors.text, "center")
--   S.footer({ { S.key("decide"), S.tr("COMMON_SELECT", "Select") } })
--   S.dispose()                                   -- from onDestroy

local UI = require("UI.SimpleUI")
local NavInput = require("Input.NavInput")

local S = {}

S.W, S.H = 1920, 1080

-- colours are { r, g, b } from 0 to 255
S.colors = {
    bg       = { 236, 238, 242 },   -- screen background
    surface  = { 255, 255, 255 },   -- panels
    surface2 = { 226, 229, 235 },   -- a second panel tone, empty tracks
    line     = { 196, 201, 210 },   -- borders and separators
    text     = { 34, 38, 46 },
    textDim  = { 116, 122, 134 },
    textOn   = { 255, 255, 255 },   -- text on the primary or accent colour
    primary  = { 58, 64, 78 },      -- the header keys, message bars
    accent   = { 30, 116, 253 },    -- highlights
    good     = { 46, 160, 90 },
    bad      = { 208, 56, 48 },
    gold     = { 222, 170, 60 },
    shade    = { 16, 18, 22 },      -- dimming layer behind pop-ups
}

-- text sizes in pixels
S.font = { small = 20, body = 26, label = 30, title = 44, big = 64 }

S.headerH = 110
S.footerH = 64
S.margin = 64

-- the SimpleUI theme of the generic screens' widgets (merged over SimpleUI's default theme)
S.theme = {
    colors = {
        primary = { 58, 64, 78, 255 }, primary2 = { 40, 44, 56, 255 },
        accent  = { 30, 116, 253, 255 }, accent2 = { 0, 84, 158, 255 },
        surface = { 255, 255, 255, 255 }, surface2 = { 226, 229, 235, 255 },
        outline = { 58, 64, 78, 255 }, text = { 34, 38, 46, 255 }, textOnAccent = { 255, 255, 255, 255 },
    },
}

-- a SimpleUI manager in this look; opts as for UI.SimpleUI.new
function S.newUI(opts)
    opts = opts or {}
    opts.theme = opts.theme or S.theme
    return UI.new(opts)
end

-- ── Strings ──────────────────────────────────────────────────────────────────────
-- the skin's strings (Locales/<lang>/*.json through THEME:GetSkinString), else the fallback given here

function S.tr(key, fallback)
    local ok, s = pcall(function() return THEME:GetSkinString(key) end)
    if ok and type(s) == "string" and s ~= "" and s:sub(1, 1) ~= "[" then return s end
    return fallback or key
end

function S.fill(s, vars)
    if vars == nil then return s end
    return (s:gsub("{(%w+)}", function(k)
        local v = vars[k]
        if v == nil then return "{" .. k .. "}" end
        return tostring(v)
    end))
end

function S.trf(key, fallback, vars) return S.fill(S.tr(key, fallback), vars) end

-- the name of the first key a navigation binding ("decide", "cancel", ...) answers to, for the footer
-- hints; kept until S.resetKeys() (call it in activate: the bindings can change in the settings)
local keyNames = {}
function S.key(binding)
    local n = keyNames[binding]
    if n == nil then
        local ok, names = pcall(function() return NavInput.bindingNames(binding, 1) end)
        n = (ok and type(names) == "table" and names[1]) or binding
        keyNames[binding] = n
    end
    return n
end

function S.resetKeys() keyNames = {} end

function S.sound(name)
    local s = SHARED:GetSharedSound(name)
    if s ~= nil then s:Play() end
end

-- ── Drawing ──────────────────────────────────────────────────────────────────────
-- a SimpleUI manager that only draws (rectangles, glyph text); it holds no widgets

local painter = nil
local function p()
    if painter == nil then painter = UI.new{ theme = S.theme } end
    return painter
end

-- a filled rectangle; c = { r, g, b }, a = opacity 0..1
function S.rect(x, y, w, h, c, a)
    if w <= 0 or h <= 0 then return end
    c = c or S.colors.surface
    p():rect(x, y, w, h, c[1], c[2], c[3], math.floor((a or 1) * 255 + 0.5))
end

-- a rectangle outline t pixels thick, inside the box
function S.frame(x, y, w, h, c, t, a)
    t = t or 2
    S.rect(x, y, w, t, c, a)
    S.rect(x, y + h - t, w, t, c, a)
    S.rect(x, y + t, t, h - 2 * t, c, a)
    S.rect(x + w - t, y + t, t, h - 2 * t, c, a)
end

-- a panel: the surface colour with a border
function S.panel(x, y, w, h, a)
    S.rect(x, y, w, h, S.colors.surface, a)
    S.frame(x, y, w, h, S.colors.line, 2, a)
end

-- the whole screen in one colour (the background by default)
function S.clear(c, a) S.rect(0, 0, S.W, S.H, c or S.colors.bg, a) end

-- a dark layer over everything, behind a pop-up
function S.shade(a) S.rect(0, 0, S.W, S.H, S.colors.shade, a or 0.5) end

-- the glyph box keeps 25 px of padding left, right and under the ink: these offsets put the ink itself on
-- the anchor point
local function anchorOffset(f, anchor)
    local dx, dy = 0, 0
    local pad = 25
    if anchor == "topleft" or anchor == "left" or anchor == "bottomleft" then dx = -pad
    elseif anchor == "topright" or anchor == "right" or anchor == "bottomright" then dx = pad end
    if anchor == "left" or anchor == "center" or anchor == "right" then
        dy = math.floor((f.BoxHeight - math.ceil(f.LineHeight)) / 2)
    elseif anchor == "bottomleft" or anchor == "bottom" or anchor == "bottomright" then
        dy = pad
    end
    return dx, dy
end

local transparent = nil

-- text with its ink anchored at (x, y); anchor is one of the nine anchor names ("topleft" by default);
-- maxWidth squeezes a line that is too wide. Returns the ink width.
function S.text(str, x, y, size, c, anchor, a, maxWidth)
    str = tostring(str or "")
    if str == "" then return 0 end
    local ui = p()
    local f = ui:gfont(size or S.font.body)
    anchor = anchor or "topleft"
    c = c or S.colors.text
    if transparent == nil then transparent = COLOR:CreateColorFromRGBA(0, 0, 0, 0) end
    local dx, dy = anchorOffset(f, anchor)
    local mw = 0
    if maxWidth ~= nil and maxWidth > 0 then mw = maxWidth + 50 end
    f:Draw(str, x + dx, y + dy, ui:color(c[1], c[2], c[3]), transparent, a or 1, 1, mw, anchor)
    return f:Measure(str)
end

function S.measure(str, size) return p():measureText(size or S.font.body, tostring(str or "")) end

-- word-wrapped text, left-aligned from (x, y)
function S.wrapped(str, x, y, width, size, c, a)
    p():drawWrapped(size or S.font.body, tostring(str or ""), x - 25, y, width, c or S.colors.text, a or 1)
end

-- the top bar: a title and an optional line under it
function S.header(title, subtitle, a)
    S.rect(0, 0, S.W, S.headerH, S.colors.surface, a)
    S.rect(0, S.headerH - 2, S.W, 2, S.colors.line, a)
    S.text(title, S.margin, subtitle and 14 or S.headerH / 2, S.font.title, S.colors.text, subtitle and "topleft" or "left", a)
    if subtitle then S.text(subtitle, S.margin, 88, S.font.small, S.colors.textDim, "left", a) end
end

-- the bottom bar: hints as { key, action } pairs, from the left
function S.footer(hints, a)
    local y = S.H - S.footerH
    S.rect(0, y, S.W, S.footerH, S.colors.surface, a)
    S.rect(0, y, S.W, 2, S.colors.line, a)
    local x = S.margin
    local cy = y + S.footerH / 2
    for _, h in ipairs(hints or {}) do
        local kw = S.measure(h[1], S.font.small) + 24
        S.rect(x, cy - 18, kw, 36, S.colors.primary, a)
        S.text(h[1], x + kw / 2, cy, S.font.small, S.colors.textOn, "center", a)
        x = x + kw + 12
        x = x + S.text(h[2], x, cy, S.font.small, S.colors.textDim, "left", a) + 40
    end
end

-- a message bar (a primary-coloured strip with centred text)
function S.message(str, x, y, w, h)
    S.rect(x, y, w, h, S.colors.primary)
    S.text(str, x + w / 2, y + h / 2, S.font.body, S.colors.textOn, "center", 1, w - 40)
end

-- frees the drawing helpers (call from onDestroy)
function S.dispose()
    if painter ~= nil then pcall(function() painter:disposeWidgets() end) end
    painter = nil
end

return S
