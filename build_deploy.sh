#!/bin/bash

# --- Configuration ---
FIREBASE_PROJECT_ID_DEV="colors-notes-dev"
FIREBASE_PROJECT_ID_STAGING="colors-notes-staging"
FIREBASE_PROJECT_ID_PROD="colors-notes-prod"

FIREBASE_CONFIG_FILE_DEV="firebase.dev.json"
FIREBASE_CONFIG_FILE_STAGING="firebase.staging.json"
FIREBASE_CONFIG_FILE_PROD="firebase.prod.json"
TARGET_FIREBASE_JSON_PATH="firebase.json"

GOOGLE_SIGNIN_CLIENT_ID_WEB_DEV="83241971458-14tiragdibb39tnm9op5nd6fqnm4ct53.apps.googleusercontent.com"
GOOGLE_SIGNIN_CLIENT_ID_WEB_STAGING="344541548510-k1vncr9ufjii7r3k4425p8sqgq5p47r6.apps.googleusercontent.com"
GOOGLE_SIGNIN_CLIENT_ID_WEB_PROD="48301164525-6lqqh5tc0m0jpsm4ovdpgalosve17a1m.apps.googleusercontent.com"

GOOGLE_SERVICES_JSON_DEV_PATH="android/app/google-services.dev.json"
GOOGLE_SERVICES_JSON_STAGING_PATH="android/app/google-services.staging.json"
GOOGLE_SERVICES_JSON_PROD_PATH="android/app/google-services.prod.json"
ANDROID_TARGET_GOOGLE_SERVICES_PATH="android/app/google-services.json"

FIREBASE_ANDROID_APP_ID_DEV="1:83241971458:android:dde10259edb60d45711c1b"
FIREBASE_ANDROID_APP_ID_STAGING="1:344541548510:android:631fa078fb9926677d174f"
FIREBASE_ANDROID_APP_ID_PROD="1:48301164525:android:c3713960cdefdbb28589e4"

TESTER_GROUPS_DEV="dev-testers"
TESTER_GROUPS_STAGING="uat-testers"
TESTER_GROUPS_PROD="prod-final-checkers"

WEB_INDEX_TEMPLATE_PATH="web/index-template.html"
WEB_INDEX_PATH="web/index.html"
WEB_INDEX_PLACEHOLDER="##GOOGLE_SIGNIN_CLIENT_ID_PLACEHOLDER##"
PUBSPEC_FILE="pubspec.yaml"
# --- Fin de la Configuration ---

ENVIRONMENT="dev"
PLATFORM="web"
ARTIFACT_TYPE="aab"
ACTION_BUILD=false
ACTION_DEPLOY=false
USER_SPECIFIED_BUILD_MODE=""
VERBOSE_MODE=false
BYPASS_TESTS=false # NOUVEAU: Option pour éviter les tests

CURRENT_FIREBASE_PROJECT_ID=""
CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB=""
CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH=""
CURRENT_FIREBASE_ANDROID_APP_ID=""
CURRENT_TESTER_GROUPS=""
CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH=""
FLUTTER_BUILD_MODE_FLAG=""
ANDROID_ARTIFACT_PATH=""
BUILD_MODE=""

usage() {
    echo "Usage: $0 -e <dev|staging|prod> --platform <web|android> [-a <aab|apk>] [-m <debug|release>] [--build] [--deploy] [--bypasstest] [--verbose]"
    echo ""
    echo "Options:"
    echo "  -e <environnement>     Spécifie l'environnement. Défaut: dev."
    echo "  --platform <web|android> Spécifie la plateforme. Défaut: web."
    echo "  -a <aab|apk>           Spécifie le type d'artefact Android (aab ou apk). Défaut: aab."
    echo "  -m <mode>              Spécifie le mode de build (debug|release)."
    echo "                         Par défaut: 'debug' pour 'dev', 'release' pour les autres."
    echo "  --build                Exécute l'étape de build (incrémente le build number dans pubspec.yaml)."
    echo "  --deploy               Exécute l'étape de déploiement."
    echo "  --bypasstest           Évite l'exécution de 'flutter test' pour les environnements staging et prod." # NOUVEAU
    echo "  --verbose, -v          Affiche les commandes exécutées."
    echo ""
    echo "Si ni --build ni --deploy n'est spécifié, le script affichera cet usage."
    echo "Pour 'prod', --deploy requiert la branche 'main' et la réussite de 'flutter test' (sauf si --bypasstest)."
    echo "Pour 'staging', --deploy autorise 'main', 'staging-branch' ou 'release-candidate/*' et 'flutter test' est exécuté (échec non bloquant, sauf si --bypasstest)."
    exit 1
}

