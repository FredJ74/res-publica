# Remise à zéro du lancement (19/12/2026) — procédure

Mission du soir du 25/11/2026, bloc 4.5. **Préparée, jamais exécutée.** Fred décide du moment ; personne ne la lance sans lui.

## Ce que veut Fred

- Le jour du lancement, le jeu repart de zéro : **tous repartent sans rien**.
- Les testeurs de la bêta reçoivent, après la remise à zéro, une **offre ponctuelle** : la personnalisation d'un commerce,
  une annonce dans la presse et une publicité dans la rue (pop-up). Les **comptes de test** (Arnie, Tom Tom,
  Bernard Bernardov) n'y ont pas droit.

## Les fichiers

| Fichier | Rôle |
|---|---|
| `outils/lancement/remise-a-zero-20261219.sql` | le script, **généré** (ne pas l'éditer à la main) |
| `outils/lancement/remise-a-zero.modele.sql` | son modèle (garde-fous, relevé, effacement, offre) |
| `outils/lancement/generer-remise-a-zero.py` | le générateur (`--verifier` : échoue si le script n'est pas à jour) |
| `baseline/classification-donnees.csv` | classement historique des tables (A, B : garder ; C : vider ; D : réinitialiser) |
| `outils/lancement/classement-complementaire-20261125.csv` | tables nouvelles et corrections (prioritaire) |
| `outils/bancs/banc-remise-a-zero-pglite-20261125.cjs` | le banc |

## Ce qui est effacé, ce qui est gardé

- **Effacé (« vider », 309 tables)** : tout l'état vivant de la bêta — personnages et leurs fiches, inventaires, comptes en
  banque, commerces des joueurs, affaires judiciaires, détentions, messages, forums, journaux, élections, historiques,
  publicités de joueurs, etc. Les personnages disparaissent : chaque joueur recrée le sien au lancement.
- **Gardé (« garder », 152 tables)** : les référentiels et réglages du MJ (ordres et coûts, catalogues, PNJ et leurs lieux,
  villes, rues, santé, climat, criminalité, accueil, guide…), les accès du MJ (`administrateurs`), les comptes de test,
  les réglages premium, et **tout ce qui touche à l'argent réel** (`premium_achats`, `premium_abonnements`,
  `premium_droits`, `premium_renouvellements`) — aucun pendant la bêta, mais jamais effacé.
- **Les comptes de connexion** (`auth.users`) ne sont pas touchés : les joueurs gardent leur identifiant.
- **À réinitialiser (« reinitialiser », 40 tables)** : l'état du monde semé au départ (bâtiments, caisses et budgets
  publics, locaux de Sovarka, titres des murs, stocks des marchés, des ports et des pharmacies, PNJ membres et possessions,
  postes tenus par des PNJ, catalogues mixtes…). Ces tables ne se vident pas : elles se **remettent à leur état initial**.
  Le script ne les touche pas et refuse de tourner tant que l'opérateur n'a pas déclaré cette étape faite.
- **À vérifier (2 tables)** : `blocus_ordres_batiments` (974 lignes : référentiel ou trace ?) et `climat_evenements`
  (calendrier planifié par mandat : à vider puis replanifier, ou à garder ?). Le script refuse de tourner tant qu'elles
  ne sont pas classées.

## Pas à pas (le jour J)

1. **Sauvegarde** : dans Supabase, vérifier la sauvegarde automatique du jour et, si le plan le permet, noter l'heure pour
   une restauration à un instant (PITR). Exporter aussi `personnages` et `premium_*` (CSV) par prudence.
2. **Mettre le jeu en pause** (message d'accueil, cron de minuit désactivé pour la nuit dans Vercel).
3. **Classer les tables « à vérifier »** dans `classement-complementaire-20261125.csv`, puis
   `python3 outils/lancement/generer-remise-a-zero.py` et le banc
   (`PGLITE_DIR=… node --test outils/bancs/banc-remise-a-zero-pglite-20261125.cjs`).
4. **Réinitialiser les 40 tables mixtes** : pour chacune, rejouer son état initial (migrations de semis, seeds de
   `baseline/seeds/`, ou remise à blanc des colonnes d'occupant). *Cette étape reste à écrire table par table avant le
   12/12 ; c'est le seul morceau non automatisé.* Le relevé d'une table nouvelle se fait en lecture
   (`SELECT count(*)`), jamais en écriture.
5. **Lancer le script** dans l'éditeur SQL de Supabase, d'un seul tenant :
   ```sql
   SET human_gambit.remise_a_zero = 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026';
   SET human_gambit.remise_reinitialisations = 'faites';
   -- puis tout le contenu de outils/lancement/remise-a-zero-20261219.sql
   ```
   Tout se passe dans une seule transaction : au moindre refus (date, table inconnue non vide, clé étrangère inattendue),
   **rien n'est effacé**.
6. **Basculer le premium** : page MJ → Premium → « Terminer la gratuité » (`beta_tout_gratuit = 0`) et fixer les prix
   (aucun sous 2 €). Sans prix fixé, les options affichent « Bientôt disponible ».
7. **Contrôles en lecture** :
   ```sql
   SELECT count(*) FROM public.personnages;                                        -- 0
   SELECT count(*) FROM public.lancement_comptes_beta;                             -- nombre de testeurs (hors comptes de test)
   SELECT produit, count(*) FROM public.premium_droits WHERE source = 'offre_lancement' GROUP BY 1;  -- 3 lignes, même nombre
   SELECT count(*) FROM public.premium_achats;                                     -- inchangé
   ```
8. **Rouvrir le jeu** (cron, message d'accueil).

## L'offre des testeurs, côté jeu

Trois droits par compte de la bêta (`premium_droits`, source `offre_lancement`) :
- `personnalisation_local`, sans cible : il s'attache au **premier commerce** (ou local) que le joueur personnalise
  (atelier de décoration) ;
- `credit_publicite_presse` : une annonce dans la presse (atelier de presse) ;
- `credit_publicite_rue` : une publicité dans la rue (pop-up), une campagne.
Chaque crédit s'utilise une fois. Le relevé `lancement_comptes_beta` empêche une seconde offre si le script était rejoué.

## Retour arrière

- Avant le `COMMIT` : rien n'est fait (transaction unique).
- Après : restaurer la sauvegarde du jour (ou PITR à l'heure notée à l'étape 1) depuis le tableau de bord Supabase.
  Les achats payés éventuels entre-temps se retrouvent chez le revendeur (Paddle) et se rejouent par ses webhooks.

## Questions pour Fred

- « Repartent sans rien » : les **personnages** disparaissent-ils (chacun recrée le sien), ou chacun garde-t-il son
  personnage, remis à zéro (argent, objets, postes) ? La procédure prépare la première lecture.
- Les deux tables « à vérifier » ci-dessus.
