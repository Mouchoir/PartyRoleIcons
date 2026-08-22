-- PartyRoleIcons
-- Retail-style tank / healer / damage icons on the Blizzard player and party
-- unit frames for Mists of Pandaria Classic.
--
-- Roles come from the group assignment first (UnitGroupRolesAssigned). When the
-- group never assigned roles - which is the case for every party that was not
-- built through the dungeon finder - the icon falls back to the unit's actual
-- specialization, resolved through a throttled inspect and cached per GUID.
--
-- Party frames are resolved at runtime because 5.5 ships the modern frame
-- layout: PartyFrame.MemberFrameN out of a frame pool, not the old
-- PartyMemberFrameN globals. Both are supported, see ResolveFrame.

local ADDON_NAME, ns = ...

-- WoW runs Lua 5.1, where unpack is a global; the headless test VM is 5.3.
local unpack = unpack or table.unpack

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------

local L = {}
ns.L = L

L["PREFIX"]           = "|cFF33CCFF[PRI]|r "
L["LOADED"]           = "loaded. Type |cFF00CCFF/pri|r for the options."
L["ENABLED"]          = "Icons |cFF00FF00enabled|r."
L["DISABLED"]         = "Icons |cFFFF0000disabled|r."
L["PLAYER_ON"]        = "Player frame icon |cFF00FF00shown|r."
L["PLAYER_OFF"]       = "Player frame icon |cFFFF0000hidden|r."
L["SPEC_ON"]          = "Specialization fallback |cFF00FF00on|r: roles are read from the spec when the group assigned none."
L["SPEC_OFF"]         = "Specialization fallback |cFFFF0000off|r: only assigned roles are shown."
L["BLIZZARD_ON"]      = "Blizzard's own party role icon is now |cFFFF0000hidden|r."
L["BLIZZARD_OFF"]     = "Blizzard's own party role icon is left alone again after a UI reload."
L["SIZE_SET"]         = "Icon size: |cFF00CCFF%d|r."
L["OFFSET_SET"]       = "Offset: |cFF00CCFFx=%d, y=%d|r."
L["ANCHOR_SET"]       = "Anchor: |cFF00CCFF%s|r."
L["RESET"]            = "Settings restored to defaults."
L["BAD_VALUE"]        = "Invalid value: |cFFFF6600%s|r."
L["TEST_ON"]          = "Preview |cFF00FF00on|r: the empty party slots are dressed up so you can set the icons up while solo."
L["TEST_OFF"]         = "Preview |cFFFF0000off|r."
L["TEST_COMBAT"]      = "The party frames cannot be shown or hidden during combat: try again out of combat."
L["TEST_HINT"]        = "Adjust with |cFF00CCFF/pri size|r, |cFF00CCFF/pri x|r, |cFF00CCFF/pri y|r and |cFF00CCFF/pri anchor|r, then |cFF00CCFF/pri test|r again to leave."
L["TEST_NO_FRAME"]    = "No party frame to dress up: this client only builds them once you are in a group."
L["TEST_RAID_STYLE"]  = "Raid-style party frames are on, so the frames dressed up here are not the ones you actually play with."
L["STATUS"]           = "icons: %s | own portrait: %s | spec fallback: %s | size: %d | anchor: %s (%d, %d) | preview: %s"
L["ON"]               = "|cFF00FF00on|r"
L["OFF"]              = "|cFFFF0000off|r"
L["HELP_HEADER"]      = "commands:"
L["HELP_CONFIG"]      = "|cFF00CCFF/pri|r - open the options panel"
L["HELP_TOGGLE"]      = "|cFF00CCFF/pri on|r or |cFF00CCFF/pri off|r - turn the icons on or off"
L["HELP_PLAYER"]      = "|cFF00CCFF/pri player|r - show or hide the icon on your own frame"
L["HELP_SPEC"]        = "|cFF00CCFF/pri spec|r - use the specialization when no role was assigned"
L["HELP_SIZE"]        = "|cFF00CCFF/pri size 8-40|r - icon size in pixels"
L["HELP_OFFSET"]      = "|cFF00CCFF/pri x N|r and |cFF00CCFF/pri y N|r - nudge the icon"
L["HELP_ANCHOR"]      = "|cFF00CCFF/pri anchor POINT|r - portrait corner the icon hangs on"
L["HELP_BLIZZARD"]    = "|cFF00CCFF/pri blizzard|r - hide Blizzard's own role icon"
L["HELP_TEST"]        = "|cFF00CCFF/pri test|r - dress up the empty party frames to set the icons up while solo"
L["HELP_RESET"]       = "|cFF00CCFF/pri reset|r - back to defaults"
L["HELP_DEBUG"]       = "|cFF00CCFF/pri debug|r - dump what the addon sees, for bug reports"
L["DEBUG_HEADER"]     = "debug dump"
L["DEBUG_RAID_STYLE"] = "Raid-style party frames are active: Blizzard draws its own role icons there, so there is nothing for this addon to attach to."
L["OPT_TITLE"]        = "Party Role Icons"
L["OPT_INTRO"]        = "Tank, healer and damage icons on the player and party portraits. Turn the group simulation on to set them up while solo."
L["OPT_ENABLED"]      = "Show role icons"
L["OPT_PLAYER"]       = "Show on my own portrait"
L["OPT_SPEC"]         = "Read the role from the specialization when the group assigned none"
L["OPT_BLIZZARD"]     = "Hide Blizzard's own role icon"
L["OPT_SIMULATE"]     = "Simulate a group"
L["OPT_SIMULATE_TIP"] = "Dresses up the empty party frames with a fake group so you can see the result without being in one. Nothing is saved."
L["OPT_SIZE"]         = "Icon size"
L["OPT_POSITION"]     = "Position around the portrait"
L["OPT_OFFSET_X"]     = "Horizontal offset"
L["OPT_OFFSET_Y"]     = "Vertical offset"
L["OPT_RESET"]        = "Restore defaults"
L["OPT_COMBAT"]       = "Out of combat only."

