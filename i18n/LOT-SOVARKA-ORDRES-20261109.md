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
