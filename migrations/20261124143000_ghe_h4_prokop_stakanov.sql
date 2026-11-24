-- APPLIQUÉE en production le 24/11/2026 (contrôlée en lecture) — l'agent principal l'applique à la fusion (mission « Purge », 24/11/2026).
-- Point H.4 (Fred, 24/11/2026) : l'habitué du Bar Sever (Krasnov) s'appelle Prokop Stakanov ; 3 h entre deux visites,
-- un verre par jour. L'identifiant technique « habitue_krasnov » ne change pas (informateur, relation sociale, verres
-- offerts, réglages MJ, RPC habitue_krasnov_accueillir) : seuls le nom affiché du référentiel des informateurs et les
-- libellés MJ changent. Les deux réglages valent déjà 3 h et 1 verre (migration 20261123211000, en production) : ils
-- sont remis à ces valeurs seulement s'ils manquent. Rejouable ; aucune donnée de joueur touchée ; rien du goulag.
BEGIN;
UPDATE public.informateurs_pnj SET nom = 'Prokop Stakanov'
 WHERE id = 'habitue_krasnov' AND nom = 'L’habitué du Bar Sever';

INSERT INTO public.sante_parametres (cle, valeur, groupe, libelle) VALUES
  ('habitue_krasnov_verres_par_jour', 1, 'pnj', 'Verres offerts par Prokop Stakanov, l’habitué du Bar Sever (Krasnov), par PJ et par jour (0 = aucun)'),
  ('habitue_krasnov_accueil_heures', 3, 'pnj', 'Heures avant que Prokop Stakanov, l’habitué du Bar Sever, accueille de nouveau le même PJ')
ON CONFLICT (cle) DO NOTHING;
UPDATE public.sante_parametres SET libelle = 'Verres offerts par Prokop Stakanov, l’habitué du Bar Sever (Krasnov), par PJ et par jour (0 = aucun)'
 WHERE cle = 'habitue_krasnov_verres_par_jour' AND libelle = 'Verres offerts par l’habitué du Bar Sever (Krasnov), par PJ et par jour (0 = aucun)';
UPDATE public.sante_parametres SET libelle = 'Heures avant que Prokop Stakanov, l’habitué du Bar Sever, accueille de nouveau le même PJ'
 WHERE cle = 'habitue_krasnov_accueil_heures' AND libelle = 'Heures avant que l’habitué du Bar Sever accueille de nouveau le même PJ';

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.informateurs_pnj WHERE id = 'habitue_krasnov' AND nom <> 'Prokop Stakanov')
     OR (SELECT count(*) FROM public.sante_parametres WHERE cle IN ('habitue_krasnov_verres_par_jour', 'habitue_krasnov_accueil_heures')) <> 2 THEN
    RAISE EXCEPTION 'ghe_h4_prokop_stakanov : contrôle structurel en échec';
  END IF;
END $$;
COMMIT;
