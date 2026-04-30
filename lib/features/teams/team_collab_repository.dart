import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TeamMapModel {
  const TeamMapModel({
    required this.id,
    required this.teamId,
    required this.title,
    required this.imageUrl,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String teamId;
  final String title;
  final String imageUrl;
  final String createdBy;
  final DateTime createdAt;

  factory TeamMapModel.fromJson(Map<String, dynamic> json) {
    return TeamMapModel(
      id: (json['id'] ?? '').toString(),
      teamId: (json['team_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      createdBy: (json['created_by'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }
}

class TeamMapMarkerModel {
  const TeamMapMarkerModel({
    required this.id,
    required this.mapId,
    required this.markerType,
    required this.x,
    required this.y,
    this.label,
    this.colorHex,
    required this.createdBy,
  });

  final String id;
  final String mapId;
  final String markerType;
  final double x;
  final double y;
  final String? label;
  final String? colorHex;
  final String createdBy;

  factory TeamMapMarkerModel.fromJson(Map<String, dynamic> json) {
    return TeamMapMarkerModel(
      id: (json['id'] ?? '').toString(),
      mapId: (json['map_id'] ?? '').toString(),
      markerType: (json['marker_type'] ?? 'target').toString(),
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      label: (json['label'] ?? '').toString().trim().isEmpty
          ? null
          : (json['label'] ?? '').toString().trim(),
      colorHex: (json['color_hex'] ?? '').toString().trim().isEmpty
          ? null
          : (json['color_hex'] ?? '').toString().trim(),
      createdBy: (json['created_by'] ?? '').toString(),
    );
  }
}

class TeamMapRouteModel {
  const TeamMapRouteModel({
    required this.id,
    required this.mapId,
    required this.points,
    this.label,
    this.colorHex,
    this.strokeWidth = 3,
    required this.createdBy,
  });

  final String id;
  final String mapId;
  final List<Map<String, double>> points;
  final String? label;
  final String? colorHex;
  final double strokeWidth;
  final String createdBy;

  factory TeamMapRouteModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawPoints = json['points'];
    final List<Map<String, double>> parsed = <Map<String, double>>[];
    if (rawPoints is List) {
      for (final dynamic entry in rawPoints) {
        if (entry is Map) {
          final double x = (entry['x'] as num?)?.toDouble() ?? 0;
          final double y = (entry['y'] as num?)?.toDouble() ?? 0;
          parsed.add(<String, double>{'x': x, 'y': y});
        }
      }
    }

    return TeamMapRouteModel(
      id: (json['id'] ?? '').toString(),
      mapId: (json['map_id'] ?? '').toString(),
      points: parsed,
      label: (json['label'] ?? '').toString().trim().isEmpty
          ? null
          : (json['label'] ?? '').toString().trim(),
      colorHex: (json['color_hex'] ?? '').toString().trim().isEmpty
          ? null
          : (json['color_hex'] ?? '').toString().trim(),
      strokeWidth: (json['stroke_width'] as num?)?.toDouble() ?? 3,
      createdBy: (json['created_by'] ?? '').toString(),
    );
  }
}

class TeamMapZoneModel {
  const TeamMapZoneModel({
    required this.id,
    required this.mapId,
    required this.points,
    this.label,
    this.colorHex,
    required this.createdBy,
  });

  final String id;
  final String mapId;
  final List<Map<String, double>> points;
  final String? label;
  final String? colorHex;
  final String createdBy;

  factory TeamMapZoneModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawPoints = json['points'];
    final List<Map<String, double>> parsed = <Map<String, double>>[];
    if (rawPoints is List) {
      for (final dynamic entry in rawPoints) {
        if (entry is Map) {
          final double x = (entry['x'] as num?)?.toDouble() ?? 0;
          final double y = (entry['y'] as num?)?.toDouble() ?? 0;
          parsed.add(<String, double>{'x': x, 'y': y});
        }
      }
    }
    return TeamMapZoneModel(
      id: (json['id'] ?? '').toString(),
      mapId: (json['map_id'] ?? '').toString(),
      points: parsed,
      label: (json['label'] ?? '').toString().trim().isEmpty
          ? null
          : (json['label'] ?? '').toString().trim(),
      colorHex: (json['color_hex'] ?? '').toString().trim().isEmpty
          ? null
          : (json['color_hex'] ?? '').toString().trim(),
      createdBy: (json['created_by'] ?? '').toString(),
    );
  }
}

class TeamMessageModel {
  const TeamMessageModel({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
    this.mapId,
  });

  final String id;
  final String teamId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? mapId;

  factory TeamMessageModel.fromJson(Map<String, dynamic> json) {
    return TeamMessageModel(
      id: (json['id'] ?? '').toString(),
      teamId: (json['team_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      senderName: (json['sender_name'] ?? '').toString().trim().isEmpty
          ? null
          : (json['sender_name'] ?? '').toString().trim(),
      senderAvatarUrl: (json['sender_avatar_url'] ?? '').toString().trim().isEmpty
          ? null
          : (json['sender_avatar_url'] ?? '').toString().trim(),
      mapId: (json['map_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['map_id'] ?? '').toString().trim(),
    );
  }
}

class TeamCollabRepository {
  TeamCollabRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  final Uuid _uuid = const Uuid();

  String get _uid {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('You must be logged in.');
    }
    return uid;
  }

  Stream<List<TeamMapModel>> watchMaps(String teamId) {
    return _client
        .from('team_maps')
        .stream(primaryKey: <String>['id'])
        .eq('team_id', teamId)
        .order('created_at', ascending: false)
        .map((List<Map<String, dynamic>> rows) {
          return rows
              .map((Map<String, dynamic> row) => TeamMapModel.fromJson(row))
              .toList();
        });
  }

  Stream<List<TeamMapMarkerModel>> watchMarkers(String mapId) {
    return _client
        .from('team_map_markers')
        .stream(primaryKey: <String>['id'])
        .eq('map_id', mapId)
        .order('created_at')
        .map((List<Map<String, dynamic>> rows) {
          return rows
              .map((Map<String, dynamic> row) => TeamMapMarkerModel.fromJson(row))
              .toList();
        });
  }

  Stream<List<TeamMapRouteModel>> watchRoutes(String mapId) {
    return _client
        .from('team_map_routes')
        .stream(primaryKey: <String>['id'])
        .eq('map_id', mapId)
        .order('created_at')
        .map((List<Map<String, dynamic>> rows) {
          return rows
              .map((Map<String, dynamic> row) => TeamMapRouteModel.fromJson(row))
              .toList();
        });
  }

  Stream<List<TeamMessageModel>> watchMessages(String teamId) {
    return _client
        .from('team_messages')
        .stream(primaryKey: <String>['id'])
        .eq('team_id', teamId)
        .order('created_at')
        .map((List<Map<String, dynamic>> rows) {
          return rows
              .map((Map<String, dynamic> row) => TeamMessageModel.fromJson(row))
              .toList();
        });
  }

  Future<void> createMap({
    required String teamId,
    required String title,
    required Uint8List imageBytes,
    required String originalFilename,
  }) async {
    final String uid = _uid;
    final String ext = p.extension(originalFilename).toLowerCase();
    final String safeExt = ext.isEmpty ? '.jpg' : ext;
    final String objectPath = 'team-maps/$uid/$teamId/${_uuid.v4()}$safeExt';

    await _client.storage
        .from('team-maps')
        .uploadBinary(
          objectPath,
          imageBytes,
          fileOptions: const FileOptions(upsert: false),
        );

    final String imageUrl = _client.storage
        .from('team-maps')
        .getPublicUrl(objectPath);

    await _client.from('team_maps').insert(<String, dynamic>{
      'team_id': teamId,
      'title': title.trim(),
      'image_url': imageUrl,
      'created_by': uid,
    });
  }

  Future<void> addMarker({
    required String mapId,
    required String markerType,
    required double x,
    required double y,
    String? label,
    String? colorHex,
  }) async {
    await _client.from('team_map_markers').insert(<String, dynamic>{
      'map_id': mapId,
      'marker_type': markerType,
      'x': x,
      'y': y,
      'label': label?.trim().isEmpty == true ? null : label?.trim(),
      'color_hex': colorHex,
      'created_by': _uid,
    });
  }

  Future<void> addRoute({
    required String mapId,
    required List<Map<String, double>> points,
    String? label,
    String? colorHex,
    double strokeWidth = 3,
  }) async {
    if (points.length < 2) {
      throw Exception('Route requires at least two points.');
    }

    await _client.from('team_map_routes').insert(<String, dynamic>{
      'map_id': mapId,
      'points': points,
      'label': label?.trim().isEmpty == true ? null : label?.trim(),
      'color_hex': colorHex,
      'stroke_width': strokeWidth,
      'created_by': _uid,
    });
  }

  Future<void> deleteMarker(String markerId) async {
    await _client.from('team_map_markers').delete().eq('id', markerId);
  }

  Future<void> updateMarkerPosition(String markerId, double x, double y) async {
    await _client
        .from('team_map_markers')
        .update(<String, dynamic>{'x': x, 'y': y})
        .eq('id', markerId);
  }

  Future<void> deleteRoute(String routeId) async {
    await _client.from('team_map_routes').delete().eq('id', routeId);
  }

  Future<void> addZone({
    required String mapId,
    required List<Map<String, double>> points,
    String? label,
    String? colorHex,
  }) async {
    if (points.length < 3) {
      throw Exception('Zone requires at least three points.');
    }
    await _client.from('team_map_zones').insert(<String, dynamic>{
      'map_id': mapId,
      'points': points,
      'label': label?.trim().isEmpty == true ? null : label?.trim(),
      'color_hex': colorHex,
      'created_by': _uid,
    });
  }

  Future<void> deleteZone(String zoneId) async {
    await _client.from('team_map_zones').delete().eq('id', zoneId);
  }

  Stream<List<TeamMapZoneModel>> watchZones(String mapId) {
    return _client
        .from('team_map_zones')
        .stream(primaryKey: <String>['id'])
        .eq('map_id', mapId)
        .order('created_at')
        .map((List<Map<String, dynamic>> rows) {
          return rows
              .map((Map<String, dynamic> row) => TeamMapZoneModel.fromJson(row))
              .toList();
        });
  }

  Future<void> sendTeamMessage({
    required String teamId,
    required String body,
    String? mapId,
  }) async {
    final String uid = _uid;

    final Map<String, dynamic>? me = await _client
        .from('profiles')
        .select('call_sign, avatar_url')
        .eq('id', uid)
        .maybeSingle();

    await _client.from('team_messages').insert(<String, dynamic>{
      'team_id': teamId,
      'user_id': uid,
      'sender_name': (me?['call_sign'] ?? 'Operator').toString(),
      'sender_avatar_url': (me?['avatar_url'] ?? '').toString(),
      'body': body.trim(),
      'map_id': mapId,
    });
  }
}
