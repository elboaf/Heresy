-- Addon Name: Heresy
-- This addon is designed to automate various tasks for a Priest in World of Warcraft, such as buffing, healing, dispelling, and assisting party members.

Heresy = {}
-- Configuration Variables
local healSecondLowest = false -- Tracks if the priest should heal the 2nd lowest member
-- Leader and Mount Configuration
local leader = "Rele" -- The name of the party leader to follow
local leaderMount = "Summon Warhorse" -- The mount spell used by the leader
local myMount = "Thalassian Unicorn" -- The mount spell used by the player
local champBuff = "Empower Champion" -- The spell used to buff the champion
local enableFollow = true -- Tracks if the follow functionality is enabled
local enableChampionBuff = true -- Tracks if champion buffing is enabled
local enableSmiteMode = true -- Tracks if Smite mode is enabled


-- Configuration Variables for Optional Buffs
local enableShadowProtection = false -- Tracks if Shadow Protection should be applied
local enableFearWard = false -- Tracks if Fear Ward should be applied

-- Global State Variables
local master_buff = false -- Tracks if the player is currently buffing
local master_drink = false -- Tracks if the player is currently drinking
local master_follow = false -- Tracks if the player is currently following the leader
local championName = leader -- The name of the designated champion
local champGraceBuffed = false -- Tracks if the champion has been buffed with "Champion's Grace"
local champProclaimed = false -- Tracks if the champion has been proclaimed
local lastBuffCompleteTime = 0 -- Tracks the last time buffing was completed
local BUFF_THROTTLE_DURATION = 30 -- Throttle duration for buffing (in seconds)
local buffThrottle = false -- Tracks if buffing is currently throttled
local mounted = false -- Tracks if the player is mounted
local inCombat = false -- Tracks if the player is in combat

-- Configuration Variables
local isDrinkingMode = false -- Tracks if the player is in drinking mode
local isDrinkingNow = false -- Tracks if the player is currently drinking
local DRINKING_MANA_THRESHOLD = 80 -- Stop drinking at this % mana
local START_DRINKING_MANA_THRESHOLD = 60 -- Start drinking at this % mana
local EMERGENCY_HEALTH_THRESHOLD = 40 -- Heal party members below this % health even while drinking
local HEALTH_THRESHOLD = 95 -- Heal if health is below this %
local BANDAIDS_MANA_THRESHOLD = 95 -- Use shield and renew if mana is above this %
local LOW_MANA_THRESHOLD = 10 -- Threshold for low mana
local CRITICAL_MANA_THRESHOLD = 15 -- Threshold for critical mana
local QDM_POT_MANA_THRESHOLD = 30 -- Threshold for using Quel'dorei Meditation or mana potions
local MANA_ANNOUNCEMENT_THRESHOLD = 40 -- Threshold for announcing low mana
local SHOOT_TOGGLE_COOLDOWN = 1.7 -- Cooldown for toggling Shoot (in seconds)
local FLAY_DURATION = 3 -- Duration for Mind Flay (in seconds)

-- Assist Mode Configuration
local assistmode = 1 -- Tracks if assist mode is enabled (1 = on, 0 = off)

-- Spell Constants
local SPELL_PWF = "Power Word: Fortitude"
local SPELL_POF = "Prayer of Fortitude"
local SPELL_SPIRIT = "Divine Spirit"
local SPELL_POSPIRIT = "Prayer of Spirit"
local SPELL_SPROT = "Shadow Protection"
local SPELL_FWARD = "Fear Ward"
local SPELL_LESSER_HEAL = "Lesser Heal"
local SPELL_HEAL = "Heal"
local SPELL_GREATER_HEAL = "Greater Heal"
local SPELL_FLASH_HEAL = "Flash Heal"
local SPELL_RENEW = "Renew"
local SPELL_SMITE = "Smite"
local SPELL_SHOOT = "Shoot"
local SPELL_SWP = "Shadow Word: Pain"
local SPELL_SWP2 = "Shadow Word: Pain(Rank 8)"
local SPELL_MIND_BLAST = "Mind Blast"
local SPELL_MIND_BLAST2 = "Mind Blast(Rank 9)"
local SPELL_MIND_FLAY = "Mind Flay"
local SPELL_QDM = "Quel'dorei Meditation"
local SPELL_PWS = "Power Word: Shield"
local SPELL_FADE = "Fade"
local SPELL_PSCREAM = "Psychic Scream"
local SPELL_INNER_FIRE = "Inner Fire"
local SPELL_DISPEL = "Dispel Magic"
local SPELL_CURE_DISEASE = "Cure Disease"
local SPELL_INNER_FOCUS = "Inner Focus"

local lastDispelTime = 0
local lastCureDiseaseTime = 0
local DISPEL_THROTTLE_DURATION = 3 -- Throttle duration for dispels (in seconds)
local CURE_DISEASE_THROTTLE_DURATION = 3 -- Throttle duration for curing diseases (in seconds)

-- Timing Variables
local lastShootToggleTime = 0 -- Tracks the last time Shoot was toggled
local lastFlayTime = 0 -- Tracks the last time Mind Flay was cast

-- Lists of Items and Buffs
local drinkstodrink = { -- List of drink items
    "Morning Glory",
    "Moonberry",
    "Sweet",
    "Melon",
    "Conjured",
}

local PWS_DEBUFF = { -- List of debuffs that prevent Power Word: Shield
    "AshesToAshes",
}

-- List of debuffs to dispel with Dispel Magic
local debuffsToDispel = {
    "ShadowWordPain",
    "Polymorph",
    "Immolation",
    "Sleep",
    "FrostNova",
    "FlameShock",
    "ThunderClap",
    "Nature_Sleep",
    "StrangleVines",
    "Slow",
    "AbominationExplosion",
    "Shadow_Teleport",
    "Shaman_Hex",
    "SummonImp",
    "Taunt",
    "AnimateDead",
    "Shadow_Cripple",
    "FrostArmor",
    "Shadow_Possession",
    "SummonWaterElemental",
    "Nature_Cyclone",
    "GolemThunderClap",
    -- Add more debuff names here as needed
}

