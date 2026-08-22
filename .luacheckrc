-- Luacheck config for WoW MoP Classic addon Lua (Lua 5.1 runtime).
std = "lua51"
max_line_length = false   -- localization tables have long string lines
unused_args = false       -- WoW callbacks pass self/event args we often ignore

read_globals = {
    -- Frames and general API
    "CreateFrame", "UIParent", "hooksecurefunc", "C_Timer", "GetTime",
    "GetLocale", "GetBuildInfo", "InCombatLockdown", "ReloadUI",
    "strtrim", "select",
    -- table.unpack only exists on 5.2+, kept as a fallback for the test VM
    table = { fields = { "insert", "remove", "concat", "sort", "unpack" } },

    -- Group and role API
    "IsInGroup", "GetNumGroupMembers", "UnitExists", "UnitIsUnit", "UnitGUID",
    "UnitClass", "UnitName", "UnitIsConnected", "UnitIsVisible",
    "UnitGroupRolesAssigned",

    -- Specialization and inspect API
    "GetSpecialization", "GetSpecializationRole", "GetSpecializationInfo",
    "GetSpecializationRoleByID", "GetInspectSpecialization",
    "NotifyInspect", "CanInspect",

    -- Talent API, Classic Era's only route to a role
    "GetNumTalentTabs", "GetTalentTabInfo",

    -- Blizzard frames we attach to or look at
    "PlayerFrame", "InspectFrame",

    -- Options panel
    "UIParent", "GameTooltip", "Settings", "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame_OpenToCategory", "BACKDROP_TUTORIAL_16_16", "SettingsPanel",
}

globals = {
    -- SavedVariable and slash handlers (globals WoW reads/writes)
    "PartyRoleIconsDB", "SLASH_PARTYROLEICONS1", "SLASH_PARTYROLEICONS2", "SlashCmdList",
}
