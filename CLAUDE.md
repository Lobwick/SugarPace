# CLAUDE.md — SugarPace

Contexte projet pour Claude Code. Lire avant toute modification.

## C'est quoi

**SugarPace** (anciennement "Diabetes Food Management") — app Connect IQ pour
Garmin Edge. Affiche la glycémie en direct (via Nightscout) et permet d'envoyer
des glucides à une boucle fermée (Loop) en un tap, pendant l'effort, sans
sortir le téléphone. Utilisateur cible : cycliste d'endurance diabétique de
type 1 sous boucle fermée.

Repo : `git@github.com:Lobwick/SugarPace.git`
Branding / textes store : voir [branding/STORE.md](branding/STORE.md).
Docs utilisateur : [README.md](README.md) (FR) / [README.en.md](README.en.md) (EN).

## ⚠️ Règle de sécurité absolue

**Ne JAMAIS exécuter, dans un test ou un script de vérification, une des
fonctions suivantes de `NightscoutService`** : `fetchGlucoseData`,
`fetchTempBasalData`, `sendFoodEntry`, `activatePreset`, `deactivatePreset`.

Ce sont de vraies requêtes réseau vers l'instance Nightscout personnelle de
l'utilisateur, connectée à sa boucle fermée réelle. Les déclencher enverrait
de vrais glucides / changerait de vrais profils sur son système médical.

Les tests de `NightscoutServiceTest.mc` n'appellent **que** les handlers de
parsing (`onReceiveGlucoseData`, `onReceiveTempBasalData`,
`onReceiveActiveOverride`) avec des données factices — ils ne font aucune
requête. Respecter ce principe pour toute nouvelle couverture de test.

## Architecture

```
Garmin Connect settings (Properties)
         │  URL / token / otp_secret / unit / color-pref
         ▼
┌─────────────────────────────────────────────┐
│  SugarPaceApp (orchestrateur, cycle de vie)  │
│   getInitialView → initializeServices        │
│   onServiceCallback(type,data) ──► AppState  │
└───────┬───────────────────────────┬──────────┘
        │ owns                      │ owns
        ▼                           ▼
┌──────────────────┐      ┌─────────────────────┐
│ NightscoutService │─────►│ OtpService (TOTP)   │
│ (file de requêtes │      │ Otp→Hmac→Sha1→Convert│
│  sérialisée)      │      └─────────────────────┘
└─────────┬─────────┘
          │ mutates
          ▼
┌───────────────────────────────────────────┐
│ AppState (glucose, history, foods, profil, │
│  régions tactiles, fenêtre chart, scroll)  │◄── vues lisent
└───────────────────────────────────────────┘
          ▲ requestUpdate()
┌─────────┴──────────┬──────────────────────┐
│ SugarPaceView       │ TempOverridesView    │  SugarPaceGlanceView
│ SugarPaceDelegate    │ TempOverridesInput.. │
└────────────────────┴──────────────────────┘
```

### Fichiers principaux
- `source/SugarPaceApp.mc` — orchestrateur, cycle de vie, `getGlanceTheme`/`onNightModeChanged`
- `source/SugarPaceView.mc` — écran principal (header glycémie, courbe, grille aliments)
- `source/SugarPaceDelegate.mc` — gestion des taps (aliment / courbe / header / swipe scroll)
- `source/SugarPaceMenuDelegate.mc` — menu physique
- `source/SugarPaceGlanceView.mc` — vue glance (carrousel home Edge)
- `source/TempOverridesView.mc` — sélection de profil temporaire + son input delegate
- `source/Layout.mc` — **toutes** les constantes de layout nommées (pas de nombres magiques dans les vues)
- `source/Constants.mc` — seuils zones glycémiques, `DEFAULT_OVERRIDE_PROFIL`, `TIME_STEP_SEC`
- `source/models/` — `AppState`, `GlucoseData`, `FoodItem`, `FoodDatabase`
- `source/services/` — `NightscoutService` (réseau), `OtpService` (payload + TOTP)
- `source/otp/` — implémentation TOTP/HOTP RFC 6238 (Otp, Hmac, Sha1, Convert)
- `source/tests/` — 24 tests `(:test)`, voir section Tests

## Build & test (commandes vérifiées cette session)

