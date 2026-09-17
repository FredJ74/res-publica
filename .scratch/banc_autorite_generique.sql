-- =====================================================================================
-- BANC D'AUTORITE GENERIQUE — Res Publica, 17 septembre 2026
--
-- POURQUOI CE BANC EXISTE. Les bancs des passes 1 et 2 jugeaient parfois une attaque sur la seule
-- levee d'une EXCEPTION. Or une RPC de ce projet refuse le plus souvent en RENVOYANT
-- {"ok":false,"raison":...}, sans lever. Un bloc « EXCEPTION WHEN insufficient_privilege » ne voit
-- donc pas ce refus et conclut « ACCEPTE — FAILLE » a tort. C'est exactement ce qui s'est produit
-- sur caisse_ministere_mouvement (cas « meme poste, autre empire »), reclasse apres verification.
--
-- REGLE DE JUGEMENT DE CE BANC, par ordre de priorite :
--   1. L'ETAT A-T-IL CHANGE ? C'est le juge souverain. Un etat modifie = ACCEPTE, quoi que dise
--      le retour. Un etat inchange ne peut jamais etre une faille.
--   2. Sinon, une exception = refus.
--   3. Sinon, un retour {"ok":false} = refus (la raison est conservee).
--   4. Sinon, {"ok":true} sans changement d'etat = ACCEPTE SANS EFFET (a examiner : soit
--      l'operation etait un no-op legitime, soit l'etat observe est incomplet).
--
-- AUTRE PIEGE DEJA RENCONTRE, applique ici : sans « SET LOCAL request.jwt.claims », la fonction
-- est_appel_serveur() retombe sur 'service_role' et rend TRUE -- toute attaque passerait alors
-- pour un appel serveur legitime (faux negatif). Chaque scenario pose donc ses claims explicitement.
--
-- Tout tourne dans une transaction ANNULEE. Aucune donnee de production n'est modifiee.
-- =====================================================================================
BEGIN;

CREATE TEMP TABLE banc(
  n int, scenario text, attendu text, exception text, retour jsonb,
  etat_change boolean, verdict text, detail text
) ON COMMIT DROP;

-- Instantane de tout ce que les attaques pourraient bouger. Toute valeur susceptible d'etre
-- modifiee par un scenario DOIT figurer ici, sinon le juge n°1 est aveugle.
CREATE OR REPLACE FUNCTION pg_temp.etat() RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object(
    'caisses', (SELECT COALESCE(jsonb_object_agg(id, data), '{}'::jsonb)
                  FROM public.caisses_batiments
                 WHERE id IN ('republic_gouvernement-min_fin','republic_gouvernement-min_def',
                              'republic_gouvernement-min_just','republic_caserne-militaire',
                              'narco_gouvernement-min_def','republic_qhs-prison')),
    'caisses_total', (SELECT count(*) FROM public.caisses_batiments),
    'tribune', (SELECT data FROM public.batiments_etat WHERE id='republic_capitale_la-tribune'),
    'batiments_total', (SELECT count(*) FROM public.batiments_etat),
    'dons', (SELECT count(*) FROM public.dons_en_attente),
    'vols', (SELECT count(*) FROM public.vols_en_attente),
    'perso', (SELECT COALESCE(jsonb_object_agg(name, jsonb_build_object(
                  'arg', arg, 'liquide', liquide, 'pa', pa,
                  'resources', resources, 'convocations', convocations, 'poste', poste)), '{}'::jsonb)
                FROM public.personnages_donnees WHERE name IN ('Arnie','Phileas Frogg')),
    'terrains', (SELECT count(*) FROM public.terrains_etat),
    'chronique', (SELECT count(*) FROM public.chronique_nationale)
  );
$$;

-- Execute un scenario : pose les claims, capture etat avant/apres, exception et retour.
CREATE OR REPLACE PROCEDURE pg_temp.attaque(
  p_n int, p_scenario text, p_attendu text, p_claims text, p_sql text)
LANGUAGE plpgsql AS $$
DECLARE
  v_avant jsonb; v_apres jsonb; v_ret jsonb; v_exc text; v_change boolean; v_verdict text;
BEGIN
  v_avant := pg_temp.etat();
  BEGIN
    PERFORM set_config('request.jwt.claims', p_claims, true);
    EXECUTE p_sql INTO v_ret;
    v_exc := NULL;
  EXCEPTION WHEN OTHERS THEN
    v_ret := NULL; v_exc := SQLERRM;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  v_apres := pg_temp.etat();
  v_change := (v_apres IS DISTINCT FROM v_avant);

  v_verdict := CASE
    WHEN v_change THEN 'ACCEPTE (etat modifie)'
    WHEN v_exc IS NOT NULL THEN 'refuse (exception)'
    WHEN v_ret IS NOT NULL AND (v_ret->>'ok') = 'false' THEN 'refuse (ok=false)'
    WHEN v_ret IS NOT NULL AND (v_ret->>'ok') = 'true' THEN 'ACCEPTE SANS EFFET'
    ELSE 'indetermine'
  END;

  INSERT INTO banc VALUES (p_n, p_scenario, p_attendu, v_exc, v_ret, v_change, v_verdict,
    COALESCE(v_ret->>'raison', left(COALESCE(v_exc,''), 90)));
END;
$$;
