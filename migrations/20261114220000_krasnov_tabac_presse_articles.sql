-- TABAC/PRESSE DE KRASNOV : quatre articles (demande de Fred du 14/11/2026, 21 h 52 : « 4 articles, a ta convenance »).
-- Regle des commerces (06/11) : 2 familles, 4 articles en freemium.
--   Tabac & loterie   : papirossy « Etoile du Nord » (makhorka du kolkhoze, +2 moral, fumee sur le pas de la porte),
--                       billet du « Loto du Plan » (+1 moral : personne n'a jamais gagne, l'espoir fait vivre).
--   Presse & papeterie : carte postale « Krasnov, la place de l'Ours » (objet ecrit et envoye, mecanique existante),
--                       revue « Chasse, Peche & Tracteurs » (integration locale : +1 ENT a Krasnov, comme la chemise
--                       de bucheron, non cumulable).
-- Moteur commun des commerces PNJ (commerces_types, commerces_dotations, recettes_commerce) : type nouveau
-- « tabac-presse », caisse autonome (ce n'est ni un marche ni une buvette), rachetable comme tout commerce de Sovarka.
-- Prix PNJ : formule commune, 2 x cout de revient, echelle de Sovarka (PA a 15 PSK) :
--   papirossy (1 plantes + 1 PA) / 15 = 2 ; loto (1 bois + 1 PA) / 20 = 2 ; carte (1 bois + 1 PA) / 16 = 2 ;
--   revue (1 bois + 1 PA) / 6 = 5 PSK.
-- Stock d'ouverture : 10 de chaque article, pour que la boutique ne soit pas vide avant la premiere production.
--
-- CORRECTIF DU SOCLE (meme lot) : le 27/10 (20261027180100_inventaire_recolte_commerce), la vente deposait elle-meme
-- les produits de marche non alimentaires (familleProduitMarche) dans l'inventaire. Une redefinition posterieure de
-- commerce_vendre_produit_interne (31/10) a efface ce depot : depuis, un souvenir, une carte postale, un aliment a
-- emporter ou une chemise achetes au marche sont payes sans arriver dans l'inventaire. Le depot est retabli, avec
-- les champs que lisent l'ecran et le serveur : dateAchat (fraicheur d'un aliment, inventaire_consommer),
-- etatCarte « vierge » et modele (carte postale a ecrire), villeOrigine, bonusIntegrationVille.
-- Aucune donnee de joueur touchee. Idempotente.
BEGIN;

