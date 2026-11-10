-- MATERIELS PAR COMBINAISON : COUINATOR 3000 ET CARTOUCHE D'ENCRE (decision 19 de Fred, 10/11/2026 au soir ;
-- GAME-DESIGN-EQUIPEMENTS.md).
--
-- Deux nouvelles recettes de la boutique d'electronique (type `electronique-informatique`), fabriquees et vendues
-- comme les dix articles existants ; prix par la regle de fixation existante (aucun prix fixe) :
--   Couinator 3000    : 1 composant electronique + 1 plastique (derives_petrochimiques), 1 PA, objet individualise ;
--                       detecteur de cameras : bonus de l'ordre « Fouiller les lieux » (75 % au lieu de 15 %, a venir).
--   Cartouche d'encre : 1 plastique, 1 PA, consommable empilable ; une cartouche par faux document imprime (a venir).
-- PA des recettes : choix technique (comme le jeu video et le telephone, 1 PA).
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

INSERT INTO public.catalogue_generiques (id, libelle, famille_id, regime, est_service, empilable, individualise, consommable, equipable, note) VALUES
  ('couinator-3000', 'Couinator 3000', 'electronique', 'libre', false, false, true, false, false,
   'Detecteur de cameras en forme de canard (Fred, 10/11/2026) : bonus de l''ordre Fouiller les lieux.'),
  ('cartouche-encre', 'Cartouche d''encre', 'informatique', 'libre', false, true, false, true, false,
   'Consommable de l''imprimante papier (Fred, 10/11/2026) : une cartouche par faux document.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.catalogue_generique_type (generique_id, type_id)
SELECT x.g, 'electronique-informatique' FROM (VALUES ('couinator-3000'), ('cartouche-encre')) x(g)
 WHERE NOT EXISTS (SELECT 1 FROM public.catalogue_generique_type c
                    WHERE c.generique_id = x.g AND c.type_id = 'electronique-informatique');

INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, intermediaires, categorie,
                                      types_autorises, stack_key, icone, image, description, generique_id) VALUES
  ('couinator_3000_commerce', 'commerce', 'Couinator 3000', 1, 1, '{"derives_petrochimiques":1}'::jsonb,
   '{"composants-electroniques":1}'::jsonb, 'informatique', '["electronique-informatique"]'::jsonb, NULL, 'ti-radar',
   'images/objet-couinator-3000.webp',
   'Détecteur de caméras en forme de canard jaune : il couine de plus en plus fort près d''une caméra.', 'couinator-3000'),
  ('cartouche_encre_commerce', 'commerce', 'Cartouche d''encre', 1, 1, '{"derives_petrochimiques":1}'::jsonb,
   '{}'::jsonb, 'informatique', '["electronique-informatique"]'::jsonb, 'cartouche-encre', 'ti-droplet', NULL,
   'Une cartouche pour imprimer un document.', 'cartouche-encre')
ON CONFLICT (id) DO NOTHING;

-- Controle structurel.
DO $$
BEGIN
  IF (SELECT count(*) FROM public.recettes_commerce
       WHERE id IN ('couinator_3000_commerce', 'cartouche_encre_commerce')
         AND types_autorises ? 'electronique-informatique') <> 2
     OR (SELECT count(*) FROM public.catalogue_generique_type
          WHERE type_id = 'electronique-informatique' AND generique_id IN ('couinator-3000', 'cartouche-encre')) <> 2 THEN
    RAISE EXCEPTION 'equipements_couinator_cartouche : controle structurel en echec';
  END IF;
END $$;

COMMIT;
