-- Options panel for PartyRoleIcons.
--
-- Everything applies live: each widget writes the setting and calls Relayout, so
-- with "Simulate a group" ticked the fake party updates while the slider moves.
-- Built as a plain canvas so it registers the same way on the modern Settings
-- API, on the legacy InterfaceOptions frame, or standalone if neither exists.

local _, ns = ...

local L = ns.L

local PANEL_WIDTH, PANEL_HEIGHT = 620, 560
local SLIDER_WIDTH = 260
local ANCHOR_CELL = 26

local panel
local widgets
local refreshing = false

--------------------------------------------------------------------------------
-- Widget helpers
--------------------------------------------------------------------------------

local function SetSolidColor(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

local function SetShownCompat(region, shown)
    if shown then region:Show() else region:Hide() end
end

local function NewLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    return label
end

local function NewCheckbox(parent, label, tooltip, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(26, 26)

    local text = NewLabel(parent, label, "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 4, 1)
    check.label = text

    check:SetScript("OnClick", function(self)
        if refreshing then return end
        onClick(self:GetChecked() and true or false, self)
    end)

    if tooltip then
        check:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
    end

    return check
end

local function NewSlider(parent, name, label, minValue, maxValue, onValue)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetWidth(SLIDER_WIDTH)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    -- The template names its labels differently depending on the client, and an
    -- unnamed slider has none at all, so resolve or build them.
    local low = slider.Low or (name and _G[name .. "Low"])
    local high = slider.High or (name and _G[name .. "High"])
    local valueText = slider.Text or (name and _G[name .. "Text"])

    if low then low:SetText(tostring(minValue)) end
    if high then high:SetText(tostring(maxValue)) end
    if not valueText then
        valueText = NewLabel(parent, "", "GameFontHighlightSmall")
        valueText:SetPoint("BOTTOM", slider, "TOP", 0, 2)
    end
    slider.valueText = valueText
    slider.labelText = label

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        self.valueText:SetText(self.labelText .. ": " .. value)
        if refreshing then return end
        onValue(value)
    end)

    return slider
end

local function NewButton(parent, label, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(label)
    button:SetScript("OnClick", function()
        if refreshing then return end
        onClick()
    end)
    return button
end

-- A three by three keypad of the nine anchor points, laid out the way they sit
-- around the portrait.
local function NewAnchorGrid(parent, onPick)
    local grid = CreateFrame("Frame", nil, parent)
    grid:SetSize(ANCHOR_CELL * 3 + 8, ANCHOR_CELL * 3 + 8)

    local buttons = {}
    for row = 1, 3 do
        for column = 1, 3 do
            local anchor = ns.ANCHOR_GRID[row][column]
            local button = CreateFrame("Button", nil, grid)
            button:SetSize(ANCHOR_CELL - 4, ANCHOR_CELL - 4)
            button:SetPoint("TOPLEFT", grid, "TOPLEFT",
                4 + (column - 1) * ANCHOR_CELL, -4 - (row - 1) * ANCHOR_CELL)

            local background = button:CreateTexture(nil, "BACKGROUND")
            background:SetAllPoints(button)
            SetSolidColor(background, 0, 0, 0, 0.55)

            local selected = button:CreateTexture(nil, "ARTWORK")
            selected:SetAllPoints(button)
            SetSolidColor(selected, 0.2, 0.8, 1, 0.85)
            selected:Hide()
            button.selected = selected

            button:SetScript("OnClick", function()
                if refreshing then return end
                onPick(anchor)
            end)
            button:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(anchor, 1, 1, 1)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function()
                if GameTooltip then GameTooltip:Hide() end
            end)

            buttons[anchor] = button
        end
    end

    grid.buttons = buttons
    return grid
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

local function Refresh()
    local db = ns.db
    if not db or not widgets then return end

    refreshing = true

    widgets.enabled:SetChecked(db.enabled)
    widgets.showPlayer:SetChecked(db.showPlayer)
    widgets.useSpec:SetChecked(db.useSpec)
    widgets.hideBlizzard:SetChecked(db.hideBlizzard)
    widgets.simulate:SetChecked(ns.IsPreview())

    widgets.size:SetValue(db.size)
    widgets.size.valueText:SetText(L["OPT_SIZE"] .. ": " .. db.size)
    widgets.offsetX:SetValue(db.x)
    widgets.offsetX.valueText:SetText(L["OPT_OFFSET_X"] .. ": " .. db.x)
    widgets.offsetY:SetValue(db.y)
    widgets.offsetY.valueText:SetText(L["OPT_OFFSET_Y"] .. ": " .. db.y)

    for anchor, button in pairs(widgets.anchors.buttons) do
        SetShownCompat(button.selected, anchor == db.anchor)
    end

    refreshing = false
end

local function Build()
    local frame = CreateFrame("Frame", "PartyRoleIconsOptionsPanel", UIParent)
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:Hide()
    frame.name = L["OPT_TITLE"]

    widgets = {}

    local title = NewLabel(frame, L["OPT_TITLE"], "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)

    local intro = NewLabel(frame, L["OPT_INTRO"], "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    intro:SetWidth(PANEL_WIDTH - 40)
    intro:SetJustifyH("LEFT")

    local anchorTo, y = intro, -16

    local function Place(widget, indent)
        widget:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", indent or 0, y)
        anchorTo = widget
        y = -10
    end

    widgets.simulate = NewCheckbox(frame, L["OPT_SIMULATE"], L["OPT_SIMULATE_TIP"],
        function(checked, self)
            if not ns.SetPreview(checked) then
                -- Combat refused the switch: put the box back where it was.
                refreshing = true
                self:SetChecked(ns.IsPreview())
                refreshing = false
            end
        end)
    Place(widgets.simulate)

    widgets.enabled = NewCheckbox(frame, L["OPT_ENABLED"], nil, function(checked)
        ns.db.enabled = checked
        ns.Relayout()
    end)
    Place(widgets.enabled)

    widgets.showPlayer = NewCheckbox(frame, L["OPT_PLAYER"], nil, function(checked)
        ns.db.showPlayer = checked
        ns.Relayout()
    end)
    Place(widgets.showPlayer)

    widgets.useSpec = NewCheckbox(frame, L["OPT_SPEC"], nil, function(checked)
        ns.db.useSpec = checked
        ns.Relayout()
    end)
    Place(widgets.useSpec)

    widgets.hideBlizzard = NewCheckbox(frame, L["OPT_BLIZZARD"], nil, function(checked)
        ns.db.hideBlizzard = checked
        ns.Relayout()
    end)
    Place(widgets.hideBlizzard)

    -- Sliders
    widgets.size = NewSlider(frame, "PartyRoleIconsSizeSlider", L["OPT_SIZE"], 8, 40,
        function(value)
            ns.db.size = value
            ns.Relayout()
        end)
    y = -34
    Place(widgets.size, 8)

    widgets.offsetX = NewSlider(frame, "PartyRoleIconsOffsetXSlider", L["OPT_OFFSET_X"], -40, 40,
        function(value)
            ns.db.x = value
            ns.Relayout()
        end)
    y = -34
    Place(widgets.offsetX)

    widgets.offsetY = NewSlider(frame, "PartyRoleIconsOffsetYSlider", L["OPT_OFFSET_Y"], -40, 40,
        function(value)
            ns.db.y = value
            ns.Relayout()
        end)
    y = -34
    Place(widgets.offsetY)

    -- Position keypad
    local positionLabel = NewLabel(frame, L["OPT_POSITION"])
    y = -30
    Place(positionLabel, -8)

    widgets.anchors = NewAnchorGrid(frame, function(anchor)
        ns.db.anchor = anchor
        ns.Relayout()
        Refresh()
    end)
    y = -8
    Place(widgets.anchors)

    widgets.reset = NewButton(frame, L["OPT_RESET"], 150, function()
        for key, value in pairs(ns.DEFAULTS) do
            ns.db[key] = value
        end
        ns.Relayout()
        Refresh()
    end)
    y = -18
    Place(widgets.reset)

    -- The Settings API calls these when the category is shown or defaulted.
    frame.OnRefresh = Refresh
    frame.OnCommit = function() end
    frame.OnDefault = function()
        for key, value in pairs(ns.DEFAULTS) do
            ns.db[key] = value
        end
        ns.Relayout()
        Refresh()
    end
    frame:SetScript("OnShow", Refresh)

    return frame
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local category

local function Register()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, L["OPT_TITLE"])
        -- Do not touch category.ID. The widespread retail idiom of overwriting it
        -- with the addon name breaks here: OpenToCategory feeds the id straight to
        -- C_SettingsUtil.OpenSettingsPanel, which only takes a number.
        Settings.RegisterAddOnCategory(category)
        return
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        return
    end

    -- No options host at all: make the panel a plain movable window.
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    if panel.SetBackdrop and BACKDROP_TUTORIAL_16_16 then
        panel:SetBackdrop(BACKDROP_TUTORIAL_16_16)
    end
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
end

local function OpenSettingsCategory()
    if not (category and Settings and Settings.OpenToCategory) then return false end

    local id = (category.GetID and category:GetID()) or category.ID
    if id ~= nil and pcall(Settings.OpenToCategory, id) then
        return true
    end

    -- Whatever the id turned out to be, the panel is registered, so opening the
    -- settings window at all still gets the player there.
    if SettingsPanel and SettingsPanel.Show then
        SettingsPanel:Show()
        return true
    end

    return false
end

-- Called at load, not on the first /pri: a panel that only registers itself when
-- the slash command is typed is a panel that is missing from the game's options
-- until then, which is exactly how it looks like the addon has none.
function ns.InitOptions()
    if panel then return end
    panel = Build()
    Register()
    Refresh()
end

function ns.OpenOptions()
    ns.InitOptions()
    Refresh()

    if OpenSettingsCategory() then
        return
    end

    if InterfaceOptionsFrame_OpenToCategory then
        -- The legacy call needs to be made twice, it lands on the wrong panel the
        -- first time.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    else
        panel:Show()
    end
end

ns.RefreshOptions = function()
    if panel then Refresh() end
end
