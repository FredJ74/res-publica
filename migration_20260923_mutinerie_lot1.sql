-- =============================================================================================
-- MUTINERIE MILITAIRE — LOT 1 (23 septembre 2026)
-- =============================================================================================
-- CE QUE CE LOT OUVRE. Un Lieutenant peut retourner sa section contre l'armee reguliere de son
-- propre pays, et les deux forces peuvent s'affronter avec LE MOTEUR DE COMBAT EXISTANT. Aucun
-- second moteur n'est cree : militaire_bataille_round, _actions, _appliquer, _arbitrer_groupes,
-- _decrocher_groupe et les rapports ne sont pas touches.
--
-- POURQUOI C'EST BON MARCHE. Dans tout le schema de combat, `camp` est un simple text libre
-- (batailles.camp_a/camp_b, batailles_engagements.camp, batailles_groupes.camp). Rien n'y dit
-- qu'un camp est un pays. Un camp mutin est donc une chaine synthetique 'mutin:<hex>' qui
-- traverse le moteur sans le modifier. Seules TROIS fonctions confondaient camp et pays, et ce
-- sont exactement les trois adaptees ici.
--
-- LE SERVEUR RESTE SEUL JUGE DE L'HOSTILITE. militaire_bataille_engager() ne prend toujours
-- AUCUN ARGUMENT : le client ne peut pas designer son adversaire. Il est decouvert a partir de la
-- piece et de l'etat reel des camps. Deux forces loyalistes du meme pays ne peuvent jamais
-- devenir hostiles, quelle que soit la requete envoyee.
-- =============================================================================================

-- ---------------------------------------------------------------------------------------------
-- 1. DONNEES
-- ---------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.mutineries (
  camp         text PRIMARY KEY,
  pays         text NOT NULL,
  fondateur    text NOT NULL,
  compagnie_id text,
  section_id   text,
  statut       text NOT NULL DEFAULT 'active',
  cree_le      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.mutineries_membres (
  camp         text NOT NULL REFERENCES public.mutineries(camp) ON DELETE CASCADE,
  personnage   text NOT NULL,
  role_origine text,
  statut       text NOT NULL DEFAULT 'actif',   -- actif | capture | rendu
  rejoint_le   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (camp, personnage)
);

-- UN SEUL CAMP PAR PERSONNAGE, A VIE. Le ralliement est definitif (regle du game design) : cet
-- index le rend structurellement impossible a contourner, y compris par le futur « Se rallier ».
CREATE UNIQUE INDEX IF NOT EXISTS mutineries_membres_un_seul_camp
  ON public.mutineries_membres (personnage);

ALTER TABLE public.mutineries          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mutineries_membres  ENABLE ROW LEVEL SECURITY;

-- LECTURE SEULE POUR LE CLIENT, et bornee a son propre pays : il doit pouvoir afficher « Mutin »,
-- il ne doit jamais pouvoir se declarer tel. AUCUN grant d'ecriture : seules les RPC
-- SECURITY DEFINER ci-dessous ecrivent ces tables.
DROP POLICY IF EXISTS mutineries_lecture_mon_pays ON public.mutineries;
CREATE POLICY mutineries_lecture_mon_pays ON public.mutineries
  FOR SELECT TO authenticated USING (pays = public.militaire_mon_pays());

DROP POLICY IF EXISTS mutineries_membres_lecture_mon_pays ON public.mutineries_membres;
CREATE POLICY mutineries_membres_lecture_mon_pays ON public.mutineries_membres
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM public.mutineries m
     WHERE m.camp = mutineries_membres.camp AND m.pays = public.militaire_mon_pays()));

REVOKE ALL ON public.mutineries         FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.mutineries_membres FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.mutineries         TO authenticated;
GRANT SELECT ON public.mutineries_membres TO authenticated;

-- Le marqueur des soldats PNJ vit dans compagnies_militaires.data.sections[].soldats[].mutin,
-- aux cotes de leaderCourant / dernier_ration / dernier_sommeil. Aucune colonne, aucune table :
-- c'est la convention du moteur. `authenticated` n'a que SELECT sur cette table, le marqueur
-- est donc infalsifiable depuis un navigateur.

