-- MALADIES — LOT 1 : SOCLE (GAME-DESIGN-MALADIES-CLIMAT.md §§ 1, 2 et 11 ; décisions de Fred du 18/11/2026).
--  * Catalogue paramétrable `maladies_parametres` : tous les réglages sont modifiables par le MJ (page d'administration).
--  * Maladies des personnages `personnages_maladies` : une maladie active au plus par sorte ; malus portés par les
--    effets temporaires existants (`effets_actifs`, lus par getStatEffective) ; plafond de PA (grippe) ; bonus d'arme
--    supprimé (gueule de bois) dans les batailles.
--  * Guérison : médicament adapté pris -> guéri au prochain Dormir ; sinon à l'échéance.
--  * Risques : viande crue (15 %), alcool (30 % à partir du 3e verre du jour de Paris).
--  * Pharmacie : pharmacie d'État de Novomirsk et salle des ventes de l'usine pharmaceutique de Luthécia (Républia),
--    stock journalier réglable (0 = pénurie), prix = 2 x prix de base des médicaments sauf prix fixé par le MJ.
--  * Symptômes visibles des seules personnes présentes dans la pièce de l'observateur ; jamais le nom de la maladie.
-- Aucune donnée de joueur modifiée. Idempotente.
BEGIN;

-- ── Catalogue ────────────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maladies_parametres (
  cle             text PRIMARY KEY,
  actif           boolean NOT NULL DEFAULT true,
  deltas          jsonb   NOT NULL DEFAULT '{}'::jsonb,        -- {"INT":-2,"CHA":-1}
  pa_max          integer CHECK (pa_max IS NULL OR pa_max BETWEEN 0 AND 30),
  sans_bonus_arme boolean NOT NULL DEFAULT false,
  duree_heures    integer NOT NULL CHECK (duree_heures BETWEEN 1 AND 2400),
  medicament      text    NOT NULL,                            -- clé du médicament adapté
  contagieuse     boolean NOT NULL DEFAULT false,
  risques         jsonb   NOT NULL DEFAULT '{}'::jsonb,        -- pourcentages par circonstance
  prix_fixe       integer CHECK (prix_fixe IS NULL OR prix_fixe >= 0),
  stock_journalier integer NOT NULL DEFAULT 20 CHECK (stock_journalier >= 0),
  nom_mj          text,                                        -- renommage temporaire du MJ (texte libre)
  symptome_mj     text,                                        -- symptôme temporaire du MJ (texte libre)
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      text
);
ALTER TABLE public.maladies_parametres ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.maladies_parametres FROM anon, authenticated;

INSERT INTO public.maladies_parametres (cle, deltas, pa_max, sans_bonus_arme, duree_heures, medicament, contagieuse, risques) VALUES
  ('intoxication',   '{"CHA":-2}',          NULL, false, 72, 'antinauseeux',       false, '{"viande_crue":15,"aliment_avarie":50,"plat_avarie":20}'),
  ('gueule_de_bois', '{"INT":-1,"CHA":-1}', NULL, true,  24, 'aspirine',           false, '{"verre":30,"verres_sans_risque":2}'),
  ('grippe',         '{"INT":-2}',          15,   false, 96, 'antigrippal',        true,  '{"piece":30,"interaction":70}'),
  ('coup_de_chaleur','{"INT":-1,"CHA":-1}', NULL, false, 48, 'sels_rehydratation', false, '{}')
ON CONFLICT (cle) DO NOTHING;

-- ── Maladies des personnages ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.personnages_maladies (
  id         bigserial PRIMARY KEY,
  nom        text NOT NULL,
  cle        text NOT NULL REFERENCES public.maladies_parametres(cle),
  source     text NOT NULL,
  debut      timestamptz NOT NULL DEFAULT now(),
  fin        timestamptz NOT NULL,
  traitee_le timestamptz,
  guerie_le  timestamptz,
  motif_fin  text,
  vue_le     timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS personnages_maladies_active_uk ON public.personnages_maladies(nom, cle) WHERE guerie_le IS NULL;
CREATE INDEX IF NOT EXISTS personnages_maladies_nom_idx ON public.personnages_maladies(nom) WHERE guerie_le IS NULL;
ALTER TABLE public.personnages_maladies ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.personnages_maladies FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.personnages_maladies_id_seq FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.verres_du_jour (
  nom  text NOT NULL,
  jour date NOT NULL,
  n    integer NOT NULL DEFAULT 0,
  PRIMARY KEY (nom, jour)
);
ALTER TABLE public.verres_du_jour ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.verres_du_jour FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.pharmacies_points_vente (
  id       text PRIMARY KEY,
  pays     text NOT NULL,
  ville    text NOT NULL,
  batiment text NOT NULL,
  piece    text NOT NULL,
  caisse_entreprise text                      -- entreprise créditée (pharmacie d'État), sinon recette perdue pour l'État
);
ALTER TABLE public.pharmacies_points_vente ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pharmacies_points_vente FROM anon, authenticated;
INSERT INTO public.pharmacies_points_vente (id, pays, ville, batiment, piece, caisse_entreprise) VALUES
  ('pharmacie-novomirsk', 'soviet',   'capitale', 'pharmacie-officielle-novomirsk', 'comptoir_pharmacie', 'pharmacie-soviet-capitale'),
  ('usine-pharma-luthecia', 'republic', 'capitale', 'usine-pharmaceutique-luthecia', 'salle_ventes', NULL)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.pharmacies_ventes (
  point      text NOT NULL REFERENCES public.pharmacies_points_vente(id),
  jour       date NOT NULL,
  medicament text NOT NULL,
  vendus     integer NOT NULL DEFAULT 0,
  PRIMARY KEY (point, jour, medicament)
);
ALTER TABLE public.pharmacies_ventes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pharmacies_ventes FROM anon, authenticated;

-- ── Fonctions internes ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.maladie_risque_interne(p_cle text, p_circonstance text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN m.actif THEN coalesce((m.risques->>p_circonstance)::numeric, 0) ELSE 0 END
    FROM public.maladies_parametres m WHERE m.cle = p_cle;
$$;

-- Effet temporaire miroir (lu par le client) : une entrée « maladie_<cle> » par maladie active.
CREATE OR REPLACE FUNCTION public.maladie_effets_synchroniser_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_now numeric := extract(epoch FROM clock_timestamp()) * 1000; v_base jsonb; v_eff jsonb;
BEGIN
  SELECT CASE WHEN jsonb_typeof(effets_actifs) = 'array' THEN effets_actifs ELSE '[]'::jsonb END
    INTO v_base FROM public.personnages_donnees WHERE name = p_nom;
  IF NOT FOUND THEN RETURN '[]'::jsonb; END IF;
  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_eff FROM jsonb_array_elements(v_base) e
   WHERE jsonb_typeof(e) = 'object' AND coalesce(e->>'cle', '') NOT LIKE 'maladie\_%'
     AND coalesce((e->>'expireA')::numeric, 0) > v_now;
  SELECT v_eff || coalesce(jsonb_agg(jsonb_build_object(
           'cle', 'maladie_' || pm.cle, 'cible', 'pj', 'deltas', mp.deltas,
           'capacite', CASE WHEN mp.sans_bonus_arme THEN 'sans_bonus_arme' END,
           'paMax', mp.pa_max, 'maladie', pm.cle,
           'libelle', coalesce(mp.nom_mj, pm.cle), 'poseA', extract(epoch FROM pm.debut) * 1000,
           'expireA', extract(epoch FROM pm.fin) * 1000)), '[]'::jsonb)
    INTO v_eff
    FROM public.personnages_maladies pm JOIN public.maladies_parametres mp ON mp.cle = pm.cle
   WHERE pm.nom = p_nom AND pm.guerie_le IS NULL AND pm.fin > now();
  UPDATE public.personnages_donnees SET effets_actifs = v_eff WHERE name = p_nom;
  RETURN v_eff;
END $$;

-- Échéances passées : guérison automatique.
CREATE OR REPLACE FUNCTION public.maladies_echeances_interne(p_nom text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_n integer;
BEGIN
  UPDATE public.personnages_maladies SET guerie_le = now(), motif_fin = 'echeance'
   WHERE nom = p_nom AND guerie_le IS NULL AND fin <= now();
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n > 0 THEN PERFORM public.maladie_effets_synchroniser_interne(p_nom); END IF;
  RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION public.maladie_contracter_interne(p_nom text, p_cle text, p_source text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE m public.maladies_parametres; v_id bigint;
BEGIN
  SELECT * INTO m FROM public.maladies_parametres WHERE cle = p_cle;
  IF NOT FOUND OR NOT m.actif THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom) THEN RETURN NULL; END IF;
  PERFORM public.maladies_echeances_interne(p_nom);
  IF EXISTS (SELECT 1 FROM public.personnages_maladies WHERE nom = p_nom AND cle = p_cle AND guerie_le IS NULL) THEN
    RETURN NULL;   -- déjà malade : pas de cumul ni de prolongation
  END IF;
  INSERT INTO public.personnages_maladies (nom, cle, source, fin)
  VALUES (p_nom, p_cle, coalesce(p_source, 'inconnue'), now() + make_interval(hours => m.duree_heures))
  RETURNING id INTO v_id;
  PERFORM public.maladie_effets_synchroniser_interne(p_nom);
  RETURN jsonb_build_object('id', v_id, 'cle', p_cle, 'nom_mj', m.nom_mj, 'symptome_mj', m.symptome_mj,
                            'duree_heures', m.duree_heures);
END $$;

-- Tirage au sort : renvoie la maladie contractée, ou NULL.
CREATE OR REPLACE FUNCTION public.maladie_tirer_interne(p_nom text, p_cle text, p_pourcentage numeric, p_source text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF coalesce(p_pourcentage, 0) <= 0 THEN RETURN NULL; END IF;
  IF random() * 100 >= p_pourcentage THEN RETURN NULL; END IF;
  RETURN public.maladie_contracter_interne(p_nom, p_cle, p_source);
END $$;

CREATE OR REPLACE FUNCTION public.maladie_guerir_interne(p_nom text, p_cle text, p_motif text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_n integer;
BEGIN
  UPDATE public.personnages_maladies SET guerie_le = now(), motif_fin = p_motif
   WHERE nom = p_nom AND guerie_le IS NULL AND (p_cle IS NULL OR cle = p_cle);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM public.maladie_effets_synchroniser_interne(p_nom);
  RETURN v_n > 0;
END $$;

-- Au Dormir : maladies traitées et échues guéries. Renvoie les clés guéries.
CREATE OR REPLACE FUNCTION public.maladies_nuit_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb;
BEGIN
  WITH g AS (
    UPDATE public.personnages_maladies SET guerie_le = now(),
           motif_fin = CASE WHEN traitee_le IS NOT NULL THEN 'medicament' ELSE 'echeance' END
     WHERE nom = p_nom AND guerie_le IS NULL AND (traitee_le IS NOT NULL OR fin <= now())
    RETURNING cle)
  SELECT coalesce(jsonb_agg(cle), '[]'::jsonb) INTO v FROM g;
  IF jsonb_array_length(v) > 0 THEN PERFORM public.maladie_effets_synchroniser_interne(p_nom); END IF;
  RETURN v;
END $$;

-- Plafond de PA : le plus bas des maladies actives ; des PA déjà au-dessus ne sont jamais retirés.
CREATE OR REPLACE FUNCTION public.maladie_pa_plafond_interne(p_nom text, p_pa_actuel integer)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN x.cap IS NULL OR x.cap >= 30 THEN 30 ELSE least(30, greatest(x.cap, coalesce(p_pa_actuel, 0))) END
    FROM (SELECT min(mp.pa_max) cap FROM public.personnages_maladies pm
            JOIN public.maladies_parametres mp ON mp.cle = pm.cle
           WHERE pm.nom = p_nom AND pm.guerie_le IS NULL AND pm.fin > now() AND mp.pa_max IS NOT NULL) x;
$$;

CREATE OR REPLACE FUNCTION public.maladie_sans_bonus_arme_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_maladies pm JOIN public.maladies_parametres mp ON mp.cle = pm.cle
                  WHERE pm.nom = p_nom AND pm.guerie_le IS NULL AND pm.fin > now() AND mp.sans_bonus_arme);
$$;

-- Un verre bu (jour de Paris) : les premiers sont sans risque, puis tirage de gueule de bois.
CREATE OR REPLACE FUNCTION public.maladie_verre_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_n integer; v_libres integer;
BEGIN
  INSERT INTO public.verres_du_jour (nom, jour, n) VALUES (p_nom, (now() AT TIME ZONE 'Europe/Paris')::date, 1)
  ON CONFLICT (nom, jour) DO UPDATE SET n = public.verres_du_jour.n + 1
  RETURNING n INTO v_n;
  v_libres := coalesce((SELECT (risques->>'verres_sans_risque')::integer FROM public.maladies_parametres WHERE cle = 'gueule_de_bois'), 2);
  IF v_n <= v_libres THEN RETURN NULL; END IF;
  RETURN public.maladie_tirer_interne(p_nom, 'gueule_de_bois', public.maladie_risque_interne('gueule_de_bois', 'verre'), 'alcool');
END $$;

REVOKE ALL ON FUNCTION public.maladie_risque_interne(text, text), public.maladie_effets_synchroniser_interne(text),
  public.maladies_echeances_interne(text), public.maladie_contracter_interne(text, text, text),
  public.maladie_tirer_interne(text, text, numeric, text), public.maladie_guerir_interne(text, text, text),
  public.maladies_nuit_interne(text), public.maladie_pa_plafond_interne(text, integer),
  public.maladie_sans_bonus_arme_interne(text), public.maladie_verre_interne(text) FROM PUBLIC, anon, authenticated;

-- ── Lectures des joueurs ─────────────────────────────────────────────────────────────────────────
-- Mes maladies (le malade connaît la sienne) ; marque les nouvelles comme vues.
CREATE OR REPLACE FUNCTION public.maladies_mes_maladies()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM public.maladies_echeances_interne(a);
  SELECT coalesce(jsonb_agg(jsonb_build_object('cle', pm.cle, 'nom_mj', mp.nom_mj, 'symptome_mj', mp.symptome_mj,
           'medicament', mp.medicament, 'fin', pm.fin, 'traitee', pm.traitee_le IS NOT NULL, 'nouvelle', pm.vue_le IS NULL,
           'deltas', mp.deltas, 'pa_max', mp.pa_max, 'sans_bonus_arme', mp.sans_bonus_arme) ORDER BY pm.debut), '[]'::jsonb)
    INTO v FROM public.personnages_maladies pm JOIN public.maladies_parametres mp ON mp.cle = pm.cle
   WHERE pm.nom = a AND pm.guerie_le IS NULL;
  UPDATE public.personnages_maladies SET vue_le = now() WHERE nom = a AND guerie_le IS NULL AND vue_le IS NULL;
  RETURN jsonb_build_object('ok', true, 'maladies', v,
    'effets_actifs', (SELECT effets_actifs FROM public.personnages_donnees WHERE name = a));
END $$;

-- Symptômes des personnes présentes dans MA pièce (jamais le nom de la maladie).
CREATE OR REPLACE FUNCTION public.maladies_symptomes_piece()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); moi record; v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building, current_room INTO moi FROM public.personnages_donnees WHERE name = a;
  SELECT coalesce(jsonb_object_agg(x.nom, x.s), '{}'::jsonb) INTO v FROM (
    SELECT pm.nom, jsonb_agg(jsonb_build_object('symptome', pm.cle, 'symptome_mj', mp.symptome_mj) ORDER BY pm.debut) s
      FROM public.personnages_maladies pm
      JOIN public.maladies_parametres mp ON mp.cle = pm.cle
      JOIN public.personnages_donnees d ON d.name = pm.nom
     WHERE pm.guerie_le IS NULL AND pm.fin > now() AND pm.nom <> a
       AND (d.country, d.current_city, d.current_building, d.current_room)
           IS NOT DISTINCT FROM (moi.country, moi.current_city, moi.current_building, moi.current_room)
       AND moi.current_room IS NOT NULL
     GROUP BY pm.nom) x;
  RETURN jsonb_build_object('ok', true, 'symptomes', v);
END $$;

-- ── Pharmacie ────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.pharmacie_point_interne(p_acteur text)
RETURNS public.pharmacies_points_vente LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT pv.* FROM public.pharmacies_points_vente pv JOIN public.personnages_donnees d ON d.name = p_acteur
   WHERE d.country = pv.pays AND d.current_city = pv.ville AND d.current_building = pv.batiment AND d.current_room = pv.piece;
$$;

CREATE OR REPLACE FUNCTION public.pharmacie_prix_interne(p_cle_maladie text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(m.prix_fixe, (SELECT greatest(1, round(2 * prix_base))::integer FROM public.ressources_economie WHERE cle = 'medicaments'), 44)
    FROM public.maladies_parametres m WHERE m.cle = p_cle_maladie;
$$;

CREATE OR REPLACE FUNCTION public.pharmacie_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); pv public.pharmacies_points_vente; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  pv := public.pharmacie_point_interne(a);
  IF pv.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_pharmacie'); END IF;
  RETURN jsonb_build_object('ok', true, 'point', pv.id, 'medicaments', (
    SELECT coalesce(jsonb_agg(jsonb_build_object('medicament', m.medicament, 'maladie', m.cle, 'nom_mj', m.nom_mj,
             'prix', public.pharmacie_prix_interne(m.cle),
             'restant', greatest(0, m.stock_journalier - coalesce(s.vendus, 0))) ORDER BY m.cle), '[]'::jsonb)
      FROM public.maladies_parametres m
      LEFT JOIN public.pharmacies_ventes s ON s.point = pv.id AND s.jour = v_jour AND s.medicament = m.medicament
     WHERE m.actif));
END $$;

CREATE OR REPLACE FUNCTION public.pharmacie_acheter_interne(p_acteur text, p_medicament text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE pv public.pharmacies_points_vente; m public.maladies_parametres; v jsonb; v_prix integer; v_total numeric;
        v_vendus integer; v_fonds numeric; v_debit numeric; v_dep jsonb; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  IF p_qte IS NULL OR p_qte < 1 OR p_qte > 10 THEN RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  pv := public.pharmacie_point_interne(p_acteur);
  IF pv.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_a_la_pharmacie'); END IF;
  SELECT * INTO m FROM public.maladies_parametres WHERE medicament = p_medicament AND actif;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'medicament_inconnu'); END IF;
  INSERT INTO public.pharmacies_ventes (point, jour, medicament, vendus) VALUES (pv.id, v_jour, p_medicament, 0)
  ON CONFLICT DO NOTHING;
  SELECT vendus INTO v_vendus FROM public.pharmacies_ventes WHERE point = pv.id AND jour = v_jour AND medicament = p_medicament FOR UPDATE;
  IF m.stock_journalier - v_vendus <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'rupture'); END IF;
  IF p_qte > m.stock_journalier - v_vendus THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'restant', m.stock_journalier - v_vendus); END IF;
  v_prix := public.pharmacie_prix_interne(m.cle);
  v_total := v_prix * p_qte;
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires b
           WHERE b.personnage = d.name AND b.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds FROM public.personnages_donnees d WHERE d.name = p_acteur;
  IF v_fonds < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total, 'disponible', v_fonds); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = p_acteur) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(p_acteur, 'pharmacie_medicaments', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_debit := public.argent_debiter_interne(p_acteur, v_total, 'liquide_puis_nationale');
  IF v_debit IS DISTINCT FROM v_total THEN RAISE EXCEPTION 'pharmacie_acheter: debit incomplet % / %', v_debit, v_total; END IF;
  UPDATE public.pharmacies_ventes SET vendus = vendus + p_qte WHERE point = pv.id AND jour = v_jour AND medicament = p_medicament;
  IF pv.caisse_entreprise IS NOT NULL THEN
    UPDATE public.entreprises
       SET data = jsonb_set(data, '{caisse}', to_jsonb(coalesce((data->>'caisse')::numeric, 0) + v_total)), updated_at = now()
     WHERE id = pv.caisse_entreprise;
  END IF;
  v_dep := public.inventaire_deposer_interne(p_acteur, jsonb_build_object('name', CASE p_medicament WHEN 'antinauseeux' THEN 'Anti-nauséeux' WHEN 'aspirine' THEN 'Aspirine' WHEN 'antigrippal' THEN 'Antigrippal' WHEN 'sels_rehydratation' THEN 'Sels de réhydratation' ELSE p_medicament END, 'icon', 'ti-pill',
    'type', 'medicament_maladie', 'medicament', p_medicament, 'soigne', m.cle,
    'stackable', true, 'stackKey', 'medicament_' || p_medicament, 'qty', p_qte));
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'pharmacie_acheter: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'medicament', p_medicament, 'quantite', p_qte, 'prix', v_prix, 'paye', v_total,
    'restant', m.stock_journalier - v_vendus - p_qte)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'liquide', liquide)
          FROM public.personnages_donnees WHERE name = p_acteur);
