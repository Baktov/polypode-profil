-- Polypode Profil: UI — fenêtre « Profils » : liste par personnage, éditeur, capture, copie

local _, ns = ...
local P = Polypode

-- Fenêtre PolypodeProfilFrame (bouton « Profils » de la fenêtre Polypode, /poly profil) :
--   * à gauche, les profils rangés sous leur personnage, affiché comme dans « Personnages
--     disponibles » de Polypode (couleur de classe, classe, niveau, « (vous) », connectés en tête,
--     déconnectés estompés) ; en-tête de personnage : clic gauche = replier / déplier, clic droit
--     = nouveau profil pour lui ; profil (genre puis nom) : clic gauche = ouvrir dans l'éditeur,
--     clic droit = menu (dupliquer, supprimer) ; détail au survol ;
--   * à droite, l'éditeur : nom, genre (menu), personnage (menu du roster), chaîne d'export
--     (zone défilante, Ctrl+V pour coller) ; « Capturer » relève la chaîne en jeu (mode Édition, talents) ; « Tout
--     sélectionner » prépare la copie (Ctrl+C) vers la fenêtre d'import de l'addon.
-- Une modification non enregistrée est signalée dans l'en-tête de l'éditeur ; changer de profil
-- la fait confirmer. Un profil modifié par un autre client est rechargé s'il n'est pas en cours
-- d'édition.

local MIN_WIDTH, MIN_HEIGHT = 860, 340 -- largeur : rangée de boutons du bas de l'éditeur
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 900, 480
local LIST_RATIO = 0.36 -- part de la largeur donnée à la liste

local frame, listPanel, editor, nameBox, kindButton, captureButton, charButton, textBox, deleteButton
local collapseAllButton -- « Tout replier » / « Tout déplier » du cadre Personnages
local selectedID -- profil ouvert dans l'éditeur (nil = nouveau)
local editKind = ns.DEFAULT_KIND
local editChar -- personnage sous lequel le profil en cours d'édition est rangé
local loaded = { name = "", kind = ns.DEFAULT_KIND, text = "" } -- état chargé, pour détecter une modification

local function WindowSettings()
	PolypodeProfilDB = PolypodeProfilDB or {}
	PolypodeProfilDB.window = PolypodeProfilDB.window or {}
	return PolypodeProfilDB.window
end

-- Personnages repliés dans la liste : { [clé] = true }.
local function Collapsed()
	PolypodeProfilDB = PolypodeProfilDB or {}
	PolypodeProfilDB.collapsed = PolypodeProfilDB.collapsed or {}
	return PolypodeProfilDB.collapsed
end

local function Gray(text)
	return "|cff999999" .. text .. "|r"
end

local function Notify(text)
	if UIErrorsFrame then
		UIErrorsFrame:AddMessage(text, 1, 0.82, 0)
	end
end

local function Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function FormatDate(version)
	return version and date("%d/%m/%Y %H:%M", version) or "?"
end

local function CharName(key)
	if not key or key == "" then
		return "?"
	end
	return P.GetDisplayName and P.GetDisplayName(key) or key
end

-- Personnage affiché comme dans « Personnages disponibles » (P.FormatCharacter de Polypode).
local function FormatChar(key)
	if P.FormatCharacter then
		return P.FormatCharacter({ key = key })
	end
	return CharName(key)
end

-- Même règle « connecté » que « Personnages disponibles » (P.IsCharacterConnected, Polypode 0.51.2).
local function IsConnected(key)
	if P.IsCharacterConnected then
		return P.IsCharacterConnected(key)
	end
	return key == P.GetCharKey() or (P.IsCharacterOnline and P.IsCharacterOnline(key)) or false
end

-- ÉDITEUR ------------------------------------------------------------------------------------

local function EditorText()
	return textBox and textBox:GetInputText() or ""
end

local function IsDirty()
	if not editor then
		return false
	end
	return Trim(nameBox:GetText()) ~= loaded.name or editKind ~= loaded.kind or editChar ~= loaded.char
		or Trim(EditorText()) ~= loaded.text
end

-- En-tête de l'éditeur : profil ouvert, date, taille, modification en cours.
local function UpdateEditorHeader()
	if not editor then
		return
	end
	local profile = selectedID and ns.Get(selectedID)
	local header
	if profile then
		header = profile.name .. Gray("  · " .. FormatDate(profile.updated))
	else
		header = "Nouveau profil"
	end
	local size = #Trim(EditorText())
	if size > 0 then
		header = header .. Gray("  · " .. size .. " caractères")
	end
	if IsDirty() then
		header = header .. "  |cffff9933(non enregistré)|r"
	end
	editor.header:SetText(header)
	deleteButton:SetEnabled(profile ~= nil)
end

-- Texte d'une liste déroulante (liste Blizzard : OverrideText, le texte ne suit pas la sélection ;
-- bouton de repli : SetText) et place disponible pour lui (sans la flèche).
local function SetChoiceText(choice, text)
	if choice.OverrideText then
		choice:OverrideText(text)
	else
		choice:SetText(text)
	end
end

local function ChoiceTextFits(choice)
	local label = choice.Text or (choice.GetFontString and choice:GetFontString())
	local margin = choice.OverrideText and 34 or 16
	return not label or label:GetStringWidth() <= choice:GetWidth() - margin
end

local function SetKind(kind)
	editKind = ns.NormalizeKind(kind)
	-- Libellé court (« Ensemble », « Simple AM »...) si le libellé complet ne tient pas.
	SetChoiceText(kindButton, ns.KindLabel(editKind))
	if not ChoiceTextFits(kindButton) then
		SetChoiceText(kindButton, ns.KindShortLabel(editKind))
	end
	captureButton:SetShown(ns.CanCapture(editKind))
	UpdateEditorHeader()
