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
        if not ok and not self.errorReported then
            self.errorReported = true
            print("|cFFFF0000[Valuate]|r Automatic junk cleanup errored and has been reported once:")
            print("  " .. tostring(err))
            print("  |cFFAAAAAARun /valuate deletepreview to check what it would act on.|r")
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
        -- The bank is the only time its containers are readable, so snapshot it now.
        -- Delayed slightly on open so every bank bag has reported its contents, and
        -- re-run on change so moving gear in or out updates the snapshot. This only
        -- feeds best-in-slot; nothing destructive ever reads the bank.
        if Valuate.ScanBankContents then
            ValuateAfter(0.4, function()
                if Valuate:ScanBankContents() then
                    ScheduleScan(0.6, "bank")  -- fold new candidates into best-in-slot
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
    characterWindowDisplayMode = "total",
    uiPosition = {},                      -- table default: fresh copy per character
    normalizeDisplay = false,
    reduceMotion = false,                 -- collapse all UI animations to instant
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
    showUpgradeArrows = true,             -- green arrow on merchant/loot/bag icons that upgrade a scale
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

-- Creates a simple default scale for testing
function Valuate:CreateDefaultScale()
    local defaultScale = {
        DisplayName = "Default",
        Color = "00FF00",
        Visible = true,
        Values = {
            -- Example stat weights (users should customize these)
            Strength = 1.0,
            Agility = 1.0,
            Stamina = 0.5,
            Intellect = 1.0,
            AttackPower = 1.0,
            SpellPower = 1.0,
        }
    }
    
    local scales = Valuate:GetScales()
    scales["Default"] = defaultScale
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
    
    -- Calculate percentage
    local percent = (diff / equippedScore) * 100
    local diffColor = diff > 0 and "|cFF00FF00" or (diff < 0 and "|cFFFF0000" or "|cFFFFFF00")
    local diffSign = diff > 0 and "+" or ""
    local diffText = string.format(formatStr, diff)
    
    -- Handle extreme percentages
    if math.abs(percent) >= 1000 then
        if compMode == "both" then
            return " " .. diffColor .. "(" .. diffSign .. diffText .. ", " .. diffSign .. "HUGE!)|r"
        else
            return " " .. diffColor .. "(" .. diffSign .. "HUGE!)|r"
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
    -- Hook the Set* methods to parse stats and mark for update
    local function OnTooltipSet(self)
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
            end
        end
    end
    
    -- Special hooks to capture item source for proper item link retrieval
    local LastInventorySlot = nil
    local LastBagSlot = nil
    
    hooksecurefunc(GameTooltip, "SetBagItem", function(self, bag, slot)
        OnTooltipSet(self)
        LastBagSlot = {bag = bag, slot = slot}
        LastInventorySlot = nil  -- Clear inventory slot when showing bag item
    end)
    
    hooksecurefunc(GameTooltip, "SetInventoryItem", function(self, unit, slot)
        OnTooltipSet(self)
        LastInventorySlot = {unit = unit, slot = slot}
        LastBagSlot = nil  -- Clear bag slot when showing inventory item
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
function Valuate:GetActiveScales()
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
    local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
    local targetSlots = (itemEquipLoc and itemEquipLoc ~= "") and EquipSlotToInvNumber[itemEquipLoc] or nil

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

    local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
    local targetSlots = (itemEquipLoc and itemEquipLoc ~= "") and EquipSlotToInvNumber[itemEquipLoc] or nil
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
    local bestIndex, bestScore, bestLink
    local upgIndex, upgDelta, upgScore, upgLink
    for index = 1, numChoices do
        local score = ScoreQuestChoice(index, scale)
        if score then
            local link = GetQuestItemLink("choice", index)
            if not bestScore or score > bestScore then
                bestScore, bestIndex, bestLink = score, index, link
            end
            local delta = score - Valuate:GetUpgradeBaseline(link, scale, scaleName)
            if not upgDelta or delta > upgDelta then
                upgDelta, upgIndex, upgScore, upgLink = delta, index, score, link
            end
        end
    end

    -- If at least one reward beats what you already have, take the biggest upgrade.
    -- Otherwise keep the highest-scoring reward (nothing is an upgrade, so grab the
    -- most valuable item overall).
    if upgIndex and upgDelta and upgDelta > 0 then
        bestIndex, bestScore, bestLink = upgIndex, upgScore, upgLink
    end

    -- If nothing scored (e.g. all rewards are bags/consumables), don't guess -
    -- leave the decision to the player. A lone choice is safe to pre-select.
    if not bestIndex then
        if numChoices == 1 then
            bestIndex = 1
            bestLink = GetQuestItemLink("choice", 1)
        else
            return
        end
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

    -- Best-in-slot / weapon-set member for any scale
    if Valuate.GetBestForInfo and Valuate:GetBestForInfo(link) then
        return true, "best-in-slot"
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
                local _, stackCount = GetContainerItemInfo(bag, slot)
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
                if isJunk then
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
            if nowLink ~= c.link then
                -- Contents changed; skip this slot silently rather than risk it.
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
            print("|cFF00FF00[Valuate]|r Repaired using guild funds (" .. money .. ").")
            return true
        end
    end

    if GetMoney() < cost then
        print("|cFFFF5555[Valuate]|r Not enough money to repair (" .. money .. ").")
        return false
    end

    RepairAllItems()
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
    local rollType, label
    if isUpgrade or isRecipe or isMaterial then
        if canNeed then rollType, label = 1, "Need"
        -- Need is not always offered for something you can't use yet, which is
        -- exactly the case for a recipe above your skill. Greed still wins it.
        elseif canGreed then rollType, label = 2, "Greed"
        else rollType, label = 0, "Pass" end
    else
        if canGreed then rollType, label = 2, "Greed"
        else rollType, label = 0, "Pass" end
    end

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
        { key = "bankSnapshot",  label = "Bank snapshot" },
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
        "RunProfile", "RunVerify", "CountEquippableUpgrades", "PrintScaleList",
        "ReportRuntimeError",
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
        id = "press", since = "0.23.2a",
        title = "Buttons show a pressed state on a fast click",
        steps = "Open the UI, hover any button, then click it within about a fifth of a second.",
        expect = "It visibly darkens while the mouse button is held.",
        broke = "The hover fade overwrote the pressed colour on the very next frame, so quick clicks looked like they had not registered.",
    },
    {
        id = "minimap", since = "0.23.1a",
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
        id = "flash", since = "0.25.0a",
        title = "Best Equipment marks the slots a scan changed",
        steps = "Open the Best Equipment tab and leave it open. Put a clear upgrade for one slot in your bags, then run /valuate scan.",
        expect = "Exactly that slot's row lights up green briefly. Rows that did not change stay dark, and nothing lights up on the first visit to the tab.",
        broke = "New in this version - never run.",
    },
    {
        id = "search", since = "0.29.0a",
        title = "Settings search dims everything except what you typed",
        steps = "Open Settings and type 'junk' in the search box at the top. Then clear it, and press Escape with text in the box.",
        expect = "Only junk-related rows stay bright; everything else dims but STAYS PUT - nothing may move or reflow. Clearing restores every row to full brightness, with none left dim.",
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
end

function Valuate:RunVerify(which)
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
                return true
            end
        end
        print("|cFFFF0000[Valuate]|r No such check: " .. which)
    end

    print("|cFF00FF00[Valuate]|r Behavioural checks - the things no gate can answer")
    print("|cFFAAAAAAEverything here fails SILENTLY when it fails. Run /valuate verify <name>|r")
    print("|cFFAAAAAAto see one in detail; some will set themselves up for you.|r")
    print(" ")
    for i, c in ipairs(VERIFY_CHECKS) do
        print(string.format("|cFF00FF00%d. %s|r |cFFAAAAAA(v%s)|r  -  /valuate verify %s",
            i, c.title, c.since, c.id))
    end
    print(" ")
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
        print("  /valuate scales - List all stat weight scales")
        print("  /valuate bank - Show the bank snapshot used for best-in-slot")
        print("  /valuate equip - Equip the best set for the active scale")
        print("  /valuate junkinterval <secs> - How often junk cleanup runs on its own (0 = off)")
        print("  /valuate profile - Measure scan, scoring and tooltip-parse timings")
        print("  /valuate junkmarks - Why surplus gear is (or is not) being marked junk")
        print("  /valuate check - Is Valuate actually working? Start here")
        print("  /valuate verify - Behavioural checks a human has to look at (some self-arming)")
        print("  /valuate errors - Anything that errored this session (empty is expected)")
        print("  /valuate why [itemlink] - Explain what Valuate thinks of an item (roll, arrow, junk)")
        print("  /valuate library - Scales shared across all your characters (save/load/delete)")
        print("  /valuate settings save|load - Copy your settings to your other characters")
        print("  /valuate import - Import a scale from a scale tag")
        print("  /valuate export [scalename] - Export a scale as a scale tag")
        print("  /valuate ui - Open the configuration UI")
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
            problems[#problems + 1] = "no active scale - nothing can be scored until you tick one"
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


