import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:lib_colors/lib_colors.dart';

const RGB_MAX = 255.0;
const HUE_MAX = 360.0;
const SV_MAX = 100.0;
const pointerHalfSize = 10;

@Component(
  selector: 'color-picker',
  templateUrl: 'color_picker.html',
  styleUrls: [ 'color_picker.scss.css' ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  directives: [
    coreDirectives,
    MaterialFabComponent,
    MaterialIconComponent,
    MaterialRippleComponent
  ]
)
class ColorPickerComponent implements OnInit {
  final StreamController<Rgb> _rgbChange = StreamController<Rgb>();

  Hsv _currentHsv;

  Rgb _rgb;
  @Input()
  set rgb(Rgb value) {
    _rgb = value;
  }
  Rgb get rgb => _rgb;

  @Output()
  Stream<Rgb> get rgbChange => _rgbChange.stream;

  String _css;
  String get css => _css;

  String _hueCss;
  String get hueCss => _hueCss;

  String _huePos;
  String get huePos => _huePos;

  String _alphaPos;
  String get alphaPos => _alphaPos;

  String _saturationLeft;
  String get saturationLeft => _saturationLeft;

  String _saturationTop;
  String get saturationTop => _saturationTop;

  Hsv _hsv;

  @ViewChild('hue')
  DivElement hue;

  @ViewChild('saturation')
  DivElement saturation;

  @ViewChild('alpha')
  DivElement alpha;

  @ViewChild('saturationRipple')
  MaterialRippleComponent saturationRipple;

  @ViewChild('selectedRipple')
  MaterialRippleComponent selectedRipple;

  Rectangle _hueRect, _saturationRect;

  Hsv RGBtoHSV(Rgb rgb) {
    // It converts [0,255] format, to [0,1]
    final r = (rgb.r == RGB_MAX) ? 1 : (rgb.r % RGB_MAX / (RGB_MAX));
    final g = (rgb.g == RGB_MAX) ? 1 : (rgb.g % RGB_MAX / (RGB_MAX));
    final b = (rgb.b == RGB_MAX) ? 1 : (rgb.b % RGB_MAX / (RGB_MAX));
    final max = math.max(math.max(r, g), b);
    final min = math.min(math.min(r, g), b);
    final d = max - min;
    final v = max;
    final s = max == 0 ? 0 : d / max;
    num h;

    if (max == min) {
      h = 0; // achromatic
    } else {
      if (max == r) {
        h = (g - b) / d + (g < b ? 6 : 0);
      } else if (max == g) {
        h = (b - r) / d + 2;
      } else if (max == b) {
        h = (r - g) / d + 4;
      }

      h /= 6;
    }

    return Hsv(
        h: h,
        s: (s * SV_MAX).round(),
        v: (v * SV_MAX).round()
    );
  }

  void saturationMove(MouseEvent event) {
    _saturationRect ??= saturation.getBoundingClientRect();
    final posX = event.page.x - _saturationRect.left;
    final s = posX / _saturationRect.width;
    final posY = event.page.y - _saturationRect.top;
    final v = posY / _saturationRect.height;

    _saturationLeft = '${posX - pointerHalfSize}px';
    _saturationTop = '${posY - pointerHalfSize}px';

    _hsv = Hsv(
        h: (_hsv ?? RGBtoHSV(_rgb)).h,
        s: math.max(s, -0) * SV_MAX,
        v: (1 - math.max(v, -0)) * SV_MAX,
    );

    _css = _hsv.clone(a: rgb.a).css;
  }

  void hueClick(MouseEvent event) {
    click(event);
    _currentHsv = _hsv.clone(a: 1);
  }

  void click(MouseEvent event, {bool ripple = true}) {
    rgb = (_hsv.clone(a: rgb.a)).toRgb;
    _rgbChange.add(rgb);

    if (ripple) {
      saturationRipple.createRipple(event.client.x, event.client.y);
    }

    selectedRipple.createRipple(event.client.x, event.client.y);
  }

  @HostListener('mouseout', [r'$event'])
  void sliderOut(MouseEvent event) {
    clear();
  }

  @HostListener('mousemove', [r'$event'])
  void checkOut(MouseEvent event) {
    if (_hueRect != null && ![saturation, hue, alpha].contains(event.target)) {
      clear();
    }
  }

  void hueMove(MouseEvent event) {
    _hueRect ??= hue.getBoundingClientRect();
    final pos = event.page.x - _hueRect.left;
    final v = pos / _hueRect.width;

    _huePos = '${pos - pointerHalfSize}px';
    _hsv = Hsv(h: math.max(v, -0), s: 100, v: 100);
    _calcSaturationPos();

    _hueCss = _hsv.css;
    _css = _hsv.clone(a: rgb.a).css;
  }

  void alphaClick(MouseEvent event) {
    rgb = alphaMove(event);
    _rgbChange.add(rgb);
  }

  Rgb alphaMove(MouseEvent event) {
    _hueRect ??= hue.getBoundingClientRect();
    final pos = event.page.x - _hueRect.left;
    final a = pos / _hueRect.width;

    _alphaPos = '${pos - pointerHalfSize}px';

    final h2 = _rgb.clone(a: math.min(math.max(a, 0), 1));

    _css = h2.css;

    return h2;
  }

  void _calcSaturationPos() {
    final srect = saturation.getBoundingClientRect();

    _saturationLeft = '${((_hsv.s / SV_MAX) * srect.width) - pointerHalfSize}px';
    _saturationTop = '${((1 - (_hsv.v / SV_MAX)) * srect.height) - pointerHalfSize}px';
  }

  void clear() {
    final rgb = _rgb.clone(a: 1);
    final width = (_hueRect ?? hue.getBoundingClientRect()).width;

    _hsv = RGBtoHSV(rgb);

    _calcSaturationPos();
    _huePos = '${(_hsv.h * width) - pointerHalfSize}px';
    _alphaPos = '${(_rgb.a * width) - pointerHalfSize}px';
    _css = _rgb.css;
    _hueCss = (_currentHsv ?? _hsv).css;
    _hueRect = null;
  }

  @override
  void ngOnInit() {
    rgb ??= Rgb(r: 140, g: 50, b: 10, a: 1);
    _currentHsv = RGBtoHSV(_rgb.clone(a: 1));
    clear();
  }
}