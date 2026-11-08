-- Palais présidentiel de Sovarka (Novomirsk), décisions de Fred du 08/11/2026 (GAME-DESIGN-NOVOMIRSK.md,
-- « Palais présidentiel ») :
--  1. Bâtiment propre à la présidence (id du socle `palais-presidentiel`, ex-« Palais du Parti »), entré depuis
--     la vue 10 (rue du Tribunal) : quatre pièces — hall d'entrée (chef du protocole), appartements du
--     président, salle de restaurant, musée présidentiel. Bureau et salle de presse du socle retirés.
--  2. Salle de restaurant et appartements : on n'y entre que groupé au président (ou en étant le président).
--  3. Musée présidentiel : entrée à 8 PSK (billet du jour acheté au hall), versés à la caisse présidentielle.
--  4. Appartements gratuits ; le président qui y dort gagne +1 PA (en plus du repos ordinaire).
--  5. Caisse présidentielle (soviet_palais-presidentiel, alimentée par la ligne « Présidence » à 3 %) : paie le
--     salaire du président, ramené de 800 à 600 PSK, et 60 PSK par invité au repas présidentiel.
--  6. Repas présidentiel : servi dans la salle de restaurant ; repas du président gratuit, autant d'invités
--     présents que la caisse peut payer ; effets du dîner d'affaires pour chacun (décision du 07/11).

-- 1. Salaire du président
UPDATE public.salaires_civils_declares SET montant = 600
 WHERE pays = 'soviet' AND categorie = 'poste' AND cle = 'president' AND montant IS DISTINCT FROM 600;

-- 2. Pièces et entrée depuis la rue
UPDATE public.navigation_lieux_regles
   SET pieces = '["accueil_elysee","appartements_president","salle_reception","musee_presidentiel"]'::jsonb
 WHERE pays = 'soviet' AND ville = 'capitale' AND batiment = 'palais-presidentiel';
INSERT INTO public.rue_sorties_batiments (country, city, noeud, building)
VALUES ('soviet', 'capitale', 'novomirsk-vue-10', 'palais-presidentiel')
ON CONFLICT DO NOTHING;

