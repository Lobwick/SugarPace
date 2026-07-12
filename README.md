 # Diabetes Food Management - Connect IQ App

Une application Connect IQ pour appareils Garmin qui permet de gérer facilement l'entrée de glucides pour les utilisateurs de pompes à insuline Loop.

## 🚀 Fonctionnalités

### Affichage Principal
- **Glycémie en temps réel** : Affichage de la glycémie actuelle depuis Nightscout
- **Tendance** : Flèche de direction et taux de variation
- **Horodatage** : Temps depuis la dernière mise à jour
- **Liste des aliments** : Affichage des aliments disponibles avec leurs glucides

### Navigation et Sélection
- **Navigation** : Utilisez les boutons Page Précédente/Suivante ou les touches directionnelles
- **Sélection visuelle** : L'aliment sélectionné est mis en surbrillance
- **Envoi direct** : Appuyez sur Select/Enter pour envoyer l'aliment à Loop

### Intégration Loop
- **Génération OTP** : Code TOTP généré automatiquement pour l'authentification
- **API Nightscout** : Envoi sécurisé des données de glucides via l'API notifications/loop
- **Métadonnées complètes** : Nom de l'aliment, quantité de glucides, timestamp ISO

## 📱 Compatibilité

Testé sur :
- **Garmin Edge 1050**
- Autres appareils Connect IQ compatibles

## 🔧 Installation

1. Compilez l'application avec Connect IQ SDK
2. Installez le fichier `.prg` sur votre appareil Garmin
3. Configurez les paramètres dans l'application Garmin Connect

## ⚙️ Configuration

### Paramètres requis dans l'app Garmin Connect :
- **Nightscout URL** : URL de votre instance Nightscout (ex: `https://votre-nightscout.herokuapp.com`)
- **Nightscout Token** : Token d'authentification pour votre Nightscout
- **Secret OTP** : Clé secrète TOTP pour l'authentification Loop (voir section ci-dessous)

### Récupération du Secret OTP

Le secret OTP est nécessaire pour l'authentification avec Loop. Voici comment l'obtenir :

#### Étape 1 : Localiser le QR Code
1. Dans votre application Loop, allez dans les paramètres de sécurité
2. Trouvez le QR code pour l'authentification à deux facteurs (2FA)
3. Ce QR code contient le secret OTP nécessaire

