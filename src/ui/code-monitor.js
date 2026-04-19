// 生成された夜景のパラメータと統計を表示する情報パネル
// (元は Ruby コードを表示していたが、AST 廃止に伴い InfoPanel 化)
export class CodeMonitor {
  constructor(el) {
    this.el = el;
  }

  showInfo(params, stats) {
    this.el.replaceChildren();
    const lines = [
      `# hakodate night view`,
      ``,
      `seed      : "${params.seed || '<random>'}"`,
      `density   : ${params.density}`,
      `chaos     : ${params.chaos_rate}%`,
      `waist     : depth=${params.max_depth} (${stats.waistWidth}px)`,
      ``,
      `# generated`,
      `lights    : ${stats.lightCount}`,
      `anchors   : ${stats.anchorCount}`,
      `horizon_y : ${stats.horizonY}`,
    ];
    for (const line of lines) {
      const div = document.createElement('div');
      div.className = 'info-line';
      div.textContent = line;
      this.el.appendChild(div);
    }
  }

  clear() {
    this.el.replaceChildren();
  }
}
