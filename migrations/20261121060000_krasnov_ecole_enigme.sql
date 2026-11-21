-- LOT DE KRASNOV (1re partie), point 7 — école et énigme de Krasnov (Fred, 20/11/2026). GAME-DESIGN-KRASNOV-LOT-20261120.md.
--  • École : « Stage de survie en forêt » dispensé par l'institutrice Alevtina Gramotova — +4 VOL pendant 24 h, 3 PA +
--    25 PSK versés à la caisse de la mairie de Krasnov. (Les ordres copiés de l'université sont retirés à l'écran.)
--  • Guide des baies sauvages : lecture 2 PA, +1 INT pendant 24 h (inchangé), UNE FOIS PAR SEMAINE ; vendu au musée de
--    Krasnov (prix provisoire 10 PSK, à fixer par Fred), plus au marché.
--  • Feuille volante glissée dans chaque guide : objet d'inventaire échangeable, qui ne disparaît jamais ; elle porte
--    l'énigme et une recette polycopiée incomplète. La résolution est attachée au PERSONNAGE (enigmes_resolues), pas à
--    la feuille : celle-ci n'est « utilisable dans l'armoire aux souvenirs » (souvenir_utilisable) que si son porteur a
--    résolu l'énigme.
--  • Résolution : la réponse (la graisse d'ours) se donne au directeur du musée de Krasnov ; énigme résolue = une
--    distinction et une ligne dans la liste des énigmes résolues du personnage.
-- Idempotente.
BEGIN;

CREATE TABLE IF NOT EXISTS public.lectures_hebdo (
  personnage text NOT NULL, cle text NOT NULL, lu_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (personnage, cle));
ALTER TABLE public.lectures_hebdo ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lectures_hebdo FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.enigmes_resolues (
  personnage text NOT NULL, enigme text NOT NULL, resolu_le timestamptz NOT NULL DEFAULT now(), distinction text NOT NULL,
  PRIMARY KEY (personnage, enigme));
ALTER TABLE public.enigmes_resolues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.enigmes_resolues FROM anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT v.f, v.pa, v.c FROM (VALUES ('stage_survie_foret', 3, 25), ('acheter_guide_baies_musee', 0, 10), ('repondre_enigme_krasnov', 0, 0)) v(f, pa, c)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v.f);

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- Guide : une lecture par semaine.
SELECT pg_temp.rp_raccorder('public.guide_baies_lire_interne(text)'::regprocedure,
  $a$  v := public.payer_ordre(p_acteur, 'lire_guide_baies', 2, 0);$a$,
  $b$  IF EXISTS (SELECT 1 FROM public.lectures_hebdo WHERE personnage = p_acteur AND cle = 'guide_baies' AND lu_le > now() - interval '7 days') THEN /* guide_hebdo_v1 */
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_lu_cette_semaine',
      'prochaine', (SELECT lu_le + interval '7 days' FROM public.lectures_hebdo WHERE personnage = p_acteur AND cle = 'guide_baies'));
  END IF;
  v := public.payer_ordre(p_acteur, 'lire_guide_baies', 2, 0);
  INSERT INTO public.lectures_hebdo (personnage, cle, lu_le) VALUES (p_acteur, 'guide_baies', now())
  ON CONFLICT (personnage, cle) DO UPDATE SET lu_le = now();$b$,
  'guide_hebdo_v1');

-- Objets : guide et feuille volante.
CREATE OR REPLACE FUNCTION public.krasnov_guide_objet_interne()
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('name', 'Guide des baies sauvages de Krasnov', 'icon', 'ti-book', 'type', 'guide_baies_krasnov',
    'stackable', true, 'stackKey', 'guide_baies_krasnov', 'qty', 1, 'legal', true,
    'desc', 'Airelles, myrtilles, camarine… et celles qu''il ne faut surtout pas manger. Une lecture par semaine : +1 INT pendant 24 h.');
$$;
CREATE OR REPLACE FUNCTION public.krasnov_feuille_objet_interne()
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('name', 'Feuille volante glissée dans le guide', 'icon', 'ti-file-description', 'type', 'feuille_enigme_krasnov',
    'enigme', 'krasnov', 'souvenir', true, 'stackable', true, 'stackKey', 'feuille_enigme_krasnov', 'qty', 1, 'legal', true,
    'desc', 'Une recette polycopiée, à moitié effacée : « Eau pure, myrtilles, un œuf, vodka… et ██████. » Au dos, d''une écriture serrée : '
         || '« Cet ingrédient servait parfois pur à éloigner les ours des essaims sauvages. » Ici commence l''énigme de Krasnov.');
