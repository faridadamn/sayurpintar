import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sayurpintar/app/theme.dart';

/// Data class for map markers representing route waypoints.
class WaypointMarker {
  final String id;
  final LatLng position;
  final String label;
  final int order;
  final bool isCurrent;
  final bool isCompleted;

  const WaypointMarker({
    required this.id,
    required this.position,
    required this.label,
    required this.order,
    this.isCurrent = false,
    this.isCompleted = false,
  });
}

/// Reusable map widget for route screens.
///
/// Renders a [FlutterMap] with numbered waypoint markers, optional polyline,
/// current-location blue dot, and tap/long-press callbacks.
class RouteMapWidget extends StatelessWidget {
  final List<WaypointMarker> markers;
  final List<LatLng>? polyline;
  final LatLng? currentLocation;
  final LatLng? center;
  final double zoom;
  final bool showCurrentLocation;
  final bool showMyLocationButton;
  final Function(LatLng)? onMapTap;
  final Function(LatLng)? onMapLongPress;
  final MapController? mapController;
  final Widget? additionalOverlay;

  const RouteMapWidget({
    super.key,
    this.markers = const [],
    this.polyline,
    this.currentLocation,
    this.center,
    this.zoom = 14,
    this.showCurrentLocation = true,
    this.showMyLocationButton = false,
    this.onMapTap,
    this.onMapLongPress,
    this.mapController,
    this.additionalOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final defaultCenter = currentLocation ??
        center ??
        (markers.isNotEmpty
            ? markers.first.position
            : const LatLng(-6.2088, 106.8456));

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        center: defaultCenter,
        zoom: zoom,
        onTap: onMapTap != null
            ? (tapPos, point) => onMapTap!(point)
            : null,
        onLongPress: onMapLongPress != null
            ? (tapPos, point) => onMapLongPress!(point)
            : null,
      ),
      children: [
        // ── Tile layer ──────────────────────────────
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sayurpintar.app',
          maxZoom: 19,
        ),

        // ── Route polyline ──────────────────────────
        if (polyline != null && polyline!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: polyline!,
                color: AppTheme.primaryGreen,
                strokeWidth: 4.0,
                borderColor: AppTheme.primaryDark,
                borderStrokeWidth: 1.5,
              ),
            ],
          ),

        // ── Waypoint markers ────────────────────────
        MarkerLayer(
          markers: [
            // Numbered stop markers
            ...markers.map((m) => Marker(
                  point: m.position,
                  width: m.isCurrent ? 52 : 40,
                  height: m.isCurrent ? 52 : 40,
                  child: _StopMarker(
                    number: m.order,
                    isCurrent: m.isCurrent,
                    isCompleted: m.isCompleted,
                  ),
                )),

            // Current location blue dot
            if (showCurrentLocation && currentLocation != null)
              Marker(
                point: currentLocation!,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // ── Overlay ─────────────────────────────────
        if (additionalOverlay != null) additionalOverlay!,
      ],
    );
  }
}

/// Numbered marker widget for a route stop.
class _StopMarker extends StatelessWidget {
  final int number;
  final bool isCurrent;
  final bool isCompleted;

  const _StopMarker({
    required this.number,
    this.isCurrent = false,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 44.0 : 34.0;
    final bgColor = isCompleted
        ? AppTheme.textSecondary
        : isCurrent
            ? AppTheme.accent
            : AppTheme.primaryGreen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: isCurrent ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isCurrent ? 0.35 : 0.2),
            blurRadius: isCurrent ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isCompleted
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '$number',
                style: TextStyle(
                  color: isCurrent ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: isCurrent ? 18 : 14,
                  fontFamily: 'Nunito',
                ),
              ),
      ),
    );
  }
}
