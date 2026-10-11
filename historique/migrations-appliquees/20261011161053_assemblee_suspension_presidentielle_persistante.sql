-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011161053 (UTC), nom
-- `assemblee_suspension_presidentielle_persistante`.
-- Le registre passe de 656 a 657 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 064cb9cf5df2c93d709fdb5801c6f2ae, 38991 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE SEANCE SUSPENDUE RESTE SUSPENDUE JUSQU'A CE QUE LE PRESIDENT LA REPRENNE
--
-- La deuxieme passe n'avait enregistre qu'un ACTE ponctuel, et elle disait pourquoi : l'arbitrage
-- donnait le cout mais ni la duree, ni la reprise, et creer un etat sans sortie aurait cree un
-- etat BLOQUE. La sortie est maintenant arbitree -- « Reprendre la seance », decidee par le
-- President seul, sans cout -- donc l'etat peut exister.
-- CE QUE LA SUSPENSION SUSPEND : la parole (demander, donner, retirer), le debat, et la police de
-- seance -- rappel et sanction. Une seance suspendue est une seance ou l'on ne parle pas.
-- CE QU'ELLE NE SUSPEND PAS, et c'est deliberе : quitter l'hemicycle et y revenir restent des
-- actes PHYSIQUES ; le seuil de boycott continue de se compter ; et le report d'un vote reste une
-- prerogative sur le CALENDRIER, pas un acte de seance.
-- ELLE N'EST JAMAIS UN BOYCOTT. `assemblee_suspendue` -- la question que pose le depouillement du
-- mercredi -- continue de ne regarder QUE les boycotts, et le compteur des episodes aussi.
-- UN POINT N'EST PAS ARBITRE ET N'A PAS ETE DEVINE : ce qui arrive a un scrutin qui arrive a
-- echeance pendant une suspension presidentielle. Le boycott a sa regle explicite, la suspension
-- presidentielle n'en a aucune : le comportement actuel est donc INCHANGE, et le point est au
-- rapport.
-- ET LE DEUXIEME BOYCOTT REMET LA PRESIDENCE EN JEU. Le compteur existait depuis la deuxieme
-- passe et ne declenchait rien, faute d'election. Le deuxieme episode DISTINCT sous une meme
-- presidence inscrit desormais une election DUE, que la convocation du lundi ouvre. On n'ouvre
-- pas le scrutin dans la transaction d'une protestation : un clic de joueur ne doit pas
-- declencher une election au milieu de son propre acte.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- UNE SEANCE SUSPENDUE RESTE SUSPENDUE JUSQU'A CE QUE LE PRESIDENT LA REPRENNE (11 octobre 2026)
-- =================================================================================================
-- LA DEUXIEME PASSE N'AVAIT ENREGISTRE QU'UN ACTE PONCTUEL, et elle disait pourquoi : l'arbitrage
-- donnait le cout mais ni la duree, ni la reprise, et creer un etat sans sortie aurait cree un etat
-- BLOQUE. La sortie est maintenant arbitree -- « Reprendre la seance », decidee par le President
-- seul, sans cout -- donc l'etat peut exister.
--
-- CE QUE LA SUSPENSION SUSPEND, ET RIEN DE PLUS. Une seance suspendue est une seance ou l'on ne
-- parle pas : on ne demande pas la parole, on ne la donne pas, on ne la retire pas, on n'intervient
-- pas au debat, et le President ne police pas une seance qui ne siege pas -- ni rappel, ni sanction.
-- CE QU'ELLE NE SUSPEND PAS, et c'est deliberе : quitter l'hemicycle et y revenir restent des actes
-- PHYSIQUES, qu'une suspension n'empeche pas ; le seuil de boycott continue donc de se compter ; et
-- le report d'un vote reste une prerogative sur le CALENDRIER, pas un acte de seance.
--
-- ELLE N'EST JAMAIS UN BOYCOTT. `assemblee_suspendue` -- la question que pose le depouillement du
-- mercredi -- continue de ne regarder QUE les boycotts, et le compteur des episodes aussi. Une
-- suspension presidentielle ne peut donc ni reporter un scrutin, ni remettre la presidence en jeu.
--
-- UN POINT N'EST PAS ARBITRE ET N'A PAS ETE DEVINE : ce qui arrive a un scrutin qui ARRIVE A
-- ECHEANCE pendant une suspension presidentielle. Le boycott a sa regle explicite -- le vote part
-- d'une semaine --, la suspension presidentielle n'en a aucune. Le comportement actuel est donc
-- INCHANGE : le depouillement du mercredi se tient. Creer un report supplementaire aurait ete
-- inventer une regle, et c'est precisement ce que le prompt interdit. LE POINT EST AU RAPPORT.
--
-- ET LE DEUXIEME BOYCOTT REMET LA PRESIDENCE EN JEU. Le compteur existait depuis la deuxieme
-- passe et ne declenchait rien, faute d'election. L'election existe : le deuxieme episode DISTINCT
-- sous une meme presidence inscrit desormais une election DUE, que la convocation du lundi ouvre.
-- On n'ouvre pas le scrutin dans la transaction d'une protestation : un clic de joueur ne doit pas
-- declencher une election au milieu de son propre acte.
-- =================================================================================================

