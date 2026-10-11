-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011145030 (UTC), nom `assemblee_seance_horloge_reelle`.
-- Le registre passe de 654 a 655 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 a72cf66d649444f61894cfdfd95d81ce, 13273 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE FILE S'ORDONNE SUR L'HORLOGE, PAS SUR LA TRANSACTION
--
-- CE QUE LE BANC A MONTRE. `now()` rend l'heure de DEBUT DE TRANSACTION, identique pour tout ce
-- qui se passe dedans. Trois demandes de parole posees dans la meme transaction portaient donc le
-- MEME horodatage a la microseconde : la file n'avait plus d'ordre, et la regle « le President
-- donne la parole au PREMIER » devenait indemontrable.
-- ET CE N'EST PAS QU'UN ARTEFACT DE BANC : `assemblee_protester` inscrit la sortie PUIS recalcule
-- la suspension. Si un episode se fermait dans cette meme transaction, `close_le` valait
-- exactement `sorti_le`, et le test de dissolution complete -- « reste-t-il un protestataire sorti
-- AVANT la fermeture ? » -- ne pouvait pas trancher.
-- `clock_timestamp()` pour les SIX horodatages d'ORDRE. Les dates metier -- `updated_at` d'une
-- proposition, l'echeance d'un scrutin -- restent sur `now()` : elles appartiennent a la
-- transaction et doivent etre identiques pour tout ce qu'elle ecrit.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- UNE FILE S'ORDONNE SUR L'HORLOGE, PAS SUR LA TRANSACTION (11 octobre 2026)
-- =================================================================================================
-- CE QUE LE BANC A MONTRE. `now()` rend l'heure de DEBUT DE TRANSACTION, identique pour tout ce qui
-- se passe dedans. Trois demandes de parole posees dans la meme transaction portaient donc le MEME
-- horodatage a la microseconde : la file n'avait plus d'ordre, et la regle « le President donne la
-- parole au PREMIER » devenait indemontrable.
--
-- ET CE N'EST PAS QU'UN ARTEFACT DE BANC. En seance, chaque demande est bien une transaction
-- distincte -- mais deux endroits ont besoin d'instants reels A L'INTERIEUR d'une meme
-- transaction :
--   . `assemblee_protester` inscrit la sortie PUIS recalcule la suspension. Si un episode se
--     ferme dans cette meme transaction, `close_le` valait exactement `sorti_le`, et le test de
--     dissolution complete -- « reste-t-il un protestataire sorti AVANT la fermeture ? » -- ne
--     pouvait pas trancher ;
--   . deux demandes concurrentes dont les transactions commencent a la meme microseconde se
--     departageaient par le nom du depute, et non par qui a leve la main le premier.
--
-- `clock_timestamp()` rend l'heure REELLE a l'instant de l'appel. C'est ce qu'il faut pour un
-- horodatage d'ORDRE. Les dates metier -- `updated_at` d'une proposition, l'echeance d'un scrutin --
-- restent sur `now()` : elles appartiennent a la transaction, et doivent etre identiques pour tout
-- ce qu'elle ecrit.
-- =================================================================================================

ALTER TABLE public.assemblee_paroles       ALTER COLUMN demande_le SET DEFAULT clock_timestamp();
ALTER TABLE public.assemblee_debats        ALTER COLUMN dit_le     SET DEFAULT clock_timestamp();
ALTER TABLE public.assemblee_disciplines   ALTER COLUMN fait_le    SET DEFAULT clock_timestamp();
ALTER TABLE public.assemblee_protestations ALTER COLUMN sorti_le   SET DEFAULT clock_timestamp();
ALTER TABLE public.assemblee_suspensions   ALTER COLUMN ouverte_le SET DEFAULT clock_timestamp();
ALTER TABLE public.assemblee_reports       ALTER COLUMN fait_le    SET DEFAULT clock_timestamp();

COMMENT ON COLUMN public.assemblee_paroles.demande_le IS
  'L instant REEL de la demande (clock_timestamp, pas now()). C est lui qui donne son ordre a la file, et le President doit donner la parole au premier : un horodatage de transaction rendrait cet ordre indeterminable entre deux demandes simultanees.';

