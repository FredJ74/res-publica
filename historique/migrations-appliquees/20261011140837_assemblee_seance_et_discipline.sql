-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011140837 (UTC), nom `assemblee_seance_et_discipline`.
-- Le registre passe de 648 a 649 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 cade516cccc671e468f3b8e3ae660e0c, 65565 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA SEANCE PARLEMENTAIRE : LA PAROLE, LA DISCIPLINE, LA PROTESTATION
--
-- Six tables et dix-neuf fonctions qui donnent a l'hemicycle une procedure reelle : une file
-- de demandes de parole que le President DOIT respecter, un debat ou l'on peut parler sans
-- autorisation, un rappel au reglement a 15 points de popularite, une sanction a 20 points et
-- 100 FR verses a la caisse de l'Assemblee, une protestation qui deplace vraiment le depute
-- jusqu'au hall, une suspension automatique a cinq protestataires, et un report de vote d'une
-- semaine calendaire.
-- LE SERVEUR ENREGISTRE DES FAITS, ET N'EN TIRE AUCUNE CONCLUSION. Une preuve structurelle
-- verifie qu'aucune colonne de qualification n'existe dans les six tables -- ni « abusif », ni
-- « justifie », ni « gravite », ni « score ». Le motif d'un rappel est conserve VERBATIM et
-- transmis tel quel a la presse, qui en pensera ce qu'elle veut. Parler sans avoir la parole
-- est enregistre comme un FAIT (`autorise = false`) et ne declenche AUCUNE sanction : une
-- preuve verifie que la porte de parole ne touche ni la popularite, ni l'argent, ni la
-- discipline.
-- TOUTE LA SEANCE EST ISOLEE DERRIERE `assemblee_president(pays)`. L'ELECTION du President
-- n'est PAS livree : trois decisions de game design manquent -- la mecanique de candidature, le
-- comportement electoral des neuf deputes PNJ, et le cas ou aucun joueur ne se presente. Le
-- tirage a la courte paille et la nouvelle election apres deux suspensions en dependent et
-- sont donc hors de cette migration. Le compteur d'episodes est rendu comme un fait et ne
-- declenche rien : ouvrir une vacance sans moyen de la combler creerait un etat bloque.
-- ET LE POSTE N'A DEMANDE AUCUNE PLOMBERIE NEUVE : `poste_est_atteste` traite deja tout poste
-- nomme par sa branche fail-closed sur `postes_attribues`. Une preuve le verifie.
-- DEUX CONSTATS SIGNALES AU RAPPORT. Les neuf deputes PNJ des sieges n'ont AUCUNE fiche de
-- personnage : ni position, ni popularite, ni argent -- la discipline de seance s'adresse donc
-- par construction aux deputes JOUEURS. Et `organisations` est un blob `text` ouvert a
-- l'ecriture de tout joueur identifie : le parti est relu au serveur, mais il reste ecrit par
-- le navigateur.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- LA SEANCE PARLEMENTAIRE : LA PAROLE, LA DISCIPLINE, LA PROTESTATION (11 octobre 2026)
-- =================================================================================================
-- CE QUI EST LIVRE ICI, ET CE QUI NE L'EST PAS.
--
-- LIVRE : le report presidentiel d'un vote, la file des demandes de parole, l'intervention sans
-- autorisation, le rappel au reglement, la sanction, la protestation avec son deplacement reel, la
-- suspension par boycott, et la matiere factuelle pour la presse.
--
-- PAS LIVRE, ET PAS INVENTE : l'ELECTION du President de l'Assemblee. Trois decisions de game
-- design manquent -- la mecanique de candidature, le comportement electoral des neuf deputes PNJ,
-- et le cas ou aucun joueur ne se presente -- et le prompt demandait explicitement de les remonter
-- plutot que de les combler. Le tirage a la courte paille et le declenchement d'une nouvelle
-- election en dependent et sont donc hors de cette migration.
--
-- TOUTE LA SEANCE EST ISOLEE DERRIERE UNE SEULE FONCTION : `assemblee_president(pays)`. C'est le
-- SEUL endroit qui dira un jour qui preside. Le jour ou l'election sera arbitree, elle ecrira la
-- ligne de `postes_attribues` et rien d'autre ne changera ici.
--
-- ET LE POSTE N'A DEMANDE AUCUNE PLOMBERIE NEUVE. `poste_est_atteste` traite deja tout poste
-- inconnu par sa branche (c) : « un poste nomme n'existe que s'il est inscrit au registre
-- postes_attribues. Fail closed. » Un joueur pourra donc porter `president_assemblee` sur sa fiche
-- des que le registre le dira, par le socle generique et sans exception.
--
-- LE SERVEUR ENREGISTRE DES FAITS. Aucune qualification n'est produite : ni « abusif », ni
-- « justifie », ni « autoritaire ». Le motif d'un rappel est conserve VERBATIM, et c'est aux
-- humains -- et a la presse joueuse -- d'en penser ce qu'ils veulent.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 0. QUI PRESIDE -- LE SEUL POINT DE VERITE
-- -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_president(p_pays text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT a.titulaire FROM public.postes_attribues a
   WHERE a.country = p_pays AND a.poste_id = 'president_assemblee' AND a.city IS NULL
   LIMIT 1;
$function$;

COMMENT ON FUNCTION public.assemblee_president(text) IS
  'Le titulaire de la presidence de l Assemblee, lu dans le registre atteste postes_attribues. SEUL point de verite de la seance : toutes les prerogatives presidentielles passent par lui. L ELECTION qui remplit cette ligne n est pas encore arbitree (candidature, vote des deputes PNJ, absence de candidat) : le jour ou elle le sera, elle ecrira ici et rien d autre ne changera.';

-- QUI EST DEPUTE. Derive de `assemblee_occupation_sieges`, le resolveur deja en place : un siege
-- est tenu par un PJ, ou a defaut par le PNJ qui l'occupe.
--
-- SEUL LE DEPUTE JOUEUR EST ICI, ET CE N'EST PAS UN CHOIX, C'EST UN CONSTAT. Les neuf deputes PNJ
-- des sieges n'ont AUCUNE fiche de personnage : leur nom ne figure pas dans `personnages_donnees`.
-- Ils n'ont donc ni position physique, ni popularite, ni argent. Un rappel au reglement contre eux
-- ne pourrait ni verifier leur presence dans l'hemicycle, ni retirer 15 points de popularite ; une
-- sanction ne pourrait pas prelever 100 FR. Toute la discipline de seance s'adresse par
-- construction aux deputes JOUEURS. L'ecart est signale au rapport : si un jour les deputes PNJ
-- doivent pouvoir etre rappeles, il leur faudra d'abord une fiche, et c'est un arbitrage separe.
CREATE OR REPLACE FUNCTION public.assemblee_est_depute(p_pays text, p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.assemblee_occupation_sieges(p_pays) o
                  WHERE o.pj_nom = p_nom);
$function$;

-- PRESENT DANS L'HEMICYCLE ? La regle de localisation UNIQUE du jeu, relue en base. Le navigateur
-- ne transmet aucune position : il ne pourrait pas mentir.
CREATE OR REPLACE FUNCTION public.assemblee_dans_hemicycle(p_pays text, p_nom text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.acteur_present_sur_site(p_nom, p_pays, 'capitale', 'assemblee', 'hemicycle');
$function$;

-- -------------------------------------------------------------------------------------------------
-- 1. LA FILE DES DEMANDES DE PAROLE
-- -------------------------------------------------------------------------------------------------
-- UNE SEULE DEMANDE ACTIVE PAR DEPUTE, et c'est la cle primaire qui le dit. Redemander apres un
-- retrait cree une ligne NEUVE avec un horodatage neuf : elle arrive donc en FIN de file, ce que
-- l'arbitrage exige, sans qu'aucun code ne doive gerer un rang.
CREATE TABLE IF NOT EXISTS public.assemblee_paroles (
  pays        text        NOT NULL,
  depute      text        NOT NULL,
  demande_le  timestamptz NOT NULL DEFAULT now(),
  a_la_parole boolean     NOT NULL DEFAULT false,
  donnee_le   timestamptz,
  PRIMARY KEY (pays, depute),
  CONSTRAINT parole_donnee_a_une_date
    CHECK ((a_la_parole AND donnee_le IS NOT NULL) OR (NOT a_la_parole AND donnee_le IS NULL))
);

-- UN SEUL ORATEUR A LA FOIS. L'index partiel l'impose : deux « donner la parole » simultanes ne
-- peuvent pas produire deux orateurs, le second viole l'index et sa transaction entiere tombe.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_un_seul_orateur
  ON public.assemblee_paroles (pays) WHERE a_la_parole;

COMMENT ON TABLE public.assemblee_paroles IS
  'La file CHRONOLOGIQUE des demandes de parole, et l orateur en cours. Le President ne choisit pas : il donne la parole au PREMIER de la file, et la porte refuse tout autre depute. Une demande refaite apres un retrait porte un horodatage neuf, donc arrive en fin de file (arbitrage du 11 octobre 2026).';

-- -------------------------------------------------------------------------------------------------
-- 2. LE DEBAT
-- -------------------------------------------------------------------------------------------------
-- `autorise` EST UN FAIT, PAS UN JUGEMENT. Il dit si le depute avait la parole quand il a parle --
-- rien de plus. Le serveur n'empeche PAS de parler sans autorisation et ne sanctionne jamais
-- automatiquement : il enregistre, et le President fait ce qu'il veut de l'information.
CREATE TABLE IF NOT EXISTS public.assemblee_debats (
  id              text        PRIMARY KEY,
  pays            text        NOT NULL,
  auteur          text        NOT NULL,
  auteur_fonction text,
  texte           text        NOT NULL,
  autorise        boolean     NOT NULL,
  dit_le          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS assemblee_debats_par_pays
  ON public.assemblee_debats (pays, dit_le DESC);

COMMENT ON TABLE public.assemblee_debats IS
  'Les interventions reellement prononcees en seance. `autorise` dit si l orateur avait la parole -- un FAIT, jamais un jugement : le serveur ne sanctionne pas une intervention sans autorisation, il la rend identifiable. Le texte est conserve verbatim.';

-- -------------------------------------------------------------------------------------------------
-- 3. LA DISCIPLINE : RAPPELS ET SANCTIONS
-- -------------------------------------------------------------------------------------------------
-- UNE SEULE TABLE POUR LES DEUX, parce qu'une sanction n'existe pas sans le rappel qu'elle
-- CONSOMME : `rappel_id` porte ce lien, et il est unique -- un rappel ne peut donc jamais servir
-- deux fois. C'est l'index qui l'interdit, pas une relecture.
CREATE TABLE IF NOT EXISTS public.assemblee_disciplines (
  id               text        PRIMARY KEY,
  pays             text        NOT NULL,
  genre            text        NOT NULL,
  president        text        NOT NULL,
  president_fonction text,
  cible            text        NOT NULL,
  cible_fonction   text,
  motif            text        NOT NULL,
  pop_delta        integer     NOT NULL,
  amende           integer     NOT NULL DEFAULT 0,
  caisse_creditee  text,
  rappel_id        text        REFERENCES public.assemblee_disciplines(id),
  chronique_id     text,
  fait_le          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT discipline_genre_connu CHECK (genre = ANY (ARRAY['rappel','sanction'])),
  CONSTRAINT discipline_motif_non_vide CHECK (btrim(motif) <> ''),
  -- UN RAPPEL NE PORTE NI AMENDE NI RAPPEL CONSOMME ; UNE SANCTION PORTE LES DEUX.
  CONSTRAINT discipline_forme_coherente CHECK (
    (genre = 'rappel'   AND amende = 0 AND rappel_id IS NULL AND caisse_creditee IS NULL)
 OR (genre = 'sanction' AND amende > 0 AND rappel_id IS NOT NULL AND caisse_creditee IS NOT NULL))
);

-- UN RAPPEL NE SE CONSOMME QU'UNE FOIS. Deux sanctions simultanees sur le meme rappel ne peuvent
-- pas passer : la seconde viole l'unicite et sa transaction entiere est annulee -- donc ni POP, ni
-- amende, ni demi-effet.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_un_rappel_une_sanction
  ON public.assemblee_disciplines (rappel_id) WHERE rappel_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS assemblee_disciplines_par_cible
  ON public.assemblee_disciplines (pays, cible, fait_le DESC);

COMMENT ON TABLE public.assemblee_disciplines IS
  'Les rappels au reglement et les sanctions, avec le motif EXACT saisi par le President -- conserve verbatim et jamais qualifie. Une sanction CONSOMME le rappel qui l a rendue possible (`rappel_id`, unique) : un seul rappel ne permet jamais deux sanctions. Le serveur ne juge ni la pertinence, ni la verite, ni la legitimite du motif (arbitrage du 11 octobre 2026).';

-- -------------------------------------------------------------------------------------------------
-- 4. LA PROTESTATION
-- -------------------------------------------------------------------------------------------------
-- TOUS LES DEPARTS NE COMPTENT PAS. `qualifie` est calcule PAR LE SERVEUR au moment de la sortie,
-- et jamais recu du navigateur : soit le depute a lui-meme subi un rappel ou une sanction, soit un
-- depute de SON PARTI en a subi un. `motif_qualifiant` dit laquelle des deux.
CREATE TABLE IF NOT EXISTS public.assemblee_protestations (
  pays             text        NOT NULL,
  depute           text        NOT NULL,
  sorti_le         timestamptz NOT NULL DEFAULT now(),
  qualifie         boolean     NOT NULL,
  motif_qualifiant text,
  discipline_id    text REFERENCES public.assemblee_disciplines(id),
  PRIMARY KEY (pays, depute),
  CONSTRAINT protestation_motif_si_qualifie CHECK (
    (qualifie AND motif_qualifiant IS NOT NULL) OR (NOT qualifie AND motif_qualifiant IS NULL))
);

COMMENT ON TABLE public.assemblee_protestations IS
  'Les deputes actuellement sortis de l hemicycle en signe de protestation. `qualifie` est calcule par le SERVEUR -- rappel ou sanction subie soi-meme, ou subie par un depute du meme parti -- et jamais transmis par le navigateur. Une sortie non qualifiee est enregistree mais ne compte pas dans le seuil de suspension.';

-- -------------------------------------------------------------------------------------------------
-- 5. LES EPISODES DE SUSPENSION
-- -------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.assemblee_suspensions (
  id             text        PRIMARY KEY,
  pays           text        NOT NULL,
  cause          text        NOT NULL,
  president      text,
  motif          text,
  protestataires jsonb       NOT NULL DEFAULT '[]'::jsonb,
  ouverte_le     timestamptz NOT NULL DEFAULT now(),
  close_le       timestamptz,
  CONSTRAINT suspension_cause_connue CHECK (cause = ANY (ARRAY['boycott','presidence']))
);

-- UN SEUL EPISODE DE BOYCOTT OUVERT A LA FOIS. C'est cet index qui empeche un depute d'empiler des
-- episodes en faisant hall -> hemicycle -> hall : tant qu'un episode court, aucun second ne
-- s'ouvre.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_un_seul_boycott_ouvert
  ON public.assemblee_suspensions (pays) WHERE cause = 'boycott' AND close_le IS NULL;

COMMENT ON TABLE public.assemblee_suspensions IS
  'Les episodes de suspension de la seance. `boycott` : cinq deputes qualifies simultanement sortis ; l episode se ferme quand ils ne sont plus que quatre, et un NOUVEL episode ne peut s ouvrir qu apres dissolution COMPLETE du groupe -- sinon un seul depute faisant l aller-retour en fabriquerait plusieurs. `presidence` : la suspension personnelle du President, qui ne compte JAMAIS dans ce decompte.';

-- -------------------------------------------------------------------------------------------------
-- 6. LE REPORT PRESIDENTIEL D'UN VOTE
-- -------------------------------------------------------------------------------------------------
-- UN TEXTE N'EST REPORTE QU'UNE FOIS PAR CETTE PREROGATIVE, et c'est la cle primaire qui l'impose :
-- impossible d'enchainer les reports presidentiels pour enterrer un texte indefiniment.
CREATE TABLE IF NOT EXISTS public.assemblee_reports (
  proposition_id    text        PRIMARY KEY REFERENCES public.assemblee_propositions(id),
  pays              text        NOT NULL,
  president         text        NOT NULL,
  ancienne_cloture  timestamptz NOT NULL,
  nouvelle_cloture  timestamptz NOT NULL,
  fait_le           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT report_repousse_vraiment CHECK (nouvelle_cloture > ancienne_cloture)
);

COMMENT ON TABLE public.assemblee_reports IS
  'Les reports de vote decides par le President de l Assemblee. La cle primaire EST la regle : un texte ne peut etre reporte qu une seule fois par cette prerogative. Les reports automatiques dus a une suspension ne passent pas par ici -- ils ne sont pas une prerogative et ne consomment pas celle du President.';

-- LES CINQ TABLES SONT FERMEES AU CLIENT : RLS active, aucune policy. Toute la seance passe par les
-- portes ci-dessous, et un navigateur ne peut ni s accorder la parole, ni se declarer protestataire
-- qualifie, ni fabriquer un rappel.
ALTER TABLE public.assemblee_paroles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_debats         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_disciplines    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_protestations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_suspensions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assemblee_reports        ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------------------------------
-- 7. LE PARTI D'UN DEPUTE
-- -------------------------------------------------------------------------------------------------
-- LU EN BASE, JAMAIS RECU DU NAVIGATEUR : c'est ce que l'arbitrage exige. Une organisation de type
-- `politique` dont la liste de membres porte ce nom, dans ce pays. `maxAdhesion` vaut 1 pour ce
-- type d'organisation : un depute n'a donc jamais deux partis, et le LIMIT 1 est fidele.
--
-- RESERVE CONSIGNEE, ET ELLE N'EST PAS DE MON RESSORT : la table `organisations` est un blob
-- ouvert a l'ecriture de TOUT joueur identifie (policy `organisations_maj_acteur`, UPDATE USING
-- acteur_identifie(), sans aucun controle de propriete). La liste des membres est donc lue au
-- serveur mais ECRITE par le navigateur, et un depute determine pourrait s'y inscrire pour se
-- qualifier. Fermer cette policy casserait tout le jeu des organisations : c'est un arbitrage
-- separe, signale et non tranche ici.
--
-- ET LA COLONNE EST DU TEXTE, PAS DU JSONB. `organisations.data` est un blob `text` : il faut le
-- convertir, et le convertir PRUDEMMENT. Un seul joueur enregistrant un blob mal forme ferait
-- echouer la conversion -- et comme cette fonction est lue a chaque protestation et a chaque
-- ouverture de la seance, UNE organisation cassee suffirait a bloquer la seance entiere. Le CASE
-- lateral isole donc chaque ligne : une organisation illisible est ignoree, et les autres sont
-- lues normalement. `IS JSON OBJECT` est un predicat PostgreSQL 16+, et la base tourne en 17.6.
CREATE OR REPLACE FUNCTION public.assemblee_parti_de(p_pays text, p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT o.id FROM public.organisations o
   CROSS JOIN LATERAL (SELECT CASE WHEN o.data IS JSON OBJECT
                                   THEN o.data::jsonb ELSE '{}'::jsonb END AS d) j
   WHERE j.d ->> 'type' = 'politique'
     AND coalesce(j.d ->> 'country', o.country_origine) = p_pays
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(j.d -> 'membres', '[]'::jsonb)) m
                  WHERE m ->> 'nom' = p_nom)
   LIMIT 1;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 8. LE RECALCUL DE LA SUSPENSION -- UNE SEULE AUTORITE SUR LE SEUIL
-- -------------------------------------------------------------------------------------------------
-- APPELEE APRES CHAQUE SORTIE ET CHAQUE RETOUR, et par elles seules. Le seuil n'est donc jamais
-- calcule a deux endroits.
--
-- LA DISTINCTION DES EPISODES EST LA PARTIE DELICATE, et voici la lecture retenue :
--   . l'episode S'OUVRE quand cinq deputes qualifies sont simultanement sortis ;
--   . il SE FERME quand ils ne sont plus que quatre -- l'arbitrage le dit : « la suspension cesse » ;
--   . mais un NOUVEL episode ne peut s'ouvrir qu'apres DISSOLUTION COMPLETE du groupe, c'est-a-dire
--     quand il ne reste PLUS AUCUN protestataire qualifie dehors.
-- Sans cette troisieme regle, un seul depute faisant hall -> hemicycle -> hall ferait passer le
-- compte de 5 a 4 puis a 5, et fabriquerait un second episode en dix secondes -- donc une nouvelle
-- election presidentielle. L'arbitrage interdit explicitement cela ; il ne dit pas COMMENT, et
-- c'est la seule lecture qui le satisfait. ELLE EST SIGNALEE AU RAPPORT : si elle ne convient pas,
-- c'est ici et nulle part ailleurs qu'il faudra la changer.
CREATE OR REPLACE FUNCTION public.assemblee_recalculer_suspension(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  SEUIL constant integer := 5;
  v_qualifies integer; v_dehors integer; v_ouvert text; v_id text; v_pres text;
BEGIN
  SELECT count(*) FILTER (WHERE qualifie), count(*)
    INTO v_qualifies, v_dehors
    FROM public.assemblee_protestations WHERE pays = p_pays;

  SELECT id INTO v_ouvert FROM public.assemblee_suspensions
   WHERE pays = p_pays AND cause = 'boycott' AND close_le IS NULL FOR UPDATE;

  IF v_ouvert IS NOT NULL AND v_qualifies < SEUIL THEN
    UPDATE public.assemblee_suspensions SET close_le = now() WHERE id = v_ouvert;
    v_ouvert := NULL;
  ELSIF v_ouvert IS NULL AND v_qualifies >= SEUIL THEN
    -- DISSOLUTION COMPLETE EXIGEE : s'il reste un protestataire qualifie depuis l'episode
    -- precedent, on est dans le MEME boycott et on ne l'ouvre pas une seconde fois.
    IF EXISTS (SELECT 1 FROM public.assemblee_suspensions s
                WHERE s.pays = p_pays AND s.cause = 'boycott' AND s.close_le IS NOT NULL
                  AND EXISTS (SELECT 1 FROM public.assemblee_protestations p
                               WHERE p.pays = p_pays AND p.qualifie
                                 AND p.sorti_le < s.close_le)) THEN
      NULL;   -- meme boycott : aucun episode neuf
    ELSE
      v_pres := public.assemblee_president(p_pays);
      v_id := 'suspension-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
      INSERT INTO public.assemblee_suspensions (id, pays, cause, president, protestataires)
      VALUES (v_id, p_pays, 'boycott', v_pres,
              (SELECT coalesce(jsonb_agg(depute ORDER BY depute), '[]'::jsonb)
                 FROM public.assemblee_protestations
                WHERE pays = p_pays AND qualifie));
      v_ouvert := v_id;
    END IF;
  END IF;

  RETURN jsonb_build_object('suspendue', v_ouvert IS NOT NULL, 'episode', v_ouvert,
                            'qualifies', v_qualifies, 'dehors', v_dehors, 'seuil', SEUIL);
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_recalculer_suspension(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assemblee_recalculer_suspension(text) TO service_role;

-- LA SEANCE EST-ELLE SUSPENDUE ? Lecture seule, et la SEULE reponse a cette question.
CREATE OR REPLACE FUNCTION public.assemblee_suspendue(p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.assemblee_suspensions
                  WHERE pays = p_pays AND cause = 'boycott' AND close_le IS NULL);
$function$;

-- -------------------------------------------------------------------------------------------------
-- 9. LA PAROLE
-- -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_parole_demander()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_rang integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;
  IF NOT public.assemblee_dans_hemicycle(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_hemicycle'); END IF;

  -- IDEMPOTENT PAR CONSTRUCTION : un double clic ne cree pas deux demandes et ne repousse pas la
  -- place deja acquise dans la file. On ne touche a rien si une demande existe.
  IF EXISTS (SELECT 1 FROM public.assemblee_paroles WHERE pays = v_pays AND depute = v_moi) THEN
    SELECT count(*) INTO v_rang FROM public.assemblee_paroles
     WHERE pays = v_pays AND NOT a_la_parole
       AND demande_le <= (SELECT demande_le FROM public.assemblee_paroles
                           WHERE pays = v_pays AND depute = v_moi);
    RETURN jsonb_build_object('ok', true, 'deja_demande', true, 'rang', v_rang);
  END IF;

  INSERT INTO public.assemblee_paroles (pays, depute) VALUES (v_pays, v_moi);
  SELECT count(*) INTO v_rang FROM public.assemblee_paroles WHERE pays = v_pays AND NOT a_la_parole;
  RETURN jsonb_build_object('ok', true, 'rang', v_rang);
END;
$function$;

-- LE PRESIDENT NE CHOISIT PAS SON ORATEUR. Il donne la parole au PREMIER de la file, et la porte
-- refuse tout autre nom : c'est une regle de jeu, et elle est tenue par le serveur, pas par
-- l'honnetete de l'interface.
CREATE OR REPLACE FUNCTION public.assemblee_parole_donner(p_depute text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_premier text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  -- LE VERROU EST PRIS SUR LA FILE ENTIERE : deux « donner la parole » concurrents ne peuvent pas
  -- lire le meme premier et produire deux orateurs.
  PERFORM 1 FROM public.assemblee_paroles WHERE pays = v_pays FOR UPDATE;
  SELECT depute INTO v_premier FROM public.assemblee_paroles
   WHERE pays = v_pays AND NOT a_la_parole ORDER BY demande_le, depute LIMIT 1;
  IF v_premier IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'file_vide'); END IF;
  IF p_depute IS NOT NULL AND p_depute <> v_premier THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_premier_de_la_file',
                              'premier', v_premier);
  END IF;
  IF EXISTS (SELECT 1 FROM public.assemblee_paroles WHERE pays = v_pays AND a_la_parole) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'un_orateur_a_deja_la_parole'); END IF;

  UPDATE public.assemblee_paroles SET a_la_parole = true, donnee_le = now()
   WHERE pays = v_pays AND depute = v_premier;
  RETURN jsonb_build_object('ok', true, 'orateur', v_premier);
END;
$function$;

-- RETIRER LA PAROLE EFFACE LA DEMANDE. C'est ce qui fait qu'une nouvelle demande arrive en FIN de
-- file : elle portera un horodatage neuf. Le depute n'est pas empeche de continuer a parler -- ses
-- interventions seront simplement enregistrees comme non autorisees.
CREATE OR REPLACE FUNCTION public.assemblee_parole_retirer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_orateur text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  SELECT depute INTO v_orateur FROM public.assemblee_paroles
   WHERE pays = v_pays AND a_la_parole FOR UPDATE;
  IF v_orateur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_orateur'); END IF;

  DELETE FROM public.assemblee_paroles WHERE pays = v_pays AND depute = v_orateur;
  RETURN jsonb_build_object('ok', true, 'retire', v_orateur);
END;
$function$;

-- PARLER. LE SERVEUR N'EMPECHE RIEN et ne sanctionne rien : il constate si l'orateur avait la
-- parole, et l'ecrit. C'est exactement ce que l'arbitrage demande -- une intervention sans
-- autorisation doit APPARAITRE dans le debat, identifiable comme telle.
CREATE OR REPLACE FUNCTION public.assemblee_debat_dire(p_texte text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_t text; v_id text; v_autorise boolean; v_fonction text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_t := nullif(btrim(coalesce(p_texte, '')), '');
  IF v_t IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'texte_vide'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  -- LE PRESIDENT PARLE TOUJOURS DE DROIT : il preside la seance. Un depute, lui, doit etre dans
  -- l'hemicycle -- on ne parle pas en seance depuis le hall.
  IF public.assemblee_president(v_pays) = v_moi THEN
    v_autorise := true; v_fonction := 'president_assemblee';
  ELSIF public.assemblee_est_depute(v_pays, v_moi) THEN
    IF NOT public.assemblee_dans_hemicycle(v_pays, v_moi) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_hemicycle'); END IF;
    v_autorise := EXISTS (SELECT 1 FROM public.assemblee_paroles
                           WHERE pays = v_pays AND depute = v_moi AND a_la_parole);
    v_fonction := 'depute';
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute');
  END IF;

  v_id := 'debat-' || (extract(epoch from clock_timestamp()) * 1000)::bigint || '-' || left(md5(v_moi), 6);
  INSERT INTO public.assemblee_debats (id, pays, auteur, auteur_fonction, texte, autorise)
  VALUES (v_id, v_pays, v_moi, v_fonction, left(v_t, 4000), v_autorise);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'autorise', v_autorise);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 10. LE RAPPEL AU REGLEMENT
-- -------------------------------------------------------------------------------------------------
-- POUVOIR DISCRETIONNAIRE, ET LE SERVEUR NE JUGE RIEN. Il verifie trois faits -- c'est le
-- President, la cible est deputee, elle est PHYSIQUEMENT dans l'hemicycle -- exige un motif non
-- vide, applique -15 POP, et conserve le texte VERBATIM. Il ne verifie ni la pertinence, ni la
-- verite, ni la legitimite du motif, et il n'en produit aucune qualification.
CREATE OR REPLACE FUNCTION public.assemblee_rappeler(p_depute text, p_motif text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_RAPPEL constant integer := -15;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_pop jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF p_depute IS NULL OR p_depute = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;
  -- UNIQUEMENT CONTRE UN DEPUTE PHYSIQUEMENT PRESENT. On ne rappelle pas au reglement quelqu'un
  -- qui a quitte l'hemicycle.
  IF NOT public.assemblee_dans_hemicycle(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente_de_l_hemicycle'); END IF;

  v_id    := 'rappel-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_chron := 'chronique-assemblee_rappel-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     chronique_id)
  VALUES (v_id, v_pays, 'rappel', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_RAPPEL, v_chron);

  v_pop := public.personnage_ajuster_pop_inf(p_depute, POP_RAPPEL, 0);

  -- LA TRACE PUBLIQUE EST FACTUELLE, ECRITE PAR LE SERVEUR, DANS LA MEME TRANSACTION. Elle dit QUI
  -- a rappele QUI, et rien de plus : aucun adjectif, aucune appreciation. Le motif exact voyage
  -- dans `data`, verbatim, pour que la presse puisse le CITER sans que personne l'ait reecrit.
  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, v_pays, 'assemblee_rappel', 'capitale',
          jsonb_build_array(v_moi, p_depute),
          'Le President de l''Assemblee a rappele ' || p_depute || ' au reglement.',
          jsonb_build_object('president', v_moi, 'cible', p_depute, 'motif', v_m,
                             'pop', POP_RAPPEL, 'discipline', v_id),
          v_id);

  RETURN jsonb_build_object('ok', true, 'rappel', v_id, 'cible', p_depute,
                            'pop', POP_RAPPEL, 'pop_applique', coalesce((v_pop->>'ok')::boolean, false));
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 11. LA SANCTION
-- -------------------------------------------------------------------------------------------------
-- ELLE N'EXISTE PAS SANS UN RAPPEL, ET ELLE LE CONSOMME. La sequence est donc rappel -> sanction,
-- puis rappel -> sanction : un seul rappel ne permet JAMAIS deux sanctions, et c'est l'index
-- unique sur `rappel_id` qui l'interdit -- pas une relecture.
--
-- ATOMICITE : les 100 FR sont debites au depute et credites a la caisse de l'Assemblee dans la
-- MEME transaction. Si le debit echoue, rien n'est ecrit : ni POP, ni amende, ni ligne de
-- discipline. On ne retire jamais 100 FR sans crediter la caisse.
CREATE OR REPLACE FUNCTION public.assemblee_sanctionner(p_depute text, p_motif text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SANCTION constant integer := -20;
  AMENDE       constant integer := 100;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_rappel text;
  v_caisse text; v_debit jsonb; v_pop jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;

  -- LE RAPPEL PREALABLE, NON ENCORE CONSOMME, LE PLUS ANCIEN D'ABORD. Verrouille : deux sanctions
  -- simultanees ne peuvent pas elire le meme rappel.
  SELECT d.id INTO v_rappel FROM public.assemblee_disciplines d
   WHERE d.pays = v_pays AND d.genre = 'rappel' AND d.cible = p_depute
     AND d.president = v_moi
     AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = d.id)
   ORDER BY d.fait_le
   FOR UPDATE
   LIMIT 1;
  IF v_rappel IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_rappel_a_consommer'); END IF;

  -- L'ARGENT D'ABORD, ET SI IL MANQUE, RIEN N'EST ECRIT. `assemblee_debiter_joueur` rend un refus
  -- structure et ne touche a rien quand les fonds manquent.
  v_debit := public.assemblee_debiter_joueur(p_depute, 0, AMENDE);
  IF coalesce((v_debit->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_debit->>'raison', 'debit_impossible'),
                              'detail', v_debit);
  END IF;
  v_caisse := v_pays || '_assemblee';
  PERFORM public.assemblee_crediter_caisse(v_caisse, AMENDE);

  v_id    := 'sanction-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_chron := 'chronique-assemblee_sanction-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     amende, caisse_creditee, rappel_id, chronique_id)
  VALUES (v_id, v_pays, 'sanction', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_SANCTION, AMENDE, v_caisse, v_rappel, v_chron);

  v_pop := public.personnage_ajuster_pop_inf(p_depute, POP_SANCTION, 0);

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, v_pays, 'assemblee_sanction', 'capitale',
          jsonb_build_array(v_moi, p_depute),
          'Le President de l''Assemblee a sanctionne ' || p_depute || '.',
          jsonb_build_object('president', v_moi, 'cible', p_depute, 'motif', v_m,
                             'pop', POP_SANCTION, 'amende', AMENDE, 'caisse', v_caisse,
                             'rappel', v_rappel, 'discipline', v_id),
          v_id);

  RETURN jsonb_build_object('ok', true, 'sanction', v_id, 'rappel_consomme', v_rappel,
                            'cible', p_depute, 'pop', POP_SANCTION, 'amende', AMENDE,
                            'caisse', v_caisse,
                            'pop_applique', coalesce((v_pop->>'ok')::boolean, false));
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 12. LA PROTESTATION
-- -------------------------------------------------------------------------------------------------
-- LE DEPLACEMENT EST REEL : le depute se retrouve au hall, dans sa position faisant autorite. Ce
-- n'est pas un drapeau d'interface -- il n'est plus dans l'hemicycle, donc il ne peut plus y
-- parler, et il ne peut plus y etre rappele au reglement.
--
-- LA QUALIFICATION EST CALCULEE PAR LE SERVEUR, jamais transmise. Deux motifs, et deux seulement :
--   . `soi_meme`  -- il a lui-meme subi un rappel ou une sanction sous cette presidence ;
--   . `parti`     -- un depute de SON parti en a subi un sous cette presidence.
-- Une sortie sans l'un des deux est enregistree, mais ne compte pas dans le seuil. Aucune
-- solidarite n'est automatique : chacun clique, ou ne clique pas.
CREATE OR REPLACE FUNCTION public.assemblee_protester()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_pres text; v_parti text;
  v_disc text; v_motif text; v_etat jsonb; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pays := a.country;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;
  IF NOT (a.current_building = 'assemblee' AND a.current_room = 'hemicycle') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_hemicycle'); END IF;

  v_pres  := public.assemblee_president(v_pays);
  v_parti := public.assemblee_parti_de(v_pays, v_moi);

  -- A. UN ACTE SUBI PAR LUI-MEME, sous la presidence en cours.
  SELECT d.id INTO v_disc FROM public.assemblee_disciplines d
   WHERE d.pays = v_pays AND d.cible = v_moi
     AND (v_pres IS NULL OR d.president = v_pres)
   ORDER BY d.fait_le DESC LIMIT 1;
  IF v_disc IS NOT NULL THEN v_motif := 'soi_meme'; END IF;

  -- B. UN ACTE SUBI PAR UN DEPUTE DE SON PARTI. Le parti est relu en base pour les DEUX cotes --
  -- celui du protestataire et celui de la victime -- et jamais recu du navigateur.
  IF v_motif IS NULL AND v_parti IS NOT NULL THEN
    SELECT d.id INTO v_disc FROM public.assemblee_disciplines d
     WHERE d.pays = v_pays AND (v_pres IS NULL OR d.president = v_pres)
       AND public.assemblee_parti_de(v_pays, d.cible) = v_parti
     ORDER BY d.fait_le DESC LIMIT 1;
    IF v_disc IS NOT NULL THEN v_motif := 'parti'; END IF;
  END IF;

  -- LE DEPLACEMENT REEL, et il est le meme pour tous : qualifie ou pas, on sort.
  UPDATE public.personnages_donnees SET current_room = 'accueil_assemblee' WHERE name = v_moi;

  INSERT INTO public.assemblee_protestations (pays, depute, qualifie, motif_qualifiant, discipline_id)
  VALUES (v_pays, v_moi, v_motif IS NOT NULL, v_motif, v_disc)
  ON CONFLICT (pays, depute) DO UPDATE
    SET qualifie = EXCLUDED.qualifie, motif_qualifiant = EXCLUDED.motif_qualifiant,
        discipline_id = EXCLUDED.discipline_id;

  v_etat := public.assemblee_recalculer_suspension(v_pays);
  RETURN jsonb_build_object('ok', true, 'qualifie', v_motif IS NOT NULL, 'motif', v_motif,
                            'parti', v_parti, 'piece', 'accueil_assemblee', 'seance', v_etat);
