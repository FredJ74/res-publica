-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011172314 (UTC), nom
-- `assemblee_suspension_seuil_une_heure`.
-- Le registre passe de 660 a 661 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 ef52fa29db9af8f99a8f0ba4606ab5da, 28392 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- UNE SUSPENSION QUI DEPASSE L HEURE RENVOIE LES SCRUTINS A LA PROCHAINE SESSION
--
-- Ce que l'arbitrage empeche : un President qui attend que son camp ait vote, suspend la seance
-- avant que l'opposition puisse voter, et laisse l'echeance passer. Deux regles, et elles sont
-- nettes. Suspension <= 1 heure : AUCUN effet sur le calendrier, l'echeance initiale demeure.
-- Suspension > 1 heure : les scrutins geles sont RENVOYES a la prochaine session parlementaire, les
-- suffrages deja exprimes sont ANNULES, le scrutin repart de zero.
-- « PROCHAINE SESSION PARLEMENTAIRE » N'EST PAS INVENTEE ICI. L'existant possedait deja la notion,
-- et plus precise qu'un « +7 jours » : le RENVOI du §27. Une proposition renvoyee porte
-- statut='renvoyee' / cloture_ts NULL ; la prochaine fenetre d'ouverture (mercredi 22 h de Paris,
-- et tout le jeudi) la reprend avec un session_num neuf, efface les votes precedents et recalcule
-- l'echeance. Cette migration ne construit donc aucun calendrier parallele : elle pose le statut de
-- renvoi et consigne la cause.
-- LE SEUIL EST MESURE EN BASE, sur `ouverte_le` / `close_le`. Aucun navigateur ouvert, aucun
-- minuteur client, aucune presence requise -- ni celle du President, ni celle des deputes. Et une
-- suspension deja reprise mais qui avait depasse l'heure est renvoyee quand meme : on ne s'en sort
-- pas en reprenant juste avant le passage du cron.
-- DEUX REGISTRES QUI NE SE TOUCHENT PAS : `assemblee_reports` reste le droit volontaire du
-- President, verrouille a une fois par texte ; `assemblee_reports_suspension` est le registre neuf
-- du renvoi pour suspension. Le droit n'est ni consomme ni rendu.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- ASSEMBLEE NATIONALE -- QUATRIEME PASSE, §4 : UNE SUSPENSION QUI DEPASSE L'HEURE RENVOIE LES
-- SCRUTINS A LA PROCHAINE SESSION
-- 11 octobre 2026
--
-- CE QUE L'ARBITRAGE EMPECHE. Un President attend que son camp ait vote, suspend la seance avant
-- que l'opposition ait pu voter, et laisse l'echeance passer : le scrutin se conclurait sur les
-- seuls bulletins deja deposes. La regle rendue est double :
--
--   A. Suspension <= 1 heure : AUCUN effet sur le calendrier legislatif. L'echeance initiale
--      demeure. Une interruption courte est une interruption, pas un report.
--   B. Suspension > 1 heure : les scrutins concernes sont RENVOYES A LA PROCHAINE SESSION
--      PARLEMENTAIRE, les suffrages deja exprimes sont ANNULES, le scrutin repart de zero et tous
--      les deputes doivent voter de nouveau.
--
-- « PROCHAINE SESSION PARLEMENTAIRE » N'EST PAS INVENTEE ICI, ELLE EXISTAIT DEJA. L'arbitrage
-- interdit de la remplacer par « +7 jours » si l'existant possede une notion plus precise. Il en
-- possede une, complete, et c'est le RENVOI du §27 :
--
--   . une proposition renvoyee porte statut='renvoyee', cloture_ts=NULL, session_ouverte_ts=NULL
--     (c'est exactement ce qu'ecrit assemblee_cloturer sur une egalite) ;
--   . assemblee_ouvrir_sessions_eligibles la reprend a la PROCHAINE FENETRE D'OUVERTURE --
--     mercredi a partir de 22 heures de Paris, et tout le jeudi (assemblee_fenetre_ouverture) ;
--   . assemblee_ouvrir_session lui donne alors un session_num NEUF, EFFACE les votes des sessions
--     precedentes, retire de nouvelles intentions PNJ, et recalcule cloture_ts au prochain
--     mercredi 22 heures de Paris.
--
-- Autrement dit : le moteur de session fait DEJA « reporter a la prochaine session, annuler les
-- suffrages, repartir de zero ». Cette migration ne construit aucun calendrier parallele ; elle
-- se contente de poser le statut de renvoi et d'en consigner la cause.
--
-- LE SEUIL EST CALCULE AU SERVEUR, ET IL NE DEPEND DE PERSONNE. Aucun navigateur ouvert, aucun
-- minuteur client, aucune presence -- ni celle du President, ni celle des deputes. La duree est
-- lue sur les deux colonnes de la suspension : `ouverte_le` et `close_le`. Une suspension encore
-- ouverte est mesuree contre l'horloge du serveur. Une suspension deja close est mesuree sur sa
-- duree reelle -- c'est ce qui interdit de suspendre une heure et demie puis de reprendre juste
-- avant le passage du cron pour effacer la trace.
--
-- QUAND LA REGLE S'APPLIQUE. Le franchissement est un FAIT, consigne des qu'il est constate ;
-- l'EFFET est pose a la premiere occasion suivante, et il y en a quatre :
--   . a la reprise de seance par le President (assemblee_reprendre_seance) ;
--   . au passage de minuit, tous les jours (cron-minuit) ;
--   . aux deux passages du lundi et du mercredi (cron-assemblee), AVANT le depouillement.
-- C'est ce dernier point qui compte : un scrutin ne peut pas se conclure sans que le seuil ait
-- ete regarde, parce que l'application precede assemblee_cloturer_echues dans la meme passe.
--
-- CE REPORT N'EST PAS LA PREROGATIVE PRESIDENTIELLE. Deux registres distincts, et ils ne se
-- touchent pas :
--   . `assemblee_reports` est le droit volontaire du President de repousser un vote d'une
--     semaine. Il est verrouille PAR PROPOSITION (`deja_reporte_une_fois`), une seule fois dans
--     la vie du texte, quel que soit son numero de session. Cette migration n'y ecrit RIEN : le
--     droit n'est donc pas consomme, et il n'est pas non plus rendu une seconde fois.
--   . `assemblee_reports_suspension` est le registre neuf : il dit quel texte a ete renvoye, par
--     quelle suspension, depuis quelle session, et combien de bulletins ont ete annules. Un
--     report pour cause de suspension est ainsi identifiable comme tel, et distinguable d'un
--     report volontaire par la seule lecture des registres.