$$;

-- Stage de survie en forêt (école de Krasnov).
CREATE OR REPLACE FUNCTION public.stage_survie_foret_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_now numeric; v_eff jsonb; v_paie jsonb; v_caisse text;
BEGIN
  SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF (p.country, p.current_city, p.current_building, p.current_room) IS DISTINCT FROM ('soviet', 'ville_b', 'universite', 'amphi') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  v_now := floor(extract(epoch FROM clock_timestamp()) * 1000);
  SELECT coalesce(jsonb_agg(e), '[]'::jsonb) INTO v_eff FROM public.personnages_donnees d, jsonb_array_elements(coalesce(d.effets_actifs, '[]'::jsonb)) e
   WHERE d.name = p_acteur AND jsonb_typeof(e) = 'object' AND coalesce((e->>'expireA')::numeric, 0) > v_now;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_eff) e WHERE e->>'cle' = 'stage_survie_vol') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'effet_deja_actif'); END IF;
  v_paie := public.payer_ordre(p_acteur, 'stage_survie_foret', 3, 25);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_caisse := public.salaire_caisse_de('maire', 'soviet', 'ville_b');
  IF v_caisse IS NOT NULL THEN
    UPDATE public.caisses_batiments SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('solde',
      coalesce(CASE WHEN jsonb_typeof(data->'solde') = 'number' THEN (data->>'solde')::numeric END, 0) + 25), updated_at = now()
     WHERE id = v_caisse;
  END IF;
  v_eff := v_eff || jsonb_build_array(jsonb_build_object('cle', 'stage_survie_vol', 'cible', 'pj', 'deltas', jsonb_build_object('VOL', 4),
    'libelle', 'Stage de survie en forêt', 'poseA', v_now, 'expireA', v_now + 24 * 3600 * 1000));
  UPDATE public.personnages_donnees SET effets_actifs = v_eff, updated_at = now() WHERE name = p_acteur;
  RETURN jsonb_build_object('ok', true, 'bonusVol', 4, 'expireA', v_now + 24 * 3600 * 1000, 'effets_actifs', v_eff, 'mairie', v_caisse IS NOT NULL)
         || jsonb_build_object('pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
END $$;
REVOKE ALL ON FUNCTION public.stage_survie_foret_interne(text) FROM PUBLIC, anon, authenticated;

-- Guide au musée de Krasnov : le guide et sa feuille volante.
CREATE OR REPLACE FUNCTION public.guide_baies_musee_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_paie jsonb; v_dep jsonb; v_dep2 jsonb; v_premiere boolean;
BEGIN
  SELECT country, current_city, current_building, inventory INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF (p.country, p.current_city, p.current_building) IS DISTINCT FROM ('soviet', 'ville_b', 'musee-novomirsk') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF public.inventaire_place_restante(coalesce(p.inventory, '[]'::jsonb)) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(p_acteur, 'acheter_guide_baies_musee', 0, 10);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_premiere := NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(p.inventory, '[]'::jsonb)) o WHERE o->>'type' = 'feuille_enigme_krasnov');
  v_dep := public.inventaire_deposer_interne(p_acteur, public.krasnov_guide_objet_interne());
  v_dep2 := public.inventaire_deposer_interne(p_acteur, public.krasnov_feuille_objet_interne());
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE OR coalesce((v_dep2->>'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'guide_baies_musee : dépôt refusé'; END IF;
  RETURN jsonb_build_object('ok', true, 'paye', 10, 'premiere_feuille', v_premiere,
    'resolue', EXISTS (SELECT 1 FROM public.enigmes_resolues WHERE personnage = p_acteur AND enigme = 'krasnov'))
    || jsonb_build_object('pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
END $$;
REVOKE ALL ON FUNCTION public.guide_baies_musee_interne(text) FROM PUBLIC, anon, authenticated;

-- Réponse à l'énigme, donnée au directeur du musée.
CREATE OR REPLACE FUNCTION public.enigme_krasnov_repondre_interne(p_acteur text, p_reponse text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_norm text;
BEGIN
  SELECT country, current_city, current_building, inventory INTO p FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF (p.country, p.current_city, p.current_building) IS DISTINCT FROM ('soviet', 'ville_b', 'musee-novomirsk') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;
  IF EXISTS (SELECT 1 FROM public.enigmes_resolues WHERE personnage = p_acteur AND enigme = 'krasnov') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_resolue'); END IF;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(p.inventory, '[]'::jsonb)) o WHERE o->>'type' = 'feuille_enigme_krasnov') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_feuille'); END IF;
  v_norm := lower(translate(coalesce(p_reponse, ''), 'ÉÈÊËÀÂÎÏÔÛÙÇéèêëàâîïôûùç’''-', 'EEEEAAIIOUUCeeeeaaiiouuc   '));
  IF v_norm !~ 'graisse' OR v_norm !~ '\mours\M' THEN
    RETURN jsonb_build_object('ok', true, 'resolue', false);
  END IF;
  INSERT INTO public.enigmes_resolues (personnage, enigme, distinction) VALUES (p_acteur, 'krasnov', 'Résolveur de l''énigme de Krasnov')
  ON CONFLICT DO NOTHING;
  RETURN jsonb_build_object('ok', true, 'resolue', true, 'distinction', 'Résolveur de l''énigme de Krasnov');
END $$;
REVOKE ALL ON FUNCTION public.enigme_krasnov_repondre_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Liste des énigmes résolues du joueur (colonne de l'inventaire).
CREATE OR REPLACE FUNCTION public.enigmes_lire()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', true, 'enigmes', coalesce(jsonb_agg(jsonb_build_object('enigme', e.enigme, 'resolu_le', e.resolu_le,
           'distinction', e.distinction) ORDER BY e.resolu_le), '[]'::jsonb))
    FROM public.enigmes_resolues e WHERE e.personnage = public.mon_personnage();
