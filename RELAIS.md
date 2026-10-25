# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

**Ambassades et Bureau de l'Emploi : chantiers de Claude seul** (Fred, 25/10). Ces
notes sont la trace du travail, pour reprendre l'historique. **Codex : ne pas toucher aux
ambassades ni au Bureau de l'Emploi.**
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
