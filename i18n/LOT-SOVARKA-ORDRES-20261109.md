# Lot i18n — quatre ordres Sovarka (9 novembre 2026)

**Périmètre :** compléments de catalogue uniquement, sur branche dédiée depuis `main`. Aucun changement de jeu, de `data.js`, des coûts, des permissions, des PA, des identifiants ni des conditions serveur. **Activation multilingue du plateau toujours interdite** (`RP_I18N_GAME_ENABLED !== true`).

## Quatre nouveaux libellés littéraux constatés

| Identifiant | Canon français lu dans `data.js` | Partie du jeu |
| --- | --- | --- |
| `sovarka_musee_billet` | Billet du musée présidentiel | Palais présidentiel |
| `sovarka_surveiller` | Placer sous surveillance | Ministère, surveillance citoyenne |
| `sovarka_registre_plaintes` | Affaires judiciaires | Ministre de la Justice |
| `sovarka_extrait_parti` | Extrait d'enregistrement du parti | Guichet des partis |

Chaque libellé est renseigné dans **FR, EN, ES, zh-TW, RU, KO, AR, pt-BR, DE** dans `i18n/orders-resources.js`. Le rendu d'ordre déjà existant `RPOrderI18n.label` ne traduit une commande par identifiant qu'en cas de correspondance **exacte** avec la version française. Les chaînes originales restent envoyées au moteur métier ; les variantes de contexte non reconnues gardent le français.

**Contrôle ajouté :** `node outils/bancs/banc-i18n-sovarka-ordres-novembre.cjs` — vérification des 36 entrées, de la correspondance française, du repli sans traduction en cas de libellé divergent, de la non-modification du contrat d'ordre et du maintien du drapeau de non-activation. Aucune action serveur n'est exécutée.

**Limites :** ces quatre lignes n'équivalent pas à une traduction complète des fenêtres de la Sécurité du Peuple, du musée ou de la Justice. Relecture éditoriale native et essai navigateur réel restent à conduire. Aucune activation publique n'est autorisée par ce lot.

## Extension du lot : amorces de deux PNJ sociaux (sans mécanique nouvelle)

Les **deux textes d'interpellation spontanée** de Jean-Lou Demer au bar des pêcheurs et Marine Leroux au restaurant sont désormais localisés dans les **neuf langues**, via `i18n/social-pnj-resources.js` chargé dans `plateau.html`.

Le changement dans `plateau-social-pnj.js` se limite à choisir le texte affiché : 
- **français et plateau non activé :** texte source strictement identique, y compris les civilités de Marine ;
- **autres langues si activation future autorisée :** salutations traduites et nom du personnage conservé sans traduction ;
- **invariants :** noms/profils/portraits, identité du PJ, déclencheur serveur, position, mémoire relationnelle, nombre de rencontres, fenêtre existante, ordre de déclenchement, journal et dialogue IA non modifiés.

Le nouveau banc `node --test outils/bancs/banc-i18n-pnj-sociaux-amorces.cjs` vérifie les neuf locales, l'interpolation, le repli en français et l'absence de traduction pour une clé inconnue. Un workflow GitHub dédié `.github/workflows/i18n-sovarka-pnj.yml` lance aussi les vérifications syntaxiques et les deux bancs de ce lot.

**Ce que le lot ne fait PAS :** générer des propos DeepSeek dans neuf langues, traduire le contenu passé de la relation, traduire le journal déjà enregistré, étendre le nombre de PNJ sociaux, ni activer le drapeau `RP_I18N_GAME_ENABLED`.