END;
$function$;

-- REVENIR ANNULE LA PROTESTATION. Le depute remonte dans l'hemicycle, sa ligne disparait, et le
-- seuil est recalcule : si le compte retombe a quatre, la suspension cesse.
CREATE OR REPLACE FUNCTION public.assemblee_revenir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_etat jsonb; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pays := a.country;
  IF NOT public.assemblee_est_depute(v_pays, v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_depute'); END IF;
  IF a.current_building IS DISTINCT FROM 'assemblee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_l_assemblee'); END IF;

  UPDATE public.personnages_donnees SET current_room = 'hemicycle' WHERE name = v_moi;
  DELETE FROM public.assemblee_protestations WHERE pays = v_pays AND depute = v_moi;

  v_etat := public.assemblee_recalculer_suspension(v_pays);
  RETURN jsonb_build_object('ok', true, 'piece', 'hemicycle', 'seance', v_etat);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 13. LA SUSPENSION PERSONNELLE DU PRESIDENT
-- -------------------------------------------------------------------------------------------------
-- ELLE EST ENREGISTREE COMME UN ACTE, PAS COMME UN ETAT, et c'est un choix CONTRAINT : l'arbitrage
-- donne son cout -- 20 points de popularite -- et dit qu'elle ne compte jamais parmi les deux
-- suspensions qui remettent la presidence en jeu, mais il ne dit NI combien de temps elle dure, NI
-- comment la seance reprend. Le jeu n'a aucun objet « seance » porteur d'un etat : une session est
-- l'ensemble des propositions au statut `session`, et le registre ne connait pas d'etat
-- « suspendue ». Inventer une duree ou une reprise serait inventer une regle, et creer un etat sans
-- sortie serait creer un etat BLOQUE -- precisement ce que le prompt interdit.
--
-- L'ACTE EST DONC COMPLET ET SANS EFFET BLOQUANT : le cout est preleve, le motif est conserve
-- verbatim, l'episode est horodate et clos dans la meme seconde, et il porte `cause = presidence`
-- pour n'etre jamais confondu avec un boycott. LE POINT RESTE A ARBITRER, et il est au rapport.
CREATE OR REPLACE FUNCTION public.assemblee_suspendre_seance(p_motif text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SUSPENSION constant integer := -20;
  v_moi text; v_pays text; v_id text; v_m text; v_pop jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  -- LE MOTIF EST CONSERVE S'IL EST DONNE, ET N'EST NI EXIGE NI JUGE : l'arbitrage ne le rend pas
  -- obligatoire pour cette prerogative, contrairement au rappel et a la sanction.
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  v_id := 'suspension-pres-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;

  INSERT INTO public.assemblee_suspensions (id, pays, cause, president, motif, close_le)
  VALUES (v_id, v_pays, 'presidence', v_moi, v_m, now());

  v_pop := public.personnage_ajuster_pop_inf(v_moi, POP_SUSPENSION, 0);
  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'pop', POP_SUSPENSION,
                            'compte_pour_le_boycott', false,
                            'pop_applique', coalesce((v_pop->>'ok')::boolean, false));
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 14. LE REPORT PRESIDENTIEL D'UN VOTE
-- -------------------------------------------------------------------------------------------------
-- UNE SEMAINE EXACTEMENT, ET EN DATES CALENDAIRES DE PARIS -- jamais +7 x 24 h. C'est la doctrine
-- du calendrier electoral du jeu, et elle compte ici : l'echeance est un MERCREDI 22 HEURES, et
-- elle doit rester un mercredi 22 heures a travers un changement d'heure.
--
-- UNE SEULE FOIS PAR TEXTE, et c'est la cle primaire de `assemblee_reports` qui l'impose. Un
-- President ne peut donc pas enchainer les reports pour enterrer un texte, et son successeur ne
-- peut pas non plus le reporter une seconde fois : la prerogative appartient au TEXTE, pas a
-- l'homme.
CREATE OR REPLACE FUNCTION public.assemblee_reporter_vote(p_proposition_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; p record; v_neuve timestamptz;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  SELECT * INTO p FROM public.assemblee_propositions
   WHERE id = p_proposition_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'proposition_inconnue'); END IF;
  IF p.country IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autre_empire'); END IF;
  -- ON NE REPOUSSE QUE CE QUI A UNE ECHEANCE. Un texte encore en debat n'a pas de cloture : il n'y
  -- a rien a repousser, et le dire est plus utile que de deviner une date.
  IF p.statut <> 'session' OR p.cloture_ts IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_session', 'statut', p.statut); END IF;
  IF p.cloture_ts <= now() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'echeance_deja_passee'); END IF;
  IF EXISTS (SELECT 1 FROM public.assemblee_reports WHERE proposition_id = p_proposition_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reporte_une_fois'); END IF;

  v_neuve := ((p.cloture_ts AT TIME ZONE 'Europe/Paris') + interval '7 days') AT TIME ZONE 'Europe/Paris';

  INSERT INTO public.assemblee_reports
    (proposition_id, pays, president, ancienne_cloture, nouvelle_cloture)
  VALUES (p_proposition_id, v_pays, v_moi, p.cloture_ts, v_neuve);

  UPDATE public.assemblee_propositions
     SET cloture_ts = v_neuve, updated_at = now() WHERE id = p_proposition_id;

  RETURN jsonb_build_object('ok', true, 'proposition', p_proposition_id,
                            'ancienne_cloture', p.cloture_ts, 'nouvelle_cloture', v_neuve);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 15. LE REPORT AUTOMATIQUE QUAND L'ASSEMBLEE EST ENCORE SUSPENDUE
-- -------------------------------------------------------------------------------------------------
-- A APPELER AVANT LE DEPOUILLEMENT DU MERCREDI, et par le serveur seul. Si un episode de boycott
-- court encore au moment ou un vote devrait etre conclu, ce vote part d'une semaine -- exactement
-- comme le demande l'arbitrage.
--
-- IL NE CONSOMME PAS LA PREROGATIVE DU PRESIDENT. Ces reports n'entrent pas dans
-- `assemblee_reports` : ce ne sont pas des decisions, ce sont des consequences. Un texte reporte
-- par un boycott reste reportable une fois par le President, et reciproquement.
CREATE OR REPLACE FUNCTION public.assemblee_reporter_si_suspendue(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_n integer := 0; v_ids jsonb := '[]'::jsonb; r record;
BEGIN
  IF NOT public.assemblee_suspendue(p_pays) THEN
    RETURN jsonb_build_object('ok', true, 'suspendue', false, 'reportes', 0);
  END IF;

  FOR r IN SELECT id, cloture_ts FROM public.assemblee_propositions
            WHERE country = p_pays AND statut = 'session'
              AND cloture_ts IS NOT NULL AND cloture_ts <= now()
            FOR UPDATE
  LOOP
    UPDATE public.assemblee_propositions
       SET cloture_ts = ((r.cloture_ts AT TIME ZONE 'Europe/Paris') + interval '7 days')
                          AT TIME ZONE 'Europe/Paris',
           updated_at = now()
     WHERE id = r.id;
    v_n := v_n + 1;
    v_ids := v_ids || to_jsonb(r.id);
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'suspendue', true, 'reportes', v_n, 'propositions', v_ids);
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_reporter_si_suspendue(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assemblee_reporter_si_suspendue(text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- 16. L'ETAT DE LA SEANCE -- CE QUE L'INTERFACE A LE DROIT DE SAVOIR
-- -------------------------------------------------------------------------------------------------
-- UNE SEULE LECTURE POUR TOUTE LA SEANCE, et elle est publique dans l'enceinte : le debat
-- parlementaire se tient devant tous. Elle ne rend AUCUN jugement et AUCUNE donnee privee -- ni
-- argent, ni casier, ni messages.
--
-- `episodes_sous_cette_presidence` EST LE COMPTEUR DU §9 : il est rendu comme un FAIT, et rien
-- n'est declenche a 2. Le declenchement -- une nouvelle election -- exige l'election elle-meme,
-- qui n'est pas arbitree ; ouvrir une vacance sans moyen de la combler creerait un etat bloque.
CREATE OR REPLACE FUNCTION public.assemblee_seance(p_limite integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_pres text; v_lim integer := least(greatest(coalesce(p_limite,50),1),200);
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_pres := public.assemblee_president(v_pays);

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'president', v_pres,
    'je_suis_le_president', (v_pres IS NOT NULL AND v_pres = v_moi),
    'je_suis_depute', public.assemblee_est_depute(v_pays, v_moi),
    'je_suis_dans_hemicycle', public.assemblee_dans_hemicycle(v_pays, v_moi),
    'mon_parti', public.assemblee_parti_de(v_pays, v_moi),
    'suspendue', public.assemblee_suspendue(v_pays),
    -- LA FILE, DANS SON ORDRE CHRONOLOGIQUE EXACT. C'est elle que le President doit respecter.
    'file', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', q.depute, 'depuis', q.demande_le)
              ORDER BY q.demande_le, q.depute), '[]'::jsonb)
       FROM public.assemblee_paroles q WHERE q.pays = v_pays AND NOT q.a_la_parole),
    'orateur', (SELECT q.depute FROM public.assemblee_paroles q
                 WHERE q.pays = v_pays AND q.a_la_parole LIMIT 1),
    'debat', (SELECT coalesce(jsonb_agg(x ORDER BY (x->>'dit_le')), '[]'::jsonb) FROM (
        SELECT jsonb_build_object('id', d.id, 'auteur', d.auteur, 'fonction', d.auteur_fonction,
                 'texte', d.texte, 'autorise', d.autorise, 'dit_le', d.dit_le) AS x
          FROM public.assemblee_debats d WHERE d.pays = v_pays
          ORDER BY d.dit_le DESC LIMIT v_lim) z),
    'dehors', (SELECT coalesce(jsonb_agg(jsonb_build_object('depute', p.depute,
                 'qualifie', p.qualifie, 'motif', p.motif_qualifiant, 'depuis', p.sorti_le)
                 ORDER BY p.sorti_le), '[]'::jsonb)
       FROM public.assemblee_protestations p WHERE p.pays = v_pays),
    'protestataires_qualifies', (SELECT count(*) FROM public.assemblee_protestations p
                                  WHERE p.pays = v_pays AND p.qualifie),
    'seuil_suspension', 5,
    -- CE QUE LE PRESIDENT PEUT SANCTIONNER : les rappels non encore consommes. C'est un fait de
    -- procedure, pas un conseil.
    'rappels_consommables', (SELECT coalesce(jsonb_agg(d.cible ORDER BY d.cible), '[]'::jsonb)
       FROM public.assemblee_disciplines d
      WHERE d.pays = v_pays AND d.genre = 'rappel' AND d.president IS NOT DISTINCT FROM v_pres
        AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = d.id)),
    'episodes_sous_cette_presidence', (SELECT count(*) FROM public.assemblee_suspensions s
       WHERE s.pays = v_pays AND s.cause = 'boycott'
         AND s.president IS NOT DISTINCT FROM v_pres));
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 17. LA MATIERE DE LA PRESSE
-- -------------------------------------------------------------------------------------------------
-- DES FAITS, ET LE MOTIF VERBATIM. Auteur, sa fonction au moment de l'acte, cible, sa fonction,
-- type d'acte, motif EXACT, consequences chiffrees, horodatage. Aucune qualification : ni
-- « abusif », ni « justifie », ni « mensonger ». Si une redaction joueuse veut ecrire qu'un
-- President est un tyran parce qu'il a sanctionne quelqu'un pour « je ne vous aime pas », c'est a
-- elle de l'ecrire -- et le motif exact est la pour qu'elle puisse le citer sans le reecrire.
--
-- RESERVEE A LA REDACTION, par le droit EXISTANT : l'appartenance a un groupe de presse.
CREATE OR REPLACE FUNCTION public.assemblee_discipline_matiere(p_limite integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_lim integer := least(greatest(coalesce(p_limite,20),1),50);
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT g.pays INTO v_pays FROM public.presse_membres m
    JOIN public.groupes_presse g ON g.id = m.groupe_id
   WHERE m.personnage = v_moi LIMIT 1;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_a_la_redaction'); END IF;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'actes', (SELECT coalesce(jsonb_agg(x ORDER BY (x->>'fait_le') DESC), '[]'::jsonb) FROM (
      SELECT jsonb_build_object(
               'id', d.id, 'type', d.genre,
               'auteur', d.president, 'auteur_fonction', d.president_fonction,
               'cible', d.cible, 'cible_fonction', d.cible_fonction,
               'motif', d.motif,
               'pop', d.pop_delta, 'amende', d.amende, 'caisse_creditee', d.caisse_creditee,
               'rappel_consomme', d.rappel_id, 'fait_le', d.fait_le) AS x
        FROM public.assemblee_disciplines d WHERE d.pays = v_pays
        ORDER BY d.fait_le DESC LIMIT v_lim) z));
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- LES DROITS
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'assemblee_president(text)', 'assemblee_est_depute(text,text)',
    'assemblee_dans_hemicycle(text,text)', 'assemblee_parti_de(text,text)',
    'assemblee_suspendue(text)',
    'assemblee_parole_demander()', 'assemblee_parole_donner(text)', 'assemblee_parole_retirer()',
    'assemblee_debat_dire(text)',
    'assemblee_rappeler(text,text)', 'assemblee_sanctionner(text,text)',
    'assemblee_protester()', 'assemblee_revenir()',
    'assemblee_suspendre_seance(text)', 'assemblee_reporter_vote(text)',
    'assemblee_seance(integer)', 'assemblee_discipline_matiere(integer)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO service_role', f);
  END LOOP;