-- List of debuffs to cure with Cure Disease
local diseasesToCure = {
    "NullifyDisease",
    "CallofBone",
    "CreepingPlague",
    "HarmUndeadAura",
    -- Add more disease debuff names here as needed
}

-- List of drink buffs
local drinkBuffs = {
    "INV_Drink",  -- Matches any buff with "INV_Drink" in its texture path
    "Drink",      -- Matches any buff with "Drink" in its name or texture path
    -- Add more partial patterns as needed
}

-- Table of mana potions to search for
local manaPotions = {
    "Mana Potion",
    "Herbal Tea",
    -- Add more mana potion names here dispe needed
}

-- Table of item buff mappings
local itemBuffMap = {
    -- Format: {itemName, buffName, targetType, classes}
    ["Scroll of Intellect"] = {"Intellect", "mana", {"MAGE", "PRIEST", "WARLOCK", "DRUID", "SHAMAN", "PALADIN", "HUNTER"}},  -- Intellect for mana users
    ["Scroll of Protection"] = {"Armor", "both", nil},  -- Armor for all party members (no class restriction)
    ["Scroll of Strength"] = {"Strength", "both", {"WARRIOR", "ROGUE", "PALADIN", "HUNTER"}},  -- Strength for melee classes
    ["Scroll of Agility"] = {"Agility", "both", {"ROGUE", "HUNTER", "WARRIOR", "PALADIN"}},  -- Agility for agility-based classes
}

-- Table of buff synonyms
local buffSynonyms = {
    ["Intellect"] = {"Arcane Intellect"},  -- "Arcane Intellect" is synonymous with "Intellect"
    ["Agility"] = {},                     -- No direct class buff synonym for "Agility"
    -- Add more buff synonyms as needed
}

-- Helper function to check if a value exists in a table
local function tContains(table, value)
    for _, v in ipairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- Helper function to check if a unit has a specific buff or any of its synonyms
local function HasItemBuff(unit, buffName)
    -- Check if the unit has the buff (using buffed())
    if buffed(buffName, unit) then
        return true
    end

    -- Check for synonyms (using buffed())
    if buffSynonyms[buffName] then
        for _, synonym in ipairs(buffSynonyms[buffName]) do
            if buffed(synonym, unit) then
                return true
            end
        end
    end

    return false
end

-- Helper function to check if a unit uses mana
local function IsManaUser(unit)
    local powerType = UnitPowerType(unit)
    return powerType == 0 -- 0 corresponds to mana
end

-- Function to check if the target is the champion
local function IsChampion(unit)
    return championName and UnitExists(unit) and UnitName(unit) == championName
end

-- Helper function to get the spell index by name
local function GetSpellIndex(spellName)
    for i = 1, 180 do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if name and strfind(name, spellName) then
            return i
        end
    end
    return nil
end

-- Function to buff the champion with "Proclaim Champion" and "Champion's Grace"
local function BuffChampion()
    if not enableChampionBuff then
        return -- Champion buffing is disabled
    end

    if not championName then
        return -- No champion designated
    end

    -- Cast "Champion's Grace" if the champion has "Holy Champion"
    for i = 1, 4 do
        local partyChamp = "party" .. i
        if UnitExists(partyChamp) and not UnitIsDeadOrGhost(partyChamp) and buffed("Holy Champion", partyChamp) and not buffed(champBuff, partyChamp) then
            CastSpellByName(champBuff)
            SpellTargetUnit(partyChamp)
            champProclaimed = false -- Reset proclamation flag
            champGraceBuffed = true
        end
    end

    if not champGraceBuffed then
        -- Check if the champion is in range and alive
        if not UnitExists("target") or not IsChampion("target") or UnitIsDeadOrGhost("target") then
            TargetByName(championName, true) -- Target the champion
            if buffed(champBuff, "target") then
                champGraceBuffed = true
            end
        end

        if not IsChampion("target") then
            return -- Champion is not targeted
        end

        -- Check if the champion has the "Holy Champion" buff
        local hasHolyChampion = buffed("Holy Champion", "target")

        -- Cast "Proclaim Champion" if the champion doesn't have "Holy Champion" and the spell is off cooldown
        if not hasHolyChampion then
            local spellIndex = GetSpellIndex("Proclaim Champion")
            if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                CastSpellByName("Proclaim Champion")
                SpellTargetUnit("target")
                if not champProclaimed then -- Prevent chat spam
                    champProclaimed = true
                end
                champGraceBuffed = false
                lastBuffCompleteTime = 0
                return
            else
                ClearTarget()
                return
            end
        end
    else
        return
    end
end

-- Helper function to check if a unit has a specific debuff
local function HasDebuff(unit, debuffList)
    for i = 1, 16 do
        local name = UnitDebuff(unit, i)
        if name then
            for _, debuff in ipairs(debuffList) do
                if strfind(name, debuff) then
                    return true
                end
            end
        end
    end
    return false
end

-- Helper function to check if a unit has a specific buff by partial name or texture path
local function HasBuff(unit, BuffList)
    for i = 1, 16 do
        local texture = UnitBuff(unit, i)
        if texture then
            for _, buffPattern in ipairs(BuffList) do
                if strfind(texture, buffPattern) then
                    return true
                end
            end
        end
    end
    return false
end

-- Helper function to check for Drink Buffs
local function CheckDrinkBuff()
    if not HasBuff("player", drinkBuffs) then
        isDrinkingMode = false
        master_drink = false
        isDrinkingNow = false
        return false
    else
        return true
    end
end

-- Helper function to check if a unit is within buffing range
local function IsUnitInRange(unit)
    return CheckInteractDistance(unit, 4)
end

-- Function to check if Shoot is active
local function IsShootActive()
    for i = 1, 120 do
        if IsAutoRepeatAction(i) then
            return true
        end
    end
    return false
end

-- Function to toggle Shoot off
local function ToggleShootOff()
    if IsShootActive() then
        CastSpellByName(SPELL_SHOOT) -- Toggle Shoot off
    end
end

-- Helper function to buff a unit with a specific spell
local function BuffUnitWithSpell(unit, spell)
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsUnitInRange(unit) then
        if not buffed(spell, unit) then
            CastSpellByName(spell)
            SpellTargetUnit(unit)
            master_buff = true
            return true
        end
    end
    master_buff = false
    return false
