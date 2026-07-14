# SugarPace — Connect IQ App

[Français](README.md) · **English**

> *Pace your sugar.*

**SugarPace** is a Connect IQ app for Garmin Edge bike computers that puts glucose and fueling on the same screen: live glucose tracking (via Nightscout) and one-tap carb entries to your closed-loop system — treat a low while riding, without pulling out your phone. Branding & store copy: [branding/](branding/STORE.md).

---

# 1. Usage

## Main screen

The main screen reads top to bottom:

- **Current glucose** in large type, colored by zone (green = in range, orange = near limits, red = out of range), followed by the unit and the **trend arrow** (`↑↑`, `↑`, `↗`, `→`, `↘`, `↓`, `↓↓`).
- **Active Nightscout profile** (dot + name) in the center of the header.
- **Freshness** of the reading on the right (e.g. `2m ago`).
- **Trend chart** as bars over the last few hours.
- **Food grid** (icon + name) at the bottom.

## Touch interactions

| Tapped area | Action |
|---|---|
| **A food tile** | Sends that food (its carbs) to Loop, with an OTP code generated on the fly |
| **The chart** | Cycles the displayed time window: 4h → 2h → 1h → 30min → 4h. The vertical scale adapts to the window's min/max |
| **The header** (glucose / profile) | Opens the **temporary profile** selection screen |
| **Menu** (physical button / `⋮`) | Also opens the temporary profile selection |

## Temporary profile selection

The screen lists the profiles/overrides available on Nightscout. The **active** profile is marked with a green bar and a checkmark. Tapping a profile activates it; tapping **Default** cancels the current temporary override.

## Settings (Garmin Connect / Connect IQ)

Configurable from the Garmin Connect (mobile) or Connect IQ (Express) app:

- **Nightscout URL** — your instance URL (e.g. `https://my-nightscout.example.com`)
- **Nightscout Token** — Nightscout authentication token
- **OTP Secret** — TOTP key for Loop (see § 2)
- **Default User** — name attached to sent entries
- **Default Unit** — displayed unit (`mg/dl` or `mmol`)
- **Color chart bars by glucose zone** — when on, each chart bar takes its zone color; otherwise bars stay gray (default)

> Loop prerequisite: your Loop must accept remote entries (Remote Carbs) via the Nightscout `notifications/loop` API.

---

# 2. Generating the OTP code (TOTP secret)

The **OTP secret** is required for Loop to accept remote commands. You retrieve it **once** from Loop's 2FA QR code, then paste it into the app settings.

### Step 1 — Locate the QR code in Loop
1. In the **Loop** app, open the security / remote services settings.
2. Display the **two-factor authentication (2FA) QR code**: it encodes the OTP secret.

