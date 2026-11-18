-- NATIONALITÉ, DOMICILE ET ÉLECTIONS (décisions de Fred du 18/11/2026, nuit ;
-- GAME-DESIGN-ELECTIONS.md « Nationalité, domicile et élections », GAME-DESIGN-NOVOMIRSK.md).
--
-- Modèle : `personnages_donnees.country` reste le PAYS OÙ L'ON SE TROUVE (le transport le réécrit,
-- comme toutes les lectures de lieu, de prix et de monnaie l'attendent). La NATIONALITÉ devient une
-- donnée propre et stable, `nationalite`, que seule une naturalisation acceptée change. Le domicile
-- (jsonb {country, city}) ne change que par domiciliation. Les droits politiques, les postes et la
-- conscription lisent désormais la nationalité.
--
-- Personnages existants : nationalité = pays de création, c'est-à-dire le pays du domicile posé à la
-- création (creation.js), à défaut le pays actuel. Idempotente.
BEGIN;

-- ---------------------------------------------------------------------------------------------
-- 1. Colonne, remplissage, garde
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.personnages_donnees ADD COLUMN IF NOT EXISTS nationalite text;

DO $remplir$
BEGIN
  PERFORM set_config('hg.nationalite_serveur', 'on', true);
  UPDATE public.personnages_donnees
     SET nationalite = coalesce(nullif(domicile->>'country', ''), country)
   WHERE nationalite IS NULL;
  PERFORM set_config('hg.nationalite_serveur', 'off', true);
END $remplir$;

-- La nationalité ne s'écrit qu'au serveur (naturalisation). À la création, elle vaut le pays choisi.
CREATE OR REPLACE FUNCTION public.personnages_nationalite_garder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.nationalite := coalesce(nullif(NEW.domicile->>'country', ''), NEW.country);
  ELSIF coalesce(current_setting('hg.nationalite_serveur', true), '') <> 'on' THEN
    NEW.nationalite := OLD.nationalite;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_personnages_nationalite_garder ON public.personnages_donnees;
CREATE TRIGGER trg_personnages_nationalite_garder BEFORE INSERT OR UPDATE ON public.personnages_donnees
  FOR EACH ROW EXECUTE FUNCTION public.personnages_nationalite_garder();
REVOKE ALL ON FUNCTION public.personnages_nationalite_garder() FROM PUBLIC, anon, authenticated;

-- La vue lue par le navigateur expose la nationalité (colonne ajoutée en dernière position).
DO $vue$
DECLARE v text; a text;
BEGIN
  v := pg_get_viewdef('public.personnages'::regclass, true);
  IF position('nationalite' IN v) > 0 THEN RETURN; END IF;
  a := E'NULL::jsonb AS fiche_base\n   FROM personnages_donnees d;';
  IF position(a IN v) = 0 THEN RAISE EXCEPTION 'vue personnages : ancrage introuvable'; END IF;
  EXECUTE 'CREATE OR REPLACE VIEW public.personnages AS ' || replace(v, a, E'NULL::jsonb AS fiche_base,\n    nationalite\n   FROM personnages_donnees d');
END $vue$;

CREATE OR REPLACE FUNCTION public.personnage_nationalite(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(nationalite, country) FROM public.personnages_donnees WHERE name = p_nom
$$;
REVOKE ALL ON FUNCTION public.personnage_nationalite(text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- 2. Partis de Sovarka : taille (au moins 2 membres, chef compris ; sinon suspendu)
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_parti_taille(p_parti text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT count(DISTINCT n)::integer FROM (
           SELECT m->>'nom' AS n FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres') = 'array'
                                                               THEN o.data::jsonb->'membres' ELSE '[]'::jsonb END) m
           UNION SELECT o.data::jsonb->>'chef') x WHERE n IS NOT NULL AND n <> ''), 0)
    FROM public.organisations o WHERE o.id = p_parti