-- -------------------------------------------------------------------------------------------------
-- LES TROIS PORTES QUI HORODATAIENT ELLES-MEMES
-- -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_parole_donner(p_depute text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_premier text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  -- LE VERROU EST PRIS SUR LA FILE ENTIERE : deux « donner la parole » concurrents ne peuvent pas
  -- lire le meme premier et produire deux orateurs.
  PERFORM 1 FROM public.assemblee_paroles WHERE pays = v_pays FOR UPDATE;
  SELECT depute INTO v_premier FROM public.assemblee_paroles
   WHERE pays = v_pays AND NOT a_la_parole ORDER BY demande_le, depute LIMIT 1;
  IF v_premier IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'file_vide'); END IF;
  IF p_depute IS NOT NULL AND p_depute <> v_premier THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_premier_de_la_file',
                              'premier', v_premier);
  END IF;
  IF EXISTS (SELECT 1 FROM public.assemblee_paroles WHERE pays = v_pays AND a_la_parole) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'un_orateur_a_deja_la_parole'); END IF;

  UPDATE public.assemblee_paroles SET a_la_parole = true, donnee_le = clock_timestamp()
   WHERE pays = v_pays AND depute = v_premier;
  RETURN jsonb_build_object('ok', true, 'orateur', v_premier);
END;
$function$;

