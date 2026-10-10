-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010175109 (UTC), nom `subventions_la_table_des_propositions_et_ses_contraintes`.
-- Le registre passe de 626 a 627 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 d8ae8e79dc31ea164de5d4c09e883f05, 9585 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAINE 7, §3 -- LA TABLE DES PROPOSITIONS ET SES CONTRAINTES
--
-- La RESERVE n'est pas une colonne, et c'est volontaire : c'est la SOMME des lignes encore
-- `proposee`, calculee a la demande -- une colonne la dupliquerait, et un plantage entre son debit
-- et la cloture perdrait ou inventerait de l'argent. L'anti-rejeu est un index unique PARTIEL sur
-- `proposee` : un double-clic est refuse, mais reproposer apres un refus reste permis -- la lecon
-- de `compromis_historique` (registre 601). Le delai de trois jours et la coherence de l'issue
-- vivent en CHECK dans la table, pas recopies dans chaque porte. Lecture publique des seules
-- propositions CLOSES, conformement a l'arbitrage §5 ; aucune ecriture cliente.
--
-- NOTE D'ARCHIVE : le corps contient la coquille « divergerp » (pour « diverger »). Elle est
-- conservee -- une archive doit dire la verite sur ce qui a ete applique.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAINE 7, §3 -- LA TABLE DES PROPOSITIONS (10 octobre 2026)
--
-- ETAGE 2. L'enveloppe est remplie par la cascade ; ici le maire en propose des montants BRUTS, un
-- par un. Pas de cle de repartition entre organisations : « autant de propositions que les fonds
-- le permettent ».
--
-- LA RESERVE N'EST PAS UNE COLONNE, ET C'EST VOLONTAIRE. Une enveloppe de 5 000 d'ou l'on propose
-- 1 500 laisse 3 500 disponibles -- mais on n'ecrit NULLE PART « reserve = 1 500 ». La reserve est
-- la SOMME des propositions encore `proposee`, calculee a la demande. Une colonne la dupliquerait,
-- et une donnee dupliquee finit toujours par divergerp -- un plantage entre le debit de la colonne
-- et la cloture de la proposition suffirait a perdre de l'argent ou a en inventer. Ici, accepter,
-- refuser ou expirer une proposition LIBERE la reserve par le seul fait de changer son statut.
--
-- L'ANTI-REJEU EST STRUCTUREL, ET IL NE REFUSE AUCUN ACTE REEL. L'index unique est PARTIEL, sur
-- `proposee` seulement : tant qu'une proposition de 1 500 a l'Olympique est en attente, une
-- seconde identique le meme jour est impossible -- c'est un double-clic ou un rejeu reseau, jamais
-- une intention. Une fois la premiere close, une identique repasse : le maire a parfaitement le
-- droit de reproposer. Et deux montants DIFFERENTS le meme jour passent toujours : c'est la lecon
-- de `compromis_historique` (registre 601), ou `resultat` entre dans la cle pour la meme raison.
--
-- CE QUI EST PUBLIC, ET CE QUI NE L'EST PAS. L'arbitrage §5 impose la publicite des TROIS ISSUES :
-- acceptee, refusee, expiree -- « un non-dit de trois jours doit aussi laisser une trace
-- publique ». Il n'impose RIEN sur une proposition encore en attente, et rendre publiques les
-- negociations en cours serait un arbitrage de game design que personne n'a rendu. La policy de
-- lecture s'arrete donc exactement a la consigne : tout ce qui est CLOS est public, et les
-- propositions vivantes se lisent par les portes, qui savent qui est le maire emetteur et qui est
-- le gestionnaire destinataire. Aucun droit d'ECRITURE n'est accorde a personne.
--
-- AUCUN JUGEMENT DE JEU N'EST PORTE. Pas de colonne « favoritisme », pas de score de
-- clientelisme, pas d'indice. La table expose des faits -- qui, a qui, combien, quand, issue --
-- et l'interpretation appartient aux joueurs, a la presse et aux opposants.

