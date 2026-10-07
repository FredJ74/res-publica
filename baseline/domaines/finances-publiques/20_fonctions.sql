-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine finances publiques -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- alimenter_caisse_fonds(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.alimenter_caisse_fonds(p_acteur text, p_fonds_id text, p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data    jsonb;
  v_m       integer := coalesce(p_montant, 0);
  v_proprio text;
  v_liquide numeric;
  v_caisse  numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_acteur,'') = '' OR coalesce(p_fonds_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_m <= 0 OR v_m IS DISTINCT FROM p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  v_proprio := v_data->>'proprietaire';
  IF v_proprio IS DISTINCT FROM p_acteur AND v_proprio IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  IF left(coalesce(v_proprio,''), 5) = 'orga:' THEN
    IF NOT public.mouvement_titulaire(v_proprio, -v_m) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants'); END IF;
  ELSE
    SELECT coalesce(liquide, 0) INTO v_liquide
      FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
    IF v_liquide IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent'); END IF;
    IF v_liquide < v_m THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'liquide_insuffisant',
                                'liquide', v_liquide); END IF;
    UPDATE public.personnages_donnees
       SET arg     = coalesce(arg, 0)     - v_m,
           liquide = coalesce(liquide, 0) - v_m,
           updated_at = now()
     WHERE name = p_acteur;
  END IF;

  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_m)),
         updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', v_caisse + v_m);
END; $function$;