-- 3. Billets du musée présidentiel
CREATE TABLE IF NOT EXISTS public.sovarka_musee_billets (
  jour date NOT NULL,
  personnage text NOT NULL,
  paye numeric NOT NULL,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (jour, personnage)
);
ALTER TABLE public.sovarka_musee_billets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_musee_billets FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost) VALUES ('sovarka_musee_billet', 0, 8) ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION public.sovarka_musee_billet()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
        p record; v_paie jsonb; v_flag text; v_rep jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sovarka:musee_billet:' || a, 0));
  IF EXISTS (SELECT 1 FROM public.sovarka_musee_billets WHERE jour = v_jour AND personnage = a) THEN
    RETURN jsonb_build_object('ok', true, 'deja', true);
  END IF;
  SELECT country, current_city, current_building, current_room INTO p FROM public.personnages_donnees WHERE name = a;
  IF p.country IS DISTINCT FROM 'soviet' OR p.current_city IS DISTINCT FROM 'capitale'
     OR p.current_building IS DISTINCT FROM 'palais-presidentiel' OR p.current_room IS DISTINCT FROM 'accueil_elysee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;
  v_paie := public.payer_ordre_interne(a, 'sovarka_musee_billet', 0, 8);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  v_flag := current_setting('rp.caisse_interne', true);
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement('soviet_palais-presidentiel', 8, true);
  PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
  IF (v_rep->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'caisse_presidentielle_refusee: %', v_rep; END IF;
  INSERT INTO public.sovarka_musee_billets (jour, personnage, paye) VALUES (v_jour, a, 8);
  RETURN jsonb_build_object('ok', true, 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
END $$;
REVOKE ALL ON FUNCTION public.sovarka_musee_billet() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_musee_billet() TO authenticated;

-- 4. Accès réservés (lu par la navigation intérieure)
CREATE OR REPLACE FUNCTION public.sovarka_palais_acces_interne(p_nom text, p_piece text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_pres text;
BEGIN
  IF p_piece IN ('appartements_president', 'salle_reception') THEN
    SELECT data::jsonb ->> 'eluId' INTO v_pres FROM public.cycles_electoraux WHERE id = 'soviet_president';
    IF v_pres IS NOT NULL AND (p_nom = v_pres OR EXISTS (
         SELECT 1 FROM public.groupes_pj_adhesions WHERE membre = p_nom AND chef = v_pres)) THEN
      RETURN NULL;
    END IF;
    RETURN 'groupe_president_requis';
  ELSIF p_piece = 'musee_presidentiel' THEN
    IF EXISTS (SELECT 1 FROM public.sovarka_musee_billets
                WHERE jour = (now() AT TIME ZONE 'Europe/Paris')::date AND personnage = p_nom) THEN
      RETURN NULL;
    END IF;
    RETURN 'billet_musee_requis';
  END IF;
  RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_palais_acces_interne(text, text) FROM PUBLIC, anon, authenticated;

-- 5. Repas présidentiel : salle de restaurant, plusieurs invités payés par la caisse présidentielle
ALTER TABLE public.sovarka_repas_presidentiels ADD COLUMN IF NOT EXISTS invites jsonb;
DROP FUNCTION IF EXISTS public.sovarka_repas_presidentiel(text, text);
CREATE OR REPLACE FUNCTION public.sovarka_repas_presidentiel(p_requete text, p_invites text[] DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE v_moi text; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_ligne record;
        v_invites text[]; v_n integer; v_presents integer; v_cout numeric; v_bonus integer; v_r jsonb;
        v_moi_fiche record; v_flag text; v_rep jsonb; v_solde numeric; v_i text;
        c_prix constant numeric := 60;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(p_requete), '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_absente'); END IF;

  PERFORM pg_advisory_xact_lock(hashtext('sovarka_repas_presidentiel|' || v_jour::text));
  SELECT * INTO v_ligne FROM public.sovarka_repas_presidentiels WHERE jour = v_jour;
  IF FOUND THEN
    IF v_ligne.requete = p_requete AND v_ligne.president = v_moi THEN RETURN v_ligne.resultat || '{"rejeu":true}'; END IF;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_pris_aujourdhui');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.cycles_electoraux
                  WHERE id = 'soviet_president' AND data::jsonb ->> 'eluId' = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_president');
  END IF;
  SELECT country, current_city, current_building, current_room INTO v_moi_fiche
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_moi_fiche.country IS DISTINCT FROM 'soviet' OR v_moi_fiche.current_city IS DISTINCT FROM 'capitale'
     OR v_moi_fiche.current_building IS DISTINCT FROM 'palais-presidentiel'
     OR v_moi_fiche.current_room IS DISTINCT FROM 'salle_reception' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  SELECT coalesce(array_agg(DISTINCT n ORDER BY n), '{}') INTO v_invites
    FROM (SELECT nullif(btrim(x), '') AS n FROM unnest(coalesce(p_invites, '{}'::text[])) x) t WHERE n IS NOT NULL;
  IF v_moi = ANY (v_invites) THEN RETURN jsonb_build_object('ok', false, 'raison', 'invite_invalide'); END IF;
  v_n := coalesce(array_length(v_invites, 1), 0);
  IF v_n > 0 THEN
    SELECT count(*) INTO v_presents FROM (
      SELECT 1 FROM public.personnages_donnees
       WHERE name = ANY (v_invites) AND country = 'soviet' AND current_city = 'capitale'
         AND current_building = 'palais-presidentiel' AND current_room = 'salle_reception'
       FOR UPDATE) t;
    IF v_presents <> v_n THEN RETURN jsonb_build_object('ok', false, 'raison', 'invite_absent'); END IF;
    v_cout := v_n * c_prix;
    v_flag := current_setting('rp.caisse_interne', true);
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement('soviet_palais-presidentiel', -v_cout, true);
    PERFORM set_config('rp.caisse_interne', coalesce(v_flag, ''), true);
    IF (v_rep->>'ok')::boolean IS NOT TRUE THEN
      SELECT coalesce((data->>'solde')::numeric, 0) INTO v_solde FROM public.caisses_batiments WHERE id = 'soviet_palais-presidentiel';
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'cout', v_cout,
                                'solde', coalesce(v_solde, 0), 'invites_possibles', floor(coalesce(v_solde, 0) / c_prix));
    END IF;
  END IF;

  SELECT montant INTO v_bonus FROM public.pa_bonus_differes WHERE source = 'diner_affaires';
  IF v_bonus IS DISTINCT FROM 3 THEN RAISE EXCEPTION 'bonus_diner_incompatible'; END IF;
  UPDATE public.personnages_donnees
     SET hp = least(100, coalesce(hp, 100) + 10), moral = least(100, coalesce(moral, 75) + 2),
         resources = jsonb_set(coalesce(resources, '{}') - 'popBase' - 'infBase', '{inf}',
                               to_jsonb(least(100, coalesce((resources ->> 'inf')::numeric, 0) + 5)), true),
         bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + v_bonus), updated_at = now()
   WHERE name = v_moi OR name = ANY (v_invites);

  SELECT jsonb_build_object('ok', true, 'invites', to_jsonb(v_invites), 'cout', coalesce(v_cout, 0),
                            'hp', hp, 'moral', moral, 'inf', (resources ->> 'inf')::numeric,
                            'bonus_pa_differe', bonus_pa_differe)
    INTO v_r FROM public.personnages_donnees WHERE name = v_moi;
  INSERT INTO public.sovarka_repas_presidentiels (jour, president, invite, invites, requete, resultat)
  VALUES (v_jour, v_moi, v_invites[1], to_jsonb(v_invites), p_requete, v_r);
  FOREACH v_i IN ARRAY v_invites LOOP
    PERFORM public.mail_systeme_envoyer('Système', v_i, 'Repas au Palais présidentiel',
      v_moi || ', Président de la République de Sovarka, vous a offert un repas au Palais présidentiel '
      || '(+10 Santé, +2 Moral, +5 INF, +3 PA au prochain Dormir).');
  END LOOP;
  RETURN v_r;
END $function$;
REVOKE ALL ON FUNCTION public.sovarka_repas_presidentiel(text, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_repas_presidentiel(text, text[]) TO authenticated;

-- 6. Patchs en place sous empreinte : accès réservés à la navigation, +1 PA au repos du président
DO $patch$
DECLARE r record; v_def text; v_new text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.navigation_interieure_personnage_interne(text,text,text,boolean)', 'c29f47e17c13b580a3ad94dec88f6f92',
     'palais_presidentiel_sovarka_v1',
     E' -- ssm_acces_sur_rendezvous_v1\n',
     E' -- palais_presidentiel_sovarka_v1 (Fred, 08/11/2026) : restaurant et appartements groupé au président, musée sur billet du jour.\n'
     || E' IF p.country=''soviet'' AND p.current_city=''capitale'' AND p_batiment=''palais-presidentiel'' AND (p.current_building IS DISTINCT FROM p_batiment OR p.current_room IS DISTINCT FROM p_piece) THEN\n'
     || E'  r:=CASE WHEN public.sovarka_palais_acces_interne(p_nom,p_piece) IS NULL THEN NULL ELSE jsonb_build_object(''ok'',false,''raison'',public.sovarka_palais_acces_interne(p_nom,p_piece),''membre'',p_nom) END;\n'
     || E'  IF r IS NOT NULL THEN RETURN r; END IF;\n END IF;\n'
     || E' -- ssm_acces_sur_rendezvous_v1\n'),
    ('public.pa_repos_nocturne(text)', '6e33ec79087f22bdaf117764bb9cce18',
     'palais_presidentiel_repos_v1',
     E'    v_nouveau := least(c_pa_max, greatest(0, v_pa + v_gain + v_bonus));\n  END IF;',
     E'    -- palais_presidentiel_repos_v1 (Fred, 08/11/2026) : +1 PA au président de Sovarka qui dort dans ses appartements.\n'
     || E'    IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_acteur AND country = ''soviet'' AND current_city = ''capitale''\n'
     || E'                 AND current_building = ''palais-presidentiel'' AND current_room = ''appartements_president'')\n'
     || E'       AND EXISTS (SELECT 1 FROM public.cycles_electoraux WHERE id = ''soviet_president'' AND data::jsonb ->> ''eluId'' = p_acteur) THEN\n'
     || E'      v_gain := v_gain + 1;\n    END IF;\n'
     || E'    v_nouveau := least(c_pa_max, greatest(0, v_pa + v_gain + v_bonus));\n  END IF;')
  ) AS t(fn, empreinte, marque, ancre, remplace) LOOP
    v_def := pg_get_functiondef(r.fn::regprocedure);
    CONTINUE WHEN strpos(v_def, r.marque) > 0;
    IF md5(v_def) <> r.empreinte THEN RAISE EXCEPTION 'empreinte_inattendue: %', r.fn; END IF;
    IF (length(v_def) - length(replace(v_def, r.ancre, ''))) / length(r.ancre) <> 1 THEN
      RAISE EXCEPTION 'ancre_non_unique: %', r.fn; END IF;
    v_new := replace(v_def, r.ancre, r.remplace);
    EXECUTE v_new;
  END LOOP;
