import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import 'team_chat_screen.dart';
import 'team_collab_repository.dart';

// ─── Edit Modes ──────────────────────────────────────────────────────────────

enum _MapEditMode {
  none,
  respawn,
  target,
  objective,
  waypoint,
  ammo,
  medic,
  bomb,
  terminal,
  extraction,
  route,
  zone,
  label,
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class TeamMapScreen extends StatefulWidget {
  const TeamMapScreen({super.key, required this.teamId, required this.teamName});
  final String teamId;
  final String teamName;
  @override
  State<TeamMapScreen> createState() => _TeamMapScreenState();
}

class _TeamMapScreenState extends State<TeamMapScreen> {
  final TeamCollabRepository _repository = TeamCollabRepository();
  final ImagePicker _picker = ImagePicker();

  TeamMapModel? _selectedMap;
  _MapEditMode _mode = _MapEditMode.none;
  bool _creatingMap = false;
  bool _savingRoute = false;

  final List<Map<String, double>> _routeDraft = <Map<String, double>>[];
  String? _routeLabel;
  final List<Map<String, double>> _zoneDraft = <Map<String, double>>[];
  String? _zoneLabel;
  List<TeamMapMarkerModel> _draftMarkers = <TeamMapMarkerModel>[];
  List<TeamMapRouteModel> _draftRoutes = <TeamMapRouteModel>[];
  List<TeamMapZoneModel> _draftZones = <TeamMapZoneModel>[];
  List<TeamMapMarkerModel> _remoteMarkers = <TeamMapMarkerModel>[];
  List<TeamMapRouteModel> _remoteRoutes = <TeamMapRouteModel>[];
  List<TeamMapZoneModel> _remoteZones = <TeamMapZoneModel>[];
  String? _draftMapId;
  bool _mapDirty = false;
  bool _savingMapDraft = false;

  String? _draggingMarkerId;
  double _dragX = 0;
  double _dragY = 0;

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  String _draftId() => 'draft_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(99999)}';

  void _syncDrafts(
    TeamMapModel map,
    List<TeamMapMarkerModel> markers,
    List<TeamMapRouteModel> routes,
    List<TeamMapZoneModel> zones,
  ) {
    _remoteMarkers = markers;
    _remoteRoutes = routes;
    _remoteZones = zones;
    if (_draftMapId == map.id && _mapDirty) {
      return;
    }
    _draftMapId = map.id;
    _draftMarkers = markers
        .map(
          (TeamMapMarkerModel marker) => TeamMapMarkerModel(
            id: marker.id,
            mapId: marker.mapId,
            markerType: marker.markerType,
            x: marker.x,
            y: marker.y,
            label: marker.label,
            colorHex: marker.colorHex,
            sizeScale: marker.sizeScale,
            createdBy: marker.createdBy,
          ),
        )
        .toList();
    _draftRoutes = routes
        .map(
          (TeamMapRouteModel route) => TeamMapRouteModel(
            id: route.id,
            mapId: route.mapId,
            points: route.points.map((Map<String, double> p) => Map<String, double>.from(p)).toList(),
            label: route.label,
            colorHex: route.colorHex,
            strokeWidth: route.strokeWidth,
            createdBy: route.createdBy,
          ),
        )
        .toList();
    _draftZones = zones
        .map(
          (TeamMapZoneModel zone) => TeamMapZoneModel(
            id: zone.id,
            mapId: zone.mapId,
            points: zone.points.map((Map<String, double> p) => Map<String, double>.from(p)).toList(),
            label: zone.label,
            colorHex: zone.colorHex,
            createdBy: zone.createdBy,
          ),
        )
        .toList();
    _mapDirty = false;
  }

