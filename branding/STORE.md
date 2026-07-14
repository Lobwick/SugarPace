# SugarPace — Branding & Store Copy

Everything copy-pasteable for the Connect IQ store listing and the GitHub repo.
Logo source: [logo.svg](logo.svg) (launcher icon derived at 68×68 in
`resources/drawables/logo.png`).

---

## GitHub

**Repo "About" description (one line):**

> SugarPace — Garmin Edge widget for T1D endurance riders: live Nightscout glucose + one-tap remote carb entries to your closed-loop system.

**Topics suggestions:** `garmin` `connect-iq` `monkey-c` `nightscout` `diabetes` `type-1-diabetes` `cycling` `closed-loop`

---

## Connect IQ Store — English

**Name:** SugarPace
**Tagline:** Pace your sugar.

**Description:**

SugarPace puts your glucose and your fueling on the same screen — your Edge.

Built by and for type 1 diabetic endurance riders on closed-loop systems: see your glucose at a glance, and log carbs to your loop in one tap when you refuel mid-ride. No phone, no menus, no stopping.

FEATURES
• Live glucose from your Nightscout site: value color-coded by range (green/orange/red), trend arrow, data freshness
• Glucose history chart — tap it to cycle 4h / 2h / 1h / 30 min windows
• One-tap fueling: tap a food tile (gels, jellies, bars) to send a remote carb entry to your loop, secured by a one-time password (TOTP)
• Temporary override profiles: see the active profile, tap the header to switch
• Home-screen glance with your latest reading
• Option: color the chart bars by glucose zone

REQUIREMENTS
• A Nightscout site (URL + API token)
• A closed-loop setup that accepts OTP-secured remote carb entries
• Configure URL, token, OTP secret and unit in the app settings (Garmin Connect app)

DISCLAIMER
SugarPace is not a medical device and must never be the sole basis for treatment decisions. It displays data from your own Nightscout service and sends carb entries to a system that you configure and control. Always confirm values and decisions with approved medical devices. Use at your own risk.

---

## Connect IQ Store — Français

**Nom :** SugarPace
**Tagline :** Ton sucre, ton rythme.

**Description :**

SugarPace réunit ta glycémie et ton ravitaillement sur le même écran : ton Edge.

Conçue par et pour les sportifs d'endurance diabétiques de type 1 sous boucle fermée : vois ta glycémie d'un coup d'œil, et envoie tes glucides à ta boucle en un seul tap quand tu te ravitailles en roulant. Sans téléphone, sans menus, sans t'arrêter.

FONCTIONNALITÉS
• Glycémie en direct depuis ton site Nightscout : valeur colorée selon la zone (vert/orange/rouge), flèche de tendance, fraîcheur de la donnée
• Graphique d'historique — tape dessus pour passer de 4h à 2h / 1h / 30 min
• Ravitaillement en un tap : touche une vignette d'aliment (gels, pâtes de fruits, barres) pour envoyer une entrée de glucides à ta boucle, sécurisée par mot de passe à usage unique (TOTP)
• Profils temporaires (overrides) : profil actif visible, changement en tapant l'en-tête
• Glance sur l'écran d'accueil avec ta dernière mesure
• Option : colorer les barres du graphique selon la zone glycémique

PRÉREQUIS
• Un site Nightscout (URL + token API)
• Une boucle fermée acceptant les entrées de glucides distantes sécurisées par OTP
• URL, token, secret OTP et unité à configurer dans les réglages de l'app (application Garmin Connect)

AVERTISSEMENT
SugarPace n'est pas un dispositif médical et ne doit jamais être la seule base d'une décision de traitement. L'app affiche les données de ton propre service Nightscout et envoie des glucides à un système que tu configures et contrôles. Vérifie toujours les valeurs et les décisions avec des dispositifs médicaux approuvés. Utilisation à tes risques.

---

## Logo — brief de génération (pour une version illustrée)

Si tu veux une déclinaison plus riche que le SVG plat, prompt pour un
générateur d'images :

> Flat minimal app icon, dark near-black rounded square background (#0B0D10).
> A white outlined water-drop / glucose drop shape, centered. Inside the drop,
> two bold forward chevrons (fast-forward symbol) suggesting pace and speed:
> first chevron vibrant green (#00C853), second chevron orange (#FF9100),
> rounded stroke ends. Clean vector style, high contrast, no gradients, no
> text, no shadows. Must stay legible at 40×40 pixels. Sport-tech aesthetic,
> bike computer icon language.

Contraintes launcher Garmin : PNG 68×68 (Edge), silhouette simple, éviter les
détails fins ; garder le même motif que le glance pour la cohérence.
