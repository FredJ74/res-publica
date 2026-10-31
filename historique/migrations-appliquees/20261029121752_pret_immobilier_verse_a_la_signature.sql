-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261029121752.
-- Archivage documentaire seulement ; ne pas rejouer.
-- PRÊT IMMOBILIER NATIONAL VERSÉ À LA SIGNATURE (29/10/2026, Claude).
-- Règle #57-11 (décidée) : prêt national sous compromis, accord sous 7 j sinon tacite,
-- DÉBLOCAGE SEULEMENT à la signature définitive. Le code versait les fonds dès l'accord
-- (échéance du compromis) : le joueur disposait de l'argent sans avoir signé.
-- -> `compromis_expire_resoudre` n'accorde plus que le statut (terrain) ;
--    l'acte notarié (`terrain_acquisition_commande`, acte_compromis) crée le prêt dans la
--    même transaction que le paiement. `pret_national_creer_interne` est idempotent : un
--    prêt déjà versé par l'ancien circuit n'est pas versé deux fois. Idempotente.
DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.compromis_expire_resoudre(text,text)'::regprocedure);
  IF strpos(v_def, 'pret verse a la signature') > 0 THEN RETURN; END IF;
  v_new := regexp_replace(v_def,
    'PERFORM public\.pret_national_creer_interne\(v_pret->>''demandeur''.*?r\.action=''compromis''\)\);',
    '-- pret verse a la signature (acte notarie), plus a l''accord');
  IF v_new = v_def THEN RAISE EXCEPTION 'patch accord non applique'; END IF;
  v_new := replace(v_new, $a$'prêt accordé (+' || v_montant::text || ' FR virés)'$a$,
    $n$CASE WHEN v_type='terrain' THEN 'prêt accordé (' || v_montant::text || ' FR versés à la signature)' ELSE 'prêt accordé (+' || v_montant::text || ' FR virés)' END$n$);
  EXECUTE v_new;
END $mig$;

DO $mig$
DECLARE v_def text; v_new text;
BEGIN
  v_def := pg_get_functiondef('public.terrain_acquisition_commande(text,text,jsonb,uuid)'::regprocedure);
  IF strpos(v_def, 'pret verse a la signature') > 0 THEN RETURN; END IF;
  v_new := replace(v_def, $a$ r:=public.payer_ordre(moi,ordre,pa,montant::integer);$a$,
    $n$ -- pret verse a la signature : le capital arrive juste avant le paiement de l'acte.
 IF p_action='acte_compromis' AND e->'pretDemande'->>'statut'='accorde' THEN
  r:=public.pret_national_creer_interne(moi,(e->'pretDemande'->>'montant')::numeric,(e->'pretDemande'->>'duree')::integer,'immobilier',t.building_id,
    'acquisition-'||t.id||'-'||coalesce(e->>'acquisitionRequete',e->>'compromisAt'),
    (SELECT (x.resultat->'pretCapture'->>'taux')::numeric FROM public.terrain_acquisitions_recus x WHERE x.terrain=t.id AND x.requete::text=e->>'acquisitionRequete' AND x.action='compromis'));
 END IF;
 r:=public.payer_ordre(moi,ordre,pa,montant::integer);$n$);
  IF v_new = v_def THEN RAISE EXCEPTION 'patch acte non applique'; END IF;
  EXECUTE v_new;
END $mig$;
