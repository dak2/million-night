export class Controls {
  constructor() {
    this.shape      = document.getElementById('shape');
    this.sky        = document.getElementById('sky');
    this.waist      = document.getElementById('waist');
    this.density    = document.getElementById('density');
    this.chaos      = document.getElementById('chaos');
    this.asymmetry  = document.getElementById('asymmetry');
    this.foreground = document.getElementById('foreground');
    this.mountain   = document.getElementById('mountain');
    this.stars      = document.getElementById('stars');
    this.starBright = document.getElementById('star-bright');
    this.seed       = document.getElementById('seed');
    this.generate   = document.getElementById('generate');
  }

  values() {
    return {
      shape:       this.shape.value,
      sky:         this.sky.value,
      waist:       parseInt(this.waist.value, 10),
      density:     parseInt(this.density.value, 10),
      chaos_rate:  parseInt(this.chaos.value, 10),
      asymmetry:   parseInt(this.asymmetry.value, 10),
      foreground:  parseInt(this.foreground.value, 10),
      mountain:    parseInt(this.mountain.value, 10),
      stars:       parseInt(this.stars.value, 10),
      star_bright: parseInt(this.starBright.value, 10),
      seed:        this.seed.value.trim(),
    };
  }

  onGenerate(handler) {
    this.generate.addEventListener('click', handler);
  }
}
