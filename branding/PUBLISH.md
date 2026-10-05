# SugarPace — Dossier de publication Connect IQ

Tout ce qu'il faut pour remplir le formulaire de soumission. Textes prêts à
copier-coller (EN + FR). Rédigés d'après les
[App Review Guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)
(version du 13 oct. 2021, lues le 5 oct. 2026) et la page
[Publishing to the Store](https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/).

> ⚠️ Le formulaire exact (libellés, limites de caractères, catégories) n'est visible
> qu'une fois connecté au compte développeur. Les champs ci-dessous viennent de la
> doc publique + des pratiques courantes du store : **vérifie-les en face du vrai
> formulaire** et ajuste.

---

## 1. Avant de soumettre

| À faire | Détail |
|---|---|
| Compte développeur Garmin | Connexion sur le site Developer ; accepter le Connect IQ Developer Agreement |
| Clé de signature | **La même `developer_key` pour toutes les versions** (sauvegardée hors du repo) |
| Test réel | Au moins un vrai Edge (840 ou 1040/1050) : réseau Bluetooth, envoi, rendu des textes |
| **Beta d'abord** | Upload avec **un autre UUID** dans `manifest.xml` + case « Beta App » : permet de tester les réglages dans Garmin Connect en production. Visible **seulement dans ton compte** (pas partageable) |
| Export | Commande VS Code **Monkey C: Export Project** → fichier `.iq` (contient tous les appareils du manifest) |
| Compte de démonstration | Voir §5 : le relecteur doit pouvoir faire marcher l'app |

Appareils du manifest : **Edge 840, 850, 1040, 1050** (tactiles uniquement). Langues : anglais, français.
Délai de relecture annoncé : **72 h** hors jours fériés ; l'app reste invisible pendant la relecture mais tu peux la télécharger pour la tester.

---

## 2. Champs du formulaire

| Champ | Valeur |
|---|---|
| Fichier | `SugarPace.iq` |
| Nom | **SugarPace** |
| Type | Widget (déduit du manifest) |
| Catégorie | La plus proche de « Santé / Forme » ou « Widgets » (choisir dans la liste) |
| Prix | **Gratuit** |
| Appareils | Ceux du manifest (cocher tout ce qui est proposé) |
| Description EN / FR | §3 |
| Nouveautés de la version | §4 |
| Captures d'écran | §6 |
| E-mail de contact | *ton e-mail de support* (à garder à jour — exigé par les guidelines) |
| Site web / support | `https://github.com/Lobwick/SugarPace` (page Issues) |
| Politique de confidentialité | `https://github.com/Lobwick/SugarPace/blob/main/PRIVACY.md` (disponible une fois poussé sur GitHub) — texte de référence : [PRIVACY.md](../PRIVACY.md) |
| Nom de développeur | Ton vrai nom ou un alias qui n'usurpe personne |
| ANT+ | Non (aucun profil ANT+ utilisé) |
| Paiement requis | Non |

---

## 3. Description du store

> Règles appliquées : décrire **toutes** les fonctions et **toutes** les dépendances
> (Nightscout requis) ; pas de promesse médicale ; ne pas laisser croire à un
> partenariat avec Garmin, Nightscout ou Loop ; aucun terme « diagnostic /
> traitement ». Voir §8 pour les risques.

### English

**Name:** SugarPace
**Tagline:** Glucose at a glance. Carb entries in one tap.

**Description:**

SugarPace puts your glucose readings and your carb logging on the screen of your Garmin Edge, so you can check and log without taking out your phone while riding.

WHAT IT DOES
• Shows your latest glucose reading from your own Nightscout site, color-coded by range, with trend arrow and the age of the reading. Readings older than 15 minutes are greyed out and flagged.
• Bar chart of the last 4 h / 2 h / 1 h / 30 min (tap the chart to switch).
• One-tap carb entry: tap a food tile (gel, jelly, bar…) to send a carb entry to your Nightscout-connected system. Each entry is secured by a one-time code (TOTP). The tile shows the result (sending / sent / failed with a short reason). Double taps are ignored so an entry is never sent twice.
• Temporary profile (override) selection: see the active profile and switch from the screen.
• Home-screen glance with your latest reading.
• mg/dL or mmol/L display, English and French.

