-- Fonctions et procedures stockees
-- ============================================================================
-- BASELINE Human Gambit -- domaine economie -- phase 20 : fonctions
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

-- creer_fonds_commerce(text,text,text,integer,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.creer_fonds_commerce(p_proprietaire text, p_bail_id text, p_fonds_id text, p_apport integer, p_enseigne text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bail jsonb;
  v_apport integer := GREATEST(0, COALESCE(p_apport, 0));
  v_lot text;
  v_deja integer;
  v_vocation text;
BEGIN
  IF COALESCE(p_proprietaire, '') = '' OR COALESCE(p_bail_id, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  -- Reference TYPEE, comme tout le reste de cette fonction : `mouvement_titulaire` plus bas et
  -- la comparaison au locataire du bail acceptent deja les deux formes. Seule cette garde
  -- exigeait un nom nu, ce qui tuait le chemin doGererFondsCommerce (ctx.ref = 'pj:<nom>').
  IF NOT public.acteur_est_moi(p_proprietaire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_titulaire');
  END IF;
  SELECT count(*) INTO v_deja FROM entreprises WHERE id = p_fonds_id;
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_id_deja_pris'; END IF;
  SELECT data INTO v_bail FROM locations_actives WHERE id = p_bail_id FOR UPDATE;
  IF v_bail IS NULL THEN RAISE EXCEPTION 'bail_absent'; END IF;
  IF (v_bail ->> 'locataire') IS DISTINCT FROM p_proprietaire
     AND ('pj:' || COALESCE(v_bail ->> 'locataire', '')) IS DISTINCT FROM p_proprietaire THEN
    RAISE EXCEPTION 'pas_titulaire';
  END IF;

  v_vocation := public.local_vocation_commerciale(v_bail ->> 'buildingId');
  IF v_vocation IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'local_non_commercial',
                              'batiment', v_bail ->> 'buildingId');
  END IF;

  SELECT count(*) INTO v_deja FROM entreprises
   WHERE data -> 'implantation' ->> 'bailId' = p_bail_id
     AND COALESCE(data ->> 'statut', 'actif') = 'actif';
  IF v_deja > 0 THEN RAISE EXCEPTION 'fonds_deja_present'; END IF;
  IF v_apport > 0 THEN
    IF NOT mouvement_titulaire(p_proprietaire, -v_apport) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
    END IF;
  ELSE
    IF NOT mouvement_titulaire(p_proprietaire, 0) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'proprietaire_absent');
    END IF;
  END IF;
  v_lot := v_bail ->> 'lotId';
  INSERT INTO entreprises (id, data, updated_at)
  VALUES (p_fonds_id, jsonb_build_object(
    'id', p_fonds_id,
    'version', 2,
    'type', 'fonds_commerce',
    'enseigne', COALESCE(NULLIF(btrim(COALESCE(p_enseigne, '')), ''), 'Fonds de commerce'),
    'proprietaire', p_proprietaire,
    'statut', 'actif',
    'caisse', v_apport,
    'implantation', jsonb_build_object(
      'country', v_bail ->> 'country', 'city', v_bail ->> 'city',
      'buildingId', v_bail ->> 'buildingId', 'roomId', v_bail ->> 'roomId',
      'lotId', v_lot, 'localKey', v_bail ->> 'localKey', 'bailId', p_bail_id,
      'vocation', v_vocation),
    'typesAutorises',      '[]'::jsonb,
    'references',          '{}'::jsonb,
    'stockReferences',     '{}'::jsonb,
    'coutMoyenReferences', '{}'::jsonb,
    'stockMatieres',       '{}'::jsonb,
    'coutMoyenMatieres',   '{}'::jsonb,
    'stockProduits',       '{}'::jsonb,
    'historique', jsonb_build_array(jsonb_build_object(
      'evenement', 'creation', 'proprietaire', p_proprietaire, 'apport', v_apport,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS')))
  ), now());
  UPDATE locations_actives SET data = v_bail || jsonb_build_object('fondsId', p_fonds_id) WHERE id = p_bail_id;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'caisse', v_apport,
                            'apport', v_apport, 'proprietaire', p_proprietaire,
                            'vocation', v_vocation, 'typesMax', public.fonds_types_max(p_proprietaire));
END;
$function$;

-- creer_oeuvre(text,text,text,text,integer,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.creer_oeuvre(p_auteur text, p_type text, p_titre text, p_country text, p_jour integer, p_contenu text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_auteur  text := NULLIF(btrim(COALESCE(p_auteur, '')), '');
  v_type    text := lower(btrim(COALESCE(p_type, '')));
  v_titre   text := btrim(COALESCE(p_titre, ''));
  v_contenu text := COALESCE(p_contenu, '');
  v_data    jsonb;
  v_id      text;
  v_deja    text;
BEGIN
  PERFORM public.exiger_acteur(p_auteur);
  IF v_titre = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'titre_requis'); END IF;
  IF length(v_titre) > 200 THEN RETURN jsonb_build_object('ok', false, 'raison', 'titre_trop_long'); END IF;
  IF v_type !~ '^[a-z][a-z0-9_]{1,39}$' THEN RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide'); END IF;
  IF length(v_contenu) > 200000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'contenu_trop_volumineux'); END IF;
  IF v_auteur IS NOT NULL AND NOT ref_patrimoine_existe(v_auteur) THEN RETURN jsonb_build_object('ok', false, 'raison', 'auteur_inexistant'); END IF;
  v_data := COALESCE(p_data, '{}'::jsonb);
  IF jsonb_typeof(v_data) <> 'object' THEN v_data := '{}'::jsonb; END IF;
  v_data := v_data - 'id' - 'auteur' - 'created_at' - 'updated_at';
  IF length(v_data::text) > 8000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'data_trop_volumineux'); END IF;
  SELECT id INTO v_deja FROM oeuvres WHERE type = v_type AND titre = v_titre AND COALESCE(auteur, '') = COALESCE(v_auteur, '') LIMIT 1;
  IF v_deja IS NOT NULL THEN RETURN jsonb_build_object('ok', true, 'id', v_deja, 'doublon', true); END IF;
  v_id := 'oeuvre-' || extract(epoch from clock_timestamp())::bigint || '-' || substr(md5(random()::text || COALESCE(v_auteur, '') || v_titre), 1, 8);
  INSERT INTO oeuvres (id, type, titre, auteur, country, jour, contenu, data)
  VALUES (v_id, v_type, v_titre, v_auteur, NULLIF(btrim(COALESCE(p_country, '')), ''), p_jour, NULLIF(v_contenu, ''), v_data);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'doublon', false);
END;
$function$;

-- creer_offre(text,text,text,text,integer,bigint,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.creer_offre(p_emetteur text, p_destinataire text, p_type text, p_actif text, p_montant integer, p_duree_ms bigint, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  c_offres_max constant integer := 20;
  c_duree_min constant bigint := 3600000;
  c_duree_max constant bigint := 30 * 24 * 3600000;
  c_duree_defaut constant bigint := 3 * 24 * 3600000;
  v_em text := btrim(COALESCE(p_emetteur, ''));
  v_de text := btrim(COALESCE(p_destinataire, ''));
  v_type text := btrim(COALESCE(p_type, ''));
  v_actif text := NULLIF(btrim(COALESCE(p_actif, '')), '');
  v_montant integer := GREATEST(0, COALESCE(p_montant, 0));
  v_duree bigint; v_data jsonb; v_id text; v_deja text; v_ouvertes integer; v_fonds jsonb; v_bail jsonb; v_locataire text; v_bailleur text;
BEGIN
  PERFORM public.exiger_acteur(p_emetteur);
  IF v_em = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_requis'); END IF;
  IF v_de = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_requis'); END IF;
  IF v_em = v_de THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_identique'); END IF;
  IF v_type NOT IN ('vente_objet', 'vente_fonds', 'resiliation_amiable', 'prestation') THEN RETURN jsonb_build_object('ok', false, 'raison', 'type_invalide'); END IF;
  IF NOT ref_patrimoine_existe(v_em) THEN RETURN jsonb_build_object('ok', false, 'raison', 'emetteur_inexistant'); END IF;
  IF NOT ref_patrimoine_existe(v_de) THEN RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_inexistant'); END IF;
  v_duree := COALESCE(NULLIF(p_duree_ms, 0), c_duree_defaut);
  IF v_duree < c_duree_min THEN v_duree := c_duree_min; END IF;
  IF v_duree > c_duree_max THEN v_duree := c_duree_max; END IF;
  v_data := COALESCE(p_data, '{}'::jsonb);
  IF jsonb_typeof(v_data) <> 'object' THEN v_data := '{}'::jsonb; END IF;
  v_data := v_data - 'id' - 'type' - 'emetteur' - 'destinataire' - 'montant' - 'statut' - 'expire_a' - 'created_at' - 'resolu_a';
  IF length(v_data::text) > 4000 THEN RETURN jsonb_build_object('ok', false, 'raison', 'termes_trop_volumineux'); END IF;
  IF v_type = 'vente_fonds' THEN
    IF v_actif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_requis'); END IF;
    SELECT data INTO v_fonds FROM entreprises WHERE id = v_actif;
    IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
    IF (v_fonds ->> 'proprietaire') IS DISTINCT FROM v_em THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  ELSIF v_type = 'resiliation_amiable' THEN
    IF v_actif IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'bail_requis'); END IF;
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_actif;
    IF v_bail IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'bail_absent'); END IF;
    v_locataire := COALESCE(v_bail ->> 'locataireRef', 'pj:' || COALESCE(v_bail ->> 'locataire', ''));
    SELECT (data::jsonb ->> 'proprietaire') INTO v_bailleur FROM terrains_etat WHERE id = (v_bail ->> 'country') || '_' || (v_bail ->> 'buildingId');
    IF NOT ((v_em = v_locataire AND v_de = v_bailleur) OR (v_em = v_bailleur AND v_de = v_locataire)) THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_partie_au_bail'); END IF;
  END IF;
  SELECT count(*) INTO v_ouvertes FROM offres WHERE emetteur = v_em AND statut = 'ouverte' AND expire_a > now();
  IF v_ouvertes >= c_offres_max THEN RETURN jsonb_build_object('ok', false, 'raison', 'quota_offres_ouvertes', 'plafond', c_offres_max); END IF;
  SELECT id INTO v_deja FROM offres WHERE emetteur = v_em AND destinataire = v_de AND type = v_type AND COALESCE(actif, '') = COALESCE(v_actif, '') AND montant = v_montant AND statut = 'ouverte' AND expire_a > now() LIMIT 1;
  IF v_deja IS NOT NULL THEN RETURN jsonb_build_object('ok', true, 'id', v_deja, 'doublon', true); END IF;
  v_id := 'offre-' || extract(epoch from clock_timestamp())::bigint || '-' || substr(md5(random()::text || v_em || v_de), 1, 8);
  INSERT INTO offres (id, type, emetteur, destinataire, actif, montant, statut, data, expire_a)
  VALUES (v_id, v_type, v_em, v_de, v_actif, v_montant, 'ouverte', v_data, now() + make_interval(secs => v_duree / 1000.0));
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'doublon', false, 'statut', 'ouverte', 'montant', v_montant, 'expireDansMs', v_duree);
END;
$function$;

-- employer_fonds(text,text,text,text,integer,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.employer_fonds(p_employeur text, p_fonds_id text, p_salarie text, p_role text, p_taux integer, p_actif boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_fonds jsonb; v_salaries jsonb; v_trouve boolean:=false; v_i integer; v_taux integer:=GREATEST(0,COALESCE(p_taux,0));
BEGIN
  PERFORM public.exiger_acteur(p_employeur);
  IF COALESCE(p_employeur,'')='' OR COALESCE(p_fonds_id,'')='' OR COALESCE(p_salarie,'')='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  IF p_employeur=p_salarie THEN RETURN jsonb_build_object('ok',false,'raison','auto_embauche'); END IF;
  SELECT data INTO v_fonds FROM entreprises WHERE id=p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','fonds_absent'); END IF;
  IF (v_fonds->>'proprietaire') IS DISTINCT FROM p_employeur THEN RETURN jsonb_build_object('ok',false,'raison','pas_proprietaire'); END IF;
  IF left(p_salarie,3)='pj:' AND NOT EXISTS(SELECT 1 FROM personnages WHERE name=substr(p_salarie,4)) THEN RETURN jsonb_build_object('ok',false,'raison','salarie_absent'); END IF;
  v_salaries:=COALESCE(v_fonds->'salaries','[]'::jsonb);
  IF jsonb_array_length(v_salaries)>0 THEN
    FOR v_i IN 0..jsonb_array_length(v_salaries)-1 LOOP
      IF (v_salaries->v_i->>'ref')=p_salarie THEN
        v_salaries:=jsonb_set(v_salaries,ARRAY[v_i::text],(v_salaries->v_i)||jsonb_build_object('role',COALESCE(NULLIF(btrim(COALESCE(p_role,'')),''),'Employé'),'tauxHoraire',v_taux,'actif',COALESCE(p_actif,true)));
        v_trouve:=true;
      END IF;
    END LOOP;
  END IF;
  IF NOT v_trouve THEN
    IF COALESCE(p_actif,true) IS NOT TRUE THEN RETURN jsonb_build_object('ok',false,'raison','salarie_inconnu'); END IF;
    v_salaries:=v_salaries||jsonb_build_array(jsonb_build_object('ref',p_salarie,'role',COALESCE(NULLIF(btrim(COALESCE(p_role,'')),''),'Employé'),'tauxHoraire',v_taux,'actif',true,'depuis',to_char(now() AT TIME ZONE 'Europe/Paris','YYYY-MM-DD')));
  END IF;
  UPDATE entreprises SET data=jsonb_set(v_fonds,'{salaries}',v_salaries),updated_at=now() WHERE id=p_fonds_id;
  RETURN jsonb_build_object('ok',true,'salarie',p_salarie,'actif',COALESCE(p_actif,true),'tauxHoraire',v_taux,'nouveau',NOT v_trouve);
END;
$function$;

-- entrepot_caisse_id(text) -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_caisse_id(p_entrepot_id text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT e.country || '_entrepot_' || e.city
    FROM public.batiments_etat e
    JOIN public.villes v ON v.pays = e.country AND v.ville = e.city
   WHERE e.id = p_entrepot_id;
$function$;

-- entrepot_caisse_lire(text) -> numeric | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_caisse_lire(p_id text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT CASE WHEN jsonb_typeof(c.data -> 'solde') = 'number'
                               THEN (c.data ->> 'solde')::numeric ELSE 0 END
                     FROM public.caisses_batiments c
                    WHERE c.id = public.entrepot_caisse_id(p_id)), 0);
$function$;

-- entrepot_caisse_mouvement(text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_caisse_mouvement(p_entrepot_id text, p_delta numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_caisse text; v_rep jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF p_delta IS NULL OR p_delta = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_nul');
  END IF;
  v_caisse := public.entrepot_caisse_id(p_entrepot_id);
  IF v_caisse IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree',
                              'entrepot', p_entrepot_id);
  END IF;
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse, p_delta, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_rep->>'raison', 'mouvement_refuse'),
                              'caisse', v_caisse);
  END IF;
  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse, 'delta', p_delta,
                            'solde', (v_rep->>'solde')::numeric);
END;
$function$;

