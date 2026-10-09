# Migrations appliquées — l'archive du cycle 2G

Une migration qui vit ici a été **appliquée à la base**, et le baseline a été
**réextrait après**. Son effet n'est donc plus dans ce fichier : il est dans
`baseline/`, qui fait foi.

C'est pour cela qu'elle a quitté `migrations/`. Ce répertoire-là ne contient que
les évolutions **futures**, et l'invariant 4 de `verifier-autorite.py`… non :
l'invariant 4 de `../../outils/baseline/verifier-workflow.py` refuse qu'une
migration antérieure au point de coupe du baseline y traîne. Il a raison —
la rejouer serait au mieux inutile.

**Ces fichiers ne sont pas rejouables, et n'ont pas à l'être.** On les garde pour
une seule raison : lire, dans six mois, *pourquoi* un droit a disparu. Le registre
Supabase dit qu'une migration est passée ; ces fichiers disent ce qu'elle voulait.

Ne pas confondre avec `../sql-racine/migrations/` : ces 184 fichiers sont
d'avant le baseline, dispersés à la racine du dépôt, sans garantie
d'application — 162 d'entre eux dépendent d'une table qu'aucun ne crée. Ici,
tout a été appliqué, dans l'ordre, et mesuré après.

## Ce qu'elles contiennent

**Ce tableau couvre le cycle de l'autorité (registre 540 à 543) puis, sans
interruption, tout ce qui a été appliqué depuis le registre 560.** Les
**44 fichiers** de ce répertoire ne sont donc pas tous listés : il manque les
migrations des chantiers 4B à 4F et des budgets municipaux, qui portent leur
résumé **dans leur propre en-tête**, la source à lire. Cette lacune est
documentaire, pas une incertitude sur ce qui a été appliqué — le registre
Supabase, lui, est complet.

> **Corrigé le 9 octobre 2026.** Ce paragraphe disait « 21 fichiers » et « ne
> décrit que le cycle de l'autorité et la dernière entrée en date ». Les deux
> affirmations étaient devenues fausses au fil des lots. Un README qui compte mal
> ses propres fichiers est un README qu'on cesse de croire.