ALTER TABLE public.assemblee_suspensions ADD COLUMN IF NOT EXISTS reprise_requete text;
ALTER TABLE public.assemblee_suspensions ADD COLUMN IF NOT EXISTS reprise_le timestamptz;

-- UNE SEULE SUSPENSION PRESIDENTIELLE OUVERTE PAR PAYS. Deux clics concurrents ne peuvent pas en
-- ouvrir deux, et donc pas prelever 40 points.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_une_seule_suspension_presidence
  ON public.assemblee_suspensions (pays) WHERE cause = 'presidence' AND close_le IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS assemblee_suspensions_une_reprise
  ON public.assemblee_suspensions (reprise_requete) WHERE reprise_requete IS NOT NULL;

COMMENT ON COLUMN public.assemblee_suspensions.reprise_requete IS
  'L identifiant de la requete joueur qui a repris la seance. Unique : un rejeu -- quand la reponse s est perdue -- renvoie la reprise deja faite au lieu de repondre « aucune suspension » a un President qui venait de reussir.';

-- LA SEANCE EST-ELLE SUSPENDUE PAR SON PRESIDENT ? Question DISTINCTE de `assemblee_suspendue`,
-- qui ne regarde que les boycotts -- et qui ne doit pas changer de sens : c'est elle que le
-- depouillement du mercredi interroge.
CREATE OR REPLACE FUNCTION public.assemblee_suspendue_par_la_presidence(p_pays text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (SELECT 1 FROM public.assemblee_suspensions
                  WHERE pays = p_pays AND cause = 'presidence' AND close_le IS NULL);
$function$;

-- -------------------------------------------------------------------------------------------------
-- SUSPENDRE
-- -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_suspendre_seance(p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SUSPENSION constant integer := -20;
  v_moi text; v_pays text; v_id text; v_m text; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_suspensions WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'suspension', d.id, 'pop', POP_SUSPENSION,
                              'compte_pour_le_boycott', false,
                              'ouverte', d.close_le IS NULL);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  -- ON NE SUSPEND PAS UNE SEANCE DEJA SUSPENDUE : ce serait payer deux fois pour le meme etat.
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_suspendue'); END IF;

  -- LE MOTIF EST CONSERVE S'IL EST DONNE, ET N'EST NI EXIGE NI JUGE : l'arbitrage ne le rend pas
  -- obligatoire pour cette prerogative, contrairement au rappel et a la sanction.
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  v_id := 'suspension-pres-' || left(md5(p_requete), 20);

  -- IL SE PAIE LUI-MEME, et le registre des causes le verifie. Un refus annule tout : pas de
  -- suspension gratuite.
  v_pop := public.personnage_ajuster_pop_inf(v_moi, v_moi, POP_SUSPENSION, NULL, 'assemblee_suspension_seance');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_suspension_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  -- `close_le` RESTE NUL : l'etat PERSISTE jusqu'a la reprise. C'est tout l'arbitrage neuf.
  INSERT INTO public.assemblee_suspensions (id, pays, cause, president, motif, requete)
  VALUES (v_id, v_pays, 'presidence', v_moi, v_m, p_requete);

  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'pop', POP_SUSPENSION,
                            'compte_pour_le_boycott', false, 'ouverte', true,
                            'pop_president', v_pop -> 'pop');
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- REPRENDRE
-- -------------------------------------------------------------------------------------------------
-- LE PRESIDENT SEUL, ET SANS NOUVEAU COUT. Il a paye pour suspendre ; reprendre n'est pas un
-- second acte, c'est la fin du premier.
CREATE OR REPLACE FUNCTION public.assemblee_reprendre_seance(p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_id text; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE : sans elle, un rejeu repondrait « aucune suspension » a un President dont la reprise
  -- venait d'aboutir.
  SELECT * INTO d FROM public.assemblee_suspensions WHERE reprise_requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'suspension', d.id);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  SELECT id INTO v_id FROM public.assemblee_suspensions
   WHERE pays = v_pays AND cause = 'presidence' AND close_le IS NULL FOR UPDATE;
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_suspension'); END IF;

  UPDATE public.assemblee_suspensions
     SET close_le = clock_timestamp(), reprise_le = clock_timestamp(), reprise_requete = p_requete
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'reprise', true, 'pop', 0);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- CE QUE LA SUSPENSION SUSPEND : LA PAROLE, LE DEBAT, LA POLICE DE SEANCE
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
  -- UNE SEANCE SUSPENDUE NE DISTRIBUE PAS LA PAROLE.
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;

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
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;

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

  UPDATE public.assemblee_paroles SET a_la_parole = true, donnee_le = clock_timestamp()
   WHERE pays = v_pays AND depute = v_premier;
  RETURN jsonb_build_object('ok', true, 'orateur', v_premier);
