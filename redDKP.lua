local ADDON_NAME = ...

--------------------------------------------------
-- SAVED VARIABLES / CORE
--------------------------------------------------

RedDKP_Data      = RedDKP_Data      or {}
RedDKP_Config    = RedDKP_Config    or {}
RedDKP_LastSync  = RedDKP_LastSync  or 0

local function EnsureSaved()
    RedDKP_Data   = RedDKP_Data   or {}
    RedDKP_Config = RedDKP_Config or {}

    RedDKP_Config.authorizedEditors = RedDKP_Config.authorizedEditors or {}
    RedDKP_Config.sortField         = RedDKP_Config.sortField         or "player"
    if RedDKP_Config.sortAscending == nil then
        RedDKP_Config.sortAscending = true
    end
    RedDKP_Config.minimapAngle = RedDKP_Config.minimapAngle or 45
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555RedDKP|r: " .. tostring(msg))
end

local function IsAuthorized()
    EnsureSaved()
    local name = UnitName("player")
    return RedDKP_Config.authorizedEditors[name] == true
end

local function EnsurePlayer(name)
    EnsureSaved()
    if not RedDKP_Data[name] then
        RedDKP_Data[name] = {
            rotated    = false,
            lastWeek   = 0,
            onTime     = 0,
            attendance = 0,
            bench      = 0,
            spent      = 0,
            balance    = 0,
        }
    end
    return RedDKP_Data[name]
end

--------------------------------------------------
-- MAIN WINDOW (CUSTOM FRAME)
--------------------------------------------------

local ROWS_VISIBLE = 12
local sortedNames  = {}

local mainFrame = CreateFrame("Frame", "RedDKPFrame", UIParent)
mainFrame:SetSize(720, 380)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetClampedToScreen(true)
mainFrame:Hide()

mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
mainFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

-- Background
local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
bg:SetVertexColor(0, 0, 0, 0.85)

-- Border
local border = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
})
border:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

-- Title bar
local titleBar = mainFrame:CreateTexture(nil, "ARTWORK")
titleBar:SetPoint("TOPLEFT", 4, -4)
titleBar:SetPoint("TOPRIGHT", -4, -4)
titleBar:SetHeight(24)
titleBar:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
titleBar:SetVertexColor(0.15, 0.15, 0.15, 1)

local titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
titleText:SetPoint("CENTER", titleBar, "CENTER", 0, -1)
titleText:SetText("Redemptions DKP")

local closeButton = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -4, -4)

--------------------------------------------------
-- TABS (DKP / OPTIONS / EXPORT)
--------------------------------------------------

local tabs = {}
local function CreateTab(index, text)
    local tab = CreateFrame("Button", "RedDKPTab"..index, mainFrame, "CharacterFrameTabButtonTemplate")
    tab:SetText(text)
    PanelTemplates_TabResize(tab, 0)
    if index == 1 then
        tab:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 5, 2)
    else
        tab:SetPoint("LEFT", tabs[index-1], "RIGHT", -15, 0)
    end
    tabs[index] = tab
    return tab
end

local TAB_DKP    = 1
local TAB_OPTIONS= 2
local TAB_EXPORT = 3

CreateTab(TAB_DKP,    "DKP")
CreateTab(TAB_OPTIONS,"Editors / Options")
CreateTab(TAB_EXPORT, "Export")

local activeTab = TAB_DKP

local function ShowTab(tab)
    activeTab = tab
    for i, t in ipairs(tabs) do
        if i == tab then
            PanelTemplates_SelectTab(t)
        else
            PanelTemplates_DeselectTab(t)
        end
    end
end

--------------------------------------------------
-- PANELS
--------------------------------------------------

local dkpPanel     = CreateFrame("Frame", nil, mainFrame)
local optionsPanel = CreateFrame("Frame", nil, mainFrame)
local exportPanel  = CreateFrame("Frame", nil, mainFrame)

local function LayoutPanel(panel)
    panel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -32)
    panel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)
end

