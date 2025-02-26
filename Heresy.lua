-- Addon Name
Heresy = {}

local master_buff = false
local master_drink = false
local master_follow = false
local championName = nil
local lastBuffCompleteTime = 0
local BUFF_THROTTLE_DURATION = 300 -- 10 minutes in seconds

-- Global variables for configuration
local isDrinkingMode = false
local DRINKING_MANA_THRESHOLD = 80 -- Stop drinking at this % mana
local START_DRINKING_MANA_THRESHOLD = 70 -- Start drinking at this % mana
local EMERGENCY_HEALTH_THRESHOLD = 40 -- Heal party members below this % health even while drinking
local HEALTH_THRESHOLD = 85 -- Heal if health is below this %
local BANDAIDS_MANA_THRESHOLD = 90 -- use shield and renew if my mana is above this %
local LOW_MANA_THRESHOLD = 10 -- Threshold for low mana
local CRITICAL_MANA_THRESHOLD = 15 -- Threshold for critical mana
local QDM_POT_MANA_THRESHOLD = 30 -- Threshold for QDM/POTS
local MANA_ANNOUNCEMENT_THRESHOLD = 40 -- Threshold for announcing low mana
local SHOOT_TOGGLE_COOLDOWN = 1.5 -- Toggle Shoot off after 1.5 seconds
local FLAY_DURATION = 3 -- Duration for Mind Flay

local assistmode = 0

-- Addon Constants
local SPELL_PWF = "Power Word: Fortitude"
local SPELL_SPIRIT = "Divine Spirit"
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
local SPELL_SWP2 = "Shadow Word: Pain(Rank 5)"
local SPELL_MIND_BLAST = "Mind Blast"
local SPELL_MIND_BLAST2 = "Mind Blast(Rank 5)"
local SPELL_MIND_FLAY = "Mind Flay"
local SPELL_QDM = "Quel'dorei Meditation"
local SPELL_PWS = "Power Word: Shield"
local SPELL_FADE = "Fade"
local SPELL_PSCREAM = "Psychic Scream"
local SPELL_INNER_FIRE = "Inner Fire"
local SPELL_DISPEL = "Dispel Magic"
local SPELL_CURE_DISEASE = "Cure Disease"
local SPELL_LEVITATE = "Levitate"

-- Timing variables for Shoot toggle
local lastShootToggleTime = 0
local lastFlayTime = 0

local drinkstodrink = {
    "Moonberry",
    "Sweet",
    "Melon",
    "Conjured",
}

local feathers = {
    "Light Feather",
}

local PWS_DEBUFF= {
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
    -- Add more debuff names here as needed
}

-- List of debuffs to cure with Cure Disease
local diseasesToCure = {
    "NullifyDisease",
    "CallofBone",
    "CreepingPlague",
    -- Add more disease debuff names here as needed
}

local drinkBuffs = {
    "INV_Drink",  -- Matches any buff with "INV_Drink" in its texture path
    "Drink",      -- Matches any buff with "Drink" in its name or texture path
    -- Add more partial patterns as needed
}

-- Table of mana potions to search for
local manaPotions = {
    "Mana Potion",
    "Greater Mana Potion",
    -- Add more mana potion names here as needed
}

local itemBuffMap = {
    -- Format: {itemName, buffName, targetType}
    ["Scroll of Intellect"] = {"Intellect", "mana"},       -- Only for mana users
    ["Scroll of Protection"] = {"Armor", "both"},         -- For all party members
    ["Scroll of Strength"] = {"Strength", "non-mana"},    -- Only for non-mana users
    ["Scroll of Strength"] = {"Agility", "non-mana"},    -- Only for non-mana users
}

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
    if not championName then
        return -- No champion designated
    end

    -- Check if the champion is in range and alive
    if not UnitExists("target") or not IsChampion("target") or UnitIsDeadOrGhost("target") then
        TargetByName(championName, true) -- Target the champion
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
            print("Heresy: Casting Proclaim Champion on " .. championName)
            return
        else
            print("Heresy: Proclaim Champion is on cooldown.")
            return
        end
    end

    -- Cast "Champion's Grace" if the champion has "Holy Champion"
    if hasHolyChampion and not buffed("Champion's Grace", "target") then
        CastSpellByName("Champion's Grace")
        SpellTargetUnit("target")
        print("Heresy: Casting Champion's Grace on " .. championName)
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

