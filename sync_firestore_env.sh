#!/bin/bash

# Script pour synchroniser les données Firestore ET les utilisateurs Firebase Authentication
# entre différents environnements Firebase.
# Vise à préserver les UIDs, y compris pour Google Sign-In.

# --- Configuration des IDs de Projet Firebase (Google Cloud Project IDs) ---
PROJECT_ID_DEV="colors-notes-dev"
PROJECT_ID_STAGING="colors-notes-staging"
PROJECT_ID_PROD="colors-notes-prod"

# --- Configuration des Paramètres de Hachage pour Firebase Auth Import ---
# IMPORTANT: Récupérez ces valeurs DEPUIS VOTRE PROJET SOURCE si vous avez des utilisateurs Email/Mot de passe.
# Console Firebase > Authentication > Sign-in method > (tout en bas) Informations sur l'algorithme de hachage de mot de passe.
# Si votre projet source n'utilise QUE Google Sign-In (ou d'autres fournisseurs OAuth) et AUCUN utilisateur par email/mot de passe,
# les valeurs par défaut pour SCRYPT pourraient fonctionner, mais il est plus sûr d'utiliser les valeurs réelles si disponibles.
# L'algorithme par défaut pour les nouveaux projets Firebase est SCRYPT.
AUTH_IMPORT_HASH_ALGO="SCRYPT" # Ex: SCRYPT, STANDARD_SCRYPT, HMAC_SHA512, MD5, etc. (SCRYPT est le plus courant)
AUTH_IMPORT_HASH_KEY="oZZpErOKEvydLeQ3knzXXEfY1kXStUB7XnzCWrC/SDLiqm7nY+wQFmrAQtu9WoB1t1dwR5K8AYh+d0En2h7MIQ==" # Clé encodée en Base64
AUTH_IMPORT_SALT_SEPARATOR="Bw==" # Séparateur de sel encodé en Base64 (souvent vide si non spécifié)
AUTH_IMPORT_ROUNDS="8" # Généralement 8 pour SCRYPT
AUTH_IMPORT_MEM_COST="14" # Généralement 14 pour SCRYPT
# Pour les autres algos (HMAC_SHA512, etc.), seuls HASH_ALGO et HASH_KEY sont généralement nécessaires.
# Les options --salt-separator, --rounds, --mem-cost sont spécifiques à SCRYPT.
# --- Fin de la Configuration ---

set -e # Quitte immédiatement si une commande échoue
set -u # Traite les variables non définies comme une erreur
set -o pipefail # Fait échouer le pipeline si une commande échoue

# Fonction pour afficher l'usage
usage() {
    echo "Usage: $0 -s <dev|staging|prod|ID_PROJET_SOURCE> -d <dev|staging|prod|ID_PROJET_DESTINATION>"
    echo ""
    echo "Options:"
    echo "  -s <environnement_source>    Spécifie l'alias de l'environnement source (dev, staging, prod) ou l'ID direct du projet Firebase."
    echo "  -d <environnement_destination> Spécifie l'alias de l'environnement de destination (dev, staging, prod) ou l'ID direct du projet Firebase."
    echo ""
    echo "Le nom du bucket d'export Firestore sera automatiquement déterminé comme '[ID_PROJET_SOURCE]-exports'."
    echo "Les données d'authentification seront exportées dans un fichier local 'users_auth_data.json'."
    echo ""
    echo "PRÉREQUIS IMPORTANTS:"
    echo "  1. 'gcloud' et 'firebase' CLIs installées et configurées."
    echo "  2. Connectez-vous à Firebase CLI: 'firebase login'."
    echo "  3. Le projet de destination DOIT avoir Google Sign-In configuré avec les bons ID clients OAuth."
    echo "  4. Le projet de destination DEVRAIT avoir le fournisseur 'Email/Mot de passe' activé pour l'importation Auth."
    echo "  5. Permissions IAM et Firebase appropriées pour l'export/import Auth et Firestore."
    echo "  6. Configurez les variables AUTH_IMPORT_* en haut de ce script avec les valeurs de votre projet SOURCE."
    echo ""
    echo "Exemple: $0 -s staging -d dev"
    exit 1
}

# Variables pour les arguments
SOURCE_ENV_OR_ID=""
DEST_ENV_OR_ID=""
AUTH_EXPORT_FILE="users_auth_data.json" # Fichier temporaire pour les données d'authentification