LayoutPanel(dkpPanel)
LayoutPanel(optionsPanel)
LayoutPanel(exportPanel)

local function UpdatePanelVisibility()
    dkpPanel:Hide()
    optionsPanel:Hide()
    exportPanel:Hide()

    if activeTab == TAB_DKP then
        dkpPanel:Show()
    elseif activeTab == TAB_OPTIONS then
        optionsPanel:Show()
    elseif activeTab == TAB_EXPORT then
        exportPanel:Show()
    end
end

for i, tab in ipairs(tabs) do
    tab:SetScript("OnClick", function()
        ShowTab(i)
        UpdatePanelVisibility()
    end)
end

ShowTab(TAB_DKP)
UpdatePanelVisibility()

--------------------------------------------------
-- DKP TABLE UI (IN DKP PANEL)
--------------------------------------------------

local headers = {
    { text = "Player",    width = 140 },
    { text = "Rotated",   width = 70  },
    { text = "LastWeek",  width = 80  },
    { text = "OnTime",    width = 60  },
    { text = "Attend",    width = 60  },
    { text = "Bench",     width = 60  },
    { text = "Spent",     width = 60  },
    { text = "Balance",   width = 80  },
}

local fieldMap = {
    [1] = "player",
    [2] = "rotated",
    [3] = "lastWeek",
    [4] = "onTime",
    [5] = "attendance",
    [6] = "bench",
    [7] = "spent",
    [8] = "balance",
}

local headerFrame = CreateFrame("Frame", nil, dkpPanel)
headerFrame:SetSize(660, 20)
headerFrame:SetPoint("TOPLEFT", dkpPanel, "TOPLEFT", 20, -10)

local headerButtons = {}
do
    local x = 0
    for i, h in ipairs(headers) do
        local btn = CreateFrame("Button", nil, headerFrame)
        btn:SetPoint("LEFT", headerFrame, "LEFT", x, 0)
        btn:SetSize(h.width, 20)

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", 0, 0)
        fs:SetWidth(h.width)
        fs:SetJustifyH("LEFT")
        fs:SetText(h.text)

        btn.text = fs
        headerButtons[i] = btn

        btn:SetScript("OnMouseDown", function()
            local field = fieldMap[i]
            if RedDKP_Config.sortField == field then
                RedDKP_Config.sortAscending = not RedDKP_Config.sortAscending
            else
                RedDKP_Config.sortField = field
                RedDKP_Config.sortAscending = true
            end
            UpdateTable()
        end)

        x = x + h.width
    end
end

local scrollFrame = CreateFrame("ScrollFrame", "RedDKPScrollFrame", dkpPanel, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -5)
scrollFrame:SetSize(660, 260)

local rows = {}
for i = 1, ROWS_VISIBLE do
    local row = CreateFrame("Button", nil, dkpPanel)
    row:SetSize(660, 18)

    if i == 1 then
        row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, -2)
    end

    row.cols = {}
    local colX = 0

    for j, h in ipairs(headers) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", row, "LEFT", colX, 0)
        fs:SetWidth(h.width)
        fs:SetJustifyH("LEFT")
        row.cols[j] = fs
        colX = colX + h.width
    end

    rows[i] = row
end

local function SortPlayers()
    table.sort(sortedNames, function(a, b)
        local field = RedDKP_Config.sortField
        local asc   = RedDKP_Config.sortAscending

        if field == "player" then
            return asc and a < b or a > b
        end

        local da = RedDKP_Data[a][field] or 0
        local db = RedDKP_Data[b][field] or 0

        return asc and da < db or da > db
    end)
end

local function RefreshSortedNames()
    EnsureSaved()
    wipe(sortedNames)
    for name in pairs(RedDKP_Data) do
        table.insert(sortedNames, name)
    end
    SortPlayers()
end

