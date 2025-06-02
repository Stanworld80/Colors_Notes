// migrate_firestore_userid.js
const admin = require('firebase-admin');

// ---- CONFIGURATION ----
// Remplacez par le chemin vers votre fichier de clé de compte de service
const SERVICE_ACCOUNT_KEY_PATH = 'D:/Keystore/ColorsNotes/firebase-adminsdk/colors-notes-dev-7cab4a333b2d.json';

// Remplacez par l'ID de votre projet Firebase cible
const FIREBASE_PROJECT_ID = 'colors-notes-dev'; // EXEMPLE: 'colors-notes-dev', 'colors-notes-staging', etc.

// IDs utilisateur à traiter
const OLD_USER_ID = 'ANCIEN_USER_ID_A_REMPLACER'; // À REMPLIR
const NEW_USER_ID = 'NOUVEAU_USER_ID_DE_REMPLACEMENT'; // À REMPLIR

// Liste des collections à analyser et mettre à jour.
// Pour chaque collection, spécifiez le nom du champ qui contient le userId.
const COLLECTIONS_AND_FIELDS_TO_UPDATE = [
  { name: 'journals',       field: 'userId' },
  { name: 'notes',          field: 'userId' },
  { name: 'paletteModels',  field: 'userId' } // Mettra à jour les modèles de palette de l'ancien utilisateur
  // Ajoutez d'autres collections et/ou champs si nécessaire
  // { name: 'autreCollection', field: 'proprietaireId' },
];

// Optionnel: Vérifier si le nouveauUserID existe dans la collection 'users' avant de commencer.
const VALIDATE_NEW_USER_EXISTS = true;
// ---- FIN DE LA CONFIGURATION ----

if (OLD_USER_ID === 'ANCIEN_USER_ID_A_REMPLACER' || NEW_USER_ID === 'NOUVEAU_USER_ID_DE_REMPLACEMENT') {
  console.error("ERREUR: Veuillez configurer OLD_USER_ID et NEW_USER_ID dans le script.");
  process.exit(1);
}
if (OLD_USER_ID === NEW_USER_ID) {
  console.error("ERREUR: OLD_USER_ID et NEW_USER_ID ne peuvent pas être identiques.");
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_KEY_PATH);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: FIREBASE_PROJECT_ID,
});

const db = admin.firestore();
const BATCH_LIMIT = 400; // Limite de Firestore pour les opérations en lot est 500

async function main() {
  console.log(`--- Démarrage du script de migration d'UserID pour le projet: ${FIREBASE_PROJECT_ID} ---`);
  console.log(`  Ancien UserID : ${OLD_USER_ID}`);
  console.log(`  Nouveau UserID: ${NEW_USER_ID}`);
  console.log(`ATTENTION: Ce script va MODIFIER des documents de manière permanente.`);
  console.log(`Assurez-vous d'avoir une SAUVEGARDE et d'avoir testé sur un environnement de non-production.`);
  console.log(`Les collections/champs suivants seront analysés pour mise à jour :`);
  COLLECTIONS_AND_FIELDS_TO_UPDATE.forEach(cf => console.log(`  - Collection: ${cf.name}, Champ: ${cf.field}`));
  console.log(`----------------------------------------------------------------\n`);

  // Simuler une demande de confirmation (décommentez pour l'utilisation réelle)
  // const readline = require('readline').createInterface({ input: process.stdin, output: process.stdout });
  // const answer = await new Promise(resolve => readline.question(`Êtes-vous sûr de vouloir remplacer toutes les occurrences de '${OLD_USER_ID}' par '${NEW_USER_ID}' dans le projet '${FIREBASE_PROJECT_ID}'? (oui/NON): `, resolve));
  // readline.close();
  // if (answer.toLowerCase() !== 'oui') {
  //   console.log("Opération annulée par l'utilisateur.");
  //   return;
  // }

  if (VALIDATE_NEW_USER_EXISTS) {
    console.log(`Vérification de l'existence du nouveau UserID '${NEW_USER_ID}' dans la collection 'users'...`);
    const newUserDoc = await db.collection('users').doc(NEW_USER_ID).get();
    if (!newUserDoc.exists) {
      console.error(`ERREUR: Le nouveau UserID '${NEW_USER_ID}' n'existe pas dans la collection 'users'. Arrêt du script.`);
      console.error(`Veuillez vérifier que le document /users/${NEW_USER_ID} existe.`);
      return;
    }
    console.log(`  Confirmation : Le nouveau UserID '${NEW_USER_ID}' existe.`);
  }

  let totalDocumentsScannedOverall = 0;
  let totalDocumentsUpdatedOverall = 0;

  for (const config of COLLECTIONS_AND_FIELDS_TO_UPDATE) {
    const collectionName = config.name;
    const fieldName = config.field;

    console.log(`\nTraitement de la collection : '${collectionName}', champ '${fieldName}'...`);
    let collectionDocsScanned = 0;
    let collectionDocsUpdated = 0;
    let batch = db.batch();
    let batchSize = 0;

    // Requête pour trouver les documents avec l'ancien UserID dans le champ spécifié
    const querySnapshot = await db.collection(collectionName).where(fieldName, '==', OLD_USER_ID).get();

    if (querySnapshot.empty) {
      console.log(`  Aucun document trouvé dans '${collectionName}' avec ${fieldName} = '${OLD_USER_ID}'.`);
      continue;
    }

    console.log(`  Trouvé ${querySnapshot.size} documents à mettre à jour dans '${collectionName}'.`);

    for (const doc of querySnapshot.docs) {
      collectionDocsScanned++;
      totalDocumentsScannedOverall++;

      // console.log(`  Mise à jour du document ${collectionName}/${doc.id}: champ '${fieldName}' de '${OLD_USER_ID}' vers '${NEW_USER_ID}'.`);
      batch.update(doc.ref, { [fieldName]: NEW_USER_ID });
      collectionDocsUpdated++;
      totalDocumentsUpdatedOverall++;
      batchSize++;

      if (batchSize >= BATCH_LIMIT) {
        try {
          await batch.commit();
          console.log(`    Lot de ${batchSize} mises à jour validé pour '${collectionName}'.`);
        } catch (error) {
          console.error(`    ERREUR lors de la validation du lot pour '${collectionName}':`, error);
          console.error("Arrêt du script à cause d'une erreur de lot. Certaines modifications pourraient ne pas avoir été appliquées.");
          return; // Arrêter en cas d'erreur de lot
        }
        batch = db.batch(); // Nouveau lot
        batchSize = 0;
      }
    }

    if (batchSize > 0) {
      try {
        await batch.commit();
        console.log(`    Lot final de ${batchSize} mises à jour validé pour '${collectionName}'.`);
      } catch (error) {
        console.error(`    ERREUR lors de la validation du lot final pour '${collectionName}':`, error);
        console.error("Certaines modifications pour cette collection pourraient avoir échoué.");
      }
    }
    console.log(`  Collection '${collectionName}' : ${collectionDocsScanned} documents analysés (correspondant au critère), ${collectionDocsUpdated} documents mis à jour.`);
  }

  console.log(`\n--- Migration d'UserID terminée pour le projet: ${FIREBASE_PROJECT_ID} ---`);
  console.log(`Total de documents analysés (correspondant au critère OLD_USER_ID): ${totalDocumentsScannedOverall}`);
  console.log(`Total de documents mis à jour                               : ${totalDocumentsUpdatedOverall}`);
  console.log(`---------------------------------------------------------------------`);
}

main().catch(error => {
  console.error("Une erreur critique est survenue durant l'exécution du script:", error);
  process.exit(1);
});