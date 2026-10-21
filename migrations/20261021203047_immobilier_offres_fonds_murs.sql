-- #66 PREPAREE UNIQUEMENT : aucune application en production autorisee.
-- Raccordements vers terrains_etat/entreprises, jamais de nouveaux titres ou caisses paralleles.
BEGIN;
-- GARDE DES FONCTIONS NOUVELLES #66
DO $g$ DECLARE h text;BEGIN
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_ref_pj(text)');IF h IS NOT NULL AND h<>'c8ccbb1575a224b3aa174caa8d9e3fde' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_ref_pj';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_titulaire(text,text)');IF h IS NOT NULL AND h<>'879ac2a5a48b7354052a04e39df794c7' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_titulaire';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_occupant(text)');IF h IS NOT NULL AND h<>'498f1bd020ddb0bff6f9d5a5a7a535ac' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_occupant';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_raccorder_pnj()');IF h IS NOT NULL AND h<>'f3598a021c447e42642043c778ce5462' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_raccorder_pnj';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_offre_deposer(text,text,text,text)');IF h IS NOT NULL AND h<>'55155472e7f0bbf469e19f086d766d7e' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_offre_deposer';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_priorites_publier()');IF h IS NOT NULL AND h<>'c4af6a11f2af57a91ebb5cff51764c89' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_priorites_publier';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_priorite_refuser(text)');IF h IS NOT NULL AND h<>'549f6cf542d5c2eb232de05d549bb0db' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_priorite_refuser';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_catalogue(text)');IF h IS NOT NULL AND h<>'5502ac2c106b5e5762aceaaa82f561f7' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_catalogue';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.vendre_fonds_commerce(text,text,text,int4,bool)');IF h IS NOT NULL AND h<>'0d2ee8ea2c56c8121efac1c8f95f62e9' THEN RAISE EXCEPTION 'definition_non_examinee: vendre_fonds_commerce';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_acte_finaliser(text,text[])');IF h IS NOT NULL AND h<>'01ae556e2c0c2ab0e7425580f758f63b' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_acte_finaliser';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_titre_proteger()');IF h IS NOT NULL AND h<>'d1951e6b03191acf276da74b4aa01992' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_titre_proteger';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_bail_serialiser()');IF h IS NOT NULL AND h<>'1ff311d413ae9f2da5f6aaf03944e6ba' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_bail_serialiser';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_biens_lire(text)');IF h IS NOT NULL AND h<>'c9d5066483a2baa42665b123f6d1b9d2' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_biens_lire';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_acte_etat(text)');IF h IS NOT NULL AND h<>'5f21c208ef92586e164f84bfcca7d462' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_acte_etat';END IF;
SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.immobilier_references_publier()');IF h IS NOT NULL AND h<>'cd5cb84c8c1641b43a6a6324e53662b6' THEN RAISE EXCEPTION 'definition_non_examinee: immobilier_references_publier';END IF;
END;$g$;
-- FIN GARDE #66









CREATE TABLE IF NOT EXISTS public.immobilier_tarifs_pays(pays text PRIMARY KEY,prix_m2 numeric NOT NULL CHECK(prix_m2>=0));
INSERT INTO public.immobilier_tarifs_pays VALUES('republic',150) ON CONFLICT DO NOTHING;
DO $$BEGIN IF (SELECT prix_m2 FROM public.immobilier_tarifs_pays WHERE pays='republic')<>150 THEN RAISE EXCEPTION 'bareme_existant_divergent';END IF;END$$;
CREATE TABLE IF NOT EXISTS public.immobilier_biens(
 id text PRIMARY KEY,pays text NOT NULL,ville text NOT NULL,building_id text NOT NULL,
 terrain_id text NOT NULL REFERENCES public.terrains_etat(id),entreprise_id text REFERENCES public.entreprises(id),
 surface numeric CHECK(surface>0),UNIQUE(pays,ville,building_id),UNIQUE(terrain_id),UNIQUE(entreprise_id));
CREATE TABLE IF NOT EXISTS public.immobilier_surfaces_validees(
 pays text,ville text,building_id text,surface numeric NOT NULL CHECK(surface>0),PRIMARY KEY(pays,ville,building_id));
INSERT INTO public.immobilier_surfaces_validees VALUES('republic','capitale','hotel-republica',1200) ON CONFLICT DO NOTHING;
DO $$BEGIN IF (SELECT surface FROM public.immobilier_surfaces_validees WHERE pays='republic' AND ville='capitale' AND building_id='hotel-republica')<>1200 THEN RAISE EXCEPTION 'surface_validee_divergente';END IF;END$$;
CREATE TABLE IF NOT EXISTS public.immobilier_offres(
 id text PRIMARY KEY,bien_id text NOT NULL REFERENCES public.immobilier_biens(id),actif text NOT NULL CHECK(actif IN('fonds','murs')),
 vendeur text NOT NULL,prix numeric NOT NULL CHECK(prix>=0 AND prix=trunc(prix)),regime text NOT NULL CHECK(regime IN('reference','libre_pj')),
 statut text NOT NULL CHECK(statut IN('priorite','disponible','vendue')),beneficiaire text,notifie_le timestamptz,priorite_fin timestamptz,
 refus_le timestamptz,publication_le timestamptz,acheteur text,created_at timestamptz NOT NULL DEFAULT now());
CREATE UNIQUE INDEX IF NOT EXISTS immobilier_offre_active ON public.immobilier_offres(bien_id,actif) WHERE statut<>'vendue';
CREATE TABLE IF NOT EXISTS public.immobilier_actes(
 acteur text,requete text,offres text[] NOT NULL,bien_id text NOT NULL,transaction_id bigint NOT NULL,
 verdict jsonb,created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(acteur,requete));
