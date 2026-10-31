-- APPLICATION ATTESTÉE par le registre canonique du 31/10/2026 : version 20261030192146.
-- Archivage documentaire seulement ; ne pas rejouer.
-- =====================================================================================
-- PORTE DE LA FICHE : REFUS BRUYANT DANS UNE FONCTION SERVEUR (30/10/2026, Claude). NON APPLIQUÉE.
-- À appliquer APRÈS 20261030210000. Compatible avec l'écran en ligne.
--
-- Pourquoi : la vue `personnages` est la porte de l'ÉCRAN. Pour tout appel joueur, sa garde
-- (personnages_vue_modifier) corrige EN SILENCE espèces, fortune, banque, caractéristiques,
-- points libres, qualifications et hausse de PA. C'est voulu pour une sauvegarde d'écran
-- périmée, mais une fonction serveur lancée par un joueur (RPC) qui écrivait par cette porte
-- voyait son effet annulé sans erreur, le reste de la transaction passant : 150 000 FR de
-- Jean Jaaj perdus (débit du compte Helvetia validé, crédit des espèces annulé).
--
-- Règle désormais tenue par la base : dans une requête RPC (request.path = '/rpc/…', posé par
-- PostgREST), toute tentative de changer l'un de ces champs PAR LA VUE lève
-- `fiche_ecriture_serveur_par_la_vue` : l'action entière est annulée, rien n'est perdu à moitié,
-- l'erreur est nommée. Les fonctions serveur écrivent `personnages_donnees`.
-- Inchangé : les sauvegardes directes de l'écran (request.path = '/personnages') gardent la
-- correction silencieuse ; le serveur (service_role, cron) n'est pas concerné.
-- Vérifié avant écriture : après 20261030210000, plus aucune fonction n'écrit ces champs par la vue
-- (aucune écriture dynamique, aucun INSERT dans la vue).
-- =====================================================================================
DO $migration$
DECLARE
  d text;
  v_source text := $s$    NEW.user_id := v_canon.user_id;
$s$;
  v_cible text := $c$    NEW.user_id := v_canon.user_id;

    -- REFUS BRUYANT (30/10/2026) : une fonction serveur lancée par un joueur n'écrit jamais
    -- l'argent ni les champs protégés par cette porte ; sinon l'effet serait annulé en silence.
    IF coalesce(current_setting('request.path', true), '') LIKE '/rpc/%' AND (
         NEW.arg IS DISTINCT FROM OLD.arg
      OR NEW.liquide IS DISTINCT FROM OLD.liquide
      OR NEW.banque IS DISTINCT FROM OLD.banque
      OR NEW.stats IS DISTINCT FROM OLD.stats
      OR NEW.free_pts_restants IS DISTINCT FROM OLD.free_pts_restants
      OR NEW.qualifications IS DISTINCT FROM OLD.qualifications
      OR coalesce(NEW.pa, 0) > coalesce(OLD.pa, 0)) THEN
      RAISE EXCEPTION 'fiche_ecriture_serveur_par_la_vue'
        USING ERRCODE = 'P0001',
              DETAIL = 'Une fonction serveur doit écrire public.personnages_donnees, pas la vue de l''écran.';
    END IF;
$c$;
BEGIN
  d := pg_get_functiondef('public.personnages_vue_modifier()'::regprocedure);
  IF position('fiche_ecriture_serveur_par_la_vue' IN d) > 0 THEN RETURN; END IF;
  IF md5(d) <> '0faa799957826bedba20ba372d0bd8ae' THEN
    RAISE EXCEPTION 'personnages_vue_modifier : corps différent de celui relevé le 30/10 (md5 %)', md5(d);
  END IF;
  IF (length(d) - length(replace(d, v_source, ''))) / length(v_source) <> 1 THEN
    RAISE EXCEPTION 'personnages_vue_modifier : point d''insertion absent ou multiple';
  END IF;
  EXECUTE replace(d, v_source, v_cible);
END $migration$;
