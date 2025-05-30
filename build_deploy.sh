#!/bin/bash

# --- Configuration - À COMPLÉTER PAR L'UTILISATEUR ---
# IDs de Projet Firebase (Google Cloud Project IDs)
FIREBASE_PROJECT_ID_DEV="colors-notes-dev"
FIREBASE_PROJECT_ID_STAGING="colors-notes-staging"
FIREBASE_PROJECT_ID_PROD="colors-notes-prod"

# Fichiers de configuration Firebase par environnement
FIREBASE_CONFIG_FILE_DEV="firebase.dev.json"
FIREBASE_CONFIG_FILE_STAGING="firebase.staging.json"
FIREBASE_CONFIG_FILE_PROD="firebase.prod.json"
TARGET_FIREBASE_JSON_PATH="firebase.json" # Nom du fichier que Firebase CLI attend

# IDs Client Google Sign-In pour le Web (depuis Google Cloud Console pour chaque projet)
GOOGLE_SIGNIN_CLIENT_ID_WEB_DEV="83241971458-14tiragdibb39tnm9op5nd6fqnm4ct53.apps.googleusercontent.com"
GOOGLE_SIGNIN_CLIENT_ID_WEB_STAGING="344541548510-k1vncr9ufjii7r3k4425p8sqgq5p47r6.apps.googleusercontent.com"
GOOGLE_SIGNIN_CLIENT_ID_WEB_PROD="48301164525-6lqqh5tc0m0jpsm4ovdpgalosve17a1m.apps.googleusercontent.com"

# Chemins vers vos fichiers google-services.json par environnement
GOOGLE_SERVICES_JSON_DEV_PATH="android/app/google-services.dev.json"
GOOGLE_SERVICES_JSON_STAGING_PATH="android/app/google-services.staging.json"
GOOGLE_SERVICES_JSON_PROD_PATH="android/app/google-services.prod.json"
ANDROID_TARGET_GOOGLE_SERVICES_PATH="android/app/google-services.json"

# IDs d'Application Android Firebase
FIREBASE_ANDROID_APP_ID_DEV="1:83241971458:android:dde10259edb60d45711c1b"
FIREBASE_ANDROID_APP_ID_STAGING="VOTRE_ID_APP_ANDROID_FIREBASE_STAGING" # Assurez-vous que cette valeur est correcte
FIREBASE_ANDROID_APP_ID_PROD="VOTRE_ID_APP_ANDROID_FIREBASE_PROD"     # Assurez-vous que cette valeur est correcte

# Groupes de Testeurs pour Firebase App Distribution
TESTER_GROUPS_DEV="dev-testers"
TESTER_GROUPS_STAGING="uat-testers"
TESTER_GROUPS_PROD="prod-final-checkers"

# Configuration pour web/index.html
WEB_INDEX_TEMPLATE_PATH="web/index-template.html"
WEB_INDEX_PATH="web/index.html"
WEB_INDEX_PLACEHOLDER="##GOOGLE_SIGNIN_CLIENT_ID_PLACEHOLDER##"
# --- Fin de la Configuration ---

# Valeurs par défaut pour les arguments
ENVIRONMENT="dev"
PLATFORM="web"
ACTION_BUILD=false
ACTION_DEPLOY=false
USER_SPECIFIED_BUILD_MODE=""
VERBOSE_MODE=false

# Variables qui seront définies en fonction de l'environnement
CURRENT_FIREBASE_PROJECT_ID=""
CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB=""
CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH=""
CURRENT_FIREBASE_ANDROID_APP_ID=""
CURRENT_TESTER_GROUPS=""
CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH="" # Pour le fichier firebase.ENV.json
FLUTTER_BUILD_MODE_FLAG=""
ANDROID_ARTIFACT_PATH=""
BUILD_MODE=""

