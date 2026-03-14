local AddonName, ns = ...
local Data = ns.Data

-- Initialize SavedVariables for preferences
MidnightCheckDB = MidnightCheckDB or {}
MidnightCheckDB.Prefs = MidnightCheckDB.Prefs or {}

local slotNames = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulders", [4] = "Shirt", [5] = "Chest",
    [6] = "Waist", [7] = "Legs", [8] = "Boots", [9] = "Wrist", [10] = "Hands",
    [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1", [14] = "Trinket 2",
    [15] = "Back", [16] = "Main Hand", [17] = "Off Hand"
}

-- ==========================================
-- Main UI Frame
-- ==========================================
local uiFrame = CreateFrame("Frame", "MidnightCheckUI", UIParent, "BackdropTemplate")
uiFrame:SetSize(380, 480)
uiFrame:SetPoint("CENTER")
uiFrame:SetMovable(true)
uiFrame:EnableMouse(true)
uiFrame:RegisterForDrag("LeftButton")
uiFrame:SetScript("OnDragStart", uiFrame.StartMoving)
uiFrame:SetScript("OnDragStop", uiFrame.StopMovingOrSizing)
uiFrame:Hide()
tinsert(UISpecialFrames, uiFrame:GetName())

uiFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false, edgeSize = 2, insets = { left = 0, right = 0, top = 0, bottom = 0 }
})
uiFrame:SetBackdropColor(0.05, 0.04, 0.08, 0.95)
uiFrame:SetBackdropBorderColor(0.4, 0.1, 0.7, 1)

local header = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
header:SetPoint("TOP", 0, -10)
header:SetText("|cFFB266FFMidnight Readiness|r")

local contentText = uiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
contentText:SetPoint("TOPLEFT", 15, -40)
contentText:SetJustifyH("LEFT")
contentText:SetJustifyV("TOP")
contentText:SetWidth(350)

local closeBtn = CreateFrame("Button", nil, uiFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", uiFrame, "TOPRIGHT", 0, 0)

-- ==========================================
-- Dropdown Menu
-- ==========================================
local ROW_HEIGHT  = 26
local MENU_WIDTH  = 185

-- Invisible full-screen frame sitting behind the dropdown.
-- When the user clicks anywhere outside the menu, this catches
-- the click and closes the dropdown.
local dropdownBackdrop = CreateFrame("Frame", nil, UIParent)
dropdownBackdrop:SetAllPoints(UIParent)
dropdownBackdrop:SetFrameStrata("FULLSCREEN")
dropdownBackdrop:EnableMouse(true)
dropdownBackdrop:Hide()

local dropdownFrame = CreateFrame("Frame", "MC_DropdownFrame", UIParent, "BackdropTemplate")
dropdownFrame:SetFrameStrata("FULLSCREEN_DIALOG") -- sits above the backdrop
dropdownFrame:SetClampedToScreen(true)            -- never goes off-screen
dropdownFrame:Hide()
dropdownFrame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false, edgeSize = 1,
})
dropdownFrame:SetBackdropColor(0.08, 0.06, 0.12, 0.98)
dropdownFrame:SetBackdropBorderColor(0.4, 0.1, 0.7, 1)

local function CloseDropdown()
    dropdownFrame:Hide()
    dropdownBackdrop:Hide()
end

dropdownBackdrop:SetScript("OnMouseDown", CloseDropdown)

-- We reuse a pool of row buttons rather than creating new ones each time.
-- This avoids memory churn from repeatedly parenting/deparenting frames.
local rowPool = {}

local function GetRow(index)
    if not rowPool[index] then
        local row = CreateFrame("Button", nil, dropdownFrame)
        row:SetSize(MENU_WIDTH - 2, ROW_HEIGHT)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.4, 0.1, 0.7, 0.35)

        row.checkMark = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.checkMark:SetPoint("LEFT", 6, 0)
        row.checkMark:SetWidth(14)
        row.checkMark:SetJustifyH("LEFT")

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", 22, 0)
        row.label:SetWidth(MENU_WIDTH - 28)
        row.label:SetJustifyH("LEFT")

        rowPool[index] = row
    end
    return rowPool[index]
