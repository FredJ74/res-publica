-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011194931 (UTC), nom
-- `calendrier_succession_portes_pnj`.
-- Le registre passe de 664 a 665 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 f552d7dfad9df0aa80273518d2d3e197, 12857 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LES PORTES PNJ, ET LA SURCHARGE A REFERMER (2/4)
--
-- ELLE COMMENCE PAR REPARER LA PRECEDENTE, ET C'EST LE PIEGE DE SIGNATURE DOCUMENTE. En ajoutant
-- un cinquieme parametre a `election_resultats_consigner`, la migration 1/4 n'a pas REMPLACE la
-- fonction : elle en a CREE une seconde. Les deux coexistaient, et un appel a quatre arguments
-- devenait AMBIGU -- la version a cinq parametres ayant un defaut, les deux candidates
-- correspondaient. Mesure faite immediatement apres l'application, l'ancienne est supprimee ici.
--
-- PUIS LES DEUX PORTES PNJ. `elections_voix_pnj_enregistrer` et
-- `tracts_electoraux_distribuer_interne` refusaient quand la phase etait celle du mandat ou de la
-- vacance. La condition est remplacee par celle qui portait deja tout le sens : le scrutin n'est
-- plus ouvert une fois sa proclamation passee. Rien d'autre ne bouge -- ni le dimanche
-- obligatoire des tracts, ni la fenetre de vote, ni les verrous consultatifs, ni les taux, ni
-- les effets, ni le decompte du vote contre.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CALENDRIER ELECTORAL COMMUN (2/3 : LES PORTES PNJ, ET LA SURCHARGE A REFERMER)
-- 11 octobre 2026

-- ============================================================================================
-- 3 bis. LA SURCHARGE LAISSEE PAR LE CINQUIEME PARAMETRE
-- ============================================================================================
-- LE PIEGE DE SIGNATURE, CONSTATE IMMEDIATEMENT APRES LA MIGRATION 1/3. `CREATE OR REPLACE
-- FUNCTION` avec un parametre de plus ne REMPLACE rien : il CREE une seconde fonction. Les deux
-- coexistaient donc, et un appel a quatre arguments devenait AMBIGU -- la version a cinq
-- parametres ayant un defaut, les deux candidates correspondaient. L'ancienne part ici, et il
-- n'en reste qu'une.
DROP FUNCTION IF EXISTS public.election_resultats_consigner(text, jsonb, jsonb, jsonb);

