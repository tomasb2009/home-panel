import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Metadata for a room that groups a set of lights.
class RoomInfo {
  const RoomInfo(this.name, this.icon);
  final String name;
  final IconData icon;
}

/// A single controllable light. On/off only — the target hardware does not
/// support dimming. Pure in-memory mock: when real hardware arrives, only the
/// data source behind [LightsModel] needs to change.
class LightDevice {
  LightDevice({
    required this.id,
    required this.name,
    required this.room,
    this.icon = Symbols.lightbulb,
    this.isOn = false,
  });

  final String id;
  final String name;
  final String room;
  final IconData icon;
  bool isOn;
}

/// Smart-lighting state for the home. The three device ids (living, comedor,
/// patio) match the areas the voice assistant controls, so commands and the
/// panel stay perfectly in sync. When real hardware arrives, only the data
/// source behind this model needs to change.
class LightsModel extends ChangeNotifier {
  static const List<RoomInfo> rooms = [
    RoomInfo('Sala de estar', Symbols.weekend),
    RoomInfo('Patio trasero', Symbols.deck),
  ];

  final List<LightDevice> devices = [
    LightDevice(id: 'living', name: 'Living', room: 'Sala de estar', icon: Symbols.weekend, isOn: false),
    LightDevice(id: 'comedor', name: 'Comedor', room: 'Sala de estar', icon: Symbols.restaurant, isOn: false),
    LightDevice(id: 'patio', name: 'Patio', room: 'Patio trasero', icon: Symbols.deck, isOn: false),
  ];

  List<LightDevice> byRoom(String room) =>
      devices.where((d) => d.room == room).toList(growable: false);

  int get onCount => devices.where((d) => d.isOn).length;
  int get total => devices.length;

  int roomOnCount(String room) => byRoom(room).where((d) => d.isOn).length;

  bool roomAllOn(String room) {
    final list = byRoom(room);
    return list.isNotEmpty && list.every((d) => d.isOn);
  }

  LightDevice _find(String id) => devices.firstWhere((d) => d.id == id);

  void toggle(String id) {
    final d = _find(id);
    d.isOn = !d.isOn;
    notifyListeners();
  }

  /// Sets a single light by id (used by the voice assistant). No-op if the id
  /// is unknown or the state is already the requested one.
  void setDevice(String id, bool on) {
    for (final d in devices) {
      if (d.id == id) {
        if (d.isOn == on) return;
        d.isOn = on;
        notifyListeners();
        return;
      }
    }
  }

  void setRoom(String room, bool on) {
    for (final d in byRoom(room)) {
      d.isOn = on;
    }
    notifyListeners();
  }

  void allOff() {
    for (final d in devices) {
      d.isOn = false;
    }
    notifyListeners();
  }

  void allOn() {
    for (final d in devices) {
      d.isOn = true;
    }
    notifyListeners();
  }

  /// Interior off, patio on — safe lighting for the night.
  void nightMode() {
    for (final d in devices) {
      d.isOn = d.room == 'Patio trasero';
    }
    notifyListeners();
  }
}
