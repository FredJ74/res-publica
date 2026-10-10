-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010152035 (UTC), nom `terrain_reamenagement_et_le_proprietaire_du_depot`.
-- Le registre passe de 621 a 622 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 b04a85fa0519cca23ed0ac0a7b9f7cd5, 6588 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- DEUX DERNIERS ACTES -- ET `sbSetTerrainState` N'A PLUS AUCUN APPELANT
--
-- Acte 1 : `confirmerReconfiguration` lisait deja son resultat, mais envoyait l'etat compose dans
-- le cache et pouvait donc effacer la nuit du cron ; elle recoit une porte dediee plutot qu'un acte
-- de `terrain_chantier_acte` (une signature de plus creerait une SECONDE fonction, et un `DROP`
-- demanderait une confirmation interactive que ce lot ne peut obtenir). La dette des deux appels
-- separes -- paiement puis ecriture -- reste consignee telle quelle. Acte 2 : `terrain_permis_acte`
-- ne verifiait pas la propriete pour `permis_deposer`, alors que la regle existait a l'ecran.
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- DEUX DERNIERS ACTES -- et `sbSetTerrainState` n'a plus aucun appelant
-- Chantier 5, les 22 ecritures de `terrains_etat` (10 octobre 2026).
--
-- ACTE 1 -- LE CHANTIER DE REAMENAGEMENT. `confirmerReconfiguration` etait l'une des TROIS
-- ecritures sur 22 qui lisaient deja leur resultat : a la difference de la construction, le
-- reamenagement n'a pas de `chantier_lancer`, et cette ecriture est la SEULE qui fait exister le
-- chantier apres un financement integral deja preleve. Elle n'avait donc pas le defaut des
-- dix-neuf autres -- mais elle envoyait l'etat compose dans le cache, donc elle pouvait effacer
-- la nuit du cron.
--
-- POURQUOI UNE PORTE A PART, ET PAS UN ACTE DE `terrain_chantier_acte`. Un acte de plus y
-- demanderait un parametre `jsonb` de plus, donc une AUTRE signature -- et `CREATE OR REPLACE`
-- sur une signature differente ne remplace rien : il cree une SECONDE fonction, les deux vivant
-- cote a cote (le piege documente au chantier 4G). La supprimer d'abord est possible, mais un
-- `DROP` dans ce canal de migration demande une confirmation interactive que ce lot ne peut pas
-- obtenir. Une porte dediee est donc le choix honnete : elle passe par le MEME ecrivain interne,
-- applique la MEME regle de propriete et la MEME liste de cles.
--
-- LA DETTE RESTE CONSIGNEE TELLE QUELLE : le paiement et cette ecriture demeurent DEUX appels.
-- Les rendre atomiques demande une porte `chantier_reamenagement_lancer` sur le modele de
-- `chantier_lancer`, et l'inventer ici dupliquerait un moteur de chantier.
--
-- ACTE 2 -- LE DEPOT D'UN PERMIS EST RESERVE AU PROPRIETAIRE, et la regle existait :
--   `doDeposerDemandePermis` -> if (!estTitulaire(ts.proprietaire)) « Vous n'etes pas proprietaire »
-- `terrain_permis_acte` ne la verifiait pas pour l'acte `permis_deposer` : un oubli de ma part,
-- trouve en relisant les dix-sept `estTitulaire` de plateau-justice-economie.js. Le detenteur d'un
-- compromis, lui, obtient son permis par l'acte `compromis_signer` -- chemin distinct, inchange.