$$;
REVOKE ALL ON FUNCTION public.sovarka_parti_taille(text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- 3. Éligibilité commune d'une candidature (nationalité, présence, domicile ; règles de Sovarka)
-- ---------------------------------------------------------------------------------------------
-- p_mode : 'soi' (le joueur se déclare) ou 'investiture' (le chef d'un parti de Sovarka investit).
CREATE OR REPLACE FUNCTION public.candidature_refus_nationalite_interne(p_nom text, p_poste text, p_ville text, p_mode text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE f record; v_nat text; v_parti text;
BEGIN
  SELECT * INTO f FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN 'personnage_introuvable'; END IF;
  v_nat := coalesce(f.nationalite, f.country);
  -- On se déclare candidat dans son pays ; l'investiture par le parti ne demande pas la présence.
  IF p_mode IS DISTINCT FROM 'investiture' AND f.country IS DISTINCT FROM v_nat THEN RETURN 'hors_de_son_pays'; END IF;
  -- Mairie : nationalité du pays ET domicile dans cette ville.
  IF p_poste = 'maire' AND (f.domicile->>'country' IS DISTINCT FROM v_nat OR f.domicile->>'city' IS DISTINCT FROM p_ville) THEN
    RETURN 'domicile_requis';
  END IF;
  IF v_nat = 'soviet' THEN
    IF p_poste = 'depute' THEN RETURN 'depute_designe_par_parti'; END IF;
    IF p_poste IN ('president', 'maire') THEN
      v_parti := public.sovarka_parti_de(p_nom);
      IF v_parti IS NULL THEN RETURN 'parti_requis'; END IF;
      IF p_poste = 'maire' AND p_mode IS DISTINCT FROM 'investiture' THEN RETURN 'investiture_requise'; END IF;
      IF p_poste = 'president' AND NOT EXISTS (SELECT 1 FROM public.organisations o
                                               WHERE o.id = v_parti AND o.data::jsonb->>'chef' = p_nom) THEN
        RETURN 'chef_de_parti_requis';
      END IF;
      IF public.sovarka_parti_taille(v_parti) < 2 THEN RETURN 'parti_suspendu'; END IF;
    END IF;
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.candidature_refus_nationalite_interne(text, text, text, text) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- 4. Publication d'une candidature : noyau commun (soi / investiture), cycle choisi par la NATIONALITÉ
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.candidature_publier_interne(p_nom text, p_poste text, p_city text, p_cle_scrutin numeric,
                                                              p_titre text, p_contenu text, p_mode text, p_parti text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE
  v_nom text := p_nom; v_pays text; v_inf numeric; v_poste record; v_fiche record; v_refus text;
  v_ville text; v_cle text; v_id text; v_topic text; v_forum text; v_temps text; v_cle_scrutin numeric;
  v_paiement jsonb; v_titre text; v_contenu text; v_cycle jsonb; v_cands jsonb;
BEGIN
  SELECT * INTO v_fiche FROM public.personnages_donnees WHERE name = v_nom;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pays := coalesce(v_fiche.nationalite, v_fiche.country);

  SELECT * INTO v_poste FROM public.postes_electifs_regles WHERE poste_id = p_poste;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_inconnu');
  END IF;
  v_ville := CASE WHEN v_poste.niveau = 'ville' THEN nullif(p_city, '') ELSE NULL END;

  v_refus := public.candidature_refus_nationalite_interne(v_nom, p_poste, v_ville, p_mode);
  IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', v_refus); END IF;

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

  v_cle := p_poste || CASE WHEN v_ville IS NOT NULL THEN '_' || v_ville ELSE '' END;

  PERFORM pg_advisory_xact_lock(hashtext('candidature_unique|'||v_nom));
  -- LE BULLETIN EST LE CYCLE (02/11/2026) : verrouillé avant le paiement, candidat ajouté dans la
  -- même transaction.
  SELECT c.data::jsonb INTO v_cycle FROM public.cycles_electoraux c
   WHERE c.id = v_pays || '_' || v_cle FOR UPDATE;
  IF v_cycle IS NULL OR jsonb_typeof(v_cycle) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cycle_introuvable');
  END IF;
  v_cle_scrutin := coalesce(p_cle_scrutin, CASE WHEN jsonb_typeof(v_cycle->'dateDebutCandidatures') = 'number'
                                                THEN (v_cycle->>'dateDebutCandidatures')::numeric END);
  v_id := v_pays || '_' || v_cle || '_' || v_nom
          || CASE WHEN v_cle_scrutin IS NOT NULL THEN '_' || v_cle_scrutin::bigint::text ELSE '' END;
  IF EXISTS (SELECT 1 FROM public.candidatures WHERE id = v_id) THEN
    RETURN jsonb_build_object('ok', true, 'deja_candidat', true, 'id', v_id,
                              'topic_id', (SELECT topic_id FROM public.candidatures WHERE id = v_id));
  END IF;
  IF public.candidature_autre_scrutin_actif(v_pays,v_nom,v_pays||'_'||v_cle) THEN
    RETURN jsonb_build_object('ok',false,'raison','candidature_simultanee_interdite');
  END IF;
  v_cands := CASE WHEN jsonb_typeof(v_cycle -> 'candidats') = 'array' THEN v_cycle -> 'candidats' ELSE '[]'::jsonb END;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_cands) e WHERE e ->> 'nom' = v_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_candidat');
  END IF;
  IF p_mode = 'investiture' THEN
    v_paiement := jsonb_build_object('ok', true);   -- l'investiture est gratuite pour l'investi
  ELSE
    v_paiement := public.payer_ordre(v_nom, 'deposer_candidature', 2, 0);
    IF NOT coalesce((v_paiement->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paiement->>'raison', 'paiement_refuse'));
    END IF;
  END IF;

  v_contenu := coalesce(nullif(btrim(p_contenu), ''), '(programme vide)');
  v_titre := coalesce(nullif(btrim(p_titre), ''),
                      '🗳️ Programme de ' || v_nom || ' — ' || v_poste.nom);
  v_topic := 'topic-programme-' || v_id;
  -- LE FORUM DE LA JURIDICTION DU SCRUTIN (ville du scrutin, ou national).
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

  UPDATE public.cycles_electoraux
     SET data = jsonb_set(v_cycle, '{candidats}', v_cands || jsonb_build_array(jsonb_build_object(
                  'nom', v_nom, 'programme', v_contenu, 'archetype', v_fiche.archetype,
                  'topicId', v_topic, 'posteActuel', v_fiche.poste ->> 'name',
                  'prospectusDistribues', 0,
                  'dateInscription', floor(extract(epoch FROM now()) * 1000))
                  || CASE WHEN p_parti IS NOT NULL THEN jsonb_build_object('investiPar', p_parti) ELSE '{}'::jsonb END), true)::text,
         updated_at = now()
   WHERE id = v_pays || '_' || v_cle;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'topic_id', v_topic, 'forum', v_forum,
                            'poste', p_poste, 'city', v_ville, 'pa', v_paiement->'pa');
END; $function$;
REVOKE ALL ON FUNCTION public.candidature_publier_interne(text, text, text, numeric, text, text, text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.candidature_publier(p_poste text, p_city text, p_cle_scrutin numeric, p_titre text, p_contenu text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_nom text;
BEGIN
  v_nom := public.mon_personnage();
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  RETURN public.candidature_publier_interne(v_nom, p_poste, p_city, p_cle_scrutin, p_titre, p_contenu, 'soi', NULL);
END; $function$;

-- Ancien chemin (candidature_deposer) : même éligibilité, cycle choisi par la nationalité.
DO $deposer$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.candidature_deposer(text,text,numeric,jsonb)'::regprocedure);
  IF position('candidature_refus_nationalite_interne' IN d) > 0 THEN RETURN; END IF;
  a := E'  v_pays := v_fiche.country;\n';
  b := E'  v_pays := coalesce(v_fiche.nationalite, v_fiche.country);\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'candidature_deposer : ancrage pays'; END IF;
  d := replace(d, a, b);
  a := substring(d FROM E'  IF coalesce\\(v_fiche\\.domicile->>''country'', v_pays\\) IS DISTINCT FROM v_pays THEN\\n.*?      RETURN jsonb_build_object\\(''ok'', false, ''raison'', ''parti_requis''\\);\\n    END IF;\\n  END IF;\\n');
  IF a IS NULL THEN RAISE EXCEPTION 'candidature_deposer : ancrage éligibilité'; END IF;
  b := E'  v_city := nullif(btrim(coalesce(p_city, '''')), '''');\n'
    || E'  IF public.candidature_refus_nationalite_interne(v_moi, p_poste, CASE WHEN v_poste.niveau = ''ville'' THEN v_city END, ''soi'') IS NOT NULL THEN\n'
    || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', public.candidature_refus_nationalite_interne(v_moi, p_poste, CASE WHEN v_poste.niveau = ''ville'' THEN v_city END, ''soi''));\n'
    || E'  END IF;\n';
  EXECUTE replace(d, a, b);
END $deposer$;

-- ---------------------------------------------------------------------------------------------
-- 5. Vote : présidentielle selon la nationalité, municipales selon le domicile ; toujours dans le pays
-- ---------------------------------------------------------------------------------------------
DO $voter$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.election_voter(text,text,text,text)'::regprocedure);
  IF position('nationalite_requise' IN d) > 0 THEN RETURN; END IF;
  a := E'  v_n        integer;\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'election_voter : ancrage déclarations'; END IF;
  d := replace(d, a, a || E'  v_f        record;\n');
  a := substring(d FROM E'  -- DOMICILE : meme regle que le client.*?RETURN jsonb_build_object\\(''ok'', false, ''raison'', ''non_domicilie''\\);\\n  END IF;\\n');
  IF a IS NULL THEN RAISE EXCEPTION 'election_voter : ancrage domicile'; END IF;
  b := E'  -- NATIONALITÉ ET DOMICILE (Fred, 18/11/2026) : présidentielle et scrutins nationaux selon la\n'
    || E'  -- nationalité ; municipales selon le domicile (ville et pays) ; on ne vote que depuis ce pays.\n'
    || E'  SELECT * INTO v_f FROM public.personnages_donnees d WHERE d.name = v_moi;\n'
    || E'  IF v_local THEN\n'
    || E'    IF v_f.domicile ->> ''country'' IS DISTINCT FROM v_pays OR v_f.domicile ->> ''city'' IS DISTINCT FROM v_ville THEN\n'
    || E'      RETURN jsonb_build_object(''ok'', false, ''raison'', ''non_domicilie'');\n'
    || E'    END IF;\n'
    || E'  ELSIF coalesce(v_f.nationalite, v_f.country) IS DISTINCT FROM v_pays THEN\n'
    || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''nationalite_requise'');\n'
    || E'  END IF;\n'
    || E'  IF v_f.country IS DISTINCT FROM v_pays THEN\n'
    || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''hors_de_son_pays'');\n'
    || E'  END IF;\n';
  EXECUTE replace(d, a, b);
END $voter$;

-- ---------------------------------------------------------------------------------------------
-- 6. Postes, salaires, conscription : la nationalité, plus le pays où l'on se trouve
-- ---------------------------------------------------------------------------------------------
DO $postes$
DECLARE d text; f text; a text; b text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.poste_postuler(text,text)', 'public.poste_accepter_nomination(text)'] LOOP
    d := pg_get_functiondef(f::regprocedure);
    IF position('coalesce(d.nationalite, d.country)' IN d) > 0 THEN CONTINUE; END IF;
    a := 'SELECT d.name, d.country INTO v_nom, v_pays';
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION '% : ancrage pays', f; END IF;
    EXECUTE replace(d, a, 'SELECT d.name, coalesce(d.nationalite, d.country) INTO v_nom, v_pays');
  END LOOP;
  d := pg_get_functiondef('public.poste_candidature_transmettre(text,text)'::regprocedure);
  IF position('nationalite' IN d) = 0 THEN
    a := 'SELECT coalesce(country, ''republic'') INTO v_pays FROM public.personnages_donnees WHERE name = v_nom';
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'poste_candidature_transmettre : ancrage'; END IF;
    EXECUTE replace(d, a, 'SELECT coalesce(nationalite, country, ''republic'') INTO v_pays FROM public.personnages_donnees WHERE name = v_nom');
  END IF;
  d := pg_get_functiondef('public.salaire_civil_percevoir()'::regprocedure);
  IF position('nationalite' IN d) = 0 THEN
    a := 'SELECT coalesce(country,''republic''), poste ->> ''id'',';
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'salaire_civil_percevoir : ancrage'; END IF;
    EXECUTE replace(d, a, 'SELECT coalesce(nationalite,country,''republic''), poste ->> ''id'',');
  END IF;
  -- Conscription de Sovarka : les citoyens de Sovarka sans poste (nationalité), où qu'ils soient.
  d := pg_get_functiondef('public.sovarka_pouvoir_commande(uuid,text,jsonb)'::regprocedure);
  IF position('coalesce(x.nationalite, x.country) = ''soviet'' AND (x.poste IS NULL' IN d) = 0 THEN
    a := 'WHERE x.country = ''soviet'' AND (x.poste IS NULL';
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'sovarka_pouvoir_commande : ancrage conscription'; END IF;
    EXECUTE replace(d, a, 'WHERE coalesce(x.nationalite, x.country) = ''soviet'' AND (x.poste IS NULL');
  END IF;
END $postes$;

-- ---------------------------------------------------------------------------------------------
-- 7. Partis de Sovarka : nationalité pour fonder, demander et être accepté ; investiture d'un candidat
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sovarka_parti_investir_interne(p_chef text, p_parti text, p_params jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d jsonb; v_cible text := btrim(coalesce(p_params->>'nom', '')); v_ville text := btrim(coalesce(p_params->>'ville', ''));
        v jsonb;
BEGIN
  SELECT data::jsonb INTO d FROM public.organisations WHERE id = p_parti;
  IF p_params - ARRAY['nom', 'ville', 'programme'] <> '{}'::jsonb THEN RETURN jsonb_build_object('ok', false, 'raison', 'champs_interdits'); END IF;
  IF v_ville NOT IN ('capitale', 'ville_a', 'ville_b') THEN RETURN jsonb_build_object('ok', false, 'raison', 'ville_invalide'); END IF;
  IF d->>'chef' IS DISTINCT FROM p_chef THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_chef'); END IF;
  IF public.sovarka_parti_taille(p_parti) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'parti_suspendu'); END IF;
  IF v_cible = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_requise'); END IF;
  IF v_cible = p_chef THEN RETURN jsonb_build_object('ok', false, 'raison', 'chef_ne_peut_s_investir'); END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(d->'membres', '[]')) m WHERE m->>'nom' = v_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'membre_absent');
  END IF;
  IF public.personnage_nationalite(v_cible) IS DISTINCT FROM 'soviet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nationalite_requise');
  END IF;
  v := public.candidature_publier_interne(v_cible, 'maire', v_ville, NULL,
         '🗳️ ' || v_cible || ', candidat investi par ' || (d->>'nom'),
         coalesce(nullif(btrim(p_params->>'programme'), ''), v_cible || ' est investi par le parti ' || (d->>'nom') || '.'),
         'investiture', p_parti);
  IF coalesce((v->>'ok')::boolean, false) AND NOT coalesce((v->>'deja_candidat')::boolean, false) THEN
    PERFORM public.mail_systeme_poser_interne(d->>'nom', v_cible, 'Investiture',
      p_chef || ', chef du parti ' || (d->>'nom') || ', vous a investi candidat à la mairie.', NULL);
  END IF;
  RETURN v || jsonb_build_object('action', 'investir', 'nom', v_cible, 'ville', v_ville);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_parti_investir_interne(text, text, jsonb) FROM PUBLIC, anon, authenticated;