usage() {
    echo "Usage: $0 -e <dev|staging|prod> --platform <web|android> [-m <debug|release>] [--build] [--deploy] [--verbose]"
    echo ""
    echo "Options:"
    echo "  -e <environnement>     Spécifie l'environnement. Défaut: dev."
    echo "  --platform <web|android> Spécifie la plateforme. Défaut: web."
    echo "  -m <mode>              Spécifie le mode de build (debug|release)."
    echo "                         Par défaut: 'debug' pour l'env 'dev', 'release' pour les autres."
    echo "  --build                Exécute l'étape de build."
    echo "  --deploy               Exécute l'étape de déploiement."
    echo "  --verbose, -v          Affiche les commandes exécutées."
    echo ""
    echo "Si ni --build ni --deploy n'est spécifié, le script affichera cet usage."
    echo "Pour l'environnement 'prod', l'option --deploy requiert d'être sur la branche 'main' et que 'flutter test' réussisse."
    echo "Pour l'environnement 'staging', l'option --deploy autorise les branches 'main', 'staging-branch' ou 'release-candidate/*' et 'flutter test' est exécuté (échec non bloquant)."
    exit 1
}

# Analyse des arguments de la ligne de commande
TEMP_ENV=""
TEMP_PLATFORM=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -e)
            TEMP_ENV="$2"
            shift
            ;;
        --platform)
            TEMP_PLATFORM="$2"
            shift
            ;;
        -m|--mode)
            USER_SPECIFIED_BUILD_MODE="$2"
            shift
            ;;
        --build)
            ACTION_BUILD=true
            ;;
        --deploy)
            ACTION_DEPLOY=true
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Paramètre inconnu: $1"
            usage
            ;;
    esac
    shift
done

if [ -n "$TEMP_ENV" ]; then ENVIRONMENT="$TEMP_ENV"; fi
if [ -n "$TEMP_PLATFORM" ]; then PLATFORM="$TEMP_PLATFORM"; fi

if [ -n "$USER_SPECIFIED_BUILD_MODE" ]; then
    BUILD_MODE="$USER_SPECIFIED_BUILD_MODE"
else
    if [ "$ENVIRONMENT" == "dev" ]; then
        BUILD_MODE="debug"
    else
        BUILD_MODE="release"
    fi
fi

case "$BUILD_MODE" in
    debug) FLUTTER_BUILD_MODE_FLAG="--debug" ;;
    release) FLUTTER_BUILD_MODE_FLAG="--release" ;;
    *) echo "Erreur : Mode de build invalide '$BUILD_MODE'. Doit être debug ou release."; usage ;;
esac

if ! $ACTION_BUILD && ! $ACTION_DEPLOY; then
    echo "Erreur : Au moins une action (--build ou --deploy) doit être spécifiée."
    usage
fi

case "$ENVIRONMENT" in
    dev|staging|prod) ;;
    *) echo "Erreur : Environnement invalide '$ENVIRONMENT'. Doit être dev, staging, ou prod."; usage ;;
esac

case "$PLATFORM" in
    web|android) ;;
    *) echo "Erreur : Plateforme invalide '$PLATFORM'. Doit être web ou android."; usage ;;
esac

echo "--------------------------------------------------"
echo "Environnement Sélectionné : $ENVIRONMENT"
echo "Plateforme Sélectionnée  : $PLATFORM"
echo "Mode de Build           : $BUILD_MODE (Flag: $FLUTTER_BUILD_MODE_FLAG)"
echo "Action Build            : $ACTION_BUILD"
echo "Action Déploiement      : $ACTION_DEPLOY"
echo "Mode Verbose            : $VERBOSE_MODE"
echo "--------------------------------------------------"
echo ""

execute_verbose() {
    local cmd_description="$1"
    shift
    local cmd_to_execute=("$@")

    if [ "$VERBOSE_MODE" = true ]; then
        printf ">>> Exécution (%s):" "$cmd_description"
        for arg in "${cmd_to_execute[@]}"; do
            printf " %q" "$arg"
        done
        printf "\n"
    fi
    "${cmd_to_execute[@]}"
    return $?
}

