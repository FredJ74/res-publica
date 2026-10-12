-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012155129 (UTC), nom
-- `administration_socle_et_incarnation_du_parquet_et_du_juge`.
-- Le registre passe de 690 a 691 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 59d6938a68e756dbd1cdd3f14be0adb6, 47532 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE SOCLE D'ADMINISTRATION, ET L'INCARNATION DE SAAD ET D'HONORE -- §B a §I
--
-- IL N'EXISTAIT AUCUN MODELE D'AUTORITE ADMINISTRATEUR DANS CE DEPOT. L'autorite est desormais
-- UNE LIGNE DANS `administrateurs`, indexee par `auth.uid()` : un compte Supabase Auth reel,
-- distinct du compte joueur, verifie au serveur a CHAQUE action sensible par `admin_exiger()`,
-- qui LEVE en 42501. Ne font PAS autorite : un bouton cache, localStorage, une variable JS,
-- l'identite d'un PJ, `CRON_SECRET`, la connaissance de l'URL du panneau.
--
-- L'INCARNATION PASSE PAR LES PORTES METIER. `admin_incarner` ne touche AUCUNE table judiciaire :
-- elle pose une incarnation pour la duree de la transaction, appelle la fonction que le titulaire
-- appellerait, gardes intactes, et consigne a l'audit prive. Aucun pouvoir supplementaire.
--
-- ELLE N'EXISTE QUE SI LE PNJ EST REELLEMENT TITULAIRE, et c'est verifie DEUX FOIS -- par la
-- porte au clic, et par les resolveurs d'identite eux-memes (`parquet_moi`, `juge_moi`). Un PJ qui
-- prend le poste entre l'ouverture de l'ecran et le clic fait echouer l'action, meme en appel
-- direct.
--
-- PERIMETRE FERME A DEUX POSTES : le parquet national et le juge de la capitale. Aucun autre PNJ.
--
-- INVISIBLE AUX JOUEURS PAR CONSTRUCTION : la porte n'ecrivant rien, il n'existe aucune donnee de
-- provenance a fuiter -- ni vers l'interface, ni vers le greffe, ni vers les IA.
--
-- AUDIT PRIVE A TROIS VERROUS : aucun droit client, aucune policy, et un declencheur qui refuse
-- toute modification et toute suppression -- y compris a `service_role`.
--
-- UN DEFAUT REEL CORRIGE EN PASSANT : `parquet_garde` appelait `acteur_present_sur_site` avec
-- QUATRE arguments pour une fonction qui en exige CINQ. Le controle de presence levait 42883 et
-- TOUTES les actions du parquet etaient cassees en production. PostgreSQL n'analyse pas les corps
-- plpgsql a la creation : les 37 preuves structurelles de la tranche du parquet ne pouvaient pas
-- le voir.
--
-- EPROUVEE PAR outils/bancs/banc-administration-tribunal.sql -- 25 epreuves, transaction annulee.
--
-- PREUVES STRUCTURELLES -- 16.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE SOCLE D'ADMINISTRATION, ET L'INCARNATION DE SAAD ET D'HONORE
-- 12 octobre 2026 -- §B a §I du cahier des charges du Tribunal
--
-- IL N'EXISTAIT AUCUN MODELE D'AUTORITE ADMINISTRATEUR DANS CE DEPOT. Ni table, ni session, ni
-- role : la seule autorite non-joueur etait `CRON_SECRET`, un en-tete partage par les routes
-- /api/*, et la detourner aurait fait d'un secret de deploiement une identite humaine. Cette
-- migration pose le socle, et rien de plus large que necessaire.
--
-- CE QUI FAIT L'AUTORITE, ET CE QUI NE LA FAIT PAS. L'autorite est UNE LIGNE DANS
-- `administrateurs`, indexee par `auth.uid()` : un compte Supabase Auth REEL, distinct du compte
-- joueur, avec son propre jeton et sa propre session. Elle est verifiee au serveur a CHAQUE
-- action sensible, par `admin_exiger()`, qui LEVE en 42501. Ne font PAS autorite, et ne peuvent
-- pas en faire : un bouton cache, `localStorage`, une variable JS, l'identite d'un PJ, la
-- connaissance de l'URL du panneau. Le navigateur ne transporte qu'un jeton signe ; c'est la base
-- qui dit s'il appartient a un administrateur.
--
-- L'ADMINISTRATION NE DEPEND PAS D'UN PERSONNAGE. Un administrateur n'a pas de fiche, pas de
-- position, pas de poste : `mon_personnage()` lui rend NULL, et c'est voulu. Les deux sessions --
-- joueur et administrateur -- vivent cote a cote dans le meme navigateur parce qu'elles ne
-- partagent aucune cle de stockage. Il n'y a AUCUNE bascule de role depuis un personnage.
--
-- L'INCARNATION PASSE PAR LES PORTES METIER, PAS A COTE. `admin_incarner` ne touche AUCUNE table
-- judiciaire : elle pose une incarnation dans la transaction, appelle la fonction metier que le
-- titulaire appellerait, et consigne. Toutes les gardes restent en place -- statut, delai de
-- jugement, juridiction, presence physique du parquet. L'administration ne donne donc AUCUN
-- pouvoir supplementaire : si le Procureur ne peut pas, l'administrateur ne peut pas.
--
-- L'INCARNATION N'EXISTE QUE SI LE PNJ EST REELLEMENT TITULAIRE. `admin_pnj_titulaire` rend NULL
-- des qu'un PJ porte le poste -- c'est LUI le titulaire, le PNJ n'est plus que present. Et la
-- verification est faite DEUX FOIS : par la porte au moment du clic, et par le resolveur
-- d'identite lui-meme (`parquet_moi`, `juge_moi`). Un PJ qui prend le poste entre l'ouverture de
-- l'ecran et le clic fait donc echouer l'action, meme si le client appelle directement.
--
-- LE PERIMETRE EST FERME A DEUX POSTES. Le parquet national et le juge de la capitale, c'est-a-
-- dire Saad et Honore. Aucun autre PNJ n'est incarnable : ni President, ni ministre, ni maire, ni
-- depute, ni police, ni armee, ni les juges de province. Le socle est techniquement extensible --
-- une ligne de registre -- mais il n'y a que ces deux lignes.
--
-- L'INTERVENTION EST INVISIBLE AUX JOUEURS. Elle ne peut pas ne pas l'etre : la porte n'ecrit
-- rien dans `plaintes_en_cours`, `dossiers_judiciaires_actes` ni `jugements`. Ce sont les
-- fonctions metier qui ecrivent, exactement comme pour un titulaire, avec le PNJ pour auteur. Il
-- n'existe donc aucun champ, aucun marqueur, aucune metadonnee de provenance a fuiter -- ni vers
-- l'interface joueur, ni vers le greffe public, ni vers le journal, ni vers les rumeurs, ni vers
-- le contexte des IA, ni vers le dialogue PNJ. Pour le monde, l'auteur est SAAD ou HONORE.
--
-- L'AUDIT EST PRIVE PAR TROIS VERROUS. `admin_journal` n'a aucun droit client, aucune policy, et
-- un declencheur qui refuse toute modification et toute suppression -- y compris a `service_role`
-- et aux fonctions SECURITY DEFINER. Il n'est lisible que par le proprietaire de la base.
--
-- UN DEFAUT REEL CORRIGE EN PASSANT : `parquet_garde` appelait `acteur_present_sur_site` avec
-- QUATRE arguments alors que la fonction en exige CINQ. Le controle de presence levait donc
-- 42883 -- « function does not exist » -- et TOUTES les actions du parquet etaient cassees en
-- production. PostgreSQL n'analyse pas les corps plpgsql a la creation : les 37 preuves
-- structurelles de la tranche du parquet ne pouvaient pas le voir. Mesure avant correction.
--
-- LA CREATION DU PREMIER COMPTE : UNE SEULE ETAPE RESTE HORS DEPOT, et aucun secret n'est
-- invente. `admin_se_declarer()` n'ouvre qu'une fois dans la vie de la base -- la table doit etre
-- VIDE -- et seulement pour un compte qui a une adresse, qui n'est PAS anonyme, et qui ne porte
-- AUCUN personnage. Il reste donc a creer un utilisateur courriel/mot de passe dans la console
-- Supabase, puis a se connecter sur le panneau et a presser le bouton unique. Rien a executer en
-- SQL, aucun mot de passe dans Git.
--
-- PREUVES STRUCTURELLES -- 16.

-- ============================================================================================
-- 1. LES DEUX TABLES : L'AUTORITE, ET L'AUDIT PRIVE
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.administrateurs (
  user_id uuid        NOT NULL,
  libelle text        NOT NULL,
  actif   boolean     NOT NULL DEFAULT true,
  cree_le timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT administrateurs_pk PRIMARY KEY (user_id)
);
-- UNE TABLE NEUVE NAIT OUVERTE AUX ROLES CLIENTS (defaut de la plateforme). On referme.
REVOKE ALL ON TABLE public.administrateurs FROM anon, authenticated;
ALTER TABLE public.administrateurs ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.admin_journal (
  rang          bigserial   NOT NULL,
  admin_user_id uuid        NOT NULL,
  admin_libelle text,
  pnj           text,
  poste         text,
  affaire       text,
  action        text        NOT NULL,
  parametres    jsonb,
  resultat      jsonb,
  ok            boolean,
  fait_le       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT admin_journal_pk PRIMARY KEY (rang)
);
REVOKE ALL ON TABLE public.admin_journal FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.admin_journal_rang_seq FROM anon, authenticated;
ALTER TABLE public.admin_journal ENABLE ROW LEVEL SECURITY;

-- TROISIEME VERROU DE L'AUDIT : il ne se reecrit pas, et il ne s'effface pas. Un declencheur qui
-- LEVE bat `service_role` et les fonctions SECURITY DEFINER, ce qu'une absence de droit ne fait
-- pas.
CREATE OR REPLACE FUNCTION public.admin_journal_append_only()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  RAISE EXCEPTION 'admin_journal est en ajout seul : ni modification ni suppression (%)', TG_OP
    USING ERRCODE = '42501';
END $$;
DROP TRIGGER IF EXISTS trg_admin_journal_append_only ON public.admin_journal;
CREATE TRIGGER trg_admin_journal_append_only
  BEFORE UPDATE OR DELETE ON public.admin_journal
  FOR EACH ROW EXECUTE FUNCTION public.admin_journal_append_only();

-- ============================================================================================
-- 2. LE REGISTRE DES ACTIONS : LE MENU, PAS LA GARDE
-- ============================================================================================
-- Ce registre dit ce que le panneau PROPOSE et ce que la porte ACCEPTE comme nom d'action. Il ne
-- decide rien : la garde de statut vit dans la fonction metier, et c'est elle qui tranche. Pour
-- qu'il ne puisse pas DIVERGER de ces gardes, `garde_texte` porte le fragment exact attendu dans
-- le corps de la fonction, et une preuve le verifie -- un barreme deplace cote metier ferait donc
-- echouer la migration suivante au lieu de donner un menu qui mente.
CREATE TABLE IF NOT EXISTS public.admin_actions_tribunal (
  poste       text    NOT NULL,
  action      text    NOT NULL,
  fonction    text    NOT NULL,
  statuts     text[]  NOT NULL,
  garde_texte text    NOT NULL,
  libelle     text    NOT NULL,
  ordre       integer NOT NULL,
  CONSTRAINT admin_actions_tribunal_pk PRIMARY KEY (poste, action),
  CONSTRAINT admin_actions_tribunal_poste CHECK (poste IN ('procureur', 'juge'))
);
REVOKE ALL ON TABLE public.admin_actions_tribunal FROM anon, authenticated;
ALTER TABLE public.admin_actions_tribunal ENABLE ROW LEVEL SECURITY;

DELETE FROM public.admin_actions_tribunal;
INSERT INTO public.admin_actions_tribunal (poste, action, fonction, statuts, garde_texte, libelle, ordre) VALUES
  ('procureur', 'enqueter',         'parquet_enqueter',         ARRAY['au_parquet'],
     'ARRAY[''au_parquet'']',                  'Diligenter une enquete',          1),
  ('procureur', 'poursuivre',       'parquet_poursuivre',       ARRAY['au_parquet','enquete'],
     'ARRAY[''au_parquet'', ''enquete'']',     'Engager les poursuites',          2),
  ('procureur', 'non_lieu',         'parquet_non_lieu',         ARRAY['au_parquet','enquete'],
     'ARRAY[''au_parquet'', ''enquete'']',     'Prononcer un non-lieu',           3),
  ('procureur', 'transmettre_juge', 'parquet_transmettre_juge', ARRAY['poursuites'],
     'ARRAY[''poursuites'']',                  'Saisir le juge',                  4),
  ('procureur', 'abandonner',       'parquet_abandonner',       ARRAY['poursuites','saisie'],
     'ARRAY[''poursuites'', ''saisie'']',      'Abandonner les poursuites',       5),
  ('procureur', 'appel_ouvrir',     'justice_appel_ouvrir',     ARRAY['jugee','relaxe'],
     'NOT IN (''jugee'', ''relaxe'')',         'Interjeter appel',                6),
  ('juge',      'relaxer',          'justice_relaxer',          ARRAY['saisie'],
     '<> ''saisie''',                          'Relaxer',                         1),
  ('juge',      'rendre_sentence',  'justice_rendre_sentence',  ARRAY['saisie'],
     '<> ''saisie''',                          'Rendre la sentence',              2),
  ('juge',      'suite_apres_abandon', 'juge_suite_apres_abandon', ARRAY['abandon_demande'],
     '<> ''abandon_demande''',                 'Statuer sur l''abandon',          3),
  ('juge',      'juger_appel',      'justice_appel_juger',      ARRAY['appel'],
     '<> ''appel''',                           'Juger en appel',                  4);

-- ============================================================================================
-- 3. L'AUTORITE : UNE LIGNE EN BASE, VERIFIEE A CHAQUE ACTION
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.est_administrateur()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT auth.uid() IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.administrateurs a
                  WHERE a.user_id = auth.uid() AND a.actif);
$$;
COMMENT ON FUNCTION public.est_administrateur() IS
  'Vrai si le compte authentifie porte une autorite administrateur active. Seule definition de cette autorite.';

CREATE OR REPLACE FUNCTION public.admin_exiger()
RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- ELLE LEVE, ELLE NE REFUSE PAS. Un refus propre serait jete par un appelant distrait ; une
  -- exception annule la transaction entiere. C'est la meme doctrine que `exiger_poste`.
  IF NOT public.est_administrateur() THEN
    RAISE EXCEPTION 'autorite_administrateur_requise' USING ERRCODE = '42501';
  END IF;
  RETURN auth.uid();
END $$;

CREATE OR REPLACE FUNCTION public.admin_moi()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT jsonb_build_object(
    'ok', true,
    'administrateur', public.est_administrateur(),
    'libelle', (SELECT a.libelle FROM public.administrateurs a
                 WHERE a.user_id = auth.uid() AND a.actif),
    'bootstrap_ouvert', NOT EXISTS (SELECT 1 FROM public.administrateurs));
$$;
COMMENT ON FUNCTION public.admin_moi() IS
  'Ce que le panneau a le droit de savoir : suis-je administrateur, et le premier compte reste-t-il a declarer.';

-- LA DECLARATION DU PREMIER COMPTE, UNE SEULE FOIS DANS LA VIE DE LA BASE.
CREATE OR REPLACE FUNCTION public.admin_se_declarer(p_libelle text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_uid uuid; v_u record; v_n integer;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_session');
  END IF;
  -- LA PORTE EST FERMEE DES QU'UN ADMINISTRATEUR EXISTE. Definitivement : il n'y a pas de
  -- deuxieme declaration, et donc pas de fenetre a guetter.
  IF EXISTS (SELECT 1 FROM public.administrateurs) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'administration_deja_constituee');
  END IF;
  -- UNE IDENTITE REELLE, PAS UN ANONYME. Les comptes joueurs sont anonymes (chantier B) : aucun
  -- d'eux ne peut franchir cette ligne.
  SELECT u.email, u.is_anonymous INTO v_u FROM auth.users u WHERE u.id = v_uid;
  IF NOT FOUND OR coalesce(v_u.is_anonymous, false) IS TRUE
     OR coalesce(btrim(coalesce(v_u.email, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_sans_identite_reelle');
  END IF;
  -- « CE N'EST PAS LE COMPTE JOUEUR. » Un compte qui porte un personnage ne peut pas devenir
  -- administrateur : c'est la separation demandee, et elle est verifiee, pas supposee.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_porte_un_personnage');
  END IF;

  INSERT INTO public.administrateurs (user_id, libelle)
  VALUES (v_uid, coalesce(nullif(btrim(coalesce(p_libelle, '')), ''), 'Administration'))
  ON CONFLICT (user_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'administration_deja_constituee');
  END IF;

  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, ok, resultat)
  VALUES (v_uid, coalesce(nullif(btrim(coalesce(p_libelle, '')), ''), 'Administration'),
          'declaration_premier_administrateur', true,
          jsonb_build_object('email', v_u.email));
  RETURN jsonb_build_object('ok', true, 'administrateur', true);
END $$;

GRANT EXECUTE ON FUNCTION public.admin_moi() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_se_declarer(text) TO authenticated;

-- ============================================================================================
-- 4. L'INCARNATION : TROIS LECTURES, TOUTES GARDEES PAR L'AUTORITE
-- ============================================================================================
-- Le contexte d'incarnation vit dans des reglages de TRANSACTION, poses par la seule porte
-- administrative. Un client ne peut pas les poser : PostgREST n'expose que les fonctions du
-- schema `public`, `set_config` n'y est pas, et aucune fonction appelable par un client ne pose
-- un reglage dont le nom vient d'un parametre. Et meme si un reglage fuyait, ces trois lectures
-- rendent NULL pour qui n'est pas administrateur : l'autorite est verifiee a chaque lecture.
CREATE OR REPLACE FUNCTION public.incarnation_courante()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE WHEN public.est_administrateur()
              THEN nullif(current_setting('rp.incarnation_pnj', true), '') END;
$$;
CREATE OR REPLACE FUNCTION public.incarnation_pays()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE WHEN public.est_administrateur()
              THEN nullif(current_setting('rp.incarnation_pays', true), '') END;
$$;
CREATE OR REPLACE FUNCTION public.incarnation_siege()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE WHEN public.est_administrateur()
              THEN nullif(current_setting('rp.incarnation_siege', true), '') END;
$$;

-- LE PNJ EST-IL REELLEMENT TITULAIRE ? Un PJ sur le poste rend NULL : c'est lui le titulaire.
CREATE OR REPLACE FUNCTION public.admin_pnj_titulaire(p_pays text, p_poste text, p_ville text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE WHEN EXISTS (
      SELECT 1 FROM public.personnages_donnees d
       WHERE d.country = p_pays AND (d.poste ->> 'id') = p_poste
         AND (d.poste ->> 'city') IS NOT DISTINCT FROM p_ville)
    THEN NULL
    ELSE (SELECT t.nom_pnj FROM public.titulaires_pnj t
           WHERE t.country = p_pays AND t.poste_id = p_poste
             AND t.city IS NOT DISTINCT FROM p_ville LIMIT 1)
  END;
$$;
COMMENT ON FUNCTION public.admin_pnj_titulaire(text, text, text) IS
  'Nom du PNJ titulaire du poste, ou NULL si un PJ le porte. Seule definition de la titularite PNJ.';

-- ============================================================================================
-- 5. LES RESOLVEURS D'IDENTITE RECONNAISSENT L'INCARNATION -- ET REVERIFIENT LA TITULARITE
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.parquet_moi()
RETURNS TABLE(nom text, pays text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_inc text; v_pays text; v_pnj text;
BEGIN
  -- CHEMIN NORMAL, INCHANGE : le PJ qui porte le poste. Il a toujours la priorite.
  RETURN QUERY
    SELECT d.name, d.country FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'procureur'
     LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  -- INCARNATION ADMINISTRATIVE. La titularite est REVERIFIEE ICI, et pas seulement a la porte :
  -- un PJ qui prend le poste ferme l'incarnation au moment meme de l'acte.
  v_inc := public.incarnation_courante();
  IF v_inc IS NULL THEN RETURN; END IF;
  v_pays := public.incarnation_pays();
  IF v_pays IS NULL THEN RETURN; END IF;
  v_pnj := public.admin_pnj_titulaire(v_pays, 'procureur', NULL);
  IF v_pnj IS NULL OR v_pnj IS DISTINCT FROM v_inc THEN RETURN; END IF;
  RETURN QUERY SELECT v_pnj, v_pays;
END $$;

-- LE JUGE A DESORMAIS UN RESOLVEUR, et c'est le SEUL endroit ou son identite se decide.
CREATE OR REPLACE FUNCTION public.juge_moi()
RETURNS TABLE(nom text, pays text, ville text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_inc text; v_pays text; v_ville text; v_pnj text;
BEGIN
  RETURN QUERY
    SELECT d.name, d.country, coalesce(d.poste ->> 'city', 'capitale')
      FROM public.personnages_donnees d
     WHERE d.user_id = auth.uid() AND (d.poste ->> 'id') = 'juge'
     LIMIT 1;
  IF FOUND THEN RETURN; END IF;

  v_inc := public.incarnation_courante();
  IF v_inc IS NULL THEN RETURN; END IF;
  v_pays  := public.incarnation_pays();
  v_ville := public.incarnation_siege();
  IF v_pays IS NULL OR v_ville IS NULL THEN RETURN; END IF;
  v_pnj := public.admin_pnj_titulaire(v_pays, 'juge', v_ville);
  IF v_pnj IS NULL OR v_pnj IS DISTINCT FROM v_inc THEN RETURN; END IF;
  RETURN QUERY SELECT v_pnj, v_pays, v_ville;
END $$;

-- `juge_de_la_ville` ne porte plus que la CONDITION TERRITORIALE, posee sur le resolveur unique.
CREATE OR REPLACE FUNCTION public.juge_de_la_ville(p_ville text)
RETURNS TABLE(nom text, pays text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT j.nom, j.pays FROM public.juge_moi() j
   WHERE j.ville IS NOT DISTINCT FROM coalesce(p_ville, 'capitale');
$$;

-- `juge_dossiers` lisait la fiche directement : elle passe par le resolveur, sinon l'incarnation
-- aurait un juge capable d'agir mais incapable de voir son propre role.
CREATE OR REPLACE FUNCTION public.juge_dossiers()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_j record;
BEGIN
  SELECT * INTO v_j FROM public.juge_moi();
  IF v_j.nom IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'pas_juge'); END IF;

  RETURN jsonb_build_object('ok', true, 'juge', v_j.nom, 'ville', coalesce(v_j.ville, 'capitale'),
    'dossiers', (SELECT coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'ville', p.city, 'dossier', p.data::jsonb,
        'actes', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                     'rang', a.rang, 'type', a.type, 'libelle', t.libelle,
                     'acteur', a.acteur, 'poste', a.acteur_poste,
                     'qualif_avant', a.qualif_avant, 'qualif_apres', a.qualif_apres,
                     'donnees', a.donnees, 'fait_le', a.fait_le) ORDER BY a.rang), '[]'::jsonb)
                    FROM public.dossiers_judiciaires_actes a
                    JOIN public.dossiers_judiciaires_actes_types t ON t.type = a.type
                   WHERE a.affaire = p.id)
      ) ORDER BY p.created_at), '[]'::jsonb)
      FROM public.plaintes_en_cours p
     WHERE p.country = v_j.pays AND p.city IS NOT DISTINCT FROM coalesce(v_j.ville, 'capitale')
       AND p.data IS NOT NULL AND left(btrim(p.data), 1) = '{'
       AND (p.data::jsonb ->> 'status') IN ('saisie', 'abandon_demande', 'appel')));
END $$;

-- ============================================================================================
-- 6. LA PRESENCE D'UN PNJ INCARNE : SON SIEGE, ET NULLE PART AILLEURS
-- ============================================================================================
-- Un PNJ n'a pas de fiche, donc pas de position : la regle unique de localisation lui rendait
-- `false` et le parquet incarne ne pouvait rien faire. Un titulaire PNJ SIEGE a son poste -- le
-- tribunal de sa ville, celui de la capitale pour un poste national -- et il n'en bouge pas. Une
-- affaire de province reste donc hors de portee de Saad, exactement comme pour un Procureur qui
-- n'aurait pas voyage. La branche ne s'allume que pour une session administrateur portant une
-- incarnation : pour tout joueur, `incarnation_courante()` vaut NULL et `p_acteur = NULL` n'est
-- jamais vrai.
CREATE OR REPLACE FUNCTION public.acteur_present_sur_site(p_acteur text, p_pays text, p_ville text, p_batiment text, p_piece text)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE a record; v_siege text;
BEGIN
  -- FERME PAR DEFAUT. Un site dont on ignore le pays, la ville ou le batiment ne
  -- permet pas d'etablir une presence : on refuse, on ne devine pas.
  IF p_acteur IS NULL OR coalesce(p_pays, '') = ''
     OR coalesce(p_ville, '') = '' OR coalesce(p_batiment, '') = '' THEN
    RETURN false;
  END IF;

  -- LE SIEGE D'UN PNJ TITULAIRE INCARNE.
  IF p_acteur = public.incarnation_courante() THEN
    v_siege := public.incarnation_siege();
    IF v_siege IS NULL THEN RETURN false; END IF;
    RETURN p_pays IS NOT DISTINCT FROM public.incarnation_pays()
       AND p_ville IS NOT DISTINCT FROM v_siege
       AND p_batiment IS NOT DISTINCT FROM public.parquet_site_competent(p_pays, v_siege);
  END IF;

  -- LA POSITION FAISANT AUTORITE, et elle seule. Le navigateur ne transmet ici
  -- aucune localisation : il ne pourrait pas mentir meme s'il essayait.
  SELECT country, current_city, current_building, current_room INTO a
    FROM public.personnages_donnees WHERE name = p_acteur;
  IF NOT FOUND OR a.current_city IS NULL OR a.current_building IS NULL THEN
    RETURN false;
  END IF;

  IF a.country          IS DISTINCT FROM p_pays     THEN RETURN false; END IF;
  IF a.current_city     IS DISTINCT FROM p_ville    THEN RETURN false; END IF;
  IF a.current_building IS DISTINCT FROM p_batiment THEN RETURN false; END IF;

  -- La piece ne compte que si le site en designe une. Sept commerces du jeu
  -- occupent leur batiment entier (voir commerces_types) : y etre, c'est y etre.
  IF coalesce(p_piece, '') <> '' AND a.current_room IS DISTINCT FROM p_piece THEN
    RETURN false;
  END IF;

  RETURN true;
END $function$;

-- ============================================================================================
-- 7. LE DEFAUT D'ARITE DE `parquet_garde`, MESURE ET CORRIGE
-- ============================================================================================
-- Quatre arguments pour une fonction qui en exige cinq : le controle de presence levait 42883 et
-- toutes les actions du parquet etaient cassees. La piece ne compte pas pour un site judiciaire,
-- exactement comme dans `parquet_dossiers` qui, elle, passait bien NULL.
CREATE OR REPLACE FUNCTION public.parquet_garde(p_affaire_id text, p_statuts text[])
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_p record; v_brut text; v_a jsonb; v_ville text; v_pays text; v_site text;
BEGIN
  SELECT * INTO v_p FROM public.parquet_moi();
  IF v_p.nom IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_procureur');
  END IF;

  SELECT p.data, p.city, p.country INTO v_brut, v_ville, v_pays
    FROM public.plaintes_en_cours p WHERE p.id = p_affaire_id;
  IF v_brut IS NULL OR left(btrim(v_brut), 1) <> '{' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'affaire_absente');
  END IF;
  v_a := v_brut::jsonb;

  IF v_pays IS DISTINCT FROM v_p.pays THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_juridiction');
  END IF;
  IF NOT (coalesce(v_a ->> 'status', '') = ANY (p_statuts)) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'statut_incompatible',
                              'statut', v_a ->> 'status', 'attendus', to_jsonb(p_statuts));
  END IF;

  -- LE DELAI S'OPPOSE ICI, et non seulement a minuit. Entre l'echeance et la passe nocturne, le
  -- dossier est perime : la poursuivre serait poursuivre une procedure eteinte.
  IF public.affaire_delai_expire(v_a, v_pays) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delai_de_jugement_expire',
                              'echeance', (v_a ->> 'delai_jugement_jour')::integer);
  END IF;

  v_site := public.parquet_site_competent(v_pays, v_ville);
  IF NOT public.acteur_present_sur_site(v_p.nom, v_pays, v_ville, v_site, NULL) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'presence_requise',
                              'ville', v_ville, 'site', v_site);
  END IF;

  RETURN jsonb_build_object('ok', true, 'procureur', v_p.nom, 'pays', v_pays,
                            'ville', v_ville, 'affaire', v_a);
END $function$;

-- ============================================================================================
-- 8. LE PANNEAU : CE QUE L'ADMINISTRATION VOIT, PAR LES YEUX DES DEUX PNJ
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.admin_tribunal_dossiers()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid; v_pays text := 'republic';
  v_saad text; v_honore text; v_parquet jsonb; v_juge jsonb; v_attente integer;
BEGIN
  v_uid := public.admin_exiger();

  -- LE PARQUET, PAR LES YEUX DE SAAD -- s'il est reellement titulaire.
  v_saad := public.admin_pnj_titulaire(v_pays, 'procureur', NULL);
  IF v_saad IS NOT NULL THEN
    PERFORM set_config('rp.incarnation_pnj', v_saad, true);
    PERFORM set_config('rp.incarnation_pays', v_pays, true);
    PERFORM set_config('rp.incarnation_siege', 'capitale', true);
    v_parquet := public.parquet_dossiers();
    PERFORM set_config('rp.incarnation_pnj', '', true);
    PERFORM set_config('rp.incarnation_pays', '', true);
    PERFORM set_config('rp.incarnation_siege', '', true);
  ELSE
    v_parquet := jsonb_build_object('ok', false, 'raison', 'poste_tenu_par_un_pj');
  END IF;

  -- LE TRIBUNAL, PAR LES YEUX D'HONORE -- juge de la capitale, et de nulle part ailleurs.
  v_honore := public.admin_pnj_titulaire(v_pays, 'juge', 'capitale');
  IF v_honore IS NOT NULL THEN
    PERFORM set_config('rp.incarnation_pnj', v_honore, true);
    PERFORM set_config('rp.incarnation_pays', v_pays, true);
    PERFORM set_config('rp.incarnation_siege', 'capitale', true);
    v_juge := public.juge_dossiers();
    PERFORM set_config('rp.incarnation_pnj', '', true);
    PERFORM set_config('rp.incarnation_pays', '', true);
    PERFORM set_config('rp.incarnation_siege', '', true);
  ELSE
    v_juge := jsonb_build_object('ok', false, 'raison', 'poste_tenu_par_un_pj');
  END IF;

  -- L'INDICATEUR DISCRET : combien de dossiers attendent une decision institutionnelle. Compte,
  -- pas alerte -- et aucune notification nulle part.
  SELECT count(*) INTO v_attente FROM (
    SELECT (d -> 'dossier') ->> 'status' AS st, 'procureur' AS po
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_parquet -> 'dossiers') = 'array'
                                     THEN v_parquet -> 'dossiers' ELSE '[]'::jsonb END) d
    UNION ALL
    SELECT (d -> 'dossier') ->> 'status', 'juge'
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(v_juge -> 'dossiers') = 'array'
                                     THEN v_juge -> 'dossiers' ELSE '[]'::jsonb END) d
  ) x
  WHERE EXISTS (SELECT 1 FROM public.admin_actions_tribunal a
                 WHERE a.poste = x.po AND x.st = ANY (a.statuts));

  RETURN jsonb_build_object(
    'ok', true,
    'pays', v_pays,
    'admin', (SELECT a.libelle FROM public.administrateurs a WHERE a.user_id = v_uid),
    'parquet', jsonb_build_object('pnj', v_saad, 'incarnable', v_saad IS NOT NULL,
                                  'vue', v_parquet),
    'juge', jsonb_build_object('pnj', v_honore, 'incarnable', v_honore IS NOT NULL,
                               'ville', 'capitale', 'vue', v_juge),
    'actions', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                  'poste', a.poste, 'action', a.action, 'libelle', a.libelle,
                  'statuts', to_jsonb(a.statuts)) ORDER BY a.poste, a.ordre), '[]'::jsonb)
                 FROM public.admin_actions_tribunal a),
    'en_attente', v_attente,
    'lu_le', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
END $$;

GRANT EXECUTE ON FUNCTION public.admin_tribunal_dossiers() TO authenticated;

-- ============================================================================================
-- 9. LA PORTE UNIQUE D'INCARNATION
-- ============================================================================================
-- ELLE N'ECRIT RIEN DANS LE JUDICIAIRE. Elle verifie l'autorite, verifie la titularite, pose
-- l'incarnation pour la duree de la transaction, appelle la fonction metier, la depose, et
-- consigne a l'audit prive. C'est ce qui rend l'intervention indiscernable d'un acte du PNJ : il
-- n'existe aucune donnee de provenance a cacher.
CREATE OR REPLACE FUNCTION public.admin_incarner(
  p_poste text, p_action text, p_affaire_id text, p_params jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid; v_lib text; v_pays text := 'republic'; v_ville_poste text;
  v_a record; v_pnj text; v_p jsonb; v_r jsonb;
BEGIN
  v_uid := public.admin_exiger();
  SELECT a.libelle INTO v_lib FROM public.administrateurs a WHERE a.user_id = v_uid;
  v_p := CASE WHEN jsonb_typeof(p_params) = 'object' THEN p_params ELSE '{}'::jsonb END;

  -- LE PERIMETRE EST FERME, ET IL TIENT EN DEUX POSTES.
  IF p_poste = 'procureur' THEN v_ville_poste := NULL;
  ELSIF p_poste = 'juge'   THEN v_ville_poste := 'capitale';
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_hors_perimetre', 'poste', p_poste);
  END IF;

  SELECT * INTO v_a FROM public.admin_actions_tribunal a
   WHERE a.poste = p_poste AND a.action = p_action;
  IF v_a.action IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'action_hors_perimetre',
                              'poste', p_poste, 'action', p_action);
  END IF;

  -- LA TITULARITE EST VERIFIEE MAINTENANT, pas a l'ouverture de l'ecran. Un PJ nomme entre les
  -- deux ferme la porte, y compris si le client appelle directement.
  v_pnj := public.admin_pnj_titulaire(v_pays, p_poste, v_ville_poste);
  IF v_pnj IS NULL THEN
    INSERT INTO public.admin_journal (admin_user_id, admin_libelle, pnj, poste, affaire,
                                      action, parametres, resultat, ok)
    VALUES (v_uid, v_lib, NULL, p_poste, p_affaire_id, p_action, v_p,
            jsonb_build_object('raison', 'poste_tenu_par_un_pj'), false);
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_tenu_par_un_pj', 'poste', p_poste);
  END IF;

  PERFORM set_config('rp.incarnation_pnj', v_pnj, true);
  PERFORM set_config('rp.incarnation_pays', v_pays, true);
  PERFORM set_config('rp.incarnation_siege', coalesce(v_ville_poste, 'capitale'), true);

  -- AUCUN SQL DYNAMIQUE : dix appels nommes, et pas un de plus. Ce sont EXACTEMENT les fonctions
  -- que le titulaire appellerait, avec leurs gardes intactes.
  v_r := CASE
    WHEN p_poste = 'procureur' AND p_action = 'enqueter'
      THEN public.parquet_enqueter(p_affaire_id)
    WHEN p_poste = 'procureur' AND p_action = 'poursuivre'
      THEN public.parquet_poursuivre(p_affaire_id, v_p ->> 'infraction')
    WHEN p_poste = 'procureur' AND p_action = 'non_lieu'
      THEN public.parquet_non_lieu(p_affaire_id, v_p ->> 'motif')
    WHEN p_poste = 'procureur' AND p_action = 'transmettre_juge'
      THEN public.parquet_transmettre_juge(p_affaire_id)
    WHEN p_poste = 'procureur' AND p_action = 'abandonner'
      THEN public.parquet_abandonner(p_affaire_id, v_p ->> 'motif')
    WHEN p_poste = 'procureur' AND p_action = 'appel_ouvrir'
      THEN public.justice_appel_ouvrir(p_affaire_id)
    WHEN p_poste = 'juge' AND p_action = 'relaxer'
      THEN public.justice_relaxer(p_affaire_id, v_p ->> 'infraction')
    WHEN p_poste = 'juge' AND p_action = 'rendre_sentence'
      THEN public.justice_rendre_sentence(p_affaire_id, v_p ->> 'infraction',
             v_p ->> 'genre', (v_p ->> 'jours')::integer, (v_p ->> 'amende')::integer)
    WHEN p_poste = 'juge' AND p_action = 'suite_apres_abandon'
      THEN public.juge_suite_apres_abandon(p_affaire_id, v_p ->> 'decision')
    WHEN p_poste = 'juge' AND p_action = 'juger_appel'
      THEN public.justice_appel_juger(p_affaire_id, v_p ->> 'verdict', v_p ->> 'infraction',
             v_p ->> 'genre', (v_p ->> 'jours')::integer, (v_p ->> 'amende')::integer)
  END;

  PERFORM set_config('rp.incarnation_pnj', '', true);
  PERFORM set_config('rp.incarnation_pays', '', true);
  PERFORM set_config('rp.incarnation_siege', '', true);

  -- L'AUDIT EST PRIVE, ET IL NE CHANGE RIEN A LA REPRESENTATION PUBLIQUE DE L'ACTE.
  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, pnj, poste, affaire,
                                    action, parametres, resultat, ok)
  VALUES (v_uid, v_lib, v_pnj, p_poste, p_affaire_id, p_action, v_p, v_r,
          coalesce((v_r ->> 'ok')::boolean, false));

  RETURN coalesce(v_r, jsonb_build_object('ok', false, 'raison', 'action_sans_effet'));
END $$;

COMMENT ON FUNCTION public.admin_incarner(text, text, text, jsonb) IS
  'Porte unique de l''incarnation administrative. N''ecrit rien dans le judiciaire : elle appelle la fonction metier du titulaire, gardes intactes, et consigne a l''audit prive.';

GRANT EXECUTE ON FUNCTION public.admin_incarner(text, text, text, jsonb) TO authenticated;

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text; v_a record;
BEGIN
  -- P1 : AUCUN DROIT CLIENT SUR LES TROIS TABLES DU SOCLE.
  SELECT count(*) INTO v_n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.oid IN ('public.administrateurs'::regclass, 'public.admin_journal'::regclass,
                   'public.admin_actions_tribunal'::regclass)
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % droit(s) client sur le socle d''administration', v_n; END IF;

  -- P2 : LES TROIS TABLES PORTENT LA RLS, ET AUCUNE POLICY NE LES OUVRE.
  SELECT count(*) INTO v_n FROM pg_class c
   WHERE c.oid IN ('public.administrateurs'::regclass, 'public.admin_journal'::regclass,
                   'public.admin_actions_tribunal'::regclass) AND c.relrowsecurity;
  IF v_n <> 3 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % table(s) du socle sous RLS, 3 attendues', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_policy p
   WHERE p.polrelid IN ('public.administrateurs'::regclass, 'public.admin_journal'::regclass,
                        'public.admin_actions_tribunal'::regclass);
  IF v_n <> 0 THEN RAISE EXCEPTION 'P2 ECHOUEE -- % policy sur le socle d''administration', v_n; END IF;

  -- P3 : L'AUDIT EST EN AJOUT SEUL, par un declencheur qui LEVE. Il bat service_role.
  SELECT count(*) INTO v_n FROM pg_trigger t
   WHERE t.tgrelid = 'public.admin_journal'::regclass
     AND t.tgname = 'trg_admin_journal_append_only' AND NOT t.tgisinternal;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- l''audit prive n''est pas en ajout seul'; END IF;
  SELECT pg_get_triggerdef(t.oid) INTO v_txt FROM pg_trigger t
   WHERE t.tgrelid = 'public.admin_journal'::regclass AND t.tgname = 'trg_admin_journal_append_only';
  IF position('BEFORE' IN v_txt) = 0 OR position('UPDATE' IN v_txt) = 0
     OR position('DELETE' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le verrou de l''audit ne couvre pas les deux operations'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'admin_journal_append_only';
  IF position('RAISE EXCEPTION' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- le verrou de l''audit ne leve pas'; END IF;

  -- P4 : L'AUTORITE A UNE SEULE DEFINITION, et elle lit la base.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'est_administrateur';
  IF position('public.administrateurs' IN v_txt) = 0 OR position('auth.uid()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- l''autorite administrateur ne vient pas de la base'; END IF;

  -- P5 : LES DEUX PORTES SENSIBLES EXIGENT L'AUTORITE, et `admin_exiger` LEVE.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'admin_exiger';
  IF position('RAISE EXCEPTION ''autorite_administrateur_requise''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- admin_exiger ne leve pas'; END IF;
  FOR v_a IN SELECT unnest(ARRAY['admin_tribunal_dossiers', 'admin_incarner']) AS f LOOP
    SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_a.f;
    IF position('public.admin_exiger()' IN v_txt) = 0 THEN
      RAISE EXCEPTION 'P5 ECHOUEE -- % n''exige pas l''autorite administrateur', v_a.f; END IF;
  END LOOP;

  -- P6 : LES TROIS LECTURES D'INCARNATION SONT GARDEES PAR L'AUTORITE. Un reglage qui fuirait ne
  --      servirait a personne d'autre qu'a un administrateur.
  FOR v_a IN SELECT unnest(ARRAY['incarnation_courante', 'incarnation_pays', 'incarnation_siege']) AS f LOOP
    SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_a.f;
    IF position('public.est_administrateur()' IN v_txt) = 0 THEN
      RAISE EXCEPTION 'P6 ECHOUEE -- % n''est pas gardee par l''autorite', v_a.f; END IF;
  END LOOP;

  -- P7 : UN PJ SUR LE POSTE FERME L'INCARNATION. La titularite a une seule definition.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'admin_pnj_titulaire';
  IF position('public.personnages_donnees' IN v_txt) = 0
     OR position('THEN NULL' IN v_txt) = 0
     OR position('public.titulaires_pnj' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- la titularite PNJ ne se ferme pas devant un PJ'; END IF;
  -- Et elle est REVERIFIEE dans les deux resolveurs d'identite, pas seulement a la porte.
  FOR v_a IN SELECT unnest(ARRAY['parquet_moi', 'juge_moi', 'admin_incarner']) AS f LOOP
    SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_a.f;
    IF position('public.admin_pnj_titulaire(' IN v_txt) = 0 THEN
      RAISE EXCEPTION 'P7 ECHOUEE -- % ne reverifie pas la titularite', v_a.f; END IF;
  END LOOP;

  -- P8 : LE PJ GARDE LA PRIORITE. Le chemin normal des resolveurs est teste AVANT l'incarnation.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'parquet_moi';
  IF position('d.user_id = auth.uid()' IN v_txt) = 0
     OR position('d.user_id = auth.uid()' IN v_txt) > position('public.incarnation_courante()' IN v_txt) THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- l''incarnation passe avant le PJ au parquet'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'juge_moi';
  IF position('d.user_id = auth.uid()' IN v_txt) = 0
     OR position('d.user_id = auth.uid()' IN v_txt) > position('public.incarnation_courante()' IN v_txt) THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- l''incarnation passe avant le PJ au tribunal'; END IF;

  -- P9 : LE PERIMETRE EST FERME A DEUX POSTES, et le registre n'en connait pas d'autre.
  SELECT count(DISTINCT poste) INTO v_n FROM public.admin_actions_tribunal;
  IF v_n <> 2 THEN RAISE EXCEPTION 'P9 ECHOUEE -- % poste(s) incarnable(s), 2 attendus', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.admin_actions_tribunal
   WHERE poste NOT IN ('procureur', 'juge');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P9 ECHOUEE -- le registre sort du perimetre'; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'admin_incarner';
  IF position('''poste_hors_perimetre''' IN v_txt) = 0
     OR position('''action_hors_perimetre''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P9 ECHOUEE -- la porte n''a pas de perimetre nomme'; END IF;

  -- P10 : LE MENU NE PEUT PAS MENTIR. Chaque ligne du registre nomme la garde EXACTE de sa
  --       fonction metier, et cette garde est retrouvee dans le corps de la fonction.
  FOR v_a IN SELECT * FROM public.admin_actions_tribunal LOOP
    SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_a.fonction;
    IF v_txt IS NULL THEN
      RAISE EXCEPTION 'P10 ECHOUEE -- la fonction % du registre n''existe pas', v_a.fonction; END IF;
    IF position(v_a.garde_texte IN v_txt) = 0 THEN
      RAISE EXCEPTION 'P10 ECHOUEE -- la garde de % a change : % introuvable',
        v_a.fonction, v_a.garde_texte; END IF;
  END LOOP;

  -- P11 : AUCUN POUVOIR SUPPLEMENTAIRE. La porte n'ecrit RIEN dans le judiciaire : pas une
  --       ecriture sur les dossiers, les actes, les jugements, les detentions ou les fiches.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'admin_incarner';
  IF position('plaintes_en_cours' IN v_txt) > 0
     OR position('dossiers_judiciaires_actes' IN v_txt) > 0
     OR position('public.jugements' IN v_txt) > 0
     OR position('public.detentions' IN v_txt) > 0
     OR position('personnages_donnees' IN v_txt) > 0
     OR position('dossier_acte_consigner' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- la porte administrative touche le judiciaire elle-meme'; END IF;
  SELECT count(*) INTO v_n FROM regexp_matches(v_txt, 'INSERT INTO', 'g');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- % insertion(s) dans la porte, 2 attendues (l''audit, deux fois)', v_n; END IF;
  IF position('INSERT INTO public.admin_journal' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P11 ECHOUEE -- la porte ne consigne pas a l''audit prive'; END IF;

  -- P12 : AUCUNE PROVENANCE ADMINISTRATIVE DANS LE MONDE. Aucune fonction du schema, hors socle
  --       d'administration, ne nomme l'audit ni les reglages d'incarnation.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosrc LIKE '%admin_journal%'
     AND p.proname NOT IN ('admin_incarner', 'admin_se_declarer', 'admin_journal_append_only');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P12 ECHOUEE -- % fonction(s) hors socle nomment l''audit prive', v_n; END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosrc LIKE '%rp.incarnation%'
     AND p.proname NOT IN ('incarnation_courante', 'incarnation_pays', 'incarnation_siege',
                           'admin_incarner', 'admin_tribunal_dossiers');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P12 ECHOUEE -- % fonction(s) lisent l''incarnation hors du socle', v_n; END IF;

  -- P13 : LA DECLARATION DU PREMIER COMPTE EST FERMEE PAR QUATRE CONDITIONS.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'admin_se_declarer';
  IF position('''administration_deja_constituee''' IN v_txt) = 0
     OR position('''compte_sans_identite_reelle''' IN v_txt) = 0
     OR position('''compte_porte_un_personnage''' IN v_txt) = 0
     OR position('u.is_anonymous' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P13 ECHOUEE -- la declaration du premier administrateur n''est pas bornee'; END IF;

  -- P14 : AUCUN SECRET DE DEPLOIEMENT N'EST DEVENU UNE IDENTITE. `CRON_SECRET` n'apparait nulle
  --       part en base, et `est_appel_serveur` n'ouvre pas l'administration.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.prosrc ILIKE '%cron_secret%';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P14 ECHOUEE -- % fonction(s) nomment CRON_SECRET', v_n; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'est_administrateur';
  IF position('est_appel_serveur' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P14 ECHOUEE -- le serveur traverse l''autorite administrateur'; END IF;

  -- P15 : LE DEFAUT D'ARITE EST CORRIGE, et le controle de presence est de nouveau appelable.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'parquet_garde';
  IF position('public.acteur_present_sur_site(v_p.nom, v_pays, v_ville, v_site, NULL)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P15 ECHOUEE -- parquet_garde appelle encore la presence a quatre arguments'; END IF;
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname = 'acteur_present_sur_site') <> 1 THEN
    RAISE EXCEPTION 'P15 ECHOUEE -- la regle de presence a plusieurs signatures'; END IF;

  -- P16 : LE SIEGE D'UN PNJ INCARNE EST BORNE, et la branche n'existe que pour lui.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'acteur_present_sur_site';
  IF position('p_acteur = public.incarnation_courante()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P16 ECHOUEE -- le siege du PNJ incarne n''existe pas'; END IF;
  IF position('public.parquet_site_competent(p_pays, v_siege)' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P16 ECHOUEE -- le siege n''est pas borne au site judiciaire de sa ville'; END IF;

  RAISE NOTICE 'LES 16 PREUVES SONT VERTES.';
END $preuves$;
