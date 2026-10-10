-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010174523 (UTC), nom `subventions_la_couche_d_eligibilite_et_son_verrou_fail_closed`.
-- Le registre passe de 624 a 625 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 15d5ec2d4727f56e1ef89a5881916b37, 9420 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAINE 7, §2 -- LA COUCHE D'ELIGIBILITE ET SON VERROU FAIL-CLOSED
--
-- La mecanique ne connait pas « le club de football » : elle connait des FAMILLES eligibles, et
-- « qui est eligible ? » devient une donnee. Un seul arbitrage est rendu -- les clubs du
-- championnat oui, les organisations criminelles non -- et les huit autres familles restent
-- `NON ARBITRE`, etat d'attente et non refus de jeu. Le verrou est STRUCTUREL : un trigger refuse
-- tout `eligible = true` pour une famille absente de `subvention_familles_resolues()`, parce que
-- declarer sans implementer ouvrirait la porte du maire sur un beneficiaire que personne ne peut
-- representer.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAINE 7, §2 -- LA COUCHE D'ELIGIBILITE (10 octobre 2026)
--
-- LA CONSIGNE EST EXPLICITE : « ne code pas la mecanique comme une subvention au club de
-- football. Raisonne en termes d'ORGANISATIONS ELIGIBLES. » Cette migration ne pose donc pas une
-- regle sur les clubs : elle fait de « qui est eligible ? » une DONNEE, et elle rend impossible
-- d'y repondre sans ecrire le code qui va avec.
--
-- CE QUI EST ARBITRE, ET CE QUI NE L'EST PAS. Un seul arbitrage est rendu : les clubs de football
-- sont eligibles, les organisations criminelles ne le sont pas. Les huit autres familles ne sont
-- PAS arbitrees -- et une migration n'a pas a decider a la place du game design. Elles sont donc
-- inscrites `eligible = false` avec le motif `NON ARBITRE`, ce qui n'est pas un refus de jeu :
-- c'est l'etat d'attente, ecrit noir sur blanc, qu'un futur arbitrage renversera d'un UPDATE.
--
-- DEUX REGISTRES, ET UN PIEGE A NOMMER. Un club du championnat n'est PAS une organisation : il
-- vit dans `clubs_football` (miroir genere) et sa caisse est dans `budgets_clubs`, tandis que les
-- organisations vivent dans `organisations`. Et la famille d'organisation `sportive` porte
-- justement le label « Club Sportif » -- deux choses differentes sous des mots voisins. La
-- colonne `registre` dit, pour chaque famille, OU se trouve l'entite ; confondre les deux aurait
-- rendu eligible une association sportive de quartier en croyant parler de l'Olympique.
--
-- LE VERROU EST STRUCTUREL, PAS DISCIPLINAIRE. Declarer une famille eligible sans savoir
-- resoudre sa domiciliation, son gestionnaire de caisse et son credit, ce serait ouvrir une porte
-- sur le vide : le maire verrait un beneficiaire que personne ne peut representer. Le trigger
-- interroge donc `subvention_familles_resolues()` -- la liste des familles que le CODE sait
-- traiter -- et REFUSE tout `eligible = true` pour une famille absente de cette liste. On ne peut
-- pas declarer sans implementer, et la base le garantit elle-meme.

CREATE OR REPLACE FUNCTION public.subvention_familles_resolues()
RETURNS SETOF text LANGUAGE sql IMMUTABLE AS $$
  -- LA LISTE DES FAMILLES QUE LE CODE SAIT TRAITER. Pour en ajouter une, il faut quatre gestes
  -- et pas un de moins : l'ajouter ICI, puis ecrire sa branche de domiciliation dans
  -- `subvention_organisations_locales`, sa branche de gestionnaire dans `subvention_gestionnaire`
  -- et sa branche de credit dans `subvention_caisse_crediter`. Tant que la cle n'est pas ici, le
  -- trigger de `subventions_familles` refuse de la declarer eligible.
  SELECT unnest(ARRAY['club_football']::text[]);
