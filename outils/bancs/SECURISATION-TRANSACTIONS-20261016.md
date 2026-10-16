# Sécurisation Supabase et transactions critiques — 16 octobre 2026

> Suite : [réception atomique préparée](RECEPTION-ATOMIQUE-20261016.md).
> La mission suivante indique que la migration d'achat a été appliquée et vérifiée
> en production par le canal externe. Elle n'est pas rejouée. Le bilan ci-dessous
> décrit la session antérieure ; la nouvelle migration de réception reste non appliquée.

**CHANTIER NON TERMINÉ en production.** Départ : `3065b20b` sur `main`, après
récupération du distant. La correction du maire PNJ est incluse et préservée.
Aucun connecteur Supabase ni variable d'accès Supabase n'est disponible dans
cette session. Aucun compte autorisé de test authentifié n'est disponible.
Aucune migration appliquée, aucune donnée joueur utilisée ou modifiée.

Les vérifications locales sont enregistrées dans
[VERIFICATIONS-SECURISATION-20261016.json](VERIFICATIONS-SECURISATION-20261016.json).
L'[audit précédent](AUDIT-COHERENCE-SERVEUR-CLIENT-20261016.md) reste historique ;
ce document actualise le statut de sa migration et les corrections ci-dessous.
Aucun prix, stock initial, coefficient, taxe, probabilité ou effet métier changé.

## 1. Achat : réconciliation préparée, application bloquée

Le propriétaire transmet une observation Supabase : MD5 du corps
`19a5c3c718d4109b98fe94a8eb5ebf30`, livraisons avant débit, présence notamment de
`familleProduitMarche` et `dateAchat`. **Cette observation n'a pas été refaite
par cette session et le corps complet n'a pas été fourni.** La liste exhaustive
des différences, les ACL et les dépendances réelles restent donc à établir.

La migration en attente
[`20261016070541_achat_commerce_debit_avant_livraison.sql`](../../migrations/20261016070541_achat_commerce_debit_avant_livraison.sql)
a été révisée, puisqu'elle n'a jamais été appliquée. Elle ne contient plus de
`CREATE OR REPLACE` avec un ancien corps recopié. Elle :

- lit `prosrc` et `pg_get_functiondef` de la signature exacte ;
- reconnaît le corps archivé testé et l'empreinte réelle **transmise** ;
- exige une occurrence exacte du bloc de débit et de l'ancre de livraison ;
- déplace uniquement le bloc, en laissant une trace réversible à son ancien emplacement ;
- démontre la réversibilité octet pour octet du reste du corps ;
- réutilise la définition installée, donc conserve paramètres, attributs, champs alimentaires,
  autorité, prix, taxes, stocks et identifiants, sans rétablir une ancienne version ;
- vérifie corps installé, OID, propriétaire et ACL après transformation ;
- ne reconnaît un rejeu que si la transformation inverse retrouve une empreinte autorisée.

Si le bloc ou l'ancre diffèrent dans la version réelle, elle **s'arrête** : aucune
adaptation devinée. Le hash de l'archive est conservé pour éprouver cette même
migration localement. Aucun hash de données, observation ou contrôle n'est ajusté.

**Cette préparation n'est pas un feu vert d'application.** L'agent disposant du
connecteur doit d'abord lire et comparer intégralement le vrai corps, les droits,
la signature et les dépendances avec les requêtes de
[`banc-dependances-coherence-lecture.sql`](banc-dependances-coherence-lecture.sql).
Il doit aussi examiner les chaînes de verrouillage/débit réelles. Si les
préconditions sont satisfaites : empreintes métier avant/après selon
`WORKFLOW-SUPABASE.md`, application MCP enregistrée, contrôle du registre et de
la définition, puis réextraction réglementaire. Aucun achat de joueur réel comme test.
Cette session n'a ni inscrit ni observé de version Supabase pour ce correctif.

## 2. Preuves PostgreSQL locales et limites

