# Régression du conditionnement Vercel

L'application reste sans `package.json` à la racine. Ce répertoire contient
uniquement le constructeur de test `@vercel/node` épinglé à **5.3.25** et son
verrou npm ; `outils/` est exclu du déploiement par `.vercelignore`.

Depuis la racine du dépôt :

```sh
npm ci --prefix outils/vercel --no-audit --no-fund
npm test --prefix outils/vercel
```

Node 24 est utilisé en CI. Le banc fait réellement compiler les graphes par
`@vercel/node`, matérialise les fichiers de la Lambda dans un dossier jetable,
puis les charge dans un processus CommonJS séparé. Les extensions modernes de
Node acceptant `require(ESM)` et détectant automatiquement ESM sont désactivées
pour reproduire le refus observé dans les journaux de production. La configuration
du constructeur sélectionne Node 22 ; sa version exacte en production reste inconnue.

La contre-épreuve reconstruit l'ancien import `.mjs` avec la logique canonique
actuelle et exige **exactement `ERR_REQUIRE_ESM`**, pas simplement un échec.
Le correctif doit ensuite charger, exécuter dix conversations simulées et
conserver les rôles PNJ/secrétaire pour maire et adjoint. Toutes les autres
entrées API sont compilées et chargées également. Un import ESM natif transitif
échappant à la compilation fait échouer le banc.

Les fournisseurs et l'authentification sont simulés ; aucun appel Supabase/IA
réel, déploiement ou achat n'est effectué. Le code métier municipal reste unique
dans `continuite-municipale.js`. Le navigateur conserve son point d'entrée
`continuite-municipale.mjs`, qui réexporte ce même code. L'API importe le `.js`,
comme les autres modules compilés par Vercel. Ne pas réintroduire d'import
serveur du `.mjs` ni déclarer tout le projet ESM pour résoudre ce seul problème.

Le banc est découvert par `controler-client.py` ; la CI installe ses dépendances
avant cette suite. Aucune dépendance npm n'est ajoutée au runtime du jeu.
