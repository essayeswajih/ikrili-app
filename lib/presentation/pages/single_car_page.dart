import 'package:flutter/material.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/data/services/local_auth_service.dart';
import 'package:ikrili/presentation/pages/single_renter_page.dart';
import 'package:ikrili/presentation/widgets/car_image.dart';
import '../../domain/entities/car.dart';
import '../widgets/app_bar.dart';
import 'package:flutter_rating_stars/flutter_rating_stars.dart';

import 'reservation_calendar_page.dart';

class SingleCarPage extends StatefulWidget {
  final Car car;

  const SingleCarPage({super.key, required this.car});

  @override
  State<SingleCarPage> createState() => _SingleCarPageState();
}

class _SingleCarPageState extends State<SingleCarPage> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final currentUser = LocalAuthService.instance.currentUser;
    final isOwner = currentUser?.id == widget.car.ownerId;
    final canReserve =
        widget.car.isAvailable && currentUser?.id != widget.car.ownerId;
    return Scaffold(
      appBar: MyAppBar(
        title: "Ikrili",
        showBackButton: true,
        backgroundColor: Colors.white,
      ),
      floatingActionButton: isOwner || canReserve
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReservationCalendarPage(car: widget.car),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_month),
              label: Text(isOwner ? 'Calendar' : 'Reserve'),
            )
          : null,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Car Image
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: CarImage(
                  image: widget.car.image,
                  fit: BoxFit.contain,
                  fallbackSize: 50,
                ),
              ),
              const SizedBox(height: 10),
              // Car Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.car.brand,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.car.model,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      strings.t('price'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.money_sharp),
                        const SizedBox(width: 5),
                        Text(
                          '${widget.car.price} ${widget.car.currency}',
                          style: const TextStyle(
                            fontSize: 26,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.t('per_day'),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.stadium_rounded),
                                    const SizedBox(width: 5),
                                    Text(
                                      strings.t('mileage'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 35),
                                    Text(
                                      "${widget.car.mileage} km",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.account_tree_sharp),
                                    const SizedBox(width: 5),
                                    Text(
                                      strings.t('transmission'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 35),
                                    Text(
                                      widget.car.gearbox,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month),
                                    const SizedBox(width: 5),
                                    Text(
                                      strings.t('first_registration'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 35),
                                    Text(
                                      "${widget.car.year}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.add_business),
                                    const SizedBox(width: 5),
                                    Text(
                                      strings.t('fuel_type'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 35),
                                    Text(
                                      widget.car.fuel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.event_seat),
                                    const SizedBox(width: 5),
                                    Text(
                                      strings.t('seats'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 35),
                                    Text(
                                      "${widget.car.seats}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.palette),
                                    const SizedBox(width: 5),
                                    Text(
                                      strings.t('color'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const SizedBox(width: 35),
                                    Text(
                                      widget.car.color,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      strings.t('registration_label'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.car.registrationNumber,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      strings.t('description'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.car.description,
                      style: const TextStyle(
                        height: 1.4,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              strings.t('renter'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Rating(rating: widget.car.user.rating),
                          ],
                        ),

                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SingleRenterPage(renter: widget.car.user),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.person),
                              const SizedBox(width: 5),
                              Text(
                                widget.car.user.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(Icons.location_on, size: 12),
                              const SizedBox(width: 1),
                              Text(
                                widget.car.location,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 5),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 35),
                            Text(
                              '${strings.t('customer_since')} ${widget.car.user.createdAt.year}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
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

class Rating extends StatelessWidget {
  final double
  rating; // Dynamic input: e.g., pass 4.2 when using <Rating rating={4.2} />

  const Rating({
    super.key,
    required this.rating, // Make it required for safety
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      // Wrap in Column to include Divider
      children: [
        RatingStars(
          starBuilder: (index, color) =>
              Icon(Icons.star, color: color, size: 17),
          starCount: 5,
          starSize: 17,
          value: rating, // Now dynamic—uses the passed value!
          valueLabelColor: const Color(0xff9b9b9b),
          valueLabelTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            fontSize: 10.0,
          ),
          valueLabelRadius: 10,
          maxValue: 5,
          starSpacing: .5,
          maxValueVisibility: true,
          valueLabelVisibility: true,
          animationDuration: const Duration(milliseconds: 1000),
          valueLabelPadding: const EdgeInsets.symmetric(
            vertical: .7,
            horizontal: 8,
          ),
          valueLabelMargin: const EdgeInsets.only(right: 8),
          starOffColor: const Color(0xffe7e8ea),
          starColor: Colors.yellow,
        ),
      ],
    );
  }
}
