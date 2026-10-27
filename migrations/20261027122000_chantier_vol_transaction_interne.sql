-- PREPAREE #135, NE PAS DEPLOYER sans prevol et resolution du stockage de benediction.
-- Le navigateur utilise un bonus consommable non archive dans les colonnes du baseline.
-- Refus explicite plutot que supprimer silencieusement ce bonus en migrant le vol.
BEGIN;
DO $prevol$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='public.personnages_donnees'::regclass
 AND attname='benediction' AND atttypid='jsonb'::regtype AND NOT attisdropped) THEN
  RAISE EXCEPTION 'chantier_vol_dependance_benediction_persistante_non_verifiee';END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid='public.personnages_donnees'::regclass
 AND tgname='zzzz_hg_inventory_revision' AND NOT tgisinternal AND tgenabled='O'
 AND tgfoid=to_regprocedure('public.inventaire_revision_garder()')) THEN
  RAISE EXCEPTION 'chantier_vol_revision_inventaire_non_verifiee';END IF;
END;$prevol$;
CREATE OR REPLACE FUNCTION public.chantier_vol_jet_interne()
RETURNS integer LANGUAGE sql VOLATILE SET search_path=public,pg_temp AS $f$
 SELECT floor(random()*100)::integer+1;
$f$;
REVOKE ALL ON FUNCTION public.chantier_vol_jet_interne() FROM PUBLIC,anon,authenticated,service_role;

-- Traduction exacte des fonctions de plateau-chantiers.js ; contre-epreuves sur grille.
CREATE OR REPLACE FUNCTION public.chantier_vol_calcul_interne(p_bonus double precision,p_vigiles integer,p_jet integer,p_matiere text,p_jour integer,p_stock integer)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $f$
DECLARE score double precision;plafond integer;q integer:=0;
BEGIN
 score:=greatest(0,least(100,50+p_bonus::double precision-CASE WHEN p_vigiles>0 THEN 20+(p_vigiles-1)*10 ELSE 0 END+(p_jet-50)));
 IF p_jour<1 THEN plafond:=0;
 ELSIF p_matiere='metal' THEN plafond:=(ARRAY[6,7,7])[((p_jour-1)%3)+1];
 ELSE plafond:=CASE p_matiere WHEN 'bois' THEN 20 WHEN 'minerai' THEN 10 ELSE 0 END;END IF;
 IF score>=50 AND plafond>0 AND p_stock>0 THEN
  q:=least(plafond,p_stock,greatest(1,floor((score-50)/50*plafond+.5)::integer));END IF;
 RETURN jsonb_build_object('score',score,'reussite',score>=50,'detecte',score<20,'quantite',q);
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_vol_calcul_interne(double precision,integer,integer,text,integer,integer) FROM PUBLIC,anon,authenticated,service_role;

