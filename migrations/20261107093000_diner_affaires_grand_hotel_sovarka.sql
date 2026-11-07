-- Dîner d'affaires au restaurant du Grand Hôtel de Sovarka (Novomirsk), 100 PSK (Fred, 07/11/2026).
-- Même contrat commerce_v1 que le Capitaine Sauvage (#379, 20261103235800) : on ajoute le lieu à
-- diner_commerce_lieu_interne, rien d'autre. 2 menus russes (impérial, puis tsars, puis plan) et
-- 1 vin du commerce brasserie-soviet-capitale-hotel-republica ; effets inchangés.
-- Indépendante de l'écran (sans l'écran, l'ordre affiche encore 300 mais l'invitation est refusée
-- côté client « Invitation indisponible », sans frais).
DO $prevol$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.diner_commerce_lieu_interne(text,text,text,text)')
     AND position('capitaine-sauvage' in prosrc)>0) THEN RAISE EXCEPTION 'diner_sovarka_lieu_absent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.entreprises WHERE id='brasserie-soviet-capitale-hotel-republica') THEN
  RAISE EXCEPTION 'diner_sovarka_commerce_absent'; END IF;
END $prevol$;

INSERT INTO public.ordres_couts(fn,pa,cost) VALUES ('diner_affaires',2,100) ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.diner_commerce_lieu_interne(p_pays text,p_ville text,p_bat text,p_piece text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE
   WHEN (p_pays,p_ville,p_bat,p_piece)=('republic','ville_a','capitaine-sauvage','salle_principale')
    THEN '{"entreprise":"brasserie-republic-ville_a-capitaine-sauvage-salle_principale","prix":150,"pa":2,
           "menus":["menu_psm_1","menu_psm_2","menu_psm_3"],"boisson":"vin","qte_boisson":1}'::jsonb
   WHEN (p_pays,p_ville,p_bat,p_piece)=('soviet','capitale','hotel-republica','restaurant')
    THEN '{"entreprise":"brasserie-soviet-capitale-hotel-republica","prix":100,"pa":2,
           "menus":["menu_sovarka_imperial","menu_sovarka_tsars","menu_sovarka_plan"],"boisson":"vin","qte_boisson":1}'::jsonb
  END;
$f$;
REVOKE ALL ON FUNCTION public.diner_commerce_lieu_interne(text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
NOTIFY pgrst,'reload schema';
