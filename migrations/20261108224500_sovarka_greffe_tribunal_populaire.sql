-- Greffe du Tribunal Populaire (Sovarka), décisions de Fred du 08/11/2026 (GAME-DESIGN-NOVOMIRSK.md,
-- « Greffe du Tribunal Populaire ») :
--  1. « Affaires en cours » et « Archives du greffe » réservés aux commissaires, juges, ministre de la
--     Justice prolétarienne (min_just) et ministre de la Sécurité du Peuple (min_int).
--  2. « Demander mon extrait de casier » : 1 PA et 8 PSK (100 FR en Républia, inchangé).
--  3. « Extrait de casier (enquête) » : mêmes rôles, sur n'importe quel habitant de Sovarka, sans affaire
--     en cours ; un étranger seulement s'il a une affaire ou une condamnation en Sovarka. L'État ne se
--     paie pas lui-même : 1 PA, aucun mouvement de caisse.
-- Le casier lu reste celui du pays (casier_judiciaire_contenu filtre déjà par pays) : à Novomirsk, on ne
-- voit que les condamnations prononcées en Sovarka.

-- 1. Qui a autorité sur le greffe de Sovarka
CREATE OR REPLACE FUNCTION public.sovarka_greffe_autorite_interne(p_nom text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.personnages_donnees d
                  WHERE d.name = p_nom AND d.country = 'soviet' AND (d.poste ->> 'id') IN ('juge', 'commissaire'))
      OR public.sovarka_est_titulaire_interne(p_nom, 'min_just')
      OR public.sovarka_est_titulaire_interne(p_nom, 'min_int');
$$;
REVOKE ALL ON FUNCTION public.sovarka_greffe_autorite_interne(text) FROM PUBLIC, anon, authenticated;

