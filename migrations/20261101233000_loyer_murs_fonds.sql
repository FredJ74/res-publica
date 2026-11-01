-- #66 — Loyer entre murs et fonds des commerces (Claude, 01/11/2026).
-- Règles : GAME-DESIGN-FONDS-MURS.md, section « Loyer entre murs et fonds ».
--   . l'exploitant du fonds paie chaque nuit un loyer au propriétaire ACTUEL des murs
--     (commune ou PJ) : le bail survit à la vente des murs ;
--   . montant : surface × loyer au m² du pays (Républia : 1 FR/m²/jour) ;
--   . aucun loyer quand le fonds est tenu par un PNJ, ni quand le même titulaire tient murs et fonds ;
--   . payeur (Fred, 01/11, 23 h 30) : la caisse du commerce d'abord, le complément sur les avoirs
--     de l'exploitant (liquide puis comptes ; caisse de l'organisation si le fonds est à elle) ;
--   . impayé : règle des baux (arbitrage du 8 septembre 2026) — avertissement la première nuit,
--     puis ardoise chiffrée et conservée, un seul avis à son ouverture ; jamais d'expulsion
--     automatique, aucun argent ne bouge tant que le tout n'est pas payable.
-- Indépendante de l'écran : l'ancien écran n'appelle rien ici ; seul le catalogue gagne un champ.
-- Prélèvement : murs_loyers_nuit(), appelée par la passe de minuit (identité serveur).

-- ---------------------------------------------------------------------------
-- 1. Données
-- ---------------------------------------------------------------------------
ALTER TABLE public.immobilier_baremes
  ADD COLUMN IF NOT EXISTS loyer_m2_jour integer NOT NULL DEFAULT 1 CHECK (loyer_m2_jour >= 0);
UPDATE public.immobilier_baremes SET loyer_m2_jour = 1 WHERE country = 'republic';