`banc-achat-commerce-local.py --local-jetable` charge le corps **archivé**, puis
le vrai fichier de migration, dans un moteur isolé ne recevant aucune URL externe.
Services d'acteur, présence, fiscalité, coût et fiche officielle : fixtures.
Le débit de fixture verrouille réellement le compte ; deux connexions distinctes
sont utilisées pour les concurrences.

Douze groupes de scénarios passent :

1. Défaut archivé reproduit : débit refusé mais livraison créée.
2. Migration compilée et rejouée ; ACL explicites, propriétaire, configuration et signature conservés.
3. Refus du débit sans objet, vente, débit effectif ou changement de stock.
4. Achat puis rejeu : une livraison, une vente et un débit.
5. Verdict nominal, objets et fonds identiques avant/après, hors séquence technique `venteId`.
6. Exception après débit : rollback de tous les effets transactionnels.
7. Deux commerces, un solde commun : une seule vente finançable.
8. Même requête concurrente : une livraison, vente, décrément et débit ; le perdant
   reçoit soit le rejeu, soit l'erreur UNIQUE historique avec rollback complet.
9. Stock décrémenté et ventilation fiscale de fixture conservée.
10. Refus du helper d'autorité de fixture sans livraison.
11. Variante **synthétique** avec métadonnées alimentaires : conservation des champs.
12. Corps inconnu refusé, y compris la variante alimentaire par la migration de production.

Pour éprouver la transformation de la variante synthétique, son hash est ajouté
**uniquement à une copie SQL en mémoire dans le test**. Il n'est pas inscrit dans
la migration du dépôt et ne prétend pas être une observation Supabase. Cela
prouve le mécanisme de conservation, **pas l'exécution de la fonction réelle**.
Le test d'autorité de fixture ne prouve ni `auth.uid()`, ni les RLS Supabase.

## 3. Réception des objets : protections corrigées, atomicité encore ouverte

Circuit reconstitué : producteurs achat/don/vol/document → `objets_recus` →
`sbGetObjetsRecus` → `verifierObjetsRecus` → réclamation puis ajout local →
sauvegarde ultérieure de l'inventaire. Les dons `don-tracts-*` passent par
`tracts_reclamer_don`, lui aussi suppressif dans le baseline. La surcharge
accepte les réceptions automatiques au-delà du plafond. Les cartes postales ne
révèlent leur contenu qu'à la lecture. Les tracts fusionnent par cible/type/légalité
avec `quantite`, les objets empilables par `stackKey` avec `qty`.

Défauts reproduits et corrigés :

- `sbDelete` rendait `true` pour un DELETE réussi même sans ligne supprimée :
  cela ne constituait pas une réclamation exclusive. Le helper de réception utilise
  maintenant le verdict avec représentation, exige exactement la ligne attendue,
  et filtre également son destinataire capturé.
- Après un changement de personnage, compte ou session, une ancienne lecture
  pouvait réclamer et ajouter des objets au nouveau personnage. Les retours sont
  gardés avant toute réclamation et après chaque attente.
- Deux polls du même acteur pouvaient se chevaucher dans le même onglet : verrou
  en cours, libéré en `finally`. Le test de deux onglets exige une seule ligne retournée.

Onze tests simulés couvrent aussi refus, reprise après panne, don de tracts tardif,
réception nominale et confidentialité des cartes. Aucun objet en attente purgé.

**La suppression et la sauvegarde de l'inventaire ne sont toujours pas atomiques.**
Une fermeture après suppression peut perdre un objet, y compris un don de tracts.
Si l'identité change après une réclamation confirmée, l'objet n'est pas injecté
chez le nouveau personnage, mais la récupération de l'ancien reste à traiter.
Le repli sans `recevoirObjetAutomatique` reste lui aussi non atomique.

### Contrat de réparation serveur préparé, sans implantation aveugle

Le catalogue à recueillir, sans donnée joueur, est dans
[`banc-reception-contrat-lecture.sql`](banc-reception-contrat-lecture.sql) : types,
contraintes, triggers, policies, droits, inventaire et fonctions de garde/fusion.
Le baseline disponible ne suffit pas à confirmer leur état réel.