local function HasItemBuff(unit, buffName)
    for i = 1, 16 do
        local name = UnitBuff(unit, i)
        if name and strfind(name, buffName) then
            return true
        end
    end
    return false
end

-- Helper function to check for Drink Buffs
local function CheckDrinkBuff()
    if not HasBuff("player", drinkBuffs) then
        isDrinkingMode = false
        master_drink = false
        --print("Heresy: drink buff not found, setting drink mode false")
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

-- Function to search bags for mana potions and use one when mana is below 40%
local function UseManaPotion()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    -- Check if mana is below 40%
    if mana < 40 then
        -- Search through all bags
        for b = 0, 4 do
            for s = 1, GetContainerNumSlots(b) do
                local itemLink = GetContainerItemLink(b, s)
                if itemLink then
                    -- Check if the item is in the mana potions table
                    for _, potion in ipairs(manaPotions) do
                        if strfind(itemLink, potion) then
                            -- Check if the item is off cooldown
                            local startTime, duration, isEnabled = GetContainerItemCooldown(b, s)
                            if startTime == 0 and duration == 0 then
                                -- Use the mana potion
                                UseContainerItem(b, s)
                                print("Heresy: Using " .. potion .. " to restore mana.")
                                return true
                            else
                                print("Heresy: " .. potion .. " is on cooldown.")
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

-- end mana pot

-- Function to buff a unit with Power Word: Fortitude and Divine Spirit
local function BuffUnit(unit)
    if BuffUnitWithSpell(unit, SPELL_PWF) then
        return true
    end
    if BuffUnitWithSpell(unit, SPELL_SPIRIT) then
        return true
    end
    return false
end

-- Function to check if all buffing is complete
local function IsBuffingComplete()
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

-- Function to dispel a unit with Dispel Magic
local function DispelUnit(unit)
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
        CastSpellByName(SPELL_DISPEL)
        SpellTargetUnit(unit)
        return true
    end
    return false
end

-- Function to cure a unit with Cure Disease
local function CureDiseaseUnit(unit)
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
        CastSpellByName(SPELL_CURE_DISEASE)
        SpellTargetUnit(unit)
        return true
    end
    return false
end

-- Function to buff Inner Fire on the player
local function BuffInnerFire()
    if not buffed(SPELL_INNER_FIRE, "player") then
        CastSpellByName(SPELL_INNER_FIRE)
    end
end

-- Function to buff party members and the champion
local function BuffParty()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    -- Check if buffing is throttled
    if GetTime() - lastBuffCompleteTime < BUFF_THROTTLE_DURATION then
        print("Heresy: Buffing is throttled. Skipping buff routine.")
        return false
    end

    if mana > DRINKING_MANA_THRESHOLD then
        master_drink = false
    end
    if master_drink then
        return false
    end
    CheckDrinkBuff()

    -- Do not buff if drinking mode is active
    if isDrinkingMode then
        print("Heresy: buffparty: drink mode true, not buffing")
        return false
    end

    -- Do not buff if mana is critically low
    if mana <= LOW_MANA_THRESHOLD then
        print("Heresy: buffparty: mana critical, not buffing")
        return false
    end


    -- Buff the player
    if BuffUnit("player") then
        return false
    end

    -- Buff party members
    for i = 1, 4 do
        local partyMember = "party" .. i
        if BuffUnit(partyMember) then
            return false
        end
    end
    -- Buff the champion first
    BuffChampion()

    -- If no buffing was needed, set the last buff complete time
    lastBuffCompleteTime = GetTime()
    print("Heresy: Buffing complete. Throttling for 10 minutes.")
    return true
end

-- end BUFPARTY function

