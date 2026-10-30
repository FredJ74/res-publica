-- Banc : argent des fonctions serveur (20261030210000), refus bruyant de la vue (211000),
-- régularisation de Jean Jaaj (212000). 30/10/2026. Exécutable sur la production : tout est annulé
-- (exception finale). Compte de test : Jean Jaaj (seul compte Helvetia). Les trois migrations sont
-- recopiées sans leurs commentaires depuis les fichiers.
-- Résultat du 30/10/2026 (production, annulé) : 11 contrôles, 0 échec. AVANT : dépôt non débité,
-- fonction fautive annulée sans erreur. APRÈS : dépôt et retrait justes, fonction fautive refusée
-- (fiche_ecriture_serveur_par_la_vue), sauvegarde d'écran inchangée, régularisation unique
-- (espèces 2800 -> 152800, fortune 50730 -> 200730, un courrier).
BEGIN;
CREATE TEMP TABLE banc_res(n serial, ok boolean, quoi text);
CREATE OR REPLACE FUNCTION pg_temp.jaaj(p_path text DEFAULT '/rpc/banc') RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', (SELECT user_id FROM public.personnages_donnees WHERE name='Jean Jaaj'), 'role','authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config('request.path', p_path, true);
END $f$;
CREATE OR REPLACE FUNCTION pg_temp.serveur() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN PERFORM set_config('role','postgres',true); PERFORM set_config('request.jwt.claims','',true); PERFORM set_config('request.path','',true); END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.serveur() TO PUBLIC;
-- Une fonction serveur fautive (écrit l'argent par la vue), lancée par un joueur.
CREATE OR REPLACE FUNCTION pg_temp.fautive() RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $f$
BEGIN UPDATE public.personnages SET liquide = coalesce(liquide,0) + 1 WHERE name = 'Jean Jaaj'; END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.fautive() TO PUBLIC;
-- Une fonction serveur qui ne touche que des champs non protégés par la vue.
CREATE OR REPLACE FUNCTION pg_temp.anodine() RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $f$
BEGIN UPDATE public.personnages SET resources = resources WHERE name = 'Jean Jaaj'; END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.anodine() TO PUBLIC;
CREATE OR REPLACE FUNCTION pg_temp.etat() RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object('liq', coalesce(d.liquide,0), 'arg', coalesce(d.arg,0),
    'h', (SELECT solde FROM public.comptes_bancaires WHERE personnage='Jean Jaaj' AND banque='helvetia'),
    'mails', (SELECT count(*) FROM public.mails m WHERE to_jsonb(m)::text ILIKE '%Régularisation de votre retrait%'))
  FROM public.personnages_donnees d WHERE d.name='Jean Jaaj' $f$;
CREATE OR REPLACE FUNCTION pg_temp.note(p_ok boolean, p_quoi text) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO banc_res(ok, quoi) VALUES (coalesce(p_ok,false), p_quoi) $f$;

-- 1. Contre-épreuve sur le code de production.
DO $b$ DECLARE a jsonb; b jsonb; BEGIN
  a := pg_temp.etat();
  PERFORM pg_temp.jaaj(); PERFORM public.deposer_helvetia('Jean Jaaj', 1000, 'liquide'); PERFORM pg_temp.serveur();
  b := pg_temp.etat();
  PERFORM pg_temp.note((b->>'h')::numeric - (a->>'h')::numeric = 1000 AND (b->>'liq') = (a->>'liq'),
    'AVANT : dépôt 1000 -> compte ' || (a->>'h') || '->' || (b->>'h') || ', espèces ' || (a->>'liq') || '->' || (b->>'liq') || ' (défaut reproduit)');
END $b$;
DO $b$ DECLARE a jsonb; b jsonb; BEGIN
  a := pg_temp.etat();
  PERFORM pg_temp.jaaj(); PERFORM pg_temp.fautive(); PERFORM pg_temp.serveur();
  b := pg_temp.etat();
  PERFORM pg_temp.note((b->>'liq') = (a->>'liq'), 'AVANT : fonction fautive -> aucune erreur, crédit annulé en silence (défaut reproduit)');
END $b$;

-- 2. Les trois migrations.
CREATE TEMP TABLE banc_avant_reg AS SELECT pg_temp.etat() e;
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
    ('public.vendre_materiaux_chantier(text,text,text,text,integer,integer)',         '35f6f7a12a756e118e6c25ff032075f5'),
    -- Fonctions de la passe de nuit (service_role) : non touchées aujourd'hui, mais le même piège
    -- se refermerait le jour où un joueur les déclencherait. Une seule règle pour toutes.
    ('public.cotisation_renouveler(text,text,integer)',                               'e5a0366ba94b3c387baf911e70ae7f7b'),
    ('public.regler_creances_helvetia_quotidien(text)',                               'b0b0cf7d8b36a563fa3a07b4cf475c65'),
    ('public.resoudre_compromis_helvetia_expire(text)',                               '0a222d11bc2adfb8e2fd5349ad080174'),
    ('public.resoudre_placement_helvetia(text)',                                      'fb15c0a29344914ca918b23795304c37'),
    ('public.resoudre_placement_national(text,numeric)',                              '912a72c669e721eb8dbd50eb7978071d'),
    ('public.restituer_reliquats_chantier(text,text)',                                '17fbaf9f5c57464d21909617ce9a83ac'),
    ('public.succession_regler(text)',                                                'd9a7dadfac1e0fa61033d9f7741b4df8'),
    ('public.taxe_fonciere_prelever(text)',                                           'd42145292864a17d8254b50f9f840969'),
    ('public.traiter_prets_helvetia_quotidien()',                                     'b2bbd5cd3f17ac8ada786e62e7b0c357')
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
                                'compromis_expire_resoudre','vendre_materiaux_chantier','cotisation_renouveler',
                                'regler_creances_helvetia_quotidien','resoudre_compromis_helvetia_expire',
                                'resoudre_placement_helvetia','resoudre_placement_national','restituer_reliquats_chantier',
                                'succession_regler','taxe_fonciere_prelever','traiter_prets_helvetia_quotidien')
              AND p.prosrc ~* '\mupdate\s+(public\.)?personnages\M') THEN
    RAISE EXCEPTION 'écriture par la vue restante';
  END IF;