-- Moteur interne de l'action, appele uniquement par chantier_commande : son recu commun
-- englobe paiement, stock, inventaire, recherche, indices et traces. Pas de recu parallele.
CREATE OR REPLACE FUNCTION public.chantier_vol_executer_interne(p_terrain text,p_params jsonb,p_requete text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE acteur text:=public.mon_personnage();p record;t record;etat jsonb;ch jsonb;inv jsonb;
 matiere text:=p_params->>'matiere';stock integer;jour integer;numero integer;vigiles integer;
 dup double precision;isn double precision;bonus double precision;jet integer;r jsonb;pay jsonb;cout record;trace text;
 v_benediction jsonb;recherche jsonb;msg text;avant_revision bigint;
BEGIN
 IF p_params-ARRAY['matiere']<>'{}' OR matiere IS NULL OR matiere NOT IN('bois','minerai','metal') THEN
 RETURN jsonb_build_object('ok',false,'raison','matiere_invalide');END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=acteur FOR UPDATE;
 IF NOT FOUND OR auth.uid() IS NULL OR p.user_id IS DISTINCT FROM auth.uid() THEN
 RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 IF p.country IS DISTINCT FROM 'republic' THEN RETURN jsonb_build_object('ok',false,'raison','pays_non_raccorde');END IF;
 IF p.current_room IS DISTINCT FROM 'terrain' OR coalesce(p.hp,0)<=0 OR EXISTS(SELECT 1 FROM public.detention_active(acteur))
 OR coalesce(p.hospitalisation->>'dateFinParis','')>(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text THEN
 RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible');END IF;
 -- Bloquer les mutations des agents avant de verrouiller le terrain, dans le meme ordre
 -- que l'affectation. Ne jamais verrouiller le personnage du proprietaire depuis un vol.
 PERFORM 1 FROM public.pnj_membres WHERE id IN(SELECT a.pnj_id FROM public.chantier_vigiles_affectations a
 JOIN public.terrains_etat tt ON tt.id=a.terrain_id WHERE tt.country=p.country AND
 (tt.id=p_terrain OR tt.building_id=p_terrain AND tt.data::jsonb->>'city'=p.current_city))
 ORDER BY id FOR UPDATE;
 SELECT * INTO t FROM public.terrains_etat WHERE country=p.country
 AND (id=p_terrain OR building_id=p_terrain AND data::jsonb->>'city'=p.current_city)
 ORDER BY (id=p_terrain) DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR t.building_id IS DISTINCT FROM p.current_building
 OR t.data::jsonb->>'city' IS DISTINCT FROM p.current_city THEN
 RETURN jsonb_build_object('ok',false,'raison','pas_sur_place');END IF;
 etat:=t.data::jsonb;ch:=etat->'chantier';
 IF coalesce(etat->>'succession_gel','')<>'' OR jsonb_typeof(ch) IS DISTINCT FROM 'object'
 OR coalesce((ch->>'dureeJours')::numeric,0)<=0
 OR coalesce((ch->>'progressionJours')::numeric,0)>=(ch->>'dureeJours')::numeric THEN
 RETURN jsonb_build_object('ok',false,'raison','chantier_indisponible');END IF;
 stock:=coalesce((ch->'stockMateriaux'->>matiere)::integer,0);
 IF stock<=0 THEN RETURN jsonb_build_object('ok',false,'raison','stock_vide');END IF;
 IF jsonb_typeof(p.inventory) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'inventaire_format_a_reexaminer';END IF;
 SELECT * INTO cout FROM public.ordres_couts WHERE fn='voler_materiel_chantier';
 IF NOT FOUND OR (SELECT count(*) FROM public.ordres_couts WHERE fn='voler_materiel_chantier')<>1 THEN
 RETURN jsonb_build_object('ok',false,'raison','cout_indisponible');END IF;
 -- Moyenne de groupe et affaiblissement : meme perimetre que getStatEffective('DUP').
 SELECT avg(v) INTO dup FROM (
 SELECT coalesce((p.stats->>'DUP')::numeric,8) v
 UNION ALL SELECT m.car_dup::numeric FROM public.pnj_membres m
 JOIN public.pnj_employes_metier e ON e.pnj_id=m.id
 WHERE m.proprietaire_pj=acteur AND m.leader_pj=acteur AND m.statut='actif' AND m.car_dup IS NOT NULL) vals;
 IF p.stats_affaiblies ? 'DUP' THEN dup:=greatest(1,floor(dup*greatest(0,least(1,p.hp::numeric/100))+.5));
 ELSE dup:=floor(dup+.5);END IF;
 SELECT coalesce((data->>'isn')::numeric,30) INTO isn FROM public.indices_villes WHERE id=p.country||'_'||p.current_city;
 bonus:=(dup-10)*2-(coalesce(isn,30)-45)/3
 +CASE WHEN p.reputation_criminelle>=70 THEN 15 WHEN p.reputation_criminelle>=40 THEN 10 WHEN p.reputation_criminelle>=20 THEN 5 ELSE 0 END;
 v_benediction:=to_jsonb(p)->'benediction';
 jour:=public.jour_de_jeu_pays(p.country);
 -- Conserver l'ordre des operations du bonus consommable historique.
 bonus:=(50+bonus+CASE WHEN (v_benediction->>'actif')::boolean AND (NOT v_benediction ? 'expire' OR jour<=(v_benediction->>'expire')::integer) THEN 5 ELSE 0 END)-50;
 IF bonus::text IN('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'caracteristique_invalide';END IF;
 SELECT count(*) INTO vigiles FROM public.chantier_vigiles_presents_interne(t.id);
 numero:=floor(coalesce((ch->>'progressionJours')::numeric,0))::integer+1;
 jet:=public.chantier_vol_jet_interne();
 r:=public.chantier_vol_calcul_interne(bonus,vigiles,jet,matiere,numero,stock);
 pay:=public.payer_ordre(acteur,'voler_materiel_chantier',cout.pa,cout.cost);
 IF NOT coalesce((pay->>'ok')::boolean,false) THEN RETURN pay;END IF;
 IF (v_benediction->>'actif')::boolean AND (NOT v_benediction ? 'expire' OR jour<=(v_benediction->>'expire')::integer) THEN
  UPDATE public.personnages_donnees SET benediction=jsonb_set(v_benediction,'{actif}','false') WHERE name=acteur;END IF;
 trace:='vol-chantier-'||p.id::text||'-'||p_requete;
 IF (r->>'reussite')::boolean THEN
  inv:=public.inventaire_ajouter(p.inventory,matiere,(r->>'quantite')::integer,'Dérobé sur un chantier.');
  ch:=jsonb_set(ch,ARRAY['stockMateriaux',matiere],to_jsonb(stock-(r->>'quantite')::integer));
  ch:=ch||jsonb_build_object('evenements',coalesce(ch->'evenements','[]')||jsonb_build_array(jsonb_build_object('cle','vol_materiaux','jour',jour,'matiere',matiere,'quantite',(r->>'quantite')::integer)));
  UPDATE public.terrains_etat SET data=jsonb_set(etat,'{chantier}',ch)::text,updated_at=now() WHERE id=t.id;
  avant_revision:=p.inventory_revision;
  UPDATE public.personnages_donnees SET inventory=inv,updated_at=now() WHERE name=acteur;
  IF NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=acteur AND inventory=inv AND inventory_revision=avant_revision+1) THEN
   RAISE EXCEPTION 'inventaire_ecriture_non_confirmee';END IF;
  PERFORM public.indice_ville_ajuster_interne(p.country,p.current_city,'social',-1);
  msg:='Vol de matériaux réussi sur un chantier : '||(r->>'quantite')||' '||matiere||'.';
 ELSE
  IF (r->>'detecte')::boolean THEN
   recherche:=public.recherche_inscrire(jsonb_build_object('id',trace,'acte','vol_materiel_chantier','type','delit_mineur','jour',jour));
   IF NOT coalesce((recherche->>'ok')::boolean,false) THEN RAISE EXCEPTION 'recherche_non_confirmee';END IF;
   msg:='Vol raté et découvert immédiatement. Avis de recherche émis contre vous.';
  ELSE msg:='Tentative de vol de matériaux manquée. Personne ne vous a vu.';END IF;
 END IF;
 INSERT INTO public.actions_tracables(id,auteur,cible,type_action,country,city,jour,jour_expiration)
 VALUES(trace,acteur,etat->>'proprietaire',CASE WHEN (r->>'reussite')::boolean THEN 'vol_materiel_chantier' ELSE 'tentative_vol_materiel_chantier' END,p.country,p.current_city,jour,jour+15);
 UPDATE public.personnages_donnees SET journal=(SELECT jsonb_agg(value ORDER BY ord) FROM
 jsonb_array_elements(jsonb_build_array(jsonb_build_object('date',(statement_timestamp() AT TIME ZONE 'Europe/Paris')::date::text,'hour',extract(hour FROM statement_timestamp() AT TIME ZONE 'Europe/Paris'),'text',msg,'cls',CASE WHEN (r->>'reussite')::boolean THEN 'event-good' ELSE 'event-bad' END,'ts',statement_timestamp()))||coalesce(journal,'[]')) WITH ORDINALITY j(value,ord) WHERE ord<=120) WHERE name=acteur;
 IF (r->>'reussite')::boolean OR (r->>'detecte')::boolean THEN
 INSERT INTO public.evenements_globaux(country,city,texte,jour) VALUES(p.country,p.current_city,
 CASE WHEN (r->>'reussite')::boolean THEN 'Des matériaux ont disparu sur un chantier de la ville.' ELSE acteur||' a été pris en flagrant délit de vol de matériel sur un chantier !' END,jour);END IF;
 RETURN r||jsonb_build_object('ok',true,'matiere',matiere,'message',msg,'vigiles',vigiles);
END;$f$;
REVOKE ALL ON FUNCTION public.chantier_vol_executer_interne(text,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