-- buff with scrolls if available
local function BuffPartyWithItems()
    for itemName, itemData in pairs(itemBuffMap) do
        local buffName = itemData[1]
        local targetType = itemData[2]

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
                            if not HasItemBuff("player", buffName) then
                                UseContainerItem(b, s)
                                SpellTargetUnit("player")
                                print("Heresy: Using " .. itemLink .. " to buff player with " .. buffName)
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

                                -- Apply the buff if the party member should receive it and doesn't already have it
                                if shouldBuff and not HasItemBuff(partyMember, buffName) then
                                    UseContainerItem(b, s)
                                    SpellTargetUnit(partyMember)
                                    print("Heresy: Using " .. itemLink .. " to buff " .. UnitName(partyMember) .. " with " .. buffName)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- end buff scrolls

-- Function to dispel debuffs from party members and myself
local function DispelParty()
    if HasDebuff("player", debuffsToDispel) then
        if UnitExists("target") and UnitCanAttack("player", "target") then
            ClearTarget()
        end
        if DispelUnit("player") then
            return
        end
    end

    for i = 1, 4 do
        local partyMember = "party" .. i
        if HasDebuff(partyMember, debuffsToDispel) then
            if UnitExists("target") and UnitCanAttack("player", "target") then
                ClearTarget()
            end
            if DispelUnit(partyMember) then
                return
            end
        end
    end
end

-- Function to cure diseases from party members and myself
local function CureDiseaseParty()
    if HasDebuff("player", diseasesToCure) then
        if UnitExists("target") and UnitCanAttack("player", "target") then
            ClearTarget()
        end
        if CureDiseaseUnit("player") then
            return
        end
    end

    for i = 1, 4 do
        local partyMember = "party" .. i
        if HasDebuff(partyMember, diseasesToCure) then
            if UnitExists("target") and UnitCanAttack("player", "target") then
                ClearTarget()
            end
            if CureDiseaseUnit(partyMember) then
                return
            end
        end
    end
end

-- Function to heal party members
local function HealParty()
    if master_buff then
        print("Heresy: we are buffing, not healing yet")
        return false
    end

    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    CheckDrinkBuff()

    -- If drinking mode is active, only heal in emergencies
    if isDrinkingMode then
        if mana >= DRINKING_MANA_THRESHOLD then
            isDrinkingMode = false
            print("Heresy: healparty: drink mode set false")
            return false
        end

        local lowestHealthUnit = nil
        local lowestHealthPercent = EMERGENCY_HEALTH_THRESHOLD

        -- Check player health
        if not UnitIsDeadOrGhost("player") and IsUnitInRange("player") then
            local playerHealth = UnitHealth("player") / UnitHealthMax("player") * 100
            if playerHealth < lowestHealthPercent then
                lowestHealthUnit = "player"
                lowestHealthPercent = playerHealth
            end
        end

        -- Check party members' health
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) and IsUnitInRange(partyMember) then
                local health = UnitHealth(partyMember) / UnitHealthMax(partyMember) * 100
                if health < lowestHealthPercent then
                    lowestHealthUnit = partyMember
                    lowestHealthPercent = health
                end
            end
        end

        -- Heal the lowest health unit if below emergency threshold
        if lowestHealthUnit and lowestHealthPercent < EMERGENCY_HEALTH_THRESHOLD then
            local SpellID, HealSize = QuickHeal_Priest_FindHealSpellToUse(lowestHealthUnit, "channel", nil, false)
            if SpellID then
                CastSpellByName(GetSpellName(SpellID, BOOKTYPE_SPELL))
                SpellTargetUnit(lowestHealthUnit)
                return true
            end
        end

        return false
    else
        -- Normal healing logic (not in drinking mode)
        local lowestHealthUnit = nil
        local lowestHealthPercent = HEALTH_THRESHOLD

        -- Check player health
        if not UnitIsDeadOrGhost("player") and IsUnitInRange("player") then
            local playerHealth = UnitHealth("player") / UnitHealthMax("player") * 100
            if playerHealth < lowestHealthPercent then
                lowestHealthUnit = "player"
                lowestHealthPercent = playerHealth
            end
        end

        -- Check party members' health
        for i = 1, 4 do
            local partyMember = "party" .. i
            if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) and IsUnitInRange(partyMember) then
                local health = UnitHealth(partyMember) / UnitHealthMax(partyMember) * 100
                if health < lowestHealthPercent then
                    lowestHealthUnit = partyMember
                    lowestHealthPercent = health
                end
            end
        end

        -- Heal the lowest health unit
        if lowestHealthUnit then

           -- If my mana is above bandaids threshold % and PWS is not on CD, and the target is not already buffed with PWS or weakened soul, and i'm in combat, then cast PWS
            local spellIndex = GetSpellIndex(SPELL_PWS)
            -- local pws_currentTime = GetTime()


            -- If mana is above 90% and the target is not already buffed with Renew, cast Renew
            if mana > BANDAIDS_MANA_THRESHOLD and not buffed(SPELL_RENEW, lowestHealthUnit) then
                CastSpellByName(SPELL_RENEW)
                SpellTargetUnit(lowestHealthUnit)
            --    pwscheck_time = pws_currentTime
            --    pwscheck_health = lowestHealthPercent
            --    pwscheck_unit = lowestHealthUnit
                return true
            end

            if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 and mana > BANDAIDS_MANA_THRESHOLD and not buffed(SPELL_PWS, lowestHealthUnit) and not HasDebuff(lowestHealthUnit, PWS_DEBUFF) and UnitAffectingCombat("player") then
                CastSpellByName(SPELL_PWS)
                SpellTargetUnit(lowestHealthUnit)
                return true
            end


            local SpellID, HealSize = QuickHeal_Priest_FindHealSpellToUse(lowestHealthUnit, "channel", nil, false)
            if SpellID then
                CastSpellByName(GetSpellName(SpellID, BOOKTYPE_SPELL))
                SpellTargetUnit(lowestHealthUnit)
                return true
            end
        end

        return false
    end
