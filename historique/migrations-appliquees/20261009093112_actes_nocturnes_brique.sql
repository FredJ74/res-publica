-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 9 OCTOBRE 2026
--
-- Registre Supabase : version 20261009093112 (UTC ; 11h31 a Paris), nom
-- `actes_nocturnes_brique`. Le registre passe de 565 a 566 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 6773e0daf385023b5863595296f36425, 9 343 caracteres,
-- 1 instruction au registre. Relu depuis `supabase_migrations.schema_migrations`, empreinte
-- verifiee avant archivage.
--
-- -----------------------------------------------------------------------------
-- CE QU'ELLE INSTALLE, ET POURQUOI C'ETAIT LA BONNE FORME
-- -----------------------------------------------------------------------------
-- L'audit du chantier 6 avait etabli le diagnostic commun a DIX familles de taches nocturnes :
-- « l'effet et sa preuve d'execution sont dans deux requetes HTTP distinctes ; la fenetre entre
-- les deux est un double debit en attente ». Trois mecaniques ont ete fermees une par une dans
-- la nuit du 8 au 9 octobre. Cette migration pose la brique qui ferme la CLASSE entiere.
--
-- DEUX TABLES ET UNE FONCTION.
--   . `actes_nocturnes(pays, mecanisme, sujet, jour)` en CLE PRIMAIRE : revendiquer un acte,
--     c'est INSERER sa ligne. Un second passage le meme jour obtient un conflit de cle et ne
--     produit rien. Ce n'est plus un marqueur qu'une ecriture avalee peut perdre, c'est une
--     contrainte que PostgreSQL resout en une instruction. Generalise le patron, deja eprouve,
--     de `repartitions_versements(pays, source, beneficiaire, jour)`.
--   . `actes_nocturnes_mecanismes` : la LISTE BLANCHE des mecanismes, avec une cle etrangere
--     depuis le journal. Revendiquer un mecanisme non declare LEVE. Un nom mal orthographie ne
--     peut donc pas ouvrir un second espace de noms en silence -- ce qui reviendrait a ne plus
--     proteger le vrai. Ajouter un mecanisme est une migration, et c'est voulu : la liste des
--     taches de minuit devient lisible en un endroit, au lieu de se reconstituer a la main
--     depuis 6 400 lignes de JavaScript. Sa colonne `note` dit ce qu'un rejeu produirait.
--   . `acte_nocturne_revendiquer(pays, mecanisme, sujet, details)` -> boolean.
--
-- -----------------------------------------------------------------------------
-- LE CHOIX D'ARCHITECTURE QUI COMPTE : LA REVENDICATION EST INJOIGNABLE DEPUIS LE RESEAU
-- -----------------------------------------------------------------------------
-- Une cle primaire ne protege que ce qui COMMITE avec elle. Si le cron pouvait appeler
-- `acte_nocturne_revendiquer` par PostgREST, il revendiquerait dans un aller-retour et
-- produirait l'effet dans un autre -- exactement le defaut qu'on repare, avec une table de plus.
--
-- Son `EXECUTE` est donc retire a `anon`, a `authenticated` ET a `service_role`. Il ne reste que
-- le proprietaire. Seules les fonctions SECURITY DEFINER possedees par `postgres` peuvent la
-- joindre : il est STRUCTURELLEMENT IMPOSSIBLE de revendiquer une journee hors de la
-- transaction qui porte l'effet. L'architecture n'est pas une convention qu'on documente, c'est
-- un droit qu'on retire.
--
-- LA PREUVE 5 TESTE LE RESULTAT OBSERVABLE, PAS LA MECANIQUE, et c'est deliberе : elle
-- interroge `has_function_privilege` pour les trois roles clients. Si l'ACL s'etait effondree a
-- NULL -- le piege « fermer trop rouvre » rencontre au chantier des privileges par defaut --
-- le defaut natif de PostgreSQL rendrait `EXECUTE` a `PUBLIC`, et `anon` repasserait a true.
-- Un controle qui se contenterait de verifier que les REVOKE ont ete emis ne le verrait pas.
--
-- -----------------------------------------------------------------------------
-- TROIS DECISIONS DE DETAIL, CHACUNE POUR UNE RAISON
-- -----------------------------------------------------------------------------
-- `jour` EST DE TYPE DATE, ET N'EST JAMAIS UN PARAMETRE. La fonction la calcule elle-meme en
-- Europe/Paris -- meme convention que `jourParisISO()` cote JavaScript et que
-- `to_char(now() AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD')` dans les autres RPC. Un appelant
-- qui pourrait choisir le jour pourrait rejouer l'effet autant de fois qu'il a de dates a
-- proposer. Et le type `date` plutot que `text` ferme la porte aux formats concurrents, qui
-- sont la facon habituelle dont deux marqueurs cessent de parler de la meme journee.
--
-- UNE IDENTITE INCOMPLETE LEVE, ELLE NE REND PAS false. `false` veut dire « deja fait
-- aujourd'hui » : le confondre avec « je n'ai pas compris ta demande » ferait passer une panne
-- pour une idempotence. Un refus metier et une erreur ne se disent pas de la meme facon.
--
-- `details jsonb` FAIT DE LA TABLE UN JOURNAL AUTANT QU'UN VERROU. Le mecanisme y ecrit ce
-- qu'il a REELLEMENT fait -- montant, reste du, verdict -- apres son effet. Le lendemain, on
-- peut dire ce qui a ete fait sans relire les soldes.
--
-- -----------------------------------------------------------------------------
-- AUCUN MECANISME N'EST DECLARE PAR CETTE MIGRATION, ET LA PREUVE 7 L'EXIGE
-- -----------------------------------------------------------------------------
-- La brique arrive vide. Chaque mecanisme est une decision, prise dans la migration qui le
-- branche. Le premier -- `preemption_mensualite` -- est declare par la migration 20261009130649,
-- appliquee juste apres : une brique sans consommateur serait une brique morte, et ce depot en
-- a deja (« briques serveur non branchees a recycler »).
--
-- -----------------------------------------------------------------------------
-- CE QUI A ETE PROUVE, ET OU
-- -----------------------------------------------------------------------------
-- BANC EN TRANSACTION ANNULEE, 7 preuves : revendication unique (deux appels, une seule ligne) ;
-- normalisation de la casse, des espaces et du sujet vide vers `-` ; un sujet distinct est un
-- acte distinct ; un mecanisme non declare LEVE une violation de cle etrangere ; une identite
-- incomplete LEVE (pays vide, mecanisme NULL) ; un slug invalide est refuse par la contrainte ;
-- les `details` sont relus. Verifie annule : aucune table, aucune fonction ne subsistait.
--
-- PREUVES STRUCTURELLES DE LA MIGRATION, 7 : cle primaire sur les quatre colonnes ; cle
-- etrangere vers le registre ; `jour` de type `date` ; RLS active sur les deux tables ; AUCUN
-- droit client sur les tables -- les trois REVOKE etaient necessaires, un `REVOKE FROM PUBLIC`
-- seul ne retire pas les droits NOMMES que Supabase accorde a `anon` et `authenticated` sur
-- toute table neuve de `public` ; la revendication injoignable depuis le reseau et le
-- proprietaire conservant son EXECUTE ; SECURITY DEFINER et `search_path` figes ; zero mecanisme
-- et zero acte a l'arrivee.
--
-- RLS SANS POLICY, DELIBEREMENT : ces deux tables n'ont aucun lecteur client. Elles rejoignent
-- les 101 tables du meme cas, et le controle du baseline qui exige « zero table sans RLS » reste
-- vert.
-- =============================================================================