```bash
SDK=~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2

# Build normal
java -Xms1g -jar "$SDK/bin/monkeybrains.jar" -o out.prg -f monkey.jungle \
  -y /Users/lobwick/workspaces/developer_key -d edge1050 -w

# Build + run les tests unitaires
java -Xms1g -jar "$SDK/bin/monkeybrains.jar" -o test.prg -f monkey.jungle \
  -y /Users/lobwick/workspaces/developer_key -d edge1050 --unit-test -w
"$SDK/bin/connectiq" &          # démarre le simulateur GUI (laisser tourner ~10-12s)
"$SDK/bin/monkeydo" test.prg edge1050 -t   # exécute les tests, résultat dans la console du sim
```

⚠️ `developer_key` doit être le **chemin absolu** (`/Users/lobwick/workspaces/developer_key`) — un chemin relatif a déjà causé un échec silencieux dans cette session.

Devices ciblés actuellement (manifest.xml) : **edge840, edge850, edge1040, edge1050**.
edge540/edge550 retirés (non-tactiles, app 100% tactile — voir Backlog).

## Pièges connus (perdre du temps une seule fois)

### 1. OOM du type-checker Monkey C sur arithmétique nullable
Le compilateur `monkeybrains` peut `OutOfMemoryError` (explosion dans
`FunctionTypeChecker.combineSubstitutions`) sur de l'arithmétique avec des
`Number?` nullables (`var x = null; ... x - y`). **Pas** un vrai manque de
mémoire (repro avec 6 Go dispo). Fix : accumulateurs `Number` non-null avec un
drapeau `seen` au lieu de sentinelles `null`. Préférer aussi des chaînes
`if` en sortie anticipée à un long `&&` avec narrowing `instanceof` sur `Object?`.

### 2. `Rez.Drawables[stringVar]` ne fonctionne PAS
L'accès dynamique à une ressource par variable de chaîne échoue **silencieusement**
en Monkey C (catché par un `try/catch` vide, aucune erreur visible). `Rez.Drawables`
est un namespace de constantes compilées, pas un dictionnaire runtime.

**Solution retenue** : `DrawableRegistry.mc` centralise le mapping
`picture_id → Rez.Drawables.symbole` dans un seul Dictionary initialisé en lazy.
`SugarPaceView.brandDrawableId()` délègue à `DrawableRegistry.get(picture)` —
la vue n'est plus jamais modifiée lors de l'ajout d'un aliment.

### 3. Requêtes réseau concurrentes = crash
Le pont BLE du device crashe l'app sous requêtes `Communications.makeWebRequest`
concurrentes. `NightscoutService` implémente une **file sérialisée**
(`enqueue`/`dispatchNext`/`onRequestComplete`) — une seule requête en vol à la
fois. Ne jamais appeler `makeWebRequest` directement ; toujours passer par
`enqueue(...)`.

### 4. Simulateur Edge 850/550 : le texte ne rend pas
Bug confirmé du simulateur SDK 9.2.0 sur les profils Edge 850/550 (résolution
420×600) : `drawText` ne dessine rien, alors que `getFontHeight`/formes/images
fonctionnent normalement. Testé et confirmé avec un `drawText("coucou")`
isolé, plein centre, sans clip — invisible sur 850, visible sur 840 et 1050.
**Ce n'est pas un bug de code** — ne pas chercher à "corriger" un rendu texte
manquant sur ces deux profils dans le sim. Valider sur 840/1050, ou sur
device réel si dispo.

### 5. Glance : fond du carrousel ≠ fond de l'app
Le glance (carrousel home Edge) suit le thème jour/nuit du système, PAS le
fond noir du reste de l'app. Texte blanc en dur = invisible en mode jour
(fond clair). Solution retenue : ne déclarer aucun `getGlanceTheme()` (garder
le fond natif Garmin), et adapter la couleur du texte via
`System.getDeviceSettings().isNightModeEnabled` (+ `onNightModeChanged()`
dans `SugarPaceApp` pour redraw immédiat au changement de mode).
Toute chaîne utilisée dans le glance (scope réduit) doit être déclarée avec
`scope="glance"` dans strings.xml, sinon `WatchUi.loadResource(Rez.Strings.x)`
crashe avec `Illegal Access (Out of Bounds) : Could not access symbol 'Rez'`.

### 6. Edge 540/550 sont non-tactiles
`isTouch: false` dans leur `simulator.json`. L'app est actuellement 100%
tactile (`onTap`, `onSwipe`) — inutilisable au bouton sauf le scroll (`onKey`
gère déjà UP/DOWN). Retirés du manifest en attendant une navigation au bouton
complète (focus + Enter). Voir Backlog.