#### Étape 2 : Extraire le Secret du QR Code
1. **Capture d'écran** : Prenez une capture d'écran du QR code affiché dans Loop
2. **Outil d'extraction** : Utilisez l'outil en ligne [2FA QR Code Extractor](https://stefansundin.github.io/2fa-qr/)
3. **Upload** : Téléchargez votre capture d'écran sur cet outil
4. **Récupération** : L'outil va extraire le secret (une chaîne comme `MNWUPWJFCJRJJ4WSBPC27HJ5CZUM6YKK`)

#### Étape 3 : Configuration
1. Copiez le secret extrait
2. Dans l'app Garmin Connect, collez ce secret dans le champ "Secret OTP"
3. Sauvegardez la configuration

⚠️ **Important** : Gardez ce secret confidentiel et ne le partagez jamais.

### Configuration Loop
Assurez-vous que votre Loop est configuré pour accepter les entrées distantes via l'API Nightscout.

## 🎮 Utilisation

### Navigation
1. **Page Suivante** : Naviguer vers l'aliment suivant
2. **Page Précédente** : Naviguer vers l'aliment précédent  
3. **Select/Enter** : Sélectionner et envoyer l'aliment en surbrillance

### Menu
- **Menu** : Accès aux Temp Overrides (profils temporaires)

### Logs de Débogage
Les logs système affichent :
- Coordonnées des aliments affichés
- Navigation entre les aliments
- Génération OTP et envoi des données
- Réponses de l'API Nightscout

## 🔒 Sécurité

- **Authentification TOTP** : Code à usage unique généré toutes les 30 secondes
- **Transmission chiffrée** : Communications HTTPS avec Nightscout
- **Token d'authentification** : Accès sécurisé aux API Nightscout

## 🛠️ Structure du Code

### Fichiers principaux
- `DiabetesFoodManagementApp.mc` : Application principale et logique de démarrage
- `DiabetesFoodManagementView.mc` : Interface utilisateur et affichage
- `DiabetesFoodManagementDelegate.mc` : Gestion des événements et navigation
- `DiabetesFoodManagementMenuDelegate.mc` : Gestion du menu

### Modules OTP
- `otp/Otp.mc` : Génération des codes TOTP
- `otp/Hmac.mc` : Implémentation HMAC-SHA1
- `otp/Sha1.mc` : Algorithme SHA1
- `otp/Convert.mc` : Utilitaires de conversion

### Ressources
- `resources/menus/menu.xml` : Définition des menus
- `resources/strings/strings.xml` : Textes de l'interface

## 📊 API Nightscout

### Endpoint utilisé
```
POST /api/v2/notifications/loop?token=<token>
```

### Données envoyées
```json
{
  "enteredBy": "felix",
  "eventType": "Remote Carbs Entry",
  "otp": "123456",
  "remoteCarbs": 15,
  "remoteAbsorption": 1,
  "notes": "Nom de l'aliment",
  "units": "mg/dl",
  "created_at": "2025-09-08T12:52:04.000Z"
}
```

## 🍽️ Aliments disponibles

La liste des aliments proposés dans l'app est définie dans `resources/foods/foods.json`. Pour ajouter ou modifier un aliment, éditez ce fichier (voir aussi `resources/drawables/` pour les icônes associées).

| Nom | Marque | Catégorie | Portion | Glucides | IG | Lipides | Protéines | Énergie |
|---|---|---|---|---|---|---|---|---|
| Energy Gel+ Red Fruit | Decathlon | GEL | 35 g | 30 g | 80 | 0 g | 0 g | 502 kJ |
| Energy Gel Red Fruit -3H | Decathlon | GEL | 35 g | 30 g | 85 | 0 g | 0 g | 502 kJ |
| 1:0.8 Gel Cola | Decathlon | GEL | 45 g | 40 g | 70 | 0 g | 0 g | 680 kJ |
| Fruit Jelly | — | JELLIES | 44 g | 35 g | 85 | 0 g | 0 g | 598 kJ |
| Energy Bar Dates & Nuts | — | BAR | 50 g | 31 g | 55 | 5.5 g | 2.3 g | 800 kJ |

⚠️ Les valeurs d'index glycémique (IG) sont estimées lorsqu'elles ne sont pas indiquées sur l'emballage du produit.

## 🐛 Dépannage

### Problèmes courants
- **Pas de données d'aliments** : Vérifiez la connexion Nightscout et l'URL
- **OTP invalide** : Vérifiez que le secret OTP est correct et que l'heure est synchronisée
- **Navigation ne fonctionne pas** : Utilisez les boutons Page Précédente/Suivante sur Edge 1050

### Logs utiles
Consultez les logs système pour :
- Erreurs de réseau
- Codes de réponse HTTP
- Coordonnées des aliments
- Valeurs OTP générées

## 🆘 Support et Contributions

### Signaler un Bug ou Demander une Fonctionnalité
Pour toute question, bug ou demande de nouvelle fonctionnalité, vous pouvez :

- **GitHub Issues** : Créer une issue sur le repository GitHub du projet
- **Email** : Contacter directement [felix.moulin@decathlon.com](mailto:felix.moulin@decathlon.com)

Merci de fournir les détails suivants :
- Modèle d'appareil Garmin
- Version de l'application
- Description du problème ou de la fonctionnalité souhaitée
- Logs système si applicable

---

## 📝 Notes de Développement

ajouter l'aide pour recuperer le secret OTP https://stefansundin.github.io/2fa-qr/

ajouter la clef dans les properties et pas en dur 

ajouter le sizing dynamic pour pouvoir ajouter plus d'element 