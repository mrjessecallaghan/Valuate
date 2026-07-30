#!/usr/bin/env node
/*
 * Undefined-global checker.
 *
 * Catches the worst bug class in this codebase: an identifier that resolves to a nil
 * GLOBAL instead of the local you meant. Lua raises no error for it - the code just
 * silently does nothing, or reads nil forever. Three real instances this session:
 *
 *   - ShowTooltipSafe read IsDraggingFrame declared 12 lines BELOW it, so the drag
 *     check never suppressed anything.
 *   - PassLoot referenced `ItemLink` (capital I) which does not exist in that scope,
 *     silently skipping the new code path.
 *   - Moving code between files can leave a reference to a local that no longer exists.
 *
 * A syntax checker cannot see any of these. Scope analysis can.
 *
 * Method: walk each file's AST tracking lexical scopes (locals, params, loop vars,
 * function names). Any identifier READ that isn't in scope is a global read; report it
 * unless it is a known WoW/Lua API or something the addon itself defines globally.
 *
 * Usage:  node tools/globals.js
 * Exits non-zero if an unknown global is read.
 */
"use strict";

const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");
const ADDONS_DIR = path.resolve(ADDON_ROOT, "..");

const SCAN = [
  ADDON_ROOT,
  path.join(ADDONS_DIR, "Valuate-AdiBags"),
  path.join(ADDONS_DIR, "Valuate-PassLoot"),
  path.join(ADDONS_DIR, "Valuate-TSM"),
];
const SKIP = /(^|[\\/])(libs|node_modules|\.git|_Valuate_Original_Archive.*|_Valuate_Handoff|tools)([\\/]|$)/i;

// Lua base library + WoW 3.3.5 API surface this addon legitimately uses.
const KNOWN = new Set((`
_G _ENV assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile
loadstring next pairs pcall print rawequal rawget rawlen rawset select setfenv
setmetatable tonumber tostring type unpack xpcall coroutine debug io math os string
table bit require module arg
CreateFrame UIParent GameTooltip GameTooltipTextLeft1 ItemRefTooltip UISpecialFrames
GetItemInfo GetItemInfoInstant GetItemQualityColor GetItemFamily GetItemCount
GetContainerNumSlots GetContainerItemLink GetContainerItemInfo GetContainerItemID
GetContainerNumFreeSlots GetContainerItemQuestInfo GetContainerItemEquipmentSetInfo
PickupContainerItem DeleteCursorItem UseContainerItem SplitContainerItem
CursorHasItem ClearCursor GetCursorInfo
GetInventoryItemLink GetInventoryItemTexture GetInventoryItemID GetInventorySlotInfo
EquipItemByName EquipPendingItem PickupInventoryItem UseInventoryItem
GetNumEquipmentSets GetEquipmentSetInfo SaveEquipmentSet DeleteEquipmentSet
UseEquipmentSet GetEquipmentSetLocations EquipmentManager_UnpackLocation
CanMerchantRepair GetRepairAllCost RepairAllItems CanGuildBankRepair GetMoney
MerchantFrame GetMerchantNumItems GetBuybackItemInfo
GetNumQuestChoices GetQuestItemLink GetQuestItemInfo GetQuestReward CompleteQuest
IsQuestCompletable AcceptQuest ConfirmAcceptQuest GetTitleText GetNumAvailableQuests
SelectAvailableQuest GetNumGossipAvailableQuests SelectGossipAvailableQuest
GetGossipAvailableQuests GetAvailableLevel GetAvailableTitle
QuestInfoFrame QuestInfoItem_OnClick QuestFrame
GetLootRollItemInfo GetLootRollItemLink RollOnLoot ConfirmLootRoll ConfirmLootSlot
ConfirmBindOnUse GetNumLootItems LootSlot
UnitClass UnitLevel UnitName UnitIsDeadOrGhost UnitStat GetRealmName
InCombatLockdown IsSpellKnown CanDualWield IsDualWielding
GetMacroIconInfo GetNumMacroIcons GetMacroItemIconInfo GetNumMacroItemIcons
GetCoinTextureString GetTime SecondsToTime ReloadUI IsAddOnLoaded GetAddOnMetadata
PlaySound PlaySoundFile
hooksecurefunc issecurevariable securecall
StaticPopupDialogs StaticPopup_Show StaticPopup_Hide StaticPopup1
CharacterFrame CharacterModelFrame PaperDollFrame
LibStub SlashCmdList SLASH_VALUATE1 SLASH_VALUATE2
Minimap Minimap_ZoomIn GetMinimapShape
ITEM_QUALITY_POOR ITEM_QUALITY_COMMON ITEM_QUALITY_UNCOMMON ITEM_QUALITY_RARE
ITEM_QUALITY_EPIC OKAY YES NO CANCEL ACCEPT CLOSE
strtrim strsplit strjoin strlower strupper strsub strlen strfind strmatch strrep
tinsert tremove twipe wipe format gsub gmatch max min abs floor ceil
date time difftime random
C_Timer C_Item C_Container
Valuate ValuateOptions ValuateScales ValuateBestEquipment
ValuateStatPatterns ValuateStatNames ValuateStatCategories ValuateEquipmentCategories
ValuateWeaponSlotPatterns ValuateWeaponTypePatterns ValuateUIFrame
PassLoot Scrap BrainDead AdiBags TSM_API TSMAPI
GetNumAuctionItems GetAuctionItemLink GetAuctionItemInfo GetAuctionItemClasses
AuctionFrame OTHER ARMOR WEAPON
NORMAL_FONT_COLOR HIGHLIGHT_FONT_COLOR RED_FONT_COLOR GREEN_FONT_COLOR
DEFAULT_CHAT_FRAME ChatFrame1 UIErrorsFrame
GameFontNormal GameFontHighlight GameFontHighlightSmall GameFontHighlightLarge
GameFontNormalSmall GameFontDisable ChatFontNormal
UIDropDownMenu_SetWidth UIDropDownMenu_SetText UIDropDownMenu_AddButton
UIDropDownMenu_CreateInfo UIDropDownMenu_Initialize UIDropDownMenu_StopCounting
UIDROPDOWNMENU_MENU_VALUE CloseDropDownMenus CloseMenus DropDownList3 DropDownList3Button1
ColorPickerFrame GetCursorPosition getglobal
ShoppingTooltip1 ShoppingTooltip2 ComparisonTooltip1 ComparisonTooltip2
IsShiftKeyDown IsControlKeyDown IsAltKeyDown
GetBindingKey GetBindingAction SetBinding SaveBindings GetCurrentBindingSet
AscensionCharacterFrame AscensionPaperDollPanel AscensionPaperDollPanelModel
`).trim().split(/\s+/));