$$;

COMMENT ON FUNCTION public.subvention_familles_resolues() IS
  'Les familles dont le code sait resoudre domiciliation, gestionnaire et credit de caisse. '
  'Le trigger de subventions_familles refuse de declarer eligible une famille absente d''ici : '
  'on ne peut pas ouvrir une porte sur un beneficiaire que personne ne peut representer.';

CREATE TABLE IF NOT EXISTS public.subventions_familles (
  famille    text PRIMARY KEY,
  libelle    text NOT NULL,
  registre   text NOT NULL CHECK (registre IN ('organisation', 'club_football')),
  eligible   boolean NOT NULL DEFAULT false,
  arbitrage  text NOT NULL,
  note       text
);

ALTER TABLE public.subventions_familles ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.subventions_familles IS
  'Qui peut recevoir une subvention municipale, par FAMILLE -- la mecanique ne connait pas « le '
  'club de football », elle connait des familles eligibles. RLS active et AUCUNE policy : un '
  'navigateur ne lit pas cette table et ne peut donc pas inventer une eligibilite. L''interface '
  'passe par subvention_organisations_locales(), qui filtre deja par commune.';

COMMENT ON COLUMN public.subventions_familles.registre IS
  'Ou vit l''entite de cette famille. PIEGE A CONNAITRE : un club du championnat n''est pas une '
  'organisation, et la famille d''organisation `sportive` porte pourtant le label « Club Sportif ».';

COMMENT ON COLUMN public.subventions_familles.eligible IS
  'false avec l''arbitrage NON ARBITRE = etat d''attente, pas refus de jeu. Un trigger refuse de '
  'passer a true une famille que subvention_familles_resolues() ne sait pas traiter.';

CREATE OR REPLACE FUNCTION public.subventions_famille_a_son_resolveur()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.eligible AND NOT EXISTS (
       SELECT 1 FROM public.subvention_familles_resolues() f(x) WHERE f.x = NEW.famille) THEN
    RAISE EXCEPTION 'famille_sans_resolveur : la famille % ne peut pas etre declaree eligible -- '
      'le code ne sait pas resoudre sa domiciliation, son gestionnaire de caisse ni son credit. '
      'Ajoutez-la d''abord a subvention_familles_resolues() et ecrivez ses trois branches.',
      NEW.famille;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS subventions_familles_verrou_resolveur ON public.subventions_familles;
CREATE TRIGGER subventions_familles_verrou_resolveur
  BEFORE INSERT OR UPDATE ON public.subventions_familles
  FOR EACH ROW EXECUTE FUNCTION public.subventions_famille_a_son_resolveur();

INSERT INTO public.subventions_familles (famille, libelle, registre, eligible, arbitrage, note) VALUES
  ('club_football', 'Club de football du championnat', 'club_football', true,
   'ARBITRE LE 10 OCTOBRE 2026 : eligible. Une commune peut subventionner les clubs sportifs de '
   'son territoire -- c''est volontairement un levier politique important.',
   'Entite dans clubs_football (miroir genere), caisse dans budgets_clubs.data.caisse, '
   'gestionnaire dans presidents_clubs.data.president.'),
  ('criminelle', 'Organisation Criminelle', 'organisation', false,
   'ARBITRE LE 10 OCTOBRE 2026 : NON eligible. Refus explicite, pas un oubli.',
   'Aucun resolveur n''est ecrit, et il n''y a aucune raison d''en ecrire un.'),
  ('politique',  'Organisation Politique',  'organisation', false, 'NON ARBITRE', NULL),
  ('religieuse', 'Organisation Religieuse', 'organisation', false, 'NON ARBITRE', NULL),
  ('syndicale',  'Organisation Syndicale',  'organisation', false, 'NON ARBITRE', NULL),
  ('economique', 'Organisation Economique', 'organisation', false, 'NON ARBITRE', NULL),
  ('loge',       'Loge Maconnique',         'organisation', false, 'NON ARBITRE', NULL),
  ('mediatique', 'Organisation Mediatique', 'organisation', false, 'NON ARBITRE', NULL),
  ('sportive',   'Club Sportif',            'organisation', false, 'NON ARBITRE',
   'ATTENTION : cette famille d''organisation n''est PAS un club du championnat, malgre son '
   'label. Le club du championnat est la famille club_football, registre clubs_football.'),
  ('supporters', 'Club de Supporters',      'organisation', false, 'NON ARBITRE', NULL)
