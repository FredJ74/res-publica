-- Banc ANNULÉ (aucune ligne ne reste) : avis personnels et expéditeurs déclarés (31/10/2026).
-- À jouer AVANT application : la première mesure doit montrer le refus, la seconde l'acceptation.
-- Se place au rôle `authenticated` avec l'identité d'un personnage existant (aucune donnée lue
-- ni modifiée en dehors d'INSERT annulés dans `mails`).
BEGIN;
CREATE TEMP TABLE banc_res(n serial, quoi text, ok boolean);
GRANT ALL ON banc_res TO authenticated; GRANT USAGE ON SEQUENCE banc_res_n_seq TO authenticated;

CREATE FUNCTION pg_temp.essai(p_from text, p_to text) RETURNS boolean LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO public.mails(id, from_player, to_player, subject, body, time, read)
  VALUES ('banc-' || md5(random()::text), p_from, p_to, 'banc', 'banc', 'banc', false);
  RETURN true;
EXCEPTION WHEN insufficient_privilege OR check_violation THEN RETURN false;
END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.essai(text, text) TO authenticated;

SELECT set_config('banc.moi', (SELECT name FROM public.personnages_donnees WHERE user_id IS NOT NULL ORDER BY name LIMIT 1), false);
SELECT set_config('banc.autre', (SELECT name FROM public.personnages_donnees WHERE user_id IS NOT NULL ORDER BY name DESC LIMIT 1), false);
SELECT set_config('request.jwt.claims', json_build_object('sub',
  (SELECT user_id FROM public.personnages_donnees WHERE name = current_setting('banc.moi')), 'role', 'authenticated')::text, false);

SET LOCAL ROLE authenticated;
INSERT INTO banc_res(quoi, ok) SELECT 'AVANT soi Gestionnaire immobilier', pg_temp.essai('Gestionnaire immobilier', current_setting('banc.moi'));
INSERT INTO banc_res(quoi, ok) SELECT 'AVANT soi Commissariat', pg_temp.essai('Commissariat', current_setting('banc.moi'));
RESET ROLE;

\i migrations/20261031190000_avis_personnels_expediteurs_declares.sql

SET LOCAL ROLE authenticated;
INSERT INTO banc_res(quoi, ok) SELECT 'APRES soi Gestionnaire immobilier (attendu t)', pg_temp.essai('Gestionnaire immobilier', current_setting('banc.moi'));
INSERT INTO banc_res(quoi, ok) SELECT 'APRES soi Commission Electorale (attendu t)', pg_temp.essai('Commission Electorale', current_setting('banc.moi'));
INSERT INTO banc_res(quoi, ok) SELECT 'APRES soi Tribunal (attendu t)', pg_temp.essai('Tribunal', current_setting('banc.moi'));
INSERT INTO banc_res(quoi, ok) SELECT 'APRES tiers Gestionnaire immobilier (attendu f)', pg_temp.essai('Gestionnaire immobilier', current_setting('banc.autre'));
INSERT INTO banc_res(quoi, ok) SELECT 'APRES tiers Caserne (attendu f)', pg_temp.essai('Caserne', current_setting('banc.autre'));
INSERT INTO banc_res(quoi, ok) SELECT 'APRES identite inventee (attendu f)', pg_temp.essai('Maître du Monde', current_setting('banc.moi'));
RESET ROLE;

SELECT quoi, ok FROM banc_res ORDER BY n;
ROLLBACK;
