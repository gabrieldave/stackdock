/** SVG técnicos (sin dependencias). Trazos en tinta, cotas en mono. */

const reg = (x: number, y: number) =>
  `<path d="M${x - 7} ${y}h14M${x} ${y - 7}v14" class="reg"/>`;

/** Fig 02a — Dock por pantalla */
export const figDock = `
<svg viewBox="0 0 480 360" class="fig" role="img" aria-hidden="true">
  ${reg(24, 24)}${reg(456, 24)}${reg(24, 336)}${reg(456, 336)}
  <rect x="80" y="40" width="320" height="180" class="scr"/>
  <rect x="80" y="40" width="320" height="6" class="mb"/>
  <rect x="140" y="232" width="200" height="112" class="scr"/>
  <rect x="140" y="232" width="200" height="4" class="mb"/>
  <g class="dockfig">
    <rect x="190" y="188" width="100" height="20" rx="5"/>
    <rect x="207" y="312" width="66" height="16" rx="4"/>
  </g>
  <g class="tiles">
    <rect x="196" y="192" width="12" height="12" rx="3" fill="#38BDF8"/><rect x="212" y="192" width="12" height="12" rx="3" fill="#FBBF24"/><rect x="228" y="192" width="12" height="12" rx="3" fill="#6366F1"/><rect x="244" y="192" width="12" height="12" rx="3" fill="#F472B6"/>
    <rect x="212" y="315" width="10" height="10" rx="2.5" fill="#38BDF8"/><rect x="226" y="315" width="10" height="10" rx="2.5" fill="#FBBF24"/><rect x="240" y="315" width="10" height="10" rx="2.5" fill="#6366F1"/>
  </g>
  <path d="M420 208v12M412 220h16M412 208h16" class="dim"/>
  <text x="432" y="217" class="lbl">24 pt</text>
  <path d="M70 40v180" class="dim"/><text x="40" y="134" class="lbl">D1</text>
  <path d="M130 232v112" class="dim"/><text x="100" y="292" class="lbl">D2</text>
  <text x="240" y="30" class="lbl c">NSVisualEffectView · .hudWindow · r16</text>
</svg>`;

/** Fig 02b — Perfiles separados */
export const figProfiles = `
<svg viewBox="0 0 480 360" class="fig" role="img" aria-hidden="true">
  ${reg(24, 24)}${reg(456, 24)}${reg(24, 336)}${reg(456, 336)}
  <rect x="200" y="56" width="80" height="80" rx="18" fill="#FBBF24" class="tile-ink"/>
  <text x="240" y="106" class="glyph c">C</text>
  <text x="240" y="40" class="lbl c">1 PROCESS · 3 WINDOWS</text>
  <path d="M240 140v40M240 180H112v28M240 180v28M240 180h128v28" class="dim flow"/>
  <g>
    <rect x="80" y="212" width="64" height="64" rx="14" fill="#FBBF24" class="tile-ink"/>
    <circle cx="132" cy="264" r="13" fill="#10B981" class="tile-ink"/><text x="132" y="269" class="mono-s c">W</text>
    <rect x="208" y="212" width="64" height="64" rx="14" fill="#FBBF24" class="tile-ink"/>
    <circle cx="260" cy="264" r="13" fill="#6366F1" class="tile-ink"/><text x="260" y="269" class="mono-s c inv">C</text>
    <rect x="336" y="212" width="64" height="64" rx="14" fill="#FBBF24" class="tile-ink"/>
    <circle cx="388" cy="264" r="13" fill="#F472B6" class="tile-ink"/><text x="388" y="269" class="mono-s c">P</text>
  </g>
  <g class="pills">
    <rect x="82" y="290" width="60" height="18" rx="9"/><text x="112" y="303" class="mono-s c">Work</text>
    <rect x="210" y="290" width="60" height="18" rx="9"/><text x="240" y="303" class="mono-s c">Client</text>
    <rect x="334" y="290" width="68" height="18" rx="9"/><text x="368" y="303" class="mono-s c">Personal</text>
  </g>
  <text x="240" y="332" class="lbl c">label ≤ 14 ch · avatar ← Local State</text>
</svg>`;

/** Fig 02c — Teletransporte */
export const figTeleport = `
<svg viewBox="0 0 480 360" class="fig" role="img" aria-hidden="true">
  ${reg(24, 24)}${reg(456, 24)}${reg(24, 336)}${reg(456, 336)}
  <rect x="80" y="40" width="320" height="180" class="scr"/>
  <rect x="140" y="232" width="200" height="112" class="scr"/>
  <rect x="104" y="64" width="176" height="112" class="win-a"/>
  <rect x="104" y="64" width="176" height="12" class="win-bar"/>
  <rect x="152" y="252" width="110" height="70" class="win-b"/>
  <path d="M192 120 C 192 200, 207 230, 207 287" class="trace"/>
  <path d="M201 279l6 9 6-9" class="trace-head"/>
  <path d="M104 186h176M104 182v8M280 182v8" class="dim"/>
  <text x="192" y="202" class="lbl c">relW 0.550</text>
  <path d="M152 330h110M152 326v8M262 326v8" class="dim"/>
  <text x="300" y="300" class="lbl">≥ 0.35</text>
  <g class="kc"><rect x="372" y="250" width="64" height="44" rx="6"/><text x="404" y="278" class="mono-k c">⌃W</text></g>
  <text x="240" y="30" class="lbl c">size → position → size (AX)</text>
</svg>`;

