-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 11 OCTOBRE 2026
--
-- Registre Supabase : version 20261011161309 (UTC), nom
-- `partis_politiques_autorite_de_l_appartenance`.
-- Le registre passe de 657 a 658 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 35fe92f5f53e870f18617b38c7f51829, 17199 caracteres, 1
-- instruction au registre. Relu depuis le registre, empreinte verifiee par
-- outils/baseline/verifier-archives-migrations.py.
--
-- ON N'ENTRE PAS DANS UN PARTI SANS QUE SON CHEF L'AIT VOULU
--
-- CE QUE LA DEUXIEME PASSE AVAIT TROUVE SANS LE CORRIGER : la solidarite parlementaire relit bien
-- le parti au serveur, mais `organisations` est un blob ouvert a l'ecriture de TOUT joueur
-- identifie, sans aucun controle de propriete. Un depute pouvait s'inscrire dans le parti d'un
-- depute sanctionne, devenir « protestataire qualifie », et contribuer a suspendre la seance --
-- voire, au deuxieme episode, a remettre la presidence en jeu.
-- POURQUOI PAS UNE FERMETURE DE LA POLICY : le blob entier est ecrit depuis le navigateur, depuis
-- six endroits du jeu, et la table melange des responsabilites tres differentes -- creation,
-- demandes, invitations, grades, elections internes, caisse, influence, greve generale. Deux
-- organisations sont meme creees avec un PNJ pour fondateur, depuis le navigateur d'un joueur.
-- UN GARDE-FOU SUR LA VERITE, PAS SUR LA PORTE. Un declencheur verifie, pour les organisations
-- POLITIQUES et pour les seules ecritures CLIENTES, que la composition ne change que de facons
-- legitimes : le chef decide ; un joueur ne s'ajoute que s'il a ete INVITE -- et l'invitation est
-- elle aussi gardee ; il se retire quand il veut ; un membre peut inscrire un PNJ recrute mais
-- jamais un nom de joueur ; la direction ne change que par le chef, ou par une election interne
-- REELLEMENT en cours et seulement vers un membre deja present.
-- DETTE CONSIGNEE : les organisations NON politiques restent forgeables de la meme maniere. Aucune
-- regle institutionnelle ne depend aujourd'hui de leur composition -- c'est ce qui rend cette
-- dette tenable --, et le jour ou l'une en dependra, il faudra l'etendre.
-- =============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- =================================================================================================
-- ON N'ENTRE PAS DANS UN PARTI SANS QUE SON CHEF L'AIT VOULU (11 octobre 2026)
-- =================================================================================================
-- CE QUE LA DEUXIEME PASSE AVAIT TROUVE SANS LE CORRIGER. La solidarite parlementaire relit bien le
-- parti AU SERVEUR -- `assemblee_parti_de` --, mais la table `organisations` est un blob ouvert a
-- l'ecriture de TOUT joueur identifie : policy `organisations_maj_acteur`, UPDATE USING
-- acteur_identifie(), sans aucun controle de propriete. Un depute pouvait donc s'inscrire dans le
-- parti d'un depute sanctionne, devenir « protestataire qualifie », et contribuer a suspendre la
-- seance -- voire, au deuxieme episode, a remettre la presidence en jeu.
--
-- POURQUOI PAS UNE FERMETURE DE LA POLICY. Parce que `sbSaveOrganisation` ecrit le blob ENTIER
-- depuis le navigateur, depuis six endroits du jeu, et que la table melange des responsabilites
-- tres differentes : la creation d'une organisation, les demandes d'adhesion, les invitations, les
-- grades, les elections internes, la caisse, l'influence, le statut de greve generale -- et, pour
-- les syndicats, une resolution d'election qui tourne dans le navigateur de N'IMPORTE QUEL joueur.
-- Fermer la porte aurait casse tout cela d'un coup.
--
-- CE QUI EST FAIT A LA PLACE : UN GARDE-FOU SUR LA VERITE, PAS SUR LA PORTE. Un declencheur
-- verifie, pour les organisations POLITIQUES et pour les seules ecritures CLIENTES, que la
-- composition du parti ne change que de facons legitimes :
--   . LE CHEF fait ce qu'il veut de son parti -- accepter, exclure, changer les grades ;
--   . UN JOUEUR ne s'ajoute lui-meme QUE si le chef l'avait INVITE, et l'invitation est elle aussi
--     gardee : personne d'autre que le chef ne peut en poser une ;
--   . UN JOUEUR se retire lui-meme quand il veut -- on ne retient personne dans un parti ;
--   . UN MEMBRE peut inscrire un PNJ qu'il a recrute, mais JAMAIS un nom de joueur ;
--   . LA DIRECTION ne change de main que par le chef, ou par une election interne REELLEMENT en
--     cours, et seulement vers quelqu'un qui etait DEJA membre -- sinon on se couronnerait chef
--     d'un parti dont on n'est pas membre, puis on s'y ajouterait.
--
-- L'ATTAQUE EST DONC FERMEE A LA SOURCE, et pas seulement du cote de l'Assemblee : toute mecanique
-- qui depend de l'appartenance a un parti -- la solidarite parlementaire, le decompte d'adherents,
-- les bonus -- lit desormais une composition que le client ne peut plus forger.
--
-- DETTE CONSIGNEE, ET ELLE EST REELLE : les organisations NON politiques -- syndicats, loges,
-- clubs, supporters -- restent forgeables de la meme maniere. Elles ne sont pas protegees ici
-- parce que leurs flux n'ont pas ete audites un par un, et qu'une fermeture aveugle aurait casse
-- des fonctions legitimes (deux d'entre elles sont creees avec un PNJ pour fondateur, depuis le
-- navigateur d'un joueur ; les elections internes des syndicats se resolvent dans le navigateur de
-- n'importe qui). AUCUNE REGLE INSTITUTIONNELLE NE DEPEND AUJOURD'HUI DE LEUR COMPOSITION -- c'est
-- ce qui rend cette dette tenable --, et le jour ou l'une en dependra, il faudra l'etendre.
-- =================================================================================================

CREATE OR REPLACE FUNCTION public.organisations_politique_autorite()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi        text;
  v_av         jsonb;   -- le blob AVANT (NULL a l'insertion)
  v_ap         jsonb;   -- le blob APRES
  v_politique  boolean;
  v_chef_avant text;
  v_est_chef   boolean;
  v_m          text;
  v_election   boolean;
BEGIN
  -- LE SERVEUR N'EST PAS CONCERNE. Les crons et les RPC reservees a service_role -- la cotisation,
  -- le contact d'organisation, l'observation d'un agent -- ecrivent legitimement, et ce garde-fou
  -- ne protege pas la base d'elle-meme.
  IF public.est_appel_serveur() THEN
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  v_av := CASE WHEN TG_OP = 'INSERT' OR OLD.data IS NULL OR NOT (OLD.data IS JSON OBJECT)
               THEN NULL ELSE OLD.data::jsonb END;
  v_ap := CASE WHEN TG_OP = 'DELETE' OR NEW.data IS NULL OR NOT (NEW.data IS JSON OBJECT)
               THEN NULL ELSE NEW.data::jsonb END;

  -- CE GARDE-FOU NE CONCERNE QUE LES PARTIS POLITIQUES. Une organisation qui l'est AVANT ou APRES
  -- est gardee : sans le « avant », on changerait le type pour echapper au controle.
  v_politique := (v_av ->> 'type') = 'politique' OR (v_ap ->> 'type') = 'politique';
  IF NOT v_politique THEN
    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RAISE EXCEPTION 'parti_acteur_non_authentifie' USING ERRCODE = '42501';
  END IF;

  -- UN BLOB DE PARTI DOIT RESTER LISIBLE. Ecrire du texte non-JSON effacerait la composition du
  -- parti pour tout le monde -- y compris pour la regle de solidarite.
  IF TG_OP <> 'DELETE' AND v_ap IS NULL THEN
    RAISE EXCEPTION 'parti_donnees_illisibles' USING ERRCODE = '42501';
  END IF;

  v_chef_avant := v_av ->> 'chef';
  v_est_chef   := (v_chef_avant IS NOT NULL AND v_chef_avant = v_moi);

  -- ---------------------------------------------------------------------------- DISSOLUTION
  IF TG_OP = 'DELETE' THEN
    IF NOT v_est_chef AND (v_av ->> 'fondateur') IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_dissolution_non_autorisee' USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;

  -- ---------------------------------------------------------------------------- CREATION
  IF TG_OP = 'INSERT' THEN
    -- ON NE FONDE UN PARTI QU'EN SON PROPRE NOM, et on n'y place personne d'autre que soi.
    IF (v_ap ->> 'fondateur') IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_fondateur_usurpe' USING ERRCODE = '42501';
    END IF;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_ap -> 'membres', '[]'::jsonb)) m
                WHERE m ->> 'nom' IS DISTINCT FROM v_moi) THEN
      RAISE EXCEPTION 'parti_fonde_avec_des_membres' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- ---------------------------------------------------------------------------- LE CHEF DECIDE
  IF v_est_chef THEN
    RETURN NEW;   -- son parti, sa composition
  END IF;

  -- ---------------------------------------------------------------------------- LA DIRECTION
  -- Seule une election interne REELLEMENT en cours peut faire changer la direction sans que le
  -- chef l'ecrive -- c'est la resolution d'election, qui tourne dans le navigateur de n'importe
  -- quel joueur. Et le nouveau chef doit avoir ete DEJA membre : sans cela, on se couronnerait
  -- chef d'un parti ou l'on n'est pas, puis on s'y ajouterait au titre de chef.
  IF (v_ap ->> 'chef') IS DISTINCT FROM v_chef_avant THEN
    v_election := coalesce((v_av -> 'election' ->> 'enCours')::boolean, false)
                  AND (v_av -> 'election' ->> 'phase') = 'vote';
    IF NOT v_election THEN
      RAISE EXCEPTION 'parti_direction_non_autorisee' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'membres', '[]'::jsonb)) m
                    WHERE m ->> 'nom' = (v_ap ->> 'chef')) THEN
      RAISE EXCEPTION 'parti_direction_hors_du_parti' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- ---------------------------------------------------------------------------- LES ADHESIONS
  -- CHAQUE NOM AJOUTE A LA LISTE DES MEMBRES est examine. C'est ici que l'attaque est fermee.
  FOR v_m IN
    SELECT m ->> 'nom' FROM jsonb_array_elements(coalesce(v_ap -> 'membres', '[]'::jsonb)) m
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'membres', '[]'::jsonb)) a
                        WHERE a ->> 'nom' = m ->> 'nom')
  LOOP
    IF v_m = v_moi THEN
      -- ON NE S'INVITE PAS SOI-MEME : il faut que le chef l'ait fait, et la liste des invitations
      -- est gardee plus bas.
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'invitationsEnvoyees', '[]'::jsonb)) i
                      WHERE i ->> 'nom' = v_moi) THEN
        RAISE EXCEPTION 'parti_adhesion_non_invitee' USING ERRCODE = '42501';
      END IF;
    ELSIF EXISTS (SELECT 1 FROM public.personnages_donnees pd WHERE pd.name = v_m) THEN
      -- UN AUTRE JOUEUR : seul le chef peut le faire entrer.
      RAISE EXCEPTION 'parti_adhesion_non_autorisee' USING ERRCODE = '42501';
    ELSE
      -- UN PNJ RECRUTE : permis a un membre du parti, jamais a un etranger.
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'membres', '[]'::jsonb)) a
                      WHERE a ->> 'nom' = v_moi) THEN
        RAISE EXCEPTION 'parti_recrutement_hors_du_parti' USING ERRCODE = '42501';
      END IF;
    END IF;
  END LOOP;

  -- CHAQUE NOM RETIRE. On quitte un parti quand on veut ; on n'en exclut pas un autre.
  FOR v_m IN
    SELECT a ->> 'nom' FROM jsonb_array_elements(coalesce(v_av -> 'membres', '[]'::jsonb)) a
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_ap -> 'membres', '[]'::jsonb)) m
                        WHERE m ->> 'nom' = a ->> 'nom')
  LOOP
    IF v_m IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_exclusion_non_autorisee' USING ERRCODE = '42501';
    END IF;
  END LOOP;

  -- ---------------------------------------------------------------------------- LES INVITATIONS
  -- LA PORTE DE L'ADHESION DE SOI-MEME. Si n'importe qui pouvait y poser son nom, le controle des
  -- adhesions ci-dessus ne vaudrait rien.
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(coalesce(v_ap -> 'invitationsEnvoyees', '[]'::jsonb)) i
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'invitationsEnvoyees', '[]'::jsonb)) j
                        WHERE j ->> 'nom' = i ->> 'nom')) THEN
    RAISE EXCEPTION 'parti_invitation_non_autorisee' USING ERRCODE = '42501';
  END IF;
  -- On refuse une invitation qui nous concerne ; on ne retire pas celle d'un autre.
  FOR v_m IN
    SELECT j ->> 'nom' FROM jsonb_array_elements(coalesce(v_av -> 'invitationsEnvoyees', '[]'::jsonb)) j
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_ap -> 'invitationsEnvoyees', '[]'::jsonb)) i
                        WHERE i ->> 'nom' = j ->> 'nom')
  LOOP
    IF v_m IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_retrait_invitation_non_autorise' USING ERRCODE = '42501';
    END IF;
  END LOOP;

  -- ---------------------------------------------------------------------------- LES DEMANDES
  -- On demande pour soi, on retire sa propre demande. Le chef, lui, est passe bien plus haut.
  FOR v_m IN
    SELECT d ->> 'nom' FROM jsonb_array_elements(coalesce(v_ap -> 'demandesAdhesion', '[]'::jsonb)) d
     WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(v_av -> 'demandesAdhesion', '[]'::jsonb)) e
                        WHERE e ->> 'nom' = d ->> 'nom')
  LOOP
    IF v_m IS DISTINCT FROM v_moi THEN
      RAISE EXCEPTION 'parti_demande_pour_autrui' USING ERRCODE = '42501';
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.organisations_politique_autorite() IS
  'Garde-fou d autorite sur la COMPOSITION des partis politiques, pour les ecritures CLIENTES seulement. Le chef decide de son parti ; un joueur ne s ajoute que s il a ete invite -- et personne d autre que le chef ne pose une invitation ; il se retire quand il veut ; un membre peut inscrire un PNJ recrute mais jamais un joueur ; la direction ne change que par le chef ou par une election interne reellement en cours, vers un membre deja present. Ferme a la SOURCE la faille trouvee a la deuxieme passe de l Assemblee : un depute pouvait s inscrire dans le parti d un depute sanctionne pour devenir protestataire qualifie (arbitrage du 11 octobre 2026).';

