const playBtn   = document.getElementById('playBtn');
const stepBtn   = document.getElementById('stepBtn');
const pauseBtn  = document.getElementById('pauseBtn');
const speedInput = document.getElementById('speed');
const eventsDiv = document.getElementById('events');
const stageText = document.getElementById('stage');
const themeBtn  = document.getElementById('themeBtn');
const svg       = document.getElementById('arch');

// ── Theme ────────────────────────────────────────────────────────────────────

function initTheme() {
  const saved = localStorage.getItem('theme') || 'dark';
  document.documentElement.setAttribute('data-theme', saved);
  updateThemeBtn();
}
function toggleTheme() {
  const cur = document.documentElement.getAttribute('data-theme');
  const next = cur === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
  updateThemeBtn();
}
function updateThemeBtn() {
  const cur = document.documentElement.getAttribute('data-theme');
  themeBtn.textContent = cur === 'dark' ? 'Light' : 'Dark';
}
themeBtn.onclick = toggleTheme;
initTheme();

// ── Helpers ──────────────────────────────────────────────────────────────────

function log(msg) {
  const el = document.createElement('div');
  el.textContent = msg;
  eventsDiv.prepend(el);
}

function setStage(text) {
  if (stageText) stageText.textContent = text;
}

function flash(id, dur = 650) {
  const node = document.getElementById(id);
  if (!node) return;
  node.classList.add('flash');
  setTimeout(() => node.classList.remove('flash'), dur);
}

function pulseLine(pathId, dur = 800) {
  const p = document.getElementById(pathId);
  if (!p) return;
  p.classList.add('pulse-line');
  setTimeout(() => p.classList.remove('pulse-line'), dur);
}

