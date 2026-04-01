# 📋 TODO : Backend et Backoffice - Module Communauté

## 🎯 Vue d'ensemble

Ce document liste **TOUT ce qui doit être ajouté ou modifié** dans le backend et le backoffice pour compléter le module "Communauté & Entraide".

---

## 🔴 PRIORITÉ HAUTE - Backend

### 1. Pagination pour les Posts

**Problème :** Le frontend envoie `page` et `limit` mais le backend ne les gère pas.

**Fichier à modifier :** `backend/src/community/community.controller.ts`

**Avant :**
```typescript
@Get('posts')
findAllPosts(@Query('type') type?: string) {
  const postType = type ? (PostType[type.toUpperCase() as keyof typeof PostType] || undefined) : undefined;
  return this.communityService.findAllPosts(postType);
}
```

**Après :**
```typescript
@Get('posts')
async findAllPosts(
  @Query('type') type?: string,
  @Query('page') page?: string,
  @Query('limit') limit?: string,
) {
  const postType = type ? (PostType[type.toUpperCase() as keyof typeof PostType] || undefined) : undefined;
  const pageNum = page ? parseInt(page, 10) : 1;
  const limitNum = limit ? parseInt(limit, 10) : 20;
  
  return this.communityService.findAllPosts(postType, pageNum, limitNum);
}
```

**Fichier à modifier :** `backend/src/community/community.service.ts`

**Avant :**
```typescript
async findAllPosts(type?: PostType): Promise<PostDocument[]> {
  const query = type ? { type } : {};
  return this.postModel
    .find(query)
    .populate('userId', 'nom prenom email photoProfil')
    .sort({ createdAt: -1 })
    .exec();
}
```

**Après :**
```typescript
async findAllPosts(
  type?: PostType,
  page: number = 1,
  limit: number = 20,
): Promise<{
  data: PostDocument[];
  total: number;
  page: number;
  totalPages: number;
}> {
  const query = type ? { type } : {};
  
  const skip = (page - 1) * limit;
  
  const [data, total] = await Promise.all([
    this.postModel
      .find(query)
      .populate('userId', 'nom prenom email photoProfil')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .exec(),
    this.postModel.countDocuments(query).exec(),
  ]);
  
  const totalPages = Math.ceil(total / limit);
  
  return {
    data,
    total,
    page,
    totalPages,
  };
}
```

---

### 2. Pagination pour les Demandes d'Aide

**Problème :** Même problème que pour les posts.

**Fichier à modifier :** `backend/src/help-request/help-request.controller.ts`

**Avant :**
```typescript
@Get()
findAll() {
  return this.helpRequestService.findAll();
}
```

**Après :**
```typescript
@Get()
async findAll(
  @Query('page') page?: string,
  @Query('limit') limit?: string,
) {
  const pageNum = page ? parseInt(page, 10) : 1;
  const limitNum = limit ? parseInt(limit, 10) : 20;
  
  return this.helpRequestService.findAll(pageNum, limitNum);
}
```

**Fichier à modifier :** `backend/src/help-request/help-request.service.ts`

Ajouter la pagination de la même manière que pour les posts.

---

### 3. Endpoint GET /community/help-requests/:id

**Problème :** Le frontend utilise `getHelpRequestById` mais je n'ai pas vu cet endpoint dans le contrôleur.

**Vérifier :** Si `findOne` existe déjà dans `help-request.controller.ts` (ligne 54-57), c'est bon. Sinon, l'ajouter.

---

### 4. Authentification JWT Complète

**Problème :** Tous les endpoints utilisent `req.user?.id || req.user?._id || req.body.userId` (temporaire).

**À faire :**

1. **Créer un JwtAuthGuard :**
   ```typescript
   // backend/src/auth/jwt-auth.guard.ts
   import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
   import { JwtService } from '@nestjs/jwt';

   @Injectable()
   export class JwtAuthGuard implements CanActivate {
     constructor(private jwtService: JwtService) {}

     async canActivate(context: ExecutionContext): Promise<boolean> {
       const request = context.switchToHttp().getRequest();
       const token = this.extractTokenFromHeader(request);
       
       if (!token) {
         throw new UnauthorizedException();
       }
       
       try {
         const payload = await this.jwtService.verifyAsync(token);
         request.user = payload;
       } catch {
         throw new UnauthorizedException();
       }
       
       return true;
     }

     private extractTokenFromHeader(request: any): string | undefined {
       const [type, token] = request.headers.authorization?.split(' ') ?? [];
       return type === 'Bearer' ? token : undefined;
     }
   }
   ```

