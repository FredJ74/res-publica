-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine politique et elections -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- candidature_publier(text,text,numeric,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.candidature_publier(p_poste text, p_city text, p_cle_scrutin numeric, p_titre text, p_contenu text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_inf numeric; v_poste record; v_fiche record;
  v_ville text; v_cle text; v_id text; v_topic text; v_forum text; v_temps text;
  v_paiement jsonb; v_titre text; v_contenu text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO v_fiche FROM public.personnages_donnees WHERE name = v_nom;
  v_pays := v_fiche.country;

  SELECT * INTO v_poste FROM public.postes_electifs_regles WHERE poste_id = p_poste;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;

  IF coalesce(v_fiche.domicile->>'country', v_pays) IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_domicilie');
  END IF;
  v_inf := CASE WHEN jsonb_typeof(v_fiche.resources->'inf') = 'number'
                THEN (v_fiche.resources->>'inf')::numeric ELSE 0 END;
  IF v_inf < v_poste.min_inf THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'influence_insuffisante',
                              'requis', v_poste.min_inf, 'reel', v_inf);
  END IF;
  IF p_poste = 'depute' THEN
    IF v_fiche.poste_depute IS NOT NULL AND jsonb_typeof(v_fiche.poste_depute) = 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_depute');
    END IF;
  ELSIF v_fiche.poste->>'id' IS NOT NULL AND v_fiche.poste->>'id' <> p_poste THEN
    IF (v_fiche.poste->>'id' = 'president' AND p_poste = 'maire')
       OR (v_fiche.poste->>'id' = 'maire' AND p_poste = 'president') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cumul_interdit');
    END IF;
  END IF;

  v_ville := CASE WHEN v_poste.niveau = 'ville' THEN nullif(p_city, '') ELSE NULL END;
  v_cle := p_poste || CASE WHEN v_ville IS NOT NULL THEN '_' || v_ville ELSE '' END;
  v_id := v_pays || '_' || v_cle || '_' || v_nom
          || CASE WHEN p_cle_scrutin IS NOT NULL THEN '_' || p_cle_scrutin::bigint::text ELSE '' END;

  IF EXISTS (SELECT 1 FROM public.candidatures WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_candidat', true, 'id', v_id,
                              'topic_id', (SELECT topic_id FROM public.candidatures WHERE id = v_id));
  END IF;

  v_paiement := public.payer_ordre(v_nom, 'deposer_candidature', 2, 0);
  IF NOT coalesce((v_paiement->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paiement->>'raison', 'paiement_refuse'));
  END IF;

  v_contenu := coalesce(nullif(btrim(p_contenu), ''), '(programme vide)');
  v_titre := coalesce(nullif(btrim(p_titre), ''),
                      '🗳️ Programme de ' || v_nom || ' — ' || v_poste.nom);
  v_topic := 'topic-programme-' || v_id;
  -- LE FORUM DE LA JURIDICTION DU SCRUTIN. Un scrutin de ville publie dans le Local de CETTE
  -- ville -- pas celui ou le candidat se trouve ; un scrutin national publie au National.
  v_forum := CASE WHEN v_poste.niveau = 'ville' AND v_ville IS NOT NULL
                  THEN 'local_' || v_ville ELSE 'national' END;
  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY" · "HH24"h"MI');

  INSERT INTO public.candidatures (id, country, poste_id, city, nom, programme, archetype,
                                   created_at, topic_id)
  VALUES (v_id, v_pays, p_poste, v_ville, v_nom, v_contenu, v_fiche.archetype, now(), v_topic);

  PERFORM set_config('rp.programme_officiel', '1', true);
  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies, last_post_author, last_post_time,
     author_is_org, author_secret)
  VALUES (v_topic, v_forum, v_titre, v_nom, v_pays, v_temps, 1, 0, v_nom, v_temps, false, false)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.forum_posts (id, topic_id, author, content, time)
  VALUES (v_topic || '-prog', v_topic, v_nom, v_contenu, v_temps)
  ON CONFLICT (id) DO NOTHING;
  PERFORM set_config('rp.programme_officiel', '0', true);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'topic_id', v_topic, 'forum', v_forum,
                            'poste', p_poste, 'city', v_ville, 'pa', v_paiement->'pa');
END; $function$;