end

-- Function to buff a unit with Shadow Protection
local function BuffShadowProtection(unit)
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsUnitInRange(unit) then
        if not buffed(SPELL_SPROT, unit) then
            CastSpellByName(SPELL_SPROT)
            SpellTargetUnit(unit)
            master_buff = true
            return true
        end
    end
    master_buff = false
    return false
end

-- Function to search bags for mana potions and use one when mana is below 40%
local function UseManaPotion()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    -- Check if mana is below 40%
    if mana < 60 and UnitAffectingCombat("player") then
        -- Search through all bags
        for b = 0, 4 do
            for s = 1, GetContainerNumSlots(b) do
                local itemLink = GetContainerItemLink(b, s)
                if itemLink then
                    -- Check if the item is in the mana potions table using strfind
                    for _, potion in ipairs(manaPotions) do
                        if strfind(itemLink, potion) then
                            -- Check if the item is off cooldown
                            local startTime, duration, isEnabled = GetContainerItemCooldown(b, s)
                            if startTime == 0 and duration == 0 then
                                -- Use the mana potion
                                UseContainerItem(b, s)
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

local function BuffUnit(unit)
    if not isDrinkingNow then
        -- Skip Power Word: Fortitude if Prayer of Fortitude is active
        if not buffed(SPELL_POF, unit) then
            if BuffUnitWithSpell(unit, SPELL_PWF) then
                return true
            end
        end

        -- Skip Divine Spirit if Prayer of Spirit is active
        if not buffed(SPELL_POSPIRIT, unit) then
            if BuffUnitWithSpell(unit, SPELL_SPIRIT) then
                return true
            end
        end

        -- Only apply Shadow Protection if enabled
        if enableShadowProtection and BuffShadowProtection(unit) then
            return true
        end

        -- Only apply Fear Ward if enabled
        if enableFearWard and not buffed(SPELL_FWARD, unit) then
            local spellIndex = GetSpellIndex(SPELL_FWARD)
            if spellIndex then
                local start, duration = GetSpellCooldown(spellIndex, BOOKTYPE_SPELL)
                if start > 0 and duration > 0 then
                    -- Fear Ward is on cooldown, skip casting it
                else
                    -- Fear Ward is not on cooldown, attempt to cast it
                    if BuffUnitWithSpell(unit, SPELL_FWARD) then
                        return true
                    end
                end
            end
        end
        return false
    end
end

-- Function to check if all buffing is complete
local function IsBuffingComplete()
    if not isDrinkingNow then
        if not BuffUnitWithSpell("player", SPELL_PWF) or not BuffUnitWithSpell("player", SPELL_SPIRIT) then
            return false
        end

        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) then
                if not BuffUnitWithSpell(partyMember, SPELL_PWF) or not BuffUnitWithSpell(partyMember, SPELL_SPIRIT) then
                    return false
                end
            end
        end

        return true
    end
end

-- Function to dispel a unit with Dispel Magic
local function DispelUnit(unit)
    if not isDrinkingNow then
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            CastSpellByName(SPELL_DISPEL)
            SpellTargetUnit(unit)
            return true
        end
        return false
    end
end

-- Function to cure a unit with Cure Disease
local function CureDiseaseUnit(unit)
    if not isDrinkingNow then
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            CastSpellByName(SPELL_CURE_DISEASE)
            SpellTargetUnit(unit)
            return true
        end
        return false
    end
end

-- Function to buff Inner Fire on the player
local function BuffInnerFire()
    if not isDrinkingNow then
        if not buffed(SPELL_INNER_FIRE, "player") then
            CastSpellByName(SPELL_INNER_FIRE)
        end
    end
end

-- Function to check if buffing is throttled
local function buffThrottleCheck()
    if GetTime() - lastBuffCompleteTime < BUFF_THROTTLE_DURATION then
        buffThrottle = true
    else
        buffThrottle = false
    end
end

local function BuffParty()
    if inCombat or mounted then  -- Do not buff if in combat or mounted
        return
    end
    CheckDrinkBuff()

    ClearTarget()
    master_buff = true
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    buffThrottle = false
    if not isDrinkingNow then
        if mana > DRINKING_MANA_THRESHOLD then
            master_drink = false
        end
        if master_drink then
            return false
        end
        CheckDrinkBuff()

        -- Do not buff if drinking mode is active
        if isDrinkingMode then
            return false
        end

        -- Do not buff if mana is critically low
        if mana <= LOW_MANA_THRESHOLD then
            return false
        end

        if not hasHolyChampion then
            champGraceBuffed = false
            champProclaimed = false
        end

        -- Buff the champion first
        BuffChampion()

        -- Buff the player
        ClearTarget()
        if BuffUnit("player") then
            return false
        end
        if not buffed(SPELL_INNER_FIRE, "player") and not isDrinkingNow then
            CastSpellByName(SPELL_INNER_FIRE)
        end

        -- Buff party members
        for i = 1, 4 do
            local partyMember = "party" .. i
            if BuffUnit(partyMember) then
                return false
            end
        end

        -- Buff raid members
        for i = 1, 40 do
            local raidMember = "raid" .. i
            if BuffUnit(raidMember) then
                return false
            end
        end

        TargetByName(championName)
        local hasHolyChampion = buffed("Holy Champion", "target")
        ClearTarget()
        -- If no buffing was needed, set the last buff complete time
        lastBuffCompleteTime = GetTime()
        return true
    end
end

