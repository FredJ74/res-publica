-- Canal technique autorise uniquement ; ne sert pas a exercer un acte en production.
BEGIN;
SET TRANSACTION READ ONLY;
SELECT p.proname,pg_get_function_identity_arguments(p.oid) signature,md5(p.prosrc) empreinte,
 p.prosecdef,p.proconfig,pg_get_userbyid(p.proowner) proprietaire,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute,
 pg_get_functiondef(p.oid) definition
FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname IN
 ('commerce_produire','commerce_vendre_produit_interne','tournee_creer','tournee_cloturer',
 'agents_couverture_de_mon_groupe','entreprise_assurer_existence','commerce_cout_revient_portion','commerce_fixer_parametres',
 'payer_ordre','helvetia_debiter_fonds_ordinaires','personnages_vue_modifier',
 'restaurant_diner_creer','restaurant_diner_repondre','restaurant_diner_servir','restaurant_diner_suivre','restaurant_diner_acquitter')
ORDER BY p.proname,signature;
SELECT id,label,pa,portions,materiaux,prix_fixe,categorie,pays_autorises,villes_autorisees,buildings_autorises,effets
FROM public.recettes_commerce WHERE id IN('vin','cafe_boisson','snack_buvette','menu_gastronomique_1','menu_gastronomique_2','menu_gastronomique_3','champagne_luthecia','cocktail_luthecia','amuse_bouche_luthecia') ORDER BY id;
SELECT cle,valeur FROM public.entreprises_constantes WHERE cle IN('cout_main_oeuvre_pa_alimentaire','pa_tournee','stock_max_commerce');
SELECT source,montant FROM public.pa_bonus_differes WHERE source='diner_affaires';
SELECT id,data->'carte' carte,data->'cartesParPiece' cartes,data->'parametres' parametres,data->'stockProduits' stock,data->'coutMoyenMatieres' couts,
 md5((data-ARRAY['carte','cartesParPiece','versionGastronomieLuthecia','stockProduits','parametres'])::text) empreinte_identite_caisse_matieres,
 md5(((data->'stockProduits')-ARRAY['champagne_luthecia','cocktail_luthecia','amuse_bouche_luthecia'])::text) empreinte_stocks_historiques
FROM public.entreprises WHERE data->>'country'='republic' AND data->>'city'='capitale' AND data->>'buildingId'='hotel-republica';
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE schemaname='public' AND tablename IN('entreprises','invitations_diner','personnages_donnees','pnj_membres');
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) definition FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid WHERE NOT t.tgisinternal AND c.relnamespace='public'::regnamespace AND c.relname IN('entreprises','invitations_diner','personnages_donnees');
SELECT table_name,column_name,data_type FROM information_schema.columns WHERE table_schema='public' AND table_name IN('invitations_diner','personnages_donnees','pnj_membres') ORDER BY table_name,ordinal_position;
SELECT c.relname,con.conname,pg_get_constraintdef(con.oid) definition FROM pg_constraint con JOIN pg_class c ON c.oid=con.conrelid WHERE c.relnamespace='public'::regnamespace AND c.relname IN('invitations_diner','entreprises','recettes_commerce');
-- Les anciens actes acceptes ne prouvent PAS qu'ils n'ont jamais ete factures : pas de conversion aveugle.
SELECT statut,count(*) FROM public.invitations_diner WHERE type='diner_affaires' AND country='republic' AND city='capitale' AND building_id='hotel-republica' AND room_id='restaurant' GROUP BY statut;
ROLLBACK;
