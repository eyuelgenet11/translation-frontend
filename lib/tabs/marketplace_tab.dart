import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/how_to_guide.dart';
import '../widgets/empty_state.dart';

class MarketplaceTab extends StatelessWidget {
  final List<Map<String, dynamic>> filteredTranslators;
  final List<Map<String, dynamic>> recommendedTranslators;
  final bool loading;
  final String selectedCategory;
  final TextEditingController searchController;
  final String? avatarUrl;
  final String? userName;
  final Color brandBrown;
  final Color bgTheme;
  final Color surfaceTheme;
  final Color textMainTheme;
  final Color textSecTheme;
  
  final Function(String) onCategoryChanged;
  final VoidCallback onSearchChanged;
  final Function(Map<String, dynamic>) onTranslatorTapped;
  final VoidCallback onProfileTapped;
  final VoidCallback onLanguageToggle;

  const MarketplaceTab({
    super.key,
    required this.filteredTranslators,
    required this.recommendedTranslators,
    required this.loading,
    required this.selectedCategory,
    required this.searchController,
    required this.avatarUrl,
    required this.userName,
    required this.brandBrown,
    required this.bgTheme,
    required this.surfaceTheme,
    required this.textMainTheme,
    required this.textSecTheme,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onTranslatorTapped,
    required this.onProfileTapped,
    required this.onLanguageToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTopBar(context),
          const SizedBox(height: 20),
          _buildModernSearchBar(),
          const SizedBox(height: 24),
          HeroCarousel(brandBrown: brandBrown),
          const SizedBox(height: 32),
          _buildCategoryRibbon(),
          const SizedBox(height: 32),
          _buildHorizontalRecommended(context),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("All Translators",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: textMainTheme)),
                Icon(Icons.sort_rounded, color: textSecTheme, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),
          loading ? _buildShimmerGrid() : _buildModernGrid(context),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: brandBrown, width: 2),
              boxShadow: [
                BoxShadow(
                  color: brandBrown.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/fffinal logo.png',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello,",
                  style: TextStyle(
                      fontSize: 12,
                      color: textSecTheme.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  userName ?? 'Guest',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textMainTheme,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
            color: surfaceTheme,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ]),
        child: TextField(
          controller: searchController,
          onChanged: (v) => onSearchChanged(),
          decoration: InputDecoration(
            hintText: "Search legal or medical experts...",
            hintStyle:
                TextStyle(fontSize: 14, color: textSecTheme.withValues(alpha: 0.5)),
            prefixIcon:
                Icon(Icons.search_rounded, color: brandBrown, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRibbon() {
    final categories = ["All", "Legal", "Medical", "Business", "Books"];
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          bool isSelected = selectedCategory == categories[i];
          return GestureDetector(
            onTap: () => onCategoryChanged(categories[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected ? brandBrown : surfaceTheme,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: isSelected ? brandBrown : Colors.grey.shade200),
              ),
              child: Center(
                child: Text(categories[i],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : textSecTheme)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceTheme,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: const CircleAvatar(radius: 36, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 16),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(width: 80, height: 16, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: double.infinity,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernGrid(BuildContext context) {
    if (filteredTranslators.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: PremiumEmptyState(
          title: "No matching experts found",
          subtitle: "Try adjusting your search or filters to find what you're looking for.",
          icon: Icons.search_off_rounded,
          brandBrown: brandBrown,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredTranslators.length,
      itemBuilder: (context, index) {
        return _buildExpertCard(context, filteredTranslators[index]);
      },
    );
  }

  Widget _buildExpertCard(BuildContext context, Map<String, dynamic> t) {
    final List? categories = t['category'] as List?;
    final String displayCategory = (categories != null && categories.isNotEmpty)
        ? categories.first.toString()
        : "Generalist";

    return Container(
      decoration: BoxDecoration(
          color: surfaceTheme,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 10))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: brandBrown.withValues(alpha: 0.04),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24))),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          const Text("ACTIVE",
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF065F46))),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Hero(
                        tag: 'translator_avatar_${t['id']}',
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white,
                        backgroundImage: (t['avatar_url'] != null)
                            ? NetworkImage(t['avatar_url'])
                            : null,
                        child: (t['avatar_url'] == null)
                            ? Text(
                                (t['full_name'] ?? "?")[0].toUpperCase(),
                                style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: brandBrown),
                              )
                            : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayCategory.toUpperCase(),
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: brandBrown,
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        t['office_name'] ?? t['full_name'] ?? "Unknown",
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textMainTheme),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          "${t['avg_rating'] ?? '5.0'} (${t['review_count'] ?? 0})",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecTheme),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => onTranslatorTapped(t),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("VIEW OFFICE",
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalRecommended(BuildContext context) {
    if (recommendedTranslators.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Top Rated Experts",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: textMainTheme)),
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: recommendedTranslators.length,
            itemBuilder: (context, i) {
              final t = recommendedTranslators[i];
              return GestureDetector(
                onTap: () => onTranslatorTapped(t),
                child: Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [brandBrown, brandBrown.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: brandBrown.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Icon(Icons.verified_user_rounded,
                            size: 100, color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Hero(
                                  tag: 'translator_avatar_${t['id']}_rec',
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: (t['avatar_url'] != null)
                                        ? NetworkImage(t['avatar_url'])
                                        : null,
                                    child: (t['avatar_url'] == null)
                                        ? const Icon(Icons.person, color: Colors.white)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['office_name'] ?? t['full_name'] ?? "Expert",
                                        style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: Color(0xFFFCD34D), size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${t['rating'] ?? '4.9'} • (40+ reviews)",
                                            style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.8),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Text(
                                "BEST FOR LEGAL DOCS",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Click to view office details and availability.",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
