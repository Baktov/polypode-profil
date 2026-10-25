-- Polypode Profil: UI — fenêtre « Profils » : liste par personnage, éditeur, capture, copie

local _, ns = ...
local P = Polypode
local L = ns.L

-- Infobulles : notions de clic en bleu (règle commune, P.ShowTooltip de Polypode 0.59.1), sinon
-- affichage simple.
local function ShowTooltip()
	if P.ShowTooltip then
		P.ShowTooltip()
	else
		GameTooltip:Show()
	end
end

-- Fenêtre PolypodeProfilFrame (bouton « Profils » de la fenêtre Polypode, /poly profil) :
--   * à gauche, les profils rangés sous leur personnage, affiché comme dans « Personnages
--     disponibles » de Polypode (couleur de classe, classe, niveau, « (vous) », connectés en tête,
--     déconnectés estompés) ; en-tête de personnage : clic gauche = replier / déplier, clic droit
--     = nouveau profil pour lui ; profil (genre puis nom) : clic gauche = ouvrir dans l'éditeur,
--     clic droit = menu (dupliquer, supprimer) ; détail au survol ;
--   * à droite, l'éditeur : personnage du profil (en-tête, à droite, non modifiable), nom, genre (menu), chaîne d'export
--     (zone défilante, Ctrl+V pour coller) ; « Capturer » relève la chaîne en jeu (mode Édition, talents) ; « Tout
--     sélectionner » prépare la copie (Ctrl+C) vers la fenêtre d'import de l'addon.
-- Une modification non enregistrée est signalée dans l'en-tête de l'éditeur ; changer de profil
-- la fait confirmer. Un profil modifié par un autre client est rechargé s'il n'est pas en cours
-- d'édition.

local MIN_WIDTH, MIN_HEIGHT = 880, 340
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 900, 480
local LIST_RATIO = 0.36 -- part de la largeur donnée à la liste
local LIST_MIN_WIDTH = 320 -- rangée Dupliquer / Supprimer / Supprimer une saison sous la liste
local BUTTON_ROW = 28 -- hauteur réservée sous la liste pour cette rangée

local frame, listPanel, editor, nameBox, textBox, deleteButton
local saveButton, duplicateButton
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

-- Un profil enregistré s'ouvre en lecture seule (le dupliquer pour le reprendre) : seul un
-- nouveau profil peut avoir une modification non enregistrée.
local function IsDirty()
	if not editor or selectedID then
		return false
	end
	return Trim(nameBox:GetText()) ~= loaded.name or editKind ~= loaded.kind or Trim(EditorText()) ~= loaded.text
end

-- En-tête de l'éditeur : genre, profil ouvert, date, taille, modification en cours.
local function UpdateEditorHeader()
	if not editor then
		return
	end
	local profile = selectedID and ns.Get(selectedID)
	local header = Gray(ns.KindLabel(editKind) .. " · ")
	if profile then
		header = header .. profile.name .. Gray("  · " .. FormatDate(profile.updated) .. "  · " .. L["lecture seule"])
	else
		header = header .. L["Nouveau profil"]
	end
	local size = #Trim(EditorText())
	if size > 0 then
		header = header .. Gray("  · " .. L["%d caractères"]:format(size))
	end
	if IsDirty() then
		header = header .. "  |cffff9933" .. L["(non enregistré)"] .. "|r"
	end
	editor.header:SetText(header)
	saveButton:SetEnabled(not profile)
	duplicateButton:SetEnabled(profile ~= nil)
	deleteButton:SetEnabled(profile ~= nil)
end

-- Genre du profil, fixé au chargement (choisi dans le menu « Nouveau ») et affiché en tête de
-- l'en-tête, sans pouvoir le changer.
local function SetKind(kind)
	editKind = ns.NormalizeKind(kind)
	UpdateEditorHeader()
end

