# Mission « Purge » du 24/11/2026 — bloc B (forums) et points A.6, A.7, A.9

Branche `claude/purge-b-20261124` (depuis main f73a9ebd, qui contient #1184). Un commit par point, dans l'ordre.

## Suivi des décisions

| Date | Point et décision | État | Commit | Source |
|---|---|---|---|---|
| 24/11/2026 | A.6 Case des PA devenue jauge comme Santé et Moral (curseur d'aide, bulle au survol, au clavier et au toucher) ; lien « Plus d'informations sur les PA ? » vers l'infirmière d'accueil de la ville (conversation si on est dans sa pièce, sinon où la trouver) ; fiches DeepSeek des six infirmières complétées pour expliquer les PA ; aucune infirmière créée | en cours (branche) | 30ef95f7 | consigne de Fred, mission Purge |
| 24/11/2026 | A.7 Fenêtre de candidature : conditions cochées en vert ou en rouge (nationalité, présence, domicile, influence, cumul, déjà candidat, période, 2 PA) et dates de la période (candidatures, campagne, vote) ; condition rouge = refus nommé avant tout appel | en cours (branche) | a3edab0c | consigne de Fred, mission Purge |
| 24/11/2026 | A.9 « Aucun message pour le moment » disparaît dès qu'un message existe (il restait quand le premier message arrivait par le relevé périodique) | en cours (branche) | dacea132 | consigne de Fred, mission Purge |
| 24/11/2026 | B.1 Règles d'accès : forum national de son pays (nationalité) toujours accessible ; national du pays visité en lecture seule ; forum local du domicile toujours accessible ; ville visitée en lecture-écriture ; sous-forums nationaux (Présidence, Assemblée, Gouvernement, Presse) suivent le forum national ; contrôlé côté serveur | en cours (migration à appliquer) | 22fbf9bf | consigne de Fred ; GAME-DESIGN-FORUMS.md (règles du 24/11) |
| 24/11/2026 | B.2 Section « Forums locaux » séparée des « Forums nationaux » | en cours (branche) | d28c5e34 | consigne de Fred, mission Purge |
| 24/11/2026 | B.3 Sujets classés de la publication ou réponse la plus récente à la plus ancienne (l'analyseur ne lisait pas les dates écrites par le serveur) | en cours (branche) | 9d68f8ec | consigne de Fred, mission Purge |
| 24/11/2026 | B.4 Dates lisibles « 23/11 à 18 h 48 » (heure de Paris), un seul format dans le forum et le courrier | en cours (branche) | 57f52f75 | consigne de Fred, mission Purge |
| 24/11/2026 | B.5 L'éditeur ne publie plus les blocs vides ni l'amorce « Nouvelle zone de texte… » | en cours (branche) | 9285fa7e | consigne de Fred, mission Purge |
| 24/11/2026 | B.6 Saisie de gauche à droite partout sauf en arabe (vérifié après #1184 : seuls les champs de parti suivaient la langue) | en cours (branche) | df996d42 | consigne de Fred, mission Purge ; règle commune |

## Constats

- **Bernard** (Bernard Bernardov, nationalité et position Sovarka, domicile Krasnov, lu en production) voyait les forums de
  Républia parce que `forum_lecture_autorisee` acceptait tout forum autre que `national` / `local_` / `org_` sans regarder le
  pays du sujet, et que l'écran ne filtrait par pays que `national` et `local_` : la Présidence, le Gouvernement et les 5 sujets
  de Presse de Républia remontaient chez lui.
- **Infirmières d'accueil, ville par ville** (résolution identique à l'écran) : Luthécia — Anne Tibiotique (dispensaire public,
  salle d'attente) ; Port-Sainte-Marie — Betty Dine (dispensaire-public-v, attente ; Corinne Titgoute y tient l'accueil mais n'est
  pas infirmière) ; Montrouge — Agnès Thésie (hôpital, attente) ; Novomirsk — Ekaterina Bintova ; Starovka — Raïssa Bintova ;
  Krasnov — Nadejda Oukolova. **Aucune création.** Fiches complétées : `anne_tibiotique`, `betty_dine`, `agnes_thesie`,
  `infirmiere_de_novomirsk` (→ `sovarka_ekaterina_bintova` par dérivation), `raissa_bintova`, `nadejda_oukolova`.
- **Dates en base** : quatre formats coexistaient (« 23/11/2026 · 17h04 », « 23/11/2026 22:51 » écrit par le serveur, ISO,
  horodatage PostgreSQL). Un seul lecteur (`rpInstantForum`) et un seul format d'affichage (`rpDateLisible`, forum.js).

## Migration à appliquer

`migrations/20261124110000_forums_acces_purge.sql` (NON appliquée, rejouable) :
- réécrit `forum_lecture_autorisee` et `forum_ecriture_autorisee` (règles B.1 ; RLS de `forum_topics` / `forum_posts` inchangées,
  elles appellent ces fonctions) ;
- remplacement contrôlé de `forum_publication_jauges_interne` (marque `purge_b1`, 3 occurrences) : un nouveau sujet de
  sous-forum national est rangé dans le pays affiché par le joueur ; réponse possible dans le forum local de son domicile depuis
  un troisième pays.
- Éprouvée sur PGlite avec les définitions de production (`banc-forums-acces-pglite-20261124.cjs`, défaut montré avant).

Contrôle en lecture après application :
```sql
SELECT (length(d) - length(replace(d, 'purge_b1', ''))) / 8 AS marques   -- attendu : 3
  FROM (SELECT pg_get_functiondef('public.forum_publication_jauges_interne(text,uuid,jsonb)'::regprocedure) d) x;
SELECT proname, position('''presse''' IN prosrc) > 0 AS sous_forums      -- attendu : true, true
  FROM pg_proc WHERE proname IN ('forum_lecture_autorisee', 'forum_ecriture_autorisee');
```
Puis, connecté avec Bernard : la Presse, la Présidence et le Gouvernement n'affichent plus aucun sujet de Républia.

## Pour Codex (textes français nouveaux ou changés, traduction en pause)

- `plateau.html` : bouton `#hg-pa-infos` « Plus d'informations sur les PA ? » (pas de clé).
- `plateau-medecin-montrer.js`, clés `medecinMontrer.*` : `pa` « PA » ; `pa_txt` « PA {n} / {max} : votre énergie du jour,
  chaque action en coûte. Dormir les recharge ; à 0, c'est l'hôpital. » ; `paInfosTitre` « Plus d'informations sur les PA » ;
  `paInfosOu` « {nom}, l'infirmière d'accueil, vous expliquera les PA. Vous la trouverez ici : {lieu}, pièce « {piece} ». » ;
  `paInfosAucune` « Il n'y a pas d'infirmière d'accueil dans cette ville. Les PA sont votre énergie du jour : … ».
- `api/_pnj-personnalites.js` : `SAVOIR_PA` (consigne DeepSeek, en français comme les autres fiches).
- `plateau-politique.js` (fenêtre de candidature, sans clé) : « Conditions pour être candidat », « Dates de la période »,
  « Avoir la nationalité : {pays} », « Être dans le pays : {pays} », « Être domicilié à {ville} », « Être domicilié dans le pays :
  {pays} », « Influence d'au moins {n} (vous : {m}) », « Ne pas être déjà député », « Ne pas être maire / président (les deux
  postes ne se cumulent pas) », « Ne pas être déjà candidat à ce scrutin », « Déposer pendant la période de candidature »,
  « Avoir {n} PA (vous : {m}) », « (rempli) » / « (non rempli) », « Candidatures : du … au … », « Campagne : du … au … »,
  « Vote : du … au … », « Dates de la période : pas encore fixées par le serveur. », « En Sovarka, le serveur vérifie aussi les
  règles des partis (adhésion, investiture). », « Une condition en rouge empêche le dépôt : rien ne sera débité. », corps de
  notification « Vous devez être domicilié dans cette ville pour vous y présenter. », « Il vous faut {n} PA pour deposer une
  candidature. » (titres de notification inchangés).
- `forum.js` : nom « Forum local — {ville} », descriptions « Discussions de {ville} (votre ville de domicile) » / « (ville
  visitée) » ; `forumUi.localForums` « Forums locaux » ; « Aucun forum local dans ce pays : rendez-vous dans une de ses villes, ou
  domiciliez-vous dans l'une d'elles. » ; « Lecture seule : vous êtes à l'étranger. Seuls les citoyens de {pays} écrivent dans ce
  forum ; le forum local de la ville où vous êtes reste ouvert à tous. » ; format de date « {jj}/{mm} à {hh} h {mn} ».

## Questions de game design (non tranchées)

- Tribunal de ville (`tribunal_<ville>`) : forum local ou sous-forum national ? Laissé tel quel (le serveur le laisse lisible par tous).
- Les messages déjà publiés qui contiennent le bloc « Nouvelle zone de texte… » : les laisser, ou masquer ce bloc à l'affichage ?
- « Un seul format partout » : faut-il aussi passer l'heure des messages du chat (« 18:48 ») et du journal au format « 23/11 à 18 h 48 » ?
- Ordre des rubriques : « Forums locaux » placé entre « Forums nationaux » et « Forums internationaux » (choix d'affichage à confirmer).
- Infirmière de Port-Sainte-Marie : Betty Dine (infirmière) retenue plutôt que Corinne Titgoute (accueil, non soignante).
- La salle d'attente du dispensaire de Luthécia a pour image une photo externe (unsplash), pas une image du jeu.
- Candidature en Sovarka : les règles de parti (adhésion, investiture, chef de parti) ne sont pas cochées dans la fenêtre (l'écran
  ne les connaît pas) ; une phrase les signale, le serveur les juge.

## Bancs

Nouveaux : `banc-pa-jauge-infirmiere-20261124.cjs`, `banc-candidature-conditions-20261124.cjs`, `banc-chat-aucun-message-20261124.cjs`,
`banc-forums-acces-pglite-20261124.cjs` (PGlite), `banc-forums-purge-20261124.cjs` (B.1 à B.5), `banc-sens-saisie-navigateur-20261124.cjs`
(Chromium) ; workflow `.github/workflows/purge-forums-20261124.yml`. Alignés sur les nouvelles règles : `banc-mobile-coque.cjs` (témoin L1
renouvelé pour la jauge des PA), `banc-forum-local-compteurs-20261103.cjs`, `banc-jauges-copies-forum-379.cjs`,
`test-forum-publication-psm-20261104.cjs`, `test-nationalite-domicile-20261118.cjs`, `banc-interview-accueil-navigateur-20261122.cjs`,
`banc-mails-defilement-navigateur.cjs`, `banc-session-nocturne.cjs`.

Faux rouges d'environnement en local : `test-mobile-prototype-fidelity-20261117.cjs` (navigateur intégré de Playwright absent) ;
`banc-postes-pays-navigateur-20261123.cjs` (1 échec, déjà rouge sur main f73a9ebd).

## Ce qui reste

- Appliquer la migration `20261124110000_forums_acces_purge.sql` (agent principal) puis faire le contrôle ci-dessus.
- Traductions (Codex, 27/11).