-- entrepot_capacite_disponible(text,text) -> integer | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_capacite_disponible(p_entrepot_id text, p_ressource text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT greatest(0, public.capacite_entrepot()
    - coalesce((SELECT (public.batiment_etat_lire(data)->'entrepot'->'stock'->>p_ressource)::numeric
                  FROM public.batiments_etat WHERE id = p_entrepot_id), 0)
    - coalesce((SELECT sum(quantite) FROM public.entrepot_transits
                 WHERE destination_id = p_entrepot_id AND ressource = p_ressource), 0))::int;
$function$;

-- entrepot_commander(text,text,integer,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_commander(p_acteur text, p_ressource text, p_quantite integer, p_fournisseur_type text, p_fournisseur_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_dest_id text; v_dest_ville text;
  v_prix numeric; v_fret numeric := 0; v_total numeric;
  v_cap integer; v_delai integer; v_libelle text;
  v_etat_d jsonb; v_ent_d jsonb; v_caisse_d numeric;
  v_etat_f jsonb; v_ent_f jsonb; v_caisse_f numeric; v_stock_f numeric;
  v_ids text[]; v_i text; v_arrivee date;
  v_caisse_dest_id text; v_caisse_four_id text; v_rep jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  IF p_quantite IS NULL OR p_quantite <= 0 OR p_quantite <> floor(p_quantite) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue');
  END IF;

  SELECT entrepot_id, ville INTO v_dest_id, v_dest_ville
    FROM public.entrepot_du_directeur(p_acteur);
  IF v_dest_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu');
  END IF;
  IF p_fournisseur_type = 'entrepot' AND p_fournisseur_id = v_dest_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_est_soi_meme');
  END IF;

  -- LA CAISSE CANONIQUE DU DESTINATAIRE. Fail-closed : un entrepot sans caisse declaree -- une
  -- ville de test -- ne commande rien, au lieu de voir sa cle fabriquee dans un blob.
  v_caisse_dest_id := public.entrepot_caisse_id(v_dest_id);
  IF v_caisse_dest_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree',
                              'entrepot', v_dest_id);
  END IF;

  -- --- Verrouillage ordonne des lignes touchees --------------------------------
  v_ids := CASE WHEN p_fournisseur_type IN ('entrepot', 'port')
                THEN ARRAY(SELECT unnest(ARRAY[v_dest_id, p_fournisseur_id]) ORDER BY 1)
                ELSE ARRAY[v_dest_id] END;
  FOREACH v_i IN ARRAY v_ids LOOP
    PERFORM 1 FROM public.batiments_etat WHERE id = v_i FOR UPDATE;
  END LOOP;

  SELECT public.batiment_etat_lire(data) INTO v_etat_d FROM public.batiments_etat WHERE id = v_dest_id;
  IF v_etat_d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent_d := coalesce(v_etat_d->'entrepot', '{}'::jsonb);
  v_caisse_d := public.entrepot_caisse_lire(v_dest_id);

  -- --- Le fournisseur : prix, stock, delai, libelle -----------------------------
  IF p_fournisseur_type IN ('entrepot', 'port') THEN
    v_delai := 1;
    SELECT public.batiment_etat_lire(data) INTO v_etat_f FROM public.batiments_etat WHERE id = p_fournisseur_id;
    IF v_etat_f IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_introuvable'); END IF;

    IF p_fournisseur_type = 'entrepot' THEN
      v_ent_f := coalesce(v_etat_f->'entrepot', '{}'::jsonb);
      v_stock_f := coalesce((v_ent_f->'stock'->>p_ressource)::numeric, 0);
      -- Prix AFFICHE par le fournisseur : son prix manuel s'il en a pose un, sinon le prix de
      -- reference. Le vendeur ne peut pas refuser : s'il affiche, il vend.
      v_prix := coalesce((v_ent_f->'prixManuel'->>p_ressource)::numeric,
                         (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource));
      v_caisse_four_id := public.entrepot_caisse_id(p_fournisseur_id);
      IF v_caisse_four_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_fournisseur_non_declaree',
                                  'entrepot', p_fournisseur_id);
      END IF;
    ELSE
      -- Port industriel : son stock institutionnel en attente de repartition, au prix de reference.
      v_ent_f := coalesce(v_etat_f->'port', '{}'::jsonb);
      v_stock_f := coalesce((v_ent_f->'stock'->>p_ressource)::numeric, 0);
      v_prix := (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource);
    END IF;

    IF v_stock_f < p_quantite THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_fournisseur_insuffisant',
                                'disponible', v_stock_f);
    END IF;
    v_libelle := p_fournisseur_id;
  ELSIF p_fournisseur_type = 'etranger' THEN
    v_delai := 2;
    SELECT prix_unitaire, libelle INTO v_prix, v_libelle
      FROM public.fournisseurs_etrangers()
     WHERE pays = p_fournisseur_id AND ressource = p_ressource;
    IF v_prix IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_introuvable');
    END IF;
    -- EMBARGO : seules les NOUVELLES commandes sont interdites. Ce qui est deja paye et en
    -- transit poursuit sa route -- aucun effet retroactif.
    IF public.embargo_actif('republic', p_fournisseur_id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'embargo', 'pays', p_fournisseur_id);
    END IF;
    v_fret := public.fret_unitaire_international();
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_type_inconnu');
  END IF;

  -- --- Capacite du destinataire, transit compris --------------------------------
  v_cap := public.entrepot_capacite_disponible(v_dest_id, p_ressource);
  IF v_cap < p_quantite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_insuffisante',
                              'capacite_disponible', v_cap, 'plafond', public.capacite_entrepot());
  END IF;

  -- --- Tresorerie ---------------------------------------------------------------
  v_total := round(p_quantite * (v_prix + v_fret), 2);
  IF v_caisse_d < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tresorerie_insuffisante',
                              'caisse', v_caisse_d, 'montant', v_total);
  END IF;

  -- --- Mouvements : tout ou rien -------------------------------------------------
  -- LE DEBIT PASSE PAR LA PRIMITIVE VERROUILLEE. L'UPDATE du blob qui ne portait que la caisse
  -- disparait : le blob ne contient plus de tresorerie.
  v_rep := public.caisse_institution_mouvement(v_caisse_dest_id, -v_total, true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_rep->>'raison', 'debit_refuse'),
                              'caisse', v_caisse_d, 'montant', v_total);
  END IF;

  IF p_fournisseur_type IN ('entrepot', 'port') THEN
    -- Le stock part immediatement de chez le fournisseur : il ne peut pas etre vendu deux fois.
    -- Le fret n'est PAS verse au vendeur -- c'est un cout logistique absorbe.
    IF p_fournisseur_type = 'entrepot' THEN
      v_caisse_f := public.entrepot_caisse_lire(p_fournisseur_id);
      -- Le blob du fournisseur ne garde que son STOCK : sa recette va a sa caisse.
      v_ent_f := v_ent_f
        || jsonb_build_object('stock', jsonb_set(coalesce(v_ent_f->'stock', '{}'::jsonb),
                                                 ARRAY[p_ressource], to_jsonb(v_stock_f - p_quantite)));
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat_f || jsonb_build_object('entrepot', v_ent_f))::text),
             updated_at = now()
       WHERE id = p_fournisseur_id;
      PERFORM public.caisse_institution_mouvement(v_caisse_four_id,
                                                  round(p_quantite * v_prix, 2), true);
    ELSE
      v_ent_f := v_ent_f
        || jsonb_build_object('stock', jsonb_set(coalesce(v_ent_f->'stock', '{}'::jsonb),
                                                 ARRAY[p_ressource], to_jsonb(v_stock_f - p_quantite)));
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat_f || jsonb_build_object('port', v_ent_f))::text),
             updated_at = now()
       WHERE id = p_fournisseur_id;
      -- Le produit de la vente du Port va a SA caisse institutionnelle, la ou vont deja ses
      -- autres recettes (criee, dedouanement).
      PERFORM public.caisse_institution_mouvement('republic_port-sainte-marie',
                                                  round(p_quantite * v_prix, 2), false);
    END IF;
  END IF;

  v_arrivee := ((now() AT TIME ZONE 'utc')::date + v_delai);
  INSERT INTO public.entrepot_transits (destination_id, ressource, quantite, origine_type,
    origine_id, origine_libelle, prix_unitaire, fret_unitaire, montant_total, arrivee_le, commande_par)
  VALUES (v_dest_id, p_ressource, p_quantite, p_fournisseur_type,
    CASE WHEN p_fournisseur_type = 'etranger' THEN NULL ELSE p_fournisseur_id END,
    v_libelle, v_prix, v_fret, v_total, v_arrivee, p_acteur);

  INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
    quantite, prix_unitaire, fret_unitaire, montant, statut, arrivee_le, acteur)
  VALUES (v_dest_id, 'commande_directe', 'entree', v_libelle, p_ressource,
    p_quantite, v_prix, v_fret, v_total, 'en_transit', v_arrivee, p_acteur);

  IF p_fournisseur_type = 'entrepot' THEN
    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
      quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
    VALUES (p_fournisseur_id, 'commande_directe', 'sortie', v_dest_id, p_ressource,
      p_quantite, v_prix, 0, round(p_quantite * v_prix, 2), 'comptant', p_acteur);
  END IF;

  RETURN jsonb_build_object('ok', true, 'ressource', p_ressource, 'quantite', p_quantite,
    'prix_unitaire', v_prix, 'fret_unitaire', v_fret, 'montant', v_total,
    'arrivee_le', v_arrivee, 'delai_jours', v_delai,
    'caisse', round(v_caisse_d - v_total, 2), 'fournisseur', v_libelle);
END; $function$;

-- entrepot_du_directeur(text) -> TABLE(entrepot_id text, ville text, batiment text) | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_du_directeur(p_acteur text)
 RETURNS TABLE(entrepot_id text, ville text, batiment text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT 'republic_' || e.ville || '_' || e.building_id, e.ville, e.building_id
    FROM public.personnages_donnees p
    JOIN public.entrepots_par_ville e ON e.ville = p.poste->>'city'
   WHERE p.name = p_acteur AND p.poste->>'id' = 'directeur_entrepot';
$function$;

-- entrepot_fixer_desiderata(text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_fixer_desiderata(p_acteur text, p_desiderata jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_id text; v_etat jsonb; v_ent jsonb; v_d jsonb := '{}'::jsonb;
        v_cle text; v_val numeric; v_cap integer := public.capacite_entrepot();
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT entrepot_id INTO v_id FROM public.entrepot_du_directeur(p_acteur);
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu');
  END IF;
  IF p_desiderata IS NULL OR jsonb_typeof(p_desiderata) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'desiderata_absents');
  END IF;

  -- Validation AVANT toute ecriture : une seule valeur invalide annule l'ensemble.
  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(p_desiderata) LOOP
    IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    IF v_val IS NULL OR NOT (v_val = v_val) OR v_val < 0 OR v_val > v_cap OR v_val <> floor(v_val) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'desiderata_invalide', 'cle', v_cle,
                                'min', 0, 'max', v_cap);
    END IF;
    v_d := jsonb_set(v_d, ARRAY[v_cle], to_jsonb(v_val::int));
  END LOOP;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
           v_ent || jsonb_build_object('desiderata', v_d, 'desiderataPar', p_acteur)))::text),
         updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'desiderata', v_d, 'entrepot', v_id);
END; $function$;

-- entrepot_livrer_transits() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_livrer_transits()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ligne record; v_etat jsonb; v_ent jsonb; v_stock numeric; v_place integer;
  v_recu integer; v_perdu integer; v_livrees int := 0; v_unites int := 0; v_pertes int := 0;
BEGIN
  FOR v_ligne IN
    SELECT * FROM public.entrepot_transits
     WHERE arrivee_le <= (now() AT TIME ZONE 'utc')::date
     ORDER BY cree_le
     FOR UPDATE
  LOOP
    SELECT public.batiment_etat_lire(data) INTO v_etat
      FROM public.batiments_etat WHERE id = v_ligne.destination_id FOR UPDATE;
    IF v_etat IS NULL THEN CONTINUE; END IF;   -- entrepot disparu : la ligne reste, on reessaiera

    v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);
    v_stock := coalesce((v_ent->'stock'->>v_ligne.ressource)::numeric, 0);
    -- La place est recalculee A LA LIVRAISON : entre la commande et l'arrivee, une livraison
    -- automatique a pu remplir l'entrepot. La capacite reservee a la commande rend ce cas tres
    -- improbable, mais on ne fait jamais deborder un entrepot en silence.
    v_place := greatest(0, public.capacite_entrepot() - v_stock::int);
    v_recu := least(v_ligne.quantite, v_place);
    v_perdu := v_ligne.quantite - v_recu;

    IF v_recu > 0 THEN
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
               v_ent || jsonb_build_object('stock',
                 jsonb_set(coalesce(v_ent->'stock', '{}'::jsonb),
                           ARRAY[v_ligne.ressource], to_jsonb(v_stock + v_recu)))))::text),
             updated_at = now()
       WHERE id = v_ligne.destination_id;
    END IF;

    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
      quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
    VALUES (v_ligne.destination_id,
      CASE WHEN v_ligne.origine_type = 'auto' THEN 'approvisionnement_auto' ELSE 'commande_directe' END,
      'entree', v_ligne.origine_libelle, v_ligne.ressource, v_recu,
      v_ligne.prix_unitaire, v_ligne.fret_unitaire, v_ligne.montant_total,
      CASE WHEN v_perdu > 0 THEN 'livre_partiel_capacite' ELSE 'livre' END, v_ligne.commande_par);

    DELETE FROM public.entrepot_transits WHERE id = v_ligne.id;
    v_livrees := v_livrees + 1;
    v_unites := v_unites + v_recu;
    v_pertes := v_pertes + v_perdu;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'lignes_livrees', v_livrees,
                            'unites_livrees', v_unites, 'unites_perdues_capacite', v_pertes);
END; $function$;

-- entrepot_reverser(text,numeric,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_reverser(p_entrepot_id text, p_montant numeric, p_mode text, p_acteur text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_roulement constant numeric := 5000;   -- fonds de roulement permanent (regle GD)
  v_pays text; v_ville text; v_caisse_id text; v_caisse numeric;
  v_mairie text; v_verse numeric; v_jour date; v_id text; v_rep jsonb;
BEGIN
  -- LES COLONNES FONT AUTORITE. Voir l'en-tete de cette migration : la derivation par
  -- split_part rendait « ville » au lieu de « ville_a », et le reversement etait donc
  -- impossible ailleurs qu'a la capitale.
  SELECT e.country, e.city INTO v_pays, v_ville
    FROM public.batiments_etat e WHERE e.id = p_entrepot_id;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable');
  END IF;

  v_caisse_id := public.entrepot_caisse_id(p_entrepot_id);
  IF v_caisse_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree',
                              'ville', v_ville);
  END IF;

  -- Verrou de ligne : deux reversements simultanes se serialisent.
  SELECT CASE WHEN jsonb_typeof(c.data -> 'solde') = 'number'
              THEN (c.data ->> 'solde')::numeric ELSE 0 END
    INTO v_caisse
    FROM public.caisses_batiments c WHERE c.id = v_caisse_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree',
                              'caisse', v_caisse_id);
  END IF;

  v_mairie := public.salaire_caisse_de('maire', v_pays, v_ville);
  IF v_mairie IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mairie_introuvable', 'ville', v_ville);
  END IF;

  IF p_mode = 'automatique' THEN
    v_verse := greatest(0, v_caisse - c_roulement);
  ELSE
    -- Virement volontaire : borne par la tresorerie REELLE, jamais par ce que
    -- le client annonce.
    v_verse := least(greatest(coalesce(p_montant, 0), 0), greatest(v_caisse, 0));
  END IF;

  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'caisse', v_caisse,
                              'roulement', c_roulement);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id := p_entrepot_id || ':' || v_jour::text ||
          CASE WHEN p_mode = 'volontaire'
               THEN ':v' || (extract(epoch from clock_timestamp())*1000)::bigint
               ELSE '' END;

  -- L'anti-rejeu EST la cle : un reversement automatique deja fait aujourd'hui
  -- ne peut pas etre rejoue, meme par deux crons concurrents.
  BEGIN
    INSERT INTO public.entrepots_reversements (id, entrepot_id, mairie_id, jour, montant, mode, acteur)
    VALUES (v_id, p_entrepot_id, v_mairie, v_jour, v_verse, p_mode, p_acteur);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reverse_aujourdhui',
                              'jour', v_jour, 'caisse', v_caisse);
  END;

  -- DEBIT DE L'ENTREPOT PUIS CREDIT DE LA MAIRIE, par la primitive verrouillee. Si le credit
  -- echouait, la levee annule le debit : la transaction est la frontiere.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse_id, -v_verse, true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    PERFORM set_config('rp.caisse_interne', '', true);
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_rep->>'raison','debit_refuse'));
  END IF;
  v_rep := public.caisse_institution_mouvement(v_mairie, v_verse, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'reversement_entrepot_credit_refuse:%', coalesce(v_rep->>'raison','?');
  END IF;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'mairie', v_mairie,
                            'caisse', v_caisse - v_verse, 'mode', p_mode, 'jour', v_jour);
