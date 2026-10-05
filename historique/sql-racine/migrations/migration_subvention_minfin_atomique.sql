-- SUBVENTION DU MINISTRE DES FINANCES : UNE SEULE TRANSACTION (16 septembre 2026).
-- DEJA EXECUTEE en production (migration MCP : subvention_ministerielle_transaction_atomique).
--
-- LE DEFAUT
-- ---------
-- La subvention se faisait en deux temps, cote navigateur :
--   1. debiterCaisseBatimentPlafonne() retire l'argent de la caisse du gouvernement -- et cela
--      fonctionne, c'est une RPC serveur ;
--   2. le beneficiaire est credite par une ecriture directe sur SA fiche.
-- Depuis le chantier B, la vue personnages refuse d'ecrire la fiche d'autrui
-- (personnage_non_possede), et l'appel etait avale par un .catch() muet. L'argent public
-- quittait donc la caisse sans jamais arriver au beneficiaire.
--
-- UN SECOND DEFAUT, plus discret, se cachait dans le meme chemin. Le montant credite etait
-- calcule comme « solde relu + montant » (ajusterSoldeCibleFiscale). Or la fortune d'autrui
-- n'est pas lisible non plus depuis le chantier B : la relecture renvoyait 0. Si l'ecriture
-- etait passee, elle aurait REMIS LA FORTUNE DU BENEFICIAIRE au montant de la subvention au
-- lieu de l'augmenter. Le refus RLS nous a protege d'une destruction de donnees. La nouvelle
-- primitive INCREMENTE : elle ne relit plus pour reecrire.
--
-- LA REGLE, retrouvee dans le code et NON MODIFIEE
-- ------------------------------------------------
--   * autorite : poste min_fin (ordre « Accorder une subvention », data.js, pa:2 cost:0) ;
--   * caisse   : <pays>_gouvernement-min_fin ;
--   * montant  : libre, choisi par le ministre, plafond 5000 (formulaire) ;
--   * versement PARTIEL tolere si la caisse ne suit pas -- comportement volontaire et ancien ;
--   * 2 PA a la charge du ministre, debites par le client AVANT l'appel, inchange ;
--   * aucun cooldown n'existe dans la mecanique : ce lot n'en invente pas ;
--   * effets annexes conserves cote client : +3 IS sur la ville, mail, journal, evenement
--     public et chronique nationale (tracabilite du Lot 4.3).
--
-- CE QUE LE SERVEUR ATTESTE : l'identite de l'acteur et son poste min_fin REEL (exiger_poste lit
-- le poste atteste de la fiche, lui-meme verrouille par le chantier « autorite des postes »), le
-- pays, la caisse competente, l'existence du beneficiaire et le montant. L'appelant ne designe
-- qu'un beneficiaire et un montant demande : il ne choisit ni la caisse, ni ce qui sort vraiment.
--
-- ATOMICITE : debit et credit vivent dans la meme fonction, donc la meme transaction. Les deux
-- lignes sont verrouillees (FOR UPDATE) avant tout mouvement. Soit les deux, soit aucun.
--
-- PERIMETRE : uniquement le beneficiaire de type CITOYEN, le seul casse. Club, entreprise et
-- organisation gardent leur chemin, qui fonctionne. caisse_institution_mouvement n'est pas
-- refondue -- sa logique de plafonnement est simplement reprise a l'identique ici, pour que le
-- debit et le credit tiennent dans une seule transaction.

CREATE OR REPLACE FUNCTION public.subvention_citoyen_verser(p_beneficiaire text, p_montant integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_acteur text; v_pays text; v_caisse text; v_data jsonb;
  v_solde numeric; v_verse numeric; v_arg numeric;
BEGIN
  -- 1. AUTORITE. exiger_poste leve si le compte n'a pas de personnage ou n'est pas min_fin.
  v_acteur := public.exiger_poste('min_fin');
  IF v_acteur IS NULL THEN            -- appel serveur (cron) : pas de subvention automatique
    RETURN jsonb_build_object('ok', false, 'raison', 'acteur_non_authentifie');
  END IF;

  SELECT country INTO v_pays FROM public.personnages_donnees WHERE name = v_acteur;
  IF coalesce(v_pays, '') = '' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pays_indetermine');
  END IF;

  -- 2. MONTANT. Memes bornes que le formulaire : au moins 1, au plus 5000.
  IF p_montant IS NULL OR p_montant < 1 OR p_montant > 5000 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'montant_invalide');
  END IF;

  -- 3. BENEFICIAIRE. Il doit exister. La ligne est verrouillee avant tout mouvement.
  SELECT coalesce(arg, 0) INTO v_arg
    FROM public.personnages_donnees WHERE name = p_beneficiaire FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'beneficiaire_introuvable');
  END IF;

  -- 4. CAISSE. Verrouillee elle aussi : le solde lu est celui qu'on debite.
  v_caisse := v_pays || '_gouvernement-min_fin';
  SELECT data INTO v_data FROM public.caisses_batiments WHERE id = v_caisse FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0);
  END IF;
  v_solde := CASE WHEN jsonb_typeof(v_data->'solde') = 'number'
                  THEN (v_data->>'solde')::numeric ELSE 0 END;
  v_verse := least(greatest(v_solde, 0), p_montant);   -- versement partiel tolere, comme avant
  IF v_verse <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'caisse_insuffisante', 'verse', 0);
  END IF;

  -- 5. LES DEUX MOUVEMENTS, ENSEMBLE.
  UPDATE public.caisses_batiments
     SET data = coalesce(v_data, '{}'::jsonb) || jsonb_build_object('solde', v_solde - v_verse),
         updated_at = now()
   WHERE id = v_caisse;

  -- INCREMENT, jamais « solde relu + montant » : c'est ce calcul qui aurait ecrase la fortune.
  UPDATE public.personnages_donnees
     SET arg = coalesce(arg, 0) + v_verse
   WHERE name = p_beneficiaire;

  RETURN jsonb_build_object('ok', true, 'verse', v_verse, 'beneficiaire', p_beneficiaire,
                            'acteur', v_acteur, 'caisse', v_caisse);
END; $$;

REVOKE ALL ON FUNCTION public.subvention_citoyen_verser(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.subvention_citoyen_verser(text, integer) TO authenticated;

-- HISTORIQUE : AUCUNE REGULARISATION. La mecanique ecrit systematiquement deux traces publiques
-- (evenement partage et chronique nationale). Or chronique_nationale est VIDE et aucun des
-- evenements globaux ne concerne une subvention : aucune subvention n'a ete accordee depuis le
-- reset de la beta. Le poste min_fin est d'ailleurs tenu par un PNJ. Rien a rattraper -- et rien
-- n'a ete credite par approximation.
--
-- Banc : .scratch/banc_subvention_minfin.py (29 controles, pays de test 'zztest', la caisse de
-- la Republique n'est jamais sollicitee).