END $$;

CREATE OR REPLACE FUNCTION public.pharmacie_acheter(p_requete uuid, p_medicament text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('medicament', p_medicament, 'qte', p_qte); v jsonb; d text;
BEGIN
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'pharmacie_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.pharmacie_acheter_interne(a, p_medicament, p_qte);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'pharmacie_acheter', prm, v);
END $$;

-- Prendre un médicament de maladie : refusé s'il ne soigne aucune maladie active (pas de prise préventive).
CREATE OR REPLACE FUNCTION public.medicament_prendre(p_requete uuid, p_medicament text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('medicament', p_medicament); v jsonb; l jsonb;
        v_cle text; v_inv jsonb; i integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'medicament_prendre', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT cle INTO v_cle FROM public.maladies_parametres WHERE medicament = p_medicament;
  IF v_cle IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'medicament_inconnu'); END IF;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  PERFORM public.maladies_echeances_interne(a);
  IF NOT EXISTS (SELECT 1 FROM public.personnages_maladies WHERE nom = a AND cle = v_cle AND guerie_le IS NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_maladie_a_traiter'); END IF;
  IF EXISTS (SELECT 1 FROM public.personnages_maladies WHERE nom = a AND cle = v_cle AND guerie_le IS NULL AND traitee_le IS NOT NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_traitee'); END IF;
  l := public.sovarka_inventaire_ligne_interne(v_inv, ARRAY['medicament_' || p_medicament]);
  IF (l->>'i')::integer < 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_medicament'); END IF;
  PERFORM public.sovarka_inventaire_retirer_interne(a, l, 1);
  UPDATE public.personnages_maladies SET traitee_le = now() WHERE nom = a AND cle = v_cle AND guerie_le IS NULL;
  v := jsonb_build_object('ok', true, 'medicament', p_medicament, 'maladie', v_cle)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'medicament_prendre', prm, v);
END $$;

REVOKE ALL ON FUNCTION public.pharmacie_point_interne(text), public.pharmacie_prix_interne(text),
  public.pharmacie_acheter_interne(text, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.maladies_mes_maladies(), public.maladies_symptomes_piece(), public.pharmacie_etat(),
  public.pharmacie_acheter(uuid, text, integer), public.medicament_prendre(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.maladies_mes_maladies(), public.maladies_symptomes_piece(), public.pharmacie_etat(),
  public.pharmacie_acheter(uuid, text, integer), public.medicament_prendre(uuid, text) TO authenticated;

-- ── Outils du MJ (administrateurs) ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_maladies_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true,
    'parametres', (SELECT coalesce(jsonb_agg(to_jsonb(m) ORDER BY m.cle), '[]'::jsonb) FROM public.maladies_parametres m),
    'malades', (SELECT coalesce(jsonb_agg(jsonb_build_object('nom', nom, 'cle', cle, 'source', source, 'debut', debut, 'fin', fin,
                 'traitee', traitee_le IS NOT NULL) ORDER BY debut DESC), '[]'::jsonb)
                  FROM public.personnages_maladies WHERE guerie_le IS NULL AND fin > now()),
    'points_vente', (SELECT coalesce(jsonb_agg(to_jsonb(p) ORDER BY p.id), '[]'::jsonb) FROM public.pharmacies_points_vente p));
END $$;

-- Modifie un ou plusieurs paramètres d'une maladie (« qui peut le plus peut le moins »).
CREATE OR REPLACE FUNCTION public.admin_maladie_modifier(p_cle text, p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE k text; v_admin text := auth.uid()::text;
BEGIN
  PERFORM public.admin_exiger();
  IF NOT EXISTS (SELECT 1 FROM public.maladies_parametres WHERE cle = p_cle) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maladie_inconnue'); END IF;
  IF jsonb_typeof(p_parametres) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  FOR k IN SELECT jsonb_object_keys(p_parametres) LOOP
    IF k NOT IN ('actif','deltas','pa_max','sans_bonus_arme','duree_heures','medicament','contagieuse','risques',
                 'prix_fixe','stock_journalier','nom_mj','symptome_mj') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'parametre_inconnu', 'parametre', k); END IF;
  END LOOP;
  UPDATE public.maladies_parametres m SET
    actif           = CASE WHEN p_parametres ? 'actif' THEN (p_parametres->>'actif')::boolean ELSE m.actif END,
    deltas          = CASE WHEN p_parametres ? 'deltas' THEN p_parametres->'deltas' ELSE m.deltas END,
    pa_max          = CASE WHEN p_parametres ? 'pa_max' THEN (p_parametres->>'pa_max')::integer ELSE m.pa_max END,
    sans_bonus_arme = CASE WHEN p_parametres ? 'sans_bonus_arme' THEN (p_parametres->>'sans_bonus_arme')::boolean ELSE m.sans_bonus_arme END,
    duree_heures    = CASE WHEN p_parametres ? 'duree_heures' THEN (p_parametres->>'duree_heures')::integer ELSE m.duree_heures END,
    medicament      = CASE WHEN p_parametres ? 'medicament' THEN p_parametres->>'medicament' ELSE m.medicament END,
    contagieuse     = CASE WHEN p_parametres ? 'contagieuse' THEN (p_parametres->>'contagieuse')::boolean ELSE m.contagieuse END,
    risques         = CASE WHEN p_parametres ? 'risques' THEN p_parametres->'risques' ELSE m.risques END,
    prix_fixe       = CASE WHEN p_parametres ? 'prix_fixe' THEN (p_parametres->>'prix_fixe')::integer ELSE m.prix_fixe END,
    stock_journalier= CASE WHEN p_parametres ? 'stock_journalier' THEN (p_parametres->>'stock_journalier')::integer ELSE m.stock_journalier END,
    nom_mj          = CASE WHEN p_parametres ? 'nom_mj' THEN nullif(btrim(p_parametres->>'nom_mj'), '') ELSE m.nom_mj END,
    symptome_mj     = CASE WHEN p_parametres ? 'symptome_mj' THEN nullif(btrim(p_parametres->>'symptome_mj'), '') ELSE m.symptome_mj END,
    updated_at = now(), updated_by = v_admin
  WHERE m.cle = p_cle;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, ok)
  VALUES (auth.uid(), 'MJ', 'maladie_modifier', jsonb_build_object('cle', p_cle) || p_parametres, true);
  RETURN jsonb_build_object('ok', true, 'parametres', (SELECT to_jsonb(m) FROM public.maladies_parametres m WHERE m.cle = p_cle));
END $$;

-- Inflige (déclenchement à la main) ou guérit une maladie ; p_nom NULL = tous les malades (fin d'épidémie).
CREATE OR REPLACE FUNCTION public.admin_maladie_infliger(p_nom text, p_cle text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v jsonb;
BEGIN
  PERFORM public.admin_exiger();
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom) THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v := public.maladie_contracter_interne(p_nom, p_cle, 'mj');
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'maladie_infliger', jsonb_build_object('nom', p_nom, 'cle', p_cle), v, v IS NOT NULL);
  RETURN jsonb_build_object('ok', v IS NOT NULL, 'raison', CASE WHEN v IS NULL THEN 'deja_malade_ou_inactive' END, 'maladie', v);
END $$;

CREATE OR REPLACE FUNCTION public.admin_maladie_guerir(p_nom text, p_cle text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_n integer := 0; x record;
BEGIN
  PERFORM public.admin_exiger();
  FOR x IN SELECT DISTINCT nom FROM public.personnages_maladies
            WHERE guerie_le IS NULL AND (p_nom IS NULL OR nom = p_nom) AND (p_cle IS NULL OR cle = p_cle) LOOP
    IF public.maladie_guerir_interne(x.nom, p_cle, CASE WHEN p_nom IS NULL THEN 'fin_epidemie' ELSE 'mj' END) THEN v_n := v_n + 1; END IF;
  END LOOP;
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, parametres, resultat, ok)
  VALUES (auth.uid(), 'MJ', 'maladie_guerir', jsonb_build_object('nom', p_nom, 'cle', p_cle), jsonb_build_object('gueris', v_n), true);
  RETURN jsonb_build_object('ok', true, 'gueris', v_n);
END $$;

REVOKE ALL ON FUNCTION public.admin_maladies_lire(), public.admin_maladie_modifier(text, jsonb),
  public.admin_maladie_infliger(text, text), public.admin_maladie_guerir(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_maladies_lire(), public.admin_maladie_modifier(text, jsonb),
  public.admin_maladie_infliger(text, text), public.admin_maladie_guerir(text, text) TO authenticated;

-- ── Raccords dans les fonctions existantes (doctrine pg_get_functiondef + ancre unique) ───────────
DO $raccords$
DECLARE d text; a text; n integer;
BEGIN
  -- 1. Dormir : guérison des maladies traitées ou échues, puis plafond de PA.
  d := pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure);
  IF position('maladies_nuit_interne' IN d) = 0 THEN
    a := E'  -- hospitalisation_pa0_repos_v2';
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'pa_repos_nocturne : ancrage maladies'; END IF;
    d := replace(d, a, E'  -- maladies_nuit_v1 (Fred, 18/11/2026) : médicament pris ou échéance passée -> guéri au Dormir.\n  PERFORM public.maladies_nuit_interne(p_acteur);\n' || a);
    a := 'least(c_pa_max, greatest(0, v_pa + v_gain';
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    IF n <> 2 THEN RAISE EXCEPTION 'pa_repos_nocturne : ancrage plafond (% occurrences)', n; END IF;
    d := replace(d, a, 'least(public.maladie_pa_plafond_interne(p_acteur, v_pa), greatest(0, v_pa + v_gain');
    EXECUTE d;
  END IF;

  -- 2. Aliment consommé : gain immédiat plafonné par la grippe.
  d := pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure);
  IF position('maladie_pa_plafond_interne' IN d) = 0 THEN
    a := 'SET pa=least(30,greatest(0,coalesce(pa,0)+v_delta))';
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'inventaire_consommer : ancrage'; END IF;
    EXECUTE replace(d, a, 'SET pa=least(public.maladie_pa_plafond_interne(p_acteur,coalesce(pa,0)),greatest(0,coalesce(pa,0)+v_delta))');
  END IF;

  -- 3. Viande crue mangée : 15 % d'intoxication.
  d := pg_get_functiondef('public.matiere_brute_manger_interne(text,text)'::regprocedure);
  IF position('maladie_tirer_interne' IN d) = 0 THEN
    a := $a$RETURN jsonb_build_object('ok', true, 'matiere', p_matiere,$a$;
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'matiere_brute_manger_interne : ancrage'; END IF;
    EXECUTE replace(d, a, $b$RETURN jsonb_build_object('ok', true, 'maladie', CASE WHEN p_matiere = 'viande' THEN public.maladie_tirer_interne(p_acteur, 'intoxication', public.maladie_risque_interne('intoxication', 'viande_crue'), 'viande_crue') END, 'matiere', p_matiere,$b$);
  END IF;

  -- 4. Tournée servie : un verre par buveur.
  d := pg_get_functiondef('public.tournee_cloturer_boire(text)'::regprocedure);
  IF position('maladie_verre_interne' IN d) = 0 THEN
    a := $a$   v_r:=jsonb_build_object('ok',true,'servie',true,$a$;
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'tournee_cloturer_boire : ancrage'; END IF;
    EXECUTE replace(d, a, E'   PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x; -- maladies_alcool_v1\n' || a);
  END IF;

  -- 5. Trinquer chez l'habitant (Sovarka) : un verre.
  d := pg_get_functiondef('public.sovarka_maison_agir(text,text)'::regprocedure);
  IF position('maladie_verre_interne' IN d) = 0 THEN
    a := $a$    v_ville := public.sovarka_maison_secret_ville_interne(m->>'id', a);$a$;
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'sovarka_maison_agir : ancrage'; END IF;
    EXECUTE replace(d, a, E'    r := jsonb_build_object(''maladie'', public.maladie_verre_interne(a)); -- maladies_alcool_v1\n' || a);
  END IF;

  -- 6. Batailles : bonus d'arme supprimé pour un personnage qui en est privé (gueule de bois).
  d := pg_get_functiondef('public.militaire_bataille_combattants'::regproc);
  IF position('maladie_sans_bonus_arme_interne' IN d) = 0 THEN
    a := 'coalesce(af.bonus, ac.bonus, 0),';
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'militaire_bataille_combattants : ancrage'; END IF;
    EXECUTE replace(d, a, 'CASE WHEN public.maladie_sans_bonus_arme_interne(pd.name) THEN 0 ELSE coalesce(af.bonus, ac.bonus, 0) END,');
  END IF;
END $raccords$;

-- Trinquer : la réponse finale écrase r ; garder la maladie tirée.
DO $trinquer$
DECLARE d text; a text;
BEGIN
  d := pg_get_functiondef('public.sovarka_maison_agir(text,text)'::regprocedure);
  IF position('''maladie'', r->''maladie''' IN d) = 0 THEN
    a := $a$    r := jsonb_build_object('ok', true, 'action', 'trinquer',$a$;
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'sovarka_maison_agir : ancrage trinquer'; END IF;
    EXECUTE replace(d, a, $b$    r := jsonb_build_object('ok', true, 'maladie', r->'maladie', 'action', 'trinquer',$b$);
  END IF;
END $trinquer$;

DO $$ BEGIN
  IF (SELECT count(*) FROM public.maladies_parametres) < 4
     OR position('maladies_nuit_interne' IN pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure)) = 0
     OR position('maladie_pa_plafond_interne' IN pg_get_functiondef('public.inventaire_consommer(text,integer,jsonb)'::regprocedure)) = 0
     OR position('maladie_tirer_interne' IN pg_get_functiondef('public.matiere_brute_manger_interne(text,text)'::regprocedure)) = 0
     OR position('maladie_verre_interne' IN pg_get_functiondef('public.tournee_cloturer_boire(text)'::regprocedure)) = 0
     OR position('maladie_verre_interne' IN pg_get_functiondef('public.sovarka_maison_agir(text,text)'::regprocedure)) = 0
     OR position('maladie_sans_bonus_arme_interne' IN pg_get_functiondef('public.militaire_bataille_combattants'::regproc)) = 0
  THEN RAISE EXCEPTION 'maladies_socle : controle structurel en echec'; END IF;
END $$;
COMMIT;