case "$ENVIRONMENT" in
    dev)
        CURRENT_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID_DEV"
        CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB="$GOOGLE_SIGNIN_CLIENT_ID_WEB_DEV"
        CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH="$GOOGLE_SERVICES_JSON_DEV_PATH"
        CURRENT_FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID_DEV"
        CURRENT_TESTER_GROUPS="$TESTER_GROUPS_DEV"
        CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH="$FIREBASE_CONFIG_FILE_DEV"
        ;;
    staging)
        CURRENT_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID_STAGING"
        CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB="$GOOGLE_SIGNIN_CLIENT_ID_WEB_STAGING"
        CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH="$GOOGLE_SERVICES_JSON_STAGING_PATH"
        CURRENT_FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID_STAGING"
        CURRENT_TESTER_GROUPS="$TESTER_GROUPS_STAGING"
        CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH="$FIREBASE_CONFIG_FILE_STAGING"
        ;;
    prod)
        CURRENT_FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID_PROD"
        CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB="$GOOGLE_SIGNIN_CLIENT_ID_WEB_PROD"
        CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH="$GOOGLE_SERVICES_JSON_PROD_PATH"
        CURRENT_FIREBASE_ANDROID_APP_ID="$FIREBASE_ANDROID_APP_ID_PROD"
        CURRENT_TESTER_GROUPS="$TESTER_GROUPS_PROD"
        CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH="$FIREBASE_CONFIG_FILE_PROD"
        ;;
esac

if [[ "$CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB" == YOUR_* ]] && [ "$PLATFORM" == "web" ]; then
    echo "ERREUR : Le GOOGLE_SIGNIN_CLIENT_ID_WEB pour l'environnement '$ENVIRONMENT' n'est pas configuré."
    exit 1
fi
if [[ "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" == YOUR_* || ! -f "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" ]] && [ "$PLATFORM" == "android" ] && $ACTION_BUILD; then
    echo "ERREUR : Le fichier source google-services.json '$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH' est introuvable ou non configuré."
    exit 1
fi
if [[ "$CURRENT_FIREBASE_ANDROID_APP_ID" == YOUR_* ]] && [ "$PLATFORM" == "android" ] && $ACTION_DEPLOY; then
    echo "ERREUR : Le FIREBASE_ANDROID_APP_ID pour l'environnement '$ENVIRONMENT' n'est pas configuré."
    exit 1
fi
if [[ ! -f "$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH" ]] && $ACTION_DEPLOY; then # Vérifier si le fichier firebase.ENV.json existe
    echo "ERREUR : Le fichier de configuration Firebase '$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH' pour l'environnement '$ENVIRONMENT' est introuvable."
    exit 1
fi


if $ACTION_BUILD && ( [ "$ENVIRONMENT" == "staging" ] || [ "$ENVIRONMENT" == "prod" ] ); then
    echo ""
    echo ">>> Exécution de 'flutter test' pour l'environnement $ENVIRONMENT <<<"
    execute_verbose "Tests Flutter" flutter test
    TEST_RESULT=$?
    if [ $TEST_RESULT -ne 0 ]; then
        if [ "$ENVIRONMENT" == "prod" ]; then
            echo "ERREUR : 'flutter test' a échoué pour l'environnement 'prod'. Build et déploiement annulés."
            exit 1
        else
            echo "AVERTISSEMENT : 'flutter test' a échoué pour l'environnement 'staging'. Le script continuera, mais veuillez vérifier les tests."
        fi
    else
        echo "'flutter test' réussi pour l'environnement $ENVIRONMENT."
    fi
    echo ""
fi