END $$;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer;
BEGIN
  -- P1 : LES SIX TABLES SONT FERMEES AU CLIENT -- RLS active, aucune policy. Un navigateur ne peut
  -- ni s'accorder la parole, ni se declarer protestataire qualifie, ni fabriquer un rappel.
  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relrowsecurity AND c.relname IN
     ('assemblee_paroles','assemblee_debats','assemblee_disciplines','assemblee_protestations',
      'assemblee_suspensions','assemblee_reports');
  IF v_n <> 6 THEN RAISE EXCEPTION 'P1a : % tables de seance sous RLS au lieu de 6', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_policies WHERE schemaname = 'public' AND tablename IN
     ('assemblee_paroles','assemblee_debats','assemblee_disciplines','assemblee_protestations',
      'assemblee_suspensions','assemblee_reports');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1b : % policy sur les tables de seance', v_n; END IF;

  -- P2 : UN SEUL ORATEUR A LA FOIS, par index UNIQUE partiel. Deux « donner la parole » simultanes
  -- ne peuvent pas produire deux orateurs.
  SELECT count(*) INTO v_n FROM pg_indexes WHERE schemaname = 'public'
    AND indexname = 'assemblee_un_seul_orateur' AND indexdef LIKE '%UNIQUE%'
    AND indexdef LIKE '%a_la_parole%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 : l unicite de l orateur n est pas garantie'; END IF;

  -- P3 : UN RAPPEL NE SE CONSOMME QU'UNE FOIS. C'est l'index, pas une relecture, qui interdit
  -- d'enchainer deux sanctions sur un seul rappel.
  SELECT count(*) INTO v_n FROM pg_indexes WHERE schemaname = 'public'
    AND indexname = 'assemblee_un_rappel_une_sanction' AND indexdef LIKE '%UNIQUE%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 : un rappel pourrait servir deux fois'; END IF;

  -- P4 : UN TEXTE N'EST REPORTE QU'UNE FOIS par la prerogative presidentielle -- la cle primaire.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'assemblee_reports' AND c.contype = 'p'
     AND pg_get_constraintdef(c.oid) = 'PRIMARY KEY (proposition_id)';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P4 : un texte pourrait etre reporte deux fois'; END IF;

  -- P5 : UN SEUL EPISODE DE BOYCOTT OUVERT. C'est ce qui empeche un depute d'empiler des episodes
  -- en faisant hall -> hemicycle -> hall.
  SELECT count(*) INTO v_n FROM pg_indexes WHERE schemaname = 'public'
    AND indexname = 'assemblee_un_seul_boycott_ouvert' AND indexdef LIKE '%UNIQUE%'
    AND indexdef LIKE '%boycott%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P5 : deux episodes de boycott pourraient courir ensemble'; END IF;

  -- P6 : LA FORME D'UN ACTE EST CONTRAINTE. Un rappel ne porte ni amende ni rappel consomme ; une
  -- sanction porte les deux. Impossible d'ecrire une sanction sans rappel.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'assemblee_disciplines'
     AND c.conname = 'discipline_forme_coherente';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P6 : la forme rappel/sanction n est pas contrainte'; END IF;

  -- P7 : LE MOTIF EST OBLIGATOIRE, par contrainte et non par politesse d'interface.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'assemblee_disciplines'
     AND c.conname = 'discipline_motif_non_vide';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P7 : un acte sans motif pourrait etre ecrit'; END IF;

  -- P8 : AUCUNE COLONNE DE QUALIFICATION dans toute la seance. Ni abusif, ni justifie, ni
  -- mensonger, ni score : le serveur enregistre des faits. Si quelqu'un en ajoute une, cette
  -- preuve tombe.
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name IN ('assemblee_paroles','assemblee_debats','assemblee_disciplines',
                        'assemblee_protestations','assemblee_suspensions','assemblee_reports')
     AND (column_name LIKE '%abusif%' OR column_name LIKE '%justifi%'
       OR column_name LIKE '%mensong%' OR column_name LIKE '%score%'
       OR column_name LIKE '%gravite%' OR column_name LIKE '%jugement%'
       OR column_name LIKE '%legitim%' OR column_name LIKE '%pertinen%');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P8 : une colonne de qualification est apparue dans la seance'; END IF;

  -- P9 : LES DEUX PORTES SYSTEME SONT FERMEES AUX CLIENTS -- le recalcul du seuil et le report
  -- automatique du mercredi. Un joueur qui pourrait les appeler pourrait fabriquer une suspension
  -- ou repousser un vote sans etre President.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_recalculer_suspension','assemblee_reporter_si_suspendue')
     AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
     AND has_function_privilege('service_role', p.oid, 'EXECUTE');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P9 : une porte systeme de la seance est ouverte aux clients'; END IF;

  -- P10 : LA PRESIDENCE EST UN POSTE DU REGISTRE, et le socle generique la couvre deja. Elle
  -- n'est PAS dans la liste des postes elus de `poste_est_atteste` : elle tombe donc dans sa
  -- branche fail-closed, celle qui n'accepte un poste que s'il est inscrit dans postes_attribues.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'poste_est_atteste'
     AND p.prosrc LIKE '%postes_attribues%' AND p.prosrc NOT LIKE '%president_assemblee%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P10a : l attestation du poste de president a change de nature'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_president'
     AND p.prosrc LIKE '%postes_attribues%' AND p.provolatile = 's';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P10b : le resolveur de la presidence ne lit pas le registre'; END IF;

  -- P11 : NI LE PARTI NI LA QUALIFICATION NE VIENNENT DU NAVIGATEUR. `assemblee_protester` ne
  -- prend AUCUN parametre : il n'y a rien a mentir.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_protester' AND p.pronargs = 0;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P11a : la protestation accepte un parametre'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_protester'
     AND p.prosrc LIKE '%assemblee_parti_de%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P11b : le parti n est pas relu en base'; END IF;

  -- P12 : LE PRESIDENT NE CHOISIT PAS SON ORATEUR. La porte nomme son refus.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_parole_donner'
     AND p.prosrc LIKE '%pas_le_premier_de_la_file%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P12 : l ordre de la file n est pas impose'; END IF;

  -- P13 : UNE INTERVENTION SANS AUTORISATION N'EST JAMAIS SANCTIONNEE AUTOMATIQUEMENT. La porte de
  -- parole ne touche ni la popularite, ni l'argent, ni la discipline. C'est tout l'arbitrage : le
  -- President peut tolerer, ignorer, ou agir.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_debat_dire'
     AND (p.prosrc LIKE '%personnage_ajuster_pop_inf%'
       OR p.prosrc LIKE '%assemblee_disciplines%'
       OR p.prosrc LIKE '%assemblee_debiter_joueur%');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P13 : parler sans autorisation declenche un effet automatique'; END IF;

  -- P14 : LA SUSPENSION DU PRESIDENT N'EST JAMAIS UN BOYCOTT. Les deux causes sont separees par
  -- contrainte, et le compteur du §9 ne compte que les boycotts.
  SELECT count(*) INTO v_n FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid JOIN pg_namespace n ON n.oid = t.relnamespace
   WHERE n.nspname = 'public' AND t.relname = 'assemblee_suspensions'
     AND c.conname = 'suspension_cause_connue';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P14a : les causes de suspension ne sont pas contraintes'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_suspendre_seance'
     AND p.prosrc LIKE '%''presidence''%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P14b : la suspension presidentielle n est pas marquee comme telle'; END IF;

  -- P15 : LA SEANCE NAIT VIDE. Aucune parole, aucun rappel, aucune protestation, aucun episode.
  SELECT (SELECT count(*) FROM public.assemblee_paroles)
       + (SELECT count(*) FROM public.assemblee_debats)
       + (SELECT count(*) FROM public.assemblee_disciplines)
       + (SELECT count(*) FROM public.assemblee_protestations)
       + (SELECT count(*) FROM public.assemblee_suspensions)
       + (SELECT count(*) FROM public.assemblee_reports) INTO v_n;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P15 : % ligne(s) de seance a la naissance', v_n; END IF;

  RAISE NOTICE 'Seance parlementaire : les 15 preuves structurelles passent.';
END $$;
