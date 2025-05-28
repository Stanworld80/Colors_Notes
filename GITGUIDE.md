# Guide d'Utilisation de Git pour le Projet "Colors & Notes"

Ce guide décrit la stratégie de gestion des branches et des tags Git à suivre pour le développement de l'application "Colors & Notes". Le respect de ce guide est essentiel pour maintenir un historique clair, faciliter la collaboration et assurer des déploiements stables.

## 1. Branches Principales

Notre flux de travail s'articule autour de deux branches principales avec une durée de vie infinie :

* **`main`**:
    * Représente le code de **production stable et testé**.
    * Chaque commit sur `main` doit correspondre à une version de production ou à un hotfix.
    * Les releases sont créées en **taguant** un commit spécifique sur cette branche (ex: `v1.0.0`).
    * **Aucun push direct** n'est autorisé sur `main` (sauf pour les administrateurs en cas d'urgence absolue, et même dans ce cas, un hotfix via PR est préférable). Les fusions se font via des Pull Requests validées depuis `develop` ou des branches de `hotfix`.

* **`develop`**:
    * Branche d'**intégration continue** pour toutes les nouvelles fonctionnalités et corrections avant leur passage en production.
    * Sert de base pour les builds de test et de staging.
    * Doit être maintenue dans un état stable, c'est-à-dire que tout ce qui y est fusionné doit être testé et fonctionnel.
    * Les développeurs créent leurs branches de fonctionnalités et de correction à partir de `develop`.

## 2. Branches de Support

Ces branches ont une durée de vie limitée et servent à organiser le travail :

### 2.1. Branches de Fonctionnalité (`feature/*`)

* **Objectif**: Développer de nouvelles fonctionnalités.
* **Création**: Toujours à partir de la dernière version de `develop`.
    ```bash
    # 1. Se positionner sur develop et la mettre à jour
    git checkout develop
    git pull origin develop

    # 2. Créer la branche de fonctionnalité
    git checkout -b feature/nom-explicite-de-la-fonctionnalite
    # Exemple: git checkout -b feature/gestion-profil-utilisateur
    ```
* **Nommage**: `feature/description-courte-en-kebab-case`
* **Flux de travail**:
    1.  Développer la fonctionnalité sur cette branche.
    2.  Faire des commits réguliers et descriptifs (voir section "Conventions de Commit").
    3.  Pousser la branche sur le dépôt distant (`git push origin feature/nom-explicite-de-la-fonctionnalite`).
    4.  Une fois la fonctionnalité terminée et testée localement, ouvrir une **Pull Request (PR)** vers `develop`.
    5.  Après revue de code et passage des tests CI, la PR est fusionnée dans `develop`.
    6.  La branche de fonctionnalité peut ensuite être supprimée (localement et sur le dépôt distant).

### 2.2. Branches de Correction (`fix/*`)

* **Objectif**: Corriger des bugs.
* **Deux scénarios**:

    * **Correction de bug standard (non critique, pour la prochaine release)**:
        * **Création**: À partir de la dernière version de `develop`.
            ```bash
            git checkout develop
            git pull origin develop
            git checkout -b fix/description-du-bug
            # Exemple: git checkout -b fix/probleme-affichage-notes
            ```
        * **Nommage**: `fix/description-courte-en-kebab-case`
        * **Flux de travail**: Similaire aux branches `feature/*`. PR vers `develop`.

    * **Hotfix (correction de bug critique en production)**:
        * **Création**: À partir du **tag de la version de production concernée sur `main`** (ou du commit correspondant sur `main`).
            ```bash
            # 1. Se positionner sur main et la mettre à jour
            git checkout main
            git pull origin main

            # 2. Créer la branche de hotfix à partir du tag (ex: v1.2.0) ou du dernier commit de main
            git checkout -b hotfix/description-bug-critique v1.2.0 
            # Ou: git checkout -b hotfix/description-bug-critique
            ```
        * **Nommage**: `hotfix/description-courte-en-kebab-case`
        * **Flux de travail**:
            1.  Appliquer la correction urgente.
            2.  Commiter et pousser la branche de hotfix.
            3.  Ouvrir une PR de la branche `hotfix/*` vers `main`.
            4.  **Revue de code et tests accélérés mais rigoureux.**
            5.  Fusionner la PR dans `main`.
            6.  **Crucial**: Immédiatement après la fusion dans `main`, créer un nouveau **tag de patch** (ex: `v1.2.1`) sur `main` (voir section "Taggage des Releases").
            7.  **Crucial**: Fusionner également la branche `hotfix/*` (ou le commit de `main` contenant le hotfix) dans `develop` pour s'assurer que la correction est incluse dans les futurs développements. Cela peut se faire via une PR de `hotfix/*` vers `develop` ou en fusionnant `main` dans `develop`.
                ```bash
                git checkout develop
                git pull origin develop
                git merge --no-ff main # ou la branche hotfix si plus direct
                git push origin develop
                ```
            8.  La branche de hotfix peut ensuite être supprimée.

