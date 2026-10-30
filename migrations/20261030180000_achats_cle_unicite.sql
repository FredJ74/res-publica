-- =============================================================================
-- ACHATS : UNE CLE D'UNICITE SERVEUR (Claude, 30 octobre 2026, cloture Luthecia)
-- =============================================================================
-- Defaut : neuf achats (et une vente) n'avaient aucune cle. Apres une reponse
-- perdue, la seconde tentative manuelle du joueur etait un NOUVEL achat : il
-- payait deux fois et recevait deux fois. A l'Entrepot, a la Criee et en vente
-- directe d'usine, les PA etaient en outre preleves par un appel separe, avant
-- l'achat : meme protege, l'achat refait aurait refait payer les PA.
--
-- Remede, sans inventaire parallele : la primitive deja en service pour les
-- receptions d'inventaire (club_accessoire_acheter, sels_ammoniaque_acheter) :
--   * registre public.inventaire_actions_recus (cle acteur + requete) ;
--   * public.inventaire_action_rejouer_interne (rejeu : meme resultat, inventaire
--     et soldes relus ; meme cle avec d'autres parametres -> requete_reutilisee).
-- Chaque achat recoit une nouvelle signature, avec p_requete uuid en tete, qui :
--   1. verrouille la cle (verrou consultatif : deux envois simultanes de la meme
--      cle s'executent l'un apres l'autre, le second rejoue le premier) ;
--   2. rejoue si la cle est deja enregistree ;
--   3. sinon execute, dans une sous-transaction, le paiement des PA quand il etait
--      separe, puis l'achat existant (corps inchange) ;
--   4. tout refus (ok <> true) annule la sous-transaction : aucune mutation
--      partielle, rien d'enregistre, le joueur peut reessayer ;
--   5. une reussite est enregistree avec la cle et rendue avec l'inventaire, sa
--      revision et les soldes relus (contrat de executerReceptionInventaire).
-- Les anciennes signatures restent executables tant que l'ecran publie les
-- appelle : migration 20261030180100 apres deploiement de l'ecran.
-- commerce_acheter_matiere (relais historique sans appelant, cle aleatoire) est
-- ferme par 20261030180100 ; assemblee_achat_illegal a deja sa propre cle.
-- =============================================================================

-- Ouvre une cle : verrou, puis rejeu eventuel. NULL = premiere execution.
CREATE OR REPLACE FUNCTION public.achat_requete_ouvrir_interne(
  p_acteur text, p_requete uuid, p_action text, p_parametres jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF p_acteur IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  IF p_requete IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'requete_invalide'); END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('inventaire_action:' || p_acteur || ':' || p_requete::text, 0));
  RETURN public.inventaire_action_rejouer_interne(p_acteur, p_requete, p_action, p_parametres);
END; $$;

-- Clot une reussite : enregistre le resultat sous la cle, rend l'etat relu.
CREATE OR REPLACE FUNCTION public.achat_requete_clore_interne(
  p_acteur text, p_requete uuid, p_action text, p_parametres jsonb, p_resultat jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE d record;
BEGIN
  INSERT INTO public.inventaire_actions_recus(acteur, requete, action, parametres, resultat, cree_le)
  VALUES (p_acteur, p_requete, p_action, p_parametres, p_resultat - 'inventory', now());
  SELECT inventory, inventory_revision, pa, liquide, arg INTO d FROM public.personnages_donnees WHERE name = p_acteur;
  RETURN p_resultat || jsonb_build_object('inventory', d.inventory, 'revision', d.inventory_revision,
    'paie', jsonb_build_object('pa', d.pa, 'liquide', d.liquide, 'arg', d.arg,
      'solde_national', coalesce((SELECT solde FROM public.comptes_bancaires
                                  WHERE personnage = p_acteur AND banque = 'nationale'), 0)));
END; $$;

-- Refus porte hors de la sous-transaction (annulee) : code HG001, verdict en DETAIL.
-- Chaque enveloppe suit le meme gabarit ; seuls l'appel et le paiement changent.

CREATE OR REPLACE FUNCTION public.acheter_a_entrepot(p_requete uuid, p_acteur text, p_pays text, p_ville text,
  p_batiment text, p_achats jsonb, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('pays', p_pays, 'ville', p_ville, 'batiment', p_batiment, 'achats', p_achats, 'pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'acheter_a_entrepot', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.payer_ordre(p_acteur, 'acheter_ressources_entrepot', p_pa, p_cost);
    IF (v->>'ok')::boolean IS TRUE THEN v := public.acheter_a_entrepot(p_acteur, p_pays, p_ville, p_batiment, p_achats); END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'acheter_a_entrepot', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.acheter_a_la_criee(p_requete uuid, p_acteur text, p_pays text, p_ville text,
  p_batiment text, p_achats jsonb, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('pays', p_pays, 'ville', p_ville, 'batiment', p_batiment, 'achats', p_achats, 'pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'acheter_a_la_criee', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.payer_ordre(p_acteur, 'acheter_criee', p_pa, p_cost);
    IF (v->>'ok')::boolean IS TRUE THEN v := public.acheter_a_la_criee(p_acteur, p_pays, p_ville, p_batiment, p_achats); END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'acheter_a_la_criee', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.acheter_vente_directe_usine(p_requete uuid, p_acteur text, p_pays text, p_ville text,
  p_batiment text, p_achats jsonb, p_pa integer DEFAULT 0, p_cost integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('pays', p_pays, 'ville', p_ville, 'batiment', p_batiment, 'achats', p_achats, 'pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'acheter_vente_directe_usine', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.payer_ordre(p_acteur, 'vente_directe_usine', p_pa, p_cost);
    IF (v->>'ok')::boolean IS TRUE THEN v := public.acheter_vente_directe_usine(p_acteur, p_pays, p_ville, p_batiment, p_achats); END IF;
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'acheter_vente_directe_usine', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.acheter_produit_manufacture(p_requete uuid, p_acteur text, p_pays text, p_produit text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE prm jsonb; v jsonb; d text;
BEGIN
  PERFORM public.exiger_acteur(p_acteur);
  prm := jsonb_build_object('pays', p_pays, 'produit', p_produit);
  v := public.achat_requete_ouvrir_interne(p_acteur, p_requete, 'acheter_produit_manufacture', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.acheter_produit_manufacture(p_acteur, p_pays, p_produit);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(p_acteur, p_requete, 'acheter_produit_manufacture', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.objet_acheter(p_requete uuid, p_ordre text, p_modele text, p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('ordre', p_ordre, 'modele', p_modele, 'pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'objet_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.objet_acheter(p_ordre, p_modele, p_pa, p_cost);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'objet_acheter', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.arme_acheter(p_requete uuid, p_entreprise text, p_arme text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('entreprise', p_entreprise, 'arme', p_arme);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'arme_acheter', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.arme_acheter(p_entreprise, p_arme);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'arme_acheter', prm, v);
END; $$;

-- Marche noir : un echec (denonciation, alerte) est un resultat ok=true, reussi=false.
-- Il est enregistre : la seconde tentative rejoue l'echec au lieu de relancer le jet.
CREATE OR REPLACE FUNCTION public.crime_acheter_arme_noire(p_requete uuid, p_entreprise text, p_arme text, p_benediction boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('entreprise', p_entreprise, 'arme', p_arme, 'benediction', p_benediction);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_acheter_arme_noire', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.crime_acheter_arme_noire(p_entreprise, p_arme, p_benediction);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_acheter_arme_noire', prm, v);
END; $$;

CREATE OR REPLACE FUNCTION public.crime_acheter_explosifs(p_requete uuid, p_pa integer, p_cost integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('pa', p_pa, 'cost', p_cost);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'crime_acheter_explosifs', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.crime_acheter_explosifs(p_pa, p_cost);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'crime_acheter_explosifs', prm, v);
END; $$;

-- Vente de bois a l'imprimerie : meme defaut en sens inverse (bois retire et paye deux fois).
CREATE OR REPLACE FUNCTION public.imprimerie_acheter_bois(p_requete uuid, p_qte integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE a text := public.mon_personnage(); prm jsonb; v jsonb; d text;
BEGIN
  prm := jsonb_build_object('qte', p_qte);
  v := public.achat_requete_ouvrir_interne(a, p_requete, 'imprimerie_acheter_bois', prm);
  IF v IS NOT NULL THEN RETURN v; END IF;
  BEGIN
    v := public.imprimerie_acheter_bois(p_qte);
    IF (v->>'ok')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'achat_refuse' USING ERRCODE = 'HG001', DETAIL = coalesce(v, '{"ok":false}')::text; END IF;
  EXCEPTION WHEN SQLSTATE 'HG001' THEN GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL; RETURN d::jsonb;
  END;
  RETURN public.achat_requete_clore_interne(a, p_requete, 'imprimerie_acheter_bois', prm, v);
END; $$;

-- Droits : aides internes fermees ; nouvelles portes ouvertes au seul joueur connecte.
REVOKE ALL ON FUNCTION public.achat_requete_ouvrir_interne(text, uuid, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.achat_requete_clore_interne(text, uuid, text, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
DO $$
DECLARE s text;
BEGIN
  FOREACH s IN ARRAY ARRAY[
    'public.acheter_a_entrepot(uuid, text, text, text, text, jsonb, integer, integer)',
    'public.acheter_a_la_criee(uuid, text, text, text, text, jsonb, integer, integer)',
    'public.acheter_vente_directe_usine(uuid, text, text, text, text, jsonb, integer, integer)',
    'public.acheter_produit_manufacture(uuid, text, text, text)',
    'public.objet_acheter(uuid, text, text, integer, integer)',
    'public.arme_acheter(uuid, text, text)',
    'public.crime_acheter_arme_noire(uuid, text, text, boolean)',
    'public.crime_acheter_explosifs(uuid, integer, integer)',
    'public.imprimerie_acheter_bois(uuid, integer)'] LOOP
    EXECUTE 'REVOKE ALL ON FUNCTION ' || s || ' FROM PUBLIC, anon';
    EXECUTE 'GRANT EXECUTE ON FUNCTION ' || s || ' TO authenticated';
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
