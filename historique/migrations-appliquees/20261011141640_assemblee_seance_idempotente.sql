-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011141640 (UTC), nom `assemblee_seance_idempotente`.
-- Le registre passe de 649 a 650 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 1f7ca1ce5e8769b3d0d93dc0caba42e7, 27434 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE REPONSE PERDUE NE DOIT PAS COUTER DEUX FOIS
--
-- CORRECTIF D'UN DEFAUT DE LA MIGRATION PRECEDENTE (20261011140837), trouve en branchant le
-- client. Le socle client du jeu REJOUE une action dont la reponse s'est perdue, avec le meme
-- identifiant de requete -- bonne regle, mais elle n'a de sens que si la porte serveur
-- reconnait cet identifiant. Les cinq portes de seance a effet ne le reconnaissaient pas : un
-- rappel rejoue retirait 30 points de popularite au lieu de 15, une sanction 40 points et
-- 200 FR, une suspension presidentielle 40 points, et une intervention apparaissait deux fois.
-- Rien de tout cela n'etait visible : le joueur voyait son action « echouer », puis ses points
-- partir.
-- LA GARDE EST DOUBLE. Une garde explicite avant toute ecriture, qui renvoie l'acte deja
-- enregistre avec `rejeu: true` ; et un identifiant DERIVE de l'empreinte de la requete, si bien
-- que meme une course entre deux transactions violerait la cle primaire et serait annulee
-- ENTIEREMENT -- donc sans demi-effet : ni popularite sans ligne, ni amende sans caisse creditee.
-- C'est le patron d'idempotence deja en service dans le jeu (`requete_deja_honoree`), etendu a la
-- seance et non reinvente.
-- LES ANCIENNES SIGNATURES SONT SUPPRIMEES, pas laissees en surcharge : une porte sans clef a
-- cote d'une porte avec clef, c'est le defaut intact, appelable par son nom. Une preuve verifie
-- qu'aucune des cinq ne survit avec son ancien nombre d'arguments.
-- ET LES QUATRE PORTES SANS EFFET CUMULABLE N'ONT RIEN RECU -- demander, donner et retirer la
-- parole, protester, revenir : leur idempotence vient de leur cle primaire. Une preuve verifie
-- qu'aucune clef inutile n'y a ete ajoutee : le decor finit toujours par etre pris pour une
-- garantie.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- UNE REPONSE PERDUE NE DOIT PAS COUTER DEUX FOIS (11 octobre 2026)
-- =================================================================================================
-- LE DEFAUT QUE CETTE MIGRATION CORRIGE. Le socle client du jeu -- `assembleeActionServeur`,
-- plateau-assemblee.js -- REJOUE une action dont la reponse s'est perdue en route, avec le MEME
-- identifiant de requete. C'est une bonne regle : elle garantit qu'un effet serveur n'est jamais
-- ignore par le navigateur. Mais elle n'a de sens que si la porte serveur RECONNAIT l'identifiant.
--
-- Les cinq portes de seance qui ont un effet ne le reconnaissaient pas. Un rappel au reglement
-- rejoue retirait 30 points de popularite au lieu de 15 ; une sanction rejouee en retirait 40 et
-- prelevait 200 FR ; une suspension presidentielle rejouee coutait 40 points ; une intervention
-- rejouee apparaissait deux fois au debat. Aucun de ces effets n'etait voulu, et aucun n'etait
-- visible : le joueur voyait seulement son action « echouer » puis ses points partir.
--
-- LA GARDE EST DOUBLE, ET C'EST VOULU.
--   1. UNE GARDE EXPLICITE, avant toute ecriture : si la requete a deja ete honoree, la porte
--      renvoie le resultat deja enregistre, avec `rejeu: true`, et ne touche a rien.
--   2. UN IDENTIFIANT DERIVE DE LA REQUETE : la cle primaire de la ligne ecrite est calculee a
--      partir de l'empreinte de la requete. Meme si la garde etait un jour contournee par une
--      course entre deux transactions, la seconde violerait la cle primaire et serait annulee
--      ENTIEREMENT -- donc sans demi-effet : ni POP sans ligne, ni amende sans caisse.
-- C'est le patron d'idempotence deja en service dans le jeu (`ventes_snapshots`,
-- `requete_deja_honoree`) : on ne l'invente pas, on l'etend a la seance.
--
-- LES QUATRE PORTES SANS EFFET CUMULABLE N'EN ONT PAS BESOIN, et n'en recoivent pas :
-- `assemblee_parole_demander` (cle primaire, deja idempotente), `assemblee_parole_donner` et
-- `assemblee_parole_retirer` (un second appel ne fait rien et ne coute rien),
-- `assemblee_protester` et `assemblee_revenir` (upsert et delete sur une cle primaire). Ajouter
-- une clef la ou elle ne sert a rien aurait ete du decor.
-- =================================================================================================

