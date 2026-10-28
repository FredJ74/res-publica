-- Groupe PJ persistant : adhésion volontaire et autorité indépendante.
-- L'appartenance n'accorde aucun droit d'administration sur les PNJ.
CREATE TABLE IF NOT EXISTS public.groupes_pj_adhesions (
 membre text PRIMARY KEY REFERENCES public.personnages_donnees(name) ON DELETE CASCADE,
 chef text NOT NULL REFERENCES public.personnages_donnees(name) ON DELETE CASCADE,
 cree_le timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT groupes_pj_pas_auto_adhesion CHECK (membre <> chef)
);
CREATE INDEX IF NOT EXISTS groupes_pj_adhesions_chef_idx ON public.groupes_pj_adhesions(chef);
ALTER TABLE public.groupes_pj_adhesions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.groupes_pj_adhesions FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.groupe_pj_rejoindre(p_chef text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text; a record; b record;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 IF p_chef IS NULL OR p_chef=moi THEN
   RETURN jsonb_build_object('ok',false,'raison','chef_invalide'); END IF;
 -- Le demandeur rejoint lui-même, aucun chef ne peut l'y contraindre.
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:'||least(moi,p_chef),0));
 SELECT country,current_city,current_building,current_room,current_street
 INTO a FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 SELECT country,current_city,current_building,current_room,current_street
 INTO b FROM public.personnages_donnees WHERE name=p_chef FOR UPDATE;
 IF a.current_city IS NULL OR b.current_city IS NULL
    OR a.country IS DISTINCT FROM b.country OR a.current_city IS DISTINCT FROM b.current_city
    OR a.current_building IS DISTINCT FROM b.current_building
    OR a.current_room IS DISTINCT FROM b.current_room
    OR a.current_street IS DISTINCT FROM b.current_street THEN
   RETURN jsonb_build_object('ok',false,'raison','pas_co_presents'); END IF;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE membre=p_chef) THEN
   RETURN jsonb_build_object('ok',false,'raison','chef_deja_membre'); END IF;
 IF EXISTS(SELECT 1 FROM public.groupes_pj_adhesions WHERE chef=moi) THEN
   RETURN jsonb_build_object('ok',false,'raison','chef_de_groupe'); END IF;
 INSERT INTO public.groupes_pj_adhesions(membre,chef) VALUES(moi,p_chef)
 ON CONFLICT(membre) DO UPDATE SET chef=excluded.chef,cree_le=now();
 RETURN jsonb_build_object('ok',true,'chef',p_chef);
END $g$;
CREATE OR REPLACE FUNCTION public.groupe_pj_quitter()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 DELETE FROM public.groupes_pj_adhesions WHERE membre=moi;
 RETURN jsonb_build_object('ok',true);
END $g$;
CREATE OR REPLACE FUNCTION public.groupe_pj_lire()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp' AS $g$
DECLARE moi text; chef_courant text;
BEGIN
 moi:=public.mon_personnage();
 IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','non_authentifie'); END IF;
 SELECT chef INTO chef_courant FROM public.groupes_pj_adhesions WHERE membre=moi;
 chef_courant:=coalesce(chef_courant,moi);
 RETURN jsonb_build_object('ok',true,'chef',chef_courant,'membres',
    (SELECT coalesce(jsonb_agg(membre ORDER BY membre),'[]'::jsonb) FROM (
      SELECT chef_courant AS membre UNION ALL
      SELECT membre FROM public.groupes_pj_adhesions WHERE chef=chef_courant
    ) t));
END $g$;
REVOKE ALL ON FUNCTION public.groupe_pj_rejoindre(text) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.groupe_pj_quitter() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.groupe_pj_lire() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.groupe_pj_rejoindre(text), public.groupe_pj_quitter(), public.groupe_pj_lire() TO authenticated;