DROP TRIGGER IF EXISTS trg_organisations_politique_autorite ON public.organisations;
CREATE TRIGGER trg_organisations_politique_autorite
  BEFORE INSERT OR UPDATE OR DELETE ON public.organisations
  FOR EACH ROW EXECUTE FUNCTION public.organisations_politique_autorite();

-- LA FONCTION DE DECLENCHEUR N'EST PAS APPELABLE PAR UN CLIENT. Un appel direct ne ferait rien
-- d'utile, mais la doctrine du depot l'interdit et le garde-fou d'autorite le verifie.
REVOKE ALL ON FUNCTION public.organisations_politique_autorite() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.organisations_politique_autorite() FROM anon;
REVOKE ALL ON FUNCTION public.organisations_politique_autorite() FROM authenticated;

-- -------------------------------------------------------------------------------------------------
-- PREUVES STRUCTURELLES
-- -------------------------------------------------------------------------------------------------
DO $$
DECLARE v_n integer; v_src text;
BEGIN
  -- P1 : LE DECLENCHEUR EXISTE, IL EST ACTIF, ET IL COUVRE LES TROIS OPERATIONS.
  SELECT count(*) INTO v_n FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'organisations'
     AND t.tgname = 'trg_organisations_politique_autorite' AND t.tgenabled = 'O'
     AND pg_get_triggerdef(t.oid) LIKE '%BEFORE INSERT OR DELETE OR UPDATE%';
  IF v_n <> 1 THEN RAISE EXCEPTION 'P1 : le garde-fou des partis n est pas en place'; END IF;

  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'organisations_politique_autorite';

  -- P2 : IL NE S'APPLIQUE QU'AUX PARTIS POLITIQUES. Les syndicats, loges, clubs et supporters
  -- gardent leurs flux intacts -- c'est ce qui rend cette correction non destructrice.
  IF v_src NOT LIKE '%= ''politique''%' THEN
    RAISE EXCEPTION 'P2 : le garde-fou ne se borne pas aux organisations politiques';
  END IF;

  -- P3 : IL LAISSE PASSER LE SERVEUR. Sans cela, la cotisation nocturne -- qui RETIRE un membre
  -- qui n a pas paye -- tomberait chaque nuit.
  IF v_src NOT LIKE '%est_appel_serveur()%' THEN
    RAISE EXCEPTION 'P3 : le garde-fou bloquerait aussi les ecritures serveur';
  END IF;

  -- P4 : LES CINQ REFUS QUI FERMENT L'ATTAQUE SONT TOUS NOMMES.
  SELECT count(*) INTO v_n FROM (VALUES
    ('parti_adhesion_non_autorisee'), ('parti_adhesion_non_invitee'),
    ('parti_invitation_non_autorisee'), ('parti_exclusion_non_autorisee'),
    ('parti_direction_non_autorisee')) AS r(nom)
   WHERE v_src LIKE '%' || r.nom || '%';
  IF v_n <> 5 THEN RAISE EXCEPTION 'P4 : % refus sur 5 sont nommes', v_n; END IF;

  -- P5 : ON NE S'AJOUTE PAS SANS INVITATION, ET L'INVITATION EST GARDEE. Les deux ensemble, sinon
  -- le controle ne vaut rien : il suffirait de se poser une invitation.
  IF v_src NOT LIKE '%invitationsEnvoyees%' THEN
    RAISE EXCEPTION 'P5a : la liste des invitations n est pas gardee';
  END IF;
  IF position('parti_adhesion_non_invitee' in v_src) = 0
     OR position('parti_invitation_non_autorisee' in v_src) = 0 THEN
    RAISE EXCEPTION 'P5b : l une des deux moities de la garde d adhesion manque';
  END IF;

  -- P6 : UN PNJ RECRUTE PEUT ENTRER, UN JOUEUR NON. La distinction se fait sur une LECTURE de
  -- personnages_donnees, pas sur un drapeau du blob -- qu'un client pourrait poser lui-meme.
  IF v_src NOT LIKE '%FROM public.personnages_donnees pd WHERE pd.name = v_m%' THEN
    RAISE EXCEPTION 'P6 : la distinction joueur / PNJ se fie au blob et non a la base';
  END IF;

  -- P7 : LA DIRECTION NE PASSE QU'A UN MEMBRE DEJA PRESENT, et seulement pendant une election
  -- reellement en cours. C'est ce qui empeche de contourner la garde d adhesion par la direction.
  IF v_src NOT LIKE '%parti_direction_hors_du_parti%'
     OR v_src NOT LIKE '%''phase'') = ''vote''%' THEN
    RAISE EXCEPTION 'P7 : la direction d un parti peut etre prise de l exterieur';
  END IF;

  -- P8 : LA FONCTION DE DECLENCHEUR N'EST PAS APPELABLE PAR UN CLIENT.
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'organisations_politique_autorite'
     AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE')
     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_n <> 1 THEN RAISE EXCEPTION 'P8 : la fonction de declencheur est appelable par un client'; END IF;

  -- P9 : LA SOLIDARITE PARLEMENTAIRE LIT TOUJOURS LA BASE, et n'a PAS ete modifiee : c'est la
  -- SOURCE qui a ete corrigee, pas son lecteur. Une rustine du cote de l'Assemblee aurait laisse
  -- la composition forgeable pour tout le reste du jeu.
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'assemblee_parti_de';
  IF v_src NOT LIKE '%public.organisations%' OR v_src NOT LIKE '%''politique''%' THEN
    RAISE EXCEPTION 'P9 : le lecteur de parti de l Assemblee a change de source';
  END IF;

  RAISE NOTICE 'Autorite de l appartenance aux partis : les 9 preuves structurelles passent.';
END $$;
