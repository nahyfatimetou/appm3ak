# 📖 Module Communauté & Entraide - Documentation Complète

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture générale](#architecture-générale)
3. [Backend (NestJS)](#backend-nestjs)
4. [Frontend (Flutter)](#frontend-flutter)
5. [Backoffice Web](#backoffice-web)
6. [API Endpoints](#api-endpoints)
7. [Base de données](#base-de-données)
8. [Sécurité et modération](#sécurité-et-modération)
9. [Guide d'utilisation](#guide-dutilisation)
10. [Installation et déploiement](#installation-et-déploiement)

---

## 🎯 Vue d'ensemble

Le module **Communauté & Entraide** est un système complet permettant aux utilisateurs de Ma3ak de :

- 📍 **Découvrir et partager des lieux accessibles** (pharmacies, restaurants, hôpitaux, etc.)
- 💬 **Échanger des conseils et témoignages** via des publications communautaires
- 🤝 **Demander et offrir de l'aide** avec géolocalisation pour le matching de proximité
- 🔍 **Trouver des lieux à proximité** en utilisant la géolocalisation

### Fonctionnalités principales

1. **Lieux accessibles** : Catalogue de lieux validés avec recherche par proximité
2. **Publications communautaires** : Forum de discussion par type de handicap
3. **Demandes d'aide** : Système de matching entre demandeurs et bénévoles
4. **Modération** : Interface admin pour valider le contenu
5. **Statistiques** : Dashboard pour suivre l'activité de la communauté

---

## 🏗️ Architecture générale

```
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND (Flutter)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Lieux      │  │   Posts      │  │  Demandes    │     │
│  │   Screen     │  │   Screen     │  │  Screen      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                 │                  │              │
│         └─────────────────┼──────────────────┘              │
│                           │                                  │
│                  ┌─────────▼─────────┐                       │
│                  │  Riverpod State   │                       │
│                  │   Management      │                       │
│                  └─────────┬─────────┘                       │
│                           │                                  │
└───────────────────────────┼──────────────────────────────────┘
                            │
                            │ HTTP/REST API
                            │
┌───────────────────────────▼──────────────────────────────────┐
│                    BACKEND (NestJS)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Lieu       │  │  Community   │  │    Admin     │     │
│  │  Controller  │  │  Controller  │  │  Controller  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                 │                  │              │
│         └─────────────────┼──────────────────┘              │
│                           │                                  │
│                  ┌─────────▼─────────┐                       │
│                  │   Services        │                       │
│                  │   (Business      │                       │
│                  │    Logic)         │                       │
│                  └─────────┬─────────┘                       │
│                           │                                  │
└───────────────────────────┼──────────────────────────────────┘
                            │
                            │ MongoDB
                            │
                  ┌─────────▼─────────┐
                  │   Base de données │
                  │   (MongoDB)       │
                  └───────────────────┘
```

---

## 🔧 Backend (NestJS)

### Structure des modules

```
backend/
├── src/
│   ├── lieu/                          # Module Lieux accessibles
│   │   ├── schemas/
│   │   │   └── lieu.schema.ts         # Schéma MongoDB avec statut
│   │   ├── dto/
│   │   │   └── create-lieu.dto.ts     # DTO de validation
│   │   ├── lieu.service.ts            # Logique métier
│   │   ├── lieu.controller.ts         # Endpoints API
│   │   └── lieu.module.ts             # Module NestJS
│   │
│   ├── community/                     # Module Communauté
│   │   ├── schemas/
│   │   │   ├── post.schema.ts         # Schéma Posts
│   │   │   ├── comment.schema.ts      # Schéma Commentaires
│   │   │   └── help-request.schema.ts # Schéma Demandes d'aide
│   │   ├── community.service.ts        # Logique métier
│   │   ├── community.controller.ts    # Endpoints API
│   │   └── community.module.ts        # Module NestJS
│   │
│   ├── admin/                         # Module Administration
│   │   ├── admin.service.ts           # Méthodes de modération
│   │   ├── admin.controller.ts        # Endpoints admin
│   │   └── admin.module.ts            # Module NestJS
│   │
│   └── config/                        # Module Référentiels
│       ├── schemas/
│       │   ├── location-category.schema.ts
│       │   ├── post-type.schema.ts
│       │   └── handicap-type.schema.ts
│       ├── dto/
│       │   ├── create-location-category.dto.ts
│       │   ├── create-post-type.dto.ts
│       │   └── create-handicap-type.dto.ts
│       ├── config.service.ts
│       ├── config.controller.ts
│       └── config.module.ts
```

### Fonctionnalités backend

#### 1. Module Lieu

**Schéma** (`lieu.schema.ts`) :
- Champs : `nom`, `typeLieu`, `adresse`, `ville`, `latitude`, `longitude`
- Géolocalisation : `location` (GeoJSON Point) avec index 2dsphere
- Modération : `statut` (PENDING, APPROVED, REJECTED)
- Traçabilité : `createdBy`, `rejectionReason`
- Équipements : `amenities`, `telephone`, `horaires`, `images`

**Service** (`lieu.service.ts`) :
- `create()` : Créer un lieu (statut PENDING par défaut)
- `findAll()` : Liste paginée (filtre APPROVED par défaut)
- `findNearby()` : Recherche géospatiale par proximité
- `findOne()` : Détails d'un lieu
- `approve()` / `reject()` : Modération (admin)

**Endpoints** :
- `GET /lieux` : Liste des lieux approuvés
- `GET /lieux/nearby` : Lieux à proximité (géolocalisation)
- `GET /lieux/:id` : Détails d'un lieu
- `POST /lieux` : Soumettre un lieu (authentifié)

#### 2. Module Community

**Schémas** :
- **Post** : `userId`, `contenu`, `type`, `commentsCount`, `likesCount`
- **Comment** : `postId`, `userId`, `contenu`
- **HelpRequest** : `userId`, `description`, `latitude`, `longitude`, `statut`, `acceptedBy`

**Service** (`community.service.ts`) :
- **Posts** : `getPosts(page, limit, type)` avec pagination
- **Commentaires** : `getPostComments(postId)`, `createComment()`
- **Demandes** : `getHelpRequests(page, limit, statut)` avec pagination

**Endpoints** :
- `GET /community/posts` : Liste paginée des posts
- `POST /community/posts` : Créer un post
- `GET /community/posts/:id/comments` : Commentaires d'un post
- `POST /community/posts/:id/comments` : Ajouter un commentaire
- `GET /community/help-requests` : Liste paginée des demandes
- `POST /community/help-requests` : Créer une demande

#### 3. Module Admin

**Service** (`admin.service.ts`) :
- **Modération lieux** : `getPendingLocations()`, `approveLocation()`, `rejectLocation()`
- **Modération posts** : `getAllPosts()`, `deletePost()`, `hidePost()`
- **Modération commentaires** : `getAllComments()`, `deleteComment()`
- **Modération demandes** : `getAllHelpRequests()`, `deleteHelpRequest()`
- **Statistiques** : `getCommunityStats()`, `getActivity()`, `getTopPosts()`

**Endpoints Admin** (14 endpoints) :
- **Lieux** : 4 endpoints (pending, liste, approve, reject)
- **Posts** : 3 endpoints (liste, supprimer, masquer)
- **Commentaires** : 2 endpoints (liste, supprimer)
- **Demandes** : 2 endpoints (liste, supprimer)
- **Statistiques** : 3 endpoints (stats, activité, top-posts)

#### 4. Module Config (Référentiels)

**Schémas** :
- **LocationCategory** : `code`, `labelFr`, `labelAr`, `icon`, `active`, `order`
- **PostTypeConfig** : `code`, `labelFr`, `labelAr`, `active`, `order`
- **HandicapTypeConfig** : `code`, `labelFr`, `labelAr`, `description`, `active`, `order`

**Endpoints** (12 endpoints) :
- **Public** : `GET /config/location-categories`, `/post-types`, `/handicap-types`
- **Admin** : CRUD complet pour chaque référentiel

---

## 📱 Frontend (Flutter)

### Structure des fichiers

```
lib/
├── data/
│   ├── models/
│   │   ├── location_model.dart        # LocationModel, LocationCategory
│   │   ├── post_model.dart            # PostModel, PostType
│   │   ├── comment_model.dart         # CommentModel
│   │   └── help_request_model.dart    # HelpRequestModel
│   └── repositories/
│       ├── location_repository.dart   # API calls lieux
│       └── community_repository.dart  # API calls posts/comments/help
│
├── providers/
│   └── community_providers.dart       # Riverpod providers
│
├── features/
│   └── community/
│       └── screens/
│           ├── community_main_screen.dart        # Écran principal (TabBar)
│           ├── community_locations_screen.dart   # Liste des lieux
│           ├── location_detail_screen.dart      # Détails d'un lieu
│           ├── submit_location_screen.dart      # Soumettre un lieu
│           ├── community_posts_screen.dart      # Liste des posts
│           ├── post_detail_screen.dart          # Détails d'un post
│           ├── create_post_screen.dart          # Créer un post
│           ├── help_requests_screen.dart        # Liste des demandes
│           └── create_help_request_screen.dart  # Créer une demande
│
└── core/
    ├── utils/
    │   └── distance_utils.dart        # Calcul de distance (Haversine)
    └── l10n/
        └── app_strings.dart           # Localisation FR/AR
```

### Écrans Flutter

#### 1. CommunityMainScreen
**Fichier** : `community_main_screen.dart`

Écran principal avec `TabBar` contenant 3 onglets :
- 📍 **Lieux accessibles** → `CommunityLocationsScreen`
- 💬 **Publications** → `CommunityPostsScreen`
- 🤝 **Demandes d'aide** → `HelpRequestsScreen`

#### 2. CommunityLocationsScreen
**Fichier** : `community_locations_screen.dart`

**Fonctionnalités** :
- Liste des lieux approuvés avec pagination
- Barre de recherche par nom
- Filtres par catégorie (FilterChip)
- **Recherche de proximité** :
  - Toggle pour activer/désactiver
  - Slider pour distance maximale (1-50 km)
  - Affichage de la distance sur chaque carte
  - Gestion des permissions de géolocalisation
- Pull-to-refresh
- Navigation vers détails ou soumission

**Providers utilisés** :
- `locationsProvider` : Liste complète
- `nearbyLocationsProvider((lat, lng, maxDistance))` : Lieux à proximité

#### 3. LocationDetailScreen
**Fichier** : `location_detail_screen.dart`

Affiche :
- Nom, catégorie, adresse complète
- Description, téléphone, horaires
- Liste des équipements d'accessibilité
- Carte avec position (si disponible)

#### 4. SubmitLocationScreen
**Fichier** : `submit_location_screen.dart`

Formulaire pour soumettre un lieu :
- Champs : nom, catégorie, adresse, ville, coordonnées
- Optionnel : description, téléphone, horaires, équipements
- Soumission → statut PENDING → modération admin

#### 5. CommunityPostsScreen
**Fichier** : `community_posts_screen.dart`

**Fonctionnalités** :
- Liste paginée des posts (20 par page)
- Filtres par type (FilterChip)
- Pull-to-refresh
- Navigation vers détails ou création

**Providers utilisés** :
- `postsProvider((page: 1, limit: 20))` : Liste paginée

#### 6. PostDetailScreen
**Fichier** : `post_detail_screen.dart`

Affiche :
- Contenu du post, auteur, date
- Liste des commentaires (scrollable)
- Formulaire pour ajouter un commentaire
- Pull-to-refresh

**Providers utilisés** :
- `postByIdProvider(id)` : Détails du post
- `postCommentsProvider(postId)` : Commentaires

#### 7. CreatePostScreen
**Fichier** : `create_post_screen.dart`

Formulaire pour créer un post :
- Sélection du type (dropdown)
- Champ texte pour le contenu
- Validation et soumission

#### 8. HelpRequestsScreen
**Fichier** : `help_requests_screen.dart`

**Fonctionnalités** :
- Liste paginée des demandes (20 par page)
- Filtres par statut (FilterChip)
- Pull-to-refresh
- Navigation vers création

**Providers utilisés** :
- `helpRequestsProvider((page: 1, limit: 20))` : Liste paginée

#### 9. CreateHelpRequestScreen
**Fichier** : `create_help_request_screen.dart`

Formulaire pour créer une demande :
- Description
- Géolocalisation automatique (geolocator)
- Gestion des permissions
- Soumission avec coordonnées

### Modèles de données

#### LocationModel
```dart
class LocationModel {
  final String id;
  final String nom;
  final LocationCategory categorie;
  final String adresse;
  final String ville;
  final double latitude;
  final double longitude;
  final String? description;
  final String? telephone;
  final String? horaires;
  final List<String>? amenities;
  final LocationStatus statut;
  final DateTime? createdAt;
}
```

#### PostModel
```dart
class PostModel {
  final String id;
  final String userId;
  final String contenu;
  final PostType type;
  final UserModel? user;
  final int? commentsCount;
  final DateTime? createdAt;
}
```

#### HelpRequestModel
```dart
class HelpRequestModel {
  final String id;
  final String userId;
  final String description;
  final double latitude;
  final double longitude;
  final HelpRequestStatus statut;
  final UserModel? user;
  final DateTime? createdAt;
}
```

### Providers Riverpod

**Fichier** : `lib/providers/community_providers.dart`

**Syntaxe** : Utilisation de **records** pour les paramètres :
```dart
// ✅ Correct
postsProvider((page: 1, limit: 20))

// ❌ Incorrect
postsProvider(page: 1, limit: 20)
```

**Providers disponibles** :
- `locationRepositoryProvider`
- `locationsProvider`
- `locationByIdProvider(id)`
- `nearbyLocationsProvider((lat, lng, maxDistance))`
- `submitLocationProvider(...)`
- `communityRepositoryProvider`
- `postsProvider((page, limit))`
- `postByIdProvider(id)`
- `createPostProvider(...)`
- `postCommentsProvider(postId)`
- `createCommentProvider(...)`
- `helpRequestsProvider((page, limit))`
- `createHelpRequestProvider(...)`

### Utilitaires

#### DistanceUtils
**Fichier** : `lib/core/utils/distance_utils.dart`

**Fonctions** :
- `calculateDistance(lat1, lon1, lat2, lon2)` : Calcul Haversine (km)
- `formatDistance(distanceKm)` : Formatage (m ou km)

**Utilisation** :
```dart
double distance = DistanceUtils.calculateDistance(
  currentLat, currentLng,
  location.latitude, location.longitude,
);
String formatted = DistanceUtils.formatDistance(distance); // "2.5 km" ou "500 m"
```

### Localisation

**Fichier** : `lib/core/l10n/app_strings.dart`

Toutes les chaînes sont localisées en français et arabe :
- `strings.community`
- `strings.places`
- `strings.communityPosts`
- `strings.helpRequests`
- `strings.findNearbyPlaces`
- `strings.nearbyPlaces`
- `strings.maxDistance`
- `strings.locationPermissionDenied`
- ... et bien d'autres

---

## 🖥️ Backoffice Web

### Interface d'administration

Le backoffice permet aux administrateurs de :

1. **Modérer les lieux** : Approuver/rejeter les soumissions
2. **Modérer le contenu** : Supprimer posts/commentaires inappropriés
3. **Gérer les référentiels** : CRUD pour catégories, types, etc.
4. **Voir les statistiques** : Dashboard avec métriques

### Endpoints Backoffice

#### Modération Lieux
- `GET /admin/lieux/pending` : Lieux en attente
- `GET /admin/lieux?statut=...` : Liste avec filtres
- `PATCH /admin/lieux/:id/approve` : Approuver
- `PATCH /admin/lieux/:id/reject` : Rejeter (avec raison)

#### Modération Posts
- `GET /admin/community/posts` : Liste tous les posts
- `DELETE /admin/community/posts/:id` : Supprimer
- `PATCH /admin/community/posts/:id/hide` : Masquer

#### Modération Commentaires
- `GET /admin/community/comments` : Liste tous les commentaires
- `DELETE /admin/community/comments/:id` : Supprimer

#### Modération Demandes
- `GET /admin/community/help-requests` : Liste toutes les demandes
- `DELETE /admin/community/help-requests/:id` : Supprimer

#### Statistiques
- `GET /admin/community/stats` : Stats générales
- `GET /admin/community/activity?period=...` : Activité par période
- `GET /admin/community/top-posts?limit=...` : Top posts

#### Référentiels
- `GET /config/admin/location-categories` : Liste catégories
- `POST /config/admin/location-categories` : Créer catégorie
- `PATCH /config/admin/location-categories/:id` : Modifier
- `DELETE /config/admin/location-categories/:id` : Supprimer
- (Même structure pour `post-types` et `handicap-types`)

### Sécurité Backoffice

Tous les endpoints admin sont protégés par :
- `@UseGuards(JwtAuthGuard, RolesGuard)`
- `@Roles(Role.ADMIN)`
- `@ApiBearerAuth()`

**Authentification requise** :
```http
Authorization: Bearer <token_jwt>
```

---

## 🔌 API Endpoints

### Endpoints Publics

#### Lieux
- `GET /lieux` : Liste des lieux approuvés
- `GET /lieux/nearby?latitude={lat}&longitude={lng}&maxDistance={dist}` : Lieux à proximité
- `GET /lieux/:id` : Détails d'un lieu
- `POST /lieux` : Soumettre un lieu (authentifié)

#### Posts
- `GET /community/posts?page={page}&limit={limit}&type={type}` : Liste paginée
- `GET /community/posts/:id` : Détails d'un post
- `POST /community/posts` : Créer un post (authentifié)
- `GET /community/posts/:postId/comments` : Commentaires d'un post
- `POST /community/posts/:postId/comments` : Ajouter un commentaire (authentifié)

#### Demandes d'aide
- `GET /community/help-requests?page={page}&limit={limit}&statut={statut}` : Liste paginée
- `POST /community/help-requests` : Créer une demande (authentifié)
- `PATCH /community/help-requests/:id/statut` : Mettre à jour le statut (authentifié)

#### Référentiels (Public)
- `GET /config/location-categories` : Catégories actives
- `GET /config/post-types` : Types de posts actifs
- `GET /config/handicap-types` : Types de handicap actifs

### Endpoints Admin

Voir section [Backoffice Web](#-backoffice-web) ci-dessus.

---

## 💾 Base de données

### Collections MongoDB

#### `lieux`
```javascript
{
  _id: ObjectId,
  nom: String,
  typeLieu: String,              // PHARMACY, RESTAURANT, etc.
  adresse: String,
  ville: String,
  latitude: Number,
  longitude: Number,
  location: {
    type: "Point",
    coordinates: [longitude, latitude]  // GeoJSON
  },
  description: String?,
  telephone: String?,
  horaires: String?,
  amenities: [String],
  images: [String],
  statut: String,                 // PENDING, APPROVED, REJECTED
  createdBy: ObjectId,            // Référence User
  rejectionReason: String?,
  createdAt: Date,
  updatedAt: Date
}
```

**Index** :
- `location: '2dsphere'` : Index géospatial
- `statut: 1`
- `typeLieu: 1`
- `createdBy: 1`

#### `posts`
```javascript
{
  _id: ObjectId,
  userId: ObjectId,               // Référence User
  contenu: String,
  type: String,                   // general, handicapMoteur, etc.
  commentsCount: Number,
  likesCount: Number,
  createdAt: Date,
  updatedAt: Date
}
```

#### `comments`
```javascript
{
  _id: ObjectId,
  postId: ObjectId,               // Référence Post
  userId: ObjectId,               // Référence User
  contenu: String,
  createdAt: Date,
  updatedAt: Date
}
```

#### `help-requests`
```javascript
{
  _id: ObjectId,
  userId: ObjectId,               // Référence User
  description: String,
  latitude: Number,
  longitude: Number,
  statut: String,                 // EN_ATTENTE, EN_COURS, TERMINEE, ANNULEE
  acceptedBy: ObjectId?,         // Référence User (bénévole)
  address: String?,
  city: String?,
  createdAt: Date,
  updatedAt: Date
}
```

**Index** :
- `latitude: 1, longitude: 1`
- `userId: 1`
- `statut: 1`
- `createdAt: -1`

#### `locationcategories`
```javascript
{
  _id: ObjectId,
  code: String,                   // PHARMACY, RESTAURANT, etc.
  labelFr: String,
  labelAr: String,
  icon: String,
  active: Boolean,
  order: Number,
  createdAt: Date,
  updatedAt: Date
}
```

#### `posttypeconfigs`
```javascript
{
  _id: ObjectId,
  code: String,                   // general, handicapMoteur, etc.
  labelFr: String,
  labelAr: String,
  active: Boolean,
  order: Number,
  createdAt: Date,
  updatedAt: Date
}
```

#### `handicaptypeconfigs`
```javascript
{
  _id: ObjectId,
  code: String,
  labelFr: String,
  labelAr: String,
  description: String?,
  active: Boolean,
  order: Number,
  createdAt: Date,
  updatedAt: Date
}
```

### Migration requise

Pour les lieux existants sans champ `statut` :

```javascript
// Dans MongoDB
db.lieux.updateMany(
  { statut: { $exists: false } },
  { $set: { statut: 'APPROVED' } }
)
```

---

## 🔐 Sécurité et modération

### Flux de modération

1. **Utilisateur soumet un lieu** → `statut: PENDING`
2. **Admin voit dans `/admin/lieux/pending`**
3. **Admin approuve ou rejette** → `statut: APPROVED` ou `REJECTED`
4. **Si approuvé** : Lieu visible dans `GET /lieux` pour tous
5. **Si rejeté** : Lieu invisible, raison stockée dans `rejectionReason`

### Permissions

- **Utilisateurs authentifiés** : Peuvent créer posts, commentaires, demandes, soumettre lieux
- **Utilisateurs non authentifiés** : Peuvent seulement consulter (lieux approuvés, posts publics)
- **Administrateurs** : Accès complet (modération, statistiques, référentiels)

### Authentification

Tous les endpoints nécessitant authentification utilisent :
- **JWT Token** dans le header `Authorization: Bearer <token>`
- **Guards NestJS** : `JwtAuthGuard`, `RolesGuard`
- **Décorateurs** : `@CurrentUser()`, `@Roles(Role.ADMIN)`

---

## 📚 Guide d'utilisation

### Pour les utilisateurs (Flutter)

1. **Accéder au module** : Onglet "Milieux" (4ème onglet)
2. **Consulter les lieux** : Onglet "Lieux accessibles"
3. **Rechercher à proximité** : Activer le toggle "Trouver des lieux à proximité"
4. **Créer un post** : Onglet "Publications" → Bouton "+"
5. **Demander de l'aide** : Onglet "Demandes d'aide" → Bouton "+"

### Pour les administrateurs (Backoffice)

1. **Se connecter** : `/auth/login` avec compte ADMIN
2. **Modérer les lieux** : `/admin/lieux/pending`
3. **Voir les stats** : `/admin/community/stats`
4. **Gérer les référentiels** : `/config/admin/location-categories`

---

## 🚀 Installation et déploiement

### Backend

```bash
cd backend
npm install
npm run start:dev
```

**Variables d'environnement** :
- `MONGODB_URI` : URI de connexion MongoDB
- `JWT_SECRET` : Secret pour JWT
- `PORT` : Port du serveur (défaut: 3000)

### Frontend

```bash
cd appm3ak
flutter pub get
flutter run
```

**Dépendances principales** :
- `flutter_riverpod: ^2.6.1`
- `dio: ^5.7.0`
- `go_router: ^14.6.2`
- `geolocator: ^13.0.1`

### Base de données

1. **Créer les collections** : Automatique via Mongoose
2. **Créer les index** : Automatique via les schémas
3. **Migration** : Exécuter la migration pour les lieux existants (voir ci-dessus)

---

## 📊 Statistiques et métriques

### Métriques disponibles

- **Total posts** : Nombre total de publications
- **Total commentaires** : Nombre total de commentaires
- **Total demandes** : Nombre total de demandes d'aide
- **Total lieux** : Nombre total de lieux
- **Lieux en attente** : Nombre de lieux à modérer
- **Posts ce mois** : Activité mensuelle
- **Demandes résolues** : Nombre de demandes terminées
- **Utilisateurs actifs** : Utilisateurs ayant créé du contenu

### Endpoints statistiques

- `GET /admin/community/stats` : Métriques générales
- `GET /admin/community/activity?period=week|month|year` : Activité par période
- `GET /admin/community/top-posts?limit=10` : Top posts

---

## 🎨 Améliorations futures

### À implémenter

1. **Système de signalement** : Signaler du contenu inapproprié
2. **Notifications** : Notifier les utilisateurs (commentaires, réponses)
3. **Images pour lieux** : Upload et affichage d'images
4. **Recherche avancée** : Recherche par ville, distance, etc.
5. **Matching intelligent** : Algorithme de matching bénévoles/demandeurs
6. **Système de réputation** : Points et badges pour les bénévoles
7. **Interface web backoffice** : Dashboard React/Vue/Angular

### Problèmes résolus

- ✅ Syntaxe Riverpod corrigée (records)
- ✅ CORS configuré
- ✅ Adaptation champs backend/frontend
- ✅ Gestion des erreurs
- ✅ Géolocalisation et calcul de distance
- ✅ Pagination complète
- ✅ Modération complète

---

## 📝 Fichiers créés/modifiés

### Backend

**Créés** :
- `src/lieu/` : Module complet
- `src/community/` : Module complet (déjà existant, modifié)
- `src/admin/` : Méthodes de modération ajoutées
- `src/config/` : Module référentiels complet

**Modifiés** :
- `src/lieu/schemas/lieu.schema.ts` : Ajout statut, createdBy, etc.
- `src/lieu/lieu.service.ts` : Gestion des statuts
- `src/admin/admin.service.ts` : Méthodes de modération
- `src/admin/admin.controller.ts` : Endpoints admin
- `src/app.module.ts` : Enregistrement ConfigModule

### Frontend

**Créés** :
- `lib/data/models/` : 4 modèles
- `lib/data/repositories/` : 2 repositories
- `lib/providers/community_providers.dart`
- `lib/features/community/screens/` : 9 écrans
- `lib/core/utils/distance_utils.dart`

**Modifiés** :
- `lib/router/app_router.dart` : Routes ajoutées
- `lib/features/home/screens/main_shell.dart` : Intégration
- `lib/core/l10n/app_strings.dart` : Localisation
- `pubspec.yaml` : Dépendance geolocator

---

## 📚 Ressources

- **Backend** : NestJS + MongoDB + Mongoose
- **Frontend** : Flutter + Riverpod + GoRouter
- **Géolocalisation** : geolocator (Flutter) + MongoDB 2dsphere
- **HTTP** : Dio (Flutter) + Axios (NestJS)
- **Documentation API** : Swagger/OpenAPI

---

## 👥 Contribution

Pour ajouter des fonctionnalités :

1. **Backend** : Créer/modifier modules NestJS
2. **Frontend** : Créer écrans Flutter + providers
3. **Tests** : Ajouter tests unitaires et d'intégration
4. **Documentation** : Mettre à jour ce README

---

**Documentation créée le :** $(date)  
**Version du module :** 1.0.0  
**Dernière mise à jour :** $(date)

---

## ✅ Checklist de vérification

- [x] Backend : Module Lieu complet
- [x] Backend : Module Community avec pagination
- [x] Backend : Module Admin avec modération (14 endpoints)
- [x] Backend : Module Config avec référentiels (12 endpoints)
- [x] Frontend : 9 écrans Flutter
- [x] Frontend : Géolocalisation et recherche de proximité
- [x] Frontend : Pagination complète
- [x] Frontend : Localisation FR/AR
- [x] Sécurité : JWT + Guards
- [x] Documentation : README complet

**Total : 26 endpoints backend + 9 écrans frontend = Module complet !** 🎉





