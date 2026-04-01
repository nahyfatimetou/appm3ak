# 🔧 Correction des Erreurs

## ✅ Problèmes Résolus

### 1. Erreur de Connexion : `ERR_CONNECTION_REFUSED` sur `localhost:3001`

**Cause** : L'application essaie de se connecter au port 3001 au lieu de 3000.

**Solution** : Forcer l'URL du backend à utiliser le port 3000.

**Commande pour lancer l'application** :
```powershell
cd "C:\Users\DELL\Downloads\appm3ak\appm3ak"
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

---

### 2. Erreurs de Layout : `RenderFlex overflowed`

**Causes** :
- Le texte dans les boutons déborde sur les petits écrans
- Les Row sans contraintes flexibles causent des débordements

**Solutions appliquées** :
1. Ajout de `Flexible` autour du texte "Connexion" dans le bouton principal
2. Réduction du padding horizontal dans le séparateur "OU"
3. Réduction de la taille de l'icône Google et ajustement du texte

---

## 🚀 Démarrage Complet

### Étape 1 : Démarrer le Backend

**Terminal 1** :
```powershell
cd "C:\Users\DELL\Downloads\backend-m3ak\backend-m3ak 2"
npm run start:dev
```

Attendez : `Ma3ak API running on http://localhost:3000`

---

### Étape 2 : Lancer l'Application Flutter

**Terminal 2** :
```powershell
cd "C:\Users\DELL\Downloads\appm3ak\appm3ak"
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

---

## ✅ Vérifications

1. **Backend démarré** : http://localhost:3000 accessible
2. **Application lancée** : Pas d'erreur `ERR_CONNECTION_REFUSED`
3. **UI correcte** : Pas d'erreur `RenderFlex overflowed`

---

## 🔍 Si les erreurs persistent

### Erreur de connexion

1. Vérifiez que le backend est bien démarré :
   ```powershell
   netstat -ano | findstr :3000
   ```

2. Testez l'API directement :
   - Ouvrez : http://localhost:3000
   - Devrait afficher : `{"message":"Hello World!"}`

3. Videz le cache du navigateur (Ctrl+Shift+Delete)

### Erreurs de layout

1. Redémarrez l'application Flutter (hot reload ne suffit pas toujours)
2. Vérifiez la taille de la fenêtre du navigateur
3. Utilisez les DevTools Flutter pour inspecter les widgets

---

**✅ Après ces corrections, tout devrait fonctionner correctement !**





