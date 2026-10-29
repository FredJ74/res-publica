-- =====================================================================================
-- LOGEMENTS SOCIAUX COMMUNAUX (29/10/2026, Claude). NON APPLIQUÉE — application par ChatGPT,
-- APRÈS 20261029210000 (achat de terrain par la commune). Compatible avec l'écran en ligne.
--
-- Décisions de Fred :
--  - trois bâtiments, réservés aux terrains de la commune (achetés par le maire avec la caisse de
--    la mairie) ; la surface fixe le plus grand type permis, on peut toujours construire plus petit :
--      petit bâtiment  : 4 appartements,  12 jours, 60 000 FR  (toute surface)
--      bâtiment moyen  : 6 appartements,  18 jours, 90 000 FR  (2 000 m² et plus)
--      barre d'immeuble: 10 appartements, 24 jours, 120 000 FR (plus de 2 200 m²)
--  - comme à Montrouge : moitié petits (30 FR, sommeil +3 moral / +4 santé), moitié grands
--    (60 FR, +5 / +7), loyers versés à la caisse de la mairie, attribution par l'adjoint aux
--    résidents de la ville ; mécanique du socle, toutes villes ;
--  - le maire élu dépose le permis d'un terrain de la commune (la commune n'est jamais « moi ») ;
--  - l'adjoint fixe le loyer appartement par appartement (« ça ouvre la voie à des scandales ») ;
--    chaque changement est inscrit dans l'historique du bâtiment ; tableau de bord de l'adjoint.
--
-- Moteurs réutilisés : chantiers_paliers / chantier_lancer / chantier_commande (réception),
-- chantier_plan_normaliser_interne (lots), location_lot_enregistrer_interne + prelever_loyer_bail
-- (bail et premier loyer ; le loyer d'un lot de la commune va déjà à recette_municipale),
-- logements_demandes / logements_attributions_historique (files existantes de Montrouge).
-- Le joueur ne loue jamais lui-même un logement social : seul l'adjoint l'attribue.
-- Corrections en place : chaque fragment remplacé doit exister une seule fois.
-- =====================================================================================

-- 1. Attestation des écritures de bail faites par l'adjoint (même principe que prets_ecritures_internes).
CREATE TABLE IF NOT EXISTS public.logements_sociaux_internes (
  transaction_id bigint NOT NULL, bail_id text NOT NULL, PRIMARY KEY (transaction_id, bail_id));
ALTER TABLE public.logements_sociaux_internes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.logements_sociaux_internes FROM PUBLIC, anon, authenticated;

-- 2. Trois paliers, même barème que les autres (5 000 FR/jour, 30 % matériaux, apport 35 %).
INSERT INTO public.chantiers_paliers(palier,label,duree_jours,cout_total,cout_materiaux,cout_travail,heures_totales,apport_minimal,gabarit)
SELECT v.palier, v.label, v.j, v.j*5000, v.j*1500, v.j*3500, v.j*50, v.j*1750,
       p.gabarit || jsonb_build_object('niveau',v.palier,'dureeJours',v.j,'coutTotal',v.j*5000,'coutMateriaux',v.j*1500,'coutTravail',v.j*3500,'heuresTotales',v.j*50)
  FROM (VALUES ('logements_petit','Logements sociaux — petit bâtiment',12),
               ('logements_moyen','Logements sociaux — bâtiment moyen',18),
               ('logements_barre','Logements sociaux — barre d''immeuble',24)) v(palier,label,j)
  CROSS JOIN (SELECT gabarit FROM public.chantiers_paliers WHERE palier='commerce_standard') p
 WHERE NOT EXISTS (SELECT 1 FROM public.chantiers_paliers x WHERE x.palier=v.palier);

-- 3. Appartements générés à la réception (aucun plan de découpage pour ces bâtiments).
CREATE OR REPLACE FUNCTION public.logements_sociaux_lots_interne(p_niveau text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE n int := CASE p_niveau WHEN 'logements_petit' THEN 4 WHEN 'logements_moyen' THEN 6 WHEN 'logements_barre' THEN 10 END;
  sortie jsonb := '[]'; i int;
BEGIN
  IF n IS NULL THEN RAISE EXCEPTION 'palier_invalide'; END IF;
  FOR i IN 1..n/2 LOOP
    sortie := sortie || jsonb_build_array(jsonb_build_object('id','logement-petit-'||i,'label','Petit appartement n°'||i,'surface',45,
      'destination','logement_social','typeLogement','petit','locataire',NULL,'loyer',30,'logementSocial',true,'bonusMoralSommeil',3,'bonusSanteSommeil',4));
  END LOOP;
  FOR i IN 1..n/2 LOOP
    sortie := sortie || jsonb_build_array(jsonb_build_object('id','logement-grand-'||i,'label','Grand appartement n°'||i,'surface',75,
      'destination','logement_social','typeLogement','grand','locataire',NULL,'loyer',60,'logementSocial',true,'bonusMoralSommeil',5,'bonusSanteSommeil',7));
  END LOOP;
  RETURN sortie;
END;
$function$;
REVOKE ALL ON FUNCTION public.logements_sociaux_lots_interne(text) FROM PUBLIC, anon, authenticated;

-- Le titulaire est-il une commune, ou le compromis est-il signé pour une commune ?
CREATE OR REPLACE FUNCTION public.logements_sociaux_terrain_communal(p_etat jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT coalesce(p_etat->>'proprietaire','') LIKE 'ville:%' OR coalesce(p_etat->>'acquisitionAcquereur','') LIKE 'ville:%' $$;

-- Ville administrée par l'adjoint au maire attesté (NULL sinon).
CREATE OR REPLACE FUNCTION public.logements_sociaux_ville_adjoint(p_nom text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT CASE WHEN d.poste->>'id'='maire_adjoint' AND public.poste_est_atteste(d.name,d.poste,d.country) THEN nullif(d.poste->>'city','') END
        FROM public.personnages_donnees d WHERE d.name = p_nom $$;
REVOKE ALL ON FUNCTION public.logements_sociaux_ville_adjoint(text) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE d text; i int; f text; frag text[];
BEGIN
  -- 4. Réception : les lots d'un bâtiment de logements sont générés, pas dessinés.
  d := pg_get_functiondef('public.chantier_plan_normaliser_interne'::regproc);
  IF position('logements_sociaux_lots_interne' IN d) = 0 THEN
    frag := ARRAY['BEGIN
 IF jsonb_typeof(p_plan) IS DISTINCT FROM ''array''',
                  'BEGIN
 IF p_niveau IN(''logements_petit'',''logements_moyen'',''logements_barre'') THEN RETURN public.logements_sociaux_lots_interne(p_niveau);END IF;
 IF jsonb_typeof(p_plan) IS DISTINCT FROM ''array'''];
    IF (length(d)-length(replace(d,frag[1],'')))/length(frag[1]) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_normaliser'; END IF;
    EXECUTE replace(d, frag[1], frag[2]);
  END IF;

  -- 5. Permis : trois paliers de plus, réservés à la commune, plafonnés par la surface.
  d := pg_get_functiondef('public.terrain_permis_deposer(text,text,uuid)'::regprocedure);
  IF position('logements_reserves_commune' IN d) = 0 THEN
    frag := ARRAY[
     'WHEN ''building'' THEN 7 END;',
     'WHEN ''building'' THEN 7 WHEN ''logements_petit'' THEN 4 WHEN ''logements_moyen'' THEN 6 WHEN ''logements_barre'' THEN 7 END;',
     ' IF public.titulaire_est_moi(etat->>''proprietaire'') IS NOT TRUE THEN',
     ' IF p_palier LIKE ''logements_%'' THEN
  IF NOT public.logements_sociaux_terrain_communal(etat) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''logements_reserves_commune'');END IF;
  IF (p_palier=''logements_moyen'' AND coalesce((etat->>''surface'')::numeric,0)<2000) OR (p_palier=''logements_barre'' AND coalesce((etat->>''surface'')::numeric,0)<=2200) THEN RETURN jsonb_build_object(''ok'',false,''raison'',''terrain_trop_petit'');END IF;
 END IF;
 IF public.titulaire_est_moi(etat->>''proprietaire'') IS NOT TRUE AND NOT (etat->>''proprietaire''=''ville:''||pays||'':''||ville AND (SELECT c.data::jsonb->>''eluId'' FROM public.cycles_electoraux c WHERE c.country=pays AND c.poste_id=''maire'' AND c.city=ville) IS NOT DISTINCT FROM acteur) THEN',
     'WHEN ''commerce_premium'' THEN ''Commerce premium'' ELSE ''Building'' END,',
     'WHEN ''commerce_premium'' THEN ''Commerce premium'' WHEN ''logements_petit'' THEN ''Logements sociaux — petit bâtiment'' WHEN ''logements_moyen'' THEN ''Logements sociaux — bâtiment moyen'' WHEN ''logements_barre'' THEN ''Logements sociaux — barre d''''immeuble'' ELSE ''Building'' END,'];
    FOR i IN 1..array_length(frag,1)/2 LOOP
      IF (length(d)-length(replace(d,frag[2*i-1],'')))/length(frag[2*i-1]) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_permis_%', i; END IF;
      d := replace(d, frag[2*i-1], frag[2*i]);
    END LOOP;
    EXECUTE d;
  END IF;

  d := pg_get_functiondef('public.terrain_permis_decider(text,boolean,text,uuid)'::regprocedure);
  IF position('logements_petit' IN d) = 0 THEN
    f := 'WHEN ''building'' THEN ''Building'' ELSE coalesce(pm->>''palierDemande'','''') END;';
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_decider'; END IF;
    EXECUTE replace(d, f, 'WHEN ''building'' THEN ''Building'' WHEN ''logements_petit'' THEN ''Logements sociaux — petit bâtiment'' WHEN ''logements_moyen'' THEN ''Logements sociaux — bâtiment moyen'' WHEN ''logements_barre'' THEN ''Logements sociaux — barre d''''immeuble'' ELSE coalesce(pm->>''palierDemande'','''') END;');
  END IF;

  d := pg_get_functiondef('public.terrain_acquisition_commande(text,text,jsonb,uuid)'::regprocedure);
  IF position('logements_petit' IN d) = 0 THEN
    f := 'permis NOT IN(''hangar'',''commerce_standard'',''commerce_premium'',''building'')';
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_acquisition'; END IF;
    EXECUTE replace(d, f, 'permis NOT IN(''hangar'',''commerce_standard'',''commerce_premium'',''building'',''logements_petit'',''logements_moyen'',''logements_barre'')');
  END IF;

  -- 6. Un logement social ne se loue pas soi-même : seul l'adjoint l'attribue.
  d := pg_get_functiondef('public.location_lot_enregistrer_interne'::regproc);
  IF position('logement_attribue_par_adjoint' IN d) = 0 THEN
    f := 'idb:=p_pays||'':''||p_batiment||'':''||piece||'':''||(p_etat->>''city'');';
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_location_lot'; END IF;
    EXECUTE replace(d, f, f||'
 IF lot->>''destination''=''logement_social'' AND NOT EXISTS(SELECT 1 FROM public.logements_sociaux_internes x WHERE x.transaction_id=txid_current() AND x.bail_id=idb) THEN RAISE EXCEPTION ''logement_attribue_par_adjoint'';END IF;');
  END IF;

  d := pg_get_functiondef('public.location_lot_ecriture_attester'::regproc);
  IF position('logements_sociaux_internes' IN d) = 0 THEN
    f := 'IF public.est_appel_serveur() THEN RETURN NEW;END IF;';
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_garde_bail'; END IF;
    EXECUTE replace(d, f, f||'
 IF EXISTS(SELECT 1 FROM public.logements_sociaux_internes x WHERE x.transaction_id=txid_current() AND x.bail_id=NEW.id) THEN RETURN NEW;END IF;');
  END IF;

  -- 7. Le loyer d'un logement social est fixé par l'adjoint, jamais par le titulaire des murs.
  d := pg_get_functiondef('public.terrain_lot_loyer_fixer(text,text,integer)'::regprocedure);
  IF position('loyer_fixe_par_adjoint' IN d) = 0 THEN
    f := 'SELECT value INTO lot FROM jsonb_array_elements(coalesce(etat->''subdivisions'',''[]'')) WHERE value->>''id'' = p_lot;';
    IF (length(d)-length(replace(d,f,'')))/length(f) <> 1 THEN RAISE EXCEPTION 'fragment_introuvable_loyer_lot'; END IF;
    EXECUTE replace(d, f, f||'
  IF lot->>''destination'' = ''logement_social'' THEN RETURN jsonb_build_object(''ok'', false, ''raison'', ''loyer_fixe_par_adjoint''); END IF;');
  END IF;
END $$;

-- 8. Offre et demande d'un résident (toutes villes dotées de logements sociaux).
CREATE OR REPLACE FUNCTION public.logements_sociaux_ville_a_offre(p_pays text, p_ville text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT (p_pays = 'republic' AND p_ville = 'ville_b') OR EXISTS (
         SELECT 1 FROM public.terrains_etat t, jsonb_array_elements(coalesce(t.data::jsonb->'subdivisions','[]')) l
          WHERE t.country = p_pays AND t.data::jsonb->>'city' = p_ville
            AND t.data::jsonb->>'proprietaire' = 'ville:'||p_pays||':'||p_ville
            AND l->>'destination' = 'logement_social') $$;
REVOKE ALL ON FUNCTION public.logements_sociaux_ville_a_offre(text,text) FROM PUBLIC, anon, authenticated;

-- L'écran l'interroge au clic, pour répondre tout de suite « Il n'y a pas de logements sociaux dans la ville. »
CREATE OR REPLACE FUNCTION public.logements_sociaux_offre()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$ SELECT jsonb_build_object('ok', true, 'offre', public.logements_sociaux_ville_a_offre(p.country, p.current_city))
        FROM public.personnages_donnees p WHERE p.name = public.mon_personnage() $$;
REVOKE ALL ON FUNCTION public.logements_sociaux_offre() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logements_sociaux_offre() TO authenticated;

CREATE OR REPLACE FUNCTION public.logement_social_demander(p_type text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; r jsonb; v_id text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_type IS NOT NULL AND p_type NOT IN ('petit','grand') THEN RETURN jsonb_build_object('ok',false,'raison','parametres_invalides'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi FOR UPDATE;
  IF p.current_building NOT IN ('mairie','mairie-capitale') THEN RETURN jsonb_build_object('ok',false,'raison','pas_a_la_mairie'); END IF;
  IF NOT public.logements_sociaux_ville_a_offre(p.country, p.current_city) THEN
    RETURN jsonb_build_object('ok',false,'raison','aucun_logement_social'); END IF;
  IF p.domicile->>'country' IS DISTINCT FROM p.country OR p.domicile->>'city' IS DISTINCT FROM p.current_city THEN
    RETURN jsonb_build_object('ok',false,'raison','residence_requise'); END IF;
  IF EXISTS (SELECT 1 FROM public.logements_demandes WHERE country = p.country AND ville = p.current_city AND demandeur = moi AND statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok',false,'raison','demande_deja_en_cours'); END IF;
  r := public.payer_ordre(moi, 'demander_logement_social', 1, 0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RETURN r; END IF;
  v_id := 'demande-logement-'||p.current_city||'-'||regexp_replace(moi,'[^a-zA-Z0-9]','','g')||'-'||floor(extract(epoch FROM clock_timestamp())*1000);
  INSERT INTO public.logements_demandes(id, country, ville, demandeur, type_souhaite, statut)
    VALUES (v_id, p.country, p.current_city, moi, p_type, 'en_attente');
  RETURN r || jsonb_build_object('ok',true,'demandeId',v_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.logement_social_demander(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logement_social_demander(text) TO authenticated;

-- 9. Attribution par l'adjoint : bail au nom du demandeur, premier loyer payé par lui.
CREATE OR REPLACE FUNCTION public.logement_social_attribuer(p_terrain text, p_lot text, p_demande text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); ville text; t record; e jsonb; lot jsonb; dm record; idb text; jour int;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  ville := public.logements_sociaux_ville_adjoint(moi);
  IF ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','reserve_adjoint'); END IF;
  SELECT * INTO t FROM public.terrains_etat WHERE building_id = p_terrain AND country = (SELECT country FROM public.personnages_donnees WHERE name = moi) FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb;
  IF e->>'city' IS DISTINCT FROM ville OR e->>'proprietaire' IS DISTINCT FROM 'ville:'||t.country||':'||ville THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_commune'); END IF;
  SELECT value INTO lot FROM jsonb_array_elements(coalesce(e->'subdivisions','[]')) WHERE value->>'id' = p_lot;
  IF lot IS NULL OR lot->>'destination' IS DISTINCT FROM 'logement_social' THEN RETURN jsonb_build_object('ok',false,'raison','logement_introuvable'); END IF;
  SELECT * INTO dm FROM public.logements_demandes WHERE id = p_demande FOR UPDATE;
  IF NOT FOUND OR dm.statut <> 'en_attente' OR dm.country <> t.country OR dm.ville <> ville THEN RETURN jsonb_build_object('ok',false,'raison','demande_introuvable'); END IF;
  idb := t.country||':'||t.building_id||':lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g')||':'||ville;
  SELECT coalesce(day,1) INTO jour FROM public.personnages_donnees WHERE name = dm.demandeur;
  BEGIN
    INSERT INTO public.logements_sociaux_internes VALUES (txid_current(), idb) ON CONFLICT DO NOTHING;
    e := public.location_lot_enregistrer_interne(e, t.country, t.building_id, p_lot, dm.demandeur, jour);
    UPDATE public.locations_actives SET data = data || jsonb_build_object('logementSocial',true,'typeLogement',lot->'typeLogement',
        'bonusMoralSommeil',lot->'bonusMoralSommeil','bonusSanteSommeil',lot->'bonusSanteSommeil','orgaAutorisee',false,'attribuePar',moi)
     WHERE id = idb;
  EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('ok',false,'raison',CASE WHEN SQLERRM IN ('premier_loyer_refuse','local_occupe','loyer_non_fixe','lot_en_travaux') THEN SQLERRM ELSE 'attribution_refusee' END);
  END;
  PERFORM public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('subdivisions',e->'subdivisions','lotsHistorique',
    coalesce(e->'lotsHistorique','[]')||jsonb_build_array(jsonb_build_object('acte','attribution_sociale','acteur',moi,'lot',p_lot,'beneficiaire',dm.demandeur,'date',statement_timestamp()))), t.country);
  UPDATE public.logements_demandes SET statut = 'attribuee', room_id_attribue = 'lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g') WHERE id = p_demande;
  INSERT INTO public.logements_attributions_historique(id, country, ville, room_id, beneficiaire, autorite)
    VALUES ('attrib-'||t.building_id||'-'||p_lot||'-'||floor(extract(epoch FROM clock_timestamp())*1000), t.country, ville, t.building_id||'/'||p_lot, dm.demandeur, moi);
  PERFORM public.mail_systeme_poser_interne('Mairie', dm.demandeur, 'Logement social attribué',
    'Un logement social vous a été attribué : '||(lot->>'label')||'. Loyer : '||(lot->>'loyer')||' FR par échéance, versé à la commune.', NULL);
  RETURN jsonb_build_object('ok',true,'bail',idb,'beneficiaire',dm.demandeur);
END;
$function$;
REVOKE ALL ON FUNCTION public.logement_social_attribuer(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logement_social_attribuer(text,text,text) TO authenticated;

-- 10. Loyer fixé par l'adjoint, appartement par appartement, occupé ou non ; historique gardé.
CREATE OR REPLACE FUNCTION public.logement_social_loyer_fixer(p_terrain text, p_lot text, p_loyer integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); ville text; t record; e jsonb; lot jsonb; x jsonb; sortie jsonb := '[]'; idb text; ancien numeric;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  ville := public.logements_sociaux_ville_adjoint(moi);
  IF ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','reserve_adjoint'); END IF;
  IF p_loyer IS NULL OR p_loyer < 1 OR p_loyer > 100000 THEN RETURN jsonb_build_object('ok',false,'raison','loyer_invalide'); END IF;
  SELECT * INTO t FROM public.terrains_etat WHERE building_id = p_terrain AND country = (SELECT country FROM public.personnages_donnees WHERE name = moi) FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  e := t.data::jsonb;
  IF e->>'city' IS DISTINCT FROM ville OR e->>'proprietaire' IS DISTINCT FROM 'ville:'||t.country||':'||ville THEN
    RETURN jsonb_build_object('ok',false,'raison','hors_commune'); END IF;
  SELECT value INTO lot FROM jsonb_array_elements(coalesce(e->'subdivisions','[]')) WHERE value->>'id' = p_lot;
  IF lot IS NULL OR lot->>'destination' IS DISTINCT FROM 'logement_social' THEN RETURN jsonb_build_object('ok',false,'raison','logement_introuvable'); END IF;
  ancien := (lot->>'loyer')::numeric;
  FOR x IN SELECT value FROM jsonb_array_elements(e->'subdivisions') LOOP
    sortie := sortie || jsonb_build_array(CASE WHEN x->>'id' = p_lot THEN x || jsonb_build_object('loyer', p_loyer) ELSE x END);
  END LOOP;
  IF nullif(lot->>'locataire','') IS NOT NULL THEN
    idb := t.country||':'||t.building_id||':lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g')||':'||ville;
    INSERT INTO public.logements_sociaux_internes VALUES (txid_current(), idb) ON CONFLICT DO NOTHING;
    UPDATE public.locations_actives SET data = data || jsonb_build_object('prix', p_loyer) WHERE id = idb;
  END IF;
  PERFORM public.terrain_etat_fusionner_interne(t.id, jsonb_build_object('subdivisions', sortie, 'lotsHistorique',
    coalesce(e->'lotsHistorique','[]')||jsonb_build_array(jsonb_build_object('acte','loyer_social','acteur',moi,'lot',p_lot,'ancien',ancien,'nouveau',p_loyer,'date',statement_timestamp()))), t.country);
  RETURN jsonb_build_object('ok',true,'lot',p_lot,'ancien',ancien,'loyer',p_loyer,'occupe',idb IS NOT NULL);
END;
$function$;
REVOKE ALL ON FUNCTION public.logement_social_loyer_fixer(text,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logement_social_loyer_fixer(text,text,integer) TO authenticated;

-- 11. Tableau de bord de l'adjoint : appartements de la commune et demandes en attente.
CREATE OR REPLACE FUNCTION public.logements_sociaux_tableau()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); v_ville text; pays text;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  v_ville := public.logements_sociaux_ville_adjoint(moi);
  IF v_ville IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','reserve_adjoint'); END IF;
  SELECT country INTO pays FROM public.personnages_donnees WHERE name = moi;
  RETURN jsonb_build_object('ok',true,'ville',v_ville,'pays',pays,'logementsMontrouge',(pays='republic' AND v_ville='ville_b'),
    'appartements', coalesce((SELECT jsonb_agg(jsonb_build_object('terrain',t.building_id,'lot',l->>'id','label',l->>'label','type',l->>'typeLogement',
         'loyer',(l->>'loyer')::numeric,'locataire',nullif(l->>'locataire',''),'batiment',t.data::jsonb->>'niveau_construction') ORDER BY t.building_id, l->>'id')
       FROM public.terrains_etat t, jsonb_array_elements(coalesce(t.data::jsonb->'subdivisions','[]')) l
      WHERE t.country = pays AND t.data::jsonb->>'city' = v_ville AND t.data::jsonb->>'proprietaire' = 'ville:'||pays||':'||v_ville
        AND l->>'destination' = 'logement_social'), '[]'),
    'demandes', coalesce((SELECT jsonb_agg(jsonb_build_object('id',d.id,'demandeur',d.demandeur,'type',d.type_souhaite,'depuis',d.created_at) ORDER BY d.created_at)
       FROM public.logements_demandes d WHERE d.country = pays AND d.ville = v_ville AND d.statut = 'en_attente'), '[]'));
END;
$function$;
REVOKE ALL ON FUNCTION public.logements_sociaux_tableau() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.logements_sociaux_tableau() TO authenticated;
