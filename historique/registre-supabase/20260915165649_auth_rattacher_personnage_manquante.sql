-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260915165649
-- Nom original      : auth_rattacher_personnage_manquante
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-15 16:56:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 7d7510dc9221c9cd303d17efcf14605c
--
-- ARCHIVE DOCUMENTAIRE exportee de supabase_migrations.schema_migrations.
-- Ce fichier NE FAIT PAS partie d'une chaine de reconstruction et NE DOIT
-- PAS etre rejoue, ni execute automatiquement, ni servir a installer une
-- base neuve. Voir historique/registre-supabase/README.md.
--
-- Le SQL ci-dessous est conserve INTEGRALEMENT, SANS AUCUNE MODIFICATION :
-- ni correction, ni mise en forme, ni separation des parties DDL et DML,
-- ni ajout d'idempotence. On archive ce qui s'est reellement passe.
-- ============================================================================
-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- INCIDENT DU 15 SEPTEMBRE 2026 — « Acces refuse (http_404) » sur « Retrouver mon personnage ».
--
-- Le chantier B (14 septembre) a livre le CLIENT du controle de propriete (auth.js
-- rpAuthRattacherPersonnage + creation.js) mais jamais la fonction correspondante cote base :
-- aucune migration *rattach* n'existe. PostgREST repondait donc 404 sur
-- /rest/v1/rpc/rattacher_personnage, auth.js:243 traduisait ce 404 en raison 'http_404', et
-- creation.js:52 l'affichait tel quel. Le controle de propriete echouait FERME : plus personne
-- ne pouvait recuperer son propre personnage. C'etait la seule des 119 RPC appelees par le
-- client a manquer en base.
--
-- CONTRAT : exactement celui deja arbitre et deja ecrit dans creation.js:33-38 --
--   soit ce personnage appartient deja a ce compte, soit il n'appartient a personne et lui est
--   rattache maintenant, soit il est a quelqu'un d'autre et l'acces est refuse.
-- Aucune regle nouvelle n'est inventee ici.
--
-- UN COMPTE = UN PERSONNAGE. La fonction ne rattache JAMAIS un personnage deja possede, et
-- refuse si le compte appelant en detient deja un autre. Elle ne peut donc pas servir a
-- s'approprier le personnage d'autrui ni a en collectionner.
--
-- « N'APPARTIENT A PERSONNE » : personnages_donnees.user_id est NOT NULL sans defaut, donc un
-- personnage sans proprietaire ne peut exister que sous la forme explicite de l'UUID nul. La
-- fenetre transitoire d'avant l'authentification a ete fermee par la reinitialisation de la
-- beta du 13 septembre : aucune ligne ne porte cette sentinelle aujourd'hui (verifie : 0), et
-- un proprietaire disparu n'est VOLONTAIREMENT pas traite comme un orphelin -- on ne reattribue
-- pas automatiquement un personnage a une nouvelle identite anonyme.

CREATE OR REPLACE FUNCTION public.rattacher_personnage(p_nom text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_proprio   uuid;
  v_mien      text;
  c_sans_maitre CONSTANT uuid := '00000000-0000-0000-0000-000000000000';
BEGIN
  -- Jamais d'action sous la cle anon partagee : il faut une identite nominative.
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_session');
  END IF;
  IF p_nom IS NULL OR btrim(p_nom) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_absent');
  END IF;

  SELECT d.user_id INTO v_proprio
    FROM public.personnages_donnees d
   WHERE d.name = p_nom
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  -- Cas nominal : il est deja a moi. Rien a ecrire, l'acces est legitime.
  IF v_proprio = v_uid THEN
    RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'deja_rattache', true);
  END IF;

  -- Ce compte porte-t-il deja un AUTRE personnage ?
  SELECT d.name INTO v_mien
    FROM public.personnages_donnees d
   WHERE d.user_id = v_uid
   LIMIT 1;
  IF v_mien IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu', 'personnage', v_mien);
  END IF;

  -- Il appartient a un autre compte : refus sec, aucune ecriture.
  IF v_proprio IS DISTINCT FROM c_sans_maitre THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_deja_possede');
  END IF;

  -- Seul cas de rattachement : personnage explicitement sans maitre.
  UPDATE public.personnages_donnees
     SET user_id = v_uid
   WHERE name = p_nom AND user_id = c_sans_maitre;

  RETURN jsonb_build_object('ok', true, 'personnage', p_nom, 'deja_rattache', false);
END;
$$;

-- Piege recurrent du depot : ALTER DEFAULT PRIVILEGES accorde EXECUTE a anon. On le retire
-- explicitement -- cette fonction n'a de sens que sous une identite nominative.
REVOKE ALL ON FUNCTION public.rattacher_personnage(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rattacher_personnage(text) TO authenticated, service_role;