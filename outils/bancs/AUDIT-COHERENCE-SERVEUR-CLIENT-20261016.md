# Audit serveur / client — 16 octobre 2026

> Suite : [sécurisation des transactions](SECURISATION-TRANSACTIONS-20261016.md).
> La préparation de migration d'achat décrite ici a été révisée pour préserver
> le corps installé, dont des ajouts alimentaires signalés depuis Supabase.
> Elle reste non appliquée ; ce rapport conserve le bilan historique de l'audit.

Human Gambit, `FredJ74/res-publica`, `main`. Départ propre à `767d329e`.
Date de lecture : Europe/Paris. Aucun changement utilisateur non commité.

**CHANTIER NON TERMINÉ en production.** Les corrections client sont testées ;
un défaut critique d'achat est reproduit sur PostgreSQL local et sa migration
est préparée, mais **non appliquée à Supabase**. Aucun accès au connecteur ni
compte de test autorisé utilisable dans cette session. Aucun joueur réel touché.

Ce rapport couvre les circuits des neuf domaines demandés et nomme les limites.
Ce n'est pas une certification de toutes les branches, des RLS vivantes ou de
la totalité des Edge Functions. Les comptes, articles et personnages des tests
sont des fixtures. Aucun tarif, indice de ressource, probabilité ou effet métier
n'est modifié. Aucun fichier généré du baseline, empreinte ou observation de base
n'a été réécrit pour faire passer un contrôle.

## 1. Cartographie des états et des échanges

L'index reproductible `python3 outils/auditer-etats-client.py --json` recense les
accès littéraux aux tables/RPC, affectations `state.*` et fusions globales dans
les JS racine/API. Il trouve environ 608 accès de table, 488 appels RPC, 802
affectations et quatre fusions de `state`. Les commentaires sont inclus et les
appels dynamiques/mutations indirectes ne sont pas résolus : ces nombres sont
des points d'inspection, pas des anomalies ni une preuve d'exhaustivité.