END;
$function$;

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
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;

  SELECT depute INTO v_orateur FROM public.assemblee_paroles
   WHERE pays = v_pays AND a_la_parole FOR UPDATE;
  IF v_orateur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_orateur'); END IF;

  DELETE FROM public.assemblee_paroles WHERE pays = v_pays AND depute = v_orateur;
  RETURN jsonb_build_object('ok', true, 'retire', v_orateur);
END;
$function$;

CREATE OR REPLACE FUNCTION public.assemblee_debat_dire(p_texte text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_t text; v_id text; v_autorise boolean; v_fonction text; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUTE ECRITURE.
  SELECT * INTO d FROM public.assemblee_debats WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'id', d.id, 'autorise', d.autorise);
  END IF;

  v_t := nullif(btrim(coalesce(p_texte, '')), '');
  IF v_t IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'texte_vide'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  -- ON NE PARLE PAS DANS UNE SEANCE SUSPENDUE -- pas meme le President : c'est lui qui l'a
  -- suspendue, et il a « Reprendre la seance » pour la rouvrir.
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;

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

  -- L'IDENTIFIANT EST DERIVE DE LA REQUETE : deuxieme garde, portee par la cle primaire.
  v_id := 'debat-' || left(md5(p_requete), 20);
  INSERT INTO public.assemblee_debats (id, pays, auteur, auteur_fonction, texte, autorise, requete)
  VALUES (v_id, v_pays, v_moi, v_fonction, left(v_t, 4000), v_autorise, p_requete);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'autorise', v_autorise);
END;
$function$;

