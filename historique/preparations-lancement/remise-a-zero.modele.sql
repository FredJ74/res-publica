-- REMISE À ZÉRO DU LANCEMENT (19/12/2026) — PRÉPARÉE, JAMAIS EXÉCUTÉE SANS FRED.
-- Mission du soir du 25/11/2026 (Claude), bloc 4.5. Fichier GÉNÉRÉ par outils/lancement/generer-remise-a-zero.py à partir de
-- baseline/classification-donnees.csv et outils/lancement/classement-complementaire-20261125.csv : ne pas l'éditer à la main.
-- Procédure complète, ce qui est effacé ou gardé, retour arrière : docs/premium/REMISE-A-ZERO-20261219.md.
-- Listes : /*COMPTES*/
--
-- Ce que fait le script, dans UNE transaction (tout ou rien) :
--   1. garde-fous : phrase de confirmation posée dans la session, date de Paris ≥ 19/12/2026, aucune table « à vérifier »,
--      aucune table inconnue non vide ;
--   2. relève les comptes de la bêta (comptes ayant un personnage, comptes de test exclus) dans lancement_comptes_beta ;
--   3. vide les tables d'état vivant (TRUNCATE sans CASCADE ; une table référencée par une table gardée est vidée par DELETE,
--      qui applique la règle de la clé : une clé étrangère inattendue fait échouer, rien n'est effacé) ;
--   4. remet les tables mixtes à leur état initial, table par table (outils/lancement/reinitialisations.modele.sql) ;
--   5. accorde l'offre des testeurs : personnalisation d'un commerce, une annonce dans la presse, une publicité dans la rue.
-- Tous les personnages disparaissent (décision de Fred du 25/11/2026 en fin de soirée) : chacun recrée le sien.
-- Les comptes de connexion (auth.users), les accès du MJ, les achats premium payés et les référentiels sont gardés.
--
-- Pour l'exécuter (Fred décide du moment) :
--   SET human_gambit.remise_a_zero = 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026';
--   puis ce fichier entier.
BEGIN;

-- 1. Garde-fous. ------------------------------------------------------------------------------------------------------
DO $garde$
BEGIN
  IF current_setting('human_gambit.remise_a_zero', true) IS DISTINCT FROM 'JE-CONFIRME-LA-REMISE-A-ZERO-DU-19-12-2026' THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : phrase de confirmation absente (voir docs/premium/REMISE-A-ZERO-20261219.md)';
  END IF;
  IF (now() AT TIME ZONE 'Europe/Paris')::date < DATE '2026-12-19' THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : pas avant le 19/12/2026 (heure de Paris)';
  END IF;
END $garde$;
-- fin des garde-fous

CREATE TEMP TABLE rz_listes ON COMMIT DROP AS SELECT
  /*GARDER*/ AS garder, /*VIDER*/ AS vider, /*REINITIALISER*/ AS reinitialiser, /*A_VERIFIER*/ AS a_verifier;

DO $controle$
DECLARE l record; v_inconnues text; v_n bigint; t text; v_vides text[] := '{}';
BEGIN
  SELECT * INTO l FROM rz_listes;
  IF cardinality(l.a_verifier) > 0 THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : tables encore « à vérifier » : %', array_to_string(l.a_verifier, ', ');
  END IF;
  -- Une table créée depuis la préparation : vide, elle est simplement ignorée ; non vide, la remise est refusée.
  FOR t IN SELECT c.relname::text FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p')
             AND NOT (c.relname::text = ANY (l.garder || l.vider || l.reinitialiser)) ORDER BY 1 LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', t) INTO v_n;
    IF v_n > 0 THEN v_vides := v_vides || (t || ' (' || v_n || ')'); END IF;
  END LOOP;
  IF cardinality(v_vides) > 0 THEN
    RAISE EXCEPTION 'REMISE À ZÉRO REFUSÉE : tables non classées et non vides : %', array_to_string(v_vides, ', ');
  END IF;
END $controle$;

-- 2. Relevé des comptes de la bêta (avant tout effacement). Comptes de test exclus. ---------------------------------
CREATE TABLE IF NOT EXISTS public.lancement_comptes_beta (
  user_id uuid PRIMARY KEY,
  personnages text[] NOT NULL,
  releve_le timestamptz NOT NULL DEFAULT now(),
  offre_accordee_le timestamptz
);
ALTER TABLE public.lancement_comptes_beta ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lancement_comptes_beta FROM PUBLIC, anon, authenticated;
INSERT INTO public.lancement_comptes_beta (user_id, personnages)
SELECT p.user_id, array_agg(p.name ORDER BY p.name)
  FROM public.personnages p
 WHERE p.user_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM public.comptes_test ct WHERE ct.personnage = p.name)
   AND NOT EXISTS (SELECT 1 FROM public.personnages p2 JOIN public.comptes_test ct2 ON ct2.personnage = p2.name WHERE p2.user_id = p.user_id)
 GROUP BY p.user_id
ON CONFLICT (user_id) DO NOTHING;

-- 3. Effacement de l'état vivant. -------------------------------------------------------------------------------------
-- TRUNCATE d'un seul tenant ; une table référencée par une table gardée (journaux.cree_par → personnages_donnees, ON DELETE
-- SET NULL) ne peut pas être tronquée : elle est vidée ensuite par DELETE, qui applique la règle de sa clé.
DO $vider$
DECLARE l record; v_tronquer text[]; v_supprimer text[]; t text;
BEGIN
  SELECT * INTO l FROM rz_listes;
  SELECT array_agg(c.relname::text ORDER BY c.relname) INTO v_supprimer
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p') AND c.relname::text = ANY (l.vider)
     AND EXISTS (SELECT 1 FROM pg_constraint k WHERE k.contype = 'f' AND k.confrelid = c.oid
                  AND NOT ((SELECT e.relname::text FROM pg_class e WHERE e.oid = k.conrelid) = ANY (l.vider)));
  SELECT array_agg(format('public.%I', c.relname) ORDER BY c.relname) INTO v_tronquer
    FROM pg_class c WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'p') AND c.relname::text = ANY (l.vider)
     AND NOT (c.relname::text = ANY (coalesce(v_supprimer, '{}')));
  IF v_tronquer IS NOT NULL THEN
    EXECUTE 'TRUNCATE ' || array_to_string(v_tronquer, ', ') || ' RESTART IDENTITY';
  END IF;
  FOREACH t IN ARRAY coalesce(v_supprimer, '{}') LOOP
    EXECUTE format('DELETE FROM public.%I', t);
  END LOOP;
END $vider$;

/*REINITIALISATIONS*/

-- 5. Offre ponctuelle des testeurs de la bêta (décision de Fred du 25/11/2026 au soir). --------------------------------
INSERT INTO public.premium_droits (user_id, produit, cible, source, note)
SELECT b.user_id, o.produit, NULL, 'offre_lancement', 'Merci d''avoir testé la bêta'
  FROM public.lancement_comptes_beta b
 CROSS JOIN (VALUES ('personnalisation_local'), ('credit_publicite_presse'), ('credit_publicite_rue')) o(produit)
 WHERE b.offre_accordee_le IS NULL;
UPDATE public.lancement_comptes_beta SET offre_accordee_le = now() WHERE offre_accordee_le IS NULL;

COMMIT;
