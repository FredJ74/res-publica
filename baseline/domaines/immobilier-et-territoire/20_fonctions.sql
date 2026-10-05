-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine immobilier et territoire -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- bail_autorite_de(jsonb) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bail_autorite_de(p_data jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.bail_je_suis_locataire(p_data)
      OR public.bail_autorite_municipale(p_data)
      OR public.bail_proprietaire_des_murs(p_data);
$function$

-- bail_autorite_municipale(jsonb) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bail_autorite_municipale(p_data jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') IN ('maire', 'maire_adjoint')
       AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_data ->> 'city', 'capitale')
  );
$function$

-- bail_cle_coherente() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bail_cle_coherente()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_base text;
BEGIN
  IF public.est_appel_serveur() THEN RETURN NEW; END IF;
  IF NEW.data IS NULL THEN
    RAISE EXCEPTION 'bail_sans_donnees' USING ERRCODE = '42501';
  END IF;
  v_base := coalesce(NEW.data ->> 'country', 'republic') || ':' ||
            coalesce(NEW.data ->> 'buildingId', '')      || ':' ||
            coalesce(NEW.data ->> 'roomId', '')          || ':' ||
            coalesce(NEW.data ->> 'city', '');
  IF NEW.id <> v_base
     AND NEW.id <> v_base || ':' || coalesce(NEW.data ->> 'locataire', '') THEN
    RAISE EXCEPTION 'bail_cle_incoherente' USING ERRCODE = '42501';
  END IF;
  -- Le pays de la colonne doit suivre celui du bail.
  IF coalesce(NEW.country, '') IS DISTINCT FROM coalesce(NEW.data ->> 'country', 'republic') THEN
    NEW.country := NEW.data ->> 'country';
  END IF;
  RETURN NEW;
END;
$function$

