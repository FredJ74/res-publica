-- Climat — sacs de sable proportionnels (décision de Fred du 19/11).
-- • Chaque sac posé devant un bâtiment réduit la perte de crue de 10 % de la perte normale (20 % du stock) :
--   3 sacs → 14 % du stock perdu, 5 sacs → 10 %, plafond 9 sacs → 2 % (il reste toujours une perte à indemniser).
-- • La taille du local n'intervient pas. Un sac = une unité « sac_de_sable » de l'inventaire.
-- • Poser coûte 1 PA et pose d'un coup tous les sacs portés, dans la limite du plafond restant devant le bâtiment.
-- • Indemnisation inchangée : par défaut ceux qui ont posé au moins un sac (50 % de la perte), extension à tous au choix du PM.
-- • Réglages MJ : sacs_protection_pct (100) est remplacé par sac_protection_pct (10 % par sac) et sacs_plafond (9).
BEGIN;

ALTER TABLE public.climat_protections ADD COLUMN IF NOT EXISTS sacs integer NOT NULL DEFAULT 1 CHECK (sacs > 0);
DELETE FROM public.aliments_parametres WHERE cle = 'sacs_protection_pct';
INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('sac_protection_pct', 10), ('sacs_plafond', 9)
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.climat_sacs_poses_interne(p_pays text, p_ville text, p_batiment text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(sum(sacs), 0)::integer FROM public.climat_protections
   WHERE pays = p_pays AND ville = p_ville AND batiment = p_batiment AND evenement IS NULL;
$$;
-- Part de la perte normale qui subsiste avec n sacs (en %), plafond appliqué.
CREATE OR REPLACE FUNCTION public.climat_sacs_reste_pct_interne(p_sacs numeric)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(0, 100 - least(greatest(coalesce(p_sacs, 0), 0), public.aliments_param_interne('sacs_plafond', 9))
                          * public.aliments_param_interne('sac_protection_pct', 10));
$$;

CREATE OR REPLACE FUNCTION public.sacs_sable_poser(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; d public.personnages_donnees; v_inv jsonb; v_droit boolean;
        v_deja integer; v_plafond integer; v_n integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'sacs_sable_poser', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF NOT EXISTS (SELECT 1 FROM public.climat_zones_inondables WHERE pays = d.country AND ville = d.current_city AND batiment = d.current_building) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_zone_inondable'); END IF;
  v_droit := EXISTS (SELECT 1 FROM public.entreprises e
                      WHERE replace(coalesce(e.data->>'proprietaire', ''), 'pj:', '') = a
                        AND ((e.data->>'country' = d.country AND e.data->>'city' = d.current_city AND e.data->>'buildingId' = d.current_building)
                          OR (e.data->'implantation'->>'country' = d.country AND e.data->'implantation'->>'city' = d.current_city
                              AND e.data->'implantation'->>'buildingId' = d.current_building)))
          OR (d.current_building LIKE 'entrepot-logistique-%' AND d.poste->>'id' = 'directeur_entrepot');
  IF NOT v_droit THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire_ni_exploitant'); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('climat_sacs:' || d.country || ':' || d.current_city || ':' || d.current_building));
  v_deja := public.climat_sacs_poses_interne(d.country, d.current_city, d.current_building);
  v_plafond := public.aliments_param_interne('sacs_plafond', 9)::integer;
  IF v_deja >= v_plafond THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_protege', 'sacs', v_deja, 'plafond', v_plafond); END IF;
  v_inv := coalesce(d.inventory, '[]'::jsonb);
  v_n := least(public.inventaire_quantite(v_inv, 'sac_de_sable')::integer, v_plafond - v_deja);
  IF v_n < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_sacs'); END IF;
  v := public.payer_ordre(a, 'poser_sacs_sable', 1, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(inventory, 'sac_de_sable', v_n), updated_at = now() WHERE name = a;
  INSERT INTO public.climat_protections (pays, ville, batiment, pose_par, sacs) VALUES (d.country, d.current_city, d.current_building, a, v_n);
  v := jsonb_build_object('ok', true, 'batiment', d.current_building, 'pa', v->'pa', 'poses', v_n, 'sacs', v_deja + v_n, 'plafond', v_plafond,
                          'perte_pct', round(public.aliments_param_interne('crue_perte_pct', 20) * public.climat_sacs_reste_pct_interne(v_deja + v_n) / 100, 2))
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'sacs_sable_poser', prm, v);
END $$;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
SELECT pg_temp.rp_raccorder('public.climat_crue_appliquer_interne(public.climat_evenements)'::regprocedure,
  $a$CASE WHEN v_prot THEN (100 - public.aliments_param_interne('sacs_protection_pct', 100)) / 100 ELSE 1 END$a$,
  $b$public.climat_sacs_reste_pct_interne((SELECT coalesce(sum(zp.sacs), 0) FROM public.climat_protections zp
       WHERE zp.evenement = e.id AND zp.pays = e.pays AND zp.ville = e.ville AND zp.batiment = v_bat)) / 100 /* climat_sacs_proportionnels_v1 */$b$,
  'climat_sacs_proportionnels_v1');

SELECT pg_temp.rp_raccorder('public.climat_objet_interne(text,integer)'::regprocedure,
  $a$'Lot de sacs de sable'$a$, $b$'Sac de sable'$b$, '''Sac de sable''');
SELECT pg_temp.rp_raccorder('public.climat_objet_interne(text,integer)'::regprocedure,
  $a$il le protège pour une crue.$a$, $b$chaque sac réduit de 10 % la perte de la prochaine crue (9 sacs au plus).$b$, 'chaque sac réduit');
UPDATE public.personnages_donnees SET inventory = (SELECT jsonb_agg(CASE WHEN x->>'stackKey' = 'sac_de_sable'
         THEN x || jsonb_build_object('name', 'Sac de sable', 'desc', 'Posé devant un bâtiment de la zone inondable, chaque sac réduit de 10 % la perte de la prochaine crue (9 sacs au plus).') ELSE x END ORDER BY o)
       FROM jsonb_array_elements(inventory) WITH ORDINALITY t(x, o))
 WHERE jsonb_typeof(inventory) = 'array' AND inventory @> '[{"stackKey":"sac_de_sable"}]';

REVOKE ALL ON FUNCTION public.climat_sacs_poses_interne(text, text, text), public.climat_sacs_reste_pct_interne(numeric) FROM PUBLIC, anon, authenticated;

COMMIT;
