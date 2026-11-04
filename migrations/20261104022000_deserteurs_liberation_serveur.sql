-- LIBERATION DES DESERTEURS : DECIDEE ET APPLIQUEE PAR LE SERVEUR (04/11/2026, Claude).
--
-- Vérification demandée par Fred (relais du 03/11, point « motifDesertionSeul ») :
--   1. 20261103140000 a fait reconnaître au serveur la détention « pour seule désertion » à ses
--      motifs, mais l'écran ne l'appelait toujours que si `est_emprisonne.motifDesertionSeul` était
--      vrai — drapeau que personne ne pose : aucun déserteur détenu n'était jamais libéré.
--   2. La démobilisation éteignait les poursuites… du seul Ministre de la Défense qui cliquait
--      (eteindrePoursuitesDesertion travaillait sur l'état de SON écran). Les déserteurs, eux,
--      restaient recherchés, détenus et marqués « déserteur ».
--   3. La porte detention_clore_motif_eteint ne vérifiait ni la mobilisation ni la réquisition :
--      un détenu pour seule désertion pouvait se libérer à tout moment.
--   4. L'incorporation différée (« d'autres peines restent à purger ») n'était qu'un drapeau de
--      l'écran (`incorporationAcceptee`), lu par personne.
--
-- Règles existantes (plateau-politique.js, 13/09 et 16/09/2026), désormais tenues par le serveur :
--   * démobilisation : pour chaque PJ du pays, motif « desertion » de ce pays retiré des avis de
--     recherche, réquisition « deserteur » passée à « eteinte », et détention close
--     (`poursuites_eteintes`) si elle ne tenait qu'à la désertion, avec le courrier de la Caserne ;
--   * incorporation (mobilisation en cours, détenu déserteur) : si la détention ne tient qu'à la
--     désertion, elle est close et le PJ conduit au corps de garde ; sinon l'incorporation est
--     actée et prend effet à la libération (fin de peine, grâce, jugement), jamais à une évasion ;
--   * extinction des poursuites par la porte du détenu : seulement si la mobilisation est levée.

DO $prevol$
DECLARE d text;
BEGIN
  d := pg_get_functiondef('public.detention_clore_motif_eteint(text)'::regprocedure);
  IF position('deserteur_seul_par_motifs_v1' IN d) = 0 OR position('incorporation_caserne_serveur_v1' IN d) = 0 THEN
    RAISE EXCEPTION 'deserteurs : detention_clore_motif_eteint n''a pas le corps attendu (20261103140000)'; END IF;
  d := pg_get_functiondef('public.militaire_mobilisation_fixer(boolean)'::regprocedure);
  IF position('ECRITURE CHIRURGICALE' IN d) = 0 THEN
    RAISE EXCEPTION 'deserteurs : militaire_mobilisation_fixer n''a pas le corps attendu'; END IF;
  IF to_regprocedure('public.detention_clore_interne(text,text,integer)') IS NULL
     OR to_regprocedure('public.mail_systeme_poser_interne(text,text,text,text,text)') IS NULL THEN
    RAISE EXCEPTION 'deserteurs : socle de détention ou de courrier absent'; END IF;
END $prevol$;

-- ── 1. Une détention ne tient-elle qu'à la désertion ? ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.detention_desertion_seule_interne(p_nom text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT (est_emprisonne->>'motifDesertionSeul')::boolean FROM public.personnages_donnees
                    WHERE name = p_nom AND jsonb_typeof(est_emprisonne) = 'object'), false)
      OR EXISTS (SELECT 1 FROM public.detentions t
                  WHERE t.id = (SELECT a.id FROM public.detention_active(p_nom) a)
                    AND jsonb_typeof(t.motifs) = 'array' AND jsonb_array_length(t.motifs) > 0
                    AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(t.motifs) m
                                     WHERE coalesce(m->>'acte', m->>'type') IS DISTINCT FROM 'desertion'));
$function$;

