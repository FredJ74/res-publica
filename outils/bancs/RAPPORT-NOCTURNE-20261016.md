# Rapport du matin — consolidation Human Gambit

16 octobre 2026, Europe/Paris. Dépôt `FredJ74/res-publica`, branche `main`.
Point de départ : `54aa6b73`, checkout propre ; continuité municipale `04317d6b`
et image corrigée présents. Aucun fichier utilisateur non commité à préserver.

**Résultat : consolidation locale réalisée et testée. La production et le
lancement ne sont pas certifiés.** Aucune connexion authentifiée réelle, aucun
SQL exécuté, aucune donnée persistante modifiée, aucune migration appliquée.
Le chantier baseline n'est pas rouvert : fichiers générés, observations et
empreintes restent intacts. Les deux contrôles transversaux rouges sont dits
comme tels, sans recalage d'un résultat attendu pour les faire passer.

## Corrections effectivement réalisées

| Défaut avéré | Correction et fichiers | Preuve locale |
|---|---|---|
| `applyCharToState` remplaçait 0 FR par 4 250 FR et les ressources à zéro par leurs valeurs initiales | `plateau-core.js` : repli seulement sur champ absent ; aucun montant initial changé | `banc-hydratation-personnage.cjs`, 7 tests sur les quatre empires prioritaires, rechargement simulé compris |
| Une panne du catalogue distant cachait aussi les articles embarqués de l'énigme | `plateau-enigme-portrait.js` : avertissement distinct, consultation des historiques maintenue | `banc-archives-musee.cjs`, ouverture des deux indices ; Chromium bureau/mobile |
| L'index client tronquait l'histoire à 1 000 parutions | `supabase.js` : pagination des seules métadonnées, tri stable date/id ; panne intermédiaire rendue comme panne | Même banc, catalogue de 1 001 éditions, seconde page refusée, filtres récents/anciens et échappement HTML ; 7 tests au total |
| L'achat PJ laissait le solde local inchangé ; la consommation appelait `chargerPersonnage`, absente du dépôt | `plateau-commerce-pj.js` : lecture minimale des valeurs serveur après succès ou rejeu, avant drainage ; aucune soustraction de prix ni addition de bonus locale | `banc-commerce-etat-client.cjs`, 11 tests : refus, panne, propriétaire de fiche, zéros, réponse tardive, changement de compte, absence de deuxième livraison |
| L'annuaire des députés inversait Port-Sainte-Marie et Montrouge et portait une liste locale de noms républiens | `plateau-politique.js` : réutilisation de `villeNom(pays,ville)` | `banc-annuaire-territoires.cjs`, 4 tests, noms des 12 villes |
| Un banc structurel exigeait encore exactement six canaux de dialogue après l'ajout municipal du septième | `banc-assemblee-hall.js` : vérifie la liste actuelle et son appel parallèle ; les six mémoires historiques restent exigées | Les 95 épreuves du banc passent ; endpoint municipal toujours couvert par ses 24 tests |

La lecture commerce est bornée au personnage et au pays, vérifie le propriétaire
contre la session et ignore les réponses devenues obsolètes. Une panne conserve
le dernier état local connu : elle ne fabrique ni solde ni effet. Une telle panne
ne permet donc pas de certifier l'affichage immédiatement après l'acte.
La lecture ne recharge pas l'inventaire, afin de préserver son circuit existant.
La RPC de consommation sur place elle-même reste à vérifier en base (voir plus bas).

## Prévention et préparation à la duplication

- `data.js` expose `ordresDeclaresDeLaPiece`, utilisé par
  `renderRoomActions` et `definitionOrdreDansPiece`. Gabarit, ajouts de bâtiment,
  ajouts de pièce et exclusions locales n'ont plus deux implémentations.
  Le registre dynamique, les coûts, les restrictions et les jets restent en place.
- `banc-ordres-territoires.cjs` confronte cette extraction au contrat antérieur
  sur **819 pièces / 3 063 ordres statiques**, dans les 12 villes déclarées.
  Il vérifie aussi les gardes correspondantes, les exclusions isolées et
  l'absence de mutation des données. Trois tests, sans RPC ni nouveau coefficient.
