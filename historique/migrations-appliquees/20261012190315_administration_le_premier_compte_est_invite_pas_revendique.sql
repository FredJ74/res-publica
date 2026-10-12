-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 12 OCTOBRE 2026
--
-- Registre Supabase : version 20261012190315 (UTC), nom
-- `administration_le_premier_compte_est_invite_pas_revendique`.
-- Le registre passe de 692 a 693 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 a0adfe1869ac2250cb7781b69b18f151, 13659 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- LE PREMIER COMPTE ADMINISTRATEUR EST INVITE, IL NE SE REVENDIQUE PLUS
--
-- CE QU'ELLE FERME, ET C'EST LE §A.2 DU CAHIER DES CHARGES. `admin_se_declarer` s'ouvrait TANT
-- QUE la table des administrateurs etait vide : entre le deploiement et le provisionnement, tout
-- compte reel et confirme pouvait prendre la place. La securite dependait donc de la VITESSE de
-- Fred, ce que la consigne refuse explicitement. La condition « la table est vide » a ete
-- RETIREE.
--
-- CE QUI LA REMPLACE : UNE INVITATION NOMMEE, POSEE PAR CETTE MIGRATION.
-- `administrateurs_invitations` porte une adresse en cle primaire, minuscule par contrainte, et
-- une seule ligne est semee. La porte exige desormais, dans cet ordre : une session ; une ligne
-- `auth.users` non anonyme (les comptes joueurs le sont tous -- aucun ne franchit cette ligne) ;
-- une adresse non vide ; `email_confirmed_at IS NOT NULL` -- la preuve que l'appelant tient la
-- boite ; aucune fiche de personnage ; et une invitation NON CONSOMMEE a son adresse. La
-- consommation est un compare-and-swap : deux onglets simultanes ne la prennent pas tous les deux.
--
-- AUCUN SECRET EN CLAIR, ET AUCUN SQL DEMANDE A FRED. L'adresse invitee n'est pas un secret : la
-- connaitre ne donne rien, il faut tenir la boite ET l'avoir confirmee chez Supabase Auth. Le
-- registre est REVOQUE a anon et authenticated, et sous RLS sans policy : personne ne s'y ajoute
-- une ligne, et personne ne le lit.
--
-- CE QUE `admin_moi()` N'APPREND PLUS A PERSONNE. `bootstrap_ouvert` disait au monde entier si
-- l'administration etait constituee. Il est remplace par `invitation_ouverte`, vrai uniquement
-- pour l'appelant qui a LUI-MEME une invitation en attente sur une adresse confirmee. Un compte
-- quelconque lit `false` et ne distingue plus une administration vide d'une administration pleine.
--
-- PREUVES STRUCTURELLES -- 9.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- LE PREMIER COMPTE ADMINISTRATEUR EST INVITE, IL NE SE REVENDIQUE PLUS
-- 12 octobre 2026 -- fermeture du §A.2
--
-- CE QUI N'ALLAIT PAS, ET C'ETAIT UNE SECURITE QUI DEPENDAIT D'UNE COURSE. `admin_se_declarer`
-- s'ouvrait a tout compte authentifie NON ANONYME, sans personnage, tant que la table
-- `administrateurs` etait vide. Les comptes joueurs etant anonymes, aucun d'eux ne pouvait
-- franchir cette ligne -- mais n'importe quel compte courriel cree par n'importe qui, lui,
-- pouvait. La protection reelle etait donc la VITESSE a laquelle Fred provisionnait son compte,
-- et c'est exactement ce qu'une securite ne doit jamais etre. Pire : `admin_moi()` annoncait
-- `bootstrap_ouvert: true` a TOUT compte authentifie, ce qui publiait l'existence de la fenetre.
--
-- CE QUI LA REMPLACE : UNE INVITATION NOMMEE, ET ELLE EST POSEE PAR MIGRATION. Un registre
-- `administrateurs_invitations` porte les adresses autorisees a se declarer. Se declarer n'est
-- plus une revendication -- c'est la CONSOMMATION d'une invitation, et une invitation ne
-- s'invente pas depuis un navigateur : la table n'a aucun droit client, aucune policy, et aucune
-- porte appelable par un client n'y ecrit. Un compte courriel arbitraire est donc refusu
-- `aucune_invitation`, que la table des administrateurs soit vide ou non.
--
-- UNE ADRESSE N'EST PAS UN SECRET, et c'est pour cela que cette solution ne met rien en clair
-- dans Git qui ne doive y etre. Le mot de passe, lui, n'existe nulle part dans le depot : il est
-- pose par Fred dans la console Supabase, et le serveur n'en voit jamais que le condensat de
-- GoTrue. Ce qui est seme ici, c'est la seule chose qui identifie le destinataire.
--
-- ET L'ADRESSE DOIT ETRE CONFIRMEE. `email_confirmed_at IS NOT NULL` : seul celui qui tient la
-- boite peut franchir la porte. Quelqu'un qui creerait un compte en se declarant cette adresse
-- sans la posseder resterait non confirme, donc refuse. C'est ce qui ferme la fenetre
-- STRUCTURELLEMENT, et non plus par rapidite.
--
-- LA CONSOMMATION EST UN COMPARE-AND-SWAP. Deux onglets qui cliquent en meme temps : un seul
-- ecrit, l'autre obtient `invitation_deja_consommee`. Et l'invitation consommee reste en base
-- avec son horodatage et le compte qui l'a prise -- c'est de l'audit, pas du menage.
--
-- `admin_moi()` NE PUBLIE PLUS RIEN. `invitation_ouverte` ne dit plus si LA fenetre est ouverte
-- mais si l'appelant a UNE invitation a son nom. Un compte sans invitation lit `false`, et
-- n'apprend donc rien de l'etat de l'administration.
--
-- LA TABLE DES ADMINISTRATEURS PEUT DESORMAIS NE PLUS ETRE VIDE : la condition a disparu, parce
-- que l'invitation est une garde plus forte et qu'elle est extensible. Inviter un second
-- administrateur un jour sera une ligne de registre, posee par migration -- jamais par un
-- navigateur.
--
-- PREUVES STRUCTURELLES -- 9.

