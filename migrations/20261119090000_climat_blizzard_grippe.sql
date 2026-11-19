-- MALADIES, PÉREMPTION ET CLIMAT — LOT 4 : blizzard, graisses, tableau de la grippe, contagion (GAME-DESIGN-MALADIES-CLIMAT.md §§ 2 et 5).
-- • Blizzard : chaque ville de Sovarka une fois par mandat présidentiel, dates tirées au hasard (différentes), alerte 48 h avant
--   (socle du lot 3). Au début : toutes les personnes présentes dans la ville perdent 3 PA, sauf celles qui portent un bocal
--   de graisse (consommé) ; puis risque de grippe selon les PA restants (tableau du § 5), moins 5 points avec la graisse.
-- • Graisses : renne (magasin du kolkhoze de Starovka, déjà en vente), castor (poissonnière de Novomirsk), ours (marché de
--   Krasnov, étals du kolkhoze) ; vendables aussi dans toute pharmacie ouverte par un PJ (le propriétaire y dépose ses bocaux).
-- • Contagion (maladies contagieuses, la grippe) : 30 % pour qui a partagé la pièce d'un malade dans la journée, 70 % en cas
--   d'interaction directe (tournée, dîner) ; un seul tirage par jour et par malade croisé, au niveau le plus élevé, à la fin
--   de la journée. Tous les taux sont ceux du catalogue des maladies (réglables par le MJ).
BEGIN;

INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('prix_graisse', 15) ON CONFLICT (cle) DO NOTHING;
ALTER TABLE public.climat_evenements ADD COLUMN IF NOT EXISTS effets_le timestamptz;
INSERT INTO public.climat_parametres (type, pays, frequence, par_periode, delai_min, delai_max, bloque_chantiers)
VALUES ('blizzard', 'soviet', 'mandat', 1, 0, 0, true) ON CONFLICT (type, pays) DO NOTHING;

-- ── Risque selon les PA restants (blizzard ; aussi coup de chaleur au lot 5) ────────────────────
CREATE OR REPLACE FUNCTION public.maladie_risque_pa_interne(p_pa integer, p_hospitalise boolean)
RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_hospitalise THEN 0
              WHEN p_pa >= 26 THEN 0 WHEN p_pa >= 21 THEN 10 WHEN p_pa >= 16 THEN 25
              WHEN p_pa >= 11 THEN 50 WHEN p_pa >= 6 THEN 65 ELSE 80 END::numeric;
$$;