function UpdateTable()
    EnsureSaved()
    RefreshSortedNames()

    local total = #sortedNames
    FauxScrollFrame_Update(scrollFrame, total, ROWS_VISIBLE, 20)

    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    for i = 1, ROWS_VISIBLE do
        local index = i + offset
        local row   = rows[i]

        if index <= total then
            local name = sortedNames[index]
            local d    = RedDKP_Data[name]

            row.cols[1]:SetText(name)
            row.cols[2]:SetText(d.rotated and "Yes" or "")
            row.cols[3]:SetText(d.lastWeek   or 0)
            row.cols[4]:SetText(d.onTime     or 0)
            row.cols[5]:SetText(d.attendance or 0)
            row.cols[6]:SetText(d.bench      or 0)
            row.cols[7]:SetText(d.spent      or 0)
            row.cols[8]:SetText(d.balance    or 0)

            row:Show()
        else
            row:Hide()
        end
    end
end

scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, 20, UpdateTable)
end)

--------------------------------------------------
-- SLASH COMMANDS (CORE)
--------------------------------------------------

local validFields = {
    rotated    = true,
    lastWeek   = true,
    onTime     = true,
    attendance = true,
    bench      = true,
    spent      = true,
    balance    = true,
}

local function HandleSet(player, field, value)
    if not IsAuthorized() then
        Print("You are not authorized to modify data.")
        return
    end

    if not player or not field or not value then
        Print("Usage: /reddkp set <player> <field> <value>")
        return
    end

    field = string.lower(field)

    if not validFields[field] then
        Print("Invalid field. Valid: rotated, lastWeek, onTime, attendance, bench, spent, balance")
        return
    end

    local data = EnsurePlayer(player)

    if field == "rotated" then
        value = string.lower(value)
        data.rotated = (value == "yes" or value == "true" or value == "1")
    else
        local num = tonumber(value)
        if not num then
            Print("Value must be a number for field " .. field)
            return
        end
        data[field] = num
    end

    Print("Updated " .. player .. " " .. field .. " = " .. tostring(value))
    UpdateTable()
end

local function HandleEditorSlash(subcmd, name)
    EnsureSaved()
    if not IsAuthorized() then
        Print("You are not authorized to change editor list.")
        return
    end
    if not name or name == "" then
        Print("Usage: /reddkp " .. subcmd .. " <CharacterName>")
        return
    end

    if subcmd == "addeditor" then
        RedDKP_Config.authorizedEditors[name] = true
        Print("Added editor: " .. name)
    elseif subcmd == "removeeditor" then
        RedDKP_Config.authorizedEditors[name] = nil
        Print("Removed editor: " .. name)
    end
end

local function ListEditors()
    EnsureSaved()
    Print("Authorized editors:")
    for name in pairs(RedDKP_Config.authorizedEditors) do
        Print(" - " .. name)
    end
end

SLASH_REDDKP1 = "/reddkp"
SLASH_REDDKP2 = "/redDKP"

SlashCmdList["REDDKP"] = function(msg)
    EnsureSaved()
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "show" then
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            ShowTab(TAB_DKP)
            UpdatePanelVisibility()
            UpdateTable()
            mainFrame:Show()
        end
        return
    end

    if cmd == "set" then
        local player, field, value = rest:match("^(%S+)%s+(%S+)%s+(.+)$")
        HandleSet(player, field, value)
        return
    end

    if cmd == "addeditor" or cmd == "removeeditor" then
        local name = rest:match("^(%S+)$")
        HandleEditorSlash(cmd, name)
        return
    end

    if cmd == "listeditors" then
        ListEditors()
        return
    end

    Print("Commands:")
    Print("/redDKP or /reddkp show - toggle DKP window")
    Print("/reddkp set <player> <field> <value>")
    Print("   fields: rotated, lastWeek, onTime, attendance, bench, spent, balance")
    Print("/reddkp addeditor <name>")
    Print("/reddkp removeeditor <name>")
    Print("/reddkp listeditors")
end

--------------------------------------------------
-- INIT
--------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == ADDON_NAME then
        EnsureSaved()
    end
end)

--------------------------------------------------
-- OPTIONS PANEL (INSIDE MAIN WINDOW)
--------------------------------------------------

local optTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
optTitle:SetPoint("TOPLEFT", 10, -10)
optTitle:SetText("RedDKP Editors & Sort Options")

local subtitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", optTitle, "BOTTOMLEFT", 0, -4)
subtitle:SetText("Manage who can edit DKP and how the table is sorted by default.")

--------------------------------------------------
-- EDITOR LIST BACKGROUND
--------------------------------------------------

local listBG = CreateFrame("Frame", nil, optionsPanel)
listBG:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
listBG:SetSize(260, 200)

local listBGTex = listBG:CreateTexture(nil, "BACKGROUND")
listBGTex:SetAllPoints()
listBGTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
listBGTex:SetVertexColor(0, 0, 0, 0.4)

local function CreateBorderPiece(parent)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    return t
end

local border2 = {}
border2.top = CreateBorderPiece(listBG)
border2.top:SetPoint("TOPLEFT", -4, 4)
border2.top:SetPoint("TOPRIGHT", 4, 4)
border2.top:SetHeight(8)

border2.bottom = CreateBorderPiece(listBG)
border2.bottom:SetPoint("BOTTOMLEFT", -4, -4)
border2.bottom:SetPoint("BOTTOMRIGHT", 4, -4)
border2.bottom:SetHeight(8)

border2.left = CreateBorderPiece(listBG)
border2.left:SetPoint("TOPLEFT", -4, 4)
border2.left:SetPoint("BOTTOMLEFT", -4, -4)
border2.left:SetWidth(8)

border2.right = CreateBorderPiece(listBG)
border2.right:SetPoint("TOPRIGHT", 4, 4)
border2.right:SetPoint("BOTTOMRIGHT", 4, -4)
border2.right:SetWidth(8)

--------------------------------------------------
-- EDITOR LIST SCROLL FRAME
--------------------------------------------------

local scroll = CreateFrame("ScrollFrame", "RedDKPEditorsScroll", listBG, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, -4)
scroll:SetPoint("BOTTOMRIGHT", -26, 4)

local editorRows = {}
local EDITOR_ROWS = 10

for i = 1, EDITOR_ROWS do
    local row = CreateFrame("Button", nil, listBG)
    row:SetSize(230, 18)

    if i == 1 then
        row:SetPoint("TOPLEFT", listBG, "TOPLEFT", 6, -6)
    else
        row:SetPoint("TOPLEFT", editorRows[i-1], "BOTTOMLEFT", 0, -2)
    end

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 4, 0)

    row:SetScript("OnClick", function(self)
        for _, r in ipairs(editorRows) do
            r.text:SetTextColor(1, 1, 1)
        end
        self.text:SetTextColor(1, 0.82, 0)
        optionsPanel.selectedEditor = self.text:GetText()
    end)

    editorRows[i] = row
end

local function RefreshEditorList()
    EnsureSaved()
    local editors = {}

    for name in pairs(RedDKP_Config.authorizedEditors) do
        table.insert(editors, name)
    end
    table.sort(editors)

    optionsPanel.editorList = editors

    FauxScrollFrame_Update(scroll, #editors, EDITOR_ROWS, 18)
    local offset = FauxScrollFrame_GetOffset(scroll)

    for i = 1, EDITOR_ROWS do
        local index = i + offset
        local row   = editorRows[i]

        if editors[index] then
            row.text:SetText(editors[index])
            row:Show()
        else
            row.text:SetText("")
            row:Hide()
        end
    end
end

scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, 18, RefreshEditorList)
end)

--------------------------------------------------
-- ADD / REMOVE EDITOR
--------------------------------------------------

local addBox = CreateFrame("EditBox", nil, optionsPanel, "InputBoxTemplate")
addBox:SetSize(160, 28)
addBox:SetPoint("TOPLEFT", listBG, "TOPRIGHT", 20, -10)
addBox:SetAutoFocus(false)

local addLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
addLabel:SetPoint("BOTTOMLEFT", addBox, "TOPLEFT", 0, 4)
addLabel:SetText("Add Editor")

local addButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
addButton:SetSize(80, 24)
addButton:SetPoint("LEFT", addBox, "RIGHT", 10, 0)
addButton:SetText("Add")

addButton:SetScript("OnClick", function()
    local name = addBox:GetText():gsub("%s+", "")
    if name == "" then return end

    EnsureSaved()
    RedDKP_Config.authorizedEditors[name] = true
    addBox:SetText("")
    RefreshEditorList()
end)

local removeButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
removeButton:SetSize(120, 24)
removeButton:SetPoint("TOPLEFT", addBox, "BOTTOMLEFT", 0, -20)
removeButton:SetText("Remove Selected")

removeButton:SetScript("OnClick", function()
    local name = optionsPanel.selectedEditor
    if not name then return end

    EnsureSaved()
    RedDKP_Config.authorizedEditors[name] = nil
    optionsPanel.selectedEditor = nil
    RefreshEditorList()
end)

--------------------------------------------------
-- SORT OPTIONS
--------------------------------------------------

local sortLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sortLabel:SetPoint("TOPLEFT", removeButton, "BOTTOMLEFT", 0, -30)
sortLabel:SetText("Default Sort Column")

local sortDropdown = CreateFrame("Frame", "RedDKPSortDropdown", optionsPanel, "UIDropDownMenuTemplate")
sortDropdown:SetPoint("TOPLEFT", sortLabel, "BOTTOMLEFT", -15, -5)

local sortFields = {
    { text = "Player",     value = "player" },
    { text = "Rotated",    value = "rotated" },
    { text = "Last Week",  value = "lastWeek" },
    { text = "On Time",    value = "onTime" },
    { text = "Attendance", value = "attendance" },
    { text = "Bench",      value = "bench" },
    { text = "Spent",      value = "spent" },
    { text = "Balance",    value = "balance" },
}

local function SortDropdown_OnClick(self)
    RedDKP_Config.sortField = self.value
    UIDropDownMenu_SetSelectedValue(sortDropdown, self.value)
    UpdateTable()
end

UIDropDownMenu_Initialize(sortDropdown, function(self, level)
    for _, info in ipairs(sortFields) do
        local item = UIDropDownMenu_CreateInfo()
        item.text  = info.text
        item.value = info.value
        item.func  = SortDropdown_OnClick
        UIDropDownMenu_AddButton(item)
    end
end)

local ascCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
ascCheck:SetPoint("LEFT", sortDropdown, "RIGHT", 40, 0)
ascCheck.text:SetText("Ascending")

ascCheck:SetScript("OnClick", function(self)
    RedDKP_Config.sortAscending = self:GetChecked()
    UpdateTable()
end)

optionsPanel:SetScript("OnShow", function()
    RefreshEditorList()
    UIDropDownMenu_SetSelectedValue(sortDropdown, RedDKP_Config.sortField)
    ascCheck:SetChecked(RedDKP_Config.sortAscending)
end)

--------------------------------------------------
-- EXPORT PANEL (CSV / JSON / XML)
--------------------------------------------------

local exportTitle = exportPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
exportTitle:SetPoint("TOPLEFT", 10, -10)
exportTitle:SetText("Export DKP Data")

local exportDesc = exportPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
exportDesc:SetPoint("TOPLEFT", exportTitle, "BOTTOMLEFT", 0, -4)
exportDesc:SetText("Copy and paste this data into external tools or spreadsheets.")

local formatLabel = exportPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
formatLabel:SetPoint("TOPLEFT", exportDesc, "BOTTOMLEFT", 0, -10)
formatLabel:SetText("Format")

local formatDropdown = CreateFrame("Frame", "RedDKPExportFormatDropdown", exportPanel, "UIDropDownMenuTemplate")
formatDropdown:SetPoint("TOPLEFT", formatLabel, "BOTTOMLEFT", -15, -5)