-- ---------------------------------------------------------------------------------------------
-- 2. HELPERS
-- ---------------------------------------------------------------------------------------------
-- Le social national. helvetia_ie_national fait deja l'equivalent pour 'ie' ; ATTENTION,
-- is_national() calcule 'isn' (la securite), PAS le social -- collision de nommage historique
-- documentee dans le depot, et raison pour laquelle cette fonction existe.
CREATE OR REPLACE FUNCTION public.mutinerie_social_national(p_pays text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT CASE WHEN count(*) = 3 THEN round(avg((v.data ->> 'social')::numeric), 2) ELSE 45 END
    FROM public.indices_villes v
   WHERE v.id = ANY (ARRAY[p_pays || '_capitale', p_pays || '_ville_a', p_pays || '_ville_b'])
     AND jsonb_typeof(v.data -> 'social') = 'number';
$function$;

-- Camp mutin ACTIF d'un PJ, ou NULL s'il est loyaliste. Un membre capture ou rendu n'est plus
-- combattant : il redevient NULL ici, sans que son appartenance historique ne soit effacee.
CREATE OR REPLACE FUNCTION public.mutinerie_camp_de(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT mm.camp FROM public.mutineries_membres mm
    JOIN public.mutineries m ON m.camp = mm.camp
   WHERE mm.personnage = p_nom AND mm.statut = 'actif' AND m.statut = 'active'
   LIMIT 1;
$function$;

CREATE OR REPLACE FUNCTION public.mutinerie_est_camp(p_camp text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT EXISTS (SELECT 1 FROM public.mutineries WHERE camp = p_camp);
$function$;

-- Le pays auquel se rattache un camp : le sien s'il est mutin, lui-meme s'il EST un pays.
CREATE OR REPLACE FUNCTION public.mutinerie_pays_du_camp(p_camp text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT coalesce((SELECT m.pays FROM public.mutineries m WHERE m.camp = p_camp), p_camp);
$function$;

-- Camps REELLEMENT presents dans une piece, pour un pays donne : un camp n'existe ici que s'il y
-- a du monde pour se battre. Sert a la decouverte d'adversaire, jamais a en designer un.
CREATE OR REPLACE FUNCTION public.mutinerie_camps_presents(
  p_pays text, p_ville text, p_bat text, p_piece text)
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT coalesce(array_agg(DISTINCT t.camp), '{}'::text[]) FROM (
    SELECT coalesce(sol->>'mutin', c.data->>'pays') AS camp
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' = p_pays
       AND NOT coalesce((sol->>'pj')::boolean, false)
       AND coalesce((sol->>'pa')::integer, 0) > 0
       AND ((sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
             AND (sol->>'leaderCourant') IS NULL)
         OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                     WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                       AND chef.current_building = p_bat AND chef.current_room = p_piece))
    UNION ALL
    SELECT coalesce(public.mutinerie_camp_de(pd.name), pd.country)
      FROM public.personnages_donnees pd
      JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
     WHERE pd.country = p_pays AND pd.current_city = p_ville
       AND pd.current_building = p_bat AND pd.current_room = p_piece
       AND coalesce(pd.pa, 0) > 0
  ) t;
$function$;

-- ---------------------------------------------------------------------------------------------
-- 3. DECLENCHEMENT
-- ---------------------------------------------------------------------------------------------
-- AUCUN ARGUMENT : la section visee est celle que l'appelant commande reellement, lue sur sa
-- fiche. Il ne peut pas retourner la section d'un autre.
CREATE OR REPLACE FUNCTION public.militaire_mutinerie_declencher()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  c_effectif_max constant integer := 24;
  c_bonus_max    constant integer := 4;
  c_seuil_crise  constant numeric := 35;
  g record; v_moi text; v_pays text; v_cie text; v_sec text;
  v_cha numeric; v_base integer; v_social numeric; v_ie numeric;
  v_deg_s numeric; v_deg_e numeric; v_score numeric; v_bonus integer;
  v_vises integer; v_dispo integer; v_camp text; v_choisis text[]; v_sols jsonb; v_secj jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), poste->>'compagnieId', poste->>'sectionId',
         public.assemblee_stat_base(stats, 'CHA')
    INTO v_pays, v_cie, v_sec, v_cha
    FROM public.personnages_donnees
   WHERE name = v_moi AND poste->>'id' = 'lieutenant';
  IF v_cie IS NULL OR v_sec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_lieutenant');
  END IF;

  IF public.mutinerie_camp_de(v_moi) IS NOT NULL
     OR EXISTS (SELECT 1 FROM public.mutineries_membres WHERE personnage = v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mutin');
  END IF;

  -- AUTORITE ET VERROU : le Lieutenant STRUCTUREL de cette section, verrou pose sur la compagnie.
  SELECT * INTO g FROM public.militaire_section_de_moi(v_cie, v_sec);
  IF g.o_raison IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', g.o_raison); END IF;

  -- BAREME DE CHARISME (game design). CHA 17+ traite comme 16 : le bareme ne monte pas au-dela.
  v_base := CASE WHEN v_cha <= 13 THEN 12 WHEN v_cha < 15 THEN 15
                 WHEN v_cha < 16 THEN 18 ELSE 20 END;

  -- BONUS DE CRISE NATIONALE : social pese 2/3, economie 1/3. Une situation saine (>= 35)
  -- n'apporte rien. 'ie' est lu pour de vrai bien qu'aucune mecanique ne le fasse encore bouger :
  -- la mutinerie sera prete le jour ou il deviendra vivant.
  v_social := public.mutinerie_social_national(v_pays);
  v_ie     := public.helvetia_ie_national(v_pays);
  v_deg_s  := greatest(0, (c_seuil_crise - v_social) / c_seuil_crise);
  v_deg_e  := greatest(0, (c_seuil_crise - v_ie)     / c_seuil_crise);
  v_score  := (2.0/3.0) * v_deg_s + (1.0/3.0) * v_deg_e;
  v_bonus  := least(c_bonus_max, greatest(0, ceil(c_bonus_max * v_score)::integer));

  v_vises := least(c_effectif_max, v_base + v_bonus);

  SELECT s INTO v_secj FROM jsonb_array_elements(g.o_data->'sections') s WHERE s->>'id' = v_sec;
  v_sols := CASE WHEN jsonb_typeof(v_secj->'soldats') = 'array' THEN v_secj->'soldats' ELSE '[]'::jsonb END;

  -- SOLDATS REELLEMENT DISPONIBLES : les PNJ vivants de la section, jamais un PJ (un joueur ne se
  -- rallie pas malgre lui), jamais un effectif invente.
  SELECT count(*)::integer INTO v_dispo FROM jsonb_array_elements(v_sols) sol
   WHERE NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND (sol->>'mutin') IS NULL;
  v_vises := least(v_vises, v_dispo);

  v_camp := 'mutin:' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
  INSERT INTO public.mutineries (camp, pays, fondateur, compagnie_id, section_id)
  VALUES (v_camp, v_pays, v_moi, v_cie, v_sec);
  INSERT INTO public.mutineries_membres (camp, personnage, role_origine)
  VALUES (v_camp, v_moi, 'lieutenant');

  -- TIRAGE ALEATOIRE parmi les soldats disponibles. Les non-tires restent strictement loyalistes.
  IF v_vises > 0 THEN
    SELECT coalesce(array_agg(mat), '{}'::text[]) INTO v_choisis FROM (
      SELECT sol->>'matricule' AS mat FROM jsonb_array_elements(v_sols) sol
       WHERE NOT coalesce((sol->>'pj')::boolean, false)
         AND coalesce((sol->>'pa')::integer, 0) > 0
         AND (sol->>'mutin') IS NULL
       ORDER BY random() LIMIT v_vises) x;

    SELECT coalesce(jsonb_agg(
             CASE WHEN sol->>'matricule' = ANY (v_choisis)
                  THEN sol || jsonb_build_object('mutin', v_camp) ELSE sol END ORDER BY pos), '[]'::jsonb)
      INTO v_sols FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos);

    UPDATE public.compagnies_militaires
       SET data = public.militaire_sections_remplacer(g.o_data, v_sec,
                    v_secj || jsonb_build_object('soldats', v_sols))
     WHERE id = v_cie;
  END IF;

  RETURN jsonb_build_object('ok', true, 'camp', v_camp, 'cha', v_cha,
    'base', v_base, 'bonus_crise', v_bonus, 'social', v_social, 'ie', v_ie,
    'soldats_rallies', v_vises, 'soldats_disponibles', v_dispo,
    'soldats_restes_loyalistes', greatest(0, v_dispo - v_vises));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_mutinerie_declencher() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_mutinerie_declencher() TO authenticated;

-- ---------------------------------------------------------------------------------------------
-- 4. HOSTILITE — LE JUGE UNIQUE
-- ---------------------------------------------------------------------------------------------
-- Deux sources d'hostilite, et deux seulement :
--   (a) guerre internationale active -- STRICTEMENT le predicat d'origine, non touche ;
--   (b) mutinerie : meme pays, et AU MOINS UN des deux camps est un camp mutin.
-- Deux camps loyalistes du meme pays echouent aux deux : (a) n'a pas de guerre d'un pays contre
-- lui-meme, (b) exige un camp mutin. Le friendly fire reste donc impossible.
CREATE OR REPLACE FUNCTION public.militaire_camps_hostiles(p_bataille_id bigint, p_camp text)
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $function$
  SELECT coalesce(array_agg(DISTINCT e.camp), '{}')
    FROM public.batailles_engagements e
   WHERE e.bataille_id = p_bataille_id
     AND e.sorti_round IS NULL
     AND e.camp IS DISTINCT FROM p_camp
     AND ( EXISTS (SELECT 1 FROM public.guerres g
                    WHERE g.statut = 'active'
                      AND ((g.data->>'attaquant' = p_camp AND g.data->>'attaque'  = e.camp)
                        OR (g.data->>'attaque'  = p_camp AND g.data->>'attaquant' = e.camp)))
        OR ( public.mutinerie_pays_du_camp(p_camp) = public.mutinerie_pays_du_camp(e.camp)
             AND (public.mutinerie_est_camp(p_camp) OR public.mutinerie_est_camp(e.camp)) ) );
$function$;

-- ---------------------------------------------------------------------------------------------
-- 5. RECRUTEMENT — CAMP-AWARE, ET groupe_id PREFIXE PAR LE CAMP
-- ---------------------------------------------------------------------------------------------
-- LE CAMP ENTRE DANS groupe_id DES CE LOT : deux sous-groupes issus de la MEME section mais de
-- camps opposes ne doivent jamais partager un groupe de combat (decision de repli, seuil de
-- 50 % de pertes, chef de groupe). Hors mutinerie, le comportement est identique a avant, le
-- prefixe etant alors simplement le pays.
CREATE OR REPLACE FUNCTION public.militaire_bataille_recruter(
  p_bataille_id bigint, p_camp text, p_ville text, p_bat text, p_piece text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE v_mutin boolean; v_pays text;
BEGIN
  v_mutin := public.mutinerie_est_camp(p_camp);
  v_pays  := public.mutinerie_pays_du_camp(p_camp);

  INSERT INTO public.batailles_engagements
    (bataille_id, camp, personnage, compagnie_id, section_id, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, pd.name, sm.compagnie_id, sm.section_id, sm.grade, pd.pa,
         p_camp || '|' || coalesce(sm.compagnie_id, 'solo') || ':' || coalesce(sm.section_id, pd.name)
    FROM public.personnages_donnees pd
    JOIN public.services_militaires sm ON sm.personnage = pd.name AND sm.fin_ts IS NULL
   WHERE pd.current_city = p_ville AND pd.current_building = p_bat AND pd.current_room = p_piece
     AND coalesce(pd.pa, 0) > 0
     AND pd.country = v_pays
     AND CASE WHEN v_mutin THEN public.mutinerie_camp_de(pd.name) = p_camp
                           ELSE public.mutinerie_camp_de(pd.name) IS NULL END
  ON CONFLICT DO NOTHING;

  INSERT INTO public.batailles_engagements
    (bataille_id, camp, compagnie_id, section_id, matricule, grade, pa_initial, groupe_id)
  SELECT p_bataille_id, p_camp, c.id, s->>'id', sol->>'matricule', 'soldat',
         (sol->>'pa')::integer, p_camp || '|' || c.id || ':' || (s->>'id')
    FROM public.compagnies_militaires c,
         jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
         jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
   WHERE c.data->>'pays' = v_pays
     AND NOT coalesce((sol->>'pj')::boolean, false)
     AND coalesce((sol->>'pa')::integer, 0) > 0
     AND CASE WHEN v_mutin THEN sol->>'mutin' = p_camp ELSE (sol->>'mutin') IS NULL END
     AND ((sol->>'ville' = p_ville AND sol->>'buildingId' = p_bat AND sol->>'roomId' = p_piece
           AND (sol->>'leaderCourant') IS NULL)
       OR EXISTS (SELECT 1 FROM public.personnages_donnees chef
                   WHERE chef.name = sol->>'leaderCourant' AND chef.current_city = p_ville
                     AND chef.current_building = p_bat AND chef.current_room = p_piece))
  ON CONFLICT DO NOTHING;
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- 6. ENGAGEMENT — DECOUVERTE DE L'ADVERSAIRE, TOUJOURS SANS ARGUMENT
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_bataille_engager()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  v_moi text; a record; v_id bigint; v_contact bigint; v_init text;
  v_camps text[]; v_camp text; v_na integer; v_total integer; v_mon_camp text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room, pa INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  IF a.country IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.services_militaires
                  WHERE personnage = v_moi AND fin_ts IS NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_militaire');
  END IF;
  IF EXISTS (SELECT 1 FROM public.batailles WHERE statut = 'en_cours'
              AND pays = a.country AND ville = a.current_city
              AND batiment = a.current_building AND piece = a.current_room) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bataille_deja_en_cours');
  END IF;

  -- MON CAMP : mon camp mutin s'il existe, mon pays sinon. Jamais fourni par le client.
  v_mon_camp := coalesce(public.mutinerie_camp_de(v_moi), a.country);

  -- (a) ENNEMIS ETRANGERS : predicat d'origine, inchange. Reserve aux forces loyalistes ;
  --     une force mutine ne combat pas encore l'etranger (lot suivant).
  IF v_mon_camp = a.country THEN
    SELECT coalesce(array_agg(DISTINCT c.data->>'pays'), '{}') INTO v_camps
      FROM public.compagnies_militaires c,
           jsonb_array_elements(coalesce(c.data->'sections','[]'::jsonb)) s,
           jsonb_array_elements(coalesce(s->'soldats','[]'::jsonb)) sol
     WHERE c.data->>'pays' IS DISTINCT FROM a.country
       AND sol->>'ville' = a.current_city AND sol->>'buildingId' = a.current_building
       AND sol->>'roomId' = a.current_room AND (sol->>'leaderCourant') IS NULL
       AND EXISTS (SELECT 1 FROM public.guerres g WHERE g.statut = 'active'
                    AND ((g.data->>'attaquant' = a.country AND g.data->>'attaque' = c.data->>'pays')
                      OR (g.data->>'attaque'  = a.country AND g.data->>'attaquant' = c.data->>'pays')));
  ELSE
    v_camps := '{}';
  END IF;

  -- (b) ADVERSAIRES DU MEME PAYS : uniquement si une mutinerie separe reellement les deux camps.
  SELECT v_camps || coalesce(array_agg(c), '{}') INTO v_camps
    FROM unnest(public.mutinerie_camps_presents(a.country, a.current_city,
                                                a.current_building, a.current_room)) c
   WHERE c IS DISTINCT FROM v_mon_camp
     AND (public.mutinerie_est_camp(c) OR public.mutinerie_est_camp(v_mon_camp));

  IF coalesce(array_length(v_camps, 1), 0) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_ennemi_ici');
  END IF;

  SELECT id INTO v_contact FROM public.contacts_militaires
   WHERE consomme_le IS NULL AND ville = a.current_city AND batiment = a.current_building
     AND ((pays_a = a.country AND pays_b = ANY(v_camps)) OR (pays_a = ANY(v_camps) AND pays_b = a.country))
   ORDER BY etabli_le DESC LIMIT 1;
  v_init := CASE WHEN v_contact IS NOT NULL THEN 'simultane' ELSE 'a' END;

  INSERT INTO public.batailles (pays, ville, batiment, piece, camp_a, camp_b, initiative,
                                leader_a, contact_id, statut, round_courant)
  VALUES (a.country, a.current_city, a.current_building, a.current_room, v_mon_camp, v_camps[1],
          v_init, v_moi, v_contact, 'en_cours', 0)
  RETURNING id INTO v_id;

  PERFORM public.militaire_bataille_recruter(v_id, v_mon_camp, a.current_city, a.current_building, a.current_room);
  FOREACH v_camp IN ARRAY v_camps LOOP
    PERFORM public.militaire_bataille_recruter(v_id, v_camp, a.current_city, a.current_building, a.current_room);
  END LOOP;

  SELECT count(*) INTO v_na    FROM public.militaire_bataille_combattants(v_id, v_mon_camp);
  SELECT count(*) INTO v_total FROM public.batailles_engagements
   WHERE bataille_id = v_id AND camp <> v_mon_camp AND sorti_round IS NULL;
  IF v_na = 0 OR v_total = 0 THEN
    DELETE FROM public.batailles_engagements WHERE bataille_id = v_id;
    DELETE FROM public.batailles WHERE id = v_id;
    RETURN jsonb_build_object('ok', false, 'raison', 'effectif_insuffisant',
      'mon_camp', v_na, 'adverse', v_total);
  END IF;

  PERFORM public.militaire_bataille_groupes_constituer(v_id);
  UPDATE public.batailles SET effectif_initial_a = v_na, effectif_initial_b = v_total,
         repli_a = public.militaire_position_repli(v_moi, a.current_city, a.current_building, a.current_room)
   WHERE id = v_id;

  IF v_contact IS NOT NULL THEN
    UPDATE public.contacts_militaires SET consomme_le = now(), bataille_id = v_id WHERE id = v_contact;
  END IF;

  RETURN jsonb_build_object('ok', true, 'bataille_id', v_id, 'initiative', v_init,
    'mon_camp', v_mon_camp, 'camps_adverses', v_camps, 'mon_effectif', v_na,
    'effectif_adverse', v_total,
    'groupes', (SELECT count(*) FROM public.batailles_groupes WHERE bataille_id = v_id));
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_bataille_engager() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_bataille_engager() TO authenticated;

-- ---------------------------------------------------------------------------------------------
-- 7. NEUTRALISATION — LE MUTIN EST CAPTURE, PAS EVACUE
-- ---------------------------------------------------------------------------------------------
-- Seule la branche « PJ tombe a 0 PA » change, et seulement pour un mutin. Le loyaliste part
-- toujours a l'infirmerie de sa caserne, le PNJ meurt toujours : comportement d'origine intact.
CREATE OR REPLACE FUNCTION public.militaire_bataille_appliquer(
  p_bataille_id bigint, p_actions jsonb, p_round integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
  act jsonb; v_pa integer; v_new integer; v_gilet jsonb; v_degre text; v_abaisse text;
  v_out jsonb := '[]'::jsonb; v_protege boolean;
  v_camp_mutin text; v_b record; v_ville_prison text; v_det jsonb;
BEGIN
  SELECT pays, ville INTO v_b FROM public.batailles WHERE id = p_bataille_id;

  FOR act IN SELECT value FROM jsonb_array_elements(coalesce(p_actions, '[]'::jsonb))
  LOOP
    v_degre := act->>'degre'; v_protege := false;

    IF v_degre = 'echec_critique' THEN
      UPDATE public.batailles_engagements SET saute_round = p_round + 1
       WHERE id = (act->>'att_eng')::bigint AND sorti_round IS NULL;
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0, 'saute_suivant', true));
      CONTINUE;
    END IF;

    IF public.militaire_degats_pct(v_degre) = 0
       OR NOT EXISTS (SELECT 1 FROM public.batailles_engagements
                       WHERE id = (act->>'cib_eng')::bigint AND sorti_round IS NULL) THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    SELECT pa INTO v_pa FROM public.militaire_bataille_combattants(
      p_bataille_id, act->>'cib_camp') WHERE eng_id = (act->>'cib_eng')::bigint;
    IF v_pa IS NULL THEN
      v_out := v_out || jsonb_build_array(act || jsonb_build_object('perte', 0));
      CONTINUE;
    END IF;

    v_new := public.militaire_pa_restants(v_pa, v_degre);

    IF v_new = 0 AND act->>'mode' = 'feu' THEN
      v_gilet := public.militaire_gilet_absorber(
        (act->>'cib_pj')::boolean, act->>'cib_nom',
        act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      IF coalesce((v_gilet->>'protege')::boolean, false) THEN
        v_protege := true;
        v_abaisse := public.militaire_degre_par_rang(public.militaire_degre_rang(v_degre) - 1);
        v_new := greatest(1, public.militaire_pa_restants(v_pa, v_abaisse));
      END IF;
    END IF;

    IF (act->>'cib_pj')::boolean THEN
      UPDATE public.personnages_donnees SET pa = v_new WHERE name = act->>'cib_nom';
    ELSE
      PERFORM public.militaire_soldat_pa_fixer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat', v_new);
    END IF;

    v_out := v_out || jsonb_build_array(act || jsonb_build_object(
      'pa_avant', v_pa, 'pa_apres', v_new, 'perte', v_pa - v_new,
      'gilet', v_protege, 'degre_applique', coalesce(v_abaisse, v_degre)));

    CONTINUE WHEN v_new > 0;

    IF (act->>'cib_pj')::boolean THEN
      v_camp_mutin := public.mutinerie_camp_de(act->>'cib_nom');
      IF v_camp_mutin IS NOT NULL THEN
        -- MUTIN NEUTRALISE : capture. La prison est ouverte par le chemin canonique du jeu, avec
        -- la peine de 7 jours ; le cycle carceral existant prend le relais.
        -- La caserne n'est pas une ville dotee d'une prison : on rabat sur la capitale.
        v_ville_prison := CASE WHEN coalesce(v_b.ville,'') IN ('', 'caserne') THEN 'capitale' ELSE v_b.ville END;
        v_det := public.detention_ouvrir_interne(act->>'cib_nom', 'Mutinerie', 7,
                   v_ville_prison, coalesce(v_b.pays, 'republic'),
                   jsonb_build_object('source', 'mutinerie', 'bataille', p_bataille_id),
                   'Armee reguliere', 'capture');
        UPDATE public.mutineries_membres SET statut = 'capture'
         WHERE personnage = act->>'cib_nom' AND camp = v_camp_mutin;
        UPDATE public.batailles_engagements
           SET sorti_round = p_round, etat_final = 'capture'
         WHERE id = (act->>'cib_eng')::bigint;
      ELSE
        UPDATE public.personnages_donnees
           SET current_city = 'caserne', current_building = 'caserne-militaire',
               current_room = 'infirmerie'
         WHERE name = act->>'cib_nom';
        UPDATE public.batailles_engagements
           SET sorti_round = p_round, etat_final = 'neutralise'
         WHERE id = (act->>'cib_eng')::bigint;
      END IF;
    ELSE
      PERFORM public.militaire_soldat_supprimer(act->>'cib_cie', act->>'cib_sec', act->>'cib_mat');
      UPDATE public.batailles_engagements
         SET sorti_round = p_round, etat_final = 'mort'
       WHERE id = (act->>'cib_eng')::bigint;
    END IF;
  END LOOP;
  RETURN v_out;
END;
$function$;
