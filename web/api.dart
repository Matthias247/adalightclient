import 'dart:html';
import 'dart:convert';
import 'dart:async';

class ColorRgb {
  int r;
  int g;
  int b;
  
  ColorRgb(this.r, this.g, this.b);
  ColorRgb.clone(ColorRgb rhs) {
    r = rhs.r;
    g = rhs.g;
    b = rhs.b;
  }
  
  bool operator==(ColorRgb other) {
    if (r != other.r) return false;
    if (g != other.g) return false;
    if (b != other.b) return false;
    return true;
  }
  
  int get hashCode => r ^ g ^ b;
  
  ColorRgb dim(double factor) {
    return new ColorRgb((r * factor) as int, (g * factor) as int, (b * factor) as int);
  }
  
  static int _valFromChar(String c) {
      int a = c.codeUnitAt(0);
      if (a >= '0'.codeUnitAt(0) && a <= '9'.codeUnitAt(0)) {
          return (a - '0'.codeUnitAt(0));
      }
      else if (a >= 'a'.codeUnitAt(0) && a <= 'f'.codeUnitAt(0)) {
          return 10 + (a - 'a'.codeUnitAt(0));
      }
      else if (a >= 'A'.codeUnitAt(0) && a <= 'F'.codeUnitAt(0)) {
          return 10 + (a - 'A'.codeUnitAt(0));
      }
      else throw new Exception();
  }
  
  ColorRgb.parseColor(String colorStr) {
    if (colorStr == null || colorStr.length != 6)
      throw new Exception();
    
    r = (_valFromChar(colorStr[0]) << 4) + _valFromChar(colorStr[1]);
    g = (_valFromChar(colorStr[2]) << 4) + _valFromChar(colorStr[3]);
    b = (_valFromChar(colorStr[4]) << 4) + _valFromChar(colorStr[5]);
    
    if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255)
      throw new Exception();
  }
  
  String toHexString() {
    String s = "";
    if (r < 0x10) s += "0";
    s += r.toRadixString(16);
    if (g < 0x10) s += "0";
    s += g.toRadixString(16);
    if (b < 0x10) s += "0";
    s += b.toRadixString(16);
    return s;
  }
}

class ScriptParameter {
  String name;
  String type;
  dynamic defaultValue = null;
  dynamic currentValue = null;
  
  ScriptParameter.clone(ScriptParameter rhs) {
    name = rhs.name;
    type = rhs.type;
    defaultValue = rhs.defaultValue;
    currentValue = rhs.currentValue;
  }
  
  bool typeEquals(ScriptParameter other) {
    return (name == other.name) && (type == other.type);
  }
  
  bool operator==(ScriptParameter other) {
    if (name != other.name) return false;
    if (type != other.type) return false;
    if (defaultValue != other.defaultValue) return false;
    if (currentValue != other.currentValue) return false;
    return true;
  }
  
  int get hashCode {
    int result = 0;
    if (name != null) result ^= name.hashCode;
    if (type != null) result ^= type.hashCode;
    if (defaultValue != null) result ^= defaultValue.hashCode;
    if (currentValue != null) result ^= currentValue.hashCode;
    return result;
  }
  
  ScriptParameter.fromMap(Map m) {
    name = m["name"];
    type = m["type"];
    defaultValue = m["default"];
    currentValue = m["current"];
    if (!(name is String) || !(type is String) || defaultValue == null)
      throw new Exception();
    
    if (type == "ColorRgb") {
      defaultValue = new ColorRgb.parseColor(defaultValue);
      if (currentValue != null) currentValue = new ColorRgb.parseColor(currentValue);
    }
  }
  
  String get currentValStr {
    if (type == "int" || type == "double") 
      return "$name=$currentValue";
    else if (type == "ColorRgb")
      return "$name=${(currentValue as ColorRgb).toHexString()}";
    return "";
  }
  
  String get currentValAsStr {
    if (type == "int" || type == "double") 
      return "$currentValue";
    else if (type == "ColorRgb")
      return "${(currentValue as ColorRgb).toHexString()}";
    return "";
  }
}

class ScriptInformation {
  String name;
  Map<String, ScriptParameter> parameters;
  
  static ScriptInformation empty = new ScriptInformation("", new Map<String, ScriptParameter>());
  
  ScriptInformation(this.name, this.parameters);
  
  ScriptInformation.clone(ScriptInformation rhs) {
    name = rhs.name;
    parameters = new Map<String, ScriptParameter>();
    rhs.parameters.forEach((k,v) {
      parameters[k] = new ScriptParameter.clone(v); 
    });
  }
  
  ScriptInformation.fromMap(Map m) {
    name = m["name"];
    if (!(name is String)) throw new Exception();
    this.parameters = new Map<String, ScriptParameter>();
    List plist = m["parameters"];
    plist.forEach((elem) {
      ScriptParameter param = new ScriptParameter.fromMap(elem);
      parameters[param.name] = param;
    });
  }
}

class WebSocketConnection {
  
  
  Future<WebSocketConnection> create() {
    Completer c = new Completer();
    
    return c.future;
  }
}

class Api {
  
  static String WS_PATH = "ws://127.0.0.1:8081/ws";
  
  String _mode = "none";
  bool get isActive => _mode != "none";
  
  ScriptInformation _activeScript = ScriptInformation.empty;
  ScriptInformation get activeScript => _activeScript;
  
