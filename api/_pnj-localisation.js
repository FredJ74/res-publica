// Métadonnées du rendu commun, jointes uniquement à la position lue au serveur.
import { SCENES_PNJ } from './_pnj-scenes-generes.js';
export function sceneDialogue(position) {
  if (!position || position.ok !== true ||
      !['country','city','building','room'].every(k => typeof position[k] === 'string' && position[k])) return null;
  return SCENES_PNJ[JSON.stringify([position.country,position.city,position.building,position.room])] || null;
}
