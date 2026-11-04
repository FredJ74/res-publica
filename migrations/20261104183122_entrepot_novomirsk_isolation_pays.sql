-- Entrepôts multi-empires : même moteur, clé (pays, ville), aucun échange international.
-- PRÉVOL RÉEL OBLIGATOIRE : outils/bancs/prevol-entrepot-novomirsk.sql.
-- Non appliquée. Aucun stock, solde ou poste PJ existant n'est réécrit.
-- Dépendances : livraisons terrestres 20261104173000/181000/183000 et socles #219/#379.
-- Ne pas attribuer implicitement Républia à une ligne inconnue ajoutée depuis la capture.
DO $origine$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public'
  AND table_name='entrepots_par_ville' AND column_name='pays') AND EXISTS(
   SELECT 1 FROM public.entrepots_par_ville e WHERE (e.ville,e.building_id) NOT IN
    (('capitale','entrepot-logistique-luthecia'),('ville_a','entrepot-logistique-psm'),
     ('ville_b','entrepot-logistique-montrouge'),('zzville-a','entrepot-zztest-a'),('zzville-b','entrepot-zztest-b'))) THEN
  RAISE EXCEPTION 'referentiel_legacy_a_identifier';
 END IF;
END $origine$;
ALTER TABLE public.entrepots_par_ville ADD COLUMN IF NOT EXISTS pays text NOT NULL DEFAULT 'republic';
ALTER TABLE public.entrepots_par_ville ALTER COLUMN pays DROP DEFAULT;
DO $cle$
DECLARE definition text;
BEGIN
 SELECT pg_get_constraintdef(oid) INTO definition FROM pg_constraint
  WHERE conrelid='public.entrepots_par_ville'::regclass AND contype='p';
 IF definition='PRIMARY KEY (ville)' THEN
  ALTER TABLE public.entrepots_par_ville DROP CONSTRAINT entrepots_par_ville_pkey;
  ALTER TABLE public.entrepots_par_ville ADD CONSTRAINT entrepots_par_ville_pkey PRIMARY KEY(pays,ville);
 ELSIF definition IS DISTINCT FROM 'PRIMARY KEY (pays, ville)' THEN
  RAISE EXCEPTION 'cle_entrepots_inattendue: %',definition;
 END IF;
END $cle$;