## 3. Pull Requests (PR)

* **Obligatoires**: Toute fusion vers `develop` ou `main` doit passer par une PR.
* **Description Claire**: La PR doit expliquer le pourquoi et le comment des changements. Lier à l'issue GitHub correspondante si applicable.
* **Revue de Code**: Au moins une revue par un autre membre de l'équipe est requise avant la fusion.
* **Tests CI**: Les tests d'intégration continue (analyse statique, tests unitaires, tests de widgets) doivent passer avec succès.
* **Fusion**: Utiliser la fusion "Squash and merge" ou "Rebase and merge" vers `develop` pour garder un historique propre. Pour `main`, une fusion simple ("Merge pull request") est souvent préférée pour préserver l'historique des releases.

## 4. Conventions de Commit

Utiliser la convention **Conventional Commits**. Cela améliore la lisibilité de l'historique et permet d'automatiser la génération de changelogs.
Format général : `<type>(<scope>): <sujet>`

* **Types courants**:
    * `feat`: Nouvelle fonctionnalité.
    * `fix`: Correction de bug.
    * `docs`: Changements dans la documentation.
    * `style`: Changements de mise en forme du code (n'affectant pas la logique).
    * `refactor`: Réécriture de code sans changer son comportement externe.
    * `perf`: Amélioration de la performance.
    * `test`: Ajout ou modification de tests.
    * `chore`: Tâches de maintenance (build, CI, etc.).
    * `ci`: Changements relatifs à la configuration de l'intégration continue.

* **Exemples**:
    * `feat(auth): Ajout de la connexion via Google`
    * `fix(ui): Correction du bug d'affichage sur le profil`
    * `docs(readme): Mise à jour des instructions d'installation`

## 5. Processus de Release et Taggage

Les releases sont effectuées à partir de la branche `main`.

1.  **Préparation sur `develop`**:
    * S'assurer que `develop` contient toutes les fonctionnalités et corrections pour la release et est stable.
    * Mettre à jour le `CHANGELOG.md` et la version dans `pubspec.yaml` (ex: `version: 1.3.0+X`). Commiter ces changements.

2.  **Fusion de `develop` vers `main`**:
    * Ouvrir une PR de `develop` vers `main`.
    * Effectuer une revue finale.
    * Fusionner la PR. `main` contient maintenant le code de la nouvelle release.

3.  **Taggage de la Release sur `main`**:
    * Après la fusion, se positionner sur `main` et s'assurer qu'elle est à jour :
        ```bash
        git checkout main
        git pull origin main
        ```
    * Créer un **tag Git annoté** (important pour inclure un message). Le nom du tag doit suivre le versionnage sémantique (SemVer).
        ```bash
        git tag -a vX.Y.Z -m "Release version X.Y.Z - Description des changements majeurs"
        # Exemple: git tag -a v1.3.0 -m "Release v1.3.0 - Ajout de la gestion des profils et correction de bugs d'affichage"
        ```
    * Pousser le tag vers le dépôt distant :
        ```bash
        git push origin vX.Y.Z
        # Ou pour pousser tous les tags locaux :
        # git push origin --tags
        ```
    * Le numéro de build (`versionCode` Android / `build_name` iOS) est généralement géré par la CI/CD lors du build de production basé sur ce tag.

4.  **(Optionnel mais recommandé) Synchroniser `develop` avec `main`**:
    * Pour s'assurer que `develop` reflète le dernier état de `main` (y compris le commit de fusion de la release).
        ```bash
        git checkout develop
        git pull origin develop # S'assurer que develop est à jour
        git merge main # Fusionner les changements de main (le tag) dans develop
        git push origin develop
        ```

## 6. Configuration Recommandée sur GitHub

* **Protection des Branches**: Configurer des règles de protection pour `main` et `develop` dans les paramètres du dépôt GitHub :
    * Exiger une Pull Request avant la fusion.
    * Exiger des revues (au moins une).
    * Exiger que les vérifications de statut (tests CI) passent.
    * Pour `main` : Envisager d'interdire les pushs directs, même pour les administrateurs.

En suivant ce guide, nous assurerons un processus de développement collaboratif, organisé et efficace pour "Colors & Notes".
