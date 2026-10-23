# Construction #94 : reprise isolee du depot de permis

## Portee et etat reel

Branche `codex/construction-permis-94-20261023`, extraite de `main` `0bfca65`.
La branche generale `codex/finalisation-construction-coffres-20261022` n'a pas ete fusionnee.
Aucun fichier de coffres, successions, commerces ou vente immobiliere n'a ete repris.
**Chantier global non termine. Cette branche n'est pas autorisee au deploiement.**

## Correction implementee

Le depot client faisait quatre operations distinctes (archive, document, paiement, terrain).
La nouvelle commande `terrain_permis_deposer(text,text,uuid)` reunit ces effets dans
une seule transaction en reutilisant `payer_ordre`, `terrain_etat_fusionner_interne`
et `objet_sas_deposer`. L'identite vient de la session serveur. Un proprietaire PJ
(chaine historique ou reference `pj:`) ou le titulaire d'un compromis non expire peut
deposer. Aucune expiration absente n'est inventee. Pays et ville sont verifies ;
la cle de terrain canonique evite de choisir un homonyme dans un autre pays.
Superficie, prix et autres attributs persistants ne sont jamais recalcules.

Le cout est 1 PA / 100 FR. Les quatre instructions durent 2/4/6/7 jours ; le plan
initial n'est pas demande au depot. Le serveur refuse un permis existant, un terrain
construit, un chantier en cours, un gel ou la carence de trois jours apres refus.

Le justificatif rejoint le SAS documentaire historique. Le registre prive des recus
atteste une commande achevee ; une archive seule ne constitue pas cette preuve.
Un rejeu ne paie ni ne livre de nouveau et renvoie les soldes courants. Une autre
intention utilisant la meme reference est refusee. Le role client ne peut ecrire
ni ce registre ni la capacite transactionnelle du payeur.

L'ancien depot `terrain_permis_acte(...,'permis_deposer',...)` et son paiement separe
sont refuses. Un ancien navigateur ne doit donc pas payer avant d'apprendre que
son circuit n'est plus accepte. Les autres actes et paiements conservent leur moteur.

Le navigateur conserve l'UUID avant envoi, empeche les doubles clics, garde la
reference apres reponse perdue et ignore une reponse concernant un autre personnage.
Aucun debit ni remboursement local. Les versions des deux scripts modifies sont
actualisees dans le plateau.

## Tests executes

- PostgreSQL jetable : **56 assertions**. Fonctions archivees reelles de paiement,
  terrain, titulaire et SAS documentaire. Identite et calendrier simules.
  Succes, compromis expire/etranger/incomplet, juridiction, gel, permis existant,
  carence, manque de PA/fonds, complement bancaire, reprise, concurrence,
  archive fabriquee, droits, rollback apres panne SAS et definitions inconnues.
- **8 scenarios client** sur la fonction effectivement chargee depuis le fichier source.
- Controleur client : **92/92 bancs**.
- Contre-epreuves : **91/91**, dont une nouvelle reintroduisant le paiement client
  avant le depot atomique. L'ancien controle de routage compte toujours 22 mutations :
  le depot change de porte, il ne disparait pas de la couverture.
- **15/15 bancs PostgreSQL locaux** declares dans le workflow ont ete executes.
  Resultats machine : `/tmp/hg94-validation-pg/postgres-integre.json` dans cette session.

Les 11 tests Node du calendrier/placements et les 23 analyses de syntaxe API passent aussi ; syntaxe SQL et garde de payload verifiees.

Ces tests ne constituent ni une authentification Supabase reelle, ni une visite du jeu.
Le transport navigateur a ete simule dans les huit scenarios client.

## Prevol et limites

Migration **preparee uniquement** :
`migrations/20261022220516_permis_depot_transactionnel.sql`.
Elle refuse un corps inconnu de `payer_ordre`, `terrain_permis_acte` ou du nouveau
point d'entree deja installe. Les empreintes portent uniquement sur les definitions
examinees de cette migration, sans changer une observation du baseline.
La version enregistree ne doit etre appliquee qu'apres comparaison du catalogue vivant.
Des versions de realites/construction deja installees pourraient legitimement faire
arreter ces gardes : il faut examiner leurs definitions, jamais ajouter aveuglement
leur empreinte a une liste blanche.

Lecture seule preparee : `outils/bancs/prevol-construction-permis.sql` (definitions,
privileges, colonnes, triggers, policies, cout et agregats d'anomalies historiques).
Le prevol doit notamment confirmer la confidentialite des tables internes et les
protections contre les anciennes sauvegardes, les triggers financiers/inventaire,
les droits du SAS et l'ordre des migrations deja appliquees.

Acces reel retente le 22 octobre a 22:11 UTC : refus du tunnel CONNECT **HTTP 403**
avant Supabase. Aucun connecteur Supabase n'est expose. Aucune migration appliquee,
aucune donnee de joueur modifiee. Creation de PR tentee avec `gh pr create` :
`Post https://api.github.com/graphql: Forbidden`. Le push Git fonctionne.

## Controles globaux et travaux encore necessaires

Les douze controles ont ete executes : **9/12**. Aucun baseline ni resultat ajuste.

- Workflow : un SQL bancaire preexistant est range dans `outils/migrations/`
  (`20261022_placement_national_idempotent.sql`). La correction de rangement existe
  dans la consolidation, mais n'a pas ete embarquee dans ce lot de permis.
- Authority : RPC recentes absentes de la photographie historique ; certaines
  declarations sont preparees mais leur installation vivante reste a verifier.
- Referential : trois derives historiques (`ordres_couts`, `postes_nommes_regles`,
  `miroirs_entreprises`). La modification validee du cout du permis doit elle aussi
  etre confrontee au catalogue vivant, sans falsifier les mesures anciennes.

Restent a terminer separement, avant toute cloture #94 : decisions de permis et
accord tacite entierement transactionnels (le cron actuel travaille encore sur des
copies), occupation serveur stable et combat commun des squatteurs, reamenagement
et fermeture des portes legacy de lots, raccordement complet du financement #65,
validation integree des commandes/echances/reception preparees dans l'autre branche,
et leurs autorites organisationnelles et municipales. Le depot de cette branche
est pour un demandeur PJ : il ne pretend pas terminer le depot institutionnel.
Ces travaux locaux inacheves sont distincts du blocage d'acces au prevol/deploiement.

Aucune fusion et aucun deploiement. Aucun test sur un joueur reel.
