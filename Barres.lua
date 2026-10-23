-- Polypode Profil: Barres — barres d'action : capture des 180 emplacements (et des macros posées) et application

local _, ns = ...
local L = ns.L

-- Les barres d'action du personnage joué, en texte (reprend le principe de l'addon MySlot, sans
-- son format binaire) :
--   Polypode barres v1
--   classe=MAGE                   (classe de la capture : avertissement si elle diffère)
--   # Spécialisation : Givre      (commentaire, pour mémoire)
--   <emplacement>=spell:<sortID>[:nom]          sort (sort de base : l'override suit le sort)
--   <emplacement>=item:<objetID>[:nom]          objet
--   <emplacement>=macro:<nom>                   macro, définie plus bas par une ligne macro=
--   <emplacement>=flyout:<flyoutID>[:nom]       menu de sorts (portails, familiers...)
--   <emplacement>=mount:<montureID>[:nom]       monture (268435455 = monture favorite aléatoire)
--   <emplacement>=pet:<GUID>[:nom]              mascotte
--   <emplacement>=equipset:<nom>                ensemble d'équipement
--   <emplacement>=outfit:<tenueID>:<nom>        tenue de transmogrification
--   <emplacement>=autre:<type>                  type non géré : laissé tel quel à l'application
--   macro=<g|p>:<icône>:<nom>:<texte>           macro posée (générale ou propre au personnage)
-- Emplacements 1 à 180 (barres 1 à 15, comme MySlot), dont les barres de forme / posture. Noms et
-- textes encodés (%XX pour « % = , : | » et les retours à la ligne) ; « [:nom] » ne sert qu'à la
-- lecture et à l'infobulle.
--
-- Application (ns.ApplyActionBars, hors combat) : chaque emplacement du profil est reposé (curseur
-- + PlaceAction), les autres sont vidés ; un sort non appris, un objet absent... laisse
-- l'emplacement vide et est compté. Les macros sont retrouvées par leur nom (même type d'abord),
-- sinon créées d'après le profil s'il reste de la place.

local HEADER = "Polypode barres v1"
local MAX_SLOTS = 180
local RANDOM_MOUNT = 268435455 -- 0x0FFFFFFF : « monture favorite aléatoire »

local PickupSpell = C_Spell and C_Spell.PickupSpell or PickupSpell
local PickupItem = C_Item and C_Item.PickupItem or PickupItem
local PickupSpellBookItem = C_SpellBook and C_SpellBook.PickupSpellBookItem or PickupSpellBookItem
local FindBaseSpellByID = C_SpellBook and C_SpellBook.FindBaseSpellByID or FindBaseSpellByID
local HasAction = C_ActionBar and C_ActionBar.HasAction or HasAction

local function Enc(text)
	return (tostring(text or ""):gsub("[%%=,:|\r\n]", function(char)
		return string.format("%%%02X", char:byte())
	end))
end

