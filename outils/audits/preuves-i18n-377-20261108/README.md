# Preuves de la revue #377, 8 novembre 2026

Code applicatif examiné : `6173d9a4ede2d2e27b10f4d8557c8976138601dc`.
Ces scripts ne corrigent rien et n'appellent aucun fournisseur payant.

Depuis la racine du dépôt :

- `node outils/audits/preuves-i18n-377-20261108/reproduire-menus.cjs`
  (Acorn dans outils/vercel/node_modules).
- `node outils/audits/preuves-i18n-377-20261108/reproduire-traduction.mjs`.
- `node outils/audits/preuves-i18n-377-20261108/comparer-donnees.cjs`
  (Git avec la coupe 30887df7 disponible).
- Avec pgserver et psycopg2 disponibles :
  `python3 outils/audits/preuves-i18n-377-20261108/valider-stockage-local.py`.
  Ce dernier démarre et détruit sa propre base, ignore les connexions de
  production et ne lit aucune variable de connexion pour choisir sa cible.

**Attention :** un succès des deux scripts « reproduire » signifie qu'un défaut
est reproduit, pas que le code est conforme. Les assertions portent sur les
observations ; après correction, il faut de vrais tests de non-régression aux
attentes inversées dans les bancs applicatifs. Ces diagnostics ne sont pas ajoutés
au contrôleur de conformité pour faire passer une anomalie au vert.

Autres commandes réellement exécutées :

- `python3 outils/bancs/controler-client.py --rapport /tmp/audit377-clients`.
- `node --test outils/bancs/banc-i18n-*.cjs outils/bancs/banc-i18n-*.mjs outils/bancs/banc-traduction-i18n.mjs outils/bancs/banc-accueil-neuf-langues.cjs`.
- Banc `outils/bancs/i18n/banc-navigateur-neuf-langues.cjs`, servi par http.server
  sur localhost : Playwright et Chromium locaux, aucune session, requêtes externes
  bloquées dans le banc. Le binaire local est indiqué au lanceur via préchargement
  hors dépôt ; aucune adaptation du jeu.
- `node outils/audits/etat-i18n-ordres.cjs` et
  `node outils/audits/audit-i18n-editorial.cjs`.

Les JSON de reproductions ne contiennent que des textes et personnages fictifs.
Aucun export de production, identifiant réel ou secret dans ce dossier.