La future porte doit vérifier l'acteur, verrouiller la vraie ligne de personnage
puis la livraison dans un ordre commun aux autres écrivains, décoder le format
réel de `data`, fusionner l'objet complet selon les règles existantes, persister
l'inventaire et supprimer la livraison **dans la même transaction**. Un échec
annule tout ; deux réclamations ne livrent qu'une fois. Une répétition après perte
de réponse relit l'inventaire autoritaire, sans delta local ni seconde livraison.
Il faut confirmer le contrat des identifiants et l'éventuel reçu durable.

`inventaire_ajouter` archivé n'est pas réutilisable aveuglément : ses quatre
paramètres ne portent pas toutes les métadonnées d'un objet nouvellement créé.
Les variantes de tracts et les objets individualisés nécessitent des preuves de
parité. Aucun nouveau format d'inventaire ou système de fusion n'est inventé ici.

Enfin, les sauvegardes complètes legacy doivent être empêchées d'écraser ensuite
l'inventaire serveur : contrôle de révision sous verrou sur la vraie table et
coordination de tous les écrivains. Une simple sauvegarde client avant RPC ou
une relecture après RPC ne garantit pas cela. La bascule client et la migration
atomique attendent ce contrat réel. Interruption avant/après commit, deux onglets,
répétition, inventaire plein, tracts, nourriture et métadonnées seront à tester
ensemble sur cette implémentation ; ils ne sont pas annoncés comme déjà validés.

## 4. Autres risques prioritaires : corrections ciblées et dépendances

| Sujet | Correction locale prouvée | Ce qui reste ouvert |
|---|---|---|
| Sauvegardes concurrentes | Ancien snapshot ou confirmation écarté après réhydratation du même nom de personnage : garde de l'objet personnage, pas seulement du nom. Deux nouveaux tests rouges avant correction, verts après. | CAS serveur universel et révision de tous les écrivains ; inventaire/argent/organisations encore exposés aux snapshots complets. |
| Réponse réseau perdue | Assemblée : aucun rejeu sous une nouvelle identité après une réponse perdue, ni commande après une sauvegarde ayant traversé un changement d'acteur. Message indisponible corrigé : ne prétend plus « rien débité ». Même clé conservée pour le rejeu existant. | Intention durable et reçu pour chaque acte ; nouvelles clés lors d'une nouvelle tentative commerce/caisse. L'idempotence de chaque porte réelle reste à vérifier. |
| Caisses et organisations | Panne ou ligne JSON invalide ne devient plus `[]`. Chargements de liste liés au personnage/compte/session et à leur version. Dernière lecture valide conservée ; vrai vide accepté. Sept tests, dont six rouges initialement. | `sbSaveOrganisation` remplace toujours un JSON entier ; les mouvements doivent être fusionnés côté serveur, selon les droits réels. Aucun merge financier client ajouté. |
| Actes économiques legacy | Analyse des demandes de naturalisation/domicile et des circuits de sauvegarde conservée dans l'audit de référence. | Pas de substitution par un débit suivi d'un effet local : la réparation transactionnelle dépend du schéma et des portes réels. |
| Retours asynchrones | Soins public/privé : garde après coût et RPC ; repos : après repos, solde, salaire, indemnité, libération et sauvegarde ; chambre : après repos et bonus. Justice : garde de l'acteur et de la détention. Politique : retour d'attribution PNJ. Militaire : lectures ordonnées et retours manger/dormir/rejoindre gardés. Assemblée : wrapper et indemnité. | Pas de certification globale de tous les handlers. Les effets locaux du repos et les actes à plusieurs RPC ne deviennent pas atomiques par une garde de retour. |

Les 23 tests de retours acteur incluent refus d'appliquer au nouveau personnage,
compte ou jeton, succès normal des soins, valeurs zéro, rejeu de même clé,
changement pendant sauvegarde, autre détention et ordre inversé des lectures militaires.
Les 16 premiers tests reproduisaient le défaut avant correction. Les règles de soin,
repos, candidature, libération et effets militaires n'ont pas été réécrites.

