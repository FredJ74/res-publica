-- La mécanique soviarkienne ne doit jamais hériter d'un transfert QHS
-- républicain : un transfert vers le goulag doit venir de la sentence
-- atomique du juge de Sovarka, même lorsqu'un appel direct à une ancienne
-- fonction de prolongation de peine est tenté.
DO $goulag_admission$
DECLARE source text; ancre text; garde text;
BEGIN
 source := pg_get_functiondef('public.detention_qhs_poser_interne(text,text,text)'::regprocedure);
 IF strpos(source,'goulag_admission_juge_20261116')>0 THEN RETURN; END IF;
 ancre := E'  IF NOT FOUND THEN RETURN; END IF;';
 garde := ancre
   || E'\n  -- goulag_admission_juge_20261116 : Sovarka uniquement, Républia inchangée.\n'
   || E'  IF v_det.country = ''soviet'' AND\n'
   || E'    (NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration c\n'
   || E'      WHERE c.singleton AND c.active)\n'
   || E'     OR (current_setting(''rp.goulag_jugement_interne'',true) IS DISTINCT FROM ''valide''\n'
   || E'       AND NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_traversees t\n'
   || E'         JOIN public.detentions d ON d.id=t.detention_id\n'
   || E'         WHERE t.nom=p_nom AND t.nouvelle_detention_id=p_detention_id\n'
   || E'           AND t.peine_reprise_le IS NOT NULL AND d.qhs AND d.country=''soviet''))) THEN\n'
   || E'    RAISE EXCEPTION ''goulag_transfert_hors_jugement''; END IF;';
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN
  RAISE EXCEPTION 'detention_qhs_poser_interne_ancre_absente';END IF;
 EXECUTE replace(source,ancre,garde);
END $goulag_admission$;

-- Fred, commentaire 6924174456 : 30 % par entrée EFFECTIVE, jamais par clic.
-- Le verrou de la ligne personnage sérialise les entrées concurrentes ; une
-- répétition de position ne passe pas le WHEN du déclencheur.
CREATE TABLE IF NOT EXISTS public.sovarka_goulag_entrees (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 nom text NOT NULL REFERENCES public.personnages_donnees(name),
 pays text NOT NULL CHECK(pays='soviet'),ville text NOT NULL,batiment text NOT NULL,
 taux integer NOT NULL DEFAULT 30 CHECK(taux=30),arrete boolean NOT NULL,
 transaction_id bigint NOT NULL DEFAULT txid_current(),creee_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sovarka_goulag_entrees ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sovarka_goulag_entrees FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX IF NOT EXISTS sovarka_goulag_entrees_transaction ON public.sovarka_goulag_entrees(nom,transaction_id);

CREATE OR REPLACE FUNCTION public.sovarka_goulag_controler_entree()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_t public.sovarka_goulag_traversees%ROWTYPE; v_jet boolean; v_ecrou jsonb; v_depot jsonb;
BEGIN
 IF NEW.country IS DISTINCT FROM 'soviet' OR NEW.current_building IS NULL
  OR NEW.current_building NOT IN ('hotel-republica','hotel-mineur','dispensaire-public','dispensaire-public-v','clinique-privee')
  OR NOT EXISTS(SELECT 1 FROM public.sovarka_goulag_configuration WHERE singleton AND active) THEN RETURN NEW; END IF;
 SELECT * INTO v_t FROM public.sovarka_goulag_traversees WHERE nom=NEW.name
  AND statut='detenu' AND NOT en_cours AND peine_gelee_secondes>0 AND peine_reprise_le IS NULL FOR UPDATE;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM public.detention_active(NEW.name)) THEN RETURN NEW; END IF;
 v_jet:=random()<0.30;
 INSERT INTO public.sovarka_goulag_entrees(nom,pays,ville,batiment,arrete)
  VALUES(NEW.name,NEW.country,NEW.current_city,NEW.current_building,v_jet);
 IF NOT v_jet THEN RETURN NEW; END IF;
 -- Zéro jour supplémentaire : seul le reliquat judiciaire sera repris par le moteur.
 v_ecrou:=public.detention_ouvrir_interne(NEW.name,'Reprise de la peine du goulag',0,
  NEW.current_city,'soviet','[]'::jsonb,'Commissariat','reincarceration');
 IF coalesce((v_ecrou->>'ok')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'goulag_reincarceration_impossible'; END IF;
 -- Réexécution de la décision judiciaire initiale, aucune nouvelle condamnation.
 PERFORM public.detention_qhs_poser_interne(NEW.name,v_ecrou->>'detention_id','Reprise de la peine du goulag');
 v_depot:=public.sovarka_goulag_confisquer_interne(NEW.name,v_ecrou->>'detention_id');
 IF coalesce((v_depot->>'ok')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'goulag_depot_reincarceration_impossible'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.sovarka_goulag_controler_entree() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS goulag_entree_effective ON public.personnages_donnees;
CREATE TRIGGER goulag_entree_effective AFTER UPDATE OF country,current_city,current_building ON public.personnages_donnees
 FOR EACH ROW WHEN ((OLD.country,OLD.current_city,OLD.current_building) IS DISTINCT FROM
 (NEW.country,NEW.current_city,NEW.current_building)) EXECUTE FUNCTION public.sovarka_goulag_controler_entree();

-- Joindre le verdict d'arrestation à la navigation publique, afin que l'écran
-- relise la cellule réelle au lieu d'afficher l'hôtel demandé.
DO $navigation_arrestation$
DECLARE source text;ancre text;ajout text;
BEGIN
 source:=pg_get_functiondef('public.navigation_interieure(text,text)'::regprocedure);
 IF strpos(source,'goulag_navigation_arrestation_20261117')>0 THEN RETURN; END IF;
 ancre:=E'  RETURN v;';
 ajout:=E'  -- goulag_navigation_arrestation_20261117\n'
  ||E'  IF coalesce((v->>''ok'')::boolean,false) AND EXISTS(SELECT 1 FROM public.sovarka_goulag_entrees\n'
  ||E'    WHERE nom=v_moi AND transaction_id=txid_current() AND arrete) THEN\n'
  ||E'   v:=v||jsonb_build_object(''goulag_arrestation'',jsonb_build_object(''ok'',true,''arrete'',true)); END IF;\n'||ancre;
 IF (length(source)-length(replace(source,ancre,'')))<>length(ancre) THEN RAISE EXCEPTION 'navigation_goulag_ancre_absente'; END IF;
 EXECUTE replace(source,ancre,ajout);
END $navigation_arrestation$;
