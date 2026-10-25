-- Polypode Profil: Interfaces — profils ElvUI et EllesmereUI (capture et import par leurs fonctions publiques)

local P = Polypode
local _, ns = ...
local L = ns.L

-- Les chaînes sont celles des boutons « Exporter » des addons eux-mêmes : on les obtient et on
-- les importe par les fonctions publiques de chaque addon, jamais en recopiant leur format.
-- Chaque import d'un profil crée un nouveau profil dans l'addon (nom libre, suffixé « (2) »...).

-- Icône d'un addon (## IconTexture de son .toc), ou nil.
function ns.AddonIcon(addon)
	local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata
	local ok, icon = pcall(getMetadata, addon, "IconTexture")
	return ok and icon or nil
end

-- Nom libre parmi existing (table { [nom] = ... }) : base, sinon « base (2) », « base (3) »...
local function UniqueName(base, existing)
	existing = existing or {}
	if not existing[base] then
		return base
	end
	local index = 2
	while existing[("%s (%d)"):format(base, index)] do
		index = index + 1
	end
	return ("%s (%d)"):format(base, index)
end

-- ELVUI --------------------------------------------------------------------------------------
-- Module « Distributor » d'ElvUI (Game/Shared/General/Distributor.lua) : ExportProfile(type, clé,
-- "text") donne la chaîne de son bouton Exporter ; Decode la relit (type, clé, données) ;
-- SetImportedProfile l'installe. Quatre types : profile (profil nommé, partagé), private
-- (réglages du personnage), global (réglages du compte), filters (filtres d'auras).

local ELVUI_TYPES = { profile = true, private = true, global = true, filters = true }

local function ElvDistributor()
	local engine = type(ElvUI) == "table" and ElvUI[1]
	if not (engine and engine.GetModule) then
		return
	end
	local ok, distributor = pcall(engine.GetModule, engine, "Distributor", true)
	if ok and distributor and distributor.ExportProfile and distributor.Decode and distributor.SetImportedProfile then
		return distributor
	end
end

function ns.HasElvUI()
	return ElvDistributor() ~= nil
end

-- Libellé d'un type de chaîne ElvUI (et de sa clé pour un profil).
local function ElvTypeLabel(dataType, key)
	if dataType == "profile" then
		return L["Profil « %s »"]:format(key or "?")
	elseif dataType == "private" then
		return L["Réglages du personnage"]
	elseif dataType == "global" then
		return L["Réglages du compte"]
	elseif dataType == "filters" then
		return L["Filtres"]
	end
	return L["inconnu"]
end

-- Profils ElvUI (noms triés) et profil actif du personnage.
function ns.GetElvUIProfiles()
	local names = {}
	for name in pairs(type(ElvDB) == "table" and ElvDB.profiles or {}) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)
	-- Profil actif : ElvDB.profileKeys, rangé par la clé de personnage d'ElvUI (E.mynameRealm).
	local engine = type(ElvUI) == "table" and ElvUI[1]
	local active = engine and type(ElvDB) == "table" and ElvDB.profileKeys and ElvDB.profileKeys[engine.mynameRealm]
	return names, active
end

-- Chaîne ElvUI d'un type (profile : clé du profil ; private : personnage joué) : texte, nom
-- proposé, ou nil, raison.
function ns.ExportElvUI(dataType, key)
	local distributor = ElvDistributor()
	if not distributor then
		return nil, L["ElvUI n'est pas chargé."]
	end
	local ok, profileKey, text = pcall(distributor.ExportProfile, distributor, dataType, key, "text")
	if not (ok and text) then
		return nil, L["ElvUI n'a pas pu exporter ces réglages."]
	end
	local label = dataType == "profile" and profileKey
		or dataType == "private" and L["Réglages de %s"]:format(P.GetDisplayName(P.GetCharKey()))
		or ElvTypeLabel(dataType)
	return text, "ElvUI — " .. label
end

-- Type, clé et données d'une chaîne ElvUI, ou nil.
local function DecodeElvUI(text)
	local distributor = ElvDistributor()
	if not distributor then
		return
	end
	local ok, dataType, key, data = pcall(distributor.Decode, distributor, text)
	if ok and ELVUI_TYPES[dataType] and type(data) == "table" then
		return dataType, key, data
	end
end

-- Détail d'infobulle : type de la chaîne.
function ns.ElvUIDetails(text)
	local dataType, key = DecodeElvUI(text)
	if not dataType then
		return { ns.HasElvUI() and L["Chaîne ElvUI illisible."] or L["ElvUI n'est pas chargé."] }
	end
	return { L["Contenu : %s"]:format(ElvTypeLabel(dataType, key)) }
end

-- Texte de confirmation avant l'import, selon le type.
function ns.ElvUIConfirm(profile)
	local dataType, key = DecodeElvUI(profile.text)
	if dataType == "profile" then
		return L["Un nouveau profil ElvUI va être créé depuis « %s », puis activé."]:format(key or "?")
	elseif dataType == "private" then
		return L["Les réglages ElvUI du personnage joué vont être remplacés (rechargement ensuite)."]
	elseif dataType == "global" then
		return L["Les réglages ElvUI du compte vont être remplacés."]
	elseif dataType == "filters" then
		return L["Les filtres d'auras d'ElvUI vont être remplacés."]
	end
	return L["Cette chaîne va être importée dans ElvUI."]
end

