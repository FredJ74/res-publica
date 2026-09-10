-- =====================================================================
-- ASSEMBLEE NATIONALE — APPLICATION DES LOIS D'INTERDICTION AUX VENTES (11 septembre 2026)
-- =====================================================================
-- A appliquer APRES migration_assemblee_actions_joueur.sql. Rejouable.
--
-- ARBITRAGE DE GAME DESIGN (11 septembre 2026)
--   1. Categorie interdite en vigueur -> TOUTE vente legale ou institutionnelle d'un objet ou d'une
--      matiere de cette categorie est refusee, quel que soit le fournisseur.
--   2. Un circuit ILLEGAL (marche noir) peut conclure la transaction : la marchandise n'est pas
--      supprimee ; acheteur et vendeur commettent deux actes distincts, detectes independamment,
--      chacun avec sa propre trace.
--   3. Seule une transaction POSTERIEURE a l'entree en vigueur (adoptee_ts) est concernee. La
--      possession d'un objet devenu interdit releve de la confiscation existante, jamais d'une
--      transaction inventee.
--
-- CE QUE FAIT CE FICHIER
--   - Correspondance serveur categorie -> matieres / types / sous-types (miroir exact de
--     CATEGORIES_INTERDICTION, plateau-assemblee.js). Aucune interpretation : cle exacte. Une loi
--     « Viandes » vise la matiere 'viande', jamais le boeuf bourguignon (dont le stackKey est
--     l'identifiant de la recette).
--   - assemblee_loi_en_vigueur : LA regle unique, horodatee (adoptee_ts <= instant de la
--     transaction). Une loi abrogee cesse immediatement de s'appliquer (statut 'abrogee').
--   - assemblee_verifier_vente : lecture publique appelee par TOUS les circuits de vente legale.
--   - Detection d'une partie (acheteur ou vendeur) et moteur a deux parties : serveur, jets
--     independants, traces protegees par le trigger de preservation.
--   - assemblee_achat_illegal : point d'entree client des circuits illegaux existants (marche noir
--     de l'armurerie, poisons), dont le vendeur est un PNJ. L'objet est resolu par le serveur.
--   - Trigger sur caisses_fret : aucun lot contenant une marchandise interdite ne peut passer au
--     statut 'vendue', quel que soit l'ecrivain.
-- =====================================================================


-- =====================================================================
-- 1. CORRESPONDANCE CATEGORIE -> OBJETS ET MATIERES
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.assemblee_categories_interdiction (
  categorie   text PRIMARY KEY,
  label       text   NOT NULL,
  matieres    text[] NOT NULL DEFAULT '{}',   -- cles de RESSOURCES_ECONOMIE, comparees au stackKey
  types_objet text[] NOT NULL DEFAULT '{}',   -- valeurs de item.type
  sous_types  text[] NOT NULL DEFAULT '{}'    -- raffinement sur item.sousType (vide = toute la famille)
);

-- Miroir exact de CATEGORIES_INTERDICTION. ON CONFLICT DO UPDATE : rejouer ce fichier resynchronise.
INSERT INTO public.assemblee_categories_interdiction (categorie, label, matieres, types_objet, sous_types) VALUES
  ('viandes',            'Viandes',                  ARRAY['viande'],                        '{}',                  '{}'),
  ('poissons',           'Poissons',                 ARRAY['poisson'],                       '{}',                  '{}'),
  ('denrees_animales',   'Denrées animales (large)', ARRAY['viande','poisson'],              '{}',                  '{}'),
  ('alcools',            'Alcools',                  ARRAY['alcool'],                        '{}',                  '{}'),
  ('tabac',              'Tabac',                    ARRAY['tabac'],                         '{}',                  '{}'),
  ('medicaments',        'Médicaments',              ARRAY['medicaments'],                   ARRAY['medicament'],   '{}'),
  ('armes_blanches',     'Armes blanches',           '{}',                                   ARRAY['arme'],         ARRAY['blanche']),
  ('armes_a_feu',        'Armes à feu',              '{}',                                   ARRAY['arme'],         ARRAY['poing','carabine']),
  ('armes',              'Armes (large)',            '{}',                                   ARRAY['arme'],         '{}'),
  ('poisons',            'Poisons',                  '{}',                                   ARRAY['poison'],       '{}'),
  ('carburants',         'Carburants',               ARRAY['carburant','petrole'],           '{}',                  '{}'),
  ('hydrocarbures',      'Hydrocarbures (large)',    ARRAY['carburant','petrole','charbon'], '{}',                  '{}'),
  ('bois_et_forets',     'Bois',                     ARRAY['bois'],                          '{}',                  '{}'),
  ('textile',            'Textile',                  ARRAY['textile'],                       '{}',                  '{}'),
  ('produits_exotiques', 'Produits exotiques',       ARRAY['produits_exotiques'],            '{}',                  '{}')
ON CONFLICT (categorie) DO UPDATE
  SET label = EXCLUDED.label, matieres = EXCLUDED.matieres,
      types_objet = EXCLUDED.types_objet, sous_types = EXCLUDED.sous_types;

ALTER TABLE public.assemblee_categories_interdiction ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS assemblee_categories_lecture ON public.assemblee_categories_interdiction;
CREATE POLICY assemblee_categories_lecture ON public.assemblee_categories_interdiction FOR SELECT USING (true);
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.assemblee_categories_interdiction FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.assemblee_categories_interdiction TO anon, authenticated, service_role;

-- L'objet {stackKey, type, sousType} appartient-il a la categorie ? Reproduction exacte de
-- assembleeInterdictionObjet : matiere par stackKey, OU type (et sous-type si la categorie en
-- precise). Une recette (stackKey = son identifiant, sans type) n'appartient a aucune categorie.
CREATE OR REPLACE FUNCTION public.assemblee_objet_vise(p_categorie text, p_objet jsonb)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.assemblee_categories_interdiction c
     WHERE c.categorie = p_categorie
       AND (   (p_objet ->> 'stackKey' IS NOT NULL AND (p_objet ->> 'stackKey') = ANY (c.matieres))
            OR (p_objet ->> 'type' IS NOT NULL AND (p_objet ->> 'type') = ANY (c.types_objet)
                AND (cardinality(c.sous_types) = 0
                     OR (p_objet ->> 'sousType' IS NOT NULL AND (p_objet ->> 'sousType') = ANY (c.sous_types)))))
  );
