-- Banc : argent des fonctions serveur écrit dans la table (migration 20261030210000), 30/10/2026.
-- Exécutable sur la production : tout est annulé (exception finale). Compte de test : Jean Jaaj
-- (seul compte Helvetia). Contre-épreuve AVANT la migration : un dépôt depuis les espèces crédite
-- le compte sans débiter les espèces. APRÈS : dépôt et retrait en liquide équilibrés, ancienne porte
-- à deux paramètres refusée au joueur, plus aucune écriture par la vue.
-- Résultat du 30/10/2026 (production, annulé) : 6 contrôles, 0 échec. AVANT : compte 10000->11000,
-- espèces 2800->2800. APRÈS : dépôt 2800->1800, retrait 1800->2800, fortune inchangée.
BEGIN;
CREATE TEMP TABLE banc_res(n serial, ok boolean, quoi text);
CREATE OR REPLACE FUNCTION pg_temp.jaaj() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', (SELECT user_id FROM public.personnages_donnees WHERE name='Jean Jaaj'), 'role','authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.path', '/rpc/banc', true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN PERFORM set_config('role','postgres',true); PERFORM set_config('request.jwt.claims','',true); PERFORM set_config('request.path','',true); END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.serveur() TO PUBLIC;
CREATE OR REPLACE FUNCTION pg_temp.etat() RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object('liq', coalesce(d.liquide,0), 'arg', coalesce(d.arg,0),
    'h', (SELECT solde FROM public.comptes_bancaires WHERE personnage='Jean Jaaj' AND banque='helvetia'))
  FROM public.personnages_donnees d WHERE d.name='Jean Jaaj' $f$;
CREATE OR REPLACE FUNCTION pg_temp.note(p_ok boolean, p_quoi text) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO banc_res(ok, quoi) VALUES (coalesce(p_ok,false), p_quoi) $f$;

-- 1. Contre-épreuve sur le code de production.
DO $b$ DECLARE a jsonb; b jsonb; BEGIN
  a := pg_temp.etat();
  PERFORM pg_temp.jaaj(); PERFORM public.deposer_helvetia('Jean Jaaj', 1000, 'liquide'); PERFORM pg_temp.serveur();
  b := pg_temp.etat();
  PERFORM pg_temp.note((b->>'h')::numeric - (a->>'h')::numeric = 1000 AND (b->>'liq') = (a->>'liq'),
    'AVANT : dépôt 1000 en liquide -> compte ' || (a->>'h') || '->' || (b->>'h') || ', espèces ' || (a->>'liq') || '->' || (b->>'liq') || ' (défaut attendu : espèces inchangées)');
END $b$;

-- 2. Migration, texte identique au fichier.
-- =====================================================================================
-- ARGENT ÉCRIT PAR LES FONCTIONS SERVEUR : LA TABLE, PAS LA PORTE DE L'ÉCRAN (30/10/2026, Claude).
-- NON APPLIQUÉE. Application par ChatGPT après prévol. Compatible avec l'écran en ligne (aucun
-- contrat client modifié).
--
-- DÉFAUT (signalé par Fred : 150 000 FR empruntés chez Helvetia par Jean Jaaj, disparus au retrait
-- en liquide). Depuis `verrouiller_soldes_lors_sauvegarde_personnage` (14/10), la garde de la vue
-- `personnages` (personnages_vue_modifier) remet `arg` et `liquide` à leur valeur enregistrée pour
-- tout appel qui n'est pas du serveur : est_appel_serveur() regarde le rôle de la requête, qui reste
-- `authenticated` dans une fonction SECURITY DEFINER lancée par un joueur. Les fonctions ci-dessous
-- écrivaient l'argent PAR CETTE VUE : quand un joueur les déclenche, leurs crédits ET leurs débits
-- d'espèces ou de fortune sont silencieusement annulés, le reste de la transaction passe.
--   . retrait Helvetia en liquide : compte débité, espèces jamais créditées (cas de Jean Jaaj,
--     trace fiche_hausses_observees n° 1371) ; prêt Helvetia : fortune non créditée (n° 1370) ;
--   . dépôt et ouverture de compte Helvetia depuis les espèces : compte crédité, espèces jamais
--     débitées (création d'argent ; un seul compte Helvetia en production, aucun abus constaté) ;
--   . vente de matériaux de chantier : matériaux retirés, produit jamais versé ;
--   . Assemblée (dépenses du député, indemnité, solde militaire perçue) : débits et crédits annulés.
-- Les mêmes fonctions lancées par le cron (service_role) n'étaient pas touchées.
--
-- CORRECTIF. Précédent : prelever_loyer_bail (29/10). Ces fonctions serveur écrivent désormais la
-- table personnages_donnees. Patch en place : seule la cible des UPDATE change, chaque corps est
-- vérifié par son empreinte de production avant modification (refus si le texte a bougé).
-- Les anciennes portes à deux paramètres deposer_helvetia(text,numeric) et
-- retirer_helvetia(text,numeric), que l'écran n'appelle plus (il passe la source/destination),
-- sont retirées aux joueurs : la première permettait de créer de l'argent par le même défaut.
-- =====================================================================================
DO $migration$
DECLARE
  r record;
  d text;
  n text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.creer_pret_helvetia(text,numeric,integer)',                              '37f86e6e9f01eed02bdef23f44e17f8c'),
    ('public.fermer_compte_helvetia(text,text)',                                      'd5f33bb8f583238455cc9be8d1fd0c1f'),
    ('public.ouvrir_compte_helvetia(text)',                                           '066a5d34a72798900294675c6677d03c'),
    ('public.rembourser_pret_helvetia_integral(text,text,jsonb)',                     '33fb77998d878a4fe8be4dfbb73a82cc'),
    ('public.helvetia_crediter_destination(text,numeric,text)',                       '689ade4b40dc76b4f14a347a2d6dccc6'),
    ('public.helvetia_debiter_source(text,numeric,text)',                             'a2f2e2d5161edde4082fc2620082d878'),
    ('public.assemblee_crediter_joueur(text,integer)',                                'f6b050f1db9f4d8a82cfb1060d4d8dec'),
    ('public.assemblee_debiter_joueur(text,integer,integer)',                         'f5b03c64c215507809518855f726fd2a'),
    ('public.compromis_expire_resoudre(text,text)',                                   'ab003f202185ab1a8074fba1153e376a'),
    ('public.vendre_materiaux_chantier(text,text,text,text,integer,integer)',         '35f6f7a12a756e118e6c25ff032075f5')
  ) AS t(sig, empreinte) LOOP
    d := pg_get_functiondef(r.sig::regprocedure);
    IF md5(d) <> r.empreinte THEN
      RAISE EXCEPTION '% : corps différent de celui relevé en production le 30/10 (md5 %)', r.sig, md5(d);
    END IF;
    -- \M (fin de mot) : « personnages_donnees » n'est jamais touché.
    n := regexp_replace(d, '\mupdate\s+(public\.)?personnages\M', 'UPDATE public.personnages_donnees', 'gi');
    IF n = d THEN RAISE EXCEPTION '% : aucune écriture par la vue trouvée', r.sig; END IF;
    EXECUTE n;
  END LOOP;

  -- Plus aucune écriture d'argent par la vue dans ces fonctions.
  IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
              AND p.proname IN ('creer_pret_helvetia','fermer_compte_helvetia','ouvrir_compte_helvetia',
                                'rembourser_pret_helvetia_integral','helvetia_crediter_destination',
                                'helvetia_debiter_source','assemblee_crediter_joueur','assemblee_debiter_joueur',
                                'compromis_expire_resoudre','vendre_materiaux_chantier')
              AND p.prosrc ~* '\mupdate\s+(public\.)?personnages\M') THEN
    RAISE EXCEPTION 'écriture par la vue restante';
  END IF;
