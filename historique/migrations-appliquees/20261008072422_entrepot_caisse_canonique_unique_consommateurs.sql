-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 8 OCTOBRE 2026
--
-- Registre Supabase : version 20261008072422, nom
-- `entrepot_caisse_canonique_unique_consommateurs`.
--
-- LE CORPS CI-DESSOUS EST EXACTEMENT CELUI QUI A TOURNE, relu dans
-- supabase_migrations.schema_migrations apres application : md5
-- bd7bd71983a20c575abe01c1c2a5c4d8 pour 24 472 octets.
--
-- POURQUOI UNE SECONDE MIGRATION LE MEME JOUR. La premiere avait deplace la tresorerie des
-- entrepots vers une caisse canonique, mais CINQ consommateurs lisaient encore le blob. Les
-- laisser en place aurait reconstitue une seconde bourse en une nuit -- et l'un d'eux,
-- l'approvisionnement de chantier du cron, aurait ECRIT `caisse: 0 + depense`, c'est-a-dire
-- recree la cle avec de l'argent dedans : de la creation monetaire, chaque nuit, en silence.
--
-- UN DEFAUT DE FOND TROUVE EN BALAYANT CES CONSOMMATEURS. entrepot_reverser derivait la ville
-- par `split_part(id, '_', 2)`, ce qui rend « ville » et non « ville_a » : le reversement d'un
-- entrepot vers sa mairie n'avait JAMAIS pu fonctionner ailleurs qu'a la capitale, depuis sa
-- creation le 20 septembre 2026. Personne ne l'avait vu parce qu'aucun appelant ne l'invoquait --
-- le defaut dormait derriere l'absence d'interface. La regle de nommage est desormais declaree
-- dans entrepot_caisse_id(), qui lit les colonnes `country` et `city` de batiments_etat, lesquelles
-- font autorite et qu'aucune heuristique de chaine ne peut contredire.
--
-- SES PROPRES PREUVES, verifiees dans la transaction : plus aucune fonction SQL ne lit la
-- tresorerie dans le blob ; entrepot_caisse_id rend bien `republic_entrepot_ville_a` pour
-- Port-Sainte-Marie ; une ville de TEST ne se voit attribuer aucune caisse canonique ; et la
-- lecture de Montrouge rend 4 927,5 FR.
-- =============================================================================

-- =============================================================================
-- LA CAISSE D'ENTREPOT N'A PLUS QU'UN SEUL MAGASIN -- TOUS SES CONSOMMATEURS SUIVENT
-- Chantier Supabase -- budgets municipaux, second temps -- 8 octobre 2026
-- =============================================================================
--
-- La migration precedente a deplace la tresorerie des trois entrepots de Republia depuis
-- batiments_etat.data.entrepot.caisse vers caisses_batiments.<pays>_entrepot_<ville>. Mais CINQ
-- consommateurs lisaient encore le blob, et les laisser en place aurait reconstitue une seconde
-- bourse en une nuit :
--
--   . entrepot_caisse_lire()  -- lecture generique
--   . entrepot_commander()    -- l'achat : debit du destinataire, credit du fournisseur
--   . entrepot_reverser()     -- deja repointe par la migration precedente, mais sur une regle
--                                de derivation FAUSSE (voir plus bas)
--   . api/cron-minuit.js, approvisionnement de chantier -- ecrivait `caisse: 0 + depense`, ce qui
--                                aurait RECREE la cle du blob avec de l'argent dedans, c'est-a-dire
--                                CREE de la monnaie. Corrige dans le meme commit, cote JS.
--   . api/cron-minuit.js, livraisons d'entrepot -- lisait et reecrivait la cle. Idem.
--
-- -----------------------------------------------------------------------------
-- UN DEFAUT DE FOND, TROUVE EN BALAYANT CES CONSOMMATEURS
-- -----------------------------------------------------------------------------
-- entrepot_reverser derivait le pays et la ville par `split_part(p_entrepot_id, '_', 2)`. Or
-- l'identifiant d'un entrepot est <pays>_<ville>_<batiment> et DEUX VILLES SUR TROIS portent un
-- souligne : sur `republic_ville_a_entrepot-logistique-psm`, cette expression rend « ville », pas
-- « ville_a ». La mairie destinataire etait donc introuvable, et la fonction refusait.
--
-- Autrement dit : le reversement d'entrepot n'a JAMAIS pu fonctionner ailleurs qu'a la capitale,
-- depuis sa creation le 20 septembre 2026. Personne ne s'en etait aperçu parce qu'aucun appelant
-- ne l'invoquait -- le defaut dormait derriere l'absence d'interface.
--
-- LA REGLE DEVIENT DECLAREE AU LIEU D'ETRE DEVINEE. batiments_etat porte deja les colonnes
-- `country` et `city` : elles font autorite, et aucune heuristique de chaine ne peut les
-- contredire. entrepot_caisse_id() est desormais le SEUL endroit qui sait composer l'identifiant
-- d'une caisse d'entrepot, et il le lit dans ces colonnes.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. UNE SEULE REGLE POUR NOMMER LA CAISSE D'UN ENTREPOT
-- -----------------------------------------------------------------------------
-- Rend NULL si le batiment n'existe pas, ou si sa ville n'est pas une VRAIE ville : les entrepots
-- de test (zzville-a, zzville-b, pays zztest) n'ont pas de caisse canonique, et leur tresorerie
-- est restee dans leur blob. Un NULL est une reponse, pas un accident -- l'appelant doit refuser.
CREATE OR REPLACE FUNCTION public.entrepot_caisse_id(p_entrepot_id text)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT e.country || '_entrepot_' || e.city
    FROM public.batiments_etat e
    JOIN public.villes v ON v.pays = e.country AND v.ville = e.city
   WHERE e.id = p_entrepot_id;
