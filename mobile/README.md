# KORA Mobile (Flutter)

Frontend Flutter de **KORA Finance** — coaching financier comportemental (Côte d'Ivoire).
Branché sur le backend FastAPI (`../backend`) via son API REST `/api/v1` + JWT.

Conforme au cahier des charges (stack Flutter + Riverpod + GoRouter) et à la charte
graphique V1.0 (couleurs, Poppins/Inter, grille 4dp, ton bienveillant FR-CI).

## Stack

| Couche | Choix |
|---|---|
| UI | Flutter 3.35 / Material 3 |
| State management | Riverpod (`flutter_riverpod`) |
| Navigation | GoRouter (5 onglets + redirection auth) |
| Réseau | Dio + intercepteur Bearer JWT |
| Stockage token | `flutter_secure_storage` |
| Polices | `google_fonts` (Poppins + Inter) |
| Graphiques | `fl_chart` |

## ⚠️ Pré-requis toolchain (important)

Ce projet vit sur le **système de fichiers WSL** (`/home/dev/projects/KORA/mobile`).
Le Flutter **Windows** ne sait pas builder depuis un chemin `\\wsl.localhost\...`
(il bascule sur `C:\Windows`). Deux options propres :

1. **(Recommandé) Installer Flutter nativement dans WSL Ubuntu.**
   Tu as déjà `java` et `dart` natifs dans WSL ; il manque le SDK Flutter Linux :
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable ~/flutter
   echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
   flutter --version            # doit pointer vers ~/flutter/bin/flutter (Linux)
   flutter doctor
   ```
   Pour lancer en **web** (le plus simple en dev) : installer Chrome dans WSL, ou
   builder l'APK et l'installer sur un téléphone.

2. **Développer côté Windows** : copier `mobile/` sur un chemin Windows natif
   (ex. `C:\Users\YEO\dev\kora_mobile`) et utiliser Flutter Windows + Android Studio.
   Inconvénient : le code est dédoublé hors du repo backend.

## Démarrage

```bash
cd mobile

# 1. Générer les dossiers de plateforme (android/, web/) — non versionnés ici
flutter create . --org ci.korafinance --project-name kora --platforms=android,web

# 2. Récupérer les dépendances
flutter pub get

# 3. Lancer le backend d'abord (dans ../backend) : uvicorn app.main:app --port 8001
#    puis lancer l'app en pointant sur l'API.
```

### URL de l'API selon la cible

Le backend dev écoute sur `:8001`. L'URL est injectée au build :

```bash
# Web / desktop (localhost fonctionne)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8001/api/v1

# Émulateur Android (localhost de l'hôte = 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001/api/v1

# Téléphone physique sur le même réseau (remplace par l'IP de ta machine)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8001/api/v1
```

Par défaut (`Env.apiBaseUrl`) : `http://localhost:8001/api/v1`.

### OTP en développement

Si le backend tourne avec `DEBUG_OTP=true`, la réponse de `/auth/otp/request`
contient le code, et l'écran OTP le pré-remplit automatiquement (voir `Env.showDebugOtp`).

## Icône de lancement

`assets/images/logo_kora.jpeg` est l'icône officielle. Pour la définir comme icône
Android/launcher après `flutter create` :

```bash
flutter pub add dev:flutter_launcher_icons
```
puis ajouter dans `pubspec.yaml` :
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/logo_kora.jpeg"
```
et lancer `dart run flutter_launcher_icons`.

## Architecture (feature-first)

```
lib/
├── main.dart                 # bootstrap + locale FR
├── app.dart                  # MaterialApp.router + thèmes light/dark
├── core/
│   ├── config/env.dart        # API_BASE_URL (--dart-define)
│   ├── format/money.dart      # "150 000 FCFA"
│   ├── network/               # Dio + intercepteur JWT + ApiException
│   ├── storage/token_store.dart
│   ├── theme/                 # couleurs, typo, spacing, ThemeData (charte)
│   ├── router/                # GoRouter + AppShell (5 onglets) + splash
│   └── providers.dart         # tokenStore + dio
├── features/
│   ├── auth/                  # OTP : phone -> code -> JWT (CDC F01)
│   ├── dashboard/             # Accueil : solde, score, dépenses (F06/F09)
│   ├── goals/                 # Objectifs : liste + création + alimentation (F12/F13)
│   ├── analytics/             # Analyse (squelette, F08)
│   ├── community/             # Communauté (squelette, F19-F24)
│   └── profile/               # Profil + déconnexion (F25)
└── shared/widgets/            # logo, barre de progression, score ring, cards
```

Chaque feature suit `data/` (repository Dio) → `domain/` (modèles) →
`application/` (providers Riverpod) → `presentation/` (écrans).

## Mapping endpoints backend

| Écran | Endpoint |
|---|---|
| Auth | `POST /auth/otp/request`, `POST /auth/otp/verify` |
| Accueil | `GET /dashboard/summary`, `GET /dashboard/score` |
| Objectifs | `GET/POST /goals`, `POST /goals/{id}/contribute` |

## État d'avancement

- ✅ Design system charte (couleurs, Poppins/Inter, grille 4dp, thèmes light/dark)
- ✅ Auth OTP complet (2 écrans) + session JWT persistée + redirection
- ✅ Dashboard : solde, mini-stats, score animé, camembert dépenses, conseil du jour
- ✅ Objectifs : liste, barres de progression, création, alimentation
- ✅ Coquille 5 onglets + Profil (déconnexion)
- ⏭️ Analyse & Communauté : écrans "bientôt" à compléter
- ⏭️ Ingestion notifications (NotificationListener Android, CDC F03) — platform channel
- ⏭️ Épargne auto / règles (F14), coffre-fort (F15), badges/défis (F19-F20)
- ⏭️ Tests widget + bundling des polices pour l'offline strict
```