ON CONFLICT (famille) DO NOTHING;

DO $p$
DECLARE v integer; v_ok boolean;
BEGIN
  -- P1 : les dix familles sont la -- les neuf d'organisation et celle des clubs du championnat.
  SELECT count(*) INTO v FROM public.subventions_familles;
  IF v <> 10 THEN RAISE EXCEPTION 'P1 : % famille(s) au lieu de 10', v; END IF;

  -- P2 : UNE SEULE est eligible aujourd'hui, et c'est celle qui a ete arbitree.
  SELECT count(*) INTO v FROM public.subventions_familles WHERE eligible;
  IF v <> 1 THEN RAISE EXCEPTION 'P2 : % famille(s) eligible(s) au lieu de 1', v; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.subventions_familles
                  WHERE famille = 'club_football' AND eligible) THEN
    RAISE EXCEPTION 'P2 : la famille eligible n''est pas club_football';
  END IF;

  -- P3 : LES CRIMINELLES SONT REFUSEES PAR ARBITRAGE, pas par oubli. La difference est dans la
  -- donnee : leur motif ne dit pas NON ARBITRE.
  IF EXISTS (SELECT 1 FROM public.subventions_familles
              WHERE famille = 'criminelle' AND (eligible OR arbitrage LIKE '%NON ARBITRE%')) THEN
    RAISE EXCEPTION 'P3 : la famille criminelle n''est pas refusee par arbitrage explicite';
  END IF;

  -- P4 : les huit autres familles d'organisation sont en ATTENTE, et le disent.
  SELECT count(*) INTO v FROM public.subventions_familles
   WHERE NOT eligible AND arbitrage = 'NON ARBITRE';
  IF v <> 8 THEN RAISE EXCEPTION 'P4 : % famille(s) en attente au lieu de 8', v; END IF;

  -- P5 : LE VERROU FAIL-CLOSED MORD POUR DE VRAI. On tente de declarer eligible une famille sans
  -- resolveur, et on exige que la base REFUSE. L'echec est ici le succes.
  v_ok := false;
  BEGIN
    UPDATE public.subventions_familles SET eligible = true WHERE famille = 'loge';
  EXCEPTION WHEN others THEN v_ok := true;
  END;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'P5 : une famille SANS resolveur a pu etre declaree eligible -- le verrou '
      'fail-closed ne mord pas, et la porte s''ouvrirait sur le vide';
  END IF;

  -- P6 : et la famille qui A un resolveur est bien dans la liste. Le verrou refuse le vide, pas
  -- le travail fait.
  IF NOT EXISTS (SELECT 1 FROM public.subvention_familles_resolues() f(x)
                  WHERE f.x = 'club_football') THEN
    RAISE EXCEPTION 'P6 : club_football n''est pas dans la liste des familles resolues';
  END IF;

  -- P7 : aucune policy. Le navigateur ne lit pas l'eligibilite.
  SELECT count(*) INTO v FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'subventions_familles';
  IF v <> 0 THEN RAISE EXCEPTION 'P7 : % policy sur subventions_familles', v; END IF;

  RAISE NOTICE 'Couche d''eligibilite : 7 preuves structurelles vertes.';
END $p$;
