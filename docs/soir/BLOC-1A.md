# Mission du soir du 25/11/2026 — bloc 1A (audit des chances : 1.1, 1.3, 1.4)

Branche `claude/soir-b1a-20261125`, issue de main 985d1c94. Source : `docs/nuit/AUDIT-CHANCES-20261125.md`.
Hors de ce bloc (bloc 1B, 1.2) : article favorable, contrer une campagne, parler à la loge, corruption de journaliste,
fabriquer un scandale, filature, mener une enquête, censure, consulter les dossiers — non touchés ici.

## Ce qui est fait, point par point

- **1.1 Principe** : les descriptions de data.js des ordres de l'audit disent ce que fait le serveur (chance, coût payé même
  en échec, conséquences réelles), sans changer de règle. Les boutons n'affichent plus de pourcentage écrit en dur
  (`plateau-politique.js`, `rateAffiche`) pour trois listes de `plateau-chances-reelles.js` : `ORDRES` (chance lue au serveur,
  pastille « Vos chances réelles : X % »), `SANS_JET` (achat ou exécution assurés : GHB, vipère, campagne de sécurité,
  propagande, emprunt, visite, mobiliser) et `SELON_CIBLE` (la chance dépend d'une cible ou d'un tiers choisi ensuite : blocus,
  douanier, défense, piège, greffier, marchander, cadavre, squatteurs, don, enquête). Le serveur sait désormais lire la
  chance de : bourrer les urnes, falsifier les listes, truquer le dépouillement, contrebande, évasion, rébellion, écouter les
  rumeurs, inspecter les cargaisons, contester des résultats, falsifier un document, voler du matériel de chantier,
  corrompre le directeur ou un gardien du QHS, incendier, fuite d'information (Républia), soins sans trace. Chaque formule est
  sortie dans une fonction que l'ordre ET la lecture appellent (migration 20261125400000, `ordres_chances_audit_interne`).
  « Incendier » (fenêtre « Mon personnage ») n'affiche plus « 30 − ISN » calculé à l'écran mais la chance du serveur.
  Crocheter : la note ne dit plus « ne laisse aucune trace ».
- **1.3a Mobiliser les membres** (siège syndical de Montrouge) : n'appelle plus l'intervention de police. Le bouton ouvre les
  actions de l'organisation syndicale du joueur (autorisation de manifester, grève), chacune à son coût ; sans syndicat, un
  message le dit. Plus de 2 PA fictifs (data.js, seed et `ordres_couts` à 0).
- **1.3b Écouter les rumeurs** chez Galina Karpova (poissonnière de Novomirsk) : lieu déclaré au serveur (95 %, 0 PA,
  source Galina). Les lieux sont tenus dans une seule fonction (`rumeur_ecoute_lieu_interne`).
- **1.3c Inspecter les cargaisons** : le quai de Sovarka est dans `port-novomirsk` (data.js) alors que le serveur attendait
  `port-sovarka` : les deux sont acceptés. Vérifié : c'était bien refusé (« pas_sur_place »).
- **1.3d Fuite d'information** : la fuite d'un document n'a jamais été décidée (texte des toutes premières versions,
  « Version 6 » et « Version 13 » ; aucun document de game design ne la décrit). En Républia, l'ordre est un ordre générique
  (60, effets +10 POP / +5 INF modulés, retour de bâton sur échec critique, détection) ; en Sovarka, il fait fuiter un sondage
  ou le registre des signalements, sans jet. Description alignée ; aucune règle changée.
- **1.3e Falsifier les listes électorales** : échec = 2 jours de détention (au lieu de 20).
- **1.4a Contrebande** : chance plafonnée à 85 % ; la douane est consultée sur un échec comme sur une réussite ; un échec repéré
  fait saisir la contrebande portée sur soi (objets « contrebande » de l'inventaire) et donne un avis de recherche ; l'écran
  dit l'issue réelle (plus de « la douane a repéré » sur un simple échec).
- **1.4b Truquer le dépouillement** : échec = 3 jours (au lieu de 20). Bourrer les urnes reste à 1 jour.
- **1.4c Évasion** : règle du serveur gardée et annoncée ; l'écran affiche les jours réellement ajoutés (2 en Sovarka) au
  lieu de « +1 jour » écrit en dur.
- **1.4d Rébellion** : règle du serveur gardée et annoncée (réussite : jours réellement ajoutés, plus « +1 jour » en dur).
- **1.4e Visiter un détenu** : RPC `prison_visiter` / `prison_visite_detenus` (migration 20261125410000) : sans jet, détenu de
  CETTE prison, une visite par jour et par détenu (pour chaque visiteur), QHS réservé à un avocat inscrit au barreau du pays et
  au conjoint ; 1 PA payé dans la même transaction ; la visite écrit « Visite au parloir. » dans la conversation privée, que
  l'écran ouvre. Sans la migration : « Le parloir est fermé pour l'instant », rien n'est débité (plus de fausse « visite
  effectuée »).
