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

-- achat_direct_manque_resoudre(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.achat_direct_manque_resoudre(p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cle text; v_pays text; v_bat text; v_data jsonb; v_ad jsonb;
  v_jour text := to_char((now() AT TIME ZONE 'Europe/Paris')::date, 'YYYY-MM-DD');
  v_n integer;
BEGIN
  SELECT t.id, t.country, t.building_id, t.data::jsonb
    INTO v_cle, v_pays, v_bat, v_data
    FROM public.terrains_etat t WHERE t.id = p_terrain_id FOR UPDATE;
  IF v_cle IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable');
  END IF;
  v_data := coalesce(v_data, '{}'::jsonb);
  v_ad := v_data -> 'achatDirect';
  IF v_ad IS NULL OR jsonb_typeof(v_ad) <> 'object' OR (v_ad ->> 'dateLimite') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucun_achat_direct');
  END IF;

  -- MEME CONDITION D'ECHEANCE QU'AVANT : dateLimite est un horodatage en millisecondes.
  IF (v_ad ->> 'dateLimite')::numeric >= (extract(epoch from now()) * 1000) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_echu');
  END IF;

  -- L'IDENTIFIANT EST DATE, PLUS HORODATE A LA MILLISECONDE. Deux gardes pour le meme rejeu :
  -- la cle primaire, et l'index unique (pays, bien, resultat, journee).
  INSERT INTO public.compromis_historique (id, country, building_id, demandeur, resultat, detail)
  VALUES ('achatdirect-' || v_cle || '-' || v_jour, v_pays, v_bat,
          coalesce(nullif(v_ad ->> 'demandeur', ''), 'inconnu'), 'perdu',
          'Rendez-vous notarial manqué (dépôt de '
            || coalesce(v_ad ->> 'acompte', '0') || ' FR perdu)')
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- LA PURGE, DANS LA MEME TRANSACTION QUE LA CONSIGNATION.
  UPDATE public.terrains_etat
     SET data = (v_data - 'achatDirect')::text, updated_at = now()
   WHERE id = v_cle;

  RETURN jsonb_build_object('ok', true, 'consigne', v_n = 1, 'jour', v_jour,
                            'demandeur', v_ad ->> 'demandeur');
END; $function$;

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
$function$;

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
$function$;

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
$function$;

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
$function$;

-- bail_je_suis_locataire(jsonb) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bail_je_suis_locataire(p_data jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce(p_data ->> 'locataire', '') = coalesce(public.mon_personnage(), '\x00'); $function$;

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
$function$;

-- batiment_caisse_client_crediter(text,text,text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.batiment_caisse_client_crediter(p_pays text, p_ville text, p_building text, p_souscle text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF p_pays IS DISTINCT FROM v_pays THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_hors_pays'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant > 100000000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  IF NOT public.fonds_transit_consommer_interne(v_moi, p_montant) THEN
    INSERT INTO public.caisses_mouvements_clients (acteur, caisse, delta, motif, accepte, raison)
    VALUES (v_moi, p_pays || '_' || p_ville || '_' || p_building || '/' || p_souscle, p_montant, 'batiment', false, 'credit_non_adosse');
    RETURN jsonb_build_object('ok', false, 'raison', 'credit_non_adosse');
  END IF;
  v_res := public.batiment_caisse_mouvement(p_pays, p_ville, p_building, p_souscle, p_montant, NULL, 0, NULL, true);
  IF NOT coalesce((v_res ->> 'ok')::boolean, false) THEN
    PERFORM public.fonds_transit_deposer_interne(v_moi, p_montant, 'rendu:batiment');
  END IF;
  RETURN v_res;
END; $function$;

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
$function$;

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
$function$;

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

  -- nominations_municipales_entrepot : garde apres verrou, avant toute ecriture.
  IF NOT v_serveur AND p_sous_cle = 'candidatures'
     AND NOT public.candidature_entrepot_modification_autorisee(p_pays,
       coalesce(public.batiment_etat_lire(v_data) -> 'candidatures', '{}'::jsonb), p_valeur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;


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
END; $function$;

-- bne_annonce_publier(text,text,text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bne_annonce_publier(p_intitule text, p_descriptif text, p_lieu text, p_salaire text, p_presse boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_ville text; v_paie jsonb; v_id uuid;
  v_int text := btrim(coalesce(p_intitule, '')); v_desc text := btrim(coalesce(p_descriptif, ''));
  v_lieu text := btrim(coalesce(p_lieu, '')); v_sal text := btrim(coalesce(p_salaire, ''));
  v_presse boolean := coalesce(p_presse, false); v_caisse text; v_nom_lieu text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'), coalesce(current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;

  IF char_length(v_int) NOT BETWEEN 1 AND 80 THEN RETURN jsonb_build_object('ok', false, 'raison', 'intitule_invalide'); END IF;
  IF char_length(v_desc) NOT BETWEEN 1 AND 600 THEN RETURN jsonb_build_object('ok', false, 'raison', 'descriptif_invalide'); END IF;
  IF char_length(v_sal) NOT BETWEEN 1 AND 60 THEN RETURN jsonb_build_object('ok', false, 'raison', 'salaire_invalide'); END IF;
  IF v_lieu NOT IN ('capitale', 'ville_a', 'ville_b', 'international') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'lieu_invalide');
  END IF;

  IF v_presse AND EXISTS (SELECT 1 FROM public.petites_annonces
                           WHERE auteur = v_moi AND statut = 'active' AND expire_at > now()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'annonce_presse_deja_active');
  END IF;

  v_paie := public.payer_ordre(v_moi,
              CASE WHEN v_presse THEN 'bne_passer_annonce_presse' ELSE 'bne_passer_annonce' END,
              1, CASE WHEN v_presse THEN 30 ELSE 0 END);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;

  INSERT INTO public.bne_annonces (pays, auteur, intitule, descriptif, lieu, salaire, presse, expire_le)
  VALUES (v_pays, v_moi, v_int, v_desc, v_lieu, v_sal, v_presse, now() + interval '7 days')
  RETURNING id INTO v_id;

  IF v_presse THEN
    v_nom_lieu := CASE v_lieu WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie'
                              WHEN 'ville_b' THEN 'Montrouge' ELSE 'à l''international' END;
    INSERT INTO public.petites_annonces (id, country, ville_depot, auteur, categorie, texte,
                                         cout_paye, duree_jours, expire_at, statut)
    VALUES ('annonce-bne-' || replace(v_id::text, '-', ''), v_pays, v_ville, v_moi, 'Emploi',
            left(v_int || ' — ' || v_desc || ' — Lieu : ' || v_nom_lieu || ' — Salaire : ' || v_sal
                 || ' — Contact : ' || v_moi || ' (via le Bureau de l''Emploi)', 900),
            30, 3, now() + interval '3 days', 'active');
    v_caisse := v_pays || '_bureau-national-emploi';
    INSERT INTO public.caisses_batiments (id, data, updated_at)
    VALUES (v_caisse, jsonb_build_object('solde', 30), now())
    ON CONFLICT (id) DO UPDATE
       SET data = coalesce(public.caisses_batiments.data, '{}'::jsonb)
                  || jsonb_build_object('solde', coalesce((public.caisses_batiments.data ->> 'solde')::numeric, 0) + 30),
           updated_at = now();
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'presse', v_presse,
                            'pa', v_paie -> 'pa', 'paiement', v_paie, 'expire_le', now() + interval '7 days');
END; $function$;

-- bne_annonce_retirer(uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bne_annonce_retirer(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.bne_annonces SET statut = 'retiree'
   WHERE id = p_id AND auteur = v_moi AND statut = 'active';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'annonce_introuvable'); END IF;
  RETURN jsonb_build_object('ok', true);
END; $function$;

-- bne_annonces_lister() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bne_annonces_lister()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  RETURN jsonb_build_object('ok', true, 'annonces', coalesce((
    SELECT jsonb_agg(jsonb_build_object('id', a.id, 'auteur', a.auteur, 'intitule', a.intitule,
             'descriptif', a.descriptif, 'lieu', a.lieu, 'salaire', a.salaire, 'presse', a.presse,
             'cree_le', a.cree_le, 'expire_le', a.expire_le, 'de_moi', a.auteur = v_moi)
             ORDER BY a.cree_le DESC)
      FROM public.bne_annonces a
     WHERE a.pays = v_pays AND a.statut = 'active' AND a.expire_le > now()), '[]'::jsonb));
END; $function$;

-- bne_caisse_lire() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bne_caisse_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_bne numeric; v_min numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_fin', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_finances'); END IF;
  SELECT CASE WHEN jsonb_typeof(data -> 'solde') = 'number' THEN (data ->> 'solde')::numeric ELSE 0 END INTO v_bne
    FROM public.caisses_batiments WHERE id = v_pays || '_bureau-national-emploi';
  SELECT CASE WHEN jsonb_typeof(data -> 'solde') = 'number' THEN (data ->> 'solde')::numeric ELSE 0 END INTO v_min
    FROM public.caisses_batiments WHERE id = v_pays || '_gouvernement-min_fin';
  RETURN jsonb_build_object('ok', true, 'solde_bne', coalesce(v_bne, 0), 'solde_ministere', coalesce(v_min, 0));
END; $function$;

-- bne_caisse_prelever(numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bne_caisse_prelever(p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_src text; v_dst text; v_data jsonb; v_solde numeric; v_paie jsonb; v_min numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  IF NOT public.mon_poste_est_dans('min_fin', v_pays) THEN RETURN jsonb_build_object('ok', false, 'raison', 'reserve_ministre_finances'); END IF;
  IF p_montant IS NULL OR p_montant <= 0 OR p_montant <> trunc(p_montant) OR p_montant > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide'); END IF;
  v_src := v_pays || '_bureau-national-emploi';
  v_dst := v_pays || '_gouvernement-min_fin';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_src FOR UPDATE;
  v_solde := CASE WHEN jsonb_typeof(v_data -> 'solde') = 'number' THEN (v_data ->> 'solde')::numeric ELSE 0 END;
  IF coalesce(v_solde, 0) < p_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'solde_insuffisant', 'solde', coalesce(v_solde, 0)); END IF;
  v_paie := public.payer_ordre(v_moi, 'bne_caisse_prelever', 1, 0);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  UPDATE public.caisses_batiments SET data = coalesce(data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - p_montant),
         updated_at = now() WHERE id = v_src;
  INSERT INTO public.caisses_batiments (id, data, updated_at)
  VALUES (v_dst, jsonb_build_object('solde', p_montant), now())
  ON CONFLICT (id) DO UPDATE
     SET data = coalesce(public.caisses_batiments.data, '{}'::jsonb)
              || jsonb_build_object('solde', coalesce(CASE WHEN jsonb_typeof(public.caisses_batiments.data -> 'solde') = 'number'
                                                           THEN (public.caisses_batiments.data ->> 'solde')::numeric END, 0) + p_montant),
         updated_at = now()
  RETURNING (data ->> 'solde')::numeric INTO v_min;
  RETURN jsonb_build_object('ok', true, 'montant', p_montant, 'solde_bne', v_solde - p_montant,
                            'solde_ministere', v_min, 'paie', v_paie);
END; $function$;

-- bne_heures_chantiers() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bne_heures_chantiers()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_ville text; t record; v_data jsonb; v_ch jsonb; v_besoin record;
  v_jour_num integer; v_fraction numeric; v_capacite numeric; v_plafond numeric; v_utiles numeric;
  v_restantes numeric; v_taux numeric; v_min numeric; v_taux_paye numeric; v_payables numeric;
  v_stock jsonb; v_m text; v_req numeric; v_dispo numeric; v_res jsonb := '[]'::jsonb; v_heures numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic'), coalesce(current_city, 'capitale') INTO v_pays, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;
  SELECT valeur INTO v_taux FROM public.entreprises_constantes WHERE cle = 'chantier_taux_horaire';
  SELECT valeur INTO v_min FROM public.entreprises_constantes WHERE cle = 'chantier_salaire_minimum';
  IF coalesce(v_taux, 0) <= 0 THEN RETURN jsonb_build_object('ok', true, 'chantiers', '[]'::jsonb); END IF;

  FOR t IN SELECT id, building_id, data FROM public.terrains_etat WHERE country = v_pays LOOP
    v_data := public.terrain_etat_lire(t.data);
    CONTINUE WHEN v_data IS NULL OR coalesce(v_data ->> 'city', 'capitale') <> v_ville
              OR coalesce(v_data ->> 'succession_gel', '') <> '';
    v_ch := CASE WHEN jsonb_typeof(v_data -> 'chantier') = 'object' THEN v_data -> 'chantier'
                 ELSE v_data -> 'chantierReamenagement' END;
    CONTINUE WHEN v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object'
              OR coalesce(v_ch ->> 'type', '') NOT IN ('construction', 'reamenagement')
              OR v_ch ->> 'arrete' = 'financement';
    v_jour_num := floor(GREATEST(0, COALESCE((v_ch ->> 'progressionJours')::numeric, 0)))::integer + 1;
    SELECT (x ->> 'bois')::numeric AS bois, (x ->> 'minerai')::numeric AS minerai, (x ->> 'metal')::numeric AS metal
      INTO v_besoin FROM (SELECT public.chantier_besoin_jour_interne(v_ch, v_jour_num) AS x) b;
    CONTINUE WHEN NOT FOUND;
    v_fraction := 1;
    v_stock := COALESCE(v_ch -> 'stockMateriaux', '{}'::jsonb);
    FOR v_m, v_req IN SELECT * FROM (VALUES ('bois', v_besoin.bois), ('minerai', v_besoin.minerai),
                                            ('metal', v_besoin.metal)) AS z(m, r) LOOP
      IF v_req > 0 THEN
        v_dispo := GREATEST(0, COALESCE((v_stock ->> v_m)::numeric, 0));
        v_fraction := LEAST(v_fraction, LEAST(1, GREATEST(0, v_dispo / v_req)));
      END IF;
    END LOOP;
    v_capacite := CASE WHEN COALESCE((v_ch ->> 'dureeJours')::numeric, 0) > 0
                       THEN (COALESCE((v_ch ->> 'coutTravail')::numeric, 0) / v_taux) / (v_ch ->> 'dureeJours')::numeric
                       ELSE 0 END;
    v_plafond := CASE WHEN (v_ch ->> 'totalVerse')::numeric >= (v_ch ->> 'coutTotal')::numeric THEN (v_ch ->> 'dureeJours')::numeric
                      WHEN (v_ch ->> 'totalVerse')::numeric >= ceil((v_ch ->> 'coutTotal')::numeric * .7) THEN (v_ch ->> 'dureeJours')::numeric * 2 / 3
                      WHEN (v_ch ->> 'totalVerse')::numeric >= ceil((v_ch ->> 'coutTotal')::numeric * .35) THEN (v_ch ->> 'dureeJours')::numeric / 3
                      ELSE 0 END;
    v_utiles := floor(v_capacite * least(v_fraction, greatest(0, v_plafond - coalesce((v_ch ->> 'progressionJours')::numeric, 0))));
    v_restantes := GREATEST(0, v_utiles - GREATEST(0, COALESCE((v_ch ->> 'heuresFaites')::numeric, 0)));
    v_taux_paye := GREATEST(COALESCE((v_ch ->> 'tauxHoraire')::numeric, v_taux), COALESCE(v_min, 50));
    v_payables := floor(GREATEST(0, COALESCE((v_ch ->> 'tresorerie')::numeric, 0)) / v_taux_paye);
    v_heures := LEAST(v_restantes, v_payables);
    CONTINUE WHEN v_heures <= 0;
    v_res := v_res || jsonb_build_array(jsonb_build_object(
      'terrain', t.building_id, 'type', v_ch ->> 'type', 'niveau', v_ch ->> 'niveau',
      'taux', v_taux_paye, 'heures', v_heures));
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'ville', v_ville, 'chantiers', v_res);
END; $function$;

-- bne_postes_a_pourvoir() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.bne_postes_a_pourvoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_postes jsonb; v_armee jsonb;
  -- Postes metier, justice, police. JAMAIS un poste politique (decision de Fred, 25/10).
  v_metier text[] := ARRAY['directeur_entrepot','directeur_raffinerie','directeur_pharma',
                           'directeur_tabac_alcools','capitaine_port','chef_douanes',
                           'juge','procureur','commissaire','commandant'];
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'poste', z.poste_id, 'label', z.label, 'ville', z.ville, 'pnj', z.nom_pnj,
           'recruteur', z.recruteur, 'portee', z.scope)
         ORDER BY array_position(v_metier, z.poste_id), z.ville NULLS FIRST), '[]'::jsonb)
    INTO v_postes
    FROM (
      SELECT r.poste_id, r.label, r.scope, t.nom_pnj,
             CASE WHEN r.scope = 'ville'
                  THEN substr(t.id, length(v_pays || '_' || r.poste_id || '_') + 1) END AS ville,
             r.nomme_par AS recruteur
        FROM public.postes_nommes_regles r
        JOIN public.titulaires_pnj t
          ON (r.scope = 'ville' AND t.id LIKE v_pays || '\_' || r.poste_id || '\_%')
          OR (r.scope = 'pays' AND t.id IN (v_pays || '_' || r.poste_id || '_national',
                                            v_pays || '_' || r.poste_id))
       WHERE r.poste_id = ANY (v_metier)
    ) z
   WHERE NOT EXISTS (
     SELECT 1 FROM public.postes_attribues a
      WHERE a.country = v_pays AND a.poste_id = z.poste_id
        AND a.city IS NOT DISTINCT FROM z.ville
        AND EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = a.titulaire));

  SELECT jsonb_build_object(
    'capitaines', coalesce(sum(CASE WHEN coalesce(c.data ->> 'capitaineNom', '') = '' THEN 1 ELSE 0 END), 0),
    'lieutenants', coalesce(sum((SELECT count(*) FROM jsonb_array_elements(coalesce(c.data -> 'sections', '[]'::jsonb)) s
                                  WHERE coalesce(s ->> 'lieutenantNom', '') = ''
                                    AND jsonb_array_length(coalesce(s -> 'soldats', '[]'::jsonb)) > 0)), 0),
    'soldats', coalesce(sum((SELECT count(*) FROM jsonb_array_elements(coalesce(c.data -> 'sections', '[]'::jsonb)) s,
                                    jsonb_array_elements(coalesce(s -> 'soldats', '[]'::jsonb)) sol
                              WHERE NOT coalesce((sol ->> 'pj')::boolean, false))), 0),
    'compagnies', count(*))
    INTO v_armee
    FROM public.compagnies_militaires c
   WHERE c.data ->> 'pays' = v_pays;

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'postes', v_postes, 'armee', v_armee);
END; $function$;

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
$function$;

-- local_louer(uuid,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.local_louer(p_requete uuid, p_orga text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; ref public.locaux_loyers_referentiel; a record;
  k text; bail jsonb; r jsonb; v text; orga text := nullif(btrim(coalesce(p_orga,'')),'');
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  SELECT * INTO a FROM public.locations_recus WHERE acteur = moi AND requete = p_requete;
  IF FOUND THEN RETURN a.resultat || jsonb_build_object('rejeu',true); END IF;
  IF coalesce(p.hp,0) <= 0 OR EXISTS(SELECT 1 FROM public.detention_active(moi))
     OR coalesce(p.hospitalisation->>'dateFinParis','') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible'); END IF;
  ref := public.local_referentiel_interne(p.current_building, p.current_room, p.current_city);
  IF ref.batiment IS NULL OR NOT ref.louable OR NOT ref.signature_serveur THEN RETURN jsonb_build_object('ok',false,'raison','pas_un_local_a_louer'); END IF;
  k := coalesce(p.country,'republic')||':'||p.current_building||':'||p.current_room||':'||p.current_city;
  PERFORM 1 FROM public.locations_actives WHERE id = k OR id LIKE k||':%' FOR UPDATE;
  IF FOUND THEN RETURN jsonb_build_object('ok',false,'raison','local_occupe'); END IF;
  IF orga IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.organisations o WHERE o.id = orga
       AND (o.data::jsonb->>'chef' = moi OR EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(o.data::jsonb->'membres')='array' THEN o.data::jsonb->'membres' ELSE '[]' END) m WHERE m->>'nom' = moi))) THEN
    RETURN jsonb_build_object('ok',false,'raison','orga_non_membre'); END IF;
  BEGIN
    r := public.payer_ordre(moi, 'louer_local', 1, 0);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0190', MESSAGE=coalesce(r->>'raison','paiement_refuse'); END IF;
    bail := jsonb_build_object('country',coalesce(p.country,'republic'),'city',p.current_city,'buildingId',p.current_building,
      'roomId',p.current_room,'localKey',coalesce(p.country,'republic')||'|'||p.current_city||'|'||p.current_building||'|'||p.current_room,
      'lotId',NULL,'localLabel',ref.label,'batimentLabel',p.current_building,'prix',ref.prix,'bonusPOP',ref.bonus_pop,
      'bonusINF',ref.bonus_inf,'bonusDIS',ref.bonus_dis,'orgaId',coalesce(orga,''),'orgaAutorisee',true,'locataire',moi,
      'depuis',coalesce(p.day,1),'visible',true,
      'destinationLoyer',jsonb_build_object('type','municipal','pays',coalesce(p.country,'republic'),'ville',p.current_city));
    INSERT INTO public.locations_actives(id,country,data) VALUES (k, coalesce(p.country,'republic'), bail);
    v := public.prelever_loyer_bail(k);
    IF v IS DISTINCT FROM 'paye' THEN RAISE EXCEPTION USING ERRCODE='P0190', MESSAGE='fonds_insuffisants'; END IF;
  EXCEPTION WHEN SQLSTATE 'P0190' THEN
    RETURN jsonb_build_object('ok',false,'raison',SQLERRM,'loyer',ref.prix);
  END;
  SELECT jsonb_build_object('ok',true,'bail',l.data,'bailId',k,'loyer',ref.prix,'pa',d.pa,'arg',d.arg,'liquide',d.liquide,
           'solde_national',(SELECT solde FROM public.comptes_bancaires WHERE personnage=moi AND banque='nationale' LIMIT 1))
    INTO r FROM public.locations_actives l, public.personnages_donnees d WHERE l.id = k AND d.name = moi;
  INSERT INTO public.locations_recus VALUES (moi, p_requete, k, r - 'pa' - 'arg' - 'liquide' - 'solde_national');
  RETURN r;