$$;


-- =====================================================================
-- 2. LA REGLE : UNE LOI EN VIGUEUR A L'INSTANT DE LA TRANSACTION
-- =====================================================================
-- En vigueur = loi mecanique ADOPTEE (une abrogation adoptee la passe a 'abrogee' dans la meme
-- transaction que sa cloture : les circuits sont reautorises immediatement), dont l'entree en
-- vigueur (adoptee_ts) est anterieure ou egale a l'instant de la transaction. L'instant est
-- toujours now() cote serveur : aucun appelant ne fournit l'heure.
CREATE OR REPLACE FUNCTION public.assemblee_loi_en_vigueur(p_country text, p_objet jsonb, p_instant timestamptz)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object('id', p.id, 'titre', p.titre, 'categorie', p.categorie, 'adoptee_ts', p.adoptee_ts)
    FROM public.assemblee_propositions p
   WHERE p.country = p_country
     AND p.type = 'mecanique'
     AND p.statut = 'adoptee'
     AND p.adoptee_ts IS NOT NULL
     AND p.adoptee_ts <= p_instant
     AND public.assemblee_objet_vise(p.categorie, p_objet)
   ORDER BY p.adoptee_ts, p.id
   LIMIT 1;
$$;

-- Verification d'une vente LEGALE, appelee par chaque circuit avant tout debit. Lecture seule,
-- publique (les lois en vigueur sont publiques). p_objets : tableau de {stackKey, type, sousType}.
-- Renvoie {ok, instant, interdits: [{index, loi}]}. FAIL-CLOSED : une entree qui n'est pas un
-- tableau est refusee (raison objets_invalides), jamais lue comme « rien a vendre ».
CREATE OR REPLACE FUNCTION public.assemblee_verifier_vente(p_objets jsonb, p_country text DEFAULT 'republic')
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
  WITH o AS (
    SELECT (t.ord - 1)::integer AS idx,
           public.assemblee_loi_en_vigueur(p_country, t.val, now()) AS loi
      FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_objets) = 'array' THEN p_objets ELSE '[]'::jsonb END)
           WITH ORDINALITY AS t(val, ord)
  )
  SELECT CASE WHEN jsonb_typeof(p_objets) IS DISTINCT FROM 'array'
    THEN jsonb_build_object('ok', false, 'instant', now(), 'raison', 'objets_invalides', 'interdits', '[]'::jsonb)
    ELSE jsonb_build_object(
           'ok', NOT EXISTS (SELECT 1 FROM o WHERE loi IS NOT NULL),
           'instant', now(),
           'interdits', COALESCE((SELECT jsonb_agg(jsonb_build_object('index', idx, 'loi', loi) ORDER BY idx)
                                    FROM o WHERE loi IS NOT NULL), '[]'::jsonb))
  END;