| Domaine | Référence persistante / lectures | Écritures et autorité | Miroirs, affichage, rafraîchissement et erreurs |
|---|---|---|---|
| Personnage : argent, santé, moral, PA, caractéristiques, carrière, influence, popularité, réputation, fonctions/statuts | `personnages_donnees`, vue `personnages` ; `sbLoadPersonnage`, `loadCharacter` | `sbPayloadPersonnage` → file → `sbEcrirePersonnage`, sauvegarde de fermeture ; RPC de coûts, repos, soins, carrière, justice | `state`, `state.char`, localStorage ; `applyCharToState`, `updateUI` ; bootstrap async, debounce et filet périodique. Zéros et repères corrigés. Aucun compteur XP générique trouvé dans le mapping inspecté : ne pas en inventer ; progression via formations, qualifications, quêtes et statistiques |
| Inventaire : aliments, boissons, matières, dons, vol, transferts | `personnages.inventory`, `objets_recus`, objets au sol/PNJ ; signatures d'objet | `removeFromInventory`, RPC `inventaire_*`, achats et dons ; sas de réception dans `verifierObjetsRecus` | `state.inventory`, grille et fiches ; résultat serveur avant effet de consommation, verrou de clic ; retours d'une ancienne identité maintenant rejetés. La réception par suppression puis ajout local reste une dette atomique |
| Économie : caisses, stocks, production, salaires, taxes, propriétés et banques | `entreprises.data`, `organisations.data`, budgets municipaux/nationaux, caisses, terrains, baux, `comptes_bancaires`, `placements_bancaires` | RPC commerce/banque/urbanisme/fiscalité/subvention et passe `api/cron-minuit.js` ; coexistence de certains écrivains legacy de blobs | Commerce, terminaux, `state.arg/liquide/comptesBancaires/placementsBancaires`, caches de locaux. Les sept entrées commerce relisent maintenant le registre ; banque distingue panne et vide. Les écritures legacy non atomiques ne deviennent pas sûres par ce seul rafraîchissement |
| Politique : candidatures, nominations, élections, votes et mandats | `cycles_electoraux`, `postes_attribues`, `titulaires_pnj`, dossiers dans `batiments_etat`, sièges Assemblée | RPC de dépôt, vote, nomination, révocation et résolution serveur ; migration municipale précédemment documentée appliquée | `CYCLES_ELECTORAUX`, `state.poste`, dossiers et annuaires ; `getTitulaireActuel`, variante fraîche du résolveur municipal. Les caches ordinaires n'ont pas tous la même discipline d'erreur. Les bancs municipaux/vote/nocturnes passent ; pas de nouvelle preuve RLS réelle |
| Justice et criminalité : plaintes, peines, amendes, recherche, détention, neutralisation | Plaintes/affaires/audiences, `detentions`, statuts judiciaires et fiche du personnage | Portes judiciaires, pénales et Assemblée ; coûts et actes côté serveur pour les circuits déjà migrés | `state.estEmprisonne`, recherches, hospitalisation, convocations et écrans de tribunal ; bancs dédiés de refus/verdict. Les réponses asynchrones de tous les actes ne sont pas encore liées à une révision commune |
| Organisations : membres, grades, droits, trésorerie et biens | `organisations.data`, propriétés, baux ; `sbLoadOrganisations`, `sbGetOrganisationParId` | `sbSaveOrganisation`, portes de cotisation, subvention et contact organisation | `state.organisations`, listes, grades et formulaires. `sbLoadOrganisations` transforme encore une panne en `[]` ; ne pas considérer ce résultat comme une dissolution ou écraser un blob à partir de lui. Fusion/mutation concurrente des blobs à isoler acte par acte |
| Militaire : effectifs, positions, matériel, blessures, mouvements | `compagnies_militaires`, `pnj_membres`, matériel, `militaire_terminal_requetes`, services/soldes | `sbMilitaire*`, commandes et terminal RPC ; lecteurs bornés aux droits ; cron | Caches d'occupation, détachements et états d'escorte ; `plateau-multijoueur.js`, `plateau-militaire-terminal.js`. Bancs client existants réussis, pas de scénario militaire authentifié réel dans cette mission |
| Presse et archives | `journal_editions`, `journaux`, index de La Tribune, archives historiques embarquées | Génération/publication serveur et faits validés ; index lu par `sbGetArchivesTribuneIndex` | Kiosque, caches d'index/édition et énigme ; pagination et maintien des historiques pendant panne acquis à la consolidation précédente, bancs toujours verts. Aucune purge ou rétention nouvelle |
| Temps/actions : journée, sommeil, PA, limites, délais | Fiche, registres de repos, cycles et dates serveur, registres nocturnes | `pa_repos_nocturne`, `payer_ordre`, autres portes et cron | `state.day`, limites locales, modales et horloges ; `doDormir` traite encore des effets locaux après le verdict PA. Horloge locale d'affichage et condition serveur ne sont pas interchangeables. Les bancs du calendrier ne certifient pas tous les effets de sommeil |

Les principales fonctions serveur ont été consultées dans le catalogue SQL
versionné et les migrations disponibles. Ce catalogue peut être en retard sur
la base vivante ; aucune conclusion de déploiement n'est tirée d'une absence locale.

## 2. Défauts avérés et corrections

