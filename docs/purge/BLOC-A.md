# Purge — bloc A : accueil, fenêtres et PNJ guide (Claude, 24/11/2026)

Branche `claude/purge-a-20261124`. Consigne de Fred mot pour mot : `GAME-DESIGN-ACCUEIL-FENETRES-PNJ-GUIDE-20261124.md`.
A.6, A.7 et A.9 : confiés à un autre agent (non traités ici).

## Suivi

| Date | Point et décision | État | Commit | Source |
|---|---|---|---|---|
| 24/11/2026 | A.1 Comptes de test marqués (`comptes_test`, par nom ou par compte : reroll compris) ; exclus du tirage au sort des candidatures, du dépouillement des élections (cron), du tirage du commerce du PNJ guide | en cours (migration à appliquer) | afe94b5c | GAME-DESIGN-ACCUEIL-FENETRES-PNJ-GUIDE-20261124.md |
| 24/11/2026 | A.2 Pop-up de bienvenue (texte exact, icône réelle du bouton d'aide, croix seule, jamais recouverte, grande croix sur téléphone) | en cours (migration à appliquer) | cefbdc35, c2542081 | idem |
| 24/11/2026 | A.2 Signature de la bienvenue : PNJ d'accueil à créer par Fred (emplacement vide, `accueil_parametres_textes`) | **en attente de Fred** | | idem |
| 24/11/2026 | A.3 Calendrier du nouveau venu tenu par le serveur (temps de jeu cumulé, interview 5–10 min, report PNJ, forcée à 30 min, première heure sans fenêtre automatique, une fenêtre par connexion + badges) | en cours (migration à appliquer) | 80f0f6c9, c2542081 | idem |
| 24/11/2026 | A.4 Interview signée par le journaliste du pays ; presse filtrée par pays ; article de Bernard re-signé Vera Pravdina et rangé en Sovarka | en cours (migration à appliquer) | 0be3a98a | idem |
| 24/11/2026 | A.5 La journaliste demande ce que le nouveau veut être et lui laisse le temps ; six chemins ; reprenable dans Mes objectifs | en cours (migration à appliquer) | 9b1686e3 | idem |
| 24/11/2026 | A.8 Notifications du navigateur pour le chat (bulle avec « ? », réglage, 1 par interlocuteur, 1 par heure, nom et lieu seulement) | en cours (migration à appliquer) | b960c547 | idem |
| 24/11/2026 | A.10 PNJ guide (journaliste du pays + un habitant par ville), serveur seul juge, filtre des noms de partis et de joueurs | en cours (migration à appliquer) | voir le dernier commit A.10 | idem |

## Comptes de test retenus (A.1) — à vérifier par Fred

Relevé en lecture (aucune marque « testeur » n'existait en base ni dans le code) :
- **Arnie** et **Tom Tom** : même adresse de compte (domaines différents), cités comme personnages de Fred dans les consignes du 21 et du 22/11.
- **Bernard Bernardov** : compte sur le domaine du jeu ; c'est le « Bernard » de la consigne.

Non marqués (douteux, à confirmer) : Michel (créé le 23/11, comme Bernard), Flaggy, Rootskain, Angie Porcelana, Ben,
Jean Jaaj, Moustafa Kheimal, Peter Kropotkine, Vince Kubrick. Fred peut en ajouter un par `admin_compte_test_fixer(nom, true)`.
Statistiques : aucune statistique de joueurs n'existe aujourd'hui dans le jeu (relevé) ; `est_compte_test(nom)` est prête.

## Habitants guides créés (A.10)

| Ville | Lieu (image existante) | Nom | Fiche DeepSeek |
|---|---|---|---|
| Luthécia | Marché Central (`images/marche.webp`) | Firmin Badaud, retraité, badaud du marché | `guide_firmin_badaud` |
| Port-Sainte-Marie | Marché, les étals (`images/port-sainte-marie-marche.webp`) | Yvonne Bigorneau, ancienne ramendeuse de filets | `guide_yvonne_bigorneau` |
| Montrouge | Marché (`images/montrouge/montrouge-marche-exterieur.jpg`) | Lucien Boulon, cheminot retraité | `guide_lucien_boulon` |
| Novomirsk | Distribution Collective (`images/Sovarka/Novomirsk/Novomirsk_marche.webp`) | Zinaïda Otcheredova, doyenne des files d'attente | `guide_zinaida_otcheredova` |
| Starovka | Marché (`images/Sovarka/Starovka/Starovka_marche_marche_ext.webp`) | Bair Namsaraev, ancien pêcheur bouriate | `guide_bair_namsaraev` |
| Krasnov | Marché (`images/Sovarka/Krasnov/Krasnov_marche_etals.webp`) | Fiodor Medvedkine, apiculteur du kolkhoze | `guide_fiodor_medvedkine` |

« Le PNJ suit l'image » : chaque habitant a pour portrait l'image du lieu où il est placé (aucune image nouvelle).

## PR #1188 (ChatGPT, fusionnée pendant le bloc) — ce qui est repris, ce qui change

Repris : le module `plateau-accueil-progressif.js` et son API (raccords de `plateau-core.js`, `plateau-pnj.js`,
`plateau-quete-accueil.js` inchangés), la bienvenue à croix seule, le garde de Luthécia différé après la découverte.
Changé pour suivre la consigne : texte exact de Fred (A.2), icône réelle recopiée du bouton d'aide, signature vide,
plus de minuterie ni de `localStorage` (temps de jeu, interview, découverte, première heure tenus par le serveur, valables
d'un appareil à l'autre) ; une conversation PNJ ne supprime plus l'interview, elle la repousse de 5 min (forcée à 30) ;
portier « une fenêtre automatique par connexion + badges » ; délai de respiration de 2 min entre deux fenêtres
automatiques pendant la première heure. Le doublon `plateau-fenetres-auto.js` de ce bloc est supprimé (alias
`RPFenetresAuto`). Banc `banc-accueil-progressif-20261124.cjs` adapté (7 tests). La phrase d'aide ajoutée par #1188 sous
la question de l'interview est retirée : la journaliste le dit elle-même (A.5).

## Migrations à appliquer (dans l'ordre ; aucune n'est appliquée)

1. `20261124100000_comptes_test.sql` — marque, fonctions, réglage MJ, tirage des candidatures (remplacement contrôlé, marque `comptes_test_tirage_v1`).
   Contrôle : `SELECT personnage, user_id IS NOT NULL FROM comptes_test;` (3 lignes) ; `SELECT position('comptes_test_tirage_v1' in pg_get_functiondef('candidature_poste_tirage_appliquer'::regproc)) > 0;`
2. `20261124101000_accueil_bienvenue.sql` — `calendrier_depuis` (posé à l'application), colonnes, bienvenue.
   Contrôle : `SELECT valeur FROM accueil_parametres WHERE cle = 'calendrier_depuis';`
3. `20261124102000_accueil_calendrier.sql` — temps de jeu, déclencheur `zz_accueil_temps_jeu` sur `presences`, `accueil_pnj_parle`.
   Contrôle : `SELECT tgname FROM pg_trigger WHERE tgrelid = 'presences'::regclass;` ; un nouveau personnage voit `secondes_jeu` monter.
4. `20261124103000_interview_journaliste_pays.sql` — déclencheur re-signé ; reprise de l'article de Bernard.
   Contrôle : `SELECT author, country FROM forum_topics WHERE id LIKE 'interview-jodie-interview_accueil_%';` → Vera Pravdina / soviet.
5. `20261124104000_accueil_question.sql` — question d'accueil. Contrôle : `SELECT pays, question FROM accueil_journalistes;`
6. `20261124105000_notifications_chat.sql` — réglage des notifications. Contrôle : `SELECT to_regclass('notifications_chat');`
7. `20261124106000_pnj_guide.sql` — habitants, pistes, état, messages, RPC du guide.
   Contrôle : `SELECT count(*) FROM pnj_guides_habitants;` (6) ; `SELECT count(*) FROM guide_pistes;` (42).
Le code navigateur appelle `accueil_bienvenue_vue`, `notifications_chat_lire`, `guide_etat_lire` : sans les migrations, ces
appels échouent sans casse (rien ne s'ouvre). Le PNJ guide exige `SUPABASE_SERVICE_ROLE_KEY` sur Vercel (déjà utilisée par le journal).

## Pour Codex (textes français nouveaux, sans traduction)

- `plateau-accueil-progressif.js`, `TXT` : bvTitre, bv1, bv2, bv3, bvFermer, bvAide, journal, meteo (texte exact de Fred pour bv*).
- `plateau-notifications-chat.js`, `TXT` : propose, aide, activer, nonMerci, titre, parle, quelquun, reglage, actives, coupees, couper, refusees, rue, aideBouton.
- `plateau-pnj-guide.js`, `TXT` : badge, debrouille, arrete, epuise, indispo, aideBadge.
- `migrations/20261124104000_accueil_question.sql` : questions de Jodie Moitout et de Vera Pravdina.
- `migrations/20261124106000_pnj_guide.sql` : `guide_pistes.activite` et `lieu` (42 lignes), noms et lieux des habitants.
- `api/_pnj-guide.js` : texte de secours (`texteSecours`, réponses de secours) — généré en français.
- `data.js` : six PNJ (noms et rôles) ; `api/_pnj-personnalites.js` : six fiches.

## Questions de game design (une par ligne)

- « Goût » du nouveau pour le tirage du commerce : lu comme le chemin choisi à l'interview (affaires, belle vie… ; à défaut, pistes par défaut) ; le métier (carrière) n'est transmis qu'à l'IA. À confirmer.
- La journaliste n'écrit que si l'interview a été donnée (chemin choisi) ; si le nouveau l'a ignorée, seul l'habitant écrit. À confirmer.
- Les deux voix ne concernent que les personnages créés après la mise en ligne (comme le calendrier) : Bernard actuel ne les recevra pas ; tester avec un reroll.
- « Reconnexion » (A.8) : lue comme le retour sur l'onglet du jeu ou le rechargement de la page.
- Notifications seulement quand le jeu n'est pas sous les yeux du joueur (onglet caché ou fenêtre sans focus) : à confirmer.
- Élections : un compte de test ne peut ni voter utilement ni être élu (bulletins et candidature ignorés au dépouillement) — Fred ne peut donc plus tester une élection avec ses comptes de test ; à confirmer.
- Tirage d'une candidature où ne restent que des comptes de test : personne n'est nommé (« aucun candidat éligible »).
- Quête d'accueil de Luthécia (garde du Palais) pendant la première heure : gardée après les 5 min de découverte, séparée des autres fenêtres automatiques par 2 min de respiration ; Fred veut-il la repousser après la première heure ?
- « Revue de presse » : aucune fenêtre de ce nom n'existe ; le journal du jour (kiosque) est la seule fenêtre de presse automatique, mise au badge journal.
- Le déclenchement « après le 3e déplacement » n'existe ni dans main ni dans la base (relevé) : seul le déclenchement à la connexion existait ; retiré pour le calendrier.
- Après la première heure, les fenêtres mises au badge pendant cette heure y restent (elles ne s'ouvrent pas d'elles-mêmes à 60 min).
- Le PNJ guide ne compte pas dans « une fenêtre automatique par connexion » (c'est un message de chat), mais n'écrit jamais pendant qu'une fenêtre est ouverte.

## Bancs (tous verts en local)

PGlite : `banc-comptes-test-20261124.cjs`, `banc-accueil-calendrier-pglite-20261124.cjs` (arrivée de Bernard), `banc-interview-journaliste-pays-20261124.cjs`,
`banc-pnj-guide-pglite-20261124.cjs`, `banc-accueil-interview-pglite-20261123.cjs`. Sans navigateur : `banc-accueil-progressif-20261124.cjs`, `banc-pnj-guide-api-20261124.mjs`.
Chromium : `banc-accueil-calendrier-navigateur-20261124.cjs`, `banc-notifications-chat-navigateur-20261124.cjs`, `banc-pnj-guide-navigateur-20261124.cjs`,
`banc-accueil-interview-navigateur-20261123.cjs`, bancs climat, forum, chat, PNJ liés. Workflow : `.github/workflows/purge-a-accueil-guide-20261124.yml`.
Faux rouges d'environnement : `banc-forums-territoires-local.py` (module pgserver absent). Rouges déjà présents sur main (vérifiés sur une copie de main) :
`banc-i18n-garde-accueil.cjs` (1 échec), `banc-i18n-player-missions-mobile-20261113.cjs` (2 échecs).

## Ce qui reste

- Appliquer les 7 migrations (agent principal), puis recette avec un personnage neuf (reroll de Bernard) : bienvenue, interview entre 5 et 10 min, badges, guide le lendemain.
- Signature de la bienvenue : PNJ d'accueil à créer par Fred.
- Traductions (Codex, 27/11).