$$;


-- =====================================================================
-- 3. DETECTION D'UNE PARTIE (ACHETEUR OU VENDEUR) — INTERNE
-- =====================================================================
-- Un seul jet, sur la discretion de CETTE partie : max(5, 50 - floor(DIS/10)), exactement la
-- formule deja utilisee des deux cotes. La trace est TOUJOURS ecrite (origine serveur, id stable,
-- protegee par personnages_preserver_judiciaire). Detection -> convocation sous 36 h, jamais une
-- arrestation ; une seule convocation ouverte par motif. Cote acheteur, une convocation coute 10
-- DIS (regle existante de assembleeTracerTransactionIllegale) ; cote vendeur, rien (regle existante
-- de la trace vendeur). Le courrier est isole : son echec n'annule jamais l'acte judiciaire.
CREATE OR REPLACE FUNCTION public.assemblee_detecter_partie(
  p_nom       text,
  p_role      text,       -- 'achat' | 'vente'
  p_loi       jsonb,
  p_libelle   text,
  p_quantite  integer,
  p_baisse_dis boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_resources jsonb;
  v_convs     jsonb;
  v_hist      jsonb;
  v_dis       numeric;
  v_taux      integer;
  v_jet       integer;
  v_detecte   boolean;
  v_deja      boolean := false;
  v_trace     jsonb;
  v_conv      jsonb := NULL;
BEGIN
  SELECT CASE WHEN jsonb_typeof(resources) = 'object' THEN resources ELSE '{}'::jsonb END,
         COALESCE(convocations, '[]'::jsonb), COALESCE(historique_crimes, '[]'::jsonb)
    INTO v_resources, v_convs, v_hist
    FROM public.personnages WHERE name = p_nom FOR UPDATE;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  v_dis  := CASE WHEN jsonb_typeof(v_resources -> 'dis') = 'number' THEN (v_resources ->> 'dis')::numeric ELSE 0 END;
  v_taux := GREATEST(5, 50 - floor(v_dis / 10)::integer);
  v_jet  := floor(random() * 100)::integer + 1;
  v_detecte := v_jet <= v_taux;

  v_trace := jsonb_build_object(
    'id', 'trace-' || md5(random()::text || clock_timestamp()::text),
    'origine', 'serveur',
    'acte', 'transaction_interdite',
    'cible', COALESCE(p_libelle, p_loi ->> 'categorie'),
    'role', p_role,
    'categorie', p_loi ->> 'categorie',
    'quantite', COALESCE(p_quantite, 1),
    'loiId', p_loi ->> 'id',
    'loiTitre', p_loi ->> 'titre',
    'ts', to_jsonb(now()),
    'expireTs', to_jsonb(now() + interval '8 days'));
  v_hist := v_hist || jsonb_build_array(v_trace);

  IF v_detecte THEN
    SELECT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_convs) c
       WHERE c.value ->> 'motif' = 'transaction_interdite'
         AND COALESCE((c.value ->> 'traitee')::boolean, false) = false
    ) INTO v_deja;
    IF NOT v_deja THEN
      v_conv := jsonb_build_object(
        'id', 'conv-' || md5(random()::text || clock_timestamp()::text),
        'origine', 'serveur',
        'motif', 'transaction_interdite',
        'limiteTs', to_jsonb(now() + interval '36 hours'),
        'role', p_role,
        'categorie', p_loi ->> 'categorie',
        'loiId', p_loi ->> 'id',
        'loiTitre', p_loi ->> 'titre',
        'traitee', false);
      v_convs := v_convs || jsonb_build_array(v_conv);
      IF p_baisse_dis THEN
        v_dis := GREATEST(0, v_dis - 10);
        v_resources := jsonb_set(v_resources, '{dis}', to_jsonb(v_dis));
      END IF;
    END IF;
  END IF;

  UPDATE public.personnages
     SET convocations = v_convs, historique_crimes = v_hist, resources = v_resources
   WHERE name = p_nom;

  IF v_conv IS NOT NULL THEN
    BEGIN
      INSERT INTO public.mails (id, from_player, to_player, subject, body, time, read)
      VALUES (
        'mail-' || md5(random()::text || clock_timestamp()::text),
        'Commissariat', p_nom, 'Convocation officielle',
        CASE WHEN p_role = 'vente'
          THEN 'Une vente portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») a été constatée dans votre commerce. '
          ELSE 'Une transaction portant sur une marchandise interdite (« ' || (p_loi ->> 'titre') || ' ») vous a été imputée. ' END
        || 'Présentez-vous au commissariat sous 36 heures pour vous justifier. '
        || 'Passé ce délai sans vous présenter, vous serez arrêté(e) et détenu(e) deux jours.',
        to_char(now() AT TIME ZONE 'Europe/Paris', 'DD/MM/YYYY'), false);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object('role', p_role, 'detecte', v_detecte, 'taux', v_taux, 'jet', v_jet,
    'convocation_creee', v_conv IS NOT NULL, 'trace', v_trace, 'convocation', v_conv, 'dis', v_dis);
