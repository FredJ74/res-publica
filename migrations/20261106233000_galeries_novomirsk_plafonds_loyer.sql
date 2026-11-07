-- GALERIES DE NOVOMIRSK : PLAFONDS DE LOYER (décision de Fred, 06/11/2026).
-- Novomirsk est l'exception opulente de Sovarka : loyers un peu plus chers. Plafonds égaux par
-- taille : 150 PSK/jour pour chacun des deux grands locaux, 75 PSK pour chacun des deux moyens.
-- Ailleurs en Sovarka, le plus grand local reste plafonné à 100 PSK. La contrainte de table
-- passe de 100 à 150 au maximum ; sovarka_local_loyer_fixer lit déjà le plafond de chaque local.
ALTER TABLE public.sovarka_locaux DROP CONSTRAINT IF EXISTS sovarka_locaux_check;
ALTER TABLE public.sovarka_locaux ADD CONSTRAINT sovarka_locaux_check
  CHECK (plafond BETWEEN 0 AND 150 AND loyer BETWEEN 0 AND plafond);

UPDATE public.sovarka_locaux l SET plafond = v.plafond
  FROM (VALUES ('vitrine_principale',150), ('boutique_milieu',150), ('arriere_boutique',75), ('cave_reserve',75)) v(piece, plafond)
 WHERE l.pays = 'soviet' AND l.ville = 'capitale' AND l.batiment = 'centre-commercial' AND l.piece = v.piece;

DO $$
BEGIN
  IF (SELECT string_agg(piece||'='||plafond, ',' ORDER BY piece) FROM public.sovarka_locaux
       WHERE pays='soviet' AND ville='capitale' AND batiment='centre-commercial')
     IS DISTINCT FROM 'arriere_boutique=75,boutique_milieu=150,cave_reserve=75,vitrine_principale=150' THEN
    RAISE EXCEPTION 'plafonds des Galeries non posés'; END IF;
END $$;
