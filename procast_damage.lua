 
 

 
local CONFIG_FILE = "procast_damage"

 
local Settings = {
    enabled = true,
    showKillableOnly = false,
    cacheUpdateRate = 0.1,
    enableLogs = true,
    enableMedusaCalc = true,
    drawKillColor = {50, 255, 50, 255},
    drawLowHPColor = {255, 165, 0, 255},
    drawSafeColor = {255, 50, 50, 255},
    fontSize = 16
}
 
local MenuItems = {}

 
local font = nil

 
local damageCache = {}
local cacheTime = 0

 
local initialized = false

 
local function LogInfo(message)
    Log.Write("[Procast Damage] " .. tostring(message))
end

 
local function LoadSettings()
    Log.Write("[Procast Damage] Loading settings from config...")
    
    Settings.enabled = Config.ReadInt(CONFIG_FILE, "enabled", 1) == 1
    Settings.showKillableOnly = Config.ReadInt(CONFIG_FILE, "showKillableOnly", 0) == 1
    Settings.cacheUpdateRate = Config.ReadFloat(CONFIG_FILE, "cacheUpdateRate", 0.1)
    Settings.enableLogs = Config.ReadInt(CONFIG_FILE, "enableLogs", 1) == 1
    Settings.enableMedusaCalc = Config.ReadInt(CONFIG_FILE, "enableMedusaCalc", 1) == 1
    Settings.fontSize = Config.ReadInt(CONFIG_FILE, "fontSize", 16)

    Log.Write("[Procast Damage] Settings loaded. Enabled: " .. tostring(Settings.enabled) .. ", Logs: " .. tostring(Settings.enableLogs))
end

 
local function SaveSettings()
    Config.WriteInt(CONFIG_FILE, "enabled", Settings.enabled and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "showKillableOnly", Settings.showKillableOnly and 1 or 0)
    Config.WriteFloat(CONFIG_FILE, "cacheUpdateRate", Settings.cacheUpdateRate)
    Config.WriteInt(CONFIG_FILE, "enableLogs", Settings.enableLogs and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "enableMedusaCalc", Settings.enableMedusaCalc and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "fontSize", Settings.fontSize)
    
    LogInfo("Settings saved to config")
end

 
local function CreateMenu()
    Log.Write("[Procast Damage] Creating menu...")
    
     
    local infoScreenTab = Menu.Find("Info Screen")
    if not infoScreenTab then
        infoScreenTab = Menu.Create("Info Screen")
        Log.Write("[Procast Damage] Created Info Screen tab")
    end
    
     
    local section = infoScreenTab:Create("Other")
    
     
    local secondTab = section:Create("Procast Damage")
    secondTab:Icon("\u{f0e7}")   
    
     
     
     
    local tabSettings = secondTab:Create("Settings")
    tabSettings:Icon("\u{f013}")   
    local gMain = tabSettings:Create("Main")
    MenuItems.enabled = gMain:Switch("Enable", true)
    MenuItems.enabled:ToolTip("Enable/disable procast damage calculator")
    
    MenuItems.showKillableOnly = gMain:Switch("Show Killable Only", false)
    MenuItems.showKillableOnly:ToolTip("Show damage only for heroes that can be killed")
    
    MenuItems.enableMedusaCalc = gMain:Switch("Medusa Mana Shield Calc(very unstable)", true)
    MenuItems.enableMedusaCalc:ToolTip("Enable special damage calculation for Medusa with Mana Shield")
    
    MenuItems.fontSize = gMain:Slider("Font Size", 10, 32, 16)
    MenuItems.fontSize:ToolTip("Size of the damage text")
    
     
     
     
    local tabDebug = secondTab:Create("Debug")
    tabDebug:Icon("\u{f188}")   
    local gDebug = tabDebug:Create("Debug Settings")
    
     
    MenuItems.enableLogs = gDebug:Switch("Enable Logs", true)
    MenuItems.enableLogs:ToolTip("Enable debug logging to console")
    
     
    MenuItems.cacheUpdateRate = gDebug:Slider("Update Rate", 0.05, 0.5, 1, "%.2f")
    MenuItems.cacheUpdateRate:ToolTip("How often to recalculate damage (in seconds)")

     
     
     
    local tabAbout = secondTab:Create("About")
    tabAbout:Icon("\u{f05a}")   
    local gAbout = tabAbout:Create("Info")

    gAbout:Label("Version: 1.0.0")
    gAbout:Button("https://t.me/lonestill_lab", function()
        local url = "https://t.me/lonestill_lab"
        local safe = url:gsub("'", "\\'")
        Log.Write("[Procast Damage] Opening Telegram: " .. safe)
        local scripts = {
            string.format("$.DispatchEvent('ExternalBrowserGoToURL', '%s');", safe),

        }
        for _, js in ipairs(scripts) do
            Engine.RunScript(js)
        end
    end):Unsafe(true)
    
    Log.Write("[Procast Damage] Menu widgets created successfully")