$function$;

COMMENT ON FUNCTION public.entrepot_caisse_id(text) IS
  'SEULE regle qui compose l''identifiant de la caisse canonique d''un entrepot, a partir des colonnes country et city de batiments_etat -- qui font autorite. Ne jamais la rederiver par split_part sur l''identifiant : deux villes sur trois portent un souligne, et `split_part(id, ''_'', 2)` rend « ville » au lieu de « ville_a ». Rend NULL pour une ville qui n''est pas dans le referentiel.';

REVOKE ALL ON FUNCTION public.entrepot_caisse_id(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.entrepot_caisse_id(text) FROM anon;
REVOKE ALL ON FUNCTION public.entrepot_caisse_id(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.entrepot_caisse_id(text) TO service_role;

-- -----------------------------------------------------------------------------
-- 2. LA LECTURE GENERIQUE SUIT LA CAISSE
-- -----------------------------------------------------------------------------
-- Meme signature, meme contrat -- un numeric, zero par defaut -- mais la source change. Tous ses
-- lecteurs suivent sans etre touches.
CREATE OR REPLACE FUNCTION public.entrepot_caisse_lire(p_id text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((SELECT CASE WHEN jsonb_typeof(c.data -> 'solde') = 'number'
                               THEN (c.data ->> 'solde')::numeric ELSE 0 END
                     FROM public.caisses_batiments c
                    WHERE c.id = public.entrepot_caisse_id(p_id)), 0);
$function$;

-- -----------------------------------------------------------------------------
-- 3. LE MOUVEMENT DE CAISSE D'UN ENTREPOT, POUR LE SERVEUR
-- -----------------------------------------------------------------------------
-- Le cron de minuit ecrivait la caisse en reecrivant le blob entier depuis JavaScript. Il passe
-- par ici : une seule porte, verrouillee, qui ne descend jamais sous zero et qui refuse une ville
-- sans caisse canonique au lieu de fabriquer la cle.
CREATE OR REPLACE FUNCTION public.entrepot_caisse_mouvement(p_entrepot_id text, p_delta numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_caisse text; v_rep jsonb;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF p_delta IS NULL OR p_delta = 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'delta_nul');
  END IF;
  v_caisse := public.entrepot_caisse_id(p_entrepot_id);
  IF v_caisse IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree',
                              'entrepot', p_entrepot_id);
  END IF;
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse, p_delta, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_rep->>'raison', 'mouvement_refuse'),
                              'caisse', v_caisse);
  END IF;
  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse, 'delta', p_delta,
                            'solde', (v_rep->>'solde')::numeric);
END;
$function$;

COMMENT ON FUNCTION public.entrepot_caisse_mouvement(text, numeric) IS
  'Mouvement de la caisse canonique d''un entrepot, RESERVE AU SERVEUR. Remplace les reecritures du blob par le cron de minuit. Jamais de solde negatif -- caisse_institution_mouvement refuse -- et une ville sans caisse declaree est refusee au lieu de voir la cle fabriquee.';

