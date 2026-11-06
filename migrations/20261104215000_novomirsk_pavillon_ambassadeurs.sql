-- Novomirsk, vue 7 : le Pavillon des Ambassadeurs est raccordé (Claude, 04/11/2026, décisions de Fred).
-- Appartements de luxe, équivalent des suites de l'hôtel Républica : trois suites louables
-- (Suite Privée et Suite Présidentielle à l'identique, Suite du Parti +10 POP +6 INF +2 DIS, toutes
-- à 500 FR/jour), une grande salle de réception et un bar (commerce « bar », copie du Bar du
-- Républica). Le Grand Hôtel de Novomirsk perd ses suites (pièces retirées de ses règles).
-- Miroirs du commerce : lignes produites par generer_miroirs_entreprises.py (empreinte 8780e919c49e05f3),
-- insérées une à une plutôt que par la régénération complète. Idempotente.
INSERT INTO public.navigation_lieux_regles(pays, ville, batiment, pieces, ferme, membership) VALUES
  ('soviet', 'capitale', 'pavillon-ambassadeurs-novomirsk',
   '["hall_pavillon", "salle_reception", "bar", "suite_privee", "suite_presidentielle", "suite_parti"]'::jsonb, false, NULL)
ON CONFLICT (pays, ville, batiment) DO UPDATE SET pieces = EXCLUDED.pieces, ferme = EXCLUDED.ferme, membership = EXCLUDED.membership;

UPDATE public.navigation_lieux_regles
   SET pieces = (SELECT coalesce(jsonb_agg(p ORDER BY o), '[]'::jsonb)
                   FROM jsonb_array_elements_text(pieces) WITH ORDINALITY x(p, o)
                  WHERE p NOT IN ('suite_privee', 'suite_presidentielle'))
 WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'hotel-republica';

INSERT INTO public.rue_sorties_batiments(country, city, noeud, building) VALUES
  ('soviet', 'capitale', 'novomirsk-vue-7', 'pavillon-ambassadeurs-novomirsk')
ON CONFLICT DO NOTHING;

INSERT INTO public.locaux_loyers_referentiel(batiment, piece, ville, prix, bonus_pop, bonus_inf, bonus_dis, label, louable) VALUES
  ('pavillon-ambassadeurs-novomirsk','suite_privee','*',500,0,8,10,'Suite Privée',true),
  ('pavillon-ambassadeurs-novomirsk','suite_presidentielle','*',500,8,8,2,'Suite Présidentielle',true),
  ('pavillon-ambassadeurs-novomirsk','suite_parti','*',500,10,6,2,'Suite du Parti',true)
ON CONFLICT DO NOTHING;

INSERT INTO public.commerces_types (cle, type) VALUES
  ('pavillon-ambassadeurs-novomirsk|bar', 'bar')
ON CONFLICT (cle) DO UPDATE SET type = EXCLUDED.type;

INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres) VALUES
  ('pavillon-ambassadeurs-novomirsk|bar', 'bar', 2000, '{"cereales": 10, "fruits_legumes": 10, "produits_exotiques": 10}'::jsonb, '{"cereales": 3, "fruits_legumes": 4, "produits_exotiques": 6}'::jsonb, '["vin", "cafe_boisson", "biere_pression", "snack_buvette"]'::jsonb, '{"prixVente": {"biere_pression": 7, "cafe_boisson": 7, "snack_buvette": 7, "vin": 7}, "stockMax": {"biere_pression": 20, "cafe_boisson": 20, "snack_buvette": 20, "vin": 20}}'::jsonb)
ON CONFLICT (cle) DO UPDATE SET type = EXCLUDED.type, caisse = EXCLUDED.caisse, stock_matieres = EXCLUDED.stock_matieres,
  cout_moyen_matieres = EXCLUDED.cout_moyen_matieres, carte = EXCLUDED.carte, parametres = EXCLUDED.parametres;

DO $$
BEGIN
  IF (SELECT jsonb_array_length(pieces) FROM public.navigation_lieux_regles
       WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'pavillon-ambassadeurs-novomirsk') IS DISTINCT FROM 6
     OR EXISTS (SELECT 1 FROM public.navigation_lieux_regles WHERE pays = 'soviet' AND ville = 'capitale'
                  AND batiment = 'hotel-republica' AND pieces ?| ARRAY['suite_privee', 'suite_presidentielle'])
     OR NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                      AND noeud = 'novomirsk-vue-7' AND building = 'pavillon-ambassadeurs-novomirsk')
     OR (SELECT count(*) FROM public.locaux_loyers_referentiel WHERE batiment = 'pavillon-ambassadeurs-novomirsk') <> 3
     OR NOT EXISTS (SELECT 1 FROM public.commerces_dotations WHERE cle = 'pavillon-ambassadeurs-novomirsk|bar' AND caisse = 2000) THEN
    RAISE EXCEPTION 'novomirsk_pavillon_incomplet';
  END IF;
END $$;
