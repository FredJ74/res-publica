-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010174731 (UTC), nom `subventions_les_trois_resolveurs_d_une_famille_eligible`.
-- Le registre passe de 625 a 626 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 550aea5a681d9cfcf4c5ed1215e3f0d5, 11661 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CHAINE 7, §2 (SUITE) -- LES TROIS RESOLVEURS D'UNE FAMILLE ELIGIBLE
--
-- La table dit QUI est eligible ; ces fonctions disent OU l'entite est domiciliee, QUI peut
-- repondre pour elle et COMMENT sa caisse se credite -- la contrepartie exacte du verrou
-- fail-closed. `subvention_entites` est UNE seule fonction exprès : deux (une pour la liste, une
-- pour le verdict) auraient pu divergir, et l'interface aurait montre un beneficiaire que la porte
-- refuse. La territorialite est stricte et lue dans les COLONNES du miroir genere, jamais derivee
-- d'un identifiant par decoupage de texte. Fait du monde consigne : `presidents_clubs` est vide,
-- donc personne ne peut encore accepter une subvention -- la mecanique le rend visible.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHAINE 7, §2 (suite) -- LES TROIS RESOLVEURS (10 octobre 2026)
--
-- `subventions_familles` dit QUI est eligible. Ces fonctions disent OU il est domicilie, QUI
-- peut repondre pour lui et COMMENT sa caisse se credite. Elles sont la contrepartie exacte du
-- verrou fail-closed pose avec la table : ajouter une famille, c'est ajouter sa cle dans
-- `subvention_familles_resolues()` et UNE branche dans chacune des trois.
--
-- POURQUOI `subvention_entites` ET PAS DEUX FONCTIONS. On a besoin de deux choses -- lister les
-- beneficiaires d'une commune, et verifier la domiciliation d'un seul -- et il serait tentant
-- d'ecrire deux fonctions. Ce serait DEUX branches a maintenir par famille, donc une occasion de
-- divergence : la liste pourrait montrer un club que le verdict refuse. Une seule fonction
-- enumere les entites d'une famille ; la liste la filtre par commune, le verdict y cherche un id.
-- La domiciliation vue par l'interface est alors, par construction, celle que la porte applique.
--
-- LA TERRITORIALITE EST STRICTE, ET ELLE N'EST PAS DEDUITE D'UNE CHAINE. `clubs_football` porte
-- `pays` et `ville` en COLONNES (miroir genere par generer_clubs_football.py). On ne derive donc
-- jamais la ville d'un identifiant par decoupage de texte -- la lecon du chantier municipal.

CREATE OR REPLACE FUNCTION public.subvention_entites(p_famille text)
RETURNS TABLE (id text, nom text, pays text, ville text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  -- BRANCHE 1 SUR 3 POUR UNE NOUVELLE FAMILLE. L'absence de branche n'est pas un silence : une
  -- famille declaree eligible sans branche ici leve, et le trigger de `subventions_familles`
  -- interdit deja d'arriver dans cet etat.
  IF p_famille = 'club_football' THEN
    RETURN QUERY SELECT c.id, c.nom, c.pays, c.ville FROM public.clubs_football c;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM public.subventions_familles f
              WHERE f.famille = p_famille AND f.eligible) THEN
    RAISE EXCEPTION 'famille_sans_branche : % est declaree eligible mais n''a pas de branche '
      'd''enumeration -- etat impossible si le verrou de subventions_familles est en place',
      p_famille;
  END IF;
  RETURN;  -- famille non eligible : aucune entite, et c'est le comportement voulu
END $$;

CREATE OR REPLACE FUNCTION public.subvention_gestionnaire(p_famille text, p_id text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v text;
BEGIN
  -- BRANCHE 2 SUR 3. QUI PEUT REPONDRE POUR L'ORGANISATION -- et la reponse n'a PAS ete inventee
  -- ici : elle est lue dans l'existant. Pour un club du championnat, l'autorite sur la caisse est
  -- deja le PRESIDENT, et elle l'est partout ailleurs dans le jeu (`gerer_salaires_club` est
  -- « reserve au president »). Aucun grade n'est introduit, aucun titre n'est suppose commun a
  -- toutes les organisations : les `grades` des neuf familles sont des paliers d'anciennete, pas
  -- des fonctions, et aucune famille n'a de grade financier.
  --
  -- CE QUE CELA DONNE AUJOURD'HUI, ET IL FAUT LE DIRE : `presidents_clubs` est VIDE. Aucun club
  -- n'a de president, donc personne ne peut aujourd'hui accepter une subvention, et une
  -- proposition expirerait au bout de trois jours. Ce n'est pas un defaut de la mecanique, c'est
  -- l'etat du monde -- et la mecanique le rend visible au lieu de le masquer.
  --
  -- Le jour ou une famille d'ORGANISATION sera arbitree eligible, sa branche lira
  -- `organisations.data` selon la regle qui existe deja cote jeu : le tresorier s'il est pose,
  -- le chef sinon (arbitrage du 7 septembre 2026, `gestionnaireCaisseOrga`).
  IF p_famille = 'club_football' THEN
    SELECT nullif(trim(p.data->>'president'), '') INTO v
      FROM public.presidents_clubs p WHERE p.id = p_id;
    RETURN v;
  END IF;
  RETURN NULL;  -- pas de gestionnaire resolvable = personne ne peut repondre, fail-closed