### 7. Widgets Garmin ≠ glances Connect IQ
Deux surfaces distinctes sur Edge 1040/1050 : la **liste de glances** (accueil,
swipe horizontal) reçoit les apps Connect IQ automatiquement à l'installation ;
le **tiroir de widgets** (swipe vertical, "Ajouter des widgets") ne liste QUE
des widgets Garmin natifs (Wallet, Météo, etc.) — aucune API Connect IQ pour
s'y enregistrer. Ne pas chercher à y faire apparaître l'app, c'est impossible
par design Garmin.

### 8. Images produit : fond, taille, dithering
- Taille = pixels exacts rendus à l'écran (`drawBitmap` ne redimensionne pas).
  84×84 pour les tuiles de la grille actuelle.
- **Fond transparent** : les PNG doivent avoir un fond transparent pour s'adapter
  au mode jour/nuit du device. `drawBitmap` composite l'image sur la couleur de
  fond de la cellule (`appState.backgroundColor`), qui suit le thème.
- `drawScaledBitmap` n'existe pas sur ces devices — impossible d'agrandir une
  image par code, il faut fournir un asset à la bonne taille.

## Ajouter un aliment au catalogue

Exactement 4 fichiers à toucher, dans cet ordre :

1. **`resources/foods/foods.json`** — ajouter l'entrée JSON avec `id`, `name`, `brand`, `subcategory`, `picture`, valeurs nutritionnelles.
2. **`resources/drawables/brands/<picture>.png`** — PNG 84×84, fond **transparent** (le compositing Monkey C gère le mode jour/nuit).
3. **`resources/drawables/drawables.xml`** — ajouter `<bitmap id="<picture>" filename="brands/<picture>.png" />`.
4. **`source/DrawableRegistry.mc`** — ajouter `"<picture>" => Rez.Drawables.<picture>,` dans le Dictionary.

`SugarPaceView.mc` ne doit **jamais** être modifié pour un ajout d'aliment.

## Conventions établies cette session

- **Toutes les valeurs de layout** (marges, gaps, hauteurs, %, intervalles)
  vont dans `Layout.mc`, jamais en dur dans les vues. Étendre ce fichier
  plutôt que réintroduire des magic numbers.
- **Layout responsive** : `SugarPaceView.onUpdate` calcule tout par rapport à
  `dc.getWidth()/getHeight()`. Deux modes de scroll selon
  `Layout.COMPACT_HEIGHT_THRESHOLD` (400px) : écrans hauts (1040/1050/850) =
  header+courbe figés, grille scrolle seule dans un viewport `setClip` ;
  écrans courts (840) = toute la page scrolle (courbe comprise) pour laisser
  la grille prendre l'écran entier.
- **Hit-testing** suit le même système partout : régions `{x0,y0,x1,y1}`
  stockées dans `AppState` (`headerRegion`, `chartRegion`,
  `foodGridCoordinates`, `presetCoordinatesProfile`), testées via
  `AppState.isPointInRegion(...)`.
- **Zones glycémiques** centralisées dans `GlucoseData.getZoneColor()` +
  seuils dans `Constants.mc` (`GLUCOSE_TARGET_LOW/HIGH`,
  `GLUCOSE_NEAR_LOW/HIGH`). Toute nouvelle UI qui colore par zone doit
  réutiliser cette fonction, pas dupliquer les seuils.
- **Préférences utilisateur** lues via `Application.Properties.getValue(...)`
  avec garde de type (`instanceof`) avant usage — jamais de cast direct qui
  peut planter si la préférence n'est pas encore synchronisée.
- **Timestamps** toujours en UTC réel via `Time.Gregorian.utcInfo(...)`,
  jamais d'offset horaire codé en dur (bug corrigé cette session dans
  `OtpService.formatCurrentTimestamp`).

## Tests (24 au total, tous exécutés et vérifiés PASS dans le sim)

| Fichier | Couvre |
|---|---|
| `OtpTest.mc` | base32 (RFC 4648), SHA-1, HMAC-SHA1 (RFC 2202), HOTP (RFC 4226) |
| `GlucoseDataTest.mc` | zones (bornes exactes), 7 flèches de tendance, `getTimeSinceUpdate` (cas null) |
| `FoodItemTest.mc` | parsing JSON→FoodItem, défauts, `toDictionary` |
| `AppStateTest.mc` | hit-testing, cycle fenêtre courbe, clamp scroll, recherche aliment par tap |
| `FoodDatabaseTest.mc` | chargement `foods.json` embarqué |
| `OtpServiceTest.mc` | timestamp UTC, payload carb-entry Loop |
| `NightscoutServiceTest.mc` | **parsing seulement** (voir règle de sécurité ci-dessus) |