DO $partis$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.sovarka_parti_commande(uuid,text,text,jsonb)'::regprocedure);
  IF position('sovarka_parti_investir_interne' IN d) > 0 THEN RETURN; END IF;
  -- Fonder ou demander l'adhésion : nationalité sovarkienne (en plus d'être en Sovarka).
  a := E'    ELSIF p_action = ''fonder'' THEN\n';
  b := E'    ELSIF p_action IN (''fonder'', ''demander'') AND public.personnage_nationalite(a) IS DISTINCT FROM ''soviet'' THEN\n'
    || E'      v := jsonb_build_object(''ok'', false, ''raison'', ''nationalite_requise'');\n' || a;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'sovarka_parti_commande : ancrage fonder'; END IF;
  d := replace(d, a, b);
  -- Accepter : le candidat doit être de nationalité sovarkienne.
  a := E'          IF public.sovarka_parti_de(v_cible) IS NOT NULL THEN\n            v := jsonb_build_object(''ok'', false, ''raison'', ''candidat_deja_dans_un_parti'');\n';
  b := a || E'          ELSIF public.personnage_nationalite(v_cible) IS DISTINCT FROM ''soviet'' THEN\n'
         || E'            v := jsonb_build_object(''ok'', false, ''raison'', ''candidat_non_sovarkien'');\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'sovarka_parti_commande : ancrage accepter'; END IF;
  d := replace(d, a, b);
  -- Investir un candidat à une mairie (chef du parti).
  a := E'      ELSIF p_action IN (''accepter'', ''refuser'', ''fixer_prix'', ''successeur'', ''designer_pm'') THEN\n';
  b := E'      ELSIF p_action = ''investir'' THEN\n'
    || E'        v := public.sovarka_parti_investir_interne(a, p_parti, p_params);\n' || a;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'sovarka_parti_commande : ancrage investir'; END IF;
  d := replace(d, a, b);
  EXECUTE d;
