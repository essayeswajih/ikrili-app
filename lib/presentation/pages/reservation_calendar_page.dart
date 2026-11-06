import 'package:flutter/material.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/data/repositories/reservation_repository.dart';
import 'package:ikrili/data/services/local_auth_service.dart';
import 'package:ikrili/domain/entities/car.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ReservationCalendarPage extends StatefulWidget {
  const ReservationCalendarPage({
    super.key,
    required this.car,
    this.readOnly = false,
  });

  final Car car;
  final bool readOnly;

  @override
  State<ReservationCalendarPage> createState() =>
      _ReservationCalendarPageState();
}

class _ReservationCalendarPageState extends State<ReservationCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  TimeOfDay? _pickupTime;
  int _totalDays = 0;
  double _totalCost = 0;
  late final Set<DateTime> _reservedDates;

  @override
  void initState() {
    super.initState();
    _reservedDates = widget.car.reservedDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _hasOverlap(DateTime start, DateTime end) {
    var current = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (current.isBefore(endDay) || current.isAtSameMomentAs(endDay)) {
      if (_reservedDates.contains(current)) return true;
      current = current.add(const Duration(days: 1));
    }
    return false;
  }

  void _showError(String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).t(key)),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _selectPickupTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted || selected == null) return;

    if (_rangeStart != null && _isToday(_rangeStart!)) {
      final now = DateTime.now();
      final pickupDt = DateTime(
        _rangeStart!.year,
        _rangeStart!.month,
        _rangeStart!.day,
        selected.hour,
        selected.minute,
      );
      if (pickupDt.isBefore(now.add(const Duration(hours: 2)))) {
        _showError('pickup_time_must_be_2h');
        return;
      }
    }

    setState(() => _pickupTime = selected);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final selectedOnly = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    if (selectedOnly.isBefore(todayOnly) ||
        _reservedDates.contains(selectedOnly)) {
      return;
    }

    setState(() {
      _focusedDay = focusedDay;
      if (_rangeEnd != null) {
        if (selectedOnly.isAtSameMomentAs(_rangeEnd!)) {
          _rangeEnd = null;
          _totalDays = 1;
          _totalCost = widget.car.price;
          return;
        }
        if (selectedOnly.isBefore(_rangeStart!)) {
          _showError('dropoff_before_pickup');
          return;
        }
        if (_hasOverlap(_rangeStart!, selectedOnly)) {
          _showError('overlap_dates');
          return;
        }
        _rangeEnd = selectedOnly;
      } else if (_rangeStart != null) {
        if (selectedOnly.isAtSameMomentAs(_rangeStart!)) {
          _rangeStart = null;
          _rangeEnd = null;
          _pickupTime = null;
          _totalDays = 0;
          _totalCost = 0;
          return;
        }
        if (selectedOnly.isBefore(_rangeStart!)) {
          _showError('dropoff_before_pickup');
          return;
        }
        if (_hasOverlap(_rangeStart!, selectedOnly)) {
          _showError('overlap_dates');
          return;
        }
        _rangeEnd = selectedOnly;
      } else {
        _rangeStart = selectedOnly;
        _rangeEnd = null;
        _pickupTime = null;
      }

      if (_rangeStart != null) {
        final end = _rangeEnd ?? _rangeStart!;
        _totalDays = end.difference(_rangeStart!).inDays + 1;
        _totalCost = _totalDays * widget.car.price;
      }
    });
  }

  Future<void> _confirmReservation() async {
    if (widget.readOnly) return;
    final strings = AppLocalizations.of(context);
    if (_rangeStart == null || _pickupTime == null) return;

    if (!LocalAuthService.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('sign_in_confirm_reservation'))),
      );
      final loggedIn = await Navigator.pushNamed(
        context,
        'login',
        arguments: {'returnToPrevious': true},
      );
      if (!mounted || loggedIn != true) return;
    }

    final currentUser = LocalAuthService.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.isBlocked) {
      _showErrorMessage('Blocked users cannot reserve cars.');
      return;
    }
    if (widget.car.ownerId == currentUser.id) {
      _showErrorMessage('You cannot reserve your own car.');
      return;
    }
    if (!widget.car.isAvailable) {
      _showErrorMessage('This car is currently unavailable.');
      return;
    }

    final pickupDt = DateTime(
      _rangeStart!.year,
      _rangeStart!.month,
      _rangeStart!.day,
      _pickupTime!.hour,
      _pickupTime!.minute,
    );
    final endDate = _rangeEnd ?? _rangeStart!;
    final dropoffDt = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      _pickupTime!.hour,
      _pickupTime!.minute,
    );

    final pickup = DateFormat('MMM dd, yyyy h:mm a').format(pickupDt);
    final dropoff = DateFormat('MMM dd, yyyy h:mm a').format(dropoffDt);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.t('confirm_reservation_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${strings.t('car')}: ${widget.car.brand} ${widget.car.model}',
            ),
            const SizedBox(height: 8),
            Text('${strings.t('pickup')}: $pickup'),
            const SizedBox(height: 4),
            Text('${strings.t('dropoff')}: $dropoff'),
            const SizedBox(height: 8),
            Text('${strings.t('total_days')}: $_totalDays'),
            const SizedBox(height: 8),
            Text(
              '${strings.t('total_cost')}: ${_totalCost.toStringAsFixed(2)} ${widget.car.currency}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.t('confirm')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    try {
      await ReservationRepository.instance.createReservation(
        car: widget.car,
        renter: currentUser,
        startDate: _rangeStart!,
        endDate: endDate,
        pickupTime: _pickupTime!.format(context),
      );
    } on ReservationException catch (error) {
      if (!mounted) return;
      _showErrorMessage(error.message);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reservation request sent to the owner.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, widget.car);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildReservedDay(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.red.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day);
    final lastDay = firstDay.add(const Duration(days: 365));
    final effectiveEnd = _rangeStart == null
        ? null
        : (_rangeEnd ?? _rangeStart!);

    var selectionText = strings.t('no_dates_selected');
    if (_rangeStart != null) {
      final start = DateFormat('MMM dd, yyyy').format(_rangeStart!);
      final time = _pickupTime == null
          ? ''
          : ' ${strings.t('starting_at')} ${_pickupTime!.format(context)}';
      if (_rangeEnd == null) {
        selectionText = '$start (${strings.t('same_day')})$time';
      } else {
        selectionText =
            '$start - ${DateFormat('MMM dd, yyyy').format(_rangeEnd!)}$time';
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          strings.t('select_reservation_dates'),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${strings.t('choose_dates_for')} ${widget.car.brand} ${widget.car.model}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TableCalendar<DateTime>(
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              rangeStartDay: _rangeStart,
              rangeEndDay: effectiveEnd,
              enabledDayPredicate: (day) {
                final dayOnly = DateTime(day.year, day.month, day.day);
                final todayOnly = DateTime(now.year, now.month, now.day);
                return !dayOnly.isBefore(todayOnly) &&
                    !_reservedDates.contains(dayOnly);
              },
               onDaySelected: widget.readOnly ? null : _onDaySelected,
              onPageChanged: (focusedDay) =>
                  setState(() => _focusedDay = focusedDay),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final dayOnly = DateTime(day.year, day.month, day.day);
                  if (_reservedDates.contains(dayOnly)) {
                    return _buildReservedDay(day);
                  }
                  return null;
                },
                disabledBuilder: (context, day, focusedDay) {
                  final dayOnly = DateTime(day.year, day.month, day.day);
                  if (_reservedDates.contains(dayOnly)) {
                    return _buildReservedDay(day);
                  }
                  return null;
                },
              ),
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                rangeStartDecoration: BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                withinRangeDecoration: BoxDecoration(
                  color: Color(0xFFE8F5E8),
                  shape: BoxShape.rectangle,
                ),
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: Colors.red),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              selectionText,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            if (_rangeStart == null)
              Center(
                child: Text(
                  strings.t('select_pickup_date'),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else if (widget.readOnly)
              const Text('Owner calendar view: dates are read-only.')
            else if (_pickupTime == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectPickupTime,
                  child: Text(strings.t('select_pickup_time')),
                ),
              )
            else ...[
              Text('${strings.t('pickup')}: ${_pickupTime!.format(context)}'),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${strings.t('total_days')}: $_totalDays'),
                      const SizedBox(height: 8),
                      Text(
                        '${strings.t('total_cost')}: ${_totalCost.toStringAsFixed(2)} ${widget.car.currency}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmReservation,
                  child: Text(strings.t('confirm_reservation_title')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
