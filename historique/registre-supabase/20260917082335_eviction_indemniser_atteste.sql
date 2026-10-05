-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917082335
-- Nom original      : eviction_indemniser_atteste
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-17 08:23:35 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : c33c79a7b3e026f76a25a8802f826e35
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
-- LOT A — INDEMNITE D'EVICTION : UNE SEULE OPERATION, ATOMIQUE
-- Suite de l'audit des frontieres d'autorite, 17 septembre 2026.
--
-- CONSTAT : doSupprimerSubdivision (plateau-justice-economie.js) debitait le proprietaire en local
-- (state.arg -= indemnite) puis tentait de crediter le locataire evince par un sbGet + sbUpdate
-- DIRECTS sur la fiche d'autrui. Depuis la fermeture RLS ces deux appels echouent en silence
-- (sbUpdate rend null sans lever) : le proprietaire payait, le locataire ne recevait RIEN, et un
-- mail lui annoncait pourtant « une indemnite d'eviction vous a ete versee ». Perte seche.
--
-- Ici, TOUT devient une seule transaction : controle d'autorite, calcul du montant, debit, credit,
-- fin du bail et retrait du lot. Aucune moitie ne peut survivre seule.
--
-- RIEN DU GAME DESIGN NE CHANGE : meme regle d'indemnite (UN AN DE LOYER = loyer * 365), meme
-- refus si le batiment est livre (« Reconfigurer les lots »), meme suppression du bail avec le lot.
-- Le montant n'est plus fourni par le navigateur : il est RECALCULE depuis le loyer inscrit dans
-- l'etat du terrain. Le beneficiaire n'est plus fourni non plus : il est lu sur le bail.
--
-- Un seul point de methode change, et il est deja doctrinal dans le projet : le debit porte sur les
-- FONDS ORDINAIRES (liquide puis Banque nationale, via helvetia_debiter_fonds_ordinaires) et non
-- sur `arg`. C'est la primitive canonique de depense -- `arg` inclut Helvetia et les placements,
-- qui ne doivent jamais couvrir automatiquement une depense courante. Le credit du locataire suit
-- la convention deja en place pour subvention_citoyen_verser (increment de arg).
--
-- IDEMPOTENCE : le lot est retire de l'etat du terrain dans la meme transaction. Un rejeu ne
-- retrouve plus le lot et rend 'lot_introuvable' -- aucune seconde indemnite possible.
CREATE OR REPLACE FUNCTION public.eviction_indemniser(
  p_country text, p_building_id text, p_lot_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_moi text; v_id text; v_proprio text; v_brut text; v_etat jsonb;
  v_subs jsonb; v_lot jsonb; v_reste jsonb; v_trouve boolean := false;
  v_loyer numeric; v_indemnite numeric := 0;
  v_bail record; v_occupant text := NULL;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  IF COALESCE(btrim(p_country),'') = '' OR COALESCE(btrim(p_building_id),'') = ''
     OR COALESCE(btrim(p_lot_id),'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_id := p_country || '_' || p_building_id;
  SELECT proprietaire, data INTO v_proprio, v_brut
    FROM public.terrains_etat WHERE id = v_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'terrain_introuvable');
  END IF;

  -- AUTORITE : seul le proprietaire du terrain peut retirer un de ses lots.
  IF v_proprio IS DISTINCT FROM v_moi THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_proprietaire');
  END IF;

  v_etat := public.terrain_etat_lire(v_brut);
  IF v_etat IS NULL OR jsonb_typeof(v_etat) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'etat_illisible');
  END IF;

  -- Meme regle que le client : un batiment LIVRE ne se redecoupe pas par formulaire.
  IF COALESCE(v_etat->>'niveau_construction','') <> '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'chantier_requis');
  END IF;

  v_subs := CASE WHEN jsonb_typeof(v_etat->'subdivisions') = 'array'
                 THEN v_etat->'subdivisions' ELSE '[]'::jsonb END;

  SELECT e INTO v_lot FROM jsonb_array_elements(v_subs) e WHERE e->>'id' = p_lot_id LIMIT 1;
  IF v_lot IS NULL THEN
    -- Deja retire (rejeu, double-clic) ou identifiant inconnu.
    RETURN jsonb_build_object('ok', false, 'raison', 'lot_introuvable');
  END IF;
  v_trouve := true;

  v_loyer := GREATEST(0, COALESCE((v_lot->>'loyer')::numeric, 0));

  -- OCCUPANT : lu sur le bail, jamais fourni par l'appelant.
  SELECT * INTO v_bail FROM public.locations_actives
   WHERE country = p_country
     AND data->>'buildingId' = p_building_id
     AND data->>'lotId' = p_lot_id
   FOR UPDATE;
  IF FOUND THEN
    v_occupant := NULLIF(btrim(COALESCE(v_bail.data->>'locataire','')), '');
  END IF;

  IF v_occupant IS NOT NULL THEN
    v_indemnite := floor(v_loyer * 365);
    IF v_indemnite > 0 THEN
      PERFORM 1 FROM public.personnages_donnees WHERE name = v_occupant FOR UPDATE;
      IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'occupant_introuvable', 'occupant', v_occupant);
      END IF;
      -- Fail-closed : sans debit effectif du proprietaire, aucune eviction, aucun credit.
      IF NOT public.helvetia_debiter_fonds_ordinaires(v_moi, v_indemnite) THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                                  'requis', v_indemnite);
      END IF;
      UPDATE public.personnages_donnees
         SET arg = COALESCE(arg,0) + v_indemnite, updated_at = now()
       WHERE name = v_occupant;
    END IF;
    -- Le lot disparait, donc son bail aussi (regle existante).
    DELETE FROM public.locations_actives WHERE id = v_bail.id;
  END IF;

  -- Retrait du lot, dans la meme transaction que le paiement.
  SELECT COALESCE(jsonb_agg(e), '[]'::jsonb) INTO v_reste
    FROM jsonb_array_elements(v_subs) e WHERE e->>'id' IS DISTINCT FROM p_lot_id;
  v_etat := v_etat || jsonb_build_object('subdivisions', v_reste);

  UPDATE public.terrains_etat
     SET data = v_etat::text, updated_at = now()
   WHERE id = v_id;

  RETURN jsonb_build_object('ok', true, 'lot', p_lot_id, 'occupant', v_occupant,
    'indemnite', v_indemnite, 'lots_restants', jsonb_array_length(v_reste),
    'arg', (SELECT arg FROM public.personnages_donnees WHERE name = v_moi),
    'liquide', (SELECT liquide FROM public.personnages_donnees WHERE name = v_moi));
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.eviction_indemniser(text, text, text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.eviction_indemniser(text, text, text) TO authenticated;