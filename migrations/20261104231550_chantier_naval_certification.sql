-- #473 : correction ciblée, ne pas réappliquer les deux migrations initiales.
-- Prévol réel des définitions et droits requis ; aucun appel métier dans la migration.
ALTER TABLE public.chantier_naval_commandes ADD COLUMN IF NOT EXISTS historique jsonb NOT NULL DEFAULT '[]'::jsonb;
DO $correction$
DECLARE r record;d text;
BEGIN
 FOR r IN SELECT * FROM (VALUES
($partie$public.chantier_naval_commander(text,uuid)$partie$,$partie$IF c.modele<>p_modele THEN$partie$,$partie$IF c.modele IS DISTINCT FROM p_modele THEN$partie$),
($partie$public.chantier_naval_commander(text,uuid)$partie$,$partie$IF p.country<>'republic' OR p.current_city<>'ville_a'
    OR p.current_building<>'chantier-naval' THEN$partie$,$partie$IF (p.country,p.current_city,p.current_building) IS DISTINCT FROM ('republic','ville_a','chantier-naval') THEN$partie$),
($partie$public.chantier_naval_commander(text,uuid)$partie$,$partie$RETURN jsonb_build_object('ok',true,'rejeu',true,'commande',c.id,'acompte',c.acompte);$partie$,$partie$RETURN jsonb_build_object('ok',true,'rejeu',true,'commande',c.id,'acompte',c.acompte) || public.inventaire_reception_etat(p.name)
    || jsonb_build_object('paie',(SELECT jsonb_build_object('pa',d.pa,'liquide',d.liquide,'arg',d.arg,
       'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=d.name AND banque='nationale'),0))
       FROM public.personnages_donnees d WHERE d.name=p.name));$partie$),
($partie$public.chantier_naval_commander(text,uuid)$partie$,$partie$'prix_total',c.prix_total,'jours',c.jours_total,'etat',c.etat);$partie$,$partie$'prix_total',c.prix_total,'jours',c.jours_total,'etat',c.etat) || public.inventaire_reception_etat(p.name)
    || jsonb_build_object('paie',(SELECT jsonb_build_object('pa',d.pa,'liquide',d.liquide,'arg',d.arg,
       'solde_national',coalesce((SELECT solde FROM public.comptes_bancaires WHERE personnage=d.name AND banque='nationale'),0))
       FROM public.personnages_donnees d WHERE d.name=p.name));$partie$),
($partie$public.chantier_naval_commander(text,uuid)$partie$,$partie$RETURNING * INTO c;
 RETURN$partie$,$partie$RETURNING * INTO c;
 UPDATE public.chantier_naval_commandes SET historique=jsonb_build_array(jsonb_build_object('type','acompte','le',now(),'montant',a,'requete',p_requete)) WHERE id=c.id;
 RETURN$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$-- AUCUN GRANT client : seul service_role pourra appeler cette primitive.$partie$,$partie$-- Double garde : ACL et identité serveur, y compris par un appelant indirect.
 IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','reserve_au_serveur');END IF;$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$IF c.dernier_jour=jour THEN$partie$,$partie$IF c.dernier_jour>=jour THEN$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$SELECT * INTO m FROM public.chantier_naval_modeles WHERE code=c.modele;$partie$,$partie$IF (c.cree_le AT TIME ZONE 'Europe/Paris')::date>jour THEN RETURN jsonb_build_object('ok',false,'raison','jour_anterieur_commande');END IF;
 SELECT * INTO m FROM public.chantier_naval_modeles WHERE code=c.modele;$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$disponible:=coalesce((v_stock->>k)::numeric,0);$partie$,$partie$disponible:=greatest(0,coalesce((v_stock->>k)::numeric,0)-coalesce((v_ent->'reserveMilitaire'->>k)::numeric,0));$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$to_jsonb(disponible-besoin)$partie$,$partie$to_jsonb((v_stock->>k)::numeric-besoin)$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$IF prix IS NULL OR prix<0 THEN$partie$,$partie$IF prix IS NULL OR prix<=0 OR prix::text IN('NaN','Infinity','-Infinity') THEN$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$(entrepot_id,operation,sens,ressource,quantite,prix_unitaire,montant,acteur,jour)$partie$,$partie$(entrepot_id,operation,sens,ressource,quantite,prix_unitaire,montant,acteur,jour,contrepartie)$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$VALUES (e_id,'chantier_naval','sortie',k,besoin,prix,besoin*prix,c.proprietaire_nom,jour);$partie$,$partie$VALUES (e_id,'chantier_naval','sortie',k,besoin,prix,besoin*prix,c.proprietaire_nom,jour,'Commande navale '||c.id::text);$partie$),
($partie$public.chantier_naval_avancer_interne(uuid)$partie$,$partie$PERFORM set_config('rp.caisse_interne','',true);
 RETURN jsonb_build_object('ok',true,'jours'$partie$,$partie$UPDATE public.chantier_naval_commandes SET historique=historique||jsonb_build_array(jsonb_build_object('type','journee','jour',jour,'numero',c.jours_faits+1,'echeance',tranche,'matieres',jsonb_build_object('bois',(v_stock->>'bois')::numeric-(v_nouveau->>'bois')::numeric,'metal',(v_stock->>'metal')::numeric-(v_nouveau->>'metal')::numeric,'derives_petrochimiques',(v_stock->>'derives_petrochimiques')::numeric-(v_nouveau->>'derives_petrochimiques')::numeric),'cout_matieres',cout,'bateau',navire)) WHERE id=c.id;
 PERFORM set_config('rp.caisse_interne','',true);
 RETURN jsonb_build_object('ok',true,'jours'$partie$),
($partie$public.chantier_naval_mes_commandes()$partie$,$partie$'bateau_id',b.id,'au_port',b.port,'navigable',coalesce(b.navigation_active,false)$partie$,$partie$'bateau_id',b.id,'au_port',b.port,'navigable',coalesce(b.navigation_active,false),
   'bateau',CASE WHEN b.id IS NULL THEN NULL ELSE jsonb_build_object('id',b.id,'immatriculation',b.id::text,'proprietaire',b.proprietaire_nom,'passagers',b.passagers,'fret',b.capacite_fret,'port',b.port,'navigation_active',b.navigation_active) END$partie$)
 ) AS fragments(signature,ancien,nouveau) LOOP
  IF to_regprocedure(r.signature) IS NULL THEN RAISE EXCEPTION 'naval_dependance_absente: %',r.signature;END IF;
  d:=pg_get_functiondef(to_regprocedure(r.signature));
  IF position(r.nouveau IN d)>0 THEN CONTINUE;END IF;
  IF position(r.ancien IN d)=0 THEN RAISE EXCEPTION 'naval_definition_inconnue: %',r.signature;END IF;
  EXECUTE replace(d,r.ancien,r.nouveau);
 END LOOP;
END $correction$;
