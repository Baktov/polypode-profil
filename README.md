# Polypode Profil

Fenêtre **« Profils »** de [Polypode](https://github.com/Baktov/polypode), sous forme d'addon
séparé : une bibliothèque de **chaînes d'export** — disposition du **mode Édition** de WoW,
**talents**, profils d'addons (**EllesmereUI**, **ElvUI**, **Baganator**, **MySlots**, **Simple Addon Manager**...) —
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
  - Bouton **Tout replier** (à droite du titre « Personnages ») : replie tous les personnages
    pour ne voir que leurs noms ; il devient **Tout déplier** quand tout est replié.
  - Profil (genre puis nom, par ex. « Talents · Arcane raid ») : clic gauche = ouvrir dans
    l'éditeur ; clic droit = dupliquer ou supprimer ; au survol : genre, personnage, date,
    **saison et version du jeu** de la sauvegarde (par exemple « Midnight, saison 2 (12.1.0) » ;
    « inconnu » pour les sauvegardes antérieures à la 1.9.0) et taille.
  - Profil de **transmogrification** : une petite icône devant son nom **ouvre la cabine
    d'essayage** sur la tenue (comme la chaîne collée dans la discussion ; hors combat).
  - Profil de **titre** : une petite icône devant son nom fait **porter ce titre** au
    personnage joué (s'il le connaît ; « Aucun titre » retire le titre).
  - Profil d'**ensemble d'équipement** : une petite icône devant son nom **ajoute l'ensemble
    aux ensembles d'équipement** du personnage joué (voir plus bas) ; l'infobulle du profil
    indique sa spécialisation et son nombre de pièces.
  - Profil de **liste des addons** : une petite icône l'**applique** au personnage joué (après
    confirmation), puis propose de **recharger l'interface** (bouton « Recharger » ou touche
    Entrée ; sur WoW Forever, taper /reload).
  - Profil de **Simple Addon Manager** : une petite icône l'**importe** dans Simple Addon
    Manager (après confirmation), puis ouvre sa propre boîte « charger le profil et recharger ».
  - Profils d'**options de WoW**, de **raccourcis clavier** et de **fenêtres de discussion** :
    une petite icône devant leur nom les **applique** au personnage joué, après confirmation
    (ils remplacent la configuration actuelle) ; un compte rendu s'affiche.
- **À droite**, l'éditeur : nom, genre (liste déroulante), **personnage** (liste déroulante : les
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

**Capturer** (genres « Mode Édition », « Talents », « Transmogrification », « Titre », « Ensemble d'équipement », « Options de WoW », « Raccourcis clavier », « Fenêtres de discussion », « Liste des addons » et « Simple Addon Manager ») relève la chaîne directement en jeu, sans
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

- Ensemble d'équipement : un menu liste les ensembles du gestionnaire d'équipement du
  personnage joué (avec leur spécialisation). Le profil garde, pour chaque emplacement, la pièce
  exacte (enchantement, gemmes, améliorations), les emplacements ignorés et la spécialisation.
  Blizzard n'a pas de chaîne d'export pour les ensembles : le texte est propre à Polypode Profil
  (il n'est pas à coller dans la discussion).
- Options de WoW : un menu propose chaque catégorie du panneau Options (Graphismes, Audio,
  Interface, Combat...) ou toutes. Seuls les réglages qui sont des variables du jeu (CVars) sont
  gardés ; les réglages calculés et ceux des addons sont écartés. Graphismes et audio sont
  propres à chaque PC : c'est là que le profil sert le plus.
- Raccourcis clavier : tous les raccourcis du jeu de raccourcis actif (compte ou personnage).
  Appliqués, ils **remplacent** les raccourcis actuels (les touches liées autrement sont
  libérées) ; les commandes d'un addon absent sont comptées « inconnues ».
- Fenêtres de discussion : fenêtres ouvertes (nom, police, couleur, transparence, verrouillage,
  ancrage, position si détachée), types de messages et canaux de chacune, couleurs des types
  de messages et réglages de la discussion (style, chuchotements, horodatage...). Appliqué, le
  profil ferme les fenêtres en trop et ouvre les manquantes ; la fenêtre principale reste placée
  par le mode Édition. Un **/reload** est conseillé ensuite.
- Liste des addons : chaque addon installé, activé (`+`) ou désactivé (`-`) pour le personnage
  joué. Appliquée, elle active / désactive les addons de la liste pour le personnage joué ;
  ceux qui ne sont pas dans la liste ne changent pas, ceux absents de ce PC sont comptés, et
  Polypode et Polypode Profil ne sont jamais désactivés. Effet au rechargement.
- Simple Addon Manager : un menu liste ses profils ; chacun est capturé par l'export de Simple
  Addon Manager lui-même (la chaîne de son bouton « Exporter », profils dépendants compris).
  « Tous les profils » les enregistre tous d'un coup, un profil Polypode chacun. Simple Addon
  Manager doit être chargé.
- Titre : le titre porté par le personnage joué, en chaîne Blizzard `/settitle Nom` (collée
  dans la discussion, elle change de titre ; sans nom, elle le retire). Attention, la commande
  de Blizzard prend le premier titre connu qui *commence* par ce nom ; l'icône de la liste
  cherche le nom exact.

Chaque capture ouvre un **nouveau profil** (le profil ouvert n'est jamais écrasé), nommé
d'après la disposition, la configuration de talents ou l'ensemble personnalisé ; l'apparence
actuelle est nommée « Apparence actuelle (date heure) ». Vous pouvez donc garder plusieurs
tenues, dispositions ou configurations côte à côte. Talents et apparence actuelle sont rangés
sous le personnage joué. Il reste à **Enregistrer** (le nom peut être modifié avant).

### Réutiliser une chaîne

Ouvrir le profil, **Tout sélectionner**, Ctrl+C, puis Ctrl+V dans la fenêtre d'import de l'addon
(mode Édition : « Importer » dans le menu des dispositions ; talents : « Importer » dans le menu
des configurations). Un addon WoW ne peut ni lire ni écrire le presse-papiers : la copie passe
toujours par Ctrl+C / Ctrl+V.

Une modification non enregistrée est signalée « (non enregistré) » dans l'en-tête de l'éditeur ;
ouvrir un autre profil ou en créer un nouveau demande alors confirmation.

---

### Recréer un ensemble d'équipement

L'icône devant un profil d'ensemble le crée chez le **personnage joué**, sous le **nom du
profil**. WoW n'enregistre un ensemble qu'à partir de ce que le personnage **porte** ; l'addon :

1. vérifie (hors combat) que chaque pièce est dans les sacs ou déjà équipée, qu'aucun ensemble
   ne porte déjà ce nom et que le maximum d'ensembles n'est pas atteint — sinon rien ne bouge ;
2. équipe les pièces une à une (la pièce exacte si elle existe, sinon le même objet, par exemple
   amélioré depuis) ;
3. crée l'ensemble (mêmes emplacements ignorés, même icône) et lui associe la spécialisation
   (s'il s'agit de la même classe) ;
4. **remet la tenue portée avant**.

Limites : les pièces en banque ne sont pas prises ; les emplacements que l'ensemble laissait
**vides** sont ignorés par l'ensemble recréé ; un échange d'arme à deux mains / arme + main
gauche peut empêcher de remettre exactement la tenue d'avant (un message le signale).

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
