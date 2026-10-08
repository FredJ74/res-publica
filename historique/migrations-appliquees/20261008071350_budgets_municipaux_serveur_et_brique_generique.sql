-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 8 OCTOBRE 2026
--
-- Registre Supabase : version 20261008071350, nom
-- `budgets_municipaux_serveur_et_brique_generique`.
--
-- LE CORPS CI-DESSOUS EST EXACTEMENT CELUI QUI A TOURNE. Il n'a pas ete recopie depuis le
-- brouillon : il a ete relu dans supabase_migrations.schema_migrations apres application, et son
-- empreinte md5 vaut 0b82381e3b3ce50916757c5831948ebe pour 66 780 octets. Le brouillon differait
-- de quatre lignes vides et d'une cedille -- c'est la version du registre qui fait foi, et c'est
-- celle-ci.
--
-- EPROUVEE AVANT D'ETRE APPLIQUEE. La partie dont une interruption aurait pu DUPLIQUER de
-- l'argent -- creation des caisses d'entrepot, puis retrait de la cle du blob -- a tourne dans
-- une transaction annulee avant toute application, et le controle de transaction lui-meme avait
-- ete prouve au prealable (BEGIN; CREATE TABLE; ROLLBACK; la table ne survivait pas). Mesure du
-- banc : ecart de conservation 0,0 FR.
--
-- CE QUE LA MESURE D'APRES A CONSTATE, hors de la transaction :
--   . masse des caisses 1 223 164 -> 1 239 635,5 FR, soit exactement +1 218 (ancienne tresorerie
--     municipale) et +15 253,5 (tresorerie des trois entrepots de vraies villes) ;
--   . 147 -> 150 caisses, les trois nouvelles portant 5 341 / 4 985 / 4 927,5 FR -- le demi-franc
--     de Montrouge a traverse, aucun arrondi n'a ete pratique ;
--   . budgets_municipaux : plus aucune cle `caisse`, `allocation` ni `derniereDistribJour` ;
--   . les entrepots de TEST (zzville-a, zzville-b, zztest) gardent leurs 99 706 FR dans leur
--     blob, intacts : ce ne sont pas des villes, on ne leur cree pas de caisse, et surtout on ne
--     leur retire pas la cle -- retirer sans migrer aurait detruit cet argent ;
--   . somme des parts, par ville : 100/100 exactement, en fraction et non en flottant ;
--   . aucune caisse negative, et l'argent des personnages inchange (23 403 FR).
-- =============================================================================

-- =============================================================================
-- LE CIRCUIT MUNICIPAL DE REPUBLIA PASSE AU SERVEUR ET A LA BRIQUE GENERIQUE
-- Chantier Supabase -- budgets municipaux -- 8 octobre 2026
-- =============================================================================
--
--   recettes municipales du jour  ->  repartition declaree  ->  commissariat / entrepot
--                                                              ... et la part conservee par
--                                                              la mairie, qui ne bouge pas
--
-- UNE SEULE TRESORERIE MUNICIPALE : caisses_batiments.<pays>_mairie_<ville>. Aucune
-- synchronisation entre deux soldes, aucun second moteur, aucun 40/40/20 code en dur, et plus
-- aucun navigateur dans la boucle.
--
-- -----------------------------------------------------------------------------
-- LA DISTINCTION QUI PORTE TOUT LE LOT : UNE BOURSE N'EST PAS UN COMPTEUR
-- -----------------------------------------------------------------------------
-- budgets_municipaux.data.caisse etait les DEUX A LA FOIS : la tresorerie de la commune, et
-- l'accumulateur de ce qui etait arrive depuis la derniere distribution. C'est cette confusion
-- qui a produit la panne de septembre, et c'est elle qu'on defait :
--
--   . L'ARGENT va dans caisses_batiments, immediatement, des qu'il est percu. Il n'attend pas.
--     Il n'existe donc aucun instant ou une recette municipale est percue et patiente quelque
--     part : elle est dans la tresorerie de la commune, qui est sous controle d'autorite,
--     journalisee, et pilotable par la brique generique.
--
--   . LA MESURE va dans recettes_municipales, une table de COMPTEURS datee. Elle ne porte pas
--     d'argent -- aucune fonction ne la debite jamais -- elle dit seulement COMBIEN est arrive
--     tel jour, par canal. La cascade de minuit la lit pour connaitre sa base.
--
-- Ce n'est donc pas une reservation, et ce n'est pas une seconde bourse. C'est un compteur
-- journalier, exactement ce que budgets_nationaux.data.reserveJour est au niveau national --
-- a ceci pres que reserveJour porte l'argent, et que ce compteur-ci n'en porte pas.
--
-- -----------------------------------------------------------------------------
-- LES TROIS CANAUX, ET POURQUOI LES TROIS SONT DES RECETTES MUNICIPALES
-- -----------------------------------------------------------------------------
-- Mesure faite dans le depot avant d'ecrire une ligne. Les trois creditaient
-- budgets_municipaux.data.caisse, et aucun ne creditait autre chose :
--
--   1  TAXE FONCIERE   -- cron de minuit, taux budgets_municipaux.data.tauxFoncier (defaut 5 %),
--                         assise sur la surface des terrains. Ecrite en JS par le cron.
--   2  LOYERS          -- prelever_loyer_bail, a minuit, pour les baux dont la destination
--                         attestee est « municipal ».
--   3  TAXE SUR LES TRANSACTIONS -- appliquer_taxe_transaction, en continu. C'est la moitie
--                         LOCALE d'une taxe a deux etages : `tauxLocal`, stocke dans le budget
--                         MUNICIPAL et fixe par le maire, va a la commune ; `tauxNational`,
--                         stocke dans le budget national, va a reserveJour. La symetrie est
--                         complete et deliberee -- la migration du 16 septembre 2026 l'ecrit
--                         noir sur blanc : « appliquer_taxe_transaction creditait le budget
--                         municipal ET la reserve nationale ».
--
-- La troisieme n'a donc jamais ete un prelevement autonome : c'est la part communale d'un impot
-- partage, et elle est aujourd'hui integralement redistribuee par la passe municipale. Ce lot
-- CONSERVE ce fait au lieu de le trancher a nouveau. Son seul changement : elle credite
-- desormais la vraie tresorerie, et sa mesure entre dans le compteur du jour.
--
-- -----------------------------------------------------------------------------
-- CE QUE CETTE MIGRATION NE FAIT PAS
-- -----------------------------------------------------------------------------
-- Aucun versement retroactif, aucun reequilibrage retroactif 40/40/20, aucune redistribution de
-- la tresorerie historique -- elle est TRANSFEREE telle quelle, pas repartie. Les circuits
-- national, Justice, Interieur et Defense ne sont pas touches. La Caserne, le QHS, les Douanes
-- et les tribunaux restent hors du circuit municipal. Aucun logement social, aucun jardin
-- ouvrier n'acquiert de depense. Aucun parametre economique n'est invente pour les trois autres
-- empires : ils n'ont aucune repartition municipale declaree, donc la cascade ne verse rien chez
-- eux -- absence de configuration, pas repli sur Republia.
--
-- LES VILLES DE TEST NE SONT PAS DES VILLES. zzville-a, zzville-b, zzville-cmr et le pays zztest
-- ne figurent pas dans le referentiel `villes`. Leurs entrepots gardent donc leur tresorerie la
-- ou elle est : on ne leur cree pas de caisse canonique, et surtout on ne retire pas la cle de
-- leur blob -- retirer sans migrer detruirait 99 706 FR. Ils sont hors circuit, et le restent.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. L'EMPREINTE FINANCIERE D'AVANT, RELEVEE DANS LA TRANSACTION
-- -----------------------------------------------------------------------------
-- La preuve de conservation ne se fait pas de memoire : la masse est mesuree ici, avant tout
-- mouvement, et reverifiee a la fin, dans la meme transaction. Une table temporaire disparait
-- avec elle.

CREATE TEMPORARY TABLE _avant ON COMMIT DROP AS
SELECT
  (SELECT coalesce(sum(CASE WHEN jsonb_typeof(data->'solde') = 'number'
                            THEN (data->>'solde')::numeric ELSE 0 END), 0)
     FROM public.caisses_batiments)                                        AS caisses,
  (SELECT count(*) FROM public.caisses_batiments)                          AS caisses_nb,
  (SELECT coalesce(sum(CASE WHEN jsonb_typeof(data->'caisse') = 'number'
                            THEN (data->>'caisse')::numeric ELSE 0 END), 0)
     FROM public.budgets_municipaux)                                       AS municipaux,
  (SELECT coalesce(sum(CASE WHEN jsonb_typeof(public.batiment_etat_lire(e.data)->'entrepot'->'caisse') = 'number'
                            THEN (public.batiment_etat_lire(e.data)->'entrepot'->>'caisse')::numeric
                            ELSE 0 END), 0)
     FROM public.batiments_etat e)                                         AS entrepots_tous,
  (SELECT coalesce(sum(CASE WHEN jsonb_typeof(public.batiment_etat_lire(e.data)->'entrepot'->'caisse') = 'number'
                            THEN (public.batiment_etat_lire(e.data)->'entrepot'->>'caisse')::numeric
                            ELSE 0 END), 0)
     FROM public.batiments_etat e
     JOIN public.villes v ON v.pays = e.country AND v.ville = e.city
    WHERE e.id LIKE '%\_entrepot-%')                                       AS entrepots_reels,
  (SELECT coalesce(sum(coalesce(arg,0)), 0) FROM public.personnages_donnees) AS personnages_arg;

