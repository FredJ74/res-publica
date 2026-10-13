-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 13 OCTOBRE 2026
--
-- Registre Supabase : version 20261013152848 (UTC), nom
-- `pnj_jeremy_connait_l_etape_de_la_visite`.
-- Le registre passe de 712 a 713 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 8db9e50bff25b871072faa9c2acd7cf3, 7817 caracteres, 1
-- instruction au registre. Relu DEPUIS LE REGISTRE par
-- outils/baseline/extraire-corps-migration.py -- il n'est pas repasse par un clavier -- et
-- empreinte verifiee par outils/baseline/verifier-archives-migrations.py.
--
-- LE GUIDE DU JEU ETAIT LE SEUL PNJ A NE JAMAIS REPONDRE
--
-- Jeremy conduit la quete d'accueil : c'est le premier PNJ qu'une nouvelle joueuse rencontre, et
-- celui a qui elle parle le plus. Son prompt etait ECRIT depuis longtemps, mais construit PAR LE
-- NAVIGATEUR dans un bloc qui n'etait plus envoye nulle part depuis le 29 septembre 2026 -- et
-- son identifiant de profil, `jeremy`, n'existait pas cote serveur. /api/chat repondait 400
-- « Profil inconnu », et la joueuse lisait « Discussion impossible momentanement ».
--
-- CE QUE CETTE PORTE AJOUTE. Le SIXIEME canal de contexte de /api/chat : l'ETAPE de la visite
-- d'accueil du joueur connecte, plus un booleen qui dit si la visite est encore en cours. Un
-- seul PNJ le recoit -- comme la memoire des mandats n'appartient qu'a Huguette Papier et les
-- regards de l'Assemblee qu'a Renee Toitout.
--
-- CE QU'ELLE NE REND PAS : ni nom, ni ville, ni carriere, ni argent, ni inventaire, ni position,
-- ni condamnation. AUCUN PARAMETRE non plus : l'identite vient de `mon_personnage()`, donc du
-- jeton, et un joueur ne peut lire que SA propre visite. STABLE, donc incapable d'ecrire.
--
-- PREUVES STRUCTURELLES -- 8.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- JEREMY NE SAVAIT PAS OU EN ETAIT LA VISITE QU'IL CONDUIT
-- 13 octobre 2026, chantier du raccordement des PNJ a DeepSeek
--
-- CE QUI N'ALLAIT PAS. Jeremy est le guide de la quete d'accueil : c'est le premier PNJ qu'une
-- nouvelle joueuse rencontre, et celui a qui elle parle le plus. Son prompt etait ECRIT depuis
-- longtemps -- vouvoiement systematique, maladresse serviable, interdiction d'inventer un lieu,
-- renvoi vers le bouton PLAN, et surtout l'ETAPE EN COURS de la visite -- mais il etait construit
-- PAR LE NAVIGATEUR, dans un bloc qui n'est plus envoye nulle part depuis le 29 septembre 2026.
-- Et son identifiant de profil, `jeremy`, n'a jamais existe cote serveur : /api/chat repondait
-- 400 « Profil inconnu », et la joueuse lisait « Discussion impossible momentanement ». Le guide
-- du jeu etait donc le seul PNJ a ne jamais repondre a une question.
--
-- CE QUE CETTE PORTE FAIT, ET RIEN DE PLUS. Elle rend au serveur de dialogue l'ETAPE de la visite
-- d'accueil du joueur connecte, et un booleen qui dit si la visite est encore en cours. C'est le
-- SIXIEME canal de contexte de /api/chat, et il est de la sixieme nature :
--   . contexte public       -> un fait du monde (qui est en face) ;
--   . memoire sociale       -> une relation (vous vous connaissez) ;
--   . memoire pedagogique   -> un historique d'explications ;
--   . memoire des mandats   -> une histoire nationale ;
--   . regards de l'Assemblee-> une observation locale ;
--   . etape de la visite    -> OU EN EST CE JOUEUR-CI dans son accueil.
--
-- UN SEUL PNJ LE RECOIT, exactement comme la memoire des mandats n'appartient qu'a Huguette
-- Papier et les regards de l'Assemblee qu'a Renee Toitout : pour les 213 autres profils, l'appel
-- n'est pas emis du tout.
--
-- CE QU'ELLE NE REND PAS, ET C'EST LA MOITIE DU TRAVAIL. Elle ne rend ni le nom, ni la ville, ni
-- la carriere, ni l'argent, ni l'inventaire, ni la position, ni les condamnations, ni aucune
-- autre colonne de la fiche. Elle ne prend AUCUN parametre : ni nom, ni pays. L'identite vient de
-- `mon_personnage()`, donc du jeton du joueur, et un joueur ne peut lire que SA propre visite.
-- La formulation de l'objectif, elle, n'est pas ici : elle vit dans api/_pnj-referents.js, miroir
-- surveille de QUETE_ACCUEIL_OBJECTIFS (plateau-quete-accueil.js). Le serveur dit OU ON EN EST ;
-- il n'invente pas la consigne.
--
-- PREUVES STRUCTURELLES -- 8.