-- Chantier 6 -- BRIQUE GENERIQUE D'IDEMPOTENCE NOCTURNE. L'idempotence vit dans une cle
-- primaire (pays, mecanisme, sujet, jour), et la revendication n'est PAS appelable depuis le
-- reseau : elle est donc forcement dans la transaction de l'effet. Banc annule : 7 preuves
-- vertes. Premier consommateur dans la migration suivante. Raisonnement complet dans
-- historique/migrations-appliquees/.
CREATE TABLE IF NOT EXISTS public.actes_nocturnes_mecanismes (
  mecanisme       text PRIMARY KEY,
  sujet_singleton boolean NOT NULL DEFAULT false,
  note            text NOT NULL,
  CONSTRAINT actes_nocturnes_mecanismes_slug CHECK (mecanisme ~ '^[a-z][a-z0-9_]{2,59}$')
);

CREATE TABLE IF NOT EXISTS public.actes_nocturnes (
  pays      text NOT NULL,
  mecanisme text NOT NULL REFERENCES public.actes_nocturnes_mecanismes(mecanisme),
  sujet     text NOT NULL,
  jour      date NOT NULL,
  acquis_le timestamptz NOT NULL DEFAULT now(),
  details   jsonb,
  PRIMARY KEY (pays, mecanisme, sujet, jour),
  CONSTRAINT actes_nocturnes_pays_non_vide  CHECK (btrim(pays)  <> ''),
  CONSTRAINT actes_nocturnes_sujet_non_vide CHECK (btrim(sujet) <> '')
);

