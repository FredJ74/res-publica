# Mission « Purge » (24/11/2026) — blocs G (élections), H (décisions du 23/11 au soir) et E (divers)

Branche `claude/purge-ghe-20261124` (depuis `main` f73a9ebd), un commit par point. Agent : Claude.

## Suivi des décisions

| Date | Point et décision | État | Commit | Source |
|---|---|---|---|---|
| 24/11/2026 | G.1 Secrétaires de mairie et officiers des salles des partis des trois villes de Sovarka = référents élections (comment se présenter) ; inscrits dans `pnj_referents` (liste du PNJ guide, A.10) | en cours (migration à appliquer) | 198977c7 | consigne de Fred ; `api/_pnj-personnalites.js` (`SAVOIR_CANDIDATURE_SOVARKA`), migration `20261124140000` |
| 24/11/2026 | G.2 Calendrier électoral en cartes : étape en gros, frise Candidatures → Campagne → Vote → Résultats, règle dans le « ? », heures et second tour derrière « Détails » | en ligne à la fusion | 1f95ac60 | `plateau-politique.js`, `style.css` (`hg-cal-*`, `hg-aide-rond`) |
| 24/11/2026 | H.1 Salle d'attente (visiteurs) et chambre (hospitalisés) séparées dans les six hôpitaux publics de Sovarka et de Républia | en ligne à la fusion | 9b6f8d1b | `GAME-DESIGN-HOSPITALISATION.md` ; `data.js` (`HOPITAUX_PUBLICS_SALLE_ET_CHAMBRE`) |
| 24/11/2026 | H.2 Bureaux du centre d'affaires de Krasnov : loyer de départ 30 PSK/jour, réglable par le maire de 0 à 40 | en cours (migration à appliquer) | b801d7a6 | point 32 ; migration `20261124141000` |
| 24/11/2026 | H.3 Musée de Krasnov : Arkadi répond aux questions libres, 1 PA pour 3 questions par salle et par jour | en cours (migration à appliquer) | 59998b7a | point 29 ; migration `20261124142000`, `api/chat.js`, `plateau-guide-arkadi.js` |
| 24/11/2026 | H.4 Habitué du Bar Sever = Prokop Stakanov ; 3 h entre deux visites, un verre par jour (réglages déjà à 3 et 1) | en cours (migration à appliquer) | f53533fa | point 25 ; migration `20261124143000` |
| 24/11/2026 | H.5 Matveï Rybakov devient le PÈRE de Prokhor Rybakov (fiches, documents points 28 et 37) | en ligne à la fusion | 37671543 | points 28 et 37 |
| 24/11/2026 | H.6 Pas d'ordre « Chasser » (aucun n'existait) ; l'ours se rencontre en explorant ; phrase de Fred chez Matveï, Nina et le commissaire | en ligne à la fusion | e22ccc45 | `GAME-DESIGN-FORET-KRASNOV-20261121.md` |
| 24/11/2026 | H.7 Grange Sainte : image gardée ; « Frère Kolkhoze » devient « Diacre laborieux » (fiche et mentions) | en ligne à la fusion | 27aa3ad7 | point 39 |
| 24/11/2026 | H.8 Légendes des dix cartes postales, mot pour mot (toutes les cartes existaient) | en ligne à la fusion | 7d2c8f06 | `GAME-DESIGN-INTERFACE-ACCUEIL-20261122.md` point 28 |
| 24/11/2026 | H.9 Dépôt des cartes postales dans l'armoire à souvenirs | décidé — bloqué (le serveur n'a que le critère, pas de dépôt) | 37b9e930 | `GAME-DESIGN-APPARTEMENTS.md` |
| 24/11/2026 | H.10 Feuille volante de l'énigme : personne ne la possède, rien à mettre à jour | décidé — rien à faire | — | consigne de Fred |
| 24/11/2026 | H.11 Quête « Une affaire mystérieuse » : le texte nomme le Sergent Bogdan Zatvorov, Armurerie Militaire de la Caserne centrale de Novomirsk | en cours (migration à appliquer) | 49826d7a | point 44 ; migration `20261124144000` |
| 24/11/2026 | E.1 « Inspecter les lieux » dans la rue à 0 PA | déjà en ligne (ouverture gratuite ; seule la fouille coûte 1 PA, comme en pièce) | — | point 10 ; banc `banc-bloc1-suites-rapports-20261123.cjs` |
| 24/11/2026 | E.2 Vraies fautes dans les noms d'images (acceuil, EPHAD, amabassades), avec redirections | en ligne à la fusion | 26e14c64 | `vercel.json` (5 réécritures) |

