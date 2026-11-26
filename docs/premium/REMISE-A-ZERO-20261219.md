# Remise à zéro du lancement (19/12/2026) — procédure

Mission du soir du 25/11/2026, bloc 4.5 ; complétée en fin de soirée (point 1.1, décisions de Fred). **Préparée, jamais exécutée.** Fred décide du moment ; personne ne la lance sans lui.

## Ce que veut Fred

- Le jour du lancement, le jeu repart de zéro : **tous repartent sans rien**. **Tous les personnages disparaissent**, et
  chacun recrée le sien, comme au premier jour (décision de Fred, 25/11 en fin de soirée).
- Les testeurs de la bêta reçoivent, après la remise à zéro, une **offre ponctuelle** : la personnalisation d'un commerce,
  une annonce dans la presse et une publicité dans la rue (pop-up). Les **comptes de test** (Arnie, Tom Tom,
  Bernard Bernardov) n'y ont pas droit.

## Les fichiers

| Fichier | Rôle |
|---|---|
| `historique/preparations-lancement/remise-a-zero-20261219.sql` | le script, **généré** (ne pas l'éditer à la main) |
| `historique/preparations-lancement/remise-a-zero.modele.sql` | son modèle (garde-fous, relevé, effacement, offre) |
| `historique/preparations-lancement/reinitialisations.modele.sql` | la remise à l'état initial des tables mixtes, table par table (inséré par le générateur) |
| `outils/lancement/generer-remise-a-zero.py` | le générateur (`--verifier` : échoue si le script n'est pas à jour) |
| `baseline/classification-donnees.csv` | classement historique des tables (A, B : garder ; C : vider ; D : réinitialiser) |
| `outils/lancement/classement-complementaire-20261125.csv` | tables nouvelles et corrections (prioritaire) |
| `outils/bancs/banc-remise-a-zero-pglite-20261125.cjs` | le banc |

## Ce qui est effacé, ce qui est gardé

- **Effacé (« vider », 433 tables)** : tout l'état vivant de la bêta — personnages et leurs fiches, inventaires, comptes en
  banque, commerces des joueurs, affaires judiciaires, détentions, messages, forums, journaux, élections, historiques,
  publicités de joueurs, etc. ; aussi `blocus_ordres_batiments` et `climat_evenements` (décision de Fred : vidées au lancement,
  le calendrier climatique se replanifie par mandat). Relevé du 25/11 en fin de soirée : les 129 tables créées depuis le
  classement sont classées (126 vidées, 3 gardées : `frontieres_fermees`, `souvenirs_objets`, `sovarka_urbanisme`).
  Une table référencée par une table gardée (`journaux.cree_par` → `personnages_donnees`) est vidée par DELETE : la clé met
  la référence à NULL.
- **Gardé (« garder », 159 tables)** : le journal du MJ (`admin_journal`, décision du 26/11), les référentiels et réglages du MJ (ordres et coûts, catalogues, PNJ et leurs lieux,
  villes, rues, santé, climat, criminalité, accueil, guide…), les accès du MJ (`administrateurs`), les comptes de test,
  les réglages premium, et **tout ce qui touche à l'argent réel** (`premium_achats`, `premium_abonnements`,
  `premium_droits`, `premium_renouvellements`) — aucun pendant la bêta, mais jamais effacé.
- **Les comptes de connexion** (`auth.users`) ne sont pas touchés : les joueurs gardent leur identifiant.
- **Remis à l'état initial (« reinitialiser », 45 tables)**, par le script lui-même (bloc « RÉINITIALISATIONS », une entrée
  par table, relevé en lecture de la production le 25/11) :
  - *aucune action* (17) : référentiels qu'aucune fonction n'écrit (catalogues, recettes, barèmes, entrepôts par ville,
    structures médicales, règles des terrains), `rp_transitions` (comportement à conserver), `lois_assemblee` (table morte),
    `dotations_amorcage_caisses` (journal d'un amorçage déjà fait) ;
  - *vidées* (état recréé à la demande) : stocks des dealers, niveaux des prisons, caisse du kolkhoze, énigme du trésor des
    Tsars, échéanciers de loyers, stocks de médicaments et des ports, possessions des PNJ, postes pris par des joueurs ;
  - *filtrées* : PNJ attachés à un joueur retirés (leurs métiers suivent par cascade), organisations fondées par des joueurs
    retirées (celles dirigées par un PNJ restent, sans membres ni caisse), commerces des joueurs retirés ;
  - *dotations du MJ* (décisions n° 5 et 6 du 26/11) : **tous les commerces restants** (ceux des PNJ) repartent de leur
    dotation initiale — caisse, et quantité de chaque matière et de chaque produit qu'ils tiennent — lue dans
    `lancement_dotations_commerces` (type, sinon « * » du pays) ; **toutes les caisses publiques** de Républia et de Sovarka
    repartent de leur dotation (`lancement_dotations_caisses`, par catégorie, sinon « * » ; défauts : montants arbitrés le
    05/10 pour Républia, × 0,3 pour Sovarka, ports à 20 000) ; les deux tables se règlent dans la page MJ, section
    « Dotations du lancement » (migration 20261126200000) ; les caisses des empires fermés ne sont pas touchées ;
  - *valeurs de départ* (décision technique du 26/11) : `budgets_nationaux` (taux national 2, réserve 0, réfectoire et
    matières de la caserne vides, seuls les lots militaires de la « dotation-initiale », dates et décisions de la bêta
    effacées) ; `ports_commerce` (taux, quotas, prix, répartition et dotation du jour à leurs valeurs de création) ;
  - les tables `avocats_barreau` et `compagnies_militaires` sont vidées (classement historique C) ;
  - *colonnes remises à blanc* : locaux de Sovarka (demandes, commerces de joueurs), murs (à la commune, sans offre),
    terrains (sans propriétaire, permis ni chantier), sièges de l'Assemblée (plus d'endormis), caisses des clubs (0),
    taux foncier des mairies (0,05) ;
  - *semis rejoué* : stock du marché de Krasnov (migration 20261122160000) et trois entrepôts logistiques
    (seed `baseline/seeds/92_mixte/batiments_etat.sql`).
