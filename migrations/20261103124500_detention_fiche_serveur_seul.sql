-- =============================================================================================
-- LA DÉTENTION SUR LA FICHE EST ÉCRITE PAR LE SERVEUR SEUL (Claude, 03/11/2026)
-- =============================================================================================
-- Relevé du 03/11 (RELAIS.md, point 5). Les quatre portes de détention encore ouvertes à
-- l'écran (detention_ouvrir_soi, detention_prolonger_soi, detention_clore_purgee,
-- detention_clore_motif_eteint) ne donnent rien au joueur : deux l'enferment, deux constatent
-- une fin réelle. Mais les deux portes de fin vérifient la peine LUE SUR LA FICHE
-- (est_emprisonne : debutTs, jours, motifDesertionSeul), et la fiche restait réécrivable par la
-- sauvegarde générale de l'écran (vue personnages, fusion à trois voies : un champ modifié par
-- l'écran l'emporte). Un joueur pouvait donc :
--   . vider est_emprisonne et sortir de cellule sans fin de peine ;
--   . raccourcir debutTs/jours, puis faire constater par detention_clore_purgee une fin fictive ;
--   . poser motifDesertionSeul et se faire libérer par detention_clore_motif_eteint ;
--   . effacer detention_qhs (plafond de PA du quartier de haute sécurité).
--
-- Toutes les écritures légitimes de ces deux colonnes sont déjà faites par des fonctions
-- serveur (ouverture, prolongation, QHS, clôtures, évasion, rébellion, passe de nuit) : l'écran
-- ne fait plus que recopier leurs réponses. Le verrou vient donc en dernier, comme prévu :
-- personnages_vue_modifier garde la valeur du serveur pour est_emprisonne et detention_qhs
-- quand l'écriture vient de l'écran. Rien d'autre ne change.
--
-- Patch en place d'un fragment vérifié de la fonction en production (une seule occurrence).
-- =============================================================================================

DO $patch$
DECLARE
  v_def  text := pg_get_functiondef('public.personnages_vue_modifier()'::regprocedure);
  v_ancre text := E'    NEW.banque            := v_canon.banque;\n';
  v_ajout text := E'    NEW.banque            := v_canon.banque;\n'
               || E'    -- detention_fiche_serveur_seul_v1 : la peine et le QHS ne s''écrivent que par le serveur.\n'
               || E'    NEW.est_emprisonne    := v_canon.est_emprisonne;\n'
               || E'    NEW.detention_qhs     := v_canon.detention_qhs;\n';
BEGIN
  IF position('detention_fiche_serveur_seul_v1' in v_def) > 0 THEN
    RAISE NOTICE 'personnages_vue_modifier : verrou de détention déjà posé';
    RETURN;
  END IF;
  IF (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre) <> 1 THEN
    RAISE EXCEPTION 'personnages_vue_modifier : ancre absente ou multiple, patch refusé';
  END IF;
  EXECUTE replace(v_def, v_ancre, v_ajout);
END $patch$;

-- Contrôles
DO $$
DECLARE v_def text := pg_get_functiondef('public.personnages_vue_modifier()'::regprocedure);
BEGIN
  IF position('NEW.est_emprisonne    := v_canon.est_emprisonne;' in v_def) = 0
     OR position('NEW.detention_qhs     := v_canon.detention_qhs;' in v_def) = 0 THEN
    RAISE EXCEPTION 'verrou de détention absent de personnages_vue_modifier';
  END IF;
  -- Le verrou doit se trouver dans la branche écran (avant le premier END IF qui la ferme).
  IF position('detention_fiche_serveur_seul_v1' in v_def) > position('v_verrou := public.rp_transition_active' in v_def) THEN
    RAISE EXCEPTION 'verrou de détention mal placé';
  END IF;
END $$;
