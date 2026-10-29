-- A APPLIQUER JUSTE APRES LA FUSION DE LA PR #213 (le jeu en ligne appelle encore ces anciens
-- contrats tant que le nouvel ecran n'est pas deploye). Ferme les deux anciennes entrees sans
-- version : don d'objet a un PNJ par simple index, et don de tracts avec objet fourni par l'ecran.
-- L'ancien index seul pourrait designer un autre objet apres la perte d'une reponse.
CREATE OR REPLACE FUNCTION public.pnj_objet_transferer(p_pnj text,p_index integer,p_sens text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('ok',false,'raison','contrat_versionne_requis'); $$;
CREATE OR REPLACE FUNCTION public.tracts_donner_joueur(p_requete text,p_expediteur text,p_destinataire text,p_objet jsonb)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('ok',false,'raison','contrat_versionne_requis'); $$;
