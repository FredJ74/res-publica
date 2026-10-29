# Relais entre agents

Passage de témoin entre Codex et Claude. Mis à jour à **chaque push**.
Règles : voir `AGENTS.md`.

## En cours

### PNJ de Luthécia sans profil — Claude 29/10 (branche `claude/pnj-profils-luthecia-20261029`, empilée sur #227)

- Fiches de personnalité DeepSeek écrites dans `api/_pnj-personnalites.js` pour **Marcel Silo** (directeur de l'Entrepôt Logistique, validé par Fred le 29/10 : intendant tatillon, soupçonné de laisser filer des palettes, ne l'avoue ni ne propose rien), **Bernard Piluler** (directeur de l'Usine Pharmaceutique : une pilule pour tout, langue de communiqué) et **Jean Bonde** (espion, rue du Quartier des Ambassades : se croit invisible, phrases codées). Les deux dernières écrites sur délégation de Fred, à sa relecture.
- Aucune règle de jeu : ils restent sous la consigne des PNJ ordinaires (ni prix, ni marchandise, ni renseignement vendu). Les « hôtes de l'agence » restent sans profil, volontairement.
- Banc `banc-dialogue-pnj-republia.js` : les deux directeurs retirés des muets déclarés, contrôle nominatif des trois fiches (Jean Bonde est dans une scène de rue que l'inventaire ne parcourt pas). 43/43 ; bancs de dialogue voisins verts. Inventaire des PNJ mis à jour.
- **À inclure dans la livraison groupée avec #227** (cette branche la contient). Test : parler à chacun des trois, vérifier le ton et qu'aucun ne promet de marchandise ni de renseignement.
- Restent muets, hors Luthécia : Yvon Paletier, Norbert Charton (entrepôts de PSM et Montrouge), deux avocats commis d'office.

### Stabilisation Luthécia cinq points — ChatGPT 28/10

- **Connexion/création PJ (nouveau correctif) :** dans `sbCreerPersonnageUnique`, un rejet réseau de `fetch` pouvait remonter comme exception non gérée plutôt que réponse métier. Gestion explicite `creation_incertaine`, sans rejeu d'INSERT (il peut avoir été effectué). Quatre scénarios sur fonction réelle ajoutés dans `banc-creation-personnage-reseau-20261028.cjs`, raccordés au workflow client. Vérification CI en attente à ce stade ; aucun compte réel touché.


- **CI du nouveau banc navigation :** `coherence-client.yml` lance désormais explicitement `node outils/bancs/banc-sortie-reponse-perdue-20261028.cjs` (commit `c0365a6`). Workflow GitHub #40725306741 déclenché, état initial `pending` ; ne pas présenter le banc comme réussi avant conclusion. Aucun déploiement ni donnée joueur modifiée.


- **Navigation (nouveau banc) :** corps vivants `rue_position_enregistrer`, `rue_position_lire`, `rue_sortie_batiment_lire` relus en lecture seule ; banc `banc-sortie-reponse-perdue-20261028.cjs` poussé commit `4fa955f` pour vérifier réponse perdue sans double mutation. Exécution CI du nouveau banc non encore confirmée ; recette authentifiée toujours à faire.


- **Nouveau rapprochement vivant banque, 28/10 :** `fonds_credits_uniques` enregistre une régularisation de 100 000 FR pour le prêt travaux de Jean Jaaj, le 18/10 à 20:27 UTC (`pret-1792353270892`). Un deuxième prêt de 10 000 FR existe aussi, distinct. Les soldes actuels ne prouvent pas le crédit initial ou son affichage. **Ne pas régulariser une seconde fois** ; audit dans `PREVOL-CINQ-POINTS-LUTHECIA-20261028.md`, commit `358aedb`. Aucun solde modifié.

- **Complément vérifié CI / banque (commit `fe952ac`) :** cinq workflows PR #218 au vert ; le journal confirme `OK banc-reception-rest-20261028.cjs`. Prêt travaux national de Jean Jaaj de 100 000 FR présent dans Supabase, restant 76 997 FR, deux comptes distincts ; versement initial non démontré. Rapport prévol enrichi. Aucune écriture en base ni déploiement.

- Branche isolée `chatgpt/fiabilisation-luthecia-20261028` issue de main, hors inventaire et groupes. Audit détaillé `outils/audits/PREVOL-CINQ-POINTS-LUTHECIA-20261028.md`.
- **Navigation :** sortie serveur `rue_sortie_batiment_lire` / `rue_position_enregistrer` vérifiée ; zéro noeud de sortie orphelin sur 36 sorties Luthécia, 33 PSM, 41 Montrouge. Les sorties manquantes et cas d'écran bloqué restent à tester authentifié.
- **Réception :** le transport REST transformait un HTTP 200 à JSON illisible en succès `donnees:true` ; correction dans `supabase.js` : `reponse_invalide`, pas de réessai aveugle d'écriture ; 204 conservé. Banc isolé `banc-reception-rest-20261028.cjs` ajouté, non exécuté ici. La panne remontée par les joueurs n'est pas déclarée résolue.
- **Banque :** contrôle agrégé, 2 prêts, 3 placements, aucun montant négatif ; versements / écarts de solde pas encore rapprochés. **Vercel :** production `READY` sur main `3a9b0c5d`, les previews Codex ne sont pas la production. Contrôle SQL réutilisable `banc-luthecia-controle-navigation-banque-20261028.sql` exécuté en lecture seule.
- **Recette générale** : priorités et défauts restants inscrits dans le rapport. Aucune migration ni déploiement production ; aucun personnage modifié.


### Fiabilisation GitHub / Vercel — 28/10, Codex

- **Complément demandé par Fred après création manuelle de la PR : Workflow corrigé.** Deux doublons SQL supprimés au profit des fixtures existantes `banc-fixture-*` (mêmes corps), trois sources déplacées octet pour octet dans `historique/fixtures-bancs/`, quatre bancs Python raccordés. Aucun SQL métier ni inventaire modifié. Le vérificateur `verifier-workflow.py` reste strictement inchangé ; les neuf familles passent. Nouveau banc de rangement : six tests dont trois refus explicites des mauvais rangements/enveloppes. PostgreSQL jetable : permis 56, Céd/football 45, construction 62 (et variante #112 : 62), banque 61 (et variante location : 61), parcours cinq terrains 324. Les variantes partagent leurs assertions : ne pas additionner comme des cas distincts. Contrôleur client complet après rangement : **107/107 bancs réussis**. Aucun accès production ni migration appliquée.

- Branche isolée **`codex/fiabilisation-ci-20261028`**, issue du main `da5ecc0`. Aucun fichier du jeu, de l'inventaire, des ambassades/BNE ou aucune migration modifié. L'inventaire reste confié à Claude ; Fred a ensuite autorisé explicitement la correction du seul rangement des cinq fixtures SQL (28/10), sans toucher à l'inventaire.
- Défaut reproduit du contrôleur : enfant encore actif après expiration du délai, diagnostics partiels jetés. Correction de l'arrêt du groupe privé, journaux conservés après timeout, distinction lancement/timeout/assertion et résultats JSON progressifs avec état complet/interrompu ; TERM nettoie aussi. Aucun verrou métier ni délai assoupli.
- Deux workflows coûteux rejoignent la politique existante d'annulation des seules anciennes exécutions d'une même PR (parcours immobilier et placements). Tests et noms de contrôles conservés ; main n'est pas annulé. Configuration distante et `vercel.json` inchangés.
- Vérifié localement : **106/106 bancs** avec le lanceur Linux du dépôt sans adaptateur externe ; **105/105 pilote local**, **7 régressions Python**, **24 tests ciblés**, **3 mutants détectés**, **3 passages Chromium (27/27 scénarios)**, **11 tests calendrier/placements**, **23 API** syntaxiquement valides ; payload **256,5/330 Mo**, 12 YAML analysés. Les comptes se recouvrent, ne pas les additionner.
- Rapport et preuves : `outils/vercel/FIABILISATION-20261028.md`, `outils/vercel/preuves-20261028/`. API GitHub runs/PR refusée ; HTTPS Vercel refusé par le proxy. Pas de résultat distant observé, pas de fusion/déploiement demandé ni effectué. Code et preuves poussés au commit `7777b42`. Création de PR réellement tentée après push : GraphQL `Forbidden`, aucun numéro créé. Branche prête pour revue, non fusionnée.


### Sécurité privée #135 — arbitrages du 27/10 (ChatGPT)

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