local function BuffPartyWithItems()
    if not isDrinkingNow then
        for itemName, itemData in pairs(itemBuffMap) do
            local buffName = itemData[1]  -- The name of the buff (e.g., "Intellect", "Strength")
            local targetType = itemData[2]
            local classes = itemData[3]  -- List of classes that should receive this buff

            -- Search through all bags
            for b = 0, 4 do
                for s = 1, GetContainerNumSlots(b) do
                    local itemLink = GetContainerItemLink(b, s)
                    if itemLink and strfind(itemLink, itemName) then
                        -- Check if the item is off cooldown
                        local startTime, duration, isEnabled = GetContainerItemCooldown(b, s)
                        if startTime == 0 and duration == 0 then
                            -- Buff the player first (if applicable)
                            if (targetType == "both" or
                                (targetType == "mana" and IsManaUser("player")) or
                                (targetType == "non-mana" and not IsManaUser("player"))) then
                                -- Check if the player's class is allowed to receive this buff
                                local _, playerClass = UnitClass("player")
                                if not classes or tContains(classes, playerClass) then
                                    if not HasItemBuff("player", buffName) then
                                        UseContainerItem(b, s)
                                        SpellTargetUnit("player")
                                    end
                                end
                            end

                            -- Buff party members (if applicable)
                            for i = 1, 4 do
                                local partyMember = "party" .. i
                                if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) then
                                    local shouldBuff = false

                                    -- Check if the party member should receive the buff based on targetType
                                    if targetType == "both" then
                                        shouldBuff = true
                                    elseif targetType == "mana" and IsManaUser(partyMember) then
                                        shouldBuff = true
                                    elseif targetType == "non-mana" and not IsManaUser(partyMember) then
                                        shouldBuff = true
                                    end

                                    -- Check if the party member's class is allowed to receive this buff
                                    local _, partyMemberClass = UnitClass(partyMember)
                                    if shouldBuff and (not classes or tContains(classes, partyMemberClass)) then
                                        -- Apply the buff if the party member should receive it and doesn't already have it
                                        if not HasItemBuff(partyMember, buffName) then
                                            UseContainerItem(b, s)
                                            SpellTargetUnit(partyMember)
                                        end
                                    end
                                end
                            end

                            -- Buff raid members (if applicable)
                            for i = 1, 40 do
                                local raidMember = "raid" .. i
                                if UnitExists(raidMember) and not UnitIsDeadOrGhost(raidMember) then
                                    local shouldBuff = false

                                    -- Check if the raid member should receive the buff based on targetType
                                    if targetType == "both" then
                                        shouldBuff = true
                                    elseif targetType == "mana" and IsManaUser(raidMember) then
                                        shouldBuff = true
                                    elseif targetType == "non-mana" and not IsManaUser(raidMember) then
                                        shouldBuff = true
                                    end

                                    -- Check if the raid member's class is allowed to receive this buff
                                    local _, raidMemberClass = UnitClass(raidMember)
                                    if shouldBuff and (not classes or tContains(classes, raidMemberClass)) then
                                        -- Apply the buff if the raid member should receive it and doesn't already have it
                                        if not HasItemBuff(raidMember, buffName) then
                                            UseContainerItem(b, s)
                                            SpellTargetUnit(raidMember)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function DispelParty()
    if not isDrinkingNow then
        local currentTime = GetTime()
        if currentTime - lastDispelTime < DISPEL_THROTTLE_DURATION then
            return
        end

        if HasDebuff("player", debuffsToDispel) then
            if UnitExists("target") and UnitCanAttack("player", "target") then
                ClearTarget()
            end
            if DispelUnit("player") then
                lastDispelTime = currentTime
                return
            end
        end

        -- Check party members
        for i = 1, 4 do
            local partyMember = "party" .. i
            if HasDebuff(partyMember, debuffsToDispel) then
                if UnitExists("target") and UnitCanAttack("player", "target") then
                    ClearTarget()
                end
                if DispelUnit(partyMember) then
                    lastDispelTime = currentTime
                    return
                end
            end
        end

        -- Check raid members
        for i = 1, 40 do
            local raidMember = "raid" .. i
            if HasDebuff(raidMember, debuffsToDispel) then
                if UnitExists("target") and UnitCanAttack("player", "target") then
                    ClearTarget()
                end
                if DispelUnit(raidMember) then
                    lastDispelTime = currentTime
                    return
                end
            end
        end
    end
end

local function CureDiseaseParty()
    if not isDrinkingNow then
        local currentTime = GetTime()
        if currentTime - lastCureDiseaseTime < CURE_DISEASE_THROTTLE_DURATION then
            return
        end

        if HasDebuff("player", diseasesToCure) then
            if UnitExists("target") and UnitCanAttack("player", "target") then
                ClearTarget()
            end
            if CureDiseaseUnit("player") then
                lastCureDiseaseTime = currentTime
                return
            end
        end

        -- Check party members
        for i = 1, 4 do
            local partyMember = "party" .. i
            if HasDebuff(partyMember, diseasesToCure) then
                if UnitExists("target") and UnitCanAttack("player", "target") then
                    ClearTarget()
                end
                if CureDiseaseUnit(partyMember) then
                    lastCureDiseaseTime = currentTime
                    return
                end
            end
        end

        -- Check raid members
        for i = 1, 40 do
            local raidMember = "raid" .. i
            if HasDebuff(raidMember, diseasesToCure) then
                if UnitExists("target") and UnitCanAttack("player", "target") then
                    ClearTarget()
                end
                if CureDiseaseUnit(raidMember) then
                    lastCureDiseaseTime = currentTime
                    return
                end
            end
        end
    end
end

local function DispelHighPriorityDebuffs()

        -- List of high-priority debuffs
        local highPriorityDebuffs = {"Shaman_Hex", "Polymorph", "Shadow_Possession", "Nature_Sleep"}

        -- Check party members for high-priority debuffs
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) then
                if HasDebuff(partyMember, highPriorityDebuffs) then
                    if UnitExists("target") and UnitCanAttack("player", "target") then
                        ClearTarget()
                    end
                    if DispelUnit(partyMember) then
                        return true -- A high-priority debuff was dispelled
                    end
                end
            end
        end

        -- Check raid members for high-priority debuffs
        for i = 1, 40 do
            local raidMember = "raid" .. i
            if UnitExists(raidMember) and not UnitIsDeadOrGhost(raidMember) then
                if HasDebuff(raidMember, highPriorityDebuffs) then
                    if UnitExists("target") and UnitCanAttack("player", "target") then
                        ClearTarget()
                    end
                    if DispelUnit(raidMember) then
                        return true -- A high-priority debuff was dispelled
                    end
                end
            end
        end

    return false -- No high-priority debuffs were found or dispelled
end

