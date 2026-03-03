local ADDON_NAME = ...

local DEFAULTS = {
  displayMyKeystone = true,
  showOnlyInPVEFrame = true,
  locked = true,
  debug = false,
  welcome = true,
  autoWidth = true,
  fontName = "Fira Mono Medium",
  customPosition = false,
  point = "TOPLEFT",
  relativePoint = "TOPLEFT",
  x = 360,
  y = -140,
}

local function CopyDefaultsInto(dst, defaults)
  if type(dst) ~= "table" then
    dst = {}
  end
  for k, v in pairs(defaults) do
    if dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

local function GetDB()
  MythicPlusProgressDB = CopyDefaultsInto(MythicPlusProgressDB, DEFAULTS)
  return MythicPlusProgressDB
end

local function SafeWrapColor(color, text)
  if color and type(color.WrapTextInColorCode) == "function" then
    return color:WrapTextInColorCode(text)
  end
  return text
end

local function SafeGetColor(fn, ...)
  if type(fn) == "function" then
    local ok, color = pcall(fn, ...)
    if ok then
      return color
    end
  end
  return nil
end

local COLOR_NOT_DONE_YELLOW = "|cffffff63"
local COLOR_OK_GREEN = "|cff73ff73"
local COLOR_KO_RED = "|cffF55660"
local COLOR_WHITE = "|cffffffff"
local COLOR_GREY = "|cffC0C0C0"

local state = {
  mapIDs = nil,
  dungeonTimers = {},
}

local ui = {
  frame = nil,
  content = nil,
  rows = {},
  measure = nil,
}

local VALID_ANCHOR_POINTS = {
  TOPLEFT = true,
  TOP = true,
  TOPRIGHT = true,
  LEFT = true,
  CENTER = true,
  RIGHT = true,
  BOTTOMLEFT = true,
  BOTTOM = true,
  BOTTOMRIGHT = true,
}

local EnsureUI

local function DPrint(db, msg)
  if db and db.debug then
    print(string.format("%s: %s", ADDON_NAME, msg))
  end
end

local function TryLoadPVEFrame()
  if type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then
    pcall(C_AddOns.LoadAddOn, "Blizzard_PVEFrame")
    return
  end
  if type(LoadAddOn) == "function" then
    pcall(LoadAddOn, "Blizzard_PVEFrame")
  end
end

local function ResolveFont(db)
  local size = 12
  local flags = "OUTLINE"

  local function fallback()
    return "Fonts\\FRIZQT__.TTF", size, flags
  end

  local fontName = (db and db.fontName) or DEFAULTS.fontName
  if fontName == "Default" then
    return fallback()
  end

  if type(LibStub) == "function" then
    local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok and lsm and type(lsm.Fetch) == "function" then
      local path = lsm:Fetch("font", fontName, true)
      if type(path) == "string" and path ~= "" then
        return path, size, flags
      end
    end
  end

  return fallback()
end

local function ApplyFont(db)
  local fontPath, fontSize, fontFlags = ResolveFont(db)
  for _, row in ipairs(ui.rows) do
    if row and row.fontStrings then
      for _, fs in ipairs(row.fontStrings) do
        if fs and fs.SetFont then
          fs:SetFont(fontPath, fontSize, fontFlags)
        end
      end
    end
  end
  if ui.measure and ui.measure.SetFont then
    ui.measure:SetFont(fontPath, fontSize, fontFlags)
  end
end

local function GetLineHeight(db)
  local _, fontSize = ResolveFont(db)
  fontSize = tonumber(fontSize) or 12
  return fontSize + 2
end

local function MeasureText(db, text)
  EnsureUI(db)
  if not ui.measure then
    return 0
  end
  ui.measure:SetText(text or "")
  ui.measure:SetWidth(0)
  ui.measure:SetWordWrap(false)
  if ui.measure.SetMaxLines then
    ui.measure:SetMaxLines(1)
  end
  local w = ui.measure:GetStringWidth()
  if type(w) ~= "number" then
    return 0
  end
  return w
end