end

 
local function UpdateSettingsFromMenu()
    if not MenuItems.enabled then return end
    
    local needsSave = false
    
    if MenuItems.enabled:Get() ~= Settings.enabled then
        Settings.enabled = MenuItems.enabled:Get()
        needsSave = true
    end
    
    if MenuItems.showKillableOnly:Get() ~= Settings.showKillableOnly then
        Settings.showKillableOnly = MenuItems.showKillableOnly:Get()
        needsSave = true
    end
    
    if MenuItems.enableMedusaCalc:Get() ~= Settings.enableMedusaCalc then
        Settings.enableMedusaCalc = MenuItems.enableMedusaCalc:Get()
        needsSave = true
        LogInfo("Medusa Mana Shield calculation " .. (Settings.enableMedusaCalc and "enabled" or "disabled"))
    end
    
    if MenuItems.enableLogs:Get() ~= Settings.enableLogs then
        Settings.enableLogs = MenuItems.enableLogs:Get()
        needsSave = true
        LogInfo("Logging " .. (Settings.enableLogs and "enabled" or "disabled"))
    end
    
    if MenuItems.fontSize:Get() ~= Settings.fontSize then
        Settings.fontSize = MenuItems.fontSize:Get()
         
        font = Renderer.LoadFont("Tahoma", Settings.fontSize, 0, 600)
        needsSave = true
    end
    
    if MenuItems.cacheUpdateRate:Get() ~= Settings.cacheUpdateRate then
        Settings.cacheUpdateRate = MenuItems.cacheUpdateRate:Get()
        needsSave = true
    end
    
    if needsSave then
        SaveSettings()
    end
end

 
local function GetMagicResistMultiplier(target)
    if not target or not Entity.IsAlive(target) then
        return 1.0
    end
    
     
    local magicMult = NPC.GetMagicalArmorDamageMultiplier(target)
    return magicMult or 1.0
end

 
local function GetPhysicalDamageMultiplier(target)
    if not target or not Entity.IsAlive(target) then
        return 1.0
    end
    
     
    local armorMult = NPC.GetArmorDamageMultiplier(target)
    return armorMult or 1.0
end

local function GetSpellAmp(caster, logDetails)
    if not caster then
        return 0
    end
    
     
    local base = NPC.GetBaseSpellAmp(caster) or 0
    
     
    local unique = NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE_UNIQUE) or 0
    local creep = NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE_CREEP) or 0
    
     
    local finalAmp = base
    if unique ~= 0 then
        finalAmp = base + unique * (1 + base / 100)
    end
    
    if logDetails and Settings.enableLogs then
        local generic = NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE) or 0
        LogInfo(string.format("Spell Amp: base=%.1f%% unique=%.1f%% -> final=%.1f%% | (generic=%.1f%% creep=%.1f%%)", 
            base, unique, finalAmp, generic, creep))
    end
    
    return finalAmp
