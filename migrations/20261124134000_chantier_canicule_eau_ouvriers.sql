-- NON APPLIQUÉE — mission « Purge » du 24/11/2026, bloc D (climat), point D.4 (consigne de Fred) :
-- « Canicule : image dédiée, et bouton « Offrir 20 bouteilles d'eau aux ouvriers » (ouvert à tout joueur présent, avec « ? »,
--   inscrit au journal du chantier). »
-- • RPC chantier_canicule_offrir_eau(p_requete, p_batiment) : tout joueur présent sur le terrain du chantier (même pays, même
--   ville, dans le lieu), pendant l'arrêt de canicule de la ville (du début de la canicule à minuit), donne 20 bouteilles d'eau
--   de son inventaire (réglage MJ aliments_parametres.canicule_eau_ouvriers_bouteilles). 0 PA, 0 argent (rien n'est dit d'un
--   coût : question posée à Fred). Une seule fois par chantier et par canicule. Ligne « eau_offerte » au journal du chantier
--   (cle, date, par, evenement, bouteilles). Idempotente par requête.
-- • Effet (choix de Claude, à confirmer par Fred — réglage MJ aliments_parametres.canicule_eau_leve_arret, 1 = oui) : l'eau
--   offerte lève l'arrêt de canicule POUR CE CHANTIER : les joueurs peuvent y travailler et la nuit suivante le chantier avance.
--   Raccords : chantier_crue_jour_interne (marque canicule_eau_ouvriers_v1) et chantier_travailler (même marque), qui lit la
--   nouvelle climat_chantier_bloque_interne(pays, ville, batiment).
-- • chantier_climat_etat(p_batiment) : ce que la zone d'alerte climatique de la fenêtre du chantier affiche (canicule en cours,
--   fin de l'arrêt, eau déjà offerte et par qui, bouteilles requises et possédées).
-- Rejouable (CREATE OR REPLACE, ON CONFLICT, marques). Aucune fonction commune du cron, aucun objet du goulag.
BEGIN;
INSERT INTO public.aliments_parametres (cle, valeur) VALUES ('canicule_eau_ouvriers_bouteilles', 20), ('canicule_eau_leve_arret', 1)
ON CONFLICT (cle) DO NOTHING;

-- Canicule qui arrête aujourd'hui les chantiers d'une ville (NULL sinon).
CREATE OR REPLACE FUNCTION public.climat_canicule_arret_interne(p_pays text, p_ville text)
RETURNS public.climat_evenements LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT e.* FROM public.climat_evenements e JOIN public.climat_parametres c ON c.type = e.type AND c.pays = e.pays
   WHERE e.type = 'canicule' AND e.pays = p_pays AND e.ville = p_ville AND NOT e.annule AND e.alerte_le IS NOT NULL AND c.bloque_chantiers
     AND now() >= e.debut AND now() < greatest(e.fin, public.climat_minuit_interne((e.debut AT TIME ZONE 'Europe/Paris')::date + 1))
   ORDER BY e.debut LIMIT 1;
$$;

-- L'eau a-t-elle été offerte sur ce chantier pour cet événement ?
CREATE OR REPLACE FUNCTION public.chantier_eau_offerte_interne(p_ch jsonb, p_evenement bigint)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT e FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_ch->'evenements') = 'array' THEN p_ch->'evenements' ELSE '[]'::jsonb END) e
   WHERE e->>'cle' = 'eau_offerte' AND (e->>'evenement')::bigint = p_evenement LIMIT 1;
$$;

-- Chantier de ce terrain (construction ou réaménagement), NULL sinon.
CREATE OR REPLACE FUNCTION public.chantier_de_terrain_interne(p_data jsonb)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN jsonb_typeof(p_data->'chantier') = 'object' THEN 'chantier'
              WHEN jsonb_typeof(p_data->'chantierReamenagement') = 'object' THEN 'chantierReamenagement' END;
$$;