END $migration$;

REVOKE EXECUTE ON FUNCTION public.deposer_helvetia(text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.retirer_helvetia(text, numeric) FROM PUBLIC, anon, authenticated;
DO $migration$
DECLARE
  d text;
  v_source text := $s$    NEW.user_id := v_canon.user_id;
$s$;
  v_cible text := $c$    NEW.user_id := v_canon.user_id;

    -- REFUS BRUYANT (30/10/2026) : une fonction serveur lancée par un joueur n'écrit jamais
    -- l'argent ni les champs protégés par cette porte ; sinon l'effet serait annulé en silence.
    IF coalesce(current_setting('request.path', true), '') LIKE '/rpc/%' AND (
         NEW.arg IS DISTINCT FROM OLD.arg
      OR NEW.liquide IS DISTINCT FROM OLD.liquide
      OR NEW.banque IS DISTINCT FROM OLD.banque
      OR NEW.stats IS DISTINCT FROM OLD.stats
      OR NEW.free_pts_restants IS DISTINCT FROM OLD.free_pts_restants
      OR NEW.qualifications IS DISTINCT FROM OLD.qualifications
      OR coalesce(NEW.pa, 0) > coalesce(OLD.pa, 0)) THEN
      RAISE EXCEPTION 'fiche_ecriture_serveur_par_la_vue'
        USING ERRCODE = 'P0001',
              DETAIL = 'Une fonction serveur doit écrire public.personnages_donnees, pas la vue de l''écran.';
    END IF;
$c$;
BEGIN
  d := pg_get_functiondef('public.personnages_vue_modifier()'::regprocedure);
  IF position('fiche_ecriture_serveur_par_la_vue' IN d) > 0 THEN RETURN; END IF;
  IF md5(d) <> '0faa799957826bedba20ba372d0bd8ae' THEN
    RAISE EXCEPTION 'personnages_vue_modifier : corps différent de celui relevé le 30/10 (md5 %)', md5(d);
  END IF;
  IF (length(d) - length(replace(d, v_source, ''))) / length(v_source) <> 1 THEN
    RAISE EXCEPTION 'personnages_vue_modifier : point d''insertion absent ou multiple';
  END IF;
  EXECUTE replace(d, v_source, v_cible);
END $migration$;
CREATE TABLE IF NOT EXISTS public.regularisations_fiche (
  reference   text PRIMARY KEY,
  personnage  text NOT NULL,
  liquide     numeric NOT NULL DEFAULT 0,
  arg         numeric NOT NULL DEFAULT 0,
  motif       text NOT NULL,
  decide_par  text NOT NULL,
  applique_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.regularisations_fiche ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.regularisations_fiche FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_ref text := 'helvetia-retrait-jaaj-20261030';
  v_inseree text;
BEGIN
  -- Les faits doivent être ceux relevés : sinon, on n'invente rien.
  IF NOT EXISTS (SELECT 1 FROM public.fiche_hausses_observees
                  WHERE id = 1371 AND personnage = 'Jean Jaaj' AND colonne = 'liquide' AND delta = 150000)
     OR NOT EXISTS (SELECT 1 FROM public.fiche_hausses_observees
                  WHERE id = 1370 AND personnage = 'Jean Jaaj' AND colonne = 'arg' AND delta = 150000) THEN
    RAISE EXCEPTION 'régularisation Jaaj : traces 1370/1371 introuvables ou différentes';
  END IF;

  INSERT INTO public.regularisations_fiche (reference, personnage, liquide, arg, motif, decide_par)
  VALUES (v_ref, 'Jean Jaaj', 150000, 150000,
          'Prêt Helvetia retiré en liquide le 30/10 : espèces jamais créditées (défaut corrigé par 20261030210000). Prêt maintenu.',
          'Fred (game designer), 30/10/2026')
  ON CONFLICT (reference) DO NOTHING
  RETURNING reference INTO v_inseree;

  IF v_inseree IS NULL THEN RETURN; END IF;  -- déjà appliquée

  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide, 0) + 150000,
         arg     = coalesce(arg, 0) + 150000
   WHERE name = 'Jean Jaaj';
  IF NOT FOUND THEN RAISE EXCEPTION 'régularisation Jaaj : personnage introuvable'; END IF;

  PERFORM public.mail_systeme_poser_interne('Banque Helvetia', 'Jean Jaaj', 'Régularisation de votre retrait',
    'Votre retrait de 150 000 FR du 30 octobre n''avait pas été remis en espèces à la suite d''une erreur '
    || 'de nos services. La somme vient de vous être versée en liquide. Votre prêt reste en vigueur '
    || 'aux conditions signées.');
END $migration$;

-- 3. Après.
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
  PERFORM pg_temp.note((c->>'arg') = (a->>'arg'), 'APRÈS : fortune inchangée par l''aller-retour');
END $b$;
DO $b$ DECLARE a jsonb; b jsonb; v_err text; BEGIN
  a := pg_temp.etat();
  PERFORM pg_temp.jaaj();
  BEGIN PERFORM pg_temp.fautive(); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  PERFORM pg_temp.serveur();
  b := pg_temp.etat();
  PERFORM pg_temp.note(v_err = 'fiche_ecriture_serveur_par_la_vue' AND (b->>'liq') = (a->>'liq'),
    'APRÈS : fonction fautive lancée par un joueur -> refus nommé (' || coalesce(v_err,'aucune erreur') || '), rien d''écrit');
END $b$;
DO $b$ DECLARE v_err text; BEGIN
  PERFORM pg_temp.jaaj();
  BEGIN PERFORM pg_temp.anodine(); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  PERFORM pg_temp.serveur();
  PERFORM pg_temp.note(v_err IS NULL, 'APRÈS : fonction qui n''écrit que des champs libres -> acceptée (' || coalesce(v_err,'ok') || ')');
END $b$;
DO $b$ DECLARE a jsonb; b jsonb; v_err text; BEGIN
  a := pg_temp.etat();
  PERFORM pg_temp.jaaj('/personnages');
  BEGIN
    UPDATE public.personnages SET liquide = coalesce(liquide,0) + 999999 WHERE name = 'Jean Jaaj';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
  END;
  PERFORM pg_temp.serveur();
  b := pg_temp.etat();
  PERFORM pg_temp.note(v_err IS NULL AND (b->>'liq') = (a->>'liq'),
    'APRÈS : sauvegarde d''écran aux espèces gonflées -> corrigée en silence comme avant (' || coalesce(v_err,'pas d''erreur') || ')');
END $b$;
DO $b$ BEGIN
  PERFORM pg_temp.note(NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f'
      AND p.proname NOT IN ('personnages_vue_modifier','deposer_helvetia','retirer_helvetia')
      AND p.prosrc ~* '\mupdate\s+(public\.)?personnages\M[^;]*\m(arg|liquide|banque|stats|free_pts_restants|qualifications)\s*='),
    'APRÈS : plus aucune fonction n''écrit l''argent ou un champ protégé par la vue');
