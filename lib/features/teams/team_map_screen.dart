import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'team_chat_screen.dart';
import 'team_collab_repository.dart';

// ─── Edit Modes ──────────────────────────────────────────────────────────────

enum _MapEditMode { none, respawn, target, objective, waypoint, route, zone, label }

// ─── Optimistic marker ───────────────────────────────────────────────────────

class _PendingMarker {
  _PendingMarker({required this.markerType, required this.x, required this.y, this.label});
  final String markerType;
  final double x;
  final double y;
  final String? label;
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
  final List<_PendingMarker> _pendingMarkers = <_PendingMarker>[];

  String? _draggingMarkerId;
  double _dragX = 0;
  double _dragY = 0;

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

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

  Future<void> _addMarker(Offset pos, Size canvasSize) async {
    final TeamMapModel? selected = _selectedMap;
    if (selected == null || _mode == _MapEditMode.none || _mode == _MapEditMode.route || _mode == _MapEditMode.zone) return;
    final double x = (pos.dx / canvasSize.width).clamp(0.0, 1.0);
    final double y = (pos.dy / canvasSize.height).clamp(0.0, 1.0);
    String? label;
    if (_mode == _MapEditMode.label) label = await _promptLabel('e.g. Alpha Base');
    final String markerType = switch (_mode) {
      _MapEditMode.respawn => 'respawn',
      _MapEditMode.target => 'target',
      _MapEditMode.objective => 'objective',
      _MapEditMode.waypoint => 'waypoint',
      _MapEditMode.label => 'label',
      _ => 'target',
    };
    final _PendingMarker optimistic = _PendingMarker(markerType: markerType, x: x, y: y, label: label);
    setState(() => _pendingMarkers.add(optimistic));
    try {
      await _repository.addMarker(mapId: selected.id, markerType: markerType, x: x, y: y, label: label);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('addMarkerFailed', args: {'error': e.toString()}))));
    } finally {
      if (mounted) setState(() => _pendingMarkers.remove(optimistic));
    }
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
      await _repository.addRoute(mapId: selected.id, points: List.from(_routeDraft), label: _routeLabel);
      if (!mounted) return;
      setState(() { _routeDraft.clear(); _routeLabel = null; });
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
    final String? label = await _promptLabel('Zone label (optional)');
    try {
      await _repository.addZone(mapId: selected.id, points: List.from(_zoneDraft), label: label);
      if (!mounted) return;
      setState(() { _zoneDraft.clear(); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save zone: $e')));
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

          return Column(
            children: [
              // ── Map selector ──
              Container(
                color: cs.surface,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selected.id,
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
                        repository: _repository,
                        mode: _mode,
                        routeDraft: _routeDraft,
                        zoneDraft: _zoneDraft,
                        pendingMarkers: _pendingMarkers,
                        currentUserId: _uid,
                        draggingMarkerId: _draggingMarkerId,
                        dragX: _dragX,
                        dragY: _dragY,
                        onTapMap: _onTapMap,
                        onMarkerDragStart: (id) => setState(() => _draggingMarkerId = id),
                        onMarkerDragUpdate: (x, y) => setState(() { _dragX = x; _dragY = y; }),
                        onMarkerDragEnd: (id, x, y) async {
                          setState(() => _draggingMarkerId = null);
                          await _repository.updateMarkerPosition(id, x, y);
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
                          if (m != _MapEditMode.route) _routeDraft.clear();
                          if (m != _MapEditMode.zone) _zoneDraft.clear();
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
                  onLabel: () {},
                  onClear: () => setState(() => _zoneDraft.clear()),
                  onSave: _saveZone,
                  saveLabel: 'Save Zone',
                  clearLabel: l10n.mapModeClear,
                ),
            ],
          );
        },
      ),
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
          TextButton(onPressed: onLabel, child: const Text('Label')),
          TextButton(onPressed: onClear, child: Text(clearLabel)),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: (canSave && !saving) ? onSave : null,
            child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(saveLabel),
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
      width: 48,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _Btn(icon: Icons.pan_tool_outlined, tip: 'View', active: mode == _MapEditMode.none, cs: cs, onTap: () => onModeSelected(_MapEditMode.none)),
        _Btn(icon: Icons.flag_rounded, tip: 'Respawn', active: mode == _MapEditMode.respawn, cs: cs, onTap: () => onModeSelected(_MapEditMode.respawn)),
        _Btn(icon: Icons.location_on_rounded, tip: 'Target', active: mode == _MapEditMode.target, cs: cs, onTap: () => onModeSelected(_MapEditMode.target)),
        _Btn(icon: Icons.adjust_rounded, tip: 'Objective', active: mode == _MapEditMode.objective, cs: cs, onTap: () => onModeSelected(_MapEditMode.objective)),
        _Btn(icon: Icons.place_rounded, tip: 'Waypoint', active: mode == _MapEditMode.waypoint, cs: cs, onTap: () => onModeSelected(_MapEditMode.waypoint)),
        _Btn(icon: Icons.title_rounded, tip: 'Label', active: mode == _MapEditMode.label, cs: cs, onTap: () => onModeSelected(_MapEditMode.label)),
        Divider(height: 10, color: cs.outlineVariant),
        _Btn(icon: Icons.route_rounded, tip: 'Route', active: mode == _MapEditMode.route, cs: cs, onTap: () => onModeSelected(_MapEditMode.route)),
        _Btn(icon: Icons.hexagon_outlined, tip: 'Zone', active: mode == _MapEditMode.zone, cs: cs, onTap: () => onModeSelected(_MapEditMode.zone)),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.tip, required this.active, required this.cs, required this.onTap});
  final IconData icon;
  final String tip;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      preferBelow: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          child: Icon(icon, size: 20, color: active ? cs.primary : cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ─── Canvas ────────────────────────────────────────────────────────────────────

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.map, required this.repository, required this.mode,
    required this.routeDraft, required this.zoneDraft, required this.pendingMarkers,
    required this.currentUserId, required this.draggingMarkerId,
    required this.dragX, required this.dragY,
    required this.onTapMap, required this.onMarkerDragStart,
    required this.onMarkerDragUpdate, required this.onMarkerDragEnd,
  });

  final TeamMapModel map;
  final TeamCollabRepository repository;
  final _MapEditMode mode;
  final List<Map<String, double>> routeDraft;
  final List<Map<String, double>> zoneDraft;
  final List<_PendingMarker> pendingMarkers;
  final String currentUserId;
  final String? draggingMarkerId;
  final double dragX, dragY;
  final void Function(Offset, Size) onTapMap;
  final ValueChanged<String> onMarkerDragStart;
  final void Function(double, double) onMarkerDragUpdate;
  final void Function(String, double, double) onMarkerDragEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF111510)),
        child: LayoutBuilder(builder: (context, constraints) {
          final Size sz = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => onTapMap(d.localPosition, sz),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 6,
              child: Stack(children: [
                // Image
                Positioned.fill(
                  child: Image.network(map.imageUrl, fit: BoxFit.contain,
                      errorBuilder: (ctx, _, _) => Center(child: Text(AppLocalizations.of(ctx).t('mapUploadFailed', args: {'error': '?'}), style: TextStyle(color: cs.error)))),
                ),
                // Zones
                StreamBuilder<List<TeamMapZoneModel>>(
                  stream: repository.watchZones(map.id),
                  builder: (context, snap) => CustomPaint(
                    painter: _ZonePainter(zones: snap.data ?? const [], draft: zoneDraft),
                    size: Size.infinite,
                  ),
                ),
                // Routes + labels
                StreamBuilder<List<TeamMapRouteModel>>(
                  stream: repository.watchRoutes(map.id),
                  builder: (context, snap) {
                    final routes = snap.data ?? const <TeamMapRouteModel>[];
                    return Stack(children: [
                      CustomPaint(painter: _RoutePainter(routes: routes, draft: routeDraft), size: Size.infinite),
                      ...routes.where((r) => (r.label ?? '').isNotEmpty).map((r) {
                        final mid = r.points[r.points.length ~/ 2];
                        return Positioned(
                          left: (mid['x'] ?? 0) * sz.width - 36,
                          top: (mid['y'] ?? 0) * sz.height - 22,
                          child: GestureDetector(
                            onLongPress: () async {
                              if (r.createdBy != currentUserId) return;
                              await repository.deleteRoute(r.id);
                            },
                            child: _LabelChip(text: r.label!),
                          ),
                        );
                      }),
                    ]);
                  },
                ),
                // Markers
                StreamBuilder<List<TeamMapMarkerModel>>(
                  stream: repository.watchMarkers(map.id),
                  builder: (context, snap) {
                    final markers = snap.data ?? const <TeamMapMarkerModel>[];
                    return Stack(children: [
                      ...markers.map((marker) {
                        final isDragging = draggingMarkerId == marker.id;
                        final lx = (isDragging ? dragX : marker.x) * sz.width;
                        final ly = (isDragging ? dragY : marker.y) * sz.height;
                        return Positioned(
                          left: math.max(0, lx - 14),
                          top: math.max(0, ly - 14),
                          child: GestureDetector(
                            onLongPress: () async {
                              if (marker.createdBy != currentUserId) return;
                              await repository.deleteMarker(marker.id);
                            },
                            onPanStart: (_) => onMarkerDragStart(marker.id),
                            onPanUpdate: (d) {
                              final nx = ((marker.x * sz.width + d.delta.dx) / sz.width).clamp(0.0, 1.0);
                              final ny = ((marker.y * sz.height + d.delta.dy) / sz.height).clamp(0.0, 1.0);
                              onMarkerDragUpdate(nx, ny);
                            },
                            onPanEnd: (_) => onMarkerDragEnd(marker.id, dragX, dragY),
                            child: _MarkerWidget(markerType: marker.markerType, label: marker.label),
                          ),
                        );
                      }),
                      ...pendingMarkers.map((pm) {
                        final lx = pm.x * sz.width;
                        final ly = pm.y * sz.height;
                        return Positioned(
                          left: math.max(0, lx - 14),
                          top: math.max(0, ly - 14),
                          child: Opacity(opacity: 0.55, child: _MarkerWidget(markerType: pm.markerType, label: pm.label)),
                        );
                      }),
                    ]);
                  },
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Marker widget ────────────────────────────────────────────────────────────

class _MarkerWidget extends StatelessWidget {
  const _MarkerWidget({required this.markerType, this.label});
  final String markerType;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (markerType) {
      'respawn'   => (Icons.flag_rounded,        const Color(0xFF4FC3F7)),
      'objective' => (Icons.adjust_rounded,      const Color(0xFFFFB74D)),
      'waypoint'  => (Icons.place_rounded,       const Color(0xFF81C784)),
      'label'     => (Icons.label_rounded,       const Color(0xFFCE93D8)),
      _           => (Icons.location_on_rounded, const Color(0xFFEF5350)),
    };
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
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        child: Icon(icon, color: color, size: 14),
      ),
    ]);
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
      for (final pt in pts) canvas.drawCircle(pt, 4, dotPaint);
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
      if (i == 0) path.moveTo(from.dx, from.dy); else path.lineTo(from.dx, from.dy);
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