END;
$function$;

-- local_referentiel_interne(text,text,text) -> locaux_loyers_referentiel | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.local_referentiel_interne(p_batiment text, p_piece text, p_ville text)
 RETURNS locaux_loyers_referentiel
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT * FROM public.locaux_loyers_referentiel
       WHERE batiment = p_batiment AND piece = p_piece AND ville IN (p_ville, '*')
       ORDER BY (ville = '*') LIMIT 1 $function$;

-- location_local_creation_serveur() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.location_local_creation_serveur()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ref public.locaux_loyers_referentiel;
BEGIN
  IF public.est_appel_serveur() OR NEW.data IS NULL THEN RETURN NEW; END IF;
  ref := public.local_referentiel_interne(NEW.data->>'buildingId', NEW.data->>'roomId', NEW.data->>'city');
  IF ref.batiment IS NOT NULL AND ref.signature_serveur THEN
    RAISE EXCEPTION 'bail_signe_par_le_serveur' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

-- location_local_tarif_attester() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.location_local_tarif_attester()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ref public.locaux_loyers_referentiel;
BEGIN
  IF public.est_appel_serveur() OR NEW.data IS NULL THEN RETURN NEW; END IF;
  ref := public.local_referentiel_interne(NEW.data->>'buildingId', NEW.data->>'roomId', NEW.data->>'city');
  IF ref.batiment IS NULL THEN RETURN NEW; END IF;
  IF NOT ref.louable THEN RAISE EXCEPTION 'pas_un_local_a_louer' USING ERRCODE = '42501'; END IF;
  NEW.data := NEW.data || jsonb_build_object('prix',ref.prix,'bonusPOP',ref.bonus_pop,'bonusINF',ref.bonus_inf,
                'bonusDIS',ref.bonus_dis);
  RETURN NEW;
END;
$function$;

-- location_lot_ecriture_attester() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.location_lot_ecriture_attester()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE e jsonb;h jsonb;t jsonb;
BEGIN
 IF public.est_appel_serveur() THEN RETURN NEW;END IF;
 IF EXISTS(SELECT 1 FROM public.logements_sociaux_internes x WHERE x.transaction_id=txid_current() AND x.bail_id=NEW.id) THEN RETURN NEW;END IF;
 IF left(coalesce(NEW.data->>'roomId',''),8)<>'lot_dyn_' AND (TG_OP='INSERT' OR left(coalesce(OLD.data->>'roomId',''),8)<>'lot_dyn_') THEN RETURN NEW;END IF;
 -- L'option d'affichage du locataire reste modifiable ; aucun montant ni jour de paiement.
 IF TG_OP='UPDATE' AND (NEW.id,NEW.country,NEW.data-'visible') IS NOT DISTINCT FROM (OLD.id,OLD.country,OLD.data-'visible') THEN RETURN NEW;END IF;
 IF EXISTS(SELECT 1 FROM public.chantier_commandes_recus r JOIN public.personnages_donnees p ON p.id=r.personnage_id
  WHERE p.name=public.mon_personnage() AND r.acteur=p.name AND r.commande->>'action'='louer'
   AND r.resultat->>'transaction_id'=txid_current()::text AND r.resultat->>'bail_id'=NEW.id AND r.resultat->>'interne'='location_lot') THEN RETURN NEW;END IF;
 -- Les moteurs existants de creation/vente du fonds mettent a jour le meme bail.
 -- Ils sont attestes par l'entreprise canonique, jamais par les champs envoyes au bail.
 IF TG_OP='UPDATE' THEN
  SELECT data INTO e FROM public.entreprises WHERE id=NEW.data->>'fondsId' AND coalesce((data->>'version')::integer,0)>=2 AND data->>'type'='fonds_commerce'
   AND coalesce(data->>'statut','actif')='actif' AND data->'implantation'->>'bailId'=NEW.id
   AND data->'implantation'->>'country'=NEW.country AND data->'implantation'->>'city'=NEW.data->>'city'
   AND data->'implantation'->>'buildingId'=NEW.data->>'buildingId' AND data->'implantation'->>'roomId'=NEW.data->>'roomId' FOR SHARE;
  IF e IS NOT NULL AND regexp_replace(e->>'proprietaire','^pj:','')=regexp_replace(coalesce(NEW.data->>'locataireRef',NEW.data->>'locataire'),'^pj:','') THEN
   IF (NEW.id,NEW.country,NEW.data-ARRAY['visible','fondsId']) IS NOT DISTINCT FROM (OLD.id,OLD.country,OLD.data-ARRAY['visible','fondsId']) THEN RETURN NEW;END IF;
   h:=e->'historique'->-1;t:=NEW.data->'transferts'->-1;
   IF (NEW.id,NEW.country,NEW.data-ARRAY['locataire','locataireRef','transferts']) IS NOT DISTINCT FROM (OLD.id,OLD.country,OLD.data-ARRAY['locataire','locataireRef','transferts'])
    AND h->>'evenement'='vente' AND t->>'cause'='vente_fonds' AND t->>'de'=h->>'vendeur' AND t->>'vers'=h->>'acheteur'
    AND regexp_replace(h->>'vendeur','^pj:','')=regexp_replace(coalesce(OLD.data->>'locataireRef',OLD.data->>'locataire'),'^pj:','')
    AND regexp_replace(h->>'acheteur','^pj:','')=regexp_replace(coalesce(NEW.data->>'locataireRef',NEW.data->>'locataire'),'^pj:','')
    AND jsonb_array_length(NEW.data->'transferts')=jsonb_array_length(coalesce(OLD.data->'transferts','[]'))+1
    AND (NEW.data->'transferts')- (jsonb_array_length(NEW.data->'transferts')-1)=coalesce(OLD.data->'transferts','[]') THEN RETURN NEW;END IF;
  END IF;
 END IF;
 RAISE EXCEPTION 'location_commande_versionnee_requise' USING ERRCODE='42501';
