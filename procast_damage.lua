 
 

 
local CONFIG_FILE = "procast_damage"

 
local Settings = {
    enabled = true,
    showKillableOnly = false,
    cacheUpdateRate = 0.1,
    enableLogs = true,
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
    if Settings.enableLogs then
        Log.Write("[Procast Damage] " .. tostring(message))
    end
end

 
local function LoadSettings()
    Log.Write("[Procast Damage] Loading settings from config...")
    
    Settings.enabled = Config.ReadInt(CONFIG_FILE, "enabled", 1) == 1
    Settings.showKillableOnly = Config.ReadInt(CONFIG_FILE, "showKillableOnly", 0) == 1
    Settings.cacheUpdateRate = Config.ReadFloat(CONFIG_FILE, "cacheUpdateRate", 0.1)
    Settings.enableLogs = Config.ReadInt(CONFIG_FILE, "enableLogs", 1) == 1
    Settings.fontSize = Config.ReadInt(CONFIG_FILE, "fontSize", 16)

    Log.Write("[Procast Damage] Settings loaded. Enabled: " .. tostring(Settings.enabled) .. ", Logs: " .. tostring(Settings.enableLogs))
end

 
local function SaveSettings()
    Config.WriteInt(CONFIG_FILE, "enabled", Settings.enabled and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "showKillableOnly", Settings.showKillableOnly and 1 or 0)
    Config.WriteFloat(CONFIG_FILE, "cacheUpdateRate", Settings.cacheUpdateRate)
    Config.WriteInt(CONFIG_FILE, "enableLogs", Settings.enableLogs and 1 or 0)
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
            gAbout:Label("Version: 1.0.0")
            gAbout:Button("Telegram channel", function()
                local url = "https://t.me/procast_scripts"
                local safe = url:gsub("'", "\\'")
                Log.Write("[Procast Damage] Opening Telegram: " .. safe)
                local scripts = {
                    string.format("$.DispatchEvent('ExternalBrowserGoToURL', '%s');", safe),
                    string.format("$.DispatchEvent('BrowserGoToURL', '%s');", safe),
                    string.format("$.DispatchEvent('ExternalBrowserGoToURL', '%s', '%s');", safe, safe),
                    string.format("$.DispatchEvent('BrowserGoToURL', '%s', '%s');", safe, safe)
                }
                for _, js in ipairs(scripts) do
                    Engine.RunScript(js)
                end
            end):Unsafe(true)
    MenuItems.enabled = gMain:Switch("Enable", true)
    MenuItems.enabled:ToolTip("Enable/disable procast damage calculator")
    
     
    MenuItems.showKillableOnly = gMain:Switch("Show Killable Only", false)
    MenuItems.showKillableOnly:ToolTip("Show damage only for heroes that can be killed")
    
     
    MenuItems.fontSize = gMain:Slider("Font Size", 10, 32, 16)
    MenuItems.fontSize:ToolTip("Size of the damage text")
    
     
     
     
    local tabDebug = secondTab:Create("Debug")
    tabDebug:Icon("\u{f188}")   
    local gDebug = tabDebug:Create("Debug Settings")
    
     
    MenuItems.enableLogs = gDebug:Switch("Enable Logs", true)
    MenuItems.enableLogs:ToolTip("Enable debug logging to console")
    
     
    MenuItems.cacheUpdateRate = gDebug:Slider("Update Rate", 0.05, 0.5, 0.1, "%.2f")
    MenuItems.cacheUpdateRate:ToolTip("How often to recalculate damage (in seconds)")
    
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

local function GetSpellAmp(caster)
    if not caster then
        return 0
    end
    local amp = NPC.GetBaseSpellAmp(caster) or 0
    amp = amp + (NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE) or 0)
    amp = amp + (NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE_UNIQUE) or 0)
    amp = amp + (NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE_CREEP) or 0)
    return amp
end

 
local function GetAbilityDamage(ability, target, caster)
    if not ability or not Entity.IsAbility(ability) then
        return 0
    end
    
    local damage = 0
    local level = Ability.GetLevel(ability)
    
    if level <= 0 then
        return 0
    end
    
    local abilityName = Ability.GetName(ability)
    
     
    damage = Ability.GetDamage(ability) or 0
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
            local value = Ability.GetLevelSpecialValueFor(ability, field)
            if value and value > 0 then
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
                local value = Ability.GetLevelSpecialValueFor(ability, field)
                if value and value > 0 then
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
            local souls = Modifier.GetStackCount(necromastery)
            if souls > 0 then
                damage = damage * souls
            end
        end
    end
    
     
    local damageType = Ability.GetDamageType(ability)
    if (not damageType or damageType == 0) and abilityName and string.match(abilityName, "^item_") then
        damageType = 2
    end

    if damageType then
        if damageType == 2 then
            damage = damage * GetMagicResistMultiplier(target)
        elseif damageType == 1 then
            damage = damage * GetPhysicalDamageMultiplier(target)
        end
    end

    if damageType == 2 or damageType == 4 then
        local amp = GetSpellAmp(caster)
        if amp ~= 0 then
            damage = damage * (1 + amp / 100)
        end
    end

    return damage
end

 
local function CalculateTotalDamage(myHero, target)
    if not myHero or not target then
        LogInfo("CalculateTotalDamage: myHero or target is nil")
        return 0
    end
    
    local totalDamage = 0
    local abilityCount = 0
    local itemCount = 0
    local foundAbilities = 0
    local castableAbilities = 0
    local foundItems = 0
    
     
    for i = 0, 23 do
        local ability = NPC.GetAbilityByIndex(myHero, i)
        if ability then
            foundAbilities = foundAbilities + 1
            local abilityName = Ability.GetName(ability)
            local level = Ability.GetLevel(ability)
            
             
            if level > 0 and not string.match(abilityName, "^special_bonus") and 
               not string.match(abilityName, "^generic_hidden") and
               not string.match(abilityName, "ability_capture") and
               not string.match(abilityName, "portal_warp") and
               not string.match(abilityName, "ability_lamp") then
                
                castableAbilities = castableAbilities + 1
                if Ability.IsReady(ability) then
                    local abilityDamage = GetAbilityDamage(ability, target, myHero)
                    
                    if abilityDamage > 0 then
                        totalDamage = totalDamage + abilityDamage
                        abilityCount = abilityCount + 1
                    end
                end
            end
        end
    end
    
     
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(myHero, i)
        if item and Ability.IsReady(item) then
            local itemDamage = GetAbilityDamage(item, target, myHero)
            
            if itemDamage > 0 then
                totalDamage = totalDamage + itemDamage
                itemCount = itemCount + 1
            end
        end
    end
    
    if totalDamage > 0 then
        LogInfo(string.format("Total damage: %.1f from %d abilities and %d items", totalDamage, abilityCount, itemCount))
    end
    return totalDamage
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

 
local function DrawHPRemaining(hero, damage)
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
    
     
    local currentHP = Entity.GetHealth(hero)
    local remainingHP = currentHP - damage
    
     
    if Settings.showKillableOnly and remainingHP > 0 then
        return
    end
    
     
    local color = Settings.drawSafeColor
    if remainingHP <= 0 then
        color = Settings.drawKillColor
    elseif remainingHP < currentHP * 0.3 then
        color = Settings.drawLowHPColor
    end

    local r, g, b, a = color[1], color[2], color[3], color[4] or 255
    local text = string.format("DMG %d | HP %d", math.floor(damage), math.max(0, math.floor(remainingHP)))

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

 
return {
    OnUpdate = function()
         
        if not initialized then
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
            LogInfo("Font loaded: " .. tostring(font))
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

