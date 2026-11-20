-- La carrière ne change que par les voies du jeu (décision de Fred du 20/11/2026). Faille : la vue `personnages`
-- recopiait NEW.career envoyé par l'écran, donc un joueur pouvait réécrire sa propre carrière depuis la fiche.
-- Désormais personnages_vue_modifier reprend la carrière canonique, comme stats, qualifications ou domicile.
-- La seconde carrière passe par le cursus universitaire (carrieres_acquises), jamais par la colonne career.
-- Les fonctions serveur (est_appel_serveur) écrivent personnages_donnees directement et ne sont pas concernées.
-- Essai annulé le 20/11 : témoin sans raccord → career réécrite en 'escort' ; avec raccord → inchangée.
-- Idempotente (raccord marqué carriere_serveur_seul_v1).
BEGIN;
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
SELECT pg_temp.rp_raccorder('public.personnages_vue_modifier()'::regprocedure,
  $a$    NEW.domicile          := v_canon.domicile;$a$,
  $b$    NEW.domicile          := v_canon.domicile;
    -- carriere_serveur_seul_v1 (Fred, 20/11/2026) : la carrière ne change que par les voies du jeu
    -- (seconde carrière : cursus universitaire, table carrieres_acquises), jamais par l'écran.
    NEW.career            := v_canon.career;$b$, 'carriere_serveur_seul_v1');
COMMIT;
