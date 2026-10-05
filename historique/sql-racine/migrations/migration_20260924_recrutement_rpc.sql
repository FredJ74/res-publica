-- =============================================================================================
-- RECRUTEMENT MILITAIRE : LES RPC (24 septembre 2026)
-- =============================================================================================
-- Toutes SECURITY DEFINER, toutes bornees a `authenticated`. Le client ne transmet jamais son
-- pays ni son identite : mon_personnage() les deduit du jeton.
--
-- LA CAPACITE EST CALCULEE, JAMAIS STOCKEE. militaire_places_libres_grade() compte les places
-- REELLEMENT occupees dans le blob de la compagnie, puis retranche les places RESERVEES par une
-- acceptation encore valide. Une acceptation dont les 48 h sont passees cesse donc de reserver a
-- la seconde pres, sans attendre le cron : l'expiration est une PROPRIETE DU TEMPS, pas un etat
-- qu'il faut penser a mettre a jour.
-- =============================================================================================

-- ---------------------------------------------------------------------------------------------
-- Places libres pour un grade donne, dans une cible donnee (compagnie/section selon le grade).
-- Rend le nombre de places ; 0 signifie « ce recruteur ne peut pas prendre ce candidat ».
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_places_libres_grade(
  p_pays text, p_grade text, p_compagnie_id text, p_section_id text)
RETURNS integer
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE c_places constant integer := 24;
        v_occupe integer; v_reserve integer; v_sec jsonb;