-- ── 2. Extinction nationale des poursuites pour désertion ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.deserteurs_eteindre_poursuites_interne(p_pays text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p record; v_rech jsonb; v_req jsonb; v_liberes text[] := '{}'; v_eteints integer := 0;
BEGIN
  FOR p IN
    SELECT name, recherche, requisition, est_emprisonne FROM public.personnages_donnees
     WHERE coalesce(country, 'republic') = p_pays
       AND ( coalesce(requisition->>'statut', '') = 'deserteur'
          OR (requisition ? 'incorporationDifferee')
          OR (jsonb_typeof(recherche) = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements(recherche) e
                WHERE e->>'acte' = 'desertion' AND coalesce(nullif(e->>'country', ''), p_pays) = p_pays))
          OR EXISTS (SELECT 1 FROM public.detention_active(name)) )
     ORDER BY name FOR UPDATE
  LOOP
    -- Même filtre que recherche_retirer : l'acte et le pays, aucun autre motif touché.
    IF jsonb_typeof(p.recherche) = 'array' THEN
      SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_rech FROM jsonb_array_elements(p.recherche) e
       WHERE NOT (e->>'acte' = 'desertion' AND coalesce(nullif(e->>'country', ''), p_pays) = p_pays);
      IF v_rech IS DISTINCT FROM p.recherche THEN
        PERFORM set_config('rp.recherche_interne', 'on', true);
        UPDATE public.personnages_donnees SET recherche = v_rech WHERE name = p.name;
        PERFORM set_config('rp.recherche_interne', '', true);
      END IF;
    END IF;
    v_req := p.requisition;
    IF jsonb_typeof(v_req) = 'object' AND (v_req->>'statut' = 'deserteur' OR v_req ? 'incorporationDifferee') THEN
      v_req := (v_req - 'incorporationDifferee')
               || CASE WHEN v_req->>'statut' = 'deserteur' THEN '{"statut":"eteinte"}'::jsonb ELSE '{}'::jsonb END;
      UPDATE public.personnages_donnees SET requisition = v_req WHERE name = p.name;
      v_eteints := v_eteints + 1;
    END IF;
    IF EXISTS (SELECT 1 FROM public.detention_active(p.name)) AND public.detention_desertion_seule_interne(p.name) THEN
      PERFORM public.detention_clore_interne(p.name, 'poursuites_eteintes');
      PERFORM public.mail_systeme_poser_interne('Caserne', p.name, 'Poursuites éteintes',
        'La démobilisation met fin aux poursuites pour désertion. Vous êtes libéré(e).');
      v_liberes := v_liberes || p.name;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('liberes', to_jsonb(v_liberes), 'requisitions_eteintes', v_eteints);
END;
$function$;

-- ── 3. La démobilisation éteint les poursuites de TOUS les déserteurs du pays ──────────────
CREATE OR REPLACE FUNCTION public.militaire_mobilisation_fixer(p_actif boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_ext jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- AUTORITE. exiger_poste leve si le poste n'est pas atteste : on ne se contente pas de lire
  -- poste->>'id' sur la fiche, qui est ce que le navigateur affiche.
  PERFORM public.exiger_poste('min_def');

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- ECRITURE CHIRURGICALE : une seule cle, sous verrou, sans relire ni reecrire le reste du blob.
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{mobilisationNationaleActive}',
                          to_jsonb(coalesce(p_actif, false)), true),
         updated_at = now()
   WHERE id = v_pays;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'budget_introuvable', 'pays', v_pays);
  END IF;

  -- demobilisation_deserteurs_v1 : l'extinction vaut pour tout le pays, pas pour le ministre.
  IF NOT coalesce(p_actif, false) THEN
    v_ext := public.deserteurs_eteindre_poursuites_interne(v_pays);
  END IF;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'actif', coalesce(p_actif, false),
                            'extinction', v_ext);
END;
$function$;

