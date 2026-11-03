-- #379, lot 3d (Claude, 03/11/2026) : dîner d'affaires du Capitaine Sauvage (Port-Sainte-Marie)
-- sur le contrat atomique du dîner de La Républia, au lieu du chemin de l'écran.
-- Avant : l'écran tirait l'acceptation d'un PNJ (Math.random), prélevait, puis s'ajoutait
-- +10 Santé +2 Moral +5 INF ; l'invité PJ se les ajoutait à l'acceptation, même sans dîner servi.
-- Règles d'origine conservées (data.js, plateau-pnj.js) : 2 PA et 150 FR à l'organisateur,
-- uniquement si l'invitation est acceptée et le service possible ; 2 menus (menu_psm_1, puis 2,
-- puis 3, dans cet ordre) et 1 vin du restaurant ; +10 Santé +2 Moral +5 INF et +3 PA au prochain
-- Dormir pour chacun des deux convives ; PNJ : 95 % s'il suit le joueur, 85 % allié, 20 % ennemi,
-- 60 % sinon. Mêmes portes que La Républia (créer, répondre, servir, suivre, acquitter) : une
-- seconde « contrat » (commerce_v1) seulement, aucun nouveau moteur de paiement ou de stock.
-- Dépend de 20261103235500 (miroir pnj_lieux_metiers avec la relation).