- `banc-consommation-inventaire.cjs` ajoute six tests des vrais handlers :
  un seul retrait en vol, refus sans perte d'inventaire, PA et fraîcheur issus
  du serveur, réponse ancienne sans intoxication inventée, reprise après refus.
  Cette tranche ajoute des preuves, sans modifier le comportement de consommation.
- `controler-client.py` rassemble les bancs historiques et Node. Le lanceur
  historique utilise JavaScriptCore ou l'adaptateur `shell-node.cjs` sur Linux.
  Les trois catalogues universitaires sont exécutés avec Node, leur vrai moteur.
  Logs, délais et codes de sortie sont conservés ; aucun SQL ne fait partie de
  cette commande. Instructions dans [README.md](README.md).
- `outils/inventorier-territoires.cjs` produit un inventaire depuis le vrai
  `data.js`, lisible ou JSON. Il recense gabarits, pièces, ordres statiques,
  casting, menus municipaux et références d'images locales absentes. Il ne
  déduit jamais une autorisation de la présence d'un personnage.

## Contrôles exécutés et limites

Commande de consolidation :

```bash
python3 outils/bancs/controler-client.py --rapport /tmp/human-gambit-bancs
node outils/inventorier-territoires.cjs --json
```

Résultats détaillés par banc :
[VERIFICATIONS-NOCTURNES-20261016.json](VERIFICATIONS-NOCTURNES-20261016.json).

- **62/62 bancs réussis** : 2 193 épreuves des bancs historiques et 166 tests
  rapportés par Node, dont les trois catalogues universitaires comptés chacun
  comme un fichier testé. Les nouvelles tranches comptent 38 tests Node.
- **90/90 contre-épreuves** existantes réussies : régressions réinjectées dans
  des copies temporaires, sans retoucher les sources de production.
- **Chromium local** : 18 dossiers de nomination, six menus (trois villes ×
  deux largeurs), refus de l'adjoint ; deux indices historiques ouverts avec
  catalogue indisponible sur bureau et mobile. Registres simulés et appels
  distants bloqués : ce ne sont pas des parcours authentifiés.
- **Syntaxe** : 93 fichiers JS/MJS/CJS analysés par Node, zéro erreur.
- **Payload Vercel** : 313,1 Mo, sous le plafond de 330 Mo, marge de 16,9 Mo.
- `git diff --check` : conforme.
- **Contrôle des fonctions : rouge**, un diagnostic préexistant de prix du
  Journal : 109 cas divergents contre 103 déclarés. Reproduit à l'identique sur
  une copie des sources `54aa6b73` : il n'est pas introduit par cette mission.
- **Contrôle des référentiels : rouge**, 29 diagnostics sur les empreintes et
  la preuve de l'artefact. Le générateur refuse notamment un ordre de 17
  ressources alors que le canon en compte 18. Les observations de base sont
  anciennes ; elles ne constituent pas une nouvelle mesure de Supabase.
- **38 bancs SQL non exécutés** ; aucun test authentifié réel. Aucun outil
  Supabase ni compte de test autorisé utilisable dans cette session.

## État des systèmes audités