if $ACTION_BUILD; then
    echo ">>> DÉBUT - Étape de Build pour $PLATFORM ($ENVIRONMENT) en mode $BUILD_MODE <<<"
    if [ "$PLATFORM" == "web" ]; then
        echo "Préparation de $WEB_INDEX_PATH pour $ENVIRONMENT..."
        if [ ! -f "$WEB_INDEX_TEMPLATE_PATH" ]; then
            echo "Erreur : Le fichier template '$WEB_INDEX_TEMPLATE_PATH' est introuvable."
            exit 1
        fi
        execute_verbose "Copie du template index.html" cp "$WEB_INDEX_TEMPLATE_PATH" "$WEB_INDEX_PATH"
        SED_CMD="sed -i.bak \"s|$WEB_INDEX_PLACEHOLDER|$CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB|g\" \"$WEB_INDEX_PATH\""
        if [ "$VERBOSE_MODE" = true ]; then
            echo ">>> Exécution (Remplacement placeholder Google Sign-In): $SED_CMD"
        fi
        eval "$SED_CMD"
        if [ -f "$WEB_INDEX_PATH.bak" ]; then rm -f "$WEB_INDEX_PATH.bak"; fi
        echo "$WEB_INDEX_PATH configuré avec l'ID Client : $CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB"
        echo "Build de l'application Flutter Web pour $ENVIRONMENT en mode $BUILD_MODE..."
        execute_verbose "Build Flutter Web" flutter build web "$FLUTTER_BUILD_MODE_FLAG" "--dart-define=APP_ENV=$ENVIRONMENT"
        if [ $? -ne 0 ]; then echo "Erreur : Le build Flutter Web a échoué !"; exit 1; fi
        echo "Build Flutter Web terminé."
    elif [ "$PLATFORM" == "android" ]; then
        echo "Préparation de $ANDROID_TARGET_GOOGLE_SERVICES_PATH pour $ENVIRONMENT..."
        execute_verbose "Copie google-services.json" cp "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" "$ANDROID_TARGET_GOOGLE_SERVICES_PATH"
        echo "$ANDROID_TARGET_GOOGLE_SERVICES_PATH configuré."
        echo "Build de l'App Bundle Flutter Android pour $ENVIRONMENT en mode $BUILD_MODE..."
        execute_verbose "Build Flutter Android" flutter build appbundle "$FLUTTER_BUILD_MODE_FLAG" "--dart-define=APP_ENV=$ENVIRONMENT"
        if [ $? -ne 0 ]; then echo "Erreur : Le build Flutter Android a échoué !"; exit 1; fi
        echo "Build Flutter Android terminé."
        if [ "$BUILD_MODE" == "release" ]; then
            ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/release/app-release.aab"
        else
            ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/debug/app-debug.aab"
        fi
        echo "Artefact disponible ici : $ANDROID_ARTIFACT_PATH"
    fi
    echo ">>> FIN - Étape de Build <<<"
    echo ""
fi