local function Dec(text)
	return (tostring(text or ""):gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function MaxMacros()
	local consts = Constants and Constants.MacroConsts
	return consts and consts.MAX_ACCOUNT_MACROS or 120, consts and consts.MAX_CHARACTER_MACROS or 30
end

local function SpellName(id)
	return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
end

local function ItemName(id)
	return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
end

local function MountName(id)
	if id == RANDOM_MOUNT then
		return L["Monture favorite aléatoire"]
	end
	return C_MountJournal and C_MountJournal.GetMountInfoByID and (C_MountJournal.GetMountInfoByID(id))
end

-- CAPTURE ------------------------------------------------------------------------------------

-- Ligne d'un emplacement (sans « n= »), et la macro posée (index) s'il y en a une ; nil si vide.
local function SlotLine(slot)
	local actionType, id, subType = GetActionInfo(slot)
	if not actionType then
		return nil
	end
	if actionType == "spell" then
		if subType == "assistedcombat" and C_AssistedCombat and C_AssistedCombat.GetActionSpell then
			id = C_AssistedCombat.GetActionSpell() or id
		end
		id = FindBaseSpellByID and FindBaseSpellByID(id) or id
		return "spell:" .. id .. ":" .. Enc(SpellName(id) or "")
	elseif actionType == "item" then
		return "item:" .. id .. ":" .. Enc(ItemName(id) or "")
	elseif actionType == "macro" then
		-- L'id rendu peut être le sort affiché par la macro : le vrai index se lit sur le curseur
		-- (même méthode que MySlot), puis la macro est reposée.
		if subType and subType ~= "" then
			PickupAction(slot)
			local _, index = GetCursorInfo()
			PlaceAction(slot)
			ClearCursor()
			id = index
		end
		local name = id and GetMacroInfo(id)
		if not name then
			return "autre:macro"
		end
		return "macro:" .. Enc(name), id
	elseif actionType == "flyout" then
		local name = GetFlyoutInfo and GetFlyoutInfo(id)
		return "flyout:" .. id .. ":" .. Enc(name or "")
	elseif actionType == "summonmount" then
		return "mount:" .. id .. ":" .. Enc(MountName(id) or "")
	elseif actionType == "summonpet" then
		local name = C_PetJournal and C_PetJournal.GetPetInfoByPetID
			and select(8, C_PetJournal.GetPetInfoByPetID(id))
		return "pet:" .. tostring(id) .. ":" .. Enc(name or "")
	elseif actionType == "equipmentset" then
		return "equipset:" .. Enc(id)
	elseif actionType == "outfit" then
		local info = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitInfo
			and C_TransmogOutfitInfo.GetOutfitInfo(id)
		return "outfit:" .. id .. ":" .. Enc(info and info.name or "")
	end
	return "autre:" .. Enc(actionType)
end

-- Texte des barres d'action du personnage joué, et un nom proposé ; ou nil et la raison.
function ns.ExportActionBars()
	if not GetActionInfo then
		return nil, L["Barres d'action indisponibles."]
	elseif InCombatLockdown() then
		return nil, L["Impossible en combat."]
	end
	ClearCursor()
	local _, classToken = UnitClass("player")
	local lines = { HEADER, "classe=" .. (classToken or "") }
	local okSpec, spec = false, nil
	if PlayerUtil and PlayerUtil.GetSpecName then
		okSpec, spec = pcall(PlayerUtil.GetSpecName)
	end
	spec = okSpec and type(spec) == "string" and spec ~= "" and spec or nil
	if spec then
		lines[#lines + 1] = "# Spécialisation : " .. spec
	end
	local macros, macroOrder = {}, {}
	local count = 0
	for slot = 1, MAX_SLOTS do
		local ok, line, macroIndex = pcall(SlotLine, slot)
		if ok and line then
			lines[#lines + 1] = slot .. "=" .. line
			count = count + 1
			if macroIndex and not macros[macroIndex] then
				macros[macroIndex] = true
				macroOrder[#macroOrder + 1] = macroIndex
			end
		end
	end
	if count == 0 then
		return nil, L["Aucune action sur les barres de ce personnage."]
	end
	local maxAccount = MaxMacros()
	table.sort(macroOrder)
	for _, index in ipairs(macroOrder) do
		local name, icon, body = GetMacroInfo(index)
		if name then
			lines[#lines + 1] = string.format("macro=%s:%s:%s:%s", index > maxAccount and "p" or "g",
				tostring(icon or 134400), Enc(name), Enc(body or ""))
		end
	end
	return table.concat(lines, "\n"), spec and L["Barres d'action %s"]:format(spec) or L["Barres d'action"]
end

-- LECTURE ------------------------------------------------------------------------------------

-- { class, slots = { [n] = { kind, value, extra } }, macros = { [nom] = { perCharacter, icon, body } } }
local function Parse(text)
	local lines = {}
	for line in (tostring(text or "") .. "\n"):gmatch("(.-)\r?\n") do
		lines[#lines + 1] = strtrim(line)
	end
	if lines[1] ~= HEADER then
		return nil
	end
	local data = { slots = {}, macros = {}, count = 0 }
	for i = 2, #lines do
		local key, value = lines[i]:match("^([^#=]+)=(.*)$")
		local slot = tonumber(key)
		if slot and slot >= 1 and slot <= MAX_SLOTS then
			local kind, rest = value:match("^(%a+):?(.*)$")
			if kind then
				local first, extra = strsplit(":", rest, 2)
				data.slots[slot] = { kind = kind, value = Dec(first or ""), extra = Dec(extra or "") }
				data.count = data.count + 1
			end
		elseif key == "classe" then
			data.class = value ~= "" and value or nil
		elseif key == "macro" then
			local scope, icon, name, body = strsplit(":", value, 4)
			name = Dec(name or "")
			if name ~= "" then
				data.macros[name] = { perCharacter = scope == "p", icon = tonumber(icon) or icon,
					body = Dec(body or "") }
			end
		end
	end
	return data
end

-- Nom de la classe (token « MAGE ») dans la langue du jeu.
local function ClassName(token)
	return token and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token] or token) or "?"
end

-- Lignes de détail de l'infobulle d'un profil de barres d'action.
function ns.ActionBarsDetails(text)
	local data = Parse(text)
	if not data then
		return nil
	end
	local bars, macroCount = {}, 0
	for slot in pairs(data.slots) do
		bars[math.ceil(slot / 12)] = true
	end
	local barCount = 0
	for _ in pairs(bars) do
		barCount = barCount + 1
	end
	for _ in pairs(data.macros) do
		macroCount = macroCount + 1
	end
	return {
		L["%d action(s) sur %d barre(s), %d macro(s)"]:format(data.count, barCount, macroCount),
		L["Classe : %s"]:format(ClassName(data.class)),
	}
end

-- Texte de confirmation avant application (classe différente signalée).
function ns.ActionBarsConfirm(text)
	local confirm = L["Les barres d'action du personnage joué vont être remplacées par celles de ce profil "
		.. "(emplacements vides compris)."]
	local data = Parse(text)
	local _, classToken = UnitClass("player")
	if data and data.class and data.class ~= classToken then
		confirm = confirm .. "\n\n|cffff4040" .. L["Profil capturé sur un(e) %s : les sorts d'une autre classe seront ignorés."]
			:format(ClassName(data.class)) .. "|r"
	end
	return confirm
end

-- APPLICATION --------------------------------------------------------------------------------

-- Index de la macro nommée name (type voulu d'abord, sinon l'autre), ou nil.
local function FindMacro(name, perCharacter)
	local maxAccount = MaxMacros()
	local numAccount, numCharacter = GetNumMacros()
	local account = { 1, numAccount or 0 }
	local character = { maxAccount + 1, maxAccount + (numCharacter or 0) }
	for _, range in ipairs(perCharacter and { character, account } or { account, character }) do
		for i = range[1], range[2] do
			if GetMacroInfo(i) == name then
				return i
			end
		end
	end
end

-- Macro du profil retrouvée ou créée ; renvoie son index, ou nil.
local function ResolveMacro(name, definition)
	local index = FindMacro(name, definition and definition.perCharacter)
	if index or not definition then
		return index
	end
	local maxAccount, maxCharacter = MaxMacros()
	local numAccount, numCharacter = GetNumMacros()
	local roomAccount, roomCharacter = (numAccount or 0) < maxAccount, (numCharacter or 0) < maxCharacter
	local perCharacter = definition.perCharacter
	if perCharacter and not roomCharacter or not perCharacter and not roomAccount then
		perCharacter = not perCharacter -- plus de place dans ce type : l'autre
	end
	if perCharacter and not roomCharacter or not perCharacter and not roomAccount then
		return nil
	end
	local icon = definition.icon
	if definition.body:sub(1, 12) == "#showtooltip" then
		icon = 134400 -- l'icône suit le sort affiché
	end
	local ok, created = pcall(CreateMacro, name, icon or 134400, definition.body, perCharacter)
	return ok and created or nil
end

-- Position d'un menu de sorts (flyout) dans le livre de sorts : { [flyoutID] = index }.
local function FlyoutIndexes()
	local list = {}
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and Enum and Enum.SpellBookSpellBank) then
		return list
	end
	local bank = Enum.SpellBookSpellBank.Player
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		for i = 1, info and info.numSpellBookItems or 0 do
			local index = info.itemIndexOffset + i
			local itemType, actionID = C_SpellBook.GetSpellBookItemType(index, bank)
			if itemType == Enum.SpellBookItemType.Flyout then
				list[actionID] = index
			end
		end
	end
	return list
end

-- Montures possédées : { [montureID] = position dans la liste affichée du journal }.
local function MountIndexes()
	local list = {}
	if not (C_MountJournal and C_MountJournal.GetNumDisplayedMounts and C_MountJournal.GetDisplayedMountInfo) then
		return list
	end
	for i = 1, C_MountJournal.GetNumDisplayedMounts() do
		local isCollected, mountID = select(11, C_MountJournal.GetDisplayedMountInfo(i))
		if isCollected and mountID then
			list[mountID] = i
		end
	end
	return list
end

-- Met l'action d'un emplacement du profil sous le curseur (rien si elle est introuvable).
local function PickupEntry(entry, context)
	local kind, value = entry.kind, entry.value
	local id = tonumber(value)
	if kind == "spell" and id then
		PickupSpell(id)
		local override = C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(id)
		if not GetCursorInfo() and override and override ~= id then
			PickupSpell(override)
		end
		local base = FindBaseSpellByID and FindBaseSpellByID(id)
		if not GetCursorInfo() and base and base ~= id then
			PickupSpell(base)
		end
		local name = not GetCursorInfo() and SpellName(id)
		if name then
			PickupSpell(name)
		end
	elseif kind == "item" and id then
		PickupItem(id)
	elseif kind == "macro" then
		local index = context.macros[value]
		if index == nil then
			index = ResolveMacro(value, context.data.macros[value]) or false
			context.macros[value] = index
		end
		if index then
			PickupMacro(index)
		end
	elseif kind == "flyout" and id then
		local index = context.flyouts[id]
		if index and PickupSpellBookItem then
			PickupSpellBookItem(index, Enum.SpellBookSpellBank.Player)
		end
	elseif kind == "mount" and id and C_MountJournal then
		if id == RANDOM_MOUNT then
			C_MountJournal.Pickup(0)
		else
			if context.mounts[id] then
				C_MountJournal.Pickup(context.mounts[id])
			end
			local spellID = not GetCursorInfo() and C_MountJournal.GetMountInfoByID
				and select(2, C_MountJournal.GetMountInfoByID(id))
			if spellID then
				PickupSpell(spellID)
			end
		end
	elseif kind == "pet" and C_PetJournal and C_PetJournal.PickupPet then
		C_PetJournal.PickupPet(value)
	elseif kind == "equipset" and C_EquipmentSet then
		local setID = C_EquipmentSet.GetEquipmentSetID(value)
		if setID then
			C_EquipmentSet.PickupEquipmentSet(setID)
		end
	elseif kind == "outfit" and id and C_TransmogOutfitInfo and C_TransmogOutfitInfo.PickupOutfit then
		C_TransmogOutfitInfo.PickupOutfit(id)
		-- Tenue d'un autre compte : retrouvée par son nom.
		local info = not GetCursorInfo() and entry.extra ~= "" and C_TransmogOutfitInfo.GetOutfitInfoByName
			and C_TransmogOutfitInfo.GetOutfitInfoByName(entry.extra)
		if info and info.outfitID then
			C_TransmogOutfitInfo.PickupOutfit(info.outfitID)
		end
	end
end

-- Libellé d'un emplacement non posé (compte rendu).
local function EntryLabel(entry)
	if entry.kind == "macro" or entry.kind == "equipset" then
		return entry.value
	end
	return entry.extra ~= "" and entry.extra or (entry.kind .. " " .. entry.value)
end

-- Applique les barres du profil au personnage joué ; renvoie ok et le compte rendu, ou nil et la
-- raison.
function ns.ApplyActionBars(text)
	local data = Parse(text)
	if not data then
		return nil, L["Texte de barres illisible (première ligne attendue : « %s »)."]:format(HEADER)
	elseif not (GetActionInfo and PickupAction and PlaceAction) then
		return nil, L["Barres d'action indisponibles."]
	elseif InCombatLockdown() then
		return nil, L["Impossible en combat."]
	end
	ClearCursor()
	local context = { data = data, macros = {}, flyouts = FlyoutIndexes(), mounts = MountIndexes() }
	local placed, cleared, missing = 0, 0, {}
	for slot = 1, MAX_SLOTS do
		local entry = data.slots[slot]
		if not entry then
			if HasAction and HasAction(slot) then
				PickupAction(slot)
				ClearCursor()
				cleared = cleared + 1
			end
		elseif entry.kind ~= "autre" then
			local ok = pcall(PickupEntry, entry, context)
			if ok and GetCursorInfo() then
				PlaceAction(slot) -- l'action remplacée passe sous le curseur, effacée ensuite
				placed = placed + 1
			else
				missing[#missing + 1] = EntryLabel(entry)
				if HasAction and HasAction(slot) then
					PickupAction(slot) -- emplacement vidé : l'action du profil n'existe pas ici
				end
			end
			ClearCursor()
		end
	end
	local report = L["%d action(s) posée(s)"]:format(placed)
	if cleared > 0 then
		report = report .. ", " .. L["%d emplacement(s) vidé(s)"]:format(cleared)
	end
	if #missing > 0 then
		local shown = {}
		for i = 1, math.min(3, #missing) do
			shown[i] = missing[i]
		end
		report = report .. ", " .. L["%d introuvable(s) (%s)"]:format(#missing, table.concat(shown, ", ")
			.. (#missing > 3 and "…" or ""))
	end
	return true, report .. "."
end
