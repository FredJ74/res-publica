-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928212744
-- Nom original      : c6_apport_matiere_acceptation
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-28 21:27:44 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 639fa52a4f34a9cab9da0696d032d3d6
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
create or replace function public.fonds_matiere_apporter(
  p_requete text, p_acteur text, p_fonds_id text,
  p_matiere text, p_qte integer, p_mode text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $fn$
DECLARE
  v_deja   record;
  v_data   jsonb;
  v_mat    text := btrim(coalesce(p_matiere, ''));
  v_mode   text := lower(btrim(coalesce(p_mode, 'vente')));
  v_veut   integer := GREATEST(0, coalesce(p_qte, 0));
  v_m      record;
  v_inv    jsonb; v_jour integer;
  v_detenu numeric; v_capacite integer; v_payable integer;
  v_prix   numeric; v_qte integer; v_montant numeric;
  v_caisse numeric; v_stock numeric; v_cmup numeric; v_nouveau numeric;
  v_sm jsonb; v_cmm jsonb; v_inv_apres jsonb; v_reste integer;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);

  IF p_requete IS NULL OR p_requete !~ '^appro-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  IF v_mode NOT IN ('vente', 'don') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mode_invalide'); END IF;
  IF coalesce(p_fonds_id,'') = '' OR v_mat = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides'); END IF;
  IF v_veut <= 0 OR v_veut IS DISTINCT FROM p_qte THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide'); END IF;

  SELECT * INTO v_deja FROM public.apports_matieres WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'quantite', v_deja.quantite, 'prixUnitaire', v_deja.prix_unitaire,
                              'montant', v_deja.montant, 'mode', v_deja.mode);
  END IF;

  SELECT data INTO v_data FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_data IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent'); END IF;
  IF coalesce((v_data->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj'); END IF;
  IF coalesce(v_data->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif'); END IF;

  IF NOT public.fonds_acteur_present(p_acteur, v_data->'implantation') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_sur_place'); END IF;

  SELECT * INTO v_m FROM public.fonds_matieres_accessibles(p_fonds_id) m WHERE m.matiere = v_mat;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_hors_activites', 'matiere', v_mat); END IF;
  IF NOT v_m.acceptee THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'matiere_non_acceptee', 'matiere', v_mat); END IF;
  IF v_m.plafond_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'plafond_matiere_non_defini',
                              'pays', v_data->'implantation'->>'country'); END IF;

  SELECT coalesce(inventory,'[]'::jsonb), coalesce(day,1) INTO v_inv, v_jour
    FROM public.personnages_donnees WHERE name = p_acteur FOR UPDATE;
  IF v_inv IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'); END IF;

  v_detenu := public.inventaire_quantite(v_inv, v_mat);
  IF v_detenu <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_personnel_insuffisant', 'detenu', v_detenu); END IF;

  v_capacite := v_m.place_restante;
  IF v_capacite <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_plein',
                              'stock', v_m.stock, 'maximum', v_m.maximum); END IF;

  v_prix   := CASE WHEN v_mode = 'don' THEN 0 ELSE GREATEST(0, coalesce(v_m.prix_achat, 0)) END;
  v_caisse := GREATEST(0, coalesce((v_data->>'caisse')::numeric, 0));

  v_payable := CASE WHEN v_prix <= 0 THEN v_veut ELSE floor(v_caisse / v_prix)::integer END;
  v_qte := LEAST(v_veut, floor(v_detenu)::integer, v_capacite, v_payable);

  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante',
                              'caisse', v_caisse, 'prixUnitaire', v_prix); END IF;

  v_montant := round(v_prix * v_qte, 2);

  IF v_montant > 0 THEN
    UPDATE public.personnages_donnees
       SET arg     = COALESCE(arg, 0)     + v_montant,
           liquide = COALESCE(liquide, 0) + v_montant,
           updated_at = now()
     WHERE name = p_acteur;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'vendeur_introuvable'); END IF;
  END IF;

  v_sm    := coalesce(v_data->'stockMatieres', '{}'::jsonb);
  v_cmm   := coalesce(v_data->'coutMoyenMatieres', '{}'::jsonb);
  v_stock := GREATEST(0, coalesce((v_sm->>v_mat)::numeric, 0));
  v_cmup  := coalesce((v_cmm->>v_mat)::numeric, 0);
  v_nouveau := round(((v_cmup * v_stock) + (v_prix * v_qte)) / (v_stock + v_qte), 4);

  v_inv_apres := public.inventaire_retirer(v_inv, v_mat, v_qte);
  UPDATE public.personnages_donnees
     SET inventory = v_inv_apres, updated_at = now()
   WHERE name = p_acteur;

  v_data := v_data
    || jsonb_build_object(
         'stockMatieres',     jsonb_set(v_sm,  ARRAY[v_mat], to_jsonb(v_stock + v_qte)),
         'coutMoyenMatieres', jsonb_set(v_cmm, ARRAY[v_mat], to_jsonb(v_nouveau)))
    || jsonb_build_object('caisse', v_caisse - v_montant);

  v_data := public.entreprise_ajouter_historique(v_data, -v_montant,
    CASE WHEN v_mode = 'don' THEN 'Don de matiere (' ELSE 'Achat de matiere (' END
    || v_mat || ' x' || v_qte || ') — ' || p_acteur, v_jour);

  UPDATE public.entreprises SET data = v_data, updated_at = now() WHERE id = p_fonds_id;

  INSERT INTO public.apports_matieres
    (requete, fonds_id, acteur, matiere, mode, quantite, prix_unitaire, montant)
  VALUES (p_requete, p_fonds_id, p_acteur, v_mat, v_mode, v_qte, v_prix, v_montant);

  v_reste := CASE WHEN v_m.maximum = 0
                  THEN GREATEST(0, coalesce(v_m.plafond_pays, 0) - (v_stock + v_qte))::integer
                  ELSE GREATEST(0, v_m.maximum - (v_stock + v_qte))::integer END;

  RETURN jsonb_build_object('ok', true, 'mode', v_mode, 'matiere', v_mat,
    'quantite', v_qte, 'demandee', v_veut, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stock', v_stock + v_qte, 'maximum', v_m.maximum, 'illimite', v_m.maximum = 0,
    'placeRestante', v_reste,
    'coutMoyen', v_nouveau, 'caisse', v_caisse - v_montant, 'inventory', v_inv_apres);
END; $fn$;

comment on function public.fonds_matiere_apporter(text, text, text, text, integer, text) is
  'Apport d''une matiere premiere a un fonds PJ, par vente (prix fixe par le proprietaire) ou par don. Exige la presence physique ET que le proprietaire ait explicitement ACCEPTE cette matiere. Perimetre derive des activites du commerce. Borne la quantite par la possession reelle, la place restante et la caisse. Met a jour le CMUP. Idempotente par cle de requete.';

revoke all on function public.fonds_matiere_apporter(text, text, text, text, integer, text) from public, anon, authenticated;
grant execute on function public.fonds_matiere_apporter(text, text, text, text, integer, text) to authenticated, service_role;