end
local function GetAbilityDamage(ability, caster)
    if not ability or not Entity.IsAbility(ability) then
        return 0
    end
    
    local damage = 0
    local level = 0
    pcall(function() level = Ability.GetLevel(ability) or 0 end)
    
    if level <= 0 then
        return 0
    end
    
    local abilityName = ""
    pcall(function() abilityName = Ability.GetName(ability) or "" end)
    
    pcall(function() damage = Ability.GetDamage(ability) or 0 end)
    
    if damage == 0 then
        local damageFields = {
            "damage", "strike_damage", "tooltip_damage",
            "damage_impact", "wave_damage", "nuke_damage", "total_damage",
            "explosion_damage", "base_damage", "ability_damage",
            "shadowraze_damage", "spirit_damage", "bonus_damage", "initial_damage",
            "area_damage", "main_damage", "damage_per_second", "burn_damage",
            "primary_damage", "secondary_damage", "magic_damage", "physical_damage",
            "requiem_line_damage", "requiem_damage", "damage_per_line"
        }
        
        for _, field in ipairs(damageFields) do
            local value = 0
            pcall(function() value = Ability.GetLevelSpecialValueFor(ability, field) or 0 end)
            if value > 0 then
                damage = value
                break
            end
        end
    end
    
    if damage == 0 then
        local specialFields = {
            ["nevermore_requiem"] = {"requiem_line_damage", "requiem_damage", "damage_per_line"},
            ["lina_laguna_blade"] = {"damage_scepter"},
            ["lion_finger_of_death"] = {"damage_scepter"},
        }
        
        local abilitySpecial = specialFields[abilityName]
        if abilitySpecial then
            for _, field in ipairs(abilitySpecial) do
                local value = 0
                pcall(function() value = Ability.GetLevelSpecialValueFor(ability, field) or 0 end)
                if value > 0 then
                    damage = value
                    break
                end
            end
        end
        
        if damage == 0 then
            return 0
        end
    end
    
    if abilityName == "nevermore_requiem" and caster then
        local necromastery = NPC.GetModifier(caster, "modifier_nevermore_necromastery")
        if necromastery then
            local souls = 0
            pcall(function() souls = Modifier.GetStackCount(necromastery) or 0 end)
            if souls > 0 then
                damage = damage * souls
            end
        end
    end

    if abilityName == "lion_finger_of_death" and caster then
        local kills = 0
        local fingerKills = NPC.GetModifier(caster, "modifier_lion_finger_of_death_kill_counter")
        if fingerKills then
            pcall(function() kills = Modifier.GetStackCount(fingerKills) or 0 end)
        end
        local charges = 0
        pcall(function() charges = Ability.GetCurrentCharges(ability) or 0 end)
        if charges > kills then
            kills = charges
        end

        if kills > 0 then
            local bonusDamagePerKill = 0
            pcall(function() bonusDamagePerKill = Ability.GetLevelSpecialValueFor(ability, "damage_per_kill") or 0 end)
            if bonusDamagePerKill == 0 then
                pcall(function() bonusDamagePerKill = Ability.GetLevelSpecialValueFor(ability, "damage_per_kill_scepter") or 0 end)
            end

            if bonusDamagePerKill > 0 then
                damage = damage + (kills * bonusDamagePerKill)
            end
        end
    end
    
    local damageType = 0
    pcall(function() damageType = Ability.GetDamageType(ability) or 0 end)
    if (damageType == 0 or damageType == nil) and abilityName and string.match(abilityName, "^item_") then
        damageType = 2 
    end

    if damageType == 2 or damageType == 4 then
        local amp = GetSpellAmp(caster, false)
        if amp ~= 0 then
            damage = damage * (1 + amp / 100)
        end
    end
    return damage
