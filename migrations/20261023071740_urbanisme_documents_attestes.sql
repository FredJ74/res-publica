-- #94 PREPAREE : attestation des archives, contenu canonique et livraison unique.
-- Depend de #112 et du raccordement transactionnel des decisions/plans/cron.
BEGIN;
DO $definitions$ BEGIN
 IF to_regprocedure('public.urbanisme_archive_canoniser()') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.urbanisme_archive_canoniser()') AND md5(prosrc)='7e29659e34d3990cee645dc874ab099b') THEN RAISE EXCEPTION 'definition_non_examinee: urbanisme_archive_canoniser()';END IF;
 IF to_regprocedure('public.urbanisme_archive_attester()') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.urbanisme_archive_attester()') AND md5(prosrc)='304aeb9d1ea6b32775117a9aca23b0c1') THEN RAISE EXCEPTION 'definition_non_examinee: urbanisme_archive_attester()';END IF;
 IF to_regprocedure('public.urbanisme_archive_verifier_final()') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.urbanisme_archive_verifier_final()') AND md5(prosrc)='e6d0bdeab5662a764bb0d25a8dc442d7') THEN RAISE EXCEPTION 'definition_non_examinee: urbanisme_archive_verifier_final()';END IF;
END;$definitions$;
REVOKE UPDATE,DELETE ON public.dossiers_urbanisme FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.urbanisme_archive_canoniser() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE t record;p jsonb;acteur text:=public.mon_personnage();poste record;nature text:=NEW.type_evenement;demandeur text;jour integer;plan jsonb;
BEGIN
 IF nature NOT IN('depot','acceptation','refus','accord_tacite','modification_plan') OR nature IS NULL THEN RAISE EXCEPTION 'nature_urbanisme_inconnue';END IF;
 SELECT * INTO t FROM public.terrains_etat WHERE country=NEW.country AND building_id=NEW.building_id AND data::jsonb->>'city'=NEW.city FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'terrain_urbanisme_introuvable';END IF;
 p:=t.data::jsonb->'permis';
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'permis_urbanisme_absent';END IF;
 IF nature='depot' THEN
  -- Le trigger #112 doit toujours verifier son autorisation transactionnelle.
  IF NOT EXISTS(SELECT 1 FROM public.permis_transactions_internes cap WHERE cap.transaction_id=txid_current() AND cap.acteur=auth.uid()) THEN RAISE EXCEPTION 'depot_permis_commande_versionnee_requise';END IF;
 ELSIF nature IN('acceptation','refus') THEN
  IF NOT EXISTS(SELECT 1 FROM public.urbanisme_decisions_internes cap WHERE cap.transaction_id=txid_current() AND cap.acteur=auth.uid() AND cap.terrain=NEW.building_id) THEN RAISE EXCEPTION 'decision_commande_versionnee_requise';END IF;
  SELECT * INTO poste FROM public.acteur_poste_courant();
  IF poste.poste_id IS DISTINCT FROM 'maire_adjoint' OR poste.poste_city IS DISTINCT FROM NEW.city OR poste.pays IS DISTINCT FROM NEW.country THEN RAISE EXCEPTION 'autorite_urbanisme_refusee';END IF;
 ELSIF nature='accord_tacite' THEN
  IF NOT public.est_appel_serveur() THEN RAISE EXCEPTION 'accord_tacite_reserve_serveur';END IF;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM public.urbanisme_plans_internes cap WHERE cap.transaction_id=txid_current() AND cap.acteur=auth.uid() AND cap.terrain=NEW.building_id) THEN RAISE EXCEPTION 'plan_commande_versionnee_requise';END IF;
  IF public.titulaire_est_moi(t.data::jsonb->>'proprietaire') IS NOT TRUE THEN
   IF to_regprocedure('public.chantier_autorite_exiger_interne(text,text,text)') IS NULL THEN RAISE EXCEPTION 'autorite_plan_indisponible';END IF;
   EXECUTE 'SELECT public.chantier_autorite_exiger_interne($1,$2,$3)' USING t.data::jsonb->>'proprietaire',NEW.country,NEW.city;
  END IF;
 END IF;
 demandeur:=CASE WHEN nature='modification_plan' THEN acteur ELSE p->>'demandeur' END;
 IF nullif(demandeur,'') IS NULL THEN RAISE EXCEPTION 'demandeur_urbanisme_absent';END IF;
 jour:=public.jour_de_jeu_pays(NEW.country);
 plan:=CASE WHEN nature='modification_plan' THEN NEW.data->'decoupage' ELSE coalesce(p->'decoupageInitial','[]') END;
 IF jsonb_typeof(plan) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'plan_archive_invalide';END IF;
 NEW.demandeur:=demandeur;NEW.numero_dossier:=p->>'numeroDossier';NEW.jour:=jour;
 NEW.libelle:='Urbanisme : '||nature;
 NEW.data:=jsonb_build_object('id',NEW.id,'nature',nature,'numeroDossier',NEW.numero_dossier,'jour',jour,
  'jourDepot',p->'dateDepot','demandeur',demandeur,'pays',NEW.country,'ville',NEW.city,'buildingId',NEW.building_id,
  'palier',p->>'palierDemande','palierLabel',p->>'palierDemande','surfaceExploitable',t.data::jsonb->'surface',
  'decoupage',plan,'motifRefus',CASE WHEN nature='refus' THEN p->>'motifRefus' END);
 RETURN NEW;
