-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928102952
-- Nom original      : c4_achat_reel_et_preuve_immuable
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-28 10:29:52 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4e838d0a7dc10a86e9d9460583af3cd4
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
-- =====================================================================
-- C4 — ACHAT REEL ET PREUVE IMMUABLE
-- =====================================================================
-- Ferme la premiere verticale commerciale PJ de bout en bout.
--
-- CE QUE LE CLIENT FOURNIT : une intention d'achat, et rien d'autre --
-- cle de requete, acteur, fonds, reference, quantite. Il ne fournit NI l'objet,
-- NI le generique, NI la recette, NI le prix, NI le montant, NI le vendeur.
-- Le serveur reconstruit tout depuis les donnees autoritaires.
--
-- CE QUI EST UNIVERSEL, ET CE QUI EST REPUBLIA. La transaction, l'idempotence,
-- la preuve, la construction serveur, le paiement et le stock sont du SOCLE. Le
-- coefficient de plafond de prix est une POLITIQUE DE PAYS, lue dans
-- entreprises_constantes -- aucune regle propre a Republia ne devient une
-- constante du moteur.

-- ---------------------------------------------------------------------------
-- 1. LA PREUVE DE TRANSACTION
-- ---------------------------------------------------------------------------
-- L'audit du 28 septembre 2026 a etabli qu'AUCUNE preuve d'achat figee n'existait
-- nulle part : ni acheter_produit_commerce, ni acheter_a_entrepot n'ecrivaient
-- dans une table de vente ; entreprises.data.historique est plafonne a 50 entrees
-- dans un blob reecrit a chaque UPDATE ; fiscalite_journal n'a aucun ecrivain ;
-- entrepot_journal ne couvre que l'approvisionnement inter-entrepots, jamais la
-- vente au detail. Aucune de ces structures ne pouvait devenir la preuve
-- canonique sans denaturer son usage : cette table est donc creee, et elle est la
-- seule de son role.
--
-- CE QU'ELLE FIGE, ET POURQUOI CE NIVEAU.
-- Une preuve doit rester vraie meme si le commercant renomme sa reference, meme
-- s'il la desactive, et meme si le referentiel L2 evolue. On fige donc :
--   - les IDENTIFIANTS STABLES (fonds, reference, generique, recette, variante) :
--     ils permettent de rattacher la vente au systeme sans la figer deux fois ;
--   - le TEXTE COMMERCIAL affiche au moment de la vente : c'est lui que
--     l'acheteur a lu, et c'est lui qui peut etre trompeur ;
--   - la FICHE OFFICIELLE telle qu'elle etait au moment de la vente, c'est-a-dire
--     la verite mecanique que l'acheteur pouvait consulter. La recopier plutot que
--     de la recalculer plus tard est ce qui rend la preuve historiquement vraie :
--     si un effet est ajoute au referentiel demain, la vente d'hier continue de
--     dire que l'objet ne procurait rien.
-- On ne recopie PAS tout le referentiel : les identifiants stables plus la fiche
-- effective suffisent a etablir ce qui a ete vendu et ce qu'il procurait.
--
-- APPEND-ONLY, ET PAS SEULEMENT PAR LES DROITS. Un declencheur refuse tout UPDATE
-- et tout DELETE, y compris pour le proprietaire de la table et pour service_role.
-- C'est le premier declencheur de ce type du schema : l'audit avait releve qu'il
-- n'en existait aucun sur aucun journal.
create table if not exists public.ventes_snapshots (
  id               uuid primary key default gen_random_uuid(),
  requete          text not null unique,
  vendu_le         timestamptz not null default now(),
  jour_paris       text not null,
  -- parties
  acheteur         text not null,
  vendeur          text not null,
  fonds_id         text not null,
  pays             text,
  -- produit, tel qu'il etait au moment de la vente
  reference_id     text not null,
  nom_commercial   text not null,
  description_commerciale text,
  generique_id     text not null,
  recette_id       text,
  variante_id      text,
  famille          text,
  types            jsonb,
  -- economie
  quantite         integer not null check (quantite > 0),
  prix_unitaire    integer not null check (prix_unitaire > 0),
  montant_total    integer not null check (montant_total > 0),
  -- verite mecanique figee : la fiche officielle telle qu'elle etait
  fiche_officielle jsonb not null
);

