-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919064948
-- Nom original      : restaurer_personnage_sauvegarde
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 06:49:48 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 28c2583bd212d15b684be5d9dbbfff97
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
-- =========================================================================================
-- RESTAURATION D'UN PERSONNAGE DEPUIS LA SAUVEGARDE DU 13/09 (19 septembre 2026)
-- =========================================================================================
-- Operation d'administration, accordee a PERSONNE : elle ne s'execute que depuis le workflow
-- technique, jamais depuis un client.
--
-- ELLE NE SE FIE JAMAIS AU NOM SEUL. Trois verrous avant d'ecrire quoi que ce soit :
--   1. le compte doit avoir DECLARE ce personnage (reconciliation_fantomes) -- c'est-a-dire
--      avoir prouve qu'il detient l'etat local de ce personnage ;
--   2. l'EMPREINTE declaree doit correspondre a la sauvegarde sur les champs poses a la
--      creation et jamais modifies : archetype, carriere, origine, ecole, et les six
--      caracteristiques. Un imposteur devrait deviner la combinaison entiere ;
--   3. le compte ne doit avoir aucun personnage, et le nom ne doit pas etre pris.
--
-- COPIE INTEGRALE ET NON DESTRUCTIVE. Les colonnes sont calculees par INTERSECTION des deux
-- schemas : aucune colonne de la sauvegarde n'est perdue (verifie : les 70 existent toujours),
-- et les quatre colonnes apparues depuis (bonus_pa_differe, competences_militaires, pa_repos_le,
-- quete_carriere) prennent simplement leur defaut. `poste` est volontairement EXCLU de la copie :
-- le trigger d'attestation le refuserait tant que le registre ne le porte pas. Il est restitue
-- ensuite par poste_attribuer_interne, qui ecrit le registre, efface le titulaire PNJ et pose le
-- miroir de fiche dans le bon ordre.
CREATE OR REPLACE FUNCTION public.restaurer_personnage_sauvegarde(
  p_nom text, p_poste text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid; v_emp jsonb; v_sauv record; v_cols text; v_sql text; v_res jsonb;
  v_champs text[] := ARRAY['archetype','career','origin','school'];
  v_c text; v_stat text;
BEGIN
  -- --- 1. Le compte a-t-il declare ce personnage ? ---
  SELECT user_id, empreinte INTO v_uid, v_emp
    FROM public.reconciliation_fantomes
   WHERE nom_local = p_nom AND traite IS FALSE
   ORDER BY vu_le DESC LIMIT 1;
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'aucune_declaration',
      'detail', 'Ce personnage n''a ete declare par aucun compte : le joueur doit recharger le jeu.');
  END IF;

  SELECT * INTO v_sauv FROM sauvegarde_beta_20260913.personnages WHERE name = p_nom;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'absent_de_la_sauvegarde'); END IF;

  -- --- 2. L'empreinte corrobore-t-elle la sauvegarde ? ---
  FOREACH v_c IN ARRAY v_champs LOOP
    IF coalesce(v_emp ->> v_c, '') IS DISTINCT FROM coalesce(
         CASE v_c WHEN 'archetype' THEN v_sauv.archetype WHEN 'career' THEN v_sauv.career
                  WHEN 'origin' THEN v_sauv.origin ELSE v_sauv.school END, '') THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'empreinte_incompatible', 'champ', v_c,
        'declare', v_emp ->> v_c, 'sauvegarde',
        CASE v_c WHEN 'archetype' THEN v_sauv.archetype WHEN 'career' THEN v_sauv.career
                 WHEN 'origin' THEN v_sauv.origin ELSE v_sauv.school END);
    END IF;
  END LOOP;
  FOREACH v_stat IN ARRAY ARRAY['CHA','DUP','ENT','INT','PER','VOL'] LOOP
    IF (v_emp -> 'stats' ->> v_stat) IS DISTINCT FROM (v_sauv.stats ->> v_stat) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'empreinte_incompatible', 'champ', 'stats.'||v_stat,
        'declare', v_emp -> 'stats' ->> v_stat, 'sauvegarde', v_sauv.stats ->> v_stat);
    END IF;
  END LOOP;

  -- --- 3. Ni doublon de compte, ni doublon de nom ---
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'compte_deja_pourvu');
  END IF;
  IF EXISTS (SELECT 1 FROM public.personnages_donnees WHERE name = p_nom) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'nom_deja_pris');
  END IF;

  -- --- 4. Copie, colonnes communes uniquement, poste exclu ---
  SELECT string_agg(quote_ident(s.column_name), ', ' ORDER BY s.column_name) INTO v_cols
    FROM information_schema.columns s
   WHERE s.table_schema='sauvegarde_beta_20260913' AND s.table_name='personnages'
     AND s.column_name NOT IN ('poste','user_id','id')
     AND EXISTS (SELECT 1 FROM information_schema.columns a
                  WHERE a.table_schema='public' AND a.table_name='personnages_donnees'
                    AND a.column_name = s.column_name);

  -- Le trigger personnages_lier_proprietaire ecrase user_id par auth.uid() : on pose donc les
  -- claims de CE compte, localement a la transaction, pour que la ligne lui soit rattachee.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid::text, 'role', 'authenticated')::text, true);

  v_sql := format('INSERT INTO public.personnages_donnees (%s, user_id) SELECT %s, %L FROM sauvegarde_beta_20260913.personnages WHERE name = %L',
                  v_cols, v_cols, v_uid, p_nom);
  EXECUTE v_sql;

  -- --- 5. Poste historique, via la primitive qui tient registre + PNJ + miroir ---
  IF p_poste IS NOT NULL THEN
    v_res := public.poste_attribuer_interne(v_sauv.country, p_poste, NULL, p_nom, 'restauration_sauvegarde');
    IF coalesce((v_res->>'ok')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_restaure', 'detail', v_res);
    END IF;
  END IF;

  UPDATE public.reconciliation_fantomes SET traite = true WHERE user_id = v_uid;

  RETURN jsonb_build_object('ok', true, 'nom', p_nom, 'user_id', v_uid,
    'poste', p_poste, 'poste_resultat', v_res);
END;
$$;

REVOKE ALL ON FUNCTION public.restaurer_personnage_sauvegarde(text, text) FROM PUBLIC, anon, authenticated;