-- ============================================================================
-- CHANTIER 4C -- LES DEUX EMPREINTES REELLES QUI MANQUAIENT
--
-- Le depot surveille ses tables miroir en comparant deux valeurs : l'empreinte
-- POSEE (une ligne dans <miroir>_empreinte, ecrite au moment de la generation)
-- et l'empreinte REELLE (une fonction qui rehache le contenu present). Quand la
-- fonction manque, la valeur posee n'est confrontee a rien : elle peut etre
-- fausse pendant des mois sans que rien ne s'allume. C'est exactement ce qui
-- s'est passe.
--
-- Deux miroirs sur quatre avaient leur fonction (ordres_couts,
-- ressources_economie). Les deux autres ne l'avaient pas. Cette migration ne
-- fait QUE les ajouter. Elle ne touche a aucune donnee, a aucune table, a aucun
-- droit et a aucune policy : si on ne peut pas ajouter un thermometre sans
-- deplacer le malade, on n'a pas un thermometre, on a un traitement.
--
-- Mesure du 6 octobre 2026, lecture seule, AVANT cette migration :
--
--   miroir                 lignes   posee              reelle             data.js
--   pa_bonus_differes          10   1c02ca809fdb9b8b   (absente)          1c02ca809fdb9b8b
--   postes_nommes_regles       17   a2993a8bc519ea01   (absente)          73985f702ae09796
--   ressources_economie        17   2c2a88b3833ca978   2c2a88b3833ca978   2c2a88b3833ca978
--   ordres_couts              405   6de4a84c58ed9b2b   a9ee71d9294ffaa8   55038ed4d716d140
--
-- Les deux colonnes « reelle » de cette migration ont ete mesurees en executant
-- les expressions ci-dessous telles quelles, en SELECT, sur la base reelle :
--   pa_bonus_differes    -> 1c02ca809fdb9b8b  (= posee = data.js : les trois concordent)
--   postes_nommes_regles -> 73985f702ae09796  (= data.js ; la valeur POSEE, elle, est perimee)
--
-- AUCUNE DONNEE N'EST CORRIGEE ICI, ni les deux valeurs posees perimees, ni la
-- derive d'ordres_couts. Les faire concorder en touchant au contenu serait
-- fabriquer le resultat du controle. Elles sont declarees dans
-- outils/baseline/referentiels.json et fermees par un lot explicite.
--
-- Idempotente : CREATE OR REPLACE.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- postes_nommes_regles : les CINQ colonnes, et la valeur QUE LE MOTEUR LIT
--
-- Deux decisions, chacune payee par une mesure.
--
-- 1. CINQ colonnes. L'ancienne formule posee n'en couvrait que trois
--    (poste_id, nomme_par, scope) : ni label, ni autorite_scope. Une empreinte
--    qui ignore une colonne ne protege pas cette colonne -- et c'est
--    litteralement comme cela que l'absence d'autorite_scope dans l'extracteur
--    du generateur a pu vivre sans etre vue. Rejouer le generateur dans cet
--    etat remettait autorite_scope a NULL pour le juge, et le ministre de la
--    Justice (city NULL) ne pouvait plus le nommer.
--
-- 2. autorite_scope est hache par sa valeur EFFECTIVE,
--    coalesce(autorite_scope, scope), parce que c'est ce que lit
--    poste_autorite_de. data.js ne declare autoriteScope que pour le juge
--    (data.js:7667) ; la base, elle, porte les dix-sept valeurs. Hacher la
--    valeur brute ferait donc diverger les deux cotes -- 2f2738f9a4e2ada6
--    contre 73985f702ae09796 -- pour une difference qui ne change RIEN au
--    comportement : les seize autres postes ont autorite_scope = scope,
--    verifie ligne par ligne en base. Une empreinte doit mesurer ce que le jeu
--    lit ; sinon elle signale un ecart qui n'existe pas, et on apprend a
--    l'ignorer.
--
-- COLLATE "C" sur le tri n'est pas un ornement : Python trie par point de
-- code, la collation de la base ignore la ponctuation au premier niveau. Deux
-- tris differents sur le meme contenu donnent deux hachages differents.
-- Le pendant exact est outils/generateurs/generer_postes_nommes.py, empreinte().
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.postes_nommes_regles_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(
      poste_id || '|' || coalesce(label, '')
               || '|' || coalesce(nomme_par, '')
               || '|' || coalesce(scope, '')
               || '|' || coalesce(autorite_scope, scope, ''),
      E'\n' ORDER BY poste_id COLLATE "C")), 16)
  FROM public.postes_nommes_regles;
$function$;

COMMENT ON FUNCTION public.postes_nommes_regles_empreinte_reelle() IS
  'Empreinte reelle du miroir des regles de nomination, sur les cinq colonnes et '
  'sur la valeur effective de autorite_scope (coalesce(autorite_scope, scope)), '
  'celle que lit poste_autorite_de. Pendant SQL de '
  'outils/generateurs/generer_postes_nommes.py. Chantier 4C.';

-- ---------------------------------------------------------------------------
-- pa_bonus_differes : deux colonnes, et c'est tout ce que la table a
--
-- montant est un integer NOT NULL ; montant::text rend la meme chaine que
-- str(int) cote Python. collecter() rend dict(sorted(...)), soit un tri par
-- point de code : d'ou COLLATE "C" ici aussi.
-- Pendant exact : outils/generateurs/generer_pa_bonus_differes.py, empreinte().
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pa_bonus_differes_empreinte_reelle()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT left(md5(string_agg(source || '|' || montant::text,
                             E'\n' ORDER BY source COLLATE "C")), 16)
  FROM public.pa_bonus_differes;
$function$;

COMMENT ON FUNCTION public.pa_bonus_differes_empreinte_reelle() IS
  'Empreinte reelle du miroir des bonus de PA differes. Pendant SQL de '
  'outils/generateurs/generer_pa_bonus_differes.py. Chantier 4C.';
