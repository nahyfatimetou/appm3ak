# Guide de débogage : Aucun lieu trouvé à proximité

## Problème
Vous activez l'onglet "Trouver des lieux à proximité" mais aucun lieu n'apparaît.

## Causes possibles

### 1. **Aucun lieu approuvé dans la base de données**
Le backend ne retourne que les lieux avec le statut `APPROVED`.

**Solution** :
1. Connectez-vous au backoffice (webm3ak)
2. Allez dans "Modération" → "Lieux"
3. Vérifiez s'il y a des lieux en attente (`PENDING`)
4. Approuvez les lieux en cliquant sur le bouton "Approuver" (✓)

### 2. **Les lieux sont trop loin**
La distance maximale par défaut est de 10 km. Si tous les lieux sont plus loin, ils ne s'afficheront pas.

**Solution** :
- Augmentez la distance maximale avec le slider (jusqu'à 50 km)
- Ou cliquez sur le bouton "Rechercher jusqu'à 50 km" dans le message d'erreur

### 3. **Coordonnées GPS invalides**
Si votre position GPS n'est pas correcte, la recherche ne fonctionnera pas.

**Vérification** :
- Le message d'erreur affiche maintenant votre position GPS
- Vérifiez que les coordonnées sont valides (latitude entre -90 et 90, longitude entre -180 et 180)

### 4. **Les lieux n'ont pas de coordonnées valides**
Si les lieux dans la base de données n'ont pas de coordonnées (latitude/longitude), ils ne seront pas trouvés.

**Vérification** :
- Dans le backoffice, vérifiez que chaque lieu a des coordonnées valides
- Les coordonnées doivent être des nombres (ex: 36.8065, 10.1815 pour Tunis)

### 5. **Erreur réseau ou backend inaccessible**
Si le backend n'est pas accessible, la requête échouera.

**Vérification** :
- Vérifiez que le backend est démarré
- Vérifiez l'URL de l'API dans la configuration
- Regardez les logs dans la console pour voir les erreurs

## Comment vérifier

### 1. Vérifier les logs dans la console
Cherchez les messages suivants :
- `🔵 [LocationRepository] getNearbyLocations:` - Appel API
- `✅ [LocationRepository] X lieux convertis avec succès` - Succès
- `❌ [LocationRepository] Erreur getNearbyLocations:` - Erreur

### 2. Tester l'endpoint directement
Utilisez Swagger ou cURL pour tester l'endpoint :
```bash
GET /lieux/nearby?latitude=36.8065&longitude=10.1815&maxDistance=10000
```

### 3. Vérifier dans le backoffice
1. Connectez-vous au backoffice
2. Allez dans "Modération" → "Lieux"
3. Vérifiez :
   - Combien de lieux sont approuvés (`APPROVED`)
   - Les coordonnées de chaque lieu
   - La distance entre votre position et les lieux

## Solutions rapides

### Solution 1 : Approuver des lieux
1. Connectez-vous au backoffice
2. Allez dans "Modération" → "Lieux"
3. Approuvez les lieux en attente

### Solution 2 : Augmenter la distance
1. Dans l'app, augmentez le slider de distance maximale
2. Ou cliquez sur "Rechercher jusqu'à 50 km"

### Solution 3 : Créer un lieu de test
1. Dans l'app, créez un nouveau lieu près de votre position
2. Dans le backoffice, approuvez ce lieu
3. Rechargez la recherche

## Messages d'erreur améliorés

L'application affiche maintenant :
- Un message clair expliquant pourquoi aucun lieu n'est trouvé
- Votre position GPS actuelle
- Un bouton pour augmenter la distance de recherche

## Test avec des données de test

Pour tester rapidement, vous pouvez créer un lieu de test dans le backoffice avec :
- Nom : "Test Pharmacie"
- Catégorie : PHARMACY
- Adresse : "Avenue Habib Bourguiba, Tunis"
- Latitude : 36.8065
- Longitude : 10.1815
- Statut : APPROVED

Ensuite, activez la recherche par proximité depuis Tunis (ou une position proche).





