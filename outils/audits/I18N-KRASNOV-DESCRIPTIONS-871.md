# #871 — descriptions de Krasnov — 15 novembre 2026

Dix descriptions uniques : hall et appartements des immeubles de la place de l’Ours et de la rue du Tabac, boutique Tabac/Presse, accueil et cinq salles du musée de Krasnov. Quatre bâtiments concernés. 80 valeurs étrangères ajoutées dans les huit langues étrangères ; français original et toutes les anciennes traductions conservés.

Le résolveur existant et le rafraîchissement de la pièce ouverte sont inchangés. Le seul ajustement de rendu est `dir="auto"` sur la description, pour le sens de lecture arabe ; ni nouveau moteur, ni RPC, ni données, ni migration, ni mécanique modifiés.

## Clôture technique — 15 novembre 2026

Dernier main b89a264 intégré sans conflit ; optimisation #972 conservée, aucune modification d’image ni du plafond. Accueil autonome, URL de cache et quatre bureaux du centre d’affaires identiques à main. Catalogue des dix descriptions et toutes les anciennes traductions intacts.

- 23 contrôles ciblés verts, dont 270 bascules Chromium : neuf langues, 320/390/1280, sens arabe RTL, français exact, suffixes/saisie/sélection/focus/position/progression/inventaire/PA/argent conservés, zéro appel métier supplémentaire. Les tests de l’accueil, des images WebP, du cache et des bureaux sont verts ; les anciennes URL de test ont été actualisées, sans toucher aux images ou au jeu.
- 84 catalogues compressés vérifiés octet par octet. Transport HTTP natif Chromium et intégrité des fonctions métier vérifiés.
- Quatre descriptions de pièces ajoutées depuis le lot restent manquantes sur main. Le banc ciblé vérifie, sur un main figé, la correction exacte des dix absences du lot et l’absence de nouvelle lacune ; son diagnostic signale ces quatre lacunes hors lot. Le contrôle global strict sans cette option continue de les signaler.
- Régressions : 42/43. L’unique échec courant concerne quatre descriptions d’ordres communes manquantes, également reproduites sur main b89a264 ; l’ancien plafond de trois est conservé. L’inventaire réel passe de 247 à 248. L’ancien échec de notification obsolète est corrigé par une preuve de provenance historique et une liste exacte d’une phrase retirée ; aucune autre absence n’est admise. Aucun nouveau texte traduit hors des dix descriptions.
- Audit régénéré depuis l’état intégré, aucune erreur d’extraction. Le pourcentage de mots statiques reconnus reste un plancher ; ces raccordements de pièces sont vérifiés séparément dans le navigateur, sans prétendre mesurer tout le jeu.

## Livraison

PR #969 existante conservée. Le blocage du payload est levé : 264,7 Mo pour 330 Mo, environ 65,3 Mo de marge. Fusion et vérification de production en cours ; les preuves de production préciseront le SHA et le déploiement réellement contrôlés. Aucun PJ authentifié, téléphone physique ou contrôle linguistique natif testé.

Les migrations et images arrivées par intégration de main appartiennent aux autres chantiers ; aucune migration n’a été exécutée dans cette mission.

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