REVOKE ALL ON FUNCTION public.entrepot_caisse_mouvement(text, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.entrepot_caisse_mouvement(text, numeric) FROM anon;
REVOKE ALL ON FUNCTION public.entrepot_caisse_mouvement(text, numeric) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.entrepot_caisse_mouvement(text, numeric) TO service_role;

-- -----------------------------------------------------------------------------
-- 4. LE REVERSEMENT CESSE DE DEVINER SA VILLE
-- -----------------------------------------------------------------------------
-- Pays et ville viennent des colonnes de batiments_etat, et la caisse de entrepot_caisse_id().
-- L'autorite de entrepot_virement_mairie ne change pas : directeur de CET entrepot, dans SA
-- ville, ni le maire ni son adjoint. Le directeur n'acquiert aucun pouvoir sur les taux
-- municipaux -- il ne deplace que sa propre tresorerie.
CREATE OR REPLACE FUNCTION public.entrepot_reverser(p_entrepot_id text, p_montant numeric, p_mode text, p_acteur text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c_roulement constant numeric := 5000;   -- fonds de roulement permanent (regle GD)
  v_pays text; v_ville text; v_caisse_id text; v_caisse numeric;
  v_mairie text; v_verse numeric; v_jour date; v_id text; v_rep jsonb;
BEGIN
  -- LES COLONNES FONT AUTORITE. Voir l'en-tete de cette migration : la derivation par
  -- split_part rendait « ville » au lieu de « ville_a », et le reversement etait donc
  -- impossible ailleurs qu'a la capitale.
  SELECT e.country, e.city INTO v_pays, v_ville
    FROM public.batiments_etat e WHERE e.id = p_entrepot_id;
  IF v_pays IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable');
  END IF;

  v_caisse_id := public.entrepot_caisse_id(p_entrepot_id);
  IF v_caisse_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree',
                              'ville', v_ville);
  END IF;

  -- Verrou de ligne : deux reversements simultanes se serialisent.
  SELECT CASE WHEN jsonb_typeof(c.data -> 'solde') = 'number'
              THEN (c.data ->> 'solde')::numeric ELSE 0 END
    INTO v_caisse
    FROM public.caisses_batiments c WHERE c.id = v_caisse_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree',
                              'caisse', v_caisse_id);
  END IF;

  v_mairie := public.salaire_caisse_de('maire', v_pays, v_ville);
  IF v_mairie IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mairie_introuvable', 'ville', v_ville);
  END IF;

  IF p_mode = 'automatique' THEN
    v_verse := greatest(0, v_caisse - c_roulement);
  ELSE
    -- Virement volontaire : borne par la tresorerie REELLE, jamais par ce que
    -- le client annonce.
    v_verse := least(greatest(coalesce(p_montant, 0), 0), greatest(v_caisse, 0));
  END IF;

  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', true, 'verse', 0, 'caisse', v_caisse,
                              'roulement', c_roulement);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id := p_entrepot_id || ':' || v_jour::text ||
          CASE WHEN p_mode = 'volontaire'
               THEN ':v' || (extract(epoch from clock_timestamp())*1000)::bigint
               ELSE '' END;

  -- L'anti-rejeu EST la cle : un reversement automatique deja fait aujourd'hui
  -- ne peut pas etre rejoue, meme par deux crons concurrents.
  BEGIN
    INSERT INTO public.entrepots_reversements (id, entrepot_id, mairie_id, jour, montant, mode, acteur)
    VALUES (v_id, p_entrepot_id, v_mairie, v_jour, v_verse, p_mode, p_acteur);
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_reverse_aujourdhui',
                              'jour', v_jour, 'caisse', v_caisse);
  END;

  -- DEBIT DE L'ENTREPOT PUIS CREDIT DE LA MAIRIE, par la primitive verrouillee. Si le credit
  -- echouait, la levee annule le debit : la transaction est la frontiere.
  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse_id, -v_verse, true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    PERFORM set_config('rp.caisse_interne', '', true);
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_rep->>'raison','debit_refuse'));
  END IF;
  v_rep := public.caisse_institution_mouvement(v_mairie, v_verse, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'reversement_entrepot_credit_refuse:%', coalesce(v_rep->>'raison','?');
  END IF;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'mairie', v_mairie,
                            'caisse', v_caisse - v_verse, 'mode', p_mode, 'jour', v_jour);
