-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011195949 (UTC), nom
-- `calendrier_succession_alignement_porte_la_fin_de_mandat`.
-- Le registre passe de 666 a 667 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 62e7ba62b16a51cb1034e7a7dfb3dfe8, 6226 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- L'ALIGNEMENT AU DIMANCHE PORTE AUSSI LA FIN DU MANDAT (4/4)
--
-- CELLE-LA N'ETAIT PAS AU PLAN : C'EST LE BANC QUI L'A TROUVEE. `cycle_electoral_aligne_dimanche`
-- est un filet, pose en declencheur sur `cycles_electoraux` : il recale sur le dimanche un
-- scrutin dont les dates auraient derive. Il reecrit `dateDebutCampagne`, `dateVote` et
-- `dateResultats` -- et il ignorait `dateFinMandat`, qui n'existait pas comme jumeau de
-- `dateResultats` quand il a ete ecrit.
--
-- DEPUIS LE CORRECTIF, LES DEUX SONT LE MEME INSTANT PAR REGLE : un mandat finit exactement quand
-- son successeur est proclame. Un filet qui deplace l'un sans l'autre les fait donc DIVERGER, et
-- c'est la fin du mandat qui devient fausse. En production ce filet ne se declenche plus -- le
-- moteur rend des dates deja alignees -- mais il reste pour les blobs venus d'ailleurs, et c'est
-- precisement pour ceux-la qu'il doit etre juste.
--
-- Quatre preuves, dont deux COMPORTEMENTALES et c'est inhabituel pour une migration : la fonction
-- est STABLE et pure, donc l'appeler sur deux blobs forges n'ecrit rien et ne commite aucun effet
-- de bord. Un blob desaligne ressort avec `dateFinMandat` egal a `dateResultats` ; un blob deja
-- aligne ressort IDENTIQUE -- le cas de production.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CALENDRIER ELECTORAL COMMUN -- L'ALIGNEMENT AU DIMANCHE PORTE AUSSI LA FIN DU MANDAT
-- 11 octobre 2026
--
-- CE QUE LE BANC A TROUVE, ET QUI N'ETAIT PAS DANS LE PLAN. `cycle_electoral_aligne_dimanche`
-- est un filet : pose en declencheur BEFORE INSERT/UPDATE sur `cycles_electoraux`, il recale sur
-- le dimanche un scrutin dont les dates auraient derive. Il reecrit `dateDebutCampagne`,
-- `dateVote` et `dateResultats` -- et il ignorait `dateFinMandat`, qui n'existait pas comme
-- jumeau de `dateResultats` quand il a ete ecrit.
--
-- DEPUIS LE CORRECTIF DU CALENDRIER DE SUCCESSION, LES DEUX SONT LE MEME INSTANT PAR REGLE : un
-- mandat finit exactement quand son successeur est proclame. Un filet qui deplace l'un sans
-- l'autre les fait donc DIVERGER, et c'est la fin du mandat qui devient fausse.
--
-- EN PRODUCTION CE FILET NE SE DECLENCHE PLUS : le moteur rend des dates deja alignees sur le
-- dimanche, donc la fonction sort par son retour « rien a changer ». Il reste pour les blobs
-- venus d'ailleurs -- et c'est precisement pour ceux-la qu'il doit etre juste.
--
-- Et la garde de sortie perd la phase du mandat, qui n'est plus jamais ecrite : seule la vacance
-- reste, pour un poste jamais pourvu.
CREATE OR REPLACE FUNCTION public.cycle_electoral_aligne_dimanche(p_d jsonb, p_maintenant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ms       numeric := floor(extract(epoch FROM p_maintenant) * 1000);
  v_loc      timestamp;
  v_dim      timestamp;
  v_vote     numeric;
  v_res      numeric;
  v_cloture  numeric;
  v_sortie   jsonb;
BEGIN
  IF p_d IS NULL OR jsonb_typeof(p_d) <> 'object' OR jsonb_typeof(p_d -> 'dateVote') <> 'number' THEN RETURN p_d; END IF;
  IF COALESCE((p_d ->> 'resultatsTraites')::boolean, false) OR COALESCE(p_d ->> 'phase', '') = 'vacant' THEN RETURN p_d; END IF;
  IF (p_d ->> 'dateVote')::numeric <= v_ms THEN RETURN p_d; END IF;

  v_loc := to_timestamp((p_d ->> 'dateVote')::numeric / 1000) AT TIME ZONE 'Europe/Paris';
  v_dim := date_trunc('day', v_loc) + ((7 - extract(isodow FROM v_loc)::int) % 7) * interval '1 day' + interval '1 minute';
  IF v_dim < v_loc THEN v_dim := v_dim + interval '7 days'; END IF;
  v_vote    := floor(extract(epoch FROM (v_dim AT TIME ZONE 'Europe/Paris')) * 1000);
  v_res     := floor(extract(epoch FROM ((date_trunc('day', v_dim) + interval '1 day') AT TIME ZONE 'Europe/Paris')) * 1000);
  v_cloture := floor(extract(epoch FROM ((date_trunc('day', v_dim) - interval '6 days' + interval '1 minute') AT TIME ZONE 'Europe/Paris')) * 1000);

  IF v_vote = (p_d ->> 'dateVote')::numeric AND jsonb_typeof(p_d -> 'dateResultats') = 'number'
     AND (p_d ->> 'dateResultats')::numeric = v_res THEN
    RETURN p_d;
  END IF;
  IF jsonb_typeof(p_d -> 'dateDebutCampagne') = 'number'
     AND ((p_d ->> 'dateDebutCampagne')::numeric <= v_ms OR (p_d ->> 'dateDebutCampagne')::numeric > v_cloture) THEN
    v_cloture := (p_d ->> 'dateDebutCampagne')::numeric;
  END IF;
  v_sortie := p_d || jsonb_build_object('dateDebutCampagne', v_cloture, 'dateVote', v_vote, 'dateResultats', v_res,
                                        'realigneDimancheTs', v_ms);
  -- LA FIN DU MANDAT SUIT LA PROCLAMATION, TOUJOURS. Elle n'est posee que si le blob en portait
  -- une : un cycle sans titulaire n'a pas de mandat a dater, et lui en inventer un serait faux.
  IF jsonb_typeof(p_d -> 'dateFinMandat') = 'number' THEN
    v_sortie := v_sortie || jsonb_build_object('dateFinMandat', v_res);
  END IF;
  RETURN v_sortie;
END;
$function$;

DO $preuve$
DECLARE v_txt text; v_d jsonb; v_n jsonb;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'cycle_electoral_aligne_dimanche';
  IF position('''dateFinMandat'', v_res' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- l''alignement ne porte pas la fin du mandat';
  END IF;
  IF position('''mandat''' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- l''alignement lit encore la phase du mandat';
  END IF;

  -- UN BLOB DESALIGNE : vote un mardi. L'alignement doit le porter au dimanche suivant, et
  -- emmener `dateFinMandat` avec `dateResultats`.
  v_d := jsonb_build_object(
    'phase', 'candidatures', 'resultatsTraites', false,
    'dateDebutCampagne', floor(extract(epoch FROM (timestamp '2026-12-07 00:01' AT TIME ZONE 'Europe/Paris')) * 1000),
    'dateVote',          floor(extract(epoch FROM (timestamp '2026-12-15 00:01' AT TIME ZONE 'Europe/Paris')) * 1000),
    'dateResultats',     floor(extract(epoch FROM (timestamp '2026-12-16 00:00' AT TIME ZONE 'Europe/Paris')) * 1000),
    'dateFinMandat',     floor(extract(epoch FROM (timestamp '2026-12-16 00:00' AT TIME ZONE 'Europe/Paris')) * 1000));
  v_n := public.cycle_electoral_aligne_dimanche(v_d, timestamp with time zone '2026-11-30 12:00+01');
  IF (v_n ->> 'dateFinMandat')::numeric IS DISTINCT FROM (v_n ->> 'dateResultats')::numeric THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- apres alignement, la fin du mandat et la proclamation divergent';
  END IF;
  IF extract(isodow FROM (to_timestamp((v_n ->> 'dateVote')::numeric / 1000) AT TIME ZONE 'Europe/Paris')) <> 7 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le vote realigne n''est pas un dimanche';
  END IF;

  -- UN BLOB DEJA ALIGNE N'EST PAS TOUCHE : c'est le cas de production.
  v_d := jsonb_build_object(
    'phase', 'candidatures', 'resultatsTraites', false,
    'dateDebutCampagne', floor(extract(epoch FROM (timestamp '2026-12-07 00:01' AT TIME ZONE 'Europe/Paris')) * 1000),
    'dateVote',          floor(extract(epoch FROM (timestamp '2026-12-13 00:01' AT TIME ZONE 'Europe/Paris')) * 1000),
    'dateResultats',     floor(extract(epoch FROM (timestamp '2026-12-14 00:00' AT TIME ZONE 'Europe/Paris')) * 1000),
    'dateFinMandat',     floor(extract(epoch FROM (timestamp '2026-12-14 00:00' AT TIME ZONE 'Europe/Paris')) * 1000));
  IF public.cycle_electoral_aligne_dimanche(v_d, timestamp with time zone '2026-11-30 12:00+01') IS DISTINCT FROM v_d THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- un calendrier deja aligne est reecrit';
  END IF;

  RAISE NOTICE 'LES 4 PREUVES SONT VERTES.';
END
$preuve$;