local function HealParty()
    if master_buff then
        return false
    end

    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    CheckDrinkBuff()

    -- Priority 1: Check for high-priority debuffs ("Shaman_Hex" and "Polymorph") and dispel them immediately
    local highPriorityDebuffFound = DispelHighPriorityDebuffs()
    if highPriorityDebuffFound then
        return true -- Exit early if a high-priority debuff was dispelled
    end

    -- If out of combat and mana is below 90%, do not heal
    if not UnitAffectingCombat("player") and mana < START_DRINKING_MANA_THRESHOLD then
        return false
    end

    -- Check if Inner Focus is available and mana is below 80%
    local innerFocusSpellIndex = GetSpellIndex(SPELL_INNER_FOCUS)
    local innerFocusReady = innerFocusSpellIndex and GetSpellCooldown(innerFocusSpellIndex, BOOKTYPE_SPELL) < 1
    local hasInnerFocusBuff = buffed(SPELL_INNER_FOCUS, "player")

    -- Cast Inner Focus if mana is below 80% and it's ready
    if mana < 30 and innerFocusReady and not hasInnerFocusBuff then
        CastSpellByName(SPELL_INNER_FOCUS)
        hasInnerFocusBuff = true
    end

    -- If drinking mode is active, only heal in emergencies
    if isDrinkingMode then
        if mana >= DRINKING_MANA_THRESHOLD then
            isDrinkingMode = false
            return false
        end

        local lowestHealthUnit = nil
        local secondLowestHealthUnit = nil
        local lowestHealthPercent = EMERGENCY_HEALTH_THRESHOLD
        local secondLowestHealthPercent = EMERGENCY_HEALTH_THRESHOLD

        -- Check player health
        if not UnitIsDeadOrGhost("player") and IsUnitInRange("player") then
            local playerHealth = UnitHealth("player") / UnitHealthMax("player") * 100
            if playerHealth < lowestHealthPercent then
                secondLowestHealthUnit = lowestHealthUnit
                secondLowestHealthPercent = lowestHealthPercent
                lowestHealthUnit = "player"
                lowestHealthPercent = playerHealth
            elseif playerHealth < secondLowestHealthPercent then
                secondLowestHealthUnit = "player"
                secondLowestHealthPercent = playerHealth
            end
        end

        -- Check party members' health
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) and IsUnitInRange(partyMember) then
                local health = UnitHealth(partyMember) / UnitHealthMax(partyMember) * 100
                if health < lowestHealthPercent then
                    secondLowestHealthUnit = lowestHealthUnit
                    secondLowestHealthPercent = lowestHealthPercent
                    lowestHealthUnit = partyMember
                    lowestHealthPercent = health
                elseif health < secondLowestHealthPercent then
                    secondLowestHealthUnit = partyMember
                    secondLowestHealthPercent = health
                end
            end
        end

        -- Check raid members' health
        for i = 1, 40 do
            local raidMember = "raid" .. i
            if UnitExists(raidMember) and not UnitIsDeadOrGhost(raidMember) and IsUnitInRange(raidMember) then
                local health = UnitHealth(raidMember) / UnitHealthMax(raidMember) * 100
                if health < lowestHealthPercent then
                    secondLowestHealthUnit = lowestHealthUnit
                    secondLowestHealthPercent = lowestHealthPercent
                    lowestHealthUnit = raidMember
                    lowestHealthPercent = health
                elseif health < secondLowestHealthPercent then
                    secondLowestHealthUnit = raidMember
                    secondLowestHealthPercent = health
                end
            end
        end

        -- Heal the lowest or 2nd lowest health unit based on the mode
        local unitToHeal = healSecondLowest and secondLowestHealthUnit or lowestHealthUnit
        if unitToHeal and (healSecondLowest and secondLowestHealthPercent < EMERGENCY_HEALTH_THRESHOLD or lowestHealthPercent < EMERGENCY_HEALTH_THRESHOLD) then
            local SpellID, HealSize = QuickHeal_Priest_FindHealSpellToUse(unitToHeal, "channel", nil, false)
            if SpellID then
                CastSpellByName(GetSpellName(SpellID, BOOKTYPE_SPELL))
                SpellTargetUnit(unitToHeal)
                return true
            end
        end

        return false
    else
        -- Normal healing logic (not in drinking mode)

        -- Track the two lowest health units for QuickHeal library
        local lowestHealthUnit = nil
        local secondLowestHealthUnit = nil
        local lowestHealthPercent = 100
        local secondLowestHealthPercent = 100

        -- Check player health
        if not UnitIsDeadOrGhost("player") and IsUnitInRange("player") then
            local playerHealth = UnitHealth("player") / UnitHealthMax("player") * 100
            if playerHealth < lowestHealthPercent then
                secondLowestHealthUnit = lowestHealthUnit
                secondLowestHealthPercent = lowestHealthPercent
                lowestHealthUnit = "player"
                lowestHealthPercent = playerHealth
            elseif playerHealth < secondLowestHealthPercent then
                secondLowestHealthUnit = "player"
                secondLowestHealthPercent = playerHealth
            end
        end

        -- Check party members' health
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) and IsUnitInRange(partyMember) then
                local health = UnitHealth(partyMember) / UnitHealthMax(partyMember) * 100
                if health < lowestHealthPercent then
                    secondLowestHealthUnit = lowestHealthUnit
                    secondLowestHealthPercent = lowestHealthPercent
                    lowestHealthUnit = partyMember
                    lowestHealthPercent = health
                elseif health < secondLowestHealthPercent then
                    secondLowestHealthUnit = partyMember
                    secondLowestHealthPercent = health
                end
            end
        end

        -- Check raid members' health
        for i = 1, 40 do
            local raidMember = "raid" .. i
            if UnitExists(raidMember) and not UnitIsDeadOrGhost(raidMember) and IsUnitInRange(raidMember) then
                local health = UnitHealth(raidMember) / UnitHealthMax(raidMember) * 100
                if health < lowestHealthPercent then
                    secondLowestHealthUnit = lowestHealthUnit
                    secondLowestHealthPercent = lowestHealthPercent
                    lowestHealthUnit = raidMember
                    lowestHealthPercent = health
                elseif health < secondLowestHealthPercent then
                    secondLowestHealthUnit = raidMember
                    secondLowestHealthPercent = health
                end
            end
        end

        -- If Inner Focus buff is active, skip Renew and Power Word: Shield
        if not hasInnerFocusBuff then
            -- Proactively cast Renew on players under 90% health
            local unitsToCheck = {"player", "party1", "party2", "party3", "party4"}
            for i = 1, 40 do
                table.insert(unitsToCheck, "raid" .. i)
            end
            for _, unit in ipairs(unitsToCheck) do
                if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsUnitInRange(unit) then
                    local health = UnitHealth(unit) / UnitHealthMax(unit) * 100
                    if health < 90 and mana > BANDAIDS_MANA_THRESHOLD and not buffed(SPELL_RENEW, unit) then
                        CastSpellByName(SPELL_RENEW)
                        SpellTargetUnit(unit)
                        return true
                    end
                end
            end

            -- Cast Power Word: Shield on players under 80% health
            for _, unit in ipairs(unitsToCheck) do
                if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsUnitInRange(unit) then
                    local health = UnitHealth(unit) / UnitHealthMax(unit) * 100
                    if health < 80 and mana > BANDAIDS_MANA_THRESHOLD and not buffed(SPELL_PWS, unit) and not HasDebuff(unit, PWS_DEBUFF) and UnitAffectingCombat("player") then
                        local spellIndex = GetSpellIndex(SPELL_PWS)
                        if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                            CastSpellByName(SPELL_PWS)
                            SpellTargetUnit(unit)
                            return true
                        end
                    end
                end
            end
        end

        -- Use QuickHeal library for the lowest or 2nd lowest health unit under 75% health
        local unitToHeal = healSecondLowest and secondLowestHealthUnit or lowestHealthUnit
        if unitToHeal and (healSecondLowest and secondLowestHealthPercent < 75 or lowestHealthPercent < 75) then
            local SpellID, HealSize = QuickHeal_Priest_FindHealSpellToUse(unitToHeal, "channel", nil, false)
            if SpellID then
                CastSpellByName(GetSpellName(SpellID, BOOKTYPE_SPELL))
                SpellTargetUnit(unitToHeal)
                return true
            end
        end

        return false
    end
