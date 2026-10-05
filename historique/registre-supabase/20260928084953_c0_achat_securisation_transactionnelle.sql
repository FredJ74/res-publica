-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260928084953
-- Nom original      : c0_achat_securisation_transactionnelle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-28 08:49:53 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 81d020aa99c436a0d3375cf6d544228a
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
-- C0 — SECURISATION DU CHEMIN D'ACHAT AVANT LE MOTEUR COMMERCIAL PJ
-- =====================================================================
-- Deux vulnerabilites confirmees sur acheter_produit_commerce, corrigees ici
-- A LA SOURCE TRANSACTIONNELLE, avant toute exposition du nouveau flux d'achat.
--
-- VULNERABILITE A — ARGENT PRIS SANS LIVRAISON
--   L'identifiant de livraison etait granule a la SECONDE :
--     'achat-'||fonds||'-'||reference||'-'||extract(epoch from clock_timestamp())::bigint
--   suivi d'un INSERT ... WHERE NOT EXISTS. Deux achats de la meme reference dans
--   la meme seconde produisaient le MEME identifiant : le debit, le decrement de
--   stock et le credit de caisse s'appliquaient DEUX FOIS, le second INSERT etait
--   silencieusement saute, et la fonction retournait ok:true. Le joueur payait
--   deux fois et recevait une fois.
--
--   CORRECTIF : l'identifiant de livraison derive d'une CLE DE REQUETE fournie par
--   l'appelant, jamais de l'horloge. C'est le patron deja eprouve dans ce depot par
--   tracts_donner_joueur : format contraint, ON CONFLICT DO NOTHING, detection de
--   rejeu. La garde est posee APRES le verrou du fonds et AVANT tout mouvement
--   d'argent : un rejeu ne debite rien, ne decremente rien, ne credite rien.
--
-- VULNERABILITE B — LE CLIENT DECIDAIT DE L'OBJET LIVRE
--   Le parametre p_objet jsonb venait du navigateur. Le serveur en retirait deux
--   champs et ajoutait la provenance, mais la NATURE de l'objet -- son type, son
--   nom, ses proprietes -- etait fournie par le client. Un navigateur modifie
--   pouvait acheter une reference a 10 FR et se faire livrer autre chose.
--
--   CORRECTIF : p_objet EST SUPPRIME DE LA SIGNATURE. Le serveur construit l'objet
--   depuis le referentiel L2, via le generique declare par la reference. Le
--   referentiel devient la source de verite mecanique. Une reference sans generique
--   ne vend rien : fail-closed, jamais d'objet devine.
--
-- L'ANCIENNE SIGNATURE EST SUPPRIMEE, pas seulement remplacee : la laisser en place
-- laisserait le trou grand ouvert. Elle n'avait aucun appelant (verifie par grep
-- exhaustif du depot : seule son enveloppe sbAcheterProduitCommerce existait, elle
-- aussi sans appelant).
--
-- CE QUE CE LOT NE FAIT PAS, DELIBEREMENT :
--   - il n'expose aucun flux d'achat : aucun fonds v2 n'existe, aucune reference
--     n'existe, et aucune interface n'appelle cette RPC ;
--   - il ne cree AUCUNE table. La preuve d'achat immuable (snapshot) releve de C4 :
--     une table de preuve sans ecrivain ni lecteur reel serait dormante ;
--   - il ne decide d'aucun mode de commercialisation. Un generique de bien consomme
--     sur place (boisson, encas, plats, menu gastronomique : 5 cas en base) ne
--     declare aucun regime d'objet ; la RPC refuse alors explicitement au lieu
--     d'inventer une livraison.

