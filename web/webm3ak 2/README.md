# Ma3ak – Backoffice Administration

> **Documentation du projet** – À partager avec l’équipe. Ce README décrit le backoffice Flutter de Ma3ak : objectifs, architecture, installation et référence technique.

---

## Pour les nouveaux sur le projet

- **Ce que c’est** : interface d’administration (backoffice) pour la plateforme **Ma3ak** (personnes en situation de handicap en Tunisie et leurs accompagnants). Seuls les comptes **administrateurs** peuvent y accéder.
- **Où commencer** : lisez [Contexte et objectifs](#contexte-et-objectifs), puis [Installation et lancement](#installation-et-lancement). Pour comprendre le code : [Structure du projet](#structure-du-projet) et [Architecture globale](#architecture-globale).
- **Backend** : l’app appelle une API REST (voir [API backend attendue](#api-backend-attendue)). Le backend doit tourner séparément (ex. sur le port 3000).
- **En cas de blocage** : vérifiez [Configuration](#configuration), [Proxy CORS](#proxy-cors) (pour le web) et la section [Dépannage](#dépannage) en bas de page.

---

## Sommaire

- [Contexte et objectifs](#contexte-et-objectifs)
- [Stack technique](#stack-technique)
- [Architecture globale](#architecture-globale)
- [Authentification](#authentification)
- [Routage et gardes](#routage-et-gardes)
- [API et client HTTP](#api-et-client-http)
- [Modèles de données](#modèles-de-données)
- [Thème et mode sombre](#thème-et-mode-sombre)
- [Types de handicap](#types-de-handicap)
- [Proxy CORS](#proxy-cors)
- [Configuration](#configuration)
- [Structure du projet](#structure-du-projet)
- [Installation et lancement](#installation-et-lancement)
- [API backend attendue](#api-backend-attendue)
- [Tests](#tests)
- [Dépannage](#dépannage)
- [Ressources](#ressources)

---

## Contexte et objectifs

<!-- Explication pour l’équipe : pourquoi ce backoffice existe et qui l’utilise. -->

- **Ma3ak** : plateforme dédiée aux personnes en situation de handicap en Tunisie et à leurs **accompagnants** (aidants).
- **Ce dépôt** : le **backoffice Flutter** — outil réservé aux **administrateurs** (rôle `ADMIN`). Il ne s’agit pas de l’app mobile/web grand public.
- **Rôle du backoffice** :
  - Connexion sécurisée (email / mot de passe ; seul le rôle ADMIN est accepté).
  - Tableau de bord : statistiques, graphiques, rapports récents.
  - Gestion des utilisateurs : liste paginée, filtres, recherche, détail, création, édition, suppression.
  - Consultation des types de handicap et du statut des profils (vérifié / en attente).

**Sécurité** : l’accès est strictement réservé aux comptes dont le rôle est `ADMIN`. Un utilisateur connecté sans ce rôle est redirigé vers une page « Accès refusé ».

---

## Stack technique

<!-- Choix techniques : Flutter pour le multi-plateforme, Provider pour l’état, go_router pour un routage déclaratif avec gardes. -->

| Domaine         | Technologie | Commentaire |
|-----------------|------------|-------------|
| Framework       | **Flutter** (SDK ^3.10) | Multi-plateforme (Web, mobile, desktop). |
| Langage         | **Dart** | Langage officiel Flutter. |
| Réseau          | **Dio** | Client HTTP avec intercepteurs (JWT, 401). |
| État global     | **Provider** (ChangeNotifier) | Auth et thème ; simple et suffisant pour ce scope. |
| Routage         | **go_router** | Routes déclaratives, redirect, ShellRoute pour le layout admin. |
| Persistance     | **SharedPreferences** | Token, user et préférence thème (pas de base locale). |
| Variables d’env | **flutter_dotenv** + `VITE_API_URL` | URL de l’API sans recompiler. |
| Formatage       | **intl** | Dates et nombres (ex. liste utilisateurs). |
| Graphiques      | **fl_chart** | Courbes et indicateurs du dashboard. |
| Cibles          | Web, Android, iOS, macOS, Windows, Linux | Déployable sur toutes les plateformes supportées par Flutter. |

---

## Architecture globale

<!-- En résumé : main initialise l’auth et l’API, puis le routeur décide où envoyer l’utilisateur selon son état (connecté, admin, etc.). Les écrans admin sont dans un shell commun (sidebar + header). -->

```
┌─────────────────────────────────────────────────────────────────┐
│                        main.dart                                  │
│  • Chargement .env, AuthProvider, ThemeProvider                   │
│  • initApiClient(getToken, on401)                                 │
│  • MultiProvider → Ma3akBackofficeApp                            │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Ma3akBackofficeApp                              │
│  • Attente auth.isLoaded puis theme + router                      │
│  • MaterialApp.router(theme, darkTheme, themeMode, routerConfig)   │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    go_router (app_router.dart)                    │
│  • redirect : non connecté → /login ; connecté non admin → /access-denied │
│  • ShellRoute(AdminLayout) pour /, /users, /users/new, /users/:id │
└─────────────────────────────────────────────────────────────────┘
                                    │
          ┌────────────────────────┼────────────────────────┐
          ▼                        ▼                        ▼
   LoginScreen            AccessDeniedScreen         AdminLayout
   (hors shell)           (hors shell)               (sidebar + header + child)
                                                              │
                                    ┌────────────────────────┼────────────────────────┐
                                    ▼                        ▼                        ▼
                            DashboardScreen           UserListScreen        UserDetailScreen
                            UserCreateScreen          UserEditScreen
```

**Flux au démarrage (pour comprendre le code) :**

1. **Démarrage** : chargement du token et du user depuis SharedPreferences + préférence thème. Tant que l’auth n’est pas chargée, un écran « Chargement… » s’affiche.
2. **Client API** : initialisé avec une fonction `getToken` et un callback `on401`. Chaque requête (sauf login) envoie le JWT ; un 401 déclenche le logout et la redirection vers login.
3. **Routeur** : les redirections dépendent de `auth.isLoaded`, `auth.isAuthenticated`, `auth.isAdmin`. Les écrans admin sont dans un **ShellRoute** (AdminLayout = sidebar + header + zone de contenu).
4. **Navigation** : après login admin → dashboard (`/`) ; depuis le dashboard on accède à la liste des utilisateurs, détail, création, édition.

---

## Authentification

<!-- Important pour le partage : comment fonctionne la connexion, le stockage et la déconnexion (manuelle ou sur 401). -->

### Flux de connexion

1. L’utilisateur saisit email et mot de passe sur **LoginScreen**.
2. `AuthProvider.login(email, password)` appelle `POST /auth/login`.
3. Si la réponse contient un user avec `role === 'ADMIN'` :
   - Le token et le user sont stockés dans SharedPreferences (pour rester connecté après fermeture de l’app).
   - Le routeur redirige vers le tableau de bord (`/`).
4. Si le user n’est pas admin : la méthode retourne `false`, message « Accès réservé aux administrateurs ».
5. En cas d’erreur (401, réseau, etc.) : message d’erreur affiché à l’utilisateur.

### Stockage local (SharedPreferences)

- **Clés** : `ma3ak_backoffice_token`, `ma3ak_backoffice_user`.
- Le user est sérialisé en JSON avec tous les champs nécessaires pour restaurer la session au redémarrage (ex. `_id`, `nom`, `prenom`, `email`, `role`, etc.).

### Déconnexion

- **Manuelle** : via l’UI (ex. page Accès refusé) ou en appelant `AuthProvider.logout()`.
- **Automatique sur 401** : l’intercepteur Dio appelle `onUnauthorized` (configuré avec `auth.logout()`), ce qui vide token/user et notifie ; le routeur redirige alors vers `/login`. Utile quand le token expire ou est révoqué.

### Mise à jour du user en cache

- Après édition du profil connecté (ou du user courant), `AuthProvider.setUser(User)` met à jour le user en mémoire et notifie, pour que le header/sidebar affichent les bonnes infos sans re-login.

---

## Routage et gardes

**Fichier** : `lib/router/app_router.dart`.

<!-- go_router utilise un RefreshListenable (auth) pour recalculer les redirections à chaque changement d’état (login, logout). Les gardes évitent d’afficher des écrans admin à un non-admin. -->

- **RefreshListenable** : `auth` (AuthProvider). À chaque changement d’état d’auth, le routeur recalcule la redirection.
- **initialLocation** : `/` (dashboard). Au lancement, on « demande » le dashboard ; le redirect envoie vers login si non connecté.

### Règles de redirection (tableau de référence)

| État                          | Route demandée     | Redirection      |
|-------------------------------|---------------------|------------------|
| Auth non chargée              | toute               | `null` (attente) |
| Sur `/login`                  | –                   | Si admin → `/` ; si connecté non admin → `/access-denied` ; sinon rester sur login |
| Sur `/access-denied`          | –                   | Si non connecté → `/login` |
| Non authentifié               | toute (sauf login)  | `/login`         |
| Authentifié mais non admin    | toute (sauf login / access-denied) | `/access-denied` |
| Authentifié et admin          | –                   | Aucune           |

### Routes déclarées

| Chemin            | Écran              | Layout      |
|-------------------|--------------------|------------|
| `/login`          | LoginScreen        | Aucun      |
| `/access-denied`  | AccessDeniedScreen | Aucun      |
| `/`               | DashboardScreen    | AdminLayout |
| `/users`          | UserListScreen     | AdminLayout |
| `/users/new`      | UserCreateScreen   | AdminLayout |
| `/users/:id`      | UserDetailScreen   | AdminLayout |
| `/users/:id/edit` | UserEditScreen     | AdminLayout |

Les paramètres de route (`:id`) sont lus via `state.pathParameters['id']`.

---

## API et client HTTP

<!-- Toutes les requêtes (sauf login) passent par le client Dio ; l’intercepteur ajoute le JWT et gère le 401. Les appels sont centralisés dans auth_api.dart et admin_api.dart. -->

### Client Dio (`lib/api/client.dart`)

- **Instance globale** : `apiClient` (Dio), initialisée dans `main()` après chargement de l’auth.
- **Base URL** : fournie par `apiBaseUrl` (voir [Configuration](#configuration)).
- **Options** : `connectTimeout` et `receiveTimeout` 15 s, headers `Content-Type` et `Accept` en JSON.
- **Intercepteur** :
  - **Requête** : ajout de `Authorization: Bearer <token>` si `getToken()` retourne une valeur.
  - **Erreur** : si status 401, appel de `onUnauthorized()` (logout) puis propagation de l’erreur.

### Endpoints utilisés

| Méthode | Endpoint              | Fichier API   | Usage |
|---------|------------------------|---------------|--------|
| POST    | `/auth/login`         | auth_api.dart | Connexion (email, password) |
| GET     | `/user/me`            | auth_api.dart | Profil utilisateur connecté (JWT) |
| GET     | `/admin/users`        | admin_api.dart| Liste paginée (page, limit, role, search) |
| POST    | `/admin/users`        | admin_api.dart| Création utilisateur |
| GET     | `/admin/users/:id`    | admin_api.dart| Détail utilisateur |
| PATCH   | `/admin/users/:id`    | admin_api.dart| Mise à jour (sans mot de passe) |
| DELETE  | `/admin/users/:id`    | admin_api.dart| Suppression |
| GET     | `/admin/stats`        | admin_api.dart| Statistiques dashboard |

### Gestion des erreurs côté UI

- **409** (création/édition) : message « Cet email est déjà utilisé ».
- **404 / 400** : messages dérivés de la réponse ou génériques (DioException).
- **401** : géré globalement par l’intercepteur (déconnexion + redirection vers login).

---

## Modèles de données

**Fichier** : `lib/models/user.dart`.

<!-- Les modèles sont alignés sur l’API backend. _id est mappé en id ; les rôles sont des strings côté API et un enum côté app. -->

### UserRole (enum)

- `handicap` → `HANDICAPE` (personne en situation de handicap)
- `accompagnant` → `ACCOMPAGNANT` (aidant)
- `admin` → `ADMIN` (administrateur)

Libellés affichés : Handicapé, Accompagnant, Administrateur.

### User

Champs principaux : `id`, `nom`, `prenom`, `email`, `telephone`, `role`, `typeHandicap`, `besoinSpecifique`, `animalAssistance`, `typeAccompagnant`, `specialisation`, `disponible`, `noteMoyenne`, `langue`, `photoProfil`, `statut`, `createdAt`, `updatedAt`.  
Mapping JSON : `_id` → `id`, `role` (string API) → enum, listes et dates parsées. Méthodes : `fromJson`, `toJson`, `copyWith`.  
Propriété calculée : `nomComplet` (prénom + nom).

### LoginResponse

- `accessToken` (string) — peut venir du champ `access_token` ou `accessToken` côté API.
- `user` (User)

### PaginatedUsers (réponse GET /admin/users)

- `data` (List&lt;User&gt;)
- `total`, `page`, `limit`, `totalPages`

### AdminStats (réponse GET /admin/stats)

- `totalUsers`, `totalHandicapes`, `totalAccompagnants` (les noms `totalBeneficiaries` / `totalCompanions` sont aussi acceptés en fallback)
- `recentRegistrations` (List&lt;User&gt;)

---

## Thème et mode sombre

<!-- Pour garder une UI cohérente : toutes les couleurs passent par Ma3akTheme.of(context). Le mode sombre est persisté en SharedPreferences. -->

### Fichiers

- **`lib/theme/ma3ak_theme.dart`** : extension `Ma3akTheme` (couleurs sémantiques) + `ma3akLightThemeData` et `ma3akDarkThemeData` (ThemeData complets).
- **`lib/theme/ma3ak_colors.dart`** : palette statique (référence pour le thème clair).
- **`lib/providers/theme_provider.dart`** : état du mode sombre et persistance.

### Ma3akTheme (ThemeExtension)

Couleurs exposées : `background`, `cardBackground`, `textPrimary`, `textSecondary`, `inputBorder`, `inputBackground`, `primary`, `primaryDark`, `lightBlue`, `accent`.  
Accès dans les widgets : `Ma3akTheme.of(context)` — à utiliser plutôt que des couleurs en dur pour rester cohérent avec le thème clair/sombre.

### ThemeProvider

- **État** : `isDarkMode` (bool), `isLoaded` (bool).
- **Persistance** : clé SharedPreferences `ma3ak_dark_mode`.
- **Méthodes** : `loadFromStorage()`, `toggle()`, `setDarkMode(bool)`.

### Dans l’app

- `MaterialApp.router` utilise `theme`, `darkTheme` et `themeMode` selon `ThemeProvider.isDarkMode`.
- Les écrans utilisent `Ma3akTheme.of(context)` pour fonds, cartes, textes, bordures, boutons. Le bouton de bascule (lune/soleil) est sur la page de login et dans le header AdminLayout.

---

## Types de handicap

**Fichiers** : `lib/utils/handicap_types.dart`, `lib/utils/user_constants.dart`.

<!-- Les codes viennent de l’API ; on les affiche en français via des maps de libellés. user_constants gère aussi statut, langue, typeAccompagnant. -->

- **handicap_types.dart** : `handicapTypeLabels` (code API → libellé FR), `handicapTypeToLabel`, `handicapTypesToLabels`, `allowedHandicapTypeCodes`.
- **user_constants.dart** : `typeHandicapLabels`, `typeHandicapToLabel` ; `typeAccompagnantLabels`, `typeAccompagnantToLabel` ; `statutLabels`, `statutToLabel` ; `langueLabels`, `langueToLabel`. Utilisés dans les formulaires et les listes (badges, dropdowns).

---

## Proxy CORS

**Fichier** : `proxy/proxy.js`.

<!-- En développement Flutter Web, le navigateur applique la politique CORS. Si le backend est sur un autre port (ex. 3000), les requêtes peuvent être bloquées. Le proxy reçoit les appels sur 3001 et les transmet au backend en ajoutant les en-têtes CORS. -->

- Le proxy écoute sur le **port 3001** et transmet les requêtes au backend (par défaut **port 3000**).
- Il ajoute les en-têtes CORS nécessaires et gère les prévoltes OPTIONS.
- **Utilisation** : lancer le backend sur 3000, puis `node proxy/proxy.js` à la racine du projet. Dans `.env`, définir `VITE_API_URL=http://localhost:3001`.

Alternative non recommandée : lancer Chrome avec `--disable-web-security`.

---

## Configuration

### Variables d’environnement

- **Fichier** : `.env` (à créer à partir de `.env.example`). Ne pas commiter les secrets ; partager uniquement `.env.example` avec l’équipe.
- **Variable utilisée** : `VITE_API_URL` (URL de base de l’API).
- **Priorité** : `--dart-define=VITE_API_URL=...` puis `.env`, puis défaut `http://localhost:3000`.
- **Chargement** : `flutter_dotenv` dans `main()` ; le fichier `.env` est optionnel (pas d’erreur s’il est absent).

### Assets

- `.env` et `assets/images/` sont déclarés dans `pubspec.yaml`. Exemple : logo dans `assets/images/logo.png`, utilisé par `AppLogo` (avec fallback icône si l’image est absente).

---

## Structure du projet

<!-- Chaque dossier a un rôle précis ; les écrans sont dans screens/, la logique API dans api/, l’état dans providers/. -->

```
lib/
├── main.dart                    # Point d'entrée, providers, init API, MaterialApp.router
├── config/
│   └── env.dart                 # apiBaseUrl (VITE_API_URL)
├── api/
│   ├── client.dart              # Dio, intercepteur JWT, on401
│   ├── auth_api.dart            # login, getMe
│   └── admin_api.dart           # getUsers, createUser, getUser, updateUser, deleteUser, getStats
├── models/
│   └── user.dart                # User, UserRole, LoginResponse, PaginatedUsers, AdminStats
├── providers/
│   ├── auth_provider.dart       # Token, user, login, logout, setUser, SharedPreferences
│   └── theme_provider.dart      # isDarkMode, toggle, SharedPreferences
├── router/
│   └── app_router.dart          # go_router, redirect, ShellRoute(AdminLayout), routes
├── screens/
│   ├── login_screen.dart        # Formulaire connexion, bouton dark mode
│   ├── access_denied_screen.dart
│   ├── dashboard_screen.dart    # Stats, graphiques fl_chart, tableau rapports
│   ├── user_list_screen.dart    # Liste paginée, filtres, recherche, tableau
│   ├── user_create_screen.dart  # POST /admin/users, formulaire complet
│   ├── user_detail_screen.dart  # GET /admin/users/:id, actions édition/suppression
│   └── user_edit_screen.dart    # PATCH /admin/users/:id, formulaire (sans email/mdp)
├── theme/
│   ├── ma3ak_colors.dart        # Palette statique (référence)
│   └── ma3ak_theme.dart         # Ma3akTheme extension, thèmes clair/sombre
├── utils/
│   ├── handicap_types.dart      # Codes handicap → libellés FR
│   └── user_constants.dart      # Libellés statut, langue, typeHandicap, typeAccompagnant
└── widgets/
    ├── admin_layout.dart        # Sidebar + header (recherche, dark mode, profil), child
    └── app_logo.dart            # Logo image ou fallback icône
```

---

## Installation et lancement

### Prérequis

- **Flutter SDK** (voir [flutter.dev](https://flutter.dev)) — à installer et à ajouter au PATH.
- **Backend API** tournant (ex. `http://localhost:3000`). Sans backend, la connexion et les données ne fonctionneront pas.

### Étapes (à partager avec les collègues)

1. **Cloner le dépôt** (si applicable) et se placer à la racine du projet.

2. **Copier le fichier d’environnement**
   ```bash
   cp .env.example .env
   ```
   Éditer `.env` et définir `VITE_API_URL`. En local avec le proxy CORS : `VITE_API_URL=http://localhost:3001`.

3. **Installer les dépendances**
   ```bash
   flutter pub get
   ```

4. **Lancer l’application**
   - Web (Chrome) : `flutter run -d chrome`
   - Ou : `flutter run` puis choisir un appareil (web, macOS, etc.)

5. **Optionnel – Proxy CORS (Flutter Web uniquement)**  
   Si le backend est sur le port 3000 et que les requêtes sont bloquées par CORS :
   - Démarrer le backend sur 3000.
   - Lancer `node proxy/proxy.js` à la racine.
   - Dans `.env`, utiliser `VITE_API_URL=http://localhost:3001`.

---

## API backend attendue

<!-- Contrat entre le backoffice et le backend : les routes et formats décrits ici doivent être respectés par l’API. Utile pour l’équipe backend et pour débugger. -->

- **POST /auth/login**  
  Body : `{ "email", "password" }`  
  Réponse : `{ "access_token"` ou `"accessToken"`, `"user"` } (user avec `role`).

- **GET /user/me** (en-tête `Authorization: Bearer <token>`)  
  Réponse : objet user.

- **GET /admin/users?page=&limit=&role=&search=**  
  Réponse : `{ "data": User[], "total", "page", "limit", "totalPages" }`.

- **POST /admin/users**  
  Body : nom, prenom, email, password, telephone, role, typeHandicap, besoinSpecifique, animalAssistance, typeAccompagnant, specialisation, disponible, langue, statut, etc.  
  Réponse : user créé.

- **GET /admin/users/:id**  
  Réponse : user.

- **PATCH /admin/users/:id**  
  Body : champs modifiables (sans mot de passe).  
  Réponse : user mis à jour.

- **DELETE /admin/users/:id**  
  Réponse : succès sans corps ou message.

- **GET /admin/stats**  
  Réponse : `{ "totalUsers", "totalHandicapes", "totalAccompagnants"` (ou `totalBeneficiaries`, `totalCompanions`), `"recentRegistrations" }`.

Les routes `/admin/*` doivent être protégées côté backend (vérification du rôle ADMIN).

---

## Tests

- **test/widget_test.dart** : test(s) widget (ex. LoginScreen, présence du bouton « Se connecter »).
- Lancer : `flutter test`.

---

## Dépannage

<!-- Section à compléter avec les problèmes courants rencontrés par l’équipe. -->

- **« Chargement… » infini** : vérifier que le backend répond et que `VITE_API_URL` pointe vers la bonne URL. Vérifier la console (erreurs réseau, CORS).
- **Erreur CORS en web** : utiliser le proxy (voir [Proxy CORS](#proxy-cors)) ou vérifier les en-têtes CORS du backend.
- **401 après connexion** : le token peut être rejeté par le backend (format, expiration). Vérifier les logs backend et la réponse de `/auth/login`.
- **Données vides ou 404** : s’assurer que les routes backend correspondent à [API backend attendue](#api-backend-attendue) (noms de champs, structure JSON).
- **Flutter non reconnu** : installer le SDK Flutter et l’ajouter au PATH ; exécuter `flutter doctor`.

---

## Ressources

- [Documentation Flutter](https://docs.flutter.dev/)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook](https://docs.flutter.dev/cookbook)

---

*Dernière mise à jour de ce README : à adapter selon les conventions de l’équipe (date, contacts, processus de contribution).*
