-- « Faire l'amour » avec une escort : une seule vérité, celle du serveur (Fred, 12/11/2026).
--
-- Jusqu'ici l'écran débitait 300, puis s'ajoutait lui-même Moral, Santé et ENT, et tenait seul le
-- palier de complicité (verre / dîner / la mer) dans son blob escort_active. Désormais :
--   * le palier vit au serveur (escorts_complicite), par escort et par employeur ;
--   * escort_intimite() fait en UN acte : vérification de l'embauche, étape éventuelle (palier + 1),
--     paiement unique (étape + 300), effets (Moral, Santé, ENT) et nouveau palier ;
--   * le gain d'ENT garde ses deux plafonds : 20 au maximum, une progression par jour réel
--     (ent_gains_quotidiens, la première donnée serveur fiable pour cette règle).
-- Barèmes repris À L'IDENTIQUE de l'écran (plateau-pnj.js) : étapes 100 / 300 / 600 ; prestation 300 ;
-- bonus par palier Moral 15/18/22/28, Santé 5/6/7/10, ENT 2/2/3/4. Même mécanisme en Sovarka
-- (GAME-DESIGN-NOVOMIRSK.md : « mêmes mécanismes qu'en Républia »), montants dans la monnaie du PJ.
BEGIN;

CREATE TABLE IF NOT EXISTS public.escorts_complicite (
  pnj_id text PRIMARY KEY,
  employeur text NOT NULL,
  palier integer NOT NULL DEFAULT 0 CHECK (palier BETWEEN 0 AND 3),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.escorts_complicite ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.escorts_complicite FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.ent_gains_quotidiens (
  personnage text PRIMARY KEY,
  jour date NOT NULL
);
ALTER TABLE public.ent_gains_quotidiens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.ent_gains_quotidiens FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.escorts_intimite_recus (
  requete uuid NOT NULL,
  acteur text NOT NULL,
  reponse jsonb NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (requete, acteur)
);
ALTER TABLE public.escorts_intimite_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.escorts_intimite_recus FROM PUBLIC, anon, authenticated;

-- Reprise des paliers que l'écran tenait (escort_active), pour les escorts encore engagées.
INSERT INTO public.escorts_complicite (pnj_id, employeur, palier)
SELECT DISTINCT ON (m.id) m.id, m.proprietaire_pj,
       least(3, greatest(0, CASE WHEN (e->>'palier') ~ '^[0-9]+$' THEN (e->>'palier')::integer ELSE 0 END))
  FROM public.pnj_membres m
  JOIN public.pnj_employes_metier em ON em.pnj_id = m.id AND em.job = 'escort'
  JOIN public.personnages_donnees d ON d.name = m.proprietaire_pj
  CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(d.escort_active) = 'array' THEN d.escort_active ELSE '[]'::jsonb END) e
 WHERE m.famille = 'employe' AND m.statut = 'actif' AND e->>'nom' = m.nom
 ORDER BY m.id
ON CONFLICT (pnj_id) DO NOTHING;

-- Gain d'ENT : plafond 20 et une seule progression par jour réel, tous mécanismes qui l'utilisent.
-- Rend le gain réellement appliqué (0 si plafonné ou déjà progressé aujourd'hui).
CREATE OR REPLACE FUNCTION public.ent_gain_quotidien_interne(p_nom text, p_gain integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_ent numeric; v_nouveau numeric;
BEGIN
  IF p_nom IS NULL OR coalesce(p_gain, 0) <= 0 THEN RETURN 0; END IF;
  SELECT coalesce((stats->>'ENT')::numeric, 0) INTO v_ent FROM public.personnages_donnees WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND OR v_ent >= 20 THEN RETURN 0; END IF;
  IF EXISTS (SELECT 1 FROM public.ent_gains_quotidiens WHERE personnage = p_nom AND jour = v_jour) THEN RETURN 0; END IF;
  v_nouveau := least(20, v_ent + p_gain);
  UPDATE public.personnages_donnees
     SET stats = jsonb_set(coalesce(stats, '{}'::jsonb), '{ENT}', to_jsonb(v_nouveau), true), updated_at = now()
   WHERE name = p_nom;
  INSERT INTO public.ent_gains_quotidiens (personnage, jour) VALUES (p_nom, v_jour)
  ON CONFLICT (personnage) DO UPDATE SET jour = EXCLUDED.jour;
  RETURN (v_nouveau - v_ent)::integer;
END $$;
REVOKE ALL ON FUNCTION public.ent_gain_quotidien_interne(text, integer) FROM PUBLIC, anon, authenticated;

-- Escort engagée par p_employeur, désignée par son nom ; rend son identifiant socle ou NULL.
CREATE OR REPLACE FUNCTION public.escort_engagee_interne(p_employeur text, p_escort text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT m.id FROM public.pnj_membres m JOIN public.pnj_employes_metier em ON em.pnj_id = m.id
   WHERE m.famille = 'employe' AND m.proprietaire_pj = p_employeur AND m.statut = 'actif'
     AND em.job = 'escort' AND m.nom = p_escort
   ORDER BY m.id LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.escort_engagee_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Palier courant ; un changement d'employeur repart de zéro.
CREATE OR REPLACE FUNCTION public.escort_palier_interne(p_pnj text, p_employeur text)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT palier FROM public.escorts_complicite WHERE pnj_id = p_pnj AND employeur = p_employeur), 0);
$$;
REVOKE ALL ON FUNCTION public.escort_palier_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Lecture pour l'écran : le palier qu'il doit afficher (propositions verre / dîner / la mer).
CREATE OR REPLACE FUNCTION public.escort_complicite(p_escort text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_pnj text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v_pnj := public.escort_engagee_interne(moi, p_escort);
  IF v_pnj IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'escort_non_engagee'); END IF;
  RETURN jsonb_build_object('ok', true, 'escort', p_escort, 'palier', public.escort_palier_interne(v_pnj, moi));
END $$;
REVOKE ALL ON FUNCTION public.escort_complicite(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escort_complicite(text) TO authenticated;

-- L'acte complet. p_palier_vise NULL : faire l'amour au palier courant ; sinon étape (palier + 1)
-- puis faire l'amour au nouveau palier, payés ensemble ou pas du tout.
CREATE OR REPLACE FUNCTION public.escort_intimite(p_requete uuid, p_escort text, p_palier_vise integer DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE moi text := public.mon_personnage(); v_ancien jsonb; v_pnj text; v_avant integer; v_palier integer;
  v_cout_etape integer := 0; c_prestation constant integer := 300; v_total integer; v_debit jsonb;
  v_moral integer; v_hp integer; v_ent integer; v_ent_gagne integer; v_rep jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_requise'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('escort_intimite:' || moi, 0));
  SELECT reponse INTO v_ancien FROM public.escorts_intimite_recus WHERE requete = p_requete AND acteur = moi;
  IF v_ancien IS NOT NULL THEN RETURN v_ancien || jsonb_build_object('rejeu', true); END IF;

  v_pnj := public.escort_engagee_interne(moi, p_escort);
  IF v_pnj IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'escort_non_engagee'); END IF;
  PERFORM 1 FROM public.pnj_membres WHERE id = v_pnj FOR UPDATE;
  v_avant := public.escort_palier_interne(v_pnj, moi);
  v_palier := v_avant;
  IF p_palier_vise IS NOT NULL THEN
    IF p_palier_vise <> v_avant + 1 OR p_palier_vise > 3 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'etape_invalide', 'palier', v_avant); END IF;
    v_cout_etape := CASE p_palier_vise WHEN 1 THEN 100 WHEN 2 THEN 300 WHEN 3 THEN 600 END;
    v_palier := p_palier_vise;
  END IF;
  v_total := v_cout_etape + c_prestation;

  -- Paiement unique (liquide d'abord, puis Banque nationale) ; refus = aucun effet.
  v_debit := public.debiter_fonds_ordinaires(moi, v_total);
  IF coalesce((v_debit->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_debit->>'raison', 'fonds_insuffisants'), 'total', v_total, 'palier', v_avant); END IF;

  INSERT INTO public.escorts_complicite (pnj_id, employeur, palier, updated_at) VALUES (v_pnj, moi, v_palier, now())
  ON CONFLICT (pnj_id) DO UPDATE SET employeur = EXCLUDED.employeur, palier = EXCLUDED.palier, updated_at = now();

  v_moral := (ARRAY[15, 18, 22, 28])[v_palier + 1];
  v_hp    := (ARRAY[5, 6, 7, 10])[v_palier + 1];
  v_ent   := (ARRAY[2, 2, 3, 4])[v_palier + 1];
  UPDATE public.personnages_donnees
     SET moral = least(100, coalesce(moral, 75) + v_moral), hp = least(100, coalesce(hp, 100) + v_hp), updated_at = now()
   WHERE name = moi;
  v_ent_gagne := public.ent_gain_quotidien_interne(moi, v_ent);

  SELECT jsonb_build_object('ok', true, 'escort', p_escort, 'palier_avant', v_avant, 'palier', v_palier,
           'cout_etape', v_cout_etape, 'cout_prestation', c_prestation, 'total', v_total,
           'gain_moral', v_moral, 'gain_hp', v_hp, 'gain_ent', v_ent_gagne,
           'moral', d.moral, 'hp', d.hp, 'ent', coalesce((d.stats->>'ENT')::numeric, 0),
           'liquide', d.liquide, 'arg', d.arg,
           'solde_national', coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage = moi AND banque = 'nationale'), 0))
    INTO v_rep FROM public.personnages_donnees d WHERE d.name = moi;
  INSERT INTO public.escorts_intimite_recus (requete, acteur, reponse) VALUES (p_requete, moi, v_rep);
  RETURN v_rep;
END $$;
REVOKE ALL ON FUNCTION public.escort_intimite(uuid, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escort_intimite(uuid, text, integer) TO authenticated;

-- Contrôles structurels (aucun appel réel : le mécanisme est éprouvé dans le banc annulé).
DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.escorts_complicite', 'SELECT')
     OR has_table_privilege('authenticated', 'public.ent_gains_quotidiens', 'SELECT')
     OR has_function_privilege('authenticated', 'public.ent_gain_quotidien_interne(text,integer)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.escort_intimite(uuid,text,integer)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.escort_intimite(uuid,text,integer)', 'EXECUTE')
     OR position('debiter_fonds_ordinaires' IN pg_get_functiondef('public.escort_intimite(uuid,text,integer)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'escort_intimite_serveur : contrôle structurel en échec';
  END IF;
END $$;

COMMIT;