-- Adapter les corps existants plutôt que recopier une version historique complète.
-- Chaque fragment doit être retrouvé exactement ; dérive inconnue => rollback de la migration.
DO $patch$
DECLARE r record; d text; n text;
BEGIN
 FOR r IN SELECT * FROM (VALUES
  ($fragment$public.entrepot_du_directeur(text)$fragment$,$fragment$SELECT 'republic_' || e.ville$fragment$,$fragment$SELECT e.pays || '_' || e.ville$fragment$),
  ($fragment$public.entrepot_du_directeur(text)$fragment$,$fragment$e.ville = p.poste->>'city'$fragment$,$fragment$e.pays = p.country AND e.ville = p.poste->>'city'$fragment$),
  ($fragment$public.fixer_prix_entrepot(text,text,jsonb)$fragment$,$fragment$SELECT building_id INTO v_bat FROM public.entrepots_par_ville WHERE ville = v_ville;$fragment$,$fragment$IF p_pays IS DISTINCT FROM (SELECT country FROM public.personnages_donnees WHERE name = p_acteur) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_invalide'); END IF;
  SELECT building_id INTO v_bat FROM public.entrepots_par_ville WHERE pays = p_pays AND ville = v_ville;$fragment$),
  ($fragment$public.chantier_commande(text,text,text,jsonb)$fragment$,$fragment$FROM public.entrepots_par_ville WHERE ville=etat->>'city'$fragment$,$fragment$FROM public.entrepots_par_ville WHERE pays=t.country AND ville=etat->>'city'$fragment$),
  ($fragment$public.chantier_jour_traiter(text)$fragment$,$fragment$FROM public.entrepots_par_ville WHERE ville=etat->>'city'$fragment$,$fragment$FROM public.entrepots_par_ville WHERE pays=r.country AND ville=etat->>'city'$fragment$),
  ($fragment$public.trading_cours()$fragment$,$fragment$WHERE b.id = v_pays || '_' || ep.ville || '_' || ep.building_id) x)$fragment$,$fragment$WHERE b.id = v_pays || '_' || ep.ville || '_' || ep.building_id) x WHERE ep.pays = v_pays)$fragment$),
  ($fragment$public.trading_acheter(text,text,text,integer,text)$fragment$,$fragment$WHERE m.country || '_' || ep.ville || '_' || ep.building_id = p_entrepot;$fragment$,$fragment$WHERE ep.pays = m.country AND ep.pays || '_' || ep.ville || '_' || ep.building_id = p_entrepot;$fragment$),
  ($fragment$public.trading_livraison_entrepot_interne(text,text,text)$fragment$,$fragment$FROM public.entrepots_par_ville ep
   ORDER BY$fragment$,$fragment$FROM public.entrepots_par_ville ep
   WHERE ep.pays = p_pays
   ORDER BY$fragment$),
  ($fragment$public.offres_achat_lire()$fragment$,$fragment$WHERE o.pays || '_' || ep.ville || '_' || ep.building_id = o.entrepot_id$fragment$,$fragment$WHERE ep.pays = o.pays AND ep.pays || '_' || ep.ville || '_' || ep.building_id = o.entrepot_id$fragment$),
  ($fragment$public.offre_achat_servir(uuid,integer,text,text,text)$fragment$,$fragment$IF o.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'offre_introuvable'); END IF;$fragment$,$fragment$IF o.id IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'offre_introuvable'); END IF;
  IF o.pays IS DISTINCT FROM (SELECT country FROM public.personnages_donnees WHERE name=v_moi) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'international_non_ouvert'); END IF;$fragment$),
  ($fragment$public.entrepot_caisse_id(text)$fragment$,$fragment$JOIN public.villes v ON v.pays = e.country AND v.ville = e.city$fragment$,$fragment$JOIN public.villes v ON v.pays = e.country AND v.ville = e.city
    JOIN public.entrepots_par_ville ep ON ep.pays=e.country AND ep.ville=e.city AND ep.building_id=e.building_id$fragment$),
  ($fragment$public.entrepot_commander(text,text,integer,text,text)$fragment$,$fragment$IF p_fournisseur_type = 'entrepot' AND p_fournisseur_id = v_dest_id THEN$fragment$,$fragment$-- Les échanges entre empires ne sont pas ouverts. Garde avant tout débit ou transit.
  IF p_fournisseur_type = 'etranger' OR (p_fournisseur_type IN ('entrepot','port') AND NOT EXISTS (
    SELECT 1 FROM public.batiments_etat f JOIN public.batiments_etat d ON d.id=v_dest_id
     WHERE f.id=p_fournisseur_id AND f.country=d.country
       AND ((p_fournisseur_type='entrepot' AND EXISTS (SELECT 1 FROM public.entrepots_par_ville ep
         WHERE ep.pays=f.country AND ep.ville=f.city AND ep.building_id=f.building_id))
         OR (p_fournisseur_type='port' AND f.country='republic' AND f.city='ville_a' AND f.building_id='port-sainte-marie')))) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'international_non_ouvert'); END IF;
  IF p_fournisseur_type = 'entrepot' AND p_fournisseur_id = v_dest_id THEN$fragment$),
  ($fragment$public.entrepot_commander(text,text,integer,text,text)$fragment$,$fragment$IF v_stock_f < p_quantite THEN$fragment$,$fragment$IF v_stock_f - (CASE WHEN p_fournisseur_type='entrepot' THEN coalesce((v_ent_f->'reserveMilitaire'->>p_ressource)::numeric,0) ELSE 0 END) < p_quantite THEN$fragment$),
  ($fragment$public.acheter_a_entrepot(text,text,text,text,jsonb)$fragment$,$fragment$PERFORM public.exiger_acteur(p_acteur);$fragment$,$fragment$PERFORM public.exiger_acteur(p_acteur);
  IF NOT EXISTS (SELECT 1 FROM public.entrepots_par_ville ep WHERE ep.pays=p_pays AND ep.ville=p_ville AND ep.building_id=p_batiment) THEN
    RETURN jsonb_build_object('ok',false,'raison','entrepot_introuvable'); END IF;
  IF NOT public.est_appel_serveur() AND NOT EXISTS (SELECT 1 FROM public.personnages_donnees p
    WHERE p.name=p_acteur AND (p.country,p.current_city,p.current_building,p.current_room)=(p_pays,p_ville,p_batiment,'salle_ventes')) THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_sur_place'); END IF;$fragment$),
  ($fragment$public.acheter_a_entrepot(text,text,text,text,jsonb)$fragment$,$fragment$v_entrepot := v_entrepot || jsonb_build_object('stock', v_stock,
                  'caisse', coalesce((v_entrepot->>'caisse')::numeric, 0) + v_paye);$fragment$,$fragment$PERFORM set_config('rp.caisse_interne','on',true);
  IF NOT coalesce((public.caisse_institution_mouvement(public.entrepot_caisse_id(v_id),v_paye,true)->>'ok')::boolean,false) THEN
    RAISE EXCEPTION 'recette_entrepot_non_confirmee'; END IF;
  v_entrepot := v_entrepot || jsonb_build_object('stock', v_stock);$fragment$),
  ($fragment$public.acheter_a_entrepot(text,text,text,text,jsonb)$fragment$,$fragment$'caisse_entrepot', (v_entrepot->>'caisse')::numeric$fragment$,$fragment$'caisse_entrepot', public.entrepot_caisse_lire(v_id)$fragment$),
  ($fragment$public.entrepot_commander(text,text,integer,text,text)$fragment$,$fragment$PERFORM public.caisse_institution_mouvement(v_caisse_four_id,
                                                  round(p_quantite * v_prix, 2), true);$fragment$,$fragment$v_rep := public.caisse_institution_mouvement(v_caisse_four_id, round(p_quantite * v_prix, 2), true);
      IF NOT coalesce((v_rep->>'ok')::boolean,false) THEN RAISE EXCEPTION 'recette_fournisseur_non_confirmee';END IF;$fragment$),
  ($fragment$public.entrepot_commander(text,text,integer,text,text)$fragment$,$fragment$PERFORM public.caisse_institution_mouvement('republic_port-sainte-marie',
                                                  round(p_quantite * v_prix, 2), false);$fragment$,$fragment$v_rep := public.caisse_institution_mouvement('republic_port-sainte-marie',round(p_quantite * v_prix, 2),true);
      IF NOT coalesce((v_rep->>'ok')::boolean,false) THEN RAISE EXCEPTION 'recette_port_non_confirmee';END IF;$fragment$),
  ($fragment$public.trading_livraison_courrier_interne(text,text,timestamp with time zone,text)$fragment$,$fragment$v_nom := CASE p_ville WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie'
                        WHEN 'ville_b' THEN 'Montrouge' ELSE p_ville END;$fragment$,$fragment$SELECT coalesce(v.nom,p_ville) INTO v_nom FROM public.villes v
    JOIN public.personnages_donnees p ON p.country=v.pays AND p.name=p_dest WHERE v.ville=p_ville;
  v_nom:=coalesce(v_nom,p_ville);$fragment$),
  ($fragment$public.fret_arrivees_constater()$fragment$,$fragment$RETURNING k.destinataire, k.ville_destination, k.declaration_douaniere$fragment$,$fragment$RETURNING k.destinataire, k.pays_destination, k.ville_destination, k.declaration_douaniere$fragment$),
  ($fragment$public.fret_arrivees_constater()$fragment$,$fragment$v_nom := CASE c.ville_destination WHEN 'capitale' THEN 'Luthécia' WHEN 'ville_a' THEN 'Port-Sainte-Marie'
                                      WHEN 'ville_b' THEN 'Montrouge' ELSE c.ville_destination END;$fragment$,$fragment$SELECT coalesce(v.nom,c.ville_destination) INTO v_nom FROM public.villes v
     WHERE v.pays=c.pays_destination AND v.ville=c.ville_destination;
    v_nom:=coalesce(v_nom,c.ville_destination);$fragment$),
  ($fragment$public.trading_acheter(text,text,text,integer,text)$fragment$,$fragment$  v_caisse_ent := public.entrepot_caisse_id(p_entrepot);$fragment$,$fragment$  IF p_livraison IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.entrepots_par_ville ep
    WHERE ep.pays=m.country AND ep.pays||'_'||ep.ville||'_'||ep.building_id=p_livraison) THEN
    RETURN jsonb_build_object('ok',false,'raison','international_non_ouvert'); END IF;
  v_caisse_ent := public.entrepot_caisse_id(p_entrepot);$fragment$),
  ($fragment$public.fixer_prix_entrepot(text,text,jsonb)$fragment$,$fragment$IF v_val IS NULL OR v_val <= 0 OR NOT (v_val = v_val) THEN$fragment$,$fragment$IF v_val IS NULL OR v_val <= 0 OR v_val::text IN ('NaN','Infinity','-Infinity') THEN$fragment$),
  ($fragment$public.offre_achat_servir(uuid,integer,text,text,text)$fragment$,$fragment$  IF o.acheteur_type = 'entrepot' AND public.entrepot_capacite_disponible(o.entrepot_id, o.ressource) < q THEN$fragment$,$fragment$  -- Même ordre de verrouillage que la commande directeur : capacité et stock restent cohérents.
  PERFORM 1 FROM public.batiments_etat e
   WHERE e.id=o.entrepot_id OR (p_source='entrepot' AND e.id=(SELECT entrepot_id FROM public.entrepot_du_directeur(v_moi)))
   ORDER BY e.id FOR UPDATE;
  IF o.acheteur_type = 'entrepot' AND public.entrepot_capacite_disponible(o.entrepot_id, o.ressource) < q THEN$fragment$)
 ) AS fragments(signature,ancien,nouveau) LOOP
  IF to_regprocedure(r.signature) IS NULL THEN RAISE EXCEPTION 'dependance_absente: %',r.signature; END IF;
  d:=pg_get_functiondef(to_regprocedure(r.signature));
  IF position(r.nouveau IN d)>0 THEN CONTINUE; END IF;
  IF position(r.ancien IN d)=0 THEN RAISE EXCEPTION 'definition_non_reconnue: %',r.signature; END IF;
  n:=replace(d,r.ancien,r.nouveau);
  EXECUTE n;
 END LOOP;
