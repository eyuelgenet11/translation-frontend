import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api_service.dart';
import 'upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> filteredCompanies = [];
  bool loading = true;
  final TextEditingController searchController = TextEditingController();

  final List<String> topOffices = [
    'assets/images/com1.jpg',
    'assets/images/com2.jpg',
    'assets/images/com3.jpg',
    'assets/images/com4.jpg',
    'assets/images/com5.jpg',
    'assets/images/com6.jpg',
    'assets/images/com7.png',
    'assets/images/com8.jpg',
    'assets/images/com9.png',
    'assets/images/com10.jpg',
  ];

  final List<String> specialOfferAssets = [
    'assets/images/a.png',
    'assets/images/com2.jpg',
    'assets/images/com3.jpg',
    'assets/images/com4.jpg',
    'assets/images/com5.jpg',
  ];

  @override
  void initState() {
    super.initState();
    fetchCompanies();
  }

  Future<void> fetchCompanies() async {
    try {
      final result = await ApiService.getCompanies();
      final companiesList = List<Map<String, dynamic>>.from(result);

      if (companiesList.length < 10) {
        companiesList.addAll(ApiService.dummyCompanies());
      }

      setState(() {
        companies = companiesList;
        filteredCompanies = companiesList;
        loading = false;
      });
    } catch (e) {
      setState(() {
        companies = ApiService.dummyCompanies();
        filteredCompanies = ApiService.dummyCompanies();
        loading = false;
      });
      debugPrint('Error fetching companies: $e');
    }
  }

  void filterCompanies(String query) {
    final results = companies.where((company) {
      final name = company['business_name']?.toString().toLowerCase() ?? '';
      return name.contains(query.toLowerCase());
    }).toList();
    setState(() => filteredCompanies = results);
  }

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFF895129);
    const Color accentColor = Color(0xFFD8B88A);
    const Color backgroundColor = Color(0xFFF9F5F2);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(160),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Rounded AppBar background
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.9),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Text(
                    'Translation Marketplace',
                    style: GoogleFonts.dancingScript(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // Floating logo
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/gslogo.png',
                      height: 76,
                      width: 76,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: brandColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Translation Companies...',
                      prefixIcon: const Icon(Icons.search, color: brandColor),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(
                          color: brandColor.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: brandColor,
                          width: 1.2,
                        ),
                      ),
                    ),
                    onChanged: filterCompanies,
                  ),
                  const SizedBox(height: 25),

                  // Top Offices Carousel
                  Text(
                    'Top Translation Offices',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: brandColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CarouselSlider.builder(
                    itemCount: topOffices.length,
                    itemBuilder: (context, index, realIdx) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            topOffices[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.business, size: 60),
                          ),
                        ),
                      );
                    },
                    options: CarouselOptions(
                      height: 180,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 5),
                      autoPlayAnimationDuration: const Duration(
                        milliseconds: 800,
                      ),
                      enlargeCenterPage: true,
                      viewportFraction: 0.8,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Special Offers
                  Text(
                    'Special Offers 🎉',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: brandColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: specialOfferAssets.length,
                      itemBuilder: (context, index) {
                        final company = companies.length > index
                            ? companies[index]
                            : null;
                        return Container(
                          width: 220,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: accentColor, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: AssetImage(
                                    company?['image_url'] ??
                                        specialOfferAssets[index],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  company?['business_name'] ??
                                      "Company ${index + 1}",
                                  style: GoogleFonts.roboto(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: brandColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Up to ${15 + index * 5}% OFF",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.roboto(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Company List
                  Text(
                    "All Translation Companies",
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: brandColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...filteredCompanies.asMap().entries.map((entry) {
                    int idx = entry.key;
                    Map<String, dynamic> company = entry.value;
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UploadScreen(company: company),
                          ),
                        );
                      },
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  company['image_url'] ??
                                      topOffices[idx % topOffices.length],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.business, size: 40),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      company['business_name'] ??
                                          'Unnamed Company',
                                      style: GoogleFonts.roboto(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      company['address'] ??
                                          'Address not provided',
                                      style: GoogleFonts.roboto(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Languages: ${company['languages_supported']?.join(', ') ?? '-'}',
                                      style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  Text(
                                    (company['rating'] is num)
                                        ? (company['rating'] as num)
                                              .toStringAsFixed(1)
                                        : '0.0',
                                    style: GoogleFonts.roboto(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 70),
                ],
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        color: brandColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/history'),
                icon: const Icon(Icons.history, color: Colors.white),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/profile'),
                icon: const Icon(Icons.person, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
