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

/// Simulated smart-lighting state for the whole home.
class LightsModel extends ChangeNotifier {
  static const List<RoomInfo> rooms = [
    RoomInfo('Living', Symbols.weekend),
    RoomInfo('Cocina', Symbols.countertops),
    RoomInfo('Dormitorio', Symbols.bed),
    RoomInfo('Baño', Symbols.bathtub),
    RoomInfo('Exterior', Symbols.deck),
    RoomInfo('Garage', Symbols.garage),
  ];

  final List<LightDevice> devices = [
    LightDevice(id: 'l1', name: 'Techo', room: 'Living', isOn: true),
    LightDevice(id: 'l2', name: 'Lámpara de pie', room: 'Living', icon: Symbols.floor_lamp, isOn: true),
    LightDevice(id: 'l3', name: 'Luz TV', room: 'Living', icon: Symbols.tv, isOn: false),
    LightDevice(id: 'k1', name: 'Techo', room: 'Cocina', isOn: true),
    LightDevice(id: 'k2', name: 'Bajo mesada', room: 'Cocina', icon: Symbols.light, isOn: false),
    LightDevice(id: 'd1', name: 'Techo', room: 'Dormitorio', isOn: false),
    LightDevice(id: 'd2', name: 'Velador', room: 'Dormitorio', icon: Symbols.light, isOn: false),
    LightDevice(id: 'b1', name: 'Techo', room: 'Baño', isOn: false),
    LightDevice(id: 'e1', name: 'Frente', room: 'Exterior', icon: Symbols.wb_incandescent, isOn: true),
    LightDevice(id: 'e2', name: 'Jardín', room: 'Exterior', icon: Symbols.yard, isOn: false),
    LightDevice(id: 'g1', name: 'Techo', room: 'Garage', isOn: false),
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

  /// Everything off except the exterior, for safety at night.
  void nightMode() {
    for (final d in devices) {
      d.isOn = d.room == 'Exterior';
    }
    notifyListeners();
  }
}
