# Tester KORA sur ton téléphone (APK Android, Wi-Fi local)

Topologie : ton téléphone → Wi-Fi → Windows `192.168.1.12:8001` → WSL `8001` → FastAPI.

## 1. Côté Windows — un seul setup réseau (1 fois)

Ouvre PowerShell **en administrateur** et lance :

```powershell
cd \\wsl.localhost\Ubuntu\home\dev\projects\KORA\mobile\scripts
.\expose_backend_lan.ps1
```

Le script :
- Détecte l'IP WSL du moment
- Crée un port-forward `0.0.0.0:8001 → IP_WSL:8001`
- Ouvre le firewall pour le port 8001 (profil Privé uniquement = Wi-Fi maison)
- T'affiche l'IP LAN à utiliser

À refaire à chaque reboot de WSL (l'IP change).

Pour tout révoquer plus tard : `.\expose_backend_lan.ps1 -Remove`

## 2. Côté WSL — lancer le backend en écoutant sur 0.0.0.0

```bash
cd ~/projects/KORA/backend
bash scripts/dev_lan.sh
```

Test rapide depuis ton téléphone (sur le même Wi-Fi) :
- Ouvre le navigateur du téléphone → `http://192.168.1.12:8001/docs`
- Si la doc Swagger s'affiche → le forward est OK

## 3. Côté WSL — APK déjà buildé

L'APK est ici :
```
~/projects/KORA/mobile/build/app/outputs/flutter-apk/app-release.apk
```

## 4. Transférer l'APK sur le téléphone

Le plus simple selon ton matériel :

- **USB** : connecte le téléphone, copie-colle l'APK dans `Documents/` ou `Download/`
- **Google Drive** : `cp ~/projects/KORA/mobile/build/app/outputs/flutter-apk/app-release.apk /mnt/c/Users/YEO/OneDrive/Documents/`, puis Drive ou OneDrive le syncera, ouvre-le depuis l'app Drive du téléphone

Côté Windows tu peux aussi :
```powershell
copy \\wsl.localhost\Ubuntu\home\dev\projects\KORA\mobile\build\app\outputs\flutter-apk\app-release.apk C:\Users\YEO\Downloads\
```
Puis envoie via Telegram/Drive depuis Windows.

## 5. Installer l'APK sur le téléphone

1. Ouvre l'APK depuis ton gestionnaire de fichiers / Drive / Telegram
2. Android : *« Cette source ne peut pas installer d'apps »* → Autoriser pour cette source
3. Confirme l'installation
4. **Important** : la première fois Android demande *« Bloquer Play Protect ? »* — choisis *« Installer quand même »* (l'APK n'est pas signé Play Store)

## 6. Premier lancement

L'app démarre sur l'écran d'auth. Entre ton numéro CI (`07...`, `01...` ou `05...`).

Comme `DEBUG_OTP=true` côté backend dev, le code OTP s'affiche dans la réponse de l'API (cf. logs uvicorn). L'APK est en mode release donc l'écran ne pré-affichera **pas** le code (sécurité), tu dois le lire dans les logs WSL et le taper à la main.

> Si tu veux que l'écran te pré-affiche le code OTP (pratique pour les démos), rebuild en debug : `flutter build apk --debug --dart-define=API_BASE_URL=...`

## Dépannage

| Symptôme | Cause probable | Fix |
|---|---|---|
| Téléphone : page blanche, *« Pas de connexion au serveur »* | Forward Windows down ou WSL rebooté | Re-run `expose_backend_lan.ps1` |
| Téléphone : *« Demande invalide »* sur OTP | Téléphone format E.164 attendu | Saisis 8 chiffres au minimum, `+225` ajouté côté app |
| Téléphone : crash à l'ouverture | APK pas signé / Play Protect bloque | Installer quand même via le bouton avancé |
| Téléphone : OTP jamais reçu par SMS | Backend en dev avec `LoggingSmsProvider` | Normal — lis le code dans les logs uvicorn |
| Backend KO sur Windows IP | Backend lancé sans `--host 0.0.0.0` | Utilise `scripts/dev_lan.sh` |
