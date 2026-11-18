-- Goulag de Sovarka — ordres internes, lot 2/4 : dortoir, cachot, libération, circulation.
-- Décisions de Fred du 17/11/2026 :
--  * Dortoir : « Dormir » +1 PA et une journée de peine purgée ; « Manger » +1 PA, une fois par jour.
--  * Cachot : « Dormir » 0 PA, une journée de peine ET une nuit de sanction (deux nuits au plus).
--  * Le temps qui passe ne réduit jamais la peine ; un sommeil par jour (même marqueur que le repos
--    général pa_repos_le, donc aucune double récupération avec le « Dormir » de la fiche).
--  * Peine achevée par le sommeil : libération automatique devant l'entrée du goulag.
DO $goulag_ordres_prerequis$
BEGIN
  IF to_regclass('public.sovarka_goulag_registre') IS NULL THEN
    RAISE EXCEPTION 'goulag_ordres_lot1_requis'; END IF;
END $goulag_ordres_prerequis$;

-- Placement au cachot : jamais plus de deux nuits, jamais d'addition au-delà.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_cachot_placer_interne(
  p_nom text, p_detention_id text, p_nuits integer, p_motif text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nuits integer;
BEGIN
  IF p_nuits NOT IN (1,2) OR p_nuits IS NULL
     OR p_motif NOT IN ('evasion_echouee','decision_judiciaire') OR p_motif IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','sanction_invalide'); END IF;
  UPDATE public.sovarka_goulag_registre
     SET cachot_nuits = least(2, greatest(cachot_nuits, p_nuits)), cachot_motif = p_motif
   WHERE detention_id = p_detention_id AND nom = p_nom
     AND liberation_le IS NULL AND evasion_le IS NULL
  RETURNING cachot_nuits INTO v_nuits;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','detenu_introuvable'); END IF;
  UPDATE public.personnages_donnees
     SET current_room = 'cachot_disciplinaire', current_street = NULL, updated_at = clock_timestamp()
   WHERE name = p_nom AND country = 'soviet' AND current_city = 'qhs' AND current_building = 'qhs-prison';
  RETURN jsonb_build_object('ok',true,'cachot_nuits',v_nuits);
END $$;

