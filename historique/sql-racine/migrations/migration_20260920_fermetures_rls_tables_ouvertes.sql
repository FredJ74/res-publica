-- =============================================================================
-- FERMETURE DE DEUX TABLES RESTEES OUVERTES EN ECRITURE
-- =============================================================================
-- Date d'application en production : 20 septembre 2026.
--
-- CE FICHIER EST UN RATTRAPAGE DE VERSIONNEMENT. Il reproduit l'ETAT FINAL
-- present en production, pas l'historique de la session.
--
-- MIGRATIONS DE PRODUCTION ABSORBEES, DANS L'ORDRE CHRONOLOGIQUE :
--   20260920123041  fermeture_lois_assemblee_morte
--   20260920123205  football_pari_engager_atteste
--   20260920123308  fermeture_paris_sportifs
--
-- DEUX FERMETURES QUI NE SE RESSEMBLENT PAS. C'est le point a retenir de ce
-- fichier, et la raison pour laquelle les trois sections sont separees :
--
--   * public.lois_assemblee est une TABLE MORTE. On ne la ferme pas parce
--     qu'un flux legitime a ete deplace ailleurs, mais parce qu'IL N'Y EN A
--     PLUS AUCUN : le moteur de l'Assemblee a ete refait le 10 septembre 2026
--     (un vote par ligne dans assemblee_votes, cloture serveur par
--     assemblee_cloturer) et plus personne ne lit ni n'ecrit cette table. Elle
--     n'est remplacee par rien dans ce fichier : aucune RPC ne lui succede.
--
--   * public.paris_sportifs est VIVANTE. Elle est fermee parce que son
--     ecriture passe DESORMAIS par une porte serveur attestee,
--     football_pari_engager(), creee a la section 2. L'ordre compte : la porte
--     est ouverte AVANT que la table ne soit fermee -- sinon la production
--     casse entre les deux migrations.
--
-- DEPENDANCES A REJOUER AVANT CE FICHIER
-- -----------------------------------------------------------------------------
--   * migration_assemblee_nationale.sql -- pertinent pour la SECTION 1 : c'est
--     le lot qui a remplace lois_assemblee par assemblee_votes /
--     assemblee_cloturer, donc ce qui rend cette table morte. Il ne cree pas
--     lois_assemblee elle-meme (socle hors depot) mais il en explique la mort.
--   * migration_championnat_rls.sql -- pertinent pour les SECTIONS 2 et 3 :
--     seul fichier du depot qui mentionne paris_sportifs, et lot de reference
--     du championnat (table public.championnat, id = 2).
--   * migration_fortune_et_paris.sql -- pertinent pour la SECTION 3 : il porte
--     football_paris_resoudre(), la RPC SECURITY DEFINER qui resout et paie les
--     paris et que la RLS ne concerne pas. Sans elle, fermer la table en
--     ecriture bloquerait la resolution.
--   * public.mon_personnage() : socle du chantier B (auth / RLS), sans fichier
--     dedie dans le depot.
--   * public.personnages_donnees : socle du chantier B.
--
-- CE QUI N'EXISTE PAS DANS CE LOT
-- -----------------------------------------------------------------------------
-- Aucune reparation ponctuelle de donnees : les trois migrations n'ecrivent
-- aucun UPDATE ni DELETE sur des lignes metier.


-- =============================================================================
-- SECTION 1 — lois_assemblee : FERMETURE D'UNE TABLE MORTE
-- =============================================================================
-- Migration de production : 20260920123041 fermeture_lois_assemblee_morte.
--
-- §6.3 — FERMETURE DE lois_assemblee
-- ---------------------------------------------------------------------------
-- EXPLOIT MESURE : un joueur ordinaire pouvait promulguer une loi (INSERT
-- reussi sous veritable role authenticated).
--
-- INVENTAIRE DES PRODUCTEURS : AUCUN. Les deux seuls wrappers clients
-- (sbArchiverLoi / sbGetArchivesLois, supabase.js) n'ont plus le moindre
-- appelant -- ni en ecriture, ni en LECTURE. Le moteur de l'Assemblee a ete
-- refait le 10 septembre 2026 : il stocke un vote par ligne (assemblee_votes)
-- et la cloture est faite par le serveur (assemblee_cloturer). Le code le dit
-- lui-meme (plateau-politique.js, vers la ligne 4607) : « La table
-- lois_assemblee et ses wrappers sont laisses en place : ils ne sont plus
-- appeles par personne [...]. Signale au rapport. »
--
-- Fermer cette table ne peut donc casser aucun flux legitime : il n'y en a pas.
--
-- POURQUOI ACTIVER LA RLS NE SUFFIT PAS. Les politiques posees sur cette table
-- sont en USING (true) / WITH CHECK (true) -- « Ecriture publique lois
-- assemblee », « Maj publique ». Les laisser en place et activer la RLS ne
-- changerait strictement RIEN : elles autorisent tout le monde. On les retire,
-- puis RLS active SANS politique = ferme. Le GRANT est revoque en plus, parce
-- que les DEFAULT PRIVILEGES du schema public reaccordent tout a anon sur
-- chaque nouvel objet : les deux couches doivent etre traitees separement.
-- service_role continue de contourner la RLS, comme partout ailleurs.

