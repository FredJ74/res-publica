-- ============================================================================
-- Chaîne élective — suite de l'audit du 02/11/2026 (outils/audits/AUDIT-CHAINE-ELECTIVE-20261102.md)
--
-- E4  Contester un tour déjà proclamé : LE RECOMPTE S'IMPOSE (décision de Fred, 02/11/2026,
--     GAME-DESIGN-ELECTIONS.md). Le serveur applique le résultat recompté exactement comme la
--     passe de nuit l'aurait fait : prise de fonctions (archive du maire sortant, indicateurs,
--     scrutin de succession de 5 semaines), second tour avec les bons qualifiés (même dimanche),
--     ou prolongation de 2 semaines ; et il rend le poste au titulaire précédent quand
--     l'élection proclamée tombe.
-- E5  Un résultat changé par contestation est annoncé (évènement public) et, s'il désigne un
--     élu, inscrit à la chronique.
-- E8  `authenticated` perd INSERT sur `candidatures` (seules les portes serveur déposent) ; le
--     DELETE de soi reste (suppression du personnage) et retire désormais aussi le nom du
--     bulletin du scrutin ouvert.
--
-- E6 et E7 sont dans api/cron-minuit.js et plateau-politique.js (aucune base).
-- Patches en place (WORKFLOW-SUPABASE.md) : un fragment inexact fait échouer la migration.
-- Idempotente : un patch déjà appliqué est détecté par son marqueur et sauté.
-- ============================================================================

-- ------------------------------------------------------------- outils --------
-- Instant (ms) = instant de départ, en heure murale de Paris, décalé d'une durée calendaire.
CREATE OR REPLACE FUNCTION public.election_ms_paris(p_ms numeric, p_decalage interval)
 RETURNS bigint
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT floor(extract(epoch FROM (((to_timestamp(p_ms / 1000.0) AT TIME ZONE 'Europe/Paris') + p_decalage)
                                   AT TIME ZONE 'Europe/Paris')) * 1000)::bigint
$function$;

-- Deux listes de noms identiques, à l'ordre près.
CREATE OR REPLACE FUNCTION public.election_memes_noms(p_a jsonb, p_b jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT array_agg(x ORDER BY x) FROM jsonb_array_elements_text(
                     CASE WHEN jsonb_typeof(p_a) = 'array' THEN p_a ELSE '[]'::jsonb END) x), '{}')
       = coalesce((SELECT array_agg(x ORDER BY x) FROM jsonb_array_elements_text(
                     CASE WHEN jsonb_typeof(p_b) = 'array' THEN p_b ELSE '[]'::jsonb END) x), '{}')
$function$;

