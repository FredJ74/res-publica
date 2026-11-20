-- ORGANISATIONS SECRÈTES : DEUX OPTIONS INDÉPENDANTES (correction de Fred du 20/11/2026, avant fusion de #1159).
-- À la création, le chef règle :
--   • membres_se_connaissent (oui/non) : les membres voient-ils les autres membres ?
--   • chef_connu (oui/non) : les membres connaissent-ils l'identité du chef ? Caché, il apparaît « le chef », sans nom
--     (entrée de membre { chef_anonyme: true }, clé chef_masque sur l'organisation).
-- Quatre configurations. Le chef (et le fondateur) voit toujours tout ; l'extérieur ne voit jamais aucun nom.
-- Rétrocompatible : l'ancien « cloisonnement » ('connus' / 'cloisonne') vaut (oui, oui) / (non, non).
-- Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION public.organisation_vue_interne(p_data jsonb, p_moi text)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE v_membres jsonb := CASE WHEN jsonb_typeof(p_data -> 'membres') = 'array' THEN p_data -> 'membres' ELSE '[]'::jsonb END;
  v_moi_entree jsonb; v_ancien boolean := coalesce(p_data ->> 'cloisonnement', 'connus') = 'connus';
  v_connus boolean; v_chef_connu boolean; v_chefs text[]; v_out jsonb; k text;
BEGIN
  IF NOT public.organisation_secrete_donnees_interne(p_data) THEN RETURN p_data; END IF;
  IF p_moi IS NOT NULL AND p_moi IN (p_data ->> 'chef', p_data ->> 'fondateur') THEN
    RETURN p_data || jsonb_build_object('secrete', true);
  END IF;
  SELECT m INTO v_moi_entree FROM jsonb_array_elements(v_membres) m WHERE m ->> 'nom' = p_moi LIMIT 1;
  IF v_moi_entree IS NULL THEN
    -- Extérieur : le nom et la nature, jamais un membre ni un compteur.
    RETURN jsonb_strip_nulls(jsonb_build_object('id', p_data ->> 'id', 'nom', p_data ->> 'nom', 'type', p_data ->> 'type',
      'desc', p_data ->> 'desc', 'country', p_data ->> 'country', 'country_origine', p_data ->> 'country_origine',
      'avatar', p_data -> 'avatar', 'visible', false, 'secrete', true, 'membres_masques', true,
      'membres', '[]'::jsonb, 'demandesAdhesion', '[]'::jsonb));
  END IF;
  v_connus := CASE WHEN jsonb_typeof(p_data -> 'membres_se_connaissent') = 'boolean' THEN (p_data ->> 'membres_se_connaissent')::boolean ELSE v_ancien END;
  v_chef_connu := CASE WHEN jsonb_typeof(p_data -> 'chef_connu') = 'boolean' THEN (p_data ->> 'chef_connu')::boolean ELSE v_ancien END;
  v_chefs := array_remove(ARRAY[p_data ->> 'chef', p_data ->> 'fondateur'], NULL);
  v_out := p_data - 'demandesAdhesion';
  -- Membres qui ne se connaissent pas : moi seul (+ le chef, connu ou anonyme) ; aucun responsable ni scrutin nommé.
  IF NOT v_connus THEN
    v_membres := (SELECT coalesce(jsonb_agg(m), '[]'::jsonb) FROM jsonb_array_elements(v_membres) m
                   WHERE m ->> 'nom' = p_moi OR m ->> 'nom' = ANY (v_chefs));
    v_out := v_out - 'election';
    FOREACH k IN ARRAY ARRAY['president', 'tresorier', 'secretaire'] LOOP
      IF NOT (v_chef_connu AND v_out ->> k = ANY (v_chefs)) THEN v_out := v_out - k; END IF;
    END LOOP;
  END IF;
  -- Chef inconnu : jamais son nom ; il reste « le chef ».
  IF NOT v_chef_connu THEN
    v_out := v_out - 'chef' - 'fondateur' - 'election';
    FOREACH k IN ARRAY ARRAY['president', 'tresorier', 'secretaire'] LOOP
      IF v_out ->> k = ANY (v_chefs) THEN v_out := v_out - k; END IF;
    END LOOP;
    v_membres := (SELECT coalesce(jsonb_agg(CASE WHEN m ->> 'nom' = ANY (v_chefs) AND m ->> 'nom' IS DISTINCT FROM p_moi
                                                THEN jsonb_build_object('chef_anonyme', true) ELSE m END), '[]'::jsonb)
                    FROM jsonb_array_elements(v_membres) m);
    IF NOT v_membres @> '[{"chef_anonyme": true}]'::jsonb THEN
      v_membres := jsonb_build_array(jsonb_build_object('chef_anonyme', true)) || v_membres;
    END IF;
  END IF;
  RETURN v_out || jsonb_build_object('membres', v_membres, 'secrete', true,
    'membres_masques', NOT v_connus, 'chef_masque', NOT v_chef_connu);
END $$;

-- Création : les deux options (secrètes seulement ; oui/oui par défaut, comme une organisation ordinaire).
DO $r$
DECLARE d text := pg_get_functiondef('public.organisation_vie_commande(text,text,text,jsonb)'::regprocedure);
  avant text := $a$      'cloisonnement', CASE WHEN (v_def->>'secret')::boolean AND p_parametres->>'cloisonnement' = 'cloisonne' THEN 'cloisonne' ELSE 'connus' END); /* organisations_secretes_v1 */$a$;
  apres text := $b$      'membres_se_connaissent', NOT ((v_def->>'secret')::boolean AND coalesce(p_parametres->>'membres_se_connaissent', 'true') = 'false'),
      'chef_connu', NOT ((v_def->>'secret')::boolean AND coalesce(p_parametres->>'chef_connu', 'true') = 'false')); /* organisations_secretes_v2 */$b$;
BEGIN
  IF position('organisations_secretes_v2' IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN RAISE EXCEPTION 'organisation_vie_commande : ancrage v1 introuvable'; END IF;
  EXECUTE replace(d, avant, apres);
END $r$;

COMMIT;