TEMP_ENV=""
TEMP_PLATFORM=""
TEMP_ARTIFACT_TYPE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -e) TEMP_ENV="$2"; shift ;;
        --platform) TEMP_PLATFORM="$2"; shift ;;
        -a|--artifact-type) TEMP_ARTIFACT_TYPE="$2"; shift ;;
        -m|--mode) USER_SPECIFIED_BUILD_MODE="$2"; shift ;;
        --build) ACTION_BUILD=true ;;
        --deploy) ACTION_DEPLOY=true ;;
        --bypasstest) BYPASS_TESTS=true ;; # NOUVEAU
        -v|--verbose) VERBOSE_MODE=true ;;
        -h|--help) usage ;;
        *) echo "Paramètre inconnu: $1"; usage ;;
    esac
    shift
done

if [ -n "$TEMP_ENV" ]; then ENVIRONMENT="$TEMP_ENV"; fi
if [ -n "$TEMP_PLATFORM" ]; then PLATFORM="$TEMP_PLATFORM"; fi
if [ -n "$TEMP_ARTIFACT_TYPE" ]; then ARTIFACT_TYPE="$TEMP_ARTIFACT_TYPE"; fi

if [ "$PLATFORM" == "android" ]; then
    case "$ARTIFACT_TYPE" in
        aab|apk) ;;
        *) echo "Erreur: Type d'artefact Android '$ARTIFACT_TYPE' invalide. Choisir 'aab' ou 'apk'."; usage ;;
    esac
fi

if [ -n "$USER_SPECIFIED_BUILD_MODE" ]; then
    BUILD_MODE="$USER_SPECIFIED_BUILD_MODE"
else
    if [ "$ENVIRONMENT" == "dev" ]; then BUILD_MODE="debug"; else BUILD_MODE="release"; fi
fi

case "$BUILD_MODE" in
    debug) FLUTTER_BUILD_MODE_FLAG="--debug" ;;
    release) FLUTTER_BUILD_MODE_FLAG="--release" ;;
    *) echo "Erreur: Mode de build '$BUILD_MODE' invalide. Choisir 'debug' ou 'release'."; usage ;;
esac

if ! $ACTION_BUILD && ! $ACTION_DEPLOY; then echo "Erreur: --build ou --deploy doit être spécifié."; usage; fi
case "$ENVIRONMENT" in dev|staging|prod) ;; *) echo "Erreur: Environnement '$ENVIRONMENT' invalide."; usage ;; esac
case "$PLATFORM" in web|android) ;; *) echo "Erreur: Plateforme '$PLATFORM' invalide."; usage ;; esac

echo "--- Configuration Sélectionnée ---"
echo "Environnement : $ENVIRONMENT"
echo "Plateforme    : $PLATFORM"
if [ "$PLATFORM" == "android" ]; then echo "Artefact Android: $ARTIFACT_TYPE"; fi
echo "Mode Build    : $BUILD_MODE (Flag: $FLUTTER_BUILD_MODE_FLAG)"
echo "Action Build  : $ACTION_BUILD"
echo "Action Deploy : $ACTION_DEPLOY"
echo "Bypass Tests  : $BYPASS_TESTS" # NOUVEAU
echo "Verbose       : $VERBOSE_MODE"
echo "---------------------------------"
echo ""