-- bail_destination_attestee(jsonb) -> jsonb | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.bail_destination_attestee(p_data jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE
    -- Un bail sans loyer reel n'a pas de destination.
    WHEN coalesce((p_data ->> 'chambreClinique')::boolean, false) THEN NULL
    -- Box portuaire multi-tenant : caisse du batiment DU BAIL.
    WHEN coalesce((p_data ->> 'isBox')::boolean, false)
      THEN jsonb_build_object('type', 'caisse_batiment',
                              'buildingId', p_data ->> 'buildingId')
    -- Lot dynamique d'un bien subdivise : le proprietaire des murs, resolu au
    -- moment du prelevement. Aucun titulaire n'est inscrit ici, volontairement.
    WHEN left(coalesce(p_data ->> 'roomId', ''), 8) = 'lot_dyn_'
      THEN jsonb_build_object('type', 'titulaire_murs')
    -- Tout le reste : la commune du bail.
    ELSE jsonb_build_object('type', 'municipal',
                            'pays',  coalesce(p_data ->> 'country', 'republic'),
                            'ville', coalesce(p_data ->> 'city', 'capitale'))
  END;
$function$

-- bail_je_suis_locataire(jsonb) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bail_je_suis_locataire(p_data jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce(p_data ->> 'locataire', '') = coalesce(public.mon_personnage(), '\x00'); $function$

-- bail_proprietaire_des_murs(jsonb) -> boolean | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bail_proprietaire_des_murs(p_data jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_prop text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN false; END IF;
  SELECT (t.data::jsonb ->> 'proprietaire') INTO v_prop
    FROM public.terrains_etat t
   WHERE t.country = coalesce(p_data ->> 'country', 'republic')
     AND t.building_id = (p_data ->> 'buildingId')
   LIMIT 1;
  IF v_prop IS NULL OR btrim(v_prop) = '' THEN RETURN false; END IF;
  IF left(v_prop, 3) = 'pj:' THEN v_prop := substr(v_prop, 4); END IF;
  RETURN v_prop = v_moi;
EXCEPTION WHEN OTHERS THEN
  RETURN false;   -- data illisible : aucune autorite accordee
END;
$function$

-- batiment_caisse_mouvement(text,text,text,text,numeric,text,numeric,numeric,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.batiment_caisse_mouvement(p_pays text, p_ville text, p_building text, p_souscle text, p_delta numeric, p_stock_cle text DEFAULT NULL::text, p_stock numeric DEFAULT 0, p_stock_max numeric DEFAULT NULL::numeric, p_exiger_existant boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id text; v_brut jsonb; v_d jsonb; v_obj jsonb; v_caisse numeric; v_st numeric; v_existe boolean;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  -- ATTRIBUTION OBLIGATOIRE : soit le serveur (cron, service_role), soit un compte portant
  -- reellement un personnage. Ne dit rien de l'AUTORITE sur le montant : voir le chantier
  -- caisse_institution_mouvement, laisse ouvert.
  IF NOT public.est_appel_serveur() AND public.mon_personnage() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  IF COALESCE(btrim(p_pays), '') = '' OR COALESCE(btrim(p_ville), '') = ''
     OR COALESCE(btrim(p_building), '') = '' OR COALESCE(btrim(p_souscle), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_delta IS NULL OR abs(p_delta) > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_id := p_pays || '_' || p_ville || '_' || p_building;
  SELECT data INTO v_brut FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  v_existe := FOUND;

  IF p_exiger_existant AND NOT v_existe THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_d := CASE WHEN NOT v_existe THEN '{}'::jsonb
              WHEN jsonb_typeof(v_brut) = 'string' THEN (v_brut #>> '{}')::jsonb
              WHEN jsonb_typeof(v_brut) = 'object' THEN v_brut
              ELSE '{}'::jsonb END;

  IF p_exiger_existant AND jsonb_typeof(v_d -> p_souscle) IS DISTINCT FROM 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_absente');
  END IF;

  v_obj := CASE WHEN jsonb_typeof(v_d -> p_souscle) = 'object' THEN v_d -> p_souscle ELSE '{}'::jsonb END;
  v_caisse := CASE WHEN jsonb_typeof(v_obj -> 'caisse') = 'number' THEN (v_obj ->> 'caisse')::numeric ELSE 0 END;

  IF v_caisse + p_delta < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'caisse', v_caisse);
  END IF;

  v_obj := v_obj || jsonb_build_object('caisse', v_caisse + p_delta);

  IF p_stock_cle IS NOT NULL AND COALESCE(p_stock, 0) <> 0 THEN
    v_st := CASE WHEN jsonb_typeof(v_obj -> p_stock_cle) = 'number' THEN (v_obj ->> p_stock_cle)::numeric ELSE 0 END;
    IF v_st + p_stock < 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'stock', v_st, 'caisse', v_caisse);
    END IF;
    IF p_stock_max IS NOT NULL AND v_st + p_stock > p_stock_max THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_plafond', 'stock', v_st,
                                'stock_max', p_stock_max, 'caisse', v_caisse);
    END IF;
    v_obj := v_obj || jsonb_build_object(p_stock_cle, v_st + p_stock);
  END IF;

  v_d := v_d || jsonb_build_object(p_souscle, v_obj);

  IF v_existe THEN
    UPDATE public.batiments_etat SET data = to_jsonb(v_d::text), updated_at = now() WHERE id = v_id;
  ELSE
    INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
    VALUES (v_id, p_pays, p_ville, p_building, to_jsonb(v_d::text), now());
  END IF;

  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse + p_delta,
                            'stock', CASE WHEN p_stock_cle IS NULL THEN NULL ELSE v_obj -> p_stock_cle END);
END;
$function$

-- batiment_etat_lire(jsonb) -> jsonb | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.batiment_etat_lire(p_data jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN p_data IS NULL THEN '{}'::jsonb
              WHEN jsonb_typeof(p_data) = 'string' THEN (p_data #>> '{}')::jsonb
              ELSE p_data END;
$function$

-- batiment_etat_sous_cle_ecrire(text,text,text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.batiment_etat_sous_cle_ecrire(p_pays text, p_ville text, p_batiment text, p_sous_cle text, p_valeur jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text; v_serveur boolean; v_poste jsonb; v_moi text;
  v_data jsonb; v_etat jsonb; v_mauvaise text; v_el jsonb; v_sous jsonb; v_n numeric;
BEGIN
  IF p_pays IS NULL OR p_ville IS NULL OR p_batiment IS NULL OR p_sous_cle IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'arguments_manquants');
  END IF;
  v_id := p_pays || '_' || p_ville || '_' || p_batiment;
  v_serveur := public.est_appel_serveur();

  IF p_sous_cle NOT IN ('blocus','effectifsPolice','effectifsDouane','candidatures',
                        'parCaisse','controles','offres') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'sous_cle_non_autorisee');
  END IF;

  v_mauvaise := public.jsonb_cle_economique_presente(p_valeur);
  IF v_mauvaise IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cle_economique_interdite', 'cle', v_mauvaise);
  END IF;

  IF NOT v_serveur THEN
    SELECT p.name, p.poste INTO v_moi, v_poste
    FROM public.personnages_donnees p WHERE p.user_id = auth.uid() LIMIT 1;
    IF v_moi IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
    END IF;

    IF p_sous_cle = 'effectifsPolice' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'commissaire'
         OR (v_poste->>'city') IS DISTINCT FROM p_ville
         OR p_batiment NOT IN ('commissariat','commissariat-local') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'effectifsDouane' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'chef_douanes'
         OR p_ville <> 'ville_a' OR p_batiment <> 'port-sainte-marie' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'controles' THEN
      IF (v_poste->>'id') IS DISTINCT FROM 'chef_douanes'
         OR v_id <> 'global_national_dissimulation-fret' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
      END IF;
    ELSIF p_sous_cle = 'parCaisse' THEN
      IF v_id <> 'global_national_dissimulation-fret' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    ELSIF p_sous_cle = 'candidatures' THEN
      IF p_ville <> 'national' OR p_batiment <> 'candidatures_postes' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    ELSIF p_sous_cle = 'offres' THEN
      IF p_ville <> 'national' OR p_batiment <> 'bne' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'emplacement_invalide');
      END IF;
    END IF;
  END IF;

  IF p_sous_cle IN ('effectifsPolice','effectifsDouane') THEN
    IF jsonb_typeof(p_valeur) <> 'object'
       OR public.jsonb_cles_hors_liste(p_valeur,
            ARRAY['policiers','douaniers','dernierPaiementJour']) IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    v_sous := COALESCE(p_valeur->'policiers', p_valeur->'douaniers');
    IF v_sous IS NOT NULL THEN
      IF jsonb_typeof(v_sous) <> 'array' OR jsonb_array_length(v_sous) > 200 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      FOR v_el IN SELECT value FROM jsonb_array_elements(v_sous) LOOP
        IF jsonb_typeof(v_el) <> 'object'
           OR public.jsonb_cles_hors_liste(v_el, ARRAY['matricule','type','maitreNom','chienNom',
                'stats','buildingId','roomId','rueNoeudId','recruteLe']) IS NOT NULL
           OR COALESCE(v_el->>'type', 'standard') NOT IN ('standard','cynophile') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
        END IF;
        IF v_el ? 'stats' THEN
          -- LES SIX, pour la police comme pour la douane.
          IF jsonb_typeof(v_el->'stats') <> 'object'
             OR public.jsonb_cles_hors_liste(v_el->'stats',
                  public.pnj_caracteristiques_cles()) IS NOT NULL THEN
            RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
          END IF;
          FOR v_n IN SELECT (value#>>'{}')::numeric FROM jsonb_each(v_el->'stats') LOOP
            IF v_n < 0 OR v_n > 100 THEN
              RETURN jsonb_build_object('ok', false, 'raison', 'stat_hors_bornes');
            END IF;
          END LOOP;
        END IF;
      END LOOP;
    END IF;

  ELSIF p_sous_cle = 'blocus' THEN
    IF jsonb_typeof(p_valeur) NOT IN ('null','object') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    IF jsonb_typeof(p_valeur) = 'object' THEN
      IF public.jsonb_cles_hors_liste(p_valeur, ARRAY['syndicatId','syndicatNom','revendication',
           'nbMilitants','intensite','leaderActuel','lanceLe',
           'dernierRenouvellementTimestamp']) IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      IF COALESCE((p_valeur->>'intensite')::numeric, 0) < 0
         OR COALESCE((p_valeur->>'intensite')::numeric, 0) > 100
         OR COALESCE((p_valeur->>'nbMilitants')::numeric, 0) < 0
         OR COALESCE((p_valeur->>'nbMilitants')::numeric, 0) > 10000 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'valeur_hors_bornes');
      END IF;
      IF NOT v_serveur THEN
        p_valeur := jsonb_set(p_valeur, '{leaderActuel}', to_jsonb(v_moi));
      END IF;
    END IF;

  ELSIF p_sous_cle = 'parCaisse' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_el IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_el) <> 'number' OR (v_el#>>'{}')::numeric < 0
         OR (v_el#>>'{}')::numeric > 100 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'valeur_hors_bornes');
      END IF;
    END LOOP;

  ELSIF p_sous_cle = 'controles' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_el IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_el) <> 'object'
         OR public.jsonb_cles_hors_liste(v_el, ARRAY['resultat','controleeLe']) IS NOT NULL
         OR COALESCE(v_el->>'resultat', '') NOT IN ('positif','negatif') THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
    END LOOP;

  ELSIF p_sous_cle = 'offres' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_sous IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_sous) <> 'array' OR jsonb_array_length(v_sous) > 100 THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      FOR v_el IN SELECT value FROM jsonb_array_elements(v_sous) LOOP
        IF jsonb_typeof(v_el) <> 'object'
           OR public.jsonb_cles_hors_liste(v_el, ARRAY['pjNom','statut']) IS NOT NULL
           OR COALESCE(v_el->>'statut', '') NOT IN ('actif','en_attente_arbitrage') THEN
          RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
        END IF;
      END LOOP;
    END LOOP;

  ELSIF p_sous_cle = 'candidatures' THEN
    IF jsonb_typeof(p_valeur) <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
    END IF;
    FOR v_sous IN SELECT value FROM jsonb_each(p_valeur) LOOP
      IF jsonb_typeof(v_sous) <> 'object'
         OR public.jsonb_cles_hors_liste(v_sous, ARRAY['posteId','city','candidats',
              'echeanceTs','autoriteNom','traitee']) IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
      IF v_sous ? 'candidats' AND jsonb_typeof(v_sous->'candidats') <> 'array' THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'forme_invalide');
      END IF;
    END LOOP;
  END IF;

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.batiments_etat (id, country, city, building_id, data)
    VALUES (v_id, p_pays, p_ville, p_batiment,
            to_jsonb(jsonb_build_object(p_sous_cle, p_valeur)::text));
    RETURN jsonb_build_object('ok', true, 'valeur', p_valeur);
  END IF;

  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_etat := jsonb_set(v_etat, ARRAY[p_sous_cle], p_valeur, true);

  UPDATE public.batiments_etat
     SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'valeur', p_valeur);
END; $function$

-- eviction_indemniser(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.eviction_indemniser(p_country text, p_building_id text, p_lot_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; v_id text; v_proprio text; v_brut text; v_etat jsonb;
  v_subs jsonb; v_lot jsonb; v_reste jsonb; v_trouve boolean := false;
  v_loyer numeric; v_indemnite numeric := 0;
  v_bail record; v_occupant text := NULL;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_country),'') = '' OR COALESCE(btrim(p_building_id),'') = ''
     OR COALESCE(btrim(p_lot_id),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_id := p_country || '_' || p_building_id;
  SELECT proprietaire, data INTO v_proprio, v_brut
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable');
  END IF;

  -- AUTORITE : seul le proprietaire du terrain peut retirer un de ses lots.
  IF v_proprio IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;

  v_etat := public.terrain_etat_lire(v_brut);
  IF v_etat IS NULL OR jsonb_typeof(v_etat) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etat_illisible');
  END IF;

  -- Meme regle que le client : un batiment LIVRE ne se redecoupe pas par formulaire.
  IF COALESCE(v_etat->>'niveau_construction','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_requis');
  END IF;

  v_subs := CASE WHEN jsonb_typeof(v_etat->'subdivisions') = 'array'
                 THEN v_etat->'subdivisions' ELSE '[]'::jsonb END;

  SELECT e INTO v_lot FROM jsonb_array_elements(v_subs) e WHERE e->>'id' = p_lot_id LIMIT 1;
  IF v_lot IS NULL THEN
    -- Deja retire (rejeu, double-clic) ou identifiant inconnu.
    RETURN jsonb_build_object('ok', false, 'raison', 'lot_introuvable');
  END IF;
  v_trouve := true;

  v_loyer := GREATEST(0, COALESCE((v_lot->>'loyer')::numeric, 0));

  -- OCCUPANT : lu sur le bail, jamais fourni par l'appelant.
  SELECT * INTO v_bail FROM public.locations_actives
   WHERE country = p_country
     AND data->>'buildingId' = p_building_id
     AND data->>'lotId' = p_lot_id
   FOR UPDATE;
  IF FOUND THEN
    v_occupant := NULLIF(btrim(COALESCE(v_bail.data->>'locataire','')), '');
  END IF;

  IF v_occupant IS NOT NULL THEN
    v_indemnite := floor(v_loyer * 365);
    IF v_indemnite > 0 THEN
      PERFORM 1 FROM public.personnages_donnees WHERE name = v_occupant FOR UPDATE;
      IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'occupant_introuvable', 'occupant', v_occupant);
      END IF;
      -- Fail-closed : sans debit effectif du proprietaire, aucune eviction, aucun credit.
      IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, v_indemnite) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                                  'requis', v_indemnite);
      END IF;
      UPDATE public.personnages_donnees
         SET arg = COALESCE(arg,0) + v_indemnite, updated_at = now()
       WHERE name = v_occupant;
    END IF;
    -- Le lot disparait, donc son bail aussi (regle existante).
    DELETE FROM public.locations_actives WHERE id = v_bail.id;
  END IF;

  -- Retrait du lot, dans la meme transaction que le paiement.
  SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) INTO v_reste
    FROM jsonb_array_elements(v_subs) e WHERE e->>'id' IS DISTINCT FROM p_lot_id;
  v_etat := v_etat || jsonb_build_object('subdivisions', v_reste);

  UPDATE public.terrains_etat
     SET data = v_etat::text, updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'lot', p_lot_id, 'occupant', v_occupant,
    'indemnite', v_indemnite, 'lots_restants', jsonb_array_length(v_reste),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END;