| Fichier | Registre | Effet mesuré après application |
|---|---|---|
| `20261005214500_autorite_defauts_fermes.sql` | 540 | privilèges de maintenance aux rôles clients 547 → 0 · `UPDATE` de séquence 40 → 0 · défaut d'une table neuve réduit à `SELECT` |
| `20261005214600_autorite_socle_acteur_identifie.sql` | 541 | `acteur_identifie()` créée · tables sans RLS 27 → 0 · policies 213 → 284 (28 permissives retirées, 99 posées) · droits d'écriture clients 233 → 132 |
| `20261006013000_autorite_rpc_sans_anon.sql` | 542 | fonctions mutantes appelables par `anon` 34 → 0 |
| `20261006160000_autorite_declencheurs_public.sql` | 543 | fonctions de déclencheur appelables par un rôle client 24 → 0 |
| `20261008214206_pays_declare_et_retrait_des_defauts_republic.sql` | 560 | `personnage_pays_declare()` + son déclencheur créés · `p_country text DEFAULT 'republic'` 11 → 0 · signatures 663 → 664 · droits EXECUTE des onze **restitués à l'identique**, ni perdu ni apparu · 3 commentaires reposés · `authenticated` sur les 7 fonctions de cron 7 → 0 |
| `20261008221846_defaut_des_privileges_de_fonction_ferme.sql` | 561 | ACL d'une fonction **neuve** : `PUBLIC authenticated postgres service_role` → **`postgres service_role`** · `has_function_privilege` rend désormais `false` pour `anon` et `authenticated` · droits des 664 fonctions existantes **inchangés** (37 / 58 / 421 / 664) · `catalogue_generiques_raccordes` passée en `security_invoker` (84 lignes avant comme après, pour les trois rôles) · `personnages` **non modifiée** |
| `20261009073456_restitution_arg_arnie_effet_de_bord_des_preuves.sql` | 565 | **première migration qui modifie une donnée de joueur**, et elle répare un écart que l'agent a causé : `arg` 8428 → 9428 pour Arnie, `liquide` inchangé, `updated_at` relevé — sans quoi la session du joueur aurait réécrit l'ancienne valeur · 7 autres personnages intacts par empreinte comparée dans la transaction |
| `20261009093112_actes_nocturnes_brique.sql` | 566 | `actes_nocturnes(pays, mecanisme, sujet, jour)` en clé primaire + sa **liste blanche** de mécanismes · `acte_nocturne_revendiquer()` **injoignable depuis le réseau** (EXECUTE retiré à `anon`, `authenticated` **et** `service_role`) : revendiquer hors de la transaction de l'effet devient structurellement impossible · RLS active, aucun droit client, zéro mécanisme à l'arrivée |
| `20261009130649_preemption_mensualite_atomique.sql` | 567 | débit de caisse **et** réduction de dette dans **une** transaction, ouverte par une revendication · 4 allers-retours HTTP → 1 RPC · une panne après acquisition annule les deux écritures **et** la revendication · les 4 caisses ministérielles comparées à leur valeur exacte d'avant |
| `20261009132222_notification_ne_casse_plus_l_acte.sql` | 568 | `mail_systeme_envoyer` **ne lève plus** : l'`INSERT` du courrier est dans son propre bloc, l'incident est consigné dans `mails_envois_systeme.echec` avec son SQLSTATE · la transaction de l'appelant survit à la perte d'un courrier (prouvé par une contrainte réelle au banc) · refus métier et droits intacts |
| `20261009005012_ardoise_impaye_atomique.sql` | 564 | la branche `expulsion_requise` de `prelever_loyer_bail` pose enfin `jourPaiement` — **6 poses au lieu de 5** · l'ardoise de l'impayé est **calculée dans la RPC**, atomique avec sa revendication, au lieu d'être recalculée par un appelant qui réécrivait le blob depuis une lecture périmée · deux verdicts distincts pour l'avis · droits et `search_path` intacts · bail de la bêta inchangé · **va par paire avec `api/cron-minuit.js`** |
| `20261009003201_mails_portent_leur_identite.sql` | 563 | `mails.id` reçoit un `DEFAULT` aligné sur `mail_systeme_envoyer` · les **9 sites** de 2 fonctions qui levaient `23502` traversent · `NOT NULL` et `PRIMARY KEY (id)` intacts · **4 empreintes de données identiques avant et après** · corrige un relevé faux de la ligne précédente : 2 fonctions concernées, pas dix |
| `20261008235521_idempotence_prets_helvetia.sql` | 562 | `traiter_prets_helvetia_quotidien` porte un marqueur de journée · trois appels le même jour prélèvent **une seule** mensualité (5000 → 4500 → 4500), le lendemain reprend (→ 4000) · verdict `deja_traite_aujourdhui` rendu · **et ses propres preuves ont laissé 1 000 FR dans `republic_banque-privee`, restitués dans la minute** — lire son en-tête |
| `20261009140303_election_voter_porte_atomique.sql` | 569 | `election_voter(text,text,text,text)` créée, `EXECUTE` à `authenticated` seul · 2 écritures clientes indépendantes (bulletin + blob du cycle) → **1 RPC** sous `FOR UPDATE` du cycle · l'électeur est lu par `mon_personnage()`, aucun paramètre ne le nomme · 6 preuves structurelles vertes · `anon` ne peut pas voter · **0 bulletin apparu** et empreinte des cycles électoraux identique avant et après |
| `20261009141441_detention_moteur_partage_et_drapeau_qhs.sql` | 570 | moteur `detention_prolonger_interne` + 2 portes (`justice_prolonger_peine`, `detention_prolonger_soi`) au lieu d'une RPC et d'une branche cliente divergentes · écrivains de `detention_qhs` **exactement 4, nommés** (`detention_qhs_poser_interne, pa_repos_nocturne, personnages_vue_modifier, qhs_pouvoir`) · drapeau posé en **objet jsonb** et non plus en scalaire string, donc lisible par `pa_repos_nocturne` · moteurs sans `EXECUTE` réseau, droits du juge inchangés · 6 preuves vertes · 0 détention créée, 1 ligne QHS, empreinte des personnages identique |
| `20261009142500_detention_porte_du_detenu_sur_lui_meme.sql` | 571 | `detention_ouvrir_interne` recréée à 9 paramètres (`p_extras` ajouté) — **1 seule surcharge**, et ses **6 appelants serveur** résolvent toujours à 8 arguments · 7ᵉ porte `detention_ouvrir_soi` ouverte à `authenticated` · les 2 insertions portent les colonnes judiciaires, la primitive n'écrit pas le QHS · 7 épreuves vertes dont le rejeu (`cible_deja_detenue`, une seule peine) et le refus sans identité (aucune ligne créée) · 0 détention créée |
| `20261009142903_detention_clore_et_transferer_au_qhs.sql` | 572 | `detention_clore_purgee()` et `detention_transferer_qhs(text,integer,text,jsonb)` créées, `EXECUTE` à `authenticated` · 4 écritures indépendantes avalées → **1 transaction** pour le transfert · `est_emprisonne` enfin **vidé en base** (il ne l'était qu'en mémoire), drapeau abaissé en objet, registre du QHS passé à `libere` · clôture idempotente (`non_detenu` au rejeu), transfert non idempotent **exprès** · 5 preuves vertes · 0 détention, 1 ligne QHS, empreinte des personnages identique |
| `20261009143302_justice_rendre_sentence_porte_atomique.sql` | 573 | `justice_rendre_sentence(jsonb,text)` créée · 2 écritures avalées + une affaire écrite **deux** fois → 1 transaction sous verrou, identifiant du jugement **dérivé de l'affaire** (donc un seul jugement au rejeu) · le juge n'est plus un paramètre : `juge: 'Napoleon'` ne franchit pas la porte · autorité par `affaire_autorite_de`, reprise telle quelle · 4 preuves vertes · 0 affaire et 0 jugement de banc subsistants, poste du banc retiré |
| `20261009150819_candidature_poste_tirage_appartient_au_serveur.sql` | 574 | `candidature_poste_tirage_appliquer(...)` créée : injoignable par `anon` et `authenticated`, `EXECUTE` pour `service_role` seul · 6 écritures avalées → 1 transaction, et le tirage `ORDER BY random()` est **après** la revendication (vérifié par position dans le corps) · registre écrit **avant** la fiche · 2 courriers par `mail_systeme_envoyer`, **0** `INSERT INTO public.mails` · mécanisme `candidature_poste_tirage` inscrit à la liste blanche, non singleton · `acte_nocturne_revendiquer` reste à `postgres` seul · 6 preuves vertes · 0 acte nocturne, 28 courriers, POP d'Arnie à 9, empreinte des postes identique |
| `20261009152210_compromis_expire_une_transaction_deux_familles.sql` | 575 | `compromis_expire_resoudre(text,text)` créée : **une** fonction pour les deux familles (terrains et entreprises) là où le cron avait deux chemins quasi identiques · 4 écritures avalées → 1 transaction, **≥ 3** `FOR UPDATE` · identifiants devenus datés (`pret-<type>-<bien>-<jour>`, `compromis-<bien>-<jour>`) avec **2** gardes `ON CONFLICT (id) DO NOTHING` · brique `actes_nocturnes` volontairement **absente** (une revendication par jour empêcherait deux compromis du même bien) · injoignable par `anon`/`authenticated`, ouverte à `service_role` · 6 preuves vertes · 0 résidu de banc (terrain, entreprise, historique, prêt), argent du personnage du banc inchangé |
| `20261009152949_mail_systeme_un_seul_ecrivain_et_son_poseur_interne.sql` | 576 | `mail_systeme_poser_interne(...)` créée — l'unique `INSERT` de `public.mails` — avec `EXECUTE` révoqué à `PUBLIC`, `anon`, `authenticated` **et** `service_role` · `mail_systeme_envoyer` garde sa liste blanche et son contrôle d'identité, et **délègue** l'écriture · fonctions écrivant encore `mails` en direct : **10, relevé tel quel** (ce lot bâtit le moteur, les six suivants routent) · 5 preuves vertes · 28 courriers avant comme après |
| `20261009153547_mails_routes_militaire_et_renseignement.sql` | 577 | 4 fonctions patchées en place par `pg_get_functiondef` + `replace` (`militaire_affectations_expirer`, `militaire_candidatures_relancer`, `militaire_candidature_accepter`, `cellule_alerter_ministre`) · chacune : 0 `INSERT` direct, **1** appel au poseur, libellé de sujet conservé · ACL de chacune **identique avant et après** · 28 courriers inchangés |
| `20261009153653_mails_routes_assemblee.sql` | 578 | 2 fonctions patchées (`assemblee_detecter_partie`, `assemblee_marquer_convocations_echues`) · leur bloc `EXCEPTION WHEN OTHERS THEN NULL` — qui avalait l'échec sans rien consigner — **supprimé**, vérifié absent · 1 appel au poseur chacune, 0 `INSERT` direct · les **2** entrées de la chaîne de détection vérifiées `SECURITY DEFINER` et possédées par `postgres` · ACL inchangées · 28 courriers |
| `20261009153746_mails_routes_banque_et_notariat.sql` | 579 | 2 fonctions patchées (`resoudre_placement_national`, `finaliser_achat_bien_helvetia`) pour **3** courriers routés (1 + 2), nombre d'appels au poseur vérifié fonction par fonction · `now()` dans une colonne `text` transmis en `(now())::text`, même valeur exactement · ACL inchangées · 28 courriers |
| `20261009153817_mails_routes_contact_organisation.sql` | 580 | 1 fonction patchée (`contact_organisation_demander`) · 1 appel au poseur, 0 `INSERT` direct, **marqueur d'action du corps conservé** (il ne survit pas à une réécriture du message) · la demande est désormais enregistrée même si le courrier ne part pas · ACL inchangée · 28 courriers |
| `20261009153925_mails_routes_prets_helvetia.sql` | 581 | **7** patches appliqués à `traiter_prets_helvetia_quotidien`, **7** appels au poseur, 0 `INSERT` direct (balayage insensible à la casse) · les 2 courriers de copropriété toujours présents et toujours adressés au copropriétaire · un courrier en échec n'annule plus la passe nocturne entière du pays · ACL inchangée · 28 courriers |
| `20261009154659_mails_routes_placement_helvetia_et_arete_assemblee.sql` | 582 | la **11ᵉ** fonction trouvée en relevant avec `~*` (`resoudre_placement_helvetia` écrivait `insert into` en minuscules) : fonctions écrivant encore `mails` en direct **10 → 0**, le poseur excepté · `service_role` retiré sur les **2** intermédiaires `SECURITY INVOKER` de la chaîne de détection, qui restent `SECURITY INVOKER` (**0** passée en `DEFINER`) et gardent leurs **2** portes d'entrée `SECURITY DEFINER` · contenu et heure du courrier inchangés, droits de la fonction routée inchangés · 5 preuves vertes · 28 courriers, 0 fonction de banc subsistante |
| `20261009155036_detention_reduction_avocat_et_evasion_atomiques.sql` | 583 | `detention_reduire_peine(boolean)` et `detention_clore_evasion()` créées, `EXECUTE` à `authenticated` · deux libérations qui ne se persistaient qu'en mémoire écrivent désormais la fiche **en base** · avocat consommé **2** fois dans le corps (refus *et* acceptation), et c'est le serveur qui refuse la seconde requête · montant de la réduction calculé dans la porte (11 jours restants → −6, il en reste 5) · `jour_fin` **jamais réécrit** par l'évasion, reliquat rendu à part · 5 preuves vertes · 0 détention, 1 ligne QHS, empreinte des personnages identique |

