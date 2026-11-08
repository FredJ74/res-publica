-- POUVOIR EN SOVARKA, MINISTÈRES (décisions de Fred du 08/11/2026, GAME-DESIGN-NOVOMIRSK.md,
-- « Organisation du pouvoir en Sovarka »).
--
--  * Lois : déposées par les partis (le chef, depuis la salle des partis, 1 PA) ; le Président du
--    Conseil du Peuple tranche seul ; acceptée, la loi est promulguée aussitôt (adoptée ET appliquée),
--    puis « approuvée » par les députés, convoqués par mail chaque jeudi en Salle du Conseil du Peuple
--    (Approuver / S'abstenir ; l'abstention coûte 5 POP au parti et vaut un signalement à la cellule
--    du Capitaine Balatov). Indemnité de député 250 PSK/jour, perdue pour toute la semaine en cas
--    d'absence le jeudi.
--  * Manifestations : seulement de soutien, organisées par un parti, +1 POP au parti au pouvoir par
--    participant (rien pour l'organisateur). Pas de manifestation spontanée en Sovarka (les places du
--    circuit spontané n'existent qu'en Républia : manif_spontanee_place_interne).
--  * Fiscalité : 10 % sur les ventes, 10 % sur la main-d'œuvre, 10 % sur les recettes municipales,
--    au profit de l'État ; pas de taxe locale (les mairies vivent des loyers) ; taux modifiables par
--    le ministre de l'Économie collective (bornes de Républia, 0-40). Préemption retirée.
--  * Justice : seul le ministre de la Justice prolétarienne saisit le juge pour retirer un droit
--    d'exploiter ; juge PNJ = retrait automatique ; juge PJ = décision libre.
--  * Vérité officielle : censure sans risque ; sondage réel (popularité des partis), publié, enterré
--    ou faussé ; un sondage faussé peut être démasqué par une fuite aux Archives (−10 POP au ministre).
--  * Défense : conscription déclenchée et levée par le ministre ; convocation par mail, 48 h pour se
--    présenter à la caserne, sinon réfractaire et recherché ; service jusqu'à la levée.
--  * Président du Conseil : vote de confiance retiré, remplacé par l'autocritique publique
--    (ministre −5 POP, Président du Conseil +2 POP, une par ministre et par semaine).

-- ============================================================================ 0. Statut « examen »
ALTER TABLE public.assemblee_propositions DROP CONSTRAINT IF EXISTS assemblee_prop_statut_valide;
ALTER TABLE public.assemblee_propositions ADD CONSTRAINT assemblee_prop_statut_valide
  CHECK (statut = ANY (ARRAY['debat','session','adoptee','rejetee','renvoyee','retiree','abrogee','examen']));

-- ============================================================================ 1. Tables
CREATE TABLE IF NOT EXISTS public.sovarka_seances (
  jour date NOT NULL, depute text NOT NULL, emarge_ts timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (jour, depute));
CREATE TABLE IF NOT EXISTS public.sovarka_approbations (
  loi_id text NOT NULL REFERENCES public.assemblee_propositions(id) ON DELETE CASCADE,
  depute text NOT NULL, choix text NOT NULL CHECK (choix IN ('APPROUVE','ABSTENTION')),
  jour date NOT NULL, parti text, ts timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (loi_id, depute));
CREATE TABLE IF NOT EXISTS public.sovarka_signalements (
  id bigserial PRIMARY KEY, ts timestamptz NOT NULL DEFAULT now(), cible text NOT NULL, parti text,
  motif text NOT NULL, details jsonb NOT NULL DEFAULT '{}'::jsonb);
CREATE TABLE IF NOT EXISTS public.sovarka_indemnites (
  depute text PRIMARY KEY, suspendu_jusqu_au date NOT NULL, motif text);
CREATE TABLE IF NOT EXISTS public.sovarka_sondages (
  id bigserial PRIMARY KEY, ts timestamptz NOT NULL DEFAULT now(), ministre text NOT NULL, sujet text NOT NULL,
  reels jsonb NOT NULL, statut text NOT NULL DEFAULT 'en_attente'
    CHECK (statut IN ('en_attente','publie','enterre','fausse')),
  publies jsonb, decide_ts timestamptz, revele_ts timestamptz, revele_par text);
CREATE TABLE IF NOT EXISTS public.sovarka_saisines (
  id bigserial PRIMARY KEY, ts timestamptz NOT NULL DEFAULT now(), ministre text NOT NULL,
  ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL, exploitant text, motif text NOT NULL,
  statut text NOT NULL DEFAULT 'en_attente' CHECK (statut IN ('en_attente','retire','rejete')),
  juge text, decide_ts timestamptz);
CREATE UNIQUE INDEX IF NOT EXISTS sovarka_saisines_une_en_attente
  ON public.sovarka_saisines (ville, batiment, piece) WHERE statut = 'en_attente';
CREATE TABLE IF NOT EXISTS public.sovarka_conscription (
  pays text PRIMARY KEY, active boolean NOT NULL DEFAULT false, depuis timestamptz, par text);
CREATE TABLE IF NOT EXISTS public.sovarka_conscrits (
  nom text PRIMARY KEY, convoque_ts timestamptz NOT NULL, presente_ts timestamptz,
  statut text NOT NULL CHECK (statut IN ('convoque','presente','refractaire','libere')));
CREATE TABLE IF NOT EXISTS public.sovarka_autocritiques (
  id bigserial PRIMARY KEY, ts timestamptz NOT NULL DEFAULT now(), pm text NOT NULL, ministre text NOT NULL,
  semaine text NOT NULL, UNIQUE (ministre, semaine));
CREATE TABLE IF NOT EXISTS public.sovarka_manifs (
  id bigserial PRIMARY KEY, ts timestamptz NOT NULL DEFAULT now(), ville text NOT NULL, jour date NOT NULL,
  parti text NOT NULL, beneficiaire text, chef text NOT NULL, participants text[] NOT NULL, effet integer NOT NULL,
  UNIQUE (ville, jour));

DO $rls$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['sovarka_seances','sovarka_approbations','sovarka_signalements','sovarka_indemnites',
    'sovarka_sondages','sovarka_saisines','sovarka_conscription','sovarka_conscrits','sovarka_autocritiques','sovarka_manifs'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated', t);
  END LOOP;
END $rls$;
REVOKE ALL ON SEQUENCE public.sovarka_signalements_id_seq, public.sovarka_sondages_id_seq,
  public.sovarka_saisines_id_seq, public.sovarka_autocritiques_id_seq, public.sovarka_manifs_id_seq
  FROM PUBLIC, anon, authenticated;

-- ============================================================================ 2. Coûts et mécanismes
INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, x.pa, x.cost FROM (VALUES ('sovarka_loi_deposer', 1, 0), ('sovarka_saisir_juge', 1, 0),
  ('sovarka_autocritique', 1, 0), ('sovarka_manif_soutien', 1, 0)) AS x(fn, pa, cost)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn);

INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note)
SELECT x.m, x.s, x.n FROM (VALUES
  ('sovarka_convocation_deputes', true, 'Mail de convocation du jeudi aux députés de Sovarka ; un rejeu renverrait le mail.'),
  ('sovarka_absence_depute', false, 'Suspension de l''indemnité d''un député absent le jeudi ; un rejeu renverrait le mail d''avis.'),
  ('sovarka_indemnite_depute', false, 'Indemnité quotidienne (250 PSK) d''un député de Sovarka ; un rejeu la verserait deux fois.')
) AS x(m, s, n)
WHERE NOT EXISTS (SELECT 1 FROM public.actes_nocturnes_mecanismes a WHERE a.mecanisme = x.m);

UPDATE public.budgets_nationaux
   SET data = (coalesce(data, '{}'::jsonb) || jsonb_build_object('tauxNational', 10))
              || jsonb_build_object('tauxMainOeuvre', coalesce((data->>'tauxMainOeuvre')::numeric, 10),
                                    'tauxMunicipal', coalesce((data->>'tauxMunicipal')::numeric, 10)),
       updated_at = now()
 WHERE id = 'soviet';

INSERT INTO public.sovarka_conscription (pays, active) VALUES ('soviet', false) ON CONFLICT (pays) DO NOTHING;

