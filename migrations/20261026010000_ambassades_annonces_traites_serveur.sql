-- APPLIQUEE le 26/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261025223724.
-- Eprouvee apres application en transaction annulee (reception, mecenat, accord, traites lus, 3 annonces). Baseline NON reextrait.
-- ============================================================================
-- AMBASSADES : ANNONCES PUBLIQUES ET TRAITES TENUS PAR LE SERVEUR (26 octobre 2026, nuit)
-- ============================================================================
-- Audit « une seule verite » (AUDIT_UNE_SEULE_VERITE.md) et AUDIT_AMBASSADES.md R2, R10.
-- R10 : l'annonce publique d'une reception, d'un mecenat ou d'un accord diplomatique etait ecrite
--       par le navigateur, apres un effet que le serveur n'avait pas constate. Desormais la
--       fonction du serveur qui fait l'action ecrit aussi l'annonce, dans la meme transaction.
-- R2  : « Relations bilaterales » affichait les traites gardes dans l'etat personnel du lecteur.
--       diplomatie_traites_lire rend les traites reellement acceptes entre les deux pays.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.annonce_publique_interne(p_pays text, p_texte text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (p_pays, NULL, p_texte, public.jour_de_jeu_pays(CASE WHEN p_pays = 'global' THEN 'republic' ELSE p_pays END));
$function$;
REVOKE ALL ON FUNCTION public.annonce_publique_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.empire_nom_interne(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p WHEN 'republic' THEN 'Républia' WHEN 'narco' THEN 'El Estado'
                WHEN 'soviet' THEN 'Sovarka' WHEN 'khalija' THEN 'Al-Khalija' ELSE p END;
$function$;

-- Reception : annonce dans le pays hote.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN jsonb_build_object(''ok'', true, ''invites'', v_invites,';
  v_ajout text := E'  PERFORM public.annonce_publique_interne(v_hote, CASE WHEN v_invites = 0\n    THEN ''DIPLOMATIE : la réception de l''''ambassade de '' || public.empire_nom_interne(p_empire) || '' s''''est tenue devant une salle vide.''\n    ELSE ''DIPLOMATIE : réception donnée à l''''ambassade de '' || public.empire_nom_interne(p_empire) || '' ('' || v_invites || '' invité'' || CASE WHEN v_invites > 1 THEN ''s'' ELSE '''' END || '').'' END);\n';
BEGIN
  v_def := pg_get_functiondef('public.ambassade_reception_organiser(text)'::regprocedure);
  IF position('annonce_publique_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout || v_frag);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : ambassade_reception_organiser'; END IF;
  EXECUTE v_new;
END $mig$;

-- Mecenat : annonce dans le pays hote.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'  RETURN jsonb_build_object(''ok'', true, ''indice'', v_indice, ''pop'', v_pop -> ''pop'', ''paie'', v_paie);';
  v_ajout text := E'  PERFORM public.annonce_publique_interne(m ->> ''hote'', ''SOFT POWER : '' || public.empire_nom_interne(p_empire) || '' finance une œuvre culturelle.'');\n';
BEGIN
  v_def := pg_get_functiondef('public.ambassade_mecenat(text)'::regprocedure);
  IF position('annonce_publique_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_ajout || v_frag);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : ambassade_mecenat'; END IF;
  EXECUTE v_new;
END $mig$;

-- Accord diplomatique accepte : annonce mondiale ; traite date du jour.
DO $mig$
DECLARE v_def text; v_new text;
  v_frag text := E'    PERFORM public.indice_diplomatique_varier_interne(v_pays, v_gain, ''accord_'' || coalesce(v_type, ''?''), v_moi);';
  v_ajout text := E'\n    PERFORM public.annonce_publique_interne(''global'', CASE WHEN v_type = ''traite'' THEN ''TRAITÉ'' ELSE ''NÉGOCIATIONS DIPLOMATIQUES'' END\n      || '' : accord conclu entre '' || public.empire_nom_interne(r.data ->> ''empireProposeur'') || '' et '' || public.empire_nom_interne(v_pays) || ''.'');';
BEGIN
  v_def := pg_get_functiondef('public.diplomatie_repondre(text,boolean)'::regprocedure);
  IF position('annonce_publique_interne' in v_def) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_frag, v_frag || v_ajout);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch non applique : diplomatie_repondre'; END IF;
  EXECUTE v_new;
END $mig$;

-- Traites en vigueur entre le pays du lecteur et un empire.
CREATE OR REPLACE FUNCTION public.diplomatie_traites_lire(p_empire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'traites', coalesce((
    SELECT jsonb_agg(jsonb_build_object('type', p.data ->> 'details', 'le', coalesce(p.data ->> 'reponduLe', p.created_at::text))
                     ORDER BY p.created_at)
      FROM public.propositions_diplomatiques p
     WHERE p.statut = 'acceptee' AND p.data ->> 'type' = 'traite'
       AND ((p.data ->> 'empireProposeur' = v_pays AND p.data ->> 'empireCible' = p_empire)
         OR (p.data ->> 'empireProposeur' = p_empire AND p.data ->> 'empireCible' = v_pays))), '[]'::jsonb));
END; $function$;
REVOKE ALL ON FUNCTION public.diplomatie_traites_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.diplomatie_traites_lire(text) TO authenticated;
