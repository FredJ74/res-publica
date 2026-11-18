-- DÉCISIONS DE FRED (18/11/2026, après-midi) :
--  1. Tutelle d'une mairie sans maire ni adjoint : le ministre (Économie collective en Sovarka, Intérieur
--     ailleurs) a TOUS les boutons du bureau du maire. En plus des impôts, du budget et des subventions
--     (20261118054000), il obtient la campagne de sécurité et les nominations municipales.
--  2. Syndicat national de Sovarka : cotisation unique de 15 PSK (1 PA conservé), jamais renouvelée.
-- Aucune donnée de joueur modifiée. Idempotente.
BEGIN;

UPDATE public.ordres_couts SET pa = 1, cost = 15 WHERE fn = 'se_syndiquer_etat' AND (pa, cost) IS DISTINCT FROM (1, 15);

DO $adh$
DECLARE d text; a1 text; a2 text;
BEGIN
  d := pg_get_functiondef('public.organisation_adhesion_payante(text,text,text)'::regprocedure);
  IF position('se_syndiquer_etat' IN d) > 0 THEN RETURN; END IF;
  a1 := $a$WHERE fn = 'se_syndiquer' ORDER BY pa, cost LIMIT 1;$a$;
  a2 := $a$public.payer_ordre(v_moi, 'se_syndiquer', v_cout.pa, v_cout.cost);$a$;
  IF (length(d) - length(replace(d, a1, ''))) / length(a1) <> 1 OR (length(d) - length(replace(d, a2, ''))) / length(a2) <> 1 THEN
    RAISE EXCEPTION 'organisation_adhesion_payante : ancrage'; END IF;
  d := replace(d, a1, $b$WHERE fn = CASE WHEN p_orga = 'orga_syndicat_etat_soviet' THEN 'se_syndiquer_etat' ELSE 'se_syndiquer' END ORDER BY pa, cost LIMIT 1;$b$);
  d := replace(d, a2, $b$public.payer_ordre(v_moi, CASE WHEN p_orga = 'orga_syndicat_etat_soviet' THEN 'se_syndiquer_etat' ELSE 'se_syndiquer' END, v_cout.pa, v_cout.cost);$b$);
  EXECUTE d;
END $adh$;

DO $campagne$
DECLARE d text; a text;
BEGIN
  d := pg_get_functiondef('public.mairie_campagne_securite_interne(text)'::regprocedure);
  IF position('maire_tutelle_ici_interne' IN d) > 0 THEN RETURN; END IF;
  a := $a$ IF a.poste->>'id'IS DISTINCT FROM 'maire'THEN RETURN$a$;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'mairie_campagne_securite_interne : ancrage'; END IF;
  -- Sous tutelle, la ville est celle où se trouve le ministre (son poste n'a pas de ville) : current_city.
  EXECUTE replace(d, a, $b$ IF a.poste->>'id'IS DISTINCT FROM 'maire' AND public.maire_tutelle_ici_interne(a.name) IS NULL THEN RETURN$b$);
END $campagne$;

DO $autorite$
DECLARE d text; a text;
BEGIN
  d := pg_get_functiondef('public.poste_autorite_de(text,text)'::regprocedure);
  IF position('maire_tutelle_ici_interne' IN d) > 0 THEN RETURN; END IF;
  a := E'  IF NOT FOUND OR v_regle.nomme_par IS NULL THEN RETURN; END IF;\n';
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'poste_autorite_de : ancrage'; END IF;
  EXECUTE replace(d, a, a
    || E'  -- Tutelle (Fred, 18/11/2026) : dans le bureau du maire d''une ville sous tutelle, le ministre nomme comme le maire.\n'
    || E'  IF v_regle.nomme_par = ''maire'' AND public.maire_tutelle_ici_interne(v_nom) IS NOT NULL THEN\n'
    || E'    v_poste := jsonb_build_object(''id'', ''maire'', ''city'', public.maire_tutelle_ici_interne(v_nom));\n  END IF;\n');
END $autorite$;

DO $$ BEGIN
  IF (SELECT cost FROM public.ordres_couts WHERE fn = 'se_syndiquer_etat') IS DISTINCT FROM 15
     OR position('se_syndiquer_etat' IN pg_get_functiondef('public.organisation_adhesion_payante(text,text,text)'::regprocedure)) = 0
     OR position('maire_tutelle_ici_interne' IN pg_get_functiondef('public.mairie_campagne_securite_interne(text)'::regprocedure)) = 0
     OR position('maire_tutelle_ici_interne' IN pg_get_functiondef('public.poste_autorite_de(text,text)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'syndicat_cotisation_tutelle_complete : controle structurel en echec'; END IF;
END $$;
COMMIT;