END $b$;

-- 4. Régularisation : effet unique, puis rejouée sans effet.
DO $b$ DECLARE a jsonb; b jsonb; BEGIN
  SELECT e INTO a FROM banc_avant_reg;
  b := pg_temp.etat();
  -- l'aller-retour de la section 3 est neutre ; seule la régularisation a changé espèces et fortune
  PERFORM pg_temp.note((b->>'liq')::numeric - (a->>'liq')::numeric = 150000 AND (b->>'arg')::numeric - (a->>'arg')::numeric = 150000
      AND (b->>'mails')::int - (a->>'mails')::int = 1,
    'RÉGULARISATION : espèces ' || (a->>'liq') || '->' || (b->>'liq') || ', fortune ' || (a->>'arg') || '->' || (b->>'arg') || ', courriers +' || ((b->>'mails')::int - (a->>'mails')::int));
  TRUNCATE banc_avant_reg; INSERT INTO banc_avant_reg VALUES (b);
END $b$;
-- Rejeu de la clé de la régularisation : le registre l'a déjà, rien ne doit bouger.
DO $migration$
DECLARE
  v_ref text := 'helvetia-retrait-jaaj-20261030';
  v_inseree text;
BEGIN
  INSERT INTO public.regularisations_fiche (reference, personnage, liquide, arg, motif, decide_par)
  VALUES (v_ref, 'Jean Jaaj', 150000, 150000, 'rejeu', 'banc')
  ON CONFLICT (reference) DO NOTHING
  RETURNING reference INTO v_inseree;
  IF v_inseree IS NULL THEN RETURN; END IF;
  UPDATE public.personnages_donnees SET liquide = coalesce(liquide, 0) + 150000, arg = coalesce(arg, 0) + 150000 WHERE name = 'Jean Jaaj';
END $migration$;
DO $b$ DECLARE a jsonb; b jsonb; BEGIN
  SELECT e INTO a FROM banc_avant_reg;
  b := pg_temp.etat();
  PERFORM pg_temp.note(a = b, 'RÉGULARISATION rejouée : aucun effet (espèces ' || (b->>'liq') || ')');
END $b$;

DO $b$ DECLARE nb int; ko int; r text; BEGIN
  SELECT count(*), count(*) FILTER (WHERE NOT ok), string_agg(CASE WHEN ok THEN 'ok  ' ELSE 'KO  ' END || quoi, E'\n' ORDER BY n)
    INTO nb, ko, r FROM banc_res;
  RAISE EXCEPTION E'BANC argent-serveur : % controles, % echec(s)\n%', nb, ko, r;
END $b$;
ROLLBACK;