## Migrations à appliquer (agent principal, à la fusion)

Toutes rejouables, éprouvées deux fois de suite sur PGlite par leur banc.

1. `20261124140000_ghe_g1_referents_elections_sovarka.sql` — 4 référents ajoutés à `pnj_referents` (Petchatkina, Balatov, Dokladova, Doznaïev), domaine de Sayana Tsydypova et du lieutenant Zhalsaraev complété. Contrôle : `SELECT referent_id, domaine FROM pnj_referents WHERE domaine LIKE 'élections (comment se présenter)%'` → 6 lignes.
2. `20261124141000_ghe_h2_bureaux_krasnov_loyer_30.sql` — bureaux 1 à 4 du centre d'affaires de Krasnov : loyer 40 → 30 (seulement sans demande ni exploitant). Contrôle : `SELECT piece, loyer, plafond FROM sovarka_locaux WHERE ville='ville_b' AND batiment='centre-affaires'` → 30/40.
3. `20261124142000_ghe_h3_arkadi_questions_musee_krasnov.sql` — `guide_musee_salle_interne` reconnaît les six salles du musée de Krasnov (« krasnov: »). Contrôle : la définition contient `ghe_h3_arkadi_v1`. **À déployer avec `api/chat.js`** (sinon Arkadi cliqué répond « Guide absent » faute de préfixe connu).
4. `20261124143000_ghe_h4_prokop_stakanov.sql` — `informateurs_pnj.nom` de `habitue_krasnov` = Prokop Stakanov ; libellés MJ. Contrôle : `SELECT nom FROM informateurs_pnj WHERE id='habitue_krasnov'`.
5. `20261124144000_ghe_h11_quete_armurier_militaire.sql` — texte de la quête `quete-1790260995706`. Contrôle : `SELECT description FROM quetes_actives WHERE id='quete-1790260995706'` contient « Sergent Bogdan Zatvorov ».

## Pour Codex (textes français nouveaux ou changés, traduction en pause)

