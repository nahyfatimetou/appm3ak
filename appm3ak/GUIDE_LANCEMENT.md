# Guide complet : Lancer l'application Ma3ak

## 📋 Prérequis

### 1. Vérifier que Flutter est installé
```bash
flutter --version
```
Si Flutter n'est pas installé, téléchargez-le depuis : https://flutter.dev/docs/get-started/install

### 2. Vérifier que Chrome est installé
- Chrome doit être installé sur votre système
- Flutter utilise Chrome pour lancer l'application web

### 3. Vérifier que le backend est démarré
Le backend doit être en cours d'exécution sur `http://localhost:3000`

Pour démarrer le backend :
```bash
cd "C:\Users\DELL\Downloads\backend-m3ak\backend-m3ak 2"
npm install  # Si ce n'est pas déjà fait
npm run start:dev
```

## 🚀 Étapes pour lancer l'application

### Étape 1 : Ouvrir le terminal
- Ouvrez PowerShell ou CMD
- Naviguez vers le dossier de l'application

### Étape 2 : Aller dans le dossier de l'application
```bash
cd "C:\Users\DELL\Downloads\appm3ak\appm3ak"
```

### Étape 3 : Vérifier les dépendances
```bash
flutter pub get
```
Cette commande installe toutes les dépendances nécessaires.

### Étape 4 : Vérifier les appareils disponibles
```bash
flutter devices
```
Vous devriez voir Chrome dans la liste des appareils disponibles.

### Étape 5 : Lancer l'application sur Chrome
```bash
flutter run -d chrome
```

**OU** si Chrome n'est pas détecté automatiquement :
```bash
flutter run -d web-server --web-port=8080
```
Puis ouvrez manuellement Chrome et allez sur `http://localhost:8080`

## ⏱️ Temps d'attente

- **Première compilation** : 2-5 minutes
- **Compilations suivantes** : 30-60 secondes
- **Hot reload** : Instantané

## 🎮 Commandes pendant l'exécution

Une fois l'application lancée, vous pouvez utiliser :

- **`r`** - Hot reload (recharger rapidement les changements)
- **`R`** - Hot restart (redémarrer complètement l'application)
- **`q`** - Quitter l'application
- **`h`** - Afficher l'aide

## 🔧 Résolution de problèmes

### Problème 1 : "No devices found"
**Solution** :
```bash
flutter config --enable-web
flutter devices
```

### Problème 2 : "Chrome not found"
**Solution** :
- Installez Google Chrome
- Ou utilisez : `flutter run -d web-server --web-port=8080`

### Problème 3 : Erreur de compilation
**Solution** :
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### Problème 4 : Erreur de connexion au backend
**Solution** :
- Vérifiez que le backend est démarré sur `http://localhost:3000`
- Vérifiez l'URL de l'API dans `lib/core/config/app_config.dart`

### Problème 5 : Erreur de permissions (géolocalisation)
**Solution** :
- Dans Chrome, cliquez sur l'icône de cadenas dans la barre d'adresse
- Autorisez l'accès à la localisation

## 📱 Tester la fonctionnalité "Lieux à proximité"

Une fois l'application lancée :

1. **Connectez-vous** ou créez un compte
2. Allez dans **"Communauté & Entraide"**
3. Cliquez sur **"Lieux accessibles"**
4. Activez le toggle **"Trouver des lieux à proximité"**
5. **Autorisez l'accès à la localisation** quand Chrome le demande
6. Les lieux à proximité devraient s'afficher

## 🎯 Commandes rapides (copier-coller)

### Lancer l'application (une seule commande)
```bash
cd "C:\Users\DELL\Downloads\appm3ak\appm3ak" && flutter pub get && flutter run -d chrome
```

### Nettoyer et relancer
```bash
cd "C:\Users\DELL\Downloads\appm3ak\appm3ak" && flutter clean && flutter pub get && flutter run -d chrome
```

## 📝 Checklist avant de lancer

- [ ] Flutter est installé et configuré
- [ ] Chrome est installé
- [ ] Le backend est démarré sur `http://localhost:3000`
- [ ] Les dépendances sont installées (`flutter pub get`)
- [ ] Vous êtes dans le bon dossier (`appm3ak\appm3ak`)

## 🌐 URLs importantes

- **Application Flutter** : `http://localhost:xxxxx` (port affiché dans le terminal)
- **Backend API** : `http://localhost:3000`
- **Backoffice** : `http://localhost:xxxxx` (si vous lancez aussi le backoffice)

## 💡 Astuces

1. **Mode debug** : L'application se lance automatiquement en mode debug avec hot reload
2. **Console** : Ouvrez la console du navigateur (F12) pour voir les logs
3. **Hot reload** : Modifiez le code et appuyez sur `r` pour voir les changements instantanément
4. **Performance** : La première compilation est plus lente, les suivantes sont plus rapides





