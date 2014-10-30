import 'package:polymer/polymer.dart';
import 'package:color_picker/color_picker.dart' as picklib;
import 'dart:html';
import 'api.dart';

@CustomTag('color-picker')
class ColorPicker extends PolymerElement {
  
  picklib.HsvGradientPicker _picker;
  picklib.HueSlider _hueSlider;
  
  Element _viewPortContainer;
  int _width;
  int _height;
  Node _currentPickNode;
  
  @published String label = "";
  @published ColorRgb color = new ColorRgb(0,0,0);
  
  int get _diameter {
    if (_width == 0) return 300; // default
    return _width;
  }
  
  int get _slider_width {
    int dia = _diameter;
    return 20;
  }
  
  bool _pickColorEquals(picklib.ColorValue lhs, picklib.ColorValue rhs) {
    if (lhs.r != rhs.r) return false;
    if (lhs.g != rhs.g) return false;
    if (lhs.b != rhs.b) return false;
    return true;
  }
  
  set _currentColor(ColorRgb newColor) {
    var nc = _colorToPicklib(newColor);
    if (_pickColorEquals(_picker.color, nc)) return;
    _picker.color = nc;
    _hueSlider.hueAngle = _picker.hue;
  }
  
  ColorRgb get _currentColor => _colorToApi(_picker.color);
  
  ColorRgb _colorToApi(picklib.ColorValue c) {
    return new ColorRgb(c.r, c.g, c.b);
  }
  
  picklib.ColorValue _colorToPicklib(ColorRgb c) {
    return new picklib.ColorValue.fromRGB(c.r, c.g, c.b);
  }

  ColorPicker.created() : super.created() {
    this.changes.listen((records) {
      records.forEach((PropertyChangeRecord record) {
        if (record.name == #color && record.newValue != null) {
          _currentColor = record.newValue;
        }
      });
    });
  }
  
  void onColorChanged(picklib.ColorValue color, num hue, num saturation, num brightness) {
    var newColor = _colorToApi(color);
    if (newColor == this.color) return; 
    this.color = newColor;
    this.fire("color-change", detail: { 'newColor': newColor});
  }
  
  void createPicker() {
    if (_currentPickNode != null) {
      _viewPortContainer.nodes.remove(_currentPickNode);
    }
    _picker = null;
    _hueSlider = null;
    _currentPickNode = null;
    
    int swidth = _slider_width;
    int pwidth = _diameter - swidth;
    _picker = new picklib.HsvGradientPicker(pwidth, pwidth, _colorToPicklib(color));
    _hueSlider = new picklib.HueSlider(swidth, pwidth);
    _picker.colorChangeListener = onColorChanged;
    _hueSlider.hueChangelistener = _picker;
    _hueSlider.hueAngle = _picker.hue;
    
    DivElement element = new DivElement();
    element.attributes["horizontal"] = "";
    element.attributes["layout"] = "";
    element.attributes["margin"] = "0";
    element.attributes["padding"] = "0";
    element.attributes["width"] = "100%";
    element.attributes["height"] = "100%";
    element.classes.add("color-picker");

    element.nodes.add(_picker.canvas);
    element.nodes.add(_hueSlider.canvas);

    // Add a dummy element in the end to clear the floats from the previous elements
    var dummyElement = new DivElement();
    dummyElement.style.clear = "both";
    element.nodes.add(dummyElement);
        
    _viewPortContainer.nodes.add(element);
    _currentPickNode = element;
    
  }
  
  @override
  void attached() {
    super.attached();
    
    _viewPortContainer = shadowRoot.querySelector("#container");
    _width = _viewPortContainer.clientWidth;
    _height = _viewPortContainer.clientHeight;
    createPicker();
        
    window.onResize.listen(resizecontainer);
  }
  
  void resizecontainer(Event e){
    int wpWidth = _viewPortContainer.clientWidth;
    int wpHeight = _viewPortContainer.clientHeight;
    if (wpWidth == _width && wpHeight == _height) return;
    _width = wpWidth;
    _height = wpHeight;
    
    createPicker();
  }
}