function collectFiles(root, out) {
  let entries;
  try { entries = fs.readdirSync(root, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const full = path.join(root, e.name);
    if (SKIP.test(full)) continue;
    if (e.isDirectory()) collectFiles(full, out);
    else if (e.isFile() && e.name.endsWith(".lua")) out.push(full);
  }
}

const files = [];
for (const r of SCAN) collectFiles(r, files);
files.sort();

// Pass 1: every global the addon ASSIGNS is legitimate (functions, config tables).
const addonGlobals = new Set();
const asts = new Map();

for (const f of files) {
  let ast;
  try {
    ast = luaparse.parse(fs.readFileSync(f, "utf8"), {
      luaVersion: "5.1", locations: true, scope: false,
    });
  } catch { continue; } // check.js reports syntax errors
  asts.set(f, ast);

  (function findAssignedGlobals(node) {
    if (!node || typeof node !== "object") return;
    if (node.type === "AssignmentStatement") {
      for (const t of node.variables || []) {
        if (t.type === "Identifier") addonGlobals.add(t.name);
      }
    }
    if (node.type === "FunctionDeclaration" && node.identifier &&
        node.identifier.type === "Identifier" && !node.isLocal) {
      addonGlobals.add(node.identifier.name);
    }
    for (const k of Object.keys(node)) {
      const v = node[k];
      if (Array.isArray(v)) v.forEach(findAssignedGlobals);
      else if (v && typeof v === "object") findAssignedGlobals(v);
    }
  })(ast);
}

// Pass 2: scope-walk each file and flag reads that resolve to an unknown global.
let problems = 0;

for (const [file, ast] of asts) {
  const rel = path.relative(ADDONS_DIR, file);
  const reported = new Set();
  const scopes = [new Set()];

  const declare = (name) => scopes[scopes.length - 1].add(name);
  const inScope = (name) => scopes.some((s) => s.has(name));

  function walk(node, parent) {
    if (!node || typeof node !== "object") return;

    switch (node.type) {
      case "LocalStatement":
        (node.init || []).forEach((n) => walk(n, node));
        (node.variables || []).forEach((v) => declare(v.name));
        return;

      case "FunctionDeclaration": {
        if (node.identifier) {
          if (node.isLocal && node.identifier.type === "Identifier") {
            declare(node.identifier.name);
          } else {
            walk(node.identifier, node); // e.g. Valuate:Foo -> reads Valuate
          }
        }
        scopes.push(new Set(["self", "..."]));
        (node.parameters || []).forEach((p) => {
          if (p.type === "Identifier") declare(p.name);
        });
        (node.body || []).forEach((n) => walk(n, node));
        scopes.pop();
        return;
      }

      case "ForNumericStatement":
        walk(node.start, node); walk(node.end, node); walk(node.step, node);
        scopes.push(new Set());
        if (node.variable) declare(node.variable.name);
        (node.body || []).forEach((n) => walk(n, node));
        scopes.pop();
        return;

      case "ForGenericStatement":
        (node.iterators || []).forEach((n) => walk(n, node));
        scopes.push(new Set());
        (node.variables || []).forEach((v) => declare(v.name));
        (node.body || []).forEach((n) => walk(n, node));
        scopes.pop();
        return;

      case "DoStatement":
      case "WhileStatement":
      case "RepeatStatement":
      case "IfClause":
      case "ElseifClause":
      case "ElseClause":
        scopes.push(new Set());
        for (const k of ["condition", "body", "clauses"]) {
          const v = node[k];
          if (Array.isArray(v)) v.forEach((n) => walk(n, node));
          else if (v) walk(v, node);
        }
        scopes.pop();
        return;

      case "MemberExpression":
        walk(node.base, node);   // only the base is a variable read; .field is not
        return;

      case "TableKeyString":
        // `{ desc = "x" }` - the key is a field name, not a variable read.
        walk(node.value, node);
        return;

      case "TableKey":
        // `{ [expr] = v }` - here the key IS an expression, so walk both.
        walk(node.key, node);
        walk(node.value, node);
        return;

      case "Identifier":
        // A bare identifier read that is not local and not known = suspicious.
        if (!inScope(node.name) && !KNOWN.has(node.name) && !addonGlobals.has(node.name)) {
          const line = node.loc ? node.loc.start.line : 0;
          const key = node.name + ":" + line;
          if (!reported.has(key)) {
            reported.add(key);
            console.error(
              "  " + rel + ":" + line + "  reads undefined global '" + node.name +
              "' - did you mean a local, or is this a moved/renamed symbol?"
            );
            problems++;
          }
        }
        return;
    }

    for (const k of Object.keys(node)) {
      if (k === "loc") continue;
      const v = node[k];
      if (Array.isArray(v)) v.forEach((n) => walk(n, node));
      else if (v && typeof v === "object") walk(v, node);
    }
  }

  (ast.body || []).forEach((n) => walk(n, ast));
}

/*
 * Pass 3: the namespace contract.
 *
 * `local Foo = ns.Foo` when nothing ever assigns ns.Foo yields nil - silently, exactly
 * like the global case above, but invisible to scope analysis because `ns.Foo` is a
 * member expression rather than a bare identifier. Since the whole UI split is built on
 * publish-then-re-localise, a typo or a forgotten `ns.X = X` line breaks a module with
 * no error at all. So: every ns.<name> that is READ must be assigned somewhere.
 */
const nsAssigned = new Set();
const nsRead = [];

for (const file of asts.keys()) {
  const src = fs.readFileSync(file, "utf8");
  const rel = path.relative(ADDONS_DIR, file);
  src.split(/\r?\n/).forEach((line, i) => {
    const code = line.replace(/--.*$/, "");
    // Assignment: `ns.Foo = ...` (but not `==`)
    let m;
    const assignRe = /\bns\.(\w+)\s*=(?!=)/g;
    while ((m = assignRe.exec(code))) nsAssigned.add(m[1]);
    // `function ns.Foo(...)` is the same assignment written the other way round.
    const declRe = /\bfunction\s+ns\.(\w+)\s*\(/g;
    while ((m = declRe.exec(code))) nsAssigned.add(m[1]);
    // Read: any other ns.Foo occurrence
    const readRe = /\bns\.(\w+)/g;
    while ((m = readRe.exec(code))) {
      const after = code.slice(m.index + m[0].length);
      if (/^\s*=(?!=)/.test(after)) continue; // that's the assignment itself
      nsRead.push({ name: m[1], file: rel, line: i + 1 });
    }
  });
}

const nsProblems = [];
for (const r of nsRead) {
  if (!nsAssigned.has(r.name)) nsProblems.push(r);
}
for (const r of nsProblems) {
  console.error(
    "  " + r.file + ":" + r.line + "  reads ns." + r.name +
    " which is never assigned - it will be nil. Publish it (ns." + r.name +
    " = ...) in the module that defines it, and load that module first in the .toc."
  );
}

if (problems > 0 || nsProblems.length > 0) {
  if (problems) console.error("\n" + problems + " undefined global read(s).");
  if (nsProblems.length) console.error(nsProblems.length + " unpublished ns.* read(s).");
  process.exit(1);
}
console.log(
  "OK  no undefined globals across " + asts.size + " file(s); " +
  nsAssigned.size + " ns.* symbols all published before use."
);