WHAT YOU NEED (required — the app does nothing without them)
• A Nightscout website you run or have access to (URL + access token).
• An automated insulin delivery app connected to that Nightscout that accepts remote carb entries and a one-time-password secret.
• A Garmin Edge 840, 850, 1040 or 1050 (touchscreen), paired with your phone with Garmin Connect — the Edge uses your phone's connection to reach Nightscout.
Settings (URL, token, OTP secret, unit) are entered in the Garmin Connect app.

IMPORTANT
SugarPace is a convenience display and data-entry tool. It is NOT a medical device, is not intended to diagnose, treat, cure, mitigate or prevent any condition, and must never be your only source of information. Always confirm values and decisions with your approved medical devices. You are responsible for the entries you send. Not affiliated with, endorsed by or sponsored by Garmin, Nightscout, or any insulin-delivery app. All trademarks belong to their owners.

SugarPace does not collect, store or share any data on any server of its own: it only talks to the Nightscout address you configure. Privacy policy and support: github.com/Lobwick/SugarPace

### Français

**Nom :** SugarPace
**Tagline :** Ta glycémie d'un coup d'œil. Tes glucides en un tap.

**Description :**

SugarPace affiche ta glycémie et te permet d'enregistrer tes glucides directement sur ton Garmin Edge, sans sortir ton téléphone pendant que tu roules.

CE QUE FAIT L'APPLICATION
• Affiche ta dernière mesure de glycémie depuis ton propre site Nightscout, colorée selon la zone, avec flèche de tendance et ancienneté de la mesure. Une mesure de plus de 15 minutes est grisée et signalée.
• Graphique des 4 h / 2 h / 1 h / 30 min (touche le graphique pour changer).
• Saisie de glucides en un tap : touche une vignette d'aliment (gel, pâte de fruits, barre…) pour envoyer une entrée de glucides à ton système relié à Nightscout. Chaque entrée est sécurisée par un code à usage unique (TOTP). La vignette affiche le résultat (envoi / envoyé / échec avec une courte raison). Les doubles taps sont ignorés : une entrée n'est jamais envoyée deux fois.
• Sélection du profil temporaire (override) : profil actif visible, changement depuis l'écran.
• Glance sur l'écran d'accueil avec ta dernière mesure.
• Affichage en mg/dL ou mmol/L, en français et en anglais.