2. **Protéger les routes :**
   ```typescript
   // Dans community.controller.ts et help-request.controller.ts
   import { UseGuards } from '@nestjs/common';
   import { JwtAuthGuard } from '../auth/jwt-auth.guard';

   @Controller('community')
   @UseGuards(JwtAuthGuard) // Protéger toutes les routes
   export class CommunityController {
     // ...
   }
   ```

3. **Supprimer les lignes temporaires :**
   Remplacer `req.user?.id || req.user?._id || req.body.userId` par `req.user.id` ou `req.user.sub` (selon votre structure JWT).

---

### 5. Endpoints pour les Lieux Accessibles

**Problème :** Le frontend utilise `/lieux` mais je n'ai pas trouvé le contrôleur correspondant.

**À créer :**

1. **Créer le module :**
   ```
   backend/src/lieux/
     ├── lieux.controller.ts
     ├── lieux.service.ts
     ├── lieux.module.ts
     ├── dto/
     │   └── create-lieu.dto.ts
     └── schemas/
         └── lieu.schema.ts
   ```

2. **Schema MongoDB :**
   ```typescript
   // lieux/schemas/lieu.schema.ts
   import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
   import { Document } from 'mongoose';

   export type LieuDocument = Lieu & Document;

   @Schema({ timestamps: true })
   export class Lieu {
     @Prop({ required: true })
     nom: string;

     @Prop({ required: true })
     typeLieu: string; // PHARMACY, RESTAURANT, etc.

     @Prop({ required: true })
     adresse: string;

     @Prop({
       type: {
         type: String,
         enum: ['Point'],
         default: 'Point',
       },
       coordinates: {
         type: [Number],
         required: true,
       },
     })
     location: {
       type: string;
       coordinates: [number, number]; // [longitude, latitude]
     };

     @Prop()
     description?: string;

     @Prop({ enum: ['PENDING', 'APPROVED', 'REJECTED'], default: 'PENDING' })
     statut: string;

     @Prop({ type: 'ObjectId', ref: 'User' })
     createdBy: string;

     @Prop()
     telephone?: string;

     @Prop()
     horaires?: string;

     @Prop([String])
     amenities?: string[];
   }

   export const LieuSchema = SchemaFactory.createForClass(Lieu);
   LieuSchema.index({ location: '2dsphere' }); // Index géospatial
   ```

3. **Controller :**
   ```typescript
   // lieux/lieux.controller.ts
   import { Controller, Get, Post, Body, Param, Query, UseGuards, Request } from '@nestjs/common';
   import { LieuxService } from './lieux.service';
   import { CreateLieuDto } from './dto/create-lieu.dto';
   import { JwtAuthGuard } from '../auth/jwt-auth.guard';

   @Controller('lieux')
   export class LieuxController {
     constructor(private readonly lieuxService: LieuxService) {}

     @Get()
     findAll() {
       return this.lieuxService.findAll();
     }

     @Get('nearby')
     findNearby(
       @Query('latitude') latitude: string,
       @Query('longitude') longitude: string,
       @Query('maxDistance') maxDistance?: string,
     ) {
       const lat = parseFloat(latitude);
       const lng = parseFloat(longitude);
       const maxDist = maxDistance ? parseFloat(maxDistance) : 10;
       return this.lieuxService.findNearby(lat, lng, maxDist);
     }

     @Get(':id')
     findOne(@Param('id') id: string) {
       return this.lieuxService.findOne(id);
     }

     @Post()
     @UseGuards(JwtAuthGuard)
     create(@Body() createDto: CreateLieuDto, @Request() req: any) {
       return this.lieuxService.create(req.user.id, createDto);
     }
   }
   ```