- **Offre des testeurs de la bêta** : la personnalisation d'un commerce et deux campagnes de publicité courtes (une annonce
  dans la presse, une publicité dans la rue).

## Pas à pas (le jour J)

1. **Sauvegarde** : dans Supabase, vérifier la sauvegarde automatique du jour et, si le plan le permet, noter l'heure pour
   une restauration à un instant (PITR). Exporter aussi `personnages` et `premium_*` (CSV) par prudence.
2. **Mettre le jeu en pause** (message d'accueil, cron de minuit désactivé pour la nuit dans Vercel).
3. **Reclasser les tables créées depuis le 25/11** (relevé en lecture de `pg_class`, jamais en écriture) dans
   `classement-complementaire-20261125.csv`, puis `python3 outils/lancement/generer-remise-a-zero.py` et le banc
   (`PGLITE_DIR=… node --test outils/bancs/banc-remise-a-zero-pglite-20261125.cjs`). Une table non classée et non vide
   fait refuser le script.
4. **Relire le bloc « RÉINITIALISATIONS »** du script généré (une ligne « ▸ table : stratégie » par table mixte).
5. **Lancer le script** dans l'éditeur SQL de Supabase, d'un seul tenant :
   ```sql
   SET human_gambit.remise_a_zero = 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026';
   -- puis tout le contenu de historique/preparations-lancement/remise-a-zero-20261219.sql
   ```
   Tout se passe dans une seule transaction (effacement, réinitialisations, offre) : au moindre refus (date, table inconnue
   non vide, clé étrangère inattendue),
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
- `campagne_publicite_courte` (deux fois) : une annonce dans la presse et une publicité dans la rue (pop-up) ; depuis le
  26/11, une campagne se vend pour tous les supports, courte (5 jours) ou longue (10 jours).
Chaque crédit s'utilise une fois. Le relevé `lancement_comptes_beta` empêche une seconde offre si le script était rejoué.

## Retour arrière

- Avant le `COMMIT` : rien n'est fait (transaction unique).
- Après : restaurer la sauvegarde du jour (ou PITR à l'heure notée à l'étape 1) depuis le tableau de bord Supabase.
  Les achats payés éventuels entre-temps se retrouvent chez le revendeur de paiement (fournisseur pas encore arrêté) et se rejouent par ses webhooks.

## Décisions de Fred (25/11/2026, fin de soirée)

- Tous les personnages disparaissent ; chacun recrée le sien.
- `blocus_ordres_batiments` et `climat_evenements` sont vidées au lancement.

## Questions pour Fred

Tranchées le 26/11 (`docs/mission-decisions-20261126.md`) : dotations des commerces et des caisses publiques, valeurs de
départ des budgets nationaux et des ports, journal du MJ gardé, barreau et compagnies vidés. Il ne reste que :

- PNJ des institutions (125 : douaniers, gardes, agents…) : gardés, car ils ne naissent qu'à la création de l'institution.
