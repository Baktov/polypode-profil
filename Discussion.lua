-- Polypode Profil: Discussion — paramétrage des fenêtres de discussion (capture et application)

local _, ns = ...

-- Genre « chat », texte propre à Polypode Profil (champs séparés par « : », textes encodés par
-- ns.Enc, Options.lua) :
--   Polypode discussion v1
--   fenetre=<id>:<affichée 0/1>:<ancrée 0/1>:<verrouillée 0/1>:<taille police>:<r>:<g>:<b>:<alpha>:<nom>
--   groupes=<id>:<groupe>,<groupe>...        (types de messages : SAY, GUILD, WHISPER...)
--   canaux=<id>:<canal>,<canal>...           (canaux affichés : Général, Commerce...)
--   position=<id>:<point>:<x>:<y>:<largeur>:<hauteur>   (fenêtre détachée seulement)
--   couleur=<type>:<r>:<g>:<b>:<nom en couleur de classe 0/1>   (ChatTypeInfo)
--   cvar=<nom>:<valeur>                      (réglages de la discussion : style, chuchotements...)
-- Fenêtres lues : la 1 et celles affichées ou ancrées (GetChatWindowInfo). La 2 (journal de
-- combat) garde ses propres filtres : seuls nom, police, couleur et verrouillage s'appliquent.
--
-- Application (hors combat) : les fenêtres actives absentes du profil sont fermées, les
-- manquantes ouvertes (FCF_OpenNewWindow, dans l'ordre des numéros), puis chaque fenêtre reçoit
-- nom, police, couleur, transparence, verrouillage, types de messages, canaux, ancrage et
-- position ; puis couleurs des types de messages et réglages. Les fonctions de Blizzard
-- (FloatingChatFrame) enregistrent tout côté jeu ; un /reload est conseillé ensuite (fenêtres
-- touchées par un addon). La fenêtre 1 reste placée par le mode Édition.

local HEADER = "Polypode discussion v1"
local Enc, Dec = ns.Enc, ns.Dec

-- Réglages de la discussion (catégorie Social et fenêtre de discussion), pris s'ils existent.
local CHAT_CVARS = {
	"chatStyle", "whisperMode", "showTimestamps", "profanityFilter", "chatMouseScroll",
	"colorChatNamesByClass", "chatClassColorOverride", "removeChatDelay", "wholeChatWindowClickable",
	"guildMemberNotify", "showToastOnline", "showToastOffline", "showToastBroadcast",
	"showToastFriendRequest", "showToastWindow", "chatBubbles", "chatBubblesParty",
}

local function Bit(value)
	return value and 1 or 0
end

local function Number(value)
	return (string.format("%.3f", tonumber(value) or 0):gsub("%.?0+$", "")) -- un seul résultat
end

local function NumWindows()
	return NUM_CHAT_WINDOWS or 10
end

local function WindowActive(id)
	local _, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(id)
	return id == 1 or shown or docked
end

-- CAPTURE ------------------------------------------------------------------------------------

function ns.ExportChat()
	if not (GetChatWindowInfo and GetChatWindowMessages and GetChatWindowChannels) then
		return nil, "Fenêtres de discussion illisibles sur ce client."
	end
	local lines = { HEADER }
	for id = 1, NumWindows() do
		local name, size, r, g, b, alpha, shown, locked, docked = GetChatWindowInfo(id)
		if WindowActive(id) then
			lines[#lines + 1] = table.concat({ "fenetre=" .. id, Bit(shown), Bit(docked), Bit(locked),
				Number(size), Number(r), Number(g), Number(b), Number(alpha), Enc(name) }, ":")
			local groups = { GetChatWindowMessages(id) }
			lines[#lines + 1] = "groupes=" .. id .. ":" .. table.concat(groups, ",")
			local channels, raw = {}, { GetChatWindowChannels(id) }
			for i = 1, #raw, 2 do
				channels[#channels + 1] = Enc(raw[i])
			end
			lines[#lines + 1] = "canaux=" .. id .. ":" .. table.concat(channels, ",")
			if not docked and id ~= 1 and GetChatWindowSavedPosition then
				local point, x, y = GetChatWindowSavedPosition(id)
				local width, height = GetChatWindowSavedDimensions(id)
				if point and width then
					lines[#lines + 1] = table.concat({ "position=" .. id, point, Number(x), Number(y),
						Number(width), Number(height) }, ":")
				end
			end
		end
	end
	local types = {}
	for chatType, info in pairs(ChatTypeInfo or {}) do
		if type(chatType) == "string" and type(info) == "table" and info.r then
			types[#types + 1] = chatType
		end
	end
	table.sort(types)
	for _, chatType in ipairs(types) do
		local info = ChatTypeInfo[chatType]
		lines[#lines + 1] = table.concat({ "couleur=" .. Enc(chatType), Number(info.r), Number(info.g), Number(info.b),
			Bit(info.colorNameByClass) }, ":")
	end
	for _, cvar in ipairs(CHAT_CVARS) do
		local value = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(cvar)
		if value ~= nil then
			lines[#lines + 1] = "cvar=" .. cvar .. ":" .. Enc(value)
		end
	end
	return table.concat(lines, "\n"), "Discussion (" .. date("%d/%m/%Y") .. ")"
end

-- LECTURE ------------------------------------------------------------------------------------

local function Parse(text)
	text = tostring(text or "")
	if not text:find("^%s*" .. HEADER) then
		return nil
	end
	local profile = { windows = {}, colors = {}, cvars = {} }
	local function Window(id)
		id = tonumber(id)
		if not id then
			return nil
		end
		profile.windows[id] = profile.windows[id] or { id = id, groups = {}, channels = {} }
		return profile.windows[id]
	end
	for line in text:gmatch("[^\r\n]+") do
		local key, value = line:match("^%s*(%a+)=(.*)$")
		local fields = value and { strsplit(":", value) } or {}
		if key == "fenetre" then
			local window = Window(fields[1])
			if window then
				window.shown, window.docked, window.locked = fields[2] == "1", fields[3] == "1", fields[4] == "1"
				window.size = tonumber(fields[5])
				window.r, window.g, window.b = tonumber(fields[6]), tonumber(fields[7]), tonumber(fields[8])
				window.alpha = tonumber(fields[9])
				window.name = Dec(fields[10] or "")
				window.defined = true
			end
		elseif key == "groupes" or key == "canaux" then
			local window = Window(fields[1])
			if window then
				local target = key == "groupes" and window.groups or window.channels
				for item in (fields[2] or ""):gmatch("[^,]+") do
					target[#target + 1] = Dec(item)
				end
			end
		elseif key == "position" then
			local window = Window(fields[1])
			if window then
				window.point = fields[2]
				window.x, window.y = tonumber(fields[3]), tonumber(fields[4])
				window.width, window.height = tonumber(fields[5]), tonumber(fields[6])
			end
		elseif key == "couleur" then
			profile.colors[#profile.colors + 1] = { type = Dec(fields[1]), r = tonumber(fields[2]),
				g = tonumber(fields[3]), b = tonumber(fields[4]), byClass = fields[5] == "1" }
		elseif key == "cvar" and fields[1] then
			profile.cvars[#profile.cvars + 1] = { fields[1], Dec(fields[2] or "") }
		end
	end
	return profile
end

function ns.ChatDetails(text)
	local profile = Parse(text)
	if not profile then
		return nil
	end
	local names = {}
	for id = 1, NumWindows() do
		local window = profile.windows[id]
		if window and window.defined then
			names[#names + 1] = window.name ~= "" and window.name or ("n° " .. id)
		end
	end
	return { #names .. " fenêtre(s) : " .. table.concat(names, ", "), #profile.colors .. " couleur(s) de messages" }
end

-- APPLICATION --------------------------------------------------------------------------------

local function ApplyWindow(frame, window)
	local id = frame:GetID()
	if window.name and window.name ~= "" then
		FCF_SetWindowName(frame, window.name)
	end
	if window.size then
		FCF_SetChatWindowFontSize(nil, frame, window.size)
	end
	if window.r then
		FCF_SetWindowColor(frame, window.r, window.g, window.b)
	end
	if window.alpha then
		FCF_SetWindowAlpha(frame, window.alpha)
	end
	FCF_SetLocked(frame, window.locked)
	if id ~= 2 then -- journal de combat : ses propres filtres
		frame:RemoveAllMessageGroups()
		for _, group in ipairs(window.groups) do
			frame:AddMessageGroup(group)
		end
		frame:RemoveAllChannels()
		for _, channel in ipairs(window.channels) do
			frame:AddChannel(channel)
		end
	end
	if id == 1 then
		return -- placée par le mode Édition, toujours ancrée
	end
	local _, _, _, _, _, _, _, _, docked = GetChatWindowInfo(id)
	if window.docked and not docked then
		FCF_DockFrame(frame, #FCFDock_GetChatFrames(GENERAL_CHAT_DOCK) + 1)
	elseif not window.docked then
		if docked then
			FCF_UnDockFrame(frame)
		end
		if window.point and window.width then
			SetChatWindowSavedPosition(id, window.point, window.x or 0, window.y or 0)
			SetChatWindowSavedDimensions(id, window.width, window.height or window.width)
			FCF_RestorePositionAndDimensions(frame)
		end
		frame:Show()
		local tab = _G[frame:GetName() .. "Tab"]
		if tab then
			tab:Show()
		end
	end
end

-- Applique un paramétrage de discussion ; true et le compte rendu, ou nil et la raison.
function ns.ApplyChat(text)
	local profile = Parse(text)
	if not profile then
		return nil, "Ce profil n'est pas un paramétrage de discussion."
	elseif InCombatLockdown() then
		return nil, "Impossible en combat."
	elseif not (FCF_OpenNewWindow and FCF_Close and GetChatWindowInfo) then
		return nil, "Fenêtres de discussion indisponibles sur ce client."
	end
	-- Fenêtres actives absentes du profil : fermées (1 et 2 jamais).
	for id = 3, NumWindows() do
		local window = profile.windows[id]
		local frame = _G["ChatFrame" .. id]
		if frame and WindowActive(id) and not (window and window.defined) then
			FCF_Close(frame)
		end
	end
	-- Fenêtres du profil, dans l'ordre : existantes réutilisées, manquantes ouvertes.
	local count = 0
	for id = 1, NumWindows() do
		local window = profile.windows[id]
		if window and window.defined then
			local frame = _G["ChatFrame" .. id]
			if id > 2 and not WindowActive(id) then
				frame = FCF_OpenNewWindow(window.name, true)
			end
			if frame then
				ApplyWindow(frame, window)
				count = count + 1
			end
		end
	end
	for _, color in ipairs(profile.colors) do
		if ChatTypeInfo and ChatTypeInfo[color.type] and color.r then
			ChangeChatColor(color.type, color.r, color.g, color.b)
			if SetChatColorNameByClass then
				SetChatColorNameByClass(color.type, color.byClass)
			end
		end
	end
	for _, entry in ipairs(profile.cvars) do
		if C_CVar and C_CVar.GetCVar(entry[1]) ~= nil and C_CVar.GetCVar(entry[1]) ~= entry[2] then
			C_CVar.SetCVar(entry[1], entry[2])
		end
	end
	return true, "Discussion paramétrée : " .. count .. " fenêtre(s). Un /reload est conseillé."
end
