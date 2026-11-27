# Blocage de la clôture documentaire — 27/11/2026

PR #1216 ; workflow **46080019076**, groupe `bancs-js (5)`, job **140777008065** : `banc-controles-globaux-20261107.cjs` échoue avec **Seed miroir différent du générateur : ordres_couts**.

Erreur identique reproduite en local sur **main intact 6ebbbd9e** et sur la branche documentaire. Le banc, le générateur, data.js, le seed et tous les fichiers JavaScript sont inchangés par cette PR ; empreintes dans `BLOCAGE-CLOTURE-20261127.json`. Les premiers essais locaux manquaient de la dépendance Acorn à cause d’un lien macOS restauré avec le workspace : après réparation locale temporaire, l’erreur de seed est bien reproduite des deux côtés. Aucun défaut de Chromium invoqué.

`ECART-SEED-20261127.diff` compare le fichier existant à la sortie du générateur, **sans modifier aucun seed ni appliquer de SQL**. Cinq entrées retirées par le code récent restent dans le miroir (`compte_offshore`, `consulter_caisse_usine`, `consulter_stock_usine`, `deliberer_loge`, `sovarka_goulag_gestion`) ; deux entrées nouvelles y manquent (`indices_interrogatoire`, `transferts_detenus`) ; deux anciens tarifs 2 PA y restent à la place des 1 PA de la source (`interroger`, `interroger_renseignement`). Ce relevé ne décide d’aucune règle et ne modifie aucun coût.

Les **82 exécutions push vertes associées au commit servi** étaient un constat exact mais couvraient les bancs sélectionnés pour ces envois ; elles ne prouvaient pas que chaque banc hors sélection passait. La PR documentaire a déclenché le contrôle plus large et révélé ce défaut préexistant. Cette limite est explicitement corrigée dans le bilan.

**Aucune fusion de #1216 avec ce rouge.** Le responsable du lot coûts/baseline doit remettre le miroir en cohérence avec les sources validées, puis la clôture pourra être rebasée et ses contrôles rejoués. Aucune correction de seed, de coûts, de migration ou de fonction serveur n’est entreprise dans ce lot i18n.

Les fonctionnalités #1183/#1184 sont déjà fusionnées, déployées et vérifiées ; ce blocage concerne la fusion du dossier de preuves et la correction des anciennes mentions du relais. Les preuves sont publiées sur la branche `codex/i18n-livraison-20261127`.

Résultat complet de la révision documentaire `e1b12270` : **10 contrôles verts, 1 rouge** ; seul `bancs-js (5)` échoue sur ce miroir. Les six groupes et tous les autres contrôles ont terminé ; aucune autre erreur n’est masquée.
