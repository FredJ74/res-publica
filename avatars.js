/* ===========================
   RES PUBLICA — AVATARS.JS
   Portraits SVG des PNJ
   =========================== */

// Genere un avatar SVG unique pour chaque PNJ selon son nom/role
function generatePnjAvatar(name, role, size = 60) {
  const seed = hashString(name + role);
  const gender = inferGender(name, role, seed);
  const age = inferAge(role, seed);
  const style = inferStyle(role, seed);

  return generateSvgPortrait(seed, gender, age, style, size);
}

function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

function inferGender(name, role, seed) {
  // Noms feminins connus
  const femNames = ['marie','beatrice','sophie','claire','anne','julie','isabelle','nathalie','patricia','sylvie','francoise','catherine','helene','agnes','pauline','laure','emma','lea','alice','sarah','dr.'];
  const lowerName = name.toLowerCase();
  for (const fn of femNames) {
    if (lowerName.includes(fn)) return 'f';
  }
  // Roles feminins
  if (role.toLowerCase().includes('infirmiere') || role.toLowerCase().includes('secretaire')) return 'f';
  // Sinon selon seed
  return seed % 3 === 0 ? 'f' : 'm';
}

function inferAge(role, seed) {
  const r = role.toLowerCase();
  if (r.includes('president') || r.includes('ministre') || r.includes('directeur') || r.includes('prefet') || r.includes('commissaire')) return 'senior';
  if (r.includes('stagiaire') || r.includes('etudiant') || r.includes('assistant')) return 'young';
  if (r.includes('depute') || r.includes('juge') || r.includes('procureur')) return 'middle';
  const ages = ['young','middle','middle','senior','senior'];
  return ages[seed % ages.length];
}

function inferStyle(role, seed) {
  const r = role.toLowerCase();
  if (r.includes('militaire') || r.includes('general') || r.includes('officier') || r.includes('garde')) return 'military';
  if (r.includes('juge') || r.includes('procureur') || r.includes('avocat') || r.includes('magistrat')) return 'formal';
  if (r.includes('journaliste') || r.includes('redacteur')) return 'casual';
  if (r.includes('criminel') || r.includes('parrain') || r.includes('gang')) return 'street';
  if (r.includes('pretre') || r.includes('imam') || r.includes('culte')) return 'religious';
  if (r.includes('medecin') || r.includes('infirmier')) return 'medical';
  const styles = ['formal','casual','formal','business','casual'];
  return styles[seed % styles.length];
}

