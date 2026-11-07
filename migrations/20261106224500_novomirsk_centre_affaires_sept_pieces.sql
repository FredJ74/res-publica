-- Novomirsk : autoriser les cinq pièces supplémentaires du centre d'affaires.
-- Additif uniquement : les anciennes pièces restent autorisées pendant les
-- sessions en cours ; le client n'expose plus open_space, bureau_standard et tribune.
-- Le second bureau reprend strictement le tarif du Bureau Prestige canonique.
UPDATE public.navigation_lieux_regles
   SET pieces = pieces || coalesce((
         SELECT jsonb_agg(nom)
           FROM jsonb_array_elements_text('["bureau_prestige_b","reunion_grande_a","reunion_grande_b","reunion_moyenne_a","reunion_moyenne_b"]'::jsonb) p(nom)
          WHERE NOT pieces ? nom
       ), '[]'::jsonb)
 WHERE pays='soviet' AND ville='capitale' AND batiment='centre-affaires';

INSERT INTO public.locaux_loyers_referentiel
    (batiment,piece,ville,prix,bonus_pop,bonus_inf,bonus_dis,label,louable,signature_serveur)
SELECT batiment,'bureau_prestige_b','capitale',prix,bonus_pop,bonus_inf,bonus_dis,
       'Bureau Prestige B',louable,signature_serveur
  FROM public.locaux_loyers_referentiel
 WHERE batiment='centre-affaires' AND piece='bureau_prestige' AND ville='*'
ON CONFLICT (batiment,piece,ville) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.navigation_lieux_regles
     WHERE pays='soviet' AND ville='capitale' AND batiment='centre-affaires'
       AND pieces @> '["hall","bureau_prestige","bureau_prestige_b","reunion_grande_a","reunion_grande_b","reunion_moyenne_a","reunion_moyenne_b"]'::jsonb
  ) OR NOT EXISTS (
    SELECT 1 FROM public.locaux_loyers_referentiel a
    JOIN public.locaux_loyers_referentiel b ON a.batiment=b.batiment
    WHERE a.batiment='centre-affaires' AND a.piece='bureau_prestige' AND a.ville='*'
      AND b.piece='bureau_prestige_b' AND b.ville='capitale'
      AND a.prix=b.prix AND a.bonus_pop=b.bonus_pop AND a.bonus_inf=b.bonus_inf AND a.bonus_dis=b.bonus_dis
      AND b.louable AND b.signature_serveur
  ) THEN
    RAISE EXCEPTION 'centre_affaires_novomirsk_incomplet';
  END IF;
END $$;
