import 'package:flutter/material.dart';
import 'package:ikrili/presentation/widgets/car_image.dart';
import 'package:ikrili/data/repositories/car_repository.dart';
import '../../domain/entities/car.dart';
import '../../domain/entities/user.dart';
import '../widgets/app_bar.dart';
import 'package:flutter_rating_stars/flutter_rating_stars.dart';

class SingleRenterPage extends StatefulWidget {
  final User renter;

  const SingleRenterPage({super.key, required this.renter});

  @override
  State<SingleRenterPage> createState() => _SingleRenterPageState();
}

class _SingleRenterPageState extends State<SingleRenterPage> {
  List<Car> _cars = const [];

  @override
  void initState() {
    super.initState();
    _cars = widget.renter.cars;
    _loadCars();
  }

  Future<void> _loadCars() async {
    try {
      final cars = await CarRepository.instance.getCarsByOwner(widget.renter.id);
      if (mounted) setState(() => _cars = cars);
    } catch (_) {
      // Keep any cars passed in the initial profile snapshot.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(
        title: widget.renter.name,
        showBackButton: true,
        backgroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      widget.renter.image.isNotEmpty
                          ? 'assets/images/users/${widget.renter.image}'
                          : 'assets/images/default_user.png', // Assume a default image
                      fit: BoxFit.cover,
                      width: 150,
                      height: 150,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Renter Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.renter.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Rating(rating: widget.renter.rating),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.renter.location,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Joined Date
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Customer of Ikrili since ${widget.renter.createdAt.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Divider
                    Container(height: 1, color: Colors.grey[300]),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Their Cars Section
              if (_cars.isNotEmpty) ...[
                Text(
                  'Their Cars',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                   itemCount: _cars.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                     final car = _cars[index];
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Car Image
                          Container(
                            width: 80,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CarImage(
                              image: car.image,
                              fit: BoxFit.cover,
                              fallbackSize: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Car Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      car.brand,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      car.model,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${car.price} ${car.currency} / day',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else ...[
                const Text(
                  'No cars listed yet.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
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