END;
$function$;

-- -----------------------------------------------------------------------------
-- 5. L'ACHAT D'ENTREPOT PAIE DEPUIS LA CAISSE, ET ENCAISSE DANS LA CAISSE
-- -----------------------------------------------------------------------------
-- Tout le reste de entrepot_commander est repris A L'IDENTIQUE depuis pg_get_functiondef :
-- verrouillage ordonne des lignes, capacite, embargo, fret, transits, journal. Seuls les trois
-- mouvements d'argent changent de magasin :
--   . le DEBIT du destinataire -- l'UPDATE du blob qui ne portait que la caisse disparait ;
--   . le CREDIT du fournisseur quand c'est un autre entrepot -- son blob ne garde que le stock ;
--   . la lecture de tresorerie, qui passe par entrepot_caisse_lire().
-- Le produit de la vente du Port continuait deja d'aller a sa caisse institutionnelle : rien a
-- changer de ce cote, et c'est d'ailleurs le motif qu'on generalise ici.
CREATE OR REPLACE FUNCTION public.entrepot_commander(p_acteur text, p_ressource text, p_quantite integer, p_fournisseur_type text, p_fournisseur_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_dest_id text; v_dest_ville text;
  v_prix numeric; v_fret numeric := 0; v_total numeric;
  v_cap integer; v_delai integer; v_libelle text;
  v_etat_d jsonb; v_ent_d jsonb; v_caisse_d numeric;
  v_etat_f jsonb; v_ent_f jsonb; v_caisse_f numeric; v_stock_f numeric;
  v_ids text[]; v_i text; v_arrivee date;
  v_caisse_dest_id text; v_caisse_four_id text; v_rep jsonb;
BEGIN
  PERFORM set_config('rp.caisse_interne', 'on', true);
  PERFORM public.exiger_acteur(p_acteur);

  IF p_quantite IS NULL OR p_quantite <= 0 OR p_quantite <> floor(p_quantite) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'quantite_invalide');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ressources_economie WHERE cle = p_ressource) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'ressource_inconnue');
  END IF;

  SELECT entrepot_id, ville INTO v_dest_id, v_dest_ville
    FROM public.entrepot_du_directeur(p_acteur);
  IF v_dest_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'poste_non_detenu');
  END IF;
  IF p_fournisseur_type = 'entrepot' AND p_fournisseur_id = v_dest_id THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_est_soi_meme');
  END IF;

  -- LA CAISSE CANONIQUE DU DESTINATAIRE. Fail-closed : un entrepot sans caisse declaree -- une
  -- ville de test -- ne commande rien, au lieu de voir sa cle fabriquee dans un blob.
  v_caisse_dest_id := public.entrepot_caisse_id(v_dest_id);
  IF v_caisse_dest_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_entrepot_non_declaree',
                              'entrepot', v_dest_id);
  END IF;

  -- --- Verrouillage ordonne des lignes touchees --------------------------------
  v_ids := CASE WHEN p_fournisseur_type IN ('entrepot', 'port')
                THEN ARRAY(SELECT unnest(ARRAY[v_dest_id, p_fournisseur_id]) ORDER BY 1)
                ELSE ARRAY[v_dest_id] END;
  FOREACH v_i IN ARRAY v_ids LOOP
    PERFORM 1 FROM public.batiments_etat WHERE id = v_i FOR UPDATE;
  END LOOP;

  SELECT public.batiment_etat_lire(data) INTO v_etat_d FROM public.batiments_etat WHERE id = v_dest_id;
  IF v_etat_d IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable'); END IF;
  v_ent_d := coalesce(v_etat_d->'entrepot', '{}'::jsonb);
  v_caisse_d := public.entrepot_caisse_lire(v_dest_id);

  -- --- Le fournisseur : prix, stock, delai, libelle -----------------------------
  IF p_fournisseur_type IN ('entrepot', 'port') THEN
    v_delai := 1;
    SELECT public.batiment_etat_lire(data) INTO v_etat_f FROM public.batiments_etat WHERE id = p_fournisseur_id;
    IF v_etat_f IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_introuvable'); END IF;

    IF p_fournisseur_type = 'entrepot' THEN
      v_ent_f := coalesce(v_etat_f->'entrepot', '{}'::jsonb);
      v_stock_f := coalesce((v_ent_f->'stock'->>p_ressource)::numeric, 0);
      -- Prix AFFICHE par le fournisseur : son prix manuel s'il en a pose un, sinon le prix de
      -- reference. Le vendeur ne peut pas refuser : s'il affiche, il vend.
      v_prix := coalesce((v_ent_f->'prixManuel'->>p_ressource)::numeric,
                         (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource));
      v_caisse_four_id := public.entrepot_caisse_id(p_fournisseur_id);
      IF v_caisse_four_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'raison', 'caisse_fournisseur_non_declaree',
                                  'entrepot', p_fournisseur_id);
      END IF;
    ELSE
      -- Port industriel : son stock institutionnel en attente de repartition, au prix de reference.
      v_ent_f := coalesce(v_etat_f->'port', '{}'::jsonb);
      v_stock_f := coalesce((v_ent_f->'stock'->>p_ressource)::numeric, 0);
      v_prix := (SELECT prix_base FROM public.ressources_economie WHERE cle = p_ressource);
    END IF;

    IF v_stock_f < p_quantite THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'stock_fournisseur_insuffisant',
                                'disponible', v_stock_f);
    END IF;
    v_libelle := p_fournisseur_id;
  ELSIF p_fournisseur_type = 'etranger' THEN
    v_delai := 2;
    SELECT prix_unitaire, libelle INTO v_prix, v_libelle
      FROM public.fournisseurs_etrangers()
     WHERE pays = p_fournisseur_id AND ressource = p_ressource;
    IF v_prix IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_introuvable');
    END IF;
    -- EMBARGO : seules les NOUVELLES commandes sont interdites. Ce qui est deja paye et en
    -- transit poursuit sa route -- aucun effet retroactif.
    IF public.embargo_actif('republic', p_fournisseur_id) THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'embargo', 'pays', p_fournisseur_id);
    END IF;
    v_fret := public.fret_unitaire_international();
  ELSE
    RETURN jsonb_build_object('ok', false, 'raison', 'fournisseur_type_inconnu');
  END IF;

  -- --- Capacite du destinataire, transit compris --------------------------------
  v_cap := public.entrepot_capacite_disponible(v_dest_id, p_ressource);
  IF v_cap < p_quantite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'capacite_insuffisante',
                              'capacite_disponible', v_cap, 'plafond', public.capacite_entrepot());
  END IF;

  -- --- Tresorerie ---------------------------------------------------------------
  v_total := round(p_quantite * (v_prix + v_fret), 2);
  IF v_caisse_d < v_total THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'tresorerie_insuffisante',
                              'caisse', v_caisse_d, 'montant', v_total);
  END IF;

  -- --- Mouvements : tout ou rien -------------------------------------------------
  -- LE DEBIT PASSE PAR LA PRIMITIVE VERROUILLEE. L'UPDATE du blob qui ne portait que la caisse
  -- disparait : le blob ne contient plus de tresorerie.
  v_rep := public.caisse_institution_mouvement(v_caisse_dest_id, -v_total, true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', coalesce(v_rep->>'raison', 'debit_refuse'),
                              'caisse', v_caisse_d, 'montant', v_total);
  END IF;

  IF p_fournisseur_type IN ('entrepot', 'port') THEN
    -- Le stock part immediatement de chez le fournisseur : il ne peut pas etre vendu deux fois.
    -- Le fret n'est PAS verse au vendeur -- c'est un cout logistique absorbe.
    IF p_fournisseur_type = 'entrepot' THEN
      v_caisse_f := public.entrepot_caisse_lire(p_fournisseur_id);
      -- Le blob du fournisseur ne garde que son STOCK : sa recette va a sa caisse.
      v_ent_f := v_ent_f
        || jsonb_build_object('stock', jsonb_set(coalesce(v_ent_f->'stock', '{}'::jsonb),
                                                 ARRAY[p_ressource], to_jsonb(v_stock_f - p_quantite)));
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat_f || jsonb_build_object('entrepot', v_ent_f))::text),
             updated_at = now()
       WHERE id = p_fournisseur_id;
      PERFORM public.caisse_institution_mouvement(v_caisse_four_id,
                                                  round(p_quantite * v_prix, 2), true);
    ELSE
      v_ent_f := v_ent_f
        || jsonb_build_object('stock', jsonb_set(coalesce(v_ent_f->'stock', '{}'::jsonb),
                                                 ARRAY[p_ressource], to_jsonb(v_stock_f - p_quantite)));
      UPDATE public.batiments_etat
         SET data = to_jsonb((v_etat_f || jsonb_build_object('port', v_ent_f))::text),
             updated_at = now()
       WHERE id = p_fournisseur_id;
      -- Le produit de la vente du Port va a SA caisse institutionnelle, la ou vont deja ses
      -- autres recettes (criee, dedouanement).
      PERFORM public.caisse_institution_mouvement('republic_port-sainte-marie',
                                                  round(p_quantite * v_prix, 2), false);
    END IF;
  END IF;

  v_arrivee := ((now() AT TIME ZONE 'utc')::date + v_delai);
  INSERT INTO public.entrepot_transits (destination_id, ressource, quantite, origine_type,
    origine_id, origine_libelle, prix_unitaire, fret_unitaire, montant_total, arrivee_le, commande_par)
  VALUES (v_dest_id, p_ressource, p_quantite, p_fournisseur_type,
    CASE WHEN p_fournisseur_type = 'etranger' THEN NULL ELSE p_fournisseur_id END,
    v_libelle, v_prix, v_fret, v_total, v_arrivee, p_acteur);

  INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
    quantite, prix_unitaire, fret_unitaire, montant, statut, arrivee_le, acteur)
  VALUES (v_dest_id, 'commande_directe', 'entree', v_libelle, p_ressource,
    p_quantite, v_prix, v_fret, v_total, 'en_transit', v_arrivee, p_acteur);

  IF p_fournisseur_type = 'entrepot' THEN
    INSERT INTO public.entrepot_journal (entrepot_id, operation, sens, contrepartie, ressource,
      quantite, prix_unitaire, fret_unitaire, montant, statut, acteur)
    VALUES (p_fournisseur_id, 'commande_directe', 'sortie', v_dest_id, p_ressource,
      p_quantite, v_prix, 0, round(p_quantite * v_prix, 2), 'comptant', p_acteur);
  END IF;

  RETURN jsonb_build_object('ok', true, 'ressource', p_ressource, 'quantite', p_quantite,
    'prix_unitaire', v_prix, 'fret_unitaire', v_fret, 'montant', v_total,
    'arrivee_le', v_arrivee, 'delai_jours', v_delai,
    'caisse', round(v_caisse_d - v_total, 2), 'fournisseur', v_libelle);