END $$;

CREATE OR REPLACE FUNCTION public.subvention_caisse_crediter(
  p_famille text, p_id text, p_montant numeric, p_motif text, p_jour integer)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_data jsonb; v_hist jsonb; v_n integer; v_solde numeric;
BEGIN
  -- BRANCHE 3 SUR 3. LE CREDIT. Reservee au serveur : aucun GRANT n'est accorde, et une fonction
  -- neuve n'est appelable par personne depuis le registre 561. Elle n'est atteinte que par la
  -- porte de reponse, dans la meme transaction que le debit de l'enveloppe municipale.
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RAISE EXCEPTION 'montant_invalide : %', p_montant;
  END IF;

  IF p_famille = 'club_football' THEN
    -- FOR UPDATE : le credit lit puis reecrit un blob. Sans verrou, deux credits simultanes se
    -- perdraient l'un l'autre -- c'est la lecon du chantier des blobs.
    SELECT b.data INTO v_data FROM public.budgets_clubs b WHERE b.id = p_id FOR UPDATE;
    IF v_data IS NULL THEN
      RAISE EXCEPTION 'caisse_introuvable : le club % n''a pas de ligne budgets_clubs', p_id;
    END IF;

    v_solde := greatest(0, coalesce((v_data->>'caisse')::numeric, 0) + p_montant);

    -- L'HISTORIQUE SUIT LA CONVENTION DU JEU, A LA LETTRE : {jour, montant, motif} ajoute en
    -- queue, puis les 50 derniers conserves -- exactement ce que fait `crediterBudgetClub`
    -- (plateau-organisations-quetes.js). On ne cree pas une seconde convention d'historique.
    v_hist := coalesce(v_data->'historique', '[]'::jsonb)
              || jsonb_build_array(jsonb_build_object(
                   'jour', p_jour, 'montant', p_montant, 'motif', p_motif));
    v_n := jsonb_array_length(v_hist);
    IF v_n > 50 THEN
      SELECT jsonb_agg(e ORDER BY n) INTO v_hist
        FROM jsonb_array_elements(v_hist) WITH ORDINALITY t(e, n) WHERE n > v_n - 50;
    END IF;

    UPDATE public.budgets_clubs
       SET data = jsonb_set(jsonb_set(v_data, '{caisse}', to_jsonb(v_solde)),
                            '{historique}', v_hist),
           updated_at = now()
     WHERE id = p_id;
    RETURN v_solde;
  END IF;

  RAISE EXCEPTION 'famille_sans_branche_de_credit : %', p_famille;
END $$;

