// Simple DMA visualizer app.js
const playBtn = document.getElementById('playBtn');
const stepBtn = document.getElementById('stepBtn');
const pauseBtn = document.getElementById('pauseBtn');
const speedInput = document.getElementById('speed');
const eventsDiv = document.getElementById('events');
const stageText = document.getElementById('stage');
const themeBtn = document.getElementById('themeBtn');

// Theme toggle
function initTheme() {
  const savedTheme = localStorage.getItem('theme') || 'dark';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeBtn();
  updateArrowMarkers(savedTheme);
}

function updateArrowMarkers(theme) {
  const marker = theme === 'light' ? 'arrow-light' : 'arrow-dark';
  const paths = document.querySelectorAll('[marker-end*="arrow"]');
  paths.forEach(path => {
    path.setAttribute('marker-end', `url(#${marker})`);
  });
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme');
  const newTheme = current === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', newTheme);
  localStorage.setItem('theme', newTheme);
  updateThemeBtn();
  updateArrowMarkers(newTheme);
}

function updateThemeBtn() {
  const current = document.documentElement.getAttribute('data-theme');
  themeBtn.textContent = current === 'dark' ? '☀️ Light' : '🌙 Dark';
}

themeBtn.onclick = toggleTheme;
initTheme();

let timeline = [];
let tIndex = 0;
let playing = false;
let timer = null;
let speed = 1.0;

const svg = document.getElementById('arch');

function log(msg) { const el = document.createElement('div'); el.textContent = msg; eventsDiv.prepend(el); }

function setStage(text) {
  if (stageText) stageText.textContent = text;
}

function flash(id, dur=600) {
  const node = document.getElementById(id);
  if (!node) return;
  node.classList.add('flash');
  setTimeout(()=> node.classList.remove('flash'), dur);
}

function pulseLine(pathId, dur=800) {
  const p = document.getElementById(pathId);
  if (!p) return;
  p.classList.add('pulse-line');
  setTimeout(() => p.classList.remove('pulse-line'), dur);
}

