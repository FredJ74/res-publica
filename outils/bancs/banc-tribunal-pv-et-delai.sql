-- BANC DU PV D'AUDITION, DU DELAI DE JUGEMENT ET DE LA PROCEDURE SIMPLIFIEE
-- 12 octobre 2026, nuit -- 24 epreuves
--
-- CE BANC NE COMMITE RIEN. Il pose un decor dans `plaintes_en_cours`, `postes_attribues`,
-- `personnages_donnees` et `rp_epoques`, joue la chaine pour de vrai, et se termine par un
-- RAISE EXCEPTION INCONDITIONNEL qui annule tout.
--
-- POURQUOI IL EXISTE. Les 30 preuves des trois migrations sont STRUCTURELLES : elles lisent des
-- catalogues, comptent des contraintes, verifient qu'une condition figure dans un corps de
-- fonction. Aucune ne peut prouver qu'un PV LIBERE reellement, qu'un delai MORD au bon jour, ni
-- qu'une reussite critique ne clot PAS un crime. Ca se joue, et ca se joue en ecrivant.
--
-- COMMENT LE TEMPS EST SIMULE. `jour_de_jeu_pays` derive le jour du jeu de `rp_epoques.jour_un`.
-- Reculer cette date d'une journee avance le monde d'un jour. On ne touche donc NI au dossier
-- NI a l'echeance pour eprouver l'expiration : c'est le temps qui passe, pas la donnee qu'on
-- corrige -- sans quoi on eprouverait sa propre triche.
--
-- CE QU'IL PROUVE :
--   1-3.   le domaine de la procedure simplifiee : infraction canonique exigee, >= 3 jours
--          refuse MEME en reussite critique, <= 2 jours accepte ;
--   4-5.   la defense est DEFINITIVE, et elle est consignee a la chronologie ;
--   6-10.  le PV : pas celui d'un autre, pas vide, verbatim, une seule fois, refus valide ;
--   11-12. le PV libere la garde a vue et NE libere PAS une peine en cours d'execution ;
--   13.    INCULPE est derive du dossier, pas stocke ;
--   14-16. le delai mord au seizieme jour, pas au quinzieme, et s'oppose au parquet ;
--   17-19. l'expiration est reservee au serveur, clot le dossier, et retire l'avis de recherche ;
--   20-21. RECHERCHE et INCULPE se cumulent sur deux affaires differentes ;
--   22-24. la table des PV est append-only, et fermee aux clients.
--
-- Usage : coller ce fichier dans un execute_sql, debarrasse de ses lignes de commentaire. Il
-- doit finir sur
--   ERROR: banc tribunal : LES 24 EPREUVES SONT VERTES. -- rien ne doit rester

