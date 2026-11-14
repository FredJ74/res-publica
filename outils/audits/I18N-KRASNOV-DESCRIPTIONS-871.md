# #871 — descriptions de Krasnov — 15 novembre 2026

Dix descriptions uniques : hall et appartements des immeubles de la place de l’Ours et de la rue du Tabac, boutique Tabac/Presse, accueil et cinq salles du musée de Krasnov. Quatre bâtiments concernés. 80 valeurs étrangères ajoutées dans les huit langues étrangères ; français original et toutes les anciennes traductions conservés.

Le résolveur existant et le rafraîchissement de la pièce ouverte sont inchangés. Le seul ajustement de rendu est `dir="auto"` sur la description, pour le sens de lecture arabe ; ni nouveau moteur, ni RPC, ni données, ni migration, ni mécanique modifiés.

## Vérification

- 9 tests ciblés verts, dont 270 bascules Chromium, neuf langues et largeurs 320/390/1280. Texte français, suffixes dynamiques, saisie, sélection, focus, position, progression, inventaire, PA et argent conservés ; aucun appel métier supplémentaire. Repli français vérifié quand une traduction manque.
- Ancien banc des descriptions : main 431d69e = 4 réussites/1 échec (10 descriptions manquantes), branche = 5/5.
- 43 contrôles de non-régression : mêmes 42 réussites/1 échec sur main et branche. L’ancienne phrase « Impossible de restaurer la position depuis le serveur. » a été retirée des sources par les correctifs de navigation de main ; le contrôle des corps de notifications la détecte désormais comme obsolète. Ce lot ne modifie ni ce catalogue ni les correctifs.
- Compression déterministe des 84 catalogues, restitution exacte des sources, transport HTTP natif Chromium et intégrité des mécanismes vérifiés parmi ces contrôles.
- Audit global sans erreur d’extraction, même méthode et mêmes 17 655 textes identifiés. Le plancher anglais reste 25,21 % des mots statiques reconnus : l’extracteur ne reconnaît pas les nouveaux raccordements de descriptions de pièces. Ce chiffre ne mesure pas tout le jeu. Les dix descriptions sont vérifiées séparément dans le navigateur.

## Blocage de livraison

Main contient 347 905 696 octets de payload simulé (331,8 Mo) pour un plafond de 346 030 080 octets (330 Mo), dépassé depuis les images du musée. La branche contient 347 910 317 octets, soit +4 621 octets. Le plafond et les images sont inchangés. La garde de déploiement est donc rouge sur les deux versions. Ne pas fusionner ou annoncer ce lot déployé tant que le budget de main n’est pas rétabli ou explicitement arbitré. Aucune recette PJ authentifié, téléphone physique ou relecture native effectuée.

Les migrations et images arrivées par intégration de main sont celles des autres chantiers ; aucune migration n’a été exécutée dans cette mission.

## Notifications livrées avant ce lot

PR #924 fusionnée `e688472e281d8d7c223fc4cbc7d67cdbf862ad99`, Vercel `dpl_4RxowEMjxUjHTYSzGr8x4RLjzQ1u` READY et alias public confirmé. 94 fichiers publics identiques, 84 catalogues décompressés directement par Chromium ; 4 077 bascules organisations et 1 728 bascules refus sur fichiers publics réussies. Preuve : `I18N-NOTIFICATIONS-CORPS-871-production.json`.

## Fichiers du lot

- `.github/workflows/i18n-krasnov-descriptions-20261115.yml`
- `RELAIS.md`
- `i18n/packed/sovarka-descriptions-resources.js.br`
- `i18n/sovarka-descriptions-resources.js`
- `outils/audits/I18N-CATALOGUES-TRANSPORT.json`
- `outils/audits/I18N-KRASNOV-DESCRIPTIONS-871-preuve.json`
- `outils/audits/I18N-KRASNOV-DESCRIPTIONS-871-sources.json`
- `outils/audits/I18N-KRASNOV-DESCRIPTIONS-871.md`
- `outils/audits/I18N-NOTIFICATIONS-CORPS-871-production.json`
- `outils/audits/i18n-global/TABLEAU-DE-BORD.md`
- `outils/audits/i18n-global/exclusions-appliquees.json.gz`
- `outils/audits/i18n-global/inventaire.json.gz`
- `outils/audits/i18n-global/priorites.json.gz`
- `outils/audits/i18n-global/ressources.json.gz`
- `outils/audits/i18n-global/sources.json.gz`
- `outils/audits/i18n-global/tableau-de-bord.json`
- `outils/bancs/banc-i18n-krasnov-descriptions-20261115.cjs`
- `plateau.html`
