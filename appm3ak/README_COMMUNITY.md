# Module Communauté & Entraide - Documentation

## 📋 Vue d'ensemble

Le module **Communauté & Entraide** permet aux utilisateurs de Ma3ak de :
- 📍 **Découvrir et partager des lieux accessibles** (pharmacies, restaurants, hôpitaux, etc.)
- 💬 **Échanger des conseils et témoignages** via des publications communautaires
- 🤝 **Demander et offrir de l'aide** avec géolocalisation pour le matching de proximité

Ce module est accessible depuis l'onglet **"Milieux"** (4ème onglet) de la navigation principale.

---

## 🎯 Fonctionnalités principales

### 1. Lieux accessibles 📍

Permet aux utilisateurs de :
- **Consulter** une liste de lieux accessibles validés (pharmacies, restaurants, hôpitaux, écoles, etc.)
- **Rechercher** des lieux par nom ou catégorie
- **Filtrer** par catégorie (PHARMACY, RESTAURANT, HOSPITAL, SCHOOL, SHOP, PUBLICTRANSPORT, PARK, OTHER)
- **Voir les détails** d'un lieu (adresse, description, téléphone, horaires, équipements)
- **Soumettre** de nouveaux lieux pour modération par les administrateurs
- **Trouver des lieux à proximité** en utilisant la géolocalisation

**Écrans :**
- `CommunityLocationsScreen` : Liste des lieux avec recherche et filtres
- `LocationDetailScreen` : Détails d'un lieu spécifique
- `SubmitLocationScreen` : Formulaire de soumission d'un nouveau lieu

### 2. Publications de la communauté 💬

Permet aux utilisateurs de :
- **Créer des posts** pour partager des conseils, témoignages ou questions
- **Catégoriser les posts** par type de handicap (moteur, visuel, auditif, cognitif) ou par type de contenu (conseil, témoignage, général)
- **Commenter** les posts pour échanger avec la communauté
- **Voir les posts** avec pagination (20 par page)
- **Filtrer** les posts par type

**Types de posts disponibles :**
- `general` : Général
- `handicapMoteur` : Handicap moteur
- `handicapVisuel` : Handicap visuel
- `handicapAuditif` : Handicap auditif
- `handicapCognitif` : Handicap cognitif
- `conseil` : Conseil
- `temoignage` : Témoignage
- `autre` : Autre

**Écrans :**
- `CommunityPostsScreen` : Liste des posts avec filtres et pagination
- `PostDetailScreen` : Détails d'un post avec ses commentaires
- `CreatePostScreen` : Formulaire de création d'un nouveau post

### 3. Demandes d'aide 🤝

Permet aux utilisateurs de :
- **Créer des demandes d'aide** avec description et géolocalisation
- **Voir les demandes** disponibles avec pagination
- **Mettre à jour le statut** d'une demande (EN_ATTENTE, EN_COURS, TERMINEE, ANNULEE)
- **Trouver des demandes à proximité** grâce à la géolocalisation (pour le matching avec les bénévoles)

**Statuts des demandes :**
- `enAttente` (EN_ATTENTE) : En attente d'un bénévole
- `enCours` (EN_COURS) : Un bénévole a accepté
- `terminee` (TERMINEE) : Demande terminée
- `annulee` (ANNULEE) : Demande annulée

**Écrans :**
- `HelpRequestsScreen` : Liste des demandes avec pagination et formulaire de création
- `CreateHelpRequestScreen` : Formulaire dédié pour créer une demande d'aide

---

## 🏗️ Architecture technique

### Structure des fichiers

```
lib/
├── data/
│   ├── models/
│   │   ├── location_model.dart          # Modèle LocationModel, LocationCategory, LocationStatus
│   │   ├── post_model.dart              # Modèle PostModel, PostType
│   │   ├── comment_model.dart           # Modèle CommentModel
│   │   └── help_request_model.dart      # Modèle HelpRequestModel, HelpRequestStatus
│   └── repositories/
│       ├── location_repository.dart      # API calls pour les lieux
│       └── community_repository.dart     # API calls pour posts, commentaires, demandes d'aide
├── providers/
│   └── community_providers.dart         # Riverpod providers pour la gestion d'état
├── features/
│   └── community/
│       └── screens/
│           ├── community_main_screen.dart        # Écran principal avec TabBar
│           ├── community_locations_screen.dart   # Liste des lieux
│           ├── location_detail_screen.dart      # Détails d'un lieu
│           ├── submit_location_screen.dart       # Soumission d'un lieu
│           ├── community_posts_screen.dart       # Liste des posts
│           ├── post_detail_screen.dart           # Détails d'un post
│           ├── create_post_screen.dart           # Création d'un post
│           ├── help_requests_screen.dart         # Liste des demandes d'aide
│           └── create_help_request_screen.dart   # Création d'une demande d'aide
└── router/
    └── app_router.dart                   # Routes ajoutées pour le module
```

