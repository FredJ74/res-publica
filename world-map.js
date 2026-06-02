/* ===========================
   RES PUBLICA — WORLD-MAP.JS
   Carte SVG interactive
   =========================== */

function renderWorldMapSVG() {
  return `
  <div style="padding:.5rem 1rem;background:#0a0805;border-bottom:1px solid #1a1810;display:flex;align-items:center;justify-content:space-between">
    <div style="font-family:'Bebas Neue',sans-serif;font-size:.75rem;letter-spacing:.15em;color:#6a5a20">CARTE DU MONDE — RES PUBLICA</div>
    <div style="font-size:.72rem;color:#4a4030;font-style:italic">Cliquez sur une ville pour vous y rendre</div>
  </div>
  <div style="flex:1;overflow:hidden;position:relative;background:#0a0f1a">
    <svg id="world-svg" viewBox="0 0 900 600" xmlns="http://www.w3.org/2000/svg"
      style="width:100%;height:100%;cursor:default">

      <!-- OCEAN -->
      <defs>
        <pattern id="ocean-pattern" x="0" y="0" width="40" height="40" patternUnits="userSpaceOnUse">
          <rect width="40" height="40" fill="#0a0f1a"/>
          <path d="M0,20 Q10,15 20,20 Q30,25 40,20" fill="none" stroke="#0d1520" stroke-width=".8"/>
        </pattern>
        <filter id="glow">
          <feGaussianBlur stdDeviation="2" result="blur"/>
          <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>

      <rect width="900" height="600" fill="url(#ocean-pattern)"/>

      <!-- Nom des oceans -->
      <text x="80" y="300" text-anchor="middle" font-size="11" fill="#0d1a2a" font-family="Georgia" font-style="italic" letter-spacing="3">OCEAN</text>
      <text x="80" y="315" text-anchor="middle" font-size="11" fill="#0d1a2a" font-family="Georgia" font-style="italic" letter-spacing="3">OCCIDENTAL</text>
      <text x="820" y="300" text-anchor="middle" font-size="11" fill="#0d1a2a" font-family="Georgia" font-style="italic" letter-spacing="3">MER</text>
      <text x="820" y="315" text-anchor="middle" font-size="11" fill="#0d1a2a" font-family="Georgia" font-style="italic" letter-spacing="3">ORIENTALE</text>

      <!-- ===================== -->
      <!-- REPUBLIA              -->
      <!-- ===================== -->
      <g id="empire-republic" onmouseenter="zoomEmpire('republic')" style="cursor:pointer">
        <!-- Territoire principal -->
        <path d="M150,80 L320,60 L380,90 L400,180 L370,250 L300,290 L220,280 L160,240 L130,170 Z"
          fill="#0d1f35" stroke="#2a4a70" stroke-width="1.5"/>
        <!-- Nom empire -->
        <text x="265" y="155" text-anchor="middle" font-family="'Bebas Neue',sans-serif" font-size="16"
          fill="#4a9ade" letter-spacing="3" opacity=".9">REPUBLIA</text>

        <!-- Province Nord (pointilles) -->
        <path d="M150,80 L320,60 L370,130 L280,160 L160,140 Z"
          fill="none" stroke="#2a4a70" stroke-width="1" stroke-dasharray="5,4"/>
        <text x="235" y="110" text-anchor="middle" font-size="9" fill="#3a6a9a"
          font-family="Georgia" font-style="italic" letter-spacing="1">Province Nord</text>

        <!-- Province Sud (pointilles) -->
        <path d="M160,140 L280,160 L370,130 L400,180 L370,250 L300,290 L220,280 L160,240 Z"
          fill="none" stroke="#2a4a70" stroke-width="1" stroke-dasharray="5,4"/>
        <text x="270" y="220" text-anchor="middle" font-size="9" fill="#3a6a9a"
          font-family="Georgia" font-style="italic" letter-spacing="1">Province Sud</text>

        <!-- LUTHECIA (Capitale) -->
        <g class="map-city" onclick="mapClickCity('republic','capitale')" style="cursor:pointer">
          <circle cx="260" cy="175" r="7" fill="#4a9ade" opacity=".9"/>
          <circle cx="260" cy="175" r="11" fill="none" stroke="#4a9ade" stroke-width="1" opacity=".5"/>
          <polygon points="260,165 263,172 270,172 265,177 267,184 260,179 253,184 255,177 250,172 257,172"
            fill="#C9A84C" opacity=".9"/>
          <text x="260" y="196" text-anchor="middle" font-size="9" fill="#e0d0a0"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">LUTHECIA</text>
          <text x="260" y="205" text-anchor="middle" font-size="7" fill="#4a9ade"
            font-family="Georgia" font-style="italic">Capitale</text>
        </g>

        <!-- PORT-SAINTE-MARIE -->
        <g class="map-city" onclick="mapClickCity('republic','ville_a')" style="cursor:pointer">
          <circle cx="175" cy="230" r="5" fill="#3a7aae" opacity=".8"/>
          <circle cx="175" cy="230" r="8" fill="none" stroke="#3a7aae" stroke-width="1" opacity=".4"/>
          <text x="175" y="247" text-anchor="middle" font-size="8" fill="#c0d0e0"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">PORT-STE-MARIE</text>
          <text x="175" y="255" text-anchor="middle" font-size="6.5" fill="#3a7aae"
            font-family="Georgia" font-style="italic">Port · Ouest</text>
        </g>

        <!-- MONTROUGE -->
        <g class="map-city" onclick="mapClickCity('republic','ville_b')" style="cursor:pointer">
          <circle cx="310" cy="100" r="5" fill="#3a7aae" opacity=".8"/>
          <circle cx="310" cy="100" r="8" fill="none" stroke="#3a7aae" stroke-width="1" opacity=".4"/>
          <text x="310" y="117" text-anchor="middle" font-size="8" fill="#c0d0e0"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">MONTROUGE</text>
          <text x="310" y="125" text-anchor="middle" font-size="6.5" fill="#3a7aae"
            font-family="Georgia" font-style="italic">Industrie · Nord</text>
        </g>

        <!-- CASERNE MILITAIRE -->
        <g class="map-city" onclick="mapClickCity('republic','caserne')" style="cursor:pointer">
          <rect x="337" y="148" width="14" height="14" fill="#2a4a2a" stroke="#4a8a4a" stroke-width="1.2" rx="2"/>
          <text x="344" y="158" text-anchor="middle" font-size="7" fill="#4a8a4a" font-family="'Bebas Neue',sans-serif">✦</text>
          <text x="344" y="172" text-anchor="middle" font-size="7.5" fill="#6a9a6a"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">CASERNE</text>
          <text x="344" y="180" text-anchor="middle" font-size="6" fill="#4a6a4a"
            font-family="Georgia" font-style="italic">Militaire · 1 PA</text>
        </g>

        <!-- QHS -->
        <g class="map-city" onclick="mapClickCity('republic','qhs')" style="cursor:pointer">
          <rect x="187" y="195" width="14" height="14" fill="#1a0808" stroke="#8a2020" stroke-width="1.2" rx="2"/>
          <text x="194" y="205" text-anchor="middle" font-size="7" fill="#8a2020" font-family="'Bebas Neue',sans-serif">▪</text>
          <text x="194" y="219" text-anchor="middle" font-size="7.5" fill="#9a4a4a"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">QHS</text>
          <text x="194" y="227" text-anchor="middle" font-size="6" fill="#6a3030"
            font-family="Georgia" font-style="italic">Haute securite · 1 PA</text>
        </g>
      </g>

      <!-- ===================== -->
      <!-- EL ESTADO             -->
      <!-- ===================== -->
      <g id="empire-narco" onmouseenter="zoomEmpire('narco')" style="cursor:pointer">
        <path d="M480,320 L620,300 L680,340 L700,430 L650,490 L550,500 L470,460 L450,390 Z"
          fill="#1a0a05" stroke="#4a2010" stroke-width="1.5"/>
        <text x="575" y="400" text-anchor="middle" font-family="'Bebas Neue',sans-serif" font-size="14"
          fill="#cc6644" letter-spacing="2" opacity=".9">EL ESTADO</text>

        <!-- Province Este -->
        <path d="M580,300 L680,340 L700,430 L620,420 L600,340 Z"
          fill="none" stroke="#4a2010" stroke-width="1" stroke-dasharray="5,4"/>
        <text x="645" y="375" text-anchor="middle" font-size="8" fill="#7a4020"
          font-family="Georgia" font-style="italic">Provincia Este</text>

        <!-- Province Oeste -->
        <path d="M480,320 L580,300 L600,340 L620,420 L550,500 L470,460 L450,390 Z"
          fill="none" stroke="#4a2010" stroke-width="1" stroke-dasharray="5,4"/>
        <text x="520" y="420" text-anchor="middle" font-size="8" fill="#7a4020"
          font-family="Georgia" font-style="italic">Provincia Oeste</text>

        <!-- CIUDAD ROJA (Capitale) -->
        <g class="map-city" onclick="mapClickCity('narco','capitale')" style="cursor:pointer">
          <circle cx="580" cy="390" r="7" fill="#cc6644" opacity=".9"/>
          <circle cx="580" cy="390" r="11" fill="none" stroke="#cc6644" stroke-width="1" opacity=".5"/>
          <polygon points="580,380 583,387 590,387 585,392 587,399 580,394 573,399 575,392 570,387 577,387"
            fill="#C9A84C" opacity=".9"/>
          <text x="580" y="411" text-anchor="middle" font-size="9" fill="#e0c0a0"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">CIUDAD ROJA</text>
          <text x="580" y="420" text-anchor="middle" font-size="7" fill="#cc6644"
            font-family="Georgia" font-style="italic">Capitale</text>
        </g>

        <!-- PUERTO NEGRO -->
        <g class="map-city" onclick="mapClickCity('narco','ville_a')" style="cursor:pointer">
          <circle cx="490" cy="445" r="5" fill="#9a4030" opacity=".8"/>
          <circle cx="490" cy="445" r="8" fill="none" stroke="#9a4030" stroke-width="1" opacity=".4"/>
          <text x="490" y="460" text-anchor="middle" font-size="8" fill="#c0a090"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">PUERTO NEGRO</text>
        </g>

        <!-- VILLA SANGRE -->
        <g class="map-city" onclick="mapClickCity('narco','ville_b')" style="cursor:pointer">
          <circle cx="660" cy="440" r="5" fill="#9a4030" opacity=".8"/>
          <circle cx="660" cy="440" r="8" fill="none" stroke="#9a4030" stroke-width="1" opacity=".4"/>
          <text x="660" y="455" text-anchor="middle" font-size="8" fill="#c0a090"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">VILLA SANGRE</text>
        </g>

        <!-- CUARTEL (Caserne El Estado) -->
        <g class="map-city" onclick="mapClickCity('narco','caserne')" style="cursor:pointer">
          <rect x="537" y="453" width="14" height="14" fill="#2a1a08" stroke="#8a4a20" stroke-width="1.2" rx="2"/>
          <text x="544" y="463" text-anchor="middle" font-size="7" fill="#8a4a20" font-family="'Bebas Neue',sans-serif">✦</text>
          <text x="544" y="477" text-anchor="middle" font-size="7.5" fill="#9a6a4a"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">CUARTEL</text>
          <text x="544" y="485" text-anchor="middle" font-size="6" fill="#6a4a30"
            font-family="Georgia" font-style="italic">Militaire · 1 PA</text>
        </g>

        <!-- PRISION CENTRAL (QHS El Estado) -->
        <g class="map-city" onclick="mapClickCity('narco','qhs')" style="cursor:pointer">
          <rect x="617" y="373" width="14" height="14" fill="#1a0505" stroke="#8a2020" stroke-width="1.2" rx="2"/>
          <text x="624" y="383" text-anchor="middle" font-size="7" fill="#8a2020" font-family="'Bebas Neue',sans-serif">▪</text>
          <text x="624" y="397" text-anchor="middle" font-size="7.5" fill="#9a3a3a"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">PRISION</text>
          <text x="624" y="405" text-anchor="middle" font-size="6" fill="#6a2a2a"
            font-family="Georgia" font-style="italic">Haute securite · 1 PA</text>
        </g>
      </g>

      <!-- ===================== -->
      <!-- SOVARKA               -->
      <!-- ===================== -->
      <g id="empire-soviet" onmouseenter="zoomEmpire('soviet')" style="cursor:pointer">
        <path d="M480,60 L680,50 L750,100 L730,200 L660,240 L560,230 L480,200 L450,130 Z"
          fill="#0d0505" stroke="#4a1010" stroke-width="1.5"/>
        <text x="600" y="145" text-anchor="middle" font-family="'Bebas Neue',sans-serif" font-size="14"
          fill="#cc4444" letter-spacing="2" opacity=".9">SOVARKA</text>

        <!-- Oblast Nord -->
        <path d="M480,60 L680,50 L700,130 L580,140 L460,110 Z"
          fill="none" stroke="#4a1010" stroke-width="1" stroke-dasharray="5,4"/>
        <text x="580" y="95" text-anchor="middle" font-size="8" fill="#7a2020"
          font-family="Georgia" font-style="italic">Oblast Nord</text>

        <!-- Oblast Sud -->
        <path d="M460,110 L580,140 L700,130 L730,200 L660,240 L560,230 L480,200 Z"
          fill="none" stroke="#4a1010" stroke-width="1" stroke-dasharray="5,4"/>
        <text x="590" y="195" text-anchor="middle" font-size="8" fill="#7a2020"
          font-family="Georgia" font-style="italic">Oblast Sud</text>

        <!-- NOVOMIRSK (Capitale) -->
        <g class="map-city" onclick="mapClickCity('soviet','capitale')" style="cursor:pointer">
          <circle cx="600" cy="150" r="7" fill="#cc4444" opacity=".9"/>
          <circle cx="600" cy="150" r="11" fill="none" stroke="#cc4444" stroke-width="1" opacity=".5"/>
          <polygon points="600,140 603,147 610,147 605,152 607,159 600,154 593,159 595,152 590,147 597,147"
            fill="#C9A84C" opacity=".9"/>
          <text x="600" y="171" text-anchor="middle" font-size="9" fill="#e0b0b0"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">NOVOMIRSK</text>
          <text x="600" y="180" text-anchor="middle" font-size="7" fill="#cc4444"
            font-family="Georgia" font-style="italic">Capitale</text>
        </g>

        <!-- STAROVKA -->
        <g class="map-city" onclick="mapClickCity('soviet','ville_a')" style="cursor:pointer">
          <circle cx="510" cy="185" r="5" fill="#8a2020" opacity=".8"/>
          <circle cx="510" cy="185" r="8" fill="none" stroke="#8a2020" stroke-width="1" opacity=".4"/>
          <text x="510" y="200" text-anchor="middle" font-size="8" fill="#c09090"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">STAROVKA</text>
        </g>

        <!-- KRASNOV -->
        <g class="map-city" onclick="mapClickCity('soviet','ville_b')" style="cursor:pointer">
          <circle cx="690" cy="185" r="5" fill="#8a2020" opacity=".8"/>
          <circle cx="690" cy="185" r="8" fill="none" stroke="#8a2020" stroke-width="1" opacity=".4"/>
          <text x="690" y="200" text-anchor="middle" font-size="8" fill="#c09090"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">KRASNOV</text>
        </g>

        <!-- GARNISON (Caserne Sovarka) -->
        <g class="map-city" onclick="mapClickCity('soviet','caserne')" style="cursor:pointer">
          <rect x="537" y="138" width="14" height="14" fill="#0a1a0a" stroke="#4a2020" stroke-width="1.2" rx="2"/>
          <text x="544" y="148" text-anchor="middle" font-size="7" fill="#6a2020" font-family="'Bebas Neue',sans-serif">✦</text>
          <text x="544" y="162" text-anchor="middle" font-size="7.5" fill="#8a4a4a"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">GARNISON</text>
          <text x="544" y="170" text-anchor="middle" font-size="6" fill="#5a3030"
            font-family="Georgia" font-style="italic">Militaire · 1 PA</text>
        </g>

        <!-- GOULAG (QHS Sovarka) -->
        <g class="map-city" onclick="mapClickCity('soviet','qhs')" style="cursor:pointer">
          <rect x="647" y="138" width="14" height="14" fill="#0a0505" stroke="#6a1010" stroke-width="1.2" rx="2"/>
          <text x="654" y="148" text-anchor="middle" font-size="7" fill="#6a1010" font-family="'Bebas Neue',sans-serif">▪</text>
          <text x="654" y="162" text-anchor="middle" font-size="7.5" fill="#8a2a2a"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">GOULAG</text>
          <text x="654" y="170" text-anchor="middle" font-size="6" fill="#5a2020"
            font-family="Georgia" font-style="italic">Camp · 1 PA</text>
        </g>
      </g>

      <!-- ===================== -->
      <!-- AL-KHALIJA            -->
      <!-- ===================== -->
      <g id="empire-khalija" onmouseenter="zoomEmpire('khalija')" style="cursor:pointer">
        <path d="M150,320 L320,310 L380,360 L360,460 L280,510 L180,500 L120,440 L110,370 Z"
          fill="#0d0d00" stroke="#4a3a00" stroke-width="1.5"/>
        <text x="245" y="415" text-anchor="middle" font-family="'Bebas Neue',sans-serif" font-size="13"
          fill="#C9A84C" letter-spacing="2" opacity=".9">AL-KHALIJA</text>

        <!-- Province Royale -->
        <path d="M150,320 L320,310 L340,390 L230,400 L130,370 Z"
          fill="none" stroke="#4a3a00" stroke-width="1" stroke-dasharray="5,4"/>
        <text x="235" y="360" text-anchor="middle" font-size="8" fill="#8a7020"
          font-family="Georgia" font-style="italic">Province Royale</text>

        <!-- Province Desertique -->
        <path d="M130,370 L230,400 L340,390 L360,460 L280,510 L180,500 L120,440 Z"
          fill="none" stroke="#4a3a00" stroke-width="1" stroke-dasharray="5,4"/>
        <text x="235" y="460" text-anchor="middle" font-size="8" fill="#8a7020"
          font-family="Georgia" font-style="italic">Province Desertique</text>

        <!-- AL-MADINA (Capitale) -->
        <g class="map-city" onclick="mapClickCity('khalija','capitale')" style="cursor:pointer">
          <circle cx="245" cy="390" r="7" fill="#C9A84C" opacity=".9"/>
          <circle cx="245" cy="390" r="11" fill="none" stroke="#C9A84C" stroke-width="1" opacity=".5"/>
          <polygon points="245,380 248,387 255,387 250,392 252,399 245,394 238,399 240,392 235,387 242,387"
            fill="#f0d070" opacity=".9"/>
          <text x="245" y="411" text-anchor="middle" font-size="9" fill="#e0d090"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">AL-MADINA</text>
          <text x="245" y="420" text-anchor="middle" font-size="7" fill="#C9A84C"
            font-family="Georgia" font-style="italic">Capitale</text>
        </g>

        <!-- OASIS CITY -->
        <g class="map-city" onclick="mapClickCity('khalija','ville_a')" style="cursor:pointer">
          <circle cx="155" cy="450" r="5" fill="#9a7a20" opacity=".8"/>
          <circle cx="155" cy="450" r="8" fill="none" stroke="#9a7a20" stroke-width="1" opacity=".4"/>
          <text x="155" y="465" text-anchor="middle" font-size="8" fill="#c0b070"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">OASIS CITY</text>
        </g>

        <!-- AL-PETROL -->
        <g class="map-city" onclick="mapClickCity('khalija','ville_b')" style="cursor:pointer">
          <circle cx="330" cy="440" r="5" fill="#9a7a20" opacity=".8"/>
          <circle cx="330" cy="440" r="8" fill="none" stroke="#9a7a20" stroke-width="1" opacity=".4"/>
          <text x="330" y="455" text-anchor="middle" font-size="8" fill="#c0b070"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">AL-PETROL</text>
        </g>

        <!-- FORTERESSE ROYALE (Caserne Al-Khalija) -->
        <g class="map-city" onclick="mapClickCity('khalija','caserne')" style="cursor:pointer">
          <rect x="192" y="393" width="14" height="14" fill="#1a1500" stroke="#8a7a10" stroke-width="1.2" rx="2"/>
          <text x="199" y="403" text-anchor="middle" font-size="7" fill="#8a7a10" font-family="'Bebas Neue',sans-serif">✦</text>
          <text x="199" y="417" text-anchor="middle" font-size="7" fill="#a09030"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">FORTERESSE</text>
          <text x="199" y="425" text-anchor="middle" font-size="6" fill="#6a6020"
            font-family="Georgia" font-style="italic">Royale · 1 PA</text>
        </g>

        <!-- PRISON ROYALE (QHS Al-Khalija) -->
        <g class="map-city" onclick="mapClickCity('khalija','qhs')" style="cursor:pointer">
          <rect x="272" y="468" width="14" height="14" fill="#0a0800" stroke="#6a5010" stroke-width="1.2" rx="2"/>
          <text x="279" y="478" text-anchor="middle" font-size="7" fill="#6a5010" font-family="'Bebas Neue',sans-serif">▪</text>
          <text x="279" y="492" text-anchor="middle" font-size="7.5" fill="#8a6a20"
            font-family="'Bebas Neue',sans-serif" letter-spacing="1">PRISON ROYALE</text>
          <text x="279" y="500" text-anchor="middle" font-size="6" fill="#5a4010"
            font-family="Georgia" font-style="italic">Haute securite · 1 PA</text>
        </g>
      </g>

      <!-- Routes entre empires (pointilles fins) -->
      <line x1="400" y1="200" x2="450" y2="150" stroke="#2a2010" stroke-width=".8" stroke-dasharray="6,5"/>
      <line x1="380" y1="240" x2="450" y2="320" stroke="#2a2010" stroke-width=".8" stroke-dasharray="6,5"/>

      <!-- Legende -->
      <g transform="translate(20,540)">
        <rect width="200" height="50" fill="#0a0a07" stroke="#2a2010" stroke-width=".5" rx="2"/>
        <text x="10" y="14" font-size="7" fill="#6a5a20" font-family="'Bebas Neue',sans-serif" letter-spacing=".1em">LEGENDE</text>
        <circle cx="20" cy="26" r="5" fill="#C9A84C"/>
        <polygon points="20,20 22,25 28,25 23,28 25,33 20,30 15,33 17,28 12,25 18,25" fill="#C9A84C" transform="scale(.6) translate(13,13)"/>
        <text x="30" y="29" font-size="7" fill="#8a8060" font-family="Georgia">Capitale</text>
        <circle cx="20" cy="40" r="4" fill="#4a6a8a"/>
        <text x="30" y="43" font-size="7" fill="#8a8060" font-family="Georgia">Ville secondaire</text>
        <line x1="100" y1="26" x2="130" y2="26" stroke="#3a3020" stroke-width="1" stroke-dasharray="4,3"/>
        <text x="135" y="29" font-size="7" fill="#8a8060" font-family="Georgia">Province</text>
        <rect x="100" y="35" width="8" height="8" fill="#2a4a2a" stroke="#4a8a4a" stroke-width="1" rx="1"/>
        <text x="113" y="43" font-size="7" fill="#6a9a6a" font-family="Georgia">Caserne</text>
        <rect x="145" y="35" width="8" height="8" fill="#1a0808" stroke="#8a2020" stroke-width="1" rx="1"/>
        <text x="158" y="43" font-size="7" fill="#9a4a4a" font-family="Georgia">QHS</text>
      </g>

      <!-- Echelle -->
      <g transform="translate(750,555)">
        <line x1="0" y1="0" x2="80" y2="0" stroke="#3a3020" stroke-width="1"/>
        <line x1="0" y1="-4" x2="0" y2="4" stroke="#3a3020" stroke-width="1"/>
        <line x1="80" y1="-4" x2="80" y2="4" stroke="#3a3020" stroke-width="1"/>
        <text x="40" y="-6" text-anchor="middle" font-size="7" fill="#4a4030" font-family="Georgia">500 km</text>
      </g>

    </svg>
  </div>
  `;
}