PRÉREQUIS (obligatoires — sans eux l'application ne fait rien)
• Un site Nightscout que tu héberges ou auquel tu as accès (URL + token d'accès).
• Une application d'administration automatisée d'insuline reliée à ce Nightscout, qui accepte les entrées de glucides à distance, et son secret de mot de passe à usage unique.
• Un Garmin Edge 840, 850, 1040 ou 1050 (tactile), associé à ton téléphone avec Garmin Connect — l'Edge utilise la connexion du téléphone pour joindre Nightscout.
Les réglages (URL, token, secret OTP, unité) se saisissent dans l'application Garmin Connect.

IMPORTANT
SugarPace est un outil d'affichage et de saisie de confort. Ce n'est PAS un dispositif médical, il n'est pas destiné à diagnostiquer, traiter, guérir, atténuer ou prévenir une affection, et ne doit jamais être ta seule source d'information. Vérifie toujours les valeurs et les décisions avec tes dispositifs médicaux approuvés. Tu es responsable des entrées que tu envoies. Sans lien, affiliation ni parrainage avec Garmin, Nightscout ou une application d'insuline. Les marques appartiennent à leurs propriétaires.

SugarPace ne collecte, ne stocke et ne partage aucune donnée sur un serveur qui lui appartient : il ne communique qu'avec l'adresse Nightscout que tu configures. Confidentialité et support : github.com/Lobwick/SugarPace

---

## 4. Nouveautés de la version (1.3.2)

**EN:**
- Display glucose in mmol/L (new setting).
- Clear feedback when sending carbs: sending / sent / failed with a short reason. Double taps are ignored.
- Age of the glucose reading shown honestly: orange after 10 min, red and greyed out after 15 min; automatic retry after a failed refresh.
- Profile screen now explains why a change failed.
- Safer behavior when the app is not configured yet.

**FR :**
- Affichage de la glycémie en mmol/L (nouveau réglage).
- Retour clair à l'envoi de glucides : envoi / envoyé / échec avec une courte raison. Les doubles taps sont ignorés.
- Ancienneté de la mesure affichée sans ambiguïté : orange après 10 min, rouge et grisée après 15 min ; nouvelle tentative automatique après un échec.
- L'écran des profils explique pourquoi un changement a échoué.
- Comportement plus sûr tant que l'app n'est pas configurée.

---

## 5. Notes pour le relecteur Garmin (si le formulaire a un champ « notes »)

À mettre aussi dans la description / README si pas de champ dédié.

> SugarPace is a front-end for a user's own Nightscout site. To test it you need a
> Nightscout URL and token. A demo Nightscout instance with fake data is available:
> URL `…`, token `…`, OTP secret `…` (read/write on a sandbox only). Enter them in
> Garmin Connect > SugarPace > Settings. No data is collected by the developer.
> The only permission needed is Communications (web requests to the configured URL).

**À préparer :** une instance Nightscout **de démonstration**, avec de fausses
données, et des identifiants **dédiés et jetables**. **Ne donne jamais** tes
vrais identifiants : une app qui ne marche pas pour le relecteur est refusée
(« functionality »), et un envoi de test ne doit jamais atteindre ta vraie boucle.

---

## 6. Captures d'écran

Faites au simulateur (Edge **1050** et **840** ; pas le 850 : bug de texte du
simulateur). Utiliser une instance de **démo**, jamais les vraies données.

1. Écran principal avec glycémie verte, flèche, graphique, grille d'aliments (1050).
2. Même écran en version compacte (840).
3. Tuile verte « envoyé » (ou orange « Envoi… »).
4. Écran des profils temporaires.
5. Glance sur l'écran d'accueil.
6. Réglages dans Garmin Connect (capture téléphone, **sans** token ni secret visibles — masquer).

Éviter de montrer : marques tierces lisibles (Decathlon, 226ers) si possible, ton
URL réelle, ta vraie glycémie.

---

## 7. Politique de confidentialité (à publier)

**EN**

SugarPace — Privacy policy (last updated: 5 Oct 2026)

SugarPace is an app for Garmin Edge devices. The developer does not operate any server for this app and does not collect, receive, store, sell or share any personal data, analytics or crash reports.

What the app handles: glucose readings and profile names that it downloads from the Nightscout address you configure; the carb entries and profile changes you choose to send to that same address; and the settings you enter (URL, access token, one-time-password secret, unit). All of this stays on your Garmin device and in your Garmin Connect account (which stores app settings under Garmin's own privacy policy), and is exchanged only with your own Nightscout site over HTTPS. The app uses your phone's connection through Garmin Connect to do so.

You control and are responsible for your Nightscout site and the data on it. To remove the app's data, uninstall SugarPace and clear its settings in Garmin Connect.

The app is not intended for children under 13. Contact: *your support e-mail* · github.com/Lobwick/SugarPace/issues

**FR**

SugarPace — Politique de confidentialité (dernière mise à jour : 5 oct. 2026)

SugarPace est une application pour Garmin Edge. Le développeur n'exploite aucun serveur pour cette application et ne collecte, ne reçoit, ne stocke, ne vend ni ne partage aucune donnée personnelle, statistique ou rapport de plantage.

Ce que l'application manipule : les mesures de glycémie et noms de profils téléchargés depuis l'adresse Nightscout que tu configures ; les entrées de glucides et changements de profil que tu choisis d'envoyer à cette même adresse ; et les réglages que tu saisis (URL, token d'accès, secret de mot de passe à usage unique, unité). Tout reste sur ton Garmin et dans ton compte Garmin Connect (qui conserve les réglages selon sa propre politique de confidentialité), et n'est échangé qu'avec ton propre site Nightscout en HTTPS, via la connexion de ton téléphone et Garmin Connect.

Tu contrôles ton site Nightscout et les données qu'il contient, et tu en es responsable. Pour supprimer les données de l'app : désinstalle SugarPace et efface ses réglages dans Garmin Connect.

L'application n'est pas destinée aux enfants de moins de 13 ans. Contact : *ton e-mail de support* · github.com/Lobwick/SugarPace/issues

---

## 8. Risques de refus et parades

| Risque | Pourquoi | Parade |
|---|---|---|
| **« Medical app »** (guidelines §1c) | L'app envoie des glucides à une boucle d'insuline : proche d'un usage thérapeutique. Garmin peut exiger des **documents réglementaires** ou refuser. | Description « outil d'affichage et de saisie », aucune allégation médicale, disclaimer en tête ; ne jamais écrire « traitement », « dosage », « insuline automatique » comme fonction. Être prêt à une réponse du type « informationnel uniquement ». **Si refus** : distribuer le `.prg` à la main (sideload) ou publier l'affichage seul (sans envoi de glucides) |
| **Sécurité physique / faux sentiment de sécurité** (§1b) | Une glycémie périmée affichée pourrait rassurer à tort | Déjà traité : valeur grisée à 15 min, « ! » si échec, aucun retry d'envoi. Le dire dans les notes au relecteur |
| **Marques** (§3a) | « Loop », « Nightscout », « Decathlon », « 226ers » + images produit | Citer Nightscout seulement comme dépendance, avec la mention de non-affiliation. Éviter « Loop » dans le titre/visuels. Pour les aliments : **vérifier le droit d'utiliser les logos et images des marques** (Decathlon, 226ers…), sinon noms/images génériques |
| **L'app ne fonctionne pas pour le relecteur** (§2a) | Rien ne s'affiche sans Nightscout | Instance de démo + identifiants jetables (§5) |
| **Confidentialité / RGPD** (§3c, page Publishing) | L'app envoie des données de santé via `Communications` | Politique publiée (§7), aucune collecte côté développeur |
| **Permissions inutiles** | Le manifest déclare `Background` et `PersistedContent` alors qu'aucun service d'arrière-plan n'existe | Les retirer (seul `Communications` est nécessaire) puis tester sur appareil |
| **Description inexacte** (§4a) | Doit citer toutes les fonctions et dépendances | Le §3 le fait ; garder la liste des appareils à jour |
| **Avis / notes** (§4c) | Interdiction de se noter ou de faire noter par des proches contre avantage | Ne pas le faire |
| **Support** (§2b) | Il faut dire clairement comment obtenir de l'aide | Lien Issues GitHub + e-mail dans la fiche |

---

## 9. Ordre conseillé

1. Retirer les permissions inutiles, tester sur un vrai Edge, finir la rotation des clés Apple/Loop et refaire les tests de bout en bout.
2. Monter l'instance Nightscout de démo (identifiants jetables).
3. Prendre les captures d'écran (§6).
4. Publier la politique de confidentialité (§7) et créer l'e-mail de support.
5. Export `.iq` → **upload en Beta** (UUID alternatif) → vérifier les réglages dans Garmin Connect.
6. Remettre l'UUID de production, re-exporter, soumettre sans la case Beta.
7. Attendre jusqu'à 72 h ; lire le motif d'un éventuel refus et répondre.