CREATE TABLE IF NOT EXISTS public.subventions_municipales (
  id               text PRIMARY KEY,
  pays             text NOT NULL,
  ville            text NOT NULL,
  maire            text NOT NULL,
  famille          text NOT NULL REFERENCES public.subventions_familles(famille),
  beneficiaire     text NOT NULL,
  beneficiaire_nom text NOT NULL,
  montant          numeric NOT NULL CHECK (montant > 0 AND montant = trunc(montant)),
  statut           text NOT NULL DEFAULT 'proposee'
                     CHECK (statut IN ('proposee', 'acceptee', 'refusee', 'expiree')),
  jour             integer NOT NULL,
  jour_echeance    integer NOT NULL,
  clos_par         text,
  clos_le          timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now(),
  -- TROIS JOURS, ET LA REGLE EST DANS LA TABLE. Un delai recopie dans chaque porte finirait par
  -- differer d'une porte a l'autre ; ici aucune ligne ne peut exister avec un autre delai.
  CONSTRAINT subventions_delai_de_trois_jours CHECK (jour_echeance = jour + 3),
  -- LA COHERENCE DE L'ISSUE. Une acceptation ou un refus ont un auteur ; une expiration n'en a
  -- pas -- personne ne l'a decidee, le temps l'a close. Et une proposition en attente n'a ni
  -- auteur ni date de cloture. Ces trois cas sont les seuls possibles.
  CONSTRAINT subventions_cloture_coherente CHECK (
       (statut = 'proposee' AND clos_par IS NULL     AND clos_le IS NULL)
    OR (statut IN ('acceptee','refusee') AND clos_par IS NOT NULL AND clos_le IS NOT NULL)
    OR (statut = 'expiree'  AND clos_par IS NULL     AND clos_le IS NOT NULL))
);

CREATE UNIQUE INDEX IF NOT EXISTS subventions_une_proposition_identique_en_attente
  ON public.subventions_municipales (pays, ville, famille, beneficiaire, montant, jour)
  WHERE statut = 'proposee';

CREATE INDEX IF NOT EXISTS subventions_enveloppe_en_attente
  ON public.subventions_municipales (pays, ville) WHERE statut = 'proposee';

ALTER TABLE public.subventions_municipales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS subventions_archives_publiques ON public.subventions_municipales;
CREATE POLICY subventions_archives_publiques ON public.subventions_municipales
  FOR SELECT USING (statut <> 'proposee');

COMMENT ON TABLE public.subventions_municipales IS
  'Les propositions de subvention d''une commune a une organisation eligible de son territoire. '
  'La RESERVE n''est pas une colonne : c''est la somme des lignes encore `proposee`. Lecture '
  'publique des seules propositions CLOSES (arbitrage §5 : les trois issues laissent une trace '
  'publique) ; aucune ecriture cliente, les portes font tout.';

COMMENT ON COLUMN public.subventions_municipales.beneficiaire_nom IS
  'Le nom FIGE au moment de la proposition. Une archive publique doit rester lisible meme si '
  'l''organisation est renommee ou dissoute plus tard -- une archive qui change n''est pas une '
  'archive.';

COMMENT ON COLUMN public.subventions_municipales.clos_par IS
  'Qui a repondu. NULL pour une expiration : personne ne l''a decidee, le temps l''a close.';