end

 
local function CalculateTotalDamage(myHero, target)

    if not myHero or not target then
        return 0
    end
    
    local totalRawDamage = 0
    

    for i = 0, 23 do
        local ability = NPC.GetAbilityByIndex(myHero, i)
        if ability then
            local level = 0
            pcall(function() level = Ability.GetLevel(ability) or 0 end)
            if level > 0 then
                local isReady = false
                pcall(function() isReady = Ability.IsReady(ability) end)
                if isReady then
                    local name = Ability.GetName(ability)
                    if not string.match(name, "^special_bonus") and 
                       not string.match(name, "^generic_hidden") and
                       not string.match(name, "ability_capture") then
                        
                        local dmg = GetAbilityDamage(ability, myHero)
                        if dmg > 0 then
                            totalRawDamage = totalRawDamage + dmg
                        end
                    end
                end
            end
        end
    end
    
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(myHero, i)
        if item then
            local isReady = false
            pcall(function() isReady = Ability.IsReady(item) end)
            if isReady then
                local dmg = GetAbilityDamage(item, myHero)
                if dmg > 0 then
                    totalRawDamage = totalRawDamage + dmg
                end
            end
        end
    end
    
    return totalRawDamage
end

 
local function UpdateDamageCache()
    if not Settings.enabled then
        return
    end
    
    local currentTime = GameRules.GetGameTime()
    
     
    if currentTime - cacheTime < Settings.cacheUpdateRate then
        return
    end
    
    cacheTime = currentTime
    damageCache = {}
    
    local myHero = Heroes.GetLocal()
    if not myHero or not Entity.IsAlive(myHero) then
        return
    end

    LogInfo("Updating damage cache...")

    local allHeroes = Heroes.GetAll()
    local enemyCount = 0
    for _, hero in ipairs(allHeroes) do
        if hero and Entity.IsAlive(hero) then
             
            if not Entity.IsSameTeam(myHero, hero) then
                local damage = CalculateTotalDamage(myHero, hero)
                local heroIndex = Entity.GetIndex(hero)
                damageCache[heroIndex] = damage
                enemyCount = enemyCount + 1
            end
        end
    end
    
    LogInfo(string.format("Cache updated for %d enemies", enemyCount))
end

 
local function DrawHPRemaining(hero, rawDamage)
    
    if not hero or not Entity.IsAlive(hero) then
        return
    end
    
    local heroPos = Entity.GetAbsOrigin(hero)
    if not heroPos then
        return
    end
    
    local barOffset = NPC.GetHealthBarOffset(hero) or 150
    local drawPos = heroPos + Vector(0, 0, barOffset + 10)
    
    local x, y, visible = Renderer.WorldToScreen(drawPos)
    if not visible then
        return
    end
    
    local heroName = NPC.GetUnitName(hero)
    local isMedusa = heroName == "npc_dota_hero_medusa" and Settings.enableMedusaCalc
    
    local finalDamage = rawDamage
    local manaSpent = 0
    
    if isMedusa then
        local manaShield = NPC.GetAbility(hero, "medusa_mana_shield")
        if manaShield then
            local manaShieldLevel = 0
            pcall(function() manaShieldLevel = Ability.GetLevel(manaShield) or 0 end)
            
            if manaShieldLevel > 0 then
                local heroLevel = 1
                pcall(function() heroLevel = NPC.GetLevel(hero) or 1 end)
                local currentMana = 0
                pcall(function() currentMana = NPC.GetMana(hero) or 0 end)
                
                local manaPerDamage = 2.4 + (0.1 * heroLevel)
                
                local absorbPart = finalDamage * 0.98
                local passPart = finalDamage * 0.02
                
                local manaNeeded = absorbPart / manaPerDamage
                
                if currentMana >= manaNeeded then
                    manaSpent = manaNeeded
                    finalDamage = passPart
                else

                    manaSpent = currentMana
                    local damageBlocked = currentMana * manaPerDamage
                    local damageOverflow = absorbPart - damageBlocked
                    finalDamage = passPart + damageOverflow
                end
            end
        end
    end

    local resistMult = 1.0
    
    if isMedusa then
        resistMult = GetMagicResistMultiplier(hero)
    else
        resistMult = GetMagicResistMultiplier(hero) 
    end
    
    finalDamage = finalDamage * resistMult
    
    if Settings.showKillableOnly and finalDamage <= 0 then
        return
    end
    
    local color = Settings.drawSafeColor
    local text = ""
    
    if isMedusa then
        local currentMana = 0
        pcall(function() currentMana = NPC.GetMana(hero) or 0 end)
        local remainingMana = currentMana - manaSpent
        
        if remainingMana <= 0 then
            color = Settings.drawKillColor
        elseif remainingMana < currentMana * 0.3 then
            color = Settings.drawLowHPColor
        end
        
        text = string.format("MANA COST %.0f | MANA %.0f | HP DMG %.0f", 
            manaSpent, math.max(0, remainingMana), finalDamage)
    else
        local currentHP = 0
        pcall(function() currentHP = Entity.GetHealth(hero) or 0 end)
        local remainingHP = currentHP - finalDamage
        
        if remainingHP <= 0 then
            color = Settings.drawKillColor
        elseif remainingHP < currentHP * 0.3 then
            color = Settings.drawLowHPColor
        end
        
        text = string.format("DMG %.0f | HP %.0f", finalDamage, math.max(0, remainingHP))
    end

    local r, g, b, a = color[1], color[2], color[3], color[4] or 255

    if font then
        Renderer.SetDrawColor(0, 0, 0, a)
        Renderer.DrawText(font, x + 1, y + 1, text)

        Renderer.SetDrawColor(r, g, b, a)
        Renderer.DrawText(font, x, y, text)
    end
