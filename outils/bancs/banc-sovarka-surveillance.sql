-- Banc annulé de 20261108180000/180100 (surveillance de Sovarka) ; rien ne reste (exception finale).
-- Joué le 08/11/2026 : paiement, rejeu, refus, limite et rapport unique conformes ; le relevé du témoin
-- contenait aussi ses vrais déplacements (attendu : plus de deux étapes).
BEGIN;
-- Sovarka : « Placer sous surveillance » au bureau du ministre de la Sécurité du Peuple
-- (décisions de Fred, 08/11/2026 ; GAME-DESIGN-NOVOMIRSK.md, « Surveillance »).
--  * 4 jours, 2 PA au ministre, 150 PSK sur la caisse du ministère (soviet_gouvernement-min_int).
--  * Rapport garanti chaque nuit : tous les déplacements de la cible et les PJ croisés dans chaque lieu ;
--    hors de Sovarka, « hors du territoire ».
--  * Risque de découverte chaque nuit : 10 % + 1,5 x (PER - 10) + 0,5 x (INT - 10) - (ISN de la ville - 30) / 5,
--    borné 2-40 % ; la cible reçoit un courrier anonyme, la surveillance continue.
--  * Toute cible (ministre, Président compris) ; 3 surveillances simultanées, une seule par cible.
-- Le moteur réutilise le registre des déplacements de la filature (historique_deplacements).

CREATE TABLE IF NOT EXISTS public.sovarka_surveillances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ts timestamptz NOT NULL DEFAULT now(),
  ministre text NOT NULL, cible text NOT NULL, rapports_restants integer NOT NULL DEFAULT 4,
  decouverte boolean NOT NULL DEFAULT false,
  statut text NOT NULL DEFAULT 'active' CHECK (statut IN ('active','terminee')));
CREATE UNIQUE INDEX IF NOT EXISTS sovarka_surveillances_une_par_cible
  ON public.sovarka_surveillances (cible) WHERE statut = 'active';
CREATE TABLE IF NOT EXISTS public.sovarka_surveillance_rapports (
  id bigserial PRIMARY KEY, surveillance uuid NOT NULL REFERENCES public.sovarka_surveillances(id) ON DELETE CASCADE,
  jour date NOT NULL, depuis timestamptz NOT NULL, jusqua timestamptz NOT NULL,
  deplacements jsonb NOT NULL, chance numeric, decouverte boolean NOT NULL DEFAULT false,
  ts timestamptz NOT NULL DEFAULT now(), UNIQUE (surveillance, jour));
ALTER TABLE public.sovarka_surveillances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sovarka_surveillance_rapports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_surveillances, public.sovarka_surveillance_rapports FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.sovarka_surveillance_rapports_id_seq FROM PUBLIC, anon, authenticated;

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT 'sovarka_surveiller', 2, 0 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts WHERE fn = 'sovarka_surveiller');
INSERT INTO public.actes_nocturnes_mecanismes (mecanisme, sujet_singleton, note)
SELECT 'sovarka_surveillance_rapport', false, 'Rapport nocturne d''une surveillance de Sovarka ; un rejeu renverrait le rapport, retirerait un jour et retirerait le risque de découverte.'
 WHERE NOT EXISTS (SELECT 1 FROM public.actes_nocturnes_mecanismes WHERE mecanisme = 'sovarka_surveillance_rapport');

