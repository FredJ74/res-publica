-- NON APPLIQUÉE — l'agent principal l'applique à la fusion (mission « Purge », 24/11/2026).
-- Point H.2 (Fred, 23/11 au soir, consigne du 24/11/2026) : bureaux du centre d'affaires de Krasnov, loyer de départ
-- 30 PSK par jour, réglable par le maire entre 0 et 40. Le plafond (40) et la porte du maire (sovarka_local_loyer :
-- loyer entre 0 et le plafond) existent déjà (migrations 20261106133000, 20261123214000) ; seul le loyer de départ change,
-- et seulement pour un bureau encore au loyer d'ouverture (40), sans demande liée ni exploitant : un loyer déjà choisi
-- par le maire n'est jamais écrasé. Rejouable ; rien du goulag.
BEGIN;
UPDATE public.sovarka_locaux l
   SET loyer = 30
 WHERE l.pays = 'soviet' AND l.ville = 'ville_b' AND l.batiment = 'centre-affaires'
   AND l.piece IN ('bureau_1', 'bureau_2', 'bureau_3', 'bureau_4')
   AND l.loyer = 40 AND l.plafond = 40 AND l.demande_id IS NULL
   AND public.sovarka_exploitant_interne(l.ville, l.batiment, l.piece) IS NULL;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.sovarka_locaux
              WHERE pays = 'soviet' AND ville = 'ville_b' AND batiment = 'centre-affaires'
                AND piece IN ('bureau_1', 'bureau_2', 'bureau_3', 'bureau_4') AND plafond <> 40) THEN
    RAISE EXCEPTION 'ghe_h2 : plafond des bureaux de Krasnov différent de 40';
  END IF;
END $$;
COMMIT;