end

local function AssistPartyMember()
    if mounted then
        return
    end
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100
    local currentTime = GetTime()

    if enableSmiteMode then
        -- Smite mode: Only use Smite to assist, and wand if mana is below 75%
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) then
                local target = partyMember .. "target"
                if UnitExists(target) and UnitCanAttack("player", target) then
                    AssistUnit(partyMember)

                    -- If mana is above 75%, cast Smite
                    if mana > 75 then
                        local smiteSpellIndex = GetSpellIndex(SPELL_SMITE)
                        if smiteSpellIndex and GetSpellCooldown(smiteSpellIndex, BOOKTYPE_SPELL) < 1 then
                            ToggleShootOff()
                            CastSpellByName(SPELL_SMITE)
                            lastShootToggleTime = currentTime
                            return
                        end
                    else
                        -- If mana is below 75%, toggle wand (Shoot)
                        if IsShootActive() and (currentTime - lastShootToggleTime) >= SHOOT_TOGGLE_COOLDOWN then
                            ToggleShootOff()
                            lastShootToggleTime = currentTime
                        elseif not IsShootActive() then
                            CastSpellByName(SPELL_SHOOT)
                            lastShootToggleTime = currentTime
                        end
                    end
                end
            end
        end
    else
        -- Original assist mode logic
        local hasMindFlay = GetSpellIndex("Mind Flay") ~= nil

        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) then
                local target = partyMember .. "target"
                if UnitExists(target) and UnitCanAttack("player", target) then
                    AssistUnit(partyMember)

                    -- Apply Shadow Word: Pain if mana is sufficient
                    if mana > 75 and not buffed(SPELL_SWP, target) then
                        CastSpellByName(SPELL_SWP2)
                    end

                    -- Cast Mind Blast if Shadow Word: Pain is active and Mind Blast is off cooldown
                    if buffed(SPELL_SWP, target) then
                        local spellIndex = GetSpellIndex(SPELL_MIND_BLAST)
                        if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                            ToggleShootOff()
                            CastSpellByName(SPELL_MIND_BLAST2)
                            lastShootToggleTime = currentTime
                            return
                        end
                    end

                    -- Cast Mind Flay if Shadow Word: Pain is active, Mind Blast is on cooldown, and Mind Flay is available
                    if buffed(SPELL_SWP, target) and hasMindFlay then
                        local spellIndex = GetSpellIndex(SPELL_MIND_BLAST)
                        if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) > 1 and (currentTime - lastFlayTime) >= FLAY_DURATION then
                            ToggleShootOff()
                            CastSpellByName(SPELL_MIND_FLAY)
                            master_follow = false
                            lastFlayTime = currentTime
                            lastShootToggleTime = currentTime
                            return
                        end
                    end

                    -- Toggle Shoot if Mind Flay is not available or not used
                    if IsShootActive() and (currentTime - lastShootToggleTime) >= SHOOT_TOGGLE_COOLDOWN then
                        ToggleShootOff()
                        lastShootToggleTime = currentTime
                    elseif not IsShootActive() and (not hasMindFlay or (currentTime - lastFlayTime) >= FLAY_DURATION) then
                        CastSpellByName(SPELL_SHOOT)
                        lastShootToggleTime = currentTime
                    end
                end
            end
        end
    end
end

local function FollowPartyMember()
    if not isDrinkingNow and enableFollow then  -- Only follow if follow is enabled
        if UnitIsDead("Player") then
            FollowByName(leader, exactMatch)
        end
        if not master_follow and not CheckDrinkBuff() then
            FollowByName(leader, exactMatch)
            master_follow = true
        end

        local mana = (UnitMana("player") / UnitManaMax("player")) * 100
        if mana > DRINKING_MANA_THRESHOLD then
            master_drink = false
        end
        if master_drink then
            return
        end

        CheckDrinkBuff()

        -- If drinking mode is active, only heal in emergencies
        if isDrinkingMode then
            if mana >= DRINKING_MANA_THRESHOLD then
                isDrinkingMode = false
                return false
            end
        end

        if not isDrinkingMode and not master_drink and not CheckDrinkBuff() then
            FollowByName(leader, exactMatch)
            master_follow = true
        end
    end
end

