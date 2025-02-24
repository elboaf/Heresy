-- Addon Name
Heresy = {}

-- Add a global variable to track drinking mode
local isDrinkingMode = false
local DRINKING_MANA_THRESHOLD = 80 -- Stop drinking at 80% mana
local EMERGENCY_HEALTH_THRESHOLD = 30 -- Heal party members below 30% health even while drinking

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
local HEALTH_THRESHOLD = 70 -- Heal if health is below 70%

-- Timing variables for Shoot toggle
local lastShootToggleTime = 0
local shootToggleCooldown = 1.5 -- Toggle Shoot off after 8 seconds
local lastFlayTime = 0
local flayDuration = 3

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
    -- CheckInteractDistance returns true if the unit is within 40 yards (index 4)
    return CheckInteractDistance(unit, 4)
end

-- Function to buff a unit with Power Word: Fortitude if they are not already buffed and are in range
local function BuffUnit(unit)
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and IsUnitInRange(unit) then
        if not buffed(SPELL_PWF, unit) then
            CastSpellByName(SPELL_PWF)
            SpellTargetUnit(unit)
            return true
        end
        if not buffed(SPELL_SPIRIT, unit) then
            CastSpellByName(SPELL_SPIRIT)
            SpellTargetUnit(unit)
            return true
        end
    end
    return false
end

-- Function to check if all buffing is complete
local function IsBuffingComplete()
    -- Check if the player is buffed
    if not buffed(SPELL_PWF, "player") or not buffed(SPELL_SPIRIT, "player") then
        return false
    end

    -- Check if party members are buffed and in range
    for i = 1, 4 do
        local partyMember = "party" .. i
        if UnitExists(partyMember) and not UnitIsDeadOrGhost(partyMember) then
            if not buffed(SPELL_PWF, partyMember) or not buffed(SPELL_SPIRIT, partyMember) then
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

local function BuffParty()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    -- Skip buffing if mana is 10% or less
    if mana <= 10 then
        return
    end

    -- Buff myself first
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

-- healparty function
local function HealParty()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    -- If in drinking mode, only interrupt for emergency healing or if mana is above 80%
    if isDrinkingMode then
        -- Check if mana is above 80%, and if so, disable drinking mode
        if mana >= DRINKING_MANA_THRESHOLD then
            isDrinkingMode = false
            return false -- No healing was needed
        end

        -- Check for emergency healing (party members below 30% health)
        local lowestHealthUnit = nil
        local lowestHealthPercent = 100

        -- Check player's health
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

        -- Only heal if the lowest health unit is below the emergency threshold
        if lowestHealthUnit and lowestHealthPercent < EMERGENCY_HEALTH_THRESHOLD then
            local healneed = UnitHealthMax(lowestHealthUnit) - UnitHealth(lowestHealthUnit)
            local Health = UnitHealth(lowestHealthUnit) / UnitHealthMax(lowestHealthUnit)

            -- Get the appropriate healing spell based on QuickHeal logic
            local SpellID, HealSize = QuickHeal_Priest_FindHealSpellToUse(lowestHealthUnit, "channel", nil, false)

            if SpellID then
                CastSpellByName(GetSpellName(SpellID, BOOKTYPE_SPELL))
                SpellTargetUnit(lowestHealthUnit)
                return true
            end
        end

        return false -- No healing was needed
    else
        -- If not in drinking mode, proceed with normal healing logic
        local lowestHealthUnit = nil
        local lowestHealthPercent = 100

        -- Check player's health
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

        -- Heal the lowest health unit based on thresholds
        if lowestHealthUnit then
            local healneed = UnitHealthMax(lowestHealthUnit) - UnitHealth(lowestHealthUnit)
            local Health = UnitHealth(lowestHealthUnit) / UnitHealthMax(lowestHealthUnit)

            -- Get the appropriate healing spell based on QuickHeal logic
            local SpellID, HealSize = QuickHeal_Priest_FindHealSpellToUse(lowestHealthUnit, "channel", nil, false)

            if SpellID then
                CastSpellByName(GetSpellName(SpellID, BOOKTYPE_SPELL))
                SpellTargetUnit(lowestHealthUnit)
                return true
            end
        end

        return false -- No healing was needed
    end