BEGIN
  -- Places deja reservees par une acceptation VIVANTE (48 h non ecoulees, pas encore finalisee).
  SELECT count(*) INTO v_reserve FROM public.candidatures_militaires cm
   WHERE cm.statut = 'acceptee' AND cm.echeance > now()
     AND cm.pays = p_pays AND cm.grade_vise = p_grade
     AND cm.compagnie_id IS NOT DISTINCT FROM p_compagnie_id
     AND cm.section_id IS NOT DISTINCT FROM p_section_id;

  IF p_grade = 'capitaine' THEN
    -- Une compagnie sans Capitaine offre une place, et une seule.
    SELECT count(*) INTO v_occupe FROM public.compagnies_militaires c
     WHERE c.id = p_compagnie_id AND coalesce(c.data->>'capitaineNom','') <> '';
    RETURN greatest(0, 1 - v_occupe - v_reserve);

  ELSIF p_grade = 'lieutenant' THEN
    -- Une section sans Lieutenant offre une place, et une seule.
    SELECT s INTO v_sec FROM public.compagnies_militaires c,
           jsonb_array_elements(c.data->'sections') s
     WHERE c.id = p_compagnie_id AND s->>'id' = p_section_id;
    IF v_sec IS NULL THEN RETURN 0; END IF;
    v_occupe := CASE WHEN coalesce(v_sec->>'lieutenantNom','') <> '' THEN 1 ELSE 0 END;
    RETURN greatest(0, 1 - v_occupe - v_reserve);

  ELSIF p_grade = 'soldat' THEN
    -- Vingt-quatre places par section -- mais seuls les JOUEURS les bloquent reellement. Un PNJ
    -- n'occupe pas une place, il la garde au chaud : la filiere existante evince le premier PNJ
    -- venu et le renvoie INTACT en reserve (matricule et entrainement compris) pour faire entrer
    -- un joueur. Compter les PNJ comme des places prises fermerait une section pleine de PNJ a
    -- tout engagement, ce qui serait une regression franche du comportement actuel.
    SELECT s INTO v_sec FROM public.compagnies_militaires c,
           jsonb_array_elements(c.data->'sections') s
     WHERE c.id = p_compagnie_id AND s->>'id' = p_section_id;
    IF v_sec IS NULL THEN RETURN 0; END IF;
    SELECT count(*) INTO v_occupe
      FROM jsonb_array_elements(coalesce(v_sec->'soldats','[]'::jsonb)) s
     WHERE coalesce((s->>'pj')::boolean, false);
    RETURN greatest(0, c_places - v_occupe - v_reserve);
  END IF;
  RETURN 0;
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- DEPOSER UNE CANDIDATURE — 2 PA, a la caserne, un grade a la fois.
-- L'ordre des controles n'est pas decoratif : TOUT est verifie avant le moindre debit. Un refus
-- ne coute donc jamais un PA, conformement a l'exigence.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_candidature_deposer(p_grade text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_pays text; v_bat text; v_grade_actuel text; v_id text; v_paie jsonb;
BEGIN
  -- Le grade de Commandant ne se candidate PAS ici : il passe par l'ordre `postuler` du Palais.
  IF p_grade NOT IN ('capitaine','lieutenant','soldat') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'grade_invalide');
  END IF;
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(country,'republic'), coalesce(current_building,'')
    INTO v_pays, v_bat FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF v_pays IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  -- ON S'ENGAGE AU CORPS DE GARDE, PAS DEPUIS SON SALON. C'est le BATIMENT qui compte.
  IF v_bat <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- DEJA MILITAIRE : on ne candidate pas. Ce n'est pas une regle nouvelle -- c'est exactement ce
  -- que refusait deja militaire_candidater_soldat (deja_officier / deja_soldat). La promotion
  -- interne n'existe pas dans ce jeu, et ce chantier ne la cree pas.
  v_grade_actuel := public.militaire_grade_effectif(v_moi);
  IF v_grade_actuel IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_militaire', 'grade', v_grade_actuel);
  END IF;

  -- Une candidature vivante suffit par grade. L'index unique le garantit de toute facon ; ce test
  -- n'est la que pour rendre un refus propre plutot qu'une violation de contrainte.
  IF EXISTS (SELECT 1 FROM public.candidatures_militaires
              WHERE candidat = v_moi AND grade_vise = p_grade AND statut IN ('active','acceptee')) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_deja_active', 'grade', p_grade);
  END IF;

  -- PAIEMENT EN DERNIER, ET PAR L'AUTORITE HABITUELLE. payer_ordre relit les PA sur la fiche,
  -- verifie que 2 PA est bien un cout declare pour cet ordre, et debite sous verrou.
  v_paie := public.payer_ordre(v_moi, 's_engager_armee', 2, 0);
  IF coalesce((v_paie->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_paie->>'raison','paiement_refuse'));
  END IF;

  v_id := 'cand-' || (extract(epoch from clock_timestamp())*1000)::bigint || '-' || substr(md5(random()::text), 1, 6);
  INSERT INTO public.candidatures_militaires (id, pays, candidat, grade_vise, derniere_relance)
  VALUES (v_id, v_pays, v_moi, p_grade, now());

  -- `->` et non `->>` : le client recopie ces PA dans state.pa sans les reinterpreter, et une
  -- chaine de caracteres y ferait un affichage faux au lieu d'un nombre.
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'grade', p_grade,
                            'pa', v_paie->'pa', 'pa_preleves', 2);
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- MES CANDIDATURES — ce que le candidat voit. Jamais les refus : c'est tout l'objet de la regle.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_mes_candidatures()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_liste jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', cm.id, 'grade', cm.grade_vise, 'statut', cm.statut,
           'depuis', cm.cree_le,
           -- On ne revele NI qui a accepte, NI ou : le courrier reste neutre et la decouverte
           -- se fait a la caserne. Seule l'echeance est utile au joueur.
           'echeance', CASE WHEN cm.statut = 'acceptee' THEN cm.echeance END)
           ORDER BY cm.cree_le), '[]'::jsonb)
    INTO v_liste
    FROM public.candidatures_militaires cm
   WHERE cm.candidat = v_moi AND cm.statut IN ('active','acceptee');

  RETURN jsonb_build_object('ok', true, 'candidatures', v_liste,
    'affectation_a_decouvrir', EXISTS (SELECT 1 FROM public.candidatures_militaires
       WHERE candidat = v_moi AND statut = 'acceptee' AND echeance > now()));
END;
$function$;

-- ---------------------------------------------------------------------------------------------
-- RETIRER UNE CANDIDATURE — definitif, sans remboursement.
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.militaire_candidature_retirer(p_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE v_moi text; v_statut text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT statut INTO v_statut FROM public.candidatures_militaires
   WHERE id = p_id AND candidat = v_moi FOR UPDATE;
  IF v_statut IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'candidature_introuvable'); END IF;
  IF v_statut <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'candidature_non_retirable', 'statut', v_statut);
  END IF;

  UPDATE public.candidatures_militaires SET statut = 'retiree' WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'id', p_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.militaire_places_libres_grade(text,text,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_candidature_deposer(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_mes_candidatures() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.militaire_candidature_retirer(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.militaire_places_libres_grade(text,text,text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_candidature_deposer(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_mes_candidatures() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.militaire_candidature_retirer(text) TO authenticated, service_role;