-- Moteur : déplacements de la cible entre deux instants, avec les PJ croisés dans chaque lieu.
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_releve_interne(p_cible text, p_depuis timestamptz, p_jusqua timestamptz)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  WITH sejours AS (
    SELECT h.country, h.city, h.building_id, h.room_id, h.created_at AS debut,
           lead(h.created_at) OVER (ORDER BY h.created_at, h.id) AS fin
      FROM public.historique_deplacements h
     WHERE h.name = p_cible AND h.created_at < p_jusqua
       AND h.created_at >= coalesce((SELECT max(x.created_at) FROM public.historique_deplacements x
                                      WHERE x.name = p_cible AND x.created_at <= p_depuis), p_depuis)
  ), bornes AS (
    SELECT country, city, building_id, room_id, greatest(debut, p_depuis) AS debut, least(coalesce(fin, p_jusqua), p_jusqua) AS fin
      FROM sejours WHERE coalesce(fin, p_jusqua) > p_depuis
  ), autres AS (
    SELECT h.name, h.country, h.city, h.building_id, h.room_id, h.created_at AS debut,
           coalesce(lead(h.created_at) OVER (PARTITION BY h.name ORDER BY h.created_at, h.id), p_jusqua) AS fin
      FROM public.historique_deplacements h
     WHERE h.name <> p_cible AND h.country = 'soviet'
       AND h.created_at < p_jusqua AND h.created_at > p_depuis - interval '2 days'
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'debut', b.debut, 'fin', b.fin,
           'hors_territoire', b.country IS DISTINCT FROM 'soviet',
           'ville', CASE WHEN b.country = 'soviet' THEN b.city END,
           'batiment', CASE WHEN b.country = 'soviet' THEN b.building_id END,
           'piece', CASE WHEN b.country = 'soviet' THEN b.room_id END,
           'croises', CASE WHEN b.country = 'soviet' THEN (
             SELECT coalesce(jsonb_agg(DISTINCT a.name), '[]'::jsonb) FROM autres a
              WHERE a.city = b.city AND a.building_id IS NOT DISTINCT FROM b.building_id
                AND a.room_id IS NOT DISTINCT FROM b.room_id AND a.debut < b.fin AND a.fin > b.debut)
             ELSE '[]'::jsonb END) ORDER BY b.debut), '[]'::jsonb)
    FROM bornes b WHERE b.fin > b.debut $$;

-- Chance de découverte d'une nuit, en pour cent (Fred : perception, intelligence, sécurité de la ville).
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_chance_interne(p_cible text)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN d.country IS DISTINCT FROM 'soviet' THEN 0 ELSE
    least(40, greatest(2, 10 + 1.5 * (coalesce((d.stats->>'PER')::numeric, 10) - 10)
                          + 0.5 * (coalesce((d.stats->>'INT')::numeric, 10) - 10)
                          - (coalesce((SELECT nullif(i.data->>'isn', '')::numeric FROM public.indices_villes i
                                        WHERE i.id = d.country || '_' || d.current_city), 30) - 30) / 5)) END
    FROM public.personnages_donnees d WHERE d.name = p_cible $$;

-- Libellé d'un lieu pour le courrier (le bureau du ministre affiche les noms du jeu).
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_lieu_interne(p jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'public', 'pg_temp' AS $$
  SELECT CASE WHEN (p->>'hors_territoire')::boolean THEN 'hors du territoire' ELSE
    CASE p->>'ville' WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' WHEN 'ville_b' THEN 'Krasnov' ELSE coalesce(p->>'ville', '?') END
    || ', ' || CASE WHEN coalesce(p->>'batiment', '') LIKE 'rue%' OR coalesce(p->>'batiment', '') = '' THEN 'dans la rue'
                    ELSE initcap(replace(replace(p->>'batiment', '-', ' '), '_', ' '))
                         || coalesce(' (' || replace(replace(p->>'piece', '-', ' '), '_', ' ') || ')', '') END END $$;

REVOKE ALL ON FUNCTION public.sovarka_surveillance_releve_interne(text, timestamptz, timestamptz),
  public.sovarka_surveillance_chance_interne(text), public.sovarka_surveillance_lieu_interne(jsonb)
  FROM PUBLIC, anon, authenticated;
-- Sovarka : surveillance, portes et passe de nuit (suite de 20261108180000 ; séparation technique,
-- limite de transport du canal de migration).

-- Lecture : surveillances en cours du ministère et leurs rapports, cibles possibles.
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT public.sovarka_est_titulaire_interne(a, 'min_int') THEN RETURN jsonb_build_object('ok', false, 'raison', 'poste_requis'); END IF;
  RETURN jsonb_build_object('ok', true, 'max', 3, 'pa', 2, 'cout', 150,
    'caisse', (SELECT coalesce((data->>'solde')::numeric, 0) FROM public.caisses_batiments WHERE id = 'soviet_gouvernement-min_int'),
    'cibles', (SELECT coalesce(jsonb_agg(d.name ORDER BY d.name), '[]'::jsonb) FROM public.personnages_donnees d WHERE d.name <> a),
    'surveillances', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'ts', s.ts, 'cible', s.cible, 'ministre', s.ministre,
        'statut', s.statut, 'rapports_restants', s.rapports_restants,
        'rapports', (SELECT coalesce(jsonb_agg(jsonb_build_object('jour', r.jour, 'depuis', r.depuis, 'jusqua', r.jusqua,
                       'deplacements', r.deplacements) ORDER BY r.jour DESC), '[]'::jsonb)
                       FROM public.sovarka_surveillance_rapports r WHERE r.surveillance = s.id)) ORDER BY s.ts DESC), '[]'::jsonb)
      FROM public.sovarka_surveillances s WHERE s.statut = 'active' OR s.ts > now() - interval '7 days'));