-- Travail des joueurs : arrêt climatique de la ville, sauf canicule levée sur ce chantier par l'eau offerte.
CREATE OR REPLACE FUNCTION public.climat_chantier_bloque_interne(p_pays text, p_ville text, p_batiment text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE e public.climat_evenements; d jsonb; emp text;
BEGIN
  IF NOT public.climat_chantiers_bloques_interne(p_pays, p_ville) THEN RETURN false; END IF;
  IF public.aliments_param_interne('canicule_eau_leve_arret', 1) <> 1 THEN RETURN true; END IF;
  e := public.climat_canicule_arret_interne(p_pays, p_ville);
  IF e.id IS NULL THEN RETURN true; END IF;
  -- Seule la canicule peut être levée : un autre événement bloquant (crue) garde l'arrêt.
  IF EXISTS (SELECT 1 FROM public.climat_evenements x JOIN public.climat_parametres c ON c.type = x.type AND c.pays = x.pays
              WHERE x.pays = p_pays AND x.ville = p_ville AND NOT x.annule AND x.alerte_le IS NOT NULL AND c.bloque_chantiers
                AND x.type <> 'canicule' AND now() >= x.debut
                AND now() < CASE WHEN x.type = 'crue' THEN greatest(x.fin, public.climat_minuit_interne((x.debut AT TIME ZONE 'Europe/Paris')::date + 1)) ELSE x.fin END) THEN
    RETURN true;
  END IF;
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE id IN (p_batiment, p_pays || '_' || p_batiment) AND country = p_pays ORDER BY (id = p_batiment) DESC LIMIT 1;
  emp := public.chantier_de_terrain_interne(d);
  RETURN emp IS NULL OR public.chantier_eau_offerte_interne(d->emp, e.id) IS NULL;
END $$;

CREATE OR REPLACE FUNCTION public.chantier_climat_etat(p_batiment text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); p public.personnages_donnees; e public.climat_evenements; d jsonb; emp text; v_offre jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = a;
  e := public.climat_canicule_arret_interne(p.country, p.current_city);
  SELECT data::jsonb INTO d FROM public.terrains_etat WHERE id = p.country || '_' || p_batiment;
  emp := public.chantier_de_terrain_interne(d);
  IF e.id IS NOT NULL AND emp IS NOT NULL THEN v_offre := public.chantier_eau_offerte_interne(d->emp, e.id); END IF;
  RETURN jsonb_build_object('ok', true, 'canicule', e.id IS NOT NULL,
    'evenement', e.id, 'fin_arret', CASE WHEN e.id IS NOT NULL THEN greatest(e.fin, public.climat_minuit_interne((e.debut AT TIME ZONE 'Europe/Paris')::date + 1)) END,
    'eau_offerte', v_offre, 'leve_arret', public.aliments_param_interne('canicule_eau_leve_arret', 1) = 1,
    'requis', public.aliments_param_interne('canicule_eau_ouvriers_bouteilles', 20)::integer,
    'possede', public.inventaire_quantite(coalesce(p.inventory, '[]'::jsonb), 'bouteille_eau')::integer,
    'present', p.current_building = p_batiment AND d IS NOT NULL AND d->>'city' = p.current_city);
END $$;

CREATE OR REPLACE FUNCTION public.chantier_canicule_offrir_eau(p_requete uuid, p_batiment text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb := jsonb_build_object('batiment', p_batiment); v jsonb; p public.personnages_donnees;
        e public.climat_evenements; r public.terrains_etat; d jsonb; emp text; ch jsonb; v_n integer; v_jour text; v_deja jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL OR coalesce(p_batiment, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'chantier_canicule_offrir_eau', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = a FOR UPDATE;
  SELECT * INTO r FROM public.terrains_etat WHERE id = p.country || '_' || p_batiment FOR UPDATE;
  d := r.data::jsonb; emp := public.chantier_de_terrain_interne(d);
  IF r.id IS NULL OR p.current_building IS DISTINCT FROM p_batiment OR d->>'city' IS DISTINCT FROM p.current_city THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_le_chantier'); END IF;
  IF emp IS NULL OR coalesce((d->emp->>'attenteReception')::boolean, false) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_chantier'); END IF;
  e := public.climat_canicule_arret_interne(p.country, p.current_city);
  IF e.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_de_canicule'); END IF;
  ch := d->emp;
  v_deja := public.chantier_eau_offerte_interne(ch, e.id);
  IF v_deja IS NOT NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'deja_offerte', 'par', v_deja->>'par'); END IF;
  v_n := public.aliments_param_interne('canicule_eau_ouvriers_bouteilles', 20)::integer;
  IF public.inventaire_quantite(coalesce(p.inventory, '[]'::jsonb), 'bouteille_eau') < v_n THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bouteilles_insuffisantes', 'requis', v_n,
      'possede', public.inventaire_quantite(coalesce(p.inventory, '[]'::jsonb), 'bouteille_eau')::integer); END IF;
  UPDATE public.personnages_donnees SET inventory = public.inventaire_retirer(coalesce(inventory, '[]'::jsonb), 'bouteille_eau', v_n), updated_at = now()
   WHERE name = a;
  v_jour := ((now() AT TIME ZONE 'Europe/Paris')::date)::text;
  ch := ch || jsonb_build_object('evenements', coalesce(ch->'evenements', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
          'cle', 'eau_offerte', 'date', v_jour, 'par', a, 'evenement', e.id, 'bouteilles', v_n, 'le', now())));
  UPDATE public.terrains_etat SET data = (d || jsonb_build_object(emp, ch))::text, updated_at = now() WHERE id = r.id;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'chantier_canicule_offrir_eau', prm,
    jsonb_build_object('ok', true, 'bouteilles', v_n, 'evenement', e.id, 'leve_arret', public.aliments_param_interne('canicule_eau_leve_arret', 1) = 1,
      'inventory', (SELECT inventory FROM public.personnages_donnees WHERE name = a)));