# Analyse des arguments
while getopts ":s:d:h" opt; do
  case ${opt} in
    s ) SOURCE_ENV_OR_ID=$OPTARG ;;
    d ) DEST_ENV_OR_ID=$OPTARG ;;
    h ) usage ;;
    \? ) echo "Option invalide: -$OPTARG" 1>&2; usage ;;
    : ) echo "L'option -$OPTARG requiert un argument." 1>&2; usage ;;
  esac
done
shift $((OPTIND -1))

# Validation des arguments
if [ -z "$SOURCE_ENV_OR_ID" ] || [ -z "$DEST_ENV_OR_ID" ]; then
    echo "Erreur : Les environnements/IDs de projet source et destination doivent être spécifiés."
    usage
fi
if [ "$AUTH_IMPORT_HASH_KEY" == "VOTRE_CLE_SIGNATAIRE_EN_BASE64_DU_PROJET_SOURCE" ]; then
    echo "ERREUR: Veuillez configurer AUTH_IMPORT_HASH_KEY et potentiellement d'autres variables AUTH_IMPORT_* en haut du script."
    usage
fi


# Fonction pour obtenir l'ID de projet Firebase basé sur l'alias d'environnement ou utiliser la valeur directe
get_project_id() {
    local env_or_id=$1
    case $env_or_id in
        dev) echo "$PROJECT_ID_DEV" ;;
        staging) echo "$PROJECT_ID_STAGING" ;;
        prod) echo "$PROJECT_ID_PROD" ;;
        *) echo "$env_or_id";;
    esac
}

SOURCE_PROJECT_ID=$(get_project_id "$SOURCE_ENV_OR_ID")
DEST_PROJECT_ID=$(get_project_id "$DEST_ENV_OR_ID")

if [ -z "$SOURCE_PROJECT_ID" ]; then echo "Erreur : ID de projet source invalide pour '$SOURCE_ENV_OR_ID'."; usage; fi
if [ -z "$DEST_PROJECT_ID" ]; then echo "Erreur : ID de projet de destination invalide pour '$DEST_ENV_OR_ID'."; usage; fi
if [ "$SOURCE_PROJECT_ID" == "$DEST_PROJECT_ID" ]; then echo "Erreur : Le projet source et de destination ne peuvent pas être identiques."; usage; fi

SOURCE_FIRESTORE_EXPORT_BUCKET_NAME="${SOURCE_PROJECT_ID}-exports"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
FIRESTORE_EXPORT_FOLDER_NAME="firestore-full-backup-${TIMESTAMP}"
FIRESTORE_EXPORT_PATH="gs://${SOURCE_FIRESTORE_EXPORT_BUCKET_NAME}/${FIRESTORE_EXPORT_FOLDER_NAME}"

echo "---------------------------------------------------------------------"
echo "Script de Synchronisation Firebase (Auth & Firestore)"
echo "---------------------------------------------------------------------"
echo "Projet Source          : $SOURCE_PROJECT_ID (Alias/Input: $SOURCE_ENV_OR_ID)"
echo "Projet Destination     : $DEST_PROJECT_ID (Alias/Input: $DEST_ENV_OR_ID)"
echo "Bucket Export Firestore: $SOURCE_FIRESTORE_EXPORT_BUCKET_NAME"
echo "Chemin Export Firestore: $FIRESTORE_EXPORT_PATH"
echo "Fichier Export Auth    : $AUTH_EXPORT_FILE (sera créé localement)"
echo "Algo Hachage Auth Import: $AUTH_IMPORT_HASH_ALGO"
echo "---------------------------------------------------------------------"
echo ""
echo "Prérequis Importants (rappel) :"
echo "  - 'firebase login' doit avoir été exécuté."
echo "  - Le projet destination ($DEST_PROJECT_ID) doit avoir Google Sign-In correctement configuré."
echo "  - Il est recommandé d'activer le fournisseur 'Email/Mot de passe' dans le projet destination ($DEST_PROJECT_ID) avant l'importation Auth."
echo "  - Les variables AUTH_IMPORT_* en haut du script doivent être correctement configurées avec les valeurs du projet SOURCE."
echo "  - Permissions IAM (GCP) et Firebase nécessaires pour les opérations."
echo "  - Le compte de service Firestore de '$DEST_PROJECT_ID' doit avoir accès en lecture au bucket '$SOURCE_FIRESTORE_EXPORT_BUCKET_NAME'."
echo ""

# Confirmation
echo "ATTENTION : Cette opération va EXPORTER les utilisateurs et les données Firestore de '$SOURCE_PROJECT_ID'"
echo "et les IMPORTER dans '$DEST_PROJECT_ID'."
echo "L'importation des utilisateurs peut créer de nouveaux utilisateurs ou mettre à jour des utilisateurs existants."
echo "L'importation Firestore ÉCRASERA toutes les données existantes dans le projet Firestore de destination ($DEST_PROJECT_ID) qui sont en conflit avec les données importées."
read -p "Êtes-vous sûr de vouloir continuer? (oui/NON): " CONFIRMATION
if [ "$CONFIRMATION" != "oui" ]; then
    echo "Opération annulée par l'utilisateur."
    exit 0
