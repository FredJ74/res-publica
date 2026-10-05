-- ============================================================================
-- MIGRATION HISTORIQUE -- DEJA APPLIQUEE -- NE PAS EXECUTER
-- ============================================================================
-- Version Supabase  : 20260914205103
-- Nom original      : entrepots_fournisseurs_etrangers
-- Categorie         : DDL -- DDL seul (structure, droits, commentaires)
-- Date (deduite de la version) : 2026-09-14 20:51:03 UTC
-- Etat              : DEJA APPLIQUEE A LA BASE DE PRODUCTION
-- MD5 du SQL historique : 3fe3a103727242cc0ec9de2bd2a5d723
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
-- FOURNISSEURS ETRANGERS. Aucun entrepot etranger n'existait dans le jeu : il fallait en
-- definir. Plutot que d'inventer un catalogue, le tarif est DERIVE des relations commerciales
-- deja codees dans le cron (ORIGINE_IMPORTS_PORT) :
--   - le petrole arrive deja d'Al-Khalija et de Sovarka ;
--   - les produits exotiques arrivent deja d'El Estado.
-- Regle retenue : un pays qui APPROVISIONNE deja Republia en une ressource la vend a son prix
-- fournisseur (prix_achat_fournisseur, son prix de production) ; tout autre pays la revend au
-- prix de reference (prix_base). Un producteur est donc reellement moins cher que les autres,
-- sans qu'aucun chiffre n'ait ete invente pour ce lot.
--
-- Le stock etranger est volontairement ILLIMITE (quantite NULL) : le jeu n'a aucun modele de
-- stock etranger, et en fabriquer un serait inventer une economie entiere. Les fournisseurs
-- etrangers jouent donc le role d'un marche mondial de dernier recours -- toujours disponible,
-- mais plus cher une fois le fret ajoute. Voir rapport : la differenciation tarifaire et la
-- finitude des stocks etrangers sont deux points d'arbitrage possibles.
CREATE OR REPLACE FUNCTION public.fournisseurs_etrangers()
RETURNS TABLE (pays text, libelle text, ressource text, prix_unitaire numeric, disponible integer)
LANGUAGE sql STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  WITH pays_etrangers(code, nom) AS (
    VALUES ('narco', 'El Estado'), ('soviet', 'Sovarka'), ('khalija', 'Al-Khalija')
  ),
  -- Relations d'approvisionnement REELLES, recopiees de ORIGINE_IMPORTS_PORT (api/cron-minuit.js).
  producteurs(code, ressource) AS (
    VALUES ('khalija', 'petrole'), ('soviet', 'petrole'), ('narco', 'produits_exotiques')
  )
  SELECT p.code,
         p.nom,
         r.cle,
         CASE WHEN EXISTS (SELECT 1 FROM producteurs pr WHERE pr.code = p.code AND pr.ressource = r.cle)
              THEN r.prix_achat_fournisseur ELSE r.prix_base END,
         NULL::integer
    FROM pays_etrangers p
    CROSS JOIN public.ressources_economie r
   WHERE r.source = 'livraison';
$$;

REVOKE ALL ON FUNCTION public.fournisseurs_etrangers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fournisseurs_etrangers() TO anon, authenticated;

-- Fret international : 0,40 FR par unite (audit du 14 septembre : c'est le tarif reellement en
-- vigueur pour la caisse de fret joueur, 200 FR pour 500 unites). Cout logistique pur, absorbe :
-- il n'est credite a personne. AUCUN droit de douane sur les commandes institutionnelles --
-- le prelevement de 10 % de la caisse de fret joueur n'est deliberement pas reutilise ici.
CREATE OR REPLACE FUNCTION public.fret_unitaire_international()
RETURNS numeric LANGUAGE sql IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $$ SELECT 0.40::numeric; $$;

REVOKE ALL ON FUNCTION public.fret_unitaire_international() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fret_unitaire_international() TO anon, authenticated;