local function EnsureRow(index, db)
  if ui.rows[index] then
    return ui.rows[index]
  end

  local rowFrame = CreateFrame("Frame", nil, ui.content)
  rowFrame:SetHeight(GetLineHeight(db))
  if rowFrame.SetClipsChildren then
    rowFrame:SetClipsChildren(true)
  end

  local score = rowFrame:CreateFontString(nil, "ARTWORK")
  score:SetJustifyH("RIGHT")
  score:SetJustifyV("TOP")
  score:SetWordWrap(false)
  if score.SetMaxLines then
    score:SetMaxLines(1)
  end

  local levelContainer = CreateFrame("Frame", nil, rowFrame)
  levelContainer:SetHeight(GetLineHeight(db))
  if levelContainer.SetClipsChildren then
    levelContainer:SetClipsChildren(true)
  end

  local levelPrefix = levelContainer:CreateFontString(nil, "ARTWORK")
  levelPrefix:SetJustifyH("RIGHT")
  levelPrefix:SetJustifyV("TOP")
  levelPrefix:SetWordWrap(false)
  if levelPrefix.SetMaxLines then
    levelPrefix:SetMaxLines(1)
  end

  local levelNumber = levelContainer:CreateFontString(nil, "ARTWORK")
  levelNumber:SetJustifyH("RIGHT")
  levelNumber:SetJustifyV("TOP")
  levelNumber:SetWordWrap(false)
  if levelNumber.SetMaxLines then
    levelNumber:SetMaxLines(1)
  end

  local name = rowFrame:CreateFontString(nil, "ARTWORK")
  name:SetJustifyH("LEFT")
  name:SetJustifyV("TOP")
  name:SetWordWrap(false)
  if name.SetMaxLines then
    name:SetMaxLines(1)
  end

  local fontPath, fontSize, fontFlags = ResolveFont(db)
  score:SetFont(fontPath, fontSize, fontFlags)
  levelPrefix:SetFont(fontPath, fontSize, fontFlags)
  levelNumber:SetFont(fontPath, fontSize, fontFlags)
  name:SetFont(fontPath, fontSize, fontFlags)

  local row = {
    frame = rowFrame,
    score = score,
    levelContainer = levelContainer,
    levelPrefix = levelPrefix,
    levelNumber = levelNumber,
    name = name,
    fontStrings = { score, levelPrefix, levelNumber, name },
  }

  ui.rows[index] = row
  return row
end

