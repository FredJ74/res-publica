-- STAROVKA ET SOVARKA (décisions de Fred, 18/11/2026, nuit ; GAME-DESIGN-NOVOMIRSK.md « PNJ de Starovka ») :
--  1. Starovka n'est accessible qu'en train : pas de bus ni de taxi entre une autre ville de Sovarka et
--     Starovka (le véhicule personnel n'y va déjà pas : routes_vehicules). Le goulag garde ses accès propres.
--  2. Syndicat de Sovarka = syndicat unique d'État qui ne fait jamais grève : pas de blocus syndical en Sovarka.
--  3. Magasin du kolkhoze de Starovka : commerce PNJ (moteur « tabac-presse », caisse autonome), six articles,
--     prix PNJ par la règle commune (2 × coût de revient, PA à 15 PSK) ; jamais transmissible à un PJ.
-- Aucune donnée de joueur touchée. Idempotente.
BEGIN;

-- 1. Train seulement pour Starovka.
DO $train$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure);
  IF position('starovka_train_seulement' IN d) > 0 THEN RETURN; END IF;
  a := E' IF p_mode NOT IN (''train'',''bus'',''avion'',''bateau'',''taxi_caserne'',''taxi_qhs'') OR p_mode IS NULL THEN RETURN jsonb_build_object(''ok'',false,''raison'',''controle_douanier_requis'');END IF;\n';
  -- La fiche de l'acteur est lue plus bas : la position est relue ici.
  b := a || E' -- Starovka n''est reliée qu''en train (Fred, 18/11/2026) : ni bus ni taxi vers ou depuis Starovka.\n'
         || E' IF p_mode=''bus'' AND p_pays=''soviet'' AND (p_ville=''ville_a'' OR EXISTS (SELECT 1 FROM public.personnages_donnees x WHERE x.name=moi AND x.country=''soviet'' AND x.current_city=''ville_a'')) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''starovka_train_seulement'');END IF;\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'transport_effectuer : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $train$;

-- 2. Pas de blocus syndical en Sovarka.
DO $blocus$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.blocus_syndical_organiser(text,integer,text)'::regprocedure);
  IF position('syndicat_etat_sans_greve' IN d) > 0 THEN RETURN; END IF;
  a := E'  v_pays := coalesce(p.country, ''republic'');\n';
  b := a || E'  -- Sovarka (Fred, 18/11/2026) : syndicat unique d''État, « le travailleur ne bloque pas son propre outil ».\n'
         || E'  IF v_pays = ''soviet'' THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''syndicat_etat_sans_greve''); END IF;\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'blocus_syndical_organiser : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $blocus$;

-- 3. Magasin du kolkhoze de Starovka.
INSERT INTO public.commerces_types (cle, type) VALUES ('magasin-kolkhoze-starovka', 'tabac-presse')
ON CONFLICT (cle) DO NOTHING;

INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, categorie, types_autorises, pays_autorises,
  villes_autorisees, buildings_autorises, icone, image, description, effets, famille_produit_marche, bonus_integration_ville, generique_id) VALUES
 ('kolkhoze_viande_renne','kolkhoze','Viande de renne',1,4,'{"viande":1}','objet','["tabac-presse"]','["soviet"]','["ville_a"]','["magasin-kolkhoze-starovka"]',
  'ti-meat',NULL,'Un morceau de renne du kolkhoze, découpé le matin même.',NULL,'aliment',NULL,NULL),
 ('kolkhoze_lait_renne','kolkhoze','Lait de renne',1,8,'{"laitages":1}','objet','["tabac-presse"]','["soviet"]','["ville_a"]','["magasin-kolkhoze-starovka"]',
  'ti-milk',NULL,'Un pot de lait de renne, épais et gras, tiré à la ferme.',NULL,'aliment',NULL,NULL),
 ('kolkhoze_confiture_airelles','kolkhoze','Confiture d''airelles',1,6,'{"fruits_legumes":1}','objet','["tabac-presse"]','["soviet"]','["ville_a"]','["magasin-kolkhoze-starovka"]',
  'ti-jar',NULL,'Les airelles de la toundra, cuites au sucre par les femmes du kolkhoze.',NULL,'aliment',NULL,NULL),
 ('kolkhoze_graisse_renne','kolkhoze','Bocal de graisse de renne',1,6,'{"viande":1}','objet','["tabac-presse"]','["soviet"]','["ville_a"]','["magasin-kolkhoze-starovka"]',
  'ti-jar',NULL,'La graisse de renne fondue qui tient chaud tout l''hiver.',NULL,'aliment',NULL,NULL),
 ('kolkhoze_peau_renne','kolkhoze','Peau de renne',1,2,'{"textile":1}','objet','["tabac-presse"]','["soviet"]','["ville_a"]','["magasin-kolkhoze-starovka"]',
  'ti-feather',NULL,'Une peau tannée, douce et chaude, pour une couverture ou des bottes.',NULL,NULL,NULL,NULL),
 ('kolkhoze_bois_renne','kolkhoze','Bois de renne',1,3,'{"viande":1}','objet','["tabac-presse"]','["soviet"]','["ville_a"]','["magasin-kolkhoze-starovka"]',
  'ti-antenna',NULL,'Une ramure tombée au printemps, polie à la main ; un souvenir de Starovka.',NULL,NULL,NULL,NULL)
