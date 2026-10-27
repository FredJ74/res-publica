# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

### Sécurité privée #135 — arbitrages du 27/10 (ChatGPT)

- **27/10, tests de sécurité supplémentaires** : six assertions de présence/absence du PNJ (ville, salle, PA, employeur, détention), refus de combat depuis une autre identité authentifiée, et refus d'un nouveau round lorsque l'agent quitte la zone. Migration + banc SQL complets joués ensemble dans `BEGIN/ROLLBACK` Supabase : OK. Ne pas fusionner avant baseline canonique, tests d'intégration complets et jonction malus/vol avec Codex.
- **27/10, poursuite en parallèle** : correction de la persistance des PA des agents privés lors du combat dans `pnj_membres` (aucune affectation de chantier) ; banc SQL versionné enrichi d'un personnage fictif sous `authenticated`, du combat et de son rejeu idempotent ; migration et banc rejoués ensemble sur Supabase dans `BEGIN/ROLLBACK` : OK. Aucun fichier inventaire/vol de matériaux modifié ; aucune écriture persistante en production.
- **27/10, branche de travail ChatGPT** : `chatgpt/securite-privee-20261027`, [PR #212](https://github.com/FredJ74/res-publica/pull/212) **en brouillon**. Raccordement client serveur-first, adaptateur de présence PNJ aux trois fonctions policières existantes, RP « remis à la police ». Bancs transactionnels réels annulés sur personnages artificiels : compilation, 4 assertions de présence, détection sous `authenticated`, reddition/détention, fuite et un round de combat OK. Cinq workflows GitHub au vert sur `fc32aa8c`, prévisualisation Vercel READY. **Non déployé en production**, migration non appliquée ; avant fusion : recette complète, baseline Supabase selon WORKFLOW-SUPABASE.md, coordination du vol de matériaux avec Codex et contrôle production. La PR #196 demeure incompatible et ne doit pas être fusionnée.

- Fred confirme : **seulement deux socles**, embauche/déplacement des PNJ et mécanique policière (malus actes illégaux, détection, interpellation, prison). « Vigile de chantier » est cosmétique. **Aucune affectation au chantier**, aucun moteur/table d'affectation propre aux vigiles. Le PJ employeur déplace librement son PNJ. En cas d'interpellation réussie, mécanisme carcéral policier existant et message RP « remis à la police, conduit en prison ».
- `AGENTS.md` a été corrigé pour lever l'ancien arbitrage contradictoire. La PR #196 `codex/vigiles-vol-135-20261027` est **ouverte, non fusionnable en l'état** : elle ajoute `chantier_vigiles_affectations` et un moteur privé de détection, en contradiction avec cette décision ; ne pas appliquer ses migrations.
- Vérification réelle Supabase en lecture seule : `pnj_position_effective(text)`, `police_detection_verifier(text,text,text)`, `combat_coup_resoudre(numeric,numeric,numeric,integer,integer)` existent. `police_detection_verifier` lit les effectifs policiers de `batiments_etat` ; il faut factoriser/utiliser son algorithme commun pour les agents PNJ sans faux policiers, sans nouvelle mécanique parallèle. Préserver les règles serveur de détection, les gardes anti-relance et le parcours d'incarcération.
- Codex traite actuellement **l'inventaire**, y compris le vol de matériaux ; ne pas toucher à ces fichiers ni aux migrations objets. Préparer séparément le raccordement de sécurité passive et la détection/interpellation avec tests en transaction annulée (`authenticated`), puis déployer seulement après tests complets.


### #135 — Recette de clôture du 27 octobre

- Branche `codex/cloture-immobilier-135-20261027`, issue de main `74128ee` : #174/#175/#178/#188 conservées, aucun ancien correctif réimporté. Aucun fichier métier ambassades/BNE ni socle transversal de Claude modifié.
- Défaut réel corrigé : `confirmerVolMateriaux` réaffectait une constante après réponse serveur. Quantité demandée distincte de la quantité accordée ; quatre tests réels sur fixtures dont contre-épreuve de l'exception, version du script actualisée.
- 105/105 pilote, 105/105 bancs clients, navigation 60/60 (incluse), occupation 30, négociation 59, permis 56, cinq parcours 324 + banque 61, progression/salaire 62+15, matériaux conformes. Assemblage des cinq parcours complété du taux horaire actuel. Trois mutants SQL détectés, preuves archivées.
- Globaux 4/12, résultats identiques au main courant : aucun contrôle maquillé. Le vol demeure un circuit historique non entièrement atomique et le raccordement des vigiles aux affectations/détection/combat communs n'est pas démontré ; ne pas déclarer ce volet fini.
- Audit du 26 : cinquième connexion Arnie et position initiale confirmées en lecture seule, résultat archivé, pas réexécuté ici. API GitHub Forbidden, HTTPS Vercel refusé par proxy, aucun outil Supabase exposé. Aucun joueur déplacé et aucune migration appliquée.
- Correctif et preuves poussés : `736ab07`. Tentative de PR en brouillon refusée par GraphQL (`Forbidden`), aucun numéro créé ni fusion.
- Rapport et preuves : `outils/audits/CLOTURE-IMMOBILIER-135-20261027.md`. PR/intégration/déploiement à vérifier par accès technique ; #135 reste ouvert. Intervention unique : fournir ces accès à une session exécutante, sans manipulation SQL ni compte/secret à recréer par Fred.


**Ambassades et Bureau de l'Emploi : chantiers de Claude seul** (Fred, 25/10). Ces
notes sont la trace du travail, pour reprendre l'historique. **Codex : ne pas toucher aux
ambassades ni au Bureau de l'Emploi.**
- **Nuit du 26 au 27/10 (Claude)** : `CONSTITUTION.md` et `ARCHITECTURE.md` ajoutés (à lire,
  `AGENTS.md` y renvoie ; tenir `ARCHITECTURE.md` à jour). Fusionnés : ordre générique par le
  serveur (`ordre_generique_executer`) ; couvre-feu et recherche militaire dans la passe de nuit
  (`minuit_couvre_feu_recherche`) ; code mort supprimé ; inventaire vérifié. Matin du 27 : objets
  abandonnés par le serveur (`20261027030000`) ; carrière religieuse de Républia par le serveur
  (`religion_agir`, `20261027040000`/`040100`) — `titulaires_pnj` et `contributions_piete` ne sont
  plus écrites par les joueurs. **Codex : pour la popularité ou l'influence rendues par une RPC,
  utiliser `adopterJaugeServeur('pop'|'inf', valeur)`, jamais `state.pop = v.pop`** (double
  comptage à la sauvegarde suivante). **Bancs SQL : se placer au rôle `authenticated`** (`set_config('role','authenticated',true)`),
  sinon `est_appel_serveur()` est vrai et masque les défauts (c'est ainsi que l'annulation des
  gains de popularité écrits par le serveur est passée inaperçue ; corrigé, `20261027050000`).
  Démenti et rumeurs politiques par le serveur (`dementi_executer`, `20261027060000`). **Scrutins fermés aux joueurs** (`cycles_electoraux`) : engendrement, dissolution et
  contestation par le serveur (`20261027070000`/`070100`) ; la passe de nuit pose
  `cycle.dernierScrutin` à chaque proclamation (ne pas le retirer : la contestation en dépend). Fraudes électorales par le serveur (`fraude_electorale_tenter`, `20261027080000`). Vote de confiance par le serveur (`20261027090000`). **Justice** (`20261027100000`-`100200`) : `recherche_retirer` refuse le retrait libre (seulement
  juste après un écrou, ou désertion éteinte) — **Codex : tout nouveau retrait de motif passe par
  une fonction serveur qui sait pourquoi** ; `enquete_garde_a_vue` n'est plus appelable ;
  convocations tenues par le serveur (`convocation_se_justifier`, `minuit_convocations`). **Crime** (`20261027110000`/`110100`) : socle pénal serveur (détection, trace, découverte de nuit) ; neutraliser, incendier, explosifs par le serveur ; `impact_deposer('hp_set')` refusé et `batiments_fermes` fermée aux joueurs — **Codex : un dégât ou une fermeture se pose dans la fonction serveur de l'acte**. Vol et empoisonnement par le serveur (`crime_voler`, `crime_empoisonner`, `20261027120000`/`120100`) ; `vols_en_attente` n'est plus écrite par les joueurs. Détection des ordres illégaux, corruptions, contrebande et falsification par le serveur (`20261027130000`) — **Codex : un nouvel acte illégal tire sa détection dans sa fonction serveur (`crime_detecter_interne`), jamais par `checkDetection` à l'écran**. Scandale de la nuit par le serveur (`minuit_scandale`, cron). **Codex : une réponse serveur qui change l'inventaire rend `inventory` et `revision`, et l'écran adopte la réponse elle-même (`sbAdopterInventaireServeur(v)`)**. Informateurs par le serveur (`informateur_recruter`/`_interroger`/`_congedier`, `minuit_informateurs` au cron) ; la colonne `informateurs` n'est plus écrite par l'écran ; interroger coûte 1 PA (Fred). Marché noir (armes, explosifs) et suites de la neutralisation d'un député par le serveur. **Codex : `corrompre_fonctionnaire_permis` (terrains) et le hooliganisme (organisations) écrivent encore leur trace de crime à l'écran ; à passer par `crime_tracer_interne` dans vos chantiers, après quoi la découverte cliente (`verifierDecouverteCrimesPasses`) pourra disparaître.** Rumeurs : `rumeur_lancer` ; les causes `rumeur_pj`/`rumeur_gouvernement` sont fermées aux joueurs. **Attention : `inventaire_sauver_revision` accepte encore tout inventaire du navigateur (voir l'audit) ; tout nouvel objet doit être déposé par le serveur.** **Chantier inventaire EN COURS (Claude, Fred : « Oui, maintenant », 27/10)** : lots 1 à 3 fusionnés (achats d'armes, gilet, poisons, relique, récolte, produits du marché, tracts ; dépôt serveur unique `inventaire_deposer_interne`, catalogue `objets_modeles`). Reste à faire, dans l'ordre : sels d'ammoniaque (`confirmerAcheterSels`, caisse `pays_usine-pharmaceutique-luthecia`), objets trouvés (`reclamerObjetTrouve`), fret (4 sites de `plateau-justice-economie.js`), employés (`plateau-multijoueur.js`), état civil, énigmes, missions de PNJ et escort, effort de guerre, acte d'entreprise et publications ; documents d'urbanisme et vol de matériaux (terrains), récompenses de quête et accessoires de club (organisations, championnat) = **Codex** ; puis, en dernier, le verrou : `inventaire_sauver_revision` ne doit plus accepter d'ajout venu du navigateur. Liste des sites : `grep -n "addToInventory(\|inventory.push(" plateau-*.js`.
- **Corrections « une seule vérité » (Fred, 26/10 : « fais dans l'ordre que tu veux »)** — Claude.
  Fait : caisses adossées (`fonds_en_transit`, `batiment_caisse_client_crediter`, primitives de
  caisse retirées au navigateur, `usine_virer_vers_ministere`, `ministere_virer_vers_usine`,
  `imprimerie_acheter_bois`). **Codex : tout nouveau crédit de caisse se fait dans la fonction
  serveur de l'action** ; un crédit demandé par le navigateur doit être adossé à un paiement.
  Suite prévue : tables ouvertes (hors successions, terrains, urbanisme, championnat), fiche,
  ordre générique.
- **Audit « une seule vérité » (26/10, nuit, branche `claude/audit-une-seule-verite-20261026`)** :
  `AUDIT_UNE_SEULE_VERITE.md` inventorie tout le jeu (tables ouvertes à tout joueur, RPC
  qui créent de l'argent sur demande, champs de fiche encore libres, ~95 tirages et l'ordre
  générique décidés par l'écran, passe de minuit cliente, échéances à l'horloge du
  navigateur, deux affichages, code mort). **Rien n'est corrigé hors ambassades et BNE** :
  l'ordre des chantiers est à décider par Fred. Corrigé côté ambassades : annonces publiques
  par le serveur, traités lus sur le serveur (migration `20261026010000`).
- **Décisions de la série de questions (25/10, branche
  `claude/decisions-ambassades-bne-20261025`)** : Indice Diplomatique réel, un par pays
  (`indices_diplomatiques` + journal, `indices_diplomatiques_lire`, seule écriture
  `indice_diplomatique_varier_interne`) ; toutes les variations par le serveur
  (`ambassade_ouvrir`, `ambassade_reception_organiser` avec présence,
  `ambassade_mecenat`, `ambassade_reserver_salle`, patchs de
  `communication_officielle_publier`, `guerre_cessez_le_feu_activer`, `guerre_declarer`,
  `indice_diplomatique_ordre` pour mobilisation / banquet / réception d'État,
  `diplomatie_repondre`). Le client ne modifie plus `INDICES_NATIONAUX[p].ID` : il la
  recharge (`chargerIndicesDiplomatiques`). Corruption d'un homologue supprimée ; Bureau de
  direction du BNE supprimé ; ouvriers PNJ payés au taux du propriétaire
  (`reliquatNPCServeur`) ; caisse du BNE ouverte au Ministre des Finances
  (`bne_caisse_lire`, `bne_caisse_prelever`, ordre `bne_caisse_prelever`). Migrations
  `20261025120000`, `120100`, `120200`.
- Contexte : objectif actuel = terminer Luthécia. Les ambassades ne seront
  raccordées aux autres empires que lorsqu'ils seront codés (arbitrage
  Fred, 24/10). Nouvelle règle de Fred : **une seule réalité, celle du
  serveur** (voir `AGENTS.md`).
- PR #142 (branche `claude/ambassadeurs-pnj-20261024`) : trois ambassadeurs
  PNJ reçus **sur audience seulement** — Valery Antonov (Sovarka, la
  rigidité), Guillermo Vasquez (El Estado, la corruption), Mohamed
  Al-Mansoori (Al-Khalija, le snobisme). Fenêtre à la charte ardoise et or.
  **Fusionnée le 24/10.** Son tirage de 70 % côté navigateur est remplacé par
  le parcours d'audience ci-dessous.
- PR #141 (branche `claude/audit-ambassades-20261024`, documentation) :
  `AUDIT_AMBASSADES.md` v2 (game design retrouvé, 12 écarts écran/serveur)
  et `AUDIT_BNE.md` (audit complet du Bureau). Chacun finit par les
  questions à trancher par Fred.
- **Audiences d'ambassade (nouveau parcours, arbitrage Fred 24/10)** — branche
  `claude/audiences-ambassades-20261024` : demande à l'accueil (1 PA, une par
  ambassade) → mail « transmise » → délai tiré par le serveur (0 à 3 jours,
  jamais de refus) → mail « accordée » → bureau ouvert 48 h pour ce joueur,
  ambassadeur PNJ dedans. Fonctions `ambassade_*` **appliquées en production**
  (registre 20261024185323 et 20261024185346), baseline pas encore
  réextrait. Passe de nuit ajoutée dans `api/cron-minuit.js`.
