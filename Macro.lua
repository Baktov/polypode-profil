-- Polypode Profil: Macro — macros : capture (nom, icône, texte) et ajout chez le personnage joué

local _, ns = ...

-- Une macro de WoW, en texte :
--   Polypode macro v1
--   nom=<nom de la macro>
--   icone=<fileID ou chemin de l'icône>
--   type=generale|personnage      (macros générales du compte, ou propres au personnage)
--   ---
--   <texte de la macro, tel quel, sur autant de lignes que nécessaire>
-- Dans le texte, « | » et « % » s'écrivent %7C et %25 : la zone de texte de l'éditeur
-- interpréterait un « | » (codes de couleur, liens).
--
-- Ajout (ns.AddMacro) : crée la macro chez le personnage joué (même type), ou remplace l'icône et
-- le texte de celle qui porte déjà ce nom. Hors combat (WoW refuse de toucher aux macros en combat).

local HEADER = "Polypode macro v1"
local SEPARATOR = "---"

-- Nombre maximal de macros générales / par personnage (repli : valeurs de Retail).
local function MaxMacros()
	local consts = Constants and Constants.MacroConsts
	return consts and consts.MAX_ACCOUNT_MACROS or 120, consts and consts.MAX_CHARACTER_MACROS or 30
end

local function EscapeBody(body)
	return (body:gsub("%%", "%%25"):gsub("|", "%%7C"))
end

local function UnescapeBody(body)
	return (body:gsub("%%7[Cc]", "|"):gsub("%%25", "%%"))
end

local function Parse(text)
	local lines = {}
	for line in ((text or "") .. "\n"):gmatch("(.-)\r?\n") do
		lines[#lines + 1] = line
	end
	if strtrim(lines[1] or "") ~= HEADER then
		return nil
	end
	local macro = { body = {} }
	local inBody = false
	for i = 2, #lines do
		local line = lines[i]
		if inBody then
			macro.body[#macro.body + 1] = line
		elseif strtrim(line) == SEPARATOR then
			inBody = true
		else
			local key, value = line:match("^(%a+)=(.*)$")
			if key == "nom" then
				macro.name = strtrim(value)
			elseif key == "icone" then
				value = strtrim(value)
				macro.icon = tonumber(value) or (value ~= "" and value or nil)
			elseif key == "type" then
				macro.perCharacter = strtrim(value) == "personnage"
			end
		end
	end
	-- Lignes vides de fin retirées (ajoutées par la saisie ou le copier-coller).
	while #macro.body > 0 and strtrim(macro.body[#macro.body]) == "" do
		macro.body[#macro.body] = nil
	end
	macro.body = UnescapeBody(table.concat(macro.body, "\n"))
	if not macro.name or macro.name == "" then
		return nil
	end
	return macro
end

-- Icône d'un profil de macro (icône d'action de sa ligne), ou nil.
function ns.MacroIcon(text)
	local macro = Parse(text)
	return macro and macro.icon
end

-- Macros du personnage joué (menu de capture) : { index, name, icon, perCharacter }, générales
-- puis propres au personnage.
function ns.GetMacros()
	local list = {}
	if not (GetNumMacros and GetMacroInfo) then
		return list
	end
	local maxAccount = MaxMacros()
	local numAccount, numCharacter = GetNumMacros()
	for i = 1, numAccount or 0 do
		local name, icon = GetMacroInfo(i)
		if name then
			list[#list + 1] = { index = i, name = name, icon = icon, perCharacter = false }
		end
	end
	for i = maxAccount + 1, maxAccount + (numCharacter or 0) do
		local name, icon = GetMacroInfo(i)
		if name then
			list[#list + 1] = { index = i, name = name, icon = icon, perCharacter = true }
		end
	end
	return list
end

-- Texte d'une macro (index de GetMacroInfo) et son nom, ou nil et la raison.
function ns.ExportMacro(index)
	local name, icon, body = GetMacroInfo(index)
	if not name then
		return nil, "Macro introuvable."
	end
	local maxAccount = MaxMacros()
	return table.concat({
		HEADER,
		"nom=" .. name,
		"icone=" .. tostring(icon or ""),
		"type=" .. (index > maxAccount and "personnage" or "generale"),
		SEPARATOR,
		EscapeBody(body or ""),
	}, "\n"), name
end

-- Lignes de détail de l'infobulle d'un profil de macro.
function ns.MacroDetails(text)
	local macro = Parse(text)
	if not macro then
		return nil
	end
	local lines = {
		(macro.icon and ("|T" .. macro.icon .. ":16|t ") or "") .. "Macro « " .. macro.name .. " » ("
			.. (macro.perCharacter and "propre au personnage" or "générale") .. ")",
	}
	for line in (macro.body .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = "|cffcccccc" .. line:gsub("|", "||") .. "|r"
	end
	return lines
end

-- Index de la macro nommée name parmi celles du type voulu, ou nil.
local function FindMacro(name, perCharacter)
	local maxAccount = MaxMacros()
	local numAccount, numCharacter = GetNumMacros()
	local first, last = 1, numAccount or 0
	if perCharacter then
		first, last = maxAccount + 1, maxAccount + (numCharacter or 0)
	end
	for i = first, last do
		if GetMacroInfo(i) == name then
			return i
		end
	end
end

-- Vrai si la macro du profil existe déjà chez le personnage joué (son ajout la remplacerait).
function ns.MacroExists(text)
	local macro = Parse(text)
	return macro ~= nil and GetNumMacros ~= nil and FindMacro(macro.name, macro.perCharacter) ~= nil
end

-- Crée la macro du profil chez le personnage joué, ou met à jour celle du même nom ; renvoie
-- ok et le compte rendu, ou nil et la raison.
function ns.AddMacro(text)
	local macro = Parse(text)
	if not macro then
		return nil, "Texte de macro illisible (première ligne attendue : « " .. HEADER .. " »)."
	elseif not (CreateMacro and EditMacro and GetNumMacros) then
		return nil, "Macros indisponibles."
	elseif InCombatLockdown() then
		return nil, "Impossible en combat."
	end
	local icon = macro.icon or 134400 -- point d'interrogation (INV_Misc_QuestionMark)
	local kind = macro.perCharacter and "propres au personnage" or "générales"
	local index = FindMacro(macro.name, macro.perCharacter)
	if index then
		local ok = pcall(EditMacro, index, macro.name, icon, macro.body)
		if not ok then
			return nil, "Échec de la mise à jour de la macro « " .. macro.name .. " »."
		end
		return true, "Macro « " .. macro.name .. " » mise à jour (" .. kind .. ")."
	end
	local maxAccount, maxCharacter = MaxMacros()
	local numAccount, numCharacter = GetNumMacros()
	if macro.perCharacter and (numCharacter or 0) >= maxCharacter
		or not macro.perCharacter and (numAccount or 0) >= maxAccount then
		return nil, "Plus de place pour une macro " .. (macro.perCharacter and "propre au personnage." or "générale.")
	end
	local ok, created = pcall(CreateMacro, macro.name, icon, macro.body, macro.perCharacter)
	if not ok or not created then
		return nil, "Échec de la création de la macro « " .. macro.name .. " »."
	end
	return true, "Macro « " .. macro.name .. " » ajoutée aux macros " .. kind .. "."
end
