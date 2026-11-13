-- Décision du game designer, 13/11/2026 : le soin confidentiel
-- ne pénalise plus la jauge de discrétion du PJ.
-- Conserver le gain de santé, le jet serveur, le tarif et toutes les autres règles.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.ordres_generiques
    WHERE fn='soins_discrets' AND effets->>'hp'='30'
      AND taux_reussite=95 AND toujours_reussi=false
  ) THEN
    RAISE EXCEPTION 'soins_discrets : référentiel inattendu, migration interrompue';
  END IF;
END $$;
UPDATE public.ordres_generiques
SET effets = effets - 'dis', maj_le=now()
WHERE fn='soins_discrets';
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.ordres_generiques
    WHERE fn='soins_discrets' AND effets='{"hp":30}'::jsonb
  ) THEN
    RAISE EXCEPTION 'soins_discrets : suppression du malus non vérifiée';
  END IF;
END $$;