-- ============================================================================================
-- 1. LE SEUIL, EN UN SEUL ENDROIT
-- ============================================================================================
-- Une heure, nommee une fois. L'ecran l'affiche, le serveur la mesure, les bancs la lisent : la
-- faire vivre dans trois constantes aurait garanti qu'elles divergent.
CREATE OR REPLACE FUNCTION public.assemblee_suspension_seuil()
RETURNS interval
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT interval '1 hour' $$;

COMMENT ON FUNCTION public.assemblee_suspension_seuil() IS
  'Duree au-dela de laquelle une suspension presidentielle renvoie les scrutins en cours a la '
  'prochaine session parlementaire (arbitrage du 11 octobre 2026, §4). Point de verite unique.';

-- ============================================================================================
-- 2. LE REGISTRE DES RENVOIS POUR SUSPENSION
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.assemblee_reports_suspension (
  id                 text PRIMARY KEY,
  pays               text NOT NULL,
  proposition_id     text NOT NULL,
  suspension_id      text NOT NULL REFERENCES public.assemblee_suspensions(id) ON DELETE CASCADE,
  -- La session ANNULEE : son numero, et ce qu'elle contenait au moment du renvoi.
  session_annulee    integer NOT NULL,
  bulletins_annules  integer NOT NULL DEFAULT 0,
  intentions_annulees integer NOT NULL DEFAULT 0,
  -- L'echeance que le texte avait avant le renvoi. Conservee pour que la presse et les joueurs
  -- puissent dire de quoi ils ont ete prives, pas pour recalculer quoi que ce soit.
  cloture_initiale   timestamptz,
  suspension_ouverte_le timestamptz NOT NULL,
  suspension_duree   interval NOT NULL,
  fait_le            timestamptz NOT NULL DEFAULT now()
);

-- L'IDEMPOTENCE EST PAR (SUSPENSION, TEXTE, SESSION), et non par suspension. Une suspension qui
-- reste ouverte plusieurs jours doit pouvoir renvoyer AUSSI la session suivante du meme texte :
-- une Assemblee suspendue ne legifere pas. En revanche la MEME session d'un MEME texte ne peut
-- jamais etre renvoyee deux fois par la MEME suspension -- sinon un second passage du cron
-- annulerait des bulletins deposes entre-temps.
CREATE UNIQUE INDEX IF NOT EXISTS assemblee_un_renvoi_par_session_suspendue
  ON public.assemblee_reports_suspension (suspension_id, proposition_id, session_annulee);