-- 1. Depot des produits de marche par la vente.
DO $do$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure);
  IF position('familleProduitMarche deposes' IN v_def) = 0 THEN
    IF (length(v_def) - length(replace(v_def, E'  RETURN jsonb_build_object(''ok'', true, ''mode'', p_mode,', ''))) / length(E'  RETURN jsonb_build_object(''ok'', true, ''mode'', p_mode,') <> 1
       OR position(E'  v_pa_metier numeric := 0; v_pa_actuel integer;\n' IN v_def) = 0 THEN
      RAISE EXCEPTION 'commerce_vendre_produit_interne : ancrage introuvable';
    END IF;
    v_def := replace(v_def, E'  RETURN jsonb_build_object(''ok'', true, ''mode'', p_mode,',
      E'  -- Produits du marche non alimentaires (familleProduitMarche deposes par le serveur, 27/10 ; retabli le 14/11/2026).\n'
      || E'  FOR v_ligne IN SELECT value FROM jsonb_array_elements(v_livraison) LOOP\n'
      || E'    IF coalesce(v_ligne ->> ''familleProduitMarche'', '''') <> '''' THEN\n'
      || E'      FOR v_i IN 1..coalesce((v_ligne ->> ''qte'')::numeric, 1)::integer LOOP\n'
      || E'        v_r := public.inventaire_deposer_interne(p_acteur, jsonb_strip_nulls(jsonb_build_object(\n'
      || E'          ''id'', (v_ligne ->> ''produit'') || ''_'' || replace(gen_random_uuid()::text, ''-'', ''''),\n'
      || E'          ''type'', v_ligne ->> ''produit'', ''name'', v_ligne ->> ''label'', ''icon'', coalesce(v_ligne ->> ''icone'', ''ti-package''),\n'
      || E'          ''imageUrl'', v_ligne ->> ''image'', ''desc'', v_ligne ->> ''description'', ''villeOrigine'', v_ville,\n'
      || E'          ''dateAchat'', CASE WHEN v_ligne ->> ''familleProduitMarche'' = ''aliment'' THEN floor(extract(epoch FROM now()) * 1000) END,\n'
      || E'          ''etatCarte'', CASE WHEN v_ligne ->> ''familleProduitMarche'' = ''carte_postale'' THEN ''vierge'' END,\n'
      || E'          ''modele'', CASE WHEN v_ligne ->> ''familleProduitMarche'' = ''carte_postale'' THEN v_ligne ->> ''produit'' END,\n'
      || E'          ''familleProduitMarche'', v_ligne -> ''familleProduitMarche'', ''bonusIntegrationVille'', v_ligne -> ''bonusIntegrationVille'')), true);\n'
      || E'        IF coalesce((v_r ->> ''ok'')::boolean, false) IS NOT TRUE THEN\n'
      || E'          RAISE EXCEPTION ''commerce_vendre_produit_interne : depot refuse %'', v_r;\n'
      || E'        END IF;\n'
      || E'      END LOOP;\n'
      || E'    END IF;\n'
      || E'  END LOOP;\n'
      || E'  RETURN (SELECT jsonb_build_object(''inventory'', inventory, ''revision'', inventory_revision) FROM public.personnages_donnees WHERE name = p_acteur)\n'
      || E'    || jsonb_build_object(''ok'', true, ''mode'', p_mode,');
    v_def := replace(v_def, E'  v_pa_metier numeric := 0; v_pa_actuel integer;\n', E'  v_pa_metier numeric := 0; v_pa_actuel integer; v_i integer;\n');
    EXECUTE v_def;
  END IF;
END $do$;

-- 2. Le commerce.
INSERT INTO public.commerces_types (cle, type) VALUES ('tabac-presse-krasnov', 'tabac-presse')
ON CONFLICT (cle) DO NOTHING;

INSERT INTO public.recettes_commerce (id, source, label, pa, portions, materiaux, categorie, types_autorises, pays_autorises,
  villes_autorisees, buildings_autorises, icone, image, description, effets, famille_produit_marche, bonus_integration_ville, generique_id) VALUES
 ('krasnov_papirossy','tabac','Papirossy « Étoile du Nord »',1,15,'{"plantes":1}','snack','["tabac-presse"]','["soviet"]','["ville_b"]','["tabac-presse-krasnov"]',
  'ti-smoking',NULL,'Cigarettes à bout de carton roulées avec la makhorka du kolkhoze. On les fume sur le pas de la porte, en regardant passer les tracteurs.',
  '{"moral":2}',NULL,NULL,NULL),
 ('krasnov_loto_plan','tabac','Billet du Loto du Plan',1,20,'{"bois":1}','snack','["tabac-presse"]','["soviet"]','["ville_b"]','["tabac-presse-krasnov"]',
  'ti-ticket',NULL,'On gratte, on lit « Le Plan a gagné ». Personne n''a jamais gagné, mais l''espoir fait vivre.',
  '{"moral":1}',NULL,NULL,NULL),
 ('carte_krasnov_place_ours','tabac','Carte postale — Krasnov, la place de l''Ours',1,16,'{"bois":1}','objet','["tabac-presse"]','["soviet"]','["ville_b"]','["tabac-presse-krasnov"]',
  'ti-mail','images/Sovarka/Krasnov/Krasnov_place_ours.webp','La statue de l''Ours, ses bancs et la mairie, sous la neige. À écrire et à envoyer.',
  NULL,'carte_postale',NULL,'carte-postale'),
 ('revue_chasse_peche_tracteurs','tabac','Revue « Chasse, Pêche & Tracteurs »',1,6,'{"bois":1}','objet','["tabac-presse"]','["soviet"]','["ville_b"]','["tabac-presse-krasnov"]',
  'ti-news',NULL,'Le mensuel des forestiers de Krasnov : le brochet record, le nouveau modèle de tracteur, et les petites annonces du kolkhoze.',
  NULL,'integration_locale','soviet.ville_b','imprime')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.commerces_dotations (cle, type, caisse, stock_matieres, cout_moyen_matieres, carte, parametres) VALUES
 ('tabac-presse-krasnov@soviet.ville_b','tabac-presse',500,'{"plantes":10,"bois":10}','{"plantes":1,"bois":1}',
  '["krasnov_papirossy","krasnov_loto_plan","carte_krasnov_place_ours","revue_chasse_peche_tracteurs"]',
  '{"stockMax":{"krasnov_papirossy":20,"krasnov_loto_plan":20,"carte_krasnov_place_ours":20,"revue_chasse_peche_tracteurs":20},
    "prixVente":{"krasnov_papirossy":2,"krasnov_loto_plan":2,"carte_krasnov_place_ours":2,"revue_chasse_peche_tracteurs":5}}')
ON CONFLICT (cle) DO NOTHING;

-- Ouverture avec un stock (le moteur cree sinon le commerce a vide, au premier passage).
INSERT INTO public.entreprises (id, data, updated_at)
SELECT 'tabac-presse-soviet-ville_b-tabac-presse-krasnov', jsonb_build_object(
  'id', 'tabac-presse-soviet-ville_b-tabac-presse-krasnov', 'type', 'tabac-presse', 'country', 'soviet', 'city', 'ville_b',
  'buildingId', 'tabac-presse-krasnov', 'roomId', NULL, 'proprietaire', 'PNJ',
  'caisse', d.caisse, 'stockMatieres', d.stock_matieres, 'coutMoyenMatieres', d.cout_moyen_matieres,
  'stockProduits', '{"krasnov_papirossy":10,"krasnov_loto_plan":10,"carte_krasnov_place_ours":10,"revue_chasse_peche_tracteurs":10}'::jsonb,
  'carte', d.carte, 'parametres', d.parametres, 'historique', '[]'::jsonb), now()
  FROM public.commerces_dotations d WHERE d.cle = 'tabac-presse-krasnov@soviet.ville_b'
ON CONFLICT (id) DO NOTHING;

-- 3. Controles structurels.
DO $$ BEGIN
  IF position('familleProduitMarche deposes' IN pg_get_functiondef('public.commerce_vendre_produit_interne(text,text,jsonb,text,text,integer,integer,text,numeric)'::regprocedure)) = 0
     OR (SELECT count(*) FROM public.recettes_commerce WHERE 'tabac-presse-krasnov' = ANY (SELECT jsonb_array_elements_text(buildings_autorises))) <> 4
     OR NOT EXISTS (SELECT 1 FROM public.commerces_types WHERE cle = 'tabac-presse-krasnov' AND type = 'tabac-presse')
     OR NOT EXISTS (SELECT 1 FROM public.entreprises WHERE id = 'tabac-presse-soviet-ville_b-tabac-presse-krasnov'
                     AND data->>'proprietaire' = 'PNJ' AND jsonb_array_length(data->'carte') = 4) THEN
    RAISE EXCEPTION 'krasnov_tabac_presse_articles : controle structurel en echec';
  END IF;
END $$;
COMMIT;