CREATE OR REPLACE FUNCTION public.quete_accueil_contexte()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE v_moi text; v_q jsonb; v_etape text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT quete_accueil INTO v_q FROM public.personnages_donnees WHERE name = v_moi;
  IF v_q IS NULL OR jsonb_typeof(v_q) <> 'object' THEN
    RETURN jsonb_build_object('ok', true, 'etape', NULL, 'visite_en_cours', false);
  END IF;
  v_etape := nullif(btrim(coalesce(v_q ->> 'etape', '')), '');

  -- LES TROIS ETATS TERMINAUX SONT NOMMES, PAS DEVINES. `carriere_terminee`,
  -- `quete_terminee_sans_aide` et `refusee` sont les trois valeurs que le client ecrit quand la
  -- visite est finie ou refusee ; toute autre valeur est une visite en cours. Nommer l'inverse --
  -- la liste des etapes vivantes -- aurait fait mentir cette porte a chaque etape ajoutee.
  RETURN jsonb_build_object(
    'ok', true,
    'etape', v_etape,
    'visite_en_cours',
      v_etape IS NOT NULL
      AND v_etape NOT IN ('carriere_terminee', 'quete_terminee_sans_aide', 'refusee'));
END;
$fn$;

REVOKE ALL ON FUNCTION public.quete_accueil_contexte() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.quete_accueil_contexte() TO authenticated;

DO $$
DECLARE v_n integer; v_src text;
BEGIN
  -- P1 -- LA PORTE EXISTE, SANS AUCUN PARAMETRE. Zero argument, c'est ce qui rend impossible de
  -- demander la visite de quelqu'un d'autre : il n'y a pas de champ pour le nommer.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'quete_accueil_contexte' AND p.pronargs = 0;
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 ECHOUEE -- % signature(s) sans parametre', v_n; END IF;

  -- P2 -- SECURITY DEFINER ET search_path GELE.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'quete_accueil_contexte'
     AND p.prosecdef AND p.proconfig @> ARRAY['search_path=public, pg_temp'];
  IF v_n <> 1 THEN RAISE EXCEPTION 'P2 ECHOUEE -- definer ou search_path non gele'; END IF;

  -- P3 -- ELLE NE PEUT RIEN ECRIRE : declaree STABLE, PostgreSQL refuserait toute ecriture.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'quete_accueil_contexte' AND p.provolatile = 's';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P3 ECHOUEE -- la porte n''est pas STABLE'; END IF;

  -- P4 -- LE CLIENT PEUT L'APPELER, ANON NON.
  SELECT count(*) INTO v_n FROM information_schema.routine_privileges
   WHERE routine_schema = 'public' AND routine_name = 'quete_accueil_contexte'
     AND grantee = 'authenticated';
  IF v_n < 1 THEN RAISE EXCEPTION 'P4 ECHOUEE -- authenticated ne peut pas appeler la porte'; END IF;
  SELECT count(*) INTO v_n FROM information_schema.routine_privileges
   WHERE routine_schema = 'public' AND routine_name = 'quete_accueil_contexte'
     AND grantee IN ('anon', 'PUBLIC');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 ECHOUEE -- % droit(s) a anon ou PUBLIC', v_n; END IF;

  -- P5 -- L'IDENTITE VIENT DU JETON. `mon_personnage()` est nomme, et aucune autre resolution
  -- d'identite ne l'est.
  SELECT public.sans_commentaires(p.prosrc) INTO v_src
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'quete_accueil_contexte';
  IF v_src !~ 'mon_personnage\(\)' THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la porte ne resout pas l''identite par mon_personnage()'; END IF;

  -- P6 -- ELLE NE LIT QU'UNE COLONNE, ET UNE SEULE TABLE. La mesure est une ABSENCE : aucune
  -- autre colonne sensible de la fiche n'est nommee dans son corps.
  IF v_src !~ 'SELECT quete_accueil INTO' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la lecture de quete_accueil a change de forme'; END IF;
  IF v_src ~ '(arg|liquide|banque|inventory|recherche|historique_crimes|contacts|domicile|poste|current_city|current_building|stats|career|archetype)\b' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- la porte nomme une donnee privee de la fiche'; END IF;
  SELECT count(*) INTO v_n FROM regexp_matches(v_src, 'FROM public\.([a-z_]+)', 'g') m
   WHERE m[1] <> 'personnages_donnees';
  IF v_n <> 0 THEN RAISE EXCEPTION 'P6 ECHOUEE -- % autre(s) table(s) lue(s)', v_n; END IF;

  -- P7 -- LES TROIS ETATS TERMINAUX SONT CEUX DU CLIENT, nommement. S'ils changent de nom d'un
  -- cote sans l'autre, Jeremy croira guider une visite finie -- ou se taira pendant la visite.
  IF v_src !~ 'carriere_terminee' OR v_src !~ 'quete_terminee_sans_aide' OR v_src !~ 'refusee' THEN
    RAISE EXCEPTION 'P7 ECHOUEE -- un etat terminal de la visite n''est plus nomme'; END IF;

  -- P8 -- LA TABLE RESTE FERMEE AU CLIENT. Cette porte est la SEULE lecture possible de
  -- `quete_accueil` : `personnages_donnees` n'accorde aucun droit a anon ni a authenticated.
  SELECT count(*) INTO v_n FROM information_schema.table_privileges
   WHERE table_schema = 'public' AND table_name = 'personnages_donnees'
     AND grantee IN ('anon', 'authenticated', 'PUBLIC');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P8 ECHOUEE -- % droit(s) client sur personnages_donnees', v_n; END IF;

  RAISE NOTICE 'LES 8 PREUVES SONT VERTES.';
END $$;