  Future<void> _createMap() async {
    if (_creatingMap) return;
    final TextEditingController titleController = TextEditingController();
    final String? title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).createTacticalMap),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(labelText: AppLocalizations.of(ctx).mapTitle),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(ctx).t('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(titleController.text.trim()), child: const Text('Next')),
        ],
      ),
    );
    titleController.dispose();
    if (title == null || title.trim().isEmpty) return;
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    setState(() => _creatingMap = true);
    try {
      await _repository.createMap(teamId: widget.teamId, title: title, imageBytes: bytes, originalFilename: file.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('mapUploadFailed', args: {'error': e.toString()}))));
    } finally {
      if (mounted) setState(() => _creatingMap = false);
    }
  }

  Future<String?> _promptLabel(String hint) async {
    final TextEditingController c = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).t('addLabel')),
        content: TextField(controller: c, decoration: InputDecoration(hintText: hint), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(ctx).t('skip'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: Text(AppLocalizations.of(ctx).t('done'))),
        ],
      ),
    );
    c.dispose();
    return result;
  }

  Future<String?> _showColorPicker(String title) async {
    const List<(String label, String hex, Color color)> colors = [
      ('Red', 'F44336', Color(0xFFF44336)),
      ('Pink', 'E91E63', Color(0xFFE91E63)),
      ('Purple', '9C27B0', Color(0xFF9C27B0)),
      ('Blue', '2196F3', Color(0xFF2196F3)),
      ('Cyan', '00BCD4', Color(0xFF00BCD4)),
      ('Green', '4CAF50', Color(0xFF4CAF50)),
      ('Lime', '8BC34A', Color(0xFF8BC34A)),
      ('Yellow', 'FFEB3B', Color(0xFFFFEB3B)),
      ('Amber', 'FFC107', Color(0xFFFFC107)),
      ('Orange', 'FF9800', Color(0xFFFF9800)),
      ('Deep Orange', 'FF5722', Color(0xFFFF5722)),
      ('Brown', '795548', Color(0xFF795548)),
    ];

    String? selectedHex;
    await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map(((String label, String hex, Color color) item) {
              return GestureDetector(
                onTap: () {
                  selectedHex = item.$2;
                  Navigator.of(ctx).pop();
                },
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: item.$3,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(ctx).colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            item.$1.substring(0, 1),
                            style: TextStyle(
                              color: _isLightColor(item.$3) ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$1,
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).t('cancel')),
          ),
        ],
      ),
    );
    return selectedHex;
  }

  bool _isLightColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5;
  }

  Future<void> _showMarkerActions(TeamMapMarkerModel marker) async {
    if (marker.createdBy != _uid) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Change marker colour'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final String? colorHex = await _showColorPicker('Marker Colour');
                  if (colorHex == null) {
                    return;
                  }
                  final int index = _draftMarkers.indexWhere((TeamMapMarkerModel item) => item.id == marker.id);
                  if (index == -1) {
                    return;
                  }
                  setState(() {
                    _draftMarkers[index] = TeamMapMarkerModel(
                      id: _draftMarkers[index].id,
                      mapId: _draftMarkers[index].mapId,
                      markerType: _draftMarkers[index].markerType,
                      x: _draftMarkers[index].x,
                      y: _draftMarkers[index].y,
                      label: _draftMarkers[index].label,
                      colorHex: colorHex,
                      sizeScale: _draftMarkers[index].sizeScale,
                      createdBy: _draftMarkers[index].createdBy,
                    );
                    _mapDirty = true;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_full_outlined),
                title: const Text('Resize marker'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  double sizeScale = marker.sizeScale;
                  final bool? confirmed = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext ctx) => StatefulBuilder(
                      builder: (BuildContext ctx, void Function(void Function()) setLocalState) => AlertDialog(
                        title: const Text('Marker size'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: sizeScale,
                              min: 0.7,
                              max: 2.4,
                              divisions: 17,
                              label: sizeScale.toStringAsFixed(1),
                              onChanged: (double value) {
                                setLocalState(() => sizeScale = value);
                              },
                            ),
                            Text('Scale ${sizeScale.toStringAsFixed(1)}x'),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
                        ],
                      ),
                    ),
                  );
                  if (confirmed != true) {
                    return;
                  }
                  final int index = _draftMarkers.indexWhere((TeamMapMarkerModel item) => item.id == marker.id);
                  if (index == -1) {
                    return;
                  }
                  setState(() {
                    final TeamMapMarkerModel current = _draftMarkers[index];
                    _draftMarkers[index] = TeamMapMarkerModel(
                      id: current.id,
                      mapId: current.mapId,
                      markerType: current.markerType,
                      x: current.x,
                      y: current.y,
                      label: current.label,
                      colorHex: current.colorHex,
                      sizeScale: sizeScale,
                      createdBy: current.createdBy,
                    );
                    _mapDirty = true;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete marker'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _draftMarkers.removeWhere((TeamMapMarkerModel item) => item.id == marker.id);
                    _mapDirty = true;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addMarker(Offset pos, Size canvasSize) async {
    final TeamMapModel? selected = _selectedMap;
    if (selected == null || _mode == _MapEditMode.none || _mode == _MapEditMode.route || _mode == _MapEditMode.zone) return;
    final double x = (pos.dx / canvasSize.width).clamp(0.0, 1.0);
    final double y = (pos.dy / canvasSize.height).clamp(0.0, 1.0);
    String? label;
    if (_mode == _MapEditMode.label) label = await _promptLabel('e.g. Alpha Base');
    final String? colorHex = await _showColorPicker('Marker Colour');
    if (!mounted) {
      return;
    }
    final String markerType = switch (_mode) {
      _MapEditMode.respawn => 'respawn',
      _MapEditMode.target => 'target',
      _MapEditMode.objective => 'objective',
      _MapEditMode.waypoint => 'waypoint',
      _MapEditMode.ammo => 'ammo',
      _MapEditMode.medic => 'medic',
      _MapEditMode.bomb => 'bomb',
      _MapEditMode.terminal => 'terminal',
      _MapEditMode.extraction => 'extraction',
      _MapEditMode.label => 'label',
      _ => 'target',
    };
    setState(() {
      _draftMarkers.add(
        TeamMapMarkerModel(
          id: _draftId(),
          mapId: selected.id,
          markerType: markerType,
          x: x,
          y: y,
          label: label,
          colorHex: colorHex,
          sizeScale: 1,
          createdBy: _uid,
        ),
      );
      _mapDirty = true;
    });
  }

  void _appendRoutePoint(Offset pos, Size sz) {
    if (_mode != _MapEditMode.route) return;
    setState(() => _routeDraft.add({'x': (pos.dx / sz.width).clamp(0.0, 1.0), 'y': (pos.dy / sz.height).clamp(0.0, 1.0)}));
  }

  Future<void> _saveRoute() async {
    final TeamMapModel? selected = _selectedMap;
    if (_savingRoute || selected == null || _routeDraft.length < 2) return;
    setState(() => _savingRoute = true);
    try {
      final String? colorHex = await _showColorPicker('Route Color');
      if (!mounted) return;
      setState(() {
        _draftRoutes.add(
          TeamMapRouteModel(
            id: _draftId(),
            mapId: selected.id,
            points: List<Map<String, double>>.from(_routeDraft),
            label: _routeLabel,
            colorHex: colorHex,
            createdBy: _uid,
          ),
        );
        _routeDraft.clear();
        _routeLabel = null;
        _mapDirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('routeSaveFailed', args: {'error': e.toString()}))));
    } finally {
      if (mounted) setState(() => _savingRoute = false);
    }
  }

  void _appendZonePoint(Offset pos, Size sz) {
    if (_mode != _MapEditMode.zone) return;
    setState(() => _zoneDraft.add({'x': (pos.dx / sz.width).clamp(0.0, 1.0), 'y': (pos.dy / sz.height).clamp(0.0, 1.0)}));
  }

  Future<void> _saveZone() async {
    final TeamMapModel? selected = _selectedMap;
    if (selected == null || _zoneDraft.length < 3) return;
    final String? colorHex = await _showColorPicker('Zone Color');
    try {
      if (!mounted) return;
      setState(() {
        _draftZones.add(
          TeamMapZoneModel(
            id: _draftId(),
            mapId: selected.id,
            points: List<Map<String, double>>.from(_zoneDraft),
            label: _zoneLabel,
            colorHex: colorHex,
            createdBy: _uid,
          ),
        );
        _zoneDraft.clear();
        _zoneLabel = null;
        _mapDirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save zone: $e')));
    }
  }

  void _discardDraftChanges() {
    final TeamMapModel? selected = _selectedMap;
    if (selected == null) {
      return;
    }
    setState(() {
      _syncDrafts(selected, _remoteMarkers, _remoteRoutes, _remoteZones);
      _routeDraft.clear();
      _routeLabel = null;
      _zoneDraft.clear();
      _zoneLabel = null;
    });
  }

  Future<void> _saveDraftChanges() async {
    final TeamMapModel? selected = _selectedMap;
    if (selected == null || _savingMapDraft) {
      return;
    }
    setState(() => _savingMapDraft = true);
    try {
      final Set<String> remoteIds = _remoteMarkers.map((TeamMapMarkerModel marker) => marker.id).toSet();
      final Set<String> draftIds = _draftMarkers
          .where((TeamMapMarkerModel marker) => !marker.id.startsWith('draft_'))
          .map((TeamMapMarkerModel marker) => marker.id)
          .toSet();

      for (final TeamMapMarkerModel marker in _draftMarkers) {
        if (marker.id.startsWith('draft_')) {
          await _repository.addMarker(
            mapId: selected.id,
            markerType: marker.markerType,
            x: marker.x,
            y: marker.y,
            label: marker.label,
            colorHex: marker.colorHex,
            sizeScale: marker.sizeScale,
          );
          continue;
        }
        await _repository.updateMarkerPosition(marker.id, marker.x, marker.y);
        await _repository.updateMarkerAppearance(
          markerId: marker.id,
          label: marker.label,
          colorHex: marker.colorHex,
          sizeScale: marker.sizeScale,
        );
      }

      for (final String markerId in remoteIds.difference(draftIds)) {
        await _repository.deleteMarker(markerId);
      }

      await _repository.replaceRoutes(mapId: selected.id, routes: _draftRoutes);
      await _repository.replaceZones(mapId: selected.id, zones: _draftZones);

      if (!mounted) return;
      setState(() => _mapDirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map changes saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save map changes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingMapDraft = false);
      }
    }
  }

  void _openChat() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TeamChatScreen(teamId: widget.teamId, teamName: widget.teamName)));
  }

  void _onTapMap(Offset pos, Size sz) {
    switch (_mode) {
      case _MapEditMode.route: _appendRoutePoint(pos, sz);
      case _MapEditMode.zone:  _appendZonePoint(pos, sz);
      case _MapEditMode.none:  break;
      default: _addMarker(pos, sz);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 1,
        shadowColor: cs.shadow.withValues(alpha: 0.15),
        title: Text(l10n.t('teamMap', args: {'teamName': widget.teamName}), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_mapDirty)
            TextButton(
              onPressed: _savingMapDraft ? null : _discardDraftChanges,
              child: const Text('Discard'),
            ),
          if (_mapDirty)
            FilledButton.tonal(
              onPressed: _savingMapDraft ? null : _saveDraftChanges,
              child: _savingMapDraft
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          IconButton(onPressed: _openChat, icon: const Icon(Icons.chat_bubble_outline_rounded), tooltip: l10n.teamChat),
          IconButton(onPressed: _creatingMap ? null : _createMap, icon: const Icon(Icons.add_photo_alternate_outlined), tooltip: l10n.uploadMap),
        ],
      ),
      body: StreamBuilder<List<TeamMapModel>>(
        stream: _repository.watchMaps(widget.teamId),
        builder: (context, snapshot) {
          final List<TeamMapModel> maps = snapshot.data ?? const [];
          if (_selectedMap == null && maps.isNotEmpty) _selectedMap = maps.first;
          if (_selectedMap != null && maps.every((m) => m.id != _selectedMap!.id)) {
            _selectedMap = maps.isEmpty ? null : maps.first;
          }
          if (snapshot.connectionState == ConnectionState.waiting && maps.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (maps.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 64, color: cs.outline),
                    const SizedBox(height: 12),
                    Text(l10n.noTeamMapsYet, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 20),
                    FilledButton.icon(onPressed: _creatingMap ? null : _createMap, icon: const Icon(Icons.upload_file_outlined), label: Text(l10n.createFirstMap)),
                  ],
                ),
              ),
            );
          }

          final TeamMapModel selected = _selectedMap!;

          return StreamBuilder<List<TeamMapMarkerModel>>(
            stream: _repository.watchMarkers(selected.id),
            builder: (context, markerSnapshot) {
              final List<TeamMapMarkerModel> markers = markerSnapshot.data ?? const <TeamMapMarkerModel>[];
              return StreamBuilder<List<TeamMapRouteModel>>(
                stream: _repository.watchRoutes(selected.id),
                builder: (context, routeSnapshot) {
                  final List<TeamMapRouteModel> routes = routeSnapshot.data ?? const <TeamMapRouteModel>[];
                  return StreamBuilder<List<TeamMapZoneModel>>(
                    stream: _repository.watchZones(selected.id),
                    builder: (context, zoneSnapshot) {
                      final List<TeamMapZoneModel> zones = zoneSnapshot.data ?? const <TeamMapZoneModel>[];
                      _syncDrafts(selected, markers, routes, zones);
                      return Column(
                        children: [
              // ── Map selector ──
              Container(
                color: cs.surface,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selected.id,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                      ),
                      items: maps.map((m) => DropdownMenuItem<String>(value: m.id, child: Text(m.title))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        if (_mapDirty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Save or discard the current draft before switching maps.')),
                          );
                          return;
                        }
                        setState(() { _selectedMap = maps.firstWhere((m) => m.id == v); _routeDraft.clear(); _zoneDraft.clear(); });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _creatingMap ? null : _createMap,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(l10n.uploadMapBtn),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  ),
                ]),
              ),
              // ── Canvas ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Stack(children: [
                    Positioned.fill(
                      child: _MapCanvas(
                        map: selected,
                        mode: _mode,
                        routes: _draftRoutes,
                        zones: _draftZones,
                        markers: _draftMarkers,
                        routeDraft: _routeDraft,
                        zoneDraft: _zoneDraft,
                        currentUserId: _uid,
                        draggingMarkerId: _draggingMarkerId,
                        dragX: _dragX,
                        dragY: _dragY,
                        onTapMap: _onTapMap,
                        onMarkerTap: _showMarkerActions,
                        onMarkerDragStart: (id, x, y) => setState(() {
                          _draggingMarkerId = id;
                          _dragX = x;
                          _dragY = y;
                        }),
                        onMarkerDragUpdate: (x, y) => setState(() { _dragX = x; _dragY = y; }),
                        onMarkerDragEnd: (id, x, y) async {
                          setState(() {
                            _draggingMarkerId = null;
                            final int index = _draftMarkers.indexWhere((TeamMapMarkerModel marker) => marker.id == id);
                            if (index != -1) {
                              final TeamMapMarkerModel marker = _draftMarkers[index];
                              _draftMarkers[index] = TeamMapMarkerModel(
                                id: marker.id,
                                mapId: marker.mapId,
                                markerType: marker.markerType,
                                x: x,
                                y: y,
                                label: marker.label,
                                colorHex: marker.colorHex,
                                sizeScale: marker.sizeScale,
                                createdBy: marker.createdBy,
                              );
                            }
                            _mapDirty = true;
                          });
                        },
                        onDeleteRoute: (String routeId) {
                          setState(() {
                            _draftRoutes.removeWhere((TeamMapRouteModel route) => route.id == routeId);
                            _mapDirty = true;
                          });
                        },
                        onDeleteZone: (String zoneId) {
                          setState(() {
                            _draftZones.removeWhere((TeamMapZoneModel zone) => zone.id == zoneId);
                            _mapDirty = true;
                          });
                        },
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 12,
                      child: _ToolDock(
                        mode: _mode,
                        onModeSelected: (m) => setState(() {
                          _mode = m;
                          if (m != _MapEditMode.route) {
                            _routeDraft.clear();
                            _routeLabel = null;
                          }
                          if (m != _MapEditMode.zone) {
                            _zoneDraft.clear();
                            _zoneLabel = null;
                          }
                        }),
                      ),
                    ),
                  ]),
                ),
              ),
              // ── Route bar ──
              if (_mode == _MapEditMode.route)
                _DraftBar(
                  label: 'Route: ${_routeDraft.length} pts',
                  canSave: _routeDraft.length >= 2,
                  saving: _savingRoute,
                  onLabel: () async {
                    final String? l = await _promptLabel('Route label');
                    if (l != null && l.isNotEmpty && mounted) setState(() => _routeLabel = l);
                  },
                  onClear: () => setState(() { _routeDraft.clear(); _routeLabel = null; }),
                  onSave: _saveRoute,
                  saveLabel: l10n.mapSaveRoute,
                  clearLabel: l10n.mapModeClear,
                )
              else if (_mode == _MapEditMode.zone)
                _DraftBar(
                  label: 'Zone: ${_zoneDraft.length} pts',
                  canSave: _zoneDraft.length >= 3,
                  saving: false,
                  onLabel: () async {
                    final String? l = await _promptLabel('Zone label (optional)');
                    if (l != null && l.isNotEmpty && mounted) setState(() => _zoneLabel = l);
                  },
                  onClear: () => setState(() { _zoneDraft.clear(); _zoneLabel = null; }),
                  onSave: _saveZone,
                  saveLabel: 'Save Zone',
                  clearLabel: l10n.mapModeClear,
                ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
    );
  }
}