if GetLocale() == "frFR" then
    L["LOADED"]           = "chargé. Tapez |cFF00CCFF/pri|r pour les options."
    L["ENABLED"]          = "Icônes |cFF00FF00activées|r."
    L["DISABLED"]         = "Icônes |cFFFF0000désactivées|r."
    L["PLAYER_ON"]        = "Icône sur votre portrait |cFF00FF00affichée|r."
    L["PLAYER_OFF"]       = "Icône sur votre portrait |cFFFF0000masquée|r."
    L["SPEC_ON"]          = "Repli sur la spécialisation |cFF00FF00actif|r : le rôle est lu dans la spé quand le groupe n'en a assigné aucun."
    L["SPEC_OFF"]         = "Repli sur la spécialisation |cFFFF0000inactif|r : seuls les rôles assignés sont affichés."
    L["BLIZZARD_ON"]      = "L'icône de rôle d'origine de Blizzard est maintenant |cFFFF0000masquée|r."
    L["BLIZZARD_OFF"]     = "L'icône de rôle d'origine de Blizzard revient au prochain rechargement de l'interface."
    L["SIZE_SET"]         = "Taille d'icône : |cFF00CCFF%d|r."
    L["OFFSET_SET"]       = "Décalage : |cFF00CCFFx=%d, y=%d|r."
    L["ANCHOR_SET"]       = "Ancrage : |cFF00CCFF%s|r."
    L["RESET"]            = "Réglages remis par défaut."
    L["BAD_VALUE"]        = "Valeur invalide : |cFFFF6600%s|r."
    L["TEST_ON"]          = "Aperçu |cFF00FF00actif|r : les emplacements de groupe vides sont habillés pour régler les icônes en solo."
    L["TEST_OFF"]         = "Aperçu |cFFFF0000inactif|r."
    L["TEST_COMBAT"]      = "Les cadres de groupe ne peuvent pas être affichés ou masqués en combat : réessayez hors combat."
    L["TEST_HINT"]        = "Réglez avec |cFF00CCFF/pri size|r, |cFF00CCFF/pri x|r, |cFF00CCFF/pri y|r et |cFF00CCFF/pri anchor|r, puis |cFF00CCFF/pri test|r pour sortir."
    L["TEST_NO_FRAME"]    = "Aucun cadre de groupe à habiller : ce client ne les construit qu'une fois en groupe."
    L["TEST_RAID_STYLE"]  = "Les cadres de groupe style raid sont actifs : les cadres habillés ici ne sont donc pas ceux que vous utilisez en jeu."
    L["STATUS"]           = "icônes : %s | portrait joueur : %s | repli spé : %s | taille : %d | ancrage : %s (%d, %d) | aperçu : %s"
    L["ON"]               = "|cFF00FF00actif|r"
    L["OFF"]              = "|cFFFF0000inactif|r"
    L["HELP_HEADER"]      = "commandes :"
    L["HELP_CONFIG"]      = "|cFF00CCFF/pri|r - ouvre le panneau d'options"
    L["HELP_TOGGLE"]      = "|cFF00CCFF/pri on|r ou |cFF00CCFF/pri off|r - active ou coupe les icônes"
    L["HELP_PLAYER"]      = "|cFF00CCFF/pri player|r - affiche ou masque l'icône sur votre propre portrait"
    L["HELP_SPEC"]        = "|cFF00CCFF/pri spec|r - lit le rôle dans la spé quand aucun rôle n'est assigné"
    L["HELP_SIZE"]        = "|cFF00CCFF/pri size 8-40|r - taille de l'icône en pixels"
    L["HELP_OFFSET"]      = "|cFF00CCFF/pri x N|r et |cFF00CCFF/pri y N|r - décale l'icône"
    L["HELP_ANCHOR"]      = "|cFF00CCFF/pri anchor POINT|r - coin du portrait où accrocher l'icône"
    L["HELP_BLIZZARD"]    = "|cFF00CCFF/pri blizzard|r - masque l'icône de rôle d'origine de Blizzard"
    L["HELP_TEST"]        = "|cFF00CCFF/pri test|r - habille les cadres de groupe vides pour régler les icônes en solo"
    L["HELP_RESET"]       = "|cFF00CCFF/pri reset|r - remet les réglages par défaut"
    L["HELP_DEBUG"]       = "|cFF00CCFF/pri debug|r - affiche ce que voit l'addon, pour un rapport de bug"
    L["DEBUG_HEADER"]     = "diagnostic"
    L["DEBUG_RAID_STYLE"] = "Les cadres de groupe style raid sont actifs : Blizzard y dessine ses propres icônes de rôle, cet addon n'a rien à accrocher."
    L["OPT_INTRO"]        = "Icônes de tank, soigneur et dps sur les portraits du joueur et du groupe. Activez la simulation de groupe pour les régler en solo."
    L["OPT_ENABLED"]      = "Afficher les icônes de rôle"
    L["OPT_PLAYER"]       = "Afficher sur mon propre portrait"
    L["OPT_SPEC"]         = "Lire le rôle dans la spécialisation quand le groupe n'en a assigné aucun"
    L["OPT_BLIZZARD"]     = "Masquer l'icône de rôle d'origine de Blizzard"
    L["OPT_SIMULATE"]     = "Simuler un groupe"
    L["OPT_SIMULATE_TIP"] = "Habille les cadres de groupe vides avec un faux groupe pour voir le résultat sans être en groupe. Rien n'est sauvegardé."
    L["OPT_SIZE"]         = "Taille de l'icône"
    L["OPT_POSITION"]     = "Position autour du portrait"
    L["OPT_OFFSET_X"]     = "Décalage horizontal"
    L["OPT_OFFSET_Y"]     = "Décalage vertical"
    L["OPT_RESET"]        = "Réglages par défaut"
    L["OPT_COMBAT"]       = "Hors combat uniquement."
end

local function Say(msg, ...)
    if select("#", ...) > 0 then
        msg = msg:format(...)
    end
    print(L["PREFIX"] .. msg)
end
ns.Say = Say

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

