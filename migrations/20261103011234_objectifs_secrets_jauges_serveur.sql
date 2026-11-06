-- Fred, 03/11/2026 : +2 INF PAR LOT nouveau, nouvelles éligibilités seulement.
-- Aucune jauge historique n'est modifiée par l'installation. Seul l'état de
-- suivi est initialisé, une fois ; rejouer la migration ne réinitialise rien.
-- Refuser une installation partielle : ne jamais recréer silencieusement la
-- mémoire des récompenses ou la marque de bascule. Empreintes du code préparé.
DO $prevol_objectifs$
DECLARE n integer;
BEGIN
 n:=(to_regclass('public.jauges_objectifs_etats')IS NOT NULL)::int
   +(to_regclass('public.jauges_objectifs_bascule')IS NOT NULL)::int
   +(to_regprocedure('public.objectifs_secrets_eligibles_interne(text)')IS NOT NULL)::int
   +(to_regprocedure('public.objectifs_secrets_actualiser_interne(text)')IS NOT NULL)::int;
 IF n NOT IN(0,4)THEN RAISE EXCEPTION 'objectifs_installation_partielle';END IF;
 IF n=4 THEN
  IF (SELECT count(*)FROM public.jauges_objectifs_bascule WHERE seule IS TRUE)<>1 THEN
   RAISE EXCEPTION 'objectifs_bascule_absente';END IF;
  IF EXISTS(SELECT 1 FROM pg_class c WHERE c.oid IN('public.jauges_objectifs_etats'::regclass,'public.jauges_objectifs_bascule'::regclass)AND NOT c.relrowsecurity)
   OR EXISTS(SELECT 1 FROM pg_policy WHERE polrelid IN('public.jauges_objectifs_etats'::regclass,'public.jauges_objectifs_bascule'::regclass))THEN
   RAISE EXCEPTION 'objectifs_autorite_a_reexaminer';END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.objectifs_secrets_eligibles_interne(text)')) IS DISTINCT FROM '19214ebbe9c8366907ddd155140c3915' THEN RAISE EXCEPTION 'objectifs_definition_a_reexaminer'; END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=to_regprocedure('public.objectifs_secrets_actualiser_interne(text)')) IS DISTINCT FROM 'db6242eb2c011c2dd26eb280032b4cc4' THEN RAISE EXCEPTION 'objectifs_definition_a_reexaminer'; END IF;
 END IF;
END;$prevol_objectifs$;
CREATE TABLE IF NOT EXISTS public.jauges_objectifs_etats (
 acteur text PRIMARY KEY, acquis text[] NOT NULL DEFAULT '{}', maj_le timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.jauges_objectifs_bascule (
 seule boolean PRIMARY KEY DEFAULT true CHECK(seule), instant timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.jauges_objectifs_etats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jauges_objectifs_bascule ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.objectifs_secrets_eligibles_interne(p_acteur text)
RETURNS text[] LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public,pg_temp
AS $function$
 SELECT array_remove(ARRAY[
 CASE WHEN a.archetype='ambitieux'AND a.poste->>'id'='president' THEN 'obj_president'END,
 CASE WHEN a.archetype='ambitieux'AND coalesce((a.resources->>'inf')::numeric,0)>=80 THEN 'obj_inf80'END,
 CASE WHEN a.archetype='ambitieux'AND a.poste->>'id'NOT IN('citoyen','depute')THEN 'obj_poste_haut'END,
 CASE WHEN a.archetype='ambitieux'AND coalesce(a.banque,0)>=50000 THEN 'obj_argent_50k'END,
 CASE WHEN a.archetype='criminel'AND coalesce((a.resources->>'dis')::numeric,0)>=90 THEN 'obj_dis90'END,
 CASE WHEN a.archetype='criminel'AND CASE WHEN jsonb_typeof(a.informateurs)='array'THEN jsonb_array_length(a.informateurs)ELSE 0 END>=2 THEN 'obj_informateur'END,
 CASE WHEN a.archetype='militaire'AND a.poste->>'id'IN('min_def','ministre_defense')THEN 'obj_ministre_def'END,
 CASE WHEN a.archetype='religieux'AND coalesce((a.resources->>'pop')::numeric,0)>=80 THEN 'obj_pop80'END
 ],NULL)FROM public.personnages_donnees a WHERE a.name=p_acteur
$function$;
-- Les autres critères du catalogue d'écran reposent sur des compteurs jamais
-- écrits ni persistés (audit #379). Aucun nombre fourni par l'écran n'est une
-- preuve ; leurs intitulés restent présents, aucun nouveau bonus n'est inventé.
REVOKE ALL ON FUNCTION public.objectifs_secrets_eligibles_interne(text)FROM PUBLIC,anon,authenticated,service_role;
DO $bascule$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('jauges_objectifs_bascule_379',0));
 IF NOT EXISTS(SELECT 1 FROM public.jauges_objectifs_bascule)THEN
  LOCK TABLE public.personnages_donnees IN SHARE ROW EXCLUSIVE MODE;
  INSERT INTO public.jauges_objectifs_bascule(seule)VALUES(true);
  INSERT INTO public.jauges_objectifs_etats(acteur,acquis)
   SELECT name,coalesce(public.objectifs_secrets_eligibles_interne(name),'{}'::text[])FROM public.personnages_donnees
   ON CONFLICT(acteur)DO NOTHING;
 END IF;
END;$bascule$;
CREATE OR REPLACE FUNCTION public.objectifs_secrets_actualiser_interne(p_acteur text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp
AS $function$
DECLARE eligibles text[]; deja text[]; nouvelles text[]; toutes text[];
BEGIN
 IF p_acteur IS DISTINCT FROM public.mon_personnage()THEN
  RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=p_acteur FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable');END IF;
 INSERT INTO public.jauges_objectifs_etats(acteur)VALUES(p_acteur)ON CONFLICT(acteur)DO NOTHING;
 SELECT acquis INTO deja FROM public.jauges_objectifs_etats WHERE acteur=p_acteur FOR UPDATE;
 eligibles:=coalesce(public.objectifs_secrets_eligibles_interne(p_acteur),'{}'::text[]);
 SELECT coalesce(array_agg(x ORDER BY x),'{}'::text[])INTO nouvelles FROM unnest(eligibles)x WHERE NOT(x=ANY(deja));
 SELECT coalesce(array_agg(DISTINCT x ORDER BY x),'{}'::text[])INTO toutes FROM unnest(deja||nouvelles)x;
 UPDATE public.jauges_objectifs_etats SET acquis=toutes,maj_le=now()WHERE acteur=p_acteur;
 RETURN jsonb_build_object('ok',true,'objectifs_completes',toutes,'objectifs_nouveaux',nouvelles,
   'gain_inf',CASE WHEN cardinality(nouvelles)>0 THEN 2 ELSE 0 END);
END;$function$;
REVOKE ALL ON FUNCTION public.objectifs_secrets_actualiser_interne(text)FROM PUBLIC,anon,authenticated,service_role;