4. **Service avec recherche géospatiale :**
   ```typescript
   // lieux/lieux.service.ts
   import { Injectable } from '@nestjs/common';
   import { InjectModel } from '@nestjs/mongoose';
   import { Model } from 'mongoose';
   import { Lieu, LieuDocument } from './schemas/lieu.schema';
   import { CreateLieuDto } from './dto/create-lieu.dto';

   @Injectable()
   export class LieuxService {
     constructor(
       @InjectModel(Lieu.name) private lieuModel: Model<LieuDocument>,
     ) {}

     async findAll(): Promise<LieuDocument[]> {
       return this.lieuModel
         .find({ statut: 'APPROVED' })
         .populate('createdBy', 'nom prenom')
         .exec();
     }

     async findNearby(
       latitude: number,
       longitude: number,
       maxDistance: number,
     ): Promise<LieuDocument[]> {
       return this.lieuModel
         .find({
           location: {
             $near: {
               $geometry: {
                 type: 'Point',
                 coordinates: [longitude, latitude], // GeoJSON: [lng, lat]
               },
               $maxDistance: maxDistance * 1000, // Convertir km en mètres
             },
           },
           statut: 'APPROVED',
         })
         .populate('createdBy', 'nom prenom')
         .exec();
     }

     async findOne(id: string): Promise<LieuDocument> {
       return this.lieuModel.findById(id).populate('createdBy', 'nom prenom').exec();
     }

     async create(userId: string, createDto: CreateLieuDto): Promise<LieuDocument> {
       const lieu = new this.lieuModel({
         ...createDto,
         createdBy: userId,
         location: {
           type: 'Point',
           coordinates: [createDto.longitude, createDto.latitude],
         },
       });
       return lieu.save();
     }
   }
   ```

---

### 6. Gestion des Erreurs Standardisée

**À ajouter :** Des messages d'erreur clairs et cohérents.

**Exemple :**
```typescript
// Dans les services
if (!post) {
  throw new NotFoundException({
    message: 'Post introuvable',
    error: 'NOT_FOUND',
    statusCode: 404,
  });
}
```

---

## 🟡 PRIORITÉ MOYENNE - Backend

### 7. Système de Signalement (Reporting)

**À créer :** Endpoints pour signaler des posts/commentaires/demandes inappropriés.

**Endpoints à ajouter :**
- `POST /community/posts/:id/report` - Signaler un post
- `POST /community/comments/:id/report` - Signaler un commentaire
- `POST /community/help-requests/:id/report` - Signaler une demande

**Schema :**
```typescript
@Schema()
export class Report {
  @Prop({ required: true })
  type: string; // 'post', 'comment', 'help-request'

  @Prop({ required: true })
  targetId: string;

  @Prop({ required: true })
  reportedBy: string;

  @Prop({ required: true })
  reason: string; // 'spam', 'inappropriate', 'harassment', etc.

  @Prop()
  description?: string;

  @Prop({ default: 'PENDING' })
  status: string; // 'PENDING', 'REVIEWED', 'RESOLVED'
}
```

---

### 8. Notifications

**À créer :** Système de notifications pour :
- Nouveau commentaire sur un post
- Nouvelle réponse à une demande d'aide
- Lieu approuvé/rejeté

**Endpoints :**
- `GET /notifications` - Liste des notifications
- `PATCH /notifications/:id/read` - Marquer comme lu
- `PATCH /notifications/read-all` - Tout marquer comme lu

---

### 9. Statistiques pour le Backoffice

**À créer :** Endpoints pour les statistiques de la communauté.

**Endpoints :**
- `GET /admin/community/stats` - Statistiques générales
  - Nombre total de posts
  - Nombre total de commentaires
  - Nombre de demandes d'aide
  - Nombre de lieux en attente de modération
  - Activité par jour/semaine

---

## 🟢 PRIORITÉ BASSE - Backend

### 10. Recherche Avancée

**À ajouter :** Recherche full-text dans les posts et commentaires.

**Utiliser :** MongoDB Text Index ou Elasticsearch.

---

### 11. Système de Tags/Catégories

**À ajouter :** Permettre aux utilisateurs de taguer leurs posts.

---

## 🎨 BACKOFFICE - Interface d'Administration

### 1. Dashboard de Modération

**Pages à créer :**

#### A. Modération des Lieux
- **Route :** `/admin/lieux/moderation`
- **Fonctionnalités :**
  - Liste des lieux en attente (`statut: PENDING`)
  - Voir les détails d'un lieu
  - Boutons : "Approuver" / "Rejeter"
  - Filtres : Par catégorie, par date de soumission
  - Recherche par nom/adresse

