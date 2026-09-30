-- Polypode Profil: Addons — liste des addons activés, profils de Simple Addon Manager, rechargement

local _, ns = ...

-- LISTE DES ADDONS (genre « addons »), texte propre à Polypode Profil :
--   Polypode addons v1
--   # personnage : <nom>
--   +<addon>   (activé pour le personnage)
--   -<addon>   (désactivé)
-- Lecture et application pour le personnage joué (UnitGUID, comme la liste des AddOns de
-- Blizzard) ; les addons absents de ce PC sont comptés, ceux absents du profil ne sont pas
-- touchés, Polypode et Polypode Profil ne sont jamais désactivés. Effet au rechargement.
--
-- SIMPLE ADDON MANAGER (genre « simpleaddonmanager ») : capture de ses profils par son propre
-- export (SimpleAddonManager:GetModule("Profile"):ExportProfile, la chaîne JSON de son bouton
-- « Exporter », dépendances comprises) ; application par son import (ImportProfile : le profil
-- du même nom est remplacé), puis sa propre boîte « charger le profil et recharger ».
--
-- RECHARGEMENT : ns.Reload (C_UI.Reload / ReloadUI) seulement sur Retail et après un clic ou
-- Entrée dans une boîte de confirmation (ReloadUI est bloqué sur WoW Forever : on y demande de
-- taper /reload, cf. ../Polypode/CLAUDE.md).

local HEADER = "Polypode addons v1"
-- Jamais désactivés par un profil (sans eux, plus de fenêtre pour revenir en arrière).
local KEEP_ENABLED = { Polypode = true, Polypode_Profil = true }

local function Available()
	return C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnEnableState and C_AddOns.EnableAddOn
end

local function Character()
	return UnitGUID("player")
end

local function IsEnabled(nameOrIndex)
	return (C_AddOns.GetAddOnEnableState(nameOrIndex, Character()) or 0) > 0
end

-- Rechargement de l'interface possible depuis l'addon (Retail ; pas WoW Forever, interface 16001).
function ns.CanReload()
	local toc = select(4, GetBuildInfo())
	return (tonumber(toc) or 0) >= 100000 and ((C_UI and C_UI.Reload) or ReloadUI) ~= nil
end

function ns.Reload()
	if C_UI and C_UI.Reload then
		C_UI.Reload()
	elseif ReloadUI then -- ancienne fonction globale (autres clients)
		ReloadUI()
	end
end

-- LISTE DES ADDONS ---------------------------------------------------------------------------

