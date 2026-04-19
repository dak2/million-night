module Hakodate
  class Generator
    SHAPES = %w[hakodate peninsula island bay straight].freeze
    SKY_MODES = %w[sunset night dawn].freeze

    LIGHT_COLORS  = ["#ff9a3d", "#ffae5c", "#ffbe7a", "#ffd096", "#ff8030", "#ffe4b8"].freeze
    ANCHOR_COLORS = ["#fff2d0", "#ffe0a8", "#ffd890"].freeze
    # カオス時に混入する「異常な色」
    CHAOS_COLORS  = ["#ff2855", "#ff44aa", "#44ddff", "#88ff44", "#aa44ff", "#ffee22", "#ff5500"].freeze
    FLARE_COLORS  = ["#ff4020", "#ff9030", "#ffff80", "#ff66dd", "#66ddff"].freeze

    def initialize(width:, height:, params:)
      @width  = width.to_f
      @height = height.to_f
      @params = params
      @rng    = Random.new(seed_to_int(params[:seed]))
    end

    def generate
      layout   = make_layout
      center_x = @width / 2 + (@rng.rand - 0.5) * @width * 0.06

      {
        layout:            layout,
        sky_mode:          sky_mode,
        shape:             shape,
        center_x:          center_x,
        waist_width:       (@width * waist_tightness).round,
        horizon_y:         layout[:horizon_y].round,
        mountain:          mountain_points(layout),
        stars:             scatter_stars(layout),
        shoreline:         shoreline_samples(layout, center_x),
        water_reflections: water_reflection_bands(layout, center_x),
        lights:            scatter_lights(layout, center_x),
        anchors:           place_anchors(layout, center_x),
        flares:            scatter_flares(layout, center_x),
        glitch_bands:      scatter_glitch_bands(layout),
        foreground:        foreground_points(layout),
        specialty:         specialty_constellation(layout),
      }
    end

    private

    def shape
      s = (@params[:shape] || "hakodate").to_s
      SHAPES.include?(s) ? s : "hakodate"
    end

    def sky_mode
      s = (@params[:sky] || "sunset").to_s
      SKY_MODES.include?(s) ? s : "sunset"
    end

    def seed_to_int(seed)
      return (Random.new_seed & 0xFFFFFFFF) if seed.nil? || seed.to_s.empty?
      h = 2166136261
      seed.to_s.each_byte do |b|
        h ^= b
        h = (h * 16777619) & 0xFFFFFFFF
      end
      h
    end

    def make_layout
      h = @height
      # foreground が大きいほど陸地エリアの下端を上げる (= 前景山が大きくなる)
      fg = (@params[:foreground] || 20).to_f / 100  # 0..0.5
      foreground_y = h * (0.92 - fg * 0.40)

      # 空を画面の ~45% まで広く取る。水平線も合わせて下げる。
      sky_end_y = h * 0.45
      horizon_y = h * 0.47

      # 水平線〜前景境界の間を陸地エリアとし、くびれ/先端を比率で再計算
      land_range = foreground_y - horizon_y

      {
        sky_end_y:    sky_end_y,
        horizon_y:    horizon_y,
        mainland_y:   horizon_y,
        waist_y:      horizon_y + land_range * 0.33,
        tip_y:        horizon_y + land_range * 0.72,
        land_end_y:   foreground_y,
        foreground_y: foreground_y,
        width:        @width,
        height:       h,
      }
    end

    # -------- 形状ディスパッチ --------
    def land_width_at(y, layout)
      case shape
      when "hakodate"  then hakodate_width(y, layout)
      when "peninsula" then peninsula_width(y, layout)
      when "island"    then island_width(y, layout)
      when "bay"       then bay_width(y, layout)
      when "straight"  then straight_width(y, layout)
      end
    end

    def in_range?(y, layout)
      y >= layout[:mainland_y] && y <= layout[:foreground_y]
    end

    def hakodate_width(y, layout)
      return 0 unless in_range?(y, layout)
      mainland_y = layout[:mainland_y]
      waist_y    = layout[:waist_y]
      tip_y      = layout[:tip_y]
      fg_y       = layout[:foreground_y]
      w          = layout[:width]
      wt = waist_tightness

      if y <= waist_y
        t = (y - mainland_y) / (waist_y - mainland_y)
        lerp(w * 0.88, w * wt, smoothstep(t))
      elsif y <= tip_y
        t = (y - waist_y) / (tip_y - waist_y)
        lerp(w * wt, w * 0.72, smoothstep(t))
      else
        t = (y - tip_y) / (fg_y - tip_y)
        lerp(w * 0.72, w * 0.18, smoothstep(t))
      end
    end

    def peninsula_width(y, layout)
      return 0 unless in_range?(y, layout)
      mainland_y = layout[:mainland_y]
      fg_y       = layout[:foreground_y]
      w          = layout[:width]
      t = (y - mainland_y) / (fg_y - mainland_y)
      lerp(w * 0.88, w * waist_tightness, smoothstep(t))
    end

    def island_width(y, layout)
      return 0 unless in_range?(y, layout)
      mainland_y = layout[:mainland_y]
      fg_y       = layout[:foreground_y]
      w          = layout[:width]
      t = (y - mainland_y) / (fg_y - mainland_y)
      envelope = Math.sin(t * Math::PI)
      w * 0.82 * envelope
    end

    def bay_width(y, layout)
      return 0 unless in_range?(y, layout)
      mainland_y = layout[:mainland_y]
      fg_y       = layout[:foreground_y]
      w          = layout[:width]
      t = (y - mainland_y) / (fg_y - mainland_y)
      lerp(w * waist_tightness, w * 0.88, smoothstep(t))
    end

    def straight_width(y, layout)
      return 0 unless in_range?(y, layout)
      layout[:width] * 0.65
    end

    def waist_tightness
      lerp(0.20, 0.04, (@params[:waist].to_f - 1) / 9.0)
    end

    # -------- 海岸線 (非対称対応) --------
    def shoreline_at(y, layout, center_x)
      width = land_width_at(y, layout)
      return nil if width.nil? || width <= 0

      asymm = (@params[:asymmetry] || 0).to_f / 100
      # y に応じて中心をゆっくり揺らす (正弦波で有機的な海岸線に)
      phase = Math.sin(y * 0.012 + 1.7) * asymm * 0.4
      cx = center_x + phase * width

      { left_x: cx - width / 2, right_x: cx + width / 2, width: width }
    end

    def shoreline_samples(layout, center_x)
      samples = 80
      pts = []
      (0..samples).each do |i|
        y = layout[:mainland_y] + (layout[:foreground_y] - layout[:mainland_y]) * i / samples
        sl = shoreline_at(y, layout, center_x)
        pts << { y: y, left_x: sl[:left_x], right_x: sl[:right_x] } if sl
      end
      pts
    end

    # -------- 遠景の山 --------
    def mountain_points(layout)
      base_y     = layout[:horizon_y]
      w          = @width
      steps      = 60
      prominence = (@params[:mountain] || 14).to_f / 14.0
      amp        = 22.0 * prominence

      (0..steps).map do |i|
        x = w * i / steps
        n = Math.sin(i * 0.3 + @rng.rand * 2) * amp +
            Math.sin(i * 0.85) * amp * 0.4 +
            (@rng.rand - 0.5) * 5
        y = base_y - 6 + n * 0.5
        { x: x, y: y }
      end
    end

    # -------- 海面反射 --------
    def water_reflection_bands(layout, center_x)
      bands = 8
      result = []
      bands.times do |i|
        y = layout[:horizon_y] + (layout[:land_end_y] - layout[:horizon_y]) * (i.to_f / bands) * 0.6
        sl = shoreline_at(y, layout, center_x)
        alpha = 0.04 + @rng.rand * 0.03
        result << {
          y:           y,
          left_end:    sl && sl[:left_x] - 2,
          right_start: sl && sl[:right_x] + 2,
          alpha:       alpha,
        }
      end
      result
    end

    # -------- 街明かり (棄却サンプリング) --------
    def chaos_level
      (@params[:chaos_rate] || 0).to_f / 100
    end

    # 座標のカオス変換: 反転/回転/入れ替え/ワープ など幾何学的な混沌
    def chaos_transform(x, y, layout)
      case @rng.rand(7)
      when 0  # 水平反転 (左右入れ替え)
        [@width - x, y]
      when 1  # 垂直反転 (上下入れ替え、陸地範囲内)
        [x, layout[:mainland_y] + (layout[:foreground_y] - y)]
      when 2  # 180度回転 (点対称)
        [@width - x, @height - y]
      when 3  # 完全ランダムワープ (空や海のどこにでも飛ぶ)
        [@rng.rand * @width, @rng.rand * @height]
      when 4  # XY 入れ替え (x と y を交換、縦横比で補正)
        [(y / @height) * @width, (x / @width) * @height]
      when 5  # 対角反射 (y=x 的な鏡映)
        [y * @width / @height, x * @height / @width]
      else    # 反対象限へ弾き飛ばす
        cx = @width / 2.0
        cy = @height / 2.0
        [cx + (cx - x) * (0.6 + @rng.rand * 0.8),
         cy + (cy - y) * (0.6 + @rng.rand * 0.8)]
      end
    end

    def scatter_lights(layout, center_x)
      target = @params[:density].to_i * 600
      c = chaos_level
      # カオスを複数の効果に配分:
      skip_rate        = c * 0.20  # 暗部 (控えめ、他に余力を残す)
      jitter           = c * 25    # 位置のブレ (px)
      coord_chaos_rate = c * 0.40  # 座標変換の発動率 (最大 40%)
      color_chaos_rate = [0, c - 0.15].max * 0.6  # chaos 15% 以降に色の変異

      lights = []
      attempts = 0
      max_attempts = target * 4

      while lights.length < target && attempts < max_attempts
        attempts += 1

        y = layout[:mainland_y] + @rng.rand * (layout[:foreground_y] - layout[:mainland_y])
        sl = shoreline_at(y, layout, center_x)
        next if sl.nil? || sl[:width] <= 1

        r = @rng.rand * 2 - 1
        biased = (r <=> 0) * (r.abs ** 1.08)
        x = (sl[:left_x] + sl[:right_x]) / 2 + biased * sl[:width] * 0.48

        next if @rng.rand < skip_rate

        # 微細な位置ブレ
        if jitter > 0
          x += (@rng.rand - 0.5) * jitter
          y += (@rng.rand - 0.5) * jitter
        end

        # 座標カオス: 一定確率で幾何学的変換を適用
        if @rng.rand < coord_chaos_rate
          x, y = chaos_transform(x, y, layout)
        end

        # 画面の遥か外に飛んだ光は捨てる (描画負荷軽減)
        next if x < -20 || x > @width + 20 || y < -20 || y > @height + 20

        edge_fade = [1.0, (layout[:foreground_y] - y).abs / 40.0].min
        depth_t   = ((y - layout[:mainland_y]).abs / (layout[:foreground_y] - layout[:mainland_y])).clamp(0, 1)
        alpha     = (0.55 + depth_t * 0.4) * edge_fade

        size = @rng.rand < 0.12 ? 2 : 1

        # 色のカオス: 暖色パレットから異常色パレットへ跳躍
        color = if color_chaos_rate > 0 && @rng.rand < color_chaos_rate
          CHAOS_COLORS[@rng.rand(CHAOS_COLORS.length)]
        else
          LIGHT_COLORS[@rng.rand(LIGHT_COLORS.length)]
        end

        lights << {
          x:     x.round,
          y:     y.round,
          size:  size,
          alpha: alpha,
          color: color,
        }
      end
      lights
    end

    def place_anchors(layout, center_x)
      count = 8 + @rng.rand(6)
      anchors = []
      count.times do
        y = layout[:mainland_y] + @rng.rand * (layout[:foreground_y] - layout[:mainland_y] - 40)
        sl = shoreline_at(y, layout, center_x)
        next if sl.nil?
        x = sl[:left_x] + @rng.rand * sl[:width]
        anchors << {
          x:      x.round,
          y:      y.round,
          radius: 1.5 + @rng.rand * 2,
          color:  ANCHOR_COLORS[@rng.rand(ANCHOR_COLORS.length)],
        }
      end
      anchors
    end

    # -------- 前景 (函館山シルエット) --------
    def foreground_points(layout)
      w     = @width
      h     = @height
      steps = 30
      fg_prominence = (@params[:foreground] || 20).to_f / 20.0

      (0..steps).map do |i|
        x     = w * i / steps
        u     = i.to_f / steps
        arc   = Math.sin(u * Math::PI) * h * 0.10 * fg_prominence
        noise = (@rng.rand - 0.5) * 10 + Math.sin(i * 0.8) * 6
        y     = layout[:foreground_y] + 10 - arc + noise
        { x: x, y: y }
      end
    end

    # -------- カオスの追加効果 --------
    # 発光体 (fires/explosions/ビーコン): 画面のどこにでも出現
    def scatter_flares(layout, center_x)
      c = chaos_level
      return [] if c < 0.15
      count = ((c - 0.10) * 28).round
      flares = []
      count.times do
        # カオスが高いほど完全ランダム位置、低いと陸地寄り
        if @rng.rand < c
          x = @rng.rand * @width
          y = @rng.rand * @height
        else
          y = layout[:mainland_y] + @rng.rand * (layout[:foreground_y] - layout[:mainland_y])
          sl = shoreline_at(y, layout, center_x)
          next if sl.nil?
          x = sl[:left_x] + @rng.rand * sl[:width]
        end
        flares << {
          x:      x.round,
          y:      y.round,
          radius: 3 + @rng.rand * 6,
          color:  FLARE_COLORS[@rng.rand(FLARE_COLORS.length)],
        }
      end
      flares
    end

    # 水平方向のグリッチ帯: 画面を横切る色の走査線
    def scatter_glitch_bands(layout)
      c = chaos_level
      return [] if c < 0.40
      count = ((c - 0.35) * 25).round
      bands = []
      count.times do
        y = @rng.rand * @height
        bands << {
          y:      y.round,
          height: 1 + @rng.rand(4),
          color:  CHAOS_COLORS[@rng.rand(CHAOS_COLORS.length)],
          alpha:  0.3 + @rng.rand * 0.5,
          offset: ((@rng.rand - 0.5) * 120).round,  # 画素ずらし量 (将来使う)
        }
      end
      bands
    end

    # -------- 星空 (パラメータ連動) --------
    def scatter_stars(layout)
      count = (@params[:stars] || 0).to_i * 5   # 0..500
      brightness_scale = (@params[:star_bright] || 50).to_f / 50.0  # 0..2
      return [] if count <= 0

      sky_area = layout[:sky_end_y] * 0.92
      stars = []
      count.times do
        x     = @rng.rand * @width
        y     = @rng.rand * sky_area
        size  = @rng.rand < 0.08 ? 2 : 1
        alpha = ((0.2 + @rng.rand * 0.75) * brightness_scale).clamp(0.0, 1.0)
        color = case @rng.rand(12)
                when 0..8 then "#ffffff"
                when 9    then "#aec6ff"  # 青白い星
                else         "#ffe6c7"    # 暖色の星
                end
        stars << { x: x.round, y: y.round, size: size, alpha: alpha, color: color }
      end
      stars
    end

    # -------- 名産品の隠し星座 (特定 seed で発動) --------
    SPECIALTY_TRIGGERS = {
      goryokaku: %w[goryokaku star 五稜郭],
      ika:       %w[ika squid イカ いか],
      uni:       %w[uni ウニ うに urchin],
      kani:      %w[kani カニ かに crab],
    }.freeze

    def specialty_constellation(layout)
      seed_key = (@params[:seed] || "").to_s.downcase
      return nil if seed_key.empty?

      kind = SPECIALTY_TRIGGERS.each_pair do |key, triggers|
        break key if triggers.any? { |t| seed_key.include?(t.downcase) }
      end
      return nil unless kind.is_a?(Symbol)

      cx = @width * 0.72
      cy = @height * 0.12
      r  = @width * 0.055

      points = case kind
               when :goryokaku then star_points(cx, cy, r)
               when :ika       then ika_points(cx, cy, r)
               when :uni       then uni_points(cx, cy, r)
               when :kani      then kani_points(cx, cy, r)
               end
      { type: kind.to_s, points: points }
    end

    def star_points(cx, cy, r)
      vertices = []
      10.times do |i|
        angle = -Math::PI / 2 + i * Math::PI / 5
        radius = i.even? ? r : r * 0.45
        vertices << [cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius]
      end
      dense_outline(vertices, 5)
    end

    IKA_NORMALIZED = [
      [ 0.00, -1.00],  # 頭頂
      [-0.14, -0.75],
      [-0.22, -0.45],
      [-0.26, -0.15],
      [-0.55,  0.12],  # 左ヒレ
      [-0.38,  0.22],
      [-0.15,  0.28],
      [-0.22,  0.55],  # 左触腕
      [-0.15,  0.90],
      [-0.05,  0.55],
      [ 0.00,  0.98],  # 中央触腕
      [ 0.05,  0.55],
      [ 0.15,  0.90],  # 右触腕
      [ 0.22,  0.55],
      [ 0.15,  0.28],
      [ 0.38,  0.22],
      [ 0.55,  0.12],  # 右ヒレ
      [ 0.26, -0.15],
      [ 0.22, -0.45],
      [ 0.14, -0.75],
    ].freeze

    def ika_points(cx, cy, r)
      vertices = IKA_NORMALIZED.map { |nx, ny| [cx + nx * r * 0.95, cy + ny * r] }
      dense_outline(vertices, 2)
    end

    def uni_points(cx, cy, r)
      result = []
      # 本体
      16.times do |i|
        a = 2 * Math::PI * i / 16
        result << { x: (cx + Math.cos(a) * r * 0.5).round, y: (cy + Math.sin(a) * r * 0.5).round }
      end
      # トゲ
      12.times do |i|
        a = 2 * Math::PI * i / 12
        [0.58, 0.72, 0.86, 1.0].each do |t|
          result << { x: (cx + Math.cos(a) * r * t).round, y: (cy + Math.sin(a) * r * t).round }
        end
      end
      result
    end

    def kani_points(cx, cy, r)
      result = []
      # 甲羅
      14.times do |i|
        a = 2 * Math::PI * i / 14
        result << { x: (cx + Math.cos(a) * r * 0.6).round, y: (cy + Math.sin(a) * r * 0.35).round }
      end
      # 左右のハサミと脚
      [
        [-0.8, -0.25], [-1.1, -0.4], [-1.25, -0.6], [-0.95, -0.55],
        [ 0.8, -0.25], [ 1.1, -0.4], [ 1.25, -0.6], [ 0.95, -0.55],
        [-0.5, 0.3], [-0.7, 0.5], [-0.85, 0.65],
        [-0.3, 0.4], [-0.5, 0.6], [-0.6, 0.75],
        [ 0.5, 0.3], [ 0.7, 0.5], [ 0.85, 0.65],
        [ 0.3, 0.4], [ 0.5, 0.6], [ 0.6, 0.75],
      ].each do |nx, ny|
        result << { x: (cx + nx * r).round, y: (cy + ny * r).round }
      end
      result
    end

    # ポリライン輪郭を内分して「密な星座」にする
    def dense_outline(vertices, per_segment)
      result = []
      vertices.each_with_index do |v, i|
        nxt = vertices[(i + 1) % vertices.length]
        per_segment.times do |j|
          t = j.to_f / per_segment
          x = v[0] + (nxt[0] - v[0]) * t
          y = v[1] + (nxt[1] - v[1]) * t
          result << { x: x.round, y: y.round }
        end
      end
      result
    end

    def lerp(a, b, t)
      a + (b - a) * t
    end

    def smoothstep(t)
      t = 0.0 if t < 0
      t = 1.0 if t > 1
      t * t * (3 - 2 * t)
    end
  end
end
