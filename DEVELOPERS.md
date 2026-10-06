# SugarPace — developer guide

Technical notes for people who build, test or contribute to SugarPace. User documentation is in [README.md](README.md) (English and French); this file is English only.

SugarPace is a Connect IQ **widget** (with a glance view) for Garmin Edge bike computers. It reads glucose from a Nightscout site and sends remote carb entries and override changes to a closed-loop system through Nightscout.

## ⚠️ Safety rule: never hit the real services from a test

`NightscoutService` talks to a **real** Nightscout instance connected to a **real** closed loop. Never call these functions from a test or a verification script, directly or indirectly:

`fetchGlucoseData`, `fetchTempBasalData`, `sendFoodEntry`, `activatePreset`, `deactivatePreset`.

They would send real carbs or change real profiles on a medical system. The tests in `source/tests/NightscoutServiceTest.mc` only call the **parsing** handlers (`onReceiveGlucoseData`, `onReceiveTempBasalData`, `onReceiveActiveOverride`) with canned data and make no request. Keep that principle for any new test.

The same caution applies to the simulator: it runs the real app, so tapping a food or a profile there sends a real request to whatever Nightscout is configured.

## Requirements

- The [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (the project is built with SDK 9.x) and a **developer key** (`developer_key`) outside the repository. Always sign with the **same key** for every release.
- Java (for `monkeybrains.jar`), and VS Code with the Monkey C extension if you prefer an IDE.
- Optional: `uv`, Chrome and `ffmpeg` only if you generate the presentation video (see the `video/` folder, when present).

Targeted devices (see `manifest.xml`): **edge840, edge850, edge1040, edge1050**. The app is 100% touch-driven, so the non-touch Edge 540/550 are not supported.

## Build and run

```bash
SDK=~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-<version>
KEY=/absolute/path/to/developer_key        # must be an ABSOLUTE path

# Normal build for one device
java -Xms1g -jar "$SDK/bin/monkeybrains.jar" -o out.prg -f monkey.jungle -y "$KEY" -d edge1050 -w

# Release package for the store: one .iq with every device of the manifest
java -Xms1g -jar "$SDK/bin/monkeybrains.jar" -e -r -o bin/SugarPace.iq -f monkey.jungle -y "$KEY" -w
```

In VS Code: **Monkey C: Build Current Project**, **Run**, and **Monkey C: Export Project** for the `.iq`.

To sideload a build on a real Edge, copy the `.prg` produced for your device into its `GARMIN/Apps` folder over USB.

### Simulator

Start the simulator **from VS Code (F5)**. Starting `connectiq` / `monkeydo` by hand next to it leaves several `.SET` state files keyed by the same app id, and the *App Settings Editor* then shows "No settings file found". If that happens: reboot, or use *Edit Persistent Storage → Application.Properties data* to change settings.

The default values in `properties.xml` for the Nightscout URL, token and OTP secret are **empty**. For local testing, enter them in the simulator (Application.Properties data), never in the file.

Known simulator quirk: on the Edge 850 profile (and 550) `drawText` draws nothing (SDK 9.2.0 simulator bug, not an app bug). Validate on the 840/1050 or on a real device.

## Unit tests

Tests are `(:test)` functions in `source/tests/`, excluded from normal builds.

```bash
java -Xms1g -jar "$SDK/bin/monkeybrains.jar" -o test.prg -f monkey.jungle -y "$KEY" -d edge1050 --unit-test -w
"$SDK/bin/connectiq" &                      # start the simulator, wait ~10 s
"$SDK/bin/monkeydo" test.prg edge1050 -t    # run the tests, results in the simulator console
```

| File | Covers |
|---|---|
| `OtpTest.mc` | base32 (RFC 4648), SHA-1, HMAC-SHA1 (RFC 2202), HOTP (RFC 4226) |
| `OtpServiceTest.mc` | UTC timestamp, Loop carb-entry payload |
| `GlucoseDataTest.mc` | zone bounds, the 7 trend arrows, age of reading |
| `FoodItemTest.mc`, `FoodDatabaseTest.mc` | JSON → `FoodItem`, bundled `foods.json` |
| `AppStateTest.mc` | hit-testing, chart-window cycle, scroll clamp, food lookup by tap |
| `ReliabilityTest.mc` | mg/dL → mmol/L, data age, fetch scheduling, send lock, error classification |
| `NightscoutServiceTest.mc` | **response parsing only** (see the safety rule) |

Not covered: rendering (`SugarPaceView`, chart maths, responsive layout), which needs a `Dc`: check it visually in the simulator.

## CI/CD

Workflows in `.github/workflows/`, based on the Docker action [`blackshadev/garmin-connectiq-build-action`](https://github.com/blackshadev/garmin-connectiq-build-action) (its image bundles the SDK and the device profiles, so there is no SDK setup). The action tag in `ci.yml` pins the SDK version.

- `ci.yml` — reusable pipeline: builds the 4 devices (matrix) and compiles the `--unit-test` target.
- `pr.yml` — runs `ci.yml` on pull requests to `main` (green/red gate).
- `main.yml` — runs `ci.yml` on `main`, then **creates a release** `v<version>` (auto notes + one `.prg` per device) when the `version` in `manifest.xml` changes.
- `add_food.yml` — opens a pull request from an "add a food" issue (see *Adding a food*).

The action only **compiles**: unit tests are compiled in CI (broken test code fails the build) but executed locally.

Optional secret `DEVELOPER_KEY_BASE64` (`base64 -i developer_key`): without it a throwaway key is generated, fine for build/test but not for signing a store package.

**To cut a release:** bump `version="X.Y.Z"` of `<iq:application>` in `manifest.xml` and merge to `main`.

## Architecture

```
Garmin Connect settings (Properties): URL / token / OTP secret / unit / chart colors
        │
        ▼
SugarPaceApp (lifecycle, owns the services; onServiceCallback → AppState)
   ├─ NightscoutService  (serialized request queue)  ──►  OtpService (TOTP)
   │        │ mutates                                      Otp → Hmac → Sha1 → Convert
   │        ▼
   └─► AppState (glucose, history, foods, profile, tap regions, chart window, scroll, send state)
            ▲ requestUpdate()
   SugarPaceView · TempOverridesView · food selection views · SugarPaceGlanceView   (+ their delegates)
```

| Path | Role |
|---|---|
| `source/SugarPaceApp.mc` | Orchestrator, lifecycle, settings-changed handler, glance entry |
| `source/SugarPaceView.mc`, `SugarPaceDelegate.mc` | Main screen (glucose header, chart, food grid) and its tap/swipe/key handling |
| `source/TempOverridesView.mc` | Profile selection screen + its input delegate |
| `source/Food*View.mc`, `Food*Delegate.mc` | Food selection menu (category → brand → item) |
| `source/SugarPaceGlanceView.mc` | Glance (home carousel) |
| `source/Layout.mc` | **Every** named layout constant (margins, gaps, percentages, intervals) |
| `source/Constants.mc` | Glucose zone thresholds, timings, fake HTTP codes, send states |
| `source/Units.mc`, `source/ErrorText.mc` | mg/dL ↔ mmol/L display; error code → short message |
| `source/DrawableRegistry.mc` | `picture id → Rez.Drawables.symbol` map |
| `source/models/` | `AppState`, `GlucoseData`, `FoodItem`, `FoodDatabase` |
| `source/services/` | `NightscoutService` (network), `OtpService` (payload + TOTP) |
| `source/otp/` | TOTP / HOTP (RFC 6238 / 4226): `Otp`, `Hmac`, `Sha1`, `Convert` |
| `resources/` | `settings/`, `properties/`, `strings/` + `strings-fre/`, `foods/foods.json`, `drawables/` |

### Conventions

- **Layout:** no magic numbers in views. Extend `Layout.mc`. `SugarPaceView.onUpdate` computes everything from `dc.getWidth()/getHeight()`. Two scroll modes around `Layout.COMPACT_HEIGHT_THRESHOLD`: tall screens pin the header and chart and scroll only the grid; short screens (840) scroll the whole page.
- **Hit-testing:** regions `{x0,y0,x1,y1}` stored in `AppState` and tested with `AppState.isPointInRegion`.
- **Glucose zones:** centralised in `GlucoseData.getZoneColor()`; reuse it, never duplicate the thresholds. Values are kept in **mg/dL** internally; the unit setting only changes display and the unit sent to Loop.
- **Settings:** read with `Application.Properties.getValue(...)` and guard the type with `instanceof` before use.
- **Timestamps:** always real UTC through `Time.Gregorian.utcInfo(...)`, never a hard-coded offset.
- **Strings used by the glance** must be declared with `scope="glance"` in `strings.xml`, otherwise `loadResource` crashes there.

## Nightscout API

Carb entry (with a one-time code):

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
  "notes": "Food name",
  "units": "mg/dL",
  "created_at": "2025-09-08T12:52:04.000Z"
}
```

Other calls: glucose entries `GET /api/v1/entries.json?count=48` (current value and chart history in one request), profiles `GET /api/v1/profile.json`, overrides `GET /api/v1/treatments.json`, activate / cancel an override `POST /api/v2/notifications/loop`.

### Network rules

- The device's BLE bridge crashes the app under **concurrent** `Communications.makeWebRequest` calls. `NightscoutService` serializes everything through one queue (`enqueue` / `dispatchNext` / `onRequestComplete`): never call `makeWebRequest` directly.
- A watchdog (15 s) abandons a lost request and reports a timeout to its responder; a late answer to an abandoned request is ignored. User actions (sending carbs) jump ahead of background fetches, and sends are **never retried automatically**.
- Fetches are scheduled by `AppState.isFetchDue`: faster retries after a failure, a faster poll when the reading is overdue.

## Adding a food

The preferred way is a GitHub issue with the **"Ajouter un aliment"** template: the `add_food.yml` workflow downloads and resizes the image and opens a pull request (the `picture` slug is generated, the glycemic index is estimated per category when left empty).

By hand, touch exactly four things, in this order:

1. `resources/foods/foods.json` — add the entry (`id`, `name`, `brand`, `subcategory`, `picture`, nutrition values).
2. `resources/drawables/brands/<picture>.png` — **150×150 px**, **transparent background** (the bitmap is composited on the cell colour; `drawBitmap` does not resize).
3. `resources/drawables/drawables.xml` — add `<bitmap id="<picture>" filename="brands/<picture>.png" />`.
4. `source/DrawableRegistry.mc` — add `"<picture>" => Rez.Drawables.<picture>,` to the map.

`SugarPaceView.mc` must never be edited to add a food. Step 4 is easy to forget and fails silently (the category default image is shown).

## Known pitfalls

1. **Type-checker `OutOfMemoryError`** on arithmetic over nullable `Number?` values (`var x = null; … x - y`): not a real memory issue. Use non-null accumulators with a `seen` flag instead of `null` sentinels, and early-exit `if` chains instead of long `&&` with `instanceof` narrowing on `Object?`.
2. **`Rez.Drawables[stringVar]` does not work**: it is a namespace of compile-time constants, not a runtime dictionary, and fails silently. That is why `DrawableRegistry` exists.
3. **Glance code**: arithmetic with `Time.now()` reachable from the glance made the compiler fail with an uninformative "critical error". Keep the glance minimal.
4. **Glance background** follows the system day/night theme, not the app's black background: no `getGlanceTheme()` is declared, and the text colour adapts through `System.getDeviceSettings().isNightModeEnabled`.
5. **Widgets vs glances**: Connect IQ apps appear in the glance list; the native widget drawer cannot list them.
6. **Product images**: sizes are exact pixels, backgrounds must be transparent, and `drawScaledBitmap` does not exist on these devices.

## The data field (`datafield/`)

A second app, a **read-only data field** for the activity screens: it shows the latest glucose and its trend (for example `112 ↗`), puts the age of the reading in the label (`Glucose 3m`), and records the glucose in the activity's FIT file (developer field 0, mg/dL, one value per record; Garmin Connect charts it after the activity). It never sends anything to Nightscout, and a reading older than 15 minutes shows `--` and is not written to the FIT file.

Why a separate app: widgets and data fields are sandboxed from each other. There is no way to share storage or call code between two apps on the device, so the data field fetches by itself (one `entries.json?count=1` request from the foreground, only when a new reading is due) and has its own settings in Garmin Connect (URL, token, mmol/L).

```
datafield/
  manifest.xml          type="datafield", its own app id, Communications + FitContributor
  monkey.jungle         base.sourcePath = source;../source/models/GlucoseData.mc;../source/Units.mc;../source/Constants.mc
  source/               SugarPaceFieldApp, SugarPaceField (SimpleDataField), EntriesParser, tests/
  resources/            strings (EN/FR), properties, settings, fitfields.xml, launcher icon
```

**Shared code by source path.** The data field compiles three widget files in place (no copy): `GlucoseData.mc` (zones, arrows, data age), `Units.mc` (mg/dL ↔ mmol/L) and `Constants.mc`. Rules for those files: never add code that sends or needs the widget's classes (`AppState`, `NightscoutService`, `Rez` strings), keep them small (the data field has **128 KB** of memory in all, versus 1 MB for the widget), and the widget's own `monkey.jungle` sets `base.sourcePath = source` explicitly, otherwise the default search would also pick up `datafield/source`. They must not carry a `(:background)` annotation, which would force the `Background` permission on the data field.

Build and test (same SDK variables as above):

```bash
cd datafield
java -Xms1g -jar "$SDK/bin/monkeybrains.jar" -o field.prg -f monkey.jungle -y "$KEY" -d edge1050 -w
java -Xms1g -jar "$SDK/bin/monkeybrains.jar" -o field-test.prg -f monkey.jungle -y "$KEY" -d edge1050 --unit-test -w
```

CI builds it on the four devices and compiles its tests (`build-datafield`, `test-compile-datafield`). The tests make no request; the safety rule above applies to the data field as well.

**Not verified yet on a real device:** a foreground web request from a data field (the docs allow it since API 5.0.0), the real memory use under the 128 KB limit (the compiled `.prg` is about 105 KB; check the simulator's memory view), and how `112 ↗` renders in each layout (1 to 6 fields).

## Releasing to the Connect IQ Store

See [`branding/PUBLISH.md`](branding/PUBLISH.md) (form fields, store texts in English and French, risks, order of steps), [`branding/STORE.md`](branding/STORE.md) (repository text, logo brief) and [`PRIVACY.md`](PRIVACY.md) (privacy policy). Before exporting: the default Nightscout URL, token and OTP secret must stay empty in `properties.xml`.

## Related files

- `CONTEXT.md` — architecture decision records (for example the add-a-food automation).
- `CLAUDE.md` — context file for the Claude Code assistant (in French).
- `code_review.md` — an old review note, kept for history.
