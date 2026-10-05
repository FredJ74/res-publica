-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914205411
-- Nom original      : entrepots_livrer_transits
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 20:54:11 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4ba4cd6488ef1e4e40bfdca5422283d7
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
-- LIVRAISON DES TRANSITS ARRIVES A ECHEANCE.
-- Appelee une fois par nuit par le cron. Idempotente par construction : chaque ligne livree est
-- SUPPRIMEE dans la meme transaction que le credit du stock. Un second appel le meme jour ne
-- trouve plus rien a livrer -- il n'existe pas d'etat « deja livre » a maintenir.
CREATE OR REPLACE FUNCTION public.entrepot_livrer_transits()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_ligne record; v_etat jsonb; v_ent jsonb; v_stock numeric; v_place integer;
  v_recu integer; v_perdu integer; v_livrees int := 0; v_unites int := 0; v_pertes int := 0;
BEGIN
  FOR v_ligne IN
    SELECT * FROM public.entrepot_transits
     WHERE arrivee_le <= (now() AT TIME ZONE 'utc')::date
     ORDER BY cree_le
     FOR UPDATE
  LOOP
    SELECT public.batiment_etat_lire(data) INTO v_etat
      FROM public.batiments_etat WHERE id = v_ligne.destination_id FOR UPDATE;
    IF v_etat IS NULL THEN CONTINUE; END IF;   -- entrepot disparu : la ligne reste, on reessaiera

    v_ent := coalesce(v_etat->'entrepot', '{}'::jsonb);
    v_stock := coalesce((v_ent->'stock'->>v_ligne.ressource)::numeric, 0);
    -- La place est recalculee A LA LIVRAISON : entre la commande et l'arrivee, une livraison
    -- automatique a pu remplir l'entrepot. La capacite reservee a la commande rend ce cas tres
    -- improbable, mais on ne fait jamais deborder un entrepot en silence.
    v_place := greatest(0, public.capacite_entrepot() - v_stock::int);
    v_recu := least(v_ligne.quantite, v_place);
    v_perdu := v_ligne.quantite - v_recu;

    IF v_recu > 0 THEN
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat || jsonb_build_object('entrepot',
               v_ent || jsonb_build_object('stock',
                 jsonb_set(coalesce(v_ent->'stock', '{}'::jsonb),
                           ARRAY[v_ligne.ressource], to_jsonb(v_stock + v_recu)))))::text),
             updated_at = now()
       WHERE id = v_ligne.destination_id;
    END IF;

    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
      quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
    VALUES (v_ligne.destination_id,
      CASE WHEN v_ligne.origine_type = 'auto' THEN 'approvisionnement_auto' ELSE 'commande_directe' END,
      'entree', v_ligne.origine_libelle, v_ligne.ressource, v_recu,
      v_ligne.prix_unitaire, v_ligne.fret_unitaire, v_ligne.montant_total,
      CASE WHEN v_perdu > 0 THEN 'livre_partiel_capacite' ELSE 'livre' END, v_ligne.commande_par);

    DELETE FROM public.entrepot_transits WHERE id = v_ligne.id;
    v_livrees := v_livrees + 1;
    v_unites := v_unites + v_recu;
    v_pertes := v_pertes + v_perdu;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'lignes_livrees', v_livrees,
                            'unites_livrees', v_unites, 'unites_perdues_capacite', v_pertes);
END; $$;

REVOKE ALL ON FUNCTION public.entrepot_livrer_transits() FROM PUBLIC, anon, authenticated;
