-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260927170538
-- Nom original      : socle_pnj_deputes_presence_conditionnelle
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-27 17:05:38 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 4869025d532b75f1fc226e667a5c8600
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
-- CHECKPOINT D — LA PRESENCE CONDITIONNELLE DES DEPUTES GAMMA
--
-- CONSTAT AVANT D'ECRIRE : la regle demandee EXISTE DEJA, et c'est exactement celle-la.
-- `assemblee_sieges` porte en permanence l'identite du depute Gamma (pnj_id, pnj_nom) et n'est
-- JAMAIS videe ; `assemblee_occupation_sieges` fait un LEFT JOIN sur les PJ portant poste_depute
-- pour la ville et le rang, et rend `est_pnj = (aucun PJ trouve)`. Donc :
--   * siege sans depute PJ  -> le Gamma est present ;
--   * PJ elu sur ce rang    -> le Gamma est absent, mais sa ligne reste intacte ;
--   * le PJ perd son siege  -> le LEFT JOIN ne trouve plus rien, LE MEME Gamma revient, avec son
--                              nom, son identifiant et sa fonction.
-- Il n'y avait donc rien a construire : la presence est DERIVEE, jamais stockee, ce qui la rend
-- reversible par construction. Ajouter un drapeau `present` en dur aurait cree un etat a maintenir,
-- donc un etat capable de se desynchroniser.
--
-- CE QUE CETTE MIGRATION AJOUTE : une lecture qui NOMME la regle, avec presence 1/0 explicite, pour
-- que personne n'ait a la rededuire du LEFT JOIN.
--
-- NE PAS GENERALISER. La disparition conditionnelle est propre aux DEPUTES. Un Commissaire, un Juge
-- ou un Grand Pretre Gamma RESTE PRESENT quand un PJ reprend sa fonction : le Commissaire Touffaud
-- ne s'evapore pas parce que le maire a nomme un Commissaire PJ, il cesse seulement d'etre le
-- titulaire du poste. Existence et titularite sont deux choses distinctes.
--
-- AUCUNE CARACTERISTIQUE N'EST INVENTEE. Les neuf deputes Gamma ont deja leurs valeurs dans
-- PNJ_STATS_NOMMES (data.js), lues par assemblee_taux_marchandage. Aucun profil « depute » n'a ete
-- arbitre, donc aucun n'est cree ici.
CREATE OR REPLACE FUNCTION public.depute_presence(p_country text DEFAULT 'republic')
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT jsonb_build_object('ok', true, 'pays', p_country,
    'sieges', COALESCE((SELECT jsonb_agg(jsonb_build_object(
        'siege_id', o.siege_id, 'ville', o.city, 'rang', o.rang,
        -- IDENTITE GAMMA, conservee en toute circonstance.
        'pnj_id', o.pnj_id, 'pnj_nom', o.pnj_nom, 'fonction', 'depute', 'classe', 'gamma',
        -- PRESENCE : 1 present, 0 absent. Derivee, jamais stockee.
        'present', CASE WHEN o.est_pnj THEN 1 ELSE 0 END,
        'occupe_par_pj', o.pj_nom,
        -- L'endormissement est une entrave METIER, distincte de l'absence : un depute endormi est
        -- PRESENT mais empeche de voter. Il ne disparait pas.
        'endormi', COALESCE(o.endormi, false))
      ORDER BY o.city, o.rang)
      FROM public.assemblee_occupation_sieges(p_country) o), '[]'::jsonb),
    'presents', (SELECT count(*) FROM public.assemblee_occupation_sieges(p_country) o WHERE o.est_pnj),
    'absents',  (SELECT count(*) FROM public.assemblee_occupation_sieges(p_country) o
                  WHERE NOT o.est_pnj));
$$;

COMMENT ON TABLE public.assemblee_sieges IS
  'Sieges de l''Assemblee. Porte l''identite PERMANENTE du depute Gamma de chaque siege : cette '
  'ligne n''est jamais videe, meme quand un PJ occupe le siege. La PRESENCE du Gamma est derivee '
  '(assemblee_occupation_sieges / depute_presence), donc reversible : quand le PJ s''en va, LE MEME '
  'depute revient. Ne jamais supprimer une ligne pour representer une absence.';

REVOKE ALL ON FUNCTION public.depute_presence(text) FROM anon;