CREATE INDEX IF NOT EXISTS assemblee_reports_suspension_par_texte
  ON public.assemblee_reports_suspension (pays, proposition_id);

-- RLS SANS AUCUNE POLICY : la table est illisible et inecrivable en direct. Tout passe par les
-- portes SECURITY DEFINER, comme les six tables de la seance.
ALTER TABLE public.assemblee_reports_suspension ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.assemblee_reports_suspension IS
  'Renvois de scrutins causes par une suspension presidentielle de plus d''une heure (§4 du '
  '11 octobre 2026). DISTINCT de assemblee_reports, qui est la prerogative volontaire du '
  'President : ce registre ne consomme pas ce droit et ne le rend pas.';

-- La marque sur la suspension elle-meme : quand son depassement a ete constate et applique.
ALTER TABLE public.assemblee_suspensions
  ADD COLUMN IF NOT EXISTS seuil_applique_le timestamptz;

COMMENT ON COLUMN public.assemblee_suspensions.seuil_applique_le IS
  'Dernier instant ou le depassement d''une heure de cette suspension a produit un renvoi. '
  'NULL = aucun renvoi n''a encore ete pose a cause d''elle.';

-- ============================================================================================
-- 3. LE FAIT : CETTE SEANCE EST-ELLE SUSPENDUE AU-DELA DU SEUIL ?
-- ============================================================================================
-- Lecture pure, pour l'ecran. Elle ne declenche rien : elle dit l'heure.
CREATE OR REPLACE FUNCTION public.assemblee_suspension_depassee(p_pays text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  -- now() ET NON clock_timestamp() : une lecture doit rendre UN instant pour toute la requete.
  -- clock_timestamp() est reserve, dans ce projet, aux horodatages d'ORDRE ecrits en base.
  SELECT EXISTS (
    SELECT 1 FROM public.assemblee_suspensions
     WHERE pays = p_pays AND cause = 'presidence' AND close_le IS NULL
       AND (now() - ouverte_le) > public.assemblee_suspension_seuil());
$$;

-- ============================================================================================
-- 4. L'EFFET : LE RENVOI
-- ============================================================================================
-- RESERVEE AU SERVEUR ET A LA SEANCE. Elle n'est accordee ni a anon ni a authenticated : un
-- client ne peut pas la provoquer, et un joueur ne peut pas la provoquer sur commande. Les deux
-- seuls appelants sont les crons (service_role) et assemblee_reprendre_seance, qui est elle-meme
-- SECURITY DEFINER et verifie que l'appelant est le President.
CREATE OR REPLACE FUNCTION public.assemblee_suspension_appliquer_seuil(p_pays text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_seuil  interval := public.assemblee_suspension_seuil();
  s        record;
  p        record;
  v_duree  interval;
  v_bull   integer;
  v_int    integer;
  v_n      integer := 0;
  v_tot_b  integer := 0;
  v_props  jsonb := '[]'::jsonb;
  v_sus    jsonb := '[]'::jsonb;
  v_touche boolean;
BEGIN
  IF p_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_absent');
  END IF;

  FOR s IN
    SELECT * FROM public.assemblee_suspensions
     WHERE pays = p_pays
       AND cause = 'presidence'
       -- LA DUREE REELLE, close ou non. Reprendre la seance n'efface pas le depassement.
       AND (coalesce(close_le, now()) - ouverte_le) > v_seuil
       -- Borne de balayage : une suspension close depuis longtemps n'a plus rien a renvoyer, et
       -- la relire a chaque passage de cron ne servirait qu'a faire grossir la requete.
       AND (close_le IS NULL OR close_le > now() - interval '30 days')
     ORDER BY ouverte_le
     FOR UPDATE
  LOOP
    v_duree  := coalesce(s.close_le, now()) - s.ouverte_le;
    v_touche := false;

    FOR p IN
      SELECT * FROM public.assemblee_propositions
       WHERE country = p_pays
         AND statut = 'session'
         AND session_ouverte_ts IS NOT NULL
         -- Le scrutin etait ouvert PENDANT la suspension. Pour une suspension close, cela borne
         -- l'effet a ce qu'elle a reellement gele ; pour une suspension encore ouverte, cela
         -- couvre tout ce qui siege aujourd'hui.
         AND session_ouverte_ts <= coalesce(s.close_le, now())
       ORDER BY id
       FOR UPDATE
    LOOP
      -- Deja renvoye par CETTE suspension depuis CETTE session : on ne recommence pas.
      IF EXISTS (SELECT 1 FROM public.assemblee_reports_suspension r
                  WHERE r.suspension_id = s.id
                    AND r.proposition_id = p.id
                    AND r.session_annulee = p.session_num) THEN
        CONTINUE;
      END IF;

      SELECT count(*) INTO v_bull FROM public.assemblee_votes
       WHERE proposition_id = p.id AND session_num = p.session_num;
      SELECT count(*) INTO v_int FROM public.assemblee_intentions
       WHERE proposition_id = p.id AND session_num = p.session_num;

      -- LE RENVOI DU §27, MOT POUR MOT. C'est l'ecriture que fait assemblee_cloturer sur une
      -- egalite ; la prochaine fenetre d'ouverture s'occupe du reste.
      UPDATE public.assemblee_propositions
         SET statut = 'renvoyee',
             cloture_ts = NULL,
             session_ouverte_ts = NULL,
             updated_at = now()
       WHERE id = p.id;

      -- « LES SUFFRAGES DEJA EXPRIMES SONT ANNULES. » On ne se contente pas de les rendre inertes
      -- par le numero de session : on les retire. Un depute qui revient sur l'ecran doit voir un
      -- scrutin vide, pas sa propre voix dans un decompte qui ne compte plus.
      DELETE FROM public.assemblee_votes
       WHERE proposition_id = p.id AND session_num = p.session_num;
      -- Les intentions PNJ de la session annulee tombent avec elle : l'ouverture suivante en
      -- retirera de neuves au sort, comme pour n'importe quelle session.
      DELETE FROM public.assemblee_intentions
       WHERE proposition_id = p.id AND session_num = p.session_num;

      INSERT INTO public.assemblee_reports_suspension
        (id, pays, proposition_id, suspension_id, session_annulee, bulletins_annules,
         intentions_annulees, cloture_initiale, suspension_ouverte_le, suspension_duree)
      VALUES (s.id || ':' || p.id || ':' || p.session_num, p_pays, p.id, s.id, p.session_num,
              v_bull, v_int, p.cloture_ts, s.ouverte_le, v_duree);

      v_n      := v_n + 1;
      v_tot_b  := v_tot_b + v_bull;
      v_props  := v_props || to_jsonb(p.id);
      v_touche := true;
    END LOOP;

    IF v_touche THEN
      UPDATE public.assemblee_suspensions
         SET seuil_applique_le = clock_timestamp() WHERE id = s.id;
      v_sus := v_sus || to_jsonb(s.id);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true,
    'seuil', v_seuil::text,
    'suspensions', v_sus,
    'reportes', v_n,
    'propositions', v_props,
    'bulletins_annules', v_tot_b);
END;
$$;

REVOKE ALL ON FUNCTION public.assemblee_suspension_appliquer_seuil(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_suspension_appliquer_seuil(text) FROM anon;
REVOKE ALL ON FUNCTION public.assemblee_suspension_appliquer_seuil(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_suspension_appliquer_seuil(text) TO service_role;

REVOKE ALL ON FUNCTION public.assemblee_suspension_depassee(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_suspension_depassee(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_suspension_depassee(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_suspension_depassee(text) TO service_role;

REVOKE ALL ON FUNCTION public.assemblee_suspension_seuil() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assemblee_suspension_seuil() FROM anon;
GRANT EXECUTE ON FUNCTION public.assemblee_suspension_seuil() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assemblee_suspension_seuil() TO service_role;

-- ============================================================================================
-- 5. LA REPRISE REGARDE LE SEUIL AVANT DE RENDRE LA PAROLE
-- ============================================================================================
-- Inchangee par ailleurs. La seule addition est l'appel final : au moment ou la suspension se
-- ferme, sa duree devient definitive, et c'est le bon instant pour en tirer la consequence.
CREATE OR REPLACE FUNCTION public.assemblee_reprendre_seance(p_requete text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_moi text; v_pays text; v_id text; d record; v_seuil jsonb; v_duree interval;
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

  -- La duree est lue SUR LA LIGNE QU'ON VIENT D'ECRIRE, pas sur une horloge relue a cote : la
  -- valeur rendue au President est alors exactement celle que l'application du seuil mesure.
  UPDATE public.assemblee_suspensions
     SET close_le = clock_timestamp(), reprise_le = clock_timestamp(), reprise_requete = p_requete
   WHERE id = v_id
  RETURNING close_le - ouverte_le INTO v_duree;

  -- §4 : LA CONSEQUENCE, TOUT DE SUITE. Si la suspension a depasse l'heure, les scrutins qu'elle
  -- a geles sont renvoyes a la prochaine session et leurs suffrages annules -- sans attendre un
  -- cron, et sans que le President ait quoi que ce soit a decider. En deca du seuil, cet appel ne
  -- trouve rien et n'ecrit rien : l'echeance initiale demeure.
  v_seuil := public.assemblee_suspension_appliquer_seuil(v_pays);

  RETURN jsonb_build_object('ok', true, 'suspension', v_id, 'reprise', true, 'pop', 0,
                            'duree', v_duree::text,
                            'seuil_depasse', v_duree > public.assemblee_suspension_seuil(),
                            'renvois', v_seuil);
END;
$$;

-- ============================================================================================
-- 6. L'ETAT DE SEANCE DIT LE SEUIL ET LES RENVOIS
-- ============================================================================================
-- Des FAITS, jamais une qualification. L'ecran apprend depuis quand la seance est suspendue, si
-- l'heure est franchie, et quels textes ont ete renvoyes pour cette cause. Il n'apprend pas si
-- c'etait abusif : ca, ce sont les joueurs et la presse qui le diront.
--
-- LA VALEUR PAR DEFAUT DU PARAMETRE EST CONSERVEE (DEFAULT 50). La retirer n'est pas possible par
-- CREATE OR REPLACE -- PostgreSQL refuse (42P13) -- et surtout l'ecran appelle la porte sans
-- argument.
CREATE OR REPLACE FUNCTION public.assemblee_seance(p_limite integer DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
        SELECT s.id, s.president, s.motif, s.ouverte_le,
               (now() - s.ouverte_le)::text AS depuis,
               (now() - s.ouverte_le) > public.assemblee_suspension_seuil() AS seuil_depasse
          FROM public.assemblee_suspensions s
         WHERE s.pays = v_pays AND s.cause = 'presidence' AND s.close_le IS NULL LIMIT 1) z),
    -- §4 : L'HEURE EST UN FAIT PUBLIC. Le seuil est nomme une seule fois en base ; l'ecran le lit
    -- au lieu de le recopier, et ne compte rien lui-meme : il n'y a aucun minuteur client dans
    -- cette regle.
    'seuil_suspension_presidence', public.assemblee_suspension_seuil()::text,
    'suspension_presidence_depassee', public.assemblee_suspension_depassee(v_pays),
    -- LES RENVOIS POUR CAUSE DE SUSPENSION, distincts des reports volontaires ci-dessous.
    'renvois_pour_suspension', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'proposition', r.proposition_id, 'session_annulee', r.session_annulee,
                 'bulletins_annules', r.bulletins_annules, 'duree', r.suspension_duree::text,
                 'fait_le', r.fait_le) ORDER BY r.fait_le DESC), '[]'::jsonb)
       FROM public.assemblee_reports_suspension r WHERE r.pays = v_pays),
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
$$;

-- ============================================================================================
-- PREUVES STRUCTURELLES
-- ============================================================================================
DO $$
DECLARE v_n integer; v_txt text;
BEGIN
  -- 1. LE SEUIL EST UNE HEURE, nomme en un seul endroit.
  IF public.assemblee_suspension_seuil() <> interval '1 hour' THEN
    RAISE EXCEPTION 'PREUVE 1 : le seuil n''est pas une heure (%)',
      public.assemblee_suspension_seuil();
  END IF;

  -- 2. LE REGISTRE EXISTE, SOUS RLS, SANS AUCUNE POLICY.
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                  WHERE n.nspname = 'public' AND c.relname = 'assemblee_reports_suspension'
                    AND c.relrowsecurity) THEN
    RAISE EXCEPTION 'PREUVE 2 : assemblee_reports_suspension sans RLS';
  END IF;
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'assemblee_reports_suspension';
  IF v_n <> 0 THEN RAISE EXCEPTION 'PREUVE 2 bis : % policy sur le registre', v_n; END IF;

  -- 3. UN RENVOI PAR (SUSPENSION, TEXTE, SESSION), garanti par un index unique.
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
                  AND indexname = 'assemblee_un_renvoi_par_session_suspendue') THEN
    RAISE EXCEPTION 'PREUVE 3 : l''unicite du renvoi n''est pas garantie';
  END IF;

  -- 4. L'APPLICATION N'EST PAS ACCORDEE AUX CLIENTS. Ni anon, ni authenticated : un joueur ne
  --    peut pas provoquer le renvoi d'un scrutin en appelant la porte directement.
  SELECT string_agg(g.grantee, ', ') INTO v_txt
    FROM information_schema.role_routine_grants g
   WHERE g.specific_schema = 'public'
     AND g.routine_name = 'assemblee_suspension_appliquer_seuil'
     AND g.grantee IN ('anon', 'authenticated', 'PUBLIC');
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'PREUVE 4 : la porte de renvoi est accordee a %', v_txt;
  END IF;

  -- 5. AUCUN « +7 JOURS » DANS LE RENVOI. La regle ne fabrique pas de calendrier : elle pose le
  --    statut de renvoi et laisse la fenetre d'ouverture decider de la date.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_suspension_appliquer_seuil';
  IF v_txt LIKE '%7 days%' OR v_txt LIKE '%assemblee_prochaine_cloture%' THEN
    RAISE EXCEPTION 'PREUVE 5 : le renvoi fabrique une echeance au lieu de renvoyer en session';
  END IF;
  IF v_txt NOT LIKE '%''renvoyee''%' THEN
    RAISE EXCEPTION 'PREUVE 5 bis : le renvoi ne pose pas le statut renvoyee';
  END IF;

  -- 6. LE RENVOI N'ECRIT JAMAIS DANS LE REGISTRE DU REPORT VOLONTAIRE. C'est ce qui garantit que
  --    le droit du President n'est ni consomme ni rendu.
  --    `assemblee_reports` suivi d'autre chose qu'un souligne : c'est la table du report
  --    volontaire. `assemblee_reports_suspension` ne declenche donc pas cette preuve, et c'est
  --    exactement la distinction que l'arbitrage demande de tenir.
  IF v_txt ~ 'public\.assemblee_reports[^_]' THEN
    RAISE EXCEPTION 'PREUVE 6 : le renvoi touche assemblee_reports';
  END IF;

  -- 7. LE REPORT VOLONTAIRE RESTE VERROUILLE PAR TEXTE, pas par session : changer de numero de
  --    session ne rend pas un second report volontaire sur le meme texte.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_reporter_vote';
  IF v_txt NOT LIKE '%deja_reporte_une_fois%' THEN
    RAISE EXCEPTION 'PREUVE 7 : le report volontaire n''est plus verrouille';
  END IF;
  IF v_txt LIKE '%session_num%' THEN
    RAISE EXCEPTION 'PREUVE 7 bis : le report volontaire regarde le numero de session';
  END IF;

  -- 8. LA REPRISE APPLIQUE LE SEUIL.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_reprendre_seance';
  IF v_txt NOT LIKE '%assemblee_suspension_appliquer_seuil%' THEN
    RAISE EXCEPTION 'PREUVE 8 : la reprise ne regarde pas le seuil';
  END IF;

  -- 9. LA DUREE EST LUE SUR LES COLONNES DE LA SUSPENSION, et sur l'horloge du serveur. Aucune
  --    duree ne vient d'un parametre : un client ne peut pas declarer depuis quand il attend.
  SELECT pg_get_function_identity_arguments(p.oid) INTO v_txt
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_suspension_appliquer_seuil';
  IF v_txt <> 'p_pays text' THEN
    RAISE EXCEPTION 'PREUVE 9 : la porte de renvoi accepte autre chose qu''un pays (%)', v_txt;
  END IF;

  -- 10. L'ETAT DE SEANCE REND LE FAIT, pour que l'ecran n'ait rien a calculer.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_seance';
  IF v_txt NOT LIKE '%suspension_presidence_depassee%'
     OR v_txt NOT LIKE '%renvois_pour_suspension%'
     OR v_txt NOT LIKE '%seuil_suspension_presidence%' THEN
    RAISE EXCEPTION 'PREUVE 10 : l''etat de seance ne rend pas le seuil';
  END IF;

  RAISE NOTICE 'LES 10 PREUVES DE §4 SONT VERTES.';
END $$;
