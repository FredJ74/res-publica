-- APPLIQUEE le 27/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261027094104.
-- Eprouvee apres application en transaction annulee (ramassage d'un objet et d'une pile, lieu refuse, objet deja pris, droits retires). Baseline NON reextrait.
-- ============================================================================
-- TABLES OUVERTES : OBJETS ABANDONNES, VOTES, DONS EN ATTENTE (27 octobre 2026)
-- ============================================================================
-- Audit « une seule verite » §1.1.
--   * OBJETS ABANDONNES : ramasser un objet supprimait la ligne en base puis ajoutait l'objet
--     a l'inventaire SUR L'ECRAN seulement ; la sauvegarde n'ecrivant plus l'inventaire, l'objet
--     disparaissait du monde reel. Et tout joueur pouvait inserer ou supprimer n'importe quelle
--     ligne. objet_abandonne_ramasser fait tout au serveur : meme lieu exige, ligne retiree,
--     objet ajoute a l'inventaire reel, dans une seule transaction. L'abandon passe deja par
--     inventaire_abandonner (serveur). Le navigateur ne peut plus ecrire la table.
--   * VOTES ELECTORAUX et DONS EN ATTENTE : n'importe quel joueur connecte pouvait SUPPRIMER
--     n'importe quelle ligne (un vote, un don destine a un autre). Aucun code du jeu ne le fait :
--     le droit est retire.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.objet_abandonne_ramasser(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; o record; v_objet jsonb; v_inv jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT current_city, current_building, current_room, coalesce(inventory, '[]'::jsonb) AS inv
    INTO d FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  SELECT * INTO o FROM public.objets_abandonnes WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'objet_disparu'); END IF;
  IF o.building_id IS DISTINCT FROM d.current_building OR o.room_id IS DISTINCT FROM d.current_room
     OR (o.city IS NOT NULL AND o.city IS DISTINCT FROM d.current_city) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  BEGIN v_objet := o.data::jsonb; EXCEPTION WHEN others THEN v_objet := NULL; END;
  IF v_objet IS NULL OR jsonb_typeof(v_objet) <> 'object' THEN
    DELETE FROM public.objets_abandonnes WHERE id = p_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_illisible'); END IF;
  v_objet := v_objet - 'id';
  IF coalesce((v_objet ->> 'stackable')::boolean, false) AND (v_objet ->> 'stackKey') IS NOT NULL THEN
    v_inv := public.inventaire_ajouter(d.inv, v_objet ->> 'stackKey', greatest(1, coalesce((v_objet ->> 'qty')::integer, 1)), v_objet ->> 'desc');
  ELSE
    v_inv := d.inv || jsonb_build_array(v_objet);
  END IF;
  DELETE FROM public.objets_abandonnes WHERE id = p_id;
  UPDATE public.personnages_donnees SET inventory = v_inv WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'objet', v_objet, 'inventory', v_inv);
END; $function$;
REVOKE ALL ON FUNCTION public.objet_abandonne_ramasser(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.objet_abandonne_ramasser(text) TO authenticated;

DO $mig$
DECLARE r record;
BEGIN
  FOR r IN SELECT polname, polrelid::regclass::text AS t FROM pg_policy
            WHERE polrelid IN ('public.objets_abandonnes'::regclass, 'public.votes_electoraux'::regclass, 'public.dons_en_attente'::regclass)
              AND ((polrelid = 'public.objets_abandonnes'::regclass AND polcmd IN ('a','d'))
                OR (polrelid = 'public.votes_electoraux'::regclass AND polcmd = 'd')
                OR (polrelid = 'public.dons_en_attente'::regclass AND polcmd = 'd')) LOOP
    EXECUTE format('DROP POLICY %I ON %s', r.polname, r.t);
  END LOOP;
END $mig$;
REVOKE INSERT, UPDATE, DELETE ON public.objets_abandonnes FROM anon, authenticated;
REVOKE DELETE ON public.votes_electoraux FROM anon, authenticated;
REVOKE DELETE ON public.dons_en_attente FROM anon, authenticated;