-- ── Graisses ─────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.graisse_objet_interne(p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('name', CASE p_cle WHEN 'graisse_castor' THEN 'Bocal de graisse de castor' ELSE 'Bocal de graisse d''ours' END,
    'icon', 'ti-jar', 'type', 'graisse', 'graisse', p_cle, 'stackable', true, 'stackKey', p_cle, 'qty', p_qte, 'legal', true,
    'imageUrl', CASE p_cle WHEN 'graisse_castor' THEN 'images/objet-graisse-castor.webp' ELSE 'images/objet-graisse-ours.webp' END,
    'desc', 'Un bocal de graisse contre le froid : protège du blizzard (consommé).');
$$;
-- Toutes les graisses qui protègent du blizzard, renne comprise (objet du kolkhoze de Starovka).
CREATE OR REPLACE FUNCTION public.graisse_cles_interne()
RETURNS text[] LANGUAGE sql IMMUTABLE AS $$ SELECT ARRAY['graisse_castor', 'graisse_ours', 'kolkhoze_graisse_renne']; $$;

CREATE TABLE IF NOT EXISTS public.graisses_points_vente (
  id text PRIMARY KEY, pays text NOT NULL, ville text NOT NULL, batiment text NOT NULL, piece text NOT NULL, cle text NOT NULL
);
ALTER TABLE public.graisses_points_vente ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.graisses_points_vente FROM anon, authenticated;
INSERT INTO public.graisses_points_vente (id, pays, ville, batiment, piece, cle) VALUES
  ('poissonniere-novomirsk', 'soviet', 'capitale', 'poissonniere-novomirsk', 'etal_poissonniere', 'graisse_castor'),
  ('marche-krasnov',         'soviet', 'ville_b',  'marche',                 'marche_ext',        'graisse_ours')
ON CONFLICT (id) DO NOTHING;

-- Pharmacie ouverte par un PJ dans la pièce du personnage (fonds dont l'activité comprend « pharmacie »).
CREATE OR REPLACE FUNCTION public.pharmacie_pj_de_la_piece_interne(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT e.id FROM public.entreprises e JOIN public.personnages_donnees d ON d.name = p_nom
   WHERE coalesce((e.data->>'version')::numeric, 0) >= 2 AND coalesce(e.data->'typesAutorises', '[]'::jsonb) ? 'pharmacie'
     AND e.data->'implantation'->>'country' = d.country AND e.data->'implantation'->>'city' = d.current_city
     AND e.data->'implantation'->>'buildingId' = d.current_building AND e.data->'implantation'->>'roomId' = d.current_room
   ORDER BY e.id LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.graisse_etat()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); pv public.graisses_points_vente; v_f text; v_g jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT g.* INTO pv FROM public.graisses_points_vente g JOIN public.personnages_donnees d ON d.name = a
   WHERE d.country = g.pays AND d.current_city = g.ville AND d.current_building = g.batiment AND d.current_room = g.piece;
  IF pv.id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'point', pv.id, 'prix', public.aliments_param_interne('prix_graisse', 15),
      'offre', jsonb_build_array(jsonb_build_object('cle', pv.cle, 'restant', NULL)));
  END IF;
  v_f := public.pharmacie_pj_de_la_piece_interne(a);
  IF v_f IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_graisse_ici'); END IF;
  SELECT coalesce(data->'graisses', '{}'::jsonb) INTO v_g FROM public.entreprises WHERE id = v_f;
  RETURN jsonb_build_object('ok', true, 'point', 'pharmacie_pj', 'prix', public.aliments_param_interne('prix_graisse', 15),
    'offre', (SELECT coalesce(jsonb_agg(jsonb_build_object('cle', key, 'restant', value::integer)), '[]'::jsonb)
                FROM jsonb_each_text(v_g) WHERE value ~ '^[0-9]+$' AND value::integer > 0));
END $$;

CREATE OR REPLACE FUNCTION public.graisse_acheter(p_requete uuid, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cle', p_cle, 'qte', p_qte); v jsonb; pv public.graisses_points_vente;
        v_f text; v_stock integer; v_prix numeric; v_total numeric; v_fonds numeric; v_debit numeric; v_dep jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'graisse_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_cle IS NULL OR NOT (p_cle = ANY (public.graisse_cles_interne())) OR p_qte IS NULL OR p_qte < 1 OR p_qte > 10 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  SELECT g.* INTO pv FROM public.graisses_points_vente g JOIN public.personnages_donnees d ON d.name = a
   WHERE d.country = g.pays AND d.current_city = g.ville AND d.current_building = g.batiment AND d.current_room = g.piece AND g.cle = p_cle;
  IF pv.id IS NULL THEN
    v_f := public.pharmacie_pj_de_la_piece_interne(a);
    IF v_f IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_graisse_ici'); END IF;
    SELECT coalesce((data->'graisses'->>p_cle)::integer, 0) INTO v_stock FROM public.entreprises WHERE id = v_f FOR UPDATE;
    IF v_stock < p_qte THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'restant', v_stock); END IF;
  END IF;
  v_prix := public.aliments_param_interne('prix_graisse', 15);
  v_total := v_prix * p_qte;
  SELECT coalesce(d.liquide, 0) + coalesce((SELECT solde FROM public.comptes_bancaires c WHERE c.personnage = d.name AND c.banque = 'nationale' ORDER BY id LIMIT 1), 0)
    INTO v_fonds FROM public.personnages_donnees d WHERE d.name = a;
  IF v_fonds < v_total THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total); END IF;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = a) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v := public.payer_ordre(a, 'acheter_graisse', 0, 0);
  IF coalesce((v->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v; END IF;
  v_debit := public.argent_debiter_interne(a, v_total, 'liquide_puis_nationale');
  IF v_debit IS DISTINCT FROM v_total THEN RAISE EXCEPTION 'graisse_acheter: debit incomplet'; END IF;
  IF v_f IS NOT NULL THEN
    UPDATE public.entreprises SET data = jsonb_set(jsonb_set(data, ARRAY['graisses', p_cle], to_jsonb(v_stock - p_qte)),
           '{caisse}', to_jsonb(coalesce((data->>'caisse')::numeric, 0) + v_total)), updated_at = now() WHERE id = v_f;
  END IF;
  v_dep := public.inventaire_deposer_interne(a, CASE WHEN p_cle = 'kolkhoze_graisse_renne'
             THEN jsonb_build_object('name', 'Bocal de graisse de renne', 'icon', 'ti-jar', 'stackable', true, 'stackKey', p_cle, 'qty', p_qte, 'legal', true)
             ELSE public.graisse_objet_interne(p_cle, p_qte) END);
  IF coalesce((v_dep->>'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'graisse_acheter: depot refuse %', v_dep; END IF;
  v := jsonb_build_object('ok', true, 'cle', p_cle, 'quantite', p_qte, 'paye', v_total)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision, 'liquide', liquide) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'graisse_acheter', prm, v);
END $$;

-- Le propriétaire d'une pharmacie PJ y dépose des bocaux de son inventaire (stock de la boutique).
CREATE OR REPLACE FUNCTION public.fonds_graisses_deposer(p_requete uuid, p_cle text, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('cle', p_cle, 'qte', p_qte); v jsonb; v_f text; v_inv jsonb; v_n integer;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'fonds_graisses_deposer', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  IF p_cle IS NULL OR NOT (p_cle = ANY (public.graisse_cles_interne())) OR coalesce(p_qte, 0) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;
  v_f := public.pharmacie_pj_de_la_piece_interne(a);
  IF v_f IS NULL OR (SELECT replace(coalesce(data->>'proprietaire', ''), 'pj:', '') FROM public.entreprises WHERE id = v_f) <> a THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_ma_pharmacie'); END IF;
  PERFORM 1 FROM public.entreprises WHERE id = v_f FOR UPDATE;
  SELECT coalesce(inventory, '[]'::jsonb) INTO v_inv FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  IF public.inventaire_quantite(v_inv, p_cle) < p_qte THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_graisse'); END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(v_inv, p_cle, p_qte), updated_at = now() WHERE name = a;
  UPDATE public.entreprises SET data = jsonb_set(data, '{graisses}', coalesce(data->'graisses', '{}'::jsonb)
           || jsonb_build_object(p_cle, coalesce((data->'graisses'->>p_cle)::integer, 0) + p_qte), true), updated_at = now()
   WHERE id = v_f RETURNING (data->'graisses'->>p_cle)::integer INTO v_n;
  v := jsonb_build_object('ok', true, 'cle', p_cle, 'quantite', p_qte, 'stock', v_n)
    || (SELECT jsonb_build_object('inventory', inventory, 'revision', inventory_revision) FROM public.personnages_donnees WHERE name = a);
  RETURN public.achat_requete_clore_interne(a, p_requete, 'fonds_graisses_deposer', prm, v);
END $$;

INSERT INTO public.ordres_couts (fn, pa, cost) SELECT 'acheter_graisse', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'acheter_graisse' AND pa = 0 AND cost = 0);

-- ── Calendrier du blizzard : une fois par mandat présidentiel et par ville ─────────────────────
CREATE OR REPLACE FUNCTION public.climat_planifier_mandat_interne()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE c public.climat_parametres; v_fin date; v_min date; v_periode text; v_jours date[]; v_villes text[]; i integer; v_n integer := 0; v_ms numeric;
BEGIN
  FOR c IN SELECT * FROM public.climat_parametres WHERE actif AND frequence = 'mandat' LOOP
    SELECT (data::jsonb->>'dateFinMandat')::numeric INTO v_ms FROM public.cycles_electoraux
     WHERE country = c.pays AND poste_id = 'president' AND left(btrim(data), 1) = '{' ORDER BY updated_at DESC NULLS LAST LIMIT 1;
    IF v_ms IS NULL THEN CONTINUE; END IF;
    v_fin := (to_timestamp(v_ms / 1000) AT TIME ZONE 'Europe/Paris')::date - 1;
    v_min := (now() AT TIME ZONE 'Europe/Paris')::date + ceil(c.preavis_heures / 24.0)::integer + 1;
    v_periode := 'mandat-' || v_ms::bigint;
    IF v_fin < v_min + 2 OR EXISTS (SELECT 1 FROM public.climat_evenements WHERE type = c.type AND pays = c.pays AND periode = v_periode AND origine = 'calendrier') THEN CONTINUE; END IF;
    v_villes := public.climat_villes_interne(c.pays);
    SELECT array_agg(d) INTO v_jours FROM (SELECT d::date FROM generate_series(v_min, v_fin, interval '1 day') d ORDER BY random() LIMIT array_length(v_villes, 1)) s;
    FOR i IN 1 .. coalesce(array_length(v_jours, 1), 0) LOOP
      IF public.climat_creer_interne(c.type, c.pays, v_villes[i], v_jours[i], v_periode, 'calendrier') IS NOT NULL THEN v_n := v_n + 1; END IF;
    END LOOP;
  END LOOP;
  RETURN v_n;
END $$;

-- ── Effets au début d'un événement (une fois) ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.climat_blizzard_appliquer_interne(e public.climat_evenements)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE p record; v_cle text; v_pa integer; v_pct numeric; v_n integer := 0; v_hosp boolean;
BEGIN
  FOR p IN SELECT name, coalesce(inventory, '[]'::jsonb) inv, coalesce(pa, 0) pa, hospitalisation FROM public.personnages_donnees
            WHERE country = e.pays AND current_city = e.ville FOR UPDATE LOOP
    v_hosp := coalesce(p.hospitalisation, 'null'::jsonb) NOT IN ('null'::jsonb, '{}'::jsonb, 'false'::jsonb);
    SELECT x INTO v_cle FROM unnest(public.graisse_cles_interne()) x WHERE public.inventaire_quantite(p.inv, x) >= 1 LIMIT 1;
    IF v_cle IS NOT NULL THEN
      UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(p.inv, v_cle, 1), updated_at = now() WHERE name = p.name;
      v_pa := p.pa;
    ELSE
      v_pa := greatest(0, p.pa - 3);
      UPDATE public.personnages_donnees SET pa = v_pa, updated_at = now() WHERE name = p.name;
    END IF;
    v_pct := greatest(0, public.maladie_risque_pa_interne(v_pa, v_hosp) - CASE WHEN v_cle IS NOT NULL THEN 5 ELSE 0 END);
    PERFORM public.maladie_tirer_interne(p.name, 'grippe', v_pct, 'blizzard');
    INSERT INTO public.climat_effets_personnages (evenement, nom, effets)
    VALUES (e.id, p.name, jsonb_build_object('graisse', v_cle, 'pa_perdus', CASE WHEN v_cle IS NULL THEN least(3, p.pa) ELSE 0 END, 'risque', v_pct))
    ON CONFLICT DO NOTHING;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $$;

-- Ce que chaque personnage a subi (lu par l'écran pour un message dans sa langue).
CREATE TABLE IF NOT EXISTS public.climat_effets_personnages (
  evenement bigint NOT NULL REFERENCES public.climat_evenements(id), nom text NOT NULL, effets jsonb NOT NULL DEFAULT '{}'::jsonb,
  vu boolean NOT NULL DEFAULT false, cree_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (evenement, nom)
);
ALTER TABLE public.climat_effets_personnages ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.climat_effets_personnages FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.climat_effets_passe_interne()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e public.climat_evenements; v_n integer := 0;
BEGIN
  FOR e IN SELECT * FROM public.climat_evenements WHERE NOT annule AND alerte_le IS NOT NULL AND effets_le IS NULL
            AND now() >= debut AND now() < fin ORDER BY debut FOR UPDATE LOOP
    IF e.type = 'blizzard' THEN PERFORM public.climat_blizzard_appliquer_interne(e); END IF;
    -- Les effets des autres types (brouillard, orage, crue, canicule) se branchent ici au lot 5.
    UPDATE public.climat_evenements SET effets_le = now() WHERE id = e.id;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION public.climat_effets_lire()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  WITH lus AS (UPDATE public.climat_effets_personnages x SET vu = true FROM public.climat_evenements e
                WHERE x.nom = a AND NOT x.vu AND e.id = x.evenement RETURNING e.type, x.effets)
  SELECT coalesce(jsonb_agg(jsonb_build_object('type', type) || effets), '[]'::jsonb) INTO v FROM lus;
  RETURN jsonb_build_object('ok', true, 'effets', v);
END $$;

-- ── Contagion ────────────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.maladies_contacts (
  nom text NOT NULL, source text NOT NULL, cle text NOT NULL, jour date NOT NULL, niveau text NOT NULL CHECK (niveau IN ('piece', 'interaction')),
  tire boolean NOT NULL DEFAULT false, PRIMARY KEY (nom, source, cle, jour)
);
ALTER TABLE public.maladies_contacts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.maladies_contacts FROM anon, authenticated;

-- Contact entre deux personnages : chacun note les maladies contagieuses de l'autre, au niveau le plus élevé atteint.
CREATE OR REPLACE FUNCTION public.maladie_contact_interne(p_a text, p_b text, p_niveau text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN RETURN; END IF;
  INSERT INTO public.maladies_contacts (nom, source, cle, jour, niveau)
  SELECT x.cible, x.source, m.cle, v_jour, p_niveau
    FROM (VALUES (p_a, p_b), (p_b, p_a)) x(cible, source)
    JOIN public.personnages_maladies m ON m.nom = x.source AND m.guerie_le IS NULL
    JOIN public.maladies_parametres mp ON mp.cle = m.cle AND mp.contagieuse AND mp.actif
   WHERE EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = x.cible)
  ON CONFLICT (nom, source, cle, jour) DO UPDATE SET niveau = CASE WHEN public.maladies_contacts.niveau = 'interaction' OR EXCLUDED.niveau = 'interaction'
                                                                   THEN 'interaction' ELSE 'piece' END;
END $$;

-- Passe horaire : partage de pièce avec un malade contagieux ; tirages des journées terminées.
CREATE OR REPLACE FUNCTION public.maladies_contagion_passe_interne()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_pieces integer := 0; v_tirages integer := 0;
BEGIN
  INSERT INTO public.maladies_contacts (nom, source, cle, jour, niveau)
  SELECT DISTINCT o.name, s.name, m.cle, v_jour, 'piece'
    FROM public.personnages_maladies m
    JOIN public.maladies_parametres mp ON mp.cle = m.cle AND mp.contagieuse AND mp.actif
    JOIN public.personnages_donnees s ON s.name = m.nom
    JOIN public.personnages_donnees o ON o.name <> s.name AND o.country = s.country AND o.current_city = s.current_city
     AND o.current_building = s.current_building AND o.current_room = s.current_room AND s.current_room IS NOT NULL
   WHERE m.guerie_le IS NULL
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_pieces = ROW_COUNT;
  FOR r IN SELECT * FROM public.maladies_contacts WHERE NOT tire AND jour < v_jour FOR UPDATE LOOP
    PERFORM public.maladie_tirer_interne(r.nom, r.cle, public.maladie_risque_interne(r.cle, r.niveau), 'contagion');
    UPDATE public.maladies_contacts SET tire = true WHERE nom = r.nom AND source = r.source AND cle = r.cle AND jour = r.jour;
    v_tirages := v_tirages + 1;
  END LOOP;
  DELETE FROM public.maladies_contacts WHERE tire AND jour < v_jour - 14;
  RETURN jsonb_build_object('pieces', v_pieces, 'tirages', v_tirages);
END $$;

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

-- Interactions directes : tournée (organisateur et chaque buveur), dîners (les deux convives joueurs).
SELECT pg_temp.rp_raccorder('public.tournee_cloturer_boire(text)'::regprocedure,
  $a$PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x WHERE$a$,
  $b$PERFORM public.maladie_contact_interne(v_moi, x, 'interaction') FROM unnest(v_participants) x; -- maladies_contagion_v1
   PERFORM public.maladie_verre_interne(x) FROM unnest(v_participants||ARRAY[v_moi]) x WHERE$b$,
  'maladies_contagion_v1');
SELECT pg_temp.rp_raccorder('public.restaurant_diner_servir(bigint)'::regprocedure,
  $a$    IF public.boisson_alcoolisee_interne('champagne_luthecia') THEN -- maladies_boissons_v1$a$,
  $b$    IF NOT i.invite_pnj THEN PERFORM public.maladie_contact_interne(moi, i.invite, 'interaction'); END IF; -- maladies_contagion_v1
    IF public.boisson_alcoolisee_interne('champagne_luthecia') THEN -- maladies_boissons_v1$b$,
  'maladies_contagion_v1');
SELECT pg_temp.rp_raccorder('public.diner_commerce_servir_interne(text,bigint)'::regprocedure,
  $a$    IF public.boisson_alcoolisee_interne(cfg->>'boisson') THEN -- maladies_boissons_v1$a$,
  $b$    IF NOT i.invite_pnj THEN PERFORM public.maladie_contact_interne(moi, i.invite, 'interaction'); END IF; -- maladies_contagion_v1
    IF public.boisson_alcoolisee_interne(cfg->>'boisson') THEN -- maladies_boissons_v1$b$,
  'maladies_contagion_v1');

-- La passe horaire du climat fait aussi le blizzard, les effets et la contagion.
CREATE OR REPLACE FUNCTION public.climat_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  RETURN jsonb_build_object('ok', true, 'planifies', public.climat_planifier_interne() + public.climat_planifier_mandat_interne(),
    'alertes', public.climat_alertes_publier_interne(), 'effets', public.climat_effets_passe_interne(),
    'contagion', public.maladies_contagion_passe_interne());
END $$;

REVOKE ALL ON FUNCTION public.maladie_risque_pa_interne(integer, boolean), public.graisse_objet_interne(text, integer), public.graisse_cles_interne(),
  public.pharmacie_pj_de_la_piece_interne(text), public.climat_planifier_mandat_interne(), public.climat_blizzard_appliquer_interne(public.climat_evenements),
  public.climat_effets_passe_interne(), public.maladie_contact_interne(text, text, text), public.maladies_contagion_passe_interne(), public.climat_passe()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.graisse_etat(), public.graisse_acheter(uuid, text, integer), public.fonds_graisses_deposer(uuid, text, integer), public.climat_effets_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.graisse_etat(), public.graisse_acheter(uuid, text, integer), public.fonds_graisses_deposer(uuid, text, integer), public.climat_effets_lire() TO authenticated;

DO $$ BEGIN
  IF public.maladie_risque_pa_interne(30, false) <> 0 OR public.maladie_risque_pa_interne(21, false) <> 10 OR public.maladie_risque_pa_interne(16, false) <> 25
     OR public.maladie_risque_pa_interne(11, false) <> 50 OR public.maladie_risque_pa_interne(6, false) <> 65 OR public.maladie_risque_pa_interne(1, false) <> 80
     OR public.maladie_risque_pa_interne(0, true) <> 0
     OR position('maladies_contagion_v1' IN pg_get_functiondef('public.tournee_cloturer_boire(text)'::regprocedure)) = 0
     OR position('maladies_contagion_v1' IN pg_get_functiondef('public.restaurant_diner_servir(bigint)'::regprocedure)) = 0
     OR position('maladies_contagion_v1' IN pg_get_functiondef('public.diner_commerce_servir_interne(text,bigint)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'lot 4 : controle structurel en echec'; END IF;
END $$;

COMMIT;