$function$

-- prelever_loyer_bail(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.prelever_loyer_bail(p_bail_id text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bail        locations_actives%ROWTYPE;
  v_data        jsonb;
  v_locataire   text;
  v_prix        numeric;
  v_dest        jsonb;
  v_dest_type   text;
  v_pays        text;
  v_ville       text;
  v_building    text;
  v_arg         numeric;
  v_jour        text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD');
  v_cle         text;
  v_titulaire   text;
  v_orga_id     text;
  v_orga_data   text;
  v_maj         integer;
BEGIN
  SELECT *
  INTO v_bail
  FROM locations_actives
  WHERE id = p_bail_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'bail_absent';
  END IF;

  v_data      := v_bail.data;
  v_locataire := v_data ->> 'locataire';
  v_prix      := COALESCE((v_data ->> 'prix')::numeric, 0);

  -- Anti-rejeu : un seul prélèvement par bail et par jour réel.
  IF (v_data ->> 'jourPaiement') = v_jour THEN
    RETURN 'deja_preleve';
  END IF;

  -- Usages sans loyer réel.
  IF v_prix <= 0
     OR (v_data ->> 'chambreClinique') = 'true'
     OR v_locataire IS NULL
  THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;

    RETURN 'ignore_sans_loyer';
  END IF;

  -- DESTINATION ATTESTEE (20 septembre 2026). Elle n'est plus lue dans le bail --
  -- ecriture directe falsifiable -- mais DERIVEE du local, par la meme regle que le
  -- client (destinationLoyerPourLocal). Le champ destinationLoyer du bail n'est plus
  -- qu'informatif. Fail-closed inchange : pas de destination -> pas de mouvement.
  v_dest := public.bail_destination_attestee(v_data);
  IF v_dest IS NULL THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;
    RETURN 'ignore_sans_loyer';
  END IF;

  IF v_dest IS NULL OR jsonb_typeof(v_dest) = 'null' THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;

    RETURN 'ignore_sans_loyer';
  END IF;

  v_dest_type := v_dest ->> 'type';

  -- Verrou du locataire.
  SELECT arg
  INTO v_arg
  FROM personnages
  WHERE name = v_locataire
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'locataire_absent';
  END IF;

  -- Impayé.
  IF COALESCE(v_arg, 0) < v_prix THEN
    IF COALESCE((v_data ->> 'avertissement')::boolean, false) THEN
      RETURN 'expulsion_requise';
    END IF;

    UPDATE locations_actives
    SET data = v_data
      || jsonb_build_object(
           'avertissement', true,
           'jourPaiement', v_jour
         )
    WHERE id = p_bail_id;

    RETURN 'avertissement';
  END IF;

  -- Crédit de la destination.
  IF v_dest_type = 'municipal' THEN

    v_pays  := COALESCE(v_dest ->> 'pays',  v_data ->> 'country');
    v_ville := COALESCE(v_dest ->> 'ville', v_data ->> 'city');
    v_cle   := v_pays || '_' || v_ville;

    UPDATE budgets_municipaux
    SET data = jsonb_set(
                 COALESCE(data, '{}'::jsonb),
                 '{caisse}',
                 to_jsonb(
                   COALESCE((data ->> 'caisse')::numeric, 0) + v_prix
                 )
               ),
        updated_at = now()
    WHERE id = v_cle;

    GET DIAGNOSTICS v_maj = ROW_COUNT;

    IF v_maj = 0 THEN
      INSERT INTO budgets_municipaux (id, data, updated_at)
      VALUES (
        v_cle,
        jsonb_build_object('caisse', v_prix),
        now()
      );
    END IF;

  ELSIF v_dest_type = 'titulaire_murs' THEN

    -- Le titulaire explicite n'est PLUS lu : c'etait la porte par laquelle un bail
    -- falsifie redirigeait le loyer. Le proprietaire ACTUEL fait foi, toujours.
    v_titulaire := NULL;

    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      SELECT (data::jsonb ->> 'proprietaire')
      INTO v_titulaire
      FROM terrains_etat
      WHERE country = (v_data ->> 'country')
        AND building_id = (v_data ->> 'buildingId');
    END IF;

    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      RAISE EXCEPTION 'destination_introuvable';
    END IF;

    -- Organisation propriétaire.
    IF left(v_titulaire, 5) = 'orga:' THEN

      v_orga_id := substr(v_titulaire, 6);

      IF v_orga_id = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      SELECT data
      INTO v_orga_data
      FROM organisations
      WHERE id = v_orga_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      IF v_orga_data IS NULL OR btrim(v_orga_data) = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      UPDATE organisations
      SET data = jsonb_set(
                   v_orga_data::jsonb,
                   '{caisse}',
                   to_jsonb(
                     COALESCE(
                       (v_orga_data::jsonb ->> 'caisse')::numeric,
                       0
                     ) + v_prix
                   )
                 )::text
      WHERE id = v_orga_id;

    ELSE

      -- PJ propriétaire, avec compatibilité ancien format nom brut.
      IF left(v_titulaire, 3) = 'pj:' THEN
        v_titulaire := substr(v_titulaire, 4);
      END IF;

      UPDATE personnages
      SET arg = COALESCE(arg, 0) + v_prix
      WHERE name = v_titulaire;

      GET DIAGNOSTICS v_maj = ROW_COUNT;

      IF v_maj = 0 THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

    END IF;

  ELSIF v_dest_type = 'caisse_batiment' THEN

    v_building := COALESCE(
      v_dest ->> 'buildingId',
      v_data ->> 'buildingId'
    );

    v_cle := (v_data ->> 'country') || '_' || v_building;

    UPDATE caisses_batiments
    SET data = jsonb_set(
                 COALESCE(data, '{}'::jsonb),
                 '{solde}',
                 to_jsonb(
                   COALESCE((data ->> 'solde')::numeric, 0) + v_prix
                 )
               ),
        updated_at = now()
    WHERE id = v_cle;

    GET DIAGNOSTICS v_maj = ROW_COUNT;

    IF v_maj = 0 THEN
      INSERT INTO caisses_batiments (id, data, updated_at)
      VALUES (
        v_cle,
        jsonb_build_object('solde', v_prix),
        now()
      );
    END IF;

  ELSE
    RAISE EXCEPTION 'destination_introuvable';
  END IF;

  -- Débit du locataire seulement après crédit valide.
  UPDATE personnages
  SET arg = COALESCE(arg, 0) - v_prix
  WHERE name = v_locataire;

  UPDATE locations_actives
  SET data = (v_data - 'avertissement')
    || jsonb_build_object(
         'jourPaiement', v_jour,
         'dernierLoyerPaye', v_jour
       )
  WHERE id = p_bail_id;

  RETURN 'paye';
END;
$function$

-- resilier_bail_volontaire(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.resilier_bail_volontaire(p_bail_id text, p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_bail_id, '') = '' OR COALESCE(p_acteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  RETURN terminer_bail(p_bail_id, 'resiliation_volontaire', p_acteur, 0);
END;
$function$

-- terminer_bail(text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.terminer_bail(p_bail_id text, p_cause text, p_acteur text, p_indemnite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bail jsonb;
  v_fonds_id text;
  v_fonds jsonb;
  v_prop text;
  v_ind integer := GREATEST(0, COALESCE(p_indemnite, 0));
  v_terrain text;
  v_locataire text;
BEGIN
  IF COALESCE(p_bail_id, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF p_cause NOT IN ('resiliation_volontaire', 'accord_amiable', 'eviction_judiciaire', 'succession_sans_heritier') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cause_invalide');
  END IF;
  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN RETURN jsonb_build_object('ok', true, 'deja_termine', true); END IF;
  v_locataire := v_bail ->> 'locataire';
  IF p_cause = 'resiliation_volontaire' THEN
    IF COALESCE(p_acteur, '') = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_requis'); END IF;
    IF v_locataire IS DISTINCT FROM p_acteur AND ('pj:' || COALESCE(v_locataire, '')) IS DISTINCT FROM p_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_titulaire');
    END IF;
  END IF;
  v_terrain := (v_bail ->> 'country') || '_' || (v_bail ->> 'buildingId');
  SELECT (data::jsonb ->> 'proprietaire') INTO v_prop FROM terrains_etat WHERE id = v_terrain;
  IF p_cause = 'accord_amiable' AND v_ind > 0 THEN
    IF COALESCE(v_prop, '') = '' THEN RAISE EXCEPTION 'bailleur_introuvable'; END IF;
    IF NOT mouvement_titulaire(v_prop, -v_ind) THEN RETURN jsonb_build_object('ok', false, 'raison', 'bailleur_insolvable'); END IF;
    IF NOT mouvement_titulaire(COALESCE(v_bail ->> 'locataireRef', v_locataire), v_ind) THEN RAISE EXCEPTION 'locataire_introuvable'; END IF;
  END IF;
  v_fonds_id := v_bail ->> 'fondsId';
  IF COALESCE(v_fonds_id, '') <> '' THEN
    SELECT data INTO v_fonds FROM entreprises WHERE id = v_fonds_id FOR UPDATE;
    IF v_fonds IS NOT NULL AND COALESCE((v_fonds ->> 'version')::integer, 0) >= 2 THEN
      v_fonds := jsonb_set(v_fonds, '{statut}', to_jsonb('abandonne'::text));
      v_fonds := jsonb_set(v_fonds, '{historique}', COALESCE(v_fonds -> 'historique', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
          'evenement', 'bail_termine', 'cause', p_cause,
          'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));
      UPDATE entreprises SET data = v_fonds, updated_at = now() WHERE id = v_fonds_id;
    END IF;
  END IF;
  INSERT INTO locations_archives (id, bail_id, country, city, building_id, room_id, lot_id, locataire, proprietaire_murs, loyer, debut, fin_cause, fonds_id, indemnite, data)
  VALUES (
    'bail-' || p_bail_id || '-' || extract(epoch from now())::bigint,
    p_bail_id, v_bail ->> 'country', v_bail ->> 'city', v_bail ->> 'buildingId', v_bail ->> 'roomId', v_bail ->> 'lotId', v_locataire, v_prop,
    GREATEST(0, COALESCE((v_bail ->> 'prix')::numeric, 0))::integer,
    NULLIF(v_bail ->> 'depuis', '')::integer, p_cause, NULLIF(v_fonds_id, ''), v_ind,
    jsonb_build_object('bail', v_bail, 'acteur', p_acteur));
  DELETE FROM locations_actives WHERE id = p_bail_id;
  RETURN jsonb_build_object('ok', true, 'deja_termine', false, 'cause', p_cause, 'fondsId', COALESCE(v_fonds_id, ''), 'indemnite', v_ind, 'proprietaireMurs', COALESCE(v_prop, ''));
END;
$function$

-- terrain_etat_lire(text) -> jsonb | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.terrain_etat_lire(p_data text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN p_data::jsonb;
EXCEPTION WHEN others THEN RETURN NULL;
END; $function$
