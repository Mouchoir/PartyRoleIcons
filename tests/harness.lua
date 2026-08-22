-- Mock WoW client, just complete enough to exercise PartyRoleIcons.lua.
--
-- FRAME_STRUCTURE selects which party frame layout the fake client exposes:
--   "legacy" - PartyMemberFrameN globals (WotLK to Cata era FrameXML)
--   "modern" - PartyFrame.MemberFrameN (what MoP Classic 5.5 ships)
--   "pool"   - PartyFrame.PartyMemberFramePool only, no MemberFrameN fields
-- The addon has to work on all three, since guessing wrong is exactly the bug
-- that makes every icon silently disappear on party members.

local failures, checks = 0, 0
local function check(label, cond, extra)
    checks = checks + 1
    if cond then
        print("  ok    " .. label)
    else
        failures = failures + 1
        print("  FAIL  " .. label .. (extra ~= nil and ("   [" .. tostring(extra) .. "]") or ""))
    end
end

local structure = FRAME_STRUCTURE or "modern"
-- "spec" is Mists and later, "talents" is Classic Era, which is also the
-- Hardcore and Season of Discovery client.
local engine = ROLE_ENGINE or "spec"
local talentLayout = TALENT_LAYOUT or "vanilla"
print(("### frames: %s | locale: %s | roles: %s%s"):format(
    structure, LOCALE_UNDER_TEST or "enUS", engine,
    engine == "talents" and (" (" .. talentLayout .. " layout)") or ""))

--------------------------------------------------------------------------------
-- Scenario state
--------------------------------------------------------------------------------

local scenario = {
    inGroup = true,
    combat = false,
    visible = true,
    units = {
        -- spec and trees are picked to mean the same role, so the same
        -- assertions hold whichever engine the client needs.
        player = { name = "Tirelachasse", class = "HUNTER",  guid = "Player-1", role = "NONE",
                   spec = 254, trees = { 0, 41, 0 } },      -- marksmanship, damage
        party1 = { name = "Rogstar",      class = "WARRIOR", guid = "Player-2", role = "NONE",
                   spec = 73,  trees = { 0, 0, 41 } },      -- protection, tank
        party2 = { name = "Purebeautee",  class = "PALADIN", guid = "Player-3", role = "NONE",
                   spec = 65,  trees = { 41, 0, 0 } },      -- holy, healer
    },
}

local clock = 100
local inspectCalls = {}
local timers = {}
local hooks = {}
local createdFrames = {}
local inspectFrameShown = false
local layoutCalls = 0
KNOWS_LFG_UPDATE = false

--------------------------------------------------------------------------------
-- Region mocks
--------------------------------------------------------------------------------

local function newTexture()
    local t = { shown = true }
    function t:GetObjectType() return "Texture" end
    function t:SetTexture(p) self.tex = p; self.atlas = nil end
    function t:SetAtlas(a) self.atlas = a; self.tex = nil end
    function t:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function t:GetTexture() return self.tex end
    function t:SetTexCoord(a, b, c, d) self.coord = { a, b, c, d } end
    function t:SetAllPoints() end
    function t:SetSize() end
    function t:SetPoint() end
    function t:ClearAllPoints() end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    function t:IsShown() return self.shown end
    return t
end

local function newFontString(text)
    local fs = { text = text, r = 1, g = 0.82, b = 0 }
    function fs:GetObjectType() return "FontString" end
    function fs:SetText(v) self.text = v end
    function fs:GetText() return self.text end
    function fs:SetTextColor(r, g, b) self.r, self.g, self.b = r, g, b end
    function fs:GetTextColor() return self.r, self.g, self.b end
    function fs:SetJustifyH() end
    function fs:SetWidth() end
    function fs:SetPoint() end
    function fs:Show() end
    function fs:Hide() end
    return fs
end

local function newStatusBar(min, max, value)
    local bar = { min = min, max = max, value = value }
    function bar:GetObjectType() return "StatusBar" end
    function bar:SetMinMaxValues(a, b) self.min, self.max = a, b end
    function bar:GetMinMaxValues() return self.min, self.max end
    function bar:SetValue(v) self.value = v end
    function bar:GetValue() return self.value end
    return bar
end

