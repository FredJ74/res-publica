-- PLAFOND DU PRIX LIBRE D'UN PJ EN SOVARKA (décision de Fred, 06/11/2026).
-- Mêmes ratios qu'en Républia, sans exception de ville : un PNJ vend à 2 fois son coût de revient,
-- un PJ jusqu'à 4 fois (le coût de la main-d'œuvre, bien plus bas en Sovarka, suffit à faire la différence).
-- Sans cette ligne, fonds_cout_revient_reference répondait « coefficient_pays_non_defini » :
-- un commerçant PJ de Sovarka ne pouvait pas fixer ses prix.
INSERT INTO public.entreprises_constantes (cle, valeur) VALUES ('coef_prix_max_pj_soviet', '4')
ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

DO $$
BEGIN
  IF public.coef_prix_max_pj('soviet') IS DISTINCT FROM 4 OR public.coef_prix_max_pj('republic') IS DISTINCT FROM 4 THEN
    RAISE EXCEPTION 'coefficients : soviet %, republic %', public.coef_prix_max_pj('soviet'), public.coef_prix_max_pj('republic');
  END IF;
END $$;
