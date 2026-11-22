-- Chantier — heures et matériaux (Fred, 22/11/2026, nuit, point 2) :
-- • Les heures de travail du jour sont TOUJOURS ouvertes en totalité (≈ 50 h pour un building), quel que soit le stock.
--   Le jour d'avance s'ouvre de même en totalité une fois les heures du jour faites.
-- • La nuit, à la clôture du jour : le chantier consomme ce qu'il a pour le jour écoulé (inchangé), puis commande
--   immédiatement à l'entrepôt de sa ville les matériaux de la journée SUIVANTE (limite : stock de l'entrepôt et
--   trésorerie du chantier). Le stock est plein dès le matin.
-- • Quand le jour d'avance s'ouvre grâce aux joueurs, la commande pour ce jour part aussitôt.
-- • Ce que l'entrepôt ne peut pas fournir reste à acheter aux joueurs ; le courrier « Chantier à l'arrêt : matériaux
--   manquants » est remplacé par une entrée au journal du chantier (onglet État), qui invite les passants à vendre.
-- • Dernière commande gardée dans le chantier (derniereCommande : quantités livrées, manquantes, coût), affichée
--   dans l'onglet Gestion. Pas de bouton de commande manuelle.
-- Raccords (marques chantier_heures_ouvertes_v1, chantier_sans_courrier_v1, chantier_commande_nuit_v1,
-- chantier_commande_avance_v1). Aucun objet du goulag touché.
BEGIN;

