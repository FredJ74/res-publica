-- Banc des reliquats immobiliers (migration 20261031130000). Production, transaction ANNULÉE :
-- tout se termine par RAISE EXCEPTION, rien n'est conservé. À lancer d'un bloc.
-- Contre-épreuve : avant la migration, l'accord tacite de nuit échoue et l'héritier n'est pas
-- inscrit dans la colonne proprietaire ; après, les deux fonctionnent.
BEGIN;
SELECT set_config('banc.res', '{}', false);
CREATE OR REPLACE FUNCTION pg_temp.banc_noter(k text, v jsonb) RETURNS void LANGUAGE sql AS
$f$ SELECT set_config('banc.res', (current_setting('banc.res')::jsonb || jsonb_build_object(k, v))::text, false) $f$;
GRANT EXECUTE ON FUNCTION pg_temp.banc_noter(text, jsonb) TO PUBLIC;

-- Préparation : permis de Jean Jaaj (terrain 5) à son dernier jour d'instruction ;
-- terrain 3 au nom d'un défunt fictif, succession fictive en faveur de Jean Jaaj.
UPDATE public.terrains_etat SET data = jsonb_set(jsonb_set(data::jsonb, '{permis,joursInstructionFaits}',
  to_jsonb((data::jsonb->'permis'->>'dureeInstruction')::integer - 1)), '{permis,jourInstruction}', '"2000-01-01"')::text
 WHERE id = 'republic_terrain-a-batir-5' AND data::jsonb->'permis'->>'statut' = 'instruction';
UPDATE public.terrains_etat SET proprietaire = 'Banc Défunt', coproprietaire = NULL,
  data = jsonb_set(data::jsonb, '{proprietaire}', '"Banc Défunt"')::text WHERE id = 'republic_terrain-a-batir-3';
INSERT INTO public.successions(id, defunt, country, dispositions) VALUES
 ('banc-succ', 'Banc Défunt', 'republic', '[{"type":"terrain","id":"terrain-a-batir-3","resultat":{"beneficiaire":"Jean Jaaj"}}]');
-- (une seule succession : la contre-épreuve est annulée, la succession reste donc en attente)

-- Contre-épreuve (avant migration)
DO $avant$ DECLARE r jsonb; v jsonb; BEGIN
  BEGIN
    SET LOCAL ROLE service_role;
    r := public.terrain_permis_instruction_jour('republic_terrain-a-batir-5');
    RESET ROLE;
    PERFORM pg_temp.banc_noter('avant_accord_tacite', r);
  EXCEPTION WHEN others THEN PERFORM pg_temp.banc_noter('avant_accord_tacite', to_jsonb('exception: ' || SQLERRM));
  END;
  BEGIN
    r := public.succession_regler('banc-succ');
    v := jsonb_build_object('retour', r, 'colonne',
      (SELECT proprietaire FROM public.terrains_etat WHERE id = 'republic_terrain-a-batir-3'),
      'fiche', (SELECT data::jsonb->>'proprietaire' FROM public.terrains_etat WHERE id = 'republic_terrain-a-batir-3'));
    RAISE EXCEPTION 'annuler_contre_epreuve';
  EXCEPTION WHEN others THEN
    PERFORM pg_temp.banc_noter('avant_succession', coalesce(v, to_jsonb('exception: ' || SQLERRM)));
  END;
END; $avant$;

-- Corps exact de la migration (sans BEGIN/COMMIT)
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


-- Après migration
DO $apres$ DECLARE r jsonb; n0 integer; BEGIN
  PERFORM pg_temp.banc_noter('md5_apres', jsonb_build_object(
    'objet_sas_deposer', (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure('public.objet_sas_deposer(text,text,jsonb,text)')),
    'succession_regler', (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure('public.succession_regler(text)'))));
  SELECT count(*) INTO n0 FROM public.objets_recus WHERE destinataire = 'Jean Jaaj';
  SET LOCAL ROLE service_role;
  r := public.terrain_permis_instruction_jour('republic_terrain-a-batir-5');
  RESET ROLE;
  PERFORM pg_temp.banc_noter('apres_accord_tacite', jsonb_build_object('retour', r,
    'statut', (SELECT data::jsonb->'permis'->>'statut' FROM public.terrains_etat WHERE id = 'republic_terrain-a-batir-5'),
    'attestations_recues', (SELECT count(*) FROM public.objets_recus WHERE destinataire = 'Jean Jaaj') - n0));
  -- Un joueur ne peut toujours pas déposer de document d'urbanisme sans personnage.
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"00000000-0000-0000-0000-000000000000"}', true);
  r := public.objet_sas_deposer('document_urbanisme', 'Jean Jaaj', '{"id":"x"}'::jsonb, 'x');
  RESET ROLE;
  PERFORM pg_temp.banc_noter('joueur_sans_personnage', r);
  r := public.succession_regler('banc-succ');
  PERFORM pg_temp.banc_noter('apres_succession', jsonb_build_object('retour', r, 'colonne',
    (SELECT proprietaire FROM public.terrains_etat WHERE id = 'republic_terrain-a-batir-3'),
    'fiche', (SELECT data::jsonb->>'proprietaire' FROM public.terrains_etat WHERE id = 'republic_terrain-a-batir-3')));
  RAISE EXCEPTION 'BANC %', current_setting('banc.res');
END; $apres$;
ROLLBACK;
