import { DefaultRubyVM } from '@ruby/wasm-wasi/dist/browser';
import { Renderer } from './canvas/renderer.js';
import { Controls } from './ui/controls.js';

import hakodateRb from './ruby/hakodate.rb?raw';
import appRb      from './ruby/app.rb?raw';

const statusEl = document.getElementById('status');
const setStatus = (s) => { if (statusEl) statusEl.textContent = s; };

// パラメータパネルの開閉トグル
function setupControlsToggle() {
  const btn = document.getElementById('controls-toggle');
  if (!btn) return;

  const KEY = 'million-night.controls-hidden';
  const saved = localStorage.getItem(KEY) === '1';
  const labelEl = btn.querySelector('.toggle-label');
  const apply = (hidden) => {
    document.body.classList.toggle('controls-hidden', hidden);
    btn.setAttribute('aria-expanded', hidden ? 'false' : 'true');
    if (labelEl) labelEl.textContent = hidden ? 'Open' : 'Close';
  };
  apply(saved);

  btn.addEventListener('click', () => {
    const willHide = !document.body.classList.contains('controls-hidden');
    apply(willHide);
    localStorage.setItem(KEY, willHide ? '1' : '0');
  });
}

// ライブ反映するビジュアル系コントロール (scene 再生成不要、CSS 変数で即反映)
function setupVisualControls() {
  const saturation = document.getElementById('saturation');
  const brightness = document.getElementById('brightness');
  const contrast   = document.getElementById('contrast');
  const hue        = document.getElementById('hue');
  const bgColor    = document.getElementById('bg-color');

  const apply = () => {
    // :root に設定することで html/body/stage すべてに反映される
    const root = document.documentElement.style;
    root.setProperty('--sat', `${saturation.value}%`);
    root.setProperty('--bri', `${brightness.value}%`);
    root.setProperty('--con', `${contrast.value}%`);
    root.setProperty('--hue', `${hue.value}deg`);
    root.setProperty('--bg-color', bgColor.value);
  };

  for (const el of [saturation, brightness, contrast, hue, bgColor]) {
    el.addEventListener('input', apply);
  }
  apply();
}

async function bootRuby() {
  const wasmUrl = 'https://cdn.jsdelivr.net/npm/@ruby/3.3-wasm-wasi@2.7.0/dist/ruby+stdlib.wasm';
  setStatus('LOADING RUBY.WASM...');
  const wasmBin = await (await fetch(wasmUrl)).arrayBuffer();
  setStatus('COMPILING...');
  const module = await WebAssembly.compile(wasmBin);
  const { vm } = await DefaultRubyVM(module);

  setStatus('INITIALIZING...');
  vm.eval([
    'require "json"',
    hakodateRb,
    appRb,
  ].join("\n"));
  return vm;
}

function generateScene(vm, width, height, params) {
  const paramsJson  = JSON.stringify(params);
  const rubyLiteral = JSON.stringify(paramsJson);
  const script = `
    __mn_params = JSON.parse(${rubyLiteral}, symbolize_names: true)
    __mn_scene  = App.generate_scene(width: ${width}, height: ${height}, params: __mn_params)
    JSON.generate(__mn_scene)
  `;
  const result = vm.eval(script);
  return JSON.parse(result.toString());
}

async function main() {
  setupControlsToggle();
  setupVisualControls();

  const controls = new Controls();
  const canvas   = document.getElementById('night-canvas');
  const renderer = new Renderer(canvas);

  controls.generate.disabled = true;
  controls.generate.textContent = 'Loading...';

  let vm;
  try {
    vm = await bootRuby();
    setStatus('');
    controls.generate.disabled = false;
    controls.generate.textContent = 'Generate';
  } catch (err) {
    console.error(err);
    setStatus(`BOOT ERROR: ${err.message}`);
    controls.generate.textContent = 'Error';
    return;
  }

  controls.onGenerate(() => {
    const params = controls.values();
    setStatus('GENERATING...');
    controls.generate.disabled = true;

    // setTimeout で DOM 更新を先行させる (重い同期処理前に UI を反映)
    setTimeout(() => {
      try {
        const t0 = performance.now();
        const scene = generateScene(vm, canvas.width, canvas.height, params);
        renderer.renderScene(scene);
        const ms = (performance.now() - t0).toFixed(0);
        setStatus(`${scene.lights.length} LIGHTS · ${ms}ms`);
      } catch (err) {
        console.error(err);
        setStatus(`ERROR: ${err.message}`);
      } finally {
        controls.generate.disabled = false;
      }
    }, 20);
  });
}

main().catch(err => {
  console.error(err);
  setStatus(`FATAL: ${err.message}`);
});
