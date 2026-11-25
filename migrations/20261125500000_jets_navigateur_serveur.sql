-- Mission du soir du 25/11/2026 (Claude), bloc 1.2 — APPLIQUÉE en production le 25/11/2026 en fin de soirée (feu vert de Fred, contrôlée en lecture). Après 20261125130000 (chances réelles, appliquée).
-- Les jets encore tirés dans le NAVIGATEUR passent au SERVEUR, avec la MÊME formule, et le coût est payé dans la MÊME
-- transaction que le jet (audit docs/nuit/AUDIT-CHANCES-20261125.md). Aucune règle de jeu ne change.
--   • « Placer un article favorable » (article) et « Contrer une campagne de presse » (etouffer) : presse_lobbying_tenter.
--     Chance clamp(5, 95, base + 2 × (CHA − 13)) — base 75 (article), 70 (étouffer), 10 si un étouffement protège la cible ;
--     CHA effectif comme getStatEffective (excommunication −2). Réussite : 1 PA et le prix (500 / 1000) payés, prix versé à la
--     caisse de la rédaction du lieu (rendu au joueur si ce journal n'a pas de caisse), article inscrit à la chronique ou
--     étouffement de 7 jours enregistré. Échec : 1 PA seulement, la rédaction refuse.
--   • « Demander à parler à quelqu'un » (loge) : loge_frapper — 1 PA, réponse à 95 %.
--   • « Corrompre un journaliste » (corruption_presse_tenter) et « Fabriquer un scandale » (scandale_tenter) : le malus de
--     sécurité intérieure est lu au serveur (crime_malus_isn_interne, ville où l'on se trouve) au lieu d'être fourni par
--     l'écran ; en cas d'accord, PA et prix sont payés DANS la fonction (et versés à la caisse de la rédaction) ; un blocus
--     syndical refuse avant le jet. Remplacements contrôlés (marques jets_b1b_*).
--   • « Mener l'enquête » et « Organiser une filature » (commissaire) : nouvelles formes à requête (p_requete uuid) qui
--     prélèvent la caisse du commissariat (250 / 150) et les 2 PA AVANT le jet, dans la même transaction (plus de relance
--     gratuite) ; l'enquête sans trace contre la cible conclut « infructueuse » au serveur. Formules inchangées
--     (commissaire_jet_interne). Les anciennes formes à deux arguments restent pour un écran en retard.
--   • « Censurer un média » : le −8 à l'indice social (que l'écran appliquait à son seul affichage) est posé au serveur, sur
--     les villes du pays (Républia : seules villes dont l'indice est tenu par le serveur). « Consulter des dossiers » : le
--     dossier lu est tiré au serveur (dossier_rang, 0 à 5). Raccord dans jauges_ordre_executer (marque jets_b1b_jauges_v1).
--   • « Vos chances réelles » : ordres_chances_lire lit aussi article, etouffer, demander_parler_loge, corrompre_journaliste,
--     fabriquer_scandale (ordres_chances_b1b_interne ; marque jets_b1b_chances_v1).
-- Sans cette migration, l'écran garde son comportement actuel (repli sur PGRST202, aucune erreur pour le joueur).
--
-- Contrôles en lecture après application :
--   SELECT has_function_privilege('authenticated', p, 'EXECUTE') FROM unnest(ARRAY[
--     'public.presse_lobbying_tenter(uuid,text,text,text,text,text)', 'public.loge_frapper(uuid)',
--     'public.commissaire_enquete_mener(uuid,text,boolean)', 'public.filature_mener(uuid,text,boolean)']) p;          -- 4 × vrai
--   SELECT has_function_privilege('authenticated', 'public.jets_pa_prelever_interne(text,text,integer)', 'EXECUTE');  -- faux
--   SELECT position(m in pg_get_functiondef(f::regprocedure)) > 0 FROM (VALUES
--     ('public.corruption_presse_tenter(text,text,text,text,integer,timestamptz)', 'jets_b1b_paie_v1'),
--     ('public.corruption_presse_tenter(text,text,text,text,integer,timestamptz)', 'jets_b1b_isn_v1'),
--     ('public.scandale_tenter(text,text,text,text,integer,timestamptz)', 'jets_b1b_paie_v1'),
--     ('public.scandale_tenter(text,text,text,text,integer,timestamptz)', 'jets_b1b_isn_v1'),
--     ('public.jauges_ordre_executer(text,uuid,jsonb)', 'jets_b1b_jauges_v1'),
--     ('public.ordres_chances_lire(text[],text)', 'jets_b1b_chances_v1')) v(f, m);                                   -- 6 × vrai
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- ── Socle : PA seuls (l'échec d'un ordre qui prend ses PA même refusé), CHA effectif, recette de la rédaction ─────────
CREATE OR REPLACE FUNCTION public.jets_pa_prelever_interne(p_acteur text, p_fn text, p_pa integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pa integer;
BEGIN
  IF coalesce(p_pa, 0) <= 0 THEN RETURN jsonb_build_object('ok', true, 'pa_preleves', 0); END IF;
  IF public.blocus_ordre_refuse_interne(p_acteur, p_fn) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'blocus_syndical', 'fn', p_fn); END IF;
  SELECT pa INTO v_pa FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < p_pa THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa); END IF;
  UPDATE public.personnages_donnees SET pa = v_pa - p_pa WHERE name = p_acteur;
  PERFORM public.accueil_ordre_paye_interne(p_acteur, p_fn, p_pa);
  RETURN jsonb_build_object('ok', true, 'pa', v_pa - p_pa, 'pa_preleves', p_pa); /* jets_b1b_v1 */
END $$;

-- CHA effectif, comme getStatEffective('CHA') côté écran (précédent : négocier avec les squatteurs) : excommunication −2.
CREATE OR REPLACE FUNCTION public.presse_cha_effectif_interne(p_nom text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.crim_stat_interne(p_nom, 'CHA', 8)
       - CASE WHEN d.excommunie IS NOT NULL AND d.excommunie::text NOT IN ('null', 'false', '') THEN 2 ELSE 0 END
    FROM public.personnages_donnees d WHERE d.name = p_nom;
$$;

-- Article favorable / étouffement : clamp(5, 95, base + 2 × (CHA − 13)), base 75 / 70, ou 10 si la cible est étouffée.
CREATE OR REPLACE FUNCTION public.presse_lobbying_taux_interne(p_nom text, p_mode text, p_etouffe boolean)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT greatest(5, least(95, round(CASE WHEN p_etouffe THEN 10 WHEN p_mode = 'article' THEN 75 ELSE 70 END
           + 2 * (coalesce(public.presse_cha_effectif_interne(p_nom), 8) - 13))))::integer;
$$;

-- Recette éditoriale : caisse « redaction » du bâtiment où l'on se trouve ; sans caisse, l'argent est rendu (comme l'écran).
CREATE OR REPLACE FUNCTION public.presse_redaction_encaisser_interne(p_nom text, p_montant numeric)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; r jsonb;
BEGIN
  IF coalesce(p_montant, 0) <= 0 THEN RETURN true; END IF;
  SELECT country, coalesce(current_city, 'capitale') AS ville, current_building INTO d FROM public.personnages_donnees WHERE name = p_nom;
  r := public.batiment_caisse_mouvement(d.country, d.ville, d.current_building, 'redaction', p_montant, NULL, 0, NULL, true);
  IF coalesce((r ->> 'ok')::boolean, false) THEN RETURN true; END IF;
  UPDATE public.personnages_donnees SET liquide = coalesce(liquide, 0) + p_montant, arg = coalesce(arg, 0) + p_montant
   WHERE name = p_nom;
  RETURN false;
END $$;

-- Paiement complet d'un ordre de presse (PA + prix déclaré au tarif) et versement à la rédaction.
CREATE OR REPLACE FUNCTION public.presse_payer_redaction_interne(p_nom text, p_fn text, p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p jsonb; v_ok boolean;
BEGIN
  p := public.payer_ordre_interne(p_nom, p_fn, p_pa, p_cost);
  IF coalesce((p ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN p; END IF;
  v_ok := public.presse_redaction_encaisser_interne(p_nom, p_cost);
  RETURN jsonb_build_object('ok', true, 'redaction_ok', v_ok, 'cout', CASE WHEN v_ok THEN p_cost ELSE 0 END,
    'paie', (SELECT jsonb_build_object('pa', d.pa, 'liquide', d.liquide, 'arg', d.arg,
               'solde_national', coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage = p_nom AND banque = 'nationale'), 0))
             FROM public.personnages_donnees d WHERE d.name = p_nom)); /* jets_b1b_v1 */
END $$;

CREATE OR REPLACE FUNCTION public.jets_html_echapper_interne(p text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT replace(replace(replace(coalesce(p, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;') $$;

-- ── Article favorable / Contrer une campagne de presse ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.presse_lobbying_tenter(p_requete uuid, p_mode text, p_cible_type text, p_cible_value text,
  p_cible_label text DEFAULT NULL, p_angle text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d record; v_cost integer; v_etouffe boolean := false;
        v_taux integer; v_jet integer; v_ok boolean; v_pays text; v_label text; v_angle text; v_phrase text; v_ville text;
        v_paie jsonb; v_seg text[]; v_solde numeric;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_mode IS NULL OR p_mode NOT IN ('article', 'etouffer')
     OR p_cible_type IS NULL OR p_cible_type NOT IN ('pj', 'organisation', 'local', 'gouvernement', 'pays')
     OR nullif(btrim(coalesce(p_cible_value, '')), '') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v_angle := left(btrim(coalesce(p_angle, '')), 1000);
  IF p_mode = 'article' AND v_angle = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'angle_requis'); END IF;
  v_label := left(coalesce(nullif(btrim(coalesce(p_cible_label, '')), ''), p_cible_value), 200);
  prm := jsonb_build_object('mode', p_mode, 'type', p_cible_type, 'cible', p_cible_value, 'angle', v_angle);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'presse_lobbying_tenter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT * INTO d FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT o.cost INTO v_cost FROM public.ordres_couts o WHERE o.fn = p_mode AND o.pa = 1 ORDER BY o.cost DESC LIMIT 1;
  v_cost := coalesce(v_cost, CASE WHEN p_mode = 'article' THEN 500 ELSE 1000 END);
  -- Ressources vérifiées AVANT le jet : une réussite ne mène jamais à un état impossible.
  IF public.blocus_ordre_refuse_interne(a, p_mode) THEN RETURN jsonb_build_object('ok', false, 'raison', 'blocus_syndical'); END IF;
  IF coalesce(d.pa, 0) < 1 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  SELECT coalesce(solde, 0) INTO v_solde FROM public.comptes_bancaires WHERE personnage = a AND banque = 'nationale';
  IF coalesce(d.liquide, 0) + coalesce(v_solde, 0) < v_cost THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'cout', v_cost); END IF;
  IF p_mode = 'article' THEN
    v_etouffe := EXISTS (SELECT 1 FROM public.tribune_articles_etouffes t
                          WHERE t.cible_type = p_cible_type AND t.cible_value = p_cible_value AND t.expire_le > now());
  END IF;
  v_taux := public.presse_lobbying_taux_interne(a, p_mode, v_etouffe);
  v_jet := floor(random() * 100)::integer + 1;
  v_ok := v_jet <= v_taux;
  -- Pays de la cible (celui de La Tribune qui publiera) : jamais celui du demandeur, sauf à défaut.
  v_seg := string_to_array(p_cible_value, '|');
  v_pays := CASE p_cible_type
    WHEN 'local' THEN nullif(v_seg[1], '')
    WHEN 'gouvernement' THEN p_cible_value WHEN 'pays' THEN p_cible_value
    WHEN 'pj' THEN (SELECT x.country FROM public.personnages_donnees x WHERE x.name = p_cible_value)
    ELSE (SELECT coalesce(o.data::jsonb ->> 'country', o.country_origine) FROM public.organisations o
           WHERE o.id::text = p_cible_value AND o.data IS JSON OBJECT LIMIT 1) END;
  v_pays := coalesce(v_pays, d.country);
  IF v_ok THEN
    v_paie := public.presse_payer_redaction_interne(a, p_mode, 1, v_cost);
    IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'presse_lobbying_paiement_refuse:%', v_paie ->> 'raison'; END IF;
    IF p_mode = 'article' THEN
      v_phrase := CASE p_cible_type WHEN 'organisation' THEN 'l''organisation « ' || v_label || ' »'
                                    WHEN 'local' THEN 'l''établissement « ' || v_label || ' »'
                                    WHEN 'gouvernement' THEN 'le gouvernement de ' || v_label ELSE v_label END;
      v_ville := CASE WHEN p_cible_type = 'local' AND v_seg[1] IN ('republic', 'soviet') THEN public.climat_nom_ville_interne(v_seg[1], v_seg[2]) END;
      INSERT INTO public.chronique_nationale (id, country, type, city, personnages, libelle, data)
      VALUES ('chronique-lobbying_article_favorable-' || p_requete::text, v_pays, 'lobbying_article_favorable', v_ville,
              CASE WHEN p_cible_type = 'pj' THEN jsonb_build_array(p_cible_value) ELSE '[]'::jsonb END,
              'La rédaction de La Tribune a été discrètement convaincue de mettre en avant ' || public.jets_html_echapper_interne(v_phrase)
                || ' sous un angle favorable : « ' || public.jets_html_echapper_interne(v_angle) || ' ».',
              jsonb_build_object('cible_type', p_cible_type, 'cible_value', p_cible_value, 'angle', v_angle));
    ELSE
      INSERT INTO public.tribune_articles_etouffes (id, cible_type, cible_value, cible_label, country, expire_le)
      VALUES ('etouffement-' || p_cible_type || '-' || p_requete::text, p_cible_type, p_cible_value, v_label, v_pays, now() + interval '7 days');
    END IF;
  ELSE
    v_paie := public.jets_pa_prelever_interne(a, p_mode, 1);
    IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'presse_lobbying_pa_refuses:%', v_paie ->> 'raison'; END IF;
  END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'presse_lobbying_tenter', prm, jsonb_build_object(
    'ok', true, 'mode', p_mode, 'succes', v_ok, 'taux', v_taux, 'jet', v_jet, 'cible_label', v_label,
    'cout', CASE WHEN v_ok THEN coalesce((v_paie ->> 'cout')::integer, 0) ELSE 0 END,
    'redaction_ok', CASE WHEN v_ok THEN (v_paie ->> 'redaction_ok')::boolean END, 'pa_preleves', 1)); /* jets_b1b_v1 */
END $$;

-- ── Loge : frapper à la porte (1 PA, réponse à 95 %) ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.loge_frapper(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb; p jsonb; v_jet integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'loge_frapper', '{}'::jsonb);
  IF v IS NOT NULL THEN RETURN v; END IF;
  p := public.payer_ordre_interne(a, 'demander_parler_loge', 1, 0);
  IF coalesce((p ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN p; END IF;
  v_jet := floor(random() * 100)::integer + 1;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'loge_frapper', '{}'::jsonb,
    jsonb_build_object('ok', true, 'reponse', v_jet <= 95, 'taux', 95, 'jet', v_jet)); /* jets_b1b_v1 */
END $$;

-- ── Commissaire : enquête et filature payées dans la transaction du jet ──────────────────────────────────────────────
-- Caisse du commissariat de la ville du POSTE (pays_commissariat_ville), PA du commissaire ; depuis sa propre ville.
CREATE OR REPLACE FUNCTION public.commissaire_ordre_payer_interne(p_fn text, p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_nom text; v_poste text; v_ville text; v_pays text; v_ici text; v_pa integer; v_caisse text; v_refus text; r jsonb; p jsonb;
BEGIN
  SELECT a.nom, a.poste_id, a.poste_city, a.pays INTO v_nom, v_poste, v_ville, v_pays FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF v_poste IS DISTINCT FROM 'commissaire' OR v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante'); END IF;
  SELECT current_city, pa INTO v_ici, v_pa FROM public.personnages_donnees WHERE name = v_nom FOR UPDATE;
  IF v_ici IS DISTINCT FROM v_ville THEN RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction'); END IF;
  IF coalesce(v_pa, 0) < coalesce(p_pa, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants'); END IF;
  IF public.blocus_ordre_refuse_interne(v_nom, p_fn) THEN RETURN jsonb_build_object('ok', false, 'raison', 'blocus_syndical'); END IF;
  IF coalesce(p_cost, 0) > 0 THEN
    v_caisse := v_pays || '_commissariat_' || v_ville;
    v_refus := public.caisse_refus_autorite(v_caisse, v_pays);
    IF v_refus IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', v_refus); END IF;
    r := public.caisse_institution_mouvement(v_caisse, -p_cost, true);
    IF coalesce((r ->> 'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_institution_insuffisante'); END IF;
  END IF;
  p := public.jets_pa_prelever_interne(v_nom, p_fn, p_pa);
  IF coalesce((p ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'commissaire_pa_refuses:%', p ->> 'raison'; END IF;
  RETURN jsonb_build_object('ok', true, 'nom', v_nom, 'pays', v_pays, 'ville', v_ville, 'cout', coalesce(p_cost, 0)); /* jets_b1b_v1 */
END $$;

CREATE OR REPLACE FUNCTION public.commissaire_enquete_mener(p_requete uuid, p_cible text, p_benediction boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; p jsonb; j jsonb; r jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = a THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  prm := jsonb_build_object('cible', p_cible, 'benediction', coalesce(p_benediction, false));
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'commissaire_enquete_mener', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  p := public.commissaire_ordre_payer_interne('mener_enquete', 2, 250);
  IF coalesce((p ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN p; END IF;
  -- Sans trace contre la cible dans la ville du poste : rien à instruire, conclusion « infructueuse » (sans jet).
  IF NOT EXISTS (SELECT 1 FROM public.actions_tracables t WHERE t.country = p ->> 'pays' AND t.city = p ->> 'ville'
                  AND t.auteur = p_cible AND t.decouvert IS NOT TRUE) THEN
    r := jsonb_build_object('ok', true, 'abouti', false, 'sans_trace', true, 'cout', 250);
  ELSE
    j := public.commissaire_jet_interne('enquete', p_cible, coalesce(p_benediction, false));
    IF coalesce((j ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'commissaire_jet_refuse:%', j ->> 'raison'; END IF;
    IF (j ->> 'abouti')::boolean IS NOT TRUE THEN
      r := j || jsonb_build_object('cout', 250);
    ELSE
      r := public.commissaire_enqueter(p_cible) || jsonb_build_object('abouti', true, 'taux', j -> 'taux', 'jet', j -> 'jet', 'cout', 250);
    END IF;
  END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'commissaire_enquete_mener', prm, r || jsonb_build_object('paye', true)); /* jets_b1b_v1 */
END $$;

CREATE OR REPLACE FUNCTION public.filature_mener(p_requete uuid, p_cible text, p_benediction boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; p jsonb; j jsonb; r jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_cible), '') = '' OR p_cible = a THEN RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide'); END IF;
  prm := jsonb_build_object('cible', p_cible, 'benediction', coalesce(p_benediction, false));
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'filature_mener', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  p := public.commissaire_ordre_payer_interne('organiser_filature', 2, 150);
  IF coalesce((p ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN p; END IF;
  j := public.commissaire_jet_interne('filature', p_cible, coalesce(p_benediction, false));
  IF coalesce((j ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'commissaire_jet_refuse:%', j ->> 'raison'; END IF;
  IF (j ->> 'abouti')::boolean IS NOT TRUE THEN
    r := j || jsonb_build_object('cout', 150);
  ELSE
    r := public.filature_deplacements(p_cible) || jsonb_build_object('abouti', true, 'taux', j -> 'taux', 'jet', j -> 'jet', 'cout', 150);
  END IF;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'filature_mener', prm, r || jsonb_build_object('paye', true)); /* jets_b1b_v1 */
END $$;

-- ── Corrompre un journaliste : ISN du serveur, blocus avant le jet, paiement en cas d'accord ──────────────────────────
SELECT pg_temp.rp_raccorder('public.corruption_presse_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$  v_r    jsonb; /* crim_corruption_presse_decl_v1 */$a$,
  $b$  v_r    jsonb; /* crim_corruption_presse_decl_v1 */
  v_paie jsonb; /* jets_b1b_decl_v1 */$b$, 'jets_b1b_decl_v1');
SELECT pg_temp.rp_raccorder('public.corruption_presse_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$       - LEAST(25, GREATEST(0, COALESCE(p_malus_isn, 0)))));$a$,
  $b$       - public.crime_malus_isn_interne(v_p.country, v_p.current_city))); /* jets_b1b_isn_v1 */$b$, 'jets_b1b_isn_v1');
SELECT pg_temp.rp_raccorder('public.corruption_presse_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;$a$,
  $b$  IF public.blocus_ordre_refuse_interne(p_joueur, 'corrompre_journaliste') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'blocus_syndical')); /* jets_b1b_blocus_v1 */
  END IF;
  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;$b$, 'jets_b1b_blocus_v1');
SELECT pg_temp.rp_raccorder('public.corruption_presse_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$  -- Trace fouillable par « Mener une enquete », en reussite comme en refus.$a$,
  $b$  IF v_ok THEN
    v_paie := public.presse_payer_redaction_interne(p_joueur, 'corrompre_journaliste', 2, 500);
    IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'corruption_presse_paiement_refuse:%', v_paie ->> 'raison'; END IF; /* jets_b1b_paie_v1 */
  END IF;
  -- Trace fouillable par « Mener une enquete », en reussite comme en refus.$b$, 'jets_b1b_paie_v1');
SELECT pg_temp.rp_raccorder('public.corruption_presse_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$'pa', CASE WHEN v_ok THEN 2 ELSE 0 END, 'cout', CASE WHEN v_ok THEN 500 ELSE 0 END));$a$,
  $b$'pa', CASE WHEN v_ok THEN 2 ELSE 0 END, 'cout', CASE WHEN v_ok THEN coalesce((v_paie ->> 'cout')::integer, 0) ELSE 0 END,
    'paye', v_ok, 'redaction_ok', v_paie -> 'redaction_ok', 'paie', v_paie -> 'paie')); /* jets_b1b_retour_v1 */$b$, 'jets_b1b_retour_v1');

-- ── Fabriquer un scandale : même chose ───────────────────────────────────────────────────────────────────────────────
SELECT pg_temp.rp_raccorder('public.scandale_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$  v_id   bigint;
BEGIN$a$,
  $b$  v_id   bigint;
  v_paie jsonb; /* jets_b1b_decl_v1 */
BEGIN$b$, 'jets_b1b_decl_v1');
SELECT pg_temp.rp_raccorder('public.scandale_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$  v_taux := public.scandale_taux(v_p.career, v_p.poste, p_malus_isn);$a$,
  $b$  v_taux := public.scandale_taux(v_p.career, v_p.poste, public.crime_malus_isn_interne(v_p.country, v_p.current_city)); /* jets_b1b_isn_v1 */$b$,
  'jets_b1b_isn_v1');
SELECT pg_temp.rp_raccorder('public.scandale_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;$a$,
  $b$  IF public.blocus_ordre_refuse_interne(p_joueur, 'fabriquer_scandale') THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'blocus_syndical')); /* jets_b1b_blocus_v1 */
  END IF;
  v_jour := (p_instant AT TIME ZONE 'Europe/Paris')::date;$b$, 'jets_b1b_blocus_v1');
SELECT pg_temp.rp_raccorder('public.scandale_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$  UPDATE public.scandales_tentatives SET accepte = true WHERE auteur = p_joueur AND jour_paris = v_jour;$a$,
  $b$  UPDATE public.scandales_tentatives SET accepte = true WHERE auteur = p_joueur AND jour_paris = v_jour;
  v_paie := public.presse_payer_redaction_interne(p_joueur, 'fabriquer_scandale', 3, 800);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'scandale_paiement_refuse:%', v_paie ->> 'raison'; END IF; /* jets_b1b_paie_v1 */$b$, 'jets_b1b_paie_v1');
SELECT pg_temp.rp_raccorder('public.scandale_tenter(text,text,text,text,integer,timestamptz)'::regprocedure,
  $a$'scandale_id', v_id, 'pa', 3, 'cout', 800));$a$,
  $b$'scandale_id', v_id, 'pa', 3, 'cout', coalesce((v_paie ->> 'cout')::integer, 0),
    'paye', true, 'redaction_ok', v_paie -> 'redaction_ok', 'paie', v_paie -> 'paie')); /* jets_b1b_retour_v1 */$b$, 'jets_b1b_retour_v1');

-- ── Censure (indice social) et dossiers (tirage) : après le paiement de jauges_ordre_executer ────────────────────────
CREATE OR REPLACE FUNCTION public.presse_censure_indice_interne(p_pays text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.indices_villes WHERE id LIKE p_pays || '\_%' ORDER BY id LOOP
    PERFORM public.indice_ville_ajuster_interne(p_pays, substr(r.id, length(p_pays) + 2), 'social', -8);
  END LOOP; /* jets_b1b_v1 */
END $$;
SELECT pg_temp.rp_raccorder('public.jauges_ordre_executer(text,uuid,jsonb)'::regprocedure,
  $a$  -- Relire après le paiement : aucun snapshot antérieur ne remplace les PA ou soldes.$a$,
  $b$  IF p_ordre='censurer_media' THEN
    PERFORM public.presse_censure_indice_interne(a.country);
    publication:=coalesce(publication,'{}'::jsonb)||jsonb_build_object('indice_social',-8,'indice_social_serveur',a.country='republic');
  ELSIF p_ordre='consulter_dossiers_gouv' THEN
    publication:=coalesce(publication,'{}'::jsonb)||jsonb_build_object('dossier_rang',floor(random()*6)::integer);
  END IF; /* jets_b1b_jauges_v1 */
  -- Relire après le paiement : aucun snapshot antérieur ne remplace les PA ou soldes.$b$, 'jets_b1b_jauges_v1');

-- ── Vos chances réelles ──────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ordres_chances_b1b_interne(p_nom text, p_fn text)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record; v_brut numeric;
BEGIN
  IF p_fn NOT IN ('article', 'etouffer', 'demander_parler_loge', 'corrompre_journaliste', 'fabriquer_scandale') THEN RETURN NULL; END IF;
  SELECT country, current_city, career, poste, stats, resources INTO d FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF p_fn IN ('article', 'etouffer') THEN RETURN public.presse_lobbying_taux_interne(p_nom, p_fn, false); END IF;
  IF p_fn = 'demander_parler_loge' THEN RETURN 95; END IF;
  IF p_fn = 'fabriquer_scandale' THEN RETURN public.scandale_taux(d.career, d.poste, public.crime_malus_isn_interne(d.country, d.current_city)); END IF;
  v_brut := LEAST(85, GREATEST(5, 30 + floor(public.assemblee_stat_base(d.stats, 'CHA'))::integer
    + floor(GREATEST(0, COALESCE(CASE WHEN jsonb_typeof(d.resources -> 'inf') = 'number' THEN (d.resources ->> 'inf')::numeric END, 0)) / 4)::integer
    - public.crime_malus_isn_interne(d.country, d.current_city)));
  RETURN public.crim_chance_bornee_interne(p_nom, v_brut, 0, 100, false); /* jets_b1b_chances_v1 */
END $$;
SELECT pg_temp.rp_raccorder('public.ordres_chances_lire(text[],text)'::regprocedure,
  $a$      ELSIF f = 'neutraliser' AND p_cible IS NOT NULL THEN$a$,
  $b$      ELSIF public.ordres_chances_b1b_interne(a, f) IS NOT NULL THEN
        out := out || jsonb_build_object(f, public.ordres_chances_b1b_interne(a, f)); /* jets_b1b_chances_v1 */
      ELSIF f = 'neutraliser' AND p_cible IS NOT NULL THEN$b$, 'jets_b1b_chances_v1');

REVOKE ALL ON FUNCTION public.jets_pa_prelever_interne(text, text, integer), public.presse_cha_effectif_interne(text),
  public.presse_lobbying_taux_interne(text, text, boolean), public.presse_redaction_encaisser_interne(text, numeric),
  public.presse_payer_redaction_interne(text, text, integer, integer), public.jets_html_echapper_interne(text),
  public.commissaire_ordre_payer_interne(text, integer, integer), public.presse_censure_indice_interne(text),
  public.ordres_chances_b1b_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.presse_lobbying_tenter(uuid, text, text, text, text, text), public.loge_frapper(uuid),
  public.commissaire_enquete_mener(uuid, text, boolean), public.filature_mener(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.presse_lobbying_tenter(uuid, text, text, text, text, text), public.loge_frapper(uuid),
  public.commissaire_enquete_mener(uuid, text, boolean), public.filature_mener(uuid, text, boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