fi

# Sauvegarder le projet gcloud et firebase actifs
ORIGINAL_GCLOUD_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
# ORIGINAL_FIREBASE_PROJECT=$(firebase projects:list | grep "(current)" | awk '{print $1}' 2>/dev/null || echo "") # Moins fiable
echo "Projet gcloud actuel (avant modification) : '$ORIGINAL_GCLOUD_PROJECT'"
# echo "Projet Firebase CLI actuel (avant modification) : '$ORIGINAL_FIREBASE_PROJECT'"


# --- ÉTAPE 1: EXPORTATION DES UTILISATEURS AUTH ---
echo ""
echo ">>> Étape 1: Exportation des utilisateurs Firebase Auth depuis '$SOURCE_PROJECT_ID' vers '$AUTH_EXPORT_FILE'..."
firebase auth:export "$AUTH_EXPORT_FILE" --project "$SOURCE_PROJECT_ID" --format=json
if [ $? -ne 0 ]; then
    echo "Erreur lors de l'exportation des utilisateurs depuis $SOURCE_PROJECT_ID."
    exit 1
fi
echo "Exportation des utilisateurs depuis '$SOURCE_PROJECT_ID' terminée avec succès vers '$AUTH_EXPORT_FILE'."


# --- ÉTAPE 2: EXPORTATION DES DONNÉES FIRESTORE ---
echo ""
echo ">>> Étape 2: Exportation des données Firestore depuis '$SOURCE_PROJECT_ID' vers '$FIRESTORE_EXPORT_PATH'..."
gcloud config set project "$SOURCE_PROJECT_ID"
echo "Projet gcloud actif configuré sur : $SOURCE_PROJECT_ID"

gcloud firestore export "$FIRESTORE_EXPORT_PATH" --quiet
if [ $? -ne 0 ]; then
    echo "Erreur lors de l'exportation des données Firestore depuis $SOURCE_PROJECT_ID."
    if [ -n "$ORIGINAL_GCLOUD_PROJECT" ]; then gcloud config set project "$ORIGINAL_GCLOUD_PROJECT"; echo "Projet gcloud restauré à : $ORIGINAL_GCLOUD_PROJECT"; fi
    exit 1
fi
echo "Exportation Firestore depuis '$SOURCE_PROJECT_ID' terminée avec succès."


# --- ÉTAPE 3: IMPORTATION DES UTILISATEURS AUTH ---
echo ""
echo ">>> Étape 3: Importation des utilisateurs Firebase Auth depuis '$AUTH_EXPORT_FILE' vers '$DEST_PROJECT_ID'..."
echo "ATTENTION: Cela peut créer de nouveaux utilisateurs ou mettre à jour des utilisateurs existants dans $DEST_PROJECT_ID."
read -p "Confirmez-vous l'importation des utilisateurs vers $DEST_PROJECT_ID? (oui/NON): " CONFIRM_AUTH_IMPORT
if [ "$CONFIRM_AUTH_IMPORT" != "oui" ]; then
    echo "Importation des utilisateurs annulée. Le script va s'arrêter."
    if [ -n "$ORIGINAL_GCLOUD_PROJECT" ]; then gcloud config set project "$ORIGINAL_GCLOUD_PROJECT"; echo "Projet gcloud restauré à : $ORIGINAL_GCLOUD_PROJECT"; fi
    rm -f "$AUTH_EXPORT_FILE"
    exit 0
fi

# Construction des options de hachage pour la commande d'importation
AUTH_IMPORT_OPTIONS="--hash-algo=$AUTH_IMPORT_HASH_ALGO --hash-key=$AUTH_IMPORT_HASH_KEY"
if [ "$AUTH_IMPORT_HASH_ALGO" == "SCRYPT" ] || [ "$AUTH_IMPORT_HASH_ALGO" == "STANDARD_SCRYPT" ]; then
    AUTH_IMPORT_OPTIONS="$AUTH_IMPORT_OPTIONS --rounds=$AUTH_IMPORT_ROUNDS --mem-cost=$AUTH_IMPORT_MEM_COST"
    # Le séparateur de sel est souvent une chaîne vide encodée en Base64, ou spécifique.
    # S'il est réellement vide (pas juste une chaîne vide dans la config Firebase), il ne faut pas le passer.
    # Firebase CLI peut le déduire si les champs salt sont présents dans le JSON.
    # Pour plus de robustesse, on peut vérifier si la variable est non vide avant de l'ajouter.
    if [ -n "$AUTH_IMPORT_SALT_SEPARATOR" ] && [ "$AUTH_IMPORT_SALT_SEPARATOR" != "VOTRE_SEPARATEUR_DE_SEL_EN_BASE64_DU_PROJET_SOURCE" ]; then # Vérifier si ce n'est pas la valeur placeholder et qu'elle est non vide
      AUTH_IMPORT_OPTIONS="$AUTH_IMPORT_OPTIONS --salt-separator=$AUTH_IMPORT_SALT_SEPARATOR"
    fi
