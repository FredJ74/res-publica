-- NON APPLIQUÉE — mission « Purge » du 24/11/2026, bloc D (climat), point D.3 (consigne de Fred) :
-- « L'arrêt doit réellement s'appliquer : la tâche de minuit passe avant la pose des effets. Banc. »
-- Constat (base lue le 24/11) : la nuit des chantiers (api/cron-minuit.js → chantier_jour_traiter, 0 h à Paris) ne connaissait
-- que la crue (chantier_crue_jour_interne). La canicule « bloquait » seulement le travail des joueurs pendant ses 6 heures : la
-- nuit suivante, le chantier avançait normalement (cas de la canicule de Luthécia du 22/11, 0 h – 6 h : la tâche de minuit était
-- passée à 0 h, avant la pose de ses effets à 0 h 17 par climat_passe, et rien ne l'arrêtait plus ensuite).
-- Correction, sans toucher api/cron-minuit.js (commun) ni chantier_jour_traiter (son appel unique, marque crue_chantier_jour_v1,
-- reste) :
-- • chantier_crue_jour_interne traite la crue ET la canicule : la nuit qui suit le jour (heure de Paris) où l'événement a
--   commencé, le chantier n'avance pas (aucun salaire, aucune consommation ni commande de matériaux) ; ligne « crue » ou
--   « canicule » dans le journal du chantier. La décision lit la DATE de début de l'événement, jamais `effets_le` : l'ordre entre
--   la tâche de minuit et la pose des effets (climat_passe, 17 de chaque heure) n'a plus d'importance.
-- • climat_chantiers_bloques_interne : le travail des joueurs est refusé du début de la canicule jusqu'à minuit, comme pour la crue.
-- • Réglage MJ conservé : « Bloque les chantiers » (climat_parametres.bloque_chantiers) de la crue et de la canicule.
-- Rejouable (CREATE OR REPLACE de deux fonctions propres au climat). Aucun objet du goulag.
BEGIN;
CREATE OR REPLACE FUNCTION public.climat_chantiers_bloques_interne(p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT EXISTS (SELECT 1 FROM public.climat_evenements e JOIN public.climat_parametres c ON c.type = e.type AND c.pays = e.pays
                  WHERE e.pays = p_pays AND e.ville = p_ville AND NOT e.annule AND e.alerte_le IS NOT NULL
                    AND now() >= e.debut AND c.bloque_chantiers
                    AND now() < CASE WHEN e.type IN ('crue', 'canicule') /* climat_arret_journee_v1 */
                                     THEN greatest(e.fin, public.climat_minuit_interne((e.debut AT TIME ZONE 'Europe/Paris')::date + 1))
                                     ELSE e.fin END);
$$;
REVOKE ALL ON FUNCTION public.climat_chantiers_bloques_interne(text, text) FROM PUBLIC, anon, authenticated;

-- Nuit du chantier : un jour de retard après une crue ou une canicule de la ville (veille, heure de Paris).
CREATE OR REPLACE FUNCTION public.chantier_crue_jour_interne(p_terrain_id text, p_pays text, p_etat jsonb, p_emplacement text, p_jour text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE ch jsonb := p_etat -> p_emplacement; v_id bigint; v_type text; v_etat jsonb;
BEGIN
  IF jsonb_typeof(ch) IS DISTINCT FROM 'object' OR coalesce((ch->>'attenteReception')::boolean, false) THEN RETURN NULL; END IF;
  SELECT e.id, e.type INTO v_id, v_type FROM public.climat_evenements e JOIN public.climat_parametres c ON c.type = e.type AND c.pays = e.pays
   WHERE e.type IN ('crue', 'canicule') /* climat_arret_journee_v1 */ AND e.pays = p_pays AND e.ville = p_etat->>'city'
     AND NOT e.annule AND e.alerte_le IS NOT NULL
     AND c.bloque_chantiers AND e.debut <= now() AND (e.debut AT TIME ZONE 'Europe/Paris')::date = p_jour::date - 1
   ORDER BY e.debut LIMIT 1;
  IF v_id IS NULL THEN RETURN NULL; END IF;
  ch := ch || jsonb_build_object('jourTraite', p_jour,
    'evenements', coalesce(ch->'evenements', '[]'::jsonb) || jsonb_build_array(jsonb_build_object('cle', v_type, 'date', p_jour, 'avance', 0, 'evenement', v_id)));
  v_etat := p_etat || jsonb_build_object(p_emplacement, ch);
  UPDATE public.terrains_etat SET data = v_etat::text, updated_at = now() WHERE id = p_terrain_id;
  RETURN jsonb_build_object('ok', true, 'etat', v_etat, 'attenteReception', false, 'avance', 0, 'crue', v_type = 'crue', 'climat', v_type, 'evenement', v_id);
END $$;
REVOKE ALL ON FUNCTION public.chantier_crue_jour_interne(text, text, jsonb, text, text) FROM PUBLIC, anon, authenticated;
COMMIT;
