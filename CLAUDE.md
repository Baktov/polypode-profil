# CLAUDE.md — Polypode Profil (Addon WoW)

Addon compagnon de **Polypode** (dossier voisin `../Polypode`, dépôt séparé) : fenêtre « Profils »,
bibliothèque de chaînes d'export (mode Édition, talents, EllesmereUI, ElvUI, Baganator, MySlots...)
communes à tous les personnages et synchronisées entre les clients connectés. Les conventions de
Polypode s'appliquent (voir `../Polypode/CLAUDE.md`) : commentaires en français, code en anglais,
pas de librairie externe, pas de `print()`, bloc `-- Polypode Profil: Fichier — rôle` en tête de
fichier, tout contenu de taille variable défile, Retail (120000) et WoW Forever (16001) avec tests
d'existence des API. Un addon ne lit ni n'écrit le presse-papiers : la copie passe par Ctrl+C /
Ctrl+V dans la zone de texte.

## Architecture

| Fichier | Rôle |
|---|---|
| `Polypode_Profil.toc` | `## Dependencies: Polypode`, SavedVariables de compte `PolypodeProfilDB` (`profiles`, `window`, `collapsed`) ; ordre `Profil → UI` |
| `Profil.lua` | Genres `ns.KINDS` (`{ key, label, capture }`, ordre d'affichage ; genre inconnu → `other` par `ns.NormalizeKind`), `ns.KindLabel`, `ns.KindOrder`, `ns.CanCapture`. Bibliothèque `PolypodeProfilDB.profiles[id] = { name, kind, text, char, updated, removed }` (`char` = clé du personnage sous lequel le profil est rangé, défaut le personnage joué ; ancien champ `author` de la 1.0.0 migré à `ADDON_LOADED` ; id hexadécimal heure serveur + hasard ; `updated` = version `NextVersion`, strictement croissante ; suppression = pierre tombale `{ removed, updated }`) : `ns.Get`, `ns.GetProfiles` (actifs, triés genre puis nom), `ns.Save(id|nil, nom, genre, texte, char)` (texte vide refusé, nom vide = libellé du genre), `ns.Delete`. Capture : `ns.GetEditModeLayouts` (`EditModeManagerFrame.layoutInfo.layouts`, préréglages compris, `activeLayout`) + `ns.ExportEditModeLayout` (`C_EditMode.ConvertLayoutInfoToString`, comme « Copier dans le presse-papiers ») ; `ns.ExportTalents` (`PlayerSpellsFrame.TalentsFrame:GetLoadoutExportString()` sous `pcall`, nom « Talents <spé> — <configuration> ») — **ne jamais charger `Blizzard_PlayerSpells` depuis l'addon** (taint : l'application des talents pourrait être bloquée) ; fenêtre jamais ouverte → message. Transmogrification : `CustomSetSlashCommand` (format `/customset v1` recopié de `TransmogUtil.CreateCustomSetSlashCommand`, 17 valeurs dans l'ordre `TRANSMOG_SLOT_ORDER` — recopié pour ne pas en dépendre), `ns.GetCustomSets` (`C_TransmogCollection.GetCustomSets` / `GetCustomSetInfo`), `ns.ExportCustomSet(id)` (`GetCustomSetItemTransmogInfoList`), Titre : `ns.ExportTitle` (`GetCurrentTitle` + `GetTitleName` → « /settitle Nom », « /settitle » seul = « Aucun titre »), `ns.ApplyTitle(texte)` (nom exact parmi `IsTitleKnown`, `SetCurrentTitle` ; la commande `/settitle` de Blizzard, `SetTitleByName`, ne compare que le début). `ns.TryOnTransmog(texte)` (hors combat : `TransmogUtil.ParseCustomSetSlashCommand` + `DressUpItemTransmogInfoList(liste, true)`, comme la commande `/customset` ; `Blizzard_TransmogShared` est une dépendance de `Blizzard_FrameXML`, toujours chargé sur Retail), `ns.ExportCurrentAppearance(callback)` (modèle `DressUpModel` invisible, `SetUnit("player")` puis `GetItemTransmogInfoList` relu toutes les 0,1 s, 2 s au plus : chargement asynchrone). Synchro (bibliothèque partagée, pas de `P.IsSender`) : `PROFV:token:id=version,...` à chaque HELLO/HI (`P.RegisterPeerCallback`, fragmenté par `SendList`) ; `PROFREQ:token:id,...` pour les plus récents ; `PROF:token:id:N:version:fragments:genre:A|R:personnage:nom` puis `PROF:token:id:+:version:n°:morceau` (`SendProfile`, aussi aux clients connectés à chaque `Save` / `Delete`) ; réception dans `pending[id]`, appliquée par `Commit` quand tous les fragments sont là et si plus récente. Texte et nom encodés `Encode` / `Decode` (%XX pour `%`, `|`, retours à la ligne, octets non ASCII : messages ASCII, fragments coupables n'importe où) |
| `UI.lua` | Fenêtre `PolypodeProfilFrame` (`P.ToggleProfil`, `P.RefreshProfil` = `ns.Refresh`, `P.ui.profilFrame` / `profilList` / `profilEditor`), redimensionnable (taille dans `PolypodeProfilDB.window`, `LayoutPanels` : liste = 36 % de la largeur). Liste `P.CreateScrollList` (`BuildItems`, cadre titré « Personnages », pas de compteur de profils) : un en-tête par personnage `{ header, key, online, count, collapsed }` (le personnage joué + ceux qui ont des profils, ordre `P.SortedKeyItems(set, IsConnected)` = connectés en tête, rendu `P.FormatCharacter` précédé de « + » / « - », estompé à 0,55 s'il est déconnecté (`decorate`), infobulle `P.CharacterTooltip` ; clic gauche = replier / déplier, état dans `PolypodeProfilDB.collapsed[clé]`, clic droit = « Nouveau profil pour ce personnage » `NewForChar`), puis ses profils `{ id, profile }` « Genre · nom » (texte décalé par `decorate`, place de l'icône d'action `ActionButton` / `SetActionIcon` des genres de `ROW_ACTIONS` : `transmog` → `ns.TryOnTransmog`, atlas `lootroll-toast-icon-transmog-up/-highlight/-down`, repli icône d'objet ; `title` → `ns.ApplyTitle`, icône `INV_Scroll_03`) ; clic gauche = `Select` (confirmation `POLYPODE_PROFIL_DISCARD` si l'éditeur est modifié), clic droit = menu Dupliquer / Supprimer (`POLYPODE_PROFIL_DELETE`), infobulle `RowTooltip`. Règle « connecté » : `P.IsCharacterConnected` (Polypode 0.51.2, repli sur soi + `P.IsCharacterOnline`). Éditeur : `nameBox` (`InputBoxTemplate`), `kindButton` (menu radio `ShowKindMenu` → `ChangeKind` : changer de genre réinitialise l'éditeur, nouveau profil vide de ce genre pour le même personnage, via `ConfirmDiscard`), `charButton` (personnage `editChar`, menu radio `ShowCharMenu` du roster, compris dans `IsDirty`), `captureButton` (genres `capture` seulement, `Capture` : menu des dispositions / talents / menu « Apparence actuelle » + ensembles personnalisés → `ApplyCapture(texte, nom, perso)` : toujours un nouveau profil via `ConfirmDiscard` + `Load(nil, copie, perso)`, jamais le profil ouvert ; nom = disposition, talents, ensemble ou « Apparence actuelle (date) » ; talents et apparence actuelle sous le personnage joué), `textBox` (`ScrollingEditBoxTemplate`, `MinimalScrollBar` à visibilité gérée, `SetMaxLetters(0)`), boutons Nouveau / Enregistrer / Supprimer / Tout sélectionner (`HighlightText`). État chargé `loaded` → `IsDirty` ; en-tête `UpdateEditorHeader` (auteur, date, taille, « (non enregistré) »). `ns.Refresh` recharge le profil ouvert s'il a changé ailleurs et n'est pas modifié. Bouton `P.AddTitleButton` « Profils » (`P.ui.profilButton`), commande `/poly profil`. Messages à l'écran par `UIErrorsFrame` |

## Dépendances vers Polypode (API publique utilisée)

`P.AddTitleButton`, `P.RegisterSlashCommand`, `P.RegisterMessageHandler`, `P.RegisterPeerCallback`,
`P.WhisperOnline`, `P.MAX_MESSAGE_LENGTH`, `P.GetTeamToken`, `P.GetCharKey`, `P.GetDisplayName`,
`P.GetRoster`, `P.GetCharacter`, `P.db.roster`, `P.SortedKeyItems`, `P.FormatCharacter`, `P.CharacterTooltip`,
`P.IsCharacterConnected`, `P.IsCharacterOnline`,
`P.CreatePanel`, `P.CreateScrollList`, `P.SetListData`, `P.SkinFrame`, `P.SkinPanel`,
`P.SkinButton`, `P.SkinEditBox`, `P.SkinScrollBar`. Toute évolution de ces fonctions dans
Polypode doit rester compatible, ou ce fichier doit suivre.

## Pistes

- Import direct dans les addons qui exposent une API d'import, et dans le mode Édition
  (`C_EditMode.ConvertStringToLayoutInfo` + sauvegarde des dispositions : à vérifier, protégé ?).
- Recherche dans la liste.

## Après chaque modification

Mettre à jour `README.md` (et ce fichier si l'architecture change), commiter puis pousser sur
`origin` (https://github.com/Baktov/polypode-profil).
