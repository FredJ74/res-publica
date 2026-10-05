-- =============================================================================================
-- REPOS QUOTIDIEN DE LA SECTION (23 septembre 2026)
-- =============================================================================================
-- CE QUE CELA AJOUTE, ET POURQUOI. L'entrainement coute 6 PA a chaque soldat sur 12, et les PA
-- d'un soldat sont aussi ses points de vie au combat. Jusqu'ici rien ne les regenerait : seules
-- la ration et le bivouac rendaient +1 PA par jour, soit trois jours pour effacer une seule
-- seance. Le cout de 6 PA est VOULU, mais il doit etre un budget de la journee, pas une dette de
-- la semaine. Le Lieutenant dispose donc d'un ordre de repos quotidien de sa section.
--
-- POURQUOI PAS UNE TROISIEME ACTION DE militaire_ordre_collectif. L'ordre collectif ne connait
-- que les soldats MENES par un chef (leaderCourant = le leader). Le repos, lui, porte sur TOUTE
-- la section, y compris les soldats deposes quelque part sans chef -- precisement ceux qui, sans
-- cela, resteraient epuises indefiniment. Le perimetre n'est pas le meme, la fonction non plus.
-- Les conventions, elles, sont reprises telles quelles : autorite par militaire_section_de_moi,
-- verrou FOR UPDATE herite, marqueur journalier a la date Europe/Paris, plafond 12, ecriture par
-- militaire_sections_remplacer.
--
-- POSITION EFFECTIVE D'UN SOLDAT. Invariant deja pose par tout le moteur : un soldat qui suit un
-- chef n'a PAS de position propre (militaire_recuperer_soldats efface ville/buildingId/roomId en
-- posant leaderCourant). Sa position EST celle de son chef. Le repos lit donc
-- personnages_donnees.current_building du leader quand il y en a un, et le buildingId du soldat
-- sinon. Sans cela, un soldat mene par un Lieutenant present a la caserne serait compte « sur le
-- terrain », ce qui est faux.
--
-- MORTALITE. 0 PA = soldat mort, et un mort est retire du blob par militaire_soldat_supprimer.
-- La garde pa > 0 est donc defensive : elle garantit que le repos ne ressuscite jamais rien, meme
-- si une ligne a 0 subsistait.
--
-- AUCUN COUT. 0 PA et 0 FR pour le Lieutenant : payer_ordre n'est pas appele, et l'ordre est
-- declare 0/0 cote data.js -- deduireCoutOrdre ne consulte le miroir que si l'un des deux est
-- strictement positif. Le cout strategique est l'usage du repos quotidien lui-meme.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.militaire_reposer_section(p_compagnie_id text, p_section_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  c_pa_max         constant integer := 12;
  c_gain_terrain   constant integer := 8;
  c_bonus_tente    constant integer := 2;
  c_capacite_tente constant integer := 13;
  g record; v_sec jsonb; v_sols jsonb; v_jour text;
  v_caserne integer; v_tente integer; v_terrain integer; v_deja integer; v_total integer;