END;$f$;
CREATE OR REPLACE FUNCTION public.urbanisme_archive_attester() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE cle text;
BEGIN
 cle:=md5(jsonb_build_array(NEW.country,NEW.building_id,NEW.numero_dossier,NEW.data->'jourDepot',NEW.type_evenement,
  CASE WHEN NEW.type_evenement='modification_plan' THEN NEW.data->'decoupage' END)::text);
 INSERT INTO public.urbanisme_archives_attestees(archive,cle_evenement,emetteur) VALUES(NEW.id,cle,public.mon_personnage());
 RETURN NEW;
END;$f$;
CREATE OR REPLACE FUNCTION public.urbanisme_archive_verifier_final() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $f$
DECLARE e jsonb;p jsonb;nature text:=NEW.type_evenement;
BEGIN
 SELECT data::jsonb INTO e FROM public.terrains_etat WHERE country=NEW.country AND building_id=NEW.building_id AND data::jsonb->>'city'=NEW.city;
 p:=e->'permis';
 IF (p->>'numeroDossier') IS DISTINCT FROM NEW.numero_dossier THEN RAISE EXCEPTION 'archive_dossier_obsolete';END IF;
 IF nature IN('acceptation','accord_tacite') AND p->>'statut' IS DISTINCT FROM 'valide'
 OR nature='refus' AND p->>'statut' IS DISTINCT FROM 'refuse'
 OR nature='depot' AND p->>'statut' IS DISTINCT FROM 'instruction'
 OR nature='modification_plan' AND coalesce(p->'decoupageInitial','[]') IS DISTINCT FROM NEW.data->'decoupage'
 THEN RAISE EXCEPTION 'archive_sans_acte_confirme';END IF;
 IF nature='accord_tacite' AND NOT coalesce((p->>'accordTacite')::boolean,false) THEN RAISE EXCEPTION 'accord_tacite_non_confirme';END IF;
 RETURN NEW;
