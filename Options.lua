local addonName, ns = ...

-- A small options window, drawn from plain colours so it needs no texture
-- files. Everything here can also be set with /swiftquest.

local ACCENT_R, ACCENT_G, ACCENT_B = 0.85, 0.63, 0.40

local window
local controls = {}

local function Fill(frame, r, g, b, a)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function Outline(frame, alpha)
    local function Edge(point1, point2, isVertical)
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, alpha)
        edge:SetPoint(point1)
        edge:SetPoint(point2)
        if isVertical then edge:SetWidth(1) else edge:SetHeight(1) end
    end
    Edge("TOPLEFT", "TOPRIGHT", false)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", false)
    Edge("TOPLEFT", "BOTTOMLEFT", true)
    Edge("TOPRIGHT", "BOTTOMRIGHT", true)
end

-- A row that reads its text and tick from the saved settings each time it
-- is refreshed, and changes them when clicked.
local function CreateRow(parent, y, isCheckbox, getText, isTicked, onClick)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(300, 24)
    row:SetPoint("TOPLEFT", 14, y)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.07)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local tick
    if isCheckbox then
        local box = CreateFrame("Frame", nil, row)
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 2, 0)
        Fill(box, 0, 0, 0, 0.5)
        Outline(box, 0.7)
        tick = box:CreateTexture(nil, "ARTWORK")
        tick:SetPoint("TOPLEFT", 3, -3)
        tick:SetPoint("BOTTOMRIGHT", -3, 3)
        tick:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
        label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    else
        Fill(row, 1, 1, 1, 0.06)
        Outline(row, 0.35)
        label:SetPoint("CENTER")
    end

    function row.Refresh()
        label:SetText(getText())
        if tick then
            tick:SetShown(isTicked() and true or false)
        end
    end
    row:SetScript("OnClick", function()
        onClick()
        ns.RefreshOptions()
    end)
    controls[#controls + 1] = row
    return row
end

local function CreateWindow()
    window = CreateFrame("Frame", addonName .. "Options", UIParent)
    window:SetSize(328, 232)
    -- Where you last put it, or the middle.
    local saved = ns.db.optionsPoint
    if type(saved) == "table" and saved[1] then
        window:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        window:SetPoint("CENTER")
    end
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        ns.db.optionsPoint = { point, relativePoint, x, y }
    end)
    window:Hide()
    Fill(window, 0.05, 0.05, 0.06, 0.97)
    Outline(window, 0.55)
    -- Lets Escape close the window.
    tinsert(UISpecialFrames, addonName .. "Options")

    ns.CloseWithPadB(_G[addonName .. "Options"], addonName .. "Options")
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("SwiftQuest")

    local close = CreateFrame("Button", nil, window)
    close:SetSize(30, 30)
    close:SetPoint("TOPRIGHT", -2, -2)
    local closeHover = close:CreateTexture(nil, "HIGHLIGHT")
    closeHover:SetAllPoints()
    closeHover:SetColorTexture(0.9, 0.2, 0.2, 0.45)
    local closeLabel = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    closeLabel:SetPoint("CENTER")
    closeLabel:SetText("x")
    close:SetScript("OnClick", function() window:Hide() end)

    CreateRow(window, -46, true,
        function() return "Accept quests when they are offered" end,
        function() return ns.db.accept end,
        function() ns.db.accept = not ns.db.accept end)
    CreateRow(window, -74, true,
        function() return "Hand in finished quests" end,
        function() return ns.db.turnIn end,
        function() ns.db.turnIn = not ns.db.turnIn end)
    CreateRow(window, -110, true,
        function() return "Leave low-level (grey) quests to me" end,
        function() return ns.db.skipTrivial end,
        function() ns.db.skipTrivial = not ns.db.skipTrivial end)
    CreateRow(window, -138, true,
        function() return "Leave repeatable quests to me" end,
        function() return ns.db.skipRepeatable end,
        function() ns.db.skipRepeatable = not ns.db.skipRepeatable end)
    CreateRow(window, -166, true,
        function() return "Leave group, dungeon and elite quests to me" end,
        function() return ns.db.skipGroup end,
        function() ns.db.skipGroup = not ns.db.skipGroup end)

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 16, 12)
    hint:SetText("Hold Shift while talking to someone (or set the Pause key) to do it by hand.")
end

function ns.RefreshOptions()
    for _, control in ipairs(controls) do
        control.Refresh()
    end
end

function ns.ToggleOptions()
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        ns.RefreshOptions()
        window:Show()
    end
end

-- Listed in the game's own Options > AddOns, with a button that opens this
-- window: that's where many players look first.
local function RegisterSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SwiftQuest")
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetWidth(520)
    text:SetJustifyH("LEFT")
    text:SetText("Accepts quests and hands them in as soon as you talk to the quest giver. It never picks a reward or pays gold.")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(220, 26)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
    open:SetText("Open SwiftQuest's options")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() and HideUIPanel then pcall(HideUIPanel, SettingsPanel) end
        ns.ToggleOptions()
    end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "SwiftQuest")
    Settings.RegisterAddOnCategory(category)
end
pcall(RegisterSettings)
