// Lectures canoniques partagees par l'affichage et le dialogue serveur.
// Aucune presence dans une piece, aucun role du client ne vaut nomination.
export const PROFILS_MUNICIPAUX_LUTHECIA = {
  le_maire_de_luthecia: {
    poste: 'maire', nom: 'Le Maire de Luthecia',
    rolePnj: 'Maire de Luthécia', rolePj: 'Secrétaire général de la mairie'
  },
  le_maire_adjoint_de_luthecia: {
    poste: 'maire_adjoint', nom: 'Le Maire Adjoint de Luthecia',
    rolePnj: 'Maire adjoint de Luthécia', rolePj: 'Secrétaire du maire adjoint'
  }
};

// `lire` doit distinguer un tableau vide d'une lecture refusee/inaccessible.
export async function lireTitulaireMunicipal(poste, pays, ville, lire) {
  if (!['maire', 'maire_adjoint'].includes(poste) || !pays || !ville) {
    throw new Error('Poste municipal ou territoire invalide');
  }
  const q = v => encodeURIComponent(v);
  async function unique(table, filtre) {
    const rows = await lire(table, filtre + '&limit=2');
    if (!Array.isArray(rows) || rows.length > 1) throw new Error('Registre municipal indisponible ou ambigu');
    return rows[0] || null;
  }
  const territoire = 'country=eq.' + q(pays) + '&city=eq.' + q(ville);
  if (poste === 'maire') {
    const cycle = await unique('cycles_electoraux', territoire + '&poste_id=eq.maire&select=data');
    if (!cycle) return null;
    const data = typeof cycle.data === 'string' ? JSON.parse(cycle.data) : cycle.data;
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('Cycle municipal invalide');
    const nom = data.eluId;
    if (nom === undefined || nom === null || nom === '') return null;
    if (typeof nom !== 'string') throw new Error('Titulaire municipal invalide');
    const joueur = await unique('personnages', 'country=eq.' + q(pays) + '&name=eq.' + q(nom) + '&select=name');
    return { nom, estPJ: !!joueur };
  }
  const attribue = await unique('postes_attribues', territoire + '&poste_id=eq.maire_adjoint&select=titulaire,depuis');
  if (attribue) {
    if (typeof attribue.titulaire !== 'string' || !attribue.titulaire) throw new Error('Attribution municipale invalide');
    const joueur = await unique('personnages', 'country=eq.' + q(pays) + '&name=eq.' + q(attribue.titulaire) + '&select=name');
    if (!joueur) throw new Error('Attribution municipale orpheline');
    return { nom: attribue.titulaire, estPJ: true, posteComplet: {
      id: poste, city: ville, nommeLe: Date.parse(attribue.depuis)
    } };
  }
  const pnj = await unique('titulaires_pnj', territoire + '&poste_id=eq.maire_adjoint&select=nom_pnj');
  if (pnj && (typeof pnj.nom_pnj !== 'string' || !pnj.nom_pnj)) throw new Error('Titulaire PNJ invalide');
  return pnj ? { nom: pnj.nom_pnj, estPJ: false } : null;
}

export function contexteMunicipal(profilId, titulaire, lectureConnue) {
  const profil = PROFILS_MUNICIPAUX_LUTHECIA[profilId];
  if (!profil) return null;
  const role = !lectureConnue ? 'Personnel permanent de la mairie — fonction non vérifiée'
    : titulaire?.estPJ ? profil.rolePj : profil.rolePnj;
  return {
    identite: 'Tu es ' + profil.nom + ', dans ton bureau de l’Hôtel de Ville de Luthécia. Ta fonction actuelle est : ' + role + '.',
    limites: !lectureConnue
      ? 'La fonction du titulaire n’a pas pu être vérifiée. Ne te présente pas comme maire ou adjoint et ne prends aucune décision municipale.'
      : titulaire?.estPJ
        ? 'Le titulaire est ' + titulaire.nom + '. Tu restes la même personne, avec le même passé et les mêmes souvenirs, mais tu es son secrétaire. Tu n’exerces aucun pouvoir du poste : ni nomination, ni révocation, ni décision ou signature réservée au titulaire.'
        : 'Tu reprends ton rôle visible de PNJ à la vacance du poste. Ta présence ne crée aucun mandat ni aucune permission : seules les décisions enregistrées font autorité.',
  };
}
