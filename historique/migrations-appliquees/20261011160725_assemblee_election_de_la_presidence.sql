-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011160725 (UTC), nom `assemblee_election_de_la_presidence`.
-- Le registre passe de 655 a 656 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 eb413d515338e145bd94ceeb16483d40, 37538 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- L'ELECTION DU PRESIDENT DE L'ASSEMBLEE
--
-- La deuxieme passe avait laisse cette porte fermee, faute de trois decisions. Elles sont
-- rendues : AUCUNE CANDIDATURE -- les neuf deputes sont eligibles d'office, PJ comme PNJ, et le
-- cas « aucun candidat » n'existe donc pas ; LES DEPUTES PNJ S'ABSTIENNENT TOUJOURS -- ils
-- peuvent recevoir des voix et etre elus, mais ne deposent aucun bulletin, et aucun vote PNJ
-- n'est fabrique pour simuler une majorite ; EN CAS D'EGALITE EN TETE, la courte paille, tiree
-- PAR LE SERVEUR et enregistree definitivement.
-- NEUF DEPUTES, PAS NEUF PLUS UN. `assemblee_presidence_eligibles` derive les neuf sieges et
-- rien d'autre ; le scrutin comme le depouillement refusent tout nom qui n'en vient pas. Un
-- dixieme parlementaire ne peut donc pas devenir President, meme par erreur.
-- ET ELLE REMPLIT LA SEULE LIGNE QUE LA SEANCE REGARDE : `postes_attribues`. Les pouvoirs de
-- seance, de discipline, de report et de suspension suivent donc le titulaire REEL,
-- immediatement, sans qu'aucun code de seance ne change. L'ancien President les perd dans la
-- meme transaction, et garde son siege : son mandat de depute ne vient pas d'ici.
-- ZERO VOTANT EST TRAITE PAR LA MEME REGLE, sans exception ajoutee : les neuf sont a egalite a
-- zero voix et la courte paille les departage tous. C'est la consequence mecanique des regles
-- arbitrees, pas une regle neuve -- et l'alternative, une presidence vacante, aurait rendu la
-- seance entierement muette puisque tout y passe par le President.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- L'ELECTION DU PRESIDENT DE L'ASSEMBLEE (11 octobre 2026)
-- =================================================================================================
-- LA DEUXIEME PASSE AVAIT LAISSE CETTE PORTE FERMEE, faute de trois decisions. Elles sont rendues :
--   . AUCUNE CANDIDATURE. Les neuf deputes sont automatiquement eligibles -- PJ comme PNJ. Il n'y
--     a donc rien a deposer, rien a enregistrer, et le cas « aucun candidat » n'existe pas.
--   . LES DEPUTES PNJ S'ABSTIENNENT TOUJOURS. Ils sont eligibles, ils peuvent recevoir des voix et
--     etre elus par les voix des PJ -- mais ils ne deposent aucun bulletin. AUCUN vote PNJ n'est
--     fabrique pour simuler une majorite, et aucun quorum artificiel n'est invente : si un seul
--     depute PJ vote, sa voix suffit.
--   . EN CAS D'EGALITE EN TETE, la courte paille, tiree PAR LE SERVEUR.
--
-- NEUF DEPUTES, PAS NEUF PLUS UN. La presidence n'est pas un dixieme siege : c'est une fonction
-- portee par l'un des neuf. `assemblee_presidence_eligibles` le dit structurellement -- elle derive
-- les neuf sieges et rien d'autre --, et le scrutin comme le depouillement refusent tout nom qui
-- n'en vient pas. Un dixieme parlementaire ne peut donc pas devenir President, meme par erreur.
--
-- ET ELLE REMPLIT LA SEULE LIGNE QUE LA SEANCE REGARDE. Toute la deuxieme passe est isolee derriere
-- `assemblee_president(pays)`, qui lit `postes_attribues`. Le depouillement ecrit cette ligne : les
-- pouvoirs de seance, de discipline, de report et de suspension suivent donc le titulaire REEL,
-- immediatement, sans qu'aucun code de seance ne change. L'ancien President les perd dans la meme
-- transaction, et garde son siege : son mandat de depute ne vient pas d'ici.
--
-- LE CALENDRIER EST CELUI DE L'ARBITRAGE, ET UN SEUL : convocation le lundi a 00h01, scrutin
-- ouvert jusqu'au lundi 23h00, resultat a 23h00, un seul tour. En dates CALENDAIRES de Paris,
-- jamais en +24 h : un passage a l'heure d'hiver ne doit pas deplacer la cloture.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. LES NEUF ELIGIBLES -- LE POINT DE VERITE DE LA COMPOSITION
-- -------------------------------------------------------------------------------------------------
-- NEUF LIGNES, TROIS PAR VILLE, TOUJOURS. Un siege est tenu par son depute JOUEUR s'il y en a un,
-- sinon par le PNJ qui l'occupe -- c'est le resolveur `assemblee_occupation_sieges`, deja en place,
-- qui en decide. Il n'y a aucune dixieme entree possible : la table des sieges en porte neuf.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_eligibles(p_pays text)
 RETURNS TABLE(depute text, ville text, rang integer, est_pnj boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(o.pj_nom, o.pnj_nom), o.city, o.rang, o.est_pnj
    FROM public.assemblee_occupation_sieges(p_pays) o
   ORDER BY o.city, o.rang;
$function$;

COMMENT ON FUNCTION public.assemblee_presidence_eligibles(text) IS
  'Les NEUF deputes eligibles a la presidence de l Assemblee -- trois par ville, jamais dix. Un siege est represente par son depute JOUEUR s il y en a un, sinon par le PNJ qui l occupe. La presidence est une fonction portee par l un des neuf, pas un siege supplementaire : le scrutin et le depouillement refusent tout nom qui ne vient pas de cette liste (arbitrage du 11 octobre 2026).';

-- LE PROCHAIN LUNDI 23 HEURES DE PARIS, strictement dans le futur. En dates calendaires : un
-- changement d'heure ne doit pas deplacer la cloture d'une heure.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_prochaine_cloture()
 RETURNS timestamptz
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_local timestamp; v_cible timestamp;
BEGIN
  v_local := now() AT TIME ZONE 'Europe/Paris';
  -- le lundi de la semaine courante a 23h00 (isodow : 1 = lundi)
  v_cible := date_trunc('day', v_local)
             - make_interval(days => extract(isodow from v_local)::integer - 1)
             + interval '23 hours';
  IF v_cible <= v_local THEN v_cible := v_cible + interval '7 days'; END IF;
  RETURN v_cible AT TIME ZONE 'Europe/Paris';
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 2. LE SCRUTIN, LES BULLETINS, ET CE QUE CHAQUE JOUEUR A DEJA VU
-- -------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.assemblee_presidence_scrutins (
  id            text        PRIMARY KEY,
  pays          text        NOT NULL,
  cause         text        NOT NULL,
  ouvert_le     timestamptz NOT NULL DEFAULT clock_timestamp(),
  cloture_ts    timestamptz NOT NULL,
  eligibles     jsonb       NOT NULL,
  statut        text        NOT NULL DEFAULT 'ouvert',
  elu           text,
  elu_est_pnj   boolean,
  egalite       jsonb,
  decompte      jsonb,
  president_sortant text,
  chronique_id  text,
  clos_le       timestamptz,
  CONSTRAINT presidence_cause_connue CHECK (cause = ANY (ARRAY['renouvellement','deux_boycotts'])),
  CONSTRAINT presidence_statut_connu CHECK (statut = ANY (ARRAY['ouvert','clos'])),
  -- UN SCRUTIN CLOS A UN ELU, UN SCRUTIN OUVERT N'EN A PAS. Il n'existe pas d'etat intermediaire :
  -- le depouillement ecrit les deux ensemble ou rien.
  CONSTRAINT presidence_clos_coherent CHECK (
    (statut = 'ouvert' AND elu IS NULL AND clos_le IS NULL AND decompte IS NULL)
 OR (statut = 'clos'   AND elu IS NOT NULL AND clos_le IS NOT NULL AND decompte IS NOT NULL))
);

-- UN SEUL SCRUTIN OUVERT PAR PAYS. Deux convocations concurrentes ne peuvent pas ouvrir deux
-- elections : la seconde viole l'index et sa transaction entiere tombe.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_presidence_un_seul_ouvert
  ON public.assemblee_presidence_scrutins (pays) WHERE statut = 'ouvert';

COMMENT ON TABLE public.assemblee_presidence_scrutins IS
  'Les elections du President de l Assemblee. `eligibles` fige les NEUF deputes au moment de l ouverture -- la presidence n est jamais un dixieme siege. `egalite` porte les noms ex aequo en tete quand il a fallu tirer a la courte paille, et `elu` le vainqueur tire PAR LE SERVEUR : le navigateur ne choisit jamais, il rejoue une animation dont le resultat est deja ecrit (arbitrage du 11 octobre 2026).';

CREATE TABLE IF NOT EXISTS public.assemblee_presidence_bulletins (
  scrutin_id text        NOT NULL REFERENCES public.assemblee_presidence_scrutins(id),
  votant     text        NOT NULL,
  pour       text        NOT NULL,
  vote_le    timestamptz NOT NULL DEFAULT clock_timestamp(),
  requete    text,
  PRIMARY KEY (scrutin_id, votant)
);

-- UN BULLETIN PAR DEPUTE, ET C'EST LA CLE PRIMAIRE QUI LE DIT. Le double vote est refuse, pas
-- ecrase : une voix deposee ne se reprend pas.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_presidence_une_requete
  ON public.assemblee_presidence_bulletins (requete) WHERE requete IS NOT NULL;

COMMENT ON TABLE public.assemblee_presidence_bulletins IS
  'Les bulletins de l election presidentielle. Seuls les deputes JOUEURS y figurent : les neuf PNJ sont eligibles mais s abstiennent toujours, et aucun vote PNJ n est fabrique pour simuler une majorite. Un depute peut voter pour n importe lequel des neuf, y compris lui-meme et y compris un PNJ.';

-- CE QUE CHAQUE JOUEUR A DEJA VU. L'etat « tirage vu » est une verite serveur : sans elle, un
-- joueur reverrait l'annonce a chaque visite, ou la manquerait pour avoir ferme l'onglet.
CREATE TABLE IF NOT EXISTS public.assemblee_presidence_tirage_vu (
  scrutin_id text        NOT NULL REFERENCES public.assemblee_presidence_scrutins(id),
  personnage text        NOT NULL,
  vu_le      timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (scrutin_id, personnage)
);

-- LES ELECTIONS EXCEPTIONNELLES DUES. Un deuxieme episode de boycott distinct sous une meme
-- presidence remet la presidence en jeu : on inscrit ici que l'election est DUE, et la convocation
-- du lundi la prend. On n'ouvre pas le scrutin dans la transaction d'une protestation -- un acte de
-- joueur ne doit pas declencher une election au milieu de son propre clic.
CREATE TABLE IF NOT EXISTS public.assemblee_presidence_dues (
  id         text        PRIMARY KEY,
  pays       text        NOT NULL,
  cause      text        NOT NULL,
  du_le      timestamptz NOT NULL DEFAULT clock_timestamp(),
  episode_id text,
  scrutin_id text        REFERENCES public.assemblee_presidence_scrutins(id),
  honore_le  timestamptz,
  CONSTRAINT presidence_due_cause_connue CHECK (cause = ANY (ARRAY['renouvellement','deux_boycotts'])),
  CONSTRAINT presidence_due_honoree_coherente CHECK (
    (honore_le IS NULL AND scrutin_id IS NULL) OR (honore_le IS NOT NULL AND scrutin_id IS NOT NULL))
);

-- UNE SEULE ELECTION EXCEPTIONNELLE EN ATTENTE PAR PAYS. Un troisieme, un quatrieme episode
-- n'empilent pas des elections : c'est la presidence qui est en jeu, une fois.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_presidence_une_seule_due
  ON public.assemblee_presidence_dues (pays) WHERE honore_le IS NULL;

COMMENT ON TABLE public.assemblee_presidence_dues IS
  'Les elections presidentielles exceptionnelles en attente de convocation. Un DEUXIEME episode de boycott distinct sous une meme presidence inscrit une ligne ici ; la convocation du lundi 00h01 l ouvre, sans attendre le renouvellement general. Le CALENDRIER EXACT de cette election exceptionnelle est le seul que l arbitrage nomme -- lundi 00h01 / lundi 23h00 -- et il est donc reutilise tel quel : aucun calendrier neuf n a ete invente.';

ALTER TABLE public.assemblee_presidence_scrutins  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_presidence_bulletins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_presidence_tirage_vu ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_presidence_dues      ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------------------------------
-- 3. LA CONVOCATION
-- -------------------------------------------------------------------------------------------------
-- RESERVEE AU SERVEUR. Un joueur qui pourrait convoquer une election la convoquerait au moment qui
-- l'arrange.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_convoquer(p_pays text, p_cause text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text; v_cloture timestamptz; v_elig jsonb; v_pres text; v_due record; v_n integer := 0;
  v_d record; v_heure text;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF coalesce(p_cause,'') NOT IN ('renouvellement','deux_boycotts') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_inconnue');
  END IF;

  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_scrutins
              WHERE pays = p_pays AND statut = 'ouvert') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_deja_ouvert');
  END IF;

  -- LES NEUF, FIGES A L'OUVERTURE. Si un siege change de main pendant la semaine, le scrutin garde
  -- la liste devant laquelle les deputes ont vote : on ne deplace pas les regles en cours de route.
  SELECT coalesce(jsonb_agg(jsonb_build_object('depute', e.depute, 'ville', e.ville,
                                               'rang', e.rang, 'est_pnj', e.est_pnj)
                            ORDER BY e.ville, e.rang), '[]'::jsonb)
    INTO v_elig FROM public.assemblee_presidence_eligibles(p_pays) e;
  IF jsonb_array_length(v_elig) <> 9 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'composition_incomplete',
                              'sieges', jsonb_array_length(v_elig));
  END IF;

  v_cloture := public.assemblee_presidence_prochaine_cloture();
  v_pres := public.assemblee_president(p_pays);
  v_id := 'presidence-' || p_pays || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISS');

  INSERT INTO public.assemblee_presidence_scrutins
    (id, pays, cause, cloture_ts, eligibles, president_sortant)
  VALUES (v_id, p_pays, p_cause, v_cloture, v_elig, v_pres);

  -- L'ELECTION EXCEPTIONNELLE EN ATTENTE EST HONOREE PAR CELLE-CI, quelle que soit sa cause : la
  -- presidence vient d'etre remise en jeu, il n'y a plus rien a rattraper.
  UPDATE public.assemblee_presidence_dues
     SET honore_le = clock_timestamp(), scrutin_id = v_id
   WHERE pays = p_pays AND honore_le IS NULL;

  -- LE COURRIER DE CONVOCATION. Il part aux neuf -- mais seuls les deputes JOUEURS ont une boite :
  -- les PNJ n'ont aucune fiche de personnage, et leur ecrire serait ecrire a personne.
  v_heure := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  FOR v_d IN SELECT e.depute, e.ville FROM public.assemblee_presidence_eligibles(p_pays) e
              WHERE NOT e.est_pnj
  LOOP
    PERFORM public.mail_systeme_poser_interne(
      'Secrétariat de l''Assemblée nationale', v_d.depute,
      'Convocation — élection du Président de l''Assemblée',
      'L''Assemblée nationale élit son Président. Les neuf députés sont éligibles : vous pouvez '
      || 'voter pour n''importe lequel d''entre eux, y compris vous-même. Le scrutin est ouvert '
      || 'jusqu''au lundi 23h00, à un seul tour, et le décompte est visible pendant toute sa '
      || 'durée. En cas d''égalité en tête, le départage se fera à la courte paille.',
      v_heure);
    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'scrutin', v_id, 'cause', p_cause,
                            'cloture_ts', v_cloture, 'convoques', v_n,
                            'eligibles', jsonb_array_length(v_elig));
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_presidence_convoquer(text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_presidence_convoquer(text,text) FROM anon;
REVOKE ALL ON FUNCTION public.assemblee_presidence_convoquer(text,text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_presidence_convoquer(text,text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 4. LE VOTE
-- -------------------------------------------------------------------------------------------------
-- UN DEPUTE JOUEUR, UNE VOIX, POUR L'UN DES NEUF. Il peut voter pour lui-meme, pour un autre PJ, ou
-- pour un PNJ : les neuf sont eligibles sans exception. AUCUNE CANDIDATURE N'EST EXIGEE, parce
-- qu'il n'y en a pas.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_voter(p_pour text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; s record; d record; v_n integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUTE ECRITURE : une reponse perdue et rejouee ne depose pas deux bulletins.
  SELECT * INTO d FROM public.assemblee_presidence_bulletins WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'pour', d.pour);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;

  SELECT * INTO s FROM public.assemblee_presidence_scrutins
   WHERE pays = v_pays AND statut = 'ouvert' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_scrutin_ouvert'); END IF;
  -- L'HEURE DU SERVEUR, ET ELLE SEULE. Un bulletin arrive apres 23h00 est refuse meme si le
  -- depouillement n'a pas encore tourne.
  IF now() >= s.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos', 'cloture_ts', s.cloture_ts); END IF;

  -- LE NOM VOTE DOIT ETRE L'UN DES NEUF FIGES A L'OUVERTURE. C'est ce qui interdit d'elire un
  -- dixieme parlementaire, ou quelqu'un qui n'est pas depute du tout.
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(s.eligibles) e
                  WHERE e ->> 'depute' = p_pour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_eligible', 'pour', p_pour); END IF;

  -- UN SEUL BULLETIN. Le double vote est REFUSE, et la voix deja deposee reste celle qui compte.
  IF EXISTS (SELECT 1 FROM public.assemblee_presidence_bulletins
              WHERE scrutin_id = s.id AND votant = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote'); END IF;

  INSERT INTO public.assemblee_presidence_bulletins (scrutin_id, votant, pour, requete)
  VALUES (s.id, v_moi, p_pour, p_requete);

  SELECT count(*) INTO v_n FROM public.assemblee_presidence_bulletins WHERE scrutin_id = s.id;
  RETURN jsonb_build_object('ok', true, 'scrutin', s.id, 'pour', p_pour, 'bulletins', v_n);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 5. LE DEPOUILLEMENT ET LA COURTE PAILLE
-- -------------------------------------------------------------------------------------------------
-- A 23 HEURES, UNE SEULE FOIS. Le resultat est determine et enregistre DEFINITIVEMENT ici : le
-- navigateur ne tire jamais, il rejoue une animation dont la fin est deja ecrite en base.
--
-- EGALITE EN TETE : seuls les ex aequo EN TETE participent au tirage. Un depute a trois voix quand
-- deux autres en ont cinq ne tire pas.
--
-- ET LE CAS DE ZERO VOTANT EST TRAITE PAR LA MEME REGLE, sans exception ajoutee : si aucun depute
-- joueur n'a vote -- il peut n'y en avoir aucun --, les neuf sont a egalite a zero voix, et la
-- courte paille les departage tous les neuf. C'est la CONSEQUENCE MECANIQUE des regles arbitrees,
-- pas une regle neuve : « egalite en tete => tirage ». L'alternative -- une presidence vacante --
-- aurait rendu la seance entierement muette, puisque tout y passe par le President.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_depouiller(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record; v_max integer; v_tete jsonb; v_elu text; v_pnj boolean;
  v_decompte jsonb; v_chron text; v_heure text; v_d record; v_sortant text;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;

  SELECT * INTO s FROM public.assemblee_presidence_scrutins
   WHERE pays = p_pays AND statut = 'ouvert' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'depouille', false, 'raison', 'aucun_scrutin_ouvert');
  END IF;
  IF now() < s.cloture_ts THEN
    RETURN jsonb_build_object('ok', true, 'depouille', false, 'raison', 'pas_encore_echu',
                              'cloture_ts', s.cloture_ts);
  END IF;

  -- LE DECOMPTE PORTE SUR LES NEUF, zero voix comprise : un eligible sans voix doit apparaitre,
  -- sinon l'egalite a zero serait invisible.
  SELECT coalesce(jsonb_agg(jsonb_build_object('depute', x.depute, 'voix', x.voix)
                            ORDER BY x.voix DESC, x.depute), '[]'::jsonb)
    INTO v_decompte
    FROM (SELECT e ->> 'depute' AS depute,
                 (SELECT count(*) FROM public.assemblee_presidence_bulletins b
                   WHERE b.scrutin_id = s.id AND b.pour = e ->> 'depute')::integer AS voix
            FROM jsonb_array_elements(s.eligibles) e) x;

  SELECT max((d ->> 'voix')::integer) INTO v_max FROM jsonb_array_elements(v_decompte) d;
  SELECT coalesce(jsonb_agg(d ->> 'depute' ORDER BY d ->> 'depute'), '[]'::jsonb)
    INTO v_tete FROM jsonb_array_elements(v_decompte) d WHERE (d ->> 'voix')::integer = v_max;

  IF jsonb_array_length(v_tete) = 1 THEN
    v_elu := v_tete ->> 0;
    v_tete := NULL;                       -- aucune egalite : rien a tirer, rien a rejouer
  ELSE
    -- LA COURTE PAILLE, TIREE PAR LE SERVEUR. Le resultat est ecrit ici et ne bougera plus.
    SELECT t INTO v_elu FROM jsonb_array_elements_text(v_tete) t ORDER BY random() LIMIT 1;
  END IF;

  SELECT e.est_pnj INTO v_pnj FROM public.assemblee_presidence_eligibles(p_pays) e
   WHERE e.depute = v_elu;
  v_sortant := public.assemblee_president(p_pays);
  v_chron := 'chronique-presidence-' || s.id;

  -- LA PROCLAMATION : le registre des postes nommes change de titulaire. C'est la SEULE ligne que
  -- la seance regarde -- les pouvoirs suivent donc immediatement, et l'ancien President les perd
  -- dans la meme transaction. Son siege de depute, lui, ne vient pas d'ici et reste intact.
  DELETE FROM public.postes_attribues
   WHERE country = p_pays AND poste_id = 'president_assemblee' AND city IS NULL;
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES ('presidence-assemblee-' || p_pays, p_pays, 'president_assemblee', NULL, v_elu,
          'election_assemblee');

  UPDATE public.assemblee_presidence_scrutins
     SET statut = 'clos', elu = v_elu, elu_est_pnj = coalesce(v_pnj, true),
         egalite = v_tete, decompte = v_decompte,
         clos_le = clock_timestamp(), chronique_id = v_chron
   WHERE id = s.id;

  -- LA TRACE PUBLIQUE EST FACTUELLE : qui a ete elu, avec combien de voix, et s'il a fallu tirer.
  -- Aucune appreciation, aucun commentaire.
  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, p_pays, 'assemblee_presidence', 'capitale',
          jsonb_build_array(v_elu) || coalesce(jsonb_build_array(v_sortant), '[]'::jsonb),
          v_elu || ' est elu President de l''Assemblee nationale'
          || CASE WHEN v_tete IS NULL THEN '.' ELSE ' apres un tirage a la courte paille.' END,
          jsonb_build_object('scrutin', s.id, 'cause', s.cause, 'elu', v_elu,
                             'voix', v_max, 'decompte', v_decompte, 'egalite', v_tete,
                             'president_sortant', v_sortant),
          s.id);

  -- LE RESULTAT PAR COURRIER AUX DEPUTES JOUEURS. Les PNJ n'ont pas de boite.
  v_heure := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  FOR v_d IN SELECT e.depute FROM public.assemblee_presidence_eligibles(p_pays) e
              WHERE NOT e.est_pnj
  LOOP
    PERFORM public.mail_systeme_poser_interne(
      'Secrétariat de l''Assemblée nationale', v_d.depute,
      'Résultat — élection du Président de l''Assemblée',
      v_elu || ' est élu Président de l''Assemblée nationale avec ' || v_max || ' voix'
      || CASE WHEN v_tete IS NULL THEN '.'
              ELSE ', après un départage à la courte paille entre '
                   || jsonb_array_length(v_tete) || ' députés à égalité.' END,
      v_heure);
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'depouille', true, 'scrutin', s.id,
                            'elu', v_elu, 'elu_est_pnj', coalesce(v_pnj, true),
                            'voix', v_max, 'egalite', v_tete, 'decompte', v_decompte,
                            'president_sortant', v_sortant);
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_presidence_depouiller(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_presidence_depouiller(text) FROM anon;
REVOKE ALL ON FUNCTION public.assemblee_presidence_depouiller(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_presidence_depouiller(text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 6. L'ETAT DU SCRUTIN, ET CE QU'IL RESTE A MONTRER AU JOUEUR
-- -------------------------------------------------------------------------------------------------
-- LE DECOMPTE EST VISIBLE PENDANT TOUTE LA DUREE DU SCRUTIN, comme l'arbitrage l'exige. Il est
-- public dans l'enceinte : qui a vote pour qui n'est PAS rendu -- seul le nombre de voix l'est, et
-- chacun voit son propre bulletin.
--
-- `a_revoir` PORTE LA REVELATION DIFFEREE : le dernier scrutin clos PAR TIRAGE que CE joueur n'a
-- jamais vu. Le resultat ne depend jamais de sa presence -- il est deja ecrit -- mais il a le droit
-- d'assister au tirage une fois.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_etat()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; s record; v_depute boolean; v_revoir jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_depute := public.assemblee_est_depute(v_pays, v_moi);

  SELECT * INTO s FROM public.assemblee_presidence_scrutins
   WHERE pays = v_pays AND statut = 'ouvert';

  SELECT to_jsonb(z) INTO v_revoir FROM (
    SELECT c.id, c.elu, c.egalite, c.decompte, c.cause, c.clos_le, c.eligibles
      FROM public.assemblee_presidence_scrutins c
     WHERE c.pays = v_pays AND c.statut = 'clos' AND c.egalite IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_tirage_vu v
                        WHERE v.scrutin_id = c.id AND v.personnage = v_moi)
     ORDER BY c.clos_le DESC LIMIT 1) z;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'je_suis_depute', v_depute,
    'president', public.assemblee_president(v_pays),
    'eligibles', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', e.depute,
                           'ville', e.ville, 'rang', e.rang, 'est_pnj', e.est_pnj)
                         ORDER BY e.ville, e.rang), '[]'::jsonb)
                    FROM public.assemblee_presidence_eligibles(v_pays) e),
    'scrutin', CASE WHEN s.id IS NULL THEN NULL ELSE jsonb_build_object(
        'id', s.id, 'cause', s.cause, 'ouvert_le', s.ouvert_le, 'cloture_ts', s.cloture_ts,
        'eligibles', s.eligibles,
        'mon_bulletin', (SELECT b.pour FROM public.assemblee_presidence_bulletins b
                          WHERE b.scrutin_id = s.id AND b.votant = v_moi),
        -- LE DECOMPTE EN DIRECT, zero voix comprise : sans les zeros, l'egalite serait illisible.
        'decompte', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', x.depute, 'voix', x.voix)
                             ORDER BY x.voix DESC, x.depute), '[]'::jsonb)
                       FROM (SELECT e ->> 'depute' AS depute,
                                    (SELECT count(*) FROM public.assemblee_presidence_bulletins b
                                      WHERE b.scrutin_id = s.id AND b.pour = e ->> 'depute')::integer AS voix
                               FROM jsonb_array_elements(s.eligibles) e) x),
        'bulletins', (SELECT count(*) FROM public.assemblee_presidence_bulletins b
                       WHERE b.scrutin_id = s.id)) END,
    'a_revoir', v_revoir,
    -- UNE ELECTION EXCEPTIONNELLE EST-ELLE DUE ? Un fait, pas une menace.
    'election_due', (SELECT to_jsonb(y) FROM (
        SELECT u.cause, u.du_le FROM public.assemblee_presidence_dues u
         WHERE u.pays = v_pays AND u.honore_le IS NULL LIMIT 1) y));