-- 2. Extrait de casier (enquête), version de Sovarka
CREATE OR REPLACE FUNCTION public.sovarka_casier_extrait_enquete_interne(p_moi text, p_personne text, p_ville text, p_inv jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pays_cible text; v_g record; v_paye jsonb; v_jour integer; v_contenu jsonb; v_doc jsonb;
BEGIN
  IF NOT public.sovarka_greffe_autorite_interne(p_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_autorites_sovarka');
  END IF;
  SELECT country INTO v_pays_cible FROM public.personnages_donnees WHERE name = p_personne;
  IF v_pays_cible IS DISTINCT FROM 'soviet'
     AND NOT EXISTS (SELECT 1 FROM public.jugements j WHERE j.accuse = p_personne AND j.country = 'soviet')
     AND NOT EXISTS (SELECT 1 FROM public.plaintes_en_cours p
                      WHERE p.country = 'soviet' AND left(btrim(coalesce(p.data, '')), 1) = '{'
                        AND (p.data::jsonb ->> 'cible') = p_personne) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etranger_hors_juridiction', 'personne', p_personne);
  END IF;

  SELECT * INTO v_g FROM public.justice_greffe_competent('soviet', p_ville);
  IF v_g.batiment IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'greffe_indetermine', 'ville', p_ville);
  END IF;
  IF NOT public.acteur_present_sur_site(p_moi, 'soviet', p_ville, v_g.batiment, v_g.piece) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_au_greffe_requise',
                              'site', v_g.batiment, 'piece', v_g.piece);
  END IF;
  IF public.inventaire_place_restante(p_inv) < 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein');
  END IF;

  v_paye := public.payer_ordre(p_moi, 'casier_extrait_enquete', 1, 0);
  IF coalesce((v_paye ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paye; END IF;

  v_jour := coalesce(public.jour_de_jeu_pays('soviet'), 1);
  v_contenu := public.casier_judiciaire_contenu(p_personne, 'soviet');
  v_doc := public.document_officiel_emettre(
    'casier_extrait', 'casier_extrait', true,
    'soviet', p_ville, p_personne, NULL, NULL, p_moi, p_moi, v_jour,
    'Extrait de casier judiciaire — ' || p_personne,
    'Delivre par le greffe du Tribunal Populaire au jour ' || v_jour || '. Document FIGE : il dit l''etat '
      || 'du casier au moment de sa delivrance, et ne se met jamais a jour.',
    'ti-file-certificate', v_contenu,
    jsonb_build_object('motif', 'surveillance_sovarka'));
  IF coalesce((v_doc ->> 'ok')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'sovarka_casier_extrait_enquete : emission refusee (%)', v_doc ->> 'raison';
  END IF;

  RETURN jsonb_build_object('ok', true, 'document', v_doc ->> 'document', 'personne', p_personne,
    'jour', v_jour, 'tribunal', p_ville, 'emis_par', v_doc ->> 'emis_par', 'sovarka', true,
    'vierge', (v_contenu ->> 'vierge')::boolean,
    'condamnations', jsonb_array_length(v_contenu -> 'condamnations'));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_casier_extrait_enquete_interne(text, text, text, jsonb) FROM PUBLIC, anon, authenticated;

-- 3. Coût déclaré de l'extrait personnel en Sovarka
INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('casier_mon_extrait', 1, 8) ON CONFLICT DO NOTHING;

-- 4. Patchs en place sous empreinte (une ou plusieurs ancres par fonction, toutes uniques)
DO $patch$
DECLARE r record; v_def text; i integer; c_garde constant text :=
  E'  -- greffe_sovarka_restreint_v1 (Fred, 08/11/2026) : registres du greffe réservés aux autorités de Sovarka.\n'
  || E'  IF v_pays = ''soviet'' AND NOT public.sovarka_greffe_autorite_interne(v_moi) THEN\n'
  || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''reserve_autorites_sovarka''); END IF;\n'
  || E'  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);\n';
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.justice_affaires_publiques()', 'cabdc8f6c816530384c88eb4e7f88a78', 'greffe_sovarka_restreint_v1',
     ARRAY[E'  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);\n'], ARRAY[c_garde]),
    ('public.justice_archives_greffe(text)', '97978fb7712663abf8d9b6877f62d1f0', 'greffe_sovarka_restreint_v1',
     ARRAY[E'  SELECT * INTO v_g FROM public.justice_greffe_competent(v_pays, v_ville);\n'], ARRAY[c_garde]),
    ('public.casier_mon_extrait()', 'bf2738475e424e9c816d41e248273791', 'greffe_sovarka_prix_v1',
     ARRAY['public.payer_ordre(v_moi, ''casier_mon_extrait'', 1, 100)',
           'public.caisse_institution_mouvement(v_caisse, 100, true)'],
     ARRAY['public.payer_ordre(v_moi, ''casier_mon_extrait'', 1, CASE WHEN v_pays = ''soviet'' THEN 8 ELSE 100 END) /* greffe_sovarka_prix_v1 : 8 PSK en Sovarka */',
           'public.caisse_institution_mouvement(v_caisse, CASE WHEN v_pays = ''soviet'' THEN 8 ELSE 100 END, true)']),
    ('public.casier_extrait_enquete(text)', 'b135a4731c2cb282b934b2cbc47951ef', 'greffe_sovarka_enquete_v1',
     ARRAY[E'  -- LE POSTE, LU EN BASE.'],
     ARRAY[E'  -- greffe_sovarka_enquete_v1 (Fred, 08/11/2026) : en Sovarka, autorités élargies, tout habitant, sans affaire.\n'
           || E'  IF v_pays = ''soviet'' THEN\n'
           || E'    RETURN public.sovarka_casier_extrait_enquete_interne(v_moi, p_personne, v_ville, v_inv);\n'
           || E'  END IF;\n\n'
           || E'  -- LE POSTE, LU EN BASE.'])
  ) AS t(fn, empreinte, marque, ancres, remplaces) LOOP
    v_def := pg_get_functiondef(r.fn::regprocedure);
    CONTINUE WHEN strpos(v_def, r.marque) > 0;
    IF md5(v_def) <> r.empreinte THEN RAISE EXCEPTION 'empreinte_inattendue: %', r.fn; END IF;
    FOR i IN 1 .. array_length(r.ancres, 1) LOOP
      IF (length(v_def) - length(replace(v_def, r.ancres[i], ''))) / length(r.ancres[i]) <> 1 THEN
        RAISE EXCEPTION 'ancre_non_unique: % (%)', r.fn, i; END IF;
      v_def := replace(v_def, r.ancres[i], r.remplaces[i]);
    END LOOP;
    EXECUTE v_def;
  END LOOP;
END $patch$;

-- 5. Contrôles structurels
DO $v$ BEGIN
  IF strpos(pg_get_functiondef('public.justice_affaires_publiques()'::regprocedure), 'greffe_sovarka_restreint_v1') = 0
     OR strpos(pg_get_functiondef('public.justice_archives_greffe(text)'::regprocedure), 'greffe_sovarka_restreint_v1') = 0
     OR strpos(pg_get_functiondef('public.casier_mon_extrait()'::regprocedure), 'greffe_sovarka_prix_v1') = 0
     OR strpos(pg_get_functiondef('public.casier_extrait_enquete(text)'::regprocedure), 'greffe_sovarka_enquete_v1') = 0 THEN
    RAISE EXCEPTION 'patch_incomplet'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'casier_mon_extrait' AND pa = 1 AND cost = 8) THEN
    RAISE EXCEPTION 'cout_sovarka_absent'; END IF;
END $v$;
