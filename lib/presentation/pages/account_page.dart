import 'package:flutter/material.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/data/repositories/car_repository.dart';
import 'package:ikrili/data/repositories/reservation_repository.dart';
import 'package:ikrili/data/services/local_auth_service.dart';
import 'package:ikrili/domain/entities/car.dart';
import 'package:ikrili/domain/entities/reservation.dart';
import 'package:ikrili/domain/entities/user.dart';
import 'package:ikrili/presentation/pages/reservation_calendar_page.dart';
import 'package:ikrili/presentation/account/account_signed_out_view.dart';
import 'package:ikrili/presentation/pages/single_car_page.dart';
import 'package:ikrili/presentation/widgets/app_bar.dart';
import 'package:ikrili/presentation/widgets/car_image.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  int _selectedIndex = 0;

  Future<void> _logout() async {
    await LocalAuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = LocalAuthService.instance.currentUser;
    final locale = AppLocalizations.of(context).locale;
    if (user == null) {
      return Scaffold(
        appBar: const MyAppBar(title: 'Account', showBackButton: true),
        body: AccountSignedOutView(
          onSignIn: () => Navigator.pushReplacementNamed(context, 'login'),
        ),
      );
    }

    final pages = [
      RoleDashboard(user: user),
      ProfilePage(user: user, onUpdated: () => setState(() {})),
    ];

    return Scaffold(
      appBar: MyAppBar(
        title: UserRoles.label(user.role, locale),
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    switch (user.role) {
      case UserRoles.admin:
        return const AdminDashboard();
      case UserRoles.carRenter:
        return DriverDashboard(user: user);
      case UserRoles.carOwner:
      default:
        return OwnerDashboard(user: user);
    }
  }
}

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key, required this.user});

  final User user;

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  late Future<List<Car>> _carsFuture;
  late Future<List<Reservation>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _carsFuture = CarRepository.instance.getCarsByOwner(widget.user.id);
    _reservationsFuture = ReservationRepository.instance.getReservationsByOwner(
      widget.user.id,
    );
  }

  Future<void> _reloadCars() async {
    setState(() {
      _carsFuture = CarRepository.instance.getCarsByOwner(widget.user.id);
      _reservationsFuture = ReservationRepository.instance
          .getReservationsByOwner(widget.user.id);
    });
  }

  Future<void> _addCar() async {
    final created = await showDialog<Car>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AddCarDialog(owner: widget.user, fallbackRegistrationNumber: 'NEW'),
    );

    if (created != null) {
      await CarRepository.instance.insertCar(created);
      await _reloadCars();
    }
  }

  Future<void> _editCar(Car car) async {
    final updated = await showDialog<Car>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddCarDialog(
        owner: widget.user,
        fallbackRegistrationNumber: car.registrationNumber,
        initialCar: car,
      ),
    );
    if (updated == null) return;
    await CarRepository.instance.updateCar(updated);
    await _reloadCars();
  }

  Future<void> _deleteCar(Car car) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${car.brand} ${car.model}?'),
        content: const Text('This also deletes its local reservations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await CarRepository.instance.deleteCar(car.id);
    await _reloadCars();
  }

  Future<void> _toggleCarAvailability(Car car) async {
    await CarRepository.instance.updateCar(
      car.copyWith(isAvailable: !car.isAvailable, updatedAt: DateTime.now()),
    );
    await _reloadCars();
  }

  Future<void> _approveReservation(Reservation reservation) async {
    try {
      await ReservationRepository.instance.approveReservation(reservation.id);
      await _reloadCars();
    } on ReservationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectReservation(Reservation reservation) async {
    await ReservationRepository.instance.rejectReservation(reservation.id);
    await _reloadCars();
  }

  Future<void> _startReservation(Reservation reservation) async {
    await ReservationRepository.instance.startReservation(reservation.id);
    await _reloadCars();
  }

  Future<void> _completeReservation(Reservation reservation) async {
    await ReservationRepository.instance.completeReservation(reservation.id);
    await _reloadCars();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Fleet dashboard',
      action: ElevatedButton.icon(
        onPressed: _addCar,
        icon: const Icon(Icons.add),
        label: const Text('Add car'),
      ),
      children: [
        FutureBuilder<List<Object>>(
          future: Future.wait([_carsFuture, _reservationsFuture]),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final cars = data == null ? const <Car>[] : data[0] as List<Car>;
            final reservations = data == null
                ? const <Reservation>[]
                : data[1] as List<Reservation>;
            final pending = reservations
                .where((item) => item.status == ReservationStatus.pending)
                .toList();
            final awaitingPayment = reservations
                .where(
                  (item) => item.status == ReservationStatus.awaitingPayment,
                )
                .toList();
            final approved = reservations
                .where((item) => item.status == ReservationStatus.approved)
                .toList();
            final active = reservations
                .where((item) => item.status == ReservationStatus.active)
                .toList();
            final earnings = reservations
                .where(
                  (item) =>
                      item.status == ReservationStatus.approved ||
                      item.status == ReservationStatus.active ||
                      item.status == ReservationStatus.completed,
                )
                .fold<double>(
                  0,
                  (sum, item) =>
                      sum +
                      (item.status == ReservationStatus.completed
                          ? item.totalCost
                          : item.depositPaid
                          ? item.depositAmount
                          : 0),
                );
            final totalBookings = reservations
                .where((item) => !item.isTerminal || item.isCompleted)
                .length;
            final topCars = [...cars]
              ..sort(
                (a, b) =>
                    b.reservedDates.length.compareTo(a.reservedDates.length),
              );

            if (snapshot.connectionState == ConnectionState.waiting &&
                cars.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatGrid(
                  stats: [
                    StatData('Cars', '${cars.length}', Icons.directions_car),
                    StatData(
                      'Bookings',
                      '$totalBookings',
                      Icons.event_available,
                    ),
                    StatData(
                      'Earnings',
                      '${earnings.toStringAsFixed(0)} DT',
                      Icons.payments,
                    ),
                  ],
                ),
                const SectionTitle(title: 'Pending requests'),
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No pending booking requests.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  ...pending.map(
                    (reservation) => ReservationListTile(
                      reservation: reservation,
                      actions: [
                        IconButton(
                          tooltip: 'Approve',
                          onPressed: () => _approveReservation(reservation),
                          icon: const Icon(Icons.check_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () => _rejectReservation(reservation),
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                      ],
                    ),
                  ),
                ReservationSection(
                  title: 'Awaiting renter payment',
                  reservations: awaitingPayment,
                  emptyText: 'No bookings are waiting for deposit payment.',
                ),
                const SectionTitle(title: 'Paid bookings'),
                if (approved.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No approved bookings yet.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  ...approved.map(
                    (reservation) => ReservationListTile(
                      reservation: reservation,
                      actions: [
                        IconButton(
                          tooltip: 'Start rental',
                          onPressed: () => _startReservation(reservation),
                          icon: const Icon(Icons.play_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ReservationSection(
                  title: 'Active rentals',
                  reservations: active,
                  emptyText: 'No active rentals.',
                  actionBuilder: (reservation) => [
                    IconButton(
                      tooltip: 'Complete rental',
                      onPressed: () => _completeReservation(reservation),
                      icon: const Icon(Icons.check_circle_outline),
                    ),
                  ],
                ),
                SectionTitle(
                  title: 'My cars',
                  trailing: 'Calendar available on every car',
                ),
                if (cars.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No cars found for this account yet.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  ...cars.map(
                    (car) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarListTile(
                        car: car,
                        onOpen: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SingleCarPage(car: car),
                            ),
                          );
                          await _reloadCars();
                        },
                        onCalendar: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ReservationCalendarPage(car: car, readOnly: true),
                          ),
                        ),
                        onEdit: () => _editCar(car),
                        onDelete: () => _deleteCar(car),
                        onToggleAvailability: () => _toggleCarAvailability(car),
                      ),
                    ),
                  ),
                const SectionTitle(title: 'Top cars'),
                if (topCars.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No top cars to display yet.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  ...topCars
                      .take(3)
                      .map(
                        (car) => ListTile(
                          leading: const Icon(Icons.trending_up),
                          title: Text('${car.brand} ${car.model}'),
                          subtitle: Text(
                            '${car.reservedDates.length} reserved days',
                          ),
                          trailing: Text(
                            '${car.price.toStringAsFixed(0)} ${car.currency}',
                          ),
                        ),
                      ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class AddCarDialog extends StatefulWidget {
  const AddCarDialog({
    super.key,
    required this.owner,
    required this.fallbackRegistrationNumber,
    this.initialCar,
  });

  final User owner;
  final String fallbackRegistrationNumber;
  final Car? initialCar;

  @override
  State<AddCarDialog> createState() => _AddCarDialogState();
}

class _AddCarDialogState extends State<AddCarDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _brandController = TextEditingController(
    text: widget.initialCar?.brand ?? '',
  );
  late final TextEditingController _modelController = TextEditingController(
    text: widget.initialCar?.model ?? '',
  );
  late final TextEditingController _priceController = TextEditingController(
    text: widget.initialCar?.price.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _imageController = TextEditingController(
    text: widget.initialCar?.image ?? '',
  );
  late final TextEditingController _mileageController = TextEditingController(
    text: widget.initialCar?.mileage.toString() ?? '',
  );
  late final TextEditingController _yearController = TextEditingController(
    text: (widget.initialCar?.year ?? DateTime.now().year).toString(),
  );
  late final TextEditingController _seatsController = TextEditingController(
    text: (widget.initialCar?.seats ?? 5).toString(),
  );
  late final TextEditingController _transmissionController =
      TextEditingController(text: widget.initialCar?.gearbox ?? 'Automatic');
  late final TextEditingController _fuelController = TextEditingController(
    text: widget.initialCar?.fuel ?? 'Petrol',
  );
  late final TextEditingController _registrationController =
      TextEditingController(text: widget.initialCar?.registrationNumber ?? '');
  late final TextEditingController _colorController = TextEditingController(
    text: widget.initialCar?.color ?? 'White',
  );
  late final TextEditingController _locationController = TextEditingController(
    text: widget.initialCar?.location ?? widget.owner.location,
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initialCar?.description ?? '');

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _mileageController.dispose();
    _yearController.dispose();
    _seatsController.dispose();
    _transmissionController.dispose();
    _fuelController.dispose();
    _registrationController.dispose();
    _colorController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _requiredText(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    return null;
  }

  String? _requiredNumber(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    if (num.tryParse(value!.trim()) == null) return 'Use a number';
    return null;
  }

  String? _requiredInteger(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Required';
    if (int.tryParse(value!.trim()) == null) return 'Use a whole number';
    return null;
  }

  String? _positivePrice(String? value) {
    final basic = _requiredNumber(value);
    if (basic != null) return basic;
    final price = double.parse(value!.trim());
    if (price <= 0) return 'Must be greater than 0';
    return null;
  }

  String? _validYear(String? value) {
    final basic = _requiredNumber(value);
    if (basic != null) return basic;
    final year = int.parse(value!.trim());
    final nextYear = DateTime.now().year + 1;
    if (year < 1980 || year > nextYear) return 'Use a valid year';
    return null;
  }

  String? _validMileage(String? value) {
    final basic = _requiredNumber(value);
    if (basic != null) return basic;
    if (int.parse(value!.trim()) < 0) return 'Cannot be negative';
    return null;
  }

  String? _validSeats(String? value) {
    final basic = _requiredNumber(value);
    if (basic != null) return basic;
    final seats = int.parse(value!.trim());
    if (seats < 1) return 'At least 1 seat';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final image = _imageController.text.trim();
    Navigator.pop(
      context,
      Car(
        id: widget.initialCar?.id ?? 'local-car-${now.microsecondsSinceEpoch}',
        ownerId: widget.owner.id,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: int.tryParse(_yearController.text.trim()) ?? now.year,
        price: double.tryParse(_priceController.text.trim()) ?? 80,
        currency: 'DT',
        image: image.isEmpty ? 'kia-rio.jpg' : image,
        color: _colorController.text.trim().isEmpty
            ? 'White'
            : _colorController.text.trim(),
        seats: int.tryParse(_seatsController.text.trim()) ?? 5,
        gearbox: _transmissionController.text.trim().isEmpty
            ? 'Automatic'
            : _transmissionController.text.trim(),
        fuel: _fuelController.text.trim().isEmpty
            ? 'Petrol'
            : _fuelController.text.trim(),
        mileage: int.tryParse(_mileageController.text.trim()) ?? 0,
        description: _descriptionController.text.trim().isEmpty
            ? 'New owner listing'
            : _descriptionController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? widget.owner.location
            : _locationController.text.trim(),
        isAvailable: widget.initialCar?.isAvailable ?? true,
        createdAt: widget.initialCar?.createdAt ?? now,
        updatedAt: now,
        user: widget.owner,
        registrationNumber: _registrationController.text.trim().isEmpty
            ? widget.fallbackRegistrationNumber
            : _registrationController.text.trim(),
        reservedDates: widget.initialCar?.reservedDates ?? [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final maxDialogWidth = screenSize.width < 620
        ? screenSize.width - 24
        : 720.0;
    final maxDialogHeight = screenSize.height * 0.88;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialCar == null ? 'Add car' : 'Edit car',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Complete the listing details renters need to trust it.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final twoColumns = constraints.maxWidth >= 560;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AddCarField(
                            controller: _imageController,
                            label: 'Image URL or asset filename',
                            hint: 'https://... or kia-rio.jpg',
                            icon: Icons.image_outlined,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          ResponsiveFieldRow(
                            twoColumns: twoColumns,
                            children: [
                              AddCarField(
                                controller: _brandController,
                                label: 'Brand',
                                icon: Icons.directions_car_outlined,
                                validator: _requiredText,
                              ),
                              AddCarField(
                                controller: _modelController,
                                label: 'Model',
                                icon: Icons.badge_outlined,
                                validator: _requiredText,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ResponsiveFieldRow(
                            twoColumns: twoColumns,
                            children: [
                              AddCarField(
                                controller: _priceController,
                                label: 'Daily price',
                                icon: Icons.payments_outlined,
                                keyboardType: TextInputType.number,
                                validator: _positivePrice,
                              ),
                              AddCarField(
                                controller: _registrationController,
                                label: 'Registration number',
                                icon: Icons.confirmation_number_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ResponsiveFieldRow(
                            twoColumns: twoColumns,
                            children: [
                              AddCarField(
                                controller: _yearController,
                                label: 'First registration',
                                icon: Icons.calendar_month_outlined,
                                keyboardType: TextInputType.number,
                                 validator: _requiredInteger,
                              ),
                              AddCarField(
                                controller: _mileageController,
                                label: 'Mileage',
                                icon: Icons.speed_outlined,
                                keyboardType: TextInputType.number,
                                 validator: _requiredInteger,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ResponsiveFieldRow(
                            twoColumns: twoColumns,
                            children: [
                              AddCarField(
                                controller: _seatsController,
                                label: 'Seats',
                                icon: Icons.event_seat_outlined,
                                keyboardType: TextInputType.number,
                                 validator: _requiredInteger,
                              ),
                              AddCarField(
                                controller: _transmissionController,
                                label: 'Transmission',
                                icon: Icons.settings_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ResponsiveFieldRow(
                            twoColumns: twoColumns,
                            children: [
                              AddCarField(
                                controller: _fuelController,
                                label: 'Fuel',
                                icon: Icons.local_gas_station_outlined,
                              ),
                              AddCarField(
                                controller: _colorController,
                                label: 'Color',
                                icon: Icons.palette_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AddCarField(
                            controller: _locationController,
                            label: 'Location',
                            icon: Icons.location_on_outlined,
                          ),
                          const SizedBox(height: 12),
                          AddCarField(
                            controller: _descriptionController,
                            label: 'Description',
                            icon: Icons.notes_outlined,
                            maxLines: 3,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.add),
                      label: Text(
                        widget.initialCar == null ? 'Add car' : 'Save',
                      ),
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

class ResponsiveFieldRow extends StatelessWidget {
  const ResponsiveFieldRow({
    super.key,
    required this.twoColumns,
    required this.children,
  });

  final bool twoColumns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!twoColumns) {
      return Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            children[index],
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 12),
        Expanded(child: children[1]),
      ],
    );
  }
}

class AddCarField extends StatelessWidget {
  const AddCarField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      textInputAction: maxLines == 1
          ? textInputAction
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key, required this.user});

  final User user;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  late Future<List<Reservation>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = ReservationRepository.instance
        .getReservationsByRenter(widget.user.id);
  }

  void _reloadReservations() {
    setState(() {
      _reservationsFuture = ReservationRepository.instance
          .getReservationsByRenter(widget.user.id);
    });
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    await ReservationRepository.instance.cancelReservation(reservation.id);
    _reloadReservations();
  }

  Future<void> _payDeposit(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay 10% deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${reservation.totalCost.toStringAsFixed(0)} DT'),
            const SizedBox(height: 8),
            Text(
              'Deposit: ${reservation.depositAmount.toStringAsFixed(0)} DT',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'This is a local test payment. No real money is charged.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pay deposit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ReservationRepository.instance.payDeposit(reservation.id);
      _reloadReservations();
    } on ReservationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoodRental = widget.user.rating >= 4 && widget.user.coins >= 100;

    return DashboardShell(
      title: 'Rental dashboard',
      children: [
        FutureBuilder<List<Reservation>>(
          future: _reservationsFuture,
          builder: (context, snapshot) {
            final reservations = snapshot.data ?? const <Reservation>[];
            final pending = reservations
                .where((item) => item.status == ReservationStatus.pending)
                .toList();
            final awaitingPayment = reservations
                .where(
                  (item) => item.status == ReservationStatus.awaitingPayment,
                )
                .toList();
            final approved = reservations
                .where((item) => item.status == ReservationStatus.approved)
                .toList();
            final closed = reservations
                .where(
                  (item) =>
                      item.status == ReservationStatus.cancelled ||
                      item.status == ReservationStatus.rejected ||
                      item.status == ReservationStatus.completed,
                )
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatGrid(
                  stats: [
                    StatData(
                      'Requests',
                      '${reservations.length}',
                      Icons.history,
                    ),
                    StatData('Coins', '${widget.user.coins}', Icons.paid),
                    StatData(
                      'Rating',
                      widget.user.rating.toStringAsFixed(1),
                      Icons.star,
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isGoodRental
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isGoodRental ? Icons.verified : Icons.info_outline,
                        color: isGoodRental ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isGoodRental
                              ? 'Good rental status active'
                              : 'Build your rating and coins to unlock good rental status',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                ReservationSection(
                  title: 'Pending requests',
                  reservations: pending,
                  emptyText: 'No pending requests.',
                  actionBuilder: (reservation) => [
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: () => _cancelReservation(reservation),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ],
                ),
                ReservationSection(
                  title: 'Awaiting payment',
                  reservations: awaitingPayment,
                  emptyText: 'No reservations waiting for payment.',
                  leadingBuilder: (reservation) => _PaymentPromptCard(
                    reservation: reservation,
                    onPay: () => _payDeposit(reservation),
                  ),
                  actionBuilder: (reservation) => [
                    FilledButton.icon(
                      onPressed: () => _payDeposit(reservation),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Pay 10%'),
                    ),
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: () => _cancelReservation(reservation),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ],
                ),
                ReservationSection(
                  title: 'Approved bookings',
                  reservations: approved,
                  emptyText: 'No approved bookings.',
                  actionBuilder: (reservation) => [
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: () => _cancelReservation(reservation),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ],
                ),
                ReservationSection(
                  title: 'History',
                  reservations: closed,
                  emptyText: 'No closed reservations yet.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Admin dashboard',
      children: [
        FutureBuilder<List<Object>>(
          future: Future.wait([
            Future<List<User>>.value(LocalAuthService.instance.users),
            CarRepository.instance.getAllCars(),
            ReservationRepository.instance.getAllReservations(),
          ]),
          builder: (context, snapshot) {
            final data = snapshot.data;
            final users = data == null ? const <User>[] : data[0] as List<User>;
            final cars = data == null ? const <Car>[] : data[1] as List<Car>;
            final reservations = data == null
                ? const <Reservation>[]
                : data[2] as List<Reservation>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatGrid(
                  stats: [
                    StatData('Users', '${users.length}', Icons.people),
                    StatData('Cars', '${cars.length}', Icons.directions_car),
                    StatData(
                      'Bookings',
                      '${reservations.length}',
                      Icons.event_available,
                    ),
                  ],
                ),
                const SectionTitle(title: 'User management'),
                ...users.map(
                  (user) => UserAdminTile(
                    user: user,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SectionTitle(title: 'Cars'),
                if (cars.isEmpty)
                  const Text(
                    'No cars listed.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  ...cars.map(
                    (car) => CarListTile(
                      car: car,
                      onOpen: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SingleCarPage(car: car),
                        ),
                      ),
                      onCalendar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ReservationCalendarPage(car: car, readOnly: true),
                        ),
                      ),
                      onDelete: () async {
                        await CarRepository.instance.deleteCar(car.id);
                        setState(() {});
                      },
                    ),
                  ),
                ReservationSection(
                  title: 'Reservations',
                  reservations: reservations,
                  emptyText: 'No reservations yet.',
                  actionBuilder: (reservation) => [
                    if (reservation.status != ReservationStatus.cancelled &&
                        reservation.status != ReservationStatus.rejected)
                      IconButton(
                        tooltip: 'Cancel',
                        onPressed: () async {
                          await ReservationRepository.instance
                              .cancelReservation(reservation.id);
                          setState(() {});
                        },
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class UserAdminTile extends StatelessWidget {
  const UserAdminTile({super.key, required this.user, required this.onChanged});

  final User user;
  final VoidCallback onChanged;

  Future<void> _rate(BuildContext context) async {
    final nextRating = await showDialog<double>(
      context: context,
      builder: (context) {
        double rating = user.rating == 0 ? 3 : user.rating;
        return AlertDialog(
          title: Text('Rate ${user.name}'),
          content: StatefulBuilder(
            builder: (context, setDialogState) => Slider(
              value: rating,
              min: 0,
              max: 5,
              divisions: 10,
              label: rating.toStringAsFixed(1),
              onChanged: (value) => setDialogState(() => rating = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, rating),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (nextRating == null) return;
    await LocalAuthService.instance.rateUser(user.email, nextRating);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == UserRoles.admin;
    final locale = AppLocalizations.of(context).locale;
    return ListTile(
      leading: CircleAvatar(
        child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person),
      ),
      title: Text(user.name),
      subtitle: Text(
        '${UserRoles.label(user.role, locale)} - ${user.email} - ${user.rating.toStringAsFixed(1)} stars',
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Rate',
            onPressed: () => _rate(context),
            icon: const Icon(Icons.star_rate),
          ),
          IconButton(
            tooltip: user.isBlocked ? 'Unblock' : 'Block',
            onPressed: isAdmin
                ? null
                : () async {
                    await LocalAuthService.instance.toggleBlocked(user.email);
                    onChanged();
                  },
            icon: Icon(user.isBlocked ? Icons.lock_open : Icons.block),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: isAdmin
                ? null
                : () async {
                    await LocalAuthService.instance.deleteUser(user.email);
                    onChanged();
                  },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, required this.onUpdated});

  final User user;
  final VoidCallback onUpdated;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _locationController = TextEditingController(text: widget.user.location);
    _addressController = TextEditingController(text: widget.user.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await LocalAuthService.instance.updateUser(
      widget.user.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        address: _addressController.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );
    widget.onUpdated();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).locale;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 44,
          child: Text(
            widget.user.name.isEmpty ? '?' : widget.user.name[0].toUpperCase(),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            UserRoles.label(widget.user.role, locale),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.mail_outline),
            hintText: widget.user.email,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
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
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: Icon(Icons.home_outlined),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save profile'),
        ),
      ],
    );
  }
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.stats});

  final List<StatData> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(stat.icon),
              const SizedBox(height: 8),
              Text(
                stat.value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatData {
  const StatData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ),
    );
  }
}

class CarListTile extends StatelessWidget {
  const CarListTile({
    super.key,
    required this.car,
    required this.onOpen,
    required this.onCalendar,
    this.onEdit,
    this.onDelete,
    this.onToggleAvailability,
  });

  final Car car;
  final VoidCallback onOpen;
  final VoidCallback onCalendar;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleAvailability;

  @override
  Widget build(BuildContext context) {
    final statusColor = car.isAvailable
        ? const Color(0xFF15803D)
        : const Color(0xFFB45309);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CarImage(
                  image: car.image,
                  width: 92,
                  height: 72,
                  fit: BoxFit.cover,
                  fallbackSize: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${car.brand} ${car.model}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            car.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _CarMeta(
                          icon: Icons.payments_outlined,
                          text:
                              '${car.price.toStringAsFixed(0)} ${car.currency}/day',
                        ),
                        _CarMeta(
                          icon: Icons.event_available_outlined,
                          text: '${car.reservedDates.length} reserved days',
                        ),
                        _CarMeta(
                          icon: Icons.speed_outlined,
                          text: '${car.mileage} km',
                        ),
                        _CarMeta(
                          icon: Icons.location_on_outlined,
                          text: car.location,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 4,
                        children: [
                          if (onToggleAvailability != null)
                            IconButton.filledTonal(
                              tooltip: car.isAvailable
                                  ? 'Mark unavailable'
                                  : 'Mark available',
                              onPressed: onToggleAvailability,
                              icon: Icon(
                                car.isAvailable
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          if (onEdit != null)
                            IconButton.filledTonal(
                              tooltip: 'Edit',
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          IconButton.filledTonal(
                            tooltip: 'Calendar',
                            onPressed: onCalendar,
                            icon: const Icon(Icons.calendar_month),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Open',
                            onPressed: onOpen,
                            icon: const Icon(Icons.open_in_new),
                          ),
                          if (onDelete != null)
                            IconButton.filledTonal(
                              tooltip: 'Delete',
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarMeta extends StatelessWidget {
  const _CarMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
      ],
    );
  }
}

class ReservationSection extends StatelessWidget {
  const ReservationSection({
    super.key,
    required this.title,
    required this.reservations,
    required this.emptyText,
    this.leadingBuilder,
    this.actionBuilder,
  });

  final String title;
  final List<Reservation> reservations;
  final String emptyText;
  final Widget Function(Reservation reservation)? leadingBuilder;
  final List<Widget> Function(Reservation reservation)? actionBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: title),
        if (reservations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              emptyText,
              style: const TextStyle(color: Colors.black54),
            ),
          )
        else
          ...reservations.map(
            (reservation) => Column(
              children: [
                if (leadingBuilder != null) leadingBuilder!(reservation),
                ReservationListTile(
                  reservation: reservation,
                  actions: actionBuilder?.call(reservation),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ReservationListTile extends StatelessWidget {
  const ReservationListTile({
    super.key,
    required this.reservation,
    this.actions,
  });

  final Reservation reservation;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final car = reservation.car;
    final renter = reservation.renter;
    final title = car == null
        ? 'Reservation ${reservation.id}'
        : '${car.brand} ${car.model}';
    final person = renter == null ? '' : ' - ${renter.name}';
    final depositState = reservation.depositPaid
        ? 'deposit paid'
        : 'deposit due ${reservation.depositAmount.toStringAsFixed(0)} DT';
    return ListTile(
      leading: Icon(_statusIcon(reservation.status)),
      title: Text(title),
      subtitle: Text(
        '${_formatDate(reservation.startDate)} to ${_formatDate(reservation.endDate)} at ${reservation.pickupTime}$person\n'
        '${reservation.totalDays} days - total ${reservation.totalCost.toStringAsFixed(0)} DT - $depositState - ${_statusLabel(reservation.status)}',
      ),
      isThreeLine: true,
      trailing: actions == null || actions!.isEmpty
          ? null
          : Wrap(spacing: 4, children: actions!),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case ReservationStatus.awaitingPayment:
        return Icons.payments_outlined;
      case ReservationStatus.approved:
        return Icons.check_circle_outline;
      case ReservationStatus.rejected:
        return Icons.cancel_outlined;
      case ReservationStatus.cancelled:
        return Icons.remove_circle_outline;
      case ReservationStatus.completed:
        return Icons.done_all;
      case ReservationStatus.pending:
      default:
        return Icons.hourglass_empty;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case ReservationStatus.awaitingPayment:
        return 'awaiting payment';
      case ReservationStatus.approved:
        return 'approved';
      case ReservationStatus.rejected:
        return 'rejected';
      case ReservationStatus.cancelled:
        return 'cancelled';
      case ReservationStatus.completed:
        return 'completed';
      case ReservationStatus.pending:
      default:
        return 'pending';
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _PaymentPromptCard extends StatelessWidget {
  const _PaymentPromptCard({required this.reservation, required this.onPay});

  final Reservation reservation;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final car = reservation.car;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  car == null
                      ? 'Payment required'
                      : 'Payment required for ${car.brand} ${car.model}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pay ${reservation.depositAmount.toStringAsFixed(0)} DT now to confirm this booking. Total rental cost is ${reservation.totalCost.toStringAsFixed(0)} DT.',
            style: const TextStyle(color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Pay 10% deposit'),
            ),
          ),
        ],
      ),
    );
  }
}
