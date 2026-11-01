-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029191802.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- MARIAGE : FERMETURE DES ÉCRITURES DIRECTES DE L'ÉCRAN (29/10/2026, Claude). NON APPLIQUÉE.
-- À appliquer APRÈS 20261029201000 ET APRÈS le déploiement de l'écran qui appelle les fonctions
-- mariage_* : avant, l'écran en ligne écrit encore ces tables lui-même et serait bloqué.
-- =====================================================================================
-- Garde en SECURITY INVOKER : current_user vaut le rôle du joueur pour une écriture directe de l'écran,
-- et le propriétaire de la fonction pour une fonction serveur SECURITY DEFINER (Helvetia, prêt
-- national, taux_imposition_fixer, mariage_*). est_appel_serveur() ne fait pas cette différence.
CREATE OR REPLACE FUNCTION public.mariage_ecriture_ecran_refuser()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN coalesce(NEW, OLD); END IF;
  RAISE EXCEPTION 'mariage_ecrit_par_le_serveur' USING ERRCODE = '42501';
END;
$function$;
DROP TRIGGER IF EXISTS mariages_ecran_refuser ON public.mariages;
CREATE TRIGGER mariages_ecran_refuser BEFORE INSERT OR UPDATE OR DELETE ON public.mariages
  FOR EACH ROW EXECUTE FUNCTION public.mariage_ecriture_ecran_refuser();
DROP TRIGGER IF EXISTS demandes_mariage_ecran_refuser ON public.demandes_mariage;
CREATE TRIGGER demandes_mariage_ecran_refuser BEFORE INSERT OR UPDATE OR DELETE ON public.demandes_mariage
  FOR EACH ROW EXECUTE FUNCTION public.mariage_ecriture_ecran_refuser();
