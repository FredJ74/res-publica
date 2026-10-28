# Audit indépendant de la PR #212 — sécurité privée et groupes

28 octobre 2026, Europe/Paris. Branche `codex/audit-securite-135-20261028`.

**Verdict : reprendre partiellement la PR, conserver les raccordements valides,
NE PAS fusionner ni déployer en l'état.** Les règles de Fred sont inchangées.
La réussite locale des correctifs ne démontre ni le groupe universel PJ+PNJ,
ni la compatibilité avec les fonctions actuellement installées dans Supabase.

## Périmètre, sources et limites

- HEAD réel de #212 obtenu par Git : `7c91ef1b0767d6ffc3dfa37be9cbc1c13ab430f1`.
  Comparaison avec main `3efca838af5b53f2f77a6c1cdbfbd69baaef5b6d`, intégré sans
  conflit pour préserver #214. Les huit fichiers propres à #212 sont distingués
  du travail de fiabilisation déjà intégré. La branche originale n'est pas réécrite.
- Lecture : AGENTS, Constitution, Architecture, Relais, audit Une seule vérité,
  WORKFLOW-SUPABASE, spécification sécurité de la branche, sources PNJ, militaires,
  police, groupes clients et trois bancs proposés. Les décisions complètes jointes
  par Fred sont la référence la plus récente ; aucun barème inventé.
- #196 : branche `codex/vigiles-vol-135-20261027` examinée par Git. Elle ajoute
  `chantier_vigiles_affectations` et son circuit particulier : contraire aux deux
  socles imposés par Fred. Aucun de ses développements n'est importé ou fusionné.
- API GitHub GraphQL refusée (`Forbidden`) : les commentaires, dernières reviews
  et issues distantes ne sont pas accessibles. Git permet de vérifier les sources,
  pas de confirmer des statuts Actions ou Vercel.
- Aucun outil SQL/Supabase n'est exposé dans cette session. La définition complète
  de `police_detection_verifier` n'est pas dans les sources SQL du dépôt : seulement
  des patchs textuels et des appels. **Elle n'a pas été réinventée en fixture.**
  `combat_coup_resoudre` est également une dépendance dont le corps n'est pas
  archivé ici. Les métadonnées vivantes, la totalité des triggers et des politiques
  ne sont donc pas validées. Rien n'est appliqué en production.

## A. Mécanismes retrouvés et raccordements possibles

| Mécanisme | Source retrouvée | Rôle et limite réelle |
| --- | --- | --- |
| Autorité PNJ | `baseline/domaines/socle-PNJ/20_fonctions.sql` : `pnj_autorite_de`, `pnj_peut_administrer`, `pnj_peut_conduire` | Propriété/autorité institutionnelle et chef transporteur sont déjà distingués. Ne pas leur substituer un simple métier ou une présence. |
| Position et suivi | Même fichier : `pnj_position_effective`, colonnes `leader_pj` / `leader_pnj_id` | Suit un PJ ou un PNJ ancré. Le trigger `pnj_pas_de_sous_hierarchie` interdit les chaînes de chefs ; il est conservé et testé. |
| Prise et séparation | `pnj_prendre`, `pnj_quitter_groupe`, wrappers `supabase.js` | Ordres réels avec autorité, co-présence et gardes de famille. La séparation matérialise la position. Ce sont les portes à réutiliser. |
| Restrictions de famille | `pnj_axes_autorite`, `pnj_mouvement_individuel`, leurs seeds et leurs gardes | L'ancien modèle refuse encore les prises individuelles des policiers/soldats et laisse certains axes au métier. C'est un raccordement à faire évoluer selon la décision universelle récente de Fred, pas un nouvel arbitrage à lui demander. |
| Dépose/reprise militaire | `baseline/domaines/militaire/20_fonctions-2.sql` : `militaire_deposer_soldats`, `militaire_recuperer_soldats` | Sélection par nombre dans une section, droits de l'officier, écritures dans les mêmes `pnj_membres`, puis projection métier. Ne pas supprimer cette autorité ni créer un dépôt militaire concurrent. |
| Chef militaire | `militaire_affecter_leader`, `20_fonctions-1.sql` | Affecte des soldats à un PJ soldat de la même section, avec présence et juridiction. Ce périmètre spécialisé n'est pas une adhésion universelle de PJ. |
| Groupes de bataille | `militaire_bataille_groupes_constituer`, `batailles_engagements.groupe_id` | Agrège les engagements par bataille/camp, choisit un chef et conserve effectif/repli. **Ce n'est pas l'identité persistante d'une patrouille dans une pièce.** |
| Effectifs de police | `pnj_miroir_police`, `pnj_comparer_police`, `pnj_force_publique_metier` | La projection dépend du blob `effectifsPolice`, l'axe position reste institutionnel. Le simple fait qu'un policier existe dans le socle ne prouve pas qu'il soit déplaçable par la porte individuelle. |
| Interception et conséquences | `migrations/20261018093000_police_interception_reprise_transactionnelle.sql` | Fuite, reddition, rounds, reçus, appel au coup commun et à la détention commune. Ces RPC existent déjà : pas de deuxième combat ni de prison privée. Leur état vivant doit être comparé aux archives. |
| Groupe PJ côté écran | `plateau-multijoueur.js` : `rejoindrePJ`, `quitterGroupe`, `getGroupSize`, `isGroupLeader` | Les premiers modifient `state.group` sans RPC ; `isGroupLeader` n'a pas d'appelant retrouvé. Aucun raccordement au transport collectif serveur ni sauvegarde de `state.group` retrouvé dans le chargeur/sauvegardeur. **Ordres présents ne signifie pas groupe serveur opérationnel.** |
| Présence affichée | `presences.groupe_pnj`, `sbUpdatePresence` | Projection d'affichage des accompagnants ; jamais une source d'autorité de commandement. |