-- Import : profil = nouveau profil ElvUI (nom libre), activé ; private / global / filters
-- remplacent les réglages correspondants (ElvUI propose lui-même de recharger pour private).
function ns.ImportElvUI(text)
	local distributor = ElvDistributor()
	if not distributor then
		return nil, L["ElvUI n'est pas chargé."]
	elseif InCombatLockdown() then
		return nil, L["Impossible en combat."]
	end
	local dataType, key, data = DecodeElvUI(text)
	if not dataType then
		return nil, L["Chaîne refusée par ElvUI."]
	end
	local name = dataType == "profile" and UniqueName(key or "Polypode", ElvDB and ElvDB.profiles) or key
	if not pcall(distributor.SetImportedProfile, distributor, dataType, name, data) then
		return nil, L["Chaîne refusée par ElvUI."]
	end
	if dataType == "profile" then
		return true, L["Nouveau profil ElvUI « %s », activé."]:format(name)
	end
	return true, L["%s d'ElvUI importés."]:format(ElvTypeLabel(dataType))
end

-- ELLESMEREUI --------------------------------------------------------------------------------
-- EllesmereUI_Profiles.lua : ExportProfile(nom) (profil complet, comme son export), ExportFullAccountData()
-- (« export complet » : réglages du compte + profil actif), DecodeImportString / IsFullAccountPayload
-- (lecture), ImportProfileInteractive (sa page d'import, qui traite les deux et demande confirmation).

local function HasEllesmereFn(name)
	return type(EllesmereUI) == "table" and type(EllesmereUI[name]) == "function"
end

function ns.HasEllesmereUI()
	return HasEllesmereFn("ExportProfile") and HasEllesmereFn("GetProfileList")
end

-- Profils EllesmereUI (ordre de l'addon) et profil actif.
function ns.GetEllesmereUIProfiles()
	local names = {}
	local ok, order, profiles = pcall(EllesmereUI.GetProfileList)
	if ok then
		for _, name in ipairs(order or {}) do
			if not profiles or profiles[name] then
				names[#names + 1] = name
			end
		end
	end
	local active = HasEllesmereFn("GetActiveProfileName") and EllesmereUI.GetActiveProfileName() or nil
	return names, active
end

-- Chaîne d'un profil EllesmereUI : texte, nom proposé, ou nil, raison.
function ns.ExportEllesmereUI(name)
	local ok, text = pcall(EllesmereUI.ExportProfile, name)
	if not (ok and type(text) == "string") then
		return nil, L["EllesmereUI n'a pas pu exporter ce profil."]
	end
	return text, "EllesmereUI — " .. name
end

-- Export complet d'EllesmereUI (réglages du compte et profil actif).
function ns.ExportEllesmereUIFull()
	if not HasEllesmereFn("ExportFullAccountData") then
		return nil, L["Export complet indisponible dans cette version d'EllesmereUI."]
	end
	local ok, text = pcall(EllesmereUI.ExportFullAccountData)
	if not (ok and type(text) == "string") then
		return nil, L["EllesmereUI n'a pas pu faire l'export complet."]
	end
	local _, active = ns.GetEllesmereUIProfiles()
	return text, "EllesmereUI — " .. L["Export complet (%s)"]:format(active or "?")
end

-- Données décodées d'une chaîne EllesmereUI, ou nil.
local function DecodeEllesmereUI(text)
	if not HasEllesmereFn("DecodeImportString") then
		return
	end
	local ok, payload = pcall(EllesmereUI.DecodeImportString, text)
	if ok and type(payload) == "table" then
		return payload
	end
end

local function IsFullPayload(payload)
	return HasEllesmereFn("IsFullAccountPayload") and EllesmereUI.IsFullAccountPayload(payload) or false
end

function ns.EllesmereUIDetails(text)
	local payload = DecodeEllesmereUI(text)
	if not payload then
		return { ns.HasEllesmereUI() and L["Chaîne EllesmereUI illisible."] or L["EllesmereUI n'est pas chargé."] }
	end
	return { L["Contenu : %s"]:format(IsFullPayload(payload) and L["export complet (compte et profil actif)"]
		or L["Profil « %s »"]:format(payload.profileName or "?")) }
end

function ns.EllesmereUIConfirm(profile)
	local payload = DecodeEllesmereUI(profile.text)
	if payload and IsFullPayload(payload) then
		return L["Export complet : les réglages EllesmereUI du compte vont être remplacés (EllesmereUI demande confirmation et recharge)."]
	end
	return L["La page d'import d'EllesmereUI va s'ouvrir sur ce profil, sous un nouveau nom."]
end

-- Import par la page d'import d'EllesmereUI (elle détecte l'export complet et demande
-- confirmation) ; un profil y arrive sous un nom libre.
function ns.ImportEllesmereUI(text)
	if not HasEllesmereFn("ImportProfileInteractive") then
		return nil, L["EllesmereUI n'est pas chargé."]
	elseif InCombatLockdown() then
		return nil, L["Impossible en combat."]
	end
	local payload = DecodeEllesmereUI(text)
	if not payload then
		return nil, L["Chaîne refusée par EllesmereUI."]
	end
	local _, profiles = pcall(EllesmereUI.GetProfileList)
	local name = UniqueName(payload.profileName or "Polypode", type(profiles) == "table" and profiles or nil)
	local ok, started, reason = pcall(EllesmereUI.ImportProfileInteractive,
		{ importString = text, profileName = name, source = "Polypode Profil" })
	if not (ok and started) then
		return nil, L["EllesmereUI a refusé l'import : %s"]:format(tostring(reason or "?"))
	end
	return true, L["Import ouvert dans EllesmereUI : validez dans sa fenêtre."]
end