END;
$function$;

-- entrepot_virement_mairie(text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepot_virement_mairie(p_entrepot_id text, p_montant numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_ville text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF p_montant IS NULL OR p_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_pays  := split_part(p_entrepot_id, '_', 1);
  v_ville := split_part(p_entrepot_id, '_', 2);

  -- AUTORITE : directeur de CET entrepot, dans SA ville. Le maire et son adjoint
  -- ne sont pas inclus : l'autonomie de la caisse est precisement le sujet.
  IF NOT EXISTS (SELECT 1 FROM public.acteur_poste_courant() a
                  WHERE a.poste_id = 'directeur_entrepot'
                    AND a.pays = v_pays
                    AND coalesce(a.poste_city, '') = v_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante');
  END IF;

  RETURN public.entrepot_reverser(p_entrepot_id, p_montant, 'volontaire', v_moi);
END;
$function$;

-- entrepots_reverser_excedent() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.entrepots_reverser_excedent()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r record; v jsonb; v_total numeric := 0; v_n int := 0; v_detail jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  FOR r IN SELECT e.id FROM public.batiments_etat e
            WHERE e.id LIKE '%\_entrepot-%'
              AND public.batiment_etat_lire(e.data) ? 'entrepot'
            ORDER BY e.id
  LOOP
    v := public.entrepot_reverser(r.id, NULL, 'automatique', NULL);
    IF coalesce((v->>'ok')::boolean, false) AND coalesce((v->>'verse')::numeric, 0) > 0 THEN
      v_total := v_total + (v->>'verse')::numeric;
      v_n := v_n + 1;
      v_detail := v_detail || jsonb_build_array(jsonb_build_object('entrepot', r.id, 'verse', v->>'verse'));
    END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'entrepots', v_n, 'total', v_total, 'detail', v_detail);
END;
$function$;

-- entreprise_acte_preemption(text,text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_acte_preemption(p_acteur text, p_entreprise text, p_libelle_etat text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_r jsonb; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'preemptionEtat','') <> 'attente_acte' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'preemption_introuvable');
  END IF;

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'));
    END IF;
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := (v_data - 'preemptionEtat' - 'preemptionPar')
            || jsonb_build_object('proprietaire',
                 COALESCE(NULLIF(btrim(COALESCE(p_libelle_etat,'')),''), 'État'));
  v_data := public.entreprise_ajouter_historique(v_data, 0,
              'Préemption par l''État, officialisée par le Ministre des Finances', v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'proprietaire', v_data->>'proprietaire',
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- entreprise_acte_rachat(text,text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_acte_rachat(p_acteur text, p_entreprise text, p_ordre text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_prix numeric; v_solde numeric; v_r jsonb; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE((v_data->>'compromis')::boolean, false) IS NOT TRUE
     OR (v_data->>'compromisPar') IS DISTINCT FROM p_acteur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_votre_compromis');
  END IF;
  IF COALESCE(v_data->'pretDemande'->>'statut','') = 'attente_validation' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pret_en_attente');
  END IF;

  v_prix := public.entreprise_prix_rachat(v_data);
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inconnu'); END IF;
  v_solde := GREATEST(0, v_prix - COALESCE((v_data->>'acompte')::numeric, 0));

  IF COALESCE(p_ordre,'') <> '' THEN
    v_r := public.payer_ordre(p_acteur, p_ordre, COALESCE(p_pa,0), COALESCE(p_cost,0));
    IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', COALESCE(v_r->>'raison','paiement_refuse'));
    END IF;
  END IF;

  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_solde) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'solde', v_solde);
  END IF;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := (v_data - 'compromis' - 'compromisPar' - 'acompte' - 'compromisAt'
                    - 'compromisExpireAt')
            || jsonb_build_object('proprietaire', p_acteur);
  v_data := public.entreprise_ajouter_historique(v_data, 0,
              'Rachat de l''entreprise par ' || p_acteur || ' (acte notarié)', v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'solde', v_solde,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur),
    'pa', (SELECT pa FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- entreprise_ajouter_historique(jsonb,numeric,text,integer) -> jsonb | sql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_ajouter_historique(p_data jsonb, p_montant numeric, p_motif text, p_jour integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  SELECT jsonb_set(p_data, '{historique}', (
    SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) FROM (
      SELECT e FROM jsonb_array_elements(
        COALESCE(p_data->'historique', '[]'::jsonb)
        || jsonb_build_array(jsonb_build_object('jour', COALESCE(p_jour,1),
                                                'montant', p_montant, 'motif', p_motif))) e
      OFFSET GREATEST(0, jsonb_array_length(COALESCE(p_data->'historique','[]'::jsonb)) + 1 - 50)
    ) t
  ), true);
$function$;

-- entreprise_assurer_existence(text,text,text,text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_assurer_existence(p_id text, p_type text, p_pays text, p_ville text, p_batiment text, p_room text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_dot record; v_arm record; v_cle text; v_type_attendu text;
  v_id_attendu text; v_param jsonb; v_modifie boolean := false;
  v_k text; v_v jsonb;
BEGIN
  IF COALESCE(p_id,'') = '' OR COALESCE(p_pays,'') = '' OR COALESCE(p_ville,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF NOT public.est_appel_serveur()
     AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = auth.uid()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_id FOR UPDATE;

  IF FOUND THEN
    IF COALESCE((v_data->>'version')::integer, 0) >= 2 THEN
      RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false);
    END IF;
    v_cle := CASE WHEN COALESCE(p_room,'') <> '' THEN p_batiment || '|' || p_room ELSE p_batiment END;
    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;
    IF NOT FOUND THEN
      SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = p_batiment;
    END IF;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false);
    END IF;

    FOR v_v IN SELECT value FROM jsonb_array_elements(v_dot.carte) LOOP
      IF NOT (COALESCE(v_data->'carte','[]'::jsonb) @> jsonb_build_array(v_v)) THEN
        v_data := jsonb_set(v_data, '{carte}', COALESCE(v_data->'carte','[]'::jsonb) || jsonb_build_array(v_v), true);
        v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(v_dot.stock_matieres) LOOP
      IF NOT (COALESCE(v_data->'stockMatieres','{}'::jsonb) ? v_k) THEN
        v_data := jsonb_set(v_data, ARRAY['stockMatieres', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(v_dot.cout_moyen_matieres) LOOP
      IF NOT (COALESCE(v_data->'coutMoyenMatieres','{}'::jsonb) ? v_k) THEN
        v_data := jsonb_set(v_data, ARRAY['coutMoyenMatieres', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    v_param := COALESCE(v_data->'parametres', '{}'::jsonb);
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(v_dot.parametres->'stockMax','{}'::jsonb)) LOOP
      IF NOT (COALESCE(v_param->'stockMax','{}'::jsonb) ? v_k) THEN
        v_param := jsonb_set(v_param, ARRAY['stockMax', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    FOR v_k, v_v IN SELECT key, value FROM jsonb_each(COALESCE(v_dot.parametres->'prixVente','{}'::jsonb)) LOOP
      IF NOT (COALESCE(v_param->'prixVente','{}'::jsonb) ? v_k) THEN
        v_param := jsonb_set(v_param, ARRAY['prixVente', v_k], v_v, true); v_modifie := true;
      END IF;
    END LOOP;
    IF v_modifie THEN
      v_data := jsonb_set(v_data, '{parametres}', v_param, true);
      UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_id;
    END IF;
    RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', false, 'rattrapee', v_modifie);
  END IF;

  IF p_type = 'armurerie' THEN
    v_id_attendu := 'armurerie-' || p_pays || '-' || p_ville;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme');
    END IF;
    SELECT * INTO v_arm FROM public.armureries_dotations WHERE pays = p_pays;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'armurerie_inconnue');
    END IF;
    v_data := jsonb_build_object(
      'id', p_id, 'type', 'armurerie', 'country', p_pays, 'city', p_ville,
      'buildingId', 'armurerie', 'roomId', NULL, 'proprietaire', 'PNJ',
      'caisse', v_arm.caisse, 'stockMatieres', v_arm.stock_matieres,
      'coutMoyenMatieres', '{}'::jsonb, 'stockProduits', '{}'::jsonb,
      'carte', '[]'::jsonb, 'parametres', v_arm.parametres, 'historique', '[]'::jsonb);

  ELSIF p_type = 'imprimerie' THEN
    v_id_attendu := 'imprimerie-' || p_pays || '-' || p_ville || '-' || p_batiment;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.imprimeries_declarees
                    WHERE pays = p_pays AND ville = p_ville AND batiment = p_batiment) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'imprimerie_non_declaree');
    END IF;
    -- Identite de propriete SEULE : la caisse et le stock de bois vivent dans batiments_etat.
    v_data := jsonb_build_object(
      'id', p_id, 'type', 'imprimerie', 'country', p_pays, 'city', p_ville,
      'buildingId', p_batiment, 'roomId', NULL, 'proprietaire', 'PNJ',
      'caisseExterne', jsonb_build_object('table','batiments_etat','sousCle','imprimerie'),
      'historique', '[]'::jsonb);

  ELSE
    v_cle := CASE WHEN COALESCE(p_room,'') <> '' THEN p_batiment || '|' || p_room ELSE p_batiment END;
    SELECT type INTO v_type_attendu FROM public.commerces_types WHERE cle = v_cle;
    IF NOT FOUND THEN
      SELECT type INTO v_type_attendu FROM public.commerces_types WHERE cle = p_batiment;
      v_cle := p_batiment;
    END IF;
    IF v_type_attendu IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'batiment_sans_commerce');
    END IF;
    IF p_type IS DISTINCT FROM v_type_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_non_conforme', 'attendu', v_type_attendu);
    END IF;
    v_id_attendu := p_type || '-' || p_pays || '-' || p_ville || '-' || p_batiment
                    || CASE WHEN COALESCE(p_room,'') <> '' THEN '-' || p_room ELSE '' END;
    IF p_id <> v_id_attendu THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_non_conforme', 'attendu', v_id_attendu);
    END IF;
    SELECT * INTO v_dot FROM public.commerces_dotations WHERE cle = v_cle;
    v_data := jsonb_build_object(
      'id', p_id, 'type', p_type, 'country', p_pays, 'city', p_ville,
      'buildingId', p_batiment, 'roomId', NULLIF(COALESCE(p_room,''), ''),
      'proprietaire', 'PNJ',
      'caisse', COALESCE(v_dot.caisse, 0),
      'stockMatieres', COALESCE(v_dot.stock_matieres, '{}'::jsonb),
      'coutMoyenMatieres', COALESCE(v_dot.cout_moyen_matieres, '{}'::jsonb),
      'stockProduits', '{}'::jsonb,
      'carte', COALESCE(v_dot.carte, '[]'::jsonb),
      'parametres', COALESCE(v_dot.parametres, jsonb_build_object('prixVente','{}'::jsonb,'stockMax','{}'::jsonb)),
      'historique', '[]'::jsonb);
  END IF;

  INSERT INTO public.entreprises (id, data, updated_at) VALUES (p_id, v_data, now())
  ON CONFLICT (id) DO NOTHING;
  SELECT data INTO v_data FROM public.entreprises WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'data', v_data, 'cree', true);
END; $function$;

-- entreprise_mouvement_fiscal(text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_mouvement_fiscal(p_acteur text, p_entreprise text, p_delta numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_caisse numeric; v_reel numeric; v_jour integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  IF p_delta IS NULL OR p_delta = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;

  v_caisse := GREATEST(0, COALESCE((v_data->>'caisse')::numeric, 0));
  -- Regle existante : un prelevement ne peut pas depasser le solde ; un versement est integral.
  v_reel := CASE WHEN p_delta >= 0 THEN p_delta ELSE -LEAST(v_caisse, -p_delta) END;

  SELECT COALESCE(day,1) INTO v_jour FROM public.personnages_donnees WHERE name = p_acteur;
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(v_caisse + v_reel), true);
  v_data := public.entreprise_ajouter_historique(v_data, v_reel,
              CASE WHEN v_reel >= 0 THEN 'Subvention ministérielle' ELSE 'Redressement fiscal' END
              || ' — ' || p_acteur, v_jour);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'montantReel', v_reel, 'caisse', v_caisse + v_reel);
END; $function$;

-- entreprise_preempter(text,text,numeric,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_preempter(p_acteur text, p_entreprise text, p_montant numeric, p_duree integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_prix numeric; v_pays text; v_taux numeric; v_total numeric;
  v_maintenant bigint; v_r jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);
  PERFORM public.exiger_poste('min_fin');

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'proprietaire','') <> 'PNJ' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_preemptable');
  END IF;
  v_maintenant := (extract(epoch from now()) * 1000)::bigint;
  IF (COALESCE((v_data->>'compromis')::boolean, false)
      AND COALESCE((v_data->>'compromisExpireAt')::bigint,0) > v_maintenant)
     OR COALESCE(v_data->>'preemptionEtat','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_preemptable');
  END IF;

  v_prix := public.entreprise_prix_rachat(v_data);
  IF v_prix IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'prix_inconnu'); END IF;
  IF p_montant IS NULL OR p_montant < v_prix OR COALESCE(p_duree,0) <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_insuffisant', 'prix', v_prix);
  END IF;

  v_pays  := COALESCE(v_data->>'country','republic');
  v_taux  := public.taux_pret_nationale(v_pays);
  v_total := round(p_montant * (1 + v_taux / 100));

  -- Mouvements institutionnels atomiques, jamais une lecture-modification-ecriture cliente.
  PERFORM public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', p_montant, false);
  v_r := public.caisse_institution_mouvement(v_pays || '_gouvernement-min_fin', -v_prix, false);
  IF COALESCE((v_r->>'ok')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante');
  END IF;

  v_data := v_data || jsonb_build_object('preemptionEtat', 'attente_acte',
                                         'preemptionPar', p_acteur);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;

  RETURN jsonb_build_object('ok', true, 'prix', v_prix, 'montant', p_montant,
    'montantTotal', v_total, 'mensualite', ceil(v_total / p_duree), 'taux', v_taux);
END; $function$;

-- entreprise_prix_rachat(jsonb) -> numeric | plpgsql | SECURITY INVOKER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_prix_rachat(p_data jsonb)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
DECLARE v_prix numeric; v_type text; v_bat text;
BEGIN
  v_type := COALESCE(p_data->>'type','');
  v_bat  := COALESCE(p_data->>'buildingId','');
  IF v_type = 'armurerie' THEN
    SELECT valeur INTO v_prix FROM public.entreprises_constantes WHERE cle = 'prix_rachat_armurerie';
    RETURN v_prix;
  END IF;
  IF v_type = 'imprimerie' THEN
    SELECT valeur INTO v_prix FROM public.entreprises_constantes WHERE cle = 'prix_rachat_imprimerie';
    RETURN v_prix;
  END IF;
  SELECT prix INTO v_prix FROM public.entreprises_prix_rachat WHERE batiment = v_bat;
  RETURN v_prix;
END; $function$;

-- entreprise_signer_compromis(text,text,numeric,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_signer_compromis(p_acteur text, p_entreprise text, p_pret_montant numeric DEFAULT NULL::numeric, p_pret_duree integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb; v_acompte numeric; v_plafond numeric; v_taux numeric;
  v_total numeric; v_pret jsonb; v_expire bigint; v_maintenant bigint;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF COALESCE(v_data->>'proprietaire','') <> 'PNJ' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_rachetable');
  END IF;
  IF public.entreprise_prix_rachat(v_data) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_rachetable');
  END IF;

  v_maintenant := (extract(epoch from now()) * 1000)::bigint;
  v_expire := COALESCE((v_data->>'compromisExpireAt')::bigint, 0);
  IF COALESCE((v_data->>'compromis')::boolean, false) AND v_expire > v_maintenant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reservee',
                              'par', v_data->>'compromisPar');
  END IF;

  SELECT valeur INTO v_acompte FROM public.entreprises_constantes WHERE cle = 'acompte_compromis';
  IF NOT public.helvetia_debiter_fonds_ordinaires(p_acteur, v_acompte) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'acompte', v_acompte);
  END IF;

  v_data := v_data || jsonb_build_object(
    'compromis', true, 'compromisPar', p_acteur, 'acompte', v_acompte,
    'compromisAt', v_maintenant, 'compromisExpireAt', v_maintenant + 7 * 86400000);

  IF p_pret_montant IS NOT NULL AND p_pret_montant > 0 THEN
    SELECT valeur INTO v_plafond FROM public.entreprises_constantes WHERE cle = 'plafond_pret_compromis';
    IF p_pret_montant > COALESCE(v_plafond, 0) OR COALESCE(p_pret_duree,0) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pret_hors_bornes', 'plafond', v_plafond);
    END IF;
    -- Le taux n'est PAS transmis : il est recalcule depuis l'indice economique reel du pays.
    v_taux  := public.taux_pret_nationale(COALESCE(v_data->>'country','republic'));
    v_total := round(p_pret_montant * (1 + v_taux / 100));
    v_pret  := jsonb_build_object('demandeur', p_acteur, 'montant', p_pret_montant,
                 'montantTotal', v_total, 'duree', p_pret_duree,
                 'mensualite', ceil(v_total / p_pret_duree), 'statut', 'attente_validation');
    v_data := jsonb_set(v_data, '{pretDemande}', v_pret, true);
  END IF;

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true, 'acompte', v_acompte,
    'expireAt', v_maintenant + 7 * 86400000, 'pret', v_pret,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = p_acteur),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = p_acteur));
END; $function$;

-- entreprise_succession_annuler_compromis(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_succession_annuler_compromis(p_acteur text, p_entreprise text, p_succession text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_defunt text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  -- Seul un compromis dont le DEFUNT est l'acheteur peut etre annule ici. Un compromis deja
  -- nettoye n'apparait plus dans le scan du client : on repond ok sans rien ecrire.
  IF (v_data->>'compromisPar') IS DISTINCT FROM v_defunt THEN
    IF v_data ? 'compromisPar' THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_le_compromis_du_defunt');
    END IF;
    RETURN jsonb_build_object('ok', true, 'deja_nettoye', true);
  END IF;

  v_data := v_data || jsonb_build_object(
    'compromis', NULL, 'compromisPar', NULL, 'acompte', NULL,
    'compromisAt', NULL, 'compromisExpireAt', NULL, 'pretDemande', NULL);
  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true);
END; $function$;

-- entreprise_succession_geler(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.entreprise_succession_geler(p_acteur text, p_entreprise text, p_succession text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_data jsonb; v_defunt text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  SELECT defunt INTO v_defunt FROM public.successions
   WHERE id = p_succession AND statut = 'en_attente';
  IF v_defunt IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_inconnue');
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_entreprise FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'introuvable'); END IF;
  IF (v_data->>'proprietaire') IS DISTINCT FROM v_defunt THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_du_defunt');
  END IF;

  -- Rejouable sans risque : reposer le meme gel est un no-op, c'est ce que fait deja le client
  -- en cas de reprise apres echec partiel.
  UPDATE public.entreprises
     SET data = jsonb_set(v_data, '{succession_gel}', to_jsonb(p_succession), true),
         updated_at = now()
   WHERE id = p_entreprise;
  RETURN jsonb_build_object('ok', true, 'gel', p_succession);
END; $function$;

-- fabriquer_produit_manufacture(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fabriquer_produit_manufacture(p_acteur text, p_pays text, p_produit text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ville text; v_bat text; v_recette jsonb; v_id text; v_pa_requis integer;
  v_etat jsonb; v_usine jsonb; v_sm jsonb; v_sp jsonb;
  v_cle text; v_q numeric; v_manque text; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, recette, COALESCE(pa, 0)
    INTO v_ville, v_bat, v_recette, v_pa_requis
  FROM public.produits_manufactures WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'produit_inconnu'); END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'atelier_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_sp := coalesce(v_usine->'stockProduits', '{}'::jsonb);

  -- Verification COMPLETE avant toute mutation : refus sans mutation partielle.
  FOR v_cle, v_q IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(v_recette) LOOP
    IF coalesce((v_sm->>v_cle)::numeric, 0) < v_q THEN v_manque := v_cle; EXIT; END IF;
  END LOOP;
  IF v_manque IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant', 'matiere', v_manque);
  END IF;

  -- PA du fabricant, lu dans la recette miroir. Verifie AVANT toute mutation, comme le stock.
  SELECT COALESCE(pa, 0) INTO v_pa FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_pa < v_pa_requis THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants',
                              'requis', v_pa_requis, 'pa_reel', v_pa);
  END IF;

  FOR v_cle, v_q IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(v_recette) LOOP
    v_sm := jsonb_set(v_sm, ARRAY[v_cle], to_jsonb(coalesce((v_sm->>v_cle)::numeric,0) - v_q));
  END LOOP;
  v_sp := jsonb_set(v_sp, ARRAY[p_produit], to_jsonb(coalesce((v_sp->>p_produit)::numeric,0) + 1));

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('stockMatieres', v_sm, 'stockProduits', v_sp)))::text),
         updated_at = now()
   WHERE id = v_id;

  IF v_pa_requis > 0 THEN
    UPDATE public.personnages_donnees SET pa = v_pa - v_pa_requis, updated_at = now()
     WHERE name = p_acteur;
  END IF;

  RETURN jsonb_build_object('ok', true, 'stock_produit', coalesce((v_sp->>p_produit)::numeric,0),
    'paConsommes', v_pa_requis, 'pa', v_pa - v_pa_requis);
END; $function$;

-- fixer_prix_entrepot(text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fixer_prix_entrepot(p_acteur text, p_pays text, p_prix jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste text; v_ville text; v_bat text; v_id text;
  v_etat jsonb; v_entrepot jsonb; v_pm jsonb := '{}'::jsonb;
  v_cle text; v_val numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id', poste->>'city' INTO v_poste, v_ville
  FROM public.personnages_donnees WHERE name = p_acteur;
  IF v_poste IS DISTINCT FROM 'directeur_entrepot' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;
  SELECT building_id INTO v_bat FROM public.entrepots_par_ville WHERE ville = v_ville;
  IF v_bat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;

  -- Validation AVANT toute ecriture : un seul prix invalide annule l'ensemble.
  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(coalesce(p_prix,'{}'::jsonb)) LOOP
    IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle);
    END IF;
    IF v_val IS NULL OR v_val <= 0 OR NOT (v_val = v_val) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_invalide', 'cle', v_cle);
    END IF;
    v_pm := jsonb_set(v_pm, ARRAY[v_cle], to_jsonb(round(v_val, 2)));
  END LOOP;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_entrepot := coalesce(v_etat->'entrepot', '{}'::jsonb);

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
           v_entrepot || jsonb_build_object('prixManuel', v_pm)))::text), updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'prixManuel', v_pm, 'batiment', v_bat);
