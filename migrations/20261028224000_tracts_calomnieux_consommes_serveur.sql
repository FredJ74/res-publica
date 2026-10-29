-- APPLIQUEE le 28/10/2026 par Claude via MCP apply_migration -- registres Supabase 20261028212558
-- (calomnie_distribuer_consommer) et 20261028212637 (calomnie_appliquer_effet par la table).
-- Eprouvee au role authenticated en transaction annulee : 6 tracts -> 6 reussites, 6 PA retires,
-- rejeu sans second retrait, lot epuise refuse ; la popularite de la cible baisse enfin.
-- ============================================================================
-- TRACTS CALOMNIEUX : PA ET TRACT CONSOMMES PAR LE SERVEUR (28 octobre 2026, Claude)
-- ============================================================================
-- calomnie_distribuer tranchait deja le jet, mais annoncait « consomme 1, pa 1 » sans rien
-- retirer : l'ecran otait lui-meme le tract (et, sur un flagrant delit, tous les tracts
-- calomnieux), qu'un tricheur gardait donc indefiniment. calomnie_distribuer_consommer fait la
-- meme distribution PUIS, dans la meme transaction : 1 PA, 1 tract de ce lot, et sur un flagrant
-- delit tous les tracts calomnieux. Rejeu de la meme requete : resultat rendu sans second retrait.
-- L'ancienne entree reste ouverte tant que l'ecran en ligne l'appelle (fermee apres la livraison
-- par 20261028210700).
-- Idempotente. Aucun acte de joueur.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.calomnie_distribuer_consommer(p_requete text, p_cible text, p_pnj_nom text, p_vol_pnj integer)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_req uuid; v_params jsonb; v jsonb; r jsonb; v_pos integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' OR length(p_requete) > 120 THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  v_req := md5('calomnie|' || p_requete)::uuid;
  v_params := jsonb_build_object('requete', p_requete, 'cible', p_cible, 'pnj', p_pnj_nom);
  PERFORM 1 FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  v := public.inventaire_action_rejouer_interne(v_moi, v_req, 'calomnie', v_params); IF v IS NOT NULL THEN RETURN v; END IF;
  r := public.calomnie_distribuer_interne(p_requete, v_moi, p_cible, p_pnj_nom, p_vol_pnj, now());
  IF coalesce((r ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN r; END IF;
  IF r ->> 'poursuite' = 'flagrant_delit' THEN
    UPDATE public.personnages_donnees
       SET inventory = coalesce((SELECT jsonb_agg(e ORDER BY o) FROM jsonb_array_elements(inventory) WITH ORDINALITY x(e, o)
                                  WHERE e ->> 'type' IS DISTINCT FROM 'tract_calomnieux'), '[]'::jsonb),
           pa = greatest(0, coalesce(pa, 0) - 1)
     WHERE name = v_moi;
  ELSE
    SELECT (o - 1)::integer INTO v_pos FROM public.personnages_donnees d, jsonb_array_elements(d.inventory) WITH ORDINALITY x(e, o)
     WHERE d.name = v_moi AND e ->> 'type' = 'tract_calomnieux' AND e ->> 'cible' = p_cible
       AND jsonb_typeof(e -> 'quantite') = 'number' AND (e ->> 'quantite')::numeric >= 1 ORDER BY o LIMIT 1;
    UPDATE public.personnages_donnees
       SET inventory = CASE WHEN v_pos IS NULL THEN inventory
                            WHEN (inventory -> v_pos ->> 'quantite')::numeric <= 1 THEN inventory - v_pos
                            ELSE jsonb_set(inventory, ARRAY[v_pos::text, 'quantite'], to_jsonb((inventory -> v_pos ->> 'quantite')::numeric - 1)) END,
           pa = greatest(0, coalesce(pa, 0) - 1)
     WHERE name = v_moi;
  END IF;
  v := r || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'pa_restants', pa)
               FROM public.personnages_donnees WHERE name = v_moi);
  INSERT INTO public.inventaire_actions_recus VALUES (v_moi, v_req, 'calomnie', v_params, v, now());
  RETURN v;
END; $function$;
REVOKE ALL ON FUNCTION public.calomnie_distribuer_consommer(text, text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calomnie_distribuer_consommer(text, text, text, integer) TO authenticated;

-- DEFAUT DEJA EN PRODUCTION, corrige ici : calomnie_appliquer_effet ecrivait la popularite de la
-- CIBLE par la vue « personnages », dont la garde refuse toute ligne qui n'appartient pas au
-- joueur appelant (personnage_non_possede). Toute distribution REUSSIE echouait donc entierement,
-- et l'ecran annoncait « Réseau indisponible ». L'ecriture passe par la table de donnees.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.calomnie_appliquer_effet(text,integer,integer)'::regprocedure);
  IF position('UPDATE public.personnages_donnees' IN v_def) = 0 THEN
    v_def := replace(v_def, E'  UPDATE public.personnages\n', E'  UPDATE public.personnages_donnees\n');
    IF position('UPDATE public.personnages_donnees' IN v_def) = 0 THEN RAISE EXCEPTION 'calomnie_appliquer_effet : motif introuvable'; END IF;
    EXECUTE v_def;
  END IF;
END $do$;
