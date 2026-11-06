import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ikrili/data/repositories/nearby_repository.dart';
import 'package:ikrili/data/services/location_service.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/domain/entities/nearby_owner.dart';
import 'package:ikrili/domain/entities/user.dart';
import 'package:ikrili/presentation/pages/single_renter_page.dart';
import 'package:ikrili/presentation/widgets/app_bar.dart';

class NearbyMapPage extends StatefulWidget {
  const NearbyMapPage({super.key});

  @override
  State<NearbyMapPage> createState() => _NearbyMapPageState();
}

class _NearbyMapPageState extends State<NearbyMapPage> {
  final _mapController = MapController();
  final _nearbyRepository = NearbyRepository();
  final _locationService = LocationService();

  LatLng _center = const LatLng(36.8065, 10.1815);
  double _radiusKm = 5;
  List<NearbyOwner> _owners = const [];
  NearbyOwner? _selectedOwner;
  bool _loading = false;
  String? _error;
  bool _hasMovedMap = false;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await _locationService.currentPosition();
      if (!mounted) return;
      setState(() => _center = LatLng(position.latitude, position.longitude));
    } catch (_) {
      // Tunis is the safe default; the user can move the map manually.
    }
    await _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedOwner = null;
      _hasMovedMap = false;
    });
    try {
      final owners = await _nearbyRepository.findOwners(
        latitude: _center.latitude,
        longitude: _center.longitude,
        radiusKm: _radiusKm,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );
      if (!mounted) return;
      setState(() => _owners = owners);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openProfile(NearbyOwner owner) {
    final now = DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SingleRenterPage(
          renter: User(
            id: owner.ownerId,
            name: owner.name,
            email: '',
            phone: '',
            address: '',
            image: owner.profileImage ?? '',
            role: 'car_owner',
            createdAt: now,
            updatedAt: now,
            rating: owner.rating,
            location: 'Pickup location',
            cars: const [],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: MyAppBar(title: strings.t('nearby'), showBackButton: true),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 12,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  _center = position.center!;
                  if (!_loading) setState(() => _hasMovedMap = true);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.softhub.ikrili',
              ),
              RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _center,
                    radius: _radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _center,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                  ..._owners.map(
                    (owner) => Marker(
                      point: LatLng(owner.latitude, owner.longitude),
                      width: 150,
                      height: 70,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedOwner = owner),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${owner.name}\nFrom ${owner.lowestPricePerDay.toStringAsFixed(0)} ${owner.currency}/day',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                            Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.radar),
                    const SizedBox(width: 8),
                    Text(strings.t('radius')),
                    ...[3.0, 5.0].map((value) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(label: Text('${value.toInt()} km'), selected: _radiusKm == value, onSelected: (_) { setState(() => _radiusKm = value); _search(); }),
                    )),
                    Expanded(
                      child: Slider(
                        min: 1,
                max: 100,
                        divisions: 19,
                        value: _radiusKm,
                        label: '${_radiusKm.toStringAsFixed(0)} km',
                        onChanged: (value) => setState(() => _radiusKm = value),
                        onChangeEnd: (_) => _search(),
                      ),
                    ),
                    Text('${_radiusKm.toStringAsFixed(0)} km'),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 76,
            left: 12,
            right: 12,
            child: Card(child: ListTile(
              leading: const Icon(Icons.event_available),
              title: Text(_dateRange == null ? strings.t('any_dates') : '${_dateRange!.start.toIso8601String().substring(0, 10)} → ${_dateRange!.end.toIso8601String().substring(0, 10)}'),
              subtitle: Text(strings.t('available_cars_filter')),
              trailing: IconButton(icon: const Icon(Icons.edit_calendar), onPressed: () async {
                final picked = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)), initialDateRange: _dateRange);
                if (picked != null && mounted) { setState(() => _dateRange = picked); _search(); }
              }),
            )),
          ),
          if (_hasMovedMap)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: Text(strings.t('search_this_area')),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  title: const Text('Unable to load nearby owners'),
                  subtitle: Text(_error!),
                  trailing: IconButton(onPressed: _search, icon: const Icon(Icons.refresh)),
                ),
              ),
            ),
          if (!_loading && _error == null && _owners.isEmpty)
            const Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Card(child: Padding(padding: EdgeInsets.all(14), child: Text(AppLocalizations.of(context).t('no_owners_found')))),
            ),
          if (_selectedOwner != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _OwnerPreviewCard(owner: _selectedOwner!, onViewProfile: () => _openProfile(_selectedOwner!)),
            ),
        ],
      ),
    );
  }
}

class _OwnerPreviewCard extends StatelessWidget {
  const _OwnerPreviewCard({required this.owner, required this.onViewProfile});

  final NearbyOwner owner;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(owner.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${owner.distanceKm.toStringAsFixed(1)} km · ${owner.availableCarsCount} available cars'),
                  Text('From ${owner.lowestPricePerDay.toStringAsFixed(0)} ${owner.currency}/day · ${owner.rating.toStringAsFixed(1)} ★'),
                ],
              ),
            ),
            FilledButton(onPressed: onViewProfile, child: Text(AppLocalizations.of(context).t('view_profile'))),
          ],
        ),
      ),
    );
  }
}