// Neon comet trail: head + 5 fading tail circles animated along path
// color: 'default' | 'sram' | 'dma'
function movePacket(pathId, dur = 600, color = 'default') {
  const path = document.getElementById(pathId);
  if (!path) return;
  const len = path.getTotalLength();

  const TRAIL = 5;
  const TRAIL_SPACING = 0.045;

  const headClass =
    color === 'sram' ? 'packet-sram' :
    color === 'dma'  ? 'packet-dma'  : 'packet';

  const glowColor =
    color === 'sram' ? 'rgba(255,102,255,' :
    color === 'dma'  ? 'rgba(245,196,0,'   : 'rgba(0,212,255,';

  const circles = [];
  for (let i = 0; i <= TRAIL; i++) {
    const c = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    if (i === 0) {
      c.setAttribute('r', 8);
      c.setAttribute('class', headClass);
    } else {
      const fade = 1 - i / (TRAIL + 1);
      const r = Math.max(2, 7 * fade);
      c.setAttribute('r', r);
      c.setAttribute('fill', '#fff');
      c.setAttribute('opacity', (fade * 0.75).toFixed(2));
      c.setAttribute('style',
        `filter: drop-shadow(0 0 ${Math.round(6 * fade)}px ${glowColor}${(fade * 0.8).toFixed(2)}))`
      );
    }
    svg.appendChild(c);
    circles.push(c);
  }

  let start = null;
  function tick(ts) {
    if (!start) start = ts;
    const t = (ts - start) / dur;
    if (t > 1) {
      circles.forEach(c => svg.removeChild(c));
      return;
    }
    circles.forEach((c, i) => {
      const tOffset = Math.max(0, t - i * TRAIL_SPACING);
      const pt = path.getPointAtLength(len * tOffset);
      c.setAttribute('cx', pt.x);
      c.setAttribute('cy', pt.y);
    });
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}

// ── Hardcoded 12-step DMA workflow ───────────────────────────────────────────

const STEPS = [
  'SoC Bus activates',                              // 0
  'CSR configured via AXI-Lite',                    // 1
  'Ring Manager receives doorbell',                 // 2
  'Descriptor Fetcher loads descriptor handle',     // 3
  'AXI4 Master fetches descriptor from memory',     // 4
  'System Memory returns descriptor data',          // 5
  'System Memory → AXI4 Master',                    // 6
  'AXI4 Master → Descriptor Fetcher',               // 7
  'Descriptor Fetcher → Data Mover',                // 8
  'Data Mover routes to AXI4 & SRAM Controller',   // 9  ← parallel
  'Writing to System Memory & SRAM',                // 10 ← parallel
  'DMA transfer: System Memory → SRAM',             // 11 ← dashed line + beam
];

let tIndex  = 0;
let playing = false;
let timer   = null;
let speed   = 1.0;

function runStep(idx) {
  const base = Math.round(500 / speed);
  const fast = Math.round(300 / speed);

  if (idx === 0) {
    flash('socBus', 800);

  } else if (idx === 1) {
    pulseLine('p_soc_csr', base + 100);
    movePacket('p_soc_csr', base);
    setTimeout(() => flash('csr', 700), base);

  } else if (idx === 2) {
    const dur = base + 300;
    pulseLine('p_csr_ring', dur + 100);
    movePacket('p_csr_ring', dur);
    setTimeout(() => flash('ring', 700), dur);

  } else if (idx === 3) {
    pulseLine('p_ring_desc', base + 100);
    movePacket('p_ring_desc', base);
    setTimeout(() => flash('desc', 700), base);

  } else if (idx === 4) {
    const dur = base + 400;
    pulseLine('p_df_axi', dur + 100);
    movePacket('p_df_axi', dur);
    setTimeout(() => flash('axi', 700), dur);

  } else if (idx === 5) {
    pulseLine('p_axi_sysmem', fast + 100);
    movePacket('p_axi_sysmem', fast);
    setTimeout(() => flash('sysmem', 700), fast);

  } else if (idx === 6) {
    // System Memory → AXI4 Master (reverse beam on same visible line)
    pulseLine('p_axi_sysmem', fast + 100);
    movePacket('p_sysmem_axi', fast);
    setTimeout(() => flash('axi', 700), fast);

  } else if (idx === 7) {
    // AXI4 Master → Descriptor Fetcher (reverse of p_df_axi)
    const dur = base + 400;
    pulseLine('p_df_axi', dur + 100);
    movePacket('p_axi_df', dur);
    setTimeout(() => flash('desc', 700), dur);

  } else if (idx === 8) {
    // Descriptor Fetcher → Data Mover
    pulseLine('p_desc_dm', base + 100);
    movePacket('p_desc_dm', base);
    setTimeout(() => flash('dataMover', 700), base);

  } else if (idx === 9) {
    // PARALLEL: Data Mover → AXI4 Master  AND  Data Mover → SRAM Controller
    const durAxi  = base + 200;
    const durSram = base + 500;
    pulseLine('p_axi_dm', durAxi + 100);
    movePacket('p_dm_axi', durAxi);
    pulseLine('p_dm_sram', durSram + 100);
    movePacket('p_dm_sram', durSram, 'sram');
    setTimeout(() => flash('axi',       700), durAxi);
    setTimeout(() => flash('sram_ctrl', 700), durSram);

  } else if (idx === 10) {
    // PARALLEL: AXI4 → System Memory  AND  SRAM Controller → SRAM
    pulseLine('p_axi_sysmem',    fast + 100);
    movePacket('p_axi_sysmem',   fast);
    pulseLine('p_sramctrl_sram', fast + 100);
    movePacket('p_sramctrl_sram', fast, 'sram');
    setTimeout(() => flash('sysmem', 700), fast);
    setTimeout(() => flash('sram',   700), fast);

  } else if (idx === 11) {
    // Dashed line turns yellow → marching banner → DMA transfer beam
    const bus = document.getElementById('p_dma_bus');
    if (bus) bus.classList.add('dma-active');

    const transferDur = base + 900;
    setTimeout(() => movePacket('p_dma_transfer', transferDur, 'dma'), 350);

    setTimeout(() => {
      flash('sysmem',    600);
      flash('axi',       400);
      flash('sram_ctrl', 400);
      flash('sram',      700);
    }, 350 + transferDur);
  }
}

function stepTimeline() {
  if (tIndex >= STEPS.length) {
    pause();
    tIndex = 0;
    const bus = document.getElementById('p_dma_bus');
    if (bus) bus.classList.remove('dma-active');
    setStage('Complete — click Step or Play to replay');
    return;
  }
  const label = STEPS[tIndex];
  setStage(`Step ${tIndex + 1} / ${STEPS.length}: ${label}`);
  log(`> ${label}`);
  runStep(tIndex);
  tIndex++;
}

function play() {
  if (playing) return;
  playing = true;
  const interval = Math.round(2200 / speed);
  timer = setInterval(stepTimeline, interval);
  stepTimeline();
}

function pause() { playing = false; clearInterval(timer); }

playBtn.onclick  = play;
pauseBtn.onclick = pause;
stepBtn.onclick  = () => { if (playing) pause(); stepTimeline(); };
speedInput.oninput = e => {
  speed = parseFloat(e.target.value);
  if (playing) { pause(); play(); }
};

setStage('Ready');
log('Press Step or Play Demo!');
