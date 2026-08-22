// Runs tests/harness.lua against addon/PartyRoleIcons/PartyRoleIcons.lua inside a
// real Lua VM (fengari), with a mock WoW client. Usage:
//   npm install
//   node tests/run.js                  # modern frames, enUS
//   node tests/run.js legacy           # legacy PartyMemberFrameN globals
//   node tests/run.js pool frFR        # frame pool only, French strings
//   node tests/run.js legacy enUS talents vanilla   # Classic Era role engine
//   node tests/run.js modern enUS noatlas   # client without the crisp flat atlas
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const root = path.join(__dirname, '..');
const addonSource = fs.readFileSync(
    path.join(root, 'addon', 'PartyRoleIcons', 'PartyRoleIcons.lua'), 'utf8');
const optionsSource = fs.readFileSync(
    path.join(root, 'addon', 'PartyRoleIcons', 'Options.lua'), 'utf8');
const harnessSource = fs.readFileSync(path.join(__dirname, 'harness.lua'), 'utf8');

const structure = process.argv[2] || 'modern';
const locale = process.argv[3];
const engine = process.argv[4];
const talentLayout = process.argv[5];
const atlas = process.argv[4];

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const setGlobal = (name, value) => {
    lua.lua_pushstring(L, to_luastring(value));
    lua.lua_setglobal(L, to_luastring(name));
};

setGlobal('ADDON_SOURCE', addonSource);
setGlobal('OPTIONS_SOURCE', optionsSource);
setGlobal('FRAME_STRUCTURE', structure);
if (locale) setGlobal('LOCALE_UNDER_TEST', locale);
if (engine) setGlobal('ROLE_ENGINE', engine);
if (talentLayout) setGlobal('TALENT_LAYOUT', talentLayout);
if (atlas) setGlobal('ATLAS_AVAILABLE', atlas);

if (lauxlib.luaL_dostring(L, to_luastring(harnessSource)) !== lua.LUA_OK) {
    console.error('lua error: ' + lua.lua_tojsstring(L, -1));
    process.exit(1);
}

lua.lua_getglobal(L, to_luastring('TEST_FAILURES'));
process.exit(lua.lua_tointeger(L, -1) === 0 ? 0 : 1);