Pas de couverture pour : rendu (`SugarPaceView`, math du chart, layout
responsive) — nécessite un `Dc`, vérification visuelle au sim uniquement.

## CI/CD

`.github/workflows/` : `ci.yml` (réutilisable, matrice 4 devices + compile
`--unit-test`), `pr.yml` (appelle ci.yml), `main.yml` (ci.yml + release
auto sur bump de version dans `manifest.xml`). Basé sur l'action Docker
`blackshadev/garmin-connectiq-build-action@9.1.1` (image avec SDK + devices
embarqués, pas de setup manuel). Cette action **compile uniquement** — les
tests sont compilés en CI mais pas exécutés (exécution reste locale).

Secret optionnel : `DEVELOPER_KEY_BASE64` (sinon clé jetable générée, valide
pour build/test mais pas pour signer un vrai paquet store).

## Historique du renommage (pour référence)

Projet initialement nommé "Diabetes Food Management" / classes
`DiabetesFoodLoop*`. Renommé en **SugarPace** cette session :
- Fichiers `source/DiabetesFoodLoop{App,View,Delegate,MenuDelegate,GlanceView}.mc`
  → `source/SugarPace{App,View,Delegate,MenuDelegate,GlanceView}.mc` (via `git mv`)
- Classes et références croisées renommées en conséquence
- `manifest.xml` : `entry="SugarPaceApp"`
- `resources/properties/properties.xml` : `default_user` = `"SugarPace"`
- `BRUNO/DiabetesFoodManagement/` → `BRUNO/SugarPace/`
- `bin/` désindexé de git (était gitignoré mais suivi par erreur depuis avant)
- `code_review.md` **non modifié** — c'est une note de revue historique qui
  référence les anciens noms de classe dans son contexte d'origine ; à
  archiver ou mettre à jour si besoin, décision jamais tranchée.
- Remote git : `git@github.com:Lobwick/SugarPace.git`

Nom de l'app choisi après une liste de 10 propositions (GlucoRide,
RangeRider, SweetSpot, FuelRange, GlycoPilot, SugarPace, T1Ride, BGRide,
GlucoFuel, SugarLine) — **SugarPace** retenu par l'utilisateur. Logo régénéré
en conséquence : goutte de glucose blanche + deux chevrons d'allure
(vert/orange) sur fond sombre — `branding/logo.svg`, décliné en icône
launcher 68×68 dans `resources/drawables/logo.png`.

## Backlog / idées non implémentées

- **Navigation au bouton** pour réintégrer edge540/edge550 : focus aliment
  déplaçable aux flèches (↑↓ + gauche/droite pour les 2 colonnes), Enter pour
  envoyer ; boutons/menu dédiés pour cycler la fenêtre courbe et ouvrir le
  profil. Le scroll au bouton existe déjà (`onKey` dans `SugarPaceDelegate`).
- **Champ de données (datafield)** au lieu de / en plus du widget : surface
  Connect IQ visible pendant l'activité elle-même (à côté puissance/vitesse),
  probablement plus utile en usage réel que le glance home. Nécessiterait un
  type d'app séparé dans le manifest, réutilisant `NightscoutService`/`GlucoseData`.
- **Rotation du secret OTP et du token Nightscout** commités en clair dans
  `resources/properties/properties.xml` — géré ainsi volontairement pour
  faciliter les tests locaux, mais **à faire tourner avant toute publication
  publique du repo** (ou avant de rendre le repo public tout court).
- **Tests d'exécution en CI** : actuellement seule la compilation des tests
  est vérifiée en CI (l'action Docker ne lance pas le simulateur). Ajouter un
  job séparé avec sim headless (xvfb) si l'exécution réelle en CI devient
  nécessaire.
- Fichiers PNG orphelins nettoyés cette session
  (`fruit_jelly.png`, `gel.png`, `monkey.png`, `layout.xml` inutilisé,
  strings `active_profile_label`/`menu_return_instruction` mortes) — refaire
  cet audit périodiquement si de nouvelles ressources s'accumulent.