local function newFrame(name, frameType, parent)
    local f = {
        name = name, frameType = frameType or "Frame", parent = parent,
        shown = true, level = 5, points = {}, events = {}, scripts = {}, children = {},
    }
    function f:GetObjectType() return self.frameType end
    function f:GetName() return self.name end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(v) self.level = v end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetWidth(w) self.w = w end
    function f:SetHeight(h) self.h = h end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:ClearAllPoints() self.points = {} end
    function f:GetNumPoints() return #self.points end
    function f:GetTop() return self.top end
    function f:GetPoint(index)
        local p = self.points[index or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    function f:SetAllPoints() end
    function f:RegisterEvent(e)
        -- The live client raises on an event it does not know.
        if e == "LFG_UPDATE" and not KNOWS_LFG_UPDATE then
            error("attempted to register unknown event: " .. tostring(e))
        end
        self.events[e] = true
    end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:CreateTexture() self.texture = newTexture(); return self.texture end
    function f:CreateFontString(_, _, template)
        local fs = newFontString("")
        fs.template = template
        return fs
    end

    -- Widget surface the options panel touches.
    function f:SetChecked(v) self.checked = not not v end
    function f:GetChecked() return self.checked end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:Enable() self.enabled = true end
    function f:Disable() self.enabled = false end
    function f:IsEnabled() return self.enabled ~= false end
    function f:SetMinMaxValues(a, b) self.min, self.max = a, b end
    function f:SetValueStep() end
    function f:SetObeyStepOnDrag() end
    function f:GetValue() return self.value end
    function f:SetFrameStrata() end
    function f:EnableMouse(v) self.mouseEnabled = not not v end
    function f:IsMouseEnabled() return self.mouseEnabled ~= false end
    function f:SetMovable() end
    function f:RegisterForDrag() end
    function f:SetBackdrop() end

    -- The real client fires OnValueChanged from SetValue, which is what makes the
    -- panel's refresh guard load bearing.
    function f:SetValue(v)
        self.value = v
        if self.scripts.OnValueChanged then
            self.scripts.OnValueChanged(self, v)
        end
    end

    function f:Click()
        if self.frameType == "CheckButton" then
            self.checked = not self.checked
        end
        if self.scripts.OnClick then
            self.scripts.OnClick(self)
        end
    end

    return f
end

--------------------------------------------------------------------------------
-- WoW API mock
--------------------------------------------------------------------------------

function CreateFrame(frameType, name, parent)
    local f = newFrame(name, frameType, parent)
    createdFrames[#createdFrames + 1] = f
    if name then _G[name] = f end
    if type(parent) == "table" and parent.children then
        parent.children[#parent.children + 1] = f
    end
    return f
end

function GetLocale() return LOCALE_UNDER_TEST or "enUS" end
function GetTime() return clock end
function GetBuildInfo() return "5.5.4", "12345", "2026-08-21", 50504 end
function InCombatLockdown() return scenario.combat end
function IsInGroup() return scenario.inGroup end

local function unitInfo(unit)
    if unit == "player" then return scenario.units.player end
    if not scenario.inGroup then return nil end
    return scenario.units[unit]
end

function GetNumGroupMembers()
    if not scenario.inGroup then return 0 end
    local n = 1
    for i = 1, 4 do
        if scenario.units["party" .. i] then n = n + 1 end
    end
    return n
end

function UnitExists(unit) return unitInfo(unit) ~= nil end
function UnitGUID(unit) local u = unitInfo(unit); return u and u.guid or nil end
function UnitName(unit) local u = unitInfo(unit); return u and u.name or nil end
function UnitClass(unit)
    local u = unitInfo(unit)
    if not u then return nil end
    return u.class, u.class
end
function UnitIsUnit(a, b)
    local ua, ub = unitInfo(a), unitInfo(b)
    return ua ~= nil and ua == ub
end
function UnitGroupRolesAssigned(unit)
    local u = unitInfo(unit)
    return u and u.role or "NONE"
end
function UnitIsConnected() return true end
function UnitIsVisible() return scenario.visible end

function GetSpecialization() return 1 end
function GetSpecializationRole() return nil end
function GetSpecializationInfo() return scenario.units.player.spec end
function GetInspectSpecialization(unit)
    local u = unitInfo(unit)
    return (u and u.inspected) and u.spec or 0
end

function CanInspect() return true end

local inspectTarget
function NotifyInspect(unit)
    inspectCalls[#inspectCalls + 1] = unit
    inspectTarget = unit
    local u = unitInfo(unit)
    if u then u.inspected = true end
end

if engine == "talents" then
    -- Classic Era has no specializations at all.
    GetSpecialization = nil
    GetSpecializationRole = nil
    GetSpecializationInfo = nil
    GetInspectSpecialization = nil

    function GetNumTalentTabs() return 3 end

    function GetTalentTabInfo(tab, inspect)
        local unit = inspect and inspectTarget or "player"
        local u = unitInfo(unit)
        if inspect and not (u and u.inspected) then return nil end
        local points = (u and u.trees and u.trees[tab]) or 0
        if talentLayout == "modern" then
            -- id, name, description, icon, pointsSpent
            return 100 + tab, "Tree " .. tab, "desc", "icon", points
        end
        -- name, icon, pointsSpent, fileName
        return "Tree " .. tab, "icon", points, "file"
    end
end

function hooksecurefunc(name, fn) hooks[name] = fn end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

C_Timer = {
    After = function(delay, fn)
        timers[#timers + 1] = { at = clock + delay, delay = delay, fn = fn }
    end,
}

-- Localized role names, as the client exposes them.
TANK = "Tank"
HEALER = "Soigneur"
DAMAGER = "Degats"

CLASS_ICON_TCOORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 },
    PRIEST  = { 0.5, 0.75, 0.25, 0.5 },
    MAGE    = { 0.25, 0.5, 0, 0.25 },
    ROGUE   = { 0.5, 0.75, 0, 0.25 },
}
RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PRIEST  = { r = 1, g = 1, b = 1 },
    MAGE    = { r = 0.41, g = 0.8, b = 0.94 },
    ROGUE   = { r = 1, g = 0.96, b = 0.41 },
}

SlashCmdList = {}
PlayerFrame = newFrame("PlayerFrame")
PlayerFrame.portrait = newTexture()

InspectFrame = { IsShown = function() return inspectFrameShown end }

-- Options host: the modern Settings API, like the live client.
UIParent = newFrame("UIParent")
local settingsRegistered, settingsOpened
local SETTINGS_CATEGORY_ID = 42
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        -- The live client hands back a NUMERIC id.
        local cat = { ID = SETTINGS_CATEGORY_ID, name = name, frame = frame }
        cat.GetID = function(self) return self.ID end
        return cat
    end,
    RegisterAddOnCategory = function(cat) settingsRegistered = cat end,
    OpenToCategory = function(id)
        -- OpenToCategory feeds the id straight to C_SettingsUtil.OpenSettingsPanel,
        -- which only accepts a number: passing a name is a hard error.
        if type(id) ~= "number" then
            error("bad argument #1 to 'OpenSettingsPanel' (outside of expected range)")
        end
        settingsOpened = id
    end,
}

--------------------------------------------------------------------------------
-- Party frames, one layout per structure
--------------------------------------------------------------------------------

local partyFrames = {}      -- [unit] = frame
local partyPortraits = {}   -- [unit] = texture

local function buildPartyFrames()
    if structure == "legacy" then
        for i = 1, 4 do
            local f = newFrame("PartyMemberFrame" .. i)
            f.portrait = newTexture()
            f.portrait:SetTexture("original-portrait-" .. i)
            f.healthbar = newStatusBar(0, 4200, 4200)
            f.manabar = newStatusBar(0, 3000, 1500)
            _G["PartyMemberFrame" .. i] = f
            _G["PartyMemberFrame" .. i .. "Name"] = newFontString("")
            partyFrames["party" .. i] = f
            partyPortraits["party" .. i] = f.portrait
        end
        -- the legacy FrameXML entry points the addon hooks
        function PartyMemberFrame_UpdateAssignedRoles() end
        function PartyMemberFrame_UpdateMember() end
        return
    end

    -- modern and pool: unnamed frames hanging off a PartyFrame container
    local container = newFrame("PartyFrame")
    local members = {}
    for i = 1, 4 do
        local f = newFrame(nil)
        f.unit = "party" .. i
        f.Portrait = newTexture()
        f.Portrait:SetTexture("original-portrait-" .. i)
        f.Name = newFontString("")
        f.HealthBarContainer = { HealthBar = newStatusBar(0, 4200, 4200) }
        f.ManaBar = newStatusBar(0, 3000, 1500)
        -- What the live client actually leaves behind when solo: every frame on
        -- the container's default anchor, which is why they all pile up.
        f:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -40)
        members[i] = f
        partyFrames["party" .. i] = f
        partyPortraits["party" .. i] = f.Portrait
        if structure == "modern" then
            container["MemberFrame" .. i] = f
        end
    end
    -- The live container is a layout frame; model that on one structure so both
    -- the "let Blizzard place them" and the "place them ourselves" paths are
    -- exercised.
    if structure == "pool" then
        container.Layout = function(self)
            layoutCalls = layoutCalls + 1
            for i, f in ipairs(members) do
                if f.shown then f.top = 500 - (i - 1) * 72 end
            end
        end
    end
    container.PartyMemberFramePool = {
        EnumerateActive = function()
            local i = 0
            return function()
                i = i + 1
                return members[i]
            end
        end,
    }
    PartyFrame = container
