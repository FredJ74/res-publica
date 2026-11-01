# Collecte privée #219 — SQL Editor

1. Ouvrir `outils/bancs/COLLECTE-ATOMIQUE-219.sql`, copier son contenu dans le SQL Editor du projet **res-publica**.
2. Choisir **No limit / Aucune limite de lignes**, puis **Run**. Le script ne contient qu'un SELECT : les sept ensembles partagent le même instantané, sans écriture ni transaction laissée ouverte.
3. Télécharger **le résultat complet en CSV** (Download/Export CSV), puis joindre ce fichier à la conversation privée. Ne pas copier les cellules affichées : leur aperçu peut être tronqué. Ne rien publier sur GitHub. Une seule exécution ; ne jamais mélanger deux campagnes.

Le tableau contient les fragments numérotés, leurs tailles et SHA-256, le SHA-256 de chaque fichier et celui du manifeste privé. L'assembleur refuse toute troncature, absence, duplication, mélange ou incohérence. Aucun mot de passe à transmettre.

## Reprise technique — à effectuer par Codex/intégrateur, pas par Fred

```bash
PYTHONPATH=/workspace/hg-parser17 /workspace/hg-venv/bin/python outils/livraison/export-sql-editor-219.py \
  --assembler /chemin/prive/resultat.csv --destination /tmp/hg219-capture-courante
```

Si le SHA-256 du manifeste a été transmis indépendamment, ajouter `--sha256-manifeste <64 caractères hexadécimaux>`. Sinon le contrôle de transport est réalisé, mais la preuve ne déclare pas cette comparaison indépendante effectuée. Ne jamais remplacer l'empreinte reçue par celle que l'assembleur veut obtenir.

Résultat, hors Git : les sept JSON originaux, le manifeste, `catalogue/canoniques/export_{structure,fonctions,logique,droits}.json`, registre/contrôle/graines, `LOCALE-PRODUCTION.json`, `capture-couts.json`, `INTEGRITE-IMPORT.json` et `exports-certification-219.tar.gz`. Dossiers700/fichiers600. Octets JSON originaux conservés ; décimaux des fichiers dérivés écrits exactement. L'archive n'est jamais publiée et n'est pas extraite dans le dépôt.

Vérifier l'intégrité, la coupe actuelle (au moins1022, sans la figer à1022), les six racines, les12 tables et la locale. Les douze contenus sont dans `referentiels.json` ; le chargeur historique reçoit les quatre tables de `referentiels-prives-hg219-coupe-courante.json`. Les contrôles MD5 PostgreSQL des contenus et la comparaison des racines restent obligatoires sur le clone : « archive assemblée » ne signifie pas « clone certifié ».

Le plan est prêt via `preparer-recette97-219.py --sortie /tmp/plan97.json` (ajouter `--paquet /tmp/hg219-capture-courante` pour le delta privé complet). L'ancien plan de tarifs438→452 reste refusé ; les sources intégrées attendent459 triples, MD5 `1e69581b8020f7375f95d7cdf5dd6c39`. Après comparaison du contenu reçu : régénérer les SQL/seeds avec les outils existants, réviser la migration tarifaire et les gardes selon le réel, puis reconstituer et certifier PostgreSQL17.6/ICUen-US153.121. Aucun simple remplacement d'empreinte.

Ordre :95 en transaction, rollback de panne, installation, rejeu refusé sans mutation ; puis `20261101170000` (#318), puis `20261101171000` (#324). Chaque lot doit être validé sur le clone. Les27 HTTP GoTrue/PostgREST doivent ensuite être exécutés sur cet état final. Le plan d'ordre ne les exécute pas et ne contourne aucune dépendance.

Génération reproductible du SQL : `export-sql-editor-219.py --generer-sql`. Il réutilise le manifeste et les requêtes canoniques ; ne jamais retoucher le SQL généré à la main. Les changements du relais sont inclus dans le SHA des requêtes du manifeste de capture.
