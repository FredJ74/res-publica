-- PR56 — PREPAREE, NON APPLIQUEE. Meme canal d'impacts, effets dans la transaction.
-- Ne pas deployer sans catalogue vivant, tests de soins/deplacements et validation.
-- Aucun rattrapage ni UPDATE de donnees existantes pendant cette migration.
BEGIN;
DO $g$ DECLARE h text; BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.impact_realite_appliquer(text)');
IF h IS NOT NULL AND h NOT IN ('3aa290bda8396f11a3a6fa8adbe0a27b') THEN RAISE EXCEPTION 'definition_non_examinee: impact_realite_appliquer'; END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.impact_deposer(text,text,text,integer,text)');
IF h IS NOT NULL AND h NOT IN ('961680528d08b457122bb5bff6eb89f9','fdfddb29ee218e8c0fa0fb042cc72cc4') THEN RAISE EXCEPTION 'definition_non_examinee: impact_deposer'; END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.personnages_preserver_impact_serveur()');
IF h IS NOT NULL AND h NOT IN ('93fc776868c89a3b6edffa4e261887dd') THEN RAISE EXCEPTION 'definition_non_examinee: personnages_preserver_impact_serveur'; END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.impacts_realites_synchroniser()');
IF h IS NOT NULL AND h NOT IN ('e6bd5d666397572e11a27a29a92c55a1') THEN RAISE EXCEPTION 'definition_non_examinee: impacts_realites_synchroniser'; END IF;
END;$g$;
ALTER TABLE public.impacts_indices_attente ADD COLUMN IF NOT EXISTS auteur text, ADD COLUMN IF NOT EXISTS applique_serveur boolean NOT NULL DEFAULT false, ADD COLUMN IF NOT EXISTS applique_le timestamptz, ADD COLUMN IF NOT EXISTS resultat jsonb;
CREATE OR REPLACE FUNCTION public.impact_realite_appliquer(p_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE i public.impacts_indices_attente%rowtype; c public.personnages_donnees%rowtype;
 j date:=(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date;
 lieu text; duree integer; affaiblies jsonb; entree jsonb; gain integer:=0;
BEGIN
 SELECT * INTO i FROM public.impacts_indices_attente WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR i.applique_serveur THEN RETURN; END IF;
 SELECT * INTO STRICT c FROM public.personnages_donnees WHERE name=i.victime FOR UPDATE;
 IF i.indice='hp_set' THEN
   lieu:=CASE WHEN c.poste->>'id' IN ('president','pm','min_int','min_fin','min_just','min_def','min_info','min_ae') THEN 'clinique' ELSE 'dispensaire' END;
   duree:=CASE i.palier WHEN 'totale' THEN 3 WHEN 'partielle' THEN 2 ELSE 1 END;
   IF lieu='dispensaire' THEN duree:=duree*2; END IF;
   SELECT coalesce(jsonb_object_agg(stat,true),'{}'::jsonb) INTO affaiblies
     FROM (SELECT stat FROM unnest(ARRAY['INT','CHA','VOL','PER','DUP','ENT']) AS t(stat) ORDER BY random() LIMIT 2) choix;
   entree:=jsonb_build_object('text','Vous avez été victime d’une agression. Vos PV sont tombés à '||i.delta||'.',
     'cls','event-bad','ts',statement_timestamp(),'impactId',i.id);
   UPDATE public.personnages_donnees SET hp=i.delta,pa=0,regen_jour=day,
     stats_affaiblies=coalesce(stats_affaiblies,'{}'::jsonb)||affaiblies,
     hospitalisation=jsonb_build_object('palier',coalesce(i.palier,'partielle'),'lieu',lieu,
       'dateDebutParis',j,'dateFinParis',j+duree,'impactId',i.id),
     journal=(SELECT coalesce(jsonb_agg(e ORDER BY n),'[]'::jsonb) FROM jsonb_array_elements(jsonb_build_array(entree)||coalesce(journal,'[]'::jsonb)) WITH ORDINALITY AS t(e,n) WHERE n<=500),
     updated_at=clock_timestamp() WHERE name=c.name;
 ELSIF i.indice='moral_carte_postale' THEN
   IF c.carte_postale_moral_jour->>'expediteur' IS DISTINCT FROM j::text THEN
     gain:=10;
     entree:=jsonb_build_object('text','Une carte postale que vous avez envoyée a été lue. +10 Moral.',
       'cls','event-good','ts',statement_timestamp(),'impactId',i.id);
     UPDATE public.personnages_donnees SET moral=least(100,greatest(0,coalesce(moral,0)+gain)),
       carte_postale_moral_jour=coalesce(carte_postale_moral_jour,'{}'::jsonb)||jsonb_build_object('expediteur',j::text),
       journal=(SELECT coalesce(jsonb_agg(e ORDER BY n),'[]'::jsonb) FROM jsonb_array_elements(jsonb_build_array(entree)||coalesce(journal,'[]'::jsonb)) WITH ORDINALITY AS t(e,n) WHERE n<=500),
       updated_at=clock_timestamp() WHERE name=c.name;
   END IF;
 ELSE
   RAISE EXCEPTION 'indice_non_pris_en_charge' USING ERRCODE='22023';
 END IF;
 UPDATE public.impacts_indices_attente SET applique_serveur=true,applique_le=clock_timestamp(),
   resultat=jsonb_build_object('indice',i.indice,'delta',i.delta,'gain_moral',gain)
   WHERE id=i.id;
END;
$function$;
REVOKE ALL ON FUNCTION public.impact_realite_appliquer(text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.impact_deposer(p_id text, p_victime text, p_indice text, p_delta integer, p_palier text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_moi text; a record; c record; v_delta integer; v_existant public.impacts_indices_attente%rowtype; v_insere text; v_ancien text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF coalesce(btrim(coalesce(p_id,'')),'') = '' OR length(p_id) > 120 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'identifiant_invalide');
  END IF;

  PERFORM 1 FROM public.personnages_donnees
    WHERE name IN (v_moi,btrim(coalesce(p_victime,''))) ORDER BY name FOR UPDATE;
  SELECT country, current_city, current_building, current_room, hp, hospitalisation INTO a
    FROM public.personnages_donnees WHERE name = v_moi;
  SELECT name, country, current_city, current_building, current_room INTO c
    FROM public.personnages_donnees WHERE name = btrim(coalesce(p_victime,''));
  IF c.name IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'victime_introuvable'); END IF;
  IF c.name = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'auto_impact_refuse'); END IF;

  v_delta:=CASE WHEN p_indice='moral_carte_postale' THEN 10 ELSE greatest(0,least(100,coalesce(p_delta,0))) END;
  -- Meme canal et meme cle. Un retry ne rejoue ni effets, ni tirage, ni journal.
  SELECT * INTO v_existant FROM public.impacts_indices_attente WHERE id=p_id;
  IF FOUND THEN
    IF v_existant.auteur IS DISTINCT FROM v_moi OR v_existant.victime IS DISTINCT FROM c.name
      OR v_existant.indice IS DISTINCT FROM p_indice OR v_existant.delta IS DISTINCT FROM v_delta
      OR v_existant.palier IS DISTINCT FROM nullif(btrim(coalesce(p_palier,'')),'') THEN
      RETURN jsonb_build_object('ok',false,'raison','identifiant_deja_utilise');
    END IF;
    RETURN jsonb_build_object('ok',true,'id',p_id,'victime',c.name,'indice',p_indice,
      'delta',v_delta,'applique_serveur',v_existant.applique_serveur,'rejeu',true);
  END IF;
  IF p_indice = 'hp_set' THEN
    IF coalesce(a.hp,100)<=0 OR coalesce(a.hospitalisation->>'dateFinParis','') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN RETURN jsonb_build_object('ok',false,'raison','acteur_incapacite'); END IF;
    -- LA CO-PRESENCE EST LA GARDE ESSENTIELLE. Elle ne remplace pas un jet serveur, mais elle
    -- supprime a elle seule l'attaque a distance sur une victime quelconque, qui etait le vrai
    -- danger : frapper sans etre la, sans arme et sans PA.
    IF a.country IS DISTINCT FROM c.country
       OR a.current_city IS DISTINCT FROM c.current_city
       OR a.current_building IS DISTINCT FROM c.current_building
       OR a.current_room IS DISTINCT FROM c.current_room THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_au_meme_endroit');
    END IF;
    v_delta := greatest(0, least(100, coalesce(p_delta, 0)));

  ELSIF p_indice = 'moral_carte_postale' THEN
    -- Une carte postale est distante par nature : aucune co-presence exigee. Le montant n'est pas
    -- negociable et le plafond quotidien reste pose cote lecteur, la ou il l'a toujours ete.
    v_delta := 10;

  ELSIF p_indice = 'poison_start' THEN
    -- REFUS EXPLICITE, ET C'EST UN CONSTAT, PAS UNE DECISION. Le producteur envoie `poisonType` et
    -- `statsTouchees`, DEUX COLONNES QUI N'EXISTENT PAS dans cette table, et omet `delta` qui est
    -- NOT NULL sans defaut. Cet INSERT a donc toujours ete rejete par PostgREST, silencieusement
    -- (sbInsert journalise et rend null, l'appelant avale le null) : l'empoisonnement n'a jamais
    -- atteint sa victime. On refuse desormais VISIBLEMENT au lieu d'echouer en silence. Reparer
    -- l'empoisonnement est un lot a part : il demande un schema, pas un correctif de canal.
    RETURN jsonb_build_object('ok', false, 'raison', 'schema_incomplet',
      'detail', 'poison_start exige des colonnes absentes de la table');

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'indice_non_autorise', 'indice', p_indice);
  END IF;

  INSERT INTO public.impacts_indices_attente(id,victime,indice,delta,palier,traite,auteur)
    VALUES(p_id,c.name,p_indice,v_delta,nullif(btrim(coalesce(p_palier,'')),''),false,v_moi)
    ON CONFLICT(id) DO NOTHING RETURNING id INTO v_insere;
  IF v_insere IS NULL THEN
    -- Deux couples d'acteurs peuvent utiliser le meme id : pas de faux succes.
    RETURN jsonb_build_object('ok',false,'raison','identifiant_deja_utilise');
  END IF;
  -- Les effets anterieurs ne doivent jamais remplacer ce nouvel impact plus tard.
  FOR v_ancien IN SELECT id FROM public.impacts_indices_attente
    WHERE victime=c.name AND NOT applique_serveur AND NOT traite AND id<>p_id
      AND indice IN ('hp_set','moral_carte_postale') ORDER BY created_at,id
  LOOP PERFORM public.impact_realite_appliquer(v_ancien); END LOOP;
  PERFORM public.impact_realite_appliquer(p_id);
  RETURN jsonb_build_object('ok',true,'id',p_id,'victime',c.name,'indice',p_indice,
    'delta',v_delta,'applique_serveur',true,'rejeu',false);
END;
$function$;
-- Une ancienne fiche ne peut effacer une convalescence serveur encore active.
-- Les soins historiques conservant l'impactId, le transfert et la fin civile restent possibles.
CREATE OR REPLACE FUNCTION public.personnages_preserver_impact_serveur()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE precedent text:=OLD.hospitalisation->>'impactId'; suivant text:=NEW.hospitalisation->>'impactId';
BEGIN
 IF auth.role()='authenticated' AND precedent IS NOT NULL AND suivant IS DISTINCT FROM precedent
   AND coalesce(OLD.hospitalisation->>'dateFinParis','9999-12-31') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN
   -- Une nouvelle agression dans CETTE transaction peut remplacer la precedente.
   IF suivant IS NULL OR NOT EXISTS(SELECT 1 FROM public.impacts_indices_attente i
     WHERE i.id=suivant AND i.victime=OLD.name AND i.indice='hp_set' AND NOT i.applique_serveur) THEN
     RAISE EXCEPTION 'realite_medicale_obsolete' USING ERRCODE='40001';
   END IF;
 END IF;
 IF auth.role()='authenticated' AND public.mon_personnage()=OLD.name AND precedent IS NOT NULL
   AND coalesce(OLD.hospitalisation->>'dateFinParis','9999-12-31') > (statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text
   AND (NEW.country,NEW.current_city,NEW.current_building,NEW.current_room)
       IS DISTINCT FROM (OLD.country,OLD.current_city,OLD.current_building,OLD.current_room) THEN
   IF NEW.country IS DISTINCT FROM OLD.country OR NOT coalesce((
       (NEW.current_city=OLD.current_city AND NEW.current_building IN ('dispensaire-public','dispensaire-public-v')
         AND NEW.hospitalisation->>'lieu'='dispensaire')
       OR (NEW.current_building='clinique-privee' AND NEW.current_city IN (OLD.current_city,'capitale')
         AND NEW.hospitalisation->>'lieu'='clinique')),false) THEN
     RAISE EXCEPTION 'acteur_incapacite' USING ERRCODE='42501';
   END IF;
 END IF;
 RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.personnages_preserver_impact_serveur() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS zzzz_preserver_impact_serveur ON public.personnages_donnees;
CREATE TRIGGER zzzz_preserver_impact_serveur BEFORE UPDATE ON public.personnages_donnees
 FOR EACH ROW EXECUTE FUNCTION public.personnages_preserver_impact_serveur();

CREATE OR REPLACE FUNCTION public.impacts_realites_synchroniser()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
DECLARE nom text:=public.mon_personnage(); ancien text;
BEGIN
 IF nom IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=nom FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','personnage_introuvable'); END IF;
 FOR ancien IN SELECT id FROM public.impacts_indices_attente
   WHERE victime=nom AND NOT applique_serveur AND NOT traite
     AND indice IN ('hp_set','moral_carte_postale') ORDER BY created_at,id
 LOOP PERFORM public.impact_realite_appliquer(ancien); END LOOP;
 RETURN jsonb_build_object('ok',true,'contrat',1);
END;
$function$;
REVOKE ALL ON FUNCTION public.impacts_realites_synchroniser() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.impacts_realites_synchroniser() TO authenticated;

-- L auteur lie le recu mais reste secret pour la victime (neutralisation non identifiee).
REVOKE SELECT ON public.impacts_indices_attente FROM authenticated;
GRANT SELECT(id,victime,indice,delta,raison,traite,created_at,palier,applique_serveur,applique_le,resultat) ON public.impacts_indices_attente TO authenticated;
REVOKE ALL ON FUNCTION public.impact_deposer(text,text,text,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.impact_deposer(text,text,text,integer,text) TO authenticated;
COMMIT;