function generateSvgPortrait(seed, gender, age, style, size) {
  // Palettes de couleurs de peau
  const skinTones = ['#FDDBB4','#F5C49B','#E8A87C','#C68642','#8D5524','#FBEADB'];
  const skin = skinTones[seed % skinTones.length];

  // Couleurs de cheveux
  const hairColors = {
    young:  ['#2C1810','#8B4513','#D4A017','#A0522D','#000000'],
    middle: ['#2C1810','#5C4033','#808080','#A0522D','#4A3728'],
    senior: ['#C0C0C0','#A9A9A9','#808080','#696969','#DCDCDC']
  };
  const hairColor = hairColors[age][(seed >> 3) % hairColors[age].length];

  // Couleur des yeux
  const eyeColors = ['#634E37','#2E8B57','#4682B4','#8B6914','#2F4F4F'];
  const eyeColor = eyeColors[(seed >> 5) % eyeColors.length];

  // Forme du visage selon seed
  const faceW = 38 + (seed % 8);
  const faceH = 44 + ((seed >> 2) % 8);
  const cx = size / 2;
  const cy = size / 2 - 2;

  // Accessoires selon style
  const hasGlasses = (style === 'formal' || style === 'medical') && seed % 3 === 0;
  const hasBeard = gender === 'm' && age !== 'young' && seed % 4 > 0 && style !== 'medical';
  const hasMoustache = gender === 'm' && seed % 5 === 0;

  // Vetements selon style
  const clothColors = {
    formal:   ['#1a2a4a','#2a3a5a','#1a1a2a','#3a2a1a'],
    military: ['#2d4a2d','#3a5a3a','#4a5a2a','#2a3a1a'],
    casual:   ['#3a5a8a','#8a3a3a','#3a8a3a','#6a3a6a'],
    business: ['#2a2a3a','#1a3a5a','#3a1a1a','#2a3a2a'],
    street:   ['#1a1a1a','#3a1a1a','#1a1a3a','#2a2a1a'],
    religious:['#1a1a3a','#3a3a1a','#1a3a1a','#2a1a1a'],
    medical:  ['#e0e8f0','#d0e0f0','#e8e8e8','#d8e8d8']
  };
  const clothColor = clothColors[style][(seed >> 7) % 4];

  // Couleur col/cravate
  const collarColors = ['#C9A84C','#8a1a1a','#1a1a8a','#1a8a1a','#f0f0f0'];
  const collarColor = collarColors[(seed >> 9) % collarColors.length];

  const halfW = faceW / 2;
  const halfH = faceH / 2;

  // Cheveux selon genre et age
  let hairSvg = '';
  if (gender === 'f') {
    const hairStyle = seed % 3;
    if (hairStyle === 0) {
      // Cheveux longs
      hairSvg = `
        <ellipse cx="${cx}" cy="${cy - halfH + 6}" rx="${halfW + 8}" ry="14" fill="${hairColor}"/>
        <rect x="${cx - halfW - 6}" y="${cy - halfH + 8}" width="10" height="${halfH + 10}" rx="5" fill="${hairColor}"/>
        <rect x="${cx + halfW - 4}" y="${cy - halfH + 8}" width="10" height="${halfH + 10}" rx="5" fill="${hairColor}"/>
      `;
    } else if (hairStyle === 1) {
      // Chignon
      hairSvg = `
        <ellipse cx="${cx}" cy="${cy - halfH + 4}" rx="${halfW + 5}" ry="12" fill="${hairColor}"/>
        <circle cx="${cx}" cy="${cy - halfH - 6}" r="8" fill="${hairColor}"/>
      `;
    } else {
      // Mi-long
      hairSvg = `
        <ellipse cx="${cx}" cy="${cy - halfH + 5}" rx="${halfW + 6}" ry="13" fill="${hairColor}"/>
        <rect x="${cx - halfW - 4}" y="${cy - halfH + 6}" width="8" height="${halfH + 4}" rx="4" fill="${hairColor}"/>
        <rect x="${cx + halfW - 4}" y="${cy - halfH + 6}" width="8" height="${halfH + 4}" rx="4" fill="${hairColor}"/>
      `;
    }
  } else {
    const hairStyle = seed % 4;
    if (hairStyle === 0) {
      // Court classique
      hairSvg = `<ellipse cx="${cx}" cy="${cy - halfH + 5}" rx="${halfW + 2}" ry="11" fill="${hairColor}"/>`;
    } else if (hairStyle === 1) {
      // Chauve
      hairSvg = `<ellipse cx="${cx}" cy="${cy - halfH + 8}" rx="${halfW - 2}" ry="7" fill="${hairColor}" opacity=".3"/>`;
    } else if (hairStyle === 2) {
      // Ondule
      hairSvg = `
        <ellipse cx="${cx}" cy="${cy - halfH + 5}" rx="${halfW + 4}" ry="12" fill="${hairColor}"/>
        <path d="M${cx - halfW},${cy - halfH + 10} Q${cx - halfW + 5},${cy - halfH + 5} ${cx},${cy - halfH + 8} Q${cx + halfW - 5},${cy - halfH + 5} ${cx + halfW},${cy - halfH + 10}" fill="${hairColor}"/>
      `;
    } else {
      // Court serre
      hairSvg = `<ellipse cx="${cx}" cy="${cy - halfH + 6}" rx="${halfW + 1}" ry="9" fill="${hairColor}"/>`;
    }
  }

  // Corps/vetements
  const bodyY = cy + halfH - 2;
  let bodySvg = '';
  if (style === 'military') {
    bodySvg = `
      <rect x="${cx - 22}" y="${bodyY}" width="44" height="35" rx="4" fill="${clothColor}"/>
      <rect x="${cx - 3}" y="${bodyY}" width="6" height="35" fill="${hairColor}" opacity=".3"/>
      <rect x="${cx - 18}" y="${bodyY + 5}" width="8" height="4" rx="1" fill="#C9A84C" opacity=".8"/>
      <rect x="${cx - 18}" y="${bodyY + 12}" width="8" height="4" rx="1" fill="#C9A84C" opacity=".8"/>
    `;
  } else if (style === 'medical') {
    bodySvg = `
      <rect x="${cx - 22}" y="${bodyY}" width="44" height="35" rx="4" fill="${clothColor}"/>
      <rect x="${cx - 3}" y="${bodyY}" width="6" height="35" fill="#b0c8d8" opacity=".5"/>
      <rect x="${cx - 12}" y="${bodyY + 8}" width="10" height="3" rx="1" fill="#e05050" opacity=".7"/>
      <rect x="${cx - 8}" y="${bodyY + 5}" width="3" height="10" rx="1" fill="#e05050" opacity=".7"/>
    `;
  } else if (style === 'religious') {
    bodySvg = `
      <rect x="${cx - 22}" y="${bodyY}" width="44" height="35" rx="4" fill="${clothColor}"/>
      <rect x="${cx - 3}" y="${bodyY}" width="6" height="35" fill="#f0f0f0" opacity=".3"/>
      <circle cx="${cx}" cy="${bodyY + 15}" r="5" fill="#C9A84C" opacity=".7"/>
    `;
  } else if (style === 'formal') {
    bodySvg = `
      <rect x="${cx - 22}" y="${bodyY}" width="44" height="35" rx="4" fill="${clothColor}"/>
      <polygon points="${cx - 6},${bodyY} ${cx + 6},${bodyY} ${cx + 3},${bodyY + 15} ${cx - 3},${bodyY + 15}" fill="#f0f0f0"/>
      <rect x="${cx - 2}" y="${bodyY + 3}" width="4" height="18" fill="${collarColor}" opacity=".9"/>
    `;
  } else if (style === 'street') {
    bodySvg = `
      <rect x="${cx - 22}" y="${bodyY}" width="44" height="35" rx="4" fill="${clothColor}"/>
      <rect x="${cx - 22}" y="${bodyY}" width="44" height="8" rx="4" fill="${hairColor}" opacity=".4"/>
    `;
  } else {
    // casual / business
    bodySvg = `
      <rect x="${cx - 22}" y="${bodyY}" width="44" height="35" rx="4" fill="${clothColor}"/>
      <rect x="${cx - 8}" y="${bodyY}" width="16" height="20" rx="3" fill="${collarColor}" opacity=".15"/>
    `;
  }

  // Barbe
  let beardSvg = '';
  if (hasBeard) {
    beardSvg = `<ellipse cx="${cx}" cy="${cy + halfH - 6}" rx="${halfW - 4}" ry="8" fill="${hairColor}" opacity=".85"/>`;
  }
  if (hasMoustache) {
    beardSvg += `<ellipse cx="${cx}" cy="${cy + 6}" rx="10" ry="3.5" fill="${hairColor}" opacity=".85"/>`;
  }

  // Lunettes
  let glassesSvg = '';
  if (hasGlasses) {
    glassesSvg = `
      <circle cx="${cx - 8}" cy="${cy - 2}" r="7" fill="none" stroke="#3a3020" stroke-width="1.5" opacity=".7"/>
      <circle cx="${cx + 8}" cy="${cy - 2}" r="7" fill="none" stroke="#3a3020" stroke-width="1.5" opacity=".7"/>
      <line x1="${cx - 1}" y1="${cy - 2}" x2="${cx + 1}" y2="${cy - 2}" stroke="#3a3020" stroke-width="1.5" opacity=".7"/>
      <line x1="${cx - 15}" y1="${cy - 2}" x2="${cx - 22}" y2="${cy}" stroke="#3a3020" stroke-width="1" opacity=".7"/>
      <line x1="${cx + 15}" y1="${cy - 2}" x2="${cx + 22}" y2="${cy}" stroke="#3a3020" stroke-width="1" opacity=".7"/>
    `;
  }

  // Rides pour seniors
  let wrinklesSvg = '';
  if (age === 'senior') {
    wrinklesSvg = `
      <path d="M${cx - halfW + 4},${cy - 8} Q${cx - halfW + 2},${cy - 5} ${cx - halfW + 4},${cy - 2}" fill="none" stroke="${skin}" stroke-width="1" opacity=".4" filter="url(#shadow)"/>
      <path d="M${cx + halfW - 4},${cy - 8} Q${cx + halfW - 2},${cy - 5} ${cx + halfW - 4},${cy - 2}" fill="none" stroke="${skin}" stroke-width="1" opacity=".4"/>
    `;
  }

  const svgStr = `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <clipPath id="circle-clip-${seed}">
        <circle cx="${cx}" cy="${cy}" r="${size/2 - 1}"/>
      </clipPath>
    </defs>
    <!-- Fond -->
    <circle cx="${cx}" cy="${cy}" r="${size/2 - 1}" fill="#1a1508" stroke="#3a2a10" stroke-width="1.5"/>
    <g clip-path="url(#circle-clip-${seed})">
      <!-- Corps -->
      ${bodySvg}
      <!-- Cou -->
      <rect x="${cx - 7}" y="${cy + halfH - 5}" width="14" height="12" rx="3" fill="${skin}"/>
      <!-- Cheveux (derriere) -->
      ${hairSvg}
      <!-- Visage -->
      <ellipse cx="${cx}" cy="${cy}" rx="${halfW}" ry="${halfH}" fill="${skin}"/>
      <!-- Oreilles -->
      <ellipse cx="${cx - halfW + 1}" cy="${cy + 2}" rx="5" ry="7" fill="${skin}"/>
      <ellipse cx="${cx + halfW - 1}" cy="${cy + 2}" rx="5" ry="7" fill="${skin}"/>
      <!-- Sourcils -->
      <path d="M${cx - 14},${cy - 12} Q${cx - 8},${cy - 15} ${cx - 2},${cy - 12}" fill="none" stroke="${hairColor}" stroke-width="2" stroke-linecap="round"/>
      <path d="M${cx + 2},${cy - 12} Q${cx + 8},${cy - 15} ${cx + 14},${cy - 12}" fill="none" stroke="${hairColor}" stroke-width="2" stroke-linecap="round"/>
      <!-- Yeux -->
      <ellipse cx="${cx - 9}" cy="${cy - 3}" rx="6" ry="5" fill="white"/>
      <ellipse cx="${cx + 9}" cy="${cy - 3}" rx="6" ry="5" fill="white"/>
      <circle cx="${cx - 9}" cy="${cy - 3}" r="3.5" fill="${eyeColor}"/>
      <circle cx="${cx + 9}" cy="${cy - 3}" r="3.5" fill="${eyeColor}"/>
      <circle cx="${cx - 8}" cy="${cy - 4}" r="1" fill="white"/>
      <circle cx="${cx + 10}" cy="${cy - 4}" r="1" fill="white"/>
      <!-- Nez -->
      <path d="M${cx},${cy - 2} Q${cx - 4},${cy + 5} ${cx - 3},${cy + 8} Q${cx},${cy + 10} ${cx + 3},${cy + 8} Q${cx + 4},${cy + 5} ${cx},${cy - 2}" fill="${skin}" stroke="${skin}" stroke-width=".5" opacity=".6"/>
      <!-- Bouche -->
      ${gender === 'f'
        ? `<path d="M${cx - 8},${cy + 13} Q${cx},${cy + 18} ${cx + 8},${cy + 13}" fill="none" stroke="#c06060" stroke-width="2" stroke-linecap="round"/>
           <path d="M${cx - 8},${cy + 13} Q${cx},${cy + 16} ${cx + 8},${cy + 13}" fill="#d07070" opacity=".4"/>`
        : `<path d="M${cx - 8},${cy + 14} Q${cx},${cy + 18} ${cx + 8},${cy + 14}" fill="none" stroke="#a05040" stroke-width="1.8" stroke-linecap="round"/>`
      }
      <!-- Rides senior -->
      ${wrinklesSvg}
      <!-- Barbe/moustache -->
      ${beardSvg}
      <!-- Lunettes -->
      ${glassesSvg}
    </g>
  </svg>`;

  return svgStr;
}

// Rendu HTML d'un avatar pour une personne
function renderPnjAvatarHtml(person, size = 40) {
  const svg = generatePnjAvatar(person.name, person.role, size);
  return `<div style="width:${size}px;height:${size}px;border-radius:50%;overflow:hidden;border:1px solid #3a2a10;flex-shrink:0">${svg}</div>`;
}
