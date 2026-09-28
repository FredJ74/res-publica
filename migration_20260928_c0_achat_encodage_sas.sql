-- =====================================================================
-- C0 — SECURISATION DU CHEMIN D'ACHAT (2/2) : ENCODAGE DU SAS
-- =====================================================================
-- Migration appliquee en base : 20260928085244 c0_achat_encodage_sas_conforme
-- (2e des 3 migrations du chantier C0+C1 ; s'applique apres
--  migration_20260928_c0_achat_securisation.sql et avant
--  migration_20260928_c1_fonds_local_types_l2.sql).
--
-- Ce fichier reproduit A L'IDENTIQUE le SQL applique. Ne pas le rejouer sur une
-- base ou la migration figure deja dans supabase_migrations.
-- =====================================================================

-- Defaut trouve par le banc C0, et HERITE DE L'ANCIENNE FONCTION : l'insertion
-- dans objets_recus ecrivait (v_objet || ...)::text dans une colonne de type
-- jsonb. PostgreSQL ne convertit pas implicitement text vers jsonb : l'insertion
-- echouait avec 42804.
--
-- L'ancienne signature portait exactement la meme erreur. Elle n'a jamais ete
-- executee (aucun appelant, aucun fonds v2, aucune reference), donc personne ne
-- l'avait constatee : la vulnerabilite A etait en realite doublee d'un defaut qui
-- aurait fait echouer tout achat des le premier appel.
--
-- CONVENTION VIVANTE DU SAS, etablie par ses trois producteurs reels
-- (inventaire_donner, objet_sas_deposer, tracts_donner_joueur) : data est un jsonb
-- contenant une CHAINE de caracteres JSON, produite par to_jsonb(objet::text). Le
-- client la relit par JSON.parse(r.data) (supabase.js). Stocker un objet jsonb au
-- lieu d'une chaine ferait echouer ce JSON.parse cote navigateur. On se conforme
-- donc a la convention existante plutot que d'en inventer une quatrieme.
create or replace function public.acheter_produit_commerce(
  p_requete      text,
  p_acheteur     text,
  p_fonds_id     text,
  p_reference_id text,
  p_quantite     integer
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
DECLARE
  v_fonds       jsonb;
  v_ref         jsonb;
  v_gen         record;
  v_var_id      text := null;
  v_var_libelle text := null;
  v_prix        integer;
  v_stock       integer;
  v_veut        integer := GREATEST(0, COALESCE(p_quantite, 0));
  v_qte         integer;
  v_montant     integer;
  v_arg         numeric;
  v_objet       jsonb;
  v_livre       jsonb;
  v_ids         text[] := '{}';
  v_id          text;
  v_destinataire text;
  v_enseigne    text;
  i             integer;
BEGIN
  PERFORM public.exiger_acteur(p_acheteur);

  IF p_requete IS NULL OR p_requete !~ '^achat-[A-Za-z0-9-]{6,80}$' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide');
  END IF;
  IF COALESCE(p_acheteur,'') = '' OR COALESCE(p_fonds_id,'') = ''
     OR COALESCE(p_reference_id,'') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;
  IF v_veut <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF NOT public.mouvement_titulaire(p_acheteur, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;

  SELECT data INTO v_fonds FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF COALESCE(v_fonds->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;

  v_ref := v_fonds->'references'->p_reference_id;
  IF v_ref IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente');
  END IF;
  IF COALESCE((v_ref->>'active')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_inactive');
  END IF;
  v_prix  := GREATEST(0, COALESCE((v_ref->>'prixVente')::numeric, 0))::integer;
  v_stock := GREATEST(0, COALESCE((v_ref->>'stock')::numeric, 0))::integer;
  IF v_prix <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_non_fixe');
  END IF;
  IF v_stock <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'rupture_de_stock');
  END IF;

  IF COALESCE(v_ref->>'generique_id','') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_sans_generique');
  END IF;
  SELECT g.id, g.libelle, g.regime, g.est_service, g.empilable, g.individualise,
         g.encombrement, g.consommable, g.equipable
    INTO v_gen
    FROM public.catalogue_generiques g
   WHERE g.id = v_ref->>'generique_id';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_inconnu');
  END IF;
  IF v_gen.est_service THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_est_un_service');
  END IF;
  IF NOT v_gen.individualise AND NOT v_gen.empilable THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_regime_indetermine');
  END IF;
  IF COALESCE(v_ref->>'variante_id','') <> '' THEN
    SELECT v.id, v.libelle INTO v_var_id, v_var_libelle
      FROM public.catalogue_variantes v
     WHERE v.id = v_ref->>'variante_id' AND v.generique_id = v_gen.id;
    IF v_var_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'variante_incoherente');
    END IF;
  END IF;

  IF left(p_acheteur, 5) = 'orga:' THEN
    SELECT GREATEST(0, COALESCE((data::jsonb->>'caisse')::numeric, 0)) INTO v_arg
      FROM public.organisations WHERE id = substr(p_acheteur, 6);
  ELSE
    SELECT COALESCE(arg, 0) INTO v_arg FROM public.personnages
     WHERE name = CASE WHEN left(p_acheteur,3) = 'pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END;
  END IF;
  IF v_arg IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;
  v_qte := LEAST(v_veut, v_stock, floor(v_arg / v_prix)::integer);
  IF v_qte <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'prixUnitaire', v_prix);
  END IF;
  v_montant := v_qte * v_prix;

  -- GARDE DE REJEU : sous verrou du fonds, AVANT tout mouvement d'argent.
  IF EXISTS (SELECT 1 FROM public.objets_recus
              WHERE id = p_requete OR id LIKE p_requete || '-%') THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree');
  END IF;

  v_destinataire := CASE WHEN left(p_acheteur,3) = 'pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END;
  v_enseigne     := COALESCE(NULLIF(btrim(v_fonds->>'enseigne'), ''), 'Commerce');
  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'type',         p_reference_id,
    'generique_id', v_gen.id,
    'variante_id',  v_var_id,
    'name',         COALESCE(NULLIF(btrim(v_ref->>'nom'), ''),
                             COALESCE(v_var_libelle, v_gen.libelle)),
    'desc',         NULLIF(btrim(v_ref->>'description'), ''),
    'icon',         COALESCE(NULLIF(btrim(v_ref->>'icon'), ''), 'ti-package'),
    'imageUrl',     NULLIF(btrim(v_ref->>'image'), ''),
    'legal',        CASE WHEN v_gen.regime = 'illegal' THEN false ELSE true END,
    'provenance',   jsonb_build_object(
                      'fondsId',     p_fonds_id,
                      'referenceId', p_reference_id,
                      'createur',    v_fonds->>'proprietaire',
                      'etapes',      '[]'::jsonb)
  ));

  IF v_gen.individualise THEN
    FOR i IN 1..v_qte LOOP
      v_id := p_requete || '-' || i;
      v_livre := v_objet
                 || jsonb_build_object('qty', 1)
                 || CASE WHEN v_gen.encombrement IS NOT NULL
                         THEN jsonb_build_object('encombrement', v_gen.encombrement)
                         ELSE '{}'::jsonb END
                 || jsonb_build_object('exemplaire', jsonb_build_object('id', v_id));
      INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
      VALUES (v_id, v_destinataire, v_enseigne, to_jsonb(v_livre::text))
      ON CONFLICT (id) DO NOTHING;
      v_ids := v_ids || v_id;
    END LOOP;
  ELSE
    v_id    := p_requete;
    v_livre := v_objet || jsonb_build_object(
                 'stackable', true, 'stackKey', p_reference_id, 'qty', v_qte);
    INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
    VALUES (v_id, v_destinataire, v_enseigne, to_jsonb(v_livre::text))
    ON CONFLICT (id) DO NOTHING;
    v_ids := v_ids || v_id;
  END IF;

  IF NOT public.mouvement_titulaire(p_acheteur, -v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;
  v_ref   := jsonb_set(v_ref, '{stock}', to_jsonb(v_stock - v_qte));
  v_fonds := jsonb_set(v_fonds, ARRAY['references', p_reference_id], v_ref);
  v_fonds := jsonb_set(v_fonds, '{caisse}',
               to_jsonb(GREATEST(0, COALESCE((v_fonds->>'caisse')::numeric, 0)) + v_montant));
  UPDATE public.entreprises SET data = v_fonds, updated_at = now() WHERE id = p_fonds_id;

  RETURN jsonb_build_object(
    'ok', true, 'rejeu', false,
    'quantite', v_qte, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stockRestant', v_stock - v_qte,
    'generique_id', v_gen.id, 'variante_id', v_var_id,
    'livraisons', to_jsonb(v_ids));
END;
$$;

revoke all on function public.acheter_produit_commerce(text,text,text,text,integer) from public, anon, authenticated;
grant execute on function public.acheter_produit_commerce(text,text,text,text,integer) to authenticated, service_role;
