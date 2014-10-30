import 'package:polymer/polymer.dart';
import 'package:core_elements/core_selector.dart';
import 'package:paper_elements/paper_input.dart';
import 'package:paper_elements/paper_toggle_button.dart';
import 'package:collection/collection.dart';

import 'dart:async';
import 'dart:html';

import 'color_picker.dart' show ColorPicker;
import 'api.dart' show Api, ColorRgb, ScriptParameter;

@CustomTag('script-view')
class ScriptView extends PolymerElement {
  @observable bool isActive = false;
  @observable String activeScriptName = "";
  @observable List<String> availableScripts = toObservable(new List<String>());
  @observable List<ScriptParameter> parameters = toObservable(new List<ScriptParameter>());

  CoreSelector _scriptSelector;
  PaperToggleButton _activeButton;
  Api _api = null;
  @observable ColorRgb col = new ColorRgb(100, 100, 0);

  ScriptView.created() : super.created() {
    _scriptSelector = this.shadowRoot.getElementById("selector") as CoreSelector;
    _activeButton = this.shadowRoot.getElementById("activeButton") as PaperToggleButton;
    _api = new Api();

    _api.stateChanged.forEach((_) {
      isActive = _api.isActive;

      availableScripts.clear();
      _api.availableScripts.forEach((e) {
        availableScripts.add(e.name);
      });

      var e = new IterableEquality();
      bool paramEqual = e.equals(parameters, _api.activeScript.parameters.values);
      if (!paramEqual) {
        parameters.clear();
        _api.activeScript.parameters.forEach((pname, p) {
          parameters.add(p);
        });
      }

      activeScriptName = _api.activeScript.name;
    });
  }

  void setScriptToName(Event ev, dynamic details, Node target) {
    var s = _scriptSelector.selected;
    if (s == null || s == "") return;
    _api.setActiveScript(s);
  }

  void handleColorChange(Event ev, dynamic details, Node target) {
    ColorPicker input = ev.target as ColorPicker;
    var typename = input.label;

    for (var p in parameters) {
      if (p.name == typename && p.type == "ColorRgb") {
        p.currentValue = input.color;
        _api.setActiveScript(activeScriptName, parameters);
        break;
      }
    }
  }

  void handleInputChange(Event ev, dynamic details, Node target) {
    if (ev == null || ev.type != "change") return;
    EventTarget input = ev.target;

    if (input is PaperInput) {
      //var input = target as PaperInput;
      var typename = input.label;
      var value = input.value;

      for (var p in parameters) {
        if (p.name == typename) {
          if (p.type == "int") {
            try {
              p.currentValue = int.parse(input.value);
            } catch (e) {
              input.inputValue = p.currentValue.toString();
              return;
            }
          } else if (p.type == "double") {
            try {
              p.currentValue = double.parse(input.value);
            } catch (e) {
              input.inputValue = p.currentValue.toString();
              return;
            }
          }
          _api.setActiveScript(activeScriptName, parameters);
          break;
        }
      }
    }
  }

  void stopLight() {
    if (!isActive) return;
    _api.stopLight().then((_) {
    }).catchError((_) {
    });
  }
}