-- -----------------------------------------------------------------------------
-- 1. LE COMPTEUR DES RECETTES DU JOUR -- UNE MESURE, PAS UNE BOURSE
-- -----------------------------------------------------------------------------
-- UNE LIGNE PAR (pays, ville, jour, canal), dont le montant s'ACCUMULE. Quatre lignes au plus
-- par commune et par jour : la table reste minuscule quel que soit le volume de transactions.
--
-- CE QUI GARANTIT QUE CE N'EST PAS UNE SECONDE TRESORERIE : aucune fonction de ce schema ne
-- soustrait jamais de cette table, et le CHECK montant > 0 l'interdit structurellement. On n'y
-- « prend » pas de l'argent : on y lit une somme. La seule lecture est celle de la cascade.

CREATE TABLE IF NOT EXISTS public.recettes_municipales (
  pays       text        NOT NULL,
  ville      text        NOT NULL,
  jour       date        NOT NULL,
  canal      text        NOT NULL,
  montant    numeric     NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT recettes_municipales_pkey PRIMARY KEY (pays, ville, jour, canal),
  CONSTRAINT recettes_municipales_pays_check    CHECK (pays <> ''),
  CONSTRAINT recettes_municipales_ville_check   CHECK (ville <> ''),
  CONSTRAINT recettes_municipales_canal_check   CHECK (canal IN ('taxe_fonciere', 'loyer', 'taxe_transaction')),
  CONSTRAINT recettes_municipales_montant_check CHECK (montant > 0)
);

COMMENT ON TABLE public.recettes_municipales IS
  'COMPTEUR des recettes municipales percues, par commune, par jour et par canal. Ce n''est PAS une tresorerie : aucune fonction n''en soustrait jamais, et le CHECK montant > 0 l''interdit. L''argent correspondant est, lui, deja dans caisses_batiments.<pays>_mairie_<ville>, credite a l''instant de la perception. Cette table dit seulement COMBIEN est arrive, pour que la cascade de minuit connaisse sa base. Equivalent municipal de budgets_nationaux.data.reserveJour, a ceci pres que reserveJour porte l''argent et que ce compteur n''en porte pas.';

ALTER TABLE public.recettes_municipales ENABLE ROW LEVEL SECURITY;

-- LECTURE PUBLIQUE, ASSUMEE. Les recettes d'une commune sont une donnee de finances publiques,
-- comme le sont deja ses taux. Ce n'est donc pas une policy dormante oubliee en USING(true) :
-- c'est une ouverture voulue, et elle ne porte que de la lecture.
DROP POLICY IF EXISTS recettes_municipales_lecture_publique ON public.recettes_municipales;
CREATE POLICY recettes_municipales_lecture_publique ON public.recettes_municipales
  FOR SELECT USING (true);

REVOKE ALL ON TABLE public.recettes_municipales FROM PUBLIC;
REVOKE ALL ON TABLE public.recettes_municipales FROM anon;
REVOKE ALL ON TABLE public.recettes_municipales FROM authenticated;
GRANT SELECT ON TABLE public.recettes_municipales TO anon;
GRANT SELECT ON TABLE public.recettes_municipales TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.recettes_municipales TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.recettes_municipales TO postgres;

-- -----------------------------------------------------------------------------
-- 2. LES ENTREPOTS RECOIVENT UNE VRAIE CAISSE CANONIQUE
-- -----------------------------------------------------------------------------
-- Leur tresorerie vivait dans batiments_etat.data.entrepot.caisse -- un nombre enfoui dans un
-- blob, qu'aucune primitive financiere ne sait deplacer. Elle devient une ligne de
-- caisses_batiments nommee <pays>_entrepot_<ville>, par la convention reguliere.
--
-- AUCUNE AUTORITE N'EST INVENTEE : caisses_autorites declare depuis le 5 octobre
-- ('entrepot', est_prefixe = true, {directeur_entrepot, maire_adjoint}). Le motif etait INERTE,
-- faute d'appelant. Il devient vivant, et caisse_territoire('entrepot_capitale', 'republic')
-- rend deja ('ville', 'capitale') sans qu'une ligne soit ajoutee -- verifie en base.
--
-- SEULES LES VRAIES VILLES. Le join sur `villes` est la garde : entrepots_par_ville contient
-- zzville-a et zzville-b, et un join naif aurait fabrique deux caisses canoniques contenant
-- 99 506 FR d'argent de test.
--
-- LE BLOB GARDE SON ENCODAGE ET SON STOCK. batiments_etat.data porte une CHAINE JSON (convention
-- declaree dans outils/baseline/encodage-blobs.json) : la reecriture repasse par
-- to_jsonb(...::text). Seule la cle `caisse` disparait ; `stock`, `prixManuel`, `desiderata`
-- restent intacts -- c'est du metier, pas de la tresorerie.

INSERT INTO public.caisses_batiments (id, data, updated_at)
SELECT e.country || '_entrepot_' || e.city,
       jsonb_build_object('solde',
         CASE WHEN jsonb_typeof(public.batiment_etat_lire(e.data)->'entrepot'->'caisse') = 'number'
              THEN (public.batiment_etat_lire(e.data)->'entrepot'->>'caisse')::numeric
              ELSE 0 END),
       now()
  FROM public.batiments_etat e
  JOIN public.villes v ON v.pays = e.country AND v.ville = e.city
 WHERE e.id LIKE '%\_entrepot-%'
   AND public.batiment_etat_lire(e.data) ? 'entrepot'
ON CONFLICT (id) DO NOTHING;

