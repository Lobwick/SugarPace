# SugarPace

**[English](#english)** · **[Français](#français)**

> *Pace your sugar.*

---

<a id="english"></a>

# English

**SugarPace** is a Connect IQ app for Garmin Edge bike computers. It puts your glucose and your fueling on the same screen: your latest reading from **your own Nightscout site**, and one-tap **carb entries** sent to your closed-loop system, so you can log what you eat without taking your phone out while riding.

> **SugarPace is not a medical device.** It is a display and data-entry tool and must never be your only source of information. Always confirm values and decisions with your approved medical devices. It is not affiliated with Garmin, Nightscout, or any loop app.

## What it does

- Shows your latest glucose reading, color-coded by range, with the trend arrow and the age of the reading.
- Draws a chart of the last 4 h / 2 h / 1 h / 30 min (tap it to switch).
- Sends a carb entry to your loop when you tap a food tile, secured by a one-time code (TOTP).
- Shows the active temporary profile and lets you switch it.
- Adds a glance with your latest reading to the Edge home screen.
- Displays glucose in mg/dL or mmol/L, in English or French.

## What you need

- A **Nightscout** site (its URL and an access token).
- A **loop** connected to that Nightscout that accepts remote carb entries, and its **OTP secret** (see *Getting your OTP secret*).
- A touchscreen **Garmin Edge 840, 850, 1040 or 1050**, paired with your phone through the Garmin Connect app (the Edge uses the phone's connection to reach Nightscout).

## Getting started

1. Install SugarPace on your Edge from the Connect IQ Store using the Garmin Connect app. *(While the app is not published yet, see [DEVELOPERS.md](DEVELOPERS.md) to install a build yourself.)*
2. In the Garmin Connect app, open the SugarPace settings and fill in your Nightscout URL, token and OTP secret (see *Settings*).
3. Open SugarPace on your Edge. Your glucose should appear within a few seconds.

## Using the app

### Main screen

From top to bottom:

- **Current glucose**, large and colored by zone (green = in range, orange = near the limits, red = out of range), then the unit and the **trend arrow** (`↑↑`, `↑`, `↗`, `→`, `↘`, `↓`, `↓↓`).
- The **active profile** (dot + name) in the middle of the header.
- The **age of the reading** on the right (for example `2m ago`).
- A **chart** of recent readings.
- Your **foods** (icon + name) at the bottom. Swipe up and down to scroll when there are more.

### Touch

| Tapped area | What happens |
|---|---|
| **A food tile** | Sends that food's carbs to your loop, with a one-time code generated on the fly. The tile shows the result (see below). |
| **The chart** | Cycles the time window: 4 h → 2 h → 1 h → 30 min → 4 h. |
| **The header** (glucose / profile) | Opens the temporary profile screen. |

### What the tile tells you

| Tile | Meaning |
|---|---|
| Orange, "Sending…" | Request in progress. Further taps are ignored while it runs. |
| Green | Accepted by the server. |
| Red + a short message | Failed. See *Troubleshooting*. |
| Red, "Unconfirmed" | No answer within 30 s. The entry **may** have gone through: check your loop before tapping again. |

There is deliberately **no automatic retry**. Further taps are ignored while sending, to limit accidental duplicates (this is not an absolute guarantee: after "Unconfirmed", always check your loop).

### How fresh is the glucose?

The age shown ("3m ago") is the age of the sensor reading, not of the download. It turns **orange** after 10 minutes and **red** after 15 minutes; the glucose number then turns gray, so an old value never looks reassuring. A red **!** means the last refresh failed; the app retries every 30 seconds.

### Temporary profiles

Tap the header to see the temporary profiles (overrides) defined in your loop. The active one has a green bar and a checkmark. Tap a profile to activate it, or **Default** to cancel the current override. If it fails, a red line at the bottom tells you what to do.

## Settings

Set them in the Garmin Connect (phone) or Connect IQ (Express) app:

| Setting | What to enter |
|---|---|
| **Nightscout URL** | Your site, for example `https://my-nightscout.example.com` |
| **Nightscout Token** | A Nightscout access token that can read data and write treatments |
| **OTP Secret** | The one-time-password secret of your loop (see below) |
| **Default User** | The name attached to the entries you send |
| **Display glucose in mmol/L** | Off (default) = mg/dL. Nightscout always provides mg/dL; this only changes the display and the unit sent to your loop. |
| **Color chart bars by glucose zone** | On = each bar takes its zone color; off = gray bars (default) |

## Getting your OTP secret

Your loop only accepts remote commands with a one-time code. SugarPace computes that code on the Edge from your **OTP secret**, which you retrieve **once** from your loop's 2FA QR code.

1. In your loop app, open the remote-control / security settings and display the **two-factor (2FA) QR code**.
2. Take a screenshot of the QR code.
3. Open the online tool [2FA QR Code Extractor](https://stefansundin.github.io/2fa-qr/) and upload the screenshot. It shows the **secret**, a string of letters and digits such as `JBSWY3DPEHPK3PXP`.
4. Paste that secret into **OTP Secret** in the SugarPace settings and save.

⚠️ **Keep this secret private.** Anyone who has it can generate valid codes. The clock of your Edge must be correct, otherwise codes will be rejected.

## Foods

SugarPace comes with a small catalogue. Open the menu button on the Edge to choose which foods appear on your screen.

| Name | Brand | Category | Serving | Carbs |
|---|---|---|---|---|
| Energy Gel+ | Decathlon | GEL | 35 g | 30 g |
| Energy Gel Red Fruit -3H | Decathlon | GEL | 35 g | 30 g |
| 1:0.8 Gel Cola | Decathlon | GEL | 45 g | 40 g |
| Fruit Jelly | Decathlon | JELLIES | 44 g | 35 g |
| Gel 160 | Maurten | GEL | 65 g | 40 g |
| Energy Bar Dates & Nuts | Decathlon | BAR | 50 g | 31 g |
| ISOTONIC GEL 68G | 226ers | GEL | 68 g | 22 g |

Glycemic index values in the catalogue are estimates when they are not printed on the packaging. To suggest a new food, open a GitHub issue with the **"Ajouter un aliment"** (add a food) template: a pull request is created for you.

## Troubleshooting

| What you see | What to do |
|---|---|
| **No glucose** | Check the Nightscout URL and token in the settings, and that your Edge is paired with your phone. |
| **Set up app** | The URL, token or OTP secret is empty. Fill them in (nothing was sent). |
| **Bad token** | The Nightscout token is wrong or cannot write. Check it in the settings and in Nightscout (Admin Tools → Subjects). |
| **Server keys** | Nightscout answers but its Loop push configuration is missing (see below). |
| **No link** | The Edge has no connection through your phone (Bluetooth / Garmin Connect), or Nightscout is unreachable. |
| **Unconfirmed** | No answer in time: check your loop before trying again. |
| **Failed NNN** | Another HTTP error: look at your Nightscout logs. |
| **Invalid OTP** (in Loop) | Check the OTP secret and that the Edge clock is correct. |

**If you host Nightscout yourself**, remote commands need these variables on your server (a missing key shows as a `500 … 'apnsKey'` error):

| Variable | Where to find it |
|---|---|
| `ENABLE` | Must include `loop` |
| `LOOP_DEVELOPER_TEAM_ID` | Apple Developer → Account → Membership details (Team ID) |
| `LOOP_APNS_KEY_ID` | Apple Developer → Certificates, Identifiers & Profiles → Keys (Key ID) |
| `LOOP_APNS_KEY` | Contents of the `.p8` file, downloadable **only once** when the key is created (APNs enabled) |
| `LOOP_PUSH_SERVER_ENVIRONMENT` | `development` if your loop was built with Xcode, `production` if installed from TestFlight |

The Team ID must be the one that signed your loop. See LoopDocs ("Remote Control") for details.

## Privacy and security

- SugarPace has **no server** and collects nothing: it only talks to the Nightscout address you configure, over HTTPS. See [PRIVACY.md](PRIVACY.md).
- Each entry is protected by a one-time code that changes every 30 seconds.
- Your token and OTP secret are stored in your Garmin Connect settings: keep them private.

## Support

Open a **GitHub issue** for bugs and feature requests. Please include your Garmin model, the app version and a description of the problem.

**Developers:** build, tests, architecture and contribution notes are in [DEVELOPERS.md](DEVELOPERS.md).

---

<a id="français"></a>

# Français

**SugarPace** est une application Connect IQ pour les compteurs vélo Garmin Edge. Elle met ta glycémie et ton ravitaillement sur le même écran : ta dernière mesure depuis **ton propre site Nightscout**, et des **entrées de glucides** envoyées en un tap à ta boucle fermée, pour enregistrer ce que tu manges sans sortir ton téléphone en roulant.

> **SugarPace n'est pas un dispositif médical.** C'est un outil d'affichage et de saisie, qui ne doit jamais être ta seule source d'information. Vérifie toujours les valeurs et les décisions avec tes dispositifs médicaux approuvés. Il n'a aucun lien ni affiliation avec Garmin, Nightscout ou une application de boucle.

## Ce que fait l'application

- Affiche ta dernière glycémie, colorée selon la zone, avec la flèche de tendance et l'âge de la mesure.
- Trace un graphique des 4 h / 2 h / 1 h / 30 min (touche-le pour changer).
- Envoie une entrée de glucides à ta boucle quand tu touches une vignette d'aliment, sécurisée par un code à usage unique (TOTP).
- Montre le profil temporaire actif et permet d'en changer.
- Ajoute un glance avec ta dernière mesure sur l'écran d'accueil de l'Edge.
- Affiche la glycémie en mg/dL ou en mmol/L, en français ou en anglais.

## Ce qu'il te faut

- Un site **Nightscout** (son URL et un token d'accès).
- Une **boucle** reliée à ce Nightscout qui accepte les entrées de glucides à distance, et son **secret OTP** (voir *Récupérer ton secret OTP*).
- Un **Garmin Edge 840, 850, 1040 ou 1050** tactile, associé à ton téléphone via l'application Garmin Connect (l'Edge utilise la connexion du téléphone pour joindre Nightscout).

## Pour commencer

1. Installe SugarPace sur ton Edge depuis le Connect IQ Store, avec l'application Garmin Connect. *(Tant que l'application n'est pas publiée, voir [DEVELOPERS.md](DEVELOPERS.md) pour installer une version toi-même.)*
2. Dans Garmin Connect, ouvre les réglages de SugarPace et renseigne l'URL Nightscout, le token et le secret OTP (voir *Réglages*).
3. Ouvre SugarPace sur ton Edge. Ta glycémie doit apparaître en quelques secondes.

## Utiliser l'application

### Écran principal

De haut en bas :

- **La glycémie**, en grand et colorée selon la zone (vert = dans la cible, orange = proche des limites, rouge = hors cible), puis l'unité et la **flèche de tendance** (`↑↑`, `↑`, `↗`, `→`, `↘`, `↓`, `↓↓`).
- Le **profil actif** (point + nom) au milieu de l'en-tête.
- **L'âge de la mesure** à droite (par exemple `2m ago`).
- Un **graphique** des dernières mesures.
- Tes **aliments** (icône + nom) en bas. Fais glisser vers le haut ou le bas pour défiler s'il y en a davantage.

### Tactile

| Zone touchée | Ce qui se passe |
|---|---|
| **Une vignette d'aliment** | Envoie les glucides de cet aliment à ta boucle, avec un code à usage unique généré à la volée. La vignette affiche le résultat (voir ci-dessous). |
| **Le graphique** | Change la fenêtre de temps : 4 h → 2 h → 1 h → 30 min → 4 h. |
| **L'en-tête** (glycémie / profil) | Ouvre l'écran des profils temporaires. |

### Ce que dit la vignette

| Vignette | Signification |
|---|---|
| Orange, « Envoi... » | Requête en cours. Les taps suivants sont ignorés pendant ce temps. |
| Verte | Acceptée par le serveur. |
| Rouge + un court message | Échec. Voir *Dépannage*. |
| Rouge, « Non confirmé » | Pas de réponse en 30 s. L'entrée a **peut-être** été envoyée : vérifie ta boucle avant de retaper. |

Il n'y a volontairement **aucun retry automatique**. Les taps suivants sont ignorés pendant l'envoi, pour limiter les doublons accidentels (ce n'est pas une garantie absolue : après « Non confirmé », vérifie toujours ta boucle).

### La glycémie est-elle récente ?

L'âge affiché (« 3m ago ») est celui de la mesure du capteur, pas du téléchargement. Il passe **orange** après 10 minutes et **rouge** après 15 minutes ; le chiffre devient alors gris, pour qu'une vieille valeur ne rassure jamais à tort. Un **!** rouge signale que le dernier rafraîchissement a échoué ; l'application réessaie toutes les 30 secondes.

### Profils temporaires

Touche l'en-tête pour voir les profils temporaires (overrides) définis dans ta boucle. Le profil actif a une barre verte et une coche. Touche un profil pour l'activer, ou **Default** pour annuler l'override en cours. En cas d'échec, une ligne rouge en bas indique quoi faire.

## Réglages

À renseigner dans l'application Garmin Connect (téléphone) ou Connect IQ (Express) :

| Réglage | Quoi saisir |
|---|---|
| **Nightscout URL** | Ton site, par exemple `https://mon-nightscout.exemple.com` |
| **Nightscout Token** | Un token d'accès Nightscout qui peut lire les données et écrire des traitements |
| **OTP Secret** | Le secret de mot de passe à usage unique de ta boucle (voir ci-dessous) |
| **Default User** | Le nom associé aux entrées que tu envoies |
| **Afficher la glycémie en mmol/L** | Décoché (défaut) = mg/dL. Nightscout fournit toujours des mg/dL ; cela ne change que l'affichage et l'unité envoyée à ta boucle. |
| **Colorer les barres selon la zone glycémique** | Coché = chaque barre prend la couleur de sa zone ; décoché = barres grises (défaut) |

## Récupérer ton secret OTP

Ta boucle n'accepte les commandes à distance qu'avec un code à usage unique. SugarPace calcule ce code sur l'Edge à partir de ton **secret OTP**, que tu récupères **une seule fois** dans le QR code 2FA de ta boucle.

1. Dans ton application de boucle, ouvre les réglages de contrôle à distance / sécurité et affiche le **QR code d'authentification à deux facteurs (2FA)**.
2. Fais une capture d'écran du QR code.
3. Ouvre l'outil en ligne [2FA QR Code Extractor](https://stefansundin.github.io/2fa-qr/) et charge la capture. Il affiche le **secret**, une chaîne de lettres et de chiffres comme `JBSWY3DPEHPK3PXP`.
4. Colle ce secret dans **OTP Secret** dans les réglages de SugarPace et enregistre.

⚠️ **Garde ce secret confidentiel.** Toute personne qui l'a peut générer des codes valides. L'heure de ton Edge doit être correcte, sinon les codes seront rejetés.

## Aliments

SugarPace est livré avec un petit catalogue. Ouvre le bouton de menu de l'Edge pour choisir les aliments affichés à l'écran.

| Nom | Marque | Catégorie | Portion | Glucides |
|---|---|---|---|---|
| Energy Gel+ | Decathlon | GEL | 35 g | 30 g |
| Energy Gel Red Fruit -3H | Decathlon | GEL | 35 g | 30 g |
| 1:0.8 Gel Cola | Decathlon | GEL | 45 g | 40 g |
| Fruit Jelly | Decathlon | JELLIES | 44 g | 35 g |
| Gel 160 | Maurten | GEL | 65 g | 40 g |
| Energy Bar Dates & Nuts | Decathlon | BAR | 50 g | 31 g |
| ISOTONIC GEL 68G | 226ers | GEL | 68 g | 22 g |

Les valeurs d'index glycémique du catalogue sont estimées quand elles ne figurent pas sur l'emballage. Pour proposer un nouvel aliment, ouvre une issue GitHub avec le modèle **« Ajouter un aliment »** : une pull request est créée pour toi.

## Dépannage

| Ce que tu vois | Que faire |
|---|---|
| **Pas de glycémie** | Vérifie l'URL et le token Nightscout dans les réglages, et que ton Edge est associé à ton téléphone. |
| **À configurer** | L'URL, le token ou le secret OTP est vide. Renseigne-les (rien n'a été envoyé). |
| **Token invalide** | Le token Nightscout est faux ou ne peut pas écrire. Vérifie-le dans les réglages et dans Nightscout (Admin Tools → Subjects). |
| **Clés serveur** | Nightscout répond mais sa configuration push Loop manque (voir ci-dessous). |
| **Pas de lien** | L'Edge n'a pas de connexion via ton téléphone (Bluetooth / Garmin Connect), ou Nightscout est injoignable. |
| **Non confirmé** | Pas de réponse à temps : vérifie ta boucle avant de réessayer. |
| **Échec NNN** | Autre erreur HTTP : regarde les logs de ton Nightscout. |
| **OTP invalide** (dans Loop) | Vérifie le secret OTP et que l'heure de l'Edge est correcte. |

**Si tu héberges Nightscout toi-même**, les commandes à distance demandent ces variables sur ton serveur (une clé manquante se voit par une erreur `500 … 'apnsKey'`) :

| Variable | Où la trouver |
|---|---|
| `ENABLE` | Doit contenir `loop` |
| `LOOP_DEVELOPER_TEAM_ID` | Apple Developer → Account → Membership details (Team ID) |
| `LOOP_APNS_KEY_ID` | Apple Developer → Certificates, Identifiers & Profiles → Keys (Key ID) |
| `LOOP_APNS_KEY` | Contenu du fichier `.p8`, téléchargeable **une seule fois** à la création de la clé (APNs activé) |
| `LOOP_PUSH_SERVER_ENVIRONMENT` | `development` si ta boucle est compilée avec Xcode, `production` si installée via TestFlight |

Le Team ID doit être celui qui a signé ta boucle. Voir LoopDocs (« Remote Control ») pour les détails.

## Confidentialité et sécurité

- SugarPace n'a **aucun serveur** et ne collecte rien : il ne communique qu'avec l'adresse Nightscout que tu configures, en HTTPS. Voir [PRIVACY.md](PRIVACY.md).
- Chaque entrée est protégée par un code à usage unique qui change toutes les 30 secondes.
- Ton token et ton secret OTP sont conservés dans tes réglages Garmin Connect : garde-les confidentiels.

## Support

Ouvre une **issue GitHub** pour les bugs et les demandes de fonctionnalités. Merci d'indiquer ton modèle Garmin, la version de l'application et la description du problème.

**Développeurs :** compilation, tests, architecture et contribution sont dans [DEVELOPERS.md](DEVELOPERS.md) (en anglais).
