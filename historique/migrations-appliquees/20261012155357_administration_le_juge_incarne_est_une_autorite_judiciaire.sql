-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012155357 (UTC), nom
-- `administration_le_juge_incarne_est_une_autorite_judiciaire`.
-- Le registre passe de 691 a 692 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 e16505a5267e48355b295a968ed4ac4a, 4404 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE JUGE INCARNE EST UNE AUTORITE JUDICIAIRE, ET LE DECLENCHEUR LE SAIT
--
-- CE QUE LE BANC A TROUVE, ET QU'AUCUNE PREUVE STRUCTURELLE NE POUVAIT TROUVER. L'incarnation
-- d'Honore marchait : `justice_relaxer` rendait `ok: true`, la ligne de jugement etait creee,
-- l'acte etait consigne a son nom -- et le dossier restait `saisie`. Le declencheur
-- `plaintes_epingler_verdict` avait restaure le `status` : il ne reconnait que
-- `affaire_autorite_de`, qui lit la FICHE du compte authentifie, et un administrateur n'a pas de
-- fiche. La relaxe etait prononcee, enregistree, et sans effet.
--
-- QUATRIEME OCCURRENCE EN TROIS JOURS de « decide au serveur n'est pas applique au serveur », et
-- TROISIEME sur ce declencheur precis. La correction est toujours la meme : l'autorite est
-- RECONNUE la ou elle est verifiee, jamais contournee par un laissez-passer.
--
-- UNE SEULE LIGNE, ET AUCUN POUVOIR NEUF. `affaire_autorite_de` s'appuie sur `juge_moi()`, le
-- resolveur unique, qui gere le juge PJ ET le PNJ titulaire incarne, et reverifie la titularite a
-- chaque appel. Le commissaire garde sa branche propre. Pour un juge PJ, rien ne change.
--
-- PREUVES STRUCTURELLES -- 4.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE JUGE INCARNE EST UNE AUTORITE JUDICIAIRE, ET LE DECLENCHEUR LE SAIT
-- 12 octobre 2026 -- correctif mesure au banc de l'administration
--
-- CE QUE LE BANC A TROUVE, ET QU'AUCUNE PREUVE STRUCTURELLE NE POUVAIT TROUVER. L'incarnation
-- d'Honore marchait : `juge_moi` le reconnaissait, `justice_relaxer` rendait `ok: true`, la ligne
-- de jugement etait creee, l'acte de relaxe etait consigne au nom d'Honore. Et le dossier restait
-- `saisie`. Le declencheur `plaintes_epingler_verdict` avait restaure le `status` : il n'accepte
-- que `affaire_autorite_de(NEW.city)`, qui lit la fiche du compte authentifie -- et un
-- administrateur n'a pas de fiche. La relaxe etait prononcee, enregistree, et sans effet.
--
-- C'EST LA QUATRIEME FOIS EN TROIS JOURS que « decide au serveur » n'etait pas « applique au
-- serveur », et la troisieme fois que ce declencheur precis en est la cause. La correction est
-- toujours la meme : l'autorite doit etre RECONNUE la ou elle est verifiee, pas contournee par un
-- laissez-passer.
--
-- LA CORRECTION EST UNE SEULE LIGNE, ET ELLE NE CREE AUCUN POUVOIR. `affaire_autorite_de`
-- s'appuie desormais sur `juge_moi()` -- le resolveur unique de l'identite du juge, qui gere
-- deja le PJ titulaire ET l'incarnation d'un PNJ titulaire, et qui reverifie la titularite a
-- chaque appel. Le commissaire garde sa branche propre : il n'est pas incarnable dans cette
-- tranche, et ne le devient pas ici. Pour un juge PJ, rien ne change : la premiere branche
-- repond comme avant.
--
-- PREUVES STRUCTURELLES -- 4.

CREATE OR REPLACE FUNCTION public.affaire_autorite_de(p_city text)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  -- LE COMMISSAIRE, ET LE JUGE PJ : la fiche du compte authentifie, comme avant.
  SELECT EXISTS (
    SELECT 1 FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid()
       AND (d.poste ->> 'id') IN ('juge', 'commissaire')
       -- Juridiction : la ville du POSTE doit etre celle de l'affaire.
       -- coalesce a 'capitale' pour les affaires anterieures sans ville.
       AND (d.poste ->> 'city') IS NOT DISTINCT FROM coalesce(p_city, 'capitale')
  )
  -- LE JUGE, PAR SON RESOLVEUR UNIQUE. Il couvre le juge PJ (deja couvert ci-dessus, et c'est
  -- sans consequence) et le PNJ titulaire incarne par l'administration, dont la titularite est
  -- reverifiee a chaque appel. Sans cette branche, un verdict d'Honore est rendu et defait.
  OR EXISTS (
    SELECT 1 FROM public.juge_moi() j
     WHERE j.ville IS NOT DISTINCT FROM coalesce(p_city, 'capitale')
  );
$function$;

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_txt text;
BEGIN
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'affaire_autorite_de';

  -- P1 : LE JUGE PASSE PAR SON RESOLVEUR UNIQUE.
  IF position('public.juge_moi()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- le declencheur de verdict ignore le resolveur du juge'; END IF;

  -- P2 : LE COMMISSAIRE GARDE SA BRANCHE, et la juridiction reste exigee des deux cotes.
  IF position('''juge'', ''commissaire''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- le commissaire a perdu son autorite'; END IF;
  IF (SELECT count(*) FROM regexp_matches(v_txt, 'coalesce\(p_city, ''capitale''\)', 'g')) <> 2 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la juridiction n''est pas exigee sur les deux branches'; END IF;

  -- P3 : AUCUN LAISSEZ-PASSER N'A ETE AJOUTE POUR CONTOURNER LE DECLENCHEUR. L'autorite est
  --      reconnue, pas court-circuitee.
  IF position('verdict_interne' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- l''autorite est contournee par un laissez-passer'; END IF;

  -- P4 : LE DECLENCHEUR S'APPUIE TOUJOURS SUR CETTE SEULE DEFINITION.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'plaintes_epingler_verdict';
  IF position('public.affaire_autorite_de(NEW.city)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- le declencheur ne lit plus la definition de l''autorite'; END IF;

  RAISE NOTICE 'LES 4 PREUVES SONT VERTES.';
END $preuves$;
