# Radio Moustache — Spécification

Décisions validées le 27/09/2026 à l'issue du questionnaire (QCM).
Ce document est la source de vérité du projet. Toute nouvelle décision y est consignée.

---

## 1. Vision

Application macOS **native** (SwiftUI, pas de webapp ni d'Electron) de diffusion et d'animation audio en direct,
pensée pour les **soirées et événements en salle**. Direction artistique : **studio radio des années 1950-60,
« full full vintage »**.

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

## 4. Écran de démarrage (Session Setup)

- Modale affichée **à chaque lancement**, **pré-remplie** avec la dernière session si ses périphériques sont
  branchés (sinon : périphériques par défaut du Mac) → validation en un clic.
- Champs : **Micro** (+ **canal d'entrée** : entrée 1, 2… ou paire stéréo), **Sortie principale**,
  **Casque de retour** (facultatif, forcément différent de la sortie principale), **Latence** (buffer 64 / 128 / 256 / 512).
- Outils : **œil magique** (niveau du micro en direct), bouton **« son test »** par sortie.
- Avertissements (non bloquants) :
  - sortie Bluetooth : 150 à 300 ms de décalage ; AirPlay : ~2 s ;
  - micro Bluetooth : macOS bascule le périphérique en qualité « téléphone » (16 kHz), entrée et sortie ;
  - micro intégré : capte toute la pièce, risque de Larsen.
- Style : **plaque de métal gravée**, menus déroulants fiables habillés vintage, voyants.
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
- Potards : **Micro**, **Master**, **Casque**, **Musique (Spotify)**.
- Rack d'effets **cumulables, ordre fixe** : Pitch → Supermarché → Distorsion ; chaque effet = interrupteur on/off +
  un potard d'intensité.
- **Annonce Supermarché** : passe-bande + saturation + réverbération de grand hall + **carillon d'annonce automatique**
  (mélodie originale synthétisée, pas de jingle protégé) + grésillement de sono.
- **Grosse Voix / Pitch** : potard de -12 à +12 demi-tons + presets Monstre / Grosse voix / Chipmunk.

## 7. Spotify

- Contrôle **AppleScript** de l'app Spotify du Mac : Play/Pause, Suivant, Précédent, shuffle/repeat, titre, artiste,
  pochette ; **lancement automatique** de Spotify. (Le SDK Spotify App Remote n'existe pas sur macOS.)
- Audio : **capture de Spotify par Process Tap** (macOS 14.2+) : le son passe par le moteur (enceinte + casque) et le
  son d'origine est coupé pendant la capture. Autorisation « Enregistrement audio système » demandée une fois.
- **Ducking** : -12 dB, descente 300 ms, remontée 1,5 s. Déclencheurs : **ON AIR** + interrupteur manuel
  **« musique en retrait »**.
- Mini-player = **platine vinyle broadcast** : la pochette devient l'étiquette du disque qui tourne, le bras avance
  avec la progression, **temps restant en chiffres Nixie**, **filtre « vieux disque »** optionnel (craquements +
  filtre d'époque, audible à l'antenne).

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

## 9. Direction artistique — « full full vintage »

Précisée le 27/09/2026 à partir de trois photos de référence fournies par l'utilisateur (studio radio des années 60
au pupitre bleu-vert ; studio des années 70 tamisé à la lampe ; ordinateur des années 80 à écran vert).

- Mélange retenu : le **matériel radio des années 60** (pupitre émaillé, gros boutons, platine, magnéto, boîtier
  ON AIR, murs en panneaux perforés) dans la **pénombre chaude des années 70** (lampe à abat-jour, grain de
  pellicule), avec des **petits écrans cathodiques verts** pour les textes (titre en cours, menus).
- **Studio de nuit** : pénombre, lumière de lampe chaude, lueurs orange et vertes. Dark mode conservé.
- **Appareils vus de face** posés sur un bureau en bois, mur perforé en haut avec l'horloge et le boîtier ON AIR :
  tout reste cliquable et lisible en direct.
- **Pupitre en émail bleu-vert martelé** (vert d'eau patiné), qui contraste avec les lueurs orange.
- Rendu : **images photoréalistes générées par IA** (Higgsfield, fonds transparents) pour les façades, boutons,
  VU-mètres, bobines et platine, **animées en code** (aiguilles, bobines, voyants), comme les plugins audio vintage.
  En attendant (Higgsfield limité le 27/09), la maquette utilise des matières en CSS et SVG.
- Validation du style sur une **maquette interactive** avant de coder :
  https://claude.ai/artifact/WB7sB9tKfAJHHjLmNmnMz1
- Référence de départ : **studio radio 1950-60**, **skeuomorphisme total** (bakélite, bois, métal, verre, vis
  apparentes, reflets, aiguilles avec inertie physique).
- Palette = **lueurs d'époque**, dark mode exclusif :
  - fond : bakélite / bois sombre ;
  - **orange électrique `#ff6b00`** : lueur des tubes, chiffres Nixie ;
  - **vert néon `#3efb0a`** : œil magique, voyants ;
  - **bordeaux profond `#6a0e15`** : enseigne ON AIR, alertes, cuir.
- Typographie : **lettres gravées** sur les façades (Jost, proche de Futura), **étiquettes Dymo** pour les jingles,
  **texte pixel vert phosphore** sur les écrans (VT323), logo en script années 60 (Yellowtail). Polices libres (OFL),
  à embarquer dans l'app.
- Composants :
  - ON AIR = **enseigne lumineuse** (bouton géant, halo, léger scintillement) ;
  - niveaux = **VU-mètres à aiguille** (master, balistique VU 300 ms) + **œil magique** (micro) ;
  - volumes = **potards en bakélite** ; effets = **interrupteurs à levier + voyants** ;
  - soundboard = **cartouches broadcast** (étiquette Dymo, voyants READY / PLAY) ;
  - Spotify = **platine vinyle broadcast**.
- Éléments de studio : **horloge à aiguilles**, **chrono d'antenne Nixie**, **icône ON AIR dans la barre des menus**,
  **reflet rouge** sur tout le studio quand on est à l'antenne.
- Ambiance : **allumage des lampes** au lancement, **patine / grain / vignettage**, **scintillement** des lueurs,
  **bruitages d'interface** (jamais envoyés à l'enceinte).
- Disposition : **console d'époque** — pont de mesure en haut (VU-mètres, enseigne ON AIR, horloge, œil magique),
  puis platine | console | rack de cartouches.
- Lisibilité : les informations critiques (ON AIR, niveaux, alertes) restent très contrastées en salle sombre.

## 10. Plan d'implémentation

1. **Architecture + AudioManager** : couche Core Audio, liste et sélection des périphériques, mémorisation,
   écran de diagnostic provisoire, CI. ✅
2. **Modale de démarrage vintage** liée à `AudioManager` : un **moniteur cathodique qui s'allume** (balayage,
   séquence de démarrage) et affiche en vert le choix du micro, du canal, de l'enceinte, du casque et de la latence ;
   à côté, un levier « secteur », l'œil magique (niveau micro réel) et les boutons « son test ».
3. **Moteur temps réel** : agrégé privé + AVAudioEngine, monitoring, première distorsion.
4. **Spotify** : AppleScript + Process Tap, ducking.
5. **Soundboard** : cartouches, import, enregistrement, persistance.

## 11. Écarts assumés par rapport au cahier des charges initial

- `AVAudioSession` (iOS uniquement) → **Core Audio HAL**.
- SDK Spotify App Remote (iOS / Android uniquement) → **AppleScript** + **Process Tap** pour l'audio.
- Interface « minimaliste » → **« full full vintage »** (demande explicite), en gardant le haut contraste.
- Core Data → **JSON + FileManager** pour la bibliothèque de jingles.