END; $function$;

-- fixer_prix_vente_directe(text,text,jsonb) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fixer_prix_vente_directe(p_acteur text, p_pays text, p_prix jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste text; v_ville text; v_bat text; v_produits jsonb; v_id text;
  v_etat jsonb; v_usine jsonb; v_pm jsonb := '{}'::jsonb;
  v_cle text; v_val numeric; v_base numeric; v_min numeric; v_max numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id' INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;
  SELECT ville, building_id, produits INTO v_ville, v_bat, v_produits
  FROM public.directeurs_usine WHERE poste_id = v_poste;
  IF v_bat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;

  FOR v_cle, v_val IN SELECT key, (value #>> '{}')::numeric FROM jsonb_each(coalesce(p_prix,'{}'::jsonb)) LOOP
    IF NOT (v_produits ? v_cle) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'produit_hors_usine', 'cle', v_cle);
    END IF;
    SELECT prix_base INTO v_base FROM public.ressources_economie WHERE cle = v_cle;
    IF v_base IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue', 'cle', v_cle); END IF;
    -- Fourchette +/-40 %, arrondie au centime, exactement comme cote client.
    v_min := round(v_base * 0.6, 2); v_max := round(v_base * 1.4, 2);
    IF v_val IS NULL OR v_val < v_min OR v_val > v_max THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'prix_hors_fourchette',
                                'cle', v_cle, 'min', v_min, 'max', v_max);
    END IF;
    v_pm := jsonb_set(v_pm, ARRAY[v_cle], to_jsonb(round(v_val, 2)));
  END LOOP;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('prixManuel', v_pm)))::text), updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'prixManuel', v_pm, 'batiment', v_bat);
END; $function$;

-- fixer_repartition_port(text,numeric,numeric,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fixer_repartition_port(p_cle text, p_capitale numeric, p_ville_a numeric, p_ville_b numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_id text := 'republic_ville_a_port-sainte-marie';
        v_data jsonb; v_etat jsonb; v_port jsonb;
BEGIN
  PERFORM public.exiger_poste('capitaine_port');

  IF p_cle IS NULL OR NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_cle) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue');
  END IF;
  IF p_capitale IS NULL OR p_ville_a IS NULL OR p_ville_b IS NULL
     OR p_capitale < 0 OR p_ville_a < 0 OR p_ville_b < 0
     OR abs((p_capitale + p_ville_a + p_ville_b) - 100) > 0.1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repartition_invalide');
  END IF;

  SELECT data INTO v_data FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'port_absent'); END IF;

  v_etat := COALESCE(public.batiment_etat_lire(v_data), '{}'::jsonb);
  v_port := COALESCE(v_etat->'port', '{}'::jsonb);
  v_port := jsonb_set(v_port, ARRAY['repartition'],
              COALESCE(v_port->'repartition', '{}'::jsonb), true);
  v_port := jsonb_set(v_port, ARRAY['repartition', p_cle],
              jsonb_build_object('capitale', p_capitale, 'ville_a', p_ville_a,
                                 'ville_b', p_ville_b), true);
  v_etat := jsonb_set(v_etat, ARRAY['port'], v_port, true);

  UPDATE public.batiments_etat SET data = to_jsonb(v_etat::text), updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'repartition', v_port->'repartition'->p_cle);
END; $function$;

-- fixer_repartition_production(text,text,numeric) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fixer_repartition_production(p_acteur text, p_pays text, p_pourcentage numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_poste text; v_ville text; v_bat text; v_id text; v_etat jsonb; v_usine jsonb;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT poste->>'id' INTO v_poste FROM public.personnages_donnees WHERE name = p_acteur;
  SELECT ville, building_id INTO v_ville, v_bat FROM public.directeurs_usine WHERE poste_id = v_poste;
  IF v_bat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu', 'poste_reel', v_poste);
  END IF;
  IF p_pourcentage IS NULL OR p_pourcentage < 0 OR p_pourcentage > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'valeur_invalide');
  END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('repartitionEntrepots', p_pourcentage / 100)))::text),
         updated_at = now()
   WHERE id = v_id;
  RETURN jsonb_build_object('ok', true, 'repartitionEntrepots', p_pourcentage / 100, 'batiment', v_bat);
END; $function$;

-- fournisseurs_etrangers() -> TABLE(pays text, libelle text, ressource text, prix_unitaire numeric, disponible integer) | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fournisseurs_etrangers()
 RETURNS TABLE(pays text, libelle text, ressource text, prix_unitaire numeric, disponible integer)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH pays_etrangers(code, nom) AS (
    VALUES ('narco', 'El Estado'), ('soviet', 'Sovarka'), ('khalija', 'Al-Khalija')
  ),
  -- Relations d'approvisionnement REELLES, recopiees de ORIGINE_IMPORTS_PORT (api/cron-minuit.js).
  producteurs(code, ressource) AS (
    VALUES ('khalija', 'petrole'), ('soviet', 'petrole'), ('narco', 'produits_exotiques')
  )
  SELECT p.code,
         p.nom,
         r.cle,
         CASE WHEN EXISTS (SELECT 1 FROM producteurs pr WHERE pr.code = p.code AND pr.ressource = r.cle)
              THEN r.prix_achat_fournisseur ELSE r.prix_base END,
         NULL::integer
    FROM pays_etrangers p
    CROSS JOIN public.ressources_economie r
   WHERE r.source = 'livraison';
$function$;

-- fret_contenu_source_garder() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fret_contenu_source_garder()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 IF NOT public.est_appel_serveur() AND coalesce(current_setting('request.path',true),'')<>'/rpc/fret_objet_agir' THEN
  IF TG_OP='INSERT' THEN RAISE EXCEPTION 'fret: depot serveur requis' USING ERRCODE='42501'; END IF;
  IF (to_jsonb(NEW)-'quantite') IS DISTINCT FROM (to_jsonb(OLD)-'quantite') OR NEW.quantite IS NULL OR NEW.quantite<0 OR NEW.quantite>OLD.quantite THEN
   RAISE EXCEPTION 'fret: contenu forge refuse' USING ERRCODE='42501'; END IF;
 END IF;
 RETURN NEW;
END; $function$;

-- fret_dedouaner(uuid) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.fret_dedouaner(p_caisse_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; c record; v_val numeric; v_jours int; v_factures int;
  v_douane numeric; v_gard numeric; v_total numeric; v_caisse text; v_mvt jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;

  SELECT * INTO c FROM public.caisses_fret WHERE id = p_caisse_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_introuvable'); END IF;
  IF c.destinataire IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_destinataire');
  END IF;
  IF COALESCE(c.dedouanee, false) THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'deja_dedouanee');
  END IF;
  IF COALESCE(c.statut, '') <> 'arrivee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_invalide', 'statut', c.statut);
  END IF;

  v_val := GREATEST(0, COALESCE(c.valeur_declaree, 0));
  v_douane := round(v_val * 10 / 100.0);
  v_gard := 0;
  IF c.date_arrivee_reelle IS NOT NULL THEN
    v_jours := floor(EXTRACT(epoch FROM (now() - c.date_arrivee_reelle)) / 86400)::int;
    v_factures := GREATEST(0, v_jours - 7);
    IF v_factures > 0 THEN v_gard := round(v_val * 1 / 100.0 * v_factures); END IF;
  END IF;
  v_total := v_douane + v_gard;

  IF v_total > 0 THEN
    IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, v_total) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'requis', v_total,
                                'douane', v_douane, 'gardiennage', v_gard);
    END IF;
    -- Credit de la caisse du port DANS LA MEME TRANSACTION que le debit.
    v_caisse := c.pays_destination || '_' || c.building_destination;
    v_mvt := public.caisse_institution_mouvement(v_caisse, v_total, false);
    IF COALESCE((v_mvt->>'ok')::boolean, false) IS NOT TRUE THEN
      RAISE EXCEPTION 'credit_caisse_port_impossible: %', COALESCE(v_mvt->>'raison','?');
    END IF;
  END IF;

  UPDATE public.caisses_fret
     SET dedouanee = true, date_dedouanement = now()
   WHERE id = p_caisse_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total, 'douane', v_douane,
    'gardiennage', v_gard, 'jours_factures', COALESCE(v_factures, 0), 'caisse', v_caisse,
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END; $function$;