END $patch$;

-- 7. Contrôles structurels
DO $v$ BEGIN
  IF NOT public.navigation_piece_referencee_interne('soviet','capitale','palais-presidentiel','musee_presidentiel')
     OR NOT public.navigation_piece_referencee_interne('soviet','capitale','palais-presidentiel','salle_reception')
     OR public.navigation_piece_referencee_interne('soviet','capitale','palais-presidentiel','bureau_president') THEN
    RAISE EXCEPTION 'pieces_palais_incorrectes'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.rue_sorties_batiments WHERE country = 'soviet' AND city = 'capitale'
                  AND noeud = 'novomirsk-vue-10' AND building = 'palais-presidentiel') THEN
    RAISE EXCEPTION 'entree_palais_absente'; END IF;
  IF strpos(pg_get_functiondef('public.navigation_interieure_personnage_interne(text,text,text,boolean)'::regprocedure), 'palais_presidentiel_sovarka_v1') = 0
     OR strpos(pg_get_functiondef('public.pa_repos_nocturne(text)'::regprocedure), 'palais_presidentiel_repos_v1') = 0 THEN
    RAISE EXCEPTION 'patch_incomplet'; END IF;
  IF (SELECT montant FROM public.salaires_civils_declares WHERE pays = 'soviet' AND categorie = 'poste' AND cle = 'president') <> 600 THEN
    RAISE EXCEPTION 'salaire_president_non_ramene'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments WHERE id = 'soviet_palais-presidentiel') THEN
    RAISE EXCEPTION 'caisse_presidentielle_absente'; END IF;
END $v$;
