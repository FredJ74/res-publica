# Réception du catalogue après Forums #422 — intégrateur ChatGPT

**État courant : la collecte a déjà été exécutée par ChatGPT, mais son fichier
n'est pas présent dans le workspace Codex. Ne pas la recommencer si l'original
est disponible.** Aucun outil/jeton Vercel ou Supabase ni clé PGP n'est exposé ici.
L'identifiant d'instantané seul n'est pas un fichier téléchargeable.

**Action unique pour ChatGPT intégrateur : transmettre le JSON déjà déchiffré de
la capture existante en fichier privé.** Ne publier ni archive ni catalogue ni clé
sur GitHub/CI. La migration `20261104001711` est déjà appliquée, ne pas la rejouer.

Paquet annoncé, **non reçu et non vérifié ici** :
- instantané `snap_VVIJobjaBuB1JmUk0KnbWfkzXRFQ`, expiration annoncée 11/11/2026 ;
- `hg422-capture.pgp.b64` : 1 236 916 octets, SHA256
  `60676500e22ff0a7bd787424d122d3c1965fce3607e872883043094050a043f8` ;
- JSON déchiffré : 5 639 402 octets, SHA256
  `054043e74e8f50dbfcff6f42cc224bf7f547953779126c73cfd1a162305af954` ;
- manifeste original `hg422_capture_manifest.json` non reçu. Le MANIFESTE de ce
  dossier conserve ces **attentes communiquées**, sans se faire passer pour lui.

Ces empreintes ne valent que pour cette capture précise. Un autre relevé exige
sa propre provenance et ses empreintes indépendantes, jamais un hash forcé.
Le JSON original déchiffré suffit : aucune clé privée à transmettre à Codex.
Après réception, comparer taille/SHA256, puis utiliser le validateur existant
avec `--sortie-privee` comme indiqué plus bas. Comparer registre et empreintes,
rendre/seeds, contrôler le diff et seulement ensuite certifier la livraison.

Les requêtes ci-dessous restent le dispositif de collecte **de remplacement**,
à utiliser par l'intégrateur uniquement si le paquet existant est irrécupérable.

Les quatre fichiers `outils/bancs/COLLECTE-FORUMS422-export_*.sql` sont exactement les SELECT imprimés par
`outils/baseline/requetes.py --export <nom>`. `outils/bancs/COLLECTE-FORUMS422-controle_global.sql` est le contrôle
canonique. Tous sont sans écriture. `MANIFESTE.json` donne leurs tailles et SHA-256.

## Collecte conseillée : une seule requête

Exécuter **`outils/bancs/COLLECTE-FORUMS422-capture_atomique.sql` par le connecteur Supabase de ChatGPT**.
C'est le SELECT du collecteur existant `relais-canonique-219.py`, réutilisé tel quel :
les quatre requêtes canoniques, contrôle global, registre, cinq mesures de miroirs et
dix référentiels authored déjà autorisés. Aucun compte PJ, message ou `auth.users`.
Un SELECT = un instantané ; ne pas tronquer ni reformater les nombres.

Conserver le résultat original hors Git, permission 600, puis transmettre en privé
son SHA-256 calculé à la source. Le format `HG_RELAIS_CANONIQUE_219_V1` reste celui
du collecteur existant, il n'indique ni une ancienne coupe ni une migration à rejouer.
Ne jamais remplacer un résultat incomplet par le catalogue précédent.

Si le connecteur limite la taille, fournir les quatre résultats séparés **complets**
et le contrôle, sous une transaction cohérente conservée par le canal technique.
Sans cohérence démontrée, ne pas prétendre à une capture unique. Ne pas compléter
un fragment absent depuis un autre relevé. Les exports séparés ne contiennent pas
les seeds : prévoir leur collecte après émission de `seeds.py --sql`.

## Réception et reprise par l'agent technique