END $patch$;

-- Aucun appelant oublié du référentiel sans filtre de pays. Un nouveau corps inconnu bloque.
DO $audit$
DECLARE r record;
BEGIN
 FOR r IN SELECT p.oid::regprocedure AS signature,p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prokind='f' AND p.prosrc LIKE '%entrepots_par_ville%'
 LOOP
  IF r.signature::text NOT IN ('entrepot_du_directeur(text)','fixer_prix_entrepot(text,text,jsonb)',
    'chantier_commande(text,text,text,jsonb)','chantier_jour_traiter(text)','trading_cours()',
    'trading_acheter(text,text,text,integer,text)','trading_livraison_entrepot_interne(text,text,text)',
    'offres_achat_lire()','entrepot_caisse_id(text)','entrepot_commander(text,text,integer,text,text)',
    'acheter_a_entrepot(text,text,text,text,jsonb)') THEN
    RAISE EXCEPTION 'appelant_entrepots_a_auditer: %',r.signature;
  END IF;
 END LOOP;
END $audit$;

INSERT INTO public.entrepots_par_ville(pays,ville,building_id)
VALUES ('soviet','capitale','entrepot-logistique-novomirsk') ON CONFLICT(pays,ville) DO NOTHING;
DO $identite$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.entrepots_par_ville WHERE pays='soviet' AND ville='capitale'
  AND building_id='entrepot-logistique-novomirsk') THEN RAISE EXCEPTION 'entrepot_sovarka_deja_different';END IF;
 IF NOT EXISTS (SELECT 1 FROM public.villes WHERE pays='soviet' AND ville='capitale') THEN RAISE EXCEPTION 'ville_sovarka_absente';END IF;