ALTER TABLE public.actes_nocturnes_mecanismes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.actes_nocturnes            ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.actes_nocturnes_mecanismes FROM PUBLIC;
REVOKE ALL ON TABLE public.actes_nocturnes_mecanismes FROM anon;
REVOKE ALL ON TABLE public.actes_nocturnes_mecanismes FROM authenticated;
REVOKE ALL ON TABLE public.actes_nocturnes FROM PUBLIC;
REVOKE ALL ON TABLE public.actes_nocturnes FROM anon;
REVOKE ALL ON TABLE public.actes_nocturnes FROM authenticated;

COMMENT ON TABLE public.actes_nocturnes IS
'L''IDEMPOTENCE DES TACHES NOCTURNES VIT DANS CETTE CLE PRIMAIRE. Revendiquer un acte, c''est
INSERER sa ligne ; un second passage le meme jour obtient un conflit de cle et ne produit rien.
Ce n''est plus un marqueur qu''une ecriture avalee peut perdre, c''est une contrainte resolue en
une instruction. Generalise repartitions_versements(pays, source, beneficiaire, jour).
Une cle primaire ne protege que ce qui COMMITE avec elle : voir acte_nocturne_revendiquer().
RETENTION : ajout seul, quelques dizaines de lignes par jour ; aucune purge posee, non-decision
assumee -- le jour venu, DELETE ... WHERE jour < current_date - 180.';
COMMENT ON COLUMN public.actes_nocturnes.jour IS
'Journee de jeu en Europe/Paris, de type date et non de type texte. Elle n''est JAMAIS un
parametre : acte_nocturne_revendiquer() la calcule. Un appelant qui choisirait le jour pourrait
rejouer l''effet autant de fois qu''il a de dates a proposer.';
COMMENT ON COLUMN public.actes_nocturnes.sujet IS
'Identifiant du sujet -- un bail, un pret, un dossier. Le litteral ''-'' quand le mecanisme n''a
qu''un sujet par pays (voir actes_nocturnes_mecanismes.sujet_singleton).';
COMMENT ON COLUMN public.actes_nocturnes.details IS
'Ce que l''acte a REELLEMENT fait, ecrit apres l''effet : montant, reste du, verdict. La table
est ainsi un journal autant qu''un verrou.';
COMMENT ON TABLE public.actes_nocturnes_mecanismes IS
'LISTE BLANCHE des mecanismes de la passe de minuit. Revendiquer un mecanisme absent LEVE une
violation de cle etrangere : un nom mal orthographie ne peut pas ouvrir un second espace de noms
en silence, ce qui reviendrait a ne plus proteger le vrai. Ajouter un mecanisme est une
migration, et c''est voulu -- la liste des taches nocturnes devient lisible en un endroit.';
COMMENT ON COLUMN public.actes_nocturnes_mecanismes.sujet_singleton IS
'true quand le mecanisme n''a QU''UN sujet par pays ; le sujet vaut alors ''-''.';
COMMENT ON COLUMN public.actes_nocturnes_mecanismes.note IS
'A quoi sert ce mecanisme et ce qu''un rejeu produirait sans la revendication.';

