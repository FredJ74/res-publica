-- Mission du soir du 25/11/2026 (Claude), bloc 1A (point 1.4e) — NON APPLIQUÉE. Après 20261125400000.
-- « Visiter un détenu » (décision de Fred, 25/11 au soir) : aucun jet ; le serveur contrôle tout.
--   • Le détenu doit être détenu dans CETTE prison : le visiteur se trouve dans le pays, la ville et le bâtiment de la
--     détention (qhs → qhs-prison ; capitale → commissariat ; autre ville → commissariat-local, comme detention_ouvrir_interne).
--   • Une visite par jour (heure de Paris) et par détenu, pour chaque visiteur.
--   • Quartier de haute sécurité : seuls entrent un avocat inscrit au barreau du pays (avocats_barreau) et la famille
--     déclarée (conjoint par un mariage non dissous, table mariages).
--   • Un visiteur détenu lui-même ne visite personne.
--   • 1 PA (tarif d'ordres_couts « visiter_prisonnier »), payé dans la même transaction que la visite.
--   • La visite ouvre une conversation privée avec le détenu : un premier message « Visite au parloir. » y est écrit au nom
--     du visiteur, et l'écran ouvre cette conversation.
-- Sans cette migration, l'écran dit que le parloir est fermé, sans rien débiter (plus de fausse « visite effectuée »).
--
-- Contrôles en lecture après application :
--   SELECT has_function_privilege('authenticated', 'public.prison_visiter(uuid,text)', 'EXECUTE');            -- vrai
--   SELECT has_function_privilege('authenticated', 'public.prison_visite_detenus()', 'EXECUTE');              -- vrai
--   SELECT has_function_privilege('anon', 'public.prison_visiter(uuid,text)', 'EXECUTE');                     -- faux
--   SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'prison_visites';  -- 1
--   SELECT pa, cost FROM public.ordres_couts WHERE fn = 'visiter_prisonnier';                                -- 1, 0
BEGIN;

CREATE TABLE IF NOT EXISTS public.prison_visites (
  visiteur text NOT NULL,
  detenu text NOT NULL,
  jour date NOT NULL,
  detention text,
  pays text,
  ville text,
  qhs boolean NOT NULL DEFAULT false,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (visiteur, detenu, jour)
);
ALTER TABLE public.prison_visites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.prison_visites FROM PUBLIC, anon, authenticated;

-- Bâtiment de la prison d'une détention (même règle que detention_ouvrir_interne).
CREATE OR REPLACE FUNCTION public.prison_batiment_interne(p_ville text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_ville = 'qhs' THEN 'qhs-prison' WHEN coalesce(p_ville, 'capitale') = 'capitale' THEN 'commissariat' ELSE 'commissariat-local' END
$$;

-- Le visiteur peut-il entrer au QHS voir ce détenu ? Avocat inscrit au barreau du pays, ou conjoint.
CREATE OR REPLACE FUNCTION public.prison_visite_qhs_autorise_interne(p_visiteur text, p_detenu text, p_pays text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.avocats_barreau b WHERE b.nom = p_visiteur AND b.pays = p_pays)
      OR EXISTS (SELECT 1 FROM public.mariages m
                  WHERE m.dissous_at IS NULL AND coalesce(m.statut, 'actif') NOT IN ('dissous', 'annule', 'refuse')
                    AND ((m.conjoint1 = p_visiteur AND m.conjoint2 = p_detenu) OR (m.conjoint2 = p_visiteur AND m.conjoint1 = p_detenu)))
$$;

-- Détenus de la prison où se trouve le visiteur, avec ce qu'il peut faire.
CREATE OR REPLACE FUNCTION public.prison_visite_detenus()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_liste jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city, current_building INTO v FROM public.personnages_donnees WHERE name = a;
  SELECT coalesce(jsonb_agg(jsonb_build_object('nom', d.nom, 'raison', d.raison, 'qhs', coalesce(d.qhs, false),
           'deja_visite', EXISTS (SELECT 1 FROM public.prison_visites x WHERE x.visiteur = a AND x.detenu = d.nom AND x.jour = v_jour),
           'autorise', NOT coalesce(d.qhs, false) OR public.prison_visite_qhs_autorise_interne(a, d.nom, d.country)) ORDER BY d.nom), '[]'::jsonb)
    INTO v_liste
    FROM public.detentions d
   WHERE d.mode_fin IS NULL AND d.jour_fin_effective IS NULL AND d.nom <> a
     AND d.country = v.country AND coalesce(d.city, 'capitale') = coalesce(v.current_city, 'capitale')
     AND public.prison_batiment_interne(d.city) = v.current_building;
  RETURN jsonb_build_object('ok', true, 'detenus', v_liste); /* prison_visite_v1 */
END $$;

CREATE OR REPLACE FUNCTION public.prison_visiter(p_requete uuid, p_detenu text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('detenu', p_detenu); v jsonb; m record; d record;
        v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_paie jsonb; v_conv text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(btrim(p_detenu), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'prison_visiter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT country, current_city, current_building INTO m FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF (SELECT id FROM public.detention_active(a)) IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'visiteur_detenu'); END IF;
  SELECT * INTO d FROM public.detention_active(p_detenu);
  IF d.id IS NULL OR p_detenu = a THEN RETURN jsonb_build_object('ok', false, 'raison', 'detenu_introuvable'); END IF;
  IF d.country IS DISTINCT FROM m.country OR coalesce(d.city, 'capitale') IS DISTINCT FROM coalesce(m.current_city, 'capitale')
     OR public.prison_batiment_interne(d.city) IS DISTINCT FROM m.current_building THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_cette_prison'); END IF;
  IF d.qhs AND NOT public.prison_visite_qhs_autorise_interne(a, p_detenu, d.country) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'qhs_avocat_famille'); END IF;
  IF EXISTS (SELECT 1 FROM public.prison_visites x WHERE x.visiteur = a AND x.detenu = p_detenu AND x.jour = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_visite_aujourdhui'); END IF;
  v_paie := public.payer_ordre(a, 'visiter_prisonnier', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.prison_visites (visiteur, detenu, jour, detention, pays, ville, qhs)
  VALUES (a, p_detenu, v_jour, d.id, d.country, d.city, coalesce(d.qhs, false));
  -- Conversation privée (même identifiant que l'écran : les deux noms triés, joints par « __ »).
  v_conv := CASE WHEN a COLLATE "C" < p_detenu COLLATE "C" THEN a || '__' || p_detenu ELSE p_detenu || '__' || a END;
  INSERT INTO public.messages_chat (id, conversation_id, auteur, message, salon, created_at)
  VALUES ('visite-' || replace(gen_random_uuid()::text, '-', ''), v_conv, a, 'Visite au parloir.', false, now());
  RETURN public.achat_requete_clore_interne(a, p_requete, 'prison_visiter', prm,
    jsonb_build_object('ok', true, 'detenu', p_detenu, 'qhs', coalesce(d.qhs, false), 'conversation', v_conv,
      'pa', v_paie -> 'pa')); /* prison_visite_v1 */
END $$;

INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'visiter_prisonnier', 1, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'visiter_prisonnier' AND pa = 1 AND cost = 0);

REVOKE ALL ON FUNCTION public.prison_batiment_interne(text), public.prison_visite_qhs_autorise_interne(text, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prison_visite_detenus(), public.prison_visiter(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prison_visite_detenus(), public.prison_visiter(uuid, text) TO authenticated;

COMMIT;
