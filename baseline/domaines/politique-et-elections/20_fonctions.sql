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

-- annonce_publique_interne(text,text) -> void | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.annonce_publique_interne(p_pays text, p_texte text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (p_pays, NULL, p_texte, public.jour_de_jeu_pays(CASE WHEN p_pays = 'global' THEN 'republic' ELSE p_pays END));
$function$;

-- candidature_autre_scrutin_actif(text,text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.candidature_autre_scrutin_actif(p_pays text, p_nom text, p_cycle_id text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
SELECT EXISTS(
 SELECT 1 FROM public.cycles_electoraux ce
 WHERE ce.country=p_pays AND ce.id<>p_cycle_id
 AND coalesce((ce.data::jsonb->>'resultatsTraites')::boolean,false)=false
 AND coalesce(ce.data::jsonb->>'phase','') NOT IN ('termine','terminee','resultats','clos')
 AND EXISTS (
  SELECT 1 FROM jsonb_array_elements(
   CASE WHEN jsonb_typeof(ce.data::jsonb->'candidats')='array' THEN ce.data::jsonb->'candidats' ELSE '[]'::jsonb END
  ) c WHERE c->>'nom'=p_nom
  AND NOT (coalesce((ce.data::jsonb->>'tour')::int,1)>1
           AND jsonb_typeof(ce.data::jsonb->'finalistes')='array'
           AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(ce.data::jsonb->'finalistes') f
             WHERE f->>'nom'=p_nom OR f#>>'{}'=p_nom))
 )
);
$function$;

-- candidature_deposer(text,text,numeric,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.candidature_deposer(p_poste text, p_city text, p_cle_scrutin numeric, p_candidat jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_cle text; v_id_cand text; v_id_cycle text;
  v_data jsonb; v_cands jsonb; v_n integer; v_city text;
  v_fiche record; v_poste record; v_inf numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_candidat IS NULL OR jsonb_typeof(p_candidat) <> 'object'
     OR coalesce(p_candidat ->> 'nom', '') <> v_moi THEN
    -- ON NE SE PORTE CANDIDAT QUE POUR SOI. Le client transmettait son propre nom dans l'objet :
    -- le serveur le relit, et refuse qu'il en nomme un autre.
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_nom');
  END IF;

  SELECT * INTO v_fiche FROM public.personnages_donnees WHERE name = v_moi;
  v_pays := v_fiche.country;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;

  -- L'ELIGIBILITE EST DESORMAIS VERIFIEE ICI (10 octobre 2026). Elle ne vivait qu'au navigateur
  -- sur ce chemin : une candidature presidentielle a 0 INF passait par la console. Les trois
  -- regles sont celles de candidature_publier, a la lettre.
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

  -- LA CLE DU CYCLE EST CELLE DU CLIENT, A LA LETTRE : <poste> ou <poste>_<ville>. Elle est
  -- reconstruite ici, et non recue, pour qu'un client ne puisse pas viser un autre scrutin.
  v_city := nullif(btrim(coalesce(p_city, '')), '');
  v_cle := p_poste || CASE WHEN v_city IS NOT NULL THEN '_' || v_city ELSE '' END;
  v_id_cycle := v_pays || '_' || v_cle;

  SELECT c.data::jsonb INTO v_data FROM public.cycles_electoraux c
   WHERE c.id = v_id_cycle FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_introuvable', 'cle', v_id_cycle);
  END IF;

  v_cands := CASE WHEN jsonb_typeof(v_data -> 'candidats') = 'array'
                  THEN v_data -> 'candidats' ELSE '[]'::jsonb END;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_cands) e WHERE e ->> 'nom' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;


  PERFORM pg_advisory_xact_lock(hashtext('candidature_unique|' || v_moi));
  IF public.candidature_autre_scrutin_actif(v_pays,v_moi,v_id_cycle) THEN
    RETURN jsonb_build_object('ok',false,'raison','candidature_simultanee_interdite');
  END IF;

  v_id_cand := v_pays || '_' || v_cle || '_' || v_moi
    || CASE WHEN p_cle_scrutin IS NOT NULL THEN '_' || trim(to_char(p_cle_scrutin, 'FM999999999999999'))
            ELSE '' END;

  INSERT INTO public.candidatures (id, country, poste_id, city, nom, programme, archetype, created_at)
  VALUES (v_id_cand, v_pays, p_poste, v_city, v_moi,
          p_candidat ->> 'programme', p_candidat ->> 'archetype', now())
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;

  -- LE BULLETIN, DANS LA MEME TRANSACTION QUE LA LIGNE ATTESTEE.
  v_data := jsonb_set(v_data, '{candidats}', v_cands || jsonb_build_array(p_candidat), true);
  UPDATE public.cycles_electoraux SET data = v_data::text, updated_at = now()
   WHERE id = v_id_cycle;

  RETURN jsonb_build_object('ok', true, 'id', v_id_cand, 'cycle', v_data);
END;
$function$;

-- candidature_entrepot_modification_autorisee(text,jsonb,jsonb) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.candidature_entrepot_modification_autorisee(p_pays text, p_ancien jsonb, p_nouveau jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cle text; v_ancien jsonb; v_nouveau jsonb; v_ville text;
  v_nom text; v_pays text; v_maire text; v_ajout jsonb; v_liste jsonb;
  v_maintenant numeric := extract(epoch FROM now()) * 1000;
BEGIN
  FOR v_cle IN
    SELECT key FROM jsonb_each(coalesce(p_ancien, '{}'::jsonb))
    UNION SELECT key FROM jsonb_each(coalesce(p_nouveau, '{}'::jsonb))
  LOOP
    v_ancien := p_ancien -> v_cle;
    v_nouveau := p_nouveau -> v_cle;
    IF v_ancien IS NOT DISTINCT FROM v_nouveau THEN CONTINUE; END IF;
    IF split_part(v_cle, '|', 1) <> 'directeur_entrepot'
       AND coalesce(v_ancien ->> 'posteId', '') <> 'directeur_entrepot'
       AND coalesce(v_nouveau ->> 'posteId', '') <> 'directeur_entrepot' THEN
      CONTINUE;
    END IF;

    v_ville := split_part(v_cle, '|', 2);
    IF v_ville = '' OR v_ville = 'national'
       OR v_cle <> 'directeur_entrepot|' || v_ville THEN RETURN false; END IF;
    IF EXISTS (SELECT 1 FROM public.poste_autorite_de('directeur_entrepot', v_ville) a
                WHERE a.pays = p_pays) THEN CONTINUE; END IF;

    SELECT d.name, d.country INTO v_nom, v_pays
      FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;
    IF v_nom IS NULL OR v_pays IS DISTINCT FROM p_pays THEN RETURN false; END IF;
    IF jsonb_typeof(v_nouveau) IS DISTINCT FROM 'object'
       OR v_nouveau ->> 'posteId' IS DISTINCT FROM 'directeur_entrepot'
       OR v_nouveau ->> 'city' IS DISTINCT FROM v_ville
       OR jsonb_typeof(v_nouveau -> 'candidats') IS DISTINCT FROM 'array' THEN
      RETURN false;
    END IF;

    IF v_ancien IS NULL OR v_ancien -> 'traitee' = 'true'::jsonb THEN
      -- Nouveau dossier : meme fenetre de 48h et meme maire PJ que le client.
      SELECT d.name INTO v_maire FROM public.personnages_donnees d
       WHERE d.country = p_pays AND d.poste ->> 'id' = 'maire'
         AND d.poste ->> 'city' = v_ville LIMIT 1;
      IF v_maire IS NULL
         OR public.jsonb_cles_hors_liste(v_nouveau,
              ARRAY['posteId','city','candidats','echeanceTs','autoriteNom','traitee']) IS NOT NULL
         OR v_nouveau -> 'traitee' IS DISTINCT FROM 'false'::jsonb
         OR v_nouveau ->> 'autoriteNom' IS DISTINCT FROM v_maire
         OR jsonb_typeof(v_nouveau -> 'echeanceTs') IS DISTINCT FROM 'number' THEN
        RETURN false;
      END IF;
      IF abs((v_nouveau ->> 'echeanceTs')::numeric - v_maintenant - 172800000) > 60000 THEN
        RETURN false;
      END IF;
      v_liste := '[]'::jsonb;
    ELSE
      IF (v_nouveau - 'candidats') IS DISTINCT FROM (v_ancien - 'candidats') THEN RETURN false; END IF;
      v_liste := coalesce(v_ancien -> 'candidats', '[]'::jsonb);
      IF jsonb_typeof(v_liste) IS DISTINCT FROM 'array' THEN RETURN false; END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_liste) c
                WHERE c ->> 'nom' = v_nom AND coalesce(c ->> 'retiree', 'false') <> 'true') THEN
      RETURN false;
    END IF;
    v_ajout := v_nouveau -> 'candidats' -> -1;
    IF jsonb_typeof(v_ajout) IS DISTINCT FROM 'object'
       OR v_ajout ->> 'nom' IS DISTINCT FROM v_nom
       OR public.jsonb_cles_hors_liste(v_ajout, ARRAY['nom','depuisTs']) IS NOT NULL
       OR jsonb_typeof(v_ajout -> 'depuisTs') IS DISTINCT FROM 'number'
       OR (v_nouveau -> 'candidats') IS DISTINCT FROM (v_liste || jsonb_build_array(v_ajout)) THEN
      RETURN false;
    END IF;
    IF abs((v_ajout ->> 'depuisTs')::numeric - v_maintenant) > 60000 THEN RETURN false; END IF;
  END LOOP;
  RETURN true;
END;
$function$;

-- candidature_poste_tirage_appliquer(text,text,text,text,text[],text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.candidature_poste_tirage_appliquer(p_pays text, p_poste_id text, p_city text, p_label text, p_candidats text[], p_autorite text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pays text := lower(btrim(coalesce(p_pays,''))); v_poste text := btrim(coalesce(p_poste_id,''));
  v_city text := nullif(btrim(coalesce(p_city,'')),'');
  v_lib text; v_sujet text; v_gagnant text; v_titulaire text;
  v_res jsonb; v_pop_avant numeric; v_pop_apres numeric; v_sanction boolean := false;
BEGIN
  -- FAIL-CLOSED : une identite incomplete LEVE. Rendre un verdict voudrait dire « rien a faire ».
  IF v_pays = '' OR v_poste = '' THEN
    RAISE EXCEPTION 'candidature_poste_tirage_appliquer : pays et poste sont obligatoires (pays=%, poste=%)', p_pays, p_poste_id;
  END IF;
  IF p_candidats IS NULL OR array_length(p_candidats, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_candidat');
  END IF;
  v_lib := coalesce(nullif(btrim(coalesce(p_label,'')),''), v_poste);
  v_sujet := v_poste || '|' || coalesce(v_city, 'national');

  -- 1. RIEN A FAIRE ? Le registre fait autorite depuis le 15 septembre 2026. Verifie AVANT la
  --    revendication, pour ne pas consommer la journee d'un dossier qu'on n'a pas traite.
  SELECT titulaire INTO v_titulaire FROM public.postes_attribues
   WHERE country = v_pays AND poste_id = v_poste AND city IS NOT DISTINCT FROM v_city FOR UPDATE;
  IF v_titulaire IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_titulaire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_deja_attribue', 'titulaire', v_titulaire);
  END IF;

  -- 2. LA REVENDICATION, dans cette transaction.
  IF NOT public.acte_nocturne_revendiquer(v_pays, 'candidature_poste_tirage', v_sujet,
         jsonb_build_object('poste', v_poste, 'ville', v_city)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_traite_aujourdhui');
  END IF;

  -- 3. LE TIRAGE. Uniforme, comme Math.random() cote JavaScript, mais ici il est INDISSOCIABLE
  --    de ses consequences : un rejeu ne l'atteint pas.
  SELECT d.name INTO v_gagnant FROM public.personnages_donnees d
   WHERE d.name = ANY (p_candidats) AND d.country = v_pays ORDER BY random() LIMIT 1;
  IF v_gagnant IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'gagnant', NULL, 'raison', 'aucun_candidat_eligible');
  END IF;

  -- 4. LES CONSEQUENCES. REGISTRE D'ABORD : la fiche n'est plus une preuve, c'est
  --    postes_attribues qui atteste qu'un joueur occupe une fonction nommee.
  DELETE FROM public.titulaires_pnj
   WHERE id = v_pays || '_' || v_poste || '_' || coalesce(v_city, 'national');
  INSERT INTO public.postes_attribues (id, country, poste_id, city, titulaire, source)
  VALUES (v_pays || '_' || v_poste || '_' || coalesce(v_city,'national'),
          v_pays, v_poste, v_city, v_gagnant, 'tirage_au_sort_candidature')
  ON CONFLICT (id) DO UPDATE
     SET titulaire = EXCLUDED.titulaire, source = EXCLUDED.source, updated_at = now();
  UPDATE public.personnages_donnees
     SET poste = jsonb_build_object('id', v_poste, 'name', v_lib, 'city', v_city,
                   'nommeLe', (extract(epoch from clock_timestamp())*1000)::bigint)
   WHERE name = v_gagnant;
  PERFORM public.mail_systeme_envoyer('Système', v_gagnant, 'Nomination automatique — ' || v_lib,
    'L''autorité de nomination n''a pas tranché dans le délai de 48h imparti. Vous avez été désigné(e) par tirage au sort parmi les candidats éligibles au poste de ' || v_lib || '.');

  -- 5. LA SANCTION DU NOMINATEUR RESTE PASSIF. resources.pop, JAMAIS une colonne racine `pop` :
  --    ecrire au mauvais endroit ne serait jamais lu par le client.
  IF nullif(btrim(coalesce(p_autorite,'')),'') IS NOT NULL THEN
    SELECT resources INTO v_res FROM public.personnages_donnees
     WHERE name = btrim(p_autorite) FOR UPDATE;
    IF v_res IS NOT NULL THEN
      v_pop_avant := coalesce(CASE WHEN jsonb_typeof(v_res->'pop')='number'
                                   THEN (v_res->>'pop')::numeric END, 0);
      v_pop_apres := greatest(0, floor(v_pop_avant / 2));
      UPDATE public.personnages_donnees
         SET resources = jsonb_set(v_res, '{pop}', to_jsonb(v_pop_apres))
       WHERE name = btrim(p_autorite);
      v_sanction := true;
      PERFORM public.mail_systeme_envoyer('Système', btrim(p_autorite), 'Décision non prise — ' || v_lib,
        'Vous n''avez pas tranché entre les candidats au poste de ' || v_lib
        || ' dans le délai de 48h. ' || v_gagnant || ' a été nommé(e) par tirage au sort. '
        || 'Votre popularité a été divisée par deux (' || round(v_pop_avant)::text
        || ' → ' || v_pop_apres::text || ').');
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'gagnant', v_gagnant, 'sanction', v_sanction,
                            'pop_avant', v_pop_avant, 'pop_apres', v_pop_apres);
END; $function$;

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


  PERFORM pg_advisory_xact_lock(hashtext('candidature_unique|'||v_nom));
  IF public.candidature_autre_scrutin_actif(v_pays,v_nom,v_pays||'_'||v_cle) THEN
    RETURN jsonb_build_object('ok',false,'raison','candidature_simultanee_interdite');
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
  -- L'ESTAMPILLE EST REMISE A ZERO D'ABORD, ET C'EST LE POINT : ce que l'appelant a annonce dans
  -- cette colonne est jete AVANT toute lecture. Elle ne pourra valoir que ce que le cycle dit.
  NEW.cle_scrutin := NULL;

  SELECT data INTO v_data FROM public.cycles_electoraux
   WHERE id = NEW.country || '_' || NEW.poste_id || CASE WHEN NEW.city IS NOT NULL THEN '_' || NEW.city ELSE '' END;
  IF NOT FOUND THEN RETURN NEW; END IF;          -- cycle cree par le client juste avant la candidature
  BEGIN v_d := v_data::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NEW; END;
  IF COALESCE((v_d ->> 'resultatsTraites')::boolean, false)
     OR (jsonb_typeof(v_d -> 'dateDebutCampagne') = 'number' AND v_ms >= (v_d ->> 'dateDebutCampagne')::numeric) THEN
    RAISE EXCEPTION 'candidatures_closes' USING HINT = 'Les candidatures a ce scrutin sont closes (gel du lundi 00:01 de la derniere semaine du mandat).';
  END IF;
  -- ET LA CANDIDATURE EST ESTAMPILLEE DU SCRUTIN VISE, PAR LE SERVEUR (11 octobre 2026).
  -- Un cycle n'etant plus detruit entre deux scrutins, la table `candidatures` n'est plus
  -- distinguable par (pays, poste, ville) : sans cette colonne, les candidats d'un scrutin passe
  -- seraient reinjectes dans le suivant par syncCyclesDepuisSupabase. La valeur n'est pas celle
  -- que le client annonce : elle est RELUE sur le cycle, ici meme, dans la transaction.
  IF jsonb_typeof(v_d -> 'dateDebutCandidatures') = 'number' THEN
    NEW.cle_scrutin := (v_d ->> 'dateDebutCandidatures')::numeric::bigint;
  END IF;
  RETURN NEW;
END;
$function$;

-- candidatures_unicite_scrutin_actif() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.candidatures_unicite_scrutin_actif()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_cycle text;
BEGIN
 v_cycle:=NEW.country||'_'||NEW.poste_id||CASE WHEN NEW.city IS NOT NULL THEN '_'||NEW.city ELSE '' END;
 PERFORM pg_advisory_xact_lock(hashtext('candidature_unique|'||NEW.nom));
 IF public.candidature_autre_scrutin_actif(NEW.country,NEW.nom,v_cycle) THEN
  RAISE EXCEPTION 'candidature_simultanee_interdite' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;$function$;

-- communication_financement(text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.communication_financement(p_pays text, p_poste_id text, p_cout numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_info text; v_sien text; v_solde_info numeric := 0; v_solde_sien numeric := 0;
BEGIN
  IF coalesce(p_cout, 0) <= 0 THEN
    -- UNE COMMUNICATION GRATUITE NE POSE AUCUNE QUESTION DE CAISSE. La conference de presse et le
    -- dementi sont dans ce cas : seuls des PA.
    RETURN jsonb_build_object('ok', true, 'gratuit', true, 'caisse', NULL, 'cout', 0);
  END IF;

  v_info := public.salaire_caisse_de('min_info', p_pays, NULL);
  v_sien := public.salaire_caisse_de(p_poste_id, p_pays, NULL);

  SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde_info
    FROM public.caisses_batiments WHERE id = v_info;
  SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde_sien
    FROM public.caisses_batiments WHERE id = v_sien;

  IF v_info IS NOT NULL AND coalesce(v_solde_info, 0) >= p_cout THEN
    RETURN jsonb_build_object('ok', true, 'gratuit', false, 'caisse', v_info,
                              'defaut', true, 'cout', p_cout, 'solde', v_solde_info);
  END IF;

  -- L'INFORMATION NE COUVRE PAS. On NOMME la caisse de repli et son solde, et on ne debite rien :
  -- c'est au joueur de dire s'il accepte de payer sur sa propre caisse institutionnelle.
  RETURN jsonb_build_object(
    'ok', false, 'gratuit', false, 'raison', 'budget_information_insuffisant',
    'cout', p_cout,
    'caisse_information', v_info, 'solde_information', coalesce(v_solde_info, 0),
    'caisse_proposee', v_sien, 'solde_proposee', coalesce(v_solde_sien, 0),
    -- SUFFISANTE OU PAS : le joueur a droit a l'information avant de repondre, sinon on lui
    -- demande d'accepter une depense impossible.
    'proposee_suffisante', (v_sien IS NOT NULL AND coalesce(v_solde_sien, 0) >= p_cout));
END;
$function$;

-- communication_officielle_publier(text,text,text,integer,integer,text,text,jsonb,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.communication_officielle_publier(p_building_id text, p_room_id text, p_fn text, p_pa integer, p_cost integer, p_titre text, p_contenu text, p_blocs jsonb, p_accepte_sa_caisse boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; a record; sa record; fin jsonb;
  v_topic text; v_post text; v_titre text; v_contenu text; v_temps text;
  v_conf text; v_chron text; v_caisse text; v_data jsonb; v_solde numeric;
  v_pa integer; v_poste_libelle text; v_ouverte text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  v_titre   := nullif(btrim(coalesce(p_titre, '')), '');
  v_contenu := nullif(btrim(coalesce(p_contenu, '')), '');
  IF v_titre IS NULL OR v_contenu IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'titre_ou_contenu_vide');
  END IF;

  SELECT * INTO sa FROM public.communications_salles
   WHERE building_id = p_building_id AND room_id = p_room_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'salle_sans_tribune');
  END IF;

  SELECT * INTO a FROM public.acteur_poste_courant() LIMIT 1;
  IF NOT FOUND OR a.poste_id IS NULL OR NOT (a.poste_id = ANY (sa.postes)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_admis_dans_cette_tribune',
                              'tribune', sa.libelle, 'postes_admis', sa.postes);
  END IF;

  -- LA TRIBUNE DECLARE CE QU'ON PEUT Y PRONONCER. Sans ce controle, tout ordre declare au miroir
  -- aurait pu servir de conference de presse.
  IF NOT (p_fn = ANY (sa.ordres)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_etranger_a_la_tribune',
                              'ordre', p_fn, 'ordres_admis', sa.ordres);
  END IF;

  -- LE MIROIR DES COUTS FAIT AUTORITE SUR LE COUPLE ANNONCE.
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts o
                  WHERE o.fn = p_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                              'fn', p_fn, 'pa', p_pa, 'cost', p_cost);
  END IF;

  -- UNE SEULE CONFERENCE OUVERTE A LA FOIS. On le dit AVANT de debiter, et on rend l'identifiant
  -- de celle qui est deja ouverte : le navigateur rouvre sa pop-up au lieu d'en creer une seconde.
  SELECT id INTO v_ouverte FROM public.conferences_presse
   WHERE pays = a.pays AND auteur = v_moi AND statut = 'ouverte' LIMIT 1;
  IF v_ouverte IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_deja_ouverte',
                              'conference', v_ouverte);
  END IF;

  -- LE FINANCEMENT, DECIDE AVANT TOUT DEBIT.
  fin := public.communication_financement(a.pays, a.poste_id, coalesce(p_cost, 0));
  IF coalesce((fin->>'gratuit')::boolean, false) THEN
    v_caisse := NULL;
  ELSIF coalesce((fin->>'ok')::boolean, false) THEN
    v_caisse := fin->>'caisse';
  ELSE
    -- L'INFORMATION NE COUVRE PAS. Sans accord explicite, on rend la main SANS RIEN AVOIR DEBITE.
    IF p_accepte_sa_caisse IS NOT TRUE THEN
      RETURN fin || jsonb_build_object('ok', false, 'accord_requis', true);
    END IF;
    IF coalesce((fin->>'proposee_suffisante')::boolean, false) IS NOT TRUE THEN
      RETURN fin || jsonb_build_object('ok', false, 'accord_requis', false,
                                       'raison', 'les_deux_caisses_insuffisantes');
    END IF;
    v_caisse := fin->>'caisse_proposee';
  END IF;

  -- LES PA SONT VERROUILLES ET VERIFIES AVANT LE MOINDRE DEBIT. Le verrou est pris ici et tenu
  -- jusqu'au bout : entre la verification et le prelevement, personne ne peut depenser ces PA
  -- ailleurs. Et le refus est STRUCTURE -- un joueur a court de PA recoit une raison, pas une
  -- erreur de transport.
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF v_pa < coalesce(p_pa, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'pa_reel', v_pa, 'requis', coalesce(p_pa, 0));
  END IF;

  -- LE DEBIT DE LA CAISSE, SOUS VERROU ET EN ENTIER. Tout ou rien : jamais de financement mixte,
  -- jamais de moitie.
  IF v_caisse IS NOT NULL THEN
    SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number'
                    THEN (v_data ->> 'solde')::numeric ELSE 0 END;
    IF v_solde < p_cost THEN
      -- Le solde a bouge entre la lecture et le verrou : on refuse, et rien n'est ecrit.
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante_au_verrou',
                                'caisse', v_caisse, 'solde', v_solde, 'requis', p_cost);
    END IF;
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - p_cost),
           updated_at = now()
     WHERE id = v_caisse;
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, v_caisse, -p_cost, 'communication_officielle:' || p_fn, true, NULL);
  END IF;

  -- LE PRELEVEMENT DES PA, APRES le debit financier : un echec de caisse ne doit jamais amputer
  -- les PA. La suffisance a deja ete verifiee sous le meme verrou, ce debit ne peut pas echouer.
  UPDATE public.personnages_donnees SET pa = v_pa - coalesce(p_pa, 0) WHERE name = v_moi;

  v_temps := to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI');
  v_topic := 'topic-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_post  := 'post-'  || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_conf  := 'conf-'  || (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_chron := 'chronique-conference_presse-' || (extract(epoch from clock_timestamp()) * 1000)::bigint;

  SELECT poste->>'name' INTO v_poste_libelle FROM public.personnages_donnees WHERE name = v_moi;

  INSERT INTO public.forum_topics
    (id, forum_id, title, author, country, time, views, replies,
     last_post_author, last_post_time, author_is_org, author_secret)
  VALUES (v_topic, sa.forum_id, v_titre, v_moi, a.pays, v_temps, 1, 0, v_moi, v_temps, false, false);

  INSERT INTO public.forum_posts
    (id, topic_id, author, content, time, author_is_org, author_secret, content_blocks, content_layout)
  VALUES (v_post, v_topic, v_moi, v_contenu, v_temps, false, false,
          CASE WHEN jsonb_typeof(p_blocs) = 'array' THEN p_blocs ELSE '[]'::jsonb END, NULL);

  -- LA CONFERENCE S'OUVRE. `communication` garde le texte DECLARE, verbatim.
  INSERT INTO public.conferences_presse
    (id, pays, building_id, room_id, auteur, poste_id, poste_libelle, ordre,
     titre, communication, statut, cout_fr, caisse_payeuse, chronique_id)
  VALUES (v_conf, a.pays, p_building_id, p_room_id, v_moi, a.poste_id, v_poste_libelle, p_fn,
          v_titre, v_contenu, 'ouverte', coalesce(p_cost, 0), v_caisse, v_chron);

  -- LA TRACE PUBLIQUE. Une PHRASE factuelle, dans la couche publique du jeu -- et ECRITE PAR LE
  -- SERVEUR, dans la meme transaction que la communication. Elle dit QU'UNE conference a eu lieu,
  -- et rien de son contenu : ni resume, ni jugement, ni transcription.
  INSERT INTO public.chronique_nationale
    (id, country, type, city, personnages, libelle, data, source_ref)
  VALUES (v_chron, a.pays, 'conference_presse', NULL,
          jsonb_build_array(v_moi),
          coalesce(v_poste_libelle, v_moi) || ' a tenu une conference de presse : « ' || v_titre || ' ».',
          jsonb_build_object('conference', v_conf, 'ordre', p_fn, 'tribune', sa.libelle,
                             'topic', v_topic),
          v_conf);

  -- Indice Diplomatique (25/10/2026) : la propagande d'Etat coute 5 points au pays.
  IF p_fn = 'propagande_etat' THEN
    PERFORM public.indice_diplomatique_varier_interne(a.pays, -5, 'propagande_etat', v_moi);
  END IF;

  RETURN jsonb_build_object('ok', true, 'topic', v_topic, 'post', v_post,
                            'conference', v_conf, 'chronique', v_chron,
                            'auteur', v_moi, 'poste', a.poste_id,
                            'poste_libelle', v_poste_libelle,
                            'tribune', sa.libelle, 'temps', v_temps,
                            'cout', coalesce(p_cost, 0), 'caisse_payeuse', v_caisse,
                            'pa_preleves', coalesce(p_pa, 0), 'pa', v_pa - coalesce(p_pa, 0));
END;
$function$;

-- communication_tribune(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.communication_tribune(p_building_id text, p_room_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE sa record; a record;
BEGIN
  SELECT * INTO sa FROM public.communications_salles
   WHERE building_id = p_building_id AND room_id = p_room_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'tribune', false);
  END IF;
  SELECT * INTO a FROM public.acteur_poste_courant() LIMIT 1;
  RETURN jsonb_build_object('ok', true, 'tribune', true, 'libelle', sa.libelle,
                            'postes_admis', sa.postes,
                            'je_peux', coalesce(a.poste_id = ANY (sa.postes), false));
END;
$function$;

-- conference_clore(text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.conference_clore(p_conference_id text, p_interrompue boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; c record; v_statut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL AND NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO c FROM public.conferences_presse WHERE id = p_conference_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_inconnue');
  END IF;
  IF NOT public.est_appel_serveur() AND c.auteur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_conference');
  END IF;
  IF c.statut <> 'ouverte' THEN
    -- IDEMPOTENT : refermer une conference close n'est pas une erreur, et un double clic sur la
    -- croix de la pop-up ne doit pas lever.
    RETURN jsonb_build_object('ok', true, 'deja_close', true, 'statut', c.statut);
  END IF;

  v_statut := CASE WHEN p_interrompue IS TRUE THEN 'interrompue' ELSE 'terminee' END;
  UPDATE public.conferences_presse
     SET statut = v_statut, close_le = now() WHERE id = p_conference_id;

  RETURN jsonb_build_object('ok', true, 'statut', v_statut,
    'echanges', (SELECT count(*) FROM public.conferences_presse_echanges
                  WHERE conference_id = p_conference_id));
END;
$function$;

-- conference_lire(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.conference_lire(p_conference_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; c record; v_est_presse boolean := false;
BEGIN
  SELECT * INTO c FROM public.conferences_presse WHERE id = p_conference_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_inconnue');
  END IF;

  v_moi := public.mon_personnage();
  IF NOT public.est_appel_serveur() THEN
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT EXISTS (SELECT 1 FROM public.presse_membres m
                     JOIN public.groupes_presse g ON g.id = m.groupe_id
                    WHERE m.personnage = v_moi AND g.pays = c.pays) INTO v_est_presse;
    IF c.auteur IS DISTINCT FROM v_moi AND NOT v_est_presse THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'lecture_reservee_a_l_auteur_et_a_la_presse');
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true,
    'conference', jsonb_build_object(
      'id', c.id, 'pays', c.pays, 'auteur', c.auteur,
      'poste', c.poste_id, 'fonction', c.poste_libelle,
      'ordre', c.ordre, 'titre', c.titre, 'communication', c.communication,
      'statut', c.statut, 'ouverte_le', c.ouverte_le, 'close_le', c.close_le),
    'echanges', (SELECT coalesce(jsonb_agg(jsonb_build_object(
          'rang', e.rang, 'question', e.question, 'reponse', e.reponse,
          'refus', e.refus, 'pose_le', e.pose_le, 'repondu_le', e.repondu_le) ORDER BY e.rang), '[]'::jsonb)
       FROM public.conferences_presse_echanges e WHERE e.conference_id = c.id));
END;
$function$;

-- conference_matiere(integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.conference_matiere(p_limite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_lim integer := least(greatest(coalesce(p_limite, 10), 1), 30);
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- LE DROIT EXISTANT, REUTILISE : etre membre d'un groupe de presse. Un ministre n'a pas acces a
  -- la matiere des conferences des autres, et un citoyen non plus.
  SELECT g.pays INTO v_pays FROM public.presse_membres m
    JOIN public.groupes_presse g ON g.id = m.groupe_id
   WHERE m.personnage = v_moi LIMIT 1;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_a_la_redaction');
  END IF;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays,
    'conferences', (SELECT coalesce(jsonb_agg(x ORDER BY (x->>'ouverte_le') DESC), '[]'::jsonb) FROM (
      SELECT jsonb_build_object(
               'id', c.id, 'auteur', c.auteur, 'fonction', c.poste_libelle, 'poste', c.poste_id,
               'ordre', c.ordre, 'titre', c.titre, 'communication', c.communication,
               'statut', c.statut, 'ouverte_le', c.ouverte_le, 'close_le', c.close_le,
               'echanges', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                     'rang', e.rang, 'question', e.question,
                     'reponse', e.reponse, 'refus', e.refus) ORDER BY e.rang), '[]'::jsonb)
                  FROM public.conferences_presse_echanges e WHERE e.conference_id = c.id)) AS x
        FROM public.conferences_presse c
       WHERE c.pays = v_pays AND c.statut <> 'ouverte'
       ORDER BY c.ouverte_le DESC LIMIT v_lim) z));
END;
$function$;

-- conference_question_poser(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.conference_question_poser(p_conference_id text, p_question text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c record; v_q text; v_rang integer; v_reste integer;
BEGIN
  v_q := nullif(btrim(coalesce(p_question, '')), '');
  IF v_q IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'question_vide');
  END IF;

  SELECT * INTO c FROM public.conferences_presse WHERE id = p_conference_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_inconnue');
  END IF;
  IF c.statut <> 'ouverte' THEN
    -- LA POP-UP A ETE FERMEE : plus aucune question ne s'ajoute, et c'est exactement l'arbitrage.
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_close', 'statut', c.statut);
  END IF;

  -- ON NE POSE PAS UNE QUESTION TANT QUE LA PRECEDENTE N'A PAS DE SUITE. Sans cela, un appel
  -- repete empilerait des questions sans reponse, et la transcription perdrait son sens.
  SELECT count(*) INTO v_reste FROM public.conferences_presse_echanges
   WHERE conference_id = p_conference_id AND reponse IS NULL AND NOT refus;
  IF v_reste > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'question_en_attente_de_reponse');
  END IF;

  SELECT coalesce(max(rang), 0) + 1 INTO v_rang
    FROM public.conferences_presse_echanges WHERE conference_id = p_conference_id;
  IF v_rang > 5 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_de_questions_atteint', 'maximum', 5);
  END IF;

  INSERT INTO public.conferences_presse_echanges (conference_id, rang, question)
  VALUES (p_conference_id, v_rang, left(v_q, 600));

  RETURN jsonb_build_object('ok', true, 'rang', v_rang, 'question', left(v_q, 600),
                            'reste_possible', 5 - v_rang);
END;
$function$;

-- conference_repondre(text,integer,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.conference_repondre(p_conference_id text, p_rang integer, p_reponse text, p_refus boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; c record; e record; v_r text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT * INTO c FROM public.conferences_presse WHERE id = p_conference_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_inconnue');
  END IF;
  -- SEUL CELUI QUI A PARLE REPOND. Un autre joueur ne met pas de mots dans sa bouche.
  IF c.auteur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_conference');
  END IF;
  IF c.statut <> 'ouverte' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conference_close', 'statut', c.statut);
  END IF;

  SELECT * INTO e FROM public.conferences_presse_echanges
   WHERE conference_id = p_conference_id AND rang = p_rang FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'question_inconnue');
  END IF;
  IF e.reponse IS NOT NULL OR e.refus THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_repondu');
  END IF;

  IF p_refus IS TRUE THEN
    -- UN REFUS NE TERMINE PAS LA CONFERENCE. La porte ne touche pas au statut : les journalistes
    -- peuvent enchainer, et c'est exactement l'arbitrage.
    UPDATE public.conferences_presse_echanges
       SET refus = true, repondu_le = now()
     WHERE conference_id = p_conference_id AND rang = p_rang;
    RETURN jsonb_build_object('ok', true, 'rang', p_rang, 'refus', true);
  END IF;

  v_r := nullif(btrim(coalesce(p_reponse, '')), '');
  IF v_r IS NULL THEN
    -- NI REPONSE NI REFUS N'EST PAS UN ETAT : il faut choisir. Un champ vide envoye par megarde
    -- ne doit pas devenir un refus implicite.
    RETURN jsonb_build_object('ok', false, 'raison', 'reponse_vide_sans_refus');
  END IF;

  UPDATE public.conferences_presse_echanges
     SET reponse = left(v_r, 4000), repondu_le = now()
   WHERE conference_id = p_conference_id AND rang = p_rang;

  RETURN jsonb_build_object('ok', true, 'rang', p_rang, 'refus', false);
END;
$function$;

-- conference_soutenir(text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.conference_soutenir(p_cycle text, p_candidat text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; v_cycle text; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_paie jsonb; r jsonb; v_d jsonb; v_conv integer := 0; v_base text := replace(gen_random_uuid()::text, '-', '');
BEGIN
  SELECT * INTO a FROM public.personnages_donnees WHERE name = public.mon_personnage() FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF a.current_building IS DISTINCT FROM 'universite' OR a.current_room IS DISTINCT FROM 'amphi' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF coalesce(btrim(p_cycle), '') = '' OR coalesce(btrim(p_candidat), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v_cycle := a.country || '_' || p_cycle;
  SELECT data::jsonb INTO v_d FROM public.cycles_electoraux WHERE id = v_cycle;
  IF v_d IS NULL OR jsonb_typeof(v_d) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'); END IF;
  IF coalesce((v_d ->> 'resultatsTraites')::boolean, false) OR jsonb_typeof(v_d -> 'dateResultats') <> 'number'
     OR floor(extract(epoch FROM now()) * 1000) >= (v_d ->> 'dateResultats')::numeric OR jsonb_typeof(v_d -> 'dateVote') <> 'number' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_clos'); END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_d -> 'candidats', '[]'::jsonb)) c WHERE c ->> 'nom' = p_candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_hors_scrutin'); END IF;
  IF EXISTS (SELECT 1 FROM public.conferences_jours WHERE acteur = a.name AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_fait_aujourdhui'); END IF;
  IF EXISTS (SELECT 1 FROM public.elections_tracts_pnj WHERE cycle_id = v_cycle AND canal = 'conference' AND candidat = p_candidat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_soutenu'); END IF;
  v_paie := public.payer_ordre(a.name, 'donner_conf', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.conferences_jours VALUES (a.name, v_jour);
  PERFORM set_config('rp.conference_interne', 'on', true);
  FOR i IN 0..2 LOOP
    r := public.elections_voix_pnj_enregistrer('conf-' || v_base || '-' || i, a.name, v_cycle, p_candidat,
           'Un auditeur de la conférence', 'conference', 'conference:' || a.name || ':' || p_candidat || ':' || i);
    IF coalesce((r ->> 'ok')::boolean, false) THEN v_conv := v_conv + 1; END IF;
  END LOOP;
  PERFORM set_config('rp.conference_interne', '', true);
  RETURN jsonb_build_object('ok', true, 'convertis', v_conv, 'tour', r -> 'tour') || jsonb_build_object('paie', v_paie);
END; $function$;

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
  v_sortie   jsonb;
BEGIN
  IF p_d IS NULL OR jsonb_typeof(p_d) <> 'object' OR jsonb_typeof(p_d -> 'dateVote') <> 'number' THEN RETURN p_d; END IF;
  IF COALESCE((p_d ->> 'resultatsTraites')::boolean, false) OR COALESCE(p_d ->> 'phase', '') = 'vacant' THEN RETURN p_d; END IF;
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
  v_sortie := p_d || jsonb_build_object('dateDebutCampagne', v_cloture, 'dateVote', v_vote, 'dateResultats', v_res,
                                        'realigneDimancheTs', v_ms);
  -- LA FIN DU MANDAT SUIT LA PROCLAMATION, TOUJOURS. Elle n'est posee que si le blob en portait
  -- une : un cycle sans titulaire n'a pas de mandat a dater, et lui en inventer un serait faux.
  IF jsonb_typeof(p_d -> 'dateFinMandat') = 'number' THEN
    v_sortie := v_sortie || jsonb_build_object('dateFinMandat', v_res);
  END IF;
  RETURN v_sortie;
END;
$function$;

-- cycle_electoral_frais_interne(text,text,timestamp with time zone) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cycle_electoral_frais_interne(p_poste text, p_city text, p_now timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour date := (p_now AT TIME ZONE 'Europe/Paris')::date; v_lundi date; v_camp timestamptz;
BEGIN
  v_lundi := date_trunc('week', v_jour)::date + 7;
  v_camp := (v_lundi + time '00:01') AT TIME ZONE 'Europe/Paris';
  IF v_camp - p_now < interval '6 days' THEN v_lundi := v_lundi + 7; END IF;
  RETURN jsonb_build_object(
    'posteId', p_poste,
    'city', CASE WHEN p_poste IN ('maire', 'depute') THEN p_city END,
    'phase', 'candidatures',
    'dateDebutCandidatures', (extract(epoch FROM p_now) * 1000)::bigint,
    'dateDebutCampagne', (extract(epoch FROM (v_lundi + time '00:01') AT TIME ZONE 'Europe/Paris') * 1000)::bigint,
    'dateVote', (extract(epoch FROM (v_lundi + 6 + time '00:01') AT TIME ZONE 'Europe/Paris') * 1000)::bigint,
    'dateResultats', (extract(epoch FROM (v_lundi + 7 + time '00:00') AT TIME ZONE 'Europe/Paris') * 1000)::bigint,
    'candidats', '[]'::jsonb, 'votes', '{}'::jsonb, 'votesPNJ', '{}'::jsonb,
    'tour', 1, 'eluId', NULL, 'resultatsTraites', false);
END; $function$;

-- cycle_electoral_initialiser(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.cycle_electoral_initialiser(p_poste text, p_city text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_city text; v_id text; v_data text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_poste NOT IN ('president', 'chef_syndicat', 'maire', 'depute') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_electif'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  v_city := CASE WHEN p_poste IN ('maire', 'depute') THEN nullif(p_city, '') END;
  IF p_poste IN ('maire', 'depute') AND (v_city IS NULL OR v_city NOT IN ('capitale', 'ville_a', 'ville_b')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ville_invalide'); END IF;
  v_id := v_pays || '_' || p_poste || coalesce('_' || v_city, '');
  INSERT INTO public.cycles_electoraux (id, country, poste_id, city, data, updated_at)
    VALUES (v_id, v_pays, p_poste, v_city, public.cycle_electoral_frais_interne(p_poste, v_city, now())::text, now())
    ON CONFLICT (id) DO NOTHING;
  SELECT data INTO v_data FROM public.cycles_electoraux WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'cycle', v_data::jsonb);
END; $function$;

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

-- election_contester(text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.election_contester(p_poste text, p_city text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_int numeric; v_city text; v_row record; v_cycle jsonb; v_scrutin jsonb;
  v_paie jsonb; v_taux integer; v_roll integer; v_f record; v_sanction jsonb; v_recompte jsonb;
  v_ancien jsonb; v_nouveau jsonb; v_change boolean := false;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, coalesce(CASE WHEN jsonb_typeof(stats -> 'INT') = 'number' THEN (stats ->> 'INT')::numeric END, 8)
    INTO v_pays, v_int FROM public.personnages_donnees WHERE name = v_moi;
  v_city := CASE WHEN p_poste IN ('maire', 'depute') THEN nullif(p_city, '') END;
  SELECT * INTO v_row FROM public.cycles_electoraux
   WHERE country = v_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM v_city FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_introuvable'); END IF;
  v_cycle := v_row.data::jsonb;
  IF (v_cycle ->> 'dernierResultatTs') IS NULL
     OR (extract(epoch FROM now()) * 1000) - (v_cycle ->> 'dernierResultatTs')::numeric NOT BETWEEN 0 AND 86400000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_delai'); END IF;
  v_scrutin := v_cycle -> 'dernierScrutin';
  IF jsonb_typeof(v_scrutin) <> 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'scrutin_non_consultable'); END IF;
  v_paie := public.payer_ordre(v_moi, 'contester_resultats', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := greatest(5, least(95, round(60 + 5 * (v_int - 13))::integer));
  v_roll := floor(random() * 100)::integer + 1;
  IF v_roll > v_taux THEN
    RETURN jsonb_build_object('ok', true, 'issue', 'rejetee', 'jet', v_roll, 'taux', v_taux) || jsonb_build_object('paie', v_paie);
  END IF;
  SELECT * INTO v_f FROM public.fraudes_electorales
   WHERE country = v_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM v_city
     AND cycle_debut = (v_scrutin ->> 'debut')::bigint AND etat = 'non_revelee'
   ORDER BY random() LIMIT 1;
  IF NOT FOUND OR random() * 100 >= coalesce(v_f.detectabilite_pct, 0) THEN
    RETURN jsonb_build_object('ok', true, 'issue', 'aucune_fraude') || jsonb_build_object('paie', v_paie);
  END IF;
  v_sanction := public.fraude_electorale_sanctionner(v_f.id, v_city);
  IF coalesce((v_sanction ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', true, 'issue', 'sans_suite', 'raison', v_sanction ->> 'raison') || jsonb_build_object('paie', v_paie);
  END IF;
  v_recompte := public.election_recompter_interne(v_row.id, v_pays, p_poste, v_city, v_scrutin);
  IF p_poste = 'depute' THEN
    v_ancien := coalesce(v_cycle -> 'elus', '[]'::jsonb);
    v_nouveau := v_recompte -> 'elus';
    IF jsonb_typeof(v_nouveau) = 'array' AND jsonb_array_length(v_nouveau) = 3
       AND (SELECT array_agg(x ORDER BY x) FROM jsonb_array_elements_text(v_nouveau) x)
           IS DISTINCT FROM (SELECT array_agg(x ORDER BY x) FROM jsonb_array_elements_text(v_ancien) x) THEN
      v_cycle := jsonb_set(v_cycle, '{elus}', v_nouveau); v_change := true;
    END IF;
  ELSE
    v_ancien := v_cycle -> 'eluId';
    v_nouveau := v_recompte -> 'elu';
    IF jsonb_typeof(v_nouveau) = 'string' AND v_nouveau IS DISTINCT FROM v_ancien THEN
      v_cycle := jsonb_set(v_cycle, '{eluId}', v_nouveau); v_change := true;
    END IF;
  END IF;
  IF v_change THEN
    UPDATE public.cycles_electoraux SET data = v_cycle::text, updated_at = now() WHERE id = v_row.id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'issue', 'fraude_revelee', 'fraudeur', v_sanction ->> 'fraudeur',
    'type', v_sanction ->> 'type', 'recompense', v_sanction -> 'recompense', 'arg', v_sanction -> 'arg_contestataire',
    'issue_changee', v_change, 'ancienne_issue', v_ancien, 'nouvelle_issue', CASE WHEN v_change THEN v_nouveau END)
    || jsonb_build_object('paie', v_paie);
END; $function$;

-- election_recompter_interne(text,text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.election_recompter_interne(p_cycle_id text, p_pays text, p_poste text, p_city text, p_scrutin jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_scores jsonb := '{}'::jsonb; v_blancs integer := 0; v_total integer; v_nb integer; v_nom text; r record;
  v_premier text; v_premier_voix integer;
BEGIN
  SELECT count(*) INTO v_nb FROM jsonb_array_elements(coalesce(p_scrutin -> 'candidats', '[]'::jsonb));
  IF v_nb = 0 THEN RETURN NULL; END IF;
  SELECT jsonb_object_agg(c ->> 'nom', 0) INTO v_scores FROM jsonb_array_elements(p_scrutin -> 'candidats') c;
  FOR v_nom IN SELECT value FROM jsonb_each_text(coalesce(p_scrutin -> 'votes', '{}'::jsonb))
               UNION ALL SELECT value FROM jsonb_each_text(coalesce(p_scrutin -> 'votesPNJ', '{}'::jsonb)) LOOP
    IF v_nom = 'BLANC' THEN v_blancs := v_blancs + 1;
    ELSIF v_scores ? v_nom THEN v_scores := jsonb_set(v_scores, ARRAY[v_nom], to_jsonb((v_scores ->> v_nom)::int + 1)); END IF;
  END LOOP;
  FOR r IN SELECT candidat, sum(effet)::int AS e FROM public.elections_tracts_pnj
            WHERE cycle_id = p_cycle_id AND tour = coalesce((p_scrutin ->> 'dateVote')::bigint, 0) GROUP BY candidat LOOP
    IF v_scores ? r.candidat THEN v_scores := jsonb_set(v_scores, ARRAY[r.candidat], to_jsonb(greatest(0, (v_scores ->> r.candidat)::int + r.e))); END IF;
  END LOOP;
  FOR r IN SELECT candidat, delta_voix FROM public.fraudes_electorales
            WHERE country = p_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city
              AND cycle_debut = (p_scrutin ->> 'debut')::bigint AND etat = 'non_revelee' LOOP
    IF v_scores ? r.candidat THEN v_scores := jsonb_set(v_scores, ARRAY[r.candidat], to_jsonb(greatest(0, (v_scores ->> r.candidat)::int + r.delta_voix))); END IF;
  END LOOP;
  SELECT coalesce(sum(value::int), 0) + v_blancs INTO v_total FROM jsonb_each_text(v_scores);
  IF v_total = 0 OR v_blancs > v_total / 2.0 THEN RETURN jsonb_build_object('elu', NULL, 'elus', '[]'::jsonb); END IF;
  IF p_poste = 'depute' THEN
    RETURN jsonb_build_object('elus', (SELECT jsonb_agg(nom) FROM (
      SELECT s.key AS nom FROM jsonb_each_text(v_scores) s
        LEFT JOIN LATERAL (SELECT nullif(c ->> 'dateInscription', '')::numeric AS d
                             FROM jsonb_array_elements(p_scrutin -> 'candidats') c WHERE c ->> 'nom' = s.key LIMIT 1) i ON true
       ORDER BY s.value::int DESC, coalesce(i.d, 'Infinity'::numeric), s.key LIMIT 3) t));
  END IF;
  SELECT key, value::int INTO v_premier, v_premier_voix FROM jsonb_each_text(v_scores) ORDER BY value::int DESC LIMIT 1;
  IF v_nb = 1 THEN
    RETURN jsonb_build_object('elu', CASE WHEN v_premier_voix >= v_blancs THEN v_premier END);
  END IF;
  RETURN jsonb_build_object('elu', CASE WHEN v_premier_voix > v_total / 2.0 THEN v_premier END);
END; $function$;

-- election_resultats_consigner(text,jsonb,jsonb,jsonb,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.election_resultats_consigner(p_cycle_id text, p_data jsonb, p_evenement jsonb DEFAULT NULL::jsonb, p_chronique jsonb DEFAULT NULL::jsonb, p_si_date_resultats numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_n integer; v_ev integer := 0; v_ch integer := 0;
BEGIN
  IF coalesce(btrim(p_cycle_id),'') = '' OR p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'election_resultats_consigner : cycle et blob sont obligatoires';
  END IF;
  -- COMPARE-AND-SWAP DANS LE FILTRE, PAS DANS LE CORPS : deux passes simultanees ne peuvent pas
  -- proclamer le meme scrutin, et un rejeu lit zero ligne. Un cycle inconnu donne aussi zero
  -- ligne : aucune annonce ne peut partir sans son cycle.
  IF p_si_date_resultats IS NULL THEN
    UPDATE public.cycles_electoraux
       SET data = p_data::text, updated_at = now()
     WHERE id = p_cycle_id
       AND coalesce((data::jsonb ->> 'resultatsTraites')::boolean, false) = false;
  ELSE
    UPDATE public.cycles_electoraux
       SET data = p_data::text, updated_at = now()
     WHERE id = p_cycle_id
       AND jsonb_typeof(data::jsonb -> 'dateResultats') = 'number'
       AND (data::jsonb ->> 'dateResultats')::numeric = p_si_date_resultats;
  END IF;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_traite');
  END IF;

  IF jsonb_typeof(p_evenement) = 'object' THEN
    INSERT INTO public.evenements_globaux (country, city, texte, jour)
    VALUES (p_evenement ->> 'country', p_evenement ->> 'city', p_evenement ->> 'texte', NULL);
    v_ev := 1;
  END IF;
  -- L'identifiant de la chronique vient de l'appelant et est DEJA deterministe
  -- (election-<cycle>-<dateResultats>) : le ON CONFLICT est une seconde barriere, pas la premiere.
  IF jsonb_typeof(p_chronique) = 'object' THEN
    INSERT INTO public.chronique_nationale (id, country, city, type, personnages, libelle, data, source_ref)
    VALUES (p_chronique ->> 'id', p_chronique ->> 'country', p_chronique ->> 'city',
            p_chronique ->> 'type',
            CASE WHEN jsonb_typeof(p_chronique -> 'personnages') = 'array'
                 THEN p_chronique -> 'personnages' ELSE '[]'::jsonb END,
            p_chronique ->> 'libelle', p_chronique -> 'data', p_chronique ->> 'source_ref')
    ON CONFLICT (id) DO NOTHING;
    GET DIAGNOSTICS v_ch = ROW_COUNT;
  END IF;
  RETURN jsonb_build_object('ok', true, 'cycle', p_cycle_id,
                            'evenement_pose', v_ev = 1, 'chronique_posee', v_ch = 1);
END; $function$;

-- election_voter(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.election_voter(p_pays text, p_poste_id text, p_ville text, p_candidat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi      text;
  v_pays     text := lower(btrim(coalesce(p_pays, '')));
  v_poste    text := btrim(coalesce(p_poste_id, ''));
  v_cand     text := btrim(coalesce(p_candidat, ''));
  v_local    boolean;
  v_ville    text;
  v_cle      text;
  v_id_cycle text;
  v_brut     text;
  v_cycle    jsonb;
  v_ms       numeric := floor(extract(epoch from now()) * 1000);
  v_domicile text;
  v_n        integer;
BEGIN
  -- L'IDENTITE N'EST PAS UN PARAMETRE. L'appelant ne dit pas qui vote : le serveur le lit.
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF v_pays = '' OR v_poste = '' OR v_cand = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- LA LOCALITE DU POSTE VIENT DU REFERENTIEL, pas du navigateur :
  -- postes_electifs_regles.niveau = 'ville' est exactement la regle de posteEstLocal(). La cle
  -- du scrutin et l'identifiant du bulletin s'en deduisent, comme getCleCycle() cote client.
  SELECT (niveau = 'ville') INTO v_local FROM public.postes_electifs_regles WHERE poste_id = v_poste;
  IF v_local IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;
  v_ville    := CASE WHEN v_local AND coalesce(btrim(p_ville), '') <> '' THEN btrim(p_ville) END;
  v_cle      := CASE WHEN v_ville IS NOT NULL THEN v_poste || '_' || v_ville ELSE v_poste END;
  v_id_cycle := v_pays || '_' || v_cle;

  -- DOMICILE : meme regle que le client -- domicile.country, a defaut le pays du personnage.
  SELECT coalesce(nullif(d.domicile ->> 'country', ''), d.country) INTO v_domicile
    FROM public.personnages_donnees d WHERE d.name = v_moi;
  IF v_domicile IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'non_domicilie');
  END IF;

  -- VERROU DU CYCLE. C'est lui qui serialise deux electeurs simultanes : le blob etant
  -- relu-modifie-reecrit, le second ecrasait sinon le bulletin du premier.
  SELECT data INTO v_brut FROM public.cycles_electoraux WHERE id = v_id_cycle FOR UPDATE;
  IF NOT FOUND OR v_brut IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_absent');
  END IF;
  BEGIN
    v_cycle := v_brut::jsonb;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_illisible');
  END;
  IF jsonb_typeof(v_cycle) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_illisible');
  END IF;

  -- LA FENETRE DE VOTE, ET ELLE SEULE (11 octobre 2026). Le retour anticipe « un mandat est en
  -- cours, donc le vote est ferme » est RETIRE : depuis l'arbitrage du calendrier commun, on vote
  -- toujours pendant le mandat du sortant -- le dernier dimanche de ce mandat. Un titulaire en
  -- fonction n'est plus un motif de refus, c'est l'etat normal d'un scrutin de succession.
  -- Les bornes n'ont pas change : dimanche 00:01 -> lundi 00:00, heure de Paris, en millisecondes
  -- JavaScript. `resultatsTraites` ferme un scrutin deja depouille.
  IF COALESCE((v_cycle ->> 'resultatsTraites')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme', 'phase', 'depouille');
  END IF;
  IF jsonb_typeof(v_cycle -> 'dateVote') <> 'number'
     OR jsonb_typeof(v_cycle -> 'dateResultats') <> 'number' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_sans_calendrier');
  END IF;
  IF v_ms < (v_cycle ->> 'dateVote')::numeric
     OR v_ms >= (v_cycle ->> 'dateResultats')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme');
  END IF;

  -- LE CANDIDAT DOIT EXISTER, ou etre le vote blanc -- qui n'est jamais un candidat fictif
  -- ajoute a la liste, mais un choix reel compte a part par le depouillement.
  IF v_cand <> 'BLANC' AND NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements(
         CASE WHEN jsonb_typeof(v_cycle -> 'candidats') = 'array' THEN v_cycle -> 'candidats' ELSE '[]'::jsonb END
       ) c WHERE c ->> 'nom' = v_cand) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidat_inconnu');
  END IF;

  -- LE BULLETIN EST LA REVENDICATION. Sa cle primaire porte (pays, cle du scrutin, votant) :
  -- un second bulletin du meme electeur pour le meme scrutin obtient un conflit et ne produit
  -- rien. Ce n'est pas un marqueur qu'une ecriture avalee peut perdre.
  --
  -- ET ELLE PORTE DESORMAIS LE TOUR, PAS SEULEMENT LE POSTE (11 octobre 2026). Un cycle n'etant
  -- plus detruit entre deux scrutins, la cle `pays_cle_votant` aurait interdit a un electeur de
  -- voter une seconde fois au scrutin SUIVANT du meme poste. Elle le lui interdisait deja au
  -- SECOND TOUR du meme scrutin, ou le blob remet `votes` a zero mais ou cette ligne survivait :
  -- personne n'a jamais pu voter a un second tour. `dateVote` identifie le tour en cours, et
  -- c'est la meme cle que `elections_tracts_pnj.tour` emploie deja.
  INSERT INTO public.votes_electoraux (id, country, poste_id, city, votant, candidat, tour, created_at)
  VALUES (v_pays || '_' || v_cle || '_' || v_moi || '_' || trim(to_char((v_cycle ->> 'dateVote')::numeric, 'FM999999999999999')),
          v_pays, v_poste, v_ville, v_moi, v_cand,
          (v_cycle ->> 'dateVote')::numeric::bigint, now())
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote');
  END IF;

  -- LE BLOB EST CE QUE LE DEPOUILLEMENT COMPTE, et il est ecrit DANS LA MEME TRANSACTION que le
  -- bulletin.
  UPDATE public.cycles_electoraux
     SET data = (v_cycle || jsonb_build_object('votes',
                   coalesce(CASE WHEN jsonb_typeof(v_cycle -> 'votes') = 'object'
                                 THEN v_cycle -> 'votes' END, '{}'::jsonb)
                   || jsonb_build_object(v_moi, v_cand)))::text,
         updated_at = now()
   WHERE id = v_id_cycle;

  RETURN jsonb_build_object('ok', true, 'votant', v_moi, 'candidat', v_cand, 'cle', v_cle);
END; $function$;

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
  v_ms   numeric := floor(extract(epoch FROM now()) * 1000);
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  IF p_canal NOT IN ('conference', 'jean_lou') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'canal_invalide');
  END IF;
  IF p_canal = 'conference' AND coalesce(current_setting('rp.conference_interne', true), '') <> 'on' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'canal_reserve_serveur');
  END IF;
  IF p_canal = 'jean_lou' AND coalesce(current_setting('rp.jean_lou_interne', true), '') <> 'on' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'canal_reserve_serveur');
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
  v_deja integer; v_pa integer; v_cost integer; v_jour integer; v_syndicat boolean;
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

  -- L'ADHESION, AU SERVEUR. Meme predicat que celui du navigateur : un syndicat de mon pays dont
  -- je suis membre.
  SELECT EXISTS (
    SELECT 1 FROM public.organisations o
     WHERE left(btrim(coalesce(o.data, '')), 1) = '{'
       AND (o.data::jsonb ->> 'type') = 'syndicale'
       AND coalesce(o.data::jsonb ->> 'country', o.country_origine) = v_pays
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(
                     CASE WHEN jsonb_typeof(o.data::jsonb -> 'membres') = 'array'
                          THEN o.data::jsonb -> 'membres' ELSE '[]'::jsonb END) m
                    WHERE m ->> 'nom' = v_moi))
    INTO v_syndicat;
  IF NOT coalesce(v_syndicat, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'adhesion_syndicale_requise'); END IF;

  -- UN SEUL RECRUTEMENT PAR JOUR DE JEU, ET PAR JOUEUR. La trace est le registre historique,
  -- qui porte desormais le JOUR DE JEU -- l'ancienne cle `jour` y ecrivait un horodatage en
  -- millisecondes, qui ne permettait aucune comparaison de journee.
  v_jour := coalesce(public.jour_de_jeu_pays(v_pays), 1);
  IF EXISTS (SELECT 1 FROM public.militants_recrutes r
              WHERE r.recruteur = v_moi AND r.country = v_pays
                AND (r.data ->> 'jour_de_jeu')::integer = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'recrutement_du_jour_deja_fait',
      'jour', v_jour); END IF;

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
  -- structure dont un lecteur vivant depend. Il porte desormais le JOUR DE JEU, qui est la trace
  -- sur laquelle la garde quotidienne s'appuie.
  INSERT INTO public.militants_recrutes (id, country, recruteur, data)
  VALUES (v_id, v_pays, v_moi, jsonb_build_object('nom', v_nom, 'pnj_id', v_id,
            'jour', (extract(epoch from now()) * 1000)::bigint,
            'jour_de_jeu', v_jour))
  ON CONFLICT (id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'pnj_id', v_id, 'nom', v_nom, 'metier', 'militant',
    'caracteristiques', public.pnj_metier_profil('militant'),
    'paiement', v_pay, 'militants', v_deja + 1, 'plafond', c_plafond, 'jour', v_jour);
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
  v_label text; v_ancien text; v_hab text;
BEGIN
  SELECT r.label INTO v_label FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF v_label IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;

  -- LA CARRIERE OUVRE LA FONCTION, OU LA FERME. Verifie ICI parce que les trois chemins d'acces
  -- a un poste nomme passent tous par cette porte : acceptation de nomination, candidature
  -- spontanee, attribution directe par l'autorite. Un PNJ n'a pas de fiche : il n'a pas de
  -- carriere non plus, et cette garde ne le concerne pas -- `poste_nommer` l'a deja oriente
  -- vers `titulaires_pnj` avant d'arriver ici.
  SELECT h.habilitation INTO v_hab FROM public.habilitations_postes h WHERE h.poste_id = p_poste;
  IF v_hab IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = p_titulaire)
     AND NOT public.habilitation_ouverte(p_titulaire, v_hab) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carriere_requise',
      'poste', p_poste, 'habilitation', v_hab,
      'carrieres_qui_ouvrent', (SELECT coalesce(jsonb_agg(c.carriere ORDER BY c.carriere), '[]'::jsonb)
                                  FROM public.habilitations_carrieres c WHERE c.habilitation = v_hab));
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

  DELETE FROM public.titulaires_pnj
   WHERE country = p_pays AND poste_id = p_poste AND city IS NOT DISTINCT FROM p_city;
  -- Le dossier de candidature du poste est solde (25/10/2026) : le poste est pourvu.
  PERFORM public.poste_candidature_dossier_solder_interne(p_pays, p_poste, p_city);

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

-- poste_candidature_dossier_ajouter_interne(text,text,text,text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_candidature_dossier_ajouter_interne(p_pays text, p_poste text, p_city text, p_candidat text, p_autorite text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text := p_pays || '_national_candidatures_postes'; v_etat jsonb; v_cands jsonb; v_cle text;
        v_dossier jsonb; v_maintenant bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
BEGIN
  INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
  VALUES (v_id, p_pays, 'national', 'candidatures_postes', to_jsonb('{"candidatures":{}}'::text), now())
  ON CONFLICT (id) DO NOTHING;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  v_cands := CASE WHEN jsonb_typeof(v_etat -> 'candidatures') = 'object' THEN v_etat -> 'candidatures' ELSE '{}'::jsonb END;
  v_cle := p_poste || '|' || coalesce(p_city, 'national');
  v_dossier := v_cands -> v_cle;
  IF v_dossier IS NULL OR coalesce((v_dossier ->> 'traitee')::boolean, false) THEN
    v_dossier := jsonb_build_object('posteId', p_poste, 'city', p_city,
      'candidats', jsonb_build_array(jsonb_build_object('nom', p_candidat, 'depuisTs', v_maintenant)),
      'echeanceTs', v_maintenant + 48 * 3600 * 1000, 'autoriteNom', p_autorite, 'traitee', false);
  ELSIF EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_dossier -> 'candidats', '[]'::jsonb)) c
                 WHERE c ->> 'nom' = p_candidat AND NOT coalesce((c ->> 'retiree')::boolean, false)) THEN
    RETURN 'deja_candidat';
  ELSE
    v_dossier := jsonb_set(v_dossier, '{candidats}', coalesce(v_dossier -> 'candidats', '[]'::jsonb)
                   || jsonb_build_array(jsonb_build_object('nom', p_candidat, 'depuisTs', v_maintenant)));
    IF v_dossier ->> 'autoriteNom' IS DISTINCT FROM p_autorite THEN
      v_dossier := v_dossier || jsonb_build_object('autoriteNom', p_autorite, 'echeanceTs', v_maintenant + 48 * 3600 * 1000);
    END IF;
  END IF;
  v_etat := coalesce(v_etat, '{}'::jsonb) || jsonb_build_object('candidatures', v_cands || jsonb_build_object(v_cle, v_dossier));
  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now() WHERE id = v_id;
  RETURN 'ajoute';
END; $function$;

-- poste_candidature_dossier_solder_interne(text,text,text) -> void | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_candidature_dossier_solder_interne(p_pays text, p_poste text, p_city text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text := p_pays || '_national_candidatures_postes'; v_etat jsonb; v_cle text := p_poste || '|' || coalesce(p_city, 'national');
BEGIN
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL OR jsonb_typeof(v_etat #> ARRAY['candidatures', v_cle]) IS DISTINCT FROM 'object'
     OR coalesce((v_etat #>> ARRAY['candidatures', v_cle, 'traitee'])::boolean, false) THEN RETURN; END IF;
  v_etat := jsonb_set(v_etat, ARRAY['candidatures', v_cle, 'traitee'], 'true'::jsonb);
  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now() WHERE id = v_id;
END; $function$;

-- poste_candidature_transmettre(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_candidature_transmettre(p_poste text, p_city text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_nom text; v_pays text; v_regle record; v_paie jsonb; v_autorite text; v_city text; v_res text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_nom;
  SELECT * INTO v_regle FROM public.postes_nommes_regles r WHERE r.poste_id = p_poste;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu'); END IF;
  v_city := CASE WHEN v_regle.scope = 'ville' THEN p_city END;
  IF EXISTS (SELECT 1 FROM public.postes_attribues a
              WHERE a.id = v_pays || '_' || p_poste || '_' || coalesce(v_city, 'national')
                AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = a.titulaire)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_deja_occupe_par_un_joueur');
  END IF;
  v_autorite := public.poste_recruteur_joueur(v_pays, p_poste, v_city);
  IF v_autorite IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'recruteur_pnj'); END IF;
  IF v_autorite = v_nom THEN RETURN jsonb_build_object('ok', false, 'raison', 'recruteur_soi_meme'); END IF;
  IF EXISTS (SELECT 1 FROM public.batiments_etat b,
                    jsonb_array_elements(coalesce(public.batiment_etat_lire(b.data)
                       #> ARRAY['candidatures', p_poste || '|' || coalesce(v_city, 'national'), 'candidats'], '[]'::jsonb)) c
              WHERE b.id = v_pays || '_national_candidatures_postes'
                AND NOT coalesce((public.batiment_etat_lire(b.data)
                       #>> ARRAY['candidatures', p_poste || '|' || coalesce(v_city, 'national'), 'traitee'])::boolean, false)
                AND c ->> 'nom' = v_nom AND NOT coalesce((c ->> 'retiree')::boolean, false)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;
  v_paie := public.payer_ordre(v_nom, 'postuler', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_res := public.poste_candidature_dossier_ajouter_interne(v_pays, p_poste, v_city, v_nom, v_autorite);
  PERFORM public.mail_systeme_poser_interne(v_nom, v_autorite, 'Candidature au poste de ' || v_regle.label,
    v_nom || ' postule au poste de <strong>' || v_regle.label || '</strong>. Vous disposez de 48h pour choisir un candidat depuis la fenêtre de gestion des candidatures, sans quoi le système tranchera automatiquement.<br><br>'
    || '[[act:candidature|' || p_poste || '|' || replace(replace(replace(v_regle.label, '|', ''), '[', ''), ']', '')
    || '|' || replace(replace(replace(v_nom, '|', ''), '[', ''), ']', '') || ']]');
  RETURN jsonb_build_object('ok', true, 'pa', v_paie -> 'pa', 'recruteur', v_autorite, 'dossier', v_res);
END; $function$;

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

  -- 1 PA par candidature (Fred, 25/10/2026). Preleve avec la nomination ; une nomination
  -- refusee annule le prelevement (sous-bloc = point de sauvegarde).
  DECLARE v_paie jsonb; v_res jsonb;
  BEGIN
    v_paie := public.payer_ordre(v_nom, 'postuler', 1, 0);
    IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
    v_res := public.poste_attribuer_interne(v_pays, p_poste, p_city, v_nom, 'candidature_autorite_pnj');
    IF coalesce((v_res ->> 'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'hg_candidature_refusee', DETAIL = v_res::text;
    END IF;
    RETURN v_res || jsonb_build_object('pa', v_paie -> 'pa');
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM = 'hg_candidature_refusee' THEN RETURN v_res; END IF;
    RAISE;
  END;
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

-- poste_recruteur_joueur(text,text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.poste_recruteur_joueur(p_pays text, p_poste text, p_city text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_regle record; v_nom text; v_ville_autorite text;
BEGIN
  SELECT * INTO v_regle FROM public.postes_nommes_regles WHERE poste_id = p_poste;
  IF NOT FOUND THEN RETURN NULL; END IF;
  v_ville_autorite := CASE WHEN coalesce(v_regle.autorite_scope, v_regle.scope) = 'ville' THEN p_city END;
  SELECT a.titulaire INTO v_nom FROM public.postes_attribues a
   WHERE a.country = p_pays AND a.poste_id = v_regle.nomme_par
     AND (v_ville_autorite IS NULL OR a.city IS NOT DISTINCT FROM v_ville_autorite)
     AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = a.titulaire)
   LIMIT 1;
  IF v_nom IS NOT NULL THEN RETURN v_nom; END IF;
  SELECT c.data::jsonb ->> 'eluId' INTO v_nom FROM public.cycles_electoraux c
   WHERE c.country = p_pays AND c.poste_id = v_regle.nomme_par
     AND (v_ville_autorite IS NULL OR c.city IS NOT DISTINCT FROM v_ville_autorite)
     AND left(btrim(c.data), 1) = '{'
     AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = c.data::jsonb ->> 'eluId')
   LIMIT 1;
  RETURN v_nom;
END; $function$;

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

-- presidence_mandat_courant(text) -> TABLE(president text, depuis timestamp with time zone) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presidence_mandat_courant(p_pays text)
 RETURNS TABLE(president text, depuis timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT pa.titulaire, pa.depuis
    FROM public.postes_attribues pa
    JOIN public.personnages_donnees c ON c.name = pa.titulaire
   WHERE pa.poste_id = 'president' AND pa.country = p_pays
     AND pa.titulaire IS NOT NULL
   LIMIT 1;
$function$;

-- presidence_memoire_contexte(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presidence_memoire_contexte(p_pays text, p_limite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_lim integer := least(greatest(coalesce(p_limite, 12), 1), 40); v_mandats jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(x ORDER BY (x->>'depuis') DESC), '[]'::jsonb) INTO v_mandats
  FROM (
    SELECT jsonb_build_object(
             'president', q.president,
             'depuis', q.mandat_depuis,
             'en_cours', (q.president = c.president AND q.mandat_depuis = c.depuis),
             'faits', q.faits) AS x
      FROM (
        SELECT m.president, m.mandat_depuis,
               jsonb_agg(jsonb_build_object(
                 'genre', m.genre, 'sujet', m.sujet, 'jour', m.jour, 'le', m.le,
                 'detail', m.detail,
                 -- La premiere reaction posterieure DANS LE MEME MANDAT. NULL est une observation.
                 'suivi_de', CASE WHEN m.genre = 'contexte' THEN (
                     SELECT r.sujet FROM public.presidence_memoire r
                      WHERE r.pays = m.pays AND r.president = m.president
                        AND r.mandat_depuis = m.mandat_depuis
                        AND r.genre = 'reaction' AND r.le > m.le
                      ORDER BY r.le LIMIT 1) ELSE NULL END
               ) ORDER BY m.le) AS faits
          FROM public.presidence_memoire m
         WHERE m.pays = p_pays
           AND m.id > (SELECT coalesce(max(id), 0) - v_lim * 8 FROM public.presidence_memoire WHERE pays = p_pays)
         GROUP BY m.president, m.mandat_depuis, m.pays
      ) q
      LEFT JOIN public.presidence_mandat_courant(p_pays) c ON true
  ) z;

  RETURN jsonb_build_object('ok', true, 'mandats', v_mandats,
                            'vide', v_mandats = '[]'::jsonb);
END;
$function$;

-- presidence_memoire_mon_pays() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presidence_memoire_mon_pays()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_inconnu');
  END IF;
  RETURN public.presidence_memoire_contexte(v_pays, 12);
END;
$function$;

-- presidence_memoire_noter(text,text,text,text,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.presidence_memoire_noter(p_pays text, p_genre text, p_source text, p_sujet text, p_detail jsonb, p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE m record; s record; v_id bigint;
BEGIN
  IF coalesce(btrim(coalesce(p_pays,'')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'enregistre', false, 'raison', 'pays_absent');
  END IF;

  SELECT * INTO s FROM public.presidence_memoire_sources WHERE source = p_source;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'enregistre', false, 'raison', 'source_non_declaree');
  END IF;
  IF s.genre IS DISTINCT FROM p_genre THEN
    RETURN jsonb_build_object('ok', false, 'enregistre', false, 'raison', 'genre_contredit_la_source',
                              'genre_declare', s.genre);
  END IF;

  SELECT * INTO m FROM public.presidence_mandat_courant(p_pays);
  IF NOT FOUND THEN
    -- AUCUN PRESIDENT JOUEUR : on n'ecrit rien, et ce n'est pas un echec. C'est l'etat de la beta
    -- au 11 octobre 2026, et c'est ce qui empeche de fabriquer un passe.
    RETURN jsonb_build_object('ok', true, 'enregistre', false, 'raison', 'aucun_president_joueur');
  END IF;

  IF p_genre = 'reaction' AND coalesce(p_acteur, '') IS DISTINCT FROM m.president THEN
    RETURN jsonb_build_object('ok', true, 'enregistre', false, 'raison', 'acteur_n_est_pas_le_president');
  END IF;

  INSERT INTO public.presidence_memoire (pays, president, mandat_depuis, genre, source, sujet, detail, jour)
  VALUES (p_pays, m.president, m.depuis, p_genre, p_source, p_sujet,
          coalesce(p_detail, '{}'::jsonb), public.jour_de_jeu_pays(p_pays))
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'enregistre', true, 'id', v_id,
                            'president', m.president, 'mandat_depuis', m.depuis);
END;
$function$;

-- vote_confiance_declencher(integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vote_confiance_declencher(p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_poste text; v_paie jsonb; v_id text; v_cloture timestamptz := now() + interval '48 hours';
  v_dep record; v_n integer := 0;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, poste ->> 'id' INTO v_pays, v_poste FROM public.personnages_donnees WHERE name = v_moi;
  IF v_poste IS DISTINCT FROM 'pm' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_pm'); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('vote_confiance_' || v_pays));
  IF EXISTS (SELECT 1 FROM public.votes_confiance WHERE country = v_pays AND statut = 'en_cours') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_deja_en_cours'); END IF;
  v_paie := public.payer_ordre(v_moi, 'declencher_vote_confiance', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_id := 'voteconf-' || (extract(epoch FROM now()) * 1000)::bigint;
  INSERT INTO public.votes_confiance (id, country, pm_nom, cloture_ts, statut, resultat, bulletins,
                                      demission_limite_ts, demission_ts, consequence_appliquee, created_at)
  VALUES (v_id, v_pays, v_moi, v_cloture, 'en_cours', NULL, '{}'::jsonb, NULL, NULL, false, now());
  FOR v_dep IN SELECT name FROM public.personnages_donnees WHERE country = v_pays AND (poste_depute ->> 'id') = 'depute' LOOP
    PERFORM public.mail_systeme_poser_interne('Assemblée Nationale', v_dep.name, 'Vote de confiance — Assemblée Nationale',
      'Le Premier Ministre ' || v_moi || ' engage la responsabilité de son gouvernement. Votez avant 48h.<br><br>'
      || '[[act:confiance_pour|' || v_id || ']][[act:confiance_contre|' || v_id || ']]',
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI'));
    v_n := v_n + 1;
  END LOOP;
  PERFORM public.annonce_publique_interne(v_pays, '🏛 Le Premier Ministre ' || v_moi
    || ' engage la responsabilité de son gouvernement devant l''Assemblée Nationale.');
  RETURN jsonb_build_object('ok', true, 'vote_id', v_id, 'cloture_ts', v_cloture, 'deputes_prevenus', v_n)
    || jsonb_build_object('paie', v_paie);
END; $function$;

-- vote_confiance_resoudre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vote_confiance_resoudre(p_vote_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_vote record; v_bulletins jsonb; v_pour int := 0; v_contre int := 0;
  v_votants int := 0; v_isn numeric := 30; v_chance numeric; v_sieges int;
  v_confiance boolean; v_resultat text; v_i int;
BEGIN
  -- LE VERROU SUR LE VOTE EST LA REVENDICATION : deux passes simultanees se serialisent ici, et
  -- la seconde lit 'termine'.
  SELECT * INTO v_vote FROM public.votes_confiance WHERE id = p_vote_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','vote_introuvable'); END IF;
  IF coalesce(v_vote.statut,'') <> 'en_cours' THEN
    RETURN jsonb_build_object('ok',false,'raison','deja_resolu','statut',v_vote.statut); END IF;
  IF v_vote.cloture_ts IS NULL OR now() < v_vote.cloture_ts THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_echu'); END IF;

  v_bulletins := coalesce(v_vote.bulletins, '{}'::jsonb);
  -- LES DEPUTES PJ REELLEMENT EN POSTE, et seuls ceux qui ont vote. Meme regle qu'avant :
  -- poste_depute.id = 'depute' sur une fiche du pays du vote. Et meme convention de
  -- depouillement : un bulletin present qui n'est pas « pour » compte CONTRE.
  SELECT count(*) FILTER (WHERE v_bulletins ->> d.name = 'pour'),
         count(*) FILTER (WHERE (v_bulletins ? d.name) AND v_bulletins ->> d.name <> 'pour'),
         count(*) FILTER (WHERE v_bulletins ? d.name)
    INTO v_pour, v_contre, v_votants
    FROM public.personnages_donnees d
   WHERE d.country = v_vote.country
     AND (d.poste_depute ->> 'id') = 'depute';

  -- Pas d'ISN national persiste cote serveur : l'ISN de la capitale est le meilleur proxy
  -- disponible, avec 30 en repli -- meme ecart d'architecture qu'avant, sciemment non traite.
  IF v_vote.country = 'republic' THEN
    SELECT coalesce(nullif(i.data ->> 'isn','')::numeric, 30) INTO v_isn
      FROM public.indices_villes i WHERE i.id = v_vote.country || '_capitale';
    v_isn := coalesce(v_isn, 30);
  END IF;
  v_chance := least(85, 30 + v_isn / 2);
  -- 9 sieges : 3 reels par ville. LE TIRAGE DES SIEGES RESTANTS EST ICI, dans la transaction qui
  -- ecrit le resultat : un rejeu ne peut plus le refaire.
  v_sieges := greatest(0, 9 - v_votants);
  FOR v_i IN 1 .. v_sieges LOOP
    IF random() * 100 < v_chance THEN v_contre := v_contre + 1; ELSE v_pour := v_pour + 1; END IF;
  END LOOP;

  v_confiance := v_pour > v_contre;
  v_resultat  := CASE WHEN v_confiance THEN 'confiance' ELSE 'censure' END;

  -- Le Premier Ministre n'est PLUS destitue automatiquement (arbitrage du 4 septembre 2026) :
  -- seule une consequence differee s'applique s'il n'a pas demissionne a l'echeance.
  UPDATE public.votes_confiance
     SET statut = 'termine', resultat = v_resultat,
         demission_limite_ts = CASE WHEN v_confiance THEN NULL
                                    ELSE now() + interval '48 hours' END
   WHERE id = p_vote_id;

  INSERT INTO public.evenements_globaux (country, city, texte, jour)
  VALUES (v_vote.country, NULL,
    '🏛 Vote de confiance : ' || v_pour::text || ' POUR / ' || v_contre::text || ' CONTRE. ' ||
    CASE WHEN v_confiance
      THEN 'Le gouvernement de ' || v_vote.pm_nom || ' obtient la confiance.'
      ELSE 'Le gouvernement de ' || v_vote.pm_nom || ' est CENSURÉ. Le Premier Ministre est politiquement appelé à démissionner sous 48h.'
    END, NULL);

  IF NOT v_confiance THEN
    PERFORM public.mail_systeme_poser_interne('Assemblée Nationale', v_vote.pm_nom,
      'Motion de censure adoptée',
      'L''Assemblée Nationale a retiré sa confiance à votre gouvernement (' || v_pour::text ||
      ' pour / ' || v_contre::text || ' contre). Vous êtes politiquement appelé(e) à démissionner sous 48h réelles. Passé ce délai sans démission, votre popularité et celle de tout le gouvernement tomberont à zéro -- vos postes ne seront cependant jamais retirés automatiquement.',
      to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'));
  END IF;

  RETURN jsonb_build_object('ok',true,'vote_id',p_vote_id,'country',v_vote.country,
                            'resultat',v_resultat,'pour',v_pour,'contre',v_contre,
                            'sieges_tires',v_sieges);
END; $function$;

-- vote_confiance_voter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.vote_confiance_voter(p_vote_id text, p_choix text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_depute text; v_vote record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_choix NOT IN ('pour', 'contre') THEN RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide'); END IF;
  SELECT country, poste_depute ->> 'id' INTO v_pays, v_depute FROM public.personnages_donnees WHERE name = v_moi;
  IF v_depute IS DISTINCT FROM 'depute' THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_deputes'); END IF;
  SELECT * INTO v_vote FROM public.votes_confiance WHERE id = p_vote_id FOR UPDATE;
  IF NOT FOUND OR v_vote.country IS DISTINCT FROM v_pays OR v_vote.statut <> 'en_cours' OR now() >= v_vote.cloture_ts THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vote_ferme'); END IF;
  IF coalesce(v_vote.bulletins, '{}'::jsonb) ? v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_vote'); END IF;
  UPDATE public.votes_confiance SET bulletins = coalesce(bulletins, '{}'::jsonb) || jsonb_build_object(v_moi, p_choix)
   WHERE id = p_vote_id;
  RETURN jsonb_build_object('ok', true, 'choix', p_choix);
END; $function$;