**Endpoints nécessaires :**
- `GET /admin/lieux/pending` - Lieux en attente
- `PATCH /admin/lieux/:id/approve` - Approuver un lieu
- `PATCH /admin/lieux/:id/reject` - Rejeter un lieu (avec raison)

#### B. Modération des Posts
- **Route :** `/admin/community/posts`
- **Fonctionnalités :**
  - Liste de tous les posts
  - Voir le contenu et les commentaires
  - Supprimer un post (avec raison)
  - Masquer un post (soft delete)

**Endpoints nécessaires :**
- `GET /admin/community/posts` - Tous les posts (avec pagination)
- `DELETE /admin/community/posts/:id` - Supprimer un post (admin)
- `PATCH /admin/community/posts/:id/hide` - Masquer un post

#### C. Modération des Commentaires
- **Route :** `/admin/community/comments`
- **Fonctionnalités :**
  - Liste de tous les commentaires
  - Supprimer un commentaire
  - Voir le post associé

**Endpoints nécessaires :**
- `GET /admin/community/comments` - Tous les commentaires
- `DELETE /admin/community/comments/:id` - Supprimer un commentaire

#### D. Modération des Demandes d'Aide
- **Route :** `/admin/community/help-requests`
- **Fonctionnalités :**
  - Liste de toutes les demandes
  - Voir les détails
  - Supprimer une demande inappropriée

---

### 2. Gestion des Signalements

**Page à créer :**
- **Route :** `/admin/reports`
- **Fonctionnalités :**
  - Liste des signalements en attente
  - Voir le contenu signalé
  - Actions : "Ignorer" / "Supprimer le contenu" / "Bannir l'utilisateur"
  - Historique des signalements traités

**Endpoints nécessaires :**
- `GET /admin/reports` - Liste des signalements
- `PATCH /admin/reports/:id/resolve` - Résoudre un signalement
- `DELETE /admin/reports/:id` - Ignorer un signalement

---

### 3. Statistiques et Analytics

**Page à créer :**
- **Route :** `/admin/community/analytics`
- **Fonctionnalités :**
  - Graphiques d'activité (posts par jour, commentaires par jour)
  - Nombre d'utilisateurs actifs
  - Top posts les plus commentés
  - Lieux les plus visités
  - Demandes d'aide par statut

**Endpoints nécessaires :**
- `GET /admin/community/stats` - Statistiques générales
- `GET /admin/community/activity` - Activité par période
- `GET /admin/community/top-posts` - Posts les plus populaires

---

### 4. Gestion des Utilisateurs

**Page à créer :**
- **Route :** `/admin/users`
- **Fonctionnalités :**
  - Liste des utilisateurs
  - Voir le profil d'un utilisateur
  - Voir l'historique (posts, commentaires, demandes)
  - Actions : "Bannir" / "Débannir" / "Supprimer le compte"

**Endpoints nécessaires :**
- `GET /admin/users` - Liste des utilisateurs
- `GET /admin/users/:id/activity` - Activité d'un utilisateur
- `PATCH /admin/users/:id/ban` - Bannir un utilisateur
- `DELETE /admin/users/:id` - Supprimer un compte

---

## 📝 Checklist de Vérification

### Backend
- [ ] Pagination pour les posts
- [ ] Pagination pour les demandes d'aide
- [ ] Authentification JWT complète
- [ ] Endpoints pour les lieux accessibles
- [ ] Gestion des erreurs standardisée
- [ ] Système de signalement
- [ ] Notifications
- [ ] Statistiques pour le backoffice

### Backoffice
- [ ] Dashboard de modération des lieux
- [ ] Dashboard de modération des posts
- [ ] Dashboard de modération des commentaires
- [ ] Gestion des signalements
- [ ] Page de statistiques
- [ ] Gestion des utilisateurs

---

## 🚀 Ordre de Priorité Recommandé

1. **Semaine 1 :** Pagination + Authentification JWT
2. **Semaine 2 :** Endpoints lieux accessibles
3. **Semaine 3 :** Backoffice - Modération des lieux
4. **Semaine 4 :** Backoffice - Modération posts/commentaires
5. **Semaine 5 :** Système de signalement
6. **Semaine 6 :** Notifications + Statistiques

---

**Document créé le :** $(date)  
**Dernière mise à jour :** $(date)





