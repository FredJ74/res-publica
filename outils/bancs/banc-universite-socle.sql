-- BANC DU SOCLE UNIVERSITAIRE (12 octobre 2026)
--
-- CE BANC NE COMMITE RIEN. Il pose un decor dans les six tables du socle, joue un cursus complet
-- jusqu'au diplome, un abandon, une expiration, et se termine par un RAISE EXCEPTION
-- INCONDITIONNEL.
--
-- CE QU'IL PROUVE :
--   1. la limite vaut EXACTEMENT le double de la duree theorique ;
--   2. un seul cursus actif a la fois ;
--   3. le rejeu d'une inscription ne cree pas de doublon ;
--   4. UN JALON NE PEUT PAS ETRE ACCOMPLI AVANT L'OUVERTURE DE SA SEMAINE -- c'est toute
--      l'incompressibilite de la duree, et aucun PA ni FR n'y change quoi que ce soit ;
--   5. le meme jalon ne compte qu'une fois : la repetition n'accelere pas ;
--   6. un jalon non fait ne fait PAS echouer le cursus -- il reste en cours ;
--   7. on ne diplome pas avant le terme theorique, meme tous jalons faits ;
--   8. on ne diplome pas avec des jalons incomplets ;
--   9. le diplome ecrit la qualification et consomme le slot a vie ;
--  10. une SECONDE qualification universitaire est impossible ;
--  11. l'abandon ne consomme PAS le slot, et on peut se reinscrire ;
--  12. l'expiration ne consomme PAS le slot, et on peut se reinscrire ;
--  13. un cursus expire n'accepte plus de jalon ;
--  14. les six tables sont fermees aux clients -- lecture directe refusee ;
--  15. l'expiration n'est pas a la main des joueurs ;
--  16. AUCUN personnage existant n'a recu de qualification.
--
-- Usage : coller ce fichier dans un execute_sql. Il doit finir sur
--   ERROR: banc universite : LES 21 EPREUVES SONT VERTES. -- rien ne doit rester
--
-- DEUX PIEGES RENCONTRES EN L'ECRIVANT, ET LES DEUX ETAIENT DANS LE BANC :
--   . deplacer la seule `limite_le` dans le passe viole `universite_limite_apres_fin_theorique`,
--     et la contrainte a raison : une limite ne peut pas preceder la fin theorique. Il faut
--     faire vieillir TOUTE l'inscription ;
--   . `now()` est CONSTANT dans une transaction, donc deux clotures du meme personnage portent la
--     MEME seconde : un `ORDER BY clos_le DESC LIMIT 1` est alors indecidable. L'assertion doit
--     porter sur l'inscription NOMMEE.

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
  MAY_U text := '3d91b1fa-a22d-41ae-82cf-fef98194b10a'; MAY text := 'May';
  v jsonb; n integer := 0; ko integer := 0; e text := ''; v_n integer; v_ins text; v_may text;