-- ============================================================================ 3. Aides
-- Impôt d'État de Sovarka sur un montant (main-d'œuvre ou recettes municipales) : versé au Trésor
-- (reserveJour), rend le montant prélevé.
CREATE OR REPLACE FUNCTION public.sovarka_impot_interne(p_montant numeric, p_cle text)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nat jsonb; v_t numeric; v_i numeric;
BEGIN
  IF p_montant IS NULL OR p_montant <= 0 OR p_cle NOT IN ('tauxMainOeuvre', 'tauxMunicipal') THEN RETURN 0; END IF;
  SELECT data INTO v_nat FROM public.budgets_nationaux WHERE id = 'soviet' FOR UPDATE;
  IF v_nat IS NULL THEN RETURN 0; END IF;
  v_t := least(40, greatest(0, coalesce((v_nat->>p_cle)::numeric, 10)));
  v_i := least(p_montant, greatest(0, round(p_montant * v_t / 100)));
  IF v_i > 0 THEN
    UPDATE public.budgets_nationaux
       SET data = jsonb_set(v_nat, '{reserveJour}', to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0) + v_i)),
           updated_at = now()
     WHERE id = 'soviet';
  END IF;
  RETURN v_i;
END $$;
CREATE OR REPLACE FUNCTION public.sovarka_impot_main_oeuvre_interne(p_montant numeric, p_pays text)
RETURNS numeric LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_pays = 'soviet' THEN public.sovarka_impot_interne(p_montant, 'tauxMainOeuvre') ELSE 0 END $$;
CREATE OR REPLACE FUNCTION public.sovarka_impot_municipal_interne(p_montant numeric)
RETURNS numeric LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.sovarka_impot_interne(p_montant, 'tauxMunicipal') $$;

-- Président du Conseil du Peuple en exercice, et ministres de Sovarka en exercice.
CREATE OR REPLACE FUNCTION public.sovarka_titulaire_interne(p_poste text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT a.titulaire FROM public.postes_attribues a
    JOIN public.personnages_donnees d ON d.name = a.titulaire AND d.poste->>'id' = a.poste_id
   WHERE a.country = 'soviet' AND a.poste_id = p_poste
   ORDER BY a.updated_at DESC NULLS LAST LIMIT 1 $$;
CREATE OR REPLACE FUNCTION public.sovarka_est_titulaire_interne(p_nom text, p_poste text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.postes_attribues a
    JOIN public.personnages_donnees d ON d.name = a.titulaire AND d.poste->>'id' = a.poste_id
   WHERE a.country = 'soviet' AND a.poste_id = p_poste AND a.titulaire = p_nom) $$;

-- Parti au pouvoir : celui du Président du Conseil, à défaut le vainqueur de la semaine à la gloire.
CREATE OR REPLACE FUNCTION public.sovarka_parti_au_pouvoir()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(public.sovarka_parti_de(public.sovarka_titulaire_interne('pm')), public.sovarka_gloire_vainqueur()) $$;

CREATE OR REPLACE FUNCTION public.sovarka_parti_pop_interne(p_parti text, p_delta numeric)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d jsonb; v numeric;
BEGIN
  IF p_parti IS NULL THEN RETURN NULL; END IF;
  SELECT data::jsonb INTO d FROM public.organisations WHERE id = p_parti FOR UPDATE;
  IF d IS NULL OR NOT public.sovarka_est_parti_interne(d) THEN RETURN NULL; END IF;
  v := least(100, greatest(0, coalesce((d->>'pop')::numeric, 0) + p_delta));
  UPDATE public.organisations SET data = jsonb_set(d, '{pop}', to_jsonb(v))::text WHERE id = p_parti;
  RETURN v;
END $$;

-- Députés de Sovarka en exercice.
CREATE OR REPLACE FUNCTION public.sovarka_deputes_interne()
RETURNS SETOF text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT name FROM public.personnages_donnees
   WHERE jsonb_typeof(poste_depute) = 'object' AND poste_depute->>'country' = 'soviet' ORDER BY name $$;

-- Jour de Paris, jeudi de la séance courante (jeudi d'aujourd'hui, ou le dernier passé).
CREATE OR REPLACE FUNCTION public.sovarka_jour_paris()
RETURNS date LANGUAGE sql STABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT (now() AT TIME ZONE 'Europe/Paris')::date $$;

-- Ordre du jour d'une séance du jeudi : les lois de Sovarka promulguées dans les sept jours.
CREATE OR REPLACE FUNCTION public.sovarka_ordre_du_jour(p_jeudi date)
RETURNS SETOF public.assemblee_propositions LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT * FROM public.assemblee_propositions
   WHERE country = 'soviet' AND coalesce((data->>'sovarka')::boolean, false)
     AND statut IN ('adoptee', 'abrogee') AND adoptee_ts IS NOT NULL
     AND (adoptee_ts AT TIME ZONE 'Europe/Paris')::date BETWEEN p_jeudi - 6 AND p_jeudi
   ORDER BY adoptee_ts $$;

DO $rev$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['sovarka_impot_interne(numeric,text)','sovarka_impot_main_oeuvre_interne(numeric,text)',
    'sovarka_impot_municipal_interne(numeric)','sovarka_titulaire_interne(text)','sovarka_est_titulaire_interne(text,text)',
    'sovarka_parti_au_pouvoir()','sovarka_parti_pop_interne(text,numeric)','sovarka_deputes_interne()',
    'sovarka_ordre_du_jour(date)','sovarka_jour_paris()'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
  END LOOP;
END $rev$;

-- ============================================================================ 4. Lecture
CREATE OR REPLACE FUNCTION public.sovarka_pouvoir_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p record; v_parti text; v_chef boolean; v_jour date := public.sovarka_jour_paris();
  v_jeudi date; v_out jsonb; v_depute boolean; v_juge_villes jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room, poste INTO p FROM public.personnages_donnees WHERE name = a;
  v_parti := public.sovarka_parti_de(a);
  v_chef := v_parti IS NOT NULL AND EXISTS (SELECT 1 FROM public.organisations WHERE id = v_parti AND data::jsonb->>'chef' = a);
  v_depute := EXISTS (SELECT 1 FROM public.sovarka_deputes_interne() d WHERE d = a);
  v_jeudi := v_jour - ((extract(isodow FROM v_jour)::int - 4 + 7) % 7);
  SELECT coalesce(jsonb_agg(v), '[]'::jsonb) INTO v_juge_villes FROM unnest(ARRAY['capitale','ville_a','ville_b']) v
   WHERE public.justice_juge_titulaire('soviet', v) = a;

  v_out := jsonb_build_object('ok', true, 'jour', v_jour, 'jeudi', extract(isodow FROM v_jour) = 4, 'jeudi_seance', v_jeudi,
    'parti', v_parti, 'chef_parti', v_chef, 'parti_au_pouvoir', public.sovarka_parti_au_pouvoir(),
    'parti_au_pouvoir_nom', (SELECT data::jsonb->>'nom' FROM public.organisations WHERE id = public.sovarka_parti_au_pouvoir()),
    'pm', public.sovarka_est_titulaire_interne(a, 'pm'),
    'postes', (SELECT coalesce(jsonb_agg(x), '[]'::jsonb) FROM unnest(ARRAY['min_int','min_fin','min_just','min_def','min_info','min_ae']) x
               WHERE public.sovarka_est_titulaire_interne(a, x)),
    'depute', v_depute, 'juge_villes', v_juge_villes,
    'emarge', EXISTS (SELECT 1 FROM public.sovarka_seances WHERE jour = v_jour AND depute = a),
    'indemnite_suspendue_jusqu_au', (SELECT suspendu_jusqu_au FROM public.sovarka_indemnites WHERE depute = a AND suspendu_jusqu_au >= v_jour),
    'conscription', (SELECT jsonb_build_object('active', active, 'depuis', depuis) FROM public.sovarka_conscription WHERE pays = 'soviet'),
    'conscrit', (SELECT jsonb_build_object('statut', statut, 'convoque_ts', convoque_ts, 'echeance', convoque_ts + interval '48 hours')
                   FROM public.sovarka_conscrits WHERE nom = a));

  -- Lois de Sovarka : en examen (Président du Conseil et auteurs), et promulguées récentes.
  v_out := v_out || jsonb_build_object('lois', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'titre', l.titre, 'type', l.type,
      'categorie', l.categorie, 'texte', l.texte_original, 'statut', l.statut, 'auteur', l.auteur,
      'parti_nom', l.data->>'parti_nom', 'depose_ts', l.depose_ts, 'adoptee_ts', l.adoptee_ts) ORDER BY l.depose_ts DESC), '[]'::jsonb)
    FROM (SELECT * FROM public.assemblee_propositions WHERE country = 'soviet' AND coalesce((data->>'sovarka')::boolean, false)
           ORDER BY depose_ts DESC LIMIT 40) l));

  -- Séance : ordre du jour de ce jeudi (ou du dernier) et mes choix.
  v_out := v_out || jsonb_build_object('ordre_du_jour', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'titre', o.titre,
      'texte', o.texte_original, 'parti_nom', o.data->>'parti_nom', 'mon_choix',
      (SELECT choix FROM public.sovarka_approbations s WHERE s.loi_id = o.id AND s.depute = a),
      'approbations', (SELECT count(*) FROM public.sovarka_approbations s WHERE s.loi_id = o.id AND s.choix = 'APPROUVE'),
      'abstentions', (SELECT count(*) FROM public.sovarka_approbations s WHERE s.loi_id = o.id AND s.choix = 'ABSTENTION'))), '[]'::jsonb)
    FROM public.sovarka_ordre_du_jour(v_jeudi) o));

  IF public.sovarka_est_titulaire_interne(a, 'pm') THEN
    v_out := v_out || jsonb_build_object('ministres', (SELECT coalesce(jsonb_agg(jsonb_build_object('poste', x, 'nom', t,
        'autocritique_faite', EXISTS (SELECT 1 FROM public.sovarka_autocritiques WHERE ministre = t AND semaine = to_char(v_jour, 'IYYY-IW')))), '[]'::jsonb)
      FROM (SELECT x, public.sovarka_titulaire_interne(x) t FROM unnest(ARRAY['min_int','min_fin','min_just','min_def','min_info','min_ae']) x) m
      WHERE t IS NOT NULL));
  END IF;
  IF public.sovarka_est_titulaire_interne(a, 'min_info') THEN
    v_out := v_out || jsonb_build_object('sondages', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'ts', ts, 'sujet', sujet,
        'reels', reels, 'statut', statut, 'publies', publies) ORDER BY ts DESC), '[]'::jsonb)
      FROM (SELECT * FROM public.sovarka_sondages WHERE ministre = a ORDER BY ts DESC LIMIT 10) s));
  END IF;
  IF public.sovarka_est_titulaire_interne(a, 'min_just') OR jsonb_array_length(v_juge_villes) > 0 THEN
    v_out := v_out || jsonb_build_object('saisines', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'ts', ts, 'ville', ville,
        'batiment', batiment, 'piece', piece, 'exploitant', exploitant, 'motif', motif, 'statut', statut, 'juge', juge) ORDER BY ts DESC), '[]'::jsonb)
      FROM (SELECT * FROM public.sovarka_saisines
             WHERE ministre = a OR (statut = 'en_attente' AND v_juge_villes ? ville) ORDER BY ts DESC LIMIT 30) s));
  END IF;
  RETURN v_out;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_pouvoir_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_pouvoir_lire() TO authenticated;