DROP POLICY IF EXISTS "Ecriture publique lois assemblee" ON public.lois_assemblee;
DROP POLICY IF EXISTS "Lecture publique lois assemblee"  ON public.lois_assemblee;
DROP POLICY IF EXISTS "Maj publique lois assemblee"      ON public.lois_assemblee;

ALTER TABLE public.lois_assemblee ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lois_assemblee FROM anon, authenticated, public;

-- Etat final constate en production le 20 septembre 2026 : relrowsecurity = true
-- et AUCUNE ligne dans pg_policies pour cette table. Table fermee, sans
-- successeur.


-- =============================================================================
-- SECTION 2 — LA PORTE SERVEUR DU PARI : football_pari_engager()
-- =============================================================================
-- Migration de production : 20260920123205 football_pari_engager_atteste.
-- ELLE PRECEDE LA FERMETURE DE LA SECTION 3, ET CET ORDRE EST OBLIGATOIRE.
--
-- §6.3 — LE PARI S'ENGAGE DESORMAIS PAR UN GUICHET SERVEUR
-- ---------------------------------------------------------------------------
-- EXPLOIT MESURE : un joueur ordinaire pouvait inserer une ligne dans
-- paris_sportifs (INSERT reussi sous veritable role authenticated).
--
-- CE QUE CELA PERMETTAIT, PRECISEMENT. football_paris_resoudre() est une RPC
-- rigoureuse : elle retrouve le match, exige qu'il soit JOUE, lit le score
-- persiste, applique ses propres cotes et fait resolution et paiement dans la
-- meme transaction. Mais elle paie ce qu'on lui presente. Il suffisait donc
-- d'inserer, APRES le coup de sifflet, un pari portant le bon pronostic, la
-- mise de son choix et son propre nom -- sans avoir jamais paye la mise, que le
-- client se contentait de retrancher localement (state.arg -= mise).
-- Gain net garanti, sans risque et sans limite.
--
-- LE GUICHET. p_mise est le seul parametre libre, et il est borne ; tout le
-- reste est etabli par le serveur :
--   * le parieur est l'appelant, jamais un nom transmis ;
--   * la saison est lue dans le championnat, pas annoncee ;
--   * le match doit exister dans la journee ET NE PAS ETRE JOUE ;
--   * la mise est reellement prelevee, avant l'inscription, et le pari n'existe
--     pas si le prelevement echoue ;
--   * l'anti-rejeu EST la cle : l'identifiant est deterministe
--     (parieur + saison + journee + match), donc un second pari sur la meme
--     rencontre est refuse par la contrainte, pas par une garde applicative.
--
-- CE QUI N'EST PAS CHANGE ICI, VOLONTAIREMENT : la mise est prise sur `arg` et
-- le gain y est recredite, exactement comme avant. Les cotes (2,5 / 3,5 / 3) et
-- le minimum de 10 FR sont repris tels quels de l'existant. Aucune regle de jeu
-- n'est arbitree dans cette migration -- elle ne fait que rendre serveur ce qui
-- etait client.
-- Note remontee au rapport : le reste de l'economie distingue `liquide`
-- (depensable) de `arg` (fortune affichee) ; les paris vivent entierement dans
-- `arg`. C'est une asymetrie preexistante, a trancher dans le lot monetaire.