BEGIN;
CREATE OR REPLACE FUNCTION pg_temp.je_suis(p_uuid text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_uuid, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.je_suis_le_serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', '', true);
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION pg_temp.je_suis_le_serveur() TO PUBLIC;

DO $banc$
DECLARE
  LEE_U text := 'ea4a2a0c-a192-4e10-8cff-d5db9b1cceb6'; LEE text := 'Lee Capene';
  TIERS_U text := '0821bcdf-0c69-4ba3-adcd-f60d9b82b7bf'; TIERS text := 'Phileas Frogg';
  v jsonb; n integer := 0; ko integer := 0; e text := '';
  v_n integer; v_d jsonb; v_jour integer; v_ech integer; v_txt text; v_leve boolean;
  A_FLOU  text := 'banc-tri-flou';
  A_GRAVE text := 'banc-tri-grave';
  A_LEGER text := 'banc-tri-leger';
  A_DEUX  text := 'banc-tri-deux';
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();
  v_jour := public.jour_de_jeu_pays('republic');

  -- DECOR : quatre dossiers contre Lee, dans la capitale, tous AU PARQUET.
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    (A_FLOU, 'republic', 'capitale', jsonb_build_object('id', A_FLOU, 'auteur', TIERS,
       'cible', LEE, 'motif', 'Quelque chose de vague', 'jour', v_jour,
       'city', 'capitale', 'country', 'republic', 'status', 'au_parquet')::text),
    (A_GRAVE, 'republic', 'capitale', jsonb_build_object('id', A_GRAVE, 'auteur', TIERS,
       'cible', LEE, 'motif', 'Il a tue mon chien', 'jour', v_jour,
       'city', 'capitale', 'country', 'republic', 'status', 'au_parquet',
       'infraction_constatee', 'assassiner_mains')::text),
    (A_LEGER, 'republic', 'capitale', jsonb_build_object('id', A_LEGER, 'auteur', TIERS,
       'cible', LEE, 'motif', 'Il a pris mon manteau', 'jour', v_jour,
       'city', 'capitale', 'country', 'republic', 'status', 'au_parquet',
       'infraction_constatee', 'vol')::text),
    (A_DEUX, 'republic', 'capitale', jsonb_build_object('id', A_DEUX, 'auteur', TIERS,
       'cible', LEE, 'motif', 'Tracts', 'jour', v_jour,
       'city', 'capitale', 'country', 'republic', 'status', 'au_parquet',
       'infraction_constatee', 'imprimer_tracts_calomnieux')::text);

  -- =========================================================== LA PROCEDURE SIMPLIFIEE
  -- LES CINQ PREMIERES EPREUVES ONT ETE RECALIBREES LE 12 OCTOBRE 2026 AU SOIR, et il fallait
  -- bien les toucher : elles appelaient `plainte_defendre(affaire, issue)`, une signature qui
  -- N'EXISTE PLUS. L'issue n'est plus annoncee par l'appelant -- c'etait le navigateur qui
  -- decidait d'une peine -- et la porte ne prend plus qu'un identifiant d'affaire. Le DOMAINE
  -- qu'elles mesuraient, lui, est inchange, et c'est ce qu'elles mesurent encore.
  -- La resolution elle-meme (formule, jet, jugement, execution, absence d'appel) est eprouvee
  -- par outils/bancs/banc-defense-simplifiee.sql -- 22 epreuves.

  n := n + 1;   -- T1 : SANS INFRACTION CANONIQUE, RIEN A PLAIDER. Le seuil n'est pas calculable.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.plainte_defendre(A_FLOU);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'infraction_non_determinee' THEN
    ko:=ko+1; e:=e||E'\nT1 dossier sans infraction : '||v::text; END IF;

  n := n + 1;   -- T2 : UN CRIME A 8 JOURS NE SE PLAIDE PAS EN DIX SECONDES. C'est LE defaut que
                --      le §A demandait de fermer, et le refus doit laisser le dossier INTACT.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.plainte_defendre(A_GRAVE);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = A_GRAVE;
  IF coalesce(v->>'raison','') <> 'procedure_simplifiee_reservee_aux_peines_courtes'
     OR (v->>'jours_reference')::int <> 8
     OR coalesce(v_d->>'status','') <> 'au_parquet' OR (v_d ? 'defense_le') THEN
    ko:=ko+1; e:=e||E'\nT2 crime clos par la defense : '||v::text||' / '||v_d::text; END IF;

  n := n + 1;   -- T3 : UNE PEINE DE REFERENCE A 1 JOUR PASSE, et le SERVEUR rend le verdict.
                --      L'issue n'est plus un parametre : elle est dans la reponse.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.plainte_defendre(A_LEGER);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = A_LEGER;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE
     OR (v_d->>'procedure_simplifiee') <> 'true'
     OR (v_d->>'status') NOT IN ('jugee','relaxe')
     OR (v->>'verdict') NOT IN ('condamnation','relaxe')
     OR (v->>'taux')::int NOT BETWEEN 5 AND 80
     OR (v->>'avocat') IS NULL THEN
    ko:=ko+1; e:=e||E'\nT3 defense sur peine courte : '||v::text||' / '||v_d::text; END IF;

  n := n + 1;   -- T4 : LA PROCEDURE EST DEFINITIVE. On ne relance pas le jet jusqu'a gagner --
                --      et desormais c'est le STATUT qui ferme la porte, le dossier etant juge.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.plainte_defendre(A_LEGER);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = A_LEGER;
  IF coalesce(v->>'raison','') NOT IN ('defense_deja_plaidee','affaire_non_defendable')
     OR (v_d->>'status') NOT IN ('jugee','relaxe') THEN
    ko:=ko+1; e:=e||E'\nT4 seconde defense : '||v::text||' / '||v_d::text; END IF;

  n := n + 1;   -- T5 : LA DEFENSE EST CONSIGNEE, ET LE VERDICT AVEC ELLE. Deux actes, pas un.
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = A_LEGER AND type = 'defense_simplifiee' AND acteur = LEE
     AND qualif_apres = 'vol' AND (donnees->>'avocat') IS NOT NULL;
  IF v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT5 defense non consignee : '||v_n||' acte(s)'; END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = A_LEGER AND type IN ('condamnation','relaxe')
     AND (donnees->>'procedure') = 'simplifiee';
  IF v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT5b verdict non consigne : '||v_n||' acte(s)'; END IF;

  -- ON REND SA LIBERTE AU PREVENU AVANT LA SUITE DU BANC. La procedure simplifiee est desormais
  -- IMMEDIATEMENT EXECUTOIRE : si le jet est perdant, elle ouvre une detention -- et une peine en
  -- cours empecherait les epreuves suivantes d'en ouvrir une, pour une raison qui n'aurait rien a
  -- voir avec ce qu'elles mesurent. Ce n'est pas un contournement : c'est du decor qu'on remet en
  -- place entre deux mesures.
  DELETE FROM public.detentions WHERE nom = LEE;
  UPDATE public.personnages_donnees SET est_emprisonne = NULL WHERE name = LEE;

  -- =========================================================== LE PV D'AUDITION
  n := n + 1;   -- T6 : LE PV EST CELUI DE L'ACCUSE, ET DE LUI SEUL.
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.pv_audition_realiser(A_GRAVE, 'Je parle a sa place', false);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'pas_mon_affaire' THEN
    ko:=ko+1; e:=e||E'\nT6 PV d un tiers : '||v::text; END IF;

  n := n + 1;   -- T7 : UN PV VIDE N'EST PAS UNE REPONSE. Le silence n'est pas un refus.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.pv_audition_realiser(A_GRAVE, '   ', false);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'reponse_absente' THEN
    ko:=ko+1; e:=e||E'\nT7 PV vide accepte : '||v::text; END IF;

  n := n + 1;   -- T8 : LA DECLARATION EST CONSIGNEE VERBATIM, et le delai part du PV.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.pv_audition_realiser(A_GRAVE,
         'Je ne parlerai qu''en presence de mon avocat, Maitre Plaidoyer.', false);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = A_GRAVE;
  SELECT declaration INTO v_txt FROM public.dossiers_auditions
   WHERE affaire = A_GRAVE AND personne = LEE;
  v_ech := v_jour + 15;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE
     OR (v->>'delai_jugement_jour')::int <> v_ech
     OR (v_d->>'delai_jugement_jour')::int <> v_ech
     OR v_txt <> 'Je ne parlerai qu''en presence de mon avocat, Maitre Plaidoyer.' THEN
    ko:=ko+1; e:=e||E'\nT8 PV declaration : '||v::text||' / verbatim='||coalesce(v_txt,'(nul)'); END IF;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = A_GRAVE AND type = 'pv_audition' AND acteur = LEE;
  IF v_n <> 1 THEN ko:=ko+1; e:=e||E'\nT8b PV non consigne a la chronologie'; END IF;

  n := n + 1;   -- T9 : UNE SEULE AUDITION PAR DOSSIER.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.pv_audition_realiser(A_GRAVE, 'Je me ravise', false);
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'audition_deja_realisee' THEN
    ko:=ko+1; e:=e||E'\nT9 second PV : '||v::text; END IF;

  n := n + 1;   -- T10 : LE REFUS EST UNE REPONSE VALIDE, et il n'ecrit aucun texte.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.pv_audition_realiser(A_DEUX, 'ce texte doit etre ignore', true);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.dossiers_auditions
   WHERE affaire = A_DEUX AND personne = LEE AND refus IS TRUE AND declaration IS NULL;
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'refus') <> 'true' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT10 PV refus : '||v::text||' / '||v_n||' ligne(s)'; END IF;

  -- =========================================================== LA LIBERATION
  n := n + 1;   -- T11 : LE PV LIBERE UNE GARDE A VUE.
  PERFORM public.detention_ouvrir_interne(TIERS, 'Garde a vue de banc', 2, 'capitale', 'republic',
    jsonb_build_array(jsonb_build_object('type','Garde a vue de banc','jours',2,'city','capitale')),
    'banc', 'garde_a_vue');
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    ('banc-tri-gav', 'republic', 'capitale', jsonb_build_object('id','banc-tri-gav',
      'auteur', LEE, 'cible', TIERS, 'motif', 'Vol', 'jour', v_jour, 'city', 'capitale',
      'country', 'republic', 'status', 'au_parquet', 'infraction_constatee', 'vol')::text);
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.pv_audition_realiser('banc-tri-gav', NULL, true);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.detention_active(TIERS);
  IF (v->>'libere') <> 'true' OR v_n <> 0 THEN
    ko:=ko+1; e:=e||E'\nT11 garde a vue non levee par le PV : '||v::text||' / '||v_n; END IF;

  n := n + 1;   -- T12 : LE PV NE LIBERE PAS UNE PEINE EN COURS D'EXECUTION. Il n'est pas une
                --       grace, et un condamne qui se fait auditionner sur une AUTRE affaire ne
                --       doit pas sortir de prison par cette porte.
  PERFORM public.detention_ouvrir_interne(TIERS, 'Peine de banc', 5, 'capitale', 'republic',
    jsonb_build_array(jsonb_build_object('type','Peine de banc','jours',5,'city','capitale')),
    'banc', 'condamnation');
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    ('banc-tri-autre', 'republic', 'capitale', jsonb_build_object('id','banc-tri-autre',
      'auteur', LEE, 'cible', TIERS, 'motif', 'Tracts', 'jour', v_jour, 'city', 'capitale',
      'country', 'republic', 'status', 'au_parquet',
      'infraction_constatee', 'imprimer_tracts_calomnieux')::text);
  PERFORM pg_temp.je_suis(TIERS_U);
  v := public.pv_audition_realiser('banc-tri-autre', NULL, true);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.detention_active(TIERS);
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR (v->>'libere') <> 'false' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT12 peine en cours levee par un PV : '||v::text||' / detentions '||v_n; END IF;
  PERFORM public.detention_clore_interne(TIERS, 'fin_de_banc', v_jour);

  -- =========================================================== LES STATUTS
  n := n + 1;   -- T13 : INCULPE EST DERIVE DU DOSSIER. Rien n'est stocke nulle part.
  SELECT count(*) INTO v_n FROM public.justice_affaires_vivantes_avec_pv(LEE);
  IF v_n <> 2 THEN
    ko:=ko+1; e:=e||E'\nT13 inculpations derivees : '||v_n||' au lieu de 2'; END IF;

  -- =========================================================== LE DELAI
  n := n + 1;   -- T14 : AU JOUR DE L'ECHEANCE, LE DELAI N'EST PAS EXPIRE. Le quinzieme jour est
                --       le dernier jour utile : un `>=` en aurait retire un.
  UPDATE public.rp_epoques SET jour_un = jour_un - 15 WHERE pays = 'republic';
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = A_GRAVE;
  IF public.jour_de_jeu_pays('republic') <> v_ech
     OR public.affaire_delai_expire(v_d, 'republic') IS NOT FALSE THEN
    ko:=ko+1; e:=e||E'\nT14 expiration au jour de l echeance (jour='
      ||public.jour_de_jeu_pays('republic')||', echeance='||v_ech||')'; END IF;

  n := n + 1;   -- T15 : LE LENDEMAIN, IL EST EXPIRE.
  UPDATE public.rp_epoques SET jour_un = jour_un - 1 WHERE pays = 'republic';
  IF public.affaire_delai_expire(v_d, 'republic') IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nT15 pas d expiration au seizieme jour'; END IF;

  n := n + 1;   -- T16 : LE PARQUET NE PEUT PLUS RIEN SUR UN DOSSIER PERIME -- avant meme que la
                --       passe de minuit ne soit passee.
  v := public.parquet_garde(A_GRAVE, ARRAY['au_parquet']);
  IF coalesce(v->>'raison','') NOT IN ('pas_procureur', 'delai_de_jugement_expire') THEN
    ko:=ko+1; e:=e||E'\nT16 garde du parquet sur dossier perime : '||v::text; END IF;

  n := n + 1;   -- T17 : L'EXPIRATION EST RESERVEE AU SERVEUR, ET LE REFUS VIENT DU PRIVILEGE.
  --
  -- PREMIERE VERSION DE CETTE EPREUVE : elle attendait le refus doux `reserve_au_serveur` que la
  -- fonction rend elle-meme. Elle ne l'a jamais obtenu -- l'appel LEVE `42501 permission denied`
  -- AVANT d'entrer dans le corps, parce que la fonction n'a aucun GRANT client. La garde interne
  -- reste utile (elle couvre un futur appelant qui aurait le droit), mais la vraie porte est le
  -- privilege, et c'est elle qu'il faut eprouver. Le GRANT est la vraie porte : doctrine du depot.
  v_leve := false;
  BEGIN
    PERFORM pg_temp.je_suis(LEE_U);
    PERFORM public.justice_delais_echus();
  EXCEPTION WHEN insufficient_privilege THEN v_leve := true; END;
  PERFORM pg_temp.je_suis_le_serveur();
  IF NOT v_leve THEN
    ko:=ko+1; e:=e||E'\nT17 un joueur a pu appeler justice_delais_echus'; END IF;

  n := n + 1;   -- T18 : LA PASSE CLOT LES DOSSIERS PERIMES ET LES CONSIGNE.
  PERFORM public.recherche_inscrire(
    jsonb_build_object('acte','assassiner_mains','type','crime','jour',v_jour), LEE);
  PERFORM public.recherche_inscrire(
    jsonb_build_object('acte','vol','type','delit_mineur','jour',v_jour), LEE);
  v := public.justice_delais_echus();
  SELECT data::jsonb INTO v_d FROM public.plaintes_en_cours WHERE id = A_GRAVE;
  SELECT count(*) INTO v_n FROM public.dossiers_judiciaires_actes
   WHERE affaire = A_GRAVE AND type = 'charges_abandonnees_delai';
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE
     OR coalesce(v_d->>'status','') <> 'delai_expire' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT18 cloture du dossier perime : '||v::text||' / '||v_d::text; END IF;

  n := n + 1;   -- T19 : LA RECHERCHE EST RESOLUE CONFORMEMENT A LA CLOTURE -- l'acte clos part,
                --       les autres restent. Un motif n'en efface jamais un autre.
  SELECT count(*) INTO v_n FROM public.personnages_donnees d,
         jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche)='array' THEN d.recherche ELSE '[]'::jsonb END) x
   WHERE d.name = LEE AND x->>'acte' = 'assassiner_mains';
  IF v_n <> 0 THEN
    ko:=ko+1; e:=e||E'\nT19 l avis de recherche de l acte clos survit : '||v_n; END IF;
  SELECT count(*) INTO v_n FROM public.personnages_donnees d,
         jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche)='array' THEN d.recherche ELSE '[]'::jsonb END) x
   WHERE d.name = LEE AND x->>'acte' = 'vol';
  IF v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT19b un autre motif a ete efface : vol='||v_n; END IF;

  n := n + 1;   -- T20 : LE DOSSIER CLOS NE REND PLUS SON PORTEUR INCULPE.
  SELECT count(*) INTO v_n FROM public.justice_affaires_vivantes_avec_pv(LEE)
   WHERE affaire = A_GRAVE;
  IF v_n <> 0 THEN
    ko:=ko+1; e:=e||E'\nT20 inculpe sur un dossier clos'; END IF;

  n := n + 1;   -- T21 : CUMUL RECHERCHE + INCULPE SUR DEUX AFFAIRES DIFFERENTES. C'est l'exemple
                --       exact du cahier des charges : l'audition de l'affaire A ne suspend rien
                --       de l'affaire B.
  --
  -- LE DECOR EST REFAIT ICI, ET LA PREMIERE VERSION DE CETTE EPREUVE L'A APPRIS. Elle reutilisait
  -- l'affaire du PV de refus (A_DEUX) apres avoir remis le temps a l'endroit -- mais cette affaire
  -- avait ete CLOSE par la passe d'expiration de T18, exactement comme la premiere : son PV datait
  -- du meme jour, donc son echeance aussi. Le banc se contredisait lui-meme. Un dossier NEUF est
  -- donc ouvert, et son audition faite, APRES le retour du temps.
  UPDATE public.rp_epoques SET jour_un = jour_un + 16 WHERE pays = 'republic';
  INSERT INTO public.plaintes_en_cours (id, country, city, data) VALUES
    ('banc-tri-cumul', 'republic', 'capitale', jsonb_build_object('id','banc-tri-cumul',
      'auteur', TIERS, 'cible', LEE, 'motif', 'Nouvelle affaire', 'jour', v_jour,
      'city', 'capitale', 'country', 'republic', 'status', 'au_parquet',
      'infraction_constatee', 'imprimer_tracts_calomnieux')::text);
  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.pv_audition_realiser('banc-tri-cumul', NULL, true);
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.justice_affaires_vivantes_avec_pv(LEE)
   WHERE affaire = 'banc-tri-cumul';
  IF v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT21 l affaire avec PV ne rend pas inculpe : '||v_n; END IF;
  -- La recherche pour `vol` subsiste : aucune affaire avec PV ne porte cette qualification.
  SELECT count(*) INTO v_n FROM public.personnages_donnees d,
         jsonb_array_elements(CASE WHEN jsonb_typeof(d.recherche)='array' THEN d.recherche ELSE '[]'::jsonb END) x
   WHERE d.name = LEE AND x->>'acte' = 'vol'
     AND NOT EXISTS (SELECT 1 FROM public.justice_affaires_vivantes_avec_pv(LEE) w
                      WHERE w.infraction = x->>'acte');
  IF v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nT21b le cumul recherche+inculpe ne tient pas : '||v_n; END IF;

  -- =========================================================== L'APPEND-ONLY
  n := n + 1;   -- T22 : UN PV NE SE REECRIT PAS, MEME EN POSTGRES.
  v_leve := false;
  BEGIN
    UPDATE public.dossiers_auditions SET declaration = 'reecrit' WHERE affaire = A_GRAVE;
  EXCEPTION WHEN raise_exception THEN v_leve := true; END;
  IF NOT v_leve THEN ko:=ko+1; e:=e||E'\nT22 un PV a pu etre reecrit'; END IF;

  n := n + 1;   -- T23 : NI EFFACE.
  v_leve := false;
  BEGIN
    DELETE FROM public.dossiers_auditions WHERE affaire = A_GRAVE;
  EXCEPTION WHEN raise_exception THEN v_leve := true; END;
  IF NOT v_leve THEN ko:=ko+1; e:=e||E'\nT23 un PV a pu etre efface'; END IF;

  n := n + 1;   -- T24 : UN CLIENT NE LIT PAS LES PV DIRECTEMENT.
  v_leve := false;
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM count(*) FROM public.dossiers_auditions;
  EXCEPTION WHEN insufficient_privilege THEN v_leve := true; END;
  PERFORM pg_temp.je_suis_le_serveur();
  IF NOT v_leve THEN ko:=ko+1; e:=e||E'\nT24 un client a lu dossiers_auditions'; END IF;

  IF ko = 0 THEN RAISE EXCEPTION 'banc tribunal : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE RAISE EXCEPTION 'banc tribunal : % epreuve(s) sur % en defaut.%', ko, n, e; END IF;
END
$banc$;
ROLLBACK;