L'absence d'une colonne PJ seule n'a PAS servi de preuve : la recherche a porté
sur les ordres, leurs appels RPC, les écritures/sauvegardes, les contrôles de
navigation et les moteurs SQL. Conclusion bornée aux sources disponibles : le
socle PNJ est réel ; le contrat serveur du groupe universel PJ+PNJ n'est pas
retrouvé. Le catalogue vivant reste nécessaire avant de décider ce qui manque en base.

## B. Structures et calculs proposés : utilité démontrée ou non

| Ajout de #212 | Verdict de l'audit |
| --- | --- |
| `pnj_membres.groupe_deploiement_id` | **Superflu pour le détachement PNJ testé.** Le lien existant `leader_pnj_id` distingue déjà l'ancre immobile et ses membres. La nouvelle clé survivait aux anciennes reprises/séparations et recréait un faux groupe. Retirée du SQL non appliqué, sans DROP de colonne réelle. |
| Identifiant aléatoire `deploiement-…` et limite 50 | La clé supplémentaire n'est plus nécessaire. Aucun maximum universel de 50 n'était documenté : cet ajout n'est pas conservé. Les validations d'identifiants restent strictes. |
| `pnj_deployer_unite(text[],boolean)` | L'intention « ensemble ou séparés » est légitime ; sa première version réécrivait directement les liens et ignorait les gardes existantes. **Conservée comme adaptateur** de `pnj_quitter_groupe`, pas comme moteur parallèle. Le nouvel ordre n'est pas annoncé comme branché dans toutes les UI. |
| `securite_agents_prives_presents_interne` | Adaptateur utile : filtre les métiers de sécurité puis appelle la position commune. Ce n'est ni une affectation de vigile ni un nouveau calcul de combat. Sa portée initiale reste les employés privés avec propriétaire PJ ; les autres formes d'employeur ne sont pas démontrées. |
| `securite_ordre_detection_interne` | Utilité réelle : l'ancien fragment policier agrège tous les présents, alors que Fred impose des unités explicites, un ordre et un arrêt au premier succès. L'auxiliaire prépare ces unités, la RPC police reste seule à tirer/inscrire la rencontre. La formule moyenne PER + effectif − 1 et dilution rue 2 est reprise, pas rééquilibrée. |
| `groupe_id` / `groupeId` dans le JSON policier | **Provenance non démontrée.** Aucun producteur retrouvé dans le catalogue policier. Le test initial injecte lui-même ces clés et ne prouve que leur lecture. Leur compatibilité est conservée, mais aucun raccordement militaire→police ni groupe policier opérationnel ne sont revendiqués. |
| `leader_pnj_id` | Relation existante réutilisable pour un détachement ancré, mais PAS un groupe PJ universel. Ses contraintes, son trigger et les axes d'autorité doivent être respectés. |
| `police_interceptions.intervenants` | Ajout justifié : conserver l'identité des seuls détecteurs pour les rounds suivants. Ni le lieu ni la co-présence ne suffisent ; un reçu d'action ne décrit pas la sélection avant la première action. Colonne du registre existant conservée, pas de nouvelle table. |
| Écritures des PA privés | Nécessaires dans leur magasin réel `pnj_membres`. Le contrat de perte de PA au combat est celui de la RPC existante ; ce n'est pas une nouvelle dépense d'ordre. L'auxiliaire générique `pnj_pa_fixer` bloque les classes bêta et n'est donc pas substitué aveuglément au résultat du combat policier. |