end

-- end HEALPARTY function

-- Function to assist a party member by casting Smite on their target
local function AssistPartyMember()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100
    local currentTime = GetTime()

    -- Check if "Mind Flay" is in the spell book
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

-- Function to follow a party member
local function FollowPartyMember()
    if not master_follow then
        FollowByName("Rele", exactMatch)
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
            print("Heresy: follow function: drinkmode set false")
            return false
        end
    end

    if not isDrinkingMode and not master_drink then
        FollowByName("Rele", exactMatch)
        master_follow = true
        -- print("Heresy: following executed")
    end

end


-- Add a flag to track if the drinking announcement has been made during the current combat
local hasAnnouncedDrinking = false

-- Function to handle out of mana logic
-- Function to handle out of mana logic
local function OOM()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    if mana < 40 then
            if UseManaPotion() then
            return
        end
    end

    CheckDrinkBuff()

    -- If drinking mode is active and mana is above the drinking threshold, stop drinking
    if isDrinkingMode and mana >= DRINKING_MANA_THRESHOLD then
        isDrinkingMode = false
        print("Heresy: OOM function, drink mode set false")
        return
    end

    -- If mana is critically low (below 10%), drink immediately
    if mana <= LOW_MANA_THRESHOLD and not UnitAffectingCombat("player") then
        if not HasBuff("player", drinkBuffs) then
            -- SendChatMessage("Heresy: CRITICALLY LOW MANA -- Drinking immediately...", "PARTY")
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
        print("Heresy: we are buffing, skipping drink")
        return false
    end

    if mana > LOW_MANA_THRESHOLD and mana < START_DRINKING_MANA_THRESHOLD and not UnitAffectingCombat("player") then
        if master_buff then
            return
        end
        if not HasBuff("player", drinkBuffs) then
            -- SendChatMessage("Heresy: LOW MANA -- Drinking...", "PARTY")
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
        SendChatMessage("Heresy: LOW MANA -- I need to drink after combat!", "PARTY")
        hasAnnouncedDrinking = true
    end
end

-- end of OOM function