end

local function SetChar(key)
	editChar = key or P.GetCharKey()
	SetChoiceText(charButton, FormatChar(editChar))
	UpdateEditorHeader()
end

-- Ouvre un profil dans l'éditeur (id nil = nouveau, prérempli par copy s'il est fourni, rangé
-- sous le personnage char, par défaut le personnage joué).
local function Load(id, copy, char)
	local profile = id and ns.Get(id)
	selectedID = profile and id or nil
	local source = profile or copy or {}
	nameBox:SetText(source.name or "")
	nameBox:SetCursorPosition(0)
	textBox:SetText(source.text or "")
	SetKind(source.kind or editKind) -- nouveau profil : le genre précédent reste proposé
	SetChar(source.char or char)
	if profile then
		loaded.name, loaded.kind, loaded.text = Trim(profile.name), ns.NormalizeKind(profile.kind), Trim(profile.text)
		loaded.char = editChar
	else
		loaded.name, loaded.kind, loaded.text, loaded.char = "", editKind, "", editChar
	end
	UpdateEditorHeader()
	if ns.Refresh then
		ns.Refresh()
	end
end

-- Lance action tout de suite, ou après confirmation si l'éditeur a une modification non enregistrée.
local function ConfirmDiscard(action)
	if not IsDirty() then
		action()
		return
	end
	StaticPopup_Show("POLYPODE_PROFIL_DISCARD", nil, nil, action)
end