-- Libération régulière : registre, fin de détention (restitution du dépôt par le moteur #1020),
-- puis dépôt devant l'entrée du camp avec une présence enregistrée pour repartir normalement.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_liberer_interne(p_nom text, p_detention_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_peine jsonb; v_ville text; v_clos jsonb; v_n integer;
BEGIN
  SELECT est_emprisonne INTO v_peine FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  SELECT coalesce(nullif(v_peine->>'retourVille',''), d.city) INTO v_ville
    FROM public.detentions d WHERE d.id = p_detention_id;
  UPDATE public.sovarka_goulag_registre SET liberation_le = now()
   WHERE detention_id = p_detention_id AND nom = p_nom AND jours_restants = 0
     AND liberation_le IS NULL AND evasion_le IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN RETURN jsonb_build_object('ok',false,'raison','liberation_non_due'); END IF;
  v_clos := public.detention_clore_interne(p_nom, 'purgee');
  IF EXISTS (SELECT 1 FROM public.detentions WHERE id = p_detention_id AND mode_fin IS NULL) THEN
    RAISE EXCEPTION 'goulag_liberation_non_close'; END IF;
  -- Décision du 17/11 : le libéré se retrouve DEVANT L'ENTRÉE du goulag.
  UPDATE public.personnages_donnees
     SET country = 'soviet', current_city = 'qhs', current_building = 'qhs-prison',
         current_room = 'entree_qhs', current_street = NULL, updated_at = clock_timestamp()
   WHERE name = p_nom;
  IF v_ville IN ('capitale','ville_a','ville_b') THEN
    INSERT INTO public.sovarka_goulag_visites(nom,origine,present,entre_le,sorti_le)
    VALUES (p_nom, v_ville, true, now(), NULL)
    ON CONFLICT (nom) DO UPDATE SET origine = EXCLUDED.origine, present = true,
      entre_le = now(), sorti_le = NULL;
  END IF;
  PERFORM public.mail_systeme_poser_interne('Camp de rééducation de Sovarka', p_nom,
    'Libération', 'Votre peine est purgée. Vous êtes libéré(e) et conduit(e) devant l''entrée du camp.');
  RETURN jsonb_build_object('ok',true,'libere',true,'detention_id',p_detention_id,
    'room','entree_qhs','fin',v_clos);
END $$;

-- « Dormir » au dortoir ou au cachot : un seul sommeil valide par jour de Paris.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_dormir()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        r public.sovarka_goulag_registre%ROWTYPE; v_refus jsonb; v_det text;
        v_jour date := public.sovarka_goulag_jour_interne(); v_lieu text; v_gain integer;
        v_pa integer; v_lib jsonb;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_nom AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND OR (p.country, p.current_city, p.current_building)
     IS DISTINCT FROM ('soviet','qhs','qhs-prison') THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(v_nom);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
  IF p.current_room = 'cellules_qhs' THEN
    IF r.cachot_nuits > 0 THEN
      RETURN jsonb_build_object('ok',false,'raison','sanction_cachot_en_cours','cachot_nuits',r.cachot_nuits); END IF;
    v_lieu := 'dortoir'; v_gain := 1;
  ELSIF p.current_room = 'cachot_disciplinaire' THEN
    IF r.cachot_nuits = 0 THEN
      -- Compteur épuisé : jamais d'enfermement indéfini, retour au dortoir sans consommer de nuit.
      UPDATE public.personnages_donnees SET current_room = 'cellules_qhs', current_street = NULL,
        updated_at = clock_timestamp() WHERE name = v_nom;
      RETURN jsonb_build_object('ok',false,'raison','sanction_terminee','room','cellules_qhs'); END IF;
    v_lieu := 'cachot'; v_gain := 0;
  ELSE
    RETURN jsonb_build_object('ok',false,'raison','pas_de_couchette'); END IF;
  IF (p.pa_repos_le IS NOT NULL AND p.pa_repos_le >= v_jour)
     OR (r.dernier_sommeil IS NOT NULL AND r.dernier_sommeil >= v_jour) THEN
    RETURN jsonb_build_object('ok',false,'raison','deja_dormi_aujourdhui','pa',p.pa); END IF;
  UPDATE public.personnages_donnees
     SET pa = least(30, greatest(0, coalesce(pa,0)) + v_gain), pa_repos_le = v_jour,
         updated_at = clock_timestamp()
   WHERE name = v_nom RETURNING pa INTO v_pa;
  UPDATE public.sovarka_goulag_registre
     SET jours_restants = greatest(0, jours_restants - 1), dernier_sommeil = v_jour,
         cachot_nuits = CASE WHEN v_lieu = 'cachot' THEN greatest(0, cachot_nuits - 1) ELSE cachot_nuits END,
         cachot_motif = CASE WHEN v_lieu = 'cachot' AND cachot_nuits <= 1 THEN NULL ELSE cachot_motif END
   WHERE detention_id = r.detention_id
  RETURNING * INTO r;
  IF r.jours_restants = 0 THEN
    v_lib := public.sovarka_goulag_liberer_interne(v_nom, r.detention_id);
    IF coalesce((v_lib->>'ok')::boolean,false) IS NOT TRUE THEN
      RAISE EXCEPTION 'goulag_liberation_impossible'; END IF;
    RETURN jsonb_build_object('ok',true,'lieu',v_lieu,'gain',v_gain,'pa',v_pa,
      'jours_restants',0,'libere',true,'room','entree_qhs');
  END IF;
  IF v_lieu = 'cachot' AND r.cachot_nuits = 0 THEN
    UPDATE public.personnages_donnees SET current_room = 'cellules_qhs', current_street = NULL,
      updated_at = clock_timestamp() WHERE name = v_nom;
  END IF;
  RETURN jsonb_build_object('ok',true,'lieu',v_lieu,'gain',v_gain,'pa',v_pa,
    'jours_restants',r.jours_restants,'cachot_nuits',r.cachot_nuits,'libere',false,
    'room',CASE WHEN v_lieu = 'cachot' AND r.cachot_nuits > 0 THEN 'cachot_disciplinaire' ELSE 'cellules_qhs' END);
END $$;

-- « Manger » : dortoir uniquement, +1 PA, un repas par jour de Paris (même règle que les repas du jeu).
CREATE OR REPLACE FUNCTION public.sovarka_goulag_manger()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        r public.sovarka_goulag_registre%ROWTYPE; v_refus jsonb; v_det text;
        v_jour date := public.sovarka_goulag_jour_interne(); v_pa integer;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_nom AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND OR (p.country, p.current_city, p.current_building, p.current_room)
     IS DISTINCT FROM ('soviet','qhs','qhs-prison','cellules_qhs') THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_dortoir'); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(v_nom);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
  IF r.cachot_nuits > 0 THEN
    RETURN jsonb_build_object('ok',false,'raison','sanction_cachot_en_cours'); END IF;
  IF r.dernier_repas IS NOT NULL AND r.dernier_repas >= v_jour THEN
    RETURN jsonb_build_object('ok',false,'raison','deja_mange','pa',p.pa); END IF;
  UPDATE public.personnages_donnees SET pa = least(30, greatest(0, coalesce(pa,0)) + 1),
    updated_at = clock_timestamp() WHERE name = v_nom RETURNING pa INTO v_pa;
  UPDATE public.sovarka_goulag_registre SET dernier_repas = v_jour WHERE detention_id = r.detention_id;
  RETURN jsonb_build_object('ok',true,'gain',1,'pa',v_pa);
END $$;

-- Circulation intérieure d'un détenu (le moteur général refuse tout déplacement aux détenus) :
-- dortoir, entrée et mirador seulement ; jamais le bureau ; aucune sortie du cachot pendant
-- la sanction. Ce n'est ni une libération ni un transport.
CREATE OR REPLACE FUNCTION public.sovarka_goulag_detenu_aller(p_piece text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); p public.personnages_donnees%ROWTYPE;
        r public.sovarka_goulag_registre%ROWTYPE; v_refus jsonb; v_det text;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  v_refus := public.sovarka_goulag_ordres_refus_interne();
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;
  IF p_piece NOT IN ('cellules_qhs','entree_qhs','mirador') OR p_piece IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','piece_interdite'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = v_nom AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND OR (p.country, p.current_city, p.current_building)
     IS DISTINCT FROM ('soviet','qhs','qhs-prison') THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_goulag'); END IF;
  v_det := public.sovarka_goulag_detention_registree_interne(v_nom);
  SELECT * INTO r FROM public.sovarka_goulag_registre WHERE detention_id = v_det FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','non_detenu_goulag'); END IF;
  IF r.cachot_nuits > 0 THEN
    RETURN jsonb_build_object('ok',false,'raison','sanction_cachot_en_cours','cachot_nuits',r.cachot_nuits); END IF;
  IF p.current_room NOT IN ('cellules_qhs','entree_qhs','mirador','cachot_disciplinaire') THEN
    RETURN jsonb_build_object('ok',false,'raison','piece_de_depart_interdite'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'qhs'
       AND batiment = 'qhs-prison' AND pieces ? p_piece) THEN
    RETURN jsonb_build_object('ok',false,'raison','piece_non_referencee'); END IF;
  IF p.current_room = p_piece THEN RETURN jsonb_build_object('ok',true,'room',p_piece,'deja',true); END IF;
  UPDATE public.personnages_donnees SET current_room = p_piece, current_street = NULL,
    updated_at = clock_timestamp() WHERE name = v_nom AND user_id = auth.uid();
  RETURN jsonb_build_object('ok',true,'room',p_piece);
END $$;

-- État de détention lu par l'écran (aucune écriture).
CREATE OR REPLACE FUNCTION public.sovarka_goulag_ma_detention()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_nom text := public.mon_personnage(); r public.sovarka_goulag_registre%ROWTYPE;
        v_jour date := public.sovarka_goulag_jour_interne(); v_pa_repos date;
BEGIN
  IF auth.uid() IS NULL OR v_nom IS NULL THEN
    RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
  SELECT * INTO r FROM public.sovarka_goulag_registre
   WHERE detention_id = public.sovarka_goulag_detention_registree_interne(v_nom);
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',true,'detenu',false); END IF;
  SELECT pa_repos_le INTO v_pa_repos FROM public.personnages_donnees WHERE name = v_nom;
  RETURN jsonb_build_object('ok',true,'detenu',true,'jours_restants',r.jours_restants,
    'cachot_nuits',r.cachot_nuits,'cachot_motif',r.cachot_motif,
    'a_dormi',(coalesce(v_pa_repos,'-infinity'::date) >= v_jour OR coalesce(r.dernier_sommeil,'-infinity'::date) >= v_jour),
    'a_mange',coalesce(r.dernier_repas,'-infinity'::date) >= v_jour,
    'tentative_faite',coalesce(r.derniere_tentative,'-infinity'::date) >= v_jour,
    'corruption_bonus',r.corruption_bonus);
END $$;

-- Le repos général (« Dormir » de la fiche) ne s'applique pas au goulag : sinon +12/+3 PA
-- s'ajouteraient au +1/0 du camp. Garde insérée sans retirer aucune autre garde existante.
DO $goulag_repos_dortoir$
DECLARE source text; ancre text; garde text;
BEGIN
  source := pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
  IF strpos(source,'goulag_sommeil_dortoir_20261117') > 0 THEN RETURN; END IF;
  ancre := E'  IF v_deja IS NOT NULL AND v_deja >= v_jour THEN';
  garde := E'  -- goulag_sommeil_dortoir_20261117 : le détenu du goulag dort au dortoir ou au cachot.\n'
    || E'  IF public.sovarka_goulag_detention_registree_interne(p_acteur) IS NOT NULL THEN\n'
    || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''sommeil_goulag_dortoir'', ''pa'', v_pa); END IF;\n'
    || ancre;
  IF (length(source) - length(replace(source, ancre, ''))) <> length(ancre) THEN
    RAISE EXCEPTION 'pa_repos_nocturne_ancre_absente'; END IF;
  EXECUTE replace(source, ancre, garde);
