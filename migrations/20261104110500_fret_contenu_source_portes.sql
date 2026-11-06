-- #433 (suite de 20261104105114) : le garde du contenu des caisses de fret reconnaît les deux
-- nouvelles portes serveur (déclaration des lots à la fermeture, saisie à l'inspection).
CREATE OR REPLACE FUNCTION public.fret_contenu_source_garder()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
 IF NOT public.est_appel_serveur() AND coalesce(current_setting('request.path',true),'') NOT IN ('/rpc/fret_objet_agir', '/rpc/trading_acheter', '/rpc/offre_achat_servir', '/rpc/fret_caisse_commande', '/rpc/douane_caisse_controler') THEN
  IF TG_OP='INSERT' THEN RAISE EXCEPTION 'fret: depot serveur requis' USING ERRCODE='42501'; END IF;
  IF (to_jsonb(NEW)-'quantite') IS DISTINCT FROM (to_jsonb(OLD)-'quantite') OR NEW.quantite IS NULL OR NEW.quantite<0 OR NEW.quantite>OLD.quantite THEN
   RAISE EXCEPTION 'fret: contenu forge refuse' USING ERRCODE='42501'; END IF;
 END IF;
 RETURN NEW;
END; $function$;