-- LE RAPPEL ET LA SANCTION : LA POLICE D'UNE SEANCE QUI NE SIEGE PAS N'A RIEN A POLICER.
CREATE OR REPLACE FUNCTION public.assemblee_rappeler(p_depute text, p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_RAPPEL constant integer := -15;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_disciplines WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'rappel', d.id, 'cible', d.cible, 'pop', d.pop_delta);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF p_depute IS NULL OR p_depute = v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;
  IF NOT public.assemblee_dans_hemicycle(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_absente_de_l_hemicycle'); END IF;

  v_pop := public.personnage_ajuster_pop_inf(v_moi, p_depute, POP_RAPPEL, NULL, 'assemblee_rappel');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_rappel_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  v_id    := 'rappel-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_rappel-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     chronique_id, requete)
  VALUES (v_id, v_pays, 'rappel', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_RAPPEL, v_chron, p_requete);

  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, v_pays, 'assemblee_rappel', 'capitale',
          jsonb_build_array(v_moi, p_depute),
          'Le President de l''Assemblee a rappele ' || p_depute || ' au reglement.',
          jsonb_build_object('president', v_moi, 'cible', p_depute, 'motif', v_m,
                             'pop', POP_RAPPEL, 'discipline', v_id),
          v_id);

  RETURN jsonb_build_object('ok', true, 'rappel', v_id, 'cible', p_depute,
                            'pop', POP_RAPPEL, 'pop_cible', v_pop -> 'pop');
END;
$function$;