local function SetDisplayRows(db, rows)
  EnsureUI(db)

  local lineHeight = GetLineHeight(db)
  local padding = 8
  local gap = 8

  local scoreWidthWanted = 0
  local levelPrefixWidthWanted = 0
  local levelNumberWidthWanted = 0
  local nameWidthWanted = 0
  local fullWidthWanted = 0

  for _, rowData in ipairs(rows) do
    if rowData.kind == "full" then
      fullWidthWanted = math.max(fullWidthWanted, MeasureText(db, rowData.text or ""))
    else
      scoreWidthWanted = math.max(scoreWidthWanted, MeasureText(db, rowData.scoreText or ""))
      levelPrefixWidthWanted = math.max(levelPrefixWidthWanted, MeasureText(db, rowData.levelPrefixText or ""))
      levelNumberWidthWanted = math.max(levelNumberWidthWanted, MeasureText(db, rowData.levelNumberText or ""))
      nameWidthWanted = math.max(nameWidthWanted, MeasureText(db, rowData.nameText or ""))
    end
  end

  local scoreWidth = math.max(40, math.ceil(scoreWidthWanted + 6))
  local levelPrefixWidth = math.ceil(levelPrefixWidthWanted + 1)
  local levelNumberWidthMax = math.max(24, math.ceil(levelNumberWidthWanted + 6))
  local levelCellWidth = math.max(44, levelPrefixWidth + levelNumberWidthMax)
  local nameColsWidth = math.max(120, math.ceil(nameWidthWanted + 6))

  local wantedCols = scoreWidth + gap + levelCellWidth + gap + nameColsWidth
  local wantedTotal = math.max(wantedCols, math.ceil(fullWidthWanted)) + (padding * 2)

  if db.autoWidth and ui.frame and ui.frame.SetWidth then
    local maxWidth = UIParent and UIParent.GetWidth and (UIParent:GetWidth() - 40) or wantedTotal
    ui.frame:SetWidth(math.min(wantedTotal, maxWidth))
  elseif ui.frame and ui.frame.SetWidth then
    ui.frame:SetWidth(420)
  end

  local contentWidth = (ui.frame and ui.frame.GetWidth) and (ui.frame:GetWidth() - (padding * 2)) or 380
  local nameWidth = math.max(80, contentWidth - scoreWidth - levelCellWidth - (gap * 2))

  ui.content:SetWidth(contentWidth)

  DPrint(
    db,
    string.format(
      "Render %d rows (w=%.0f s=%.0f lp=%.0f ln=%.0f n=%.0f)",
      #rows,
      contentWidth,
      scoreWidth,
      levelPrefixWidth,
      levelNumberWidthMax,
      nameWidth
    )
  )

  for i = 1, math.max(#rows, #ui.rows) do
    local rowData = rows[i]
    local row = ui.rows[i]
    if rowData then
      row = EnsureRow(i, db)
      row.frame:ClearAllPoints()
      row.frame:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, -((i - 1) * lineHeight))
      row.frame:SetPoint("TOPRIGHT", ui.content, "TOPRIGHT", 0, -((i - 1) * lineHeight))
      row.frame:SetHeight(lineHeight)

      row.score:ClearAllPoints()
      row.levelContainer:ClearAllPoints()
      row.levelPrefix:ClearAllPoints()
      row.levelNumber:ClearAllPoints()
      row.name:ClearAllPoints()

      if rowData.kind == "full" then
        row.score:Hide()
        row.levelContainer:Hide()
        row.levelPrefix:Hide()
        row.levelNumber:Hide()
        row.name:Show()
        row.name:SetJustifyH("LEFT")
        row.name:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
        row.name:SetWidth(contentWidth)
        row.name:SetText(rowData.text or "")
      else
        row.score:Show()
        row.levelContainer:Show()
        row.levelPrefix:Show()
        row.levelNumber:Show()
        row.name:Show()

        row.score:SetJustifyH("RIGHT")
        row.score:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
        row.score:SetWidth(scoreWidth)
        row.score:SetText(rowData.scoreText or "")

        row.levelContainer:SetPoint("TOPLEFT", row.score, "TOPRIGHT", gap, 0)
        row.levelContainer:SetWidth(levelCellWidth)

        row.levelNumber:SetJustifyH("RIGHT")
        row.levelNumber:SetPoint("TOPRIGHT", row.levelContainer, "TOPRIGHT", 0, 0)
        local levelNumberText = rowData.levelNumberText or ""
        local levelNumberWidth = math.max(1, MeasureText(db, levelNumberText) + 2)
        row.levelNumber:SetWidth(levelNumberWidth)
        row.levelNumber:SetText(levelNumberText)

        row.levelPrefix:SetJustifyH("RIGHT")
        row.levelPrefix:SetPoint("TOPRIGHT", row.levelNumber, "TOPLEFT", 0, 0)
        row.levelPrefix:SetText(rowData.levelPrefixText or "")

        row.name:SetJustifyH("LEFT")
        row.name:SetPoint("TOPLEFT", row.levelContainer, "TOPRIGHT", gap, 0)
        row.name:SetWidth(nameWidth)
        row.name:SetText(rowData.nameText or "")
      end

      row.frame:Show()
    elseif row then
      row.frame:Hide()
    end
  end

  local contentHeight = (#rows * lineHeight)
  ui.content:SetHeight(contentHeight)
  if ui.frame and ui.frame.SetHeight then
    ui.frame:SetHeight(contentHeight + (padding * 2))
  end
end

local function EnsureMaps()
  if type(C_ChallengeMode) ~= "table" or type(C_ChallengeMode.GetMapTable) ~= "function" then
    return false
  end

  local mapIDs = C_ChallengeMode.GetMapTable()
  if type(mapIDs) ~= "table" or #mapIDs == 0 then
    return false
  end

  state.mapIDs = mapIDs
  state.dungeonTimers = {}

  if type(C_ChallengeMode.GetMapUIInfo) == "function" then
    for _, mapID in ipairs(mapIDs) do
      local _, _, maxTime = C_ChallengeMode.GetMapUIInfo(mapID)
      if type(maxTime) == "number" then
        state.dungeonTimers[mapID] = { timer = maxTime }
      end
    end
  end

  return true
end

local function GetChestCount(mapID, completionTime, keyLevel)
  local timers = state.dungeonTimers[mapID]
  if not timers then
    return 0
  end

  local maxTime = timers.timer
  if type(maxTime) ~= "number" then
    return 0
  end

  if type(keyLevel) == "number" and keyLevel >= 12 then
    maxTime = maxTime + 90
  end

  if completionTime <= maxTime * 0.6 then
    return 3
  elseif completionTime <= maxTime * 0.8 then
    return 2
  elseif completionTime <= maxTime then
    return 1
  end
  return 0
end

local function GetRunInfo(mapID)
  local result = {}

  if type(C_ChallengeMode) == "table" and type(C_ChallengeMode.GetMapUIInfo) == "function" then
    result.name = C_ChallengeMode.GetMapUIInfo(mapID)
  else
    result.name = tostring(mapID)
  end

  if type(C_MythicPlus) ~= "table" or type(C_MythicPlus.GetSeasonBestForMap) ~= "function" then
    return result
  end

  local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
  local info
  if intimeInfo and overtimeInfo then
    info = (intimeInfo.dungeonScore or 0) >= (overtimeInfo.dungeonScore or 0) and intimeInfo or overtimeInfo
  else
    info = intimeInfo or overtimeInfo
  end

  if info then
    result.level = info.level
    result.score = info.dungeonScore
    result.completionTime = info.durationSec
    result.chestCount = GetChestCount(mapID, result.completionTime or 0, result.level or 0)
    result.overtime = result.chestCount == 0
    result.color = result.overtime and COLOR_KO_RED or COLOR_OK_GREEN
  end

  if type(C_ChallengeMode) == "table" then
    result.scoreColor = SafeGetColor(C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor, result.score or 0)
  end

  return result
end

local function DisplayMyKeystone(db)
  if not db.displayMyKeystone then
    return ""
  end

  if type(C_MythicPlus) ~= "table" then
    return ""
  end

  local ownedMapID = type(C_MythicPlus.GetOwnedKeystoneChallengeMapID) == "function" and C_MythicPlus.GetOwnedKeystoneChallengeMapID() or nil
  if not ownedMapID or ownedMapID == 0 then
    return ""
  end

  local keystoneName = (type(C_ChallengeMode) == "table" and type(C_ChallengeMode.GetMapUIInfo) == "function") and C_ChallengeMode.GetMapUIInfo(ownedMapID) or tostring(ownedMapID)
  local keystoneLevel = type(C_MythicPlus.GetOwnedKeystoneLevel) == "function" and C_MythicPlus.GetOwnedKeystoneLevel() or "?"
  return string.format("%sMy Keystone:|r %s+%s %s|r\n\n", COLOR_GREY, COLOR_NOT_DONE_YELLOW, tostring(keystoneLevel), tostring(keystoneName))
end

local function FormatRunRow(entry)
  local level = entry.Level
  local name = entry.Name
  local score = entry.Score
  local chestCount = entry.ChestCount or 0
  local color = entry.Color or COLOR_WHITE
  local scoreColor = entry.ScoreColor

  if type(level) == "number" and level > 0 then
    local scoreNumber = tonumber(score) or 0
    local scoreText = tostring(scoreNumber)
    if scoreColor then
      scoreText = SafeWrapColor(scoreColor, scoreText)
    end

    local prefixText = ""
    local numberText = tostring(level)
    if chestCount and chestCount > 0 then
      prefixText = string.rep("+", chestCount)
    end

    return {
      kind = "cols",
      scoreText = scoreText,
      levelPrefixText = string.format("%s%s|r", color, prefixText),
      levelNumberText = string.format("%s%s|r", color, numberText),
      nameText = string.format("%s%s|r", color, tostring(name)),
    }
  end

  return {
    kind = "cols",
    scoreText = "",
    levelPrefixText = "",
    levelNumberText = "",
    nameText = string.format("%s%s|r %snot cleared yet|r", COLOR_NOT_DONE_YELLOW, tostring(name), COLOR_GREY),
  }
end

local function BuildRows(db)
  if not state.mapIDs and not EnsureMaps() then
    return {
      { kind = "full", text = COLOR_GREY .. "Mythic+ data not available yet.|r" },
    }
  end

  local grid = {}
  for i, mapID in ipairs(state.mapIDs) do
    local runInfo = GetRunInfo(mapID)
    grid[i] = {
      Name = runInfo.name,
      Level = runInfo.level or 0,
      Color = runInfo.color or COLOR_WHITE,
      Score = runInfo.score or 0,
      ScoreColor = runInfo.scoreColor,
      ChestCount = runInfo.chestCount,
    }
  end

  table.sort(grid, function(lhs, rhs)
    return (lhs.Score or 0) > (rhs.Score or 0)
  end)

  local rows = {}

  table.insert(rows, { kind = "full", text = "Highest Mythic+ Runs" })

  if type(C_PlayerInfo) == "table" and type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) == "function" then
    local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    if ratingSummary and (ratingSummary.currentSeasonScore or 0) > 0 then
      local totalScore = ratingSummary.currentSeasonScore
      local scoreColor = type(C_ChallengeMode) == "table" and SafeGetColor(C_ChallengeMode.GetDungeonScoreRarityColor, totalScore) or nil
      table.insert(rows, { kind = "full", text = string.format("Total score: %s", SafeWrapColor(scoreColor, tostring(totalScore))) })
    end
  end

  table.insert(rows, { kind = "cols", scoreText = "Score", levelPrefixText = "", levelNumberText = "Level", nameText = "Dungeon" })

  for _, row in ipairs(grid) do
    table.insert(rows, FormatRunRow(row))
  end

  local ks = DisplayMyKeystone(db)
  if ks ~= "" then
    ks = ks:gsub("\n+$", "")
    for part in ks:gmatch("([^\n]+)") do
      table.insert(rows, { kind = "full", text = part })
    end
  end

  return rows