-- fret_deposer_objet_interne(text,jsonb,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fret_deposer_objet_interne(p_acteur text, p_objet jsonb, p_quantite integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE d jsonb; k integer;
BEGIN
 IF p_quantite IS NULL OR p_quantite<=0 THEN RAISE EXCEPTION 'fret: quantite invalide'; END IF;
 IF coalesce((p_objet->>'stackable')::boolean,false) AND nullif(p_objet->>'stackKey','') IS NOT NULL THEN
  d:=public.inventaire_deposer_interne(p_acteur,p_objet||jsonb_build_object('qty',p_quantite));
  IF (d->>'ok')::boolean IS DISTINCT FROM true OR (d->>'qte')::integer<>p_quantite THEN RAISE EXCEPTION 'fret: depot incomplet'; END IF;
 ELSE
  IF p_quantite>1 AND nullif(p_objet->>'id','') IS NOT NULL THEN RAISE EXCEPTION 'fret: identite historique ambigue'; END IF;
  FOR k IN 1..p_quantite LOOP
   d:=public.inventaire_deposer_interne(p_acteur,p_objet);
   IF (d->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'fret: depot incomplet'; END IF;
  END LOOP;
 END IF;
 RETURN d;
END; $function$;

-- fret_objet_agir(uuid,uuid,text,uuid,integer,integer,bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fret_objet_agir(p_requete uuid, p_caisse uuid, p_action text, p_ligne uuid DEFAULT NULL::uuid, p_index integer DEFAULT NULL::integer, p_quantite integer DEFAULT NULL::integer, p_revision bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE a public.personnages_donnees; c public.caisses_fret; l public.contenu_caisses_fret;
 params jsonb; v jsonb; d jsonb; o jsonb; inv jsonb; q integer; total integer; prix integer; paiement jsonb;
BEGIN
 SELECT * INTO a FROM public.personnages_donnees WHERE name=public.mon_personnage() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 IF p_requete IS NULL OR p_action IS NULL OR p_action NOT IN('deposer','reprendre','retirer','acheter') THEN
 RETURN jsonb_build_object('ok',false,'raison','commande_invalide'); END IF;
 params:=jsonb_build_object('caisse',p_caisse,'action',p_action,'ligne',p_ligne,'index',p_index,'quantite',p_quantite,'revision',p_revision);
 v:=public.inventaire_action_rejouer_interne(a.name,p_requete,'fret',params);IF v IS NOT NULL THEN RETURN v; END IF;
 SELECT * INTO c FROM public.caisses_fret WHERE id=p_caisse FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','caisse_introuvable'); END IF;
 IF p_action IN('deposer','reprendre') THEN
  IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM
    (c.pays_origine,c.ville_origine,c.building_origine,'entrepot') THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
  IF c.statut<>'ouverte' THEN RETURN jsonb_build_object('ok',false,'raison','caisse_fermee'); END IF;
 ELSE
  IF (a.country,a.current_city,a.current_building,a.current_room) IS DISTINCT FROM
    (c.pays_destination,c.ville_destination,c.building_destination,'entrepot') THEN RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;
 END IF;
 PERFORM 1 FROM public.contenu_caisses_fret WHERE caisse_id=c.id ORDER BY id FOR UPDATE;
 IF p_action='deposer' THEN
  IF a.name IS DISTINCT FROM c.leader AND NOT (a.name=ANY(c.chargeurs_autorises)) THEN RETURN jsonb_build_object('ok',false,'raison','pas_chargeur'); END IF;
  IF p_revision IS DISTINCT FROM a.inventory_revision THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_perime'); END IF;
  IF p_index IS NULL OR p_index<0 OR p_index>=jsonb_array_length(a.inventory) THEN RETURN jsonb_build_object('ok',false,'raison','index_invalide'); END IF;
  o:=a.inventory->p_index;
  IF o->>'type' IN('acte_officiel','colis_secret_pat','relique') OR o->>'id'='cle-debarras-musee'
   OR coalesce((o->>'calepinEnigme1')::boolean,false) OR o->>'id' LIKE 'fiche-etat-civil-%' THEN RETURN jsonb_build_object('ok',false,'raison','objet_non_cessible'); END IF;
  IF coalesce((o->>'stackable')::boolean,false) AND (coalesce((o->>'qty')::numeric,1)<=0 OR coalesce((o->>'qty')::numeric,1)<>trunc(coalesce((o->>'qty')::numeric,1))) THEN RETURN jsonb_build_object('ok',false,'raison','quantite_historique_invalide'); END IF;
  q:=CASE WHEN coalesce((o->>'stackable')::boolean,false) THEN coalesce((o->>'qty')::numeric,1)::integer ELSE 1 END;
  IF p_quantite IS NULL OR p_quantite<=0 OR p_quantite>q THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
  SELECT coalesce(sum(quantite),0) INTO total FROM public.contenu_caisses_fret WHERE caisse_id=c.id;
  IF total+p_quantite>500 THEN RETURN jsonb_build_object('ok',false,'raison','caisse_pleine'); END IF;
  inv:=CASE WHEN q=p_quantite THEN a.inventory-p_index ELSE jsonb_set(a.inventory,ARRAY[p_index::text,'qty'],to_jsonb(q-p_quantite)) END;
  INSERT INTO public.contenu_caisses_fret(caisse_id,deposant,objet,quantite) VALUES(c.id,a.name,o-'qty',p_quantite);
  UPDATE public.personnages_donnees SET inventory=inv WHERE name=a.name;
  q:=p_quantite;
 ELSIF p_action IN('reprendre','retirer') THEN
  SELECT * INTO l FROM public.contenu_caisses_fret WHERE id=p_ligne AND caisse_id=c.id;
  IF NOT FOUND OR l.quantite<=0 THEN RETURN jsonb_build_object('ok',false,'raison','ligne_indisponible'); END IF;
  IF p_action='reprendre' THEN
   IF l.deposant IS DISTINCT FROM a.name THEN RETURN jsonb_build_object('ok',false,'raison','pas_deposant'); END IF;
   q:=l.quantite;
  ELSE
   IF c.statut<>'arrivee' OR NOT c.dedouanee THEN RETURN jsonb_build_object('ok',false,'raison','caisse_non_dedouanee'); END IF;
   IF c.destinataire IS DISTINCT FROM a.name AND NOT(a.name=ANY(c.receptionnaires_autorises)) THEN RETURN jsonb_build_object('ok',false,'raison','pas_receptionnaire'); END IF;
   IF p_quantite IS NULL OR p_quantite<=0 THEN RETURN jsonb_build_object('ok',false,'raison','quantite_invalide'); END IF;
   q:=least(l.quantite,p_quantite);
  END IF;
  IF public.inventaire_place_restante(a.inventory)<q THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein'); END IF;
  IF p_action='retirer' THEN
   paiement:=public.payer_ordre(a.name,'receptionner_commande',1,0);
   IF (paiement->>'ok')::boolean IS DISTINCT FROM true THEN RETURN paiement; END IF;
  END IF;
  d:=public.fret_deposer_objet_interne(a.name,l.objet,q);
  UPDATE public.contenu_caisses_fret SET quantite=quantite-q WHERE id=l.id;
  IF p_action='retirer' AND NOT EXISTS(SELECT 1 FROM public.contenu_caisses_fret WHERE caisse_id=c.id AND quantite>0) THEN
   UPDATE public.caisses_fret SET statut='videe' WHERE id=c.id;
  END IF;
 ELSE
  IF c.statut<>'a_vendre' THEN RETURN jsonb_build_object('ok',false,'raison','lot_indisponible'); END IF;
  SELECT coalesce(sum(quantite),0) INTO total FROM public.contenu_caisses_fret WHERE caisse_id=c.id AND quantite>0;
  IF total<=0 THEN RETURN jsonb_build_object('ok',false,'raison','lot_vide'); END IF;
  IF public.inventaire_place_restante(a.inventory)<total THEN RETURN jsonb_build_object('ok',false,'raison','inventaire_plein'); END IF;
  SELECT public.assemblee_verifier_vente(jsonb_agg(objet),a.country) INTO v FROM public.contenu_caisses_fret WHERE caisse_id=c.id AND quantite>0;
  IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RETURN v; END IF;
  prix:=round(coalesce(c.valeur_declaree,0)*(total::numeric/coalesce(nullif(c.quantite_arrivee,0),total))*0.5);
  IF prix<0 THEN RETURN jsonb_build_object('ok',false,'raison','valeur_invalide'); END IF;
  IF NOT public.helvetia_debiter_fonds_ordinaires(a.name,prix) THEN RETURN jsonb_build_object('ok',false,'raison','fonds_insuffisants'); END IF;
  IF prix>0 THEN
   -- 28/10/2026 (Claude) : la caisse du port est creee si besoin, comme pour les autres recettes.
   PERFORM set_config('rp.caisse_interne','on',true);
   v:=public.caisse_institution_mouvement(c.pays_destination||'_'||c.building_destination,prix,false);
   PERFORM set_config('rp.caisse_interne','',true);
   IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'fret: caisse port refusee'; END IF;
  END IF;
  FOR l IN SELECT * FROM public.contenu_caisses_fret WHERE caisse_id=c.id AND quantite>0 ORDER BY id LOOP
   d:=public.fret_deposer_objet_interne(a.name,l.objet,l.quantite);
   UPDATE public.contenu_caisses_fret SET quantite=0 WHERE id=l.id;
  END LOOP;
  UPDATE public.caisses_fret SET statut='vendue' WHERE id=c.id;q:=total;
 END IF;
 SELECT jsonb_build_object('ok',true,'inventory',inventory,'revision',inventory_revision,'qte',q,'prix',coalesce(prix,0),
  'paie',jsonb_build_object('pa',pa,'arg',arg,'liquide',liquide,'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=a.name AND banque='nationale'),0)))
 INTO v FROM public.personnages_donnees WHERE name=a.name;
 INSERT INTO public.inventaire_actions_recus VALUES(a.name,p_requete,'fret',params,v,now());RETURN v;
END; $function$;

-- fret_unitaire_international() -> numeric | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.fret_unitaire_international()
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$ SELECT 0.40::numeric; $function$;

-- hotel_nuitee_ajouter_interne(text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.hotel_nuitee_ajouter_interne(p_acteur text, p_hotel text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p record; n integer; ville text;
BEGIN
 SELECT id,country,current_city,current_building INTO p FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND OR p.current_building IS DISTINCT FROM p_hotel OR p_hotel NOT IN ('hotel-republica','hotel-port','hotel-mineur')
 THEN RAISE EXCEPTION 'hotel_reservation_lieu_invalide';END IF;
 SELECT montant INTO n FROM public.pa_bonus_hotel WHERE building_id=p_hotel;
 IF n IS NULL THEN RAISE EXCEPTION 'hotel_bonus_absent';END IF;
 INSERT INTO public.hotel_nuitees(personnage_id,country,city,building_id,pa_bonus,moral_bonus)
 VALUES(p.id,p.country,p.current_city,p_hotel,n,3);
 RETURN jsonb_build_object('ok',true,'hotel',p_hotel,'ville',p.current_city);
END;$function$;

-- hotel_nuitee_consommation_interne(text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.hotel_nuitee_consommation_interne(p_acteur text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p record;n record;out_pa integer;out_moral integer; today_paris date:=(now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
 SELECT id,country,current_city,current_building,current_room,pa_repos_le,pa,moral
 INTO p FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND OR p.pa_repos_le IS DISTINCT FROM today_paris THEN RETURN jsonb_build_object('ok',false,'raison','repos_non_valide');END IF;
 IF NOT ((p.current_building='hotel-republica' AND p.current_room='chambres')
 OR (p.current_building='hotel-port' AND p.current_room='chambre_port')
 OR (p.current_building='hotel-mineur' AND p.current_room='chambre_mineur')) THEN
 RETURN jsonb_build_object('ok',false,'raison','hors_chambre');END IF;
 SELECT * INTO n FROM public.hotel_nuitees WHERE personnage_id=p.id AND consommee_le=today_paris LIMIT 1;
 IF FOUND THEN
  IF n.country=p.country AND n.city=p.current_city AND n.building_id=p.current_building THEN
   RETURN jsonb_build_object('ok',true,'rejeu',true,'pa',p.pa,'moral',p.moral,
    'montant',n.pa_bonus,'moralBonus',n.moral_bonus,'hotel',n.building_id);
  END IF;
  RETURN jsonb_build_object('ok',false,'raison','nuit_deja_utilisee');
 END IF;
 SELECT * INTO n FROM public.hotel_nuitees
 WHERE personnage_id=p.id AND country=p.country AND city=p.current_city
 AND building_id=p.current_building AND consommee_le IS NULL
 ORDER BY cree_le,id LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','aucune_reservation'); END IF;
 UPDATE public.hotel_nuitees SET consommee_le=today_paris WHERE id=n.id;
 UPDATE public.personnages_donnees SET pa=LEAST(30,GREATEST(0,COALESCE(pa,0)+n.pa_bonus)),
 moral=LEAST(100,GREATEST(0,COALESCE(moral,0)+n.moral_bonus)),updated_at=now()
 WHERE id=p.id RETURNING pa,moral INTO out_pa,out_moral;
 RETURN jsonb_build_object('ok',true,'pa',out_pa,'moral',out_moral,
 'montant',n.pa_bonus,'moralBonus',n.moral_bonus,'hotel',n.building_id);
END;$function$;

-- hotel_reservations_lire() -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.hotel_reservations_lire()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p record; r jsonb;
BEGIN
 SELECT id INTO p FROM public.personnages_donnees WHERE name=public.mon_personnage() AND user_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',n.id,'buildingId',n.building_id,'ville',n.city,
 'country',n.country,'bonus',jsonb_build_object('paBonus',n.pa_bonus,'moral',n.moral_bonus))
 ORDER BY n.cree_le,n.id),'[]'::jsonb) INTO r
 FROM public.hotel_nuitees n WHERE n.personnage_id=p.id AND n.consommee_le IS NULL;
 RETURN r;
END;$function$;

-- local_vocation_commerciale(text) -> text | sql | SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.local_vocation_commerciale(p_building_id text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case p_building_id
    when 'centre-commercial' then 'commerce'
    when 'centre-artisanal'  then 'artisanat'
    when 'centre-affaires'   then 'services'
    else null
  end;
$function$;

-- matiere_circuits_disponibles(text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.matiere_circuits_disponibles(p_matiere text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_matiere)
    THEN NULL
    ELSE jsonb_build_object(
      'matiere', p_matiere,
      'achat_entrepot', EXISTS (
        SELECT 1 FROM public.batiments_etat b
         WHERE b.id LIKE '%entrepot%'
           AND public.batiment_etat_lire(b.data)->'entrepot'->'stock' ? p_matiere),
      'achat_criee', EXISTS (
        SELECT 1 FROM public.batiments_etat b
         WHERE public.batiment_etat_lire(b.data)->'port'->'criee'->'stock' ? p_matiere),
      'vente_commerce', EXISTS (
        SELECT 1 FROM public.recettes_commerce r WHERE r.materiaux ? p_matiere),
      'vente_armurerie', EXISTS (
        SELECT 1 FROM public.recettes_production r WHERE r.materiaux ? p_matiere),
      'vente_usine', EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.matiere = p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.usines_rachat_config u
         WHERE coalesce(u.matieres_hors_chaine, '[]'::jsonb) ? p_matiere),
      'vente_medical', EXISTS (
        SELECT 1 FROM public.structures_medicales s
         WHERE coalesce(s.ressources, '[]'::jsonb) ? p_matiere),
      'production_usine', EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.produit = p_matiere),
      'recolte', p_matiere IN ('metal', 'poisson', 'charbon', 'bois'),
      'transformation', EXISTS (
        SELECT 1 FROM public.recettes_commerce r WHERE r.materiaux ? p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.recettes_production r WHERE r.materiaux ? p_matiere)
        OR EXISTS (
        SELECT 1 FROM public.chaines_production_usine c WHERE c.matiere = p_matiere),
      'categories', coalesce((
        SELECT jsonb_agg(c.categorie ORDER BY c.categorie)
          FROM public.assemblee_categories_interdiction c
         WHERE p_matiere = ANY (c.matieres)), '[]'::jsonb)
    ) END;
$function$;

-- matiere_refus_circuit_legal(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.matiere_refus_circuit_legal(p_acteur text, p_matiere text, p_mode text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_pays text; v_loi jsonb; v_mode text := lower(btrim(coalesce(p_mode, '')));
BEGIN
  IF coalesce(p_acteur, '') = '' OR coalesce(p_matiere, '') = '' THEN RETURN NULL; END IF;

  -- LE DON N'EST PAS UN CIRCUIT ECONOMIQUE. Seul endroit du serveur ou cette
  -- exception est ecrite. Un transfert gratuit reste possible, et sa trace au
  -- registre est justement ce qui rendra une filiere reperable.
  IF v_mode = 'don' THEN RETURN NULL; END IF;

  -- LA JURIDICTION EST CELLE DU PERSONNAGE, LUE EN BASE. Jamais un pays transmis
  -- par l'appelant : plusieurs des RPC gardees ici recoivent le leur du navigateur.
  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
  IF v_pays IS NULL THEN RETURN NULL; END IF;

  -- assemblee_loi_en_vigueur n'est vraie que pour une loi ADOPTEE **ET MISE EN
  -- APPLICATION** depuis le 30 septembre 2026 : une loi votee que le Ministre de
  -- l'Interieur n'a pas encore prononcee ne bloque donc rien.
  v_loi := public.assemblee_loi_en_vigueur(v_pays,
             jsonb_build_object('stackKey', p_matiere), now());
  IF v_loi IS NULL THEN RETURN NULL; END IF;

  -- LA TRANSFORMATION EST LA SEULE DIMENSION VOTEE. Un stock deja possede reste
  -- transformable, sauf si l'Assemblee l'a expressement interdit (cas B). Le
  -- niveau vient de la loi, jamais du client ni du ministre.
  IF v_mode = 'transformation'
     AND coalesce((v_loi -> 'portee' ->> 'transformation_stock_interdite')::boolean, false) IS NOT TRUE THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object('ok', false, 'raison', 'matiere_interdite',
                            'matiere', p_matiere, 'mode', v_mode, 'loi', v_loi);
END $function$;

-- matiere_refus_circuit_legal_lot(text,jsonb,text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.matiere_refus_circuit_legal_lot(p_acteur text, p_panier jsonb, p_mode text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT public.matiere_refus_circuit_legal(p_acteur, k.cle, p_mode)
    FROM jsonb_object_keys(
           CASE WHEN jsonb_typeof(p_panier) = 'object' THEN p_panier ELSE '{}'::jsonb END
         ) AS k(cle)
   WHERE public.matiere_refus_circuit_legal(p_acteur, k.cle, p_mode) IS NOT NULL
   ORDER BY k.cle
   LIMIT 1;
$function$;

-- ordres_couts_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ordres_couts_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(fn || '|' || pa || '|' || cost, E'\n'
                             ORDER BY fn COLLATE "C", pa, cost)), 16)
  FROM public.ordres_couts;
$function$;

-- payer_ordre(text,text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.payer_ordre(p_acteur text, p_fn text DEFAULT NULL::text, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_fn text := coalesce(nullif(btrim(coalesce(p_fn,'')), ''), '(non transmis)');
  v_acquisition boolean;
  v_connu boolean; v_valide boolean;
  v_pa integer; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0;
  v_pris_liquide numeric; v_pris_national numeric;
  v_memorable record; v_pays text;
BEGIN
  IF v_fn='louer_lot_ici' THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  IF v_fn = 'deposer_demande_permis' AND NOT EXISTS (
    SELECT 1 FROM public.permis_transactions_internes WHERE transaction_id=txid_current() AND acteur=auth.uid()
  ) THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise'); END IF;
  PERFORM public.exiger_acteur(p_acteur);
  v_acquisition:=EXISTS(SELECT 1 FROM public.acquisitions_transactions_internes a WHERE a.transaction_id=txid_current() AND a.acteur=p_acteur AND ((a.ordre=v_fn AND a.pa=p_pa AND a.montant=p_cost) OR (a.ordre='signer_compromis' AND v_fn='deposer_demande_permis' AND p_pa=0 AND p_cost=0)));
  IF v_fn IN('acheter_terrain','signer_compromis','acte_vente_terrain','emprunter') AND NOT v_acquisition THEN RETURN jsonb_build_object('ok',false,'raison','commande_versionnee_requise');END IF;
  IF coalesce(p_pa, 0) < 0 OR coalesce(p_cost, 0) < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_negatif');
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o WHERE o.fn = v_fn) INTO v_connu;

  IF NOT v_connu AND NOT v_acquisition THEN
    INSERT INTO public.ordres_couts_inconnus (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn) DO UPDATE SET occurrences = public.ordres_couts_inconnus.occurrences + 1;
    RETURN jsonb_build_object('ok', false, 'raison', 'ordre_inconnu', 'fn', v_fn);
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.ordres_couts o
                 WHERE o.fn = v_fn AND o.pa = coalesce(p_pa,0) AND o.cost = coalesce(p_cost,0))
    INTO v_valide;
  IF NOT v_valide AND NOT v_acquisition THEN
    INSERT INTO public.ordres_couts_ecarts (fn, pa, cost)
    VALUES (v_fn, coalesce(p_pa,0), coalesce(p_cost,0))
    ON CONFLICT (fn, pa, cost)
      DO UPDATE SET occurrences = public.ordres_couts_ecarts.occurrences + 1, vu_le = now();
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare',
                              'fn', v_fn, 'pa', p_pa, 'cost', p_cost);
  END IF;

  SELECT pa, liquide, arg INTO v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_pa IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);

  IF v_pa < coalesce(p_pa, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pa_insuffisants', 'pa_reel', v_pa);
  END IF;
  IF coalesce(v_liquide,0) + v_solde < coalesce(p_cost, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'disponible', coalesce(v_liquide,0) + v_solde);
  END IF;

  v_pris_liquide := least(coalesce(v_liquide,0), coalesce(p_cost,0));
  v_pris_national := coalesce(p_cost,0) - v_pris_liquide;

  UPDATE public.personnages_donnees
     SET pa = v_pa - coalesce(p_pa,0),
         liquide = coalesce(v_liquide,0) - v_pris_liquide,
         arg = coalesce(v_arg,0) - coalesce(p_cost,0)
   WHERE name = p_acteur;

  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national,
           updated_at = now() WHERE id = v_compte_id;
  END IF;

  -- LA MEMOIRE DES MANDATS (11 octobre 2026). Apres le prelevement, donc sur un fait accompli, et
  -- seulement si le triplet figure au registre des actes memorables. `presidence_memoire_noter`
  -- verifie elle-meme que l'acteur est bien le President en exercice : si c'est un ministre qui
  -- tient la conference de presse, rien n'est ecrit. Le registre ne contient AUCUN panneau a
  -- (0 PA, 0 FR) -- ouvrir une fenetre n'est pas un acte.
  SELECT * INTO v_memorable FROM public.presidence_memoire_ordres
   WHERE fn = v_fn AND pa = coalesce(p_pa,0) AND cost = coalesce(p_cost,0);
  IF FOUND THEN
    SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = p_acteur;
    PERFORM public.presidence_memoire_noter(
      v_pays, 'reaction', 'ordre_presidentiel', v_memorable.sujet,
      jsonb_build_object('ordre', v_fn, 'pa', coalesce(p_pa,0), 'cout', coalesce(p_cost,0)),
      p_acteur);
  END IF;

  -- FONDS EN TRANSIT (26/10/2026) : ce que le navigateur vient de payer pourra etre verse a une
  -- caisse par lui, et rien d'autre. Seulement pour un paiement demande directement par le navigateur.
  IF coalesce(p_cost, 0) > 0 AND coalesce(current_setting('request.path', true), '') = '/rpc/payer_ordre' THEN
    PERFORM public.fonds_transit_deposer_interne(p_acteur, p_cost, 'ordre:' || v_fn);
  END IF;

  RETURN jsonb_build_object(
    'ok', true, 'pa', v_pa - coalesce(p_pa,0),
    'liquide', coalesce(v_liquide,0) - v_pris_liquide,
    'arg', coalesce(v_arg,0) - coalesce(p_cost,0),
    'solde_national', v_solde - v_pris_national,
    'pa_preleves', coalesce(p_pa,0), 'montant_preleve', coalesce(p_cost,0));
END;
$function$;

-- prix_ressource_selon_stock(text,numeric) -> numeric | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.prix_ressource_selon_stock(p_cle text, p_en_stock numeric)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_base numeric; v_plafond numeric; v_taux numeric;
BEGIN
  SELECT prix_base, plafond INTO v_base, v_plafond FROM public.ressources_economie WHERE cle = p_cle;
  IF v_base IS NULL THEN RETURN NULL; END IF;   -- jamais de tarif invente
  v_taux := greatest(0, least(1, coalesce(p_en_stock,0) / nullif(v_plafond,0)));
  RETURN round(v_base * (1 + (0.5 - v_taux) * 0.8), 2);
END; $function$;

-- produire_en_usine(text,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.produire_en_usine(p_acteur text, p_pays text, p_produit text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_ville text; v_bat text; v_matiere text; v_salaire numeric;
  v_id text; v_etat jsonb; v_usine jsonb; v_vd jsonb; v_sm jsonb;
  v_caisse numeric; v_stock_mat numeric; v_stock_prod numeric; v_place numeric; v_produits int;
  v_arg numeric; v_liquide numeric;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  SELECT ville, building_id, matiere, salaire_pa INTO v_ville, v_bat, v_matiere, v_salaire
  FROM public.chaines_production_usine WHERE produit = p_produit;
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'chaine_inconnue'); END IF;

  -- PRODUCTION LEGALE (30 septembre 2026). Une loi appliquee visant la matiere
  -- PRODUITE ferme la chaine : on ne fabrique plus legalement ce qui est
  -- interdit, dans les deux cas A et B.
  IF public.matiere_refus_circuit_legal(p_acteur, p_produit, 'production') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, p_produit, 'production');
  END IF;
  -- TRANSFORMATION. La chaine CONSOMME aussi une matiere : si c'est elle qui
  -- est interdite et que la loi a vote le cas B, la chaine s'arrete aussi.
  IF public.matiere_refus_circuit_legal(p_acteur, v_matiere, 'transformation') IS NOT NULL THEN
    RETURN public.matiere_refus_circuit_legal(p_acteur, v_matiere, 'transformation');
  END IF;

  v_id := p_pays || '_' || v_ville || '_' || v_bat;
  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'usine_introuvable'); END IF;
  v_usine := coalesce(v_etat->'usine', '{}'::jsonb);
  v_vd := coalesce(v_usine->'venteDirecte', '{}'::jsonb);
  v_sm := coalesce(v_usine->'stockMatieres', '{}'::jsonb);
  v_caisse := coalesce((v_usine->>'caisse')::numeric, 0);
  v_stock_mat := coalesce((v_sm->>v_matiere)::numeric, 0);
  v_stock_prod := coalesce((v_vd->>p_produit)::numeric, 0);

  -- Memes trois conditions qu'avant, dans le meme ordre.
  IF v_stock_mat < 5 THEN RETURN jsonb_build_object('ok', false, 'raison', 'matiere_insuffisante', 'matiere', v_matiere); END IF;
  IF v_caisse < v_salaire THEN RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante'); END IF;
  v_place := greatest(0, 50 - v_stock_prod);
  IF v_place <= 0 THEN RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein'); END IF;

  v_produits := least(10, v_place)::int;   -- PRODUIT_PAR_PA_USINE, plafonne par la place
  v_sm := jsonb_set(v_sm, ARRAY[v_matiere], to_jsonb(v_stock_mat - 5));  -- MATIERE_PAR_PA_USINE
  v_vd := jsonb_set(v_vd, ARRAY[p_produit], to_jsonb(v_stock_prod + v_produits));
  v_caisse := v_caisse - v_salaire;

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('usine',
           v_usine || jsonb_build_object('caisse', v_caisse, 'venteDirecte', v_vd, 'stockMatieres', v_sm)))::text),
         updated_at = now()
   WHERE id = v_id;

  -- Le salaire sort de la caisse de l'usine et entre en liquide : aucune valeur
  -- creee, exactement comme le credit generique du jeu (crediterFondsOrdinaires).
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg,0) + v_salaire, liquide = coalesce(liquide,0) + v_salaire
   WHERE name = p_acteur
   RETURNING arg, liquide INTO v_arg, v_liquide;
  IF v_arg IS NULL THEN RAISE EXCEPTION 'personnage_introuvable' USING ERRCODE = '42501'; END IF;

  RETURN jsonb_build_object('ok', true, 'produits', v_produits, 'salaire', v_salaire,
    'arg', v_arg, 'liquide', v_liquide, 'caisse_usine', v_caisse,
    'stock_produit', v_stock_prod + v_produits, 'stock_matiere', v_stock_mat - 5);
END; $function$;

-- recettes_militaires_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recettes_militaires_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      produit || '|' || coalesce(label, '')
              || '|' || (SELECT coalesce(string_agg(k || ':' || (r.materiaux ->> k),
                                                    ',' ORDER BY k COLLATE "C"), '')
                           FROM jsonb_object_keys(r.materiaux) AS k)
              || '|' || coalesce(pa::text, '')
              || '|' || coalesce(produit_par_lot::text, '')
              || '|' || coalesce(type_objet, '')
              || '|' || coalesce(sous_type, '')
              || '|' || coalesce(prix_pnj::text, '')
              || '|' || coalesce(capacite::text, ''),
      E'\n' ORDER BY produit COLLATE "C")), 16)
  FROM public.recettes_militaires AS r;
$function$;

-- recevoir_soin(text,text,text,text,text,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recevoir_soin(p_acteur text, p_pays text, p_ville text, p_batiment text, p_type text, p_cout integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id text := p_pays || '_' || p_ville || '_' || p_batiment;
  v_etat jsonb; v_sante jsonb; v_sm jsonb;
  v_jour int; v_stats jsonb; v_marqueur text;
  v_hp numeric; v_pa numeric; v_liquide numeric; v_arg numeric;
  v_compte_id text; v_solde numeric := 0; v_pris_liquide numeric; v_pris_national numeric;
  v_taxe jsonb; v_net numeric; v_gain_hp int; v_gain_pa int;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF p_type NOT IN ('public','clinique') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_inconnu');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ordres_couts
                 WHERE fn = CASE WHEN p_type='public' THEN 'soin_public' ELSE 'soins' END
                   AND cost = coalesce(p_cout,0)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_non_declare', 'cout', p_cout);
  END IF;
  v_marqueur := CASE WHEN p_type='public' THEN 'soinPublicJour' ELSE 'soinCliniqueJour' END;

  SELECT coalesce(stats,'{}'::jsonb), coalesce(day,1), coalesce(hp,0), coalesce(pa,0),
         coalesce(liquide,0), coalesce(arg,0)
    INTO v_stats, v_jour, v_hp, v_pa, v_liquide, v_arg
  FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_stats IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF coalesce((v_stats->>v_marqueur)::int, -1) = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_soigne_aujourdhui');
  END IF;

  SELECT public.batiment_etat_lire(data) INTO v_etat FROM public.batiments_etat WHERE id = v_id FOR UPDATE;
  IF v_etat IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'structure_introuvable'); END IF;
  v_sante := coalesce(v_etat->'sante', '{}'::jsonb);
  v_sm := coalesce(v_sante->'stockMatieres', '{}'::jsonb);

  IF p_type = 'public' THEN
    IF coalesce((v_sm->>'desinfectant')::numeric,0) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rupture_stock');
    END IF;
    v_gain_hp := 10; v_gain_pa := 1;      -- valeurs REELLES du jeu
  ELSE
    IF coalesce((v_sm->>'desinfectant')::numeric,0) < 1
       OR coalesce((v_sm->>'medicaments')::numeric,0) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'rupture_stock');
    END IF;
    v_gain_hp := 30; v_gain_pa := 2;
  END IF;

  SELECT id, solde INTO v_compte_id, v_solde FROM public.comptes_bancaires
  WHERE personnage = p_acteur AND banque = 'nationale' FOR UPDATE;
  v_solde := coalesce(v_solde, 0);
  IF v_liquide + v_solde < coalesce(p_cout,0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants', 'disponible', v_liquide + v_solde);
  END IF;
  v_pris_liquide := least(v_liquide, coalesce(p_cout,0));
  v_pris_national := coalesce(p_cout,0) - v_pris_liquide;

  IF p_type = 'public' THEN
    v_sm := jsonb_set(v_sm, '{desinfectant}', to_jsonb(coalesce((v_sm->>'desinfectant')::numeric,0) - 1));
    v_sante := v_sante || jsonb_build_object('stockMatieres', v_sm);
  ELSE
    v_taxe := public.appliquer_taxe_transaction(p_pays, p_ville, coalesce(p_cout,0));
    v_net := (v_taxe->>'net')::numeric;
    v_sm := jsonb_set(jsonb_set(v_sm,
              '{desinfectant}', to_jsonb(coalesce((v_sm->>'desinfectant')::numeric,0) - 1)),
              '{medicaments}', to_jsonb(coalesce((v_sm->>'medicaments')::numeric,0) - 1));
    v_sante := v_sante || jsonb_build_object('stockMatieres', v_sm,
                 'caisse', coalesce((v_sante->>'caisse')::numeric,0) + v_net);
  END IF;

  UPDATE public.batiments_etat
     SET data = to_jsonb((v_etat || jsonb_build_object('sante', v_sante))::text), updated_at = now()
   WHERE id = v_id;
  UPDATE public.personnages_donnees
     SET liquide = v_liquide - v_pris_liquide, arg = v_arg - coalesce(p_cout,0),
         hp = least(100, v_hp + v_gain_hp), pa = least(30, v_pa + v_gain_pa),
         stats = jsonb_set(v_stats, ARRAY[v_marqueur], to_jsonb(v_jour))
   WHERE name = p_acteur;
  IF v_pris_national > 0 AND v_compte_id IS NOT NULL THEN
    UPDATE public.comptes_bancaires SET solde = solde - v_pris_national, updated_at = now() WHERE id = v_compte_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'hp', least(100, v_hp + v_gain_hp),
    'pa', least(30, v_pa + v_gain_pa), 'liquide', v_liquide - v_pris_liquide,
    'arg', v_arg - coalesce(p_cout,0), 'solde_national', v_solde - v_pris_national,
    'gain_hp', v_gain_hp, 'gain_pa', v_gain_pa, 'taxe', v_taxe);
END; $function$;

-- recolte_effectuer(text,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.recolte_effectuer(p_matiere text, p_pa integer, p_cost integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_moi text; m record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date; v_nb integer; v_paie jsonb;
  v_q integer; v_cle text; v_dep jsonb; k integer;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT country, current_city INTO m FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT (p_matiere = ANY (CASE m.country || ':' || coalesce(m.current_city, '')
      WHEN 'republic:ville_a' THEN ARRAY['Poisson'] WHEN 'republic:ville_b' THEN ARRAY['Charbon', 'Métal']
      WHEN 'narco:ville_a' THEN ARRAY['Bois', 'Cuir'] WHEN 'narco:ville_b' THEN ARRAY['Bois exotique', 'Caoutchouc']
      WHEN 'soviet:ville_a' THEN ARRAY['Minerai de fer', 'Charbon'] WHEN 'soviet:ville_b' THEN ARRAY['Blé', 'Cuir']
      WHEN 'khalija:ville_a' THEN ARRAY['Épices', 'Coton'] WHEN 'khalija:ville_b' THEN ARRAY['Pétrole', 'Poisson']
      ELSE ARRAY[]::text[] END)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rien_a_recolter_ici'); END IF;
  SELECT nb INTO v_nb FROM public.recoltes_journalieres WHERE nom = v_moi AND jour = v_jour FOR UPDATE;
  IF coalesce(v_nb, 0) >= 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'limite_atteinte'); END IF;
  v_q := floor(random() * 2)::integer + 1;
  v_cle := CASE p_matiere WHEN 'Métal' THEN 'metal' WHEN 'Poisson' THEN 'poisson' WHEN 'Charbon' THEN 'charbon' WHEN 'Bois' THEN 'bois' END;
  IF (SELECT public.inventaire_place_restante(inventory) FROM public.personnages_donnees WHERE name = v_moi) < v_q THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'inventaire_plein'); END IF;
  v_paie := public.payer_ordre(v_moi, 'recolter_matiere', p_pa, p_cost);
  IF coalesce((v_paie ->> 'ok')::boolean, false) IS NOT TRUE THEN RETURN v_paie; END IF;
  INSERT INTO public.recoltes_journalieres (nom, jour, nb) VALUES (v_moi, v_jour, 1)
  ON CONFLICT (nom, jour) DO UPDATE SET nb = public.recoltes_journalieres.nb + 1;
  IF v_cle IS NOT NULL THEN
    v_dep := public.inventaire_deposer_interne(v_moi, jsonb_build_object('name', p_matiere,
      'icon', CASE v_cle WHEN 'metal' THEN 'ti-bolt' WHEN 'poisson' THEN 'ti-fish' WHEN 'charbon' THEN 'ti-flame' ELSE 'ti-trees' END,
      'stackable', true, 'stackKey', v_cle, 'qty', v_q, 'desc', 'Récolté localement.'));
  ELSE
    FOR k IN 1..v_q LOOP
      v_dep := public.inventaire_deposer_interne(v_moi, jsonb_build_object('type', 'matiere_premiere', 'matiere', p_matiere,
        'name', p_matiere, 'icon', 'ti-package'));
    END LOOP;
  END IF;
  IF coalesce((v_dep ->> 'ok')::boolean, false) IS NOT TRUE THEN RAISE EXCEPTION 'recolte_effectuer: depot refuse %', v_dep; END IF;
  RETURN jsonb_build_object('ok', true, 'quantite', v_q, 'recoltes_jour', coalesce(v_nb, 0) + 1, 'pa', v_paie -> 'pa')
    || (v_dep - 'ok' - 'qte');
END; $function$;

-- refectoire_repas(text,text,integer,integer,integer) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.refectoire_repas(p_pays text, p_joueur text, p_jour integer, p_pa_max integer DEFAULT 30, p_gain integer DEFAULT 2)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pj personnages%ROWTYPE; v_pays text; v_jour text; v_stats jsonb;
  v_data jsonb; v_ref jsonb; v_commun jsonb; v_rations integer;
  v_cer integer; v_via integer; v_poi integer; v_prot text; v_fab boolean := false; v_pa integer;
BEGIN
  PERFORM public.exiger_acteur(p_joueur);
  IF COALESCE(btrim(p_joueur), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  SELECT * INTO v_pj FROM public.personnages WHERE name = p_joueur FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_absent'); END IF;
  IF COALESCE(v_pj.current_building, '') <> 'caserne-militaire' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place');
  END IF;

  -- Ni le pays ni le jour ne sont crus : le batiment 'caserne-militaire' existe dans les quatre
  -- empires, et p_jour etait un robinet de PA. p_pays, p_jour, p_gain et p_pa_max sont ignores.
  v_pays := COALESCE(NULLIF(btrim(COALESCE(v_pj.country, '')), ''), 'republic');
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date::text;

  v_stats := CASE WHEN jsonb_typeof(v_pj.stats) = 'object' THEN v_pj.stats ELSE '{}'::jsonb END;
  IF COALESCE(v_stats ->> 'repasCaserneJour', '') = v_jour THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_mange', 'jourCle', v_jour);
  END IF;

  SELECT data INTO v_data FROM public.budgets_nationaux WHERE id = v_pays FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'refectoire_vide'); END IF;
  v_data := COALESCE(v_data, '{}'::jsonb);

  v_ref := CASE WHEN jsonb_typeof(v_data -> 'refectoire') = 'object'
                THEN v_data -> 'refectoire' ELSE '{}'::jsonb END;
  v_commun := CASE WHEN jsonb_typeof(v_data -> 'caserneMatieres') = 'object'
                   THEN v_data -> 'caserneMatieres' ELSE '{}'::jsonb END;
  v_rations := GREATEST(0, COALESCE((v_ref ->> 'rations')::integer, 0));

  IF v_rations <= 0 THEN
    -- Fabrication automatique d'un lot de 10, sur le STOCK COMMUN : 1 cereale + 1 (viande OU poisson).
    v_cer := GREATEST(0, COALESCE((v_commun ->> 'cereales')::integer, 0));
    v_via := GREATEST(0, COALESCE((v_commun ->> 'viande')::integer, 0));
    v_poi := GREATEST(0, COALESCE((v_commun ->> 'poisson')::integer, 0));
    IF v_cer < 1 OR (v_via + v_poi) < 1 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ingredients_insuffisants',
                                'cereales', v_cer, 'viande', v_via, 'poisson', v_poi);
    END IF;
    v_prot := CASE WHEN v_via >= 1 THEN 'viande' ELSE 'poisson' END;
    v_commun := v_commun || jsonb_build_object('cereales', v_cer - 1,
                  v_prot, (CASE WHEN v_prot = 'viande' THEN v_via ELSE v_poi END) - 1);
    v_rations := 10;
    v_fab := true;
  END IF;

  v_rations := v_rations - 1;
  v_data := v_data
            || jsonb_build_object('caserneMatieres', v_commun)
            || jsonb_build_object('refectoire', v_ref || jsonb_build_object('rations', v_rations));
  UPDATE public.budgets_nationaux SET data = v_data, updated_at = now() WHERE id = v_pays;

  v_pa := LEAST(30, GREATEST(0, COALESCE(v_pj.pa, 0)) + 2);
  UPDATE public.personnages_donnees
     SET pa = v_pa, stats = v_stats || jsonb_build_object('repasCaserneJour', v_jour)
   WHERE name = p_joueur;

  RETURN jsonb_build_object('ok', true, 'pa', v_pa, 'rations', v_rations,
                            'fabrique', v_fab, 'proteine', v_prot,
                            'pays', v_pays, 'jourCle', v_jour);
END; $function$;

-- repondre_offre(text,text,boolean) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public
CREATE OR REPLACE FUNCTION public.repondre_offre(p_offre_id text, p_acteur text, p_acceptee boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_offre offres%ROWTYPE;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  IF COALESCE(p_offre_id,'')='' OR COALESCE(p_acteur,'')='' THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO v_offre FROM offres WHERE id=p_offre_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','offre_absente'); END IF;
  IF v_offre.statut<>'ouverte' THEN RETURN jsonb_build_object('ok',true,'deja_resolue',true,'statut',v_offre.statut); END IF;
  IF v_offre.expire_a<=now() THEN UPDATE offres SET statut='expiree',resolu_a=now() WHERE id=p_offre_id; RETURN jsonb_build_object('ok',false,'raison','offre_expiree'); END IF;
  IF p_acteur=v_offre.destinataire THEN
    UPDATE offres SET statut=CASE WHEN COALESCE(p_acceptee,false) THEN 'acceptee' ELSE 'refusee' END,resolu_a=now() WHERE id=p_offre_id;
    RETURN jsonb_build_object('ok',true,'deja_resolue',false,'statut',CASE WHEN COALESCE(p_acceptee,false) THEN 'acceptee' ELSE 'refusee' END,'type',v_offre.type,'actif',v_offre.actif,'emetteur',v_offre.emetteur,'destinataire',v_offre.destinataire,'montant',v_offre.montant);
  ELSIF p_acteur=v_offre.emetteur AND COALESCE(p_acceptee,false) IS NOT TRUE THEN
    UPDATE offres SET statut='annulee',resolu_a=now() WHERE id=p_offre_id;
    RETURN jsonb_build_object('ok',true,'deja_resolue',false,'statut','annulee');
  END IF;
  RETURN jsonb_build_object('ok',false,'raison','pas_partie_a_l_offre');
END;
$function$;

-- ressources_economie_empreinte_reelle() -> text | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ressources_economie_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      cle || '|' || public.ressources_economie_nombre(prix_base)
          || '|' || public.ressources_economie_nombre(prix_achat_fournisseur)
          || '|' || public.ressources_economie_nombre(plafond::numeric)
          || '|' || coalesce(source, ''),
      E'\n' ORDER BY cle COLLATE "C")), 16)
  FROM public.ressources_economie;
$function$;

-- ressources_economie_nombre(numeric) -> text | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.ressources_economie_nombre(n numeric)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN n IS NULL THEN ''
              WHEN n = trunc(n) THEN trunc(n)::bigint::text
              ELSE n::text END;
$function$;

-- restaurant_diner_acquitter(bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_diner_acquitter(p_invitation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text:=public.mon_personnage();i public.invitations_diner;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation FOR UPDATE;
 IF NOT FOUND OR i.contrat_restaurant IS DISTINCT FROM 'luthecia_v1' OR i.resultat_service IS NULL THEN RETURN '{"ok":false,"raison":"service_non_confirme"}'; END IF;
 IF i.inviteur=moi THEN
  IF i.lecture_inviteur THEN RETURN '{"ok":true,"rejeu":true}'; END IF;
  UPDATE public.invitations_diner SET lecture_inviteur=true WHERE id=i.id;
 ELSIF NOT i.invite_pnj AND i.invite=moi THEN
  IF i.lecture_invite THEN RETURN '{"ok":true,"rejeu":true}'; END IF;
  UPDATE public.invitations_diner SET lecture_invite=true WHERE id=i.id;
 ELSE RETURN '{"ok":false,"raison":"pas_mon_invitation"}'; END IF;
 RETURN '{"ok":true}';
END $function$;

-- restaurant_diner_creer(text,text,boolean,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_diner_creer(p_requete text, p_invite text, p_pnj boolean, p_message text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text:=public.mon_personnage(); i public.invitations_diner; p public.personnages_donnees; chance integer; etat text; accepte boolean;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 IF p_requete IS NULL OR p_requete !~ '^diner-[A-Za-z0-9-]{10,80}$' OR coalesce(p_invite,'')='' OR p_invite=moi OR p_pnj IS NULL THEN RETURN '{"ok":false,"raison":"parametres_invalides"}'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('restaurant:'||p_requete,0));
 SELECT * INTO i FROM public.invitations_diner WHERE requete_restaurant=p_requete FOR UPDATE;
 IF FOUND THEN
  IF i.inviteur=moi AND i.invite=p_invite AND i.invite_pnj=p_pnj AND coalesce(i.message,'')=left(coalesce(p_message,''),200) THEN RETURN jsonb_build_object('ok',true,'id',i.id,'statut',i.statut,'rejeu',true); END IF;
  RETURN '{"ok":false,"raison":"requete_incompatible"}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(ARRAY[moi,CASE WHEN NOT p_pnj THEN p_invite ELSE moi END]) ORDER BY name FOR UPDATE;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF NOT FOUND OR p.country IS DISTINCT FROM 'republic' OR p.current_city IS DISTINCT FROM 'capitale' OR p.current_building IS DISTINCT FROM 'hotel-republica' OR p.current_room IS DISTINCT FROM 'restaurant' THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.entreprises WHERE public.restaurant_luthecia_est_commerce(data) AND data->>'versionGastronomieLuthecia'='1') THEN RETURN '{"ok":false,"raison":"carte_non_installee"}'; END IF;
 etat:='attente';
 IF p_pnj THEN
  -- PNJ fixes de la salle, identites/relations de data.js, sans aucun personnage cree.
  chance:=public.restaurant_luthecia_pnj_chance(moi,p_invite);
  IF chance IS NULL THEN RETURN '{"ok":false,"raison":"pnj_non_present"}'; END IF;
  accepte:=floor(random()*100)+1<=chance;etat:=CASE WHEN accepte THEN 'acceptee' ELSE 'refusee' END;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=p_invite AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room='restaurant') THEN RETURN '{"ok":false,"raison":"invite_absent"}'; END IF;
 END IF;
 INSERT INTO public.invitations_diner(inviteur,invite,country,city,building_id,room_id,cout,type,message,statut,contrat_restaurant,requete_restaurant,invite_pnj,resultat_service)
 VALUES(moi,p_invite,'republic','capitale','hotel-republica','restaurant',300,'diner_affaires',left(coalesce(p_message,''),200),etat,'luthecia_v1',p_requete,p_pnj,CASE WHEN etat='refusee' THEN '{"ok":false,"raison":"invitation_refusee"}'::jsonb ELSE NULL END) RETURNING * INTO i;
 RETURN jsonb_build_object('ok',true,'id',i.id,'statut',i.statut);
END $function$;

-- restaurant_diner_proteger() -> trigger | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_diner_proteger()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 IF current_user NOT IN('postgres','supabase_admin') THEN
  IF TG_OP<>'DELETE' AND NEW.contrat_restaurant IS NOT NULL THEN RAISE EXCEPTION 'diner_par_rpc_requis' USING ERRCODE='42501'; END IF;
  IF TG_OP<>'INSERT' AND OLD.contrat_restaurant IS NOT NULL THEN RAISE EXCEPTION 'diner_par_rpc_requis' USING ERRCODE='42501'; END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF; RETURN NEW;
END $function$;

-- restaurant_diner_repondre(bigint,boolean,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_diner_repondre(p_invitation bigint, p_accepte boolean, p_reponse text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text:=public.mon_personnage(); i public.invitations_diner; etat text:=CASE WHEN p_accepte THEN 'acceptee' ELSE 'refusee' END;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation FOR UPDATE;
 IF NOT FOUND OR i.contrat_restaurant IS DISTINCT FROM 'luthecia_v1' OR i.invite IS DISTINCT FROM moi OR i.invite_pnj OR p_accepte IS NULL THEN RETURN '{"ok":false,"raison":"pas_mon_invitation"}'; END IF;
 IF i.statut=etat THEN RETURN '{"ok":true,"rejeu":true}'; END IF;
 IF i.statut<>'attente' OR i.resultat_service IS NOT NULL THEN RETURN '{"ok":false,"raison":"invitation_close"}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room='restaurant') THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 UPDATE public.invitations_diner SET statut=etat,reponse=left(coalesce(p_reponse,''),200),resultat_service=CASE WHEN NOT p_accepte THEN '{"ok":false,"raison":"invitation_refusee"}'::jsonb ELSE NULL END WHERE id=i.id;
 RETURN '{"ok":true}';
END $function$;

-- restaurant_diner_servir(bigint) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_diner_servir(p_invitation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text:=public.mon_personnage(); i public.invitations_diner; d jsonb; entreprise text; restant integer:=2; disponible integer; pris integer; menu text; articles jsonb:='[]'; r jsonb; detail text; bonus integer; precedent text;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}'; END IF;
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation FOR UPDATE;
 IF NOT FOUND OR i.inviteur IS DISTINCT FROM moi OR i.contrat_restaurant IS DISTINCT FROM 'luthecia_v1' THEN RETURN '{"ok":false,"raison":"pas_mon_invitation"}'; END IF;
 IF i.resultat_service IS NOT NULL THEN RETURN i.resultat_service||'{"rejeu":true}'; END IF;
 IF i.statut<>'acceptee' THEN RETURN '{"ok":false,"raison":"acceptation_requise"}'; END IF;
 -- Une seule entreprise canonique. Pas de recherche d'un autre restaurant pour satisfaire le stock.
 SELECT id,data INTO entreprise,d FROM public.entreprises WHERE public.restaurant_luthecia_est_commerce(data) AND data->>'versionGastronomieLuthecia'='1' ORDER BY id LIMIT 1 FOR UPDATE;
 IF d IS NULL THEN RETURN '{"ok":false,"raison":"commerce_introuvable"}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(ARRAY[moi,CASE WHEN NOT i.invite_pnj THEN i.invite ELSE moi END]) ORDER BY name FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room='restaurant') OR
   (i.invite_pnj AND public.restaurant_luthecia_pnj_chance(moi,i.invite) IS NULL) OR
   (NOT i.invite_pnj AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=i.invite AND country='republic' AND current_city='capitale' AND current_building='hotel-republica' AND current_room='restaurant')) THEN r:='{"ok":false,"raison":"action_obsolete"}';
 ELSE
  FOREACH menu IN ARRAY ARRAY['menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3'] LOOP
   disponible:=greatest(0,coalesce((d->'stockProduits'->>menu)::integer,0));pris:=least(restant,disponible);
   IF pris>0 THEN articles:=articles||jsonb_build_array(jsonb_build_object('produit',menu,'qte',pris));restant:=restant-pris; END IF;
   EXIT WHEN restant=0;
  END LOOP;
  IF restant>0 OR coalesce((d->'stockProduits'->>'champagne_luthecia')::integer,0)<2 THEN r:='{"ok":false,"raison":"stock_insuffisant"}';
  ELSE
   articles:=articles||'[{"produit":"champagne_luthecia","qte":2}]';
   -- La meme vente qu'un service historique, mais le PA/paiement, les stocks et les effets
   -- sont un seul acte et un seul recu. Aucun chiffre de prix/quantite fourni par le navigateur.
   precedent:=current_setting('rp.diner_luthecia',true);
   BEGIN
    PERFORM set_config('rp.diner_luthecia','on',true);
    r:=public.commerce_vendre_produit_interne(moi,entreprise,articles,'service','diner_affaires',2,300,NULL,NULL);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'diner_vente_refusee' USING DETAIL=r::text; END IF;
    SELECT montant INTO bonus FROM public.pa_bonus_differes WHERE source='diner_affaires';
    IF bonus IS DISTINCT FROM 3 THEN RAISE EXCEPTION 'bonus_diner_incompatible'; END IF;
    UPDATE public.personnages_donnees SET hp=least(100,coalesce(hp,100)+10),moral=least(100,coalesce(moral,75)+2),
      resources=jsonb_set(coalesce(resources,'{}'),'{inf}',to_jsonb(least(100,coalesce((resources->>'inf')::numeric,0)+5)),true),
      bonus_pa_differe=least(30,coalesce(bonus_pa_differe,0)+bonus),updated_at=now()
    WHERE name=moi OR (NOT i.invite_pnj AND name=i.invite);
    r:=jsonb_build_object('ok',true,'total',300,'repas',2,'champagnes',2,'pa',2,'articles',articles);
    PERFORM set_config('rp.diner_luthecia',coalesce(precedent,''),true);
   EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'diner_vente_refusee' THEN RAISE; END IF;
    GET STACKED DIAGNOSTICS detail=PG_EXCEPTION_DETAIL;r:=detail::jsonb;
   END;
  END IF;
 END IF;
 UPDATE public.invitations_diner SET resultat_service=r WHERE id=i.id;
 RETURN r;
END $function$;

-- restaurant_diner_suivre() -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_diner_suivre()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT jsonb_build_object('ok',public.mon_personnage() IS NOT NULL,'invitations',coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.id),'[]'))
 FROM public.invitations_diner i WHERE i.contrat_restaurant='luthecia_v1' AND
 ((i.inviteur=public.mon_personnage() AND NOT i.lecture_inviteur) OR (NOT i.invite_pnj AND i.invite=public.mon_personnage() AND i.resultat_service IS NOT NULL AND NOT i.lecture_invite));
$function$;

-- restaurant_luthecia_carte(jsonb,text) -> jsonb | sql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_carte(d jsonb, acteur text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT CASE WHEN public.restaurant_luthecia_est_commerce(d) THEN coalesce(d->'cartesParPiece'->(SELECT current_room FROM public.personnages_donnees WHERE name=acteur),'[]'::jsonb) ELSE coalesce(d->'carte','[]'::jsonb) END;
$function$;

-- restaurant_luthecia_configurer(jsonb) -> jsonb | plpgsql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_configurer(d jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE bar jsonb;restaurant jsonb;union_carte jsonb;k text;
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) OR d->>'versionGastronomieLuthecia'='1' THEN RETURN d; END IF;
 IF jsonb_typeof(d->'stockProduits') IS DISTINCT FROM 'object' OR jsonb_typeof(d->'parametres'->'stockMax') IS DISTINCT FROM 'object' OR jsonb_typeof(d->'parametres'->'prixVente') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'structure_commerce_inconnue'; END IF;
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]') INTO bar FROM jsonb_array_elements_text(coalesce(d->'carte','[]')) WITH ORDINALITY a(x,ord) WHERE EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=x AND (categorie='boisson' OR id='snack_buvette'));
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]') INTO restaurant FROM jsonb_array_elements_text(coalesce(d->'carte','[]')) WITH ORDINALITY a(x,ord) WHERE EXISTS(SELECT 1 FROM public.recettes_commerce WHERE id=x AND (categorie='boisson' OR id IN('menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3'))) AND x<>'cocktail_luthecia';
  bar:=bar||'["cocktail_luthecia","champagne_luthecia"]';restaurant:=restaurant||'["champagne_luthecia","amuse_bouche_luthecia"]';
  SELECT jsonb_agg(DISTINCT x) INTO bar FROM jsonb_array_elements(bar) a(x);
  SELECT jsonb_agg(DISTINCT x) INTO restaurant FROM jsonb_array_elements(restaurant) a(x);
  SELECT jsonb_agg(DISTINCT x) INTO union_carte FROM jsonb_array_elements(bar||restaurant) a(x);
  d:=d||jsonb_build_object('versionGastronomieLuthecia',1,'cartesParPiece',jsonb_build_object('bar',bar,'restaurant',restaurant),'carte',union_carte);
  FOREACH k IN ARRAY ARRAY['champagne_luthecia','cocktail_luthecia','amuse_bouche_luthecia'] LOOP
   IF NOT(coalesce(d->'stockProduits','{}') ? k) THEN d:=jsonb_set(d,ARRAY['stockProduits',k],'0',true); END IF;
   IF NOT(coalesce(d->'parametres'->'stockMax','{}') ? k) THEN d:=jsonb_set(d,ARRAY['parametres','stockMax',k],'20',true); END IF;
  END LOOP;
  FOREACH k IN ARRAY ARRAY['champagne_luthecia','cocktail_luthecia'] LOOP d:=jsonb_set(d,ARRAY['parametres','prixVente',k],'25',true); END LOOP;
  FOREACH k IN ARRAY ARRAY['menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3'] LOOP d:=jsonb_set(d,ARRAY['parametres','prixVente',k],'125',true); END LOOP;
  d:=jsonb_set(d,ARRAY['parametres','prixVente','amuse_bouche_luthecia'],to_jsonb(coalesce((d->'parametres'->'prixVente'->>'snack_buvette')::numeric,round(public.commerce_cout_revient_portion(d,'amuse_bouche_luthecia')*2))),true);
 RETURN d;
END $function$;

-- restaurant_luthecia_est_commerce(jsonb) -> boolean | sql | SECURITY INVOKER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_est_commerce(d jsonb)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 SELECT coalesce(d->>'country'='republic' AND d->>'city'='capitale' AND d->>'buildingId'='hotel-republica',false);
$function$;

-- restaurant_luthecia_initialiser() -> trigger | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_initialiser()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN NEW.data:=public.restaurant_luthecia_configurer(NEW.data); RETURN NEW; END $function$;

-- restaurant_luthecia_pnj_chance(text,text) -> integer | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_pnj_chance(acteur text, invite text)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE p public.personnages_donnees; chance integer;
BEGIN
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur;
 IF NOT FOUND THEN RETURN NULL; END IF;
 chance:=CASE invite WHEN 'Gaston Sauceblanche' THEN 60 WHEN 'Régis Gondasse' THEN 60 WHEN 'Yvette Gratinée' THEN 60 WHEN 'Jean Dupont' THEN 60 WHEN 'Marie Leblanc' THEN 20 ELSE NULL END;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.employes)='array' THEN p.employes ELSE '[]' END) e WHERE e->>'nom'=invite AND e->'inGroupe'='true'::jsonb)
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p.escort_active)='array' THEN p.escort_active ELSE '[]' END) e WHERE e->>'nom'=invite)
  OR EXISTS(SELECT 1 FROM public.pnj_membres WHERE nom=invite AND leader_pj IN(acteur,'pj:'||acteur) AND statut='actif') THEN chance:=95; END IF;
 -- Reutiliser la projection serveur des agents, jamais les vrais noms ni un cache de presence.
 IF acteur=public.mon_personnage() AND EXISTS(
  SELECT 1 FROM jsonb_array_elements(coalesce(public.agents_couverture_de_mon_groupe()->'agents','[]'::jsonb)) a WHERE a->>'nom'=invite
 ) THEN chance:=95; END IF;
 RETURN chance;
