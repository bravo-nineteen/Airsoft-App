import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'team_chat_screen.dart';
import 'team_collab_repository.dart';

class TeamMapScreen extends StatefulWidget {
  const TeamMapScreen({super.key, required this.teamId, required this.teamName});

  final String teamId;
  final String teamName;

  @override
  State<TeamMapScreen> createState() => _TeamMapScreenState();
}

enum _MapEditMode { none, respawn, target, objective, waypoint, route }

class _TeamMapScreenState extends State<TeamMapScreen> {
  final TeamCollabRepository _repository = TeamCollabRepository();
  final ImagePicker _picker = ImagePicker();

  TeamMapModel? _selectedMap;
  _MapEditMode _mode = _MapEditMode.none;
  bool _creatingMap = false;
  bool _savingRoute = false;
  final List<Map<String, double>> _routeDraft = <Map<String, double>>[];

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<void> _createMap() async {
    if (_creatingMap) {
      return;
    }

    final TextEditingController titleController = TextEditingController();
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).createTacticalMap),
          content: TextField(
            controller: titleController,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).mapTitle),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context).t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(titleController.text.trim()),
              child: const Text('Next'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    if (title == null || title.trim().isEmpty) {
      return;
    }

    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }

    final Uint8List bytes = await file.readAsBytes();

    setState(() {
      _creatingMap = true;
    });

    try {
      await _repository.createMap(
        teamId: widget.teamId,
        title: title,
        imageBytes: bytes,
        originalFilename: file.name,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).mapUploadSuccess)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('mapUploadFailed', args: {'error': error.toString()}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creatingMap = false;
        });
      }
    }
  }

  Future<void> _addMarker(Offset localPosition, Size canvasSize) async {
    final TeamMapModel? selected = _selectedMap;
    if (selected == null) {
      return;
    }

    if (_mode == _MapEditMode.route || _mode == _MapEditMode.none) {
      return;
    }

    final double x = (localPosition.dx / canvasSize.width).clamp(0, 1);
    final double y = (localPosition.dy / canvasSize.height).clamp(0, 1);
    final String markerType = switch (_mode) {
      _MapEditMode.respawn => 'respawn',
      _MapEditMode.target => 'target',
      _MapEditMode.objective => 'objective',
      _MapEditMode.waypoint => 'waypoint',
      _MapEditMode.none || _MapEditMode.route => 'target',
    };

    try {
      await _repository.addMarker(
        mapId: selected.id,
        markerType: markerType,
        x: x,
        y: y,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('addMarkerFailed', args: {'error': error.toString()}))),
      );
    }
  }

  void _appendRoutePoint(Offset localPosition, Size canvasSize) {
    if (_mode != _MapEditMode.route) {
      return;
    }
    final double x = (localPosition.dx / canvasSize.width).clamp(0, 1);
    final double y = (localPosition.dy / canvasSize.height).clamp(0, 1);
    setState(() {
      _routeDraft.add(<String, double>{'x': x, 'y': y});
    });
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamChatScreen(
          teamId: widget.teamId,
          teamName: widget.teamName,
        ),
      ),
    );
  }

  Future<void> _saveRoute() async {
    final TeamMapModel? selected = _selectedMap;
    if (_savingRoute || selected == null || _routeDraft.length < 2) {
      return;
    }

    setState(() {
      _savingRoute = true;
    });

    try {
      await _repository.addRoute(
        mapId: selected.id,
        points: List<Map<String, double>>.from(_routeDraft),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _routeDraft.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).routeSaved)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('routeSaveFailed', args: {'error': error.toString()}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingRoute = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('teamMap', args: {'teamName': widget.teamName})),
        actions: <Widget>[
          IconButton(
            onPressed: _creatingMap ? null : _createMap,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: AppLocalizations.of(context).uploadMap,
          ),
        ],
      ),
      body: StreamBuilder<List<TeamMapModel>>(
        stream: _repository.watchMaps(widget.teamId),
        builder: (BuildContext context, AsyncSnapshot<List<TeamMapModel>> snapshot) {
          final List<TeamMapModel> maps = snapshot.data ?? const <TeamMapModel>[];

          if (_selectedMap == null && maps.isNotEmpty) {
            _selectedMap = maps.first;
          }
          if (_selectedMap != null &&
              maps.every((TeamMapModel m) => m.id != _selectedMap!.id)) {
            _selectedMap = maps.isEmpty ? null : maps.first;
          }

          if (snapshot.connectionState == ConnectionState.waiting && maps.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (maps.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.map_outlined, size: 56),
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(context).noTeamMapsYet,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _creatingMap ? null : _createMap,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(AppLocalizations.of(context).createFirstMap),
                    ),
                  ],
                ),
              ),
            );
          }

          final TeamMapModel selected = _selectedMap!;

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selected.id,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).mapTitle,
                          border: const OutlineInputBorder(),
                        ),
                        items: maps
                            .map(
                              (TeamMapModel map) => DropdownMenuItem<String>(
                                value: map.id,
                                child: Text(map.title),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedMap = maps.firstWhere((TeamMapModel m) => m.id == value);
                            _routeDraft.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _creatingMap ? null : _createMap,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(AppLocalizations.of(context).uploadMapBtn),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: _MapCanvas(
                          map: selected,
                          repository: _repository,
                          mode: _mode,
                          routeDraft: _routeDraft,
                          currentUserId: _uid,
                          onTapMap: (Offset offset, Size size) {
                            if (_mode == _MapEditMode.route) {
                              _appendRoutePoint(offset, size);
                            } else {
                              _addMarker(offset, size);
                            }
                          },
                          onClearRouteDraft: () {
                            setState(() {
                              _routeDraft.clear();
                            });
                          },
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 14,
                        child: _RightToolDock(
                          mode: _mode,
                          onModeSelected: (_MapEditMode mode) {
                            setState(() {
                              _mode = mode;
                              if (mode != _MapEditMode.route) {
                                _routeDraft.clear();
                              }
                            });
                          },
                          onOpenChat: _openChat,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _mode == _MapEditMode.route
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: <Widget>[
                    Text('Draft: ${_routeDraft.length}'),
                    const Spacer(),
                    TextButton(
                      onPressed: _routeDraft.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _routeDraft.clear();
                              });
                            },
                      child: Text(AppLocalizations.of(context).mapModeClear),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _savingRoute || _routeDraft.length < 2 ? null : _saveRoute,
                      child: _savingRoute
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(AppLocalizations.of(context).mapSaveRoute),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.map,
    required this.repository,
    required this.mode,
    required this.routeDraft,
    required this.currentUserId,
    required this.onTapMap,
    required this.onClearRouteDraft,
  });

  final TeamMapModel map;
  final TeamCollabRepository repository;
  final _MapEditMode mode;
  final List<Map<String, double>> routeDraft;
  final String currentUserId;
  final void Function(Offset localPosition, Size canvasSize) onTapMap;
  final VoidCallback onClearRouteDraft;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              const Color(0xFF161D15),
              const Color(0xFF11140F),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) => onTapMap(details.localPosition, canvasSize),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Image.network(
                        map.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (BuildContext errCtx, _, _) {
                          return Center(child: Text(AppLocalizations.of(errCtx).t('mapUploadFailed', args: {'error': '?'})));
                        },
                      ),
                    ),
                    StreamBuilder<List<TeamMapRouteModel>>(
                      stream: repository.watchRoutes(map.id),
                      builder: (BuildContext context, AsyncSnapshot<List<TeamMapRouteModel>> routeSnapshot) {
                        final List<TeamMapRouteModel> routes = routeSnapshot.data ?? const <TeamMapRouteModel>[];
                        return CustomPaint(
                          painter: _RoutePainter(
                            routes: routes,
                            draft: routeDraft,
                          ),
                          size: Size.infinite,
                        );
                      },
                    ),
                    StreamBuilder<List<TeamMapMarkerModel>>(
                      stream: repository.watchMarkers(map.id),
                      builder: (BuildContext context, AsyncSnapshot<List<TeamMapMarkerModel>> markerSnapshot) {
                        final List<TeamMapMarkerModel> markers = markerSnapshot.data ?? const <TeamMapMarkerModel>[];
                        return Stack(
                          children: markers.map((TeamMapMarkerModel marker) {
                            final double left = marker.x * constraints.maxWidth;
                            final double top = marker.y * constraints.maxHeight;

                            return Positioned(
                              left: math.max(0, left - 11),
                              top: math.max(0, top - 11),
                              child: GestureDetector(
                                onLongPress: () async {
                                  if (marker.createdBy != currentUserId) {
                                    return;
                                  }
                                  await repository.deleteMarker(marker.id);
                                },
                                child: _markerIcon(marker.markerType),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _markerIcon(String type) {
    final (IconData icon, Color color) = switch (type) {
      'respawn' => (Icons.flag, Colors.blueAccent),
      'objective' => (Icons.adjust, Colors.orangeAccent),
      'waypoint' => (Icons.trip_origin, Colors.greenAccent),
      _ => (Icons.location_on, Colors.redAccent),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(3),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.routes, required this.draft});

  final List<TeamMapRouteModel> routes;
  final List<Map<String, double>> draft;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final TeamMapRouteModel route in routes) {
      if (route.points.length < 2) {
        continue;
      }
      paint.color = _colorFromHex(route.colorHex) ?? const Color(0xFF8FCB63);
      paint.strokeWidth = route.strokeWidth;

      final Path path = Path();
      final Map<String, double> first = route.points.first;
      path.moveTo((first['x'] ?? 0) * size.width, (first['y'] ?? 0) * size.height);

      for (int i = 1; i < route.points.length; i++) {
        final Map<String, double> point = route.points[i];
        path.lineTo((point['x'] ?? 0) * size.width, (point['y'] ?? 0) * size.height);
      }
      canvas.drawPath(path, paint);
    }

    if (draft.length >= 2) {
      paint
        ..color = const Color(0xFF4FC3F7)
        ..strokeWidth = 2.5;
      final Path path = Path();
      final Map<String, double> first = draft.first;
      path.moveTo((first['x'] ?? 0) * size.width, (first['y'] ?? 0) * size.height);
      for (int i = 1; i < draft.length; i++) {
        final Map<String, double> point = draft[i];
        path.lineTo((point['x'] ?? 0) * size.width, (point['y'] ?? 0) * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.routes != routes || oldDelegate.draft != draft;
  }

  Color? _colorFromHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) {
      return null;
    }
    final String value = hex.replaceAll('#', '').trim();
    if (value.length != 6) {
      return null;
    }
    final int? intValue = int.tryParse(value, radix: 16);
    if (intValue == null) {
      return null;
    }
    return Color(0xFF000000 | intValue);
  }
}

class _RightToolDock extends StatelessWidget {
  const _RightToolDock({
    required this.mode,
    required this.onModeSelected,
    required this.onOpenChat,
  });

  final _MapEditMode mode;
  final ValueChanged<_MapEditMode> onModeSelected;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color background = Colors.black.withValues(alpha: 0.62);
    final Color active = Theme.of(context).colorScheme.primary;

    Widget button({
      required IconData icon,
      required String tooltip,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: selected ? active.withValues(alpha: 0.25) : Colors.transparent,
          foregroundColor: selected ? active : Colors.white,
        ),
        icon: Icon(icon, size: 18),
      );
    }

    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          button(
            icon: Icons.visibility_outlined,
            tooltip: l10n.t('viewAll'),
            selected: mode == _MapEditMode.none,
            onTap: () => onModeSelected(_MapEditMode.none),
          ),
          button(
            icon: Icons.flag_outlined,
            tooltip: l10n.mapModeRespawn,
            selected: mode == _MapEditMode.respawn,
            onTap: () => onModeSelected(_MapEditMode.respawn),
          ),
          button(
            icon: Icons.location_on_outlined,
            tooltip: l10n.mapModeTarget,
            selected: mode == _MapEditMode.target,
            onTap: () => onModeSelected(_MapEditMode.target),
          ),
          button(
            icon: Icons.my_location_outlined,
            tooltip: l10n.mapModeObjective,
            selected: mode == _MapEditMode.objective,
            onTap: () => onModeSelected(_MapEditMode.objective),
          ),
          button(
            icon: Icons.timeline,
            tooltip: l10n.mapModeRoute,
            selected: mode == _MapEditMode.route,
            onTap: () => onModeSelected(_MapEditMode.route),
          ),
          const Divider(height: 12, color: Colors.white24),
          button(
            icon: Icons.chat_bubble_outline,
            tooltip: l10n.teamChat,
            selected: false,
            onTap: onOpenChat,
          ),
        ],
      ),
    );
  }
}