-- candidatures_cloture() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.candidatures_cloture()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data text;
  v_d    jsonb;
  v_ms   numeric := floor(extract(epoch FROM now()) * 1000);
BEGIN
  SELECT data INTO v_data FROM public.cycles_electoraux
   WHERE id = NEW.country || '_' || NEW.poste_id || CASE WHEN NEW.city IS NOT NULL THEN '_' || NEW.city ELSE '' END;
  IF NOT FOUND THEN RETURN NEW; END IF;          -- cycle cree par le client juste avant la candidature
  BEGIN v_d := v_data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR COALESCE(v_d ->> 'phase', '') IN ('mandat', 'vacant')
     OR (jsonb_typeof(v_d -> 'dateDebutCampagne') = 'number' AND v_ms >= (v_d ->> 'dateDebutCampagne')::numeric) THEN
    RAISE EXCEPTION 'candidatures_closes' USING HINT = 'Les candidatures a ce scrutin sont closes (cloture du lundi 00:01).';
  END IF;
  RETURN NEW;
END;
$function$;

-- cycle_electoral_aligne_dimanche(jsonb,timestamp with time zone) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cycle_electoral_aligne_dimanche(p_d jsonb, p_maintenant timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ms       numeric := floor(extract(epoch FROM p_maintenant) * 1000);
  v_loc      timestamp;
  v_dim      timestamp;
  v_vote     numeric;
  v_res      numeric;
  v_cloture  numeric;
BEGIN
  IF p_d IS NULL OR jsonb_typeof(p_d) <> 'object' OR jsonb_typeof(p_d -> 'dateVote') <> 'number' THEN RETURN p_d; END IF;
  IF COALESCE((p_d ->> 'resultatsTraites')::boolean, false) OR COALESCE(p_d ->> 'phase', '') IN ('mandat', 'vacant') THEN RETURN p_d; END IF;
  IF (p_d ->> 'dateVote')::numeric <= v_ms THEN RETURN p_d; END IF;

  v_loc := to_timestamp((p_d ->> 'dateVote')::numeric / 1000) AT TIME ZONE 'Europe/Paris';
  v_dim := date_trunc('day', v_loc) + ((7 - extract(isodow FROM v_loc)::int) % 7) * interval '1 day' + interval '1 minute';
  IF v_dim < v_loc THEN v_dim := v_dim + interval '7 days'; END IF;
  v_vote    := floor(extract(epoch FROM (v_dim AT TIME ZONE 'Europe/Paris')) * 1000);
  v_res     := floor(extract(epoch FROM ((date_trunc('day', v_dim) + interval '1 day') AT TIME ZONE 'Europe/Paris')) * 1000);
  v_cloture := floor(extract(epoch FROM ((date_trunc('day', v_dim) - interval '6 days' + interval '1 minute') AT TIME ZONE 'Europe/Paris')) * 1000);

  IF v_vote = (p_d ->> 'dateVote')::numeric AND jsonb_typeof(p_d -> 'dateResultats') = 'number'
     AND (p_d ->> 'dateResultats')::numeric = v_res THEN
    RETURN p_d;
  END IF;
  IF jsonb_typeof(p_d -> 'dateDebutCampagne') = 'number'
     AND ((p_d ->> 'dateDebutCampagne')::numeric <= v_ms OR (p_d ->> 'dateDebutCampagne')::numeric > v_cloture) THEN
    v_cloture := (p_d ->> 'dateDebutCampagne')::numeric;
  END IF;
  RETURN p_d || jsonb_build_object('dateDebutCampagne', v_cloture, 'dateVote', v_vote, 'dateResultats', v_res,
                                   'realigneDimancheTs', v_ms);
END;
$function$;

-- cycles_electoraux_dimanche() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cycles_electoraux_dimanche()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_d jsonb;
  v_n jsonb;
BEGIN
  BEGIN v_d := NEW.data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  v_n := public.cycle_electoral_aligne_dimanche(v_d, now());
  IF v_n IS DISTINCT FROM v_d THEN NEW.data := v_n::text; END IF;
  RETURN NEW;
END;
$function$;

-- elections_voix_pnj_enregistrer(text,text,text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
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
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false) OR COALESCE(v_d ->> 'phase', '') IN ('mandat', 'vacant') THEN
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

-- indice_ville_ajuster_interne(text,text,text,integer) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.indice_ville_ajuster_interne(p_pays text, p_ville text, p_cle text, p_delta integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text := p_pays || '_' || p_ville; v_data jsonb; v_val integer;
BEGIN
  IF p_pays IS DISTINCT FROM 'republic' THEN RETURN; END IF;
  SELECT data INTO v_data FROM public.indices_villes WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  v_val := coalesce((v_data ->> p_cle)::integer, 50) + p_delta;
  v_val := greatest(0, least(100, v_val));
  UPDATE public.indices_villes
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object(p_cle, v_val),
         updated_at = now()
   WHERE id = v_id;
END;
$function$;

-- militant_recruter(text,text,text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.militant_recruter(p_nom text, p_organisation_id text DEFAULT NULL::text, p_ville text DEFAULT NULL::text, p_batiment text DEFAULT NULL::text, p_piece text DEFAULT NULL::text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT NULL::integer, p_cost integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_plafond constant integer := 2;
  v_moi text; v_prof record; v_id text; v_nom text; v_pay jsonb; v_pays text;
  v_deja integer; v_pa integer; v_cost integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_nom := btrim(COALESCE(p_nom, ''));
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;

  SELECT * INTO v_prof FROM public.pnj_metiers_profils WHERE metier = 'militant';
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'profil_metier_absent'); END IF;

  SELECT COALESCE(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  -- PLAFOND COMPTE AU SERVEUR, sur le socle qui fait autorite.
  SELECT count(*) INTO v_deja FROM public.pnj_membres m
   WHERE m.famille = 'militant' AND m.proprietaire_pj = v_moi AND m.statut = 'actif';
  IF v_deja >= c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_militants',
      'plafond', c_plafond, 'deja', v_deja); END IF;

  v_id := 'militant-' || substr(md5(lower(btrim(v_moi)) || '|' || lower(v_nom)), 1, 12);
  IF EXISTS (SELECT 1 FROM public.pnj_membres WHERE id = v_id AND statut = 'actif') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_recrute', 'pnj_id', v_id); END IF;

  v_pa   := COALESCE(p_pa,   v_prof.pa_initial,   0);
  v_cost := COALESCE(p_cost, v_prof.cout_initial, 0);
  IF p_fn IS NOT NULL AND (v_pa > 0 OR v_cost > 0) THEN
    v_pay := public.payer_ordre(v_moi, p_fn, v_pa, v_cost);
  ELSE
    v_pay := jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF COALESCE((v_pay->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paiement_refuse', 'paiement', v_pay); END IF;

  -- IL NE SUIT PERSONNE : un militant reste sur son lieu de militance, donc position PROPRE et
  -- aucun leader. C'est l'autre etat autorise par pnj_position_deux_etats.
  INSERT INTO public.pnj_membres (id, famille, classe, nom, pays, proprietaire_pj,
      ville, building_id, room_id, pa, statut, car_int, car_cha, car_vol, car_per, car_dup, car_ent)
  VALUES (v_id, 'militant', 'beta', v_nom, v_pays, v_moi,
      p_ville, p_batiment, p_piece, 12, 'actif',
      v_prof.car_int, v_prof.car_cha, v_prof.car_vol,
      v_prof.car_per, v_prof.car_dup, v_prof.car_ent)
  ON CONFLICT (id) DO UPDATE SET
      statut = 'actif', proprietaire_pj = EXCLUDED.proprietaire_pj,
      ville = EXCLUDED.ville, building_id = EXCLUDED.building_id, room_id = EXCLUDED.room_id,
      car_int = EXCLUDED.car_int, car_cha = EXCLUDED.car_cha, car_vol = EXCLUDED.car_vol,
      car_per = EXCLUDED.car_per, car_dup = EXCLUDED.car_dup, car_ent = EXCLUDED.car_ent,
      maj_le = now();

  INSERT INTO public.pnj_militants_metier (pnj_id, organisation_id, grade, rejoint_le)
  VALUES (v_id, p_organisation_id, 'Militant (PNJ)', now())
  ON CONFLICT (pnj_id) DO UPDATE SET
      organisation_id = EXCLUDED.organisation_id, grade = EXCLUDED.grade;

  -- Le registre historique est CONSERVE : sbGetMesMilitants le lit encore, et on ne retire pas une
  -- structure dont un lecteur vivant depend.
  INSERT INTO public.militants_recrutes (id, country, recruteur, data)
  VALUES (v_id, v_pays, v_moi, jsonb_build_object('nom', v_nom, 'pnj_id', v_id,
            'jour', (extract(epoch from now()) * 1000)::bigint))
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'nom', v_nom, 'metier', 'militant',
    'caracteristiques', public.pnj_metier_profil('militant'),
    'paiement', v_pay, 'militants', v_deja + 1, 'plafond', c_plafond);
END; $function$;

-- poste_accepter_nomination(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_accepter_nomination(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pays text; v_n record;
BEGIN
  SELECT d.name, d.country INTO v_nom, v_pays
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO v_n FROM public.nominations_en_attente WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR v_n.traitee THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nomination_introuvable');
  END IF;
  IF v_n.destinataire IS DISTINCT FROM v_nom OR v_n.country IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nomination_pas_pour_vous');
  END IF;

  UPDATE public.nominations_en_attente SET traitee = true WHERE id = p_id;
  RETURN public.poste_attribuer_interne(v_pays, v_n.poste_id, v_n.city, v_nom, 'nomination');
END;
$function$;

-- poste_attribuer_candidature(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_attribuer_candidature(p_poste text, p_city text, p_candidat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pays text; v_depuis timestamptz;
BEGIN
  SELECT a.nom, a.pays INTO v_nom, v_pays FROM public.poste_autorite_de(p_poste, p_city) a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_candidat IS NULL OR btrim(p_candidat) = ''
     OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_introuvable');
  END IF;

  SELECT depuis INTO v_depuis FROM public.postes_attribues
   WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  IF v_depuis IS NOT NULL AND v_depuis > now() - interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_protege');
  END IF;

  RETURN public.poste_attribuer_interne(v_pays, p_poste, p_city, p_candidat, 'candidature_acceptee');
END;
$function$;

-- poste_attribuer_interne(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_attribuer_interne(p_pays text, p_poste text, p_city text, p_titulaire text, p_source text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  v_label text; v_ancien text;
BEGIN
  SELECT r.label INTO v_label FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF v_label IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;

  SELECT a.titulaire INTO v_ancien FROM public.postes_attribues a WHERE a.id = v_id;

  -- Le predecesseur perd la fonction : registre d'abord, miroir de fiche ensuite.
  IF v_ancien IS NOT NULL AND v_ancien IS DISTINCT FROM p_titulaire THEN
    UPDATE public.personnages_donnees SET poste = NULL
     WHERE name = v_ancien AND poste ->> 'id' = p_poste;
  END IF;

  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, depuis, source, updated_at)
  VALUES (v_id, p_pays, p_poste, p_city, p_titulaire, now(), p_source, now())
  ON CONFLICT (id) DO UPDATE
    SET titulaire = EXCLUDED.titulaire, depuis = now(),
        source = EXCLUDED.source, updated_at = now();

  -- Le PNJ qui tenait la fonction s'efface.
  DELETE FROM public.titulaires_pnj
   WHERE country = p_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city;

  -- Miroir d'affichage sur la fiche : atteste, donc accepte par le trigger.
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', p_poste, 'name', v_label, 'city', p_city,
                                    'nommeLe', (extract(epoch from now())*1000)::bigint)
   WHERE name = p_titulaire;

  RETURN jsonb_build_object('ok', true, 'poste', p_poste, 'city', p_city,
                            'titulaire', p_titulaire, 'predecesseur', v_ancien);
END;
$function$;

-- poste_autorite_de(text,text) -> TABLE(nom text, pays text, autorite text, scope text) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_autorite_de(p_poste text, p_city text)
 RETURNS TABLE(nom text, pays text, autorite text, scope text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_poste jsonb; v_regle record;
BEGIN
  SELECT d.name, d.country, d.poste INTO v_nom, v_pays, v_poste
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN RETURN; END IF;

  SELECT * INTO v_regle FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF NOT FOUND OR v_regle.nomme_par IS NULL THEN RETURN; END IF;

  -- Le poste porte par la fiche est deja atteste (trigger) : on peut s'y fier.
  IF (v_poste ->> 'id') IS DISTINCT FROM v_regle.nomme_par THEN RETURN; END IF;

  -- L'AUTORITE est-elle territoriale ? C'est autorite_scope qui le dit, plus
  -- scope : un juge siege en ville mais est nomme par un ministre national.
  IF coalesce(v_regle.autorite_scope, v_regle.scope) = 'ville'
     AND (v_poste ->> 'city') IS DISTINCT FROM p_city THEN
    RETURN;
  END IF;

  RETURN QUERY SELECT v_nom, v_pays, v_regle.nomme_par, v_regle.scope;
END;
$function$;

-- poste_est_atteste(text,jsonb,text) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_est_atteste(p_nom text, p_poste jsonb, p_pays text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text; v_city text; v_cycle text;
BEGIN
  IF p_poste IS NULL OR jsonb_typeof(p_poste) = 'null' THEN RETURN true; END IF;
  IF jsonb_typeof(p_poste) <> 'object' THEN RETURN false; END IF;
  v_id   := p_poste ->> 'id';
  v_city := nullif(p_poste ->> 'city', '');
  IF v_id IS NULL OR v_id = '' THEN RETURN false; END IF;

  -- a) POSTES ELUS : la verite est le depouillement, ecrit par le cron.
  IF v_id IN ('president', 'maire', 'chef_syndicat') THEN
    SELECT c.data INTO v_cycle FROM public.cycles_electoraux c
     WHERE c.country = p_pays AND c.poste_id = v_id
       AND c.city IS NOT DISTINCT FROM v_city
     LIMIT 1;
    IF v_cycle IS NULL OR left(btrim(v_cycle), 1) <> '{' THEN RETURN false; END IF;
    RETURN (v_cycle::jsonb ->> 'eluId') = p_nom;
  END IF;

  IF v_id = 'depute' THEN
    SELECT c.data INTO v_cycle FROM public.cycles_electoraux c
     WHERE c.country = p_pays AND c.poste_id = 'depute'
       AND c.city IS NOT DISTINCT FROM v_city
     LIMIT 1;
    IF v_cycle IS NULL OR left(btrim(v_cycle), 1) <> '{' THEN RETURN false; END IF;
    RETURN (v_cycle::jsonb -> 'elus') ? p_nom;
  END IF;

  -- b) POSTES MILITAIRES : la verite est la compagnie.
  IF v_id = 'capitaine' THEN
    RETURN EXISTS (SELECT 1 FROM public.compagnies_militaires m
                    WHERE m.data ->> 'capitaineNom' = p_nom);
  END IF;
  IF v_id = 'lieutenant' THEN
    RETURN EXISTS (SELECT 1 FROM public.compagnies_militaires m,
                        jsonb_array_elements(coalesce(m.data -> 'sections', '[]'::jsonb)) s
                    WHERE s ->> 'lieutenantNom' = p_nom);
  END IF;

  -- c) TOUT LE RESTE : un poste nomme n'existe que s'il est inscrit au registre. Fail closed --
  --    un identifiant inconnu n'est jamais accepte.
  RETURN EXISTS (SELECT 1 FROM public.postes_attribues a
                  WHERE a.titulaire = p_nom AND a.poste_id = v_id
                    AND a.country = p_pays AND a.city IS NOT DISTINCT FROM v_city);
END;
$function$;

-- poste_nommer(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_nommer(p_poste text, p_city text, p_destinataire text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_scope text;
  v_est_pj boolean; v_id text; v_depuis timestamptz;
BEGIN
  SELECT a.nom, a.pays, a.scope INTO v_nom, v_pays, v_scope
    FROM public.poste_autorite_de(p_poste, p_city) a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;
  IF p_destinataire IS NULL OR btrim(p_destinataire) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_absent');
  END IF;

  -- Protection de 3 jours du titulaire fraichement nomme (regle de jeu existante).
  SELECT depuis INTO v_depuis FROM public.postes_attribues
   WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  IF v_depuis IS NOT NULL AND v_depuis > now() - interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_protege');
  END IF;

  v_est_pj := EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_destinataire);

  IF NOT v_est_pj THEN
    -- Destinataire PNJ : prise de fonction immediate, comme le fait le jeu aujourd'hui.
    UPDATE public.personnages_donnees SET poste = NULL
     WHERE name = (SELECT titulaire FROM public.postes_attribues
                    WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national'));
    DELETE FROM public.postes_attribues
     WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
    INSERT INTO public.titulaires_pnj (id, country, poste_id, city, nom_pnj, updated_at)
    VALUES (v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national'),
            v_pays, p_poste, p_city, p_destinataire, now())
    ON CONFLICT (id) DO UPDATE SET nom_pnj = EXCLUDED.nom_pnj, updated_at = now();
    RETURN jsonb_build_object('ok', true, 'decision', 'pnj_en_fonction', 'titulaire', p_destinataire);
  END IF;

  v_id := 'nom-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' ||
          substr(md5(random()::text), 1, 6);
  DELETE FROM public.nominations_en_attente
   WHERE country = v_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city
     AND traitee IS FALSE;
  INSERT INTO public.nominations_en_attente (id, country, poste_id, city, destinataire, par)
  VALUES (v_id, v_pays, p_poste, p_city, p_destinataire, v_nom);

  RETURN jsonb_build_object('ok', true, 'decision', 'proposition_envoyee',
                            'id', v_id, 'destinataire', p_destinataire);
END;
$function$;

-- poste_postuler(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_postuler(p_poste text, p_city text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_pays text; v_regle record; v_depuis timestamptz; v_autorite_pj boolean;
BEGIN
  SELECT d.name, d.country INTO v_nom, v_pays
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO v_regle FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu'); END IF;

  SELECT depuis INTO v_depuis FROM public.postes_attribues
   WHERE id = v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  IF v_depuis IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_deja_occupe_par_un_joueur');
  END IF;

  -- L'autorite de nomination est-elle tenue par un joueur ?
  v_autorite_pj := EXISTS (
    SELECT 1 FROM public.postes_attribues a
     WHERE a.country = v_pays AND a.poste_id = v_regle.nomme_par
       AND (v_regle.scope = 'pays' OR a.city IS NOT DISTINCT FROM p_city))
   OR EXISTS (
    SELECT 1 FROM public.cycles_electoraux c
     WHERE c.country = v_pays AND c.poste_id = v_regle.nomme_par
       AND left(btrim(c.data), 1) = '{' AND (c.data::jsonb ->> 'eluId') IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.personnages_donnees d
                    WHERE d.name = c.data::jsonb ->> 'eluId'));
  IF v_autorite_pj THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_joueur_doit_decider');
  END IF;

  RETURN public.poste_attribuer_interne(v_pays, p_poste, p_city, v_nom, 'candidature_autorite_pnj');
END;
$function$;

-- poste_quitter() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_quitter()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text;
BEGIN
  SELECT d.name INTO v_nom FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  DELETE FROM public.postes_attribues WHERE titulaire = v_nom;
  UPDATE public.personnages_donnees SET poste = NULL WHERE name = v_nom;
  RETURN jsonb_build_object('ok', true, 'decision', 'demission');
END;
$function$;

-- poste_revoquer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_revoquer(p_poste text, p_city text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pays text; v_id text; v_titulaire text; v_depuis timestamptz;
BEGIN
  SELECT a.nom, a.pays INTO v_nom, v_pays FROM public.poste_autorite_de(p_poste, p_city) a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  v_id := v_pays || '_' || p_poste || '_' || coalesce(p_city, 'national');
  SELECT titulaire, depuis INTO v_titulaire, v_depuis FROM public.postes_attribues WHERE id = v_id;
  IF v_titulaire IS NULL THEN
    DELETE FROM public.titulaires_pnj
     WHERE country = v_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city;
    RETURN jsonb_build_object('ok', true, 'decision', 'pnj_revoque');
  END IF;
  IF v_depuis > now() - interval '3 days' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_protege');
  END IF;

  DELETE FROM public.postes_attribues WHERE id = v_id;
  UPDATE public.personnages_donnees SET poste = NULL
   WHERE name = v_titulaire AND poste ->> 'id' = p_poste;
  RETURN jsonb_build_object('ok', true, 'decision', 'revoque', 'ancien_titulaire', v_titulaire);
END;
$function$;

-- postes_nommes_regles_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.postes_nommes_regles_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      poste_id || '|' || coalesce(label, '')
               || '|' || coalesce(nomme_par, '')
               || '|' || coalesce(scope, '')
               || '|' || coalesce(autorite_scope, scope, ''),
      E'\n' ORDER BY poste_id COLLATE "C")), 16)
  FROM public.postes_nommes_regles;
$function$;