END $partis$;

-- Chef élu président : il quitte la tête du parti (en restant membre) et désigne son successeur ;
-- à défaut sous 3 jours, le plus ancien membre devient chef. Passe de nuit (tâche « sovarka_partis_presidence »).
CREATE OR REPLACE FUNCTION public.sovarka_partis_presidence_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE o record; d jsonb; v_jour integer := coalesce(public.jour_de_jeu_pays('soviet'), 1);
        v_grades jsonb := public.organisation_regles_membres() -> 'politique' -> 'grades' -> 'soviet';
        v_succ text; n_marques int := 0; n_remplaces int := 0;
BEGIN
  FOR o IN SELECT id, data::jsonb AS d FROM public.organisations
            WHERE data IS JSON OBJECT AND public.sovarka_est_parti_interne(data::jsonb) FOR UPDATE LOOP
    d := o.d;
    IF EXISTS (SELECT 1 FROM public.personnages_donnees x
                WHERE x.name = d->>'chef' AND x.poste->>'id' = 'president'
                  AND coalesce(x.nationalite, x.country) = 'soviet') THEN
      IF d->>'chefPresidentDepuis' IS NULL THEN
        d := d || jsonb_build_object('chefPresidentDepuis', v_jour);
        n_marques := n_marques + 1;
        PERFORM public.mail_systeme_poser_interne(d->>'nom', d->>'chef', 'Successeur à la tête du parti',
          'Élu président, vous quittez la tête du parti ' || (d->>'nom') || ' tout en restant membre. Désignez votre successeur '
          || '(« Mon parti », salle des partis) : sans désignation sous 3 jours, le plus ancien membre devient chef.', NULL);
      ELSIF v_jour - (d->>'chefPresidentDepuis')::integer >= 3 THEN
        SELECT m->>'nom' INTO v_succ FROM jsonb_array_elements(coalesce(d->'membres', '[]')) WITH ORDINALITY e(m, i)
         WHERE m->>'nom' IS DISTINCT FROM d->>'chef'
         ORDER BY coalesce((m->>'rejointLe')::integer, 2147483647), i LIMIT 1;
        IF v_succ IS NOT NULL THEN
          PERFORM public.mail_systeme_poser_interne(d->>'nom', v_succ, 'Vous dirigez désormais ' || (d->>'nom'),
            'Sans successeur désigné par ' || (d->>'chef') || ' (élu président), vous devenez chef du parti en tant que plus ancien membre.', NULL);
          d := jsonb_set(d, '{membres}', (SELECT jsonb_agg(CASE WHEN m->>'nom' = v_succ THEN m || jsonb_build_object('gradeIdx', 3, 'grade', v_grades->>3)
                                                              WHEN m->>'nom' = d->>'chef' THEN m || jsonb_build_object('gradeIdx', 2, 'grade', v_grades->>2)
                                                              ELSE m END ORDER BY i) FROM jsonb_array_elements(d->'membres') WITH ORDINALITY e(m, i)));
          d := (d - 'chefPresidentDepuis') || jsonb_build_object('chef', v_succ);
          n_remplaces := n_remplaces + 1;
        END IF;
      END IF;
    ELSIF d ? 'chefPresidentDepuis' THEN
      d := d - 'chefPresidentDepuis';   -- successeur désigné entre-temps, ou plus président
    END IF;
    IF d IS DISTINCT FROM o.d THEN UPDATE public.organisations SET data = d::text WHERE id = o.id; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'marques', n_marques, 'remplaces', n_remplaces);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_partis_presidence_passe() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_partis_presidence_passe() TO service_role;