comment on table public.ventes_snapshots is
  'Preuve immuable d''une vente. Ecrite dans la MEME transaction que le paiement, le decrement de stock et la livraison. Fige le texte commercial affiche et la fiche officielle du moment : une reference renommee, redecrite, retarifee ou desactivee ensuite ne change rien a une vente passee. Append-only, y compris pour service_role.';

create index if not exists idx_ventes_snapshots_acheteur on public.ventes_snapshots (acheteur, vendu_le desc);
create index if not exists idx_ventes_snapshots_fonds    on public.ventes_snapshots (fonds_id, vendu_le desc);

create or replace function public.ventes_snapshots_append_only()
returns trigger
language plpgsql
as $$
BEGIN
  RAISE EXCEPTION 'preuve_immuable: une vente enregistree ne peut etre ni modifiee ni supprimee'
    USING ERRCODE = '42501';
END;
$$;

drop trigger if exists trg_ventes_snapshots_append_only on public.ventes_snapshots;
create trigger trg_ventes_snapshots_append_only
  before update or delete on public.ventes_snapshots
  for each row execute function public.ventes_snapshots_append_only();

-- FERMEE AUX CLIENTS. Aucune ecriture directe, aucune lecture publique. Une
-- lecture controlee par les parties legitimes sera ouverte quand le systeme de
-- preuve aura un lecteur reel -- on n'expose rien par anticipation.
alter table public.ventes_snapshots enable row level security;
revoke all on public.ventes_snapshots from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. ACHAT REEL
-- ---------------------------------------------------------------------------
-- QUATRE CHANGEMENTS PAR RAPPORT A C2, TOUS DEMANDES PAR LE MODELE DE PREUVE :
--
--   a) L'IDEMPOTENCE CHANGE DE GARDIEN. Elle reposait sur objets_recus -- or
--      l'acheteur a le droit de SUPPRIMER ses lignes de sas en les reclamant.
--      Rejouer une cle apres reclamation aurait donc rachete. La garde est
--      desormais la contrainte d'unicite de ventes_snapshots.requete, qui est
--      permanente et append-only. C'est une correction reelle, pas un
--      deplacement cosmetique.
--
--   b) LE PRIX EST REVALIDE AU MOMENT DE LA VENTE, avec exactement la formule qui
--      a servi a le fixer : cout de revient courant x coefficient du pays. Une
--      reference devenue hors plafond ne se vend plus, et rien n'est modifie
--      automatiquement -- le prix du commercant lui appartient.
--
--   c) LE GENERIQUE DOIT TOUJOURS RELEVER DES TYPES DU FONDS. Retirer un type
--      d'activite retire de la vente les references qui en dependaient.
--
--   d) L'OBJET LIVRE PORTE SA RECETTE. generique_id disait ce que c'est, il dit
--      desormais aussi comment il a ete fabrique. C'est un ancrage possible pour
--      un futur systeme d'authenticite -- possible, pas decide : rien ici ne pose
--      que recette_id vaut authenticite.
--
-- ACHETEUR = PROPRIETAIRE : aucune regle n'existe dans le moteur historique, et
-- aucune n'est inventee ici. L'achat reussit ; l'argent va de la poche du
-- proprietaire a la caisse de son propre fonds, sans gain. Point remonte.
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
  v_acces       record;
  v_var_id      text := null;
  v_var_libelle text := null;
  v_prix        integer;
  v_stock       integer;
  v_veut        integer := GREATEST(0, COALESCE(p_quantite, 0));
  v_qte         integer;
  v_montant     integer;
  v_arg         numeric;
  v_cout        jsonb;
  v_objet       jsonb;
  v_livre       jsonb;
  v_fiche       jsonb;
  v_ids         text[] := '{}';
  v_id          text;
  v_destinataire text;
  v_enseigne    text;
  v_types       jsonb;
  v_deja        record;
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
  IF v_veut <= 0 OR v_veut IS DISTINCT FROM p_quantite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;

  -- (a) GARDE D'IDEMPOTENCE, permanente, avant toute lecture d'etat mutable
  SELECT * INTO v_deja FROM public.ventes_snapshots WHERE requete = p_requete;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree',
                              'venteId', v_deja.id, 'quantite', v_deja.quantite,
                              'montant', v_deja.montant_total);
  END IF;

  IF NOT public.mouvement_titulaire(p_acheteur, 0) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acheteur_absent');
  END IF;

  SELECT data INTO v_fonds FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF COALESCE((v_fonds->>'version')::numeric, 0) < 2 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_un_fonds_pj');
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
  v_stock := GREATEST(0, COALESCE((v_fonds->'stockReferences'->>p_reference_id)::numeric, 0))::integer;
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
         g.encombrement, g.famille_id
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

  -- (c) le generique doit TOUJOURS relever des types du fonds
  SELECT * INTO v_acces FROM public.fonds_generiques_accessibles(p_fonds_id)
   WHERE generique_id = v_gen.id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_hors_perimetre',
                              'generique', v_gen.id);
  END IF;

  -- coherence de la recette, quand la reference en declare une
  IF COALESCE(v_ref->>'recette_id','') <> '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.recettes_commerce
                    WHERE id = v_ref->>'recette_id' AND generique_id = v_gen.id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'recette_hors_generique',
                                'recette', v_ref->>'recette_id', 'generique', v_gen.id);
    END IF;
  END IF;

  IF COALESCE(v_ref->>'variante_id','') <> '' THEN
    SELECT v.id, v.libelle INTO v_var_id, v_var_libelle
      FROM public.catalogue_variantes v
     WHERE v.id = v_ref->>'variante_id' AND v.generique_id = v_gen.id;
    IF v_var_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'variante_incoherente');
    END IF;
  END IF;

  -- (b) REVALIDATION DU PRIX avec la formule qui a servi a le fixer
  v_cout := public.fonds_cout_revient_reference(p_fonds_id, p_reference_id);
  IF (v_cout->>'disponible')::boolean IS NOT TRUE THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_de_revient_indisponible',
                              'detail', v_cout);
  END IF;
  IF v_prix > (v_cout->>'prixMaximum')::numeric THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'prix_devenu_hors_plafond',
                              'prix', v_prix, 'maximum', (v_cout->>'prixMaximum')::numeric,
                              'coutUnitaire', (v_cout->>'coutUnitaire')::numeric,
                              'coefficient', (v_cout->>'coefficient')::numeric);
  END IF;

  -- solvabilite
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
  IF v_veut > v_stock THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'stock_insuffisant',
                              'demande', v_veut, 'stock', v_stock);
  END IF;
  v_qte := v_veut;
  v_montant := v_qte * v_prix;
  IF v_arg < v_montant THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'requis', v_montant, 'disponibles', v_arg);
  END IF;

  -- CONSTRUCTION SERVEUR DE L'OBJET. Aucune propriete ne vient du client :
  -- l'identite mecanique sort du referentiel, l'habillage sort de la reference.
  v_destinataire := CASE WHEN left(p_acheteur,3) = 'pj:' THEN substr(p_acheteur,4) ELSE p_acheteur END;
  v_enseigne     := COALESCE(NULLIF(btrim(v_fonds->>'enseigne'), ''), 'Commerce');
  v_objet := jsonb_strip_nulls(jsonb_build_object(
    'type',         p_reference_id,
    'generique_id', v_gen.id,
    'recette_id',   NULLIF(btrim(COALESCE(v_ref->>'recette_id','')), ''),
    'variante_id',  v_var_id,
    'name',         COALESCE(NULLIF(btrim(v_ref->>'nom'), ''),
                             COALESCE(v_var_libelle, v_gen.libelle)),
    'desc',         NULLIF(btrim(v_ref->>'description'), ''),
    'icon',         'ti-package',
    'imageUrl',     NULLIF(btrim(v_ref->>'image'), ''),
    'legal',        CASE WHEN v_gen.regime = 'illegal' THEN false ELSE true END,
    'provenance',   jsonb_build_object(
                      'fondsId',     p_fonds_id,
                      'referenceId', p_reference_id,
                      'createur',    v_fonds->>'proprietaire',
                      'etapes',      '[]'::jsonb)
  ));

  -- LIVRAISON. Identifiants derives de la cle de requete, jamais de l'horloge.
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

  -- ARGENT ET STOCK
  IF NOT public.mouvement_titulaire(p_acheteur, -v_montant) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants');
  END IF;
  v_fonds := jsonb_set(v_fonds, ARRAY['stockReferences', p_reference_id],
               to_jsonb(v_stock - v_qte), true);
  v_fonds := jsonb_set(v_fonds, '{caisse}',
               to_jsonb(GREATEST(0, COALESCE((v_fonds->>'caisse')::numeric, 0)) + v_montant));
  UPDATE public.entreprises SET data = v_fonds, updated_at = now() WHERE id = p_fonds_id;

  -- PREUVE, dans la MEME transaction. La fiche officielle est figee telle qu'elle
  -- etait : c'est la verite mecanique que l'acheteur pouvait consulter.
  v_fiche := public.objet_fiche_officielle(v_livre);
  SELECT jsonb_agg(ty.libelle ORDER BY ty.ordre) INTO v_types
    FROM public.catalogue_generique_type gt
    JOIN public.catalogue_types ty ON ty.id = gt.type_id
   WHERE gt.generique_id = v_gen.id;

  INSERT INTO public.ventes_snapshots
    (requete, jour_paris, acheteur, vendeur, fonds_id, pays,
     reference_id, nom_commercial, description_commerciale,
     generique_id, recette_id, variante_id, famille, types,
     quantite, prix_unitaire, montant_total, fiche_officielle)
  VALUES (p_requete,
     to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD'),
     p_acheteur, v_fonds->>'proprietaire', p_fonds_id, v_fonds->'implantation'->>'country',
     p_reference_id,
     COALESCE(NULLIF(btrim(v_ref->>'nom'), ''), COALESCE(v_var_libelle, v_gen.libelle)),
     NULLIF(btrim(v_ref->>'description'), ''),
     v_gen.id, NULLIF(btrim(COALESCE(v_ref->>'recette_id','')), ''), v_var_id,
     v_acces.famille, v_types,
     v_qte, v_prix, v_montant, v_fiche);

  RETURN jsonb_build_object(
    'ok', true, 'rejeu', false,
    'quantite', v_qte, 'prixUnitaire', v_prix, 'montant', v_montant,
    'stockRestant', v_stock - v_qte,
    'generique_id', v_gen.id, 'recette_id', v_ref->>'recette_id', 'variante_id', v_var_id,
    'livraisons', to_jsonb(v_ids),
    'venteId', (SELECT id FROM public.ventes_snapshots WHERE requete = p_requete));
END;
$$;

comment on function public.acheter_produit_commerce(text,text,text,text,integer) is
  'Achat d''une reference commerciale. Le client ne fournit qu''une intention : cle de requete, acteur, fonds, reference, quantite. Prix, quantite transferable, nature de l''objet et montant sont relus ou construits par le serveur sous verrou. Le prix est REVALIDE contre le plafond du pays au moment de la vente. Paiement, decrement de stock, credit de caisse, livraison et preuve immuable sont dans la meme transaction. Idempotent par ventes_snapshots.requete, garde permanente.';

revoke all on function public.acheter_produit_commerce(text,text,text,text,integer) from public, anon, authenticated;
grant execute on function public.acheter_produit_commerce(text,text,text,text,integer) to authenticated, service_role;