| Gravité | Reproduction et cause | Correction réelle |
|---|---|---|
| Critique, serveur, **en attente** | `acheter_produit_commerce` insère `objets_recus` puis appelle le débit. Si le débit refuse, `RETURN {ok:false}` ne rollbacke pas les INSERT déjà faits. Ancienne définition : un objet créé malgré refus reproduit sur PostgreSQL | Migration préparée : déplacement du débit avant toute livraison ; même fonction, paramètres, autorité, prix, fiscalité et effets. Non appliquée en production |
| Élevée, potentiellement persistante | Santé/moral à zéro remplacés par 100/75 dans le payload normal et de fermeture ; discipline à zéro remplacée par 50 à la lecture et à la fermeture | `supabase.js` : repli nul/absent plutôt que test de vérité. Les zéros restent des données |
| Critique, écrasement de cache | Un onglet A voit que B a écrit, copie seulement sa date, puis au second tick sauvegarde son ancien contenu sous cette date | Le filet périodique n'adopte plus de repère sans état ; une lecture impossible ou un repère absent ne permet plus de sauvegarde automatique aveugle |
| Élevée, capture différée | Une sauvegarde est en file ; le tableau d'inventaire ou les stats continuent à changer avant l'envoi car le payload gardait leurs références | Snapshot JSON réellement capturé avant la file ; position garde son traitement actualisé existant |
| Élevée, identité/date | Reconnexion ou personnage changé pendant la file/lecture ; ancienne confirmation posant sa date sur le nouvel état ; date client utilisée à la place du résultat | Gardes nom/compte/jeton, repère issu de la réponse serveur. Le repli à la fermeture porte aussi le filtre du repère connu et n'envoie rien sans lui |
| Élevée, finance | Apport/retrait caisse, salaire de fabrication ou apport matière ajoutés à un vieux miroir local ; chemin public d'apport non rafraîchi ; ancien snapshot d'inventaire réappliqué lors d'un rejeu | Sept points d'entrée commerce : relecture des valeurs actuelles, inventaire inclus pour les apports. Aucun delta de rémunération/solde ni PA de fabrication appliqué localement dans ces entrées |
| Élevée, double clic/retard | Deux clics de production généraient deux clés, malgré le commentaire prétendant une clé unique ; réponse d'une ancienne session appliquée à la nouvelle | Verrou en vol par action/contexte ; il est libéré même sur erreur. Gardes avant/après RPC et lecture ; rejeu rafraîchit sans seconde annonce/récompense |
| Élevée, inventaire | Consommation confirmée après passage à un autre personnage : copie de l'ancien inventaire et application des PA au nouveau | `removeFromInventory` retourne `contexte_modifie` et indique séparément si la transaction précédente était confirmée. Aucun effet sur le nouveau personnage ; message n'affirme pas un refus métier fictif |
| Élevée, banques | `sbGetComptesBancaires` et placements rendaient `[]` sur panne ; le rafraîchissement vidait le miroir bancaire. Réponses anciennes pouvant gagner | Panne explicitement rejetée, vrais tableaux vides acceptés ; bootstrap préserve le connu. Helvetia charge les trois sources en parallèle, ignore réponses obsolètes et champs financiers partiels/invalides |
| Normale, rangement et diagnostic | Deux SQL hors workflow ; tractage qualifié à tort comme sans définition locale lorsque seuls baseline/migrations étaient inspectés | Photographies archivées octet pour octet dans `historique/sql-hors-registre`, sans prétendre qu'elles sont enregistrées ou appliquées. Le contrôle du workflow devient vert sans exception artificielle |

Les tests ont été écrits puis exécutés rouges avant correction : cinq défauts
sur les sept premiers cas de sauvegarde, 19 échecs sur les 21 premiers cas
commerce, puis compléments ciblés de lecture, fermeture, session, banque et
inventaire. Les résultats finaux sont verts.

Les gardes par jeton sont conservatrices : une rotation du jeton peut faire
ignorer une réponse pourtant légitime. Elle ne rejoue ni ne rembourse l'acte ;
une nouvelle lecture établit son résultat. Aucun jeton n'est enregistré dans
les preuves ou messages.

## 3. Transactions : preuve SQL et migration préparée

[20261016070541_achat_commerce_debit_avant_livraison.sql](../../migrations/20261016070541_achat_commerce_debit_avant_livraison.sql)

**État : NON APPLIQUÉE.** Commit de préparation : `b9baa044`.