-- Function to handle out of mana logic
local function OOM()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    if mana < 40 and UnitAffectingCombat("player") then
        if UseManaPotion() then
            return
        end
    end

    CheckDrinkBuff()

    -- If drinking mode is active and mana is above the drinking threshold, stop drinking
    if isDrinkingMode and mana >= DRINKING_MANA_THRESHOLD then
        isDrinkingMode = false
        return
    end

    -- If mana is critically low (below 10%), drink immediately
    if mana <= LOW_MANA_THRESHOLD and not UnitAffectingCombat("player") then
        if not HasBuff("player", drinkBuffs) then
            if not isDrinkingNow then
                isDrinkingNow = true
            end
            for b = 0, 4 do
                for s = 1, GetContainerNumSlots(b) do
                    local itemLink = GetContainerItemLink(b, s)
                    if itemLink then
                        for _, drink in ipairs(drinkstodrink) do
                            if strfind(itemLink, drink) then
                                UseContainerItem(b, s)
                                isDrinkingMode = true
                                master_drink = true
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    -- If mana is below 80%, drink
    if master_buff then
        return false
    end

    if mana > LOW_MANA_THRESHOLD and mana < START_DRINKING_MANA_THRESHOLD and not UnitAffectingCombat("player") then
        if master_buff then
            return
        end
        if not HasBuff("player", drinkBuffs) then
            if not isDrinkingNow then
                isDrinkingNow = true
            end
            for b = 0, 4 do
                for s = 1, GetContainerNumSlots(b) do
                    local itemLink = GetContainerItemLink(b, s)
                    if itemLink then
                        for _, drink in ipairs(drinkstodrink) do
                            if strfind(itemLink, drink) then
                                UseContainerItem(b, s)
                                isDrinkingMode = true
                                master_drink = true
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    -- If mana is critically low during combat, use Quel'dorei Meditation
    if mana < QDM_POT_MANA_THRESHOLD and UnitAffectingCombat("player") and not HasBuff("player", drinkBuffs) then
        local c, s = CastSpellByName, SPELL_QDM
        local i = nil
        for j = 1, 180 do
            local n = GetSpellName(j, BOOKTYPE_SPELL)
            if n and strfind(n, s) then
                i = j
                break
            end
        end
        if i then
            if GetSpellCooldown(i, BOOKTYPE_SPELL) < 1 then
                c(s)
            end
        end
    end

    -- Announce low mana during combat
    if UnitAffectingCombat("player") and mana < MANA_ANNOUNCEMENT_THRESHOLD and not hasAnnouncedDrinking then
        SendChatMessage("LOW MANA -- I need to drink after combat!", "PARTY")
        hasAnnouncedDrinking = true
    end
end

local function mountedSanity()
    local playerHasBuffSanity = buffed(myMount, "player")
    if playerHasBuffSanity then
        mounted = true
    else
        mounted = false
    end
end

-- Function to check if the player is drinking and update the drinking state
local function isDrinkingSanity()
    if HasBuff("player", drinkBuffs) then
        isDrinkingNow = true
    else
        isDrinkingNow = false
    end
end

-- Function to check if the player is in combat and update the combat state
local function isCombatSanity()
    if UnitAffectingCombat("player") then
        inCombat = true
    else
        inCombat = false
    end
end

local function MountWithRele()
    CheckDrinkBuff()
    -- Target leader (exact match)
    if not master_buff then
        TargetByName(leader, true)

        -- Check if the target is valid and is leader
        if UnitExists("target") and UnitIsPlayer("target") and UnitName("target") == leader then
            -- Check if leader has the leaderMount buff
            local releHasBuff = buffed(leaderMount, "target")

            -- Check if you have the leaderMount buff
            local playerHasBuff = buffed(myMount, "player")

            -- If leader has the buff and you don't, mount up
            if releHasBuff and not playerHasBuff then
                local spellIndex = GetSpellIndex(myMount)
                if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                    CastSpellByName(myMount)
                    mounted = true
                end
            -- If leader does not have the buff and you do, dismount
            elseif not releHasBuff and playerHasBuff then
                local spellIndex = GetSpellIndex(myMount)
                if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                    CastSpellByName(myMount)
                    mounted = false
                end
            end
        end

        -- Clear the target after checking
        ClearTarget()
    end
end

-- Event handler to reset the announcement flag when combat ends
local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        hasAnnouncedDrinking = false
        lastDispelTime = 0
        lastCureDiseaseTime = 0
    end
end

-- Helper function to check for dead party members and resurrect them
local function ResurrectDeadPartyMembers()
    -- Check if the player is in combat or drinking
    if UnitAffectingCombat("player") or isDrinkingNow then
        return false
    end

    -- Check if the player has the "Resurrection" spell
    local resurrectionSpell = "Resurrection"
    local spellIndex = GetSpellIndex(resurrectionSpell)
    if not spellIndex then
        return false
    end

    -- Check if the spell is on cooldown
    local startTime, duration = GetSpellCooldown(spellIndex, BOOKTYPE_SPELL)
    if startTime > 0 and duration > 0 then
        return false
    end

    -- Iterate through party members
    for i = 1, 4 do
        local partyMember = "party" .. i
        if UnitExists(partyMember) and UnitIsDeadOrGhost(partyMember) then
            -- Check if the party member is in range
            if CheckInteractDistance(partyMember, 4) then
                -- Cast Resurrection on the dead party member
                CastSpellByName(resurrectionSpell)
                SpellTargetUnit(partyMember)
                return true
            end
        end
    end

    -- Iterate through raid members
    for i = 1, 40 do
        local raidMember = "raid" .. i
        if UnitExists(raidMember) and UnitIsDeadOrGhost(raidMember) then
            -- Check if the raid member is in range
            if CheckInteractDistance(raidMember, 4) then
                -- Cast Resurrection on the dead raid member
                CastSpellByName(resurrectionSpell)
                SpellTargetUnit(raidMember)
                return true
            end
        end
    end

    return false
end

-- Helper function to accept resurrection when dead
local function AcceptResurrection()
    -- Check if the player is dead or a ghost
    if not UnitIsDeadOrGhost("player") then
        return false
    end

    -- Check if a resurrection popup is active
    local resurrectionFrame = StaticPopup_Visible("RESURRECT")
    if resurrectionFrame then
        -- Accept the resurrection
        StaticPopup_OnClick(StaticPopup_FindVisible("RESURRECT"), 1)
        return true
    end

    return false