CREATE OR REPLACE FUNCTION public.assemblee_sanctionner(p_depute text, p_motif text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  POP_SANCTION constant integer := -20;
  AMENDE       constant integer := 100;
  v_moi text; v_pays text; v_m text; v_id text; v_chron text; v_rappel text;
  v_caisse text; v_paye boolean; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_disciplines WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'sanction', d.id, 'cible', d.cible, 'pop', d.pop_delta,
                              'amende', d.amende, 'caisse', d.caisse_creditee,
                              'rappel_consomme', d.rappel_id);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;
  IF public.assemblee_suspendue_par_la_presidence(v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'seance_suspendue'); END IF;
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;

  SELECT x.id INTO v_rappel FROM public.assemblee_disciplines x
   WHERE x.pays = v_pays AND x.genre = 'rappel' AND x.cible = p_depute
     AND x.president = v_moi
     AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = x.id)
   ORDER BY x.fait_le
   FOR UPDATE
   LIMIT 1;
  IF v_rappel IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_rappel_a_consommer'); END IF;

  v_paye := public.helvetia_debiter_fonds_ordinaires(p_depute, AMENDE);
  IF v_paye IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'montant_requis', AMENDE, 'cible', p_depute);
  END IF;
  v_caisse := v_pays || '_assemblee';
  PERFORM public.assemblee_crediter_caisse(v_caisse, AMENDE);

  v_pop := public.personnage_ajuster_pop_inf(v_moi, p_depute, POP_SANCTION, NULL, 'assemblee_sanction');
  IF coalesce((v_pop->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'assemblee_sanction_popularite_refusee: %', coalesce(v_pop->>'raison', 'inconnue');
  END IF;

  v_id    := 'sanction-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_sanction-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     amende, caisse_creditee, rappel_id, chronique_id, requete)
  VALUES (v_id, v_pays, 'sanction', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_SANCTION, AMENDE, v_caisse, v_rappel, v_chron, p_requete);

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
                            'caisse', v_caisse, 'pop_cible', v_pop -> 'pop');
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- LE DEUXIEME EPISODE DE BOYCOTT REMET LA PRESIDENCE EN JEU
-- -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assemblee_recalculer_suspension(p_pays text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  SEUIL constant integer := 5;
  v_qualifies integer; v_dehors integer; v_ouvert text; v_id text; v_pres text;
  v_episodes integer; v_due boolean := false;
BEGIN
  SELECT count(*) FILTER (WHERE qualifie), count(*)
    INTO v_qualifies, v_dehors
    FROM public.assemblee_protestations WHERE pays = p_pays;

  SELECT id INTO v_ouvert FROM public.assemblee_suspensions
   WHERE pays = p_pays AND cause = 'boycott' AND close_le IS NULL FOR UPDATE;

  IF v_ouvert IS NOT NULL AND v_qualifies < SEUIL THEN
    -- clock_timestamp() et non now() : la fermeture doit etre POSTERIEURE aux sorties inscrites
    -- dans la meme transaction, sinon le test de dissolution complete ci-dessous ne tranche plus.
    UPDATE public.assemblee_suspensions SET close_le = clock_timestamp() WHERE id = v_ouvert;
    v_ouvert := NULL;
  ELSIF v_ouvert IS NULL AND v_qualifies >= SEUIL THEN
    -- DISSOLUTION COMPLETE EXIGEE : s'il reste un protestataire qualifie depuis l'episode
    -- precedent, on est dans le MEME boycott et on ne l'ouvre pas une seconde fois. 5 -> 4 -> 5,
    -- 5 -> 3 -> 1 -> 5 : meme episode. Seul un retour a ZERO le termine.
    IF EXISTS (SELECT 1 FROM public.assemblee_suspensions s
                WHERE s.pays = p_pays AND s.cause = 'boycott' AND s.close_le IS NOT NULL
                  AND EXISTS (SELECT 1 FROM public.assemblee_protestations p
                               WHERE p.pays = p_pays AND p.qualifie
                                 AND p.sorti_le < s.close_le)) THEN
      NULL;   -- meme boycott : aucun episode neuf
    ELSE
      v_pres := public.assemblee_president(p_pays);
      v_id := 'suspension-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS');
      INSERT INTO public.assemblee_suspensions (id, pays, cause, president, protestataires)
      VALUES (v_id, p_pays, 'boycott', v_pres,
              (SELECT coalesce(jsonb_agg(depute ORDER BY depute), '[]'::jsonb)
                 FROM public.assemblee_protestations
                WHERE pays = p_pays AND qualifie));
      v_ouvert := v_id;

      -- LE DEUXIEME EPISODE DISTINCT SOUS UNE MEME PRESIDENCE REMET LA PRESIDENCE EN JEU. On
      -- inscrit que l'election est DUE ; la convocation du lundi l'ouvrira. Ouvrir le scrutin ici
      -- reviendrait a declencher une election dans la transaction du clic d'un depute.
      SELECT count(*) INTO v_episodes FROM public.assemblee_suspensions s
       WHERE s.pays = p_pays AND s.cause = 'boycott'
         AND s.president IS NOT DISTINCT FROM v_pres;
      IF v_episodes >= 2
         AND NOT EXISTS (SELECT 1 FROM public.assemblee_presidence_dues u
                          WHERE u.pays = p_pays AND u.honore_le IS NULL) THEN
        INSERT INTO public.assemblee_presidence_dues (id, pays, cause, episode_id)
        VALUES ('due-' || p_pays || '-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS'),
                p_pays, 'deux_boycotts', v_id);
        v_due := true;
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object('suspendue', v_ouvert IS NOT NULL, 'episode', v_ouvert,
                            'qualifies', v_qualifies, 'dehors', v_dehors, 'seuil', SEUIL,
                            'election_presidentielle_due', v_due);
END;
$function$;