La garde reconnaît uniquement le corps archivé ou le corps corrigé par MD5 du
code, afin de refuser d'écraser une fonction vivante différente. Ce n'est pas
une empreinte de données ni une observation Supabase inventée. L'agent devra
lire le vrai corps avant application ; si différent, la migration s'arrête et
le rapprochement doit être réexaminé. `CREATE OR REPLACE` conserve les droits
existants, qui doivent eux aussi être contrôlés dans le vrai catalogue.

`banc-achat-commerce-local.py --local-jetable` ne prend aucune URL et crée son
propre moteur avec `pgserver`. Dépendances de test épinglées dans
`requirements-postgres-local.txt`. La fonction d'achat réellement archivée est
chargée, puis la migration réelle. Services annexes (autorité, présence,
taxation, fiche, mouvement) et schémas sont des fixtures : **pas une preuve
RLS/Supabase**. Le débit de fixture verrouille réellement la ligne du compte.

Sept scénarios PostgreSQL locaux réussis :

1. Défaut reproduit sur l'ancienne définition : refus et livraison créée.
2. Migration compilée et réappliquée, sans autre modification d'instructions.
3. Débit refusé : aucun objet, vente, prélèvement ou stock modifié.
4. Achat nominal puis rejeu : une livraison et un débit.
5. Erreur après le débit : rollback complet, argent et objets conservés.
6. Deux connexions/deux commerces/un solde commun : une seule vente/livraison.
7. Corps de fonction inconnu : garde de migration refusant son remplacement.

Le banc compare le texte d'instructions ancien/nouveau hors commentaires et
hors bloc déplacé : aucune autre règle n'est changée. La migration ne contient
aucun appel métier ni test laissant de données en production.

Dépendances : fonction existante d'achat et ses relations/helpers (notamment
`mouvement_titulaire`, `objets_recus`, `ventes_snapshots`, `entreprises`, catalogues,
fiscalité et contrôle d'acteur). Contrôler le vrai catalogue avant toute application
enregistrée via MCP, puis suivre la réextraction prévue par le workflow. Aucun
ordre d'exécution n'est demandé au game designer.

## 4. Dépendances Supabase

Les lectures à effectuer par l'agent sont préparées dans
`banc-dependances-coherence-lecture.sql`, sous transaction READ ONLY et ROLLBACK :
existence, signatures, corps, ACL, privilèges anon/authenticated, vues et
dépendances enregistrées. `pg_depend` ne suffit pas à reconstituer tous les
accès dynamiques de PL/pgSQL. Ces requêtes n'ont pas été exécutées sur Supabase.

- `consommer_sur_place_commerce` : appel client retrouvé, aucune définition
  dans les SQL locaux inspectés. Absence en production non prouvée ; aucun
  contrat d'effets inventé pour créer la fonction à l'aveugle.
- `tracts_electoraux_distribuer_collectif` : **définition retrouvée** dans la
  photographie désormais archivée ; signature des cinq paramètres cohérente
  avec le wrapper. Le commentaire source affirme une installation le 14 octobre,
  mais ni cette installation ni le rattachement au registre ne sont attestés ici.
- `archives_tribune_index` : lecture client retrouvée, vue absente du baseline
  disponible ; existence, droits, sécurité de la vue et rétention à lire réellement.
- Edge Functions décoration/publicité premium : appels trouvés, sources et
  déploiements non disponibles localement ; autorité et versions restent à vérifier.

## 5. Référentiels économiques : causes mesurées, aucun tarif modifié

`node outils/auditer-ressources.mjs` produit
[DIAGNOSTIC-RESSOURCES-20261016.json](DIAGNOSTIC-RESSOURCES-20261016.json).

- Grille réelle : **109 cas**, tous divergents avec le Journal ; référence
  déclarée **103**. En retirant les **six cas laitages**, le compte redevient
  exactement **103**. La référence de taille est ancienne ; cela ne résout
  pas les divergences de valeurs déjà présentes. Elle n'a pas été modifiée.