fi

# Exécution de la commande avec eval pour gérer correctement les options construites dynamiquement
# shellcheck disable=SC2086 # Les guillemets dans AUTH_IMPORT_OPTIONS sont intentionnels pour eval
eval firebase auth:import "\"$AUTH_EXPORT_FILE\"" --project "\"$DEST_PROJECT_ID\"" $AUTH_IMPORT_OPTIONS

IMPORT_AUTH_STATUS=$?
if [ $IMPORT_AUTH_STATUS -ne 0 ]; then
    echo "Erreur lors de l'importation des utilisateurs vers $DEST_PROJECT_ID (Code: $IMPORT_AUTH_STATUS)."
    echo "Vérifiez les paramètres de hachage et si le fournisseur Email/Mot de passe est activé dans le projet destination."
    if [ -n "$ORIGINAL_GCLOUD_PROJECT" ]; then gcloud config set project "$ORIGINAL_GCLOUD_PROJECT"; echo "Projet gcloud restauré à : $ORIGINAL_GCLOUD_PROJECT"; fi
    # Conserver AUTH_EXPORT_FILE pour investigation
    exit 1
fi
echo "Importation des utilisateurs vers '$DEST_PROJECT_ID' terminée avec succès."
rm -f "$AUTH_EXPORT_FILE"
echo "Fichier local '$AUTH_EXPORT_FILE' supprimé."


# --- ÉTAPE 4: IMPORTATION DES DONNÉES FIRESTORE ---
echo ""
echo ">>> Étape 4: Importation des données Firestore depuis '$FIRESTORE_EXPORT_PATH' vers '$DEST_PROJECT_ID'..."
echo "Cette opération peut prendre du temps et écrasera les données Firestore conflictuelles dans $DEST_PROJECT_ID."
read -p "Confirmez-vous l'importation Firestore vers $DEST_PROJECT_ID? (oui/NON): " CONFIRM_FIRESTORE_IMPORT
if [ "$CONFIRM_FIRESTORE_IMPORT" != "oui" ]; then
    echo "Importation Firestore annulée. Le script va s'arrêter."
    if [ -n "$ORIGINAL_GCLOUD_PROJECT" ]; then gcloud config set project "$ORIGINAL_GCLOUD_PROJECT"; echo "Projet gcloud restauré à : $ORIGINAL_GCLOUD_PROJECT"; fi
    exit 0
fi

gcloud config set project "$DEST_PROJECT_ID"
echo "Projet gcloud actif configuré sur : $DEST_PROJECT_ID"

gcloud firestore import "$FIRESTORE_EXPORT_PATH" --quiet
if [ $? -ne 0 ]; then
    echo "Erreur lors de l'importation des données Firestore vers $DEST_PROJECT_ID."
     if [ -n "$ORIGINAL_GCLOUD_PROJECT" ]; then gcloud config set project "$ORIGINAL_GCLOUD_PROJECT"; echo "Projet gcloud restauré à : $ORIGINAL_GCLOUD_PROJECT"; fi
    exit 1
fi
echo "Importation Firestore vers '$DEST_PROJECT_ID' terminée avec succès."


# Restaurer le projet gcloud original s'il était défini
if [ -n "$ORIGINAL_GCLOUD_PROJECT" ]; then
    gcloud config set project "$ORIGINAL_GCLOUD_PROJECT"
    echo "Projet gcloud restauré à : $ORIGINAL_GCLOUD_PROJECT"
fi

echo ""
echo "---------------------------------------------------------------------"
echo "Opération de synchronisation Firebase (Auth & Firestore) terminée."
echo "Veuillez vérifier les utilisateurs et les données dans le projet de destination: $DEST_PROJECT_ID"
echo "Les fichiers d'export Firestore sont conservés dans : $FIRESTORE_EXPORT_PATH"
echo "---------------------------------------------------------------------"

exit 0
