-- Médecin payé en liquide seulement (Fred, 22/11/2026, soir, GAME-DESIGN-SANTE-20261122.md, « Suites », point 5 :
-- « tous les paiements se font en liquide ; la banque est un dépôt volontaire du joueur »).
-- medecin_repondre (texte de production) : le contrôle des fonds ne compte plus le compte en banque, et le débit
-- se fait en liquide seulement. Un patient sans assez de liquide reçoit le refus « fonds_insuffisants » avant tout
-- prélèvement (comportement existant). Rejouable. Rien d'autre n'est modifié.
CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_n integer, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> p_n THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de % (%)', p_fn, n, p_n, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : marque absente', p_fn; END IF;
END $$;

SELECT pg_temp.rp_remplacer('public.medecin_repondre(bigint,boolean)'::regprocedure,
  $a$v_dispo := greatest(coalesce(pt.liquide, 0), 0) + coalesce((SELECT greatest(solde, 0) FROM public.comptes_bancaires$a$,
  $b$v_dispo := greatest(coalesce(pt.liquide, 0), 0) /* medecin_liquide_v1 : la banque ne compte pas */ + 0 * coalesce((SELECT greatest(solde, 0) FROM public.comptes_bancaires$b$,
  1, 'medecin_liquide_v1');
SELECT pg_temp.rp_remplacer('public.medecin_repondre(bigint,boolean)'::regprocedure,
  $a$argent_debiter_interne(a, p.prix, 'liquide_puis_nationale')$a$,
  $b$argent_debiter_interne(a, p.prix, 'liquide') /* medecin_liquide_debit_v1 */$b$,
  1, 'medecin_liquide_debit_v1');
