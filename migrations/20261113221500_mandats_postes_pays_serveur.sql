-- Séparation des mandats : le poste seul ne suffit pas.
-- Un titulaire peut voyager, mais il ne devient pas membre du gouvernement étranger.
-- Les fonctions communes (caserne, nominations, postes locaux) utilisent ce contrôle.
CREATE OR REPLACE FUNCTION public.exiger_poste(p_poste text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $fn$
DECLARE
  v_nom text;
  v_poste text;
  v_pays_present text;
  v_pays_mandat text;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NULL; END IF;
  SELECT p.name,p.poste->>'id',p.country
    INTO v_nom,v_poste,v_pays_present
    FROM public.personnages_donnees p
    WHERE p.user_id=auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN
    RAISE EXCEPTION 'acteur_non_authentifie: aucun personnage rattache a ce compte'
      USING ERRCODE='42501';
  END IF;
  IF v_poste IS DISTINCT FROM p_poste THEN
    RAISE EXCEPTION 'autorite_insuffisante: poste % requis, poste reel %',
      p_poste,coalesce(v_poste,'(aucun)') USING ERRCODE='42501';
  END IF;
  SELECT a.pays INTO v_pays_mandat
    FROM public.acteur_poste_courant() a
    WHERE a.nom=v_nom AND a.poste_id=p_poste;
  IF v_pays_mandat IS NULL OR v_pays_mandat IS DISTINCT FROM v_pays_present THEN
    RAISE EXCEPTION 'mandat_autre_pays: fonction % valable uniquement dans son empire',
      p_poste USING ERRCODE='42501';
  END IF;
  RETURN v_nom;
END $fn$;

-- Autorité de nomination et révocation : ne pas prendre le lieu de voyage
-- pour le pays du mandat. Ces fonctions dérivent leur pays de poste_autorite_de.
CREATE OR REPLACE FUNCTION public.poste_autorite_de(p_poste text,p_city text)
RETURNS TABLE(nom text,pays text,autorite text,scope text)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $fn$
DECLARE
  v_nom text;
  v_pays text;
  v_pays_mandat text;
  v_poste jsonb;
  v_regle record;
BEGIN
  SELECT d.name,d.country,d.poste
    INTO v_nom,v_pays,v_poste FROM public.personnages_donnees d
    WHERE d.user_id=auth.uid() LIMIT 1;
  IF v_nom IS NULL THEN RETURN; END IF;

  SELECT * INTO v_regle FROM public.postes_nommes_regles r
    WHERE r.poste_id=p_poste;
  IF NOT FOUND OR v_regle.nomme_par IS NULL THEN RETURN; END IF;
  IF (v_poste->>'id') IS DISTINCT FROM v_regle.nomme_par THEN RETURN; END IF;

  SELECT a.pays INTO v_pays_mandat
    FROM public.acteur_poste_courant() a
    WHERE a.nom=v_nom AND a.poste_id=v_regle.nomme_par;
  IF v_pays_mandat IS NULL OR v_pays_mandat IS DISTINCT FROM v_pays THEN
    RETURN;
  END IF;

  IF coalesce(v_regle.autorite_scope,v_regle.scope)='ville'
    AND (v_poste->>'city') IS DISTINCT FROM p_city THEN
    RETURN;
  END IF;
  RETURN QUERY SELECT v_nom,v_pays,v_regle.nomme_par,v_regle.scope;
END $fn$;