END;
$$;


-- =====================================================================
-- 4. MOTEUR D'UNE TRANSACTION ILLEGALE A DEUX PARTIES — INTERNE
-- =====================================================================
-- Aucune loi en vigueur a cet instant -> transaction legale, rien n'est ecrit (non-retroactivite :
-- rien ne rattrape plus tard une transaction anterieure). Sinon, une detection par partie JOUEUR
-- reellement existante, chacune avec son propre tirage : aucune ne lit l'autre. Un vendeur PNJ
-- ('PNJ', NULL ou inexistant) n'engage aucune responsabilite. Verrous poses dans l'ordre des noms :
-- deux transactions croisees entre les memes joueurs ne peuvent pas s'interbloquer.
CREATE OR REPLACE FUNCTION public.assemblee_transaction_interdite_interne(
  p_country  text,
  p_acheteur text,
  p_vendeur  text,
  p_objet    jsonb,
  p_libelle  text,
  p_quantite integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_loi     jsonb;
  v_vendeur text;
  v_a       jsonb := NULL;
  v_v       jsonb := NULL;
BEGIN
  v_loi := public.assemblee_loi_en_vigueur(p_country, p_objet, now());
  IF v_loi IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'interdit', false);
  END IF;

  v_vendeur := NULLIF(NULLIF(btrim(COALESCE(p_vendeur, '')), ''), 'PNJ');
  IF v_vendeur IS NOT DISTINCT FROM p_acheteur THEN v_vendeur := NULL; END IF;

  PERFORM 1 FROM public.personnages
   WHERE name IN (p_acheteur, v_vendeur) ORDER BY name FOR UPDATE;

  IF p_acheteur IS NOT NULL THEN
    v_a := public.assemblee_detecter_partie(p_acheteur, 'achat', v_loi, p_libelle, p_quantite, true);
  END IF;
  IF v_vendeur IS NOT NULL THEN
    v_v := public.assemblee_detecter_partie(v_vendeur, 'vente', v_loi, p_libelle, p_quantite, false);
  END IF;

  RETURN jsonb_build_object('ok', true, 'interdit', true, 'loi', v_loi, 'acheteur', v_a, 'vendeur', v_v);
END;
$$;