-- Une commande à l'entrepôt de la ville : achète ce qui manque pour p_besoin, consigne le résultat au journal.
CREATE OR REPLACE FUNCTION public.chantier_commande_materiaux_interne(p_ch jsonb, p_acteur text, p_pays text, p_ville text,
  p_besoin jsonb, p_jour text, p_pour_jour integer, p_motif text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ch jsonb := p_ch; entrepot text; plan jsonb; stock jsonb; manque jsonb := '{}'::jsonb; m text; ev jsonb; q numeric;
BEGIN
  IF p_besoin IS NULL THEN RETURN ch; END IF;
  SELECT building_id INTO entrepot FROM public.entrepots_par_ville WHERE pays = p_pays AND ville = p_ville;
  stock := coalesce(ch->'stockMateriaux', '{}'::jsonb);
  IF entrepot IS NOT NULL AND nullif(p_acteur, '') IS NOT NULL THEN
    plan := public.approvisionner_chantier(p_acteur, p_pays, p_ville, entrepot, p_besoin, stock, greatest(0, coalesce((ch->>'tresorerie')::numeric, 0)));
    IF NOT coalesce((plan->>'ok')::boolean, false) THEN RAISE EXCEPTION 'approvisionnement_non_confirme'; END IF;
    stock := stock || coalesce(plan->'stockChantier', '{}'::jsonb);
    ch := ch || jsonb_build_object('stockMateriaux', stock,
      'tresorerie', coalesce((ch->>'tresorerie')::numeric, 0) - coalesce((plan->>'depense')::numeric, 0));
  END IF;
  FOREACH m IN ARRAY ARRAY['bois', 'minerai', 'metal'] LOOP
    q := coalesce((p_besoin->>m)::numeric, 0) - greatest(0, coalesce((stock->>m)::numeric, 0));
    IF q > 0 THEN manque := manque || jsonb_build_object(m, q); END IF;
  END LOOP;
  ev := jsonb_build_object('cle', 'commande_materiaux', 'motif', p_motif, 'date', p_jour, 'pourJour', p_pour_jour, 'ville', p_ville,
    'livre', coalesce(plan->'achats', '{}'::jsonb), 'manque', manque, 'cout', coalesce((plan->>'depense')::numeric, 0));
  ch := ch || jsonb_build_object('derniereCommande', ev,
    'evenements', coalesce(ch->'evenements', '[]'::jsonb) || jsonb_build_array(ev)
      || CASE WHEN manque <> '{}'::jsonb THEN jsonb_build_array(jsonb_build_object('cle', 'manque_materiaux', 'date', p_jour,
           'pourJour', p_pour_jour, 'manque', manque)) ELSE '[]'::jsonb END);
  RETURN ch;
END $function$;

-- Nuit : après la clôture (et le jour d'avance éventuel), commande pour le jour suivant.
CREATE OR REPLACE FUNCTION public.chantier_commande_nuit_interne(p_ch jsonb, p_source jsonb, p_pays text, p_ville text, p_d numeric, p_jour text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_prog numeric := coalesce((p_ch->>'progressionJours')::numeric, 0); v_num integer;
BEGIN
  IF v_prog >= p_d OR coalesce((p_ch->>'attenteReception')::boolean, false) THEN RETURN p_ch; END IF;
  v_num := floor(v_prog)::integer + 1;
  RETURN public.chantier_commande_materiaux_interne(p_ch, p_source->>'destinataire', p_pays, p_ville,
    public.chantier_besoin_jour_interne(p_ch, v_num), p_jour, v_num, 'nuit');
END $function$;

-- Jour d'avance ouvert par les joueurs : la commande de ce jour part aussitôt (une fois par jour).
CREATE OR REPLACE FUNCTION public.chantier_commande_avance_interne(p_ch jsonb, p_acteur text, p_pays text, p_ville text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_jour text := (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text;
        v_prog numeric := coalesce((p_ch->>'progressionJours')::numeric, 0); v_num integer; b1 jsonb; b2 jsonb; tot jsonb := '{}'::jsonb; m text;
BEGIN
  IF p_ch->'jourAvance'->>'jour' IS DISTINCT FROM v_jour OR coalesce((p_ch->'jourAvance'->>'heures')::numeric, 0) <= 0 THEN RETURN p_ch; END IF;
  IF p_ch->'derniereCommande'->>'motif' = 'avance' AND p_ch->'derniereCommande'->>'date' = v_jour THEN RETURN p_ch; END IF;
  v_num := floor(v_prog)::integer + 1;
  IF v_num + 1 > coalesce((p_ch->>'dureeJours')::numeric, 0) THEN RETURN p_ch; END IF;
  b1 := public.chantier_besoin_jour_interne(p_ch, v_num); b2 := public.chantier_besoin_jour_interne(p_ch, v_num + 1);
  IF b1 IS NULL OR b2 IS NULL THEN RETURN p_ch; END IF;
  FOREACH m IN ARRAY ARRAY['bois', 'minerai', 'metal'] LOOP
    tot := tot || jsonb_build_object(m, coalesce((b1->>m)::numeric, 0) + coalesce((b2->>m)::numeric, 0));
  END LOOP;
  RETURN public.chantier_commande_materiaux_interne(p_ch, p_acteur, p_pays, p_ville, tot, v_jour, v_num + 1, 'avance');
END $function$;
REVOKE ALL ON FUNCTION public.chantier_commande_materiaux_interne(jsonb, text, text, text, jsonb, text, integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.chantier_commande_nuit_interne(jsonb, jsonb, text, text, numeric, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.chantier_commande_avance_interne(jsonb, text, text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN RAISE EXCEPTION '% : ancrage (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
-- Heures toujours ouvertes (jour courant et jour d'avance).
SELECT pg_temp.rp_raccorder('public.chantier_travailler(text, text, text, integer)'::regprocedure,
  $a$v_utiles:=floor(v_capacite*least(v_fraction,greatest(0,v_plafond$a$,
  $b$v_utiles:=floor(v_capacite*least(1 /* chantier_heures_ouvertes_v1 */,greatest(0,v_plafond$b$,
  'chantier_heures_ouvertes_v1');
SELECT pg_temp.rp_raccorder('public.chantier_avance_heures_interne(jsonb, numeric, numeric, numeric)'::regprocedure,
  $a$floor(p_capacite * least(1, f, greatest(0, p_plafond - v_prog - 1)))$a$,
  $b$floor(p_capacite * least(1 /* chantier_heures_ouvertes_v1 */, greatest(0, p_plafond - v_prog - 1)))$b$,
  'chantier_heures_ouvertes_v1');
-- Commande aussitôt le jour d'avance ouvert.
SELECT pg_temp.rp_raccorder('public.chantier_travailler(text, text, text, integer)'::regprocedure,
  $a$  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object(v_emplacement, v_ch))::text$a$,
  $b$  v_ch := public.chantier_commande_avance_interne(v_ch, p_acteur, p_pays, v_data->>'city') /* chantier_commande_avance_v1 */;
  UPDATE public.terrains_etat
     SET data = (v_data || jsonb_build_object(v_emplacement, v_ch))::text$b$,
  'chantier_commande_avance_v1');
-- Plus de courrier de pénurie : l'entrée au journal le remplace.
SELECT pg_temp.rp_raccorder('public.chantier_jour_traiter(text)'::regprocedure,
  $a$IF ch->>'manqueMateriauxAvise' IS NULL THEN$a$,
  $b$IF false /* chantier_sans_courrier_v1 */ AND ch->>'manqueMateriauxAvise' IS NULL THEN$b$,
  'chantier_sans_courrier_v1');
-- Commande de nuit pour le jour suivant, après la clôture et le jour d'avance.
SELECT pg_temp.rp_raccorder('public.chantier_jour_traiter(text)'::regprocedure,
  $a$ ch:=ch||jsonb_build_object('jourTraite',jour);$a$,
  $b$ ch:=public.chantier_commande_nuit_interne(ch,source,r.country,etat->>'city',d,jour) /* chantier_commande_nuit_v1 */;
 ch:=ch||jsonb_build_object('jourTraite',jour);$b$,
  'chantier_commande_nuit_v1');
COMMIT;
