# Nominations municipales — application et contrôles

## État : migration appliquée ; baseline et validation en jeu en attente

Le code est sur `main`. ChatGPT a applique la migration via Supabase (registre
`20261015212703`) et execute le banc SQL : **155 epreuves vertes**, annulees
volontairement par l'exception finale. Les empreintes des postes attribues,
titulaires PNJ et candidatures etaient identiques avant et apres. Les tarifs et
les droits sur la fonction interne ont ete controles. Le baseline n'a pas encore
ete reextrait et les essais authentifies en jeu restent a effectuer.

Migration archivée : `historique/migrations-appliquees/20261015210718_nominations_municipales_au_maire.sql`.
Le changement serveur est applique : la règle d'entrepôt attribue maintenant
l'autorité au maire. Les essais authentifiés en jeu restent à confirmer.

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

## Suite après application : ne pas rejouer la migration

Les étapes d'application, le banc de 155 épreuves et la comparaison d'intégrité
ont déjà été validés par ChatGPT/Supabase le 15 octobre 2026, registre
`20261015212703`. La migration est archivée. Ne pas les recommencer sans nécessité.

Restent à effectuer par un agent disposant des accès techniques :

1. Les quatre exports complets et le contrôle global du catalogue, avec les
   requêtes **existantes** de `outils/baseline/requetes.py`.
2. Le rendu du baseline et des seeds, la revue objet par objet du diff et les
   mesures réelles de concordance. L'empreinte **locale cible** du référentiel
   des postes est `694f117ace57b0b1` (18 règles) ; elle ne constitue pas une
   nouvelle mesure Supabase. Ne pas remplacer une observation datée par cette
   valeur calculée hors base.
3. Les contrôles du workflow et les essais authentifiés de l'application,
   avec des comptes de test autorisés ou un environnement isolé. Aucun poste
   ni personnage de joueur réel ne doit être modifié pour ces essais.

La reprise détaillée est dans `REPRISE-BASELINE-20261015.md`. Le dernier bilan
Codex, les diagnostics et les accès manquants figurent dans
[`CLOTURE-NOMINATIONS-20261015.md`](CLOTURE-NOMINATIONS-20261015.md).

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
- Le contrôleur global termine après correction de la regex et reste à **8/12** :
  deux SQL hors workflow, RPC `tracts_electoraux_distribuer_collectif` absente du
  baseline, divergences de référentiels et de fonctions économiques. Le
  transfert laisse une divergence entre le référentiel client et les anciennes
  observations de la base, faute de réextraction après application ; elle ne
  doit être masquée ni présentée comme résolue.

La migration est appliquee, mais le baseline doit encore etre reextrait. Voir `outils/bancs/REPRISE-BASELINE-20261015.md`.
