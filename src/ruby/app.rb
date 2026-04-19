# JS から呼ばれるエントリポイント
class App
  def self.generate_scene(width:, height:, params:)
    Hakodate::Generator.new(width: width, height: height, params: params).generate
  end
end