-- levitate function for style :)
local function Levitate()
            for b = 0, 4 do
                for s = 1, GetContainerNumSlots(b) do
                    local itemLink = GetContainerItemLink(b, s)
                    if itemLink then
                        for _, feather in ipairs(feathers) do
                            if strfind(itemLink, feather) then
                                if not buffed("Levitate", "player") then
                                    CastSpellByName(SPELL_LEVITATE)
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end


-- end levitate 





-- Function to check if "Rele" has the "Thalassian Unicorn" buff and mount/dismount accordingly
local function MountWithRele()
    -- Target "Rele" (exact match)
    if not master_buff then
    TargetByName("Rele", true)

    -- Check if the target is valid and is "Rele"
    if UnitExists("target") and UnitIsPlayer("target") and UnitName("target") == "Rele" then
        -- Check if "Rele" has the "Thalassian Unicorn" buff
        local releHasBuff = buffed("Thalassian Unicorn", "target")

        -- Check if you have the "Thalassian Unicorn" buff
        local playerHasBuff = buffed("Thalassian Unicorn", "player")

        -- If "Rele" has the buff and you don't, mount up
        if releHasBuff and not playerHasBuff then
            local spellIndex = GetSpellIndex("Thalassian Unicorn")
            if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                CastSpellByName("Thalassian Unicorn")
                print("Heresy: Mounting up with Thalassian Unicorn.")
            else
                print("Heresy: Thalassian Unicorn is on cooldown.")
            end
        -- If "Rele" does not have the buff and you do, dismount
        elseif not releHasBuff and playerHasBuff then
            local spellIndex = GetSpellIndex("Thalassian Unicorn")
            if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                CastSpellByName("Thalassian Unicorn")
                print("Heresy: Dismounting Thalassian Unicorn.")
            else
                print("Heresy: Thalassian Unicorn is on cooldown.")
            end
        end
    else
        print("Heresy: Rele is not found or is not a valid target.")
    end

    -- Clear the target after checking
    ClearTarget()
    end
end

-- end mount function

-- Event handler to reset the announcement flag when combat ends
local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        hasAnnouncedDrinking = false
    end
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
        print("Heresy: Assist mode is now ON.")
    else
        print("Heresy: Assist mode is now OFF.")
    end
end

-- Slash command to designate the champion
SLASH_HERESY_CHAMP1 = "/heresy-champ"
SlashCmdList["HERESY_CHAMP"] = function()
    if UnitExists("target") and UnitIsPlayer("target") then
        championName = UnitName("target")
        print("Heresy: " .. championName .. " has been designated as the champion!")
        SendChatMessage("Heresy: " .. championName .. " has been designated as the champion!", "PARTY")

    else
        championName = nil
        print("Heresy: You must target a player to designate them as the champion.")
    end
end

-- Slash command to reset the last buff complete time and allow manual rebuffing
SLASH_HERESY_REBUFF1 = "/heresy-rebuff"
SlashCmdList["HERESY_REBUFF"] = function()
    lastBuffCompleteTime = 0
    print("Heresy: Buffing throttle reset. Attempting to rebuff now.")
    BuffParty() -- Immediately attempt to rebuff
end

-- Main heresy slash command
SLASH_HERESY1 = "/heresy"
SlashCmdList["HERESY"] = function()
    if master_drink and UnitAffectingCombat("player") then
        print("Heresy: canceling drinkmode due to combat")
        master_drink = false
    end
    if master_buff and UnitAffectingCombat("player") then
        print("Heresy: canceling buffmode due to combat")
        master_buff = false
    end

    local healingNeeded = HealParty()
    DispelParty()
    CureDiseaseParty()
    OOM()

    if not healingNeeded then
        local mana = (UnitMana("player") / UnitManaMax("player")) * 100


            if not UnitAffectingCombat("player") then

            -- Buff Party
                if GetTime() - lastBuffCompleteTime >= BUFF_THROTTLE_DURATION then
                    BuffParty()
                end
                BuffInnerFire()
                --Levitate()
                MountWithRele()
            end

            BuffPartyWithItems()
            FollowPartyMember()



        if assistmode == 1 then
            AssistPartyMember()
        end
    end
end