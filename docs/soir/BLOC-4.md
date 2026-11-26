# Mission du soir du 25/11/2026 — Bloc 4 : premium, le socle

Branche `claude/soir-b4-20261125` (issue de main 985d1c94). Principes de Fred : jamais de pay-to-win, mêmes statistiques en
gratuit et en premium. Pendant la bêta, tout reste gratuit (droits accordés à tous), comme aujourd'hui.

## Fait, point par point

- **4.1 Modèle** — `migrations/20261125700000_premium_socle.sql` : produits (`premium_produits`) sans aucun prix
  (`prix_centimes` NULL = non fixé, rien n'est affiché aux joueurs, l'achat répond « prix_non_fixe ») ; plancher de 2 € tenu
  par une contrainte et par `premium_admin_prix_fixer`. Options durables : commerce premium (3 familles / 10 articles au
  lieu de 2 / 4, attaché au fonds), bureau à 6 emplacements, personnalisation du local ou du bâtiment privé, publicités de
  joueur. À l'unité : renouvellement d'image, crédits de publicité (presse, rue, cinéma). Abonnement mensuel : toutes les
  options + un renouvellement d'image par semaine ISO (heure de Paris), non cumulable, au-delà à l'unité. Euros, achat par
  achat, aucune monnaie intermédiaire. Tarifs en dur retirés : 4,99 € / 7,99 € (atelier de presse, ses neuf langues, la
  contrainte SQL `publicites_premium_presse_check`), 0,99 € (commerce, appartements et leurs neuf langues, page MJ), et
  toute mention de Stripe (écran, catalogue, fonction `commerce-decoration`). Fenêtre premium `plateau-premium.js`
  (droits et prix lus au serveur), page MJ `admin-premium.js` (prix, gratuité de la bêta, publicité, modération).
