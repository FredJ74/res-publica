-- CENTRES D'AFFAIRES DE STAROVKA ET KRASNOV : BUREAUX ATTRIBUES PAR LA MAIRIE (Claude, 09/11/2026)
--
-- Regles deja decidees par Fred, appliquees aux deux villes de province :
--  * en Sovarka la propriete privee n'existe pas : un local s'obtient par demande a la mairie,
--    attribution du maire, signature chez le notaire (06/11/2026) ;
--  * les bureaux du centre d'affaires suivent ce schema (07/11/2026, Novomirsk) ;
--  * hors Novomirsk, le plafond de loyer va jusqu'a 100 PSK pour le plus grand local (06/11/2026).
-- Jusqu'ici, a Starovka et Krasnov, les trois bureaux restaient en location privee au guichet
-- (« Louer ce local », 1000 / 500 / 200 par jour), en contradiction avec ces regles.
-- Plafonds : meme regle provisoire que les centres (proportionnels au loyer de Republia, le plus
-- grand a 100) : prestige 100, standard 50, open space 20. Loyer de depart 0 tant que le maire
-- ne l'a pas fixe. Valeurs a valider par Fred.
-- Aucun bail actif dans ces bureaux au 09/11/2026 (verifie avant ecriture).
-- local_louer refuse deja tout local de sovarka_locaux (attribution_municipale) ;
-- sovarka_attribution_signer connait deja le libelle « Centre d'affaires ».

INSERT INTO public.sovarka_locaux (pays, ville, batiment, piece, label, origine, plafond, loyer)
VALUES ('soviet', 'ville_a', 'centre-affaires', 'bureau_prestige', 'Bureau prestige', 'centre', 100, 0),
       ('soviet', 'ville_a', 'centre-affaires', 'bureau_standard', 'Bureau standard', 'centre',  50, 0),
       ('soviet', 'ville_a', 'centre-affaires', 'open_space',      'Open space',      'centre',  20, 0),
       ('soviet', 'ville_b', 'centre-affaires', 'bureau_prestige', 'Bureau prestige', 'centre', 100, 0),
       ('soviet', 'ville_b', 'centre-affaires', 'bureau_standard', 'Bureau standard', 'centre',  50, 0),
       ('soviet', 'ville_b', 'centre-affaires', 'open_space',      'Open space',      'centre',  20, 0)
ON CONFLICT DO NOTHING;

DO $verif$
BEGIN
  IF (SELECT count(*) FROM public.sovarka_locaux WHERE pays = 'soviet' AND ville IN ('ville_a', 'ville_b')
        AND batiment = 'centre-affaires') <> 6 THEN
    RAISE EXCEPTION 'bureaux des centres d''affaires de province non declares';
  END IF;
  IF position('attribution_municipale' IN pg_get_functiondef('public.local_louer(uuid, text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'local_louer ne refuse pas les locaux municipaux';
  END IF;
  IF position($c$'centre-affaires'$c$ IN pg_get_functiondef('public.sovarka_attribution_signer(text)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'sovarka_attribution_signer ne connait pas le centre d''affaires';
  END IF;
END
$verif$;
