-- Valuate - Stat Weight Calculator for WoW Ascension Bronzebeard
-- Interface: 30300 (WotLK 3.3.5a)

-- Addon namespace
Valuate = {}

-- The addon's private table, shared by every file in this addon. The ui/ modules
-- publish onto it and re-localise from it. This file loads FIRST, so `ns` is empty
-- here at load time - only read it at runtime (see the ui-module check in
-- Valuate:RunSelfTest), never during this file's own execution.
local _, ns = ...
ns = ns or {}

-- Version info (read from .toc file automatically)
Valuate.version = GetAddOnMetadata("Valuate", "Version") or "Unknown"
Valuate.interface = 30300

-- Keybinding function that WoW calls when the key is pressed
-- This is registered in Bindings.xml and must be defined early
function ValuateToggleUI()
    if Valuate and Valuate.ToggleUI then
        Valuate:ToggleUI()
    else
        print("|cFFFF0000Valuate|r: UI not ready. Please try again or /reload.")
    end
end

-- Equipment slot to inventory slot mapping (for upgrade comparison)
local EquipSlotToInvNumber = {
    ["INVTYPE_AMMO"] = { 0 },
    ["INVTYPE_HEAD"] = { 1 },
    ["INVTYPE_NECK"] = { 2 },
    ["INVTYPE_SHOULDER"] = { 3 },
    ["INVTYPE_BODY"] = { 4 },
    ["INVTYPE_CHEST"] = { 5 },
    ["INVTYPE_ROBE"] = { 5 },
    ["INVTYPE_WAIST"] = { 6 },
    ["INVTYPE_LEGS"] = { 7 },
    ["INVTYPE_FEET"] = { 8 },
    ["INVTYPE_WRIST"] = { 9 },
    ["INVTYPE_HAND"] = { 10 },
    ["INVTYPE_FINGER"] = { 11, 12 },
    ["INVTYPE_TRINKET"] = { 13, 14 },
    ["INVTYPE_CLOAK"] = { 15 },
    ["INVTYPE_WEAPON"] = { 16, 17 },
    ["INVTYPE_SHIELD"] = { 17 },
    ["INVTYPE_2HWEAPON"] = { 16 },
    ["INVTYPE_WEAPONMAINHAND"] = { 16 },
    ["INVTYPE_WEAPONOFFHAND"] = { 17 },
    ["INVTYPE_HOLDABLE"] = { 17 },
    ["INVTYPE_RANGED"] = { 18 },
    ["INVTYPE_THROWN"] = { 18 },
    ["INVTYPE_RANGEDRIGHT"] = { 18 },
    ["INVTYPE_RELIC"] = { 18 },
}

-- Slot ID to friendly name mapping
local SlotIdToName = {
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [16] = "Main Hand",
    [17] = "Off Hand",
}

-- Weapon configuration ("set") definitions, in display order. Each scale can
-- enable/disable these independently and pick one as its "active" set; the active
-- set resolves into the Main Hand (16) / Off Hand (17) best-in-slot entries.
local WEAPON_SET_DEFS = {
    { key = "TwoHand",        label = "Two-Hander",   short = "2H" },
    { key = "OneHandShield",  label = "1H + Shield",  short = "1H+Sh" },
    { key = "OneHandOffhand", label = "1H + Off-Hand", short = "1H+OH" },
    { key = "DualWield",      label = "Dual Wield",   short = "DW" },
}

-- Helper function to check if two weapon types are comparable
local function AreWeaponTypesComparable(hoverType, equippedType)
    -- Handle nil or empty strings
    if not hoverType or hoverType == "" or not equippedType or equippedType == "" then
        return false
    end
    
    -- Shields never compare to weapons
    if (hoverType == "INVTYPE_SHIELD" or hoverType == "INVTYPE_HOLDABLE") then
        return (equippedType == "INVTYPE_SHIELD" or equippedType == "INVTYPE_HOLDABLE")
    end
    if (equippedType == "INVTYPE_SHIELD" or equippedType == "INVTYPE_HOLDABLE") then
        return false
    end
    
    -- 2H weapons only compare to other 2H weapons
    if hoverType == "INVTYPE_2HWEAPON" then
        return equippedType == "INVTYPE_2HWEAPON"
    end
    if equippedType == "INVTYPE_2HWEAPON" then
        return false
    end
    
    -- Ranged weapons only compare to other ranged weapons
    if hoverType == "INVTYPE_RANGED" or hoverType == "INVTYPE_RANGEDRIGHT" or hoverType == "INVTYPE_THROWN" then
        return (equippedType == "INVTYPE_RANGED" or equippedType == "INVTYPE_RANGEDRIGHT" or equippedType == "INVTYPE_THROWN")
    end
    if equippedType == "INVTYPE_RANGED" or equippedType == "INVTYPE_RANGEDRIGHT" or equippedType == "INVTYPE_THROWN" then
        return false
    end
    
    -- 1H generic weapons (INVTYPE_WEAPON) compare to other 1H generic weapons, mainhand-only, and offhand-only
    if hoverType == "INVTYPE_WEAPON" then
        return equippedType == "INVTYPE_WEAPON" or equippedType == "INVTYPE_WEAPONMAINHAND" or equippedType == "INVTYPE_WEAPONOFFHAND"
    end
    if equippedType == "INVTYPE_WEAPON" then
        return hoverType == "INVTYPE_WEAPON" or hoverType == "INVTYPE_WEAPONMAINHAND" or hoverType == "INVTYPE_WEAPONOFFHAND"
    end
    
    -- Mainhand-only weapons compare to mainhand-only and 1H generic
    if hoverType == "INVTYPE_WEAPONMAINHAND" then
        return equippedType == "INVTYPE_WEAPONMAINHAND" or equippedType == "INVTYPE_WEAPON"
    end
    if equippedType == "INVTYPE_WEAPONMAINHAND" then
        return hoverType == "INVTYPE_WEAPONMAINHAND" or hoverType == "INVTYPE_WEAPON"
    end
    
    -- Offhand-only weapons compare to offhand-only and 1H generic
    if hoverType == "INVTYPE_WEAPONOFFHAND" then
        return equippedType == "INVTYPE_WEAPONOFFHAND" or equippedType == "INVTYPE_WEAPON"
    end
    if equippedType == "INVTYPE_WEAPONOFFHAND" then
        return hoverType == "INVTYPE_WEAPONOFFHAND" or hoverType == "INVTYPE_WEAPON"
    end
    
    -- For all other cases, types should match exactly
    return hoverType == equippedType
end

-- Frame for event handling
local frame = CreateFrame("Frame")

-- Auto-scan throttle
local lastAutoScanTime = 0

-- Scan responsiveness, per auto-scan mode.
--
-- Four separate delays stack up before a scan actually runs: the scheduled delay,
-- the bag-quiet window the callback waits for, the minimum gap between scans, and
-- the burst cap that stops a continuous stream of BAG_UPDATEs deferring forever.
-- With one conservative set of numbers, "always" behaved almost like the other
-- modes - a bag change took several seconds to show up, and during sustained
-- looting closer to six.
--
-- "always" is an explicit request to track your bags closely, so it gets much
-- tighter numbers. The other modes keep the cautious ones; they only scan on
-- discrete events where latency doesn't matter.
--
-- These do NOT relax the in-transit guards (equipmentSwapPending /
-- recentEquipmentChange). Those are what stop a scan reading a bag slot mid-move,
-- and they stay exactly as they were.
-- `equip` is deliberately longer than `delay` even in the fast profile. A bag
-- change is just contents moving; an equip/unequip moves an item BETWEEN a bag
-- slot and an equipment slot, which is the exact situation the in-transit guard
-- exists for - reading a bag slot mid-move is what used to make items vanish. So
-- it gets a real settle window, just not the original 3.5 seconds.
local SCAN_TIMING_ALWAYS  = { delay = 0.7, quiet = 0.4, throttle = 0.75, defer = 2.0, equip = 1.2 }
local SCAN_TIMING_DEFAULT = { delay = 2.5, quiet = 2.0, throttle = 2.0,  defer = 6.0, equip = 3.5 }

local function ScanTiming()
    local mode = Valuate.GetOptions and Valuate:GetOptions().autoScan
    if mode == "always" then return SCAN_TIMING_ALWAYS end
    return SCAN_TIMING_DEFAULT
end

-- Track if equipment swap is in progress
local equipmentSwapPending = false
local pendingScanTimer = nil
local bagUpdateCooldown = 0  -- Cooldown after bag updates to let items settle
local recentEquipmentChange = false  -- Track if we recently had equipment changes

-- Upgrade found during combat; the PLAYER_REGEN_ENABLED handler rechecks on leaving.
--
-- Declared HERE rather than with the rest of the bag-upgrade state further down,
-- because the event handler that READS it sits at the top of this file. As a local
-- declared below its reader it was a nil global there instead - so the deferred
-- prompt was set on leaving combat and then never seen, silently, for every upgrade
-- found in combat. Lua raises nothing for this; tools/globals.js now does.
local bagUpgradePending = false

-- ========================================
-- Cancelable one-shot timer (client-compat)
-- ========================================
-- Ascension / 3.3.5a clients ship C_Timer in several flavors:
--   * C_Timer.NewTimer(delay, cb) -> object with :Cancel()  (cancelable)
--   * C_Timer.After(delay, cb)    -> no return value, no C_Timer.Cancel
--   * neither present              -> older/limited clients
-- The auto-scan logic needs to be able to CANCEL a pending scan, so we wrap
-- all of these behind a single helper that always returns a handle exposing
-- :Cancel(). This makes scan-throttling actually work instead of silently
-- leaking overlapping scans (the previous code called C_Timer.Cancel on a
-- handle that C_Timer.After never returned).
-- Free list for the no-C_Timer fallback below. Only ever touched on clients that
-- lack C_Timer; this one has it (AdiBags uses it unguarded), so the pool normally
-- stays empty.
local timerFramePool = {}

local function ValuateAfter(delay, callback)
    if C_Timer and C_Timer.NewTimer then
        -- Native cancelable timer object.
        return C_Timer.NewTimer(delay, callback)
    elseif C_Timer and C_Timer.After then
        -- No native cancel: gate the callback behind a cancelled flag.
        local handle = { cancelled = false }
        function handle:Cancel() self.cancelled = true end
        C_Timer.After(delay, function()
            if not handle.cancelled then callback() end
        end)
        return handle
    else
        -- Pure OnUpdate fallback for clients lacking C_Timer entirely.
        --
        -- POOLED. WoW never frees frames, and this addon calls ValuateAfter
        -- constantly - scan scheduling, retries, the bank snapshot, the login
        -- passes - so allocating one per call would leak steadily on those clients.
        -- The pool keeps the count at the high-water mark of CONCURRENT timers,
        -- which is a handful, instead of the total ever scheduled.
        local timerFrame = tremove(timerFramePool)
        if not timerFrame then timerFrame = CreateFrame("Frame") end

        local handle = { cancelled = false, elapsed = 0, frame = timerFrame }
        local function release(self)
            -- valuate-lint-ignore: raw-onupdate-needs-reason  this IS the shared timer helper (ValuateAfter)
            self:SetScript("OnUpdate", nil)
            if handle.frame then
                handle.frame = nil
                tinsert(timerFramePool, self)
            end
        end

        function handle:Cancel()
            self.cancelled = true
            -- Cancelling returns the frame too; otherwise a cancelled timer's frame
            -- would be lost, which is the leak this pool exists to prevent - and
            -- ScheduleScan cancels far more timers than it lets finish.
            if self.frame then release(self.frame) end
        end

        -- valuate-lint-ignore: raw-onupdate-needs-reason  this IS the shared timer helper (ValuateAfter)
        timerFrame:SetScript("OnUpdate", function(self, e)
            handle.elapsed = handle.elapsed + (e or 0)
            if handle.elapsed >= delay then
                release(self)
                if not handle.cancelled then callback() end
            end
        end)
        return handle
    end
end

-- Published so the ui/ layer can actually use it.
--
-- CLAUDE.md §9 tells you delays belong on ValuateAfter rather than a raw OnUpdate - but
-- it was a file-local here, so nothing in ui/ could reach it and the advice was
-- impossible to follow. ui/CharacterWindow.lua consequently rolled its own timer three
-- times, each needing a lint annotation to explain why it was raw.
--
-- A rule that cannot be obeyed is not a rule, it is a trap for whoever reads it next.
--
-- Both branches return a handle with :Cancel(), so callers can treat the return
-- uniformly regardless of which C_Timer flavour this client shipped.
ns.ValuateAfter = ValuateAfter
Valuate.After = ValuateAfter

-- Schedule a scan with proper delays
local scanBurstStartedAt
-- Burst cap now comes from ScanTiming().defer, so "always" mode isn't held to the
-- conservative six seconds during sustained looting.
local function ScheduleScan(delay, reason, retries)
    delay = delay or 3.0  -- Default delay increased significantly to ensure items are in bags
    
    -- Check autoScan setting
    local options = Valuate:GetOptions()
    local autoScan = options.autoScan or "onEquipmentChange"
    
    -- Determine if we should scan based on reason and setting
    local shouldScan = false
    if reason == "login" then
        -- The login refresh runs in every mode except "off": the other modes choose
        -- WHEN to react to changes, whereas this is about not starting the session
        -- on stale data. "off" means no automatic scans at all, and that is honoured.
        shouldScan = (autoScan ~= "off")
    elseif autoScan == "always" then
        shouldScan = true
    elseif autoScan == "onEquipmentChange" and (reason == "equipment" or reason == "swap") then
        shouldScan = true
    elseif autoScan == "onLoot" and reason == "loot" then
        shouldScan = true
    elseif autoScan == "off" then
        shouldScan = false
    end
    
    if not shouldScan then
        return
    end
    
    -- Cap the debounce. A plain cancel-and-re-arm starves itself: BAG_UPDATE fires
    -- constantly while looting, and each one pushed the deadline back, so a scan
    -- requested mid-burst never ran.
    local timing = ScanTiming()
    local now = GetTime()
    if not pendingScanTimer then
        scanBurstStartedAt = now
    elseif scanBurstStartedAt and (now - scanBurstStartedAt) >= timing.defer then
        return  -- let the already-armed timer fire
    end

    if pendingScanTimer then
        pendingScanTimer:Cancel()
        pendingScanTimer = nil
    end
    -- Schedule new scan
    pendingScanTimer = ValuateAfter(delay, function()
        pendingScanTimer = nil
        scanBurstStartedAt = nil
        local currentTime = GetTime()

        -- A swap is in flight; EQUIPMENT_SWAP_FINISHED schedules the next scan.
        if equipmentSwapPending then return end

        if (currentTime - bagUpdateCooldown) < timing.quiet then
            -- Bags are still settling. This used to DROP the scan outright, so
            -- during continuous looting a scan requested mid-burst simply never
            -- happened - items sat in your bags unscanned. Retry instead, bounded
            -- so we can't re-arm forever (ValuateAfter's no-C_Timer fallback
            -- allocates a frame per call, and WoW never frees frames).
            retries = (retries or 0) + 1
            if retries <= 5 then
                ScheduleScan(2.0, reason, retries)
            end
            return
        end

        if currentTime - lastAutoScanTime >= timing.throttle then
            lastAutoScanTime = currentTime
            recentEquipmentChange = false
            if Valuate.ScanBestEquipment then
                Valuate:ScanBestEquipment()
            end
        end
    end)
end

-- ============================================================================
-- Automation heartbeat
-- ============================================================================
-- Purely diagnostic. Records when each automated path last ran and what it
-- concluded, so "is this even working?" has an answer that doesn't depend on
-- catching it in the act. Every silent-automation bug found so far - the starved
-- debounces, the dropped scans, the swallowed notify - looked identical from the
-- outside: nothing happening, no error, nothing to point at.
--
-- Session-scoped on purpose, and NOT saved: a timestamp from three days ago would
-- be more misleading than no timestamp at all.
local automationHeartbeat = {}

function Valuate:MarkAutomation(name, outcome)
    if not name then return end
    automationHeartbeat[name] = { at = GetTime(), outcome = outcome }
end

-- Returns secondsAgo, outcome - or nil if it has not run this session.
function Valuate:GetAutomationHeartbeat(name)
    local h = automationHeartbeat[name]
    if not h then return nil end
    return GetTime() - h.at, h.outcome
end

-- Debounced junk cleanup. Bags fill from every acquisition path, not just looting, so
-- this runs on any inventory addition. Debounced because ITEM_PUSH fires once per item.
--
-- The debounce is CAPPED, because a plain cancel-and-re-arm starves itself: every
-- ITEM_PUSH pushed the deadline back another second, so while you were looting
-- continuously - precisely when bags fill up - cleanup never actually ran. Once a
-- burst has been deferred MAX_CLEANUP_DEFER seconds we stop re-arming and let the
-- pending timer fire, so a long farming session still gets cleaned up mid-burst.
local pendingDeleteTimer
local deleteBurstStartedAt
local MAX_CLEANUP_DEFER = 5
local function ScheduleJunkCleanup(delay)
    if not Valuate.GetOptions or not Valuate:GetOptions().autoDeleteJunk then return end

    local now = GetTime()
    if not pendingDeleteTimer then
        deleteBurstStartedAt = now
    elseif deleteBurstStartedAt and (now - deleteBurstStartedAt) >= MAX_CLEANUP_DEFER then
        -- Burst is still going; leave the armed timer alone so it gets to fire.
        return
    end

    if pendingDeleteTimer and pendingDeleteTimer.Cancel then
        pendingDeleteTimer:Cancel()
    end
    pendingDeleteTimer = ValuateAfter(delay or 1.0, function()
        pendingDeleteTimer = nil
        deleteBurstStartedAt = nil
        if Valuate.AutoDeleteJunk then Valuate:AutoDeleteJunk() end
    end)
end

-- Periodic junk cleanup, backing up the event-driven triggers above.
--
-- Those only fire on loot and bag updates, which misses plenty of ways bags fill:
-- mail, trade, crafting, vendor buys, disenchanting, or simply an event arriving
-- while a scan guard was up. A slow ticker closes that gap.
--
-- Cheap by construction: AutoDeleteJunk returns immediately unless free slots are
-- below the keep-free target, so a tick with nothing to do costs one comparison.
--
-- ONE frame, created once and reused. ValuateAfter's no-C_Timer fallback creates a
-- frame per call and WoW never frees frames, so re-arming a timer every interval
-- would leak steadily on those clients.
local junkTicker = CreateFrame("Frame")
junkTicker.elapsed = 0
junkTicker.poll = 0
-- valuate-lint-ignore: raw-onupdate-needs-reason  dedicated periodic-cleanup driver frame
junkTicker:SetScript("OnUpdate", function(self, e)
    -- OnUpdate fires every frame (60+/sec), so the per-frame cost here is one add
    -- and one compare. The options lookup happens at most every POLL seconds; at a
    -- 60s cleanup interval that granularity is irrelevant.
    local POLL = 2
    self.poll = self.poll + (e or 0)
    if self.poll < POLL then return end
    self.elapsed = self.elapsed + self.poll
    self.poll = 0

    local options = Valuate.GetOptions and Valuate:GetOptions()
    local interval = options and tonumber(options.autoDeleteIntervalSecs) or 0
    if not options or not options.autoDeleteJunk or interval <= 0 then
        self.elapsed = 0
        return
    end
    if self.elapsed < interval then return end
    self.elapsed = 0
    -- Deliberately NOT gated on combat: bags filling up mid-fight is exactly when
    -- this matters, and deletion is not a protected action in 3.3.5.
    -- Safe to call unconditionally - AutoDeleteJunk returns silently unless free
    -- slots are already below the keep-free target.
    --
    -- Contained and reported once. This is the timer that DELETES things: an error
    -- part-way through would otherwise be silent (script errors are off by default)
    -- and repeat every interval, which is the last place that should happen quietly.
    if Valuate.AutoDeleteJunk then
        local ok, err = pcall(Valuate.AutoDeleteJunk, Valuate)
        if not ok then
            -- Through the shared reporter, so this lands in /valuate errors.
            --
            -- It used to print its own once-only message with its own flag, which meant
            -- /valuate errors - the command whose whole job is "anything that went wrong
            -- this session" - would answer "nothing" while junk cleanup had been broken
            -- since login. A diagnostic that under-reports is worse than none, because
            -- it is trusted.
            if Valuate.ReportRuntimeError then
                Valuate:ReportRuntimeError("automatic junk cleanup", err)
            end
            if not self.errorReported then
                self.errorReported = true
                print("  |cFFAAAAAARun /valuate deletepreview to check what it would act on.|r")
            end
        end
    end
end)

-- Debounced "something entered your bags -> is it an upgrade?" check. Shared by every
-- inventory-addition trigger (loot, quest rewards, mail, trade, crafting, vendor buys),
-- since ITEM_PUSH can fire many times in quick succession when a batch of items lands.
-- Each call restarts the timer, so we scan and prompt once after things settle.
local pendingNotifyTimer
local notifyBurstStartedAt
local MAX_NOTIFY_DEFER = 5
local function ScheduleUpgradeNotifyCheck(delay, retries)
    if not Valuate.GetOptions or not Valuate:GetOptions().notifyBagUpgrade then return end

    -- Capped debounce, same reasoning as the scan and cleanup schedulers: ITEM_PUSH
    -- fires once per looted item, and an uncapped re-arm meant a long loot burst
    -- postponed the check indefinitely.
    local now = GetTime()
    if not pendingNotifyTimer then
        notifyBurstStartedAt = now
    elseif notifyBurstStartedAt and (now - notifyBurstStartedAt) >= MAX_NOTIFY_DEFER then
        return  -- let the already-armed timer fire
    end

    if pendingNotifyTimer and pendingNotifyTimer.Cancel then
        pendingNotifyTimer:Cancel()
    end
    pendingNotifyTimer = ValuateAfter(delay or 1.5, function()
        pendingNotifyTimer = nil
        notifyBurstStartedAt = nil
        -- Not gated on combat: CheckBagUpgradeNotify defers to PLAYER_REGEN_ENABLED
        -- itself. Only the in-transit guard applies (don't read bag slots mid-move).
        if equipmentSwapPending or recentEquipmentChange then
            -- Previously this DROPPED the check, so an upgrade that landed while
            -- gear was in transit never prompted at all - a big part of why the
            -- popup appeared only sometimes. Retry instead, bounded so we can't
            -- re-arm forever on clients without C_Timer (each call makes a frame).
            retries = (retries or 0) + 1
            if retries <= 5 then
                ScheduleUpgradeNotifyCheck(2.0, retries)
            end
            return
        end
        if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
        if Valuate.CheckBagUpgradeNotify then Valuate:CheckBagUpgradeNotify("loot") end
    end)
end

-- Event handler
local function OnEvent(self, event, addonName, ...)
    if event == "ADDON_LOADED" and addonName == "Valuate" then
        -- Addon loaded, initialize
        Valuate:Initialize()
    elseif event == "PLAYER_LEVEL_UP" then
        -- The new level arrives in the first vararg slot, which this handler names
        -- `addonName` because ADDON_LOADED got there first. Fall back to UnitLevel if
        -- it is missing rather than trusting the parameter name.
        local newLevel = tonumber(addonName) or (UnitLevel and UnitLevel("player"))
        if Valuate.AnnounceUnlockedUpgrades then
            Valuate:AnnounceUnlockedUpgrades(newLevel)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")

        -- Refresh best-in-slot on login. The saved data survives across sessions but
        -- can be stale - gear arrives by mail, or the last session ended mid-scan -
        -- and until something happened to trigger a scan, the panel and the arrows
        -- were showing whatever was true when you last logged out.
        --
        -- TWO attempts, deliberately. Right after entering the world the client's
        -- item cache is cold: GetItemInfo returns nil for items it hasn't loaded
        -- yet, and the scan skips those, so a single early scan can quietly produce
        -- a WORSE result than not scanning at all. The first pass covers the normal
        -- case; the second catches anything still loading. A spare scan per session
        -- is far cheaper than best-in-slot silently missing half your bags.
        ValuateAfter(6.0, function() ScheduleScan(0, "login") end)
        ValuateAfter(15.0, function() ScheduleScan(0, "login") end)
    elseif event == "EQUIPMENT_SWAP_PENDING" then
        -- Equipment swap is starting, pause scanning completely
        equipmentSwapPending = true
        recentEquipmentChange = true
        -- Cancel any pending scan
        if pendingScanTimer then
            pendingScanTimer:Cancel()
            pendingScanTimer = nil
        end
    elseif event == "EQUIPMENT_SWAP_FINISHED" then
        -- Equipment swap is complete, but wait for bag updates to settle
        equipmentSwapPending = false
        bagUpdateCooldown = GetTime()
        -- Failsafe: clear the in-transit flag once items settle even when
        -- Auto Scan is off (see PLAYER_EQUIPMENT_CHANGED note).
        ValuateAfter(4.0, function()
            recentEquipmentChange = false
        end)
        -- Wait much longer after swap to ensure items are fully in bags
        -- Don't scan immediately - let items settle first
        ScheduleScan(3.0, "swap")
    elseif event == "BAG_UPDATE" then
        -- Bag contents changed - items are being moved
        local currentTime = GetTime()
        bagUpdateCooldown = currentTime  -- Reset cooldown
        -- If we're in a swap or recently had equipment changes, wait longer.
        -- This is the real "items are in transit" guard - it must stay.
        if equipmentSwapPending or recentEquipmentChange then
            return
        end

        -- Below the in-transit guard on purpose, so it inherits that protection without
        -- altering it: nothing is collected while items are still moving between bags and
        -- slots. Throttled internally, and a no-op unless you switched it on.
        if Valuate.AutoLearnAppearances then Valuate:AutoLearnAppearances() end

        -- Check if we should scan on bag updates (for "always" mode).
        -- Debouncing is handled entirely by ScheduleScan (it cancels and
        -- reschedules on every call) plus the scan callback's own bag-quiet
        -- gate (it waits until GetTime() - bagUpdateCooldown >= 2s before it
        -- actually scans). The previous "< 1.0" early-return here compared
        -- currentTime against bagUpdateCooldown, which was just set to
        -- currentTime one line above, so it was always true and silently
        -- disabled "always" mode entirely.
        local options = Valuate:GetOptions()
        local autoScan = options.autoScan or "onEquipmentChange"
        if autoScan == "always" then
            -- Short settle window in "always" mode: the point of the mode is that
            -- best-in-slot tracks your bags, so a change should show up promptly
            -- rather than several seconds later.
            ScheduleScan(ScanTiming().delay, "bag")
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Equipment changed - mark that we had a change
        recentEquipmentChange = true
        -- Failsafe: always clear the in-transit flag after items have settled.
        -- Previously it was only cleared when a scheduled scan ran, so with
        -- Auto Scan = "off" it stayed true forever and silently blocked all
        -- MANUAL scans (/valuate scan and the panel button) after any equip.
        ValuateAfter(4.0, function()
            recentEquipmentChange = false
        end)
        -- Skip scanning entirely if equipment swap is in progress
        if equipmentSwapPending then
            return
        end

        -- Every equip AND unequip lands here (PLAYER_EQUIPMENT_CHANGED covers both),
        -- so best-in-slot re-evaluates against what you're actually wearing.
        -- Still a real settle window so the item has finished moving between the
        -- bag and the equipment slot - just a much shorter one in "always" mode.
        ScheduleScan(ScanTiming().equip, "equipment")
    elseif event == "LOOT_OPENED" then
        -- Loot window opened - schedule scan after loot is collected
        -- Wait a bit to ensure items are in bags
        ScheduleScan(2.0, "loot")
    elseif event == "QUEST_COMPLETE" then
        -- Quest reward screen is up - auto-select the best choosable reward
        if Valuate.AutoSelectBestQuestReward then
            Valuate:AutoSelectBestQuestReward()
        end
    elseif event == "QUEST_PROGRESS" then
        -- "Do you have the items?" screen - advance it when full auto turn-in is on
        if Valuate.AutoAdvanceQuestProgress then
            Valuate:AutoAdvanceQuestProgress()
        end
    elseif event == "QUEST_FINISHED" then
        -- Quest window closed: clear our best-reward marker so it can't linger on
        -- screen (it's parented to UIParent, not the quest button).
        if Valuate.questRewardMarker then Valuate.questRewardMarker:Hide() end
    elseif event == "QUEST_DETAIL" or event == "QUEST_ACCEPT_CONFIRM"
           or event == "QUEST_GREETING" or event == "GOSSIP_SHOW" then
        -- Auto-accept quests offered by NPCs (opt-in)
        if Valuate.AutoAcceptQuests then
            Valuate:AutoAcceptQuests(event)
        end
    elseif event == "LOOT_CLOSED" then
        -- Prune junk to keep bag space free, and check for upgrades (both opt-in).
        ScheduleJunkCleanup(1.0)
        ScheduleUpgradeNotifyCheck(1.5)
    elseif event == "ITEM_PUSH" then
        -- ANY item entering your bags - quest reward, mail, trade, craft, vendor buy,
        -- loot - can both fill your bags and be an upgrade, so run both checks.
        ScheduleJunkCleanup(1.0)
        ScheduleUpgradeNotifyCheck(1.5)
    elseif event == "MERCHANT_SHOW" then
        -- Sell junk / repair on arrival at a vendor (both opt-in). Small delay so the
        -- merchant frame is fully up before we start selling.
        local options = Valuate:GetOptions()
        if options.autoRepair and Valuate.AutoRepair then
            ValuateAfter(0.3, function() Valuate:AutoRepair() end)
        end
        if options.autoSellJunk and Valuate.AutoSellJunk then
            ValuateAfter(0.5, function() Valuate:AutoSellJunk() end)
        end
    elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED"
           or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        local bankJustOpened = (event == "BANKFRAME_OPENED")
        -- The bank is the only time its containers are readable, so snapshot it now.
        -- Delayed slightly on open so every bank bag has reported its contents, and
        -- re-run on change so moving gear in or out updates the snapshot. This only
        -- feeds best-in-slot; nothing destructive ever reads the bank.
        if Valuate.ScanBankContents then
            ValuateAfter(0.4, function()
                if Valuate:ScanBankContents() then
                    ScheduleScan(0.6, "bank")  -- fold new candidates into best-in-slot
                    -- ...then say whether anything in there beats what you are wearing.
                    --
                    -- The count already existed - CountEquippableUpgrades has always
                    -- returned a bank figure, and the minimap tooltip shows it - but
                    -- only if you went looking. Standing at an open bank is the one
                    -- moment it is directly actionable: the item is an arm's reach away
                    -- and you are about to walk off without it.
                    --
                    -- ONLY on open. This branch also handles PLAYERBANKSLOTS_CHANGED,
                    -- which fires on every item moved in or out - so without this guard,
                    -- shuffling five things through the bank would print five times.
                    if bankJustOpened then
                        ValuateAfter(1.2, function()
                            if not Valuate.CountEquippableUpgrades then return end
                            -- Convenience, so it honours the verbosity option. Fires on
                            -- every bank visit that has an upgrade in it.
                            if not Valuate:GetOptions().chatMessages then return end
                            local _, scaleName = Valuate:GetPrimaryScale()
                            if not scaleName then return end
                            local _, _, bankCount = Valuate:CountEquippableUpgrades(scaleName)
                            if (bankCount or 0) > 0 then
                                print(string.format(
                                    "|cFF00FF00Valuate|r: |cFFFF8800%d item(s) in this bank|r beat what you are wearing for %s.",
                                    bankCount, scaleName))
                                print("  |cFFAAAAAATake them out and Valuate will treat them as equippable.|r")
                            end
                        end)
                    end
                end
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat: show any bag-upgrade prompt that was deferred while fighting.
        -- Rescan first, since the deferred check may have been made on stale data.
        if bagUpgradePending then
            bagUpgradePending = false
            if not equipmentSwapPending and not recentEquipmentChange then
                if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
            end
            if Valuate.CheckBagUpgradeNotify then Valuate:CheckBagUpgradeNotify("loot") end
        end
    elseif event == "START_LOOT_ROLL" then
        -- arg1 (the addonName slot) is the rollID for this event
        if Valuate.AutoRollOnLoot then
            Valuate:AutoRollOnLoot(addonName)
        end
    elseif event == "CONFIRM_LOOT_ROLL" then
        -- arg1 = rollID, arg2 = rollType
        local rollType = ...
        if Valuate.ConfirmAutoLootRoll then
            Valuate:ConfirmAutoLootRoll(addonName, rollType)
        end
    elseif event == "EQUIP_BIND_CONFIRM" or event == "AUTOEQUIP_BIND_CONFIRM"
           or event == "LOOT_BIND_CONFIRM" then
        -- arg1 (the addonName slot) is the inventory/loot slot for these events
        if Valuate.HandleBindConfirm then
            Valuate:HandleBindConfirm(event, addonName)
        end
    end
end

-- ========================================
-- Per-Character Profile System
-- ========================================

-- Get unique character identifier (realm + character name)
function Valuate:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return realm .. "_" .. name
end

-- Single source of truth for per-character option defaults. Used both when
-- creating a fresh character's options and when backfilling missing keys for an
-- existing character after an update (see Valuate:Initialize). Keeping one list
-- prevents the two default sets from drifting apart.
-- Note: characterWindowScale is intentionally omitted (its default is nil).
local DEFAULT_OPTIONS = {
    debug = false,
    decimalPlaces = 1,
    rightAlign = false,
    showScaleValue = "all",              -- "all" or "current"
    showBestFor = true,
    chatMessages = true,                  -- verbose chat messages
    scanVerbose = false,                  -- scan completion messages
    showStartupMessage = true,            -- "Valuate loaded" message
    comparisonMode = "number",
    showCharacterWindowDisplay = true,
    minimapButtonHidden = false,
    -- Where on the minimap ring you dragged the button. Declared here rather than
    -- created on first drag, because the settings snapshot only applies keys that
    -- exist in this table - undeclared, it was saved and then silently discarded.
    -- Unlike uiPosition this is a ring angle, so it means the same thing on every
    -- character and every resolution, and is worth carrying to an alt.
    minimapButtonAngle = 200,             -- degrees; matches MinimapButton's fallback
    characterWindowDisplayMode = "total",
    uiPosition = {},                      -- table default: fresh copy per character
    normalizeDisplay = false,
    reduceMotion = false,                 -- collapse all UI animations to instant
    -- id -> addon version it was checked at. /valuate verify keeps your place across
    -- sessions: ten checks is more than anyone holds in their head, and losing track
    -- halfway is the difference between doing the pass and abandoning it.
    verifiedChecks = {},
    showStatBreakdown = false,
    autoScan = "onEquipmentChange",       -- "off" | "onEquipmentChange" | "onLoot" | "always"
    notifyBagUpgrade = false,             -- popup when an equippable upgrade for the current scale is in bags
    notifyBagUpgradeMode = "everyLoot",   -- "everyLoot" (re-prompt each loot) | "oncePerUpgrade"
    notifyBagUpgradeStyle = "dialog",     -- "dialog" (popup with Equip button) | "chat" (message only)
    notifyUpgradeSound = false,           -- play a sound cue when an upgrade is found
    notifyOtherSpecUpgrades = false,      -- also mention upgrades for your NON-active scales
    autoRollLoot = false,                 -- auto Need/Greed on group loot rolls
    autoRollRecipes = true,               -- also Need unlearned recipes for professions you have
    autoRollTradeGoods = true,            -- also Need crafting materials your professions use
    professionOverrides = {},             -- profession name -> true; treated as yours regardless of detection
    autoConfirmBindOnLoot = false,        -- auto-confirm bind prompts when YOU loot/use a BoP item
    autoDeleteJunk = false,               -- delete cheapest junk to keep bag slots free
    autoDeleteDryRun = false,             -- log what WOULD be deleted instead of deleting
    autoDeleteKeepFree = 4,               -- target number of free bag slots
    autoDeleteMaxQuality = 2,             -- never delete above this quality (2 = uncommon/green)
    autoDeleteMaxValue = 100000,          -- ceiling: never delete a stack worth MORE than this (copper)
    autoDeleteMinValue = 0,               -- floor: never delete a stack worth LESS than this (0 = no floor)
    autoDeleteValueSource = "vendor",     -- "vendor", or a TSM price source e.g. "DBMarket"
    autoDeleteIntervalSecs = 60,          -- also run cleanup every N seconds (0 = only on loot/bag events)
    autoSellJunk = false,                 -- sell junk automatically when a merchant opens
    autoRepair = false,                   -- repair automatically when a merchant can repair
    autoRepairGuildFirst = false,         -- try guild funds before your own money
    autoAcceptQuests = false,             -- auto-accept quests offered by NPCs
    autoAcceptSkipTrivial = false,        -- skip quests far below your level
    autoAcceptTrivialBelow = 8,           -- "far below" = this many levels under you
    autoQuestReward = false,              -- auto-select best quest reward for the active scale
    autoQuestTurnIn = false,              -- also auto-complete the quest (requires autoQuestReward)
    ignoreProfessionTools = true,         -- never score/track fishing poles & profession tool weapons
    showUpgradeArrows = true,              -- green arrow on merchant/loot/bag icons that upgrade a scale
    includeBankItems = true,              -- count banked gear as best-in-slot candidates (Equip All still skips it)
    -- Collect wardrobe appearances you do not have yet, from items in your bags. Off by
    -- default like every automation here, and with more reason than most: collecting may
    -- BIND the item, which nothing in this client lets me verify. /valuate wardrobe lists
    -- exactly what it would take before you switch it on.
    autoLearnAppearances = false,
}

-- Backfill any missing option keys from DEFAULT_OPTIONS without clobbering saved
-- values. Table-valued defaults get a fresh table so characters never share a ref.
local function ApplyOptionDefaults(options)
    for key, value in pairs(DEFAULT_OPTIONS) do
        if options[key] == nil then
            if type(value) == "table" then
                options[key] = {}
            else
                options[key] = value
            end
        end
    end
end

-- Get character-specific options table
function Valuate:GetOptions()
    if not ValuateOptions then
        ValuateOptions = {}
        ApplyOptionDefaults(ValuateOptions)
    end
    return ValuateOptions
end

-- Restores every option to its default. Returns how many actually changed.
--
-- Options ONLY. Scales, the scale library, best-equipment data and the bank
-- snapshot are untouched: 48 options accumulate a lot of state you might want to
-- clear, but losing your scales because you wanted your checkboxes back would be
-- an appalling trade.
function Valuate:RestoreDefaultOptions()
    local options = Valuate:GetOptions()
    local changed = 0

    -- Wipe in place rather than replacing the table: other files hold references to
    -- it (GetOptions() results get cached in closures), and swapping the table would
    -- leave them writing to an orphan.
    for key in pairs(options) do
        options[key] = nil
        changed = changed + 1
    end
    ApplyOptionDefaults(options)

    -- Anything derived from an option has to be recomputed, or the UI keeps showing
    -- decisions made under the old settings.
    if Valuate.ResetTooltips then Valuate:ResetTooltips() end
    if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
    if Valuate.ApplyMinimapButtonOptions then Valuate:ApplyMinimapButtonOptions() end
    return changed
end

-- ============================================================================
-- Settings snapshot (shared across characters)
-- ============================================================================
-- The scale library solved "set it up again on every alt" for scales; 48 options
-- have exactly the same problem and nothing solved it. This is one account-wide
-- snapshot you can save on a configured character and apply to any other.
--
-- Three options are NEVER copied, because they describe the character rather than
-- your preferences:
local SNAPSHOT_EXCLUDED = {
    -- Where you dragged the window; screen-specific, and not what "settings" means.
    uiPosition = true,
    -- Which professions this character has. Copying a blacksmith's overrides onto a
    -- tailor would make auto-roll Need recipes they can never learn - and quietly.
    professionOverrides = true,
    -- Names a scale that may not exist on the target character.
    characterWindowScale = true,
}

function Valuate:SaveSettingsSnapshot()
    local snapshot, count = {}, 0
    for key, value in pairs(Valuate:GetOptions()) do
        -- Only plain values: the excluded keys cover the tables, and copying a table
        -- by reference would alias two characters' settings to the same object.
        if not SNAPSHOT_EXCLUDED[key] and type(value) ~= "table" then
            snapshot[key] = value
            count = count + 1
        end
    end
    ValuateSettingsSnapshot = snapshot
    return count
end

function Valuate:LoadSettingsSnapshot()
    local snapshot = ValuateSettingsSnapshot
    if type(snapshot) ~= "table" or not next(snapshot) then
        return false, "no settings have been saved yet"
    end

    local options = Valuate:GetOptions()
    local applied = 0
    for key, value in pairs(snapshot) do
        -- Only keys that are still real options, so a snapshot taken before an
        -- option was renamed can't reintroduce a dead key.
        if DEFAULT_OPTIONS[key] ~= nil and not SNAPSHOT_EXCLUDED[key] then
            options[key] = value
            applied = applied + 1
        end
    end

    if Valuate.ResetTooltips then Valuate:ResetTooltips() end
    if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
    if Valuate.ApplyMinimapButtonOptions then Valuate:ApplyMinimapButtonOptions() end
    return true, applied
end

function Valuate:HasSettingsSnapshot()
    return type(ValuateSettingsSnapshot) == "table" and next(ValuateSettingsSnapshot) ~= nil
end

-- Get character-specific scales table
function Valuate:GetScales()
    if not ValuateScales then
        ValuateScales = {}
    end
    return ValuateScales
end

-- ============================================================================
-- Generated scale naming
-- ============================================================================
-- A scale the wizard builds names ITSELF, from what it actually weights:
-- "Auto - Str/Crit/Hit/AP/Haste". The five stats it leads with are the five it will
-- really chase, so the name summarises the scale instead of being a label you have to
-- remember the meaning of. Five is what fits a scale-list row without truncating.
--
-- Ties break on the stat NAME. pairs() order is undefined, and without a total order the
-- same weights could produce two different names on two characters - the exact bug class
-- this project keeps turning up.
local AUTO_NAME_PREFIX = "Auto - "
local AUTO_NAME_COUNT = 5

function Valuate:BuildAutoScaleName(weights)
    local ranked = {}
    for stat, weight in pairs(weights or {}) do
        -- Only stats the scale CHASES describe it. A scale that weights Spirit at zero,
        -- or negatively, is not a Spirit scale.
        if type(weight) == "number" and weight > 0 then
            table.insert(ranked, { stat = stat, weight = weight })
        end
    end

    table.sort(ranked, function(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.stat < b.stat
    end)

    local parts = {}
    for i = 1, math.min(AUTO_NAME_COUNT, #ranked) do
        local stat = ranked[i].stat
        -- Falls back to the full stat name rather than dropping it: a long name beats a
        -- name that quietly describes four stats while the scale weights five.
        local abbreviations = ValuateStatAbbreviations or {}
        table.insert(parts, abbreviations[stat] or stat)
    end

    if #parts == 0 then
        -- Nothing weighted. Still a valid, unique-able name, and it says what is wrong.
        return AUTO_NAME_PREFIX .. "Empty"
    end
    return AUTO_NAME_PREFIX .. table.concat(parts, "/")
end

-- ============================================================================
-- Matching a build to a curated template
-- ============================================================================
-- Ascension is classless, so "what class are you" is the wrong question and a spec list is
-- the wrong menu. But the 31 CLASS_SPEC_TEMPLATES are still hand-tuned weight sets, and
-- the gear you are ALREADY wearing says which of them you resemble. Comparing the two is
-- how the wizard proposes an answer instead of interrogating you for one.
--
-- Cosine similarity: the angle between what you wear and what a spec values, ignoring how
-- MUCH of it you have. That matters here - a level 20 and a level 80 wearing the same kind
-- of gear should match the same template, and raw totals would put them nowhere near each
-- other.
local MATCH_IGNORED_STATS = {
    -- On everything, in proportion to item level rather than to what you are building.
    -- Leaving them in pulls every comparison toward the same answer.
    Stamina = true, Armor = true, Health = true, ItemLevel = true,
}

local function StatVectorSimilarity(weights, totals)
    local dot, weightLen, totalLen = 0, 0, 0
    for stat, weight in pairs(weights) do
        if not MATCH_IGNORED_STATS[stat] and type(weight) == "number" and weight > 0 then
            local have = totals[stat]
            if type(have) == "number" and have > 0 then
                dot = dot + weight * have
                totalLen = totalLen + have * have
            end
            weightLen = weightLen + weight * weight
        end
    end
    -- Only stats you actually have count toward YOUR length, so a spec is not punished for
    -- valuing something you have none of yet.
    if dot <= 0 or weightLen <= 0 or totalLen <= 0 then return 0 end
    return dot / (math.sqrt(weightLen) * math.sqrt(totalLen))
end

-- Returns the best-matching spec, its similarity, and the runner-up - the wizard shows the
-- runner-up so a close call is visible rather than presented as certainty.
function Valuate:MatchTemplateToStats(templates, totals, role)
    if type(templates) ~= "table" or type(totals) ~= "table" then return nil, 0 end

    local ranked = {}
    for _, class in ipairs(templates) do
        for _, spec in ipairs(class.specs or {}) do
            if (not role) or spec.role == role then
                table.insert(ranked, {
                    spec = spec,
                    class = class,
                    score = StatVectorSimilarity(spec.weights or {}, totals),
                    -- Class and spec name together, because two classes both have a
                    -- "Protection" and ordering has to be total.
                    key = tostring(class.class) .. "/" .. tostring(spec.name),
                })
            end
        end
    end

    table.sort(ranked, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.key < b.key
    end)

    if not ranked[1] or ranked[1].score <= 0 then return nil, 0 end
    -- The runner-up's SCORE comes back too. Without it the caller can only say "X was the
    -- next best", which it then has to phrase as "X was close" - and that is a claim, not a
    -- description. It was being made whether or not the runner-up was anywhere near.
    return ranked[1].spec, ranked[1].score, ranked[2] and ranked[2].spec or nil,
        ranked[1].class, ranked[2] and ranked[2].score or 0
end

-- Rescales so the leading stat is exactly 1.0 and drops the noise. Templates carry weights
-- as low as 0.005, which exist as tiebreakers and are meaningless once a scale is scored -
-- but they DO reach the stat editor, where forty near-zero rows are what makes a generated
-- scale feel unusable rather than optimized.
local NORMALIZE_FLOOR = 0.05

function Valuate:NormalizeWeights(weights, floor)
    floor = floor or NORMALIZE_FLOOR
    local top = 0
    for _, weight in pairs(weights or {}) do
        if type(weight) == "number" and weight > top then top = weight end
    end
    if top <= 0 then return {} end

    local out = {}
    for stat, weight in pairs(weights) do
        if type(weight) == "number" and weight > 0 then
            local scaled = weight / top
            -- Rounded to two places: a weight of 0.8333333 is not more accurate than 0.83,
            -- and it looks like a bug in the editor.
            scaled = math.floor(scaled * 100 + 0.5) / 100
            if scaled >= floor then out[stat] = scaled end
        end
    end
    return out
end

-- Running the wizard twice with the same answers would produce the same name, and scales
-- are keyed by name - so the second run would overwrite the first. Suffix instead of
-- refusing: the wizard must never dead-end on something the user did not ask about.
function Valuate:BuildUniqueAutoScaleName(weights, existing)
    local base = Valuate:BuildAutoScaleName(weights)
    existing = existing or Valuate:GetScales()
    if not existing[base] then return base end

    local n = 2
    while existing[base .. " (" .. n .. ")"] do
        n = n + 1
    end
    return base .. " (" .. n .. ")"
end

-- ============================================================================
-- The guided wizard: plan, then commit
-- ============================================================================
-- Split deliberately in two. PlanAutoScale works everything out and changes NOTHING, so
-- the wizard can show you exactly what it is about to make and you can back out; commit is
-- the only half that writes. A wizard that creates as it goes leaves debris behind when you
-- close it halfway, and this one is aimed at people who will close it halfway.
--
-- Every generated scale shares ONE colour rather than taking the matched spec's, so you can
-- tell at a glance which scales you built by hand and which the wizard made. The icon still
-- comes from the matched spec: the icon says what it is, the colour says where it came from.
local AUTO_SCALE_COLOR = "3FE0C8"

-- Below this the wizard says so rather than presenting a guess with a straight face. Mixed
-- gear, levelling greens and a half-finished set all land here, and they are exactly the
-- people who cannot tell a good answer from a bad one - which is why the wizard, not the
-- user, has to be the one to admit it.
local MATCH_UNSURE = 0.55

-- A runner-up only gets mentioned if it was genuinely nearly as good. "X was close" said
-- about something that scored far lower is a false statement on a confirm screen.
local MATCH_CLOSE_MARGIN = 0.03

-- Same gear, same answer - so a second run would build a scale identical to one you already
-- have, and hand it a "(2)" suffix to tell two indistinguishable things apart. Finding it
-- first turns that into "you already have this", which is the honest result and one less
-- row in the list.
local function WeightsMatch(a, b)
    for stat, weight in pairs(a) do
        if b[stat] ~= weight then return false end
    end
    -- Both directions: a subset is not a match, and checking one way would call a scale
    -- with three extra stats identical to one with three fewer.
    for stat in pairs(b) do
        if a[stat] == nil then return false end
    end
    return true
end

function Valuate:FindMatchingAutoScale(weights, scales)
    if type(weights) ~= "table" then return nil end
    scales = scales or Valuate:GetScales()

    -- Sorted, because pairs() has no order and two equally-identical scales would otherwise
    -- make the wizard offer a different one each time you ran it.
    local names = {}
    for name in pairs(scales) do table.insert(names, name) end
    table.sort(names)

    for _, name in ipairs(names) do
        local scale = scales[name]
        if scale and type(scale.Values) == "table" and WeightsMatch(weights, scale.Values) then
            return name
        end
    end
    return nil
end

-- A scale THIS wizard made whose weights no longer match what your gear says.
--
-- Without this the wizard can only ever create. Level twenty levels, respec, change armour
-- class, and the Auto scale you made at the start is quietly wrong - and the only way to fix
-- it is to delete it and run the wizard again, which is a chore nobody should have to work
-- out for themselves.
--
-- ONLY wizard-made scales qualify, and the colour is the test. A scale you recoloured or
-- built by hand is yours; the wizard has no business rewriting it. That is deliberately
-- stricter than matching on the "Auto - " name, which you could have typed yourself.
-- `basedOn` is the class/spec the new plan came from, and matching on it is what makes this
-- safe. Without it, asking for a Tank build while you already had a DPS Auto scale would
-- offer to REPLACE the DPS one - they are two different builds, not one that drifted, and
-- wanting both is completely ordinary.
--
-- Scales made before this existed have no AutoSource, so they are never updated. They get a
-- second scale instead, which is the old behaviour and the safe direction.
function Valuate:FindUpdatableAutoScale(weights, basedOn, scales)
    if type(weights) ~= "table" or next(weights) == nil then return nil end
    if type(basedOn) ~= "string" or basedOn == "" then return nil end
    scales = scales or Valuate:GetScales()

    -- Sorted: pairs() has no order, and two updatable scales would otherwise make the wizard
    -- offer a different one each time you opened it.
    local names = {}
    for name in pairs(scales) do table.insert(names, name) end
    table.sort(names)

    for _, name in ipairs(names) do
        local scale = scales[name]
        if scale
            and scale.Color == AUTO_SCALE_COLOR
            and scale.AutoSource == basedOn
            and type(scale.Values) == "table"
            and next(scale.Values) ~= nil
            and not WeightsMatch(weights, scale.Values) then
            return name
        end
    end
    return nil
end

function Valuate:PlanAutoScale(opts)
    opts = opts or {}
    local totals = opts.totals
    if type(totals) ~= "table" or next(totals) == nil then
        return nil, "I could not read any equipped gear - put something on first."
    end

    local spec, score, runnerUp, class, runnerUpScore =
        Valuate:MatchTemplateToStats(opts.templates, totals, opts.role)
    if not spec then
        return nil, "Nothing in the templates resembles what you are wearing."
    end

    local weights = Valuate:NormalizeWeights(spec.weights)
    if next(weights) == nil then
        return nil, "The closest template has no weights worth keeping."
    end

    -- Every field the wizard needs to DESCRIBE the plan, so the confirm screen never has to
    -- recompute anything and cannot disagree with what gets committed.
    -- If an identical scale already exists, the plan describes THAT one rather than a twin.
    local duplicateOf = Valuate:FindMatchingAutoScale(weights, opts.existing)

    -- Otherwise, a wizard-made scale that has drifted is offered as an UPDATE rather than as
    -- a second scale. Checked only when there is no exact duplicate, because "you already
    -- have this" is the better answer whenever it is true.
    local updates = nil
    if not duplicateOf then
        updates = Valuate:FindUpdatableAutoScale(weights,
            tostring(class and class.class or "?") .. " " .. tostring(spec.name or "?"),
            opts.existing)
    end

    return {
        duplicateOf = duplicateOf,
        updates = updates,
        -- An UPDATE takes the plain name, not a unique one: the scale it replaces is about to
        -- free that slot, so suffixing would rename your scale to "(2)" for no reason.
        name = duplicateOf
            or (updates and Valuate:BuildAutoScaleName(weights))
            or Valuate:BuildUniqueAutoScaleName(weights, opts.existing),
        weights = weights,
        color = AUTO_SCALE_COLOR,
        icon = spec.icon,
        basedOn = tostring(class and class.class or "?") .. " " .. tostring(spec.name or "?"),
        role = spec.role,
        -- The template's banned stats travel with the plan.
        --
        -- They were being dropped: every wizard-made scale got an EMPTY Unusable table, so a
        -- two-hander-only build scored daggers and wands as normal candidates and Best
        -- Equipment would offer them. The templates define these carefully - Retribution bans
        -- nine weapon types - and the wizard was throwing all of it away.
        --
        -- CoA templates have no unusable list yet, so this is nil for them, which is the same
        -- empty table they got before. No change there, and no invented restrictions either.
        unusable = spec.unusable,
        confidence = score,
        -- Only when it really was close. Certainty you have not earned is worse than a
        -- question, but so is a hedge you have not earned.
        alternative = (runnerUp and (score - (runnerUpScore or 0)) <= MATCH_CLOSE_MARGIN)
            and runnerUp.name or nil,
        -- Set when the wizard should not sound sure. The screen still lets you create it -
        -- a dead end helps nobody - but it says what would give a better answer.
        caution = (score < MATCH_UNSURE)
            and "Your gear is mixed, so this is a rough guess. Picking a role below usually does better."
            or nil,
    }
end

function Valuate:CommitAutoScale(plan, scales)
    if type(plan) ~= "table" or type(plan.name) ~= "string" or plan.name == "" then
        return nil, "There is nothing to create."
    end
    scales = scales or Valuate:GetScales()

    -- Already have this exact scale. Select it rather than creating an indistinguishable
    -- twin - and do NOT overwrite it, because the user may have renamed or recoloured it
    -- and only the weights are known to match.
    local existing = plan.duplicateOf and scales[plan.duplicateOf]
    if existing then
        if Valuate.GetOptions then
            Valuate:GetOptions().characterWindowScale = plan.duplicateOf
        end
        if Valuate.ResetTooltips then Valuate:ResetTooltips() end
        if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
        return existing, "reused"
    end

    -- Updating a scale the wizard made earlier. The old entry goes, the new one arrives under
    -- the name the current weights earn - the top five stats may well have changed, and a
    -- scale called "Auto - Str/Crit/..." that no longer weights Strength first is worse than
    -- no name at all.
    --
    -- Safe because only wizard-coloured scales reach here, and because you pressed a button
    -- that said "Update" next to a preview of exactly what it would become.
    if plan.updates and scales[plan.updates] and plan.updates ~= plan.name then
        scales[plan.updates] = nil
    end

    local scale = {
        DisplayName = plan.name,
        Color = plan.color or AUTO_SCALE_COLOR,
        Icon = plan.icon,
        -- Which class/spec built this, so a later run can tell "the same build, drifted"
        -- from "a different build entirely" and only offer to update the former.
        AutoSource = plan.basedOn,
        Values = {},
        Unusable = {},
        Visible = true,
    }
    -- Banned stats, copied for the same reason the weights are: the plan outlives the commit.
    for stat in pairs(plan.unusable or {}) do
        scale.Unusable[stat] = true
    end

    -- COPIED, not referenced. The plan can be shown again or thrown away without the saved
    -- scale changing underneath it - and the wizard does show it again on the last screen.
    for stat, weight in pairs(plan.weights or {}) do
        scale.Values[stat] = weight
    end
    scales[plan.name] = scale

    -- Ends on a scale that is actually in use. Dropping you back at a list with a new row to
    -- go and select yourself is the point where a wizard stops being one.
    if Valuate.GetOptions then
        Valuate:GetOptions().characterWindowScale = plan.name
    end
    if Valuate.ResetTooltips then Valuate:ResetTooltips() end
    if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
    -- The caller says what happened rather than inferring it, so the final screen can report
    -- "updated" instead of claiming to have made something new.
    return scale, plan.updates and "updated" or nil
end

-- Has the scale the wizard made for you fallen behind the gear you are actually wearing?
--
-- v0.88.0a gave the wizard the ability to UPDATE its own scale, and immediately created a
-- discovery problem: the only way to find out a scale had drifted was to re-run the wizard
-- on a hunch. A stale scale is not a preference, it is quietly wrong - it ranks your gear
-- against weights you outgrew - so leaving that behind a hunch is not good enough.
--
-- This is the read-only half of PlanAutoScale. It writes nothing, creates nothing, and is
-- deliberately NOT an automation: it changes no state and takes no action, it only answers
-- a question the UI asks so it can offer the wizard by the right name. Nothing here needs
-- an opt-in because nothing here happens to you.
--
-- No `role` is passed. "Whatever your gear most resembles" is the only honest question to
-- ask unprompted; supplying a role would be inventing an intent you never expressed. And
-- because FindUpdatableAutoScale matches on AutoSource, a Tank scale is never reported as
-- drifted just because you are standing in DPS gear - that is a different build, not a
-- stale one, which is the same distinction the update itself rests on.
local DRIFT_TTL = 20
local driftCache, driftAt = nil, -1
function Valuate:GetAutoScaleDrift()
    if not Valuate.PlanAutoScale or not Valuate.GetScales then return nil end

    local now = (GetTime and GetTime()) or 0
    -- `now < driftAt` catches a clock that went backwards (a /reload resets GetTime).
    if driftAt >= 0 and now - driftAt <= DRIFT_TTL and now >= driftAt then
        return driftCache or nil
    end

    -- Cheap pre-check first: no wizard-made scale means nothing can be stale, so everyone
    -- who has never run the wizard skips the template match entirely.
    local anyAuto = false
    for _, scale in pairs(Valuate:GetScales()) do
        if type(scale) == "table" and scale.Color == AUTO_SCALE_COLOR and scale.AutoSource then
            anyAuto = true
            break
        end
    end

    local drifted = nil
    if anyAuto then
        local totals = Valuate.GetCachedEquippedStatTotals
            and Valuate:GetCachedEquippedStatTotals()
        local plan = Valuate:PlanAutoScale({
            templates = (Valuate.GetTemplateSet and Valuate:GetTemplateSet())
                or ns.CLASS_SPEC_TEMPLATES,
            totals = totals,
        })
        drifted = plan and plan.updates or nil
    end

    driftCache, driftAt = drifted or false, now
    return drifted
end

-- Get character-specific best equipment table
function Valuate:GetBestEquipment()
    if not ValuateBestEquipment then
        ValuateBestEquipment = {}
    end
    return ValuateBestEquipment
end

-- Migrate from account-wide to per-character SavedVariables
function Valuate:MigrateToPerCharacter()
    -- Check if we need to migrate from account-wide to per-character
    -- The SavedVariablesPerCharacter are now the main storage, but we may have
    -- old account-wide data that needs to be copied to this character
    
    -- Migration is automatic: WoW will create per-character versions of ValuateOptions
    -- and ValuateScales when we use SavedVariablesPerCharacter in the .toc file
    -- If this character doesn't have data yet, it will start with empty tables
    
    -- For backwards compatibility, we don't need explicit migration code since
    -- each character will get a fresh copy when logging in after the update
    
    -- Just ensure the per-character data is initialized
    if not ValuateOptions then
        ValuateOptions = {}
    end
    
    if not ValuateScales then
        ValuateScales = {}
    end
end

-- Initialize function
function Valuate:Initialize()
    -- Run migration first (if needed)
    Valuate:MigrateToPerCharacter()
    
    -- Get per-character options and initialize defaults if they don't exist
    local options = Valuate:GetOptions()
    
    -- Backfill any missing options from the shared defaults (handles existing
    -- characters that saved data before newer options were added).
    ApplyOptionDefaults(options)

    -- showScaleValue needs migration beyond a simple default: older versions
    -- stored a boolean, and we must guard against any invalid saved value.
    if type(options.showScaleValue) == "boolean" then
        -- Old boolean -> new string format (feature now always shows values)
        options.showScaleValue = "all"
    end
    if options.showScaleValue ~= "all" and options.showScaleValue ~= "current" then
        options.showScaleValue = "all"
    end
    
    -- Get per-character scales
    local scales = Valuate:GetScales()
    
    -- Initialize best equipment storage
    Valuate:GetBestEquipment()
    
    -- Clean up orphaned best equipment data from deleted scales
    Valuate:CleanupOrphanedBestEquipment()

    -- Basic initialization (reuse the 'options' table fetched above)
    if options.showStartupMessage then
        print("|cFF00FF00Valuate|r loaded (v" .. self.version .. ")")
    end
    
    -- Verify stat patterns loaded
    if not ValuateStatPatterns then
        print("|cFFFF0000Valuate|r: ERROR - StatDefinitions.lua failed to load!")
    end
    
    -- Hook into tooltips to parse scaled stats
    Valuate:HookTooltips()
    
    -- Create a default scale if none exist
    if not next(scales) then
        Valuate:CreateDefaultScale()
    end
    
    -- Initialize character window UI if available
    if Valuate.InitializeCharacterWindowUI then
        Valuate:InitializeCharacterWindowUI()
    end
end

-- The scale a brand-new install starts with, plus the one-time message explaining
-- what it is.
--
-- Its weights are deliberately crude - every primary stat at 1.0 - so an item's score
-- is roughly "how many stats does this have". That is a reasonable heuristic while
-- levelling and a poor one for anything else: it scores a plate DPS piece and a cloth
-- caster piece almost identically.
--
-- The problem was never the weights, it was the silence. This addon ships FORTY-FIVE
-- researched class/spec templates and the first-run path never mentioned them, so a
-- new user saw numbers that looked authoritative, had no way to know they were
-- placeholders, and would only find the real ones by going looking.
--
-- Nothing here can guess better on their behalf: Ascension is CLASSLESS, so there is
-- no spec to infer. Which makes saying so the whole job.
function Valuate:CreateDefaultScale()
    local defaultScale = {
        DisplayName = "Starter",
        Color = "00FF00",
        Visible = true,
        Values = {
            -- Crude on purpose; see above. Every primary stat counts the same.
            Strength = 1.0,
            Agility = 1.0,
            Stamina = 0.5,
            Intellect = 1.0,
            AttackPower = 1.0,
            SpellPower = 1.0,
        }
    }

    local scales = Valuate:GetScales()
    scales["Starter"] = defaultScale

    -- Deferred so it lands after the addon's own load line rather than above it, and
    -- after whatever else is still printing at login.
    --
    -- Deliberately NOT gated on chatMessages, unlike the level-up and bank notices.
    -- Those are conveniences that repeat; this fires once in a character's entire life
    -- and is the difference between the addon working for you and sitting there scoring
    -- everything the same. Silencing routine chatter is not a request to be left
    -- guessing on your first login.
    ValuateAfter(2, function()
        print("|cFF00FF00Valuate|r: created a |cFFFFFFFFStarter|r scale to get you going.")
        print("  |cFFFFFF00It weights every stat the same|r, so its scores only really mean")
        print("  \"has more stats\". Good enough while levelling, not much use beyond it.")

        -- An ALT is the case this branch exists for.
        --
        -- Scales and options are per-character; the scale library and the settings
        -- snapshot are account-wide, and they exist precisely so a new character does
        -- not start from nothing. But nothing ever said so at the one moment it
        -- matters, so someone who set all this up on their main would arrive here, see
        -- a Starter scale, and have no idea their real work was one command away.
        local saved = Valuate.ListScaleLibrary and Valuate:ListScaleLibrary() or {}
        local hasSnapshot = Valuate.HasSettingsSnapshot and Valuate:HasSettingsSnapshot()

        if #saved > 0 then
            print(string.format("  |cFF00FF00You already have %d scale(s) saved|r from another character:",
                #saved))
            -- Capped: this prints at login, and someone with fifteen scales in the
            -- library should get a hint, not a wall of text they scroll past.
            local shown = {}
            for i = 1, math.min(#saved, 5) do shown[i] = saved[i] end
            print("  " .. table.concat(shown, ", ")
                .. (#saved > 5 and (", and " .. (#saved - 5) .. " more") or ""))
            print("  |cFF00FF00/valuate library|r loads them onto this one.")
            if hasSnapshot then
                print("  |cFF00FF00/valuate settings load|r brings your options across too.")
            end
        else
            print("  |cFF00FF00Type /valuate|r and click |cFFFFFFFFFrom Template|r (top-left) - there are 45 built-in")
            print("  specs with proper weights. Pick whichever matches how you actually play.")
        end
    end)
end

-- ========================================
-- Stat Parsing System
-- ========================================

-- Helper function to strip color codes from text
local function StripColorCodes(text)
    if not text then return "" end
    -- Remove color codes like |cAARRGGBB| and |r|
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

-- Creates or gets the hidden tooltip used for parsing
local function GetPrivateTooltip()
    if not ValuatePrivateTooltip then
        ValuatePrivateTooltip = CreateFrame("GameTooltip", "ValuatePrivateTooltip", nil, "GameTooltipTemplate")
        ValuatePrivateTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return ValuatePrivateTooltip
end

-- Expose GetPrivateTooltip for use in other files
function Valuate:GetPrivateTooltip()
    return GetPrivateTooltip()
end

-- Tooltip wording varies between Blizzard and custom servers. Ascension drops the
-- possessive ("Equip: Improves hit rating by 2" where Blizzard says "...improves your
-- hit rating by 2") and uses Improves/Increases interchangeably. Rather than
-- duplicating every stat pattern for each phrasing, fold BOTH the tooltip line and
-- the patterns to one canonical form before matching. This is bidirectional: it fixes
-- patterns that require "your" against lines that omit it, AND patterns that omit it
-- against lines that include it.
local function NormalizeStatText(text)
    if not text then return text end
    text = text:gsub("[Ii]mproves", "Increases")   -- fold verb variants
    text = text:gsub("%s[Yy]our%s", " ")           -- drop the possessive
    text = text:gsub("%s%s+", " ")                 -- collapse repeated spaces
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

-- Normalized copy of ValuateStatPatterns, built once and cached (normalizing every
-- pattern on every tooltip line would be far too slow). Integer captures are also
-- widened to accept decimals, since scaled values aren't guaranteed to be whole.
local NormalizedStatPatterns = nil
local function GetNormalizedStatPatterns()
    if NormalizedStatPatterns then return NormalizedStatPatterns end
    if not ValuateStatPatterns then return nil end

    local built = {}
    for _, patternData in ipairs(ValuateStatPatterns) do
        local pattern = NormalizeStatText(patternData[1])
        -- (%d+) -> (%d+%.?%d*) so "2" and "2.5" both match. Patterns that already
        -- capture decimals (DPS/Speed) contain no literal "(%d+)" and are untouched.
        pattern = pattern:gsub("%(%%d%+%)", "(%%d+%%.?%%d*)")
        table.insert(built, { pattern, patternData[2] })
    end
    NormalizedStatPatterns = built
    return NormalizedStatPatterns
end

-- Parses stats from tooltip text using regex patterns
-- Returns a table with stat names as keys and values as numbers
function Valuate:ParseStatsFromTooltip(tooltipName, debug)
    local stats = {}
    local tooltip = _G[tooltipName]
    
    if not tooltip then
        return nil
    end
    
    -- Ensure stat patterns are loaded
    if not ValuateStatPatterns then
        print("|cFFFF0000Valuate|r: Stat patterns not loaded. Please reload UI.")
        return nil
    end
    
    local options = Valuate:GetOptions()
    debug = debug or (options.debug == true)
    
    -- Track weapon slot type for assigning type-specific DPS/Speed
    local weaponSlotType = nil  -- IsMainHand, IsOffHand, IsOneHand, IsTwoHand, IsRanged
    local isMelee = false
    local isRanged = false
    
    -- First pass: identify weapon/armor slot type and item level
    for i = 1, tooltip:NumLines() do
        local leftText = getglobal(tooltipName .. "TextLeft" .. i)
        local rightText = getglobal(tooltipName .. "TextRight" .. i)
        
        if leftText and leftText.GetText then
            local rawText = leftText:GetText() or ""
            local lineText = StripColorCodes(rawText)
            -- Trim stray outer whitespace so anchored (^...$) patterns still match.
            lineText = lineText:gsub("^%s+", ""):gsub("%s+$", "")

            -- Check for item level
            local itemLevel = string.match(lineText, "^Item Level (%d+)$")
            if itemLevel then
                stats["ItemLevel"] = tonumber(itemLevel)
                if debug then
                    print("|cFF00FF00[DEBUG]|r Item Level = " .. itemLevel)
                end
            end
            
            -- Check for weapon slot type (appears on left side)
            if ValuateWeaponSlotPatterns then
                for _, patternData in ipairs(ValuateWeaponSlotPatterns) do
                    if string.match(lineText, patternData[1]) then
                        weaponSlotType = patternData[2]
                        stats[patternData[2]] = 1
                        if debug then
                            print("|cFF00FF00[DEBUG]|r Weapon slot: " .. patternData[2])
                        end
                        -- Determine if melee or ranged
                        if patternData[2] == "IsRanged" then
                            isRanged = true
                        else
                            isMelee = true
                        end
                        break
                    end
                end
            end
        end
        
        -- Check right side for weapon type (e.g., "Sword", "Axe")
        if rightText and rightText.GetText then
            local rawRightText = rightText:GetText() or ""
            local rightLineText = StripColorCodes(rawRightText)
            -- Trim stray outer whitespace so anchored (^...$) patterns still match.
            rightLineText = rightLineText:gsub("^%s+", ""):gsub("%s+$", "")
            
            -- Check for weapon types
            if ValuateWeaponTypePatterns then
                for _, patternData in ipairs(ValuateWeaponTypePatterns) do
                    if string.match(rightLineText, patternData[1]) then
                        local statName = patternData[2]
                        -- Handle 2H weapon type conversion
                        if weaponSlotType == "IsTwoHand" then
                            if statName == "IsAxe" then statName = "Is2HAxe"
                            elseif statName == "IsMace" then statName = "Is2HMace"
                            elseif statName == "IsSword" then statName = "Is2HSword"
                            end
                        end
                        stats[statName] = 1
                        if debug then
                            print("|cFF00FF00[DEBUG]|r Weapon type: " .. statName)
                        end
                        break
                    end
                end
            end
            
            -- Check for armor types
            if ValuateArmorTypePatterns then
                for _, patternData in ipairs(ValuateArmorTypePatterns) do
                    if string.match(rightLineText, patternData[1]) then
                        stats[patternData[2]] = 1
                        if debug then
                            print("|cFF00FF00[DEBUG]|r Armor type: " .. patternData[2])
                        end
                        break
                    end
                end
            end
            
            -- Check for relic types
            if ValuateRelicTypePatterns then
                for _, patternData in ipairs(ValuateRelicTypePatterns) do
                    if string.match(rightLineText, patternData[1]) then
                        stats[patternData[2]] = 1
                        if debug then
                            print("|cFF00FF00[DEBUG]|r Relic type: " .. patternData[2])
                        end
                        break
                    end
                end
            end
        end
    end
    
    -- Second pass: parse regular stats
    for i = 1, tooltip:NumLines() do
        local leftText = getglobal(tooltipName .. "TextLeft" .. i)
        if leftText and leftText.GetText then
            local rawText = leftText:GetText() or ""
            local lineText = StripColorCodes(rawText)
            
            if debug then
                print("|cFF8888FF[DEBUG]|r Line " .. i .. ": '" .. lineText .. "'")
            end
            
            -- Try to match against each stat pattern
            if lineText and lineText ~= "" then
                -- Split by newlines in case multiple stats are in one GetText() result
                -- Some tooltips return multi-line strings from a single GetText() call
                local lines = {}
                for line in string.gmatch(lineText, "[^\r\n]+") do
                    table.insert(lines, line)
                end
                
                -- If no newlines found, process the original line
                if #lines == 0 then
                    table.insert(lines, lineText)
                end
                
                -- Process each line separately
                for _, line in ipairs(lines) do
                    local matched = false
                    -- Fast reject: every stat pattern captures a number, so a line with
                    -- no digit ("Soulbound", "Unique", "Binds when equipped") can't match
                    -- any of them. Skip the ~100-pattern loop and the normalize entirely.
                    if line:find("%d") then
                    -- Match against the canonical form so wording differences
                    -- ("your", Improves/Increases) don't need duplicate patterns.
                    local normalizedLine = NormalizeStatText(line)
                    local patterns = GetNormalizedStatPatterns() or ValuateStatPatterns
                    for _, patternData in ipairs(patterns) do
                        local pattern = patternData[1]
                        local statName = patternData[2]

                        local matches = {string.match(normalizedLine, pattern)}
                        if matches[1] then
                            local value = tonumber(matches[1])
                            if value then
                                stats[statName] = (stats[statName] or 0) + value
                                if debug then
                                    print("|cFF00FF00[DEBUG]|r Matched " .. statName .. " = " .. value .. " (pattern: " .. pattern .. ")")
                                end
                                matched = true
                                break  -- Found a match, move to next line
                            end
                        end
                    end
                    if debug and not matched then
                        print("|cFFFF8800[DEBUG]|r No pattern matched for: '" .. line .. "'")
                    end
                    end  -- close digit fast-reject
                end
            end
        end
    end

    -- Assign type-specific DPS and Speed based on weapon slot
    if stats["Dps"] then
        local dps = stats["Dps"]
        
        -- Assign to slot-specific DPS
        if stats["IsMainHand"] then
            stats["MainHandDps"] = dps
        end
        if stats["IsOffHand"] then
            stats["OffHandDps"] = dps
        end
        if stats["IsOneHand"] then
            stats["OneHandDps"] = dps
        end
        if stats["IsTwoHand"] then
            stats["TwoHandDps"] = dps
        end
        
        -- Assign to melee/ranged DPS
        if isMelee then
            stats["MeleeDps"] = dps
        end
        if isRanged or stats["IsRanged"] then
            stats["RangedDps"] = dps
        end
        
        if debug then
            print("|cFF00FF00[DEBUG]|r Assigned DPS to type-specific stats")
        end
    end
    
    if stats["Speed"] then
        local speed = stats["Speed"]
        
        -- Assign to melee/ranged Speed
        if isMelee then
            stats["MeleeSpeed"] = speed
        end
        if isRanged or stats["IsRanged"] then
            stats["RangedSpeed"] = speed
        end
        
        if debug then
            print("|cFF00FF00[DEBUG]|r Assigned Speed to type-specific stats")
        end
    end
    
    -- Calculate Feral AP from weapon DPS (for druids)
    -- Feral AP = (Weapon DPS - 54.8) * 14
    if stats["Dps"] and stats["IsStaff"] then
        local feralAP = math.floor((stats["Dps"] - 54.8) * 14)
        if feralAP > 0 then
            stats["FeralAP"] = feralAP
            if debug then
                print("|cFF00FF00[DEBUG]|r Calculated Feral AP = " .. feralAP)
            end
        end
    end
    
    return stats
end

-- Gets stats for an item link by parsing its tooltip
-- Returns a stats table, or nil if parsing fails
-- Note: For scaled items, this reads the base item stats, not scaled values
-- Scaled values are only available when reading from the actual displayed tooltip
function Valuate:GetStatsForItemLink(itemLink)
    if not itemLink or type(itemLink) ~= "string" then
        return nil
    end
    
    -- Parse tooltip from the item link
    -- Note: SetHyperlink uses base item data, not scaled values
    local tooltip = GetPrivateTooltip()
    if not tooltip then
        return nil
    end
    
    tooltip:ClearLines()
    local success = pcall(function() tooltip:SetHyperlink(itemLink) end)
    if not success then
        -- Invalid item link - SetHyperlink failed
        return nil
    end
    
    -- Parse the tooltip (note: this will show base stats, not scaled stats)
    local options = Valuate:GetOptions()
    local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip", options.debug)
    
    return stats
end

-- Gets stats directly from an already-displayed tooltip
-- This reads the actual tooltip text (includes scaled values)
-- tooltipName: Name of the tooltip frame (e.g., "GameTooltip")
function Valuate:GetStatsFromDisplayedTooltip(tooltipName)
    if not tooltipName then
        return nil
    end
    
    -- Parse the tooltip that's already displayed (this will have scaled values)
    return Valuate:ParseStatsFromTooltip(tooltipName)
end

-- ========================================
-- Tooltip Integration (Performance-Optimized)
-- ========================================

-- Helper function to extract item ID from item link
local function GetItemIdFromLink(itemLink)
    if not itemLink then return nil end
    local itemId = itemLink:match("item:(%d+):")
    return itemId and tonumber(itemId) or nil
end

-- Weapon subtypes that are profession tools / non-combat gear Valuate should
-- never score, display, track, or filter on: fishing poles and the tool weapons
-- (mining picks, skinning knives, blacksmith hammers, engineering tools, etc.,
-- which the game files under the "Miscellaneous" weapon subtype).
-- IMPORTANT: keyed off itemType == "Weapon" so ARMOR/"Miscellaneous" items
-- (caster held-in-off-hand tomes/orbs, which are real gear) are NOT excluded.
-- Subtypes are localized; these are the enUS values (Ascension is enUS).
local EXCLUDED_WEAPON_SUBTYPES = {
    ["Fishing Poles"] = true,
    ["Fishing Pole"] = true,   -- singular, seen on some clients
    ["Miscellaneous"] = true,  -- mining pick / skinning knife / blacksmith hammer / etc.
}

-- Returns true if Valuate should ignore this item entirely - no score, no
-- tooltip lines, not tracked as best equipment, not matched by loot filters.
-- Controlled by the ignoreProfessionTools option (on by default). Central gate
-- reused by the tooltip, scan, quest, and PassLoot paths.
-- Memoized "is this a profession-tool weapon type" fact, keyed by itemId. The fact
-- is item-intrinsic (a fishing pole is always a fishing pole), so it never needs
-- invalidating; the user's option is checked outside the cache. This matters because
-- the tooltip OnUpdate hook calls this every frame while hovering, and GetItemInfo
-- isn't free.
local professionToolCache = {}

-- Purely cosmetic slots. These never carry stats, so scoring them produces a
-- meaningless number on every tabard and shirt tooltip. Excluded unconditionally -
-- unlike profession tools, this has nothing to do with the ignoreProfessionTools
-- option, so it must not be gated behind it.
local COSMETIC_EQUIP_LOCS = {
    ["INVTYPE_TABARD"] = true,
    ["INVTYPE_BODY"] = true,   -- shirt
}
-- Separate from professionToolCache on purpose: this answer depends only on the
-- item, whereas the profession-tool answer depends on a setting the user can
-- toggle, and the two must not share a cache entry.
local cosmeticSlotCache = {}
function Valuate:IsItemExcludedFromEvaluation(itemLink)
    if not itemLink then return false end

    local cosmeticId = GetItemIdFromLink(itemLink)
    local knownCosmetic = cosmeticId and cosmeticSlotCache[cosmeticId]
    if knownCosmetic ~= nil then
        if knownCosmetic then return true end
    else
        local equipLoc = select(9, GetItemInfo(itemLink))
        if equipLoc then  -- nil means not cached yet; don't memoize a guess
            local isCosmetic = COSMETIC_EQUIP_LOCS[equipLoc] and true or false
            if cosmeticId then cosmeticSlotCache[cosmeticId] = isCosmetic end
            if isCosmetic then return true end
        end
    end

    if Valuate:GetOptions().ignoreProfessionTools == false then
        return false
    end
    local itemId = GetItemIdFromLink(itemLink)
    if itemId then
        local cached = professionToolCache[itemId]
        if cached ~= nil then return cached end
    end
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    if not itemType then
        -- Item not cached yet; don't memoize a premature answer.
        return false
    end
    local result = (itemType == "Weapon" and itemSubType and EXCLUDED_WEAPON_SUBTYPES[itemSubType]) and true or false
    if itemId then professionToolCache[itemId] = result end
    return result
end

-- Classes that can dual-wield by default (best-effort fallback; Ascension is
-- classless, so this is only used when the more reliable signals below fail).
local DUAL_WIELD_DEFAULT = {
    WARRIOR = true, ROGUE = true, HUNTER = true, SHAMAN = true, DEATHKNIGHT = true,
}

-- Returns true if the character can wield a one-hand weapon in the off-hand.
-- Used so the best-equipment scan doesn't recommend a 1H weapon for the off-hand
-- slot on characters who can't dual-wield (e.g. casters/tanks). Layered detection:
--   1. a native API if the client provides one,
--   2. currently having an off-hand weapon equipped (proof positive),
--   3. class default (unreliable under Ascension's classless system).
-- Dedicated off-hands - shields, held-in-off-hand, and off-hand-only weapons -
-- are unaffected; only generic INVTYPE_WEAPON items are gated by this.
function Valuate:CanDualWield()
    if type(CanDualWield) == "function" then
        local ok, res = pcall(CanDualWield)
        if ok and res ~= nil then return res and true or false end
    end
    if type(IsDualWielding) == "function" then
        local ok, res = pcall(IsDualWielding)
        if ok and res then return true end
    end
    -- Proof positive: an off-hand weapon is currently equipped.
    local offLink = GetInventoryItemLink("player", 17)
    if offLink then
        local _, _, _, _, _, _, _, _, offLoc = GetItemInfo(offLink)
        if offLoc == "INVTYPE_WEAPONOFFHAND" or offLoc == "INVTYPE_WEAPON"
           or offLoc == "INVTYPE_WEAPONMAINHAND" then
            return true
        end
    end
    -- Ascension is classless: the Dual Wield passive (spell 674) is learnable by
    -- anyone, so knowing it is far more reliable than a class default table.
    if type(IsSpellKnown) == "function" then
        local ok, known = pcall(IsSpellKnown, 674)
        if ok and known then return true end
    end
    local _, class = UnitClass("player")
    return DUAL_WIELD_DEFAULT[class] or false
end

-- Track current item and whether we've added our lines
local CurrentTooltipItem = nil
local CurrentTooltipStats = nil
local ValuateLinesAdded = false
-- Tracked separately from ValuateLinesAdded: the junk verdict is added independently of
-- the score lines, and the tooltip refresh runs every frame - without its own flag the
-- line would be appended sixty times a second.
local ValuateJunkLineAdded = false
-- Cached border color for the current hovered item, computed once per item
-- instead of every OnUpdate frame. nil = not computed yet; false = "no coloring";
-- otherwise a {r, g, b} table.
local CurrentTooltipBorderColor = nil

-- Store default tooltip border colors
local DefaultTooltipBorderColor = nil

-- Unique marker for detecting Valuate lines in tooltips (nearly invisible color code)
local VALUATE_MARKER = "|cFF000001"
local VALUATE_MARKER_FULL = "|cFF000001|r"

-- Determine tooltip border color based on displayed scale
-- Returns r, g, b values (0-1 range) or nil if no coloring should be applied
local function GetTooltipBorderColor(stats, itemLink)
    -- Check if a character window scale is selected
    local scaleName = Valuate:GetOptions().characterWindowScale
    if not scaleName or scaleName == "" then
        return nil  -- No scale selected, use default border
    end
    
    -- Get the scale data
    local scale = Valuate:GetScales()[scaleName]
    if not scale or not scale.Values then
        return nil  -- Invalid scale
    end
    
    -- Check if item is equippable
    local equipSlot = nil
    if itemLink then
        local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
        equipSlot = itemEquipLoc
    end
    
    if not equipSlot or equipSlot == "" then
        return nil  -- Non-equippable item, use default border
    end
    
    -- Check if item has any stats marked as unusable (banned) for this scale
    if scale.Unusable then
        -- First check parsed stats
        for statName, statValue in pairs(stats) do
            if scale.Unusable[statName] and statValue and statValue > 0 then
                return nil  -- Item has banned stat, use default border
            end
        end
        
        -- Also check equipment slot type directly (in case tooltip parsing missed weapon type)
        if equipSlot then
            if (equipSlot == "INVTYPE_WEAPON" or equipSlot == "INVTYPE_WEAPONMAINHAND") and scale.Unusable["OneHandDps"] then
                return nil  -- Item is 1H weapon (banned), use default border
            elseif equipSlot == "INVTYPE_2HWEAPON" and scale.Unusable["TwoHandDps"] then
                return nil  -- Item is 2H weapon (banned), use default border
            elseif equipSlot == "INVTYPE_WEAPONOFFHAND" and scale.Unusable["OffHandDps"] then
                return nil  -- Item is offhand weapon (banned), use default border
            elseif (equipSlot == "INVTYPE_RANGED" or equipSlot == "INVTYPE_RANGEDRIGHT" or equipSlot == "INVTYPE_THROWN") and scale.Unusable["RangedDps"] then
                return nil  -- Item is ranged weapon (banned), use default border
            end
        end
    end
    
    -- Calculate item score
    local score = Valuate:CalculateItemScore(stats, scale)
    if not score or score <= 0 then
        return nil  -- No score, use default border
    end
    
    -- Get equipped item score for comparison
    local equippedScore = nil
    
    -- Try to get equipped score from shopping tooltip first (if comparing items)
    if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
        local stName, stLink = ShoppingTooltip1:GetItem(); local equippedItemLink = stLink or stName
        if equippedItemLink then
            local _, _, _, _, _, _, _, _, shoppingEquipLoc = GetItemInfo(equippedItemLink)
            -- Check if items are comparable (uses smart weapon comparison logic)
            if shoppingEquipLoc and AreWeaponTypesComparable(equipSlot, shoppingEquipLoc) then
                local equippedStats = Valuate:GetStatsFromDisplayedTooltip("ShoppingTooltip1")
                if equippedStats then
                    equippedScore = Valuate:CalculateItemScore(equippedStats, scale)
                end
            end
        end
    end
    
    -- Fall back to getting equipped score the normal way
    if not equippedScore then
        equippedScore = Valuate:GetEquippedItemScore(equipSlot, scale)
    end
    
    if not equippedScore then
        return nil  -- No equipped item to compare, use default border
    end
    
    -- Determine border color based on comparison
    local diff = score - equippedScore
    
    if diff > 0 then
        return 0, 1, 0  -- Green for upgrades
    elseif diff < 0 then
        return 1, 0, 0  -- Red for downgrades
    else
        return nil  -- Equal scores - use default border
    end
end

-- Check if our Valuate lines are present in the tooltip
local function HasValuateLines(tooltip)
    if not tooltip then return false end
    local numLines = tooltip:NumLines()
    for i = 1, numLines do
        local leftText = getglobal(tooltip:GetName() .. "TextLeft" .. i)
        if leftText then
            local text = leftText:GetText()
            if text and text:find(VALUATE_MARKER, 1, true) then
                return true
            end
        end
    end
    return false
end

-- Helper function to format percentage comparison text
-- Returns formatted text string with color codes
local function FormatPercentageComparison(diff, equippedScore, formatStr, compMode)
    if not equippedScore or equippedScore == 0 then
        -- Can't calculate percentage, return number only or "new"
        local diffColor = diff > 0 and "|cFF00FF00" or (diff < 0 and "|cFFFF0000" or "|cFFFFFF00")
        local diffSign = diff > 0 and "+" or ""
        local diffText = string.format(formatStr, diff)
        if equippedScore == 0 then
            return " " .. diffColor .. "(" .. diffSign .. diffText .. ")|r"
        else
            return " " .. diffColor .. "(new)|r"
        end
    end
    
    -- Calculate percentage.
    --
    -- Divided by the MAGNITUDE, so the sign of the percentage comes from the change and
    -- not from the baseline. Scales may hold negative weights - the weight box keeps a
    -- leading minus on purpose - so an equipped item can score below zero, and dividing
    -- by a negative score flips the sign. Going from -10 to -5 is an improvement, and the
    -- raw division reports it as -50%: the caller has already chosen a green "+" from
    -- `diff`, so the tooltip printed "+-50.0%" in green.
    --
    -- CalculateStatBreakdownWithComparison has always done it this way for the per-stat
    -- lines. This is the same computation in the same tooltip disagreeing with itself.
    local percent = (diff / math.abs(equippedScore)) * 100
    local diffColor = diff > 0 and "|cFF00FF00" or (diff < 0 and "|cFFFF0000" or "|cFFFFFF00")
    local diffSign = diff > 0 and "+" or ""
    local diffText = string.format(formatStr, diff)
    
    -- Handle extreme percentages.
    --
    -- HUGE! needs its OWN sign. `diffSign` is empty for a loss on the convention that the
    -- formatted number already carries the minus - true everywhere else here, and false in
    -- this branch, because there is no number. A catastrophic downgrade therefore rendered
    -- as "(HUGE!)", distinguishable from a huge gain's "(+HUGE!)" only by the absent plus
    -- and the colour. On the one line the addon prints for every item, "HUGE!" reads as
    -- good news.
    local hugeSign = diff > 0 and "+" or (diff < 0 and "-" or "")
    if math.abs(percent) >= 1000 then
        if compMode == "both" then
            return " " .. diffColor .. "(" .. diffSign .. diffText .. ", " .. hugeSign .. "HUGE!)|r"
        else
            return " " .. diffColor .. "(" .. hugeSign .. "HUGE!)|r"
        end
    end
    
    local percentText = string.format("%.1f", percent)
    if compMode == "percent" then
        return " " .. diffColor .. "(" .. diffSign .. percentText .. "%)|r"
    elseif compMode == "both" then
        return " " .. diffColor .. "(" .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%)|r"
    else
        -- Default to number
        return " " .. diffColor .. "(" .. diffSign .. diffText .. ")|r"
    end
end

-- Add score lines to tooltip
local function AddScoreLinesToTooltip(tooltip, stats, itemLink)
    if not tooltip or not stats then return end

    -- Never score profession tools / fishing poles (central gate)
    if itemLink and Valuate:IsItemExcludedFromEvaluation(itemLink) then return end

    -- Get active scales
    local activeScales = Valuate:GetActiveScales()
    if #activeScales == 0 then return end
    
    -- Get the item's equipment slot for comparison
    local equipSlot = nil
    if itemLink then
        local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
        equipSlot = itemEquipLoc
    end
    
    -- Check if this is a multi-slot item type (rings, trinkets, 1H weapons)
    local isMultiSlot = (equipSlot == "INVTYPE_FINGER" or equipSlot == "INVTYPE_TRINKET" or equipSlot == "INVTYPE_WEAPON")
    
    local options = Valuate:GetOptions()
    local scales = Valuate:GetScales()
    
    -- Add "Best for" line at the TOP if player owns the item and it's best for any scales
    local hasScores = false
    if itemLink and options.showBestFor ~= false then
        local ownsItem = Valuate:PlayerOwnsItem(itemLink)
        if ownsItem then
            -- Qualified line, e.g. "★ Best two-hander for: Retribution" (weapons) or
            -- "★ Best for: Retribution" (everything else).
            local bestForLine = Valuate:BuildBestForLine(itemLink)
            if bestForLine then
                tooltip:AddLine(" ")  -- Blank line before "Best for"
                tooltip:AddLine(VALUATE_MARKER_FULL .. " " .. bestForLine, nil, nil, nil, true)
                hasScores = true  -- Mark that we've added lines
            end

            -- An item is either best-in-slot or a future upgrade, never both -
            -- equippability is item-intrinsic - so these two lines cannot both appear.
            local futureLine = Valuate:BuildFutureLine(itemLink)
            if futureLine then
                if not bestForLine then tooltip:AddLine(" ") end
                tooltip:AddLine(VALUATE_MARKER_FULL .. " " .. futureLine, nil, nil, nil, true)
                hasScores = true
            end
        end
    end
    
    -- Determine current scale for "current" mode
    local currentScaleName = nil
    if options.showScaleValue == "current" then
        -- Use characterWindowScale if set and active, otherwise use first active scale
        if options.characterWindowScale then
            for _, scaleName in ipairs(activeScales) do
                if scaleName == options.characterWindowScale then
                    currentScaleName = scaleName
                    break
                end
            end
        end
        -- Fall back to first active scale if characterWindowScale is not set or not active
        if not currentScaleName and #activeScales > 0 then
            currentScaleName = activeScales[1]
        end
    end
    
    -- Calculate and display scores
    for _, scaleName in ipairs(activeScales) do
        local scale = scales[scaleName]
        if scale then
            -- Skip this scale if we're in "current" mode and this isn't the current scale
            if not (options.showScaleValue == "current" and scaleName ~= currentScaleName) then
            
            -- Check if item has any stats marked as unusable (banned) for this scale
            local hasUnusableStat = false
            if scale.Unusable then
                -- First check parsed stats
                for statName, statValue in pairs(stats) do
                    if scale.Unusable[statName] and statValue and statValue > 0 then
                        hasUnusableStat = true
                        if options.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item has banned stat '" .. statName .. "'")
                        end
                        break
                    end
                end
                
                -- Also check equipment slot type directly (in case tooltip parsing missed weapon type)
                if not hasUnusableStat and equipSlot then
                    if (equipSlot == "INVTYPE_WEAPON" or equipSlot == "INVTYPE_WEAPONMAINHAND") and scale.Unusable["OneHandDps"] then
                        hasUnusableStat = true
                        if options.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is 1H weapon (banned by OneHandDps)")
                        end
                    elseif equipSlot == "INVTYPE_2HWEAPON" and scale.Unusable["TwoHandDps"] then
                        hasUnusableStat = true
                        if options.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is 2H weapon (banned by TwoHandDps)")
                        end
                    elseif equipSlot == "INVTYPE_WEAPONOFFHAND" and scale.Unusable["OffHandDps"] then
                        hasUnusableStat = true
                        if options.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is offhand weapon (banned by OffHandDps)")
                        end
                    elseif (equipSlot == "INVTYPE_RANGED" or equipSlot == "INVTYPE_RANGEDRIGHT" or equipSlot == "INVTYPE_THROWN") and scale.Unusable["RangedDps"] then
                        hasUnusableStat = true
                        if options.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is ranged weapon (banned by RangedDps)")
                        end
                    end
                end
            end
            
            -- Only show score if no banned stats found on this item
            if not hasUnusableStat then
                local score = Valuate:CalculateItemScore(stats, scale)
                if score and score > 0 then
                    -- Check if user wants to show scale values
                    local showValue = options.showScaleValue == "all" or options.showScaleValue == "current"
                    
                    -- Only display scale info if showValue is enabled
                    if showValue then
                        if not hasScores then
                            tooltip:AddLine(" ")
                            hasScores = true
                        end
                        local color = scale.Color or "FFFFFF"
                        local displayName = scale.DisplayName or scaleName
                        local decimals = options.decimalPlaces or 1
                        local formatStr = "%." .. decimals .. "f"
                        local scoreText = string.format(formatStr, score)
                        
                        -- Build the display text based on options
                        local compMode = options.comparisonMode or "number"
                        local comparisonText = ""
                    
                    -- Build icon prefix based on scale's Icon setting
                    local prefix = VALUATE_MARKER_FULL
                    local icon = scale.Icon
                    if icon and icon ~= "" then
                        prefix = prefix .. "|T" .. icon .. ":0|t "
                    end
                    
                    -- Show detailed stat breakdown if enabled
                    if options.showStatBreakdown then
                        -- Check if this is a multi-slot item for per-slot breakdown
                        -- Only show multi-slot breakdown on hover tooltips (itemLink provided), not shopping tooltips
                        local isMultiSlotBreakdown = isMultiSlot and compMode ~= "off" and itemLink
                        
                        -- For non-multi-slot items, show breakdown once
                        if not isMultiSlotBreakdown then
                            -- Try to get equipped item stats for comparison
                            -- Only compare if itemLink is provided (hover tooltip), not for shopping tooltips (itemLink is nil)
                            local equippedStats = nil
                            if itemLink and equipSlot and equipSlot ~= "" then
                                -- Try shopping tooltip first for context
                                if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
                                    local stName, stLink = ShoppingTooltip1:GetItem(); local equippedItemLink = stLink or stName
                                    if equippedItemLink then
                                        local _, _, _, _, _, _, _, _, shoppingEquipLoc = GetItemInfo(equippedItemLink)
                                        if shoppingEquipLoc and AreWeaponTypesComparable(equipSlot, shoppingEquipLoc) then
                                            equippedStats = Valuate:GetStatsFromDisplayedTooltip("ShoppingTooltip1")
                                        end
                                    end
                                end
                                
                                -- Fall back to getting equipped item stats the normal way
                                if not equippedStats then
                                    local invSlots = EquipSlotToInvNumber[equipSlot]
                                    if invSlots then
                                        for _, slotId in ipairs(invSlots) do
                                            local itemLink = GetInventoryItemLink("player", slotId)
                                            if itemLink then
                                                local _, _, _, _, _, _, _, _, equippedEquipLoc = GetItemInfo(itemLink)
                                                if equippedEquipLoc and AreWeaponTypesComparable(equipSlot, equippedEquipLoc) then
                                                    local tooltip = GetPrivateTooltip()
                                                    tooltip:ClearLines()
                                                    tooltip:SetInventoryItem("player", slotId)
                                                    equippedStats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                                                    break  -- Use first comparable equipped item
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            
                            -- Use comparison breakdown if we have equipped stats
                            local breakdown
                            if equippedStats then
                                breakdown = Valuate:CalculateStatBreakdownWithComparison(stats, equippedStats, scale)
                            else
                                breakdown = Valuate:CalculateStatBreakdown(stats, scale)
                            end
                        
                            if breakdown and #breakdown > 0 then
                                -- Display scale name as header for the breakdown
                                tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ":|r")
                            
                            -- Track totals for the summary line
                            local totalHoverContrib = 0
                            local totalEquippedContrib = 0
                            
                            -- Display each stat contribution
                            for _, entry in ipairs(breakdown) do
                                local statDisplayName = ValuateStatNames[entry.statName] or entry.statName
                                
                                if equippedStats and entry.equippedValue and compMode ~= "off" then
                                    -- With comparison (only if comparison mode is enabled)
                                    local hoverValueText = string.format(formatStr, entry.hoverValue)
                                    local weightText = string.format(formatStr, entry.hoverWeight)
                                    local hoverContribText = string.format(formatStr, entry.hoverContribution)
                                    local equippedContribText = string.format(formatStr, entry.equippedContribution)
                                    local diffText = string.format(formatStr, entry.diff)
                                    local percentText = string.format("%.1f", entry.percentDiff)
                                    
                                    -- Add to totals
                                    totalHoverContrib = totalHoverContrib + entry.hoverContribution
                                    totalEquippedContrib = totalEquippedContrib + entry.equippedContribution
                                    
                                    -- Determine color for the difference values only
                                    local diffColor
                                    local diffSign = ""
                                    if entry.diff > 0 then
                                        diffColor = "00FF00"  -- Green for upgrade
                                        diffSign = "+"
                                    elseif entry.diff < 0 then
                                        diffColor = "FF0000"  -- Red for downgrade
                                        diffSign = ""  -- Negative sign already in number
                                    else
                                        diffColor = "FFFF00"  -- Yellow for no change (matches original scale comparison)
                                        diffSign = ""
                                    end
                                    
                                    -- Build comparison text based on comparison mode
                                    local comparisonPart = ""
                                    if compMode == "number" then
                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. diffText .. "|r|cFF" .. color .. ")"
                                    elseif compMode == "percent" then
                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. percentText .. "%|r|cFF" .. color .. ")"
                                    elseif compMode == "both" then
                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%|r|cFF" .. color .. ")"
                                    end
                                    
                                    -- Format: "  Stat: hoverValue × weight = hoverContrib (comparison)"
                                    -- Only show the hover item's value, not the equipped item's value
                                    if options.rightAlign then
                                        -- Right-aligned: split into left and right parts
                                        local leftPart = "  " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                            hoverValueText .. " × " .. weightText .. "|r"
                                        local rightPart = "|cFF" .. color .. hoverContribText .. comparisonPart .. "|r"
                                        tooltip:AddDoubleLine(leftPart, rightPart)
                                    else
                                        -- Normal: single line
                                        local breakdownLine = "  " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                            hoverValueText .. " × " .. weightText .. " = " .. hoverContribText .. 
                                            comparisonPart .. "|r"
                                        tooltip:AddLine(breakdownLine)
                                    end
                                else
                                    -- Without comparison (no equipped item or comparison mode is "off")
                                    local statValueText = string.format(formatStr, entry.statValue or entry.hoverValue)
                                    local weightText = string.format(formatStr, entry.weight or entry.hoverWeight)
                                    local contributionText = string.format(formatStr, entry.contribution or entry.hoverContribution)
                                    
                                    -- Add to total (no comparison)
                                    totalHoverContrib = totalHoverContrib + (entry.contribution or entry.hoverContribution)
                                    
                                    if options.rightAlign then
                                        -- Right-aligned: split into left and right parts
                                        local leftPart = "  " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                            statValueText .. " × " .. weightText .. "|r"
                                        local rightPart = "|cFF" .. color .. contributionText .. "|r"
                                        tooltip:AddDoubleLine(leftPart, rightPart)
                                    else
                                        -- Normal: single line
                                        local breakdownLine = "  " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                            statValueText .. " × " .. weightText .. " = " .. contributionText .. "|r"
                                        tooltip:AddLine(breakdownLine)
                                    end
                                end
                            end
                            
                            -- Display total line
                            if equippedStats and compMode ~= "off" then
                                -- With comparison - only show hover item's total with comparison
                                local totalHoverText = string.format(formatStr, totalHoverContrib)
                                local totalEquippedText = string.format(formatStr, totalEquippedContrib)
                                local totalDiff = totalHoverContrib - totalEquippedContrib
                                local totalDiffText = string.format(formatStr, totalDiff)
                                local totalPercentDiff = 0
                                if totalEquippedContrib ~= 0 then
                                    totalPercentDiff = (totalDiff / math.abs(totalEquippedContrib)) * 100
                                elseif totalDiff ~= 0 then
                                    totalPercentDiff = (totalDiff > 0) and 100 or -100
                                end
                                local totalPercentText = string.format("%.1f", totalPercentDiff)
                                
                                -- Determine color for total difference
                                local totalDiffColor
                                local totalDiffSign = ""
                                if totalDiff > 0 then
                                    totalDiffColor = "00FF00"
                                    totalDiffSign = "+"
                                elseif totalDiff < 0 then
                                    totalDiffColor = "FF0000"
                                    totalDiffSign = ""
                                else
                                    totalDiffColor = "FFFF00"  -- Yellow for no change (matches original scale comparison)
                                    totalDiffSign = ""
                                end
                                
                                -- Build total comparison text.
                                -- The equipped total is shown explicitly. It was previously
                                -- computed and discarded, which made the percentage
                                -- impossible to interpret: it is a percentage OF the equipped
                                -- score, so two items compared while wearing different gear
                                -- produce percentages that can't be compared to each other -
                                -- a smaller upgrade over weak boots reads higher than a bigger
                                -- upgrade over good ones.
                                local vsPart = " |cFFAAAAAAvs " .. totalEquippedText .. "|r|cFF" .. color .. ""
                                local totalComparisonPart = ""
                                if compMode == "number" then
                                    totalComparisonPart = vsPart .. " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalDiffText .. "|r|cFF" .. color .. ")"
                                elseif compMode == "percent" then
                                    totalComparisonPart = vsPart .. " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalPercentText .. "%|r|cFF" .. color .. ")"
                                elseif compMode == "both" then
                                    totalComparisonPart = vsPart .. " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalDiffText .. ", " .. totalDiffSign .. totalPercentText .. "%|r|cFF" .. color .. ")"
                                end
                                
                                if options.rightAlign then
                                    local leftPart = "  " .. prefix .. "|cFF" .. color .. "Total:|r"
                                    local rightPart = "|cFF" .. color .. totalHoverText .. totalComparisonPart .. "|r"
                                    tooltip:AddDoubleLine(leftPart, rightPart)
                                else
                                    local totalLine = "  " .. prefix .. "|cFF" .. color .. "Total: " .. totalHoverText .. 
                                        totalComparisonPart .. "|r"
                                    tooltip:AddLine(totalLine)
                                end
                            else
                                -- Without comparison
                                local totalText = string.format(formatStr, totalHoverContrib)
                                if options.rightAlign then
                                    local leftPart = "  " .. prefix .. "|cFF" .. color .. "Total:|r"
                                    local rightPart = "|cFF" .. color .. totalText .. "|r"
                                    tooltip:AddDoubleLine(leftPart, rightPart)
                                else
                                    local totalLine = "  " .. prefix .. "|cFF" .. color .. "Total: " .. totalText .. "|r"
                                    tooltip:AddLine(totalLine)
                                end
                            end
                            end
                        end
                    end
                    
                    -- Calculate comparison if enabled and item is equippable
                    -- Only show multi-slot breakdown on hover tooltips (itemLink provided), not shopping tooltips
                    if compMode ~= "off" and equipSlot and equipSlot ~= "" and isMultiSlot and itemLink and showValue then
                        -- For multi-slot items, show individual comparisons
                        local equippedScores = Valuate:GetEquippedItemScores(equipSlot, scale)
                        
                        if equippedScores and next(equippedScores) then
                            -- Add scale name header (only once at the top)
                            if options.showStatBreakdown then
                                tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ":|r")
                            elseif showValue then
                                -- Show main line with item score (old behavior when breakdown is off)
                                if options.rightAlign then
                                    tooltip:AddDoubleLine(prefix .. "|cFF" .. color .. displayName .. "|r", "|cFF" .. color .. scoreText .. "|r")
                                else
                                    tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r")
                                end
                            end
                            
                            -- Add individual comparison lines for each equipped item
                            for slotId, equippedScore in pairs(equippedScores) do
                                local slotName = SlotIdToName[slotId] or ("Slot " .. slotId)
                                local diff = score - equippedScore
                                local diffColor = ""
                                local diffSign = ""
                                
                                if diff > 0 then
                                    diffColor = "|cFF00FF00"
                                    diffSign = "+"
                                elseif diff < 0 then
                                    diffColor = "|cFFFF0000"
                                    diffSign = ""
                                else
                                    diffColor = "|cFFFFFF00"
                                    diffSign = ""
                                end
                                
                                local diffText = string.format(formatStr, diff)
                                local slotComparisonText = ""
                                
                                if compMode == "number" then
                                    slotComparisonText = diffColor .. diffSign .. diffText .. "|r"
                                elseif compMode == "percent" then
                                    if equippedScore > 0 then
                                        local percent = (diff / equippedScore) * 100
                                        local percentText
                                        if math.abs(percent) >= 1000 then
                                            percentText = "HUGE!"
                                            slotComparisonText = diffColor .. diffSign .. percentText .. "|r"
                                        else
                                            percentText = string.format("%.1f", percent)
                                            slotComparisonText = diffColor .. diffSign .. percentText .. "%|r"
                                        end
                                    else
                                        slotComparisonText = diffColor .. "new|r"
                                    end
                                elseif compMode == "both" then
                                    if equippedScore > 0 then
                                        local percent = (diff / equippedScore) * 100
                                        local percentText
                                        if math.abs(percent) >= 1000 then
                                            percentText = "HUGE!"
                                            slotComparisonText = diffColor .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "|r"
                                        else
                                            percentText = string.format("%.1f", percent)
                                            slotComparisonText = diffColor .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%|r"
                                        end
                                    else
                                        slotComparisonText = diffColor .. diffSign .. diffText .. ", new|r"
                                    end
                                end
                                
                                -- Add slot comparison line (only if showValue is true)
                                if showValue then
                                    if options.rightAlign then
                                        tooltip:AddDoubleLine("  " .. prefix .. "|cFF" .. color .. slotName .. "|r", slotComparisonText)
                                    else
                                        tooltip:AddLine("  " .. prefix .. "|cFF" .. color .. slotName .. ": " .. slotComparisonText .. "|r")
                                    end
                                end
                                
                                -- Add stat breakdown for this specific equipped item if enabled
                                if options.showStatBreakdown then
                                    -- Get stats for this specific equipped item
                                    local itemLink = GetInventoryItemLink("player", slotId)
                                    if itemLink then
                                        local equipTooltip = GetPrivateTooltip()
                                        equipTooltip:ClearLines()
                                        equipTooltip:SetInventoryItem("player", slotId)
                                        local slotEquippedStats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                                        
                                        if slotEquippedStats then
                                            local slotBreakdown = Valuate:CalculateStatBreakdownWithComparison(stats, slotEquippedStats, scale)
                                            
                                            if slotBreakdown and #slotBreakdown > 0 then
                                                local slotTotalHover = 0
                                                local slotTotalEquipped = 0
                                                
                                                -- Display each stat for this slot
                                                for _, entry in ipairs(slotBreakdown) do
                                                    local statDisplayName = ValuateStatNames[entry.statName] or entry.statName
                                                    local hoverValueText = string.format(formatStr, entry.hoverValue)
                                                    local weightText = string.format(formatStr, entry.hoverWeight)
                                                    local hoverContribText = string.format(formatStr, entry.hoverContribution)
                                                    local equippedContribText = string.format(formatStr, entry.equippedContribution)
                                                    local diffText = string.format(formatStr, entry.diff)
                                                    local percentText = string.format("%.1f", entry.percentDiff)
                                                    
                                                    slotTotalHover = slotTotalHover + entry.hoverContribution
                                                    slotTotalEquipped = slotTotalEquipped + entry.equippedContribution
                                                    
                                                    -- Determine color for difference
                                                    local diffColor, diffSign = "", ""
                                                    if entry.diff > 0 then
                                                        diffColor = "00FF00"
                                                        diffSign = "+"
                                                    elseif entry.diff < 0 then
                                                        diffColor = "FF0000"
                                                        diffSign = ""
                                                    else
                                                        diffColor = "FFFF00"  -- Yellow for no change (matches original scale comparison)
                                                        diffSign = ""
                                                    end
                                                    
                                                    -- Build comparison text
                                                    local comparisonPart = ""
                                                    if compMode == "number" then
                                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. diffText .. "|r|cFF" .. color .. ")"
                                                    elseif compMode == "percent" then
                                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. percentText .. "%|r|cFF" .. color .. ")"
                                                    elseif compMode == "both" then
                                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%|r|cFF" .. color .. ")"
                                                    end
                                                    
                                                    -- Display stat line (indented more) - only show hover item's value
                                                    if options.rightAlign then
                                                        local leftPart = "    " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                                            hoverValueText .. " × " .. weightText .. "|r"
                                                        local rightPart = "|cFF" .. color .. hoverContribText .. comparisonPart .. "|r"
                                                        tooltip:AddDoubleLine(leftPart, rightPart)
                                                    else
                                                        local breakdownLine = "    " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                                            hoverValueText .. " × " .. weightText .. " = " .. hoverContribText .. 
                                                            comparisonPart .. "|r"
                                                        tooltip:AddLine(breakdownLine)
                                                    end
                                                end
                                                
                                                -- Display total for this slot
                                                local totalHoverText = string.format(formatStr, slotTotalHover)
                                                local totalEquippedText = string.format(formatStr, slotTotalEquipped)
                                                local totalDiff = slotTotalHover - slotTotalEquipped
                                                local totalDiffText = string.format(formatStr, totalDiff)
                                                local totalPercentDiff = 0
                                                if slotTotalEquipped ~= 0 then
                                                    totalPercentDiff = (totalDiff / math.abs(slotTotalEquipped)) * 100
                                                elseif totalDiff ~= 0 then
                                                    totalPercentDiff = (totalDiff > 0) and 100 or -100
                                                end
                                                local totalPercentText = string.format("%.1f", totalPercentDiff)
                                                
                                                local totalDiffColor, totalDiffSign = "", ""
                                                if totalDiff > 0 then
                                                    totalDiffColor = "00FF00"
                                                    totalDiffSign = "+"
                                                elseif totalDiff < 0 then
                                                    totalDiffColor = "FF0000"
                                                    totalDiffSign = ""
                                                else
                                                    totalDiffColor = "FFFF00"  -- Yellow for no change (matches original scale comparison)
                                                    totalDiffSign = ""
                                                end
                                                
                                                -- Same reasoning as the single-slot block above:
                                                -- show what the percentage is a percentage OF.
                                                local vsPart = " |cFFAAAAAAvs " .. totalEquippedText .. "|r|cFF" .. color .. ""
                                                local totalComparisonPart = ""
                                                if compMode == "number" then
                                                    totalComparisonPart = vsPart .. " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalDiffText .. "|r|cFF" .. color .. ")"
                                                elseif compMode == "percent" then
                                                    totalComparisonPart = vsPart .. " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalPercentText .. "%|r|cFF" .. color .. ")"
                                                elseif compMode == "both" then
                                                    totalComparisonPart = vsPart .. " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalDiffText .. ", " .. totalDiffSign .. totalPercentText .. "%|r|cFF" .. color .. ")"
                                                end
                                                
                                                if options.rightAlign then
                                                    local leftPart = "    " .. prefix .. "|cFF" .. color .. "Total:|r"
                                                    local rightPart = "|cFF" .. color .. totalHoverText .. totalComparisonPart .. "|r"
                                                    tooltip:AddDoubleLine(leftPart, rightPart)
                                                else
                                                    local totalLine = "    " .. prefix .. "|cFF" .. color .. "Total: " .. totalHoverText .. 
                                                        totalComparisonPart .. "|r"
                                                    tooltip:AddLine(totalLine)
                                                end
                                                
                                                -- Add blank line between slots for readability
                                                tooltip:AddLine(" ")
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            -- No equipped items in these slots (skip if stat breakdown already shown)
                            if showValue and not options.showStatBreakdown then
                                if options.rightAlign then
                                    tooltip:AddDoubleLine(prefix .. "|cFF" .. color .. displayName .. "|r", "|cFF" .. color .. scoreText .. "|r")
                                else
                                    tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r")
                                end
                            end
                        end
                    elseif compMode ~= "off" and equipSlot and equipSlot ~= "" then
                        -- Try to get equipped score from shopping tooltip first (if comparing items)
                        -- This ensures both items use the same scaled stats context
                        local equippedScore = nil
                        if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
                            local stName, stLink = ShoppingTooltip1:GetItem(); local equippedItemLink = stLink or stName
                            if equippedItemLink then
                                -- Check if this shopping tooltip shows the equipped item for this slot
                                local _, _, _, _, _, _, _, _, shoppingEquipLoc = GetItemInfo(equippedItemLink)
                                -- Check if items are comparable (uses smart weapon comparison logic)
                                if shoppingEquipLoc and AreWeaponTypesComparable(equipSlot, shoppingEquipLoc) then
                                    local equippedStats = Valuate:GetStatsFromDisplayedTooltip("ShoppingTooltip1")
                                    if equippedStats then
                                        equippedScore = Valuate:CalculateItemScore(equippedStats, scale)
                                    end
                                end
                            end
                        end
                        
                        -- Fall back to getting equipped score the normal way
                        if not equippedScore then
                            equippedScore = Valuate:GetEquippedItemScore(equipSlot, scale)
                        end
                        
                        if equippedScore then
                            local diff = score - equippedScore
                            local diffColor = ""
                            local diffSign = ""
                            
                            if diff > 0 then
                                diffColor = "|cFF00FF00"  -- Green for upgrades
                                diffSign = "+"
                            elseif diff < 0 then
                                diffColor = "|cFFFF0000"  -- Red for downgrades
                                diffSign = ""  -- Negative sign is included in the number
                            else
                                diffColor = "|cFFFFFF00"  -- Yellow for no change
                                diffSign = ""
                            end
                            
                            -- Use helper function to format comparison text
                            comparisonText = FormatPercentageComparison(diff, equippedScore, formatStr, compMode)
                        end
                        
                        -- Build final display text for single-slot items (skip if stat breakdown already shown)
                        if not options.showStatBreakdown then
                            local displayText
                            if showValue then
                                displayText = prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r" .. comparisonText
                            else
                                -- Show only comparison (no base score)
                                if comparisonText ~= "" then
                                    -- Remove the leading space and parentheses from comparison text for cleaner display
                                    local cleanComp = comparisonText:gsub("^ ", ""):gsub("%(", ""):gsub("%)", "")
                                    displayText = prefix .. "|cFF" .. color .. displayName .. ":|r " .. cleanComp
                                else
                                    -- No comparison available, show score anyway
                                    displayText = prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r"
                                end
                            end
                            
                            if options.rightAlign then
                                -- Use AddDoubleLine for right-aligned scores
                                local rightText = "|cFF" .. color .. scoreText .. "|r" .. comparisonText
                                if not showValue and comparisonText ~= "" then
                                    rightText = comparisonText:gsub("^ ", "")
                                end
                                tooltip:AddDoubleLine(prefix .. "|cFF" .. color .. displayName .. "|r", rightText)
                            else
                                tooltip:AddLine(displayText)
                            end
                        end
                    else
                        -- No comparison mode or not equippable - just show the score (skip if stat breakdown already shown)
                        if not options.showStatBreakdown then
                            if options.rightAlign then
                                tooltip:AddDoubleLine(prefix .. "|cFF" .. color .. displayName .. "|r", "|cFF" .. color .. scoreText .. "|r")
                            else
                                tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r")
                            end
                        end
                    end
                    end  -- Close "if showValue then" block
                end
            end
            end  -- Close "if not (options.showScaleValue == "current" and scaleName ~= currentScaleName) then"
        end
    end
    
    if hasScores then
        tooltip:Show()  -- Resize tooltip to fit new lines
    end
end

-- Hooks into tooltip display functions to parse and display item scores
function Valuate:HookTooltips()
    -- Where the tooltip's current item came from, when we know.
    --
    -- Declared ABOVE OnTooltipSet because that function clears them - a local declared
    -- below its reader is a nil global up here, silently, which is the single most
    -- productive bug in this file's history.
    local LastInventorySlot = nil
    local LastBagSlot = nil

    -- Hook the Set* methods to parse stats and mark for update
    local function OnTooltipSet(self)
        -- Forget the previous item's source.
        --
        -- Every Set* hook calls this FIRST and the two that know their source then set
        -- it, so after this runs the pair describes the item now being shown or nothing
        -- at all. Without it they only ever cleared each other: SetMerchantItem,
        -- SetLootItem, SetHyperlink and the quest setters clear neither, so a bag slot
        -- remembered from an earlier hover survived onto an unrelated item.
        --
        -- That matters below, where a malformed link is REPLACED by the link from the
        -- remembered slot. Stale slot, and the tooltip would then parse, score and
        -- colour a different item than the one under the cursor.
        LastInventorySlot = nil
        LastBagSlot = nil
        -- GetItem() returns name, link - use the real LINK (the name-only first
        -- return was why the malformed-link workaround below was always needed).
        local itemName, itemLink = self:GetItem()
        itemLink = itemLink or itemName
        if itemLink then
            -- New item - reset state
            if CurrentTooltipItem ~= itemLink then
                CurrentTooltipItem = itemLink
                CurrentTooltipStats = nil
                CurrentTooltipBorderColor = nil
                ValuateLinesAdded = false
                ValuateJunkLineAdded = false
            end
        end
    end
    
    -- Special hooks to capture item source for proper item link retrieval
    hooksecurefunc(GameTooltip, "SetBagItem", function(self, bag, slot)
        OnTooltipSet(self)
        LastBagSlot = {bag = bag, slot = slot}
        LastInventorySlot = nil  -- belt-and-braces; OnTooltipSet above already cleared both
    end)
    
    hooksecurefunc(GameTooltip, "SetInventoryItem", function(self, unit, slot)
        OnTooltipSet(self)
        LastInventorySlot = {unit = unit, slot = slot}
        LastBagSlot = nil  -- belt-and-braces; OnTooltipSet above already cleared both
    end)
    
    hooksecurefunc(GameTooltip, "SetHyperlink", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetLootItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetAuctionItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetMerchantItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetQuestItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetQuestLogItem", OnTooltipSet)
    
    -- Hook OnUpdate to continuously check and add our lines.
    --
    -- Split out and pcall'd below. This runs roughly sixty times a SECOND for as long
    -- as a tooltip is on screen, so an error in here is not one error - it is a wall of
    -- them, every frame, until you move the mouse, which makes the game unusable rather
    -- than merely broken.
    --
    -- The event handler, the AdiBags filter and the minimap-button tooltip all already
    -- contain their errors, each with a comment giving this same reason. This was the
    -- highest-frequency handler of the four and the only one left unguarded.
    local function RefreshTooltip(self, elapsed)
        -- Only process if tooltip is visible and has an item
        if not self:IsVisible() then return end
        -- Prefer the real link (2nd return); fall back to the name so the
        -- inventory/bag source workaround below can still resolve it.
        local tipName, tipLink = self:GetItem()
        local itemLink = tipLink or tipName
        if not itemLink then
            -- No item, reset border to default
            if DefaultTooltipBorderColor then
                self:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
            end
            return
        end
        
        -- Fix for malformed item links: GetItem() sometimes returns incomplete links
        -- If we have a captured source (inventory or bag), use it to get proper link
        local itemId = GetItemIdFromLink(itemLink)
        if not itemId then
            if LastInventorySlot then
                -- Character sheet item
                local properLink = GetInventoryItemLink(LastInventorySlot.unit, LastInventorySlot.slot)
                if properLink then
                    itemLink = properLink
                end
            elseif LastBagSlot then
                -- Bag item
                local properLink = GetContainerItemLink(LastBagSlot.bag, LastBagSlot.slot)
                if properLink then
                    itemLink = properLink
                end
            end
        end

        -- Profession tools / fishing poles are ignored entirely: don't parse
        -- stats, add lines, or color the border. Reset the border to default.
        if Valuate:IsItemExcludedFromEvaluation(itemLink) then
            if DefaultTooltipBorderColor then
                self:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
            end
            return
        end

        -- Check if our lines are already present. Only worth scanning the lines
        -- while we still think we haven't added them (this loops every tooltip
        -- line, so skip it once our lines are confirmed present).
        if not ValuateLinesAdded and HasValuateLines(self) then
            ValuateLinesAdded = true
            -- Don't return yet - still need to update border color
        end

        -- If lines were added but are now gone, the tooltip was rebuilt - need to re-add
        -- Parse stats if we haven't yet for this item
        if not CurrentTooltipStats or CurrentTooltipItem ~= itemLink then
            CurrentTooltipItem = itemLink
            CurrentTooltipStats = Valuate:GetStatsFromDisplayedTooltip("GameTooltip")
            CurrentTooltipBorderColor = nil  -- recompute border once for this item
            ValuateLinesAdded = false
            ValuateJunkLineAdded = false
        end
        
        -- Add our lines if we have stats
        local statsAdded = false
        if CurrentTooltipStats and next(CurrentTooltipStats) and not ValuateLinesAdded then
            AddScoreLinesToTooltip(self, CurrentTooltipStats, itemLink)
            ValuateLinesAdded = true
            statsAdded = true
        end
        
        -- Add "Best for" line independently (even if no stats were parsed)
        -- This ensures the "Best for" line shows on character sheet and bags
        -- Only add if stats weren't added (AddScoreLinesToTooltip already adds it)
        local options = Valuate:GetOptions()
        if itemLink and not statsAdded and not ValuateLinesAdded and options.showBestFor ~= false then
            local ownsItem = Valuate:PlayerOwnsItem(itemLink)
            if ownsItem then
                local bestForLine = Valuate:BuildBestForLine(itemLink)
                if bestForLine then
                    self:AddLine(" ")
                    self:AddLine(VALUATE_MARKER_FULL .. " " .. bestForLine, nil, nil, nil, true)
                    self:Show()
                    ValuateLinesAdded = true
                end

                -- Same pairing as the other tooltip path; see the note there.
                local futureLine = Valuate:BuildFutureLine(itemLink)
                if futureLine then
                    if not bestForLine then self:AddLine(" ") end
                    self:AddLine(VALUATE_MARKER_FULL .. " " .. futureLine, nil, nil, nil, true)
                    self:Show()
                    ValuateLinesAdded = true
                end
            end
        end
        
        -- Cleanup verdict: would this item be sold or deleted?
        --
        -- Shown ONLY while a cleanup feature is armed, so it configures itself: users
        -- who never enable selling or deleting never see it, and nobody needs a
        -- forty-eighth option to turn it off.
        --
        -- This is the line the junk features have always needed. "Make sure the auto
        -- junk is robust" is not really a request for more guards - it is a request to
        -- be able to SEE what it would do, on the item, before switching it on.
        if itemLink and (options.autoDeleteJunk or options.autoSellJunk) then
            -- Only trust LastBagSlot if it genuinely holds the item being shown.
            --
            -- It is set by SetBagItem and cleared by SetInventoryItem - but NOT by
            -- SetMerchantItem, SetLootItem, SetHyperlink or the quest setters, which
            -- all just refresh the item. So hovering a bag item and then a merchant
            -- item left it pointing at the bag slot, and the quest-item and
            -- equipment-set protections were evaluated against YOUR BAG rather than
            -- the item on screen. A vendor grey could have been reported as "kept:
            -- quest item" because slot 5 of your backpack holds one.
            --
            -- Same re-verification the delete and sell paths do before acting: confirm
            -- the slot still holds what you think it does. Failing that, hand over nil
            -- and let the verdict say it is working from the link alone - which it
            -- already knows how to do.
            local bagInfo = LastBagSlot
            if bagInfo and GetContainerItemLink(bagInfo.bag, bagInfo.slot) ~= itemLink then
                bagInfo = nil
            end
            local isJunk, keptReason, partial = Valuate:GetJunkVerdict(
                itemLink, bagInfo and bagInfo.bag, bagInfo and bagInfo.slot)
            if isJunk and not ValuateJunkLineAdded then
                ValuateJunkLineAdded = true
                self:AddLine(" ")
                if keptReason then
                    self:AddLine(VALUATE_MARKER_FULL .. " Junk, but kept: " .. keptReason,
                        0.55, 0.85, 0.55, true)
                elseif partial then
                    -- Say so rather than promising. Without a bag and slot the quest-item
                    -- and equipment-set protections could not be checked, and claiming
                    -- "will be removed" about a quest item would be a bad way to find out.
                    self:AddLine(VALUATE_MARKER_FULL .. " Junk - would be removed from your bags",
                        1.0, 0.65, 0.2, true)
                else
                    self:AddLine(VALUATE_MARKER_FULL .. " Junk - nothing is protecting this",
                        1.0, 0.5, 0.3, true)
                end
                self:Show()
            end
        end

        -- Apply border coloring based on displayed scale
        if CurrentTooltipStats and next(CurrentTooltipStats) then
            -- Store default border color on first run
            if not DefaultTooltipBorderColor then
                local r, g, b, a = self:GetBackdropBorderColor()
                DefaultTooltipBorderColor = {r, g, b, a}
            end

            -- Compute the border color ONCE per hovered item, not every frame.
            -- GetTooltipBorderColor parses the equipped item's tooltip, so running
            -- it ~60x/sec was the addon's biggest CPU cost. Cache it: nil means
            -- "not computed yet", false means "no coloring", else a {r,g,b} table.
            if CurrentTooltipBorderColor == nil then
                local r, g, b = GetTooltipBorderColor(CurrentTooltipStats, itemLink)
                if r and g and b then
                    CurrentTooltipBorderColor = { r, g, b }
                else
                    CurrentTooltipBorderColor = false
                end
            end

            -- Apply the cached result (cheap every frame)
            if CurrentTooltipBorderColor then
                self:SetBackdropBorderColor(CurrentTooltipBorderColor[1], CurrentTooltipBorderColor[2], CurrentTooltipBorderColor[3], 1)
            elseif DefaultTooltipBorderColor then
                self:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
            end
        end
    end

    GameTooltip:HookScript("OnUpdate", function(self, elapsed)
        local ok, err = pcall(RefreshTooltip, self, elapsed)
        if ok then return end
        -- Reported once, then the frames that follow cost a pcall and a table lookup.
        -- Deliberately NOT disabled after an error: a single malformed item would
        -- otherwise switch tooltip scoring off for the rest of the session, silently,
        -- which is a worse outcome than one line in chat.
        Valuate:ReportRuntimeError("tooltip refresh", err)
    end)

    -- Clear state when tooltip hides
    GameTooltip:HookScript("OnHide", function(self)
        CurrentTooltipItem = nil
        CurrentTooltipStats = nil
        CurrentTooltipBorderColor = nil
        ValuateLinesAdded = false
        ValuateJunkLineAdded = false
        LastInventorySlot = nil
        LastBagSlot = nil
        
        -- Reset border color to default
        if DefaultTooltipBorderColor then
            self:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
        end
    end)
    
    -- ========================================
    -- Shopping/Comparison Tooltip Hooks
    -- ========================================
    --
    -- IMPLEMENTATION NOTES (for future reference):
    -- 
    -- The shopping tooltips (ShoppingTooltip1, ShoppingTooltip2) show the "Currently Equipped"
    -- item when you hover over gear. Adding Valuate scores to these required special handling.
    --
    -- WHAT DIDN'T WORK:
    -- 1. OnUpdate hooks - Caused flickering because the tooltip gets rebuilt frequently by the
    --    game or other addons (like EquipCompare). Our lines would be added, then the tooltip
    --    would be rebuilt (removing our lines), then we'd add them again, causing flicker.
    -- 2. OnTooltipSetItem - This script hook doesn't fire on shopping tooltips.
    -- 3. Frame-based delays/throttling - Still caused flickering because the underlying
    --    rebuild issue wasn't addressed.
    --
    -- WHAT WORKS (Pawn-style approach):
    -- Hook the actual methods that SET the tooltip content:
    -- - SetHyperlinkCompareItem: Main method used by the game for comparison tooltips
    -- - SetInventoryItem: Used by EquipCompare addon
    --
    -- By hooking these methods with hooksecurefunc, our code runs immediately AFTER the
    -- tooltip content is set, before any rebuild can occur. This is a one-time addition
    -- per tooltip set, not a continuous loop, so there's no flickering.
    --
    -- Reference: This approach is used by Pawn addon (Pawn.lua lines 212-219)
    -- ========================================
    
    -- Update a shopping tooltip with Valuate scores (called from method hooks)
    -- Shopping tooltips show equipped items - display ONLY equipped item's values (no comparison)
    local function UpdateShoppingTooltip(tooltipName)
        local tooltip = _G[tooltipName]
        if not tooltip then return end
        
        -- Skip if our lines are already present
        if HasValuateLines(tooltip) then return end
        
        -- Shopping tooltips show equipped items - display only equipped item's stats (no comparison)
        -- NOTE: shoppingItemLink is declared at function scope so the border-coloring
        -- block below can reuse it. (Previously it was scoped to the if-block, so the
        -- border coloring always saw nil and never ran.)
        local shoppingItemLink
        local equippedStats = Valuate:GetStatsFromDisplayedTooltip(tooltipName)
        if equippedStats and next(equippedStats) then
            -- Get the item link for "Best for" checking. GetItem() returns
            -- name, link - prefer the real link, keep the name for the
            -- equipped-slot search fallback below.
            local shoppingName
            shoppingName, shoppingItemLink = tooltip:GetItem()
            shoppingItemLink = shoppingItemLink or shoppingName

            -- Fix malformed item links from shopping tooltips
            local itemId = GetItemIdFromLink(shoppingItemLink)

            if not itemId and shoppingName then
                -- No usable link - match the NAME against equipped items to
                -- recover the proper link
                for slotId = 1, 18 do
                    if slotId ~= 4 then  -- Skip shirt slot
                        local equippedLink = GetInventoryItemLink("player", slotId)
                        if equippedLink then
                            local itemName = GetItemInfo(equippedLink)
                            if itemName and itemName == shoppingName then
                                -- Found matching item!
                                shoppingItemLink = equippedLink
                                break
                            end
                        end
                    end
                end
            end
            
            -- Pass the item link so "Best for" line can be added
            AddScoreLinesToTooltip(tooltip, equippedStats, shoppingItemLink)
            tooltip:Show()  -- Resize tooltip to fit new lines
        end
        
        -- Apply border coloring for shopping tooltips (reuse cached shoppingItemLink)
        if shoppingItemLink and equippedStats then
            -- Store default border color on first run
            if not DefaultTooltipBorderColor then
                local r, g, b, a = tooltip:GetBackdropBorderColor()
                DefaultTooltipBorderColor = {r, g, b, a}
            end
            
            -- Get border color based on equipped item
            local r, g, b = GetTooltipBorderColor(equippedStats, shoppingItemLink)
            if r and g and b then
                tooltip:SetBackdropBorderColor(r, g, b, 1)
            else
                -- No coloring needed, use default
                if DefaultTooltipBorderColor then
                    tooltip:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
                end
            end
        end
    end
    
    -- Hook SetHyperlinkCompareItem - main comparison method used by the game
    if ShoppingTooltip1 and ShoppingTooltip1.SetHyperlinkCompareItem then
        hooksecurefunc(ShoppingTooltip1, "SetHyperlinkCompareItem", function(self, ...)
            UpdateShoppingTooltip("ShoppingTooltip1")
        end)
    end
    if ShoppingTooltip2 and ShoppingTooltip2.SetHyperlinkCompareItem then
        hooksecurefunc(ShoppingTooltip2, "SetHyperlinkCompareItem", function(self, ...)
            UpdateShoppingTooltip("ShoppingTooltip2")
        end)
    end
    
    -- Shopping tooltip item source tracking
    local ShoppingTooltip1Slot = nil
    local ShoppingTooltip2Slot = nil
    
    -- Hook SetInventoryItem - used by EquipCompare addon for comparison tooltips
    if ShoppingTooltip1 then
        hooksecurefunc(ShoppingTooltip1, "SetInventoryItem", function(self, unit, slot)
            ShoppingTooltip1Slot = {unit = unit, slot = slot}
            UpdateShoppingTooltip("ShoppingTooltip1")
        end)
    end
    if ShoppingTooltip2 then
        hooksecurefunc(ShoppingTooltip2, "SetInventoryItem", function(self, unit, slot)
            ShoppingTooltip2Slot = {unit = unit, slot = slot}
            UpdateShoppingTooltip("ShoppingTooltip2")
        end)
    end
    
    -- Hook EquipCompare's ComparisonTooltip frames (if EquipCompare addon is loaded)
    if ComparisonTooltip1 and ComparisonTooltip1.SetHyperlinkCompareItem then
        hooksecurefunc(ComparisonTooltip1, "SetHyperlinkCompareItem", function(self, ...)
            UpdateShoppingTooltip("ComparisonTooltip1")
        end)
    end
    if ComparisonTooltip2 and ComparisonTooltip2.SetHyperlinkCompareItem then
        hooksecurefunc(ComparisonTooltip2, "SetHyperlinkCompareItem", function(self, ...)
            UpdateShoppingTooltip("ComparisonTooltip2")
        end)
    end
    
    if ComparisonTooltip1 then
        hooksecurefunc(ComparisonTooltip1, "SetInventoryItem", function(self, ...)
            UpdateShoppingTooltip("ComparisonTooltip1")
        end)
    end
    if ComparisonTooltip2 then
        hooksecurefunc(ComparisonTooltip2, "SetInventoryItem", function(self, ...)
            UpdateShoppingTooltip("ComparisonTooltip2")
        end)
    end
end

-- ========================================
-- Tooltip Reset System
-- ========================================

--- Attempts to reset a single tooltip, causing Valuate scores to be recalculated
--- Similar to Pawn's PawnResetTooltip function, but handles Ascension's scaled stats
--- tooltipName: Name of the tooltip frame to reset (string)
--- Returns: true if successful, false/nil otherwise
local function ResetTooltip(tooltipName)
    local tooltip = _G[tooltipName]
    if not tooltip or not tooltip.IsShown or not tooltip:IsShown() or not tooltip.GetItem then 
        return false 
    end
    
    local _, itemLink = tooltip:GetItem()
    if not itemLink then 
        return false 
    end
    
    -- For GameTooltip and ShoppingTooltips, check if this is showing an equipped item
    -- If so, we need to use SetInventoryItem to preserve scaled stats
    local isEquippedItem = false
    local slotId = nil
    
    if tooltipName == "GameTooltip" or tooltipName == "ShoppingTooltip1" or tooltipName == "ShoppingTooltip2" then
        -- Check all equipment slots to see if this item is equipped
        for i = 1, 18 do
            if i ~= 4 then -- Skip shirt slot
                local equippedLink = GetInventoryItemLink("player", i)
                if equippedLink == itemLink then
                    isEquippedItem = true
                    slotId = i
                    break
                end
            end
        end
    end
    
    -- Force tooltip to refresh
    tooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
    
    if isEquippedItem and slotId then
        -- Use SetInventoryItem for equipped items to show SCALED stats
        tooltip:SetInventoryItem("player", slotId)
    else
        -- Use SetHyperlink for non-equipped items (shows base stats)
        tooltip:SetHyperlink(itemLink)
    end
    
    tooltip:Show()
    return true
end

--- Resets all visible tooltips to recalculate Valuate scores
--- This should be called whenever scale settings change (stat weights, visibility, etc.)
--- Similar to Pawn's PawnResetTooltips function
function Valuate:ResetTooltips()
    -- Called whenever scoring inputs change - a stat weight edited, a stat banned,
    -- a scale toggled. None of that moves the equipped-gear signature, so the arrow
    -- cache has to be dropped explicitly here or arrows would keep answering with
    -- the old weights until you happened to equip something.
    if Valuate.ResetUpgradeArrowCache then Valuate:ResetUpgradeArrowCache() end

    -- Same argument, one cache further down: the active-scale list is derived from the
    -- scales table, so a scale toggled or renamed has to drop it here or the change would
    -- not reach a bag repaint until the TTL happened to lapse.
    if Valuate.InvalidateActiveScales then Valuate:InvalidateActiveScales() end

    -- Reset main tooltip
    ResetTooltip("GameTooltip")
    
    -- Reset item ref tooltips (shift-click item links in chat)
    ResetTooltip("ItemRefTooltip")
    
    -- Reset shopping/comparison tooltips
    ResetTooltip("ShoppingTooltip1")
    ResetTooltip("ShoppingTooltip2")
    
    -- Reset AtlasLoot tooltip if it exists (addon compatibility)
    ResetTooltip("AtlasLootTooltip")
    
    -- Reset EquipCompare tooltips if they exist (addon compatibility)
    ResetTooltip("ComparisonTooltip1")
    ResetTooltip("ComparisonTooltip2")
    
    -- Refresh character window display if it exists
    if Valuate.RefreshCharacterWindowDisplay then
        Valuate:RefreshCharacterWindowDisplay()
    end
end

-- ========================================
-- Stat Weight System
-- ========================================

-- Calculate item score based on stat weights (scale)
-- stats: Table of stat values {Strength = 10, Stamina = 20, ...}
-- scale: Table of stat weights {Strength = 1.5, Stamina = 1.0, ...}
-- Returns: Total score (number)
function Valuate:CalculateItemScore(stats, scale)
    if not stats or not scale or not scale.Values then
        return nil
    end
    
    -- Check for empty Values table
    if not next(scale.Values) then
        return nil
    end
    
    local total = 0
    local scaleValues = scale.Values
    
    -- Calculate normalization factor if global normalize display is enabled
    local normalizeFactor = 1
    local options = Valuate:GetOptions()
    if options and options.normalizeDisplay then
        local maxWeight = 0
        for statName, weight in pairs(scaleValues) do
            local absWeight = math.abs(weight)
            if absWeight > maxWeight then
                maxWeight = absWeight
            end
        end
        if maxWeight > 0 then
            normalizeFactor = 1 / maxWeight
        end
    end
    
    -- Multiply each stat value by its weight (and normalize if enabled) and sum them
    for statName, statValue in pairs(stats) do
        local weight = scaleValues[statName]
        if weight and weight ~= 0 then
            total = total + (statValue * weight * normalizeFactor)
        end
    end
    
    return total
end

-- Ranks a scale's stats by how much they actually contribute to a set of stat totals.
--
-- The question this answers is the one a stat-weight tool is FOR and could not previously
-- be asked: of the weights I have set, which are doing any work? A scale with fifteen
-- weights on it looks carefully tuned, and if twelve of them are on stats your gear does
-- not carry, tuning them is theatre. The only way to find out was to change a number and
-- watch whether anything moved.
--
-- Pure on purpose - totals in, ranking out, no tooltips and no client. That makes it the
-- part worth executing in a gate, and the caller does the gathering.
--
-- Returns: ranked (list, contributing stats), idle (list, weighted but absent), total.
--   ranked entry: { stat, value, weight, contribution, share }
--
-- `share` is against the sum of ABSOLUTE contributions. A negative weight is still a stat
-- doing work, and dividing by the signed total would let one penalty push everything
-- else's share past 100% - the same sign trap that had the tooltip printing "+-50%".
local function RankStatShares(statTotals, scale)
    if not statTotals or not scale or not scale.Values then return nil end

    local ranked, idle, total, magnitude = {}, {}, 0, 0
    for statName, weight in pairs(scale.Values) do
        if weight and weight ~= 0 then
            local value = statTotals[statName]
            if value and value ~= 0 then
                local contribution = value * weight
                total = total + contribution
                magnitude = magnitude + math.abs(contribution)
                tinsert(ranked, {
                    stat = statName, value = value,
                    weight = weight, contribution = contribution,
                })
            else
                -- Weighted, but you are carrying none of it. Worth naming: it is the
                -- difference between a weight that is wrong and a weight that is unused.
                tinsert(idle, statName)
            end
        end
    end

    for _, entry in ipairs(ranked) do
        entry.share = magnitude > 0 and (math.abs(entry.contribution) / magnitude * 100) or 0
    end

    -- Biggest contributor first, by MAGNITUDE so a large penalty ranks as the big deal it
    -- is. Stat name breaks ties, because pairs() order is undefined and a list that
    -- reshuffles between identical runs reads as a bug in the numbers.
    table.sort(ranked, function(a, b)
        local ca, cb = math.abs(a.contribution), math.abs(b.contribution)
        if ca ~= cb then return ca > cb end
        return a.stat < b.stat
    end)
    table.sort(idle)

    return ranked, idle, total
end

-- Calculate detailed breakdown of stat contributions for an item
-- stats: Table of stat values {Strength = 10, Stamina = 20, ...}
-- scale: Table of stat weights {Strength = 1.5, Stamina = 1.0, ...}
-- Returns: Table of stat contributions sorted by value (descending)
--   Each entry: {statName, statValue, weight, contribution}
function Valuate:CalculateStatBreakdown(stats, scale)
    if not stats or not scale or not scale.Values then
        return nil
    end
    
    local breakdown = {}
    local scaleValues = scale.Values
    
    -- Calculate normalization factor if global normalize display is enabled
    local normalizeFactor = 1
    local options = Valuate:GetOptions()
    if options and options.normalizeDisplay then
        local maxWeight = 0
        for statName, weight in pairs(scaleValues) do
            local absWeight = math.abs(weight)
            if absWeight > maxWeight then
                maxWeight = absWeight
            end
        end
        if maxWeight > 0 then
            normalizeFactor = 1 / maxWeight
        end
    end
    
    -- Calculate contribution for each stat
    for statName, statValue in pairs(stats) do
        local weight = scaleValues[statName]
        if weight and weight ~= 0 and statValue and statValue ~= 0 then
            local normalizedWeight = weight * normalizeFactor
            local contribution = statValue * normalizedWeight
            table.insert(breakdown, {
                statName = statName,
                statValue = statValue,
                weight = normalizedWeight,
                contribution = contribution
            })
        end
    end
    
    -- Sort by contribution (descending)
    table.sort(breakdown, function(a, b)
        local ca, cb = math.abs(a.contribution), math.abs(b.contribution)
        if ca ~= cb then return ca > cb end
        return a.statName < b.statName  -- stable tooltip line order on equal weight
    end)
    
    return breakdown
end

-- Calculate detailed breakdown with comparison between two items
-- hoverStats: Stats of the item being hovered over
-- equippedStats: Stats of the equipped item to compare against
-- scale: Table of stat weights
-- Returns: Table of stat contributions with comparison data, sorted by hover contribution (descending)
--   Each entry: {statName, hoverValue, hoverWeight, hoverContribution, equippedValue, equippedContribution, diff, percentDiff}
function Valuate:CalculateStatBreakdownWithComparison(hoverStats, equippedStats, scale)
    if not hoverStats or not scale or not scale.Values then
        return nil
    end
    
    local breakdown = {}
    local scaleValues = scale.Values
    
    -- Calculate normalization factor if global normalize display is enabled
    local normalizeFactor = 1
    local options = Valuate:GetOptions()
    if options and options.normalizeDisplay then
        local maxWeight = 0
        for statName, weight in pairs(scaleValues) do
            local absWeight = math.abs(weight)
            if absWeight > maxWeight then
                maxWeight = absWeight
            end
        end
        if maxWeight > 0 then
            normalizeFactor = 1 / maxWeight
        end
    end
    
    -- Build union of all stat names from both items
    local allStats = {}
    for statName, _ in pairs(hoverStats) do
        allStats[statName] = true
    end
    if equippedStats then
        for statName, _ in pairs(equippedStats) do
            allStats[statName] = true
        end
    end
    
    -- Calculate contribution for each stat
    for statName, _ in pairs(allStats) do
        local weight = scaleValues[statName]
        if weight and weight ~= 0 then
            local hoverValue = hoverStats[statName] or 0
            local equippedValue = (equippedStats and equippedStats[statName]) or 0
            
            -- Only include if at least one item has this stat
            if hoverValue ~= 0 or equippedValue ~= 0 then
                local normalizedWeight = weight * normalizeFactor
                local hoverContribution = hoverValue * normalizedWeight
                local equippedContribution = equippedValue * normalizedWeight
                local diff = hoverContribution - equippedContribution
                
                local percentDiff = 0
                if equippedContribution ~= 0 then
                    percentDiff = (diff / math.abs(equippedContribution)) * 100
                elseif diff ~= 0 then
                    -- Equipped has 0, hover has something = infinite gain
                    percentDiff = (diff > 0) and 100 or -100
                end
                
                table.insert(breakdown, {
                    statName = statName,
                    hoverValue = hoverValue,
                    hoverWeight = normalizedWeight,
                    hoverContribution = hoverContribution,
                    equippedValue = equippedValue,
                    equippedContribution = equippedContribution,
                    diff = diff,
                    percentDiff = percentDiff
                })
            end
        end
    end
    
    -- Sort by hover contribution (descending)
    table.sort(breakdown, function(a, b)
        local ca, cb = math.abs(a.hoverContribution), math.abs(b.hoverContribution)
        if ca ~= cb then return ca > cb end
        return a.statName < b.statName  -- stable tooltip line order on equal weight
    end)
    
    return breakdown
end

-- Gets individual scores for each equipped item in multi-slot types (rings, trinkets, weapons)
-- equipSlot: The equipment slot type (e.g., "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_WEAPON")
-- scale: The scale data table to use for scoring
-- Returns: Table with slot IDs as keys and scores as values, or nil if not a multi-slot type
function Valuate:GetEquippedItemScores(equipSlot, scale)
    local invSlots = EquipSlotToInvNumber[equipSlot]
    if not invSlots or #invSlots <= 1 then return nil end
    
    local scores = {}
    local tooltip = GetPrivateTooltip()
    
    for _, slotId in ipairs(invSlots) do
        local itemLink = GetInventoryItemLink("player", slotId)
        -- Ignore profession tools / fishing poles as comparison baselines too
        if itemLink and not Valuate:IsItemExcludedFromEvaluation(itemLink) then
            -- Get the equipped item's type
            local _, _, _, _, _, _, _, _, equippedEquipLoc = GetItemInfo(itemLink)
            
            -- Check if these item types should be compared
            local shouldCompare = false
            if equippedEquipLoc and equippedEquipLoc ~= "" then
                shouldCompare = AreWeaponTypesComparable(equipSlot, equippedEquipLoc)
            end
            -- If equippedEquipLoc is missing or empty, we can't determine comparability, so don't compare
            
            if shouldCompare then
                tooltip:ClearLines()
                -- Use SetInventoryItem so equipped scores use the same SCALED stats
                -- basis as the best-equipment scan and character window (consistency).
                tooltip:SetInventoryItem("player", slotId)
                local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                if stats then
                    local score = Valuate:CalculateItemScore(stats, scale)
                    if score then
                        scores[slotId] = score
                    end
                end
            end
        end
    end

    return next(scores) and scores or nil
end

-- Gets the score of an equipped item in a specific inventory slot using SCALED stats
-- slotId: The inventory slot ID (1-18)
-- scale: The scale data table to use for scoring
-- Returns: The score for the item in that slot, or 0 if no item/no score
function Valuate:GetEquippedItemScoreBySlotId(slotId, scale)
    if not slotId or not scale or not scale.Values then
        return 0
    end
    
    local itemLink = GetInventoryItemLink("player", slotId)
    if not itemLink then
        return 0
    end
    
    local tooltip = GetPrivateTooltip()
    tooltip:ClearLines()
    -- Use SetInventoryItem to get SCALED stats (same as what's shown in tooltips)
    tooltip:SetInventoryItem("player", slotId)
    local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
    
    if stats then
        local score = Valuate:CalculateItemScore(stats, scale)
        return score or 0
    end
    
    return 0
end

-- Gets the score of currently equipped item(s) for comparison
-- equipSlot: The equipment slot type (e.g., "INVTYPE_HEAD", "INVTYPE_FINGER")
-- scale: The scale data table to use for scoring
-- Returns: The lowest score among equipped items in that slot (for multi-slot items like rings)
function Valuate:GetEquippedItemScore(equipSlot, scale)
    local invSlots = EquipSlotToInvNumber[equipSlot]
    if not invSlots then return nil end
    
    local lowestScore = nil
    local tooltip = GetPrivateTooltip()
    
    for _, slotId in ipairs(invSlots) do
        local itemLink = GetInventoryItemLink("player", slotId)
        -- Ignore profession tools / fishing poles as comparison baselines too
        if itemLink and not Valuate:IsItemExcludedFromEvaluation(itemLink) then
            -- Get the equipped item's type
            local _, _, _, _, _, _, _, _, equippedEquipLoc = GetItemInfo(itemLink)
            
            -- Check if these item types should be compared
            local shouldCompare = false
            if equippedEquipLoc and equippedEquipLoc ~= "" then
                shouldCompare = AreWeaponTypesComparable(equipSlot, equippedEquipLoc)
            end
            -- If equippedEquipLoc is missing or empty, we can't determine comparability, so don't compare
            
            if shouldCompare then
                tooltip:ClearLines()
                -- Use SetInventoryItem so the equipped item is read with its SCALED
                -- stats - the same basis as the hovered item's displayed tooltip and
                -- the best-equipment scan. (Previously SetHyperlink read base stats,
                -- which made tooltip "vs equipped" numbers disagree with the panel.)
                tooltip:SetInventoryItem("player", slotId)
                local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                if stats then
                    local score = Valuate:CalculateItemScore(stats, scale)
                    if score and (not lowestScore or score < lowestScore) then
                        lowestScore = score
                    end
                end
            end
        end
    end
    
    return lowestScore  -- Return nil if no equipped item found, not 0
end

-- Calculates the total score for all currently equipped gear
-- scale: The scale data table to use for scoring
-- Returns: Total score (number) for all equipped items
function Valuate:CalculateTotalEquippedScore(scale)
    if not scale or not scale.Values then
        return 0
    end
    
    local totalScore = 0
    local tooltip = GetPrivateTooltip()
    
    -- Equipment slots: 1=head, 2=neck, 3=shoulder, 4=shirt(skip), 5=chest, 6=waist, 7=legs,
    -- 8=feet, 9=wrist, 10=hands, 11=finger1, 12=finger2, 13=trinket1, 14=trinket2,
    -- 15=back, 16=mainhand, 17=offhand, 18=ranged, 19=tabard(skip)
    for slotId = 1, 18 do
        -- Skip shirt (4) and tabard (19, but that's after 18 anyway)
        if slotId ~= 4 then
            local itemLink = GetInventoryItemLink("player", slotId)
            if itemLink then
                tooltip:ClearLines()
                tooltip:SetInventoryItem("player", slotId)
                local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                if stats then
                    local score = Valuate:CalculateItemScore(stats, scale)
                    if score then
                        totalScore = totalScore + score
                    end
                end
            end
        end
    end
    
    return totalScore
end

-- Gets all active scales (scales that should be displayed)
-- Returns: Table of scale names that are active
-- The sorted active list, cached.
--
-- MEASURED, not guessed: tools/hotpath.js drives the path AdiBags drives - one filter call
-- per item per repaint, each asking IsBestInSlot and GetFutureUpgradeScales - and found a
-- 120-item bag with 6 scales rebuilding and re-SORTING this list 240 times per repaint.
-- The list is derived from the scales table alone, so it cannot change while a repaint is
-- in flight; 239 of those sorts could not affect any answer.
--
-- Invalidated from ResetTooltips, which is already the "scoring inputs changed" signal and
-- already drops the upgrade-arrow cache for the same reason. Hanging this there rather than
-- on thirty individual mutation sites means a new one inherits it.
--
-- The TTL is a safety net, not the mechanism. If some future path edits scales without
-- going through ResetTooltips, a stale list would mark gear as surplus that is not - and
-- surplus feeds auto-delete. One second is imperceptible for a visibility toggle and still
-- collapses an entire repaint burst into a single build.
-- Cache effectiveness, counted.
--
-- v0.91.0a and v0.92.0a cut a bag repaint from 240 sorts and 240 GetItemInfo calls to none,
-- and every word of that was proved by a headless gate counting calls - which is evidence
-- about the SOURCE, not about your client. A cache that silently never hits looks exactly
-- like a cache that works: same answers, same code path, no error.
--
-- Two increments each. /valuate profile reports the hit rate, so one command in the game
-- confirms or refutes the claim rather than leaving it as a number from a test harness.
local cacheStats = { activeHit = 0, activeBuild = 0, slotHit = 0, slotMiss = 0 }
function Valuate:GetCacheStats() return cacheStats end

local ACTIVE_SCALES_TTL = 1
local activeScalesCache, activeScalesAt = nil, -1

function Valuate:InvalidateActiveScales()
    activeScalesCache, activeScalesAt = nil, -1
end

function Valuate:GetActiveScales()
    local now = (GetTime and GetTime()) or 0
    -- `now < activeScalesAt` catches a clock that went backwards (a /reload resets GetTime).
    if activeScalesCache and now - activeScalesAt <= ACTIVE_SCALES_TTL and now >= activeScalesAt then
        cacheStats.activeHit = cacheStats.activeHit + 1
        return activeScalesCache
    end
    cacheStats.activeBuild = cacheStats.activeBuild + 1

    local active = {}
    local scales = Valuate:GetScales()

    if not scales then
        return active
    end

    for scaleName, scaleData in pairs(scales) do
        -- Check if scale has values and is visible
        if scaleData.Values and (scaleData.Visible ~= false) then  -- Default to visible if not set
            tinsert(active, scaleName)
        end
    end

    -- SORTED, because pairs() order is undefined and a dozen callers treat this list as
    -- if it had one. The Best Equipment tab lays its columns out in this order, so the
    -- scales could appear left-to-right differently after a reload; GetPrimaryScale
    -- took element [1] as its fallback, so which scale drove the upgrade arrows, the
    -- character-sheet score and the auto-roll baseline was likewise arbitrary.
    --
    -- Ordered by DISPLAY name so the columns match the scale list beside them, with the
    -- key as a tiebreaker: two scales may share a display name, and without a unique
    -- second key table.sort (which is not stable) would put them in either order.
    table.sort(active, function(a, b)
        local da = (scales[a].DisplayName or a)
        local db = (scales[b].DisplayName or b)
        if da ~= db then return da < db end
        return a < b
    end)

    activeScalesCache, activeScalesAt = active, now
    return active
end

-- ========================================
-- Best Equipment Tracking
-- ========================================

-- True if a tooltip FontString is drawn in Blizzard's "unmet requirement" red
-- (~1.0, 0.125, 0.125). Requirement failures - level too high, an unlearned
-- weapon proficiency, wrong class, missing skill/reputation - are all rendered
-- in this red on the item tooltip, so reading the color reflects exactly what
-- the player sees, and respects Ascension's learned proficiencies rather than a
-- static class table.
local function TooltipLineIsRed(fontString)
    if not fontString or not fontString.GetText then return false end
    local text = fontString:GetText()
    if not text or text == "" then return false end
    local r, g, b = fontString:GetTextColor()
    if not r then return false end
    return r > 0.8 and g < 0.35 and b < 0.35
end

-- Scans an already-populated tooltip for any red (unmet) requirement line, on
-- either the left (level/skill/class lines) or right (weapon/armor proficiency).
-- Line 1 is the item name (quality-colored, never requirement-red) so it's skipped.
local function TooltipHasUnmetRequirement(tooltipName)
    local tooltip = _G[tooltipName]
    if not tooltip then return false end
    for i = 2, tooltip:NumLines() do
        if TooltipLineIsRed(getglobal(tooltipName .. "TextLeft" .. i))
           or TooltipLineIsRed(getglobal(tooltipName .. "TextRight" .. i)) then
            return true
        end
    end
    return false
end

-- How many of this item may be EQUIPPED at once, from its tooltip.
-- Returns nil when unrestricted.
--
-- GetItemInfo does not expose uniqueness on 3.3.5, so the tooltip is the only
-- source. Three shapes appear, and the third is the one that matters here:
--   "Unique"                                -> 1
--   "Unique (20)"                           -> 20
--   "Unique-Equipped: Protector's Band (1)" -> 1   (unique CATEGORY)
-- Other addons on this client test the first two with an exact match, which misses
-- the category form entirely - and that is exactly the case that was assigning one
-- ring to both ring slots. So we prefix-match and read any trailing "(N)".
local function TooltipUniqueLimit(tooltipName)
    local tooltip = _G[tooltipName]
    if not tooltip then return nil end

    local uniqueEquip = ITEM_UNIQUE_EQUIPPABLE or "Unique-Equipped"
    local unique = ITEM_UNIQUE or "Unique"

    for i = 2, tooltip:NumLines() do
        local fs = getglobal(tooltipName .. "TextLeft" .. i)
        local text = fs and fs.GetText and fs:GetText()
        if text and text ~= "" then
            -- Anchored to the start of the line so an item whose NAME contains
            -- "Unique" can't trigger this.
            if text:find(uniqueEquip, 1, true) == 1 or text:find(unique, 1, true) == 1 then
                local n = tonumber(text:match("%((%d+)%)"))
                return (n and n > 0) and n or 1
            end
        end
    end
    return nil
end

-- Integration modules (AdiBags, PassLoot, ...) can register a callback to be told
-- when the best-equipment data changes, so they can invalidate their own caches.
-- Without this an AdiBags filter keeps showing the PREVIOUS scan's categorisation
-- until something unrelated happens to make it re-filter, which looks like "some
-- best items aren't going into the section".
local bestEquipmentListeners = {}
function Valuate:RegisterBestEquipmentListener(fn)
    if type(fn) ~= "function" then return false end
    table.insert(bestEquipmentListeners, fn)
    return true
end

-- Cheap fingerprint of everything an upgrade-arrow answer depends on: what you
-- have equipped, and which scale is being asked about. Scale WEIGHTS are handled
-- separately in ResetTooltips, since editing them changes answers without changing
-- any of this.
local upgradeCacheSignature
local function UpgradeBaselineSignature()
    local parts = {}
    for slotId = 1, 18 do
        if slotId ~= 4 then
            local link = GetInventoryItemLink("player", slotId)
            parts[#parts + 1] = (link and GetItemIdFromLink(link)) or "-"
        end
    end
    local _, primaryName = Valuate:GetPrimaryScale()
    parts[#parts + 1] = primaryName or "-"
    return table.concat(parts, ",")
end

function Valuate:NotifyBestEquipmentChanged()
    -- Only drop the arrow cache when the ANSWERS could have changed.
    --
    -- This used to reset on every scan, which was fine when scans were rare. With
    -- Auto Scan on "Always" they now run about once a second while looting, so every
    -- visible bag icon was rebuilding a tooltip and re-checking scales on every
    -- repaint - for a baseline that had not moved. A scan that finds nothing new
    -- must not invalidate anything.
    local sig = UpgradeBaselineSignature()
    if sig ~= upgradeCacheSignature then
        upgradeCacheSignature = sig
        if Valuate.ResetUpgradeArrowCache then Valuate:ResetUpgradeArrowCache() end
    end

    for _, fn in ipairs(bestEquipmentListeners) do
        pcall(fn)
    end
end

-- Returns the ordered list of weapon-set definitions ({key, label}).
-- Which inventory slot IDs an equip location maps to (rings/trinkets/weapons give
-- two). Exposed because integrations need to ask "does Valuate actually have an
-- opinion about this item's slot?" before acting on its absence from best-in-slot.
-- Returns the shared table, so callers must treat it as read-only.
function Valuate:GetInventorySlotsForEquipLoc(equipLoc)
    if not equipLoc or equipLoc == "" then return nil end
    return EquipSlotToInvNumber[equipLoc]
end

function Valuate:GetWeaponSetDefinitions()
    return WEAPON_SET_DEFS
end

-- Whether a given weapon-set config key is enabled for a scale.
-- Backward-compat: a scale with no WeaponSets table has every config enabled.
function Valuate:IsWeaponSetEnabled(scale, key)
    if not scale then return false end
    if scale.WeaponSets == nil then return true end
    return scale.WeaponSets[key] and true or false
end

-- Shorthand label (e.g. "2H", "1H+Sh") for a scale's currently-resolved active
-- weapon set, from the last scan. Returns nil if none is tracked.
function Valuate:GetActiveWeaponSetShort(scaleName)
    if not scaleName then return nil end
    local be = Valuate:GetBestEquipment()[scaleName]
    local key = be and be.activeWeaponSet
    if not key then return nil end
    for _, def in ipairs(WEAPON_SET_DEFS) do
        if def.key == key then return def.short end
    end
    return nil
end

-- ============================================================================
-- Bank cache
-- ============================================================================
-- Bank containers (-1, and bank bags 5-11) are only readable while the bank
-- frame is open. So we snapshot them whenever the player visits a bank, and the
-- rest of the addon reads that snapshot. Stats are parsed HERE, at snapshot
-- time, because SetBagItem gives the real (scaled) stats only while the
-- container is live - SetHyperlink later would return base stats instead.
--
-- Cached items are candidates for best-in-slot, NOT for anything destructive:
-- auto-delete, auto-sell and the free-slot count stay strictly bags-only.
local BANK_CONTAINER_ID = -1
local FIRST_BANK_BAG, LAST_BANK_BAG = 5, 11

function Valuate:GetBankCache()
    if not ValuateBankCache then
        ValuateBankCache = { items = {}, scannedAt = 0 }
    end
    ValuateBankCache.items = ValuateBankCache.items or {}
    return ValuateBankCache
end

-- Snapshots every equippable item in the bank. Called on BANKFRAME_OPENED and
-- whenever bank contents change while it is open.
function Valuate:ScanBankContents()
    -- Same in-transit guard as ScanBestEquipment: touching a tooltip mid-swap
    -- can make items vanish.
    if equipmentSwapPending or recentEquipmentChange then return false end

    local tooltip = _G["ValuatePrivateTooltip"]
    if not tooltip then return false end

    local playerLevel = UnitLevel("player") or 1
    local items, scanned = {}, 0

    local containers = { BANK_CONTAINER_ID }
    for bagId = FIRST_BANK_BAG, LAST_BANK_BAG do tinsert(containers, bagId) end

    for _, bagId in ipairs(containers) do
        local numSlots = GetContainerNumSlots(bagId) or 0
        for slotId = 1, numSlots do
            local itemLink = GetContainerItemLink(bagId, slotId)
            if itemLink then
                scanned = scanned + 1
                local itemId = GetItemIdFromLink(itemLink)
                if itemId then
                    if items[itemId] then
                        items[itemId].count = items[itemId].count + 1
                    else
                        local itemName, _, _, _, itemMinLevel, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
                        if itemEquipLoc and itemEquipLoc ~= ""
                           and not Valuate:IsItemExcludedFromEvaluation(itemLink) then
                            local ok, stats, hasUnmetReq, uniqueLimit = pcall(function()
                                tooltip:ClearLines()
                                tooltip:SetBagItem(bagId, slotId)
                                local parsed = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                                return parsed,
                                    TooltipHasUnmetRequirement("ValuatePrivateTooltip"),
                                    TooltipUniqueLimit("ValuatePrivateTooltip")
                            end)
                            if ok and stats then
                                local _, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                                local reqLevel = itemMinLevel or 0
                                items[itemId] = {
                                    itemLink = itemLink,
                                    itemName = itemName or "Unknown",
                                    itemEquipLoc = itemEquipLoc,
                                    stats = stats,
                                    itemTexture = itemTexture,
                                    itemQuality = itemQuality or 0,
                                    reqLevel = reqLevel,
                                    -- "Equippable" here means the character MEETS the
                                    -- requirements - not that it can be reached right
                                    -- now. Reachability is the `source` field's job.
                                    equippableNow = (playerLevel >= reqLevel) and (not hasUnmetReq),
                                    uniqueLimit = uniqueLimit,
                                    count = 1,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    local cache = Valuate:GetBankCache()
    cache.items = items
    cache.scannedAt = time()
    cache.slotsScanned = scanned
    local cached = 0
    for _ in pairs(items) do cached = cached + 1 end
    Valuate:MarkAutomation("bankSnapshot",
        string.format("%d equippable item(s) from %d slot(s)", cached, scanned))
    return true
end

-- Scans all equipped items and items in bags to find the best item for each slot per scale
-- Stores results in ValuateBestEquipment[scaleName][slotId] = {itemLink, score, itemName}
-- Items the character can't equip yet (too high level / unlearned proficiency) are
-- not chosen as the current best; if they'd be an upgrade they're recorded under
-- ValuateBestEquipment[scaleName].future[slotId] so they're kept but never auto-equipped.
function Valuate:ScanBestEquipment()
    -- CRITICAL FIX: Do not scan if equipment swap is pending or recent equipment change occurred
    -- Calling SetBagItem during item transit causes items to disappear
    if equipmentSwapPending or recentEquipmentChange then
        return false  -- caller can tell the user to retry in a few seconds
    end
    
    local bestEquipment = Valuate:GetBestEquipment()
    local activeScales = Valuate:GetActiveScales()
    local scales = Valuate:GetScales()
    local tooltip = GetPrivateTooltip()
    local options = Valuate:GetOptions()
    local playerLevel = UnitLevel("player") or 1
    local canDualWield = Valuate:CanDualWield()

    if #activeScales == 0 then
        if options.scanVerbose then
            print("|cFFFF8800[Valuate]|r No active scales - cannot scan best equipment")
        end
        return
    end
    
    -- Initialize/clear storage for each scale (reset previous scan data, but preserve locks)
    for _, scaleName in ipairs(activeScales) do
        -- Save locks before clearing
        local locks = bestEquipment[scaleName] and bestEquipment[scaleName].locks
        bestEquipment[scaleName] = {}  -- Always reset to clear previous scan results
        -- Restore locks
        if locks then
            bestEquipment[scaleName].locks = locks
        end
    end
    
    -- First pass: Count all items by item ID (equipped + bags)
    local itemCounts = {}  -- itemId -> count
    local itemData = {}    -- itemId -> {itemLink, itemName, itemEquipLoc, stats, itemTexture, itemQuality}
    
    local itemsScanned = 0
    local itemsProcessed = 0
    
    -- First pass: Count all items and collect their data
    -- Scan equipped items (slots 1-18, skip 4=shirt)
    for slotId = 1, 18 do
        if slotId ~= 4 then
            local itemLink = GetInventoryItemLink("player", slotId)
            if itemLink then
                itemsScanned = itemsScanned + 1
                local itemId = GetItemIdFromLink(itemLink)
                if itemId then
                    itemCounts[itemId] = (itemCounts[itemId] or 0) + 1
                    
                    -- Store item data if not already stored
                    if not itemData[itemId] then
                        local itemName, _, _, _, itemMinLevel, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
                        tooltip:ClearLines()
                        -- Use SetInventoryItem for equipped items to get actual scaled stats
                        tooltip:SetInventoryItem("player", slotId)
                        local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                        local uniqueLimit = TooltipUniqueLimit("ValuatePrivateTooltip")

                        if stats and itemEquipLoc and itemEquipLoc ~= ""
                           and not Valuate:IsItemExcludedFromEvaluation(itemLink) then
                            local _, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                            itemData[itemId] = {
                                itemLink = itemLink,
                                itemName = itemName or "Unknown",
                                itemEquipLoc = itemEquipLoc,
                                stats = stats,
                                itemTexture = itemTexture,
                                itemQuality = itemQuality or 0,
                                reqLevel = itemMinLevel or 0,
                                -- An equipped item is by definition currently equippable.
                                equippableNow = true,
                                source = "equipped",
                                uniqueLimit = uniqueLimit,
                            }
                            itemsProcessed = itemsProcessed + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Scan bag items (bags 0-4)
    for bagId = 0, 4 do
        local numSlots = GetContainerNumSlots(bagId)
        for slotId = 1, numSlots do
            local itemLink = GetContainerItemLink(bagId, slotId)
            if itemLink then
                itemsScanned = itemsScanned + 1
                local itemId = GetItemIdFromLink(itemLink)
                if itemId then
                    itemCounts[itemId] = (itemCounts[itemId] or 0) + 1
                    
                    -- Store item data if not already stored
                    if not itemData[itemId] then
                        local itemName, _, _, _, itemMinLevel, _, _, _, itemEquipLoc = GetItemInfo(itemLink)

                        -- Only process equippable items, and never profession tools / fishing poles
                        if itemEquipLoc and itemEquipLoc ~= ""
                           and not Valuate:IsItemExcludedFromEvaluation(itemLink) then
                            -- CRITICAL FIX: Skip SetBagItem if items are in transit
                            -- Calling SetBagItem during equipment swaps causes items to disappear
                            if equipmentSwapPending or recentEquipmentChange then
                                -- Skip this item - don't call SetBagItem during swaps
                            else
                                -- Get item stats AND its current equippability in one pass while
                                -- the tooltip holds this bag item (both need the populated tooltip).
                                tooltip:ClearLines()
                                -- Use SetBagItem for bag items to get actual scaled stats
                                -- Use pcall to safely handle cases where item might be in transit
                                local success, stats, hasUnmetReq, uniqueLimit = pcall(function()
                                    tooltip:SetBagItem(bagId, slotId)
                                    local parsed = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                                    return parsed,
                                        TooltipHasUnmetRequirement("ValuatePrivateTooltip"),
                                        TooltipUniqueLimit("ValuatePrivateTooltip")
                                end)

                                if success and stats then
                                    local _, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                                    local reqLevel = itemMinLevel or 0
                                    -- Equippable now = meets required level AND the tooltip shows no
                                    -- red (unmet) requirement lines. Bag items only; equipped items
                                    -- are always equippable.
                                    local equippableNow = (playerLevel >= reqLevel) and (not hasUnmetReq)
                                    itemData[itemId] = {
                                        itemLink = itemLink,
                                        itemName = itemName or "Unknown",
                                        itemEquipLoc = itemEquipLoc,
                                        stats = stats,
                                        itemTexture = itemTexture,
                                        itemQuality = itemQuality or 0,
                                        reqLevel = reqLevel,
                                        equippableNow = equippableNow,
                                        source = "bags",
                                        uniqueLimit = uniqueLimit,
                                    }
                                    itemsProcessed = itemsProcessed + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Merge the bank snapshot. Banked gear is genuinely owned, so it belongs in
    -- best-in-slot - it just isn't reachable right now, which is what `source`
    -- records so Equip All can skip it and the panel can badge it.
    --
    -- Deliberately conservative: an item already seen in bags or equipped is NOT
    -- topped up with its banked copies. `source` describes a whole itemId, not an
    -- individual copy, so counting a banked duplicate here would let the scan fill
    -- a second ring/trinket slot with an item it would then wrongly report as
    -- reachable. Understating what you own is the safe direction; overstating it
    -- produces an Equip All that silently half-works.
    if Valuate:GetOptions().includeBankItems then
        for itemId, cached in pairs(Valuate:GetBankCache().items) do
            if not itemData[itemId] then
                itemData[itemId] = {
                    itemLink = cached.itemLink,
                    itemName = cached.itemName,
                    itemEquipLoc = cached.itemEquipLoc,
                    stats = cached.stats,
                    itemTexture = cached.itemTexture,
                    itemQuality = cached.itemQuality or 0,
                    reqLevel = cached.reqLevel or 0,
                    equippableNow = cached.equippableNow,
                    uniqueLimit = cached.uniqueLimit,
                    source = "bank",
                }
                itemCounts[itemId] = (itemCounts[itemId] or 0) + (cached.count or 1)
                itemsScanned = itemsScanned + (cached.count or 1)
                itemsProcessed = itemsProcessed + 1
            end
        end
    end

    -- Second pass: For each scale, assign items to slots, tracking usage
    for _, scaleName in ipairs(activeScales) do
        local scale = scales[scaleName]
        if scale then
            -- Track how many times each item ID has been used for this scale
            local itemUsage = {}  -- itemId -> count of times used
            
            -- Check for locked slots
            local locks = bestEquipment[scaleName].locks or {}

            -- Honour explicit intent: if this scale has the Dual Wield set enabled the
            -- user is telling us they dual-wield, which beats auto-detection. There is
            -- no dependable dual-wield API on 3.3.5 and class defaults are meaningless
            -- on a classless server, so without this an off-hand 1H is never picked.
            local wantsDualWield = canDualWield or Valuate:IsWeaponSetEnabled(scale, "DualWield")
            
            -- Collect all items with their scores for this scale
            local itemsWithScores = {}  -- {itemId, score, itemData}
            
            for itemId, data in pairs(itemData) do
                -- Check if item has unusable stats
                local hasUnusableStat = false
                if scale.Unusable then
                    for statName, statValue in pairs(data.stats) do
                        if scale.Unusable[statName] and statValue and statValue > 0 then
                            hasUnusableStat = true
                            break
                        end
                    end
                    
                    if not hasUnusableStat and data.itemEquipLoc then
                        if (data.itemEquipLoc == "INVTYPE_WEAPON" or data.itemEquipLoc == "INVTYPE_WEAPONMAINHAND") and scale.Unusable["OneHandDps"] then
                            hasUnusableStat = true
                        elseif data.itemEquipLoc == "INVTYPE_2HWEAPON" and scale.Unusable["TwoHandDps"] then
                            hasUnusableStat = true
                        elseif data.itemEquipLoc == "INVTYPE_WEAPONOFFHAND" and scale.Unusable["OffHandDps"] then
                            hasUnusableStat = true
                        elseif (data.itemEquipLoc == "INVTYPE_RANGED" or data.itemEquipLoc == "INVTYPE_RANGEDRIGHT" or data.itemEquipLoc == "INVTYPE_THROWN") and scale.Unusable["RangedDps"] then
                            hasUnusableStat = true
                        end
                    end
                end
                
                if not hasUnusableStat then
                    local score = Valuate:CalculateItemScore(data.stats, scale)
                    if score and score > 0 then
                        table.insert(itemsWithScores, {
                            itemId = itemId,
                            score = score,
                            data = data
                        })
                    end
                end
            end
            
            -- Sort by score (descending) so we assign best items first.
            -- itemId breaks ties: table.sort is not stable and the input order comes
            -- from pairs(itemData), which is undefined. Without this, two items with
            -- an identical score swap places between scans, so "Best for" tooltips,
            -- the equipment set and the AdiBags tag all flip at random.
            table.sort(itemsWithScores, function(a, b)
                if a.score ~= b.score then return a.score > b.score end
                return a.itemId < b.itemId
            end)
            
            -- Pass 1: assign the CURRENT best-in-slot from items the character can
            -- equip right now. These drive tooltips ("Best for"), the panel, and
            -- right-click-to-equip. Items are pre-sorted by score descending.
            for _, itemInfo in ipairs(itemsWithScores) do
                if itemInfo.data.equippableNow then
                    local itemId = itemInfo.itemId
                    local score = itemInfo.score
                    local data = itemInfo.data
                    local targetSlots = EquipSlotToInvNumber[data.itemEquipLoc]

                    if targetSlots then
                        for _, targetSlotId in ipairs(targetSlots) do
                            -- Skip locked slots; and don't put a generic one-hand
                            -- weapon in the off-hand (17) unless we can dual-wield.
                            if not locks[targetSlotId]
                               and not (targetSlotId == 17 and data.itemEquipLoc == "INVTYPE_WEAPON" and not wantsDualWield) then
                                -- Calculate available copies each time.
                                -- Unique-Equipped caps how many can be WORN at once,
                                -- regardless of how many you own. Without this a single
                                -- unique ring was recommended for BOTH ring slots -
                                -- advice the game will not let you follow.
                                local ownedCopies = itemCounts[itemId]
                                if data.uniqueLimit and data.uniqueLimit < ownedCopies then
                                    ownedCopies = data.uniqueLimit
                                end
                                local availableCopies = ownedCopies - (itemUsage[itemId] or 0)

                                -- Only assign if we have copies available
                                if availableCopies > 0 then
                                    -- Check if this is better than current best for this slot
                                    local currentBest = bestEquipment[scaleName][targetSlotId]
                                    if not currentBest or score > currentBest.score then
                                        bestEquipment[scaleName][targetSlotId] = {
                                            itemLink = data.itemLink,
                                            score = score,
                                            itemName = data.itemName,
                                            itemTexture = data.itemTexture,
                                            itemQuality = data.itemQuality,
                                            source = data.source,
                                        }
                                        -- Mark this item as used for this slot
                                        itemUsage[itemId] = (itemUsage[itemId] or 0) + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- ===== Weapon sets =====
            -- Find the best currently-equippable item for each weapon category,
            -- assemble the enabled weapon configurations, and resolve the active one
            -- into the Main Hand (16) / Off Hand (17) best-in-slot entries so every
            -- existing consumer reflects the chosen set. itemsWithScores is already
            -- sorted by score descending with banned stats filtered out.
            local function makeWeaponRec(itemInfo)
                local d = itemInfo.data
                return {
                    itemLink = d.itemLink,
                    score = itemInfo.score,
                    itemName = d.itemName,
                    itemTexture = d.itemTexture,
                    itemQuality = d.itemQuality,
                    itemId = itemInfo.itemId,
                    source = d.source,
                }
            end

            local bestMH2H, bestMH1H, bestOffShield, bestOffHold, bestOH1H
            for _, itemInfo in ipairs(itemsWithScores) do
                if itemInfo.data.equippableNow then
                    local loc = itemInfo.data.itemEquipLoc
                    local id = itemInfo.itemId
                    if loc == "INVTYPE_2HWEAPON" then
                        if not bestMH2H then bestMH2H = makeWeaponRec(itemInfo) end
                    elseif loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONMAINHAND" then
                        if not bestMH1H then
                            bestMH1H = makeWeaponRec(itemInfo)
                            -- Owning 2+ of the top one-hander (and able to dual-wield)
                            -- means a second copy wins the off-hand over any lesser 1H -
                            -- unless it is Unique-Equipped, where owning two still only
                            -- lets you WEAR one.
                            local uniq = itemInfo.data.uniqueLimit
                            if wantsDualWield and loc == "INVTYPE_WEAPON"
                               and (itemCounts[id] or 0) >= 2
                               and (not uniq or uniq >= 2) then
                                bestOH1H = makeWeaponRec(itemInfo)
                            end
                        elseif wantsDualWield and not bestOH1H and loc == "INVTYPE_WEAPON" then
                            bestOH1H = makeWeaponRec(itemInfo)
                        end
                    elseif loc == "INVTYPE_SHIELD" then
                        if not bestOffShield then bestOffShield = makeWeaponRec(itemInfo) end
                    elseif loc == "INVTYPE_HOLDABLE" or loc == "INVTYPE_WEAPONOFFHAND" then
                        if not bestOffHold then bestOffHold = makeWeaponRec(itemInfo) end
                    end
                end
            end

            -- Assemble enabled configs (a set forms as long as it has a main-hand item;
            -- the off-hand may be empty if the player owns nothing suitable yet).
            local weaponSets = {}
            local function addWeaponSet(key, mh, oh)
                if mh and Valuate:IsWeaponSetEnabled(scale, key) then
                    weaponSets[key] = { mh = mh, oh = oh, total = (mh.score or 0) + (oh and oh.score or 0) }
                end
            end
            addWeaponSet("TwoHand", bestMH2H, nil)
            addWeaponSet("OneHandShield", bestMH1H, bestOffShield)
            addWeaponSet("OneHandOffhand", bestMH1H, bestOffHold)
            addWeaponSet("DualWield", bestMH1H, bestOH1H)

            if next(weaponSets) then
                bestEquipment[scaleName].weaponSets = weaponSets

                -- Resolve the active set. An explicit choice always wins. Otherwise
                -- "auto" = the HIGHEST-SCORING set.
                --
                -- It used to prefer whichever set matched your currently-equipped
                -- weapons, which caused lock-in: equip a 1H and the active set flipped
                -- to OneHandShield, so a better 2H sitting in your bags disappeared from
                -- Main Hand and stopped counting as an upgrade - invisible precisely
                -- because you weren't using it. "Best" must mean best available, so the
                -- equipped setup is now only a tie-break between equal-scoring sets.
                local activeKey = scale.ActiveWeaponSet
                if not (activeKey and activeKey ~= "auto" and weaponSets[activeKey]) then
                    -- Iterate in DEFINITION order, not pairs(): Lua's table order is
                    -- undefined, and ties are common (with no shield or off-hand yet,
                    -- OneHandShield / OneHandOffhand / DualWield all form from the same
                    -- lone 1H and score identically). With pairs() the winner was
                    -- arbitrary AND could change between scans, so Main/Off Hand - and
                    -- what the upgrade prompt compares against - flipped around on its own.
                    --
                    -- Ties break toward the set with more positions actually filled, so a
                    -- real 1H+Shield beats a "set" that is just a bare main hand.
                    activeKey = nil
                    local bestTotal, bestFilled
                    for _, def in ipairs(WEAPON_SET_DEFS) do
                        local set = weaponSets[def.key]
                        if set then
                            local filled = (set.mh and 1 or 0) + (set.oh and 1 or 0)
                            if not bestTotal
                               or set.total > bestTotal
                               or (set.total == bestTotal and filled > bestFilled) then
                                bestTotal, bestFilled, activeKey = set.total, filled, def.key
                            end
                        end
                    end

                    -- Tie-break: if what you're wearing scores the same as the winner,
                    -- keep it, so an equal-value swap doesn't churn your gear.
                    local ohLink = GetInventoryItemLink("player", 17)
                    local mhLink = GetInventoryItemLink("player", 16)
                    local mhLoc = mhLink and select(9, GetItemInfo(mhLink)) or nil
                    local ohLoc = ohLink and select(9, GetItemInfo(ohLink)) or nil
                    local detected
                    if mhLoc == "INVTYPE_2HWEAPON" then
                        detected = "TwoHand"
                    elseif ohLoc == "INVTYPE_SHIELD" then
                        detected = "OneHandShield"
                    elseif ohLoc == "INVTYPE_HOLDABLE" or ohLoc == "INVTYPE_WEAPONOFFHAND" then
                        detected = "OneHandOffhand"
                    elseif ohLoc == "INVTYPE_WEAPON" or ohLoc == "INVTYPE_WEAPONMAINHAND" then
                        detected = "DualWield"
                    end
                    if detected and weaponSets[detected] and bestTotal
                       and weaponSets[detected].total >= bestTotal then
                        activeKey = detected
                    end
                end

                local active = weaponSets[activeKey]
                if active then
                    bestEquipment[scaleName].activeWeaponSet = activeKey
                    if not locks[16] then bestEquipment[scaleName][16] = active.mh end
                    if not locks[17] then bestEquipment[scaleName][17] = active.oh end
                end
            elseif scale.WeaponSets ~= nil then
                -- Every weapon config explicitly disabled: track no weapons.
                if not locks[16] then bestEquipment[scaleName][16] = nil end
                if not locks[17] then bestEquipment[scaleName][17] = nil end
            end

            -- Union of items that are the category-best for any ENABLED config, tagged
            -- with a display category. Drives the "Best <category> for" tooltip and the
            -- AdiBags "keep" decision (Phase 2) so gear for a non-active but enabled set
            -- is never dropped.
            local weaponKeep = {}
            local function keepWeapon(rec, category)
                if rec then weaponKeep[rec.itemId] = category end
            end
            if Valuate:IsWeaponSetEnabled(scale, "TwoHand") then keepWeapon(bestMH2H, "twohander") end
            if Valuate:IsWeaponSetEnabled(scale, "OneHandShield")
               or Valuate:IsWeaponSetEnabled(scale, "OneHandOffhand")
               or Valuate:IsWeaponSetEnabled(scale, "DualWield") then
                keepWeapon(bestMH1H, "onehander")
            end
            if Valuate:IsWeaponSetEnabled(scale, "OneHandShield") then keepWeapon(bestOffShield, "shield") end
            if Valuate:IsWeaponSetEnabled(scale, "OneHandOffhand") then keepWeapon(bestOffHold, "offhand") end
            if Valuate:IsWeaponSetEnabled(scale, "DualWield") then keepWeapon(bestOH1H, "onehander") end
            if next(weaponKeep) then
                bestEquipment[scaleName].weaponKeep = weaponKeep
            end

            -- Pass 2: record the best FUTURE upgrade per slot from items that are
            -- NOT yet equippable (too high level / unlearned proficiency). These are
            -- kept for reference only - never auto-equipped and never marked
            -- "Best for" on tooltips. Only items that would actually beat the current
            -- best in that slot are worth keeping. No copy accounting: a future item
            -- may show for every slot it fits (e.g. both rings).
            -- Weapons need a set-aware baseline here. Slots 16/17 hold the ACTIVE set's
            -- weapons, so judging a future weapon against them asks the wrong question:
            -- while you run a 2H, a one-hander that would hugely improve your 1H+Shield
            -- set scores below that 2H and was never recorded as a future upgrade - so
            -- AdiBags never kept it. GetUpgradeBaseline measures an item against the
            -- weakest position it could actually take across your enabled sets, which is
            -- the same rule quest rewards and auto-roll already use.
            local WEAPON_LOCS = {
                INVTYPE_2HWEAPON = true, INVTYPE_WEAPON = true,
                INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
                INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true,
            }

            local futureBest = {}
            -- itemId -> how many future slots it already occupies, so a
            -- Unique-Equipped item isn't listed as the future best for both rings.
            local futureUsage = {}
            for _, itemInfo in ipairs(itemsWithScores) do
                if not itemInfo.data.equippableNow then
                    local score = itemInfo.score
                    local data = itemInfo.data
                    local targetSlots = EquipSlotToInvNumber[data.itemEquipLoc]

                    -- Computed once per item; it does not vary by target slot.
                    local weaponBaseline
                    if WEAPON_LOCS[data.itemEquipLoc] and Valuate.GetUpgradeBaseline then
                        local ok, base = pcall(function()
                            return Valuate:GetUpgradeBaseline(data.itemLink, scale, scaleName)
                        end)
                        if ok and type(base) == "number" then weaponBaseline = base end
                    end

                    if targetSlots then
                        for _, targetSlotId in ipairs(targetSlots) do
                            if not locks[targetSlotId]
                               and not (targetSlotId == 17 and data.itemEquipLoc == "INVTYPE_WEAPON" and not wantsDualWield) then
                                local currentBest = bestEquipment[scaleName][targetSlotId]
                                local currentScore = weaponBaseline
                                    or (currentBest and currentBest.score or 0)
                                local existingFuture = futureBest[targetSlotId]
                                -- A unique item can only ever fill one of its slots.
                                local uniqueOk = true
                                if data.uniqueLimit then
                                    local used = futureUsage[itemInfo.itemId] or 0
                                    -- Re-placing it in a slot it already holds is fine;
                                    -- taking an ADDITIONAL slot is what's capped.
                                    local alreadyHere = existingFuture
                                        and existingFuture.itemLink == data.itemLink
                                    if not alreadyHere and used >= data.uniqueLimit then
                                        uniqueOk = false
                                    end
                                end
                                if uniqueOk and score > currentScore and (not existingFuture or score > existingFuture.score) then
                                    futureBest[targetSlotId] = {
                                        itemLink = data.itemLink,
                                        score = score,
                                        itemName = data.itemName,
                                        itemTexture = data.itemTexture,
                                        itemQuality = data.itemQuality,
                                        reqLevel = data.reqLevel or 0,
                                        source = data.source,
                                    }
                                    if data.uniqueLimit then
                                        futureUsage[itemInfo.itemId] = (futureUsage[itemInfo.itemId] or 0) + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if next(futureBest) then
                bestEquipment[scaleName].future = futureBest
            end
        end
    end
    
    if options.scanVerbose then
        print("|cFF00FF00[Valuate]|r Best equipment scan complete: " .. itemsProcessed .. " items processed from " .. itemsScanned .. " items scanned")
    end
    
    -- Notify UI to update if needed
    if Valuate.RefreshBestEquipmentDisplay then
        Valuate:RefreshBestEquipmentDisplay()
    end
    -- Tell integration modules (AdiBags/PassLoot) the data changed so they re-filter
    -- instead of showing the previous scan's categorisation.
    Valuate:NotifyBestEquipmentChanged()
    Valuate:MarkAutomation("scan", string.format("%d of %d items processed", itemsProcessed, itemsScanned))
    return true
end

-- Which inventory slots an item can go in, memoised by item ID.
--
-- The AdiBags filter asks two questions per item per repaint - is this best-in-slot, and is
-- it a future upgrade - and both used to call GetItemInfo for the same item to find out the
-- same immutable fact. tools/hotpath.js measured 240 calls for a 120-item bag.
--
-- Cached FOREVER and never invalidated, which is safe only because an item's equip location
-- is intrinsic: no enchant, gem, scaling or reforge moves a chest piece to the finger slot.
-- Keyed by item ID rather than link for the same reason - two links for one item differ by
-- enchants and gems, and keying on the link would fragment the cache for no gain.
--
-- The one thing that MUST not be cached is a miss. GetItemInfo returns nil for an item the
-- client has not received from the server yet; storing that would leave the item permanently
-- unequippable in Valuate's eyes, and it would fix itself only on a /reload. `false` means
-- "asked, and it genuinely goes nowhere", which is a different answer from "do not know yet".
local targetSlotsCache = {}
local function TargetSlotsForItem(itemLink, itemId)
    local cached = targetSlotsCache[itemId]
    if cached ~= nil then
        cacheStats.slotHit = cacheStats.slotHit + 1
        return cached or nil
    end
    cacheStats.slotMiss = cacheStats.slotMiss + 1

    local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
    if itemEquipLoc == nil then
        return nil  -- not cached client-side yet; ask again next time
    end

    local slots = (itemEquipLoc ~= "") and EquipSlotToInvNumber[itemEquipLoc] or nil
    targetSlotsCache[itemId] = slots or false
    return slots
end

-- Returns "best for" info for an item across active scales, or nil.
-- Each entry: { scaleName = <string>, category = <nil|"twohander"|"onehander"|"shield"|"offhand"> }.
-- Weapons are matched via each scale's weaponKeep union, so an item that is best in ANY
-- enabled weapon config is reported and tagged with its category. Everything else matches
-- the per-slot best-in-slot entry as before (category nil).
function Valuate:GetBestForInfo(itemLink)
    if not itemLink then return nil end
    if Valuate:IsItemExcludedFromEvaluation(itemLink) then return nil end

    local itemId = GetItemIdFromLink(itemLink)
    if not itemId then return nil end

    local bestEquipment = Valuate:GetBestEquipment()
    local activeScales = Valuate:GetActiveScales()
    local targetSlots = TargetSlotsForItem(itemLink, itemId)

    local results = {}
    for _, scaleName in ipairs(activeScales) do
        local be = bestEquipment[scaleName]
        if be then
            local category = be.weaponKeep and be.weaponKeep[itemId]
            if category then
                tinsert(results, { scaleName = scaleName, category = category })
            elseif targetSlots then
                for _, slotId in ipairs(targetSlots) do
                    local bestItem = be[slotId]
                    if bestItem and bestItem.itemLink
                       and GetItemIdFromLink(bestItem.itemLink) == itemId then
                        tinsert(results, { scaleName = scaleName, category = nil })
                        break
                    end
                end
            end
        end
    end

    return #results > 0 and results or nil
end

-- Checks if an item is the best-in-slot for any active scale.
-- Returns: table of scale names, or nil. Weapons count if best in any enabled config.
function Valuate:IsBestInSlot(itemLink)
    local info = Valuate:GetBestForInfo(itemLink)
    if not info then return nil end
    local names = {}
    for _, entry in ipairs(info) do
        tinsert(names, entry.scaleName)
    end
    return names
end

-- Formatted "★ Best [category] for: <scales>" tooltip line for an item, or nil if it
-- isn't best for any active scale. Excludes the hidden Valuate marker; callers that need
-- line-detection prepend it themselves.
local BEST_FOR_CATEGORY_LABELS = {
    twohander = "two-hander",
    onehander = "one-hander",
    shield = "shield",
    offhand = "off-hand",
}
function Valuate:BuildBestForLine(itemLink)
    local info = Valuate:GetBestForInfo(itemLink)
    if not info then return nil end

    local scales = Valuate:GetScales()
    local names = {}
    local category = nil
    for _, entry in ipairs(info) do
        if entry.category then category = entry.category end
        local scale = scales[entry.scaleName]
        if scale then
            local color = scale.Color or "FFFFFF"
            local displayName = scale.DisplayName or entry.scaleName
            tinsert(names, "|cFF" .. color .. displayName .. "|r")
        end
    end
    if #names == 0 then return nil end

    local catLabel = category and BEST_FOR_CATEGORY_LABELS[category]
    local prefix = catLabel and ("Best " .. catLabel .. " for:") or "Best for:"
    return "|cFFFFD700★ " .. prefix .. "|r " .. table.concat(names, ", ")
end

-- Checks whether an item is a tracked FUTURE upgrade for any active scale: an item
-- the character can't equip yet (e.g. requires a higher level) but which would beat
-- the current best-in-slot once usable. These are recorded in
-- bestEquipment[scale].future[slotId] by ScanBestEquipment's future pass.
-- Returns a table of scale names, or nil.
function Valuate:GetFutureUpgradeScales(itemLink)
    if not itemLink then return nil end
    if Valuate:IsItemExcludedFromEvaluation(itemLink) then return nil end

    local itemId = GetItemIdFromLink(itemLink)
    if not itemId then return nil end

    local targetSlots = TargetSlotsForItem(itemLink, itemId)
    if not targetSlots then return nil end

    local bestEquipment = Valuate:GetBestEquipment()
    local activeScales = Valuate:GetActiveScales()

    local results = {}
    for _, scaleName in ipairs(activeScales) do
        local be = bestEquipment[scaleName]
        local future = be and be.future
        if future then
            for _, slotId in ipairs(targetSlots) do
                local f = future[slotId]
                if f and f.itemLink and GetItemIdFromLink(f.itemLink) == itemId then
                    tinsert(results, scaleName)
                    break
                end
            end
        end
    end

    return #results > 0 and results or nil
end

-- The tooltip line for an item you cannot use yet but will.
--
-- The addon has known this since future upgrades existed and has been quietly acting on it:
-- IsProtectedFromDelete keeps such items, so auto-delete has been sparing them without ever
-- saying why. The moment that matters is at a vendor with a full bag, hovering the thing and
-- deciding - and the tooltip said nothing at all.
--
-- Reports the LEVEL as well as the scales, because "keep this" and "keep this for eleven
-- more levels" are different decisions. The level comes from the same future record the
-- protection reads, so the line cannot claim something the rest of the addon disagrees with.
--
-- Returns nil when there is nothing to say, so callers can add it unconditionally.
function Valuate:BuildFutureLine(itemLink)
    local scaleNames = Valuate:GetFutureUpgradeScales(itemLink)
    if not scaleNames or #scaleNames == 0 then return nil end

    local itemId = GetItemIdFromLink(itemLink)
    local bestEquipment = Valuate:GetBestEquipment()
    local scales = Valuate:GetScales()

    -- Lowest requirement across the scales that want it: the same item, so the earliest
    -- level is the true answer to "when can I wear this".
    local reqLevel
    local names = {}
    for _, scaleName in ipairs(scaleNames) do
        local scale = scales[scaleName]
        if scale then
            tinsert(names, "|cFF" .. (scale.Color or "FFFFFF") ..
                (scale.DisplayName or scaleName) .. "|r")
        end
        local future = bestEquipment[scaleName] and bestEquipment[scaleName].future
        if future and itemId then
            for _, f in pairs(future) do
                if f and f.itemLink and GetItemIdFromLink(f.itemLink) == itemId then
                    local lvl = f.reqLevel or 0
                    if lvl > 0 and (not reqLevel or lvl < reqLevel) then reqLevel = lvl end
                end
            end
        end
    end
    if #names == 0 then return nil end

    -- No level means the item is held back by something a level will not fix - a
    -- proficiency, most often. Saying "at level 0" would be worse than saying nothing
    -- specific, so the wording drops the promise instead of inventing one.
    local prefix = reqLevel
        and string.format("|cFF66CCFF Upgrade at level %d for:|r", reqLevel)
        or "|cFF66CCFF Upgrade once you can use it, for:|r"
    return prefix .. " " .. table.concat(names, ", ")
end

-- Announces gear that the level you just gained has made wearable.
--
-- The addon already tracks items you own that would be upgrades if you were high
-- enough - bestEquipment[scale].future[slotId], each carrying its reqLevel - and
-- nothing ever looked at them at the moment that data is FOR. Levelling on its own
-- triggers no rescan under most autoScan settings, so a piece carried since level 18
-- could sit in your bags long after it became wearable, with the addon quietly knowing.
--
-- Deliberately reports only what ACTUALLY left the future list, rather than everything
-- whose reqLevel you now meet. An item can sit there for reasons a level does not fix -
-- an unmet proficiency, for instance - and "your level is high enough" is not the same
-- claim as "you can wear this". So: note the candidates, rescan, then report the
-- difference.
-- Groups everything sitting in the future list by the level it unlocks at.
--
-- The data has been there since future upgrades existed; nothing ever let you LOOK at it.
-- The level-up announcement tells you what just became wearable, which is the right thing
-- at that moment and no help at all when you are deciding whether a piece is worth carrying
-- for another eight levels.
--
-- Pure: the scan results, the active scale list and a level go in; two sorted lists come
-- out. No client calls, so it is the part worth executing in a gate.
--
-- The second list is the interesting one. An item can sit in the future list for reasons a
-- level does not fix - an unmet weapon proficiency, most often - and lumping those in with
-- "you'll get this at 42" would be a promise the addon cannot keep. AnnounceUnlockedUpgrades
-- already draws that distinction by rescanning rather than trusting reqLevel; this draws it
-- by reporting them separately.
--
-- Returns: byLevel  = { { level = n, items = { { link, scales = {…} }, … } }, … } sorted
--          blocked  = { { link, scales = {…} }, … } - level is met, something else is not
local function GroupFutureUpgrades(bestEquipment, activeScales, playerLevel)
    if not bestEquipment or not activeScales then return {}, {} end
    playerLevel = playerLevel or 0

    -- link -> { level = n, scales = { name -> true } }. Keyed by link so an item that is a
    -- future upgrade for three scales is one line naming three, not three lines.
    local seen = {}
    for _, scaleName in ipairs(activeScales) do
        local future = bestEquipment[scaleName] and bestEquipment[scaleName].future
        if type(future) == "table" then
            for _, f in pairs(future) do
                if f and f.itemLink then
                    local entry = seen[f.itemLink]
                    if not entry then
                        entry = { level = f.reqLevel or 0, scales = {} }
                        seen[f.itemLink] = entry
                    end
                    -- Lowest requirement wins if two scales disagree: it is the same item,
                    -- and the earlier level is the true answer to "when can I wear this".
                    if (f.reqLevel or 0) < entry.level then entry.level = f.reqLevel or 0 end
                    entry.scales[scaleName] = true
                end
            end
        end
    end

    local levels, blocked = {}, {}
    for link, entry in pairs(seen) do
        local names = {}
        for name in pairs(entry.scales) do names[#names + 1] = name end
        table.sort(names)
        local row = { link = link, scales = names }

        if entry.level > playerLevel then
            levels[entry.level] = levels[entry.level] or {}
            tinsert(levels[entry.level], row)
        else
            tinsert(blocked, row)
        end
    end

    -- Sorted throughout: pairs() order is undefined, and a list that reshuffles between two
    -- identical runs reads as the data changing when it has not.
    local byLevel = {}
    for level, items in pairs(levels) do
        -- valuate-lint-ignore: sort-needs-tiebreaker  `seen` is KEYED by link, so no two rows here can share one - the comparator is already total
        table.sort(items, function(a, b) return a.link < b.link end)
        tinsert(byLevel, { level = level, items = items })
    end
    -- valuate-lint-ignore: sort-needs-tiebreaker  `levels` is keyed by level, so each appears exactly once
    table.sort(byLevel, function(a, b) return a.level < b.level end)
    -- valuate-lint-ignore: sort-needs-tiebreaker  same unique-link argument as above
    table.sort(blocked, function(a, b) return a.link < b.link end)

    return byLevel, blocked
end

-- /valuate future - what is waiting, and at what level.
function Valuate:PrintFutureUpgrades()
    local playerLevel = (UnitLevel and UnitLevel("player")) or 0
    local byLevel, blocked =
        GroupFutureUpgrades(Valuate:GetBestEquipment(), Valuate:GetActiveScales(), playerLevel)

    if #byLevel == 0 and #blocked == 0 then
        print("|cFF00FF00[Valuate]|r Nothing is waiting on a level. Anything in your bags that beats what you are wearing is already wearable - run /valuate scan if that seems wrong.")
        return true
    end

    if #byLevel > 0 then
        print(string.format("|cFF00FF00[Valuate]|r Waiting on your level (you are %d):", playerLevel))
        for _, group in ipairs(byLevel) do
            local gap = group.level - playerLevel
            print(string.format("  |cFFFFD100Level %d|r |cFFAAAAAA(%d away)|r", group.level, gap))
            for _, row in ipairs(group.items) do
                print(string.format("      %s |cFF888888for %s|r",
                    row.link, table.concat(row.scales, ", ")))
            end
        end
    end

    if #blocked > 0 then
        print("|cFFFF8800[Valuate]|r High enough level, but still not wearable:")
        for _, row in ipairs(blocked) do
            print(string.format("      %s |cFF888888for %s|r",
                row.link, table.concat(row.scales, ", ")))
        end
        print("|cFFAAAAAASomething other than your level is in the way - most often a weapon or armour proficiency you have not trained.|r")
    end
    return true
end

function Valuate:AnnounceUnlockedUpgrades(newLevel)
    if not newLevel then return end
    -- Convenience, not safety: this fires on every level, which for someone actually
    -- levelling is sixty-odd times. Anyone who turned chat messages off asked for
    -- exactly this to stop.
    if not Valuate:GetOptions().chatMessages then return end

    local candidates = {}
    local bestEquipment = Valuate:GetBestEquipment()
    for _, scaleName in ipairs(Valuate:GetActiveScales()) do
        local future = bestEquipment[scaleName] and bestEquipment[scaleName].future
        if future then
            for _, f in pairs(future) do
                if f and f.itemLink and (f.reqLevel or 0) <= newLevel then
                    candidates[f.itemLink] = true
                end
            end
        end
    end
    if not next(candidates) then return end

    -- Let the level actually apply before rescanning; PLAYER_LEVEL_UP fires before
    -- UnitLevel reports the new value on some 3.3.5 clients.
    --
    -- `attempt` exists because ScanBestEquipment REFUSES while an equipment swap is in
    -- flight, returning false. The first version ignored that return, so dinging in the
    -- middle of a swap meant the scan was declined, the future list was unchanged, and
    -- the announcement vanished - silently, at exactly the moment it was wanted.
    -- Bounded at three tries: if gear is still moving six seconds later, the next
    -- ordinary scan will fold the items in anyway, and it is not worth a timer that
    -- outlives the moment.
    local function attempt(triesLeft)
        local scanned = Valuate.ScanBestEquipment and Valuate:ScanBestEquipment()
        if not scanned and triesLeft > 0 then
            ValuateAfter(3, function() attempt(triesLeft - 1) end)
            return
        end

        local stillFuture = {}
        local after = Valuate:GetBestEquipment()
        for _, scaleName in ipairs(Valuate:GetActiveScales()) do
            local future = after[scaleName] and after[scaleName].future
            if future then
                for _, f in pairs(future) do
                    if f and f.itemLink then stillFuture[f.itemLink] = true end
                end
            end
        end

        local unlocked = {}
        for link in pairs(candidates) do
            if not stillFuture[link] then tinsert(unlocked, link) end
        end
        if #unlocked == 0 then return end
        -- pairs() gave no order and this is user-visible; sort it.
        table.sort(unlocked)

        print(string.format("|cFF00FF00Valuate|r: level %d unlocked %d item(s) you already have:",
            newLevel, #unlocked))
        for i = 1, math.min(#unlocked, 5) do
            print("  " .. unlocked[i])
        end
        if #unlocked > 5 then
            print(string.format("  |cFFAAAAAA...and %d more.|r", #unlocked - 5))
        end
        print("  |cFFAAAAAA/valuate equip|r equips the best set, or check Best Equipment.")
    end

    ValuateAfter(2, function() attempt(3) end)
end

-- Checks if the player owns an item (equipped or in bags)
-- itemLink: The item link to check
-- Returns: true if player owns the item, false otherwise
function Valuate:PlayerOwnsItem(itemLink)
    if not itemLink then return false end
    
    -- Get item ID for comparison (handles unique suffixes)
    local itemId = GetItemIdFromLink(itemLink)
    if not itemId then return false end
    
    -- Check equipped slots (1-18, skip 4=shirt)
    for slotId = 1, 18 do
        if slotId ~= 4 then
            local equippedLink = GetInventoryItemLink("player", slotId)
            if equippedLink then
                local equippedId = GetItemIdFromLink(equippedLink)
                if equippedId == itemId then
                    return true
                end
            end
        end
    end
    
    -- Check bags (0-4)
    for bagId = 0, 4 do
        local numSlots = GetContainerNumSlots(bagId)
        for slotId = 1, numSlots do
            local bagItemLink = GetContainerItemLink(bagId, slotId)
            if bagItemLink then
                local bagItemId = GetItemIdFromLink(bagItemLink)
                if bagItemId == itemId then
                    return true
                end
            end
        end
    end
    
    -- The bank can't be read unless it's open, so consult the snapshot taken on
    -- the last visit instead. It may be stale (gear withdrawn since), which is the
    -- right trade here: this answers "do I already own one?", and a false positive
    -- only means we don't flag a duplicate as new.
    if Valuate:GetOptions().includeBankItems then
        if Valuate:GetBankCache().items[itemId] then
            return true
        end
    end

    return false
end

-- Clears best equipment data for a specific scale
-- scaleName: Name of the scale to clear data for
-- Clears best equipment data for a specific scale (respects locked slots)
function Valuate:ClearBestEquipmentForScale(scaleName)
    if not scaleName then return false end
    
    local bestEquipment = Valuate:GetBestEquipment()
    if bestEquipment[scaleName] then
        -- Store locked slots before clearing
        local locks = bestEquipment[scaleName].locks
        local lockedItems = {}
        
        if locks then
            -- Save items from locked slots
            for slotId, isLocked in pairs(locks) do
                if isLocked and bestEquipment[scaleName][slotId] then
                    lockedItems[slotId] = bestEquipment[scaleName][slotId]
                end
            end
        end
        
        -- Clear all data
        bestEquipment[scaleName] = {}
        
        -- Restore locks and locked items
        if locks then
            bestEquipment[scaleName].locks = locks
            for slotId, itemData in pairs(lockedItems) do
                bestEquipment[scaleName][slotId] = itemData
            end
        end
        
        local lockedCount = 0
        for _ in pairs(lockedItems) do lockedCount = lockedCount + 1 end
        
        local options = Valuate:GetOptions()
        if options.chatMessages then
            if lockedCount > 0 then
                print("|cFF00FF00[Valuate]|r Cleared best equipment for scale: " .. scaleName .. " (kept " .. lockedCount .. " locked slots)")
            else
                print("|cFF00FF00[Valuate]|r Cleared best equipment for scale: " .. scaleName)
            end
        end
        
        -- Refresh display if needed
        if Valuate.RefreshBestEquipmentDisplay then
            Valuate:RefreshBestEquipmentDisplay()
        end
        Valuate:NotifyBestEquipmentChanged()

        return true
    end

    return false
end

-- Converts an icon texture path to an icon index for SaveEquipmentSet
-- iconPath: Full icon path (e.g., "Interface\\Icons\\Spell_Holy_HolyBolt")
-- Returns: Icon index (number) or 1 if not found
function Valuate:GetIconIndexFromPath(iconPath)
    if not iconPath or iconPath == "" then
        return nil  -- Return nil instead of 1 to indicate "not found"
    end
    
    -- Extract just the filename from the path
    local iconName = iconPath:match("([^\\]+)$")
    if not iconName then
        return nil
    end
    
    -- First check macro icons (positive indices, equipment sets prefer these)
    local numMacroIcons = GetNumMacroIcons()
    if numMacroIcons and numMacroIcons > 0 then
        for i = 1, numMacroIcons do
            local macroIcon = GetMacroIconInfo(i)
            if macroIcon then
                local macroIconName = macroIcon:match("([^\\]+)$")
                if macroIconName == iconName then
                    return i
                end
            end
        end
    end
    
    -- Then check item icons (negative indices)
    local numItemIcons = GetNumMacroItemIcons()
    if numItemIcons and numItemIcons > 0 then
        for i = 1, numItemIcons do
            local itemIcon = GetMacroItemIconInfo(i)
            if itemIcon then
                local itemIconName = itemIcon:match("([^\\]+)$")
                if itemIconName == iconName then
                    return -i  -- Negative index for item icons
                end
            end
        end
    end
    
    -- Not found, return nil to indicate caller should use texture path
    return nil
end

-- Creates an equipment set from the best items for a given scale
-- scaleName: Name of the scale to create gearset for
-- setName: Name for the equipment set (defaults to scale display name)
-- override: If true, will delete existing set with same name first
-- Returns: true if successful, false otherwise
-- SAFE VERSION: Creates a gear set from CURRENTLY equipped items (no auto-equipping)
-- User must manually equip items before calling this
function Valuate:CreateGearSetFromCurrentEquipment(scaleName, setName, override, suppressHints)
    if not scaleName then return false end
    
    local bestEquipment = Valuate:GetBestEquipment()
    local scales = Valuate:GetScales()
    local scale = scales[scaleName]
    
    if not scale or not bestEquipment[scaleName] then
        print("|cFFFF0000[Valuate]|r No best equipment data found for scale: " .. (scaleName or "nil"))
        return false
    end
    
    -- Default set name is the scale, suffixed with the active weapon set in shorthand
    -- (e.g. "Retribution (2H)") so each weapon configuration gets its own WoW set
    -- rather than overwriting the others. An explicit setName is used verbatim.
    local finalSetName = setName
    if not finalSetName then
        finalSetName = scale.DisplayName or scaleName
        local short = Valuate:GetActiveWeaponSetShort(scaleName)
        if short then
            finalSetName = finalSetName .. " (" .. short .. ")"
        end
    end

    -- Check if set name already exists and delete it (always override)
    for i = 1, GetNumEquipmentSets() do
        local existingName = GetEquipmentSetInfo(i)
        if existingName == finalSetName then
            DeleteEquipmentSet(i)
            break
        end
    end
    
    -- Check if we're at the limit
    if GetNumEquipmentSets() >= 10 then
        print("|cFFFF0000[Valuate]|r Maximum number of equipment sets (10) reached. Please delete one first.")
        return false
    end
    
    -- SAFE: Just save whatever is currently equipped, no auto-equipping
    -- Get icon index for the set
    local iconIndex = 1  -- Default icon index
    if scale.Icon and scale.Icon ~= "" then
        local foundIndex = Valuate:GetIconIndexFromPath(scale.Icon)
        if foundIndex then
            iconIndex = foundIndex
        end
    end
    
    -- Save the equipment set (saves current equipment)
    SaveEquipmentSet(finalSetName, iconIndex)
    
    local options = Valuate:GetOptions()
    if options.chatMessages then
        print("|cFF00FF00[Valuate]|r Saved equipment set '" .. finalSetName .. "' from your equipped items.")
        if not suppressHints then
            print("|cFFFFAA00[Valuate]|r IMPORTANT: The set saves what you're WEARING, not what's shown in Best Equipment.")
            print("|cFFFFAA00[Valuate]|r Manually equip your best items BEFORE clicking 'Create Set'.")
        end
    end
    
    return true
end

-- ========================================
-- Bag-upgrade notification
-- ========================================
-- When an equippable upgrade for your CURRENT scale is sitting in your bags, offer a
-- one-click "equip best set" popup - out of combat only. Opt-in; re-prompts each loot
-- event by default (or only when the available upgrades change).
-- (bagUpgradePending is declared at the top of this file, next to the other event-
-- handler flags - the PLAYER_REGEN_ENABLED handler up there reads it.)
local lastNotifiedSignature = nil    -- "oncePerUpgrade" dedupe
local pendingEquipScale = nil        -- scale the popup's Equip button will act on

-- NOTE: this prompt deliberately does NOT use Blizzard's StaticPopup system.
-- Those frames are recycled, and showing an addon dialog on one taints it; when
-- Blizzard later reuses that frame for a secure dialog (e.g. USE_BIND) the secure
-- call gets tainted and blocked. Valuate:ShowConfirmDialog is our own frame.

-- Counts slots whose best-in-slot item for scaleName is NOT the one currently worn -
-- i.e. an equippable upgrade is in the bags. best[slot] only ever holds an
-- equippable-now item (future upgrades live under .future), so a mismatch is a real,
-- wearable upgrade. Skips locked slots. Returns count and a signature string.
function Valuate:CountEquippableUpgrades(scaleName)
    if not scaleName then return 0, "" end
    local be = Valuate:GetBestEquipment()[scaleName]
    if not be then return 0, "" end
    local locks = be.locks or {}
    local scale = Valuate:GetScales()[scaleName]
    local count, sig, bankCount = 0, {}, 0
    -- Biggest single equippable gain, so the popup can show WHICH item rather than
    -- just a number. Only tracked for reachable gear - offering to equip something
    -- in the bank is exactly the prompt-with-a-dead-button case below.
    local top
    for slotId = 1, 18 do
        if slotId ~= 4 and not locks[slotId] then
            local best = be[slotId]
            if best and best.itemLink then
                local bestId = GetItemIdFromLink(best.itemLink)
                local curLink = GetInventoryItemLink("player", slotId)
                local curId = curLink and GetItemIdFromLink(curLink)
                if bestId and bestId ~= curId then
                    -- Banked gear is a real upgrade but NOT an equippable one:
                    -- EquipItemByName can't reach the bank. Counting it here would
                    -- make the notify prompt offer "Equip Best Set" for something
                    -- EquipBestSet then skips - a prompt whose button does nothing.
                    -- Reported separately so the message can still mention it.
                    if best.source == "bank" then
                        bankCount = bankCount + 1
                    else
                        count = count + 1
                        sig[#sig + 1] = slotId .. ":" .. bestId

                        if scale then
                            local eq = Valuate:GetEquippedItemScoreBySlotId(slotId, scale) or 0
                            local delta = (best.score or 0) - eq
                            -- Strict >: ties keep the first slot, which is
                            -- deterministic because slotId ascends.
                            if delta > 0 and (not top or delta > top.delta) then
                                top = {
                                    itemLink = best.itemLink,
                                    itemName = best.itemName,
                                    itemTexture = best.itemTexture,
                                    itemQuality = best.itemQuality,
                                    slotId = slotId,
                                    delta = delta,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return count, table.concat(sig, ","), bankCount, top
end

-- Shows/refreshes the bag-upgrade popup for the current scale. trigger is "loot" or
-- "scan": "everyLoot" mode only pops on a loot trigger; "oncePerUpgrade" pops whenever
-- the available-upgrade set changes. Always hides the popup once nothing's left to equip.
-- verbose: report each gate to chat (used by /valuate notifycheck) instead of failing
-- silently, so it's obvious WHY no prompt appeared.
function Valuate:CheckBagUpgradeNotify(trigger, verbose)
    local function say(msg) if verbose then print("|cFFAAAAAA[Valuate notify]|r " .. msg) end end

    local options = Valuate:GetOptions()
    if not options.notifyBagUpgrade and not verbose then return end
    if not options.notifyBagUpgrade then
        say("option is OFF - enable 'Notify Bag Upgrades' in Settings (checking anyway).")
    end

    local scale, scaleName = Valuate:GetPrimaryScale()
    if not scale then
        say("no active scale to compare against - activate a scale first.")
        return
    end
    say("active spec: " .. (scale.DisplayName or scaleName))

    -- Out of combat / alive only; otherwise defer to PLAYER_REGEN_ENABLED.
    if InCombatLockdown() then
        bagUpgradePending = true
        say("in combat - deferred until you leave combat.")
        return
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        say("you're dead/ghost - skipped.")
        return
    end

    local count, sig, bankCount, topUpgrade = Valuate:CountEquippableUpgrades(scaleName)
    say("equippable upgrades in bags: " .. count)
    if bankCount > 0 then
        say("upgrades sitting in your bank (not equippable from here): " .. bankCount)
    end
    if count == 0 then
        lastNotifiedSignature = nil
        -- Nothing left to equip: take the prompt down. Must target the UPGRADE popup
        -- (the confirm dialog is a different frame), or it would linger on screen
        -- offering to equip gear you are already wearing.
        if Valuate.HideUpgradePopup then Valuate:HideUpgradePopup() end
        if bankCount > 0 then
            -- Don't claim they're wearing the best when better gear is banked.
            say(bankCount .. " upgrade(s) are in your bank - withdraw them, then this will prompt.")
        else
            say("nothing to prompt about (you're already wearing the best equippable items).")
        end
        say("if you expect an upgrade, run /valuate scan first - the prompt uses scan results.")
        return
    end

    local mode = options.notifyBagUpgradeMode or "everyLoot"
    local shouldShow
    if mode == "oncePerUpgrade" then
        shouldShow = (sig ~= lastNotifiedSignature)
        if not shouldShow then say("mode 'once per upgrade': already prompted for these exact items.") end
    else -- everyLoot
        shouldShow = (trigger == "loot")
        if not shouldShow then say("mode 'every loot': only prompts on a loot event (this was a '" .. tostring(trigger) .. "' check).") end
    end
    if verbose then shouldShow = true end  -- an explicit check always shows the prompt
    if not shouldShow then
        Valuate:MarkAutomation("upgradeNotify",
            string.format("%d upgrade(s) found, prompt suppressed by '%s' mode", count, mode))
        return
    end

    Valuate:MarkAutomation("upgradeNotify", string.format("prompted for %d upgrade(s)", count))
    lastNotifiedSignature = sig
    pendingEquipScale = scaleName

    local label = scale.DisplayName or scaleName
    local bankNote = bankCount > 0
        and string.format(" (%d more in your bank)", bankCount)
        or ""

    -- Upgrades for your OTHER specs. The primary-scale check above cannot see these
    -- at all, so on a classless server - where one drop often suits a spec you aren't
    -- currently running - they would otherwise be silently vendored or left behind.
    -- Scales are listed in GetActiveScales order, which is already deterministic.
    local otherNote = ""
    if options.notifyOtherSpecUpgrades then
        local scales = Valuate:GetScales()
        local others = {}
        for _, otherName in ipairs(Valuate:GetActiveScales()) do
            if otherName ~= scaleName then
                local n = Valuate:CountEquippableUpgrades(otherName)
                if n > 0 then
                    local s = scales[otherName]
                    others[#others + 1] = string.format("%s (%d)", (s and s.DisplayName) or otherName, n)
                end
            end
        end
        if #others > 0 then
            otherNote = "Also upgrades for: " .. table.concat(others, ", ")
            say("other specs with upgrades: " .. table.concat(others, ", "))
        end
    end

    if (options.notifyBagUpgradeStyle or "dialog") == "chat" then
        -- Chat-only: same detection, no popup. For players who want to know without
        -- a dialog stealing focus mid-fight.
        print(string.format(
            "|cFF00FF00[Valuate]|r %d upgrade(s) for %s are in your bags%s - /valuate equip to wear them.",
            count, label, bankNote))
        -- Separate print: chat frames don't break on \n, so an appended line would
        -- run together with the one above.
        if otherNote ~= "" then print("|cFF00FF00[Valuate]|r " .. otherNote) end
    elseif Valuate.ShowUpgradePopup then
        Valuate:ShowUpgradePopup({
            count = count,
            bankCount = bankCount,
            scale = scale,
            scaleName = scaleName,
            top = topUpgrade,
            onEquip = function()
                if pendingEquipScale and Valuate.EquipBestSet then
                    Valuate:EquipBestSet(pendingEquipScale)
                end
            end,
        })
        -- Other-spec upgrades don't belong in a compact popup about THIS spec, so
        -- they go to chat where the detail has room.
        if otherNote ~= "" then
            print("|cFF00FF00[Valuate]|r " .. otherNote)
        end
    end

    if options.notifyUpgradeSound then
        -- PlaySound is unprotected and safe from an addon; guarded because Ascension
        -- clients have been known to trim FrameXML globals.
        if type(PlaySound) == "function" then PlaySound("igQuestListComplete") end
    end
    -- Celebratory cue on the minimap button so the upgrade is noticed even if the
    -- popup is off-screen or dismissed.
    if Valuate.PulseMinimapButton then Valuate:PulseMinimapButton() end
end

-- ========================================
-- Bind confirmations
-- ========================================
-- Equipping a bind-on-equip item raises EQUIP_BIND_CONFIRM; with nothing answering it
-- the equip silently doesn't happen, which stalls Equip All on BoE upgrades.
--
-- Auto-confirming a bind is consequential (it destroys the item's trade/AH value), so
-- we deliberately do NOT blanket-confirm. Valuate records a short-lived "I started this
-- equip" intent and only confirms while that intent is live - a bind prompt you raised
-- yourself by manually equipping something still behaves exactly as it always has.
local equipIntentUntil = 0

function Valuate:MarkEquipIntent(seconds)
    equipIntentUntil = GetTime() + (seconds or 5)
end

local function HasEquipIntent()
    return GetTime() <= equipIntentUntil
end

-- Handles the bind-confirmation events. slot semantics differ per event, so each is
-- passed through to its matching API. Every API is feature-detected because these vary
-- across 3.3.5 client builds.
function Valuate:HandleBindConfirm(event, slot)
    local options = Valuate:GetOptions()

    if event == "EQUIP_BIND_CONFIRM" or event == "AUTOEQUIP_BIND_CONFIRM" then
        -- Only when Valuate initiated the equip.
        if HasEquipIntent() and EquipPendingItem then
            EquipPendingItem(slot)
        end
    elseif event == "LOOT_BIND_CONFIRM" then
        -- Raised by YOUR looting, not by Valuate, so it needs its own opt-in.
        if options.autoConfirmBindOnLoot and ConfirmLootSlot then
            ConfirmLootSlot(slot)
        end
    end
    -- NOTE: USE_BIND_CONFIRM is deliberately NOT handled. Using an item is a protected
    -- path, so an addon calling ConfirmBindOnUse() taints it and the client then blocks
    -- the actual use ("Valuate has been blocked from an action only available to the
    -- Blizzard UI") - which broke legitimate bind-on-use items such as Ascension's
    -- vanity sync. Answer that popup yourself; it's one click and it always works.
end

-- Equips every currently-equippable best-in-slot item for a scale in one go, so the
-- player doesn't have to right-click each slot. Skips locked slots and anything
-- already worn. Then (unless disabled) integrates with WoW's Equipment Manager by
-- saving/updating a set named after the scale once the swaps settle, so it can be
-- re-equipped from the character panel or a /equipset macro later.
-- Returns the number of items it began equipping, or false if it couldn't run.
function Valuate:EquipBestSet(scaleName)
    if not scaleName then return false end
    local options = Valuate:GetOptions()

    if InCombatLockdown() then
        print("|cFFFF0000[Valuate]|r Can't change equipment in combat.")
        return false
    end

    local bestEquipment = Valuate:GetBestEquipment()
    local be = bestEquipment[scaleName]
    if not be then
        print("|cFFFF8800[Valuate]|r No best equipment for this scale yet - run a scan first.")
        return false
    end

    local scales = Valuate:GetScales()
    local scale = scales[scaleName]
    local locks = be.locks or {}

    -- Tell the bind-confirm handler these equips are ours, so BoE upgrades don't stall
    -- on the "this will bind to you" popup. Generous window: equips are asynchronous.
    Valuate:MarkEquipIntent(8)

    local equipped, inBank = 0, 0
    for slotId = 1, 18 do
        -- Skip shirt (4) and any slot the user locked.
        if slotId ~= 4 and not locks[slotId] then
            local item = be[slotId]
            if item and item.source == "bank" then
                -- Best-in-slot, but sitting in the bank: EquipItemByName can't reach
                -- it. Count it so we can say so instead of quietly equipping less
                -- than the panel shows.
                inBank = inBank + 1
            elseif item and item.itemLink then
                local cur = GetInventoryItemLink("player", slotId)
                local curId = cur and GetItemIdFromLink(cur)
                if curId ~= GetItemIdFromLink(item.itemLink) then
                    -- EquipItemByName targets the specific slot, so multi-slot items
                    -- (rings/trinkets/1H) go exactly where the scan assigned them.
                    EquipItemByName(item.itemLink, slotId)
                    equipped = equipped + 1
                end
            end
        end
    end

    -- Deliberately does NOT pin the active set. Equipping is not the same as choosing:
    -- pinning an "auto" scale here froze it on whatever you happened to equip, so a
    -- better configuration found later (e.g. a stronger 2H in your bags) could never
    -- become active again - it silently stopped being offered as an upgrade.
    -- An explicit choice still sticks: clicking a weapon-set row in the Best Equipment
    -- panel, or the scale editor's Active-set button, sets scale.ActiveWeaponSet.
    -- On "auto" the set we just equipped IS the highest-scoring one, so the panel's
    -- marker and flash already point at it.

    local label = (scale and (scale.DisplayName or scaleName)) or scaleName
    if options.chatMessages then
        if equipped > 0 then
            print(string.format("|cFF00FF00[Valuate]|r Equipping %d best item(s) for %s.", equipped, label))
        elseif inBank == 0 then
            print("|cFF00FF00[Valuate]|r Already wearing the best items for " .. label .. ".")
        end
    end
    -- Always reported, even with chat messages off: "Equip All did nothing" with no
    -- explanation is precisely the silent failure this addon is not allowed to have.
    if inBank > 0 then
        print(string.format(
            "|cFFFF8800[Valuate]|r %d best item(s) for %s are in your bank - withdraw them, then Equip All again.",
            inBank, label))
    end

    -- NOTE: saving a WoW equipment set is deliberately NOT done here. Equipping and
    -- overwriting a saved set are separate intentions, so the set snapshot lives behind
    -- its own "Save Set" button (Valuate:SaveEquipmentSetForScale).

    return equipped
end

-- Snapshots the gear you are CURRENTLY WEARING into a WoW equipment set named after
-- the scale (suffixed with the active weapon set, e.g. "Retribution (2H)"). Separate
-- from EquipBestSet so equipping and overwriting a saved set stay independent actions.
function Valuate:SaveEquipmentSetForScale(scaleName)
    if not scaleName then return false end

    if InCombatLockdown() then
        print("|cFFFF0000[Valuate]|r Can't save an equipment set in combat.")
        return false
    end
    if not GetNumEquipmentSets or not SaveEquipmentSet then
        print("|cFFFF0000[Valuate]|r This client doesn't expose the equipment manager API.")
        return false
    end

    local ok, result = pcall(function()
        return Valuate:CreateGearSetFromCurrentEquipment(scaleName, nil, nil, true)
    end)
    if not ok then
        print("|cFFFF0000[Valuate]|r Failed to save the equipment set.")
        return false
    end
    return result
end

-- OLD FUNCTION REMOVED - Use Blizzard's equipment manager directly to switch sets
-- This prevents potential issues with programmatic equipment changes

-- Cleans up orphaned best equipment data for scales that no longer exist
function Valuate:CleanupOrphanedBestEquipment()
    local bestEquipment = Valuate:GetBestEquipment()
    local scales = Valuate:GetScales()
    local removed = 0
    
    -- Iterate through all best equipment data
    for scaleName, _ in pairs(bestEquipment) do
        -- If the scale no longer exists, remove its best equipment data
        if not scales[scaleName] then
            bestEquipment[scaleName] = nil
            removed = removed + 1
        end
    end
    
    if removed > 0 then
        local options = Valuate:GetOptions()
        if options.chatMessages then
            print("|cFF00FF00[Valuate]|r Cleaned up best equipment data for " .. removed .. " removed scale(s)")
        end
    end
    
    return removed
end


-- ========================================
-- Auto Quest Reward Selection
-- ========================================

-- Determines which scale drives automatic decisions (currently quest rewards).
-- Prefers the character-window scale if it is active, otherwise the first
-- active scale. Returns scaleData, scaleName - or nil if no scale is active.
-- Deliberately does NOT go through GetActiveScales, for two reasons.
--
-- Correctness: that list used to be built in pairs() order, so "the first active
-- scale" was whichever one Lua happened to hand over first. This is the answer that
-- decides which scale drives the upgrade arrows, the character-sheet score and the
-- auto-roll baseline, so it must not vary between reloads. GetActiveScales is sorted
-- now, but picking the minimum directly says what is meant rather than depending on
-- somebody else's ordering staying put.
--
-- Cost: this is called for EVERY item icon on EVERY bag repaint, from the top of
-- IsItemLinkUpgrade, before its cache is even consulted - so the cache never saved
-- this part. Building and sorting a list to read one element from it, a hundred times
-- per repaint, is pure garbage for the collector to deal with mid-combat. Scanning for
-- the minimum allocates nothing.
function Valuate:GetPrimaryScale()
    local scales = Valuate:GetScales()
    if not scales then return nil, nil end

    -- The explicitly-chosen scale wins, provided it is actually active.
    local preferred = Valuate:GetOptions().characterWindowScale
    if preferred and preferred ~= "" then
        local chosen = scales[preferred]
        if chosen and chosen.Values and chosen.Visible ~= false then
            return chosen, preferred
        end
    end

    -- Otherwise the first active scale in the same order GetActiveScales uses, found
    -- without building the list.
    local bestName, bestDisplay
    for name, data in pairs(scales) do
        if data.Values and data.Visible ~= false then
            local display = data.DisplayName or name
            if not bestName or display < bestDisplay
               or (display == bestDisplay and name < bestName) then
                bestName, bestDisplay = name, display
            end
        end
    end

    if not bestName then return nil, nil end
    return scales[bestName], bestName
end

-- Scores a single quest reward choice for the given scale.
-- Reads SCALED stats directly from the quest item tooltip (Ascension scales
-- quest rewards too), and honors the scale's banned ("Unusable") stats exactly
-- like the item tooltips do. Returns a score, or nil if it can't/shouldn't be
-- scored (non-gear reward, banned stats, tooltip failure).
-- ========================================
-- Shared upgrade evaluation API
-- ========================================

-- Does this scale ban the item? Mirrors the checks used by the tooltip, the
-- best-equipment scan and quest scoring: any banned stat present, plus equip-location
-- backstops for weapon bans the tooltip parse can miss.
local function ScaleBansItem(scale, stats, equipLoc)
    if not scale or not scale.Unusable then return false end

    if stats then
        for statName, statValue in pairs(stats) do
            if scale.Unusable[statName] and statValue and statValue > 0 then
                return true
            end
        end
    end

    if equipLoc then
        if (equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND") and scale.Unusable["OneHandDps"] then
            return true
        elseif equipLoc == "INVTYPE_2HWEAPON" and scale.Unusable["TwoHandDps"] then
            return true
        elseif equipLoc == "INVTYPE_WEAPONOFFHAND" and scale.Unusable["OffHandDps"] then
            return true
        elseif (equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN") and scale.Unusable["RangedDps"] then
            return true
        end
    end

    return false
end

-- Populates the private tooltip through one of its Set* methods and returns the parsed
-- stats, e.g. Valuate:GetStatsForTooltipSetter("SetLootRollItem", rollID) or
-- ("SetQuestItem", "choice", index). Returns nil if the setter fails or nothing parsed.
function Valuate:GetStatsForTooltipSetter(setterName, ...)
    local tooltip = GetPrivateTooltip()
    if not tooltip or type(tooltip[setterName]) ~= "function" then return nil end

    tooltip:ClearLines()
    local args = { ... }
    local ok = pcall(function() tooltip[setterName](tooltip, unpack(args)) end)
    if not ok then return nil end

    local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
    if not stats or not next(stats) then return nil end
    return stats
end

-- Sums the stats across everything you are wearing.
--
-- Slot 4 (Shirt) and 19 (Tabard) are skipped: they carry no stats, and a slot that can
-- never contribute is noise in a diagnostic about what contributes.
function Valuate:GetEquippedStatTotals()
    local totals, slotsRead = {}, 0
    for slotId = 1, 18 do
        if slotId ~= 4 then
            local link = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
            if link then
                local stats = Valuate:GetStatsForTooltipSetter("SetInventoryItem", "player", slotId)
                if stats then
                    slotsRead = slotsRead + 1
                    for statName, value in pairs(stats) do
                        totals[statName] = (totals[statName] or 0) + value
                    end
                end
            end
        end
    end
    return totals, slotsRead
end

-- Cached equipped totals, for callers on a hover path.
--
-- GetEquippedStatTotals reads seventeen slots through the private tooltip, which is what
-- a scan costs and far too much to repeat every time the mouse crosses a row. The totals
-- only change when you change gear, so a short TTL is enough - and it is a TTL rather than
-- event invalidation deliberately: hooking PLAYER_EQUIPMENT_CHANGED would mean editing the
-- handler that carries the in-transit scan guards, which is the one place in this addon
-- not worth touching for a tooltip.
--
-- Five seconds. Long enough that hovering along a column of sixty stat rows costs one
-- scan, short enough that gear you just equipped is reflected by the time you look.
local statTotalsCache, statTotalsAt, statTotalsSlots = nil, 0, 0
local STAT_TOTALS_TTL = 5

function Valuate:GetCachedEquippedStatTotals()
    local now = (GetTime and GetTime()) or 0
    -- `now < statTotalsAt` catches a clock that went backwards (a /reload resets GetTime),
    -- which would otherwise pin a stale cache for as long as the difference.
    if not statTotalsCache or now - statTotalsAt > STAT_TOTALS_TTL or now < statTotalsAt then
        statTotalsCache, statTotalsSlots = Valuate:GetEquippedStatTotals()
        statTotalsAt = now
    end
    return statTotalsCache, statTotalsSlots
end

-- What one stat is doing for one scale, right now.
--
-- Goes through RankStatShares - the same function /valuate weights uses - rather than
-- doing the arithmetic again here. Two copies of one calculation is how the tooltip and
-- its row ended up disagreeing about empty slots, and how the percentage ended up dividing
-- by a signed baseline in one place and a magnitude in the other.
--
-- The RANKING is recomputed per call while the TOTALS are cached: your weights change as
-- you type, and a share that did not move when you changed the number would be worse than
-- no share at all.
--
-- Returns: entry (nil if the stat contributes nothing), isIdle, slotsRead.
function Valuate:GetStatShareInfo(statName, scale)
    if not statName or not scale or not scale.Values then return nil, false, 0 end
    local totals, slotsRead = Valuate:GetCachedEquippedStatTotals()
    if slotsRead == 0 then return nil, false, 0 end

    local ranked, idle = RankStatShares(totals, scale)
    if not ranked then return nil, false, slotsRead end

    for _, entry in ipairs(ranked) do
        if entry.stat == statName then return entry, false, slotsRead end
    end
    for _, name in ipairs(idle) do
        if name == statName then return nil, true, slotsRead end
    end
    return nil, false, slotsRead
end

-- /valuate weights - which of this scale's weights are actually doing anything.
function Valuate:PrintStatShares(scaleName)
    local scale
    if scaleName and scaleName ~= "" then
        scale = Valuate:GetScales()[scaleName]
        if not scale then
            print("|cFFFF0000[Valuate]|r No scale called '" .. scaleName .. "'.")
            return true
        end
    else
        scale, scaleName = Valuate:GetPrimaryScale()
    end
    if not scale then
        print("|cFFFF0000[Valuate]|r No active scale - activate one first.")
        return true
    end

    local totals, slotsRead = Valuate:GetEquippedStatTotals()
    if slotsRead == 0 then
        print("|cFFFF8800[Valuate]|r Could not read any equipped item. If you are wearing gear, the client may not have cached it yet - try again in a moment.")
        return true
    end

    local ranked, idle, total = RankStatShares(totals, scale)
    if not ranked then
        print("|cFFFF0000[Valuate]|r That scale has no stat weights set.")
        return true
    end

    local label = scale.DisplayName or scaleName
    local decimals = Valuate:GetOptions().decimalPlaces or 1
    local fmt = "%." .. decimals .. "f"

    print(string.format("|cFF00FF00[Valuate]|r What is driving your |cFFFFD100%s|r score, across %d equipped item(s):",
        label, slotsRead))

    if #ranked == 0 then
        print("|cFFFF8800Nothing.|r Not one of this scale's weighted stats appears on your gear.")
    end
    for i, e in ipairs(ranked) do
        local name = (ValuateStatNames and ValuateStatNames[e.stat]) or e.stat
        -- A bar makes the shape readable at a glance; the numbers are for acting on.
        local bars = math.floor(e.share / 5 + 0.5)
        print(string.format("  %2d. |cFFFFFFFF%-22s|r |cFF00FF00%s|r %5.1f%%   %s x %s = " .. fmt,
            i, name, string.rep("|", bars), e.share,
            string.format(fmt, e.value), string.format(fmt, e.weight), e.contribution))
    end

    print(string.format("|cFFAAAAAATotal: " .. fmt .. "|r", total))

    if #idle > 0 then
        print("|cFFFF8800Weighted, but you are carrying none of it:|r " ..
            table.concat(idle, ", "))
        print("|cFFAAAAAAThose weights change nothing until you equip the stat. Not wrong - just not doing anything yet.|r")
    end
    return true
end

local function ScoreQuestChoice(index, scale)
    if not scale or not scale.Values then
        return nil
    end

    local tooltip = GetPrivateTooltip()
    tooltip:ClearLines()
    local ok = pcall(function() tooltip:SetQuestItem("choice", index) end)
    if not ok then
        return nil
    end

    local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
    if not stats or not next(stats) then
        return nil
    end

    -- Never pre-select a profession tool / fishing pole as a quest reward
    local questItemLink = GetQuestItemLink("choice", index)
    if questItemLink and Valuate:IsItemExcludedFromEvaluation(questItemLink) then
        return nil
    end

    -- Skip rewards the character can't actually use yet (too high level,
    -- unlearned proficiency, wrong class, etc.). The quest tooltip is still
    -- populated here, so reuse the same red requirement-line scan the best
    -- equipment feature uses. Consistent "can I use it?" logic across features.
    if TooltipHasUnmetRequirement("ValuatePrivateTooltip") then
        return nil
    end

    -- Respect banned stats (shared with the tooltip / best-equipment logic)
    local equipLoc = questItemLink and select(9, GetItemInfo(questItemLink)) or nil
    if ScaleBansItem(scale, stats, equipLoc) then
        return nil
    end

    return Valuate:CalculateItemScore(stats, scale)
end

-- Returns the score a reward with this link must beat to be an upgrade for the given
-- scale: the LOWEST-scoring position it could take across every enabled weapon set,
-- or the weakest best-in-slot for non-weapon gear. Ranking rewards by
-- (rewardScore - baseline) therefore favours the biggest upgrade to ANY set - a huge
-- gain to a weak 1H (or dual-wield off-hand, or empty shield slot) beats a marginal
-- gain to an already-strong 2H. Empty positions count as 0 (a full upgrade); returns
-- 0 when nothing is tracked yet.
function Valuate:GetUpgradeBaseline(itemLink, scale, scaleName)
    if not itemLink or not scaleName then return 0 end
    local be = Valuate:GetBestEquipment()[scaleName]
    if not be then return 0 end

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc or equipLoc == "" then return 0 end

    local ws = be.weaponSets
    -- Current score of the item now occupying position `which` ("mh"/"oh") of set
    -- `key`; 0 when that position is empty (so a reward filling it is a full upgrade).
    local function setScore(key, which)
        local set = ws and ws[key]
        local rec = set and set[which]
        return (rec and rec.score) or 0
    end

    -- Every set position this reward could take, across ENABLED sets. Its best play
    -- is the weakest of these, so we take the minimum below.
    local baselines = {}
    local function add(s) baselines[#baselines + 1] = s or 0 end

    local is1H = (equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND")
    if equipLoc == "INVTYPE_2HWEAPON" then
        if Valuate:IsWeaponSetEnabled(scale, "TwoHand") then add(setScore("TwoHand", "mh")) end
    elseif is1H then
        if Valuate:IsWeaponSetEnabled(scale, "OneHandShield") then add(setScore("OneHandShield", "mh")) end
        if Valuate:IsWeaponSetEnabled(scale, "OneHandOffhand") then add(setScore("OneHandOffhand", "mh")) end
        if Valuate:IsWeaponSetEnabled(scale, "DualWield") then
            if equipLoc == "INVTYPE_WEAPON" then
                -- Can go in either hand: it would replace the weaker of the two.
                add(math.min(setScore("DualWield", "mh"), setScore("DualWield", "oh")))
            else
                add(setScore("DualWield", "mh"))  -- main-hand-only 1H
            end
        end
    elseif equipLoc == "INVTYPE_SHIELD" then
        if Valuate:IsWeaponSetEnabled(scale, "OneHandShield") then add(setScore("OneHandShield", "oh")) end
    elseif equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_WEAPONOFFHAND" then
        if Valuate:IsWeaponSetEnabled(scale, "OneHandOffhand") then add(setScore("OneHandOffhand", "oh")) end
    end

    if #baselines > 0 then
        local minB = baselines[1]
        for i = 2, #baselines do
            if baselines[i] < minB then minB = baselines[i] end
        end
        return minB
    end

    -- Non-weapon gear (or a weapon whose sets are all disabled): the weakest
    -- best-in-slot among the slots this item can occupy (the one you'd replace).
    local targetSlots = EquipSlotToInvNumber[equipLoc]
    if not targetSlots then return 0 end
    local minScore
    for _, slotId in ipairs(targetSlots) do
        local b = be[slotId]
        local s = (b and b.score) or 0
        if not minScore or s < minScore then minScore = s end
    end
    return minScore or 0
end

-- Why is this item not my best-in-slot?
--
-- The single most common question a gear addon gets, and the one thing /valuate why could
-- not answer: it explained rolls, arrows and junk - every automated DECISION - while the
-- addon's own core output, "this is your best chest", had no diagnostic at all. "Every
-- automated path has a diagnostic that explains why it did nothing" was true of everything
-- except the headline feature.
--
-- Returns an array, one entry per active scale, each:
--   { scaleName, verdict, score, bestScore, bestLink, gap }
-- verdict is one of:
--   "best"       this item IS the best for that scale
--   "beaten"     something scores higher; bestLink names it and gap is the difference
--   "unscored"   the scale gives this item nothing, so it can never win
--   "noweights"  the scale has no weights at all
--
-- Deliberately does NOT consider equippability. "You cannot wear this yet" is a different
-- answer from "this loses on points", and conflating them is what made the old silence
-- confusing - a level-gated item and a genuinely worse one looked identical.
function Valuate:ExplainBestInSlot(itemLink, stats)
    if not itemLink or not stats then return nil end

    local itemId = GetItemIdFromLink(itemLink)
    if not itemId then return nil end

    local targetSlots = TargetSlotsForItem(itemLink, itemId)
    if not targetSlots then return nil end  -- not equippable gear; nothing to be best AT

    local bestEquipment = Valuate:GetBestEquipment()
    local results = {}

    for _, scaleName in ipairs(Valuate:GetActiveScales()) do
        local scale = Valuate:GetScales()[scaleName]
        local be = bestEquipment[scaleName]
        if scale then
            local entry = { scaleName = scaleName }
            if not scale.Values or next(scale.Values) == nil then
                entry.verdict = "noweights"
            else
                entry.score = Valuate:CalculateItemScore(stats, scale) or 0

                -- The winner among the slots this item could occupy. The WEAKEST of them
                -- is the one it would actually displace, which is the same rule
                -- GetUpgradeBaseline uses - two answers from one rule, not two rules.
                local bestScore, bestLink
                for _, slotId in ipairs(targetSlots) do
                    local b = be and be[slotId]
                    local s = (b and b.score) or 0
                    if not bestScore or s < bestScore then
                        bestScore, bestLink = s, b and b.itemLink
                    end
                end
                entry.bestScore = bestScore or 0
                entry.bestLink = bestLink

                if entry.score <= 0 then
                    entry.verdict = "unscored"
                elseif bestLink and GetItemIdFromLink(bestLink) == itemId then
                    entry.verdict = "best"
                elseif entry.score > entry.bestScore then
                    -- Scores higher than the incumbent but is not recorded as best: the
                    -- scan has not run since this arrived. Saying "beaten" here would be
                    -- a lie, so say what is actually true.
                    entry.verdict = "unscanned"
                    entry.gap = entry.score - entry.bestScore
                else
                    entry.verdict = "beaten"
                    entry.gap = entry.bestScore - entry.score
                end
            end
            table.insert(results, entry)
        end
    end

    return #results > 0 and results or nil
end

-- How much this item would improve each scale, given already-parsed stats.
-- Returns an array of { scaleName, scale, score, baseline, delta }, or nil.
-- opts.includeInactive = true considers every configured scale, not just active ones
-- (used by auto-roll / delete protection: "an upgrade for ANY spec").
-- Equippability is deliberately NOT considered, so an item gated behind a higher level
-- still counts as an upgrade ("will be an upgrade").
function Valuate:GetItemUpgradeInfo(itemLink, stats, opts)
    if not itemLink or not stats then return nil end
    if Valuate:IsItemExcludedFromEvaluation(itemLink) then return nil end

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc or equipLoc == "" then return nil end  -- not equippable gear

    opts = opts or {}
    local scales = Valuate:GetScales()

    -- Candidate scale names: one named scale, every configured scale, or the active ones.
    local candidates = {}
    if opts.scaleName then
        -- Restrict to a single scale. Used by the upgrade arrows, which should only
        -- flag gear that helps the spec you are actually playing - an arrow for a
        -- spec you aren't running is indistinguishable from one for the spec you are.
        if scales[opts.scaleName] then
            candidates[1] = opts.scaleName
        end
    elseif opts.includeInactive then
        -- Sorted because pairs() order is undefined and the caller
        -- (IsUpgradeForAnyScale) resolves an equal delta by taking the first entry,
        -- so an unsorted list reports a different "best" scale run to run.
        for scaleName in pairs(scales) do tinsert(candidates, scaleName) end
        table.sort(candidates)
    else
        for _, scaleName in ipairs(Valuate:GetActiveScales()) do tinsert(candidates, scaleName) end
    end

    local results = {}
    for _, scaleName in ipairs(candidates) do
        local scale = scales[scaleName]
        if scale and scale.Values and not ScaleBansItem(scale, stats, equipLoc) then
            local score = Valuate:CalculateItemScore(stats, scale)
            if score and score > 0 then
                local baseline = Valuate:GetUpgradeBaseline(itemLink, scale, scaleName)
                tinsert(results, {
                    scaleName = scaleName,
                    scale = scale,
                    score = score,
                    baseline = baseline,
                    delta = score - baseline,
                })
            end
        end
    end

    return #results > 0 and results or nil
end

-- ============================================================================
-- Upgrade arrows
-- ============================================================================
-- Answers "is this link an upgrade for any of my scales?" from a link ALONE, for
-- the icon overlays on merchant, loot and bag buttons.
--
-- Cached because this is called once per visible button every time a container
-- repaints, and each miss costs a tooltip build plus a scan of every scale. The
-- cache is cleared whenever gear or scales change (ResetUpgradeArrowCache), since
-- equipping something changes the answer for everything else.
local upgradeLinkCache = {}
local upgradeLinkCacheCount = 0
local upgradeCacheScale  -- which scale the cached answers were computed for
local UPGRADE_CACHE_MAX = 500

function Valuate:ResetUpgradeArrowCache()
    upgradeLinkCache = {}
    upgradeLinkCacheCount = 0
end

-- Returns isUpgrade, bestDelta, bestScaleName.
function Valuate:IsItemLinkUpgrade(itemLink)
    if not itemLink then return false end

    -- Answers are relative to the CURRENT spec, so switching spec invalidates all of
    -- them. A scan usually clears this anyway, but changing the active scale doesn't
    -- have to involve one, and a stale arrow for your previous spec is exactly the
    -- thing this feature is supposed to avoid.
    local _, currentScaleName = Valuate:GetPrimaryScale()
    if currentScaleName ~= upgradeCacheScale then
        Valuate:ResetUpgradeArrowCache()
        upgradeCacheScale = currentScaleName
    end

    local cached = upgradeLinkCache[itemLink]
    if cached ~= nil then
        return cached.up, cached.delta, cached.scaleName
    end

    local isUp, delta, scaleName = false, 0, nil
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    -- Only gear can be an upgrade; skip the tooltip build entirely otherwise, which
    -- is most of a bag's contents.
    if equipLoc and equipLoc ~= "" and not Valuate:IsItemExcludedFromEvaluation(itemLink) then
        local stats = Valuate:GetStatsForTooltipSetter("SetHyperlink", itemLink)
        if stats then
            -- Current spec only. Checking every active scale meant an arrow could be
            -- flagging an upgrade for a spec you aren't playing, with no way to tell
            -- which from the icon.
            local _, primaryName = Valuate:GetPrimaryScale()
            if primaryName then
                isUp, delta, scaleName =
                    Valuate:IsUpgradeForAnyScale(itemLink, stats, { scaleName = primaryName })
            end
        end
    end

    -- Bounded: a long session at a vendor would otherwise grow this without limit.
    -- Dropping the whole table is fine - it refills from what is on screen.
    if upgradeLinkCacheCount >= UPGRADE_CACHE_MAX then
        Valuate:ResetUpgradeArrowCache()
    end
    upgradeLinkCache[itemLink] = { up = isUp, delta = delta or 0, scaleName = scaleName }
    upgradeLinkCacheCount = upgradeLinkCacheCount + 1

    return isUp, delta or 0, scaleName
end

-- Convenience wrapper: is this item an upgrade for ANY candidate scale?
-- Returns isUpgrade, bestDelta, bestScaleName.
function Valuate:IsUpgradeForAnyScale(itemLink, stats, opts)
    local info = Valuate:GetItemUpgradeInfo(itemLink, stats, opts)
    if not info then return false, 0, nil end

    local bestDelta, bestScaleName
    for _, entry in ipairs(info) do
        if not bestDelta or entry.delta > bestDelta then
            bestDelta, bestScaleName = entry.delta, entry.scaleName
        end
    end

    if bestDelta and bestDelta > 0 then
        return true, bestDelta, bestScaleName
    end
    return false, bestDelta or 0, bestScaleName
end

-- Auto-selects the highest-scoring quest reward choice for the active scale.
-- By default this only PRE-SELECTS (highlights) the reward so the player still
-- clicks "Complete Quest" themselves. If autoQuestTurnIn is also enabled it goes
-- one step further and actually completes the quest (GetQuestReward).
-- Called on QUEST_COMPLETE when options.autoQuestReward is enabled.
-- Which quest reward to take, given what each one scored.
--
-- Separated from AutoSelectBestQuestReward because a quest reward is IRREVERSIBLE - the
-- other choices are gone the moment one is taken, and with auto turn-in on this runs
-- without asking. That makes the policy worth stating on its own rather than reading out of
-- a loop that also talks to GetQuestItemLink and paints a highlight texture.
--
-- `scored` holds only the choices that produced a score: { index, score, delta }, where
-- delta is the score over what you already have in that slot. `numChoices` is how many the
-- quest offers in total, scored or not.
--
-- The policy, in order:
--   1. Any real upgrade -> the BIGGEST one. A strong weapon you will never beat your current
--      best with should lose to a modest trinket that actually fills an empty slot.
--   2. Otherwise -> the highest raw score. Nothing is an upgrade, so take the most valuable.
--   3. Nothing scored at all -> guess only when there is nothing to guess between. One
--      choice is safe to pre-select; two or more and we leave it to you. This is the rule
--      that matters, and it is the same shape as the surplus-gear one: when the action
--      cannot be undone, uncertainty declines to act.
--
-- Ties go to the LOWEST index, deliberately: an irreversible choice must not depend on the
-- order a table happened to be built in.
local function ChooseQuestReward(scored, numChoices)
    local bestIndex, bestScore
    local upgIndex, upgDelta

    for _, c in ipairs(scored or {}) do
        if not bestScore or c.score > bestScore then
            bestScore, bestIndex = c.score, c.index
        end
        if not upgDelta or c.delta > upgDelta then
            upgDelta, upgIndex = c.delta, c.index
        end
    end

    if upgIndex and upgDelta and upgDelta > 0 then
        return upgIndex
    end
    if bestIndex then
        return bestIndex
    end
    if numChoices == 1 then
        return 1
    end
    return nil
end

function Valuate:AutoSelectBestQuestReward()
    local options = Valuate:GetOptions()
    if not options.autoQuestReward then
        return
    end

    -- GetNumQuestChoices() = number of "choose one of these" rewards.
    -- 0 means only guaranteed rewards (nothing to choose).
    local numChoices = GetNumQuestChoices()
    if not numChoices or numChoices < 1 then
        -- Nothing to select. With full auto turn-in on, still complete the quest
        -- (index 0 = the guaranteed reward, if any).
        if options.autoQuestTurnIn then
            if options.chatMessages then
                print("|cFF00FF00Valuate|r: auto-completing quest (no reward choice).")
            end
            GetQuestReward(0)
        end
        return
    end

    local scale, scaleName = Valuate:GetPrimaryScale()
    if not scale then
        if options.chatMessages then
            print("|cFFFF8800Valuate|r: Auto quest reward skipped - no active scale to score with.")
        end
        return
    end

    -- Score every choice, tracking both the highest raw score (fallback) and the
    -- biggest UPGRADE over the current best-in-slot ("Best for") item for that slot.
    -- We prefer the reward that most improves your gear, not just the one with the
    -- highest number in a vacuum: a strong weapon you'll never beat your current best
    -- with should lose to a modest trinket that actually upgrades an empty slot.
    local scored, links = {}, {}
    for index = 1, numChoices do
        local score = ScoreQuestChoice(index, scale)
        if score then
            local link = GetQuestItemLink("choice", index)
            links[index] = link
            scored[#scored + 1] = {
                index = index,
                score = score,
                delta = score - Valuate:GetUpgradeBaseline(link, scale, scaleName),
            }
        end
    end

    -- The policy lives in ChooseQuestReward, which returns nil when it should not guess.
    local bestIndex = ChooseQuestReward(scored, numChoices)
    if not bestIndex then return end

    local bestLink = links[bestIndex] or GetQuestItemLink("choice", bestIndex)
    local bestScore
    for _, c in ipairs(scored) do
        if c.index == bestIndex then bestScore = c.score end
    end

    -- Mark the best reward WITHOUT touching Blizzard's UI. Writing QuestInfoFrame's
    -- fields or calling QuestInfoItem_OnClick from addon code taints the quest frame,
    -- and the client then blocks "Complete Quest" ("blocked from an action only
    -- available to the Blizzard UI"). So we only draw our own highlight texture
    -- anchored to the reward button and let YOU click it - unless auto turn-in is on,
    -- which takes the reward through the GetQuestReward API below instead.
    pcall(function()
        local button = _G["QuestInfoItem" .. bestIndex]
        if not button then return end
        if not Valuate.questRewardMarker then
            local tex = UIParent:CreateTexture(nil, "OVERLAY")
            tex:SetTexture("Interface\\Buttons\\CheckButtonHilight")
            tex:SetBlendMode("ADD")
            tex:SetVertexColor(1, 0.82, 0.1)
            Valuate.questRewardMarker = tex
        end
        local marker = Valuate.questRewardMarker
        marker:ClearAllPoints()
        marker:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        marker:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        marker:Show()
    end)

    local rewardText = bestLink or ("choice " .. bestIndex)

    -- Full auto turn-in: actually complete the quest, taking the best reward.
    -- GetQuestReward takes the choice index directly, so this is authoritative
    -- regardless of the itemChoice set above.
    if options.autoQuestTurnIn then
        if options.chatMessages then
            if bestScore then
                print(string.format("|cFF00FF00Valuate|r turning in quest, reward: %s |cFFAAAAAA(score %.1f for %s)|r",
                    rewardText, bestScore, scale.DisplayName or scaleName or "scale"))
            else
                print("|cFF00FF00Valuate|r turning in quest, reward: " .. rewardText)
            end
        end
        -- Irreversible: the other rewards are gone the moment this returns. Recorded so
        -- the report can say WHICH one was taken, not merely that something was.
        Valuate:MarkAutomation("questReward", "took " .. (bestLink or ("choice " .. bestIndex)))
        GetQuestReward(bestIndex)
        return
    end

    if options.chatMessages then
        if bestScore then
            print(string.format("|cFF00FF00Valuate|r auto-selected reward: %s |cFFAAAAAA(score %.1f for %s)|r",
                rewardText, bestScore, scale.DisplayName or scaleName or "scale"))
        else
            print("|cFF00FF00Valuate|r auto-selected reward: " .. rewardText)
        end
    end
end

-- On the quest "progress" screen (the "do you have the items?" step), advance to
-- the reward screen when full auto turn-in is enabled. QUEST_COMPLETE then fires
-- and AutoSelectBestQuestReward finishes the turn-in.
function Valuate:AutoAdvanceQuestProgress()
    local options = Valuate:GetOptions()
    if not (options.autoQuestReward and options.autoQuestTurnIn) then
        return
    end
    if IsQuestCompletable and IsQuestCompletable() then
        CompleteQuest()
    end
end

-- ========================================
-- Junk auto-delete (DESTRUCTIVE - deletion is irreversible)
-- ========================================

local autoDeleteSessionCount = 0

-- Resolves an item's UNIT value in copper from the configured price source, falling
-- back to the vendor sell price whenever the source is unavailable or returns nothing.
-- sourceKey: "vendor" (default) or a TSM price source / custom price string such as
-- "DBMarket", "DBMinBuyout", or even "max(dbmarket,vendorsell)".
-- Returns: value, sourceUsed ("vendor" | sourceKey | "vendor (fallback)").
-- TSM's API differs sharply between generations, so each shape is tried defensively;
-- a missing or broken price source must never stop the caller from getting a number.
function Valuate:GetItemUnitValue(itemLink, sourceKey)
    if not itemLink then return 0, "vendor" end
    local vendor = select(11, GetItemInfo(itemLink)) or 0

    if not sourceKey or sourceKey == "" or strlower(sourceKey) == "vendor" then
        return vendor, "vendor"
    end

    -- TSM4+ : TSM_API.GetCustomPriceValue(priceString, itemString)
    if TSM_API and TSM_API.GetCustomPriceValue and TSM_API.ToItemString then
        local ok, itemString = pcall(TSM_API.ToItemString, itemLink)
        if ok and itemString then
            local ok2, v = pcall(TSM_API.GetCustomPriceValue, sourceKey, itemString)
            if ok2 and type(v) == "number" and v > 0 then return v, sourceKey end
        end
    end

    -- TSM3 : TSMAPI:GetItemValue(itemLink, priceSource)
    if TSMAPI and TSMAPI.GetItemValue then
        local ok, v = pcall(TSMAPI.GetItemValue, TSMAPI, itemLink, sourceKey)
        if ok and type(v) == "number" and v > 0 then return v, sourceKey end
    end

    -- TSM3 custom price strings : TSMAPI:ParseCustomPrice(str) -> function(itemLink)
    if TSMAPI and TSMAPI.ParseCustomPrice then
        local ok, priceFunc = pcall(TSMAPI.ParseCustomPrice, TSMAPI, sourceKey)
        if ok and type(priceFunc) == "function" then
            local ok2, v = pcall(priceFunc, itemLink)
            if ok2 and type(v) == "number" and v > 0 then return v, sourceKey end
        end
    end

    return vendor, "vendor (fallback)"
end

-- Free slots across the normal bags.
local function CountFreeBagSlots()
    local free = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            if not GetContainerItemLink(bag, slot) then
                free = free + 1
            end
        end
    end
    return free
end

-- Hard protections that the user CANNOT switch off. Anything Valuate considers gear
-- you want, a quest item, or part of a WoW equipment set is never a delete candidate.
-- Returns true plus a reason when the item must be kept.
local function IsProtectedFromDelete(bag, slot, link)
    if not link then return true, "no link" end

    -- Quest items
    if GetContainerItemQuestInfo then
        local ok, isQuestItem, questId = pcall(GetContainerItemQuestInfo, bag, slot)
        if ok and (isQuestItem or questId) then return true, "quest item" end
    end

    -- Belongs to a WoW equipment set
    if GetContainerItemEquipmentSetInfo then
        local ok, inSet = pcall(GetContainerItemEquipmentSetInfo, bag, slot)
        if ok and inSet then return true, "in an equipment set" end
    end

    -- Best-in-slot / weapon-set member for any scale.
    --
    -- GetBestForInfo checks weaponKeep FIRST, so an off-set weapon - your 2H while
    -- 1H+Shield is active, say - comes back with a `category` and is protected here.
    -- That is what makes the "never deletes weapon-set members" promise true, and it
    -- is worth knowing that the protection is this branch rather than one of its own.
    --
    -- The REASON now distinguishes them. Both are protected either way, but "kept:
    -- best-in-slot" on a weapon you are not currently using reads like a mistake, and
    -- the tooltip verdict shows this string verbatim.
    if Valuate.GetBestForInfo then
        local info = Valuate:GetBestForInfo(link)
        if info then
            for _, entry in ipairs(info) do
                if entry.category then
                    return true, "weapon-set member (" .. tostring(entry.category) .. ")"
                end
            end
            return true, "best-in-slot"
        end
    end

    -- Tracked future upgrade (can't use it yet, but will)
    if Valuate.GetFutureUpgradeScales and Valuate:GetFutureUpgradeScales(link) then
        return true, "future upgrade"
    end

    -- An upgrade for any scale, even if it never made it into the scan results.
    if Valuate.GetStatsForTooltipSetter and Valuate.IsUpgradeForAnyScale then
        local stats = Valuate:GetStatsForTooltipSetter("SetBagItem", bag, slot)
        if stats then
            local isUpgrade = Valuate:IsUpgradeForAnyScale(link, stats, { includeInactive = true })
            if isUpgrade then return true, "an upgrade" end
        end
    end

    return false
end

-- Resolves AdiBags and its Junk module once. Shared by the delete and sell paths so
-- there is a single junk classification in the addon (duplicating it is how the
-- "0 junk found" bug happened).
-- Memoised: this is now on a per-bag-icon path (the new-item hook asks about every
-- button on every repaint), and two LibStub lookups per item is real work for an
-- answer that cannot change once found.
--
-- Only a SUCCESSFUL resolve is cached. AdiBags may not have loaded yet when the
-- first call happens, and caching the miss would disable junk handling for the rest
-- of the session.
local cachedAdiBags, cachedJunkModule
local function ResolveAdiBagsJunk()
    if cachedAdiBags and cachedJunkModule then
        return cachedAdiBags, cachedJunkModule
    end

    local AdiBags, junkModule
    if LibStub then
        local ace = LibStub("AceAddon-3.0", true)
        AdiBags = ace and ace:GetAddon("AdiBags", true)
        if AdiBags and AdiBags.GetModule then
            junkModule = AdiBags:GetModule("Junk", true)
        end
    end

    if AdiBags and junkModule then
        cachedAdiBags, cachedJunkModule = AdiBags, junkModule
    end
    return AdiBags, junkModule
end

-- True when the item counts as junk. Prefers the AdiBags Junk module's CheckItem
-- (authoritative, honours include/exclude), then addon:IsJunk, then grey/Poor quality
-- when AdiBags isn't installed at all.
local function IsItemJunk(AdiBags, junkModule, itemId, quality)
    local numId = tonumber(itemId)
    if junkModule and junkModule.CheckItem and numId then
        -- valuate-lint-ignore: no-duplicate-junk-logic (this IS the canonical helper)
        local ok, res = pcall(function() return junkModule:CheckItem(numId) end)
        return (ok and res) and true or false
    elseif AdiBags and AdiBags.IsJunk and numId then
        -- valuate-lint-ignore: no-duplicate-junk-logic (this IS the canonical helper)
        local ok, res = pcall(function() return AdiBags:IsJunk(numId) end)
        return (ok and res) and true or false
    elseif not AdiBags then
        return (quality == ITEM_QUALITY_POOR) or (quality == 0)
    end
    return false
end

-- Public wrapper so integrations classify junk through the SAME helper the delete
-- and sell paths use, instead of re-implementing it. Duplicating this logic is what
-- kept the "0 junk found" bug alive through two attempted fixes, which is why
-- there is a lint rule against it.
function Valuate:IsItemJunk(itemId, quality)
    local AdiBags, junkModule = ResolveAdiBagsJunk()
    return IsItemJunk(AdiBags, junkModule, itemId, quality)
end

-- What Valuate makes of an item for cleanup purposes: is it junk, and if so is
-- anything protecting it?
--
-- Exists so the TOOLTIP can answer the question the cleanup features raise but never
-- answered on the item itself - "would this get sold or deleted?". Until now that was
-- only available by remembering to type /valuate why, which is the wrong moment: you
-- want it while looking at the item, before switching automation on.
--
-- A method rather than a file-local because the tooltip code sits some 3,600 lines
-- ABOVE IsProtectedFromDelete, and a local declared here would be a nil global up
-- there. That trap has produced two real bugs in this file already.
--
-- bag/slot are optional. IsProtectedFromDelete pcalls both of the checks that need
-- them, so passing nil is safe - it just means the quest-item and equipment-set
-- protections cannot be evaluated, which the caller is told via `partial`.
--
-- Returns: isJunk, protectedReason, partial
function Valuate:GetJunkVerdict(link, bag, slot)
    if not link then return false end

    local itemId = GetItemIdFromLink(link)
    local _, _, quality = GetItemInfo(link)
    if not itemId or not Valuate:IsItemJunk(itemId, quality) then return false end

    local _, reason = IsProtectedFromDelete(bag, slot, link)
    return true, reason, (bag == nil or slot == nil)
end

-- Deletes the least valuable junk until the configured number of bag slots is free.
-- Only ever considers items AdiBags classes as Junk (which honours its own
-- include/exclude lists) or, without AdiBags, poor/grey quality.
function Valuate:AutoDeleteJunk(opts)
    opts = opts or {}
    local preview = opts.preview == true
    local force = opts.force == true  -- on-demand: ignore the enable toggle + free-slot gate
    local options = Valuate:GetOptions()
    if not preview and not force and not options.autoDeleteJunk then return end

    -- NOTE: no combat gate. Deleting BAG items (PickupContainerItem + DeleteCursorItem)
    -- is not a protected action in 3.3.5 - only equipping gear is - and freeing bag
    -- space mid-fight (AoE farming) is exactly when this is wanted. Only equipping in
    -- combat is blocked, which this feature never does.

    -- Keep the in-transit guard, though: never touch bag slots or call SetBagItem while
    -- items are moving between bags/equipped, or they can vanish. This is about item
    -- movement integrity, NOT combat.
    if equipmentSwapPending or recentEquipmentChange then
        if preview then print("|cFFFF8800[Valuate]|r Items are still settling - try again in a moment.") end
        return
    end

    local keepFree = options.autoDeleteKeepFree or 4
    local free = CountFreeBagSlots()
    -- Preview always runs so you can inspect the rules at any time. Everything else only
    -- acts when bags are actually below the target - including on-demand, which reports
    -- rather than failing silently.
    if not preview and free >= keepFree then
        -- Recorded even though nothing was deleted: "ran, and correctly did nothing"
        -- is the answer people actually need when cleanup seems idle.
        Valuate:MarkAutomation("junkCleanup",
            string.format("no action - %d free, target %d", free, keepFree))
        if force then
            print(string.format("|cFF00FF00[Valuate]|r Nothing to do - %d free slot(s), target is %d. "
                .. "Junk is only removed when you drop below the target.", free, keepFree))
        end
        return
    end

    local maxQuality = options.autoDeleteMaxQuality or 2
    local maxValue = options.autoDeleteMaxValue or 0
    local minValue = options.autoDeleteMinValue or 0
    local valueSource = options.autoDeleteValueSource or "vendor"
    local dryRun = preview or (options.autoDeleteDryRun == true)

    -- Diagnostics so a preview can explain WHY nothing matched.
    local nScanned, nJunk, nQuality, nValue, nProtected = 0, 0, 0, 0, 0
    -- How often the configured price source actually resolved vs fell back to vendor.
    local nSourceHits, nSourceFallback = 0, 0

    -- Shared AdiBags junk classification (see ResolveAdiBagsJunk / IsItemJunk).
    local AdiBags, junkModule = ResolveAdiBagsJunk()

    -- Collect candidates
    local candidates = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = GetItemIdFromLink(link)
                local name, _, quality = GetItemInfo(link)
                -- `locked` means the slot is mid-operation: being moved, split, or
                -- awaiting the server's answer. AutoSellJunk has always skipped those,
                -- at both scan and act time; this path - the IRREVERSIBLE one - checked
                -- neither. A locked slot can still report the same link, so the
                -- re-verify further down does not cover it.
                local _, stackCount, slotLocked = GetContainerItemInfo(bag, slot)
                stackCount = stackCount or 1

                -- Unit value from the configured price source (vendor by default).
                local unitValue, usedSource = Valuate:GetItemUnitValue(link, valueSource)
                if usedSource == valueSource then
                    nSourceHits = nSourceHits + 1
                else
                    nSourceFallback = nSourceFallback + 1
                end

                -- Deletable set = exactly what AdiBags' Junk filter classifies as junk.
                local isJunk = IsItemJunk(AdiBags, junkModule, itemId, quality)

                local value = unitValue * stackCount

                nScanned = nScanned + 1
                if isJunk and slotLocked then
                    -- Silently skipped: a locked slot is transient, and the next run
                    -- picks it up if it is still junk. Counted as protected so the
                    -- preview never claims an item is deletable that this pass refused.
                    nProtected = nProtected + 1
                    if preview or options.debug then
                        print("|cFF88CC88[Valuate]|r keeping " .. link .. " (slot is mid-move)")
                    end
                elseif isJunk then
                    nJunk = nJunk + 1
                    if not (quality and quality <= maxQuality) then
                        nQuality = nQuality + 1
                    elseif (maxValue > 0 and value > maxValue) or (minValue > 0 and value < minValue) then
                        nValue = nValue + 1
                    else
                        local protected, reason = IsProtectedFromDelete(bag, slot, link)
                        if protected then
                            nProtected = nProtected + 1
                            if preview or options.debug then
                                print("|cFF88CC88[Valuate]|r keeping " .. link .. " (" .. tostring(reason) .. ")")
                            end
                        else
                            tinsert(candidates, {
                                bag = bag, slot = slot, link = link,
                                name = name or "item", value = value, count = stackCount,
                            })
                        end
                    end
                end
            end
        end
    end

    local function money(v)
        return GetCoinTextureString and GetCoinTextureString(v) or (v .. "c")
    end

    if preview then
        print(string.format("|cFF00FF00[Valuate]|r Delete preview - %d free slot(s), target %d. Scanned %d item(s): %d junk, %d over quality limit, %d outside value range, %d protected -> |cFFFFD700%d deletable|r.",
            free, keepFree, nScanned, nJunk, nQuality, nValue, nProtected, #candidates))
        print(string.format("|cFFAAAAAA[Valuate]|r Limits: quality <= %d, value %s..%s per stack.",
            maxQuality,
            minValue > 0 and money(minValue) or "any",
            maxValue > 0 and money(maxValue) or "any"))
        if junkModule and junkModule.CheckItem then
            print("|cFFAAAAAA[Valuate]|r Junk source: AdiBags Junk module (CheckItem; honours include/exclude).")
        elseif AdiBags and AdiBags.IsJunk then
            print("|cFFFF8800[Valuate]|r Junk source: AdiBags:IsJunk fallback (Junk module not found).")
        else
            print("|cFFAAAAAA[Valuate]|r Junk source: grey/Poor quality (AdiBags not loaded).")
        end
        if strlower(valueSource) == "vendor" then
            print("|cFFAAAAAA[Valuate]|r Value source: vendor sell price.")
        elseif nSourceFallback > 0 then
            print(string.format("|cFFFF8800[Valuate]|r Value source '%s' resolved for %d item(s) but FELL BACK to vendor for %d - check the source name / that TSM is loaded.",
                valueSource, nSourceHits, nSourceFallback))
        else
            print(string.format("|cFFAAAAAA[Valuate]|r Value source: '%s' (resolved for all %d item(s)).",
                valueSource, nSourceHits))
        end
    end

    if #candidates == 0 then
        if preview then
            print("|cFFFF8800[Valuate]|r Nothing would be deleted. Loosen the quality/value limits, or check the 'keeping' lines above.")
        elseif options.chatMessages then
            print("|cFFFF8800[Valuate]|r Bags are low on space but no safe junk to remove.")
        end
        return
    end

    -- Cheapest first, so anything worth keeping survives longest.
    -- bag/slot break ties: table.sort is not stable and equal vendor values are very
    -- common among junk (whole stacks, many greys share a price). Without a total
    -- order, `deletepreview` can rank a different item than `deletenow` removes -
    -- and deletion is irreversible, so preview must predict it exactly.
    table.sort(candidates, function(a, b)
        if a.value ~= b.value then return a.value < b.value end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)

    -- Preview: list the ranked queue (capped). Otherwise - including on-demand (force) -
    -- only ever remove enough to reach the free-slot target. "Delete now" means "run the
    -- normal cleanup immediately", NOT "delete all my junk": deletion is irreversible, so
    -- it should never remove more than the setting asks for.
    local needed
    if preview then
        needed = math.min(#candidates, opts.limit or 15)
    else
        needed = keepFree - free
    end
    local removed = 0
    for _, c in ipairs(candidates) do
        if removed >= needed then break end

        if dryRun then
            print(string.format("|cFFFFAA00[Valuate dry-run]|r %d. would delete %s x%d (%s)",
                removed + 1, c.link, c.count, money(c.value)))
            removed = removed + 1
        else
            -- Safety: re-verify the slot STILL holds the exact item we vetted. Bags can
            -- shift between the scan and here (another addon, a stack change), and we
            -- must never delete a slot whose contents changed out from under us.
            local nowLink = GetContainerItemLink(c.bag, c.slot)
            local _, _, nowLocked = GetContainerItemInfo(c.bag, c.slot)
            if nowLink ~= c.link or nowLocked then
                -- Contents changed, or the slot is mid-operation; skip it silently
                -- rather than risk it. SellNextBatch has always checked both - this
                -- path only compared the link, and a slot can be locked while still
                -- reporting the same one.
            else
            PickupContainerItem(c.bag, c.slot)
            if CursorHasItem and CursorHasItem() then
                DeleteCursorItem()
                -- If a confirmation dialog intercepted the delete the item is still on
                -- the cursor. We deliberately do NOT auto-answer that popup - it exists
                -- to prevent exactly this kind of accident. Put it back and move on.
                if CursorHasItem and CursorHasItem() then
                    ClearCursor()
                    print("|cFFFF8800[Valuate]|r Skipped " .. c.link .. " - needs manual confirmation.")
                else
                    removed = removed + 1
                    autoDeleteSessionCount = autoDeleteSessionCount + 1
                    print(string.format("|cFFFF5555[Valuate]|r Deleted %s x%d (%s)",
                        c.link, c.count, money(c.value)))
                end
            else
                ClearCursor()
            end
            end  -- close slot re-verify guard
        end
    end

    if preview then
        if #candidates > removed then
            print(string.format("|cFFAAAAAA[Valuate]|r ...and %d more deletable item(s) not shown.", #candidates - removed))
        end
    else
        Valuate:MarkAutomation("junkCleanup", string.format("%s %d item(s)",
            dryRun and "would remove" or "removed", removed))
        if removed > 0 and options.chatMessages then
            print(string.format("|cFF00FF00[Valuate]|r %s %d item(s); %d free slot(s). Session total: %d.",
                dryRun and "Would remove" or "Removed", removed, CountFreeBagSlots(), autoDeleteSessionCount))
        end
    end
end

-- ========================================
-- Merchant: auto-sell junk + auto-repair
-- ========================================
-- Selling is strictly better than deleting - you get the gold and the vendor's buyback
-- tab can recover a mistake - so this runs on the same junk classification and the same
-- hard protections as auto-delete, and should mean deletion is rarely needed.

-- Sells one batch of junk, then reschedules itself. The server rejects rapid-fire
-- sells, so we go in small batches with a short gap rather than one tight loop.
local sellQueue, sellTotal = nil, 0

local function SellNextBatch()
    if not MerchantFrame or not MerchantFrame:IsShown() then
        sellQueue = nil
        return
    end
    if not sellQueue or #sellQueue == 0 then
        if sellTotal > 0 then
            print(string.format("|cFF00FF00[Valuate]|r Sold junk for %s.",
                GetCoinTextureString and GetCoinTextureString(sellTotal) or (sellTotal .. "c")))
        end
        sellQueue = nil
        return
    end

    for _ = 1, 6 do
        local c = table.remove(sellQueue, 1)
        if not c then break end
        -- Re-verify the slot still holds what we vetted, and that it's still sellable
        -- and unlocked, before acting. Bags can shift between queueing and selling, and
        -- UseContainerItem on the wrong/unsellable item would use it instead.
        local _, _, locked = GetContainerItemInfo(c.bag, c.slot)
        if GetContainerItemLink(c.bag, c.slot) == c.link and not locked then
            UseContainerItem(c.bag, c.slot)   -- at a merchant this sells the item
            sellTotal = sellTotal + (c.value or 0)
        end
    end

    ValuateAfter(0.3, SellNextBatch)
end

-- Collects junk (same classification + protections as auto-delete) and sells it.
-- ============================================================================
-- Wardrobe: collect appearances you do not already have
-- ============================================================================
-- Ascension keeps a wardrobe of collected appearances. Items in your bags whose look you
-- have not collected yet can be collected without consuming the item - PastLoot does exactly
-- this immediately before deleting or vendoring something, which is where the API below was
-- read from rather than guessed at.
--
-- Treated as UNVERIFIED throughout: this is a custom-server API, seen working in another
-- addon but never run by me. Every call is feature-detected and wrapped, because the cost of
-- being wrong about an API on this client was demonstrated an hour ago by a font object that
-- would not draw and stopped the UI opening at all.
--
-- One thing I cannot check from here and you should know: collecting an appearance may BIND
-- the item. PastLoot only ever calls it on things it is about to destroy or sell, which is
-- consistent with binding and proves nothing either way. That is why this is off by default
-- and why the preview exists - run it, look at the list, and decide.
local APPEARANCE_THROTTLE = 5      -- seconds between automatic passes
local lastAppearancePass = 0
-- Separate from the timestamp rather than overloading 0 for "never". GetTime() really can be
-- 0, and a sentinel that collides with a legitimate value is how the first pass ends up
-- either always skipped or never throttled.
local appearancePassRan = false

local function AppearanceApiReady()
    return type(C_Appearance) == "table"
        and type(C_Appearance.GetItemAppearanceID) == "function"
        and type(C_AppearanceCollection) == "table"
        and type(C_AppearanceCollection.IsAppearanceCollected) == "function"
        and type(C_AppearanceCollection.CollectItemAppearance) == "function"
        and type(GetContainerItemGUID) == "function"
end

-- Read-only. Returns the list of bag items whose appearance is not collected yet, so the
-- preview and the action are the same decision rather than two implementations that can
-- disagree - the shape that has caused this project trouble more than once.
--
-- Bags only, never the bank: the bank cannot be reached without the frame open, and a
-- best-effort pass over stale cached data is not something to hand to an automated feature.
function Valuate:GetUncollectedAppearances()
    if not AppearanceApiReady() then
        return nil, "this client has no wardrobe API"
    end

    local found, seenAppearance = {}, {}
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            local itemId = link and tonumber(link:match("item:(%d+)"))
            if itemId then
                local okId, appearanceId = pcall(C_Appearance.GetItemAppearanceID, itemId)
                if okId and appearanceId then
                    local okHas, collected =
                        pcall(C_AppearanceCollection.IsAppearanceCollected, appearanceId)
                    -- Only when the API positively says NOT collected. An errored call
                    -- leaves `collected` nil, and treating unknown as "not collected" would
                    -- have us act on an answer we never got.
                    if okHas and collected == false and not seenAppearance[appearanceId] then
                        -- Two items can share one appearance. Collecting either collects it,
                        -- but IsAppearanceCollected will not have caught up within this pass,
                        -- so without this the second one is collected redundantly.
                        seenAppearance[appearanceId] = true
                        found[#found + 1] = {
                            bag = bag, slot = slot, link = link,
                            itemId = itemId, appearanceId = appearanceId,
                        }
                    end
                end
            end
        end
    end

    -- Bag then slot order, which is what the loops produce, so the preview lists items in the
    -- order you would find them and two runs agree.
    return found
end

-- Collects them. Returns how many were collected, and a reason whenever that is zero, so the
-- caller never has to guess between "nothing to do" and "could not do it".
-- `pending` is optional: pass a list you already showed the user, and the re-verify below
-- becomes a real check. Without it this function scans and acts in one breath, nothing can
-- move in between, and the guard would be theatre - which is what it was until the gate for
-- it could not be made to fail.
function Valuate:LearnUncollectedAppearances(pending)
    local why
    if not pending then
        pending, why = Valuate:GetUncollectedAppearances()
    end
    if not pending then
        return 0, why
    end
    if #pending == 0 then
        return 0, "every appearance in your bags is already collected"
    end

    local collected = 0
    for _, entry in ipairs(pending) do
        -- Re-read the GUID at the moment of acting. The list may be a few frames old, and a
        -- GUID that no longer matches means the slot changed under us - the same
        -- re-verify-before-acting rule the delete and sell paths follow.
        local guid = GetContainerItemGUID(entry.bag, entry.slot)
        if guid and guid ~= "" then
            local link = GetContainerItemLink(entry.bag, entry.slot)
            if link == entry.link then
                if pcall(C_AppearanceCollection.CollectItemAppearance, guid) then
                    collected = collected + 1
                end
            end
        end
    end

    if collected == 0 then
        return 0, "found " .. #pending .. " uncollected, but the items moved before I could act"
    end
    return collected
end

-- The automatic pass. Off unless you switch it on, throttled, and silent when it finds
-- nothing - an automation that announces "did nothing" every few seconds is one you turn off.
function Valuate:AutoLearnAppearances()
    if not Valuate:GetOptions().autoLearnAppearances then return end

    local now = (GetTime and GetTime()) or 0
    -- `lastAppearancePass ~= 0` means "has never run", so the FIRST pass is never throttled.
    -- Without it the first call is skipped whenever GetTime() is near zero, which is exactly
    -- what a fresh session looks like to a test and what the gate caught.
    --
    -- `now < lastAppearancePass` catches a clock that went backwards on /reload, which would
    -- otherwise pin the throttle shut for as long as the difference.
    if appearancePassRan
        and now - lastAppearancePass < APPEARANCE_THROTTLE
        and now >= lastAppearancePass then
        return
    end
    appearancePassRan = true
    lastAppearancePass = now

    local collected, why = Valuate:LearnUncollectedAppearances()
    if collected > 0 then
        print(string.format("|cFF00FF00Valuate|r: collected %d new wardrobe appearance(s).",
            collected))
        Valuate:MarkAutomation("wardrobe", string.format("collected %d appearance(s)", collected))
    else
        Valuate:MarkAutomation("wardrobe", why or "nothing to collect")
    end
end

function Valuate:AutoSellJunk(verbose)
    local options = Valuate:GetOptions()
    if not MerchantFrame or not MerchantFrame:IsShown() then
        if verbose then print("|cFFFF8800[Valuate]|r No merchant window open.") end
        return 0
    end
    if equipmentSwapPending or recentEquipmentChange then return 0 end

    local AdiBags, junkModule = ResolveAdiBagsJunk()
    local maxQuality = options.autoDeleteMaxQuality or 2
    local valueSource = options.autoDeleteValueSource or "vendor"

    local queue, count = {}, 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = GetItemIdFromLink(link)
                local _, _, quality = GetItemInfo(link)
                local _, stackCount, locked = GetContainerItemInfo(bag, slot)
                stackCount = stackCount or 1

                -- Sale price is the VENDOR price regardless of the ranking source -
                -- that's what the merchant actually pays.
                local unit = select(11, GetItemInfo(link)) or 0

                -- CRITICAL: only queue items the vendor will actually BUY. At a merchant
                -- UseContainerItem sells the item, but an item with no sell price can't
                -- be sold - and the call can fall through to USING it instead, which
                -- would consume a junk-classified consumable. Requiring a sell price
                -- makes that impossible. Locked slots (mid-move) are skipped too.
                if unit > 0 and not locked
                   and IsItemJunk(AdiBags, junkModule, itemId, quality)
                   and quality and quality <= maxQuality then
                    -- Same hard protections as deleting: never sell best-in-slot,
                    -- weapon-set members, future upgrades, quest or equipment-set items.
                    local protected = IsProtectedFromDelete(bag, slot, link)
                    if not protected then
                        count = count + 1
                        queue[#queue + 1] = {
                            bag = bag, slot = slot, link = link,
                            value = unit * stackCount,
                        }
                    end
                end
            end
        end
    end

    if count == 0 then
        Valuate:MarkAutomation("junkSell", "no sellable junk found")
        if verbose then print("|cFFFF8800[Valuate]|r No sellable junk found (after protections).") end
        return 0
    end

    Valuate:MarkAutomation("junkSell", string.format("selling %d item(s)", count))
    sellQueue, sellTotal = queue, 0
    SellNextBatch()
    return count
end

-- Repairs at merchants that offer it, optionally trying guild funds first.
function Valuate:AutoRepair(verbose)
    local options = Valuate:GetOptions()
    if not CanMerchantRepair or not CanMerchantRepair() then
        if verbose then print("|cFFFF8800[Valuate]|r This merchant can't repair.") end
        return false
    end

    local cost = GetRepairAllCost and GetRepairAllCost() or 0
    if not cost or cost <= 0 then
        if verbose then print("|cFF00FF00[Valuate]|r Nothing to repair.") end
        return false
    end

    local money = GetCoinTextureString and GetCoinTextureString(cost) or (cost .. "c")

    -- Guild funds first when asked and permitted.
    if options.autoRepairGuildFirst and CanGuildBankRepair and CanGuildBankRepair() then
        local ok = pcall(function() RepairAllItems(1) end)
        if ok then
            Valuate:MarkAutomation("autoRepair", "guild funds, " .. money)
            print("|cFF00FF00[Valuate]|r Repaired using guild funds (" .. money .. ").")
            return true
        end
    end

    if GetMoney() < cost then
        -- Recorded as well as printed. "Could not afford it" is exactly the kind of
        -- did-nothing the report exists to explain, and a chat line scrolls away.
        Valuate:MarkAutomation("autoRepair", "could not afford " .. money)
        print("|cFFFF5555[Valuate]|r Not enough money to repair (" .. money .. ").")
        return false
    end

    RepairAllItems()
    Valuate:MarkAutomation("autoRepair", "repaired for " .. money)
    print("|cFF00FF00[Valuate]|r Repaired for " .. money .. ".")
    return true
end

-- Auto-rolls on a group loot roll when options.autoRollLoot is enabled.
-- Need when the item is an upgrade for ANY configured scale (active or not), Greed
-- otherwise. Never rolls Need on something that isn't an upgrade.
-- rollID: the roll being offered. isRetry guards the one-shot item-cache retry.
-- ============================================================================
-- Learnable recipes
-- ============================================================================
-- Professions the character actually has.
--
-- GetProfessions() is a later-expansion API - other addons on this client guard it
-- before calling - so the skill list is the reliable source here. Headers
-- ("Professions", "Secondary Skills") are skipped; only real skill lines count.
-- Professions that can own a recipe or consume materials. Gathering skills are
-- absent: they have no recipes, and they produce materials rather than needing
-- them, so offering them as overrides would only invite mistakes.
local OVERRIDABLE_PROFESSIONS = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "First Aid", "Inscription", "Jewelcrafting", "Leatherworking", "Tailoring",
}

local function GetKnownProfessions()
    local out = {}
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, (GetNumSkillLines() or 0) do
            local skillName, isHeader = GetSkillLineInfo(i)
            if skillName and not isHeader then
                out[skillName] = true
            end
        end
    end

    -- Manual overrides are ADDITIVE, never subtractive. Detection reads the skill
    -- list, which silently returns nothing when its headers are collapsed - so the
    -- override list exists to make the feature work regardless of that, and taking
    -- something away here would just reintroduce the problem from the other side.
    local overrides = Valuate.GetOptions and Valuate:GetOptions().professionOverrides
    if type(overrides) == "table" then
        for prof, enabled in pairs(overrides) do
            if enabled then out[prof] = true end
        end
    end
    return out
end

-- The list offered in Settings, and whether each is auto-detected right now.
function Valuate:GetProfessionOverrideChoices()
    local detected = {}
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, (GetNumSkillLines() or 0) do
            local skillName, isHeader = GetSkillLineInfo(i)
            if skillName and not isHeader then detected[skillName] = true end
        end
    end
    return OVERRIDABLE_PROFESSIONS, detected
end

-- Blizzard prints "Already known" on a recipe you have learned.
local function TooltipSaysAlreadyKnown(tooltipName)
    local tooltip = _G[tooltipName]
    if not tooltip then return false end
    local known = ITEM_SPELL_KNOWN or "Already known"
    for i = 2, tooltip:NumLines() do
        local fs = getglobal(tooltipName .. "TextLeft" .. i)
        local text = fs and fs.GetText and fs:GetText()
        if text == known then return true end
    end
    return false
end

-- Which professions CONSUME each trade-goods subtype.
--
-- Trade goods don't say what they're for, so this mapping is the whole feature.
-- Gathering professions are deliberately absent: a miner produces ore, they don't
-- need to win it off a corpse, and listing them would make every miner Need every
-- piece of metal. "Elemental" legitimately maps to almost everything - elementals
-- are used across the crafting professions.
--
-- Subtype strings are localised; this client is enUS, matching the approach already
-- taken for EXCLUDED_WEAPON_SUBTYPES.
local TRADE_GOOD_PROFESSIONS = {
    ["Cloth"]          = { "Tailoring", "First Aid" },
    ["Leather"]        = { "Leatherworking" },
    ["Metal & Stone"]  = { "Blacksmithing", "Engineering", "Jewelcrafting" },
    ["Herb"]           = { "Alchemy", "Inscription" },
    ["Elemental"]      = { "Alchemy", "Blacksmithing", "Engineering",
                           "Leatherworking", "Tailoring", "Jewelcrafting" },
    ["Enchanting"]     = { "Enchanting" },
    ["Jewelcrafting"]  = { "Jewelcrafting" },
    ["Parts"]          = { "Engineering" },
    ["Devices"]        = { "Engineering" },
    ["Explosives"]     = { "Engineering" },
    ["Meat"]           = { "Cooking" },
}

-- Is this a trade good used by one of our professions?
-- Returns isUseful, professionName.
function Valuate:IsUsefulTradeGood(itemLink)
    if not itemLink then return false end

    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    if itemType ~= "Trade Goods" or not itemSubType then return false end

    local users = TRADE_GOOD_PROFESSIONS[itemSubType]
    -- Unmapped subtypes ("Other", "Materials", the generic bucket) are left alone
    -- rather than guessed at.
    if not users then return false end

    local professions = GetKnownProfessions()
    if not next(professions) then return false end
    for _, prof in ipairs(users) do
        if professions[prof] then return true, prof end
    end
    return false
end

-- Is this a recipe for a profession we have, that we haven't learned yet?
-- Returns isLearnable, professionName, blockReason.
-- blockReason is set when the answer is false, so diagnostics can say WHY rather
-- than leaving four different causes looking identical.
--
-- The required SKILL LEVEL is deliberately ignored: a recipe you can't use yet is
-- still worth taking, because you will train into it. That is the whole point of
-- this feature, so the usual "can you use it right now" checks must not apply.
--
-- tooltipSetter/... let the caller point the private tooltip at the exact source
-- (a loot roll, a bag slot), which is the only way to read "Already known".
function Valuate:IsLearnableRecipe(itemLink, tooltipSetter, ...)
    if not itemLink then return false end

    -- itemType/itemSubType are localised strings; this client is enUS, and the
    -- subtype of a recipe is the profession name ("Blacksmithing", "Cooking", ...).
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
    if itemType ~= "Recipe" or not itemSubType then return false, nil, "not a recipe" end

    local professions = GetKnownProfessions()
    -- An empty list means we could not read the skills (collapsed headers, or the
    -- API is unavailable). Refuse rather than guess: rolling Need on a recipe for a
    -- profession you don't have is a rude thing to do to a group.
    if not next(professions) then return false, nil, "no professions detected" end
    if not professions[itemSubType] then
        return false, nil, "you don't have " .. itemSubType .. " on this character"
    end

    -- Already carrying one? A second copy teaches you nothing, so don't take it off
    -- someone who could use it. Bank included - a spare sitting in the bank is still
    -- a spare. The item being rolled for isn't in your bags yet, so this only ever
    -- counts copies you already had.
    if GetItemCount then
        local owned = GetItemCount(itemLink, true) or 0
        if owned > 0 then
            return false, nil, string.format("you already have %d in your bags/bank", owned)
        end
    end

    if tooltipSetter then
        local tooltip = GetPrivateTooltip()
        if tooltip and type(tooltip[tooltipSetter]) == "function" then
            tooltip:ClearLines()
            local args = { ... }
            local ok = pcall(function() tooltip[tooltipSetter](tooltip, unpack(args)) end)
            if ok and TooltipSaysAlreadyKnown("ValuatePrivateTooltip") then
                return false, nil, "already known"
            end
        end
    end

    return true, itemSubType
end

-- Is PassLoot also going to roll on this loot?
--
-- Valuate-PassLoot registers a RULE that PassLoot evaluates - it doesn't roll
-- itself - so with both Valuate's auto-roll and a PassLoot rule active, TWO addons
-- act on the same START_LOOT_ROLL. They can disagree (Valuate Needs an unlearned
-- recipe while a PassLoot rule passes on it), and which one lands is a race.
--
-- Deliberately not arbitrated: there is no way to know which the player meant, and
-- silently overriding the other addon would be worse than saying so. This just
-- makes the overlap visible where the user is already looking.
function Valuate:IsPassLootRollingToo()
    local pl = _G.PassLoot
    if not pl or not pl.GetModule then return false end
    local ok, mod = pcall(pl.GetModule, pl, "Valuate", true)
    return (ok and mod) and true or false
end

-- What to roll, given whether we want the item and what the game is offering.
--
-- Three booleans, eight combinations, and two of them are the only things that matter:
--
--   * NEVER Need on something we do not want. Needing on gear you cannot use is the thing
--     people get removed from groups for, and it is done on your behalf without asking.
--   * NEVER Pass when Greed is available. Passing costs you the item and gains nobody
--     anything; if we are going to act automatically, the floor is "no worse than Greed".
--
-- Pulled out of AutoRollOnLoot as a named function so those two can be stated as
-- assertions over the whole input space rather than read out of a branch that sits between
-- a tooltip parse and a live RollOnLoot call. Eight cases is small enough to enumerate, and
-- tools/rolltest.js enumerates them.
--
-- Returns: rollType (0 pass / 1 need / 2 greed), label.
local function DecideRollType(wants, canNeed, canGreed)
    if wants and canNeed then return 1, "Need" end
    -- Need is not always offered for something you cannot use yet - a recipe above your
    -- skill is exactly that - and Greed still wins it.
    if canGreed then return 2, "Greed" end
    return 0, "Pass"
end

function Valuate:AutoRollOnLoot(rollID, isRetry)
    local options = Valuate:GetOptions()
    if not options.autoRollLoot or not rollID then return end
    if not GetLootRollItemInfo or not RollOnLoot then return end

    local _, name, _, _, _, canNeed, canGreed = GetLootRollItemInfo(rollID)
    local link = GetLootRollItemLink and GetLootRollItemLink(rollID)

    -- Item data may not be cached yet, which would make the stat parse unreliable.
    -- Retry once shortly; rolls expire, so we only get one grace period.
    if link and not GetItemInfo(link) and not isRetry then
        ValuateAfter(0.5, function() Valuate:AutoRollOnLoot(rollID, true) end)
        return
    end

    local isUpgrade, delta, scaleName = false, 0, nil
    if link then
        local stats = Valuate:GetStatsForTooltipSetter("SetLootRollItem", rollID)
        if stats then
            isUpgrade, delta, scaleName =
                Valuate:IsUpgradeForAnyScale(link, stats, { includeInactive = true })
        end
    end

    -- A recipe for one of your professions that you haven't learned. Checked after
    -- the upgrade test because it uses the same private tooltip, and this call
    -- repoints it.
    local isRecipe, recipeProfession = false, nil
    if link and options.autoRollRecipes ~= false then
        isRecipe, recipeProfession = Valuate:IsLearnableRecipe(link, "SetLootRollItem", rollID)
    end

    -- Crafting materials for a profession we have.
    local isMaterial, materialProfession = false, nil
    if link and not isRecipe and options.autoRollTradeGoods ~= false then
        isMaterial, materialProfession = Valuate:IsUsefulTradeGood(link)
    end

    -- 0 = pass, 1 = need, 2 = greed.
    local rollType, label =
        DecideRollType(isUpgrade or isRecipe or isMaterial, canNeed, canGreed)

    if options.chatMessages then
        local reason
        if isRecipe then
            reason = string.format("unlearned %s recipe", recipeProfession or "profession")
            -- Say so when we wanted Need and couldn't have it, rather than leaving a
            -- Greed on a learnable recipe looking like the feature simply failed.
            if not canNeed then
                reason = reason .. ", |cFFFF8800Need not offered|r"
            end
        elseif isMaterial then
            reason = string.format("%s material", materialProfession or "profession")
            if not canNeed then
                reason = reason .. ", |cFFFF8800Need not offered|r"
            end
        elseif isUpgrade then
            reason = string.format("upgrade for %s, +%.1f", scaleName or "a scale", delta or 0)
        else
            reason = "not an upgrade"
        end
        print(string.format("|cFF00FF00Valuate|r rolled |cFFFFD700%s|r on %s |cFFAAAAAA(%s)|r",
            label, link or name or "item", reason))
    end

    Valuate:MarkAutomation("autoRoll", string.format("%s on %s", label, name or "an item"))
    RollOnLoot(rollID, rollType)
end

-- Confirms the "are you sure?" popup that follows a Need roll on a BoP item.
function Valuate:ConfirmAutoLootRoll(rollID, rollType)
    local options = Valuate:GetOptions()
    if not options.autoRollLoot or not rollID then return end
    if ConfirmLootRoll then ConfirmLootRoll(rollID, rollType) end
end

-- Auto-accepts quests offered by NPCs when options.autoAcceptQuests is enabled.
-- Handles the whole accept flow:
--   QUEST_DETAIL         - a single quest offer -> AcceptQuest()
--   QUEST_ACCEPT_CONFIRM - escort / party-shared quest -> ConfirmAcceptQuest()
--   QUEST_GREETING       - old-style multi-quest NPC -> open the first available
--   GOSSIP_SHOW          - gossip NPC that also offers quests -> open the first available
-- Opening an available quest fires QUEST_DETAIL, which accepts it; the greeting/
-- gossip then re-fires for the next, so multi-quest NPCs clear one at a time.
-- Is a quest trivial (far below your level) and therefore skippable?
-- questLevel of nil means "couldn't tell" - never skip in that case, because
-- silently declining a quest you wanted is far worse than accepting a grey one.
local function IsTrivialQuestLevel(questLevel)
    local options = Valuate:GetOptions()
    if not options.autoAcceptSkipTrivial then return false end
    if type(questLevel) ~= "number" or questLevel <= 0 then return false end
    local playerLevel = UnitLevel("player") or 1
    local margin = tonumber(options.autoAcceptTrivialBelow) or 8
    return (playerLevel - questLevel) >= margin
end

-- Reads the gossip quest list without hard-coding its stride.
--
-- Addons on this client disagree about the layout: AutoQuest reads 5 values per
-- quest, Zygor reads 3 (its older-client path). Rather than pick one and hope,
-- derive the stride from the actual return count. Title is always first and level
-- second, which is the only part every layout agrees on - so that is all we use.
-- Returns a table of { title, level } or nil if the shape can't be trusted.
local function ReadGossipQuests()
    if not GetGossipAvailableQuests or not GetNumGossipAvailableQuests then return nil end
    local num = GetNumGossipAvailableQuests() or 0
    if num < 1 then return nil end

    local packed = { GetGossipAvailableQuests() }
    local stride = math.floor(#packed / num)
    if stride < 2 then return nil end  -- no level field available; caller must not filter

    local out = {}
    for i = 1, num do
        local base = (i - 1) * stride
        out[i] = { title = packed[base + 1], level = tonumber(packed[base + 2]) }
    end
    return out
end

function Valuate:AutoAcceptQuests(event)
    local options = Valuate:GetOptions()
    if not options.autoAcceptQuests then return end

    if event == "QUEST_DETAIL" then
        if options.chatMessages then
            local title = GetTitleText and GetTitleText()
            print("|cFF00FF00Valuate|r auto-accepted quest" .. (title and (": " .. title) or "") .. ".")
        end
        AcceptQuest()
    elseif event == "QUEST_ACCEPT_CONFIRM" then
        if ConfirmAcceptQuest then ConfirmAcceptQuest() end
    elseif event == "QUEST_GREETING" then
        local numAvail = GetNumAvailableQuests and GetNumAvailableQuests() or 0
        if numAvail > 0 and SelectAvailableQuest then
            -- Pick the first non-trivial quest rather than always index 1, so a grey
            -- quest at the top of the list no longer blocks the real one behind it.
            for i = 1, numAvail do
                local lvl = GetAvailableLevel and GetAvailableLevel(i) or nil
                if not IsTrivialQuestLevel(lvl) then
                    SelectAvailableQuest(i)
                    return
                end
            end
            Valuate:MarkAutomation("questAccept", "all offered quests were trivial - skipped")
        end
    elseif event == "GOSSIP_SHOW" then
        local numAvail = GetNumGossipAvailableQuests and GetNumGossipAvailableQuests() or 0
        if numAvail > 0 and SelectGossipAvailableQuest then
            local quests = ReadGossipQuests()
            if not quests then
                -- Layout wasn't recognised, so we can't judge level. Accept as before -
                -- never silently decline a quest just because we couldn't read it.
                SelectGossipAvailableQuest(1)
                return
            end
            for i = 1, numAvail do
                if not IsTrivialQuestLevel(quests[i] and quests[i].level) then
                    SelectGossipAvailableQuest(i)
                    return
                end
            end
            Valuate:MarkAutomation("questAccept", "all offered quests were trivial - skipped")
        end
    end
end

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- Levelling can make gear you already carry wearable; nothing else triggers a rescan
-- for it, since your bags did not change.
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("EQUIPMENT_SWAP_PENDING")
frame:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("START_LOOT_ROLL")
frame:RegisterEvent("CONFIRM_LOOT_ROLL")
frame:RegisterEvent("LOOT_CLOSED")
frame:RegisterEvent("EQUIP_BIND_CONFIRM")
frame:RegisterEvent("AUTOEQUIP_BIND_CONFIRM")
frame:RegisterEvent("LOOT_BIND_CONFIRM")
-- USE_BIND_CONFIRM intentionally NOT registered - see HandleBindConfirm (taints the
-- protected item-use path and gets the addon blocked).
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
frame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
frame:RegisterEvent("ITEM_PUSH")
-- Event errors, remembered per event so a failure in a frequently-firing branch
-- (BAG_UPDATE, ITEM_PUSH) reports once instead of once per fire.
local eventErrors = {}
local eventErrorOrder = {}

-- Wrapped so a bug in one event branch cannot silently disable part of the addon.
--
-- Most players run with scriptErrors OFF, which is the default: an unhandled error
-- there is swallowed entirely, so the symptom is "some feature just stopped" with
-- nothing to point at. That is the worst possible failure mode for an addon this
-- size, and every silent-failure bug in this project has cost more to find than it
-- did to fix.
--
-- The trade: with scriptErrors ON you would otherwise get a full traceback, and now
-- you get the message only. The message carries file:line, which is usually enough,
-- and it is a good deal in exchange for the errors being visible at all by default.
frame:SetScript("OnEvent", function(self, event, ...)
    local ok, err = pcall(OnEvent, self, event, ...)
    if ok or eventErrors[event] then return end

    eventErrors[event] = tostring(err)
    eventErrorOrder[#eventErrorOrder + 1] = event
    print("|cFFFF0000[Valuate]|r Error while handling " .. tostring(event) .. ":")
    print("  " .. tostring(err))
    print("  |cFFAAAAAAReported once per event. /valuate errors to list them again.|r")
end)

-- Lists what has gone wrong this session. Empty is the expected answer; anything
-- here is worth reporting, since it means a code path is broken rather than merely
-- switched off.
-- Records a runtime error from somewhere that is NOT an event handler, using the same
-- once-only reporting and the same /valuate errors listing.
--
-- A method rather than a local because the callers live far above this point in the
-- file - a local declared here would be a nil global up there, which is the trap this
-- project has now hit twice. Methods on the Valuate table are resolved when they are
-- CALLED, so ordering does not matter.
function Valuate:ReportRuntimeError(key, err)
    key = tostring(key or "unknown")
    if eventErrors[key] then return end

    eventErrors[key] = tostring(err)
    eventErrorOrder[#eventErrorOrder + 1] = key
    print("|cFFFF0000[Valuate]|r Error in " .. key .. ":")
    print("  " .. tostring(err))
    print("  |cFFAAAAAAReported once. /valuate errors to list them again.|r")
end

function Valuate:GetEventErrors()
    local list = {}
    for _, event in ipairs(eventErrorOrder) do
        list[#list + 1] = { event = event, message = eventErrors[event] }
    end
    return list
end

-- Re-evaluate the bag-upgrade prompt whenever best-equipment data changes (any scan).
-- "scan" trigger hides the popup once you're wearing the best set, and drives the
-- "oncePerUpgrade" mode; the loot path handles the "everyLoot" re-prompt.
if Valuate.RegisterBestEquipmentListener then
    Valuate:RegisterBestEquipmentListener(function()
        if Valuate.CheckBagUpgradeNotify then Valuate:CheckBagUpgradeNotify("scan") end
    end)
end

-- ========================================
-- Status report (/valuate report)
-- ========================================
-- One digest of where your gear stands and what the automation is actually set to do.
-- Deliberately answers the questions that otherwise need three separate commands:
-- what upgrades are waiting, how much they're worth, which weapon set is live, whether
-- bags are under pressure, and which automation is armed.
function Valuate:PrintReport()
    local options = Valuate:GetOptions()
    local scales = Valuate:GetScales()
    local activeScales = Valuate:GetActiveScales()
    local decimals = options.decimalPlaces or 1
    local fmt = "%." .. decimals .. "f"

    print("|cFF00FF00[Valuate]|r Report  |cFFAAAAAA(v" .. (Valuate.version or "?") .. ")|r")

    if #activeScales == 0 then
        print("  |cFFFF8800No active scales.|r Activate one in the Scales tab.")
        return
    end

    -- Equipped score per slot, parsed once and shared across scales.
    local equippedStats = {}
    for slotId = 1, 18 do
        if slotId ~= 4 and GetInventoryItemLink("player", slotId) then
            equippedStats[slotId] =
                Valuate:GetStatsForTooltipSetter("SetInventoryItem", "player", slotId)
        end
    end

    local _, primaryName = Valuate:GetPrimaryScale()

    for _, scaleName in ipairs(activeScales) do
        local scale = scales[scaleName]
        if scale then
            local be = Valuate:GetBestEquipment()[scaleName]
            local color = scale.Color or "FFFFFF"
            local label = scale.DisplayName or scaleName
            local isPrimary = (scaleName == primaryName)

            -- Equipped vs best-achievable, and what the upgrades are worth.
            local equippedTotal, bestTotal, gain = 0, 0, 0
            if be then
                local locks = be.locks or {}
                for slotId = 1, 18 do
                    if slotId ~= 4 then
                        local eq = equippedStats[slotId]
                            and Valuate:CalculateItemScore(equippedStats[slotId], scale) or 0
                        local best = (not locks[slotId]) and be[slotId] and be[slotId].score or 0
                        equippedTotal = equippedTotal + eq
                        bestTotal = bestTotal + math.max(eq, best)
                        if best > eq then gain = gain + (best - eq) end
                    end
                end
            end

            local count = be and Valuate:CountEquippableUpgrades(scaleName) or 0
            print(string.format("  |cFF%s%s|r%s  equipped " .. fmt .. " / best " .. fmt,
                color, label, isPrimary and " |cFFFFD700(current spec)|r" or "",
                equippedTotal, bestTotal))

            if not be then
                print("      |cFFAAAAAAno scan data - run /valuate scan|r")
            elseif count > 0 then
                print(string.format("      |cFF00FF00%d upgrade(s) in bags, +" .. fmt .. " available|r",
                    count, gain))
            else
                print("      |cFFAAAAAAwearing the best equippable items|r")
            end

            -- Weapon sets, primary scale only (keeps the digest readable).
            if isPrimary and be and be.weaponSets then
                for _, def in ipairs(Valuate:GetWeaponSetDefinitions()) do
                    local set = be.weaponSets[def.key]
                    if set then
                        print(string.format("      %s%-13s|r " .. fmt,
                            def.key == be.activeWeaponSet and "|cFFFFD700> " or "|cFFAAAAAA  ",
                            def.label, set.total or 0))
                    end
                end
            end
        end
    end

    -- Bag pressure - the number auto-delete actually acts on.
    local free = CountFreeBagSlots()
    local keepFree = options.autoDeleteKeepFree or 4
    print(string.format("  Bags: %d free (target %d)%s", free, keepFree,
        free < keepFree and " |cFFFF8800- below target|r" or ""))

    -- What is actually armed. Silence here is why "nothing happened" is confusing.
    -- Sub-options are reported UNDER their parent rather than as separate entries.
    -- A flat list of every toggle would be accurate but unreadable, and the thing
    -- you actually want to know is "what will this do when it fires".
    local on = {}
    local function add(enabled, label)
        if enabled then on[#on + 1] = label end
    end
    local function withExtras(label, extras)
        if #extras == 0 then return label end
        return label .. " (+" .. table.concat(extras, ", +") .. ")"
    end

    add(options.autoAcceptQuests, options.autoAcceptSkipTrivial
        and "accept quests (skipping trivial)" or "accept quests")
    add(options.autoQuestReward, "pick quest reward")
    add(options.autoQuestTurnIn, "turn in quests")

    if options.autoRollLoot then
        local extras = {}
        if options.autoRollRecipes ~= false then extras[#extras + 1] = "recipes" end
        if options.autoRollTradeGoods ~= false then extras[#extras + 1] = "materials" end
        add(true, withExtras("roll on loot", extras))
    end

    if options.notifyBagUpgrade then
        local extras = {}
        if options.notifyOtherSpecUpgrades then extras[#extras + 1] = "other specs" end
        if options.notifyUpgradeSound then extras[#extras + 1] = "sound" end
        add(true, withExtras(
            (options.notifyBagUpgradeStyle == "chat") and "upgrade alert (chat)" or "upgrade popup",
            extras))
    end

    add(options.showUpgradeArrows, "upgrade arrows")
    add(options.includeBankItems, "bank items counted")

    if options.autoDeleteJunk then
        local iv = tonumber(options.autoDeleteIntervalSecs) or 0
        add(true, iv > 0 and string.format("delete junk (every %ds)", iv) or "delete junk")
    end
    add(options.autoSellJunk, "sell junk")
    add(options.autoRepair, "repair")

    -- Surplus-gear marking lives in the AdiBags module's own settings, but it feeds
    -- THIS addon's auto-delete, so someone running both needs to see them together
    -- rather than discovering the combination the hard way.
    local ab = _G.AdiBags
    local abMod = ab and ab.GetModule and select(2, pcall(ab.GetModule, ab, "ValuateBestItems", true))
    if type(abMod) == "table" and abMod.db and abMod.db.profile.markNonBestAsJunk then
        add(true, "|cFFFF8800mark surplus gear as junk|r")
    end

    -- Conflicts belong next to the list of what's armed, not buried in a sub-command.
    if options.autoRollLoot and Valuate:IsPassLootRollingToo() then
        add(true, "|cFFFF8800PassLoot also rolling - they can disagree|r")
    end
    if #on > 0 then
        print("  Automation on: |cFF00FF00" .. table.concat(on, ", ") .. "|r")
    else
        print("  Automation: |cFFAAAAAAall off|r")
    end

    -- Heartbeat: when each automated path last ran and what it concluded. This is
    -- the line that answers "is it even running?" - the question every silent
    -- automation bug so far has forced people to guess at.
    local HEARTBEATS = {
        { key = "scan",          label = "Gear scan" },
        { key = "junkCleanup",   label = "Junk cleanup" },
        { key = "junkSell",      label = "Junk selling" },
        { key = "upgradeNotify", label = "Upgrade alert" },
        -- questAccept has been RECORDED since auto-accept existed and never displayed:
        -- the outcome was captured and thrown away. autoRoll and autoRepair had no
        -- heartbeat at all, so the report could not say whether they had run.
        { key = "questAccept",   label = "Quest auto-accept" },
        { key = "autoRoll",      label = "Loot roll" },
        { key = "autoRepair",    label = "Auto-repair" },
        { key = "questReward",   label = "Quest reward taken" },
        { key = "bankSnapshot",  label = "Bank snapshot" },
        { key = "wardrobe",      label = "Wardrobe collecting" },
    }
    print("  |cFFAAAAAALast run this session:|r")
    for _, hb in ipairs(HEARTBEATS) do
        local ago, outcome = Valuate:GetAutomationHeartbeat(hb.key)
        if ago then
            print(string.format("    %s: |cFFFFFFFF%s ago|r |cFFAAAAAA(%s)|r",
                hb.label, SecondsToTime(math.max(1, math.floor(ago))), outcome or "ran"))
        else
            print(string.format("    %s: |cFFAAAAAAnot yet this session|r", hb.label))
        end
    end
end

-- ========================================
-- Self-test (/valuate selftest)
-- ========================================
-- Fast in-game sanity check of the plumbing: options completeness, core methods
-- present + callable, key data structures well-formed, tooltip parsing alive. It
-- doesn't prove behaviour is correct, but it catches a broken build the moment you
-- reload - a missing method, a nil'd option, a parser that stopped returning stats.
function Valuate:RunSelfTest()
    local pass, fail = 0, 0
    local function check(ok, label, detail)
        if ok then
            pass = pass + 1
        else
            fail = fail + 1
            print("|cFFFF5555  FAIL|r " .. label .. (detail and (" - " .. detail) or ""))
        end
    end

    print("|cFF00FF00[Valuate]|r Self-test (v" .. (Valuate.version or "?") .. ")...")

    -- Options completeness against the single source of truth.
    local options = Valuate:GetOptions()
    check(type(options) == "table", "GetOptions returns a table")
    if type(options) == "table" then
        local missing = {}
        for key in pairs(DEFAULT_OPTIONS) do
            if options[key] == nil then missing[#missing + 1] = key end
        end
        check(#missing == 0, "all option keys present", #missing > 0 and ("missing: " .. table.concat(missing, ", ")) or nil)
    end

    -- Core methods exist and are callable.
    local methods = {
        "GetScales", "GetActiveScales", "GetBestEquipment", "ScanBestEquipment",
        "ParseStatsFromTooltip", "CalculateItemScore", "GetItemUpgradeInfo",
        "IsUpgradeForAnyScale", "GetBestForInfo", "GetFutureUpgradeScales",
        "EquipBestSet", "SaveEquipmentSetForScale", "GetWeaponSetDefinitions",
        "IsWeaponSetEnabled", "GetUpgradeBaseline", "GetStatsForTooltipSetter",
        "GetPrimaryScale", "GetPrivateTooltip", "AutoRollOnLoot", "AutoDeleteJunk",
        "HandleBindConfirm", "MarkEquipIntent", "AutoAcceptQuests",
        "ScanBankContents", "GetBankCache", "MarkAutomation", "GetAutomationHeartbeat",
        "IsItemLinkUpgrade", "ResetUpgradeArrowCache",
        "IsLearnableRecipe", "IsUsefulTradeGood", "GetProfessionOverrideChoices",
        "GetScaleLibrary", "SaveScaleToLibrary", "LoadScaleFromLibrary", "ListScaleLibrary",
        "SaveSettingsSnapshot", "LoadSettingsSnapshot", "HasSettingsSnapshot",
        "RestoreDefaultOptions", "IsPassLootRollingToo", "GetEventErrors",
        "ShowUpgradePopup", "HideUpgradePopup",
        "RunProfile", "RunVerify", "CountEquippableUpgrades", "PrintScaleList", "GetJunkVerdict",
        "AnnounceUnlockedUpgrades",
        "ReportRuntimeError",
        -- The scale wizard. Absent from this list for its first eleven releases, which meant
        -- selftest reported all-clear while the whole subsystem could be missing - and it is
        -- the subsystem a new user meets first.
        "MatchTemplateToStats", "NormalizeWeights", "BuildAutoScaleName",
        "BuildUniqueAutoScaleName", "FindMatchingAutoScale",
        "PlanAutoScale", "CommitAutoScale", "GetAutoScaleDrift", "GetCacheStats",
        -- These two live in ui/Wizard.lua and MinimapButton.lua rather than here, which is
        -- exactly why they are worth checking: a module that failed to load leaves the rest
        -- of the addon working and only these missing.
        "ShowScaleWizard", "ApplyMinimapButtonOptions",
        -- ARCHITECTURE.md tells integrations to register through this. If it disappeared,
        -- AdiBags would simply stop refreshing and nothing would say why.
        "RegisterBestEquipmentListener",
        -- Picks the CoA or classic template set. Lives in ui/Data.lua, so this also proves
        -- that module loaded.
        "GetTemplateSet",
    }
    for _, m in ipairs(methods) do
        check(type(Valuate[m]) == "function", "method " .. m)
    end

    -- Data structures well-formed.
    check(type(Valuate:GetScales()) == "table", "GetScales structure")
    check(type(Valuate:GetActiveScales()) == "table", "GetActiveScales structure")

    -- GetPrimaryScale finds the first active scale WITHOUT building the sorted list,
    -- because it runs for every item icon on every bag repaint. Two orderings written
    -- separately is exactly how they drift, and the symptom would be quiet: arrows
    -- following one scale while the Best Equipment columns lead with another.
    --
    -- Only meaningful when no explicit character-window scale is in force; that path
    -- is an override, so disagreeing with the list order there is correct.
    do
        local activeList = Valuate:GetActiveScales()
        local preferred = Valuate:GetOptions().characterWindowScale
        local preferredActive = false
        for _, n in ipairs(activeList) do
            if n == preferred then preferredActive = true break end
        end
        if #activeList > 0 and not preferredActive then
            local _, primaryName = Valuate:GetPrimaryScale()
            check(primaryName == activeList[1], "primary scale matches the active-scale order",
                  primaryName ~= activeList[1]
                      and ("primary is " .. tostring(primaryName) ..
                           " but the list leads with " .. tostring(activeList[1])) or nil)
        end
    end
    check(type(Valuate:GetBestEquipment()) == "table", "GetBestEquipment structure")

    -- THE key invariant, and the only one that cannot be checked without a running
    -- client: [slotId] holds an item equippable RIGHT NOW, and anything gated behind
    -- level or proficiency lives in .future instead.
    --
    -- Three features rest on it. The upgrade prompt treats a slot mismatch as a
    -- genuinely wearable upgrade; Equip All tries to equip whatever is there; the
    -- level-up announcement reports what has just LEFT .future. If a too-high-level
    -- item ever reaches a slot, all three go wrong at once and none of them errors -
    -- you are simply offered gear you cannot wear.
    --
    -- ARCHITECTURE.md states this as fact. Nothing verified it until now.
    do
        local playerLevel = (UnitLevel and UnitLevel("player")) or 0
        local unwearable, firstBad = 0, nil
        local be = Valuate:GetBestEquipment()
        for _, scaleName in ipairs(Valuate:GetActiveScales()) do
            local slots = be[scaleName]
            if type(slots) == "table" then
                for slotId = 1, 18 do
                    local entry = slots[slotId]
                    if type(entry) == "table" and entry.itemLink then
                        local _, _, _, _, minLevel = GetItemInfo(entry.itemLink)
                        -- minLevel nil means the item is not cached yet; skip rather
                        -- than report a failure the client simply cannot answer.
                        if minLevel and playerLevel > 0 and minLevel > playerLevel then
                            unwearable = unwearable + 1
                            firstBad = firstBad or (scaleName .. " slot " .. slotId
                                .. " needs level " .. minLevel .. ": " .. entry.itemLink)
                        end
                    end
                end
            end
        end
        check(unwearable == 0, "best-in-slot entries are all equippable now",
              unwearable > 0 and (unwearable .. " too high level, e.g. " .. tostring(firstBad)) or nil)
    end

    -- Bank snapshot: well-formed, and consistent with what the panel claims.
    -- A best-in-slot entry flagged "bank" that is NOT in the snapshot means the two
    -- have desynced - the panel would badge an item Equip All then can't explain.
    local bankCache = Valuate:GetBankCache()
    check(type(bankCache) == "table" and type(bankCache.items) == "table", "bank cache structure")
    if type(bankCache.items) == "table" then
        local malformed = 0
        for _, entry in pairs(bankCache.items) do
            if type(entry) ~= "table" or not entry.itemLink or type(entry.stats) ~= "table" then
                malformed = malformed + 1
            end
        end
        check(malformed == 0, "bank cache entries well-formed",
              malformed > 0 and (malformed .. " malformed entr(ies)") or nil)

        local orphaned = 0
        for _, slots in pairs(Valuate:GetBestEquipment()) do
            if type(slots) == "table" then
                for slotId = 1, 18 do
                    local item = slots[slotId]
                    if type(item) == "table" and item.source == "bank" and item.itemLink then
                        local id = GetItemIdFromLink(item.itemLink)
                        if id and not bankCache.items[id] then orphaned = orphaned + 1 end
                    end
                end
            end
        end
        check(orphaned == 0, "bank-sourced best items exist in the snapshot",
              orphaned > 0 and (orphaned .. " orphaned; re-visit a bank to refresh") or nil)
    end

    -- Anything that errored this session. Worth failing on: it means a code path is
    -- broken rather than merely switched off, and with scriptErrors off by default
    -- this is otherwise invisible.
    local errs = Valuate:GetEventErrors()
    check(#errs == 0, "no event errors this session",
          #errs > 0 and (#errs .. " - see /valuate errors") or nil)

    -- Scale library: entries must be TAGS (strings). Storing a scale table here by
    -- mistake would import as garbage on another character, and the failure would
    -- surface on a different character from the one that caused it.
    local lib = Valuate:GetScaleLibrary()
    check(type(lib) == "table", "scale library structure")
    if type(lib) == "table" then
        local bad = 0
        for _, tag in pairs(lib) do
            if type(tag) ~= "string" or tag == "" then bad = bad + 1 end
        end
        check(bad == 0, "library entries are scale tags",
              bad > 0 and (bad .. " entr(ies) are not strings") or nil)
    end

    -- Profession overrides must be a name -> boolean map. A stray non-string key
    -- would silently never match a recipe's subtype.
    local overrides = Valuate:GetOptions().professionOverrides
    check(type(overrides) == "table", "profession overrides structure")
    if type(overrides) == "table" then
        local badKeys = 0
        for name in pairs(overrides) do
            if type(name) ~= "string" then badKeys = badKeys + 1 end
        end
        check(badKeys == 0, "profession override keys are names",
              badKeys > 0 and (badKeys .. " non-string key(s)") or nil)
    end

    -- Escape-to-close: a frame silently missing from UISpecialFrames looks identical
    -- to one that is there, so it is worth asserting.
    --
    -- Every Valuate frame is created LAZILY - the main window on first /valuate ui,
    -- the dialogs and pickers on first use - so only frames that actually exist yet
    -- are checked. Asserting on all of them would fail on a fresh login for frames
    -- that simply have not been opened, and a selftest that cries wolf is worse than
    -- no selftest.
    if UISpecialFrames then
        local registered = {}
        for _, name in ipairs(UISpecialFrames) do registered[name] = true end

        local created, missing = 0, {}
        for _, name in ipairs({
            "ValuateUIFrame", "ValuateConfirmDialog", "ValuateUpgradePopup",
            "ValuateImportExportDialog", "ValuateScaleLibraryFrame",
            "ValuateIconPickerFrame", "ValuateTemplatePickerFrame",
            "ValuateClassSpecificPickerFrame",
        }) do
            if _G[name] then
                created = created + 1
                if not registered[name] then missing[#missing + 1] = name end
            end
        end
        check(#missing == 0,
              string.format("Escape closes every created window (%d so far)", created),
              #missing > 0 and ("not registered: " .. table.concat(missing, ", ")) or nil)
    end

    -- Weapon-set metadata is the expected shape.
    local defs = Valuate:GetWeaponSetDefinitions()
    check(type(defs) == "table" and #defs == 4, "weapon-set definitions (4)",
        type(defs) == "table" and ("got " .. #defs) or nil)
    if type(defs) == "table" then
        for _, d in ipairs(defs) do
            check(d.key and d.label and d.short, "weapon-set def has key/label/short", d.key)
        end
    end

    -- Tooltip parsing is alive: parse whatever is in the chest slot (5) if worn.
    local chestLink = GetInventoryItemLink("player", 5)
    if chestLink then
        local ok, stats = pcall(function()
            return Valuate:GetStatsForTooltipSetter("SetInventoryItem", "player", 5)
        end)
        check(ok, "tooltip parse runs without error")
        check(ok and type(stats) == "table", "tooltip parse returns stats for equipped chest")

        -- Exercise the upgrade / value / notify APIs on a real item under pcall, so a
        -- RUNTIME error (the class the syntax gate can't see) is caught here rather than
        -- mid-loot or mid-delete. Results don't matter; not erroring does.
        local function runs(label, fn)
            local okc, err = pcall(fn)
            check(okc, label, (not okc) and tostring(err) or nil)
        end
        runs("GetItemUpgradeInfo runs", function() Valuate:GetItemUpgradeInfo(chestLink, stats or {}, { includeInactive = true }) end)
        runs("IsUpgradeForAnyScale runs", function() Valuate:IsUpgradeForAnyScale(chestLink, stats or {}) end)
        runs("GetUpgradeBaseline runs", function()
            local sc, sn = Valuate:GetPrimaryScale()
            if sc then Valuate:GetUpgradeBaseline(chestLink, sc, sn) end
        end)
        runs("GetItemUnitValue runs", function() Valuate:GetItemUnitValue(chestLink, "vendor") end)
        runs("GetBestForInfo runs", function() Valuate:GetBestForInfo(chestLink) end)
    else
        print("|cFFAAAAAA  (skipped item-API checks - no chest equipped)|r")
    end

    -- Integration sanity: not "did it error" but "is the answer plausible". AdiBags
    -- being loaded while classifying ZERO of a full bag as junk is the exact signature
    -- of the CheckItem/IsJunk contract bug - a crash-free wrong answer that cost days.
    do
        local AdiBags, junkModule
        if LibStub then
            local ace = LibStub("AceAddon-3.0", true)
            AdiBags = ace and ace:GetAddon("AdiBags", true)
            if AdiBags and AdiBags.GetModule then
                junkModule = AdiBags:GetModule("Junk", true)
            end
        end
        if AdiBags then
            check(junkModule ~= nil, "AdiBags Junk module resolves",
                "GetModule('Junk') returned nil - junk detection will fall back")
            if junkModule and junkModule.CheckItem then
                -- Deliberately goes through IsItemJunk - the same helper the delete and
                -- sell paths use - so this tests the REAL classification, not a parallel
                -- probe that could drift from it.
                local scanned, junk = 0, 0
                for bag = 0, 4 do
                    for slot = 1, (GetContainerNumSlots(bag) or 0) do
                        local link = GetContainerItemLink(bag, slot)
                        if link then
                            scanned = scanned + 1
                            local id = GetItemIdFromLink(link)
                            local _, _, quality = GetItemInfo(link)
                            if IsItemJunk(AdiBags, junkModule, id, quality) then
                                junk = junk + 1
                            end
                        end
                    end
                end
                print(string.format("|cFFAAAAAA  AdiBags junk: %d of %d bag item(s) classified|r", junk, scanned))
                -- Not a hard failure (a genuinely junk-free bag is possible), but loud:
                -- a full bag with zero junk almost always means a broken contract.
                if scanned >= 20 and junk == 0 then
                    print("|cFFFF8800  WARN|r AdiBags classified 0 junk across " .. scanned ..
                        " items - verify the Junk filter, or the CheckItem contract may have changed.")
                end
            end
        else
            print("|cFFAAAAAA  (AdiBags not loaded - junk falls back to grey quality)|r")
        end
    end

    -- The UI is split across ui/*.lua, each of which publishes its entry points onto the
    -- shared namespace. tools/tocsync.js proves a module is LISTED in the .toc; only this
    -- proves it actually LOADED and published. A module that errors while loading, or is
    -- missing from the .toc on this machine, shows up here as a missing symbol instead of
    -- as a broken tab discovered later.
    do
        local uiExports = {
            ["ui/Shared.lua"] = "COLORS",
            ["ui/Data.lua"] = "CLASS_SPEC_TEMPLATES",
            ["ui/Animations.lua"] = "Anim",
            ["ui/Widgets.lua"] = "CreateStyledButton",
            ["ui/Pickers.lua"] = "ShowIconPicker",
            ["ui/ScaleList.lua"] = "CreateScaleList",
            ["ui/ScaleEditor.lua"] = "CreateScaleEditor",
            ["ui/BestEquipment.lua"] = "CreateBestEquipmentPanel",
            ["ui/Settings.lua"] = "CreateSettingsPanel",
            ["ui/InfoPanels.lua"] = "CreateInstructionsPanel",
        }
        for file, symbol in pairs(uiExports) do
            check(ns[symbol] ~= nil, "loaded " .. file,
                "ns." .. symbol .. " is nil - that module did not load or did not publish")
        end
        -- ui/Dialog.lua and ui/CharacterWindow.lua publish onto the Valuate table rather
        -- than the namespace, so they are covered by the method checks above.
    end

    -- Every automation option should have a diagnostic command (CLAUDE.md convention),
    -- and the dialog path must exist or prompts silently vanish.
    check(type(Valuate.ShowConfirmDialog) == "function", "ShowConfirmDialog exists (upgrade prompt path)")
    check(type(Valuate.CheckBagUpgradeNotify) == "function", "CheckBagUpgradeNotify exists")
    check(type(Valuate.AutoSellJunk) == "function", "AutoSellJunk exists")
    check(type(Valuate.AutoRepair) == "function", "AutoRepair exists")

    -- Non-destructive exercise of the scan-dependent helpers.
    do
        local sc, sn = Valuate:GetPrimaryScale()
        if sn then
            local okc, err = pcall(function() Valuate:CountEquippableUpgrades(sn) end)
            check(okc, "CountEquippableUpgrades runs", (not okc) and tostring(err) or nil)
        end
    end

    if fail == 0 then
        print(string.format("|cFF00FF00[Valuate]|r Self-test PASSED (%d checks).", pass))
    else
        print(string.format("|cFFFF5555[Valuate]|r Self-test: %d passed, %d FAILED.", pass, fail))
    end
    return fail == 0
end

-- ========================================
-- Profiler (/valuate profile)
-- ========================================
-- Measures the paths that run often enough to matter: the full gear scan, the
-- per-item scoring called once per item per scale, and tooltip stat parsing which
-- runs on every mouseover. Until now there was no measurement at all, so any claim
-- about Valuate being heavy or light was guesswork.
--
-- Uses debugprofilestop() (millisecond resolution, confirmed present on this
-- client); GetTime() is frame-quantised and would report 0 for everything here.
function Valuate:RunProfile()
    if not debugprofilestop then
        print("|cFFFF5555[Valuate]|r debugprofilestop() unavailable - can't profile on this client.")
        return false
    end
    if equipmentSwapPending or recentEquipmentChange then
        print("|cFFFF8800[Valuate]|r Items are still settling - try again in a moment.")
        return false
    end

    print("|cFF00FF00[Valuate]|r Profile (v" .. (Valuate.version or "?") .. ")...")

    local function timeIt(label, iterations, fn)
        local ok, err = pcall(fn, 1)  -- warm up: first call pays cache/JIT costs
        if not ok then
            print(string.format("|cFFFF5555  %s: errored|r - %s", label, tostring(err)))
            return
        end
        local t0 = debugprofilestop()
        for i = 1, iterations do fn(i) end
        local total = debugprofilestop() - t0
        print(string.format("  %-22s |cFFFFFFFF%7.3f ms|r each  |cFFAAAAAA(%d run%s, %.1f ms total)|r",
            label, total / iterations, iterations, iterations == 1 and "" or "s", total))
    end

    -- Full scan: heavy and infrequent, so a single run is the honest measure.
    timeIt("Full gear scan", 1, function() Valuate:ScanBestEquipment() end)

    -- Scoring: called once per item per scale inside the scan, so its cost is
    -- multiplied by both. Sampled from a real equipped item.
    local scale = Valuate:GetPrimaryScale()
    local sampleStats
    for slotId = 1, 18 do
        if slotId ~= 4 and GetInventoryItemLink("player", slotId) then
            local tooltip = Valuate:GetPrivateTooltip()
            if tooltip then
                tooltip:ClearLines()
                tooltip:SetInventoryItem("player", slotId)
                sampleStats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                if sampleStats then break end
            end
        end
    end

    if scale and sampleStats then
        timeIt("Score one item", 1000, function()
            Valuate:CalculateItemScore(sampleStats, scale)
        end)
    else
        print("  |cFFAAAAAAScore one item: skipped - no equipped item to sample.|r")
    end

    -- Tooltip parsing runs on every gear mouseover, so it is the most
    -- user-perceptible path of the three.
    local tooltip = Valuate:GetPrivateTooltip()
    if tooltip and GetInventoryItemLink("player", 16) then
        timeIt("Parse tooltip stats", 200, function()
            tooltip:ClearLines()
            tooltip:SetInventoryItem("player", 16)
            Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
        end)
    else
        print("  |cFFAAAAAAParse tooltip stats: skipped - nothing in main hand.|r")
    end

    -- The per-bag-item integration path. This is the one that actually scales with
    -- bag size: AdiBags calls into both of these for EVERY visible button on every
    -- repaint, so a millisecond here is multiplied by a bagful.
    local sampleLink
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then sampleLink = link break end
        end
        if sampleLink then break end
    end

    if sampleLink then
        -- Cached: what a repaint of an unchanged bag actually costs.
        timeIt("Upgrade arrow (cached)", 500, function()
            Valuate:IsItemLinkUpgrade(sampleLink)
        end)
        -- Uncached: the cost after any scan, since a scan clears the cache and the
        -- next repaint pays full price for every item at once.
        timeIt("Upgrade arrow (cold)", 50, function()
            Valuate:ResetUpgradeArrowCache()
            Valuate:IsItemLinkUpgrade(sampleLink)
        end)
        timeIt("Junk classification", 500, function()
            Valuate:IsItemJunk(GetItemIdFromLink(sampleLink))
        end)
    else
        print("  |cFFAAAAAABag item paths: skipped - no items in your bags to sample.|r")
    end

    print("  |cFFAAAAAAScan runs on loot/equipment changes; scoring and parsing run per item.|r")
    print("  |cFFAAAAAAArrow and junk costs are per VISIBLE bag icon, per repaint.|r")

    -- Are the caches actually HITTING?
    --
    -- A cache that silently never hits looks exactly like one that works - same answers,
    -- same code path, no error, just the old cost back. The timings above cannot tell the
    -- difference, and the gates that proved these numbers counted calls in a test harness,
    -- not in your client. This is the line that carries the claim across.
    local cs = Valuate:GetCacheStats()
    local function rate(hit, miss)
        local total = hit + miss
        if total == 0 then return "not used yet" end
        return string.format("%.0f%% hit |cFFAAAAAA(%d of %d)|r", hit / total * 100, hit, total)
    end
    print("  |cFF00FF00Caches|r |cFFAAAAAA(since login)|r")
    print("    Active-scale list   " .. rate(cs.activeHit, cs.activeBuild))
    print("    Item slot lookups   " .. rate(cs.slotHit, cs.slotMiss))
    print("  |cFFAAAAAAOpen your bags a few times first - these only move when something " ..
          "asks. A low rate after that is a real problem; 'not used yet' just means idle.|r")
    return true
end

-- Prints every scale, in a stable order, with its internal key when that differs from
-- the display name.
--
-- One implementation because there were two, both looping ValuateScales with pairs()
-- and both printing in whatever order Lua felt like - so the same "Available scales"
-- list came out differently on consecutive runs of the same command. Trivial on its
-- own; the reason it matters is that this list is what you read to find the exact name
-- to type back in, and a list that reorders itself is a poor thing to search.
--
-- The key is shown only when it differs, since that is exactly when typing the display
-- name may be ambiguous and the key is what disambiguates.
function Valuate:PrintScaleList()
    local names = {}
    for name in pairs(Valuate:GetScales() or {}) do tinsert(names, name) end
    table.sort(names, function(a, b)
        local scales = Valuate:GetScales()
        local da = scales[a].DisplayName or a
        local db = scales[b].DisplayName or b
        if da ~= db then return da < db end
        return a < b  -- display names may collide; keys cannot
    end)

    for _, name in ipairs(names) do
        local scale = Valuate:GetScales()[name]
        local displayName = scale.DisplayName or name
        if displayName ~= name then
            print("  " .. displayName .. "  |cFFAAAAAA(" .. name .. ")|r")
        else
            print("  " .. displayName)
        end
    end
end

-- ========================================
-- Behavioural verification (/valuate verify)
-- ========================================
-- Six static gates parse and scope-check every file, and tools/animtest.js runs the
-- animation engine headlessly against a mocked API. None of them can answer "does the
-- button look pressed", and a run of releases has now shipped fixes whose only proof
-- is that the reasoning was careful.
--
-- This is the list of what that leaves. Deliberately SHORT - not everything the addon
-- does, only behaviours that fail SILENTLY (nothing errors, it just quietly does
-- nothing), and that are awkward to stumble into on purpose. "Find a gear upgrade
-- while in combat, then leave combat" is not a test anyone actually runs, so the
-- checks that can arm themselves do.
--
-- Each entry names the version that introduced it, so a stale list is visible rather
-- than merely wrong: entries far behind the current version are ones nobody got to.
local VERIFY_CHECKS = {
    {
        id = "cachehit", since = "0.93.0a",
        gate = "tools/hotpath.js",
        title = "The repaint caches actually hit in the client, not just in the harness",
        steps = "Open and close your bags four or five times, moving something between them. Then run /valuate profile and read the Caches section at the bottom.",
        expect = "Both rates well above 90%. 'Not used yet' means nothing asked - open your bags first. Anything below about half means the cache is being thrown away as fast as it fills.",
        broke = "v0.91.0a and v0.92.0a cut a bag repaint from 240 sorts and 240 GetItemInfo calls to none. Every word of that was proved by a gate COUNTING CALLS IN A TEST HARNESS - evidence about the source, not about your client. A cache that silently never hits looks exactly like one that works: same answers, same code path, no error, just the old cost quietly back. This is the only check that can tell the two apart.",
        arm = function()
            if not Valuate.RunProfile then
                return false, "RunProfile is missing."
            end
            Valuate:RunProfile()
            return true, "Read the Caches section above."
        end,
    },
    {
        id = "coaclass", since = "0.79.0a",
        gate = "tools/speccoverage.js",
        title = "A Conquest of Azeroth character is matched against CoA builds, not classic ones",
        steps = "This command prints which template set your character resolved to and the name the client gave for your class. Run it on a CoA realm.",
        expect = "On CoA: the CoA set, and a class name that appears in it - Necromancer, Starcaller, Witch Hunter and so on. On a classless realm: the classic set. Never the classic set on a CoA character.",
        broke = "The whole 21-class, 70-spec feature hangs on one assumption no gate can test: that UnitClass(\"player\") returns the CoA class name at all, spelled the way the templates spell it. If it returns a stock class token instead - or a localised string, or nothing on a classless realm - GetTemplateSet falls through to the classic ten and the entire CoA data set is silently unreachable. Nothing errors. The wizard just quietly proposes an Arms Warrior build to a Necromancer.",
        arm = function()
            if not Valuate.GetTemplateSet then
                return false, "GetTemplateSet is missing - ui/Data.lua did not load."
            end
            local className, classToken = UnitClass("player")
            local set, which = Valuate:GetTemplateSet()
            local count = 0
            for _ in ipairs(set or {}) do count = count + 1 end
            print(string.format(
                "|cFF3FE0C8[Valuate]|r UnitClass says |cFFFFFFFF%s|r (token %s); matched the |cFFFFFFFF%s|r set of %d classes.",
                tostring(className), tostring(classToken), tostring(which), count))
            return true, "Read the line above - does that set match the realm you are on?"
        end,
    },
    {
        id = "newstats", since = "0.72.0a",
        title = "Mastery, Versatility and Leech are actually read off a tooltip",
        steps = "Find any item carrying Mastery, Versatility or Leech - bags, a vendor, the auction house. Hover it, then run /valuate why <item link> for the same item.",
        expect = "The stat is named in the breakdown with the number the tooltip shows. A score that ignores it means the line was not parsed.",
        broke = "These are not stock 3.3.5 stats, so their tooltip wording had to be GUESSED. The parser accepts both \"+12 Mastery Rating\" and a bare \"+12 Mastery\" because I could not see which Ascension uses. If it uses neither - a percentage, a different order, a suffix - every item carrying them scores as though it carried nothing, silently, and the gear that most needs scoring is the gear that gets it wrong. This is the check no headless test can ever replace.",
    },
    {
        id = "scalerefresh", since = "0.89.0a",
        gate = "tools/scalelisttest.js",
        title = "The wizard button offers to REFRESH a scale that has gone stale",
        steps = "On a character with a wizard-made 'Auto - ' scale, level up or change several pieces of gear, then open Valuate and look at the button above the scale list. Hover it, then click through the wizard.",
        expect = "It reads 'Refresh my scale' and its tooltip names the scale. The wizard's preview button says 'Update it', and finishing leaves you with the SAME number of scales - the old one replaced, not a twin. If nothing has drifted it reads 'Make me a scale' as before.",
        broke = "New in this version, and the whole update path is unreachable without it. Two things to watch: a scale you built YOURSELF must never be offered (no teal, no source), and asking for a different ROLE must create rather than replace - a tank build is not a drifted DPS build.",
    },
    {
        id = "wardrobebind", since = "0.74.0a",
        gate = "tools/wardrobetest.js",
        title = "Wardrobe collecting does not bind something you meant to sell",
        steps = "Run /valuate wardrobe to LIST what it would collect - do not enable the automation yet. Pick one item on that list you do not care about. Note whether it is already soulbound. Then /valuate wardrobenow and look at the item again.",
        expect = "The appearance is collected. Whether the item became soulbound is the thing to find out, and the answer decides whether this feature is safe to leave on.",
        broke = "CollectItemAppearance is an Ascension API with no documented binding behaviour, and an addon cannot see the difference until after the fact. The README says so rather than guessing. Do this once, deliberately, on something worthless - and if it does bind, that is worth knowing before it runs unattended on a bag full of quest rewards.",
    },
    {
        id = "adibagscan", since = "0.77.0a",
        title = "The scan button sits with AdiBags' own buttons and works",
        steps = "With AdiBags loaded, open your bags. Look along the top row of buttons for a teal V. Click it.",
        expect = "It is in line with AdiBags' own header buttons, not overlapping them or floating. Clicking rescans - best-in-slot markers update. Disabling the Valuate-AdiBags module makes the button disappear rather than leaving a dead one behind.",
        broke = "AddHeaderWidget is another addon's contract, and the ordering value is a guess about what else is already there. A widget that lands on top of AdiBags' search box would be obvious in the client and invisible to every gate here.",
    },
    {
        id = "press", since = "0.23.2a",
        title = "Buttons show a pressed state on a fast click",
        steps = "Open the UI, hover any button, then click it within about a fifth of a second.",
        expect = "It visibly darkens while the mouse button is held.",
        broke = "The hover fade overwrote the pressed colour on the very next frame, so quick clicks looked like they had not registered.",
    },
    {
        id = "minimap", since = "0.23.1a",
        gate = "tools/minimaptest.js",
        title = "The minimap pulse survives being interrupted by a drag",
        steps = "This command starts a pulse. Immediately drag the minimap button around and let go.",
        expect = "The button follows the cursor, and when the pulse ends no starburst is left behind and the button is back to its normal size.",
        broke = "The pulse and the drag handler shared the button's single OnUpdate slot, so the drag discarded the pulse's cleanup and left the glow stuck on at up to 1.14x scale.",
        arm = function()
            if not Valuate.PulseMinimapButton then
                return false, "PulseMinimapButton is missing - the minimap module did not load."
            end
            if Valuate:GetOptions().reduceMotion then
                return false, "Reduce Motion is on, so there is no pulse to interrupt. Turn it off in Settings first."
            end
            if Valuate:GetOptions().minimapButtonHidden then
                return false, "The minimap button is hidden. Enable it in Settings first."
            end
            Valuate:PulseMinimapButton()
            return true, "Pulse started - drag the button NOW."
        end,
    },
    {
        id = "wizard", since = "0.64.0a",
        gate = "tools/wizarduitest.js",
        title = "The scale wizard opens, previews, and creates a working scale",
        steps = "This command opens the wizard. Click 'Build it for me', read the preview, then 'Create it'.",
        expect = "Three screens. The preview names a scale starting 'Auto - ' with five stats and says what it matched; creating it leaves that scale selected, in the wizard's teal, with your gear rescanned. Closing the wizard at the preview must leave NO new scale behind.",
        broke = "Every screen is new. The headless gates cover the decisions and the click-through, but only the client proves the frames actually draw - and five contract bugs turned up writing that gate (a stagger helper called as a function, a tooltip helper given the wrong arguments, ToggleUI closing the main window, a button tint applied to the wrong object, and SetScript silently replacing the hover animation).",
        arm = function()
            if not Valuate.ShowScaleWizard then
                return false, "The wizard did not load - check for Lua errors on login."
            end
            Valuate:ShowScaleWizard()
            local before = 0
            for _ in pairs(Valuate:GetScales()) do before = before + 1 end
            return true, string.format(
                "Wizard open. You have %d scale(s) now - if you close it at the preview, " ..
                "that number must not change.", before)
        end,
    },
    {
        id = "buttonoptions", since = "0.60.2a",
        gate = "tools/minimaptest.js",
        title = "Changing the minimap button's position takes effect without a reload",
        steps = "This command moves the button to the opposite side of the minimap. Run it a second time to put it back.",
        expect = "The button jumps across the minimap the moment you run it - no /reload needed - and the second run returns it to exactly where it was.",
        broke = "The angle was only ever read when the button was created, and Show/Hide WRITE the option rather than applying it. So loading a settings snapshot or restoring defaults changed the setting while the button stayed put. The angle was not a declared option either, which meant the snapshot saved it, counted it in the total, and then silently dropped it on load - an alt got the default position while every other setting transferred.",
        arm = function()
            if not Valuate.ApplyMinimapButtonOptions then
                return false, "ApplyMinimapButtonOptions is missing - the minimap module did not load."
            end
            local options = Valuate:GetOptions()
            if options.minimapButtonHidden then
                return false, "The minimap button is hidden. Enable it in Settings first."
            end
            local before = options.minimapButtonAngle or 200
            options.minimapButtonAngle = (before + 180) % 360
            Valuate:ApplyMinimapButtonOptions()
            return true, string.format(
                "Moved the button from %d to %d degrees. Run this again to put it back.",
                before, options.minimapButtonAngle)
        end,
    },
    {
        id = "combat", since = "0.23.1a",
        title = "An upgrade found during combat is offered when you leave it",
        steps = "This command sets the deferred flag and runs the leave-combat path directly.",
        expect = "The bag-upgrade prompt appears, exactly as if you had just dropped out of combat.",
        broke = "The flag was declared 3,500 lines BELOW the handler that reads it, so that handler saw a nil global. Every in-combat upgrade was silently dropped. Nothing errored.",
        arm = function()
            local scale, scaleName = Valuate:GetPrimaryScale()
            if not scale then
                return false, "No active scale, so there is nothing to be an upgrade for."
            end
            if not Valuate:GetOptions().notifyBagUpgrade then
                return false, "The bag-upgrade prompt is turned off - enable it in Settings, or this proves nothing."
            end
            -- Say this UP FRONT. Arming a check that cannot possibly fire and letting
            -- the result read as a failure is worse than not offering the check.
            local count = Valuate.CountEquippableUpgrades
                and Valuate:CountEquippableUpgrades(scaleName) or 0
            if count == 0 then
                return false, "You have no equippable upgrade in your bags for '" .. scaleName ..
                    "', so nothing would appear even if this works. Put one in your bags first."
            end
            bagUpgradePending = true
            OnEvent(frame, "PLAYER_REGEN_ENABLED")
            return true, "Fired with " .. count .. " upgrade(s) waiting - the prompt should be on screen."
        end,
    },
    {
        id = "keybind", since = "0.49.0a",
        gate = "tools/settingstest.js",
        title = "The keybind button lets go of your keyboard",
        steps = "Settings > the Toggle UI keybind button. Left-click it so it says \"Press Key...\", then RIGHT-click to clear instead of pressing a key. Then do it again, and this time close the window while it is still waiting. Reopen Settings.",
        expect = "Both times the button goes back to its normal colour and stops saying \"Press Key...\". After reopening, typing does not bind anything, and chat still receives what you type.",
        broke = "Right-click cleared the binding but never ended the capture, and nothing ended it when the window closed. The button kept EnableKeyboard(true) - and 3.3.5 has no SetPropagateKeyboardInput, so a frame holding the keyboard CONSUMES what you type. Reopening Settings re-armed it, and the next key you pressed was silently bound.",
    },
    {
        id = "equipcount", since = "0.58.0a",
        title = "Equip All says how many slots it will change, and is right",
        steps = "Open Best Equipment with a few upgrades in your bags. Hover Equip All and read the list. Then click it and count what actually changed. Try it again immediately - hover it a second time.",
        expect = "The listed slots are the ones that change, and the count matches. Straight after equipping, the tooltip says there is nothing left to change.",
        broke = "New in this version. The tooltip predicts what EquipBestSet will do by mirroring its skip rules - locked slots, bank items, anything already worn, compared by item ID. Those are two separate pieces of code stating one rule, so the thing to catch is a count that does not match what happened.",
    },
    {
        id = "futureslot", since = "0.56.1a",
        title = "A slot's tooltip mentions what is waiting behind its best item",
        steps = "Open Best Equipment. Find a slot where you have a usable best item AND /valuate future lists something for that same slot. Hover the row.",
        expect = "After the score and the vs-Equipped line, a blue line naming the waiting item and the level it needs. On a slot with nothing waiting, no such line at all.",
        broke = "New in this version. The row can only draw one item and it draws the future one only when there is NO equippable best - which while levelling is the rare case, so anything waiting sat invisible behind what you already had. Watch for 'level 0': when nothing is blocking but the level, the line must not name one.",
    },
    {
        id = "futuremark", since = "0.56.0a",
        gate = "tools/arrowtest.js",
        title = "Future upgrades get a still blue marker, upgrades a pulsing green one",
        steps = "Open your bags with something you can equip that beats your current best, and something /valuate future lists. Look at both icons for a few seconds.",
        expect = "The wearable one has a green arrow that PULSES. The future one has a blue arrow that does not move at all. Two different colours, and only one of them is asking for attention.",
        broke = "New in this version. Watch for the blue one pulsing too - movement is the loudest thing a bag icon does and it belongs to the marker you can act on. If both move, you stop reading either.",
    },
    {
        id = "futureline", since = "0.55.0a",
        gate = "tools/futurelinetest.js",
        title = "A future upgrade says so on its tooltip",
        steps = "Find gear in your bags that needs a higher level than you have and would beat your best once wearable - /valuate future lists exactly these. Hover one. Then hover something that IS your best-in-slot, and something that is neither.",
        expect = "The future item gets a blue line naming the level and the scales. The best-in-slot item gets the gold star line instead - never both, since an item cannot be equippable and not equippable at once. The third gets neither.",
        broke = "New in this version. The addon has protected these items from auto-delete since future upgrades existed and never said why, so the thing to watch for is the line NOT appearing on an item /valuate future does list - that would mean the tooltip and the protection disagree about the same item.",
    },
    {
        id = "share", since = "0.48.0a",
        gate = "tools/sharetest.js",
        title = "A stat's weight box says what that weight is doing",
        steps = "Open the Scale Editor and hover the weight box of a stat you have a lot of, then one you have weighted but carry none of, then one with no weight at all. Now type a bigger number into the first and hover it again.",
        expect = "Three different answers - a percentage, \"you are carrying none of this stat\", and \"no weight set\". After typing, the percentage has MOVED: the ranking is recomputed per hover even though the equipped totals are cached for five seconds.",
        broke = "New in this version. Watch for every row claiming the same figure, which would mean the lookup is ignoring the stat name, and for a percentage that never changes as you type, which would mean the ranking got cached along with the totals.",
    },
    {
        id = "solidcolour", since = "0.46.0a",
        title = "Accent bars and separators actually draw",
        steps = "Open the UI and look at the thin coloured line across the top of each panel, the separators in the Scale Editor, and the coloured bar above each Best Equipment column. Then trigger an upgrade popup.",
        expect = "All of them are visible and tinted. If any are missing or the panel below one is half-built, this client does not have the modern texture call and the fallback is not working.",
        broke = "Twenty-two places filled a texture with SetColorTexture, which arrived in Legion - this addon targets Interface 30300, where the call is SetTexture(r, g, b, a). Whether it mattered depends on how much Ascension's client backported, which is not something I can check from here. It now asks the texture which method it has. This check is worth one look because it is the difference between 'we were fine' and 'a third of the UI was erroring at build time'.",
    },
    {
        id = "rows", since = "0.43.0a",
        gate = "tools/scalelisttest.js",
        title = "Scale rows still act on the scale they are showing",
        steps = "Make four scales. Delete the SECOND one, so the rows below it shift up. Now hover, tick, recolour, rename and finally delete the scale that moved into that second row.",
        expect = "Every one of those acts on the scale whose name you can read on that row. The confirmation names it too. Nothing is left highlighted after the list changes under your cursor.",
        broke = "New in this version. The rows are now reused rather than rebuilt, which fixed a permanent leak of about ten frames per scale per edit - but a reused row that remembered its old scale would delete the wrong one, and there is no undo. tools/scalelisttest.js proves the handlers follow; this is the half it cannot see.",
    },
    {
        id = "flash", since = "0.25.0a",
        title = "Best Equipment marks the slots a scan changed",
        steps = "Open the Best Equipment tab and leave it open. Put a clear upgrade for one slot in your bags, then run /valuate scan.",
        expect = "Exactly that slot's row lights up green briefly. Rows that did not change stay dark, and nothing lights up on the first visit to the tab.",
        broke = "New in this version - never run.",
    },
    {
        id = "junkline", since = "0.34.0a",
        title = "The tooltip says whether an item would be cleaned up",
        steps = "Turn on auto-sell or auto-delete, then hover a grey item, a green item that is best-in-slot, and a quest item that AdiBags calls junk.",
        expect = "Only junk items get the line. Anything protected reads \"Junk, but kept: <reason>\". With the features OFF, no line appears at all. Hover a grey in your BAG then a grey at a MERCHANT - the merchant one must not inherit the bag item verdict.",
        broke = "New in this version - never run. Watch for the line appearing MORE THAN ONCE on one tooltip: it is added from the per-frame refresh, so a broken guard means sixty copies a second.",
    },
    {
        id = "scanage", since = "0.38.2a",
        title = "Best Equipment says how old its data is",
        steps = "Log in and open Best Equipment BEFORE anything triggers a scan. Then press Scan Best Equipment and watch the label beside the button.",
        expect = "Before scanning it warns these are last session's results. After scanning it reads \"Scanned moments ago\", and it keeps up to date after BACKGROUND scans too - not only after pressing the button.",
        broke = "New in this version. Saved best-in-slot survives logout and was shown exactly like fresh data, so stale results looked authoritative.",
    },
    {
        id = "bankvisit", since = "0.38.1a",
        title = "Opening a bank says whether anything in it is an upgrade",
        steps = "Put an item better than what you are wearing into your bank, walk away, then come back and open it. Then move a few items in and out while it is open.",
        expect = "About a second and a half after opening, one message names how many banked items beat your gear. Moving items around must NOT print it again.",
        broke = "New in this version. The count already existed and the minimap tooltip showed it, but only if you went looking - never at the moment the item is an arm reach away.",
    },
    {
        id = "levelup", since = "0.38.0a",
        title = "Levelling tells you what it just made wearable",
        steps = "Carry an upgrade you are too low-level for (Best Equipment lists these as future upgrades), then gain the level that unlocks it.",
        expect = "About two seconds after dinging, a message names the item. Nothing appears if you had no future upgrades, or if the item is still gated by something a level does not fix.",
        broke = "New in this version. Levelling triggered no rescan under most autoScan settings, so gear could sit in your bags long after it became wearable - with the addon already knowing.",
    },
    {
        id = "firstrun", since = "0.37.1a",
        title = "A brand-new install explains itself",
        steps = "Hardest one to test - it needs a character that has never run Valuate. On an alt, or after clearing ValuateScales from SavedVariables, log in and watch chat about two seconds after the load line.",
        expect = "A Starter scale appears, and a message says its weights are crude and points at the From Template button. The scale list should show From Template as the WIDE button, with Blank beside it.",
        broke = "New in this version. The old default was called Default, said nothing about being a placeholder, and the 45 real templates were hidden behind a 20%-wide + button.",
    },
    {
        id = "altstart", since = "0.37.2a",
        title = "A new alt is told its scales are already saved",
        steps = "Save a scale to the library (/valuate library) on this character, then log in on an alt that has never run Valuate.",
        expect = "The first-run message lists the saved scales and points at /valuate library, INSTEAD of the template advice. With an empty library you get the template advice as before.",
        broke = "New in this version. The library and settings snapshot are account-wide precisely so an alt does not start from nothing, and the one moment that matters never mentioned them.",
    },
    {
        id = "scoreroll", since = "0.36.1a",
        title = "Best Equipment scores land on the CURRENT scan, not the previous one",
        steps = "Open Best Equipment and watch the numbers count up. Before they finish, switch to another tab and straight back. Also run /valuate scan while the tab is open.",
        expect = "Every score settles on the value for the latest scan. A row must never come to rest showing an older number.",
        broke = "The count-ups were unowned tweens capturing the score they started with, writing to a POOLED label. A re-reveal left the old run going, and it could finish last and win.",
    },
    {
        id = "statgrid", since = "0.33.0a",
        gate = "tools/statsearchtest.js",
        title = "The stat editor shows the right values after switching scales",
        steps = "Open Scales. Click between two scales with clearly different weights several times. Ban a stat on one, switch away, switch back. Then import or load a scale over the one you are editing and toggle a weapon set.",
        expect = "Every value, ban checkbox and weapon-set tick matches the scale you selected - no leftovers from the previous one, and no row stuck greyed out.",
        broke = "The grid is now built once and repopulated rather than rebuilt, which stopped it orphaning ~250 frames per click. If reuse missed anything, the symptom is a row showing the PREVIOUS scale - which matters, because you might then correct a value that was never wrong.",
    },
    {
        id = "search", since = "0.29.0a",
        gate = "tools/settingstest.js",
        title = "Settings search dims everything except what you typed",
        steps = "Open Settings and type 'junk' in the search box at the top. Then clear it, and press Escape with text in the box.",
        expect = "Only junk-related rows stay bright; everything else dims but STAYS PUT - nothing may move or reflow. The box shows a match count on the right. Clearing restores every row to full brightness, with none left dim.",
        broke = "New in this version - never run. It dims rather than hides precisely because every control anchors to the one above it, so hiding one would collapse the rest of the column. If anything moves, that is the bug.",
    },
    {
        id = "arrow", since = "0.27.0a",
        title = "Upgrade arrows pop in when they arrive - and only then",
        steps = "Open your bags with at least one upgrade already showing an arrow, then loot or buy another upgrade. Also close and reopen the bag, and drag items around.",
        expect = "A newly-arrived arrow pops out to full size. Arrows already on screen must NOT re-animate while you move things around.",
        broke = "New in this version - never run. The risk here is the opposite of the feature: the arrow update runs for every button on every bag repaint, so getting this wrong means every arrow jitters constantly.",
    },
    {
        id = "resize", since = "0.24.0a",
        title = "The window resizes smoothly instead of snapping",
        steps = "Open the UI and switch between the Scales, Best Equipment and Settings tabs.",
        expect = "The window eases between heights. It must never overshoot and spring back, which would mean something is still setting the height directly.",
        broke = "New in this version - never run.",
    },
    {
        id = "charsheet", since = "0.23.2a",
        gate = "tools/charwindowtest.js",
        title = "The character sheet score appears even on a slow load",
        steps = "Fully log out and back in (not /reload), then open your character sheet.",
        expect = "The Valuate score is there.",
        broke = "The fallback that waits for a slow character UI cleared its own timer after ONE attempt, so if the UI was not ready one second in it gave up permanently.",
    },
}

local function PrintVerifyCheck(c, index)
    print(string.format("|cFF00FF00%d. %s|r |cFFAAAAAA(since v%s)|r", index, c.title, c.since))
    print("   |cFFFFFF00Do:|r " .. c.steps)
    print("   |cFF88FF88Expect:|r " .. c.expect)
    print("   |cFFAAAAAAWhy:|r " .. c.broke)
    if c.gate then
        -- Says what is already proven, so this is a smaller ask than the ones with no
        -- gate behind them. The build runs that file on every commit; what it cannot do
        -- is look at the screen.
        print("   |cFF66CCFFAlready proven:|r " .. c.gate ..
              " runs this logic. |cFFAAAAAAYou are checking it LOOKS right.|r")
    end
end

-- Marks a check done (or not), remembering WHICH VERSION it was checked at.
--
-- The version matters. A tick that just says "done" goes stale silently the moment the
-- behaviour changes underneath it - which is the failure mode this entire checklist
-- exists to catch, so it would be a poor thing to build into the checklist itself.
-- Storing the version means a check verified at v0.30.0a against a behaviour reworked
-- in v0.33.0a can say so rather than looking finished.
local function SetVerified(id, done)
    local opts = Valuate:GetOptions()
    opts.verifiedChecks = opts.verifiedChecks or {}
    opts.verifiedChecks[id] = done and (Valuate.version or "?") or nil
end

-- true when version string `a` is older than `b`.
--
-- Compared NUMERICALLY, component by component, not as strings: "0.9.0a" < "0.10.0a" is
-- true as versions and false as text, because "9" sorts after "1". Nothing in this
-- project can hit that today - every version in play has a two-digit minor - but a
-- comparison that is wrong only for inputs which "cannot happen" is a trap left for
-- later, and this one costs six lines to do properly.
local function VersionOlder(a, b)
    if not a or not b then return false end
    local ai, bi = string.gmatch(a, "%d+"), string.gmatch(b, "%d+")
    for _ = 1, 3 do
        local x, y = tonumber(ai() or 0), tonumber(bi() or 0)
        if x ~= y then return x < y end
    end
    return false
end

-- The STATE, separate from how it is drawn.
--
-- Returns: verifiedAtVersion (nil if unchecked), isStale.
--
-- Split out because the summary line used to count progress by pattern-matching the
-- formatted label - searching it for "[x]" and "STALE". That works right up until the
-- marker or the wording changes, at which point the count silently becomes "0 of 16
-- checked" and looks entirely authoritative. Deriving data from presentation is the
-- same silent-wrongness this checklist exists to catch, so it had no business being
-- inside the checklist.
local function VerifiedState(c)
    local opts = Valuate:GetOptions()
    local at = opts.verifiedChecks and opts.verifiedChecks[c.id]
    if not at then return nil, false end
    -- `since` is the version the check was introduced or last revised at. Newer than
    -- when you ticked it means what you verified is not what ships now.
    local stale = (c.since and at ~= "?" and VersionOlder(at, c.since)) and true or false
    return at, stale
end

-- The first check still wanting attention, in list order, plus how many do.
--
-- STALE COUNTS AS PENDING. A tick recorded at v0.30.0a against behaviour reworked in
-- v0.33.0a is not evidence about what ships; treating it as finished is how a checklist
-- ends up reporting "16 of 16" while testing nothing. The list has always drawn the
-- distinction - this makes the walkthrough act on it.
-- UNGATED checks come first.
--
-- A check whose logic is already executed by a build gate is a smaller thing to confirm:
-- the behaviour is proven, and what remains is whether it looks right. A check with no gate
-- behind it is the only evidence that will ever exist for that behaviour.
--
-- Twenty-one checks is a long sitting and it may not be finished in one. If it stops
-- half-way, the half that got done should be the half nothing else covers - so `next` hands
-- those out first. Within each group the list order is preserved, so it stays predictable.
local function NextPendingCheck()
    local first, firstIndex, pending = nil, nil, 0
    local fallback, fallbackIndex = nil, nil
    for i, c in ipairs(VERIFY_CHECKS) do
        local at, stale = VerifiedState(c)
        if (not at) or stale then
            pending = pending + 1
            if c.gate then
                if not fallback then fallback, fallbackIndex = c, i end
            else
                if not first then first, firstIndex = c, i end
            end
        end
    end
    if first then return first, firstIndex, pending end
    return fallback, fallbackIndex, pending
end

-- "[x] v0.33.0a" / "[x] v0.30.0a - STALE, changed in v0.33.0a" / "[ ]"
local function VerifiedLabel(c)
    local at, stale = VerifiedState(c)
    if not at then return "|cFF888888[ ]|r" end
    if stale then
        return "|cFFFF8800[x] " .. at .. " - STALE, changed in v" .. c.since .. "|r"
    end
    return "|cFF00FF00[x] " .. at .. "|r"
end


function Valuate:RunVerify(which)
    which = which and strtrim(which) or ""

    -- /valuate verify done <id> | undo <id> | reset
    local verb, target = strmatch(which, "^(%a+)%s+(.+)$")
    if not verb then verb = strmatch(which, "^(%a+)$") end

    if verb == "reset" then
        Valuate:GetOptions().verifiedChecks = {}
        print("|cFF00FF00[Valuate]|r Cleared every verification tick.")
        return true
    end

    -- /valuate verify next - hand out the next one and set it up.
    --
    -- The whole list is sixteen checks that each need a client, a character and a bag of
    -- gear, so it gets run in one long sitting or not at all. Making that sitting a loop
    -- (next, do it, done, next) rather than a lookup is the difference between a
    -- checklist you work through and one you read.
    if verb == "next" and not target then
        local c, index, pending = NextPendingCheck()
        if not c then
            print(string.format("|cFF00FF00[Valuate]|r All %d behavioural checks are ticked at the current version.",
                #VERIFY_CHECKS))
            print("|cFFAAAAAAThey un-tick themselves when the behaviour they cover changes, so this is worth re-running after an update.|r")
            return true
        end
        local at, stale = VerifiedState(c)
        print(string.format("|cFF00FF00[Valuate]|r %d left to check.", pending))
        if stale then
            print(string.format("|cFFFF8800Re-check:|r you ticked this at v%s, but it changed in v%s.", at, c.since))
        end
        PrintVerifyCheck(c, index)
        if c.arm then
            local ok, message = c.arm()
            print(ok and ("   |cFF00FF00Armed:|r " .. message)
                     or ("   |cFFFF8800Cannot arm:|r " .. message))
        else
            print("   |cFFAAAAAAThis one cannot be armed - it needs you to do it.|r")
        end
        print("   |cFFAAAAAAThen: /valuate verify done " .. c.id .. "|r")
        return true
    end

    if (verb == "done" or verb == "undo") and target then
        for _, c in ipairs(VERIFY_CHECKS) do
            if c.id == target then
                SetVerified(c.id, verb == "done")
                print(string.format("|cFF00FF00[Valuate]|r %s: %s",
                    c.id, verb == "done"
                        and ("checked at v" .. (Valuate.version or "?"))
                        or "unchecked"))
                -- Point at the next one, but do NOT arm it. Arming has side effects - it
                -- starts a pulse, it fires a combat-exit - and firing one the moment you
                -- ticked something else means it goes off while you are not watching,
                -- which is a check wasted rather than a check run.
                local nxt, _, pending = NextPendingCheck()
                if nxt then
                    print(string.format("|cFFAAAAAA%d left. Next: /valuate verify next  (%s)|r",
                        pending, nxt.id))
                elseif verb == "done" then
                    print("|cFF00FF00That was the last one - every behavioural check is ticked at this version.|r")
                end
                return true
            end
        end
        print("|cFFFF0000[Valuate]|r No such check: " .. target)
        return true
    end

    if which and which ~= "" then
        for i, c in ipairs(VERIFY_CHECKS) do
            if c.id == which then
                print("|cFF00FF00[Valuate]|r Behavioural check: " .. c.id)
                PrintVerifyCheck(c, i)
                if c.arm then
                    local ok, message = c.arm()
                    print(ok and ("   |cFF00FF00Armed:|r " .. message)
                             or ("   |cFFFF8800Cannot arm:|r " .. message))
                else
                    print("   |cFFAAAAAAThis one cannot be armed - it needs you to do it.|r")
                end
                print("   |cFFAAAAAAWhen it passes: /valuate verify done " .. c.id .. "|r")
                return true
            end
        end
        print("|cFFFF0000[Valuate]|r No such check: " .. which)
    end

    print("|cFF00FF00[Valuate]|r Behavioural checks - the things no gate can answer")
    print("|cFFAAAAAAEverything here fails SILENTLY when it fails. Run /valuate verify next|r")
    print("|cFFAAAAAAto be handed the next one, set up and ready; or name one to jump to it.|r")
    print(" ")

    -- Counted from the STATE, never from the rendered label. Reformatting the list must
    -- not be able to change the tally.
    local done, stale, gated = 0, 0, 0
    for i, c in ipairs(VERIFY_CHECKS) do
        local at, isStale = VerifiedState(c)
        if at then
            done = done + 1
            if isStale then stale = stale + 1 end
        end
        if c.gate then gated = gated + 1 end
        print(string.format("%s |cFF00FF00%d. %s|r%s  -  /valuate verify %s",
            VerifiedLabel(c), i, c.title,
            c.gate and " |cFF66CCFF(logic gated)|r" or "", c.id))
    end

    print(" ")
    print(string.format("|cFFAAAAAA%d of %d checked%s. Work through them with /valuate verify next, " ..
        "tick one with /valuate verify done <name>, or start over with /valuate verify reset.|r",
        done, #VERIFY_CHECKS,
        stale > 0 and (", " .. stale .. " now STALE - those come round again") or ""))
    -- The honest shape of the remaining work: how much of this is confirming something
    -- already proven, and how much is the only evidence that will ever exist.
    print(string.format("|cFFAAAAAA%d have their logic run by a build gate, so those are " ..
        "'does it look right'. The other %d are the real unknowns - /valuate verify next " ..
        "hands you those first.|r", gated, #VERIFY_CHECKS - gated))
    print("|cFFAAAAAA/valuate check covers the other half: is the addon loaded and configured.|r")
    return true
end

-- Slash command handler (basic)
SLASH_VALUATE1 = "/valuate"
SLASH_VALUATE2 = "/val"
SlashCmdList["VALUATE"] = function(msg)
    local command = strlower(strtrim(msg))
    
    -- Default behavior: open UI (unless help is explicitly requested)
    if command == "" then
        if Valuate.ToggleUI then
            Valuate:ToggleUI()
        else
            print("|cFFFF0000Valuate|r: UI not loaded. Please reload UI with /reload")
        end
        return
    end
    
    if command == "help" then
        print("|cFF00FF00Valuate|r - Stat Weight Calculator")
        print("Commands:")
        print("  /valuate or /val - Open the configuration UI")
        print("  /valuate help - Show this help")
        print("  /valuate version - Show version info")
        print("  /valuate scan - Scan bags/equipped now for best-in-slot items")
        print("  /valuate report - Gear status: upgrades waiting, weapon sets, bag space, automation")
        print("  /valuate selftest - Check the addon's own plumbing and integrations")
        print("  /valuate quest - Toggle auto-choosing the best quest reward")
        print("  /valuate turnin - Toggle auto-completing quests (takes best reward)")
        print("  /valuate test [itemlink] - Test parsing an item (shift-click item to link)")
        print("  /valuate debug - Toggle debug mode (shows tooltip text being parsed)")
        print("  |cFF3FE0C8/valuate wizard|r - Build an optimized scale from the gear you are wearing")
        print("  /valuate wardrobe - List bag appearances you have not collected yet")
        print("  /valuate wardrobenow - Collect those appearances now (may bind the items)")
        print("  /valuate autowardrobe - Toggle collecting new appearances automatically")
        print("  /valuate scales - List all stat weight scales")
        print("  /valuate bank - Show the bank snapshot used for best-in-slot")
        print("  /valuate equip - Equip the best set for the active scale")
        print("  /valuate junkinterval <secs> - How often junk cleanup runs on its own (0 = off)")
        print("  /valuate profile - Measure scan, scoring and tooltip-parse timings")
        print("  /valuate weights [scale] - Which of your stat weights actually matter")
        print("  /valuate future - Gear waiting on a level, and which level")
        print("  /valuate junkmarks - Why surplus gear is (or is not) being marked junk")
        print("  /valuate check - Is Valuate actually working? Start here")
        print("  /valuate verify [done|undo|reset] - Behavioural checks a human has to look at")
        print("  /valuate errors - Anything that errored this session (empty is expected)")
        print("  /valuate why [itemlink] - Explain what Valuate thinks of an item (roll, arrow, junk)")
        print("  /valuate library - Scales shared across all your characters (save/load/delete)")
        print("  /valuate settings save|load - Copy your settings to your other characters")
        print("  /valuate import - Import a scale from a scale tag")
        print("  /valuate export [scalename] - Export a scale as a scale tag")
        print("  /valuate ui - Open the configuration UI")
        -- Automation and cleanup.
        --
        -- These were missing from this list entirely, which mattered more than the others:
        -- every command that DELETES or SELLS lives here, and so does deletepreview, the one
        -- the addon tells you to run before switching deletion on. Someone reading
        -- /valuate help could not find out that any of it existed.
        print(" ")
        print("|cFFAAAAAAAutomation (all off by default):|r")
        print("  /valuate roll - Toggle auto Need/Greed on group loot rolls")
        print("  /valuate accept - Toggle auto-accepting quests")
        print("  /valuate notify - Toggle the prompt when an upgrade lands in your bags")
        print("  /valuate notifycheck - Explain why the upgrade prompt did or did not appear")
        print(" ")
        print("|cFFAAAAAABags and merchants:|r")
        print("  |cFFFF8800/valuate deletepreview - What auto-delete WOULD remove. Run this first.|r")
        print("  /valuate autodelete - Toggle junk auto-delete (|cFFFF5555irreversible|r)")
        print("  /valuate deletenow - Delete junk now, honouring Keep Free Slots")
        print("  /valuate keepfree <n> - Bag slots auto-delete tries to keep free")
        print("  /valuate valuesource <src> - What \"least valuable\" means: vendor price, or a TSM source")
        print("  /valuate sell - Toggle selling junk at merchants (safer: gold, plus Buyback)")
        print("  /valuate sellnow - Sell junk now")
        print("  /valuate repair - Toggle auto-repair on visiting a merchant")
    elseif command == "version" then
        print("|cFF00FF00Valuate|r version " .. Valuate.version .. " (Interface " .. Valuate.interface .. ")")
    elseif command == "report" then
        Valuate:PrintReport()
    elseif command == "check" then
        -- One command to answer "is this actually working?".
        --
        -- Not a wrapper around the other four: it triages. selftest proves the build
        -- loaded, but a fully-loaded addon can still be doing nothing useful - no
        -- scan has run, no scale is active, every feature is off. Those are the
        -- states that read as "broken" to someone who just installed it, and none of
        -- them is an error.
        print("|cFF00FF00[Valuate]|r Health check")
        local problems = {}

        local passed = Valuate:RunSelfTest()
        if not passed then
            problems[#problems + 1] = "the self-test failed - see the FAIL lines above"
        end

        local errs = Valuate:GetEventErrors()
        if #errs > 0 then
            problems[#problems + 1] = #errs .. " event(s) errored - /valuate errors"
        end

        local activeScales = Valuate:GetActiveScales()
        if #activeScales == 0 then
            problems[#problems + 1] =
                "no active scale - nothing can be scored until you tick one, or run " ..
                "/valuate wizard to build one from the gear you are wearing"
        end

        -- An ACTIVE scale with no weights scores everything 0, and looks completely
        -- normal doing it: a column of zeros in Best Equipment and 0.0 in every
        -- tooltip, with nothing saying why.
        --
        -- GetActiveScales only requires a Values TABLE, and an empty one is truthy - so
        -- this is exactly what the "Blank" button produces until you fill it in. The
        -- existing check below only fires when NO scale found anything, so one good
        -- scale alongside one empty scale went unreported.
        do
            local scales = Valuate:GetScales()
            local empty = {}
            for _, name in ipairs(activeScales) do
                local scale = scales[name]
                local hasWeight = false
                if scale and scale.Values then
                    for _, v in pairs(scale.Values) do
                        if type(v) == "number" and v ~= 0 then hasWeight = true break end
                    end
                end
                if not hasWeight then empty[#empty + 1] = scale and (scale.DisplayName or name) or name end
            end
            if #empty > 0 then
                -- activeScales is sorted, so this inherits a stable order.
                -- Points at the wizard rather than at the stat editor. "Open it and set
                -- some" assumes you know what your weights should be, which is the exact
                -- thing someone in this state does not know - it is why the scale is empty.
                problems[#problems + 1] = "active but has no stat weights, so it scores everything 0: "
                    .. table.concat(empty, ", ")
                    .. " - run /valuate wizard to build one from your gear, or untick it"
            end
        end

        local scanAgo = Valuate:GetAutomationHeartbeat("scan")
        if not scanAgo then
            problems[#problems + 1] = "no gear scan has run yet - try /valuate scan"
        end

        local be = Valuate:GetBestEquipment()
        local haveBest = false
        for _, name in ipairs(activeScales) do
            local entry = be[name]
            if type(entry) == "table" then
                for slotId = 1, 18 do
                    if entry[slotId] then haveBest = true break end
                end
            end
            if haveBest then break end
        end
        if #activeScales > 0 and scanAgo and not haveBest then
            problems[#problems + 1] = "a scan ran but found no best-in-slot gear - check your scale has stat weights"
        end

        if #problems == 0 then
            print("  |cFF00FF00Everything looks healthy.|r")
            print("  |cFFAAAAAA/valuate report for what's armed, /valuate profile for timings.|r")
        else
            print(string.format("  |cFFFF8800%d thing(s) worth looking at:|r", #problems))
            for _, p in ipairs(problems) do print("   - " .. p) end
        end
    elseif strsub(command, 1, 6) == "verify" then
        Valuate:RunVerify(strtrim(strsub(command, 7)))
    elseif command == "wardrobe" then
        -- The preview. Deliberately the SHORT name, because it is the one to reach for
        -- first; the command that acts has to be typed deliberately.
        local pending, why = Valuate:GetUncollectedAppearances()
        if not pending then
            print("|cFFFF8800Valuate|r: " .. tostring(why))
        elseif #pending == 0 then
            print("|cFF00FF00Valuate|r: every appearance in your bags is already collected.")
        else
            print(string.format("|cFF00FF00Valuate|r: %d uncollected appearance(s) in your bags:",
                #pending))
            for _, entry in ipairs(pending) do
                print("   " .. tostring(entry.link))
            end
            print("|cFFAAAAAACollecting may BIND these items - that is not something I can " ..
                "verify on this server. Run|r /valuate wardrobenow |cFFAAAAAAto collect them.|r")
        end
    elseif command == "wardrobenow" then
        local collected, why = Valuate:LearnUncollectedAppearances()
        if collected > 0 then
            print(string.format("|cFF00FF00Valuate|r: collected %d new appearance(s).", collected))
        else
            print("|cFFFF8800Valuate|r: " .. tostring(why or "nothing to collect"))
        end
    elseif command == "autowardrobe" then
        local options = Valuate:GetOptions()
        options.autoLearnAppearances = not options.autoLearnAppearances
        if options.autoLearnAppearances then
            print("|cFF00FF00Valuate|r: auto-collect wardrobe appearances |cFF00FF00ON|r. " ..
                "Run /valuate wardrobe first if you have not seen what it would take.")
        else
            print("|cFF00FF00Valuate|r: auto-collect wardrobe appearances |cFFFF8800OFF|r.")
        end
    elseif command == "wizard" then
        -- The guided scale builder. Lives in ui/Wizard.lua, so it is absent if the UI
        -- modules failed to load - which is worth saying rather than doing nothing.
        if Valuate.ShowScaleWizard then
            Valuate:ShowScaleWizard()
        else
            print("|cFFFF0000[Valuate]|r The wizard did not load. Check for Lua errors on login.")
        end
    elseif command == "selftest" then
        Valuate:RunSelfTest()
    elseif command == "pulse" then
        -- Preview the minimap upgrade-pulse animation.
        if Valuate.PulseMinimapButton then Valuate:PulseMinimapButton() end
    elseif strsub(command, 1, 3) == "why" or strsub(command, 1, 9) == "rollcheck" then
        -- "why" is the honest name now that this explains arrows and junk as well as
        -- rolls; "rollcheck" stays because it is already documented and in muscle
        -- memory. Both take the item link at the same offset, since "why " and
        -- "rollcheck " differ in length - normalise before parsing.
        if strsub(command, 1, 3) == "why" then
            command = "rollcheck " .. strtrim(strsub(command, 5) or "")
        end
        -- Explains, step by step, what auto-roll would decide for an item and why.
        -- Written because "it greeded on a recipe I can learn" has several possible
        -- causes that look identical from outside: the profession list couldn't be
        -- read, the recipe belongs to an alt's profession, it's already known, or
        -- Need simply wasn't offered by the client.
        local itemLink = strsub(command, 11)
        if not itemLink or itemLink == "" then
            print("|cFFFF0000Valuate|r: Usage: /valuate rollcheck [itemlink]")
            print("  Shift-click an item in chat to get its link, then paste after 'rollcheck'")
        else
            local options = Valuate:GetOptions()
            local name, _, _, _, _, itemType, itemSubType = GetItemInfo(itemLink)
            print("|cFF00FF00[Valuate]|r Roll check: " .. (name or itemLink))
            if not itemType then
                print("  |cFFFF8800Item not cached yet|r - hover it once, then try again.")
            else
                print(string.format("  Type: |cFFFFFFFF%s|r / |cFFFFFFFF%s|r",
                    itemType, itemSubType or "?"))

                local _, detected = Valuate:GetProfessionOverrideChoices()
                local profs = {}
                for p in pairs(GetKnownProfessions()) do
                    -- Mark which came from the skill list and which you added by
                    -- hand, so a wrong answer points at the right place to fix it.
                    profs[#profs + 1] = detected[p] and p or (p .. " (manual)")
                end
                table.sort(profs)
                if #profs > 0 then
                    print("  Your professions: |cFFFFFFFF" .. table.concat(profs, ", ") .. "|r")
                else
                    print("  |cFFFF8800No professions detected|r - open your skills window once, or tick them under Settings > Professions. Until then no recipe or material can roll Need.")
                end

                if itemType == "Recipe" then
                    if not options.autoRollLoot then
                        print("  |cFFFF8800Auto Roll Loot is off|r - nothing is rolled automatically.")
                    elseif options.autoRollRecipes == false then
                        print("  |cFFFF8800'Need Unlearned Recipes' is off.|r")
                    else
                        local learnable, _, blockReason =
                            Valuate:IsLearnableRecipe(itemLink, "SetHyperlink", itemLink)
                        if learnable then
                            print("  |cFF00FF00Would roll Need|r - unlearned recipe for a profession you have.")
                            print("  |cFFAAAAAA(A skill requirement you don't meet yet is fine - it Needs anyway.)|r")
                            print("  |cFFAAAAAAIf it still Greeds, the CLIENT didn't offer Need - it withholds Need for items you can't use yet, and no addon can override that. Greed is the fallback so the item isn't lost.|r")
                        else
                            print("  |cFFFF8800Would NOT Need|r - " .. (blockReason or "unknown reason") .. ".")
                            if blockReason and blockReason:find("don't have") then
                                print("  |cFFAAAAAANote: a tooltip line like \"could be learned by: <name>\" lists your OTHER characters too.|r")
                            end
                        end
                    end
                elseif itemType == "Trade Goods" then
                    local useful, prof = Valuate:IsUsefulTradeGood(itemLink)
                    if useful then
                        print(string.format("  |cFF00FF00Would roll Need|r - material used by %s.", prof))
                    else
                        print("  |cFFFF8800Would NOT Need|r - no profession of yours uses this subtype (or it's an unmapped one).")
                    end
                else
                    print("  Not a recipe or trade good; only gear upgrades roll Need.")
                end

                -- Upgrade arrows were the one automated decision with no way to ask
                -- "why not?" - and since they became spec-only and cached, there are
                -- several answers that look identical from the outside.
                print("  |cFFAAAAAA-- upgrade arrow --|r")
                if not options.showUpgradeArrows then
                    print("  |cFFFF8800Arrows are off|r in Settings.")
                else
                    local _, primaryName = Valuate:GetPrimaryScale()
                    if not primaryName then
                        print("  |cFFFF8800No active scale|r, so nothing can be an upgrade.")
                    else
                        local isUp, delta = Valuate:IsItemLinkUpgrade(itemLink)
                        if isUp then
                            print(string.format("  |cFF00FF00Arrow shown|r - +%.1f for %s.",
                                delta or 0, primaryName))
                        else
                            print(string.format("  |cFFFF8800No arrow|r - not an upgrade for %s (your current spec).",
                                primaryName))
                            print("  |cFFAAAAAAArrows follow the CURRENT spec only; it may still be an upgrade for another scale.|r")
                        end
                    end
                end

                -- The addon's core output finally gets its own diagnostic. "Why isn't this
                -- my best?" had no answer anywhere - not in the tooltip, not here.
                print("  |cFFAAAAAA-- best-in-slot --|r")
                local bisStats = Valuate:GetStatsForItemLink(itemLink)
                local bis = bisStats and Valuate:ExplainBestInSlot(itemLink, bisStats)
                if not bisStats then
                    print("  |cFFFF8800Could not read its stats|r - hover the item once, then try again.")
                elseif not bis then
                    print("  |cFFAAAAAANot equippable gear, so there is no slot for it to win.|r")
                else
                    for _, e in ipairs(bis) do
                        if e.verdict == "best" then
                            print(string.format("  |cFF00FF00BEST|r for |cFFFFFFFF%s|r (%.1f).",
                                e.scaleName, e.score))
                        elseif e.verdict == "beaten" then
                            print(string.format("  |cFFFF8800Beaten|r for |cFFFFFFFF%s|r: %.1f vs %.1f, short by |cFFFF8800%.1f|r.",
                                e.scaleName, e.score, e.bestScore, e.gap))
                            if e.bestLink then
                                print("      beaten by " .. e.bestLink)
                            end
                        elseif e.verdict == "unscanned" then
                            print(string.format("  |cFF00FF00Would win|r for |cFFFFFFFF%s|r by %.1f - but the scan has not run since it arrived. |cFFAAAAAA/valuate scan|r",
                                e.scaleName, e.gap))
                        elseif e.verdict == "unscored" then
                            print(string.format("  |cFFFF8800Scores nothing|r for |cFFFFFFFF%s|r - none of its stats are weighted, so it can never win.",
                                e.scaleName))
                        else
                            print(string.format("  |cFFFF8800%s has no weights|r, so nothing can be best for it.",
                                e.scaleName))
                        end
                    end
                    print("  |cFFAAAAAAThis is about POINTS, not whether you can wear it - see the arrow line above for that.|r")
                end

                -- And whether the bag integrations would act on it.
                if Valuate.IsItemJunk then
                    local id = GetItemIdFromLink(itemLink)
                    if id and Valuate:IsItemJunk(id) then
                        print("  |cFFFF8800Classed as JUNK|r - auto-sell and auto-delete can act on it.")
                    end
                end
            end
        end
    elseif strsub(command, 1, 4) == "test" then
        local itemLink = strsub(command, 6)
        if itemLink and itemLink ~= "" then
            -- Temporarily enable debug for test command
            local options = Valuate:GetOptions()
            local oldDebug = options.debug
            options.debug = true
            local stats = Valuate:GetStatsForItemLink(itemLink)
            options.debug = oldDebug
            if stats then
                print("|cFF00FF00Valuate|r: Parsed stats for item (base values, not scaled):")
                for statName, value in pairs(stats) do
                    local displayName = ValuateStatNames[statName] or statName
                    print("  " .. displayName .. ": " .. value)
                end
                print("|cFFFFFF00Note:|r Scaled values are read live when you hover the item's tooltip.")
            else
                print("|cFFFF0000Valuate|r: Failed to parse stats for item.")
            end
        else
            print("|cFFFF0000Valuate|r: Usage: /valuate test [itemlink]")
            print("  Shift-click an item in chat to get its link, then paste after 'test'")
        end
    elseif command == "debug" then
        local options = Valuate:GetOptions()
        options.debug = not options.debug
        print("|cFF00FF00Valuate|r: Debug mode " .. (options.debug and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif command == "scan" then
        if Valuate.ScanBestEquipment then
            if Valuate:ScanBestEquipment() then
                print("|cFF00FF00Valuate|r: Best equipment scan complete.")
            else
                print("|cFFFF8800Valuate|r: Items are still settling from an equipment change - try again in a few seconds.")
            end
        else
            print("|cFFFF0000Valuate|r: Scan unavailable. Please /reload.")
        end
    elseif command == "roll" then
        local options = Valuate:GetOptions()
        options.autoRollLoot = not options.autoRollLoot
        print("|cFF00FF00Valuate|r: Auto roll on loot " .. (options.autoRollLoot and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        if options.autoRollLoot and Valuate:IsPassLootRollingToo() then
            print("  |cFFFF8800PassLoot is also rolling|r - it has a Valuate rule loaded, so two addons")
            print("  will act on the same roll and can disagree. Turn off one of them.")
        end
        if options.autoRollLoot then
            local wantsRecipes = options.autoRollRecipes ~= false
            local wantsMats = options.autoRollTradeGoods ~= false
            if wantsRecipes or wantsMats then
                -- Report the professions we can see. An empty list is the one silent
                -- failure mode here: no professions detected means neither of these
                -- will ever roll Need, and nothing else would tell you that.
                local names = {}
                for prof in pairs(GetKnownProfessions()) do names[#names + 1] = prof end
                table.sort(names)
                if #names > 0 then
                    local what = {}
                    if wantsRecipes then what[#what + 1] = "unlearned recipes" end
                    if wantsMats then what[#what + 1] = "crafting materials" end
                    print("  Will Need " .. table.concat(what, " and ")
                        .. " for: |cFFFFFFFF" .. table.concat(names, ", ") .. "|r")
                else
                    print("  |cFFFF8800No professions detected|r - neither recipes nor materials will roll Need.")
                    print("  Open your skills window once, or tick them under Settings > Professions.")
                end
            end
        end
    elseif command == "notify" then
        local options = Valuate:GetOptions()
        options.notifyBagUpgrade = not options.notifyBagUpgrade
        print("|cFF00FF00Valuate|r: Bag-upgrade popup " .. (options.notifyBagUpgrade and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif command == "notifycheck" then
        -- Diagnose the bag-upgrade prompt: scan, then report every gate and show the
        -- prompt if there is anything to equip.
        if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
        Valuate:CheckBagUpgradeNotify("loot", true)
    elseif command == "sell" then
        local options = Valuate:GetOptions()
        options.autoSellJunk = not options.autoSellJunk
        print("|cFF00FF00Valuate|r: Auto sell junk at merchants " .. (options.autoSellJunk and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif command == "sellnow" then
        Valuate:AutoSellJunk(true)
    elseif command == "repair" then
        local options = Valuate:GetOptions()
        options.autoRepair = not options.autoRepair
        print("|cFF00FF00Valuate|r: Auto repair " .. (options.autoRepair and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif command == "autodelete" then
        local options = Valuate:GetOptions()
        options.autoDeleteJunk = not options.autoDeleteJunk
        print("|cFF00FF00Valuate|r: Auto delete junk " .. (options.autoDeleteJunk and "|cFFFF5555ENABLED|r - deletions are permanent" or "|cFF00FF00disabled|r"))
        if options.autoDeleteJunk then
            local iv = tonumber(options.autoDeleteIntervalSecs) or 0
            print("  Runs on loot/bag events" .. (iv > 0 and (", and every " .. iv .. "s") or " only - /valuate junkinterval <secs> to also run on a timer")
                .. ". Only ever deletes while free slots are under " .. tostring(options.autoDeleteKeepFree or 0) .. ".")
        end
    elseif command:match("^valuesource") then
        -- /valuate valuesource <vendor|TSM price source>
        local options = Valuate:GetOptions()
        local src = strtrim(command:match("^valuesource%s+(.+)$") or "")
        if src ~= "" then
            options.autoDeleteValueSource = src
            print("|cFF00FF00Valuate|r: Value source set to '" .. src .. "'. Run /valuate deletepreview to confirm it resolves.")
        else
            print("|cFF00FF00Valuate|r: Value source is '" .. (options.autoDeleteValueSource or "vendor")
                .. "'. Usage: /valuate valuesource <vendor|DBMarket|...>")
        end
    elseif command:match("^junkinterval") then
        -- /valuate junkinterval <secs> - how often cleanup runs on its own (0 = off)
        local options = Valuate:GetOptions()
        local n = tonumber(command:match("^junkinterval%s+(%d+)$"))
        if n then
            n = math.max(0, math.min(3600, n))
            options.autoDeleteIntervalSecs = n
            if n == 0 then
                print("|cFF00FF00Valuate|r: Periodic junk cleanup OFF - it will only run on loot and bag events.")
            else
                print("|cFF00FF00Valuate|r: Junk cleanup will also run every " .. n .. "s.")
            end
        else
            local cur = tonumber(options.autoDeleteIntervalSecs) or 0
            print("|cFF00FF00Valuate|r: Periodic junk cleanup is "
                .. (cur > 0 and ("every " .. cur .. "s") or "OFF")
                .. ". Usage: /valuate junkinterval <seconds, 0 to disable>")
        end
    elseif command:match("^keepfree") then
        -- /valuate keepfree <n> - how many bag slots auto-delete keeps free
        local options = Valuate:GetOptions()
        local n = tonumber(command:match("^keepfree%s+(%d+)$"))
        if n then
            n = math.max(0, math.min(60, n))
            options.autoDeleteKeepFree = n
            print("|cFF00FF00Valuate|r: Auto delete will keep |cFFFFD700" .. n .. "|r bag slot(s) free.")
        else
            print("|cFF00FF00Valuate|r: Keeping |cFFFFD700" .. (options.autoDeleteKeepFree or 4)
                .. "|r bag slot(s) free. Usage: /valuate keepfree <number>")
        end
    elseif command == "deletepreview" then
        -- Always runs, regardless of free space or whether auto-delete is enabled,
        -- and deletes nothing. Reports the ranked queue plus why items were skipped.
        Valuate:AutoDeleteJunk({ preview = true, limit = 15 })
    elseif command == "deletenow" then
        -- On-demand: delete ALL eligible junk right now, regardless of the enable
        -- toggle or the free-slot target. Still respects every hard protection, the
        -- quality/value limits, and the AdiBags Junk classification.
        print("|cFFFF5555Valuate|r: Deleting all eligible junk now...")
        Valuate:AutoDeleteJunk({ force = true })
    elseif command == "accept" then
        local options = Valuate:GetOptions()
        options.autoAcceptQuests = not options.autoAcceptQuests
        print("|cFF00FF00Valuate|r: Auto accept quests " .. (options.autoAcceptQuests and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif command == "quest" then
        local options = Valuate:GetOptions()
        options.autoQuestReward = not options.autoQuestReward
        print("|cFF00FF00Valuate|r: Auto quest reward " .. (options.autoQuestReward and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif command == "turnin" then
        local options = Valuate:GetOptions()
        options.autoQuestTurnIn = not options.autoQuestTurnIn
        print("|cFF00FF00Valuate|r: Auto quest turn-in " .. (options.autoQuestTurnIn and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        if options.autoQuestTurnIn and not options.autoQuestReward then
            print("|cFFFFAA00Valuate|r: Note - also enable Auto Quest Reward (/valuate quest) for turn-in to work.")
        end
    elseif command == "profile" then
        Valuate:RunProfile()
    elseif command == "future" then
        Valuate:PrintFutureUpgrades()
    elseif command == "weights" or strsub(command, 1, 8) == "weights " then
        Valuate:PrintStatShares(strtrim(strsub(msg, 8)))
    elseif command == "equip" then
        -- Equips the best set for the active scale. Referenced by the chat-style
        -- upgrade notification, which has no button to click.
        local scale, scaleName = Valuate:GetPrimaryScale()
        if not scale then
            print("|cFFFF0000Valuate|r: No active scale - activate one first.")
        else
            Valuate:EquipBestSet(scaleName)
        end
    elseif strsub(command, 1, 8) == "settings" then
        -- /valuate settings [save|load]
        local verb = strtrim(strsub(command, 10) or "")
        if verb == "save" then
            local n = Valuate:SaveSettingsSnapshot()
            print(string.format("|cFF00FF00Valuate|r: Saved %d setting(s) for use on your other characters.", n))
            print("  |cFFAAAAAANot copied: window position, this character's professions, and the character-window scale.|r")
        elseif verb == "load" then
            local ok, result = Valuate:LoadSettingsSnapshot()
            if ok then
                print(string.format("|cFF00FF00Valuate|r: Applied %d saved setting(s) to this character.", result))
                print("  |cFFAAAAAAReopen the Valuate window to see the updated controls.|r")
            else
                print("|cFFFF0000Valuate|r: " .. tostring(result) .. " - run /valuate settings save on a configured character first.")
            end
        else
            print("|cFF00FF00[Valuate]|r Settings snapshot |cFFAAAAAA(shared by all your characters)|r")
            if Valuate:HasSettingsSnapshot() then
                print("  A snapshot exists. |cFFFFFFFF/valuate settings load|r applies it here.")
            else
                print("  |cFFAAAAAANone saved.|r Use |cFFFFFFFF/valuate settings save|r on a character you've configured.")
            end
        end
    elseif strsub(command, 1, 7) == "library" then
        -- /valuate library [save|load|delete] <name>
        local rest = strtrim(strsub(command, 9) or "")
        local verb, arg = rest:match("^(%S+)%s+(.+)$")
        if not verb then verb, arg = rest, nil end

        local lib = Valuate:GetScaleLibrary()
        if verb == "save" and arg then
            local ok, result = Valuate:SaveScaleToLibrary(arg)
            if ok then
                print("|cFF00FF00Valuate|r: Saved '" .. result .. "' to the shared library.")
                print("  Available on all your characters via /valuate library load " .. result)
            else
                print("|cFFFF0000Valuate|r: " .. tostring(result))
            end
        elseif verb == "load" and arg then
            -- overwrite = true: loading an entry you already have is a deliberate
            -- "give me the library's copy", and refusing would leave no way to do it.
            local ok, result = Valuate:LoadScaleFromLibrary(arg, true)
            if ok then
                print("|cFF00FF00Valuate|r: Loaded '" .. tostring(result) .. "' onto this character.")
                if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
                -- The scale list lives in the UI namespace, which this file can't
                -- see; it rebuilds itself when the window is next opened, so a
                -- missed refresh here costs nothing.
            else
                print("|cFFFF0000Valuate|r: " .. tostring(result))
            end
        elseif verb == "delete" and arg then
            if Valuate:DeleteScaleFromLibrary(arg) then
                print("|cFF00FF00Valuate|r: Removed '" .. arg .. "' from the library.")
            else
                print("|cFFFF0000Valuate|r: No library entry called '" .. arg .. "'.")
            end
        else
            local names = Valuate:ListScaleLibrary()
            print("|cFF00FF00[Valuate]|r Scale library |cFFAAAAAA(shared by all your characters)|r")
            if #names == 0 then
                print("  |cFFAAAAAAEmpty.|r Save one with: /valuate library save <scale name>")
            else
                for _, name in ipairs(names) do
                    print("  |cFFFFFFFF" .. name .. "|r")
                end
                print("  |cFFAAAAAALoad onto this character: /valuate library load <name>|r")
            end
        end
    elseif command == "errors" then
        local errs = Valuate:GetEventErrors()
        if #errs == 0 then
            print("|cFF00FF00[Valuate]|r No errors this session.")
        else
            print(string.format("|cFFFF0000[Valuate]|r %d event(s) errored this session:", #errs))
            for _, e in ipairs(errs) do
                print("  |cFFFFFFFF" .. e.event .. "|r")
                print("    " .. tostring(e.message))
            end
            print("  |cFFAAAAAAEach is reported once. A code path is broken, not just switched off.|r")
        end
    elseif command == "junkmarks" then
        -- Diagnostic for the AdiBags "mark surplus gear as junk" option. Lives here
        -- because that is where every other Valuate diagnostic lives, and because
        -- the feature feeds auto-delete, which is a Valuate feature.
        local ab = _G.AdiBags
        local m = ab and ab.GetModule and select(2, pcall(ab.GetModule, ab, "ValuateBestItems", true))
        if type(m) == "table" and m.PrintJunkStatus then
            m:PrintJunkStatus()
        else
            print("|cFFFF8800[Valuate]|r The Valuate-AdiBags module isn't loaded, so nothing is being marked as junk.")
        end
    elseif command == "bank" then
        -- Diagnostic: says WHY the bank contributes nothing, rather than silently
        -- contributing nothing. The three reasons are: never visited, the option is
        -- off, or the visit found no equippable gear.
        local options = Valuate:GetOptions()
        local cache = Valuate:GetBankCache()
        local n = 0
        for _ in pairs(cache.items) do n = n + 1 end

        print("|cFF00FF00Valuate|r: Bank snapshot")
        if not options.includeBankItems then
            print("  |cFFFF8800Disabled|r - 'Include bank items' is off in Settings, so nothing below is used.")
        end
        if (cache.scannedAt or 0) == 0 then
            print("  |cFFFF8800Never scanned.|r Visit a bank once - the snapshot is taken automatically when the bank frame opens.")
        else
            print(string.format("  Last scanned: %s ago (%d slots seen)",
                SecondsToTime(math.max(1, time() - cache.scannedAt)), cache.slotsScanned or 0))
            print(string.format("  Equippable items cached: |cFFFFFFFF%d|r", n))
            if n == 0 then
                print("  |cFFFF8800No equippable gear found|r - the bank holds only non-gear, or everything was excluded (e.g. profession tools).")
            end
        end
        print("  Bank items can be best-in-slot, but Equip All skips them - you must withdraw them first.")
    elseif command == "scales" then
        local activeScales = Valuate:GetActiveScales()
        if #activeScales > 0 then
            print("|cFF00FF00Valuate|r: Active scales:")
            local scales = Valuate:GetScales()
            for _, scaleName in ipairs(activeScales) do
                local scale = scales[scaleName]
                local color = scale.Color or "FFFFFF"
                print("  |cFF" .. color .. (scale.DisplayName or scaleName) .. "|r")
            end
        else
            print("|cFFFF0000Valuate|r: No scales configured. Using default scale.")
        end
    elseif command == "import" then
        -- Open import dialog
        if Valuate.ShowImportDialog then
            Valuate:ShowImportDialog()
        else
            print("|cFFFF0000Valuate|r: UI not loaded. Please open Valuate UI first with /valuate")
        end
    elseif strsub(command, 1, 6) == "export" then
        -- Export a scale
        local scaleName = strtrim(strsub(command, 8))
        
        if scaleName == "" then
            -- No scale name specified - list available scales
            print("|cFF00FF00Valuate|r: Please specify a scale name to export.")
            print("Available scales:")
            Valuate:PrintScaleList()
            print("Usage: /valuate export [scalename]")
        else
            -- Find the scale, case-insensitively, by internal name or display name.
            --
            -- This used to take the FIRST match and break. pairs() has no order, so with
            -- two scales whose names differ only in case, or where one scale's key
            -- happens to equal another's display name, it exported an arbitrary one of
            -- them - and said nothing. Handing a friend the wrong scale is a failure you
            -- only find out about later, if at all.
            --
            -- So: collect every match. An exact internal-name hit is unambiguous by
            -- definition (keys are unique) and wins outright; otherwise, more than one
            -- match is reported rather than guessed at.
            local wanted = strlower(scaleName)
            local exactKey = nil
            local matches = {}

            for name, scale in pairs(ValuateScales) do
                local displayName = scale.DisplayName or name
                if name == scaleName then
                    exactKey = name
                elseif strlower(name) == wanted or strlower(displayName) == wanted then
                    tinsert(matches, name)
                end
            end
            table.sort(matches)  -- pairs() collected them; don't report them arbitrarily either

            local foundName = exactKey or (#matches == 1 and matches[1] or nil)
            local foundScale = foundName and ValuateScales[foundName] or nil

            if not foundName and #matches > 1 then
                print("|cFFFF8800Valuate|r: '" .. scaleName .. "' matches " .. #matches .. " scales:")
                for _, name in ipairs(matches) do
                    local dn = ValuateScales[name].DisplayName or name
                    print("  " .. dn .. (dn ~= name and ("  |cFFAAAAAA(" .. name .. ")|r") or ""))
                end
                print("|cFFFFFF00Use the exact name in brackets to pick one.|r")
                return
            end

            if foundScale and foundName then
                local scaleTag, whyNot = Valuate:GetScaleTag(foundName)
                if scaleTag then
                    print("|cFF00FF00Valuate|r: Scale tag for |cFFFFFFFF" .. (foundScale.DisplayName or foundName) .. "|r:")
                    print(scaleTag)
                    print("|cFFFFFF00Tip:|r Open the Valuate UI (/valuate) to use the Export button for easier copying.")
                else
                    print("|cFFFF0000Valuate|r: " .. (whyNot or "Failed to generate export string for scale."))
                end
            else
                print("|cFFFF0000Valuate|r: Scale not found: " .. scaleName)
                print("Available scales:")
                Valuate:PrintScaleList()
            end
        end
    elseif command == "ui" then
        if Valuate.ToggleUI then
            Valuate:ToggleUI()
        else
            print("|cFFFF0000Valuate|r: UI not loaded. Please reload UI with /reload")
        end
    else
        print("|cFF00FF00Valuate|r: Unknown command. Type |cFFFFFFFF/valuate help|r for available commands.")
    end
end

-- ========================================
-- Keybinding System
-- ========================================
-- Note: ValuateToggleUI() is defined at the top of the file to ensure
-- it's available when Bindings.xml is processed


