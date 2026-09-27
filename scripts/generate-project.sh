#!/usr/bin/env bash
# Génère RadioMoustache.xcodeproj à partir de project.yml (XcodeGen).
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen est introuvable. Installe-le avec : brew install xcodegen" >&2
  exit 1
fi

xcodegen generate
echo "Projet généré. Ouvre-le avec : open RadioMoustache.xcodeproj"
