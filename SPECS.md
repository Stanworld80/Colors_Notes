# Colors & Notes - Spécifications Détaillées

**Version du Document :** 1.3 **Date :** 28 mai 2025 **Application Version :** MVP ~1.3

## **1. Introduction**

Ce document fournit une description technique détaillée de l'application "Colors & Notes" dans sa version MVP actuelle (~1.3). Il est destiné à servir de référence principale pour les développeurs chargés de la maintenance, de l'évolution et de la mise en production de l'application. Il couvre l'architecture générale, les fonctionnalités implémentées, les modèles de données, la logique métier clé, une description des interfaces utilisateur principales, ainsi qu'une proposition pour la mise en production et l'industrialisation des déploiements Web et Android.

L'objectif de "Colors & Notes" est de permettre aux utilisateurs d'organiser des notes en les associant à des couleurs personnalisées, regroupées dans des palettes. Chaque journal possède sa propre instance de palette, indépendante des modèles.

## **2. Architecture Générale**

* **Framework :** Flutter
* **Langage :** Dart
* **Base de données Backend :** Firebase Firestore
* **Authentification :** Firebase Authentication (Email/Mot de passe, Google Sign-In)
* **Hébergement Web :** Firebase Hosting
* **Gestion d'état :** Provider
* **Plateformes Cibles :** Web, Android
* **Gestion de Code Source :** GitHub
* **CI/CD :** GitHub Actions

## **3. MVP Actuel (Version ~1.3)**

La version actuelle de l'application (branche `experimental`, en date du 8 mai 2025) intègre les fonctionnalités suivantes :

### **3.1. Fonctionnalités Principales**

* **Authentification Utilisateur (SF-AUTH-01 à 05)**
    * Inscription et connexion par email et mot de passe.
    * Inscription et connexion via Google Sign-In (fonctionnel sur Web après configuration de `index.html`).
    * Persistance de la session utilisateur.
    * Création automatique du profil utilisateur et d'un premier "Journal par Défaut" avec une palette par défaut lors de la première inscription (centralisé dans `FirestoreService.initializeNewUserData`).