CREATE OR REPLACE FUNCTION public.subvention_organisations_locales(p_pays text, p_ville text)
RETURNS TABLE (famille text, libelle_famille text, organisation_id text, nom text,
               gestionnaire text, caisse_connue boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  -- LES BENEFICIAIRES POSSIBLES D'UNE COMMUNE. Le navigateur ne choisit pas cette liste, il la
  -- recoit : l'eligibilite vient de la table, la domiciliation des colonnes du miroir, et le
  -- gestionnaire du resolveur. `gestionnaire` peut etre NULL -- l'interface doit alors dire que
  -- personne ne pourrait repondre, plutot que de laisser le maire engager 2 PA pour rien.
  SELECT f.famille, f.libelle, e.id, e.nom,
         public.subvention_gestionnaire(f.famille, e.id),
         public.subvention_gestionnaire(f.famille, e.id) IS NOT NULL
    FROM public.subventions_familles f
    CROSS JOIN LATERAL public.subvention_entites(f.famille) e
   WHERE f.eligible AND e.pays = p_pays AND e.ville = p_ville
   ORDER BY f.famille, e.nom;
$$;

CREATE OR REPLACE FUNCTION public.subvention_beneficiaire_verdict(
  p_pays text, p_ville text, p_famille text, p_id text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_eligible boolean; v_pays text; v_ville text;
BEGIN
  -- LE VERDICT QUE LA PORTE APPLIQUERA. Il rend NULL quand tout va bien, et un MOTIF NOMME
  -- sinon. Quatre refus distincts, parce qu'« action impossible » n'apprend rien a un joueur.
  SELECT f.eligible INTO v_eligible FROM public.subventions_familles f WHERE f.famille = p_famille;
  IF v_eligible IS NULL THEN RETURN 'famille_inconnue'; END IF;
  IF NOT v_eligible THEN RETURN 'famille_non_eligible'; END IF;

  SELECT e.pays, e.ville INTO v_pays, v_ville
    FROM public.subvention_entites(p_famille) e WHERE e.id = p_id;
  IF v_pays IS NULL THEN RETURN 'beneficiaire_introuvable'; END IF;

  -- STRICTE TERRITORIALITE : le pays ET la ville. Un maire de Luthecia ne subventionne pas un
  -- club de Montrouge, et encore moins un club d'un autre empire.
  IF v_pays IS DISTINCT FROM p_pays OR v_ville IS DISTINCT FROM p_ville THEN
    RETURN 'beneficiaire_hors_commune';
  END IF;
  RETURN NULL;
END $$;

GRANT EXECUTE ON FUNCTION public.subvention_organisations_locales(text, text) TO authenticated;

DO $p$
DECLARE v integer; v_t text;
BEGIN
  -- P1 : les trois clubs de Republia sont enumeres, un par commune.
  SELECT count(*) INTO v FROM public.subvention_entites('club_football') e WHERE e.pays = 'republic';
  IF v <> 3 THEN RAISE EXCEPTION 'P1 : % club(s) republic au lieu de 3', v; END IF;

  -- P2 : UNE COMMUNE NE VOIT QUE SES PROPRES ELIGIBLES. C'est la territorialite, mesuree.
  SELECT count(*) INTO v FROM public.subvention_organisations_locales('republic', 'capitale');
  IF v <> 1 THEN RAISE EXCEPTION 'P2a : % eligible(s) a la capitale au lieu de 1', v; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.subvention_organisations_locales('republic', 'capitale') l
                  WHERE l.organisation_id = 'olympique-luthecia') THEN
    RAISE EXCEPTION 'P2b : l''eligible de la capitale n''est pas l''Olympique';
  END IF;

  -- P3 : UN MAIRE D'UNE AUTRE VILLE EST REFUSE, et le motif le dit.
  v_t := public.subvention_beneficiaire_verdict('republic', 'ville_a', 'club_football',
                                                'olympique-luthecia');
  IF v_t IS DISTINCT FROM 'beneficiaire_hors_commune' THEN
    RAISE EXCEPTION 'P3 : un club hors commune a recu le verdict %', coalesce(v_t, 'VALIDE'); END IF;

  -- P4 : LE MAIRE DE LA BONNE VILLE EST VALIDE.
  v_t := public.subvention_beneficiaire_verdict('republic', 'capitale', 'club_football',
                                                'olympique-luthecia');
  IF v_t IS NOT NULL THEN RAISE EXCEPTION 'P4 : le club local est refuse pour %', v_t; END IF;

  -- P5 : UNE ORGANISATION CRIMINELLE EST REFUSEE, et pas par hasard -- par sa famille.
  v_t := public.subvention_beneficiaire_verdict('republic', 'capitale', 'criminelle', 'peu-importe');
  IF v_t IS DISTINCT FROM 'famille_non_eligible' THEN
    RAISE EXCEPTION 'P5 : une criminelle a recu le verdict %', coalesce(v_t, 'VALIDE'); END IF;

  -- P6 : une famille inventee par un navigateur est refusee comme INCONNUE.
  v_t := public.subvention_beneficiaire_verdict('republic', 'capitale', 'confrerie_forgee', 'x');
  IF v_t IS DISTINCT FROM 'famille_inconnue' THEN
    RAISE EXCEPTION 'P6 : une famille forgee a recu le verdict %', coalesce(v_t, 'VALIDE'); END IF;

  -- P7 : AUCUN CLUB N'A DE GESTIONNAIRE AUJOURD'HUI. Fait du monde, consigne : `presidents_clubs`
  -- est vide. Si cette preuve tombe un jour, c'est que des presidents ont ete elus -- tant mieux.
  SELECT count(*) INTO v FROM public.subvention_organisations_locales('republic', 'capitale') l
   WHERE l.caisse_connue;
  IF v <> 0 THEN
    RAISE NOTICE 'P7 : % club(s) ont desormais un president -- l''etat du monde a change', v;
  END IF;

  -- P8 : le credit n'est appelable par AUCUN client.
  IF has_function_privilege('authenticated',
       'public.subvention_caisse_crediter(text,text,numeric,text,integer)', 'EXECUTE')
     OR has_function_privilege('anon',
       'public.subvention_caisse_crediter(text,text,numeric,text,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P8 : un client peut crediter la caisse d''une organisation directement';
  END IF;

  RAISE NOTICE 'Trois resolveurs : 8 preuves structurelles vertes.';
END $p$;
