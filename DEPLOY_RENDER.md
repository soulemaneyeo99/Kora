# Déployer le backend KORA sur Render (free tier)

Objectif : passer de "backend local WSL" à "URL HTTPS publique joignable depuis le téléphone n'importe où" — sans payer.

Topologie :

```
Téléphone (APK)
   │  HTTPS
   ▼
https://kora-backend.onrender.com/api/v1/...    (Render Web Service free)
   │
   ├── Postgres ────► Render Postgres (free, 90 jours)
   └── Redis    ────► Upstash Redis (free)
```

Coût total : **0 €/mois** tant qu'on reste sur les free tiers.

---

## 1. Créer un compte Upstash + récupérer l'URL Redis

Render Redis est payant. On utilise Upstash à la place — free tier 256 Mo, 10k commandes/jour, largement suffisant pour notre OTP throttle.

1. Va sur https://upstash.com → **Sign Up** (avec ton GitHub, c'est plus rapide)
2. Une fois connecté → **Create Database** :
   - Name : `kora-redis`
   - Type : **Regional** (Single zone, c'est le free)
   - Region : **eu-west-1 (Ireland)** ou la plus proche de Frankfurt
   - TLS : laissé activé (par défaut)
3. Crée → Tu arrives sur le détail
4. Onglet **Connect** → copie l'**Endpoint Redis URL** (format `rediss://default:XXXX@xxxx.upstash.io:6379`)
5. Garde cette URL de côté pour l'étape 3.

## 2. Pousser le code sur GitHub

Le repo `github.com/soulemaneyeo99/Kora` existe et est vide. On va pousser le monorepo (backend/ + mobile/).

Dans WSL :

```bash
cd ~/projects/KORA

# Le repo est déjà initialisé, commit fait, remote configuré.
# Il ne reste qu'à pousser :
git push -u origin main
```

À la première fois Git va demander tes identifiants GitHub. Deux options :

- **Plus simple** : utiliser un **Personal Access Token** comme mot de passe
  1. https://github.com/settings/tokens/new
  2. Note : `kora-deploy`
  3. Expiration : 90 days
  4. Scopes : coche `repo`
  5. Generate → copie le token (commence par `ghp_...`)
  6. Au prompt `Password:` de git, colle le token

- **Plus durable** : configurer une clé SSH (https://docs.github.com/en/authentication/connecting-to-github-with-ssh)

Une fois le push fait, refresh `github.com/soulemaneyeo99/Kora` — tu dois voir tous les fichiers.

## 3. Créer le service Render

1. Va sur https://render.com → **Sign up with GitHub** (autorise Render à voir tes repos)
2. Dashboard → **+ New** → **Blueprint**
3. Connecte ton repo `soulemaneyeo99/Kora`
4. Render détecte automatiquement le fichier `render.yaml` à la racine
5. **Blueprint name** : `kora` → **Apply**
6. Render va créer :
   - 1 Web Service : `kora-backend` (build en cours...)
   - 1 Postgres : `kora-postgres` (provisioning...)

Le **premier build prend 5-10 min** (install deps Python, migrations Alembic, etc.).

## 4. Configurer les env vars manquantes

Pendant que ça build, **Dashboard Render → kora-backend → Environment** :

| Variable | Valeur | Note |
|---|---|---|
| `REDIS_URL` | `rediss://default:XXXX@xxxx.upstash.io:6379` | Copié depuis Upstash (étape 1) |
| `AT_API_KEY` | *(vide)* | Vide = OTP loggué dans Render logs (suffit pour tester) |

Les autres (DATABASE_URL, JWT_SECRET, ENVIRONMENT, DEBUG_OTP, etc.) sont gérées automatiquement par le `render.yaml`.

**Save Changes** → Render redéploie automatiquement.

## 5. Vérifier le déploiement

Quand le build est passé au vert (status **Live**) :

1. Note l'URL fournie par Render, du style `https://kora-backend-xxxx.onrender.com`
2. Test rapide : ouvre `https://kora-backend-xxxx.onrender.com/api/v1/health` dans ton navigateur → doit répondre `{"status":"ok"}` ou similaire
3. Ouvre `https://kora-backend-xxxx.onrender.com/docs` → 404 (normal, on a désactivé `/docs` en prod)
4. Onglet **Logs** Render → tu verras *"Seed: N categories systeme creees"* au premier démarrage

## 6. Rebuild l'APK avec l'URL Render

Dans WSL :

```bash
cd ~/projects/KORA/mobile
source scripts/env_android.sh

flutter build apk --release \
  --dart-define=API_BASE_URL=https://kora-backend-xxxx.onrender.com/api/v1

cp build/app/outputs/flutter-apk/app-release.apk \
   /mnt/c/Users/YEO/Downloads/kora-finance-0.1.0.apk
```

Réinstalle sur le téléphone par-dessus l'ancien APK (Android conserve les data) ou désinstalle d'abord.

## 7. Premier login depuis le téléphone (en 4G ou n'importe quel Wi-Fi)

1. Lance KORA Finance
2. Entre ton numéro
3. **Premier appel = cold start ~30s** (Render free tier dort après 15 min d'inactivité). Patiente, la balle est dans le 45s timeout Dio.
4. Va sur Render Dashboard → **kora-backend → Logs** :
   ```
   [SMS-MOCK] -> +2250712345678 : Code KORA : 482931
   ```
5. Tape le code → tu es loggué, tu vois le dashboard.

## Coûts / limites à connaître

| Service | Free tier | Limite qui pourrait gêner |
|---|---|---|
| Render Web | 750h/mois | Sleep après 15 min sans trafic → cold start de 30-45s |
| Render Postgres | 1 Go, 90 jours | Expire et est supprimé après 90 jours (à recréer) |
| Upstash Redis | 256 Mo, 10k req/jour | Largement suffisant pour notre OTP throttle |

Si tu veux supprimer plus tard, dans le dashboard Render : Settings → Delete Service.

## Sécurité : ce qui est durci en prod

- `ENVIRONMENT=production` → `/docs` désactivé, refuse `DEBUG_OTP=true`
- `JWT_SECRET` généré aléatoirement par Render (jamais en clair dans le code)
- HTTPS partout (Render fournit le certif)
- Mobile : `network_security_config` peut être retiré (plus besoin d'autoriser HTTP en clair)
- Téléphones tiers anonymisés (SHA-256) dans `counterparty` — déjà géré par le backend