end

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

                -- Cast Shadow Word: Pain if mana > 50 and the target doesn't have it
                if mana > 80 and not buffed(SPELL_SWP, target) then
                    CastSpellByName(SPELL_SWP2)
                end

                -- Cast Mind Blast if mana > 80, Shadow Word: Pain is on the target, and Mind Blast is off cooldown
                if mana > 75 and buffed(SPELL_SWP, target) then
                    local spellIndex = GetSpellIndex(SPELL_MIND_BLAST)
                    if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) < 1 then
                        -- Toggle Shoot off before casting Mind Blast
                        ToggleShootOff()
                        CastSpellByName(SPELL_MIND_BLAST2)
                        lastShootToggleTime = currentTime -- Reset the timer
                        return -- Exit after casting Mind Blast
                    end
                end
                -- Cast Mind Flay if mana > 80, Shadow Word: Pain is on the target, and Mind Blast is on cooldown
                if mana > 75 and buffed(SPELL_SWP, target) then
                    local spellIndex = GetSpellIndex(SPELL_MIND_BLAST)
                    if spellIndex and GetSpellCooldown(spellIndex, BOOKTYPE_SPELL) > 1 and (currentTime - lastFlayTime) >= flayDuration then
                        -- Toggle Shoot off before casting Mind Flay
                        ToggleShootOff()
                        CastSpellByName(SPELL_MIND_FLAY)
                        lastFlayTime = currentTime
                        lastShootToggleTime = currentTime -- Reset the timer
                        return -- Exit after casting Mind Flay
                    end
                end

                -- Fallback to Shoot if Mind Blast is on cooldown or conditions aren't met
                -- Toggle Shoot off after 8 seconds if it's active
                if IsShootActive() and (currentTime - lastShootToggleTime) >= shootToggleCooldown then
                    ToggleShootOff()
                    lastShootToggleTime = currentTime -- Reset the timer
                elseif not IsShootActive() and mana < 95 and (currentTime - lastFlayTime) >= flayDuration then
                    CastSpellByName(SPELL_SHOOT) -- Toggle Shoot on
                    lastShootToggleTime = currentTime -- Reset the timer
                end
            end
        end
    end
end

-- Function to follow a party member
local function FollowPartyMember()
    -- Check if the priest is currently drinking
    if HasBuff("player", drinkBuffs) then
        return  -- Exit the function if the priest is drinking
    end

    -- If not drinking, proceed to follow a party member
    FollowByName("Rele", exactMatch)
end

-- Add a flag to track if the drinking announcement has been made during the current combat
local hasAnnouncedDrinking = false

-- oom function
local function OOM()
    local mana = (UnitMana("player") / UnitManaMax("player")) * 100

    -- If in drinking mode, only stop drinking if mana is above 80%
    if isDrinkingMode and mana >= DRINKING_MANA_THRESHOLD then
        isDrinkingMode = false
        return
    end

    -- If mana is critically low (below 10%), drink immediately without checking buffing
    if mana <= 10 and not UnitAffectingCombat("player") then
        if not HasBuff("player", drinkBuffs) then
            --SendChatMessage("Heresy: CRITICALLY LOW MANA -- Drinking immediately...", "PARTY")
            for b = 0, 4 do
                for s = 1, GetContainerNumSlots(b) do
                    local itemLink = GetContainerItemLink(b, s)
                    if itemLink then
                        for _, drink in ipairs(drinkstodrink) do
                            if strfind(itemLink, drink) then
                                UseContainerItem(b, s)
                                isDrinkingMode = true -- Enable drinking mode
                                return -- Exit the function after starting to drink
                            end
                        end
                    end
                end
            end
        end
    end

    -- If mana is low but not critically low (10% < mana < 70%), check if buffing is complete before drinking
    if mana > 10 and mana < 70 and not UnitAffectingCombat("player") and IsBuffingComplete() then
        if not HasBuff("player", drinkBuffs) then
            --SendChatMessage("Heresy: LOW MANA -- Drinking...", "PARTY")
            for b = 0, 4 do
                for s = 1, GetContainerNumSlots(b) do
                    local itemLink = GetContainerItemLink(b, s)
                    if itemLink then
                        for _, drink in ipairs(drinkstodrink) do
                            if strfind(itemLink, drink) then
                                UseContainerItem(b, s)
                                isDrinkingMode = true -- Enable drinking mode
                                return -- Exit the function after starting to drink
                            end
                        end
                    end
                end
            end
        end
    end

    -- Use Quel'dorei Meditation if mana is critically low, in combat, and not drinking
    if mana < 15 and UnitAffectingCombat("player") and not HasBuff("player", drinkBuffs) then
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

    -- Announce drinking requirement after combat if mana is low and the announcement hasn't been made yet
    if UnitAffectingCombat("player") and mana < 40 and not hasAnnouncedDrinking then
        SendChatMessage(">> LOW MANA << I need to drink after combat!", "PARTY")
        hasAnnouncedDrinking = true -- Set the flag to prevent repeated announcements
    end
end

-- Event handler to reset the announcement flag when combat ends
local function OnEvent(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Combat ended, reset the announcement flag
        hasAnnouncedDrinking = false
    end
end

-- Create a frame to listen for combat events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- Fires when combat ends
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

-- main heresey slash command
SLASH_HERESY1 = "/heresy"
SlashCmdList["HERESY"] = function()
    -- Check if healing is needed
    local healingNeeded = HealParty()

    -- Always check for low mana and drink if necessary
    OOM()

    -- If no healing is needed, proceed to buff and assist
    if not healingNeeded then
        local mana = (UnitMana("player") / UnitManaMax("player")) * 100

        -- Skip buffing if mana is 10% or less
        if mana > 10 then
            if not UnitAffectingCombat("player") then
                BuffParty()
            end
            BuffInnerFire()
            FollowPartyMember()
        end

        if assistmode == 1 then
            AssistPartyMember()
        end
    end
end