END $function$;

-- restaurant_luthecia_production_verifier(jsonb,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_production_verifier(d jsonb, acteur text, recette text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE c numeric;
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) THEN RETURN '{"ok":true}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND country='republic' AND current_city='capitale' AND current_building='hotel-republica') OR NOT(public.restaurant_luthecia_carte(d,acteur) @> jsonb_build_array(recette)) THEN RETURN '{"ok":false,"raison":"hors_carte_piece"}'; END IF;
 IF coalesce(d->>'proprietaire','PNJ')='PNJ' AND recette IN('champagne_luthecia','cocktail_luthecia') THEN
  IF d->'coutMoyenMatieres'->>'fruits_legumes' IS NULL THEN RETURN '{"ok":false,"raison":"cout_matiere_inconnu"}'; END IF;
  c:=public.commerce_cout_revient_portion(d,recette);
  IF c IS NULL OR c*2>25 THEN RETURN jsonb_build_object('ok',false,'raison','marge_pnj_insuffisante','coutUnitaire',c); END IF;
 END IF;
 RETURN '{"ok":true}';
END $function$;

-- restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_vente_verifier(d jsonb, acteur text, produits jsonb, mode_vente text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 -- Compatibilite des appels historiques : aucune reservation deduite d'un panier vide.
 RETURN public.restaurant_luthecia_vente_verifier(d,acteur,produits,mode_vente,NULL);
END $function$;

-- restaurant_luthecia_vente_verifier(jsonb,text,jsonb,text,text) -> jsonb | plpgsql | SECURITY DEFINER | search_path=public, pg_temp
CREATE OR REPLACE FUNCTION public.restaurant_luthecia_vente_verifier(d jsonb, acteur text, produits jsonb, mode_vente text, ordre text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 IF NOT public.restaurant_luthecia_est_commerce(d) THEN RETURN '{"ok":true}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND country='republic' AND current_city='capitale' AND current_building='hotel-republica'
  AND CASE WHEN ordre='reserver_chambre_hotel' THEN current_room='accueil' ELSE current_room IN('bar','restaurant') END)
 THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 IF d->>'versionGastronomieLuthecia' IS DISTINCT FROM '1' THEN RETURN '{"ok":false,"raison":"carte_non_installee"}'; END IF;
 IF ordre='reserver_chambre_hotel' THEN
  -- Une prestation exacte, sans articles ni autre mode, a l'accueil uniquement.
  IF mode_vente IS DISTINCT FROM 'service' OR produits IS DISTINCT FROM '[]'::jsonb THEN
   RETURN '{"ok":false,"raison":"reservation_invalide"}';
  END IF;
 ELSE
  -- Le service des diners reste reserve a sa porte atomique existante.
  IF mode_vente='service' AND current_setting('rp.diner_luthecia',true) IS DISTINCT FROM 'on' THEN
   RETURN '{"ok":false,"raison":"service_par_invitation_requis"}';
  END IF;
 END IF;
 RETURN '{"ok":true}';
END $function$;
