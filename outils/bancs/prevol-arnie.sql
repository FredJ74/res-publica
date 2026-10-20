-- AUDIT UNIQUEMENT. Canal technique autorise avec lecture de auth.users.
-- Aucun appel de securisation, rattachement, migration, ecriture ou extraction de jeton.
BEGIN;
SET TRANSACTION READ ONLY;
DO $lecture$
DECLARE nombre integer; proprietaire uuid;
BEGIN
 SELECT count(*) INTO nombre FROM public.personnages_donnees WHERE name='Arnie';
 IF nombre<>1 THEN RAISE EXCEPTION 'Arnie_non_identifie_sans_ambiguite: nombre=%',nombre; END IF;
 SELECT user_id INTO proprietaire FROM public.personnages_donnees WHERE name='Arnie';
 IF proprietaire IS NULL THEN RAISE EXCEPTION 'Arnie_sans_UID_ne_pas_rattacher_automatiquement'; END IF;
 IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=proprietaire) THEN RAISE EXCEPTION 'compte_Arnie_absent_ne_pas_recreer'; END IF;
END $lecture$;
SELECT p.id personnage_id,p.name personnage,p.user_id,u.id auth_uid,
 u.is_anonymous compte_anonyme,
 (nullif(u.email,'') IS NOT NULL) adresse_presente,
 (u.email_confirmed_at IS NOT NULL) adresse_confirmee,
 encode(sha256(convert_to(lower(btrim(coalesce(u.email,''))),'UTF8')),'hex') adresse_sha256,
 (nullif(u.new_email,'') IS NOT NULL) adresse_en_attente,
 (nullif(u.encrypted_password,'') IS NOT NULL) mot_de_passe_present,
 (SELECT coalesce(jsonb_agg(DISTINCT i.provider),'[]') FROM auth.identities i WHERE i.user_id=u.id) fournisseurs,
 p.country,p.current_city,p.current_building,p.current_room,
 md5((to_jsonb(p)-ARRAY['current_city','current_building','current_room','updated_at'])::text) empreinte_fiche_protegee,
 now() verifie_le
FROM public.personnages_donnees p JOIN auth.users u ON u.id=p.user_id WHERE p.name='Arnie';
-- Tous les personnages du MEME UID : compter, ne jamais choisir un membre de la famille.
SELECT count(*) nombre_personnages_du_compte FROM public.personnages_donnees
WHERE user_id=(SELECT user_id FROM public.personnages_donnees WHERE name='Arnie');
-- Inspecter les vrais effets des fonctions de navigation, lecture et sauvegarde.
-- Existence ou nom ne prouve jamais l'absence d'effet de gameplay.
SELECT p.proname,pg_get_function_identity_arguments(p.oid) signature,
 pg_get_userbyid(p.proowner) proprietaire,p.prosecdef,p.provolatile,
 p.proconfig,md5(p.prosrc) empreinte,pg_get_functiondef(p.oid) definition,
 has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute
FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname IN
 ('mon_personnage','rattacher_personnage','personnages_vue_modifier','personnages_lier_proprietaire',
  'rue_position_lire','rue_position_enregistrer','rue_sortie_batiment_lire','inventaire_reception_etat','deplacement_enregistrer')
ORDER BY p.proname,signature;
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) definition
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
WHERE c.relnamespace='public'::regnamespace AND c.relname IN('personnages','personnages_donnees','presences') AND NOT t.tgisinternal;
SELECT tablename,policyname,roles,cmd,qual,with_check FROM pg_policies
WHERE schemaname='public' AND tablename IN('personnages_donnees','presences');
-- Avant toute eventuelle securisation, inspecter aussi les declencheurs auth :
-- aucun changement d'identite ou de patrimoine ne doit leur etre attribue par hypothese.
SELECT c.relname,t.tgname,pg_get_triggerdef(t.oid) definition,
 pg_get_functiondef(t.tgfoid) fonction_declencheur
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
WHERE c.relnamespace='auth'::regnamespace AND c.relname IN('users','identities') AND NOT t.tgisinternal;
ROLLBACK;