execute_verbose() {
    local cmd_description="$1"; shift; local cmd_to_execute=("$@")
    if [ "$VERBOSE_MODE" = true ]; then
        printf ">>> Exécution (%s):" "$cmd_description"; for arg in "${cmd_to_execute[@]}"; do printf " %q" "$arg"; done; printf "\n"
    fi
    "${cmd_to_execute[@]}"; return $?
}

increment_pubspec_build_number() {
    if [ ! -f "$PUBSPEC_FILE" ]; then echo "Erreur: Fichier '$PUBSPEC_FILE' introuvable."; return 1; fi
    current_version_line=$(grep '^version:' "$PUBSPEC_FILE")
    if [ -z "$current_version_line" ]; then echo "Erreur: Ligne 'version:' introuvable dans '$PUBSPEC_FILE'."; return 1; fi
    current_version_string=$(echo "$current_version_line" | awk '{print $2}')
    base_version=$(echo "$current_version_string" | cut -d+ -f1)
    current_build_number_str=$(echo "$current_version_string" | cut -d+ -s -f2)
    if [ -z "$current_build_number_str" ]; then current_build_number=0; else current_build_number=$((current_build_number_str)); fi
    new_build_number=$((current_build_number + 1)); new_version_string="${base_version}+${new_build_number}"
    execute_verbose "Mise à jour version pubspec.yaml" sed -i "s/^version: .*/version: $new_version_string/" "$PUBSPEC_FILE"
    if [ $? -ne 0 ]; then echo "Erreur: Échec mise à jour version dans '$PUBSPEC_FILE'."; return 1; fi
    echo "Numéro de build dans '$PUBSPEC_FILE' mis à jour: '$current_version_string' -> '$new_version_string'."
    return 0
}

case "$ENVIRONMENT" in
    dev)
        CURRENT_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID_DEV"; CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB="$GOOGLE_SIGNIN_CLIENT_ID_WEB_DEV"
        CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH="$GOOGLE_SERVICES_JSON_DEV_PATH"; CURRENT_FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID_DEV"
        CURRENT_TESTER_GROUPS="$TESTER_GROUPS_DEV"; CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH="$FIREBASE_CONFIG_FILE_DEV" ;;
    staging)
        CURRENT_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID_STAGING"; CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB="$GOOGLE_SIGNIN_CLIENT_ID_WEB_STAGING"
        CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH="$GOOGLE_SERVICES_JSON_STAGING_PATH"; CURRENT_FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID_STAGING"
        CURRENT_TESTER_GROUPS="$TESTER_GROUPS_STAGING"; CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH="$FIREBASE_CONFIG_FILE_STAGING" ;;
    prod)
        CURRENT_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID_PROD"; CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB="$GOOGLE_SIGNIN_CLIENT_ID_WEB_PROD"
        CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH="$GOOGLE_SERVICES_JSON_PROD_PATH"; CURRENT_FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID_PROD"
        CURRENT_TESTER_GROUPS="$TESTER_GROUPS_PROD"; CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH="$FIREBASE_CONFIG_FILE_PROD" ;;
esac

if [[ "$CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB" == YOUR_* || "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" == YOUR_* || "$CURRENT_FIREBASE_ANDROID_APP_ID" == YOUR_* ]]; then
    echo "ERREUR: Vérifiez les placeholders 'YOUR_*' dans la configuration du script pour '$ENVIRONMENT'."
    if [[ ( ! -f "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" && "$PLATFORM" == "android" && $ACTION_BUILD ) || \
          ( ! -f "$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH" && $ACTION_DEPLOY ) ]]; then
        echo "ERREUR: Fichiers de configuration manquants pour '$ENVIRONMENT'."
    fi
    exit 1
fi

if $ACTION_BUILD; then
    echo ""; echo ">>> Incrémentation du numéro de build dans $PUBSPEC_FILE <<<"
    increment_pubspec_build_number; if [ $? -ne 0 ]; then exit 1; fi; echo ""
fi

