-- =============================================================================================
-- NOTIFICATION DES RAPPORTS DE CELLULE : DIRE OU LE RAPPORT SE TROUVE (24 septembre 2026)
-- =============================================================================================
-- CE QUI EST CORRIGE, ET RIEN D'AUTRE : le texte du courrier.
--
-- L'ancien message annoncait le rapport « dans votre panneau ». Aucun ecran, aucun bouton, aucun
-- onglet du jeu ne porte ce nom : le mot n'existe que dans les commentaires du code et dans des
-- noms de fonctions. Le ministre recevait donc une notification qui ne designait rien, et le
-- rapport -- parfaitement lisible, a trois niveaux de profondeur -- restait introuvable. Constate
-- en production le 24 septembre 2026 : un ministre a cherche dans le journal d'evenements.
--
-- Le message nomme desormais le chemin REEL, verifie ecran par ecran :
--   Bureau du Ministre de la Defense -> « Renseignement militaire » -> « Lire les rapports ».
-- L'entree « Lire les rapports » est ajoutee au meme lot, cote client.
--
-- ACCORD EN NOMBRE. « X fait(s) consigne(s) » devient « 0 fait consigne », « 1 fait consigne »,
-- « 2 faits consignes ». Le pluriel est calcule, plus suggere entre parentheses.
--
-- CE QUI NE CHANGE PAS, ET C'EST L'ESSENTIEL : la selection des cellules actives, la garde
-- anti-rejeu sur (cellule_id, jour), l'agregation des faits depuis renseignements_connus, le
-- contenu ecrit dans rapports_cellules, sa structure, et le fait que le courrier reste une
-- NOTIFICATION -- il ne porte toujours aucun renseignement. Aucun rapport deja genere n'est
-- touche : cette fonction n'ecrit que pour un jour qui n'a pas encore le sien.
-- =============================================================================================

CREATE OR REPLACE FUNCTION public.cellules_rapports_generer()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  c record; v_jour date := (now() AT TIME ZONE 'Europe/Paris')::date;
  v_faits jsonb; v_n integer := 0; v_nb integer;
BEGIN
  FOR c IN SELECT id, pays_proprietaire, pays_cible
             FROM public.cellules_renseignement WHERE statut = 'active'
  LOOP
    CONTINUE WHEN EXISTS (SELECT 1 FROM public.rapports_cellules rc
                           WHERE rc.cellule_id = c.id AND rc.jour = v_jour);

    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'categorie', r.categorie, 'fait', r.contenu, 'source', r.source)
             ORDER BY r.categorie, r.created_at), '[]'::jsonb)
      INTO v_faits
      FROM public.renseignements_connus r
     WHERE r.titulaire = 'cellule:' || c.id
       AND (r.created_at AT TIME ZONE 'Europe/Paris')::date = v_jour;

    INSERT INTO public.rapports_cellules (cellule_id, jour, contenu, nb_faits)
    VALUES (c.id, v_jour,
            jsonb_build_object('cellule', c.id, 'pays_cible', c.pays_cible,
                               'jour', v_jour, 'faits', v_faits),
            jsonb_array_length(v_faits))
    ON CONFLICT (cellule_id, jour) DO NOTHING;

    -- Le nombre est lu UNE fois et sert a la fois au chiffre et a l'accord.
    v_nb := jsonb_array_length(v_faits);

    PERFORM public.cellule_alerter_ministre(c.id, NULL,
      'Rapport de renseignement du ' || to_char(v_jour, 'DD/MM/YYYY'),
      'Le rapport quotidien de votre cellule ' || c.id ||
      ' est disponible dans votre Bureau du Ministre de la Défense, rubrique ' ||
      '« Renseignement militaire » → « Lire les rapports ». ' ||
      v_nb || CASE WHEN v_nb > 1 THEN ' faits consignés.' ELSE ' fait consigné.' END);
    v_n := v_n + 1;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'rapports', v_n);
END;
$function$;