### Modèles de données

#### LocationModel
```dart
class LocationModel {
  final String id;
  final String nom;
  final LocationCategory categorie;  // PHARMACY, RESTAURANT, HOSPITAL, etc.
  final String adresse;
  final String ville;
  final double latitude;
  final double longitude;
  final String? description;
  final String? telephone;
  final String? horaires;
  final List<String>? amenities;     // Équipements d'accessibilité
  final LocationStatus statut;        // PENDING, APPROVED, REJECTED
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
```

#### PostModel
```dart
class PostModel {
  final String id;
  final String userId;
  final String contenu;
  final PostType type;               // general, handicapMoteur, conseil, etc.
  final UserModel? user;              // Utilisateur créateur (populated)
  final int? commentsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
```

#### CommentModel
```dart
class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String contenu;
  final UserModel? user;              // Utilisateur créateur (populated)
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
  final HelpRequestStatus statut;     // EN_ATTENTE, EN_COURS, TERMINEE, ANNULEE
  final UserModel? user;              // Utilisateur créateur (populated)
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
```

### Repositories

#### LocationRepository
Méthodes disponibles :
- `getAllLocations()` : Récupère tous les lieux approuvés
- `getLocationById(String id)` : Récupère un lieu par ID
- `getNearbyLocations({latitude, longitude, maxDistance?})` : Trouve les lieux à proximité
- `submitLocation({nom, categorie, adresse, ville, latitude, longitude, ...})` : Soumet un nouveau lieu

#### CommunityRepository
Méthodes disponibles :
- **Posts :**
  - `getPosts({page, limit})` : Liste paginée des posts
  - `getPostById(String id)` : Récupère un post par ID
  - `createPost({contenu, type})` : Crée un nouveau post
- **Commentaires :**
  - `getPostComments(String postId)` : Récupère les commentaires d'un post
  - `createComment({postId, contenu})` : Ajoute un commentaire
- **Demandes d'aide :**
  - `getHelpRequests({page, limit})` : Liste paginée des demandes
  - `createHelpRequest({description, latitude, longitude})` : Crée une demande
  - `updateHelpRequestStatus({id, statut})` : Met à jour le statut

### Providers Riverpod

Tous les providers sont définis dans `lib/providers/community_providers.dart` :

#### Providers pour les lieux
- `locationRepositoryProvider` : Instance du repository
- `locationsProvider` : Liste de tous les lieux
- `locationByIdProvider` : Un lieu par ID (family)
- `nearbyLocationsProvider` : Lieux à proximité (family)
- `submitLocationProvider` : Soumission d'un lieu (family)

#### Providers pour les posts
- `communityRepositoryProvider` : Instance du repository
- `postsProvider` : Liste paginée des posts (family)
- `postByIdProvider` : Un post par ID (family)
- `createPostProvider` : Création d'un post (family)
- `postCommentsProvider` : Commentaires d'un post (family)
- `createCommentProvider` : Création d'un commentaire (family)

#### Providers pour les demandes d'aide
- `helpRequestsProvider` : Liste paginée des demandes (family)
- `helpRequestByIdProvider` : Une demande par ID (family)
- `createHelpRequestProvider` : Création d'une demande (family)
- `updateHelpRequestStatusProvider` : Mise à jour du statut (family)

**Note :** Les providers utilisent la syntaxe des **records** pour les paramètres :
```dart
// ✅ Correct
postsProvider((page: 1, limit: 20))

// ❌ Incorrect
postsProvider(page: 1, limit: 20)
```

---

## 🔌 Endpoints API

Tous les endpoints sont définis dans `lib/data/api/endpoints.dart` :

### Lieux accessibles
- `GET /lieux` : Liste de tous les lieux
- `GET /lieux/nearby?latitude={lat}&longitude={lng}&maxDistance={dist?}` : Lieux à proximité
- `GET /lieux/:id` : Détails d'un lieu
- `POST /lieux` : Soumettre un nouveau lieu

### Publications
- `GET /community/posts?page={page}&limit={limit}` : Liste paginée des posts
- `GET /community/posts/:id` : Détails d'un post
- `POST /community/posts` : Créer un post
- `GET /community/posts/:postId/comments` : Commentaires d'un post
- `POST /community/posts/:postId/comments` : Ajouter un commentaire