Ces commandes sont pour les agents, jamais pour le game designer. Chemins privés
hors de tout dépôt, à adapter sans placer de secret dans un argument :

```sh
sha256sum /tmp/hg422-capture.json
python3 outils/livraison/relais-canonique-219.py \
  --verifier /tmp/hg422-capture.json --sortie-privee /tmp/hg422-recu
```

Le répertoire cible doit être neuf. Le validateur refuse incohérences, fonctions
corrompues, catégories absentes et options de séquences manquantes. Il matérialise :

- `canoniques/export_structure.json`
- `canoniques/export_fonctions.json`
- `canoniques/export_logique.json`
- `canoniques/export_droits.json`
- `controle_global.json`, `registre.json`, `referentiels_controle.json`
- `seeds.json` (dix référentiels autorisés) et `provenance.json`.

Avant rendu, vérifier sur le fichier reçu : nom/version #422, les deux corps MD5
annoncés par l'intégrateur, les huit policies, RLS, rôles et droits de séquences.
Les séquences n'ont pas toutes nécessairement un droit client : ne pas inventer
un GRANT manquant ni imposer un nombre de droits tiré de l'ancien baseline.

Puis **exécuter les outils existants**, sans éditer le SQL rendu :

```sh
python3 outils/baseline/rendre.py /tmp/hg422-recu/canoniques
python3 outils/baseline/seeds.py --sql /tmp/hg422-recu/canoniques > /tmp/hg422-seeds-a-collecter.sql
```

`seeds.py --sql` doit être relu pour sa surface classifiée avant exécution par le
connecteur de ChatGPT. Le relais ne capture volontairement que dix tables authored :
ne pas traiter ces dix tables comme un export complet des seeds. Collecter les
seeds nécessaires au catalogue reçu, ou conserver explicitement les seeds anciens
inchangés via `fusionner-seeds-captures.py` en documentant leur provenance ; jamais
annoncer qu'ils ont tous été réextraits. Aucun contenu privé ne doit être publié.
Après réception du résultat complet autorisé :

```sh
python3 outils/baseline/seeds.py --rendre /tmp/hg422-recu/canoniques /tmp/hg422-seeds.json
python3 outils/baseline/regenerer-seeds-miroirs.py
python3 outils/baseline/controler-tout.py
```

Actualiser les attentes **uniquement depuis la capture** avec les outils du
workflow (`actualiser-attentes-catalogue.py`, contrôle global reçu), classer les
objets nouveaux si nécessaire, examiner intégralement le diff. Ne pas déduire les
attentes du SQL qu'on vient de rendre. Ne pas avancer le point de coupe sans les
exports. Archiver la migration Forums uniquement quand son effet est dans le
baseline réel ; conserver son préfixe Git original et documenter la version du
registre `20261104001711`. Ne pas archiver en bloc les autres migrations sans
rapprochement du registre par nom et dépendances.

## Livraison après réconciliation

Conserver #410/#423/#424/#425/#426/#427/#430 et les évolutions de main. Ne pas
importer séparément la branche #428 ; sa fusion indépendante dans main `bcdbe141` est conservée. Contrôler l'exact SHA final et ses cinq CI, puis sortir
#422 du brouillon/fusionner seulement si les conditions sont satisfaites.

Pour Vercel : observer le statut READY et le commit du déploiement de production ;
relire les ressources servies `plateau.html`, `forum.js`, `supabase.js` et leurs
versions. Un statut Actions ne prouve pas la version servie.

Recette sans écriture sur un PJ réel : lectures authentifiées avec comptes isolés,
ville/pays réel et accès direct REST sujets/réponses, chef/membre/tiers, compteurs,
voyants et règles institutions/presse/international/sport. Aller-retour et perte
d'adhésion sous fixtures isolées ; ne pas déplacer ni exclure un vrai PJ pour
produire cette preuve. Absence de JWT : refus sans fuite, pas une recette PJ.