if $ACTION_BUILD && [ "$PLATFORM" == "android" ]; then
    echo ">>> Préparation config signature pour '$ENVIRONMENT' ($BUILD_MODE) <<<"
    KEY_PROPERTIES_SOURCE_FILE=""
    if [ "$BUILD_MODE" == "release" ]; then
        if [ "$ENVIRONMENT" == "dev" ]; then KEY_PROPERTIES_SOURCE_FILE="android/key.dev.properties";
        elif [ "$ENVIRONMENT" == "staging" ]; then KEY_PROPERTIES_SOURCE_FILE="android/key.staging.properties";
        elif [ "$ENVIRONMENT" == "prod" ]; then KEY_PROPERTIES_SOURCE_FILE="android/key.prod.properties"; fi
    fi

    if [ -n "$KEY_PROPERTIES_SOURCE_FILE" ]; then
        if [ ! -f "$KEY_PROPERTIES_SOURCE_FILE" ]; then echo "ERREUR: Fichier propriétés de clé '$KEY_PROPERTIES_SOURCE_FILE' introuvable !"; exit 1; fi
        execute_verbose "Copie config de clé" cp "$KEY_PROPERTIES_SOURCE_FILE" "android/key.properties"
        echo "Config signature pour '$ENVIRONMENT' ($BUILD_MODE) prête."
    elif [ "$BUILD_MODE" == "release" ]; then
        echo "AVERTISSEMENT: Pas de fichier de propriétés de clé spécifique pour un build 'release' de '$ENVIRONMENT'."
    else
        echo "Build 'debug', utilisera le debug.keystore standard d'Android."
    fi
    echo ""
fi

# MODIFICATION ICI: Ajout de la condition ! $BYPASS_TESTS
if ( $ACTION_BUILD && ( [ "$ENVIRONMENT" == "staging" ] && ! $BYPASS_TESTS ) || [ "$ENVIRONMENT" == "prod" ] ); then
    echo ""; echo ">>> Exécution 'flutter test' pour $ENVIRONMENT <<<"
    execute_verbose "Tests Flutter" flutter test; TEST_RESULT=$?
    if [ $TEST_RESULT -ne 0 ]; then
        if [ "$ENVIRONMENT" == "prod" ]; then echo "ERREUR: 'flutter test' échoué pour 'prod'. Stop."; exit 1;
        else echo "AVERTISSEMENT: 'flutter test' échoué pour 'staging'. Continuation..."; fi
    else echo "'flutter test' réussi pour $ENVIRONMENT."; fi
    echo ""
elif $ACTION_BUILD && $BYPASS_TESTS && [ "$ENVIRONMENT" == "staging" ]; then
    echo ""; echo ">>> AVERTISSEMENT: 'flutter test' évité pour $ENVIRONMENT via --bypasstest <<<"; echo ""
fi

