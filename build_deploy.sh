#!/bin/bash

# --- Configuration - À COMPLÉTER PAR L'UTILISATEUR ---
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
FIREBASE_ANDROID_APP_ID_STAGING="1:344541548510:android:631fa078fb9926677d174f" # Assurez-vous que cette valeur est correcte
FIREBASE_ANDROID_APP_ID_PROD="1:48301164525:android:c3713960cdefdbb28589e4"     # Assurez-vous que cette valeur est correcte

TESTER_GROUPS_DEV="dev-testers"
TESTER_GROUPS_STAGING="uat-testers"
TESTER_GROUPS_PROD="prod-final-checkers"

WEB_INDEX_TEMPLATE_PATH="web/index-template.html"
WEB_INDEX_PATH="web/index.html"
WEB_INDEX_PLACEHOLDER="##GOOGLE_SIGNIN_CLIENT_ID_PLACEHOLDER##"
# --- Fin de la Configuration ---

ENVIRONMENT="dev"
PLATFORM="web"
ARTIFACT_TYPE="aab" # Nouveau: aab ou apk, par défaut aab
ACTION_BUILD=false
ACTION_DEPLOY=false
USER_SPECIFIED_BUILD_MODE=""
VERBOSE_MODE=false

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
    echo "Usage: $0 -e <dev|staging|prod> --platform <web|android> [-a <aab|apk>] [-m <debug|release>] [--build] [--deploy] [--verbose]"
    echo ""
    echo "Options:"
    echo "  -e <environnement>     Spécifie l'environnement. Défaut: dev."
    echo "  --platform <web|android> Spécifie la plateforme. Défaut: web."
    echo "  -a <aab|apk>           Spécifie le type d'artefact Android (aab ou apk). Défaut: aab."
    echo "  -m <mode>              Spécifie le mode de build (debug|release)."
    echo "                         Par défaut: 'debug' pour 'dev', 'release' pour les autres."
    echo "  --build                Exécute l'étape de build."
    echo "  --deploy               Exécute l'étape de déploiement."
    echo "  --verbose, -v          Affiche les commandes exécutées."
    echo ""
    echo "Si ni --build ni --deploy n'est spécifié, le script affichera cet usage."
    echo "Pour 'prod', --deploy requiert la branche 'main' et la réussite de 'flutter test'."
    echo "Pour 'staging', --deploy autorise 'main', 'staging-branch' ou 'release-candidate/*' et 'flutter test' est exécuté (échec non bloquant)."
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
        *) echo "Erreur : Type d'artefact invalide '$ARTIFACT_TYPE' pour Android. Doit être aab ou apk."; usage ;;
    esac
fi

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
if [ "$PLATFORM" == "android" ]; then
    echo "Type d'Artefact Android : $ARTIFACT_TYPE"
fi
echo "Mode de Build           : $BUILD_MODE (Flag: $FLUTTER_BUILD_MODE_FLAG)"
echo "Action Build            : $ACTION_BUILD"
echo "Action Déploiement      : $ACTION_DEPLOY"
echo "Mode Verbose            : $VERBOSE_MODE"
echo "--------------------------------------------------"
echo ""