/** Fig 03 — Wireframe arquitectónico del Panel de Control 4.0.6 (respaldo) */
export const panelWireframe = (title: string) => `
<svg viewBox="0 0 1200 760" class="wire" role="img" aria-label="${title}">
  <defs>
    <pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
      <path d="M0 0v6" class="hatch"/>
    </pattern>
  </defs>
  <rect x="40" y="30" width="1120" height="700" rx="14" class="w-frame"/>
  <path d="M40 74h1120" class="w-line"/>
  <circle cx="68" cy="52" r="6" class="w-dot"/><circle cx="88" cy="52" r="6" class="w-dot"/><circle cx="108" cy="52" r="6" class="w-dot"/>
  <text x="600" y="57" class="w-t c">StackDock — Control Panel 4.0.6</text>
  <path d="M280 74v656" class="w-line"/>
  <g class="w-side">
    <rect x="56" y="96" width="208" height="30" rx="6" class="w-sel"/>
    <text x="72" y="116">Displays</text><text x="72" y="156">Dock</text><text x="72" y="196">Profiles</text>
    <text x="72" y="236">Files</text><text x="72" y="276">Shortcuts</text><text x="72" y="316">Privacy &amp; License</text>
  </g>
  <!-- ① mapa -->
  <rect x="320" y="100" width="480" height="260" rx="10" class="w-box"/>
  <rect x="420" y="124" width="280" height="140" rx="4" class="w-scr"/>
  <rect x="470" y="272" width="180" height="64" rx="4" class="w-scr"/>
  <rect x="520" y="244" width="80" height="12" rx="4" class="w-dock"/>
  <rect x="530" y="316" width="60" height="10" rx="3" class="w-dock"/>
  <g class="w-chips"><rect x="336" y="124" width="64" height="22" rx="11"/><rect x="336" y="154" width="64" height="22" rx="11" class="on"/><rect x="336" y="184" width="64" height="22" rx="11"/><rect x="336" y="214" width="64" height="22" rx="11"/></g>
  <g class="w-s"><text x="368" y="139" class="c">BTM</text><text x="368" y="169" class="c">ELEV</text><text x="368" y="199" class="c">TOP</text><text x="368" y="229" class="c">AUTO</text></g>
  <!-- ② solo / dual -->
  <rect x="830" y="100" width="290" height="90" rx="10" class="w-box"/>
  <rect x="852" y="132" width="246" height="34" rx="8" class="w-seg"/>
  <rect x="856" y="136" width="119" height="26" rx="6" class="w-seg-on"/>
  <text x="915" y="154" class="w-s c">SOLO</text><text x="1036" y="154" class="w-s c">DUAL</text>
  <!-- ③ perfiles -->
  <rect x="830" y="210" width="290" height="200" rx="10" class="w-box"/>
  <g class="w-rows">
    <circle cx="864" cy="250" r="12" fill="#10B981"/><rect x="888" y="244" width="120" height="10" rx="5"/><rect x="1060" y="242" width="40" height="16" rx="8" class="tog"/>
    <circle cx="864" cy="290" r="12" fill="#6366F1"/><rect x="888" y="284" width="96" height="10" rx="5"/><rect x="1060" y="282" width="40" height="16" rx="8" class="tog"/>
    <circle cx="864" cy="330" r="12" fill="#F472B6"/><rect x="888" y="324" width="108" height="10" rx="5"/><rect x="1060" y="322" width="40" height="16" rx="8" class="tog"/>
    <rect x="852" y="360" width="24" height="24" rx="5" fill="url(#hatch)" class="w-hb"/><rect x="888" y="368" width="140" height="8" rx="4"/>
  </g>
  <!-- ④ Findaro -->
  <rect x="320" y="380" width="480" height="110" rx="10" class="w-box"/>
  <rect x="344" y="406" width="56" height="56" rx="12" class="w-tile"/><rect x="416" y="406" width="56" height="56" rx="12" class="w-tile"/>
  <path d="M372 424v18M364 434l8 8 8-8" class="w-ico"/><path d="M432 424h24M436 428l2 22h16l2-22" class="w-ico"/>
  <text x="496" y="428" class="w-s">OPEN WITH</text>
  <rect x="496" y="438" width="180" height="28" rx="6" class="w-seg"/><text x="512" y="457" class="w-t">Findaro  ▾</text>
  <!-- ⑤ atajos -->
  <rect x="320" y="510" width="480" height="200" rx="10" class="w-box"/>
  <g class="w-keys"><rect x="344" y="540" width="84" height="56" rx="8"/><rect x="444" y="540" width="84" height="56" rx="8"/></g>
  <text x="386" y="575" class="w-k c">⌥D</text><text x="486" y="575" class="w-k c">⌃W</text>
  <text x="552" y="562" class="w-s">SHOW / HIDE DOCKS</text><text x="552" y="584" class="w-s">MOVE · MIN 35 %</text>
  <rect x="344" y="624" width="432" height="8" rx="4" class="w-track"/><rect x="344" y="624" width="151" height="8" rx="4" class="w-fill"/>
  <path d="M495 616v24" class="w-mark"/><text x="495" y="664" class="w-s c">0.35</text>
  <!-- ⑥ privacidad -->
  <rect x="830" y="430" width="290" height="280" rx="10" class="w-box"/>
  <g class="w-s">
    <text x="852" y="468">SCREEN RECORDING</text><text x="1098" y="468" class="r">0</text>
    <path d="M852 482h246" class="w-line"/>
    <text x="852" y="508">ACCESSIBILITY</text><text x="1098" y="508" class="r">GRANTED</text>
    <path d="M852 522h246" class="w-line"/>
    <text x="852" y="548">LICENSE</text><text x="1098" y="548" class="r">Ed25519 · OFFLINE</text>
    <path d="M852 562h246" class="w-line"/>
    <text x="852" y="588">NETWORK</text><text x="1098" y="588" class="r">UPDATE FEED</text>
  </g>
  <rect x="852" y="616" width="246" height="70" rx="8" fill="url(#hatch)" class="w-hb"/>
</svg>`;
