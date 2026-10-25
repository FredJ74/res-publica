-- Même journal public que addExternalEvent, écrit avec l'acte et son reçu, jamais au rejeu.
BEGIN;
DO $g$ DECLARE h text;d text;BEGIN
 IF to_regclass('public.evenements_globaux') IS NULL THEN RAISE EXCEPTION 'journal_public_absent';END IF;
 SELECT md5(prosrc),pg_get_functiondef(oid) INTO h,d FROM pg_proc WHERE oid=to_regprocedure('public.chantier_vol_commande(text,text,uuid)');
 IF h='f74a0fba9ee0d31a81b337f6955f0e37' THEN
  d:=replace(d,$a$social_avant integer;$a$,$b$social_avant integer;v_evenement bigint;v_texte text;$b$);
  d:=replace(d,$a$  r:=jsonb_build_object('ok',true,'succes',succes$a$,$b$  IF succes AND quantite>0 OR detecte THEN
   v_texte:=CASE WHEN detecte THEN moi||' a été pris en flagrant délit de vol de matériel sur un chantier !' ELSE 'Des matériaux ont disparu sur un chantier de la ville.' END;
   INSERT INTO public.evenements_globaux(country,city,texte,jour) VALUES(p.country,p.current_city,v_texte,jour) RETURNING id INTO v_evenement;
   IF v_evenement IS NULL OR NOT EXISTS(SELECT 1 FROM public.evenements_globaux g WHERE g.id=v_evenement AND g.country=p.country AND g.city=p.current_city AND g.texte=v_texte) THEN RAISE EXCEPTION 'evenement_vol_non_confirme';END IF;
  END IF;
  r:=jsonb_build_object('ok',true,'succes',succes$b$);
  d:=replace(d,$a$'terrain',p_terrain);$a$,$b$'terrain',p_terrain,'evenementPublic',v_evenement);$b$);
  EXECUTE d;
 ELSIF h IS DISTINCT FROM 'f3ee84eb8e78c5bbcf44d0ef78454082' THEN RAISE EXCEPTION 'definition_non_examinee: chantier_vol_commande';END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.chantier_vol_commande(text,text,uuid)') AND md5(prosrc)='f3ee84eb8e78c5bbcf44d0ef78454082') THEN RAISE EXCEPTION 'patch_evenement_vol_incomplet';END IF;
END;$g$;
COMMIT;
