-- NATIONALITÉ : COMPLÉMENTS DE FRED (18/11/2026, « Décisions du 18/11 », point 4).
--  1. Programme par défaut de l'investi : « X est investi par le parti Y, qui viendra détailler son programme
--     personnellement. »
--  2. Naturalisation : un ministre joueur peut répondre à partir de 48 h ; sans réponse, la demande est acceptée
--     7 jours après son dépôt, qu'il y ait un ministre joueur ou non (passe de nuit « naturalisations »).
-- Idempotente.
BEGIN;
DO $inv$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.sovarka_parti_investir_interne(text,text,jsonb)'::regprocedure);
  IF position('viendra détailler son programme' IN d) > 0 THEN RETURN; END IF;
  a := $a$v_cible || ' est investi par le parti ' || (d->>'nom') || '.'$a$;
  b := $b$v_cible || ' est investi par le parti ' || (d->>'nom') || ', qui viendra détailler son programme personnellement.'$b$;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'sovarka_parti_investir_interne : ancrage'; END IF;
  EXECUTE replace(d, a, b);
END $inv$;

CREATE OR REPLACE FUNCTION public.naturalisations_passe()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; n int := 0; v_ms bigint := floor(extract(epoch FROM now()) * 1000);
BEGIN
  -- Sans réponse (ministre joueur ou non), acceptée 7 jours après le dépôt (Fred, 18/11/2026).
  FOR r IN SELECT * FROM public.demandes_naturalisation
            WHERE coalesce(statut, 'pending') = 'pending' AND date_demande IS NOT NULL
              AND v_ms - date_demande >= 7 * 86400 * 1000
            FOR UPDATE LOOP
    UPDATE public.demandes_naturalisation SET statut = 'acceptee' WHERE id = r.id;
    PERFORM public.naturalisation_appliquer_interne(r.demandeur, r.pays_vise);
    n := n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'acceptees_d_office', n);
END $$;
REVOKE ALL ON FUNCTION public.naturalisations_passe() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.naturalisations_passe() TO service_role;

DO $mail$
DECLARE d text; a text; b text;
BEGIN
  d := pg_get_functiondef('public.naturalisation_demander(uuid)'::regprocedure);
  IF position('acceptée 7 jours après' IN d) > 0 THEN RETURN; END IF;
  a := $a$48 h après le dépôt.'$a$;
  b := $b$48 h après le dépôt. Sans réponse, la demande est acceptée 7 jours après son dépôt.'$b$;
  IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'naturalisation_demander : ancrage'; END IF;
  EXECUTE replace(d, a, b);
END $mail$;

DO $$ BEGIN
  IF position('viendra détailler son programme' IN pg_get_functiondef('public.sovarka_parti_investir_interne(text,text,jsonb)'::regprocedure)) = 0
     OR position('postes_attribues' IN pg_get_functiondef('public.naturalisations_passe()'::regprocedure)) > 0
     OR position('acceptée 7 jours après' IN pg_get_functiondef('public.naturalisation_demander(uuid)'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'nationalite_complements : controle structurel en echec'; END IF;
END $$;
COMMIT;