CREATE OR REPLACE FUNCTION public.acte_nocturne_revendiquer(
  p_pays text, p_mecanisme text, p_sujet text DEFAULT '-', p_details jsonb DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
DECLARE
  v_pays   text := lower(btrim(coalesce(p_pays, '')));
  v_meca   text := lower(btrim(coalesce(p_mecanisme, '')));
  v_sujet  text := btrim(coalesce(p_sujet, ''));
  v_n      integer;
BEGIN
  -- FAIL-CLOSED : une identite incomplete LEVE. Rendre false voudrait dire « deja fait ».
  IF v_pays = '' OR v_meca = '' THEN
    RAISE EXCEPTION 'acte_nocturne_revendiquer : pays et mecanisme sont obligatoires (pays=%, mecanisme=%)', p_pays, p_mecanisme;
  END IF;
  IF v_sujet = '' THEN
    v_sujet := '-';
  END IF;
  -- LE JOUR N'EST PAS UN PARAMETRE. Europe/Paris, comme jourParisISO() cote JavaScript.
  INSERT INTO public.actes_nocturnes (pays, mecanisme, sujet, jour, details)
  VALUES (v_pays, v_meca, v_sujet, (now() AT TIME ZONE 'Europe/Paris')::date, p_details)
  ON CONFLICT (pays, mecanisme, sujet, jour) DO NOTHING;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n = 1;
END; $fn$;

REVOKE ALL ON FUNCTION public.acte_nocturne_revendiquer(text, text, text, jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.acte_nocturne_revendiquer(text, text, text, jsonb) FROM authenticated;
REVOKE ALL ON FUNCTION public.acte_nocturne_revendiquer(text, text, text, jsonb) FROM service_role;

COMMENT ON FUNCTION public.acte_nocturne_revendiquer(text, text, text, jsonb) IS
'Revendique l''acte (pays, mecanisme, sujet, jour courant) : true s''il est ACQUIS, false s''il
etait deja pris aujourd''hui. LEVE si l''identite est incomplete ou le mecanisme non declare --
un refus metier et une erreur ne se disent pas de la meme facon.
PAS APPELABLE DEPUIS LE RESEAU, et c''est l''essentiel de l''architecture : EXECUTE retire a
anon, authenticated ET service_role. Seules les fonctions SECURITY DEFINER du serveur la
joignent, donc il est IMPOSSIBLE de revendiquer une journee hors de la transaction qui porte
l''effet.';

DO $$
DECLARE v_n int; v_def text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.actes_nocturnes'::regclass AND contype = 'p'
                    AND pg_get_constraintdef(oid) = 'PRIMARY KEY (pays, mecanisme, sujet, jour)') THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- la cle primaire n''est pas (pays, mecanisme, sujet, jour)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.actes_nocturnes'::regclass AND contype = 'f') THEN
    RAISE EXCEPTION 'P1 ECHOUEE -- aucune cle etrangere vers le registre des mecanismes';
  END IF;

  IF (SELECT format_type(atttypid, atttypmod) FROM pg_attribute
       WHERE attrelid = 'public.actes_nocturnes'::regclass AND attname = 'jour') <> 'date' THEN
    RAISE EXCEPTION 'P2 ECHOUEE -- jour n''est pas de type date';
  END IF;

  SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname IN ('actes_nocturnes','actes_nocturnes_mecanismes')
     AND c.relrowsecurity;
  IF v_n <> 2 THEN RAISE EXCEPTION 'P3 ECHOUEE -- % table(s) avec RLS au lieu de 2', v_n; END IF;

  -- Les trois REVOKE etaient necessaires : un REVOKE FROM PUBLIC seul ne retire pas les droits
  -- NOMMES que Supabase accorde a anon et authenticated sur toute table neuve de public.
  SELECT count(*) INTO v_n
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
    CROSS JOIN LATERAL aclexplode(c.relacl) ae LEFT JOIN pg_roles r ON r.oid = ae.grantee
   WHERE c.relname IN ('actes_nocturnes','actes_nocturnes_mecanismes')
     AND coalesce(r.rolname, 'PUBLIC') IN ('PUBLIC','anon','authenticated');
  IF v_n <> 0 THEN RAISE EXCEPTION 'P4 ECHOUEE -- % droit(s) client subsistent sur les tables', v_n; END IF;

  -- On teste le RESULTAT OBSERVABLE, pas la mecanique : si l'ACL s'etait effondree a NULL, le
  -- defaut natif rendrait EXECUTE a PUBLIC et anon repasserait a true -- ce controle le verrait.
  IF has_function_privilege('anon', 'public.acte_nocturne_revendiquer(text,text,text,jsonb)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.acte_nocturne_revendiquer(text,text,text,jsonb)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.acte_nocturne_revendiquer(text,text,text,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- la revendication reste appelable depuis le reseau';
  END IF;
  IF NOT has_function_privilege('postgres', 'public.acte_nocturne_revendiquer(text,text,text,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P5 ECHOUEE -- le proprietaire a perdu son EXECUTE';
  END IF;

  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'acte_nocturne_revendiquer';
  IF v_def !~ 'SECURITY DEFINER' OR v_def !~ 'search_path TO ''public'', ''pg_temp''' THEN
    RAISE EXCEPTION 'P6 ECHOUEE -- autorite ou search_path incorrects';
  END IF;

  -- La brique n'arrive avec AUCUN mecanisme declare : chaque mecanisme est une decision.
  SELECT count(*) INTO v_n FROM public.actes_nocturnes_mecanismes;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P7 ECHOUEE -- % mecanisme(s) declare(s) par la brique', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.actes_nocturnes;
  IF v_n <> 0 THEN RAISE EXCEPTION 'P7 ECHOUEE -- % acte(s) deja journalise(s)', v_n; END IF;

  RAISE NOTICE 'SEPT PREUVES STRUCTURELLES VERTES.';
END $$;