END;
$function$;

-- CE JOUEUR A VU LE TIRAGE. Une seule fois par scrutin : l'etat est serveur, donc il survit a un
-- rafraichissement, a un changement de machine, et a un onglet ferme trop vite.
CREATE OR REPLACE FUNCTION public.assemblee_presidence_tirage_vu(p_scrutin_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_scrutins
                  WHERE id = p_scrutin_id AND statut = 'clos') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_inconnu'); END IF;

  INSERT INTO public.assemblee_presidence_tirage_vu (scrutin_id, personnage)
  VALUES (p_scrutin_id, v_moi)
  ON CONFLICT (scrutin_id, personnage) DO NOTHING;
  RETURN jsonb_build_object('ok', true, 'scrutin', p_scrutin_id);
END;
$function$;

DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'assemblee_presidence_eligibles(text)', 'assemblee_presidence_prochaine_cloture()',
    'assemblee_presidence_voter(text,text)', 'assemblee_presidence_etat()',
    'assemblee_presidence_tirage_vu(text)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC', f);
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO service_role', f);
  END LOOP;
END $$;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer; v_src text; v_c timestamptz; v_l timestamp;
BEGIN
  -- P1 : LES QUATRE TABLES DU SCRUTIN SONT FERMEES AU CLIENT. Un navigateur qui pourrait ecrire un
  -- bulletin elirait qui il veut.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relrowsecurity AND c.relname IN
     ('assemblee_presidence_scrutins','assemblee_presidence_bulletins',
      'assemblee_presidence_tirage_vu','assemblee_presidence_dues');
  IF v_n <> 4 THEN RAISE EXCEPTION 'P1a : % tables de scrutin sous RLS au lieu de 4', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_policies WHERE schemaname = 'public' AND tablename IN
     ('assemblee_presidence_scrutins','assemblee_presidence_bulletins',
      'assemblee_presidence_tirage_vu','assemblee_presidence_dues');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1b : % policy sur les tables de scrutin', v_n; END IF;

  -- P2 : NEUF ELIGIBLES, TROIS PAR VILLE. La presidence n'est pas un dixieme siege, et cette
  -- preuve est la pour le dire a chaque migration future.
  SELECT count(*) INTO v_n FROM public.assemblee_presidence_eligibles('republic');
  IF v_n <> 9 THEN RAISE EXCEPTION 'P2a : % eligibles au lieu de 9', v_n; END IF;
  SELECT count(*) INTO v_n FROM (
    SELECT e.ville, count(*) AS c FROM public.assemblee_presidence_eligibles('republic') e
     GROUP BY e.ville HAVING count(*) <> 3) z;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2b : une ville n a pas exactement 3 eligibles'; END IF;

  -- P3 : UN SEUL SCRUTIN OUVERT, UN SEUL BULLETIN PAR DEPUTE, UNE SEULE ELECTION DUE.
  SELECT count(*) INTO v_n FROM pg_indexes WHERE schemaname = 'public' AND indexdef LIKE '%UNIQUE%'
    AND indexname IN ('assemblee_presidence_un_seul_ouvert', 'assemblee_presidence_une_requete',
                      'assemblee_presidence_une_seule_due');
  IF v_n <> 3 THEN RAISE EXCEPTION 'P3 : % index d unicite du scrutin au lieu de 3', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'assemblee_presidence_bulletins' AND c.contype = 'p'
     AND pg_get_constraintdef(c.oid) = 'PRIMARY KEY (scrutin_id, votant)';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3b : un depute pourrait deposer deux bulletins'; END IF;

  -- P4 : LE VOTE REFUSE UN NOM QUI N'EST PAS L'UN DES NEUF, ET REFUSE LE SECOND BULLETIN.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_voter';
  IF v_src NOT LIKE '%pas_eligible%' OR v_src NOT LIKE '%deja_vote%'
     OR v_src NOT LIKE '%s.eligibles%' THEN
    RAISE EXCEPTION 'P4 : le vote ne borne pas les noms eligibles ou n interdit pas le double vote';
  END IF;

  -- P5 : AUCUN BULLETIN N'EST FABRIQUE POUR UN PNJ. Ni la convocation ni le depouillement
  -- n'inserent de bulletin : seule la porte de vote le fait, et elle exige mon_personnage().
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_presidence_convoquer','assemblee_presidence_depouiller')
     AND p.prosrc LIKE '%INSERT INTO public.assemblee_presidence_bulletins%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 : une porte serveur fabrique des bulletins'; END IF;

  -- P6 : LE TIRAGE EST SERVEUR, ET IL NE PORTE QUE SUR LES EX AEQUO EN TETE.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_depouiller';
  IF v_src NOT LIKE '%ORDER BY random()%' THEN
    RAISE EXCEPTION 'P6a : le tirage n est pas fait par le serveur';
  END IF;
  IF v_src NOT LIKE '%= v_max%' THEN
    RAISE EXCEPTION 'P6b : le tirage ne se borne pas aux ex aequo en tete';
  END IF;

  -- P7 : LE DEPOUILLEMENT ECRIT LE REGISTRE DES POSTES, et c'est par la que les pouvoirs changent
  -- de main. S'il ecrivait ailleurs, l'ancien President garderait ses prerogatives.
  IF v_src NOT LIKE '%INSERT INTO public.postes_attribues%'
     OR v_src NOT LIKE '%DELETE FROM public.postes_attribues%' THEN
    RAISE EXCEPTION 'P7 : la proclamation ne remplace pas le titulaire au registre';
  END IF;

  -- P8 : IL NE TOUCHE PAS AU MANDAT DE DEPUTE. Perdre la presidence n'est pas perdre son siege.
  IF v_src LIKE '%poste_depute%' OR v_src LIKE '%assemblee_sieges%' THEN
    RAISE EXCEPTION 'P8 : le depouillement touche aux sieges de depute';
  END IF;

  -- P9 : LES DEUX PORTES SYSTEME SONT FERMEES AUX JOUEURS -- convoquer et depouiller.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_presidence_convoquer','assemblee_presidence_depouiller')
     AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
     AND has_function_privilege('service_role', p.oid, 'EXECUTE');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P9 : une porte systeme du scrutin est ouverte aux clients'; END IF;

  -- P10 : LA CLOTURE EST UN LUNDI 23 HEURES DE PARIS, strictement dans le futur, et calculee en
  -- DATES CALENDAIRES : un changement d'heure ne doit pas la deplacer.
  v_c := public.assemblee_presidence_prochaine_cloture();
  v_l := v_c AT TIME ZONE 'Europe/Paris';
  IF extract(isodow from v_l)::integer <> 1 THEN
    RAISE EXCEPTION 'P10a : la cloture ne tombe pas un lundi (%)', v_l;
  END IF;
  IF extract(hour from v_l)::integer <> 23 OR extract(minute from v_l)::integer <> 0 THEN
    RAISE EXCEPTION 'P10b : la cloture ne tombe pas a 23h00 (%)', v_l;
  END IF;
  IF v_c <= now() THEN RAISE EXCEPTION 'P10c : la cloture est dans le passe'; END IF;

  -- P11 : UN SCRUTIN CLOS A UN ELU. La contrainte interdit l'etat intermediaire -- un scrutin
  -- « clos sans elu » laisserait la presidence vacante sans que personne l'ait decide.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'assemblee_presidence_scrutins'
     AND c.conname = 'presidence_clos_coherent';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P11 : un scrutin pourrait etre clos sans elu'; END IF;

  -- P12 : AUCUNE PHASE DE CANDIDATURE N'A ETE CREEE. C'est l'arbitrage : les neuf sont eligibles
  -- d'office. Une table ou une porte de candidature serait une regle inventee.
  SELECT count(*) INTO v_n FROM information_schema.tables
   WHERE table_schema = 'public' AND table_name LIKE '%presidence%candidat%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P12a : une table de candidature a la presidence est apparue'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname LIKE 'assemblee_presidence%'
     AND (p.proname LIKE '%candidat%' OR p.prosrc LIKE '%candidature%');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P12b : une porte de candidature a la presidence est apparue'; END IF;

  -- P13 : AUCUN QUORUM. Une voix suffit, et zero votant est traite par la regle d'egalite -- pas
  -- par un seuil invente.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_presidence_depouiller';
  IF v_src ~* '(quorum|minimum_votants|seuil_participation)' THEN
    RAISE EXCEPTION 'P13 : un quorum a ete introduit dans le depouillement';
  END IF;

  -- P14 : LES QUATRE TABLES NAISSENT VIDES.
  SELECT (SELECT count(*) FROM public.assemblee_presidence_scrutins)
       + (SELECT count(*) FROM public.assemblee_presidence_bulletins)
       + (SELECT count(*) FROM public.assemblee_presidence_tirage_vu)
       + (SELECT count(*) FROM public.assemblee_presidence_dues) INTO v_n;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P14 : % ligne(s) de scrutin a la naissance', v_n; END IF;

  RAISE NOTICE 'Election de la presidence : les 14 preuves structurelles passent.';
END $$;
