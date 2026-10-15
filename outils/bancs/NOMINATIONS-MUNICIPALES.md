# Nominations municipales — application et contrôles

## État : en attente de la base

Le code est préparé pour `main`. La migration et le banc SQL **n'ont pas été
exécutés**, conformément à la consigne du game designer. Les validations SQL
locales portent uniquement sur les grammaires SQL et PL/pgSQL (pglast), sans
connexion ni application. Le chantier n'est pas terminé.

Migration : `migrations/20261015210718_nominations_municipales_au_maire.sql`.
Le changement serveur doit être appliqué avant de considérer le nouveau parcours
comme utilisable en partie. Le serveur actuellement déployé peut encore accorder
l'autorité d'entrepôt à l'adjoint et refuser le maire jusqu'à cette application.

## Périmètre audité

Les deux modèles `BUILDINGS['mairie-capitale']` et `BUILDINGS.mairie` portent les
bureaux du maire et de l'adjoint. Le premier couvre Luthécia ; le second couvre
Port-Sainte-Marie et Montrouge. Les mairies des autres empires réutilisent ces
modèles : leurs surcharges locales ont été contrôlées pour ne pas réintroduire
les anciens boutons. Aucun nouveau poste ou bâtiment n'est créé.

Le maire a un bouton gratuit **Nominations**, puis trois dossiers réutilisant
`ouvrirGestionPosteNomme`, `ouvrirGestionCandidatures`, les confirmations et RPC
existantes. Le commissaire peut désormais afficher ses candidatures dans ce même
circuit, au tarif existant de nomination de 3 PA. Pour l'adjoint, la nomination
reste fondée sur les candidatures ; aucun bouton de nomination directe n'est
inventé. Le directeur conserve les deux chemins existants : candidature et
nomination directe.

| Acte | Commissaire | Maire adjoint | Directeur d'entrepôt |
|---|---:|---:|---:|
| Ouverture/consultation du dossier | gratuit | gratuit | gratuit |
| Attribution depuis les candidatures | 3 PA | 1 PA | 1 PA |
| Proposition de nomination directe | 3 PA | non proposée | 3 PA |
| Révocation | 1 PA | 1 PA | 1 PA |

Tous ces actes restent à 0 FR. Les gardes d'éligibilité, d'incompatibilité,
les délais et les protections existantes ne sont pas modifiés. Le payeur reçoit
l'identifiant de l'acte, pas le nom du menu gratuit. Les tarifs sont déclarés
dans `ACTIONS_POSTE_NOMME` et reconnus par le générateur existant des coûts.

Le rôle et le territoire sont revérifiés à l'ouverture et dans les confirmations,
y compris les appels directs et l'ancienne façade de l'entrepôt. La révocation
municipale d'un PNJ emprunte désormais `poste_revoquer`, car la suppression
directe par un client est interdite par la RLS.

## Dépendances et effets de la migration

Pas de secret, d'extension ou de paquet applicatif supplémentaire. Utiliser le
compte technique et **apply_migration** du connecteur Supabase, conformément à
`WORKFLOW-SUPABASE.md` ; ne pas appliquer hors registre.

Les prérequis sont déjà présents dans le baseline : `auth.uid()`,
`personnages_donnees`, `postes_nommes_regles`, `ordres_couts`, `batiments_etat`,
`poste_autorite_de`, `batiment_etat_lire`, `jsonb_cles_hors_liste` et
`batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb)` ; rôles `anon` et
`authenticated`.

La migration :

1. Change **une seule règle**, `directeur_entrepot.nomme_par`, de `maire_adjoint`
   à `maire`. Les RPC `poste_nommer`, `poste_attribuer_candidature`,
   `poste_revoquer` et leurs limites territoriales lisent déjà cette règle.
2. Ajoute uniquement les sept triplets de coût utilisés par les actes des
   dossiers, sans réécrire les autres prix ou leurs sentinelles historiques.
3. Ajoute un helper interne, inaccessible à `anon` et `authenticated`, puis
   l'appelle depuis la porte de stockage existante après le verrou de ligne.
   Un adjoint ou un tiers ne peut plus traiter/effacer un dossier d'entrepôt,
   modifier ses candidats, son échéance ou son nominateur. Tout joueur garde
   le droit d'ajouter **sa propre** candidature, avec les métadonnées de la
   fenêtre existante de 48 h ; une autre candidature n'est jamais remplacée.
   Les autres dossiers et sous-clés ne sont pas modifiés.
4. Vérifie structurellement le transfert, le patch et les droits du helper.
   Le patch est idempotent et refuse une définition de porte qui aurait dérivé.

