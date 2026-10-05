-- ===========================================================================
-- NEUF REFERENTS DE PLUS POUR REPUBLIA (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- Ce fichier ne cree aucune structure : le socle a ete fige au lot precedent, et
-- ajouter un referent n'est plus qu'une affaire de donnees. C'est precisement ce
-- qu'on attendait de lui.
--
-- CE QUE CES NEUF COMPLETENT :
--   * les deux derniers PNJ de la caserne -- Alouche et Eve etaient les seuls
--     encore servis par un litteral ecrit a la main dans l'assembleur ; avec eux,
--     plus aucun profil n'echappe a la source unique ;
--   * quatre referents civils qui portaient DEJA un corpus pedagogique arbitre
--     mais aucune personnalite -- elections, voyages, port, milieu criminel ;
--   * trois chefs de supporters, UN PAR VILLE. Leur role n'est pas d'expliquer le
--     football mais ce que le club pese dans la societe, et chaque ville a sa
--     propre culture de tribune : une institution a Luthecia, une famille a
--     Port-Sainte-Marie, une responsabilite collective a Montrouge.
--
-- LES TROIS LISTES RESTENT ALIGNEES. Celle-ci, REFERENTS dans
-- api/_pnj-referents.js, et PNJ_REFERENTS dans plateau-pnj.js. Le banc
-- .scratch/banc_referents_personnalites.py echoue si l'une diverge.
-- ===========================================================================

insert into public.pnj_referents (referent_id, pays, domaine) values
  ('caporal_alouche',   'republic', 'militaire — intendance et refectoire'),
  ('eve_toahemarch',    'republic', 'militaire — sante, blessures et soins'),
  ('jean_lou_zeure',    'republic', 'elections et campagnes'),
  ('alain_bordage',     'republic', 'voyages internationaux'),
  ('marcel_ancre',      'republic', 'administration portuaire'),
  ('pat_hounette',      'republic', 'milieu criminel'),
  ('alfredo_mifassole', 'republic', 'role social et politique du club — Luthecia'),
  ('pascal_hamar',      'republic', 'role social du club — Port-Sainte-Marie'),
  ('lucas_tenaire',     'republic', 'role social du club — Montrouge')
on conflict (referent_id) do nothing;

DO $garde$
DECLARE n integer;
BEGIN
  -- AU MOINS seize : la garde doit rester vraie quand d'autres empires recevront
  -- leurs propres referents.
  SELECT count(*) INTO n FROM public.pnj_referents;
  IF n < 16 THEN RAISE EXCEPTION 'liste des referents : % entrees, au moins 16 attendues', n; END IF;
  SELECT count(*) INTO n FROM public.pnj_referents WHERE pays IS NULL;
  IF n <> 0 THEN RAISE EXCEPTION '% referent(s) sans empire', n; END IF;
END $garde$;
