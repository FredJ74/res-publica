-- =====================================================================================
-- RENSEIGNEMENT — DECOUPLAGE COUVERTURE / POSITION PHYSIQUE
-- 22 septembre 2026
-- =====================================================================================
-- LA DETTE. agents_renseignement porte ville/building_id/room_id mais AUCUN pays de
-- presence. Le moteur se servait donc de `pays_couverture` comme pays de localisation --
-- ce qui tenait debout uniquement parce que agent_deposer interdisait de poser un agent
-- hors de son pays de couverture : les deux valeurs etaient forcees egales.
--
-- L'arbitrage du 22 septembre 2026 rend la couverture PUREMENT NARRATIVE (tenue, faux nom,
-- profession fictive). La garantie d'egalite tombe, et les neuf fonctions qui lisaient
-- `pays_couverture` comme une position deviendraient silencieusement fausses : un agent
-- sous couverture khalijienne poste a Sovarka chercherait ses faits a Al-Khalija et ne
-- serait arretable que par la justice khalijienne.
--
-- CE QUE FAIT CETTE MIGRATION
--   1. Ajoute `pays` : le pays de PRESENCE PHYSIQUE, distinct de `pays_couverture`.
--      Additive. `pays_couverture` n'est ni supprime ni modifie -- il reste la donnee
--      narrative, et l'unicite (pays_couverture, nom_couverture) reste en place.
--   2. Backfill deterministe depuis pays_couverture : jusqu'a aujourd'hui les deux etaient
--      egaux par construction, donc l'etat des agents existants est rigoureusement conserve.
--   3. Pose agent_position_effective() : la position d'un agent pose est la sienne ; celle
--      d'un agent PORTE est celle de son porteur, resolue A LA LECTURE. Aucune copie
--      synchronisee a chaque deplacement -- le wagon est a la position de sa locomotive.
--   4. Reecrit les fonctions de collecte, de trace, de contre-espionnage et de detention
--      pour qu'elles raisonnent sur cette position effective.
--   5. Remplace la regle « porte => ne collecte pas » par la seule regle voulue : un agent
--      encore DANS LE BUREAU DU MINISTRE ne collecte pas. Ailleurs, il travaille -- y
--      compris pendant son transport.
--
-- Le lieu « bureau du ministre de la Defense » est nomme ici et dans plateau-core.js
-- (BATIMENT_BUREAU_MIN_DEF / PIECE_BUREAU_MIN_DEF) : les deux doivent rester identiques.
-- =====================================================================================

-- ---------------------------------------------------------------------------------
-- 1. SCHEMA — additif
-- ---------------------------------------------------------------------------------
ALTER TABLE public.agents_renseignement ADD COLUMN IF NOT EXISTS pays text;

COMMENT ON COLUMN public.agents_renseignement.pays IS
  'Pays de PRESENCE PHYSIQUE de l''agent pose. NULL tant qu''il n''a jamais ete pose. '
  'Ne jamais confondre avec pays_couverture, qui est purement narratif.';
COMMENT ON COLUMN public.agents_renseignement.pays_couverture IS
  'Pays de la COUVERTURE : tenue, faux nom, profession fictive. Aucun effet mecanique. '
  'N''est JAMAIS une localisation (arbitrage du 22 septembre 2026).';

-- 2. BACKFILL — uniquement pour les agents reellement poses (ville renseignee). Un agent
--    non pose n'a pas de position, et s'en inventer une serait une donnee fausse.
UPDATE public.agents_renseignement
   SET pays = pays_couverture
 WHERE pays IS NULL AND ville IS NOT NULL;

-- 3. INDEX DE POSITION. Il portait (pays_couverture, ville, building_id) -- c'est-a-dire
--    la conflation elle-meme. On le repose sur le vrai pays. L'index d'unicite des
--    couvertures, lui, est LEGITIME et n'est pas touche.
DROP INDEX IF EXISTS public.idx_agents_position;
CREATE INDEX IF NOT EXISTS idx_agents_position
    ON public.agents_renseignement (pays, ville, building_id)
 WHERE statut = 'actif';

-- ---------------------------------------------------------------------------------
-- 4. POSITION EFFECTIVE — la primitive centrale
-- ---------------------------------------------------------------------------------
-- Agent pose        -> sa position propre.
-- Agent porte par X -> la position serveur de X, lue au moment ou on en a besoin.
-- STABLE et sans effet de bord : utilisable en jointure laterale comme en appel direct.
CREATE OR REPLACE FUNCTION public.agent_position_effective(p_agent_id text)
RETURNS TABLE(pays text, ville text, building_id text, room_id text, porte boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT
    CASE WHEN ag.leader_courant IS NULL THEN ag.pays        ELSE d.country          END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.ville       ELSE d.current_city     END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.building_id ELSE d.current_building END,
    CASE WHEN ag.leader_courant IS NULL THEN ag.room_id     ELSE d.current_room     END,
    ag.leader_courant IS NOT NULL
  FROM public.agents_renseignement ag
  LEFT JOIN public.personnages_donnees d ON d.name = ag.leader_courant
  WHERE ag.id = p_agent_id;
$$;

-- Un agent encore dans le bureau du ministre ne collecte rien. Le compteur de l'operation,
-- lui, court depuis la convocation -- ce sont deux choses distinctes.
CREATE OR REPLACE FUNCTION public.agent_au_bureau_min_def(p_bat text, p_piece text)
RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT p_bat = 'palais-gouvernement' AND p_piece = 'bureau_min_def';
$$;

GRANT EXECUTE ON FUNCTION public.agent_position_effective(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.agent_au_bureau_min_def(text, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------------
-- 5. FONCTIONS REECRITES
-- ---------------------------------------------------------------------------------
-- Appliquees en quatre migrations successives, dans cet ordre :
--   renseignement_position_effective_socle            (schema, backfill, index, primitives)
--   renseignement_collecte_position_effective         (trace, traducteur, conseillere, garde)
--   renseignement_decouplage_couverture_et_transfert  (balayage, depot, prise, transfert)
--   renseignement_coordinateurs_position_effective    (multimodal, port)
--
-- Chacune remplace le garde « leader_courant IS NOT NULL => agent_non_pose » par le couple
--   position effective absente        -> agent_sans_position
--   position effective = bureau MinDef -> agent_au_bureau
-- et substitue la position effective a pays_couverture partout ou celui-ci tenait lieu de
-- localisation. Le corps source complet de chaque fonction est en base (pg_proc) ; il n'est
-- pas duplique ici pour eviter deux verites divergentes.
--
-- SEUL USAGE DE pays_couverture CONSERVE : cellule_renseignement_creer, qui attribue une
-- identite de couverture libre dans le pays choisi. C'est l'usage narratif legitime.

-- ---------------------------------------------------------------------------------
-- 6. PORTRAITS — CHEMIN PAR ROLE, JAMAIS PAR IDENTITE
-- ---------------------------------------------------------------------------------
-- Migration renseignement_portraits_par_role. Le chemin etait bati sur le vrai nom de
-- l'agent : un joueur qui transporte l'equipe sans rien savoir d'elle pouvait lire
-- « raymond-hialiste-khalija.png » dans les outils de son navigateur et percer la
-- couverture. agent_portrait_chemin(role, pays) ne nomme plus personne.
-- 16 fichiers attendus dans images/renseignement/ :
--   garde|traducteur|conseiller|coordinateur  x  republic|narco|soviet|khalija  (.png)
-- republic sert d'apparence neutre avant tout choix de couverture. Tant qu'ils manquent,
-- l'attribut onerror du client retombe sur l'avatar generique du job.