CREATE OR REPLACE FUNCTION public.football_pari_engager(
  p_home    text,
  p_away    text,
  p_journee integer,
  p_choix   text,
  p_mise    integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_moi text; v_data jsonb; v_saison integer; v_j jsonb; v_m jsonb;
  v_id text; v_arg numeric;
BEGIN
  v_moi := public.mon_personnage();
  IF v_moi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  IF p_choix IS NULL OR p_choix NOT IN ('domicile', 'nul', 'adversaire') THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'choix_invalide');
  END IF;
  -- Minimum repris de l'ecran existant. Plafond de securite : une mise ne peut
  -- pas etre un nombre arbitraire, meme si le joueur avait les fonds.
  IF p_mise IS NULL OR p_mise < 10 OR p_mise > 1000000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'mise_invalide');
  END IF;

  SELECT data INTO v_data FROM public.championnat WHERE id = 2;
  IF v_data IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'championnat_absent');
  END IF;
  v_saison := coalesce((v_data ->> 'numero')::int, 0);

  SELECT j INTO v_j FROM jsonb_array_elements(coalesce(v_data -> 'calendrier', '[]'::jsonb)) j
   WHERE (j ->> 'numero')::int = p_journee;
  IF v_j IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'journee_inconnue');
  END IF;

  SELECT m INTO v_m FROM jsonb_array_elements(coalesce(v_j -> 'matchs', '[]'::jsonb)) m
   WHERE m ->> 'home' = p_home AND m ->> 'away' = p_away;
  IF v_m IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'match_inconnu');
  END IF;
  -- LE POINT CENTRAL : on ne parie pas sur un resultat connu.
  IF coalesce((v_m ->> 'played')::boolean, false) THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'match_deja_joue');
  END IF;

  v_id := 'pari:' || v_moi || ':' || v_saison || ':' || p_journee || ':' || p_home || ':' || p_away;

  -- La mise EST prelevee, et elle l'est AVANT toute inscription. Verrou sur la
  -- fiche : deux paris simultanes ne peuvent pas depenser le meme argent.
  SELECT coalesce(arg, 0) INTO v_arg
    FROM public.personnages_donnees WHERE name = v_moi FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_introuvable');
  END IF;
  IF v_arg < p_mise THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'fonds_insuffisants',
                              'arg', v_arg, 'mise', p_mise);
  END IF;

  BEGIN
    INSERT INTO public.paris_sportifs (id, resolu, data)
    VALUES (v_id, false, jsonb_build_object(
      'joueur', v_moi, 'homeId', p_home, 'awayId', p_away, 'choix', p_choix,
      'mise', p_mise, 'journeeNumero', p_journee, 'saisonNumero', v_saison));
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pari_deja_engage');
  END;

  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) - p_mise, updated_at = now()
   WHERE name = v_moi
   RETURNING arg INTO v_arg;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'mise', p_mise,
                            'saison', v_saison, 'arg', v_arg);
END;
$$;

REVOKE ALL ON FUNCTION public.football_pari_engager(text, text, integer, text, integer)
  FROM public, anon;
GRANT EXECUTE ON FUNCTION public.football_pari_engager(text, text, integer, text, integer)
  TO authenticated, service_role;


-- =============================================================================
-- SECTION 3 — paris_sportifs : FERMETURE D'UNE TABLE VIVANTE, DERRIERE SA RPC
-- =============================================================================
-- Migration de production : 20260920123308 fermeture_paris_sportifs.
-- A NE JAMAIS REJOUER SANS LA SECTION 2 : sans football_pari_engager, plus
-- personne ne peut engager de pari.
--
-- §6.3 — FERMETURE DE paris_sportifs
-- ---------------------------------------------------------------------------
-- SEQUENCEMENT RESPECTE : le producteur legitime a ete migre AVANT cette
-- fermeture. confirmerPariMatch() (plateau-organisations-quetes.js) passe
-- desormais par football_pari_engager(), et les trois wrappers d'acces direct
-- (sbCreerPari, sbResoudrePari, sbGetParisJourneeNonResolus) n'ont plus aucun
-- appelant -- verifie.
--
-- La lecture est fermee elle aussi : aucun ecran n'affiche les paris, le seul
-- lecteur etait sbGetParisJourneeNonResolus, orpheline. La resolution se fait
-- dans football_paris_resoudre, SECURITY DEFINER, que la RLS ne concerne pas.
--
-- Les politiques existantes etaient en USING (true) / WITH CHECK (true) : les
-- laisser en place aurait rendu l'activation de la RLS purement decorative.
-- On les retire, puis RLS active SANS politique = ferme. Le REVOKE traite la
-- seconde couche, celle des GRANT, que les DEFAULT PRIVILEGES du schema public
-- reaccordent a anon sur chaque nouvel objet.

DROP POLICY IF EXISTS "Ecriture publique paris sportifs" ON public.paris_sportifs;
DROP POLICY IF EXISTS "Lecture publique paris sportifs"  ON public.paris_sportifs;
DROP POLICY IF EXISTS "Maj publique paris sportifs"      ON public.paris_sportifs;

ALTER TABLE public.paris_sportifs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.paris_sportifs FROM anon, authenticated, public;

-- Etat final constate en production le 20 septembre 2026 : relrowsecurity = true
-- et AUCUNE ligne dans pg_policies pour cette table. Toute ecriture legitime
-- passe par football_pari_engager (section 2) ou football_paris_resoudre.
