# Polypode Profil

*English version: [README.en.md](README.en.md)*

Fenêtre **« Profils »** de [Polypode](https://github.com/Baktov/polypode), sous forme d'addon
séparé : une bibliothèque de **chaînes d'export** — disposition du **mode Édition** de WoW,
**talents**, profils d'addons (**EllesmereUI**, **ElvUI**, **Baganator**, **MySlots**, **Simple Addon Manager**...), **barres d'action** —
gardées une fois pour toutes et disponibles sur tous vos personnages, pour configurer
rapidement un nouveau personnage ou une nouvelle fenêtre.

Désactivé, Polypode fonctionne normalement, sans bouton « Profils » ni commande `/poly profil`.

> **Langues** : français, anglais, allemand, espagnol, italien et portugais du Brésil, selon la
> langue choisie dans Polypode (option « Langue / Language »). Les traductions ont été faites avec
> l'aide de Claude, l'IA d'Anthropic : les retours de joueurs dont c'est la langue maternelle sont
> les bienvenus ([issue GitHub](https://github.com/Baktov/polypode-profil/issues)).

---

## Installation

1. Installer d'abord **Polypode** (dépendance obligatoire).
2. Placer le dossier `Polypode_Profil` dans `World of Warcraft/_retail_/Interface/AddOns/`
   (et, pour **WoW Forever**, dans `World of Warcraft/_forever_/Interface/AddOns/`, par
   exemple par une jonction `mklink /J`).
3. Cocher « Polypode Profil » dans la liste des AddOns.

---

## Utilisation

Le bouton **Profils** (barre de titre de la fenêtre Polypode) ou `/poly profil` ouvre la fenêtre
(**double-clic** sur sa barre de titre : retour à la taille par défaut).

- **À gauche**, les profils rangés **par saison, puis sous leur personnage**. La saison d'un
  profil est celle de son **dernier enregistrement** (« Midnight, saison 2 » ; « Saison inconnue »
  pour les sauvegardes antérieures à la 1.9.0 et sur WoW Forever) ; la saison en cours vient en
  tête, puis les autres de la plus récente à la plus ancienne. Un même personnage apparaît dans
  chaque saison où il a des profils. Il est affiché comme dans « Personnages disponibles » de
  Polypode : nom en couleur de classe, classe, niveau, « (vous) », connectés en tête,
  déconnectés estompés, et la même infobulle (connecté ou non, équipes). Votre personnage
  actuel apparaît toujours dans la saison en cours, même sans profil.
  - En-tête de saison : clic gauche = replier / déplier la saison (état gardé).
  - En-tête de personnage : clic gauche = replier / déplier ses profils de cette saison (état
    gardé) ; clic droit = menu **Nouveau** pour ce personnage (profil enregistré dans la saison en cours).
  - Bouton **Tout replier** (à droite du titre « Personnages ») : replie toutes les saisons
    pour ne voir que leurs noms ; il devient **Tout déplier** quand tout est replié.
  - Profil (genre puis nom, par ex. « Talents · Arcane raid ») : clic gauche = ouvrir dans
    l'éditeur (en lecture seule) ; clic droit = dupliquer (comme le bouton **Dupliquer**) ou supprimer ; au survol : genre, personnage, date,
    **saison et version du jeu** de la sauvegarde (par exemple « Midnight, saison 2 (12.1.0) » ;
    « inconnu » pour les sauvegardes antérieures à la 1.9.0) et taille.
  - Profil de **transmogrification** : une petite icône devant son nom **ouvre la cabine
    d'essayage** sur la tenue (comme la chaîne collée dans la discussion ; hors combat). **Chez le
    transmogrificateur** (fenêtre ouverte), la même icône **charge la tenue** dans sa fenêtre :
    elle passe par un ensemble personnalisé du nom du profil (repris s'il existe déjà avec la même
    tenue, sinon créé ; il en faut une place libre), puis le bouton **Appliquer** de Blizzard la
    valide et en affiche le coût.
  - Profil de **titre** : une petite icône devant son nom fait **porter ce titre** au
    personnage joué (s'il le connaît ; « Aucun titre » retire le titre).
  - Profil de **macro** : l'icône devant son nom est **celle de la macro** ; un clic l'**ajoute
    aux macros** du personnage joué (générales ou propres au personnage, comme à la capture),
    hors combat. Si une macro du même nom existe déjà, une confirmation est demandée puis son
    icône et son texte sont remplacés. L'infobulle du profil montre l'icône, le type et le texte.
  - Profil de **barres d'action** : une petite icône les **applique** au personnage joué, après
    confirmation (avertissement si le profil vient d'une autre classe) ; voir « Barres d'action »
    plus bas.
  - Profil d'**ensemble d'équipement** : une petite icône devant son nom **ajoute l'ensemble
    aux ensembles d'équipement** du personnage joué (voir plus bas) ; l'infobulle du profil
    indique sa spécialisation et son nombre de pièces.
  - Profil de **liste des addons** : une petite icône l'**applique** au personnage joué (après
    confirmation), puis propose de **recharger l'interface** (bouton « Recharger » ou touche
    Entrée ; sur WoW Forever, taper /reload).
  - Profil de **Simple Addon Manager** : une petite icône l'**importe** dans Simple Addon
    Manager (après confirmation), puis ouvre sa propre boîte « charger le profil et recharger ».
  - Profil **ElvUI** : une petite icône (celle d'ElvUI) l'**importe** dans ElvUI, après
    confirmation. Un profil y devient un **nouveau profil** (son nom, suffixé « (2) »... s'il est
    pris), activé ; des réglages du personnage (*private*), du compte (*global*) ou des filtres
    d'auras **remplacent** ceux en place (ElvUI propose de recharger pour ceux du personnage).
  - Profil **EllesmereUI** : une petite icône (celle d'EllesmereUI) ouvre la **page d'import
    d'EllesmereUI** sur la chaîne : un profil y arrive sous un **nouveau nom** ; un **export
    complet** remplace les réglages du compte (EllesmereUI demande confirmation et recharge).
  - Profils **Baganator**, **Chattynator**, **Platynator** : une petite icône (celle de l'addon)
    l'**importe** dans l'addon (par sa fonction d'import), après confirmation : un profil y devient
    un **nouveau profil** (le nom du profil sans « Addon — », suffixé « (2) »... s'il est pris),
    activé ; un autre contenu (catégories de Baganator, style de Platynator) y est importé.
  - Profil **Details!** : une petite icône l'**importe** dans Details! comme **nouveau profil**
    (nom libre), activé.
  - Profil **TalentLoadoutManager** : une petite icône **ajoute** la configuration de talents à
    TalentLoadoutManager, **sans l'appliquer** (on la charge ensuite depuis TLM) ; la fenêtre des
    talents de Blizzard n'est pas touchée, donc pas de risque de blocage (contrairement à l'import
    bêta des talents).
  - Profils d'**options de WoW**, de **raccourcis clavier** et de **fenêtres de discussion** :
    une petite icône devant leur nom les **applique** au personnage joué, après confirmation
    (ils remplacent la configuration actuelle) ; un compte rendu s'affiche.
- **À droite**, l'éditeur. En-tête : à gauche le **genre** et le profil ouvert (ou « Nouveau
  profil »), à droite son **personnage** ; ni l'un ni l'autre ne se modifie. Le genre est choisi
  dans le menu **Nouveau** (voir « Créer un profil ») ; le personnage est celui sous lequel le
  profil a été créé, ou, pour un nouveau profil, le personnage joué (celui de l'en-tête après un
  clic droit sur un personnage de la liste). Dessous : le nom et la chaîne elle-même, dans une
  zone qui défile.
  - Un **profil enregistré s'ouvre en lecture seule** (« lecture seule » dans l'en-tête) : le nom
    s'affiche en simple texte, genre et chaîne ne se modifient pas (la chaîne reste sélectionnable pour Ctrl+C) et
    **Enregistrer** est grisé. Seul un nouveau profil s'enregistre.
  - **Dupliquer** (sous la liste des personnages, ou clic droit sur le profil) ouvre une copie
    du profil pour votre **personnage actuel**, affiché en haut à droite (nom suivi de
    « (copie) » si le profil était déjà le sien) : **Enregistrer** la garde sous lui. Pour
    changer un profil : le dupliquer, modifier la copie, l'enregistrer, puis supprimer l'ancien.

### Supprimer tous les profils d'une saison

Le bouton **Supprimer une saison** (sous la liste des personnages, à droite de « Supprimer ») liste les
saisons pendant lesquelles vos profils ont été enregistrés (avec leur nombre, « Saison inconnue »
pour les sauvegardes antérieures à la 1.9.0 et celles de WoW Forever). En choisir une supprime, après confirmation, tous
les profils de cette saison, sur tous vos clients.

### Créer un profil

Le bouton **Nouveau** (en bas de l'éditeur, ou clic droit sur un personnage de la liste) ouvre le
menu des genres, en trois groupes. Dans le menu comme dans la liste des profils, chaque genre a
une couleur, et les genres sont triés par couleur : **bleu** pour les réglages essentiels de WoW
(Barres d'action, Options de WoW, Raccourcis clavier, Mode Édition), **vert** pour les autres
réglages du client (Transmogrification, Titre, Macro, Ensemble d'équipement, Fenêtres de
discussion, Liste des addons, Talents), **violet** pour les addons, **blanc** pour « Autre » :

1. **Capturer et appliquer en jeu** : Transmogrification, Titre, Macro, Ensemble d'équipement,
   Barres d'action, Options de WoW, Raccourcis clavier, Fenêtres de discussion, Liste des addons,
   Simple Addon Manager, EllesmereUI, ElvUI, Baganator, Chattynator, Platynator, Details!,
   TalentLoadoutManager. La chaîne est relevée en jeu ; dans la liste, l'icône devant le profil
   l'applique (la transmogrification s'essaie dans la cabine d'essayage, ou s'applique chez le
   transmogrificateur).
2. **Capturer, puis copier la chaîne** : Mode Édition, Talents. La chaîne est relevée en jeu, puis
   copiée (Tout sélectionner, Ctrl+C) dans la fenêtre d'import du jeu. **Bêta** : l'icône du
   profil ouvre cette fenêtre d'import déjà remplie (chaîne et nom, la partie après le dernier
   « — ») ; il reste à cliquer sur « Importer ». Le mode Édition, ou la fenêtre des talents (N),
   doit d'abord être ouvert par vous (l'addon ne les ouvre jamais, pour ne pas risquer de les
   « souiller » et de faire bloquer des actions par le jeu) ; un **/reload** ensuite est conseillé.
3. **Coller une chaîne (import / export)** : MySlots, Autre. La chaîne est collée depuis le
   bouton **Exporter** de l'addon, puis recopiée dans son import (MySlots n'offre ni export ni
   import utilisables par un autre addon).

Baganator, Chattynator et Platynator (même auteur) n'ont pas d'export utilisable par un autre
addon. Leur sous-menu propose donc **Capturer (bêta)** : leurs profils (l'actif est signalé),
exportés en recopiant la façon de faire de leur bouton « Exporter » ; si une mise à jour de l'addon
change ce format, la chaîne capturée pourrait ne plus s'importer. **Coller une chaîne (fiable)**
reste le moyen sûr (bouton « Exporter » de l'addon : profil, catégories ou style). Dans les deux
cas, l'icône de la liste l'**importe**.

Details! (son export de profil) et TalentLoadoutManager (les configurations de la spécialisation en
cours, chaîne de talents de Blizzard) se capturent par leurs propres fonctions.

Le nom d'un profil d'addon (EllesmereUI, ElvUI, Baganator, MySlots) commence par celui de l'addon
(« ElvUI — … », proposé à compléter quand on colle une chaîne, ajouté à l'enregistrement s'il
manque).

Un genre des groupes 1 et 2 ouvre un sous-menu : ses captures (dispositions, macros,
ensembles...), puis **Coller une chaîne** (une chaîne venue d'ailleurs, par exemple des talents
trouvés sur un site) ; un menu trop long (macros...) défile, limité à la moitié de l'écran. Un genre du groupe 3 ouvre directement un profil vide. Dans tous les cas,
l'éditeur reçoit un **nouveau profil** de ce genre : donner un nom (ou garder celui proposé),
coller la chaîne si besoin (Ctrl+V), puis **Enregistrer**.

Les captures relèvent la chaîne directement en jeu, sans passer par le presse-papiers :

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
- ElvUI : un menu liste ses **profils** (l'actif est signalé), puis les **réglages du personnage**
  (*private*, rangés sous le personnage joué), les **réglages du compte** (*global*) et les
  **filtres d'auras**. Chaque chaîne est celle du bouton « Exporter » d'ElvUI (par sa fonction
  d'export) ; l'infobulle du profil en rappelle le contenu.
- EllesmereUI : un menu liste ses **profils** (l'actif est signalé), puis l'**export complet**
  (réglages du compte et profil actif, comme son onglet « Full Export »). L'infobulle du profil
  indique s'il s'agit d'un profil ou d'un export complet.
- Titre : le titre porté par le personnage joué, en chaîne Blizzard `/settitle Nom` (collée
  dans la discussion, elle change de titre ; sans nom, elle le retire). Attention, la commande
  de Blizzard prend le premier titre connu qui *commence* par ce nom ; l'icône de la liste
  cherche le nom exact.
- Barres d'action : les 180 emplacements des barres 1 à 15 du personnage joué (barres de
  forme / posture comprises) et le texte des macros qui y sont posées ; rangé sous le personnage
  joué, nommé d'après la spécialisation.
- Macro : menu de vos macros (générales, puis celles du personnage joué, avec leur icône) ; le
  profil garde le nom, l'icône, le type et le texte de la macro :
  `Polypode macro v1`, `nom=`, `icone=`, `type=generale|personnage`, `---`, puis le texte tel
  quel (« | » et « % » écrits `%7C` et `%25`). Une macro propre au personnage est rangée sous
  le personnage joué.

Chaque capture ouvre un **nouveau profil** (le profil ouvert n'est jamais écrasé), nommé
d'après la disposition, la configuration de talents ou l'ensemble personnalisé ; l'apparence
actuelle est nommée « Apparence actuelle (date heure) ». Vous pouvez donc garder plusieurs
tenues, dispositions ou configurations côte à côte. Talents et apparence actuelle sont rangés
sous le personnage joué. Il reste à **Enregistrer** (le nom peut être modifié avant).

Le genre d'un profil ne change plus après coup : pour un autre genre, faire un autre **Nouveau**.

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

### Barres d'action

Le genre **Barres d'action** applique les barres sans l'addon MySlot, mais en reprend moins
(ni raccourcis, ni familier, ni click bindings, ni Cooldown Manager) : le genre **MySlots**
reste là pour garder les chaînes de MySlot telles quelles. Le texte est propre à Polypode Profil (`Polypode barres v1`, une ligne
par emplacement : `12=spell:133:Boule de feu`, `13=macro:Ma macro`, `14=item:6948:...`, puis
une ligne `macro=` par macro posée). Sont gérés : sorts (sort de base, l'amélioration par un
talent suit), objets, macros, menus de sorts (portails...), montures (dont la monture favorite
aléatoire), mascottes, ensembles d'équipement et tenues de transmogrification.

Appliqué (icône de la liste, hors combat), le profil **repose chaque action** sur son
emplacement et **vide les autres**. Les macros sont retrouvées par leur nom, sinon créées
d'après le profil (s'il reste de la place). Un sort non appris, un objet absent ou une monture
non possédée laisse l'emplacement vide ; le compte rendu les compte et en cite quelques-uns.
Ne sont pas repris : barre du familier, lancement de sorts au clic, gestionnaire de temps de
recharge.

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

---

## Langues (Languages)

Polypode Profil s'affiche dans la langue choisie dans Polypode (option « Langue / Language », `/poly langue`),
par défaut celle du jeu : français, anglais, allemand, espagnol, italien ou portugais du Brésil
(anglais pour une autre langue). Nécessite Polypode 2.9 pour choisir la langue ; avec un Polypode plus
ancien, le module reste en français. La commande `/poly profil` garde son nom.

*Polypode Profil follows the language chosen in Polypode ("Langue / Language" option, `/poly language`), by
default the game's: French, English, German, Spanish, Italian or Brazilian Portuguese (English for any
other language).*

---

## Version

`3.7.0` : couleur par famille de genre (bleu : essentiels de WoW, vert : autres réglages du client, violet : addons, blanc : autre), dans le menu Nouveau et dans la liste des profils, triée par couleur.
`3.6.0` : Chattynator et Platynator (capture bêta, import), Details! et TalentLoadoutManager (capture et import par leurs fonctions) ; Baganator, Chattynator et Platynator partagent le même code.
`3.5.0` : mode Édition et talents (bêta) : l'icône ouvre la fenêtre d'import de Blizzard déjà remplie (mode Édition ou fenêtre des talents ouverts par le joueur), « Importer » reste au joueur.
`3.4.0` : Baganator : « Capturer (bêta) » de ses profils (export recopié de Baganator) et « Coller une chaîne (fiable) ».
`3.3.0` : Baganator importé par sa fonction d'import (nouveau profil au nom libre, ou catégories) ; sa chaîne reste collée.
`3.2.0` : ElvUI et EllesmereUI capturés et importés par leurs propres fonctions : profils, réglages du personnage, du compte et filtres d'ElvUI, export complet d'EllesmereUI ; l'import crée un nouveau profil dans l'addon.
`3.1.2` : menu Nouveau : Barres d'action, Options de WoW, Raccourcis clavier et Mode Édition en bleu foncé.
`3.1.1` : menu Nouveau et sous-menus (macros, options...) limités à la moitié de l'écran, avec ascenseur.
`3.1.0` : transmogrification appliquée chez le transmogrificateur (même icône, par un ensemble personnalisé, validée par « Appliquer » de Blizzard) ; nom d'un profil enregistré affiché en simple texte ; profils EllesmereUI, ElvUI, Baganator et MySlots nommés « Addon — nom ».
`3.0.0` : menu **Nouveau** en trois groupes (capturer et appliquer, capturer puis copier, coller une chaîne), avec les captures de chaque genre et « Coller une chaîne » ; liste déroulante du genre et bouton Capturer retirés, genre affiché dans l'en-tête ; clic droit sur un personnage = même menu.
`2.7.0` : boutons Dupliquer, Supprimer et Supprimer une saison sous la liste des personnages ; fenêtre revenue à 900 par défaut (880 au minimum).
`2.6.0` : profil enregistré ouvert en lecture seule ; bouton **Dupliquer** (copie pour le personnage actuel, à enregistrer), aussi au clic droit ; fenêtre plus large (1100 par défaut, 1050 au minimum).
`2.5.0` : personnage du profil affiché à droite de l'en-tête de l'éditeur, non modifiable ; ligne « Personnage » retirée.
`2.4.0` : liste des profils rangée par saison (celle du dernier enregistrement), puis par personnage ; saisons repliables.
`2.3.0` : double-clic sur la barre de titre : retour à la taille par défaut (Polypode 2.12).
`2.2.0` : Polypode Profil en anglais, allemand, espagnol, italien et portugais du Brésil, selon la langue choisie dans Polypode (Profiles, Profile, Perfiles, Profili, Perfis) ; les chaînes d'export gardent leur format (en-têtes et lignes en français), lisibles quelle que soit la langue. *Translated into English, German, Spanish, Italian and Brazilian Portuguese.*
`2.1.1` : genre « MySlots » rétabli (ses profils ne sont plus supprimés) : « Barres d'action » en reprend moins que MySlot.
`2.1.0` : genre « Barres d'action » (capture des barres 1 à 15 et de leurs macros, application par l'icône de la liste) ; genre « MySlots » retiré, ses profils supprimés.
`2.0.0` : première version publique (release GitHub v2.0.0). Nécessite Polypode 2.0.0.
`1.11.1` : notions de clic en bleu dans les infobulles (Polypode 0.60).
`1.11.0` : genre « Macro » : capture d'une macro (nom, icône, texte) et icône d'ajout aux macros.
`1.10.2` : profils supprimés avec leur personnage.
`1.10.1` : infobulle d'un profil : intitulés en bleu clair.
`1.10.0` : bouton « Supprimer une saison ».
`1.9.1` : bouton « Tout replier / Tout déplier » du cadre Personnages.
`1.9.0` : saison et version du jeu de chaque sauvegarde, dans l'infobulle.
`1.8.2` : listes déroulantes genre / personnage habillées par le skin.
`1.8.1` : genre et personnage en listes déroulantes Blizzard.
`1.8.0` : liste des addons et profils de Simple Addon Manager.
`1.7.0` : genres options de WoW, raccourcis clavier et fenêtres de discussion.
`1.6.0` : genre « Simple Addon Manager » ; libellé court dès que le genre ne tient pas.
`1.5.1` : bouton de genre : « Ensemble » quand « Capturer » est affiché.
`1.5.0` : genre « Ensemble d'équipement » : capture avec spécialisation et recréation.
`1.4.0` : genre « Titre » : capture et icône pour porter le titre.
`1.3.0` : icône « essayer » devant les profils de transmogrification.
`1.2.1` : chaque capture ouvre un nouveau profil nommé.
`1.2.0` : genre « Transmogrification » avec capture.
`1.1.2` : plus de compteur de profils en haut de la liste.
`1.1.1` : changer de genre réinitialise l'éditeur.
`1.1.0` : profils rangés sous leur personnage.
`1.0.0` : première version : bibliothèque de chaînes d'export.
