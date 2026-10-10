-- =============================================================================
-- ARCHIVE -- MIGRATION APPLIQUEE LE 10 OCTOBRE 2026
--
-- Registre Supabase : version 20261010075352 (UTC), nom `tournee_la_cloture_et_ses_credits_sont_un_seul_acte`.
-- Le registre passe de 594 a 595 entrees.
--
-- CORPS EXACT ENREGISTRE : md5 07f541aa61b134edfb2be1ecec397203, 5168 caracteres, 1 instruction au
-- registre. Relu depuis le registre, empreinte verifiee avant archivage.
--
-- CLOTURE D'UNE TOURNEE : LE CREDIT DES INVITES ARRIVE ENFIN
--
-- UN FAIT MESURE CHANGE LE DIAGNOSTIC. `crediterTourneeInviteAcceptant` creditait +2 Moral et
+1 ENT par un sbUpdate client sur la fiche de L'AUTRE joueur, avec un catch avale. Mesure faite
en base : un tel UPDATE ne rend pas « 0 ligne », il LEVE `personnage_non_possede` (42501) depuis
le trigger `personnages_vue_modifier`. Depuis le chantier B, AUCUN invite n'a recu le gain que le
jeu lui annonce. La regle etait ecrite dans le code et dans le toast ; elle est enfin appliquee,
plafonds compris (moral 100, ENT 20). `tournee_cloturer(tournee, servie)` porte aussi le
nettoyage des invitations et un COMPARE-AND-SWAP sur `statut` : la reprise a 30 s ne peut plus
revendre la tournee entiere. Fenetre residuelle consignee : la vente elle-meme reste en amont.
--
-- ELLE VA PAR PAIRE AVEC : `plateau-actions-illegales-rumeurs.js` (`resoudreTournee`, suppression de
-- `crediterTourneeInviteAcceptant` et de `nettoyerInvitations`) et `supabase.js` (suppression de
-- `sbMarquerTourneeResolue` et `sbMarquerTourneePaDebite`, deux chemins de cloture sans verrou).
-- =============================================================================