## C. Défauts démontrés et corrections

**S1 — Registre policier tronqué, critique.** Après filtrage des `intervenants`,
le combat réécrivait le blob avec cette seule liste. Combat privé : les policiers
pouvaient tous disparaître du registre ; combat d'un policier : les autres étaient
retirés. Deux contre-tests indépendants l'ont reproduit sur `7c91ef1b`.
Correction : réécrire le registre policier intégral, ne remplacer que les PA des
matricules participants ; persister les PNJ privés une seule fois, séparément.

**S2 — Dépose contournant les gardes communes.** Un PNJ institutionnel suivant
le PJ pouvait être déposé par la nouvelle RPC malgré `axe_position_hors_socle`.
Correction : passage par `pnj_quitter_groupe`, verrouillage puis contrôle de tous
les identifiants avant mutation ; refus atomique de la dépose commune.

**S3 — Ancienne clé de détachement encore active.** Après reprise puis séparation
individuelle via les ordres existants, deux agents conservaient la clé ajoutée
et étaient encore comptés comme un groupe. Correction : supprimer cette deuxième
identité dans la préparation, réutiliser les liens existants.

Cette réutilisation a révélé une vraie limite de `pnj_prendre` : déplacer l'ancre
avant de vérifier les membres fait perdre leur position, et le trigger interdit
qu'une ancre conduise encore des PNJ quand elle rejoint un PJ. Correction dans la
**fonction commune** : vérifier d'abord tous les membres, défaire les liens via
`pnj_quitter_groupe`, puis reprendre le lot. Le trigger et les contraintes sont
conservés, pas désactivés pour faire passer le test.

**S4 — Lecture concurrente périmée des PA privés.** Sans commissariat à verrouiller,
deux combats sur le même PNJ pouvaient lire ses PA avant de se bloquer à l'UPDATE.
Une trace de fixture non transactionnelle démontre deux lectures avant libération
sur la proposition initiale, une seule après correction. Verrouiller les PNJ
sélectionnés, dans un ordre stable, **avant** la lecture. Même garde pour la fuite.
Un essai supplémentaire avec un premier combat committé dans PostgreSQL jetable
vérifie le snapshot réel : après deux coups simulés, 12 → 11 → 10, pas 12 → 11 → 11.

**C1 — Effectif d'écran non conforme.** Trois policiers co-présents, mais une
unité d'un seul confirmée : l'écran conservait les trois. Correction limitée à
l'affichage de l'effectif confirmé. Le récit de remise à la police et le circuit
carcéral existant sont conservés ; cache de ce JS relevé dans `plateau.html`.

**S5 — Rue perdue dans le socle, défaut préexistant.** La position commune
rendait NULL pour la rue d'un PNJ suivant un PJ ; l'adaptateur privé compensait
par un second JOIN au personnage. La co-présence comparait aussi une rue normalisée
à un bâtiment NULL du joueur, ce qui refusait une reprise sur place. Deux nouveaux
contre-tests le montrent. Correction des fonctions communes `pnj_position_effective`
et `pnj_co_present`, puis suppression du JOIN compensatoire privé. Le test de
déploiement/reprise en rue passe ; ce ne sont pas des défauts créés par ChatGPT.