-- ---------------------------------------------------------------------------------------------
-- 8. Naturalisation : demande à une mairie du pays visé (2 PA + 50), décision du ministre de
--    l'Intérieur de ce pays, acceptée d'office au bout de 7 jours si le ministre est PNJ ou vacant
-- ---------------------------------------------------------------------------------------------
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'demander_naturalisation', 2, 50
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'demander_naturalisation' AND pa = 2 AND cost = 50);
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'changer_domicile', 1, 50
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'changer_domicile' AND pa = 1 AND cost = 50);

CREATE OR REPLACE FUNCTION public.naturalisation_appliquer_interne(p_nom text, p_pays text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_ancien text; o record; d jsonb; v_reste int; v_succ text; n_partis int := 0;
BEGIN
  SELECT coalesce(nationalite, country) INTO v_ancien FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF v_ancien IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_ancien = p_pays THEN RETURN jsonb_build_object('ok', true, 'deja', true); END IF;
  -- Perte de tout poste et de tout mandat dans l'ancien pays.
  DELETE FROM public.postes_attribues WHERE titulaire = p_nom;
  PERFORM set_config('hg.nationalite_serveur', 'on', true);
  UPDATE public.personnages_donnees SET nationalite = p_pays, poste = NULL, poste_depute = NULL WHERE name = p_nom;
  PERFORM set_config('hg.nationalite_serveur', 'off', true);
  -- Perte de l'appartenance à un parti de l'ancien pays (le chef passe la main au plus ancien membre).
  FOR o IN SELECT id, data::jsonb AS d FROM public.organisations
            WHERE data IS JSON OBJECT AND data::jsonb->>'type' = 'politique'
              AND coalesce(data::jsonb->>'country', country_origine) = v_ancien
              AND (data::jsonb->>'chef' = p_nom OR EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(data::jsonb->'membres', '[]')) m WHERE m->>'nom' = p_nom))
            FOR UPDATE LOOP
    d := jsonb_set(o.d, '{membres}', coalesce((SELECT jsonb_agg(m) FROM jsonb_array_elements(coalesce(o.d->'membres', '[]')) m WHERE m->>'nom' IS DISTINCT FROM p_nom), '[]'));
    SELECT count(*) INTO v_reste FROM jsonb_array_elements(d->'membres');
    IF v_reste = 0 THEN
      DELETE FROM public.organisations WHERE id = o.id;
    ELSE
      IF d->>'chef' = p_nom THEN
        SELECT m->>'nom' INTO v_succ FROM jsonb_array_elements(d->'membres') WITH ORDINALITY e(m, i)
         ORDER BY coalesce((m->>'rejointLe')::integer, 2147483647), i LIMIT 1;
        d := d || jsonb_build_object('chef', v_succ);
      END IF;
      UPDATE public.organisations SET data = d::text WHERE id = o.id;
    END IF;
    n_partis := n_partis + 1;
  END LOOP;
  PERFORM public.mail_systeme_poser_interne('Service de l''Immigration', p_nom, 'Naturalisation effective',
    'Votre naturalisation est effective. Vous perdez tout poste, tout mandat et votre appartenance à un parti dans votre ancien pays.', NULL);
  RETURN jsonb_build_object('ok', true, 'ancien', v_ancien, 'nationalite', p_pays, 'partis_quittes', n_partis);