local DEFAULTS = {
    enabled      = true,
    showPlayer   = true,
    useSpec      = true,
    hideBlizzard = false,
    size         = 16,
    anchor       = "BOTTOMRIGHT",
    x            = -1,
    y            = 1,
}

ns.DEFAULTS = DEFAULTS

local db

local function InitDB()
    if type(PartyRoleIconsDB) ~= "table" then
        PartyRoleIconsDB = {}
    end
    db = PartyRoleIconsDB
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end
    ns.db = db
end

--------------------------------------------------------------------------------
-- Artwork
--------------------------------------------------------------------------------

-- One artwork, on purpose. UI-LFG-ICON-ROLES is the round icon with the dark
-- backing that the game itself puts on unit frames: a 256x256 sheet with 67px
-- cells, so it stays crisp at any icon size. Note the legacy
-- GetTexCoordsForRoleSmallCircle helper returns 64px-era coordinates that do not
-- match this sheet, and slicing a fragment out of it is exactly what makes role
-- icons look truncated in other addons.
--
-- Blizzard's other sheet, UI-LFG-ICON-PORTRAITROLES, carries the same artwork
-- without the backing, but at roughly 18 texels per cell it is a blurry mess on a
-- unit frame, and the group finder atlases that should have replaced it render
-- wrong here. A choice between a good icon and a bad one is not a choice worth
-- offering, so there is no style setting.
local ROLE_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local ROLE_COORDS = {
    TANK    = { 0,         66 / 256,  67 / 256, 132 / 256 },
    HEALER  = { 67 / 256, 132 / 256,  0,         66 / 256 },
    DAMAGER = { 67 / 256, 132 / 256, 67 / 256, 132 / 256 },
}

