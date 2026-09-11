-- =====================================================================
-- DOTATION D'AMORCAGE UNIQUE DES CAISSES DE BATIMENTS (arbitrage du 11 septembre 2026)
-- =====================================================================
-- Regle : chaque caisse de batiment reelle des 4 pays est completee UNE SEULE FOIS jusqu'a 200
-- unites de SA monnaie locale (FR Republia, PS El Estado, RP Sovarka, DR Al-Khalija). Les montants
-- sont des nombres nus, deja exprimes dans la monnaie du pays du batiment : aucune conversion.
--   solde >= 200 -> rien ; 0 < solde < 200 -> complete a 200 ; 0 -> 200.
-- Ce n'est NI un plancher permanent NI une subvention periodique : apres cette dotation, une caisse
-- peut descendre sous 200 ou a 0, et n'est jamais renflouee.
--
-- IDEMPOTENCE : registre dotations_amorcage_caisses, une ligne par caisse examinee (y compris
-- celles a >= 200, dotation 0). Une caisse deja inscrite n'est plus jamais examinee : une nouvelle
-- execution ne verse RIEN a une caisse deja traitee, meme si son solde est depuis retombe sous 200.
--
-- PERIMETRE (inventaire du code du 11 septembre 2026) -- seules les caisses de batiments REELS,
-- lues/ecrites par le jeu, d'un batiment present dans la ville :
--   1. caisses_batiments (data.solde) : cle <pays>_<id>.
--   2. batiments_etat (data = texte JSON) : sous-caisses entrepot/usine (lignes existantes),
--      imprimerie (La Tribune / L'Autruche Entravee, defaut 0) et sante (clinique privee, defaut 0).
--   3. entreprises (data.caisse) : lignes existantes uniquement, proprietaire PNJ/public.
-- EXCLUS (voir rapport) : comptes personnels, organisations, fonds de commerce, clubs, budgets
-- municipaux/nationaux, reserve-nationale (compte national sans batiment), banque-privee (tresorerie
-- Helvetia, systeme distinct), cles orphelines/heritees, caisses de marche/multimodal attribuees a une
-- ville sans ce batiment, entreprises marche/buvette (caisse inutilisee), sous-objets batiments_etat
-- absents dont le defaut est > 200 (usine 3000, entrepot 8500 : les creer les appauvrirait).
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.dotations_amorcage_caisses (
  caisse_ref    text PRIMARY KEY,
  stockage      text NOT NULL,
  pays          text NOT NULL,
  cle           text NOT NULL,
  solde_avant   numeric NOT NULL,
  montant_verse numeric NOT NULL,
  solde_apres   numeric NOT NULL,
  caisse_creee  boolean NOT NULL DEFAULT false,
  applique_ts   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.dotations_amorcage_caisses ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.dotations_amorcage_caisses FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  c_cible   CONSTANT numeric := 200;
  p         text;
  v         text;
  r         record;
  v_data    jsonb;
  v_d       jsonb;
  v_obj     jsonb;
  v_solde   numeric;
  v_verse   numeric;
  v_existe  boolean;
  v_ref     text;
  v_ins     integer;
BEGIN
  CREATE TEMP TABLE _cibles (stockage text, pays text, ville text, cle text, section text) ON COMMIT DROP;

  -- 1. caisses_batiments -------------------------------------------------------------------------
  FOREACH p IN ARRAY ARRAY['republic','narco','soviet','khalija'] LOOP
    -- Institutions nationales (batiments presents dans les 4 pays)
    INSERT INTO _cibles SELECT 'caisses_batiments', p, NULL, x, NULL FROM unnest(ARRAY[
      'palais-presidentiel', 'gouvernement-pm', 'gouvernement-min_info', 'gouvernement-min_ae',
      'gouvernement-min_int', 'gouvernement-min_fin', 'gouvernement-min_just', 'gouvernement-min_def',
      'assemblee', 'caserne-militaire', 'qhs-prison', 'office-notarial', 'centre-multinodal-luthecia']) x;
    -- Caisses locales : commissariat, tribunal, mairie, dispensaire, stade dans les 3 villes reelles
    FOREACH v IN ARRAY ARRAY['capitale','ville_a','ville_b'] LOOP
      INSERT INTO _cibles VALUES
        ('caisses_batiments', p, v, 'commissariat_' || v, NULL),
        ('caisses_batiments', p, v, 'tribunal_' || v, NULL),
        ('caisses_batiments', p, v, CASE WHEN v = 'capitale' THEN 'mairie-capitale' ELSE 'mairie_' || v END, NULL),
        ('caisses_batiments', p, v, 'dispensaire_' || v, NULL),
        ('caisses_batiments', p, v, 'stade_' || v, NULL);
    END LOOP;
    -- Hotels des villes secondaires (hotel-port / hotel-mineur) ; marche de la capitale
    INSERT INTO _cibles VALUES
      ('caisses_batiments', p, 'ville_a', 'hotel_ville_a', NULL),
      ('caisses_batiments', p, 'ville_b', 'hotel_ville_b', NULL),
      ('caisses_batiments', p, 'capitale', 'marche_capitale', NULL);
  END LOOP;
  -- Republia uniquement : marches de PSM et Montrouge, hubs multimodaux secondaires, port, cultes
  INSERT INTO _cibles VALUES
    ('caisses_batiments', 'republic', 'ville_a', 'marche_ville_a', NULL),
    ('caisses_batiments', 'republic', 'ville_b', 'marche_ville_b', NULL),
    ('caisses_batiments', 'republic', 'ville_a', 'centre-multinodal-port-sainte-marie', NULL),
    ('caisses_batiments', 'republic', 'ville_b', 'centre-multinodal-montrouge', NULL),
    ('caisses_batiments', 'republic', 'ville_a', 'port-sainte-marie', NULL),
    ('caisses_batiments', 'republic', 'capitale', 'tabernacle-impots', NULL),
    ('caisses_batiments', 'republic', 'ville_a', 'notre-dame-mer', NULL),
    ('caisses_batiments', 'republic', 'ville_b', 'eglise-montrouge', NULL);

  -- 2. batiments_etat ----------------------------------------------------------------------------
  INSERT INTO _cibles VALUES
    ('batiments_etat', 'republic', 'capitale', 'entrepot-logistique-luthecia', 'entrepot'),
    ('batiments_etat', 'republic', 'ville_a',  'entrepot-logistique-psm',      'entrepot'),
    ('batiments_etat', 'republic', 'ville_b',  'entrepot-logistique-montrouge','entrepot'),
    ('batiments_etat', 'republic', 'capitale', 'usine-pharmaceutique-luthecia','usine'),
    ('batiments_etat', 'republic', 'ville_a',  'pole-tabac-alcools-psm',       'usine'),
    ('batiments_etat', 'republic', 'ville_b',  'raffinerie-montrouge',         'usine'),
    ('batiments_etat', 'republic', 'capitale', 'la-tribune', 'imprimerie'),
    ('batiments_etat', 'republic', 'ville_b',  'la-tribune', 'imprimerie'),
    ('batiments_etat', 'narco',    'capitale', 'la-tribune', 'imprimerie'),
    ('batiments_etat', 'soviet',   'capitale', 'la-tribune', 'imprimerie'),
    ('batiments_etat', 'khalija',  'capitale', 'la-tribune', 'imprimerie'),
    ('batiments_etat', 'republic', 'capitale', 'clinique-privee', 'sante'),
    ('batiments_etat', 'narco',    'capitale', 'clinique-privee', 'sante'),
    ('batiments_etat', 'soviet',   'capitale', 'clinique-privee', 'sante'),
    ('batiments_etat', 'khalija',  'capitale', 'clinique-privee', 'sante');

  -- 3. entreprises : lignes existantes (hors marche/buvette, dont data.caisse n'est jamais utilisee)
  INSERT INTO _cibles
  SELECT 'entreprises', split_part(e.id, '-', 2), NULL, e.id, NULL
    FROM public.entreprises e
   WHERE e.id NOT LIKE 'marche-%' AND e.id NOT LIKE 'buvette-%'
     AND split_part(e.id, '-', 2) IN ('republic','narco','soviet','khalija');

  -- Application ----------------------------------------------------------------------------------
  FOR r IN SELECT * FROM _cibles ORDER BY stockage, pays, cle, section LOOP
    v_ref := r.stockage || ':' || r.pays || '_' || COALESCE(r.ville || '_', '') || r.cle || COALESCE('#' || r.section, '');
    IF r.stockage = 'entreprises' THEN v_ref := 'entreprises:' || r.cle; END IF;
    IF r.stockage = 'caisses_batiments' THEN v_ref := 'caisses_batiments:' || r.pays || '_' || r.cle; END IF;
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.dotations_amorcage_caisses WHERE caisse_ref = v_ref);

    IF r.stockage = 'caisses_batiments' THEN
      SELECT data INTO v_data FROM public.caisses_batiments WHERE id = r.pays || '_' || r.cle FOR UPDATE;
      v_existe := FOUND;
      v_solde := CASE WHEN v_existe AND jsonb_typeof(v_data -> 'solde') = 'number' THEN (v_data ->> 'solde')::numeric ELSE 0 END;
      CONTINUE WHEN v_solde < 0;   -- cas non prevu par la regle : laisse intact, non inscrit
      v_verse := CASE WHEN v_solde < c_cible THEN c_cible - v_solde ELSE 0 END;
      IF v_verse > 0 THEN
        IF v_existe THEN
          UPDATE public.caisses_batiments
             SET data = jsonb_set(CASE WHEN jsonb_typeof(v_data) = 'object' THEN v_data ELSE '{}'::jsonb END, '{solde}', to_jsonb(c_cible)),
                 updated_at = now()
           WHERE id = r.pays || '_' || r.cle;
        ELSE
          INSERT INTO public.caisses_batiments (id, data, updated_at) VALUES (r.pays || '_' || r.cle, jsonb_build_object('solde', c_cible), now());
        END IF;
      END IF;

    ELSIF r.stockage = 'batiments_etat' THEN
      SELECT data INTO v_data FROM public.batiments_etat WHERE id = r.pays || '_' || r.ville || '_' || r.cle FOR UPDATE;
      v_existe := FOUND;
      v_d := CASE WHEN NOT v_existe THEN '{}'::jsonb
                  WHEN jsonb_typeof(v_data) = 'string' THEN (v_data #>> '{}')::jsonb
                  WHEN jsonb_typeof(v_data) = 'object' THEN v_data ELSE '{}'::jsonb END;
      v_obj := v_d -> r.section;
      -- entrepot/usine : uniquement si la sous-caisse existe deja (sinon le jeu applique un defaut > 200)
      CONTINUE WHEN r.section IN ('entrepot', 'usine') AND (v_obj IS NULL OR jsonb_typeof(v_obj -> 'caisse') <> 'number');
      IF v_obj IS NULL OR jsonb_typeof(v_obj) <> 'object' THEN
        -- Memes valeurs par defaut que le jeu quand le sous-objet est absent (caisse 0).
        v_obj := CASE r.section WHEN 'imprimerie' THEN '{"caisse":0,"stockBois":0}'::jsonb
                                ELSE '{"caisse":0,"stockMatieres":{}}'::jsonb END;
      END IF;
      v_solde := CASE WHEN jsonb_typeof(v_obj -> 'caisse') = 'number' THEN (v_obj ->> 'caisse')::numeric ELSE 0 END;
      CONTINUE WHEN v_solde < 0;
      v_verse := CASE WHEN v_solde < c_cible THEN c_cible - v_solde ELSE 0 END;
      IF v_verse > 0 THEN
        v_d := v_d || jsonb_build_object(r.section, v_obj || jsonb_build_object('caisse', c_cible));
        IF v_existe THEN
          UPDATE public.batiments_etat SET data = to_jsonb(v_d::text), updated_at = now()
           WHERE id = r.pays || '_' || r.ville || '_' || r.cle;
        ELSE
          INSERT INTO public.batiments_etat (id, country, city, building_id, data, updated_at)
          VALUES (r.pays || '_' || r.ville || '_' || r.cle, r.pays, r.ville, r.cle, to_jsonb(v_d::text), now());
        END IF;
      END IF;

    ELSE -- entreprises
      SELECT data INTO v_data FROM public.entreprises WHERE id = r.cle FOR UPDATE;
      CONTINUE WHEN NOT FOUND;
      -- Batiments publics ou PNJ uniquement : jamais l'entreprise d'un joueur.
      CONTINUE WHEN NOT (COALESCE(v_data ->> 'proprietaire', 'PNJ') = 'PNJ' OR (v_data ->> 'proprietaire') LIKE 'État%');
      v_existe := true;
      v_solde := CASE WHEN jsonb_typeof(v_data -> 'caisse') = 'number' THEN (v_data ->> 'caisse')::numeric ELSE 0 END;
      CONTINUE WHEN v_solde < 0;
      v_verse := CASE WHEN v_solde < c_cible THEN c_cible - v_solde ELSE 0 END;
      IF v_verse > 0 THEN
        UPDATE public.entreprises SET data = jsonb_set(v_data, '{caisse}', to_jsonb(c_cible)), updated_at = now() WHERE id = r.cle;
      END IF;
    END IF;

    INSERT INTO public.dotations_amorcage_caisses (caisse_ref, stockage, pays, cle, solde_avant, montant_verse, solde_apres, caisse_creee)
    VALUES (v_ref, r.stockage, r.pays, COALESCE(r.ville || '/', '') || r.cle || COALESCE('#' || r.section, ''), v_solde, v_verse, GREATEST(v_solde, c_cible), NOT v_existe AND v_verse > 0)
    ON CONFLICT (caisse_ref) DO NOTHING;
    GET DIAGNOSTICS v_ins = ROW_COUNT;
    IF v_ins = 0 THEN
      RAISE EXCEPTION 'dotation_amorcage : course sur %', v_ref;   -- annule tout plutot que verser deux fois
    END IF;
  END LOOP;
END $$;
