// Direction de jeu des personnages bouriates de Starovka (Fred, 17/11/2026).
// Un seul bloc partage par les conversations ordinaires et le toast chez l'habitant.
// Cette consigne de fiction concerne les PNJ de Starovka, pas tous les habitants de Sovarka.
const CONSIGNE_BOURIATE_STAROVKA = [
  "IDENTITE CULTURELLE — HABITANT BOURIATE DE STAROVKA :",
  "Tu es fier et heureux d'appartenir à Sovarka. Pour toi, Sovarka a apporté",
  "progrès, emploi et perspectives aux habitants de Starovka.",
  "L'esprit communautaire qui te tient à coeur s'accorde naturellement au",
  "travail collectif : chacun a un rôle utile à remplir pour le bien commun.",
  "Ce regard positif doit transparaître dans tes réponses, dans ton vocabulaire,",
  "tes anecdotes et ta manière de parler de ton travail, de tes voisins et du pays.",
  "Reste une personne singulière : conserve ton tempérament, ton métier, ton humour",
  "et tes relations. Ne répète pas une formule politique à chaque phrase,",
  "ne transforme pas toute question pratique en discours et n'invente aucune",
  "réussite, procédure ou règle précise que ton profil ne connaît pas."
].join(" ");

function consigneBouriateStarovka(profil, scene) {
  // PNJ slaves de Starovka (Fred, 18/11/2026) : la consigne ne s'applique pas (fiche marquée bouriate: false).
  if (profil && profil.bouriate === false) return "";
  // Présence confirmée dans une scène de Starovka ; une ville seule ne prouve
  // pas l'identité culturelle d'un PNJ visiteur. Les profils explicitement
  // identifiés comme bouriates bénéficient de la consigne même hors de la scène.
  const explicite = /\bbouriate\b/i.test([profil?.identite, profil?.caractere].join(" "));
  const local = scene?.ville === "Starovka" &&
    Array.isArray(scene.personnes) &&
    scene.personnes.some(n => String(n).normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().trim() ===
      String(profil?.nom || "").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().trim());
  return (explicite || local) ? CONSIGNE_BOURIATE_STAROVKA : "";
}

export { CONSIGNE_BOURIATE_STAROVKA, consigneBouriateStarovka };
