# Bilan de clôture des nominations municipales — 15 octobre 2026

**CHANTIER NON TERMINÉ.** La réextraction du baseline et les essais authentifiés
restent bloqués par les accès de la session Codex. Le ticket #1 doit rester ouvert.
Ce constat ne remet pas en cause les validations déjà effectuées via ChatGPT.

## Sources et acquis conservés

Dépôt remis à jour sur `main`, point de départ `9b383b46`. Les consignes de
`WORKFLOW-SUPABASE.md`, `REPRISE-BASELINE-20261015.md`,
`NOMINATIONS-MUNICIPALES.md` et `outils/baseline/README.md` ont été lues.
Le ticket [#1](https://github.com/FredJ74/res-publica/issues/1) a été lu sur sa
page GitHub publique : la clôture exige un baseline aligné, des contrôles
réussis ou des exceptions justifiées, et un parcours réellement authentifié.

Acquis rapportés par ChatGPT/Supabase et conservés sans les rejouer :

- migration appliquée et enregistrée sous `20261015212703` ;
- archive dans `historique/migrations-appliquees/` ;
- 155 épreuves SQL vertes, transactions annulées ;
- empreintes des données métier inchangées.

Aucune migration, aucune création de compte et aucune écriture sur la base du
jeu n'ont été effectuées pendant cette tentative de clôture. Aucun poste ou
personnage de joueur réel n'a été modifié.

## Correction effectuée

`outils/baseline/verifier-workflow.py` plantait sous Python 3.12 : sa regex des
blocs `DO` répétait des indicateurs globaux après une alternative. La regex
utilise maintenant un groupe d'alternatives et les flags explicites `re.M | re.I`.
Les tags nommés, anonymes et la casse restent reconnus ; les faux positifs ont
été vérifiés. Aucune assertion n'a été retirée ou affaiblie.

Le contrôleur peut maintenant aller jusqu'à son verdict et expose deux fichiers
SQL hors des répertoires canoniques. Il reste rouge sur ce diagnostic réel.
Les anciennes consignes proposant de réappliquer la migration municipale ont
été remplacées par les seules étapes encore nécessaires.

## Résultats observés dans cette session

| Vérification | Résultat |
|---|---|
| Tests client municipaux (`node --test outils/bancs/banc-nominations-municipales.cjs`) | 101/101 réussis |
| Banc existant des candidatures nocturnes | 32/32 réussis |
| Garde du payload Vercel | Réussie, 313,0 Mo sous 330 Mo |
| Reconnaissance des blocs DO après correction | Tags nommés/anonymes, minuscules et faux positifs vérifiés |
| Grammaire des quatre requêtes d'export et du contrôle global | Cinq SELECT valides, non exécutés |
| Nouveaux tests authentifiés de l'application | **0 exécuté** |
| Nouvelles mesures Supabase / exports / génération du baseline et des seeds | **Non effectués** |

Les tests client couvrent les trois dossiers dans Luthécia, Port-Sainte-Marie et
Montrouge, les postes vacants, les titulaires PJ/PNJ, les coûts des nominations
et révocations, les candidatures, la protection et les refus de l'adjoint et du
maire hors territoire. Le transport y est simulé. Le banc du cron utilise
également des réponses simulées et l'adaptateur Node Linux du lanceur historique
JavaScriptCore. Aucun de ces deux résultats n'est un essai authentifié en jeu.
Le test client confirme la concordance **locale** du référentiel municipal
`data.js` avec l'artefact serveur généré ; aucune concordance actuelle avec la
base réelle n'est revendiquée.

### Contrôleur global : 8 réussites, 4 échecs sur 12

La commande documentée comme « onze contrôles » en lance aujourd'hui **douze**,
y compris le contrôle des faits publics. Tous ont été exécutés et terminés :

| Contrôle | Résultat |
|---|---|
| Processus / workflow | Échec : deux SQL hors des répertoires admis |
| Classification | Réussi sur les fichiers présents |
| Fidélité du baseline au catalogue enregistré | Réussi sur l'ancien instantané, **pas sur la base actuelle** |
| Autorité | Échec : RPC de tractage absente du baseline |
| Référentiels | Échec : observations anciennes et génération économique incomplète |
| Faits publics / Journal | Réussi |
| Fonctions recopiées | Échec : prix des ressources du Journal |
| Monde neuf | Réussi |
| Assemblage | Réussi |
| Reconstruction | Réussie : grammaire PostgreSQL et simulation, pas application sur base neuve |
| Pilote communication | Réussi |
| Archive historique du registre | Réussi sur l'archive versionnée, pas comparaison avec le registre courant |

Aucune sortie ne déclare la suite verte et aucune valeur d'empreinte, observation
de la base ou attente de test n'a été modifiée pour faire disparaître un échec.

## Qualification des diagnostics restants

- **SQL hors workflow, préexistants** :
  `sql/catalogue_pnj_statiques_republia_20261014.sql` et
  `sql/tractage_collectif_stade_20261014.sql`. Le premier contient des données
  du catalogue PNJ électoral ; le second trois fonctions de tractage collectif.
  Le contrôleur rapporte trois anomalies : leur total hors répertoires, puis
  chacun des deux chemins. Leur application et leur correspondance au registre
  ne peuvent pas être établies ici ; les déplacer arbitrairement dans les
  migrations appliquées inventerait cette correspondance. Ils restent intacts.
- **RPC `tracts_electoraux_distribuer_collectif`, préexistante et hors nominations** :
  appelée dans `supabase.js:4276`, absente du baseline actuel. Sa source est
  versionnée dans le second SQL ci-dessus. Sans catalogue actuel, impossible de
  décider si c'est uniquement un retard du baseline ou un problème d'application.
- **Référentiel municipal, lié au chantier et bloquant pour la clôture** :
  le générateur local calcule `694f117ace57b0b1` ; l'observation versionnée dans
  `outils/baseline/referentiels.json` reste `6c0c7aa0d29bf852`. Ce dernier nombre
  est une ancienne observation, pas une preuve que la migration aurait échoué.
  Seule une nouvelle lecture Supabase permet de le remplacer correctement.
- **Coûts et référentiels économiques** : le générateur local des coûts donne
  `79ecb2f9d4bf71f5` face à l'ancienne observation `20e52d8f9bbe8e3f`.
  Les anciennes divergences de sentinelles restent présentes. Le générateur de
  `RESSOURCES_ECONOMIE_SERVEUR` refuse un ordre de 17 clés face à 18 clés actuelles.
  La génération complète de l'artefact ne peut donc pas être certifiée. Ne pas
  modifier les ressources pour faire passer le contrôle municipal ; ces écarts
  demandent des mesures réelles et, pour les règles économiques, une analyse
  séparée. Le référentiel municipal client/serveur concorde localement.
- **Fonction de prix du Journal, hors nominations** :
  `economie/prix-ressource-journal` présente 109 cas divergents contre 103
  déclarés. Aucun nombre attendu n'a été relevé artificiellement. Cela ne prouve
  pas une régression municipale ; ce diagnostic doit rester visible et qualifié
  avant une éventuelle exception de clôture.

Les écarts économiques et de tractage ne justifient pas d'ouvrir un autre
chantier ici. Le retard du baseline et l'absence de parcours authentifié sont,
eux, des critères municipaux de clôture non satisfaits.

## Accès effectivement vérifiés et manquants

- Git HTTPS vers le dépôt : lecture fonctionnelle ; écriture vérifiée lors du push.
- Page web publique du ticket #1 : HTTP 200, contenu lu.
- API GitHub : échec du tunnel proxy en HTTP 403 pour `api.github.com`, en REST
  comme via `gh`, malgré la présence d'un binding `GH_TOKEN` et une permission
  réseau accordée. Aucune valeur de credential n'a été affichée. Ce refus
  intervient avant le traitement de la requête API ; il ne prouve pas que le
  binding GitHub est invalide. La mise à jour du ticket via l'API reste bloquée.
- Aucun outil Supabase SQL / `execute_sql` n'est exposé dans cette session.
- La lecture REST de la règle du directeur d'entrepôt sur
  `jxpwoosmmhohoihxpbuc.supabase.co` a également été bloquée au tunnel proxy
  (HTTP 403), avant toute réponse de Supabase.
- Aucun binding de base de données ni de comptes de test maire/adjoint n'est
  disponible dans les variables de cette machine ; aucun export complet récent
  n'a été trouvé dans l'espace de travail, y compris les fichiers cachés.

Pour finir, l'agent doit disposer du canal de lecture des catalogues Supabase,
d'une route réseau autorisée vers ce projet, de sessions de test municipales
provisionnées dans un environnement isolé (avec nettoyage possible), et d'un
accès API GitHub utilisable. Il ne s'agit pas de demander des clés en chat ou de
faire exécuter des commandes au game designer.

## Suite à réaliser par l'agent équipé

1. Extraire les quatre ensembles complets avec les requêtes existantes ; relever
   également le contrôle global et le registre courant, sans rejouer la migration.
2. Régénérer par `rendre.py` et `seeds.py`, examiner chaque changement, compléter
   la classification uniquement d'après les objets effectivement extraits et
   mesurer les référentiels réels. Ne pas fabriquer de fichiers d'export locaux
   à partir du seul SQL archivé.
3. Exécuter les vrais parcours authentifiés avec les comptes de test pour les
   trois villes ; conserver les preuves sans tokens et nettoyer les fixtures.
4. Relancer les contrôles, mettre à jour le ticket et ne le fermer que si ses
   critères sont remplis. Le présent bilan ne constitue pas cette clôture.
