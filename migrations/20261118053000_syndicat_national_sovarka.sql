-- SYNDICAT NATIONAL DE SOVARKA (Fred, 18/11/2026, « Décisions du 18/11 », points 3 et 7 ;
-- GAME-DESIGN-NOVOMIRSK.md) :
--  - un seul syndicat d'État (organisation `orga_syndicat_etat_soviet`, type « syndicale »), sans blocus ni grève ;
--    ses prérogatives sont au « Bureau du syndicat national » des mairies de Novomirsk, Krasnov et Starovka
--    (pièce `bureau_syndicat_national`) : adhérer (1 PA, 50 PSK, sans parti), quitter, élire le chef (moteur
--    générique des organisations), « Manifestation de soutien au président » ;
--  - manifestation : ordre du chef, depuis le bureau d'une ville, au moins 10 syndiqués, une par jour et par
--    ville. Tous les syndiqués présents dans la ville (quel que soit leur domicile) y participent et paient 2 PA ;
--    un syndiqué à 3 PA ou moins ne participe pas (absent). Taux = présents ÷ domiciliés dans la ville (au moins
--    1 au dénominateur). POP du président : au-dessus de 50 %, +1 par tranche de 5 % (plafond +10) ; 50 % : 0 ;
--    en dessous, −1 par tranche de 5 %. Publiée au journal d'événements et dans la presse du jour. Légale.
--  - chef initial : Lev Lozungov (PNJ), remplaçable par élection.
-- Aucune donnée de joueur modifiée. Idempotente.
BEGIN;

INSERT INTO public.organisations (id, country_origine, data)
SELECT 'orga_syndicat_etat_soviet', 'soviet', jsonb_build_object(
  'id', 'orga_syndicat_etat_soviet', 'type', 'syndicale', 'syndicatEtat', true,
  'nom', 'Syndicat national de Sovarka',
  'desc', 'Le syndicat unique d''État : fêtes du travail, médailles, colonies de vacances. Le travailleur ne bloque pas son propre outil.',
  'fondateur', 'Lev Lozungov (PNJ)', 'chef', 'Lev Lozungov (PNJ)', 'chefEstPnj', true,
  'country', 'soviet', 'country_origine', 'soviet', 'creeLe', coalesce(public.jour_de_jeu_pays('soviet'), 1),
  'membres', '[]'::jsonb, 'demandesAdhesion', '[]'::jsonb,
  'bonusLocaux', jsonb_build_object('pop', 0, 'inf', 0, 'dis', 0), 'caisse', 0, 'influence', 50,
  'election', NULL, 'visible', true)::text
 WHERE NOT EXISTS (SELECT 1 FROM public.organisations WHERE id = 'orga_syndicat_etat_soviet');

INSERT INTO public.ordres_couts (fn, pa, cost)
SELECT x.fn, x.pa, x.cost FROM (VALUES ('se_syndiquer_etat', 1, 50), ('consulter_syndicat_etat', 0, 0), ('quitter_syndicat_etat', 0, 0),
  ('declencher_election_syndicat_etat', 1, 0), ('manifestation_soutien_president', 0, 0)) AS x(fn, pa, cost)
 WHERE NOT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = x.fn);

-- Adhésion : même porte que le syndicat des dockers, au bureau du syndicat national d'une mairie de Sovarka.
DO $adh$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.organisation_adhesion_payante(text,text,text)'::regprocedure);
  IF position('orga_syndicat_etat_soviet' IN d) > 0 THEN RETURN; END IF;
  a := E'  IF p_orga IS DISTINCT FROM ''orga_syndicat_dockers_republic_ville_a'' THEN\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''adhesion_payante_inconnue'');\n  END IF;\n';
  b := E'  IF p_orga IS NULL OR p_orga NOT IN (''orga_syndicat_dockers_republic_ville_a'', ''orga_syndicat_etat_soviet'') THEN\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''adhesion_payante_inconnue'');\n  END IF;\n'
    || E'  -- Syndicat national de Sovarka (Fred, 18/11/2026) : au bureau du syndicat national d''une mairie de Sovarka.\n'
    || E'  IF p_orga = ''orga_syndicat_etat_soviet'' AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees x WHERE x.name = v_moi\n'
    || E'       AND x.country = ''soviet'' AND x.current_city IN (''capitale'', ''ville_a'', ''ville_b'') AND x.current_room = ''bureau_syndicat_national'') THEN\n'
    || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_au_bureau_syndical'');\n  END IF;\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'organisation_adhesion_payante : ancrage'; END IF;
  EXECUTE replace(d, a, b);
END $adh$;