-- ── 4. La porte du détenu : règles de mobilisation et incorporation différée ───────────────
CREATE OR REPLACE FUNCTION public.detention_clore_motif_eteint(p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_peine jsonb; v_r jsonb; v_pays text; v_req jsonb; v_mobil boolean;
BEGIN
  -- LISTE FERMEE : la porte ne sert que ces deux actes administratifs.
  IF p_mode NOT IN ('poursuites_eteintes','incorporation') THEN
    RAISE EXCEPTION 'detention_clore_motif_eteint : mode inconnu « % »', p_mode;
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT est_emprisonne, coalesce(country, 'republic'), requisition INTO v_peine, v_pays, v_req
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_peine IS NULL OR jsonb_typeof(v_peine) <> 'object' THEN
    RETURN jsonb_build_object('ok',false,'raison','non_detenu'); END IF;
  -- deserteurs_regles_mobilisation_v1
  v_mobil := coalesce((SELECT (b.data->>'mobilisationNationaleActive')::boolean
                         FROM public.budgets_nationaux b WHERE b.id = v_pays), false);
  IF p_mode = 'poursuites_eteintes' AND v_mobil THEN
    RETURN jsonb_build_object('ok',false,'raison','mobilisation_en_cours'); END IF;
  IF p_mode = 'incorporation' THEN
    IF NOT v_mobil THEN RETURN jsonb_build_object('ok',false,'raison','mobilisation_levee'); END IF;
    IF coalesce(v_req->>'statut', '') NOT IN ('deserteur', 'incorpore') THEN
      RETURN jsonb_build_object('ok',false,'raison','pas_deserteur'); END IF;
  END IF;
  -- deserteur_seul_par_motifs_v1 : la détention ne tient qu'à la désertion si tous ses motifs en relèvent.
  IF NOT public.detention_desertion_seule_interne(v_moi) THEN
    IF p_mode = 'incorporation' THEN
      -- incorporation_differee_v1 : actée maintenant, effective à la libération (detention_clore_interne).
      UPDATE public.personnages_donnees
         SET requisition = coalesce(v_req, '{}'::jsonb) || '{"statut":"incorpore","incorporationDifferee":true}'::jsonb
       WHERE name = v_moi;
      RETURN jsonb_build_object('ok', true, 'mode', p_mode, 'differee', true);
    END IF;
    RETURN jsonb_build_object('ok',false,'raison','peine_pas_seulement_desertion');
  END IF;
  v_r := public.detention_clore_interne(v_moi, p_mode);
  -- incorporation_caserne_serveur_v1 : la caserne est une zone déclarée de la navigation.
  IF p_mode = 'incorporation' THEN
    IF NOT EXISTS(SELECT 1 FROM public.navigation_lieux_regles n JOIN public.personnages_donnees d
        ON d.name = v_moi AND n.pays = d.country WHERE n.ville = 'caserne'
        AND n.batiment = 'caserne-militaire' AND n.pieces ? 'corps_garde') THEN
      RAISE EXCEPTION 'caserne_non_referencee'; END IF;
    UPDATE public.personnages_donnees SET current_city = 'caserne', current_building = 'caserne-militaire',
           current_room = 'corps_garde', current_street = NULL,
           requisition = (coalesce(requisition, '{}'::jsonb) - 'incorporationDifferee') || '{"statut":"incorpore"}'::jsonb,
           updated_at = clock_timestamp() WHERE name = v_moi;
  ELSE
    UPDATE public.personnages_donnees
       SET requisition = CASE WHEN requisition->>'statut' = 'deserteur'
                              THEN requisition || '{"statut":"eteinte"}'::jsonb ELSE requisition END
     WHERE name = v_moi AND jsonb_typeof(requisition) = 'object';
  END IF;
  RETURN v_r || jsonb_build_object('ok', true, 'mode', p_mode, 'differee', false);
END; $function$;

-- ── 5. L'incorporation différée prend effet à la libération ───────────────────────────────
DO $patch$
DECLARE d text;
  a_decl text := 'DECLARE v_jour integer; v_peine jsonb; v_det record; v_qhs boolean; v_bat text; v_piece text;';
  a_qhs  text := E'  -- 4. Le registre du QHS, sans quoi le Ministere voit un detenu libre.\n';
  bloc   text := E'  -- incorporation_differee_v1 : un déserteur qui a accepté l''incorporation est conduit à la\n'
              || E'  -- caserne à sa libération (pas à une évasion), si la mobilisation dure encore.\n'
              || E'  IF p_mode NOT IN (''evasion'', ''incorporation'', ''poursuites_eteintes'') THEN\n'
              || E'    SELECT requisition, coalesce(country, ''republic'') INTO v_req, v_pays_inc\n'
              || E'      FROM public.personnages_donnees WHERE name = p_nom;\n'
              || E'    IF coalesce((v_req->>''incorporationDifferee'')::boolean, false) THEN\n'
              || E'      UPDATE public.personnages_donnees SET requisition = v_req - ''incorporationDifferee'' WHERE name = p_nom;\n'
              || E'      IF coalesce((SELECT (b.data->>''mobilisationNationaleActive'')::boolean FROM public.budgets_nationaux b\n'
              || E'                    WHERE b.id = v_pays_inc), false)\n'
              || E'         AND EXISTS (SELECT 1 FROM public.navigation_lieux_regles n WHERE n.pays = v_pays_inc\n'
              || E'                      AND n.ville = ''caserne'' AND n.batiment = ''caserne-militaire'' AND n.pieces ? ''corps_garde'') THEN\n'
              || E'        UPDATE public.personnages_donnees SET current_city = ''caserne'', current_building = ''caserne-militaire'',\n'
              || E'               current_room = ''corps_garde'', current_street = NULL, updated_at = clock_timestamp()\n'
              || E'         WHERE name = p_nom;\n'
              || E'        PERFORM public.mail_systeme_poser_interne(''Caserne'', p_nom, ''Incorporation'',\n'
              || E'          ''Votre peine est terminée : comme vous l''''aviez accepté, vous êtes conduit(e) à la caserne et incorporé(e).'');\n'
              || E'      END IF;\n'
              || E'    END IF;\n'
              || E'  END IF;\n';
BEGIN
  d := pg_get_functiondef('public.detention_clore_interne(text,text,integer)'::regprocedure);
  IF position('incorporation_differee_v1' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, a_decl, ''))) / length(a_decl) <> 1
     OR (length(d) - length(replace(d, a_qhs, ''))) / length(a_qhs) <> 1 THEN
    RAISE EXCEPTION 'detention_clore_interne : ancre absente ou multiple'; END IF;
  d := replace(d, a_decl, a_decl || ' v_req jsonb; v_pays_inc text;');
  d := replace(d, a_qhs, bloc || a_qhs);
  EXECUTE d;
END $patch$;

REVOKE ALL ON FUNCTION public.detention_desertion_seule_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.deserteurs_eteindre_poursuites_interne(text) FROM PUBLIC, anon, authenticated;
NOTIFY pgrst, 'reload schema';