end

 
local function Initialize()
    if initialized then return end
    
    Log.Write("[Procast Damage] Initializing...")
    
    local success, err = pcall(function()
        LoadSettings()
        Log.Write("[Procast Damage] Settings loaded")
        CreateMenu()
        Log.Write("[Procast Damage] Menu created")
    
         
        if MenuItems.enabled then
            MenuItems.enabled:Set(Settings.enabled)
            MenuItems.showKillableOnly:Set(Settings.showKillableOnly)
            MenuItems.enableMedusaCalc:Set(Settings.enableMedusaCalc)
            MenuItems.enableLogs:Set(Settings.enableLogs)
            MenuItems.fontSize:Set(Settings.fontSize)
            MenuItems.cacheUpdateRate:Set(Settings.cacheUpdateRate)
        end
    end)
    
    if not success then
        Log.Write("[Procast Damage] ERROR during initialization: " .. tostring(err))
    else
        Log.Write("[Procast Damage] Initialization complete. Enabled: " .. tostring(Settings.enabled))
        initialized = true
    end
end

-- Initialize immediately on script load
do
    Log.Write("[Procast Damage] Script loading...")
    local success, err = pcall(function()
        Initialize()
    end)
    if not success then
        Log.Write("[Procast Damage] LOAD ERROR: " .. tostring(err))
    end
end

return {
    OnUpdate = function()
        -- Debug: check if callback is being called
        if not initialized then
            Log.Write("[Procast Damage] OnUpdate - not initialized yet, calling Initialize()")
            Initialize()
        end
        
         
        UpdateSettingsFromMenu()
        
         
        UpdateDamageCache()
    end,
    
    OnDraw = function()
        if not initialized or not Settings.enabled then
            return
        end
        
         
        if not font then
            font = Renderer.LoadFont("Tahoma", Settings.fontSize, 0, 600)
            Log.Write("[Procast Damage] Font loaded: " .. tostring(font))
        end
        
        local myHero = Heroes.GetLocal()
        if not myHero or not Entity.IsAlive(myHero) then
            return
        end
        
         
        for heroIndex, damage in pairs(damageCache) do
            local hero = Entity.Get(heroIndex)
            if hero and Entity.IsAlive(hero) and damage > 0 then
                DrawHPRemaining(hero, damage)
            end
        end
    end
}

