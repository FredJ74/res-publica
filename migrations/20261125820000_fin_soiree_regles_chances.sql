-- Mission de fin de soirée du 25/11/2026 (Claude), points 1.4, 1.6, 1.10, 2.1, 2.2, 2.3 — NON APPLIQUÉE. Après 20261125700000.
-- Décisions de Fred (25/11, fin de soirée) et choix techniques tranchés par Claude :
-- • 1.4 Contrebande : un échec repéré par la douane coûte une AMENDE égale au gain qu'aurait rapporté la contrebande, plus la
--   recherche (au lieu de la saisie de la contrebande portée sur soi). Le gain n'existait nulle part en base : il devient un
--   réglage MJ (crim_parametres contrebande_gain, 500, et contrebande_gain_soviet, 100 PSK), porté aussi par la cargaison
--   (champ « valeur »). L'amende est prise sur le liquide puis le compte national, dans la limite de ce que le joueur possède.
-- • 1.6 Médaille commémorative du Tractorisme : plus vendue au musée (souvenirs_objets.achetable = false ; l'emplacement de la
--   liste 3 ne change pas). Offerte à coup sûr au PREMIER chant de « Chanter l'hymne au Tracteur » à la Grange Sainte de
--   Novomirsk, une seule fois par personnage (tractorisme_medailles). Le chant y passe par tractorisme_chanter_hymne (paiement
--   de l'ordre « prier » et remise dans la même transaction). Inventaire plein : la médaille attend le chant suivant.
-- • 1.10 Censure : le scandale peut éclater aussi en Sovarka (même chance, réglage MJ censure_scandale_taux, 30). En Sovarka, la
--   censure agit sur la POPULARITÉ DU PARTI AU POUVOIR (sovarka_parti_pop_interne, l'indice serveur le plus proche de la
--   popularité du régime) : +3 sans scandale (réglage censure_sovarka_hausse), −5 si le scandale éclate (censure_sovarka_baisse).
-- • 2.1 Bénédiction : accordée et tenue par le serveur (benedictions ; benediction_contact_demander : 1 PA, 80 %, 24 h, non
--   cumulable) ; les jets du commissaire (enquête, filature) la consomment au serveur, le paramètre p_benediction de l'écran
--   est ignoré.
-- • 2.2 Charisme du serveur (presse) : valeur de base, moins l'excommunication, PLUS les bonus temporaires tenus au serveur
--   (effets_actifs, deltas CHA non expirés).
-- • 2.3 Fuite d'information et soins sans trace : ordres_chances_lire rend aussi la chance du demi-effet (clé « <ordre>_demi »).
-- Sans cette migration : comportement actuel (l'écran garde ses anciens chemins, aucune erreur pour le joueur).
--
-- Contrôles en lecture après application :
--   SELECT position('contrebande_amende_v1' in pg_get_functiondef('public.crime_contrebande(integer,integer)'::regprocedure)) > 0;   -- vrai
--   SELECT valeur FROM public.crim_parametres WHERE cle IN ('contrebande_gain', 'contrebande_gain_soviet') ORDER BY cle;           -- 500, 100
--   SELECT achetable FROM public.souvenirs_objets WHERE cle = 'souv_novomirsk_medaille';                                            -- faux
--   SELECT has_function_privilege('authenticated', 'public.tractorisme_chanter_hymne(uuid)', 'EXECUTE');                            -- vrai
--   SELECT position('censure_sovarka_v1' in d) > 0 AND position('censure_sovarka_regime_v1' in d) > 0
--     FROM (SELECT pg_get_functiondef('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure) d) x;                          -- vrai
--   SELECT position('benediction_serveur_v1' in pg_get_functiondef('public.commissaire_enquete_mener(uuid,text,boolean)'::regprocedure)) > 0
--      AND position('benediction_serveur_v1' in pg_get_functiondef('public.filature_mener(uuid,text,boolean)'::regprocedure)) > 0;  -- vrai
--   SELECT has_function_privilege('authenticated', 'public.benediction_contact_demander(uuid,text)', 'EXECUTE');                    -- vrai
--   SELECT has_function_privilege('authenticated', 'public.benediction_consommer_interne(text)', 'EXECUTE');                        -- faux
--   SELECT position('cha_serveur_v1' in pg_get_functiondef('public.presse_cha_effectif_interne(text)'::regprocedure)) > 0;         -- vrai
--   SELECT position('demi_effet_v1' in pg_get_functiondef('public.ordres_chances_lire(text[],text)'::regprocedure)) > 0;           -- vrai
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- ── 1.4 Contrebande : amende égale au gain sur un échec repéré ─────────────────────────────────────────────────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES ('contrebande_gain', 500), ('contrebande_gain_soviet', 100)
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.crim_contrebande_gain_interne(p_pays text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(0, CASE WHEN p_pays = 'soviet' THEN public.crim_param_interne('contrebande_gain_soviet', 100)
                          ELSE public.crim_param_interne('contrebande_gain', 500) END) /* contrebande_amende_v1 */
$$;

DO $garde$
BEGIN
  IF position('contrebande_amende_v1' IN pg_get_functiondef('public.crime_contrebande(integer,integer)'::regprocedure)) = 0
     AND position('audit_chances_contrebande_v1' IN pg_get_functiondef('public.crime_contrebande(integer,integer)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'crime_contrebande : version de production inattendue (marque audit_chances_contrebande_v1 absente)';
  END IF;
END $garde$;

CREATE OR REPLACE FUNCTION public.crime_contrebande(p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_paie jsonb; v_taux integer; v_roll integer; v_repere boolean := false; v_gain numeric; v_amende numeric := 0;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_paie := public.payer_ordre(v_moi, 'contrebande_port', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_taux := public.crim_contrebande_taux_interne(v_moi);
  v_gain := public.crim_contrebande_gain_interne((SELECT country FROM public.personnages_donnees WHERE name = v_moi));
  v_roll := least(100, floor(random() * 100)::integer + 1 + public.securite_malus_lieu_interne(v_moi)); /* securite_dissuasion */
  IF v_roll <= v_taux THEN
    UPDATE public.personnages_donnees
       SET inventory = (CASE WHEN jsonb_typeof(inventory) = 'array' THEN inventory ELSE '[]'::jsonb END)
         || jsonb_build_array(jsonb_build_object('id', 'contrebande-' || replace(gen_random_uuid()::text, '-', ''),
              'type', 'contrebande', 'name', 'Cargaison de contrebande', 'icon', 'ti-package-off', 'legal', false,
              'desc', 'Marchandises importées illégalement.', 'valeur', v_gain))
     WHERE name = v_moi;
    PERFORM public.crime_dis_ajuster_interne(v_moi, -5);
  END IF;
  -- La douane peut repérer la manœuvre, qu'elle réussisse ou non : avis de recherche.
  v_repere := public.crime_detecter_interne(v_moi, 'contrebande_port', true);
  IF v_repere AND v_roll > v_taux THEN
    -- Échec repéré (décision de Fred, 25/11 fin de soirée) : amende égale au gain qu'aurait rapporté la contrebande,
    -- prise sur le liquide puis le compte national, dans la limite de ce que le joueur possède.
    v_amende := public.argent_debiter_interne(v_moi, v_gain, 'liquide_puis_nationale');
  END IF;
  RETURN jsonb_build_object('ok', true, 'reussi', v_roll <= v_taux, 'repere', v_repere, 'saisie', 0,
    'amende', CASE WHEN v_repere AND v_roll > v_taux THEN v_gain ELSE 0 END, 'amende_payee', v_amende, 'gain', v_gain,
    'taux', v_taux, 'jet', v_roll,
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi),
    'inventory', (SELECT inventory FROM public.personnages_donnees WHERE name = v_moi))
    || public.crime_etat_acteur_interne(v_moi); /* audit_chances_contrebande_v1 contrebande_amende_v1 */
END; $function$;
REVOKE ALL ON FUNCTION public.crim_contrebande_gain_interne(text) FROM PUBLIC, anon, authenticated;

-- ── 1.6 Médaille du Tractorisme : premier chant à la Grange Sainte de Novomirsk ────────────────────────────────────
UPDATE public.souvenirs_objets SET achetable = false WHERE cle = 'souv_novomirsk_medaille';

CREATE TABLE IF NOT EXISTS public.tractorisme_medailles (
  personnage text PRIMARY KEY,
  remise_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.tractorisme_medailles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.tractorisme_medailles FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.tractorisme_chanter_hymne(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb; d record; p jsonb; s public.souvenirs_objets; v_dep jsonb;
        v_medaille boolean := false; v_plein boolean := false;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'tractorisme_chanter_hymne', '{}'::jsonb);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT country, current_city, current_building, current_room INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF (d.country, d.current_city, d.current_building, d.current_room) IS DISTINCT FROM ('soviet', 'capitale', 'kolkhoze-spirituel', 'grange_sainte') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_grange_sainte'); END IF;
  p := public.payer_ordre_interne(a, 'prier', 1, 0);
  IF coalesce((p ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN p; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tractorisme_medailles WHERE personnage = a) THEN
    SELECT * INTO s FROM public.souvenirs_objets WHERE cle = 'souv_novomirsk_medaille';
    IF s.cle IS NOT NULL THEN
      v_dep := public.inventaire_deposer_interne(a, public.souvenir_objet_interne(s));
      IF coalesce((v_dep ->> 'ok')::boolean, false) THEN
        INSERT INTO public.tractorisme_medailles (personnage) VALUES (a);
        v_medaille := true;
      ELSE
        v_plein := true;   -- inventaire plein : la médaille attend le chant suivant
      END IF;
    END IF;
  END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'tractorisme_chanter_hymne', '{}'::jsonb,
    p || jsonb_build_object('ok', true, 'medaille', v_medaille, 'medaille_en_attente', v_plein,
      'message', CASE WHEN v_medaille THEN 'Votre voix angélique a touché les dieux du Tractorisme : ils vous offrent la médaille du Tractorisme en remerciement de ce moment d''intense émotion.' END,
      'inventory', (SELECT inventory FROM public.personnages_donnees WHERE name = a))); /* tractorisme_medaille_v1 */
END $$;
REVOKE ALL ON FUNCTION public.tractorisme_chanter_hymne(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tractorisme_chanter_hymne(uuid) TO authenticated;

-- ── 1.10 Censure : scandale possible partout ; en Sovarka, popularité du parti au pouvoir ──────────────────────────
INSERT INTO public.crim_parametres (cle, valeur) VALUES ('censure_scandale_taux', 30), ('censure_sovarka_hausse', 3), ('censure_sovarka_baisse', 5)
ON CONFLICT (cle) DO NOTHING;

CREATE OR REPLACE FUNCTION public.censure_sovarka_regime_interne(p_scandale boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_parti text := public.sovarka_parti_au_pouvoir(); v_delta numeric; v_pop numeric;
BEGIN
  IF v_parti IS NULL THEN RETURN jsonb_build_object('regime_delta', 0); END IF;
  v_delta := CASE WHEN p_scandale THEN -public.crim_param_interne('censure_sovarka_baisse', 5)
                  ELSE public.crim_param_interne('censure_sovarka_hausse', 3) END;
  v_pop := public.sovarka_parti_pop_interne(v_parti, v_delta);
  RETURN jsonb_build_object('regime_parti', v_parti, 'regime_delta', v_delta, 'regime_pop', v_pop); /* censure_sovarka_regime_v1 */
END $$;
REVOKE ALL ON FUNCTION public.censure_sovarka_regime_interne(boolean) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $a$pa_cout:=2; v_detecte:=(a.country IS DISTINCT FROM 'soviet') AND random()<0.30;$a$,
  $b$pa_cout:=2; v_detecte:=random()*100<public.crim_param_interne('censure_scandale_taux',30); /* censure_sovarka_v1 */$b$,
  1, 'censure_sovarka_v1');
SELECT pg_temp.rp_remplacer('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $a$    PERFORM public.presse_censure_indice_interne(a.country);$a$,
  $b$    PERFORM public.presse_censure_indice_interne(a.country);
    IF a.country='soviet' THEN
      publication:=coalesce(publication,'{}'::jsonb)||public.censure_sovarka_regime_interne(coalesce((publication->>'scandale')::boolean,false));
    END IF; /* censure_sovarka_regime_v1 */$b$,
  1, 'censure_sovarka_regime_v1');

-- ── 2.1 Bénédiction tenue par le serveur ───────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.benedictions (
  personnage text PRIMARY KEY,
  accordee_le timestamptz NOT NULL DEFAULT now(),
  expire_le timestamptz NOT NULL,
  consommee_le timestamptz,
  par text
);
ALTER TABLE public.benedictions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.benedictions FROM PUBLIC, anon, authenticated;

-- Consomme la bénédiction active (une seule, 24 h) : vrai si elle s'applique à ce jet.
CREATE OR REPLACE FUNCTION public.benediction_consommer_interne(p_nom text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  UPDATE public.benedictions SET consommee_le = now()
   WHERE personnage = p_nom AND consommee_le IS NULL AND expire_le > now();
  RETURN FOUND; /* benediction_serveur_v1 */
END $$;

CREATE OR REPLACE FUNCTION public.benediction_active_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.benedictions WHERE personnage = p_nom AND consommee_le IS NULL AND expire_le > now())
$$;

-- Bénédiction demandée à un religieux présent (même règle que l'écran : 1 PA, 80 %, 24 h, non cumulable, refusée à l'excommunié).
CREATE OR REPLACE FUNCTION public.benediction_contact_demander(p_requete uuid, p_pnj text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('pnj', left(coalesce(p_pnj, ''), 120)); v jsonb;
        v_excom jsonb; p jsonb; v_jet integer; v_ok boolean;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'benediction_contact_demander', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT excommunie INTO v_excom FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF v_excom IS NOT NULL AND v_excom::text NOT IN ('null', 'false', '') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'excommunie'); END IF;
  p := public.jets_pa_prelever_interne(a, 'benediction_contact', 1);
  IF coalesce((p ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN p; END IF;
  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= 80;
  IF v_ok THEN
    INSERT INTO public.benedictions (personnage, accordee_le, expire_le, consommee_le, par)
    VALUES (a, now(), now() + interval '1 day', NULL, left(coalesce(p_pnj, ''), 120))
    ON CONFLICT (personnage) DO UPDATE SET accordee_le = now(), expire_le = now() + interval '1 day', consommee_le = NULL, par = EXCLUDED.par;
  END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'benediction_contact_demander', prm,
    jsonb_build_object('ok', true, 'benie', v_ok, 'jet', v_jet, 'taux', 80, 'pa', p -> 'pa')); /* benediction_serveur_v1 */
END $$;
REVOKE ALL ON FUNCTION public.benediction_consommer_interne(text), public.benediction_active_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.benediction_contact_demander(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.benediction_contact_demander(uuid, text) TO authenticated;

SELECT pg_temp.rp_remplacer('public.commissaire_enquete_mener(uuid,text,boolean)'::regprocedure,
  $a$public.commissaire_jet_interne('enquete', p_cible, coalesce(p_benediction, false))$a$,
  $b$public.commissaire_jet_interne('enquete', p_cible, public.benediction_consommer_interne(a) /* benediction_serveur_v1 */)$b$,
  1, 'benediction_serveur_v1');
SELECT pg_temp.rp_remplacer('public.filature_mener(uuid,text,boolean)'::regprocedure,
  $a$public.commissaire_jet_interne('filature', p_cible, coalesce(p_benediction, false))$a$,
  $b$public.commissaire_jet_interne('filature', p_cible, public.benediction_consommer_interne(a) /* benediction_serveur_v1 */)$b$,
  1, 'benediction_serveur_v1');

-- ── 2.2 Charisme du serveur : bonus temporaires tenus au serveur compris ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.presse_cha_effectif_interne(p_nom text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_stat_interne(p_nom, 'CHA', 8)
       - CASE WHEN d.excommunie IS NOT NULL AND d.excommunie::text NOT IN ('null', 'false', '') THEN 2 ELSE 0 END
       + coalesce((SELECT sum(CASE WHEN jsonb_typeof(e.obj -> 'deltas' -> 'CHA') = 'number' THEN (e.obj -> 'deltas' ->> 'CHA')::numeric ELSE 0 END)
                     FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.effets_actifs) = 'array' THEN d.effets_actifs ELSE '[]'::jsonb END) e(obj)
                    WHERE jsonb_typeof(e.obj -> 'expireA') = 'number'
                      AND (e.obj ->> 'expireA')::numeric > extract(epoch FROM clock_timestamp()) * 1000), 0) /* cha_serveur_v1 */
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$$;
REVOKE ALL ON FUNCTION public.presse_cha_effectif_interne(text) FROM PUBLIC, anon, authenticated;

-- ── 2.3 Chance du demi-effet des ordres génériques (fuite d'information, soins sans trace) ─────────────────────────
-- ordre_generique_executer : jet de 1 à 100 ; demi-effet (« partial ») quand 100 − 0,7 × taux < jet ≤ 100 − 0,4 × taux.
CREATE OR REPLACE FUNCTION public.ordre_generique_demi_chance_interne(p_fn text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN o.toujours_reussi THEN 0 ELSE
           (floor(100 - 0.4 * x.t) - floor(100 - 0.7 * x.t))::integer END /* demi_effet_v1 */
    FROM public.ordres_generiques o
    CROSS JOIN LATERAL (SELECT greatest(5, CASE WHEN o.taux_reussite >= 98 THEN 99 ELSE o.taux_reussite END)::numeric AS t) x
   WHERE o.fn = p_fn
$$;
REVOKE ALL ON FUNCTION public.ordre_generique_demi_chance_interne(text) FROM PUBLIC, anon, authenticated;

SELECT pg_temp.rp_remplacer('public.ordres_chances_lire(text[],text)'::regprocedure,
  $a$        out := out || jsonb_build_object(f, public.ordres_chances_audit_interne(a, f));$a$,
  $b$        out := out || jsonb_build_object(f, public.ordres_chances_audit_interne(a, f));
        IF f IN ('fuite_info', 'soins_discrets') THEN
          out := out || jsonb_build_object(f || '_demi', public.ordre_generique_demi_chance_interne(f)); /* demi_effet_v1 */
        END IF;$b$,
  1, 'demi_effet_v1');

NOTIFY pgrst, 'reload schema';

COMMIT;