function mapClickCity(countryId, cityId) {
  closeWorldMap();
  // Si meme pays, voyage direct
  if (countryId === state.country) {
    travelToCity(cityId);
  } else {
    // Voyage inter-empire
    if (!TEST_MODE && state.pa < 5) {
      showToast('PA insuffisants', 'Un voyage international coute 5 PA.', false);
      return;
    }
    state.country = countryId;
    state.currentCity = cityId;
    state.currentBuilding = null;
    state.currentRoom = null;
    if (!TEST_MODE) state.pa -= 5;
    buildCityTabs();
    renderMinimap(cityId);
    showVueRue();
    updateUI();
    const co = COUNTRIES[countryId];
    const world = WORLD[countryId];
    const city = world?.[cityId];
    addJournalEntry(`Vous voyagez vers ${city?.name || cityId}, ${co?.n || countryId}.`, 'event-info');
  }
}

// Zoom sur un empire au survol
let currentZoom = null;

function zoomEmpire(empireId) {
  const svg = document.getElementById('world-svg');
  if (!svg) return;

  const zoomBoxes = {
    republic: '100 40 330 280',
    narco:    '420 270 320 270',
    soviet:   '420 30 370 230',
    khalija:  '80 290 320 260',
    caserne:  '300 130 120 100',
    qhs:      '155 170 120 100'
  };

  const box = zoomBoxes[empireId];
  if (!box || currentZoom === empireId) return;

  currentZoom = empireId;
  svg.style.transition = 'all .4s ease';
  svg.setAttribute('viewBox', box);

  // Bouton reset zoom
  const resetBtn = document.getElementById('map-reset-zoom');
  if (resetBtn) resetBtn.style.display = 'block';
}

function resetZoom() {
  const svg = document.getElementById('world-svg');
  if (!svg) return;
  svg.style.transition = 'all .4s ease';
  svg.setAttribute('viewBox', '0 0 900 600');
  currentZoom = null;
  const resetBtn = document.getElementById('map-reset-zoom');
  if (resetBtn) resetBtn.style.display = 'none';
}