end



-- Function to log boolean variables for debugging
local function LogBooleanVariables()
    local booleanVariables = {
        master_drink = master_drink,
        inCombat = inCombat,
        isDrinkingMode = isDrinkingMode,
        isDrinkingNow = isDrinkingNow,
        master_buff = master_buff,
        mounted = mounted,
        buffThrottle = buffThrottle,
        master_follow = master_follow,
        champGraceBuffed = champGraceBuffed,
        champProclaimed = champProclaimed,
        hasAnnouncedDrinking = hasAnnouncedDrinking,
    }

    print("------start-variable-dump--------")
    for varName, varValue in pairs(booleanVariables) do
        print(varName .. ": " .. tostring(varValue))
    end
    print("---------------------------------")
end

-- Create a frame to listen for combat events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", OnEvent)

-- Slash command to toggle assist mode
SLASH_HERESY_ASSIST1 = "/heresyassist"
SlashCmdList["HERESY_ASSIST"] = function()
    assistmode = assistmode == 1 and 0 or 1
    if assistmode == 1 then
        print("Assist mode is now ON.")
    else
        print("Assist mode is now OFF.")
    end
end

-- Slash command to designate the champion
SLASH_HERESY_CHAMP1 = "/heresy-champ"
SlashCmdList["HERESY_CHAMP"] = function()
    if UnitExists("target") and UnitIsPlayer("target") then
        championName = UnitName("target")
        leader = UnitName("target")
        print("" .. championName .. " has been designated as the champion!")
    else
        championName = nil
    end
end

-- Slash command to reset the last buff complete time and allow manual rebuffing
SLASH_HERESY_REBUFF1 = "/heresy-rebuff"
SlashCmdList["HERESY_REBUFF"] = function()
    lastBuffCompleteTime = 0
    champGraceBuffed = false
    champProclaimed = false
    isDrinkingMode = false
    isDrinkingNow = false
    CheckDrinkBuff()
    BuffParty() -- Immediately attempt to rebuff
    FollowPartyMember()
end

-- Slash command to toggle Shadow Protection
SLASH_HERESY_SHADOWPROT1 = "/heresy-shadowprot"
SlashCmdList["HERESY_SHADOWPROT"] = function()
    enableShadowProtection = not enableShadowProtection
    if enableShadowProtection then
        print("Shadow Protection is now ENABLED.")
    else
        print("Shadow Protection is now DISABLED.")
    end
end

-- Slash command to toggle Fear Ward
SLASH_HERESY_FEARWARD1 = "/heresy-fearward"
SlashCmdList["HERESY_FEARWARD"] = function()
    enableFearWard = not enableFearWard
    if enableFearWard then
        print("Fear Ward is now ENABLED.")
    else
        print("Fear Ward is now DISABLED.")
    end
end

-- Slash command to toggle follow functionality
SLASH_HERESY_FOLLOW1 = "/heresy-follow"
SlashCmdList["HERESY_FOLLOW"] = function()
    enableFollow = not enableFollow
    if enableFollow then
        print("Follow functionality is now ENABLED.")
    else
        print("Follow functionality is now DISABLED.")
    end
end

-- Slash command to toggle champion buffing
SLASH_HERESY_CHAMPIONBUFF1 = "/heresy-championbuff"
SlashCmdList["HERESY_CHAMPIONBUFF"] = function()
    enableChampionBuff = not enableChampionBuff
    if enableChampionBuff then
        print("Champion buffing is now ENABLED.")
    else
        print("Champion buffing is now DISABLED.")
    end
end

-- Slash command to toggle healing the 2nd lowest member
SLASH_HERESY_HEALSECONDLOWEST1 = "/heresy-healsecondlowest"
SlashCmdList["HERESY_HEALSECONDLOWEST"] = function()
    healSecondLowest = not healSecondLowest
    if healSecondLowest then
        print("Healing the 2nd lowest member is now ENABLED.")
    else
        print("Healing the 2nd lowest member is now DISABLED.")
    end
end

-- Slash command to toggle Smite mode
SLASH_HERESY_SMITE1 = "/heresy-smite"
SlashCmdList["HERESY_SMITE"] = function()
    enableSmiteMode = not enableSmiteMode
    if enableSmiteMode then
        print("Smite mode is now ENABLED.")
    else
        print("Smite mode is now DISABLED.")
    end
end

SLASH_HERESY1 = "/heresy"
SlashCmdList["HERESY"] = function()
    -- Priority 1: Check for high-priority debuffs ("Shaman_Hex" and "Polymorph") and dispel them immediately
    local highPriorityDebuffFound = DispelHighPriorityDebuffs()
    if highPriorityDebuffFound then
        return -- Exit early if a high-priority debuff was dispelled
    end
    if UnitIsDead("Player") then
        FollowPartyMember()
    end

    mountedSanity()
    buffThrottleCheck()
    isDrinkingSanity()
    isCombatSanity()

    if master_drink and UnitAffectingCombat("player") then
        master_drink = false
    end
    if master_buff and UnitAffectingCombat("player") then
        master_buff = false
    end


    -- Priority 2: Healing (only if no high-priority debuffs were found)
    local healingNeeded = HealParty()

    -- Priority 3: Other dispels and curing diseases
    DispelParty()
    CureDiseaseParty()

    -- Priority 4: Out of mana logic
    OOM()

    if not healingNeeded then
        local mana = (UnitMana("player") / UnitManaMax("player")) * 100

        if not UnitAffectingCombat("player") then
            -- Buff Party
            if GetTime() - lastBuffCompleteTime >= BUFF_THROTTLE_DURATION and not isDrinkingNow then
                BuffParty()
                BuffPartyWithItems()
            end
            MountWithRele()
            ResurrectDeadPartyMembers()
        end

        if not isDrinkingNow then
            FollowPartyMember()
        end

        if assistmode == 1 then
            AssistPartyMember()
        end
        if UnitAffectingCombat("player") then
            isDrinkingNow = false
        end
    end
end