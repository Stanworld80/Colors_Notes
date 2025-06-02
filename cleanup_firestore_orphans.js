// cleanup_firestore_orphans.js
const admin = require('firebase-admin');

// ---- CONFIGURATION ----
// Remplacez par le chemin vers votre fichier de clé de compte de service
const SERVICE_ACCOUNT_KEY_PATH = 'D:/Keystore/ColorsNotes/firebase-adminsdk/colors-notes-dev-7cab4a333b2d.json'; //dev
//const SERVICE_ACCOUNT_KEY_PATH = 'D:/Keystore/ColorsNotes/firebase-adminsdk/colors-notes-staging-db04f9d707bc.json'; //staging
//const SERVICE_ACCOUNT_KEY_PATH = 'D:/Keystore/ColorsNotes/firebase-adminsdk/colors-notes-prod-b4de21352f1d.json'; //prod
// Remplacez par l'ID de votre projet Firebase cible (celui que vous voulez nettoyer)
const FIREBASE_PROJECT_ID = 'colors-notes-dev'; // EXEMPLE: 'colors-notes-dev', 'colors-notes-staging', etc.

// Liste des collections à analyser et nettoyer.
// NE PAS inclure 'users' ici car c'est la source de vérité.
const COLLECTIONS_TO_CLEAN = [
  'journals',
  'notes',
  'paletteModels'
];
// Définissez si les modèles de palette prédéfinis (ceux avec isPredefined: true) doivent être ignorés.
// En général, oui, car leur 'userId' pourrait être null ou ne pas correspondre à un utilisateur réel.
const IGNORE_PREDEFINED_PALETTE_MODELS = true;
// ---- FIN DE LA CONFIGURATION ----

const serviceAccount = require(SERVICE_ACCOUNT_KEY_PATH);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: FIREBASE_PROJECT_ID,
});

const db = admin.firestore();
const BATCH_LIMIT = 400; // Firestore batch limit is 500, using 400 for safety

