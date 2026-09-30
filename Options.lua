-- Polypode Profil: Options — options de WoW (CVars du panneau Options) et raccourcis clavier

local _, ns = ...

-- Deux genres, en texte propre à Polypode Profil (pas de chaîne d'export chez Blizzard) :
--
-- OPTIONS (genre « options ») : les réglages du panneau Options de WoW qui sont des CVars, par
-- catégorie (Graphismes, Audio, Interface...). La liste vient du registre du panneau
-- (SettingsPanel.settings : réglage → catégorie ; lecture seule, rien n'y est modifié) ; les
-- réglages « proxy » (calculés, stockés ailleurs) et ceux des addons sont écartés.
--   Polypode options v1
--   # <catégorie>
--   <cvar>=<valeur>
-- Application : C_CVar.SetCVar hors combat (les préréglages graphiques d'abord, pour ne pas
-- écraser les réglages fins) ; CVars inconnues, verrouillées ou en lecture seule ignorées.
--
-- RACCOURCIS (genre « bindings ») : tous les raccourcis clavier du jeu de raccourcis actif.
--   Polypode raccourcis v1
--   <commande>=<touche>,<touche>
-- Application (hors combat) : le jeu de raccourcis actif devient celui du profil (les touches
-- liées autrement sont libérées), puis SaveBindings. Commandes inconnues (addon absent) comptées.
--
-- Valeurs, commandes et touches encodées (Enc : %XX pour « % = , : » et les retours à la ligne).

local OPTIONS_HEADER = "Polypode options v1"
-- Jeux de raccourcis de WoW : 1 = compte, 2 = personnage.
local ACCOUNT_SET = Enum and Enum.BindingSet and Enum.BindingSet.Account or 1
local CHARACTER_SET = Enum and Enum.BindingSet and Enum.BindingSet.Character or 2
local BINDINGS_HEADER = "Polypode raccourcis v1"

local function Enc(text)
	return (tostring(text or ""):gsub("[%%=,:\r\n]", function(char)
		return string.format("%%%02X", char:byte())
	end))
end

local function Dec(text)
	return (tostring(text or ""):gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

ns.Enc, ns.Dec = Enc, Dec

-- Lignes utiles d'un texte à en-tête : itère sur « clé=valeur » (commentaires « # » ignorés).
local function Lines(text, header)
	text = tostring(text or "")
	if not text:find("^%s*" .. header) then
		return nil
	end
	local list = {}
	for line in text:gmatch("[^\r\n]+") do
		local key, value = line:match("^%s*([^#=][^=]*)=(.*)$")
		if key and strtrim(key) ~= header then
			list[#list + 1] = { strtrim(key), value }
		end
	end
	return list
end

local function CVarInfo(name)
	if not (C_CVar and C_CVar.GetCVarInfo) then
		return nil
	end
	local ok, value, _, _, _, locked, _, readOnly = pcall(C_CVar.GetCVarInfo, name)
	if ok and value ~= nil then
		return { value = value, locked = locked, readOnly = readOnly }
	end
end

-- OPTIONS ------------------------------------------------------------------------------------

-- Catégories du panneau Options : { [nom de la catégorie principale] = { [cvar] = true } }.
local function OptionCategories()
	local categories = {}
	local panel = SettingsPanel
	if not (panel and type(panel.settings) == "table") then
		return categories
	end
	local addOnSet = Settings and Settings.CategorySet and Settings.CategorySet.AddOns
	for setting, category in pairs(panel.settings) do
		local okVariable, variable = pcall(setting.GetVariable, setting)
		if okVariable and type(variable) == "string" and CVarInfo(variable) then
			local okSet, set = pcall(category.GetCategorySet, category)
			if not (okSet and addOnSet and set == addOnSet) then
				local top = category
				for _ = 1, 10 do -- remonte à la catégorie principale
					local okParent, parent = pcall(top.GetParentCategory, top)
					if not (okParent and parent) then
						break
					end
					top = parent
				end
				local okName, name = pcall(top.GetName, top)
				name = okName and type(name) == "string" and name or "?"
				categories[name] = categories[name] or {}
				categories[name][variable] = true
			end
		end
	end
	return categories
end

-- Catégories pour le menu de capture : { { name, count }, ... } triées par nom.
function ns.GetOptionCategories()
	local list = {}
	for name, cvars in pairs(OptionCategories()) do
		local count = 0
		for _ in pairs(cvars) do
			count = count + 1
		end
		list[#list + 1] = { name = name, count = count }
	end
	table.sort(list, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	return list
end

-- Texte des CVars d'une catégorie (nil = toutes) et nom proposé.
function ns.ExportOptions(categoryName)
	local categories = OptionCategories()
	local names = {}
	for name in pairs(categories) do
		if not categoryName or name == categoryName then
			names[#names + 1] = name
		end
	end
	if #names == 0 then
		return nil, "Aucun réglage trouvé (panneau Options pas encore chargé ?)."
	end
	table.sort(names)
	local lines, count = { OPTIONS_HEADER }, 0
	for _, name in ipairs(names) do
		local cvars = {}
		for cvar in pairs(categories[name]) do
			cvars[#cvars + 1] = cvar
		end
		table.sort(cvars)
		lines[#lines + 1] = "# " .. name
		for _, cvar in ipairs(cvars) do
			local info = CVarInfo(cvar)
			if info and not info.readOnly and not info.locked then
				lines[#lines + 1] = cvar .. "=" .. Enc(info.value)
				count = count + 1
			end
		end
	end
	return table.concat(lines, "\n"), "Options — " .. (categoryName or "toutes") .. " (" .. date("%d/%m/%Y") .. ")", count
end

-- Préréglages graphiques appliqués avant les réglages fins qu'ils modifient.
local function OptionRank(cvar)
	return cvar:lower():find("graphicsquality$") and 1 or 2
end

-- Applique un profil d'options ; renvoie true et le compte rendu, ou nil et la raison.
function ns.ApplyOptions(text)
	local list = Lines(text, OPTIONS_HEADER)
	if not list then
		return nil, "Ce profil n'est pas un profil d'options."
	elseif InCombatLockdown() then
		return nil, "Impossible en combat."
	end
	table.sort(list, function(a, b)
		local ra, rb = OptionRank(a[1]), OptionRank(b[1])
		if ra ~= rb then
			return ra < rb
		end
		return a[1] < b[1]
	end)
	local applied, same, refused = 0, 0, 0
	for _, entry in ipairs(list) do
		local cvar, value = entry[1], Dec(entry[2])
		local info = CVarInfo(cvar)
		if not info or info.readOnly or info.locked then
			refused = refused + 1
		elseif info.value == value then
			same = same + 1
		elseif C_CVar.SetCVar(cvar, value) then
			applied = applied + 1
		else
			refused = refused + 1
		end
	end
	return true, string.format("Options : %d appliquée(s), %d déjà à jour, %d ignorée(s).%s", applied, same, refused,
		applied > 0 and " Certains réglages graphiques demandent de relancer le jeu." or "")
end

function ns.OptionsDetails(text)
	local list = Lines(text, OPTIONS_HEADER)
	if not list then
		return nil
	end
	local categories = {}
	for name in tostring(text):gmatch("\n# ([^\r\n]+)") do
		categories[#categories + 1] = name
	end
	return { #list .. " réglage(s)", "Catégories : " .. (#categories > 0 and table.concat(categories, ", ") or "?") }
end

-- RACCOURCIS ---------------------------------------------------------------------------------

-- Raccourcis actuels : { { command, keys = { ... } }, ... } (commandes liées seulement).
local function CurrentBindings()
	local list = {}
	if not (GetNumBindings and GetBinding) then
		return list
	end
	for index = 1, GetNumBindings() do
		local binding = { GetBinding(index) }
		local command = binding[1]
		if command and #binding > 2 then
			local keys = {}
			for i = 3, #binding do
				if binding[i] and binding[i] ~= "" then
					keys[#keys + 1] = binding[i]
				end
			end
			if #keys > 0 then
				list[#list + 1] = { command = command, keys = keys }
			end
		end
	end
	return list
end

local function BindingSetLabel()
	local set = GetCurrentBindingSet and GetCurrentBindingSet()
	return set == CHARACTER_SET and "personnage" or "compte"
end

-- Texte de tous les raccourcis et nom proposé.
function ns.ExportBindings()
	local bindings = CurrentBindings()
	if #bindings == 0 then
		return nil, "Aucun raccourci lisible."
	end
	local lines = { BINDINGS_HEADER, "# jeu de raccourcis : " .. BindingSetLabel() }
	for _, binding in ipairs(bindings) do
		local keys = {}
		for i, key in ipairs(binding.keys) do
			keys[i] = Enc(key)
		end
		lines[#lines + 1] = Enc(binding.command) .. "=" .. table.concat(keys, ",")
	end
	return table.concat(lines, "\n"), "Raccourcis (" .. date("%d/%m/%Y") .. ")"
end

-- Applique un profil de raccourcis au jeu de raccourcis actif ; true et le compte rendu, ou nil
-- et la raison.
function ns.ApplyBindings(text)
	local list = Lines(text, BINDINGS_HEADER)
	if not list then
		return nil, "Ce profil n'est pas un profil de raccourcis."
	elseif InCombatLockdown() then
		return nil, "Impossible en combat."
	elseif not (SetBinding and SaveBindings and GetBindingAction) then
		return nil, "Raccourcis indisponibles sur ce client."
	end
	local wanted = {} -- [touche] = commande
	for _, entry in ipairs(list) do
		local command = Dec(entry[1])
		for key in entry[2]:gmatch("[^,]+") do
			wanted[Dec(key)] = command
		end
	end
	-- Touches liées à autre chose que dans le profil : libérées.
	local cleared = 0
	for _, binding in ipairs(CurrentBindings()) do
		for _, key in ipairs(binding.keys) do
			if wanted[key] ~= binding.command then
				SetBinding(key)
				cleared = cleared + 1
			end
		end
	end
	local set, same, failed = 0, 0, 0
	for key, command in pairs(wanted) do
		if GetBindingAction(key) == command then
			same = same + 1
		elseif SetBinding(key, command) then
			set = set + 1
		else
			failed = failed + 1
		end
	end
	SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or ACCOUNT_SET)
	return true, string.format("Raccourcis (%s) : %d lié(s), %d déjà en place, %d libéré(s), %d inconnu(s).",
		BindingSetLabel(), set, same, cleared, failed)
end

function ns.BindingsDetails(text)
	local list = Lines(text, BINDINGS_HEADER)
	if not list then
		return nil
	end
	local setName = tostring(text):match("# jeu de raccourcis : (%a+)")
	return { #list .. " commande(s) liée(s)", "Jeu de raccourcis d'origine : " .. (setName or "?") }
end