-- Also the layout of the options panel's position picker: three rows of three,
-- read like a keypad around the portrait.
local ANCHOR_GRID = {
    { "TOPLEFT",    "TOP",    "TOPRIGHT" },
    { "LEFT",       "CENTER", "RIGHT" },
    { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
}
ns.ANCHOR_GRID = ANCHOR_GRID

local VALID_ANCHORS = {}
for _, row in ipairs(ANCHOR_GRID) do
    for _, anchor in ipairs(row) do
        VALID_ANCHORS[anchor] = true
    end
end

--------------------------------------------------------------------------------
-- Role sources
--------------------------------------------------------------------------------

local VALID_ROLES = { TANK = true, HEALER = true, DAMAGER = true }

-- Every Mists specialization, so the addon never depends on
-- GetSpecializationRoleByID being exposed by the client.
local SPEC_ROLE = {
    [250] = "TANK",    [251] = "DAMAGER", [252] = "DAMAGER",                 -- Death Knight
    [102] = "DAMAGER", [103] = "DAMAGER", [104] = "TANK",    [105] = "HEALER", -- Druid
    [253] = "DAMAGER", [254] = "DAMAGER", [255] = "DAMAGER",                 -- Hunter
    [62]  = "DAMAGER", [63]  = "DAMAGER", [64]  = "DAMAGER",                 -- Mage
    [268] = "TANK",    [269] = "DAMAGER", [270] = "HEALER",                  -- Monk
    [65]  = "HEALER",  [66]  = "TANK",    [70]  = "DAMAGER",                 -- Paladin
    [256] = "HEALER",  [257] = "HEALER",  [258] = "DAMAGER",                 -- Priest
    [259] = "DAMAGER", [260] = "DAMAGER", [261] = "DAMAGER",                 -- Rogue
    [262] = "DAMAGER", [263] = "DAMAGER", [264] = "HEALER",                  -- Shaman
    [265] = "DAMAGER", [266] = "DAMAGER", [267] = "DAMAGER",                 -- Warlock
    [71]  = "DAMAGER", [72]  = "DAMAGER", [73]  = "TANK",                    -- Warrior
}

-- Classes with no tank and no healer specialization: never worth an inspect.
local PURE_DAMAGE = {
    HUNTER = true, MAGE = true, ROGUE = true, WARLOCK = true,
}

local function RoleFromSpecID(specID)
    if not specID or specID == 0 then return nil end
    local role = SPEC_ROLE[specID]
    if role then return role end
    if GetSpecializationRoleByID then
        role = GetSpecializationRoleByID(specID)
        if VALID_ROLES[role] then return role end
    end
    return nil
end

local function PlayerSpecRole()
    if not GetSpecialization then return nil end
    local index = GetSpecialization()
    if not index then return nil end
    if GetSpecializationRole then
        local role = GetSpecializationRole(index)
        if VALID_ROLES[role] then return role end
    end
    if GetSpecializationInfo then
        return RoleFromSpecID(GetSpecializationInfo(index))
    end
    return nil
end

--------------------------------------------------------------------------------
-- Role sources, talent tree flavour
--------------------------------------------------------------------------------

-- Classic Era has no specializations at all, so the role has to come from which
-- talent tree the points went into. Trees are identified by their tab index,
-- which is fixed per class, rather than by their localized name.
--
-- Feral Combat is the one genuinely ambiguous tree: the same tree is the bear
-- tank and the cat, and nothing in the talent data separates them. It resolves
-- to damage, the more common build.
local TREE_ROLES = {
    WARRIOR = { "DAMAGER", "DAMAGER", "TANK" },     -- Arms, Fury, Protection
    PALADIN = { "HEALER",  "TANK",    "DAMAGER" },  -- Holy, Protection, Retribution
    PRIEST  = { "HEALER",  "HEALER",  "DAMAGER" },  -- Discipline, Holy, Shadow
    SHAMAN  = { "DAMAGER", "DAMAGER", "HEALER" },   -- Elemental, Enhancement, Restoration
    DRUID   = { "DAMAGER", "DAMAGER", "HEALER" },   -- Balance, Feral Combat, Restoration
    HUNTER  = { "DAMAGER", "DAMAGER", "DAMAGER" },
    MAGE    = { "DAMAGER", "DAMAGER", "DAMAGER" },
    ROGUE   = { "DAMAGER", "DAMAGER", "DAMAGER" },
    WARLOCK = { "DAMAGER", "DAMAGER", "DAMAGER" },
}

-- Below this the character has not committed to anything yet.
local MIN_TREE_POINTS = 5

-- The specialization API is the better source wherever it exists. It also has to
-- be the deciding test rather than the talent API, because on Mists
-- GetNumTalentTabs still exists but throws when called.
local USE_TALENT_TREES = not (GetInspectSpecialization and GetSpecializationInfo)

local function TreePoints(tab, inspect)
    local _, _, third, _, fifth = GetTalentTabInfo(tab, inspect)
    -- The return layout moved: points are the third value on the older signature
    -- (name, icon, points, file) and the fifth on the newer one
    -- (id, name, description, icon, points). Take the first number on offer.
    if type(third) == "number" then return third end
    if type(fifth) == "number" then return fifth end
    return 0
end

local function DominantTree(inspect)
    local tabs = GetNumTalentTabs(inspect) or 0
    local best, bestPoints = nil, 0
    for tab = 1, tabs do
        local points = TreePoints(tab, inspect)
        if points > bestPoints then
            best, bestPoints = tab, points
        end
    end
    return best, bestPoints
end

local function TalentTreeRole(unit, inspect)
    if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end

    local _, class = UnitClass(unit)
    local roles = class and TREE_ROLES[class]
    if not roles then return nil end

    local ok, tab, points = pcall(DominantTree, inspect)
    if not ok or not tab or points < MIN_TREE_POINTS then return nil end
    return roles[tab]
end

--------------------------------------------------------------------------------
-- Frame resolution
--------------------------------------------------------------------------------

local UNITS = { "player", "party1", "party2", "party3", "party4" }

-- 5.5 builds the party frames the modern way: a PartyFrame container holding
-- MemberFrameN out of a frame pool. The old PartyMemberFrameN globals do not
-- exist there, which is why every addon that only looks them up shows nothing on
-- party members. Both layouts are handled, newest first.
local function ResolveFrame(unit)
    if unit == "player" then
        return _G["PlayerFrame"], "PlayerFrame"
    end

    local index = tonumber(unit:match("party(%d)"))
    if not index then return nil, "?" end

    local container = _G["PartyFrame"]
    if container then
        local member = container["MemberFrame" .. index]
        if member then
            return member, "PartyFrame.MemberFrame" .. index
        end

        local pool = container.PartyMemberFramePool
        if pool and pool.EnumerateActive then
            for frame in pool:EnumerateActive() do
                if frame.unit == unit or frame.displayedUnit == unit then
                    return frame, "PartyFrame pool"
                end
            end
        end
    end

    local legacy = _G["PartyMemberFrame" .. index]
    if legacy then
        return legacy, "PartyMemberFrame" .. index
    end

    return nil, "missing"
end

local function IsTexture(object)
    return type(object) == "table"
        and object.GetObjectType
        and object:GetObjectType() == "Texture"
end

local function IsOfType(object, objectType)
    return type(object) == "table"
        and object.GetObjectType
        and object:GetObjectType() == objectType
end

-- The portrait is the region the icon hangs on, and its field name moved around
-- over the years: portrait, Portrait, or a PortraitContainer child.
local function ResolvePortrait(frame)
    local frameName = frame.GetName and frame:GetName() or nil
    local candidates = {
        frame.portrait,
        frame.Portrait,
        frame.PortraitContainer and frame.PortraitContainer.Portrait or nil,
        frameName and _G[frameName .. "Portrait"] or nil,
    }
    for i = 1, 4 do
        if IsTexture(candidates[i]) then
            return candidates[i]
        end
    end
    return frame
end

local function ResolveNameText(frame)
    local frameName = frame.GetName and frame:GetName() or nil
    local candidates = {
        frame.Name,
        frame.name,
        frameName and _G[frameName .. "Name"] or nil,
    }
    for i = 1, 3 do
        if IsOfType(candidates[i], "FontString") then
            return candidates[i]
        end
    end
    return nil
end

local function ResolveBars(frame)
    local frameName = frame.GetName and frame:GetName() or nil
    local candidates = {
        frame.healthbar,
        frame.HealthBar,
        frame.HealthBarContainer and frame.HealthBarContainer.HealthBar or nil,
        frameName and _G[frameName .. "HealthBar"] or nil,
        frame.manabar,
        frame.ManaBar,
        frameName and _G[frameName .. "ManaBar"] or nil,
    }
    local bars, seen = {}, {}
    for i = 1, 7 do
        local bar = candidates[i]
        if IsOfType(bar, "StatusBar") and not seen[bar] then
            seen[bar] = true
            bars[#bars + 1] = bar
        end
    end
    return bars
end

local function ResolveNativeRoleIcon(frame)
    local frameName = frame.GetName and frame:GetName() or nil
    return frame.RoleIcon
        or frame.roleIcon
        or (frameName and _G[frameName .. "RoleIcon"])
        or nil
end

--------------------------------------------------------------------------------
-- Inspect queue
--------------------------------------------------------------------------------

local INSPECT_THROTTLE = 1.5
local INSPECT_TIMEOUT = 5

local specRoleCache = {}   -- [guid] = role
local inspectPending       -- GUID of the inspect currently in flight
local inspectSentAt = 0
local nextInspectAt = 0
local needsRetry = false

local function UnitForGUID(guid)
    if not guid then return nil end
    for i = 1, #UNITS do
        local unit = UNITS[i]
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

local function RequestInspect(unit, guid)
    local now = GetTime()

    -- One inspect at a time, and never faster than the throttle. Combat is fine:
    -- a dungeon group is in combat most of the time, which is exactly when the
    -- icons are wanted.
    if inspectPending and now - inspectSentAt < INSPECT_TIMEOUT then
        needsRetry = true
        return
    end
    if now < nextInspectAt then
        needsRetry = true
        return
    end

    -- UnitIsVisible is the real precondition: the server only answers for a unit
    -- the client has loaded. Never fight the player's own inspect window either.
    if (InspectFrame and InspectFrame:IsShown())
        or not UnitIsConnected(unit)
        or not UnitIsVisible(unit)
        or not CanInspect(unit, false) then
        needsRetry = true
        return
    end

    inspectPending = guid
    inspectSentAt = now
    nextInspectAt = now + INSPECT_THROTTLE
    needsRetry = true
    NotifyInspect(unit)
end

--------------------------------------------------------------------------------
-- Icons
--------------------------------------------------------------------------------

-- Keyed by frame, not by unit: the modern party frames come out of a pool and
-- can be recycled behind our back. Weak keys so a released frame is collectable.
local icons = setmetatable({}, { __mode = "k" })

local function ApplyLayout(icon)
    icon:SetSize(db.size, db.size)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", icon.anchorRegion, db.anchor, db.x, db.y)
end

-- Set once the role is known, not at layout time.
local function ApplyRoleArt(texture, role)
    texture:SetTexture(ROLE_TEXTURE)
    local coords = ROLE_COORDS[role]
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

local function EnsureIcon(frame)
    local icon = icons[frame]
    if icon then return icon end

    -- A child frame drawn above the parent: the unit frame border sits over the
    -- portrait corners, so an OVERLAY texture parented to the unit frame itself
    -- can still end up behind that border.
    icon = CreateFrame("Frame", nil, frame)
    icon:SetFrameLevel(frame:GetFrameLevel() + 10)
    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints(icon)
    icon.anchorRegion = ResolvePortrait(frame)
    icon:Hide()

    icons[frame] = icon
    ApplyLayout(icon)
    return icon
end

--------------------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------------------

-- Solo, UnitExists("party1") is false and the party frames are hidden, so there
-- is nothing to hang an icon on. The preview dresses up the empty party slots
-- with a placeholder portrait, a role name and full bars, entirely client side,
-- so the size and the position can be set up without a real group. It is
-- deliberately a runtime state: nothing is saved, a reload always comes back to
-- the real frames.

-- A plausible five man: one of each role, with a class whose icon makes the role
-- obvious at a glance. The name is the localized role name, so the preview reads
-- as a legend rather than as four invented players.
local PREVIEW_SLOTS = {
    party1 = { role = "TANK",    class = "WARRIOR" },
    party2 = { role = "HEALER",  class = "PRIEST" },
    party3 = { role = "DAMAGER", class = "MAGE" },
    party4 = { role = "DAMAGER", class = "ROGUE" },
}

local PREVIEW_ROLES = {}
for unit, slot in pairs(PREVIEW_SLOTS) do
    PREVIEW_ROLES[unit] = slot.role
end

local CLASS_PORTRAITS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local FALLBACK_PORTRAIT = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Gap between two party frames, on top of the frame's own height. Blizzard chains
-- them the same way once it builds a real party list.
local PREVIEW_GAP = 23

local previewActive = false
local previewState = {}

-- Solo, Blizzard leaves every party frame on the container's default anchor, so
-- showing them all puts the four of them in the same spot. Chain them the way a
-- real party list is laid out, and only ever move a slot nobody is standing in.
local function PositionPreviewFrame(unit, frame, state)
    local index = tonumber(unit:match("party(%d)"))
    if not index then return end

    local previous = index > 1 and ResolveFrame("party" .. (index - 1)) or nil
    local anchorTo, point, relativePoint, x, y

    if previous then
        -- Already chained under its predecessor: Blizzard has laid the list out,
        -- leave it alone.
        local _, relativeTo = frame:GetPoint(1)
        if relativeTo == previous then return end
        anchorTo, point, relativePoint, x, y = previous, "TOPLEFT", "BOTTOMLEFT", 0, -PREVIEW_GAP
    else
        -- First slot: keep whatever anchor it already has, it is where Blizzard
        -- puts party member one. Only step in when it has none at all.
        if frame:GetNumPoints() > 0 then return end
        anchorTo, point, relativePoint, x, y = _G["PlayerFrame"], "TOPLEFT", "BOTTOMLEFT", 0, -40
        if not anchorTo then return end
    end

    state.points = state.points or {}
    for i = 1, frame:GetNumPoints() do
        state.points[i] = { frame:GetPoint(i) }
    end
    state.repositioned = true

    frame:ClearAllPoints()
    frame:SetPoint(point, anchorTo, relativePoint, x, y)
end

local function DressFrame(unit, frame)
    -- The original look is captured once, on the first dress up.
    local state = previewState[frame]
    if not state then
        state = { shown = frame:IsShown(), bars = {} }

        local nameText = ResolveNameText(frame)
        if nameText then
            state.nameText = nameText
            state.name = nameText:GetText()
        end

        local portrait = ResolvePortrait(frame)
        if IsTexture(portrait) then
            state.portrait = portrait
            state.portraitTexture = portrait:GetTexture()
        end

        if state.nameText and state.nameText.GetTextColor then
            state.r, state.g, state.b = state.nameText:GetTextColor()
        end

        for _, bar in ipairs(ResolveBars(frame)) do
            local minValue, maxValue = bar:GetMinMaxValues()
            state.bars[#state.bars + 1] = {
                bar = bar, min = minValue, max = maxValue, value = bar:GetValue(),
            }
        end

        -- A dressed up frame points at a unit that does not exist, and Blizzard's
        -- own hover and click handlers assume it does: their tooltip code errors
        -- out on the missing aura data. Nothing to interact with, so take the
        -- frame out of the mouse's way entirely.
        if frame.EnableMouse then
            state.mouseEnabled = frame.IsMouseEnabled and frame:IsMouseEnabled()
            frame:EnableMouse(false)
        end

        previewState[frame] = state
    end

    -- The placeholder look is re-applied on every refresh: Blizzard blanks and
    -- hides an empty party frame whenever it re-evaluates the roster, zoning
    -- included, and would otherwise wipe the preview.
    local slot = PREVIEW_SLOTS[unit]
    local role = slot.role
    if state.nameText then
        state.nameText:SetText(_G[role] or role)
        local colors = _G["RAID_CLASS_COLORS"]
        local color = colors and colors[slot.class]
        if color and state.nameText.SetTextColor then
            state.nameText:SetTextColor(color.r, color.g, color.b)
        end
    end
    if state.portrait then
        -- The class icon sheet is a 4x4 grid of round portraits, which is exactly
        -- what the party portrait region expects.
        local coords = _G["CLASS_ICON_TCOORDS"]
        coords = coords and coords[slot.class]
        if coords then
            state.portrait:SetTexture(CLASS_PORTRAITS)
            state.portrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            state.portrait:SetTexture(FALLBACK_PORTRAIT)
        end
    end
    for _, entryBar in ipairs(state.bars) do
        entryBar.bar:SetMinMaxValues(0, 100)
        entryBar.bar:SetValue(100)
    end
    if not frame:IsShown() then
        frame:Show()
    end
end

local function RestoreFrame(frame, keepDisplay)
    local state = previewState[frame]
    if not state then return end
    previewState[frame] = nil

    -- Interactivity always goes back, even on a handover: a real member's frame
    -- has to be clickable again.
    if state.mouseEnabled ~= nil and frame.EnableMouse then
        frame:EnableMouse(state.mouseEnabled)
    end

    -- keepDisplay is for a slot a real party member just took over: Blizzard now
    -- owns the name, the portrait, the bars and the position, so putting the
    -- placeholder values back would fight the layout it just did.
    if keepDisplay then return end

    if state.repositioned then
        frame:ClearAllPoints()
        for _, point in ipairs(state.points or {}) do
            frame:SetPoint(unpack(point))
        end
    end

    if state.nameText then
        state.nameText:SetText(state.name or "")
        if state.r and state.nameText.SetTextColor then
            state.nameText:SetTextColor(state.r, state.g, state.b)
        end
    end
    if state.portrait then
        state.portrait:SetTexture(state.portraitTexture)
        -- Portraits are drawn uncropped, so put the coordinates back whatever the
        -- class icon sheet needed.
        state.portrait:SetTexCoord(0, 1, 0, 1)
    end
    for _, entryBar in ipairs(state.bars) do
        entryBar.bar:SetMinMaxValues(entryBar.min, entryBar.max)
        entryBar.bar:SetValue(entryBar.value)
    end
    if not state.shown then
        frame:Hide()
    end
end

-- The party frames hang off a layout container, so the exact geometry is one call
-- away and there is no need to guess a spacing. Only trusted if it actually
-- spread the frames out, since a container that lays out nothing leaves them
-- piled up on the same spot.
local function LayoutPreviewFrames()
    local container = _G["PartyFrame"]
    if not (container and container.Layout) then return false end

    container:Layout()

    local first, second = ResolveFrame("party1"), ResolveFrame("party2")
    if not (first and second and first.GetTop and second.GetTop) then return false end

    local firstTop, secondTop = first:GetTop(), second:GetTop()
    return firstTop ~= nil and secondTop ~= nil and math.abs(firstTop - secondTop) > 1
end

-- Follows the roster while the preview is on: a slot someone joins goes back to
-- Blizzard, a slot that empties out gets dressed up again.
local function RefreshPreview()
    if not previewActive or InCombatLockdown() then return end

    local dressed = {}
    for i = 2, #UNITS do
        local unit = UNITS[i]
        local frame = ResolveFrame(unit)
        if frame then
            if UnitExists(unit) then
                RestoreFrame(frame, true)
            else
                DressFrame(unit, frame)
                dressed[#dressed + 1] = { unit = unit, frame = frame }
            end
        end
    end

    if #dressed == 0 or LayoutPreviewFrames() then return end

    for _, entry in ipairs(dressed) do
        PositionPreviewFrame(entry.unit, entry.frame, previewState[entry.frame])
    end
end

local function StopPreview()
    for frame in pairs(previewState) do
        RestoreFrame(frame)
    end
end

--------------------------------------------------------------------------------
-- Update
--------------------------------------------------------------------------------

-- Returns the role and where it came from. The source matters: anything other
-- than an assigned role is a guess from the specialization, and a guess has to be
-- watched, because the moment the group assigns roles the real thing takes over.
local function ResolveRole(unit)
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if VALID_ROLES[role] then return role, "assigned" end

    if not db.useSpec then return nil end

    if UnitIsUnit(unit, "player") then
        if USE_TALENT_TREES then
            return TalentTreeRole("player", false), "spec"
        end
        return PlayerSpecRole(), "spec"
    end

    local guid = UnitGUID(unit)
    if not guid then return nil end

    local cached = specRoleCache[guid]
    if cached then return cached, "spec" end

    local _, class = UnitClass(unit)
    if class and PURE_DAMAGE[class] then
        specRoleCache[guid] = "DAMAGER"
        return "DAMAGER", "class"
    end

    RequestInspect(unit, guid)
    return nil
end

local Update

-- Three self-cancelling timers, each for a different kind of "not settled yet":
--   settle    - the data behind an event often lands just after the event
--   retry     - an inspect is still pending
--   roleWatch - a displayed role is a guess, so keep an eye out for the real one
local RETRY_DELAY = 2
local SETTLE_DELAY = 0.5
local ROLE_WATCH_DELAY = 5

local needsRoleWatch = false
local retryScheduled, settleScheduled, roleWatchScheduled = false, false, false

local function ScheduleRetry()
    if retryScheduled then return end
    retryScheduled = true
    C_Timer.After(RETRY_DELAY, function()
        retryScheduled = false
        Update()
    end)
end

local function ScheduleSettle()
    if settleScheduled then return end
    settleScheduled = true
    C_Timer.After(SETTLE_DELAY, function()
        settleScheduled = false
        Update()
    end)
end

local function ScheduleRoleWatch()
    if roleWatchScheduled then return end
    roleWatchScheduled = true
    C_Timer.After(ROLE_WATCH_DELAY, function()
        roleWatchScheduled = false
        Update()
    end)
end

local function UpdateUnit(unit)
    local frame = ResolveFrame(unit)
    if not frame then return end

    local role, source
    if db.enabled then
        if unit == "player" then
            if db.showPlayer and (IsInGroup() or previewActive) then
                -- In the preview a character with no specialization yet still
                -- deserves an icon to line up.
                role, source = ResolveRole("player")
                role = role or (previewActive and "DAMAGER" or nil)
            end
        elseif UnitExists(unit) and IsInGroup() and frame:IsShown() then
            role, source = ResolveRole(unit)
        elseif previewActive then
            role = PREVIEW_ROLES[unit]
        end
    end

    -- A guessed role is provisional: keep looking until the group assigns one.
    if source and source ~= "assigned" then
        needsRoleWatch = true
    end

    if not role then
        local existing = icons[frame]
        if existing then existing:Hide() end
        return
    end

    local icon = EnsureIcon(frame)
    ApplyRoleArt(icon.texture, role)
    icon:Show()

    if db.hideBlizzard then
        local native = ResolveNativeRoleIcon(frame)
        if native and native.Hide then
            native:Hide()
        end
    end
end

function Update()
    if not db then return end

    RefreshPreview()

    needsRetry, needsRoleWatch = false, false
    for i = 1, #UNITS do
        UpdateUnit(UNITS[i])
    end

    -- Only re-arm while something is still unresolved, so the timers stop on their
    -- own once every role is known or the group is gone.
    if db.enabled and IsInGroup() then
        if needsRetry then ScheduleRetry() end
        if needsRoleWatch then ScheduleRoleWatch() end
    end
end

local function Relayout()
    for _, icon in pairs(icons) do
        ApplyLayout(icon)
    end
    Update()
end

ns.Update = Update
ns.Relayout = Relayout

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local hooked = false

local function InstallHooks()
    if hooked then return end
    hooked = true

    -- Legacy layout only: the modern frames drive this through mixins, and the
    -- roster events below already cover them.
    if _G["PartyMemberFrame_UpdateAssignedRoles"] then
        hooksecurefunc("PartyMemberFrame_UpdateAssignedRoles", function()
            Update()
        end)
    end
    if _G["PartyMemberFrame_UpdateMember"] then
        hooksecurefunc("PartyMemberFrame_UpdateMember", function()
            Update()
        end)
    end
end

local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED",
    "ROLE_CHANGED_INFORM",
    "PARTY_LEADER_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    -- Classic Era has neither of the two above; this is how it says the player
    -- spent a talent point.
    "CHARACTER_POINTS_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "UNIT_CONNECTION",
    "PLAYER_REGEN_ENABLED",
    "INSPECT_READY",
    -- What actually assigns the roles in a queued group is the dungeon finder
    -- role check, and it does not reliably come with PLAYER_ROLES_ASSIGNED.
    "LFG_ROLE_CHECK_ROLE_CHOSEN",
    "LFG_ROLE_CHECK_UPDATE",
    "LFG_ROLE_CHECK_HIDE",
    "LFG_ROLE_UPDATE",
    "LFG_UPDATE",
}

local events = CreateFrame("Frame")
local unsupportedEvents = {}

for i = 1, #EVENTS do
    -- Registering an event this client does not know is an error, so never let
    -- one missing name take the whole addon down.
    if not pcall(events.RegisterEvent, events, EVENTS[i]) then
        unsupportedEvents[#unsupportedEvents + 1] = EVENTS[i]
    end
end

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        InitDB()
        -- Register the options panel now, so it is in the game's options whether
        -- or not the player ever types the slash command.
        if ns.InitOptions then
            ns.InitOptions()
        end
        Say(ADDON_NAME .. " " .. L["LOADED"])
        return
    end

    if not db then return end

    if event == "INSPECT_READY" then
        if inspectPending == arg1 then
            inspectPending = nil
        end
        local unit = UnitForGUID(arg1)
        if unit then
            local role
            if USE_TALENT_TREES then
                role = TalentTreeRole(unit, true)
            elseif GetInspectSpecialization then
                role = RoleFromSpecID(GetInspectSpecialization(unit))
            end
            if role then
                specRoleCache[arg1] = role
            end
        end
        -- Deliberately no ClearInspectPlayer here: the inspect data belongs to
        -- whoever asked for it, and clearing it empties the player's own inspect
        -- window when it lands on the same event.
        Update()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 and UnitExists(arg1) then
        local guid = UnitGUID(arg1)
        if guid then
            specRoleCache[guid] = nil
        end
    end

    if event == "PLAYER_ENTERING_WORLD" then
        InstallHooks()
    end

    Update()

    -- The roster and role data behind an event regularly lands a moment after the
    -- event itself, so always take a second look.
    ScheduleSettle()
end)

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

-- Returns true when the preview actually changed state, so the options panel can
-- put its checkbox back when combat refuses the switch.
local function SetPreview(enabled, quiet)
    enabled = not not enabled
    if enabled == previewActive then return true end

    -- Showing or hiding a unit frame is a protected action while the player is in
    -- combat, so the preview only ever flips out of combat.
    if InCombatLockdown() then
        Say(L["TEST_COMBAT"])
        return false
    end

    previewActive = enabled

    if enabled then
        if not quiet then
            Say(L["TEST_ON"])
            Say(L["TEST_HINT"])
        end
        if not ResolveFrame("party1") then
            Say(L["TEST_NO_FRAME"])
        end
        local compact = _G["CompactPartyFrame"]
        if compact and compact:IsShown() then
            Say(L["TEST_RAID_STYLE"])
        end
    else
        StopPreview()
        if not quiet then
            Say(L["TEST_OFF"])
        end
    end

    Update()
    return true
end

local function TogglePreview()
    SetPreview(not previewActive)
end

ns.SetPreview = SetPreview
ns.IsPreview = function() return previewActive end

local function PrintStatus()
    Say(L["STATUS"],
        db.enabled and L["ON"] or L["OFF"],
        db.showPlayer and L["ON"] or L["OFF"],
        db.useSpec and L["ON"] or L["OFF"],
        db.size, db.anchor, db.x, db.y,
        previewActive and L["ON"] or L["OFF"])
end

local function PrintHelp()
    Say(ADDON_NAME .. " " .. L["HELP_HEADER"])
    print(L["HELP_CONFIG"])
    print(L["HELP_TOGGLE"])
    print(L["HELP_PLAYER"])
    print(L["HELP_SPEC"])
    print(L["HELP_SIZE"])
    print(L["HELP_OFFSET"])
    print(L["HELP_ANCHOR"])
    print(L["HELP_BLIZZARD"])
    print(L["HELP_TEST"])
    print(L["HELP_RESET"])
    print(L["HELP_DEBUG"])
end

local function PrintDebug()
    Say(ADDON_NAME .. " " .. L["DEBUG_HEADER"])
    print(("client %s | group %d | preview %s | size %d anchor %s %d,%d"):format(
        tostring(select(4, GetBuildInfo())),
        GetNumGroupMembers and GetNumGroupMembers() or -1,
        tostring(previewActive),
        db.size, db.anchor, db.x, db.y))

    local container = _G["PartyFrame"]
    print(("frames: PartyFrame=%s pool=%s legacy=%s compact=%s"):format(
        container and "yes" or "no",
        (container and container.PartyMemberFramePool) and "yes" or "no",
        _G["PartyMemberFrame1"] and "yes" or "no",
        (_G["CompactPartyFrame"] and _G["CompactPartyFrame"]:IsShown()) and "shown" or "no"))

    local compact = _G["CompactPartyFrame"]
    if compact and compact:IsShown() then
        print(L["DEBUG_RAID_STYLE"])
    end

    for i = 1, #UNITS do
        local unit = UNITS[i]
        local frame, source = ResolveFrame(unit)
        if not frame then
            print(("%s: no frame (%s)"):format(unit, tostring(source)))
        else
            local guid = UnitExists(unit) and UnitGUID(unit) or nil
            local portrait = ResolvePortrait(frame)
            local icon = icons[frame]
            local _, class = UnitClass(unit)
            print(("%s via %s: exists=%s shown=%s visible=%s name=%s class=%s"):format(
                unit, source,
                tostring(UnitExists(unit)),
                tostring(frame:IsShown()),
                tostring(frame.IsVisible and frame:IsVisible()),
                tostring(UnitName(unit)),
                tostring(class)))
            print(("   role: assigned=%s cached=%s | portrait=%s | icon=%s native=%s"):format(
                tostring(UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)),
                tostring(guid and specRoleCache[guid] or nil),
                portrait == frame and "FRAME FALLBACK" or "ok",
                icon and (icon:IsShown() and "shown" or "hidden") or "none",
                ResolveNativeRoleIcon(frame) and "yes" or "no"))
            if unit ~= "player" and UnitExists(unit) then
                print(("   inspect: connected=%s visible=%s canInspect=%s"):format(
                    tostring(UnitIsConnected(unit)),
                    tostring(UnitIsVisible(unit)),
                    tostring(CanInspect(unit, false))))
            end
        end
    end

    print(("events: %d registered, unsupported: %s"):format(
        #EVENTS - #unsupportedEvents,
        #unsupportedEvents > 0 and table.concat(unsupportedEvents, ", ") or "none"))
    if USE_TALENT_TREES then
        local ok, tab, points = pcall(DominantTree, false)
        print(("roles: from talent trees | own dominant tree=%s points=%s"):format(
            ok and tostring(tab) or "error", ok and tostring(points) or "-"))
    else
        print(("roles: from specializations | GetInspectSpecialization=%s"):format(
            tostring(GetInspectSpecialization ~= nil)))
    end
end

SLASH_PARTYROLEICONS1 = "/pri"
SLASH_PARTYROLEICONS2 = "/partyroleicons"

SlashCmdList["PARTYROLEICONS"] = function(input)
    if not db then InitDB() end

    local command, value = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()
    value = value or ""

    if command == "on" then
        db.enabled = true
        Say(L["ENABLED"])
        Update()
    elseif command == "off" then
        db.enabled = false
        Say(L["DISABLED"])
        Update()
    elseif command == "player" then
        db.showPlayer = not db.showPlayer
        Say(db.showPlayer and L["PLAYER_ON"] or L["PLAYER_OFF"])
        Update()
    elseif command == "spec" then
        db.useSpec = not db.useSpec
        Say(db.useSpec and L["SPEC_ON"] or L["SPEC_OFF"])
        Update()
    elseif command == "blizzard" then
        db.hideBlizzard = not db.hideBlizzard
        Say(db.hideBlizzard and L["BLIZZARD_ON"] or L["BLIZZARD_OFF"])
        Update()
    elseif command == "size" then
        local size = tonumber(value)
        if not size or size < 8 or size > 40 then
            Say(L["BAD_VALUE"], value)
        else
            db.size = math.floor(size)
            Say(L["SIZE_SET"], db.size)
            Relayout()
        end
    elseif command == "x" or command == "y" then
        local offset = tonumber(value)
        if not offset or offset < -100 or offset > 100 then
            Say(L["BAD_VALUE"], value)
        else
            db[command] = math.floor(offset)
            Say(L["OFFSET_SET"], db.x, db.y)
            Relayout()
        end
    elseif command == "anchor" then
        local anchor = value:upper():gsub("%s", "")
        if not VALID_ANCHORS[anchor] then
            Say(L["BAD_VALUE"], value)
        else
            db.anchor = anchor
            Say(L["ANCHOR_SET"], db.anchor)
            Relayout()
        end
    elseif command == "test" or command == "preview" then
        TogglePreview()
    elseif command == "reset" then
        for key, default in pairs(DEFAULTS) do
            db[key] = default
        end
        Say(L["RESET"])
        Relayout()
    elseif command == "debug" then
        PrintDebug()
    elseif command == "config" or command == "options" then
        if ns.OpenOptions then ns.OpenOptions() else PrintStatus() end
    elseif command == "" and ns.OpenOptions then
        ns.OpenOptions()
    else
        PrintStatus()
        PrintHelp()
    end

    -- Keep the options panel in step when a setting is changed from chat.
    if ns.RefreshOptions then
        ns.RefreshOptions()
    end
end
