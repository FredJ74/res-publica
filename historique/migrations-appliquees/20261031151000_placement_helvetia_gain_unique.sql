-- Placement Helvetia : le gain net était versé deux fois (Claude, 31/10/2026, suite de #267).
-- Compatible avec l'écran en ligne (la fonction n'est appelée que par la passe de nuit) ;
-- aucune donnée de joueur modifiée.
--
-- resoudre_placement_helvetia (règles inchangées : 8 % de gain brut, 30 % de frais, 50 % d'impôt
-- si le placement est déclaré) :
--   * le gain net était crédité sur le compte Helvetia ET ajouté à `arg`. Or `arg` est l'argent
--     total liquide + Banque nationale (fiche par défaut : 4 250 = 500 + 3 750) ; le compte
--     Helvetia n'y entre pas. Le gain apparaissait donc une seconde fois dans l'argent total.
--     Le compte Helvetia seul est crédité, comme l'annonce le courrier.
--   * la caisse `<pays>_banque-privee` (argent détenu par la banque, #267) ne recevait que les
--     frais ; le gain net, versé sur un compte que la banque détient, y entre aussi. Sinon un
--     retrait ultérieur de ce gain viderait la caisse d'un argent qu'elle n'a jamais reçu.
-- Constat : finaliser_achat_bien_helvetia n'est pas en cause : acompte et solde sont pris sur les
-- fonds ordinaires (liquide puis Banque nationale), jamais sur le compte Helvetia ; créditer la
-- caisse du prix entier est donc juste.
-- Banc : outils/bancs/banc-placement-helvetia.sql
BEGIN;

CREATE FUNCTION pg_temp.helvetia_corriger(p_sig text, p_avant text, p_apres text,
  p_regles text[]) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE h text; d text; i integer; n integer;
BEGIN
  SELECT md5(prosrc), pg_get_functiondef(oid) INTO h, d FROM pg_proc WHERE oid = to_regprocedure(p_sig);
  IF h = p_apres THEN RETURN; END IF;
  IF h IS DISTINCT FROM p_avant THEN RAISE EXCEPTION 'definition_non_examinee: % (%)', p_sig, h; END IF;
  FOR i IN 1 .. array_length(p_regles, 1) BY 2 LOOP
    SELECT count(*) INTO n FROM regexp_matches(d, p_regles[i], 'g');
    IF n <> 1 THEN RAISE EXCEPTION '%: motif % trouvé % fois', p_sig, (i + 1) / 2, n; END IF;
    d := regexp_replace(d, p_regles[i], p_regles[i + 1]);
  END LOOP;
  EXECUTE d;
  SELECT md5(prosrc) INTO h FROM pg_proc WHERE oid = to_regprocedure(p_sig);
  IF h IS DISTINCT FROM p_apres THEN RAISE EXCEPTION '%: empreinte après correction inattendue (%)', p_sig, h; END IF;
END $f$;

SELECT pg_temp.helvetia_corriger('public.resoudre_placement_helvetia(text)',
  'b81e7fdddb348bdabc34639429b1a139', '143ce2357e533df73cf91e38861a1ff4', ARRAY[
  $m$numeric, 0\) \+ v_frais\)$m$, $r$numeric, 0) + v_frais + v_gain_net)$r$,
  $m$jsonb_build_object\('solde', v_frais\)$m$, $r$jsonb_build_object('solde', v_frais + v_gain_net)$r$,
  $m$\n\s*UPDATE public\.personnages_donnees\s+set arg = coalesce\(arg, 0\) \+ v_gain_net\s+where name = v_placement\.personnage;$m$,
  E'\n  -- Le gain net va sur le compte Helvetia seul : `arg` (liquide + Banque nationale) ne bouge pas.'
]);

COMMIT;
