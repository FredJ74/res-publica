-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260917094218
-- Nom original      : fonds_crediter_atteste
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-17 09:42:18 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 023d3828a353ab2676315f43610d6d60
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
-- PRIMITIVE DE CREDIT D'ARGENT ATTESTE — 17 septembre 2026, passe 3.
-- Pendant monetaire de pa_crediter_atteste, validee par le game designer, et FERMEE PAR
-- CONSTRUCTION : elle ne doit jamais devenir une API « credite X FR au personnage Y ».
--
-- INVARIANTS, dans l'ordre d'importance :
--  1. LE BENEFICIAIRE EST TOUJOURS L'APPELANT. Aucun parametre de destinataire n'existe : le
--     serveur credite mon_personnage(). Crediter autrui reste impossible par cette voie (les
--     transferts entre joueurs passent par don_argent_deposer, qui debite l'expediteur).
--  2. LE MONTANT N'EST JAMAIS FOURNI PAR LE CLIENT. Il vient soit d'un montant fixe declare dans
--     fonds_credits_sources, soit du COUT REEL de l'ordre lu dans le miroir ordres_couts (le meme
--     miroir extrait de data.js que payer_ordre utilise pour valider les depenses), eventuellement
--     multiplie par une part declaree dans la source. Exactement la doctrine de pa_crediter_atteste.
--  3. LA CAUSE EST UNE LISTE BLANCHE. Une source non declaree est refusee. Ajouter une cause est un
--     acte deliberé (INSERT dans fonds_credits_sources), pas un parametre libre.
--  4. IDEMPOTENCE PAR REFERENCE METIER. La cle unique (source, reference) rend le rejeu sans effet :
--     une requete executee cote serveur mais dont la reponse n'est jamais parvenue au navigateur
--     peut etre retentee sans crediter deux fois.
--  5. JOURNALISATION. Chaque credit laisse une ligne auditable : qui, quelle cause, quelle
--     reference, quel montant, quand.
--  6. ATOMICITE. Ecriture de la trace et credit dans la meme transaction ; si la trace existe deja,
--     aucun credit.
--
-- CE QU'ELLE NE COUVRE PAS, volontairement : tout credit dont le montant est choisi par le joueur
-- (capital d'un pret, subvention libre). Ces cas ne sont pas attestables par construction et
-- doivent passer par une RPC metier dediee qui connait leur regle.

CREATE TABLE IF NOT EXISTS public.fonds_credits_sources (
  source      text PRIMARY KEY,
  montant     numeric,                 -- montant fixe ; NULL = lire le cout de l'ordre
  part        numeric NOT NULL DEFAULT 1,  -- fraction du cout de l'ordre (1 = integralite)
  libelle     text NOT NULL
);
ALTER TABLE public.fonds_credits_sources ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.fonds_credits_uniques (
  id         bigserial PRIMARY KEY,
  acteur     text NOT NULL,
  source     text NOT NULL,
  reference  text NOT NULL,
  ordre      text,
  montant    numeric NOT NULL,
  cree_le    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fonds_credits_uniques_ref UNIQUE (source, reference)
);
ALTER TABLE public.fonds_credits_uniques ENABLE ROW LEVEL SECURITY;

-- Causes declarees. Aucune n'est inventee : ce sont les remboursements deja pratiques par le code.
INSERT INTO public.fonds_credits_sources (source, montant, part, libelle) VALUES
  ('remboursement_ordre',        NULL, 1,   'Remboursement integral du cout d''un ordre qui n''a pas abouti'),
  ('remboursement_ordre_echoue', NULL, 0.3, 'Remboursement de 30% du cout d''un ordre dont le jet a echoue')
ON CONFLICT (source) DO NOTHING;

CREATE OR REPLACE FUNCTION public.fonds_crediter_atteste(
  p_acteur text, p_source text, p_reference text, p_ordre text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_declare boolean; v_montant numeric; v_part numeric; v_cout numeric;
  v_arg numeric; v_liquide numeric;
BEGIN
  -- Le beneficiaire est l'appelant, et seulement lui.
  PERFORM public.exiger_acteur(p_acteur);

  IF p_reference IS NULL OR btrim(p_reference) = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'reference_absente');
  END IF;

  SELECT true, s.montant, s.part INTO v_declare, v_montant, v_part
    FROM public.fonds_credits_sources s WHERE s.source = p_source;
  IF NOT COALESCE(v_declare, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'source_non_declaree');
  END IF;

  -- Montant : fixe si la source en declare un, sinon le COUT REEL de l'ordre, jamais celui que
  -- le client pretend. La part permet un remboursement partiel declare (ex. 30%).
  IF v_montant IS NULL THEN
    SELECT max(o.cost) INTO v_cout FROM public.ordres_couts o WHERE o.fn = p_ordre;
    IF v_cout IS NULL OR v_cout <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'raison', 'ordre_non_declare', 'ordre', p_ordre);
    END IF;
    v_montant := floor(v_cout * COALESCE(v_part, 1));
  END IF;
  IF v_montant IS NULL OR v_montant <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_nul');
  END IF;

  -- Trace d'abord : c'est elle qui porte l'idempotence.
  BEGIN
    INSERT INTO public.fonds_credits_uniques (acteur, source, reference, ordre, montant)
    VALUES (p_acteur, p_source, p_reference, p_ordre, v_montant);
  EXCEPTION WHEN unique_violation THEN
    SELECT COALESCE(arg,0), COALESCE(liquide,0) INTO v_arg, v_liquide
      FROM public.personnages_donnees WHERE name = p_acteur;
    RETURN jsonb_build_object('ok', false, 'raison', 'credit_deja_accorde',
                              'arg', v_arg, 'liquide', v_liquide);
  END;

  -- Credit des FONDS ORDINAIRES : liquide (immediatement depensable) et arg (fortune affichee),
  -- exactement ce que fait crediterFondsOrdinaires cote client, mais atteste.
  UPDATE public.personnages_donnees
     SET liquide = COALESCE(liquide,0) + v_montant,
         arg     = COALESCE(arg,0) + v_montant,
         updated_at = now()
   WHERE name = p_acteur
   RETURNING arg, liquide INTO v_arg, v_liquide;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_introuvable');
  END IF;

  RETURN jsonb_build_object('ok', true, 'montant', v_montant, 'source', p_source,
                            'arg', v_arg, 'liquide', v_liquide);
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.fonds_crediter_atteste(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fonds_crediter_atteste(text, text, text, text) TO authenticated;