-- =====================================================================
-- 5. CIRCUITS ILLEGAUX EXISTANTS : POINT D'ENTREE CLIENT
-- =====================================================================
-- Catalogue SERVEUR des objets vendus par les circuits illegaux existants : le client transmet un
-- identifiant, jamais la nature de l'objet (il ne peut ni masquer ni travestir ce qu'il achete).
-- Leurs vendeurs sont des PNJ (l'armurier du comptoir, le fournisseur de poison) : seule la partie
-- acheteuse est detectee. Miroir de ARMES_CATALOGUE.republic et POISON_OBJETS.
CREATE TABLE IF NOT EXISTS public.assemblee_catalogue_illegal (
  circuit text  NOT NULL,
  ref     text  NOT NULL,
  objet   jsonb NOT NULL,
  libelle text  NOT NULL,
  PRIMARY KEY (circuit, ref)
);
INSERT INTO public.assemblee_catalogue_illegal (circuit, ref, objet, libelle) VALUES
  ('armurerie_marche_noir', 'couteau',         '{"type":"arme","sousType":"blanche"}',  'Couteau de poche'),
  ('armurerie_marche_noir', 'revolver',        '{"type":"arme","sousType":"poing"}',    'Revolver .38'),
  ('armurerie_marche_noir', 'carabine_chasse', '{"type":"arme","sousType":"carabine"}', 'Carabine de chasse'),
  ('poison', 'parapluie', '{"type":"poison"}', 'Poison'),
  ('poison', 'ghb',       '{"type":"poison"}', 'Poison'),
  ('poison', 'polonium',  '{"type":"poison"}', 'Poison'),
  ('poison', 'vipere',    '{"type":"poison"}', 'Poison')
ON CONFLICT (circuit, ref) DO UPDATE SET objet = EXCLUDED.objet, libelle = EXCLUDED.libelle;
ALTER TABLE public.assemblee_catalogue_illegal ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.assemblee_catalogue_illegal FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.assemblee_catalogue_illegal TO service_role;

-- Appelee APRES une transaction illegale reussie. La vente est conservee dans tous les cas ; seule
-- sa qualification judiciaire est tranchee ici, a l'instant serveur. Idempotente par requete : un
-- double envoi ne produit jamais deux traces. L'acheteur ne peut incriminer que lui-meme.
CREATE OR REPLACE FUNCTION public.assemblee_achat_illegal(p_nom text, p_circuit text, p_ref text, p_requete text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rej     jsonb;
  v_cat     public.assemblee_catalogue_illegal%ROWTYPE;
  v_country text;
  v_res     jsonb;
BEGIN
  v_rej := public.assemblee_requete_ouvrir(p_requete, p_nom, 'achat_illegal');
  IF v_rej IS NOT NULL THEN RETURN v_rej; END IF;

  SELECT * INTO v_cat FROM public.assemblee_catalogue_illegal WHERE circuit = p_circuit AND ref = p_ref;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'objet_inconnu'));
  END IF;
  SELECT country INTO v_country FROM public.personnages WHERE name = p_nom;
  IF NOT FOUND THEN
    RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object('ok', false, 'raison', 'personnage_introuvable'));
  END IF;

  v_res := public.assemblee_transaction_interdite_interne(v_country, p_nom, NULL, v_cat.objet, v_cat.libelle, 1);
  RETURN public.assemblee_requete_clore(p_requete, jsonb_build_object(
    'ok', true, 'interdit', COALESCE((v_res ->> 'interdit')::boolean, false),
    'loi', v_res -> 'loi', 'acheteur', v_res -> 'acheteur',
    'dis', v_res -> 'acheteur' -> 'dis'));
END;
$$;


-- =====================================================================
-- 6. TRACE VENDEUR PAR COMMERCE — MEME MOTEUR, HORODATAGE REEL
-- =====================================================================
-- Toujours INTERNE (service_role) : a appeler depuis une transaction de vente serveur. Reecrite
-- sur assemblee_detecter_partie (une seule implementation de la detection) et sur l'entree en
-- vigueur reelle (adoptee_ts <= now()).
CREATE OR REPLACE FUNCTION public.assemblee_tracer_vente_interdite(
  p_commerce_id text,
  p_categorie   text,
  p_libelle     text,
  p_country     text DEFAULT 'republic'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_vendeur text;
  v_loi     jsonb;
  v_det     jsonb;
BEGIN
  SELECT NULLIF(e.data ->> 'proprietaire', 'PNJ') INTO v_vendeur FROM public.entreprises e WHERE e.id = p_commerce_id;
  IF v_vendeur IS NULL OR btrim(v_vendeur) = '' THEN
    RETURN jsonb_build_object('ok', true, 'vendeur', null, 'raison', 'commerce_pnj_ou_introuvable');
  END IF;

  SELECT jsonb_build_object('id', p.id, 'titre', p.titre, 'categorie', p.categorie, 'adoptee_ts', p.adoptee_ts)
    INTO v_loi
    FROM public.assemblee_propositions p
   WHERE p.country = p_country AND p.type = 'mecanique' AND p.statut = 'adoptee'
     AND p.categorie = p_categorie AND p.adoptee_ts IS NOT NULL AND p.adoptee_ts <= now()
   ORDER BY p.adoptee_ts, p.id LIMIT 1;
  IF v_loi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'categorie_non_interdite');
  END IF;

  v_det := public.assemblee_detecter_partie(v_vendeur, 'vente', v_loi, COALESCE(p_libelle, p_categorie), 1, false);
  IF v_det IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'vendeur', null, 'raison', 'vendeur_introuvable');
  END IF;

  RETURN jsonb_build_object('ok', true, 'detecte', v_det -> 'detecte',
    'convocation_creee', v_det -> 'convocation_creee', 'loi', v_loi ->> 'titre');