local EXPORT_FORMATS = {
    { text = "CSV",  value = "csv"  },
    { text = "JSON", value = "json" },
    { text = "XML",  value = "xml"  },
}

local currentExportFormat = "csv"

local function GenerateCSV()
    EnsureSaved()
    local lines = {}
    table.insert(lines, "Player,Rotated,LastWeek,OnTime,Attendance,Bench,Spent,Balance")

    for name, d in pairs(RedDKP_Data) do
        table.insert(lines,
            string.format("%s,%s,%d,%d,%d,%d,%d,%d",
                name,
                d.rotated and "Yes" or "No",
                d.lastWeek   or 0,
                d.onTime     or 0,
                d.attendance or 0,
                d.bench      or 0,
                d.spent      or 0,
                d.balance    or 0
            )
        )
    end

    return table.concat(lines, "\n")
end

local function GenerateJSON()
    EnsureSaved()
    local parts = {}
    table.insert(parts, "{")

    local first = true
    for name, d in pairs(RedDKP_Data) do
        if not first then
            table.insert(parts, ",")
        end
        first = false

        table.insert(parts, string.format(
            "\"%s\":{\"rotated\":%s,\"lastWeek\":%d,\"onTime\":%d,\"attendance\":%d,\"bench\":%d,\"spent\":%d,\"balance\":%d}",
            name,
            d.rotated and "true" or "false",
            d.lastWeek   or 0,
            d.onTime     or 0,
            d.attendance or 0,
            d.bench      or 0,
            d.spent      or 0,
            d.balance    or 0
        ))
    end

    table.insert(parts, "}")
    return table.concat(parts, "")
end

local function GenerateXML()
    EnsureSaved()
    local lines = {}
    table.insert(lines, "<RedDKP>")

    for name, d in pairs(RedDKP_Data) do
        table.insert(lines, string.format(
            "  <Player name=\"%s\" rotated=\"%s\" lastWeek=\"%d\" onTime=\"%d\" attendance=\"%d\" bench=\"%d\" spent=\"%d\" balance=\"%d\" />",
            name,
            d.rotated and "true" or "false",
            d.lastWeek   or 0,
            d.onTime     or 0,
            d.attendance or 0,
            d.bench      or 0,
            d.spent      or 0,
            d.balance    or 0
        ))
    end

    table.insert(lines, "</RedDKP>")
    return table.concat(lines, "\n")
end