Aucun titulaire ni dossier en cours n'est réécrit par la migration. Le mécanisme
existant de réconciliation remet la fenêtre de décision à 48 h pour le nouveau
nominateur, à l'ouverture du dossier ou au passage du cron. Le référentiel du
cron a été régénéré **uniquement pour POSTES_NOMMES_EXCLUSIFS_SERVEUR** par
`valeur_generee` du générateur existant ; les autres référentiels ne bougent pas.

La lecture publique préexistante du blob des candidatures n'est pas rendue
confidentielle par ce lot. Les contrôles retirent le pouvoir de gestion et de
décision, pas la visibilité de noms qui étaient déjà publics. Les écritures
sensibles sont contrôlées côté serveur, indépendamment des boutons.

## Passage de relais à ChatGPT

1. Relire la migration et vérifier ses prérequis et l'ancre du patch sur la
   définition actuelle de `batiment_etat_sous_cle_ecrire`. Faire une lecture des
   titulaires, candidatures et données financières avant application pour
   vérifier ensuite leur absence de mutation.
2. L'appliquer via `apply_migration`, en conservant sa trace dans le registre.
3. Relire et exécuter **en une seule transaction**
   `outils/bancs/banc-nominations-municipales.sql` avec le compte technique.
   Ce banc crée trois utilisateurs anonymes de test et leurs personnages,
   remplace temporairement les registres municipaux dans sa transaction et
   teste les vraies RPC sous identité `authenticated`, sans désactiver de
   trigger. Ne pas le découper et ne jamais remplacer sa fin par `COMMIT`.
   Le succès attendu est l'exception finale :
   `banc nominations : LES 155 EPREUVES SONT VERTES -- transaction annulee`.
   Elle annule tout le banc. Toute autre erreur est un échec à diagnostiquer.
   Ce résultat est **attendu, pas encore observé**.
4. Comparer les données métier avant/après migration : aucun poste ou dossier
   existant ne doit avoir été changé par l'application elle-même. Vérifier
   également l'idempotence de la migration en transaction annulée.
5. Réextraire le baseline selon `WORKFLOW-SUPABASE.md`, revoir les droits et le
   diff, puis archiver la migration appliquée. Mettre à jour les observations
   de `outils/baseline/referentiels.json` à partir des mesures réelles.
   L'empreinte cible du générateur `postes_nommes_regles` est
   `694f117ace57b0b1` (18 règles). Ne pas présenter cette valeur comme mesurée
   en base avant application. Les autres anciennes divergences restent hors lot.
6. Rejouer les contrôles ci-dessous, puis les essais authentifiés maire/adjoint
   dans le jeu. Confirmer le transfert en base avant de clore le chantier.

## Vérifications exécutées dans Codex

Depuis la racine du dépôt :

```sh
node --test outils/bancs/banc-nominations-municipales.cjs
PYTHONPATH=/workspace/onboarding-res-publica /workspace/.res-publica-venv/bin/python outils/bancs/lancer-banc.py outils/bancs/banc-candidatures-nocturnes.js
python3 outils/payload-vercel.py --garde
```

- **101/101 tests client** : configurations des mairies, trois dossiers dans les
  trois villes, candidats et postes vacants, nominations PJ/PNJ, confirmations,
  coûts, révocations PJ/PNJ, protection et refus de l'adjoint/du maire d'ailleurs.
  Le transport est simulé : ce ne sont pas des tests d'application en base.
- **32/32 épreuves du banc existant des candidatures nocturnes**, avec l'adaptateur
  Node Linux du lanceur historique JavaScriptCore. Les appels réseau sont simulés.
- Chromium : clics réels sur les trois dossiers et leur gestion des candidatures,
  en bureau et mobile, pour les trois villes ; menu non ouvert par l'adjoint ;
  aucune erreur JavaScript ni appel au serveur du jeu. Ce sont des tests du
  composant avec des données simulées, pas une session de jeu authentifiée.
- Syntaxe des fichiers JS et grammaires SQL/PLpgSQL de la migration, du patch
  composé sur le baseline et du banc, sans exécuter de SQL.
- Le contrôleur global reste à **8/12** : défaut préexistant de regex dans
  `verifier-workflow.py`, RPC `tracts_electoraux_distribuer_collectif` absente,
  divergences de référentiels et de fonctions économiques déjà connues. Le
  transfert ajoute une divergence **attendue tant que la migration est en
  attente** entre le référentiel client et les observations de la base ; elle
  ne doit être masquée ni présentée comme résolue.

Le baseline n'a pas été édité pour simuler une application qui n'a pas eu lieu.
