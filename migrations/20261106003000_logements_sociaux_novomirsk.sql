-- Logements sociaux de Novomirsk (vue 14), decisions de Fred du 06/11/2026 : en Sovarka, tous les
-- logements hors suites sont des logements sociaux, sur la mecanique de Montrouge (demande a la
-- mairie, attribution par l'adjoint au maire, loyer a la commune, resiliation au depart).
-- 4 petits (10 PSK, +3 moral +4 sante au sommeil, comme Montrouge) et 4 grands
-- (20 PSK, +5 moral +7 sante), nombre decide par Fred. Loyers arrondis par Fred (regle du PA : 15 PSK contre 50 FR).
-- Le socle etait deja generique (logements_sociaux_historiques) sauf deux endroits patches ici :
--   * logements_sociaux_ville_a_offre ne connaissait que Montrouge en dur ;
--   * le courrier d'attribution ecrivait « FR » quel que soit le pays.
BEGIN;

INSERT INTO public.logements_sociaux_historiques (pays, ville, batiment, piece, label, type_logement, loyer, bonus_moral, bonus_sante) VALUES
  ('soviet', 'capitale', 'logements-novomirsk', 'petit_appartement_1', 'Petit appartement n°1', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk', 'petit_appartement_2', 'Petit appartement n°2', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk', 'petit_appartement_3', 'Petit appartement n°3', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk', 'petit_appartement_4', 'Petit appartement n°4', 'petit', 10, 3, 4),
  ('soviet', 'capitale', 'logements-novomirsk', 'grand_appartement_1', 'Grand appartement n°1', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk', 'grand_appartement_2', 'Grand appartement n°2', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk', 'grand_appartement_3', 'Grand appartement n°3', 'grand', 20, 5, 7),
  ('soviet', 'capitale', 'logements-novomirsk', 'grand_appartement_4', 'Grand appartement n°4', 'grand', 20, 5, 7)
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.logements_sociaux_ville_a_offre(p_pays text, p_ville text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT EXISTS (SELECT 1 FROM public.logements_sociaux_historiques h WHERE h.pays = p_pays AND h.ville = p_ville)
      OR EXISTS (
         SELECT 1 FROM public.terrains_etat t, jsonb_array_elements(coalesce(t.data::jsonb->'subdivisions','[]')) l
          WHERE t.country = p_pays AND t.data::jsonb->>'city' = p_ville
            AND t.data::jsonb->>'proprietaire' = 'ville:'||p_pays||':'||p_ville
            AND l->>'destination' = 'logement_social') $function$;

-- Courrier d'attribution : la monnaie du pays (patch en place, fragment verifie).
DO $$
DECLARE f text; ancien text := '||h.loyer||'' FR par échéance'; nouveau text := '||h.loyer||CASE h.pays WHEN ''soviet'' THEN '' PSK'' ELSE '' FR'' END||'' par échéance';
BEGIN
  SELECT pg_get_functiondef('public.logement_historique_attribuer_interne(text,text,text,text,text)'::regprocedure) INTO f;
  IF position(nouveau IN f) > 0 THEN RETURN; END IF;
  IF position(ancien IN f) = 0 THEN RAISE EXCEPTION 'logement_historique_attribuer_definition_non_examinee'; END IF;
  EXECUTE replace(f, ancien, nouveau);
END $$;

INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'logements-novomirsk',
   '["salle","petit_appartement_1","petit_appartement_2","petit_appartement_3","petit_appartement_4","grand_appartement_1","grand_appartement_2","grand_appartement_3","grand_appartement_4"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;
INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-14', 'logements-novomirsk')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
  IF NOT public.logements_sociaux_ville_a_offre('soviet', 'capitale')
     OR NOT public.logements_sociaux_ville_a_offre('republic', 'ville_b')
     OR public.logements_sociaux_ville_a_offre('soviet', 'ville_b')
     OR (SELECT count(*) FROM public.logements_sociaux_historiques WHERE pays = 'soviet' AND ville = 'capitale') <> 8
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE building = 'logements-novomirsk') THEN
    RAISE EXCEPTION 'logements_sociaux_novomirsk_incomplet';
  END IF;
END $$;

COMMIT;
