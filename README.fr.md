# SugarPace — Connect IQ App

**Français** · [English](README.md)

> *Ton sucre, ton rythme.*

**SugarPace** est une application Connect IQ pour compteurs Garmin Edge qui réunit glycémie et ravitaillement sur le même écran : suivi de la glycémie en direct (via Nightscout) et envoi de glucides à la boucle fermée en un tap — pour resucrer en roulant, sans sortir le téléphone. Identité visuelle et textes store : [branding/](branding/STORE.md).

---

# 1. Utilisation

## Écran principal

L'écran principal se lit de haut en bas :

- **Glycémie actuelle** en grand, colorée selon la zone (vert = dans la cible, orange = proche des limites, rouge = hors limites), suivie de l'unité et de la **flèche de tendance** (`↑↑`, `↑`, `↗`, `→`, `↘`, `↓`, `↓↓`).
- **Profil Nightscout actif** (pastille + nom) au centre de l'en-tête.
- **Fraîcheur** de la donnée à droite (ex. `2m ago`).
- **Graphe de tendance** en barres sur les dernières heures.
- **Grille d'aliments** (icône + nom) en bas.

## Interactions tactiles

| Zone touchée | Action |
|---|---|
| **Une vignette d'aliment** | Envoie cet aliment (ses glucides) à Loop, avec un code OTP généré à la volée. La vignette affiche le résultat (voir *Retour d'envoi*) et les taps suivants sont ignorés pendant l'envoi, pour limiter les doublons accidentels (pas une garantie absolue : voir « Non confirmé » ci-dessous) |
| **Le graphe** | Change la fenêtre de temps affichée : 4h → 2h → 1h → 30min → 4h. L'échelle verticale s'adapte au min/max de la fenêtre |
| **L'en-tête** (glycémie / profil) | Ouvre l'écran de sélection de **profil temporaire** |

## Retour d'envoi

| Vignette | Signification |
|---|---|
| Orange, « Envoi... » | Requête en cours — les taps sont ignorés |
| Verte | Acceptée par le serveur |
| Rouge + message court | Échec — voir le tableau de *Dépannage* |
| Rouge, « Non confirmé » | Pas de réponse en 30 s : l'entrée a **peut-être** été envoyée — vérifie Loop avant de retaper |

Il n'y a volontairement **aucun retry automatique** à l'envoi : ce qui limite les doublons. Une requête partie sans réponse (« Non confirmé ») a peut-être atteint Loop : vérifie-la avant de retaper.

## Fraîcheur des données

L'âge de la mesure (« 3m ago ») est celui de la mesure du capteur. Il passe **orange** après 10 min, **rouge** après 15 min (le chiffre devient alors gris pour qu'une vieille valeur ne rassure jamais à tort). Un **!** rouge signale que la dernière requête a échoué ; l'app réessaie toutes les 30 s.

## Écran Traitements (profils + bolus)

Ouvert en touchant l'en-tête. En haut : les profils temporaires (voir ci-dessous). En bas : **Bolus** — le montant recommandé par Loop (lu sur Nightscout, avec son âge) et un bouton.

⚠️ Envoyer un bolus délivre de **l'insuline réelle**. Le bouton ne fonctionne que si le réglage est activé, si la recommandation a moins de 10 minutes et vaut entre 0,05 et 5 U, et si elle n'a pas déjà été envoyée. Un premier tap arme (« Confirmer »), un second tap dans les 5 s envoie. Aucun retry automatique. Après un échec ambigu (erreur serveur, pas de lien, « Non confirmé »), la dose a **peut-être** été délivrée : l'écran affiche « Vérifie Loop d'abord », et un nouvel essai n'est proposé qu'une fois une recommandation récupérée au moins 15 s après l'échec (cette retenue survit à un redémarrage, et une requête encore en file après 10 s est annulée : elle ne peut pas être livrée après coup). Vérifie Loop avant de réessayer. **Choix assumé :** si cette revérification renvoie la *même* recommandation, elle peut être renvoyée (c'est à toi de décider ; le risque est de doubler une dose si la première requête est bien arrivée à Loop, d'où l'avertissement et l'attente de 15 s). La garde anti-doublon est enregistrée avant l'envoi et rien n'est envoyé si elle ne peut pas l'être. Une requête réseau récemment abandonnée bloque aussi l'envoi pendant une minute (« Réessaie »). Les limites de Loop (bolus maximum, code à usage unique) restent appliquées.