END $$;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

-- Nuit : une canicule levée par l'eau offerte n'arrête pas ce chantier.
SELECT pg_temp.rp_remplacer('public.chantier_crue_jour_interne(text,text,jsonb,text,text)'::regprocedure,
  $a$  IF v_id IS NULL THEN RETURN NULL; END IF;$a$,
  $b$  IF v_id IS NULL THEN RETURN NULL; END IF;
  IF v_type = 'canicule' AND public.aliments_param_interne('canicule_eau_leve_arret', 1) = 1
     AND public.chantier_eau_offerte_interne(ch, v_id) IS NOT NULL THEN RETURN NULL; END IF; /* canicule_eau_ouvriers_v1 */$b$,
  1, 'canicule_eau_ouvriers_v1');

-- Travail des joueurs : arrêt lu par chantier (eau offerte).
SELECT pg_temp.rp_remplacer('public.chantier_travailler(text,text,text,integer)'::regprocedure,
  $a$IF public.climat_chantiers_bloques_interne(p_pays, (SELECT current_city FROM public.personnages_donnees WHERE name = p_acteur)) THEN -- climat_chantiers_v1$a$,
  $b$IF public.climat_chantier_bloque_interne(p_pays, (SELECT current_city FROM public.personnages_donnees WHERE name = p_acteur), p_batiment) THEN -- climat_chantiers_v1 canicule_eau_ouvriers_v1$b$,
  1, 'canicule_eau_ouvriers_v1');

REVOKE ALL ON FUNCTION public.climat_canicule_arret_interne(text, text), public.chantier_eau_offerte_interne(jsonb, bigint),
  public.chantier_de_terrain_interne(jsonb), public.climat_chantier_bloque_interne(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.chantier_climat_etat(text), public.chantier_canicule_offrir_eau(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chantier_climat_etat(text), public.chantier_canicule_offrir_eau(uuid, text) TO authenticated;
COMMIT;
