-- ===========================================================================
-- LAURENT BARRE, DIX-SEPTIEME REFERENT (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- Sa personnalite avait ete arbitree le 18 aout 2026, en meme temps que son
-- corpus pedagogique -- mais seul le corpus avait ete repris, et il etait reste
-- une fiche riche parmi les autres. Il rejoint le socle avec ce qui avait ete
-- decide pour lui, sans rien y ajouter.
--
-- Aucune structure n'est touchee : le socle fige accueille un referent de plus
-- par une ligne de donnees.
-- ===========================================================================

insert into public.pnj_referents (referent_id, pays, domaine) values
  ('laurent_barre', 'republic', 'immobilier et entrepreneuriat')
on conflict (referent_id) do nothing;

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.pnj_referents;
  IF n < 17 THEN RAISE EXCEPTION 'liste des referents : % entrees, au moins 17 attendues', n; END IF;
  SELECT count(*) INTO n FROM public.pnj_referents WHERE pays IS NULL;
  IF n <> 0 THEN RAISE EXCEPTION '% referent(s) sans empire', n; END IF;
END $garde$;
