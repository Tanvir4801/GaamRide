import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';

class GaamMap extends StatelessWidget {
  const GaamMap({
    required this.markers,
    required this.polylines,
    this.onMapCreated,
    super.key,
  });

  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController controller)? onMapCreated;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: LocationService.initialCameraPosition,
      cameraTargetBounds: CameraTargetBounds(LocationService.serviceBounds),
      minMaxZoomPreference: const MinMaxZoomPreference(11, 17),
      markers: markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: onMapCreated,
    );
  }
}
