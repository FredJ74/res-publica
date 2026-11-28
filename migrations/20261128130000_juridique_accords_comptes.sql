-- Mission du 28/11/2026 (après-midi, Claude), étape 5 — intégration des textes juridiques (consigne de Fred).
-- Les textes eux-mêmes (mentions légales, CGU avec la charte de conduite en annexe, CGV, politique de confidentialité)
-- seront fournis plus tard ; ici, seulement la mécanique :
--   1. Registre des versions en vigueur (juridique_versions) : texte, version, date de publication, « modification
--      importante » (déclenche la ré-acceptation). Le serveur ne reconnaît un accord que pour une version réelle.
--   2. Accords (juridique_accords) : compte, texte, version, langue, date, case « 16 ans au moins ».
--      juridique_accepter (case cochée à la création du personnage, ou fenêtre de ré-acceptation à la connexion),
--      juridique_etat (lu à chaque chargement du plateau ; note aussi l'activité du compte).
--   3. Premier ordre bloqué côté serveur : payer_ordre_interne refuse « conditions_a_accepter » tant que le compte n'a
--      pas accepté la version en vigueur des CGU et de la politique de confidentialité (et « compte_suspendu » pendant
--      une suspension de modération). Ni les PNJ (sans compte), ni les comptes de test, ni les administrateurs, ni les
--      appels du serveur ne sont concernés. Marque juridique_accord_v1.
--      Les joueurs déjà inscrits n'ont aucun accord : ils passent par la fenêtre de ré-acceptation à leur connexion.
--   4. Export des données du compte connecté (mes_donnees_exporter).
--   5. Suppression du compte : compte_suppression_demander puis, après la destruction du personnage par la mécanique de
--      succession existante (navigateur), compte_suppression_finaliser. Les messages de forum restent, signés
--      « Ancien joueur ».
--   6. Signalement des images personnalisées et des noms de personnages (contenu_signaler), dans la même file que les
--      messages (signalements_messages, page admin-signalements.js) ; sanctions de modération notifiées avec leur
--      raison (admin_sanction_prononcer, admin_sanction_lever, sanction_vue).
--   7. Comptes inactifs depuis 3 ans : liste pour le traitement de nuit (comptes_inactifs_lister), avertissement noté
--      seulement après un envoi réel d'e-mail (comptes_inactifs_avertissement_noter), suppression au plus tôt 30 jours
--      après cet avertissement (compte_inactif_supprimer : succession côté serveur, forum « Ancien joueur », compte effacé).
-- Rejouable (CREATE IF NOT EXISTS, CREATE OR REPLACE, remplacement contrôlé avec marque).
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.rp_remplacer(p_fn regprocedure, p_avant text, p_apres text, p_marque text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE d text := pg_get_functiondef(p_fn); n integer;
BEGIN
  IF position(p_marque IN d) > 0 THEN RETURN; END IF;
  n := (length(d) - length(replace(d, p_avant, ''))) / length(p_avant);
  IF n <> 1 THEN RAISE EXCEPTION '% : % occurrence(s) au lieu de 1 (%)', p_fn, n, left(p_avant, 70); END IF;
  EXECUTE replace(d, p_avant, p_apres);
  IF position(p_marque IN pg_get_functiondef(p_fn)) = 0 THEN RAISE EXCEPTION '% : raccord absent', p_fn; END IF;
END $$;

-- 1. Registre des versions -------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.juridique_versions (
  texte text NOT NULL CHECK (texte IN ('mentions-legales', 'cgu', 'cgv', 'confidentialite')),
  version text NOT NULL CHECK (version ~ '^[0-9]+(\.[0-9]+)*$'),
  publie_le date NOT NULL,
  importante boolean NOT NULL DEFAULT false,
  note text,
  cree_le timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (texte, version)
);
ALTER TABLE public.juridique_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.juridique_versions FROM anon, authenticated;
-- Versions provisoires (une ligne de texte) ; marquées importantes : tout compte doit les accepter une fois.
INSERT INTO public.juridique_versions (texte, version, publie_le, importante, note) VALUES
  ('mentions-legales', '0.1', DATE '2026-11-28', true, 'Texte provisoire'),
  ('cgu', '0.1', DATE '2026-11-28', true, 'Texte provisoire'),
  ('cgv', '0.1', DATE '2026-11-28', true, 'Texte provisoire'),
  ('confidentialite', '0.1', DATE '2026-11-28', true, 'Texte provisoire')
ON CONFLICT (texte, version) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.juridique_accords (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL,
  texte text NOT NULL,
  version text NOT NULL,
  langue text NOT NULL CHECK (langue IN ('fr', 'en', 'es', 'de', 'ru', 'ko', 'ar', 'pt-BR', 'zh-TW')),
  age_16 boolean NOT NULL DEFAULT false,
  accepte_le timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (texte, version) REFERENCES public.juridique_versions (texte, version)
);
CREATE INDEX IF NOT EXISTS juridique_accords_compte ON public.juridique_accords (user_id, texte);
ALTER TABLE public.juridique_accords ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.juridique_accords FROM anon, authenticated;

-- Dernière activité connue d'un compte (chaque chargement du plateau), pour les comptes inactifs.
CREATE TABLE IF NOT EXISTS public.comptes_activite (
  user_id uuid PRIMARY KEY,
  vu_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.comptes_activite ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.comptes_activite FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.comptes_inactifs_avertissements (
  user_id uuid PRIMARY KEY,
  activite_le timestamptz NOT NULL,
  averti_le timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.comptes_inactifs_avertissements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.comptes_inactifs_avertissements FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.comptes_suppressions (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL,
  personnage text,
  motif text NOT NULL CHECK (motif IN ('demande', 'inactivite')),
  etat text NOT NULL DEFAULT 'demandee' CHECK (etat IN ('demandee', 'terminee', 'echec')),
  detail jsonb,
  demande_le timestamptz NOT NULL DEFAULT now(),
  termine_le timestamptz
);
CREATE INDEX IF NOT EXISTS comptes_suppressions_compte ON public.comptes_suppressions (user_id, etat);
ALTER TABLE public.comptes_suppressions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.comptes_suppressions FROM anon, authenticated;

-- Version en vigueur d'un texte : la plus récente déjà publiée (date de Paris), puis le plus grand numéro.
CREATE OR REPLACE FUNCTION public.juridique_version_courante_interne(p_texte text)
RETURNS public.juridique_versions LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT v.* FROM public.juridique_versions v
   WHERE v.texte = p_texte AND v.publie_le <= (now() AT TIME ZONE 'Europe/Paris')::date
   ORDER BY v.publie_le DESC, string_to_array(v.version, '.')::int[] DESC LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.juridique_versions_courantes_interne()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('texte', c.texte, 'version', c.version, 'date', c.publie_le,
                                               'importante', c.importante) ORDER BY t.o), '[]'::jsonb)
    FROM unnest(ARRAY['mentions-legales', 'cgu', 'cgv', 'confidentialite']) WITH ORDINALITY AS t(texte, o)
    CROSS JOIN LATERAL public.juridique_version_courante_interne(t.texte) c
   WHERE c.texte IS NOT NULL;
$$;

-- Textes à accepter (CGU et confidentialité) : en vigueur, et le compte n'a accepté ni la dernière version
-- « importante » publiée ni une version postérieure.
CREATE OR REPLACE FUNCTION public.juridique_textes_a_accepter_interne(p_uid uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE t text; c public.juridique_versions; i public.juridique_versions; v_ok boolean; r jsonb := '[]'::jsonb;
BEGIN
  IF p_uid IS NULL THEN RETURN r; END IF;
  FOREACH t IN ARRAY ARRAY['cgu', 'confidentialite'] LOOP
    c := public.juridique_version_courante_interne(t);
    CONTINUE WHEN c.texte IS NULL;
    SELECT v.* INTO i FROM public.juridique_versions v
     WHERE v.texte = t AND v.importante AND v.publie_le <= (now() AT TIME ZONE 'Europe/Paris')::date
     ORDER BY v.publie_le DESC, string_to_array(v.version, '.')::int[] DESC LIMIT 1;
    SELECT EXISTS (
      SELECT 1 FROM public.juridique_accords a
        JOIN public.juridique_versions v ON v.texte = a.texte AND v.version = a.version
       WHERE a.user_id = p_uid AND a.texte = t AND a.age_16
         AND (i.texte IS NULL OR (v.publie_le, string_to_array(v.version, '.')::int[])
                                 >= (i.publie_le, string_to_array(i.version, '.')::int[])))
      INTO v_ok;
    IF NOT v_ok THEN
      r := r || jsonb_build_array(jsonb_build_object('texte', c.texte, 'version', c.version, 'date', c.publie_le,
                                                     'importante', c.importante));
    END IF;
  END LOOP;
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.juridique_langue_interne(p_langue text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_langue IN ('fr', 'en', 'es', 'de', 'ru', 'ko', 'ar', 'pt-BR', 'zh-TW') THEN p_langue ELSE 'fr' END;
$$;

-- Langue du compte : celle de son dernier accord (sinon le français).
CREATE OR REPLACE FUNCTION public.juridique_langue_compte_interne(p_uid uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT coalesce((SELECT a.langue FROM public.juridique_accords a WHERE a.user_id = p_uid
                    ORDER BY a.accepte_le DESC, a.id DESC LIMIT 1), 'fr');
$$;

-- 2. Sanctions de modération (déclarées ici car lues par juridique_etat et payer_ordre_interne) ------------------------
CREATE TABLE IF NOT EXISTS public.moderation_sanctions (
  id bigserial PRIMARY KEY,
  signalement_id bigint REFERENCES public.signalements_messages (id) ON DELETE SET NULL,
  personnage text NOT NULL,
  user_id uuid,
  type text NOT NULL CHECK (type IN ('avertissement', 'retrait_contenu', 'suspension')),
  regle text NOT NULL CHECK (length(regle) BETWEEN 1 AND 300),
  contenu text CHECK (contenu IS NULL OR length(contenu) <= 2000),
  raison text NOT NULL CHECK (length(raison) BETWEEN 1 AND 1000),
  duree_jours integer CHECK (duree_jours IS NULL OR duree_jours BETWEEN 1 AND 3650),
  debut timestamptz NOT NULL DEFAULT now(),
  fin timestamptz,
  levee_le timestamptz,
  cree_par uuid,
  cree_le timestamptz NOT NULL DEFAULT now(),
  vue_le timestamptz,
  notification jsonb,
  CHECK ((type = 'suspension') = (duree_jours IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS moderation_sanctions_compte ON public.moderation_sanctions (user_id, type);
ALTER TABLE public.moderation_sanctions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.moderation_sanctions FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.moderation_sanction_json_interne(s public.moderation_sanctions)
RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object('id', s.id, 'type', s.type, 'regle', s.regle, 'contenu', s.contenu, 'raison', s.raison,
    'duree_jours', s.duree_jours, 'debut', s.debut, 'fin', s.fin, 'levee_le', s.levee_le, 'cree_le', s.cree_le,
    'contact', 'contact@human-gambit.com');
$$;

-- Refus commun d'un ordre payant : NULL si l'ordre est permis.
CREATE OR REPLACE FUNCTION public.juridique_ordre_refus_interne(p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid; s public.moderation_sanctions; v_a jsonb;
BEGIN
  IF public.est_appel_serveur() OR public.est_administrateur() THEN RETURN NULL; END IF;
  SELECT d.user_id INTO v_uid FROM public.personnages_donnees d WHERE d.name = p_nom;
  IF v_uid IS NULL OR public.est_compte_test(p_nom) THEN RETURN NULL; END IF;
  SELECT * INTO s FROM public.moderation_sanctions m
   WHERE m.user_id = v_uid AND m.type = 'suspension' AND m.levee_le IS NULL AND m.debut <= now() AND m.fin > now()
   ORDER BY m.fin DESC LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_suspendu', 'sanction', public.moderation_sanction_json_interne(s));
  END IF;
  v_a := public.juridique_textes_a_accepter_interne(v_uid);
  IF jsonb_array_length(v_a) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'conditions_a_accepter', 'textes', v_a);
  END IF;
  RETURN NULL;
END $$;

-- État juridique du compte connecté : lu à chaque chargement du plateau (note aussi l'activité).
CREATE OR REPLACE FUNCTION public.juridique_etat()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid := auth.uid(); v_nom text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie',
                              'versions', public.juridique_versions_courantes_interne());
  END IF;
  INSERT INTO public.comptes_activite (user_id, vu_le) VALUES (v_uid, now())
  ON CONFLICT (user_id) DO UPDATE SET vu_le = excluded.vu_le;
  SELECT d.name INTO v_nom FROM public.personnages_donnees d WHERE d.user_id = v_uid LIMIT 1;
  RETURN jsonb_build_object('ok', true,
    'versions', public.juridique_versions_courantes_interne(),
    'a_accepter', public.juridique_textes_a_accepter_interne(v_uid),
    'exempte', v_nom IS NOT NULL AND public.est_compte_test(v_nom),
    'sanctions_non_vues', coalesce((SELECT jsonb_agg(public.moderation_sanction_json_interne(m) ORDER BY m.cree_le)
                                      FROM public.moderation_sanctions m WHERE m.user_id = v_uid AND m.vue_le IS NULL), '[]'::jsonb),
    'suspension', (SELECT public.moderation_sanction_json_interne(m) FROM public.moderation_sanctions m
                    WHERE m.user_id = v_uid AND m.type = 'suspension' AND m.levee_le IS NULL AND m.debut <= now() AND m.fin > now()
                    ORDER BY m.fin DESC LIMIT 1));
END $$;

-- Acceptation : CGU (charte de conduite en annexe) et politique de confidentialité, versions en vigueur.
CREATE OR REPLACE FUNCTION public.juridique_accepter(p_langue text, p_age_16 boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid := auth.uid(); v_langue text := public.juridique_langue_interne(p_langue); t text;
  c public.juridique_versions; r jsonb := '[]'::jsonb;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_age_16 IS NOT TRUE THEN RETURN jsonb_build_object('ok', false, 'raison', 'age_16_requis'); END IF;
  FOREACH t IN ARRAY ARRAY['cgu', 'confidentialite'] LOOP
    c := public.juridique_version_courante_interne(t);
    IF c.texte IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'texte_sans_version', 'texte', t); END IF;
    INSERT INTO public.juridique_accords (user_id, texte, version, langue, age_16)
    VALUES (v_uid, c.texte, c.version, v_langue, true);
    r := r || jsonb_build_array(jsonb_build_object('texte', c.texte, 'version', c.version));
  END LOOP;
  INSERT INTO public.comptes_activite (user_id, vu_le) VALUES (v_uid, now())
  ON CONFLICT (user_id) DO UPDATE SET vu_le = excluded.vu_le;
  RETURN jsonb_build_object('ok', true, 'accords', r, 'langue', v_langue,
                            'a_accepter', public.juridique_textes_a_accepter_interne(v_uid));
END $$;

-- 3. Premier ordre bloqué côté serveur --------------------------------------------------------------------------------
SELECT pg_temp.rp_remplacer('public.payer_ordre_interne(text,text,integer,integer,integer)'::regprocedure,
  '  PERFORM public.exiger_acteur(p_acteur);',
  '  PERFORM public.exiger_acteur(p_acteur);
  -- juridique_accord_v1 (Fred, 28/11/2026) : CGU et confidentialité acceptées dans leur version en vigueur, compte non suspendu.
  IF public.juridique_ordre_refus_interne(p_acteur) IS NOT NULL THEN RETURN public.juridique_ordre_refus_interne(p_acteur); END IF;',
  'juridique_accord_v1');

-- 4. Export des données du compte connecté ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.juridique_export_lignes_interne(p_sql text, p_nom text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r jsonb;
BEGIN
  EXECUTE format('SELECT coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb) FROM (%s LIMIT 5000) t', p_sql) INTO r USING p_nom;
  RETURN r;
EXCEPTION WHEN undefined_table OR undefined_column THEN
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.mes_donnees_exporter()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid := auth.uid(); v_nom text; r jsonb;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT d.name INTO v_nom FROM public.personnages_donnees d WHERE d.user_id = v_uid LIMIT 1;
  r := jsonb_build_object('ok', true, 'format', 'human-gambit-export-1', 'exporte_le', now(),
    'compte', (SELECT jsonb_build_object('id', u.id, 'email', u.email, 'cree_le', u.created_at,
                                         'derniere_connexion', u.last_sign_in_at, 'email_confirme_le', u.email_confirmed_at)
                 FROM auth.users u WHERE u.id = v_uid),
    'accords', coalesce((SELECT jsonb_agg(jsonb_build_object('texte', a.texte, 'version', a.version, 'langue', a.langue,
                                                             'age_16', a.age_16, 'accepte_le', a.accepte_le) ORDER BY a.id)
                           FROM public.juridique_accords a WHERE a.user_id = v_uid), '[]'::jsonb),
    'sanctions', coalesce((SELECT jsonb_agg(public.moderation_sanction_json_interne(m) ORDER BY m.id)
                             FROM public.moderation_sanctions m WHERE m.user_id = v_uid), '[]'::jsonb),
    'derniere_activite', (SELECT ca.vu_le FROM public.comptes_activite ca WHERE ca.user_id = v_uid),
    'personnage', NULL);
  IF v_nom IS NOT NULL THEN
    r := r || jsonb_build_object(
      'personnage', (SELECT to_jsonb(d) - 'user_id' FROM public.personnages_donnees d WHERE d.name = v_nom),
      'naissance', public.juridique_export_lignes_interne('SELECT * FROM public.etat_civil_naissances WHERE nom = $1', v_nom),
      'comptes_bancaires', public.juridique_export_lignes_interne('SELECT * FROM public.comptes_bancaires WHERE personnage = $1', v_nom),
      'placements', public.juridique_export_lignes_interne('SELECT * FROM public.placements_bancaires WHERE personnage = $1', v_nom),
      'prets', public.juridique_export_lignes_interne('SELECT * FROM public.prets WHERE emprunteur = $1', v_nom),
      'mariages', public.juridique_export_lignes_interne('SELECT * FROM public.mariages WHERE conjoint1 = $1 OR conjoint2 = $1', v_nom),
      'testaments', public.juridique_export_lignes_interne('SELECT * FROM public.testaments WHERE testateur = $1', v_nom),
      'courrier', public.juridique_export_lignes_interne(
        'SELECT * FROM public.mails WHERE to_player = $1 OR from_player = $1 OR from_real = $1 ORDER BY created_at DESC', v_nom),
      'forum', public.juridique_export_lignes_interne(
        'SELECT id, topic_id, author, author_real, content, created_at, edited FROM public.forum_posts WHERE author = $1 OR author_real = $1 ORDER BY created_at DESC', v_nom),
      'conversations', public.juridique_export_lignes_interne(
        'SELECT id, conversation_id, message, salon, created_at FROM public.messages_chat WHERE auteur = $1 ORDER BY created_at DESC', v_nom),
      'journal', public.juridique_export_lignes_interne(
        'SELECT id, type, donnees, cree_le FROM public.crim_evenements WHERE personnage = $1 ORDER BY cree_le DESC', v_nom),
      'signalements_envoyes', public.juridique_export_lignes_interne(
        'SELECT id, source, message_id, motif, statut, cree_le FROM public.signalements_messages WHERE signale_par = $1', v_nom));
  END IF;
  RETURN r;
END $$;

-- 5. Suppression du compte -------------------------------------------------------------------------------------------
-- Forum : les messages restent, signés « Ancien joueur » (sujets, réponses, auteurs réels des organisations secrètes).
CREATE OR REPLACE FUNCTION public.compte_anonymiser_forum_interne(p_nom text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE n integer := 0; k integer;
BEGIN
  IF coalesce(btrim(p_nom), '') = '' OR p_nom = 'Ancien joueur' THEN RETURN 0; END IF;
  UPDATE public.forum_posts SET author = 'Ancien joueur' WHERE author = p_nom AND NOT coalesce(author_is_org, false);
  GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.forum_posts SET author_real = 'Ancien joueur' WHERE author_real = p_nom;
  GET DIAGNOSTICS k = ROW_COUNT; n := n + k;
  UPDATE public.forum_topics SET author = 'Ancien joueur' WHERE author = p_nom AND NOT coalesce(author_is_org, false);
  UPDATE public.forum_topics SET author_real = 'Ancien joueur' WHERE author_real = p_nom;
  UPDATE public.forum_topics SET last_post_author = 'Ancien joueur' WHERE last_post_author = p_nom;
  UPDATE public.auteurs_secrets SET auteur = 'Ancien joueur' WHERE auteur = p_nom AND source = 'forum_posts';
  RETURN n;
END $$;

-- Efface le compte (le personnage doit déjà avoir disparu) : supprime l'utilisateur ; si une ligne s'y rattache encore
-- (achat, décor), le compte est vidé de ses données personnelles et fermé à jamais au lieu d'être supprimé.
CREATE OR REPLACE FUNCTION public.compte_effacer_interne(p_uid uuid, p_noms text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp', 'auth' AS $$
DECLARE n text; v_forum integer := 0; v_mode text;
BEGIN
  IF p_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'compte_absent'); END IF;
  IF EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.user_id = p_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_encore_present'); END IF;
  IF EXISTS (SELECT 1 FROM public.administrateurs a WHERE a.user_id = p_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_administrateur'); END IF;
  FOREACH n IN ARRAY coalesce(p_noms, '{}') LOOP
    v_forum := v_forum + public.compte_anonymiser_forum_interne(n);
  END LOOP;
  DELETE FROM public.comptes_activite WHERE user_id = p_uid;
  DELETE FROM public.comptes_inactifs_avertissements WHERE user_id = p_uid;
  BEGIN
    DELETE FROM auth.users WHERE id = p_uid;
    v_mode := 'supprime';
  EXCEPTION WHEN foreign_key_violation THEN
    DELETE FROM auth.sessions WHERE user_id = p_uid;
    DELETE FROM auth.identities WHERE user_id = p_uid;
    UPDATE auth.users SET email = 'supprime-' || p_uid::text || '@invalid.human-gambit.com', phone = NULL,
           encrypted_password = '', email_change = '', phone_change = '', raw_user_meta_data = '{}'::jsonb,
           banned_until = 'infinity', updated_at = now()
     WHERE id = p_uid;
    v_mode := 'ferme';
  END;
  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'forum_messages', v_forum);
END $$;

CREATE OR REPLACE FUNCTION public.compte_suppression_demander()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid := auth.uid(); v_nom text; v_id bigint;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF EXISTS (SELECT 1 FROM public.administrateurs a WHERE a.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_administrateur'); END IF;
  SELECT d.name INTO v_nom FROM public.personnages_donnees d WHERE d.user_id = v_uid LIMIT 1;
  SELECT s.id INTO v_id FROM public.comptes_suppressions s
   WHERE s.user_id = v_uid AND s.etat = 'demandee' AND s.motif = 'demande' AND s.personnage IS NOT DISTINCT FROM v_nom LIMIT 1;
  IF v_id IS NULL THEN
    INSERT INTO public.comptes_suppressions (user_id, personnage, motif) VALUES (v_uid, v_nom, 'demande') RETURNING id INTO v_id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'demande', v_id, 'personnage', v_nom);
END $$;

CREATE OR REPLACE FUNCTION public.compte_suppression_finaliser()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_uid uuid := auth.uid(); v_noms text[]; r jsonb;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.comptes_suppressions s WHERE s.user_id = v_uid AND s.etat = 'demandee' AND s.motif = 'demande'
                  AND s.demande_le > now() - interval '1 day') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'demande_absente'); END IF;
  IF EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_encore_present'); END IF;
  SELECT array_agg(DISTINCT s.personnage) FILTER (WHERE s.personnage IS NOT NULL) INTO v_noms
    FROM public.comptes_suppressions s WHERE s.user_id = v_uid AND s.etat = 'demandee';
  r := public.compte_effacer_interne(v_uid, v_noms);
  UPDATE public.comptes_suppressions SET etat = CASE WHEN r ->> 'ok' = 'true' THEN 'terminee' ELSE 'echec' END,
         termine_le = now(), detail = r
   WHERE user_id = v_uid AND etat = 'demandee';
  RETURN r;
END $$;

-- 6. Signalements : images personnalisées et noms de personnages ------------------------------------------------------
ALTER TABLE public.signalements_messages DROP CONSTRAINT IF EXISTS signalements_messages_source_check;
ALTER TABLE public.signalements_messages ADD CONSTRAINT signalements_messages_source_check
  CHECK (source IN ('courrier', 'forum', 'conversation', 'image', 'nom'));

CREATE OR REPLACE FUNCTION public.contenu_signaler(p_source text, p_personnage text, p_image text, p_motif text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage(); v_cible text := btrim(coalesce(p_personnage, ''));
  v_motif text := btrim(regexp_replace(coalesce(p_motif, ''), '\s+', ' ', 'g')); v_image text := btrim(coalesce(p_image, ''));
  v_id bigint; v_msg text; v_extrait text;
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_source NOT IN ('image', 'nom') THEN RETURN jsonb_build_object('ok', false, 'raison', 'source_inconnue'); END IF;
  IF v_motif = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'motif_requis'); END IF;
  -- Décor personnalisé (commerce ou logement) : l'auteur est le propriétaire du décor, retrouvé par le serveur.
  IF p_source = 'image' AND v_cible = '' THEN
    SELECT d.name INTO v_cible FROM public.personnages_donnees d
     WHERE d.user_id = coalesce(
       (SELECT c.owner_user_id FROM public.commerce_decors c WHERE coalesce(c.image_path, '') <> ''
          AND (right(v_image, length(c.image_path)) = c.image_path
               OR right(v_image, length(replace(c.image_path, '/', '%2F'))) = replace(c.image_path, '/', '%2F')) LIMIT 1),
       (SELECT l.owner_user_id FROM public.logements_decors l WHERE coalesce(l.image_path, '') <> ''
          AND (right(v_image, length(l.image_path)) = l.image_path
               OR right(v_image, length(replace(l.image_path, '/', '%2F'))) = replace(l.image_path, '/', '%2F')) LIMIT 1))
     LIMIT 1;
    v_cible := coalesce(v_cible, '');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.name = v_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;
  IF v_cible = v_moi THEN RETURN jsonb_build_object('ok', false, 'raison', 'propre_contenu'); END IF;
  IF p_source = 'image' THEN
    IF v_image !~* '^(https?://|images/|/images/)' OR length(v_image) > 2000 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'image_invalide'); END IF;
    v_msg := 'image:' || md5(v_image); v_extrait := v_image;
  ELSE
    v_msg := 'nom:' || v_cible; v_extrait := v_cible;
  END IF;
  INSERT INTO public.signalements_messages (source, message_id, signale_par, motif, auteur, destinataires, mineur, extrait)
  VALUES (p_source, v_msg, v_moi, left(v_motif, 500), v_cible, '{}', public.personnage_est_mineur(v_cible), v_extrait)
  ON CONFLICT (source, message_id, signale_par) DO NOTHING RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'deja', v_id IS NULL);
END $$;

-- Texte de la notification d'une sanction, dans la langue du compte (9 langues).
CREATE OR REPLACE FUNCTION public.moderation_notification_texte_interne(p_langue text, s public.moderation_sanctions)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE d jsonb := '{
 "fr":{"sujet":"Décision de modération","avertissement":"Vous recevez un avertissement de la modération.","retrait_contenu":"Un de vos contenus a été retiré par la modération.","suspension":"Votre compte est suspendu par la modération : vos ordres sont bloqués pendant la durée indiquée.","regle":"Règle enfreinte","contenu":"Contenu visé","duree":"Durée","jours":"{n} jour(s), jusqu''au {fin}","sans_duree":"Sans durée","raison":"Raison","contester":"Vous pouvez contester cette décision en écrivant à contact@human-gambit.com."},
 "en":{"sujet":"Moderation decision","avertissement":"You have received a warning from the moderators.","retrait_contenu":"One of your contents has been removed by the moderators.","suspension":"Your account has been suspended by the moderators: your orders are blocked for the stated period.","regle":"Rule broken","contenu":"Content concerned","duree":"Duration","jours":"{n} day(s), until {fin}","sans_duree":"No duration","raison":"Reason","contester":"You may contest this decision by writing to contact@human-gambit.com."},
 "es":{"sujet":"Decisión de moderación","avertissement":"Ha recibido una advertencia de la moderación.","retrait_contenu":"La moderación ha retirado uno de sus contenidos.","suspension":"La moderación ha suspendido su cuenta: sus órdenes quedan bloqueadas durante el periodo indicado.","regle":"Norma infringida","contenu":"Contenido afectado","duree":"Duración","jours":"{n} día(s), hasta el {fin}","sans_duree":"Sin duración","raison":"Motivo","contester":"Puede impugnar esta decisión escribiendo a contact@human-gambit.com."},
 "de":{"sujet":"Moderationsentscheidung","avertissement":"Sie haben eine Verwarnung der Moderation erhalten.","retrait_contenu":"Einer Ihrer Inhalte wurde von der Moderation entfernt.","suspension":"Ihr Konto wurde von der Moderation gesperrt: Ihre Befehle sind für den angegebenen Zeitraum blockiert.","regle":"Verletzte Regel","contenu":"Betroffener Inhalt","duree":"Dauer","jours":"{n} Tag(e), bis {fin}","sans_duree":"Ohne Dauer","raison":"Begründung","contester":"Sie können diese Entscheidung anfechten, indem Sie an contact@human-gambit.com schreiben."},
 "ru":{"sujet":"Решение модерации","avertissement":"Вы получили предупреждение от модерации.","retrait_contenu":"Модерация удалила один из ваших материалов.","suspension":"Модерация заблокировала ваш аккаунт: ваши приказы недоступны в течение указанного срока.","regle":"Нарушенное правило","contenu":"Затронутый материал","duree":"Срок","jours":"{n} дн., до {fin}","sans_duree":"Без срока","raison":"Причина","contester":"Вы можете оспорить это решение, написав на contact@human-gambit.com."},
 "ko":{"sujet":"운영진 조치 안내","avertissement":"운영진으로부터 경고를 받았습니다.","retrait_contenu":"운영진이 회원님의 콘텐츠 하나를 삭제했습니다.","suspension":"운영진이 회원님의 계정을 정지했습니다. 표시된 기간 동안 명령을 내릴 수 없습니다.","regle":"위반한 규칙","contenu":"대상 콘텐츠","duree":"기간","jours":"{n}일, {fin}까지","sans_duree":"기간 없음","raison":"사유","contester":"이 결정에 이의가 있으면 contact@human-gambit.com 으로 연락해 주세요."},
 "ar":{"sujet":"قرار من الإشراف","avertissement":"تلقيت تحذيرًا من فريق الإشراف.","retrait_contenu":"أزال فريق الإشراف أحد محتوياتك.","suspension":"علّق فريق الإشراف حسابك: أوامرك محظورة طوال المدة المذكورة.","regle":"القاعدة المخالفة","contenu":"المحتوى المعني","duree":"المدة","jours":"{n} يوم/أيام، حتى {fin}","sans_duree":"بلا مدة","raison":"السبب","contester":"يمكنك الاعتراض على هذا القرار بالكتابة إلى contact@human-gambit.com."},
 "pt-BR":{"sujet":"Decisão da moderação","avertissement":"Você recebeu uma advertência da moderação.","retrait_contenu":"Um dos seus conteúdos foi removido pela moderação.","suspension":"Sua conta foi suspensa pela moderação: suas ordens ficam bloqueadas durante o período indicado.","regle":"Regra violada","contenu":"Conteúdo em questão","duree":"Duração","jours":"{n} dia(s), até {fin}","sans_duree":"Sem duração","raison":"Motivo","contester":"Você pode contestar esta decisão escrevendo para contact@human-gambit.com."},
 "zh-TW":{"sujet":"管理決定通知","avertissement":"您已收到管理團隊的警告。","retrait_contenu":"管理團隊已移除您的一項內容。","suspension":"管理團隊已停權您的帳號：在所示期間內無法下達命令。","regle":"違反的規則","contenu":"相關內容","duree":"期間","jours":"{n} 天，至 {fin}","sans_duree":"無期限","raison":"理由","contester":"如對此決定有異議，請寫信至 contact@human-gambit.com。"}
}'::jsonb; t jsonb; v_duree text;
BEGIN
  t := coalesce(d -> public.juridique_langue_interne(p_langue), d -> 'fr');
  v_duree := CASE WHEN s.duree_jours IS NULL THEN t ->> 'sans_duree'
    ELSE replace(replace(t ->> 'jours', '{n}', s.duree_jours::text), '{fin}',
                 to_char(s.fin AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY HH24:MI')) END;
  RETURN jsonb_build_object('sujet', t ->> 'sujet', 'corps',
    (t ->> s.type) || E'\n\n' || (t ->> 'regle') || ' : ' || s.regle || E'\n' || (t ->> 'contenu') || ' : '
    || coalesce(s.contenu, '—') || E'\n' || (t ->> 'duree') || ' : ' || v_duree || E'\n' || (t ->> 'raison') || ' : '
    || s.raison || E'\n\n' || (t ->> 'contester'));
END $$;

CREATE OR REPLACE FUNCTION public.admin_sanction_prononcer(p_signalement_id bigint, p_personnage text, p_type text,
  p_regle text, p_contenu text, p_raison text, p_duree_jours integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_admin uuid := public.admin_exiger(); g public.signalements_messages; v_nom text; v_uid uuid;
  s public.moderation_sanctions; v_txt jsonb; v_mail jsonb;
  v_regle text := btrim(coalesce(p_regle, '')); v_raison text := btrim(coalesce(p_raison, ''));
BEGIN
  IF p_signalement_id IS NOT NULL THEN
    SELECT * INTO g FROM public.signalements_messages WHERE id = p_signalement_id;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'signalement_introuvable'); END IF;
  END IF;
  v_nom := coalesce(nullif(btrim(coalesce(p_personnage, '')), ''), g.auteur);
  SELECT d.user_id INTO v_uid FROM public.personnages_donnees d WHERE d.name = v_nom;
  IF v_uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_joueur'); END IF;
  IF p_type NOT IN ('avertissement', 'retrait_contenu', 'suspension') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'type_inconnu'); END IF;
  IF v_regle = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'regle_requise'); END IF;
  IF v_raison = '' THEN RETURN jsonb_build_object('ok', false, 'raison', 'raison_requise'); END IF;
  IF p_type = 'suspension' AND (p_duree_jours IS NULL OR p_duree_jours NOT BETWEEN 1 AND 3650) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'duree_requise'); END IF;
  INSERT INTO public.moderation_sanctions (signalement_id, personnage, user_id, type, regle, contenu, raison, duree_jours, fin, cree_par)
  VALUES (p_signalement_id, v_nom, v_uid, p_type, left(v_regle, 300),
          left(coalesce(nullif(btrim(coalesce(p_contenu, '')), ''), g.extrait), 2000), left(v_raison, 1000),
          CASE WHEN p_type = 'suspension' THEN p_duree_jours END,
          CASE WHEN p_type = 'suspension' THEN now() + make_interval(days => p_duree_jours) END, v_admin)
  RETURNING * INTO s;
  v_txt := public.moderation_notification_texte_interne(public.juridique_langue_compte_interne(v_uid), s);
  v_mail := public.mail_systeme_poser_interne('Modération', v_nom, v_txt ->> 'sujet', v_txt ->> 'corps', NULL);
  UPDATE public.moderation_sanctions SET notification = v_mail WHERE id = s.id;
  IF p_signalement_id IS NOT NULL THEN
    UPDATE public.signalements_messages SET statut = 'traite', traite_le = now(), traite_par = v_admin WHERE id = p_signalement_id;
  END IF;
  RETURN jsonb_build_object('ok', true, 'sanction', public.moderation_sanction_json_interne(s), 'notification', v_mail);
END $$;

CREATE OR REPLACE FUNCTION public.admin_sanction_lever(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  UPDATE public.moderation_sanctions SET levee_le = now() WHERE id = p_id AND levee_le IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'sanction_introuvable'); END IF;
  RETURN jsonb_build_object('ok', true);
END $$;

CREATE OR REPLACE FUNCTION public.admin_sanctions_lire(p_personnage text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  PERFORM public.admin_exiger();
  RETURN jsonb_build_object('ok', true, 'sanctions', coalesce((
    SELECT jsonb_agg(public.moderation_sanction_json_interne(m) || jsonb_build_object('personnage', m.personnage,
             'signalement_id', m.signalement_id, 'vue_le', m.vue_le) ORDER BY m.cree_le DESC)
      FROM (SELECT * FROM public.moderation_sanctions x WHERE p_personnage IS NULL OR x.personnage = p_personnage
             ORDER BY x.cree_le DESC LIMIT 200) m), '[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.sanction_vue(p_id bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  UPDATE public.moderation_sanctions SET vue_le = now() WHERE id = p_id AND user_id = auth.uid() AND vue_le IS NULL;
  RETURN jsonb_build_object('ok', true);
END $$;

-- 7. Comptes inactifs depuis 3 ans ------------------------------------------------------------------------------------
-- Dernière activité : création, dernière connexion, dernier chargement du plateau. Jamais un administrateur, jamais un
-- compte de test.
CREATE OR REPLACE FUNCTION public.comptes_activites_interne()
RETURNS TABLE (user_id uuid, email text, activite timestamptz) LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp' AS $$
  SELECT u.id, u.email::text,
         greatest(u.created_at, coalesce(u.last_sign_in_at, u.created_at), coalesce(ca.vu_le, u.created_at))
    FROM auth.users u LEFT JOIN public.comptes_activite ca ON ca.user_id = u.id
   WHERE NOT EXISTS (SELECT 1 FROM public.administrateurs a WHERE a.user_id = u.id)
     AND NOT EXISTS (SELECT 1 FROM public.comptes_test t WHERE t.user_id = u.id)
     AND NOT EXISTS (SELECT 1 FROM public.comptes_test t JOIN public.personnages_donnees d ON d.name = t.personnage
                      WHERE d.user_id = u.id)
     AND coalesce(u.email, '') NOT LIKE 'supprime-%@invalid.human-gambit.com';
$$;

CREATE OR REPLACE FUNCTION public.comptes_inactifs_lister(p_limite integer DEFAULT 50)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', true,
    'avertir', coalesce((SELECT jsonb_agg(x) FROM (
        SELECT jsonb_build_object('user_id', a.user_id, 'email', a.email, 'activite', a.activite,
               'suppression_le', greatest(a.activite + interval '3 years', now() + interval '30 days'),
               'langue', public.juridique_langue_compte_interne(a.user_id),
               'personnage', (SELECT d.name FROM public.personnages_donnees d WHERE d.user_id = a.user_id LIMIT 1)) x
          FROM public.comptes_activites_interne() a
          LEFT JOIN public.comptes_inactifs_avertissements w ON w.user_id = a.user_id
         WHERE a.activite < now() - interval '3 years' + interval '1 month'
           AND coalesce(a.email, '') <> ''
           AND (w.user_id IS NULL OR w.averti_le < a.activite)
         ORDER BY a.activite LIMIT greatest(1, least(coalesce(p_limite, 50), 500))) s), '[]'::jsonb),
    'supprimer', coalesce((SELECT jsonb_agg(x) FROM (
        SELECT jsonb_build_object('user_id', a.user_id, 'activite', a.activite, 'averti_le', w.averti_le) x
          FROM public.comptes_activites_interne() a
          JOIN public.comptes_inactifs_avertissements w ON w.user_id = a.user_id
         WHERE a.activite < now() - interval '3 years'
           AND w.averti_le > a.activite AND w.averti_le <= now() - interval '30 days'
         ORDER BY a.activite LIMIT greatest(1, least(coalesce(p_limite, 50), 500))) s), '[]'::jsonb));
$$;

-- Noté seulement après un envoi réel de l'e-mail (api/_comptes-inactifs.js) : sans avertissement, aucune suppression.
CREATE OR REPLACE FUNCTION public.comptes_inactifs_avertissement_noter(p_uid uuid, p_activite timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'appel_serveur_requis'); END IF;
  INSERT INTO public.comptes_inactifs_avertissements (user_id, activite_le, averti_le) VALUES (p_uid, p_activite, now())
  ON CONFLICT (user_id) DO UPDATE SET activite_le = excluded.activite_le, averti_le = excluded.averti_le;
  RETURN jsonb_build_object('ok', true);
END $$;

-- Liens qui empêchent la suppression d'une fiche (clé étrangère sans cascade) : les nuitées d'hôtel du personnage.
-- Sans cela, « Détruire mon personnage » échouait en silence pour tout client d'un hôtel (constat du 28/11/2026).
-- Les traces du goulag (sovarka_goulag_*) ne sont pas effacées : leur suppression bloque toujours (question à Fred).
CREATE OR REPLACE FUNCTION public.personnage_liens_liberer_interne(p_nom text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE n integer;
BEGIN
  DELETE FROM public.hotel_nuitees WHERE personnage_id = (SELECT d.id FROM public.personnages_donnees d WHERE d.name = p_nom);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;
-- Appelée par l'écran juste avant la suppression de la fiche, une fois la succession ouverte (plateau-personnage.js).
CREATE OR REPLACE FUNCTION public.personnage_suppression_liens_liberer()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text := public.mon_personnage();
BEGIN
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.successions s WHERE s.defunt = v_moi AND s.statut = 'en_attente') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'succession_non_ouverte'); END IF;
  RETURN jsonb_build_object('ok', true, 'nuitees', public.personnage_liens_liberer_interne(v_moi));
END $$;

-- Succession côté serveur d'un personnage dont le compte disparaît sans navigateur (inactivité) : mêmes portes que
-- l'écran (succession_ouvrir, gels, prêts, convocations, testament, veuvage, acte de décès, suppression), jouées au nom
-- du compte. Échec à l'ouverture ou au gel : rien n'est supprimé (même doctrine que confirmerDestructionPersonnage).
CREATE OR REPLACE FUNCTION public.compte_succession_serveur_interne(p_uid uuid, p_nom text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_claims text := current_setting('request.jwt.claims', true); v_sub text := current_setting('request.jwt.claim.sub', true);
  v jsonb; d jsonb; g jsonb; v_sid text; v_benef text; v_vus text[] := '{}'; v_pays text; v_ville text; r jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
  BEGIN
    IF public.mon_personnage() IS DISTINCT FROM p_nom THEN
      r := jsonb_build_object('ok', false, 'raison', 'personnage_non_rattache');
    ELSE
      SELECT coalesce(country, 'republic'), current_city INTO v_pays, v_ville FROM public.personnages_donnees WHERE name = p_nom;
      v := public.succession_ouvrir();
      IF v ->> 'ok' IS DISTINCT FROM 'true' THEN
        r := jsonb_build_object('ok', false, 'raison', 'succession:' || coalesce(v ->> 'raison', '?'));
      ELSE
        v_sid := v ->> 'succession_id';
        FOR d IN SELECT * FROM jsonb_array_elements(coalesce(v -> 'dispositions', '[]'::jsonb)) LOOP
          IF d ->> 'type' = 'terrain' THEN g := public.terrain_succession_geler(d ->> 'id', v_sid);
          ELSIF d ->> 'type' = 'entreprise' THEN g := public.entreprise_succession_geler(p_nom, d ->> 'id', v_sid);
          ELSE g := jsonb_build_object('ok', true); END IF;
          IF g ->> 'ok' IS DISTINCT FROM 'true' THEN
            RAISE EXCEPTION 'gel_impossible:%', d ->> 'id';
          END IF;
        END LOOP;
        UPDATE public.prets SET statut = 'succession' WHERE emprunteur = p_nom AND statut = 'en_cours';
        FOR d IN SELECT * FROM jsonb_array_elements(coalesce(v -> 'dispositions', '[]'::jsonb)) LOOP
          v_benef := d -> 'chaine' -> -1 ->> 'beneficiaire';
          CONTINUE WHEN v_benef IS NULL OR v_benef = ANY (v_vus);
          v_vus := v_vus || v_benef;
          PERFORM public.mail_systeme_poser_interne('Office Notarial', v_benef, 'Succession — ' || p_nom,
            p_nom || ' est décédé(e). Vous êtes convoqué(e) au sujet d''une succession. Rendez-vous au Bureau des Successions de l''Office Notarial de Luthécia, rubrique « Réclamer un héritage », pour consulter et répondre.', '');
        END LOOP;
        IF v ->> 'conjoint' IS NOT NULL THEN
          PERFORM public.mail_systeme_poser_interne('Office Notarial', v ->> 'conjoint', 'Succession — ' || p_nom,
            p_nom || ', votre conjoint(e), est décédé(e). En tant que conjoint(e) survivant(e), vous pouvez consulter l''ensemble du règlement successoral au Bureau des Successions de l''Office Notarial de Luthécia, rubrique « Réclamer un héritage ».', '');
        END IF;
        -- Veuvage : le mariage actif du défunt est dissous (mariage_dissoudre ne s'appelle que par le survivant).
        IF v ->> 'mariage_id' IS NOT NULL THEN
          UPDATE public.mariages SET statut = 'dissous', raison_dissolution = 'veuvage', dissous_at = now()
           WHERE id::text = v ->> 'mariage_id' AND statut = 'actif';
        END IF;
        IF v ->> 'testament_id' IS NOT NULL THEN
          UPDATE public.testaments SET statut = 'execute' WHERE id = v ->> 'testament_id';
        END IF;
        INSERT INTO public.etat_civil_deces (id, nom, country, city)
        VALUES ('deces-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint, p_nom, v_pays, v_ville);
        PERFORM public.personnage_liens_liberer_interne(p_nom);
        DELETE FROM public.personnages WHERE name = p_nom;
        IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom) THEN RAISE EXCEPTION 'fiche_non_supprimee'; END IF;
        DELETE FROM public.presences WHERE name = p_nom;
        DELETE FROM public.dons_en_attente WHERE destinataire = p_nom;
        DELETE FROM public.votes_electoraux WHERE votant = p_nom;
        DELETE FROM public.candidatures WHERE nom = p_nom;
        r := jsonb_build_object('ok', true, 'succession_id', v_sid);
      END IF;
    END IF;
  EXCEPTION WHEN others THEN
    r := jsonb_build_object('ok', false, 'raison', 'echec:' || left(SQLERRM, 200));
  END;
  PERFORM set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  PERFORM set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  RETURN r;
END $$;

CREATE OR REPLACE FUNCTION public.compte_inactif_supprimer(p_uid uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a record; v_nom text; r jsonb; e jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN RETURN jsonb_build_object('ok', false, 'raison', 'appel_serveur_requis'); END IF;
  SELECT x.* INTO a FROM public.comptes_activites_interne() x
    JOIN public.comptes_inactifs_avertissements w ON w.user_id = x.user_id
   WHERE x.user_id = p_uid AND x.activite < now() - interval '3 years'
     AND w.averti_le > x.activite AND w.averti_le <= now() - interval '30 days';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'non_eligible'); END IF;
  SELECT d.name INTO v_nom FROM public.personnages_donnees d WHERE d.user_id = p_uid LIMIT 1;
  IF v_nom IS NOT NULL THEN
    r := public.compte_succession_serveur_interne(p_uid, v_nom);
    IF r ->> 'ok' IS DISTINCT FROM 'true' THEN
      INSERT INTO public.comptes_suppressions (user_id, personnage, motif, etat, detail, termine_le)
      VALUES (p_uid, v_nom, 'inactivite', 'echec', r, now());
      RETURN r;
    END IF;
  END IF;
  e := public.compte_effacer_interne(p_uid, CASE WHEN v_nom IS NULL THEN '{}'::text[] ELSE ARRAY[v_nom] END);
  INSERT INTO public.comptes_suppressions (user_id, personnage, motif, etat, detail, termine_le)
  VALUES (p_uid, v_nom, 'inactivite', CASE WHEN e ->> 'ok' = 'true' THEN 'terminee' ELSE 'echec' END,
          jsonb_build_object('succession', r, 'effacement', e), now());
  RETURN e || jsonb_build_object('personnage', v_nom);
END $$;

-- Droits ---------------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.juridique_version_courante_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.juridique_versions_courantes_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.juridique_textes_a_accepter_interne(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.juridique_langue_compte_interne(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.moderation_sanction_json_interne(public.moderation_sanctions) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.juridique_ordre_refus_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.juridique_export_lignes_interne(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compte_anonymiser_forum_interne(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compte_effacer_interne(uuid, text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.moderation_notification_texte_interne(text, public.moderation_sanctions) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.comptes_activites_interne() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compte_succession_serveur_interne(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.personnage_liens_liberer_interne(text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.juridique_etat() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.juridique_accepter(text, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mes_donnees_exporter() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.compte_suppression_demander() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.compte_suppression_finaliser() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.contenu_signaler(text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sanction_vue(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.personnage_suppression_liens_liberer() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_sanction_prononcer(bigint, text, text, text, text, text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_sanction_lever(bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_sanctions_lire(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.juridique_etat() TO authenticated;
GRANT EXECUTE ON FUNCTION public.juridique_accepter(text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mes_donnees_exporter() TO authenticated;
GRANT EXECUTE ON FUNCTION public.compte_suppression_demander() TO authenticated;
GRANT EXECUTE ON FUNCTION public.compte_suppression_finaliser() TO authenticated;
GRANT EXECUTE ON FUNCTION public.contenu_signaler(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sanction_vue(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.personnage_suppression_liens_liberer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_sanction_prononcer(bigint, text, text, text, text, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_sanction_lever(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_sanctions_lire(text) TO authenticated;

REVOKE ALL ON FUNCTION public.comptes_inactifs_lister(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.comptes_inactifs_avertissement_noter(uuid, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compte_inactif_supprimer(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.comptes_inactifs_lister(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.comptes_inactifs_avertissement_noter(uuid, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.compte_inactif_supprimer(uuid) TO service_role;

COMMIT;