**S6 — Identités absentes agrégées.** Deux entrées sans matricule formaient une
unité de deux par regroupement des NULL. Elles sont maintenant exclues, faute
d'identité utilisable dans les intervenants ; le test refuse ce faux groupe.
Les entrées métier valides, leur coût et leur formule restent inchangés.

**M1 — Migration non rejouable et trop grosse.** La proposition fait 15 838
caractères ; le canal de migration documenté accepte environ 12 500. Les patchs
refusaient aussi une seconde installation. Les fragments exacts déjà remplacés
sont maintenant reconnus ; une source différente reste refusée. Les étapes
réellement disponibles sont installées deux fois dans le banc. Le patch du
**détecteur vivant** ne peut pas être exécuté sans sa définition : son analyse
syntaxique n'est pas une preuve d'intégration ni de rejouabilité sur production.

Scission technique, sans nouveau mécanisme :

1. `20261027222500_securite_privee_socle_policier.sql` : liens/auxiliaires/reprise.
2. `20261028074753_securite_privee_detection_unites.sql` : détecteur existant.
3. `20261028074754_securite_privee_combat_pa_et_registre.sql` : fuite/combat existants.

Chaque fichier reste sous 12 500 caractères. Ils ne doivent pas être activés
isolément. Aucune version du registre n'est inventée ; il faut d'abord vérifier
si une ancienne variante a été appliquée. Les gardes doivent alors refuser une
source différente ; surtout pas supprimer automatiquement une colonne réelle.
Les trois bancs SQL existants ont aussi une enveloppe explicite BEGIN/ROLLBACK ;
leurs assertions ne sont pas supprimées. Workflow passe sans modification de son
vérificateur, de son baseline ou de ses références.

## D. Tests indépendants et limites

Le programme `outils/bancs/banc-audit-securite-135-local.py` charge les corps SQL
archivés de la police, les fonctions et seeds PNJ, cinq contraintes réelles et le
trigger anti-sous-hiérarchie. Identité/Auth, verdicts judiciaires et coups de combat
sont des dépendances **simulées** ; le détecteur manquant n'est pas reconstitué.
Les appels métier sont faits sous `authenticated` avec `request.path`.

- Proposition originale : **8 contre-tests échouent** : S1 (deux cas), S2, S3, S4,
  les deux limites de rue préexistantes S5, et l’identité manquante S6. Les autres cas peuvent passer : les bancs
  originaux n'étaient pas tous inutiles et tous les ajouts n'étaient pas erronés.
- Préparation corrigée : **18/18 scénarios PostgreSQL** passent, dont priorités
  police→privé, droits des auxiliaires, refus d'un autre chef, absence de l'agent,
  immunité de l'employeur, reçu perdu/rejoué, panne de reçu annulant PA et registre,
  reddition, fuite réussie et échouée, reprise/séparation et concurrence réelle.
- Par défaut, **toutes les opérations métier sont annulées**. Le décor fictif est
  installé dans un serveur PostgreSQL local temporaire, puis entièrement détruit.
- Option explicite `--concurrence-commit-jetable` : **19/19**, avec une opération
  committée **uniquement dans cette base éphémère** pour vérifier le snapshot après
  attente. Aucun joueur réel ni serveur Supabase n'y participe ; ce cas est distinct
  des transactions annulées et n'est pas présenté comme tel.
- **35/35 tests client interception**, transports simulés, dont le nouvel effectif.
- **107/107 bancs clients complets**, lanceur Linux versionné du dépôt.
- **105/105 tests locaux du pilote**, pas une connexion de joueur réel.
- Analyse SQL des trois étapes, du prévol et des trois anciens bancs ; syntaxe JS,
  23 modules API, YAML, garde payload et Workflow contrôlés localement.

