-- PRÉPARATION NON APPLIQUÉE : rehorodatée après la coupe canonique du 31/10/2026.
-- Ancien fichier : 20261022124055_chantier_autorite_et_recus.sql ; aucun changement de règle.
-- #57 PREPAREE. Portes de commande et recu commun, aucun lancement dans le DDL.
BEGIN;
DO $g$ DECLARE h text; BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.chantier_autorite_exiger_interne(text,text,text)'); IF h IS NOT NULL AND h<>'13da73d866b2c75d44ae432a771c0b10' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_autorite_exiger_interne(text,text,text)';END IF;
END;$g$;
CREATE TABLE IF NOT EXISTS public.chantier_commandes_recus (
 personnage_id uuid NOT NULL,acteur text NOT NULL,requete text NOT NULL,terrain_id text NOT NULL,commande jsonb NOT NULL,resultat jsonb NOT NULL,cree_le timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
ALTER TABLE public.chantier_commandes_recus ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chantier_commandes_recus FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.chantier_autorite_exiger_interne(p_titulaire text,p_pays text,p_ville text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE n text:=public.mon_personnage();a record;d jsonb;
BEGIN
 IF n IS NULL THEN RAISE EXCEPTION 'acteur_non_authentifie' USING ERRCODE='42501';END IF;
 IF p_titulaire LIKE 'orga:%' THEN
  -- Reutiliser la porte de representation existante, pas la presence dans une piece.
  d:=public.organisation_equipement_exiger(substr(p_titulaire,6));
 ELSIF p_titulaire='ville:'||p_pays||':'||p_ville THEN
  SELECT * INTO a FROM public.acteur_poste_courant();
  SELECT poste INTO d FROM public.personnages_donnees WHERE name=n;
  IF a.pays IS DISTINCT FROM p_pays OR a.poste_id IS DISTINCT FROM 'maire' OR a.poste_city IS DISTINCT FROM p_ville
    OR NOT public.poste_est_atteste(n,d,p_pays) THEN RAISE EXCEPTION 'mandat_municipal_requis' USING ERRCODE='42501';END IF;
 ELSIF p_titulaire IS DISTINCT FROM n AND p_titulaire IS DISTINCT FROM 'pj:'||n THEN
  RAISE EXCEPTION 'pas_proprietaire' USING ERRCODE='42501';
 END IF;
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_autorite_exiger_interne(text,text,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
