-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927133640
-- Nom original      : socle_pnj_classes_alpha_beta_gamma
-- Categorie         : MIXTE -- MIXTE (structure ET mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 13:36:40 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 74cebe26dea4e0071a939a60934fd6a7
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
-- LOT 2a — LA COUCHE CLASSE, ET LA GARANTIE QUE BETA NE CONSOMME PAS DE PA (27 septembre 2026)
--
-- L'architecture validee est SOCLE -> CLASSE -> METIER. La classe manquait : rien, dans la base,
-- ne distinguait un PNJ qui consomme ses PA d'un PNJ qui n'en consomme pas. « Beta ne consomme
-- pas de PA » n'etait donc qu'une intention, pas une garantie.
--
-- POURQUOI UNE TABLE ET PAS UNE COLONNE. Une colonne `classe` sur pnj_membres aurait oblige a
-- retoucher tous les chemins d'ecriture des soldats -- le declencheur miroir, l'outil de copie --
-- alors que ce lot doit laisser les soldats strictement intacts. Or la classe n'est pas une
-- propriete de l'individu : c'est une propriete de sa FAMILLE. Tous les douaniers sont Beta, tous
-- les soldats sont Alpha. Une table de correspondance dit exactement cela, et n'oblige a toucher
-- aucun chemin existant.
--
-- Une famille ABSENTE de cette table n'a pas de classe : les gardes de classe la refusent alors
-- par defaut. Raccorder une famille au socle exige donc de declarer sa classe -- on ne peut pas
-- l'oublier en silence.
CREATE TABLE public.pnj_familles_classes (
  famille text PRIMARY KEY,
  classe  text NOT NULL CHECK (classe IN ('alpha','beta','gamma')),
  note    text
);
ALTER TABLE public.pnj_familles_classes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.pnj_familles_classes FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.pnj_familles_classes IS
  'Classe de chaque famille de PNJ. alpha : consomme ses PA pour agir. beta : porte 12 PA qui ne '
  'sont jamais consommes. gamma : immuable, sans proprietaire, PA inertes. Une famille absente '
  'n''a pas de classe et les gardes la refusent -- c''est volontaire.';

INSERT INTO public.pnj_familles_classes (famille, classe, note) VALUES
  ('soldat',   'alpha', 'Famille pilote Alpha. Ses PA bougent encore par le blob militaire : la '
                     || 'bascule de l''axe PA est le lot 5.'),
  ('douanier', 'beta',  'Premiere famille Beta raccordee (lot 2). 12 PA presents, jamais debites.');

CREATE OR REPLACE FUNCTION public.pnj_classe_de(p_pnj_id text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT c.classe FROM public.pnj_membres m
    JOIN public.pnj_familles_classes c ON c.famille = m.famille
   WHERE m.id = p_pnj_id;
$$;

-- ---------------------------------------------------------------------------------------
-- LA GARANTIE DE CLASSE SUR LES PA
-- ---------------------------------------------------------------------------------------
-- Seule la classe alpha peut voir ses PA debites. Beta et Gamma les portent sans jamais les
-- depenser -- c'est ce qui les distingue, et ce doit etre une garde, pas une convention.
-- Une famille sans classe declaree est refusee elle aussi : on n'ouvre pas un debit par defaut.
CREATE OR REPLACE FUNCTION public.pnj_pa_debiter(p_ids text[], p_cout integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE r record; v_morts integer := 0; v_touches integer := 0; v_reste integer;
        v_hors text; v_classe text;
BEGIN
  IF public.pnj_axe_partage_verrouille(p_ids) IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'soldat_axe_blob_autoritaire',
      'pnj', public.pnj_axe_partage_verrouille(p_ids),
      'explication', 'Pendant la phase miroir, les mouvements de soldats passent par les RPC militaires : le blob reste l autorite et le declencheur met le socle a jour.');
  END IF;
  IF p_cout IS NULL OR p_cout < 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'cout_invalide'); END IF;

  -- CONTROLE DE CLASSE AVANT TOUTE ECRITURE : un lot mixte est refuse EN ENTIER, jamais
  -- partiellement applique.
  SELECT m.id, public.pnj_classe_de(m.id) INTO v_hors, v_classe
    FROM public.pnj_membres m
   WHERE m.id = ANY(p_ids)
     AND COALESCE(public.pnj_classe_de(m.id), '') <> 'alpha'
   LIMIT 1;
  IF v_hors IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'classe_sans_consommation_de_pa',
      'pnj', v_hors, 'classe', COALESCE(v_classe, 'non_declaree'),
      'explication', 'Seule la classe alpha depense ses PA pour agir. Une famille dont la classe '
                  || 'n est pas declaree est refusee de la meme facon.');
  END IF;

  FOR r IN SELECT id, pa FROM public.pnj_membres
            WHERE id = ANY(p_ids) AND statut = 'actif' FOR UPDATE LOOP
    v_reste := greatest(0, r.pa - p_cout);
    UPDATE public.pnj_membres SET pa = v_reste WHERE id = r.id;
    v_touches := v_touches + 1;
    IF v_reste = 0 THEN PERFORM public.pnj_mourir(r.id); v_morts := v_morts + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'touches', v_touches, 'morts', v_morts);
END; $$;

REVOKE ALL ON FUNCTION public.pnj_classe_de(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pnj_pa_debiter(text[],integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pnj_classe_de(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pnj_pa_debiter(text[],integer) TO service_role;