| Système | Constat dans le code actuel | Limite ou suite |
|---|---|---|
| Mairies | Menu unique et trois dossiers dans les trois villes ; nomination/révocation passent par les circuits existants, gardés côté UI et dans les SQL archivés | La migration municipale est documentée comme appliquée sous `20261015212703`, mais pas relue en direct pendant cette mission |
| Continuité des PNJ | Luthécia utilise le résolveur partagé frais, sans mandat déduit du casting ; identité et identifiant de dialogue du maire conservés ; adjoint permanent déclaré une seule fois | Rôles et mémoire réels à vérifier avec comptes isolés ; Port-Sainte-Marie et Montrouge n'ont pas automatiquement reçu de nouveaux PNJ |
| Candidatures | Les tests municipaux couvrent les dossiers, restrictions territoriales, adjoint interdit et titulaires PJ/PNJ ; les règles existantes de protection sont conservées | Un test UI simulé ne prouve pas à lui seul le refus d'une RPC en production |
| PNJ sociaux/fonctionnels | Donner reste un choix argent/objet ; Voler conserve le choix explicite ; neutralisation générique refusée aux gamma, voie Assemblée distincte ; circuits relationnels toujours utilisés | Aucun badge relationnel générique « neutre/hostile/ami » trouvé dans le rendu courant ; les données `rel` et leurs effets ne sont pas supprimés |
| Commerce/inventaire | Achats via RPC et clé de requête ; livraison par le sas existant ; consommation d'aliment confirmée avant retrait/effet local ; lecture des soldes corrigée | Concurrence et RLS réelles non exercées ; certains mouvements de caisse/production appliquent encore des deltas au miroir local, à tester en multi-onglets avant extension |
| Premium | La vitrine commerce déclare l'option liée au fonds, transmise avec lui, perdue à résiliation ; boutons de paiement désactivés | Les Edge Functions de décoration/publicité sont appelées mais leurs sources ne sont pas dans ce dépôt : autorisations serveur et transfert réel non certifiés |
| Presse/musée | Filtres existants : 30 jours pour le récent, anciennes marquées PJ, historiques embarqués ; aucune purge ajoutée | `archives_tribune_index` est appelée mais absente du baseline disponible : confirmer la vue, ses droits et la rétention réelle via un accès Supabase |
| Ordres/permissions | Fusion statique unifiée ; registre dynamique et portes serveur conservés ; aucune chance de succès modifiée | Plusieurs ordres génériques restent calculés côté navigateur : leur migration requiert un audit métier transactionnel, pas un déplacement esthétique |

### Anomalies et dépendances encore ouvertes

1. **Concordance économique et schéma réel** : Journal encore fondé sur 16
   ressources, canon sur 18, 34 écarts de données relevés ; générateur à ordre
   fixé à 17. Les prix du Journal ne sont pas des prix de transaction. Ce
   chantier ne modifie pas les tarifs pour aligner un contrôle. Il faut
   reprendre cette dette avec le vrai catalogue et préserver les indices de
   ressources employés par les opérations économiques.
2. **Deux RPC littérales sans définition dans le baseline ni les migrations
   appliquées disponibles** : `consommer_sur_place_commerce` et
   `tracts_electoraux_distribuer_collectif`. Cela ne prouve pas leur absence de
   la base vivante. Vérifier existence, signatures, droits et idempotence avant
   de créer une migration ; ne pas inventer d'effets de consommation.
3. **Une image locale absente, deux usages à Novomirsk** :
   `images/bureau-gouv-sovarka.png`, bureau présidentiel et bureaux du
   gouvernement. Aucun remplacement approximatif ni génération effectués.
4. **Authentification, concurrence et données réelles** : disposer d'une session
   agent avec connecteur Supabase et comptes autorisés ou environnement isolé
   pour rejouer les parcours. Aucun poste ni personnage de joueur réel ne doit
   servir de fixture. L'agent doit effectuer ces opérations, pas le game designer.
5. **Arbitrages distincts des défauts techniques** : durée de conservation des
   éditions exclusivement PNJ si une purge est souhaitée ; règles détaillées
   des variations d'empire. La fenêtre d'affichage de 30 jours ne constitue pas
   une autorisation de supprimer des archives. Aucun de ces arbitrages n'est inventé.

## Réutilisation dans les autres villes

| Ville de Républia | Bâtiments | Pièces déclarées | Ordres statiques | Cartes PNJ déclarées | Menus Nominations |
|---|---:|---:|---:|---:|---:|
| Luthécia (`capitale`) | 36 | 140 | 458 | 107 | 1 |
| Port-Sainte-Marie (`ville_a`) | 31 | 84 | 216 | 61 | 1 |
| Montrouge (`ville_b`) | 35 | 82 | 320 | 44 | 1 |

Ces comptes décrivent le contenu déclaré, pas un volume de fonctionnalités
certifiées. Les trois villes n'ont aucune référence d'image locale absente
dans cet inventaire. Aucun gabarit de bâtiment référencé n'est manquant dans
les douze villes inspectées. Les ordres dynamiques ne sont pas comptés.

Réutilisables immédiatement : `villeNom`/`villesDe`, conventions de caisse,
gabarits `BUILDINGS`, fusion des ordres, menus et dossiers municipaux,
résolveur `lireTitulaireMunicipal(poste,pays,ville,lire)`, rails de transport et
de verdict RPC, transactions de commerce, sas d'inventaire et bancs communs.
Les tests portent déjà sur les trois villes, sans ajouter de données en base.