Les trois bancs SQL de ChatGPT n'ont PAS été rejoués intégralement sur Supabase.
L'ordre de catégories/tailles est éprouvé via leur auxiliaire réel ; l'appel à la
boucle du détecteur réel, l'arrêt des jets après succès et la protection contre
les relances après échec ne sont pas établis sans son corps vivant. Les ACL des
nouvelles fonctions sont éprouvées ; celles de production restent à relever.
Les anciens tests n'étaient pas une preuve suffisante : les clés `groupeId`
sont ajoutées par le décor du test, les scénarios ne vérifiaient pas la conservation
de tous les policiers après le filtrage, et deux appels séquentiels ne couvrent
pas deux victimes concurrentes. Le banc mentionne `police_detection_attempts` et
le réinitialise pour ses tirages : cela indique un mécanisme à examiner, pas
l'absence de protection ni la preuve de sa validité. Ce registre figure au prévol.

Un contre-test client indépendant charge en mémoire le JS original : **34 tests
passent, celui de l'effectif échoue précisément avec `3 !== 1`**. Aucun fichier
suivi n'est remplacé pour cette épreuve.

Aucun test local n'est une campagne Arnie ou une preuve de fonctionnement en jeu.

## E. Développement restant : absent ou non raccordé ?

1. **Raccordements existants** : réutiliser sélection/droits militaires, dépose,
   reprise, projection police et position PNJ ; adapter les vieux gardes de famille
   aux règles universelles récentes sans leur substituer une porte moins protégée.
   Ne pas créer de table de vigiles ni réécrire un combat.
2. **Contrat serveur non retrouvé pour les groupes PJ** : les ordres clients sont
   là, mais l'adhésion persistée, le commandement et le déplacement de plusieurs PJ
   ne sont pas démontrés. Identifier d'abord le contrat vivant ; s'il manque aussi
   en base, c'est le chaînon à développer avec les mécanismes de présence existants,
   pas une raison de créer un groupe privé, policier et militaire chacun.
3. **Groupes policiers effectivement constitués** : relier les unités réelles au
   registre existant. Les clés JSON injectées par un test ne sont pas une formation
   de groupe. L'identité d'engagement de bataille n'est pas ce chaînon.
4. **Prévol vivant obligatoire** : `outils/bancs/PREFLIGHT-AUDIT-SECURITE-135.sql`
   relève définitions, signatures, ACL, RLS, triggers, contraintes, registre et
   règles de famille, sans donnée personnelle. Vérifier aussi les chemins de
   déplacement directs et les refus d'ordres pendant une rencontre : les gardes
   clientes seules ne suffisent pas et les définitions vivantes manquent ici.
5. **Intégration et recette réelle** : comparaison des fonctions de production,
   tests authentifiés sur données de test autorisées, absence de double jet après
   reprise et exécution en jeu avant toute activation. Aucun arbitrage nouveau
   de game design identifié comme nécessaire aux correctifs livrés.

## F. Évaluation et livraison

**PR #212 à reprendre partiellement.** Conserver le branchement aux RPC policières,
la sélection des intervenants, les positions communes, les reçus et le récit RP.
Abandonner la deuxième identité de détachement PNJ ; garder l'ordre de déploiement
comme adaptateur contrôlé du socle. Ne pas annoncer un groupe universel achevé.

Le premier correctif est sauvegardé au commit `ba3d267f` sur la branche d'audit.
Les sources finales et leurs preuves sont sur cette même branche, séparée de
#212 et de #213. Aucun fichier d'inventaire ni autorisation de sauvegarde de fiche
modifié ; le seul JS métier touché est la sélection d'effectif de la rencontre.
Les modifications de main, dont #214, sont conservées. Les autres travaux ne
sont pas fusionnés en bloc.

**Blocages de mise en production :** catalogue vivant incomplet/inaccessible,
validation du détecteur et de ses relances, provenance des groupes policiers,
contrat et raccordement du groupe PJ universel, recette authentifiée. Ce sont
pour partie des travaux de code/raccordement et pour partie des accès manquants :
ils ne sont pas tous imputés à l'environnement.

**Aucune migration appliquée, aucun déploiement ni fusion de #196/#212, aucune
donnée réelle de joueur modifiée.** Les preuves brutes sont dans
`outils/audits/preuves-securite-135-20261028/` ; les empreintes lient les résultats
aux sources et ne remplacent aucune empreinte du baseline Supabase.