- **1.4f Voler du matériel de chantier** : description réelle. Vérifié au serveur : l'agent de sécurité présent sur le lieu
  impose sa dissuasion (`securite_malus_lieu_interne`, règle #135) dans `crime_voler_materiaux` ; c'est vrai. (Le compte
  `vigiles` du chantier est lu mais inutilisé : seuls les agents présents comptent.)

## Lignes de suivi (à coller dans docs/suivi-decisions.md, section « Mission du soir »)

| Date | Décision | État | En ligne le | Commit | Source |
|---|---|---|---|---|---|
| 25/11/2026 | 1.1 Audit des chances : chaque description suit le serveur sans changer la règle ; plus de pourcentage écrit en dur, « Vos chances réelles : X % » lue au serveur pour 18 ordres de l'audit ; conséquences d'échec annoncées telles quelles (migration 20261125400000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.1 |
| 25/11/2026 | 1.3a « Mobiliser les membres » (siège syndical) ouvre l'organisation syndicale du joueur, plus l'intervention de police ; 0 PA. | en cours |  |  | Mission du soir 1.3 |
| 25/11/2026 | 1.3b « Écouter les rumeurs » chez la poissonnière de Novomirsk : lieu déclaré au serveur (migration 20261125400000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.3 |
| 25/11/2026 | 1.3c « Inspecter les cargaisons » au quai de Novomirsk accepté par le serveur (migration 20261125400000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.3 |
| 25/11/2026 | 1.3d « Fuite d'information » : la fuite de document n'a jamais été décidée ; description alignée sur la réalité (Républia : effets de POP/INF, Sovarka : sondage ou registre, sans jet). | en cours |  |  | Mission du soir 1.3 |
| 25/11/2026 | 1.3e Falsifier les listes électorales : un échec coûte 2 jours de détention (migration 20261125400000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.3 |
| 25/11/2026 | 1.4a Contrebande : chance plafonnée à 85 %, douane sur échec comme sur réussite, échec repéré = saisie et recherche (migration 20261125400000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.4 |
| 25/11/2026 | 1.4b Truquer le dépouillement : échec = 3 jours de détention ; bourrer les urnes reste à 1 jour (migration 20261125400000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.4 |
| 25/11/2026 | 1.4c Évasion : règle du serveur gardée (DUP, ISN ; échec +1 jour, 2 en Sovarka, et 500), annoncée. | en cours |  |  | Mission du soir 1.4 |
| 25/11/2026 | 1.4d Rébellion : règle du serveur gardée (VOL, force du codétenu ; échec −15 DIS, +4 jours, ni transfert ni grilles), annoncée. | en cours |  |  | Mission du soir 1.4 |
| 25/11/2026 | 1.4e Visiter un détenu : sans jet, contrôlé par le serveur (cette prison, une visite par jour et par détenu, QHS : avocat et famille), conversation privée (migration 20261125410000 écrite, non appliquée). | en cours |  |  | Mission du soir 1.4 |
| 25/11/2026 | 1.4f Voler du matériel de chantier : vrai vol, description réelle, l'agent de sécurité posté sur le chantier le protège. | en cours |  |  | Mission du soir 1.4 |

## Migrations, dans l'ordre (écrites, testées en PGlite, NON appliquées)

1. `migrations/20261125400000_audit_chances_regles_lieux.sql` — contrôles en lecture (en tête du fichier) : marques
   `audit_chances_fraude_jours_v1` et `audit_chances_fraude_taux_v1` dans `fraude_electorale_tenter` ; `audit_chances_contrebande_v1`
   dans `crime_contrebande` ; `audit_chances_evasion_v1` et `audit_chances_rebellion_v1` ; `audit_chances_poissonniere_v1` dans
   `rumeur_ecoute_jauges_interne` ; `audit_chances_port_novomirsk_v1` et `audit_chances_inspection_v1` dans `jauges_ordre_executer` ;
   `audit_chances_contester_v1`, `audit_chances_falsifier_v1`, `audit_chances_vol_chantier_v1` ; `audit_chances_soir_v1` dans
   `ordres_chances_lire` (tous vrais) ; `ordres_couts` de `mobiliser` = `0/0` ; `ordres_chances_audit_interne` non exécutable par
   `authenticated` (faux). Ancrages relevés en production le 25/11 au soir (lecture seule).
2. `migrations/20261125410000_visiter_prisonnier.sql` — contrôles : `prison_visiter` et `prison_visite_detenus` exécutables par
   `authenticated` (vrai) et pas par `anon` (faux) ; table `prison_visites` présente (1) ; `ordres_couts` de `visiter_prisonnier` = 1, 0.

**Attention bloc 1B** : 20261125400000 raccorde `ordres_chances_lire` juste avant `END IF; EXCEPTION WHEN OTHERS THEN NULL;` et
réécrit cette ligne à l'identique : un raccord du bloc 1B sur le même ancrage reste possible après la mienne. Une
réécriture complète d'`ordres_chances_lire` par le bloc 1B effacerait la branche `audit_chances_soir_v1` : à fusionner.

## Bancs

- Nouveau : `outils/bancs/banc-audit-chances-soir-pglite-20261125.cjs` (11 tests, PGlite : fraudes, contrebande, évasion,
  rébellion, rumeurs chez Galina, quai de Novomirsk, contester / falsifier / vol de chantier / corruption QHS / incendier /
  ordres génériques, visite au parloir ; écran : descriptions, pourcentages, mobiliser, visite, messages).
- Adaptés : `banc-i18n-communes-partage-20261113.cjs` et `banc-i18n-corps-notifications-20261114.cjs` (lignes et phrases
  remplacées documentées), plans de recette (`preparer-recette97-219.py`, `preparer-livraison-complete-219.py` : la coupe
  historique garde « mobiliser » à 2 PA), `test-i18n-infobulles-communes-20261113.mjs` (anciennes lignes livrées gardées au catalogue, plafond des
  descriptions en attente de traduction), `test-i18n-sovarka-infobulles-20261113.mjs` (rumeur glissée à Galina en attente).
- Contrôleur de la CI en local (`controler-client.py --modifies-depuis ""`, 323 bancs liés) : tous verts sauf 21 bancs qui
  échouent de même sur main 985d1c94 dans les mêmes conditions (bancs historiques lisant l'ancienne copie
  `~/ResPublica`, Chromium local). Verts aussi : `node --test outils/bancs/test-*.mjs` (441 tests), chances réelles, inspection des cargaisons, catalogue
  des ordres, ordres tactiles (Chromium), cambriolage, justice lot 6, climat.

## Pour Codex (français nouveau ou changé, à traduire)

- `data.js`, descriptions (`desc`) des ordres : acheter_ghb, acheter_vipere, blocus_portuaire (×2), bourrer_urnes,
  campagne_securite (×2), contester_resultats, contrebande_port (×3), corrompre_douanier, corrompre_fonct, corrompre_gardien,
  defense (phrase ajoutée), emprunter, escort_piege, lancer_rumeur_cible (×2 dont Galina), greffe_corrompre_dossier,
  greffe_corrompre_faux_casier, falsifier_document, falsifier_listes_electorales, marchander_vote, inspecter_cargaisons (×3),
  fuite_info, tentative_evasion (×2), se_rebeller, truquer_depouillement, propagande_etat (×3, Républia), soins_discrets,
  voler_materiel_chantier, donner_argent_pnj, visiter_prisonnier, ouvrir_enquete, mobiliser (nouvelle). Les anciennes lignes
  du catalogue `i18n/infobulles-communes-resources.js` restent (liste HISTORIQUES du banc) jusqu'à leur remplacement.
- `plateau-justice-economie.js` : `VISITE_REFUS` (cinq motifs), « Le parloir est fermé pour l'instant. », « Aucun détenu dans
  cette prison actuellement. », « Choisir un détenu à visiter (1 PA, une visite par jour et par détenu) : », « Quartier de haute
  sécurité : avocat et famille seulement. », « Déjà visité aujourd'hui. », titres « Parloir fermé », « Visite refusée », journal
  « Visite au parloir : {nom}. » ; messages d'évasion et de rébellion (« +{n} jour(s) »).
- Migration 20261125410000 : message « Visite au parloir. » (écrit dans la conversation).
- `plateau-navigation.js` (contrebande) : « Mais la douane vous a repéré : vous êtes recherché. », « La douane a repéré la
  manœuvre : vous êtes recherché. », « Votre contrebande est saisie. », « La manœuvre a échoué, sans que la douane ne vous
  repère. », entrées de journal correspondantes.
- `plateau-organisations-quetes.js` : toast « Aucun syndicat » / « Vous n'êtes membre d'aucune organisation syndicale… ».
- `plateau-criminalite.js` : `pNote` (crochetage).
- `plateau-personnage.js` : infobulle « Vos chances réelles : X % » du bouton Incendier (texte déjà connu).

## Questions de game design (une par ligne)

- Contrebande : un échec « repéré » saisit la contrebande portée sur soi (objets « Cargaison de contrebande ») ; l'ordre ne coûte
  aucune marchandise à l'achat (0 FR) : faut-il autre chose comme « saisie » (amende, cargaison du jour) ?
- Visite au QHS : « l'avocat » est ici tout avocat inscrit au barreau du pays (aucun lien avocat ↔ détenu n'existe en base) ;
  faut-il le restreindre à l'avocat du détenu (à créer) ?
- Visite : « une visite par jour et par prisonnier » est compté par visiteur (chacun peut voir le même détenu une fois par jour) ;
  ou bien une seule visite par jour au total pour ce détenu ?
- Visite : seule la famille par mariage est « déclarée » en base ; d'autres liens (enfant, parent) doivent-ils compter ?
- « Visiter un détenu » n'existe qu'à l'entrée du QHS ; faut-il l'ajouter aux cellules des commissariats (le serveur le permet) ?
- Mobiliser les membres : le siège syndical de Montrouge n'a pas de syndicat PNJ propre ; le bouton ouvre le syndicat du joueur
  (organisation « syndicale »). Faut-il un syndicat ouvrier de Montrouge, comme celui des Dockers ?
- Ordres génériques (fuite, soins sans trace) : la chance affichée est celle du plein effet ; faut-il afficher aussi la chance
  d'un demi-effet ?