CREATE TABLE IF NOT EXISTS public.syndicat_etat_manifestations (
  ville text NOT NULL CHECK (ville IN ('capitale', 'ville_a', 'ville_b')), jour integer NOT NULL,
  chef text NOT NULL, presents integer NOT NULL, domicilies integer NOT NULL, taux integer NOT NULL,
  effet_pop integer NOT NULL, president text, participants jsonb NOT NULL DEFAULT '[]'::jsonb,
  cree_le timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (ville, jour));
ALTER TABLE public.syndicat_etat_manifestations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.syndicat_etat_manifestations FROM PUBLIC, anon;
GRANT SELECT ON public.syndicat_etat_manifestations TO authenticated;
DROP POLICY IF EXISTS syndicat_etat_manifestations_lecture ON public.syndicat_etat_manifestations;
CREATE POLICY syndicat_etat_manifestations_lecture ON public.syndicat_etat_manifestations FOR SELECT TO authenticated USING (true);

-- Effet sur la POP du président selon le taux (en %).
CREATE OR REPLACE FUNCTION public.syndicat_etat_effet_pop(p_taux integer)
RETURNS integer LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_taux > 50 THEN least(10, (p_taux - 50) / 5)
              WHEN p_taux < 50 THEN -least(10, (50 - p_taux) / 5) ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public.syndicat_etat_manifester_interne(p_chef text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE d jsonb; v_ville text; v_nom_ville text; v_jour integer; v_noms text[]; v_participants text[];
        v_dom integer; v_pres integer; v_taux integer; v_effet integer; v_pres_nom text; v_pj boolean;
        v_txt text; v_titre text; v_corps text;
BEGIN
  SELECT data::jsonb INTO d FROM public.organisations WHERE id = 'orga_syndicat_etat_soviet' FOR UPDATE;
  IF d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'syndicat_absent'); END IF;
  IF d->>'chef' IS DISTINCT FROM p_chef THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_chef'); END IF;
  SELECT current_city INTO v_ville FROM public.personnages_donnees
   WHERE name = p_chef AND country = 'soviet' AND current_room = 'bureau_syndicat_national' AND current_city IN ('capitale', 'ville_a', 'ville_b');
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_bureau_syndical'); END IF;
  SELECT coalesce(array_agg(DISTINCT coalesce(m->>'nom', m #>> '{}')), '{}') INTO v_noms
    FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d->'membres') = 'array' THEN d->'membres' ELSE '[]'::jsonb END) m;
  IF coalesce(array_length(v_noms, 1), 0) < 10 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'syndicat_trop_petit', 'minimum', 10, 'membres', coalesce(array_length(v_noms, 1), 0));
  END IF;
  v_jour := coalesce(public.jour_de_jeu_pays('soviet'), 1);
  IF EXISTS (SELECT 1 FROM public.syndicat_etat_manifestations WHERE ville = v_ville AND jour = v_jour) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_manifeste_aujourdhui');
  END IF;
  -- Participants : syndiqués présents dans la ville avec plus de 3 PA ; 2 PA chacun.
  WITH p AS (
    UPDATE public.personnages_donnees x SET pa = pa - 2, updated_at = now()
     WHERE x.name = ANY (v_noms) AND x.country = 'soviet' AND x.current_city = v_ville AND coalesce(x.pa, 0) > 3
    RETURNING x.name)
  SELECT coalesce(array_agg(name ORDER BY name), '{}') INTO v_participants FROM p;
  v_pres := coalesce(array_length(v_participants, 1), 0);
  SELECT count(*) INTO v_dom FROM public.personnages_donnees x
   WHERE x.name = ANY (v_noms) AND x.domicile->>'country' = 'soviet' AND x.domicile->>'city' = v_ville;
  v_taux := floor(v_pres * 100.0 / greatest(v_dom, 1))::integer;
  v_effet := public.syndicat_etat_effet_pop(v_taux);
  SELECT nullif(data::jsonb->>'eluId', '') INTO v_pres_nom FROM public.cycles_electoraux WHERE id = 'soviet_president';
  v_pj := v_pres_nom IS NOT NULL AND EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = v_pres_nom);
  IF v_pj AND v_effet <> 0 THEN PERFORM public.jauges_effet_appliquer_interne(v_pres_nom, v_effet, 0, 0); END IF;
  v_nom_ville := CASE v_ville WHEN 'capitale' THEN 'Novomirsk' WHEN 'ville_a' THEN 'Starovka' ELSE 'Krasnov' END;
  v_txt := 'Manifestation de soutien au président à ' || v_nom_ville || ' : ' || v_pres || ' syndiqué(s) dans le cortège pour '
        || v_dom || ' domicilié(s), participation ' || v_taux || ' %. '
        || CASE WHEN v_pres_nom IS NULL THEN 'Présidence vacante : aucun effet.'
                WHEN NOT v_pj THEN 'Président non joueur : popularité non suivie, aucun effet.'
                WHEN v_effet > 0 THEN 'Popularité du président : +' || v_effet || '.'
                WHEN v_effet < 0 THEN 'Désaveu : popularité du président ' || v_effet || '.'
                ELSE 'Aucun effet sur la popularité du président.' END;
  INSERT INTO public.evenements_globaux (country, city, texte, jour) VALUES ('soviet', v_ville, '🚩 ' || v_txt, v_jour);
  v_titre := 'Le Syndicat national défile à ' || v_nom_ville;
  v_corps := 'Sous la conduite de ' || replace(p_chef, ' (PNJ)', '') || ', chef du Syndicat national, ' || v_pres
          || ' syndiqué(s) ont défilé à ' || v_nom_ville || ' en soutien au président'
          || CASE WHEN v_pres_nom IS NOT NULL THEN ' ' || replace(v_pres_nom, ' (PNJ)', '') ELSE '' END
          || '. Pour ' || v_dom || ' syndiqué(s) domicilié(s) dans la ville, la participation atteint ' || v_taux || ' %. '
          || CASE WHEN NOT v_pj THEN 'La présidence n''étant pas tenue par un citoyen joueur, le défilé reste sans effet sur sa popularité.'
                  WHEN v_effet > 0 THEN 'Effet sur la popularité du président : +' || v_effet || '.'
                  WHEN v_effet < 0 THEN 'Le cortège clairsemé sonne comme un désaveu : ' || v_effet || ' de popularité pour le président.'
                  ELSE 'Effet nul sur la popularité du président.' END;
  INSERT INTO public.journal_articles_en_attente (id, country, rubrique, titre, texte, ville, statut, origine, priorite, dedup_key, expire_le, fait_json)
  VALUES ('manif-soutien-' || v_ville || '-' || v_jour, 'soviet', 'politique', v_titre, v_corps, v_ville, 'attente', 'syndicat_etat',
          'importante', 'manif-soutien-' || v_ville || '-' || v_jour, now() + interval '2 days',
          jsonb_build_object('presents', v_pres, 'domicilies', v_dom, 'taux', v_taux, 'effet_pop', v_effet, 'president', v_pres_nom))
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.syndicat_etat_manifestations (ville, jour, chef, presents, domicilies, taux, effet_pop, president, participants)
  VALUES (v_ville, v_jour, p_chef, v_pres, v_dom, v_taux, CASE WHEN v_pj THEN v_effet ELSE 0 END, v_pres_nom, to_jsonb(v_participants));
  RETURN jsonb_build_object('ok', true, 'ville', v_ville, 'jour', v_jour, 'presents', v_pres, 'domicilies', v_dom,
    'taux', v_taux, 'effet_pop', CASE WHEN v_pj THEN v_effet ELSE 0 END, 'effet_calcule', v_effet, 'president', v_pres_nom, 'president_pj', v_pj,
    'membres', array_length(v_noms, 1), 'participe', p_chef = ANY (v_participants))
    || (SELECT jsonb_build_object('pa', pa) FROM public.personnages_donnees WHERE name = p_chef);
END $function$;
REVOKE ALL ON FUNCTION public.syndicat_etat_manifester_interne(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.syndicat_etat_manifester(p_requete uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
DECLARE a text := public.mon_personnage(); prm jsonb := '{}'::jsonb; v jsonb; d text;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'syndicat_etat_manifester', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.syndicat_etat_manifester_interne(a);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'refus' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'syndicat_etat_manifester', prm, v);
END $function$;
REVOKE ALL ON FUNCTION public.syndicat_etat_manifester(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.syndicat_etat_manifester(uuid) TO authenticated;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.organisations WHERE id = 'orga_syndicat_etat_soviet')
     OR position('orga_syndicat_etat_soviet' IN pg_get_functiondef('public.organisation_adhesion_payante(text,text,text)'::regprocedure)) = 0
     OR public.syndicat_etat_effet_pop(100) <> 10 OR public.syndicat_etat_effet_pop(40) <> -2
     OR public.syndicat_etat_effet_pop(50) <> 0 OR public.syndicat_etat_effet_pop(250) <> 10 OR public.syndicat_etat_effet_pop(0) <> -10
  THEN RAISE EXCEPTION 'syndicat_national_sovarka : controle structurel en echec'; END IF;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;
