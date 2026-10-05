-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260916200036
-- Nom original      : fraude_electorale_sanction_serveur
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-16 20:00:36 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8c6ef703e7e96f73a04c5c9d2832a41e
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
-- CONTESTATION DE RESULTATS : LA SANCTION DEVIENT REELLE (16 septembre 2026).
--
-- LE DEFAUT. Quand une contestation etablit une fraude, le contestataire encaisse ses +200 FR et
-- l'evenement public est publie -- deux ecritures qui aboutissent. La sanction du fraudeur, elle,
-- passait par une ecriture directe sur SA fiche : refusee depuis le chantier B, avalee par un
-- .catch() muet. Le fraudeur n'etait ni amende ni detenu, et la detention qu'on lui fabriquait
-- n'avait de toute facon ni detentionId ni ligne `detentions` -- une peine fantome de plus.
--
-- LA REGLE, retrouvee dans le code et NON MODIFIEE :
--   fraudeur      : -500 FR et 2 jours de detention (peine fixe de la decouverte a posteriori,
--                   distincte des peines du flagrant delit) ;
--   contestataire : +200 FR ;
--   motif         : « Fraude électorale (<type>) révélée par contestation ».
--
-- CE QUE LE SERVEUR ETABLIT LUI-MEME : il retrouve la fraude dans `fraudes_electorales`, la table
-- canonique, et n'accepte que si elle n'est PAS ENCORE REVELEE. Le navigateur ne declare donc ni
-- l'existence de la fraude, ni le coupable (c'est `auteur` en base), ni le montant, ni la duree.
-- Il ne fait que demander l'execution de la consequence d'une contestation qu'il vient de gagner.
--
-- IDEMPOTENCE : le passage a l'etat « revelee » se fait sous verrou (FOR UPDATE) AVANT toute
-- sanction. Deux requetes concurrentes, un rejeu, un F5 : la seconde voit une fraude deja revelee
-- et ne produit ni amende, ni detention, ni recompense.
--
-- ATOMICITE : revelation, amende, detention et recompense vivent dans la meme transaction. La
-- detention passe par detention_ouvrir_interne -- aucune seconde mecanique de prison.

CREATE OR REPLACE FUNCTION public.fraude_electorale_sanctionner(p_fraude_id text, p_ville text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_contestataire text; v_f record; v_res jsonb; v_arg_contest numeric;
  v_amende integer := 500; v_recompense integer := 200; v_jours integer := 2;
  v_raison text; v_ville text;
BEGIN
  v_contestataire := public.mon_personnage();
  IF v_contestataire IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  -- 1. LA FRAUDE, dans la table canonique, verrouillee avant tout effet.
  SELECT * INTO v_f FROM public.fraudes_electorales WHERE id = p_fraude_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fraude_introuvable');
  END IF;
  IF coalesce(v_f.etat, '') = 'revelee' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fraude_deja_revelee');
  END IF;
  IF coalesce(v_f.auteur, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'auteur_inconnu');
  END IF;

  -- 2. LA REVELATION EST LE VERROU : rejeu et concurrence butent ici.
  UPDATE public.fraudes_electorales
     SET etat = 'revelee', revelee_par = v_contestataire, revelee_le = now()
   WHERE id = p_fraude_id;

  v_ville := coalesce(nullif(p_ville, ''), v_f.city, 'capitale');
  v_raison := 'Fraude électorale (' || replace(coalesce(v_f.type, 'fraude'), '_', ' ')
              || ') révélée par contestation';

  -- 3. L'AMENDE. Le montant vient d'ici, jamais de l'appelant.
  UPDATE public.personnages_donnees
     SET arg = greatest(0, coalesce(arg, 0) - v_amende)
   WHERE name = v_f.auteur;

  -- 4. LA DETENTION, par la primitive canonique -- 2 jours, la peine de ce chemin.
  v_res := public.detention_ouvrir_interne(
             v_f.auteur, v_raison, v_jours, v_ville, v_f.country,
             jsonb_build_array(jsonb_build_object(
               'type', v_raison, 'jours', v_jours, 'city', v_ville,
               'source', 'fraude_revelee_contestation',
               'date_evenement', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))),
             v_contestataire, 'fraude_revelee');

  -- 5. LA RECOMPENSE du contestataire, dans la meme transaction.
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) + v_recompense
   WHERE name = v_contestataire
   RETURNING arg INTO v_arg_contest;

  RETURN jsonb_build_object(
    'ok', true, 'fraudeur', v_f.auteur, 'type', v_f.type, 'amende', v_amende,
    'jours', v_jours, 'recompense', v_recompense, 'arg_contestataire', v_arg_contest,
    'detention_id', v_res->>'detention_id',
    'detention_ouverte', coalesce((v_res->>'ok')::boolean, false),
    'detention_raison', v_res->>'raison');
END; $$;

REVOKE ALL ON FUNCTION public.fraude_electorale_sanctionner(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fraude_electorale_sanctionner(text, text) TO authenticated;