END;$function$;

-- location_lot_enregistrer_interne(jsonb,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.location_lot_enregistrer_interne(p_etat jsonb, p_pays text, p_batiment text, p_lot text, p_acteur text, p_jour integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE lot jsonb;nouveau jsonb;lots jsonb:='[]';piece text;idb text;bail jsonb;r text;loyer numeric;
BEGIN
 SELECT value INTO lot FROM jsonb_array_elements(coalesce(p_etat->'subdivisions','[]')) WHERE value->>'id'=p_lot;
 IF lot IS NULL OR (SELECT count(*) FROM jsonb_array_elements(coalesce(p_etat->'subdivisions','[]')) WHERE value->>'id'=p_lot)<>1 OR nullif(p_etat->>'niveau_construction','') IS NULL THEN RAISE EXCEPTION 'lot_introuvable';END IF;
 IF nullif(lot->>'proprietaire','') IS NOT NULL AND lot->>'proprietaire' IS DISTINCT FROM p_etat->>'proprietaire' THEN RAISE EXCEPTION 'lot_vendu';END IF;
 IF nullif(lot->>'locataire','') IS NOT NULL THEN RAISE EXCEPTION 'local_occupe';END IF;
 IF p_etat->'chantierReamenagement'->'lotsConcernes' ? p_lot THEN RAISE EXCEPTION 'lot_en_travaux';END IF;
 loyer:=(lot->>'loyer')::numeric;
 IF coalesce(loyer,0)=0 THEN RAISE EXCEPTION 'loyer_non_fixe';END IF;
 IF loyer IS NULL OR loyer<0 OR loyer<>trunc(loyer) OR loyer::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'loyer_invalide';END IF;
 piece:='lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g');idb:=p_pays||':'||p_batiment||':'||piece||':'||(p_etat->>'city');
 IF lot->>'destination'='logement_social' AND NOT EXISTS(SELECT 1 FROM public.logements_sociaux_internes x WHERE x.transaction_id=txid_current() AND x.bail_id=idb) THEN RAISE EXCEPTION 'logement_attribue_par_adjoint';END IF;
 IF EXISTS(SELECT 1 FROM public.locations_actives WHERE id=idb OR country=p_pays AND data->>'city'=p_etat->>'city' AND data->>'buildingId'=p_batiment AND data->>'roomId'=piece) THEN RAISE EXCEPTION 'local_occupe';END IF;
 bail:=jsonb_build_object('country',p_pays,'city',p_etat->>'city','buildingId',p_batiment,'roomId',piece,'lotId',p_lot,'localKey',p_pays||'|'||(p_etat->>'city')||'|'||p_batiment||'|'||piece,'localLabel',lot->>'label','batimentLabel',p_batiment,'prix',loyer,'bonusPOP',0,'bonusINF',0,'bonusDIS',0,'orgaId','','orgaAutorisee',true,'locataire',p_acteur,'depuis',p_jour,'visible',true,'destinationLoyer',public.bail_destination_attestee(jsonb_build_object('roomId',piece)));
 INSERT INTO public.locations_actives(id,country,data) VALUES(idb,p_pays,bail);
 r:=public.prelever_loyer_bail(idb);
 IF r NOT IN('paye','ignore_sans_loyer') THEN RAISE EXCEPTION 'premier_loyer_refuse';END IF;
 FOR nouveau IN SELECT value FROM jsonb_array_elements(p_etat->'subdivisions') LOOP
  lots:=lots||jsonb_build_array(CASE WHEN nouveau->>'id'=p_lot THEN nouveau||jsonb_build_object('locataire',p_acteur) ELSE nouveau END);
 END LOOP;
 RETURN p_etat||jsonb_build_object('subdivisions',lots,'lotsHistorique',coalesce(p_etat->'lotsHistorique','[]')||jsonb_build_array(jsonb_build_object('acte','location','acteur',p_acteur,'lot',p_lot,'bail',idb,'premierLoyer',loyer,'date',statement_timestamp())));
END;$function$;

-- logement_historique_attribuer_interne(text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logement_historique_attribuer_interne(p_moi text, p_ville text, p_batiment text, p_piece text, p_demande text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE h public.logements_sociaux_historiques; v_pays text; dm record; idb text; jour int; v text;
BEGIN
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_moi;
  SELECT * INTO h FROM public.logements_sociaux_historiques x WHERE x.pays = v_pays AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','logement_introuvable'); END IF;
  IF h.ville IS DISTINCT FROM p_ville THEN RETURN jsonb_build_object('ok',false,'raison','hors_commune'); END IF;
  SELECT * INTO dm FROM public.logements_demandes WHERE id = p_demande FOR UPDATE;
  IF NOT FOUND OR dm.statut <> 'en_attente' OR dm.country <> h.pays OR dm.ville <> h.ville THEN RETURN jsonb_build_object('ok',false,'raison','demande_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees r WHERE r.name = dm.demandeur AND r.domicile->>'country' = h.pays AND r.domicile->>'city' = h.ville) THEN
    RETURN jsonb_build_object('ok',false,'raison','demandeur_non_resident'); END IF;
  idb := h.pays||':'||h.batiment||':'||h.piece||':'||h.ville;
  IF EXISTS (SELECT 1 FROM public.locations_actives WHERE id = idb) THEN RETURN jsonb_build_object('ok',false,'raison','local_occupe'); END IF;
  SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name = dm.demandeur;
  BEGIN
    INSERT INTO public.locations_actives(id, country, data) VALUES (idb, h.pays, jsonb_build_object(
      'country',h.pays,'city',h.ville,'buildingId',h.batiment,'roomId',h.piece,'localKey',h.pays||'|'||h.ville||'|'||h.batiment||'|'||h.piece,
      'localLabel',h.label,'batimentLabel','Logements','prix',h.loyer,'bonusPOP',0,'bonusINF',0,'bonusDIS',0,'orgaId','','orgaAutorisee',false,
      'locataire',dm.demandeur,'depuis',jour,'visible',true,'logementSocial',true,'typeLogement',h.type_logement,
      'bonusMoralSommeil',h.bonus_moral,'bonusSanteSommeil',h.bonus_sante,'attribuePar',p_moi,
      'destinationLoyer',public.bail_destination_attestee(jsonb_build_object('roomId',h.piece,'country',h.pays,'city',h.ville))));
    v := public.prelever_loyer_bail(idb);
    IF v IS DISTINCT FROM 'paye' THEN RAISE EXCEPTION 'premier_loyer_refuse'; END IF;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok',false,'raison',CASE WHEN SQLERRM = 'premier_loyer_refuse' THEN SQLERRM ELSE 'attribution_refusee' END,'detail',SQLERRM);
  END;
  UPDATE public.logements_demandes SET statut = 'attribuee', room_id_attribue = h.piece WHERE id = p_demande;
  INSERT INTO public.logements_attributions_historique(id, country, ville, room_id, beneficiaire, autorite)
    VALUES ('attrib-'||h.piece||'-'||floor(extract(epoch FROM clock_timestamp())*1000), h.pays, h.ville, h.piece, dm.demandeur, p_moi);
  PERFORM public.mail_systeme_poser_interne('Mairie', dm.demandeur, 'Logement social attribué',
    'Un logement social vous a été attribué : '||h.label||'. Loyer : '||h.loyer||' FR par échéance, versé à la commune.', NULL);
  RETURN jsonb_build_object('ok',true,'bail',idb,'beneficiaire',dm.demandeur);
END;
$function$;

-- logement_historique_loyer_fixer_interne(text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logement_historique_loyer_fixer_interne(p_moi text, p_ville text, p_batiment text, p_piece text, p_loyer integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE h public.logements_sociaux_historiques; v_pays text; idb text; occupe boolean;
BEGIN
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_moi;
  SELECT * INTO h FROM public.logements_sociaux_historiques x WHERE x.pays = v_pays AND x.batiment = p_batiment AND x.piece = p_piece FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','logement_introuvable'); END IF;
  IF h.ville IS DISTINCT FROM p_ville THEN RETURN jsonb_build_object('ok',false,'raison','hors_commune'); END IF;
  UPDATE public.logements_sociaux_historiques x SET loyer = p_loyer WHERE x.pays = h.pays AND x.batiment = h.batiment AND x.piece = h.piece;
  idb := h.pays||':'||h.batiment||':'||h.piece||':'||h.ville;
  UPDATE public.locations_actives SET data = data || jsonb_build_object('prix', p_loyer) WHERE id = idb;
  occupe := FOUND;
  INSERT INTO public.logements_loyers_historique(pays, ville, batiment, piece, ancien, nouveau, autorite)
    VALUES (h.pays, h.ville, h.batiment, h.piece, h.loyer, p_loyer, p_moi);
  RETURN jsonb_build_object('ok',true,'lot',h.piece,'ancien',h.loyer,'loyer',p_loyer,'occupe',occupe);
END;
$function$;

-- logement_social_attribuer(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logement_social_attribuer(p_terrain text, p_lot text, p_demande text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); ville text; t record; e jsonb; lot jsonb; dm record; idb text; jour int;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  ville := public.logements_sociaux_ville_adjoint(moi);
  IF ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','reserve_adjoint'); END IF;
  IF EXISTS (SELECT 1 FROM public.logements_sociaux_historiques h WHERE h.batiment = p_terrain) THEN
    RETURN public.logement_historique_attribuer_interne(moi, ville, p_terrain, p_lot, p_demande); END IF;
  SELECT * INTO t FROM public.terrains_etat WHERE building_id = p_terrain AND country = (SELECT country FROM public.personnages_donnees WHERE name = moi) FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb;
  IF e->>'city' IS DISTINCT FROM ville OR e->>'proprietaire' IS DISTINCT FROM 'ville:'||t.country||':'||ville THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_commune'); END IF;
  SELECT value INTO lot FROM jsonb_array_elements(coalesce(e->'subdivisions','[]')) WHERE value->>'id' = p_lot;
  IF lot IS NULL OR lot->>'destination' IS DISTINCT FROM 'logement_social' THEN RETURN jsonb_build_object('ok',false,'raison','logement_introuvable'); END IF;
  SELECT * INTO dm FROM public.logements_demandes WHERE id = p_demande FOR UPDATE;
  IF NOT FOUND OR dm.statut <> 'en_attente' OR dm.country <> t.country OR dm.ville <> ville THEN RETURN jsonb_build_object('ok',false,'raison','demande_introuvable'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees r WHERE r.name = dm.demandeur AND r.domicile->>'country' = t.country AND r.domicile->>'city' = ville) THEN
    RETURN jsonb_build_object('ok',false,'raison','demandeur_non_resident'); END IF;
  idb := t.country||':'||t.building_id||':lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g')||':'||ville;
  SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name = dm.demandeur;
  BEGIN
    INSERT INTO public.logements_sociaux_internes VALUES (txid_current(), idb) ON CONFLICT DO NOTHING;
    e := public.location_lot_enregistrer_interne(e, t.country, t.building_id, p_lot, dm.demandeur, jour);
    UPDATE public.locations_actives SET data = data || jsonb_build_object('logementSocial',true,'typeLogement',lot->'typeLogement',
        'bonusMoralSommeil',lot->'bonusMoralSommeil','bonusSanteSommeil',lot->'bonusSanteSommeil','orgaAutorisee',false,'attribuePar',moi)
     WHERE id = idb;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok',false,'raison',CASE WHEN SQLERRM IN ('premier_loyer_refuse','local_occupe','loyer_non_fixe','lot_en_travaux') THEN SQLERRM ELSE 'attribution_refusee' END);
  END;
  PERFORM public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('subdivisions',e->'subdivisions','lotsHistorique',
    coalesce(e->'lotsHistorique','[]')||jsonb_build_array(jsonb_build_object('acte','attribution_sociale','acteur',moi,'lot',p_lot,'beneficiaire',dm.demandeur,'date',statement_timestamp()))), t.country);
  UPDATE public.logements_demandes SET statut = 'attribuee', room_id_attribue = 'lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g') WHERE id = p_demande;
  INSERT INTO public.logements_attributions_historique(id, country, ville, room_id, beneficiaire, autorite)
    VALUES ('attrib-'||t.building_id||'-'||p_lot||'-'||floor(extract(epoch FROM clock_timestamp())*1000), t.country, ville, t.building_id||'/'||p_lot, dm.demandeur, moi);
  PERFORM public.mail_systeme_poser_interne('Mairie', dm.demandeur, 'Logement social attribué',
    'Un logement social vous a été attribué : '||(lot->>'label')||'. Loyer : '||(lot->>'loyer')||' FR par échéance, versé à la commune.', NULL);
  RETURN jsonb_build_object('ok',true,'bail',idb,'beneficiaire',dm.demandeur);
END;
$function$;

-- logement_social_demander(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logement_social_demander(p_type text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; r jsonb; v_id text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_type IS NOT NULL AND p_type NOT IN ('petit','grand') THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF p.current_building NOT IN ('mairie','mairie-capitale') THEN RETURN jsonb_build_object('ok',false,'raison','pas_a_la_mairie'); END IF;
  IF NOT public.logements_sociaux_ville_a_offre(p.country, p.current_city) THEN
    RETURN jsonb_build_object('ok',false,'raison','aucun_logement_social'); END IF;
  IF p.domicile->>'country' IS DISTINCT FROM p.country OR p.domicile->>'city' IS DISTINCT FROM p.current_city THEN
    RETURN jsonb_build_object('ok',false,'raison','residence_requise'); END IF;
  IF EXISTS (SELECT 1 FROM public.logements_demandes WHERE country = p.country AND ville = p.current_city AND demandeur = moi AND statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_en_cours'); END IF;
  r := public.payer_ordre(moi, 'demander_logement_social', 1, 0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  v_id := 'demande-logement-'||p.current_city||'-'||regexp_replace(moi,'[^a-zA-Z0-9]','','g')||'-'||floor(extract(epoch FROM clock_timestamp())*1000);
  INSERT INTO public.logements_demandes(id, country, ville, demandeur, type_souhaite, statut)
    VALUES (v_id, p.country, p.current_city, moi, p_type, 'en_attente');
  RETURN r || jsonb_build_object('ok',true,'demandeId',v_id);
END;
$function$;

-- logement_social_loyer_fixer(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logement_social_loyer_fixer(p_terrain text, p_lot text, p_loyer integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); ville text; t record; e jsonb; lot jsonb; x jsonb; sortie jsonb := '[]'; idb text; ancien numeric;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  ville := public.logements_sociaux_ville_adjoint(moi);
  IF ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','reserve_adjoint'); END IF;
  IF p_loyer IS NULL OR p_loyer < 1 OR p_loyer > 100000 THEN RETURN jsonb_build_object('ok',false,'raison','loyer_invalide'); END IF;
  IF EXISTS (SELECT 1 FROM public.logements_sociaux_historiques h WHERE h.batiment = p_terrain) THEN
    RETURN public.logement_historique_loyer_fixer_interne(moi, ville, p_terrain, p_lot, p_loyer); END IF;
  SELECT * INTO t FROM public.terrains_etat WHERE building_id = p_terrain AND country = (SELECT country FROM public.personnages_donnees WHERE name = moi) FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb;
  IF e->>'city' IS DISTINCT FROM ville OR e->>'proprietaire' IS DISTINCT FROM 'ville:'||t.country||':'||ville THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_commune'); END IF;
  SELECT value INTO lot FROM jsonb_array_elements(coalesce(e->'subdivisions','[]')) WHERE value->>'id' = p_lot;
  IF lot IS NULL OR lot->>'destination' IS DISTINCT FROM 'logement_social' THEN RETURN jsonb_build_object('ok',false,'raison','logement_introuvable'); END IF;
  ancien := (lot->>'loyer')::numeric;
  FOR x IN SELECT value FROM jsonb_array_elements(e->'subdivisions') LOOP
    sortie := sortie || jsonb_build_array(CASE WHEN x->>'id' = p_lot THEN x || jsonb_build_object('loyer', p_loyer) ELSE x END);
  END LOOP;
  IF nullif(lot->>'locataire','') IS NOT NULL THEN
    idb := t.country||':'||t.building_id||':lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g')||':'||ville;
    INSERT INTO public.logements_sociaux_internes VALUES (txid_current(), idb) ON CONFLICT DO NOTHING;
    UPDATE public.locations_actives SET data = data || jsonb_build_object('prix', p_loyer) WHERE id = idb;
  END IF;
  PERFORM public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('subdivisions', sortie, 'lotsHistorique',
    coalesce(e->'lotsHistorique','[]')||jsonb_build_array(jsonb_build_object('acte','loyer_social','acteur',moi,'lot',p_lot,'ancien',ancien,'nouveau',p_loyer,'date',statement_timestamp()))), t.country);
  RETURN jsonb_build_object('ok',true,'lot',p_lot,'ancien',ancien,'loyer',p_loyer,'occupe',idb IS NOT NULL);
END;
$function$;

-- logements_historiques_liste_interne(text,text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logements_historiques_liste_interne(p_pays text, p_ville text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT coalesce(jsonb_agg(jsonb_build_object('terrain',h.batiment,'lot',h.piece,'label',h.label,'type',h.type_logement,'loyer',h.loyer,
         'locataire',(SELECT nullif(l.data->>'locataire','') FROM public.locations_actives l WHERE l.id = h.pays||':'||h.batiment||':'||h.piece||':'||h.ville),
         'batiment','historique') ORDER BY h.piece), '[]')
        FROM public.logements_sociaux_historiques h WHERE h.pays = p_pays AND h.ville = p_ville $function$;

-- logements_sociaux_domicile_resilier() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logements_sociaux_domicile_resilier()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE b record; t record; e jsonb; x jsonb; sortie jsonb;
BEGIN
  IF (OLD.domicile->>'country', OLD.domicile->>'city') IS NOT DISTINCT FROM (NEW.domicile->>'country', NEW.domicile->>'city') THEN
    RETURN NEW; END IF;
  FOR b IN DELETE FROM public.locations_actives
            WHERE data->>'locataire' = NEW.name AND data->>'logementSocial' = 'true'
              AND (country IS DISTINCT FROM NEW.domicile->>'country' OR data->>'city' IS DISTINCT FROM NEW.domicile->>'city')
           RETURNING id, country, data LOOP
    IF nullif(b.data->>'lotId','') IS NOT NULL THEN
      SELECT * INTO t FROM public.terrains_etat WHERE country = b.country AND building_id = b.data->>'buildingId' FOR UPDATE;
      IF FOUND THEN
        e := t.data::jsonb; sortie := '[]';
        FOR x IN SELECT value FROM jsonb_array_elements(coalesce(e->'subdivisions','[]')) LOOP
          sortie := sortie || jsonb_build_array(CASE WHEN x->>'id' = b.data->>'lotId' AND x->>'locataire' = NEW.name
                                                     THEN x || jsonb_build_object('locataire', NULL) ELSE x END);
        END LOOP;
        PERFORM public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('subdivisions', sortie, 'lotsHistorique',
          coalesce(e->'lotsHistorique','[]') || jsonb_build_array(jsonb_build_object('acte','resiliation_depart','lot',b.data->>'lotId',
            'ancienLocataire',NEW.name,'date',statement_timestamp()))), t.country);
      END IF;
    END IF;
    PERFORM public.mail_systeme_poser_interne('Mairie', NEW.name, 'Logement social résilié',
      'Votre domicile officiel a quitté la ville : votre bail social (' || coalesce(b.data->>'localLabel', 'logement') || ') est résilié.', NULL);
  END LOOP;
  RETURN NEW;
END;
$function$;

-- logements_sociaux_lots_interne(text) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logements_sociaux_lots_interne(p_niveau text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE n int := CASE p_niveau WHEN 'logements_petit' THEN 4 WHEN 'logements_moyen' THEN 6 WHEN 'logements_barre' THEN 10 END;
  sortie jsonb := '[]'; i int;
BEGIN
  IF n IS NULL THEN RAISE EXCEPTION 'palier_invalide'; END IF;
  FOR i IN 1..n/2 LOOP
    sortie := sortie || jsonb_build_array(jsonb_build_object('id','logement-petit-'||i,'label','Petit appartement n°'||i,'surface',45,
      'destination','logement_social','typeLogement','petit','locataire',NULL,'loyer',30,'logementSocial',true,'bonusMoralSommeil',3,'bonusSanteSommeil',4));
  END LOOP;
  FOR i IN 1..n/2 LOOP
    sortie := sortie || jsonb_build_array(jsonb_build_object('id','logement-grand-'||i,'label','Grand appartement n°'||i,'surface',75,
      'destination','logement_social','typeLogement','grand','locataire',NULL,'loyer',60,'logementSocial',true,'bonusMoralSommeil',5,'bonusSanteSommeil',7));
  END LOOP;
  RETURN sortie;
END;
$function$;

-- logements_sociaux_offre() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logements_sociaux_offre()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT jsonb_build_object('ok', true, 'offre', public.logements_sociaux_ville_a_offre(p.country, p.current_city))
        FROM public.personnages_donnees p WHERE p.name = public.mon_personnage() $function$;

-- logements_sociaux_tableau() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logements_sociaux_tableau()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); v_ville text; pays text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  v_ville := public.logements_sociaux_ville_adjoint(moi);
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','reserve_adjoint'); END IF;
  SELECT country INTO pays FROM public.personnages_donnees WHERE name = moi;
  RETURN jsonb_build_object('ok',true,'ville',v_ville,'pays',pays,'logementsMontrouge',(pays='republic' AND v_ville='ville_b'),
    'appartements', coalesce((SELECT jsonb_agg(jsonb_build_object('terrain',t.building_id,'lot',l->>'id','label',l->>'label','type',l->>'typeLogement',
         'loyer',(l->>'loyer')::numeric,'locataire',nullif(l->>'locataire',''),'batiment',t.data::jsonb->>'niveau_construction') ORDER BY t.building_id, l->>'id')
       FROM public.terrains_etat t, jsonb_array_elements(coalesce(t.data::jsonb->'subdivisions','[]')) l
      WHERE t.country = pays AND t.data::jsonb->>'city' = v_ville AND t.data::jsonb->>'proprietaire' = 'ville:'||pays||':'||v_ville
        AND l->>'destination' = 'logement_social'), '[]'),
    'historiques', public.logements_historiques_liste_interne(pays, v_ville),
    'demandes', coalesce((SELECT jsonb_agg(jsonb_build_object('id',d.id,'demandeur',d.demandeur,'type',d.type_souhaite,'depuis',d.created_at) ORDER BY d.created_at)
       FROM public.logements_demandes d WHERE d.country = pays AND d.ville = v_ville AND d.statut = 'en_attente'), '[]'));
END;
$function$;

-- logements_sociaux_terrain_communal(jsonb) -> boolean | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.logements_sociaux_terrain_communal(p_etat jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT coalesce(p_etat->>'proprietaire','') LIKE 'ville:%' OR coalesce(p_etat->>'acquisitionAcquereur','') LIKE 'ville:%' $function$;

-- logements_sociaux_ville_a_offre(text,text) -> boolean | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logements_sociaux_ville_a_offre(p_pays text, p_ville text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT (p_pays = 'republic' AND p_ville = 'ville_b') OR EXISTS (
         SELECT 1 FROM public.terrains_etat t, jsonb_array_elements(coalesce(t.data::jsonb->'subdivisions','[]')) l
          WHERE t.country = p_pays AND t.data::jsonb->>'city' = p_ville
            AND t.data::jsonb->>'proprietaire' = 'ville:'||p_pays||':'||p_ville
            AND l->>'destination' = 'logement_social') $function$;

-- logements_sociaux_ville_adjoint(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.logements_sociaux_ville_adjoint(p_nom text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT CASE WHEN d.poste->>'id'='maire_adjoint' AND public.poste_est_atteste(d.name,d.poste,d.country) THEN nullif(d.poste->>'city','') END
        FROM public.personnages_donnees d WHERE d.name = p_nom $function$;

-- permis_commune_payer_interne(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.permis_commune_payer_interne(p_acteur text, p_pays text, p_ville text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE caisse text := public.salaire_caisse_de('maire', p_pays, p_ville); solde numeric; ancien text; r jsonb;
BEGIN
  IF caisse IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','caisse_mairie_introuvable'); END IF;
  SELECT (data->>'solde')::numeric INTO solde FROM public.caisses_batiments WHERE id = caisse FOR UPDATE;
  IF coalesce(solde,0) < 100 THEN RETURN jsonb_build_object('ok',false,'raison','caisse_communale_insuffisante'); END IF;
  UPDATE public.personnages_donnees SET pa = pa - 1, updated_at = now() WHERE name = p_acteur AND coalesce(pa,0) >= 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','pa_insuffisants'); END IF;
  ancien := current_setting('rp.caisse_interne', true);
  PERFORM set_config('rp.caisse_interne', 'on', true);
  r := public.caisse_institution_mouvement(caisse, -100, true);
  PERFORM set_config('rp.caisse_interne', coalesce(ancien,''), true);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'caisse_communale_insuffisante'; END IF;
  RETURN (SELECT jsonb_build_object('ok',true,'pa',d.pa,'arg',d.arg,'liquide',d.liquide,'payeParCommune',true)
            FROM public.personnages_donnees d WHERE d.name = p_acteur);
END;
$function$;

-- permis_depot_archive_proteger() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.permis_depot_archive_proteger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 IF NEW.type_evenement='depot' AND NOT EXISTS(
  SELECT 1 FROM public.permis_transactions_internes
  WHERE transaction_id=txid_current() AND acteur=auth.uid()
 ) THEN RAISE EXCEPTION 'depot_permis_commande_versionnee_requise'; END IF;
 RETURN NEW;
END;$function$;

-- prelever_loyer_bail(text) -> text | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.prelever_loyer_bail(p_bail_id text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_lot_dynamique boolean;
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
  v_liquide_loyer numeric;
  v_disponible_bancaire numeric;
  v_debit_banque numeric;
  v_debit_liquide numeric;
  v_jour        text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD');
  v_cle         text;
  v_titulaire   text;
  v_orga_id     text;
  v_orga_data   text;
  v_maj         integer;
  v_rec         jsonb;
  -- L'ardoise de l'impaye, desormais calculee ET posee ici : voir le bloc de la
  -- branche « expulsion_requise ».
  v_imp         jsonb;
  v_avise       boolean;
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
  v_lot_dynamique:=left(coalesce(v_data->>'roomId',''),8)='lot_dyn_';
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

  SELECT coalesce(liquide,0) INTO v_liquide_loyer
     FROM public.personnages_donnees WHERE name=v_locataire FOR UPDATE;
  SELECT coalesce(sum(greatest(solde,0)),0) INTO v_disponible_bancaire
     FROM public.comptes_bancaires WHERE personnage=v_locataire AND banque='nationale';
  IF v_lot_dynamique THEN
    IF v_prix<0 OR v_prix<>trunc(v_prix) OR v_prix::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'loyer_invalide';END IF;
    v_arg:=coalesce(v_liquide_loyer,0)+coalesce(v_disponible_bancaire,0);
  END IF;
  -- Impayé.
  IF COALESCE(v_arg, 0) < v_prix OR coalesce(v_liquide_loyer,0)+v_disponible_bancaire < v_prix THEN
    IF COALESCE((v_data ->> 'avertissement')::boolean, false) THEN
      -- ARDOISE ATOMIQUE (chantier 6, 9 octobre 2026). Cette branche etait LA SEULE sortie
      -- a effet a ne pas poser jourPaiement : un rejeu du cron la meme nuit rendait de
      -- nouveau « expulsion_requise », et l'appelant rajoutait un jour et un loyer a
      -- l'ardoise. La dette DOUBLAIT a chaque passe.
      --
      -- Poser le marqueur ne suffisait pas : l'appelant reecrivait le blob entier depuis
      -- une lecture ANTERIEURE a cet appel, et effacait donc le marqueur dans la foulee.
      -- Le calcul de l'ardoise descend ici, ou il devient atomique avec sa revendication :
      -- une RPC est une seule transaction, et v_data a ete lu FOR UPDATE.
      --
      -- La regle, elle, ne change pas (arbitrage du 8 septembre 2026) : aucune expulsion
      -- automatique, un impaye est un FAIT qu'on chiffre et qu'on conserve, et un seul
      -- avis a l'ouverture de l'ardoise. Aucun argent ne bouge : le loyer reste du.
      v_imp := CASE WHEN jsonb_typeof(v_data -> 'impaye') = 'object'
                    THEN v_data -> 'impaye' ELSE '{}'::jsonb END;
      v_avise := COALESCE((v_imp ->> 'avisEnvoye')::boolean, false);
      UPDATE locations_actives
         SET data = v_data || jsonb_build_object(
               'jourPaiement', v_jour,
               'impaye', jsonb_build_object(
                  'depuis',     COALESCE(v_imp ->> 'depuis', v_jour),
                  'jours',      COALESCE((v_imp ->> 'jours')::numeric, 0) + 1,
                  'montantDu',  COALESCE((v_imp ->> 'montantDu')::numeric, 0) + v_prix,
                  'avisEnvoye', true))
       WHERE id = p_bail_id;
      -- Deux verdicts distincts, parce que l'appelant n'a plus qu'une chose a faire et
      -- qu'elle depend de celui-ci : poster l'avis UNE fois, a l'ouverture.
      IF v_avise THEN
        RETURN 'expulsion_requise_deja_avise';
      END IF;
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

    v_rec := public.recette_municipale(v_pays, v_ville, v_prix, 'loyer');
    IF NOT COALESCE((v_rec ->> 'ok')::boolean, false) THEN
      RAISE EXCEPTION 'destination_introuvable';
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

    IF v_lot_dynamique AND v_titulaire='ville:'||(v_data->>'country')||':'||(v_data->>'city') THEN
      v_rec:=public.recette_municipale(v_data->>'country',v_data->>'city',v_prix,'loyer');
      IF NOT coalesce((v_rec->>'ok')::boolean,false) THEN RAISE EXCEPTION 'destination_introuvable';END IF;
    ELSIF left(v_titulaire, 5) = 'orga:' THEN

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

      UPDATE public.personnages_donnees
      SET arg = COALESCE(arg, 0) + v_prix,
          liquide=CASE WHEN v_lot_dynamique THEN coalesce(liquide,0)+v_prix ELSE liquide END
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

  -- Débit atomique des avoirs réels, priorité au compte national.
  v_debit_banque:=least(v_disponible_bancaire,v_prix);
  v_debit_liquide:=v_prix-v_debit_banque;
  UPDATE public.comptes_bancaires
     SET solde=solde-v_debit_banque,updated_at=now()
   WHERE personnage=v_locataire AND banque='nationale' AND solde>=v_debit_banque;
  IF v_debit_banque>0 AND NOT FOUND THEN RAISE EXCEPTION 'compte_bancaire_modifie'; END IF;
  UPDATE public.personnages_donnees
     SET arg=arg-v_prix,liquide=liquide-v_debit_liquide,updated_at=now()
   WHERE name=v_locataire AND liquide>=v_debit_liquide;
  IF NOT FOUND THEN RAISE EXCEPTION 'avoirs_modifies'; END IF;

  UPDATE locations_actives
  SET data = (v_data - 'avertissement')
    || jsonb_build_object(
         'jourPaiement', v_jour,
         'dernierLoyerPaye', v_jour
       )
  WHERE id = p_bail_id;

  RETURN 'paye';
END;
$function$;

-- resilier_bail_volontaire(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.resilier_bail_volontaire(p_bail_id text, p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF COALESCE(p_bail_id, '') = '' OR COALESCE(p_acteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  -- Le demandeur agit-il en son propre nom ? La reference typee du navigateur est acceptee,
  -- le nom nu des baux historiques aussi. Qu'il soit le titulaire DE CE BAIL est verifie
  -- ensuite par terminer_bail, qui seule lit la ligne.
  IF NOT public.acteur_est_moi(p_acteur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_titulaire');
  END IF;
  RETURN terminer_bail(p_bail_id, 'resiliation_volontaire', p_acteur, 0);
END;
$function$;

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
$function$;

-- terrain_acquisition_commande(text,text,jsonb,uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_acquisition_commande(p_terrain text, p_action text, p_parametres jsonb, p_requete uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text:=public.mon_personnage();p record;t record;a record;fiche record;e jsonb;r jsonb;patch jsonb;params jsonb:=coalesce(p_parametres,'{}');prix numeric;surface numeric;montant numeric;pa integer;ordre text;ms numeric:=floor(extract(epoch FROM clock_timestamp())*1000);date_rdv numeric;terme integer;conjoint text;pret jsonb;permis text;commune boolean:=false;caisse_c text;titulaire_c text;ancien_c text;
BEGIN
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR p_action IS NULL OR p_action NOT IN('depot','compromis','acte_direct','acte_compromis') OR jsonb_typeof(params)<>'object' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(params) k WHERE k NOT IN('occupation','pret','permis','acquereur')) THEN RETURN jsonb_build_object('ok',false,'raison','parametre_non_autorise');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE acteur=moi AND requete=p_requete;
 IF FOUND THEN
  IF (a.terrain,a.action,a.parametres) IS DISTINCT FROM (p.country||'_'||p_terrain,p_action,params) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=a.terrain;
  RETURN a.resultat||jsonb_build_object('rejeu',true,'etat',e);
 END IF;
 IF coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain AND country=p.country AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;e:=t.data::jsonb;
 IF coalesce(e->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele');END IF;
 IF e->>'proprietaire'='Helvetia' THEN RETURN jsonb_build_object('ok',false,'raison','circuit_helvetia_requis');END IF;
 IF p_action IN('depot','compromis') THEN
  IF p.current_building IS DISTINCT FROM p_terrain OR p.current_city IS DISTINCT FROM e->>'city' THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
  IF nullif(e->>'proprietaire','') IS NOT NULL OR coalesce((e->>'compromis')::boolean,false) OR jsonb_typeof(e->'achatDirect')='object' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_indisponible');END IF;
  IF coalesce(e->>'pnj','')<>'' OR coalesce(e->>'policeAppellee','')<>'' OR coalesce((e->>'enqueteJusqua')::numeric,0)>ms THEN RETURN jsonb_build_object('ok',false,'raison','terrain_occupe');END IF;
  IF params->>'occupation' IS DISTINCT FROM coalesce(e->>'dateGeneration','historique')||':'||coalesce(e->>'pnj','') THEN RETURN jsonb_build_object('ok',false,'raison','occupation_modifiee');END IF;
  SELECT * INTO fiche FROM public.terrains_referentiel WHERE pays=t.country AND ville=e->>'city' AND batiment=t.building_id;
  surface:=coalesce((e->>'surface')::numeric,fiche.surface);prix:=coalesce((e->>'valeur_totale')::numeric,fiche.prix_achat);
  IF surface IS NULL OR surface<=0 OR surface::text IN('NaN','Infinity','-Infinity') OR prix IS NULL OR prix<1000 OR prix<>trunc(prix) OR prix::text IN('NaN','Infinity','-Infinity') THEN RETURN jsonb_build_object('ok',false,'raison','prix_ou_surface_non_reference');END IF;
  pret:=params->'pret';permis:=params->>'permis';
  IF jsonb_typeof(pret)='object' THEN
   IF p_action<>'compromis' OR (pret->>'montant')::numeric<1000 OR (pret->>'montant')::numeric>150000 OR (pret->>'montant')::numeric<>trunc((pret->>'montant')::numeric) OR (pret->>'duree')::numeric<>trunc((pret->>'duree')::numeric) OR (pret->>'duree')::integer<=0 OR NOT(pret ? 'montant' AND pret ? 'duree') THEN RETURN jsonb_build_object('ok',false,'raison','pret_invalide');END IF;
   pret:=jsonb_build_object('demandeur',moi,'montant',(pret->>'montant')::numeric,'duree',(pret->>'duree')::integer,'taux',CASE WHEN p.country='republic' THEN public.taux_pret_nationale(p.country) ELSE (SELECT 5+(data->'indices'->p.country->>'IE')::numeric/10 FROM public.terrain_actions_regles WHERE id) END,'statut','attente_validation');
  ELSIF pret IS NOT NULL AND pret<>'null'::jsonb THEN RETURN jsonb_build_object('ok',false,'raison','pret_invalide');END IF;
  IF params ? 'acquereur' AND params->>'acquereur' NOT IN('personnel','commune') THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides');END IF;
  IF params->>'acquereur'='commune' THEN
   IF (SELECT c.data::jsonb->>'eluId' FROM public.cycles_electoraux c WHERE c.country=p.country AND c.poste_id='maire' AND c.city=e->>'city') IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','pas_maire_de_la_commune');END IF;
   IF jsonb_typeof(pret)='object' THEN RETURN jsonb_build_object('ok',false,'raison','commune_sans_pret');END IF;
   commune:=true;
  END IF;
  IF permis IS NOT NULL AND (p_action<>'compromis' OR permis NOT IN('hangar','commerce_standard','commerce_premium','building','logements_petit','logements_moyen','logements_barre')) THEN RETURN jsonb_build_object('ok',false,'raison','palier_invalide');END IF;
  montant:=1000;pa:=2;ordre:=CASE p_action WHEN 'depot' THEN 'acheter_terrain' ELSE 'signer_compromis' END;
 ELSE
  IF p.current_building IS DISTINCT FROM 'office-notarial' OR p.current_city IS DISTINCT FROM 'capitale' THEN RETURN jsonb_build_object('ok',false,'raison','pas_chez_notaire');END IF;
  IF nullif(e->>'proprietaire','') IS NOT NULL THEN RETURN jsonb_build_object('ok',false,'raison','deja_acquis');END IF;
  IF p_action='acte_direct' THEN
   IF e->'achatDirect'->>'demandeur' IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_achat_direct');END IF;
   IF e->'achatDirect'->>'dateAchat' IS NULL OR e->'achatDirect'->>'dateLimite' IS NULL OR ms<(e->'achatDirect'->>'dateAchat')::numeric OR ms>(e->'achatDirect'->>'dateLimite')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','rendez_vous_hors_delai');END IF;
   prix:=(e->'achatDirect'->>'prix')::numeric;montant:=prix-(e->'achatDirect'->>'acompte')::numeric;
  ELSE
   IF e->>'compromis' IS DISTINCT FROM 'true' OR e->>'compromisPar' IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_compromis');END IF;
   IF e->'pretDemande'->>'statut'='attente_validation' AND (e->>'compromisExpireAt')::numeric<=ms THEN
    r:=public.compromis_expire_resoudre('terrain',t.id);SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=t.id;
   END IF;
   IF e->>'compromis' IS DISTINCT FROM 'true' OR (e->>'compromisExpireAt')::numeric<=ms AND e->'pretDemande'->>'statut' IS DISTINCT FROM 'accorde' THEN RETURN jsonb_build_object('ok',false,'raison','compromis_expire');END IF;
   IF e->'pretDemande'->>'statut' IS NOT NULL AND e->'pretDemande'->>'statut'<>'accorde' OR e->'permis'->>'statut' IN('instruction','attente_validation','refuse') THEN RETURN jsonb_build_object('ok',false,'raison','clauses_non_acquises');END IF;
   prix:=(e->>'valeur_totale')::numeric;montant:=prix-coalesce((e->>'acompte')::numeric,0);
  END IF;
  surface:=(e->>'surface')::numeric;pa:=1;ordre:='acte_vente_terrain';
  commune:=coalesce(e->>'acquisitionAcquereur','') LIKE 'ville:%';
  IF commune AND (SELECT c.data::jsonb->>'eluId' FROM public.cycles_electoraux c WHERE c.country=p.country AND c.poste_id='maire' AND c.city=e->>'city') IS DISTINCT FROM moi THEN RETURN jsonb_build_object('ok',false,'raison','pas_maire_de_la_commune');END IF;
 END IF;
 IF p_action IN('acte_direct','acte_compromis') AND e->>'acquisitionVersion'='2' THEN
  SELECT * INTO a FROM public.terrain_acquisitions_recus WHERE terrain=t.id AND requete::text=e->>'acquisitionRequete' AND action=CASE p_action WHEN 'acte_direct' THEN 'depot' ELSE 'compromis' END;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','depot_non_atteste');END IF;
  prix:=(a.resultat->>'prix')::numeric;montant:=prix-(a.resultat->>'montant')::numeric;
 END IF;
 IF montant IS NULL OR montant<0 OR montant<>trunc(montant) THEN RETURN jsonb_build_object('ok',false,'raison','montant_invalide');END IF;
 IF commune THEN
  titulaire_c:='ville:'||p.country||':'||(e->>'city');
  caisse_c:=public.salaire_caisse_de('maire',p.country,e->>'city');
  IF caisse_c IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','caisse_mairie_introuvable');END IF;
 END IF;
 -- Tout echec apres le premier paiement leve : debit, credit, permis, titre et recu disparaissent ensemble.
 INSERT INTO public.acquisitions_transactions_internes VALUES(txid_current(),moi,t.id,ordre,pa,CASE WHEN commune THEN 0 ELSE montant END);
 -- pret verse a la signature : le capital arrive juste avant le paiement de l'acte.
 IF p_action='acte_compromis' AND e->'pretDemande'->>'statut'='accorde' THEN
  r:=public.pret_national_creer_interne(moi,(e->'pretDemande'->>'montant')::numeric,(e->'pretDemande'->>'duree')::integer,'immobilier',t.building_id,
    'acquisition-'||t.id||'-'||coalesce(e->>'acquisitionRequete',e->>'compromisAt'),
    (SELECT (x.resultat->'pretCapture'->>'taux')::numeric FROM public.terrain_acquisitions_recus x WHERE x.terrain=t.id AND x.requete::text=e->>'acquisitionRequete' AND x.action='compromis'));
 END IF;
 r:=public.payer_ordre(moi,ordre,pa,CASE WHEN commune THEN 0 ELSE montant::integer END);IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE=coalesce(r->>'raison','paiement_refuse');END IF;
 IF commune AND montant>0 THEN
  ancien_c:=current_setting('rp.caisse_interne',true);
  PERFORM set_config('rp.caisse_interne','on',true);
  r:=public.caisse_institution_mouvement(caisse_c,-montant,true);
  PERFORM set_config('rp.caisse_interne',coalesce(ancien_c,''),true);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='P0135',MESSAGE='caisse_communale_insuffisante';END IF;
 END IF;
 IF p_action='depot' THEN
  terme:=2+floor(random()*6)::integer;date_rdv:=extract(epoch FROM (((clock_timestamp() AT TIME ZONE 'Europe/Paris')+make_interval(days=>terme)) AT TIME ZONE 'Europe/Paris'))*1000;
  patch:=jsonb_build_object('achatDirect',jsonb_build_object('demandeur',moi,'acompte',1000,'prix',prix,'surface',surface,'dateAchat',date_rdv,'dateLimite',date_rdv+86400000));
  r:=public.terrain_compromis_acte(t.id,'achat_direct_deposer',patch);
 ELSIF p_action='compromis' THEN
  patch:=jsonb_build_object('compromis',true,'compromisPar',moi,'acompte',1000,'compromisAt',ms,'compromisExpireAt',floor(extract(epoch FROM (((clock_timestamp() AT TIME ZONE 'Europe/Paris')+interval '7 days') AT TIME ZONE 'Europe/Paris'))*1000),'pretDemande',pret);
  r:=public.terrain_compromis_acte(t.id,'compromis_signer',patch);
 ELSE
  SELECT CASE WHEN conjoint1=moi THEN conjoint2 ELSE conjoint1 END INTO conjoint FROM public.mariages WHERE statut='actif' AND (conjoint1=moi OR conjoint2=moi) LIMIT 1;
  patch:=jsonb_build_object('proprietaire',coalesce(titulaire_c,moi),'coproprietaire',CASE WHEN commune THEN NULL ELSE conjoint END,'acheteAt',ms,'surface',surface,'valeur_totale',prix,'dette_fonciere',0,'city',e->>'city','constructionAutorisee',coalesce((e->>'constructionAutorisee')::boolean,false));
  patch:=patch||CASE p_action WHEN 'acte_direct' THEN '{"achatDirect":null}'::jsonb ELSE '{"compromis":null,"compromisPar":null,"acompte":null,"compromisAt":null,"compromisExpireAt":null}'::jsonb END;
  r:=public.terrain_proprietaire_muter(t.id,CASE p_action WHEN 'acte_direct' THEN 'achat_direct' ELSE 'compromis' END,patch,p_requete::text);
 END IF;
 IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING MESSAGE=coalesce(r->>'raison','acquisition_refusee');END IF;
 e:=r->'etat';
 e:=public.terrain_etat_fusionner_interne(t.id,jsonb_build_object('acquisitionVersion',2,'acquisitionRequete',p_requete,'surface',surface,'valeur_totale',prix,'acquisitionAcquereur',CASE WHEN p_action IN('depot','compromis') THEN titulaire_c END),p.country);
 IF p_action='compromis' AND permis IS NOT NULL THEN
  r:=public.terrain_permis_deposer(p_terrain,permis,p_requete);IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING MESSAGE=coalesce(r->>'raison','permis_non_confirme');END IF;e:=r->'etat';
 END IF;
 r:=jsonb_build_object('ok',true,'action',p_action,'montant',montant,'prix',prix,'etat',e,'pretCapture',pret);
 IF p_action='depot' THEN
  r:=r||jsonb_build_object('courrier',public.mail_systeme_poser_interne('Office Notarial',moi,'Rendez-vous fixé — achat de terrain',
    'Votre dépôt de garantie de 1 000 FR est enregistré. Rendez-vous le '||to_char(to_timestamp((e->'achatDirect'->>'dateAchat')::numeric/1000) AT TIME ZONE 'Europe/Paris','DD/MM/YYYY HH24:MI')||' à l’Office Notarial. Tolérance de 24h ; passé ce délai, dépôt perdu et terrain remis en vente.',NULL));
 END IF;
 INSERT INTO public.terrain_acquisitions_recus VALUES(moi,p_requete,t.id,p_action,params,r-'etat');
 DELETE FROM public.acquisitions_transactions_internes WHERE transaction_id=txid_current() AND acteur=moi;
 UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE name=moi;
 RETURN r;
EXCEPTION WHEN SQLSTATE 'P0135' THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);
END;$function$;

-- terrain_chantier_acte(text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_chantier_acte(p_terrain_id text, p_acte text, p_matiere text DEFAULT NULL::text, p_quantite integer DEFAULT NULL::integer, p_jour integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_ch jsonb; v_final jsonb;
  v_d double precision; v_total double precision; v_verse double precision; v_prog double precision;
  v_s1 double precision; v_s2 double precision; v_s3 double precision;
  v_requis double precision; v_plafond double precision; v_gain double precision; v_neuf double precision;
  v_stock jsonb; v_dispo integer; v_qte integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  -- Arbitrage : republic, soviet, narco et khalija sont tous non P2W.
  -- Aucun pays futur n'est autorise implicitement ; il faudra un arbitrage explicite.
  IF p_acte='chantier_accelerer' THEN RETURN jsonb_build_object('ok',false,'raison','delai_incompressible');END IF;
  IF p_acte NOT IN ('chantier_accelerer', 'chantier_materiaux_voler') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;

  IF p_acte='chantier_accelerer' AND v_pays='republic' THEN RETURN jsonb_build_object('ok',false,'raison','delai_incompressible');END IF;
  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_ch := v_etat -> 'chantier';
  IF v_ch IS NULL OR jsonb_typeof(v_ch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;

  IF coalesce((v_ch->>'dureeJours')::numeric,0)<=0 OR coalesce((v_ch->>'progressionJours')::numeric,0)>=(v_ch->>'dureeJours')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','chantier_a_son_terme');END IF;
  IF p_acte = 'chantier_accelerer' THEN
    SELECT valeur::double precision INTO v_s1 FROM public.entreprises_constantes WHERE cle = 'seuil_demarrage_pct';
    SELECT valeur::double precision INTO v_s2 FROM public.entreprises_constantes WHERE cle = 'seuil_premier_tiers_pct';
    SELECT valeur::double precision INTO v_s3 FROM public.entreprises_constantes WHERE cle = 'seuil_deux_tiers_pct';
    IF v_s1 IS NULL OR v_s2 IS NULL OR v_s3 IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'seuils_indisponibles');
    END IF;
    v_d     := greatest(0, coalesce((v_ch ->> 'dureeJours')::double precision, 0));
    v_total := greatest(0, coalesce((v_ch ->> 'coutTotal')::double precision, 0));
    v_verse := greatest(0, coalesce((v_ch ->> 'totalVerse')::double precision, 0));
    v_prog  := greatest(0, coalesce((v_ch ->> 'progressionJours')::double precision, 0));

    -- peutProgresser : montantManquant(...) <= 0, avec seuilFinancementRequis par palier de tiers.
    v_requis := ceil(v_total * (CASE WHEN v_d <= 0 THEN v_s3
                                     WHEN v_prog < v_d * 1 / 3 THEN v_s1
                                     WHEN v_prog < v_d * 2 / 3 THEN v_s2
                                     ELSE v_s3 END) / 100);
    IF greatest(0, v_requis - v_verse) > 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'financement_insuffisant',
                                'manquant', greatest(0, v_requis - v_verse));
    END IF;
    IF greatest(0, v_d - v_prog) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'chantier_a_son_terme');
    END IF;

    -- progressionMaxFinancee, puis progressionAutorisee avec un gain de la MOITIE du travail
    -- restant -- la regle exacte de `doCorrompreChantier`, inchangee.
    v_plafond := CASE WHEN v_d <= 0 THEN 0
                      WHEN v_total <= 0 THEN v_d
                      WHEN v_verse * 100 >= v_s3 * v_total THEN v_d
                      WHEN v_verse * 100 >= v_s2 * v_total THEN v_d * 2 / 3
                      WHEN v_verse * 100 >= v_s1 * v_total THEN v_d * 1 / 3
                      ELSE 0 END;
    v_gain := greatest(0, least(v_prog + greatest(0, (v_d - v_prog) / 2), v_plafond) - v_prog);
    IF v_gain <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'progression_plafonnee', 'plafond', v_plafond);
    END IF;
    v_neuf := least(v_d, v_prog + v_gain);
    v_ch := v_ch || jsonb_build_object('progressionJours', v_neuf);
    -- appliquerVerrouPlan : le plan se fige aux deux tiers, et une seule fois.
    IF coalesce((v_ch ->> 'planVerrouille')::boolean, false) IS NOT TRUE
       AND v_d > 0 AND v_neuf >= v_d * 2 / 3 THEN
      v_ch := v_ch || jsonb_build_object('planVerrouille', true, 'jourVerrouPlan', p_jour);
    END IF;
    v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
                 jsonb_build_object('chantier', v_ch), v_pays);
    RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final, 'chantier', v_ch,
      'progression', v_neuf, 'reste', greatest(0, v_d - v_neuf), 'gain', v_gain);
  END IF;

  -- VOL DE MATERIAUX : par crime_voler_materiaux depuis le 28/10/2026 (chantier inventaire).
  IF p_acte = 'chantier_materiaux_voler' THEN RETURN jsonb_build_object('ok', false, 'raison', 'vol_par_le_serveur'); END IF;
  IF p_matiere NOT IN ('bois', 'minerai', 'metal') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_inconnue');
  END IF;
  IF coalesce(p_quantite, 0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  v_stock := coalesce(v_ch -> 'stockMateriaux', '{}'::jsonb);
  v_dispo := greatest(0, coalesce((v_stock ->> p_matiere)::numeric, 0))::integer;
  IF v_dispo <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_vide', 'matiere', p_matiere);
  END IF;
  -- LE PLAFOND EST LE STOCK REEL, PAS CELUI QUE LE CLIENT AVAIT LU.
  v_qte := least(p_quantite, v_dispo);
  v_ch := v_ch
    || jsonb_build_object('stockMateriaux', v_stock || jsonb_build_object(p_matiere, v_dispo - v_qte))
    || jsonb_build_object('evenements', coalesce(v_ch -> 'evenements', '[]'::jsonb)
         || jsonb_build_array(jsonb_build_object('cle', 'vol_materiaux', 'jour', p_jour,
              'matiere', p_matiere, 'quantite', v_qte)));
  v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
               jsonb_build_object('chantier', v_ch), v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final, 'chantier', v_ch,
    'matiere', p_matiere, 'quantite', v_qte, 'stock_restant', v_dispo - v_qte);
END; $function$;

-- terrain_compromis_acte(text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_compromis_acte(p_terrain_id text, p_acte text, p_patch jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_patch jsonb; v_final jsonb;
  v_cles text[]; v_k text;
BEGIN
  v_moi := public.mon_personnage();
  IF p_acte IN('compromis_signer','achat_direct_deposer') AND NOT EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=v_moi) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_acte NOT IN ('compromis_signer', 'compromis_pret_demander', 'compromis_transfert_proposer',
                    'compromis_transfert_accepter', 'achat_direct_deposer') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acte_inconnu');
  END IF;
  IF p_patch IS NULL OR jsonb_typeof(p_patch) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'patch_invalide');
  END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;

  -- LISTE DE CLES PAR ACTE (10 octobre 2026). Meme regle que `terrain_permis_acte` : un acte
  -- ne touche que les cles qu'il declare. Relevees sur les six chemins du navigateur.
  v_cles := CASE p_acte
    WHEN 'compromis_signer' THEN ARRAY['compromis', 'compromisPar', 'acompte',
                                        'compromisAt', 'compromisExpireAt', 'pretDemande', 'permis']
    WHEN 'compromis_pret_demander' THEN ARRAY['pretDemande']
    WHEN 'compromis_transfert_proposer' THEN ARRAY['transfertPropose', 'transfertProposePar']
    WHEN 'compromis_transfert_accepter' THEN ARRAY['compromisPar', 'transfertPropose',
                                        'transfertProposePar', 'permis', 'pretDemande']
    ELSE ARRAY['achatDirect'] END;
  FOR v_k IN SELECT jsonb_object_keys(p_patch) LOOP
    IF NOT (v_k = ANY (v_cles)) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'cle_hors_acte', 'cle', v_k);
    END IF;
  END LOOP;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF p_acte='compromis_pret_demander' AND v_etat->>'proprietaire' IS DISTINCT FROM 'Helvetia' AND NOT EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=v_moi) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  -- LE GEL SUCCESSORAL EST LA MEME REGLE QUE DANS `terrain_proprietaire_muter`, lue en base.
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  v_patch := p_patch;

  IF p_acte = 'compromis_signer' THEN
    -- LA REGLE EXISTAIT DEJA, cote serveur, pour le jumeau Helvetia : `signer_compromis_bien_helvetia`
    -- refuse « bien deja sous compromis ». Le chemin ordinaire ne la verifiait que dans l'ecran.
    IF coalesce((v_etat ->> 'compromis')::boolean, false)
       AND (v_etat ->> 'compromisPar') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'deja_sous_compromis',
                                'detenteur', v_etat ->> 'compromisPar');
    END IF;
    -- LE DETENTEUR N'EST PLUS DICTE PAR LE NAVIGATEUR.
    v_patch := v_patch || jsonb_build_object('compromis', true, 'compromisPar', v_moi);

  ELSIF p_acte IN ('compromis_pret_demander', 'compromis_transfert_proposer') THEN
    IF coalesce((v_etat ->> 'compromis')::boolean, false) IS NOT TRUE
       OR (v_etat ->> 'compromisPar') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_compromis');
    END IF;
    IF p_acte = 'compromis_transfert_proposer' THEN
      IF nullif(btrim(coalesce(v_patch ->> 'transfertPropose', '')), '') IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_absent');
      END IF;
      IF (v_patch ->> 'transfertPropose') = v_moi THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'transfert_a_soi_meme');
      END IF;
      v_patch := v_patch || jsonb_build_object('transfertProposePar', v_moi);
    END IF;

  ELSIF p_acte = 'compromis_transfert_accepter' THEN
    -- LA REGLE QUI N'EXISTAIT QUE DANS L'ECRAN. Sans elle, n'importe quel joueur connecte posait
    -- son nom dans `compromisPar` et reprenait le compromis d'un autre.
    IF (v_etat ->> 'transfertPropose') IS DISTINCT FROM v_moi THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'transfert_non_propose');
    END IF;
    v_patch := v_patch || jsonb_build_object('compromisPar', v_moi,
      'transfertPropose', NULL, 'transfertProposePar', NULL);

  ELSIF p_acte = 'achat_direct_deposer' THEN
    IF coalesce((v_etat ->> 'compromis')::boolean, false)
       OR ((v_etat -> 'achatDirect') IS NOT NULL
           AND (v_etat -> 'achatDirect' ->> 'demandeur') IS DISTINCT FROM v_moi) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'terrain_indisponible');
    END IF;
    IF jsonb_typeof(v_patch -> 'achatDirect') <> 'object' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'achat_direct_absent');
    END IF;
    v_patch := jsonb_set(v_patch, '{achatDirect,demandeur}', to_jsonb(v_moi));

  END IF;

  v_final := public.terrain_etat_fusionner_interne(p_terrain_id, v_patch, v_pays);
  RETURN jsonb_build_object('ok', true, 'acte', p_acte, 'etat', v_final);
END; $function$;

-- terrain_etat_fusionner_interne(text,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_etat_fusionner_interne(p_terrain_id text, p_patch jsonb, p_pays text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_cle text; v_data jsonb; v_pays text; v_bat text;
BEGIN
  SELECT t.id, coalesce(t.data::jsonb, '{}'::jsonb), t.country, t.building_id
    INTO v_cle, v_data, v_pays, v_bat
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1
     FOR UPDATE;

  IF v_cle IS NULL THEN
    -- PREMIERE ECRITURE SUR UN TERRAIN VIERGE. La cle est celle que `sbSetTerrainState` composait
    -- deja : pays + '_' + batiment. Le pays vient de l'appelant serveur, jamais du navigateur.
    v_pays := coalesce(p_pays, 'republic');
    v_bat := p_terrain_id;
    v_cle := v_pays || '_' || v_bat;
    v_data := coalesce(p_patch, '{}'::jsonb);
    INSERT INTO public.terrains_etat (id, country, building_id, proprietaire, data, updated_at)
    VALUES (v_cle, v_pays, v_bat, nullif(v_data ->> 'proprietaire', ''), v_data::text, now())
    ON CONFLICT (id) DO NOTHING;
    RETURN v_data;
  END IF;

  v_data := v_data || coalesce(p_patch, '{}'::jsonb);
  UPDATE public.terrains_etat
     SET data = v_data::text, proprietaire = nullif(v_data ->> 'proprietaire', ''), updated_at = now()
   WHERE id = v_cle;
  RETURN v_data;
END; $function$;

-- terrain_etat_lire(text) -> jsonb | plpgsql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.terrain_etat_lire(p_data text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN p_data::jsonb;
EXCEPTION WHEN others THEN RETURN NULL;
END; $function$;

-- terrain_etat_verrouiller_interne(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_etat_verrouiller_interne(p_terrain_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_cle text; v_data jsonb;
BEGIN
  SELECT t.id, coalesce(t.data::jsonb, '{}'::jsonb) INTO v_cle, v_data
    FROM public.terrains_etat t
   WHERE t.id = p_terrain_id OR t.building_id = p_terrain_id
   ORDER BY (t.id = p_terrain_id) DESC LIMIT 1
     FOR UPDATE;
  IF v_cle IS NULL THEN
    RETURN jsonb_build_object('trouve', false, 'etat', '{}'::jsonb, 'gele', false);
  END IF;
  RETURN jsonb_build_object('trouve', true, 'cle', v_cle, 'etat', v_data,
    'gele', coalesce(v_data ->> 'succession_gel', '') <> '');
END; $function$;

-- terrain_lot_loyer_fixer(text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_lot_loyer_fixer(p_terrain_id text, p_lot text, p_loyer integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; t record; etat jsonb; lot jsonb; sortie jsonb := '[]'; x jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_lot IS NULL OR btrim(p_lot) = '' THEN RETURN jsonb_build_object('ok',false,'raison','lot_introuvable'); END IF;
  IF p_loyer IS NULL OR p_loyer < 1 OR p_loyer > 100000 THEN RETURN jsonb_build_object('ok',false,'raison','loyer_invalide'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi;
  IF coalesce(p.hp,0) <= 0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible'); END IF;
  SELECT * INTO t FROM public.terrains_etat
   WHERE country = p.country AND (id = p_terrain_id OR building_id = p_terrain_id AND data::jsonb->>'city' = p.current_city)
   ORDER BY (id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  etat := t.data::jsonb;
  IF coalesce(etat->>'succession_gel','') <> '' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
  -- Même autorité que le chantier : PJ titulaire, chef de l'organisation, maire de la commune.
  BEGIN
    PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire', t.country, etat->>'city');
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_titulaire_des_murs');
  END;
  SELECT value INTO lot FROM jsonb_array_elements(coalesce(etat->'subdivisions','[]')) WHERE value->>'id' = p_lot;
  IF lot->>'destination' = 'logement_social' THEN RETURN jsonb_build_object('ok', false, 'raison', 'loyer_fixe_par_adjoint'); END IF;
  IF lot IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','lot_introuvable'); END IF;
  -- Protection des baux : le loyer d'un lot occupé ne change pas en cours de bail.
  IF nullif(lot->>'locataire','') IS NOT NULL OR EXISTS(
       SELECT 1 FROM public.locations_actives
        WHERE country = t.country AND data->>'city' = etat->>'city' AND data->>'buildingId' = t.building_id
          AND data->>'roomId' = 'lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g')) THEN
    RETURN jsonb_build_object('ok',false,'raison','lot_occupe'); END IF;
  IF etat->'chantierReamenagement'->'lotsConcernes' ? p_lot THEN
    RETURN jsonb_build_object('ok',false,'raison','lot_en_travaux'); END IF;
  IF (lot->>'loyer') = p_loyer::text THEN
    RETURN jsonb_build_object('ok',true,'rejeu',true,'etat',etat); END IF;
  FOR x IN SELECT value FROM jsonb_array_elements(etat->'subdivisions') LOOP
    sortie := sortie || jsonb_build_array(CASE WHEN x->>'id' = p_lot THEN x || jsonb_build_object('loyer', p_loyer) ELSE x END);
  END LOOP;
  etat := etat || jsonb_build_object('subdivisions', sortie,
    'lotsHistorique', coalesce(etat->'lotsHistorique','[]') || jsonb_build_array(jsonb_build_object(
      'acte','loyer_fixe','acteur',moi,'lot',p_lot,'loyer',p_loyer,'date',statement_timestamp())));
  UPDATE public.terrains_etat SET data = etat::text, updated_at = now() WHERE id = t.id;
  RETURN jsonb_build_object('ok',true,'etat',etat,'lot',p_lot,'loyer',p_loyer);
END;
$function$;

-- terrain_lots_acte(text,text,jsonb,text[]) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_lots_acte(p_terrain_id text, p_acte text, p_lots jsonb DEFAULT NULL::jsonb, p_retirer text[] DEFAULT NULL::text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text:=public.mon_personnage();p record;t record;etat jsonb;lots jsonb;sortie jsonb:='[]';entree jsonb;lot jsonb;nouveau jsonb;bail record;vus text[]:=ARRAY[]::text[];idlot text;modifie boolean:=false;proprio boolean:=false;
BEGIN
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_acte IN('lot_ajouter','lot_fusion_proposer','lot_fusion_accepter') THEN RETURN jsonb_build_object('ok',false,'raison','reamenagement_payant_requis');END IF;
 IF p_acte IS NULL OR p_acte NOT IN('lot_louer','lot_bail_libere','lot_fusion_refuser') THEN RETURN jsonb_build_object('ok',false,'raison','acte_inconnu');END IF;
 IF p_retirer IS NOT NULL AND cardinality(p_retirer)>0 THEN RETURN jsonb_build_object('ok',false,'raison','suppression_interdite');END IF;
 IF jsonb_typeof(p_lots) IS DISTINCT FROM 'array' OR jsonb_array_length(p_lots)=0 THEN RETURN jsonb_build_object('ok',false,'raison','lots_invalides');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF coalesce(p.hp,0)<=0 OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text OR EXISTS(SELECT 1 FROM public.detention_active(moi)) THEN RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE country=p.country AND (id=p_terrain_id OR building_id=p_terrain_id AND data::jsonb->>'city'=p.current_city) ORDER BY (id=p_terrain_id) DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable');END IF;
 etat:=t.data::jsonb;lots:=coalesce(etat->'subdivisions','[]');
 IF coalesce(etat->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele');END IF;
 -- Valider TOUTE la commande avant la premiere ecriture, puis ne reprendre que l'identifiant.
 FOR entree IN SELECT value FROM jsonb_array_elements(p_lots) LOOP
  idlot:=entree->>'id';
  IF idlot IS NULL OR idlot=ANY(vus) THEN RETURN jsonb_build_object('ok',false,'raison','identifiant_lot_invalide');END IF;
  vus:=array_append(vus,idlot);
  SELECT value INTO lot FROM jsonb_array_elements(lots) WHERE value->>'id'=idlot;
  IF lot IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','lot_introuvable');END IF;
  IF p_acte='lot_louer' THEN
   IF p.current_city IS DISTINCT FROM etat->>'city' OR p.current_building IS DISTINCT FROM t.building_id THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
   IF etat->'chantierReamenagement'->'lotsConcernes' ? idlot THEN RETURN jsonb_build_object('ok',false,'raison','lot_en_travaux');END IF;
   SELECT * INTO bail FROM public.locations_actives WHERE country=t.country AND data->>'city'=etat->>'city' AND data->>'buildingId'=t.building_id AND data->>'roomId'='lot_dyn_'||regexp_replace(idlot,'[^A-Za-z0-9_-]','_','g') FOR UPDATE;
   IF NOT FOUND OR bail.data->>'locataire' IS DISTINCT FROM moi OR nullif(lot->>'locataire','') IS NOT NULL AND lot->>'locataire' NOT IN(moi,'pj:'||moi) THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_bail');END IF;
  ELSIF p_acte='lot_fusion_refuser' THEN
   IF lot->>'locataire' NOT IN(moi,'pj:'||moi) OR lot->>'locataire' IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','pas_mon_bail');END IF;
  ELSE
   -- Une liberation de miroir ne resilie pas le bail canonique et n'expulse personne.
   IF EXISTS(SELECT 1 FROM public.locations_actives WHERE country=t.country AND data->>'city'=etat->>'city' AND data->>'buildingId'=t.building_id AND data->>'roomId'='lot_dyn_'||regexp_replace(idlot,'[^A-Za-z0-9_-]','_','g')) THEN RETURN jsonb_build_object('ok',false,'raison','bail_encore_actif');END IF;
   IF nullif(lot->>'locataire','') IS NOT NULL AND lot->>'locataire' NOT IN(moi,'pj:'||moi) THEN
    -- Meme autorite que le chantier pour PJ, organisation et commune ; aucun titre de presentation.
    PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire',t.country,etat->>'city');
   END IF;
  END IF;
 END LOOP;
 FOR lot IN SELECT value FROM jsonb_array_elements(lots) LOOP
  nouveau:=lot;
  IF lot->>'id'=ANY(vus) THEN
   nouveau:=CASE WHEN p_acte='lot_louer' THEN lot||jsonb_build_object('locataire',moi) WHEN p_acte='lot_bail_libere' THEN lot||jsonb_build_object('locataire',NULL) ELSE lot-'propositionAgrandissement' END;
  END IF;
  modifie:=modifie OR nouveau<>lot;sortie:=sortie||jsonb_build_array(nouveau);
 END LOOP;
 IF modifie THEN
  etat:=etat||jsonb_build_object('subdivisions',sortie,'lotsHistorique',coalesce(etat->'lotsHistorique','[]')||jsonb_build_array(jsonb_build_object('acte',p_acte,'acteur',moi,'date',statement_timestamp(),'lots',to_jsonb(vus))));
  UPDATE public.terrains_etat SET data=etat::text,updated_at=now() WHERE id=t.id;
 END IF;
 RETURN jsonb_build_object('ok',true,'etat',etat,'lots',sortie,'rejeu',NOT modifie,'retires',0);
END;$function$;

-- terrain_negociation_conclure(text,text,integer,uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_negociation_conclure(p_terrain text, p_occupation text, p_montant integer, p_requete uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text:=public.mon_personnage();p record;r record;c jsonb;e jsonb;cle text;solde numeric;
 paiement jsonb;resultat jsonb;taux integer;jet integer;accepte boolean;bonus integer:=0;argent integer;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL OR p_montant IS NULL OR p_montant<1 OR nullif(p_occupation,'') IS NULL THEN
  RETURN jsonb_build_object('ok',false,'raison','requete_invalide'); END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
 SELECT n.* INTO r FROM public.terrain_negociations_recus n WHERE n.acteur=p.id AND n.requete=p_requete;
 IF FOUND THEN
  IF r.terrain IS DISTINCT FROM p.country||'_'||p_terrain OR r.occupation IS DISTINCT FROM p_occupation OR r.montant<>p_montant THEN
   RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee'); END IF;
  resultat:=r.resultat||jsonb_build_object('rejeu',true);
  SELECT public.terrain_etat_lire(data) INTO e FROM public.terrains_etat WHERE id=r.terrain;
 ELSE
  c:=public.terrain_negociation_preparer(p_terrain);
  IF c->>'ok' IS DISTINCT FROM 'true' THEN RETURN c; END IF;
  IF c->>'occupation' IS DISTINCT FROM p_occupation THEN RETURN jsonb_build_object('ok',false,'raison','occupation_modifiee','etat',c->'etat'); END IF;
  IF p_montant<(c->>'minimum')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','offre_trop_faible','minimum',c->'minimum','dernierRefus',c->'dernierRefus'); END IF;
  SELECT coalesce(cb.solde,0) INTO solde FROM public.comptes_bancaires cb WHERE cb.personnage=acteur AND cb.banque='nationale' FOR UPDATE;
  IF coalesce(p.liquide,0)+coalesce(solde,0)<p_montant THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants'); END IF;
  paiement:=public.payer_ordre(acteur,'negocier_squatteurs',1,0);
  IF paiement->>'ok' IS DISTINCT FROM 'true' THEN RETURN paiement; END IF;
  argent:=CASE WHEN p_montant>=4000 THEN 20 WHEN p_montant>=1000 THEN floor(8+(p_montant-1000)::numeric*4/1000)
   WHEN p_montant>=500 THEN floor(5+(p_montant-500)::numeric*3/500) ELSE floor(p_montant::numeric/100) END;
  taux:=greatest(5,least(90,floor((c->>'baseTaux')::numeric+argent+.5)::integer));
  jet:=public.terrain_negociation_jet_interne();accepte:=jet<=taux;e:=c->'etat';cle:=p.country||'_'||p_terrain;
  IF accepte THEN
   IF public.helvetia_debiter_fonds_ordinaires(acteur,p_montant) IS NOT TRUE THEN RAISE EXCEPTION 'paiement_non_confirme'; END IF;
   IF e->>'pnj'='squatter_cool' THEN
    UPDATE public.personnages_donnees SET moral=least(100,coalesce(moral,50)+1) WHERE id=p.id RETURNING moral-coalesce(p.moral,50) INTO bonus;
   END IF;
   e:=public.terrain_etat_fusionner_interne(cle,'{"pnj":null,"pnjData":null,"occupationScellee":true}'::jsonb,p.country);
  ELSE
   INSERT INTO public.terrain_negociations_refus VALUES(p.id,cle,p_occupation,p_montant)
    ON CONFLICT ON CONSTRAINT terrain_negociations_refus_pkey DO UPDATE SET montant=excluded.montant;
  END IF;
  resultat:=jsonb_build_object('ok',true,'accepte',accepte,'pnj',c->'etat'->>'pnj','montant',p_montant,'taux',taux,'jet',jet,'bonusMoral',bonus);
  INSERT INTO public.terrain_negociations_recus(acteur,requete,terrain,occupation,montant,resultat) VALUES(p.id,p_requete,cle,p_occupation,p_montant,resultat);
 END IF;
 SELECT jsonb_build_object('pa',d.pa,'arg',d.arg,'liquide',d.liquide,'moral',d.moral,
  'solde_national',coalesce((SELECT cb.solde FROM public.comptes_bancaires cb WHERE cb.personnage=acteur AND cb.banque='nationale'),0))
  INTO paiement FROM public.personnages_donnees d WHERE id=p.id;
 RETURN resultat||jsonb_build_object('etat',e,'paiement',paiement);
END;$function$;

-- terrain_negociation_jet_interne() -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_negociation_jet_interne()
 RETURNS integer
 LANGUAGE sql
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT 1+floor(random()*100)::integer $function$;

-- terrain_negociation_preparer(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_negociation_preparer(p_terrain text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text:=public.mon_personnage();p record;t record;e jsonb;revision text;dernier integer;
 cha numeric;social numeric;bonus integer;org record;m jsonb;grade integer;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_terrain OR p_terrain NOT LIKE 'terrain-a-batir%' THEN
  RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=p.country||'_'||p_terrain
  AND country=p.country AND building_id=p_terrain FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
 e:=public.terrain_etat_lire(t.data);
 IF e IS NULL OR e->>'city' IS DISTINCT FROM p.current_city THEN RETURN jsonb_build_object('ok',false,'raison','terrain_incoherent'); END IF;
 IF coalesce(e->>'succession_gel','')<>'' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele','etat',e); END IF;
 IF coalesce(e->>'policeAppellee','')<>'' OR coalesce((e->>'enqueteJusqua')::numeric,0)>extract(epoch FROM clock_timestamp())*1000 THEN
  RETURN jsonb_build_object('ok',false,'raison','intervention_en_cours','etat',e); END IF;
 IF coalesce(e->>'pnj','') NOT IN ('squatter_cool','squatter_agr') THEN
  RETURN jsonb_build_object('ok',false,'raison','aucun_squatteur','etat',e); END IF;
 revision:=coalesce(e->>'dateGeneration','historique')||':'||(e->>'pnj');
 SELECT n.montant INTO dernier FROM public.terrain_negociations_refus n WHERE n.acteur=p.id AND n.terrain=t.id AND n.occupation=revision;
 SELECT avg(v) INTO cha FROM (
  SELECT coalesce((p.stats->>'CHA')::numeric,8) v
  UNION ALL SELECT mb.car_cha::numeric
   FROM public.pnj_membres mb JOIN public.pnj_employes_metier em ON em.pnj_id=mb.id
   WHERE mb.proprietaire_pj=acteur AND mb.leader_pj=acteur AND mb.statut='actif'
 ) valeurs;
 cha:=cha-CASE WHEN p.excommunie IS NOT NULL AND p.excommunie<>'null'::jsonb THEN 2 ELSE 0 END;
 IF p.stats_affaiblies ? 'CHA' THEN cha:=greatest(1,floor(cha*greatest(0,least(1,coalesce(p.hp,0)::numeric/100))+.5));
 ELSE cha:=floor(cha+.5); END IF;
 IF p.country='republic' THEN
  SELECT (data->>'social')::numeric INTO social FROM public.indices_villes WHERE id=p.country||'_'||p.current_city;
  social:=coalesce(social,45);
 ELSE social:=CASE p.country WHEN 'narco' THEN 25 WHEN 'soviet' THEN 35 WHEN 'khalija' THEN 40 ELSE 45 END; END IF;
 bonus:=0;
 FOR org IN SELECT data::jsonb d FROM public.organisations LOOP
  SELECT v INTO m FROM jsonb_array_elements(coalesce(org.d->'membres','[]'::jsonb)) v WHERE v->>'nom'=acteur LIMIT 1;
  IF m IS NULL THEN CONTINUE; END IF;
  grade:=coalesce((m->>'gradeIdx')::integer,0);
  bonus:=bonus+CASE org.d->>'type'
   WHEN 'economique' THEN CASE WHEN grade>=3 THEN 30 WHEN grade>=2 THEN 20 WHEN grade>=1 THEN 10 ELSE 0 END
   WHEN 'syndicale' THEN CASE WHEN grade>=2 THEN 25 WHEN grade>=1 THEN 15 ELSE 0 END ELSE 0 END;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'etat',e,'occupation',revision,'dernierRefus',dernier,
  'minimum',greatest(CASE WHEN e->>'pnj'='squatter_agr' THEN 500 ELSE 1 END,coalesce(dernier::numeric+1,1)),
  'baseTaux',50+2*(cha-13)+(social-50)/5+bonus);
END;$function$;

-- terrain_occupation_action(text,text,text,uuid,numeric,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.terrain_occupation_action(p_terrain text, p_action text, p_occupation text, p_requete uuid, p_taux numeric DEFAULT NULL::numeric, p_cout integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE acteur text:=public.mon_personnage();p record;r record;c jsonb;e jsonb;resultat jsonb;paiement jsonb;jet integer;succes boolean;ms numeric:=floor(extract(epoch FROM clock_timestamp())*1000);cle text;entree jsonb;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p_requete IS NULL OR nullif(p_occupation,'') IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','requete_invalide');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 SELECT a.* INTO r FROM public.terrain_actions_recus a WHERE a.acteur=p.id AND a.requete=p_requete;
 IF FOUND THEN
  IF (r.terrain,r.action,r.occupation) IS DISTINCT FROM (p.country||'_'||p_terrain,p_action,p_occupation) THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  IF (r.resultat->>'cout')::integer IS DISTINCT FROM p_cout THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  IF (r.resultat->>'taux')::numeric IS DISTINCT FROM p_taux THEN RETURN jsonb_build_object('ok',false,'raison','requete_reutilisee');END IF;
  SELECT data::jsonb INTO e FROM public.terrains_etat WHERE id=r.terrain;
  RETURN r.resultat||jsonb_build_object('rejeu',true,'etat',e);
 END IF;
 c:=public.terrain_occupation_action_preparer(p_terrain,p_action);
 IF c->>'ok' IS DISTINCT FROM 'true' THEN RETURN c;END IF;
 IF c->>'occupation' IS DISTINCT FROM p_occupation THEN RETURN jsonb_build_object('ok',false,'raison','occupation_modifiee','etat',c->'etat');END IF;
 IF (c->>'taux')::numeric IS DISTINCT FROM p_taux THEN RETURN jsonb_build_object('ok',false,'raison','taux_modifie');END IF;
 IF (c->>'cout')::integer IS DISTINCT FROM p_cout THEN RETURN jsonb_build_object('ok',false,'raison','cout_modifie');END IF;
 -- Verrouiller la contrepartie bancaire avant le payeur, selon le socle financier ordinaire.
 PERFORM 1 FROM public.comptes_bancaires WHERE personnage=acteur AND banque='nationale' FOR UPDATE;
 IF (c->>'cout')::numeric>0 AND coalesce(p.liquide,0)+coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=acteur AND banque='nationale'),0)<(c->>'cout')::numeric THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants');END IF;
 paiement:=public.payer_ordre(acteur,CASE WHEN p_action='cadavre' THEN 'faire_disparaitre_cadavre' ELSE 'appeler_police_terrain' END,(c->>'pa')::integer,0);
 IF paiement->>'ok' IS DISTINCT FROM 'true' THEN RETURN paiement;END IF;
 IF (c->>'cout')::numeric>0 AND public.helvetia_debiter_fonds_ordinaires(acteur,(c->>'cout')::numeric) IS NOT TRUE THEN RAISE EXCEPTION 'paiement_non_confirme';END IF;
 IF p_action='police' THEN succes:=true;jet:=NULL;ELSE jet:=public.terrain_negociation_jet_interne();succes:=jet<=(c->>'taux')::numeric;END IF;
 e:=c->'etat';cle:=p.country||'_'||p_terrain;
 IF p_action IN('police','corruption_police') AND succes THEN
  e:=e||jsonb_build_object('policeAppellee',ms,'policeInterventionAt',ms+(c->>'delaiHeures')::numeric*3600000,
   'interventionPolice',jsonb_build_object('statut','attente','occupation',p_occupation,'echeance',ms+(c->>'delaiHeures')::numeric*3600000,'requete',p_requete));
 END IF;
 IF p_action='cadavre' THEN
  IF succes THEN
   entree:=jsonb_build_object('type','cadavre_dissimule','auteur',acteur,'date',ms,'prescriptionAt',ms+(c->>'prescriptionJours')::numeric*86400000);
   e:=e||jsonb_build_object('pnj',NULL,'pnjData',NULL,'occupationScellee',true,'cadavreDisparuAt',ms,'prescriptionAt',entree->'prescriptionAt','actesIllegaux',coalesce(e->'actesIllegaux','[]')||jsonb_build_array(entree));
  ELSE
   entree:=jsonb_build_object('id','cadavre-'||p_requete,'type','suspicion_cadavre','terrain',p_terrain,'debut',ms,'fin',ms+86400000);
   paiement:=public.recherche_inscrire(entree);
   IF paiement->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'recherche_non_confirmee';END IF;
  END IF;
 END IF;
 IF p_action<>'police' THEN
  UPDATE public.personnages_donnees SET resources=coalesce(resources,'{}')||jsonb_build_object('dis',greatest(0,coalesce((resources->>'dis')::numeric,50)-CASE WHEN succes THEN 5 WHEN p_action='cadavre' THEN 20 ELSE 15 END)),
   hp=greatest(0,hp-CASE WHEN p_action='cadavre' AND NOT succes THEN 5 ELSE 0 END),updated_at=clock_timestamp() WHERE id=p.id;
 END IF;
 -- Meme l'appel legal change la revision : une sauvegarde anterieure ne peut republier ses PA.
 UPDATE public.personnages_donnees SET updated_at=clock_timestamp() WHERE id=p.id;
 UPDATE public.terrains_etat SET data=e::text,updated_at=now() WHERE id=cle;
 resultat:=jsonb_build_object('ok',true,'succes',succes,'action',p_action,'taux',c->'taux','jet',jet,'cout',c->'cout','pa',c->'pa','delaiHeures',c->'delaiHeures','prescriptionJours',c->'prescriptionJours');
 INSERT INTO public.terrain_actions_recus VALUES(p.id,p_requete,cle,p_occupation,p_action,resultat);
 RETURN resultat||jsonb_build_object('etat',e);
END;$function$;
