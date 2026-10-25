-- Polypode Profil: Profil — bibliothèque de chaînes d'export (mode Édition, talents, addons), sauvegarde et synchro

local _, ns = ...
local P = Polypode -- dépendance obligatoire (## Dependencies: Polypode), chargée avant nous
local L = ns.L

-- Addon compagnon de Polypode : une bibliothèque de « profils », c'est-à-dire des chaînes
-- d'export copiées depuis le mode Édition de WoW, la fenêtre des talents ou un addon (EllesmereUI,
-- ElvUI, Baganator, MySlots...), gardées pour être recollées plus tard sur n'importe quel
-- personnage. Un addon ne lit pas le presse-papiers : la chaîne est collée (Ctrl+V) dans la
-- fenêtre, puis recopiée (Ctrl+C) dans la fenêtre d'import de l'addon. Seuls le mode Édition et
-- les talents peuvent être capturés directement (API de Blizzard).
--
-- Sauvegarde (fichier de compte, commune à tous les personnages) :
--   PolypodeProfilDB.profiles[id] = { name, kind, text, char = clé du personnage auquel le profil
--   est rangé (par défaut celui qui l'a créé ; la liste les regroupe par personnage), updated =
--   version, removed = true (pierre tombale : suppression propagée aux autres clients) }.
--   id = heure serveur + hasard, en hexadécimal ; version = heure serveur du dernier changement,
--   strictement croissante (la plus récente l'emporte).
--
-- Synchro (bibliothèque partagée : tout client connecté peut modifier tout profil) :
--   PROFV:token:id=version,id=version,... — versions de tous les profils, à chaque rencontre
--     (P.RegisterPeerCallback), fragmentée ;
--   PROFREQ:token:id,id,... — demande des profils plus récents que les siens ;
--   PROF:token:id:N:version:fragments:genre:A|R:personnage:nom — en-tête d'un profil (nom en
--     dernier), suivi de PROF:token:id:+:version:n°:morceau pour chaque fragment du texte ;
--     envoyé en réponse à PROFREQ et aux clients connectés à chaque changement. Le profil n'est
--     appliqué qu'une fois tous les fragments reçus, et seulement s'il est plus récent.
-- Texte et nom encodés en ASCII (%XX pour « % », « | », retours à la ligne et octets non ASCII) :
-- un fragment peut couper n'importe où sans casser un caractère.

-- Groupes de genres, sections du menu « Nouveau » : apply = capturé en jeu et appliqué par
-- l'icône de la ligne ; copy = capturé en jeu, chaîne à copier ; paste = chaîne collée et copiée
-- (import / export d'un addon).
ns.KIND_GROUPS = {
	{ key = "apply", label = L["Capturer et appliquer en jeu"] },
	{ key = "copy", label = L["Capturer, puis copier la chaîne"] },
	{ key = "paste", label = L["Coller une chaîne (import / export)"] },
}

-- Genres de profil, dans l'ordre d'affichage (groupe par groupe).
ns.KINDS = {
	{ key = "transmog", label = L["Transmogrification"], group = "apply" },
	{ key = "title", label = L["Titre"], group = "apply" },
	{ key = "macro", label = L["Macro"], group = "apply" }, -- Macro.lua
	{ key = "equipset", label = L["Ensemble d'équipement"], group = "apply" }, -- Equipement.lua
	{ key = "actionbars", label = L["Barres d'action"], group = "apply" }, -- Barres.lua
	{ key = "options", label = L["Options de WoW"], group = "apply" }, -- Options.lua
	{ key = "bindings", label = L["Raccourcis clavier"], group = "apply" }, -- Options.lua
	{ key = "chat", label = L["Fenêtres de discussion"], group = "apply" }, -- Discussion.lua
	{ key = "addons", label = L["Liste des addons"], group = "apply" }, -- Addons.lua
	{ key = "simpleaddonmanager", label = "Simple Addon Manager", group = "apply" }, -- Addons.lua
	-- prefix : profil d'un addon, nommé « Addon — nom ».
	{ key = "ellesmereui", label = "EllesmereUI", group = "apply", prefix = true }, -- Interfaces.lua
	{ key = "elvui", label = "ElvUI", group = "apply", prefix = true }, -- Interfaces.lua
	{ key = "baganator", label = "Baganator", group = "apply", prefix = true }, -- Interfaces.lua (collé, importé)
	{ key = "editmode", label = L["Mode Édition"], group = "copy" },
	{ key = "talents", label = L["Talents"], group = "copy" },
	{ key = "myslots", label = "MySlots", group = "paste", prefix = true },
	{ key = "other", label = L["Autre"], group = "paste" },
}
ns.DEFAULT_KIND = "other"

local KIND_INDEX = {}
for index, kind in ipairs(ns.KINDS) do
	KIND_INDEX[kind.key] = index
end

-- Genre connu (un genre inconnu, venu d'une version plus récente, est rangé dans « Autre »).
function ns.NormalizeKind(kind)
	return KIND_INDEX[kind] and kind or ns.DEFAULT_KIND
end

function ns.KindLabel(kind)
	return ns.KINDS[KIND_INDEX[ns.NormalizeKind(kind)]].label
end

function ns.KindOrder(kind)
	return KIND_INDEX[ns.NormalizeKind(kind)]
end

-- Préfixe du nom d'un profil d'addon (libellé du genre), ou nil.
function ns.KindNamePrefix(kind)
	local entry = ns.KINDS[KIND_INDEX[ns.NormalizeKind(kind)]]
	return entry.prefix and entry.label or nil
end

-- Groupe du genre : "apply", "copy" ou "paste" (ns.KIND_GROUPS).
function ns.KindGroup(kind)
	return ns.KINDS[KIND_INDEX[ns.NormalizeKind(kind)]].group
end

local store -- PolypodeProfilDB.profiles

-- Version suivante d'une donnée : heure serveur, strictement croissante.
local function NextVersion(old)
	return math.max(GetServerTime(), (tonumber(old) or 0) + 1)
end

local function Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Changed()
	if ns.Refresh then
		ns.Refresh()
	end
end

-- Contexte de jeu d'une sauvegarde : saison (« Midnight, saison 2 », comme Polypode Suivi :
-- C_SeasonInfo + C_DelvesUI) et version du client (« 12.1.0 », GetBuildInfo). nil si inconnu.
local function GameContext()
	local build = GetBuildInfo and GetBuildInfo()
	local okExpansion, expansion = pcall(function()
		return C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonExpansion
			and C_SeasonInfo.GetCurrentDisplaySeasonExpansion()
	end)
	local okNumber, number = pcall(function()
		return C_DelvesUI and C_DelvesUI.GetCurrentDelvesSeasonNumber and C_DelvesUI.GetCurrentDelvesSeasonNumber()
	end)
	local season
	if okExpansion and expansion then
		local name = _G["EXPANSION_NAME" .. expansion] or L["Extension %s"]:format(expansion)
		number = okNumber and tonumber(number) or nil
		season = (number and number > 0) and L["%s, saison %d"]:format(name, number) or L["%s, hors saison"]:format(name)
	end
	return season, build
end

-- Saison en cours (« Midnight, saison 2 »), ou nil si le jeu ne la donne pas (WoW Forever).
function ns.CurrentSeason()
	return (GameContext())
end

-- Texte « saison (version) » d'un profil pour l'infobulle, ou nil (sauvegarde antérieure à 1.9.0).
function ns.GameContextText(profile)
	if not (profile.season or profile.build) then
		return nil
	end
	local text = profile.season or L["saison inconnue"]
	return profile.build and (text .. " (" .. profile.build .. ")") or text
end

-- BIBLIOTHÈQUE -------------------------------------------------------------------------------

-- Profil actif, ou nil (supprimé ou inconnu).
function ns.Get(id)
	local profile = store and store[id]
	if profile and not profile.removed then
		return profile
	end
end

-- Profils actifs, triés par genre puis par nom : { { id, profile }, ... }.
function ns.GetProfiles()
	local list = {}
	for id, profile in pairs(store or {}) do
		if not profile.removed then
			list[#list + 1] = { id = id, profile = profile }
		end
	end
	table.sort(list, function(a, b)
		local ka, kb = ns.KindOrder(a.profile.kind), ns.KindOrder(b.profile.kind)
		if ka ~= kb then
			return ka < kb
		end
		local na, nb = (a.profile.name or ""):lower(), (b.profile.name or ""):lower()
		if na ~= nb then
			return na < nb
		end
		return a.id < b.id
	end)
	return list
end

local SendProfile -- défini dans SYNCHRO

local function NewID()
	local id
	repeat
		id = string.format("%x%04x", GetServerTime(), math.random(0, 0xffff))
	until not (store and store[id])
	return id
end

-- Crée (id nil) ou met à jour un profil, rangé sous le personnage char (défaut : le personnage
-- joué) ; renvoie son id, ou nil et la raison.
function ns.Save(id, name, kind, text, char)
	if not store then
		return nil, L["Données non chargées."]
	end
	name, text = Trim(name), Trim(text)
	if text == "" then
		return nil, L["La chaîne est vide."]
	end
	if name == "" then
		name = ns.KindLabel(kind)
	end
	local profile = id and store[id]
	if not profile or profile.removed then
		id = id or NewID()
		profile = {}
		store[id] = profile
	end
	profile.removed = nil
	profile.char = char or profile.char or P.GetCharKey()
	profile.name, profile.kind, profile.text = name, ns.NormalizeKind(kind), text
	profile.season, profile.build = GameContext() -- saison et version du jeu de cette sauvegarde
	profile.updated = NextVersion(profile.updated)
	SendProfile(id)
	Changed()
	return id
end

-- Supprime un profil (pierre tombale, propagée aux autres clients).
function ns.Delete(id)
	local profile = store and store[id]
	if not profile or profile.removed then
		return
	end
	store[id] = { removed = true, updated = NextVersion(profile.updated) }
	SendProfile(id)
	Changed()
end

-- CAPTURE EN JEU -----------------------------------------------------------------------------

-- Dispositions du mode Édition (préréglages de Blizzard compris), telles que les montre la
-- fenêtre du mode Édition : { { name, active, layout }, ... }.
function ns.GetEditModeLayouts()
	local list = {}
	local manager = EditModeManagerFrame
	local info = manager and manager.layoutInfo
	if not (info and info.layouts and C_EditMode and C_EditMode.ConvertLayoutInfoToString) then
		return list
	end
	for index, layout in ipairs(info.layouts) do
		list[#list + 1] = { name = layout.layoutName or L["Disposition %s"]:format(index), active = index == info.activeLayout,
			layout = layout }
	end
	return list
end

-- Chaîne d'export d'une disposition (celle que donne « Copier dans le presse-papiers »).
function ns.ExportEditModeLayout(layout)
	local ok, text = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
	if ok and type(text) == "string" and text ~= "" then
		return text
	end
	return nil, L["Export de la disposition impossible."]
end

-- Chaîne d'export des talents affichés par la fenêtre des talents de Blizzard (configuration
-- active), et un nom proposé. La fenêtre doit avoir été ouverte une fois : elle ne connaît son
-- arbre qu'à son premier affichage. Elle n'est jamais chargée d'ici : chargée par un addon, elle
-- serait « souillée » (taint) et WoW pourrait bloquer ensuite l'application des talents.
function ns.ExportTalents()
	local OPEN_FIRST = L["Ouvrez une fois la fenêtre des talents (N), puis recommencez."]
	if not PlayerSpellsFrame then
		return nil, OPEN_FIRST
	end
	local talents = PlayerSpellsFrame.TalentsFrame
	if not (talents and talents.GetLoadoutExportString) then
		return nil, L["Talents indisponibles sur ce client."]
	end
	local ok, text = pcall(talents.GetLoadoutExportString, talents)
	if not ok or type(text) ~= "string" or text == "" then
		return nil, OPEN_FIRST
	end
	local name = L["Talents"]
	if PlayerUtil and PlayerUtil.GetSpecName then
		local okSpec, spec = pcall(PlayerUtil.GetSpecName)
		if okSpec and spec then
			name = name .. " " .. spec
		end
	end
	if C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID and C_Traits and C_Traits.GetConfigInfo
		and PlayerUtil and PlayerUtil.GetCurrentSpecID then
		local okConfig, configID = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, PlayerUtil.GetCurrentSpecID())
		local info = okConfig and configID and C_Traits.GetConfigInfo(configID)
		if info and info.name and info.name ~= "" then
			name = name .. " — " .. info.name
		end
	end
	return text, name
end

-- IMPORT PRÉ-REMPLI (BÊTA) : mode Édition et talents n'ont pas d'import sûr pour un addon (leurs
-- fenêtres, appelées par un addon, peuvent être « souillées » et bloquer ensuite des actions). On
-- ouvre seulement la fenêtre d'import de Blizzard, chaîne et nom déjà remplis : c'est le clic du
-- joueur sur « Importer » qui importe. La fenêtre du mode Édition / des talents doit avoir été
-- ouverte par le joueur (jamais par l'addon) ; un /reload ensuite efface toute trace.

-- Nom proposé : la partie après le dernier « — » du nom du profil (« Mode Édition — Raid » → « Raid »).
local function ImportName(name)
	name = tostring(name or "")
	return strtrim(name:match(".*—%s*(.-)$") or name)
end

function ns.OpenEditModeImport(text, name)
	if InCombatLockdown() then
		return nil, L["Impossible en combat."]
	end
	local dialog = EditModeImportLayoutDialog
	if not (dialog and dialog.ShowImportLayoutDialog and dialog.GetImportEditBox and dialog.GetEditBox) then
		return nil, L["Import du mode Édition indisponible sur ce client."]
	elseif not (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then
		return nil, L["Ouvrez d'abord le mode Édition (Échap, Mode Édition), puis recliquez."]
	end
	local ok = pcall(function()
		dialog:ShowImportLayoutDialog()
		dialog:GetImportEditBox():SetText(text)
		-- La fenêtre efface le nom à chaque chaîne lue : le nom se pose après la chaîne.
		dialog:GetEditBox():SetText(ImportName(name))
	end)
	if not ok then
		return nil, L["La fenêtre d'import du mode Édition n'a pas pu s'ouvrir."]
	end
	return true, L["Vérifiez le nom, puis « Importer » ; un /reload ensuite est conseillé (bêta)."]
end

function ns.OpenTalentsImport(text, name)
	if InCombatLockdown() then
		return nil, L["Impossible en combat."]
	end
	local dialog = ClassTalentLoadoutImportDialog
	if not (PlayerSpellsFrame and PlayerSpellsFrame:IsShown() and dialog and dialog.ShowDialog) then
		return nil, L["Ouvrez d'abord la fenêtre des talents (N), puis recliquez."]
	end
	local ok = pcall(function()
		dialog:ShowDialog()
		dialog.ImportControl:GetEditBox():SetText(text)
		dialog.NameControl:GetEditBox():SetText(ImportName(name))
	end)
	if not ok then
		return nil, L["La fenêtre d'import des talents n'a pas pu s'ouvrir."]
	end
	return true, L["Vérifiez le nom, puis « Importer » ; un /reload ensuite est conseillé (bêta)."]
end

-- TRANSMOGRIFICATION : chaîne « /customset v1 ... » de Blizzard (« Copier dans le presse-papiers »
-- de la cabine d'essayage) ; collée dans la discussion, elle ouvre la cabine d'essayage avec la
-- tenue. Format recopié de TransmogUtil.CreateCustomSetSlashCommand (Blizzard_TransmogShared,
-- dépendance de Blizzard_FrameXML sur Retail ; recopié pour ne pas en dépendre) : 17 valeurs, dans l'ordre
-- de TRANSMOG_SLOT_ORDER, apparence de chaque emplacement, plus l'apparence secondaire (épaules,
-- main droite) et l'illusion (mains droite et gauche).
local TRANSMOG_SLOT_ORDER = {
	INVSLOT_HEAD, INVSLOT_SHOULDER, INVSLOT_BACK, INVSLOT_CHEST, INVSLOT_BODY, INVSLOT_TABARD,
	INVSLOT_WRIST, INVSLOT_HAND, INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET, INVSLOT_MAINHAND, INVSLOT_OFFHAND,
}

local function CustomSetSlashCommand(list)
	if type(list) ~= "table" then
		return nil
	end
	local values, any = {}, false
	for _, slot in ipairs(TRANSMOG_SLOT_ORDER) do
		local info = list[slot] or {}
		local appearance = tonumber(info.appearanceID) or 0
		any = any or appearance > 0
		values[#values + 1] = appearance
		if slot == INVSLOT_SHOULDER or slot == INVSLOT_MAINHAND then
			values[#values + 1] = tonumber(info.secondaryAppearanceID) or 0
		end
		if slot == INVSLOT_MAINHAND or slot == INVSLOT_OFFHAND then
			values[#values + 1] = tonumber(info.illusionID) or 0
		end
	end
	return any and ("/customset v1 " .. table.concat(values, ",")) or nil
end

-- Ensembles personnalisés enregistrés : { { id, name }, ... }, triés par nom.
function ns.GetCustomSets()
	local list = {}
	if not (C_TransmogCollection and C_TransmogCollection.GetCustomSets and C_TransmogCollection.GetCustomSetInfo) then
		return list
	end
	local ok, ids = pcall(C_TransmogCollection.GetCustomSets)
	for _, id in ipairs(ok and ids or {}) do
		local name = C_TransmogCollection.GetCustomSetInfo(id)
		list[#list + 1] = { id = id, name = name or L["Ensemble %s"]:format(id) }
	end
	table.sort(list, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	return list
end

-- Chaîne d'un ensemble personnalisé.
function ns.ExportCustomSet(id)
	local getList = C_TransmogCollection and C_TransmogCollection.GetCustomSetItemTransmogInfoList
	local ok, list = pcall(getList, id)
	local text = ok and CustomSetSlashCommand(list)
	if text then
		return text
	end
	return nil, L["Export de l'ensemble impossible."]
end

-- Ouvre la cabine d'essayage sur une chaîne « /customset v1 ... », comme la commande tapée dans la
-- discussion (SlashCommandsOverrides.lua de Blizzard : ParseCustomSetSlashCommand puis
-- DressUpItemTransmogInfoList avec le détail de l'ensemble). Hors combat seulement. Renvoie true,
-- ou nil et la raison.
-- Liste ItemTransmogInfo d'une chaîne « /customset v1 ... », ou nil et la raison.
local function ParseCustomSet(text)
	local args = tostring(text or ""):match("^%s*/customset%s+(.-)%s*$")
	if not args then
		return nil, L["Ce profil n'est pas une chaîne « /customset »."]
	elseif InCombatLockdown() then
		return nil, L["Impossible en combat."]
	elseif not (TransmogUtil and TransmogUtil.ParseCustomSetSlashCommand) then
		return nil, L["Cabine d'essayage indisponible sur ce client."]
	end
	local ok, list = pcall(TransmogUtil.ParseCustomSetSlashCommand, args)
	if not ok or not list then
		return nil, L["Chaîne de transmogrification invalide."]
	end
	return list
end

function ns.TryOnTransmog(text)
	local list, reason = ParseCustomSet(text)
	if not list then
		return nil, reason
	elseif not DressUpItemTransmogInfoList then
		return nil, L["Cabine d'essayage indisponible sur ce client."]
	end
	local showCustomSetDetails = true
	DressUpItemTransmogInfoList(list, showCustomSetDetails)
	return true
end

-- Vrai si la fenêtre du transmogrificateur est ouverte (l'icône applique alors la tenue).
function ns.IsAtTransmogrifier()
	return C_Transmog and C_Transmog.IsAtTransmogNPC and C_Transmog.IsAtTransmogNPC() or false
end

-- Vrai si deux listes ItemTransmogInfo sont identiques (IsEqual du mixin de Blizzard).
local function SameTransmogList(a, b)
	if not (a and b) or #a ~= #b then
		return false
	end
	for slot, info in ipairs(a) do
		if not (info.IsEqual and info:IsEqual(b[slot])) then
			return false
		end
	end
	return true
end

-- Applique une tenue chez le transmogrificateur (fenêtre ouverte), comme un clic sur un ensemble
-- personnalisé dans cette fenêtre (C_TransmogOutfitInfo.SetOutfitToCustomSet, Blizzard_TransmogTemplates) :
-- la chaîne passe par un ensemble personnalisé du nom du profil (le même s'il existe déjà avec
-- la même tenue, sinon créé : C_TransmogCollection.NewCustomSet, icône de la première apparence
-- comme WardrobeCustomSetManager). La tenue est mise en attente ; le bouton « Appliquer » de
-- Blizzard la valide (et en affiche le coût). Renvoie true et un message, ou nil et la raison.
function ns.ApplyTransmog(text, name)
	local list, reason = ParseCustomSet(text)
	if not list then
		return nil, reason
	end
	local collection, outfit = C_TransmogCollection, C_TransmogOutfitInfo
	if not (collection and collection.NewCustomSet and collection.GetCustomSetItemTransmogInfoList
		and outfit and outfit.SetOutfitToCustomSet) then
		return nil, L["Transmogrification indisponible sur ce client."]
	end
	local customSetID
	for _, set in ipairs(ns.GetCustomSets()) do
		local ok, setList = pcall(collection.GetCustomSetItemTransmogInfoList, set.id)
		if set.name == name and ok and SameTransmogList(list, setList) then
			customSetID = set.id
			break
		end
	end
	if not customSetID then
		local max = collection.GetNumMaxCustomSets and collection.GetNumMaxCustomSets()
		if max and #ns.GetCustomSets() >= max then
			return nil, L["Plus de place pour un ensemble personnalisé (%d au maximum) : supprimez-en un."]:format(max)
		end
		local icon
		for _, info in ipairs(list) do
			local source = info.appearanceID and info.appearanceID ~= 0 and collection.GetAppearanceSourceInfo
				and collection.GetAppearanceSourceInfo(info.appearanceID)
			if source and source.icon then
				icon = source.icon
				break
			end
		end
		local ok, id = pcall(collection.NewCustomSet, name, icon, list)
		if not (ok and id) then
			return nil, L["Création de l'ensemble personnalisé refusée par le jeu."]
		end
		customSetID = id
	end
	if not pcall(outfit.SetOutfitToCustomSet, customSetID) then
		return nil, L["Le transmogrificateur a refusé la tenue."]
	end
	return true, L["Tenue chargée chez le transmogrificateur : « Appliquer » pour la valider."]
end

-- TITRE : chaîne « /settitle Nom » (commande de Blizzard, sans nom = aucun titre), collable dans
-- la discussion. La commande de Blizzard prend le premier titre connu qui COMMENCE par le nom ;
-- ns.ApplyTitle cherche le nom exact.
local function TitleName(id)
	local name = GetTitleName and GetTitleName(id)
	return name and strtrim(name) or nil
end

-- Titre porté par le personnage joué : chaîne et nom proposé.
function ns.ExportTitle()
	if not (GetCurrentTitle and GetTitleName) then
		return nil, L["Titres indisponibles sur ce client."]
	end
	local id = GetCurrentTitle()
	local name = id and id > 0 and (not IsTitleKnown or IsTitleKnown(id)) and TitleName(id)
	if name and name ~= "" then
		return "/settitle " .. name, name
	end
	return "/settitle", L["Aucun titre"]
end

-- Porte le titre d'une chaîne « /settitle Nom » (nom exact, parmi les titres connus du
-- personnage joué) ; sans nom, retire le titre. Renvoie true, ou nil et la raison.
function ns.ApplyTitle(text)
	local wanted = tostring(text or ""):match("^%s*/settitle%s*(.-)%s*$")
	if not wanted then
		return nil, L["Ce profil n'est pas une chaîne « /settitle »."]
	elseif not (SetCurrentTitle and GetNumTitles and IsTitleKnown) then
		return nil, L["Titres indisponibles sur ce client."]
	elseif wanted == "" then
		SetCurrentTitle(-1)
		return true
	end
	wanted = wanted:lower()
	for id = 1, GetNumTitles() do
		if IsTitleKnown(id) and (TitleName(id) or ""):lower() == wanted then
			SetCurrentTitle(id)
			return true
		end
	end
	return nil, L["Titre inconnu de ce personnage."]
end

-- Apparence portée par le personnage joué, lue sur un modèle de cabine d'essayage invisible
-- (comme la cabine d'essayage de Blizzard). Le modèle se charge de façon asynchrone : callback(texte)
-- ou callback(nil, raison) est appelé dès que la liste est lisible, au plus tard après 2 s.
local appearanceModel

function ns.ExportCurrentAppearance(callback)
	if not appearanceModel then
		local ok, model = pcall(CreateFrame, "DressUpModel", nil, UIParent)
		if not ok or not model or not model.GetItemTransmogInfoList then
			callback(nil, L["Transmogrification indisponible sur ce client."])
			return
		end
		model:SetSize(1, 1)
		model:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10) -- hors écran
		model:SetAlpha(0)
		model:Hide()
		appearanceModel = model
	end
	local model = appearanceModel
	model:Show()
	model:SetUnit("player")
	local tries = 0
	local function Try()
		tries = tries + 1
		local ok, list = pcall(model.GetItemTransmogInfoList, model)
		local text = ok and CustomSetSlashCommand(list)
		if text or tries >= 20 then
			model:Hide()
			if text then
				callback(text)
			else
				callback(nil, L["Apparence du personnage illisible pour l'instant, réessayez."])
			end
			return
		end
		C_Timer.After(0.1, Try)
	end
	Try()
end

-- SYNCHRO ------------------------------------------------------------------------------------

local pending = {} -- [id] = profil en cours de réception { version, count, parts, got, ... }

local function Token()
	return P.GetTeamToken and P.GetTeamToken()
end

local function Encode(text)
	return (text:gsub("[%%|\r\n\128-\255%z]", function(char)
		return string.format("%%%02X", char:byte())
	end))
end

local function Decode(text)
	return (text:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

-- Envoie un profil (ou sa pierre tombale) à target, sinon aux clients connectés.
function SendProfile(id, target)
	local token = Token()
	local profile = store and store[id]
	if not token or not profile or not P.WhisperOnline then
		return
	end
	local version = profile.updated or 0
	local text = profile.removed and "" or Encode(profile.text or "")
	local maxLength = P.MAX_MESSAGE_LENGTH or 255
	-- Place du texte dans un fragment, en-tête compris avec un n° de 5 chiffres au pire.
	local budget = maxLength - #string.format("PROF:%s:%s:+:%d:99999:", token, id, version)
	local count = math.ceil(#text / budget)
	local header = string.format("PROF:%s:%s:N:%d:%d:%s:%s:%s:", token, id, version, count,
		profile.kind or ns.DEFAULT_KIND, profile.removed and "R" or "A", profile.char or "")
	-- Nom tronqué s'il ne tient pas, sans couper un caractère encodé (%XX).
	local name = Encode(profile.name or ""):sub(1, maxLength - #header):gsub("%%%x?$", "")
	P.WhisperOnline(header .. name, target)
	for index = 1, count do
		P.WhisperOnline(string.format("PROF:%s:%s:+:%d:%d:%s", token, id, version, index,
			text:sub((index - 1) * budget + 1, index * budget)), target)
	end
	-- Saison et version du jeu : message à part (un champ de plus dans PROF serait mal lu par les
	-- versions précédentes, qui ignorent ce type).
	if not profile.removed and (profile.season or profile.build) then
		P.WhisperOnline(string.format("PROFINFO:%s:%s:%d:%s:%s", token, id, version,
			((profile.build or ""):gsub(":", "")), Encode(profile.season or "")), target)
	end
end

-- Envoie une liste « a,b,c » fragmentée : prefix .. morceau, sans couper un élément.
local function SendList(prefix, items, target)
	local budget = (P.MAX_MESSAGE_LENGTH or 255) - #prefix
	local current, used = {}, 0
	local function Flush()
		if #current > 0 then
			P.WhisperOnline(prefix .. table.concat(current, ","), target)
			current, used = {}, 0
		end
	end
	for _, item in ipairs(items) do
		local cost = #item + (#current > 0 and 1 or 0)
		if used + cost > budget then
			Flush()
			cost = #item
		end
		current[#current + 1] = item
		used = used + cost
	end
	Flush()
end

-- Rencontre d'un client : on lui annonce les versions de tous nos profils (pierres tombales
-- comprises) ; il demandera ceux qui sont plus récents chez nous.
local function SendVersions(target)
	local token = Token()
	if not token or not store or not P.WhisperOnline then
		return
	end
	local items = {}
	for id, profile in pairs(store) do
		items[#items + 1] = id .. "=" .. (profile.updated or 0)
	end
	table.sort(items)
	SendList("PROFV:" .. token .. ":", items, target)
end

-- PROFV : on demande les profils dont la version annoncée est plus récente que la nôtre.
local function OnVersions(rest, sender)
	local token = Token()
	if not token or not store then
		return
	end
	local wanted = {}
	for id, version in (rest or ""):gmatch("(%x+)=(%d+)") do
		local profile = store[id]
		if (profile and tonumber(profile.updated) or 0) < tonumber(version) then
			wanted[#wanted + 1] = id
		end
	end
	SendList("PROFREQ:" .. token .. ":", wanted, sender)
end

-- PROFREQ : un client demande certains de nos profils.
local function OnRequest(rest, sender)
	for id in (rest or ""):gmatch("%x+") do
		if store and store[id] then
			SendProfile(id, sender)
		end
	end
end

-- Profil reçu en entier : appliqué s'il est plus récent que le nôtre.
local function Commit(id, received)
	pending[id] = nil
	local profile = store[id]
	if profile and (tonumber(profile.updated) or 0) >= received.version then
		return
	end
	if received.removed then
		store[id] = { removed = true, updated = received.version }
	else
		store[id] = {
			name = received.name,
			kind = received.kind,
			text = Decode(table.concat(received.parts)),
			char = received.char ~= "" and received.char or nil,
			updated = received.version,
		}
	end
	Changed()
end

-- PROF : en-tête (N) ou fragment (+) d'un profil.
local function OnProfile(rest)
	if not store then
		return
	end
	local id, flag, version, remainder = strsplit(":", rest or "", 4)
	version = tonumber(version)
	if not id or not id:match("^%x+$") or not version then
		return
	end
	if flag == "N" then
		local count, kind, state, char, name = strsplit(":", remainder or "", 5)
		count = tonumber(count)
		local profile = store[id]
		if not count or (profile and tonumber(profile.updated) or 0) >= version then
			pending[id] = nil
			return -- déjà à jour
		end
		pending[id] = { version = version, count = count, got = 0, parts = {}, kind = kind,
			removed = state == "R", char = char or "", name = Decode(name or "") }
		if count == 0 then
			Commit(id, pending[id])
		end
	elseif flag == "+" then
		local received = pending[id]
		local index, chunk = strsplit(":", remainder or "", 2)
		index = tonumber(index)
		if not received or received.version ~= version or not index or index < 1 or index > received.count
			or received.parts[index] then
			return -- fragment d'une version qu'on n'attend pas
		end
		received.parts[index] = chunk or ""
		received.got = received.got + 1
		if received.got == received.count then
			Commit(id, received)
		end
	end
end

-- Personnage supprimé dans Polypode (Maj + clic dans « Personnages disponibles ») : les profils
-- rangés sous lui sont supprimés (pierres tombales propagées par la synchro de Profil ; rien à
-- faire quand la suppression vient d'un autre client, qui les propage lui-même). Polypode 0.53.0.
if P.RegisterCharacterData then
	local function ProfilesOf(key)
		local ids = {}
		for _, entry in ipairs(ns.GetProfiles()) do
			if entry.profile.char == key then
				ids[#ids + 1] = entry.id
			end
		end
		return ids
	end
	P.RegisterCharacterData({
		name = "Polypode Profil",
		describe = function(key)
			local count = #ProfilesOf(key)
			if count > 0 then
				return L["%d profil(s) rangé(s) sous ce personnage"]:format(count)
			end
		end,
		remove = function(key, fromSync)
			if fromSync then
				return
			end
			for _, id in ipairs(ProfilesOf(key)) do
				ns.Delete(id)
			end
		end,
	})
end

if P.RegisterMessageHandler then
	P.RegisterMessageHandler("PROF", OnProfile)
	P.RegisterMessageHandler("PROFV", OnVersions)
	P.RegisterMessageHandler("PROFREQ", OnRequest)
	-- PROFINFO:token:id:version:build:saison — contexte de jeu d'un profil, appliqué seulement
	-- à la version du profil qu'on détient (il suit les fragments PROF dans la file d'envoi).
	P.RegisterMessageHandler("PROFINFO", function(rest)
		local id, version, build, season = strsplit(":", rest or "", 4)
		local profile = store and id and store[id]
		if profile and not profile.removed and tonumber(profile.updated) == tonumber(version) then
			profile.build = build ~= "" and build or nil
			season = Decode(season or "")
			profile.season = season ~= "" and season or nil
			Changed()
		end
	end)
	P.RegisterPeerCallback(function(sender)
		SendVersions(sender)
	end)
end

-- ÉVÉNEMENTS ---------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == "Polypode_Profil" then
		PolypodeProfilDB = PolypodeProfilDB or {}
		PolypodeProfilDB.profiles = PolypodeProfilDB.profiles or {}
		store = PolypodeProfilDB.profiles
		for _, profile in pairs(store) do
			if profile.author then -- 1.0.0 : l'auteur devient le personnage du profil
				profile.char, profile.author = profile.char or profile.author, nil
			end
		end
		events:UnregisterEvent("ADDON_LOADED")
	end
end)