### Demandes d'aide
- `GET /community/help-requests?page={page}&limit={limit}` : Liste paginée des demandes
- `POST /community/help-requests` : Créer une demande
- `POST /community/help-requests/:id/statut` : Mettre à jour le statut

---

## 💾 Structure de la base de données

### Collections/Schémas MongoDB

#### Lieux (`lieux`)
```javascript
{
  _id: ObjectId,
  nom: String,
  typeLieu: String,              // PHARMACY, RESTAURANT, etc.
  adresse: String,                // Adresse complète (inclut ville)
  location: {
    type: "Point",
    coordinates: [longitude, latitude]  // GeoJSON format
  },
  description: String?,
  statut: String,                 // PENDING, APPROVED, REJECTED
  createdBy: ObjectId,            // Référence User
  createdAt: Date,
  updatedAt: Date
}
```

#### Posts (`posts`)
```javascript
{
  _id: ObjectId,
  userId: ObjectId,               // Référence User
  contenu: String,
  type: String,                   // general, handicapMoteur, etc.
  createdAt: Date,
  updatedAt: Date
}
```

#### Commentaires (`comments`)
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

#### Demandes d'aide (`help-requests`)
```javascript
{
  _id: ObjectId,
  userId: ObjectId,               // Référence User
  description: String,
  latitude: Number,
  longitude: Number,
  statut: String,                 // EN_ATTENTE, EN_COURS, TERMINEE, ANNULEE
  createdAt: Date,
  updatedAt: Date
}
```

---

## 🚀 Guide d'utilisation

### Accéder au module

1. Lancez l'application Flutter
2. Connectez-vous avec votre compte
3. Cliquez sur l'onglet **"Milieux"** (4ème onglet en bas)
4. Vous verrez 3 onglets en haut :
   - 📍 **Lieux accessibles**
   - 💬 **Publications de la communauté**
   - 🤝 **Demandes d'aide**

### Utiliser les lieux accessibles

1. **Consulter les lieux :**
   - L'onglet "Lieux accessibles" affiche automatiquement tous les lieux approuvés
   - Utilisez la barre de recherche pour filtrer par nom
   - Utilisez les filtres par catégorie (pharmacie, restaurant, etc.)

2. **Voir les détails d'un lieu :**
   - Cliquez sur une carte de lieu
   - Vous verrez l'adresse complète, la description, le téléphone, les horaires et les équipements

3. **Soumettre un nouveau lieu :**
   - Cliquez sur le bouton **"+"** en bas à droite
   - Remplissez le formulaire (nom, catégorie, adresse, ville, coordonnées)
   - Ajoutez une description, téléphone, horaires si disponibles
   - Soumettez pour modération

### Utiliser les publications

1. **Voir les posts :**
   - L'onglet "Publications" affiche tous les posts de la communauté
   - Utilisez le filtre pour voir les posts par type (handicap moteur, visuel, etc.)
   - La pagination charge automatiquement 20 posts à la fois

2. **Créer un post :**
   - Cliquez sur le bouton **"+"** en bas à droite
   - Choisissez le type de post (général, conseil, témoignage, etc.)
   - Écrivez votre contenu
   - Publiez

3. **Commenter un post :**
   - Cliquez sur un post pour voir les détails
   - Faites défiler pour voir les commentaires existants
   - Écrivez votre commentaire en bas
   - Envoyez

### Utiliser les demandes d'aide

1. **Voir les demandes :**
   - L'onglet "Demandes d'aide" affiche toutes les demandes
   - Les demandes sont triées par date (plus récentes en premier)
   - Vous pouvez voir le statut de chaque demande (En attente, En cours, Terminée)

2. **Créer une demande :**
   - Cliquez sur le bouton **"+"** en bas à droite
   - Décrivez votre besoin d'aide
   - La géolocalisation sera utilisée pour trouver des bénévoles à proximité
   - Publiez la demande

3. **Mettre à jour le statut :**
   - Sur une demande, vous pouvez changer le statut
   - Par exemple : "En attente" → "En cours" → "Terminée"

---

## 📝 Fichiers créés/modifiés

### Nouveaux fichiers créés

#### Modèles
- ✅ `lib/data/models/location_model.dart`
- ✅ `lib/data/models/post_model.dart`
- ✅ `lib/data/models/comment_model.dart`
- ✅ `lib/data/models/help_request_model.dart`

#### Repositories
- ✅ `lib/data/repositories/location_repository.dart`
- ✅ `lib/data/repositories/community_repository.dart`

#### Providers
- ✅ `lib/providers/community_providers.dart`