-- Les lectures passent par le catalogue : une offre prioritaire n'est jamais publiee aux tiers.
ALTER TABLE public.immobilier_tarifs_pays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.immobilier_biens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.immobilier_surfaces_validees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.immobilier_offres ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.immobilier_actes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.immobilier_tarifs_pays,public.immobilier_biens,public.immobilier_surfaces_validees,public.immobilier_offres,public.immobilier_actes FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.immobilier_ref_pj(p_ref text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$
 SELECT CASE WHEN left(p_ref,3)='pj:' THEN substr(p_ref,4) WHEN p_ref='PNJ' OR left(p_ref,5)='orga:' OR left(p_ref,6)='ville:' THEN NULL ELSE nullif(p_ref,'') END;
$$;
CREATE OR REPLACE FUNCTION public.immobilier_titulaire(p_bien text,p_actif text) RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.immobilier_biens%rowtype;t public.terrains_etat%rowtype;v text;
BEGIN
 SELECT * INTO b FROM public.immobilier_biens WHERE id=p_bien;
 IF NOT FOUND THEN RETURN NULL;END IF;
 IF p_actif='fonds' THEN SELECT data->>'proprietaire' INTO v FROM public.entreprises WHERE id=b.entreprise_id;RETURN v;END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE id=b.terrain_id;
 IF t.proprietaire IS DISTINCT FROM t.data::jsonb->>'proprietaire' AND NOT coalesce(public.immobilier_ref_pj(t.proprietaire)=public.immobilier_ref_pj(t.data::jsonb->>'proprietaire'),false) THEN RAISE EXCEPTION 'titres_murs_divergents';END IF;
 RETURN t.proprietaire;
END;$$;
CREATE OR REPLACE FUNCTION public.immobilier_occupant(p_bien text) RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.immobilier_biens%rowtype;liste text[];
BEGIN
 SELECT * INTO STRICT b FROM public.immobilier_biens WHERE id=p_bien;
 SELECT array_agg(DISTINCT data->>'locataire') INTO liste FROM public.locations_actives
 WHERE country=b.pays AND data->>'city'=b.ville AND data->>'buildingId'=b.building_id
 AND nullif(data->>'locataire','') IS NOT NULL AND coalesce(data->>'chambreClinique','false')<>'true';
 IF cardinality(liste)>1 THEN RAISE EXCEPTION 'occupation_multiple_a_raccorder';END IF;
 RETURN liste[1];
END;$$;
-- Initialisation explicite par le serveur, pas au passage d'un navigateur, pas de donnees reelles dans le DDL.
CREATE OR REPLACE FUNCTION public.immobilier_raccorder_pnj() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE e record;t record;cle text;titre text;s numeric;n integer:=0;
BEGIN
 IF NOT public.est_appel_serveur() THEN RAISE EXCEPTION 'serveur_requis' USING ERRCODE='42501';END IF;
 FOR e IN SELECT id,data FROM public.entreprises WHERE data->>'proprietaire'='PNJ' ORDER BY id LOOP
  IF nullif(e.data->>'country','') IS NULL OR nullif(e.data->>'city','') IS NULL OR nullif(e.data->>'buildingId','') IS NULL THEN CONTINUE;END IF;
  IF (SELECT count(*) FROM public.entreprises WHERE data->>'country'=e.data->>'country' AND data->>'city'=e.data->>'city' AND data->>'buildingId'=e.data->>'buildingId')<>1 THEN CONTINUE;END IF;
  cle:=(e.data->>'country')||':'||(e.data->>'city')||':'||(e.data->>'buildingId');
  PERFORM pg_advisory_xact_lock(hashtextextended('immobilier:'||cle,0));
  IF EXISTS(SELECT 1 FROM public.immobilier_biens WHERE id=cle) THEN CONTINUE;END IF;
  IF (SELECT count(*) FROM public.terrains_etat WHERE country=e.data->>'country' AND building_id=e.data->>'buildingId' AND coalesce(data::jsonb->>'city',e.data->>'city')=e.data->>'city')>1 THEN RAISE EXCEPTION 'cadastre_ambigu';END IF;
  SELECT * INTO t FROM public.terrains_etat WHERE country=e.data->>'country' AND building_id=e.data->>'buildingId' AND coalesce(data::jsonb->>'city',e.data->>'city')=e.data->>'city';
  titre:=t.id;
  IF titre IS NULL THEN
   titre:=(e.data->>'country')||'_'||(e.data->>'city')||'_'||(e.data->>'buildingId');
   INSERT INTO public.terrains_etat(id,country,building_id,proprietaire,data)
    VALUES(titre,e.data->>'country',e.data->>'buildingId','ville:'||(e.data->>'country')||'_'||(e.data->>'city'),
     jsonb_build_object('city',e.data->>'city','proprietaire','ville:'||(e.data->>'country')||'_'||(e.data->>'city'))::text);
  ELSIF (t.proprietaire IS NULL OR t.proprietaire='PNJ') AND (t.data::jsonb->>'proprietaire' IS NULL OR t.data::jsonb->>'proprietaire'='PNJ') THEN
   UPDATE public.terrains_etat SET proprietaire='ville:'||(e.data->>'country')||'_'||(e.data->>'city'),
    data=(data::jsonb||jsonb_build_object('proprietaire','ville:'||(e.data->>'country')||'_'||(e.data->>'city')))::text WHERE id=titre;
  END IF;
  -- Aucun titre PJ, superficie, bail ou subdivision n'est reecrit.
  SELECT surface INTO s FROM public.immobilier_surfaces_validees WHERE pays=e.data->>'country' AND ville=e.data->>'city' AND building_id=e.data->>'buildingId';
  IF t.id IS NOT NULL AND t.data::jsonb->>'surface' ~ '^[0-9]+(\.[0-9]+)?$' THEN
   IF s IS NOT NULL AND s<>(t.data::jsonb->>'surface')::numeric THEN RAISE EXCEPTION 'surface_persistante_divergente';END IF;
   s:=(t.data::jsonb->>'surface')::numeric;
  END IF;
  INSERT INTO public.immobilier_biens VALUES(cle,e.data->>'country',e.data->>'city',e.data->>'buildingId',titre,e.id,s);
  n:=n+1;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'raccordes',n);
END;$$;