end

local ApplyButtonItems -- forward declaration (defined after buttons are created)

local function ShowDropdown(anchorBtn, category)
    if InCombatLockdown() then
        print("|cFFB266FF[MidnightCheck]|r Can't change preferences in combat.")
        return
    end

    local list = Data.Consumables[category]
    if not list or #list == 0 then return end

    local currentPref = MidnightCheckDB.Prefs[category] or list[1]
    local numItems = #list

    -- Hide any rows beyond what we need this time
    for i = numItems + 1, #rowPool do
        rowPool[i]:Hide()
    end

    dropdownFrame:SetSize(MENU_WIDTH, numItems * ROW_HEIGHT + 6)

    for i, itemName in ipairs(list) do
        local row = GetRow(i)
        row:SetPoint("TOPLEFT", dropdownFrame, "TOPLEFT", 1, -3 - (i - 1) * ROW_HEIGHT)
        row.checkMark:SetText(itemName == currentPref and "|cFF55FF55✔|r" or "")
        row.label:SetText(itemName)
        row:Show()

        -- Capture itemName and category for the click handler
        row:SetScript("OnClick", function()
            MidnightCheckDB.Prefs[category] = itemName
            print("|cFFB266FF[MidnightCheck]|r " .. category .. " set to: " .. itemName)
            CloseDropdown()
            ApplyButtonItems()
            RunCheck()
        end)
    end

    -- Anchor the menu just above the button that was right-clicked
    dropdownFrame:ClearAllPoints()
    dropdownFrame:SetPoint("BOTTOMLEFT", anchorBtn, "TOPLEFT", 0, 4)

    dropdownBackdrop:Show()
    dropdownFrame:Show()
end

-- ==========================================
-- Secure Action Buttons
-- ==========================================
-- Buttons are parented to UIParent (not uiFrame) to avoid inheriting taint.
-- RunCheck() scans inventory/auras which can taint uiFrame's children.
-- A separate visual-only frame (EnableMouse=false) handles styling.
local secureButtons = {}