DO $p$
DECLARE v integer; v_ok boolean; v_def text;
BEGIN
  -- P1 : LE DELAI DE TROIS JOURS EST INVIOLABLE. On tente une echeance a 5 jours : la base refuse.
  v_ok := false;
  BEGIN
    INSERT INTO public.subventions_municipales
      (id, pays, ville, maire, famille, beneficiaire, beneficiaire_nom, montant, jour, jour_echeance)
    VALUES ('zz-p1', 'republic', 'capitale', 'X', 'club_football', 'olympique-luthecia',
            'Olympique', 100, 10, 15);
  EXCEPTION WHEN others THEN v_ok := true; END;
  IF NOT v_ok THEN RAISE EXCEPTION 'P1 : une echeance hors des trois jours a ete acceptee'; END IF;

  -- P2 : UN MONTANT NUL OU NEGATIF EST REFUSE PAR LA TABLE, pas seulement par la porte.
  v_ok := false;
  BEGIN
    INSERT INTO public.subventions_municipales
      (id, pays, ville, maire, famille, beneficiaire, beneficiaire_nom, montant, jour, jour_echeance)
    VALUES ('zz-p2', 'republic', 'capitale', 'X', 'club_football', 'olympique-luthecia',
            'Olympique', -500, 10, 13);
  EXCEPTION WHEN others THEN v_ok := true; END;
  IF NOT v_ok THEN RAISE EXCEPTION 'P2 : un montant negatif a ete accepte'; END IF;

  -- P3 : UNE FAMILLE INCONNUE EST REFUSEE PAR LA CLE ETRANGERE. Un navigateur ne peut pas
  -- inventer une famille, meme si une porte etait un jour oubliee.
  v_ok := false;
  BEGIN
    INSERT INTO public.subventions_municipales
      (id, pays, ville, maire, famille, beneficiaire, beneficiaire_nom, montant, jour, jour_echeance)
    VALUES ('zz-p3', 'republic', 'capitale', 'X', 'confrerie_forgee', 'x', 'X', 100, 10, 13);
  EXCEPTION WHEN others THEN v_ok := true; END;
  IF NOT v_ok THEN RAISE EXCEPTION 'P3 : une famille inexistante a ete acceptee'; END IF;

  -- P4 : UNE ACCEPTATION SANS AUTEUR EST REFUSEE. L'issue et son auteur sont indissociables.
  v_ok := false;
  BEGIN
    INSERT INTO public.subventions_municipales
      (id, pays, ville, maire, famille, beneficiaire, beneficiaire_nom, montant, jour,
       jour_echeance, statut)
    VALUES ('zz-p4', 'republic', 'capitale', 'X', 'club_football', 'olympique-luthecia',
            'Olympique', 100, 10, 13, 'acceptee');
  EXCEPTION WHEN others THEN v_ok := true; END;
  IF NOT v_ok THEN RAISE EXCEPTION 'P4 : une acceptation sans auteur a ete acceptee'; END IF;

  -- P5 : L'ANTI-REJEU EST PARTIEL SUR `proposee`. Sans le WHERE, le maire ne pourrait jamais
  -- reproposer le meme montant apres un refus.
  SELECT pg_get_indexdef(i.indexrelid) INTO v_def
    FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
   WHERE c.relname = 'subventions_une_proposition_identique_en_attente';
  IF v_def IS NULL OR v_def NOT LIKE 'CREATE UNIQUE INDEX%' THEN
    RAISE EXCEPTION 'P5a : l''index d''anti-rejeu est absent ou non unique'; END IF;
  IF v_def NOT LIKE '%WHERE (statut = ''proposee''%' THEN
    RAISE EXCEPTION 'P5b : l''index n''est pas partiel -- il interdirait de reproposer : %', v_def;
  END IF;

  -- P6 : LA TABLE EST EN LECTURE SEULE POUR TOUT LE MONDE. Une seule policy, et elle est SELECT.
  SELECT count(*) INTO v FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'subventions_municipales';
  IF v <> 1 THEN RAISE EXCEPTION 'P6a : % policy au lieu d''une seule', v; END IF;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public'
              AND tablename = 'subventions_municipales' AND cmd <> 'SELECT') THEN
    RAISE EXCEPTION 'P6b : une policy autre que SELECT existe -- un client pourrait ecrire';
  END IF;
  IF has_table_privilege('authenticated', 'public.subventions_municipales', 'INSERT')
     OR has_table_privilege('authenticated', 'public.subventions_municipales', 'UPDATE')
     OR has_table_privilege('anon', 'public.subventions_municipales', 'INSERT') THEN
    RAISE EXCEPTION 'P6c : un client a un droit d''ecriture sur les propositions';
  END IF;

  -- P7 : la table est vide -- aucune des quatre tentatives ci-dessus n'a laisse de trace.
  SELECT count(*) INTO v FROM public.subventions_municipales;
  IF v <> 0 THEN RAISE EXCEPTION 'P7 : % ligne(s) de banc subsistent dans la table', v; END IF;

  RAISE NOTICE 'Table des propositions : 7 preuves structurelles vertes.';
END $p$;
