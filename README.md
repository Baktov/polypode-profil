# Polypode Profil

Fenêtre **« Profils »** de [Polypode](https://github.com/Baktov/polypode), sous forme d'addon
séparé : une bibliothèque de **chaînes d'export** — disposition du **mode Édition** de WoW,
**talents**, profils d'addons (**EllesmereUI**, **ElvUI**, **Baganator**, **MySlots**...) —
gardées une fois pour toutes et disponibles sur tous vos personnages, pour configurer
rapidement un nouveau personnage ou une nouvelle fenêtre.

Désactivé, Polypode fonctionne normalement, sans bouton « Profils » ni commande `/poly profil`.

---

## Installation

1. Installer d'abord **Polypode** (dépendance obligatoire).
2. Placer le dossier `Polypode_Profil` dans `World of Warcraft/_retail_/Interface/AddOns/`
   (et, pour **WoW Forever**, dans `World of Warcraft/_classic_beta_/Interface/AddOns/`, par
   exemple par une jonction `mklink /J`).
3. Cocher « Polypode Profil » dans la liste des AddOns.

---

## Utilisation

Le bouton **Profils** (barre de titre de la fenêtre Polypode) ou `/poly profil` ouvre la fenêtre.

- **À gauche**, les profils rangés **sous leur personnage**, affiché comme dans « Personnages
  disponibles » de Polypode : nom en couleur de classe, classe, niveau, « (vous) », connectés en
  tête, déconnectés estompés, et la même infobulle (connecté ou non, équipes). Votre personnage
  actuel apparaît toujours, même sans profil.
  - En-tête de personnage : clic gauche = replier / déplier ses profils (état gardé) ; clic
    droit = nouveau profil pour ce personnage.
  - Profil (genre puis nom, par ex. « Talents · Arcane raid ») : clic gauche = ouvrir dans
    l'éditeur ; clic droit = dupliquer ou supprimer ; au survol : genre, personnage, date et
    taille.
- **À droite**, l'éditeur : nom, genre (bouton-menu), **personnage** (bouton-menu : les
  personnages de votre roster, connectés en tête ; par défaut le personnage joué) et la chaîne
  elle-même, dans une zone qui défile. Changer le personnage range le profil ailleurs dans la
  liste. **Changer le genre réinitialise l'éditeur** : nom et chaîne sont effacés pour un
  nouveau profil de ce genre (même personnage) ; le profil qui était ouvert n'est pas modifié
  (confirmation demandée s'il avait des modifications non enregistrées).

### Enregistrer une chaîne

1. Dans l'addon (ou le mode Édition, ou les talents), utiliser son bouton **Exporter** et copier
   la chaîne (Ctrl+C).
2. Dans « Profils » : **Nouveau**, coller la chaîne (Ctrl+V) dans la zone de texte, donner un nom
   et choisir le genre.
3. **Enregistrer**.

**Capturer** (genres « Mode Édition », « Talents » et « Transmogrification ») relève la chaîne directement en jeu, sans
passer par le presse-papiers :

- Mode Édition : un menu liste vos dispositions (la disposition active est signalée) ;
- Talents : la configuration de talents active. La fenêtre des talents (N) doit avoir été
  ouverte au moins une fois dans la session (l'addon ne la charge pas lui-même, pour ne pas
  risquer de bloquer ensuite l'application des talents).

- Transmogrification : un menu propose **l'apparence actuelle** du personnage joué et chacun de
  vos **ensembles personnalisés**. La chaîne est celle de Blizzard (`/customset v1 ...`, comme
  « Copier dans le presse-papiers » de la cabine d'essayage) : pour s'en resservir, la coller
  dans la **discussion** et valider, la cabine d'essayage s'ouvre avec la tenue (à enregistrer
  ou appliquer ensuite chez le transmogrificateur).

La chaîne capturée remplace le texte de l'éditeur ; le nom est proposé s'il est vide. Il reste à
**Enregistrer**.

### Réutiliser une chaîne

Ouvrir le profil, **Tout sélectionner**, Ctrl+C, puis Ctrl+V dans la fenêtre d'import de l'addon
(mode Édition : « Importer » dans le menu des dispositions ; talents : « Importer » dans le menu
des configurations). Un addon WoW ne peut ni lire ni écrire le presse-papiers : la copie passe
toujours par Ctrl+C / Ctrl+V.

Une modification non enregistrée est signalée « (non enregistré) » dans l'en-tête de l'éditeur ;
ouvrir un autre profil ou en créer un nouveau demande alors confirmation.

---

## Partage entre personnages et clients

Les profils sont gardés dans le fichier de **compte** (`PolypodeProfilDB`) : communs à tous les
personnages. Ils sont aussi **échangés entre vos clients connectés** (multibox), comme les
équipes de Polypode : à chaque connexion, chaque client annonce la version de ses profils et
récupère ceux qui sont plus récents ailleurs ; un profil enregistré ou supprimé part aussitôt
aux clients connectés. La version la plus récente l'emporte ; une suppression est propagée elle
aussi. Un profil ouvert dans l'éditeur et modifié ailleurs est rechargé, sauf s'il est en cours
d'édition.

Les longues chaînes (profils complets d'ElvUI ou d'EllesmereUI) passent en de nombreux messages :
leur arrivée sur les autres clients peut prendre quelques secondes.

Cet addon n'a pas d'options.

---

## Pistes

- Import direct (sans Ctrl+V) dans les addons qui l'exposent par une API, et dans le mode
  Édition.
- Recherche dans la liste, si elle devient longue.
