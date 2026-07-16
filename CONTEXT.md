# SugarPace — Context & ADRs

## ADR-001 : Ajout d'aliment via GitHub Issue (2026-07-16)

### Contexte

Ajouter un aliment au catalogue nécessite aujourd'hui de toucher 4 endroits manuellement :
1. `resources/foods/foods.json`
2. `resources/drawables/drawables.xml`
3. `resources/drawables/brands/<picture>.png`
4. `source/DrawableRegistry.mc`

L'étape 4 est silencieusement oubliable (retombe sur l'image par défaut sans erreur de compilation).

### Décision

Automatiser l'intégralité du processus via une GitHub Issue template + un workflow Actions qui ouvre une PR prête à merger.

### Détails retenus

**Déclenchement** : à la création de l'issue (immédiat, pas de label intermédiaire). Repo personnel, le seul auteur d'issues est le propriétaire.

**Slug `picture`** : généré automatiquement par le workflow, jamais saisi par l'utilisateur.
```
picture = f"{brand.strip().lower().replace(' ', '_')}_{name.strip().lower().replace(' ', '_')}"
```

**Image** : l'utilisateur colle dans le template l'URL d'une image GitHub (glisser-déposer dans l'issue → `user-images.githubusercontent.com/...`). Le workflow la télécharge et la redimensionne à 150×150 px (fond transparent préservé).

**Estimation GI** : champ optionnel dans le template. Si vide, formule calibrée sur le catalogue existant :

| Sous-catégorie | Baseline GI |
|---|---|
| GEL | 80 |
| JELLIES | 82 |
| BAR | 55 |
| OTHER | 65 |

Correction par portion : `gi = baseline - 0.5 × fat_g - 0.3 × protein_g`, plancher 20, arrondi entier.

**Fichiers modifiés par le workflow** :
- `resources/foods/foods.json` — insertion de l'entrée JSON
- `resources/drawables/drawables.xml` — ajout `<bitmap>`
- `resources/drawables/brands/<picture>.png` — image redimensionnée
- `source/DrawableRegistry.mc` — ajout ligne dans le Dictionary

**Validation** : un script Python séparé vérifie la cohérence (foods.json ↔ drawables.xml ↔ DrawableRegistry.mc), exécutable localement et en CI.