- 25/10 : voyants de la messagerie synchronisés (bouton « Messages/Forums »,
  « Boîte Mail », « Mails reçus » lisent la même copie de ce que rend le
  serveur), et règle commune : **l'agent fusionne lui-même** quand les
  contrôles passent (voir `AGENTS.md`).
- 25/10 : **`GAME-DESIGN-AMBASSADES.md`**, la référence des décisions de Fred
  (secrétaires PNJ, naturalisation, transfert de détenus, asile, valise,
  immunité, réceptions ; visas et dépêches écartés). Portes du hall
  cliquables et onglets avec infobulle « Accès limité : il faut avoir une
  invitation. » (branche `claude/portes-ambassades-20261025`, fonction
  `ambassade_acces_bureaux` appliquée, registre 20261025002311).
- 25/10 nuit : **asile politique** (branche `claude/asile-ambassades-20261025`) :
  demande à l'accueil (2 PA), décision de l'ambassadeur PNJ selon le dossier
  (recherché ou affaire vivante) sous 0 à 3 jours, mail ; le réfugié entre
  dans le bureau de son ambassade et ne peut pas être arrêté au Quartier des
  Ambassades (patch de `detention_ouvrir_interne` et `police_detection_verifier`,
  + déclencheur filet). Trois migrations appliquées (registre 20261025004912,
  20261025004941, 20261025005227).
