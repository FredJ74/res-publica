-- ===========================================================================
-- UN REFERENT APPARTIENT A UN EMPIRE (1er octobre 2026)
-- ---------------------------------------------------------------------------
-- POURQUOI MAINTENANT, ALORS QUE RIEN NE CHANGE. La regle de socle dit que les
-- mecaniques se mutualisent entre les empires et que les personnages ne le font
-- jamais. Le catalogue des escorts, construit le meme jour, porte deja un `pays`
-- sur chaque identite ; celui des referents n'en avait pas. Deux socles jumeaux,
-- deux formes differentes : l'ecart se serait paye au premier referent de
-- Sovarka.
--
-- CE FICHIER NE CHANGE AUCUN COMPORTEMENT. Il n'existe aujourd'hui que des
-- referents de Republia, et personne ne lit encore cette colonne. C'est une
-- PREPARATION, assumee comme telle : sept lignes a renseigner aujourd'hui,
-- treize ou vingt plus tard.
--
-- CE QU'IL NE FAIT PAS. Il ne corrige pas l'incoherence reelle -- un joueur a
-- Novomirsk qui clique sur Marc Hantile obtient le referent economie de
-- Republia. Celle-la vient de la duplication des PNJ nommes dans data.js, et
-- elle releve du developpement de chaque empire, pas de ce socle.
-- ===========================================================================

alter table public.pnj_referents
  add column if not exists pays text;

-- Les sept existants sont de Republia. Renseigne avant de poser la contrainte :
-- une colonne NOT NULL sur des lignes vides echouerait.
update public.pnj_referents set pays = 'republic' where pays is null;

alter table public.pnj_referents
  alter column pays set not null;

comment on column public.pnj_referents.pays is
  'Empire auquel ce referent appartient. Un personnage n''existe QUE dans son empire : Sovarka aura son propre referent economie, qui ne sera pas Marc Hantile. Doit rester aligne avec le champ `pays` de api/_pnj-referents.js -- le banc .scratch/banc_referents_personnalites.py le verifie.';

create index if not exists pnj_referents_par_empire
  on public.pnj_referents (pays);

DO $garde$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.pnj_referents WHERE pays IS NULL;
  IF n <> 0 THEN RAISE EXCEPTION '% referent(s) sans empire', n; END IF;
  SELECT count(*) INTO n FROM public.pnj_referents WHERE pays = 'republic';
  IF n < 7 THEN RAISE EXCEPTION 'Republia : % referents, au moins 7 attendus', n; END IF;
END $garde$;