* **Gestion des Journaux**
    * **Création de Journaux (SF-JOURNAL-01) :**
        * À partir d'un journal vierge (avec une palette par défaut ou personnalisée).
        * À partir d'un modèle de palette thématique prédéfini.
        * En copiant un journal existant (copie de la structure et de l'instance de palette).
    * **Sélection du Journal Actif (SF-JOURNAL-02) :** Via un `PopupMenuButton` dans l'AppBar (`DynamicJournalAppBar`), l'état est géré par `ActiveJournalNotifier`.
    * **Renommage de Journaux (SF-JOURNAL-04).**
    * **Suppression de Journaux (SF-JOURNAL-06) :** Avec confirmation et suppression des notes associées.
    * **Mémorisation du dernier journal actif (SF-JOURNAL-03) :** En cours ou à finaliser.
* **Gestion des Notes**
    * **Création et Édition de Notes :** Association d'une note à une couleur/humeur de la palette du journal actif et à un texte.
    * **Liaison Note-Couleur :** Chaque note est liée à un `paletteElementId` unique d'un `ColorData` de la palette du journal. La modification d'une couleur (titre, valeur hex) dans la palette met à jour dynamiquement l'apparence de toutes les notes liées sans modifier les documents `Note` eux-mêmes.
    * **Édition Date/Heure de l'Événement :** Le champ `eventTimestamp` d'une note est modifiable par l'utilisateur.
    * **Affichage des Notes (`NoteListPage`) :**
        * **Vue Grille/Liste (SF-VIEW-02) :** Bouton pour basculer entre une vue liste et une vue grille dense.
        * **Couleur de Fond :** Les cartes des notes utilisent la couleur associée comme fond, avec ajustement automatique de la couleur du texte pour la lisibilité.
        * **Tri des Notes :** Boutons dédiés pour trier par date d'événement, date de création, contenu et ordre des couleurs de la palette du journal. Indicateur visuel du sens du tri.
* **Gestion des Palettes de Couleurs**
    * **Palette d'Instance :** Chaque journal possède sa propre instance de palette (une liste de `ColorData`).
    * **Modèles de Palettes (`PaletteModel`) :**
        * Modèles prédéfinis (`predefined_templates.dart`).
        * Modèles personnels créés et gérés par l'utilisateur (`PaletteModelManagementPage`, `EditPaletteModelPage` en mode création/édition de modèle).
    * **Édition de Palette (`EditPaletteModelPage`) :**
        * **Mode Instance :** Modification de la palette du journal actif (accessible via l'icône palette dans `DynamicJournalAppBar`).
        * **Mode Modèle :** Création/Modification des `PaletteModel` personnels.
        * Ajout, modification (titre, couleur via sélecteur), suppression de couleurs (`ColorData`).
        * Validation pour empêcher l'ajout de couleurs en double (basée sur la valeur hexadécimale) au sein d'une même palette.
        * Le champ titre de la couleur est vide par défaut lors de l'ajout.
    * **Suppression de Couleur dans une Instance (SF-PALETTE-07a) :** Interdite si la couleur (identifiée par son `paletteElementId`) est utilisée par au moins une note dans le journal.
* **Interface Utilisateur (UI) et Expérience Utilisateur (UX)**
    * **AppBar Dynamique (`DynamicJournalAppBar`) :** Affiche le nom du journal actif, permet la sélection du journal, l'accès à l'édition de la palette du journal actif et la déconnexion.
    * **Page d'Accueil (`LoggedHomepage`) :** Affiche une grille des couleurs de la palette du journal actif. Un clic sur une couleur navigue vers `EntryPage` pour créer une note avec cette couleur présélectionnée. Cohérence visuelle avec la grille des notes.
    * **Navigation :** Utilisation de `Navigator` pour la navigation entre les écrans.
    * **Feedback Utilisateur :** Messages d'erreur et de confirmation via `SnackBar` ou dialogues.
* **Technique**
    * **Logging :** Utilisation du package `logger` pour le suivi des opérations et erreurs dans les services et certaines pages.
    * **Initialisation Centralisée :** La création du document utilisateur et du premier journal est gérée dans `FirestoreService`.
    * **Règles Firestore :** Ajustées pour `paletteModels` et `notes` pour permettre les opérations CRUD nécessaires.

### **3.2. Modèles de Données (Firebase Firestore)**

Les données sont structurées dans les collections Firestore suivantes :

* **`users`**

    * Document ID : `uid` de l'utilisateur Firebase Authentication.
    * Champs :
        * `uid` (String) : Identifiant unique de l'utilisateur.
        * `email` (String) : Adresse e-mail de l'utilisateur.
        * `displayName` (String, optionnel) : Nom d'affichage.
        * `creationDate` (Timestamp) : Date de création du compte.
        * `activeJournalId` (String, optionnel) : ID du dernier journal actif (pour SF-JOURNAL-03).


* **`journals`**

    * Sous-collection de `users/{userId}/journals`.
    * Document ID : ID unique généré (e.g., par `uuid`).
    * Champs :
        * `id` (String) : Identifiant unique du journal.
        * `userId` (String) : ID de l'utilisateur propriétaire.
        * `name` (String) : Nom du journal.
        * `creationDate` (Timestamp) : Date de création du journal.
        * `lastModifiedDate` (Timestamp) : Date de dernière modification.
        * `palette` (Map) : Instance de la palette du journal.
            * `id` (String) : ID unique de la palette (peut être le même que le journalId ou un uuid).
            * `name` (String) : Nom de la palette (e.g., "Palette de [Nom du Journal]").
            * `colors` (List) : Liste des couleurs de la palette. Chaque élément est un `ColorData`.
                * `id` (String) : ID unique de la couleur au sein de la palette (e.g., `uuid`). *Note : Ce champ est présent dans le modèle Dart `ColorData`, sa persistance exacte en tant que `id` distinct du `paletteElementId` dans Firestore est à confirmer. Le `paletteElementId` est crucial.*
                * `paletteElementId` (String) : **Identifiant fonctionnel unique** d'un élément de couleur au sein de cette instance de palette (généré via `uuid`). Utilisé pour lier les notes.
                * `title` (String) : Nom/label de la couleur (e.g., "Joyeux", "Travail").
                * `hexColor` (String) : Valeur hexadécimale de la couleur (e.g., "#FF0000").


* **`notes`**

    * Sous-collection de `journals/{journalId}/notes`.
    * Document ID : ID unique généré (e.g., par `uuid`).
    * Champs :
        * `id` (String) : Identifiant unique de la note.
        * `journalId` (String) : ID du journal auquel la note appartient.
        * `userId` (String) : ID de l'utilisateur propriétaire.
        * `content` (String) : Texte de la note.
        * `paletteElementId` (String) : Référence à l'identifiant unique (`paletteElementId`) de la `ColorData` dans la `palette` du `journal` parent.
        * `creationDate` (Timestamp) : Date de création de la note.
        * `eventTimestamp` (Timestamp) : Date de l'événement associé à la note (modifiable par l'utilisateur).


* **`paletteModels`**

    * Collection racine.
    * Document ID : ID unique généré (e.g., par `uuid`) ou nom descriptif pour les modèles prédéfinis.
    * Champs :
        * `id` (String) : Identifiant unique du modèle de palette.
        * `userId` (String, optionnel) : ID de l'utilisateur créateur si c'est un modèle personnel. `null` ou une valeur spéciale pour les modèles prédéfinis.
        * `name` (String) : Nom du modèle de palette.
        * `isPredefined` (bool) : `true` si c'est un modèle fourni par l'application, `false` sinon.
        * `colors` (List) : Liste des `ColorData` du modèle.
            * `id` (String) : ID unique de la couleur au sein du modèle (e.g., `uuid`).
            * `title` (String) : Nom/label de la couleur.
            * `hexColor` (String) : Valeur hexadécimale de la couleur.
            * *Note : `paletteElementId` n'est pas stocké dans `PaletteModel` car il est spécifique à une instance de palette dans un `Journal`.*

### **3.3. Modèles de Données (Classes Dart)**

Les classes Dart correspondantes se trouvent dans `lib/models/` :

* `app_user.dart` : `AppUser` (pour `users`)
* `journal.dart` : `Journal` (pour `journals`)
* `palette.dart` : `Palette` (représente l'instance de palette dans un `Journal`)
* `color_data.dart` : `ColorData` (pour les couleurs dans `Palette` et `PaletteModel`)
* `note.dart` : `Note` (pour `notes`)
* `palette_model.dart` : `PaletteModel` (pour `paletteModels`)

### **3.4. Logique Métier Clé**

* **Création de Journal :**
    * **Vierge :** Un nouveau `Journal` est créé avec une palette par défaut (e.g., quelques couleurs basiques) ou une palette entièrement nouvelle définie par l'utilisateur. Chaque `ColorData` dans la nouvelle palette d'instance reçoit un `paletteElementId` unique.
    * **Depuis Modèle (`PaletteModel`) :** Le `Journal` est créé, et sa `palette` est initialisée en copiant les `ColorData` du `PaletteModel` sélectionné. Chaque `ColorData` copié dans l'instance de palette du journal reçoit un nouveau `paletteElementId` unique.
    * **Depuis Journal Existant :** Le `Journal` est créé, son nom est initialisé (e.g., "Copie de [Nom Ancien Journal]"). Sa `palette` est une copie profonde de la palette du journal source. Chaque `ColorData` copié dans la nouvelle instance de palette reçoit un nouveau `paletteElementId` unique. Les notes ne sont PAS copiées.
* **Liaison Note-Couleur et Mise à Jour "Gratuite" :**
    * Lors de la création d'une note, le `paletteElementId` de la `ColorData` sélectionnée dans la palette du journal actif est stocké dans le document `Note`.
    * Lors de l'affichage d'une note, sa couleur est récupérée en recherchant la `ColorData` avec le `paletteElementId` correspondant dans la `palette` du `Journal` courant.
    * Si l'utilisateur modifie le `title` ou `hexColor` d'une `ColorData` dans la palette d'un journal (via `EditPaletteModelPage` en mode instance), seul le document `Journal` (contenant la palette) est mis à jour. Toutes les notes existantes qui référencent cette `ColorData` via son `paletteElementId` refléteront automatiquement le changement visuel lors de leur prochain affichage, car elles liront les informations de couleur mises à jour depuis la palette du journal.
* **Unicité des `paletteElementId` :** Chaque `ColorData` au sein d'une instance de `Palette` (dans un `Journal`) doit avoir un `paletteElementId` unique. Ceci est assuré par la génération d'un `uuid` lors de l'ajout d'une couleur à une instance de palette ou lors de la création d'une instance de palette (copie depuis modèle/journal).
* **Validation des Couleurs :**
    * Lors de l'édition d'une palette (instance ou modèle), la valeur hexadécimale d'une couleur doit être unique au sein de cette palette.
    * Le titre d'une couleur n'a pas de contrainte d'unicité forte, mais il est recommandé d'éviter les doublons pour la clarté.
* **Suppression de Couleur d'une Palette d'Instance :** Une `ColorData` ne peut être supprimée de la palette d'un journal que si son `paletteElementId` n'est référencé par aucune `Note` dans ce journal. Ceci est vérifié par la méthode `isPaletteElementUsedInNotes` de `FirestoreService` (nécessite un index Firestore composite sur `journalId` et `paletteElementId` dans la collection `notes`).

### **3.5. Description des Visuels (Écrans Principaux)**

* **`SignInPage.dart` / `RegisterPage.dart` :**
    * **Objectif :** Authentification des utilisateurs.
    * **Visuel :** Champs de formulaire standards pour email/mot de passe, boutons de connexion/inscription, et bouton pour l'authentification Google. Liens pour naviguer entre les deux pages.
* **`LoggedHomepage.dart` :**
    * **Objectif :** Page d'accueil après connexion. Afficher les couleurs de la palette du journal actif et permettre la création rapide de notes.
    * **Visuel :** `DynamicJournalAppBar` en haut. En dessous, une grille de boutons. Chaque bouton représente une couleur de la palette du journal actif, affichant le `title` de la couleur et utilisant sa `hexColor` comme fond. Un clic navigue vers `EntryPage`. Boutons flottants ou menu pour accéder à la gestion des journaux et à la liste des notes.
* **`NoteListPage.dart` :**
    * **Objectif :** Afficher et gérer les notes du journal actif.
    * **Visuel :** `DynamicJournalAppBar`. Boutons pour basculer entre vue liste et vue grille. Boutons de tri dédiés avec indicateurs de direction.
        * **Vue Liste :** Chaque note est une carte affichant un extrait du contenu, la date, et la couleur (via le fond de la carte ou un indicateur coloré).
        * **Vue Grille :** Cartes plus petites, optimisées pour la densité, affichant la couleur de fond et potentiellement une icône ou un titre minimal.
* **`EntryPage.dart` :**
    * **Objectif :** Créer ou modifier une note.
    * **Visuel :** Champ de texte multiligne pour le contenu de la note. Sélecteur de couleur (probablement une liste déroulante ou une mini-grille des couleurs de la palette active). Sélecteur de date/heure pour `eventTimestamp`. Bouton de sauvegarde.
* **`JournalManagementPage.dart` :**
    * **Objectif :** Gérer les journaux de l'utilisateur (créer, renommer, supprimer, sélectionner).
    * **Visuel :** Liste des journaux de l'utilisateur. Bouton pour créer un nouveau journal (ouvrant `CreateJournalPage`). Options sur chaque journal pour renommer, supprimer, ou sélectionner comme actif. Bouton pour accéder à `PaletteModelManagementPage`.
* **`CreateJournalPage.dart` :**
    * **Objectif :** Guider l'utilisateur dans la création d'un nouveau journal.
    * **Visuel :** Options pour créer un journal :
        * Vierge (avec choix de palette : par défaut, nouvelle, ou depuis un modèle de palette).
        * Depuis un modèle de palette prédéfini ou personnel.
        * Depuis un journal existant. Champ pour le nom du nouveau journal.
* **`PaletteModelManagementPage.dart` :**
    * **Objectif :** Gérer les modèles de palettes personnels de l'utilisateur.
    * **Visuel :** Liste des modèles de palettes personnels. Bouton pour créer un nouveau modèle (navigue vers `EditPaletteModelPage` en mode création de modèle). Options sur chaque modèle pour éditer ou supprimer.
* **`EditPaletteModelPage.dart` :**
    * **Objectif :** Éditer une instance de palette (du journal actif) ou un modèle de palette.
    * **Visuel :**
        * Champ pour le nom de la palette/modèle (si applicable).
        * Liste des couleurs (`ColorData`) actuelles. Chaque couleur affiche son titre et sa couleur, avec des options pour éditer ou supprimer.
        * Bouton "Ajouter une couleur" : ouvre un dialogue ou une section pour définir le titre et la valeur hexadécimale (via un sélecteur de couleur type `flutter_colorpicker` et un champ texte).
        * Bouton "Enregistrer" (pour le mode modèle, ou si la sauvegarde n'est pas automatique en mode instance).
        * Validation en temps réel ou à la sauvegarde pour l'unicité des `hexColor`.

## **4. Proposition de Mise en Production et Industrialisation**

### **4.1. Infrastructure (Firebase)**

* **Plan Firebase :**
    * Commencer avec le plan Spark (gratuit) pour le lancement et les premiers tests.
    * Prévoir une migration vers le plan Blaze (paiement à l'usage) si l'application gagne en utilisateurs et en données, pour bénéficier de limites plus élevées, de sauvegardes automatiques (via Firestore Scheduled Backups) et potentiellement de Cloud Functions.
* **Règles de Sécurité Firestore :**
    * **Audit Complet :** Réviser toutes les règles de sécurité pour s'assurer qu'elles sont suffisamment restrictives (principe du moindre privilège) tout en permettant les fonctionnalités de l'application.
    * **Validation Côté Serveur :** Utiliser les règles pour valider la structure des données à l'écriture autant que possible (e.g., types de champs, présence de champs obligatoires).
    * **Tests des Règles :** Utiliser l'émulateur Firebase et les outils de test des règles pour valider leur comportement.
* **Cloud Functions (si plan Blaze) :**
    * Envisager pour des tâches de maintenance (nettoyage de données orphelines), des migrations de données complexes, ou des notifications futures.
    * Exemple : Une fonction pour vérifier périodiquement l'intégrité des `paletteElementId` ou pour générer des rapports d'utilisation.
* **Sauvegardes :**
    * **Plan Spark :** Exportations manuelles régulières de Firestore via la console Firebase ou `gcloud`.
    * **Plan Blaze :** Configurer les sauvegardes planifiées automatiques de Firestore. Définir une politique de rétention.
* **Index Firestore :**
    * Surveiller les avertissements d'index manquants dans la console Firebase et les logs.
    * Créer les index composites nécessaires (déjà fait pour certains tris et requêtes, mais à vérifier pour toute nouvelle fonctionnalité).

### **4.2. Déploiement Web**

* **Firebase Hosting :**
    * Continuer à utiliser Firebase Hosting pour sa simplicité et son intégration.
* **Nom de Domaine Personnalisé :**
    * Configurer des noms de domaine personnalisés pour chaque environnement (e.g., `dev.colorsandnotes.com`, `staging.colorsandnotes.com`, `app.colorsandnotes.com`).
* **Optimisations de Performance :**
    * **Build de Production Flutter :** Toujours utiliser `flutter build web --release`.
    * **Renderer :** Tester et choisir le renderer web optimal (HTML ou Canvaskit) en fonction des performances et de la compatibilité visuelle souhaitée. Canvaskit offre une meilleure fidélité mais un bundle plus gros.
    * **Lazy Loading / Code Splitting :** Flutter gère cela automatiquement dans une certaine mesure (deferred loading pour les routes). Explorer des optimisations manuelles si des goulots d'étranglement sont identifiés.
    * **Minification et Compression :** Firebase Hosting gère la compression (gzip/Brotli).
    * **Caching :** Configurer les en-têtes de cache de manière appropriée dans `firebase.json` pour les assets.
* **Progressive Web App (PWA) :**
    * Assurer que le `manifest.json` et le service worker (généré par Flutter) sont correctement configurés pour une expérience PWA optimale (installation sur l'écran d'accueil, capacités hors ligne de base si pertinent).

### **4.3. Déploiement Android**

* **Google Play Store :**
    * Créer un compte développeur Google Play.
    * Préparer les assets graphiques pour la fiche Play Store (icônes, captures d'écran, description).
* **Processus de Build et Signature :**
    * **Build App Bundle (`.aab`) :** Générer un Android App Bundle (`flutter build appbundle --release`) pour bénéficier de la distribution optimisée de Google Play (Dynamic Delivery).
    * **Signature d'Application :** Configurer la signature de l'application avec un keystore sécurisé. **Ne jamais perdre cette clé.** Utiliser la signature d'application par Google Play est recommandé.
* **Gestion des Versions :**
    * Suivre les conventions de versionnage (e.g., `versionName` `X.Y.Z` et `versionCode` incrémental dans `pubspec.yaml` et `build.gradle`).
* **Configuration Spécifique Android :**
    * Vérifier `AndroidManifest.xml` pour les permissions nécessaires, les configurations d'icônes, le nom de l'application, etc.
    * Adapter les icônes de lancement (`mipmap`).
    * Gérer les différentes tailles d'écran et densités si des ajustements spécifiques sont nécessaires au-delà de ce que Flutter fournit.

### **4.4. Industrialisation du Développement (Révisé et Détaillé)**

Cette section détaille le plan d'action pour mettre en place une ingénierie logicielle robuste avec trois environnements.

#### 4.4.1. Gestion de Versions (Git et GitHub)

* **Stratégie de Branches :**
    * `main` : Code de production, stable et testé. Les releases sont créées en taguant cette branche (ex: `vX.Y.Z`). Ne jamais pusher directement sur `main` sauf pour les fusions validées.
    * `develop` : Branche d'intégration continue pour les nouvelles fonctionnalités et corrections. Sert de base pour les déploiements sur l'environnement **`dev`**.
    * `release-candidate/vX.Y.Z` (ou `staging-branch`): Créée à partir de `develop` lorsque `develop` est prête pour une phase de recette plus formelle. Sert de base pour les déploiements sur l'environnement **`staging`**. Peut recevoir des corrections de bugs spécifiques à cette release candidate (qui doivent ensuite être reportées sur `develop`).
    * `feature/<nom-feature>` : Branches pour le développement de nouvelles fonctionnalités. Créées à partir de `develop` et fusionnées dans `develop` via une Pull Request.
    * `fix/<nom-bug>` : Branches pour les corrections de bugs.
        * Pour les bugs non urgents : Créées à partir de `develop`, testées, puis fusionnées dans `develop` via une Pull Request.
        * Pour les **hotfixes** (bugs critiques en production) : Créées à partir du tag de la version concernée sur `main`. Une fois le hotfix testé, il est fusionné dans `main` et un nouveau tag de patch (ex: `vX.Y.Z+1`) est appliqué. Le hotfix doit ensuite être impérativement fusionné dans `develop` et dans toute branche `release-candidate` active.
* **Processus de Release :**
    1.  `develop` est stabilisée (contient les fonctionnalités de la future release).
    2.  Une branche `release-candidate/vX.Y.Z` est créée à partir de `develop`.
    3.  La branche `release-candidate` est déployée sur l'environnement **`staging`** (`colors-notes-staging`).
    4.  Tests de recette et validation par les testeurs externes sur l'environnement `staging`. Les corrections de bugs critiques trouvées sont faites sur `release-candidate` et reportées sur `develop`.
    5.  Une fois la recette validée sur `staging`, la branche `release-candidate/vX.Y.Z` est fusionnée dans `main`.
    6.  La branche `release-candidate/vX.Y.Z` est également fusionnée dans `develop` (pour s'assurer que `develop` contient les dernières corrections de la RC).
    7.  Un tag Git (ex: `v1.3.0`) est appliqué au commit de fusion sur `main`. Ce tag identifie de manière unique la version de production.
    8.  Le workflow de CI/CD pour la production est déclenché par ce tag, déployant sur l'environnement **`prod`** (`colors-notes-prod`).
    9.  Le numéro de build (`versionCode` pour Android, `build_name` pour iOS) est typiquement incrémenté automatiquement par le système de CI/CD lors du build de production.
* **Pull Requests (PR) :**
    * Toute fusion vers `develop`, `release-candidate/*`, et `main` doit passer par une PR.
    * Revue de code obligatoire par au moins un autre développeur.
    * Lier les PRs aux issues GitHub correspondantes.
    * S'assurer que les tests CI passent avant la fusion.
* **Commits :**
    * Utiliser la convention "Conventional Commits" (e.g., `feat: ...`, `fix: ...`, `docs: ...`, `chore: ...`) pour des messages de commit clairs et pour faciliter la génération automatique de changelogs.

#### 4.4.2. Environnements Multiples

* **Projets Firebase :**
    * **`colors-notes-dev`**: Pour le développement quotidien et les tests internes de l'équipe.
        * Services Firebase dédiés (Firestore, Auth, Hosting).
        * Règles de sécurité potentiellement plus permissives pour faciliter les tests.
    * **`colors-notes-staging`**: Pour la préproduction, la recette et les tests par des testeurs externes.
        * Services Firebase dédiés, configurés aussi proche que possible de la production.
        * Règles de sécurité identiques à la production.
        * Peut contenir des données de test représentatives ou une copie anonymisée des données de production (si la politique le permet).
    * **`colors-notes-prod`**: Uniquement pour l'application en production, accessible aux utilisateurs finaux.
        * Services Firebase dédiés avec quotas et configurations de production.
        * Règles de sécurité strictes.
* **Configuration Flutter (`firebase_options.dart`) :**
    * Utiliser `flutterfire configure` pour générer des fichiers d'options distincts pour chaque projet Firebase (ex: `firebase_options_dev.dart`, `firebase_options_staging.dart`, `firebase_options_prod.dart`).
    * La sélection du bon fichier se fera au moment du build via la variable d'environnement `APP_ENV`.
* **Déploiement Web (Firebase Hosting) :**
    * **Dev :** `dev.colorsandnotes.com` (ou similaire) pointant vers le projet `colors-notes-dev`. Déployé depuis la branche `develop`.
    * **Staging :** `staging.colorsandnotes.com` (ou similaire) pointant vers le projet `colors-notes-staging`. Déployé depuis la branche `release-candidate/*`.
    * **Production :** `app.colorsandnotes.com` pointant vers le projet `colors-notes-prod`. Déployé depuis la branche `main` (via un tag `vX.Y.Z`).
* **Déploiement Android (Google Play Console) :**
    * **Test Interne :** Builds de la branche `develop` (utilisant la configuration `colors-notes-dev`).
    * **Alpha/Beta (Recette) :** Builds de la branche `release-candidate/*` (utilisant la configuration `colors-notes-staging`).
    * **Production :** Builds de la branche `main` (tagués `vX.Y.Z`, utilisant la configuration `colors-notes-prod`).

#### 4.4.3. Intégration Continue et Déploiement Continu (CI/CD) avec GitHub Actions

* **Principes :** Automatiser les étapes de build, test, et déploiement pour chaque environnement.

* **Workflows GitHub Actions (fichiers YAML dans `.github/workflows/`) :**

    * **1. Workflow de Test (`test-flutter-app.yml`) :**
        * **Déclencheurs :** `push` (sur toutes les branches sauf `main`), `pull_request` (vers `develop`, `release-candidate/*`, `main`).
        * **Jobs :** `setup-flutter`, `analyze`, `unit-widget-tests`, `coverage` (Optionnel).

    * **2. Workflow de Déploiement Dev (`deploy-dev.yml`) :**
        * **Déclencheurs :** `push` (sur la branche `develop`).
        * **Jobs :**
            * Dépend du succès du workflow `test-flutter-app.yml`.
            * `configure-firebase-dev` : Sélectionne/configure `firebase_options_dev.dart`.
            * `build-web-dev` : `flutter build web --release --dart-define=APP_ENV=dev`.
            * `deploy-web-dev` : Déploie sur Firebase Hosting (projet `colors-notes-dev`).
            * `build-android-dev` : `flutter build appbundle --release --dart-define=APP_ENV=dev`.
            * `deploy-android-internal-dev` : Déploie l'AAB sur la piste de Test Interne de Google Play (projet `colors-notes-dev`).

    * **3. Workflow de Déploiement Staging (`deploy-staging.yml`) :**
        * **Déclencheurs :** `push` (sur les branches `release-candidate/*`) ou `workflow_dispatch` pour un déclenchement manuel.
        * **Jobs :**
            * Dépend du succès du workflow `test-flutter-app.yml`.
            * `configure-firebase-staging` : Sélectionne/configure `firebase_options_staging.dart`.
            * `build-web-staging` : `flutter build web --release --dart-define=APP_ENV=staging`.
            * `deploy-web-staging` : Déploie sur Firebase Hosting (projet `colors-notes-staging`).
            * `build-android-staging` : `flutter build appbundle --release --dart-define=APP_ENV=staging`.
            * `deploy-android-alpha-beta-staging` : Déploie l'AAB sur une piste Alpha/Beta de Google Play (projet `colors-notes-staging`).

    * **4. Workflow de Déploiement Production (`deploy-production.yml`) :**
        * **Déclencheurs :** Création de tag `v*.*.*` (sur la branche `main`).
        * **Jobs :**
            * Dépend du succès du workflow `test-flutter-app.yml`.
            * `configure-firebase-prod` : Sélectionne/configure `firebase_options_prod.dart`.
            * `build-web-prod` : `flutter build web --release --dart-define=APP_ENV=prod`.
            * `deploy-web-prod` : Déploie sur Firebase Hosting (projet `colors-notes-prod`).
            * `build-android-prod` : `flutter build appbundle --release --dart-define=APP_ENV=prod`.
            * `deploy-android-prod` : Déploie l'AAB sur la piste de Production de Google Play (projet `colors-notes-prod`).

* **Gestion des Secrets :**
    * Utiliser les "Secrets" de GitHub Actions pour stocker les tokens et clés pour les trois projets Firebase, le keystore Android, et la clé API Google Play.
    * Exemples de secrets : `FIREBASE_TOKEN_DEV`, `FIREBASE_TOKEN_STAGING`, `FIREBASE_TOKEN_PROD`, `FIREBASE_SERVICE_ACCOUNT_DEV`, `FIREBASE_SERVICE_ACCOUNT_STAGING`, `FIREBASE_SERVICE_ACCOUNT_PROD`, `ANDROID_KEYSTORE_BASE64`, etc.

* **Configuration par Environnement dans Flutter :**
    * Utiliser `--dart-define=APP_ENV=dev`, `--dart-define=APP_ENV=staging`, ou `--dart-define=APP_ENV=prod` lors du build.
    * Dans `main.dart` ou un fichier de configuration, lire cette variable pour initialiser Firebase avec les bonnes options :
      ```dart
      // main.dart
      const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

      void main() async {
        WidgetsFlutterBinding.ensureInitialized();
        FirebaseOptions options;
        if (appEnv == 'prod') {
            // Assurez-vous d'avoir un fichier firebase_options_prod.dart
            options = DefaultFirebaseOptionsProd.currentPlatform; 
        } else if (appEnv == 'staging') {
            // Assurez-vous d'avoir un fichier firebase_options_staging.dart
            options = DefaultFirebaseOptionsStaging.currentPlatform; 
        } else { // dev
            // Assurez-vous d'avoir un fichier firebase_options_dev.dart
            options = DefaultFirebaseOptionsDev.currentPlatform; 
        }
        await Firebase.initializeApp(options: options);
        // ... reste du code de main()
        runApp(MyApp());
      }
      ```
    * Il faudra générer et nommer correctement ces fichiers (`firebase_options_dev.dart`, `firebase_options_staging.dart`, `firebase_options_prod.dart`) en utilisant `flutterfire configure` pour chaque projet Firebase respectif.

#### 4.4.4. Stratégie de Tests Automatisés

* **Tests Unitaires (Dart/Flutter) :**
    * **Localisation :** Répertoire `test/unit/`.
    * **Cibles :** Logique métier pure dans les services (`FirestoreService`, `AuthService`), fonctions de transformation dans les modèles de données (méthodes `toMap`/`fromMap`, validations), et la logique des `ChangeNotifier` (Providers).
    * **Outils :** `package:test`, `package:mockito` ou `package:mocktail` pour simuler les dépendances.
    * **Exemple :** Tester si `FirestoreService.createJournal` appelle correctement les méthodes Firestore avec les bons arguments.
* **Tests de Widgets (Flutter) :**
    * **Localisation :** Répertoire `test/widget/`.
    * **Cibles :** Vérifier que les widgets individuels et les écrans s'affichent correctement, répondent aux interactions utilisateur (taps, saisies de texte), et gèrent leur état interne ou interagissent correctement avec les Providers.
    * **Outils :** `flutter_test` (fournit `WidgetTester`).
    * **Exemple :** Tester que la page `SignInPage` affiche les champs email/mot de passe et qu'un appui sur le bouton "Connexion" déclenche l'appel au `AuthService`.
* **Tests d'Intégration (Flutter) :**
    * **Localisation :** Répertoire `integration_test/`.
    * **Cibles :** Tester des flux utilisateurs complets à travers plusieurs écrans et services, y compris les interactions réelles avec Firebase (en utilisant l'émulateur Firebase ou un projet de test dédié configuré dans la CI, typiquement sur l'environnement `dev`).
    * **Outils :** `package:integration_test` (à exécuter sur un émulateur/appareil).
    * **Exemple :** Scénario complet : Inscription -> Création d'un journal -> Ajout d'une note -> Vérification de l'affichage de la note.
* **Tests de Non-Régression :**
    * Consiste à exécuter l'ensemble des suites de tests (unitaires, widgets, intégration) automatiquement via la CI à chaque commit et avant chaque fusion de PR.
    * Si un test échoue, la build est marquée comme échouée, empêchant la régression.
* **Couverture de Code :**
    * **Objectif :** Viser une couverture de code d'au moins 70-80% pour les tests unitaires et widgets.
    * **Outils :** Exécuter `flutter test --coverage`. Générer un rapport HTML avec `genhtml` (nécessite `lcov` installé sur l'agent CI).
    * **Intégration CI :** Publier les rapports de couverture (e.g., sur Codecov, Coveralls) pour suivre l'évolution.

#### 4.4.5. Stratégie de Montée de Version et Migrations de Données (Firestore)

* **Versionnement de l'Application :**
    * Adopter le **Versionnage Sémantique (SemVer : `MAJOR.MINOR.PATCH`)** :
        * `MAJOR` : Changements non rétrocompatibles.
        * `MINOR` : Ajout de nouvelles fonctionnalités rétrocompatibles.
        * `PATCH` : Corrections de bugs rétrocompatibles (y compris hotfixes).
    * Mettre à jour la version (`X.Y.Z`) dans `pubspec.yaml` sur la branche `develop` avant de créer une `release-candidate`. Le numéro de build (`+B`) est incrémenté automatiquement par la CI/CD lors de chaque build de `staging` et `prod`.
    * **CI :** Le workflow de déploiement en production (déclenché par un tag `vX.Y.Z`) utilise `X.Y.Z` du tag pour `versionName` et un compteur de build GitHub Actions pour `versionCode`.
* **Migration de Schéma et de Données Firestore :**
    * **Principe :** Firestore étant NoSQL schemaless, les migrations sont gérées au niveau applicatif ou via des scripts/Cloud Functions.
    * **Stratégies Clés :**
        1. **Lecture Tolérante / Écriture de la Nouvelle Version (Expansion & Contraction) :**
            * **Phase d'Expansion :**
                * L'application est mise à jour pour lire l'ancien ET le nouveau format de document.
                * Lorsqu'un document est modifié, il est sauvegardé au nouveau format.
                * Les nouveaux documents sont créés directement au nouveau format.
                * Optionnel : Ajouter un champ `schemaVersion: <number>` dans les documents.
            * **Phase de Migration des Données (si nécessaire) :**
                * Exécuter un script ou une Cloud Function (sur l'environnement `staging` d'abord, puis `prod`) pour migrer en arrière-plan les documents restants.
            * **Phase de Contraction (optionnelle, dans une version ultérieure) :**
                * Une fois toutes les données migrées, le code de lecture de l'ancien format peut être supprimé.
        2. **Migration par Lots (Cloud Functions ou Scripts) :**
            * Pour des changements de structure importants.
            * Développer une Cloud Function ou un script.
            * **Important :** Tester sur `staging`, sauvegardes avant migration sur `prod`, exécuter pendant heures creuses, gérer erreurs.
    * **Outillage et Précautions :**
        * **Scripts de Migration :** Dart ou Node.js.
        * **Idempotence.**
        * **Sauvegardes.**
        * **Déploiement progressif.**

#### 4.4.6. Monitoring et Logging

* **Firebase Crashlytics :** Intégrer pour les trois environnements (avec des configurations distinctes si possible pour le filtrage).
* **Firebase Performance Monitoring :** Pour les trois environnements.
* **Logger (Package `logger` en place) :**
    * Configurer les niveaux de log par environnement (`Level.debug` en `dev`, `Level.info` en `staging`, `Level.warning` en `prod`).
    * Envoyer les logs vers Google Cloud Logging pour `staging` et `prod`.

#### 4.4.7. Documentation Technique

* **Ce Document :** Maintenir à jour.
* **Commentaires dans le Code :** Dart Doc.
* **Documentation CI/CD :** Workflows, secrets, procédures.
* **Décisions d'Architecture.**

### **4.5. Maintenance et Évolutions Futures**

* **Gestion des Bugs :** GitHub Issues.
* **Planification des Nouvelles Fonctionnalités :** GitHub Issues.
* **Mises à Jour des Dépendances.**
* **Feedback Utilisateur.**

## **5. Points d'Attention Particuliers**

* **Performance.**
* **Sécurité.**
* **Scalabilité.**
* **Expérience Utilisateur (UX).**

Ce document servira de base pour les développements futurs. Il devra être mis à jour au fur et à mesure de l'évolution de l'application.