CREATE OR REPLACE FUNCTION public.immobilier_offre_deposer(p_id text,p_bien text,p_actif text,p_prix text DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b public.immobilier_biens%rowtype;moi text:=public.mon_personnage();vendeur text;prix numeric;regime text;occupant text;courrier jsonb;h_notification timestamptz;ancien public.immobilier_offres%rowtype;d jsonb;
BEGIN
 IF moi IS NULL AND NOT public.est_appel_serveur() THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}';END IF;
 IF p_id IS NULL OR p_id !~ '^[A-Za-z0-9_-]{1,120}$' OR p_actif NOT IN('fonds','murs') OR p_actif IS NULL THEN RETURN '{"ok":false,"raison":"parametres_invalides"}';END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended('immobilier:'||p_bien,0));
 SELECT * INTO ancien FROM public.immobilier_offres WHERE id=p_id;
 IF FOUND THEN
  IF ancien.bien_id<>p_bien OR ancien.actif<>p_actif OR (p_prix IS NOT NULL AND ancien.prix::text<>p_prix) THEN RETURN '{"ok":false,"raison":"requete_reutilisee"}';END IF;
  vendeur:=public.immobilier_titulaire(p_bien,p_actif);
  IF vendeur IS DISTINCT FROM ancien.vendeur THEN RETURN '{"ok":false,"raison":"titre_modifie"}';END IF;
  IF public.immobilier_ref_pj(vendeur) IS NOT NULL AND public.immobilier_ref_pj(vendeur)<>moi THEN RETURN '{"ok":false,"raison":"pas_proprietaire"}';END IF;
  RETURN jsonb_build_object('ok',true,'offre',ancien.id,'rejeu',true);
 END IF;
 SELECT * INTO b FROM public.immobilier_biens WHERE id=p_bien FOR UPDATE;
 IF NOT public.est_appel_serveur() AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country=b.pays AND current_building='office-notarial' AND current_room='bureau_contrats' AND coalesce(hp,100)>0) THEN RETURN '{"ok":false,"raison":"pas_chez_notaire"}';END IF;
 IF NOT FOUND OR b.surface IS NULL THEN RETURN '{"ok":false,"raison":"fiche_incomplete"}';END IF;
 IF EXISTS(SELECT 1 FROM public.immobilier_offres WHERE bien_id=p_bien AND actif=p_actif AND statut<>'vendue') THEN RETURN '{"ok":false,"raison":"offre_existante"}';END IF;
 vendeur:=public.immobilier_titulaire(p_bien,p_actif);
 IF public.immobilier_ref_pj(vendeur) IS NOT NULL THEN
  IF public.immobilier_ref_pj(vendeur)<>moi THEN RETURN '{"ok":false,"raison":"pas_proprietaire"}';END IF;
  IF b.pays<>'republic' THEN RETURN '{"ok":false,"raison":"regime_revente_non_arbitre"}';END IF;
  IF p_prix IS NULL OR p_prix!~'^[0-9]+$' THEN RETURN '{"ok":false,"raison":"prix_invalide"}';END IF;
  prix:=p_prix::numeric;regime:='libre_pj';
 ELSE
  regime:='reference';
  IF p_actif='fonds' AND vendeur='PNJ' THEN
   IF NOT public.est_appel_serveur() THEN RETURN '{"ok":false,"raison":"offre_reference_serveur"}';END IF;
   SELECT data INTO d FROM public.entreprises WHERE id=b.entreprise_id FOR UPDATE;
   prix:=public.entreprise_prix_rachat(d);
  ELSIF p_actif='murs' AND vendeur='ville:'||b.pays||'_'||b.ville THEN
   IF NOT public.est_appel_serveur() AND NOT EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country=b.pays AND poste->>'id' IN('maire','maire_adjoint') AND poste->>'city'=b.ville) THEN RETURN '{"ok":false,"raison":"autorite_municipale_requise"}';END IF;
   SELECT b.surface*prix_m2 INTO prix FROM public.immobilier_tarifs_pays WHERE pays=b.pays;
  ELSE RETURN '{"ok":false,"raison":"titulaire_non_raccorde"}';END IF;
  IF p_prix IS NOT NULL AND p_prix IS DISTINCT FROM prix::text THEN RETURN '{"ok":false,"raison":"prix_public_non_modifiable"}';END IF;
 END IF;
 IF prix IS NULL OR prix<0 OR prix<>trunc(prix) THEN RETURN '{"ok":false,"raison":"prix_non_resolu"}';END IF;
 IF p_actif='murs' THEN
  PERFORM 1 FROM public.locations_actives WHERE country=b.pays AND data->>'city'=b.ville AND data->>'buildingId'=b.building_id ORDER BY id FOR UPDATE;
  occupant:=public.immobilier_occupant(p_bien);
 END IF;
 INSERT INTO public.immobilier_offres(id,bien_id,actif,vendeur,prix,regime,statut,beneficiaire,publication_le)
 VALUES(p_id,p_bien,p_actif,vendeur,prix,regime,CASE WHEN occupant IS NOT NULL AND occupant IS DISTINCT FROM public.immobilier_ref_pj(vendeur) THEN 'priorite' ELSE 'disponible' END,occupant,CASE WHEN occupant IS NULL OR occupant=public.immobilier_ref_pj(vendeur) THEN clock_timestamp() END);
 IF occupant IS NOT NULL AND occupant IS DISTINCT FROM public.immobilier_ref_pj(vendeur) THEN
  courrier:=public.mail_systeme_poser_interne('Office notarial',occupant,'Priorité sur les murs de votre établissement',
   'Offre '||p_id||' : murs à '||prix||' FR. Vous disposez de trois jours réels pour exercer votre priorité chez le notaire.');
  IF courrier->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'notification_preemption_refusee';END IF;
  h_notification:=clock_timestamp();
  UPDATE public.immobilier_offres SET notifie_le=h_notification,priorite_fin=h_notification+interval '72 hours' WHERE id=p_id;
 END IF;
 RETURN jsonb_build_object('ok',true,'offre',p_id,'rejeu',false);
END;$$;

CREATE OR REPLACE FUNCTION public.immobilier_priorites_publier() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE o record;n integer:=0;
BEGIN
 IF NOT public.est_appel_serveur() THEN RAISE EXCEPTION 'serveur_requis' USING ERRCODE='42501';END IF;
 FOR o IN SELECT id,bien_id FROM public.immobilier_offres WHERE statut='priorite' AND priorite_fin<=clock_timestamp() ORDER BY id LOOP
  PERFORM pg_advisory_xact_lock(hashtextextended('immobilier:'||o.bien_id,0));
  UPDATE public.immobilier_offres SET statut='disponible',publication_le=priorite_fin WHERE id=o.id AND statut='priorite' AND priorite_fin<=clock_timestamp();
  IF FOUND THEN n:=n+1;END IF;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'publiees',n);