end

buildPartyFrames()

local function frameFor(unit)
    if unit == "player" then return PlayerFrame end
    return partyFrames[unit]
end

local function portraitFor(unit)
    if unit == "player" then return PlayerFrame.portrait end
    return partyPortraits[unit]
end

local function setPartyFramesShown(shown)
    for _, frame in pairs(partyFrames) do
        frame.shown = shown
    end
end

local function nameTextFor(unit)
    local frame = frameFor(unit)
    if structure == "legacy" then
        return _G[frame:GetName() .. "Name"]
    end
    return frame.Name
end

local function healthBarFor(unit)
    local frame = frameFor(unit)
    if structure == "legacy" then return frame.healthbar end
    return frame.HealthBarContainer.HealthBar
end

local function manaBarFor(unit)
    local frame = frameFor(unit)
    if structure == "legacy" then return frame.manabar end
    return frame.ManaBar
end

-- The addon runs three self-cancelling timers; the delay tells them apart.
local RETRY_DELAY, SETTLE_DELAY, WATCH_DELAY = 2, 0.5, 5

local function timersAt(delay)
    local n = 0
    for _, t in ipairs(timers) do
        if t.delay == delay then n = n + 1 end
    end
    return n
end

local function advance(seconds)
    clock = clock + seconds
    local due, keep = timers, {}
    timers = {}
    for _, t in ipairs(due) do
        if t.at <= clock then t.fn() else keep[#keep + 1] = t end
    end
    for _, t in ipairs(keep) do timers[#timers + 1] = t end
end

--------------------------------------------------------------------------------
-- Load the addon
--------------------------------------------------------------------------------

local ns = {}

local chunk, err = load(ADDON_SOURCE, "PartyRoleIcons.lua")
if not chunk then
    print("could not load the addon source: " .. tostring(err))
    TEST_FAILURES = 1
    return
end
chunk("PartyRoleIcons", ns)

local optionsChunk
if OPTIONS_SOURCE then
    optionsChunk, err = load(OPTIONS_SOURCE, "Options.lua")
    if not optionsChunk then
        print("could not load the options source: " .. tostring(err))
        TEST_FAILURES = 1
        return
    end
    optionsChunk("PartyRoleIcons", ns)
end

local eventFrame
for _, f in ipairs(createdFrames) do
    if f.events["ADDON_LOADED"] and f.scripts.OnEvent then eventFrame = f end
end
if not eventFrame then
    print("event frame not found")
    TEST_FAILURES = 1
    return
end

local function fire(event, arg1) eventFrame.scripts.OnEvent(eventFrame, event, arg1) end
local function slash(input) SlashCmdList["PARTYROLEICONS"](input) end

-- The addon parents its icon to the unit frame and anchors it to the portrait,
-- so the icon is the created frame whose first anchor points at that portrait.
local function iconOf(unit)
    local portrait = portraitFor(unit)
    for _, f in ipairs(createdFrames) do
        if f.name == nil and f.points[1] and f.points[1][2] == portrait then
            return f
        end
    end
    return nil
end

local CIRCLE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"

-- 256x256 sheets, 67px cells: what the live client actually needs.
local ROLE_OF_COORD = {
    ["0,0.2578125,0.26171875,0.515625"] = "TANK",
    ["0.26171875,0.515625,0,0.2578125"] = "HEALER",
    ["0.26171875,0.515625,0.26171875,0.515625"] = "DAMAGER",
}

local function roleShown(unit)
    local icon = iconOf(unit)
    if not icon or not icon:IsShown() then return nil end
    local c = icon.texture.coord
    if not c then return nil end
    return ROLE_OF_COORD[table.concat(c, ",")] or table.concat(c, ",")
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

print("\n== load and first update ==")
fire("ADDON_LOADED", "PartyRoleIcons")
check("SavedVariables table created", type(PartyRoleIconsDB) == "table")
check("defaults applied", PartyRoleIconsDB.size == 16 and PartyRoleIconsDB.anchor == "BOTTOMRIGHT")
check("slash command registered", type(SlashCmdList["PARTYROLEICONS"]) == "function")
check("options panel registered at load, no slash command needed",
    settingsRegistered ~= nil and _G["PartyRoleIconsOptionsPanel"] ~= nil)

fire("PLAYER_ENTERING_WORLD")
check("player hunter resolves to DAMAGER from spec", roleShown("player") == "DAMAGER", roleShown("player"))
check("icon anchored to the portrait, not the frame", iconOf("player") ~= nil)
check("icon texture is the circle sheet", iconOf("player").texture:GetTexture() == CIRCLE)
check("warrior needs an inspect", inspectCalls[1] == "party1", table.concat(inspectCalls, ","))
check("warrior has no icon yet", roleShown("party1") == nil, roleShown("party1"))
check("paladin throttled, no second inspect", #inspectCalls == 1, #inspectCalls)
check("retry timer armed", timersAt(RETRY_DELAY) == 1, timersAt(RETRY_DELAY))
check("settle pass armed after the event", timersAt(SETTLE_DELAY) == 1)

print("\n== inspect results ==")
fire("INSPECT_READY", "Player-2")
check("warrior resolves to TANK", roleShown("party1") == "TANK", roleShown("party1"))

advance(2)
check("paladin inspected after the throttle", inspectCalls[2] == "party2", table.concat(inspectCalls, ","))
fire("INSPECT_READY", "Player-3")
check("paladin resolves to HEALER", roleShown("party2") == "HEALER", roleShown("party2"))
check("empty party slot stays empty", roleShown("party3") == nil)
advance(3)
check("retry timer stopped once everything resolved", timersAt(RETRY_DELAY) == 0,
    timersAt(RETRY_DELAY))
check("role watch stays armed while a role is only a guess",
    timersAt(WATCH_DELAY) == 1, timersAt(WATCH_DELAY))

print("\n== the player's own inspect window is left alone ==")
inspectFrameShown = true
scenario.units.party3 = { name = "Newcomer", class = "PALADIN", guid = "Player-4", role = "NONE",
                          spec = 66, trees = { 0, 41, 0 } }   -- protection, tank
local before = #inspectCalls
fire("GROUP_ROSTER_UPDATE")
check("no inspect while the inspect window is open", #inspectCalls == before, #inspectCalls)
inspectFrameShown = false
advance(2)
check("inspect resumes once it is closed", inspectCalls[#inspectCalls] == "party3", inspectCalls[#inspectCalls])
fire("INSPECT_READY", "Player-4")
check("protection paladin resolves to TANK", roleShown("party3") == "TANK", roleShown("party3"))

print("\n== assigned roles win over spec ==")
scenario.units.party1.role = "DAMAGER"
fire("PLAYER_ROLES_ASSIGNED")
check("assigned DAMAGER overrides the tank spec", roleShown("party1") == "DAMAGER", roleShown("party1"))
scenario.units.party1.role = "NONE"
fire("PLAYER_ROLES_ASSIGNED")
check("falls back to the cached tank spec", roleShown("party1") == "TANK", roleShown("party1"))

print("\n== out of range and combat ==")
scenario.units.party4 = { name = "Faraway", class = "SHAMAN", guid = "Player-5", role = "NONE",
                          spec = 264, trees = { 0, 0, 41 } }  -- restoration, healer
scenario.visible = false
before = #inspectCalls
fire("GROUP_ROSTER_UPDATE")
check("no inspect for a unit the client cannot see", #inspectCalls == before, #inspectCalls)
scenario.visible = true
scenario.combat = true
advance(2)
check("combat does not block the inspect", inspectCalls[#inspectCalls] == "party4", inspectCalls[#inspectCalls])
fire("INSPECT_READY", "Player-5")
check("restoration shaman resolves to HEALER", roleShown("party4") == "HEALER", roleShown("party4"))
scenario.combat = false

if engine == "talents" then
    print("\n== talent tree roles, Classic Era ==")

    scenario.units.party4 = { name = "Bearcat", class = "DRUID", guid = "Player-6",
                              role = "NONE", trees = { 0, 45, 0 } }
    fire("GROUP_ROSTER_UPDATE")
    advance(2)
    fire("INSPECT_READY", "Player-6")
    check("feral druid resolves to damage, the one ambiguous tree",
        roleShown("party4") == "DAMAGER", roleShown("party4"))

    scenario.units.party4 = { name = "Fresh", class = "PALADIN", guid = "Player-7",
                              role = "NONE", trees = { 3, 0, 0 } }
    fire("GROUP_ROSTER_UPDATE")
    advance(2)
    fire("INSPECT_READY", "Player-7")
    check("too few points spent to commit to anything, no icon",
        roleShown("party4") == nil, roleShown("party4"))

    scenario.units.party4 = { name = "Faraway", class = "SHAMAN", guid = "Player-5",
                              role = "NONE", trees = { 0, 0, 41 } }
    fire("GROUP_ROSTER_UPDATE")
    advance(2)
    fire("INSPECT_READY", "Player-5")
    check("restoration shaman back to healer", roleShown("party4") == "HEALER",
        roleShown("party4"))

    scenario.units.player.trees = { 0, 0, 30 }
    fire("CHARACTER_POINTS_CHANGED")
    check("the player's own role is read from the player's own trees",
        roleShown("player") == "DAMAGER", roleShown("player"))
end


print("\n== settings ==")
slash("size 24")
check("size accepted", PartyRoleIconsDB.size == 24 and iconOf("player").w == 24)
check("size applied to every icon", iconOf("party1").w == 24)
slash("size 99")
check("out of range size rejected", PartyRoleIconsDB.size == 24)
slash("size abc")
check("non numeric size rejected", PartyRoleIconsDB.size == 24)
slash("anchor topleft")
check("anchor accepted and normalised", PartyRoleIconsDB.anchor == "TOPLEFT")
slash("anchor nowhere")
check("bad anchor rejected", PartyRoleIconsDB.anchor == "TOPLEFT")
slash("x -4")
slash("y 6")
check("offsets stored", PartyRoleIconsDB.x == -4 and PartyRoleIconsDB.y == 6)
check("icon re-anchored", iconOf("player").points[1][1] == "CENTER" and iconOf("player").points[1][3] == "TOPLEFT")

slash("player")
check("player icon hidden by toggle", roleShown("player") == nil)
slash("player")
check("player icon back", roleShown("player") == "DAMAGER")

slash("off")
check("all icons off", roleShown("player") == nil and roleShown("party1") == nil)
slash("on")
check("all icons back on", roleShown("player") == "DAMAGER" and roleShown("party1") == "TANK")

slash("spec")
check("spec fallback off hides unassigned roles", roleShown("party1") == nil)
slash("spec")
check("spec fallback on restores them", roleShown("party1") == "TANK")

slash("reset")
check("reset restores defaults", PartyRoleIconsDB.size == 16 and PartyRoleIconsDB.anchor == "BOTTOMRIGHT")

print("\n== status, help and debug do not error ==")
slash("")
slash("wat")
slash("debug")
slash("blizzard")
slash("blizzard")
check("survived every command", true)

print("\n== spec change invalidates the cache ==")
scenario.units.party3.spec = 70                 -- retribution
scenario.units.party3.trees = { 0, 0, 41 }
scenario.units.party3.inspected = false
fire("PLAYER_SPECIALIZATION_CHANGED", "party3")
check("cache cleared, icon dropped until re-inspect", roleShown("party3") == nil, roleShown("party3"))
advance(2)
fire("INSPECT_READY", "Player-4")
check("retribution paladin resolves to DAMAGER", roleShown("party3") == "DAMAGER", roleShown("party3"))

print("\n== a guessed role gives way to the assigned one ==")
check("unknown event did not break registration",
    eventFrame.events["LFG_ROLE_CHECK_UPDATE"] == true
    and eventFrame.events["LFG_UPDATE"] == nil)

-- Exactly the reported case: the paladin was inspected as a healer, then picked
-- tank in the dungeon finder role check.
scenario.units.party2.role = "NONE"
fire("GROUP_ROSTER_UPDATE")
check("guessed healer from the spec", roleShown("party2") == "HEALER", roleShown("party2"))

scenario.units.party2.role = "TANK"
fire("LFG_ROLE_CHECK_UPDATE")
check("the role check flips the icon to the chosen role",
    roleShown("party2") == "TANK", roleShown("party2"))

-- Same again, but the role lands only after the event fired: the settle pass has
-- to catch it.
scenario.units.party2.role = "NONE"
fire("GROUP_ROSTER_UPDATE")
check("back to the guess", roleShown("party2") == "HEALER", roleShown("party2"))
fire("LFG_ROLE_CHECK_ROLE_CHOSEN")
scenario.units.party2.role = "DAMAGER"
check("still on the guess right after the event", roleShown("party2") == "HEALER")
advance(1)
check("settle pass picks up the late data", roleShown("party2") == "DAMAGER",
    roleShown("party2"))

-- And with no event at all, the watch has to correct it on its own.
scenario.units.party2.role = "TANK"
check("no event, still stale", roleShown("party2") == "DAMAGER")
advance(6)
check("role watch corrects a missed event", roleShown("party2") == "TANK",
    roleShown("party2"))

-- Once every role is assigned there is nothing left to watch.
scenario.units.player.role = "DAMAGER"
scenario.units.party1.role = "TANK"
scenario.units.party3.role = "DAMAGER"
scenario.units.party4.role = "HEALER"
fire("PLAYER_ROLES_ASSIGNED")
advance(6)
advance(6)
check("watch stops once every role is assigned", timersAt(WATCH_DELAY) == 0,
    timersAt(WATCH_DELAY))
for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
    scenario.units[unit].role = "NONE"
end

print("\n== preview mode ==")
-- back to solo, with the party frames hidden the way Blizzard leaves them
scenario.inGroup = false
scenario.units.party3 = nil
scenario.units.party4 = nil
setPartyFramesShown(false)
fire("GROUP_ROSTER_UPDATE")
check("solo really shows nothing", roleShown("player") == nil and roleShown("party1") == nil)

local inspectsBeforePreview = #inspectCalls
slash("test")
check("preview shows the player role from the spec", roleShown("player") == "DAMAGER", roleShown("player"))
check("preview slot 1 is a tank", roleShown("party1") == "TANK", roleShown("party1"))
check("preview slot 2 is a healer", roleShown("party2") == "HEALER", roleShown("party2"))
check("preview slot 3 and 4 are damage", roleShown("party3") == "DAMAGER" and roleShown("party4") == "DAMAGER")
check("preview shows the hidden party frames", frameFor("party1"):IsShown() and frameFor("party4"):IsShown())
check("preview names the slots with the localized role",
    nameTextFor("party1"):GetText() == "Tank" and nameTextFor("party2"):GetText() == "Soigneur",
    nameTextFor("party1"):GetText())
check("preview fills the bars",
    healthBarFor("party1"):GetValue() == 100 and select(2, healthBarFor("party1"):GetMinMaxValues()) == 100)
check("preview swaps the portrait for a class icon", portraitFor("party1"):GetTexture() == "Interface\\TargetingFrame\\UI-Classes-Circles")
check("no inspect fired for the fake units", #inspectCalls == inspectsBeforePreview,
    #inspectCalls - inspectsBeforePreview)

local usesLayout = structure == "pool"
if usesLayout then
    check("asked the container to lay the frames out", layoutCalls > 0, layoutCalls)
    check("no anchor of ours when Blizzard placed them",
        frameFor("party2"):GetNumPoints() == 1
        and select(2, frameFor("party2"):GetPoint(1)) == PartyFrame,
        frameFor("party2"):GetNumPoints())
else
    check("preview lays the slots out as a list, not a stack",
        select(2, frameFor("party2"):GetPoint(1)) == frameFor("party1")
        and select(2, frameFor("party3"):GetPoint(1)) == frameFor("party2")
        and select(2, frameFor("party4"):GetPoint(1)) == frameFor("party3"))
    if structure == "legacy" then
        check("first slot anchored under the player frame when it had no anchor",
            select(2, frameFor("party1"):GetPoint(1)) == PlayerFrame,
            tostring(select(2, frameFor("party1"):GetPoint(1))))
    else
        check("first slot keeps the anchor Blizzard gave it",
            select(2, frameFor("party1"):GetPoint(1)) == PartyFrame,
            tostring(select(2, frameFor("party1"):GetPoint(1))))
    end
    check("one anchor per frame, re-dressing does not pile them up",
        frameFor("party2"):GetNumPoints() == 1, frameFor("party2"):GetNumPoints())
end
check("dressed frames are taken out of the mouse's way",
    frameFor("party1"):IsMouseEnabled() == false and frameFor("party4"):IsMouseEnabled() == false)

slash("size 22")
check("size still adjustable during the preview", iconOf("party1").w == 22)

-- Blizzard blanks and hides an empty party frame every time it re-evaluates the
-- roster, a zone change included.
frameFor("party3").shown = false
nameTextFor("party3"):SetText("")
healthBarFor("party3"):SetValue(0)
fire("PLAYER_ENTERING_WORLD")
check("preview survives Blizzard blanking the frame",
    frameFor("party3"):IsShown()
    and nameTextFor("party3"):GetText() == "Degats"
    and healthBarFor("party3"):GetValue() == 100,
    nameTextFor("party3"):GetText())
check("icon is back after the re-dress", roleShown("party3") == "DAMAGER")

scenario.combat = true
slash("test")
check("combat refuses to leave the preview", roleShown("party1") == "TANK")
scenario.combat = false

slash("test")
check("leaving the preview hides the icons", roleShown("party1") == nil and roleShown("player") == nil)
check("party frames hidden again", not frameFor("party1"):IsShown() and not frameFor("party4"):IsShown())
check("names restored", nameTextFor("party1"):GetText() == "")
if structure == "legacy" then
    check("anchors given back", frameFor("party2"):GetNumPoints() == 0,
        frameFor("party2"):GetNumPoints())
else
    check("original anchor given back, exactly as it was",
        frameFor("party2"):GetNumPoints() == 1
        and select(2, frameFor("party2"):GetPoint(1)) == PartyFrame,
        frameFor("party2"):GetNumPoints())
end
check("mouse given back", frameFor("party1"):IsMouseEnabled() == true)
check("portraits restored", portraitFor("party1"):GetTexture() == "original-portrait-1")
check("bars restored", healthBarFor("party1"):GetValue() == 4200 and manaBarFor("party1"):GetValue() == 1500)

print("\n== preview hands a slot back when someone joins ==")
slash("test")
check("preview on again", frameFor("party2"):IsShown())
scenario.inGroup = true
frameFor("party1").shown = true
fire("GROUP_ROSTER_UPDATE")
check("real member keeps the real role", roleShown("party1") == "TANK", roleShown("party1"))
check("empty slots stay dressed up", roleShown("party3") == "DAMAGER")
check("the frame handed back is clickable again", frameFor("party1"):IsMouseEnabled() == true)
check("Blizzard's own layout of that slot is left alone",
    frameFor("party1"):GetNumPoints() == (structure == "legacy" and 1 or 1))
slash("test")
check("a slot handed back is left to Blizzard, not restored by us",
    portraitFor("party1"):GetTexture() == "Interface\\TargetingFrame\\UI-Classes-Circles")
check("real member keeps its icon after the preview", roleShown("party1") == "TANK", roleShown("party1"))
check("empty slot icons are gone", roleShown("party3") == nil)

print("\n== options panel ==")
-- solo again, nothing shown, exactly the state a player configures from
scenario.inGroup = false
setPartyFramesShown(false)
slash("reset")
-- Blizzard repaints a slot it takes back over, so start from a clean portrait.
portraitFor("party1"):SetTexture("original-portrait-1")
portraitFor("party1"):SetTexCoord(0, 1, 0, 1)
fire("GROUP_ROSTER_UPDATE")

slash("")
local optionsPanel = _G["PartyRoleIconsOptionsPanel"]
check("bare /pri built the panel", optionsPanel ~= nil)
check("panel registered with the Settings API", settingsRegistered ~= nil)
check("the category id handed out by the API is left untouched",
    settingsRegistered and settingsRegistered.ID == SETTINGS_CATEGORY_ID,
    settingsRegistered and tostring(settingsRegistered.ID))
check("panel opened with the numeric category id", settingsOpened == SETTINGS_CATEGORY_ID,
    tostring(settingsOpened))

local function findWidget(predicate, parent)
    parent = parent or optionsPanel
    for _, child in ipairs(parent.children) do
        if predicate(child) then return child end
        local found = findWidget(predicate, child)
        if found then return found end
    end
    return nil
end

local function checkbox(labelKey)
    local label = ns.L[labelKey]
    return findWidget(function(w)
        return w.frameType == "CheckButton" and w.label and w.label.text == label
    end)
end

local function button(labelKey)
    local label = ns.L[labelKey]
    return findWidget(function(w)
        return w.frameType == "Button" and w.text == label
    end)
end

local anchorGrid = findWidget(function(w) return w.buttons ~= nil end)
local sizeSlider = _G["PartyRoleIconsSizeSlider"]
local offsetXSlider = _G["PartyRoleIconsOffsetXSlider"]
local offsetYSlider = _G["PartyRoleIconsOffsetYSlider"]

check("size slider built", sizeSlider ~= nil and sizeSlider.min == 8 and sizeSlider.max == 40)
check("offset sliders built", offsetXSlider ~= nil and offsetYSlider ~= nil and offsetXSlider.min == -40)
check("anchor keypad built with nine points", anchorGrid ~= nil and (function()
    local n = 0
    for _ in pairs(anchorGrid.buttons) do n = n + 1 end
    return n == 9
end)())
check("every checkbox built", checkbox("OPT_SIMULATE") and checkbox("OPT_ENABLED")
    and checkbox("OPT_PLAYER") and checkbox("OPT_SPEC") and checkbox("OPT_BLIZZARD"))
check("widgets reflect the saved settings",
    sizeSlider:GetValue() == ns.db.size and checkbox("OPT_ENABLED"):GetChecked() == true)

print("\n-- simulate group from the panel --")
checkbox("OPT_SIMULATE"):Click()
check("simulation on", ns.IsPreview() == true)
check("fake group shows the three roles",
    roleShown("party1") == "TANK" and roleShown("party2") == "HEALER" and roleShown("party3") == "DAMAGER")
check("fake portraits are class icons",
    portraitFor("party1"):GetTexture() == "Interface\\TargetingFrame\\UI-Classes-Circles",
    portraitFor("party1"):GetTexture())
check("fake portrait cropped to the warrior cell",
    table.concat(portraitFor("party1").coord, ",") == "0,0.25,0,0.25",
    table.concat(portraitFor("party1").coord, ","))
check("fake names are the localized roles", nameTextFor("party1"):GetText() == "Tank",
    nameTextFor("party1"):GetText())
check("fake name coloured by class", select(1, nameTextFor("party1"):GetTextColor()) == 0.78,
    select(1, nameTextFor("party1"):GetTextColor()))

print("\n-- sliders drive the icons live --")
sizeSlider:SetValue(28)
check("size slider wrote the setting", ns.db.size == 28)
check("icons resized live", iconOf("party1").w == 28, iconOf("party1").w)
offsetXSlider:SetValue(-12)
offsetYSlider:SetValue(9)
check("offsets written", ns.db.x == -12 and ns.db.y == 9)
check("icon re-anchored live", iconOf("party1").points[1][4] == -12 and iconOf("party1").points[1][5] == 9)

print("\n-- keypad and style --")
anchorGrid.buttons["TOPLEFT"]:Click()
check("anchor picked", ns.db.anchor == "TOPLEFT")
check("icon anchored to the new point", iconOf("party1").points[1][3] == "TOPLEFT")
check("keypad highlights the pick", anchorGrid.buttons["TOPLEFT"].selected:IsShown()
    and not anchorGrid.buttons["CENTER"].selected:IsShown())

print("\n-- checkboxes --")
checkbox("OPT_ENABLED"):Click()
check("icons off from the panel", ns.db.enabled == false and roleShown("party1") == nil)
checkbox("OPT_ENABLED"):Click()
check("icons back on", ns.db.enabled == true and roleShown("party1") == "TANK")
checkbox("OPT_PLAYER"):Click()
check("own portrait toggled off", ns.db.showPlayer == false and roleShown("player") == nil)
checkbox("OPT_PLAYER"):Click()
checkbox("OPT_SPEC"):Click()
check("spec fallback toggled off", ns.db.useSpec == false)
checkbox("OPT_SPEC"):Click()

print("\n-- combat refuses the simulation switch --")
scenario.combat = true
checkbox("OPT_SIMULATE"):Click()
check("simulation unchanged in combat", ns.IsPreview() == true)
check("checkbox snapped back", checkbox("OPT_SIMULATE"):GetChecked() == true)
scenario.combat = false

print("\n-- chat commands and the panel stay in step --")
slash("size 14")
check("slider followed the slash command", sizeSlider:GetValue() == 14, sizeSlider:GetValue())
slash("anchor bottom")
check("keypad followed the slash command", anchorGrid.buttons["BOTTOM"].selected:IsShown())

button("OPT_RESET"):Click()
check("reset button restored the defaults",
    ns.db.size == 16 and ns.db.anchor == "BOTTOMRIGHT")
check("widgets followed the reset", sizeSlider:GetValue() == 16)
check("simulation survives a settings reset", ns.IsPreview() == true)

checkbox("OPT_SIMULATE"):Click()
check("simulation off from the panel", ns.IsPreview() == false)
check("fake group cleaned up", roleShown("party1") == nil and not frameFor("party1"):IsShown())
check("portraits restored after the simulation",
    portraitFor("party1"):GetTexture() == "original-portrait-1")

print("")
print(("%d checks, %d failures"):format(checks, failures))
TEST_FAILURES = failures