-- Miroir de ouvrirSuccessionSurCycle / calendrierSuccession (api/cron-minuit.js) : scrutin de
-- succession ouvert à `p_debut` (lundi 00:00 de Paris) pour `p_semaines` semaines. Le titulaire
-- n'est pas touché. `p_garder` conserve candidats et bulletins du scrutin déjà ouvert à cet instant.
CREATE OR REPLACE FUNCTION public.election_cycle_succession(p_cycle jsonb, p_debut numeric, p_semaines integer, p_garder boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT (p_cycle - 'relancePossibleApres' - 'egalite3eSiege' - 'realigneDimancheTs' - 'debutTour')
    || jsonb_build_object(
         'phase', 'candidatures', 'tour', 1, 'resultatsTraites', false,
         'dateDebutCandidatures', p_debut::bigint,
         'dateDebutCampagne', public.election_ms_paris(p_debut, make_interval(days => 7 * p_semaines - 7, mins => 1)),
         'dateVote',          public.election_ms_paris(p_debut, make_interval(days => 7 * p_semaines - 1, mins => 1)),
         'dateResultats',     public.election_ms_paris(p_debut, make_interval(days => 7 * p_semaines)),
         'dateFinMandat',     public.election_ms_paris(p_debut, make_interval(days => 7 * p_semaines)))
    || CASE WHEN p_garder THEN '{}'::jsonb
            ELSE jsonb_build_object('candidats', '[]'::jsonb, 'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb) END
$function$;

-- ------------------------------------------------------------- E4 / E5 -------
-- Ne lit ni n'écrit le cycle en base : il reçoit le cycle verrouillé par election_contester,
-- rend le cycle corrigé et pose les annonces (même transaction que l'appelant).
CREATE OR REPLACE FUNCTION public.election_contestation_appliquer(p_cycle_id text, p_cycle jsonb, p_scrutin jsonb,
  p_recompte jsonb, p_pays text, p_poste text, p_city text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c jsonb := p_cycle;
  v_fin numeric := nullif(p_scrutin ->> 'finTour', '')::numeric;
  v_premier_tour boolean := nullif(p_scrutin ->> 'debutTour', '') IS NULL;
  v_depute boolean := p_poste = 'depute';
  v_etat text; v_cible text; v_nouveau jsonb; v_ancien jsonb; v_cands jsonb;
  v_lieu text; v_poste_nom text; v_ville_nom text; v_texte text; v_sortant text; v_noms text;
  v_debut numeric; v_budget jsonb; v_indic jsonb;
  v_semaine CONSTANT numeric := 604800000;
  v_now bigint := floor(extract(epoch FROM now()) * 1000);
BEGIN
  v_ancien := CASE WHEN v_depute THEN coalesce(c -> 'elus', '[]'::jsonb) ELSE c -> 'eluId' END;

  -- PHOTOGRAPHIE ANTERIEURE AU 02/11 (sans bornes de tour) : remplacement seul, comme avant.
  IF v_fin IS NULL THEN
    IF v_depute THEN
      v_nouveau := p_recompte -> 'elus';
      IF jsonb_typeof(v_nouveau) = 'array' AND jsonb_array_length(v_nouveau) = 3
         AND NOT public.election_memes_noms(v_nouveau, v_ancien) THEN
        RETURN jsonb_build_object('change', true, 'issue', 'elu', 'ancien', v_ancien, 'nouveau', v_nouveau,
                                  'cycle', jsonb_set(c, '{elus}', v_nouveau));
      END IF;
    ELSE
      v_nouveau := p_recompte -> 'elu';
      IF jsonb_typeof(v_nouveau) = 'string' AND v_nouveau IS DISTINCT FROM v_ancien THEN
        RETURN jsonb_build_object('change', true, 'issue', 'elu', 'ancien', v_ancien, 'nouveau', v_nouveau,
                                  'cycle', jsonb_set(c, '{eluId}', v_nouveau));
      END IF;
    END IF;
    RETURN jsonb_build_object('change', false, 'ancien', v_ancien);
  END IF;

  -- CE QUE LA PROCLAMATION CONTESTEE A FAIT. `finTour` est l'instant de cette proclamation.
  IF nullif(c ->> 'dateDebutMandatTs', '')::numeric = v_fin THEN v_etat := 'installe';
  ELSIF c ->> 'phase' = 'second_tour' AND nullif(c ->> 'debutTour', '')::numeric = v_fin THEN v_etat := 'second_tour';
  ELSE v_etat := 'prolonge';
  END IF;

  -- CE QUE LE RECOMPTE DIT (mêmes règles que resoudreScrutinSimple / resoudreScrutinDepute).
  IF v_depute THEN
    v_nouveau := CASE WHEN jsonb_typeof(p_recompte -> 'elus') = 'array' THEN p_recompte -> 'elus' ELSE '[]'::jsonb END;
    IF jsonb_array_length(v_nouveau) > 0 THEN
      v_cible := 'elu';
      -- Trois sièges, comme la passe de nuit : complétés par les PNJ déjà en place.
      IF jsonb_array_length(v_nouveau) < 3 THEN
        SELECT v_nouveau || coalesce(jsonb_agg(x ORDER BY o), '[]'::jsonb) INTO v_nouveau FROM (
          SELECT x, o FROM jsonb_array_elements(coalesce(p_scrutin -> 'elusAvant', c -> 'elus', '[]'::jsonb)) WITH ORDINALITY e(x, o)
           WHERE NOT (v_nouveau @> jsonb_build_array(x))
             AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees p WHERE p.name = x #>> '{}')
           ORDER BY o LIMIT greatest(0, 3 - jsonb_array_length(v_nouveau))) t;
      END IF;
    ELSE
      v_cible := 'rien';
    END IF;
  ELSIF jsonb_typeof(p_recompte -> 'elu') = 'string' THEN
    v_cible := 'elu'; v_nouveau := p_recompte -> 'elu';
  ELSIF v_premier_tour AND jsonb_typeof(p_recompte -> 'secondTour') = 'array'
        AND jsonb_array_length(p_recompte -> 'secondTour') >= 2 THEN
    v_cible := 'second_tour'; v_nouveau := p_recompte -> 'secondTour';
  ELSE
    v_cible := 'rien'; v_nouveau := NULL;
  END IF;

  -- RIEN NE CHANGE.
  IF (v_etat = 'installe' AND v_cible = 'elu' AND public.election_memes_noms(
        CASE WHEN v_depute THEN v_nouveau ELSE jsonb_build_array(v_nouveau) END,
        CASE WHEN v_depute THEN v_ancien ELSE jsonb_build_array(v_ancien) END))
     OR (v_etat = 'second_tour' AND v_cible = 'second_tour' AND public.election_memes_noms(v_nouveau,
        (SELECT jsonb_agg(k -> 'nom') FROM jsonb_array_elements(coalesce(c -> 'candidats', '[]'::jsonb)) k)))
     OR (v_etat = 'prolonge' AND v_cible = 'rien') THEN
    RETURN jsonb_build_object('change', false, 'ancien', v_ancien);
  END IF;

  -- L'ELECTION PROCLAMEE TOMBE : le poste revient au titulaire d'avant la proclamation.
  IF v_etat = 'installe' AND v_cible <> 'elu' THEN
    IF NOT (p_scrutin ? CASE WHEN v_depute THEN 'elusAvant' ELSE 'titulaireAvant' END) THEN
      RETURN jsonb_build_object('change', false, 'ancien', v_ancien, 'raison', 'titulaire_precedent_inconnu');
    END IF;
    IF p_poste = 'maire' THEN
      DELETE FROM public.mandats_maires_archives
       WHERE id = 'mandat-' || p_pays || '-' || p_city || '-'
                  || coalesce(nullif(p_scrutin ->> 'debutMandatAvant', '')::numeric, v_fin - 5 * v_semaine)::bigint::text;
    END IF;
    IF v_depute THEN c := jsonb_set(c, '{elus}', coalesce(p_scrutin -> 'elusAvant', '[]'::jsonb));
    ELSIF jsonb_typeof(p_scrutin -> 'titulaireAvant') = 'string' THEN c := jsonb_set(c, '{eluId}', p_scrutin -> 'titulaireAvant');
    ELSE c := c - 'eluId';
    END IF;
    c := CASE WHEN jsonb_typeof(p_scrutin -> 'debutMandatAvant') = 'number'
              THEN jsonb_set(c, '{dateDebutMandatTs}', p_scrutin -> 'debutMandatAvant') ELSE c - 'dateDebutMandatTs' END;
    c := CASE WHEN jsonb_typeof(p_scrutin -> 'indicateursAvant') = 'object'
              THEN jsonb_set(c, '{indicateursDebutMandat}', p_scrutin -> 'indicateursAvant') ELSE c - 'indicateursDebutMandat' END;
  END IF;

  IF v_cible = 'elu' THEN
    -- PRISE DE FONCTIONS à l'instant de la proclamation contestée (un lundi 00:00), sauf si
    -- elle avait déjà eu lieu : alors seul le nom change, le mandat garde ses dates.
    IF v_etat <> 'installe' THEN
      v_sortant := c ->> 'eluId';
      IF p_poste = 'maire' THEN
        SELECT b.data INTO v_budget FROM public.budgets_municipaux b WHERE b.id = p_pays || '_' || p_city;
        v_indic := jsonb_build_object(
          'taux_impots_locaux', CASE WHEN jsonb_typeof(v_budget -> 'tauxLocal') = 'number' THEN v_budget -> 'tauxLocal' END,
          'caisse_municipale',  CASE WHEN jsonb_typeof(v_budget -> 'caisse') = 'number' THEN v_budget -> 'caisse' END);
        IF v_sortant IS NOT NULL THEN
          v_debut := coalesce(nullif(c ->> 'dateDebutMandatTs', '')::numeric, v_fin - 5 * v_semaine);
          INSERT INTO public.mandats_maires_archives (id, country, city, maire, est_pj, debut_ts, fin_ts, indicateurs_debut, indicateurs_fin)
          VALUES ('mandat-' || p_pays || '-' || p_city || '-' || v_debut::bigint::text, p_pays, p_city, v_sortant,
                  EXISTS (SELECT 1 FROM public.personnages_donnees p WHERE p.name = v_sortant),
                  to_timestamp(v_debut / 1000.0), to_timestamp(v_fin / 1000.0), c -> 'indicateursDebutMandat', v_indic)
          ON CONFLICT (id) DO NOTHING;
        END IF;
        c := jsonb_set(c, '{indicateursDebutMandat}', v_indic);
      END IF;
      c := jsonb_set(c - 'dissolutionUtilisee' - 'administrateur', '{dateDebutMandatTs}', to_jsonb(v_fin::bigint));
      c := public.election_cycle_succession(c, v_fin, 5, v_etat = 'prolonge');
    END IF;
    c := CASE WHEN v_depute THEN jsonb_set(c, '{elus}', v_nouveau) ELSE jsonb_set(c, '{eluId}', v_nouveau) END;

  ELSIF v_cible = 'second_tour' THEN
    -- SECOND TOUR ENTRE LES BONS QUALIFIES, le dimanche qui suit la proclamation contestée ; la
    -- clé du scrutin (fraudes, candidatures) redevient celle du premier tour, comme au cron.
    SELECT jsonb_agg(jsonb_build_object('nom', q #>> '{}', 'voix', 0, 'programme',
             coalesce((SELECT k ->> 'programme' FROM jsonb_array_elements(p_scrutin -> 'candidats') k
                        WHERE k ->> 'nom' = q #>> '{}' LIMIT 1), '')) ORDER BY o)
      INTO v_cands FROM jsonb_array_elements(v_nouveau) WITH ORDINALITY e(q, o);
    c := (c - 'relancePossibleApres' - 'egalite3eSiege' - 'realigneDimancheTs') || jsonb_build_object(
      'tour', 2, 'debutTour', v_fin::bigint, 'candidats', v_cands, 'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb,
      'dateDebutCandidatures', p_scrutin -> 'debut',
      'dateDebutCampagne', public.election_ms_paris(v_fin, interval '1 minute'),
      'dateVote',          public.election_ms_paris(v_fin, interval '6 days 1 minute'),
      'dateResultats',     public.election_ms_paris(v_fin, interval '7 days'),
      'dateFinMandat',     public.election_ms_paris(v_fin, interval '7 days'),
      'phase', 'second_tour', 'resultatsTraites', false);

  ELSE
    -- AUCUN VERDICT : prolongation de 2 semaines, le titulaire en fonction le reste.
    c := public.election_cycle_succession(c, v_fin, 2, v_etat IN ('installe', 'prolonge'));
  END IF;

  -- ANNONCE (E5). Noms affichés posés par la passe de nuit dans la photographie (E7).
  v_poste_nom := coalesce(p_scrutin ->> 'posteNom', p_poste);
  v_ville_nom := coalesce(p_scrutin ->> 'villeNom', p_city);
  v_lieu := CASE WHEN p_city IS NOT NULL THEN ' (' || v_ville_nom || ')' ELSE '' END;
  IF v_depute THEN
    SELECT string_agg(x, ', ') INTO v_noms FROM jsonb_array_elements_text(v_nouveau) x;
    v_texte := CASE WHEN v_cible = 'elu'
      THEN v_noms || ' sont élu(e)s député(e)s de ' || v_ville_nom || ' (3 sièges).'
      ELSE 'les législatives de ' || v_ville_nom || ' sont invalidées : les député(e)s en fonction le restent, un nouveau scrutin est ouvert.' END;
  ELSIF v_cible = 'elu' THEN
    v_texte := CASE v_etat
      WHEN 'installe' THEN (v_nouveau #>> '{}') || ' est élu(e) ' || v_poste_nom || v_lieu || ' à la place de ' || coalesce(v_ancien #>> '{}', '?') || '.'
      WHEN 'second_tour' THEN 'le recompte du premier tour donne la majorité absolue à ' || (v_nouveau #>> '{}') || ', élu(e) ' || v_poste_nom || v_lieu || '. Le second tour est annulé.'
      ELSE 'le recompte donne la victoire à ' || (v_nouveau #>> '{}') || ', élu(e) ' || v_poste_nom || v_lieu || '.' END;
  ELSIF v_cible = 'second_tour' THEN
    SELECT string_agg(x, ' et ') INTO v_noms FROM jsonb_array_elements_text(v_nouveau) x;
    v_texte := CASE WHEN v_etat = 'installe'
      THEN 'l''élection de ' || coalesce(v_ancien #>> '{}', '?') || ' (' || v_poste_nom || v_lieu || ') est annulée'
      ELSE 'le recompte du premier tour (' || v_poste_nom || v_lieu || ') change les qualifiés' END
      || ' : second tour entre ' || v_noms || ' dimanche. Le titulaire en fonction le reste jusqu''au résultat.';
  ELSE
    v_texte := CASE WHEN v_etat = 'installe'
      THEN 'l''élection de ' || coalesce(v_ancien #>> '{}', '?') || ' (' || v_poste_nom || v_lieu || ') est annulée'
      ELSE 'le recompte du premier tour (' || v_poste_nom || v_lieu || ') ne désigne personne, le second tour est annulé' END
      || ' : le titulaire en fonction le reste, un nouveau scrutin est ouvert.';
  END IF;
  v_texte := 'APRÈS CONTESTATION : ' || v_texte;
  INSERT INTO public.evenements_globaux (country, city, texte, jour) VALUES (p_pays, p_city, '⚖️ ' || v_texte, NULL);
  IF v_cible = 'elu' THEN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES ('election-' || p_cycle_id || '-' || v_fin::bigint || '-contestation-' || v_now, p_pays, p_city, 'election_resultat',
            CASE WHEN v_depute THEN v_nouveau ELSE jsonb_build_array(v_nouveau) END, v_texte,
            jsonb_build_object('poste_id', p_poste, CASE WHEN v_depute THEN 'elus' ELSE 'elu' END, v_nouveau,
                               'contestation', true, 'cycle_row_id', p_cycle_id),
            p_cycle_id)
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN jsonb_build_object('change', true, 'issue', v_cible, 'etat_conteste', v_etat,
                            'ancien', v_ancien, 'nouveau', v_nouveau, 'cycle', c, 'annonce', v_texte);
END; $function$;

REVOKE ALL ON FUNCTION public.election_contestation_appliquer(text,jsonb,jsonb,jsonb,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.election_cycle_succession(jsonb,numeric,integer,boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.election_ms_paris(numeric,interval) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.election_memes_noms(jsonb,jsonb) FROM PUBLIC, anon, authenticated;

DO $mig$
DECLARE v_def text; v_new text; v_debut integer; v_fin integer;
  v_bloc_fin CONSTANT text := $a$  IF v_change THEN
    UPDATE public.cycles_electoraux SET data = v_cycle::text, updated_at = now() WHERE id = v_row.id;
  END IF;$a$;
BEGIN
  -- -------------------------------------------- recompte : qualifiés du 2nd tour --
  v_def := pg_get_functiondef('public.election_recompter_interne(text,text,text,text,jsonb)'::regprocedure);
  IF position('AUDIT_E4_QUALIFIES' IN v_def) = 0 THEN
    v_new := replace(v_def, $a$  v_premier text; v_premier_voix integer;$a$, $b$  v_premier text; v_premier_voix integer; v_q jsonb;$b$);
    v_new := replace(v_new,
      $a$  RETURN jsonb_build_object('elu', CASE WHEN v_premier_voix > v_total / 2.0 THEN v_premier END);$a$,
      $b$  -- AUDIT_E4_QUALIFIES (02/11/2026) : qualifiés du second tour, regle de resoudreScrutinSimple
  -- (15 % des exprimes, a defaut les deux premiers ; egalite : ordre du bulletin).
  SELECT coalesce(jsonb_agg(nom ORDER BY voix DESC, ord), '[]'::jsonb) INTO v_q FROM (
    SELECT s.key AS nom, s.value::int AS voix, i.ord FROM jsonb_each_text(v_scores) s
      LEFT JOIN LATERAL (SELECT min(o) AS ord FROM jsonb_array_elements(p_scrutin -> 'candidats') WITH ORDINALITY e(c, o)
                          WHERE e.c ->> 'nom' = s.key) i ON true
     WHERE s.value::int >= 0.15 * v_total) t;
  IF jsonb_array_length(v_q) < 2 THEN
    SELECT coalesce(jsonb_agg(nom ORDER BY voix DESC, ord), '[]'::jsonb) INTO v_q FROM (
      SELECT s.key AS nom, s.value::int AS voix, i.ord FROM jsonb_each_text(v_scores) s
        LEFT JOIN LATERAL (SELECT min(o) AS ord FROM jsonb_array_elements(p_scrutin -> 'candidats') WITH ORDINALITY e(c, o)
                            WHERE e.c ->> 'nom' = s.key) i ON true
       ORDER BY s.value::int DESC, i.ord LIMIT 2) t;
  END IF;
  RETURN jsonb_build_object('elu', CASE WHEN v_premier_voix > v_total / 2.0 THEN v_premier END,
                            'secondTour', CASE WHEN v_premier_voix > v_total / 2.0 THEN '[]'::jsonb ELSE v_q END);$b$);
    IF position('v_q jsonb;' IN v_new) = 0 OR position('AUDIT_E4_QUALIFIES' IN v_new) = 0 THEN
      RAISE EXCEPTION 'patch E4 non applique : election_recompter_interne';
    END IF;
    EXECUTE v_new;
  END IF;

  -- -------------------------------------------- contestation : le recompte s'impose --
  v_def := pg_get_functiondef('public.election_contester(text,text,integer,integer)'::regprocedure);
  IF position('AUDIT_E4_E5' IN v_def) = 0 THEN
    v_debut := position($a$  IF p_poste = 'depute' THEN
    v_ancien := coalesce(v_cycle -> 'elus', '[]'::jsonb);$a$ IN v_def);
    v_fin := position(v_bloc_fin IN v_def);
    IF v_debut = 0 OR v_fin = 0 OR v_fin < v_debut THEN
      RAISE EXCEPTION 'patch E4 non applique : bloc de remplacement d''election_contester introuvable';
    END IF;
    v_new := substr(v_def, 1, v_debut - 1) || $b$  -- AUDIT_E4_E5 (02/11/2026) : LE RECOMPTE S'IMPOSE (decision de Fred). Prise de fonctions,
  -- second tour avec les bons qualifies ou prolongation, exactement comme la passe de nuit, et
  -- annonce publique du resultat corrige (election_contestation_appliquer).
  v_app := public.election_contestation_appliquer(v_row.id, v_cycle, v_scrutin, v_recompte, v_pays, p_poste, v_city);
  v_change := coalesce((v_app ->> 'change')::boolean, false);
  v_ancien := v_app -> 'ancien';
  v_nouveau := v_app -> 'nouveau';
  IF v_change THEN
    UPDATE public.cycles_electoraux SET data = (v_app -> 'cycle')::text, updated_at = now() WHERE id = v_row.id;
  END IF;$b$ || substr(v_def, v_fin + length(v_bloc_fin));
    v_new := replace(v_new, $a$v_ancien jsonb; v_nouveau jsonb; v_change boolean := false;$a$,
                            $b$v_ancien jsonb; v_nouveau jsonb; v_change boolean := false; v_app jsonb;$b$);
    v_new := replace(v_new, $a$'issue_changee', v_change,$a$,
                            $b$'issue_changee', v_change, 'issue_nouvelle', v_app ->> 'issue', 'annonce', v_app ->> 'annonce',$b$);
    IF position('v_app jsonb;' IN v_new) = 0 OR position('''annonce''' IN v_new) = 0 THEN
      RAISE EXCEPTION 'patch E4 non applique : declaration ou retour d''election_contester';
    END IF;
    EXECUTE v_new;
  END IF;
END $mig$;

-- ------------------------------------------------------------------ E8 --------
-- Le dépôt passe par candidature_publier / candidature_deposer (SECURITY DEFINER).
REVOKE INSERT ON TABLE public.candidatures FROM authenticated;

-- Un retrait (suppression du personnage) retire aussi le nom du bulletin du scrutin ouvert,
-- tant que le vote n'a pas commencé. Les bulletins déjà déposés ne sont pas touchés.
CREATE OR REPLACE FUNCTION public.candidatures_retrait_bulletin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.cycles_electoraux c
     SET data = jsonb_set(c.data::jsonb, '{candidats}',
                  coalesce((SELECT jsonb_agg(e ORDER BY o) FROM jsonb_array_elements(c.data::jsonb -> 'candidats') WITH ORDINALITY x(e, o)
                             WHERE e ->> 'nom' IS DISTINCT FROM OLD.nom), '[]'::jsonb))::text,
         updated_at = now()
   WHERE c.country = OLD.country AND c.poste_id = OLD.poste_id AND c.city IS NOT DISTINCT FROM OLD.city
     AND jsonb_typeof(c.data::jsonb -> 'candidats') = 'array'
     AND (c.data::jsonb ->> 'dateDebutCandidatures')::numeric::bigint = OLD.cle_scrutin
     AND floor(extract(epoch FROM now()) * 1000) < (c.data::jsonb ->> 'dateVote')::numeric
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(c.data::jsonb -> 'candidats') e WHERE e ->> 'nom' = OLD.nom);
  RETURN OLD;
END; $function$;
REVOKE ALL ON FUNCTION public.candidatures_retrait_bulletin() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS candidatures_retrait_bulletin ON public.candidatures;
CREATE TRIGGER candidatures_retrait_bulletin AFTER DELETE ON public.candidatures
  FOR EACH ROW EXECUTE FUNCTION public.candidatures_retrait_bulletin();