- 25/10 nuit : **corrections du Bureau de l'Emploi** (branche
  `claude/bne-corrections-20261025`) : B1-B7, B9, B10 et un bug trouvé au banc
  (aucun emploi n'était payé). Migration appliquée (registre 20261025010423).
  Détail dans `AUDIT_BNE.md` § 6.
- 25/10 soir : **nouvelle formule du Bureau de l'Emploi** décidée par Fred,
  consignée dans **`GAME-DESIGN-BNE.md`** (recensement des postes réels tenus
  par des PNJ, candidature transmise au recruteur officiel avec décision le
  vendredi, annonces des joueurs, virement automatique, suppression des sept
  offres fictives et de l'inscription).
- 25/10 soir, **lot 1 livré** (branche `claude/bne-recensement-20261025`, registre
  20261025181516) : sept offres et inscription supprimées, mail aux titulaires,
  écran « Postes à pourvoir » lu sur `bne_postes_a_pourvoir` ; candidature par le
  circuit existant du 25 août (Fred : « on conserve l'ancien fonctionnement en
  entier ») ; capitaine/lieutenant postulables depuis le Bureau.
- 25/10 soir : **1 PA par candidature** (registre 20261025182135) et **lot 3,
  annonces des joueurs** (registre 20261025183757 : `bne_annonces`,
  `bne_annonce_publier/lister/retirer`, option Tribune 30 FR versés à la caisse
  `<pays>_bureau-national-emploi`).
- 25/10 soir : **taux horaire des chantiers** fixé par le titulaire, minimum 50 FR
  (registre 20261025193111) : action `taux` de `chantier_commande`,
  `chantier_taux_definir`, `chantier_travailler` paie au taux du chantier. **Codex :
  touche à tes fichiers construction** (`plateau-construction-commandes.js` : ordre
  dynamique `taux_chantier` ; `plateau-chantiers.js` : `tauxHoraireChantier`). Le
  travail PNJ (cron) reste au taux de référence de 70 FR.
- 25/10 soir : **virements entre joueurs** (registre 20261025194235 et
  20261025194255) : `banque_virement`, `banque_virement_automatique_creer`,
  `virements_automatiques_mes`, `virement_automatique_arreter`, passe de nuit
  `virements_automatiques_executer` (cron). Tous les lots de `GAME-DESIGN-BNE.md`
  sont livrés ; reste la question du Bureau de direction (fin de chantier).
- 25/10 soir : **trois référentes emploi** (Nathalie Boulot, Edwige Leroux, Pétra
  Vaillepas), fiches dans `api/_pnj-referents.js`, déclarées dans `pnj_referents`
  (registre 20261025201502).
- 25/10 nuit : **fin des chantiers**. BNE : restes retirés, heures de chantier et
  dossier de candidature par le serveur (#162). Ambassades : actions du ministre par
  le serveur, table en lecture seule pour les joueurs, asile tranché par
  l'ambassadeur joueur, secrétaires, valise (registre 20261025210049, …210208,
  …210344). Bloqués par l'absence de voyage entre empires : immunité, arrestation de
  l'expulsé, transfert de détenus, naturalisation (voir `GAME-DESIGN-AMBASSADES.md`).
- Prochaines étapes (Claude) : coder `GAME-DESIGN-BNE.md` par lots — 1. suppression
  des offres et de l'inscription + recensement ; 2. candidatures et décision du
  vendredi ; 3. annonces des joueurs (+ parution Tribune par le serveur, caisse du
  Bureau) ; 4. virement entre joueurs puis virement automatique ; 5. taux horaire
  des chantiers fixé par le propriétaire (minimum 50 FR).
  Ambassades : griser « Bientôt disponible » les ordres non raccordables (en
  attente de Fred).
- Bancs : 85/102 en local, les 17 échecs sont identiques sur `main`
  (bancs navigateur, environnement).
- Issue #143 : passer toutes les fenêtres à la charte (plus tard).

Travaux déjà ouverts avant la mise en place du relais (pull requests
existantes, à reprendre si Fred le demande) :
- #139 `integration/livraison-terrain-135-20261024` — terrains : occupation
  transactionnelle, réaménagement, protection des locaux (issue #135).
  Restent L11 acquisition/financement, L04 prêt conso, L09 bénédiction.
- Nombreuses PR WIP plus anciennes (construction #94, successions #95,
  interception policière…) : voir la liste des PR ouvertes.

## Derniers chantiers

- 24/10/2026 — Mise en place du relais Codex/Claude (`AGENTS.md`,
  `CLAUDE.md`, `RELAIS.md`).
