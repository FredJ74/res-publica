-- =====================================================================================
-- TERRAINS ET LOYERS DES LOTS — défauts reproduits le 29/10/2026
-- (Claude, chantier terrains / immobilier / prêts / placements confié par Fred).
-- Chaque défaut a été reproduit au rôle authenticated, en transaction annulée, sur la base
-- réelle (Arnie, terrain-a-batir-1 et -4). Aucun joueur réel modifié.
--
-- 1. CONSTRUIRE SANS PERMIS ACCORDÉ. Les terrains 1, 2 et 3 de Luthécia portent encore
--    `constructionAutorisee: true` (reliquat d'anciens essais), et l'achat le conserve. Le
--    lancement du chantier ne vérifiait que ce drapeau et le palier demandé : un acheteur
--    déposait son permis et lançait aussitôt les travaux, permis encore « en instruction ».
--    -> le lancement exige un permis au statut `valide` ; le drapeau des terrains sans
--       propriétaire ni permis accordé est remis à faux.
--
-- 2. LOTS LOUÉS GRATUITEMENT, POUR TOUJOURS. Depuis #57, les lots naissent du plan validé
--    pendant le chantier, avec un loyer de 0 ; l'ancien acte qui fixait le loyer à la création
--    (`lot_ajouter`) est fermé, et aucun autre ne permettait de le fixer. Une location signée
--    donnait donc un bail à 0 FR, jamais prélevé.
--    -> nouvelle porte `terrain_lot_loyer_fixer` (titulaire des murs, lot libre) ;
--       un lot sans loyer fixé ne peut plus être loué (`loyer_non_fixe`).
--
-- (Le défaut 3, placements, est dans 20261029094135.)
--
-- Idempotente : chaque patch en place est ignoré s'il est déjà posé.
-- =====================================================================================

-- 1a. Le lancement exige un permis accordé.
DO $mig$
DECLARE v_def text; v_new text;
  v_ancien text := $a$IF NOT coalesce((etat->>'constructionAutorisee')::boolean,false) OR etat->'permis'->>'palierDemande' IS DISTINCT FROM p_parametres->>'palier' THEN RAISE EXCEPTION 'permis_non_conforme';END IF;$a$;
  v_nouveau text := $n$IF NOT coalesce((etat->>'constructionAutorisee')::boolean,false) OR etat->'permis'->>'statut' IS DISTINCT FROM 'valide' OR etat->'permis'->>'palierDemande' IS DISTINCT FROM p_parametres->>'palier' THEN RAISE EXCEPTION 'permis_non_conforme';END IF;$n$;
BEGIN
  v_def := pg_get_functiondef('public.chantier_commande(text,text,text,jsonb)'::regprocedure);
  IF strpos(v_def, v_nouveau) > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_ancien, v_nouveau);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch lancement non applique : fragment introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- 1b. Reliquat : aucun terrain sans propriétaire ni permis accordé n'est « constructible ».
UPDATE public.terrains_etat
   SET data = (data::jsonb || '{"constructionAutorisee":false}'::jsonb)::text, updated_at = now()
 WHERE nullif(proprietaire, '') IS NULL
   AND nullif(data::jsonb->>'proprietaire', '') IS NULL
   AND coalesce((data::jsonb->>'constructionAutorisee')::boolean, false)
   AND data::jsonb->'permis'->>'statut' IS DISTINCT FROM 'valide';

-- 2a. Un lot sans loyer fixé ne se loue pas.
DO $mig$
DECLARE v_def text; v_new text;
  v_ancien text := $a$ loyer:=(lot->>'loyer')::numeric;$a$;
  v_nouveau text := $n$ loyer:=(lot->>'loyer')::numeric;
 IF coalesce(loyer,0)=0 THEN RAISE EXCEPTION 'loyer_non_fixe';END IF;$n$;
