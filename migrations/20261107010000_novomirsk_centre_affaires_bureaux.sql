-- CENTRE D'AFFAIRES DE NOVOMIRSK : BUREAUX ATTRIBUES PAR LA MAIRIE (Claude, 07/11/2026, decision de Fred)
--
-- Fred : les deux bureaux prestige se louent selon le schema des locaux commerciaux de Sovarka
-- (« Demande de location » -> dossiers du maire -> signature chez le notaire), comme aux Galeries.
-- Loyer 150 PSK/jour (plafond 150). On peut y installer le siege d'une association et du materiel
-- (bail ordinaire de locations_actives : « Gerer mon local », equipements).
-- Les salles de reunion restent en location a la journee, sans passer par le maire.
-- Le guichet « Louer ce local » est ferme d'office : local_louer refuse tout local de sovarka_locaux.

INSERT INTO public.sovarka_locaux (pays, ville, batiment, piece, label, origine, plafond, loyer)
VALUES ('soviet', 'capitale', 'centre-affaires', 'bureau_prestige',   'Bureau prestige A', 'centre', 150, 150),
       ('soviet', 'capitale', 'centre-affaires', 'bureau_prestige_b', 'Bureau prestige B', 'centre', 150, 150)
ON CONFLICT DO NOTHING;

-- Libelle du batiment dans le bail signe chez le notaire (sinon « Immeuble collectif »).
DO $migration$
DECLARE
  d text := pg_get_functiondef('public.sovarka_attribution_signer(text)'::regprocedure);
  ancre text := $a$WHEN 'centre-artisanal' THEN 'Centre artisanal'$a$;
BEGIN
  IF strpos(d, $b$WHEN 'centre-affaires'$b$) > 0 THEN RETURN; END IF;
  IF strpos(d, ancre) = 0 THEN RAISE EXCEPTION 'sovarka_attribution_signer : ancre introuvable'; END IF;
  EXECUTE replace(d, ancre, ancre || $c$ WHEN 'centre-affaires' THEN 'Centre d''affaires'$c$);
END
$migration$;

DO $verif$
BEGIN
  IF (SELECT count(*) FROM public.sovarka_locaux WHERE pays = 'soviet' AND ville = 'capitale'
        AND batiment = 'centre-affaires' AND plafond = 150) <> 2 THEN
    RAISE EXCEPTION 'bureaux du centre d''affaires non declares';
  END IF;
END
$verif$;