END $identite$;
INSERT INTO public.batiments_etat(id,country,city,building_id,data)
VALUES ('soviet_capitale_entrepot-logistique-novomirsk','soviet','capitale','entrepot-logistique-novomirsk',
 to_jsonb('{"entrepot":{"stock":{},"prixManuel":{},"desiderata":{},"reserveMilitaire":{}}}'::text)) ON CONFLICT(id) DO NOTHING;
-- Initialisation sans dotation monétaire ni matière fictive. Les caisses existantes sont conservées.
INSERT INTO public.caisses_batiments(id,data) VALUES('soviet_entrepot_capitale','{"solde":0}') ON CONFLICT(id) DO NOTHING;
INSERT INTO public.navigation_lieux_regles(pays,ville,batiment,pieces,ferme,membership)
VALUES('soviet','capitale','entrepot-logistique-novomirsk','["accueil","salle_ventes","bureau_direction"]',false,NULL)
ON CONFLICT(pays,ville,batiment) DO UPDATE SET pieces=EXCLUDED.pieces;
INSERT INTO public.rue_sorties_batiments(country,city,noeud,building)
VALUES('soviet','capitale','novomirsk-vue-8','entrepot-logistique-novomirsk') ON CONFLICT(country,city,noeud,building) DO NOTHING;

