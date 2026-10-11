-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011195123 (UTC), nom
-- `calendrier_succession_transition_des_cycles`.
-- Le registre passe de 665 a 666 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e84d5e5e77a565d651c5e389777ebeef, 15218 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LA TRANSITION DES CYCLES VIVANTS, ET DOUZE PREUVES (3/4)
--
-- UN SEUL PRINCIPE : NE JAMAIS RACCOURCIR UN MANDAT EN COURS. Les douze cycles de la base se
-- repartissent en trois cas, et la migration dit lequel pour chacun.
--
--   (a) HUIT LIGNES INTACTES -- pas de titulaire, scrutin encore a venir : il n'y a aucun mandat
--       a proteger et le calendrier est devant. On ne les touche pas.
--
--   (b) DEUX MANDATS RE-ANCRES. `republic_president` finissait au lundi 2026-11-02 00:00 : il
--       n'a pas bouge d'une seconde, et son scrutin de succession est pose par-dessus (gel le
--       2026-10-26 00:01, vote le dimanche 2026-11-01). `republic_maire_ville_b` portait un
--       mandat d'une generation anterieure au calendrier du dimanche, annonce jusqu'au VENDREDI
--       2026-10-16 01:59 : il est re-ancre au lundi 2026-10-19 00:00 -- trois jours de PLUS,
--       jamais un de moins. Consequence assumee et rapportee : un mandat deja dans ses derniers
--       jours ne peut pas offrir quatre semaines de candidatures sans etre prolonge, et le
--       prolonger de dix jours serait un changement plus grand.
--
--   (c) UN SCRUTIN REJOUE. `republic_depute_ville_a` etait fige en vacance depuis le
--       13 septembre 2026 SANS `relancePossibleApres` : la condition de relance ne pouvait donc
--       jamais etre vraie, et les trois sieges de Port-Sainte-Marie n'avaient plus de scrutin du
--       tout. Un scrutin neuf de deux semaines est pose a partir du prochain lundi de Paris.
--
-- ET DOUZE PREUVES, dont trois qui portent sur les DONNEES et pas sur le texte : aucun cycle
-- n'est plus sans scrutin a venir, aucun ne porte un etat de l'ancien contrat, et les deux
-- titulaires en exercice sont toujours la -- une migration qui les perdrait trahirait l'arbitrage
-- qu'elle applique.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CALENDRIER ELECTORAL COMMUN (3/3 : TRANSITION DES CYCLES VIVANTS, ET LES PREUVES)
-- 11 octobre 2026

-- ============================================================================================
-- 5. TRANSITION DES CYCLES VIVANTS VERS LE NOUVEAU CONTRAT
-- ============================================================================================
-- TROIS CAS, ET UN SEUL PRINCIPE : NE JAMAIS RACCOURCIR UN MANDAT EN COURS.
--
--   (a) PAS DE TITULAIRE, SCRUTIN ENCORE A VENIR -- la ligne est deja conforme : il n'y a aucun
--       mandat a proteger et le calendrier est devant. ON NE LA TOUCHE PAS. Huit lignes sur
--       douze au 11 octobre 2026.
--
--   (b) UN TITULAIRE -- le scrutin de succession est (re)pose sur le mandat EXISTANT. Sa fin est
--       le PREMIER LUNDI 00:00 DE PARIS a ou apres la fin deja annoncee : un mandat peut etre
--       re-ancre, jamais ecourte. Deux lignes concernees :
--         . `republic_president` : fin deja au lundi 2026-11-02 00:00, elle ne bouge pas d'une
--           seconde. Gel le 2026-10-26 00:01, vote le dimanche 2026-11-01.
--         . `republic_maire_ville_b` : mandat d'une generation anterieure au calendrier du
--           dimanche, annonce jusqu'au VENDREDI 2026-10-16 01:59. Re-ancre au lundi 2026-10-19
--           00:00 -- trois jours de plus, jamais un de moins. Consequence assumee : son gel
--           tombe le 2026-10-12 00:01, donc la fenetre de candidature restante est courte. Un
--           mandat deja dans ses derniers jours ne peut pas offrir quatre semaines de
--           candidatures sans etre prolonge, et le prolonger de dix jours serait un changement
--           plus grand que celui-la.
--
--   (c) PAS DE TITULAIRE ET SCRUTIN ECHU OU FIGE -- un scrutin neuf de deux semaines est pose a
--       partir du prochain lundi de Paris : une semaine de candidatures, une de campagne et de
--       vote. C'est exactement ce que fait `ouvrirSuccessionSurCycle(lundi, PROLONGATION_SEMAINES)`
--       au cron. Une ligne concernee : `republic_depute_ville_a`, figee en vacance depuis le
--       13 septembre 2026 sans `relancePossibleApres`, donc sans aucune relance possible -- les
--       trois sieges de Port-Sainte-Marie n'avaient plus de scrutin du tout.
--
-- `candidats`, `votes` et `votesPNJ` sont remis a zero sur les lignes (b) et (c) : mesure faite
-- avant ecriture, les douze cycles portent ZERO candidat, et leurs bulletins appartiennent a des
-- scrutins echus. Les lignes (a) ne sont pas touchees, donc rien n'y est perdu.
DO $transition$
DECLARE
  r              record;
  v_d            jsonb;
  v_a_titulaire  boolean;
  v_ms           numeric := floor(extract(epoch FROM now()) * 1000);
  v_lundi_local  timestamp;
  v_fin_local    timestamp;
  v_fin          numeric;
  v_gel          numeric;
  v_vote         numeric;
  v_debut_cand   numeric;
  v_fin_annoncee numeric;
  n_intactes     integer := 0;
  n_mandats      integer := 0;
  n_rejoues      integer := 0;