END $$;
REVOKE ALL ON FUNCTION public.sovarka_surveillance_lire() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_surveillance_lire() TO authenticated;

-- Porte : placer un PJ sous surveillance (bureau du ministre de la Sécurité du Peuple).
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_commande(p_requete uuid, p_cible text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); act text := 'sovarka:surveillance'; par jsonb; v jsonb; dt text; p record;
  v_paie jsonb; v_caisse jsonb; v_id uuid; v_cible text := btrim(coalesce(p_cible, ''));
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  par := jsonb_build_object('cible', v_cible);
  v := public.achat_requete_ouvrir_interne(a, p_requete, act, par);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    SELECT name, country, current_city, current_building, current_room INTO p
      FROM public.personnages_donnees WHERE name = a FOR UPDATE;
    PERFORM 1 FROM public.caisses_batiments WHERE id = 'soviet_gouvernement-min_int' FOR UPDATE;
    IF p.country IS DISTINCT FROM 'soviet' THEN v := jsonb_build_object('ok', false, 'raison', 'reserve_a_sovarka');
    ELSIF NOT public.sovarka_est_titulaire_interne(a, 'min_int') THEN v := jsonb_build_object('ok', false, 'raison', 'poste_requis');
    ELSIF NOT (p.current_city = 'capitale' AND p.current_building = 'palais-gouvernement' AND p.current_room = 'bureau_min_int') THEN
      v := jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
    ELSIF v_cible = a OR NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_cible) THEN
      v := jsonb_build_object('ok', false, 'raison', 'cible_invalide');
    ELSIF EXISTS (SELECT 1 FROM public.sovarka_surveillances WHERE cible = v_cible AND statut = 'active') THEN
      v := jsonb_build_object('ok', false, 'raison', 'deja_surveille');
    ELSIF (SELECT count(*) FROM public.sovarka_surveillances WHERE statut = 'active') >= 3 THEN
      v := jsonb_build_object('ok', false, 'raison', 'limite_surveillances');
    ELSE
      v_paie := public.payer_ordre_interne(a, 'sovarka_surveiller', 2, 0);
      IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN v := v_paie;
      ELSE
        PERFORM set_config('rp.caisse_interne', 'on', true);
        v_caisse := public.caisse_institution_mouvement('soviet_gouvernement-min_int', -150, true);
        PERFORM set_config('rp.caisse_interne', 'off', true);
        IF coalesce((v_caisse->>'ok')::boolean, false) IS NOT TRUE THEN
          v := jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
        ELSE
          INSERT INTO public.sovarka_surveillances (ministre, cible) VALUES (a, v_cible) RETURNING id INTO v_id;
          v := jsonb_build_object('ok', true, 'surveillance', v_id, 'cible', v_cible, 'jours', 4,
                 'pa', v_paie->'pa', 'liquide', v_paie->'liquide', 'arg', v_paie->'arg');
        END IF;
      END IF;
    END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'acte_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS dt = PG_EXCEPTION_DETAIL; RETURN dt::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, act, par, v);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_surveillance_commande(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sovarka_surveillance_commande(uuid, text) TO authenticated;