La quatrième répare la première. La migration 1 avait révoqué `EXECUTE` sur ces
24 fonctions « FROM anon, authenticated » en laissant le `GRANT` à **PUBLIC**,
qui vaut pour tous les rôles : la révocation était sincère et sans effet. C'est
l'invariant 9 de `verifier-autorite.py`, relu après la réextraction du baseline,
qui l'a vu — il lit les droits tels qu'ils sont, pas tels qu'on a cru les
écrire. **Révoquer sur une fonction, c'est toujours `FROM PUBLIC` en plus des
rôles nommés.**

Les six premières n'ont touché aucune donnée : ni `INSERT`, ni `UPDATE` de
ligne, ni `DELETE`, ni `TRUNCATE`, ni `DROP TABLE`. Les 7 personnages de la bêta
sont intacts.

> **La septième, si — et il faut le dire ici et non seulement dans son en-tête.**
> `20261008235521_idempotence_prets_helvetia` a prouvé son effet en **faisant
> tourner la mécanique** : prêt témoin créé, RPC appelée quatre fois, témoin
> supprimé. Mais cette RPC crédite aussi la caisse de la banque privée à chaque
> prélèvement, et une migration **commite** — y compris les effets de bord de
> ses preuves, sur des tables auxquelles on ne pensait pas. 1 000 FR sont restés
> dans `republic_banque-privee` ; détectés par l'empreinte des caisses, qui ne
> correspondait plus, et restitués dans la minute à `{"solde": 0}`.
>
> **La règle qui en sort, et qui vaut pour toute migration future :** dans une
> migration, les preuves sont **structurelles** — lire le corps d'une fonction,
> compter des droits, vérifier une contrainte. L'épreuve **comportementale**
> appartient au banc en transaction annulée, avant application, et à lui seul.
> Les six premières respectaient déjà cette règle sans qu'elle soit écrite ;
> elle l'est maintenant.

> **Et une huitième touche une donnée EXPRÈS :**
> `20261009073456_restitution_arg_arnie_effet_de_bord_des_preuves` rend les
> 1 000 FR que les preuves ci-dessus avaient aussi retirés du solde du
> personnage témoin — effet de bord vu seulement après, en relisant *toutes* les
> écritures de la branche exécutée. Elle est passée par le canal normal,
> `apply_migration`, **précisément pour que le registre en garde la trace** : une
> correction de données hors registre serait exactement le trou que le chantier
> de reproductibilité a rebouché.
>
> **Ce qu'elle apprend en plus, et qui n'était pas évident** : il a fallu
> **relever `updated_at`**. `sbVerifierEtSauvegarderPersonnage` (supabase.js)
> compare l'horodatage serveur au dernier qu'elle a écrit ; s'ils sont égaux,
> elle republie sa copie en mémoire. Une session tenant encore l'ancienne valeur
> aurait donc écrasé la restitution en silence — le commentaire de cette
> fonction nomme exactement ce cas, « une correction serveur directe a écrit
> entretemps ». Relever l'horodatage n'est pas une coquetterie, c'est le
> mécanisme par lequel une correction serveur survit.