if $ACTION_DEPLOY; then
    echo ">>> DEBUT - Étape de Déploiement pour $PLATFORM ($ENVIRONMENT) en mode $BUILD_MODE <<<"

    # Copier le fichier firebase.ENV.json vers firebase.json
    echo "Configuration de $TARGET_FIREBASE_JSON_PATH pour l'environnement $ENVIRONMENT..."
    execute_verbose "Copie de la configuration Firebase" cp "$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH" "$TARGET_FIREBASE_JSON_PATH"
    if [ $? -ne 0 ]; then
        echo "Erreur : La copie de '$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH' vers '$TARGET_FIREBASE_JSON_PATH' a échoué."
        exit 1
    fi
    echo "$TARGET_FIREBASE_JSON_PATH configuré."

    CURRENT_GIT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
    echo "Branche Git actuelle détectée : '$CURRENT_GIT_BRANCH'"
    if [ "$ENVIRONMENT" == "prod" ]; then
        if [ "$CURRENT_GIT_BRANCH" != "main" ]; then
            echo "ERREUR : Le déploiement vers l'environnement 'prod' DOIT se faire depuis la branche 'main'."
            echo "Branche actuelle : '$CURRENT_GIT_BRANCH'."
            execute_verbose "Nettoyage de $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH" # Nettoyage en cas d'erreur
            exit 1
        else
            echo "Vérification de la branche OK pour 'prod' (branche 'main')."
        fi
    elif [ "$ENVIRONMENT" == "staging" ]; then
        if [[ "$CURRENT_GIT_BRANCH" == "main" || "$CURRENT_GIT_BRANCH" == "staging-branch" || "$CURRENT_GIT_BRANCH" == release-candidate/* ]]; then
            echo "Vérification de la branche OK pour 'staging' (branche '$CURRENT_GIT_BRANCH')."
        else
            echo "ERREUR : Le déploiement vers l'environnement 'staging' doit se faire depuis la branche 'main', 'staging-branch' ou une branche 'release-candidate/*'."
            echo "Branche actuelle : '$CURRENT_GIT_BRANCH'."
            execute_verbose "Nettoyage de $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH" # Nettoyage en cas d'erreur
            exit 1
        fi
    fi

    if [ "$PLATFORM" == "web" ]; then
        echo "Déploiement Web vers Firebase Hosting projet : $CURRENT_FIREBASE_PROJECT_ID..."
        execute_verbose "Déploiement Firebase Web" firebase deploy --only hosting --project "$CURRENT_FIREBASE_PROJECT_ID"
        DEPLOY_RESULT=$?
        if [ $DEPLOY_RESULT -ne 0 ]; then
            echo "Erreur : Le déploiement Firebase Web a échoué !"
            execute_verbose "Nettoyage de $TARGET_FIREBASE_JSON_PATH après échec" rm -f "$TARGET_FIREBASE_JSON_PATH"
            exit 1
        fi
        echo "Déploiement Firebase Web terminé."

    elif [ "$PLATFORM" == "android" ]; then
        if [ -z "$ANDROID_ARTIFACT_PATH" ]; then
            if [ "$BUILD_MODE" == "release" ]; then
                ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/release/app-release.aab"
            else
                ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/debug/app-debug.aab"
            fi
        fi
        if [ ! -f "$ANDROID_ARTIFACT_PATH" ]; then
            echo "Erreur : L'artefact Android '$ANDROID_ARTIFACT_PATH' est introuvable. Avez-vous exécuté --build avec le bon mode (-m $BUILD_MODE) ?"
            execute_verbose "Nettoyage de $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH" # Nettoyage en cas d'erreur
            exit 1
        fi
        echo "Déploiement de l'App Bundle Android vers Firebase App Distribution..."
        echo "Projet Firebase      : $CURRENT_FIREBASE_PROJECT_ID"
        echo "ID App Android Firebase: $CURRENT_FIREBASE_ANDROID_APP_ID"
        echo "Groupes de Testeurs  : $CURRENT_TESTER_GROUPS"
        echo "Artefact             : $ANDROID_ARTIFACT_PATH"

        FIREBASE_APP_DIST_CMD="firebase appdistribution:distribute \"$ANDROID_ARTIFACT_PATH\" \
            --app \"$CURRENT_FIREBASE_ANDROID_APP_ID\" \
            --project \"$CURRENT_FIREBASE_PROJECT_ID\" \
            --release-notes \"Build $BUILD_MODE pour $ENVIRONMENT ($PLATFORM) - $(date +'%Y-%m-%d %H:%M')\" \
            --groups \"$CURRENT_TESTER_GROUPS\""

        if [ "$VERBOSE_MODE" = true ]; then
            echo ">>> Commande (Distribution App Android Firebase): $FIREBASE_APP_DIST_CMD"
        fi
        eval "$FIREBASE_APP_DIST_CMD"
        DIST_RESULT=$?

        if [ $DIST_RESULT -ne 0 ]; then
            echo "Erreur : La distribution Firebase App Android a échoué !"
            execute_verbose "Nettoyage de $TARGET_FIREBASE_JSON_PATH après échec" rm -f "$TARGET_FIREBASE_JSON_PATH"
            exit 1
        fi
        echo "Distribution Firebase App Android terminée."
    fi

    # Nettoyage du fichier firebase.json temporaire
    execute_verbose "Nettoyage de $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"
    echo "$TARGET_FIREBASE_JSON_PATH nettoyé."

    echo ">>> FIN - Étape de Déploiement <<<"
    echo ""
fi

echo "Script terminé avec succès."
exit 0