- Canon et artefact : **18 ressources** ; ordre du générateur : **17**,
  laitages manquant. L'artefact place laitages à l'indice 1 et décale les
  anciennes clés suivantes. Les indices sont consommés par la logistique :
  régénérer naïvement pourrait changer leur interprétation.
- Les données du Journal ont encore des prix/plafonds distincts et des ressources
  absentes. Le cours théorique variable, le prix municipal fixe et un prix manuel
  ne sont pas interchangeables. L'audit ne choisit pas un contrat éditorial à la
  place du game designer et ne modifie aucun cours réel pour rendre un test vert.
- Le contrôle des référentiels conserve ses **29 diagnostics**, dont les repères
  de miroirs anciens. Aucun hash posé/réel de la base n'a été remesuré ici.

## 6. Validation et prévention

Résultats par banc : [VERIFICATIONS-COHERENCE-20261016.json](VERIFICATIONS-COHERENCE-20261016.json).

- **65/65 bancs JS réussis** : 2 193 épreuves historiques et 208 tests Node.
  Cette mission ajoute 42 cas Node par rapport à la consolidation précédente.
- **90/90 contre-épreuves existantes** réussies.
- **7 scénarios PostgreSQL locaux** réussis, avec les limites de fixtures décrites.
- Analyse syntaxique Node : **97 fichiers**, zéro erreur ; SQL préparés analysés
  par `pglast`. YAML du nouveau workflow analysé et structure contrôlée.
- `verifier-workflow.py` : **vert**, après archivage documentaire sans réécriture.
- `verifier-fonctions.py` et `verifier-referentiels.py` : **rouges**, diagnostics
  économiques préexistants expliqués ci-dessus ; aucun camouflage.
- Payload Vercel : environ **313,0 Mo / 330 Mo** ; `git diff --check` conforme.
- Aucun nouveau test navigateur authentifié. Aucun test Supabase de production.
  Concurrence consommation/transfert réel, vente/achat réel, multi-interfaces
  authentifiées et rechargement après transaction en production restent non exécutés.

Le workflow `.github/workflows/coherence-client.yml` relance les bancs JS et le
PostgreSQL jetable sur push/PR, sans identifiant Supabase ni migration distante.
Les commandes ont été éprouvées localement ; résultat GitHub Actions distant
non observé pendant cette session. Les audits économiques restent distincts
des suites vertes, avec leurs résultats rouges publiés.

## 7. Risques résiduels et reprise immédiate