## Sélection de profil temporaire

L'écran liste les profils/overrides disponibles sur Nightscout. Le profil **actif** est repéré par une barre verte et une coche. Toucher un profil l'active ; toucher **Default** annule l'override temporaire en cours. En cas d'échec, une ligne rouge en bas indique quoi faire (voir *Dépannage*).

## Réglages (Garmin Connect / Connect IQ)

Configurables depuis l'app Garmin Connect (Mobile) ou Connect IQ (Express) :

- **Nightscout URL** — URL de votre instance (ex. `https://mon-nightscout.example.com`)
- **Nightscout Token** — token d'authentification Nightscout
- **Secret OTP** — clé TOTP pour Loop (voir § 2)
- **Default User** — nom associé aux entrées envoyées
- **Afficher la glycémie en mmol/L** — décoché (défaut) = mg/dL. Nightscout envoie toujours des mg/dL ; l'app ne convertit que l'affichage et envoie l'unité choisie à Loop
- **Autoriser l'envoi du bolus recommandé par Loop** — désactivé par défaut. Une fois activé, l'écran *Traitements* peut envoyer le bolus recommandé par Loop après une double confirmation (voir *Écran Traitements*)
- **Colorer les barres selon la zone glycémique** — si activé, chaque barre du graphe prend la couleur de sa zone ; sinon les barres restent grises (défaut)

> Prérequis Loop : votre Loop doit accepter les entrées distantes (Remote Carbs) via l'API Nightscout `notifications/loop`.

---

# 2. Génération du code OTP (secret TOTP)

Le **secret OTP** est indispensable pour que Loop accepte les commandes distantes. Il se récupère **une seule fois** depuis le QR code 2FA de Loop, puis se colle dans les réglages de l'app.

### Étape 1 — Localiser le QR code dans Loop
1. Dans l'app **Loop**, ouvrez les réglages de sécurité / services distants.
2. Affichez le **QR code d'authentification à deux facteurs (2FA)** : il encode le secret OTP.

### Étape 2 — Extraire le secret du QR code
1. Prenez une **capture d'écran** du QR code.
2. Ouvrez l'outil en ligne [2FA QR Code Extractor](https://stefansundin.github.io/2fa-qr/).
3. Chargez la capture d'écran.
4. L'outil renvoie le **secret** (chaîne du type `REDACTED_OTP_SECRET`).

### Étape 3 — Configurer l'app
1. Copiez le secret extrait.
2. Dans Garmin Connect → réglages de l'app → collez-le dans **Secret OTP**.
3. Sauvegardez.

Au moment d'envoyer un aliment, l'app génère un code TOTP à 6 chiffres (renouvelé toutes les 30 s) à partir de ce secret.

⚠️ **Gardez ce secret confidentiel.** L'heure de la montre doit être synchronisée, sinon les codes seront rejetés.

---

# 3. Pour les développeurs

## Compilation

Projet Monkey C standard (Connect IQ SDK). Point d'entrée du build : `monkey.jungle` → `manifest.xml`.

```bash
# Build pour un device (ex. edge1050), signé avec votre clé développeur
monkeyc -f monkey.jungle -d edge1050 -o bin/SugarPace.prg -y developer_key

# Lancer dans le simulateur
connectiq                 # démarre le simulateur
monkeydo bin/SugarPace.prg edge1050
```

> ⚠️ Le type-checker peut atteindre un `OutOfMemoryError` sur de l'arithmétique avec des `Number?` nullables. Garder les accumulateurs numériques non-null (pattern `seen`/drapeau) plutôt que des sentinelles `null`.

## Tests unitaires

Tests annotés `(:test)` dans `source/tests/` (crypto OTP avec vecteurs RFC, zones glycémiques, flèches, parsing FoodItem). Ils sont exclus du build normal.

```bash
# Compiler la cible de test puis l'exécuter dans le simulateur
monkeyc -f monkey.jungle -d edge1050 -o build/test.prg -y developer_key --unit-test
connectiq &
monkeydo build/test.prg edge1050 -t
```

