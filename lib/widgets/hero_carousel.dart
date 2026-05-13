import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';

class HeroCarousel extends StatelessWidget {
  final Color brandBrown;

  const HeroCarousel({super.key, required this.brandBrown});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> slides = [
      {
        'url': 'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?q=80&w=1000',
        'title': "Ge'ez Legal Experts",
        'subtitle': "Certified translations for court & official use"
      },
      {
        'url': 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?q=80&w=1000',
        'title': "Medical Documents",
        'subtitle': "Specialized healthcare translation services"
      },
      {
        'url': 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=1000',
        'title': "Business Growth",
        'subtitle': "Localizing your brand for the Ethiopian market"
      },
    ];

    return CarouselSlider(
      options: CarouselOptions(
        height: 120.0,
        enlargeCenterPage: true,
        autoPlay: true,
        aspectRatio: 2.5,
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: true,
        autoPlayAnimationDuration: const Duration(milliseconds: 1000),
        viewportFraction: 0.8,
      ),
      items: slides.map((slide) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                color: brandBrown,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: brandBrown.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
                image: DecorationImage(
                  image: NetworkImage(slide['url']!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slide['title']!,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slide['subtitle']!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
