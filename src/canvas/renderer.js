import { getPreset, COMMON } from './palette.js';

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.width = canvas.width;
    this.height = canvas.height;
  }

  renderScene(scene) {
    const layout = scene.layout;
    const preset = getPreset(scene.sky_mode);

    this.drawSky(layout, preset);
    this.drawStars(scene.stars);
    this.drawFarMountain(scene.mountain, layout, preset);
    this.drawWater(layout, preset);
    this.drawWaterReflection(scene.water_reflections, preset);
    this.drawLand(scene.shoreline);
    this.drawShoreGlow(scene.shoreline, preset);
    this.drawLights(scene.lights);
    this.drawFlares(scene.flares);                  // カオス: 発光体
    this.drawAnchors(scene.anchors);
    this.drawGlitchBands(scene.glitch_bands);       // カオス: 走査線
    this.drawForeground(scene.foreground, layout);
    this.drawSpecialty(scene.specialty);
  }

  drawStars(stars) {
    if (!stars || stars.length === 0) return;
    const { ctx } = this;
    ctx.globalCompositeOperation = 'lighter';
    for (const s of stars) {
      ctx.globalAlpha = s.alpha;
      ctx.fillStyle = s.color;
      ctx.fillRect(s.x, s.y, s.size, s.size);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  // カオス発光体: 大小 3 層のグローで "爆発" や "ビーコン" のような強い光
  drawFlares(flares) {
    if (!flares || flares.length === 0) return;
    const { ctx } = this;
    ctx.globalCompositeOperation = 'lighter';
    for (const f of flares) {
      ctx.fillStyle = f.color + '20';
      ctx.beginPath();
      ctx.arc(f.x, f.y, f.radius * 4, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = f.color + '60';
      ctx.beginPath();
      ctx.arc(f.x, f.y, f.radius * 2, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = f.color;
      ctx.beginPath();
      ctx.arc(f.x, f.y, f.radius, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalCompositeOperation = 'source-over';
  }

  // グリッチ帯: 画面を横切る色の走査線 (CRT 故障のような効果)
  drawGlitchBands(bands) {
    if (!bands || bands.length === 0) return;
    const { ctx, width: W } = this;
    ctx.globalCompositeOperation = 'screen';
    for (const b of bands) {
      ctx.globalAlpha = b.alpha;
      ctx.fillStyle = b.color;
      ctx.fillRect(0, b.y, W, b.height);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  // 函館名産の隠し星座 (seed に "ika" / "goryokaku" 等を含むと発動)
  drawSpecialty(specialty) {
    if (!specialty) return;
    const { ctx } = this;
    ctx.globalCompositeOperation = 'lighter';
    for (const p of specialty.points) {
      // 3 層のグローで星のように輝かせる
      ctx.fillStyle = 'rgba(255, 235, 190, 0.12)';
      ctx.beginPath();
      ctx.arc(p.x, p.y, 6, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = 'rgba(255, 245, 210, 0.55)';
      ctx.beginPath();
      ctx.arc(p.x, p.y, 2.2, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = 'rgba(255, 255, 240, 0.95)';
      ctx.beginPath();
      ctx.arc(p.x, p.y, 0.9, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalCompositeOperation = 'source-over';
  }

  drawSky(layout, preset) {
    const { ctx, width: W } = this;
    const grad = ctx.createLinearGradient(0, 0, 0, layout.sky_end_y);
    for (const s of preset.sky) grad.addColorStop(s.stop, s.color);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, layout.sky_end_y);
  }

  drawFarMountain(points, layout, preset) {
    const { ctx, width: W } = this;
    const baseY = layout.horizon_y;

    ctx.fillStyle = preset.farMountain;
    ctx.beginPath();
    ctx.moveTo(0, baseY);
    for (const p of points) ctx.lineTo(p.x, p.y);
    ctx.lineTo(W, baseY);
    ctx.closePath();
    ctx.fill();

    ctx.strokeStyle = preset.farMountainLit;
    ctx.lineWidth = 1;
    ctx.globalAlpha = 0.4;
    ctx.beginPath();
    points.forEach((p, i) => {
      if (i === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    });
    ctx.stroke();
    ctx.globalAlpha = 1;
  }

  drawWater(layout, preset) {
    const { ctx, width: W, height: H } = this;
    const grad = ctx.createLinearGradient(0, layout.horizon_y, 0, H);
    for (const s of preset.water) grad.addColorStop(s.stop, s.color);
    ctx.fillStyle = grad;
    ctx.fillRect(0, layout.horizon_y, W, H - layout.horizon_y);
  }

  drawWaterReflection(bands, preset) {
    const { ctx, width: W } = this;
    ctx.globalCompositeOperation = 'lighter';
    for (const b of bands) {
      ctx.fillStyle = preset.reflection.replace('%a', b.alpha.toFixed(3));
      if (b.left_end != null && b.right_start != null) {
        ctx.fillRect(0, b.y, Math.max(0, b.left_end), 2);
        ctx.fillRect(b.right_start, b.y, Math.max(0, W - b.right_start), 2);
      } else {
        ctx.fillRect(0, b.y, W, 2);
      }
    }
    ctx.globalCompositeOperation = 'source-over';
  }

  drawLand(shoreline) {
    const { ctx } = this;
    if (!shoreline || shoreline.length === 0) return;
    ctx.fillStyle = COMMON.land;
    ctx.beginPath();
    ctx.moveTo(shoreline[0].left_x, shoreline[0].y);
    for (const p of shoreline) ctx.lineTo(p.left_x, p.y);
    for (let i = shoreline.length - 1; i >= 0; i--) ctx.lineTo(shoreline[i].right_x, shoreline[i].y);
    ctx.closePath();
    ctx.fill();
  }

  drawShoreGlow(shoreline, preset) {
    const { ctx } = this;
    ctx.fillStyle = preset.shoreGlow;
    const gw = 6;
    for (const p of shoreline) {
      ctx.fillRect(p.left_x - gw, p.y, gw, 2);
      ctx.fillRect(p.right_x, p.y, gw, 2);
    }
  }

  drawLights(lights) {
    const { ctx } = this;
    ctx.globalCompositeOperation = 'lighter';
    for (const l of lights) {
      ctx.globalAlpha = l.alpha;
      ctx.fillStyle = l.color;
      ctx.fillRect(l.x, l.y, l.size, l.size);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  drawAnchors(anchors) {
    const { ctx } = this;
    ctx.globalCompositeOperation = 'lighter';
    for (const a of anchors) {
      ctx.fillStyle = a.color + '30';
      ctx.beginPath();
      ctx.arc(a.x, a.y, a.radius * 5, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = a.color + '70';
      ctx.beginPath();
      ctx.arc(a.x, a.y, a.radius * 2, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = a.color;
      ctx.beginPath();
      ctx.arc(a.x, a.y, a.radius, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalCompositeOperation = 'source-over';
  }

  drawForeground(points, layout) {
    const { ctx, width: W, height: H } = this;
    ctx.fillStyle = COMMON.foreground;
    ctx.beginPath();
    ctx.moveTo(0, H);
    ctx.lineTo(0, layout.foreground_y + 30);
    for (const p of points) ctx.lineTo(p.x, p.y);
    ctx.lineTo(W, layout.foreground_y + 30);
    ctx.lineTo(W, H);
    ctx.closePath();
    ctx.fill();
  }
}
