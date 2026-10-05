-- =====================================================================
-- TRACE — SOCLE DU CONTRE-ESPIONNAGE (19 septembre 2026)
--
-- CE FICHIER N'EST QU'UNE TRACE. Il n'est pas execute par le jeu : les
-- migrations ont deja ete appliquees en production sous les noms
--   is_national_trois_villes
--   contre_espionnage_score_paliers
-- =====================================================================
--
-- ================= 1. INDICE DE SECURITE NATIONAL =====================
--
-- ARBITRAGE GD : IS_national = moyenne des indices de securite des TROIS
-- VILLES CANONIQUES de l'empire ; valeur neutre 50 tant qu'elles ne sont
-- pas toutes initialisees. Aucune valeur nationale persistee (elle
-- pourrait diverger des villes).
--
-- SOURCE CANONIQUE -- AUCUNE TABLE NOUVELLE N'A ETE CREEE.
-- VILLES_PAR_EMPIRE (plateau-navigation.js:1589) declare exactement trois
-- villes par empire, et les trois `id` sont LES MEMES pour les quatre
-- empires : 'capitale', 'ville_a', 'ville_b'. Son propre commentaire
-- precise que ces id "sont les seules cles de recherche utilisees et les
-- seules valeurs persistees". indices_villes est keyee '<pays>_<ville>'.
-- La regle s'exprime donc directement en SQL, sans dupliquer la liste.
--
-- 'republic_zzville-cmr' (residu de banc) est exclu PAR CONSTRUCTION --
-- il n'est pas l'une des trois cles canoniques -- et non par liste noire.
-- La ligne n'est PAS supprimee : nettoyage des fixtures = chantier separe.
--
-- "pas encore initialises" : la moyenne porte sur trois valeurs. Tant que
-- les TROIS lignes ne sont pas presentes, une moyenne sur une ou deux
-- villes serait une invention -> valeur neutre 50.
--
-- BANC : republic = 30.00 (ses trois villes a 30) ; narco / soviet /
-- khalija / pays inexistant = 50. Et surtout, exclusion PROUVEE : en
-- transaction annulee, 'republic_zzville-cmr' pousse a isn=90 laisse
-- is_national('republic') a 30.00.

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

-- ================= 2. JET UNIQUE A PALIERS ============================
--
-- ARBITRAGE GD FIXE :
--   score = clamp(0, 100, d100 + 3 x (PER_com - DUP_agent) + (IS_national - 50)/2)
--   d100 uniforme 1..100, tire EXCLUSIVEMENT cote serveur.
--   Paliers CUMULATIFS : <50 echec | 50-69 faux nom | 70-84 + agent
--   etranger | 85-91 + vrai nom | 92-100 + pays d'origine.
-- Distribution PLATE assumee.
--
-- Deux fonctions PURES, pour que la part deterministe soit testable seule.
-- Le tirage du de vivra dans la RPC d'enquete -- jamais dans le navigateur :
-- aujourd'hui le seul jet d'enquete du jeu est un Math.random() client, et
-- plainte_instruire_interne ne tire rien du tout.
--
-- Aucune caracteristique nouvelle : PER est deja la stat d'enquete du jeu,
-- DUP deja la stat de dissimulation. assemblee_stat_base(stats, cle) lira
-- les deux et rend deja 8 par defaut, comme le client.
--
-- Le palier est un ENTIER CROISSANT 0..4 : "une connaissance acquise n'est
-- jamais perdue" devient greatest(niveau_connu, niveau_obtenu).
--
-- BORNES VERIFIEES : 49->0, 50->1, 69->1, 70->2, 84->2, 85->3, 91->3,
-- 92->4, 100->4.
--
-- MATRICE MESUREE (40 000 tirages par cellule) -- atteinte de chaque palier :
--   PER 8 / DUP 16, IS 30 ....... 17,3 / 0    / 0    / 0
--   PER 12/ DUP 12, IS 30 ....... 41,3 / 21,1 / 6,1  / 0
--   PER 16/ DUP 8,  IS 30 ....... 65,3 / 45,0 / 30,3 / 23,3
--   PER 20/ DUP 8,  IS 30 ....... 76,9 / 56,6 / 41,9 / 34,8
--   PER 12/ DUP 12, IS 50 ....... 51,5 / 31,4 / 16,5 / 9,4
--   PER 20/ DUP 8,  IS 80 ....... 100  / 81,8 / 67,1 / 60,1
--
-- DEUX CONSEQUENCES A CONNAITRE, issues de l'arbitrage lui-meme :
--   * a l'IS reel de Republia (30), le palier "pays d'origine" est
--     INATTEIGNABLE (0 %) pour des adversaires equivalents ou pour un
--     commissaire inferieur ; il ne s'ouvre qu'a un enqueteur nettement
--     superieur ;
--   * un commissaire faible face a un bon agent plafonne au palier 1
--     (fausse identite) : il ne peut donc JAMAIS rendre cet agent
--     arrestable, l'arrestation exigeant le palier 2.

CREATE OR REPLACE FUNCTION public.contre_espionnage_modificateur(
  p_per_commissaire numeric, p_dup_agent numeric, p_is_national numeric)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $function$
  SELECT round(3 * (coalesce(p_per_commissaire, 8) - coalesce(p_dup_agent, 8))
             + (coalesce(p_is_national, 50) - 50) / 2.0)::integer;
$function$;

CREATE OR REPLACE FUNCTION public.contre_espionnage_palier(p_score integer)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p_score IS NULL THEN 0
    WHEN p_score >= 92 THEN 4
    WHEN p_score >= 85 THEN 3
    WHEN p_score >= 70 THEN 2
    WHEN p_score >= 50 THEN 1
    ELSE 0
  END;
$function$;

REVOKE ALL ON FUNCTION public.contre_espionnage_modificateur(numeric,numeric,numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.contre_espionnage_palier(integer)                        FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_modificateur(numeric,numeric,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.contre_espionnage_palier(integer)                        TO service_role;