StaticPopupDialogs["POLYPODE_PROFIL_DISCARD"] = {
	text = "Le profil en cours d'édition n'est pas enregistré. Abandonner les modifications ?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, action)
		action()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- SUPPRESSION PAR SAISON : profils regroupés par la saison de leur sauvegarde (profile.season ;
-- clé "" = saison inconnue, sauvegardes antérieures à la 1.9.0).
local UNKNOWN_SEASON = ""

local function SeasonLabel(season)
	return season == UNKNOWN_SEASON and "Saison inconnue (sauvegardes anciennes)" or season
end

-- { { season, ids = { ... } }, ... } triées par nom de saison, inconnue en dernier.
local function ProfilesBySeason()
	local bySeason, list = {}, {}
	for _, entry in ipairs(ns.GetProfiles()) do
		local season = entry.profile.season or UNKNOWN_SEASON
		if not bySeason[season] then
			bySeason[season] = { season = season, ids = {} }
			list[#list + 1] = bySeason[season]
		end
		table.insert(bySeason[season].ids, entry.id)
	end
	table.sort(list, function(a, b)
		if (a.season == UNKNOWN_SEASON) ~= (b.season == UNKNOWN_SEASON) then
			return b.season == UNKNOWN_SEASON
		end
		return a.season < b.season
	end)
	return list
end

StaticPopupDialogs["POLYPODE_PROFIL_DELETE_SEASON"] = {
	text = "Supprimer les %s profil(s) enregistrés pendant « %s » ?\n(sur tous vos clients)",
	button1 = DELETE or "Supprimer",
	button2 = CANCEL,
	OnAccept = function(_, group)
		for _, id in ipairs(group.ids) do
			ns.Delete(id)
		end
		Notify(#group.ids .. " profil(s) supprimé(s) : " .. SeasonLabel(group.season) .. ".")
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function ShowSeasonDeleteMenu(button)
	local groups = ProfilesBySeason()
	if #groups == 0 or not (MenuUtil and MenuUtil.CreateContextMenu) then
		Notify("Aucun profil enregistré.")
		return
	end
	MenuUtil.CreateContextMenu(button, function(_, root)
		root:CreateTitle("Supprimer tous les profils de la saison")
		for _, group in ipairs(groups) do
			root:CreateButton(SeasonLabel(group.season) .. Gray(" (" .. #group.ids .. ")"), function()
				StaticPopup_Show("POLYPODE_PROFIL_DELETE_SEASON", #group.ids, SeasonLabel(group.season), group)
			end)
		end
	end)
end

StaticPopupDialogs["POLYPODE_PROFIL_DELETE"] = {
	text = "Supprimer le profil « %s » ?\n(sur tous vos clients)",
	button1 = DELETE or "Supprimer",
	button2 = CANCEL,
	OnAccept = function(_, id)
		ns.Delete(id)
		if selectedID == id then
			Load(nil)
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function Select(id)
	if id == selectedID then
		return
	end
	ConfirmDiscard(function()
		Load(id)
	end)
end

local function SaveEditor()
	local id, reason = ns.Save(selectedID, nameBox:GetText(), editKind, EditorText(), editChar)
	if not id then
		Notify(reason)
		return
	end
	Load(id)
end

local function AskDelete(id)
	local profile = ns.Get(id)
	if profile then
		StaticPopup_Show("POLYPODE_PROFIL_DELETE", profile.name, nil, id)
	end
end

local function SelectAll()
	if Trim(EditorText()) == "" then
		return
	end
	textBox:SetFocus()
	textBox:GetEditBox():HighlightText()
	Notify("Chaîne sélectionnée : Ctrl+C pour la copier.")
end

-- Chaîne capturée en jeu : remplace le texte ; le nom proposé n'est pris que si le nom est vide.
-- Chaîne capturée en jeu : toujours un nouveau profil (jamais le profil ouvert, qui serait écrasé
-- à l'enregistrement), du genre en cours, nommé name, rangé sous char (défaut : le personnage de
-- l'éditeur) ; confirmation si l'éditeur a une modification non enregistrée.
local function ApplyCapture(text, name, char)
	local kind, target = editKind, char or editChar
	ConfirmDiscard(function()
		Load(nil, { name = name, kind = kind, text = text }, target)
		Notify("Chaîne capturée : « Enregistrer » pour la garder.")
	end)
end

local function Capture(button)
	if editKind == "talents" then
		local text, nameOrReason = ns.ExportTalents()
		if text then
			ApplyCapture(text, nameOrReason, P.GetCharKey()) -- talents du personnage joué
		else
			Notify(nameOrReason)
		end
	elseif editKind == "transmog" then
		if not (MenuUtil and MenuUtil.CreateContextMenu) then
			return
		end
		local sets = ns.GetCustomSets()
		MenuUtil.CreateContextMenu(button, function(_, root)
			root:CreateTitle("Tenue à capturer")
			root:CreateButton("Apparence actuelle", function()
				ns.ExportCurrentAppearance(function(text, reason)
					if text then
						-- Tenue du personnage joué, datée : plusieurs captures restent distinctes.
						ApplyCapture(text, "Apparence actuelle (" .. FormatDate(GetServerTime()) .. ")", P.GetCharKey())
					else
						Notify(reason)
					end
				end)
			end)
			if #sets > 0 then
				root:CreateDivider()
				root:CreateTitle("Ensembles personnalisés")
				for _, set in ipairs(sets) do
					root:CreateButton(set.name, function()
						local text, reason = ns.ExportCustomSet(set.id)
						if text then
							ApplyCapture(text, set.name)
						else
							Notify(reason)
						end
					end)
				end
			end
		end)
	elseif editKind == "options" then
		local categories = ns.GetOptionCategories()
		if #categories == 0 or not (MenuUtil and MenuUtil.CreateContextMenu) then
			Notify("Aucun réglage lisible (ouvrez une fois le panneau Options, puis recommencez).")
			return
		end
		local function CaptureOptions(categoryName)
			local text, nameOrReason = ns.ExportOptions(categoryName)
			if text then
				ApplyCapture(text, nameOrReason)
			else
				Notify(nameOrReason)
			end
		end
		MenuUtil.CreateContextMenu(button, function(_, root)
			root:CreateTitle("Catégorie d'options à capturer")
			root:CreateButton("Toutes les catégories", function()
				CaptureOptions(nil)
			end)
			root:CreateDivider()
			for _, category in ipairs(categories) do
				root:CreateButton(category.name .. Gray(" (" .. category.count .. ")"), function()
					CaptureOptions(category.name)
				end)
			end
		end)
	elseif editKind == "simpleaddonmanager" then
		local names = ns.GetSAMProfiles()
		if #names == 0 or not (MenuUtil and MenuUtil.CreateContextMenu) then
			Notify(ns.HasSimpleAddonManager() and "Aucun profil dans Simple Addon Manager."
				or "Simple Addon Manager n'est pas chargé.")
			return
		end
		MenuUtil.CreateContextMenu(button, function(_, root)
			root:CreateTitle("Profil de Simple Addon Manager")
			-- Tous : enregistrés directement, un profil Polypode chacun (sans passer par l'éditeur).
			root:CreateButton("Tous les profils (enregistrés chacun)", function()
				local saved = 0
				for _, name in ipairs(names) do
					local text = ns.ExportSAMProfile(name)
					if text and ns.Save(nil, name, "simpleaddonmanager", text, P.GetCharKey()) then
						saved = saved + 1
					end
				end
				Notify(saved .. " profil(s) de Simple Addon Manager enregistré(s).")
			end)
			root:CreateDivider()
			for _, name in ipairs(names) do
				root:CreateButton(name, function()
					local text, reason = ns.ExportSAMProfile(name)
					if text then
						ApplyCapture(text, name)
					else
						Notify(reason)
					end
				end)
			end
		end)
	elseif editKind == "bindings" or editKind == "chat" or editKind == "addons" then
		local export = editKind == "bindings" and ns.ExportBindings or editKind == "chat" and ns.ExportChat
			or ns.ExportAddons
		local text, nameOrReason = export()
		if text then
			ApplyCapture(text, nameOrReason)
		else
			Notify(nameOrReason)
		end
	elseif editKind == "equipset" then
		local sets = ns.GetEquipmentSets()
		if #sets == 0 or not (MenuUtil and MenuUtil.CreateContextMenu) then
			Notify("Aucun ensemble d'équipement chez ce personnage.")
			return
		end
		MenuUtil.CreateContextMenu(button, function(_, root)
			root:CreateTitle("Ensemble à capturer")
			for _, set in ipairs(sets) do
				root:CreateButton(set.name .. (set.spec and Gray(" (" .. set.spec .. ")") or ""), function()
					local text, nameOrReason = ns.ExportEquipmentSet(set.id)
					if text then
						ApplyCapture(text, nameOrReason, P.GetCharKey()) -- ensemble du personnage joué
					else
						Notify(nameOrReason)
					end
				end)
			end
		end)
	elseif editKind == "title" then
		local text, nameOrReason = ns.ExportTitle()
		if text then
			ApplyCapture(text, nameOrReason, P.GetCharKey()) -- titre du personnage joué
		else
			Notify(nameOrReason)
		end
	elseif editKind == "editmode" then
		local layouts = ns.GetEditModeLayouts()
		if #layouts == 0 or not (MenuUtil and MenuUtil.CreateContextMenu) then
			Notify("Aucune disposition du mode Édition disponible.")
			return
		end
		MenuUtil.CreateContextMenu(button, function(_, root)
			root:CreateTitle("Disposition à capturer")
			for _, entry in ipairs(layouts) do
				root:CreateButton(entry.name .. (entry.active and Gray(" (active)") or ""), function()
					local text, reason = ns.ExportEditModeLayout(entry.layout)
					if text then
						ApplyCapture(text, "Mode Édition — " .. entry.name)
					else
						Notify(reason)
					end
				end)
			end
		end)
	end
end

-- Changer de genre réinitialise l'éditeur : nouveau profil vide (nom et chaîne effacés) de ce
-- genre, pour le même personnage ; le profil ouvert n'est pas modifié (confirmation si l'éditeur
-- a une modification non enregistrée).
local function ChangeKind(kind)
	if kind == editKind then
		return
	end
	local char = editChar
	ConfirmDiscard(function()
		editKind = kind
		Load(nil, nil, char)
	end)
end

-- Contenu de la liste déroulante des genres.
local function KindMenu(root)
	root:CreateTitle("Genre du profil")
	for _, kind in ipairs(ns.KINDS) do
		root:CreateRadio(kind.label, function()
			return editKind == kind.key
		end, function()
			ChangeKind(kind.key)
		end)
	end
end

-- Personnage du profil : menu des personnages du roster (connectés en tête), plus le personnage
-- actuel du profil s'il n'y est plus.
local function CharMenu(root)
	if not (P.SortedKeyItems and P.GetRoster) then
		return
	end
	local set = P.GetRoster()
	if editChar then
		set[editChar] = set[editChar] or true
	end
	root:CreateTitle("Personnage du profil")
	for _, item in ipairs(P.SortedKeyItems(set, IsConnected)) do
		root:CreateRadio(FormatChar(item.key), function()
			return editChar == item.key
		end, function()
			SetChar(item.key)
		end)
	end
end


-- LISTE --------------------------------------------------------------------------------------

-- Un en-tête par personnage (le personnage joué et ceux qui ont des profils ; connectés en tête,
-- puis ordre alphabétique, comme « Personnages disponibles »), suivi de ses profils (genre puis
-- nom, ordre de ns.GetProfiles) s'il n'est pas replié.
local function BuildItems()
	local byChar = { [P.GetCharKey()] = {} }
	for _, entry in ipairs(ns.GetProfiles()) do
		local key = entry.profile.char or "?"
		byChar[key] = byChar[key] or {}
		table.insert(byChar[key], entry)
	end
	local collapsed = Collapsed()
	local items = {}
	for _, item in ipairs(P.SortedKeyItems(byChar, IsConnected)) do
		local key = item.key
		items[#items + 1] = { header = true, key = key, online = item.first, count = #byChar[key],
			collapsed = collapsed[key] or false }
		if not collapsed[key] then
			for _, entry in ipairs(byChar[key]) do
				items[#items + 1] = entry
			end
		end
	end
	return items
end

-- Vrai si tous les personnages de la liste sont repliés (bouton « Tout déplier »).
local function AllCollapsed()
	for _, item in ipairs(BuildItems()) do
		if item.header and not item.collapsed then
			return false
		end
	end
	return true
end

local function ShowRowMenu(id)
	local profile = ns.Get(id)
	if not profile or not (MenuUtil and MenuUtil.CreateContextMenu) then
		return
	end
	MenuUtil.CreateContextMenu(frame, function(_, root)
		root:CreateTitle(profile.name)
		root:CreateButton("Dupliquer", function()
			ConfirmDiscard(function()
				Load(nil, { name = profile.name .. " (copie)", kind = profile.kind, text = profile.text,
					char = profile.char })
			end)
		end)
		root:CreateButton("Supprimer", function()
			AskDelete(id)
		end)
	end)
end

-- Nouveau profil rangé sous ce personnage (déplié pour le voir apparaître).
local function NewForChar(key)
	ConfirmDiscard(function()
		Collapsed()[key] = nil
		Load(nil, nil, key)
	end)
end

local function ShowCharRowMenu(key)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then
		return
	end
	MenuUtil.CreateContextMenu(frame, function(_, root)
		root:CreateTitle(CharName(key))
		root:CreateButton("Nouveau profil pour ce personnage", function()
			NewForChar(key)
		end)
	end)
end

-- ICÔNE D'ACTION devant certains profils (genre → action sur la chaîne du profil) :
--   transmogrification : ouvrir la cabine d'essayage sur la tenue (ns.TryOnTransmog) ; atlas
--     des jets de butin « transmogrification », icône d'objet si l'atlas manque (WoW Forever) ;
--   titre : porter le titre (ns.ApplyTitle) ;
--   ensemble d'équipement : le créer chez le personnage joué (ns.CreateEquipmentSet) ;
--   options, raccourcis, discussion : les appliquer (confirmation d'abord : ils remplacent la
--     configuration actuelle).
-- run(profil) renvoie ok, message (compte rendu affiché, sinon done) ou nil, raison.
local ACTION_SIZE = 16
local ShowReload -- boîte de rechargement, définie après ROW_ACTIONS
local ROW_ACTIONS = {
	transmog = {
		atlas = "lootroll-toast-icon-transmog",
		texture = "Interface\\Icons\\INV_Chest_Cloth_17",
		title = "Essayer la tenue",
		tooltip = "Ouvre la cabine d'essayage sur cette tenue (comme la chaîne collée dans la discussion). Hors combat.",
		hint = "essayer la tenue (cabine d'essayage)",
		run = function(profile)
			return ns.TryOnTransmog(profile.text)
		end,
	},
	equipset = {
		texture = "Interface\\Icons\\INV_Helmet_03",
		title = "Ajouter aux ensembles d'équipement",
		tooltip = "Crée cet ensemble (nom du profil) chez le personnage joué, avec sa spécialisation. WoW "
			.. "n'enregistre que ce qui est porté : les pièces (sacs ou équipées) sont équipées une à une, "
			.. "l'ensemble est créé, puis la tenue d'avant est remise. Hors combat.",
		hint = "ajouter aux ensembles d'équipement du personnage joué",
		done = "Création de l'ensemble…",
		run = function(profile)
			return ns.CreateEquipmentSet(profile.text, profile.name, Notify)
		end,
	},
	title = {
		texture = "Interface\\Icons\\INV_Scroll_03",
		title = "Porter ce titre",
		tooltip = "Le personnage joué porte ce titre (s'il le connaît) ; « Aucun titre » retire le titre.",
		hint = "porter ce titre",
		done = "Titre changé.",
		run = function(profile)
			return ns.ApplyTitle(profile.text)
		end,
	},
	options = {
		texture = "Interface\\Icons\\INV_Misc_Gear_01",
		title = "Appliquer ces options",
		tooltip = "Applique ces réglages du panneau Options de WoW (hors combat). Les réglages verrouillés ou "
			.. "inconnus sont ignorés ; certains réglages graphiques demandent de relancer le jeu.",
		hint = "appliquer ces options de WoW",
		confirm = "Les options de WoW de ce profil vont remplacer les vôtres.",
		run = function(profile)
			return ns.ApplyOptions(profile.text)
		end,
	},
	bindings = {
		texture = "Interface\\Icons\\INV_Misc_Key_03",
		title = "Appliquer ces raccourcis",
		tooltip = "Le jeu de raccourcis actif (compte ou personnage) devient celui du profil : les touches liées "
			.. "autrement sont libérées. Hors combat.",
		hint = "appliquer ces raccourcis clavier",
		confirm = "Vos raccourcis clavier actuels vont être remplacés par ceux de ce profil.",
		run = function(profile)
			return ns.ApplyBindings(profile.text)
		end,
	},
	chat = {
		texture = "Interface\\Icons\\INV_Letter_15",
		title = "Appliquer ce paramétrage",
		tooltip = "Fenêtres de discussion (ouvertes, fermées, nom, police, couleur, types de messages, canaux, "
			.. "position), couleurs des messages et réglages de la discussion. Hors combat ; /reload conseillé ensuite.",
		hint = "appliquer ce paramétrage de discussion",
		confirm = "Vos fenêtres de discussion vont être remplacées par celles de ce profil.",
		run = function(profile)
			return ns.ApplyChat(profile.text)
		end,
	},
	addons = {
		texture = "Interface\\Icons\\INV_Misc_Gear_08",
		title = "Appliquer cette liste d'addons",
		tooltip = "Active / désactive les addons de la liste pour le personnage joué (les autres ne changent pas ; "
			.. "Polypode et Polypode Profil restent activés), puis propose de recharger l'interface.",
		hint = "appliquer cette liste d'addons (rechargement ensuite)",
		confirm = "Les addons du personnage joué vont être activés / désactivés comme dans ce profil.",
		run = function(profile)
			local ok, message, needsReload = ns.ApplyAddons(profile.text)
			if ok and needsReload then
				return ok, message, function()
					ShowReload(message)
				end
			end
			return ok, message
		end,
	},
	simpleaddonmanager = {
		texture = 133742, -- icône de Simple Addon Manager
		title = "Importer dans Simple Addon Manager",
		tooltip = "Importe ce profil dans Simple Addon Manager (le profil du même nom y est remplacé), puis "
			.. "propose sa boîte « charger le profil et recharger ». Simple Addon Manager doit être chargé.",
		hint = "importer dans Simple Addon Manager",
		confirm = "Ce profil va être importé dans Simple Addon Manager (le profil du même nom y sera remplacé).",
		run = function(profile)
			return ns.ImportSAMProfile(profile.text)
		end,
	},
}

-- Rechargement proposé (Entrée ou clic sur « Recharger ») ; sur WoW Forever, où l'addon ne peut
-- pas recharger, un message demande de taper /reload.
StaticPopupDialogs["POLYPODE_PROFIL_RELOAD"] = {
	text = "%s\n\nRecharger l'interface maintenant pour appliquer ?",
	button1 = RELOADUI or "Recharger",
	button2 = "Plus tard",
	OnAccept = function()
		ns.Reload()
	end,
	enterClicksFirstButton = true,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function ShowReload(message)
	if ns.CanReload() then
		StaticPopup_Show("POLYPODE_PROFIL_RELOAD", message)
	else
		Notify(message .. " Tapez /reload pour appliquer.")
	end
end

-- Lignes de détail de l'infobulle d'un profil, par genre.
local KIND_DETAILS = {
	equipset = function(text)
		return ns.EquipmentSetDetails(text)
	end,
	options = function(text)
		return ns.OptionsDetails(text)
	end,
	bindings = function(text)
		return ns.BindingsDetails(text)
	end,
	chat = function(text)
		return ns.ChatDetails(text)
	end,
	addons = function(text)
		return ns.AddonsDetails(text)
	end,
}

-- run(profil) renvoie ok, message et éventuellement une suite (boîte de rechargement...),
-- lancée après l'affichage du message ; ou nil et la raison.
local function RunAction(action, profile)
	local ok, message, followUp = action.run(profile)
	if ok then
		if message or action.done then
			Notify(message or action.done)
		end
		if followUp then
			followUp()
		end
	else
		Notify(message)
	end
end

StaticPopupDialogs["POLYPODE_PROFIL_APPLY"] = {
	text = "%s\n\nAppliquer le profil « %s » ?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, data)
		RunAction(data.action, data.profile)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function RowTooltip(data)
	if data.header then
		-- Mêmes indications que « Personnages disponibles » (P.CharacterTooltip : nom, équipes).
		local hints = {
			data.online and "|cff40ff40Connecté|r" or "|cff999999Déconnecté (ou pas vu cette session)|r",
			data.count .. " profil(s)",
			"Clic gauche : " .. (data.collapsed and "déplier" or "replier"),
			"Clic droit : nouveau profil pour ce personnage",
		}
		if P.CharacterTooltip and P.GetCharacter and P.GetCharacter(data.key) then
			return P.CharacterTooltip(data.key, hints)
		end
		table.insert(hints, 1, CharName(data.key))
		return hints
	end
	local profile = data.profile
	local lines = {
		profile.name,
		"Genre : " .. ns.KindLabel(profile.kind),
		"Personnage : " .. CharName(profile.char),
		"Enregistré le " .. FormatDate(profile.updated),
		-- Saison et version du jeu au moment de la sauvegarde (inconnues avant la 1.9.0).
		"Enregistré sous : " .. (ns.GameContextText(profile) or Gray("inconnu (sauvegarde plus ancienne)")),
		#(profile.text or "") .. " caractères",
	}
	local details = KIND_DETAILS[ns.NormalizeKind(profile.kind)]
	for _, line in ipairs(details and details(profile.text) or {}) do
		lines[#lines + 1] = line
	end
	lines[#lines + 1] = " "
	local action = ROW_ACTIONS[ns.NormalizeKind(profile.kind)]
	if action then
		lines[#lines + 1] = Gray("Icône : " .. action.hint)
	end
	lines[#lines + 1] = Gray("Clic gauche : ouvrir dans l'éditeur")
	lines[#lines + 1] = Gray("Clic droit : dupliquer, supprimer")
	return lines
end

local function HasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- Habille l'icône selon l'action (atlas avec états survol / appui, sinon texture de repli).
local function SetActionIcon(button, action)
	if button.action == action then
		return
	end
	button.action = action
	if action.atlas and HasAtlas(action.atlas .. "-up") then
		button:SetNormalAtlas(action.atlas .. "-up")
		button:SetHighlightAtlas(action.atlas .. "-highlight")
		button:SetPushedAtlas(action.atlas .. "-down")
	else
		button:SetNormalTexture(action.texture)
		button:SetHighlightTexture(action.texture, "ADD")
		button:SetPushedTexture(action.texture)
	end
end

local function ActionButton(row)
	if row.actionButton then
		return row.actionButton
	end
	local button = CreateFrame("Button", nil, row)
	button:SetSize(ACTION_SIZE, ACTION_SIZE)
	button:SetPoint("LEFT", 14, 0)
	button:SetFrameLevel(row:GetFrameLevel() + 2)
	-- Lignes recyclées : l'icône agit sur la donnée courante de la ligne.
	button:SetScript("OnClick", function(self)
		local data = self:GetParent().data
		if not (self.action and data and data.profile) then
			return
		end
		if self.action.confirm then
			StaticPopup_Show("POLYPODE_PROFIL_APPLY", self.action.confirm, data.profile.name,
				{ action = self.action, profile = data.profile })
		else
			RunAction(self.action, data.profile)
		end
	end)
	button:SetScript("OnEnter", function(self)
		if not self.action then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(self.action.title)
		GameTooltip:AddLine(self.action.tooltip, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	row.actionButton = button
	return button
end

-- CONSTRUCTION -------------------------------------------------------------------------------

local function CreateButton(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	if P.SkinButton then
		P.SkinButton(button)
	end
	return button
end

-- Infobulle ajoutée au survol (HookScript : garde le survol propre aux listes déroulantes).
local function SetTooltip(widget, title, text)
	widget:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(title)
		GameTooltip:AddLine(text, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	widget:HookScript("OnLeave", GameTooltip_Hide)
end

local function LayoutPanels()
	listPanel:SetWidth(math.max(200, frame:GetWidth() * LIST_RATIO))
end

-- Liste déroulante Blizzard (WowStyle1DropdownTemplate : cadre et flèche qui signalent un choix),
-- menu construit à chaque ouverture par generator(root) ; à défaut (client sans ce modèle), bouton
-- qui ouvre le même menu, avec une flèche « v » à droite.
local function CreateChoice(parent, width, generator)
	local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	if ok and dropdown and dropdown.SetupMenu and dropdown.OverrideText then
		dropdown:SetSize(width, 24)
		dropdown:SetupMenu(function(_, root)
			generator(root)
		end)
		if P.SkinDropdown then -- Polypode 0.51.3 : skin EllesmereUI / ElvUI
			P.SkinDropdown(dropdown, width)
		end
		return dropdown
	end
	local button = CreateButton(parent, "", width, function(self)
		if MenuUtil and MenuUtil.CreateContextMenu then
			MenuUtil.CreateContextMenu(self, function(_, root)
				generator(root)
			end)
		end
	end)
	local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	arrow:SetPoint("RIGHT", -6, 0)
	arrow:SetText("v")
	return button
end

local function BuildEditor()
	editor = P.CreatePanel(frame, "")
	editor:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 8, 0)
	editor:SetPoint("BOTTOMRIGHT", -12, 12)

	-- Ligne du nom : « Nom » [champ] [genre] [Capturer]
	local nameLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameLabel:SetPoint("TOPLEFT", 10, -34)
	nameLabel:SetText("Nom")

	captureButton = CreateButton(editor, "Capturer", 80, function(self)
		Capture(self)
	end)
	captureButton:SetPoint("TOPRIGHT", -10, -29)
	SetTooltip(captureButton, "Capturer",
		"Relève la chaîne en jeu : une disposition du mode Édition (menu), les talents de la configuration "
			.. "active (la fenêtre des talents doit avoir été ouverte une fois), ou une tenue (apparence actuelle "
			.. "ou ensemble personnalisé : chaîne « /customset », à coller dans la discussion pour l'essayer), "
			.. "le titre porté (chaîne « /settitle »), un ensemble d'équipement (menu, avec sa spécialisation), les options de WoW (menu par catégorie), les raccourcis clavier ou les fenêtres de discussion. "
			.. "Chaque capture ouvre un nouveau profil, nommé d'après la disposition, les talents, le titre ou l'ensemble "
			.. "(« Apparence actuelle » datée) : le profil ouvert n'est jamais écrasé.")

	kindButton = CreateChoice(editor, 130, KindMenu)
	kindButton:SetPoint("RIGHT", captureButton, "LEFT", -6, 0)
	SetTooltip(kindButton, "Genre", "Mode Édition, talents ou addon d'où vient la chaîne (range la liste).")

	nameBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
	nameBox:SetHeight(20)
	nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
	nameBox:SetPoint("RIGHT", kindButton, "LEFT", -10, 0)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(80)
	nameBox:SetScript("OnTextChanged", UpdateEditorHeader)
	nameBox:SetScript("OnEnterPressed", nameBox.ClearFocus)
	nameBox:SetScript("OnEscapePressed", nameBox.ClearFocus)
	if P.SkinEditBox then
		P.SkinEditBox(nameBox)
	end

	-- Ligne du personnage : « Personnage » [menu du roster]
	local charLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	charLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -16)
	charLabel:SetText("Personnage")

	charButton = CreateChoice(editor, 200, CharMenu)
	charButton:SetPoint("LEFT", charLabel, "RIGHT", 12, 0)
	charButton:SetPoint("RIGHT", -10, 0)
	SetTooltip(charButton, "Personnage", "Personnage sous lequel le profil est rangé dans la liste.")

	-- Boutons du bas.
	local newButton = CreateButton(editor, "Nouveau", 80, function()
		ConfirmDiscard(function()
			Load(nil)
		end)
	end)
	newButton:SetPoint("BOTTOMLEFT", 10, 10)
	SetTooltip(newButton, "Nouveau profil", "Vide l'éditeur pour coller (Ctrl+V) une nouvelle chaîne d'export.")

	local saveButton = CreateButton(editor, "Enregistrer", 90, SaveEditor)
	saveButton:SetPoint("LEFT", newButton, "RIGHT", 6, 0)
	SetTooltip(saveButton, "Enregistrer",
		"Garde le profil (nom, genre, chaîne) pour tous vos personnages et l'envoie à vos autres clients connectés.")

	deleteButton = CreateButton(editor, "Supprimer", 80, function()
		if selectedID then
			AskDelete(selectedID)
		end
	end)
	deleteButton:SetPoint("LEFT", saveButton, "RIGHT", 6, 0)

	local seasonButton = CreateButton(editor, "Supprimer une saison", 140, function(self)
		ShowSeasonDeleteMenu(self)
	end)
	seasonButton:SetPoint("LEFT", deleteButton, "RIGHT", 6, 0)
	SetTooltip(seasonButton, "Supprimer une saison",
		"Liste les saisons de vos profils enregistrés ; en choisir une supprime (après confirmation) tous "
			.. "les profils enregistrés pendant cette saison, sur tous vos clients.")

	local selectButton = CreateButton(editor, "Tout sélectionner", 120, SelectAll)
	selectButton:SetPoint("BOTTOMRIGHT", -10, 10)
	SetTooltip(selectButton, "Tout sélectionner",
		"Sélectionne la chaîne : Ctrl+C pour la copier, puis Ctrl+V dans la fenêtre d'import du mode Édition, "
			.. "des talents ou de l'addon.")

	-- Zone de texte défilante (Ctrl+V pour coller une chaîne).
	local textPanel = P.CreatePanel(editor, "")
	textPanel:SetPoint("TOPLEFT", 8, -88)
	textPanel:SetPoint("BOTTOMRIGHT", -8, 40)

	textBox = CreateFrame("Frame", nil, textPanel, "ScrollingEditBoxTemplate")
	textBox:SetPoint("TOPLEFT", 8, -8)
	textBox:SetPoint("BOTTOMRIGHT", -8, 8)
	local editBox = textBox:GetEditBox()
	editBox:SetMaxLetters(0)
	if editBox.SetMaxBytes then
		editBox:SetMaxBytes(0)
	end
	textBox:SetDefaultText("Collez ici (Ctrl+V) la chaîne d'export du mode Édition, des talents ou d'un addon.")
	textBox:RegisterCallback("OnTextChanged", UpdateEditorHeader, editor)

	local scrollBar = CreateFrame("EventFrame", nil, textPanel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPRIGHT", -6, -8)
	scrollBar:SetPoint("BOTTOMRIGHT", -6, 8)
	local scrollBox = textBox:GetScrollBox()
	ScrollUtil.RegisterScrollBoxWithScrollBar(scrollBox, scrollBar)
	-- Place de la barre réservée seulement quand elle est affichée (comme les listes de Polypode).
	local topLeft = CreateAnchor("TOPLEFT", textPanel, "TOPLEFT", 8, -8)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar,
		{ topLeft, CreateAnchor("BOTTOMRIGHT", textPanel, "BOTTOMRIGHT", -24, 8) },
		{ topLeft, CreateAnchor("BOTTOMRIGHT", textPanel, "BOTTOMRIGHT", -8, 8) })

	P.SkinPanel(editor)
	P.SkinPanel(textPanel)
	if P.SkinScrollBar then
		P.SkinScrollBar(scrollBar)
	end
end

local function Build()
	local settings = WindowSettings()
	frame = CreateFrame("Frame", "PolypodeProfilFrame", UIParent, "BackdropTemplate")
	frame:SetSize(math.max(settings.width or DEFAULT_WIDTH, MIN_WIDTH),
		math.max(settings.height or DEFAULT_HEIGHT, MIN_HEIGHT))
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.9)
	frame:Hide()
	tinsert(UISpecialFrames, "PolypodeProfilFrame") -- Échap ferme la fenêtre

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 12, -8)
	title:SetText("Profils")
	frame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	frame.CloseButton = closeBtn

	listPanel = P.CreatePanel(frame, "Personnages")
	listPanel:SetPoint("TOPLEFT", 12, -36)
	listPanel:SetPoint("BOTTOMLEFT", 12, 12)

	-- « Tout replier » / « Tout déplier », à droite du titre du cadre : condense la liste.
	collapseAllButton = CreateButton(listPanel, "Tout replier", 90, function()
		local collapsed = Collapsed()
		if AllCollapsed() then
			wipe(collapsed)
		else
			for _, item in ipairs(BuildItems()) do
				if item.header then
					collapsed[item.key] = true
				end
			end
		end
		ns.Refresh()
	end)
	collapseAllButton:SetHeight(18)
	collapseAllButton:SetPoint("TOPRIGHT", -6, -4)
	listPanel.header:SetPoint("RIGHT", collapseAllButton, "LEFT", -6, 0)
	SetTooltip(collapseAllButton, "Tout replier / déplier",
		"Replie tous les personnages pour ne voir que leurs noms, ou les déplie tous.")
	P.CreateScrollList(listPanel, function(data)
		if data.header then
			-- Personnage comme dans « Personnages disponibles », précédé du repli, suivi du nombre.
			return "|cffffd200" .. (data.collapsed and "+" or "-") .. "|r " .. FormatChar(data.key)
				.. Gray(" (" .. data.count .. ")")
		end
		return Gray(ns.KindLabel(data.profile.kind) .. " · ") .. data.profile.name -- décalé par decorate
	end, nil, {
		onClick = function(data, button)
			if data.header then
				if button == "RightButton" then
					ShowCharRowMenu(data.key)
				else
					Collapsed()[data.key] = not data.collapsed or nil
					ns.Refresh()
				end
			elseif button == "RightButton" then
				ShowRowMenu(data.id)
			else
				Select(data.id)
			end
		end,
		isSelected = function(data)
			return data.id ~= nil and data.id == selectedID
		end,
		tooltip = RowTooltip,
		-- Personnages déconnectés estompés, comme dans « Personnages disponibles ».
		-- Profils en retrait sous leur personnage (place de l'icône « essayer » des profils de
		-- transmogrification) ; lignes recyclées : retrait et icône recalculés à chaque affichage.
		decorate = function(row, data)
			row:SetAlpha((data.header and not data.online) and 0.55 or 1)
			row.text:SetPoint("LEFT", data.header and 4 or (14 + ACTION_SIZE + 4), 0)
			local action = not data.header and ROW_ACTIONS[ns.NormalizeKind(data.profile.kind)]
			if action then
				local button = ActionButton(row)
				SetActionIcon(button, action)
				button:Show()
			elseif row.actionButton then
				row.actionButton:Hide()
			end
		end,
	})
	listPanel.emptyText:SetText("Aucun profil enregistré.")

	BuildEditor()

	-- Poignée de redimensionnement (coin bas-droit), taille gardée dans PolypodeProfilDB.window.
	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(frame:GetFrameLevel() + 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		local current = WindowSettings()
		current.width, current.height = frame:GetSize()
	end)
	frame.resizeGrip = grip
	frame:SetScript("OnSizeChanged", LayoutPanels)
	LayoutPanels()

	P.ui.profilFrame = frame
	P.ui.profilList = listPanel
	P.ui.profilEditor = editor

	P.SkinFrame(frame)
	P.SkinPanel(listPanel)

	Load(nil)
end

-- Remplit la liste, si la fenêtre est ouverte ; recharge le profil ouvert s'il a changé
-- ailleurs et n'est pas en cours d'édition.
function ns.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	if selectedID and not IsDirty() then
		local profile = ns.Get(selectedID)
		if not profile then
			Load(nil)
			return
		elseif Trim(profile.name) ~= loaded.name or ns.NormalizeKind(profile.kind) ~= loaded.kind
			or Trim(profile.text) ~= loaded.text then
			Load(selectedID)
			return
		end
	end
	P.SetListData(listPanel, BuildItems())
	collapseAllButton:SetText(AllCollapsed() and "Tout déplier" or "Tout replier")
	UpdateEditorHeader()
end

P.RefreshProfil = ns.Refresh

-- Ouvre / ferme la fenêtre (bouton « Profils », /poly profil).
function P.ToggleProfil()
	if not frame then
		Build()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		ns.Refresh()
	end
end

-- INTÉGRATION À POLYPODE -------------------------------------------------------------------------

if P.AddTitleButton then
	P.AddTitleButton({
		text = "Profils",
		width = 60,
		onClick = function()
			P.ToggleProfil()
		end,
		tooltip = {
			"Profils",
			"Chaînes d'export du mode Édition, des talents et des addons (EllesmereUI, ElvUI, Baganator, "
				.. "MySlots, Simple Addon Manager...), gardées pour tous vos personnages.",
		},
		onCreate = function(button)
			P.ui.profilButton = button
		end,
	})
end

if P.RegisterSlashCommand then
	P.RegisterSlashCommand("profil", P.ToggleProfil, "profils (chaînes d'export du mode Édition, des talents, des addons)")
end
