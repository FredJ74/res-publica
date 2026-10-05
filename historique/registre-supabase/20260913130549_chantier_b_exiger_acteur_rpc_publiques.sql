-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260913130549
-- Nom original      : chantier_b_exiger_acteur_rpc_publiques
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-13 13:05:49 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 0389a87883ea0e037554d4047a9e5d05
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
-- ============================================================================
-- CHANTIER B — L'IDENTITE DE L'ACTEUR N'EST PLUS UN PARAMETRE
-- 13 septembre 2026.
-- ============================================================================
-- LE DEFAUT. 47 RPC appelables par n'importe quel navigateur prenaient l'acteur
-- en simple parametre texte : retirer_helvetia('UnAutreJoueur', 999999) etait
-- accepte. Les fonctions verifiaient scrupuleusement leurs invariants de jeu --
-- solde suffisant, bornes de montant, appartenance du pret -- mais toutes ces
-- verifications portaient sur des parametres fournis par le MEME appelant. Aucune
-- ne se demandait qui appelait. Le depot ne comptait aucune fonction consultant
-- auth.uid(), sur 120.
--
-- LE CORRECTIF, EN UNE LIGNE PAR FONCTION. On insere "PERFORM exiger_acteur(...)"
-- en tete de chaque point d'entree public, sur le parametre qui designe l'acteur.
-- exiger_acteur leve 42501 si le nom ne correspond pas au personnage du compte
-- connecte -- et laisse passer le serveur (service_role), qui n'a pas d'auth.uid().
-- Aucun corps n'est reecrit : la definition existante est relue, la ligne inseree
-- juste apres son BEGIN, et la fonction recreee a l'identique pour le reste.
-- Les definitions d'origine sont sauvegardees dans
-- sauvegarde_beta_20260913.definitions_fonctions.
--
-- CE QUI EST VOLONTAIREMENT LAISSE DE COTE, ET POURQUOI :
--   * vendre_fonds_commerce(p_vendeur, p_acheteur) : lequel des deux appelle ?
--     Ambigu, donc non garde -- un mauvais choix bloquerait une vente legitime.
--   * restituer_reliquats_chantier(p_beneficiaire) : peut legitimement etre
--     declenchee pour un tiers.
--   * personnage_ajuster_pop_inf / tracts_appliquer_effet_pop : aucun parametre
--     d'acteur, seulement une cible. Ce sont des effets institutionnels : ils
--     appellent un controle d'AUTORITE, pas d'identite. Traites separement.
--   * Les 5 fonctions en langage SQL (pas plpgsql) : pas de bloc BEGIN ou inserer
--     un PERFORM. Reprises a part.

DO $migration$
DECLARE
  r record;
  def text;
  nouvelle text;
  cible record;
  faits int := 0;
  ignores text := '';
BEGIN
  FOR cible IN
    SELECT * FROM (VALUES
      ('accepter_accord_helvetia','p_personnage'), ('acheter_produit_commerce','p_acheteur'),
      ('alimenter_caisse_fonds','p_acteur'),       ('assemblee_achat_illegal','p_nom'),
      ('assemblee_amender','p_nom'),               ('assemblee_consulter_lobbyiste','p_nom'),
      ('assemblee_deposer','p_nom'),               ('assemblee_lier_topic','p_nom'),
      ('assemblee_marchander','p_nom'),            ('assemblee_neutraliser_depute','p_nom'),
      ('assemblee_retirer','p_auteur'),            ('assemblee_reveiller_depute','p_nom'),
      ('assemblee_verser_indemnite','p_nom'),      ('assemblee_voter','p_votant'),
      ('corruption_presse_tenter','p_joueur'),     ('creer_fonds_commerce','p_proprietaire'),
      ('creer_oeuvre','p_auteur'),                 ('creer_offre','p_emetteur'),
      ('creer_placement_helvetia','p_personnage'), ('creer_placement_national','p_personnage'),
      ('creer_pret_helvetia','p_personnage'),      ('deposer_helvetia','p_personnage'),
      ('elections_voix_pnj_enregistrer','p_joueur'),('employer_fonds','p_employeur'),
      ('fermer_compte_helvetia','p_personnage'),   ('finaliser_achat_bien_helvetia','p_personnage'),
      ('fuite_reserver','p_joueur'),               ('imprimerie_cession_finaliser','p_acheteur'),
      ('militaire_retrait','p_lieutenant'),        ('militaire_subtiliser','p_joueur'),
      ('ouvrir_compte_helvetia','p_personnage'),   ('refectoire_repas','p_joueur'),
      ('rembourser_pret_helvetia_integral','p_personnage'), ('repondre_offre','p_acteur'),
      ('resilier_bail_volontaire','p_acteur'),     ('retirer_caisse_fonds','p_acteur'),
      ('retirer_helvetia','p_personnage'),         ('scandale_tenter','p_joueur'),
      ('signer_compromis_bien_helvetia','p_personnage'), ('tracts_donner_joueur','p_expediteur'),
      ('vendre_materiaux_chantier','p_vendeur')
    ) AS t(nom, param)
  LOOP
    FOR r IN
      SELECT p.oid, p.oid::regprocedure::text AS sig
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
      JOIN pg_language l ON l.oid = p.prolang AND l.lanname = 'plpgsql'
      WHERE p.proname = cible.nom
        AND pg_get_function_identity_arguments(p.oid) ~ ('\m' || cible.param || '\M')
    LOOP
      def := pg_get_functiondef(r.oid);
      -- Deja garde (rejeu de la migration) : on ne double pas le controle.
      IF def LIKE '%exiger_acteur%' THEN CONTINUE; END IF;

      -- Insertion juste apres le BEGIN du corps. On exige que ce BEGIN existe
      -- reellement : sinon on n'y touche pas et on le signale.
      nouvelle := regexp_replace(
        def,
        '(AS \$function\$.*?\n)([ \t]*BEGIN[ \t]*\n)',
        '\1\2  PERFORM public.exiger_acteur(' || cible.param || ');' || chr(10),
        's');

      IF nouvelle = def THEN
        ignores := ignores || r.sig || ' (aucun BEGIN reconnu); ';
        CONTINUE;
      END IF;

      EXECUTE nouvelle;
      faits := faits + 1;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'RPC gardees : % | ignorees : %', faits, coalesce(nullif(ignores,''), 'aucune');
END
$migration$;