END $migration$;

REVOKE EXECUTE ON FUNCTION public.deposer_helvetia(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.retirer_helvetia(text, numeric) FROM PUBLIC, anon, authenticated;

-- 3. Après la migration.
DO $b$ DECLARE a jsonb; b jsonb; c jsonb; BEGIN
  a := pg_temp.etat();
  PERFORM pg_temp.jaaj(); PERFORM public.deposer_helvetia('Jean Jaaj', 1000, 'liquide'); PERFORM pg_temp.serveur();
  b := pg_temp.etat();
  PERFORM pg_temp.jaaj(); PERFORM public.retirer_helvetia('Jean Jaaj', 1000, 'liquide'); PERFORM pg_temp.serveur();
  c := pg_temp.etat();
  PERFORM pg_temp.note((b->>'h')::numeric - (a->>'h')::numeric = 1000 AND (a->>'liq')::numeric - (b->>'liq')::numeric = 1000,
    'APRÈS : dépôt 1000 -> compte ' || (a->>'h') || '->' || (b->>'h') || ', espèces ' || (a->>'liq') || '->' || (b->>'liq'));
  PERFORM pg_temp.note((b->>'h')::numeric - (c->>'h')::numeric = 1000 AND (c->>'liq')::numeric - (b->>'liq')::numeric = 1000,
    'APRÈS : retrait 1000 en liquide -> compte ' || (b->>'h') || '->' || (c->>'h') || ', espèces ' || (b->>'liq') || '->' || (c->>'liq'));
  PERFORM pg_temp.note((c->>'arg') = (a->>'arg'), 'APRÈS : fortune (arg) inchangée par un aller-retour : ' || (a->>'arg') || '->' || (c->>'arg'));
END $b$;
DO $b$ BEGIN
  PERFORM pg_temp.jaaj();
  BEGIN
    PERFORM public.deposer_helvetia('Jean Jaaj', 1000);
    PERFORM pg_temp.serveur(); PERFORM pg_temp.note(false, 'ancienne porte deposer_helvetia(text,numeric) encore ouverte');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM pg_temp.serveur(); PERFORM pg_temp.note(true, 'ancienne porte deposer_helvetia(text,numeric) refusée au joueur');
  END;
END $b$;
DO $b$ BEGIN
  PERFORM pg_temp.note(has_function_privilege('authenticated', 'public.retirer_helvetia(text,numeric,text)', 'EXECUTE')
    AND has_function_privilege('authenticated', 'public.deposer_helvetia(text,numeric,text)', 'EXECUTE')
    AND NOT has_function_privilege('authenticated', 'public.retirer_helvetia(text,numeric)', 'EXECUTE'),
    'portes de l''écran conservées, ancienne porte de retrait fermée');
END $b$;

DO $b$ DECLARE nb int; ko int; r text; BEGIN
  SELECT count(*), count(*) FILTER (WHERE NOT ok), string_agg(CASE WHEN ok THEN 'ok  ' ELSE 'KO  ' END || quoi, E'\n' ORDER BY n)
    INTO nb, ko, r FROM banc_res;
  RAISE EXCEPTION E'BANC argent-serveur : % controles, % echec(s)\n%', nb, ko, r;
END $b$;