if $ACTION_BUILD; then
    echo ">>> DÉBUT - Build pour $PLATFORM ($ENVIRONMENT) en mode $BUILD_MODE <<<"
        execute_verbose "Flutter Clean" flutter clean
    if [ "$PLATFORM" == "web" ]; then
        echo "Préparation $WEB_INDEX_PATH pour $ENVIRONMENT..."
        if [ ! -f "$WEB_INDEX_TEMPLATE_PATH" ]; then echo "Erreur: Template '$WEB_INDEX_TEMPLATE_PATH' introuvable."; exit 1; fi
        execute_verbose "Copie template index.html" cp "$WEB_INDEX_TEMPLATE_PATH" "$WEB_INDEX_PATH"
        SED_CMD="sed -i.bak \"s|$WEB_INDEX_PLACEHOLDER|$CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB|g\" \"$WEB_INDEX_PATH\""
        if [ "$VERBOSE_MODE" = true ]; then echo ">>> Exécution (Remplacement placeholder Google Sign-In): $SED_CMD"; fi
        eval "$SED_CMD"; if [ -f "$WEB_INDEX_PATH.bak" ]; then rm -f "$WEB_INDEX_PATH.bak"; fi
        echo "$WEB_INDEX_PATH configuré."
        echo "Build Flutter Web ($FLUTTER_BUILD_MODE_FLAG)..."
        execute_verbose "Build Flutter Web" flutter build web "$FLUTTER_BUILD_MODE_FLAG" "--dart-define=APP_ENV=$ENVIRONMENT"
        if [ $? -ne 0 ]; then echo "Erreur: Build Flutter Web échoué !"; exit 1; fi
        echo "Build Flutter Web terminé."
    elif [ "$PLATFORM" == "android" ]; then
        echo "Préparation $ANDROID_TARGET_GOOGLE_SERVICES_PATH pour $ENVIRONMENT..."
        execute_verbose "Copie google-services.json" cp "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" "$ANDROID_TARGET_GOOGLE_SERVICES_PATH"
        echo "$ANDROID_TARGET_GOOGLE_SERVICES_PATH configuré."
        if [ "$ARTIFACT_TYPE" == "apk" ]; then
            echo "Build APK Android ($FLUTTER_BUILD_MODE_FLAG)..."
            execute_verbose "Build Flutter APK" flutter build apk "$FLUTTER_BUILD_MODE_FLAG" "--dart-define=APP_ENV=$ENVIRONMENT"
            if [ $? -ne 0 ]; then echo "Erreur: Build Flutter APK échoué !"; exit 1; fi
            echo "Build Flutter APK terminé."
            if [ "$BUILD_MODE" == "release" ]; then ANDROID_ARTIFACT_PATH="build/app/outputs/flutter-apk/app-release.apk"; else ANDROID_ARTIFACT_PATH="build/app/outputs/flutter-apk/app-debug.apk"; fi
        else
            echo "Build App Bundle Android ($FLUTTER_BUILD_MODE_FLAG)..."
            execute_verbose "Build Flutter App Bundle" flutter build appbundle "$FLUTTER_BUILD_MODE_FLAG" "--dart-define=APP_ENV=$ENVIRONMENT"
            if [ $? -ne 0 ]; then echo "Erreur: Build Flutter App Bundle échoué !"; exit 1; fi
            echo "Build Flutter App Bundle terminé."
            if [ "$BUILD_MODE" == "release" ]; then ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/release/app-release.aab"; else ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/debug/app-debug.aab"; fi
        fi
        echo "Artefact: $ANDROID_ARTIFACT_PATH"
    fi
    echo ">>> FIN - Build <<<"; echo ""
fi