-- -------------------------------------------------------------------------------------------------
-- 1. LA COLONNE DE REQUETE SUR LES QUATRE TABLES QUI ENREGISTRENT UN EFFET
-- -------------------------------------------------------------------------------------------------
ALTER TABLE public.assemblee_debats      ADD COLUMN IF NOT EXISTS requete text;
ALTER TABLE public.assemblee_disciplines ADD COLUMN IF NOT EXISTS requete text;
ALTER TABLE public.assemblee_suspensions ADD COLUMN IF NOT EXISTS requete text;
ALTER TABLE public.assemblee_reports     ADD COLUMN IF NOT EXISTS requete text;

-- L'UNICITE EST PARTIELLE : les lignes nees sans requete -- un episode de boycott ouvert par le
-- serveur, qui n'a pas de requete joueur -- restent possibles, et ne se genent pas entre elles.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_debats_une_requete
  ON public.assemblee_debats (requete) WHERE requete IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_disciplines_une_requete
  ON public.assemblee_disciplines (requete) WHERE requete IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_suspensions_une_requete
  ON public.assemblee_suspensions (requete) WHERE requete IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_reports_une_requete
  ON public.assemblee_reports (requete) WHERE requete IS NOT NULL;

COMMENT ON COLUMN public.assemblee_disciplines.requete IS
  'L identifiant de la requete joueur qui a produit cet acte. Unique : un rejeu de la meme requete -- quand la reponse s est perdue en route -- renvoie cet acte au lieu d en creer un second. Sans cette colonne, un rappel rejoue couterait 30 points de popularite au lieu de 15.';

-- -------------------------------------------------------------------------------------------------
-- 2. LES ANCIENNES SIGNATURES DISPARAISSENT
-- -------------------------------------------------------------------------------------------------
-- ON NE LAISSE PAS LA PORTE SANS CLEF OUVERTE A COTE DE LA PORTE AVEC CLEF. Une surcharge
-- survivante serait exactement le defaut qu'on corrige, appelable par n'importe quel client un peu
-- ancien -- ou par n'importe qui connaissant son nom.
DROP FUNCTION IF EXISTS public.assemblee_debat_dire(text);
DROP FUNCTION IF EXISTS public.assemblee_rappeler(text, text);
DROP FUNCTION IF EXISTS public.assemblee_sanctionner(text, text);
DROP FUNCTION IF EXISTS public.assemblee_suspendre_seance(text);
DROP FUNCTION IF EXISTS public.assemblee_reporter_vote(text);

-- -------------------------------------------------------------------------------------------------
-- 3. PARLER
-- -------------------------------------------------------------------------------------------------
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