  List<ScriptInformation> _availableScripts = new List<ScriptInformation>();
  List<ScriptInformation> get availableScripts => _availableScripts;
  
  WebSocket _ws = null;
  
  int _nextReqId = 0;
  Map<int, Completer> _requestMap = new Map();
  
  StreamController _stateChangedStream = new StreamController();
  Timer _reconnectTimer = null;
    
  Api() {
    _initWebSocket();
  }
  
  Stream get stateChanged => _stateChangedStream.stream;
  
  int get _nextRequestId {
    int ret = _nextReqId;
    _nextReqId++;
    if (_nextReqId > 9007199254740992) {
      _nextReqId = 0;
    }
    return ret;
  }
  
  String _makeRequestContent(Completer completer, String method, Map data) {
    Map content = new Map();
    int id = _nextRequestId;
    _requestMap[id] = completer;
    content["id"] = id;
    content["type"] = "rq";
    content["method"] = method;
    content["data"] = data;
    return JSON.encode(content);
  }
  
  Future _makeWebSocketRequest(String methodName, Map data) {
    Completer c = new Completer();
    if (_ws == null || _ws.readyState != WebSocket.OPEN) {
      c.completeError(new Exception("Not connected"));
      return c.future;
    }
    
    _ws.send(_makeRequestContent(c, methodName, data));
    return c.future;
  }
  
  Future stopLight() {
    return _makeWebSocketRequest("stop", null);
  }
  
  Future getState() {
    return _makeWebSocketRequest("getState", null);
  }
  
  Future getCurrentScript() {
    return _makeWebSocketRequest("getCurrentScript", null);
  }
  
  Future getScripts() {
    return _makeWebSocketRequest("getScripts", null);
  }
  
  Future setActiveScript(String scriptName, [List<ScriptParameter> parameters = null]) {
    Completer c = new Completer();
    if (scriptName == null || scriptName == "") {
      c.completeError("Invalid script name");
      return c.future;
    }
        
    Map data = new Map();
    data["name"] = scriptName;
    Map paramMap = new Map();
    data["parameters"] = paramMap;
    if (parameters != null) {
      parameters.forEach((p) {
        paramMap[p.name] = p.currentValAsStr;
      });
    }
    
    return _makeWebSocketRequest("setScript", data);
  }
  
  void _initWebSocket() {
    WebSocket newWs = new WebSocket(WS_PATH);
    newWs.onOpen.listen((e) {
      if (newWs != _ws) return;
      print("Connection established");
    });
    newWs.onClose.listen((e) {
      if (newWs != _ws) return;
      _ws = null;
      
      // Mark outstanding requests as failed
      for (Completer c in _requestMap.values) {
        c.completeError(new Exception("Connection closed"));
      }
      _requestMap.clear();
      
      // Clear the current state
      _setStateToDefaults();
      _stateChangedStream.add(null);
      // Schedule a reconnect
      if (_reconnectTimer == null) {
        _reconnectTimer = new Timer(new Duration(seconds: 3), () {
          _reconnectTimer = null;
          _initWebSocket();
        });
      }
    });
    newWs.onMessage.listen((MessageEvent e) {
      if (newWs != _ws) return;
      try {
        Map msg = JSON.decode(e.data);
        var type = msg["type"];
        if (type == "ev") { // Received an event
          var evname = msg["name"];
          var data = msg["data"];
          if (evname is String && data is Map)
            _handleEvent(evname, data);
        }
        else if (type == "rp") { // Received a response
          var id = msg["id"];
          var result = msg["result"];
          var error = msg["error"];
          if (id is int)
            _handleResponse(id, result, error);
        }
      }
      catch (e) {}
    });
    _ws = newWs;
  }
  
  void _setStateToDefaults() {
    _mode = "none";
    _activeScript = ScriptInformation.empty;
    _availableScripts.clear();
  }
  
  void _handleResponse(int id, dynamic result, dynamic error) {
    Completer c = _requestMap[id];
    if (c == null) return; // No such request
    _requestMap.remove(id);
    if (error != null) {
      c.completeError(error);
    }
    else {
      c.complete(result);
    }
    // else received neither result nor error
  }
  
  void _handleEvent(String name, Map data) {
    if (name == "stateChanged") {
      _handleGetState(data);
    }
  }
  
  void _handleGetState(Map newState) {
    _setStateToDefaults();
    
    if (newState.containsKey("mode")) {
      var a = newState["mode"];
      if (a is String) _mode = a;
    }
    
    if (newState.containsKey("active_script")) {
      try {
        ScriptInformation info = new ScriptInformation.fromMap(newState["active_script"]);
        _activeScript = info;
      }
      catch (e) {}
    }
    
    var scriptList = newState["available_scripts"];
    if (scriptList is List) {
      for (var elem in scriptList) {
        try {
          ScriptInformation info = new ScriptInformation.fromMap(elem);
          _availableScripts.add(info);
        }
        catch (e) {}
      }
    }
    
    _stateChangedStream.add(null);
  }
  
  void close() {
    if (_ws != null) _ws.close();
    _ws = null;
    if (_reconnectTimer != null) _reconnectTimer.cancel();
    _reconnectTimer = null;
    
    _setStateToDefaults();
    _stateChangedStream.add(null);
    _stateChangedStream.close();
  }
  
}

