
Standards

No repo coding-standards file exists; findings are smell-baseline and hard issues only.

Hard issues (bugs / security)

 - Security — hardcoded credential (NightscoutService.mc:296)
 var url = getNightscoutUrl() + "/api/v2/notifications/loop?token=garmin-5709111d29db02b8";
 Token is baked into source; bypasses the configured nightscout_token property and leaks a credential.
 - Crash risk (OtpService.mc:20)
 return Application.Properties.getValue("otp_secret"); — no null check. Crashes if the property is unset.
 - Inconsistent center-Y (DiabetesFoodLoopDelegate.mc vs TempOverridesView.mc)
 Two getCenterYPosition() methods return different hardcoded values (300 vs 100), producing inconsistent selection behaviour.

Judgement-call smells

 - Mysterious Name — DEFAULT_OVERRIDE_PROFIL (typo) and desactivePreset() (misspelling + mixed language).
 - Duplicated Code — displayGel, displayFruitJelly, displayMonkey are near-identical rendering methods differing only by bitmap.
 - Duplicated Code + Divergent Change — formatCurrentTimestamp() exists in both NightscoutService and OtpService with conflicting logic (one subtracts 7200 seconds, one doesn't).
 - Feature Envy — DiabetesFoodLoopView navigates deeply into appState.glucoseData.bloodSugarLevel, appState.foodItems, etc., instead of calling higher-level methods.
 - Primitive Obsession / Repeated Switches — stringly-typed event dispatch in onServiceCallback (type.equals("glucose"), type.equals("foods"), …) is brittle.
 - Data Clumps — startY/endY/index layout fields are mixed into the FoodItem domain model and passed around as dictionaries.
 - Dead code — onReceiveAvailableProfiles() and onReceiveActiveProfile() in NightscoutService are never called.

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Spec

The spec source is the README.md (no formal PRD or issue references found).

(a) Missing or partial requirements

 - "Navigation : boutons Page Précédente/Suivante ou touches directionnelles" — AppState.navigateUp()/navigateDown() exist but DiabetesFoodLoopDelegate never overrides page/directional handlers. 
Navigation buttons do nothing.
 - "Sélection visuelle : L'aliment sélectionné est mis en surbrillance" — the highlight fillRectangle is commented out. Not implemented.
 - "Autres appareils Connect IQ compatibles" — selection uses a hardcoded Edge 1050 center-Y (return 300), breaking compatibility with other devices.
 - README dev note: "ajouter la clef dans les properties et pas en dur" — explicitly called out as a TODO, not done.
 - README dev note: "ajouter le sizing dynamic" — fixed startY = 220, no scroll; items beyond maxItems are silently dropped.

(b) Scope creep (not asked for)

 - Per-subcategory food icons (gel, fruit_jelly, monkey fallback) — README only asks for a food list with carb counts.
 - Colour-coded glucose ranges (green/yellow/red) — not mentioned in the spec.
 - Centre-tap heuristic to infer selected food — README only promises button navigation.

(c) Looks implemented, but wrong

 - "Token d'authentification : Accès sécurisé aux API Nightscout" — sendFoodEntry() hardcodes token=garmin-5709111d29db02b8 instead of reading the configured token. Both a spec violation and the security
 bug flagged above.
 - JSON payload — the README documents a JSON body for /api/v2/notifications/loop, but sendFoodEntry() uses REQUEST_CONTENT_TYPE_URL_ENCODED. The request format doesn't match the spec.

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Summary:

 - Standards — 3 hard issues (hardcoded token, OTP null-crash, inconsistent center-Y), 6 smell findings; worst: the hardcoded credential.
 - Spec — 5 missing/partial requirements, 3 scope-creep items, 2 wrong implementations; worst: navigation buttons don't work and the token credential is hardcoded in violation of a README TODO.



 - ajouter des tests unitaires 
 - regarder si dans ressources tout est utile 
 - passer en variable les chiffre en dur dans les view pour plus de compréhension 
- rejeux en cas d'interruption pour envoyer les carbs 

 TODO : 
<iq:product id="edge1040"/>
<iq:product id="edge1050"/>
<iq:product id="edge540"/>
<iq:product id="edge550"/>
<iq:product id="edge840"/>
<iq:product id="edge850"/>