END; $function$;

-- -----------------------------------------------------------------------------
-- 6. LA PREUVE : PLUS AUCUNE FONCTION SQL NE LIT LA TRESORERIE DANS LE BLOB
-- -----------------------------------------------------------------------------
DO $$
DECLARE v_coupables text;
BEGIN
  SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_coupables
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prosrc LIKE '%entrepot%caisse%'
     AND (p.prosrc LIKE '%''{entrepot,caisse}''%'
          OR p.prosrc LIKE '%-> ''entrepot'' -> ''caisse''%'
          OR p.prosrc LIKE '%->''entrepot''->''caisse''%');
  IF v_coupables IS NOT NULL THEN
    RAISE EXCEPTION 'PREUVE ECHOUEE -- ces fonctions lisent encore la tresorerie dans le blob : %', v_coupables;
  END IF;

  -- Et la regle de nommage rend bien la ville complete, y compris pour les deux villes dont
  -- l'identifiant porte un souligne. C'est le defaut corrige par cette migration.
  IF public.entrepot_caisse_id('republic_ville_a_entrepot-logistique-psm')
       IS DISTINCT FROM 'republic_entrepot_ville_a' THEN
    RAISE EXCEPTION 'PREUVE ECHOUEE -- entrepot_caisse_id rend % pour Port-Sainte-Marie',
      public.entrepot_caisse_id('republic_ville_a_entrepot-logistique-psm');
  END IF;
  IF public.entrepot_caisse_id('republic_zzville-a_entrepot-zztest-a') IS NOT NULL THEN
    RAISE EXCEPTION 'PREUVE ECHOUEE -- une ville de test s''est vu attribuer une caisse canonique';
  END IF;
  IF public.entrepot_caisse_lire('republic_ville_b_entrepot-logistique-montrouge') <> 4927.5 THEN
    RAISE EXCEPTION 'PREUVE ECHOUEE -- la lecture de Montrouge rend % au lieu de 4927.5',
      public.entrepot_caisse_lire('republic_ville_b_entrepot-logistique-montrouge');
  END IF;
END $$;