-- -------------------------------------------------------------------------------------------------
-- 4. LE RAPPEL AU REGLEMENT
-- -------------------------------------------------------------------------------------------------
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

  -- LA GARDE, AVANT TOUTE ECRITURE. Un rappel rejoue rendait 30 points de popularite au lieu de 15.
  SELECT * INTO d FROM public.assemblee_disciplines WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'rappel', d.id, 'cible', d.cible, 'pop', d.pop_delta);
  END IF;

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

  v_id    := 'rappel-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_rappel-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     chronique_id, requete)
  VALUES (v_id, v_pays, 'rappel', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_RAPPEL, v_chron, p_requete);

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
-- 5. LA SANCTION
-- -------------------------------------------------------------------------------------------------
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
  v_caisse text; v_debit jsonb; v_pop jsonb; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  -- LA GARDE, AVANT TOUT DEBIT. Une sanction rejouee prelevait 200 FR et 40 points.
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
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_obligatoire'); END IF;
  IF NOT public.assemblee_est_depute(v_pays, p_depute) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_pas_deputee'); END IF;

  -- LE RAPPEL PREALABLE, NON ENCORE CONSOMME, LE PLUS ANCIEN D'ABORD. Verrouille : deux sanctions
  -- simultanees ne peuvent pas elire le meme rappel.
  SELECT x.id INTO v_rappel FROM public.assemblee_disciplines x
   WHERE x.pays = v_pays AND x.genre = 'rappel' AND x.cible = p_depute
     AND x.president = v_moi
     AND NOT EXISTS (SELECT 1 FROM public.assemblee_disciplines s WHERE s.rappel_id = x.id)
   ORDER BY x.fait_le
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

  v_id    := 'sanction-' || left(md5(p_requete), 20);
  v_chron := 'chronique-assemblee_sanction-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_disciplines
    (id, pays, genre, president, president_fonction, cible, cible_fonction, motif, pop_delta,
     amende, caisse_creditee, rappel_id, chronique_id, requete)
  VALUES (v_id, v_pays, 'sanction', v_moi, 'president_assemblee', p_depute, 'depute', v_m,
          POP_SANCTION, AMENDE, v_caisse, v_rappel, v_chron, p_requete);

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
-- 6. LA SUSPENSION PERSONNELLE DU PRESIDENT
-- -------------------------------------------------------------------------------------------------
-- L'ACTE RESTE UN ACTE, PAS UN ETAT, et la raison n'a pas change : l'arbitrage ne dit ni combien
-- de temps dure une suspension volontaire, ni comment la seance reprend. Creer un etat sans
-- condition de sortie serait creer un etat bloque. LE POINT RESTE A ARBITRER.
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
                              'compte_pour_le_boycott', false);
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF public.assemblee_president(v_pays) IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_president'); END IF;

  -- LE MOTIF EST CONSERVE S'IL EST DONNE, ET N'EST NI EXIGE NI JUGE : l'arbitrage ne le rend pas
  -- obligatoire pour cette prerogative, contrairement au rappel et a la sanction.
  v_m := nullif(btrim(coalesce(p_motif, '')), '');
  v_id := 'suspension-pres-' || left(md5(p_requete), 20);

  INSERT INTO public.assemblee_suspensions (id, pays, cause, president, motif, close_le, requete)
  VALUES (v_id, v_pays, 'presidence', v_moi, v_m, now(), p_requete);

  v_pop := public.personnage_ajuster_pop_inf(v_moi, POP_SUSPENSION, 0);
  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'pop', POP_SUSPENSION,
                            'compte_pour_le_boycott', false,
                            'pop_applique', coalesce((v_pop->>'ok')::boolean, false));
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 7. LE REPORT PRESIDENTIEL D'UN VOTE
-- -------------------------------------------------------------------------------------------------
-- ICI LA CLEF NE PROTEGE PAS D'UN DOUBLE EFFET -- la cle primaire de `assemblee_reports` s'en
-- charge deja -- ELLE PROTEGE D'UN FAUX REFUS. Sans elle, un rejeu lisait sa propre ecriture et
-- repondait « deja reporte une fois » : le President croyait son report perdu alors qu'il etait
-- enregistre.
CREATE OR REPLACE FUNCTION public.assemblee_reporter_vote(p_proposition_id text, p_requete text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; p record; v_neuve timestamptz; d record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR p_requete !~ '^rq-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;

  SELECT * INTO d FROM public.assemblee_reports WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'proposition', d.proposition_id,
                              'ancienne_cloture', d.ancienne_cloture,
                              'nouvelle_cloture', d.nouvelle_cloture);
  END IF;

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

  -- UNE SEMAINE CALENDAIRE DE PARIS, jamais +7 x 24 h : une echeance du mercredi 22 heures reste
  -- un mercredi 22 heures a travers un changement d'heure.
  v_neuve := ((p.cloture_ts AT TIME ZONE 'Europe/Paris') + interval '7 days') AT TIME ZONE 'Europe/Paris';

  INSERT INTO public.assemblee_reports
    (proposition_id, pays, president, ancienne_cloture, nouvelle_cloture, requete)
  VALUES (p_proposition_id, v_pays, v_moi, p.cloture_ts, v_neuve, p_requete);

  UPDATE public.assemblee_propositions
     SET cloture_ts = v_neuve, updated_at = now() WHERE id = p_proposition_id;

  RETURN jsonb_build_object('ok', true, 'proposition', p_proposition_id,
                            'ancienne_cloture', p.cloture_ts, 'nouvelle_cloture', v_neuve);
END;
$function$;

