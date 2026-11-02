-- ORGANISATIONS, ÉTAPE B — référentiel des fondations (Claude, 02/11/2026). Additive.
-- Grades, confidentialité et prérequis RECOPIÉS de TYPES_ORGANISATIONS (data.js), pour les types
-- fondables dans un local loué (sportive et supporters exclus, TYPES_ORGA_EXCLUS_LOCAL_LOUE).
-- Le serveur ne lit pas data.js : test-organisations-vie-referentiel.mjs échoue si les deux divergent.
BEGIN;
CREATE OR REPLACE FUNCTION public.organisation_vie_referentiel() RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path = public, pg_temp AS $ref$
SELECT '{
 "politique":{"secret":false,"requis":{"pop":20,"inf":15},"grades":{"republic":["Sympathisant","Militant","Cadre","Secrétaire Général"],"narco":["Seguidor","Activista","Líder Local","Jefe Supremo"],"soviet":["Camarade","Activiste","Commissaire","Secrétaire du Parti"],"khalija":["Partisan","Conseiller","Vizir","Grand Vizir"]}},
 "religieuse":{"secret":false,"requis":{"inf":20,"pop":15},"grades":{"republic":["Novice","Diacre","Pretre","Grand Pontife"],"narco":["Croyant","Reverend","Archeveque","El Profeta"],"soviet":["Camarade Croyant","Lecteur du Parti","Prophete du Kolkhoze","Grand Oracle"],"khalija":["Etudiant","Imam","Grand Mufti","Ayatollah Supreme"]}},
 "syndicale":{"secret":false,"requis":{"inf":15,"pop":10},"grades":{"republic":["Adherent","Delegue","Secretaire Adjoint","Secretaire General"],"narco":["Adherent","Delegue","Secretaire Adjoint","Secretaire General"],"soviet":["Camarade","Delegue Ouvrier","Commissaire Syndical","Secretaire General"],"khalija":["Adherent","Delegue","Secretaire Adjoint","Secretaire General"]}},
 "economique":{"secret":false,"requis":{"inf":15,"arg":10000},"grades":{"republic":["Actionnaire","Directeur","PDG","President du Conseil"],"narco":["Investisseur","Gerant","Patron","El Patron Economico"],"soviet":["Cooperateur","Directeur de Plan","Commissaire Economique","Ministre de l''Abondance"],"khalija":["Associe","Directeur","Cheikh des Affaires","Sultan Economique"]}},
 "criminelle":{"secret":true,"requis":{"dis":60},"grades":{"republic":["Affilie","Soldat","Capo","Parrain"],"narco":["Sicario","Teniente","Comandante","El Jefe"],"soviet":["Homme de main","Brigadier","Vor","Pakhan"],"khalija":["Sbire","Lieutenant","Emir de l''ombre","Calife de l''obscurite"]}},
 "loge":{"secret":true,"requis":{"inf":25},"grades":{"republic":["Apprenti","Compagnon","Maitre","Grand Maitre"],"narco":["Iniciado","Hermano","Maestro","Gran Maestro"],"soviet":["Apprenti du Parti","Frere Collectif","Maitre Sovietique","Grand Architecte"],"khalija":["Murid","Ikhwan","Sheikh","Grand Sheikh"]}},
 "mediatique":{"secret":false,"requis":{"inf":30,"pop":10},"grades":{"republic":["Correspondant","Journaliste","Redacteur en chef","Directeur de Publication"],"narco":["Informateur","Reporter","Editeur","Patron des Medias"],"soviet":["Propagandiste","Redacteur","Chef de la Pravda","Commissaire a l''Information"],"khalija":["Conteur","Chroniqueur","Editorialiste","Grand Orateur du Sheikh"]}}
}'::jsonb
$ref$;
REVOKE ALL ON FUNCTION public.organisation_vie_referentiel() FROM PUBLIC, anon, authenticated;

COMMIT;