END;
$$;


-- =====================================================================
-- 7. FRET : LE LOT NE PEUT PAS ETRE VENDU S'IL CONTIENT UNE MARCHANDISE INTERDITE
-- =====================================================================
-- La vente d'un lot non reclame est exactement la transition 'a_vendre' -> 'vendue' de
-- caisses_fret, et son contenu vit en base (contenu_caisses_fret). Le trigger refuse cette
-- transition quel que soit l'ecrivain -- client, REST direct ou cron.
CREATE OR REPLACE FUNCTION public.assemblee_fret_vente_legale()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_loi jsonb;
BEGIN
  IF OLD.statut = 'a_vendre' AND NEW.statut = 'vendue' THEN
    SELECT public.assemblee_loi_en_vigueur(COALESCE(NEW.pays_destination, 'republic'), c.objet, now())
      INTO v_loi
      FROM public.contenu_caisses_fret c
     WHERE c.caisse_id = NEW.id
       AND COALESCE(c.quantite, 0) > 0
       AND public.assemblee_loi_en_vigueur(COALESCE(NEW.pays_destination, 'republic'), c.objet, now()) IS NOT NULL
     LIMIT 1;
    IF v_loi IS NOT NULL THEN
      RAISE EXCEPTION 'vente_interdite' USING DETAIL = (v_loi ->> 'titre');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assemblee_fret_vente_legale ON public.caisses_fret;
CREATE TRIGGER trg_assemblee_fret_vente_legale
  BEFORE UPDATE OF statut ON public.caisses_fret
  FOR EACH ROW EXECUTE FUNCTION public.assemblee_fret_vente_legale();


-- =====================================================================
-- 8. DROITS
-- =====================================================================
REVOKE ALL ON FUNCTION public.assemblee_objet_vise(text, jsonb)                              FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_loi_en_vigueur(text, jsonb, timestamptz)             FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_verifier_vente(jsonb, text)                          FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_detecter_partie(text, text, jsonb, text, integer, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_transaction_interdite_interne(text, text, text, jsonb, text, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_achat_illegal(text, text, text, text)                FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_tracer_vente_interdite(text, text, text, text)       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assemblee_fret_vente_legale()                                  FROM PUBLIC, anon, authenticated;

-- Lectures publiques (appelees depuis les fonctions ci-dessus sous l'identite de l'appelant, et par
-- les circuits de vente legale).
GRANT EXECUTE ON FUNCTION public.assemblee_objet_vise(text, jsonb)                  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_loi_en_vigueur(text, jsonb, timestamptz) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_verifier_vente(jsonb, text)              TO anon, authenticated, service_role;
-- Action joueur : l'acheteur ne peut incriminer que lui-meme.
GRANT EXECUTE ON FUNCTION public.assemblee_achat_illegal(text, text, text, text)    TO anon, authenticated, service_role;
-- Internes.
GRANT EXECUTE ON FUNCTION public.assemblee_detecter_partie(text, text, jsonb, text, integer, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_transaction_interdite_interne(text, text, text, jsonb, text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.assemblee_tracer_vente_interdite(text, text, text, text) TO service_role;

-- =====================================================================
-- FIN
-- =====================================================================
