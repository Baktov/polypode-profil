-- Polypode Profil: Equipement — ensembles d'équipement : capture (avec spécialisation) et recréation

local _, ns = ...

-- Un ensemble d'équipement du gestionnaire de Blizzard, en texte (pas de chaîne d'export chez
-- Blizzard ; pas de « | », que la zone de texte interpréterait) :
--   Polypode ensemble v1
--   icone=<fileID>
--   spe=<specID>:<nom de la spécialisation>      (absente si aucune)
--   <emplacement>=<chaîne d'objet « item:... »>  (une ligne par pièce, emplacements 1 à 19)
--   ignore=<emplacement>,...                      (emplacements ignorés par l'ensemble)
--   vide=<emplacement>,...                        (emplacements que l'ensemble laisse vides)
-- Chaîne d'objet normalisée (NormalizeItemString) : sans le niveau ni la spécialisation du
-- personnage, qui changent avec lui ; enchantement, gemmes et bonus (améliorations) restent.
--
-- Recréation (ns.CreateEquipmentSet) : WoW n'enregistre un ensemble qu'à partir de ce que le
-- personnage porte (C_EquipmentSet.CreateEquipmentSet). On vérifie d'abord que chaque pièce est
-- équipée ou dans les sacs, puis on les équipe une à une (curseur : prise dans le sac ou un autre
-- emplacement, pose sur l'emplacement), on crée l'ensemble (pièces ignorées = ignore + vide),
-- on lui associe la spécialisation (même specID chez ce personnage), puis on rééquipe ce qu'il
-- portait avant. Hors combat ; un seul à la fois. Les emplacements « vide » ne sont pas vidés :
-- l'ensemble recréé les ignore.

local HEADER = "Polypode ensemble v1"
local FIRST_SLOT, LAST_SLOT = 1, 19
local STEP_DELAY = 0.3 -- secondes entre deux mouvements d'objet
local STEP_TIMEOUT = 3 -- secondes d'attente d'un mouvement (objet verrouillé)
local MAX_STEPS = 40

-- Spécialisation n° index du personnage joué : specID, nom (C_SpecializationInfo sur Retail,
-- ancienne fonction globale en repli).
local function SpecInfo(index)
	local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
	if not (index and getInfo) then
		return nil
	end
	local specID, name = getInfo(index)
	if specID and specID ~= 0 then
		return specID, name
	end
end

local function Available()
	return C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.CreateEquipmentSet
		and (not C_EquipmentSet.CanUseEquipmentSets or C_EquipmentSet.CanUseEquipmentSets())
end

-- « item:id:enchant:gemme1..4:suffixe:unique:niveau:spé:... » sans niveau ni spé (champs 10, 11).
local function NormalizeItemString(itemString)
	if not itemString then
		return nil
	end
	local fields = { strsplit(":", itemString) }
	fields[10], fields[11] = "", ""
	return table.concat(fields, ":")
end

local function ItemStringOf(link)
	return link and NormalizeItemString(link:match("|H(item:[^|]+)|h")) or nil
end

local function ItemIDOf(itemString)
	return itemString and tonumber(itemString:match("^item:(%d+)")) or nil
end

-- CAPTURE ------------------------------------------------------------------------------------

-- Ensembles du personnage joué : { { id, name, spec }, ... } (spec = nom de la spécialisation).
function ns.GetEquipmentSets()
	local list = {}
	if not Available() then
		return list
	end
	for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
		local name = C_EquipmentSet.GetEquipmentSetInfo(id)
		local specIndex = C_EquipmentSet.GetEquipmentSetAssignedSpec and C_EquipmentSet.GetEquipmentSetAssignedSpec(id)
		local specName = select(2, SpecInfo(specIndex))
		list[#list + 1] = { id = id, name = name or ("Ensemble " .. id), spec = specName }
	end
	table.sort(list, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	return list
end

-- Lien exact d'une pièce d'ensemble d'après sa position (équipée ou dans les sacs), sinon nil.
local function LinkAtLocation(location)
	if not (location and location > EQUIPMENT_SET_IGNORED_SLOT and EquipmentManager_GetLocationData) then
		return nil
	end
	local data = EquipmentManager_GetLocationData(location)
	if data.isBags and data.bag and data.slot then
		return C_Container.GetContainerItemLink(data.bag, data.slot)
	elseif data.isPlayer and not data.isBank and data.slot then
		return GetInventoryItemLink("player", data.slot)
	end
end

-- Texte d'un ensemble et nom proposé (son nom), ou nil et la raison.
function ns.ExportEquipmentSet(id)
	if not Available() then
		return nil, "Ensembles d'équipement indisponibles."
	end
	local name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
	if not name then
		return nil, "Ensemble introuvable."
	end
	local itemIDs = C_EquipmentSet.GetItemIDs(id) or {}
	local ignored = C_EquipmentSet.GetIgnoredSlots(id) or {}
	local locations = C_EquipmentSet.GetItemLocations(id) or {}
	local lines = { HEADER, "icone=" .. (icon or 0) }
	local specIndex = C_EquipmentSet.GetEquipmentSetAssignedSpec and C_EquipmentSet.GetEquipmentSetAssignedSpec(id)
	local specID, specName = SpecInfo(specIndex)
	if specID then
		lines[#lines + 1] = "spe=" .. specID .. ":" .. (specName or "")
	end
	local ignoreList, emptyList = {}, {}
	for slot = FIRST_SLOT, LAST_SLOT do
		local itemID = tonumber(itemIDs[slot])
		if ignored[slot] then
			ignoreList[#ignoreList + 1] = slot
		elseif itemID and itemID > 0 then
			lines[#lines + 1] = slot .. "=" .. (ItemStringOf(LinkAtLocation(locations[slot])) or ("item:" .. itemID))
		else
			emptyList[#emptyList + 1] = slot
		end
	end
	if #ignoreList > 0 then
		lines[#lines + 1] = "ignore=" .. table.concat(ignoreList, ",")
	end
	if #emptyList > 0 then
		lines[#lines + 1] = "vide=" .. table.concat(emptyList, ",")
	end
	return table.concat(lines, "\n"), name
end

-- Lit le texte d'un ensemble : { icon, specID, specName, items = { [slot] = chaîne }, ignore =
-- { [slot] = true }, count }, ou nil.
local function Parse(text)
	text = tostring(text or "")
	if not text:find("^%s*" .. HEADER) then
		return nil
	end
	local set = { items = {}, ignore = {}, count = 0 }
	for line in text:gmatch("[^\r\n]+") do
		local key, value = line:match("^%s*([%w]+)=(.-)%s*$")
		local slot = tonumber(key)
		if slot and slot >= FIRST_SLOT and slot <= LAST_SLOT and value:find("^item:%d+") then
			set.items[slot] = value
			set.count = set.count + 1
		elseif key == "icone" then
			set.icon = tonumber(value)
		elseif key == "spe" then
			local specID, specName = value:match("^(%d+):?(.*)$")
			set.specID, set.specName = tonumber(specID), specName ~= "" and specName or nil
		elseif key == "ignore" or key == "vide" then
			for number in value:gmatch("%d+") do
				set.ignore[tonumber(number)] = true
			end
		end
	end
	return set
end

-- Lignes de détail pour l'infobulle d'un profil d'ensemble.
function ns.EquipmentSetDetails(text)
	local set = Parse(text)
	if not set then
		return nil
	end
	return {
		"Spécialisation : " .. (set.specName or "aucune"),
		set.count .. " pièce(s)",
	}
end

-- RECRÉATION ---------------------------------------------------------------------------------

local running = false

-- Objet de l'emplacement d'équipement / de sac, en chaîne normalisée.
local function EquippedString(slot)
	return ItemStringOf(GetInventoryItemLink("player", slot))
end

local function BagString(bag, slot)
	return ItemStringOf(C_Container.GetContainerItemLink(bag, slot))
end

-- Vrai si itemString (chaîne de l'objet trouvé) convient pour wanted : même chaîne en mode
-- exact, sinon même itemID.
local function Matches(itemString, wanted, exact)
	if not itemString then
		return false
	elseif exact then
		return itemString == wanted
	end
	return ItemIDOf(itemString) == ItemIDOf(wanted)
end

local function BagIDs()
	local bags = {}
	for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
		bags[#bags + 1] = bag
	end
	return bags
end

-- Mode de comparaison par emplacement : exact si la chaîne exacte existe (équipée ou en sac),
-- sinon par itemID (pièce améliorée depuis, par exemple). Renvoie aussi les emplacements dont
-- aucune pièce ne convient.
local function PlanModes(set)
	local present = {}
	for slot = FIRST_SLOT, LAST_SLOT do
		local s = EquippedString(slot)
		if s then
			present[s] = (present[s] or 0) + 1
		end
	end
	local idCount = {}
	for _, bag in ipairs(BagIDs()) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local s = BagString(bag, slot)
			if s then
				present[s] = (present[s] or 0) + 1
			end
		end
	end
	for s, n in pairs(present) do
		local id = ItemIDOf(s)
		idCount[id] = (idCount[id] or 0) + n
	end
	local modes, missing, neededID = {}, {}, {}
	for slot, wanted in pairs(set.items) do
		modes[slot] = (present[wanted] or 0) > 0
		local id = ItemIDOf(wanted)
		neededID[id] = (neededID[id] or 0) + 1
		if (idCount[id] or 0) < neededID[id] then
			missing[#missing + 1] = slot
		end
	end
	return modes, missing
end

-- Prochain mouvement : premier emplacement dont la pièce ne convient pas, et où la prendre (sac,
-- ou autre emplacement d'équipement qui ne la garde pas pour lui-même). nil si tout est en place.
local function NextMove(set, modes)
	for slot = FIRST_SLOT, LAST_SLOT do
		local wanted = set.items[slot]
		if wanted and not Matches(EquippedString(slot), wanted, modes[slot]) then
			for _, bag in ipairs(BagIDs()) do
				for bagSlot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
					if Matches(BagString(bag, bagSlot), wanted, modes[slot]) then
						return { slot = slot, bag = bag, bagSlot = bagSlot }
					end
				end
			end
			for other = FIRST_SLOT, LAST_SLOT do
				local otherWanted = set.items[other]
				if other ~= slot and Matches(EquippedString(other), wanted, modes[slot])
					and not (otherWanted and Matches(EquippedString(other), otherWanted, modes[other])) then
					return { slot = slot, fromSlot = other }
				end
			end
			return { slot = slot, missing = true }
		end
	end
end

local function DoMove(move)
	ClearCursor()
	if move.bag then
		C_Container.PickupContainerItem(move.bag, move.bagSlot)
	else
		PickupInventoryItem(move.fromSlot)
	end
	if not CursorHasItem() then
		return false
	end
	PickupInventoryItem(move.slot) -- pose (échange avec la pièce portée, qui revient au curseur ou au sac)
	if CursorHasItem() then
		-- Pièce remplacée restée au curseur : on la pose à l'endroit d'où venait la nouvelle.
		if move.bag then
			C_Container.PickupContainerItem(move.bag, move.bagSlot)
		else
			PickupInventoryItem(move.fromSlot)
		end
	end
	ClearCursor()
	return true
end

local function Busy()
	if CursorHasItem() then
		return true
	end
	for slot = FIRST_SLOT, LAST_SLOT do
		if IsInventoryItemLocked(slot) then
			return true
		end
	end
	return false
end

-- Équipe les pièces de set, pas à pas ; done(ok, raison) à la fin.
local function EquipAll(set, modes, done)
	local steps, waited = 0, 0
	local function Step()
		if InCombatLockdown() then
			done(false, "Interrompu : combat.")
			return
		end
		if Busy() then
			waited = waited + STEP_DELAY
			if waited > STEP_TIMEOUT then
				done(false, "Interrompu : objet verrouillé.")
				return
			end
			C_Timer.After(STEP_DELAY, Step)
			return
		end
		waited = 0
		local move = NextMove(set, modes)
		if not move then
			done(true)
			return
		elseif move.missing then
			done(false, "Pièce introuvable (emplacement " .. move.slot .. ").")
			return
		end
		steps = steps + 1
		if steps > MAX_STEPS or not DoMove(move) then
			done(false, "Interrompu : impossible d'équiper une pièce (emplacement " .. move.slot .. ").")
			return
		end
		C_Timer.After(STEP_DELAY, Step)
	end
	Step()
end

-- Pièces portées maintenant, pour les rééquiper après la création : { items, count } au format
-- d'un ensemble (comparaison exacte).
local function CurrentGear()
	local gear = { items = {}, ignore = {}, count = 0 }
	for slot = FIRST_SLOT, LAST_SLOT do
		local s = EquippedString(slot)
		if s then
			gear.items[slot] = s
			gear.count = gear.count + 1
		end
	end
	return gear
end

local function SpecIndexFor(specID)
	if not (specID and GetNumSpecializations) then
		return nil
	end
	for index = 1, GetNumSpecializations() do
		if SpecInfo(index) == specID then
			return index
		end
	end
end

-- Crée, chez le personnage joué, l'ensemble d'équipement name décrit par text. Asynchrone :
-- renvoie true (lancé) ou nil et la raison ; callback(message) à la fin (réussite ou échec).
function ns.CreateEquipmentSet(text, name, callback)
	local set = Parse(text)
	name = name and strtrim(name) or ""
	if not set then
		return nil, "Ce profil n'est pas un ensemble d'équipement."
	elseif not Available() then
		return nil, "Ensembles d'équipement indisponibles."
	elseif running then
		return nil, "Création d'un ensemble déjà en cours."
	elseif InCombatLockdown() then
		return nil, "Impossible en combat."
	elseif name == "" then
		return nil, "Le profil n'a pas de nom."
	elseif C_EquipmentSet.GetEquipmentSetID(name) then
		return nil, "Un ensemble « " .. name .. " » existe déjà chez ce personnage."
	elseif (C_EquipmentSet.GetNumEquipmentSets() or 0) >= (MAX_EQUIPMENT_SETS_PER_PLAYER or 10) then
		return nil, "Nombre maximal d'ensembles atteint."
	elseif set.count == 0 then
		return nil, "L'ensemble ne contient aucune pièce."
	end
	local modes, missing = PlanModes(set)
	if #missing > 0 then
		return nil, #missing .. " pièce(s) absente(s) des sacs et de l'équipement."
	end

	running = true
	local before = CurrentGear()
	local beforeModes = {}
	for slot in pairs(before.items) do
		beforeModes[slot] = true
	end
	local function Finish(message)
		running = false
		C_EquipmentSet.ClearIgnoredSlotsForSave()
		callback(message)
	end
	-- Rééquipe ce que le personnage portait avant (les pièces encore présentes).
	local function Restore(message)
		EquipAll(before, beforeModes, function(ok)
			Finish(ok and message or (message .. " (tenue précédente pas entièrement remise)"))
		end)
	end

	EquipAll(set, modes, function(ok, reason)
		if not ok then
			Restore("Ensemble non créé : " .. reason)
			return
		end
		C_EquipmentSet.ClearIgnoredSlotsForSave()
		for slot = FIRST_SLOT, LAST_SLOT do
			if not set.items[slot] then
				C_EquipmentSet.IgnoreSlotForSave(slot)
			end
		end
		C_EquipmentSet.CreateEquipmentSet(name, set.icon)
		local tries = 0
		local function WaitCreated()
			tries = tries + 1
			local id = C_EquipmentSet.GetEquipmentSetID(name)
			if not id and tries < 15 then
				C_Timer.After(0.2, WaitCreated)
				return
			elseif not id then
				Restore("Ensemble non créé (pas de réponse du jeu).")
				return
			end
			local message = "Ensemble « " .. name .. " » créé."
			local specIndex = SpecIndexFor(set.specID)
			if specIndex and C_EquipmentSet.AssignSpecToEquipmentSet then
				C_EquipmentSet.AssignSpecToEquipmentSet(id, specIndex)
				message = message .. " Spécialisation : " .. (set.specName or specIndex) .. "."
			elseif set.specID then
				message = message .. " Spécialisation non associée (autre classe)."
			end
			Restore(message)
		end
		C_Timer.After(0.2, WaitCreated)
	end)
	return true
end
