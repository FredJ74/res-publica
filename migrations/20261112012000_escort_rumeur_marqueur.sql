-- Marqueur de rumeur au format commun (« <sujet>_rumeur_vN ») pour le type « appel_escort » ajouté par
-- 20261112005000 : le banc banc-rumeurs-ecoute-jauges-379 recense ainsi les types reconnus côté serveur.
-- Aucun comportement modifié : seul un commentaire est ajouté dans rumeur_ecoute_jauges_interne. Idempotente.
BEGIN;
DO $mig$
DECLARE d text; a text := '''appel_escort''/* escort_scandale_v1 */';
BEGIN
  d := pg_get_functiondef('public.rumeur_ecoute_jauges_interne(text)'::regprocedure);
  IF position('escort_rumeur_v1' IN d) = 0 THEN
    IF (length(d) - length(replace(d, a, ''))) / length(a) <> 1 THEN RAISE EXCEPTION 'rumeur_ecoute_jauges_interne : ancrage introuvable'; END IF;
    EXECUTE replace(d, a, '''appel_escort''/* escort_rumeur_v1 *//* escort_scandale_v1 */');
  END IF;
  IF position('escort_rumeur_v1' IN pg_get_functiondef('public.rumeur_ecoute_jauges_interne(text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'escort_rumeur_marqueur : contrôle structurel en échec'; END IF;
END $mig$;
COMMIT;