local exportScroll = CreateFrame("ScrollFrame", "RedDKPExportScroll", exportPanel, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", formatDropdown, "BOTTOMLEFT", 16, -10)
exportScroll:SetPoint("BOTTOMRIGHT", -30, 10)

local exportEditBox = CreateFrame("EditBox", nil, exportScroll)
exportEditBox:SetMultiLine(true)
exportEditBox:SetFontObject(ChatFontNormal)
exportEditBox:SetWidth(640)
exportEditBox:SetAutoFocus(false)
exportScroll:SetScrollChild(exportEditBox)

local function RefreshExportText()
    local text
    if currentExportFormat == "csv" then
        text = GenerateCSV()
    elseif currentExportFormat == "json" then
        text = GenerateJSON()
    elseif currentExportFormat == "xml" then
        text = GenerateXML()
    end
    exportEditBox:SetText(text or "")
    exportEditBox:HighlightText()
end

local function ExportFormat_OnClick(self)
    currentExportFormat = self.value
    UIDropDownMenu_SetSelectedValue(formatDropdown, self.value)
    RefreshExportText()
end

UIDropDownMenu_Initialize(formatDropdown, function(self, level)
    for _, info in ipairs(EXPORT_FORMATS) do
        local item = UIDropDownMenu_CreateInfo()
        item.text  = info.text
        item.value = info.value
        item.func  = ExportFormat_OnClick
        UIDropDownMenu_AddButton(item)
    end
end)

exportPanel:SetScript("OnShow", function()
    UIDropDownMenu_SetSelectedValue(formatDropdown, currentExportFormat)
    RefreshExportText()
end)

--------------------------------------------------
-- GUILD SYNC SYSTEM (CLEANED)
--------------------------------------------------

local SYNC_PREFIX = "REDDKP_SYNC"
local CHUNK_SIZE  = 220

local function SerializeTable(tbl)
    local out = {}

    for name, d in pairs(tbl) do
        table.insert(out,
            name .. ";" ..
            (d.rotated and "1" or "0") .. ";" ..
            (d.lastWeek   or 0) .. ";" ..
            (d.onTime     or 0) .. ";" ..
            (d.attendance or 0) .. ";" ..
            (d.bench      or 0) .. ";" ..
            (d.spent      or 0) .. ";" ..
            (d.balance    or 0)
        )
    end

    return table.concat(out, "|")
end

local function DeserializeTable(str)
    local result = {}

    for entry in string.gmatch(str, "([^|]+)") do
        local name, rot, lw, ot, att, bench, spent, bal =
            string.match(entry, "([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+)")

        if name then
            result[name] = {
                rotated    = rot == "1",
                lastWeek   = tonumber(lw)   or 0,
                onTime     = tonumber(ot)   or 0,
                attendance = tonumber(att)  or 0,
                bench      = tonumber(bench)or 0,
                spent      = tonumber(spent)or 0,
                balance    = tonumber(bal)  or 0,
            }
        end
    end

    return result
end

local function SendChunked(prefix, msg, channel)
    local total = math.ceil(#msg / CHUNK_SIZE)

    for i = 1, total do
        local chunk = string.sub(msg, (i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE)
        SendAddonMessage(prefix, i .. "/" .. total .. ":" .. chunk, channel)
    end
end

local function BroadcastDKP()
    if not IsAuthorized() then
        Print("You are not authorized to broadcast DKP data.")
        return
    end

    EnsureSaved()

    local serialized = SerializeTable(RedDKP_Data)
    local timestamp  = time()

    Print("Broadcasting DKP data to guild...")

    SendChunked(SYNC_PREFIX, timestamp .. "#" .. serialized, "GUILD")
end

local incomingChunks   = {}
local expectedChunks   = 0
local receivedChunks   = 0
local incomingTimestamp= 0

local function ResetIncoming()
    incomingChunks    = {}
    expectedChunks    = 0
    receivedChunks    = 0
    incomingTimestamp = 0
end

local function ProcessFullSync()
    local full = table.concat(incomingChunks, "")
    local ts, data = string.match(full, "^(%d+)#(.+)$")

    ts = tonumber(ts or 0)

    if ts <= RedDKP_LastSync then
        Print("Received DKP sync, but it is not newer than your current data.")
        return
    end

    RedDKP_LastSync = ts
    RedDKP_Data     = DeserializeTable(data)

    Print("DKP sync complete. Updated to timestamp " .. ts)
    UpdateTable()
end

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("CHAT_MSG_ADDON")

syncFrame:SetScript("OnEvent", function(_, _, prefix, msg, channel, sender)
    if prefix ~= SYNC_PREFIX then return end

    local header, chunk = string.match(msg, "^(%d+/%d+):(.+)$")
    if not header then return end

    local index, total = string.match(header, "^(%d+)%/(%d+)$")
    index = tonumber(index)
    total = tonumber(total)

    if not index or not total then return end

    if index == 1 then
        ResetIncoming()
        expectedChunks = total
    end

    incomingChunks[index] = chunk
    receivedChunks        = receivedChunks + 1

    if receivedChunks == expectedChunks then
        ProcessFullSync()
    end
end)

local function RequestSync()
    Print("Requesting DKP sync from guild editors...")
    SendAddonMessage(SYNC_PREFIX, "REQUEST", "GUILD")
end

local requestFrame = CreateFrame("Frame")
requestFrame:RegisterEvent("CHAT_MSG_ADDON")

requestFrame:SetScript("OnEvent", function(_, _, prefix, msg, channel, sender)
    if prefix ~= SYNC_PREFIX then return end
    if msg ~= "REQUEST" then return end

    if IsAuthorized() then
        Print("Responding to sync request from " .. sender)
        BroadcastDKP()
    end
end)

SlashCmdList["REDDKP_SYNC"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "sync" then
        RequestSync()
        return
    end

    if msg == "broadcast" then
        BroadcastDKP()
        return
    end

    Print("Sync commands:")
    Print("/reddkpsync sync - request DKP data from editors")
    Print("/reddkpsync broadcast - send your DKP table to guild")
end

SLASH_REDDKP_SYNC1 = "/reddkpsync"

--------------------------------------------------
-- MINIMAP BUTTON (LDB + FALLBACK + SEXYMAP)
--------------------------------------------------

local function OpenMainToOptions()
    ShowTab(TAB_OPTIONS)
    UpdatePanelVisibility()
    if not mainFrame:IsShown() then
        mainFrame:Show()
    end
end

local function ToggleMainToDKP()
    if mainFrame:IsShown() and activeTab == TAB_DKP then
        mainFrame:Hide()
    else
        ShowTab(TAB_DKP)
        UpdatePanelVisibility()
        UpdateTable()
        mainFrame:Show()
    end
end

-- LDB launcher if available
local ldb
if LibStub then
    ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
end

if ldb then
    ldb:NewDataObject("RedDKP", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        label = "RedDKP",

        OnClick = function(_, button)
            if button == "LeftButton" then
                ToggleMainToDKP()
            elseif button == "RightButton" then
                OpenMainToOptions()
            end
        end,

        OnTooltipShow = function(tt)
            tt:AddLine("RedDKP")
            tt:AddLine("Left-click: Open DKP Window", 1, 1, 1)
            tt:AddLine("Right-click: Editors / Options", 1, 1, 1)
        end,
    })
end

-- Fallback minimap button
local function CreateFallbackMinimapButton()
    local mini = CreateFrame("Button", "RedDKPMiniMapButton", Minimap)
    mini:SetSize(32, 32)
    mini:SetFrameStrata("MEDIUM")
    mini:SetFrameLevel(8)

    mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    mini.icon = mini:CreateTexture(nil, "ARTWORK")
    mini.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    mini.icon:SetSize(20, 20)
    mini.icon:SetPoint("CENTER")

    mini:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("RedDKP")
        GameTooltip:AddLine("Left-click: Open DKP Window", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Editors / Options", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move around minimap", 1, 1, 1)
        GameTooltip:Show()
    end)

    mini:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    mini.OnClickHandler = function(self, button)
        if button == "LeftButton" then
            ToggleMainToDKP()
        elseif button == "RightButton" then
            OpenMainToOptions()
        end
    end

    mini:SetScript("OnClick", mini.OnClickHandler)

    local function UpdateMinimapButtonPosition()
        local angle = math.rad(RedDKP_Config.minimapAngle or 45)
        local x = 52 * math.cos(angle)
        local y = 52 * math.sin(angle)
        mini:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    if not SexyMap then
        mini:RegisterForDrag("LeftButton")

        mini:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local px, py = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale()

                px = px / scale
                py = py / scale

                local angle = math.deg(math.atan2(py - my, px - mx))
                RedDKP_Config.minimapAngle = angle

                UpdateMinimapButtonPosition()
            end)
        end)

        mini:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
        end)
    end

    UpdateMinimapButtonPosition()

    local function RegisterWithSexyMap()
        if not SexyMap or not SexyMap.AddButton then
            return false
        end

        SexyMap:AddButton(mini)
        mini:SetScript("OnClick", mini.OnClickHandler)
        return true
    end

    local smOK = RegisterWithSexyMap()
    if not smOK then
        local smWatcher = CreateFrame("Frame")
        smWatcher:RegisterEvent("ADDON_LOADED")
        smWatcher:SetScript("OnEvent", function(_, _, addon)
            if addon == "SexyMap" then
                RegisterWithSexyMap()
            end
        end)
    end
end

if not ldb then
    CreateFallbackMinimapButton()
end