-- ============================================================================ 5. Commandes
CREATE OR REPLACE FUNCTION public.sovarka_pouvoir_commande(p_requete uuid, p_action text, p_params jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE
  a text := public.mon_personnage(); act text := 'sovarka:pouvoir'; par jsonb; v jsonb; dt text; p record;
  v_paie jsonb; v_parti text; d jsonb; v_id text; v_titre text; v_texte text; v_type text; v_cat text := NULL;
  v_cible text := NULL; v_portee jsonb := NULL; v_vp jsonb; l public.assemblee_propositions; v_jour date := public.sovarka_jour_paris();
  v_n integer; v_noms text[]; v_beneficiaire text; v_reels jsonb; s public.sovarka_sondages; v_publies jsonb;
  v_ministre text; v_contenu text; v_juge text; v_exploitant text; sz public.sovarka_saisines; v_ville text;
  v_pop numeric; v_pm text; v_deps text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  p_params := coalesce(p_params, '{}'::jsonb);
  par := jsonb_build_object('action', p_action, 'params', p_params);
  v := public.achat_requete_ouvrir_interne(a, p_requete, act, par);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    SELECT name, country, current_city, current_building, current_room INTO p
      FROM public.personnages_donnees WHERE name = a FOR UPDATE;
    v_parti := public.sovarka_parti_de(a);

    IF p.country IS DISTINCT FROM 'soviet' THEN
      v := jsonb_build_object('ok', false, 'raison', 'reserve_a_sovarka');

    -- ------------------------------------------------------------------ Lois : dépôt par le chef de parti
    ELSIF p_action = 'loi_deposer' THEN
      SELECT data::jsonb INTO d FROM public.organisations WHERE id = v_parti;
      v_type := p_params->>'type';
      v_texte := btrim(coalesce(p_params->>'texte', ''));
      v_titre := btrim(coalesce(p_params->>'titre', ''));
      IF d IS NULL OR d->>'chef' IS DISTINCT FROM a THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_chef_de_parti');
      ELSIF NOT (p.current_room = 'salle_partis' AND ((p.current_city = 'capitale' AND p.current_building = 'mairie-capitale')
                 OR (p.current_city IN ('ville_a', 'ville_b') AND p.current_building = 'mairie'))) THEN
        v := jsonb_build_object('ok', false, 'raison', 'salle_des_partis_requise');
      ELSIF v_type IS NULL OR v_type NOT IN ('rp', 'mecanique', 'abrogation') THEN v := jsonb_build_object('ok', false, 'raison', 'type_invalide');
      ELSIF v_texte = '' THEN v := jsonb_build_object('ok', false, 'raison', 'champs_requis');
      ELSIF length(v_texte) > 20000 THEN v := jsonb_build_object('ok', false, 'raison', 'texte_trop_long');
      ELSE
        IF v_type = 'abrogation' THEN
          SELECT * INTO l FROM public.assemblee_propositions
           WHERE id = p_params->>'loi_cible' AND statut = 'adoptee' AND country = 'soviet';
          IF NOT FOUND THEN v := jsonb_build_object('ok', false, 'raison', 'loi_cible_introuvable');
          ELSE v_cible := l.id; v_titre := left('Abrogation — ' || l.titre, 200); END IF;
        ELSIF v_titre = '' THEN v := jsonb_build_object('ok', false, 'raison', 'champs_requis');
        ELSIF length(v_titre) > 120 THEN v := jsonb_build_object('ok', false, 'raison', 'titre_trop_long');
        ELSIF v_type = 'mecanique' THEN
          IF NOT EXISTS (SELECT 1 FROM public.assemblee_categories_interdiction WHERE categorie = p_params->>'categorie') THEN
            v := jsonb_build_object('ok', false, 'raison', 'categorie_invalide');
          ELSE
            v_cat := p_params->>'categorie';
            IF p_params ? 'portee' AND jsonb_typeof(p_params->'portee') = 'object' THEN
              v_vp := public.assemblee_portee_valider(p_params->'portee');
              IF NOT coalesce((v_vp->>'ok')::boolean, false) THEN v := v_vp; ELSE v_portee := v_vp->'portee'; END IF;
            END IF;
          END IF;
        END IF;
        IF v IS NULL THEN
          v_paie := public.payer_ordre_interne(a, 'sovarka_loi_deposer', 1, 0);
          IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
          ELSE
            v_id := 'prop-' || (extract(epoch FROM clock_timestamp()) * 1000)::bigint || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);
            INSERT INTO public.assemblee_propositions (id, country, auteur, titre, type, categorie, loi_cible_id, texte_original,
                   statut, eligible_session_ts, data)
            VALUES (v_id, 'soviet', a, v_titre, v_type, v_cat, v_cible, v_texte, 'examen', now(),
                    jsonb_build_object('sovarka', true, 'parti', v_parti, 'parti_nom', d->>'nom')
                    || CASE WHEN v_portee IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('portee', v_portee) END);
            v_pm := public.sovarka_titulaire_interne('pm');
            IF v_pm IS NOT NULL THEN
              PERFORM public.mail_systeme_poser_interne('Secrétariat du Conseil du Peuple', v_pm, 'Projet de loi à trancher : ' || v_titre,
                'Le parti « ' || (d->>'nom') || ' » dépose un projet de loi. Vous le tranchez seul, depuis votre bureau du Palais du Gouvernement.', NULL);
            END IF;
            v := jsonb_build_object('ok', true, 'action', p_action, 'loi', v_id, 'titre', v_titre,
                   'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
          END IF;
        END IF;
      END IF;

    -- ------------------------------------------------------------------ Lois : le Président du Conseil tranche seul
    ELSIF p_action = 'loi_trancher' THEN
      SELECT * INTO l FROM public.assemblee_propositions WHERE id = p_params->>'loi' FOR UPDATE;
      IF NOT public.sovarka_est_titulaire_interne(a, 'pm') THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_president_du_conseil');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureaux') THEN
        v := jsonb_build_object('ok', false, 'raison', 'bureau_du_president_du_conseil_requis');
      ELSIF l.id IS NULL OR l.country IS DISTINCT FROM 'soviet' OR l.statut <> 'examen' THEN v := jsonb_build_object('ok', false, 'raison', 'projet_introuvable');
      ELSIF jsonb_typeof(p_params->'accepter') IS DISTINCT FROM 'boolean' THEN v := jsonb_build_object('ok', false, 'raison', 'champs_requis');
      ELSIF (p_params->>'accepter')::boolean THEN
        UPDATE public.assemblee_propositions SET statut = 'adoptee', adoptee_ts = now(), appliquee_ts = now(), appliquee_par = a
         WHERE id = l.id;
        IF l.type = 'abrogation' AND l.loi_cible_id IS NOT NULL THEN
          UPDATE public.assemblee_propositions SET statut = 'abrogee', abrogee_ts = now()
           WHERE id = l.loi_cible_id AND statut = 'adoptee' AND country = 'soviet';
        END IF;
        PERFORM public.mail_systeme_poser_interne('Conseil du Peuple', l.auteur, 'Loi promulguée : ' || l.titre,
          'Le Président du Conseil du Peuple a accepté votre projet. La loi est promulguée et s''applique dès maintenant ; '
          || 'les députés l''approuveront jeudi.', NULL);
        PERFORM public.annonce_publique_interne('soviet', '📜 Loi promulguée par le Président du Conseil du Peuple : ' || l.titre || '.');
        v := jsonb_build_object('ok', true, 'action', p_action, 'loi', l.id, 'titre', l.titre, 'statut', 'adoptee');
      ELSE
        UPDATE public.assemblee_propositions SET statut = 'rejetee' WHERE id = l.id;
        PERFORM public.mail_systeme_poser_interne('Conseil du Peuple', l.auteur, 'Projet de loi refusé : ' || l.titre,
          'Le Président du Conseil du Peuple a refusé votre projet de loi.', NULL);
        v := jsonb_build_object('ok', true, 'action', p_action, 'loi', l.id, 'titre', l.titre, 'statut', 'rejetee');
      END IF;

    -- ------------------------------------------------------------------ Séance du jeudi : émarger, approuver
    ELSIF p_action IN ('seance_emarger', 'loi_approuver') THEN
      IF NOT EXISTS (SELECT 1 FROM public.sovarka_deputes_interne() x WHERE x = a) THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_depute');
      ELSIF extract(isodow FROM v_jour) <> 4 THEN v := jsonb_build_object('ok', false, 'raison', 'seance_le_jeudi');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'salle_conseil') THEN
        v := jsonb_build_object('ok', false, 'raison', 'salle_du_conseil_requise');
      ELSIF p_action = 'seance_emarger' THEN
        INSERT INTO public.sovarka_seances (jour, depute) VALUES (v_jour, a) ON CONFLICT DO NOTHING;
        v := jsonb_build_object('ok', true, 'action', p_action, 'jour', v_jour);
      ELSIF NOT EXISTS (SELECT 1 FROM public.sovarka_seances WHERE jour = v_jour AND depute = a) THEN
        v := jsonb_build_object('ok', false, 'raison', 'emargement_requis');
      ELSIF coalesce(p_params->>'choix', '') NOT IN ('APPROUVE', 'ABSTENTION') THEN v := jsonb_build_object('ok', false, 'raison', 'choix_invalide');
      ELSIF NOT EXISTS (SELECT 1 FROM public.sovarka_ordre_du_jour(v_jour) o WHERE o.id = p_params->>'loi') THEN
        v := jsonb_build_object('ok', false, 'raison', 'hors_ordre_du_jour');
      ELSIF EXISTS (SELECT 1 FROM public.sovarka_approbations WHERE loi_id = p_params->>'loi' AND depute = a) THEN
        v := jsonb_build_object('ok', false, 'raison', 'deja_vote');
      ELSE
        INSERT INTO public.sovarka_approbations (loi_id, depute, choix, jour, parti)
        VALUES (p_params->>'loi', a, p_params->>'choix', v_jour, v_parti);
        IF p_params->>'choix' = 'ABSTENTION' THEN
          v_pop := public.sovarka_parti_pop_interne(v_parti, -5);
          INSERT INTO public.sovarka_signalements (cible, parti, motif, details)
          VALUES (a, v_parti, 'abstention', jsonb_build_object('loi', p_params->>'loi', 'jour', v_jour));
        END IF;
        v := jsonb_build_object('ok', true, 'action', p_action, 'choix', p_params->>'choix', 'pop_parti', v_pop);
      END IF;

    -- ------------------------------------------------------------------ Manifestation de soutien (un parti)
    ELSIF p_action = 'manif_soutien' THEN
      SELECT data::jsonb INTO d FROM public.organisations WHERE id = v_parti;
      v_beneficiaire := public.sovarka_parti_au_pouvoir();
      IF d IS NULL OR d->>'chef' IS DISTINCT FROM a THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_chef_de_parti');
      ELSIF v_beneficiaire IS NULL THEN v := jsonb_build_object('ok', false, 'raison', 'aucun_parti_au_pouvoir');
      ELSIF p.current_building IS NOT NULL OR p.current_city IS NULL THEN v := jsonb_build_object('ok', false, 'raison', 'dans_la_rue');
      ELSIF EXISTS (SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = a) THEN v := jsonb_build_object('ok', false, 'raison', 'pas_chef');
      ELSE
        PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:manif:' || p.current_city, 0));
        IF EXISTS (SELECT 1 FROM public.sovarka_manifs WHERE ville = p.current_city AND jour = v_jour) THEN
          v := jsonb_build_object('ok', false, 'raison', 'deja_aujourdhui');
        ELSE
          SELECT array_agg(x.name ORDER BY x.name) INTO v_noms FROM public.personnages_donnees x
           WHERE (x.name = a OR x.name IN (SELECT membre FROM public.groupes_pj_adhesions WHERE chef = a))
             AND x.country = 'soviet' AND x.current_city = p.current_city AND x.current_building IS NULL;
          v_n := coalesce(array_length(v_noms, 1), 0);
          IF v_n < 10 THEN v := jsonb_build_object('ok', false, 'raison', 'groupe_insuffisant', 'presents', v_n, 'minimum', 10);
          ELSE
            v_paie := public.payer_ordre_interne(a, 'sovarka_manif_soutien', 1, 0);
            IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
            ELSE
              v_pop := public.sovarka_parti_pop_interne(v_beneficiaire, v_n);
              INSERT INTO public.sovarka_manifs (ville, jour, parti, beneficiaire, chef, participants, effet)
              VALUES (p.current_city, v_jour, v_parti, v_beneficiaire, a, v_noms, v_n);
              PERFORM public.annonce_publique_interne('soviet', '📢 Manifestation de soutien du parti « ' || (d->>'nom') || ' » : '
                || v_n || ' manifestants acclament ' || coalesce((SELECT data::jsonb->>'nom' FROM public.organisations WHERE id = v_beneficiaire), 'le Parti') || '.');
              v := jsonb_build_object('ok', true, 'action', p_action, 'participants', v_n, 'pop_parti_au_pouvoir', v_pop,
                     'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
            END IF;
          END IF;
        END IF;
      END IF;

    -- ------------------------------------------------------------------ Vérité officielle : sondages
    ELSIF p_action = 'sondage_commander' THEN
      v_texte := btrim(coalesce(p_params->>'sujet', ''));
      IF NOT public.sovarka_est_titulaire_interne(a, 'min_info') THEN v := jsonb_build_object('ok', false, 'raison', 'poste_requis');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureau_min_info') THEN
        v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
      ELSIF length(v_texte) < 3 OR length(v_texte) > 200 THEN v := jsonb_build_object('ok', false, 'raison', 'sujet_invalide');
      ELSE
        v_paie := public.payer_ordre_interne(a, 'commanditer_sondage', 1, 200);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
        ELSE
          SELECT coalesce(jsonb_agg(jsonb_build_object('parti', o.id, 'nom', o.data::jsonb->>'nom',
                   'pop', coalesce((o.data::jsonb->>'pop')::numeric, 0)) ORDER BY coalesce((o.data::jsonb->>'pop')::numeric, 0) DESC), '[]'::jsonb)
            INTO v_reels FROM public.organisations o
           WHERE o.data IS JSON OBJECT AND public.sovarka_est_parti_interne(o.data::jsonb);
          INSERT INTO public.sovarka_sondages (ministre, sujet, reels) VALUES (a, v_texte, v_reels) RETURNING * INTO s;
          PERFORM public.jauges_effet_appliquer_interne(a, 0, 5, 0);
          v := jsonb_build_object('ok', true, 'action', p_action, 'sondage', s.id, 'reels', v_reels, 'gain_inf', 5,
                 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
        END IF;
      END IF;

    ELSIF p_action = 'sondage_decider' THEN
      SELECT * INTO s FROM public.sovarka_sondages WHERE id = (p_params->>'sondage')::bigint FOR UPDATE;
      IF s.id IS NULL OR s.ministre IS DISTINCT FROM a THEN v := jsonb_build_object('ok', false, 'raison', 'sondage_introuvable');
      ELSIF s.statut <> 'en_attente' THEN v := jsonb_build_object('ok', false, 'raison', 'deja_decide');
      ELSIF coalesce(p_params->>'choix', '') NOT IN ('publier', 'enterrer', 'fausser') THEN v := jsonb_build_object('ok', false, 'raison', 'choix_invalide');
      ELSIF p_params->>'choix' = 'enterrer' THEN
        UPDATE public.sovarka_sondages SET statut = 'enterre', decide_ts = now() WHERE id = s.id;
        v := jsonb_build_object('ok', true, 'action', p_action, 'statut', 'enterre');
      ELSE
        IF p_params->>'choix' = 'publier' THEN v_publies := s.reels;
        ELSE
          -- Les chiffres faussés : un par parti du sondage réel, de 0 à 100, rien d'autre.
          IF jsonb_typeof(p_params->'valeurs') IS DISTINCT FROM 'object' THEN v := jsonb_build_object('ok', false, 'raison', 'valeurs_requises');
          ELSE
            SELECT coalesce(jsonb_agg(r || jsonb_build_object('pop', least(100, greatest(0, round(coalesce((p_params->'valeurs'->>(r->>'parti'))::numeric, (r->>'pop')::numeric)))))
                     ORDER BY ord), '[]'::jsonb)
              INTO v_publies FROM jsonb_array_elements(s.reels) WITH ORDINALITY AS t(r, ord);
          END IF;
        END IF;
        IF v IS NULL THEN
          SELECT string_agg('• ' || (r->>'nom') || ' : ' || (r->>'pop') || ' %', E'\n') INTO v_contenu FROM jsonb_array_elements(v_publies) r;
          v_vp := public.forum_publication_jauges_interne(a, p_requete, jsonb_build_object('forum', 'national',
                    'titre', 'Sondage officiel — ' || s.sujet,
                    'contenu', 'Popularité des partis de Sovarka, selon le ministère de la Vérité officielle :' || E'\n' || coalesce(v_contenu, '(aucun parti)')));
          IF NOT coalesce((v_vp->>'ok')::boolean, false) THEN v := jsonb_build_object('ok', false, 'raison', 'publication_refusee');
          ELSE
            UPDATE public.sovarka_sondages SET statut = CASE WHEN p_params->>'choix' = 'publier' THEN 'publie' ELSE 'fausse' END,
                   publies = v_publies, decide_ts = now() WHERE id = s.id;
            v := jsonb_build_object('ok', true, 'action', p_action, 'statut', CASE WHEN p_params->>'choix' = 'publier' THEN 'publie' ELSE 'fausse' END);
          END IF;
        END IF;
      END IF;

    -- ------------------------------------------------------------------ Fuite aux Archives (sondage faussé)
    ELSIF p_action = 'fuite' THEN
      IF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'archives_gouv') THEN
        v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
      ELSIF (SELECT poste FROM public.personnages_donnees WHERE name = a) IS NULL THEN v := jsonb_build_object('ok', false, 'raison', 'poste_requis');
      ELSE
        v_paie := public.payer_ordre_interne(a, 'fuite_info', 3, 0);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
        ELSE
          SELECT * INTO s FROM public.sovarka_sondages WHERE statut = 'fausse' AND revele_ts IS NULL ORDER BY decide_ts DESC LIMIT 1 FOR UPDATE;
          IF s.id IS NULL THEN
            v := jsonb_build_object('ok', true, 'action', p_action, 'trouve', false,
                   'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
          ELSE
            SELECT string_agg('• ' || (r->>'nom') || ' : ' || (r->>'pop') || ' % (publié : '
                     || coalesce((SELECT q->>'pop' FROM jsonb_array_elements(s.publies) q WHERE q->>'parti' = r->>'parti'), '?') || ' %)', E'\n')
              INTO v_contenu FROM jsonb_array_elements(s.reels) r;
            v_vp := public.forum_publication_jauges_interne(a, p_requete, jsonb_build_object('forum', 'national',
                      'titre', 'Fuite — le sondage « ' || s.sujet || ' » était truqué',
                      'contenu', 'Les vrais chiffres, conservés aux Archives du gouvernement :' || E'\n' || coalesce(v_contenu, '')));
            IF NOT coalesce((v_vp->>'ok')::boolean, false) THEN v := jsonb_build_object('ok', false, 'raison', 'publication_refusee');
            ELSE
              UPDATE public.sovarka_sondages SET revele_ts = now(), revele_par = a WHERE id = s.id;
              PERFORM public.jauges_effet_appliquer_interne(s.ministre, -10, 0, 0);
              PERFORM public.crime_tracer_interne(a, 'fuite_info', 'Archives du gouvernement');
              PERFORM public.crime_detecter_interne(a, 'fuite_info', true, 'fuite_info');
              v := jsonb_build_object('ok', true, 'action', p_action, 'trouve', true, 'ministre', s.ministre,
                     'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg',
                     'recherche', (SELECT recherche FROM public.personnages_donnees WHERE name = a));
            END IF;
          END IF;
        END IF;
      END IF;

    -- ------------------------------------------------------------------ Justice : saisir le juge, décider
    ELSIF p_action = 'saisir_juge' THEN
      v_ville := p_params->>'ville';
      v_texte := btrim(coalesce(p_params->>'motif', ''));
      v_exploitant := public.sovarka_exploitant_interne(v_ville, p_params->>'batiment', p_params->>'piece');
      IF NOT public.sovarka_est_titulaire_interne(a, 'min_just') THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_ministre_justice');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureau_min_just') THEN
        v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
      ELSIF length(v_texte) < 3 OR length(v_texte) > 300 THEN v := jsonb_build_object('ok', false, 'raison', 'motif_invalide');
      ELSIF v_exploitant IS NULL THEN v := jsonb_build_object('ok', false, 'raison', 'local_non_exploite');
      ELSIF EXISTS (SELECT 1 FROM public.sovarka_saisines WHERE ville = v_ville AND batiment = p_params->>'batiment'
                      AND piece = p_params->>'piece' AND statut = 'en_attente') THEN
        v := jsonb_build_object('ok', false, 'raison', 'saisine_deja_en_cours');
      ELSE
        v_paie := public.payer_ordre_interne(a, 'sovarka_saisir_juge', 1, 0);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
        ELSE
          INSERT INTO public.sovarka_saisines (ministre, ville, batiment, piece, exploitant, motif)
          VALUES (a, v_ville, p_params->>'batiment', p_params->>'piece', v_exploitant, v_texte) RETURNING * INTO sz;
          v_juge := public.justice_juge_titulaire('soviet', v_ville);
          IF v_juge IS NULL THEN
            -- Juge PNJ : il donne toujours raison au ministre (décision de Fred, 08/11/2026).
            v := public.sovarka_droit_retour_etat_interne(v_ville, sz.batiment, sz.piece, 'tribunal', 'Juge du Tribunal Populaire', v_texte);
            IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = v::text; END IF;
            UPDATE public.sovarka_saisines SET statut = 'retire', juge = 'PNJ', decide_ts = now() WHERE id = sz.id;
            v := v || jsonb_build_object('ok', true, 'action', p_action, 'decision', 'retire', 'juge', 'PNJ');
          ELSE
            PERFORM public.mail_systeme_poser_interne('Ministère de la Justice prolétarienne', v_juge, 'Saisine : droit d''exploiter',
              'Le ministre de la Justice prolétarienne vous saisit : retrait du droit d''exploiter de ' || v_exploitant
              || '. Motif : ' || v_texte || '. Décidez au tribunal, bureau des magistrats.', NULL);
            v := jsonb_build_object('ok', true, 'action', p_action, 'decision', 'en_attente', 'juge', v_juge);
          END IF;
          v := v || jsonb_build_object('pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
        END IF;
      END IF;

    ELSIF p_action = 'juge_rejeter' THEN
      SELECT * INTO sz FROM public.sovarka_saisines WHERE id = (p_params->>'saisine')::bigint FOR UPDATE;
      IF sz.id IS NULL OR sz.statut <> 'en_attente' THEN v := jsonb_build_object('ok', false, 'raison', 'saisine_introuvable');
      ELSIF public.justice_juge_titulaire('soviet', sz.ville) IS DISTINCT FROM a THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_juge');
      ELSIF NOT (p.current_city = sz.ville AND p.current_building IN ('tribunal', 'tribunal-local')) THEN v := jsonb_build_object('ok', false, 'raison', 'pas_au_tribunal');
      ELSE
        UPDATE public.sovarka_saisines SET statut = 'rejete', juge = a, decide_ts = now() WHERE id = sz.id;
        PERFORM public.mail_systeme_poser_interne('Tribunal Populaire', sz.ministre, 'Saisine rejetée',
          'Le juge ' || a || ' refuse de retirer le droit d''exploiter de ' || coalesce(sz.exploitant, '?') || '.', NULL);
        v := jsonb_build_object('ok', true, 'action', p_action, 'decision', 'rejete');
      END IF;

    -- ------------------------------------------------------------------ Défense : conscription
    ELSIF p_action IN ('conscription_declencher', 'conscription_lever') THEN
      IF NOT public.sovarka_est_titulaire_interne(a, 'min_def') THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_ministre_defense');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureau_min_def') THEN
        v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
      ELSIF p_action = 'conscription_declencher' THEN
        IF (SELECT active FROM public.sovarka_conscription WHERE pays = 'soviet' FOR UPDATE) THEN
          v := jsonb_build_object('ok', false, 'raison', 'deja_active');
        ELSE
          UPDATE public.sovarka_conscription SET active = true, depuis = now(), par = a WHERE pays = 'soviet';
          SELECT array_agg(x.name) INTO v_noms FROM public.personnages_donnees x
           WHERE x.country = 'soviet' AND (x.poste IS NULL OR jsonb_typeof(x.poste) <> 'object' OR coalesce(x.poste->>'id', '') = '')
             AND (x.poste_depute IS NULL OR jsonb_typeof(x.poste_depute) <> 'object')
             AND public.militaire_grade_effectif(x.name) IS NULL;
          v_n := coalesce(array_length(v_noms, 1), 0);
          INSERT INTO public.sovarka_conscrits (nom, convoque_ts, statut)
          SELECT n, now(), 'convoque' FROM unnest(coalesce(v_noms, '{}'::text[])) n
          ON CONFLICT (nom) DO UPDATE SET convoque_ts = now(), presente_ts = NULL, statut = 'convoque';
          PERFORM public.mail_systeme_poser_interne('Ministère de la Défense de la Patrie', n, 'Ordre de conscription',
            'La Patrie vous appelle. Présentez-vous à la caserne centrale de Novomirsk dans les 48 heures (ordre « Se présenter (conscription) »). '
            || 'Passé ce délai, vous serez réfractaire et recherché. Le service dure jusqu''à la levée de la conscription.', NULL)
            FROM unnest(coalesce(v_noms, '{}'::text[])) n;
          PERFORM public.annonce_publique_interne('soviet', '🎖️ Conscription décrétée par le ministre de la Défense de la Patrie : ' || v_n || ' citoyens appelés.');
          v := jsonb_build_object('ok', true, 'action', p_action, 'appeles', v_n);
        END IF;
      ELSE
        IF NOT coalesce((SELECT active FROM public.sovarka_conscription WHERE pays = 'soviet' FOR UPDATE), false) THEN
          v := jsonb_build_object('ok', false, 'raison', 'pas_active');
        ELSE
          UPDATE public.sovarka_conscription SET active = false, depuis = NULL, par = a WHERE pays = 'soviet';
          v_n := 0;
          FOR v_deps IN SELECT nom FROM public.sovarka_conscrits WHERE statut IN ('convoque', 'presente', 'refractaire') LOOP
            -- Fin du service : retiré de sa section s'il y a été incorporé ; candidature en cours retirée ;
            -- l'avis de recherche du réfractaire tombe.
            UPDATE public.compagnies_militaires c
               SET data = jsonb_set(c.data, '{sections}', (SELECT coalesce(jsonb_agg(
                     CASE WHEN jsonb_typeof(sec->'soldats') = 'array' THEN jsonb_set(sec, '{soldats}', (SELECT coalesce(jsonb_agg(sol ORDER BY pos), '[]'::jsonb)
                       FROM jsonb_array_elements(sec->'soldats') WITH ORDINALITY t(sol, pos)
                      WHERE NOT (coalesce((sol->>'pj')::boolean, false) AND sol->>'nom' = v_deps))) ELSE sec END ORDER BY spos), '[]'::jsonb)
                     FROM jsonb_array_elements(c.data->'sections') WITH ORDINALITY s(sec, spos)))
             WHERE c.data->>'pays' = 'soviet' AND jsonb_typeof(c.data->'sections') = 'array'
               AND EXISTS (SELECT 1 FROM jsonb_array_elements(c.data->'sections') s2, jsonb_array_elements(coalesce(s2->'soldats', '[]'::jsonb)) so
                            WHERE coalesce((so->>'pj')::boolean, false) AND so->>'nom' = v_deps);
            IF FOUND THEN PERFORM public.militaire_service_fermer(v_deps, 'soldat'); END IF;
            UPDATE public.candidatures_militaires SET statut = 'retiree' WHERE candidat = v_deps AND statut = 'active';
            PERFORM set_config('rp.recherche_interne', 'on', true);
            UPDATE public.personnages_donnees
               SET recherche = (SELECT coalesce(jsonb_agg(e), '[]'::jsonb) FROM jsonb_array_elements(recherche) e WHERE e->>'acte' IS DISTINCT FROM 'refractaire')
             WHERE name = v_deps AND jsonb_typeof(recherche) = 'array';
            PERFORM set_config('rp.recherche_interne', '', true);
            PERFORM public.mail_systeme_poser_interne('Ministère de la Défense de la Patrie', v_deps, 'Conscription levée',
              'La conscription est levée : vous êtes libéré de vos obligations militaires.', NULL);
            v_n := v_n + 1;
          END LOOP;
          UPDATE public.sovarka_conscrits SET statut = 'libere' WHERE statut IN ('convoque', 'presente', 'refractaire');
          PERFORM public.annonce_publique_interne('soviet', '🎖️ La conscription est levée.');
          v := jsonb_build_object('ok', true, 'action', p_action, 'liberes', v_n);
        END IF;
      END IF;

    ELSIF p_action = 'conscrit_presenter' THEN
      IF NOT EXISTS (SELECT 1 FROM public.sovarka_conscrits WHERE nom = a AND statut IN ('convoque', 'refractaire')) THEN
        v := jsonb_build_object('ok', false, 'raison', 'pas_convoque');
      ELSIF p.current_building IS DISTINCT FROM 'caserne-militaire' THEN v := jsonb_build_object('ok', false, 'raison', 'pas_a_la_caserne');
      ELSE
        v := public.militaire_candidature_deposer('soldat');
        IF coalesce((v->>'ok')::boolean, false) IS TRUE OR v->>'raison' IN ('deja_militaire', 'candidature_deja_active') THEN
          UPDATE public.sovarka_conscrits SET statut = 'presente', presente_ts = now() WHERE nom = a;
          PERFORM set_config('rp.recherche_interne', 'on', true);
          UPDATE public.personnages_donnees
             SET recherche = (SELECT coalesce(jsonb_agg(e), '[]'::jsonb) FROM jsonb_array_elements(recherche) e WHERE e->>'acte' IS DISTINCT FROM 'refractaire')
           WHERE name = a AND jsonb_typeof(recherche) = 'array';
          PERFORM set_config('rp.recherche_interne', '', true);
          v := jsonb_build_object('ok', true, 'action', p_action, 'candidature', v->'id', 'pa', v->'pa',
                 'recherche', (SELECT recherche FROM public.personnages_donnees WHERE name = a));
        END IF;
      END IF;

    -- ------------------------------------------------------------------ Autocritique publique
    ELSIF p_action = 'autocritique' THEN
      v_ministre := p_params->>'ministre';
      IF NOT public.sovarka_est_titulaire_interne(a, 'pm') THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_president_du_conseil');
      ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureaux') THEN
        v := jsonb_build_object('ok', false, 'raison', 'bureau_du_president_du_conseil_requis');
      ELSIF NOT EXISTS (SELECT 1 FROM unnest(ARRAY['min_int','min_fin','min_just','min_def','min_info','min_ae']) x
                         WHERE public.sovarka_titulaire_interne(x) = v_ministre) THEN v := jsonb_build_object('ok', false, 'raison', 'pas_ministre');
      ELSIF EXISTS (SELECT 1 FROM public.sovarka_autocritiques WHERE ministre = v_ministre AND semaine = to_char(v_jour, 'IYYY-IW')) THEN
        v := jsonb_build_object('ok', false, 'raison', 'deja_cette_semaine');
      ELSE
        v_paie := public.payer_ordre_interne(a, 'sovarka_autocritique', 1, 0);
        IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
        ELSE
          INSERT INTO public.sovarka_autocritiques (pm, ministre, semaine) VALUES (a, v_ministre, to_char(v_jour, 'IYYY-IW'));
          PERFORM public.jauges_effet_appliquer_interne(v_ministre, -5, 0, 0);
          PERFORM public.jauges_effet_appliquer_interne(a, 2, 0, 0);
          v_vp := public.forum_publication_jauges_interne(a, p_requete, jsonb_build_object('forum', 'national',
                    'titre', 'Autocritique publique de ' || v_ministre,
                    'contenu', 'Sur l''invitation du Président du Conseil du Peuple, le camarade ministre ' || v_ministre
                      || ' reconnaît publiquement ses erreurs et remercie le Parti de sa vigilance.'));
          IF NOT coalesce((v_vp->>'ok')::boolean, false) THEN
            RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = '{"ok":false,"raison":"publication_refusee"}';
          END IF;
          PERFORM public.mail_systeme_poser_interne('Conseil du Peuple', v_ministre, 'Autocritique publique',
            'Le Président du Conseil du Peuple vous a contraint à une autocritique publique, publiée dans la presse (−5 POP).', NULL);
          v := jsonb_build_object('ok', true, 'action', p_action, 'ministre', v_ministre,
                 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg',
                 'pop', (SELECT (resources->>'pop')::numeric FROM public.personnages_donnees WHERE name = a));
        END IF;
      END IF;

    ELSE
      v := jsonb_build_object('ok', false, 'raison', 'action_inconnue');
    END IF;

    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS dt = PG_EXCEPTION_DETAIL; RETURN dt::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, act, par, v);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_pouvoir_commande(uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_pouvoir_commande(uuid, text, jsonb) TO authenticated;

-- ============================================================================ 6. Passe de nuit
CREATE OR REPLACE FUNCTION public.sovarka_pouvoir_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour date := public.sovarka_jour_paris(); v_dow int; dep text; v_titres text; v_verse integer;
  v_conv int := 0; v_abs int := 0; v_pay int := 0; v_ref int := 0; c record;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  v_dow := extract(isodow FROM v_jour)::int;

  -- Jeudi : convocation des députés.
  IF v_dow = 4 AND public.acte_nocturne_revendiquer('soviet', 'sovarka_convocation_deputes', '-', NULL) THEN
    SELECT string_agg('• ' || titre, E'\n') INTO v_titres FROM public.sovarka_ordre_du_jour(v_jour);
    FOR dep IN SELECT * FROM public.sovarka_deputes_interne() LOOP
      PERFORM public.mail_systeme_poser_interne('Secrétariat du Conseil du Peuple', dep, 'Convocation : séance du jeudi',
        'Camarade député, vous êtes convoqué aujourd''hui au Palais du Gouvernement de Sovarka, Salle du Conseil du Peuple, '
        || 'pour approuver les lois promulguées. Émargez puis approuvez ou abstenez-vous (une abstention est signalée et coûte 5 POP à votre parti).'
        || E'\n\nAttention : un député absent perd son indemnité (250 PSK par jour) pour toute la semaine, jusqu''à la convocation suivante.'
        || E'\n\nOrdre du jour :\n' || coalesce(v_titres, '(aucune loi promulguée cette semaine)'), NULL);
      v_conv := v_conv + 1;
    END LOOP;
  END IF;

  -- Vendredi : les absents de la veille perdent leur indemnité pour sept jours (jusqu'au jeudi suivant inclus).
  IF v_dow = 5 THEN
    FOR dep IN SELECT d FROM public.sovarka_deputes_interne() d
                WHERE NOT EXISTS (SELECT 1 FROM public.sovarka_seances s WHERE s.jour = v_jour - 1 AND s.depute = d) LOOP
      IF public.acte_nocturne_revendiquer('soviet', 'sovarka_absence_depute', dep, NULL) THEN
        INSERT INTO public.sovarka_indemnites (depute, suspendu_jusqu_au, motif) VALUES (dep, v_jour + 6, 'absence ' || (v_jour - 1))
        ON CONFLICT (depute) DO UPDATE SET suspendu_jusqu_au = greatest(sovarka_indemnites.suspendu_jusqu_au, excluded.suspendu_jusqu_au),
                                           motif = excluded.motif;
        PERFORM public.mail_systeme_poser_interne('Secrétariat du Conseil du Peuple', dep, 'Indemnité suspendue',
          'Absent à la séance de jeudi : votre indemnité de député est suspendue pour sept jours, jusqu''au ' || to_char(v_jour + 6, 'DD/MM') || ' inclus.', NULL);
        v_abs := v_abs + 1;
      END IF;
    END LOOP;
  END IF;

  -- Chaque jour : indemnité des députés non suspendus, sur la caisse du Soviet (plafonnée à son solde).
  FOR dep IN SELECT d FROM public.sovarka_deputes_interne() d
              WHERE NOT EXISTS (SELECT 1 FROM public.sovarka_indemnites i WHERE i.depute = d AND i.suspendu_jusqu_au >= v_jour) LOOP
    IF public.acte_nocturne_revendiquer('soviet', 'sovarka_indemnite_depute', dep, NULL) THEN
      v_verse := public.assemblee_debiter_caisse_plafonne('soviet_assemblee', 250);
      IF v_verse > 0 THEN PERFORM public.argent_crediter_interne(dep, v_verse, 'liquide'); v_pay := v_pay + 1; END IF;
    END IF;
  END LOOP;

  -- Conscription : passé 48 h, le convoqué est réfractaire et recherché.
  FOR c IN SELECT nom FROM public.sovarka_conscrits WHERE statut = 'convoque' AND convoque_ts < now() - interval '48 hours' FOR UPDATE LOOP
    UPDATE public.sovarka_conscrits SET statut = 'refractaire' WHERE nom = c.nom;
    PERFORM public.crime_rechercher_interne(c.nom, 'refractaire', 'delit_mineur');
    PERFORM public.mail_systeme_poser_interne('Ministère de la Défense de la Patrie', c.nom, 'Réfractaire',
      'Vous ne vous êtes pas présenté à la caserne dans les 48 heures : vous êtes réfractaire et recherché.', NULL);
    v_ref := v_ref + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'jour', v_jour, 'convocations', v_conv, 'absents', v_abs, 'indemnites', v_pay, 'refractaires', v_ref);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_pouvoir_passe() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sovarka_pouvoir_passe() TO service_role;

-- ============================================================================ 7. Retrait de droit : saisine requise
CREATE OR REPLACE FUNCTION public.sovarka_droit_retirer(p_ville text, p_batiment text, p_piece text, p_motif text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); p record; r jsonb; v jsonb; v_motif text := btrim(coalesce(p_motif,'')); sz public.sovarka_saisines;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi;
  IF p.country IS DISTINCT FROM 'soviet' OR p.current_city IS DISTINCT FROM p_ville OR p.current_building NOT IN ('tribunal','tribunal-local') THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_au_tribunal'); END IF;
  IF public.justice_juge_titulaire('soviet', p_ville) IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','reserve_juge'); END IF;
  -- Décision de Fred (08/11/2026) : seul le ministre de la Justice prolétarienne saisit le juge.
  SELECT * INTO sz FROM public.sovarka_saisines
   WHERE ville = p_ville AND batiment = p_batiment AND piece = p_piece AND statut = 'en_attente' FOR UPDATE;
  IF sz.id IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','saisine_requise'); END IF;
  IF length(v_motif) < 3 OR length(v_motif) > 300 THEN RETURN jsonb_build_object('ok',false,'raison','motif_invalide'); END IF;
  IF public.sovarka_exploitant_interne(p_ville, p_batiment, p_piece) IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','local_non_exploite'); END IF;
  r := public.payer_ordre(moi, 'sovarka_retirer_droit', 1, 0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  v := public.sovarka_droit_retour_etat_interne(p_ville, p_batiment, p_piece, 'tribunal', moi, v_motif);
  IF v->>'ok' = 'true' THEN
    UPDATE public.sovarka_saisines SET statut = 'retire', juge = moi, decide_ts = now() WHERE id = sz.id;
  END IF;
  RETURN r || v;
END $$;

-- ============================================================================ 8. Corrections en place
DO $patch$
DECLARE r record; v_def text; v_n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    -- Pas de taxe locale en Sovarka : les mairies vivent des loyers.
    ('public.appliquer_taxe_transaction(text,text,numeric)',
     $a$  v_tl := coalesce((v_muni->>'tauxLocal')::numeric, 2);$a$,
     $b$  v_tl := CASE WHEN p_pays = 'soviet' THEN 0 ELSE coalesce((v_muni->>'tauxLocal')::numeric, 2) END;$b$),
    -- 10 % des recettes municipales de Sovarka vont à l'État.
    ('public.recette_municipale(text,text,numeric,text)',
     $a$  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse, p_montant, true);$a$,
     $b$  IF p_pays = 'soviet' THEN
    p_montant := p_montant - public.sovarka_impot_municipal_interne(p_montant);
    IF p_montant <= 0 THEN RETURN jsonb_build_object('ok', true, 'caisse', v_caisse, 'montant', 0, 'canal', p_canal); END IF;
  END IF;
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse, p_montant, true);$b$),
    -- 10 % de la main-d'œuvre payée en Sovarka vont à l'État.
    ('public.commerce_produire(text,text,text,text)',
     $a$  UPDATE public.personnages_donnees
     SET pa = v_pa - COALESCE(v_pa_requis,0),$a$,
     $b$  v_salaire := v_salaire - public.sovarka_impot_main_oeuvre_interne(v_salaire, v_pays);
  UPDATE public.personnages_donnees
     SET pa = v_pa - COALESCE(v_pa_requis,0),$b$),
    ('public.vehicule_travailler_interne(text,jsonb)',
     $a$  PERFORM public.argent_crediter_interne(p_moi, v_salaire, 'liquide');$a$,
     $b$  PERFORM public.argent_crediter_interne(p_moi, v_salaire - public.sovarka_impot_main_oeuvre_interne(v_salaire, coalesce(v_data->>'country', 'republic')), 'liquide');$b$),
    -- Taux de Sovarka modifiables par le ministre de l'Économie collective.
    ('public.taux_imposition_fixer(text,integer,text,integer,integer)',
     $a$  ELSIF p_portee = 'national' THEN
    v_poste_requis := 'min_fin'; v_cle_champ := 'tauxNational';$a$,
     $b$  ELSIF p_portee = 'national' THEN
    v_poste_requis := 'min_fin'; v_cle_champ := 'tauxNational';
  ELSIF p_portee IN ('main_oeuvre', 'municipal') THEN
    v_poste_requis := 'min_fin'; v_cle_champ := CASE p_portee WHEN 'main_oeuvre' THEN 'tauxMainOeuvre' ELSE 'tauxMunicipal' END;$b$),
    ('public.taux_imposition_fixer(text,integer,text,integer,integer)',
     $a$  -- LE PAIEMENT, DANS CETTE TRANSACTION.$a$,
     $b$  IF p_portee IN ('main_oeuvre', 'municipal') AND v_pays IS DISTINCT FROM 'soviet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'portee_reservee_sovarka');
  END IF;
  IF p_portee = 'local' AND v_pays = 'soviet' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_taxe_locale_en_sovarka');
  END IF;
  -- LE PAIEMENT, DANS CETTE TRANSACTION.$b$),
    -- Censure sans risque en Sovarka ; le sondage de Sovarka a son propre circuit.
    ('public.jauges_ordre_executer(text,uuid,jsonb)',
     $a$pa_cout:=2; v_detecte:=random()<0.30;$a$,
     $b$pa_cout:=2; v_detecte:=(a.country IS DISTINCT FROM 'soviet') AND random()<0.30;$b$),
    ('public.jauges_ordre_executer(text,uuid,jsonb)',
     $a$  WHEN 'commanditer_sondage' THEN
$a$,
     $b$  WHEN 'commanditer_sondage' THEN
    IF a.country = 'soviet' THEN RETURN jsonb_build_object('ok',false,'raison','sondage_sovarka');END IF;
$b$),
    -- Conscrit : pas de démission tant que la conscription n'est pas levée.
    ('public.militaire_soldat_retirer(text,text,text)',
     $a$  IF v_moi = p_nom THEN v_par := 'demission';$a$,
     $b$  IF v_moi = p_nom AND EXISTS (SELECT 1 FROM public.sovarka_conscrits WHERE nom = p_nom AND statut = 'presente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conscrit_jusqu_a_la_levee');
  ELSIF v_moi = p_nom THEN v_par := 'demission';$b$)
  ) AS t(fn, avant, apres) LOOP
    v_def := pg_get_functiondef(r.fn::regprocedure);
    v_n := (length(v_def) - length(replace(v_def, r.avant, ''))) / length(r.avant);
    IF v_n <> 1 THEN RAISE EXCEPTION 'fragment non unique (%) dans %', v_n, r.fn; END IF;
    EXECUTE replace(v_def, r.avant, r.apres);
  END LOOP;

  -- Préemption et vote de confiance : fermés en Sovarka (garde en tête de corps).
  FOR r IN SELECT * FROM (VALUES
    ('public.entreprise_preempter(text,text,numeric,integer)', 'p_acteur', 'pas_de_preemption_en_sovarka'),
    ('public.entreprise_acte_preemption(text,text,text,text,integer,integer)', 'p_acteur', 'pas_de_preemption_en_sovarka'),
    ('public.vote_confiance_declencher(integer,integer)', 'public.mon_personnage()', 'pas_de_vote_de_confiance_en_sovarka')
  ) AS t(fn, acteur, raison) LOOP
    v_def := pg_get_functiondef(r.fn::regprocedure);
    IF position(r.raison IN v_def) = 0 THEN
      IF position(E'\nBEGIN\n' IN v_def) = 0 THEN RAISE EXCEPTION 'BEGIN introuvable dans %', r.fn; END IF;
      v_def := regexp_replace(v_def, E'\nBEGIN\n', E'\nBEGIN\n  IF (SELECT country FROM public.personnages_donnees WHERE name = ' || r.acteur
        || E') = ''soviet'' THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''' || r.raison || E'''); END IF;\n');
      EXECUTE v_def;
    END IF;
  END LOOP;
END $patch$;