BEGIN
  v_def := pg_get_functiondef('public.location_lot_enregistrer_interne(jsonb,text,text,text,text,integer)'::regprocedure);
  IF strpos(v_def, 'loyer_non_fixe') > 0 THEN RETURN; END IF;
  v_new := replace(v_def, v_ancien, v_nouveau);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch location non applique : fragment introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- 2a bis. Le refus est rendu au joueur comme les autres refus de commande, pas en erreur brute.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.chantier_commande(text,text,text,jsonb)'::regprocedure);
  IF strpos(v_def, '''loyer_non_fixe''') > 0 THEN RETURN; END IF;
  v_new := replace(v_def, $a$'loyer_invalide','premier_loyer_refuse'$a$, $n$'loyer_invalide','loyer_non_fixe','premier_loyer_refuse'$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch refus location non applique : fragment introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- 2a ter. LE PREMIER LOYER D'UN LOT FAISAIT ÉCHOUER LA LOCATION. `prelever_loyer_bail`
-- crédite le PJ titulaire des murs par la vue `personnages`, dont le déclencheur refuse
-- d'écrire la fiche d'un autre joueur (« personnage_non_possede ») quand c'est le locataire
-- qui signe. La passe de minuit (service) passait ; la signature, jamais. Même défaut que la
-- calomnie corrigée le 28/10 : on écrit la table, pas la vue. Invisible tant que les lots
-- valaient 0 FR.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.prelever_loyer_bail(text)'::regprocedure);
  IF strpos(v_def, 'UPDATE public.personnages_donnees
      SET arg = COALESCE(arg, 0) + v_prix') > 0 THEN RETURN; END IF;
  v_new := replace(v_def, $a$UPDATE personnages
      SET arg = COALESCE(arg, 0) + v_prix,$a$, $n$UPDATE public.personnages_donnees
      SET arg = COALESCE(arg, 0) + v_prix,$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch credit titulaire non applique : fragment introuvable'; END IF;
  EXECUTE v_new;
END $mig$;

-- 2b. Le titulaire des murs fixe le loyer journalier d'un lot libre.
CREATE OR REPLACE FUNCTION public.terrain_lot_loyer_fixer(p_terrain_id text, p_lot text, p_loyer integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE moi text := public.mon_personnage(); p record; t record; etat jsonb; lot jsonb; sortie jsonb := '[]'; x jsonb;
BEGIN
  IF moi IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','acteur_non_authentifie'); END IF;
  IF p_lot IS NULL OR btrim(p_lot) = '' THEN RETURN jsonb_build_object('ok',false,'raison','lot_introuvable'); END IF;
  IF p_loyer IS NULL OR p_loyer < 1 OR p_loyer > 100000 THEN RETURN jsonb_build_object('ok',false,'raison','loyer_invalide'); END IF;
  SELECT * INTO p FROM public.personnages_donnees WHERE name = moi;
  IF coalesce(p.hp,0) <= 0 OR EXISTS(SELECT 1 FROM public.detention_active(moi)) THEN
    RETURN jsonb_build_object('ok',false,'raison','acteur_indisponible'); END IF;
  SELECT * INTO t FROM public.terrains_etat
   WHERE country = p.country AND (id = p_terrain_id OR building_id = p_terrain_id AND data::jsonb->>'city' = p.current_city)
   ORDER BY (id = p_terrain_id) DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'raison','terrain_introuvable'); END IF;
  etat := t.data::jsonb;
  IF coalesce(etat->>'succession_gel','') <> '' THEN RETURN jsonb_build_object('ok',false,'raison','terrain_gele'); END IF;
  -- Même autorité que le chantier : PJ titulaire, chef de l'organisation, maire de la commune.
  BEGIN
    PERFORM public.chantier_autorite_exiger_interne(etat->>'proprietaire', t.country, etat->>'city');
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok',false,'raison','pas_titulaire_des_murs');
  END;
  SELECT value INTO lot FROM jsonb_array_elements(coalesce(etat->'subdivisions','[]')) WHERE value->>'id' = p_lot;
  IF lot IS NULL THEN RETURN jsonb_build_object('ok',false,'raison','lot_introuvable'); END IF;
  -- Protection des baux : le loyer d'un lot occupé ne change pas en cours de bail.
  IF nullif(lot->>'locataire','') IS NOT NULL OR EXISTS(
       SELECT 1 FROM public.locations_actives
        WHERE country = t.country AND data->>'city' = etat->>'city' AND data->>'buildingId' = t.building_id
          AND data->>'roomId' = 'lot_dyn_'||regexp_replace(p_lot,'[^A-Za-z0-9_-]','_','g')) THEN
    RETURN jsonb_build_object('ok',false,'raison','lot_occupe'); END IF;
  IF etat->'chantierReamenagement'->'lotsConcernes' ? p_lot THEN
    RETURN jsonb_build_object('ok',false,'raison','lot_en_travaux'); END IF;
  IF (lot->>'loyer') = p_loyer::text THEN
    RETURN jsonb_build_object('ok',true,'rejeu',true,'etat',etat); END IF;
  FOR x IN SELECT value FROM jsonb_array_elements(etat->'subdivisions') LOOP
    sortie := sortie || jsonb_build_array(CASE WHEN x->>'id' = p_lot THEN x || jsonb_build_object('loyer', p_loyer) ELSE x END);
  END LOOP;
  etat := etat || jsonb_build_object('subdivisions', sortie,
    'lotsHistorique', coalesce(etat->'lotsHistorique','[]') || jsonb_build_array(jsonb_build_object(
      'acte','loyer_fixe','acteur',moi,'lot',p_lot,'loyer',p_loyer,'date',statement_timestamp())));
  UPDATE public.terrains_etat SET data = etat::text, updated_at = now() WHERE id = t.id;
  RETURN jsonb_build_object('ok',true,'etat',etat,'lot',p_lot,'loyer',p_loyer);
END;
$function$;
REVOKE ALL ON FUNCTION public.terrain_lot_loyer_fixer(text,text,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.terrain_lot_loyer_fixer(text,text,integer) TO authenticated;

