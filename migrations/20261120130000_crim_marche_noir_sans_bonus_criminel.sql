-- Correctif Criminalité (Fred, 20/11/2026) : la carrière criminelle ne donne plus +15 à l'achat
-- d'armes et d'explosifs au marché noir (§ 15 : aucun avantage « marché noir »).
-- Les autres modificateurs de carrière (renseignement, escort, malus) ne changent pas.
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

SELECT pg_temp.rp_raccorder('public.crime_acheter_arme_noire(text,text,boolean)'::regprocedure,
  $a$CASE m.career WHEN 'criminal_c' THEN 15 WHEN 'intel' THEN 15$a$,
  $a$CASE m.career /* crim_marche_noir_sans_bonus_v1 */ WHEN 'intel' THEN 15$a$,
  'crim_marche_noir_sans_bonus_v1');

SELECT pg_temp.rp_raccorder('public.crime_acheter_explosifs(integer,integer)'::regprocedure,
  $a$+ CASE WHEN m.career = 'criminal_c' THEN 15 ELSE 0 END$a$,
  $a$/* crim_marche_noir_sans_bonus_v1 */$a$,
  'crim_marche_noir_sans_bonus_v1');