## Intégration continue (GitHub Actions)

Trois workflows dans `.github/workflows/`, basés sur l'action Docker
[`blackshadev/garmin-connectiq-build-action`](https://github.com/blackshadev/garmin-connectiq-build-action) (image qui embarque le SDK + les profils device, donc aucun setup SDK à faire) :
- **`ci.yml`** : pipeline réutilisable — compile les 4 devices (matrice) + compile la cible `--unit-test`.
- **`pr.yml`** (pull request → main) : appelle `ci.yml`. Gate vert/rouge.
- **`main.yml`** (push sur main) : appelle `ci.yml`, puis **crée une release** `v<version>` (notes auto-générées + les `.prg` par device) **quand la version de `manifest.xml` change** (tag inexistant).

**Prérequis** (Settings → Secrets → Actions) — un seul, optionnel :

| Type | Nom | Contenu |
|---|---|---|
| Secret (opt.) | `DEVELOPER_KEY_BASE64` | `base64` de ta `developer_key`. Sinon une clé jetable est générée (OK pour build/tests ; le paquet store se signe avec ta vraie clé). |

```bash
# Générer la valeur du secret depuis ta clé
base64 -i developer_key | pbcopy   # macOS
```

**Cut a release** : bump `version="X.Y.Z"` de `<iq:application>` dans `manifest.xml`, merge sur `main` → release `vX.Y.Z` créée automatiquement.

> ⚠️ Cette action Docker **compile** seulement (pas de simulateur). Les tests unitaires sont donc **compilés** en CI (le code de test cassé fait échouer le build), mais leur **exécution** reste locale : `monkeydo build/test.prg edge1050 -t`. La version de l'action (`@9.1.1`) fixe la version du SDK utilisée.

## Architecture

Séparation vues / état / services :

**App & UI**
- `source/SugarPaceApp.mc` — cycle de vie, initialisation des services, callbacks
- `source/SugarPaceView.mc` — écran principal (en-tête glycémie, graphe, grille d'aliments)
- `source/SugarPaceDelegate.mc` — gestion des taps (aliment / graphe / en-tête)
- `source/TempOverridesView.mc` — écran de sélection de profil + son input delegate
- `source/SugarPaceGlanceView.mc` — vue « glance »

**État (models)**
- `source/models/AppState.mc` — état centralisé (glycémie, historique, aliments, profil, régions tactiles, fenêtre du graphe)
- `source/models/GlucoseData.mc` — donnée glycémie (valeur, tendance, zones de couleur)
- `source/models/FoodItem.mc`, `source/models/FoodDatabase.mc` — aliments

**Services**
- `source/services/NightscoutService.mc` — requêtes Nightscout (glycémie, profils, envoi de glucides). Les requêtes BLE sont volontairement **non concurrentes** (glycémie courante + historique fusionnés en une seule requête ; fetch profil décalé) pour éviter les crashs.
- `source/services/OtpService.mc` — construction des données d'entrée + code OTP

**OTP**
- `source/otp/Otp.mc` — génération TOTP
- `source/otp/Hmac.mc` — HMAC-SHA1
- `source/otp/Sha1.mc` — SHA1
- `source/otp/Convert.mc` — utilitaires (Base32, etc.)

**Ressources**
- `resources/settings/settings.xml` + `resources/properties/properties.xml` — réglages configurables
- `resources/strings/` (+ `strings-fre/`) — libellés (EN / FR)
- `resources/menus/menu.xml` — menus
- `resources/foods/foods.json` — liste des aliments (les données ; `foods.xml` n'est que la déclaration de ressource)
- `resources/drawables/` — icônes des aliments

## API Nightscout

**Envoi de glucides** (avec OTP) :

```
POST /api/v2/notifications/loop?token=<token>
```

```json
{
  "enteredBy": "Default User",
  "eventType": "Remote Carbs Entry",
  "otp": "123456",
  "remoteCarbs": 15,
  "remoteAbsorption": 1,
  "notes": "Nom de l'aliment",
  "units": "mg/dl",
  "created_at": "2025-09-08T12:52:04.000Z"
}
```

**Autres appels** : lecture des entrées glycémie (`/api/v1/entries.json?count=48`), lecture des profils (`/api/v1/profile.json`), overrides (`/api/v1/treatments.json`), activation/annulation d'override (`/api/v2/notifications/loop`).

## Aliments

La liste est définie dans `resources/foods/foods.json`. Pour ajouter/modifier un aliment, éditez ce fichier (et `resources/drawables/` pour l'icône).

| Nom | Marque | Catégorie | Portion | Glucides | IG | Lipides | Protéines | Énergie |
|---|---|---|---|---|---|---|---|---|
| Energy Gel+ Red Fruit | Decathlon | GEL | 35 g | 30 g | 80 | 0 g | 0 g | 502 kJ |
| Energy Gel Red Fruit -3H | Decathlon | GEL | 35 g | 30 g | 85 | 0 g | 0 g | 502 kJ |
| 1:0.8 Gel Cola | Decathlon | GEL | 45 g | 40 g | 70 | 0 g | 0 g | 680 kJ |
| Fruit Jelly | — | JELLIES | 44 g | 35 g | 85 | 0 g | 0 g | 598 kJ |
| Energy Bar Dates & Nuts | — | BAR | 50 g | 31 g | 55 | 5.5 g | 2.3 g | 800 kJ |

⚠️ Les valeurs d'index glycémique (IG) sont estimées lorsqu'elles ne figurent pas sur l'emballage.

## Compatibilité

Testé sur **Garmin Edge 1050**. Devices ciblés (écran tactile uniquement) : Edge 840/850/1040/1050 (voir `manifest.xml`).

## Dépannage

- **Pas de données** : vérifier l'URL et le token Nightscout.
- **OTP invalide** : vérifier le secret OTP et la synchro de l'heure de la montre.

**Messages affichés après un envoi / changement de profil raté :**

| Message | Code | Que faire |
|---|---|---|
| **À configurer** / *Renseigner les réglages Nightscout* | — | URL, token ou secret OTP vide. Les renseigner dans les réglages de l'app (rien n'a été envoyé) |
| **Token invalide** / *Token invalide : voir réglages* | 401, 403 | Le token Nightscout est faux ou sans droit d'écriture. Vérifier **Nightscout Token** dans les réglages et le rôle du sujet dans Nightscout (Admin Tools) |
| **Clés serveur** / *Erreur serveur : ajouter clés Loop (APNs)* | 5xx (souvent 500) | Nightscout répond mais sa config push Loop manque. Définir `ENABLE=… loop` et les variables ci-dessous sur le serveur |
| **Pas de lien** / *Pas de connexion à Nightscout* | négatif | L'Edge n'a pas de lien avec le téléphone (Bluetooth / Garmin Connect Mobile) ou Nightscout est injoignable |
| **Non confirmé** | timeout | Vérifier Loop avant de réessayer |
| **Échec NNN** | autre | Code HTTP brut, voir les logs Nightscout |

**Commandes à distance Loop — variables serveur** (Nightscout `500 … reading 'apnsKey'`) :

| Variable | Où la trouver |
|---|---|
| `LOOP_DEVELOPER_TEAM_ID` | Apple Developer → Account → Membership details (Team ID) |
| `LOOP_APNS_KEY_ID` | Apple Developer → Certificates, Identifiers & Profiles → Keys (Key ID) |
| `LOOP_APNS_KEY` | Contenu du fichier `.p8`, téléchargeable **une seule fois** à la création de la clé (APNs activé) |
| `LOOP_PUSH_SERVER_ENVIRONMENT` | `development` si Loop est compilé avec Xcode, `production` si installé via TestFlight |

Le Team ID doit être celui qui a signé ton Loop. Détails : LoopDocs (« Remote Control »). Exemple sur Fly.io : `fly secrets set -a <app> LOOP_APNS_KEY="$(cat AuthKey_XXXXXXXXXX.p8)" …`.
- **Crash à l'ouverture** : symptôme classique de requêtes BLE concurrentes — garder les fetch réseau non simultanés.

## Sécurité

- Code **TOTP** à usage unique (30 s) généré sur l'appareil.
- Communications **HTTPS** avec Nightscout, accès par token.

---

## Support & contributions

- **GitHub Issues** pour bugs et demandes de fonctionnalités.
- Merci d'indiquer : modèle Garmin, version de l'app, description du problème, logs système si possible.
