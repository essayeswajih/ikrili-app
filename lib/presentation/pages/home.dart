import 'package:flutter/material.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/data/repositories/car_repository.dart';
import 'package:ikrili/domain/entities/car.dart';
import 'package:ikrili/presentation/pages/single_car_page.dart';
import 'package:ikrili/presentation/widgets/app_bar.dart';
import 'package:ikrili/presentation/widgets/car_image.dart';
import 'package:ikrili/presentation/widgets/drawer.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _searchController = TextEditingController();
  late Future<List<Car>> _carsFuture;

  String query = '';
  String? selectedBrand;
  double? minPrice;
  double? maxPrice;
  String locationQuery = '';
  int? maxMileage;
  int? minSeats;
  bool recommendedRentersOnly = false;

  final List<BrandOption> brands = const [
    BrandOption(name: 'Mercedes', asset: 'Mercedes-Logo.svg.png'),
    BrandOption(name: 'BMW', asset: 'bmw-car-logo.png'),
    BrandOption(name: 'Ferrari', asset: 'ferrari.png'),
    BrandOption(name: 'VOLKSWAGEN', asset: 'Volkswagen-logo.jpg'),
    BrandOption(name: 'Toyota', asset: 'toyota-logo-2020.png'),
    BrandOption(name: 'KIA', asset: 'kia.jpg'),
    BrandOption(name: 'Clio', asset: 'clio.png'),
  ];

  @override
  void initState() {
    super.initState();
    _carsFuture = CarRepository.instance.getAllCars(availableOnly: true);
  }

  Set<String> get _topRenterIds {
    final cars = CarRepository.instance.cachedCars;
    final renters = cars.map((car) => car.user).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return renters.take(5).map((user) => user.id).toSet();
  }

  int get activeFilterCount {
    return [
      selectedBrand,
      minPrice,
      maxPrice,
      locationQuery.trim().isEmpty ? null : locationQuery,
      maxMileage,
      minSeats,
      recommendedRentersOnly ? true : null,
    ].whereType<Object>().length;
  }

  Future<void> _reloadCars() async {
    setState(() {
      _carsFuture = CarRepository.instance.getAllCars(availableOnly: true);
    });
  }

  List<Car> _filteredCars(List<Car> availableCars) {
    final normalizedQuery = query.trim().toLowerCase();
    return availableCars.where((car) {
      final carName = '${car.brand} ${car.model}'.toLowerCase();
      final matchesSearch =
          normalizedQuery.isEmpty || carName.contains(normalizedQuery);
      final matchesBrand =
          selectedBrand == null ||
          car.brand.toLowerCase() == selectedBrand!.toLowerCase();
      final matchesMinPrice = minPrice == null || car.price >= minPrice!;
      final matchesMaxPrice = maxPrice == null || car.price <= maxPrice!;
      final matchesLocation =
          locationQuery.trim().isEmpty ||
          car.location.toLowerCase().contains(
            locationQuery.trim().toLowerCase(),
          );
      final matchesMileage = maxMileage == null || car.mileage <= maxMileage!;
      final matchesSeats = minSeats == null || car.seats >= minSeats!;
      final matchesRecommended =
          !recommendedRentersOnly || _topRenterIds.contains(car.user.id);
      return matchesSearch &&
          matchesBrand &&
          matchesMinPrice &&
          matchesMaxPrice &&
          matchesLocation &&
          matchesMileage &&
          matchesSeats &&
          matchesRecommended;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => query = '');
  }

  void _clearFilters() {
    setState(() {
      selectedBrand = null;
      minPrice = null;
      maxPrice = null;
      locationQuery = '';
      maxMileage = null;
      minSeats = null;
      recommendedRentersOnly = false;
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FilterSheet(
        brands: brands,
        initialBrand: selectedBrand,
        initialMinPrice: minPrice,
        initialMaxPrice: maxPrice,
        initialLocation: locationQuery,
        initialMaxMileage: maxMileage,
        initialMinSeats: minSeats,
        initialRecommendedRentersOnly: recommendedRentersOnly,
      ),
    );
    if (result == null) return;
    setState(() {
      selectedBrand = result.brand;
      minPrice = result.minPrice;
      maxPrice = result.maxPrice;
      locationQuery = result.location;
      maxMileage = result.maxMileage;
      minSeats = result.minSeats;
      recommendedRentersOnly = result.recommendedRentersOnly;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scaffold(
      appBar: const MyAppBar(title: 'Ikrili', showBackButton: true),
      drawer: const MyDrawer(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF6F7F9),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: FutureBuilder<List<Car>>(
              future: _carsFuture,
              builder: (context, snapshot) {
                final availableCars = snapshot.data ?? const <Car>[];
                final filteredCars = _filteredCars(availableCars);
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Unable to load cars: ${snapshot.error}'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 8,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: strings.t('search_cars'),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: _clearSearch,
                                      icon: const Icon(Icons.close),
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) => setState(() => query = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 56,
                            child: IconButton(
                              tooltip: strings.t('filters'),
                              onPressed: _openFilters,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                              ),
                              icon: Badge.count(
                                isLabelVisible: activeFilterCount > 0,
                                count: activeFilterCount,
                                child: const Icon(Icons.tune),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.t('available_cars'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          '${filteredCars.length} found',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    if (activeFilterCount > 0) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(strings.t('clear_filters')),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child:
                          snapshot.connectionState == ConnectionState.waiting &&
                              availableCars.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : filteredCars.isEmpty
                          ? const Center(
                              child: Text(
                                'No cars found matching your search.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.only(bottom: 18),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.72,
                                  ),
                              itemCount: filteredCars.length,
                              itemBuilder: (context, index) => CarCard(
                                car: filteredCars[index],
                                onChanged: _reloadCars,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class CarCard extends StatelessWidget {
  const CarCard({super.key, required this.car, required this.onChanged});
  final Car car;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SingleCarPage(car: car)),
        );
        onChanged();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFFFAFAFA),
                padding: const EdgeInsets.all(10),
                child: CarImage(
                  image: car.image,
                  fit: BoxFit.contain,
                  fallbackSize: 50,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${car.brand} ${car.model}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          car.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${car.price.toStringAsFixed(0)} ${car.currency}/day',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keep the rest of the filter widgets unchanged below.

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.brands,
    this.initialBrand,
    this.initialMinPrice,
    this.initialMaxPrice,
    this.initialLocation = '',
    this.initialMaxMileage,
    this.initialMinSeats,
    this.initialRecommendedRentersOnly = false,
  });
  final List<BrandOption> brands;
  final String? initialBrand;
  final double? initialMinPrice;
  final double? initialMaxPrice;
  final String initialLocation;
  final int? initialMaxMileage;
  final int? initialMinSeats;
  final bool initialRecommendedRentersOnly;
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String? _brand = widget.initialBrand;
  late bool _recommendedRentersOnly = widget.initialRecommendedRentersOnly;
  late final _minPriceController = TextEditingController(
    text: widget.initialMinPrice?.toStringAsFixed(0) ?? '',
  );
  late final _maxPriceController = TextEditingController(
    text: widget.initialMaxPrice?.toStringAsFixed(0) ?? '',
  );
  late final _locationController = TextEditingController(
    text: widget.initialLocation,
  );
  late final _mileageController = TextEditingController(
    text: widget.initialMaxMileage?.toString() ?? '',
  );
  late final _seatsController = TextEditingController(
    text: widget.initialMinSeats?.toString() ?? '',
  );

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _locationController.dispose();
    _mileageController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.pop(
      context,
      FilterResult(
        brand: _brand,
        minPrice: double.tryParse(_minPriceController.text.trim()),
        maxPrice: double.tryParse(_maxPriceController.text.trim()),
        location: _locationController.text.trim(),
        maxMileage: int.tryParse(_mileageController.text.trim()),
        minSeats: int.tryParse(_seatsController.text.trim()),
        recommendedRentersOnly: _recommendedRentersOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.t('filters'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.brands.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final brand = widget.brands[index];
                    return BrandIconButton(
                      brand: brand,
                      isSelected: _brand == brand.name,
                      onTap: () => setState(
                        () => _brand = _brand == brand.name ? null : brand.name,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min price'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mileageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max mileage',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _seatsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min seats'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recommended renters'),
                subtitle: const Text('Only cars from top 5 rated renters'),
                value: _recommendedRentersOnly,
                onChanged: (value) =>
                    setState(() => _recommendedRentersOnly = value),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const FilterResult(
                          brand: null,
                          minPrice: null,
                          maxPrice: null,
                          location: '',
                          maxMileage: null,
                          minSeats: null,
                          recommendedRentersOnly: false,
                        ),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.check),
                      label: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandIconButton extends StatelessWidget {
  const BrandIconButton({
    super.key,
    required this.brand,
    required this.isSelected,
    required this.onTap,
  });
  final BrandOption brand;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: brand.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.black : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Image.asset(
            'assets/images/brands/${brand.asset}',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image_not_supported, size: 28),
          ),
        ),
      ),
    );
  }
}

class BrandOption {
  const BrandOption({required this.name, required this.asset});
  final String name;
  final String asset;
}

class FilterResult {
  const FilterResult({
    required this.brand,
    required this.minPrice,
    required this.maxPrice,
    required this.location,
    required this.maxMileage,
    required this.minSeats,
    required this.recommendedRentersOnly,
  });
  final String? brand;
  final double? minPrice;
  final double? maxPrice;
  final String location;
  final int? maxMileage;
  final int? minSeats;
  final bool recommendedRentersOnly;
}