end

local function IsFiniteNumber(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function GetCenterOffsets(frame)
  local cx, cy = frame:GetCenter()
  local pcx, pcy = UIParent:GetCenter()
  if not (cx and cy and pcx and pcy) then
    return nil, nil
  end

  local frameScale = frame:GetEffectiveScale() or 1
  local parentScale = UIParent:GetEffectiveScale() or 1
  local x = ((cx * frameScale) - (pcx * parentScale)) / parentScale
  local y = ((cy * frameScale) - (pcy * parentScale)) / parentScale
  return x, y
end

local function HasValidSavedPosition(db)
  if not db or not db.customPosition then
    return false
  end
  if not VALID_ANCHOR_POINTS[db.point] or not VALID_ANCHOR_POINTS[db.relativePoint] then
    return false
  end
  if not IsFiniteNumber(db.x) or not IsFiniteNumber(db.y) then
    return false
  end
  return true
end

local function SavePosition(frame, db)
  local x, y = GetCenterOffsets(frame)
  if IsFiniteNumber(x) and IsFiniteNumber(y) then
    db.customPosition = true
    db.point = "CENTER"
    db.relativePoint = "CENTER"
    db.x = x
    db.y = y
    return
  end

  local point, _, relativePoint, fallbackX, fallbackY = frame:GetPoint(1)
  relativePoint = relativePoint or point
  if VALID_ANCHOR_POINTS[point] and VALID_ANCHOR_POINTS[relativePoint] and IsFiniteNumber(fallbackX) and IsFiniteNumber(fallbackY) then
    db.customPosition = true
    db.point = point
    db.relativePoint = relativePoint
    db.x = fallbackX
    db.y = fallbackY
  end
end

local function ApplyPosition(frame, db)
  frame:ClearAllPoints()

  if HasValidSavedPosition(db) then
    frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    return
  end

  db.customPosition = false
  db.point = DEFAULTS.point
  db.relativePoint = DEFAULTS.relativePoint
  db.x = DEFAULTS.x
  db.y = DEFAULTS.y

  if PVEFrameTab1 and PVEFrameTab1.GetName then
    frame:SetPoint("TOPLEFT", PVEFrameTab1, "BOTTOMLEFT", -20, -15)
    return
  end

  if PVEFrame and PVEFrame.GetName then
    frame:SetPoint("TOPLEFT", PVEFrame, "TOPLEFT", 18, -64)
    return
  end

  frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end

EnsureUI = function(db)
  if ui.frame then
    return
  end

  local frame = CreateFrame("Frame", "MythicPlusProgressFrame", UIParent, "BackdropTemplate")
  ui.frame = frame

  frame:SetSize(420, 80)
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if not db.locked then
      if not db.customPosition then
        local x, y = GetCenterOffsets(self)
        if IsFiniteNumber(x) and IsFiniteNumber(y) then
          self:ClearAllPoints()
          self:SetPoint("CENTER", UIParent, "CENTER", x, y)
        end
        db.customPosition = true
      end
      self:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self, db)
  end)

  frame:SetBackdrop({
    bgFile = "Interface/FrameGeneral/UI-Background-Rock",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 256,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(1, 1, 1, 0.9)

  local content = CreateFrame("Frame", nil, frame)
  ui.content = content
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
  content:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
  content:SetSize(1, 1)

  local measure = content:CreateFontString(nil, "ARTWORK")
  ui.measure = measure
  measure:Hide()

  ApplyPosition(frame, db)
end

local function UpdateVisibility(db)
  if not ui.frame then
    return
  end

  if not db.showOnlyInPVEFrame then
    ui.frame:Show()
    return
  end

  if not PVEFrame then
    ui.frame:Show()
    return
  end

  if PVEFrame.IsShown and PVEFrame:IsShown() then
    ui.frame:Show()
  else
    ui.frame:Hide()
  end
end

local function HookPVEFrame()
  if not PVEFrame or not PVEFrame.HookScript then
    return
  end
  if PVEFrame.__AddonMythicPlusHooked then
    return
  end

  PVEFrame.__AddonMythicPlusHooked = true
  PVEFrame:HookScript("OnShow", function()
    UpdateVisibility(GetDB())
  end)
  PVEFrame:HookScript("OnHide", function()
    UpdateVisibility(GetDB())
  end)
end

local pendingRefresh = false
local function RefreshNow()
  local db = GetDB()
  TryLoadPVEFrame()
  EnsureUI(db)
  HookPVEFrame()
  EnsureMaps()
  ApplyFont(db)
  local rows = BuildRows(db)
  SetDisplayRows(db, rows)
  UpdateVisibility(db)
end

local function RefreshSoon()
  if pendingRefresh then
    return
  end
  pendingRefresh = true
  C_Timer.After(0.3, function()
    pendingRefresh = false
    RefreshNow()
  end)
end

local function PrintHelp()
  print(string.format("%s commands:", ADDON_NAME))
  print("  /mpp - refresh")
  print("  /mpp keystone - toggle 'My Keystone'")
  print("  /mpp pve - toggle show only in PVE frame")
  print("  /mpp lock | unlock - toggle dragging")
  print("  /mpp reset - reset position")
  print("  /mpp width - toggle auto width")
end

SLASH_MYTHICPLUSPROGRESS1 = "/mpp"
SLASH_MYTHICPLUSPROGRESS2 = "/mythicplusprogress"
SlashCmdList.MYTHICPLUSPROGRESS = function(msg)
  local db = GetDB()
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

  if msg == "" then
    RefreshNow()
    return
  end

  if msg == "help" then
    PrintHelp()
    return
  end

  if msg == "keystone" then
    db.displayMyKeystone = not db.displayMyKeystone
    RefreshNow()
    print(string.format("%s: displayMyKeystone = %s", ADDON_NAME, tostring(db.displayMyKeystone)))
    return
  end

  if msg == "pve" then
    db.showOnlyInPVEFrame = not db.showOnlyInPVEFrame
    RefreshNow()
    print(string.format("%s: showOnlyInPVEFrame = %s", ADDON_NAME, tostring(db.showOnlyInPVEFrame)))
    return
  end

  if msg == "lock" then
    db.locked = true
    RefreshNow()
    print(string.format("%s: locked = true", ADDON_NAME))
    return
  end

  if msg == "unlock" then
    db.locked = false
    RefreshNow()
    print(string.format("%s: locked = false (drag with left mouse)", ADDON_NAME))
    return
  end

  if msg == "reset" then
    for k, v in pairs(DEFAULTS) do
      db[k] = v
    end
    db.customPosition = false
    if ui.frame then
      ApplyPosition(ui.frame, db)
    end
    RefreshNow()
    print(string.format("%s: position reset", ADDON_NAME))
    return
  end

  if msg == "width" then
    db.autoWidth = not db.autoWidth
    RefreshNow()
    print(string.format("%s: autoWidth = %s", ADDON_NAME, tostring(db.autoWidth)))
    return
  end

  PrintHelp()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
events:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")

events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      GetDB()
      RefreshSoon()
    elseif arg1 == "Blizzard_PVEFrame" then
      HookPVEFrame()
      if ui.frame then
        ApplyPosition(ui.frame, GetDB())
        UpdateVisibility(GetDB())
      end
    end
    return
  end

  if event == "PLAYER_LOGIN" then
    HookPVEFrame()
    local db = GetDB()
    if db.welcome then
      db.welcome = false
      print(string.format("%s loaded. Type /mpp help", ADDON_NAME))
    end
    RefreshSoon()
    return
  end

  if event == "PLAYER_LOGOUT" then
    local db = GetDB()
    if ui.frame and db.customPosition then
      SavePosition(ui.frame, db)
    end
    return
  end

  if event == "CHALLENGE_MODE_MAPS_UPDATE" then
    state.mapIDs = nil
    RefreshSoon()
    return
  end

  RefreshSoon()
end)
