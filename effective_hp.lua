
local CONFIG_FILE = "effective_hp"


local Settings = {
    enabled = true,
    showPhysical = true,
    showMagical = true,
    showActual = true,
    enableLogs = true,
    fontSize = 18
}


local MenuItems = {}

local font = nil

local initialized = false


local function LogInfo(message)
    Log.Write("[Effective HP] " .. tostring(message))
end

local function LoadSettings()
    LogInfo("Loading settings from config...")
    
    Settings.enabled = Config.ReadInt(CONFIG_FILE, "enabled", 1) == 1
    Settings.showPhysical = Config.ReadInt(CONFIG_FILE, "showPhysical", 1) == 1
    Settings.showMagical = Config.ReadInt(CONFIG_FILE, "showMagical", 1) == 1
    Settings.showActual = Config.ReadInt(CONFIG_FILE, "showActual", 1) == 1
    Settings.enableLogs = Config.ReadInt(CONFIG_FILE, "enableLogs", 1) == 1
    Settings.fontSize = Config.ReadInt(CONFIG_FILE, "fontSize", 18)
    
    LogInfo("Settings loaded. Enabled: " .. tostring(Settings.enabled))
end


local function SaveSettings()
    Config.WriteInt(CONFIG_FILE, "enabled", Settings.enabled and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "showPhysical", Settings.showPhysical and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "showMagical", Settings.showMagical and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "showActual", Settings.showActual and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "enableLogs", Settings.enableLogs and 1 or 0)
    Config.WriteInt(CONFIG_FILE, "fontSize", Settings.fontSize)
    
    LogInfo("Settings saved to config")
end


local function CreateMenu()
    LogInfo("Creating menu...")
    
  
    local infoScreenTab = Menu.Find("Info Screen")
    if not infoScreenTab then
        infoScreenTab = Menu.Create("Info Screen")
        LogInfo("Created Info Screen tab")
    end

    local section = infoScreenTab:Create("Other")
    
 
    local secondTab = section:Create("Effective HP")
    secondTab:Icon("\u{f204}") 

    local tabSettings = secondTab:Create("Settings")
    tabSettings:Icon("\u{f013}") 
    local gMain = tabSettings:Create("Main")
    
    MenuItems.enabled = gMain:Switch("Enable", Settings.enabled)
    MenuItems.enabled:ToolTip("Enable/disable effective HP calculator")
    
    MenuItems.showPhysical = gMain:Switch("Show Physical HP", Settings.showPhysical)
    MenuItems.showPhysical:ToolTip("Display effective physical HP")
    
    MenuItems.showMagical = gMain:Switch("Show Magical HP", Settings.showMagical)
    MenuItems.showMagical:ToolTip("Display effective magical HP")
    
    MenuItems.showActual = gMain:Switch("Show Actual HP", Settings.showActual)
    MenuItems.showActual:ToolTip("Display current HP")
    
    MenuItems.fontSize = gMain:Slider("Font Size", 12, 32, Settings.fontSize)
    MenuItems.fontSize:ToolTip("Size of the text")
    
    local tabDebug = secondTab:Create("Debug")
    tabDebug:Icon("\u{f188}") 
    local gDebug = tabDebug:Create("Debug Settings")
    
    MenuItems.enableLogs = gDebug:Switch("Enable Logs", Settings.enableLogs)
    MenuItems.enableLogs:ToolTip("Enable debug logging to console")
    
    LogInfo("Menu created successfully")
end


local function UpdateSettingsFromMenu()
    if not MenuItems.enabled then return end
    
    local needsSave = false
    
    if MenuItems.enabled:Get() ~= Settings.enabled then
        Settings.enabled = MenuItems.enabled:Get()
        needsSave = true
    end
    
    if MenuItems.showPhysical:Get() ~= Settings.showPhysical then
        Settings.showPhysical = MenuItems.showPhysical:Get()
        needsSave = true
    end
    
    if MenuItems.showMagical:Get() ~= Settings.showMagical then
        Settings.showMagical = MenuItems.showMagical:Get()
        needsSave = true
    end
    
    if MenuItems.showActual:Get() ~= Settings.showActual then
        Settings.showActual = MenuItems.showActual:Get()
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
    
    if needsSave then
        SaveSettings()
    end
end

local function GetPhysicalArmorReduction(armor)

    local reduction = (armor * 0.06) / (1 + armor * 0.06)
    return math.max(0, math.min(reduction, 0.75)) 
end

local function GetMagicResistanceReduction(resistance)
    
    return math.max(0, math.min(resistance / 100, 0.75))
end

local function CalculateEffectivePhysicalHP(hero)
    local currentHP = hero:GetHealth()
    local armor = hero:GetArmor()
    
    local reduction = GetPhysicalArmorReduction(armor)
    local damageMultiplier = 1 - reduction
    
    if damageMultiplier <= 0 then
        return math.huge
    end
    
    local effectiveHP = currentHP / damageMultiplier
    return effectiveHP
end

local function CalculateEffectiveMagicalHP(hero)
    local currentHP = hero:GetHealth()
    local magicResistance = hero:GetMagicResist()
    
    local reduction = GetMagicResistanceReduction(magicResistance)
    local damageMultiplier = 1 - reduction
    
    if damageMultiplier <= 0 then
        return math.huge
    end
    
    local effectiveHP = currentHP / damageMultiplier
    return effectiveHP
end