CREATE OR REPLACE FUNCTION public.terrain_reamenagement_poser(
  p_terrain_id text, p_chantier jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $fn$
DECLARE v_moi text; v_pays text; v_lu jsonb; v_etat jsonb; v_final jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_chantier IS NULL OR jsonb_typeof(p_chantier) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_absent');
  END IF;
  SELECT d.country INTO v_pays FROM public.personnages_donnees d WHERE d.name = v_moi LIMIT 1;

  v_lu := public.terrain_etat_verrouiller_interne(p_terrain_id);
  v_etat := v_lu -> 'etat';
  IF (v_lu ->> 'gele')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_gele');
  END IF;
  -- LA REGLE DES DEUX ECRANS DE RECONFIGURATION, lue en base :
  --   if (!estTitulaire(ts.proprietaire)) « Vous n'etes pas proprietaire de ce batiment. »
  IF NOT public.titulaire_est_moi(v_etat ->> 'proprietaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;
  -- LISTE DE CLES, en dur : cette porte n'ecrit QUE son propre chantier. Elle ne peut donc pas
  -- effacer `chantier`, `permis`, `subdivisions` ni le compromis, meme appelee par un client
  -- modifie ou par un ecran reste ouvert pendant la nuit du cron.
  v_final := public.terrain_etat_fusionner_interne(p_terrain_id,
               jsonb_build_object('chantierReamenagement', p_chantier), v_pays);
  RETURN jsonb_build_object('ok', true, 'etat', v_final);
END; $fn$;

REVOKE ALL ON FUNCTION public.terrain_reamenagement_poser(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.terrain_reamenagement_poser(text, jsonb) TO authenticated, service_role;

DO $m$
DECLARE v_def text; v_new text; v_ancre text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_permis_acte(text,text,jsonb)'::regprocedure);
  v_ancre := '    IF jsonb_typeof(v_patch -> ''permis'') <> ''object'' THEN';
  v_new := replace(v_def, v_ancre,
    E'    IF NOT public.titulaire_est_moi(v_etat ->> ''proprietaire'') THEN\n'
    || E'      RETURN jsonb_build_object(''ok'', false, ''raison'', ''pas_proprietaire'');\n'
    || E'    END IF;\n' || v_ancre);
  IF v_new = v_def THEN RAISE EXCEPTION 'l''ancre du depot de permis est introuvable'; END IF;
  EXECUTE v_new;
END $m$;

DO $p$
DECLARE v_def text; v integer;
BEGIN
  v_def := pg_get_functiondef('public.terrain_reamenagement_poser(text,jsonb)'::regprocedure);
  IF v_def NOT LIKE '%titulaire_est_moi%' THEN
    RAISE EXCEPTION 'le reamenagement ne verifie pas la propriete';
  END IF;
  IF v_def NOT LIKE '%terrain_etat_fusionner_interne%'
     OR v_def LIKE '%UPDATE public.terrains_etat%' THEN
    RAISE EXCEPTION 'le reamenagement n''utilise pas l''ecrivain unique';
  END IF;
  -- UNE SEULE CLE ECRITE, et elle est en dur dans le corps.
  IF (length(v_def) - length(replace(v_def, 'chantierReamenagement', '')))
     / length('chantierReamenagement') <> 1 THEN
    RAISE EXCEPTION 'le reamenagement ecrit plus que sa propre cle';
  END IF;
  IF NOT has_function_privilege('authenticated',
       'public.terrain_reamenagement_poser(text,jsonb)'::regprocedure, 'EXECUTE')
     OR has_function_privilege('anon',
       'public.terrain_reamenagement_poser(text,jsonb)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'les droits de la porte du reamenagement sont faux';
  END IF;

  v_def := pg_get_functiondef('public.terrain_permis_acte(text,text,jsonb)'::regprocedure);
  IF (length(v_def) - length(replace(v_def, 'titulaire_est_moi', '')))
     / length('titulaire_est_moi') <> 2 THEN
    RAISE EXCEPTION 'la porte du permis ne verifie pas la propriete aux DEUX actes qui l''exigent';
  END IF;

  -- LES HUIT PORTES DES TERRAINS EXISTENT, et seules elles sont appelables par un joueur.
  SELECT count(*) INTO v FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname IN ('terrain_compromis_acte', 'terrain_permis_acte',
     'terrain_chantier_acte', 'terrain_lots_acte', 'terrain_succession_geler',
     'terrain_succession_annuler_compromis', 'terrain_proprietaire_muter',
     'terrain_reamenagement_poser')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v <> 8 THEN RAISE EXCEPTION 'un joueur ne peut appeler que % portes de terrain sur 8', v; END IF;

  RAISE NOTICE 'Les 7 preuves structurelles des deux derniers actes sont vertes.';
END $p$;
