// lib/screens/admin/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _pickedLocation;
  String? _pickedAddress;
  bool _isLoading = true;
  LatLng _initialLocation = const LatLng(37.7749, -122.4194); 

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _initialLocation = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });
  }

  Future<void> _selectLocation(LatLng position) async {
    setState(() {
      _pickedLocation = position;
    });

    // Get the address of the selected location
    List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      setState(() {
        _pickedAddress = '${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          if (_pickedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.of(context).pop('$_pickedAddress');
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialLocation,
                zoom: 16,
              ),
              onMapCreated: (controller) {
              },
              onTap: _selectLocation,
              markers: _pickedLocation == null
                  ? {}
                  : {
                      Marker(
                        markerId: const MarkerId('m1'),
                        position: _pickedLocation!,
                      ),
                    },
            ),
      bottomNavigationBar: _pickedAddress != null
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _pickedAddress!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