// ─── Draft action bar ─────────────────────────────────────────────────────────

class _DraftBar extends StatelessWidget {
  const _DraftBar({required this.label, required this.canSave, required this.saving, required this.onLabel, required this.onClear, required this.onSave, required this.saveLabel, required this.clearLabel});
  final String label;
  final bool canSave;
  final bool saving;
  final VoidCallback onLabel;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final String saveLabel;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onLabel,
            icon: const Icon(Icons.label_outlined, size: 18),
            label: const Text('Label'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_outlined, size: 18),
            label: Text(clearLabel),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: (canSave && !saving) ? onSave : null,
            icon: saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.black))) : const Icon(Icons.check_rounded, size: 18),
            label: Text(saveLabel),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
        ]),
      ),
    );
  }
}

// ─── Tool dock ────────────────────────────────────────────────────────────────

class _ToolDock extends StatelessWidget {
  const _ToolDock({required this.mode, required this.onModeSelected});
  final _MapEditMode mode;
  final ValueChanged<_MapEditMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 136,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(icon: Icons.pan_tool_outlined, label: 'View', active: mode == _MapEditMode.none, cs: cs, onTap: () => onModeSelected(_MapEditMode.none)),
          _ToolButton(icon: Icons.flag_rounded, label: 'Respawn', active: mode == _MapEditMode.respawn, cs: cs, onTap: () => onModeSelected(_MapEditMode.respawn)),
          _ToolButton(icon: Icons.location_on_rounded, label: 'Target', active: mode == _MapEditMode.target, cs: cs, onTap: () => onModeSelected(_MapEditMode.target)),
          _ToolButton(icon: Icons.adjust_rounded, label: 'Objective', active: mode == _MapEditMode.objective, cs: cs, onTap: () => onModeSelected(_MapEditMode.objective)),
          _ToolButton(icon: Icons.place_rounded, label: 'Waypoint', active: mode == _MapEditMode.waypoint, cs: cs, onTap: () => onModeSelected(_MapEditMode.waypoint)),
          _ToolButton(icon: Icons.inventory_2_rounded, label: 'Ammo', active: mode == _MapEditMode.ammo, cs: cs, onTap: () => onModeSelected(_MapEditMode.ammo)),
          _ToolButton(icon: Icons.medical_services_rounded, label: 'Medic', active: mode == _MapEditMode.medic, cs: cs, onTap: () => onModeSelected(_MapEditMode.medic)),
          _ToolButton(icon: Icons.whatshot_rounded, label: 'Bomb', active: mode == _MapEditMode.bomb, cs: cs, onTap: () => onModeSelected(_MapEditMode.bomb)),
          _ToolButton(icon: Icons.dns_rounded, label: 'Terminal', active: mode == _MapEditMode.terminal, cs: cs, onTap: () => onModeSelected(_MapEditMode.terminal)),
          _ToolButton(icon: Icons.flight_takeoff_rounded, label: 'Extraction', active: mode == _MapEditMode.extraction, cs: cs, onTap: () => onModeSelected(_MapEditMode.extraction)),
          _ToolButton(icon: Icons.title_rounded, label: 'Label', active: mode == _MapEditMode.label, cs: cs, onTap: () => onModeSelected(_MapEditMode.label)),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
          _ToolButton(icon: Icons.route_rounded, label: 'Route', active: mode == _MapEditMode.route, cs: cs, onTap: () => onModeSelected(_MapEditMode.route)),
          _ToolButton(icon: Icons.hexagon_outlined, label: 'Zone', active: mode == _MapEditMode.zone, cs: cs, onTap: () => onModeSelected(_MapEditMode.zone)),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.cs,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 136,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Canvas ────────────────────────────────────────────────────────────────────

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.map, required this.mode,
    required this.routes, required this.zones, required this.markers,
    required this.routeDraft, required this.zoneDraft,
    required this.currentUserId, required this.draggingMarkerId,
    required this.dragX, required this.dragY,
    required this.onTapMap, required this.onMarkerDragStart,
    required this.onMarkerDragUpdate, required this.onMarkerDragEnd,
    required this.onMarkerTap, required this.onDeleteRoute, required this.onDeleteZone,
  });

  final TeamMapModel map;
  final _MapEditMode mode;
  final List<TeamMapRouteModel> routes;
  final List<TeamMapZoneModel> zones;
  final List<TeamMapMarkerModel> markers;
  final List<Map<String, double>> routeDraft;
  final List<Map<String, double>> zoneDraft;
  final String currentUserId;
  final String? draggingMarkerId;
  final double dragX, dragY;
  final void Function(Offset, Size) onTapMap;
  final void Function(String, double, double) onMarkerDragStart;
  final void Function(double, double) onMarkerDragUpdate;
  final void Function(String, double, double) onMarkerDragEnd;
  final ValueChanged<TeamMapMarkerModel> onMarkerTap;
  final ValueChanged<String> onDeleteRoute;
  final ValueChanged<String> onDeleteZone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF111510)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size sz = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => onTapMap(details.localPosition, sz),
              child: InteractiveViewer(
                panEnabled: draggingMarkerId == null,
                minScale: 0.8,
                maxScale: 6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        map.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, _, _) => Center(
                          child: Text(
                            AppLocalizations.of(ctx).t('mapUploadFailed', args: {'error': '?'}),
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _ZonePainter(zones: zones, draft: zoneDraft),
                      size: Size.infinite,
                    ),
                    CustomPaint(
                      painter: _RoutePainter(routes: routes, draft: routeDraft),
                      size: Size.infinite,
                    ),
                    ...routes.map((TeamMapRouteModel route) {
                      final Map<String, double> mid = route.points[route.points.length ~/ 2];
                      return Positioned(
                        left: (mid['x'] ?? 0) * sz.width - 36,
                        top: (mid['y'] ?? 0) * sz.height - 22,
                        child: GestureDetector(
                          onLongPress: () {
                            if (route.createdBy != currentUserId) return;
                            onDeleteRoute(route.id);
                          },
                          child: _LabelChip(
                            text: (route.label ?? 'Route') + (route.createdBy == currentUserId ? '  Hold to delete' : ''),
                          ),
                        ),
                      );
                    }),
                    ...zones.where((TeamMapZoneModel zone) => zone.points.isNotEmpty).map((TeamMapZoneModel zone) {
                      double sumX = 0;
                      double sumY = 0;
                      for (final Map<String, double> point in zone.points) {
                        sumX += point['x'] ?? 0;
                        sumY += point['y'] ?? 0;
                      }
                      final double centerX = sumX / zone.points.length;
                      final double centerY = sumY / zone.points.length;
                      return Positioned(
                        left: centerX * sz.width - 42,
                        top: centerY * sz.height - 14,
                        child: GestureDetector(
                          onLongPress: () {
                            if (zone.createdBy != currentUserId) return;
                            onDeleteZone(zone.id);
                          },
                          child: _LabelChip(
                            text: (zone.label ?? 'Zone') + (zone.createdBy == currentUserId ? '  Hold to delete' : ''),
                          ),
                        ),
                      );
                    }),
                    ...markers.map((TeamMapMarkerModel marker) {
                      final bool isDragging = draggingMarkerId == marker.id;
                      final double lx = (isDragging ? dragX : marker.x) * sz.width;
                      final double ly = (isDragging ? dragY : marker.y) * sz.height;
                      final double radiusOffset = 14 * marker.sizeScale;
                      return Positioned(
                        left: math.max(0, lx - radiusOffset),
                        top: math.max(0, ly - radiusOffset),
                        child: GestureDetector(
                          onTap: () => onMarkerTap(marker),
                          onPanStart: (_) {
                            if (marker.createdBy != currentUserId) return;
                            onMarkerDragStart(marker.id, marker.x, marker.y);
                          },
                          onPanUpdate: (details) {
                            if (marker.createdBy != currentUserId) return;
                            final double baseX = isDragging ? dragX : marker.x;
                            final double baseY = isDragging ? dragY : marker.y;
                            final double nx = (baseX + (details.delta.dx / sz.width)).clamp(0.0, 1.0);
                            final double ny = (baseY + (details.delta.dy / sz.height)).clamp(0.0, 1.0);
                            onMarkerDragUpdate(nx, ny);
                          },
                          onPanEnd: (_) {
                            if (marker.createdBy != currentUserId) return;
                            onMarkerDragEnd(marker.id, dragX, dragY);
                          },
                          child: _MarkerWidget(
                            markerType: marker.markerType,
                            label: marker.label,
                            colorHex: marker.colorHex,
                            sizeScale: marker.sizeScale,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Marker widget ────────────────────────────────────────────────────────────

class _MarkerWidget extends StatelessWidget {
  const _MarkerWidget({required this.markerType, this.label, this.colorHex, this.sizeScale = 1});
  final String markerType;
  final String? label;
  final String? colorHex;
  final double sizeScale;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color fallbackColor) = switch (markerType) {
      'respawn'   => (Icons.flag_rounded,        const Color(0xFF4FC3F7)),
      'objective' => (Icons.adjust_rounded,      const Color(0xFFFFB74D)),
      'waypoint'  => (Icons.place_rounded,       const Color(0xFF81C784)),
      'ammo'      => (Icons.inventory_2_rounded, const Color(0xFF8D6E63)),
      'medic'     => (Icons.medical_services_rounded, const Color(0xFFEF5350)),
      'bomb'      => (Icons.whatshot_rounded,    const Color(0xFFFF7043)),
      'terminal'  => (Icons.dns_rounded,         const Color(0xFF7986CB)),
      'extraction'=> (Icons.flight_takeoff_rounded, const Color(0xFF26A69A)),
      'label'     => (Icons.label_rounded,       const Color(0xFFCE93D8)),
      _           => (Icons.location_on_rounded, const Color(0xFFEF5350)),
    };
    final Color color = _hex(colorHex) ?? fallbackColor;
    final double diameter = 28 * sizeScale;
    final double iconSize = 14 * sizeScale.clamp(0.8, 1.8);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if ((label ?? '').isNotEmpty) ...[
        Container(
          constraints: const BoxConstraints(maxWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(6)),
          child: Text(label!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: 2),
      ],
      Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        child: Icon(icon, color: color, size: iconSize),
      ),
    ]);
  }

  Color? _hex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final String value = hex.replaceAll('#', '').trim();
    if (value.length != 6) return null;
    final int? parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
}

// ─── Label chip ───────────────────────────────────────────────────────────────

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Route painter (curved via quadratic bezier) ──────────────────────────────

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.routes, required this.draft});
  final List<TeamMapRouteModel> routes;
  final List<Map<String, double>> draft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

    for (final route in routes) {
      if (route.points.length < 2) continue;
      paint.color = _hex(route.colorHex) ?? const Color(0xFF8FCB63);
      paint.strokeWidth = route.strokeWidth;
      canvas.drawPath(_curved(route.points.map((p) => Offset((p['x'] ?? 0) * size.width, (p['y'] ?? 0) * size.height)).toList()), paint);
    }

    if (draft.length >= 2) {
      paint..color = const Color(0xFF4FC3F7)..strokeWidth = 2.5;
      final pts = draft.map((p) => Offset((p['x'] ?? 0) * size.width, (p['y'] ?? 0) * size.height)).toList();
      canvas.drawPath(_curved(pts), paint);
      final dotPaint = Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.75);
      for (final pt in pts) {
        canvas.drawCircle(pt, 4, dotPaint);
      }
    }
  }

  Path _curved(List<Offset> pts) {
    if (pts.length == 2) return Path()..moveTo(pts[0].dx, pts[0].dy)..lineTo(pts[1].dx, pts[1].dy);
    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final Offset mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
      if (i == 0) {
        path.lineTo(mid.dx, mid.dy);
      } else {
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.routes != routes || old.draft != draft;

  Color? _hex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final v = hex.replaceAll('#', '').trim();
    if (v.length != 6) return null;
    final i = int.tryParse(v, radix: 16);
    return i == null ? null : Color(0xFF000000 | i);
  }
}