-- appliquer_taxe_transaction(text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.appliquer_taxe_transaction(p_pays text, p_ville text, p_montant_brut numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cle_muni text := p_pays || '_' || p_ville;
  v_muni jsonb; v_nat jsonb; v_tl numeric; v_tn numeric;
  v_taxe_l numeric; v_taxe_n numeric;
BEGIN
  SELECT data INTO v_muni FROM public.budgets_municipaux WHERE id = v_cle_muni FOR UPDATE;
  SELECT data INTO v_nat FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  v_tl := coalesce((v_muni->>'tauxLocal')::numeric, 2);
  v_tn := coalesce((v_nat->>'tauxNational')::numeric, 2);
  v_taxe_l := round(p_montant_brut * v_tl / 100);
  v_taxe_n := round(p_montant_brut * v_tn / 100);

  IF v_muni IS NOT NULL THEN
    UPDATE public.budgets_municipaux
       SET data = jsonb_set(v_muni, '{caisse}', to_jsonb(coalesce((v_muni->>'caisse')::numeric,0) + v_taxe_l)),
           updated_at = now()
     WHERE id = v_cle_muni;
  END IF;
  IF v_nat IS NOT NULL THEN
    UPDATE public.budgets_nationaux
       SET data = jsonb_set(v_nat, '{reserveJour}', to_jsonb(coalesce((v_nat->>'reserveJour')::numeric,0) + v_taxe_n)),
           updated_at = now()
     WHERE id = p_pays;
  END IF;

  RETURN jsonb_build_object('net', p_montant_brut - v_taxe_l - v_taxe_n,
    'taxeLocale', v_taxe_l, 'taxeNationale', v_taxe_n, 'tauxLocal', v_tl, 'tauxNational', v_tn);
END; $function$;

-- budget_national_epingler() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.budget_national_epingler()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste      text;
  r            record;
  v_parent     text;
  v_old_parent jsonb;
  v_new_parent jsonb;
  v_ouverture  boolean;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF OLD.data IS NULL OR NEW.data IS NULL THEN RETURN NEW; END IF;

  SELECT (d.poste ->> 'id') INTO v_poste
    FROM public.personnages_donnees d WHERE d.user_id = auth.uid() LIMIT 1;

  -- Les deux marqueurs de journee ne sont plus ecrits que par le cron : les
  -- quatre passes clientes qui les partageaient ont ete retirees le
  -- 20 septembre. Aucun client n'a de raison legitime d'y toucher.
  IF (NEW.data -> 'derniereDistribJour') IS DISTINCT FROM (OLD.data -> 'derniereDistribJour') THEN
    NEW.data := NEW.data || jsonb_build_object('derniereDistribJour', OLD.data -> 'derniereDistribJour');
  END IF;
  IF (NEW.data -> 'dernierVirementCaserneJour') IS DISTINCT FROM (OLD.data -> 'dernierVirementCaserneJour') THEN
    NEW.data := NEW.data || jsonb_build_object('dernierVirementCaserneJour', OLD.data -> 'dernierVirementCaserneJour');
  END IF;

  -- 1. CHAMPS GOUVERNES ENTIEREMENT PAR UN SEUL POSTE (comportement d'origine).
  FOR r IN SELECT * FROM public.budget_national_champs_regles WHERE sous_champ IS NULL LOOP
    IF (NEW.data -> r.champ) IS DISTINCT FROM (OLD.data -> r.champ)
       AND coalesce(v_poste, '') <> r.poste_id THEN
      IF (OLD.data ? r.champ) THEN
        NEW.data := jsonb_set(NEW.data, ARRAY[r.champ], OLD.data -> r.champ);
      ELSE
        NEW.data := NEW.data - r.champ;
      END IF;
    END IF;
  END LOOP;

  -- 2. CHAMPS COMPOSITES : l'autorite descend au SOUS-CHAMP.
  FOR v_parent IN
    SELECT DISTINCT champ FROM public.budget_national_champs_regles WHERE sous_champ IS NOT NULL
  LOOP
    v_old_parent := OLD.data -> v_parent;
    v_new_parent := NEW.data -> v_parent;

    -- L'objet ne se supprime pas et ne se denature pas : « on CLOT, on n'efface pas »
    -- (plateau-gouvernement.js:956). Seul le serveur pourrait le retirer.
    IF v_old_parent IS NOT NULL AND jsonb_typeof(v_old_parent) = 'object'
       AND (v_new_parent IS NULL OR jsonb_typeof(v_new_parent) <> 'object') THEN
      v_new_parent := v_old_parent;
    END IF;
    IF v_new_parent IS NULL OR jsonb_typeof(v_new_parent) <> 'object' THEN CONTINUE; END IF;
    IF v_old_parent IS NULL OR jsonb_typeof(v_old_parent) <> 'object' THEN
      v_old_parent := '{}'::jsonb;
    END IF;

    FOR r IN SELECT * FROM public.budget_national_champs_regles
              WHERE champ = v_parent AND sous_champ IS NOT NULL LOOP
      IF (v_new_parent -> r.sous_champ) IS DISTINCT FROM (v_old_parent -> r.sous_champ)
         AND coalesce(v_poste, '') <> r.poste_id THEN
        IF (v_old_parent ? r.sous_champ) THEN
          v_new_parent := jsonb_set(v_new_parent, ARRAY[r.sous_champ], v_old_parent -> r.sous_champ);
        ELSE
          v_new_parent := v_new_parent - r.sous_champ;
        END IF;
      END IF;
    END LOOP;

    -- L'OUVERTURE est constatee APRES l'arbitrage d'autorite : qui n'a pas pu poser
    -- actif=true n'a rien ouvert, et n'obtient donc pas les reglages d'ouverture.
    v_ouverture := coalesce(v_old_parent ->> 'actif', '') <> 'true'
               AND coalesce(v_new_parent ->> 'actif', '') = 'true';

    -- Un objet cree de toutes pieces sans ouverture legitime ne laisse aucun residu.
    IF NOT (OLD.data ? v_parent) AND NOT v_ouverture THEN
      NEW.data := NEW.data - v_parent;
      CONTINUE;
    END IF;

    -- Le declencheur ne choisit pas les reglages operationnels : le serveur les pose.
    IF v_ouverture THEN
      FOR r IN SELECT * FROM public.budget_national_champs_regles
                WHERE champ = v_parent AND sous_champ IS NOT NULL
                  AND valeur_ouverture IS NOT NULL LOOP
        v_new_parent := jsonb_set(v_new_parent, ARRAY[r.sous_champ], r.valeur_ouverture);
      END LOOP;
    END IF;

    NEW.data := jsonb_set(NEW.data, ARRAY[v_parent], v_new_parent);
  END LOOP;

  RETURN NEW;
END;
$function$;

-- budgets_armurerie_verrou() -> trigger | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.budgets_armurerie_verrou()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF COALESCE(current_setting('rp.armurerie_militaire', true), '') = '1' THEN RETURN NEW; END IF;

  IF (NEW.data -> 'stockArmurerieMilitaire') IS DISTINCT FROM (OLD.data -> 'stockArmurerieMilitaire') THEN
    NEW.data := CASE WHEN (OLD.data -> 'stockArmurerieMilitaire') IS NULL
                     THEN NEW.data - 'stockArmurerieMilitaire'
                     ELSE jsonb_set(NEW.data, '{stockArmurerieMilitaire}', OLD.data -> 'stockArmurerieMilitaire') END;
  END IF;
  IF (NEW.data -> 'lotsMilitaires') IS DISTINCT FROM (OLD.data -> 'lotsMilitaires') THEN
    NEW.data := CASE WHEN (OLD.data -> 'lotsMilitaires') IS NULL
                     THEN NEW.data - 'lotsMilitaires'
                     ELSE jsonb_set(NEW.data, '{lotsMilitaires}', OLD.data -> 'lotsMilitaires') END;
  END IF;
  RETURN NEW;
END; $function$;

-- budgets_virement_caserne_verrou() -> trigger | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.budgets_virement_caserne_verrou()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF coalesce(current_setting('rp.virement_caserne', true), '') = '1' THEN RETURN NEW; END IF;

  -- Toute autre tentative de modifier CETTE sous-cle est annulee silencieusement : la valeur
  -- precedente est restauree. Le reste de l'ecriture passe normalement -- on ne casse pas les
  -- producteurs legitimes qui reecrivent le blob sans toucher a ce champ.
  IF (NEW.data -> 'virementJournalierCaserne') IS DISTINCT FROM (OLD.data -> 'virementJournalierCaserne') THEN
    NEW.data := CASE WHEN (OLD.data -> 'virementJournalierCaserne') IS NULL
                     THEN NEW.data - 'virementJournalierCaserne'
                     ELSE jsonb_set(NEW.data, '{virementJournalierCaserne}',
                                    OLD.data -> 'virementJournalierCaserne') END;
  END IF;
  RETURN NEW;
END;
$function$;

-- caisse_client_mouvement(text,numeric,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.caisse_client_mouvement(p_caisse text, p_delta numeric, p_motif text DEFAULT NULL::text, p_plafonne boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_existe boolean; v_solde numeric; v_verse numeric;
  v_res jsonb; v_raison text; v_postes text[];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  IF coalesce(btrim(p_caisse),'') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF v_pays IS NULL OR p_caisse NOT LIKE v_pays || '\_%' THEN
    v_raison := 'caisse_hors_pays';
  ELSE
    SELECT true, (data->>'solde')::numeric INTO v_existe, v_solde
      FROM public.caisses_batiments WHERE id = p_caisse;
    IF NOT coalesce(v_existe, false) THEN
      v_raison := 'caisse_inexistante';
    ELSIF p_delta < 0 OR p_plafonne THEN
      -- SORTIE D'ARGENT PUBLIC : autorite exigee.
      v_postes := public.caisse_postes_requis(p_caisse, v_pays);
      IF v_postes IS NOT NULL THEN
        IF array_length(v_postes, 1) IS NULL THEN
          v_raison := 'caisse_reservee_au_serveur';
        ELSIF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                           WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays) THEN
          v_raison := 'autorite_insuffisante';
        END IF;
      END IF;
    END IF;
  END IF;

  IF v_raison IS NOT NULL THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, p_delta, p_motif, false, v_raison);
    RETURN jsonb_build_object('ok', false, 'raison', v_raison);
  END IF;

  IF p_plafonne THEN
    v_verse := least(greatest(coalesce(v_solde,0), 0), abs(p_delta));
    IF v_verse <= 0 THEN
      INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
      VALUES (v_moi, p_caisse, p_delta, p_motif, false, 'solde_nul');
      RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', coalesce(v_solde,0));
    END IF;
    v_res := public.caisse_institution_mouvement(p_caisse, -v_verse, true);
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_caisse, -v_verse, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
    IF coalesce((v_res->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', true, 'verse', v_verse,
        'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', v_res->>'raison', 'verse', 0);
  END IF;

  v_res := public.caisse_institution_mouvement(p_caisse, p_delta, true);
  INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
  VALUES (v_moi, p_caisse, p_delta, p_motif, coalesce((v_res->>'ok')::boolean,false), v_res->>'raison');
  IF coalesce((v_res->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', true,
      'solde', (SELECT (data->>'solde')::numeric FROM public.caisses_batiments WHERE id = p_caisse));
  END IF;
  RETURN v_res;
END;
$function$;

-- caisse_commissariat_lire(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.caisse_commissariat_lire(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_nom text; v_poste text; v_poste_city text; v_pays text;
  v_solde numeric; v_autorise boolean := false;
BEGIN
  IF p_id IS NULL OR p_id NOT LIKE '%commissariat%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_perimetre');
  END IF;

  SELECT a.nom, a.poste_id, a.poste_city, a.pays
    INTO v_nom, v_poste, v_poste_city, v_pays
    FROM public.acteur_poste_courant() a;
  IF v_nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  -- La caisse doit appartenir a l'empire de l'acteur : l'identifiant commence par son pays.
  IF p_id NOT LIKE v_pays || '\_%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;

  IF v_poste IN ('president', 'min_int') THEN
    v_autorise := true;
  ELSIF v_poste IN ('commissaire', 'maire', 'maire_adjoint') AND v_poste_city IS NOT NULL THEN
    -- La caisse d'une ville porte son nom : republic_commissariat_capitale.
    v_autorise := (p_id LIKE '%\_' || v_poste_city);
  END IF;

  IF NOT v_autorise THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  SELECT CASE WHEN jsonb_typeof(c.data -> 'solde') = 'number'
              THEN (c.data ->> 'solde')::numeric ELSE 0 END
    INTO v_solde FROM public.caisses_batiments c WHERE c.id = p_id;

  RETURN jsonb_build_object('ok', true, 'solde', coalesce(v_solde, 0));
END;
$function$;

-- caisse_institution_mouvement(text,numeric,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement(p_id text, p_delta numeric, p_exiger_existant boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data jsonb; v_solde numeric; v_existe boolean;
  v_moi text; v_pays text; v_postes text[]; v_client boolean;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_delta IS NULL OR p_delta = 0
     OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_client := coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
              AND NOT public.est_appel_serveur();

  IF p_delta < 0 AND v_client THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_postes := public.caisse_postes_requis(p_id, v_pays);
    IF v_postes IS NOT NULL THEN
      IF array_length(v_postes, 1) IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_reservee_au_serveur');
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                      WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays) THEN
        INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
        VALUES (v_moi, p_id, p_delta, 'primitive_heritee', false, 'autorite_insuffisante');
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  v_existe := FOUND;
  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF v_solde + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant');
  END IF;

  IF v_existe THEN
    UPDATE public.caisses_batiments
       SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde + p_delta),
           updated_at = now()
     WHERE id = p_id;
  ELSE
    IF v_client THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_inexistante');
    END IF;
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (p_id, jsonb_build_object('solde', v_solde + p_delta), now());
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- caisse_institution_mouvement_plafonne(text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.caisse_institution_mouvement_plafonne(p_id text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_solde numeric; v_verse numeric;
        v_moi text; v_pays text; v_postes text[]; v_ville text;
BEGIN
  IF COALESCE(btrim(p_id), '') = '' OR p_montant IS NULL OR p_montant <= 0
     OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF coalesce(current_setting('rp.caisse_interne', true), '') <> 'on'
     AND NOT public.est_appel_serveur() THEN
    v_moi := public.mon_personnage();
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
    IF v_pays IS NULL OR p_id NOT LIKE v_pays || '\_%' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays');
    END IF;
    v_postes := public.caisse_postes_requis(p_id, v_pays);
    v_ville  := public.caisse_ville_de(p_id, v_pays);
    IF v_postes IS NOT NULL THEN
      IF array_length(v_postes, 1) IS NULL
         OR NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                         WHERE a.poste_id = ANY (v_postes) AND a.pays = v_pays
                           -- LA VILLE : un poste national passe, un poste de ville doit etre
                           -- celui de CETTE ville.
                           AND (v_ville IS NULL OR a.poste_city IS NULL
                                OR a.poste_city = v_ville)) THEN
        INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
        VALUES (v_moi, p_id, -p_montant, 'primitive_heritee_plafonnee', false,
                CASE WHEN v_ville IS NULL THEN 'autorite_insuffisante'
                     ELSE 'autorite_insuffisante_hors_ville' END);
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante', 'verse', 0);
      END IF;
    END IF;
  END IF;

  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number'
                  THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'solde', v_solde);
  END IF;
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'solde', v_solde - v_verse);
END; $function$;

-- caisse_ministere_mouvement(text,numeric,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.caisse_ministere_mouvement(p_source_id text, p_montant numeric, p_destination_id text DEFAULT NULL::text, p_plafonne boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pays text; v_poste text; v_acteur text; v_pays_acteur text;
  v_data jsonb; v_solde numeric; v_verse numeric;
  v_dest_data jsonb; v_dest_solde numeric;
BEGIN
  IF COALESCE(btrim(p_source_id), '') = '' OR p_montant IS NULL
     OR p_montant <= 0 OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  -- La source DOIT etre une caisse ministerielle : cette RPC ne sert qu'a celles-la.
  v_pays  := substring(p_source_id from '^([^_]+)_gouvernement-');
  v_poste := substring(p_source_id from '^[^_]+_gouvernement-(.+)$');
  IF v_pays IS NULL OR v_poste IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_non_ministerielle');
  END IF;

  -- AUTORITE : leve si le compte connecte n'occupe pas CE ministere.
  v_acteur := public.exiger_poste(v_poste);
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT country INTO v_pays_acteur FROM public.personnages_donnees WHERE name = v_acteur;
  IF v_pays_acteur IS DISTINCT FROM v_pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction',
                              'pays_caisse', v_pays, 'pays_acteur', v_pays_acteur);
  END IF;

  -- Verrous dans un ordre fixe (source puis destination) : deux virements simultanes se serialisent.
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = p_source_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data->'solde') = 'number'
                  THEN (v_data->>'solde')::numeric ELSE 0 END;

  IF p_plafonne THEN
    v_verse := LEAST(GREATEST(v_solde, 0), p_montant);
  ELSE
    IF v_solde < p_montant THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', v_solde);
    END IF;
    v_verse := p_montant;
  END IF;
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', v_solde, 'verse', 0);
  END IF;

  UPDATE public.caisses_batiments
     SET data = COALESCE(v_data,'{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = p_source_id;

  -- Credit de la destination DANS LA MEME TRANSACTION : l'argent ne peut plus se perdre entre
  -- les deux mouvements, ce que deux appels HTTP separes ne garantissaient pas.
  IF COALESCE(btrim(p_destination_id), '') <> '' THEN
    SELECT data INTO v_dest_data FROM public.caisses_batiments WHERE id = p_destination_id FOR UPDATE;
    v_dest_solde := CASE WHEN FOUND AND jsonb_typeof(v_dest_data->'solde') = 'number'
                         THEN (v_dest_data->>'solde')::numeric ELSE 0 END;
    IF FOUND THEN
      UPDATE public.caisses_batiments
         SET data = COALESCE(v_dest_data,'{}'::jsonb) || jsonb_build_object('solde', v_dest_solde + v_verse),
             updated_at = now()
       WHERE id = p_destination_id;
    ELSE
      INSERT INTO public.caisses_batiments (id, data, updated_at)
      VALUES (p_destination_id, jsonb_build_object('solde', v_verse), now());
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'acteur', v_acteur,
    'poste', v_poste, 'source', p_source_id, 'destination', p_destination_id,
    'solde_source', v_solde - v_verse);
END;
$function$;

-- caisse_postes_requis(text,text) -> text[] | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.caisse_postes_requis(p_caisse text, p_pays text)
 RETURNS text[]
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_suffixe text; r record; v_poste text;
BEGIN
  v_suffixe := regexp_replace(p_caisse, '^' || p_pays || '_', '');

  -- Ministere : le poste EST dans l'identifiant, comme le fait deja
  -- caisse_ministere_mouvement.
  v_poste := substring(v_suffixe from '^gouvernement-(.+)$');
  IF v_poste IS NOT NULL THEN RETURN ARRAY[v_poste]; END IF;

  SELECT * INTO r FROM public.caisses_autorites c
   WHERE (NOT c.est_prefixe AND c.motif = v_suffixe)
      OR (c.est_prefixe AND v_suffixe LIKE c.motif || '%')
   ORDER BY c.est_prefixe LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN r.postes_debit;
END;
$function$;

-- caisse_ville_de(text,text) -> text | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.caisse_ville_de(p_caisse text, p_pays text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE v_suffixe text; r record;
BEGIN
  v_suffixe := regexp_replace(p_caisse, '^' || p_pays || '_', '');
  IF v_suffixe LIKE 'gouvernement-%' THEN RETURN NULL; END IF;   -- ministere : national
  SELECT * INTO r FROM public.caisses_autorites c
   WHERE c.est_prefixe AND v_suffixe LIKE c.motif || '\_%'
   ORDER BY length(c.motif) DESC LIMIT 1;
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN substring(v_suffixe from '^' || r.motif || '_(.+)$');
END; $function$;

-- debiter_fonds_ordinaires(text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.debiter_fonds_ordinaires(p_acteur text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ok boolean; v_liq_avant numeric; v_nat_avant numeric;
  v_pris_liq numeric; v_pris_nat numeric; v_debit uuid;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'montant', 0);
  END IF;
  IF p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  SELECT coalesce(liquide, 0) INTO v_liq_avant
    FROM public.personnages_donnees WHERE name = p_acteur;
  SELECT coalesce(solde, 0) INTO v_nat_avant FROM public.comptes_bancaires
   WHERE personnage = p_acteur AND banque = 'nationale';

  v_ok := public.helvetia_debiter_fonds_ordinaires(p_acteur, p_montant);
  IF NOT v_ok THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;

  -- Repartition REELLE du prelevement, recalculee sur l'etat d'avant : c'est elle
  -- qu'un remboursement devra restituer, pas une hypothese.
  v_pris_liq := least(coalesce(v_liq_avant, 0), p_montant);
  v_pris_nat := p_montant - v_pris_liq;

  INSERT INTO public.fonds_debits (acteur, montant, preleve_liquide, preleve_national)
  VALUES (p_acteur, p_montant, v_pris_liq, v_pris_nat)
  RETURNING id INTO v_debit;

  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'debit_id', v_debit,
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'solde_national', coalesce((SELECT solde FROM public.comptes_bancaires
                                 WHERE personnage = p_acteur AND banque = 'nationale'), 0));
END;
$function$;

-- dotation_attribuer_point(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.dotation_attribuer_point(p_stat text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_plafond   constant integer := 16;
  c_defaut    constant integer := 8;
  v_moi       text;
  v_stats     jsonb;
  v_reliquat  integer;
  v_courant   integer;
  v_cout      integer;
BEGIN
  IF p_stat IS NULL OR p_stat NOT IN ('INT','CHA','VOL','PER','DUP','ENT') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caracteristique_inconnue');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT CASE WHEN jsonb_typeof(d.stats) = 'object' THEN d.stats ELSE '{}'::jsonb END,
         coalesce(d.free_pts_restants, 0)
    INTO v_stats, v_reliquat
    FROM public.personnages_donnees d
   WHERE d.name = v_moi
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF v_reliquat <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dotation_epuisee');
  END IF;

  v_courant := coalesce((v_stats ->> p_stat)::integer, c_defaut);

  IF v_courant >= c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_atteint',
                              'plafond', c_plafond, 'valeur', v_courant);
  END IF;

  -- Meme bareme que adjStat : 2 points a partir de 12, sinon 1.
  v_cout := CASE WHEN v_courant >= 12 THEN 2 ELSE 1 END;

  IF v_reliquat < v_cout THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'points_insuffisants',
                              'restants', v_reliquat, 'requis', v_cout);
  END IF;

  UPDATE public.personnages_donnees
     SET stats             = v_stats || jsonb_build_object(p_stat, v_courant + 1),
         free_pts_restants = v_reliquat - v_cout
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'stat', p_stat, 'valeur', v_courant + 1,
                            'cout', v_cout, 'restants', v_reliquat - v_cout);
END;
$function$;

-- fonds_acteur_present(text,jsonb) -> boolean | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_acteur_present(p_acteur text, p_implantation jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT p_implantation IS NOT NULL
     AND public.acteur_present_sur_site(
           p_acteur,
           p_implantation->>'country',
           p_implantation->>'city',
           p_implantation->>'buildingId',
           p_implantation->>'roomId');
$function$;

-- fonds_cout_revient_reference(text,text) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_cout_revient_reference(p_fonds_id text, p_reference_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_ref jsonb; v_pays text;
  v_cmup numeric; v_stock numeric; v_coef numeric;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'fonds_absent');
  END IF;
  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'reference_absente');
  END IF;
  v_pays  := v_data->'implantation'->>'country';
  v_cmup  := (v_data->'coutMoyenReferences'->>p_reference_id)::numeric;
  v_stock := coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0);

  -- Aucun lot n'a jamais ete produit : il n'existe aucun cout reel a opposer.
  IF v_cmup IS NULL OR v_cmup <= 0 THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'aucun_cout_de_production',
                              'stock', v_stock);
  END IF;

  v_coef := public.coef_prix_max_pj(v_pays);
  IF v_coef IS NULL THEN
    RETURN jsonb_build_object('disponible', false, 'raison', 'coefficient_pays_non_defini',
                              'pays', v_pays, 'coutUnitaire', v_cmup);
  END IF;

  RETURN jsonb_build_object(
    'disponible', true, 'pays', v_pays, 'stock', v_stock,
    'recette', v_ref->>'recette_id', 'generique', v_ref->>'generique_id',
    'coutUnitaire', v_cmup, 'coefficient', v_coef,
    'prixMaximum', ceil(v_cmup * v_coef));
END;
$function$;

-- fonds_crediter_atteste(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_crediter_atteste(p_acteur text, p_source text, p_reference text, p_ordre text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_declare boolean; v_montant numeric; v_part numeric; v_cout numeric;
  v_arg numeric; v_liquide numeric;
BEGIN
  -- Le beneficiaire est l'appelant, et seulement lui.
  PERFORM public.exiger_acteur(p_acteur);

  IF p_reference IS NULL OR btrim(p_reference) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente');
  END IF;

  SELECT true, s.montant, s.part INTO v_declare, v_montant, v_part
    FROM public.fonds_credits_sources s WHERE s.source = p_source;
  IF NOT COALESCE(v_declare, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'source_non_declaree');
  END IF;

  -- Montant : fixe si la source en declare un, sinon le COUT REEL de l'ordre, jamais celui que
  -- le client pretend. La part permet un remboursement partiel declare (ex. 30%).
  IF v_montant IS NULL THEN
    SELECT max(o.cost) INTO v_cout FROM public.ordres_couts o WHERE o.fn = p_ordre;
    IF v_cout IS NULL OR v_cout <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ordre_non_declare', 'ordre', p_ordre);
    END IF;
    v_montant := floor(v_cout * COALESCE(v_part, 1));
  END IF;
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_nul');
  END IF;

  -- Trace d'abord : c'est elle qui porte l'idempotence.
  BEGIN
    INSERT INTO public.fonds_credits_uniques (acteur, source, reference, ordre, montant)
    VALUES (p_acteur, p_source, p_reference, p_ordre, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT COALESCE(arg,0), COALESCE(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = p_acteur;
    RETURN jsonb_build_object('ok', false, 'raison', 'credit_deja_accorde',
                              'arg', v_arg, 'liquide', v_liquide);
  END;

  -- Credit des FONDS ORDINAIRES : liquide (immediatement depensable) et arg (fortune affichee),
  -- exactement ce que fait crediterFondsOrdinaires cote client, mais atteste.
  UPDATE public.personnages_donnees
     SET liquide = COALESCE(liquide,0) + v_montant,
         arg     = COALESCE(arg,0) + v_montant,
         updated_at = now()
   WHERE name = p_acteur
   RETURNING arg, liquide INTO v_arg, v_liquide;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_introuvable');
  END IF;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'source', p_source,
                            'arg', v_arg, 'liquide', v_liquide);
END;
$function$;

-- fonds_definir_types(text,text,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_definir_types(p_acteur text, p_fonds_id text, p_types text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data      jsonb;
  v_demandes  text[];
  v_connus    text[];
  v_inconnus  text[];
  v_max       integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF COALESCE((v_data ->> 'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj');
  END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data ->> 'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;

  -- normalisation : doublons retires, ordre du referentiel
  SELECT array_agg(t.id ORDER BY t.ordre) INTO v_connus
    FROM public.catalogue_types t
   WHERE t.id = ANY (COALESCE(p_types, '{}'));
  v_connus := COALESCE(v_connus, '{}');

  SELECT array_agg(DISTINCT x) INTO v_inconnus
    FROM unnest(COALESCE(p_types, '{}')) AS x
   WHERE NOT EXISTS (SELECT 1 FROM public.catalogue_types t WHERE t.id = x);
  IF v_inconnus IS NOT NULL AND array_length(v_inconnus, 1) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_inconnu', 'types', to_jsonb(v_inconnus));
  END IF;

  v_max := public.fonds_types_max(v_data ->> 'proprietaire');
  IF array_length(v_connus, 1) IS NOT NULL AND array_length(v_connus, 1) > v_max THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'trop_de_types',
                              'maximum', v_max, 'demandes', array_length(v_connus, 1));
  END IF;

  v_data := jsonb_set(v_data, '{typesAutorises}', to_jsonb(v_connus));
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id,
                            'typesAutorises', to_jsonb(v_connus), 'maximum', v_max);
END;
$function$;

-- fonds_generiques_accessibles(text) -> TABLE(generique_id text, libelle text, famille_id text, famille text, types text[]) | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_generiques_accessibles(p_fonds_id text)
 RETURNS TABLE(generique_id text, libelle text, famille_id text, famille text, types text[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with f as (select data as d from public.entreprises where id = p_fonds_id),
  t as (select jsonb_array_elements_text(coalesce((select d->'typesAutorises' from f), '[]'::jsonb)) as type_id)
  select g.id, g.libelle, g.famille_id, fam.libelle,
         array_agg(distinct ty.id order by ty.id)
    from t
    join public.catalogue_generique_type gt on gt.type_id = t.type_id
    join public.catalogue_generiques g      on g.id = gt.generique_id
    join public.catalogue_familles fam      on fam.id = g.famille_id
    join public.catalogue_types ty          on ty.id = gt.type_id
   where exists (select 1 from public.recettes_commerce r where r.generique_id = g.id)
   group by g.id, g.libelle, g.famille_id, fam.libelle
   order by fam.libelle, g.libelle;
$function$;

-- fonds_matiere_apporter(text,text,text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_matiere_apporter(p_requete text, p_acteur text, p_fonds_id text, p_matiere text, p_qte integer, p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_deja   record;
  v_data   jsonb;
  v_mat    text := btrim(coalesce(p_matiere, ''));
  v_mode   text := lower(btrim(coalesce(p_mode, 'vente')));
  v_veut   integer := GREATEST(0, coalesce(p_qte, 0));
  v_m      record;
  v_inv    jsonb; v_jour integer;
  v_detenu numeric; v_capacite integer; v_payable integer;
  v_prix   numeric; v_qte integer; v_montant numeric;
  v_caisse numeric; v_stock numeric; v_cmup numeric; v_nouveau numeric;
  v_sm jsonb; v_cmm jsonb; v_inv_apres jsonb; v_reste integer; v_refus jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  IF p_requete IS NULL OR p_requete !~ '^appro-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF v_mode NOT IN ('vente', 'don') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF coalesce(p_fonds_id,'') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_veut <= 0 OR v_veut IS DISTINCT FROM p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  SELECT * INTO v_deja FROM public.apports_matieres WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'prixUnitaire', v_deja.prix_unitaire,
                              'montant', v_deja.montant, 'mode', v_deja.mode);
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  IF NOT public.fonds_acteur_present(p_acteur, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  -- LEGALITE. Meme primitive, meme verdict, meme vocabulaire que le moteur
  -- historique : une matiere interdite n'est ni vendue ni donnee, et la gratuite
  -- ne contourne rien. Le pays est celui de l'implantation du fonds.
  v_refus := public.matiere_refus_circuit_legal(p_acteur, v_mat, v_mode);
  IF v_refus IS NOT NULL THEN RETURN v_refus; END IF;

  SELECT * INTO v_m FROM public.fonds_matieres_accessibles(p_fonds_id) m WHERE m.matiere = v_mat;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_hors_activites', 'matiere', v_mat); END IF;
  IF NOT v_m.acceptee THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee', 'matiere', v_mat); END IF;
  IF v_m.plafond_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini',
                              'pays', v_data->'implantation'->>'country'); END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(day,1) INTO v_inv, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_detenu := public.inventaire_quantite(v_inv, v_mat);
  IF v_detenu <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu); END IF;

  v_capacite := v_m.place_restante;
  IF v_capacite <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein',
                              'stock', v_m.stock, 'maximum', v_m.maximum); END IF;

  v_prix   := CASE WHEN v_mode = 'don' THEN 0 ELSE GREATEST(0, coalesce(v_m.prix_achat, 0)) END;
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));

  v_payable := CASE WHEN v_prix <= 0 THEN v_veut ELSE floor(v_caisse / v_prix)::integer END;
  v_qte := LEAST(v_veut, floor(v_detenu)::integer, v_capacite, v_payable);

  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'prixUnitaire', v_prix); END IF;

  v_montant := round(v_prix * v_qte, 2);

  IF v_montant > 0 THEN
    UPDATE public.personnages_donnees
       SET arg     = COALESCE(arg, 0)     + v_montant,
           liquide = COALESCE(liquide, 0) + v_montant,
           updated_at = now()
     WHERE name = p_acteur;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_introuvable'); END IF;
  END IF;

  v_sm    := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm   := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_stock := GREATEST(0, coalesce((v_sm->>v_mat)::numeric, 0));
  v_cmup  := coalesce((v_cmm->>v_mat)::numeric, 0);
  v_nouveau := round(((v_cmup * v_stock) + (v_prix * v_qte)) / (v_stock + v_qte), 4);

  v_inv_apres := public.inventaire_retirer(v_inv, v_mat, v_qte);
  UPDATE public.personnages_donnees
     SET inventory = v_inv_apres, updated_at = now()
   WHERE name = p_acteur;

  v_data := v_data
    || jsonb_build_object(
         'stockMatieres',     jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + v_qte)),
         'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[v_mat], to_jsonb(v_nouveau)))
    || jsonb_build_object('caisse', v_caisse - v_montant);

  v_data := public.entreprise_ajouter_historique(v_data, -v_montant,
    CASE WHEN v_mode = 'don' THEN 'Don de matiere (' ELSE 'Achat de matiere (' END
    || v_mat || ' x' || v_qte || ') — ' || p_acteur, v_jour);

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  INSERT INTO public.apports_matieres
    (requete, fonds_id, acteur, matiere, mode, quantite, prix_unitaire, montant)
  VALUES (p_requete, p_fonds_id, p_acteur, v_mat, v_mode, v_qte, v_prix, v_montant);

  v_reste := CASE WHEN v_m.maximum = 0
                  THEN GREATEST(0, coalesce(v_m.plafond_pays, 0) - (v_stock + v_qte))::integer
                  ELSE GREATEST(0, v_m.maximum - (v_stock + v_qte))::integer END;

  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'matiere', v_mat,
    'quantite', v_qte, 'demandee', v_veut, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stock', v_stock + v_qte, 'maximum', v_m.maximum, 'illimite', v_m.maximum = 0,
    'placeRestante', v_reste,
    'coutMoyen', v_nouveau, 'caisse', v_caisse - v_montant, 'inventory', v_inv_apres);
END; $function$;

-- fonds_matiere_parametres(text,text,text,numeric,integer,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fonds_matiere_parametres(p_acteur text, p_fonds_id text, p_matiere text, p_prix_achat numeric, p_maximum integer, p_acceptee boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_pays text; v_plafond integer; v_par jsonb; v_mat text; v_ok boolean;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  v_mat := btrim(coalesce(p_matiere, ''));
  IF coalesce(p_fonds_id,'') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  IF NOT EXISTS (SELECT 1 FROM public.fonds_matieres_accessibles(p_fonds_id) m
                  WHERE m.matiere = v_mat) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_hors_activites'); END IF;

  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  IF v_plafond IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini', 'pays', v_pays); END IF;

  IF p_prix_achat IS NULL OR p_prix_achat < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;
  IF p_maximum IS NULL OR p_maximum < 0 OR p_maximum > v_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide',
                              'minimum', 0, 'maximum', v_plafond); END IF;

  v_ok := p_maximum > 0;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['prixAchatMatiere'],
             jsonb_set(coalesce(v_par->'prixAchatMatiere','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(round(p_prix_achat, 2))), true);
  v_par := jsonb_set(v_par, ARRAY['stockMaxMatieres'],
             jsonb_set(coalesce(v_par->'stockMaxMatieres','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(p_maximum)), true);
  v_par := jsonb_set(v_par, ARRAY['matieresAcceptees'],
             jsonb_set(coalesce(v_par->'matieresAcceptees','{}'::jsonb),
                       ARRAY[v_mat], to_jsonb(v_ok)), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'matiere', v_mat,
                            'prixAchat', round(p_prix_achat, 2), 'maximum', p_maximum,
                            'acceptee', v_ok, 'plafondPays', v_plafond);
END; $function$;

-- fonds_matieres_accessibles(text) -> TABLE(matiere text, stock numeric, maximum integer, plafond_pays integer, prix_achat numeric, place_restante integer, acceptee boolean, utilisee boolean) | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fonds_matieres_accessibles(p_fonds_id text)
 RETURNS TABLE(matiere text, stock numeric, maximum integer, plafond_pays integer, prix_achat numeric, place_restante integer, acceptee boolean, utilisee boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_data jsonb; v_pays text; v_plafond integer; v_defaut integer;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL OR coalesce((v_data->>'version')::numeric, 0) < 2 THEN RETURN; END IF;
  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);
  v_defaut  := LEAST(2, coalesce(v_plafond, 0));

  RETURN QUERY
  WITH acces AS (
    SELECT DISTINCT m.key AS cle
      FROM public.fonds_generiques_accessibles(p_fonds_id) g
      JOIN LATERAL public.generique_recettes_systeme(g.generique_id) s ON true,
           jsonb_each(s.materiaux) m
  ), utilisees AS (
    SELECT DISTINCT m.key AS cle
      FROM jsonb_each(coalesce(v_data->'references', '{}'::jsonb)) e
      JOIN public.recettes_commerce rc ON rc.id = e.value->>'recette_id',
           jsonb_each(coalesce(rc.materiaux, '{}'::jsonb)) m
  )
  SELECT x.cle, x.stk, x.maxi, v_plafond,
         coalesce((v_data->'parametres'->'prixAchatMatiere'->>x.cle)::numeric,
                  (SELECT re.prix_achat_fournisseur FROM public.ressources_economie re
                    WHERE re.cle = x.cle)),
         GREATEST(0, x.maxi - x.stk)::integer,
         x.maxi > 0,
         EXISTS (SELECT 1 FROM utilisees u WHERE u.cle = x.cle)
    FROM (
      SELECT a.cle,
             GREATEST(0, coalesce((v_data->'stockMatieres'->>a.cle)::numeric, 0)) AS stk,
             LEAST(GREATEST(0, coalesce((v_data->'parametres'->'stockMaxMatieres'->>a.cle)::integer,
                                        v_defaut)),
                   coalesce(v_plafond, 0))::integer AS maxi
        FROM acces a
    ) x
   ORDER BY x.cle;
END; $function$;

-- fonds_matieres_recherchees(text) -> TABLE(matiere text, stock numeric, maximum integer, plafond_pays integer, prix_achat numeric, place_restante integer) | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_matieres_recherchees(p_fonds_id text)
 RETURNS TABLE(matiere text, stock numeric, maximum integer, plafond_pays integer, prix_achat numeric, place_restante integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_pays text; v_plafond integer;
BEGIN
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id;
  IF v_data IS NULL OR coalesce((v_data->>'version')::numeric, 0) < 2 THEN RETURN; END IF;
  v_pays    := v_data->'implantation'->>'country';
  v_plafond := public.fonds_plafond_stock_matiere(v_pays);

  RETURN QUERY
  WITH recettes AS (
    SELECT DISTINCT e.value->>'recette_id' AS rid
      FROM jsonb_each(coalesce(v_data->'references', '{}'::jsonb)) e
     WHERE nullif(btrim(coalesce(e.value->>'recette_id', '')), '') IS NOT NULL
  ), matieres AS (
    SELECT DISTINCT m.key AS cle
      FROM recettes r
      JOIN public.recettes_commerce rc ON rc.id = r.rid,
           jsonb_each(coalesce(rc.materiaux, '{}'::jsonb)) m
  )
  SELECT x.cle,
         x.stk,
         x.maxi,
         v_plafond,
         coalesce((v_data->'parametres'->'prixAchatMatiere'->>x.cle)::numeric,
                  (SELECT re.prix_achat_fournisseur FROM public.ressources_economie re WHERE re.cle = x.cle)),
         GREATEST(0, x.maxi - x.stk)::integer
    FROM (
      SELECT m.cle,
             GREATEST(0, coalesce((v_data->'stockMatieres'->>m.cle)::numeric, 0)) AS stk,
             LEAST(coalesce((v_data->'parametres'->'stockMaxMatieres'->>m.cle)::integer, coalesce(v_plafond, 0)),
                   coalesce(v_plafond, 0))::integer AS maxi
        FROM matieres m
    ) x
   ORDER BY x.cle;
END; $function$;

-- fonds_plafond_stock_matiere(text) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.fonds_plafond_stock_matiere(p_pays text)
 RETURNS integer
 LANGUAGE sql
 STABLE
AS $function$
  select valeur::integer
    from public.entreprises_constantes
   where cle = 'stock_max_matiere_' || coalesce(nullif(btrim(p_pays), ''), '__aucun__');
$function$;

-- fonds_reference_activer(text,text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_reference_activer(p_acteur text, p_fonds_id text, p_reference_id text, p_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb;
  v_ref  jsonb;
  v_max  integer;
  v_actives integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;

  IF coalesce(p_active, false) THEN
    IF coalesce((v_ref->>'prixVente')::numeric, 0) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_fixe');
    END IF;
    -- PLUS DE PLAFOND A L'ACTIVATION (C6). Il en existait un, sur les references
    -- ACTIVES, et il entrait en concurrence avec le plafond du CATALOGUE pose a la
    -- creation. Deux semantiques pour une meme limite, c'est une faille : on
    -- creait 4 produits, on en desactivait un, on en creait un cinquieme, et le
    -- commerce finissait avec 5 references en jonglant. La limite gratuite porte
    -- desormais sur le CATALOGUE, une seule fois, a la creation. Retirer une
    -- reference de la vente ne libere donc aucune place -- elle appartient
    -- toujours au commerce.
  END IF;

  v_ref  := jsonb_set(v_ref, '{active}', to_jsonb(coalesce(p_active, false)));
  v_ref  := jsonb_set(v_ref, '{modifiee_le}',
              to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_data := jsonb_set(v_data, ARRAY['references', p_reference_id], v_ref);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id,
                            'active', coalesce(p_active, false));
END;
$function$;

-- fonds_reference_creer(text,text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_reference_creer(p_acteur text, p_fonds_id text, p_generique_id text, p_recette_id text, p_nom text, p_description text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_nom text := btrim(coalesce(p_nom, ''));
  v_desc text := nullif(btrim(coalesce(p_description, '')), '');
  v_rec  text := nullif(btrim(coalesce(p_recette_id, '')), '');
  v_ref_id text; v_gen record; v_n integer; v_nb_recettes integer; v_r record;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_generique_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;
  IF length(v_nom) > 80 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_trop_long', 'maximum', 80); END IF;
  IF v_desc IS NOT NULL AND length(v_desc) > 400 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'description_trop_longue', 'maximum', 400); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  SELECT * INTO v_gen FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = p_generique_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', p_generique_id,
                              'typesAutorises', coalesce(v_data->'typesAutorises','[]'::jsonb));
  END IF;

  SELECT count(*) INTO v_nb_recettes FROM public.recettes_commerce WHERE generique_id = p_generique_id;
  IF v_nb_recettes > 0 AND v_rec IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'recette_systeme_requise',
                              'recettes', (select jsonb_agg(jsonb_build_object('id', recette_id, 'label', label))
                                             from public.generique_recettes_systeme(p_generique_id)));
  END IF;
  IF v_nb_recettes = 0 AND v_rec IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_sans_recette');
  END IF;
  IF v_rec IS NOT NULL THEN
    SELECT * INTO v_r FROM public.recettes_commerce WHERE id = v_rec;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'recette_inexistante'); END IF;
    IF v_r.generique_id IS DISTINCT FROM p_generique_id THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                                'recetteGenerique', v_r.generique_id,
                                'generiqueDemande', p_generique_id); END IF;
  END IF;

  SELECT count(*) INTO v_n FROM jsonb_each(coalesce(v_data->'references','{}'::jsonb));
  -- PLAFOND FREEMIUM (C6). La valeur de C2 etait explicitement provisoire ; elle
  -- est desormais arbitree a 4 pour un commerce gratuit, et lue dans
  -- entreprises_constantes pour qu'un statut Premium puisse la relever demain
  -- sans toucher une ligne de moteur. Fail closed a la CREATION : on refuse la
  -- reference suivante, on ne detruit JAMAIS une reference deja existante.
  IF v_n >= public.fonds_references_max(v_data->>'proprietaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_references_atteint',
                              'maximum', public.fonds_references_max(v_data->>'proprietaire'),
                              'references', v_n);
  END IF;
  v_ref_id := 'ref-' || replace(gen_random_uuid()::text, '-', '');
  v_data := jsonb_set(v_data, ARRAY['references', v_ref_id], jsonb_strip_nulls(jsonb_build_object(
    'generique_id', v_gen.generique_id,
    'recette_id',   v_rec,
    'variante_id',  null,
    'nom',          v_nom,
    'description',  v_desc,
    'image',        null,
    'prixVente',    0,
    'active',       false,
    'creee_le',     to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')
  )));
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', v_ref_id,
                            'generique_id', v_gen.generique_id, 'generique', v_gen.libelle,
                            'recette_id', v_rec, 'famille', v_gen.famille, 'nom', v_nom,
                            'active', false, 'prixVente', 0, 'references', v_n + 1);
END;
$function$;

-- fonds_reference_modifier(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_reference_modifier(p_acteur text, p_fonds_id text, p_reference_id text, p_nom text, p_description text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb;
  v_ref  jsonb;
  v_nom  text;
  v_desc text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;

  IF p_nom IS NOT NULL THEN
    v_nom := btrim(p_nom);
    IF v_nom = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent'); END IF;
    IF length(v_nom) > 80 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'nom_trop_long', 'maximum', 80); END IF;
    v_ref := jsonb_set(v_ref, '{nom}', to_jsonb(v_nom));
  END IF;
  IF p_description IS NOT NULL THEN
    v_desc := nullif(btrim(p_description), '');
    IF v_desc IS NOT NULL AND length(v_desc) > 400 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'description_trop_longue', 'maximum', 400); END IF;
    v_ref := CASE WHEN v_desc IS NULL THEN v_ref - 'description'
                  ELSE jsonb_set(v_ref, '{description}', to_jsonb(v_desc)) END;
  END IF;
  v_ref  := jsonb_set(v_ref, '{modifiee_le}',
              to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_data := jsonb_set(v_data, ARRAY['references', p_reference_id], v_ref);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id,
                            'nom', v_ref->>'nom', 'description', v_ref->>'description',
                            'generique_id', v_ref->>'generique_id');
END;
$function$;

-- fonds_reference_prix(text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_reference_prix(p_acteur text, p_fonds_id text, p_reference_id text, p_prix integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_ref jsonb; v_cout jsonb; v_prix integer := floor(coalesce(p_prix, 0));
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;
  IF v_prix <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide'); END IF;

  v_cout := public.fonds_cout_revient_reference(p_fonds_id, p_reference_id);
  IF (v_cout->>'disponible')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_de_revient_indisponible',
                              'detail', v_cout);
  END IF;
  IF v_prix > (v_cout->>'prixMaximum')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_au_dessus_du_plafond',
                              'maximum', (v_cout->>'prixMaximum')::numeric,
                              'coutUnitaire', (v_cout->>'coutUnitaire')::numeric,
                              'coefficient', (v_cout->>'coefficient')::numeric);
  END IF;

  v_ref  := jsonb_set(v_ref, '{prixVente}', to_jsonb(v_prix));
  v_ref  := jsonb_set(v_ref, '{modifiee_le}',
              to_jsonb(to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')));
  v_data := jsonb_set(v_data, ARRAY['references', p_reference_id], v_ref);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id, 'prixVente', v_prix,
                            'maximum', (v_cout->>'prixMaximum')::numeric,
                            'coutUnitaire', (v_cout->>'coutUnitaire')::numeric);
END;
$function$;

-- fonds_reference_produire(text,text,text,text) -> jsonb | sql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_reference_produire(p_requete text, p_acteur text, p_fonds_id text, p_reference_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT public.fonds_reference_produire_lots(p_requete, p_acteur, p_fonds_id, p_reference_id, 1);
$function$;

-- fonds_reference_produire_lots(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_reference_produire_lots(p_requete text, p_acteur text, p_fonds_id text, p_reference_id text, p_lots integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_lots integer := coalesce(p_lots, 0);
  v_max_ref integer;
  v_data jsonb; v_ref jsonb; v_r record; v_gen record;
  v_sm jsonb; v_couts jsonb; v_m text; v_q jsonb;
  v_besoin numeric; v_dispo numeric; v_cm numeric;
  v_mat numeric := 0; v_pa_val numeric; v_pa_requis integer;
  v_nom_pj text; v_pa integer; v_manque jsonb := '[]'::jsonb;
  v_stock_avant integer; v_quantite integer; v_cout_lot numeric; v_unit numeric;
  v_cmup_avant numeric; v_cmup_apres numeric;
  v_deja record; v_salaire numeric; v_caisse numeric; v_jour integer;
  v_conso jsonb := '{}'::jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_requete IS NULL OR p_requete !~ '^prod-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_lots < 1 OR v_lots > 99 OR v_lots IS DISTINCT FROM p_lots THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lots_invalides',
                              'minimum', 1, 'maximum', 99);
  END IF;
  v_nom_pj := CASE WHEN left(p_acteur,3) = 'pj:' THEN substr(p_acteur,4) ELSE p_acteur END;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  IF NOT public.fonds_acteur_present(v_nom_pj, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  v_ref := v_data->'references'->p_reference_id;
  IF v_ref IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;
  IF coalesce(v_ref->>'recette_id','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_sans_recette'); END IF;

  SELECT * INTO v_r FROM public.recettes_commerce WHERE id = v_ref->>'recette_id';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'recette_inexistante'); END IF;
  IF v_r.generique_id IS DISTINCT FROM (v_ref->>'generique_id') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                              'recetteGenerique', v_r.generique_id,
                              'referenceGenerique', v_ref->>'generique_id'); END IF;
  IF coalesce(v_r.portions, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rendement_non_declare'); END IF;

  SELECT * INTO v_gen FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = v_ref->>'generique_id';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', v_ref->>'generique_id'); END IF;

  SELECT * INTO v_deja FROM public.productions_references WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'coutUnitaire', v_deja.cout_unitaire);
  END IF;

  SELECT coalesce(pa, 0), coalesce(day, 1) INTO v_pa, v_jour
    FROM public.personnages_donnees WHERE name = v_nom_pj FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  v_pa_requis := greatest(0, coalesce(v_r.pa, 0)) * v_lots;
  IF v_pa < v_pa_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_pa_requis, 'disponibles', v_pa,
                              'lots', v_lots); END IF;

  SELECT valeur::numeric INTO v_pa_val FROM public.entreprises_constantes
   WHERE cle = 'cout_main_oeuvre_pa_alimentaire';
  IF v_pa_val IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_pa_non_declaree'); END IF;
  v_salaire := round(v_pa_requis * v_pa_val, 2);

  -- TRANSFORMATION D'UN STOCK (30 septembre 2026), cote fonds PJ. Meme regle
  -- et meme garde que le moteur historique : le niveau vient de la loi votee.
  IF public.matiere_refus_circuit_legal_lot(v_nom_pj, coalesce(v_r.materiaux, '{}'::jsonb), 'transformation') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal_lot(v_nom_pj, coalesce(v_r.materiaux, '{}'::jsonb), 'transformation');
  END IF;
  v_sm    := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_couts := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(coalesce(v_r.materiaux, '{}'::jsonb)) LOOP
    v_besoin := (v_q#>>'{}')::numeric * v_lots;
    v_conso  := jsonb_set(v_conso, ARRAY[v_m], to_jsonb(v_besoin), true);
    v_dispo  := coalesce((v_sm->>v_m)::numeric, 0);
    IF v_dispo < v_besoin THEN
      v_manque := v_manque || jsonb_build_object('matiere', v_m, 'requis', v_besoin, 'dispo', v_dispo);
    END IF;
    v_cm := (v_couts->>v_m)::numeric;
    IF v_cm IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cout_matiere_inconnu', 'matiere', v_m);
    END IF;
    v_mat := v_mat + v_besoin * v_cm;
  END LOOP;
  IF jsonb_array_length(v_manque) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matieres_insuffisantes',
                              'manquantes', v_manque, 'lots', v_lots);
  END IF;

  v_quantite := v_r.portions * v_lots;
  v_max_ref  := nullif((v_data->'parametres'->'stockMaxReferences'->>p_reference_id)::integer, 0);
  v_stock_avant := greatest(0, coalesce((v_data->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
  IF v_max_ref IS NOT NULL AND v_stock_avant + v_quantite > v_max_ref THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_max_reference_depasse',
      'stock', v_stock_avant, 'rendement', v_quantite, 'rendementLot', v_r.portions,
      'lots', v_lots, 'maximum', v_max_ref);
  END IF;

  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));
  IF v_caisse < v_salaire THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'salaire', v_salaire, 'lots', v_lots);
  END IF;

  FOR v_m, v_q IN SELECT key, value FROM jsonb_each(v_conso) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_m],
              to_jsonb(coalesce((v_sm->>v_m)::numeric, 0) - (v_q#>>'{}')::numeric));
  END LOOP;

  v_cout_lot := v_mat + v_pa_requis * v_pa_val;
  v_unit     := v_cout_lot / v_quantite;

  v_cmup_avant := (v_data->'coutMoyenReferences'->>p_reference_id)::numeric;
  IF v_stock_avant <= 0 OR v_cmup_avant IS NULL THEN
    v_cmup_apres := v_unit;
  ELSE
    v_cmup_apres := (v_stock_avant * v_cmup_avant + v_cout_lot) / (v_stock_avant + v_quantite);
  END IF;

  v_data := jsonb_set(v_data, '{stockMatieres}', v_sm);
  v_data := jsonb_set(v_data, ARRAY['stockReferences', p_reference_id],
              to_jsonb(v_stock_avant + v_quantite), true);
  v_data := jsonb_set(v_data, ARRAY['coutMoyenReferences', p_reference_id],
              to_jsonb(v_cmup_apres), true);
  v_data := v_data || jsonb_build_object('caisse', v_caisse - v_salaire);
  v_data := public.entreprise_ajouter_historique(v_data, -v_salaire,
              'Production de ' || coalesce(v_ref->>'nom', p_reference_id)
              || ' (' || v_lots || ' lot(s), ' || v_quantite || ' unites) — ' || v_nom_pj, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  UPDATE public.personnages_donnees
     SET pa      = v_pa - v_pa_requis,
         arg     = COALESCE(arg, 0)     + v_salaire,
         liquide = COALESCE(liquide, 0) + v_salaire,
         updated_at = now()
   WHERE name = v_nom_pj;

  INSERT INTO public.productions_references
    (requete, fonds_id, reference_id, generique_id, recette_id, acteur,
     quantite, pa, matieres, cout_matieres, cout_lot, cout_unitaire)
  VALUES (p_requete, p_fonds_id, p_reference_id, v_r.generique_id, v_r.id, p_acteur,
     v_quantite, v_pa_requis, v_conso, v_mat, v_cout_lot, v_unit);

  RETURN jsonb_build_object('ok', true, 'rejeu', false,
    'referenceId', p_reference_id, 'recette', v_r.id, 'generique', v_r.generique_id,
    'lots', v_lots, 'rendementLot', v_r.portions,
    'quantite', v_quantite, 'stockAvant', v_stock_avant, 'stockApres', v_stock_avant + v_quantite,
    'paPreleves', v_pa_requis, 'paRestants', v_pa - v_pa_requis,
    'salaire', v_salaire, 'caisse', v_caisse - v_salaire,
    'coutMatieres', v_mat, 'coutLot', v_cout_lot, 'coutUnitaireLot', v_unit,
    'cmupAvant', v_cmup_avant, 'cmupApres', v_cmup_apres,
    'matieresConsommees', v_conso);
END; $function$;

-- fonds_reference_stock_max(text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fonds_reference_stock_max(p_acteur text, p_fonds_id text, p_reference_id text, p_maximum integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_par jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_fonds_id,'') = '' OR coalesce(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_maximum IS NULL OR p_maximum < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'maximum_invalide'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM p_acteur
     AND (v_data->>'proprietaire') IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF v_data->'references'->p_reference_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente'); END IF;

  v_par := coalesce(v_data->'parametres', '{}'::jsonb);
  v_par := jsonb_set(v_par, ARRAY['stockMaxReferences'],
             jsonb_set(coalesce(v_par->'stockMaxReferences','{}'::jsonb),
                       ARRAY[p_reference_id], to_jsonb(p_maximum)), true);

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{parametres}', v_par, true), updated_at = now()
   WHERE id = p_fonds_id;

  RETURN jsonb_build_object('ok', true, 'referenceId', p_reference_id, 'maximum', p_maximum);
END; $function$;

-- fonds_references_max(text) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.fonds_references_max(p_proprietaire text)
 RETURNS integer
 LANGUAGE sql
 STABLE
AS $function$
  select greatest(1, coalesce(
    (select valeur::integer from public.entreprises_constantes
      where cle = 'references_max_base'), 4));
$function$;

-- fonds_rembourser(uuid,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fonds_rembourser(p_debit_id uuid, p_source text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; d public.fonds_debits%ROWTYPE;
  v_part numeric; v_fixe numeric; v_montant numeric;
  v_arg numeric; v_liquide numeric; v_maj integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_debit_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'debit_absent');
  END IF;

  SELECT s.montant, s.part INTO v_fixe, v_part
    FROM public.fonds_credits_sources s WHERE s.source = p_source;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'source_non_declaree');
  END IF;

  -- Verrou sur la ligne : deux remboursements simultanes ne peuvent pas passer.
  SELECT * INTO d FROM public.fonds_debits WHERE id = p_debit_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'debit_introuvable');
  END IF;
  -- Le debit d'autrui n'est pas remboursable : il n'existe pas, pour moi.
  IF d.acteur IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'debit_introuvable');
  END IF;
  IF d.rembourse_le IS NOT NULL THEN
    SELECT coalesce(arg,0), coalesce(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_rembourse',
                              'arg', v_arg, 'liquide', v_liquide);
  END IF;

  -- Montant : la part declaree du debit REEL, jamais un montant transmis. Un
  -- montant fixe declare est plafonne par ce qui a ete preleve : une source ne
  -- peut pas rendre plus que ce qui a ete pris.
  v_montant := floor(d.montant * coalesce(v_part, 1));
  IF v_fixe IS NOT NULL THEN v_montant := least(v_fixe, d.montant); END IF;
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_nul');
  END IF;

  UPDATE public.fonds_debits
     SET rembourse_le = now(), montant_rembourse = v_montant, source_remb = p_source
   WHERE id = p_debit_id AND rembourse_le IS NULL;
  GET DIAGNOSTICS v_maj = ROW_COUNT;
  IF v_maj = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_rembourse');
  END IF;

  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide,0) + v_montant,
         arg     = coalesce(arg,0)     + v_montant,
         updated_at = now()
   WHERE name = v_moi
   RETURNING arg, liquide INTO v_arg, v_liquide;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'source', p_source,
                            'arg', v_arg, 'liquide', v_liquide);
END;
$function$;

-- fonds_types_max(text) -> integer | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.fonds_types_max(p_proprietaire text)
 RETURNS integer
 LANGUAGE sql
 STABLE
AS $function$
  select greatest(1, coalesce(
    (select valeur::integer from public.entreprises_constantes
      where cle = 'types_commerce_max_base'), 2));
$function$;

-- pa_bonus_chambre(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pa_bonus_chambre(p_acteur text, p_batiment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_montant integer; v_pa integer; v_resa jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT montant INTO v_montant FROM public.pa_bonus_hotel WHERE building_id = p_batiment;
  IF v_montant IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hotel_non_declare');
  END IF;
  SELECT reservation_hotel INTO v_resa
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_resa IS NULL OR jsonb_typeof(v_resa) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_reservation');
  END IF;
  -- La reservation est consommee ici : un bonus par sejour, jamais rejouable.
  UPDATE public.personnages_donnees SET reservation_hotel = NULL WHERE name = p_acteur;
  v_pa := public.pa_crediter_interne(p_acteur, v_montant);
  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'montant', v_montant);
END;
$function$;

-- pa_bonus_differe_crediter(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pa_bonus_differe_crediter(p_acteur text, p_source text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_montant integer; v_total integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT montant INTO v_montant FROM public.pa_bonus_differes WHERE source = p_source;
  IF v_montant IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'source_non_declaree');
  END IF;
  -- Plafonne a la reserve maximale : une accumulation sans fin n'aurait aucun sens, le bonus
  -- etant consomme au prochain Dormir et le stock plafonne a 30.
  UPDATE public.personnages_donnees
     SET bonus_pa_differe = least(30, coalesce(bonus_pa_differe, 0) + v_montant)
   WHERE name = p_acteur
   RETURNING bonus_pa_differe INTO v_total;
  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'bonus_differe', v_total);
END;
$function$;

-- pa_bonus_differes_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pa_bonus_differes_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(source || '|' || montant::text,
                             E'\n' ORDER BY source COLLATE "C")), 16)
  FROM public.pa_bonus_differes;
$function$;

-- pa_crediter_atteste(text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pa_crediter_atteste(p_acteur text, p_source text, p_reference text, p_ordre text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_declare boolean; v_montant integer; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_reference IS NULL OR btrim(p_reference) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente');
  END IF;

  SELECT true, montant INTO v_declare, v_montant
    FROM public.pa_credits_sources WHERE source = p_source;
  IF NOT coalesce(v_declare, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'source_non_declaree');
  END IF;

  -- Remboursement : le montant est celui que l'ordre coute REELLEMENT, pas celui qu'on demande.
  IF v_montant IS NULL THEN
    SELECT max(o.pa) INTO v_montant FROM public.ordres_couts o WHERE o.fn = p_ordre;
    IF v_montant IS NULL OR v_montant <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ordre_non_declare');
    END IF;
  END IF;

  BEGIN
    INSERT INTO public.pa_credits_uniques (acteur, source, reference, montant)
    VALUES (p_acteur, p_source, p_reference, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT coalesce(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = p_acteur;
    RETURN jsonb_build_object('ok', false, 'raison', 'credit_deja_accorde', 'pa', v_pa);
  END;

  v_pa := public.pa_crediter_interne(p_acteur, v_montant);
  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'montant', v_montant);
END;
$function$;

-- pa_crediter_interne(text,integer) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pa_crediter_interne(p_nom text, p_montant integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pa integer;
BEGIN
  UPDATE public.personnages_donnees
     SET pa = least(30, greatest(0, coalesce(pa, 0) + greatest(0, coalesce(p_montant, 0))))
   WHERE name = p_nom
   RETURNING pa INTO v_pa;
  RETURN v_pa;
END;
$function$;

-- pa_repos_nocturne(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.pa_repos_nocturne(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_pa_max         constant integer := 30;
  c_gain_civil     constant integer := 12;
  c_gain_caserne   constant integer := 12;
  c_gain_terrain   constant integer := 8;
  c_bonus_tente    constant integer := 2;
  v_pa integer; v_qhs jsonb; v_bonus integer; v_deja date;
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_nouveau integer; v_plafond_qhs integer;
  v_caserne boolean; v_tente boolean; v_grade text; v_gain integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT coalesce(pa, 0), detention_qhs, coalesce(bonus_pa_differe, 0), pa_repos_le,
         coalesce(current_building, '') = 'caserne-militaire',
         EXISTS (SELECT 1 FROM jsonb_array_elements(
                   CASE WHEN jsonb_typeof(d.inventory) = 'array' THEN d.inventory ELSE '[]'::jsonb END) i
                  WHERE i->>'produitMilitaire' = 'tente')
    INTO v_pa, v_qhs, v_bonus, v_deja, v_caserne, v_tente
    FROM public.personnages_donnees d WHERE d.name = p_acteur FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF v_deja IS NOT NULL AND v_deja >= v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_repose', 'pa', v_pa);
  END IF;

  IF v_qhs IS NOT NULL AND jsonb_typeof(v_qhs) = 'object' AND (v_qhs ->> 'enQHS')::boolean IS TRUE THEN
    v_plafond_qhs := CASE WHEN (v_qhs ->> 'paLimite1Jour')::boolean IS TRUE THEN 1 ELSE 3 END;
    v_nouveau := least(c_pa_max, greatest(0, v_plafond_qhs + v_bonus));
    IF (v_qhs ->> 'paLimite1Jour')::boolean IS TRUE THEN
      UPDATE public.personnages_donnees
         SET detention_qhs = v_qhs || jsonb_build_object('paLimite1Jour', false)
       WHERE name = p_acteur;
    END IF;
  ELSE
    v_grade := public.militaire_grade_effectif(p_acteur);
    IF v_grade IS NULL THEN
      v_gain := c_gain_civil;
    ELSIF v_caserne THEN
      v_gain := c_gain_caserne;
    ELSIF v_tente THEN
      v_gain := c_gain_terrain + c_bonus_tente;
    ELSE
      v_gain := c_gain_terrain;
    END IF;
    v_nouveau := least(c_pa_max, greatest(0, v_pa + v_gain + v_bonus));
  END IF;

  UPDATE public.personnages_donnees
     SET pa = v_nouveau, bonus_pa_differe = 0, pa_repos_le = v_jour
   WHERE name = p_acteur;

  RETURN jsonb_build_object('ok', true, 'pa', v_nouveau, 'bonus_consomme', v_bonus,
                            'qhs', (v_qhs ->> 'enQHS')::boolean IS TRUE,
                            'grade_militaire', v_grade, 'gain', v_gain,
                            'caserne', v_caserne, 'tente', v_tente);
END;
$function$;

-- percevoir_salaire_directeur(text,text,text,text,text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.percevoir_salaire_directeur(p_acteur text, p_pays text, p_ville text, p_batiment text, p_souscle text, p_poste_attendu text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste text; v_poste_city text; v_pays text; v_jour int; v_stats jsonb;
  v_marqueur text; v_id text; d record; v_nb int;
  v_etat jsonb; v_sous jsonb; v_solde numeric; v_verse numeric;
  v_arg numeric; v_liquide numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id', poste->>'city', coalesce(country,'republic'),
         coalesce(day,1), coalesce(stats,'{}'::jsonb), coalesce(arg,0), coalesce(liquide,0)
    INTO v_poste, v_poste_city, v_pays, v_jour, v_stats, v_arg, v_liquide
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_jour IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;
  IF v_poste IS DISTINCT FROM p_poste_attendu THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;
  SELECT count(*) INTO v_nb FROM public.directions_etablissements x
   WHERE x.pays = v_pays AND x.poste_id = v_poste
     AND (coalesce(btrim(v_poste_city), '') = '' OR x.ville = v_poste_city);
  IF v_nb <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'direction_non_declaree',
                              'poste', v_poste, 'ville_du_poste', v_poste_city, 'lignes_trouvees', v_nb);
  END IF;
  SELECT * INTO d FROM public.directions_etablissements x
   WHERE x.pays = v_pays AND x.poste_id = v_poste
     AND (coalesce(btrim(v_poste_city), '') = '' OR x.ville = v_poste_city);
  v_marqueur := 'salaireDirecteur_' || d.souscle || '_' || d.building_id;
  IF coalesce((v_stats->>v_marqueur)::int, -1) = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui');
  END IF;
  v_id := d.pays || '_' || d.ville || '_' || d.building_id;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etablissement_introuvable', 'id', v_id);
  END IF;
  v_sous  := coalesce(v_etat->d.souscle, '{}'::jsonb);
  v_solde := coalesce((v_sous->>'caisse')::numeric, 0);
  v_verse := least(v_solde, d.salaire_jour);
  IF v_verse < 0 THEN v_verse := 0; END IF;
  IF v_verse > 0 THEN
    UPDATE public.batiments_etat
       SET data = to_jsonb((v_etat || jsonb_build_object(d.souscle,
             v_sous || jsonb_build_object('caisse', v_solde - v_verse)))::text), updated_at = now()
     WHERE id = v_id;
  END IF;
  UPDATE public.personnages_donnees
     SET arg = v_arg + v_verse, liquide = v_liquide + v_verse,
         stats = jsonb_set(v_stats, ARRAY[v_marqueur], to_jsonb(v_jour))
   WHERE name = p_acteur;
  RETURN jsonb_build_object('ok', true, 'verse', v_verse,
    'complet', v_verse >= d.salaire_jour, 'du', d.salaire_jour,
    'etablissement', d.building_id, 'ville', d.ville,
    'arg', v_arg + v_verse, 'liquide', v_liquide + v_verse, 'caisse', v_solde - v_verse);
END; $function$;

-- redressement_fiscal_appliquer(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.redressement_fiscal_appliquer(p_type text, p_cible text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_montant constant numeric := 2000;
  v_acteur text; v_pays text;
  v_solde numeric; v_pris numeric;
  v_txt text; v_json jsonb; v_nat jsonb; v_ent jsonb;
BEGIN
  v_acteur := public.exiger_poste('min_fin');
  IF v_acteur IS NULL THEN v_acteur := public.mon_personnage(); END IF;
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_acteur;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF coalesce(btrim(coalesce(p_cible, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_invalide');
  END IF;

  IF p_type = 'club_sportif' THEN
    SELECT coalesce((data->>'caisse')::numeric, 0) INTO v_solde
      FROM public.budgets_clubs WHERE id = p_cible FOR UPDATE;
    IF v_solde IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    v_pris := least(v_solde, c_montant);
    IF v_pris <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide', 'solde', v_solde);
    END IF;
    UPDATE public.budgets_clubs
       SET data = jsonb_set(coalesce(data, '{}'::jsonb), '{caisse}', to_jsonb(v_solde - v_pris))
     WHERE id = p_cible;

  ELSIF p_type = 'organisation' THEN
    SELECT data INTO v_txt FROM public.organisations WHERE id = p_cible FOR UPDATE;
    IF v_txt IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cible_introuvable');
    END IF;
    BEGIN
      v_json := v_txt::jsonb;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'donnee_illisible');
    END;
    v_solde := coalesce((v_json->>'caisse')::numeric, 0);
    v_pris := least(v_solde, c_montant);
    IF v_pris <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide', 'solde', v_solde);
    END IF;
    UPDATE public.organisations
       SET data = (jsonb_set(v_json, '{caisse}', to_jsonb(v_solde - v_pris)))::text
     WHERE id = p_cible;

  ELSIF p_type = 'entreprise' THEN
    -- Reutilise la primitive attestee qui existait deja pour ce type (elle exige min_fin de son
    -- cote, replafonne sur la caisse reelle et n'ecrit que la caisse). Ce qui change ici : son
    -- versement au Tresor etait un appel client SEPARE, non atomique et jamais verifie.
    v_ent := public.entreprise_mouvement_fiscal(v_acteur, p_cible, -c_montant);
    IF NOT coalesce((v_ent->>'ok')::boolean, false) THEN
      RETURN jsonb_build_object('ok', false, 'raison',
        coalesce(v_ent->>'raison', 'entreprise_refusee'), 'detail', v_ent);
    END IF;
    v_pris := abs(coalesce((v_ent->>'montantReel')::numeric, 0));
    IF v_pris <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide');
    END IF;

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'type_non_couvert', 'type', p_type);
  END IF;

  SELECT data INTO v_nat FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_nat IS NULL THEN
    RAISE EXCEPTION 'redressement_fiscal: budget national % absent', v_pays;
  END IF;
  UPDATE public.budgets_nationaux
     SET data = jsonb_set(v_nat, '{reserveJour}',
           to_jsonb(coalesce((v_nat->>'reserveJour')::numeric, 0) + v_pris)),
         updated_at = now()
   WHERE id = v_pays;

  RETURN jsonb_build_object('ok', true, 'montant', v_pris, 'pays', v_pays);
END;
$function$;

-- retirer_caisse_fonds(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.retirer_caisse_fonds(p_acteur text, p_fonds_id text, p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_data    jsonb;
  v_caisse  integer;
  v_m       integer := coalesce(p_montant, 0);
  v_proprio text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF coalesce(p_acteur,'') = '' OR coalesce(p_fonds_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_m <= 0 OR v_m IS DISTINCT FROM p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  v_proprio := v_data->>'proprietaire';
  IF v_proprio IS DISTINCT FROM p_acteur AND v_proprio IS DISTINCT FROM 'pj:' || p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;

  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0))::integer;
  IF v_m > v_caisse THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse); END IF;

  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse - v_m)),
         updated_at = now()
   WHERE id = p_fonds_id;

  IF left(coalesce(v_proprio,''), 5) = 'orga:' THEN
    IF NOT public.mouvement_titulaire(v_proprio, v_m) THEN
      RAISE EXCEPTION 'titulaire_introuvable'; END IF;
  ELSE
    UPDATE public.personnages_donnees
       SET arg     = coalesce(arg, 0)     + v_m,
           liquide = coalesce(liquide, 0) + v_m,
           updated_at = now()
     WHERE name = p_acteur;
    IF NOT FOUND THEN RAISE EXCEPTION 'titulaire_introuvable'; END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'montant', v_m, 'caisse', v_caisse - v_m);
END; $function$;

-- salaire_caisse_de(text,text,text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.salaire_caisse_de(p_poste_id text, p_pays text, p_ville text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v_id text; v_alt text;
BEGIN
  SELECT * INTO r FROM public.salaires_caisses s WHERE s.poste_id = p_poste_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  v_id := replace(replace(r.motif, '{pays}', coalesce(p_pays,'')), '{ville}', coalesce(p_ville,''));
  IF EXISTS (SELECT 1 FROM public.caisses_batiments c WHERE c.id = v_id) THEN
    RETURN v_id;
  END IF;

  -- La capitale ecrit « mairie-capitale » la ou les autres villes ecrivent
  -- « mairie_ville_a ». On essaie donc la variante a tiret avant d'abandonner.
  v_alt := replace(v_id, '_' || coalesce(p_ville,''), '-' || coalesce(p_ville,''));
  IF v_alt <> v_id AND EXISTS (SELECT 1 FROM public.caisses_batiments c WHERE c.id = v_alt) THEN
    RETURN v_alt;
  END IF;

  RETURN NULL;
END;
$function$;

-- salaire_civil_percevoir() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.salaire_civil_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; v_ville text; v_grade text;
  v_jour date; v_id text; v_cle text; v_origine text; v_montant integer;
  v_offres jsonb; v_offre text; v_caisse text; v_solde numeric;
  v_arg numeric; v_liquide numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(country,'republic'), poste ->> 'id',
         public.salaire_ville_du_poste(poste ->> 'id', poste ->> 'city')
    INTO v_pays, v_poste, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;
  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NOT NULL OR coalesce(v_poste,'') IN ('soldat','lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paye_par_la_caserne');
  END IF;
  IF v_poste IS NOT NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s
     WHERE s.pays = v_pays AND s.cle = v_poste AND s.categorie = 'poste';
  END IF;
  IF v_cle IS NULL THEN
    SELECT coalesce(e.data -> 'offres', e.data -> 'bne' -> 'offres')
      INTO v_offres FROM public.batiments_etat e WHERE e.id = v_pays || '_national_bne';
    IF v_offres IS NOT NULL AND jsonb_typeof(v_offres) = 'object' THEN
      SELECT t.k INTO v_offre
        FROM jsonb_each(v_offres) AS t(k, v)
        WHERE EXISTS (
          SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.v)='array' THEN t.v ELSE '[]'::jsonb END) o
           WHERE o ->> 'pjNom' = v_moi AND coalesce(o ->> 'statut','actif') = 'actif')
        LIMIT 1;
      IF v_offre IS NOT NULL THEN
        SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
          FROM public.salaires_civils_declares s
         WHERE s.pays = v_pays AND s.cle = v_offre AND s.categorie = 'emploi';
      END IF;
    END IF;
  END IF;
  IF v_cle IS NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s
     WHERE s.pays = v_pays AND s.cle = 'default';
  END IF;
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bareme_absent', 'pays', v_pays);
  END IF;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;
  IF v_origine = 'poste' THEN
    v_caisse := public.salaire_caisse_de(v_poste, v_pays, v_ville);
    IF v_caisse IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_payeuse_non_declaree', 'poste', v_poste);
    END IF;
  END IF;
  BEGIN
    INSERT INTO public.salaires_civils_verses (id, personnage, jour, origine, cle, montant)
    VALUES (v_id, v_moi, v_jour, v_origine, v_cle, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT coalesce(arg,0), coalesce(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui',
                              'jour', v_jour, 'arg', v_arg, 'liquide', v_liquide);
  END;
  IF v_caisse IS NOT NULL THEN
    SELECT (data->>'solde')::numeric INTO v_solde
      FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    IF coalesce(v_solde, 0) < v_montant THEN
      DELETE FROM public.salaires_civils_verses WHERE id = v_id;
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                                'caisse', v_caisse, 'solde', coalesce(v_solde,0), 'du', v_montant);
    END IF;
    UPDATE public.caisses_batiments
       SET data = coalesce(data,'{}'::jsonb) || jsonb_build_object('solde', v_solde - v_montant),
           updated_at = now()
     WHERE id = v_caisse;
  END IF;
  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide,0) + v_montant, arg = coalesce(arg,0) + v_montant,
         updated_at = now()
   WHERE name = v_moi
   RETURNING arg, liquide INTO v_arg, v_liquide;
  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'origine', v_origine,
                            'cle', v_cle, 'jour', v_jour, 'caisse', v_caisse,
                            'arg', v_arg, 'liquide', v_liquide);
END; $function$;

-- salaire_religieux_percevoir() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.salaire_religieux_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi     text;
  v_pays    text;
  v_jour    date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_total   numeric := 0;
  v_details jsonb := '[]'::jsonb;
  r         record;
  v_titulaire text;
  v_id      text;
  v_solde   numeric;
  v_verse   numeric;
  v_arg     numeric;
  v_liquide numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT coalesce(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;
  IF coalesce(v_pays, 'republic') <> 'republic' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'carriere_religieuse_republia_uniquement');
  END IF;

  FOR r IN SELECT * FROM public.salaires_religieux_declares ORDER BY cle LOOP
    -- LE TITULAIRE FAIT AUTORITE, PAS L'APPELANT. Le repli PNJ par defaut n'est
    -- jamais le joueur : une charge sans titulaire enregistre ne paie personne.
    SELECT t.nom_pnj INTO v_titulaire
      FROM public.titulaires_pnj t
     WHERE t.country = 'republic'
       AND t.poste_id = split_part(r.cle, ':', 1)
       AND ((r.ville IS NULL AND t.city IS NULL) OR t.city = r.ville)
     LIMIT 1;

    CONTINUE WHEN v_titulaire IS NULL OR v_titulaire <> v_moi;

    v_id := v_moi || ':' || r.cle || ':' || v_jour::text;
    BEGIN
      INSERT INTO public.salaires_religieux_verses (id, personnage, cle, jour, montant)
      VALUES (v_id, v_moi, r.cle, v_jour, r.montant);
    EXCEPTION WHEN unique_violation THEN
      CONTINUE;  -- deja percu aujourd'hui pour CETTE charge
    END;

    SELECT (data->>'solde')::numeric INTO v_solde
      FROM public.caisses_batiments WHERE id = r.caisse FOR UPDATE;

    -- Plafonne : la caisse paie ce qu'elle peut, jamais a decouvert.
    v_verse := least(coalesce(v_solde, 0), r.montant);
    IF v_verse <= 0 THEN
      -- Rien verse : on retire la ligne d'anti-rejeu pour que le titulaire puisse
      -- retenter si sa caisse est realimentee dans la journee.
      DELETE FROM public.salaires_religieux_verses WHERE id = v_id;
      v_details := v_details || jsonb_build_object('cle', r.cle, 'verse', 0, 'raison', 'caisse_vide');
      CONTINUE;
    END IF;

    UPDATE public.caisses_batiments
       SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
           updated_at = now()
     WHERE id = r.caisse;
    UPDATE public.salaires_religieux_verses SET montant = v_verse WHERE id = v_id;

    v_total   := v_total + v_verse;
    v_details := v_details || jsonb_build_object('cle', r.cle, 'verse', v_verse, 'caisse', r.caisse);
  END LOOP;

  IF v_total > 0 THEN
    UPDATE public.personnages_donnees
       SET liquide = coalesce(liquide, 0) + v_total,
           arg     = coalesce(arg, 0)     + v_total,
           updated_at = now()
     WHERE name = v_moi
     RETURNING arg, liquide INTO v_arg, v_liquide;
  ELSE
    SELECT coalesce(arg, 0), coalesce(liquide, 0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
  END IF;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'jour', v_jour,
                            'details', v_details, 'arg', v_arg, 'liquide', v_liquide);
END;
$function$;

-- salaire_ville_du_poste(text,text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.salaire_ville_du_poste(p_poste_id text, p_ville_fiche text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN coalesce(btrim(p_ville_fiche), '') <> '' THEN p_ville_fiche
    ELSE (SELECT s.ville_defaut FROM public.salaires_caisses s WHERE s.poste_id = p_poste_id)
  END;
$function$;

-- salaires_coherence() -> TABLE(probleme text, cles text) | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.salaires_coherence()
 RETURNS TABLE(probleme text, cles text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'bareme de poste sans caisse payeuse', string_agg(s.pays || '/' || s.cle, ', ' ORDER BY s.pays, s.cle)
    FROM public.salaires_civils_declares s
   WHERE s.categorie = 'poste'
     AND NOT EXISTS (SELECT 1 FROM public.salaires_caisses c WHERE c.poste_id = s.cle)
  HAVING count(*) > 0
  UNION ALL
  SELECT 'caisse payeuse sans bareme', string_agg(c.poste_id, ', ' ORDER BY c.poste_id)
    FROM public.salaires_caisses c
   WHERE NOT EXISTS (SELECT 1 FROM public.salaires_civils_declares s
                      WHERE s.cle = c.poste_id AND s.categorie = 'poste')
  HAVING count(*) > 0
  UNION ALL
  SELECT 'poste de direction declare en bareme de poste : SUPPRIME le cumul avec le revenu universel',
         string_agg(s.pays || '/' || s.cle, ', ' ORDER BY s.pays, s.cle)
    FROM public.salaires_civils_declares s
   WHERE s.categorie = 'poste'
     AND EXISTS (SELECT 1 FROM public.directions_etablissements d
                  WHERE d.pays = s.pays AND d.poste_id = s.cle)
  HAVING count(*) > 0
  UNION ALL
  SELECT 'bareme sans empire declare', string_agg(s.cle, ', ' ORDER BY s.cle)
    FROM public.salaires_civils_declares s
   WHERE coalesce(btrim(s.pays), '') = ''
  HAVING count(*) > 0;
$function$;

-- subvention_citoyen_verser(text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.subvention_citoyen_verser(p_beneficiaire text, p_montant integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_acteur text; v_pays text; v_caisse text; v_data jsonb;
  v_solde numeric; v_verse numeric; v_arg numeric;
BEGIN
  -- 1. AUTORITE. exiger_poste leve si le compte n'a pas de personnage ou n'est pas min_fin.
  v_acteur := public.exiger_poste('min_fin');
  IF v_acteur IS NULL THEN            -- appel serveur (cron) : pas de subvention automatique
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;
  IF coalesce(v_pays, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_indetermine');
  END IF;

  -- 2. MONTANT. Memes bornes que le formulaire : au moins 1, au plus 5000.
  IF p_montant IS NULL OR p_montant < 1 OR p_montant > 5000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  -- 3. BENEFICIAIRE. Il doit exister. La ligne est verrouillee avant tout mouvement.
  SELECT coalesce(arg, 0) INTO v_arg
    FROM public.personnages_donnees WHERE name = p_beneficiaire FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_introuvable');
  END IF;

  -- 4. CAISSE. Verrouillee elle aussi : le solde lu est celui qu'on debite.
  v_caisse := v_pays || '_gouvernement-min_fin';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data->'solde') = 'number'
                  THEN (v_data->>'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);   -- versement partiel tolere, comme avant
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0);
  END IF;

  -- 5. LES DEUX MOUVEMENTS, ENSEMBLE.
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = v_caisse;

  -- INCREMENT, jamais « solde relu + montant » : c'est ce calcul qui aurait ecrase la fortune.
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) + v_verse
   WHERE name = p_beneficiaire;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'beneficiaire', p_beneficiaire,
                            'acteur', v_acteur, 'caisse', v_caisse);
END; $function$;

-- vente_structure_encaisser(text,integer,integer,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.vente_structure_encaisser(p_fn text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0, p_caisse text DEFAULT NULL::text, p_ville text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text;
  v_pays text;
  v_ville text;
  v_taxable boolean;
  v_paye jsonb;
  v_taxe jsonb := NULL;
  v_net numeric;
  v_credit jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  v_taxable := CASE p_fn
    WHEN 'reserver_chambre_hotel' THEN true
    WHEN 'consommer_buvette'      THEN true
    WHEN 'faire_don'              THEN false
    ELSE NULL
  END;
  IF v_taxable IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'vente_non_declaree', 'fn', p_fn);
  END IF;

  SELECT coalesce(pd.country, 'republic'),
         coalesce(nullif(btrim(coalesce(p_ville, '')), ''), pd.current_city, 'capitale')
    INTO v_pays, v_ville
    FROM public.personnages_donnees pd
   WHERE pd.name = v_acteur;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF coalesce(btrim(coalesce(p_caisse, '')), '') = ''
     OR p_caisse NOT LIKE v_pays || '\_%' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_empire', 'caisse', p_caisse);
  END IF;

  v_paye := public.payer_ordre(v_acteur, p_fn, p_pa, p_cost);
  IF NOT coalesce((v_paye->>'ok')::boolean, false) THEN
    RETURN v_paye;
  END IF;

  v_net := coalesce(p_cost, 0);
  IF v_taxable AND v_net > 0 THEN
    v_taxe := public.appliquer_taxe_transaction(v_pays, v_ville, v_net);
    v_net := coalesce((v_taxe->>'net')::numeric, v_net);
  END IF;

  IF v_net > 0 THEN
    v_credit := public.caisse_institution_mouvement(p_caisse, v_net, false);
    IF NOT coalesce((v_credit->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'vente_structure: credit impossible sur % (%)',
        p_caisse, coalesce(v_credit->>'raison', 'motif inconnu');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'pa', v_paye->'pa',
    'liquide', v_paye->'liquide',
    'arg', v_paye->'arg',
    'solde_national', v_paye->'solde_national',
    'pa_preleves', v_paye->'pa_preleves',
    'montant_preleve', v_paye->'montant_preleve',
    'net', v_net,
    'taxe', v_taxe,
    'caisse', p_caisse,
    'ville', v_ville);
END;
$function$;