#### Écrans
- ✅ `lib/features/community/screens/community_main_screen.dart`
- ✅ `lib/features/community/screens/community_locations_screen.dart`
- ✅ `lib/features/community/screens/location_detail_screen.dart`
- ✅ `lib/features/community/screens/submit_location_screen.dart`
- ✅ `lib/features/community/screens/community_posts_screen.dart`
- ✅ `lib/features/community/screens/post_detail_screen.dart`
- ✅ `lib/features/community/screens/create_post_screen.dart`
- ✅ `lib/features/community/screens/help_requests_screen.dart`
- ✅ `lib/features/community/screens/create_help_request_screen.dart`

### Fichiers modifiés

- ✅ `lib/router/app_router.dart` : Ajout des routes pour le module
- ✅ `lib/features/home/screens/main_shell.dart` : Intégration de `CommunityMainScreen` dans l'onglet "Milieux"
- ✅ `lib/core/l10n/app_strings.dart` : Ajout des chaînes de localisation pour le module
- ✅ `lib/data/api/endpoints.dart` : Ajout des endpoints communautaires (déjà présents)

---

## 🔐 Sécurité et modération

### Lieux accessibles
- Les lieux soumis sont en statut `PENDING` par défaut
- Seuls les administrateurs peuvent approuver (`APPROVED`) ou rejeter (`REJECTED`) un lieu
- Les utilisateurs ne voient que les lieux approuvés dans la liste principale

### Publications et commentaires
- Tous les utilisateurs authentifiés peuvent créer des posts et commentaires
- Les posts sont publics à toute la communauté
- **À implémenter :** Système de signalement pour contenu inapproprié

### Demandes d'aide
- Les demandes sont visibles par tous les utilisateurs
- Le matching avec les bénévoles se fait via la géolocalisation (backend)
- **À implémenter :** Système de réputation et de confiance pour les bénévoles

---

## 🎨 Localisation

Toutes les chaînes de caractères sont localisées en français et arabe via `AppStrings` :

```dart
// Exemples de chaînes ajoutées
strings.community              // "Communauté & Entraide"
strings.places                 // "Lieux accessibles"
strings.communityPosts         // "Publications de la communauté"
strings.helpRequests           // "Demandes d'aide"
strings.submitLocation         // "Soumettre un lieu"
strings.createPost             // "Créer une publication"
strings.createHelpRequest      // "Créer une demande d'aide"
// ... et bien d'autres
```

---

## 🐛 Problèmes connus et améliorations futures

### À implémenter
1. **Géolocalisation réelle** : Utiliser `geolocator` pour obtenir automatiquement la position dans `CreateHelpRequestScreen`
2. **Matching intelligent** : Implémenter la fonction de matching dans le backend pour trouver les bénévoles à proximité
3. **Système de signalement** : Ajouter un bouton de signalement sur chaque post/demande pour contenu inapproprié
4. **Notifications** : Notifier les utilisateurs lorsqu'ils reçoivent un commentaire ou une réponse à leur demande
5. **Images pour les lieux** : Support complet pour l'upload d'images lors de la soumission d'un lieu
6. **Recherche avancée** : Recherche par ville, distance, etc. pour les lieux
7. **Filtres avancés** : Filtrer les demandes d'aide par statut, distance, etc.

### Problèmes résolus
- ✅ Syntaxe Riverpod corrigée (utilisation de records au lieu de paramètres nommés)
- ✅ CORS configuré pour permettre les requêtes depuis le frontend
- ✅ Adaptation des champs backend (typeLieu ↔ categorie, location GeoJSON ↔ latitude/longitude)
- ✅ Gestion des erreurs et affichage des messages d'erreur utilisateur

---

## 📚 Ressources

- **Backend API** : NestJS avec MongoDB
- **Frontend** : Flutter avec Riverpod pour l'état global
- **Navigation** : GoRouter
- **HTTP Client** : Dio
- **Localisation** : AppStrings (FR/AR)

---

## 👥 Contribution

Pour ajouter de nouvelles fonctionnalités au module :

1. **Ajouter un modèle** : Créez un nouveau fichier dans `lib/data/models/`
2. **Ajouter un repository** : Créez ou modifiez un repository dans `lib/data/repositories/`
3. **Ajouter des providers** : Ajoutez les providers dans `lib/providers/community_providers.dart`
4. **Créer l'écran** : Créez un nouveau fichier dans `lib/features/community/screens/`
5. **Ajouter la route** : Ajoutez la route dans `lib/router/app_router.dart`
6. **Localiser** : Ajoutez les chaînes dans `lib/core/l10n/app_strings.dart`

---

**Documentation créée le :** $(date)  
**Version du module :** 1.0.0  
**Dernière mise à jour :** $(date)