END $$;
REVOKE ALL ON FUNCTION public.naturalisation_appliquer_interne(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.naturalisation_demander(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; v_nat text; v_pays text; v_paie jsonb; v_id text;
        v_min text; v_ms bigint := floor(extract(epoch FROM clock_timestamp()) * 1000);
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, coalesce(nationalite, country) AS nat
    INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  v_pays := p.country; v_nat := p.nat;
  -- À l'accueil d'une mairie du pays visé (n'importe laquelle, quel que soit le domicile).
  IF NOT ((p.current_building = 'mairie-capitale' AND p.current_city = 'capitale') OR (p.current_building = 'mairie' AND p.current_city <> 'capitale')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mairie_requise');
  END IF;
  IF v_pays = v_nat THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_citoyen'); END IF;
  IF EXISTS (SELECT 1 FROM public.demandes_naturalisation WHERE demandeur = a AND coalesce(statut, 'pending') = 'pending') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_en_cours');
  END IF;
  v_paie := public.payer_ordre_interne(a, 'demander_naturalisation', 2, 50);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_id := 'natu-' || v_ms || '-' || substr(md5(a || p_requete::text), 1, 6);
  INSERT INTO public.demandes_naturalisation (id, demandeur, pays_origine, pays_vise, montant, date_demande, date_traitement_possible, statut)
  VALUES (v_id, a, v_nat, v_pays, 50, v_ms, v_ms + 48 * 3600 * 1000, 'pending');
  SELECT titulaire INTO v_min FROM public.postes_attribues WHERE country = v_pays AND poste_id = 'min_int' AND city IS NULL LIMIT 1;
  IF v_min IS NOT NULL THEN
    PERFORM public.mail_systeme_poser_interne('Service de l''Immigration', v_min, 'Demande de naturalisation',
      a || ' demande la naturalisation. Vous pouvez traiter sa demande depuis votre bureau (« Demandes de naturalisation »), 48 h après le dépôt.', NULL);
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'pays_vise', v_pays, 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
END $$;
REVOKE ALL ON FUNCTION public.naturalisation_demander(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.naturalisation_demander(uuid) TO authenticated;

DO $traiter$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.naturalisation_traiter(text,boolean)'::regprocedure);
  IF position('naturalisation_appliquer_interne' IN d) > 0 THEN RETURN; END IF;
  -- Le pays du ministre est sa nationalité (un ministre en voyage reste compétent).
  a := 'SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;';
  b := 'SELECT coalesce(nationalite, country) INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'naturalisation_traiter : ancrage pays'; END IF;
  d := replace(d, a, b);
  a := E'    UPDATE public.demandes_naturalisation SET statut = ''acceptee'' WHERE id = p_demande_id;\n';
  b := a || E'    PERFORM public.naturalisation_appliquer_interne(v_d.demandeur, v_d.pays_vise);\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'naturalisation_traiter : ancrage acceptation'; END IF;
  EXECUTE replace(d, a, b);
END $traiter$;

-- Ministre PNJ ou poste vacant : acceptée d'office au bout de 7 jours (si un PJ est nommé entre-temps,
-- il reprend la main). Passe de nuit (tâche « naturalisations »).
CREATE OR REPLACE FUNCTION public.naturalisations_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; n int := 0; v_ms bigint := floor(extract(epoch FROM now()) * 1000);
BEGIN
  FOR r IN SELECT * FROM public.demandes_naturalisation
            WHERE coalesce(statut, 'pending') = 'pending' AND date_demande IS NOT NULL
              AND v_ms - date_demande >= 7 * 86400 * 1000
              AND NOT EXISTS (SELECT 1 FROM public.postes_attribues pa JOIN public.personnages_donnees x ON x.name = pa.titulaire
                               WHERE pa.country = demandes_naturalisation.pays_vise AND pa.poste_id = 'min_int' AND pa.city IS NULL)
            FOR UPDATE LOOP
    UPDATE public.demandes_naturalisation SET statut = 'acceptee' WHERE id = r.id;
    PERFORM public.naturalisation_appliquer_interne(r.demandeur, r.pays_vise);
    n := n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'acceptees_d_office', n);
END $$;
REVOKE ALL ON FUNCTION public.naturalisations_passe() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.naturalisations_passe() TO service_role;

-- ---------------------------------------------------------------------------------------------
-- 9. Domiciliation : 1 PA et 50 dans la monnaie du pays de la ville, automatique (au lieu de 200)
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.domicile_changer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE
  v_nom text := public.mon_personnage();
  v_pays text; v_ville text; v_ancien jsonb; v_jour integer; v_paie jsonb; r record;
BEGIN
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT d.country, d.current_city, d.domicile, coalesce(d.day, 1)
    INTO v_pays, v_ville, v_ancien, v_jour
    FROM public.personnages_donnees d WHERE d.name = v_nom FOR UPDATE;
  IF v_ville IS NULL OR v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_inconnue');
  END IF;
  IF v_ancien ->> 'country' = v_pays AND v_ancien ->> 'city' = v_ville THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_domicilie');
  END IF;
  v_paie := public.payer_ordre_interne(v_nom, 'changer_domicile', 1, 50);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.personnages_donnees
     SET domicile = jsonb_build_object('country', v_pays, 'city', v_ville, 'depuis', v_jour)
   WHERE name = v_nom;
  SELECT d.domicile, d.liquide, d.arg, d.pa INTO r FROM public.personnages_donnees d WHERE d.name = v_nom;
  RETURN jsonb_build_object('ok', true, 'cout', 50, 'pa_cout', 1, 'ancien', v_ancien,
                            'domicile', r.domicile, 'liquide', r.liquide, 'arg', r.arg, 'pa', r.pa);
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- 10. Contrôles
-- ---------------------------------------------------------------------------------------------
DO $post$
BEGIN
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE nationalite IS NULL) THEN
    RAISE EXCEPTION 'nationalite : personnages sans nationalité';
  END IF;
  IF position('candidature_refus_nationalite_interne' IN pg_get_functiondef('public.candidature_deposer(text,text,numeric,jsonb)'::regprocedure)) = 0
     OR position('nationalite_requise' IN pg_get_functiondef('public.election_voter(text,text,text,text)'::regprocedure)) = 0
     OR position('sovarka_parti_investir_interne' IN pg_get_functiondef('public.sovarka_parti_commande(uuid,text,text,jsonb)'::regprocedure)) = 0
     OR position('naturalisation_appliquer_interne' IN pg_get_functiondef('public.naturalisation_traiter(text,boolean)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'nationalite : raccords absents'; END IF;
END $post$;

NOTIFY pgrst, 'reload schema';
COMMIT;
