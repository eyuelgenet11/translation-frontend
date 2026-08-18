import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/empty_state.dart';
import '../ds.dart';

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
  final int unreadNotificationCount;
  final VoidCallback onNotificationTapped;

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
    required this.unreadNotificationCount,
    required this.onNotificationTapped,
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
                Expanded(
                  child: Text("All Translators",
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: textMainTheme),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DS.bgSecondary,
                    borderRadius: BorderRadius.circular(DS.radiusTag),
                    border: Border.all(color: DS.border),
                  ),
                  child: Text(
                    "${filteredTranslators.length} Experts",
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: DS.textSecondary,
                    ),
                  ),
                ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DS.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DS.border),
                    boxShadow: DS.shadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icon/TERGUM_padded.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello,",
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: DS.textSecondary,
                      fontWeight: FontWeight.w400),
                ),
                Text(
                  userName ?? 'Guest',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: DS.textPrimary,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Notification Bell
          GestureDetector(
            onTap: onNotificationTapped,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: DS.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DS.border),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: DS.textPrimary,
                    size: 22,
                  ),
                ),
                if (unreadNotificationCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: DS.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: DS.background, width: 2),
                      ),
                      child: Text(
                        unreadNotificationCount > 9 ? '9+' : '$unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
        height: DS.inputHeight,
        decoration: BoxDecoration(
          color: DS.background,
          borderRadius: BorderRadius.circular(DS.radiusInput),
          border: Border.all(color: DS.border),
          boxShadow: DS.shadow,
        ),
        child: TextField(
          controller: searchController,
          onChanged: (v) => onSearchChanged(),
          style: GoogleFonts.inter(color: DS.textPrimary),
          decoration: InputDecoration(
            hintText: "Search legal or medical experts...",
            hintStyle: GoogleFonts.inter(fontSize: 14, color: DS.placeholder),
            prefixIcon: const Icon(Icons.search_rounded, color: DS.primary, size: 20),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRibbon() {
    final categories = [
      {"label": "All", "icon": Icons.auto_awesome},
      {"label": "Legal", "icon": Icons.balance},
      {"label": "Medical", "icon": Icons.local_hospital},
      {"label": "Business", "icon": Icons.business_center},
      {"label": "Books", "icon": Icons.menu_book},
    ];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final cat = categories[i];
          final bool isSelected = selectedCategory == cat['label'];
          return GestureDetector(
            onTap: () => onCategoryChanged(cat['label'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isSelected ? DS.primary : DS.background,
                borderRadius: BorderRadius.circular(DS.radiusTag),
                border: Border.all(
                  color: isSelected ? DS.primary : DS.border,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : DS.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : DS.textSecondary,
                      ),
                    ),
                  ],
                ),
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
        childAspectRatio: 0.88,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceTheme,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: const CircleAvatar(radius: 24, backgroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(width: 70, height: 12, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: double.infinity,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
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
        childAspectRatio: 0.74,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
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
    final double avgRating = (t['avg_rating'] ?? 5.0).toDouble();
    final int reviewCount = (t['review_count'] ?? 0) as int;

    return GestureDetector(
      onTap: () => onTranslatorTapped(t),
      child: Container(
        decoration: DS.cardDecoration(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: 'translator_avatar_${t['id']}',
              child: CircleAvatar(
                radius: 26,
                backgroundColor: DS.bgSecondary,
                backgroundImage: (t['avatar_url'] != null)
                    ? NetworkImage(t['avatar_url'])
                    : null,
                child: (t['avatar_url'] == null)
                    ? Text(
                        (t['full_name'] ?? "?")[0].toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: DS.primary,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t['office_name'] ?? t['full_name'] ?? "Unknown",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: DS.bgSecondary,
                borderRadius: BorderRadius.circular(DS.radiusTag),
                border: Border.all(color: DS.border),
              ),
              child: Text(
                displayCategory.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: DS.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: reviewCount > 0 ? const Color(0xFFF59E0B) : DS.placeholder,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  reviewCount > 0
                      ? "${avgRating.toStringAsFixed(1)} ($reviewCount)"
                      : "New",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: DS.textSecondary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () => onTranslatorTapped(t),
                style: DS.primaryButton(height: 36),
                child: const Text(
                  "Select",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
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
          child: Text(
            "Top Rated Experts",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: DS.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 165,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: recommendedTranslators.length,
            itemBuilder: (context, i) {
              final t = recommendedTranslators[i];
              final double avgRating = (t['avg_rating'] ?? 0.0).toDouble();
              final int reviewCount = (t['review_count'] ?? 0) as int;
              final List? cats = t['category'] as List?;
              final String primaryCategory = (cats != null && cats.isNotEmpty)
                  ? cats.first.toString().toUpperCase()
                  : 'GENERALIST';

              final String ratingDisplay = reviewCount > 0
                  ? avgRating.toStringAsFixed(1)
                  : 'New';

              final String rankLabel = i == 0
                  ? '🥇 #1 TOP RATED'
                  : i == 1
                      ? '🥈 #2 TOP RATED'
                      : i == 2
                          ? '🥉 #3 TOP RATED'
                          : 'TOP $primaryCategory';

              return GestureDetector(
                onTap: () => onTranslatorTapped(t),
                child: Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: DS.cardDecoration(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Hero(
                            tag: 'translator_avatar_${t['id']}_rec',
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: DS.bgSecondary,
                              backgroundImage: (t['avatar_url'] != null)
                                  ? NetworkImage(t['avatar_url'])
                                  : null,
                              child: (t['avatar_url'] == null)
                                  ? Text(
                                      (t['full_name'] ?? "?")[0].toUpperCase(),
                                      style: GoogleFonts.inter(
                                        color: DS.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    )
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
                                      color: DS.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      color: reviewCount > 0
                                          ? const Color(0xFFF59E0B)
                                          : DS.placeholder,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$ratingDisplay • $reviewCount reviews",
                                      style: GoogleFonts.inter(
                                          color: DS.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: DS.bgSecondary,
                              borderRadius: BorderRadius.circular(DS.radiusTag),
                              border: Border.all(color: DS.border),
                            ),
                            child: Text(
                              rankLabel,
                              style: GoogleFonts.inter(
                                  color: DS.textPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
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

