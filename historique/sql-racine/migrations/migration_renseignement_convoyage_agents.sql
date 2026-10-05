-- =====================================================================
-- CHAINE DU RENSEIGNEMENT : LE CONVOYAGE DES AGENTS (21 septembre 2026)
-- Appliquee sous le nom : renseignement_convoyage_agents
-- =====================================================================
-- CE QUI ETAIT CASSE. cellule_renseignement_creer insere les quatre agents avec
-- ville/building_id/room_id a NULL -- c'est l'etat NON DEPLOYE, que le reste du
-- systeme connait deja : le panneau du ministre l'affiche (« non deploye »), la
-- collecte l'exclut (ville IS NOT NULL) et les observateurs le refusent
-- (agent_non_pose). Un seul maillon l'ignorait : agent_prendre, qui exigeait une
-- co-presence EXACTE avec une position NULL. `IS DISTINCT FROM` face a NULL etant
-- vrai, l'agent ne pouvait JAMAIS etre pris, donc jamais pose, donc jamais
-- collecte, donc jamais arrete. Toute la chaine etait morte derriere ce refus.
--
-- LE CHOIX : ON CORRIGE LA GARDE, PAS L'ETAT INITIAL. Trois etats existent deja
-- dans l'architecture -- non deploye (leader NULL + ville NULL), convoye (leader
-- non NULL), pose (ville non NULL) -- et trois lecteurs les distinguent
-- explicitement. Donner une position de depart aux agents a la creation aurait
-- supprime un etat que le client sait nommer, et aurait surtout livre a la
-- collecte des agents poses dans leur PROPRE empire : les observateurs lisent la
-- position d'un agent avec pays_couverture comme pays implicite, ils auraient
-- produit du renseignement geographiquement faux.
--
-- OU PREND-ON UN AGENT NON DEPLOYE ? Dans l'empire proprietaire, ou il attend.
-- Le controle existait deja sous le nom `pas_mon_empire` (personnages_donnees.
-- country designe le pays OU L'ON SE TROUVE : il suit le joueur en voyage,
-- cf. plateau-navigation.js executerVoyage). Il suffit desormais a lui seul pour
-- l'agent non deploye : on le prend chez soi, on le convoie, on le depose.
-- =====================================================================
CREATE OR REPLACE FUNCTION public.agent_prendre(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT ag.*, c.pays_proprietaire, c.ministre, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.statut_cellule <> 'active' THEN RETURN jsonb_build_object('ok', false, 'raison', 'cellule_inactive'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;
  IF a.leader_courant IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_en_groupe', 'leader', a.leader_courant); END IF;

  IF a.ville IS NULL THEN
    -- AGENT NON DEPLOYE. Il n'a pas de position a laquelle se rendre : il attend
    -- dans l'empire qui l'a recrute. Tout compatriote PRESENT dans cet empire
    -- peut donc s'en charger -- c'est le convoi annonce par l'interface.
    IF d.country IS DISTINCT FROM a.pays_proprietaire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_empire');
    END IF;
  ELSE
    -- AGENT POSE. Il faut etre PHYSIQUEMENT la ou il se trouve pour le reprendre,
    -- et l'autorite ne peut plus etre `country` : un agent pose l'est par
    -- construction dans le pays CIBLE, ou tout repreneur a `country` = cible.
    -- C'est donc le ministre proprietaire de la cellule qui le reprend, ou un
    -- compatriote si l'agent a ete pose dans l'empire proprietaire lui-meme.
    IF d.current_building IS NULL OR d.current_room IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;
    IF d.current_city IS DISTINCT FROM a.ville
       OR d.current_building IS DISTINCT FROM a.building_id
       OR d.current_room IS DISTINCT FROM a.room_id THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
    IF d.country IS DISTINCT FROM a.pays_proprietaire AND v_moi IS DISTINCT FROM a.ministre THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_empire');
    END IF;
  END IF;

  UPDATE public.agents_renseignement
     SET leader_courant = v_moi, ville = NULL, building_id = NULL, room_id = NULL, maj_le = now()
   WHERE id = p_agent_id;
  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id, 'leader', v_moi);
END;
$function$;

-- ---------------------------------------------------------------------
-- LE DEPOT SE FAIT DANS LE PAYS DE COUVERTURE, ET NULLE PART AILLEURS.
-- Ce n'est pas une regle nouvelle, c'est celle que TOUT LE RESTE suppose deja :
-- agents_renseignement_ici ne montre un agent pose qu'aux joueurs dont le pays
-- vaut pays_couverture, et les observateurs calculent la distance en prenant
-- pays_couverture pour pays de l'agent. Un agent depose dans son propre empire
-- aurait donc collecte du renseignement tout en etant invisible au
-- contre-espionnage qui l'entoure : aucune arrestation possible, aucun risque.
-- La garde ferme cette anomalie avant qu'elle ne devienne atteignable.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.agent_deposer(p_agent_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; d record; a record;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT country, current_city, current_building, current_room INTO d
    FROM public.personnages_donnees WHERE name = v_moi;
  IF d.current_building IS NULL OR d.current_room IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'position_indefinie'); END IF;

  SELECT ag.*, c.statut AS statut_cellule INTO a
    FROM public.agents_renseignement ag
    JOIN public.cellules_renseignement c ON c.id = ag.cellule_id
   WHERE ag.id = p_agent_id FOR UPDATE;
  IF a.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'agent_introuvable'); END IF;
  IF a.leader_courant IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_agent'); END IF;
  IF a.statut <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'agent_indisponible', 'statut', a.statut); END IF;
  IF d.country IS DISTINCT FROM a.pays_couverture THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_dans_le_pays_de_couverture',
      'attendu', a.pays_couverture); END IF;

  -- Depose a la position REELLE du chef. Il y reste, immobile, jusqu'a ce qu'un
  -- PJ vienne le reprendre.
  UPDATE public.agents_renseignement
     SET leader_courant = NULL, ville = d.current_city,
         building_id = d.current_building, room_id = d.current_room, maj_le = now()
   WHERE id = p_agent_id;
  RETURN jsonb_build_object('ok', true, 'agent', p_agent_id,
    'ville', d.current_city, 'batiment', d.current_building, 'piece', d.current_room);
END;
$function$;

-- DOCTRINE DES DROITS : les DEFAULT PRIVILEGES du schema public reaccordent
-- EXECUTE a anon a chaque CREATE. On revoque, puis on accorde nommement.
REVOKE ALL ON FUNCTION public.agent_prendre(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.agent_deposer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.agent_prendre(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.agent_deposer(text) TO authenticated, service_role;
