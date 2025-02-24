-- Addon Name
Heresy = {}

local master_buff = false
local master_heal = false
local master_drink = false

-- Global variables for configuration
local isDrinkingMode = false
local DRINKING_MANA_THRESHOLD = 80 -- Stop drinking at 80% mana
local EMERGENCY_HEALTH_THRESHOLD = 30 -- Heal party members below 30% health even while drinking
local HEALTH_THRESHOLD = 70 -- Heal if health is below 70%
local LOW_MANA_THRESHOLD = 10 -- Threshold for low mana
local CRITICAL_MANA_THRESHOLD = 15 -- Threshold for critical mana
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

-- Timing variables for Shoot toggle
local lastShootToggleTime = 0
local lastFlayTime = 0

local drinkstodrink = {
    "Sweet",
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
    -- Add more debuff names here as needed
}

-- List of debuffs to cure with Cure Disease
local diseasesToCure = {
    "NullifyDisease",
    "CallofBone",
    -- Add more disease debuff names here as needed
}

local drinkBuffs = {
    "INV_Drink",  -- Matches any buff with "INV_Drink" in its texture path
    "Drink",      -- Matches any buff with "Drink" in its name or texture path
    -- Add more partial patterns as needed
}

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
        --print("Heresy: drink buff not found, setting drink mode false")
    end
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

-- Function to buff party members
-- Function to buff party members
-- Function to buff party members
local function BuffParty()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100
    if mana > DRINKING_MANA_THRESHOLD then
        master_drink = false
    end
    if master_drink then
        return
    end
    CheckDrinkBuff()

    -- Do not buff if drinking mode is active
    if isDrinkingMode then
        print("Heresy: buffparty: drink mode true, not buffing")
        return
    end

    -- Do not buff if mana is critically low
    if mana <= LOW_MANA_THRESHOLD then
        print("Heresy: buffparty: mana critical, not buffing")
        return
    end

    -- Buff the player
    if BuffUnit("player") then
        return
    end

    -- Buff party members
    for i = 1, 4 do
        local partyMember = "party" .. i
        if BuffUnit(partyMember) then
            return
        end
    end
end

-- end BUFPARTY function


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
-- Function to heal party members
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
        local lowestHealthPercent = 90

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

    for i = 1, 4 do
        local partyMember = "party" .. i
        if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) then
            local target = partyMember .. "target"
            if UnitExists(target) and UnitCanAttack("player", target) then
                AssistUnit(partyMember)

                if mana > 75 and not buffed(SPELL_SWP, target) then
                    CastSpellByName(SPELL_SWP2)
                end

                if buffed(SPELL_SWP, target) then
                    local spellIndex = GetSpellIndex(SPELL_MIND_BLAST)
                    if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                        ToggleShootOff()
                        CastSpellByName(SPELL_MIND_BLAST2)
                        lastShootToggleTime = currentTime
                        return
                    end
                end

                if buffed(SPELL_SWP, target) then
                    local spellIndex = GetSpellIndex(SPELL_MIND_BLAST)
                    if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) > 1 and (currentTime - lastFlayTime) >= FLAY_DURATION then
                        ToggleShootOff()
                        CastSpellByName(SPELL_MIND_FLAY)
                        lastFlayTime = currentTime
                        lastShootToggleTime = currentTime
                        return
                    end
                end

                if IsShootActive() and (currentTime - lastShootToggleTime) >= SHOOT_TOGGLE_COOLDOWN then
                    ToggleShootOff()
                    lastShootToggleTime = currentTime
                elseif not IsShootActive() and (currentTime - lastFlayTime) >= FLAY_DURATION then
                    CastSpellByName(SPELL_SHOOT)
                    lastShootToggleTime = currentTime
                end
            end
        end
    end
end

-- Function to follow a party member
local function FollowPartyMember()
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
        -- print("Heresy: following executed")
    end

end


-- Add a flag to track if the drinking announcement has been made during the current combat
local hasAnnouncedDrinking = false

-- Function to handle out of mana logic
-- Function to handle out of mana logic
local function OOM()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

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

    if mana > LOW_MANA_THRESHOLD and mana < DRINKING_MANA_THRESHOLD and not UnitAffectingCombat("player") then
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
    if mana < CRITICAL_MANA_THRESHOLD and UnitAffectingCombat("player") and not HasBuff("player", drinkBuffs) then
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

-- Main heresy slash command
SLASH_HERESY1 = "/heresy"
SlashCmdList["HERESY"] = function()
    local healingNeeded = HealParty()
    DispelParty()
    OOM()

    if not healingNeeded then
        local mana = (UnitMana("player") / UnitManaMax("player")) * 100


            if not UnitAffectingCombat("player") then
                BuffParty()
                BuffInnerFire()
                FollowPartyMember()
            end


        if assistmode == 1 then
            AssistPartyMember()
        end
    end
end