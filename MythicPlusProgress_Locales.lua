local _, ns = ...
ns = ns or {}

local enUS = {
  HELP_HEADER = "%s commands:",
  HELP_REFRESH = "  /mpp - refresh",
  HELP_KEYSTONE = "  /mpp keystone - toggle 'My Keystone'",
  HELP_PVE = "  /mpp pve - toggle show only in PVE frame",
  HELP_LOCK = "  /mpp lock | unlock - toggle dragging",
  HELP_RESET = "  /mpp reset - reset position",

  HEADER_HIGHEST_RUNS = "Highest Mythic+ Runs",
  HEADER_SCORE = "Score",
  HEADER_LEVEL = "Level",
  HEADER_DUNGEON = "Dungeon",
  TOTAL_SCORE = "Total score: %s",
  MY_KEYSTONE = "%sMy Keystone:|r %s+%s %s|r\n\n",
  NOT_CLEARED_YET = "%s%s|r %snot cleared yet|r",
  DATA_NOT_AVAILABLE = "%sMythic+ data not available yet.|r",

  TRANSITION_IN_PROGRESS = "%sSeason transition in progress.|r",
  TRANSITION_S1_NEXT_RESET = "%sMythic+ Season 1 will be available soon.|r",
  TRANSITION_REGION_DATE = "%sRegion: %s | Planned date: %02d March %d|r",
  TRANSITION_ETA = "%sServer reset ETA: %s|r",
  TRANSITION_UNLOCK_UTC = "%sEstimated unlock (UTC): %s|r",

  STATUS_KEYSTONE = "%s: displayMyKeystone = %s",
  STATUS_PVE = "%s: showOnlyInPVEFrame = %s",
  STATUS_LOCKED_TRUE = "%s: locked = true",
  STATUS_LOCKED_FALSE = "%s: locked = false (drag with left mouse)",
  STATUS_POSITION_RESET = "%s: position reset",
  STATUS_LOADED = "%s loaded. Type /mpp help",
}

local frFR = {
  HELP_HEADER = "Commandes %s :",
  HELP_REFRESH = "  /mpp - rafraichir",
  HELP_KEYSTONE = "  /mpp keystone - activer/desactiver 'Ma cle'",
  HELP_PVE = "  /mpp pve - afficher uniquement dans la fenetre JcE",
  HELP_LOCK = "  /mpp lock | unlock - activer/desactiver le deplacement",
  HELP_RESET = "  /mpp reset - reinitialiser la position",

  HEADER_HIGHEST_RUNS = "Meilleures runs Mythique+",
  HEADER_SCORE = "Score",
  HEADER_LEVEL = "Niveau",
  HEADER_DUNGEON = "Donjon",
  TOTAL_SCORE = "Score total : %s",
  MY_KEYSTONE = "%sMa cle :|r %s+%s %s|r\n\n",
  NOT_CLEARED_YET = "%s%s|r %spas encore terminée|r",
  DATA_NOT_AVAILABLE = "%sDonnées Mythique+ indisponibles pour le moment.|r",

  TRANSITION_IN_PROGRESS = "%sTransition de saison en cours.|r",
  TRANSITION_S1_NEXT_RESET = "%sLes Mythique+ Saison 1 seront disponibles prochainement.|r",
  TRANSITION_REGION_DATE = "%sRegion : %s | Date prévue : %02d mars %d|r",
  TRANSITION_ETA = "%sTemps restant avant reset serveur : %s|r",
  TRANSITION_UNLOCK_UTC = "%sDisponibilité estimée (UTC) : %s|r",

  STATUS_KEYSTONE = "%s: displayMyKeystone = %s",
  STATUS_PVE = "%s: showOnlyInPVEFrame = %s",
  STATUS_LOCKED_TRUE = "%s: locked = true",
  STATUS_LOCKED_FALSE = "%s: locked = false (déplacer avec clic gauche)",
  STATUS_POSITION_RESET = "%s: position reinitialisée",
  STATUS_LOADED = "%s chargé. Tape /mpp help",
}

local ruRU = {
  HELP_HEADER = "%s команды:",
  HELP_REFRESH = "  /mpp - обновить",
  HELP_KEYSTONE = "  /mpp keystone - вкл./выкл. отображение 'Мой М+ ключ'",
  HELP_PVE = "  /mpp pve - Отображать только в режиме PvE",
  HELP_LOCK = "  /mpp lock | unlock - перемещение",
  HELP_RESET = "  /mpp reset - сбросить положение",

  HEADER_HIGHEST_RUNS = "Лучшие прохождения M+",
  HEADER_SCORE = "Результат",
  HEADER_LEVEL = "Уровень",
  HEADER_DUNGEON = "Подземелье",
  TOTAL_SCORE = "Общий результат: %s",
  MY_KEYSTONE = "%sМой М+ ключ:|r %s+%s %s|r\n\n",
  NOT_CLEARED_YET = "%s%s|r %sещё не закончено|r",
  DATA_NOT_AVAILABLE = "%sДанные по + в данный момент недоступны.|r",

  TRANSITION_IN_PROGRESS = "%sИдет переход между сезонами.|r",
  TRANSITION_S1_NEXT_RESET = "%sПервый сезон M+ скоро станет доступен.|r",
  TRANSITION_REGION_DATE = "%sРегион: %s | Планируемая дата: %02d марта %d|r",
  TRANSITION_ETA = "%sОриентировочное время перезапуска сервера: %s|r",
  TRANSITION_UNLOCK_UTC = "%sОриентировочное время разблокировки (UTC): %s|r",

  STATUS_KEYSTONE = "%s: displayMyKeystone = %s",
  STATUS_PVE = "%s: showOnlyInPVEFrame = %s",
  STATUS_LOCKED_TRUE = "%s: locked = true",
  STATUS_LOCKED_FALSE = "%s: locked = false (перемещайте с помощью ЛКМ)",
  STATUS_POSITION_RESET = "%s: сброс положения",
  STATUS_LOADED = "%s загружен. Введите /mpp help",
}

local currentLocale = GetLocale and GetLocale() or "enUS"
local active = enUS
if currentLocale == "frFR" then
  active = frFR
end

ns.L = function(key, ...)
  local text = active[key] or enUS[key] or key
  if select("#", ...) > 0 then
    return string.format(text, ...)
  end
  return text
end