- **4.2 Droits côté serveur** — tables `premium_abonnements`, `premium_achats`, `premium_droits`,
  `premium_renouvellements` ; lecture `premium_droits_lire()` ; chaque option vérifie le droit au serveur (raccords
  contrôlés, marque `premium_socle_v1`) : plafonds du commerce lus sur le FONDS (`fonds_definir_types`,
  `fonds_reference_creer`), bureau (`equipement_option_premium_activer`, `equipements_emplacements_interne` : une option
  prise par abonnement ne compte que tant qu'il court), appartement (`logement_premium_activer`), atelier de presse
  (`publicite_premium_creer_beta`), ateliers de décoration (`supabase/edge-functions/commerce-decoration` et
  `logement-decoration` : première image = droit de personnalisation, image remplacée = renouvellement). Compteur
  hebdomadaire : `premium_renouvellement_autoriser_service`. Bêta : `premium_parametres.beta_tout_gratuit = 1`.
  Hors bêta, un commerce qui a déjà plus de 2 familles ou 4 articles les garde (le plafond ne joue qu'à la création).
- **4.3 Publicité** — (a) annonceurs extérieurs : `premium_pub_externe_dormir()` appelée au réveil (Dormir) ; une par jour,
  jamais pour un abonné, réglage MJ `pub_externe_active` éteint ; table `premium_pub_externe_annonces` vide (aucune régie) :
  sans annonce, rien ne s'affiche et rien n'est compté. (b) publicités de joueurs : `publicites_joueurs` ; pop-up en ville
  (une apparition par jour et par passant, dans la ville de l'annonceur), réclame dans les salles du cinéma de Montrouge
  (avant la séance), annonce dans les journaux (atelier existant). Texte court nettoyé (60 / 280 caractères, sans balise),
  toujours échappé à l'affichage ; une campagne à la fois par support ; durée réglage MJ (7 jours) ; retrait par l'auteur
  ou le MJ ; jamais sa propre réclame ; comptes de test jamais diffusés. Le lien vers la rue et le cinéma est ajouté au bas
  de l'atelier de presse et dans la fenêtre premium.
- **4.4 Paiement** — `api/_paiement.js`, greffé sur `api/chat.js` (12 fonctions) : `POST /api/paiement` (commande avec le
  jeton du joueur ; le prix vient de la base, jamais du navigateur) et `POST /api/paiement/webhook` (signature HMAC-SHA256
  du corps brut vérifiée, horodatage borné à 5 min ; seul ce chemin confirme un achat, montant et devise revérifiés,
  idempotent). Fournisseur Paddle (Billing, bac à sable par défaut), faux fournisseur pour les bancs (interdit en
  production), paiement fermé par défaut (`PAIEMENT_FOURNISSEUR` absent). Remboursement : droits révoqués.
- **4.5 Remise à zéro du 19/12** — préparée, non exécutée : `docs/premium/REMISE-A-ZERO-20261219.md` (pas à pas, effacé /
  gardé, retour arrière), `historique/preparations-lancement/remise-a-zero-20261219.sql` (généré), offre des testeurs (personnalisation
  d'un commerce, une annonce presse, une publicité de rue) aux comptes de la bêta, comptes de test exclus.
- **4.6** — rien codé (reportage hebdomadaire, film mensuel, portrait IA, mini-jeux).

## Lignes de suivi (prêtes pour docs/suivi-decisions.md)

| Date | Décision | État | En ligne le | Commit | Source |
|---|---|---|---|---|---|
| 25/11/2026 | 4.1 Premium : options achetées une fois et durables (commerce premium 3 familles / 10 articles, bureau à 6, personnalisation du local ou du bâtiment privé, publicités de joueurs) ; renouvellement d'image à l'unité ; abonnement mensuel = toutes les options + un renouvellement d'image par semaine, non cumulable ; euros, achat par achat ; aucun prix fixé (réglages MJ, plancher 2 €) ; tarifs 4,99 € / 7,99 € / 0,99 € et Stripe retirés (migration 20261125700000 écrite, non appliquée). | en cours |  |  | Mission du soir 4.1 |
| 25/11/2026 | 4.2 Droits premium tenus par le serveur (abonnements, achats, droits, compteur hebdomadaire de renouvellements ; chaque option vérifie le droit) ; bêta : tout gratuit pour tous (migration 20261125700000 écrite, non appliquée). | en cours |  |  | Mission du soir 4.2 |
| 25/11/2026 | 4.3 Publicité des annonceurs : une par jour au Dormir, joueurs gratuits seulement, jamais les abonnés ; réglage MJ éteint ; aucune régie (migration 20261125700000 écrite, non appliquée). | en cours |  |  | Mission du soir 4.3 |
| 25/11/2026 | 4.3 Publicités de joueurs (option premium) : pop-up en ville, réclame au cinéma de Montrouge, annonce dans les journaux ; jeu de rôle, texte court échappé (migration 20261125700000 écrite, non appliquée). | en cours |  |  | Mission du soir 4.3 |
| 25/11/2026 | 4.4 Paiement par un revendeur qui vend en son nom et gère la TVA (Paddle) : interface serveur prête en mode test, faux fournisseur pour les bancs, aucun achat sous 2 €. | en cours |  |  | Mission du soir 4.4 |
| 25/11/2026 | 4.5 Remise à zéro du 19/12 et offre des testeurs de la bêta : procédure préparée et documentée, non exécutée (Fred décide du moment). | en cours |  |  | Mission du soir 4.5 |
| 25/11/2026 | 4.6 Reportage hebdomadaire, film mensuel au cinéma de Montrouge, portrait par IA, mini-jeux : hors mission, forme à trancher avec Fred. | décidé |  |  | Mission du soir 4.6 |

## Migration à valider (non appliquée)

`migrations/20261125700000_premium_socle.sql` — après les migrations du jour. Raccords contrôlés : chaque ancrage est compté
(une ou deux occurrences exactes) et la migration échoue sinon. Contrôles en lecture (en tête du fichier) :
```sql
SELECT count(*) FROM public.premium_produits WHERE prix_centimes IS NULL;                          -- 9
SELECT valeur FROM public.premium_parametres WHERE cle = 'beta_tout_gratuit';                       -- 1
SELECT valeur FROM public.premium_parametres WHERE cle = 'pub_externe_active';                      -- 0
-- marque premium_socle_v1 dans les six fonctions raccordées                                          -- vrai
SELECT has_function_privilege('authenticated', 'public.premium_droits_lire()', 'EXECUTE');          -- vrai
SELECT has_function_privilege('authenticated', 'public.premium_achat_confirmer_service(uuid,text,text,integer,text)', 'EXECUTE');  -- faux
SELECT has_function_privilege('anon', 'public.premium_droits_lire()', 'EXECUTE');                   -- faux
```
Ancrages relus en production le 25/11 au soir (lecture seule) : `fonds_definir_types`, `fonds_reference_creer` (×2),
`equipements_emplacements_interne`, `equipement_option_premium_activer`, `logement_premium_activer`,
`publicite_premium_creer_beta`. Sans la migration : comportement actuel, l'écran dit « offertes à tous pendant la bêta ».

**Aussi à déployer après la migration** (fonctions Supabase, hors Vercel) : `commerce-decoration` et `logement-decoration`
(sans la migration, elles retombent sur le comportement de bêta si la RPC manque).

## Paiement : fournisseur recommandé et ce que Fred doit faire

Recommandation : **Paddle** (Paddle Billing). Il vend en son nom (« merchant of record ») et déclare la TVA de tous les pays,
gère abonnements, remboursements et factures, accepte les prix fixés au moment de l'achat (nos prix MJ) ; Lemon Squeezy
fait de même mais appartient désormais à Stripe et son avenir est moins lisible.
1. Créer un compte vendeur sur paddle.com (et un compte « sandbox » pour les essais), au nom de l'entreprise de Fred.
2. Faire valider le site : Paddle demande les CGV, la politique de remboursement et une page de prix en ligne.
3. Dans Paddle (sandbox d'abord) : créer une clé d'API et une destination de notification (webhook) vers
   `https://res-publica.vercel.app/api/paiement/webhook`, événements `transaction.completed`, `subscription.*`,
   `adjustment.*` ; noter son « secret ».
4. Dans Vercel → Settings → Environment Variables : `PAIEMENT_FOURNISSEUR=paddle`, `PADDLE_ENV=sandbox`,
   `PADDLE_API_KEY=…`, `PADDLE_WEBHOOK_SECRET=…` (ne jamais les mettre dans le dépôt ni dans un message).
5. Fixer les prix dans la page MJ (2 € minimum) ; au lancement, passer `PADDLE_ENV=production` avec les clés réelles.

## Pour Codex (français nouveau, à traduire)

- `plateau-premium.js` : tout l'objet `TXT` et `RAISONS` (fenêtre premium, réclames, publicités de joueurs).
- `plateau-publicite-premium.js` : nouvelle clé `otherMedia` (« Autres supports : la rue et le cinéma de Montrouge »),
  absente de `i18n/premium-ads-resources.js`.
- `plateau-commerce-pj.js` : section Commerce Premium réécrite (sans prix), messages de nouvelle génération
  (« renouvellement d’image à l’unité », « inclus une fois par semaine dans l’abonnement, sinon à l’unité »).
- `i18n/premium-ads-resources.js` (`beta`, `five`, `ten`) et `i18n/appartements-resources.js` (`atelier.intro`) : seuls les
  tarifs et Stripe ont été retirés dans les neuf langues (aucune nouvelle phrase) ; à relire.
- Libellés des produits (`premium_produits.libelle`, migration) et page MJ `admin-premium.js` (français seulement).

## Bancs

- `outils/bancs/banc-premium-socle-pglite-20261125.cjs` (9 tests : bêta, hors bêta, prix, achat idempotent, abonnement et
  renouvellement hebdomadaire, publicité extérieure, publicités de joueurs, offre de lancement).
- `outils/bancs/banc-paiement-premium-20261125.mjs` (7 tests : signature, fournisseurs, commande, webhook, événements,
  Paddle, greffe).
- `outils/bancs/banc-premium-ecran-20261125.cjs` (4 tests : aucun tarif ni Stripe, branchements, fenêtre, réclames).
- `outils/bancs/banc-remise-a-zero-pglite-20261125.cjs` (4 tests).
- Adaptés : `test-commerce-premium-beta.mjs` (plus de vitrine à 4,99 €), `banc-i18n-publicite-premium-20261112.cjs`
  (versions de cache). Rejoués verts : gestion du commerce (Chromium, témoin au pixel), équipements, appartements, chat,
  guide, aide, Vercel à 12 fonctions, audit i18n global. `banc-deploiement-sobre.cjs` : un échec local identique sur main
  (analyseur JavaScriptCore de macOS), sans lien.
- Piège trouvé : une flèche « → » ajoutée dans un commentaire de `plateau-commerce-pj.js` cassait le témoin au pixel de
  `banc-i18n-gestion-commerce` (script injecté en ligne) ; retirée.

## Limites connues

- Un renouvellement d'image est décompté avant la génération : si OpenAI échoue ensuite, il est perdu (à rembourser à la
  main par le MJ). Amélioration possible : décompter à la validation de l'aperçu.
- L'appartement premium activé reste acquis même si l'abonnement s'arrête (le bureau à 6, lui, suit l'abonnement).
- Le corps brut du webhook se lit sur le flux de la requête Vercel : à vérifier au premier essai en bac à sable (un échec
  donne « signature_invalide », sans effet).
- La remise à zéro laisse une étape à écrire table par table (40 tables mixtes à remettre à leur état initial) et deux
  tables à classer ; le script refuse de tourner tant que ce n'est pas fait.

## Questions de game design

- Publicités de joueurs : l'option s'achète une fois ; donne-t-elle des campagnes illimitées (une à la fois par support,
  durée réglée par le MJ, comme codé) ou un nombre de parutions ?
- L'atelier de presse garde ses formules « 5 / 10 parutions » : faut-il les garder, maintenant que l'option est durable ?
- Abonnement arrêté : l'appartement premium déjà activé reste-t-il acquis (codé ainsi) ou revient-il au gratuit ?
- Remise à zéro : les personnages disparaissent (codé), ou chacun garde son personnage remis à zéro ?
- `blocus_ordres_batiments` et `climat_evenements` : à vider ou à garder au lancement ?