CREATE TABLE IF NOT EXISTS public.murs_loyers (
  titre_id        text PRIMARY KEY REFERENCES public.murs_titres(id),
  jour_paiement   text,                     -- jour de Paris du dernier passage (anti-rejeu)
  dernier_paye    text,                     -- jour de Paris du dernier loyer encaissé
  dernier_montant integer,
  avertissement   boolean NOT NULL DEFAULT false,
  impaye          jsonb,                    -- {depuis, jours, montantDu, exploitant}
  exploitant      text,                     -- titulaire du fonds lors du dernier passage
  ardoises_closes jsonb NOT NULL DEFAULT '[]'::jsonb, -- ardoises des exploitants précédents (conservées)
  updated_at      timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.murs_loyers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.murs_loyers FROM anon, authenticated;
-- Pas de lecture directe : l'écran passe par immobilier_catalogue, qui ne montre l'ardoise
-- qu'aux deux parties.

-- ---------------------------------------------------------------------------
-- 2. Moteur de lecture : loyer d'un titre (injoignable du réseau)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.murs_loyer_etat_interne(p_titre text, p_observateur text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  t public.murs_titres%ROWTYPE; v_m2 integer; v_fonds text; v_fonds_nom text; v_applique boolean;
  l public.murs_loyers%ROWTYPE; v_partie boolean;
BEGIN
  SELECT * INTO t FROM public.murs_titres WHERE id = p_titre;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT loyer_m2_jour INTO v_m2 FROM public.immobilier_baremes WHERE country = t.country;
  SELECT coalesce(data->>'proprietaire', 'PNJ') INTO v_fonds FROM public.entreprises WHERE id = t.id;
  v_fonds := coalesce(v_fonds, 'PNJ');
  v_fonds_nom := CASE WHEN left(v_fonds, 3) = 'pj:' THEN substr(v_fonds, 4) ELSE v_fonds END;
  v_applique := v_fonds <> 'PNJ' AND v_fonds_nom IS DISTINCT FROM t.proprietaire AND coalesce(v_m2, 0) > 0;
  SELECT * INTO l FROM public.murs_loyers WHERE titre_id = t.id;
  v_partie := p_observateur IS NOT NULL AND (p_observateur = t.proprietaire OR p_observateur = v_fonds_nom);
  RETURN jsonb_build_object(
    'montantJour', CASE WHEN v_m2 IS NULL THEN NULL ELSE t.surface * v_m2 END,
    'loyerM2', v_m2,
    'applique', v_applique,
    'motif', CASE WHEN v_fonds = 'PNJ' THEN 'fonds_pnj'
                  WHEN v_fonds_nom = t.proprietaire THEN 'meme_titulaire'
                  WHEN coalesce(v_m2, 0) <= 0 THEN 'bareme_absent' END,
    'dernierPaye', CASE WHEN v_partie THEN l.dernier_paye END,
    'avertissement', CASE WHEN v_partie THEN coalesce(l.avertissement, false) END,
    'impaye', CASE WHEN v_partie THEN l.impaye END);
END; $function$;

-- ---------------------------------------------------------------------------
-- 3. Prélèvement d'un titre (une transaction, rejouable sans double effet le même jour)
-- ---------------------------------------------------------------------------
-- Verdicts : titre_absent, deja_preleve, ignore_fonds_pnj, ignore_meme_titulaire,
-- ignore_sans_bareme, paye, avertissement, impaye_ouvert, impaye_deja_avise.
CREATE OR REPLACE FUNCTION public.murs_loyer_prelever(p_titre text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  t public.murs_titres%ROWTYPE; l public.murs_loyers%ROWTYPE; e jsonb;
  v_jour text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD');
  v_m2 integer; v_montant integer; v_fonds text; v_fonds_nom text;
  v_caisse numeric; v_part_caisse integer; v_reste integer; v_rec jsonb; v_imp jsonb;
  v_avis_a text; v_chef text;
BEGIN
  SELECT * INTO t FROM public.murs_titres WHERE id = p_titre FOR UPDATE;
  IF NOT FOUND THEN RETURN 'titre_absent'; END IF;
  INSERT INTO public.murs_loyers (titre_id) VALUES (t.id) ON CONFLICT (titre_id) DO NOTHING;
  SELECT * INTO l FROM public.murs_loyers WHERE titre_id = t.id FOR UPDATE;
  IF l.jour_paiement = v_jour THEN RETURN 'deja_preleve'; END IF;

  SELECT data INTO e FROM public.entreprises WHERE id = t.id FOR UPDATE;
  v_fonds := coalesce(e->>'proprietaire', 'PNJ');
  v_fonds_nom := CASE WHEN left(v_fonds, 3) = 'pj:' THEN substr(v_fonds, 4) ELSE v_fonds END;
  SELECT loyer_m2_jour INTO v_m2 FROM public.immobilier_baremes WHERE country = t.country;
  v_montant := t.surface * coalesce(v_m2, 0);

  -- Sans loyer : on marque le jour, l'éventuel avertissement tombe avec l'exploitation.
  IF v_fonds = 'PNJ' OR v_fonds_nom = t.proprietaire OR v_montant <= 0 THEN
    UPDATE public.murs_loyers SET jour_paiement = v_jour, avertissement = false, exploitant = v_fonds,
           updated_at = now() WHERE titre_id = t.id;
    RETURN CASE WHEN v_fonds = 'PNJ' THEN 'ignore_fonds_pnj'
                WHEN v_fonds_nom = t.proprietaire THEN 'ignore_meme_titulaire'
                ELSE 'ignore_sans_bareme' END;
  END IF;

  -- Un nouvel exploitant n'hérite ni de l'avertissement ni de l'ardoise du précédent.
  IF l.exploitant IS DISTINCT FROM v_fonds THEN
    IF l.impaye IS NOT NULL THEN
      UPDATE public.murs_loyers SET ardoises_closes = ardoises_closes || jsonb_build_array(l.impaye)
       WHERE titre_id = t.id;
    END IF;
    l.avertissement := false;
    l.impaye := NULL;
  END IF;

  -- Destinataire des avis : le PJ exploitant, ou le chef de l'organisation exploitante.
  IF left(v_fonds, 5) = 'orga:' THEN
    SELECT o.data::jsonb->>'chef' INTO v_chef FROM public.organisations o WHERE o.id = substr(v_fonds, 6);
    v_avis_a := v_chef;
  ELSE
    v_avis_a := v_fonds_nom;
  END IF;

  -- Payeur : la caisse du commerce d'abord, le complément sur l'exploitant (tout ou rien).
  v_caisse := greatest(0, coalesce((e->>'caisse')::numeric, 0));
  v_part_caisse := least(floor(v_caisse)::integer, v_montant);
  v_reste := v_montant - v_part_caisse;
  IF v_reste > 0 AND NOT public.mouvement_titulaire(v_fonds, -v_reste) THEN
    -- Impayé : aucun argent ne bouge, le loyer reste dû.
    IF NOT l.avertissement THEN
      UPDATE public.murs_loyers SET jour_paiement = v_jour, avertissement = true, impaye = l.impaye,
             exploitant = v_fonds, updated_at = now() WHERE titre_id = t.id;
      IF v_avis_a IS NOT NULL THEN
        PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', v_avis_a,
          'Loyer impayé — ' || t.libelle,
          'Le loyer des murs de ' || t.libelle || ' (' || v_montant || ' FR) n''a pas pu être prélevé : '
          || 'la caisse du commerce et vos avoirs n''y suffisent pas. Faute de paiement la nuit prochaine, '
          || 'l''impayé sera inscrit et signalé au propriétaire des murs.');
      END IF;
      RETURN 'avertissement';
    END IF;
    v_imp := coalesce(l.impaye, '{}'::jsonb);
    UPDATE public.murs_loyers SET jour_paiement = v_jour, exploitant = v_fonds, updated_at = now(),
           impaye = jsonb_build_object(
             'depuis', coalesce(v_imp->>'depuis', v_jour),
             'jours', coalesce((v_imp->>'jours')::integer, 0) + 1,
             'montantDu', coalesce((v_imp->>'montantDu')::integer, 0) + v_montant,
             'exploitant', v_fonds)
     WHERE titre_id = t.id;
    IF v_imp ? 'depuis' THEN RETURN 'impaye_deja_avise'; END IF;
    IF v_avis_a IS NOT NULL THEN
      PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', v_avis_a,
        'Impayé inscrit — ' || t.libelle,
        'Le loyer des murs de ' || t.libelle || ' reste impayé : la dette est inscrite et grossit de '
        || v_montant || ' FR par nuit tant que le loyer ne peut pas être prélevé. Le propriétaire des murs en est informé.');
    END IF;
    IF t.proprietaire <> 'commune' THEN
      PERFORM public.mail_systeme_poser_interne('Gestionnaire immobilier', t.proprietaire,
        'Loyer impayé — ' || t.libelle,
        'L''exploitant du fonds de ' || t.libelle || ' ne paie plus le loyer de vos murs (' || v_montant
        || ' FR par nuit). La dette est inscrite ; il n''y a pas d''expulsion automatique : '
        || 'à vous de régler l''affaire, à l''amiable ou devant la justice.');
    END IF;
    RETURN 'impaye_ouvert';
  END IF;

  -- Débit de la caisse du commerce (la part de l'exploitant est déjà prélevée ci-dessus).
  IF v_part_caisse > 0 THEN
    UPDATE public.entreprises
       SET data = jsonb_set(e, '{caisse}', to_jsonb(v_caisse - v_part_caisse)), updated_at = now()
     WHERE id = t.id;
  END IF;

  -- Crédit du propriétaire ACTUEL des murs.
  IF t.proprietaire = 'commune' THEN
    v_rec := public.recette_municipale(t.country, t.ville, v_montant, 'loyer');
    IF NOT coalesce((v_rec->>'ok')::boolean, false) THEN RAISE EXCEPTION 'destination_introuvable'; END IF;
  ELSIF NOT public.mouvement_titulaire(t.proprietaire, v_montant) THEN
    RAISE EXCEPTION 'destination_introuvable';
  END IF;

  UPDATE public.murs_loyers
     SET jour_paiement = v_jour, dernier_paye = v_jour, dernier_montant = v_montant,
         avertissement = false, impaye = l.impaye, exploitant = v_fonds, updated_at = now()
   WHERE titre_id = t.id;
  RETURN 'paye';
END; $function$;

-- ---------------------------------------------------------------------------
-- 4. Passe de nuit : tous les titres, chacun dans sa propre sous-transaction
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.murs_loyers_nuit()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  r record; v text; v_bilan jsonb := '{}'::jsonb; v_erreurs jsonb := '[]'::jsonb;
BEGIN
  FOR r IN SELECT id FROM public.murs_titres ORDER BY id LOOP
    BEGIN
      v := public.murs_loyer_prelever(r.id);
    EXCEPTION WHEN others THEN
      v := 'erreur';
      v_erreurs := v_erreurs || jsonb_build_array(jsonb_build_object('titre', r.id, 'erreur', left(SQLERRM, 120)));
    END;
    v_bilan := v_bilan || jsonb_build_object(v, coalesce((v_bilan->>v)::integer, 0) + 1);
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'verdicts', v_bilan, 'erreurs', v_erreurs);
END; $function$;