## 5. Dépendances réelles : non vérifiées dans cette session

Les requêtes de catalogue préparent les signatures, corps, MD5, ACL et droits
anon/authenticated de `consommer_sur_place_commerce`,
`tracts_electoraux_distribuer_collectif` et de l'achat, ainsi que la définition et
les droits de `archives_tribune_index`. **Aucune de ces lectures n'a été exécutée
sur Supabase.** Aucune fonction recréée au motif qu'elle manque dans le dépôt.

La photographie de tractage existe dans `historique/sql-hors-registre`, mais
n'atteste ni sa version vivante ni son inscription au registre. Les sources et
l'inventaire déployé des Edge Functions premium ne sont pas disponibles : pas de
validation de leurs autorisations. Aucun secret demandé ou imprimé.

## 6. Contrôles et statut de clôture

- **68/68 bancs clients passent**, transports simulés : 2 193 épreuves historiques
  et 252 tests Node, dont 43 nouveaux cas dans cette mission.
- **90/90 contre-épreuves passent.**
- **12 groupes PostgreSQL locaux passent**, avec les limitations de fixtures ci-dessus.
- Syntaxe Node : **84 fichiers** racine/API, zéro erreur ; trois SQL analysés par
  `pglast`, migration compilée sur PostgreSQL local ; `git diff --check` conforme.
- Garde de payload Vercel conforme. Aucun fichier du baseline modifié ou régénéré.
- Le lanceur global exécute **12 contrôles** malgré son ancienne désignation « onze » :
  **9 passent, 3 échouent**. Linux utilise l'adaptateur Node existant pour les chemins
  JavaScriptCore macOS et le venv déjà installé pour `pglast` ; aucun seuil changé.

Échecs conservés :

1. Autorité, invariant 13 : `tracts_electoraux_distribuer_collectif` appelé dans le
   client mais absent du baseline. Cet appel et son absence préexistent ; aucun
   nouveau RPC ni changement de baseline dans cette mission. Cela ne démontre pas
   son absence en production. La vérification réelle reste requise.
2. Référentiels : empreintes/moteur de génération déjà en écart, dont ordre de
   17 ressources contre 18, laitages absent. Aucun artefact régénéré pour masquer cela.
3. Fonctions : prix-ressource Journal, **109 cas divergents contre 103 déclarés**,
   écart déjà documenté. Aucune référence ni valeur économique ajustée.

Le « baseline fidèle » vert atteste sa cohérence avec ses exports enregistrés,
**pas avec la base réelle actuelle**. Pas de synchronisation Supabase prétendue.

Lectures réelles Supabase : **aucune**. Migrations appliquées : **aucune**.
Parcours authentifiés réels : **aucun**. Résultat GitHub Actions distant : non observé.
Les comptes/personnages réels n'ont pas servi de fixtures. Les scripts locaux et
les requêtes préparées sont destinés aux agents, aucune manipulation technique
n'est demandée au game designer.

Aucun arbitrage de gameplay nécessaire pour les correctifs livrés. La clarification
éditoriale des prix économiques déjà signalée reste distincte ; aucun prix modifié.
L'absence du corps réel/ACL et de l'accès MCP bloque l'application ; l'absence du
contrat inventaire et de révision bloque la réception atomique fiable. Le chantier
et le feu vert de duplication restent **NON TERMINÉS**.

## 7. Commits de cette mission

- `3f17b581` — transformation conservatrice de la fonction installée, préparation non appliquée.
- `aaf10ad7` — réclamation effective et isolation des réceptions.
- `885f1e1e` — organisations : panne, données invalides et chargements périmés.
- `cd6fa8da` — retours des soins/repos/justice/politique/militaire/Assemblée.
- `bb7e2b09` — snapshots antérieurs à une réhydratation annulés.
- `06fd701c` — preuves PostgreSQL, deux onglets, catalogue et préservation des ACL.

Le commit documentaire suivant contient ce rapport et les résultats. La publication
et son SHA sont confirmés dans le compte rendu de session après push.