function ns.ExportAddons()
	if not Available() then
		return nil, "Liste des addons illisible sur ce client."
	end
	local names = {}
	for index = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnName(index)
		if name then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)
	local lines = { HEADER, "# personnage : " .. (UnitName("player") or "?") }
	for _, name in ipairs(names) do
		lines[#lines + 1] = (IsEnabled(name) and "+" or "-") .. name
	end
	return table.concat(lines, "\n"), "Addons (" .. date("%d/%m/%Y") .. ")"
end

local function ParseAddons(text)
	text = tostring(text or "")
	if not text:find("^%s*" .. HEADER) then
		return nil
	end
	local list = {}
	for line in text:gmatch("[^\r\n]+") do
		local sign, name = line:match("^%s*([%+%-])(.-)%s*$")
		if sign and name ~= "" then
			list[#list + 1] = { name = name, enabled = sign == "+" }
		end
	end
	return list
end

function ns.AddonsDetails(text)
	local list = ParseAddons(text)
	if not list then
		return nil
	end
	local on = 0
	for _, entry in ipairs(list) do
		on = on + (entry.enabled and 1 or 0)
	end
	return { on .. " activé(s), " .. (#list - on) .. " désactivé(s)", "Effet au rechargement de l'interface" }
end

-- Applique une liste d'addons au personnage joué. Renvoie true, le compte rendu et vrai s'il
-- faut recharger ; ou nil et la raison.
function ns.ApplyAddons(text)
	local list = ParseAddons(text)
	if not list then
		return nil, "Ce profil n'est pas une liste d'addons."
	elseif not Available() then
		return nil, "Liste des addons indisponible sur ce client."
	end
	local enabled, disabled, same, missing = 0, 0, 0, 0
	for _, entry in ipairs(list) do
		local name = entry.name
		if not (C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist(name)) then
			missing = missing + 1
		elseif IsEnabled(name) == entry.enabled or (not entry.enabled and KEEP_ENABLED[name]) then
			same = same + 1
		elseif entry.enabled then
			C_AddOns.EnableAddOn(name, Character())
			enabled = enabled + 1
		else
			C_AddOns.DisableAddOn(name, Character())
			disabled = disabled + 1
		end
	end
	if C_AddOns.SaveAddOns then
		C_AddOns.SaveAddOns()
	end
	local changed = enabled + disabled
	return true, string.format("Addons : %d activé(s), %d désactivé(s), %d inchangé(s), %d absent(s) de ce PC.",
		enabled, disabled, same, missing), changed > 0
end

-- SIMPLE ADDON MANAGER -----------------------------------------------------------------------

-- Module « Profile » de Simple Addon Manager, s'il est chargé.
local function SAMProfiles()
	local sam = _G.SimpleAddonManager
	if type(sam) ~= "table" or type(sam.GetModule) ~= "function" then
		return nil
	end
	local ok, module = pcall(sam.GetModule, sam, "Profile")
	if ok and type(module) == "table" and module.ExportProfile and module.ImportProfile then
		return module, sam
	end
end

function ns.HasSimpleAddonManager()
	return SAMProfiles() ~= nil and type(SimpleAddonManagerDB) == "table" and type(SimpleAddonManagerDB.sets) == "table"
end

-- Noms des profils de Simple Addon Manager, triés.
function ns.GetSAMProfiles()
	local names = {}
	if ns.HasSimpleAddonManager() then
		for name in pairs(SimpleAddonManagerDB.sets) do
			names[#names + 1] = name
		end
		table.sort(names, function(a, b)
			return tostring(a):lower() < tostring(b):lower()
		end)
	end
	return names
end

-- Chaîne d'export (JSON) d'un profil de Simple Addon Manager.
function ns.ExportSAMProfile(name)
	local module = SAMProfiles()
	if not module then
		return nil, "Simple Addon Manager n'est pas chargé."
	end
	local ok, text = pcall(module.ExportProfile, module, name)
	if ok and type(text) == "string" and text ~= "" then
		return text
	end
	return nil, "Export du profil « " .. tostring(name) .. " » impossible."
end

-- Profils principaux d'une chaîne d'export : ceux dont aucun autre ne dépend.
local function MainProfiles(text)
	local json = LibStub and LibStub("JsonLua-0.1", true)
	if not json then
		return {}
	end
	local ok, data = pcall(json.decode, text)
	local profiles = ok and type(data) == "table" and data.profiles
	if type(profiles) ~= "table" then
		return {}
	end
	local isDependency = {}
	for _, profile in pairs(profiles) do
		for dependency in pairs(type(profile.profileDep) == "table" and profile.profileDep or {}) do
			isDependency[dependency] = true
		end
	end
	local mains = {}
	for name in pairs(profiles) do
		if not isDependency[name] then
			mains[#mains + 1] = name
		end
	end
	table.sort(mains)
	return mains
end

-- Importe un profil dans Simple Addon Manager. Renvoie true, le compte rendu et une suite (sa
-- boîte « charger ce profil et recharger ») ; ou nil et la raison.
function ns.ImportSAMProfile(text)
	local module, sam = SAMProfiles()
	if not module then
		return nil, "Simple Addon Manager n'est pas chargé."
	end
	local ok = pcall(module.ImportProfile, module, text)
	if not ok then
		return nil, "Chaîne refusée par Simple Addon Manager."
	end
	if sam.Update then
		pcall(sam.Update, sam)
	end
	local mains = MainProfiles(text)
	local message = "Importé dans Simple Addon Manager" .. (#mains > 0 and (" : " .. table.concat(mains, ", ")) or "") .. "."
	local followUp
	if #mains == 1 and module.ShowLoadProfileAndReloadUIDialog then
		followUp = function()
			module:ShowLoadProfileAndReloadUIDialog(mains[1])
		end
	end
	return true, message, followUp
end
