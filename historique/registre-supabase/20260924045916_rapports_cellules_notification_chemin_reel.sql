-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260924045916
-- Nom original      : rapports_cellules_notification_chemin_reel
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-24 04:59:16 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : bc521f27391cdaa12eca5edba10e9a77
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
CREATE OR REPLACE FUNCTION public.cellules_rapports_generer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_faits jsonb; v_n integer := 0; v_nb integer;
BEGIN
  FOR c IN SELECT id, pays_proprietaire, pays_cible
             FROM public.cellules_renseignement WHERE statut = 'active'
  LOOP
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.rapports_cellules rc
                           WHERE rc.cellule_id = c.id AND rc.jour = v_jour);

    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'categorie', r.categorie, 'fait', r.contenu, 'source', r.source)
             ORDER BY r.categorie, r.created_at), '[]'::jsonb)
      INTO v_faits
      FROM public.renseignements_connus r
     WHERE r.titulaire = 'cellule:' || c.id
       AND (r.created_at AT TIME ZONE 'Europe/Paris')::date = v_jour;

    INSERT INTO public.rapports_cellules (cellule_id, jour, contenu, nb_faits)
    VALUES (c.id, v_jour,
            jsonb_build_object('cellule', c.id, 'pays_cible', c.pays_cible,
                               'jour', v_jour, 'faits', v_faits),
            jsonb_array_length(v_faits))
    ON CONFLICT (cellule_id, jour) DO NOTHING;

    -- Le nombre est lu UNE fois et sert a la fois au chiffre et a l'accord.
    v_nb := jsonb_array_length(v_faits);

    PERFORM public.cellule_alerter_ministre(c.id, NULL,
      'Rapport de renseignement du ' || to_char(v_jour, 'DD/MM/YYYY'),
      'Le rapport quotidien de votre cellule ' || c.id ||
      ' est disponible dans votre Bureau du Ministre de la Défense, rubrique ' ||
      '« Renseignement militaire » → « Lire les rapports ». ' ||
      v_nb || CASE WHEN v_nb > 1 THEN ' faits consignés.' ELSE ' fait consigné.' END);
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rapports', v_n);
END;
$function$;