-- ============================================================================================
-- 1. LE REGISTRE DES INVITATIONS
-- ============================================================================================
CREATE TABLE IF NOT EXISTS public.administrateurs_invitations (
  email         text        NOT NULL,
  note          text,
  cree_le       timestamptz NOT NULL DEFAULT now(),
  consommee_le  timestamptz,
  consommee_par uuid,
  CONSTRAINT administrateurs_invitations_pk PRIMARY KEY (email),
  -- Une adresse normalisee : GoTrue stocke les adresses en minuscules, et une invitation qui ne
  -- correspondrait pas a la casse pres serait une invitation morte.
  CONSTRAINT administrateurs_invitations_minuscules CHECK (email = lower(email)),
  -- Consommee, c'est consommee PAR quelqu'un : les deux colonnes vont ensemble ou aucune.
  CONSTRAINT administrateurs_invitations_consommation CHECK (
    (consommee_le IS NULL AND consommee_par IS NULL)
    OR (consommee_le IS NOT NULL AND consommee_par IS NOT NULL))
);
-- UNE TABLE NEUVE NAIT OUVERTE AUX ROLES CLIENTS (defaut de la plateforme). On referme.
REVOKE ALL ON TABLE public.administrateurs_invitations FROM anon, authenticated;
ALTER TABLE public.administrateurs_invitations ENABLE ROW LEVEL SECURITY;

INSERT INTO public.administrateurs_invitations (email, note) VALUES
  ('fredjasseron@yahoo.fr',
   'Invitation initiale, posee par migration le 12 octobre 2026. L''adresse identifie le destinataire ; elle n''est pas un secret et n''ouvre rien seule. Il reste a creer l''utilisateur courriel/mot de passe correspondant dans la console Supabase, avec confirmation, puis a se connecter au panneau et a consommer l''invitation.')
ON CONFLICT (email) DO NOTHING;