END;$f$;
REVOKE ALL ON FUNCTION public.urbanisme_archive_canoniser(),public.urbanisme_archive_attester(),public.urbanisme_archive_verifier_final() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS urbanisme_archive_canonique ON public.dossiers_urbanisme;
CREATE TRIGGER urbanisme_archive_canonique BEFORE INSERT ON public.dossiers_urbanisme FOR EACH ROW EXECUTE FUNCTION public.urbanisme_archive_canoniser();
DROP TRIGGER IF EXISTS urbanisme_archive_attestation ON public.dossiers_urbanisme;
CREATE TRIGGER urbanisme_archive_attestation AFTER INSERT ON public.dossiers_urbanisme FOR EACH ROW EXECUTE FUNCTION public.urbanisme_archive_attester();
DROP TRIGGER IF EXISTS urbanisme_archive_acte_final ON public.dossiers_urbanisme;
CREATE CONSTRAINT TRIGGER urbanisme_archive_acte_final AFTER INSERT ON public.dossiers_urbanisme
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.urbanisme_archive_verifier_final();
DO $g$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.objet_sas_deposer(text,text,jsonb,text)') AND md5(prosrc) IN ('5be54b74273872b4bdd5302777d9fa7a','bd5ccd4ef395201c5c4c8c87378993c1')) THEN RAISE EXCEPTION 'definition_non_examinee: objet_sas_deposer';END IF;
END;$g$;
CREATE OR REPLACE FUNCTION public.objet_sas_deposer(p_motif text, p_destinataire text, p_objet jsonb, p_reference text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_acteur text;
  v_vol record;
  v_nouveau_type text;
  v_demandeur text;
  v_expediteur text;
  v_id text; v_archive jsonb; v_deja text;
BEGIN
  v_acteur := public.mon_personnage();
  IF v_acteur IS NULL AND NOT (p_motif='document_urbanisme' AND public.est_appel_serveur()) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF coalesce(btrim(coalesce(p_destinataire, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_invalide');
  END IF;
  IF p_objet IS NULL OR jsonb_typeof(p_objet) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'objet_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_destinataire) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_introuvable');
  END IF;

  IF p_motif = 'butin_vol' THEN
    -- La victime depose le butin pour le voleur. La ligne de vol est la piece justificative :
    -- elle doit exister, designer l'acteur comme victime et le destinataire comme voleur.
    SELECT * INTO v_vol FROM public.vols_en_attente
     WHERE id = p_reference FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vol_introuvable', 'reference', p_reference);
    END IF;
    IF v_vol.victime IS DISTINCT FROM v_acteur THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'pas_la_victime');
    END IF;
    IF v_vol.voleur IS DISTINCT FROM p_destinataire THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'destinataire_pas_le_voleur');
    END IF;
    -- Anti-rejeu : un butin deja confirme ne se depose pas deux fois.
    IF v_vol.type_butin IN ('matiere_confirmee', 'objet_confirme') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'butin_deja_confirme');
    END IF;
    v_nouveau_type := CASE v_vol.type_butin
      WHEN 'matiere' THEN 'matiere_confirmee'
      WHEN 'objet'   THEN 'objet_confirme'
      ELSE NULL END;
    IF v_nouveau_type IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'type_butin_non_transferable',
                                'type_butin', v_vol.type_butin);
    END IF;
    v_expediteur := 'Butin de vol';

  ELSIF p_motif = 'document_urbanisme' THEN
    SELECT d.data,d.demandeur,a.objet_id INTO v_archive,v_demandeur,v_deja
    FROM public.urbanisme_archives_attestees a JOIN public.dossiers_urbanisme d ON d.id=a.archive
    WHERE a.archive=p_reference FOR UPDATE OF a;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','archive_non_attestee'); END IF;
    IF v_demandeur IS DISTINCT FROM p_destinataire THEN RETURN jsonb_build_object('ok',false,'raison','destinataire_pas_le_demandeur'); END IF;
    IF v_acteur IS DISTINCT FROM v_demandeur AND NOT EXISTS(
      SELECT 1 FROM public.urbanisme_archives_attestees WHERE archive=p_reference AND emetteur=v_acteur
    ) AND NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok',false,'raison','emetteur_non_autorise'); END IF;
    IF v_deja IS NOT NULL THEN RETURN jsonb_build_object('ok',true,'rejeu',true,'id',v_deja,'destinataire',v_demandeur); END IF;
    -- L'objet est construit a partir de l'archive attestee : aucun champ du navigateur ne devient un droit.
    p_objet:=jsonb_build_object('id',p_reference,'type','document_urbanisme_'||(v_archive->>'nature'),
      'name','Document d urbanisme — '||(v_archive->>'nature'),'icon','ti-file-text','legal',true,'documentUrbanisme',v_archive);
    v_expediteur := 'Services d''urbanisme';

  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'motif_non_declare', 'motif', p_motif);
  END IF;

  v_id := 'objet-recu-' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
  VALUES (v_id, p_destinataire, v_expediteur, to_jsonb(p_objet::text));

  IF p_motif='document_urbanisme' THEN UPDATE public.urbanisme_archives_attestees SET objet_id=v_id WHERE archive=p_reference; END IF;

  -- Meme transaction que le depot : le marquage du butin ne peut plus rester en arriere.
  IF p_motif = 'butin_vol' THEN
    UPDATE public.vols_en_attente SET type_butin = v_nouveau_type WHERE id = p_reference;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'destinataire', p_destinataire,
                            'motif', p_motif, 'type_butin', v_nouveau_type);
END;
$function$;
COMMIT;
