# Radio Moustache — Spécification

Décisions validées le 27/09/2026 à l'issue du questionnaire (QCM), direction artistique revue le 28/09/2026.
Ce document est la source de vérité du projet. Toute nouvelle décision y est consignée.

---

## 1. Vision

Application macOS **native** (SwiftUI, pas de webapp ni d'Electron) de diffusion et d'animation audio en direct,
pensée pour les **soirées et événements en salle**. Direction artistique : **radio pirate des années 60,
« Radio Moustache, émetteur clandestin, 1967 »**, en « full full vintage » (voir §9).

## 2. Plateforme et projet

| Sujet | Décision |
|---|---|
| macOS minimum | **14.2 Sonoma** (14.2 : première version avec la capture audio d'app, *Process Tap*) |
| Langage | Swift 6 (mode langage 6, concurrence stricte), SwiftUI, Observation (`@Observable`) |
| Dépendances | **100 % frameworks Apple**, aucun Swift Package tiers |
| Projet | **XcodeGen** (`project.yml`) ; le `.xcodeproj` est généré et non versionné |
| Distribution | Usage perso / petit groupe : pas d'App Sandbox, signature locale ou Apple ID |
| Bundle ID | `com.skemedia.RadioMoustache` (modifiable dans `project.yml`) |
| Langues | Interface en français (String Catalog, prête à traduire) ; identifiants Swift en anglais, commentaires en français |
| Qualité | CI GitHub Actions (macOS) : build + tests unitaires (Swift Testing) à chaque push |
| Livraison | Commits sur `claude/eager-feynman-i41p3l` ; validation par l'utilisateur après chaque étape |

## 3. Contexte d'usage et matériel

- Usage : soirées / événements **en salle** — l'enceinte est dans la même pièce que le micro (risque de Larsen).
- Micros possibles : USB, interface audio + XLR (choix du canal), micro intégré du Mac, AirPods / micro Bluetooth.
- Sorties possibles : enceinte Bluetooth, enceinte / sono filaire, casque filaire, casque Bluetooth / AirPods.
- Conséquences : l'app accepte tout type de périphérique mais **prévient** des cas à risque (voir §4).

## 4. Écran de démarrage : « Préparation de l'émission » (Session Setup)

- Écran affiché **à chaque lancement**, **pré-rempli** avec la dernière session si ses périphériques sont
  branchés (sinon : périphériques par défaut du Mac).
- **Allumage automatique** (choix du 28/09/2026, remplace l'allumage au levier) : au lancement, le moniteur s'allume tout
  seul dès que le matériel est connu, avec une **séquence de démarrage courte (moins de 2 s)** qu'un clic ou Entrée fait
  passer. Le levier « SECTEUR » sert seulement à éteindre et à rallumer ; rallumé, le moniteur reprend où il en était.
- **Préparation guidée, une question à la fois** (demande du 28/09/2026 : le premier écran, un menu de cinq réglages
  avec les essais sur le côté, était jugé peu intuitif). Onglets **1 MICRO · 2 ENCEINTE · 3 CASQUE · 4 GO** : étape
  affichée en vidéo inverse, étapes pas encore atteintes éteintes, « ! » sur une étape à régler.
  1. **Micro** : « Dans quel micro parles-tu ? », liste des micros, **barre de niveau** sous la liste
     (« NIVEAU [#####.....] PARLE ! »).
  2. **Enceinte** : « Où écoute le public ? », liste des sorties, bouton **[ ESSAI : « UN, DEUX » ]**.
  3. **Casque** : « Et dans tes oreilles ? », « Aucun (pas de retour) » puis les sorties, bouton d'essai.
  4. **Go** : récapitulatif (un clic sur une ligne ramène à son étape), alertes, gros bouton **[ PARÉ À ÉMETTRE ! ]**.
- Les listes sont des **boutons radio** : un clic ou les flèches ↑↓ prennent l'appareil **tout de suite** (la barre de
  niveau et l'œil magique suivent le micro choisi). **[ SUIVANT > ]** (Entrée ou →) ne passe à l'étape suivante que si
  l'étape est réglée, sinon le moniteur dit pourquoi ; **[ < RETOUR ]** (Échap ou ←) revient en arrière ; Espace lance
  l'essai aux étapes Enceinte et Casque. Seules les étapes déjà atteintes s'ouvrent depuis les onglets.
- **Récap direct** : si le matériel de la dernière émission est branché et sans problème, le moniteur s'ouvre sur
  l'étape 4, « Même matériel que la dernière fois ? » → validation en un clic. Au retour de la cabine : étape 4 aussi.
- **Réglages avancés**, cachés par défaut (l'app choisit) : **canal d'entrée** (entrée 1, 2… ou paire stéréo) à l'étape
  Micro, seulement si le micro a plusieurs entrées ; **latence** (buffer 64 / 128 / 256 / 512) à l'étape Go.
- Champs : **Micro** (+ canal), **Sortie principale**, **Casque de retour** (facultatif, forcément différent de la
  sortie principale), **Latence**.
- Outils : **œil magique** sur le boîtier « Commandes » (niveau réel du micro et du canal choisis, tant que le moniteur
  est allumé) ; **son d'essai** par sortie, dans son étape : **la voix du Mac annonce « Essai enceinte, un, deux »** (ou
  « casque ») **puis un bip** de 1 kHz, pour savoir tout de suite quelle sortie parle.
- **Journal de bord** : la dernière émission validée (date et appareils) est mémorisée et affichée sur le bureau.
- Avertissements (non bloquants) :
  - sortie Bluetooth : 150 à 300 ms de décalage ; AirPlay : ~2 s ;
  - micro Bluetooth : macOS bascule le périphérique en qualité « téléphone » (16 kHz), entrée et sortie ;
  - micro intégré : capte toute la pièce, risque de Larsen.
- Style (détail au §9) : les étapes s'affichent en vert sur le **moniteur cathodique « Contrôle émetteur »** ; à
  côté, le boîtier « Commandes » porte le **levier « SECTEUR »** et l'œil magique.
- Mémorisation : `UserDefaults` (UID des périphériques, jamais les `AudioDeviceID` qui changent à chaque reconnexion).
- Déconnexion pendant la session : **bandeau d'alerte bordeaux + reconnexion automatique** dès que le périphérique
  réapparaît (silence entre-temps).

## 5. Moteur audio

- **Core Audio (HAL)** pour lister et sélectionner les périphériques : `AVAudioSession` n'existe pas sur macOS et
  `AVAudioEngine` ne sait pas énumérer les périphériques.
- Routage (étape 3) : **périphérique agrégé privé** créé par l'app (micro + sortie principale + casque, et plus tard
  le tap Spotify), compensation de dérive d'horloge. **AVAudioEngine en rendu manuel temps réel**, piloté par
  l'IOProc de l'agrégé : le mix est rendu une fois puis écrit sur les canaux de l'enceinte et du casque avec des
  gains séparés.
- Casque : **même mix que l'enceinte**, volume séparé.
- ON AIR désactivé : **micro coupé partout** (enceinte et casque).
- Chaîne voix : coupe-bas ~80 Hz → **noise gate** → **compresseur « voix radio »** → effets → mix → **limiteur de
  sécurité** (master). **Détection anti-Larsen** : baisse automatique du micro + alerte.
- Point ouvert (étape 3) : repli si l'agrégé est impossible (fréquences incompatibles, ex. micro Bluetooth à 16 kHz).
- Constaté sur le matériel réel (test de l'étape 1) : l'enceinte Bluetooth tourne à **44,1 kHz** alors que le micro USB
  et les AirPods sont à **48 kHz** → conversion de fréquence indispensable à l'étape 3. Les AirPods apparaissent comme
  **deux périphériques distincts** (micro à 24 kHz, sortie à 48 kHz).

## 6. Console micro et effets

- **ON AIR hybride** : clic bref = antenne verrouillée ; appui long = push-to-talk (coupure au relâchement).
- Raccourcis **dans l'app** (fenêtre au premier plan) : Espace = ON AIR ; bloc de touches 4×4 = cartouches,
  par **position physique** (fonctionne en AZERTY comme en QWERTY).
- Potards : **Micro**, **Master**, **Casque**, **Musique** (le conducteur : Spotify et fichiers).
- Rack d'effets **cumulables, ordre fixe** : Pitch → Supermarché → Distorsion ; chaque effet = interrupteur on/off +
  un potard d'intensité.
- **Annonce Supermarché** : passe-bande + saturation + réverbération de grand hall + **carillon d'annonce automatique**
  (mélodie originale synthétisée, pas de jingle protégé) + grésillement de sono.
- **Grosse Voix / Pitch** : potard de -12 à +12 demi-tons + presets Monstre / Grosse voix / Chipmunk.

## 7. Musique : le conducteur (Spotify + fichiers)

Décidé le 28/09/2026 : la liste de lecture est **l'essentiel de l'émission**.

- **Conducteur** = la liste de lecture de l'émission, affichée au **centre du bureau** de la cabine (grand écran vert
  « CONDUCTEUR » à côté de la platine, §9).
- **Deux sources dans la même liste** : des **titres Spotify** (tes playlists, la recherche) et des **fichiers audio du
  Mac** (mp3, m4a, wav, aiff, caf, flac ; glisser-déposer ou bouton « + Fichier »).
- **Plusieurs conducteurs nommés** (« Apéro du jeudi », « Mariage Julie & Tom »…), enregistrés ; on choisit celui à
  charger. Une playlist Spotify peut servir de point de départ à un conducteur.
- **Enchaînement automatique** : le titre suivant part tout seul, comme à la radio, avec un **fondu court**
  (≈ 2 s). Entre deux titres Spotify, c'est le fondu réglé dans Spotify qui s'applique : l'app place le titre suivant
  dans la file d'attente de Spotify et le laisse enchaîner.
- Outils :
  - **réordonner** par glisser-déposer, et **« À suivre »** : le titre choisi passe juste après celui en cours ;
  - **heures de passage** de chaque titre à l'heure de Paris, et **fin prévue** du conducteur ;
  - **« Stop après »** : la musique s'arrête à la fin du titre en cours, pour prendre l'antenne ;
  - **« Chercher »** : recherche dans Spotify (et parmi les fichiers déjà ajoutés), ajout au conducteur en un clic ;
  - **« En retrait »** : musique baissée à la main (voir ducking).
- **Platine vinyle** = le titre en cours : la pochette devient l'étiquette du disque qui tourne, le bras avance avec la
  progression, **temps restant en chiffres Nixie** ; précédent / lecture-pause / suivant pilotent le conducteur.
  **Filtre « vieux disque »** optionnel (craquements + filtre d'époque, audible à l'antenne).
- **Spotify** (compte **Premium**, confirmé le 28/09/2026) :
  - **API Web Spotify** (connexion à ton compte par OAuth avec PKCE, sans secret) pour lire tes playlists, chercher des
    titres, récupérer titres, artistes, durées et pochettes, et remplir la file d'attente. Il faut créer une fois une
    **app développeur Spotify** (gratuite) et donner son identifiant client à Radio Moustache ;
  - lecture pilotée dans l'**app Spotify du Mac**, lancée automatiquement (AppleScript pour lire un titre précis,
    mettre en pause, connaître la position ; la lecture automatique de Spotify en fin de liste est désactivée) ;
  - limite de Spotify pour les nouvelles apps (depuis fin 2024) : les playlists créées par Spotify (éditoriales,
    « Découvertes de la semaine »…) ne sont pas lisibles ; tes propres playlists (ou tes copies) le sont ;
  - audio : **capture de Spotify par Process Tap** (macOS 14.2+) : le son passe par le moteur (enceinte + casque) et le
    son d'origine est coupé pendant la capture. Autorisation « Enregistrement audio système » demandée une fois.
- **Fichiers** : lus par le moteur de l'app, sur l'enceinte et le casque, avec les fondus.
- **Ducking** : -12 dB, descente 300 ms, remontée 1,5 s. Déclencheurs : **ON AIR** + touche **« En retrait »** du
  conducteur.

## 8. Soundboard (cartouches)

- **Racks de 16 cartouches** (4×4), en banques A, B, C…
- Mode par cartouche : One-shot / Toggle / Boucle / Maintien.
- Cartouches **superposables** + gros bouton **STOP ALL** (fondu).
- Personnalisation : **étiquette Dymo + couleur**, **volume individuel**, **durée + compte à rebours**.
- Import : glisser-déposer sur une fente, import multiple, formats mp3 / wav / m4a / aiff / caf / flac,
  **normalisation du volume** à l'import.
- Enregistrement au micro : **voix avec effets actifs**, toujours **hors antenne** ; décompte 3-2-1, suppression
  automatique des silences, réécoute avant sauvegarde.
- Stockage : copie dans `~/Library/Application Support/RadioMoustache/` + index `library.json`
  (JSON + FileManager, plus simple et lisible que Core Data).

## 9. Direction artistique : « Radio Moustache, émetteur clandestin, 1967 »

Validée le 28/09/2026 sur la maquette interactive : https://claude.ai/artifact/WB7sB9tKfAJHHjLmNmnMz1
(elle remplace un premier essai « studio des années 60 », jugé pas assez marqué).

- **Concept** : une **radio pirate des années 60**, comme les radios qui émettaient alors depuis des bateaux ancrés
  en eaux internationales. Le studio est caché dans la **cabine radio d'un vieux chalutier**, **la nuit**. Tout est
  bricolé : scotch de masquage écrit au marqueur, gaffer, étiquettes Dymo, pochoirs.
- **Décor commun aux deux écrans** :
  - **cloison en acier rivetée** peinte en vert d'eau, écaillée et rouillée, tuyau au plafond ;
  - **drapeau pirate** : tête de mort à **moustache en guidon orange**, deux micros croisés à la place des tibias ;
  - nom au **pochoir** « Radio Moustache », fréquence **102,4 MHz** ;
  - **bureau en bois** sombre, **lampe suspendue qui se balance** (la lumière bouge avec elle), grain de pellicule,
    vignettage.
- **Écran 1, « Préparation de l'émission »** (l'écran de démarrage du §4) :
  - sur le bureau : **journal de bord** tapé à la machine (dernière session + un mot au marqueur), tasse émaillée qui
    fume, cendrier et cigarette ;
  - **moniteur « Contrôle émetteur »** (boîtier kaki, écran cathodique vert) avec le scotch « PAS TOUCHE ! — le
    capitaine » ;
  - **boîtier « Commandes »** : **interrupteur à couteau « SECTEUR »** (étincelles) et **œil magique** (niveau du micro) ;
  - au lancement, le moniteur s'allume tout seul : **séquence de démarrage** (« chauffage des lampes… antenne hissée…
    position : eaux internationales… 102,4 MHz… matériel audio trouvé »), puis les **étapes guidées** en vert (§4) :
    onglets, question en grand, liste à boutons radio, niveau du micro ou essai de la sortie, messages,
    **[ < RETOUR ]** / **[ SUIVANT > ]**, et **[ PARÉ À ÉMETTRE ! ]** à l'étape 4.
- **Écran 2, « Cabine radio »** (le studio) :
  - au mur : **horloge de bord** en laiton, **boîtier ON AIR** en tôle froissée (vitre rouge au pochoir, **ampoule rouge
    grillagée**), **hublot** en laiton (mer au clair de lune, phare qui balaie l'horizon) ;
  - **rack de l'émetteur** : 4 **lampes** qui rougeoient (plus fort à l'antenne), 2 **VU-mètres**, **cadran d'accord**
    88–108 MHz (Paris, Londres, Bruxelles, Monte-Carlo, aiguille sur 102,4), **œil magique** du micro, **chrono
    d'antenne en chiffres Nixie** ;
  - sur le bureau, de gauche à droite : **platine vinyle** (titre en cours, temps restant en Nixie, petit écran vert),
    **conducteur** au centre (boîtier kaki, grand écran vert : heures de passage, titre en cours en vidéo inverse,
    « stop après » ; touches ivoire « À suivre », « Stop après », « Chercher », « + Fichier », « En retrait » ;
    étiquette Dymo du conducteur chargé, §7), **console en émail vert d'eau martelé** (potards Micro / Master /
    Casque / Musique en 2 × 2, leviers d'effets Pitch / Supermarché / Disto avec potard d'intensité), **rack de
    cartouches** kaki (banques A / B / C, 16 cartouches à étiquette Dymo, voyants READY / PLAY,
    **STOP · TOUT COUPER**) ;
  - à l'antenne : **la cabine vire au rouge**, la vitre ON AIR et l'ampoule s'allument et scintillent.