-- Le blob perd sa tresorerie, et garde tout le reste.
UPDATE public.batiments_etat e
   SET data = to_jsonb((public.batiment_etat_lire(e.data) #- '{entrepot,caisse}')::text),
       updated_at = now()
  FROM public.villes v
 WHERE v.pays = e.country AND v.ville = e.city
   AND e.id LIKE '%\_entrepot-%'
   AND public.batiment_etat_lire(e.data) #> '{entrepot,caisse}' IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3. L'ANCIENNE TRESORERIE MUNICIPALE REJOINT LA CAISSE MAIRIE, UNE FOIS
-- -----------------------------------------------------------------------------
-- Les deux magasins n'ont jamais eu la meme source : budgets_municipaux.data.caisse n'a recu que
-- des taxes et des loyers municipaux, la caisse mairie n'a recu que l'ancienne cle nationale. Le
-- SEUL chemin de l'un vers l'autre -- le virement communal du maire adjoint -- DEBITE le premier
-- en creditant le second : il deplace, il ne duplique pas. Le contenu est donc de l'argent
-- DISTINCT, et il est repris exactement une fois.
--
-- LA CAISSE PAYEUSE est resolue par salaire_caisse_de('maire', ...), seule regle qui connaisse
-- l'exception de nommage de la capitale (`mairie-capitale` au lieu de `mairie_capitale`). On ne
-- reecrit pas cette resolution ici.

-- UNE LIGNE HORS VILLE NE PEUT PAS ETRE REPRISE : elle n'a aucune caisse mairie ou aller. On
-- verifie donc qu'aucune ne porte d'argent AVANT de retirer la cle. republic_caserne existe
-- parce que getVilleKey() ne filtrait pas les zones speciales -- artefact deja consigne.
DO $$
DECLARE v_hors numeric;
BEGIN
  SELECT coalesce(sum(CASE WHEN jsonb_typeof(b.data->'caisse') = 'number'
                           THEN (b.data->>'caisse')::numeric ELSE 0 END), 0)
    INTO v_hors
    FROM public.budgets_municipaux b
   WHERE NOT EXISTS (SELECT 1 FROM public.villes v
                      WHERE b.id = v.pays || '_' || v.ville);
  IF v_hors <> 0 THEN
    RAISE EXCEPTION 'ARRET : une ligne municipale HORS VILLE porte % FR. Elle n''a pas de caisse mairie ou aller, et les perdre serait inacceptable.', v_hors;
  END IF;
END $$;

UPDATE public.caisses_batiments c
   SET data = coalesce(c.data, '{}'::jsonb) || jsonb_build_object('solde',
         (CASE WHEN jsonb_typeof(c.data->'solde') = 'number'
               THEN (c.data->>'solde')::numeric ELSE 0 END)
         + (CASE WHEN jsonb_typeof(b.data->'caisse') = 'number'
                 THEN (b.data->>'caisse')::numeric ELSE 0 END)),
       updated_at = now()
  FROM public.villes v
  JOIN public.budgets_municipaux b ON b.id = v.pays || '_' || v.ville
 WHERE c.id = public.salaire_caisse_de('maire', v.pays, v.ville)
   AND jsonb_typeof(b.data->'caisse') = 'number'
   AND (b.data->>'caisse')::numeric <> 0;

-- LES DEUX CLES CONCURRENTES DISPARAISSENT, sur TOUTES les lignes.
--   `caisse`     : c'etait la seconde bourse. Son contenu vient d'etre transfere.
--   `allocation` : c'etait la seconde regle de repartition -- six beneficiaires a 100 %, lue par
--                  la seule distribution cliente. La regle canonique est desormais
--                  repartitions_budgetaires, et laisser `allocation` en place serait exactement
--                  la situation que les arbitrages interdisent : deux regles concurrentes
--                  pouvant diverger.
--   `derniereDistribJour` : le marqueur d'idempotence de la distribution cliente. L'idempotence
--                  vit maintenant dans la cle primaire de repartitions_versements.
UPDATE public.budgets_municipaux
   SET data = data - 'caisse' - 'allocation' - 'derniereDistribJour',
       updated_at = now()
 WHERE data ?| ARRAY['caisse', 'allocation', 'derniereDistribJour'];

COMMENT ON TABLE public.budgets_municipaux IS
  'CONFIGURATION municipale, et plus une tresorerie. Porte les taux fixes par le maire (tauxFoncier, tauxLocal) et les indices de la ville. La tresorerie d''une mairie est caisses_batiments.<pays>_mairie_<ville>, et elle seule ; la mesure des recettes du jour est recettes_municipales. Les cles `caisse`, `allocation` et `derniereDistribJour` ont ete retirees le 8 octobre 2026 : la premiere etait une seconde bourse, la deuxieme une seconde regle de repartition, la troisieme le marqueur d''une distribution cliente qui n''existe plus.';

-- -----------------------------------------------------------------------------
-- 4. ENCAISSER UNE RECETTE MUNICIPALE : UN SEUL POINT D'ENTREE
-- -----------------------------------------------------------------------------
-- L'ARGENT VA DANS LA CAISSE, LE COMPTEUR N'EST QU'UNE MESURE. Une recette municipale credite
-- immediatement caisses_batiments.<pays>_mairie_<ville> -- la seule bourse -- et incremente en
-- meme temps la ligne du jour de recettes_municipales, qui ne porte pas d'argent mais DIT COMBIEN
-- est arrive. Les deux ecritures sont dans la meme transaction : il n'existe aucun instant ou
-- l'une a eu lieu sans l'autre.
--
-- AUCUN ARRONDI. Le montant passe tel quel : une taxe fonciere a 4 927,50 FR credite 4 927,50 FR.
-- Un floor() ici detruirait des centimes a chaque perception, et la preuve de conservation ne
-- serait plus exacte.
--
-- UNE RECETTE MUNICIPALE N'EXISTE QUE POUR UNE VRAIE VILLE. La caserne, le QHS et les villes de
-- test n'en sont pas : elles ne se voient pas ouvrir une bourse municipale par ce chemin, et la
-- fonction le DIT au lieu de l'ignorer -- l'appelant doit alors ne rien prelever.
--
-- RESERVEE AU SERVEUR. Un navigateur n'encaisse pas une recette publique. La porte interne est
-- ouverte pour le credit, parce que l'autorite de l'operation est celle du serveur et non celle
-- d'un poste.

CREATE OR REPLACE FUNCTION public.recette_municipale(p_pays text, p_ville text, p_montant numeric, p_canal text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_caisse text; v_jour date; v_rep jsonb;
BEGIN
  IF coalesce(btrim(p_pays), '') = '' OR coalesce(btrim(p_ville), '') = ''
     OR p_montant IS NULL OR p_montant <= 0
     OR p_canal NOT IN ('taxe_fonciere', 'loyer', 'taxe_transaction') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.villes v WHERE v.pays = p_pays AND v.ville = p_ville) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_ville', 'ville', p_ville);
  END IF;

  v_caisse := public.salaire_caisse_de('maire', p_pays, p_ville);
  IF v_caisse IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_mairie_introuvable', 'ville', p_ville);
  END IF;

  PERFORM set_config('rp.caisse_interne', 'on', true);
  v_rep := public.caisse_institution_mouvement(v_caisse, p_montant, true);
  PERFORM set_config('rp.caisse_interne', '', true);
  IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'credit_refuse', 'detail', v_rep);
  END IF;

  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  INSERT INTO public.recettes_municipales (pays, ville, jour, canal, montant, updated_at)
  VALUES (p_pays, p_ville, v_jour, p_canal, p_montant, now())
  ON CONFLICT (pays, ville, jour, canal)
    DO UPDATE SET montant = recettes_municipales.montant + excluded.montant,
                  updated_at = now();

  RETURN jsonb_build_object('ok', true, 'caisse', v_caisse, 'montant', p_montant,
                            'canal', p_canal, 'jour', v_jour);
END;
$function$;

COMMENT ON FUNCTION public.recette_municipale(text, text, numeric, text) IS
  'SEUL point d''entree d''une recette municipale. Credite caisses_batiments.<pays>_mairie_<ville> -- la SEULE tresorerie -- et incremente la ligne du jour de recettes_municipales, qui est une MESURE et non une bourse. Les deux ecritures sont dans la meme transaction. N''arrondit rien. Refuse toute ville absente du referentiel `villes` : la caserne, le QHS et les villes de test n''encaissent rien. RESERVEE AU SERVEUR.';

REVOKE ALL ON FUNCTION public.recette_municipale(text, text, numeric, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.recette_municipale(text, text, numeric, text) FROM anon;
REVOKE ALL ON FUNCTION public.recette_municipale(text, text, numeric, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.recette_municipale(text, text, numeric, text) TO service_role;

-- -----------------------------------------------------------------------------
-- 5. LES TROIS CANAUX PASSENT PAR CE POINT D'ENTREE
-- -----------------------------------------------------------------------------

-- 5a. TAXE SUR LES TRANSACTIONS. La moitie LOCALE rejoint la tresorerie communale ; la moitie
-- NATIONALE continue d'alimenter reserveJour, inchangee -- ce lot ne touche pas au national.
--
-- LA TAXE LOCALE N'EST PLUS PRELEVEE SI ELLE NE PEUT PAS ETRE ENCAISSEE. Auparavant le montant
-- etait retire du net du vendeur et le credit municipal etait conditionne a l'existence d'une
-- ligne de budget : pour une ville sans ligne, le vendeur payait une taxe qui n'arrivait nulle
-- part. Desormais le verdict d'encaissement commande : refus -> taxe locale a zero -> le vendeur
-- garde son argent. Aucune creation ni destruction possible.
CREATE OR REPLACE FUNCTION public.appliquer_taxe_transaction(p_pays text, p_ville text, p_montant_brut numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_cle_muni text := p_pays || '_' || p_ville;
  v_muni jsonb; v_nat jsonb; v_tl numeric; v_tn numeric;
  v_taxe_l numeric; v_taxe_n numeric; v_rec jsonb;
BEGIN
  SELECT data INTO v_muni FROM public.budgets_municipaux WHERE id = v_cle_muni FOR UPDATE;
  SELECT data INTO v_nat FROM public.budgets_nationaux WHERE id = p_pays FOR UPDATE;
  v_tl := coalesce((v_muni->>'tauxLocal')::numeric, 2);
  v_tn := coalesce((v_nat->>'tauxNational')::numeric, 2);
  v_taxe_l := round(p_montant_brut * v_tl / 100);
  v_taxe_n := round(p_montant_brut * v_tn / 100);

  IF v_taxe_l > 0 THEN
    v_rec := public.recette_municipale(p_pays, p_ville, v_taxe_l, 'taxe_transaction');
    IF NOT coalesce((v_rec->>'ok')::boolean, false) THEN
      v_taxe_l := 0;
    END IF;
  END IF;

  IF v_nat IS NOT NULL THEN
    UPDATE public.budgets_nationaux
       SET data = jsonb_set(v_nat, '{reserveJour}', to_jsonb(coalesce((v_nat->>'reserveJour')::numeric,0) + v_taxe_n)),
           updated_at = now()
     WHERE id = p_pays;
  END IF;

  RETURN jsonb_build_object('net', p_montant_brut - v_taxe_l - v_taxe_n,
    'taxeLocale', v_taxe_l, 'taxeNationale', v_taxe_n, 'tauxLocal', v_tl, 'tauxNational', v_tn);
END; $function$;

-- 5b. LOYERS A DESTINATION MUNICIPALE. Le seul changement est la destination de l'argent : il va
-- a la tresorerie de la commune au lieu du blob. Le reste de la fonction -- anti-rejeu par
-- jourPaiement, destination attestee, verrous, ardoise d'impaye -- est repris A L'IDENTIQUE
-- depuis pg_get_functiondef, sans retouche.
--
-- FAIL-CLOSED COMME LES AUTRES BRANCHES : si l'encaissement est refuse, on leve
-- `destination_introuvable` plutot que de debiter le locataire au profit de personne. C'est
-- exactement ce que font deja les branches titulaire_murs et caisse_batiment.
CREATE OR REPLACE FUNCTION public.prelever_loyer_bail(p_bail_id text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_bail        locations_actives%ROWTYPE;
  v_data        jsonb;
  v_locataire   text;
  v_prix        numeric;
  v_dest        jsonb;
  v_dest_type   text;
  v_pays        text;
  v_ville       text;
  v_building    text;
  v_arg         numeric;
  v_jour        text := to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD');
  v_cle         text;
  v_titulaire   text;
  v_orga_id     text;
  v_orga_data   text;
  v_maj         integer;
  v_rec         jsonb;
BEGIN
  SELECT *
  INTO v_bail
  FROM locations_actives
  WHERE id = p_bail_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'bail_absent';
  END IF;

  v_data      := v_bail.data;
  v_locataire := v_data ->> 'locataire';
  v_prix      := COALESCE((v_data ->> 'prix')::numeric, 0);

  -- Anti-rejeu : un seul prélèvement par bail et par jour réel.
  IF (v_data ->> 'jourPaiement') = v_jour THEN
    RETURN 'deja_preleve';
  END IF;

  -- Usages sans loyer réel.
  IF v_prix <= 0
     OR (v_data ->> 'chambreClinique') = 'true'
     OR v_locataire IS NULL
  THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;

    RETURN 'ignore_sans_loyer';
  END IF;

  -- DESTINATION ATTESTEE (20 septembre 2026). Elle n'est plus lue dans le bail --
  -- ecriture directe falsifiable -- mais DERIVEE du local, par la meme regle que le
  -- client (destinationLoyerPourLocal). Le champ destinationLoyer du bail n'est plus
  -- qu'informatif. Fail-closed inchange : pas de destination -> pas de mouvement.
  v_dest := public.bail_destination_attestee(v_data);
  IF v_dest IS NULL THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;
    RETURN 'ignore_sans_loyer';
  END IF;

  IF v_dest IS NULL OR jsonb_typeof(v_dest) = 'null' THEN
    UPDATE locations_actives
    SET data = v_data || jsonb_build_object('jourPaiement', v_jour)
    WHERE id = p_bail_id;

    RETURN 'ignore_sans_loyer';
  END IF;

  v_dest_type := v_dest ->> 'type';

  -- Verrou du locataire.
  SELECT arg
  INTO v_arg
  FROM personnages
  WHERE name = v_locataire
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN 'locataire_absent';
  END IF;

  -- Impayé.
  IF COALESCE(v_arg, 0) < v_prix THEN
    IF COALESCE((v_data ->> 'avertissement')::boolean, false) THEN
      RETURN 'expulsion_requise';
    END IF;

    UPDATE locations_actives
    SET data = v_data
      || jsonb_build_object(
           'avertissement', true,
           'jourPaiement', v_jour
         )
    WHERE id = p_bail_id;

    RETURN 'avertissement';
  END IF;

  -- Crédit de la destination.
  IF v_dest_type = 'municipal' THEN

    v_pays  := COALESCE(v_dest ->> 'pays',  v_data ->> 'country');
    v_ville := COALESCE(v_dest ->> 'ville', v_data ->> 'city');

    v_rec := public.recette_municipale(v_pays, v_ville, v_prix, 'loyer');
    IF NOT COALESCE((v_rec ->> 'ok')::boolean, false) THEN
      RAISE EXCEPTION 'destination_introuvable';
    END IF;

  ELSIF v_dest_type = 'titulaire_murs' THEN

    -- Le titulaire explicite n'est PLUS lu : c'etait la porte par laquelle un bail
    -- falsifie redirigeait le loyer. Le proprietaire ACTUEL fait foi, toujours.
    v_titulaire := NULL;

    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      SELECT (data::jsonb ->> 'proprietaire')
      INTO v_titulaire
      FROM terrains_etat
      WHERE country = (v_data ->> 'country')
        AND building_id = (v_data ->> 'buildingId');
    END IF;

    IF v_titulaire IS NULL OR v_titulaire = '' THEN
      RAISE EXCEPTION 'destination_introuvable';
    END IF;

    -- Organisation propriétaire.
    IF left(v_titulaire, 5) = 'orga:' THEN

      v_orga_id := substr(v_titulaire, 6);

      IF v_orga_id = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      SELECT data
      INTO v_orga_data
      FROM organisations
      WHERE id = v_orga_id
      FOR UPDATE;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      IF v_orga_data IS NULL OR btrim(v_orga_data) = '' THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

      UPDATE organisations
      SET data = jsonb_set(
                   v_orga_data::jsonb,
                   '{caisse}',
                   to_jsonb(
                     COALESCE(
                       (v_orga_data::jsonb ->> 'caisse')::numeric,
                       0
                     ) + v_prix
                   )
                 )::text
      WHERE id = v_orga_id;

    ELSE

      -- PJ propriétaire, avec compatibilité ancien format nom brut.
      IF left(v_titulaire, 3) = 'pj:' THEN
        v_titulaire := substr(v_titulaire, 4);
      END IF;

      UPDATE personnages
      SET arg = COALESCE(arg, 0) + v_prix
      WHERE name = v_titulaire;

      GET DIAGNOSTICS v_maj = ROW_COUNT;

      IF v_maj = 0 THEN
        RAISE EXCEPTION 'destination_introuvable';
      END IF;

    END IF;

  ELSIF v_dest_type = 'caisse_batiment' THEN

    v_building := COALESCE(
      v_dest ->> 'buildingId',
      v_data ->> 'buildingId'
    );

    v_cle := (v_data ->> 'country') || '_' || v_building;

    UPDATE caisses_batiments
    SET data = jsonb_set(
                 COALESCE(data, '{}'::jsonb),
                 '{solde}',
                 to_jsonb(
                   COALESCE((data ->> 'solde')::numeric, 0) + v_prix
                 )
               ),
        updated_at = now()
    WHERE id = v_cle;

    GET DIAGNOSTICS v_maj = ROW_COUNT;

    IF v_maj = 0 THEN
      INSERT INTO caisses_batiments (id, data, updated_at)
      VALUES (
        v_cle,
        jsonb_build_object('solde', v_prix),
        now()
      );
    END IF;

  ELSE
    RAISE EXCEPTION 'destination_introuvable';
  END IF;

  -- Débit du locataire seulement après crédit valide.
  UPDATE personnages
  SET arg = COALESCE(arg, 0) - v_prix
  WHERE name = v_locataire;

  UPDATE locations_actives
  SET data = (v_data - 'avertissement')
    || jsonb_build_object(
         'jourPaiement', v_jour,
         'dernierLoyerPaye', v_jour
       )
  WHERE id = p_bail_id;

  RETURN 'paye';
END;
$function$;

-- -----------------------------------------------------------------------------
-- 6. LE REVERSEMENT D'ENTREPOT LIT DESORMAIS LA VRAIE CAISSE
-- -----------------------------------------------------------------------------
-- L'autorite et la territorialite de entrepot_virement_mairie ne changent PAS d'une ligne :
-- directeur_entrepot de CET entrepot, dans SA ville, et la mairie destinataire est resolue par
-- salaire_caisse_de('maire', pays, ville). Le directeur n'acquiert aucun pouvoir sur les taux
-- municipaux -- il ne touche qu'a sa propre caisse.
--
-- CE QUI CHANGE : la tresorerie lue et debitee est <pays>_entrepot_<ville> et non plus le blob.
-- Le mouvement devient donc un transfert entre deux CAISSES, par la primitive verrouillee, dans
-- une seule transaction -- au lieu d'un jsonb_set suivi d'un credit.
--
-- FAIL-CLOSED SUR LES VILLES DE TEST : un entrepot sans caisse canonique -- zzville-a, zzville-b,
-- zztest -- rend `caisse_entrepot_non_declaree` au lieu de reverser zero en silence. Leur
-- tresorerie est restee dans leur blob, intacte, et ce chemin ne la touche pas.
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
  -- L'identifiant est <pays>_<ville>_<batiment> : on en derive pays et ville.
  v_pays  := split_part(p_entrepot_id, '_', 1);
  v_ville := split_part(p_entrepot_id, '_', 2);
  IF v_pays = '' OR v_ville = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_invalide');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.batiments_etat e WHERE e.id = p_entrepot_id) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'entrepot_introuvable');
  END IF;

  -- LA CAISSE CANONIQUE, et le verrou de ligne qui serialise deux reversements simultanes.
  v_caisse_id := v_pays || '_entrepot_' || v_ville;
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
  -- echouait, la levee annule le debit : la transaction interne est la frontiere.
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
-- 7. LA REPARTITION MUNICIPALE DECLAREE : 40 / 40 / 20, VALEURS INITIALES
-- -----------------------------------------------------------------------------
-- TROIS BENEFICIAIRES PAR VILLE, et aucun croisement territorial : chaque ville finance son
-- commissariat, son entrepot et sa propre mairie. Les tribunaux restent au Ministere de la
-- Justice, les Douanes a l'Interieur, la Caserne a la Defense -- aucun ne reapparait ici.
--
-- 40 / 40 / 20 SONT DES VALEURS INITIALES, PAS DES TAUX PERMANENTS. Le maire modifie librement
-- les TROIS parts, la sienne comprise : 20 % n'est ni un minimum, ni une reserve obligatoire, ni
-- une valeur protegee. La seule contrainte est que la somme fasse exactement 100 %, verifiee en
-- fractions exactes par budget_part_totale().
--
-- LA TROISIEME LIGNE A POUR BENEFICIAIRE SA PROPRE SOURCE. C'est le motif deja pose pour le
-- Ministere de l'Economie et des Finances : la part est journalisee -- le circuit reste lisible --
-- mais jamais transferee, puisqu'on ne se vire pas de l'argent a soi-meme. C'est ce qui empeche
-- la boucle, et c'est pourquoi aucun mecanisme nouveau n'est necessaire pour « la part conservee
-- par la mairie ».
--
-- LES IDENTIFIANTS NE SONT PAS RECOPIES A LA MAIN. Le suffixe de la caisse mairie vient de
-- salaire_caisse_de(), seule regle qui connaisse l'exception `mairie-capitale` ; les deux autres
-- se composent par la convention reguliere. Ajouter une ville au referentiel suffirait.
--
-- CE QUE LES QUATRE EQUIPEMENTS PERDENT, ET OU ILS LE RETROUVENT. L'ancienne cle `allocation`
-- financait six beneficiaires : commissariat 20, multimodal 15, stade 15, marche 15,
-- dispensaire 20, tribunal 15. Le tribunal etait un DOUBLON -- le Ministere de la Justice le
-- finance depuis le chantier 4F, a un tiers chacun. Les quatre autres passent d'un financement
-- RECURRENT AUTOMATIQUE a un financement DISCRETIONNAIRE par le maire, depuis les 20 % qu'il
-- conserve : l'ecran « Financer un batiment communal » existe deja et propose exactement ces
-- categories. Ce n'est donc pas une suppression de financement, c'est un deplacement de la
-- decision vers l'elu.

INSERT INTO public.repartitions_budgetaires
  (pays, source, beneficiaire, part_numerateur, part_denominateur, poste_autorite, rang, libelle, note)
SELECT 'republic',
       regexp_replace(public.salaire_caisse_de('maire', 'republic', vi.ville), '^republic_', ''),
       b.beneficiaire, b.num, 100, 'maire', b.rang,
       b.libelle || ' — ' || vi.nom,
       'ARBITRAGE DU 8 OCTOBRE 2026 : valeurs INITIALES de Republia, 40/40/20. Le maire modifie librement les trois parts, la sienne comprise ; la seule contrainte est une somme de 100 % exactement.'
  FROM public.villes vi
  CROSS JOIN (VALUES
      ('commissariat_', 40, 1, 'Commissariat'),
      ('entrepot_',     40, 2, 'Entrepôt municipal'),
      (NULL,            20, 3, 'Caisse propre de la mairie')
    ) AS t(prefixe, num, rang, libelle)
  CROSS JOIN LATERAL (SELECT
      CASE WHEN t.prefixe IS NULL
           THEN regexp_replace(public.salaire_caisse_de('maire', 'republic', vi.ville), '^republic_', '')
           ELSE t.prefixe || vi.ville END AS beneficiaire,
      t.num, t.rang, t.libelle) AS b
 WHERE vi.pays = 'republic'
   AND public.salaire_caisse_de('maire', 'republic', vi.ville) IS NOT NULL
ON CONFLICT (pays, source, beneficiaire) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 8. L'AUTORITE SUR LES TAUX DEVIENT TERRITORIALE
-- -----------------------------------------------------------------------------
-- IL N'Y A QU'UN MINISTRE DES FINANCES, MAIS IL Y A TROIS MAIRES. budget_repartition_fixer ne
-- verifiait que l'INTITULE du poste : `poste_autorite = 'maire'` aurait donc laisse le maire de
-- Luthecia fixer les taux de Montrouge. Le trou n'existait pas tant que toutes les sources
-- etaient nationales ; il s'ouvre avec ce lot, et on le ferme dans le meme mouvement.
--
-- LA REGLE EST GENERIQUE, PAS MUNICIPALE : des que caisse_territoire() classe la source comme
-- une caisse de VILLE, la ville du poste de l'acteur doit etre cette ville. Un territoire
-- INDETERMINE est refuse -- fail-closed : on ne fixe pas les taux d'une caisse dont on ne sait
-- pas de qui elle releve.
CREATE OR REPLACE FUNCTION public.budget_repartition_fixer(p_source text, p_beneficiaire text, p_part numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; r record;
  v_part numeric; v_somme numeric;
  v_anc_num numeric; v_anc_den numeric; v_num numeric; v_den numeric;
  v_portee text; v_ville_source text; v_ville_acteur text;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(country,'republic'), poste->>'id' INTO v_pays, v_poste
    FROM public.personnages_donnees WHERE name = v_moi;

  SELECT * INTO r FROM public.repartitions_budgetaires
   WHERE pays = v_pays AND source = p_source AND beneficiaire = p_beneficiaire;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'repartition_non_declaree',
                              'source', p_source, 'beneficiaire', p_beneficiaire);
  END IF;
  IF v_poste IS DISTINCT FROM r.poste_autorite THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'poste_requis', r.poste_autorite);
  END IF;

  -- AUTORITE TERRITORIALE (8 octobre 2026). Voir le commentaire au-dessus de la fonction.
  SELECT t.portee, t.ville INTO v_portee, v_ville_source
    FROM public.caisse_territoire(p_source, v_pays) t;
  IF v_portee = 'ville' THEN
    SELECT coalesce(a.poste_city, '') INTO v_ville_acteur
      FROM public.acteur_poste_courant() a LIMIT 1;
    IF coalesce(v_ville_acteur, '') IS DISTINCT FROM v_ville_source THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_sa_commune',
                                'ville_requise', v_ville_source,
                                'ville_du_poste', v_ville_acteur);
    END IF;
  ELSIF v_portee IS DISTINCT FROM 'national' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'territoire_indetermine',
                              'source', p_source);
  END IF;

  v_part := round(coalesce(p_part, 0)::numeric, 4);
  IF v_part < 0 OR v_part > 100 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'part_hors_bornes');
  END IF;

  -- LA SOMME NE DEPASSE JAMAIS LE TOUT. Verifiee ICI, au serveur : une somme a 110 % versee par
  -- un client modifie distribuerait plus que les recettes.
  --
  -- LA COMPARAISON NE DIVISE PAS. On ecrit la ligne, on demande a budget_part_totale() la somme
  -- exacte de la source, et on compare numerateur et denominateur. Si le total depasse, on
  -- RESTAURE l'ancienne valeur et on refuse -- la verification est donc faite sur l'etat REEL,
  -- pas sur une simulation qui pourrait differer. Tout se passe dans une transaction : un refus
  -- ne laisse aucune trace.
  -- L'ancienne valeur est deja dans `r`, lu au debut : pas de seconde lecture.
  v_anc_num := r.part_numerateur;
  v_anc_den := r.part_denominateur;

  UPDATE public.repartitions_budgetaires
     SET part_numerateur = trim_scale(v_part), part_denominateur = 100
   WHERE pays = v_pays AND source = p_source AND beneficiaire = p_beneficiaire;

  SELECT numerateur, denominateur INTO v_num, v_den
    FROM public.budget_part_totale(v_pays, p_source);
  IF v_num > v_den THEN
    UPDATE public.repartitions_budgetaires
       SET part_numerateur = v_anc_num, part_denominateur = v_anc_den
     WHERE pays = v_pays AND source = p_source AND beneficiaire = p_beneficiaire;
    RETURN jsonb_build_object('ok', false, 'raison', 'somme_depasse_cent',
                              'somme_obtenue', round(v_num * 100 / v_den, 4));
  END IF;
  v_somme := round(v_num * 100 / v_den, 4);

  RETURN jsonb_build_object('ok', true, 'pays', v_pays, 'source', p_source,
                            'beneficiaire', p_beneficiaire, 'part', v_part,
                            'somme', v_somme);
END;
$function$;

-- -----------------------------------------------------------------------------
-- 9. LA CASCADE MUNICIPALE DE MINUIT
-- -----------------------------------------------------------------------------
-- UNE SEULE SOURCE DE VERITE POUR LA BASE : la somme des lignes du jour de
-- recettes_municipales. Pas de solde lu, pas de delta calcule entre deux releves, pas de champ a
-- remettre a zero. Si rien n'est arrive aujourd'hui, la base est nulle et rien ne bouge.
--
-- POURQUOI LA BASE N'EST PAS LE SOLDE DE LA CAISSE MAIRIE. Parce que la mairie CONSERVE 20 % : son
-- solde s'accumule d'un jour sur l'autre. Repartir le solde reviendrait a redistribuer chaque
-- nuit ce qu'elle a deja mis de cote -- une boucle qui viderait la commune au profit de son
-- commissariat et de son entrepot.
--
-- L'IDEMPOTENCE EST ENTIEREMENT DELEGUEE. budget_repartir() ecrit dans
-- repartitions_versements(pays, source, beneficiaire, jour) dont la cle primaire porte le jour :
-- un second passage leve une violation d'unicite et ne verse rien. Il n'y a donc AUCUN marqueur
-- a poser ici, et rien qu'une ecriture avalee puisse perdre.
--
-- FAIL-CLOSED PAR EMPIRE ET PAR VILLE. Une ville sans repartition declaree est ignoree avec son
-- motif : les trois autres empires n'ont aucune ligne municipale, la cascade ne leur verse donc
-- rien et ne retombe JAMAIS sur la configuration de Republia. Absence de configuration n'est pas
-- un defaut a combler, c'est une reponse.

CREATE OR REPLACE FUNCTION public.budget_municipal_cascade(p_pays text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  r record; v_caisse text; v_source text; v_base numeric; v_rep jsonb;
  v_villes jsonb := '[]'::jsonb; v_verse numeric := 0; v_conserve numeric := 0;
BEGIN
  IF NOT public.est_appel_serveur() THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reserve_au_serveur');
  END IF;
  IF coalesce(btrim(p_pays), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  FOR r IN SELECT v.ville, v.nom FROM public.villes v WHERE v.pays = p_pays ORDER BY v.ville
  LOOP
    v_caisse := public.salaire_caisse_de('maire', p_pays, r.ville);
    IF v_caisse IS NULL THEN
      v_villes := v_villes || jsonb_build_array(jsonb_build_object(
        'ville', r.ville, 'raison', 'caisse_mairie_introuvable'));
      CONTINUE;
    END IF;
    v_source := regexp_replace(v_caisse, '^' || p_pays || '_', '');

    IF NOT EXISTS (SELECT 1 FROM public.repartitions_budgetaires b
                    WHERE b.pays = p_pays AND b.source = v_source) THEN
      v_villes := v_villes || jsonb_build_array(jsonb_build_object(
        'ville', r.ville, 'raison', 'aucune_repartition_declaree'));
      CONTINUE;
    END IF;

    SELECT coalesce(sum(m.montant), 0) INTO v_base
      FROM public.recettes_municipales m
     WHERE m.pays = p_pays AND m.ville = r.ville AND m.jour = v_jour;

    v_rep := public.budget_repartir(p_pays, v_source, v_base);
    v_verse    := v_verse    + coalesce((v_rep->>'verse')::numeric, 0);
    v_conserve := v_conserve + coalesce((v_rep->>'conserve')::numeric, 0);
    v_villes := v_villes || jsonb_build_array(jsonb_build_object(
      'ville', r.ville, 'nom', r.nom, 'source', v_source, 'base', v_base,
      'repartition', v_rep));
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'pays', p_pays, 'jour', v_jour,
                            'verse', v_verse, 'conserve', v_conserve, 'villes', v_villes);
END;
$function$;

COMMENT ON FUNCTION public.budget_municipal_cascade(text) IS
  'Cascade municipale de minuit : pour chaque VRAIE ville du pays, repartit les recettes municipales DU JOUR -- somme des lignes de recettes_municipales -- selon repartitions_budgetaires, par la brique generique budget_repartir. La base n''est jamais le solde de la caisse mairie, qui accumule la part conservee. L''idempotence vit dans la cle primaire de repartitions_versements. Une ville sans repartition declaree est ignoree : aucun repli sur la configuration de Republia. RESERVEE AU SERVEUR.';

REVOKE ALL ON FUNCTION public.budget_municipal_cascade(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.budget_municipal_cascade(text) FROM anon;
REVOKE ALL ON FUNCTION public.budget_municipal_cascade(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.budget_municipal_cascade(text) TO service_role;

-- -----------------------------------------------------------------------------
-- 10. LE VIREMENT COMMUNAL DEVIENT UN VRAI MOUVEMENT ENTRE DEUX CAISSES
-- -----------------------------------------------------------------------------
-- LE CORRECTIF DU 8 OCTOBRE (3359c38) A CESSE DE DETRUIRE DE L'ARGENT, SANS RENDRE L'OPERATION
-- TRANSACTIONNELLE. Il ordonnait « credit confirme puis debit », ce qui ferme le cas couteux mais
-- laisse ouvert son inverse : credit passe, sauvegarde de l'assiette refusee, et la commune garde
-- une somme deja versee. Tant que la mairie n'avait pas de vraie caisse, cela ne pouvait pas se
-- fermer : on ne rend pas atomique une ecriture sur un blob et un appel de RPC.
--
-- MAINTENANT QUE LES DEUX COTES SONT DES CAISSES, le mouvement se dit en une transaction. Le
-- debit et le credit sont dans le MEME bloc, et une levee a l'interieur du bloc annule le debit :
-- il n'existe aucune fenetre ou l'argent a quitte la mairie sans arriver au batiment, ni
-- l'inverse.
--
-- AUTORITE : maire ou maire adjoint, et la ville du poste commande. La cible doit etre une caisse
-- de SA commune -- caisse_territoire() le dit -- donc un adjoint de Luthecia ne finance pas le
-- commissariat de Montrouge, et il ne peut pas non plus viser une caisse nationale.
CREATE OR REPLACE FUNCTION public.mairie_virement_batiment(p_building_id text, p_montant numeric)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  a record; v_source text; v_cible text; v_montant numeric;
  v_portee text; v_ville_cible text; v_rep jsonb; v_raison text;
BEGIN
  IF public.mon_personnage() IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT * INTO a FROM public.acteur_poste_courant() LIMIT 1;
  IF NOT FOUND OR coalesce(a.poste_id, '') NOT IN ('maire', 'maire_adjoint') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'autorite_insuffisante',
                              'postes_requis', jsonb_build_array('maire', 'maire_adjoint'));
  END IF;
  IF coalesce(a.poste_city, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'commune_inconnue');
  END IF;
  IF coalesce(btrim(p_building_id), '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'parametres_invalides');
  END IF;

  v_montant := floor(coalesce(p_montant, 0));
  IF v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  v_source := public.salaire_caisse_de('maire', a.pays, a.poste_city);
  IF v_source IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_mairie_introuvable');
  END IF;

  -- LA CIBLE EST DANS SA COMMUNE, ou nulle part.
  SELECT t.portee, t.ville INTO v_portee, v_ville_cible
    FROM public.caisse_territoire(p_building_id, a.pays) t;
  IF v_portee IS DISTINCT FROM 'ville' OR v_ville_cible IS DISTINCT FROM a.poste_city THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'hors_de_sa_commune',
                              'ville_du_poste', a.poste_city, 'ville_cible', v_ville_cible,
                              'portee', v_portee);
  END IF;

  v_cible := a.pays || '_' || p_building_id;
  IF v_cible = v_source THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cible_est_la_source');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.caisses_batiments c WHERE c.id = v_cible) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_cible_inconnue', 'caisse', v_cible);
  END IF;

  -- DEBIT ET CREDIT DANS LE MEME SOUS-BLOC. Le bloc EXCEPTION cree un point de reprise :
  -- toute levee a l'interieur annule le debit, et aucun etat intermediaire ne survit.
  BEGIN
    PERFORM set_config('rp.caisse_interne', 'on', true);
    v_rep := public.caisse_institution_mouvement(v_source, -v_montant, true);
    IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'RP_VIREMENT:%', coalesce(v_rep->>'raison', 'debit_refuse');
    END IF;
    v_rep := public.caisse_institution_mouvement(v_cible, v_montant, true);
    IF NOT coalesce((v_rep->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'RP_VIREMENT:%', coalesce(v_rep->>'raison', 'credit_refuse');
    END IF;
    PERFORM set_config('rp.caisse_interne', '', true);
  EXCEPTION WHEN raise_exception THEN
    v_raison := SQLERRM;
    -- 'RP_VIREMENT:' fait douze caracteres ; le motif commence donc au treizieme.
    IF left(v_raison, 12) = 'RP_VIREMENT:' THEN
      v_raison := substr(v_raison, 13);
    END IF;
    RETURN jsonb_build_object('ok', false, 'raison', v_raison, 'rien_na_bouge', true);
  END;

  RETURN jsonb_build_object('ok', true, 'source', v_source, 'cible', v_cible,
                            'montant', v_montant, 'solde_cible', (v_rep->>'solde')::numeric);
END;
$function$;

COMMENT ON FUNCTION public.mairie_virement_batiment(text, numeric) IS
  'Virement ponctuel de la caisse de la mairie vers la caisse d''un batiment de SA commune, par le maire ou son adjoint. Debit et credit dans la meme transaction : aucune fenetre ou l''argent a quitte la mairie sans arriver, ni l''inverse. La cible doit etre territorialement dans la ville du poste -- une caisse nationale ou d''une autre commune est refusee.';

REVOKE ALL ON FUNCTION public.mairie_virement_batiment(text, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mairie_virement_batiment(text, numeric) FROM anon;
GRANT EXECUTE ON FUNCTION public.mairie_virement_batiment(text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mairie_virement_batiment(text, numeric) TO service_role;

-- -----------------------------------------------------------------------------
-- 11. UN SALAIRE SE PAIE JUSQU'AU DISPONIBLE, ET LE JOURNAL DIT CE QUI A ETE PAYE
-- -----------------------------------------------------------------------------
-- ARBITRAGE DU 8 OCTOBRE 2026 : caisse insuffisante -> paiement PARTIEL jusqu'au disponible ;
-- jamais de negatif, jamais de dette, jamais de creation monetaire. La fonction refusait
-- jusqu'ici en bloc (`caisse_insuffisante`) : un maire dont la commune avait 700 FR sur 800 ne
-- touchait rien du tout.
--
-- LA REGLE EST APPLIQUEE A TOUS LES SALAIRES CIVILS, PAS AUX SEULS ELUS MUNICIPAUX. En limiter
-- l'effet a deux postes aurait introduit une exception dans une fonction generique, et le depot
-- declare deja cette doctrine ailleurs : caisse_institution_mouvement_plafonne existe
-- precisement pour « les virements, salaires et reparations qui tolerent un montant reduit ».
-- C'etait `salaire_civil_percevoir` qui faisait exception, pas l'inverse.
--
-- PAS DE DETTE, DONC PAS DE RELIQUAT. La cle d'idempotence reste le jour : un salaire paye
-- partiellement aujourd'hui est paye pour aujourd'hui. Le complement ne sera jamais reclame --
-- c'est exactement ce que « jamais de dette » signifie.
--
-- LE JOURNAL EST CORRIGE APRES COUP, A LA VALEUR REELLEMENT VERSEE. L'insertion a lieu avant le
-- mouvement -- c'est elle qui tient le verrou anti-rejeu -- donc elle porte d'abord le montant
-- DU. Si le versement est partiel, la ligne est mise a jour : salaires_civils_verses ne doit
-- jamais affirmer un montant que la caisse n'a pas paye.
--
-- EN FRANCS ENTIERS. Une caisse peut porter des centimes (un entrepot a 4 927,50 FR) ; un salaire
-- ne les emporte pas. floor() garantit que le versement est un entier et que la caisse ne devient
-- jamais negative.
CREATE OR REPLACE FUNCTION public.salaire_civil_percevoir()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_moi text; v_pays text; v_poste text; v_ville text; v_grade text;
  v_jour date; v_id text; v_cle text; v_origine text; v_montant integer;
  v_offres jsonb; v_offre text; v_caisse text; v_solde numeric;
  v_arg numeric; v_liquide numeric; v_paye numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;
  SELECT coalesce(country,'republic'), poste ->> 'id',
         public.salaire_ville_du_poste(poste ->> 'id', poste ->> 'city')
    INTO v_pays, v_poste, v_ville
    FROM public.personnages_donnees WHERE name = v_moi;
  v_grade := public.militaire_grade_effectif(v_moi);
  IF v_grade IS NOT NULL OR coalesce(v_poste,'') IN ('soldat','lieutenant','capitaine','commandant') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'paye_par_la_caserne');
  END IF;
  IF v_poste IS NOT NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s
     WHERE s.pays = v_pays AND s.cle = v_poste AND s.categorie = 'poste';
  END IF;
  IF v_cle IS NULL THEN
    SELECT coalesce(e.data -> 'offres', e.data -> 'bne' -> 'offres')
      INTO v_offres FROM public.batiments_etat e WHERE e.id = v_pays || '_national_bne';
    IF v_offres IS NOT NULL AND jsonb_typeof(v_offres) = 'object' THEN
      SELECT t.k INTO v_offre
        FROM jsonb_each(v_offres) AS t(k, v)
        WHERE EXISTS (
          SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(t.v)='array' THEN t.v ELSE '[]'::jsonb END) o
           WHERE o ->> 'pjNom' = v_moi AND coalesce(o ->> 'statut','actif') = 'actif')
        LIMIT 1;
      IF v_offre IS NOT NULL THEN
        SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
          FROM public.salaires_civils_declares s
         WHERE s.pays = v_pays AND s.cle = v_offre AND s.categorie = 'emploi';
      END IF;
    END IF;
  END IF;
  IF v_cle IS NULL THEN
    SELECT s.cle, s.categorie, s.montant INTO v_cle, v_origine, v_montant
      FROM public.salaires_civils_declares s
     WHERE s.pays = v_pays AND s.cle = 'default';
  END IF;
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'bareme_absent', 'pays', v_pays);
  END IF;
  v_jour := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_id   := v_moi || ':' || v_jour::text;
  IF v_origine = 'poste' THEN
    v_caisse := public.salaire_caisse_de(v_poste, v_pays, v_ville);
    IF v_caisse IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_payeuse_non_declaree', 'poste', v_poste);
    END IF;
  END IF;
  BEGIN
    INSERT INTO public.salaires_civils_verses (id, personnage, jour, origine, cle, montant)
    VALUES (v_id, v_moi, v_jour, v_origine, v_cle, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT coalesce(arg,0), coalesce(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = v_moi;
    RETURN jsonb_build_object('ok', false, 'raison', 'deja_percu_aujourdhui',
                              'jour', v_jour, 'arg', v_arg, 'liquide', v_liquide);
  END;
  v_paye := v_montant;
  IF v_caisse IS NOT NULL THEN
    SELECT (data->>'solde')::numeric INTO v_solde
      FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
    v_paye := floor(least(v_montant, greatest(coalesce(v_solde, 0), 0)));
    IF v_paye <= 0 THEN
      DELETE FROM public.salaires_civils_verses WHERE id = v_id;
      RETURN jsonb_build_object('ok', false, 'raison', 'caisse_vide',
                                'caisse', v_caisse, 'solde', coalesce(v_solde,0), 'du', v_montant);
    END IF;
    UPDATE public.caisses_batiments
       SET data = coalesce(data,'{}'::jsonb) || jsonb_build_object('solde', v_solde - v_paye),
           updated_at = now()
     WHERE id = v_caisse;
    IF v_paye <> v_montant THEN
      UPDATE public.salaires_civils_verses SET montant = v_paye WHERE id = v_id;
    END IF;
  END IF;
  UPDATE public.personnages_donnees
     SET liquide = coalesce(liquide,0) + v_paye, arg = coalesce(arg,0) + v_paye,
         updated_at = now()
   WHERE name = v_moi
   RETURNING arg, liquide INTO v_arg, v_liquide;
  RETURN jsonb_build_object('ok', true, 'montant', v_paye, 'du', v_montant,
                            'partiel', v_paye <> v_montant, 'origine', v_origine,
                            'cle', v_cle, 'jour', v_jour, 'caisse', v_caisse,
                            'arg', v_arg, 'liquide', v_liquide);
END; $function$;

-- -----------------------------------------------------------------------------
-- 12. LES PREUVES, DANS LA TRANSACTION
-- -----------------------------------------------------------------------------
-- Rien n'est affirme de memoire. Chaque invariant est verifie ici, avant le commit ; une seule
-- violation leve, et la migration entiere n'a pas lieu. C'est la methode qui a deja empeche
-- l'application d'une migration fausse le 7 octobre.

DO $$
DECLARE
  a record;
  v_caisses_apres numeric; v_caisses_nb_apres integer;
  v_muni_apres numeric; v_entrepots_reels_apres numeric; v_entrepots_tous_apres numeric;
  v_arg_apres numeric;
  v_attendu numeric; v_negatives integer; v_cles integer;
  v_entrepots_crees integer; v_lignes_rep integer;
  v_detail text := '';
  r record;
BEGIN
  SELECT * INTO a FROM _avant;

  SELECT coalesce(sum(CASE WHEN jsonb_typeof(data->'solde') = 'number'
                           THEN (data->>'solde')::numeric ELSE 0 END), 0), count(*)
    INTO v_caisses_apres, v_caisses_nb_apres
    FROM public.caisses_batiments;

  SELECT coalesce(sum(CASE WHEN jsonb_typeof(data->'caisse') = 'number'
                           THEN (data->>'caisse')::numeric ELSE 0 END), 0)
    INTO v_muni_apres FROM public.budgets_municipaux;

  SELECT coalesce(sum(CASE WHEN jsonb_typeof(public.batiment_etat_lire(e.data)->'entrepot'->'caisse') = 'number'
                           THEN (public.batiment_etat_lire(e.data)->'entrepot'->>'caisse')::numeric
                           ELSE 0 END), 0)
    INTO v_entrepots_tous_apres FROM public.batiments_etat e;

  SELECT coalesce(sum(CASE WHEN jsonb_typeof(public.batiment_etat_lire(e.data)->'entrepot'->'caisse') = 'number'
                           THEN (public.batiment_etat_lire(e.data)->'entrepot'->>'caisse')::numeric
                           ELSE 0 END), 0)
    INTO v_entrepots_reels_apres
    FROM public.batiments_etat e
    JOIN public.villes v ON v.pays = e.country AND v.ville = e.city
   WHERE e.id LIKE '%\_entrepot-%';

  SELECT coalesce(sum(coalesce(arg,0)), 0) INTO v_arg_apres FROM public.personnages_donnees;

  -- PREUVE 1 -- CONSERVATION EXACTE DE LA MASSE. Deux apports rejoignent caisses_batiments et
  -- rien d'autre ne bouge : l'ancienne tresorerie municipale, et la tresorerie des entrepots des
  -- VRAIES villes. L'egalite est stricte, au centime.
  v_attendu := a.caisses + a.municipaux + a.entrepots_reels;
  IF v_caisses_apres <> v_attendu THEN
    RAISE EXCEPTION 'PREUVE 1 ECHOUEE -- masse non conservee. caisses avant=% + municipaux=% + entrepots reels=% => attendu=% ; mesure=% ; ecart=%',
      a.caisses, a.municipaux, a.entrepots_reels, v_attendu, v_caisses_apres, v_caisses_apres - v_attendu;
  END IF;

  -- PREUVE 2 -- PLUS AUCUNE SECONDE BOURSE NI SECONDE REGLE. Les trois cles ont disparu de
  -- TOUTES les lignes, y compris celles hors ville.
  SELECT count(*) INTO v_cles FROM public.budgets_municipaux
   WHERE data ?| ARRAY['caisse', 'allocation', 'derniereDistribJour'];
  IF v_cles <> 0 OR v_muni_apres <> 0 THEN
    RAISE EXCEPTION 'PREUVE 2 ECHOUEE -- % ligne(s) municipale(s) portent encore caisse/allocation/derniereDistribJour, total caisse=%',
      v_cles, v_muni_apres;
  END IF;

  -- PREUVE 3 -- LA TRESORERIE DES ENTREPOTS REELS A QUITTE LE BLOB, UNE FOIS.
  IF v_entrepots_reels_apres <> 0 THEN
    RAISE EXCEPTION 'PREUVE 3 ECHOUEE -- % FR de tresorerie subsistent dans le blob des entrepots de vraies villes',
      v_entrepots_reels_apres;
  END IF;

  -- PREUVE 4 -- LES ENTREPOTS DE TEST N'ONT PAS ETE TOUCHES. Leur tresorerie est restee dans
  -- leur blob : on ne la migre pas (ce ne sont pas des villes) et surtout on ne la retire pas.
  IF v_entrepots_tous_apres <> a.entrepots_tous - a.entrepots_reels THEN
    RAISE EXCEPTION 'PREUVE 4 ECHOUEE -- les entrepots hors vraies villes devaient conserver % FR, ils en portent %',
      a.entrepots_tous - a.entrepots_reels, v_entrepots_tous_apres;
  END IF;

  -- PREUVE 5 -- LES TROIS CAISSES D'ENTREPOT EXISTENT, ET ELLES SEULES.
  SELECT count(*) INTO v_entrepots_crees FROM public.caisses_batiments WHERE id LIKE '%\_entrepot\_%';
  IF v_entrepots_crees <> 3 THEN
    RAISE EXCEPTION 'PREUVE 5 ECHOUEE -- % caisse(s) d''entrepot creees, 3 attendues', v_entrepots_crees;
  END IF;

  -- PREUVE 6 -- AUCUNE CAISSE NEGATIVE, NULLE PART.
  SELECT count(*) INTO v_negatives FROM public.caisses_batiments
   WHERE jsonb_typeof(data->'solde') = 'number' AND (data->>'solde')::numeric < 0;
  IF v_negatives <> 0 THEN
    RAISE EXCEPTION 'PREUVE 6 ECHOUEE -- % caisse(s) negative(s)', v_negatives;
  END IF;

  -- PREUVE 7 -- 40 + 40 + 20 = 100 EXACTEMENT, pour chacune des trois villes, en fraction exacte
  -- et non en flottant. budget_part_totale rend numerateur et denominateur : on exige l'egalite.
  FOR r IN SELECT v.ville,
                  regexp_replace(public.salaire_caisse_de('maire', 'republic', v.ville), '^republic_', '') AS source
             FROM public.villes v WHERE v.pays = 'republic' ORDER BY v.ville
  LOOP
    DECLARE v_n numeric; v_d numeric; v_nb integer;
    BEGIN
      SELECT numerateur, denominateur INTO v_n, v_d FROM public.budget_part_totale('republic', r.source);
      SELECT count(*) INTO v_nb FROM public.repartitions_budgetaires
       WHERE pays = 'republic' AND source = r.source;
      IF v_nb <> 3 THEN
        RAISE EXCEPTION 'PREUVE 7 ECHOUEE -- % a % beneficiaire(s) declare(s), 3 attendus', r.ville, v_nb;
      END IF;
      IF v_n <> v_d THEN
        RAISE EXCEPTION 'PREUVE 7 ECHOUEE -- la somme des parts de % vaut %/% et non 100 %%',
          r.ville, v_n, v_d;
      END IF;
      v_detail := v_detail || r.ville || '=' || v_n::text || '/' || v_d::text || ' ';
    END;
  END LOOP;

  -- PREUVE 8 -- LES AUTRES EMPIRES N'ONT RECU AUCUNE REPARTITION MUNICIPALE. Absence de
  -- configuration, pas repli sur Republia.
  SELECT count(*) INTO v_lignes_rep FROM public.repartitions_budgetaires
   WHERE pays <> 'republic';
  IF v_lignes_rep <> 0 THEN
    RAISE EXCEPTION 'PREUVE 8 ECHOUEE -- % ligne(s) de repartition declaree(s) hors Republia', v_lignes_rep;
  END IF;

  -- PREUVE 9 -- L'ARGENT DES PERSONNAGES N'A PAS BOUGE. Cette migration ne touche qu'aux
  -- institutions ; si une ligne de personnage avait change, c'est qu'une primitive avait fuite.
  IF v_arg_apres <> a.personnages_arg THEN
    RAISE EXCEPTION 'PREUVE 9 ECHOUEE -- l''argent des personnages est passe de % a %',
      a.personnages_arg, v_arg_apres;
  END IF;

  -- PREUVE 10 -- LA CASERNE ET LE QHS NE SONT PAS DES COMMUNES. Aucune caisse mairie, aucun
  -- compteur de recettes, aucune repartition ne les concerne.
  IF EXISTS (SELECT 1 FROM public.repartitions_budgetaires
              WHERE source LIKE 'mairie%'
                AND (beneficiaire LIKE '%caserne%' OR beneficiaire LIKE '%qhs%')) THEN
    RAISE EXCEPTION 'PREUVE 10 ECHOUEE -- la caserne ou le QHS figure parmi les beneficiaires municipaux';
  END IF;

  RAISE NOTICE 'DIX PREUVES VERTES. masse % -> % (+% municipaux +% entrepots) ; caisses % -> % ; parts : %',
    a.caisses, v_caisses_apres, a.municipaux, a.entrepots_reels,
    a.caisses_nb, v_caisses_nb_apres, v_detail;
END $$;