if $ACTION_DEPLOY; then
    echo ">>> DEBUT - Déploiement pour $PLATFORM ($ENVIRONMENT) en mode $BUILD_MODE <<<"
    echo "Configuration $TARGET_FIREBASE_JSON_PATH pour $ENVIRONMENT..."
    execute_verbose "Copie config Firebase" cp "$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH" "$TARGET_FIREBASE_JSON_PATH"
    if [ $? -ne 0 ]; then echo "Erreur: Copie de '$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH' vers '$TARGET_FIREBASE_JSON_PATH' échouée."; exit 1; fi
    echo "$TARGET_FIREBASE_JSON_PATH configuré."

    CURRENT_GIT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
    echo "Branche Git actuelle: '$CURRENT_GIT_BRANCH'"
    if [ "$ENVIRONMENT" == "prod" ] && [ "$CURRENT_GIT_BRANCH" != "main" ]; then
        echo "ERREUR: Déploiement 'prod' depuis la branche 'main' uniquement.";
        execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH";
        exit 1
    elif [ "$ENVIRONMENT" == "staging" ] && ! [[ "$CURRENT_GIT_BRANCH" == "main" || "$CURRENT_GIT_BRANCH" == "staging-branch" || "$CURRENT_GIT_BRANCH" == release-candidate/* ]]; then
        echo "ERREUR: Déploiement 'staging' depuis 'main', 'staging-branch' ou 'release-candidate/*'.";
        execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH";
        exit 1
    fi
    echo "Vérification branche OK pour '$ENVIRONMENT' ('$CURRENT_GIT_BRANCH')."

    if [ "$PLATFORM" == "web" ]; then
        echo "Déploiement Web vers Firebase Hosting projet: $CURRENT_FIREBASE_PROJECT_ID..."
        execute_verbose "Déploiement Firebase Web" firebase deploy --only hosting --project "$CURRENT_FIREBASE_PROJECT_ID"
        if [ $? -ne 0 ]; then echo "Erreur: Déploiement Firebase Web échoué !"; execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"; exit 1; fi
        echo "Déploiement Firebase Web terminé."
    elif [ "$PLATFORM" == "android" ]; then
        if [ -z "$ANDROID_ARTIFACT_PATH" ]; then
            if [ "$ARTIFACT_TYPE" == "apk" ]; then
                if [ "$BUILD_MODE" == "release" ]; then ANDROID_ARTIFACT_PATH="build/app/outputs/flutter-apk/app-release.apk"; else ANDROID_ARTIFACT_PATH="build/app/outputs/flutter-apk/app-debug.apk"; fi
            else
                if [ "$BUILD_MODE" == "release" ]; then ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/release/app-release.aab"; else ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/debug/app-debug.aab"; fi
            fi
        fi
        if [ ! -f "$ANDROID_ARTIFACT_PATH" ]; then echo "Erreur: Artefact Android '$ANDROID_ARTIFACT_PATH' introuvable."; execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"; exit 1; fi

        if [ "$ENVIRONMENT" == "prod" ]; then
            echo "Artefact Android Prod ($ARTIFACT_TYPE) prêt: $ANDROID_ARTIFACT_PATH"
            echo "Pour Google Play Store: Téléversement manuel ou via CI/CD dédié."
            if [ -n "$TESTER_GROUPS_PROD" ]; then echo "Distribution vers testeurs prod ($TESTER_GROUPS_PROD) via App Distribution..."; else
                echo "Aucun groupe testeur prod spécifié pour App Distribution. Fin déploiement Android 'prod'."
                execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"; echo ">>> FIN - Déploiement <<<"; echo ""; exit 0
            fi
        else echo "Déploiement $ARTIFACT_TYPE Android vers Firebase App Distribution..."; fi

        echo "Projet Firebase  : $CURRENT_FIREBASE_PROJECT_ID"; echo "ID App Android   : $CURRENT_FIREBASE_ANDROID_APP_ID"
        echo "Groupes Testeurs : $CURRENT_TESTER_GROUPS"; echo "Artefact         : $ANDROID_ARTIFACT_PATH"
        FIREBASE_APP_DIST_CMD="firebase appdistribution:distribute \"$ANDROID_ARTIFACT_PATH\" --app \"$CURRENT_FIREBASE_ANDROID_APP_ID\" --project \"$CURRENT_FIREBASE_PROJECT_ID\" --release-notes \"Build $BUILD_MODE ($ARTIFACT_TYPE) pour $ENVIRONMENT ($PLATFORM) - $(date +'%Y-%m-%d %H:%M')\" --groups \"$CURRENT_TESTER_GROUPS\""
        if [ "$VERBOSE_MODE" = true ]; then echo ">>> Commande (Distribution App Android): $FIREBASE_APP_DIST_CMD"; fi; eval "$FIREBASE_APP_DIST_CMD"
        if [ $? -ne 0 ]; then echo "Erreur: Distribution Firebase App Android échouée ! (Si AAB, vérifiez liaison Google Play)"; execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"; exit 1; fi
        echo "Distribution Firebase App Android terminée."
    fi
    execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"; echo "$TARGET_FIREBASE_JSON_PATH nettoyé."
    echo ">>> FIN - Déploiement <<<"; echo ""
fi

if [ "$PLATFORM" == "android" ] && $ACTION_BUILD && [ "$BUILD_MODE" == "release" ] && [ -f "android/key.properties" ]; then
    echo ""; echo ">>> Nettoyage du fichier de configuration de clé temporaire <<<"
    execute_verbose "Suppression de key.properties" rm "android/key.properties"
    echo "Fichier 'android/key.properties' nettoyé."
fi

echo "Script terminé avec succès."
exit 0
