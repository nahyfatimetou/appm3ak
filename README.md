# M3ak (Ma3ak) - Monorepo

Projet Flutter + NestJS pour mobilite, inclusion et entraide (Communaute/Aide).

## Structure

- `frontend/appm3ak/appm3ak` : application Flutter principale
- `backend/backend-m3ak 2` : API NestJS principale
- `README_COMMUNAUTE_AIDE.md` : guide dedie module Communaute/Aide

## Prerequis

- Node.js 20+ (ou 22)
- npm
- Flutter SDK (Dart 3.x)
- Android Studio / emulateur (ou appareil physique)
- MongoDB (local ou distant)

## Lancer le backend

```bash
cd "backend/backend-m3ak 2"
npm install
npm run start:dev
```

Par defaut, API sur `http://localhost:3000`.

## Lancer le frontend

```bash
cd frontend/appm3ak/appm3ak
flutter pub get
flutter run
```

### URL API selon appareil

- Emulateur Android: `http://10.0.2.2:3000`
- iOS Simulator / Web desktop: `http://localhost:3000`
- Telephone reel: `http://<IP_LAN_PC>:3000`

Exemple:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## Docs utiles

- Frontend detail: `frontend/appm3ak/appm3ak/README.md`
- Backend detail: `backend/backend-m3ak 2/README.md`
- Communaute/Aide: `README_COMMUNAUTE_AIDE.md`
- Community Flutter module: `frontend/appm3ak/appm3ak/lib/features/community/README.md`

## Depannage rapide

- Timeout login vers `10.0.2.2:3000`:
  - verifier que `npm run start:dev` tourne
  - verifier firewall Windows (port 3000 / node.exe)
  - verifier la bonne URL API pour ton device
- Erreur `Cannot find module '@nestjs/core'`:
  - relancer `npm install` dans `backend/backend-m3ak 2`

## Export ZIP legers (< 25 Mo)

Script disponible:

```bash
powershell -ExecutionPolicy Bypass -File scripts/export_slim_zips.ps1
```

Genere:

- `frontend.zip`
- `backend.zip`

avec suppression du module Sante et de gros assets pour partage rapide.