DO $prevol$
BEGIN
 IF to_regclass('public.pnj_lieux_metiers') IS NULL OR NOT EXISTS(SELECT 1 FROM information_schema.columns
     WHERE table_schema='public' AND table_name='pnj_lieux_metiers' AND column_name='rel') THEN
  RAISE EXCEPTION '379_lot3d_miroir_pnj_absent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_creer(text,text,boolean,text)')
     AND (md5(prosrc)='3b35cdf583b4a85835a64a2cae3a9bf4' OR position('hg379_diner_commerce_v1' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_lot3d_creer_divergent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_repondre(bigint,boolean,text)')
     AND (md5(prosrc)='b29a9f18f3e6a8c2c43c1176ee67adc3' OR position('hg379_diner_commerce_v1' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_lot3d_repondre_divergent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_servir(bigint)')
     AND (md5(prosrc)='8d91a15259c3cfcd9d2e67623598a47f' OR position('hg379_diner_commerce_v1' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_lot3d_servir_divergent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_suivre()')
     AND (md5(prosrc)='6fc3ad2a14f9355edd06c28e53a24dd0' OR position('commerce_v1' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_lot3d_suivre_divergent'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.restaurant_diner_acquitter(bigint)')
     AND (md5(prosrc)='d58847cb4791b6e2047beed14edff974' OR position('commerce_v1' in prosrc)>0)) THEN
  RAISE EXCEPTION '379_lot3d_acquitter_divergent'; END IF;
END $prevol$;

INSERT INTO public.ordres_couts(fn,pa,cost) VALUES ('diner_affaires',2,150) ON CONFLICT DO NOTHING;

-- Lieux servis par le contrat commerce_v1. Une seule ligne aujourd'hui ; la carte vient de data.js.
CREATE OR REPLACE FUNCTION public.diner_commerce_lieu_interne(p_pays text,p_ville text,p_bat text,p_piece text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE WHEN (p_pays,p_ville,p_bat,p_piece)=('republic','ville_a','capitaine-sauvage','salle_principale')
    THEN '{"entreprise":"brasserie-republic-ville_a-capitaine-sauvage-salle_principale","prix":150,"pa":2,
           "menus":["menu_psm_1","menu_psm_2","menu_psm_3"],"boisson":"vin","qte_boisson":1}'::jsonb END;
$f$;
REVOKE ALL ON FUNCTION public.diner_commerce_lieu_interne(text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.diner_commerce_pnj_chance_interne(p_acteur text,p_invite text)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE chance integer;
BEGIN
 SELECT CASE l.rel WHEN 'ally' THEN 85 WHEN 'enemy' THEN 20 ELSE 60 END INTO chance
   FROM public.personnages_donnees a JOIN public.pnj_lieux_metiers l
     ON l.pays=a.country AND l.ville=a.current_city AND l.building_id=a.current_building AND l.room_id=a.current_room AND l.nom=p_invite
  WHERE a.name=p_acteur;
 -- Groupe, escort, agents : même règle et même lecture que le dîner de La Républia (95 %).
 IF public.restaurant_luthecia_pnj_chance(p_acteur,p_invite)=95 THEN chance:=95; END IF;
 RETURN chance;
END $f$;
REVOKE ALL ON FUNCTION public.diner_commerce_pnj_chance_interne(text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.diner_commerce_creer_interne(moi text,p_requete text,p_invite text,p_pnj boolean,p_message text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE i public.invitations_diner; p public.personnages_donnees; cfg jsonb; chance integer; etat text:='attente';
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('restaurant:'||p_requete,0));
 SELECT * INTO i FROM public.invitations_diner WHERE requete_restaurant=p_requete FOR UPDATE;
 IF FOUND THEN
  IF i.inviteur=moi AND i.invite=p_invite AND i.invite_pnj=p_pnj AND coalesce(i.message,'')=left(coalesce(p_message,''),200) THEN RETURN jsonb_build_object('ok',true,'id',i.id,'statut',i.statut,'rejeu',true); END IF;
  RETURN '{"ok":false,"raison":"requete_incompatible"}'; END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(ARRAY[moi,CASE WHEN NOT p_pnj THEN p_invite ELSE moi END]) ORDER BY name FOR UPDATE;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 cfg:=public.diner_commerce_lieu_interne(p.country,p.current_city,p.current_building,p.current_room);
 IF cfg IS NULL THEN RETURN '{"ok":false,"raison":"pas_sur_place"}'; END IF;
 IF p_pnj THEN
  chance:=public.diner_commerce_pnj_chance_interne(moi,p_invite);
  IF chance IS NULL THEN RETURN '{"ok":false,"raison":"pnj_non_present"}'; END IF;
  etat:=CASE WHEN floor(random()*100)+1<=chance THEN 'acceptee' ELSE 'refusee' END;
 ELSIF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=p_invite AND country=p.country AND current_city=p.current_city
     AND current_building=p.current_building AND current_room=p.current_room) THEN
  RETURN '{"ok":false,"raison":"invite_absent"}';
 END IF;
 INSERT INTO public.invitations_diner(inviteur,invite,country,city,building_id,room_id,cout,type,message,statut,contrat_restaurant,requete_restaurant,invite_pnj,resultat_service)
 VALUES(moi,p_invite,p.country,p.current_city,p.current_building,p.current_room,(cfg->>'prix')::integer,'diner_affaires',left(coalesce(p_message,''),200),etat,
        'commerce_v1',p_requete,p_pnj,CASE WHEN etat='refusee' THEN '{"ok":false,"raison":"invitation_refusee"}'::jsonb ELSE NULL END) RETURNING * INTO i;
 RETURN jsonb_build_object('ok',true,'id',i.id,'statut',i.statut,'prix',i.cout);
END $f$;
REVOKE ALL ON FUNCTION public.diner_commerce_creer_interne(text,text,text,boolean,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.diner_commerce_servir_interne(moi text,p_invitation bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE i public.invitations_diner; cfg jsonb; d jsonb; restant integer:=2; disponible integer; pris integer; menu text;
  articles jsonb:='[]'; r jsonb; detail text; bonus integer;
BEGIN
 SELECT * INTO i FROM public.invitations_diner WHERE id=p_invitation FOR UPDATE;
 IF NOT FOUND OR i.inviteur IS DISTINCT FROM moi OR i.contrat_restaurant IS DISTINCT FROM 'commerce_v1' THEN RETURN '{"ok":false,"raison":"pas_mon_invitation"}'; END IF;
 IF i.resultat_service IS NOT NULL THEN RETURN i.resultat_service||'{"rejeu":true}'; END IF;
 IF i.statut<>'acceptee' THEN RETURN '{"ok":false,"raison":"acceptation_requise"}'; END IF;
 cfg:=public.diner_commerce_lieu_interne(i.country,i.city,i.building_id,i.room_id);
 SELECT data INTO d FROM public.entreprises WHERE id=cfg->>'entreprise' FOR UPDATE;
 PERFORM 1 FROM public.personnages_donnees WHERE name=ANY(ARRAY[moi,CASE WHEN NOT i.invite_pnj THEN i.invite ELSE moi END]) ORDER BY name FOR UPDATE;
 IF cfg IS NULL OR d IS NULL THEN r:='{"ok":false,"raison":"commerce_introuvable"}';
 ELSIF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country=i.country AND current_city=i.city AND current_building=i.building_id AND current_room=i.room_id)
   OR (i.invite_pnj AND public.diner_commerce_pnj_chance_interne(moi,i.invite) IS NULL)
   OR (NOT i.invite_pnj AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=i.invite AND country=i.country AND current_city=i.city AND current_building=i.building_id AND current_room=i.room_id)) THEN
  r:='{"ok":false,"raison":"action_obsolete"}';
 ELSE
  FOR menu IN SELECT jsonb_array_elements_text(cfg->'menus') LOOP
   disponible:=greatest(0,coalesce((d->'stockProduits'->>menu)::integer,0));pris:=least(restant,disponible);
   IF pris>0 THEN articles:=articles||jsonb_build_array(jsonb_build_object('produit',menu,'qte',pris));restant:=restant-pris; END IF;
   EXIT WHEN restant=0;
  END LOOP;
  IF restant>0 OR coalesce((d->'stockProduits'->>(cfg->>'boisson'))::integer,0)<(cfg->>'qte_boisson')::integer THEN r:='{"ok":false,"raison":"stock_insuffisant"}';
  ELSE
   articles:=articles||jsonb_build_array(jsonb_build_object('produit',cfg->>'boisson','qte',(cfg->>'qte_boisson')::integer));
   -- La même vente de service que l'ancien chemin (ordre diner_affaires, coût déclaré), mais vente,
   -- stock et effets des deux convives forment un seul acte et un seul reçu.
   BEGIN
    r:=public.commerce_vendre_produit_interne(moi,cfg->>'entreprise',articles,'service','diner_affaires',(cfg->>'pa')::integer,(cfg->>'prix')::integer,NULL,NULL);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'diner_vente_refusee' USING DETAIL=r::text; END IF;
    SELECT montant INTO bonus FROM public.pa_bonus_differes WHERE source='diner_affaires';
    IF bonus IS DISTINCT FROM 3 THEN RAISE EXCEPTION 'bonus_diner_incompatible'; END IF;
    UPDATE public.personnages_donnees SET hp=least(100,coalesce(hp,100)+10),moral=least(100,coalesce(moral,75)+2),
      resources=jsonb_set(coalesce(resources,'{}')-'popBase'-'infBase','{inf}',to_jsonb(least(100,coalesce((resources->>'inf')::numeric,0)+5)),true),
      bonus_pa_differe=least(30,coalesce(bonus_pa_differe,0)+bonus),updated_at=now()
    WHERE name=moi OR (NOT i.invite_pnj AND name=i.invite);
    r:=jsonb_build_object('ok',true,'total',(cfg->>'prix')::integer,'repas',2,'boissons',(cfg->>'qte_boisson')::integer,'pa',(cfg->>'pa')::integer,'articles',articles);
   EXCEPTION WHEN raise_exception THEN
    IF SQLERRM<>'diner_vente_refusee' THEN RAISE; END IF;
    GET STACKED DIAGNOSTICS detail=PG_EXCEPTION_DETAIL;r:=detail::jsonb;
   END;
  END IF;
 END IF;
 UPDATE public.invitations_diner SET resultat_service=r WHERE id=i.id;
 RETURN r;
END $f$;
REVOKE ALL ON FUNCTION public.diner_commerce_servir_interne(text,bigint) FROM PUBLIC,anon,authenticated,service_role;

-- Les cinq portes existantes : aiguillage vers commerce_v1, corps de La Républia inchangés.
DO $patch$
DECLARE v_def text;
BEGIN
 -- créer : hors du restaurant de La Républia, un lieu commerce_v1 prend la main.
 v_def:=pg_get_functiondef('public.restaurant_diner_creer(text,text,boolean,text)'::regprocedure);
 IF position('hg379_diner_commerce_v1' in v_def)=0 THEN
  IF (length(v_def)-length(replace(v_def,E' PERFORM pg_advisory_xact_lock(hashtextextended(''restaurant:''||p_requete,0));',
      '')))/length(E' PERFORM pg_advisory_xact_lock(hashtextextended(''restaurant:''||p_requete,0));')<>1 THEN RAISE EXCEPTION '379_lot3d_ancre_creer'; END IF;
  v_def:=replace(v_def,E' PERFORM pg_advisory_xact_lock(hashtextextended(''restaurant:''||p_requete,0));',
   E' -- hg379_diner_commerce_v1\n'
 ||E' IF EXISTS(SELECT 1 FROM public.personnages_donnees x WHERE x.name=moi AND public.diner_commerce_lieu_interne(x.country,x.current_city,x.current_building,x.current_room) IS NOT NULL) THEN\n'
 ||E'  RETURN public.diner_commerce_creer_interne(moi,p_requete,p_invite,p_pnj,p_message); END IF;\n'
 ||E' PERFORM pg_advisory_xact_lock(hashtextextended(''restaurant:''||p_requete,0));');
  EXECUTE v_def;
 END IF;
 -- servir : une invitation commerce_v1 est servie par sa porte interne.
 v_def:=pg_get_functiondef('public.restaurant_diner_servir(bigint)'::regprocedure);
 IF position('hg379_diner_commerce_v1' in v_def)=0 THEN
  IF (length(v_def)-length(replace(v_def,E' IF moi IS NULL THEN RETURN ''{"ok":false,"raison":"acteur_non_authentifie"}''; END IF;\n SELECT * INTO i','')))
     /length(E' IF moi IS NULL THEN RETURN ''{"ok":false,"raison":"acteur_non_authentifie"}''; END IF;\n SELECT * INTO i')<>1 THEN RAISE EXCEPTION '379_lot3d_ancre_servir'; END IF;
  v_def:=replace(v_def,E' IF moi IS NULL THEN RETURN ''{"ok":false,"raison":"acteur_non_authentifie"}''; END IF;\n SELECT * INTO i',
   E' IF moi IS NULL THEN RETURN ''{"ok":false,"raison":"acteur_non_authentifie"}''; END IF;\n'
 ||E' -- hg379_diner_commerce_v1\n'
 ||E' IF EXISTS(SELECT 1 FROM public.invitations_diner WHERE id=p_invitation AND contrat_restaurant=''commerce_v1'') THEN\n'
 ||E'  RETURN public.diner_commerce_servir_interne(moi,p_invitation); END IF;\n SELECT * INTO i');
  EXECUTE v_def;
 END IF;
 -- répondre : même porte, présence lue sur l'invitation (identique pour La Républia).
 v_def:=pg_get_functiondef('public.restaurant_diner_repondre(bigint,boolean,text)'::regprocedure);
 IF position('hg379_diner_commerce_v1' in v_def)=0 THEN
  IF position(E'i.contrat_restaurant IS DISTINCT FROM ''luthecia_v1''' in v_def)=0
     OR position(E'WHERE name=moi AND country=''republic'' AND current_city=''capitale'' AND current_building=''hotel-republica'' AND current_room=''restaurant''' in v_def)=0 THEN
   RAISE EXCEPTION '379_lot3d_ancre_repondre'; END IF;
  v_def:=replace(v_def,E'i.contrat_restaurant IS DISTINCT FROM ''luthecia_v1''',E'coalesce(i.contrat_restaurant,'''') NOT IN(''luthecia_v1'',''commerce_v1'') /* hg379_diner_commerce_v1 */');
  v_def:=replace(v_def,E'WHERE name=moi AND country=''republic'' AND current_city=''capitale'' AND current_building=''hotel-republica'' AND current_room=''restaurant''',
    'WHERE name=moi AND country=i.country AND current_city=i.city AND current_building=i.building_id AND current_room=i.room_id');
  EXECUTE v_def;
 END IF;
 -- suivre et acquitter : les deux contrats.
 v_def:=pg_get_functiondef('public.restaurant_diner_suivre()'::regprocedure);
 IF position('commerce_v1' in v_def)=0 THEN
  IF position(E'i.contrat_restaurant=''luthecia_v1''' in v_def)=0 THEN RAISE EXCEPTION '379_lot3d_ancre_suivre'; END IF;
  EXECUTE replace(v_def,E'i.contrat_restaurant=''luthecia_v1''',E'i.contrat_restaurant IN(''luthecia_v1'',''commerce_v1'')');
 END IF;
 v_def:=pg_get_functiondef('public.restaurant_diner_acquitter(bigint)'::regprocedure);
 IF position('commerce_v1' in v_def)=0 THEN
  IF position(E'i.contrat_restaurant IS DISTINCT FROM ''luthecia_v1''' in v_def)=0 THEN RAISE EXCEPTION '379_lot3d_ancre_acquitter'; END IF;
  EXECUTE replace(v_def,E'i.contrat_restaurant IS DISTINCT FROM ''luthecia_v1''',E'coalesce(i.contrat_restaurant,'''') NOT IN(''luthecia_v1'',''commerce_v1'')');
 END IF;
END $patch$;
NOTIFY pgrst,'reload schema';
