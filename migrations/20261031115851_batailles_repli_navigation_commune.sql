-- #219 PRÉPARÉE, non appliquée. Dépend des compléments jusqu'à 223600.
-- Le repli existant ne comportait aucun jet : ne pas en inventer un ici.
-- Une seule implémentation de navigation ; identité explicite réservée au serveur.
DO $navigation$
DECLARE s text;a text;
BEGIN
 IF to_regprocedure('public.navigation_commander_personnage_interne(text,text,text,text)') IS NOT NULL THEN RETURN;END IF;
 SELECT prosrc INTO s FROM pg_proc WHERE oid='public.navigation_commander_interne(text,text,text)'::regprocedure;
 a:='moi:=public.mon_personnage();';
 IF (length(s)-length(replace(s,a,'')))/length(a)<>1 THEN RAISE EXCEPTION 'navigation_identite_non_examinee';END IF;
 s:=replace(s,a,'moi:=p_nom;');
 EXECUTE format('CREATE FUNCTION public.navigation_commander_personnage_interne(p_nom text,p_mode text,p_destination text,p_piece text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS %L',s);
END $navigation$;
REVOKE ALL ON FUNCTION public.navigation_commander_personnage_interne(text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.navigation_commander_interne(p_mode text,p_destination text,p_piece text)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
 SELECT public.navigation_commander_personnage_interne(public.mon_personnage(),p_mode,p_destination,p_piece);
$g$;
REVOKE ALL ON FUNCTION public.navigation_commander_interne(text,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.militaire_bataille_decrocher_groupe(p_bataille_id bigint,p_groupe_id text,p_round integer)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $g$
DECLARE b public.batailles%ROWTYPE;g public.batailles_groupes%ROWTYPE;v jsonb;ids text[];pnjs text[];n integer;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('groupe_pj:graphe',0));
 SELECT * INTO b FROM public.batailles WHERE id=p_bataille_id FOR UPDATE;
 IF NOT FOUND OR b.statut<>'en_cours' THEN RETURN 0;END IF;
 SELECT * INTO g FROM public.batailles_groupes WHERE bataille_id=p_bataille_id AND groupe_id=p_groupe_id AND sorti_round IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN 0;END IF;
 IF g.leader IS NULL THEN
  -- Pas de faux PJ utilisé comme conducteur d'une unité autonome.
  RAISE EXCEPTION 'repli_PNJ_autonome_non_raccorde' USING ERRCODE='P2194',DETAIL='{"ok":false,"raison":"repli_PNJ_autonome_non_raccorde"}';END IF;
 v:=public.navigation_destination_fuite_interne(g.leader);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'repli_destination_refusee' USING ERRCODE='P2194',DETAIL=v::text;END IF;
 SELECT coalesce(array_agg(personnage) FILTER(WHERE personnage IS NOT NULL),'{}'::text[]),
 coalesce(array_agg(pnj_id) FILTER(WHERE pnj_id IS NOT NULL),'{}'::text[]),count(*)
 INTO ids,pnjs,n FROM public.batailles_engagements WHERE bataille_id=p_bataille_id AND groupe_id=p_groupe_id AND sorti_round IS NULL;
 -- Aucun engagé ne peut être laissé fictivement dans le combat ou téléporté
 -- hors d'un autre groupe. La composition canonique, pas le camp, fait autorité.
 IF EXISTS(SELECT 1 FROM unnest(ids) ident WHERE NOT EXISTS(SELECT 1 FROM public.groupe_participants_interne(g.leader) p WHERE p.est_pj AND p.identifiant=ident))
 OR EXISTS(SELECT 1 FROM unnest(pnjs) ident WHERE NOT EXISTS(SELECT 1 FROM public.groupe_participants_interne(g.leader) p WHERE NOT p.est_pj AND p.identifiant=ident)) THEN
  RAISE EXCEPTION 'repli_composition_modifiee' USING ERRCODE='P2194',DETAIL='{"ok":false,"raison":"composition_modifiee"}';END IF;
 -- La sortie de cet engagement et le déplacement appartiennent à la même
 -- transaction. Les autres combats, prisons, interceptions et incapacités restent gardés.
 UPDATE public.batailles_engagements SET sorti_round=p_round,etat_final='replie'
 WHERE bataille_id=p_bataille_id AND groupe_id=p_groupe_id AND sorti_round IS NULL;
 UPDATE public.batailles_groupes SET sorti_round=p_round,attente_depuis=NULL WHERE bataille_id=p_bataille_id AND groupe_id=p_groupe_id;
 v:=public.navigation_commander_personnage_interne(g.leader,'rue',v->>'destination',NULL);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'repli_mouvement_refuse' USING ERRCODE='P2194',DETAIL=v::text;END IF;
 RETURN n;
END $g$;
REVOKE ALL ON FUNCTION public.militaire_bataille_decrocher_groupe(bigint,text,integer) FROM PUBLIC,anon,authenticated,service_role;
