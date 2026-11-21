-- BARÈME DES INFORMATEURS DE SOVARKA (Fred, 19/11/2026, consigné le 21/11) : « Sovarka fonctionne de la même façon, avec
-- des sommes de 7 à 20 PSK ». Paliers de Républia (20-29 FR flou, 30-44 FR correct, 45-50 FR premier choix) repris en
-- proportion : 7 à 11 PSK flou, 12 à 17 PSK correct, 18 à 20 PSK premier choix. Payer donne toujours un service.
-- Fonction commune informateur_palier_interne(pays, montant) ; l'habitué du Bar Sever de Krasnov l'utilise.
-- Idempotente.
BEGIN;

CREATE OR REPLACE FUNCTION public.informateur_palier_interne(p_pays text, p_montant numeric)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_pays = 'soviet' THEN
           CASE WHEN p_montant BETWEEN 18 AND 20 THEN 'premier_choix' WHEN p_montant BETWEEN 12 AND 17 THEN 'correct'
                WHEN p_montant BETWEEN 7 AND 11 THEN 'flou' END
         ELSE
           CASE WHEN p_montant BETWEEN 45 AND 50 THEN 'premier_choix' WHEN p_montant BETWEEN 30 AND 44 THEN 'correct'
                WHEN p_montant BETWEEN 20 AND 29 THEN 'flou' END
         END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.rp_raccorder(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn);
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  IF (length(d) - length(replace(d, p_avant, ''))) / length(p_avant) <> 1 THEN
    RAISE EXCEPTION '% : ancrage introuvable ou multiple (%)', p_fn, left(p_avant, 60); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;
SELECT pg_temp.rp_raccorder('public.secret_source_interne(text,text,integer)'::regprocedure,
  $a$    v_palier := CASE WHEN p_montant >= 20 THEN 'premier_choix' WHEN p_montant >= 13 THEN 'correct' ELSE 'flou' END;$a$,
  $b$    v_palier := public.informateur_palier_interne('soviet', p_montant); /* informateurs_bareme_v1 */$b$,
  'informateurs_bareme_v1');

COMMIT;