BEGIN
  PERFORM pg_temp.je_suis_le_serveur();

  -- DECOR : deux qualifications, deux cursus de durees differentes, trois jalons dont un de
  -- TERRAIN (le point de raccordement a une vraie activite de batiment, non branche).
  INSERT INTO public.qualifications (id, libelle) VALUES
    ('banc_q_a', 'Qualification du banc A'), ('banc_q_b', 'Qualification du banc B');
  INSERT INTO public.universite_cursus (id, libelle, qualification, semaines_theoriques) VALUES
    ('banc_c_a', 'Cursus du banc A', 'banc_q_a', 4),
    ('banc_c_b', 'Cursus du banc B', 'banc_q_b', 3);
  INSERT INTO public.universite_cursus_jalons (id, cursus, rang, libelle, genre, batiment) VALUES
    ('banc_j_a1', 'banc_c_a', 1, 'Semaine 1', 'universite', NULL),
    ('banc_j_a2', 'banc_c_a', 2, 'Semaine 2', 'terrain', 'banque-nationale'),
    ('banc_j_a4', 'banc_c_a', 4, 'Semaine 4', 'universite', NULL);

  n := n + 1;   -- E1 : LA LIMITE VAUT EXACTEMENT LE DOUBLE (4 semaines -> 8).
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_inscrire('banc_c_a', 'rq-banc-univ-001');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT id INTO v_ins FROM public.universite_inscriptions WHERE personnage = LEE AND statut='en_cours';
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nE1 inscription refusee : '||coalesce(v->>'raison','?');
  ELSIF (SELECT limite_le FROM public.universite_inscriptions WHERE id=v_ins)
     IS DISTINCT FROM public.universite_plus_semaines(
        (SELECT debut_le FROM public.universite_inscriptions WHERE id=v_ins), 8) THEN
    ko:=ko+1; e:=e||E'\nE1 la limite n est pas 2 x 4 semaines';
  END IF;

  n := n + 1;   -- E2 : UN SEUL CURSUS ACTIF.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_inscrire('banc_c_b', 'rq-banc-univ-002');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'cursus_deja_en_cours' THEN
    ko:=ko+1; e:=e||E'\nE2 deux cursus actifs : '||coalesce(v->>'raison','ACCEPTE'); END IF;

  n := n + 1;   -- E3 : REJEU sans doublon.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_inscrire('banc_c_a', 'rq-banc-univ-001');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.universite_inscriptions WHERE personnage=LEE;
  IF v->>'rejeu' <> 'true' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nE3 rejeu : '||v::text||' / '||v_n||' inscription(s)'; END IF;

  n := n + 1;   -- E4 : PAS D'ACCELERATION. La semaine 2 n'est pas ouverte le premier jour.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_jalon_accomplir('banc_j_a2', 'rq-banc-univ-j2');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'semaine_non_ouverte' THEN
    ko:=ko+1; e:=e||E'\nE4 jalon futur accepte : '||coalesce(v->>'raison','ACCEPTE'); END IF;

  n := n + 1;   -- E5 : la semaine 1 est ouverte immediatement.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_jalon_accomplir('banc_j_a1', 'rq-banc-univ-j1');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nE5 jalon ouvert refuse : '||coalesce(v->>'raison','?'); END IF;

  n := n + 1;   -- E6 : LA REPETITION N'ACCELERE PAS. Le meme jalon ne compte qu'une fois.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_jalon_accomplir('banc_j_a1', 'rq-banc-univ-j1-bis');
  PERFORM pg_temp.je_suis_le_serveur();
  SELECT count(*) INTO v_n FROM public.universite_jalons_accomplis WHERE inscription=v_ins;
  IF v->>'rejeu' <> 'true' OR v_n <> 1 THEN
    ko:=ko+1; e:=e||E'\nE6 jalon repete : '||v::text||' / '||v_n; END IF;

  n := n + 1;   -- E7 : UN JALON MANQUE N'ECHOUE PAS LE CURSUS.
  IF (SELECT statut FROM public.universite_inscriptions WHERE id=v_ins) <> 'en_cours' THEN
    ko:=ko+1; e:=e||E'\nE7 le cursus a echoue sur un jalon non fait'; END IF;

  n := n + 1;   -- E8 : LA DUREE THEORIQUE EST UN MINIMUM.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_diplomer('rq-banc-univ-dip1');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'duree_theorique_non_atteinte' THEN
    ko:=ko+1; e:=e||E'\nE8 diplome avant terme : '||coalesce(v->>'raison','ACCEPTE'); END IF;

  -- On fait vieillir TOUTE l'inscription : terme atteint, limite non. Deplacer la seule limite
  -- violerait la contrainte, et elle a raison.
  UPDATE public.universite_inscriptions
     SET debut_le = now() - interval '35 days',
         fin_theorique_le = now() - interval '7 days',
         limite_le = now() + interval '21 days'
   WHERE id = v_ins;

  n := n + 1;   -- E9 : JALONS INCOMPLETS, pas de diplome, et le compte est rendu.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_diplomer('rq-banc-univ-dip2');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'jalons_incomplets' OR (v->>'accomplis')::int <> 1 THEN
    ko:=ko+1; e:=e||E'\nE9 diplome avec jalons incomplets : '||v::text; END IF;

  PERFORM pg_temp.je_suis(LEE_U);
  PERFORM public.universite_jalon_accomplir('banc_j_a2', 'rq-banc-univ-j2b');
  PERFORM public.universite_jalon_accomplir('banc_j_a4', 'rq-banc-univ-j4b');
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- E10 : LE DIPLOME PASSE et consomme le slot.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_diplomer('rq-banc-univ-dip3');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v->>'qualification' <> 'banc_q_a'
     OR v->>'slot_consomme' <> 'true' THEN
    ko:=ko+1; e:=e||E'\nE10 diplome refuse : '||v::text; END IF;

  n := n + 1;   -- E11 : la qualification est inscrite, de source universitaire.
  IF NOT EXISTS (SELECT 1 FROM public.personnages_qualifications
                  WHERE personnage=LEE AND qualification='banc_q_a' AND source='universite') THEN
    ko:=ko+1; e:=e||E'\nE11 la qualification n est pas inscrite'; END IF;

  n := n + 1;   -- E12 : le cursus est clos en 'diplome'.
  IF (SELECT statut FROM public.universite_inscriptions WHERE id=v_ins) <> 'diplome' THEN
    ko:=ko+1; e:=e||E'\nE12 le cursus n est pas clos en diplome'; END IF;

  n := n + 1;   -- E13 : UNE SECONDE QUALIFICATION UNIVERSITAIRE EST IMPOSSIBLE.
  PERFORM pg_temp.je_suis(LEE_U);
  v := public.universite_inscrire('banc_c_b', 'rq-banc-univ-003');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'slot_universitaire_deja_consomme' THEN
    ko:=ko+1; e:=e||E'\nE13 seconde inscription acceptee : '||coalesce(v->>'raison','ACCEPTE'); END IF;

  n := n + 1;   -- E14 : L'ABANDON NE CONSOMME PAS LE SLOT.
  PERFORM pg_temp.je_suis(MAY_U);
  PERFORM public.universite_inscrire('banc_c_b', 'rq-banc-univ-may1');
  v := public.universite_abandonner('rq-banc-univ-may-ab');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE OR v->>'slot_consomme' <> 'false'
     OR public.universite_slot_consomme(MAY) THEN
    ko:=ko+1; e:=e||E'\nE14 abandon : '||v::text; END IF;

  n := n + 1;   -- E15 : et on peut se reinscrire apres un abandon.
  PERFORM pg_temp.je_suis(MAY_U);
  v := public.universite_inscrire('banc_c_b', 'rq-banc-univ-may2');
  PERFORM pg_temp.je_suis_le_serveur();
  v_may := v->>'inscription';
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nE15 reinscription apres abandon refusee : '||coalesce(v->>'raison','?'); END IF;

  n := n + 1;   -- E16 : L'EXPIRATION NE CONSOMME PAS LE SLOT.
  UPDATE public.universite_inscriptions
     SET debut_le = now() - interval '70 days',
         fin_theorique_le = now() - interval '49 days',
         limite_le = now() - interval '1 day'
   WHERE id = v_may;
  v := public.universite_expirer_echues();
  IF (v->>'expires')::int <> 1
     OR (SELECT statut FROM public.universite_inscriptions WHERE id = v_may) <> 'expire'
     OR public.universite_slot_consomme(MAY) THEN
    ko:=ko+1; e:=e||E'\nE16 expiration : '||v::text||' / statut='
      ||coalesce((SELECT statut FROM public.universite_inscriptions WHERE id=v_may),'?')
      ||' / slot='||public.universite_slot_consomme(MAY)::text; END IF;

  n := n + 1;   -- E17 : un cursus expire n'accepte plus de jalon.
  PERFORM pg_temp.je_suis(MAY_U);
  v := public.universite_jalon_accomplir('banc_j_a1', 'rq-banc-univ-may-j');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce(v->>'raison','') <> 'aucun_cursus_en_cours' THEN
    ko:=ko+1; e:=e||E'\nE17 jalon apres expiration : '||coalesce(v->>'raison','ACCEPTE'); END IF;

  n := n + 1;   -- E18 : LES SIX TABLES SONT FERMEES AUX CLIENTS.
  BEGIN
    PERFORM set_config('role', 'authenticated', true);
    PERFORM count(*) FROM public.universite_inscriptions;
    ko:=ko+1; e:=e||E'\nE18 un client a lu universite_inscriptions directement';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- E19 : l'expiration n'est pas a la main des joueurs.
  BEGIN
    PERFORM pg_temp.je_suis(LEE_U);
    PERFORM public.universite_expirer_echues();
    ko:=ko+1; e:=e||E'\nE19 un joueur a pu expirer les cursus';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.je_suis_le_serveur();

  n := n + 1;   -- E20 : AUCUN personnage existant n'a recu de qualification.
  SELECT count(*) INTO v_n FROM public.personnages_qualifications
   WHERE qualification NOT LIKE 'banc\_%';
  IF v_n <> 0 THEN ko:=ko+1; e:=e||E'\nE20 '||v_n||' qualification(s) non issue(s) du banc'; END IF;

  n := n + 1;   -- E21 : apres expiration, la reinscription passe -- le slot etait bien libre.
  PERFORM pg_temp.je_suis(MAY_U);
  v := public.universite_inscrire('banc_c_b', 'rq-banc-univ-may3');
  PERFORM pg_temp.je_suis_le_serveur();
  IF coalesce((v->>'ok')::boolean,false) IS NOT TRUE THEN
    ko:=ko+1; e:=e||E'\nE21 reinscription apres expiration refusee : '||coalesce(v->>'raison','?'); END IF;

  IF ko = 0 THEN RAISE EXCEPTION 'banc universite : LES % EPREUVES SONT VERTES. -- rien ne doit rester', n;
  ELSE RAISE EXCEPTION 'banc universite : % epreuve(s) sur % en defaut.%', ko, n, e; END IF;
END
$banc$;
ROLLBACK;