BEGIN
  -- AUTORITE : le Lieutenant STRUCTUREL de cette section, et personne d'autre. Ni le Capitaine,
  -- ni le Commandant, ni un leader operationnel. Le verrou FOR UPDATE sur la compagnie est pris
  -- ici, avant toute lecture des soldats.
  SELECT * INTO g FROM public.militaire_section_de_moi(p_compagnie_id, p_section_id);
  IF g.o_raison IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', g.o_raison);
  END IF;

  SELECT s INTO v_sec FROM jsonb_array_elements(g.o_data->'sections') s
   WHERE s->>'id' = p_section_id;
  v_sols := CASE WHEN jsonb_typeof(v_sec->'soldats') = 'array' THEN v_sec->'soldats' ELSE '[]'::jsonb END;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  WITH base AS (
    SELECT sol, pos,
           NOT coalesce((sol->>'pj')::boolean, false)        AS est_pnj,
           coalesce((sol->>'pa')::numeric, 0)::integer       AS pa,
           nullif(btrim(coalesce(sol->>'leaderCourant','')), '') AS leader,
           coalesce(sol->>'dernier_sommeil', '')             AS marqueur
      FROM jsonb_array_elements(v_sols) WITH ORDINALITY AS t(sol, pos)
  ),
  situe AS (
    -- Position EFFECTIVE : celle du chef si le soldat en suit un, la sienne sinon.
    SELECT b.*,
           coalesce(pd.current_building, b.sol->>'buildingId') AS batiment
      FROM base b
      LEFT JOIN public.personnages_donnees pd
             ON b.leader IS NOT NULL AND pd.name = b.leader
  ),
  eligible AS (
    SELECT s.*,
           (s.est_pnj AND s.pa > 0 AND s.marqueur <> v_jour)   AS peut,
           (coalesce(s.batiment, '') = 'caserne-militaire')    AS a_la_caserne
      FROM situe s
  ),
  -- Une tente couvre 13 hommes. La couverture se calcule PAR LEADER, sur ses propres tentes :
  -- jamais de mutualisation entre groupes. Elle ne concerne que le terrain.
  tentes AS (
    SELECT l.leader,
           (SELECT count(*) FROM jsonb_array_elements(
                     CASE WHEN jsonb_typeof(pd.inventory) = 'array' THEN pd.inventory ELSE '[]'::jsonb END) i
             WHERE i->>'produitMilitaire' = 'tente')::integer AS nb
      FROM (SELECT DISTINCT leader FROM eligible
             WHERE peut AND NOT a_la_caserne AND leader IS NOT NULL) l
      JOIN public.personnages_donnees pd ON pd.name = l.leader
  ),
  -- Ordre DETERMINISTE des beneficiaires quand la couverture est partielle : par matricule.
  -- Le resultat serveur est donc stable, et aucune interface de selection n'est necessaire.
  rang AS (
    SELECT pos, leader,
           row_number() OVER (PARTITION BY leader ORDER BY (sol->>'matricule'), pos) AS n
      FROM eligible
     WHERE peut AND NOT a_la_caserne AND leader IS NOT NULL
  ),
  final AS (
    SELECT e.sol, e.pos, e.pa,
           CASE
             WHEN NOT e.peut            THEN 'aucun'
             WHEN e.a_la_caserne        THEN 'caserne'
             WHEN r.n IS NOT NULL
              AND r.n <= coalesce(t.nb, 0) * c_capacite_tente THEN 'tente'
             ELSE 'terrain'
           END AS sort,
           (NOT e.peut AND e.est_pnj AND e.pa > 0 AND e.marqueur = v_jour) AS deja_repose
      FROM eligible e
      LEFT JOIN rang   r ON r.pos = e.pos
      LEFT JOIN tentes t ON t.leader = e.leader
  )
  SELECT coalesce(jsonb_agg(
           CASE f.sort
             WHEN 'caserne' THEN f.sol || jsonb_build_object('pa', c_pa_max, 'dernier_sommeil', v_jour)
             WHEN 'tente'   THEN f.sol || jsonb_build_object(
                                  'pa', least(c_pa_max, f.pa + c_gain_terrain + c_bonus_tente),
                                  'dernier_sommeil', v_jour)
             WHEN 'terrain' THEN f.sol || jsonb_build_object(
                                  'pa', least(c_pa_max, f.pa + c_gain_terrain),
                                  'dernier_sommeil', v_jour)
             ELSE f.sol
           END ORDER BY f.pos), '[]'::jsonb),
         count(*) FILTER (WHERE f.sort = 'caserne')::integer,
         count(*) FILTER (WHERE f.sort = 'tente')::integer,
         count(*) FILTER (WHERE f.sort = 'terrain')::integer,
         count(*) FILTER (WHERE f.deja_repose)::integer,
         count(*)::integer
    INTO v_sols, v_caserne, v_tente, v_terrain, v_deja, v_total
    FROM final f;

  IF coalesce(v_caserne,0) + coalesce(v_tente,0) + coalesce(v_terrain,0) = 0 THEN
    -- Rien a ecrire : on ne touche pas au blob pour un ordre sans effet.
    RETURN jsonb_build_object('ok', true, 'caserne', 0, 'tente', 0, 'terrain', 0,
      'deja_reposes', coalesce(v_deja,0), 'effectif', coalesce(v_total,0), 'reposes', 0);
  END IF;

  UPDATE public.compagnies_militaires
     SET data = public.militaire_sections_remplacer(g.o_data, p_section_id,
                  v_sec || jsonb_build_object('soldats', v_sols))
   WHERE id = p_compagnie_id;

  RETURN jsonb_build_object('ok', true,
    'caserne', v_caserne, 'tente', v_tente, 'terrain', v_terrain,
    'deja_reposes', v_deja, 'effectif', v_total,
    'reposes', v_caserne + v_tente + v_terrain);
END;
$function$;

-- PIEGE RECURRENT DU PROJET : une RPC non accordee repond 42501 « permission denied », pas un
-- refus metier, et le client affiche un motif incomprehensible. GRANT explicite, jamais a anon.
REVOKE ALL ON FUNCTION public.militaire_reposer_section(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.militaire_reposer_section(text, text) TO authenticated;
