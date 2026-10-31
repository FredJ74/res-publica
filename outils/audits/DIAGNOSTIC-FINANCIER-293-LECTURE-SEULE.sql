-- #293 — audit non destructif des montants de fiche et du compte national.
-- Ne modifie aucune table. Exécuter avec un rôle de lecture autorisé.
-- Ne jamais prendre la colonne personnages_donnees.banque pour le compte réel.
-- Les comparaisons ne valent qu'après vérification d'une éventuelle seconde
-- ligne nationale par personnage et de la sémantique de arg.
WITH compte AS (
 SELECT personnage,
        count(*) AS nombre_comptes,
        sum(coalesce(solde,0)) AS solde
 FROM public.comptes_bancaires
 WHERE banque = 'nationale'
 GROUP BY personnage
), ecarts AS (
 SELECT p.name,
        p.arg,
        p.liquide,
        p.banque AS banque_heritee,
        coalesce(c.solde,0) AS banque_nationale_reelle,
        coalesce(c.nombre_comptes,0) AS nombre_comptes,
        p.arg - coalesce(p.liquide,0) - coalesce(c.solde,0) AS ecart_reel
 FROM public.personnages_donnees p
 LEFT JOIN compte c ON c.personnage = p.name
)
SELECT count(*) AS personnages,
       count(*) FILTER (WHERE banque_heritee IS DISTINCT FROM banque_nationale_reelle) AS banque_heritee_divergente,
       count(*) FILTER (WHERE ecart_reel <> 0) AS totaux_divergents,
       count(*) FILTER (WHERE nombre_comptes > 1) AS multi_comptes_nationaux,
       min(ecart_reel) AS ecart_min,
       max(ecart_reel) AS ecart_max,
       sum(abs(ecart_reel)) AS ecarts_absolus
FROM ecarts;

-- Inventaire ciblé des fonctions pouvant affecter la fiche financière.
-- Recherche indicative : une occurrence de champ ne prouve pas une écriture.
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS arguments,
       (p.prosrc ~* '(SET|,)[[:space:]]*arg[[:space:]]*=') AS mention_affectation_arg,
       (p.prosrc ~* '(SET|,)[[:space:]]*liquide[[:space:]]*=') AS mention_affectation_liquide,
       (p.prosrc ~* '(SET|,)[[:space:]]*banque[[:space:]]*=') AS mention_affectation_banque
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND (p.prosrc ~* '(SET|,)[[:space:]]*arg[[:space:]]*='
    OR p.prosrc ~* '(SET|,)[[:space:]]*liquide[[:space:]]*='
    OR p.prosrc ~* '(SET|,)[[:space:]]*banque[[:space:]]*=')
ORDER BY p.proname, arguments;