-- -------------------------------------------------------------------------------------------------
-- 8. LES DROITS DES CINQ PORTES RECREEES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'assemblee_debat_dire(text,text)',
    'assemblee_rappeler(text,text,text)',
    'assemblee_sanctionner(text,text,text)',
    'assemblee_suspendre_seance(text,text)',
    'assemblee_reporter_vote(text,text)'] LOOP
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
DECLARE v_n integer;
BEGIN
  -- P1 : LES QUATRE TABLES D'EFFET PORTENT UNE REQUETE UNIQUE. Sans cet index, la garde explicite
  -- serait seule, et une course entre deux transactions passerait a travers.
  SELECT count(*) INTO v_n FROM pg_indexes WHERE schemaname = 'public' AND indexdef LIKE '%UNIQUE%'
    AND indexname IN ('assemblee_debats_une_requete','assemblee_disciplines_une_requete',
                      'assemblee_suspensions_une_requete','assemblee_reports_une_requete');
  IF v_n <> 4 THEN RAISE EXCEPTION 'P1 : % index d unicite de requete au lieu de 4', v_n; END IF;

  -- P2 : AUCUNE PORTE SANS CLEF NE SURVIT. Une surcharge a l'ancienne signature serait exactement
  -- le defaut qu'on corrige, et elle serait appelable.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND (
        (p.proname = 'assemblee_debat_dire'       AND p.pronargs <> 2)
     OR (p.proname = 'assemblee_rappeler'         AND p.pronargs <> 3)
     OR (p.proname = 'assemblee_sanctionner'      AND p.pronargs <> 3)
     OR (p.proname = 'assemblee_suspendre_seance' AND p.pronargs <> 2)
     OR (p.proname = 'assemblee_reporter_vote'    AND p.pronargs <> 2));
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 : % porte(s) de seance sans clef d idempotence survit', v_n; END IF;

  -- P3 : LES CINQ PORTES VALIDENT LA REQUETE ET RECONNAISSENT UN REJEU.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_debat_dire','assemblee_rappeler','assemblee_sanctionner',
                       'assemblee_suspendre_seance','assemblee_reporter_vote')
     AND p.prosrc LIKE '%requete_invalide%'
     AND p.prosrc LIKE '%requete_deja_honoree%'
     AND p.prosrc LIKE '%^rq-[A-Za-z0-9-]{6,80}$%';
  IF v_n <> 5 THEN RAISE EXCEPTION 'P3 : % porte(s) sur 5 gardent la requete', v_n; END IF;

  -- P4 : LA SECONDE GARDE -- L'IDENTIFIANT EST DERIVE DE LA REQUETE. Meme si la garde explicite
  -- etait contournee par une course, la cle primaire annulerait la seconde transaction ENTIEREMENT.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_debat_dire','assemblee_rappeler','assemblee_sanctionner',
                       'assemblee_suspendre_seance')
     AND p.prosrc LIKE '%left(md5(p_requete), 20)%';
  IF v_n <> 4 THEN RAISE EXCEPTION 'P4 : % porte(s) sur 4 derivent leur identifiant de la requete', v_n; END IF;

  -- P5 : LA GARDE PASSE AVANT L'EFFET. Dans chacune des trois portes couteuses, la lecture de la
  -- requete deja honoree precede le premier INSERT et le premier debit.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_rappeler','assemblee_sanctionner','assemblee_suspendre_seance')
     AND position('requete_deja_honoree' in p.prosrc) > 0
     AND position('requete_deja_honoree' in p.prosrc) < position('INSERT INTO' in p.prosrc)
     AND (position('assemblee_debiter_joueur' in p.prosrc) = 0
       OR position('requete_deja_honoree' in p.prosrc) < position('assemblee_debiter_joueur' in p.prosrc));
  IF v_n <> 3 THEN RAISE EXCEPTION 'P5 : % porte(s) sur 3 gardent AVANT l effet', v_n; END IF;

  -- P6 : LES CINQ PORTES RESTENT FERMEES A `anon`. Un visiteur non identifie ne preside rien.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_debat_dire','assemblee_rappeler','assemblee_sanctionner',
                       'assemblee_suspendre_seance','assemblee_reporter_vote')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_n <> 5 THEN RAISE EXCEPTION 'P6 : une porte de seance est ouverte a anon ou fermee aux joueurs'; END IF;

  -- P7 : LES QUATRE PORTES SANS EFFET CUMULABLE N'ONT PAS RECU DE CLEF, et c'est voulu : leur
  -- idempotence vient de leur cle primaire, pas d'un identifiant de requete. Une clef inutile
  -- serait du decor, et le decor finit par etre pris pour une garantie.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('assemblee_parole_demander','assemblee_parole_donner',
                       'assemblee_parole_retirer','assemblee_protester','assemblee_revenir')
     AND p.prosrc LIKE '%p_requete%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P7 : une porte sans effet cumulable a recu une clef inutile'; END IF;

  RAISE NOTICE 'Idempotence de la seance : les 7 preuves structurelles passent.';
END $$;