Adaptations locales encore nécessaires : casting permanent et profils de
dialogue, biographies, visuels, spécialités et implantations. Les profils de
continuité serveur restent délibérément limités à Luthécia ; les étendre doit
déclarer pays/ville/profil, pas copier les handlers. Les spécificités existantes
(logements sociaux de Montrouge, port de Port-Sainte-Marie, institutions et
énigme de Luthécia) restent locales, sans être normalisées de force.

## Variations d'empire : points d'extension

Socle existant : `VILLES`, `WORLD[pays][ville].buildingContext`,
`roomOverrides.orders/excludeOrders`, `requiresPost/requiresRole`,
`RP_ORDRES_DYNAMIQUES`, dispatch `doOrder` et moteurs/portes RPC. Les référentiels
serveur sont générés depuis les données et doivent rester surveillés.

La fusion partagée constitue la première préparation concrète : la déclaration
locale et la garde voient désormais les mêmes ordres. Aucune règle nouvelle
n'a été activée dans Sovarka, El Estado ou Al-Khalija.

Pour une évolution ultérieure, séparer l'intention d'ordre, sa règle déjà validée
par empire et son moteur. La porte serveur doit résoudre pays, ville, titulaire
et présence depuis l'état réel ; le client peut afficher la règle, pas imposer
le coefficient. Déclarer seulement les variations arbitrées (disponibilité,
conditions, jet, conséquence), puis les éprouver en conservant les résultats
actuels comme référence. Ne pas recopier `doOrder` par empire.

À différer : refonte générale du routeur, migration de tous les jets vers SQL,
castes et nouveaux coefficients criminels. Risques : prix/pouvoirs divergents,
double paiement, ordre affiché sans porte correspondante, biais des jets. Les
3 063 déclarations actuelles ont été préservées, pas « rééquilibrées ».

## Performance

Pas de script chargé deux fois trouvé dans les pages HTML racine. Les plus
grosses images sont notamment des cartes postales PNG (jusqu'à 3,48 Mo) et
des stades : constat de poids, sans réencodage automatique ni promesse de gain
visuel nul. Aucune nouvelle dépendance applicative, aucun timer ajouté.
La relecture commerce ne transfère que six champs ; la pagination presse ne
charge ni contenu d'édition ni images. La documentation et les bancs sont
exclus du payload de production par les règles existantes.

## Commits de correction

- `f2d1ed78` — ressources à zéro au chargement.
- `9ff487d5` — indices du musée et pagination des archives.
- `f08dc64e` — actualisation du personnage après achat/consommation.
- `062b92ce` — fusion partagée des ordres et noms territoriaux.
- `83354898` — lanceur portable et banc de dialogue actualisé.

Le commit portant ce rapport ajoute l'inventaire, les six tests d'inventaire
et le relevé de vérification. L'état de publication est communiqué avec le
SHA final après vérification du push sur `main`.

## Les cinq prochaines priorités

1. **Obtenir la preuve de bout en bout sur environnement isolé** : maires,
   adjoints, candidats et clients de commerce ; prérequis : accès agent et
   comptes de test. C'est le verrou principal pour considérer Républia fiable.
2. **Résoudre les dépendances serveur manquantes ou non archivées** : deux RPC,
   vue d'archives et Edge Functions premium ; dépend de l'accès au vrai catalogue.
   Archiver les définitions réelles avant de proposer un changement.
3. **Remettre d'accord les référentiels économiques** en préservant tarifs et
   indices réels ; dépend de l'état serveur confirmé. Aucun lancement avec un
   contrôle rouge ignoré ou une empreinte recopiée pour le faire taire.
4. **Achever Port-Sainte-Marie et Montrouge par configuration** : casting,
   continuité, profils et parcours locaux, à partir des rails déjà testés ;
   éviter les copies de logique et maintenir leurs spécificités.
5. **Préparer la première tranche des trois empires suivants** : traiter les
   ressources graphiques manquantes et n'activer que les variations arbitrées,
   avec une matrice de tests par ordre/empire et une porte serveur correspondante.

**Aucune dette détectée n'est présentée comme résolue par les seuls tests locaux.**
