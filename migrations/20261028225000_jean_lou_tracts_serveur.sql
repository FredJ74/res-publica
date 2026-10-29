-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registre Supabase 20261028213307.
-- Eprouvee au role authenticated en transaction annulee : 3 tracts -> 3 PNJ (2 convaincus, 2 voix),
-- quete en « tracts_termines », rejeu sans second retrait, 4e tentative refusee ; avec 210800
-- (essai annule) : voix « jean_lou » directe refusee, voix par la mission acceptee.
-- ============================================================================
-- MISSION JEAN-LOU : TRACT, JET ET VOIX PAR LE SERVEUR (28 octobre 2026, Claude)
-- ============================================================================
-- distribuerTractJeanLou faisait tout a l'ecran : retrait du tract de mission, jet (50 % + INF/10,
-- plafond 80 %), progression de la quete, et enregistrement de la voix du PNJ par
-- elections_voix_pnj_enregistrer, canal « jean_lou » -- canal qu'un joueur pouvait d'ailleurs
-- appeler seul, sans jet ni tract, pour s'ajouter des voix. jean_lou_tract_distribuer fait tout
-- dans une transaction, avec les memes regles. Le canal « jean_lou » sera reserve au serveur apres
-- la livraison (20261028210800) ; le canal « conference » releve du chantier des elections.
-- Idempotente. Aucun acte de joueur.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.jean_lou_tract_distribuer(p_requete uuid, p_pnj text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; qc jsonb; params jsonb; v jsonb; el jsonb; v_cycle text; v_pos integer;
  v_taux integer; v_roll integer; v_conv boolean; r jsonb; v_cibles jsonb; v_inf numeric;
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_pnj), '') = '' OR length(p_pnj) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  params := jsonb_build_object('pnj', p_pnj);
  v := public.inventaire_action_rejouer_interne(a.name, p_requete, 'jean_lou', params);
  IF v IS NOT NULL THEN RETURN v || jsonb_build_object('quete_carriere', a.quete_carriere); END IF;
  qc := CASE WHEN jsonb_typeof(a.quete_carriere) = 'object' THEN a.quete_carriere ELSE '{}'::jsonb END;
  IF qc ->> 'ambition' IS DISTINCT FROM 'politique' OR qc ->> 'etape' IS DISTINCT FROM 'tracts_recus' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etape_non_conforme'); END IF;
  v_cibles := CASE WHEN jsonb_typeof(qc -> 'ciblesJeanLou') = 'array' THEN qc -> 'ciblesJeanLou' ELSE '[]'::jsonb END;
  IF v_cibles ? p_pnj THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_tente'); END IF;
  -- L'election : celle retenue par la quete, sinon le premier scrutin ou le joueur est candidat.
  el := CASE WHEN jsonb_typeof(qc -> 'electionCible') = 'object' THEN qc -> 'electionCible' END;
  IF el IS NOT NULL THEN
    SELECT id INTO v_cycle FROM public.cycles_electoraux
     WHERE id IN (coalesce(el ->> 'country', a.country) || '_' || (el ->> 'posteId') || '_' || coalesce(el ->> 'city', ''),
                  coalesce(el ->> 'country', a.country) || '_' || (el ->> 'posteId'))
     ORDER BY length(id) DESC LIMIT 1;
  ELSE
    SELECT id, jsonb_build_object('posteId', coalesce(poste_id, data::jsonb ->> 'posteId'), 'city', coalesce(city, data::jsonb ->> 'city'), 'country', country)
      INTO v_cycle, el
      FROM public.cycles_electoraux
     WHERE country = a.country AND data::jsonb -> 'candidats' @> jsonb_build_array(jsonb_build_object('nom', a.name))
     ORDER BY id LIMIT 1;
  END IF;
  IF v_cycle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_candidat'); END IF;
  SELECT (o - 1)::integer INTO v_pos FROM jsonb_array_elements(CASE WHEN jsonb_typeof(a.inventory) = 'array' THEN a.inventory ELSE '[]'::jsonb END)
    WITH ORDINALITY x(e, o)
   WHERE e ->> 'type' = 'tract' AND e ->> 'origineQuete' = 'jean_lou'
     AND jsonb_typeof(e -> 'quantite') = 'number' AND (e ->> 'quantite')::numeric >= 1 ORDER BY o LIMIT 1;
  IF v_pos IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'tract_absent'); END IF;
  UPDATE public.personnages_donnees
     SET inventory = CASE WHEN (inventory -> v_pos ->> 'quantite')::numeric <= 1 THEN inventory - v_pos
                          ELSE jsonb_set(inventory, ARRAY[v_pos::text, 'quantite'], to_jsonb((inventory -> v_pos ->> 'quantite')::numeric - 1)) END
   WHERE name = a.name;
  v_inf := coalesce(CASE WHEN jsonb_typeof(a.resources -> 'inf') = 'number' THEN (a.resources ->> 'inf')::numeric END, 0);
  v_taux := least(80, 50 + floor(v_inf / 10)::integer);
  v_roll := floor(random() * 100)::integer + 1;
  v_conv := v_roll <= v_taux;
  IF v_conv THEN
    PERFORM set_config('rp.jean_lou_interne', 'on', true);
    r := public.elections_voix_pnj_enregistrer('jl-' || p_requete::text, a.name, v_cycle, a.name, p_pnj, 'jean_lou', NULL);
    PERFORM set_config('rp.jean_lou_interne', '', true);
    -- PNJ deja engage par un autre biais : la voix n'est pas ecrite, et le tract ne compte pas.
    IF coalesce((r ->> 'ok')::boolean, false) IS NOT TRUE THEN v_conv := false; END IF;
  END IF;
  qc := qc || jsonb_build_object('electionCible', el,
          'ciblesJeanLou', v_cibles || to_jsonb(p_pnj),
          'resultatsJeanLou', (CASE WHEN jsonb_typeof(qc -> 'resultatsJeanLou') = 'array' THEN qc -> 'resultatsJeanLou' ELSE '[]'::jsonb END) || to_jsonb(v_conv));
  IF jsonb_array_length(qc -> 'ciblesJeanLou') >= 3 THEN qc := qc || jsonb_build_object('etape', 'tracts_termines'); END IF;
  UPDATE public.personnages_donnees SET quete_carriere = qc WHERE name = a.name;
  v := jsonb_build_object('ok', true, 'convaincu', v_conv, 'taux', v_taux, 'jet', v_roll, 'quete_carriere', qc,
         'voix', CASE WHEN v_conv THEN r ELSE NULL END)
       || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a.name);
  INSERT INTO public.inventaire_actions_recus VALUES (a.name, p_requete, 'jean_lou', params, v, now());
  RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.jean_lou_tract_distribuer(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.jean_lou_tract_distribuer(uuid, text) TO authenticated;
