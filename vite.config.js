import { defineConfig } from 'vite';

export default defineConfig({
  // 相対パスにすることで GitHub Pages (repo-name サブディレクトリ) でも
  // ローカル (vite preview) でも同じ build 成果物で動く
  base: './',
  assetsInclude: ['**/*.wasm'],
  server: {
    // 開発サーバ (ローカル) 用。Ruby.wasm が SharedArrayBuffer を使う場合の保険。
    // GitHub Pages ではこのヘッダは設定できないが、@ruby/wasm-wasi 2.7 系は
    // 単一スレッド動作なので無くても動く。
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },
});