| Priorité | Risque encore ouvert | Cause et prochaine action de l'agent |
|---|---|---|
| Critique | Achat : correction SQL pas encore en production | Lire le vrai corps/droits, confronter la migration, appliquer via le registre sur environnement autorisé, puis contrôles. Ne pas considérer le défaut fermé par le seul commit |
| Critique | Réception d'objets : suppression de la file puis ajout local | `verifierObjetsRecus` n'est pas une transaction de livraison vers l'inventaire persistant ; interruption ou identité changée peut perdre/mélanger un effet. Déplacer réclamation + insertion inventaire dans une porte atomique, avec contrat réel et tests isolés |
| Élevée | Sauvegardes complètes et concurrence inter-domaines | Le filtre de fermeture et les gardes client n'offrent pas un CAS universel : la vue a un trigger INSTEAD OF, certaines RPC ne mettent pas tous les repères à jour, les écritures explicites legacy existent. Nécessite version serveur vérifiée sous verrou sur la vraie table |
| Élevée | Résultat réseau indéterminé et nouvelle tentative | Le verrou en vol n'est pas une garantie d'idempotence après perte de réponse. Certaines commandes génèrent une nouvelle clé à chaque tentative et les mouvements de caisse n'ont pas de clé dédiée. Ne pas confondre protection du double clic et reprise exactement une fois ; contrat serveur et registre d'intention à compléter |
| Élevée | Changement de domicile, demande de naturalisation, certains revenus/subventions legacy | Des coûts/effets restent calculés ou enchaînés côté navigateur (`changerDomicile`, `confirmerDemandeNaturalisation`, branches historiques). Ne pas substituer un simple débit puis effet local : la bonne réparation est une transaction de l'acte et son autorité, sur schéma réel |
| Élevée | Réponses asynchrones hors commerce/Helvetia/inventaire | Les gardes ajoutées sont ciblées ; soins, sommeil, actes politiques/justice/militaires et bootstrap ne partagent pas tous une révision commune. Élargir la preuve par famille, sans réécrire le gameplay |
| Élevée | Organisations et autres blobs partagés | Plusieurs lecteurs masquent encore panne/vide, et des sauvegardes remplacent un JSON entier. Relire/fusionner par acte côté serveur, jamais créditer depuis un solde supposé |
| Élevée | Autorisations vivantes et dépendances | Aucun connecteur ni compte de test ; les contrôles locaux ne prouvent pas les RLS réellement déployées. Vérifier les trois dépendances prioritaires et les Edge Functions |
| Élevée | Référentiels économiques et ordre des ressources | Canon/artefact/générateur/Journal divergent ; déterminer la correspondance réelle des indices et l'usage éditorial, sans modifier les tarifs ni falsifier des observations |
| Normale | État non chargé et panne d'une première lecture | Les corrections préservent le connu, mais tous les écrans n'affichent pas encore explicitement « non chargé ». Définir un contrat d'état inconnu commun, sans convertir une absence en zéro |

Ces points interdisent un feu vert global de duplication. Ils ne sont pas
présentés comme des régressions introduites par les correctifs ni comme tous
reproductibles sur la base vivante sans accès. Les améliorations client ne
remplacent pas l'autorité transactionnelle du serveur.

## 8. Stratégie durable

1. Une porte par acte persistant, moteur partagé, autorité/territoire/prix lus
   en base et effets atomiques. Idempotence attachée à l'intention, pas seulement
   au bouton ; identité de transaction rendue dans le verdict.
2. Verdicts explicites : succès/refus/indéterminé, champs modifiés et révision
   autoritaire. Un résultat partiel ne vaut pas un état complet et une panne
   ne vaut ni liste vide ni solde nul.
3. Réducteur de miroirs borné à compte/session/personnage/domaine/révision.
   Les gardes ciblées ajoutées sont une étape, pas ce mécanisme global déjà fini.
4. Retirer progressivement les champs possédés par les RPC du PATCH global.
   Toute garde de concurrence doit être vérifiée sur la table autoritaire sous
   verrou, pas uniquement dans le navigateur ou sur la vue.
5. Entre onglets : invalider et relire après une transaction ; ne pas répliquer
   des deltas monétaires. BroadcastChannel peut aider l'affichage, jamais
   garantir un paiement. Éprouver deux connexions et les mêmes clés de requête.
6. CI : bancs clients, contre-épreuves et PostgreSQL local ; puis suite séparée
   authentifiée isolée pour les portes réelles. Les contrôles rouges restent
   visibles jusqu'à résolution justifiée, avec observations datées.

## 9. Commits et état de livraison

- `2c34528c` — sauvegardes, zéros, snapshots, repères et identité.
- `19cabfe4` — transactions commerce et double clic.
- `fa15d43d` — retours d'inventaire isolés par personnage/session.
- `b9baa044` — migration d'achat préparée et banc PostgreSQL jetable.
- `1b87f6e4` — pannes bancaires, vrais vides et réponses tardives.
- `0537a3cd` — dépendances retrouvées, audits et archivage hors registre.

Le commit de ce rapport ajoute les preuves et le workflow de prévention.
Publication et SHA final confirmés dans le compte rendu de session.
**La migration reste à appliquer par un agent disposant des accès ; aucun SQL,
script, secret ou geste GitHub n'est demandé au game designer.**
