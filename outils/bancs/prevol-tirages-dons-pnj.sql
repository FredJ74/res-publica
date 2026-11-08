-- Prévol en lecture seule, compte agrégé uniquement ; aucun nom ou solde de PJ en sortie.
-- À exécuter par l'intégrateur AVANT activation. Tous les compteurs doivent être 0.
WITH profils AS (SELECT key AS job,value::numeric AS dup FROM jsonb_each_text('{"serveur":4,"hotelier":5,"barman":5,"escort":8,"commissaire":6,"policier":4,"inspecteur":5,"militaire":3,"soldat":3,"garde":3,"general":5,"journaliste":6,"redacteur":6,"medecin":4,"infirmier":3,"avocat":7,"juge":5,"banquier":7,"commercant":6,"marchande":5,"professeur":4,"syndicaliste":5,"loge":8,"venerable":8,"grand_pretre":6,"douanier":6,"docker":3,"portier":3,"secretaire":5,"lobbyiste":8,"hotesse":5,"default":4}'::jsonb)),
miroirs AS (
 SELECT d.name,coalesce(d.employes,'[]') AS employes,
  CASE WHEN jsonb_typeof(d.employes)='array' THEN d.employes ELSE '[]'::jsonb END AS liste
 FROM public.personnages_donnees d
), ensembles AS (
 SELECT d.name,
  (SELECT coalesce(jsonb_agg(e->>'pnjId' ORDER BY e->>'pnjId'),'[]') FROM jsonb_array_elements(d.liste)e WHERE e->'inGroupe'='true'::jsonb) AS miroir,
  (SELECT coalesce(jsonb_agg(m.id ORDER BY m.id),'[]') FROM public.pnj_membres m JOIN public.pnj_employes_metier em ON em.pnj_id=m.id
    WHERE m.proprietaire_pj=d.name AND m.leader_pj=d.name AND m.statut='actif') AS socle
 FROM miroirs d
), valeurs AS (
 SELECT CASE WHEN jsonb_typeof(e->'stats'->'DUP')='number' THEN (e->'stats'->>'DUP')::numeric ELSE p.dup END AS ancien,
   m.car_dup AS canonique
 FROM miroirs d CROSS JOIN LATERAL jsonb_array_elements(d.liste)e
 LEFT JOIN profils p ON p.job=e->>'job'
 LEFT JOIN public.pnj_membres m ON m.id=e->>'pnjId' AND m.proprietaire_pj=d.name AND m.leader_pj=d.name AND m.statut='actif'
 WHERE e->'inGroupe'='true'::jsonb
)
SELECT jsonb_build_object(
 'miroirs_non_tableaux',(SELECT count(*)FROM miroirs WHERE jsonb_typeof(employes)IS DISTINCT FROM 'array'),
 'groupes_non_reconcilies',(SELECT count(*)FROM ensembles WHERE miroir IS DISTINCT FROM socle),
 'caracteristiques_non_reconciliees',(SELECT count(*)FROM valeurs WHERE ancien IS DISTINCT FROM canonique),
 'flags_groupe_non_booleens',(SELECT count(*)FROM miroirs d CROSS JOIN LATERAL jsonb_array_elements(d.liste)e WHERE e ? 'inGroupe'AND jsonb_typeof(e->'inGroupe')NOT IN('boolean','null')),
 'dispatcher_present',to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)')IS NOT NULL,
 'empreinte_dispatcher',md5(pg_get_functiondef(to_regprocedure('public.jauges_ordre_executer(text,uuid,jsonb)'))),
 'projection_employes_presente',to_regprocedure('public.employe_mes_employes()')IS NOT NULL
);
