-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260925214253
-- Nom original      : dotation_initiale_reliquat
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-25 21:42:53 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 9b955563ceae52437d6170b7a03d7adc
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
-- =============================================================================================
-- RELIQUAT DE LA DOTATION INITIALE : L'ATTRIBUTION DEVIENT AUTORITAIRE (25 septembre 2026)
-- =============================================================================================
-- CE QUE C'EST, ET CE QUE CE N'EST PAS. A la creation, un personnage recoit une dotation de 30
-- points a repartir entre ses six caracteristiques. Il peut n'en depenser qu'une partie ; le
-- reliquat vit dans `free_pts_restants` et reste distribuable plus tard. Ce n'est NI un gain, NI
-- une progression, NI une recompense : c'est la finalisation differee de la repartition initiale.
-- Une fois `free_pts_restants = 0`, les caracteristiques de base sont definitivement figees.
--
-- CE QUI ETAIT CASSE. attribuerPointReliquat (plateau-pnj.js:94) appliquait la bonne regle mais
-- ecrivait depuis le navigateur, via la VUE `personnages` -- dont le trigger re-epingle `stats`
-- ET `free_pts_restants`. Le joueur voyait « +1 INT (definitif) », et rien n'etait ecrit : ni le
-- point attribue, ni le point depense. La mecanique legitime d'attribution etait entierement
-- inoperante.
--
-- LES REGLES SONT REPRISES A L'IDENTIQUE DE LA REPARTITION INITIALE, PAS REINVENTEES.
-- Source : `adjStat` (creation.js:572-581) --
--     caracteristiques admissibles : les six de STAT_DEFS (INT, CHA, VOL, PER, DUP, ENT)
--     plafond ..................... base+free >= 16 refuse (les niveaux 17-20 se debloquent en jeu)
--     cout d'un point ............. 2 a partir de 12, sinon 1   (cur >= 12 ? 2 : 1)
--     valeur par defaut ........... 8 si la cle est absente     (meme defaut que le client)
-- Aucun bareme, aucun plafond, aucune liste n'est modifie.
--
-- POURQUOI L'UPDATE PORTE SUR personnages_donnees ET NON SUR LA VUE. Le re-epinglage vit dans le
-- trigger INSTEAD OF de la vue. Une RPC SECURITY DEFINER appelee par PostgREST garde `role =
-- authenticated`, donc `est_appel_serveur()` y est FAUX : passer par la vue se ferait re-epingler
-- comme n'importe quelle ecriture cliente. On ecrit donc la table de base, ou seuls les triggers
-- d'attestation de poste, de proprietaire, de bornage du jour et d'observation de l'inventaire
-- s'appliquent -- aucun ne touche aux caracteristiques.
--
-- ATOMICITE. Lecture sous FOR UPDATE : deux appels simultanes avec un seul point restant se
-- serialisent, le second lit la valeur deja decrementee et est refuse. Aucun double point.
--
-- LE PLAFOND NE SE CONTOURNE PAS EN GARDANT SES POINTS. Le controle porte sur la valeur COURANTE
-- de la caracteristique, pas sur ce qui a ete depense : conserver ses points pour plus tard ne
-- permet jamais de depasser 16 par ce biais.
CREATE OR REPLACE FUNCTION public.dotation_attribuer_point(p_stat text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  c_plafond   constant integer := 16;
  c_defaut    constant integer := 8;
  v_moi       text;
  v_stats     jsonb;
  v_reliquat  integer;
  v_courant   integer;
  v_cout      integer;
BEGIN
  IF p_stat IS NULL OR p_stat NOT IN ('INT','CHA','VOL','PER','DUP','ENT') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caracteristique_inconnue');
  END IF;

  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT CASE WHEN jsonb_typeof(d.stats) = 'object' THEN d.stats ELSE '{}'::jsonb END,
         coalesce(d.free_pts_restants, 0)
    INTO v_stats, v_reliquat
    FROM public.personnages_donnees d
   WHERE d.name = v_moi
     FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable');
  END IF;

  IF v_reliquat <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'dotation_epuisee');
  END IF;

  v_courant := coalesce((v_stats ->> p_stat)::integer, c_defaut);

  IF v_courant >= c_plafond THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_atteint',
                              'plafond', c_plafond, 'valeur', v_courant);
  END IF;

  -- Meme bareme que adjStat : 2 points a partir de 12, sinon 1.
  v_cout := CASE WHEN v_courant >= 12 THEN 2 ELSE 1 END;

  IF v_reliquat < v_cout THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'points_insuffisants',
                              'restants', v_reliquat, 'requis', v_cout);
  END IF;

  UPDATE public.personnages_donnees
     SET stats             = v_stats || jsonb_build_object(p_stat, v_courant + 1),
         free_pts_restants = v_reliquat - v_cout
   WHERE name = v_moi;

  RETURN jsonb_build_object('ok', true, 'stat', p_stat, 'valeur', v_courant + 1,
                            'cout', v_cout, 'restants', v_reliquat - v_cout);
END;
$$;

REVOKE ALL ON FUNCTION public.dotation_attribuer_point(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dotation_attribuer_point(text) TO authenticated;