-- Commentaires d'objets
-- ============================================================================
-- BASELINE Human Gambit -- domaine justice -- phase 80 : commentaires
--
-- Fichier GENERE par outils/baseline/rendre.py depuis les catalogues
-- PostgreSQL. Ne pas editer a la main : toute correction passe par une
-- migration, puis par une nouvelle extraction.
--
-- ORDRE D'APPLICATION : par PHASE croissante, tous domaines confondus, et non
-- domaine par domaine. Voir baseline/README.md.
-- ============================================================================

COMMENT ON COLUMN public.detentions.provenance IS 'NULL = detention d''un PJ (comportement historique). Sinon, systeme PNJ proprietaire de l''etat de la cible, ex. agent_renseignement.';
COMMENT ON FUNCTION public.detention_clore_evasion() IS 'Clot SA PROPRE detention par evasion : mode_fin = evasion, est_emprisonne vide, drapeau QHS
abaisse et ligne du registre du QHS liberee -- en une transaction. jour_fin n''est JAMAIS reecrit :
une evasion n''est pas une liberation. Rend les motifs d''origine, le pays et le reliquat, pour que
l''appelant construise l''avis de recherche. Verdicts : acteur_non_authentifie, non_detenu, puis ok.';
COMMENT ON FUNCTION public.detention_clore_purgee() IS 'Clot SA PROPRE peine quand elle est purgee : mode_fin = purgee, est_emprisonne vide, drapeau QHS
abaisse en OBJET et ligne du registre du QHS passee a libere -- en une transaction. Le jour de
reference vient de la fiche, jamais de l''appelant. Idempotente : rejouee, elle rend non_detenu.
Verdicts : acteur_non_authentifie, non_detenu, peine_non_purgee, puis ok.';
COMMENT ON FUNCTION public.detention_ouvrir_interne(text,text,integer,text,text,jsonb,text,text,jsonb) IS 'PRIMITIVE d''incarceration : ouvre la ligne detentions et pose est_emprisonne dans la meme
transaction, refuse une cible deja detenue, et sait arreter un PNJ comme un PJ. AUCUN controle
d''autorite -- c''est le role de ses portes (justice_executer_condamnation, arrestation_urgence,
enquete_garde_a_vue, fraude_electorale_sanctionner, plainte_instruire_interne,
militaire_bataille_appliquer, detention_ouvrir_soi). p_extras porte les metadonnees judiciaires
optionnelles : ville_condamnation, jour_affaire, detention_precedente_id, reliquat_jours,
retour_ville. Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.detention_ouvrir_soi(text,integer,text,jsonb,boolean,jsonb) IS 'S''incarcerer SOI-MEME : flagrant delit sur soi, placement au QHS, rebellion matee, sentence,
tracts calomnieux. L''identite, le pays et le jour viennent du serveur, jamais de l''appelant.
Verdicts : acteur_non_authentifie, duree_invalide, cible_deja_detenue, puis ok avec detention_id,
jour_debut et jour_fin.';
COMMENT ON FUNCTION public.detention_prolonger_interne(text,jsonb,boolean) IS 'MOTEUR de prolongation de peine : concatene les motifs sous verrou, repousse jour_fin, aligne
est_emprisonne, et pose le drapeau QHS si demande. N''a AUCUN controle d''autorite -- c''est le
role de ses portes : justice_prolonger_peine (un juge, sur un tiers) et detention_prolonger_soi
(le detenu, sur lui-meme). Non appelable depuis le reseau.';
COMMENT ON FUNCTION public.detention_prolonger_soi(jsonb,boolean) IS 'Prolonge SA PROPRE peine : rebellion en cellule, placement au QHS. L''identite vient de
mon_personnage(), jamais d''un parametre. Verdicts : acteur_non_authentifie, motifs_absents,
cible_non_detenue, puis ok avec jours_ajoutes et jour_fin.';
COMMENT ON FUNCTION public.detention_qhs_poser_interne(text,text,text) IS 'SEUL ECRIVAIN du caractere QHS au moment de l''acte : pose detentions.qhs, est_emprisonne.qhs et
detention_qhs -- ce dernier en OBJET et non en chaine, forme que pa_repos_nocturne exige pour
appliquer le plafond de PA -- puis inscrit au registre du QHS une seule fois. Non appelable
depuis le reseau.';
COMMENT ON FUNCTION public.detention_reduire_peine(boolean) IS 'Applique la requete de l''avocat sur SA PROPRE peine, en une transaction : consomme l''avocat
(dans les deux cas, requete acceptee ou refusee), et si elle est acceptee reduit la peine de la
moitie du reliquat arrondie au superieur, en cloturant par anticipee_avocat si le terme est
atteint. Le MONTANT de la reduction est calcule ici, pas recu ; seul le resultat de la plaidoirie
vient de l''appelant, parce qu''il depend de valeurs qui vivent dans l''etat client. Verdicts :
acteur_non_authentifie, non_detenu, avocat_deja_utilise, peine_sans_terme, puis ok.';
COMMENT ON FUNCTION public.detention_transferer_qhs(text,integer,text,jsonb) IS 'Bascule SA PROPRE detention en cours vers le quartier de haute securite : clot l''ancienne ligne
par transfert_qhs, en ouvre une nouvelle qui la cite via detention_precedente_id, et pose le
drapeau QHS -- en une transaction. N''est PAS idempotente a dessein : un second appel est une
seconde rebellion, que le jeu permet. L''invariant tenu est qu''exactement une peine reste en
cours. Verdicts : acteur_non_authentifie, duree_invalide, non_detenu, puis ok.';
COMMENT ON FUNCTION public.justice_rendre_sentence(jsonb,text) IS 'Archive un jugement et clot son affaire en une transaction, sous affaire_autorite_de(ville) :
juge ou commissaire de la ville de l''affaire. Le magistrat et le jour viennent du serveur, jamais
de l''appelant. Une affaire ne se juge qu''une fois (verdict affaire_deja_jugee), et l''identifiant
du jugement est derive de celui de l''affaire. Verdicts : acteur_non_authentifie, affaire_invalide,
autorite_refusee, affaire_absente, affaire_deja_jugee, puis ok avec jugement_id.';
