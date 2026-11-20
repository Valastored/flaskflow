#!/usr/bin/env bash
# Builds the signed Play Store bundle (build/flaskflow.aab) on macOS.
# Installs what's missing (only inside your home folder, no sudo):
#   - Java 17 (Temurin)           -> ~/Library/Java/flaskflow-jdk17
#   - Android SDK command-line    -> ~/Library/Android/sdk
#   - Godot export templates      -> ~/Library/Application Support/Godot/export_templates
#   - Android build template      -> <project>/android/build
# Then exports with the release keystore in signing/.
#
# Usage (Godot must be CLOSED):   bash tools/build_android_mac.sh
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SDK="$HOME/Library/Android/sdk"
JDK_DIR="$HOME/Library/Java/flaskflow-jdk17"
KEYSTORE="$PROJECT/signing/flaskflow-release.keystore"
OUT="$PROJECT/build/flaskflow.aab"

step() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "Ce script est pour macOS."
[ -x "$GODOT" ] || fail "Godot introuvable dans /Applications (sinon : GODOT=/chemin/vers/Godot bash $0)."
[ -f "$KEYSTORE" ] || fail "Keystore introuvable : $KEYSTORE"
if pgrep -xq Godot; then
  fail "Ferme Godot (Cmd+Q) avant de lancer ce script, puis relance-le."
fi

ARCH="$(uname -m)"; [ "$ARCH" = "arm64" ] && JARCH="aarch64" || JARCH="x64"

# ---------------------------------------------------------------- Java 17
step "Java 17"
if [ ! -x "$JDK_DIR/Contents/Home/bin/java" ]; then
  mkdir -p "$JDK_DIR"
  curl -fL --progress-bar \
    "https://api.adoptium.net/v3/binary/latest/17/ga/mac/$JARCH/jdk/hotspot/normal/eclipse" \
    -o /tmp/flaskflow-jdk.tar.gz
  tar -xzf /tmp/flaskflow-jdk.tar.gz -C "$JDK_DIR" --strip-components=1
  rm -f /tmp/flaskflow-jdk.tar.gz
fi
export JAVA_HOME="$JDK_DIR/Contents/Home"
"$JAVA_HOME/bin/java" -version 2>&1 | head -1

# ---------------------------------------------------------------- Android SDK
step "SDK Android"
SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  mkdir -p "$SDK/cmdline-tools"
  ZIP_NAME="$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml \
    | grep -o 'commandlinetools-mac-[0-9]*_latest.zip' | sort -V | tail -1)"
  [ -n "$ZIP_NAME" ] || fail "Impossible de trouver les outils Android sur dl.google.com"
  curl -fL --progress-bar "https://dl.google.com/android/repository/$ZIP_NAME" -o /tmp/flaskflow-clt.zip
  rm -rf "$SDK/cmdline-tools/latest" /tmp/flaskflow-clt
  unzip -q /tmp/flaskflow-clt.zip -d /tmp/flaskflow-clt
  mv /tmp/flaskflow-clt/cmdline-tools "$SDK/cmdline-tools/latest"
  rm -rf /tmp/flaskflow-clt /tmp/flaskflow-clt.zip
fi
export ANDROID_HOME="$SDK"
yes | "$SDKMANAGER" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
"$SDKMANAGER" --sdk_root="$SDK" "platform-tools" "platforms;android-36" "build-tools;36.0.0" \
  "platforms;android-35" "build-tools;35.0.0" | grep -v "^\[" || true

# ---------------------------------------------------------------- Godot templates
GODOT_VERSION_FULL="$("$GODOT" --version | tail -1)"        # e.g. 4.5.1.stable.official.xxxx
GODOT_VER="$(echo "$GODOT_VERSION_FULL" | cut -d. -f1-3)"   # 4.5.1  (or 4.6.stable -> handled below)
case "$GODOT_VER" in *stable*) GODOT_VER="$(echo "$GODOT_VER" | sed 's/\.stable//')";; esac
TEMPLATE_DIR_NAME="$GODOT_VER.stable"
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$TEMPLATE_DIR_NAME"
step "Modèles d'export Godot $GODOT_VER"
if [ ! -f "$TEMPLATES/android_source.zip" ]; then
  mkdir -p "$TEMPLATES"
  curl -fL --progress-bar \
    "https://github.com/godotengine/godot/releases/download/$GODOT_VER-stable/Godot_v$GODOT_VER-stable_export_templates.tpz" \
    -o /tmp/flaskflow-templates.tpz
  rm -rf /tmp/flaskflow-templates
  unzip -q /tmp/flaskflow-templates.tpz -d /tmp/flaskflow-templates
  cp -R /tmp/flaskflow-templates/templates/. "$TEMPLATES/"
  rm -rf /tmp/flaskflow-templates /tmp/flaskflow-templates.tpz
fi

# ---------------------------------------------------------------- Android build template
step "Modèle de compilation Android du projet"
if [ "$(cat "$PROJECT/android/.build_version" 2>/dev/null)" != "$TEMPLATE_DIR_NAME" ]; then
  rm -rf "$PROJECT/android/build"
  mkdir -p "$PROJECT/android/build"
  unzip -q "$TEMPLATES/android_source.zip" -d "$PROJECT/android/build"
  printf "%s" "$TEMPLATE_DIR_NAME" > "$PROJECT/android/.build_version"
  touch "$PROJECT/android/build/.gdignore"
fi

# ---------------------------------------------------------------- Godot editor settings
step "Réglages Android de Godot"
for SETTINGS in "$HOME/Library/Application Support/Godot"/editor_settings-*.tres; do
  [ -f "$SETTINGS" ] || continue
  python3 - "$SETTINGS" "$JAVA_HOME" "$SDK" <<'PY'
import re, sys
path, java, sdk = sys.argv[1:]
s = open(path).read()
for key, val in (("export/android/java_sdk_path", java), ("export/android/android_sdk_path", sdk)):
    line = f'{key} = "{val}"'
    if re.search(rf'^{re.escape(key)} = .*$', s, re.M):
        s = re.sub(rf'^{re.escape(key)} = .*$', line, s, flags=re.M)
    else:
        s = s.rstrip("\n") + "\n" + line + "\n"
open(path, "w").write(s)
PY
done

# ---------------------------------------------------------------- Export
step "Import du projet"
"$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1 || true

if [ -z "${KEYSTORE_PASSWORD:-}" ]; then
  printf "Mot de passe du keystore (rien ne s'affiche pendant la saisie) : "
  read -rs KEYSTORE_PASSWORD; echo
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="flaskflow"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASSWORD"

step "Export du jeu (la 1re fois, Gradle télécharge ses dépendances : quelques minutes)"
mkdir -p "$PROJECT/build"
rm -f "$OUT"
"$GODOT" --headless --path "$PROJECT" --export-release "Android" "$OUT" 2>&1 | tee "$PROJECT/build/export.log" | grep -E "ERROR|error:|FAILURE|BUILD|savepack|export" || true

if [ -f "$OUT" ]; then
  printf "\n\033[1;32m✓ Fichier prêt : %s (%s)\033[0m\n" "$OUT" "$(du -h "$OUT" | cut -f1)"
  open -R "$OUT"
else
  fail "L'export a échoué. Le détail est dans build/export.log"
fi