-- >>> DEBUT DU SQL HISTORIQUE -- ne rien inserer au-dessus de cette ligne <<<
-- CHANTIER 5, CHAINE 6 -- LA CLOTURE D'UNE TOURNEE (10 octobre 2026)
--
-- UN FAIT MESURE D'ABORD, ET IL CHANGE LE DIAGNOSTIC. crediterTourneeInviteAcceptant
-- (plateau-actions-illegales-rumeurs.js) creditait +2 Moral et +1 ENT a chaque invite ayant
-- accepte, par un sbUpdate client sur la fiche de L'AUTRE JOUEUR, avec .catch(() => {}). Mesure
-- faite en base ce jour : un tel UPDATE ne rend pas « 0 ligne », il LEVE
-- « personnage_non_possede » (ERRCODE 42501) depuis le trigger personnages_vue_modifier de la vue
-- public.personnages -- la politique RLS personnages_maj_soi reserve l'UPDATE a
-- user_id = auth.uid(). Le catch avalait donc cette exception a chaque fois : AUCUN invite n'a
-- jamais recu le gain que le jeu lui annonce depuis le lot du 20 aout 2026.
--
-- La regle n'est pas inventee ici : elle est ecrite dans la documentation de ce lot (« section
-- 13 »), dans le toast affiche a l'offreur et dans la ligne de Journal. Elle etait CONCUE et
-- SILENCIEUSEMENT EMPECHEE par la plateforme. Bornes conservees : moral plafonne a 100, ENT
-- plafonne a 20, et la limite « une fois par jour » de appliquerGainENT reste volontairement NON
-- appliquee, pour la raison deja consignee cote JS (dernierGainENTJour n'est jamais persiste).
--
-- LES DEUX AUTRES DEFAUTS DE LA CHAINE 6.
--   . sbSupprimerInvitationDiner etait avale ligne par ligne : une invitation survivante
--     reapparaissait chez l'invite comme une tournee encore en attente.
--   . sbMarquerTourneeResolue etait attendu mais son retour n'etait jamais lu. S'il echouait, la
--     ligne restait en 'en_resolution' ; trente secondes plus tard le polling la RECLAMAIT et
--     resoudreTournee RECOMMENCAIT TOUT -- vente, PA, stock, caisse. Le compare-and-swap sur
--     statut rend ce rejeu impossible.
--
-- CE QUI RESTE EN DEHORS, ET POURQUOI. La vente (argent, PA, stock, caisse, taxe) est deja UNE
-- transaction serveur depuis le chantier C phase 3 : commerce_vendre_produit. Elle n'est pas
-- absorbee ici parce que l'identifiant de l'entreprise est resolu cote client par chargerCommerce,
-- et le deriver en SQL demanderait d'inventer une regle de nommage -- ce que ce projet s'interdit.
-- Fenetre residuelle consignee : vente aboutie, puis navigateur perdu AVANT cette porte ; la ligne
-- reste 'en_resolution' et la reprise a 30 s revendra. Elle existait identiquement avant ce lot.

CREATE OR REPLACE FUNCTION public.tournee_cloturer(p_tournee_id text, p_servie boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  t public.tournees; v_moi text; v_credites integer := 0; v_supprimees integer := 0;
  v_n integer; r record;
BEGIN
  SELECT * INTO t FROM public.tournees WHERE id = p_tournee_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'raison', 'tournee_introuvable'); END IF;

  -- SEUL L'OFFREUR CLOT SA TOURNEE (le serveur traverse : mon_personnage() rend NULL pour lui).
  v_moi := public.mon_personnage();
  IF v_moi IS NOT NULL AND v_moi IS DISTINCT FROM t.offreur THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_mon_offre');
  END IF;

  -- LE COMPARE-AND-SWAP : seule une tournee revendiquee se clot, et une seule fois.
  IF t.statut <> 'en_resolution' THEN
    RETURN jsonb_build_object('ok', false, 'raison', 'pas_en_resolution', 'statut', t.statut);
  END IF;

  IF coalesce(p_servie, false) THEN
    -- LE CREDIT DES INVITES, ENFIN APPLIQUE -- et dans la meme transaction que la cloture.
    -- Il vise la TABLE, pas la vue : c'est la vue qui refusait la fiche d'autrui.
    FOR r IN SELECT i.invite FROM public.invitations_diner i
              WHERE i.tournee_id = p_tournee_id AND i.statut = 'acceptee'
    LOOP
      UPDATE public.personnages_donnees d
         SET moral = least(100, coalesce(d.moral, 75) + 2),
             stats = CASE
               WHEN coalesce((d.stats ->> 'ENT')::numeric, 0) < 20
                 THEN jsonb_set(coalesce(d.stats, '{}'::jsonb), '{ENT}',
                        to_jsonb(least(20, coalesce((d.stats ->> 'ENT')::numeric, 0) + 1)), true)
               ELSE coalesce(d.stats, '{}'::jsonb) END
       WHERE d.name = r.invite;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_credites := v_credites + v_n;
    END LOOP;
  END IF;

  DELETE FROM public.invitations_diner WHERE tournee_id = p_tournee_id;
  GET DIAGNOSTICS v_supprimees = ROW_COUNT;

  UPDATE public.tournees
     SET statut = 'resolue',
         pa_debite = CASE WHEN coalesce(p_servie,false) THEN true ELSE coalesce(pa_debite,false) END
   WHERE id = p_tournee_id AND statut = 'en_resolution';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'tournee_cloturer : la cloture n''a pas pris sur %', p_tournee_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'servie', coalesce(p_servie,false),
    'credites', v_credites, 'invitations_supprimees', v_supprimees);
END; $fn$;

REVOKE ALL ON FUNCTION public.tournee_cloturer(text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tournee_cloturer(text, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.tournee_cloturer(text, boolean) TO authenticated, service_role;