BEGIN
  -- Le lundi 00:00 de Paris de la semaine en cours. date_trunc('week') part du lundi (ISO).
  v_lundi_local := date_trunc('week', (now() AT TIME ZONE 'Europe/Paris'));

  FOR r IN SELECT id, poste_id, data FROM public.cycles_electoraux ORDER BY id LOOP
    BEGIN v_d := r.data::jsonb; EXCEPTION WHEN OTHERS THEN CONTINUE; END;
    IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN CONTINUE; END IF;

    v_a_titulaire := CASE
      WHEN r.poste_id = 'depute' THEN EXISTS (
        SELECT 1 FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_d -> 'elus') = 'array' THEN v_d -> 'elus' ELSE '[]'::jsonb END) e
         WHERE jsonb_typeof(e) = 'string' AND btrim(e #>> '{}') <> '')
      ELSE COALESCE(NULLIF(btrim(COALESCE(v_d ->> 'eluId', '')), ''), NULL) IS NOT NULL
    END;

    -- (a) rien a proteger, calendrier devant : intacte.
    IF NOT v_a_titulaire
       AND COALESCE((v_d ->> 'resultatsTraites')::boolean, false) = false
       AND jsonb_typeof(v_d -> 'dateResultats') = 'number'
       AND (v_d ->> 'dateResultats')::numeric > v_ms THEN
      n_intactes := n_intactes + 1;
      CONTINUE;
    END IF;

    IF v_a_titulaire THEN
      -- (b) la fin deja annoncee, arrondie AU LUNDI SUIVANT OU EGAL, et jamais avant maintenant.
      v_fin_annoncee := COALESCE(
        CASE WHEN jsonb_typeof(v_d -> 'dateFinMandat')  = 'number' THEN (v_d ->> 'dateFinMandat')::numeric END,
        CASE WHEN jsonb_typeof(v_d -> 'dateResultats')  = 'number' THEN (v_d ->> 'dateResultats')::numeric END,
        v_ms);
      v_fin_local := date_trunc('week', (to_timestamp(v_fin_annoncee / 1000) AT TIME ZONE 'Europe/Paris'));
      IF floor(extract(epoch FROM (v_fin_local AT TIME ZONE 'Europe/Paris')) * 1000) < v_fin_annoncee THEN
        v_fin_local := v_fin_local + interval '7 days';
      END IF;
      WHILE floor(extract(epoch FROM (v_fin_local AT TIME ZONE 'Europe/Paris')) * 1000) <= v_ms LOOP
        v_fin_local := v_fin_local + interval '7 days';
      END LOOP;
      v_debut_cand := COALESCE(
        CASE WHEN jsonb_typeof(v_d -> 'dateDebutMandatTs') = 'number' THEN (v_d ->> 'dateDebutMandatTs')::numeric END,
        floor(extract(epoch FROM (v_lundi_local AT TIME ZONE 'Europe/Paris')) * 1000));
      n_mandats := n_mandats + 1;
    ELSE
      -- (c) scrutin neuf de deux semaines a partir du prochain lundi, candidatures des maintenant.
      v_fin_local  := v_lundi_local + interval '21 days';
      WHILE floor(extract(epoch FROM ((v_fin_local - interval '7 days') AT TIME ZONE 'Europe/Paris')) * 1000) <= v_ms LOOP
        v_fin_local := v_fin_local + interval '7 days';
      END LOOP;
      v_debut_cand := v_ms;
      n_rejoues := n_rejoues + 1;
    END IF;

    v_fin  := floor(extract(epoch FROM (v_fin_local AT TIME ZONE 'Europe/Paris')) * 1000);
    v_gel  := floor(extract(epoch FROM ((v_fin_local - interval '7 days' + interval '1 minute') AT TIME ZONE 'Europe/Paris')) * 1000);
    v_vote := floor(extract(epoch FROM ((v_fin_local - interval '1 day'  + interval '1 minute') AT TIME ZONE 'Europe/Paris')) * 1000);

    v_d := v_d - 'relancePossibleApres' - 'egalite3eSiege' - 'realigneDimancheTs'
           || jsonb_build_object(
                'phase', 'candidatures',
                'tour', 1,
                'candidats', '[]'::jsonb,
                'votes', '{}'::jsonb,
                'votesPNJ', '{}'::jsonb,
                'dateDebutCandidatures', v_debut_cand,
                'dateDebutCampagne', v_gel,
                'dateVote', v_vote,
                'dateResultats', v_fin,
                'dateFinMandat', v_fin,
                'resultatsTraites', false);

    UPDATE public.cycles_electoraux SET data = v_d::text, updated_at = now() WHERE id = r.id;
    RAISE NOTICE 'cycle % : fin et resultat au % (Paris)', r.id, (v_fin_local)::text;
  END LOOP;

  RAISE NOTICE 'transition : % intactes, % mandats re-ancres, % scrutins rejoues', n_intactes, n_mandats, n_rejoues;
  IF n_mandats + n_rejoues = 0 THEN
    RAISE EXCEPTION 'transition : aucune ligne traitee -- la lecture des cycles a echoue';
  END IF;
END
$transition$;

-- ============================================================================================
-- 6. PREUVES STRUCTURELLES
-- ============================================================================================
-- Elles portent sur le TEXTE des fonctions et sur l'ETAT des cycles apres transition. Aucune ne
-- simule un comportement : le comportement est eprouve par les bancs, en transaction annulee.
DO $preuves$
DECLARE v_txt text; v_n integer; v_ms numeric := floor(extract(epoch FROM now()) * 1000);
BEGIN
  -- P1 : plus aucune porte electorale ne lit la phase du mandat.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname IN ('candidatures_cloture','election_voter','elections_voix_pnj_enregistrer',
                       'tracts_electoraux_distribuer_interne')
     AND position('''mandat''' IN pg_get_functiondef(p.oid)) > 0;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- % porte(s) lisent encore la phase du mandat', v_n;
  END IF;

  -- P2 : le gel des candidatures est la SEULE borne de date du declencheur.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'candidatures_cloture';
  IF position('dateDebutCampagne' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le gel du lundi 00:01 a disparu du declencheur';
  END IF;
  IF position('''vacant''' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- un poste sans titulaire refuse encore les candidatures';
  END IF;

  -- P3 : le declencheur estampille le scrutin, et il le relit sur le cycle.
  IF position('NEW.cle_scrutin' IN v_txt) = 0
     OR position('v_d ->> ''dateDebutCandidatures''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la candidature n''est pas estampillee du scrutin relu au serveur';
  END IF;

  -- P4 : la fenetre de vote n'a pas bouge, et le bulletin porte son tour.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'election_voter';
  IF position('(v_cycle ->> ''dateVote'')::numeric' IN v_txt) = 0
     OR position('(v_cycle ->> ''dateResultats'')::numeric' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la fenetre de vote n''est plus [dateVote, dateResultats)';
  END IF;
  IF position('tour' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le bulletin ne porte pas son tour';
  END IF;

  -- P5 : la consignation sait garder sur dateResultats, et sait encore garder sans. ET IL N'EN
  -- EXISTE QU'UNE : la surcharge a quatre parametres laissee par le cinquieme est bien partie.
  SELECT count(*) INTO v_n FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'election_resultats_consigner';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- % versions de election_resultats_consigner coexistent', v_n;
  END IF;
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'election_resultats_consigner';
  IF position('p_si_date_resultats' IN v_txt) = 0
     OR position('''resultatsTraites'')::boolean, false) = false' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la consignation n''a pas ses deux gardes';
  END IF;

  -- P6 : les deux colonnes d'estampille existent, et sont indexees avec leur scrutin.
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='candidatures' AND column_name='cle_scrutin')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='votes_electoraux' AND column_name='tour') THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- une estampille de scrutin manque';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='candidatures_par_scrutin')
     OR NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='votes_electoraux_par_tour') THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- un index d''estampille manque';
  END IF;

  -- P7 : AUCUN CYCLE N'EST PLUS DANS UN ETAT SANS SCRUTIN A VENIR. C'est l'invariant du
  -- correctif, mesure sur les donnees : tout cycle porte une proclamation future.
  SELECT count(*) INTO v_n FROM public.cycles_electoraux c
   WHERE left(btrim(c.data), 1) = '{'
     AND (jsonb_typeof(c.data::jsonb -> 'dateResultats') <> 'number'
          OR (c.data::jsonb ->> 'dateResultats')::numeric <= v_ms
          OR COALESCE((c.data::jsonb ->> 'resultatsTraites')::boolean, false));
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- % cycle(s) sans scrutin a venir', v_n;
  END IF;

  -- P8 : plus aucun cycle ne porte un etat de l'ancien contrat.
  SELECT count(*) INTO v_n FROM public.cycles_electoraux c
   WHERE left(btrim(c.data), 1) = '{'
     AND (COALESCE(c.data::jsonb ->> 'phase','') IN ('mandat','vacant')
          OR c.data::jsonb ? 'relancePossibleApres');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- % cycle(s) portent encore un etat de l''ancien contrat', v_n;
  END IF;

  -- P9 : AUCUN MANDAT N'A ETE RACCOURCI. Pour chaque cycle a titulaire, la proclamation du
  -- successeur est a ou apres la fin qui etait annoncee avant cette migration -- verifiee ici
  -- sur les deux seules lignes concernees, dont les dates d'origine sont inscrites en dur.
  IF EXISTS (SELECT 1 FROM public.cycles_electoraux c WHERE c.id = 'republic_president'
              AND (c.data::jsonb ->> 'dateFinMandat')::numeric
                  <> floor(extract(epoch FROM (timestamp '2026-11-02 00:00' AT TIME ZONE 'Europe/Paris')) * 1000)) THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- le mandat presidentiel ne finit plus au lundi 2026-11-02 00:00';
  END IF;
  IF EXISTS (SELECT 1 FROM public.cycles_electoraux c WHERE c.id = 'republic_maire_ville_b'
              AND (c.data::jsonb ->> 'dateFinMandat')::numeric
                  < floor(extract(epoch FROM (timestamp '2026-10-16 01:59' AT TIME ZONE 'Europe/Paris')) * 1000)) THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- le mandat du maire de Montrouge a ete raccourci';
  END IF;

  -- P10 : LES TITULAIRES SONT TOUJOURS LA. La transition n'a efface aucun `eluId` ni `elus` --
  -- c'est la raison d'etre du correctif, et une migration qui les perdrait le trahirait.
  IF NOT EXISTS (SELECT 1 FROM public.cycles_electoraux c WHERE c.id = 'republic_president'
                  AND c.data::jsonb ->> 'eluId' = 'Le Président (PNJ)')
     OR NOT EXISTS (SELECT 1 FROM public.cycles_electoraux c WHERE c.id = 'republic_maire_ville_b'
                  AND c.data::jsonb ->> 'eluId' = 'Le Maire (PNJ)') THEN
    RAISE EXCEPTION 'P10 ECHOUEE -- un titulaire en exercice a disparu de son cycle';
  END IF;

  -- P11 : LE VOTE EST UN DIMANCHE ET LA PROCLAMATION UN LUNDI MINUIT, A PARIS, POUR LES DOUZE.
  SELECT count(*) INTO v_n FROM public.cycles_electoraux c
   WHERE left(btrim(c.data), 1) = '{'
     AND (extract(isodow FROM (to_timestamp((c.data::jsonb ->> 'dateVote')::numeric / 1000) AT TIME ZONE 'Europe/Paris')) <> 7
          OR extract(isodow FROM (to_timestamp((c.data::jsonb ->> 'dateResultats')::numeric / 1000) AT TIME ZONE 'Europe/Paris')) <> 1
          OR (to_timestamp((c.data::jsonb ->> 'dateResultats')::numeric / 1000) AT TIME ZONE 'Europe/Paris')::time <> time '00:00');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- % cycle(s) ne votent pas un dimanche ou ne proclament pas un lundi minuit', v_n;
  END IF;

  -- P12 : poste_est_atteste n'a pas change, et il reste la source d'autorite : il lit `eluId` /
  -- `elus` et RIEN de la fiche du personnage.
  SELECT pg_get_functiondef(p.oid) INTO v_txt FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'poste_est_atteste';
  IF position('''eluId''' IN v_txt) = 0 OR position('-> ''elus''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- l''attestation ne lit plus le depouillement';
  END IF;
  IF position('poste_depute' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- l''attestation lit un champ pose sur la fiche';
  END IF;

  RAISE NOTICE 'LES 12 PREUVES SONT VERTES.';
END
$preuves$;