// ─── Zone painter (filled hatch + rounded polygon) ───────────────────────────

class _ZonePainter extends CustomPainter {
  const _ZonePainter({required this.zones, required this.draft});
  final List<TeamMapZoneModel> zones;
  final List<Map<String, double>> draft;

  @override
  void paint(Canvas canvas, Size size) {
    for (final zone in zones) {
      if (zone.points.length < 3) continue;
      final pts = zone.points.map((p) => Offset((p['x'] ?? 0) * size.width, (p['y'] ?? 0) * size.height)).toList();
      _draw(canvas, pts, _hex(zone.colorHex) ?? const Color(0xFFF44336));
    }
    if (draft.length >= 3) {
      final pts = draft.map((p) => Offset((p['x'] ?? 0) * size.width, (p['y'] ?? 0) * size.height)).toList();
      _draw(canvas, pts, const Color(0xFF4FC3F7), isDraft: true);
    }
    for (final pt in draft) {
      canvas.drawCircle(Offset((pt['x'] ?? 0) * size.width, (pt['y'] ?? 0) * size.height), 5, Paint()..color = const Color(0xFF4FC3F7));
    }
  }

  void _draw(Canvas canvas, List<Offset> pts, Color c, {bool isDraft = false}) {
    final path = _roundedPoly(pts);
    canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.16)..style = PaintingStyle.fill);
    // Hatching
    canvas.save();
    canvas.clipPath(path);
    final Paint hp = Paint()..color = c.withValues(alpha: 0.28)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final bounds = _bounds(pts);
    double o = bounds.left - bounds.height;
    while (o < bounds.right + bounds.height) {
      canvas.drawLine(Offset(o, bounds.top), Offset(o + bounds.height, bounds.bottom), hp);
      o += 11;
    }
    canvas.restore();
    canvas.drawPath(path, Paint()..color = c.withValues(alpha: isDraft ? 0.55 : 0.85)..style = PaintingStyle.stroke..strokeWidth = isDraft ? 1.5 : 2.2..strokeJoin = StrokeJoin.round);
  }

  Path _roundedPoly(List<Offset> pts) {
    const double r = 14;
    final n = pts.length;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n];
      final curr = pts[i];
      final next = pts[(i + 1) % n];
      final d1 = (curr - prev).distance;
      final d2 = (next - curr).distance;
      final cr = math.min(r, math.min(d1, d2) / 2);
      final from = curr + (prev - curr) / d1 * cr;
      final to   = curr + (next - curr) / d2 * cr;
      if (i == 0) {
        path.moveTo(from.dx, from.dy);
      } else {
        path.lineTo(from.dx, from.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, to.dx, to.dy);
    }
    path.close();
    return path;
  }

  Rect _bounds(List<Offset> pts) {
    double l = pts[0].dx, r = l, t = pts[0].dy, b = t;
    for (final p in pts) { if (p.dx < l) l = p.dx; if (p.dx > r) r = p.dx; if (p.dy < t) t = p.dy; if (p.dy > b) b = p.dy; }
    return Rect.fromLTRB(l, t, r, b);
  }

  @override
  bool shouldRepaint(covariant _ZonePainter old) => old.zones != zones || old.draft != draft;

  Color? _hex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    final v = hex.replaceAll('#', '').trim();
    if (v.length != 6) return null;
    final i = int.tryParse(v, radix: 16);
    return i == null ? null : Color(0xFF000000 | i);
  }
}