local function CalculateBothEffectiveHP(hero)
    return {
        physical = CalculateEffectivePhysicalHP(hero),
        magical = CalculateEffectiveMagicalHP(hero),
        actualHP = hero:GetHealth()
    }
end

local function PrintEffectiveHP(hero)
    if not hero or not hero:IsValid() then
        return
    end
    
    UpdateSettingsFromMenu()
    
    if not Settings.enabled then
        return
    end
    
    local data = CalculateBothEffectiveHP(hero)
    
    print("=== Effective HP ===")
    
    if Settings.showActual then
        print("Actual HP: " .. math.floor(data.actualHP))
    end
    
    if Settings.showPhysical then
        print("Physical Effective HP: " .. math.floor(data.physical))
    end
    
    if Settings.showMagical then
        print("Magical Effective HP: " .. math.floor(data.magical))
    end
end

local function GetEffectiveHPReduction(hero, damageType)

    local effectiveHP = damageType == "physical" 
        and CalculateEffectivePhysicalHP(hero) 
        or CalculateEffectiveMagicalHP(hero)
    
    local actualHP = hero:GetHealth()
    
    if actualHP <= 0 then return 0 end
    
    return ((effectiveHP - actualHP) / actualHP) * 100
end


local function DrawEffectiveHP()
    if not Settings.enabled then
        return
    end
    
    local myHero = Heroes.GetLocal()
    if not myHero or not Entity.IsAlive(myHero) then
        return
    end
    
    if not font then
        font = Renderer.LoadFont("Tahoma", Settings.fontSize, 0, 600)
    end
    
    if not font then
        return
    end
    
    local screenW, screenH = Renderer.GetScreenSize()
    
    local currentHP = Entity.GetHealth(myHero)
    local armor = NPC.GetPhysicalArmorValue(myHero, false) or 0  
    local magicResist = NPC.GetMagicalArmorValue(myHero) or 0
    
    local physicalMult = NPC.GetArmorDamageMultiplier(myHero) or 1.0
    local effectivePhysicalHP = physicalMult > 0 and (currentHP / physicalMult) or 999999
    

    local magicalMult = NPC.GetMagicalArmorDamageMultiplier(myHero) or 1.0
    local effectiveMagicalHP = magicalMult > 0 and (currentHP / magicalMult) or 999999
    
    local lines = {}
    local y = screenH - 150 
    local x = 20 
    
    if Settings.showActual then
        table.insert(lines, {
            text = string.format("HP: %d", math.floor(currentHP)),
            color = {255, 255, 255, 255}
        })
    end
    
    if Settings.showPhysical then
        table.insert(lines, {
            text = string.format("Physical EHP: %d (Armor: %.1f)", math.floor(effectivePhysicalHP), armor),
            color = {255, 180, 100, 255} 
        })
    end
    
    if Settings.showMagical then
        table.insert(lines, {
            text = string.format("Magical EHP: %d (Resist: %.1f%%)", math.floor(effectiveMagicalHP), magicResist),
            color = {100, 180, 255, 255} 
        })
    end
    

    local bgHeight = #lines * (Settings.fontSize + 4) + 10
    local bgWidth = 350
    Renderer.SetDrawColor(0, 0, 0, 150)
    Renderer.DrawFilledRect(x - 5, y - 5, bgWidth, bgHeight)
    

    for i, line in ipairs(lines) do
        local r, g, b, a = line.color[1], line.color[2], line.color[3], line.color[4]
        

        Renderer.SetDrawColor(0, 0, 0, a)
        Renderer.DrawText(font, x + 1, y + 1, line.text)
        

        Renderer.SetDrawColor(r, g, b, a)
        Renderer.DrawText(font, x, y, line.text)
        
        y = y + Settings.fontSize + 4
    end
end

local function Initialize()
    if initialized then return end
    
    LogInfo("Initializing...")
    
    local success, err = pcall(function()
        LoadSettings()
        CreateMenu()
        

        if MenuItems.enabled then
            MenuItems.enabled:Set(Settings.enabled)
            MenuItems.showPhysical:Set(Settings.showPhysical)
            MenuItems.showMagical:Set(Settings.showMagical)
            MenuItems.showActual:Set(Settings.showActual)
            MenuItems.enableLogs:Set(Settings.enableLogs)
            MenuItems.fontSize:Set(Settings.fontSize)
        end
    end)
    
    if not success then
        LogInfo("ERROR: " .. tostring(err))
    else
        LogInfo("Loaded successfully!")
        initialized = true
    end
end

do
    Initialize()
end


return {
    GetPhysicalArmorReduction = GetPhysicalArmorReduction,
    GetMagicResistanceReduction = GetMagicResistanceReduction,
    CalculateEffectivePhysicalHP = CalculateEffectivePhysicalHP,
    CalculateEffectiveMagicalHP = CalculateEffectiveMagicalHP,
    CalculateBothEffectiveHP = CalculateBothEffectiveHP,
    PrintEffectiveHP = PrintEffectiveHP,
    GetEffectiveHPReduction = GetEffectiveHPReduction,
    CreateMenu = CreateMenu,
    LoadSettings = LoadSettings,
    SaveSettings = SaveSettings,
    GetSettings = function() return Settings end,
    
    OnUpdate = function()
        UpdateSettingsFromMenu()
    end,
    
    OnDraw = function()
        if initialized and Settings.enabled then
            DrawEffectiveHP()
        end
    end
}
