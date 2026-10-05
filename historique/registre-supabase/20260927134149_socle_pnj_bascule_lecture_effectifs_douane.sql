-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927134149
-- Nom original      : socle_pnj_bascule_lecture_effectifs_douane
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 13:41:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8a3bc418f7704c47fff2ef85d9860f07
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
-- LOT 2d — PREMIERE BASCULE DE LECTURE VERS LE SOCLE (27 septembre 2026)
--
-- L'equivalence est prouvee : comparateur 4/4, zero divergence, y compris apres une paye normale
-- et apres une paye a caisse insuffisante ou deux agents quittent le service. On bascule donc une
-- lecture -- et on choisit deliberement la MOINS consequente : la consultation publique des
-- effectifs. C'est un pur affichage, ouvert a tous, sans effet de jeu. Meme demarche que pour les
-- soldats, ou `militaire_detachement_ici` avait ete la premiere lecture basculee.
--
-- Ce qui n'est PAS bascule dans ce lot : la paye, le recrutement, le licenciement et le controle
-- de fret continuent de lire et d'ecrire `effectifsDouane`. Le blob reste l'autorite.
--
-- LE PAYS VIENT DU SERVEUR, jamais du client -- meme doctrine que `pnj_membres_ici`. La fonction
-- ne prend donc aucun argument : il n'y a rien a falsifier.
CREATE OR REPLACE FUNCTION public.douane_effectifs_publics()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_moi text; v_pays text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT COALESCE(country, 'republic') INTO v_pays
    FROM public.personnages_donnees WHERE name = v_moi;

  -- L'ordre reproduit celui du tableau d'origine : anciennete, puis matricule.
  RETURN jsonb_build_object('ok', true, 'douaniers', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
             'matricule', fp.matricule, 'type', fp.type_unite,
             'maitreNom', fp.maitre_nom, 'chienNom', fp.chien_nom)
             ORDER BY fp.recrute_le, fp.matricule)
      FROM public.pnj_membres m
      JOIN public.pnj_force_publique_metier fp ON fp.pnj_id = m.id
     WHERE m.famille = 'douanier' AND m.pays = v_pays AND m.statut = 'actif'
  ), '[]'::jsonb));
END; $$;

REVOKE ALL ON FUNCTION public.douane_effectifs_publics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.douane_effectifs_publics() TO authenticated, service_role;