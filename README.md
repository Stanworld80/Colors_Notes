# Colors & Notes -

"Color your day."

Une application web et Android développée avec Flutter et Firebase pour organiser vos notes et pensées quotidiennes en les associant à des couleurs personnalisées regroupées dans des palettes uniques pour chaque journal.

## 📜 Licence 
Tout le projet, l'ensemble du code , commentaires et documentations liées sont sous la licence Creative Commons : Attribution-NonCommercial-ShareAlike 4.0 International  :
L'ensemble est distribué sous la licence **Creative Commons Attribution - Pas d’Utilisation Commerciale - Partage dans les Mêmes Conditions 4.0 International (CC BY-NC-SA 4.0)**.

[![Licence CC BY-NC-SA 4.0](https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png)](http://creativecommons.org/licenses/by-nc-sa/4.0/)

**Auteur :** Stanislas Mathieu Eric Selle < stanworld@gmail.com > (2025)

En résumé, vous êtes libre de :
* **Partager** — copier et redistribuer le matériel sur n'importe quel support ou format
* **Adapter** — remixer, transformer et créer à partir du matériel

Sous les conditions suivantes :
* **Attribution (BY)** — Vous devez créditer l'Œuvre, intégrer un lien vers la licence et indiquer si des modifications ont été effectuées. Vous devez indiquer ces informations par tous les moyens raisonnables, sans toutefois suggérer que le Concédant vous soutient ou soutient la façon dont vous avez utilisé son Œuvre.
* **Pas d’Utilisation Commerciale (NC)** — Vous n'êtes pas autorisé à faire un usage commercial de cette Oeuvre, tout ou partie du matériel la composant.
* **Partage dans les Mêmes Conditions (SA)** — Dans le cas où vous effectuez un remix, que vous transformez, ou créez à partir du matériel composant l'Oeuvre originale, vous devez diffuser l'Oeuvre modifiée dans les même conditions, c'est-à-dire avec la même licence avec laquelle l'Oeuvre originale a été diffusée.

Voir le fichier [LICENSE](LICENSE) pour le texte légal complet.
Voir aussi :
- [Guide Git](doc/GITGUIDE.md)
- [Spécifications](doc/SPECS.md)
- [Guide Testeur](doc/TESTER_GUIDE.md)

[CC BY-NC-SA](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode) 

https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.txt




## ✨ Fonctionnalités (Version MVP 1.0)

* **Authentification :** Inscription et connexion par Email/Mot de passe et Google Sign-In.
* **Gestion de Journal :**
    * Création de journal :
        * Vierge (avec choix de palette de base)
        * Depuis un modèle thématique prédéfini (ex: Sport, Humeur)
        * Depuis un journal existant (copie de structure)
    * Sélection de l'journal actif.
    * Renommage des journals.
    * Suppression des journals (avec confirmation et suppression des notes associées).
* **Gestion des Palettes :**
    * Chaque journal possède sa propre **instance** de palette indépendante.
    * Gestion complète des **modèles** de palettes personnelles réutilisables (Créer, Voir, Modifier, Renommer, Supprimer).
    * Éditeur de couleurs avec sélecteur visuel et gestion des titres (pré-remplissage avec Hex).
    * Validation des contraintes (nombre de couleurs, unicité titres/valeurs).
    * Modification des couleurs de l'**instance** de palette d'un journal actif.
* **Gestion des Notes :**
    * Création rapide de notes en cliquant sur une couleur de la palette de l'journal actif.
    * Ajout de commentaires (limités en caractères).
    * Affichage de la liste des notes par journal (triées par date).
    * Modification des commentaires des notes.
    * Suppression des notes (avec confirmation).
* **Navigation :** Barre de navigation simple pour basculer entre Accueil, Liste des Notes, Gestion des Journals. Accès à la gestion des modèles de palettes depuis la gestion des journals.

## 🚀 Technologies Utilisées

* **Framework :** Flutter (pour Web et Android)
* **Backend & Base de Données :** Firebase (Authentication, Cloud Firestore)
* **Gestion d'État :** Provider
* **Authentification Google :** google_sign_in
* **Sélecteur de Couleur :** flutter_colorpicker
* **Formatage Dates :** intl

## 🛠️ Installation et Configuration (Pour Développeurs)

1.  **Prérequis :**
    * Assurez-vous d'avoir le [SDK Flutter](https://docs.flutter.dev/get-started/install) installé.
    * Un compte Firebase et un projet Firebase créés.
2.  **Cloner le Dépôt :**
    ```bash
    git clone [URL_DE_VOTRE_DEPOT_GITHUB]
    cd colors_notes
    ```
3.  **Configuration Firebase :**
    * Ce projet utilise FlutterFire. Vous devrez configurer votre propre projet Firebase :
        * Suivez les instructions de [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup?platform=web) pour connecter votre projet Flutter à votre projet Firebase pour les plateformes cibles (Web, Android).
        * Cela générera/mettra à jour `lib/firebase_options.dart`.
        * Pour **Android**, assurez-vous d'ajouter votre fichier `google-services.json` (téléchargé depuis les paramètres de votre projet Firebase) dans le dossier `android/app/`.
        * Pour **Web**, assurez-vous que les informations de configuration Firebase sont correctes (généralement géré par `firebase_options.dart`).
    * **Authentification Google :** Configurez les identifiants OAuth 2.0 pour Web et Android dans la console Google Cloud / Firebase et assurez-vous que les Client IDs correspondent à ceux utilisés dans le code (notamment dans `AuthService` ou les configurations natives). N'oubliez pas d'ajouter `http://localhost` aux origines JavaScript autorisées pour le développement web.
    * **Firestore :** Activez Cloud Firestore dans votre projet Firebase (une base de données `(default)` en mode Natif suffit) et configurez les [Règles de Sécurité](https://firebase.google.com/docs/firestore/security/get-started) (voir exemple dans le code ou ci-dessous). Créez manuellement les [Index Composites](https://firebase.google.com/docs/firestore/query-data/indexing) requis par les requêtes (Firestore vous donnera les liens dans les logs d'erreurs lors des premières exécutions si nécessaire).
4.  **Installer les Dépendances :**
    ```bash
    flutter pub get
    ```

## ▶️ Exécuter l'Application

* **Pour le Web (dans Chrome) :**
    ```bash
    flutter run -d chrome
    ```
* **Pour Android (avec un émulateur ou appareil connecté) :**
    ```bash
    flutter run
    flutter run
    ```

## 🧪 Tests et Qualité

Le projet inclut une suite de tests d'intégration automatisés pour valider les fonctionnalités clés sur de vrais appareils Android via **Firebase Test Lab**.

### Exécuter les tests sur Firebase Test Lab

Pour exécuter tous les tests d'intégration (création de compte, journaux, notes, notifications) :

```powershell
./tools/run_firebase_test_lab.ps1
```

Pour exécuter spécifiquement le test des notifications (plus rapide) :

```powershell
./tools/run_firebase_notification_test.ps1
```

Ces scripts construisent automatiquement l'APK de test et l'envoient à Firebase Test Lab. Les résultats sont consultables dans la console Firebase.

## 📂 Structure du Projet (Simplifiée)
* lib/
* ├── core/                 # Modèles prédéfinis, constantes...
* ├── models/               # Classes de données (Journal, Note, Palette...)
* ├── providers/            # Gestion d'état (ActiveJournalNotifier...)
* ├── screens/              # Widgets représentant les écrans principaux
* ├── services/             # Logique métier, accès Firebase (AuthService, FirestoreService)
* └── main.dart             # Point d'entrée de l'application

# 🔮 Travaux Futurs / TODO (Post-MVP)

*(Basé sur les spécifications initiales)*

* Interface d'administration détaillée (SF-ADMIN-\*).
* Option de suppression de couleur utilisée avec suppression/modification des notes liées.
* Optimisation du stockage/gestion des instances de palettes pour un grand nombre d'journals.
* Amélioration de l'UI/UX générale.
* Options de tri/filtrage/recherche avancées pour les notes.
* Fonctionnalités de partage (si pertinent).
* Affichage Grid/Liste pour les notes (SF-VIEW-02).
* Gestion du dernier journal utilisé (SF-AGENDA-03).
* Finaliser la création d'journal depuis un journal existant (copie palette OK, mais UI à peaufiner).