-- ============================================================================================
-- 2. LA DECLARATION DEVIENT UNE CONSOMMATION D'INVITATION
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.admin_se_declarer(p_libelle text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_uid uuid; v_u record; v_email text; v_n integer; v_lib text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_session');
  END IF;
  v_lib := coalesce(nullif(btrim(coalesce(p_libelle, '')), ''), 'Administration');

  -- UNE IDENTITE REELLE ET CONFIRMEE, PAS UN ANONYME. Les comptes joueurs sont anonymes
  -- (chantier B) : aucun d'eux ne peut franchir cette ligne. Et la confirmation est ce qui
  -- prouve que l'appelant tient la boite de l'adresse invitee.
  SELECT u.email, u.is_anonymous, u.email_confirmed_at INTO v_u
    FROM auth.users u WHERE u.id = v_uid;
  IF NOT FOUND OR coalesce(v_u.is_anonymous, false) IS TRUE
     OR coalesce(btrim(coalesce(v_u.email, '')), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_sans_identite_reelle');
  END IF;
  IF v_u.email_confirmed_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'adresse_non_confirmee');
  END IF;
  v_email := lower(btrim(v_u.email));

  -- « CE N'EST PAS LE COMPTE JOUEUR. » Verifie, pas suppose.
  IF EXISTS (SELECT 1 FROM public.personnages_donnees d WHERE d.user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_porte_un_personnage');
  END IF;

  -- L'INVITATION EST LA SEULE PORTE, et elle se consomme par COMPARE-AND-SWAP : deux onglets
  -- simultanes ne peuvent pas la prendre tous les deux.
  IF NOT EXISTS (SELECT 1 FROM public.administrateurs_invitations i WHERE i.email = v_email) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_invitation');
  END IF;
  UPDATE public.administrateurs_invitations
     SET consommee_le = now(), consommee_par = v_uid
   WHERE email = v_email AND consommee_le IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'invitation_deja_consommee');
  END IF;

  INSERT INTO public.administrateurs (user_id, libelle)
  VALUES (v_uid, v_lib)
  ON CONFLICT (user_id) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'administrateur_deja_inscrit');
  END IF;

  INSERT INTO public.admin_journal (admin_user_id, admin_libelle, action, ok, resultat)
  VALUES (v_uid, v_lib, 'declaration_premier_administrateur', true,
          jsonb_build_object('email', v_email, 'invitation', v_email));
  RETURN jsonb_build_object('ok', true, 'administrateur', true);
END $$;

-- ============================================================================================
-- 3. `admin_moi()` NE PUBLIE PLUS L'ETAT DE L'ADMINISTRATION
-- ============================================================================================
CREATE OR REPLACE FUNCTION public.admin_moi()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT jsonb_build_object(
    'ok', true,
    'administrateur', public.est_administrateur(),
    'libelle', (SELECT a.libelle FROM public.administrateurs a
                 WHERE a.user_id = auth.uid() AND a.actif),
    -- L'APPELANT N'APPREND RIEN SUR LES AUTRES. Vrai seulement s'il a LUI-MEME une invitation
    -- non consommee, sur une adresse confirmee. Un compte sans invitation lit `false` et ne
    -- distingue donc pas une administration constituee d'une administration vide.
    'invitation_ouverte', EXISTS (
       SELECT 1 FROM auth.users u
         JOIN public.administrateurs_invitations i ON i.email = lower(btrim(u.email))
        WHERE u.id = auth.uid()
          AND coalesce(u.is_anonymous, false) IS FALSE
          AND u.email_confirmed_at IS NOT NULL
          AND i.consommee_le IS NULL));
$$;
COMMENT ON FUNCTION public.admin_moi() IS
  'Ce que le panneau a le droit de savoir : suis-je administrateur, et ai-je MOI-MEME une invitation a consommer. Ne publie jamais l''etat de l''administration a un compte qui n''est pas concerne.';