-- Passe de nuit : un rapport par surveillance active, tirage de découverte, fin au quatrième rapport.
CREATE OR REPLACE FUNCTION public.sovarka_surveillance_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_jour date := public.sovarka_jour_paris(); s public.sovarka_surveillances; v_depuis timestamptz;
  v_dep jsonb; v_chance numeric; v_vu boolean; v_texte text; v_dest text; v_n int := 0; v_k int;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_serveur'); END IF;
  FOR s IN SELECT * FROM public.sovarka_surveillances WHERE statut = 'active' ORDER BY ts FOR UPDATE LOOP
    CONTINUE WHEN NOT public.acte_nocturne_revendiquer('soviet', 'sovarka_surveillance_rapport', s.id::text || ':' || v_jour, NULL);
    v_depuis := coalesce((SELECT max(jusqua) FROM public.sovarka_surveillance_rapports WHERE surveillance = s.id), s.ts);
    v_dep := public.sovarka_surveillance_releve_interne(s.cible, v_depuis, now());
    v_chance := CASE WHEN s.decouverte THEN NULL ELSE public.sovarka_surveillance_chance_interne(s.cible) END;
    v_vu := v_chance IS NOT NULL AND random() * 100 < v_chance;
    INSERT INTO public.sovarka_surveillance_rapports (surveillance, jour, depuis, jusqua, deplacements, chance, decouverte)
    VALUES (s.id, v_jour, v_depuis, now(), v_dep, v_chance, v_vu);
    v_k := 5 - s.rapports_restants;
    UPDATE public.sovarka_surveillances SET rapports_restants = rapports_restants - 1,
           decouverte = decouverte OR v_vu, statut = CASE WHEN rapports_restants <= 1 THEN 'terminee' ELSE 'active' END
     WHERE id = s.id;
    SELECT string_agg('• ' || to_char((e->>'debut')::timestamptz AT TIME ZONE 'Europe/Paris', 'DD/MM HH24"h"MI') || ' — '
             || public.sovarka_surveillance_lieu_interne(e)
             || CASE WHEN jsonb_array_length(e->'croises') > 0
                     THEN ' — en présence de ' || (SELECT string_agg(c, ', ') FROM jsonb_array_elements_text(e->'croises') c) ELSE '' END,
             E'\n' ORDER BY (e->>'debut')::timestamptz)
      INTO v_texte FROM jsonb_array_elements(v_dep) e;
    v_dest := coalesce(public.sovarka_titulaire_interne('min_int'), s.ministre);
    PERFORM public.mail_systeme_poser_interne('Ministère de la Sécurité du Peuple', v_dest,
      'Rapport de surveillance — ' || s.cible || ' (' || v_k || '/4)',
      'Déplacements de ' || s.cible || ' depuis le dernier rapport :' || E'\n'
      || coalesce(v_texte, 'Aucun déplacement enregistré.')
      || CASE WHEN v_k >= 4 THEN E'\n\nFin de la surveillance.' ELSE '' END, NULL);
    IF v_vu THEN
      PERFORM public.mail_systeme_poser_interne('Pressentiment', s.cible, 'Vous avez l''impression d''être suivi',
        'Depuis quelques jours, les mêmes silhouettes reviennent derrière vous, une voiture stationne trop longtemps '
        || 'devant votre porte… Vous avez la certitude d''être surveillé, sans savoir par qui ni pourquoi.', NULL);
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rapports', v_n);
END $$;
REVOKE ALL ON FUNCTION public.sovarka_surveillance_passe() FROM PUBLIC, anon, authenticated;

-- Raccordement à la passe de nuit des ministères (patch en place sous empreinte).
DO $patch$
DECLARE v_def text; v_n int;
  v_avant text := $a$'indemnites', v_pay, 'refractaires', v_ref,$a$;
  v_apres text := $b$'indemnites', v_pay, 'refractaires', v_ref, 'surveillances', public.sovarka_surveillance_passe(),$b$;
BEGIN
  v_def := pg_get_functiondef('public.sovarka_pouvoir_passe()'::regprocedure);
  IF position('sovarka_surveillance_passe' IN v_def) > 0 THEN RETURN; END IF;
  v_n := (length(v_def) - length(replace(v_def, v_avant, ''))) / length(v_avant);
  IF v_n <> 1 THEN RAISE EXCEPTION 'fragment non unique dans sovarka_pouvoir_passe (%)', v_n; END IF;
  EXECUTE replace(v_def, v_avant, v_apres);
END $patch$;
DO $banc$
DECLARE a text; ua uuid; b text; c text; r jsonb; q uuid := gen_random_uuid(); pa0 int; pa1 int; k0 numeric; k1 numeric;
  w text; v jsonb; v2 jsonb; n int; d jsonb; ch numeric;
