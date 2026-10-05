-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927151757
-- Nom original      : socle_pnj_classe_gamma_depute_et_titulaire_de_poste
-- Categorie         : DML -- DML seul (mutation de donnees)
-- Date (deduite de la version) : 2026-09-27 15:17:57 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 57627eab28370e34bd0637e1c2946de2
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
-- CHECKPOINT D — LA CLASSE GAMMA EST DECLAREE POUR SES DEUX FAMILLES REELLES
--
-- Deux familles Gamma existent VRAIMENT, avec des donnees de production, et aucune ligne dans
-- pnj_membres :
--
--   * TITULAIRE PNJ DE POSTE -- 16 lignes dans `titulaires_pnj` (Premier Ministre, 5 ministres,
--     3 juges de ville + le juge national, Commandant, Chef des Douanes, Capitaine du Port et
--     3 directeurs d'industrie). Il occupe un poste tant qu'aucun PJ ne le prend. `pnj_institutions`
--     dit deja l'essentiel : un titulaire PNJ n'est PAS une autorite -- propriete institutionnelle
--     n'est pas autorite humaine.
--
--   * DEPUTE PNJ -- 9 lignes dans `assemblee_sieges`, 3 par ville. Il vote, on marchande son
--     intention, et un joueur peut l'ENDORMIR (`assemblee_neutraliser_depute`) jusqu'au reveil de
--     minuit. Verifie : cette neutralisation ne le tue pas, ne le deplace pas et ne l'approprie
--     pas -- elle empeche son METIER. Elle est donc compatible avec Gamma, qui interdit la mort et
--     la propriete, pas l'entrave politique. Verifie aussi : AUCUNE fonction de l'Assemblee ne
--     touche les PA d'un depute ; `assemblee_debiter_joueur` debite le JOUEUR.
--
-- CE QUE CETTE DECLARATION FAIT. Elle est PREVENTIVE et ne cree aucune donnee. Le jour ou l'une de
-- ces familles entrera dans pnj_membres, les gardes generiques seront deja en place :
--   - `pnj_pa_garde` refusera toute variation de PA, puisque seule la classe alpha en consomme ;
--   - `pnj_axe_verrouille` verrouillera chaque axe, l'autorite etant 'institution' ;
--   - `pnj_mouvement_individuel_refus` interdira de les prendre dans un groupe.
-- Autrement dit : on ne peut pas transformer un PNJ institutionnel en employe par accident.
--
-- CE QU'ELLE NE FAIT PAS. Elle ne les inscrit pas au socle. Les inscrire exigerait de decider OU
-- ils se trouvent physiquement -- ni `titulaires_pnj` ni `assemblee_sieges` ne portent de position,
-- et la regle spatiale veut que PJ et PNJ vivent dans le meme monde. C'est un arbitrage, pas une
-- migration : je ne l'invente pas.
INSERT INTO public.pnj_familles_classes (famille, classe, note) VALUES
  ('titulaire_poste', 'gamma',
   'Occupe un poste vacant tant qu''aucun PJ ne le prend. Donnees : titulaires_pnj (16 lignes, '
   || 'poste_id + city, la ville NULL valant national). Aucune caracteristique, aucun PA, aucune '
   || 'possession, aucune position stockee. N''EST PAS UNE AUTORITE : un poste tenu par un PNJ '
   || 'laisse l''autorite humaine vacante, et "personne" est un etat valide. Pas inscrit dans '
   || 'pnj_membres : sa position physique n''est definie nulle part et l''inventer serait un '
   || 'arbitrage.'),
  ('depute', 'gamma',
   'Depute PNJ siegeant a l''Assemblee. Donnees : assemblee_sieges (9 lignes, 3 par ville). Vote, '
   || 'son intention se marchande (assemblee_marchander), et un joueur peut l''endormir '
   || '(assemblee_neutraliser_depute) jusqu''a assemblee_reveil_minuit. Cette entrave est METIER : '
   || 'elle ne tue pas, ne deplace pas, n''approprie pas. Aucun PA : aucune fonction de '
   || 'l''Assemblee n''en touche. Pas inscrit dans pnj_membres, pour la meme raison que le '
   || 'titulaire de poste.')
ON CONFLICT (famille) DO UPDATE SET classe = EXCLUDED.classe, note = EXCLUDED.note;

INSERT INTO public.pnj_mouvement_individuel (famille, autorise, raison, note) VALUES
  ('titulaire_poste', false, 'pnj_institutionnel',
   'Un titulaire de poste n''est employable par personne. Le prendre dans un groupe reviendrait a '
   || 'transformer une institution en employe.'),
  ('depute', false, 'pnj_institutionnel',
   'Un depute ne se recrute pas. On negocie son vote ou on l''endort ; on ne l''emmene pas.')
ON CONFLICT (famille) DO UPDATE SET autorise = EXCLUDED.autorise,
  raison = EXCLUDED.raison, note = EXCLUDED.note;

-- Tous les axes generiques de ces deux familles sont sous autorite de leur institution.
INSERT INTO public.pnj_axes_autorite (famille, axe, autorite, note)
SELECT f.famille, a.axe, 'institution',
       'Classe gamma : l''institution qui porte ce PNJ decide, le socle ne decide rien. '
       || 'Le verrou d''axe est donc ferme, par construction.'
  FROM (VALUES ('titulaire_poste'), ('depute')) f(famille),
       (VALUES ('position_leader'), ('pa'), ('possessions'), ('argent'), ('propriete')) a(axe)
ON CONFLICT (famille, axe) DO UPDATE SET autorite = EXCLUDED.autorite, note = EXCLUDED.note;