$$;
REVOKE ALL ON FUNCTION public.enigmes_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enigmes_lire() TO authenticated;

-- La feuille n'est utilisable dans l'armoire aux souvenirs que si son porteur a résolu l'énigme.
CREATE OR REPLACE FUNCTION public.souvenir_utilisable_interne(p_acteur text, p_objet jsonb)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN p_objet->>'type' = 'feuille_enigme_krasnov'
              THEN EXISTS (SELECT 1 FROM public.enigmes_resolues WHERE personnage = p_acteur AND enigme = 'krasnov')
              ELSE true END;
$$;
REVOKE ALL ON FUNCTION public.souvenir_utilisable_interne(text, jsonb) FROM PUBLIC, anon, authenticated;

-- Enveloppes à clé d'unicité.
CREATE OR REPLACE FUNCTION public.krasnov_ecole_agir(p_requete uuid, p_action text, p_texte text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('action', p_action, 'texte', p_texte); v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_action NOT IN ('stage_survie', 'acheter_guide', 'repondre_enigme') THEN RETURN jsonb_build_object('ok', false, 'raison', 'action_inconnue'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'krasnov_ecole_agir', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := CASE p_action WHEN 'stage_survie' THEN public.stage_survie_foret_interne(a)
                       WHEN 'acheter_guide' THEN public.guide_baies_musee_interne(a)
                       ELSE public.enigme_krasnov_repondre_interne(a, p_texte) END;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'krasnov_ecole_agir', prm, v);
END $$;
REVOKE ALL ON FUNCTION public.krasnov_ecole_agir(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.krasnov_ecole_agir(uuid, text, text) TO authenticated;

-- Le guide n'est plus vendu au marché de Krasnov (il passe au musée).
UPDATE public.commerces_dotations SET carte = carte - 'guide_baies_krasnov',
       parametres = jsonb_set(jsonb_set(parametres, '{stockMax}', (parametres->'stockMax') - 'guide_baies_krasnov'), '{prixVente}', (parametres->'prixVente') - 'guide_baies_krasnov')
 WHERE cle = 'marche@soviet.ville_b' AND carte ? 'guide_baies_krasnov';
UPDATE public.entreprises SET data = jsonb_set(data, '{carte}', (data->'carte') - 'guide_baies_krasnov')
 WHERE jsonb_typeof(data->'carte') = 'array' AND data->'carte' ? 'guide_baies_krasnov';

COMMIT;