- **Horloge de bord** (demandée le 28/09/2026) :
  - **heure de Paris** : fuseau `Europe/Paris`, heure d'été comprise ; le cadran affiche « PARIS » et le décalage
    « GMT+1 » ou « GMT+2 » selon la saison ;
  - **trotteuse rouge qui avance à chaque seconde** (petit rebond), calée sur les secondes réelles ; le chrono d'antenne
    et les compteurs avancent au même rythme ;
  - cadran d'horloge de cabine radio de navire : chiffres 1 à 12, 13 à 24 en rouge, **secteurs de silence** rouges
    (h+15 à h+18, h+45 à h+48) et verts (h+00 à h+03, h+30 à h+33) ;
  - **affichage Nixie HH:MM:SS** sous l'horloge (demandé le 28/09/2026).
- **Palette = lueurs d'époque**, dark mode exclusif, sur de l'acier vert d'eau, du bois sombre et de la tôle kaki ou
  noire :
  - **orange électrique `#ff6b00`** : lampes de l'émetteur, chiffres Nixie, moustache du drapeau, voyants PLAY ;
  - **vert phosphore `#3efb0a`** : écrans cathodiques, œil magique, voyants READY ;
  - **rouge / bordeaux `#6a0e15`** : ON AIR, alertes, bouton STOP.