### Step 2 — Extract the secret from the QR code
1. Take a **screenshot** of the QR code.
2. Open the online tool [2FA QR Code Extractor](https://stefansundin.github.io/2fa-qr/).
3. Upload the screenshot.
4. The tool returns the **secret** (a string like `MNWUPWJFCJRJJ4WSBPC27HJ5CZUM6YKK`).

### Step 3 — Configure the app
1. Copy the extracted secret.
2. In Garmin Connect → app settings → paste it into **OTP Secret**.
3. Save.

When you send a food, the app generates a 6-digit TOTP code (rotating every 30 s) from this secret.

⚠️ **Keep this secret confidential.** The watch clock must be synced, otherwise codes will be rejected.

---

# 3. For developers

## Building

Standard Monkey C project (Connect IQ SDK). Build entry point: `monkey.jungle` → `manifest.xml`.

```bash
# Build for a device (e.g. edge1050), signed with your developer key
monkeyc -f monkey.jungle -d edge1050 -o bin/SugarPace.prg -y developer_key

# Run in the simulator
connectiq                 # starts the simulator
monkeydo bin/SugarPace.prg edge1050
```

> ⚠️ The type checker can hit an `OutOfMemoryError` on arithmetic over nullable `Number?` values. Keep numeric accumulators non-null (a `seen`/flag pattern) instead of `null` sentinels.

## Architecture

Views / state / services separation:

**App & UI**
- `source/SugarPaceApp.mc` — lifecycle, service initialization, callbacks
- `source/SugarPaceView.mc` — main screen (glucose header, chart, food grid)
- `source/SugarPaceDelegate.mc` — tap handling (food / chart / header)
- `source/SugarPaceMenuDelegate.mc` — menu
- `source/TempOverridesView.mc` — profile selection screen + its input delegate
- `source/SugarPaceGlanceView.mc` — glance view

**State (models)**
- `source/models/AppState.mc` — centralized state (glucose, history, foods, profile, tap regions, chart window)
- `source/models/GlucoseData.mc` — glucose reading (value, trend, zone colors)
- `source/models/FoodItem.mc`, `source/models/FoodDatabase.mc` — foods

**Services**
- `source/services/NightscoutService.mc` — Nightscout requests (glucose, profiles, carb sending). BLE requests are deliberately **non-concurrent** (current value + history merged into a single request; profile fetch staggered) to avoid crashes.
- `source/services/OtpService.mc` — builds the entry payload + OTP code

**OTP**
- `source/otp/Otp.mc` — TOTP generation
- `source/otp/Hmac.mc` — HMAC-SHA1
- `source/otp/Sha1.mc` — SHA1
- `source/otp/Convert.mc` — utilities (Base32, etc.)

**Resources**
- `resources/settings/settings.xml` + `resources/properties/properties.xml` — configurable settings
- `resources/strings/` (+ `strings-fre/`) — labels (EN / FR)
- `resources/menus/menu.xml` — menus
- `resources/foods/foods.json` — food list (the data; `foods.xml` is just the resource declaration)
- `resources/drawables/` — food icons

## Nightscout API

**Sending carbs** (with OTP):

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
  "units": "mg/dl",
  "created_at": "2025-09-08T12:52:04.000Z"
}
```

**Other calls**: read glucose entries (`/api/v1/entries.json?count=48`), read profiles (`/api/v1/profile.json`), overrides (`/api/v1/treatments.json`), activate/cancel override (`/api/v2/notifications/loop`).

## Foods

The list is defined in `resources/foods/foods.json`. To add/change a food, edit that file (and `resources/drawables/` for the icon).

| Name | Brand | Category | Serving | Carbs | GI | Fat | Protein | Energy |
|---|---|---|---|---|---|---|---|---|
| Energy Gel+ Red Fruit | Decathlon | GEL | 35 g | 30 g | 80 | 0 g | 0 g | 502 kJ |
| Energy Gel Red Fruit -3H | Decathlon | GEL | 35 g | 30 g | 85 | 0 g | 0 g | 502 kJ |
| 1:0.8 Gel Cola | Decathlon | GEL | 45 g | 40 g | 70 | 0 g | 0 g | 680 kJ |
| Fruit Jelly | — | JELLIES | 44 g | 35 g | 85 | 0 g | 0 g | 598 kJ |
| Energy Bar Dates & Nuts | — | BAR | 50 g | 31 g | 55 | 5.5 g | 2.3 g | 800 kJ |

⚠️ Glycemic index (GI) values are estimated when not printed on the packaging.

## Compatibility

Tested on **Garmin Edge 1050**. Target devices: Edge 540/550/840/850/1040/1050 (see `manifest.xml`).

## Troubleshooting

- **No data**: check the Nightscout URL and token.
- **Invalid OTP**: check the OTP secret and the watch clock sync.
- **Crash on launch**: classic symptom of concurrent BLE requests — keep network fetches non-simultaneous.

## Security

- One-time **TOTP** code (30 s) generated on-device.
- **HTTPS** communication with Nightscout, token-based access.

---

## Support & contributions

- **GitHub Issues** for bugs and feature requests.
- Please include: Garmin device model, app version, description of the problem, system logs if possible.
