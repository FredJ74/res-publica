-- Images WebP (Claude, 02/11/2026) : les portraits de quatre escorts (escorts_catalogue.portrait)
-- et l'image du camion de la caserne de Luthécia (camions_militaires.image_url) pointent vers des
-- PNG convertis en WebP par la PR « PNG vers WebP ». À appliquer APRÈS Vercel READY (les .webp
-- doivent être servis). Les PNG restent servis jusqu'au lot suivant, qui les retirera.
-- Gardes : chaque ligne n'est modifiée que si elle porte exactement l'ancien chemin ; rejouable.
DO $webp$
DECLARE n integer;
BEGIN
  UPDATE public.escorts_catalogue SET portrait = replace(portrait, '.png', '.webp')
   WHERE portrait IN ('images/escort-f-2-robe-or.png', 'images/escort-f-3-robe-marine.png',
                      'images/escort-h-2-chemise-noire.png', 'images/escort-h-3-chemise-ouverte.png');
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n NOT IN (0, 4) THEN RAISE EXCEPTION 'escorts_catalogue : % ligne(s) au lieu de 4', n; END IF;
  UPDATE public.camions_militaires SET image_url = 'images/republia-camion-caserne.webp'
   WHERE image_url = 'images/republia-camion-caserne.png';
  IF EXISTS (SELECT 1 FROM public.escorts_catalogue WHERE portrait ~ 'escort-[fh]-[23]-.*\.png$')
     OR EXISTS (SELECT 1 FROM public.camions_militaires WHERE image_url = 'images/republia-camion-caserne.png') THEN
    RAISE EXCEPTION 'chemins PNG restants';
  END IF;
END $webp$;
