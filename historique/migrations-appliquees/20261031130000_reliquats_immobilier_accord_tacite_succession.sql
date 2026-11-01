-- Reliquats immobiliers des PR #139 et #71 (Claude, 31/10/2026). Compatible avec l'écran en ligne.
--
-- 1. Accord tacite de nuit (reprise de 20261024140830_permis_document_sas_serveur, PR #139,
--    jamais appliquée) : la passe de minuit appelle terrain_permis_instruction_jour sous le rôle
--    service_role, sans personnage. objet_sas_deposer refusait alors le dépôt de l'attestation
--    (acteur_non_authentifie), l'instruction levait document_accord_non_confirme et toute la
--    transaction était annulée : aucun permis ne pouvait être accordé tacitement, la nuit
--    rejouait l'échec indéfiniment. Seul le motif document_urbanisme est ouvert à l'appel
--    serveur ; il reste justifié par l'archive municipale qui nomme le demandeur.
--
-- 2. Succession (reprise partielle de 20261021220316_succession_titres_canoniques, PR #71) :
--    succession_regler transmettait le terrain dans la fiche (data.proprietaire) mais laissait
--    les colonnes proprietaire et coproprietaire au nom du défunt. Or les fonctions serveur
--    (titulaire_est_moi, loyers, permis, notaire) lisent ces colonnes : l'héritier n'aurait pas
--    été reconnu comme titulaire. Aucune succession n'a encore été réglée en production.
BEGIN;

DO $sas$ DECLARE h text; d text; BEGIN
  SELECT md5(prosrc), pg_get_functiondef(oid) INTO h, d FROM pg_proc
   WHERE oid = to_regprocedure('public.objet_sas_deposer(text,text,jsonb,text)');
  IF h = '5be54b74273872b4bdd5302777d9fa7a' THEN
    IF (length(d) - length(replace(d, 'IF v_acteur IS NULL THEN', ''))) / length('IF v_acteur IS NULL THEN') <> 1 THEN
      RAISE EXCEPTION 'objet_sas_deposer: point de raccordement non unique';
    END IF;
    d := replace(d, 'IF v_acteur IS NULL THEN',
      'IF v_acteur IS NULL AND NOT (coalesce(p_motif=''document_urbanisme'',false) AND coalesce(public.est_appel_serveur(),false)) THEN');
    EXECUTE d;
  ELSIF h IS DISTINCT FROM 'c1d3cdf82694cd31d6aabe7496634d63' THEN
    RAISE EXCEPTION 'definition_non_examinee: objet_sas_deposer (%)', h;
  END IF;
END; $sas$;

DO $succ$ DECLARE h text; d text; avant text; BEGIN
  SELECT md5(prosrc), pg_get_functiondef(oid) INTO h, d FROM pg_proc
   WHERE oid = to_regprocedure('public.succession_regler(text)');
  avant := 'UPDATE public.terrains_etat SET data = v_etat::text, updated_at = now() WHERE id = v_tid;';
  IF h = '4b45ea34b0888a3776a7798ddad7149a' THEN
    IF (length(d) - length(replace(d, avant, ''))) / length(avant) <> 1 THEN
      RAISE EXCEPTION 'succession_regler: point de raccordement non unique';
    END IF;
    d := replace(d, avant,
      'UPDATE public.terrains_etat SET proprietaire = v_benef, coproprietaire = NULL, data = v_etat::text, updated_at = now() WHERE id = v_tid;');
    EXECUTE d;
  ELSIF h IS DISTINCT FROM '15e1ddab10ad856bca75c492fd64396c' THEN
    RAISE EXCEPTION 'definition_non_examinee: succession_regler (%)', h;
  END IF;
END; $succ$;

COMMIT;