-- ---------------------------------------------------------------------------
-- 1. LE REFERENTIEL PEUT DESORMAIS ETRE DESIGNE DIRECTEMENT PAR UN OBJET
-- ---------------------------------------------------------------------------
-- Un objet produit par un commerce PJ ne releve d'AUCUNE correspondance legacy :
-- son identite mecanique est posee par le serveur au moment de la vente. Il porte
-- donc directement generique_id (et variante_id le cas echeant), et le resolveur
-- doit l'honorer -- sans quoi l'estampille serait inerte et la fiche officielle
-- resterait muette sur tout produit neuf.
--
-- INERTIE PROUVEE POUR L'EXISTANT : aucun objet d'inventaire, aucune ligne de sas,
-- aucun objet au sol ne porte aujourd'hui generique_id ni variante_id (mesure du
-- 28 septembre 2026 : 0 sur 4 objets d'inventaire, 0 sur 6 lignes de sas). La
-- branche ajoutee ne peut donc modifier la resolution d'aucun objet existant.
--
-- LIMITE CONNUE, ANTERIEURE A CE LOT : l'inventaire reste reecrivable par le
-- client (verrou rp_transitions.argent_verrou a false). Un joueur peut donc forger
-- generique_id sur SON objet et fausser SA fiche. Cela ne lui accorde aucun effet
-- mecanique -- les effets viennent de effets_effectifs des correspondances, et un
-- generique neuf les a a NULL. Le trou d'inventaire est un chantier distinct.
create or replace function public.generique_de_objet(p_objet jsonb)
returns table (generique_id text, variante_id text, effets_effectifs jsonb,
               motif text, valeur text, priorite int)
language sql stable
as $$
  with direct as (
    -- Designation DIRECTE par le referentiel. Priorite maximale : quand le serveur
    -- a lui-meme pose l'identite mecanique, aucune cle legacy n'a a la deviner.
    select g.id                                  as generique_id,
           (select v.id from public.catalogue_variantes v
             where v.id = p_objet->>'variante_id' and v.generique_id = g.id) as variante_id,
           null::jsonb                           as effets_effectifs,
           'generique_id'::text                  as motif,
           g.id                                  as valeur,
           1000                                  as priorite,
           0::bigint                             as ordre
      from public.catalogue_generiques g
     where g.id = p_objet->>'generique_id'
  ),
  cand(motif, valeur) as (
    select 'type_originequete', (p_objet->>'type') || '|' || (p_objet->>'origineQuete')
      where p_objet->>'type' is not null and p_objet->>'origineQuete' is not null
    union all
    select 'type_produit_militaire', (p_objet->>'type') || '|' || (p_objet->>'produitMilitaire')
      where p_objet->>'type' is not null and p_objet->>'produitMilitaire' is not null
    union all
    select 'produit_militaire', p_objet->>'produitMilitaire'
      where p_objet->>'produitMilitaire' is not null
    union all
    select 'type_tracttype', (p_objet->>'type') || '|' || (p_objet->>'tractType')
      where p_objet->>'type' is not null and p_objet->>'tractType' is not null
    union all
    select 'famille_produit_marche', p_objet->>'familleProduitMarche'
      where p_objet->>'familleProduitMarche' is not null
    union all
    select 'type_soustype', (p_objet->>'type') || '|' || (p_objet->>'sousType')
      where p_objet->>'type' is not null and p_objet->>'sousType' is not null
    union all
    select 'recette_id', p_objet->>'type'
      where p_objet->>'type' is not null
    union all
    select 'stack_key', p_objet->>'stackKey'
      where p_objet->>'stackKey' is not null
    union all
    select 'type', p_objet->>'type'
      where p_objet->>'type' is not null
  ),
  legacy as (
    select c.generique_id, c.variante_id, c.effets_effectifs, c.motif, c.valeur,
           c.priorite, c.id as ordre
      from cand
      join public.catalogue_correspondance_legacy c
        on c.motif = cand.motif and c.valeur = cand.valeur
  ),
  tout as (select * from direct union all select * from legacy)
  select t.generique_id, t.variante_id, t.effets_effectifs, t.motif, t.valeur, t.priorite
    from tout t
   order by t.priorite desc, t.ordre asc
   limit 1;
$$;

comment on function public.generique_de_objet(jsonb) is
  'Resolveur de referentiel. Lecture seule, aucun effet de bord. Honore d''abord une designation directe (generique_id pose par le serveur), puis les correspondances legacy par priorite. Rend 0 ligne lorsque aucun generique ne peut etre determine : un objet non resoluble doit rendre NULL, jamais une valeur devinee.';

revoke all on function public.generique_de_objet(jsonb) from anon, authenticated;
grant execute on function public.generique_de_objet(jsonb) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. SUPPRESSION DE LA SIGNATURE VULNERABLE
-- ---------------------------------------------------------------------------
drop function if exists public.acheter_produit_commerce(text, text, text, integer, jsonb);