local function CreateSecureBtn(name, labelText, category, xOffset)
    -- Pure secure button: UIParent parent, minimal addon interactions
    local btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    btn:SetSize(65, 30)
    btn:SetPoint("BOTTOMLEFT", uiFrame, "BOTTOMLEFT", xOffset, 15)
    btn:SetFrameStrata("HIGH")
    btn:Hide()
    btn.category = category

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("type2", "none")
    btn:SetAttribute("macrotext", "")

    btn:SetScript("PostClick", function(self, button)
        if button == "RightButton" and not InCombatLockdown() then
            ShowDropdown(self, self.category)
        elseif button == "LeftButton" then
            C_Timer.After(2, function() if uiFrame:IsShown() then RunCheck() end end)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local pref = MidnightCheckDB.Prefs[self.category]
            or (Data.Consumables[self.category] and Data.Consumables[self.category][1])
            or "None"
        GameTooltip:AddLine(labelText .. " Button")
        GameTooltip:AddLine("Tracking: |cFF00FF00" .. pref .. "|r", 1, 1, 1)
        GameTooltip:AddLine("Left-Click to Use", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-Click to Change Item", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Visual overlay parented to uiFrame (mouse-disabled so clicks reach btn)
    local visual = CreateFrame("Frame", nil, uiFrame, "BackdropTemplate")
    visual:SetSize(65, 30)
    visual:SetPoint("BOTTOMLEFT", uiFrame, "BOTTOMLEFT", xOffset, 15)
    visual:EnableMouse(false)
    visual:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    visual:SetBackdropColor(0.2, 0.1, 0.3, 1)
    visual:SetBackdropBorderColor(0, 0, 0, 1)

    local label = visual:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetAllPoints()
    label:SetJustifyH("CENTER")
    label:SetText(labelText)

    table.insert(secureButtons, btn)
    return btn
end

local btnFood   = CreateSecureBtn("MC_BtnFood",   "Food",       "Food",           15)
local btnFlask  = CreateSecureBtn("MC_BtnFlask",  "Flask",      "Flasks",         85)
local btnWeapon = CreateSecureBtn("MC_BtnWeapon", "Oil",        "Weapon",        155)
local btnPotion = CreateSecureBtn("MC_BtnPotion", "Combat Pot", "Potions",       225)
local btnHealth = CreateSecureBtn("MC_BtnHealth", "Health Pot", "HealthPotions", 295)

-- Keep secure buttons (parented to UIParent) in sync with uiFrame's visibility
uiFrame:HookScript("OnShow", function()
    for _, b in ipairs(secureButtons) do b:Show() end
end)
uiFrame:HookScript("OnHide", function()
    for _, b in ipairs(secureButtons) do b:Hide() end
end)

-- Sets each button's macro to "/use ItemName" based on current prefs.
-- Must be called from a clean (untainted) context only.
ApplyButtonItems = function()
    if InCombatLockdown() then return end
    local function SetBtn(btn, category)
        local item = MidnightCheckDB.Prefs[category]
            or (Data.Consumables[category] and Data.Consumables[category][1])
        btn:SetAttribute("macrotext", item and ("/use " .. item) or "")
    end
    SetBtn(btnFood,   "Food")
    SetBtn(btnFlask,  "Flasks")
    SetBtn(btnWeapon, "Weapon")
    SetBtn(btnPotion, "Potions")
    SetBtn(btnHealth, "HealthPotions")
end

-- ==========================================
-- Core Scanning Logic
-- ==========================================
function RunCheck()
    if not uiFrame:IsShown() then uiFrame:Show() end
    contentText:SetText("Scanning...")

    local _, unitClass = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex) or nil

    if not specID or not Data.Specs[unitClass] or not Data.Specs[unitClass][specID] then
        contentText:SetText("|cFFFF5555Spec data not found in database.|r")
        return
    end

    local specData = Data.Specs[unitClass][specID]
    local report = ""

    -- 1. Check Consumables & Weapon Buff
    report = report .. "|cFFCCCCCCConsumables (Counts in bags):|r\n"

    local hasFoodBuff, hasFlaskBuff = false, false
    local hasWeaponBuff = select(1, GetWeaponEnchantInfo())

    pcall(function()
        for i = 1, 40 do
            local auraName = nil
            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                if aura then auraName = aura.name end
            elseif UnitAura then
                auraName = UnitAura("player", i, "HELPFUL")
            end

            if auraName then
                if string.find(auraName, "Well Fed") then hasFoodBuff = true end
                if Data.Consumables and type(Data.Consumables.Flasks) == "table" then
                    for _, flask in pairs(Data.Consumables.Flasks) do
                        if type(flask) == "string" and string.find(auraName, flask, 1, true) then
                            hasFlaskBuff = true
                        end
                    end
                end
            end
        end
    end)

    -- Helper: scans one consumable category and updates the report
    local function ProcessConsumable(category, hasBuffFlag, isAuraCheck)
        local preferredItem = MidnightCheckDB.Prefs[category]
            or (Data.Consumables[category] and Data.Consumables[category][1])
        if not preferredItem then return end

        local count     = GetItemCount(preferredItem)
        local countText = " (|cFFFFFF00" .. count .. "|r left)"

        if isAuraCheck then
            if hasBuffFlag then
                report = report .. "   >> |cFF55FF55[OK]|r "      .. preferredItem .. countText .. "\n"
            else
                report = report .. "   >> |cFFFF5555[MISSING]|r " .. preferredItem .. countText .. "\n"
            end
        else
            if count > 0 then
                report = report .. "   >> |cFF55FF55[READY]|r " .. preferredItem .. countText .. "\n"
            else
                report = report .. "   >> |cFFFF5555[OUT]|r "    .. preferredItem .. countText .. "\n"
            end
        end

    end

    ProcessConsumable("Food",          hasFoodBuff,   true)
    ProcessConsumable("Flasks",        hasFlaskBuff,  true)
    ProcessConsumable("Weapon",        hasWeaponBuff, true)
    ProcessConsumable("Potions",       false,         false)
    ProcessConsumable("HealthPotions", false,         false)

    if InCombatLockdown() then
        report = report .. "\n|cFFFFFF00(In Combat: Buttons locked to previous state)|r\n"
    end

    -- 2. Check Enchants
    report = report .. "\n|cFFCCCCCCEnchants:|r\n"
    local allEnchantsGood = true
    pcall(function()
        if specData.Enchants then
            for slotId, expectedEnchant in pairs(specData.Enchants) do
                local numId = tonumber(slotId)
                if numId then
                    local slotName = slotNames[numId] or ("Slot " .. numId)
                    local link = GetInventoryItemLink("player", numId)
                    if not link or not string.find(link, "enchant:", 1, true) then
                        report = report .. "   >> |cFFFF5555[MISSING]|r " .. tostring(slotName)
                            .. " (|cFFB266FFNeeds: " .. tostring(expectedEnchant) .. "|r)\n"
                        allEnchantsGood = false
                    end
                end
            end
        end
    end)
    if allEnchantsGood then
        report = report .. "   >> |cFF55FF55[OK]|r All required gear enchanted.\n"
    end

    -- 3. Check Gems
    report = report .. "\n|cFFCCCCCCGems:|r\n"
    local emptySockets = 0
    pcall(function()
        for i = 1, 18 do
            local link = GetInventoryItemLink("player", i)
            if link then
                local stats = (C_Item and C_Item.GetItemStats)
                    and C_Item.GetItemStats(link)
                    or  (GetItemStats and GetItemStats(link))
                if stats and stats["EMPTY_SOCKET_PRISMATIC"] then
                    emptySockets = emptySockets + 1
                end
            end
        end
    end)
    if emptySockets > 0 then
        report = report .. "   >> |cFFFF5555[MISSING]|r " .. emptySockets .. " Empty Sockets\n"
    else
        report = report .. "   >> |cFF55FF55[OK]|r All sockets filled\n"
    end

    contentText:SetText(report)
end

-- ==========================================
-- Events, Slash Commands & Minimap
-- ==========================================
local eventListener = CreateFrame("Frame")
eventListener:RegisterEvent("PLAYER_ENTERING_WORLD")
eventListener:RegisterEvent("ADDON_LOADED")
eventListener:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        MidnightCheckDB       = MidnightCheckDB or {}
        MidnightCheckDB.Prefs = MidnightCheckDB.Prefs or {}
        ApplyButtonItems()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if select(2, GetInstanceInfo()) == "raid" then
            C_Timer.After(2, function()
                print("|cFFB266FF[MidnightCheck]|r Raid detected. Running readiness scan...")
                if not uiFrame:IsShown() then RunCheck() end
            end)
        end
    end
end)

SLASH_MIDNIGHTCHECK1 = "/mc"
SLASH_MIDNIGHTCHECK2 = "/midnight"
SlashCmdList["MIDNIGHTCHECK"] = function() RunCheck() end

-- ==========================================
-- Minimap Button
-- ==========================================
local minimapButton = CreateFrame("Button", "MidnightCheckMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = minimapButton:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(20, 20)
bg:SetPoint("CENTER")

local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetTexture(136209) -- Spell_Priest_VoidShift
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

local function UpdatePosition(angle)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local currentAngle = math.rad(225)
UpdatePosition(currentAngle)

minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
        xpos = xpos / minimapButton:GetEffectiveScale() - xmin - 70
        ypos = ypos / minimapButton:GetEffectiveScale() - ymin - 70
        currentAngle = math.atan2(ypos, xpos)
        UpdatePosition(currentAngle)
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnClick", function()
    if uiFrame:IsShown() then
        uiFrame:Hide()
    else
        RunCheck()
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cFFB266FFMidnight Readiness|r")
    GameTooltip:AddLine("Left-Click to scan your gear.")
    GameTooltip:AddLine("Drag to move this button.")
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