END;$$;
CREATE OR REPLACE FUNCTION public.immobilier_priorite_refuser(p_offre text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE o public.immobilier_offres%rowtype;moi text:=public.mon_personnage();
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}';END IF;
 PERFORM 1 FROM public.personnages_donnees WHERE name=moi FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND coalesce(hp,100)<=0) THEN RETURN '{"ok":false,"raison":"acteur_incapacite"}';END IF;
 SELECT * INTO o FROM public.immobilier_offres WHERE id=p_offre;
 IF NOT FOUND THEN RETURN '{"ok":false,"raison":"offre_absente"}';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('immobilier:'||o.bien_id,0));
 SELECT * INTO o FROM public.immobilier_offres WHERE id=p_offre FOR UPDATE;
 IF o.beneficiaire IS DISTINCT FROM moi THEN RETURN '{"ok":false,"raison":"pas_prioritaire"}';END IF;
 IF o.statut='vendue' THEN RETURN '{"ok":false,"raison":"deja_vendue"}';END IF;
 IF o.statut='priorite' THEN
  IF o.priorite_fin<=clock_timestamp() THEN UPDATE public.immobilier_offres SET statut='disponible',publication_le=priorite_fin WHERE id=p_offre;
  ELSE UPDATE public.immobilier_offres SET statut='disponible',refus_le=clock_timestamp(),publication_le=clock_timestamp() WHERE id=p_offre;END IF;
 END IF;
 RETURN '{"ok":true}';
END;$$;

CREATE OR REPLACE FUNCTION public.immobilier_catalogue(p_pays text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE moi text:=public.mon_personnage();r jsonb;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',o.id,'bien_id',b.id,'actif',o.actif,'vendeur',o.vendeur,'pays',b.pays,'ville',b.ville,'building_id',b.building_id,'surface',b.surface,
  'prix',o.prix::text,'regime',o.regime,'statut',CASE WHEN o.statut='priorite' AND o.priorite_fin<=clock_timestamp() THEN 'disponible' ELSE o.statut END,
  'sous_compromis',o.actif='fonds' AND coalesce((e.data->>'compromis')::boolean,false) AND coalesce((e.data->>'compromisExpireAt')::numeric,0)>extract(epoch FROM clock_timestamp())*1000,
  'prioritaire',o.beneficiaire=moi AND o.statut='priorite' AND o.priorite_fin>clock_timestamp(),'priorite_fin',CASE WHEN o.beneficiaire=moi THEN o.priorite_fin END,
  'disponible',b.surface IS NOT NULL AND public.immobilier_titulaire(b.id,o.actif)=o.vendeur
    AND NOT (o.actif='fonds' AND coalesce((e.data->>'compromis')::boolean,false) AND coalesce((e.data->>'compromisExpireAt')::numeric,0)>extract(epoch FROM clock_timestamp())*1000 AND coalesce(e.data->>'compromisPar','')<>moi)
    AND (o.statut='disponible' OR (o.statut='priorite' AND (o.beneficiaire=moi OR o.priorite_fin<=clock_timestamp())))) ORDER BY o.created_at,o.id),'[]') INTO r
 FROM public.immobilier_offres o JOIN public.immobilier_biens b ON b.id=o.bien_id LEFT JOIN public.entreprises e ON e.id=b.entreprise_id
 WHERE b.pays=p_pays AND o.statut<>'vendue' AND (o.statut<>'priorite' OR o.priorite_fin<=clock_timestamp() OR o.beneficiaire=moi OR public.immobilier_ref_pj(o.vendeur)=moi OR (o.vendeur='ville:'||b.pays||'_'||b.ville AND EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country=b.pays AND poste->>'id' IN('maire','maire_adjoint') AND poste->>'city'=b.ville)));
 RETURN jsonb_build_object('ok',true,'offres',r);
END;$$;

DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.vendre_fonds_commerce(text,text,text,integer)');IF h IS NULL OR h NOT IN('cb3c22d94317435bafb6cb0e2ab80de7','aac3ccef114484fe223676a0ce446af4') THEN RAISE EXCEPTION 'definition_non_examinee: vendre_fonds_commerce';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.vendre_fonds_commerce(p_vendeur text, p_acheteur text, p_fonds_id text, p_prix integer, p_paiement_externe boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_data jsonb;
  v_bail_id text;
  v_bail jsonb;
  v_prix integer := GREATEST(0, COALESCE(p_prix, 0));
  v_caisse integer;
  v_premier text;
  v_second text;
