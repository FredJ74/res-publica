# PR #379 — reprise des quatre reliquats

**État : corrections préparées, promotion en production bloquée.**
Ne pas fusionner ni appliquer les deux migrations sur la seule foi des bancs verts.
La compatibilité d'un ancien navigateur avec les effets maintenant appliqués par le
serveur n'est pas certifiée ; le diagnostic isolé ci-dessous expose un risque réel.

Branche : `codex/audit-transversal-cloture-135-20261102`.
Référence initiale : `b6b00e97`. Corrections : `ab349ba4`, `0117ef4f`, `edbbebca`.
Main intégré : `6256929c` (#380 et #381 de Claude), fusion de travail `4034751e`.
Les seuls conflits étaient les versions de cache de `plateau.html` : les préfixes
récents de Claude et les suffixes de cette PR sont conservés. Les modifications
PNJ/DeepSeek présentes dans cette fusion proviennent de main, pas d'une réécriture
par cette mission. #377 n'est pas importée.

## Corrections et contrats

| Reliquat | Vérification et correction | Limite de certification |
|---|---|---|
| Anciens vols | `crime_voler` examiné transfère immédiatement et crée des lignes déjà traitées. Aucun producteur JS actuel de transfert différé retrouvé. Ancien consommateur rendu inerte, timer de lancement et deux helpers SQL inutilisés retirés. Aucun montant, objet ou ligne de joueur modifié. | Le constat communiqué de zéro ligne en attente concorde. Le corps vivant du producteur reste à comparer au prévol avant promotion. |
| Explosifs | Le moteur `militaire_subtiliser_tenter` est conservé ; dépôt par `inventaire_deposer_interne`. Réponse avec PA, inventaire, révision et contrat. Client : adoption de la réponse d'origine, verrou de clic, contrôle de personnage/session, relecture après réponse perdue sans réexécution automatique. | Les seuils et les 2 PA de tentative sont conservés. Pas de reçu de requête nouveau : ne pas promettre l'idempotence entre deux tentatives manuelles distinctes. La sanction QHS conserve son circuit existant ; elle n'est pas certifiée atomique avec le tirage. |
| Codétenu | Commande existante retrouvée : `employe_recruter`, helper `sbEmployeRecruter`. Suppression du prix/profil aléatoire et de l'employé construits à l'écran. | Le catalogue canonique indique **recrutable=false**, et aucun candidat actif n'est établi ici. Le refus serveur est respecté ; ce n'est pas l'activation d'un recrutement. `detenu` n'est pas assimilé à `codetenu`. Aucune nouvelle fonction PNJ ni modification DeepSeek. |
| Impacts | La même commande d'acquittement, surchargée avec contrat explicite, applique puis marque dans une transaction. POP, INF, DIS, carte postale, `hp_set`, `poison_start` ; refus des types inconnus sans les effacer. Verrous, propriété, rejouabilité et plafond quotidien testés. L'écran ne tire ni n'applique d'effet, puis relit le personnage. | L'ancien appel d'acquittement sans effet est fermé. **Un ancien cache peut néanmoins soumettre son propre delta par la sauvegarde historique : blocage décrit ci-dessous.** |

Les nouveaux clients exigent `p_contrat=1` : une base ancienne sans cette surcharge
refuse l'appel avant dépense ou acquittement. Aucune réussite n'est annoncée sur une
réponse absente. Aucune nouvelle consultation périodique n'est introduite.

## Blocage de coexistence des versions — ne pas masquer

Exécution réelle : `banc-reliquats-379-local.py --ancien-cache` sur PostgreSQL 17.6.
Le diagnostic installe la vue canonique (sous un nom de fixture), son déclencheur
`personnages_vue_modifier`, la fusion à trois voies et `personnages_fusionner_pop`. Après application serveur POP 10 → 15,
un ancien navigateur soumet POP=15, popBase=10 : le déclencheur produit **20**.
Résultat : **26 cas réussis, un cas rouge**, code de sortie 1. Cette épreuve n'est
ni désactivée ni présentée comme une réussite du nouveau contrat.

Le rôle `authenticated` n'obtient qu'UPDATE sur la vue de fixture, aucun droit
d'écriture direct sur la table de données. Le contrôle d'identité de la vue est
réel. Cette épreuve ne reconstruit pas tous les autres déclencheurs ni les corps
vivants ; elle démontre le défaut dans les corps de sauvegarde examinés. Le prévol doit
comparer aussi `personnages_vue_modifier`, `personnages_fusionner_pop`,
`fiche_fusionner_ecran` et les protections effectivement déployées. L'accès vivant
n'est pas disponible ici pour décider si une protection plus récente ferme déjà
ce chemin.

**Condition impérative de promotion :** démontrer sur le contrat vivant que la
sauvegarde d'un ancien cache ne double aucun effet, ou livrer au préalable la
fermeture compatible de cette écriture avec son responsable transversal. Modifier
aveuglément la fusion POP/INF ferait perdre les effets légitimes historiques qui
l'utilisent encore ; ce rapport n'autorise ni leur suppression ni un verrou global
improvisé. Le simple changement de cache ou le refus de l'ancien acquittement ne
constitue pas une protection serveur suffisante. Ce point reste ouvert.

## Migrations préparées, aucune application distante

1. `20261102202046_subtilisation_reponse_serveur_versionnee.sql`.
2. `20261102202047_impacts_consommation_serveur_atomique.sql`.

Les migrations refusent les corps SQL inconnus, acceptent le rejeu de leurs propres
définitions et conservent les droits des moteurs existants. Les nouvelles surcharges
ne sont exécutables que par `authenticated`, pas `anon` ou `service_role`.
L'inventaire utilise son dépôt et son déclencheur de révision existants ; `hp_set`
utilise le déclencheur PA=0 déjà livré, sans nouveau moteur hospitalier.
La seconde migration notifie PostgREST du changement de contrat.

Le prévol prêt pour l'intégrateur est
[`PREFLIGHT-379-CONTRATS-LECTURE-SEULE.sql`](../bancs/PREFLIGHT-379-CONTRATS-LECTURE-SEULE.sql) :
transaction cohérente en lecture seule, métadonnées, empreintes, agrégats sans
identités et présence des versions. Une différence de corps exige une relecture,
jamais un changement arbitraire d'empreinte. Comparer également les migrations
récentes de Claude, sans les rejouer. Le relevé **communiqué** de 1137 versions,
dernière `20261102191015`, n'a pas été exécuté par cette session et peut être dépassé.

Avant activation : lever le blocage d'ancien cache, refaire le prévol réel,
vérifier les dépendances et les contrats sur clone fidèle, valider l'ordre client /
SQL et obtenir l'accord d'intégration. Retour arrière : les savepoints et le rejeu
sont éprouvés avant commit sur le cluster jetable. Après des effets réels, ne pas
réinstaller l'ancien client ni l'ancien acquittement : cela ne déferait pas les
effets déjà appliqués. Préférer une correction en avant ou une restauration
transactionnelle préparée avant toute action, jamais une purge des files.

## Preuves locales

Résultats bruts, limites et SHA-256 : dossier `preuves-reliquats379-20261103/` et son
`MANIFESTE.json`. Ils ne contiennent aucun export de production ni secret.

- 10 tests clients vols/codétenu ; contre-épreuve sur `b6b00e97` : 9 échecs / 10.
- 31 tests clients subtilisation/impacts ; contre-épreuve : 28 échecs / 31,
  aucun cas annulé.
- 26/26 cas dédiés sur PostgreSQL **17.6, ICU 153.121**, et 26/26 sur **16.2**.
  Installation, rollback et double rejeu réellement exécutés. Contre-épreuve SQL :
  18 échecs / 26 avec les anciens effets/acquittements.
- Diagnostic d'ancien cache séparé : **1 échec / 27**, attendu 15, observé 20.
- Après intégration de main : 118 tests du pilote/Chromium, 53 transversaux,
  380 cas PostgreSQL et 12 contrôles globaux hors ligne réussis. Le résultat final
  du contrôleur clients est **171/171**, sans additionner des suites qui se
  recouvrent. Une première passe sans le Python enfant équipé de pglast a échoué
  dans deux bancs ; le relancement avec l’environnement complet passe, sans
  modification des tests.

Les JWT et personnages sont fictifs. Certaines contre-épreuves committent un décor
concurrent, puis détruisent le cluster entier. La géographie hospitalière est
simulée dans le banc dédié ; son déclencheur PA=0 est réel. Ce ne sont pas des
recettes authentifiées de production ni une nouvelle certification complète du
catalogue vivant. Les 12 contrôles hors ligne comprennent Authority et Referential,
mais « Reconstruction » reste ici l'assemblage/grammaire, pas un clone vivant.

## CI, production et relais

Les cinq verts historiques appartenaient à `b6b00e97`, pas aux corrections suivantes.
Les **six contrôles publics sont verts sur `4034751e`**, tête intégrant main ;
leurs étapes et SHA sont conservés dans les preuves. Le sixième couvre le parcours
immobilier du workflow actuel, sans intervention sur ce chantier. Ce constat ne
certifie pas automatiquement un commit de documentation ultérieur : sa propre
CI doit être observée aussi. L'API GitHub authentifiée refuse
toujours l'accès (`Forbidden`) ; les pages publiques permettent un relevé des
contrôles, pas la lecture de tous les journaux privés ni l'édition de la PR.

Vercel : la lecture de `res-publica.vercel.app/plateau.html` est refusée par le proxy
de cet environnement (tunnel HTTP 403). Cela ne démontre pas une panne Vercel.
Aucun SHA servi n'est certifié ici. Pas de paiement, déplacement, sanction, test
authentifié PJ, migration, fusion ou déploiement de production effectué.

**Relais à ChatGPT : ne pas intégrer tant que les contrats vivants et le défaut
d'ancien cache ne sont pas levés et les contrôles CI de la tête finale vérifiés.**
Après intégration autorisée seulement : constater la version servie et recetter
les chemins concernés avec des comptes/fixtures isolés autorisés.