ON CONFLICT (id) DO NOTHING;

-- Prix : 2 × (coût moyen des matières + 15 PSK × PA) / portions, arrondi à l'unité inférieure.
INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres) VALUES
 ('magasin-kolkhoze-starovka@soviet.ville_a','tabac-presse',500,'{"viande":10,"laitages":10,"fruits_legumes":10,"textile":10}',
  '{"viande":2,"laitages":1,"fruits_legumes":1,"textile":1}',
  '["kolkhoze_viande_renne","kolkhoze_lait_renne","kolkhoze_confiture_airelles","kolkhoze_graisse_renne","kolkhoze_peau_renne","kolkhoze_bois_renne"]',
  '{"stockMax":{"kolkhoze_viande_renne":20,"kolkhoze_lait_renne":20,"kolkhoze_confiture_airelles":20,"kolkhoze_graisse_renne":20,"kolkhoze_peau_renne":20,"kolkhoze_bois_renne":20},
    "prixVente":{"kolkhoze_viande_renne":8,"kolkhoze_lait_renne":4,"kolkhoze_confiture_airelles":5,"kolkhoze_graisse_renne":5,"kolkhoze_peau_renne":16,"kolkhoze_bois_renne":11}}')
ON CONFLICT (cle) DO NOTHING;

INSERT INTO public.entreprises (id, data, updated_at)
SELECT 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka', jsonb_build_object(
  'id', 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka', 'type', 'tabac-presse', 'country', 'soviet', 'city', 'ville_a',
  'buildingId', 'magasin-kolkhoze-starovka', 'roomId', NULL, 'proprietaire', 'PNJ', 'nonTransmissible', true,
  'caisse', d.caisse, 'stockMatieres', d.stock_matieres, 'coutMoyenMatieres', d.cout_moyen_matieres,
  'stockProduits', '{"kolkhoze_viande_renne":10,"kolkhoze_lait_renne":10,"kolkhoze_confiture_airelles":10,"kolkhoze_graisse_renne":10,"kolkhoze_peau_renne":10,"kolkhoze_bois_renne":10}'::jsonb,
  'carte', d.carte, 'parametres', d.parametres, 'historique', '[]'::jsonb), now()
  FROM public.commerces_dotations d WHERE d.cle = 'magasin-kolkhoze-starovka@soviet.ville_a'
ON CONFLICT (id) DO NOTHING;

-- Les commerces des kolkhozes ne sont jamais transmissibles à un PJ (compromis refusé).
DO $compromis$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.entreprise_signer_compromis(text,text,numeric,integer)'::regprocedure);
  IF position('nonTransmissible' IN d) > 0 THEN RETURN; END IF;
  a := E'  IF COALESCE(v_data->>''proprietaire'','''') <> ''PNJ'' THEN\n    RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_rachetable'');\n  END IF;\n';
  b := a || E'  -- Commerces des kolkhozes (Fred, 18/11/2026) : jamais transmissibles à un PJ.\n'
         || E'  IF COALESCE((v_data->>''nonTransmissible'')::boolean, false) THEN\n'
         || E'    RETURN jsonb_build_object(''ok'', false, ''raison'', ''commerce_kolkhoze_non_transmissible'');\n  END IF;\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'entreprise_signer_compromis : ancrage introuvable'; END IF;
  EXECUTE replace(d, a, b);
END $compromis$;

DO $$ BEGIN
  IF position('starovka_train_seulement' IN pg_get_functiondef('public.transport_effectuer(text,text,text,uuid)'::regprocedure)) = 0
     OR position('syndicat_etat_sans_greve' IN pg_get_functiondef('public.blocus_syndical_organiser(text,integer,text)'::regprocedure)) = 0
     OR position('nonTransmissible' IN pg_get_functiondef('public.entreprise_signer_compromis(text,text,numeric,integer)'::regprocedure)) = 0
     OR (SELECT count(*) FROM public.recettes_commerce WHERE 'magasin-kolkhoze-starovka' = ANY (SELECT jsonb_array_elements_text(buildings_autorises))) <> 6
     OR NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'tabac-presse-soviet-ville_a-magasin-kolkhoze-starovka'
                     AND data->>'proprietaire' = 'PNJ' AND (data->>'nonTransmissible')::boolean AND jsonb_array_length(data->'carte') = 6) THEN
    RAISE EXCEPTION 'starovka_train_syndicat_kolkhoze : controle structurel en echec';
  END IF;
END $$;
COMMIT;