BEGIN
  SELECT name, user_id INTO a, ua FROM public.personnages_donnees WHERE user_id IS NOT NULL AND coalesce(hp,0) > 0 ORDER BY name LIMIT 1;
  SELECT name INTO b FROM public.personnages_donnees WHERE name <> a ORDER BY name LIMIT 1;
  SELECT name INTO c FROM public.personnages_donnees WHERE name NOT IN (a, b) ORDER BY name LIMIT 1;
  w := c;
  DELETE FROM public.postes_attribues WHERE country = 'soviet' AND poste_id = 'min_int';
  INSERT INTO public.postes_attribues (id, country, poste_id, titulaire, source) VALUES ('banc-min-int', 'soviet', 'min_int', a, 'banc');
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale', current_building='palais-gouvernement',
    current_room='bureau_min_int', pa=20, poste=jsonb_build_object('id','min_int') WHERE name = a;
  UPDATE public.personnages_donnees SET country='soviet', current_city='capitale' WHERE name IN (b, c);
  -- Trajet témoin : b au Grand Hôtel avec c, puis à l'étranger.
  INSERT INTO public.historique_deplacements (name, country, city, building_id, room_id, jour, heure, created_at) VALUES
    (b, 'soviet', 'capitale', 'hotel-republica', 'hall', 1, '10h', now() - interval '3 hours'),
    (c, 'soviet', 'capitale', 'hotel-republica', 'hall', 1, '10h', now() - interval '170 minutes'),
    (c, 'soviet', 'capitale', 'rue-centrale', 'novomirsk-vue-1', 1, '11h', now() - interval '2 hours'),
    (b, 'republic', 'capitale', 'rue-centrale', 'x', 1, '12h', now() - interval '1 hour');
  SELECT (data->>'solde')::numeric INTO k0 FROM public.caisses_batiments WHERE id = 'soviet_gouvernement-min_int';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  r := public.sovarka_surveillance_commande(q, b);
  IF (r->>'ok')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc KO surveiller: %', r; END IF;
  v := public.sovarka_surveillance_commande(q, b);                                  -- rejeu
  IF v->>'surveillance' IS DISTINCT FROM r->>'surveillance' THEN RAISE EXCEPTION 'banc KO rejeu: %', v; END IF;
  v := public.sovarka_surveillance_commande(gen_random_uuid(), b);
  IF v->>'raison' IS DISTINCT FROM 'deja_surveille' THEN RAISE EXCEPTION 'banc KO double: %', v; END IF;
  v := public.sovarka_surveillance_commande(gen_random_uuid(), a);
  IF v->>'raison' IS DISTINCT FROM 'cible_invalide' THEN RAISE EXCEPTION 'banc KO soi: %', v; END IF;
  v := public.sovarka_surveillance_lire();
  IF jsonb_array_length(v->'surveillances') < 1 THEN RAISE EXCEPTION 'banc KO lire: %', v; END IF;
  RESET ROLE;
  SELECT (data->>'solde')::numeric INTO k1 FROM public.caisses_batiments WHERE id = 'soviet_gouvernement-min_int';
  SELECT pa INTO pa1 FROM public.personnages_donnees WHERE name = a;
  IF k0 - k1 <> 150 OR pa1 <> 18 THEN RAISE EXCEPTION 'banc KO paiement caisse % -> %, pa %', k0, k1, pa1; END IF;
  -- Limite de 3.
  INSERT INTO public.sovarka_surveillances (ministre, cible) SELECT a, name FROM public.personnages_donnees WHERE name NOT IN (a, b) ORDER BY name LIMIT 2;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  SELECT name INTO c FROM public.personnages_donnees WHERE name <> a AND name NOT IN (SELECT cible FROM public.sovarka_surveillances WHERE statut='active') LIMIT 1;
  v := public.sovarka_surveillance_commande(gen_random_uuid(), c);
  IF v->>'raison' IS DISTINCT FROM 'limite_surveillances' THEN RAISE EXCEPTION 'banc KO limite: %', v; END IF;
  RESET ROLE;
  -- Passe : rapport du trajet témoin, un seul par nuit.
  UPDATE public.sovarka_surveillances SET ts = now() - interval '4 hours' WHERE id = (r->>'surveillance')::uuid;
  v := public.sovarka_pouvoir_passe();
  v2 := public.sovarka_pouvoir_passe();
  SELECT deplacements INTO d FROM public.sovarka_surveillance_rapports WHERE surveillance = (r->>'surveillance')::uuid;
  SELECT count(*) INTO n FROM public.sovarka_surveillance_rapports WHERE surveillance = (r->>'surveillance')::uuid;
  IF n <> 1 OR (v2->'surveillances'->>'rapports')::int <> 0 THEN RAISE EXCEPTION 'banc KO rejeu passe: % / %', n, v2; END IF;
  IF jsonb_array_length(d) <> 2 OR NOT (d->0->'croises') ? w
     OR (d->1->>'hors_territoire')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'banc KO releve: %', d; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.mails WHERE subject LIKE 'Rapport de surveillance — ' || b || '%') THEN RAISE EXCEPTION 'banc KO mail'; END IF;
  ch := public.sovarka_surveillance_chance_interne(a);
  RAISE EXCEPTION 'banc OK : rapport %, passe %, chance ministre %', d, v->'surveillances', ch;
END $banc$;
ROLLBACK;
