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
| `Polypode_Profil.toc` | `## Dependencies: Polypode`, SavedVariables de compte `PolypodeProfilDB` (`profiles`, `window`) ; ordre `Profil → UI` |
| `Profil.lua` | Genres `ns.KINDS` (`{ key, label, capture }`, ordre d'affichage ; genre inconnu → `other` par `ns.NormalizeKind`), `ns.KindLabel`, `ns.KindOrder`, `ns.CanCapture`. Bibliothèque `PolypodeProfilDB.profiles[id] = { name, kind, text, author, updated, removed }` (id hexadécimal heure serveur + hasard ; `updated` = version `NextVersion`, strictement croissante ; suppression = pierre tombale `{ removed, updated }`) : `ns.Get`, `ns.GetProfiles` (actifs, triés genre puis nom), `ns.Save(id|nil, nom, genre, texte)` (texte vide refusé, nom vide = libellé du genre), `ns.Delete`. Capture : `ns.GetEditModeLayouts` (`EditModeManagerFrame.layoutInfo.layouts`, préréglages compris, `activeLayout`) + `ns.ExportEditModeLayout` (`C_EditMode.ConvertLayoutInfoToString`, comme « Copier dans le presse-papiers ») ; `ns.ExportTalents` (`PlayerSpellsFrame.TalentsFrame:GetLoadoutExportString()` sous `pcall`, nom « Talents <spé> — <configuration> ») — **ne jamais charger `Blizzard_PlayerSpells` depuis l'addon** (taint : l'application des talents pourrait être bloquée) ; fenêtre jamais ouverte → message. Synchro (bibliothèque partagée, pas de `P.IsSender`) : `PROFV:token:id=version,...` à chaque HELLO/HI (`P.RegisterPeerCallback`, fragmenté par `SendList`) ; `PROFREQ:token:id,...` pour les plus récents ; `PROF:token:id:N:version:fragments:genre:A|R:auteur:nom` puis `PROF:token:id:+:version:n°:morceau` (`SendProfile`, aussi aux clients connectés à chaque `Save` / `Delete`) ; réception dans `pending[id]`, appliquée par `Commit` quand tous les fragments sont là et si plus récente. Texte et nom encodés `Encode` / `Decode` (%XX pour `%`, `|`, retours à la ligne, octets non ASCII : messages ASCII, fragments coupables n'importe où) |
| `UI.lua` | Fenêtre `PolypodeProfilFrame` (`P.ToggleProfil`, `P.RefreshProfil` = `ns.Refresh`, `P.ui.profilFrame` / `profilList` / `profilEditor`), redimensionnable (taille dans `PolypodeProfilDB.window`, `LayoutPanels` : liste = 36 % de la largeur). Liste `P.CreateScrollList` : en-têtes de genre `{ header, kind, count }` puis profils `{ id, profile }` ; clic gauche = `Select` (confirmation `POLYPODE_PROFIL_DISCARD` si l'éditeur est modifié), clic droit = menu Dupliquer / Supprimer (`POLYPODE_PROFIL_DELETE`), infobulle `RowTooltip`. Éditeur : `nameBox` (`InputBoxTemplate`), `kindButton` (menu radio `ShowKindMenu`), `captureButton` (genres `capture` seulement, `Capture` : menu des dispositions / talents → `ApplyCapture`), `textBox` (`ScrollingEditBoxTemplate`, `MinimalScrollBar` à visibilité gérée, `SetMaxLetters(0)`), boutons Nouveau / Enregistrer / Supprimer / Tout sélectionner (`HighlightText`). État chargé `loaded` → `IsDirty` ; en-tête `UpdateEditorHeader` (auteur, date, taille, « (non enregistré) »). `ns.Refresh` recharge le profil ouvert s'il a changé ailleurs et n'est pas modifié. Bouton `P.AddTitleButton` « Profils » (`P.ui.profilButton`), commande `/poly profil`. Messages à l'écran par `UIErrorsFrame` |

## Dépendances vers Polypode (API publique utilisée)

`P.AddTitleButton`, `P.RegisterSlashCommand`, `P.RegisterMessageHandler`, `P.RegisterPeerCallback`,
`P.WhisperOnline`, `P.MAX_MESSAGE_LENGTH`, `P.GetTeamToken`, `P.GetCharKey`, `P.GetDisplayName`,
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