BEGIN
  IF COALESCE(p_vendeur, '') = '' OR COALESCE(p_acheteur, '') = '' OR COALESCE(p_fonds_id, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF p_vendeur = p_acheteur THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_identique'); END IF;
  IF left(p_acheteur, 6) = 'ville:' THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_invalide'); END IF;
  IF p_vendeur < p_acheteur THEN v_premier := p_vendeur; v_second := p_acheteur; ELSE v_premier := p_acheteur; v_second := p_vendeur; END IF;
  IF NOT mouvement_titulaire(v_premier, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent'); END IF;
  IF NOT mouvement_titulaire(v_second, 0) THEN RETURN jsonb_build_object('ok', false, 'raison', 'titulaire_absent'); END IF;
  SELECT data INTO v_data FROM entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF COALESCE((v_data ->> 'version')::integer, 0) < 2 THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds'); END IF;
  IF COALESCE(v_data ->> 'statut', 'actif') <> 'actif' THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;
  IF (v_data ->> 'proprietaire') IS DISTINCT FROM p_vendeur THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire'); END IF;
  IF v_prix > 0 AND NOT p_paiement_externe THEN
    IF NOT mouvement_titulaire(p_acheteur, -v_prix) THEN RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_insolvable'); END IF;
    IF NOT mouvement_titulaire(p_vendeur, v_prix) THEN RAISE EXCEPTION 'vendeur_introuvable'; END IF;
  END IF;
  v_caisse := GREATEST(0, COALESCE((v_data ->> 'caisse')::numeric, 0))::integer;
  IF v_caisse > 0 THEN
    IF p_paiement_externe THEN
      IF public.immobilier_ref_pj(p_vendeur) IS NULL THEN RAISE EXCEPTION 'vendeur_non_raccorde';END IF;
      PERFORM public.helvetia_crediter_destination(public.immobilier_ref_pj(p_vendeur),v_caisse,'national');
    ELSIF NOT mouvement_titulaire(p_vendeur,v_caisse) THEN RAISE EXCEPTION 'extraction_impossible';END IF;
  END IF;
  v_data := jsonb_set(v_data, '{proprietaire}', to_jsonb(p_acheteur));
  v_data := jsonb_set(v_data, '{caisse}', to_jsonb(0));
  v_data := jsonb_set(v_data, '{historique}', COALESCE(v_data -> 'historique', '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'evenement', 'vente', 'vendeur', p_vendeur, 'acheteur', p_acheteur, 'prix', v_prix, 'caisseExtraite', v_caisse,
      'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))));
  UPDATE entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;
  v_bail_id := v_data -> 'implantation' ->> 'bailId';
  IF COALESCE(v_bail_id, '') <> '' THEN
    SELECT data INTO v_bail FROM locations_actives WHERE id = v_bail_id FOR UPDATE;
    IF v_bail IS NOT NULL THEN
      UPDATE locations_actives
        SET data = v_bail || jsonb_build_object(
              'locataire', CASE WHEN left(p_acheteur, 3) = 'pj:' THEN substr(p_acheteur, 4) ELSE p_acheteur END,
              'locataireRef', p_acheteur,
              'transferts', COALESCE(v_bail -> 'transferts', '[]'::jsonb) || jsonb_build_array(
                jsonb_build_object('cause', 'vente_fonds', 'de', p_vendeur, 'vers', p_acheteur,
                  'horodatage', to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD"T"HH24:MI:SS'))))
        WHERE id = v_bail_id;
    END IF;
  END IF;
  RETURN jsonb_build_object('ok', true, 'fondsId', p_fonds_id, 'prix', v_prix, 'caisseExtraite', v_caisse, 'acheteur', p_acheteur, 'bailTransfere', COALESCE(v_bail_id, ''));
END;
$function$;
CREATE OR REPLACE FUNCTION public.vendre_fonds_commerce(p_vendeur text,p_acheteur text,p_fonds_id text,p_prix integer)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=public,pg_temp AS $function$
 SELECT public.vendre_fonds_commerce(p_vendeur,p_acheteur,p_fonds_id,p_prix,false);
$function$;
REVOKE ALL ON FUNCTION public.vendre_fonds_commerce(text,text,text,integer,boolean) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.vendre_fonds_commerce(text,text,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.vendre_fonds_commerce(text,text,text,integer) TO service_role;
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.recette_municipale(text,text,numeric,text)');
 IF h IS NULL OR h NOT IN('1a0ee027dc0a9b0b77524f9d5c2d061c','81acdda0369275ea3369cb8ea1bf7c89') THEN RAISE EXCEPTION 'definition_non_examinee: recette_municipale';END IF;END;$g$;
-- Ne jamais effacer une extension du catalogue vivant non examinee.
DO $g$ DECLARE definition text;canaux text[];BEGIN
 SELECT pg_get_constraintdef(oid) INTO definition FROM pg_constraint WHERE conrelid='public.recettes_municipales'::regclass AND conname='recettes_municipales_canal_check';
 IF definition IS NOT NULL THEN
  SELECT array_agg(DISTINCT m[1] ORDER BY m[1]) INTO canaux FROM regexp_matches(definition,'''([^'']+)''','g') m;
  IF canaux IS DISTINCT FROM ARRAY['loyer','taxe_fonciere','taxe_transaction']::text[] AND canaux IS DISTINCT FROM ARRAY['cession_immobiliere','loyer','taxe_fonciere','taxe_transaction']::text[] THEN RAISE EXCEPTION 'canaux_municipaux_non_examines';END IF;
 END IF;
END;$g$;
ALTER TABLE public.recettes_municipales DROP CONSTRAINT IF EXISTS recettes_municipales_canal_check;
ALTER TABLE public.recettes_municipales ADD CONSTRAINT recettes_municipales_canal_check CHECK(canal IN('taxe_fonciere','loyer','taxe_transaction','cession_immobiliere'));
CREATE OR REPLACE FUNCTION public.recette_municipale(p_pays text, p_ville text, p_montant numeric, p_canal text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_caisse text; v_jour date; v_rep jsonb;
BEGIN
  IF coalesce(btrim(p_pays), '') = '' OR coalesce(btrim(p_ville), '') = ''
     OR p_montant IS NULL OR p_montant <= 0
     OR p_canal NOT IN ('taxe_fonciere', 'loyer', 'taxe_transaction', 'cession_immobiliere') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.villes v WHERE v.pays = p_pays AND v.ville = p_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_ville', 'ville', p_ville);
  END IF;

  v_caisse := public.salaire_caisse_de('maire', p_pays, p_ville);
  IF v_caisse IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_mairie_introuvable', 'ville', p_ville);
  END IF;

  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse, p_montant, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'credit_refuse', 'detail', v_rep);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  INSERT INTO public.recettes_municipales (pays, ville, jour, canal, montant, updated_at)
  VALUES (p_pays, p_ville, v_jour, p_canal, p_montant, now())
  ON CONFLICT (pays, ville, jour, canal)
    DO UPDATE SET montant = recettes_municipales.montant + excluded.montant,
                  updated_at = now();

  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse, 'montant', p_montant,
                            'canal', p_canal, 'jour', v_jour);
END;
$function$;
-- La cession d'imprimerie existante encaisse l'Etat mais ne debite pas le PJ.
-- Si sa definition vivante a change, l'agent doit l'examiner avant cette preparation.
DO $g$ DECLARE h text;BEGIN SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid=to_regprocedure('public.imprimerie_cession_finaliser(text,text,text,numeric,integer)');
 IF h IS NOT NULL AND h<>'b960c4317c0ad28af187fe08207ad2c2' THEN RAISE EXCEPTION 'definition_non_examinee: imprimerie_cession_finaliser';END IF;END;$g$;
CREATE OR REPLACE FUNCTION public.immobilier_acte_finaliser(p_requete text,p_offres text[]) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE moi text:=public.mon_personnage();ids text[];b public.immobilier_biens%rowtype;o public.immobilier_offres%rowtype;
 a public.immobilier_actes%rowtype;p public.personnages_donnees%rowtype;d jsonb;r jsonb;total numeric:=0;reste numeric;ancien text;v text;nb integer;occupant text;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}';END IF;
 IF p_requete IS NULL OR p_requete !~ '^[A-Za-z0-9_-]{1,120}$' OR cardinality(p_offres) NOT BETWEEN 1 AND 2 OR cardinality(p_offres) IS NULL THEN RETURN '{"ok":false,"raison":"requete_invalide"}';END IF;
 SELECT array_agg(DISTINCT x ORDER BY x) INTO ids FROM unnest(p_offres) AS t(x);
 IF cardinality(ids)<>cardinality(p_offres) OR array_position(ids,NULL) IS NOT NULL THEN RETURN '{"ok":false,"raison":"offres_invalides"}';END IF;
 -- Verrou des participants AVANT les biens ; memes noms dans le meme ordre pour les ventes croisees.
 PERFORM 1 FROM public.personnages_donnees WHERE name=moi OR name IN(
   SELECT public.immobilier_ref_pj(vendeur) FROM public.immobilier_offres WHERE id=ANY(ids)) ORDER BY name FOR UPDATE;
 SELECT * INTO a FROM public.immobilier_actes WHERE acteur=moi AND requete=p_requete;
 IF FOUND THEN
  IF a.offres IS DISTINCT FROM ids THEN RETURN '{"ok":false,"raison":"requete_reutilisee"}';END IF;
  RETURN a.verdict||'{"rejeu":true}'::jsonb;
 END IF;
 SELECT * INTO p FROM public.personnages_donnees WHERE name=moi;
 IF coalesce(p.hp,100)<=0 THEN RETURN '{"ok":false,"raison":"acteur_incapacite"}';END IF;
 IF p.current_building IS DISTINCT FROM 'office-notarial' OR p.current_room IS DISTINCT FROM 'bureau_contrats' THEN RETURN '{"ok":false,"raison":"pas_chez_notaire"}';END IF;
 SELECT count(*),min(bien_id) INTO nb,ancien FROM public.immobilier_offres WHERE id=ANY(ids);
 IF nb<>cardinality(ids) OR (SELECT count(DISTINCT bien_id) FROM public.immobilier_offres WHERE id=ANY(ids))<>1 THEN RETURN '{"ok":false,"raison":"offres_invalides"}';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('immobilier:'||ancien,0));
 -- Un autre appel du meme acteur a pu terminer pendant l'attente.
 SELECT * INTO a FROM public.immobilier_actes WHERE acteur=moi AND requete=p_requete;
 IF FOUND THEN IF a.offres IS DISTINCT FROM ids THEN RETURN '{"ok":false,"raison":"requete_reutilisee"}';END IF;RETURN a.verdict||'{"rejeu":true}'::jsonb;END IF;
 SELECT * INTO b FROM public.immobilier_biens WHERE id=ancien FOR UPDATE;
 IF b.surface IS NULL OR b.pays IS DISTINCT FROM p.country THEN RETURN '{"ok":false,"raison":"fiche_incomplete_ou_hors_pays"}';END IF;
 SELECT data::jsonb INTO d FROM public.terrains_etat WHERE id=b.terrain_id FOR UPDATE;
 IF d->>'succession_gel' IS NOT NULL AND EXISTS(SELECT 1 FROM public.immobilier_offres WHERE id=ANY(ids) AND actif='murs') THEN RETURN '{"ok":false,"raison":"bien_gele"}';END IF;
 PERFORM 1 FROM public.entreprises WHERE id=b.entreprise_id FOR UPDATE;
 PERFORM 1 FROM public.locations_actives WHERE country=b.pays AND data->>'city'=b.ville AND data->>'buildingId'=b.building_id ORDER BY id FOR UPDATE;
 FOR o IN SELECT * FROM public.immobilier_offres WHERE id=ANY(ids) ORDER BY actif FOR UPDATE LOOP
  IF o.statut='vendue' THEN RETURN '{"ok":false,"raison":"offre_vendue"}';END IF;
  IF public.immobilier_titulaire(b.id,o.actif) IS DISTINCT FROM o.vendeur THEN RETURN '{"ok":false,"raison":"titre_modifie"}';END IF;
  IF public.immobilier_ref_pj(o.vendeur)=moi THEN RETURN '{"ok":false,"raison":"acheteur_identique"}';END IF;
  IF o.actif='murs' THEN
   occupant:=public.immobilier_occupant(b.id);
   IF occupant IS DISTINCT FROM o.beneficiaire THEN RETURN '{"ok":false,"raison":"occupation_modifiee"}';END IF;
   IF o.statut='priorite' AND o.priorite_fin>clock_timestamp() AND o.beneficiaire IS DISTINCT FROM moi THEN RETURN '{"ok":false,"raison":"priorite_exploitant"}';END IF;
  ELSE
   SELECT data INTO d FROM public.entreprises WHERE id=b.entreprise_id;
   IF d->>'succession_gel' IS NOT NULL OR d->>'successionGel' IS NOT NULL THEN RETURN '{"ok":false,"raison":"bien_gele"}';END IF;
   IF coalesce((d->>'version')::integer,0)>=2 AND (coalesce((d->>'caisse')::numeric,0)<>trunc(coalesce((d->>'caisse')::numeric,0)) OR coalesce((d->>'caisse')::numeric,0)<0) THEN RETURN '{"ok":false,"raison":"etat_financier_non_entier"}';END IF;
   IF coalesce((d->>'acompte')::numeric,0)<>trunc(coalesce((d->>'acompte')::numeric,0)) OR coalesce((d->>'acompte')::numeric,0)<0 OR coalesce((d->>'acompte')::numeric,0)>o.prix THEN RETURN '{"ok":false,"raison":"acompte_historique_incoherent"}';END IF;
   IF d->'pretDemande'->>'statut'='attente_validation' THEN RETURN '{"ok":false,"raison":"pret_en_attente"}';END IF;
   IF coalesce((d->>'compromis')::boolean,false) THEN
    IF d->>'compromisPar' IS DISTINCT FROM moi THEN RETURN '{"ok":false,"raison":"pas_votre_compromis"}';END IF;
    IF coalesce((d->>'compromisExpireAt')::numeric,0)<=extract(epoch FROM clock_timestamp())*1000 THEN RETURN '{"ok":false,"raison":"compromis_expire"}';END IF;
   END IF;
  END IF;
  total:=total+o.prix;
 END LOOP;
 -- Toute exception apres le premier mouvement annule frais, argent, titres, baux et recu.
 BEGIN
  INSERT INTO public.immobilier_actes(acteur,requete,offres,bien_id,transaction_id) VALUES(moi,p_requete,ids,b.id,txid_current());
  r:=public.payer_ordre(moi,'officialiser_transaction',1,0);
  IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'frais_refuses';END IF;
  FOR o IN SELECT * FROM public.immobilier_offres WHERE id=ANY(ids) ORDER BY actif LOOP
   IF o.actif='fonds' AND o.vendeur='PNJ' THEN
    SELECT data INTO d FROM public.entreprises WHERE id=b.entreprise_id;
    IF public.entreprise_prix_rachat(d) IS DISTINCT FROM o.prix THEN RAISE EXCEPTION 'prix_catalogue_modifie';END IF;
    IF d->>'type'='imprimerie' AND to_regprocedure('public.imprimerie_cession_finaliser(text,text,text,numeric,integer)') IS NULL THEN RAISE EXCEPTION 'cession_imprimerie_a_raccorder';END IF;
    IF NOT coalesce((d->>'compromis')::boolean,false) THEN
     r:=public.entreprise_signer_compromis(moi,b.entreprise_id,NULL,NULL);
     IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'compromis_refuse';END IF;
    END IF;
    IF d->>'type'='imprimerie' THEN
     SELECT data INTO d FROM public.entreprises WHERE id=b.entreprise_id;
     reste:=o.prix-coalesce((d->>'acompte')::numeric,0);
     IF reste<0 OR NOT public.helvetia_debiter_fonds_ordinaires(moi,reste) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
     r:=public.imprimerie_cession_finaliser('immobilier66-'||md5(moi||':'||p_requete||':'||b.id),moi,b.entreprise_id,o.prix,p.day);
    ELSE
     r:=public.entreprise_acte_rachat(moi,b.entreprise_id,NULL,0,0);
    END IF;
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'achat_fonds_refuse';END IF;
   ELSE
    IF NOT public.helvetia_debiter_fonds_ordinaires(moi,o.prix) THEN RAISE EXCEPTION 'fonds_insuffisants';END IF;
    IF left(o.vendeur,6)='ville:' THEN
     r:=public.recette_municipale(b.pays,b.ville,o.prix,'cession_immobiliere');
     IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'credit_vendeur_refuse';END IF;
    ELSE
     v:=public.immobilier_ref_pj(o.vendeur);
     IF v IS NULL THEN RAISE EXCEPTION 'vendeur_non_raccorde';END IF;
     -- La destination nationale est le moteur de credit existant, pas une nouvelle caisse.
     IF o.prix>0 THEN PERFORM public.helvetia_crediter_destination(v,o.prix,'national');END IF;
    END IF;
    IF o.actif='murs' THEN
     UPDATE public.terrains_etat SET proprietaire=moi,data=(data::jsonb||jsonb_build_object('proprietaire',moi))::text,updated_at=now() WHERE id=b.terrain_id;
     INSERT INTO public.terrains_historique_ventes(id,country,building_id,proprietaire,prix) VALUES('acte-'||p_requete||'-'||md5(moi),b.pays,b.building_id,moi,o.prix);
    ELSE
     SELECT data INTO d FROM public.entreprises WHERE id=b.entreprise_id;
     IF coalesce((d->>'version')::integer,0)>=2 THEN
      r:=public.vendre_fonds_commerce(o.vendeur,'pj:'||moi,b.entreprise_id,o.prix::integer,true);
      IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'transfert_fonds_refuse';END IF;
     ELSE
      d:=public.entreprise_ajouter_historique(d||jsonb_build_object('proprietaire',moi),o.prix,'Cession notariée du fonds',p.day);
      UPDATE public.entreprises SET data=d,updated_at=now() WHERE id=b.entreprise_id;
     END IF;
    END IF;
   END IF;
   UPDATE public.immobilier_offres SET statut='vendue',acheteur=moi,publication_le=coalesce(publication_le,CASE WHEN priorite_fin<=clock_timestamp() THEN priorite_fin END) WHERE id=o.id;
  END LOOP;
  r:=jsonb_build_object('ok',true,'requete',p_requete,'offres',ids,'prix_total',total::text,'rejeu',false);
  UPDATE public.immobilier_actes SET verdict=r WHERE acteur=moi AND requete=p_requete;
  RETURN r;
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM IN('frais_refuses','prix_catalogue_modifie','cession_imprimerie_a_raccorder','compromis_refuse','achat_fonds_refuse','fonds_insuffisants','credit_vendeur_refuse','vendeur_non_raccorde','transfert_fonds_refuse') THEN RETURN jsonb_build_object('ok',false,'raison',SQLERRM);ELSE RAISE;END IF;
 END;
END;$$;

-- Les anciens canaux ne peuvent pas restaurer le vendeur ou contourner une offre/priorite.
CREATE OR REPLACE FUNCTION public.immobilier_titre_proteger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE bien text;v_actif text;avant text;apres text;
BEGIN
 IF TG_TABLE_NAME='terrains_etat' THEN
  SELECT id INTO bien FROM public.immobilier_biens WHERE terrain_id=OLD.id;v_actif:='murs';avant:=OLD.proprietaire;
  IF TG_OP<>'DELETE' THEN apres:=NEW.proprietaire;
   IF bien IS NOT NULL AND NEW.proprietaire IS DISTINCT FROM NEW.data::jsonb->>'proprietaire' AND NOT coalesce(public.immobilier_ref_pj(NEW.proprietaire)=public.immobilier_ref_pj(NEW.data::jsonb->>'proprietaire'),false) THEN RAISE EXCEPTION 'titres_murs_divergents';END IF;
  END IF;
 ELSE
  SELECT id INTO bien FROM public.immobilier_biens WHERE entreprise_id=OLD.id;v_actif:='fonds';avant:=OLD.data->>'proprietaire';
  IF TG_OP<>'DELETE' THEN apres:=NEW.data->>'proprietaire';END IF;
 END IF;
 -- Le pouvoir d'Etat existant reste distinct du droit de l'exploitant.
 IF TG_TABLE_NAME='entreprises' AND TG_OP='UPDATE' THEN
  IF OLD.data->>'preemptionEtat'='attente_acte' AND EXISTS(SELECT 1 FROM public.acteur_poste_courant() a WHERE a.poste_id='min_fin') THEN RETURN NEW;END IF;
 END IF;
 IF bien IS NOT NULL AND (TG_OP='DELETE' OR apres IS DISTINCT FROM avant) AND NOT public.est_appel_serveur() THEN
  IF TG_OP='DELETE' OR NOT EXISTS(SELECT 1 FROM public.immobilier_actes a JOIN public.immobilier_offres o ON o.id=ANY(a.offres)
    WHERE a.bien_id=bien AND a.transaction_id=txid_current() AND a.verdict IS NULL AND o.actif=v_actif AND o.vendeur=avant
    AND public.immobilier_ref_pj(apres)=a.acteur) THEN RAISE EXCEPTION 'acte_notaire_requis' USING ERRCODE='42501';END IF;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END;$$;
DROP TRIGGER IF EXISTS zzzz_immobilier_titre ON public.terrains_etat;
CREATE TRIGGER zzzz_immobilier_titre BEFORE UPDATE OR DELETE ON public.terrains_etat FOR EACH ROW EXECUTE FUNCTION public.immobilier_titre_proteger();
DROP TRIGGER IF EXISTS zzzz_immobilier_titre ON public.entreprises;
CREATE TRIGGER zzzz_immobilier_titre BEFORE UPDATE OR DELETE ON public.entreprises FOR EACH ROW EXECUTE FUNCTION public.immobilier_titre_proteger();

-- Un bail cree/change pendant la vente partage le verrou du bien, sans changer ses clauses.
CREATE OR REPLACE FUNCTION public.immobilier_bail_serialiser() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE d jsonb;cle text;
BEGIN
 IF TG_OP='DELETE' THEN d:=OLD.data;ELSE d:=NEW.data;END IF;
 SELECT id INTO cle FROM public.immobilier_biens WHERE pays=coalesce(d->>'country',CASE WHEN TG_OP='DELETE' THEN OLD.country ELSE NEW.country END) AND ville=d->>'city' AND building_id=d->>'buildingId';
 IF cle IS NOT NULL THEN PERFORM pg_advisory_xact_lock(hashtextextended('immobilier:'||cle,0));END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;
END;$$;
DROP TRIGGER IF EXISTS zzzz_immobilier_bail ON public.locations_actives;
CREATE TRIGGER zzzz_immobilier_bail BEFORE INSERT OR UPDATE OR DELETE ON public.locations_actives FOR EACH ROW EXECUTE FUNCTION public.immobilier_bail_serialiser();

CREATE OR REPLACE FUNCTION public.immobilier_biens_lire(p_pays text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE moi text:=public.mon_personnage();r jsonb;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',b.id,'pays',b.pays,'ville',b.ville,'building_id',b.building_id,'surface',b.surface,
  'proprietaire_murs',public.immobilier_titulaire(b.id,'murs'),'proprietaire_fonds',public.immobilier_titulaire(b.id,'fonds'),
  'peut_vendre_fonds',public.immobilier_ref_pj(public.immobilier_titulaire(b.id,'fonds'))=moi,
  'peut_vendre_murs',public.immobilier_ref_pj(public.immobilier_titulaire(b.id,'murs'))=moi OR (public.immobilier_titulaire(b.id,'murs')='ville:'||b.pays||'_'||b.ville
   AND EXISTS(SELECT 1 FROM public.personnages_donnees WHERE name=moi AND country=b.pays AND poste->>'city'=b.ville AND poste->>'id' IN('maire','maire_adjoint')))) ORDER BY b.id),'[]') INTO r
 FROM public.immobilier_biens b WHERE b.pays=p_pays;
 RETURN jsonb_build_object('ok',true,'biens',r);
END;$$;
REVOKE ALL ON FUNCTION public.immobilier_biens_lire(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.immobilier_biens_lire(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.immobilier_acte_etat(p_requete text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE moi text:=public.mon_personnage();v jsonb;
BEGIN
 IF moi IS NULL THEN RETURN '{"ok":false,"raison":"acteur_non_authentifie"}';END IF;
 SELECT verdict INTO v FROM public.immobilier_actes WHERE acteur=moi AND requete=p_requete;
 RETURN jsonb_build_object('ok',true,'termine',v IS NOT NULL,'verdict',v);
END;$$;
REVOKE ALL ON FUNCTION public.immobilier_acte_etat(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.immobilier_acte_etat(text) TO authenticated;

-- Publication initiale des references, operation serveur explicite apres prevol ; aucun prix PJ invente.
CREATE OR REPLACE FUNCTION public.immobilier_references_publier() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE b record;v_actif text;titulaire text;r jsonb;n integer:=0;incomplets integer:=0;
BEGIN
 IF NOT public.est_appel_serveur() THEN RAISE EXCEPTION 'serveur_requis' USING ERRCODE='42501';END IF;
 FOR b IN SELECT * FROM public.immobilier_biens WHERE surface IS NOT NULL ORDER BY id LOOP
  FOREACH v_actif IN ARRAY ARRAY['fonds','murs'] LOOP
   titulaire:=public.immobilier_titulaire(b.id,v_actif);
   IF (v_actif='fonds' AND titulaire='PNJ') OR (v_actif='murs' AND titulaire='ville:'||b.pays||'_'||b.ville) THEN
    IF (v_actif='fonds' AND (SELECT public.entreprise_prix_rachat(data) FROM public.entreprises WHERE id=b.entreprise_id) IS NULL) OR (v_actif='murs' AND NOT EXISTS(SELECT 1 FROM public.immobilier_tarifs_pays WHERE pays=b.pays)) THEN incomplets:=incomplets+1;CONTINUE;END IF;
    IF EXISTS(SELECT 1 FROM public.immobilier_offres o WHERE o.bien_id=b.id AND o.actif=v_actif AND o.statut<>'vendue') THEN CONTINUE;END IF;
    r:=public.immobilier_offre_deposer('reference-'||md5(b.id||':'||v_actif),b.id,v_actif,NULL);
    IF r->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'publication_reference_refusee';END IF;
    n:=n+1;
   END IF;
  END LOOP;
 END LOOP;
 RETURN jsonb_build_object('ok',true,'publiees',n,'non_valorisees',incomplets);
END;$$;
REVOKE ALL ON FUNCTION public.immobilier_references_publier() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.immobilier_references_publier() TO service_role;

-- Droits explicites : tous les helpers sont prives ; aucune table n'est modifiable par le client.
REVOKE ALL ON FUNCTION public.immobilier_ref_pj(text),public.immobilier_titulaire(text,text),public.immobilier_occupant(text),public.immobilier_raccorder_pnj(),public.immobilier_priorites_publier(),public.immobilier_titre_proteger(),public.immobilier_bail_serialiser() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.immobilier_offre_deposer(text,text,text,text),public.immobilier_priorite_refuser(text),public.immobilier_catalogue(text),public.immobilier_acte_finaliser(text,text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.immobilier_offre_deposer(text,text,text,text),public.immobilier_priorite_refuser(text),public.immobilier_catalogue(text),public.immobilier_acte_finaliser(text,text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.immobilier_raccorder_pnj(),public.immobilier_priorites_publier() TO service_role;
COMMIT;