- `plateau-politique.js`, calendrier électoral : étapes « Candidatures ouvertes », « Campagne », « Vote en cours », « Second tour — campagne », « Second tour — vote en cours », « Départage du 3e siège — campagne / — vote en cours », « Dépouillement », « Poste vacant — candidatures ouvertes », « Mandat en cours », « Aucun scrutin en cours » ; frise « Candidatures / Campagne / Vote / Résultats » ; « Aucun parti pour l'instant. », « Aucun candidat pour l'instant. » ; boutons « Détails », « Bureau de vote → » ; en-tête « Les scrutins de {pays} et de {ville} » ; bulle « Un mandat dure 5 semaines : candidatures pendant les 4 premières, campagne la 5e. On vote le dernier dimanche, résultat à minuit ; un second tour, si nécessaire, a lieu le dimanche suivant. » (remplace le bandeau « Mandat de 5 semaines · … ») ; `aria-label` « Aide : … ».
- `data.js`, salles d'attente : « La salle d'attente de l'hôpital. On y vient en visiteur ; les patients hospitalisés restent dans leur chambre. » (Luthécia, PSM, Montrouge, Starovka) ; Krasnov inchangé. Catalogue des descriptions de pièces à revoir.
- `plateau-guide-arkadi.js`, `ARKADI_QUESTIONS` (13 textes : titre, intro, ouvrir, placeholder, demander, vous, attente, fini, refus).
- `plateau-pnj.js`, refus d'un guide : « Le guide répond à vos questions dans sa fenêtre « Écouter le guide » : 1 PA pour trois questions dans cette salle, aujourd'hui. » ; « Vous avez posé vos trois questions dans cette salle aujourd'hui. »
- `plateau-social-pnj.js` : « Prokop Stakanov, l'habitué du Bar Sever, vous offre un verre. » / « … vous reconnaît. » ; nom affiché « Prokop Stakanov ».
- `data.js` : PNJ « Diacre laborieux », rôle « PNJ - Diacre du Tractorisme » (`i18n/sovarka-roles-resources.js` a encore « Enfant de chœur laborieux »).
- `plateau-personnage.js`, `TEXTES_CARTE_POSTALE.fr` : dix clés `legende_carte_*` (textes de Fred, mot pour mot).
- Fiches DeepSeek (prompts, pas d'i18n) : `SAVOIR_CANDIDATURE_SOVARKA`, `OURS_NE_SE_CHASSE_PAS`, Prokop Stakanov, Diacre laborieux, Matveï/Prokhor père et fils.

## Bancs

Nouveaux (verts en local) : `banc-ghe-g1-referents-elections`, `-g2-calendrier-cartes` (Chromium, 1280 et 390 px), `-h1-hopitaux`, `-h2-bureaux-krasnov`, `-h3-arkadi-questions`, `-h4-prokop-stakanov`, `-h5-rybakov-pere-fils`, `-h6-ours`, `-h7-diacre-laborieux`, `-h8-legendes-cartes`, `-h11-quete-armurier`, `-e2-noms-images` (tous `…-20261124.cjs` ; PGlite via `PGLITE_DIR`).
Mis à jour (décision changée à la source) : `test-hopitaux-chambre-partout`, `test-montrouge-hopital-chambre`, `test-hopitaux-sovarka-chambre`, `banc-bloc4-krasnov`, `test-ilia-guide-musee`, `test-bloc3-pnj-sovarka`, `banc-bloc6-novomirsk`, `banc-bloc5-contenus`, `banc-tabac-presse-navigateur`, et les trois bancs d'images renommées.
Faux rouges d'environnement : `banc-deploiement-sobre` (« syntaxe API portable », JavaScriptCore de macOS, module de test synthétique) ; `banc-i18n-transport-catalogues` (Chromium intégré) ; `banc-bloc4-krasnov` sans `NODE_PATH` (vert avec).

## Questions de game design rencontrées

- H.6 : « les bûcherons » — aucun PNJ bûcheron n'existe (le camp de bûcherons est un nœud du goulag, réservé) ; faut-il en créer ?
- H.9 : dépôt dans l'armoire installée seulement ? par le seul propriétaire ou quiconque a la jouissance du local ? une carte postale compte-t-elle dans les douze souvenirs exacts de la liste (aucune carte n'y figure) ?
- E.2 : renommer aussi les ~45 images dont le nom contient des espaces (ex. rues de Krasnov, salles du musée national) et la faute « Starkova_rue_magasin chasse » ? (non fait : renommage en masse rejeté).
- H.11 : aucun écran ne lit `quetes_actives` (`sbGetQueteActive` n'est appelé nulle part) : la quête n'est visible par personne.
- G.1 : le titre « Président de la commission électorale » (Starovka) et « Responsable électorale » (Krasnov) n'étaient pas dans la consigne : non référents « élections » de plus (Dugar Tsyrempilov l'est déjà) ; à étendre ?

## Ce qui reste

- H.9 : dépôt serveur à coder après les réponses de Fred.
- Appliquer les cinq migrations (et déployer `api/chat.js` avec la n° 3).
- Écart relevé, non corrigé (hors consigne) : `PNJ_REFERENTS` (client) cite `arseni_ledokolov` alors que la migration du 18/11 inscrivait `gleb_ledokolov` ; la base porte `arseni_ledokolov` (cohérent).
- Choix technique signalé (G.1) : un PNJ « ordinaire » qui porte un savoir de référent (Kouzma, Praskovia, Matveï, Sayana…) recevait la consigne « TU NE CONNAIS AUCUNE REGLE DU JEU », contradictoire ; il reçoit désormais la consigne des fiches riches (« tu ne sors pas de ton domaine »).
