-- 2 novembre 2026, decision de Fred : « les dealers vendent tous la meme chose ».
-- La boulette a 50 FR de Céd' Labone (centre artisanal de Luthecia) est aussi vendue par
-- Ronan Lafourgue (centre artisanal de PSM, ville_a) et Jojo Laferraille (Montrouge, ville_b).
-- Meme prix, meme objet, meme trace ; seule la cible de la trace porte le nom du dealer local.
-- Patch en place de la definition de production (deux fragments verifies), pas de reecriture.
DO $$
DECLARE f text; ancien_lieu text; nouveau_lieu text; ancienne_cible text; nouvelle_cible text;
BEGIN
  SELECT pg_get_functiondef('public.pnj_ced_acheter(uuid)'::regprocedure) INTO f;
  IF position('dealers_republia_meme_vente' IN f) > 0 THEN RETURN; END IF;
  ancien_lieu := 'p.current_city IS DISTINCT FROM ''capitale''';
  nouveau_lieu := 'coalesce(p.current_city,'''') NOT IN (''capitale'',''ville_a'',''ville_b'') /* dealers_republia_meme_vente */';
  ancienne_cible := 'acteur,''Céd'''' Labone'',''achat_drogue''';
  nouvelle_cible := 'acteur,CASE p.current_city WHEN ''ville_a'' THEN ''Ronan Lafourgue'' WHEN ''ville_b'' THEN ''Jojo Laferraille'' ELSE ''Céd'''' Labone'' END,''achat_drogue''';
  IF position(ancien_lieu IN f) = 0 OR position(ancienne_cible IN f) = 0 THEN
    RAISE EXCEPTION 'pnj_ced_acheter_definition_non_examinee';
  END IF;
  f := replace(replace(f, ancien_lieu, nouveau_lieu), ancienne_cible, nouvelle_cible);
  EXECUTE f;
END $$;