REVOKE ALL ON FUNCTION public.assemblee_recalculer_suspension(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_recalculer_suspension(text) FROM anon;
REVOKE ALL ON FUNCTION public.assemblee_recalculer_suspension(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_recalculer_suspension(text) TO service_role;

-- -------------------------------------------------------------------------------------------------
-- L'ETAT DE LA SEANCE REND LA SUSPENSION PRESIDENTIELLE
-- -------------------------------------------------------------------------------------------------
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
    -- DEUX SUSPENSIONS DISTINCTES, ET ELLES NE SE CONFONDENT JAMAIS. Le boycott empeche un vote de
    -- conclure ; la suspension presidentielle arrete la seance elle-meme.
    'suspendue_par_la_presidence', public.assemblee_suspendue_par_la_presidence(v_pays),
    'suspension_presidence', (SELECT to_jsonb(z) FROM (
        SELECT s.id, s.president, s.motif, s.ouverte_le FROM public.assemblee_suspensions s
         WHERE s.pays = v_pays AND s.cause = 'presidence' AND s.close_le IS NULL LIMIT 1) z),
    'deputes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'depute', o.pj_nom, 'ville', o.city,
                   'dans_hemicycle', public.assemblee_dans_hemicycle(v_pays, o.pj_nom),
                   'parti', public.assemblee_parti_de(v_pays, o.pj_nom))
                 ORDER BY o.city, o.rang), '[]'::jsonb)
       FROM public.assemblee_occupation_sieges(v_pays) o WHERE o.pj_nom IS NOT NULL),
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
    'rappels_consommables', (SELECT coalesce(jsonb_agg(d.cible ORDER BY d.cible), '[]'::jsonb)
       FROM public.assemblee_disciplines d
      WHERE d.pays = v_pays AND d.genre = 'rappel' AND d.president IS NOT DISTINCT FROM v_pres
        AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = d.id)),
    'textes_reportes', (SELECT coalesce(jsonb_agg(r.proposition_id ORDER BY r.proposition_id), '[]'::jsonb)
       FROM public.assemblee_reports r WHERE r.pays = v_pays),
    'episodes_sous_cette_presidence', (SELECT count(*) FROM public.assemblee_suspensions s
       WHERE s.pays = v_pays AND s.cause = 'boycott'
         AND s.president IS NOT DISTINCT FROM v_pres),
    -- UNE ELECTION EXCEPTIONNELLE EST-ELLE DUE ? Un fait rendu, et c'est la convocation du lundi
    -- qui l'ouvrira -- pas cet ecran.
    'election_presidentielle_due', EXISTS (SELECT 1 FROM public.assemblee_presidence_dues u
       WHERE u.pays = v_pays AND u.honore_le IS NULL));
END;
$function$;

DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'assemblee_suspendue_par_la_presidence(text)', 'assemblee_reprendre_seance(text)',
    'assemblee_suspendre_seance(text,text)', 'assemblee_parole_demander()',
    'assemblee_parole_donner(text)', 'assemblee_parole_retirer()',
    'assemblee_debat_dire(text,text)', 'assemblee_rappeler(text,text,text)',
    'assemblee_sanctionner(text,text,text)', 'assemblee_seance(integer)'] LOOP
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
DECLARE v_n integer; v_src text;
BEGIN
  -- P1 : UNE SEULE SUSPENSION PRESIDENTIELLE OUVERTE PAR PAYS. Deux clics ne couteraient pas
  -- 40 points.
  SELECT count(*) INTO v_n FROM pg_indexes WHERE schemaname = 'public' AND indexdef LIKE '%UNIQUE%'
    AND indexname IN ('assemblee_une_seule_suspension_presidence', 'assemblee_suspensions_une_reprise');
  IF v_n <> 2 THEN RAISE EXCEPTION 'P1 : % index d unicite de suspension au lieu de 2', v_n; END IF;

  -- P2 : L'ETAT PERSISTE. La suspension n'est plus close dans la seconde : la porte n'ecrit plus
  -- close_le a l'insertion.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_suspendre_seance';
  IF v_src LIKE '%close_le, requete%' OR v_src LIKE '%clock_timestamp(), p_requete)%' THEN
    RAISE EXCEPTION 'P2 : la suspension presidentielle se referme encore immediatement';
  END IF;
  IF v_src NOT LIKE '%deja_suspendue%' THEN
    RAISE EXCEPTION 'P2b : on pourrait suspendre une seance deja suspendue';
  END IF;

  -- P3 : SEUL LE PRESIDENT REPREND, ET LA REPRISE NE COUTE RIEN.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_reprendre_seance';
  IF v_src NOT LIKE '%pas_le_president%' THEN
    RAISE EXCEPTION 'P3a : n importe qui pourrait reprendre la seance';
  END IF;
  IF v_src LIKE '%personnage_ajuster_pop_inf%' OR v_src LIKE '%helvetia_debiter%' THEN
    RAISE EXCEPTION 'P3b : la reprise de seance a un cout';
  END IF;

  -- P4 : SIX PORTES DE SEANCE REFUSENT PENDANT UNE SUSPENSION PRESIDENTIELLE -- la parole (trois),
  -- le debat, le rappel et la sanction. Une seance suspendue ne siege pas.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_parole_demander','assemblee_parole_donner',
                       'assemblee_parole_retirer','assemblee_debat_dire',
                       'assemblee_rappeler','assemblee_sanctionner')
     AND p.prosrc LIKE '%assemblee_suspendue_par_la_presidence%'
     AND p.prosrc LIKE '%seance_suspendue%';
  IF v_n <> 6 THEN RAISE EXCEPTION 'P4 : % porte(s) sur 6 respectent la suspension', v_n; END IF;

  -- P5 : LA PROTESTATION ET LE RETOUR NE SONT PAS SUSPENDUS. Ce sont des actes PHYSIQUES : une
  -- suspension n'enferme personne dans l'hemicycle.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname IN ('assemblee_protester','assemblee_revenir')
     AND p.prosrc LIKE '%seance_suspendue%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P5 : la suspension empeche de quitter ou regagner l hemicycle'; END IF;

  -- P6 : `assemblee_suspendue` NE REGARDE TOUJOURS QUE LES BOYCOTTS. C'est elle que le
  -- depouillement du mercredi interroge : si elle changeait de sens, une suspension
  -- presidentielle reporterait les scrutins -- une regle que personne n'a arbitree.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_suspendue';
  IF v_src NOT LIKE '%''boycott''%' OR v_src LIKE '%presidence%' THEN
    RAISE EXCEPTION 'P6 : assemblee_suspendue ne distingue plus le boycott de la presidence';
  END IF;
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_reporter_si_suspendue';
  IF v_src LIKE '%presidence%' THEN
    RAISE EXCEPTION 'P6b : le report automatique du mercredi tient compte de la presidence';
  END IF;

  -- P7 : LE COMPTEUR D'EPISODES NE COMPTE QUE LES BOYCOTTS, et le declenchement aussi.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_recalculer_suspension';
  IF v_src NOT LIKE '%s.cause = ''boycott''%' THEN
    RAISE EXCEPTION 'P7a : le compteur d episodes ne se borne pas aux boycotts';
  END IF;
  IF v_src NOT LIKE '%v_episodes >= 2%'
     OR v_src NOT LIKE '%assemblee_presidence_dues%' THEN
    RAISE EXCEPTION 'P7b : le deuxieme episode ne remet pas la presidence en jeu';
  END IF;

  -- P8 : LE DEUXIEME EPISODE N'OUVRE PAS LE SCRUTIN LUI-MEME. Un clic de depute ne doit pas
  -- declencher une election dans sa propre transaction.
  IF v_src LIKE '%assemblee_presidence_convoquer%'
     OR v_src LIKE '%INSERT INTO public.assemblee_presidence_scrutins%' THEN
    RAISE EXCEPTION 'P8 : la protestation ouvre une election dans sa propre transaction';
  END IF;

  -- P9 : LA REGLE DE DISSOLUTION COMPLETE EST INTACTE. 5 -> 4 -> 5 reste le MEME episode.
  IF v_src NOT LIKE '%p.sorti_le < s.close_le%' THEN
    RAISE EXCEPTION 'P9 : la regle de dissolution complete a disparu';
  END IF;

  -- P10 : L'ETAT DE SEANCE REND LES DEUX SUSPENSIONS SEPAREMENT.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_seance';
  IF v_src NOT LIKE '%suspendue_par_la_presidence%' OR v_src NOT LIKE '%''suspendue''%' THEN
    RAISE EXCEPTION 'P10 : l etat de seance confond les deux suspensions';
  END IF;

  RAISE NOTICE 'Suspension presidentielle persistante : les 10 preuves structurelles passent.';
END $$;