-- ---------------------------------------------------------------------------
-- 3. ACHAT SECURISE
-- ---------------------------------------------------------------------------
-- ORDRE DES OPERATIONS, ET IL EST LA GARANTIE :
--   1. attestation d'acteur         -- exception, donc annule tout
--   2. format de la cle de requete  -- refus avant toute lecture
--   3. VERROU du fonds (FOR UPDATE) -- serialise les appels concurrents
--   4. lecture du prix et du stock  -- relus en base, jamais crus du client
--   5. resolution du generique L2   -- la nature de l'objet vient d'ici
--   6. calcul de la quantite reelle -- bornee par stock ET par les fonds
--   7. GARDE DE REJEU               -- sous verrou, AVANT tout mouvement
--   8. livraison au sas             -- ids derives de la cle, jamais de l'horloge
--   9. argent, stock, caisse        -- une seule transaction avec la livraison
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
  v_ids         text[] := '{}';
  v_id          text;
  v_destinataire text;
  v_enseigne    text;
  i             integer;
BEGIN
  -- 1. identite
  PERFORM public.exiger_acteur(p_acheteur);

  -- 2. cle de requete : meme discipline que tracts_donner_joueur
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

  -- 3. verrou du fonds
  SELECT data INTO v_fonds FROM public.entreprises WHERE id = p_fonds_id FOR UPDATE;
  IF v_fonds IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_absent');
  END IF;
  IF COALESCE(v_fonds->>'statut','actif') <> 'actif' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_inactif');
  END IF;

  -- 4. prix et stock relus en base
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

  -- 5. NATURE DE L'OBJET : referentiel L2, jamais le client
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
  -- Un service ne produit jamais d'objet d'inventaire. Sa remise releve d'un lot
  -- ulterieur (prestations) : on refuse plutot que d'inventer une livraison.
  IF v_gen.est_service THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'generique_est_un_service');
  END IF;
  -- Un bien consomme sur place ne declare aucun regime d'objet. Le mode de
  -- commercialisation (sur place / a emporter) n'est pas arbitre : on refuse.
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

  -- 6. quantite reellement transferable
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

  -- 7. GARDE DE REJEU, sous verrou, avant tout mouvement d'argent.
  -- La cle ne contient que [A-Za-z0-9-] : aucun joker LIKE possible.
  IF EXISTS (SELECT 1 FROM public.objets_recus
              WHERE id = p_requete OR id LIKE p_requete || '-%') THEN
    RETURN jsonb_build_object('ok', true, 'rejeu', true, 'raison', 'requete_deja_honoree');
  END IF;

  -- 8. livraison au sas. Identifiants DERIVES DE LA CLE, jamais de l'horloge.
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
      INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
      VALUES (v_id, v_destinataire, v_enseigne,
              (v_objet
                || jsonb_build_object('qty', 1)
                || CASE WHEN v_gen.encombrement IS NOT NULL
                        THEN jsonb_build_object('encombrement', v_gen.encombrement)
                        ELSE '{}'::jsonb END
                || jsonb_build_object('exemplaire',
                     jsonb_build_object('id', v_id)))::text)
      ON CONFLICT (id) DO NOTHING;
      v_ids := v_ids || v_id;
    END LOOP;
  ELSE
    v_id := p_requete;
    INSERT INTO public.objets_recus (id, destinataire, expediteur, data)
    VALUES (v_id, v_destinataire, v_enseigne,
            (v_objet || jsonb_build_object(
               'stackable', true,
               'stackKey',  p_reference_id,
               'qty',       v_qte))::text)
    ON CONFLICT (id) DO NOTHING;
    v_ids := v_ids || v_id;
  END IF;

  -- 9. argent, stock, caisse -- meme transaction que la livraison
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

comment on function public.acheter_produit_commerce(text,text,text,text,integer) is
  'Achat d''une reference commerciale. Le client ne decide NI du prix, NI de la quantite, NI de la nature de l''objet livre : tout est relu en base sous verrou, et l''objet est construit depuis le referentiel L2 via le generique de la reference. La cle de requete p_requete rend l''appel idempotent : un rejeu ne debite rien. Aucun objet n''est jamais devine -- une reference sans generique ne vend pas.';

revoke all on function public.acheter_produit_commerce(text,text,text,text,integer) from public, anon, authenticated;
grant execute on function public.acheter_produit_commerce(text,text,text,text,integer) to authenticated, service_role;