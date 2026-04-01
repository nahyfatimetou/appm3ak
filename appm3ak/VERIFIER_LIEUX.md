# Guide rapide : Vérifier pourquoi aucun lieu n'apparaît

## ✅ Checklist rapide

### 1. Vérifier dans le backoffice
```
1. Ouvrez le backoffice (webm3ak)
2. Connectez-vous en tant qu'admin
3. Allez dans "Modération" → "Lieux"
4. Vérifiez :
   ✓ Y a-t-il des lieux dans la liste ?
   ✓ Combien sont approuvés (statut APPROVED) ?
   ✓ Les lieux ont-ils des coordonnées (latitude, longitude) ?
```

### 2. Vérifier dans l'application
```
1. Activez "Trouver des lieux à proximité"
2. Autorisez l'accès à la localisation
3. Regardez le message affiché :
   - Si "Aucun lieu approuvé trouvé" → Il faut approuver des lieux
   - Si votre position GPS s'affiche → La recherche fonctionne mais aucun lieu proche
   - Si erreur réseau → Vérifier que le backend est démarré
```

### 3. Vérifier les logs
```
Dans la console de débogage, cherchez :
- 🔵 [LocationRepository] getNearbyLocations → Appel API
- ✅ [LocationRepository] X lieux convertis → Succès
- ❌ [LocationRepository] Erreur → Problème
```

## 🔧 Solutions rapides

### Solution 1 : Approuver des lieux existants
Si vous avez des lieux en attente (`PENDING`) :
1. Backoffice → Modération → Lieux
2. Cliquez sur "Approuver" (✓) pour chaque lieu
3. Rechargez la recherche dans l'app

### Solution 2 : Créer un lieu de test
1. Dans l'app : Créez un nouveau lieu près de votre position
2. Dans le backoffice : Approuvez ce lieu
3. Dans l'app : Rechargez la recherche

### Solution 3 : Augmenter la distance
1. Dans l'app : Augmentez le slider jusqu'à 50 km
2. Ou cliquez sur "Rechercher jusqu'à 50 km"

## 📍 Test rapide avec cURL

Testez l'endpoint directement :
```bash
curl "http://localhost:3000/lieux/nearby?latitude=36.8065&longitude=10.1815&maxDistance=10000"
```

Remplacez `36.8065` et `10.1815` par vos coordonnées GPS.

## 🐛 Problèmes courants

### Problème : "Aucun lieu approuvé trouvé"
**Cause** : Tous les lieux sont en statut `PENDING` ou `REJECTED`
**Solution** : Approuvez des lieux dans le backoffice

### Problème : Position GPS incorrecte
**Cause** : Les services de localisation ne fonctionnent pas
**Solution** : Vérifiez les permissions de localisation dans les paramètres

### Problème : Erreur réseau
**Cause** : Le backend n'est pas accessible
**Solution** : Vérifiez que le backend est démarré sur le port 3000

### Problème : Distance trop petite
**Cause** : Tous les lieux sont plus loin que 10 km
**Solution** : Augmentez la distance maximale à 50 km