INSERT INTO public.pnj_lieux_metiers(pays,ville,building_id,room_id,nom,job,rel) VALUES
('soviet','capitale','entrepot-logistique-novomirsk','accueil','Agent logistique de Novomirsk','fonctionnaire','neutral'),
('soviet','capitale','entrepot-logistique-novomirsk','bureau_direction','Directeur logistique de Novomirsk','directeur_entrepot','neutral')
ON CONFLICT(pays,ville,building_id,room_id,nom) DO NOTHING;

-- Même reçu de requête que les achats d'inventaire ; pas de second moteur financier.
CREATE OR REPLACE FUNCTION public.entrepot_commander(p_requete uuid,p_acteur text,p_ressource text,p_quantite integer,p_fournisseur_type text,p_fournisseur_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $commande$
DECLARE prm jsonb; v jsonb;
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 prm:=jsonb_build_object('ressource',p_ressource,'quantite',p_quantite,'type',p_fournisseur_type,'fournisseur',p_fournisseur_id);
 v:=public.achat_requete_ouvrir_interne(p_acteur,p_requete,'entrepot_commander',prm);
 IF v IS NOT NULL THEN RETURN v;END IF;
 v:=public.entrepot_commander(p_acteur,p_ressource,p_quantite,p_fournisseur_type,p_fournisseur_id);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
 RETURN public.achat_requete_clore_interne(p_acteur,p_requete,'entrepot_commander',prm,v);
END $commande$;
REVOKE ALL ON FUNCTION public.entrepot_commander(text,text,integer,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.entrepot_commander(uuid,text,text,integer,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.entrepot_commander(uuid,text,text,integer,text,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.offre_achat_publier(p_requete uuid,p_type text,p_organisation text,p_ressource text,p_quantite integer,p_prix numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $versionnee$
DECLARE acteur text:=public.mon_personnage();prm jsonb;v jsonb;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 prm:=jsonb_build_object('p_type',p_type,'p_organisation',p_organisation,'p_ressource',p_ressource,'p_quantite',p_quantite,'p_prix',p_prix);
 v:=public.achat_requete_ouvrir_interne(acteur,p_requete,'offre_achat_publier',prm);
 IF v IS NOT NULL THEN RETURN v;END IF;
 v:=public.offre_achat_publier(p_type,p_organisation,p_ressource,p_quantite,p_prix);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
 RETURN public.achat_requete_clore_interne(acteur,p_requete,'offre_achat_publier',prm,v);
END $versionnee$;
REVOKE ALL ON FUNCTION public.offre_achat_publier(text,text,text,integer,numeric) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.offre_achat_publier(uuid,text,text,text,integer,numeric) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.offre_achat_publier(uuid,text,text,text,integer,numeric) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.offre_achat_retirer(p_requete uuid,p_offre uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $versionnee$
DECLARE acteur text:=public.mon_personnage();prm jsonb;v jsonb;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 prm:=jsonb_build_object('p_offre',p_offre);
 v:=public.achat_requete_ouvrir_interne(acteur,p_requete,'offre_achat_retirer',prm);
 IF v IS NOT NULL THEN RETURN v;END IF;
 v:=public.offre_achat_retirer(p_offre);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
 RETURN public.achat_requete_clore_interne(acteur,p_requete,'offre_achat_retirer',prm,v);
END $versionnee$;
REVOKE ALL ON FUNCTION public.offre_achat_retirer(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.offre_achat_retirer(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.offre_achat_retirer(uuid,uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.offre_achat_servir(p_requete uuid,p_offre uuid,p_quantite integer,p_source text,p_organisation text,p_fonds text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $versionnee$
DECLARE acteur text:=public.mon_personnage();prm jsonb;v jsonb;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 prm:=jsonb_build_object('p_offre',p_offre,'p_quantite',p_quantite,'p_source',p_source,'p_organisation',p_organisation,'p_fonds',p_fonds);
 v:=public.achat_requete_ouvrir_interne(acteur,p_requete,'offre_achat_servir',prm);
 IF v IS NOT NULL THEN RETURN v;END IF;
 v:=public.offre_achat_servir(p_offre,p_quantite,p_source,p_organisation,p_fonds);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
 RETURN public.achat_requete_clore_interne(acteur,p_requete,'offre_achat_servir',prm,v);
END $versionnee$;
REVOKE ALL ON FUNCTION public.offre_achat_servir(uuid,integer,text,text,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.offre_achat_servir(uuid,uuid,integer,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.offre_achat_servir(uuid,uuid,integer,text,text,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.trading_acheter(p_requete uuid,p_organisation text,p_entrepot text,p_ressource text,p_quantite integer,p_livraison text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $versionnee$
DECLARE acteur text:=public.mon_personnage();prm jsonb;v jsonb;
BEGIN
 IF acteur IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie');END IF;
 prm:=jsonb_build_object('p_organisation',p_organisation,'p_entrepot',p_entrepot,'p_ressource',p_ressource,'p_quantite',p_quantite,'p_livraison',p_livraison);
 v:=public.achat_requete_ouvrir_interne(acteur,p_requete,'trading_acheter',prm);
 IF v IS NOT NULL THEN RETURN v;END IF;
 v:=public.trading_acheter(p_organisation,p_entrepot,p_ressource,p_quantite,p_livraison);
 IF NOT coalesce((v->>'ok')::boolean,false) THEN RETURN v;END IF;
 RETURN public.achat_requete_clore_interne(acteur,p_requete,'trading_acheter',prm,v);
END $versionnee$;
REVOKE ALL ON FUNCTION public.trading_acheter(text,text,text,integer,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.trading_acheter(uuid,text,text,text,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.trading_acheter(uuid,text,text,text,integer,text) TO authenticated,service_role;

-- La fixation des prix coûtait 1 PA dans un appel séparé, avant de pouvoir être refusée.
-- Même enveloppe transactionnelle que les achats, sans deuxième prélèvement côté écran.
CREATE OR REPLACE FUNCTION public.fixer_prix_entrepot(p_requete uuid,p_acteur text,p_pays text,p_prix jsonb,p_pa integer DEFAULT 1,p_cost integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $prix$
DECLARE prm jsonb;v jsonb;d text;
BEGIN
 PERFORM public.exiger_acteur(p_acteur);
 prm:=jsonb_build_object('pays',p_pays,'prix',p_prix,'pa',p_pa,'cost',p_cost);
 v:=public.achat_requete_ouvrir_interne(p_acteur,p_requete,'fixer_prix_entrepot',prm);
 IF v IS NOT NULL THEN RETURN v;END IF;
 BEGIN
  v:=public.fixer_prix_entrepot(p_acteur,p_pays,p_prix);
  IF NOT coalesce((v->>'ok')::boolean,false) THEN RAISE EXCEPTION 'prix_refuses' USING ERRCODE='HG001',DETAIL=v::text;END IF;
  v:=v||jsonb_build_object('paiement',public.payer_ordre(p_acteur,'fixer_prix_achat_entrepot',p_pa,p_cost));
  IF NOT coalesce((v->'paiement'->>'ok')::boolean,false) THEN RAISE EXCEPTION 'prix_paiement_refuse' USING ERRCODE='HG001',DETAIL=(v->'paiement')::text;END IF;
 EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d=PG_EXCEPTION_DETAIL;RETURN d::jsonb;
 END;
 RETURN public.achat_requete_clore_interne(p_acteur,p_requete,'fixer_prix_entrepot',prm,v);
END $prix$;
REVOKE ALL ON FUNCTION public.fixer_prix_entrepot(text,text,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.fixer_prix_entrepot(uuid,text,text,jsonb,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fixer_prix_entrepot(uuid,text,text,jsonb,integer,integer) TO authenticated,service_role;