async function main() {
  console.log(`--- Démarrage du script de nettoyage pour le projet: ${FIREBASE_PROJECT_ID} ---`);
  console.log(`ATTENTION: Ce script va supprimer des documents de manière permanente.`);
  console.log(`Assurez-vous d'avoir une SAUVEGARDE de votre base de données avant de continuer.`);
  console.log(`Les collections suivantes seront analysées : ${COLLECTIONS_TO_CLEAN.join(', ')}`);
  console.log(`----------------------------------------------------------------\n`);

  // Simuler une demande de confirmation (décommentez pour l'utilisation réelle)
  // const readline = require('readline').createInterface({ input: process.stdin, output: process.stdout });
  // const answer = await new Promise(resolve => readline.question(`Êtes-vous absolument sûr de vouloir continuer sur le projet '${FIREBASE_PROJECT_ID}'? (oui/NON): `, resolve));
  // readline.close();
  // if (answer.toLowerCase() !== 'oui') {
  //   console.log("Opération annulée par l'utilisateur.");
  //   return;
  // }

  console.log('Récupération de tous les IDs utilisateurs valides...');
  const usersSnapshot = await db.collection('users').get();
  const validUserIds = new Set(usersSnapshot.docs.map(doc => doc.id));
  console.log(`Trouvé ${validUserIds.size} utilisateurs valides.`);
  if (validUserIds.size === 0) {
    console.warn("AVERTISSEMENT: Aucun utilisateur valide trouvé dans la collection 'users'. Le script pourrait supprimer beaucoup de données. Vérifiez votre collection 'users'.");
    // Vous pourriez vouloir arrêter le script ici si c'est inattendu.
    // return;
  }

  let totalDocumentsScanned = 0;
  let totalDocumentsDeleted = 0;

  for (const collectionName of COLLECTIONS_TO_CLEAN) {
    console.log(`\nTraitement de la collection : ${collectionName}...`);
    let collectionDocsScanned = 0;
    let collectionDocsDeleted = 0;
    let batch = db.batch();
    let batchSize = 0;

    const collectionRef = db.collection(collectionName);
    // Pour de très grandes collections, envisagez d'utiliser .stream() ou des requêtes paginées.
    // Pour la simplicité, .get() est utilisé ici.
    const snapshot = await collectionRef.get();

    if (snapshot.empty) {
      console.log(`  La collection '${collectionName}' est vide.`);
      continue;
    }

    for (const doc of snapshot.docs) {
      collectionDocsScanned++;
      totalDocumentsScanned++;
      const data = doc.data();

      // Logique spécifique pour 'paletteModels' pour ignorer les prédéfinis
      if (collectionName === 'paletteModels' && IGNORE_PREDEFINED_PALETTE_MODELS && data.isPredefined === true) { // [cite: 1135]
        // console.log(`  Ignoré : Modèle de palette prédéfini ${collectionName}/${doc.id}.`);
        continue;
      }

      // Vérifier le champ 'userId'
      if (data && typeof data.userId === 'string' && data.userId.trim() !== '') {
        if (!validUserIds.has(data.userId)) {
          console.log(`  À SUPPRIMER : Document ${collectionName}/${doc.id} a un userId invalide ('${data.userId}').`);
          batch.delete(doc.ref);
          collectionDocsDeleted++;
          totalDocumentsDeleted++;
          batchSize++;

          if (batchSize >= BATCH_LIMIT) {
            try {
              await batch.commit();
              console.log(`    Lot de ${batchSize} suppressions validé pour '${collectionName}'.`);
            } catch (error) {
              console.error(`    ERREUR lors de la validation du lot pour '${collectionName}':`, error);
              // Arrêter ou gérer l'erreur (ex: réessayer, logguer les IDs échoués)
              // Pour la simplicité, nous allons arrêter. Vous pouvez implémenter une logique plus robuste.
              console.error("Arrêt du script à cause d'une erreur de lot.");
              return;
            }
            batch = db.batch(); // Nouveau lot
            batchSize = 0;
          }
        }
      } else if (data && data.hasOwnProperty('userId')) {
         // Le champ userId existe mais est null, vide, ou pas une chaîne.
         // Selon votre règle "ayant pour valeur un document existant", ces cas ne correspondent pas,
         // car ils n'ont pas une *valeur* qui *devrait* exister mais *n'existe pas*.
         // Vous pourriez vouloir logguer ces cas pour investigation manuelle si un userId est attendu.
        // console.log(`  INFO: Document ${collectionName}/${doc.id} a un champ userId présent mais null, vide ou d'un type incorrect: '${data.userId}'. Ignoré.`);
      } else {
        // Le document n'a pas de champ 'userId'. Il est conservé selon la règle.
        // console.log(`  INFO: Document ${collectionName}/${doc.id} n'a pas de champ 'userId'. Conservé.`);
      }
    }

    if (batchSize > 0) {
      try {
        await batch.commit();
        console.log(`    Lot final de ${batchSize} suppressions validé pour '${collectionName}'.`);
      } catch (error) {
        console.error(`    ERREUR lors de la validation du lot final pour '${collectionName}':`, error);
        console.error("Certaines suppressions pour cette collection pourraient avoir échoué.");
      }
    }
    console.log(`  Collection '${collectionName}' : ${collectionDocsScanned} documents analysés, ${collectionDocsDeleted} documents supprimés.`);
  }

  console.log(`\n--- Nettoyage terminé pour le projet: ${FIREBASE_PROJECT_ID} ---`);
  console.log(`Total documents analysés : ${totalDocumentsScanned}`);
  console.log(`Total documents supprimés : ${totalDocumentsDeleted}`);
  console.log(`---------------------------------------------------------`);
}

main().catch(error => {
  console.error("Une erreur critique est survenue durant l'exécution du script:", error);
  process.exit(1);
});