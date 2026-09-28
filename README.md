# Radio Moustache

Application macOS native de diffusion et d'animation audio en direct : micro à l'antenne avec effets,
Spotify avec ducking automatique, soundboard de jingles. Direction artistique : radio pirate des années 60 (« émetteur clandestin, 1967 »).

La spécification complète et toutes les décisions sont dans [`docs/SPEC.md`](docs/SPEC.md).

## Prérequis

- macOS 14.2 ou plus récent
- Xcode 16 ou plus récent (Swift 6)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) : `brew install xcodegen`

## Lancer le projet

```bash
./scripts/generate-project.sh   # génère RadioMoustache.xcodeproj à partir de project.yml
open RadioMoustache.xcodeproj    # ⌘R pour lancer, ⌘U pour les tests
```

Le `.xcodeproj` est généré et n'est pas versionné : relance le script après chaque `git pull` qui modifie
`project.yml` ou ajoute des fichiers.

### Signature

Par défaut, l'app est signée « Sign to Run Locally » : aucun compte Apple n'est nécessaire. Dans ce mode, macOS
peut redemander l'accès au micro après chaque build. Pour l'éviter, signe avec ton Apple ID (gratuit) :

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig   # puis renseigne ton Team ID
./scripts/generate-project.sh
```

## Structure

```
RadioMoustache/
├── App/              Point d'entrée, délégué AppKit (mode sombre imposé)
├── Audio/
│   ├── CoreAudio/    Couche HAL : lecture des propriétés, périphériques, écoute des branchements
│   ├── Devices/      Sélection, canaux d'entrée, taille de buffer, validation
│   └── AudioManager  Façade @Observable consommée par l'interface
├── Session/          Mémorisation de la dernière configuration (UserDefaults)
├── DesignSystem/     Palette (lueurs d'époque)
├── Features/         Écrans (diagnostic provisoire de l'étape 1)
└── Resources/        Assets, String Catalog (interface en français)
RadioMoustacheTests/  Tests unitaires (Swift Testing), matériel simulé
```

## Avancement

- [x] **Étape 1** : architecture, `AudioManager` (Core Audio), liste et sélection des périphériques, mémorisation, CI
- [ ] **Étape 2** : écran « Préparation de l'émission » (levier secteur, moniteur cathodique, œil magique, sons d'essai)
- [ ] **Étape 3** : moteur temps réel (agrégé privé + AVAudioEngine), monitoring, distorsion
- [ ] **Étape 4** : Spotify (AppleScript + capture audio) et ducking
- [ ] **Étape 5** : soundboard (cartouches), import, enregistrement, persistance

## Intégration continue

Chaque push lance un build et les tests unitaires sur macOS (GitHub Actions, `.github/workflows/ci.yml`).
