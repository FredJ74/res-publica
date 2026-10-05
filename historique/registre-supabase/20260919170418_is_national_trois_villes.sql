-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260919170418
-- Nom original      : is_national_trois_villes
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-19 17:04:18 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 8ea53574bab7cf3e88a8d22c1fe86aba
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
-- LOT 1 (socle) du chantier contre-espionnage — Indice de Securite NATIONAL.
--
-- ARBITRAGE GD : IS_national = moyenne des indices de securite des TROIS VILLES
-- CANONIQUES de l'empire. Valeur neutre 50 tant qu'elles ne sont pas toutes
-- initialisees.
--
-- SOURCE CANONIQUE DES TROIS VILLES -- aucune table nouvelle n'est creee.
-- VILLES_PAR_EMPIRE (plateau-navigation.js:1589) declare exactement trois villes
-- par empire, et les trois `id` sont LES MEMES pour les quatre empires :
-- 'capitale', 'ville_a', 'ville_b'. Le commentaire de cette constante precise que
-- ces id "sont les seules cles de recherche utilisees et les seules valeurs
-- persistees". indices_villes est justement keyee '<pays>_<ville>'.
-- La regle canonique s'exprime donc directement ici, sans dupliquer une liste.
--
-- CONSEQUENCE VOULUE : 'republic_zzville-cmr' -- residu de banc de test -- est
-- exclu PAR CONSTRUCTION, parce qu'il n'est pas l'une des trois cles canoniques,
-- et non par une liste noire. Cette ligne n'est PAS supprimee : le nettoyage des
-- fixtures est un chantier separe (consigne explicite).
--
-- LECTURE DE LA REGLE "pas encore initialises" : la moyenne demandee porte sur
-- trois valeurs. Tant que les TROIS lignes canoniques ne sont pas toutes
-- presentes, la moyenne n'est pas calculable sans biais (une moyenne sur une ou
-- deux villes serait une invention) -- on rend donc la valeur neutre 50.
-- Etat au moment de la migration : republic a ses trois villes a isn=30
-- (IS_national = 30) ; narco, soviet et khalija n'ont aucune ligne (IS = 50).
--
-- Aucune valeur nationale n'est persistee : la fonction derive toujours des
-- valeurs canoniques des villes, elle ne peut donc jamais diverger d'elles.

CREATE OR REPLACE FUNCTION public.is_national(p_pays text)
RETURNS numeric
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN count(*) = 3 THEN round(avg((v.data ->> 'isn')::numeric), 2)
    ELSE 50
  END
  FROM public.indices_villes v
  WHERE v.id = ANY (ARRAY[p_pays || '_capitale',
                          p_pays || '_ville_a',
                          p_pays || '_ville_b'])
    AND jsonb_typeof(v.data -> 'isn') = 'number';
$function$;

REVOKE ALL ON FUNCTION public.is_national(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_national(text) TO service_role;