execute_verbose() {
    local cmd_description="$1"; shift
    local cmd_to_execute=("$@")
    if [ "$VERBOSE_MODE" = true ]; then
        printf ">>> Exécution (%s):" "$cmd_description"
        for arg in "${cmd_to_execute[@]}"; do printf " %q" "$arg"; done
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
    echo "ERREUR : Le GOOGLE_SIGNIN_CLIENT_ID_WEB pour '$ENVIRONMENT' n'est pas configuré."
    exit 1
fi
if [[ "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" == YOUR_* || ! -f "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" ]] && [ "$PLATFORM" == "android" ] && $ACTION_BUILD; then
    echo "ERREUR : Fichier google-services.json '$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH' introuvable ou non configuré."
    exit 1
fi
if [[ "$CURRENT_FIREBASE_ANDROID_APP_ID" == YOUR_* ]] && [ "$PLATFORM" == "android" ] && $ACTION_DEPLOY; then
    echo "ERREUR : Le FIREBASE_ANDROID_APP_ID pour '$ENVIRONMENT' n'est pas configuré."
    exit 1
fi
if [[ ! -f "$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH" ]] && $ACTION_DEPLOY; then
    echo "ERREUR : Fichier de configuration Firebase '$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH' pour '$ENVIRONMENT' introuvable."
    exit 1
fi

if $ACTION_BUILD && ( [ "$ENVIRONMENT" == "staging" ] || [ "$ENVIRONMENT" == "prod" ] ); then
    echo ""
    echo ">>> Exécution de 'flutter test' pour l'environnement $ENVIRONMENT <<<"
    execute_verbose "Tests Flutter" flutter test
    TEST_RESULT=$?
    if [ $TEST_RESULT -ne 0 ]; then
        if [ "$ENVIRONMENT" == "prod" ]; then
            echo "ERREUR : 'flutter test' a échoué pour 'prod'. Build et déploiement annulés."
            exit 1
        else
            echo "AVERTISSEMENT : 'flutter test' a échoué pour 'staging'. Continuation..."
        fi
    else
        echo "'flutter test' réussi pour $ENVIRONMENT."
    fi
    echo ""
fi

if $ACTION_BUILD; then
    echo ">>> DÉBUT - Build pour $PLATFORM ($ENVIRONMENT) en mode $BUILD_MODE <<<"
    if [ "$PLATFORM" == "web" ]; then
        echo "Préparation de $WEB_INDEX_PATH pour $ENVIRONMENT..."
        if [ ! -f "$WEB_INDEX_TEMPLATE_PATH" ]; then echo "Erreur : Template '$WEB_INDEX_TEMPLATE_PATH' introuvable."; exit 1; fi
        execute_verbose "Copie template index.html" cp "$WEB_INDEX_TEMPLATE_PATH" "$WEB_INDEX_PATH"
        SED_CMD="sed -i.bak \"s|$WEB_INDEX_PLACEHOLDER|$CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB|g\" \"$WEB_INDEX_PATH\""
        if [ "$VERBOSE_MODE" = true ]; then echo ">>> Exécution (Remplacement placeholder Google Sign-In): $SED_CMD"; fi
        eval "$SED_CMD"
        if [ -f "$WEB_INDEX_PATH.bak" ]; then rm -f "$WEB_INDEX_PATH.bak"; fi
        echo "$WEB_INDEX_PATH configuré avec ID Client : $CURRENT_GOOGLE_SIGNIN_CLIENT_ID_WEB"
        echo "Build Flutter Web pour $ENVIRONMENT en mode $BUILD_MODE..."
        execute_verbose "Build Flutter Web" flutter build web "$FLUTTER_BUILD_MODE_FLAG" "--dart-define=APP_ENV=$ENVIRONMENT"
        if [ $? -ne 0 ]; then echo "Erreur : Build Flutter Web échoué !"; exit 1; fi
        echo "Build Flutter Web terminé."
    elif [ "$PLATFORM" == "android" ]; then
        echo "Préparation de $ANDROID_TARGET_GOOGLE_SERVICES_PATH pour $ENVIRONMENT..."
        execute_verbose "Copie google-services.json" cp "$CURRENT_GOOGLE_SERVICES_JSON_SOURCE_PATH" "$ANDROID_TARGET_GOOGLE_SERVICES_PATH"
        echo "$ANDROID_TARGET_GOOGLE_SERVICES_PATH configuré."

        if [ "$ARTIFACT_TYPE" == "apk" ]; then
            echo "Build de l'APK Flutter Android pour $ENVIRONMENT en mode $BUILD_MODE..."
            execute_verbose "Build Flutter APK" flutter build apk "$FLUTTER_BUILD_MODE_FLAG" "--dart-define=APP_ENV=$ENVIRONMENT"
            if [ $? -ne 0 ]; then echo "Erreur : Le build Flutter APK a échoué !"; exit 1; fi
            echo "Build Flutter APK terminé."
            if [ "$BUILD_MODE" == "release" ]; then
                ANDROID_ARTIFACT_PATH="build/app/outputs/flutter-apk/app-release.apk"
            else # debug
                ANDROID_ARTIFACT_PATH="build/app/outputs/flutter-apk/app-debug.apk"
            fi
        else # appbundle
            echo "Build de l'App Bundle Flutter Android pour $ENVIRONMENT en mode $BUILD_MODE..."
            execute_verbose "Build Flutter App Bundle" flutter build appbundle "$FLUTTER_BUILD_MODE_FLAG" "--dart-define=APP_ENV=$ENVIRONMENT"
            if [ $? -ne 0 ]; then echo "Erreur : Le build Flutter App Bundle a échoué !"; exit 1; fi
            echo "Build Flutter App Bundle terminé."
            if [ "$BUILD_MODE" == "release" ]; then
                ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/release/app-release.aab"
            else # debug
                ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/debug/app-debug.aab"
            fi
        fi
        echo "Artefact disponible : $ANDROID_ARTIFACT_PATH"
    fi
    echo ">>> FIN - Build <<<"
    echo ""
fi

if $ACTION_DEPLOY; then
    echo ">>> DEBUT - Déploiement pour $PLATFORM ($ENVIRONMENT) en mode $BUILD_MODE <<<"

    echo "Configuration de $TARGET_FIREBASE_JSON_PATH pour $ENVIRONMENT..."
    execute_verbose "Copie configuration Firebase" cp "$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH" "$TARGET_FIREBASE_JSON_PATH"
    if [ $? -ne 0 ]; then echo "Erreur : Copie de '$CURRENT_FIREBASE_CONFIG_FILE_SOURCE_PATH' vers '$TARGET_FIREBASE_JSON_PATH' échouée."; exit 1; fi
    echo "$TARGET_FIREBASE_JSON_PATH configuré."

    CURRENT_GIT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
    echo "Branche Git actuelle : '$CURRENT_GIT_BRANCH'"
    if [ "$ENVIRONMENT" == "prod" ]; then
        if [ "$CURRENT_GIT_BRANCH" != "main" ]; then
            echo "ERREUR : Déploiement 'prod' DOIT être depuis la branche 'main'."
            execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"; exit 1
        else
            echo "Vérification branche OK pour 'prod' (main)."
        fi
    elif [ "$ENVIRONMENT" == "staging" ]; then
        if [[ "$CURRENT_GIT_BRANCH" == "main" || "$CURRENT_GIT_BRANCH" == "staging-branch" || "$CURRENT_GIT_BRANCH" == release-candidate/* ]]; then
            echo "Vérification branche OK pour 'staging' ('$CURRENT_GIT_BRANCH')."
        else
            echo "ERREUR : Déploiement 'staging' doit être depuis 'main', 'staging-branch' ou 'release-candidate/*'."
            execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"; exit 1
        fi
    fi

    if [ "$PLATFORM" == "web" ]; then
        echo "Déploiement Web vers Firebase Hosting projet : $CURRENT_FIREBASE_PROJECT_ID..."
        execute_verbose "Déploiement Firebase Web" firebase deploy --only hosting --project "$CURRENT_FIREBASE_PROJECT_ID"
        DEPLOY_RESULT=$?
        if [ $DEPLOY_RESULT -ne 0 ]; then
            echo "Erreur : Déploiement Firebase Web échoué !"
            execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH après échec" rm -f "$TARGET_FIREBASE_JSON_PATH"; exit 1
        fi
        echo "Déploiement Firebase Web terminé."
    elif [ "$PLATFORM" == "android" ]; then
        if [ -z "$ANDROID_ARTIFACT_PATH" ]; then # Si --build n'a pas été exécuté dans ce run
            if [ "$ARTIFACT_TYPE" == "apk" ]; then
                if [ "$BUILD_MODE" == "release" ]; then
                    ANDROID_ARTIFACT_PATH="build/app/outputs/flutter-apk/app-release.apk"
                else
                    ANDROID_ARTIFACT_PATH="build/app/outputs/flutter-apk/app-debug.apk"
                fi
            else # aab
                if [ "$BUILD_MODE" == "release" ]; then
                    ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/release/app-release.aab"
                else
                    ANDROID_ARTIFACT_PATH="build/app/outputs/bundle/debug/app-debug.aab"
                fi
            fi
        fi
        if [ ! -f "$ANDROID_ARTIFACT_PATH" ]; then
            echo "Erreur : Artefact Android '$ANDROID_ARTIFACT_PATH' introuvable. Exécutez --build avec mode (-m $BUILD_MODE) et type (-a $ARTIFACT_TYPE) ?"
            execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"; exit 1
        fi

        if [ "$ENVIRONMENT" == "prod" ]; then
            echo "L'artefact Android de Production ($ARTIFACT_TYPE) est prêt : $ANDROID_ARTIFACT_PATH"
            echo "Pour Google Play Store: Téléversez-le manuellement ou utilisez votre pipeline CI/CD dédié."
            if [ -n "$TESTER_GROUPS_PROD" ]; then
                 echo "Distribution vers les testeurs de production ($TESTER_GROUPS_PROD) via App Distribution..."
            else
                echo "Aucun groupe de testeurs de production spécifié pour App Distribution. Fin du déploiement Android pour 'prod'."
                execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"
                echo ">>> FIN - Déploiement <<<"; echo ""; exit 0
            fi
        else
            echo "Déploiement $ARTIFACT_TYPE Android vers Firebase App Distribution..."
        fi

        echo "Projet Firebase      : $CURRENT_FIREBASE_PROJECT_ID"
        echo "ID App Android       : $CURRENT_FIREBASE_ANDROID_APP_ID"
        echo "Groupes Testeurs     : $CURRENT_TESTER_GROUPS"
        echo "Artefact             : $ANDROID_ARTIFACT_PATH"

        FIREBASE_APP_DIST_CMD="firebase appdistribution:distribute \"$ANDROID_ARTIFACT_PATH\" \
            --app \"$CURRENT_FIREBASE_ANDROID_APP_ID\" \
            --project \"$CURRENT_FIREBASE_PROJECT_ID\" \
            --release-notes \"Build $BUILD_MODE ($ARTIFACT_TYPE) pour $ENVIRONMENT ($PLATFORM) - $(date +'%Y-%m-%d %H:%M')\" \
            --groups \"$CURRENT_TESTER_GROUPS\""

        if [ "$VERBOSE_MODE" = true ]; then echo ">>> Commande (Distribution App Android): $FIREBASE_APP_DIST_CMD"; fi
        eval "$FIREBASE_APP_DIST_CMD"
        DIST_RESULT=$?
        if [ $DIST_RESULT -ne 0 ]; then
            echo "Erreur : Distribution Firebase App Android échouée !"
            echo "Si c'est un AAB, assurez-vous que le projet Firebase est lié à Google Play."
            execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH après échec" rm -f "$TARGET_FIREBASE_JSON_PATH"; exit 1
        fi
        echo "Distribution Firebase App Android terminée."
    fi

    execute_verbose "Nettoyage $TARGET_FIREBASE_JSON_PATH" rm -f "$TARGET_FIREBASE_JSON_PATH"
    echo "$TARGET_FIREBASE_JSON_PATH nettoyé."
    echo ">>> FIN - Déploiement <<<"
    echo ""
fi

echo "Script terminé avec succès."
exit 0