-- ============================================================================================
-- PREUVES
-- ============================================================================================
DO $preuves$
DECLARE v_n integer; v_txt text;
BEGIN
  -- P1 : AUCUN DROIT CLIENT SUR LE REGISTRE DES INVITATIONS, et la RLS sans policy.
  SELECT count(*) INTO v_n FROM pg_class c, aclexplode(c.relacl) a
   WHERE c.oid = 'public.administrateurs_invitations'::regclass
     AND (SELECT rolname FROM pg_roles WHERE oid = a.grantee) IN ('anon', 'authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % droit(s) client sur les invitations', v_n; END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.administrateurs_invitations'::regclass) THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- les invitations ne sont pas sous RLS'; END IF;
  SELECT count(*) INTO v_n FROM pg_policy
   WHERE polrelid = 'public.administrateurs_invitations'::regclass;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % policy sur les invitations', v_n; END IF;

  -- P2 : AUCUNE PORTE APPELABLE PAR UN CLIENT N'ECRIT DANS LE REGISTRE. Seule la migration le
  --      fait. Une invitation ne peut donc pas naitre d'un navigateur.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prosrc ~ '(INSERT INTO|UPDATE)\s+public\.administrateurs_invitations'
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND p.proname <> 'admin_se_declarer';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- % porte(s) cliente(s) ecrivent dans les invitations', v_n; END IF;
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'admin_se_declarer';
  IF position('INSERT INTO public.administrateurs_invitations' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- la declaration cree sa propre invitation'; END IF;

  -- P3 : LA CONDITION « TABLE VIDE » A DISPARU. Ce n'etait pas une garde : c'etait une course.
  IF position('administration_deja_constituee' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la declaration garde encore sur la vacuite de la table'; END IF;
  IF position('EXISTS (SELECT 1 FROM public.administrateurs)' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P3 ECHOUEE -- la fenetre de revendication est encore ouverte'; END IF;

  -- P4 : L'INVITATION EST LA PORTE, et son absence est un refus NOMME.
  IF position('''aucune_invitation''' IN v_txt) = 0
     OR position('public.administrateurs_invitations i WHERE i.email = v_email' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P4 ECHOUEE -- la declaration ne repose pas sur une invitation'; END IF;

  -- P5 : ELLE SE CONSOMME EN COMPARE-AND-SWAP.
  IF position('WHERE email = v_email AND consommee_le IS NULL' IN v_txt) = 0
     OR position('''invitation_deja_consommee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la consommation de l''invitation n''est pas atomique'; END IF;

  -- P6 : L'ADRESSE DOIT ETRE CONFIRMEE. C'est ce qui ferme la fenetre structurellement.
  IF position('email_confirmed_at IS NULL' IN v_txt) = 0
     OR position('''adresse_non_confirmee''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- une adresse non confirmee peut se declarer'; END IF;

  -- P7 : LES DEUX AUTRES GARDES TIENNENT -- ni anonyme, ni porteur d'un personnage.
  IF position('u.is_anonymous' IN v_txt) = 0
     OR position('''compte_porte_un_personnage''' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- la separation d''avec le compte joueur a disparu'; END IF;

  -- P8 : `admin_moi` NE PUBLIE PLUS L'ETAT GLOBAL. La cle a change de sens ET de nom, et la
  --      nouvelle est liee a l'appelant.
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'admin_moi';
  IF position('bootstrap_ouvert' IN v_txt) > 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- admin_moi publie encore l''etat de l''administration'; END IF;
  IF position('invitation_ouverte' IN v_txt) = 0 OR position('u.id = auth.uid()' IN v_txt) = 0 THEN
    RAISE EXCEPTION 'P8 ECHOUEE -- l''invitation annoncee n''est pas celle de l''appelant'; END IF;

  -- P9 : UNE INVITATION EXISTE, NON CONSOMMEE, EN MINUSCULES. Sans elle le socle serait
  --      inaccessible a tout le monde -- ce qui est sur, mais pas ce qu'on veut.
  SELECT count(*) INTO v_n FROM public.administrateurs_invitations
   WHERE consommee_le IS NULL AND email = lower(email);
  IF v_n < 1 THEN RAISE EXCEPTION 'P9 ECHOUEE -- aucune invitation ouverte'; END IF;

  RAISE NOTICE 'LES 9 PREUVES SONT VERTES.';
END $preuves$;