CREATE OR REPLACE FUNCTION public.assemblee_recalculer_suspension(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  SEUIL constant integer := 5;
  v_qualifies integer; v_dehors integer; v_ouvert text; v_id text; v_pres text;
BEGIN
  SELECT count(*) FILTER (WHERE qualifie), count(*)
    INTO v_qualifies, v_dehors
    FROM public.assemblee_protestations WHERE pays = p_pays;

  SELECT id INTO v_ouvert FROM public.assemblee_suspensions
   WHERE pays = p_pays AND cause = 'boycott' AND close_le IS NULL FOR UPDATE;

  IF v_ouvert IS NOT NULL AND v_qualifies < SEUIL THEN
    -- clock_timestamp() et non now() : la fermeture doit etre POSTERIEURE aux sorties inscrites
    -- dans la meme transaction, sinon le test de dissolution complete ci-dessous ne tranche plus.
    UPDATE public.assemblee_suspensions SET close_le = clock_timestamp() WHERE id = v_ouvert;
    v_ouvert := NULL;
  ELSIF v_ouvert IS NULL AND v_qualifies >= SEUIL THEN
    -- DISSOLUTION COMPLETE EXIGEE : s'il reste un protestataire qualifie depuis l'episode
    -- precedent, on est dans le MEME boycott et on ne l'ouvre pas une seconde fois. Sans cette
    -- regle, un seul depute faisant hall -> hemicycle -> hall fabriquerait des episodes a volonte.
    IF EXISTS (SELECT 1 FROM public.assemblee_suspensions s
                WHERE s.pays = p_pays AND s.cause = 'boycott' AND s.close_le IS NOT NULL
                  AND EXISTS (SELECT 1 FROM public.assemblee_protestations p
                               WHERE p.pays = p_pays AND p.qualifie
                                 AND p.sorti_le < s.close_le)) THEN
      NULL;   -- meme boycott : aucun episode neuf
    ELSE
      v_pres := public.assemblee_president(p_pays);
      v_id := 'suspension-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS');
      INSERT INTO public.assemblee_suspensions (id, pays, cause, president, protestataires)
      VALUES (v_id, p_pays, 'boycott', v_pres,
              (SELECT coalesce(jsonb_agg(depute ORDER BY depute), '[]'::jsonb)
                 FROM public.assemblee_protestations
                WHERE pays = p_pays AND qualifie));
      v_ouvert := v_id;
    END IF;
  END IF;

  RETURN jsonb_build_object('suspendue', v_ouvert IS NOT NULL, 'episode', v_ouvert,
                            'qualifies', v_qualifies, 'dehors', v_dehors, 'seuil', SEUIL);
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_recalculer_suspension(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_recalculer_suspension(text) FROM anon;
REVOKE ALL ON FUNCTION public.assemblee_recalculer_suspension(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_recalculer_suspension(text) TO service_role;

CREATE OR REPLACE FUNCTION public.assemblee_suspendre_seance(p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SUSPENSION constant integer := -20;
  v_moi text; v_pays text; v_id text; v_m text; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_suspensions WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'suspension', d.id, 'pop', POP_SUSPENSION,
                              'compte_pour_le_boycott', false);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  -- LE MOTIF EST CONSERVE S'IL EST DONNE, ET N'EST NI EXIGE NI JUGE : l'arbitrage ne le rend pas
  -- obligatoire pour cette prerogative, contrairement au rappel et a la sanction.
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  v_id := 'suspension-pres-' || left(md5(p_requete), 20);

  -- IL SE PAIE LUI-MEME, et le registre des causes le verifie : `assemblee_suspension_seance`
  -- refuse toute cible autre que l'acteur. Un refus ici annule tout : pas de suspension gratuite.
  v_pop := public.personnage_ajuster_pop_inf(v_moi, v_moi, POP_SUSPENSION, NULL, 'assemblee_suspension_seance');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_suspension_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  INSERT INTO public.assemblee_suspensions (id, pays, cause, president, motif, close_le, requete)
  VALUES (v_id, v_pays, 'presidence', v_moi, v_m, clock_timestamp(), p_requete);

  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'pop', POP_SUSPENSION,
                            'compte_pour_le_boycott', false, 'pop_president', v_pop -> 'pop');
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_suspendre_seance(text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_suspendre_seance(text,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_suspendre_seance(text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_suspendre_seance(text,text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer; v_t1 timestamptz; v_t2 timestamptz;
BEGIN
  -- P1 : LES SIX HORODATAGES D'ORDRE SONT SUR L'HORLOGE REELLE.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public' AND column_default = 'clock_timestamp()'
     AND (table_name, column_name) IN (
       ('assemblee_paroles','demande_le'), ('assemblee_debats','dit_le'),
       ('assemblee_disciplines','fait_le'), ('assemblee_protestations','sorti_le'),
       ('assemblee_suspensions','ouverte_le'), ('assemblee_reports','fait_le'));
  IF v_n <> 6 THEN
    RAISE EXCEPTION 'P1 : % horodatage(s) d ordre sur 6 utilisent l horloge reelle', v_n;
  END IF;

  -- P2 : ET ELLE AVANCE VRAIMENT DANS UNE TRANSACTION. Preuve directe, pas une lecture de code :
  -- c'est exactement ce que now() ne faisait pas, et ce qui rendait la file inordonnable.
  v_t1 := clock_timestamp();
  PERFORM count(*) FROM generate_series(1, 20000);
  v_t2 := clock_timestamp();
  IF v_t2 <= v_t1 THEN
    RAISE EXCEPTION 'P2 : l horloge n avance pas dans une transaction';
  END IF;
  IF now() <> now() THEN
    RAISE EXCEPTION 'P2b : now() n est plus constant dans une transaction';
  END IF;

  -- P3 : LES TROIS PORTES QUI HORODATENT ELLES-MEMES N'APPELLENT PLUS now(). La fermeture d'un
  -- episode doit etre posterieure aux sorties inscrites dans la meme transaction.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_parole_donner','assemblee_recalculer_suspension',
                       'assemblee_suspendre_seance')
     AND p.prosrc LIKE '%clock_timestamp()%'
     AND p.prosrc NOT LIKE '%= now()%';
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'P3 : % porte(s) sur 3 horodatent sur l horloge reelle', v_n;
  END IF;

  -- P4 : LE RECALCUL DU SEUIL RESTE FERME AUX CLIENTS. On vient de le remplacer : un CREATE OR
  -- REPLACE conserve les droits, mais on verifie plutot que d'esperer.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_recalculer_suspension'
     AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
     AND has_function_privilege('service_role', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 : le recalcul du seuil est ouvert aux clients'; END IF;

  -- P5 : LA REGLE DE DISSOLUTION COMPLETE EST TOUJOURS LA. C'est elle qui empeche un depute de
  -- fabriquer plusieurs episodes en faisant hall -> hemicycle -> hall.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_recalculer_suspension'
     AND p.prosrc LIKE '%p.sorti_le < s.close_le%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 : la regle de dissolution complete a disparu'; END IF;

  RAISE NOTICE 'Horloge reelle de la seance : les 5 preuves structurelles passent.';
END $$;