- **Typographie** (polices libres, embarquées dans l'app) : **Black Ops One** (pochoirs), **Permanent Marker**
  (scotch écrit au marqueur), **Special Elite** (machine à écrire), **VT323** (écrans verts), **Jost** (gravures,
  étiquettes Dymo, chiffres Nixie). Licences OFL et Apache 2.0.
- **Rendu** : les matières (cloison, bois, tôle froissée, papier, grain) et le drapeau sont des **images exportées de la
  maquette** (sources SVG et script d'export dans le dépôt), le reste est dessiné en SwiftUI ; plus tard, des images
  photoréalistes générées par IA avec Higgsfield (bloqué les 27 et 28/09 par sa limite quotidienne). **Tout ce qui
  bouge est animé en code** (levier, aiguilles, lampes, fumée, lumière, trotteuse).
- **Fenêtre** : redimensionnable aux **proportions 16:10** (scène de référence 1440 × 900 points, mise à l'échelle),
  plein écran possible avec des bandes sombres, barre de titre masquée. Le diagnostic audio de l'étape 1 reste
  accessible dans une fenêtre à part (menu Fenêtre, ⌥⌘D).
- **Composants** : ON AIR hybride (§6), **VU-mètres à aiguille** (balistique VU 300 ms), **œil magique**, **potards**,
  **leviers + voyants**, **cartouches**, **platine** ; **icône ON AIR dans la barre des menus**.
- **Bruitages d'interface** (clac du levier, étincelles, allumage du moniteur, frappe du texte, validation) :
  **fabriqués par l'app** (synthèse), joués sur les **haut-parleurs intégrés du Mac**, ou dans le casque de retour s'il
  n'y en a pas ; **jamais sur l'enceinte ni à l'antenne**.
- **Lisibilité** : les informations critiques (ON AIR, niveaux, alertes, heure) restent très contrastées en salle
  sombre.

## 10. Plan d'implémentation

1. **Architecture + AudioManager** : couche Core Audio, liste et sélection des périphériques, mémorisation,
   écran de diagnostic provisoire, CI. ✅
2. **Écran « Préparation de l'émission »** lié à `AudioManager` (§4 et §9) : moniteur cathodique qui s'allume tout
   seul, préparation guidée en 4 étapes (micro et son niveau, enceinte et casque avec leur essai, récapitulatif),
   réglages avancés (canal, latence), œil magique sur le niveau réel du micro, puis « Paré à émettre ». ✅ (validé le
   28/09/2026, puis refait en étapes guidées le même jour, à revalider)
3. **Moteur temps réel** : agrégé privé + AVAudioEngine, monitoring, première distorsion.
4. **Musique : le conducteur** (§7) : conducteurs nommés, titres Spotify (API Web + app Spotify du Mac) et fichiers,
   enchaînement automatique et fondus, à suivre, heures de passage, stop après, recherche, capture de Spotify
   (Process Tap), ducking. Étape la plus longue : elle pourra être livrée en deux temps (fichiers, puis Spotify).
5. **Soundboard** : cartouches, import, enregistrement, persistance.

## 11. Écarts assumés par rapport au cahier des charges initial

- `AVAudioSession` (iOS uniquement) → **Core Audio HAL**.
- SDK Spotify App Remote (iOS / Android uniquement) → **API Web Spotify** (playlists, recherche, file d'attente) +
  **AppleScript** (lecture dans l'app Spotify du Mac) + **Process Tap** pour l'audio.
- Mini-player Spotify seul → **conducteur** mêlant Spotify et fichiers (demande du 28/09/2026 : la musique est
  l'essentiel).
- Interface « minimaliste » → **radio pirate des années 60, « full full vintage »** (demande explicite), en gardant
  le haut contraste et les couleurs d'origine (orange, vert néon, bordeaux) comme lueurs.
- Core Data → **JSON + FileManager** pour la bibliothèque de jingles.
