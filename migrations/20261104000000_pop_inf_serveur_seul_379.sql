-- #379, fermeture (Claude, 03/11/2026) : POP et INF ne viennent plus jamais de la sauvegarde
-- générale du navigateur. Tous les producteurs actifs sont des commandes serveur (lots grâce,
-- inspection, présidence, 2 et 3) ; l'écran adopte leurs valeurs (adopterJaugeServeur).
-- Une sauvegarde générale (PATCH hors /rpc/) garde donc la POP et l'INF ENREGISTRÉES : la
-- variation proposée par le navigateur est ignorée, le reste de la sauvegarde passe. On ne
-- refuse pas la sauvegarde entière (préparatif de ChatGPT) : un ancien onglet resté ouvert après
-- le déploiement perdrait sinon ses autres champs (position, PA…) à chaque enregistrement.
-- Les commandes serveur (rôle serveur ou chemin /rpc/) écrivent leurs jauges comme avant.
-- Remplace 20261103183000 (garde de base périmée), dont le cas est absorbé : aucune base
-- client n'est plus jamais appliquée. Préparatif outils/livraison/preparatifs-379/ caduc.

DO $prevol$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='public.personnages_fusionner_pop()'::regprocedure AND prosecdef
     AND (md5(prosrc)='ccfcb6d1bdc4358058ab415bfab3172e' OR position('hg379_serveur_seul_v1' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_serveur_seul_prevol_definition_divergente'; END IF;
END $prevol$;

CREATE OR REPLACE FUNCTION public.personnages_fusionner_pop()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public,pg_temp
AS $f$
DECLARE
  -- hg379_serveur_seul_v1
  v_client boolean := NOT public.est_appel_serveur()
    AND coalesce(current_setting('request.path', true),'') NOT LIKE '/rpc/%';
BEGIN
  IF jsonb_typeof(NEW.resources) IS DISTINCT FROM 'object' THEN RETURN NEW; END IF;
  -- Les bases de l'ancien protocole de variation ne sont jamais stockées.
  NEW.resources := NEW.resources - 'popBase' - 'infBase';
  IF TG_OP = 'UPDATE' AND v_client THEN
    IF jsonb_typeof(OLD.resources -> 'pop') = 'number'
      THEN NEW.resources := jsonb_set(NEW.resources, '{pop}', OLD.resources -> 'pop');
      ELSE NEW.resources := NEW.resources - 'pop'; END IF;
    IF jsonb_typeof(OLD.resources -> 'inf') = 'number'
      THEN NEW.resources := jsonb_set(NEW.resources, '{inf}', OLD.resources -> 'inf');
      ELSE NEW.resources := NEW.resources - 'inf'; END IF;
  END IF;
  RETURN NEW;
END $f$;
NOTIFY pgrst,'reload schema';