END $goulag_repos_dortoir$;

-- Une peine du goulag ne se purge jamais au calendrier : la libération vient du sommeil.
DO $goulag_purge_calendrier$
DECLARE source text; ancre text; garde text;
BEGIN
  source := pg_get_functiondef('public.detention_clore_purgee()'::regprocedure);
  IF strpos(source,'goulag_peine_au_sommeil_20261117') > 0 THEN RETURN; END IF;
  ancre := E'  SELECT * INTO v_det FROM public.detention_active(v_moi);\n';
  garde := ancre
    || E'  -- goulag_peine_au_sommeil_20261117 : aucun décompte par simple passage du temps.\n'
    || E'  IF EXISTS (SELECT 1 FROM public.sovarka_goulag_registre r WHERE r.detention_id = v_det.id) THEN\n'
    || E'    RETURN jsonb_build_object(''ok'',false,''raison'',''peine_goulag_au_sommeil''); END IF;\n';
  IF (length(source) - length(replace(source, ancre, ''))) <> length(ancre) THEN
    RAISE EXCEPTION 'detention_clore_purgee_ancre_absente'; END IF;
  EXECUTE replace(source, ancre, garde);
END $goulag_purge_calendrier$;

REVOKE ALL ON FUNCTION public.sovarka_goulag_cachot_placer_interne(text,text,integer,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_liberer_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_dormir() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_manger() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_detenu_aller(text) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.sovarka_goulag_ma_detention() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_dormir() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_manger() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_detenu_aller(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_goulag_ma_detention() TO authenticated;