-- ============================================================================================
-- 4. LES DEUX PORTES PNJ : LE MANDAT NE FERME PLUS LE SCRUTIN
-- ============================================================================================
-- Elles refusaient quand la phase etait celle du mandat ou de la vacance. La condition est
-- remplacee par celle qui portait deja tout le sens : le scrutin n'est plus ouvert une fois sa
-- proclamation passee. Rien d'autre ne bouge -- ni le dimanche obligatoire des tracts, ni la
-- fenetre de vote, ni les verrous consultatifs, ni les taux, ni les effets.
CREATE OR REPLACE FUNCTION public.elections_voix_pnj_enregistrer(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_pnj_nom text, p_canal text, p_cle text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej  jsonb;
  v_p    record;
  v_c    record;
  v_d    jsonb;
  v_tour bigint;
  v_nom  text;
  v_cle  text;
  v_ms   numeric := floor(extract(epoch FROM now()) * 1000);
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  IF p_canal NOT IN ('conference', 'jean_lou') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'canal_invalide');
  END IF;
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'voix_pnj');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF COALESCE(btrim(p_candidat), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;

  SELECT country, current_city INTO v_p FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT id, country, data INTO v_c FROM public.cycles_electoraux WHERE id = p_cycle_id;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'));
  END IF;
  BEGIN v_d := v_c.data::jsonb; EXCEPTION WHEN OTHERS THEN v_d := NULL; END;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_illisible'));
  END IF;
  -- UN SCRUTIN EST CLOS QUAND IL EST DEPOUILLE, PAS QUAND UN MANDAT EST EN COURS (11 octobre
  -- 2026). La phase du mandat n'existe plus, et un titulaire en exercice est desormais l'etat
  -- NORMAL d'un scrutin de succession : le refuser fermait toute la mecanique pendant les cinq
  -- semaines du mandat.
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR jsonb_typeof(v_d -> 'dateResultats') <> 'number'
     OR v_ms >= (v_d ->> 'dateResultats')::numeric THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_clos'));
  END IF;
  v_tour := CASE WHEN jsonb_typeof(v_d -> 'dateVote') = 'number' THEN (v_d ->> 'dateVote')::numeric::bigint END;
  IF v_tour IS NULL THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_sans_date'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'));
  END IF;

  IF p_cle IS NOT NULL AND btrim(p_cle) <> '' THEN
    v_cle := btrim(p_cle);
    v_nom := COALESCE(NULLIF(btrim(COALESCE(p_pnj_nom, '')), ''), v_cle);
  ELSE
    v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
    IF v_nom = '' THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
    END IF;
    v_cle := COALESCE(v_c.country, v_p.country, '') || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;
    v_nom := p_pnj_nom;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('voix_pnj|' || p_cycle_id || '|' || v_tour || '|' || v_cle));
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND pnj_cle = v_cle)
     OR (jsonb_typeof(v_d -> 'votesPNJ') = 'object' AND ((v_d -> 'votesPNJ') ? v_nom
         OR (v_d -> 'votesPNJ') ? replace(COALESCE(p_pnj_nom, ''), '''', ''))) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vote'));
  END IF;

  INSERT INTO public.elections_tracts_pnj (cycle_id, tour, pnj_cle, pnj_nom, candidat, sens, effet, joueur, canal)
  VALUES (p_cycle_id, v_tour, v_cle, v_nom, p_candidat, 1, 1, p_joueur, p_canal);

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'effet', 1, 'tour', v_tour, 'cle', v_cle, 'canal', p_canal));
END;
$function$;

-- Le tract electoral : meme retrait, et rien d'autre. La fenetre [dateVote, dateResultats) et
-- l'obligation du dimanche portaient deja toute la contrainte ; la lecture de la phase du mandat
-- y etait redondante hier et fausse aujourd'hui.
CREATE OR REPLACE FUNCTION public.tracts_electoraux_distribuer_interne(p_requete text, p_joueur text, p_cycle_id text, p_candidat text, p_sens text, p_pnj_nom text, p_vol_pnj integer, p_instant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rej     jsonb;
  v_p       record;
  v_c       record;
  v_d       jsonb;
  v_ms      bigint;
  v_tour    bigint;
  v_ville   text;
  v_nom     text;
  v_cle     text;
  v_taux    integer;
  v_jet     integer;
  v_sens    smallint;
  v_effet   smallint;
  v_score   numeric;
  v_inv     jsonb;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_joueur, 'tract_electoral');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  IF p_sens NOT IN ('pour', 'contre') OR COALESCE(btrim(p_candidat), '') = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'parametres_invalides'));
  END IF;
  v_sens := CASE WHEN p_sens = 'pour' THEN 1 ELSE -1 END;

  SELECT country, current_city, stats, resources, inventory, pa INTO v_p FROM public.personnages WHERE name = p_joueur;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'joueur_introuvable'));
  END IF;

  SELECT id, country, city, poste_id, data INTO v_c FROM public.cycles_electoraux WHERE id = p_cycle_id;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'));
  END IF;
  BEGIN v_d := v_c.data::jsonb; EXCEPTION WHEN OTHERS THEN v_d := NULL; END;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_illisible'));
  END IF;
  IF COALESCE(v_c.poste_id, v_d ->> 'posteId', '') NOT IN ('president', 'maire', 'depute') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'scrutin_non_concerne'));
  END IF;

  IF v_c.country IS DISTINCT FROM v_p.country THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_pays'));
  END IF;

  v_ms := floor(extract(epoch FROM p_instant) * 1000)::bigint;
  v_tour := CASE WHEN jsonb_typeof(v_d -> 'dateVote') = 'number' THEN (v_d ->> 'dateVote')::numeric::bigint END;
  IF v_tour IS NULL OR jsonb_typeof(v_d -> 'dateResultats') <> 'number'
     OR COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR v_ms < v_tour OR v_ms >= (v_d ->> 'dateResultats')::numeric::bigint THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_phase_vote'));
  END IF;

  IF extract(isodow FROM (p_instant AT TIME ZONE 'Europe/Paris')) <> 7 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pas_dimanche'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(COALESCE(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'));
  END IF;

  v_ville := NULLIF(COALESCE(v_c.city, v_d ->> 'city'), '');
  IF v_ville IS NOT NULL THEN
    IF v_p.current_city IS DISTINCT FROM v_ville THEN
      RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_ville', 'ville_scrutin', v_ville));
    END IF;
  ELSIF COALESCE(v_p.current_city, '') NOT IN ('capitale', 'ville_a', 'ville_b', 'caserne', 'qhs') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'hors_territoire'));
  END IF;

  v_inv := CASE WHEN jsonb_typeof(v_p.inventory) = 'array' THEN v_p.inventory ELSE '[]'::jsonb END;
  IF NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(v_inv) i
     WHERE i ->> 'type' = 'tract' AND i ->> 'cible' = p_candidat
       AND COALESCE(i ->> 'tractType', 'pour') = p_sens
       AND COALESCE(i ->> 'origineQuete', '') <> 'jean_lou'
       AND jsonb_typeof(i -> 'quantite') = 'number' AND (i ->> 'quantite')::numeric >= 1
  ) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'tract_absent'));
  END IF;

  IF COALESCE(v_p.pa, 0) < 1 THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'));
  END IF;

  v_nom := public.tracts_electoraux_nom_pnj(p_pnj_nom);
  IF v_nom = '' THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'pnj_invalide'));
  END IF;
  v_cle := v_c.country || ':' || COALESCE(v_p.current_city, '') || ':' || v_nom;

  PERFORM pg_advisory_xact_lock(hashtext('tract_pnj|' || p_cycle_id || '|' || v_tour || '|' || v_cle));
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND pnj_cle = v_cle)
     OR (jsonb_typeof(v_d -> 'votesPNJ') = 'object' AND ((v_d -> 'votesPNJ') ? p_pnj_nom
         OR (v_d -> 'votesPNJ') ? replace(p_pnj_nom, '''', ''))) THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'deja_vote'));
  END IF;

  v_taux := public.tracts_electoraux_taux(
    public.assemblee_stat_base(v_p.stats, 'CHA'),
    CASE WHEN jsonb_typeof(v_p.resources -> 'inf') = 'number' THEN (v_p.resources ->> 'inf')::numeric ELSE 0 END,
    LEAST(30, GREATEST(0, COALESCE(p_vol_pnj, 10))));
  v_jet := floor(random() * 100)::integer + 1;
  IF v_jet > v_taux THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
      'ok', true, 'reussi', false, 'consomme', 1, 'pa', 1, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens));
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('tract_cand|' || p_cycle_id || '|' || v_tour || '|' || p_candidat));
  IF v_sens = 1 THEN
    v_effet := 1;
  ELSE
    SELECT
      (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votes') = 'object' THEN v_d -> 'votes' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + (SELECT count(*) FROM jsonb_each_text(CASE WHEN jsonb_typeof(v_d -> 'votesPNJ') = 'object' THEN v_d -> 'votesPNJ' ELSE '{}'::jsonb END) e WHERE e.value = p_candidat)
    + COALESCE((SELECT sum(effet) FROM public.elections_tracts_pnj WHERE cycle_id = p_cycle_id AND tour = v_tour AND candidat = p_candidat), 0)
    INTO v_score;
    v_effet := CASE WHEN v_score >= 1 THEN -1 ELSE 0 END;
  END IF;

  INSERT INTO public.elections_tracts_pnj (cycle_id, tour, pnj_cle, pnj_nom, candidat, sens, effet, joueur)
  VALUES (p_cycle_id, v_tour, v_cle, p_pnj_nom, p_candidat, v_sens, v_effet, p_joueur);

  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'reussi', true, 'consomme', 1, 'pa', 1, 'jet', v_jet, 'taux', v_taux, 'sens', p_sens,
    'effet', v_effet, 'tour', v_tour));
END;
$function$;