-- Personnage du profil, fixé au chargement (profil ouvert : le sien ; nouveau : le personnage
-- joué ou celui demandé) et affiché à droite de l'en-tête, sans pouvoir le changer.
local function SetChar(key)
	editChar = key or P.GetCharKey()
	editor.charText:SetText(FormatChar(editChar))
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
	-- Profil enregistré : lecture seule, le nom est un simple texte à la place du champ.
	nameBox:SetShown(not profile)
	editor.nameText:SetText(profile and profile.name or "")
	editor.nameText:SetShown(profile ~= nil)
	textBox:SetText(source.text or "")
	SetKind(source.kind or editKind) -- sans genre donné : le genre précédent reste
	SetChar(source.char or char)
	if profile then
		loaded.name, loaded.kind, loaded.text = Trim(profile.name), ns.NormalizeKind(profile.kind), Trim(profile.text)
	else
		-- Nom proposé (capture, préfixe d'addon, copie) : pas une modification à lui seul.
		loaded.name, loaded.kind, loaded.text = Trim(source.name), editKind, ""
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
	text = L["Le profil en cours d'édition n'est pas enregistré. Abandonner les modifications ?"],
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
	return season == UNKNOWN_SEASON and L["Saison inconnue"] or season
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
	text = L["Supprimer les %s profil(s) enregistrés pendant « %s » ?\n(sur tous vos clients)"],
	button1 = DELETE or L["Supprimer"],
	button2 = CANCEL,
	OnAccept = function(_, group)
		for _, id in ipairs(group.ids) do
			ns.Delete(id)
		end
		Notify(L["%d profil(s) supprimé(s) : %s."]:format(#group.ids, SeasonLabel(group.season)))
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function ShowSeasonDeleteMenu(button)
	local groups = ProfilesBySeason()
	if #groups == 0 or not (MenuUtil and MenuUtil.CreateContextMenu) then
		Notify(L["Aucun profil enregistré."])
		return
	end
	MenuUtil.CreateContextMenu(button, function(_, root)
		root:CreateTitle(L["Supprimer tous les profils de la saison"])
		for _, group in ipairs(groups) do
			root:CreateButton(SeasonLabel(group.season) .. Gray(" (" .. #group.ids .. ")"), function()
				StaticPopup_Show("POLYPODE_PROFIL_DELETE_SEASON", #group.ids, SeasonLabel(group.season), group)
			end)
		end
	end)
end

StaticPopupDialogs["POLYPODE_PROFIL_DELETE"] = {
	text = L["Supprimer le profil « %s » ?\n(sur tous vos clients)"],
	button1 = DELETE or L["Supprimer"],
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

-- Nom d'un profil d'addon (genres « prefix » : EllesmereUI, ElvUI, Baganator, MySlots) : préfixé
-- par le nom de l'addon, « ElvUI — nom » (rien d'autre que le préfixe = le nom de l'addon seul) ;
-- autres genres : inchangé.
local NAME_SEPARATOR = " — "

local function NamePrefix(kind)
	return ns.KindNamePrefix(kind)
end

local function PrefixedName(kind, name)
	local prefix = NamePrefix(kind)
	name = Trim(name)
	if not prefix then
		return name
	end
	if name == "" or name == prefix or name == Trim(prefix .. NAME_SEPARATOR) then
		return prefix
	elseif name:sub(1, #prefix):lower() == prefix:lower() then
		return name
	end
	return prefix .. NAME_SEPARATOR .. name
end

-- Enregistre le nouveau profil de l'éditeur (un profil enregistré, en lecture seule, ne
-- s'enregistre pas : le dupliquer).
local function SaveEditor()
	if selectedID then
		return
	end
	local id, reason = ns.Save(nil, PrefixedName(editKind, nameBox:GetText()), editKind, EditorText(), editChar)
	if not id then
		Notify(reason)
		return
	end
	Load(id)
end

-- Copie d'un profil pour le personnage joué : nouveau profil prérempli (même genre, même chaîne ;
-- nom suivi de « (copie) » s'il reste au même personnage), à enregistrer sous lui.
local function Duplicate(id)
	local profile = ns.Get(id)
	if not profile then
		return
	end
	local char = P.GetCharKey()
	ConfirmDiscard(function()
		local name = profile.char == char and L["%s (copie)"]:format(profile.name) or profile.name
		Load(nil, { name = name, kind = profile.kind, text = profile.text }, char)
	end)
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
	Notify(L["Chaîne sélectionnée : Ctrl+C pour la copier."])
end

-- NOUVEAU PROFIL -----------------------------------------------------------------------------

-- Nouveau profil du genre kind dans l'éditeur, rangé sous char (défaut : le personnage joué),
-- prérempli par une chaîne capturée (text, name) ou vide pour y coller une chaîne ; jamais le
-- profil ouvert, qui reste tel quel. Confirmation si l'éditeur a une modification non enregistrée.
local function StartNew(kind, char, text, name)
	ConfirmDiscard(function()
		-- Genre à coller d'un addon : nom proposé « ElvUI — », à compléter.
		local prefix = not name and NamePrefix(kind)
		Load(nil, { name = prefix and (prefix .. NAME_SEPARATOR) or name, kind = kind, text = text }, char)
		if prefix then
			nameBox:SetCursorPosition(#nameBox:GetText())
		end
		if text then
			Notify(L["Chaîne capturée : « Enregistrer » pour la garder."])
		else
			textBox:SetFocus()
			Notify(L["Collez la chaîne (Ctrl+V), puis « Enregistrer »."])
		end
	end)
end

-- Capture par une fonction d'export qui renvoie texte, nom (ou nil, raison) : done(texte, nom, own),
-- own = rangée sous le personnage joué ; sinon la raison est affichée.
local function Run(done, own, export, ...)
	local text, nameOrReason = export(...)
	if text then
		done(text, nameOrReason, own)
	else
		Notify(nameOrReason)
	end
end

-- Sous-menu de capture de chaque genre capturable : CAPTURES[genre](menu, done) ajoute ses entrées
-- à menu (description MenuUtil) ; done(texte, nom, own) ouvre le nouveau profil (own = rangé sous
-- le personnage joué : talents, titre, tenue actuelle, macro de personnage, ensemble, barres).
local CAPTURES = {
	transmog = function(menu, done)
		menu:CreateButton(L["Apparence actuelle"], function()
			ns.ExportCurrentAppearance(function(text, reason)
				if text then
					-- Tenue du personnage joué, datée : plusieurs captures restent distinctes.
					done(text, L["Apparence actuelle (%s)"]:format(FormatDate(GetServerTime())), true)
				else
					Notify(reason)
				end
			end)
		end)
		local sets = ns.GetCustomSets()
		if #sets > 0 then
			menu:CreateTitle(L["Ensembles personnalisés"])
			for _, set in ipairs(sets) do
				menu:CreateButton(set.name, function()
					local text, reason = ns.ExportCustomSet(set.id)
					if text then
						done(text, set.name)
					else
						Notify(reason)
					end
				end)
			end
		end
	end,
	title = function(menu, done)
		menu:CreateButton(L["Titre porté"], function()
			Run(done, true, ns.ExportTitle)
		end)
	end,
	macro = function(menu, done)
		local macros = ns.GetMacros()
		if #macros == 0 then
			menu:CreateTitle(L["Aucune macro chez ce personnage."])
			return
		end
		local function AddGroup(title, perCharacter)
			local first = true
			for _, macro in ipairs(macros) do
				if macro.perCharacter == perCharacter then
					if first then
						menu:CreateTitle(title)
						first = false
					end
					local icon = macro.icon and ("|T" .. macro.icon .. ":16|t ") or ""
					menu:CreateButton(icon .. macro.name, function()
						Run(done, perCharacter, ns.ExportMacro, macro.index)
					end)
				end
			end
		end
		AddGroup(L["Macros générales"], false)
		AddGroup(L["Macros de %s"]:format(P.GetDisplayName(P.GetCharKey())), true)
	end,
	equipset = function(menu, done)
		local sets = ns.GetEquipmentSets()
		if #sets == 0 then
			menu:CreateTitle(L["Aucun ensemble d'équipement chez ce personnage."])
			return
		end
		for _, set in ipairs(sets) do
			menu:CreateButton(set.name .. (set.spec and Gray(" (" .. set.spec .. ")") or ""), function()
				Run(done, true, ns.ExportEquipmentSet, set.id)
			end)
		end
	end,
	actionbars = function(menu, done)
		menu:CreateButton(L["Capturer"], function()
			Run(done, true, ns.ExportActionBars)
		end)
	end,
	options = function(menu, done)
		local categories = ns.GetOptionCategories()
		if #categories == 0 then
			menu:CreateTitle(L["Aucun réglage lisible (ouvrez une fois le panneau Options, puis recommencez)."])
			return
		end
		menu:CreateButton(L["Toutes les catégories"], function()
			Run(done, false, ns.ExportOptions, nil)
		end)
		menu:CreateDivider()
		for _, category in ipairs(categories) do
			menu:CreateButton(category.name .. Gray(" (" .. category.count .. ")"), function()
				Run(done, false, ns.ExportOptions, category.name)
			end)
		end
	end,
	bindings = function(menu, done)
		menu:CreateButton(L["Capturer"], function()
			Run(done, false, ns.ExportBindings)
		end)
	end,
	chat = function(menu, done)
		menu:CreateButton(L["Capturer"], function()
			Run(done, false, ns.ExportChat)
		end)
	end,
	addons = function(menu, done)
		menu:CreateButton(L["Capturer"], function()
			Run(done, false, ns.ExportAddons)
		end)
	end,
	simpleaddonmanager = function(menu, done)
		local names = ns.GetSAMProfiles()
		if #names == 0 then
			menu:CreateTitle(ns.HasSimpleAddonManager() and L["Aucun profil dans Simple Addon Manager."]
				or L["Simple Addon Manager n'est pas chargé."])
			return
		end
		-- Tous : enregistrés directement, un profil Polypode chacun (sans passer par l'éditeur).
		menu:CreateButton(L["Tous les profils (enregistrés chacun)"], function()
			local saved = 0
			for _, name in ipairs(names) do
				local text = ns.ExportSAMProfile(name)
				if text and ns.Save(nil, name, "simpleaddonmanager", text, P.GetCharKey()) then
					saved = saved + 1
				end
			end
			Notify(L["%d profil(s) de Simple Addon Manager enregistré(s)."]:format(saved))
		end)
		menu:CreateDivider()
		for _, name in ipairs(names) do
			menu:CreateButton(name, function()
				local text, reason = ns.ExportSAMProfile(name)
				if text then
					done(text, name)
				else
					Notify(reason)
				end
			end)
		end
	end,
	elvui = function(menu, done)
		if not ns.HasElvUI() then
			menu:CreateTitle(L["ElvUI n'est pas chargé."])
			return
		end
		-- Profils nommés (partagés), puis réglages du personnage, du compte et filtres d'auras.
		local names, active = ns.GetElvUIProfiles()
		menu:CreateTitle(L["Profils"])
		for _, name in ipairs(names) do
			menu:CreateButton(name .. (name == active and Gray(" " .. L["(actif)"]) or ""), function()
				Run(done, false, ns.ExportElvUI, "profile", name)
			end)
		end
		menu:CreateDivider()
		menu:CreateButton(L["Réglages du personnage (private)"], function()
			Run(done, true, ns.ExportElvUI, "private")
		end)
		menu:CreateButton(L["Réglages du compte (global)"], function()
			Run(done, false, ns.ExportElvUI, "global")
		end)
		menu:CreateButton(L["Filtres d'auras (filters)"], function()
			Run(done, false, ns.ExportElvUI, "filters")
		end)
	end,
	ellesmereui = function(menu, done)
		if not ns.HasEllesmereUI() then
			menu:CreateTitle(L["EllesmereUI n'est pas chargé."])
			return
		end
		local names, active = ns.GetEllesmereUIProfiles()
		menu:CreateTitle(L["Profils"])
		for _, name in ipairs(names) do
			menu:CreateButton(name .. (name == active and Gray(" " .. L["(actif)"]) or ""), function()
				Run(done, false, ns.ExportEllesmereUI, name)
			end)
		end
		menu:CreateDivider()
		menu:CreateButton(L["Export complet (compte et profil actif)"], function()
			Run(done, false, ns.ExportEllesmereUIFull)
		end)
	end,
	details = function(menu, done)
		if not ns.HasDetails() then
			menu:CreateTitle(L["%s n'est pas chargé."]:format("Details!"))
			return
		end
		local names, active = ns.GetDetailsProfiles()
		menu:CreateTitle(L["Profils"])
		for _, name in ipairs(names) do
			menu:CreateButton(name .. (name == active and Gray(" " .. L["(actif)"]) or ""), function()
				Run(done, false, ns.ExportDetails, name)
			end)
		end
	end,
	tlm = function(menu, done)
		if not ns.HasTLM() then
			menu:CreateTitle(L["%s n'est pas chargé."]:format("TalentLoadoutManager"))
			return
		end
		local loadouts = ns.GetTLMLoadouts()
		if #loadouts == 0 then
			menu:CreateTitle(L["Aucune configuration pour cette spécialisation."])
			return
		end
		menu:CreateTitle(L["Configurations de la spécialisation"])
		for _, loadout in ipairs(loadouts) do
			menu:CreateButton(loadout.name, function()
				Run(done, true, ns.ExportTLM, loadout.id, loadout.name)
			end)
		end
	end,
	editmode = function(menu, done)
		local layouts = ns.GetEditModeLayouts()
		if #layouts == 0 then
			menu:CreateTitle(L["Aucune disposition du mode Édition disponible."])
			return
		end
		for _, entry in ipairs(layouts) do
			menu:CreateButton(entry.name .. (entry.active and Gray(" " .. L["(active)"]) or ""), function()
				local text, reason = ns.ExportEditModeLayout(entry.layout)
				if text then
					done(text, L["Mode Édition — %s"]:format(entry.name))
				else
					Notify(reason)
				end
			end)
		end
	end,
	talents = function(menu, done)
		menu:CreateButton(L["Configuration active"], function()
			Run(done, true, ns.ExportTalents)
		end)
	end,
}

-- Baganator, Chattynator, Platynator : capture recopiée de leur export (pas de fonction publique).
for _, kind in ipairs({ "baganator", "chattynator", "platynator" }) do
	CAPTURES[kind] = function(menu, done)
		local names, active = ns.GetPlusmouseProfiles(kind)
		if #names == 0 then
			menu:CreateTitle(L["%s n'est pas chargé."]:format(ns.KindLabel(kind)))
			return
		end
		menu:CreateTitle(L["Capturer (bêta)"])
		for _, name in ipairs(names) do
			menu:CreateButton(name .. (name == active and Gray(" " .. L["(actif)"]) or ""), function()
				Run(done, false, ns.ExportPlusmouse, kind, name)
			end)
		end
	end
end

local MENU_MAX_SCREEN_RATIO = 0.5 -- hauteur maximale d'un menu, en part de l'écran

-- Genres dont la capture recopie un format privé de l'addon (fragile) : « Capturer (bêta) ».
local BETA_CAPTURE = { baganator = true, chattynator = true, platynator = true }

-- Genres mis en avant dans le menu « Nouveau » (libellé en bleu foncé).
-- Libellé d'un genre dans le menu, dans la couleur de sa famille (ns.KIND_FAMILIES).
local function MenuKindLabel(kind)
	return ns.ColorByKind(kind.key, kind.label)
end

-- Menu « Nouveau » : une section par groupe de genres (ns.KIND_GROUPS) ; genre capturable =
-- sous-menu (captures en jeu, puis « Coller une chaîne »), genre à coller = nouveau profil vide.
-- char : personnage du nouveau profil (défaut : le personnage joué).
local function ShowNewMenu(owner, char)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then
		StartNew(ns.DEFAULT_KIND, char)
		return
	end
	-- Menu et sous-menus (macros, options...) limités à la moitié de l'écran, avec ascenseur au-delà.
	local maxHeight = UIParent:GetHeight() * MENU_MAX_SCREEN_RATIO
	local function Limit(description)
		if description.SetScrollMode then
			description:SetScrollMode(maxHeight)
		end
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		Limit(root)
		if char and char ~= P.GetCharKey() then
			root:CreateTitle(L["Nouveau profil pour %s"]:format(CharName(char)))
			root:CreateDivider()
		end
		for index, group in ipairs(ns.KIND_GROUPS) do
			if index > 1 then
				root:CreateDivider()
			end
			root:CreateTitle(group.label)
			for _, kind in ipairs(ns.KINDS) do
				-- Genre d'un addon non chargé sur ce personnage : absent du menu.
				if kind.group == group.key and ns.KindAvailable(kind.key) then
					local fill = CAPTURES[kind.key]
					if fill then
						local menu = root:CreateButton(MenuKindLabel(kind))
					Limit(menu)
						-- Lecture fragile (API absente sur un client) : le reste du menu s'affiche quand même.
						if not pcall(fill, menu, function(text, name, own)
							StartNew(kind.key, own and P.GetCharKey() or char, text, name)
						end) then
							menu:CreateTitle(L["Capture indisponible sur ce client."])
						end
						menu:CreateDivider()
						-- Capture « bêta » : le collage, lui, est sûr.
						menu:CreateButton(BETA_CAPTURE[kind.key] and L["Coller une chaîne (fiable)"] or L["Coller une chaîne"], function()
							StartNew(kind.key, char)
						end)
					else
						root:CreateButton(MenuKindLabel(kind), function()
							StartNew(kind.key, char)
						end)
					end
				end
			end
		end
	end)
end


-- LISTE --------------------------------------------------------------------------------------

-- Clés de repli (PolypodeProfilDB.collapsed) : une saison, un personnage dans une saison.
local function SeasonFoldKey(season)
	return "S:" .. season
end

local function CharFoldKey(season, key)
	return "C:" .. season .. "|" .. key
end

-- Arbre saison → personnage → profils. Saison d'un profil = profile.season, celle de son dernier
-- enregistrement ("" = inconnue). Saison en cours d'abord, puis de la plus récente à la plus
-- ancienne (dernier enregistrement), inconnue en dernier. Dans une saison : un en-tête par
-- personnage (connectés en tête, puis ordre alphabétique, comme « Personnages disponibles »),
-- suivi de ses profils (genre puis nom, ordre de ns.GetProfiles). Le personnage joué figure
-- toujours dans la saison en cours, même sans profil. Un en-tête replié cache ce qu'il contient.
local function BuildItems()
	local current = ns.CurrentSeason() or UNKNOWN_SEASON
	local bySeason, groups = {}, {}
	local function Group(season)
		if not bySeason[season] then
			bySeason[season] = { season = season, byChar = {}, count = 0, latest = 0 }
			groups[#groups + 1] = bySeason[season]
		end
		return bySeason[season]
	end
	Group(current).byChar[P.GetCharKey()] = {}
	for _, entry in ipairs(ns.GetProfiles()) do
		local group = Group(entry.profile.season or UNKNOWN_SEASON)
		local key = entry.profile.char or "?"
		group.byChar[key] = group.byChar[key] or {}
		table.insert(group.byChar[key], entry)
		group.count = group.count + 1
		group.latest = math.max(group.latest, tonumber(entry.profile.updated) or 0)
	end
	local function Rank(group)
		return group.season == current and 0 or group.season == UNKNOWN_SEASON and 2 or 1
	end
	table.sort(groups, function(a, b)
		if Rank(a) ~= Rank(b) then
			return Rank(a) < Rank(b)
		end
		return a.latest > b.latest
	end)

	local collapsed = Collapsed()
	local items = {}
	for _, group in ipairs(groups) do
		local seasonFold = SeasonFoldKey(group.season)
		items[#items + 1] = { header = true, isSeason = true, season = group.season, fold = seasonFold,
			count = group.count, collapsed = collapsed[seasonFold] or false }
		if not collapsed[seasonFold] then
			for _, item in ipairs(P.SortedKeyItems(group.byChar, IsConnected)) do
				local key, fold = item.key, CharFoldKey(group.season, item.key)
				items[#items + 1] = { header = true, key = key, fold = fold, online = item.first,
					count = #group.byChar[key], collapsed = collapsed[fold] or false }
				if not collapsed[fold] then
					for _, entry in ipairs(group.byChar[key]) do
						items[#items + 1] = entry
					end
				end
			end
		end
	end
	return items
end

-- Vrai si toutes les saisons de la liste sont repliées (bouton « Tout déplier »).
local function AllCollapsed()
	for _, item in ipairs(BuildItems()) do
		if item.isSeason and not item.collapsed then
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
		root:CreateButton(L["Dupliquer"], function()
			Duplicate(id)
		end)
		root:CreateButton(L["Supprimer"], function()
			AskDelete(id)
		end)
	end)
end

-- Clic droit sur un personnage : menu « Nouveau » pour lui ; le profil sera enregistré dans la
-- saison en cours, dépliée (avec le personnage) pour le voir apparaître.
local function ShowCharRowMenu(key)
	local season = ns.CurrentSeason() or UNKNOWN_SEASON
	local collapsed = Collapsed()
	collapsed[SeasonFoldKey(season)] = nil
	collapsed[CharFoldKey(season, key)] = nil
	ShowNewMenu(frame, key)
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
-- Retraits de la liste : saison, personnage, profil (icône d'action puis texte).
local SEASON_INDENT, CHAR_INDENT, PROFILE_INDENT = 4, 14, 24
local ShowReload -- boîte de rechargement, définie après ROW_ACTIONS
local ROW_ACTIONS = {
	transmog = {
		atlas = "lootroll-toast-icon-transmog",
		texture = "Interface\\Icons\\INV_Chest_Cloth_17",
		title = L["Essayer / appliquer la tenue"],
		tooltip = L["Partout : ouvre la cabine d'essayage sur cette tenue. Chez le transmogrificateur (fenêtre "
			.. "ouverte) : charge la tenue dans sa fenêtre, par un ensemble personnalisé du nom du profil (créé "
			.. "s'il n'existe pas) ; « Appliquer » de Blizzard la valide et la paie. Hors combat."],
		hint = L["essayer la tenue, ou l'appliquer chez le transmogrificateur"],
		-- Transmogrificateur ouvert : appliquer ; sinon essayer.
		run = function(profile)
			if ns.IsAtTransmogrifier() then
				return ns.ApplyTransmog(profile.text, profile.name)
			end
			return ns.TryOnTransmog(profile.text)
		end,
	},
	equipset = {
		texture = "Interface\\Icons\\INV_Helmet_03",
		title = L["Ajouter aux ensembles d'équipement"],
		tooltip = L["Crée cet ensemble (nom du profil) chez le personnage joué, avec sa spécialisation. WoW "
			.. "n'enregistre que ce qui est porté : les pièces (sacs ou équipées) sont équipées une à une, "
			.. "l'ensemble est créé, puis la tenue d'avant est remise. Hors combat."],
		hint = L["ajouter aux ensembles d'équipement du personnage joué"],
		done = L["Création de l'ensemble…"],
		run = function(profile)
			return ns.CreateEquipmentSet(profile.text, profile.name, Notify)
		end,
	},
	title = {
		texture = "Interface\\Icons\\INV_Scroll_03",
		title = L["Porter ce titre"],
		tooltip = L["Le personnage joué porte ce titre (s'il le connaît) ; « Aucun titre » retire le titre."],
		hint = L["porter ce titre"],
		done = L["Titre changé."],
		run = function(profile)
			return ns.ApplyTitle(profile.text)
		end,
	},
	macro = {
		texture = 134400, -- repli : point d'interrogation ; sinon l'icône de la macro (iconFor)
		iconFor = function(profile)
			return ns.MacroIcon(profile.text)
		end,
		title = L["Ajouter aux macros"],
		tooltip = L["Crée cette macro (nom, icône, texte) chez le personnage joué, dans les macros générales "
			.. "ou propres au personnage selon le profil ; une macro du même nom est mise à jour. Hors combat."],
		hint = L["ajouter aux macros du personnage joué"],
		-- Confirmation seulement si une macro du même nom serait remplacée.
		confirm = function(profile)
			return ns.MacroExists(profile.text) and L["Une macro de ce nom existe déjà : elle va être remplacée."] or nil
		end,
		run = function(profile)
			return ns.AddMacro(profile.text)
		end,
	},
	actionbars = {
		texture = 132333, -- ability_warrior_battleshout
		title = L["Appliquer ces barres d'action"],
		tooltip = L["Repose chaque action du profil (sorts, objets, macros, montures, mascottes, ensembles...) sur les "
			.. "barres 1 à 15 du personnage joué et vide les autres emplacements. Les macros sont retrouvées par "
			.. "leur nom, sinon créées. Un sort non appris ou un objet absent laisse l'emplacement vide. Hors combat."],
		hint = L["appliquer ces barres d'action au personnage joué"],
		confirm = function(profile)
			return ns.ActionBarsConfirm(profile.text)
		end,
		run = function(profile)
			return ns.ApplyActionBars(profile.text)
		end,
	},
	options = {
		texture = "Interface\\Icons\\INV_Misc_Gear_01",
		title = L["Appliquer ces options"],
		tooltip = L["Applique ces réglages du panneau Options de WoW (hors combat). Les réglages verrouillés ou "
			.. "inconnus sont ignorés ; certains réglages graphiques demandent de relancer le jeu."],
		hint = L["appliquer ces options de WoW"],
		confirm = L["Les options de WoW de ce profil vont remplacer les vôtres."],
		run = function(profile)
			return ns.ApplyOptions(profile.text)
		end,
	},
	bindings = {
		texture = "Interface\\Icons\\INV_Misc_Key_03",
		title = L["Appliquer ces raccourcis"],
		tooltip = L["Le jeu de raccourcis actif (compte ou personnage) devient celui du profil : les touches liées "
			.. "autrement sont libérées. Hors combat."],
		hint = L["appliquer ces raccourcis clavier"],
		confirm = L["Vos raccourcis clavier actuels vont être remplacés par ceux de ce profil."],
		run = function(profile)
			return ns.ApplyBindings(profile.text)
		end,
	},
	chat = {
		texture = "Interface\\Icons\\INV_Letter_15",
		title = L["Appliquer ce paramétrage"],
		tooltip = L["Fenêtres de discussion (ouvertes, fermées, nom, police, couleur, types de messages, canaux, "
			.. "position), couleurs des messages et réglages de la discussion. Hors combat ; /reload conseillé ensuite."],
		hint = L["appliquer ce paramétrage de discussion"],
		confirm = L["Vos fenêtres de discussion vont être remplacées par celles de ce profil."],
		run = function(profile)
			return ns.ApplyChat(profile.text)
		end,
	},
	addons = {
		texture = "Interface\\Icons\\INV_Misc_Gear_08",
		title = L["Appliquer cette liste d'addons"],
		tooltip = L["Active / désactive les addons de la liste pour le personnage joué (les autres ne changent pas ; "
			.. "Polypode et Polypode Profil restent activés), puis propose de recharger l'interface."],
		hint = L["appliquer cette liste d'addons (rechargement ensuite)"],
		confirm = L["Les addons du personnage joué vont être activés / désactivés comme dans ce profil."],
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
		title = L["Importer dans Simple Addon Manager"],
		tooltip = L["Importe ce profil dans Simple Addon Manager (le profil du même nom y est remplacé), puis "
			.. "propose sa boîte « charger le profil et recharger ». Simple Addon Manager doit être chargé."],
		hint = L["importer dans Simple Addon Manager"],
		confirm = L["Ce profil va être importé dans Simple Addon Manager (le profil du même nom y sera remplacé)."],
		run = function(profile)
			return ns.ImportSAMProfile(profile.text)
		end,
	},
	elvui = {
		texture = "Interface\\Icons\\INV_Misc_Gear_08", -- repli : l'icône d'ElvUI (## IconTexture)
		iconFor = function()
			return ns.AddonIcon("ElvUI")
		end,
		title = L["Importer dans ElvUI"],
		tooltip = L["Profil : crée un nouveau profil ElvUI (nom libre) et l'active. Réglages du personnage, "
			.. "du compte ou filtres d'auras : les remplacent (ElvUI propose de recharger pour ceux du "
			.. "personnage). Hors combat."],
		hint = L["importer dans ElvUI"],
		confirm = function(profile)
			return ns.ElvUIConfirm(profile)
		end,
		run = function(profile)
			return ns.ImportElvUI(profile.text)
		end,
	},
	ellesmereui = {
		texture = "Interface\\Icons\\INV_Misc_Gear_07", -- repli : l'icône d'EllesmereUI (## IconTexture)
		iconFor = function()
			return ns.AddonIcon("EllesmereUI")
		end,
		title = L["Importer dans EllesmereUI"],
		tooltip = L["Ouvre la page d'import d'EllesmereUI sur cette chaîne : un profil y arrive sous un nouveau "
			.. "nom ; un export complet remplace les réglages du compte (EllesmereUI demande confirmation "
			.. "et recharge). Hors combat."],
		hint = L["importer dans EllesmereUI"],
		confirm = function(profile)
			return ns.EllesmereUIConfirm(profile)
		end,
		run = function(profile)
			return ns.ImportEllesmereUI(profile.text)
		end,
	},
	-- Mode Édition et talents (bêta) : fenêtre d'import de Blizzard pré-remplie, le joueur importe.
	editmode = {
		texture = "Interface\\Icons\\INV_Misc_Wrench_01",
		title = L["Importer dans le mode Édition (bêta)"],
		tooltip = L["Mode Édition ouvert : ouvre sa fenêtre d'import avec la chaîne et le nom déjà remplis ; "
			.. "cliquez vous-même sur « Importer ». Un /reload ensuite est conseillé. Hors combat."],
		hint = L["ouvrir l'import du mode Édition (bêta)"],
		run = function(profile)
			return ns.OpenEditModeImport(profile.text, profile.name)
		end,
	},
	talents = {
		texture = "Interface\\Icons\\INV_Misc_Book_09",
		title = L["Importer dans les talents (bêta)"],
		tooltip = L["Fenêtre des talents ouverte : ouvre sa fenêtre d'import avec la chaîne et le nom déjà "
			.. "remplis ; cliquez vous-même sur « Importer ». Un /reload ensuite est conseillé. Hors combat."],
		hint = L["ouvrir l'import des talents (bêta)"],
		run = function(profile)
			return ns.OpenTalentsImport(profile.text, profile.name)
		end,
	},
	details = {
		texture = "Interface\\Icons\\INV_Misc_Spyglass_02", -- repli : l'icône de Details! (## IconTexture)
		iconFor = function()
			return ns.AddonIcon("Details")
		end,
		title = L["Importer dans %s"]:format("Details!"),
		tooltip = L["Crée un nouveau profil %s (nom libre) et l'active. Hors combat."]:format("Details!"),
		hint = L["importer dans %s"]:format("Details!"),
		confirm = L["Un nouveau profil %s va être créé, puis activé."]:format("Details!"),
		run = function(profile)
			return ns.ImportDetails(profile.text, profile.name)
		end,
	},
	tlm = {
		texture = "Interface\\Icons\\INV_Misc_Book_11", -- repli : l'icône de TalentLoadoutManager (## IconTexture)
		iconFor = function()
			return ns.AddonIcon("TalentLoadoutManager")
		end,
		title = L["Importer dans %s"]:format("TalentLoadoutManager"),
		tooltip = L["Ajoute cette configuration de talents à TalentLoadoutManager, sans l'appliquer ; on la "
			.. "charge ensuite depuis TLM. La fenêtre des talents de Blizzard n'est pas touchée. Hors combat."],
		hint = L["importer dans %s"]:format("TalentLoadoutManager"),
		run = function(profile)
			return ns.ImportTLM(profile.text, profile.name)
		end,
	},
}

-- Baganator, Chattynator, Platynator : même action, par l'import public de chaque addon.
for kind, addon in pairs({ baganator = "Baganator", chattynator = "Chattynator", platynator = "Platynator" }) do
	ROW_ACTIONS[kind] = {
		texture = "Interface\\Icons\\INV_Misc_Gear_02", -- repli : l'icône de l'addon (## IconTexture)
		iconFor = function()
			return ns.AddonIcon(addon)
		end,
		title = L["Importer dans %s"]:format(addon),
		tooltip = L["Profil : crée un nouveau profil %s (nom libre) et l'active ; autre contenu (catégories, "
			.. "style) : l'importe. Hors combat."]:format(addon),
		hint = L["importer dans %s"]:format(addon),
		confirm = function(profile)
			return ns.PlusmouseConfirm(kind, profile)
		end,
		run = function(profile)
			return ns.ImportPlusmouse(kind, profile.text, profile.name)
		end,
	}
end

-- Rechargement proposé (Entrée ou clic sur « Recharger ») ; sur WoW Forever, où l'addon ne peut
-- pas recharger, un message demande de taper /reload.
StaticPopupDialogs["POLYPODE_PROFIL_RELOAD"] = {
	text = L["%s\n\nRecharger l'interface maintenant pour appliquer ?"],
	button1 = RELOADUI or L["Recharger"],
	button2 = L["Plus tard"],
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
		Notify(message .. " " .. L["Tapez /reload pour appliquer."])
	end
end

-- Lignes de détail de l'infobulle d'un profil, par genre.
local KIND_DETAILS = {
	elvui = function(text)
		return ns.ElvUIDetails(text)
	end,
	ellesmereui = function(text)
		return ns.EllesmereUIDetails(text)
	end,
	baganator = function(text)
		return ns.PlusmouseDetails("baganator", text)
	end,
	chattynator = function(text)
		return ns.PlusmouseDetails("chattynator", text)
	end,
	platynator = function(text)
		return ns.PlusmouseDetails("platynator", text)
	end,
	macro = function(text)
		return ns.MacroDetails(text)
	end,
	equipset = function(text)
		return ns.EquipmentSetDetails(text)
	end,
	actionbars = function(text)
		return ns.ActionBarsDetails(text)
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
	text = L["%s\n\nAppliquer le profil « %s » ?"],
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
	if data.isSeason then
		return {
			SeasonLabel(data.season),
			L["%d profil(s)"]:format(data.count),
			Gray(L["Profils rangés selon la saison de leur dernier enregistrement."]),
			data.collapsed and L["Clic gauche : déplier"] or L["Clic gauche : replier"],
		}
	end
	if data.header then
		-- Mêmes indications que « Personnages disponibles » (P.CharacterTooltip : nom, équipes).
		local hints = {
			data.online and "|cff40ff40" .. L["Connecté"] .. "|r" or "|cff999999" .. L["Déconnecté (ou pas vu cette session)"] .. "|r",
			L["%d profil(s)"]:format(data.count),
			data.collapsed and L["Clic gauche : déplier"] or L["Clic gauche : replier"],
			L["Clic droit : nouveau profil pour ce personnage"],
		}
		if P.CharacterTooltip and P.GetCharacter and P.GetCharacter(data.key) then
			return P.CharacterTooltip(data.key, hints)
		end
		table.insert(hints, 1, CharName(data.key))
		return hints
	end
	local profile = data.profile
	-- Intitulés en bleu clair, pour distinguer d'un coup d'œil l'intitulé de sa valeur.
	local function Label(text)
		return "|cff66ccff" .. text .. "|r "
	end
	local lines = {
		profile.name,
		Label(L["Genre :"]) .. ns.KindLabel(profile.kind),
		Label(L["Personnage :"]) .. CharName(profile.char),
		Label(L["Enregistré le"]) .. FormatDate(profile.updated),
		-- Saison et version du jeu au moment de la sauvegarde (inconnues avant la 1.9.0).
		Label(L["Enregistré sous :"]) .. (ns.GameContextText(profile) or Gray(L["inconnu (sauvegarde plus ancienne)"])),
		L["%d caractères"]:format(#(profile.text or "")),
	}
	local details = KIND_DETAILS[ns.NormalizeKind(profile.kind)]
	for _, line in ipairs(details and details(profile.text) or {}) do
		lines[#lines + 1] = line
	end
	lines[#lines + 1] = " "
	local action = ROW_ACTIONS[ns.NormalizeKind(profile.kind)]
	if action then
		lines[#lines + 1] = Gray(L["Icône : %s"]:format(action.hint))
	end
	lines[#lines + 1] = Gray(L["Clic gauche : ouvrir dans l'éditeur"])
	lines[#lines + 1] = Gray(L["Clic droit : dupliquer, supprimer"])
	return lines
end

local function HasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- Habille l'icône selon l'action (atlas avec états survol / appui, sinon texture de repli) ;
-- action.iconFor(profil) donne une icône propre au profil (macro : la sienne).
-- Addon du genre absent sur ce personnage (ns.KindAvailable) : icône grisée et estompée.
local function SetActionIcon(button, action, profile)
	local texture = action.iconFor and action.iconFor(profile) or action.texture
	button.available = ns.KindAvailable(profile.kind)
	if button.action ~= action or button.actionTexture ~= texture then
		button.action, button.actionTexture = action, texture
		if not action.iconFor and action.atlas and HasAtlas(action.atlas .. "-up") then
			button:SetNormalAtlas(action.atlas .. "-up")
			button:SetHighlightAtlas(action.atlas .. "-highlight")
			button:SetPushedAtlas(action.atlas .. "-down")
		else
			button:SetNormalTexture(texture)
			button:SetHighlightTexture(texture, "ADD")
			button:SetPushedTexture(texture)
		end
	end
	local normal = button:GetNormalTexture()
	if normal then
		normal:SetDesaturated(not button.available)
	end
	button:SetAlpha(button.available and 1 or 0.35)
end

local function ActionButton(row)
	if row.actionButton then
		return row.actionButton
	end
	local button = CreateFrame("Button", nil, row)
	button:SetSize(ACTION_SIZE, ACTION_SIZE)
	button:SetPoint("LEFT", PROFILE_INDENT, 0)
	button:SetFrameLevel(row:GetFrameLevel() + 2)
	-- Lignes recyclées : l'icône agit sur la donnée courante de la ligne.
	button:SetScript("OnClick", function(self)
		local data = self:GetParent().data
		if not (self.action and data and data.profile) then
			return
		elseif not self.available then
			Notify(L["%s n'est pas chargé sur ce personnage."]:format(ns.KindLabel(data.profile.kind)))
			return
		end
		local confirm = self.action.confirm
		if type(confirm) == "function" then
			confirm = confirm(data.profile)
		end
		if confirm then
			StaticPopup_Show("POLYPODE_PROFIL_APPLY", confirm, data.profile.name,
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
		local data = self:GetParent().data
		if not self.available and data and data.profile then
			GameTooltip:AddLine(L["%s n'est pas chargé sur ce personnage."]:format(ns.KindLabel(data.profile.kind)),
				1, 0.3, 0.3, true)
		end
		ShowTooltip()
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
		ShowTooltip()
	end)
	widget:HookScript("OnLeave", GameTooltip_Hide)
end

local function LayoutPanels()
	listPanel:SetWidth(math.max(LIST_MIN_WIDTH, frame:GetWidth() * LIST_RATIO))
end

local function BuildEditor()
	editor = P.CreatePanel(frame, "")
	editor:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 8, 0)
	editor:SetPoint("BOTTOMRIGHT", -12, 12)

	-- En-tête : genre et profil ouvert à gauche, son personnage à droite (texte seul).
	editor.charText = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	editor.charText:SetPoint("TOPRIGHT", -10, -8)
	editor.charText:SetJustifyH("RIGHT")
	editor.charText:SetWordWrap(false)
	editor.header:SetPoint("RIGHT", editor.charText, "LEFT", -10, 0)

	-- Ligne du nom : « Nom » [champ]
	local nameLabel = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameLabel:SetPoint("TOPLEFT", 10, -34)
	nameLabel:SetText(L["Nom"])

	nameBox = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
	nameBox:SetHeight(20)
	nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
	nameBox:SetPoint("RIGHT", -10, 0)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(80)
	nameBox:SetScript("OnTextChanged", UpdateEditorHeader)
	nameBox:SetScript("OnEnterPressed", nameBox.ClearFocus)
	nameBox:SetScript("OnEscapePressed", nameBox.ClearFocus)
	if P.SkinEditBox then
		P.SkinEditBox(nameBox)
	end
	editor.nameText = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	editor.nameText:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
	editor.nameText:SetPoint("RIGHT", -10, 0)
	editor.nameText:SetJustifyH("LEFT")
	editor.nameText:SetWordWrap(false)
	editor.nameText:Hide()

	-- Boutons du bas.
	local newButton = CreateButton(editor, L["Nouveau"], 80, function(self)
		ShowNewMenu(self)
	end)
	newButton:SetPoint("BOTTOMLEFT", 10, 10)
	SetTooltip(newButton, L["Nouveau profil"],
		L["Menu des genres, en trois groupes : capturés en jeu et appliqués par l'icône de la liste, capturés "
			.. "en jeu puis copiés, ou collés (import / export d'un addon). Choisir une capture ou « Coller une "
			.. "chaîne » ouvre un nouveau profil de ce genre, pour votre personnage actuel."])

	saveButton = CreateButton(editor, L["Enregistrer"], 90, SaveEditor)
	saveButton:SetPoint("LEFT", newButton, "RIGHT", 6, 0)
	SetTooltip(saveButton, L["Enregistrer"],
		L["Garde le nouveau profil (nom, genre, chaîne) sous le personnage affiché en haut à droite et l'envoie "
			.. "à vos autres clients connectés. Un profil déjà enregistré ne se modifie pas : le dupliquer."])

	local selectButton = CreateButton(editor, L["Tout sélectionner"], 120, SelectAll)
	selectButton:SetPoint("BOTTOMRIGHT", -10, 10)
	SetTooltip(selectButton, L["Tout sélectionner"],
		L["Sélectionne la chaîne : Ctrl+C pour la copier, puis Ctrl+V dans la fenêtre d'import du mode Édition, "
			.. "des talents ou de l'addon."])

	-- Zone de texte défilante (Ctrl+V pour coller une chaîne).
	local textPanel = P.CreatePanel(editor, "")
	textPanel:SetPoint("TOPLEFT", 8, -62)
	textPanel:SetPoint("BOTTOMRIGHT", -8, 40)

	textBox = CreateFrame("Frame", nil, textPanel, "ScrollingEditBoxTemplate")
	textBox:SetPoint("TOPLEFT", 8, -8)
	textBox:SetPoint("BOTTOMRIGHT", -8, 8)
	local editBox = textBox:GetEditBox()
	editBox:SetMaxLetters(0)
	if editBox.SetMaxBytes then
		editBox:SetMaxBytes(0)
	end
	-- Profil enregistré (lecture seule) : une frappe est annulée ; sélection et Ctrl+C restent possibles.
	editBox:HookScript("OnTextChanged", function(self, userInput)
		local profile = userInput and selectedID and ns.Get(selectedID)
		if profile and self:GetText() ~= profile.text then
			self:SetText(profile.text)
		end
	end)
	textBox:SetDefaultText(L["Collez ici (Ctrl+V) la chaîne d'export du mode Édition, des talents ou d'un addon."])
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

-- AIDE ---------------------------------------------------------------------------------------
-- Bouton « ? » de la barre de titre : fenêtre PolypodeProfilHelpFrame, liste défilante de tous
-- les genres du menu « Nouveau » (même ceux dont l'addon n'est pas chargé), groupe par groupe,
-- dans la couleur de leur famille, avec la légende des couleurs, la façon de capturer, l'action de
-- l'icône (ROW_ACTIONS) et cette icône.

local helpFrame, helpList
local HELP_ICON_SIZE = 16

-- Légende : une ligne par famille, dans sa couleur.
local HELP_FAMILIES = {
	{ key = "essential", text = L["Bleu : réglages essentiels de WoW"] },
	{ key = "client", text = L["Vert : autres réglages du client"] },
	{ key = "addon", text = L["Violet : addons"] },
	{ key = "other", text = L["Blanc : autre"] },
}

local function HelpCapture(kind)
	if kind.group == "paste" then
		return L["chaîne à coller"]
	elseif BETA_CAPTURE[kind.key] then
		return L["capture en jeu (bêta) ou chaîne collée"]
	end
	return L["capture en jeu ou chaîne collée"]
end

local function HelpImport(kind)
	local action = ROW_ACTIONS[kind.key]
	return action and action.hint or L["copie manuelle (Tout sélectionner, Ctrl+C)"]
end

local function HelpItems()
	local items = { { title = L["Codes couleur"] } }
	for _, family in ipairs(HELP_FAMILIES) do
		items[#items + 1] = { text = ns.KIND_FAMILIES[family.key].color .. family.text .. "|r" }
	end
	for _, group in ipairs(ns.KIND_GROUPS) do
		items[#items + 1] = { title = group.label }
		for _, kind in ipairs(ns.KINDS) do
			if kind.group == group.key then
				items[#items + 1] = { kind = kind, available = ns.KindAvailable(kind.key) }
			end
		end
	end
	return items
end

-- Icône de l'action d'un genre, comme dans la liste (atlas, icône de l'addon, sinon texture).
local function SetHelpIcon(texture, kind, available)
	local action = ROW_ACTIONS[kind.key]
	if not action then
		texture:Hide()
		return
	end
	local ok, icon = pcall(function()
		return action.iconFor and action.iconFor({ kind = kind.key, text = "" })
	end)
	if not (ok and icon) and action.atlas and HasAtlas(action.atlas .. "-up") then
		texture:SetAtlas(action.atlas .. "-up")
	else
		texture:SetTexture(ok and icon or action.texture)
	end
	texture:SetDesaturated(not available)
	texture:SetAlpha(available and 1 or 0.35)
	texture:Show()
end

local function BuildHelp()
	helpFrame = CreateFrame("Frame", "PolypodeProfilHelpFrame", UIParent, "BackdropTemplate")
	helpFrame:SetSize(640, 480)
	helpFrame:SetPoint("CENTER", 40, -20)
	helpFrame:SetFrameStrata("DIALOG")
	helpFrame:SetMovable(true)
	helpFrame:EnableMouse(true)
	helpFrame:RegisterForDrag("LeftButton")
	helpFrame:SetScript("OnDragStart", helpFrame.StartMoving)
	helpFrame:SetScript("OnDragStop", helpFrame.StopMovingOrSizing)
	helpFrame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	helpFrame:SetBackdropColor(0, 0, 0, 0.95)
	helpFrame:Hide()
	tinsert(UISpecialFrames, "PolypodeProfilHelpFrame") -- Échap ferme la fenêtre

	local title = helpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 12, -8)
	title:SetText(L["Genres de profils"])
	helpFrame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, helpFrame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	helpFrame.CloseButton = closeBtn

	helpList = P.CreatePanel(helpFrame, L["Genres du menu « Nouveau », capture et icône de la liste"])
	helpList:SetPoint("TOPLEFT", 12, -36)
	helpList:SetPoint("BOTTOMRIGHT", -12, 12)
	P.CreateScrollList(helpList, function(data)
		if data.title then
			return "|cffffd200" .. data.title .. "|r"
		elseif data.text then
			return data.text
		end
		local kind = data.kind
		local text = ns.ColorByKind(kind.key, kind.label) .. Gray("  ·  " .. HelpCapture(kind) .. "  ·  " .. HelpImport(kind))
		if not data.available then
			text = text .. "  |cffff5555" .. L["non chargé sur ce personnage"] .. "|r"
		end
		return text
	end, nil, {
		tooltip = function(data)
			if not data.kind then
				return nil
			end
			local kind = data.kind
			local lines = {
				ns.ColorByKind(kind.key, kind.label),
				L["Capture : %s"]:format(HelpCapture(kind)),
				L["Icône de la liste : %s"]:format(HelpImport(kind)),
			}
			if not data.available then
				lines[#lines + 1] = "|cffff5555" .. L["%s n'est pas chargé sur ce personnage."]:format(kind.label) .. "|r"
			end
			return lines
		end,
		-- Lignes recyclées : icône et retrait recalculés à chaque affichage.
		decorate = function(row, data)
			if not row.helpIcon then
				row.helpIcon = row:CreateTexture(nil, "ARTWORK")
				row.helpIcon:SetSize(HELP_ICON_SIZE, HELP_ICON_SIZE)
				row.helpIcon:SetPoint("LEFT", CHAR_INDENT, 0)
			end
			if data.kind then
				SetHelpIcon(row.helpIcon, data.kind, data.available)
				row.text:SetPoint("LEFT", CHAR_INDENT + HELP_ICON_SIZE + 6, 0)
			else
				row.helpIcon:Hide()
				row.text:SetPoint("LEFT", data.title and SEASON_INDENT or CHAR_INDENT, 0)
			end
		end,
	})

	P.SkinFrame(helpFrame)
	P.SkinPanel(helpList)
end

-- Ouvre / ferme l'aide ; la liste est recalculée à chaque ouverture (addons chargés).
local function ToggleHelp()
	if not helpFrame then
		BuildHelp()
	end
	if helpFrame:IsShown() then
		helpFrame:Hide()
		return
	end
	P.SetListData(helpList, HelpItems())
	helpFrame:Show()
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
	title:SetText(L["Profils"])
	frame.TitleText = title

	-- « ? » à droite du titre : aide sur les genres (ToggleHelp).
	local helpButton = CreateButton(frame, "?", 22, ToggleHelp)
	helpButton:SetHeight(20)
	helpButton:SetPoint("LEFT", title, "RIGHT", 8, 0)
	SetTooltip(helpButton, L["Aide"], L["Liste de tous les genres de profils (même ceux dont l'addon n'est pas "
		.. "chargé), avec les codes couleur, la façon de les capturer et l'action de leur icône."])

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	frame.CloseButton = closeBtn

	listPanel = P.CreatePanel(frame, L["Personnages"])
	listPanel:SetPoint("TOPLEFT", 12, -36)
	listPanel:SetPoint("BOTTOMLEFT", 12, 12 + BUTTON_ROW)

	-- Sous la liste : actions sur le profil ouvert (Dupliquer, Supprimer) et sur une saison.
	duplicateButton = CreateButton(frame, L["Dupliquer"], 80, function()
		if selectedID then
			Duplicate(selectedID)
		end
	end)
	duplicateButton:SetPoint("BOTTOMLEFT", 12, 12)
	SetTooltip(duplicateButton, L["Dupliquer"],
		L["Ouvre une copie du profil pour votre personnage actuel ; « Enregistrer » la garde sous lui."])

	deleteButton = CreateButton(frame, L["Supprimer"], 80, function()
		if selectedID then
			AskDelete(selectedID)
		end
	end)
	deleteButton:SetPoint("LEFT", duplicateButton, "RIGHT", 6, 0)

	local seasonButton = CreateButton(frame, L["Supprimer une saison"], 140, function(self)
		ShowSeasonDeleteMenu(self)
	end)
	seasonButton:SetPoint("LEFT", deleteButton, "RIGHT", 6, 0)
	SetTooltip(seasonButton, L["Supprimer une saison"],
		L["Liste les saisons de vos profils enregistrés ; en choisir une supprime (après confirmation) tous "
			.. "les profils enregistrés pendant cette saison, sur tous vos clients."])

	-- « Tout replier » / « Tout déplier », à droite du titre du cadre : replie les saisons (leurs
	-- personnages gardent leur état), ou déplie tout.
	collapseAllButton = CreateButton(listPanel, L["Tout replier"], 90, function()
		local collapsed = Collapsed()
		if AllCollapsed() then
			wipe(collapsed)
		else
			for _, item in ipairs(BuildItems()) do
				if item.isSeason then
					collapsed[item.fold] = true
				end
			end
		end
		ns.Refresh()
	end)
	collapseAllButton:SetHeight(18)
	collapseAllButton:SetPoint("TOPRIGHT", -6, -4)
	listPanel.header:SetPoint("RIGHT", collapseAllButton, "LEFT", -6, 0)
	SetTooltip(collapseAllButton, L["Tout replier / déplier"],
		L["Replie toutes les saisons pour ne voir que leurs noms, ou déplie tout."])
	P.CreateScrollList(listPanel, function(data)
		local fold = data.header and ("|cffffd200" .. (data.collapsed and "+" or "-") .. "|r ")
		if data.isSeason then
			return fold .. "|cffffffff" .. SeasonLabel(data.season) .. "|r" .. Gray(" (" .. data.count .. ")")
		elseif data.header then
			-- Personnage comme dans « Personnages disponibles », précédé du repli, suivi du nombre.
			return fold .. FormatChar(data.key) .. Gray(" (" .. data.count .. ")")
		end
		-- « Genre · nom » dans la couleur de la famille du genre ; décalé par decorate.
		return ns.ColorByKind(data.profile.kind, ns.KindLabel(data.profile.kind) .. " · " .. data.profile.name)
	end, nil, {
		onClick = function(data, button)
			if data.header then
				if button == "RightButton" then
					if not data.isSeason then
						ShowCharRowMenu(data.key)
					end
				else
					Collapsed()[data.fold] = not data.collapsed or nil
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
		-- Personnages en retrait sous leur saison, profils sous leur personnage (après la place de
		-- l'icône d'action) ; lignes recyclées : retrait et icône recalculés à chaque affichage.
		decorate = function(row, data)
			row:SetAlpha((data.header and not data.isSeason and not data.online) and 0.55 or 1)
			row.text:SetPoint("LEFT", data.isSeason and SEASON_INDENT or data.header and CHAR_INDENT
				or (PROFILE_INDENT + ACTION_SIZE + 4), 0)
			local action = not data.header and ROW_ACTIONS[ns.NormalizeKind(data.profile.kind)]
			if action then
				local button = ActionButton(row)
				SetActionIcon(button, action, data.profile)
				button:Show()
			elseif row.actionButton then
				row.actionButton:Hide()
			end
		end,
	})
	listPanel.emptyText:SetText(L["Aucun profil enregistré."])

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
	-- Double-clic sur la barre de titre : taille par défaut (Polypode 2.12).
	if P.EnableTitleDoubleClick then
		P.EnableTitleDoubleClick(frame, function()
			local current = WindowSettings()
			current.width, current.height = DEFAULT_WIDTH, DEFAULT_HEIGHT
			frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
		end)
	end
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
	collapseAllButton:SetText(AllCollapsed() and L["Tout déplier"] or L["Tout replier"])
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
		text = L["Profils"],
		width = 60,
		onClick = function()
			P.ToggleProfil()
		end,
		tooltip = {
			L["Profils"],
			L["Chaînes d'export du mode Édition, des talents et des addons (EllesmereUI, ElvUI, Baganator, "
				.. "MySlots, Simple Addon Manager...), gardées pour tous vos personnages."],
		},
		onCreate = function(button)
			P.ui.profilButton = button
		end,
	})
end

if P.RegisterSlashCommand then
	P.RegisterSlashCommand("profil", P.ToggleProfil, L["profils (chaînes d'export du mode Édition, des talents, des addons)"])
end