-- ---------------------------------------------------------------------------
-- 5. Catalogue de l'Office notarial : chaque titre porte son loyer
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.immobilier_catalogue()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_moi text; v_pays text; v_res jsonb;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie'); END IF;
  SELECT coalesce(country, 'republic') INTO v_pays FROM public.personnages_donnees WHERE name = v_moi;
  SELECT coalesce(jsonb_agg(public.immobilier_titre_etat_interne(t.id, v_moi)
                            || jsonb_build_object('loyer', public.murs_loyer_etat_interne(t.id, v_moi))
                            ORDER BY t.ville, t.id), '[]'::jsonb)
    INTO v_res FROM public.murs_titres t WHERE t.country = v_pays;
  RETURN jsonb_build_object('ok', true, 'titres', v_res, 'maintenant', (extract(epoch from now())*1000)::bigint);
END; $function$;

-- ---------------------------------------------------------------------------
-- 6. Droits : prélèvement et passe de nuit au serveur seul
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.murs_loyer_etat_interne(text, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.murs_loyer_prelever(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.murs_loyers_nuit() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.murs_loyer_prelever(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.murs_loyers_nuit() TO service_role;
REVOKE ALL ON FUNCTION public.immobilier_catalogue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.immobilier_catalogue() TO authenticated;

-- Preuve structurelle (la migration ne prélève rien).
DO $preuve$
BEGIN
  IF (SELECT loyer_m2_jour FROM public.immobilier_baremes WHERE country = 'republic') IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'loyer Républia : 1 FR/m²/jour attendu'; END IF;
  IF has_function_privilege('authenticated', 'public.murs_loyers_nuit()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.murs_loyers_nuit()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.murs_loyer_prelever(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'le prélèvement doit rester réservé au serveur'; END IF;
  IF has_table_privilege('authenticated', 'public.murs_loyers', 'SELECT') THEN
    RAISE EXCEPTION 'murs_loyers ne se lit que par le catalogue'; END IF;
END $preuve$;
