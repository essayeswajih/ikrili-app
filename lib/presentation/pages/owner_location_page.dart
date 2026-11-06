import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:ikrili/config/api_config.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/data/services/location_service.dart';
import 'package:ikrili/data/remote/token_store.dart';
import 'package:ikrili/presentation/widgets/app_bar.dart';

class OwnerLocationPage extends StatefulWidget {
  const OwnerLocationPage({super.key});

  @override
  State<OwnerLocationPage> createState() => _OwnerLocationPageState();
}

class _OwnerLocationPageState extends State<OwnerLocationPage> {
  final _locationService = LocationService();
  LatLng _selected = const LatLng(36.8065, 10.1815);
  bool _gpsEnabled = false;
  bool _saving = false;
  String? _message;


  Future<void> _saveFixed() async {
    await _send('/owners/me/location/fixed', 'PUT', {
      'latitude': _selected.latitude,
      'longitude': _selected.longitude,
    });
  }

  Future<void> _toggleGps(bool enabled) async {
    await _send('/owners/me/location/settings', 'PATCH', {'enabled': enabled});
    if (mounted) setState(() => _gpsEnabled = enabled);
  }

  Future<void> _updateGps() async {
    try {
      final position = await _locationService.currentPosition();
      await _send('/owners/me/location/gps', 'POST', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (mounted) {
        setState(() => _selected = LatLng(position.latitude, position.longitude));
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    }
  }

  Future<void> _send(String path, String method, Map<String, dynamic> body) async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      await TokenStore.instance.load();
      final headers = {
        'Content-Type': 'application/json',
        if (TokenStore.instance.accessToken != null)
          'Authorization': 'Bearer ${TokenStore.instance.accessToken}',
      };
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = jsonEncode(body);
      final client = http.Client();
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close();
        throw Exception('Location update failed (${response.statusCode})');
      }
      if (mounted) setState(() => _message = 'Pickup location saved.');
      client.close();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: MyAppBar(title: strings.t('pickup_location'), showBackButton: true),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selected,
                initialZoom: 12,
                onTap: (_, point) => setState(() => _selected = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.softhub.ikrili',
                ),
                RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: _selected,
                    width: 48,
                    height: 48,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 42),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${strings.t('selected_coordinates')}: ${_selected.latitude.toStringAsFixed(5)}, ${_selected.longitude.toStringAsFixed(5)}'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveFixed,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(strings.t('save_pickup_location')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _gpsEnabled,
                  onChanged: _saving ? null : _toggleGps,
                  title: Text(strings.t('enable_gps')),
                  subtitle: Text(strings.t('gps_privacy')),
                ),
                OutlinedButton.icon(
                  onPressed: !_gpsEnabled || _saving ? null : _updateGps,
                  icon: const Icon(Icons.gps_fixed),
                  label: Text(strings.t('update_gps')),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

