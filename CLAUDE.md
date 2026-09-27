# Radio Moustache : notes de travail

- `docs/SPEC.md` est la source de vérité : on y consigne toute nouvelle décision.
- Projet XcodeGen : on modifie `project.yml`, jamais le `.xcodeproj` (généré, ignoré par git).
- Swift 6 (concurrence stricte), SwiftUI + `@Observable`, macOS 14.2 minimum, 100 % frameworks Apple.
- Identifiants Swift en anglais ; commentaires et textes d'interface en français (String Catalog).
- Le code audio temps réel ne doit jamais allouer, verrouiller ni bloquer dans les callbacks de rendu.
- Pas de toolchain Swift dans l'environnement cloud de Claude : c'est la CI GitHub Actions (macOS) qui fait foi
  pour la compilation et les tests.
- Travail par étapes (voir SPEC §10) : chaque étape est validée par l'utilisateur avant de passer à la suivante.