function movePacketAlong(pathId, label, dur=800, isSram=false) {
  const path = document.getElementById(pathId);
  if (!path) return;
  const len = path.getTotalLength();
  const circle = document.createElementNS('http://www.w3.org/2000/svg','circle');
  circle.setAttribute('r', 8);
  circle.setAttribute('class', isSram ? 'packet-sram' : 'packet');
  svg.appendChild(circle);
  let start = null;
  function step(ts) {
    if (!start) start = ts;
    const t = (ts-start)/dur;
    if (t>1) {
      svg.removeChild(circle);
      return;
    }
    const pt = path.getPointAtLength(len * t);
    circle.setAttribute('cx', pt.x);
    circle.setAttribute('cy', pt.y);
    requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}

function handleEvent(ev) {
  log(`> ${ev.type} ${ev.payload || ''}`);
  
  if (ev.type === 'SOC_WRITE_CSR') {
    pulseLine('p_soc_csr', 400);
    movePacketAlong('p_soc_csr', '', 400);
    setTimeout(() => flash('csr', 600), 400);
  } 
  else if (ev.type === 'CSR_WRITE_RINGLEN') {
    pulseLine('p_soc_csr', 300);
    flash('csr', 450);
  }
  else if (ev.type === 'CSR_DOORBELL') {
    pulseLine('p_csr_ring', 450);
    movePacketAlong('p_csr_ring', '', 450);
    setTimeout(() => flash('ring', 450), 300);
  }
  else if (ev.type === 'RING_ISSUE_HANDLE') {
    pulseLine('p_ring_df_in', 350);
    movePacketAlong('p_ring_df_in', '', 350);
    setTimeout(() => flash('df_in_fifo', 500), 200);
  }
  else if (ev.type === 'DF_ACCEPT_HANDLE') {
    flash('desc', 500);
    flash('df_in_fifo', 500);
  }
  else if (ev.type === 'DF_FETCH_DESCRIPTOR') {
    pulseLine('p_ring_desc', 550);
    movePacketAlong('p_ring_desc', '', 550);
    setTimeout(() => flash('desc', 500), 250);
    setTimeout(() => flash('df_out_fifo', 500), 450);
  }
  else if (ev.type === 'DF_ERROR_CHECK') {
    flash('desc', 500);
  }
  else if (ev.type === 'DF_DISPATCH_DM') {
    pulseLine('p_desc_df_out', 400);
    movePacketAlong('p_desc_df_out', '', 400);
    setTimeout(() => flash('df_out_fifo', 500), 200);
    setTimeout(() => flash('dataMover', 550), 300);
  }
  else if (ev.type === 'DM_DECODE') {
    flash('dataMover', 700);
  }
  else if (ev.type === 'DM_ROUTE_AXI') {
    pulseLine('p_dm_axi_fifo', 450);
    movePacketAlong('p_dm_axi_fifo', '', 450);
    setTimeout(() => flash('dm_axi_fifo', 550), 150);
    setTimeout(() => flash('axi', 550), 300);
  }
  else if (ev.type === 'DM_ROUTE_SRAM') {
    pulseLine('p_dm_sram_fifo', 450);
    movePacketAlong('p_dm_sram_fifo', '', 450, true);
    setTimeout(() => flash('dm_sram_fifo', 550), 150);
    setTimeout(() => flash('sram_ctrl', 550), 300);
  }
  else if (ev.type === 'CSR_NOTIFY_RING') {
    pulseLine('p_csr_ring', 500);
    movePacketAlong('p_csr_ring', '', 500);
    setTimeout(() => flash('ring', 600), 500);
  }
  else if (ev.type === 'RING_NOTIFY_DESC') {
    pulseLine('p_ring_desc', 600);
    movePacketAlong('p_ring_desc', '', 600);
    setTimeout(() => flash('desc', 600), 600);
  }
  else if (ev.type === 'DESC_FETCH_AXI') {
    pulseLine('p_desc_axi', 600);
    movePacketAlong('p_desc_axi', '', 600);
    setTimeout(() => flash('axi', 400), 600);
    setTimeout(() => {
      pulseLine('p_axi_sysmem', 400);
      movePacketAlong('p_axi_sysmem', '', 400);
      setTimeout(() => flash('sysmem', 400), 400);
    }, 600);
  }
  else if (ev.type === 'DESC_RETURN_AXI') {
    pulseLine('p_sysmem_axi', 400);
    movePacketAlong('p_sysmem_axi', '', 400);
    setTimeout(() => flash('axi', 400), 400);
  }
  else if (ev.type === 'DESC_NOTIFY_DM') {
    pulseLine('p_desc_dm', 400);
    movePacketAlong('p_desc_dm', '', 400);
    setTimeout(() => flash('dataMover', 600), 400);
  }
  else if (ev.type === 'AXI_READ_SYSMEM') {
    pulseLine('p_axi_sysmem', 400);
    movePacketAlong('p_axi_sysmem', '', 400);
    setTimeout(() => flash('sysmem', 450), 300);
  }
  else if (ev.type === 'AXI_FILL_MID') {
    pulseLine('p_axi_mid', 350);
    movePacketAlong('p_axi_mid', '', 350);
    setTimeout(() => flash('mid_fifo', 500), 150);
  }
  else if (ev.type === 'SRAM_WRITE_BRAM') {
    pulseLine('p_sramctrl_bram', 350);
    movePacketAlong('p_sramctrl_bram', '', 350, true);
    setTimeout(() => flash('bram', 600), 150);
  }
  else if (ev.type === 'DM_DONE') {
    flash('ring', 450);
    flash('irq', 450);
  }
  else if (ev.type === 'DM_READ_SYSMEM') {
    pulseLine('p_dm_axi', 400);
    movePacketAlong('p_dm_axi', '', 400);
    setTimeout(() => flash('axi', 400), 400);
    setTimeout(() => pulseLine('p_axi_sysmem', 400), 600);
    setTimeout(() => movePacketAlong('p_axi_sysmem', '', 400), 600);
    setTimeout(() => flash('sysmem', 500), 1000);
  }
  else if (ev.type === 'DM_WRITE_SRAM') {
    pulseLine('p_sysmem_axi', 400);
    movePacketAlong('p_sysmem_axi', '', 400);
    setTimeout(() => pulseLine('p_dm_sram_ctrl', 400), 400);
    setTimeout(() => movePacketAlong('p_dm_sram_ctrl', '', 400), 400);
    setTimeout(() => flash('sram_ctrl', 400), 800);
    setTimeout(() => {
      pulseLine('p_sramctrl_sram', 400);
      movePacketAlong('p_sramctrl_sram', '', 400, true);
      flash('sram', 600);
    }, 1200);
  }
}

// Built-in DMA Demo workflow, split into step-by-step internal DMA stages
timeline = [
  { type: 'SOC_WRITE_CSR', payload: 'Write BASEADDR' },
  { type: 'CSR_WRITE_RINGLEN', payload: 'Write RINGLEN' },
  { type: 'CSR_DOORBELL', payload: 'Enable and ring doorbell' },
  { type: 'RING_ISSUE_HANDLE', payload: 'Ring manager issues descriptor handle' },
  { type: 'DF_ACCEPT_HANDLE', payload: 'Descriptor fetcher accepts handle' },
  { type: 'DF_FETCH_DESCRIPTOR', payload: 'Descriptor fetcher reads descriptor' },
  { type: 'DF_ERROR_CHECK', payload: 'Bounds and length check' },
  { type: 'DF_DISPATCH_DM', payload: 'Descriptor forwarded to data mover' },
  { type: 'DM_DECODE', payload: 'Data mover decodes direction and length' },
  { type: 'DM_ROUTE_AXI', payload: 'Queue AXI-side instruction' },
  { type: 'AXI_READ_SYSMEM', payload: 'AXI master reads system memory' },
  { type: 'AXI_FILL_MID', payload: 'Fill mid FIFO' },
  { type: 'DM_ROUTE_SRAM', payload: 'Queue SRAM-side instruction' },
  { type: 'SRAM_WRITE_BRAM', payload: 'SRAM controller writes BRAM' },
  { type: 'DM_DONE', payload: 'Movement completes and IRQ updates' }
];

function stepTimeline() {
  if (tIndex >= timeline.length) { 
    pause(); 
    tIndex = 0; // loop back
    setStage('Completed. Click Step to replay.');
    return; 
  }
  const ev = timeline[tIndex++];
  setStage(`Step ${tIndex}/${timeline.length}: ${ev.payload}`);
  handleEvent(ev);
}

function play() {
  if (playing) return;
  playing = true;
  timer = setInterval(stepTimeline, 2000 / speed);
  stepTimeline(); // do first immediately
}

function pause() { playing=false; clearInterval(timer); }

playBtn.onclick = play;
stepBtn.onclick = () => { if (playing) pause(); stepTimeline(); };
pauseBtn.onclick = pause;
speedInput.oninput = (e)=> { speed = parseFloat(e.target.value); if (playing) { pause(); play(); } };

setStage('Ready');
log('Press Step or Play Demo!');
