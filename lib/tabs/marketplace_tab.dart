import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/hero_carousel.dart';
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
                    color: brandBrown.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${filteredTranslators.length} Experts",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: brandBrown,
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: brandBrown, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: brandBrown.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icon/TERGUM_padded.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 56,
                  child: Text(
                    "TIRGUMSRA",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: brandBrown,
                      letterSpacing: 0.6,
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
                    color: brandBrown.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: brandBrown.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: brandBrown,
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
                        color: Colors.redAccent.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: surfaceTheme, width: 2),
                      ),
                      child: Text(
                        unreadNotificationCount > 9 ? '9+' : '$unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
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
    final categories = [
      {"label": "All", "emoji": "✨"},
      {"label": "Legal", "emoji": "⚖️"},
      {"label": "Medical", "emoji": "🏥"},
      {"label": "Business", "emoji": "💼"},
      {"label": "Books", "emoji": "📚"},
    ];
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final cat = categories[i];
          final bool isSelected = selectedCategory == cat['label'];
          return GestureDetector(
            onTap: () => onCategoryChanged(cat['label']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [brandBrown, brandBrown.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : surfaceTheme,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.grey.shade200),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: brandBrown.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  "${cat['emoji']} ${cat['label']}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? Colors.white : textSecTheme,
                  ),
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
        childAspectRatio: 0.88,
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
    final Color accentColor = brandBrown;

    return GestureDetector(
      onTap: () => onTranslatorTapped(t),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceTheme,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top accent strip
                Container(
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                const SizedBox(height: 24), // space for overlapping avatar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Category tag
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            displayCategory.toUpperCase(),
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t['office_name'] ?? t['full_name'] ?? "Unknown",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textMainTheme,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: reviewCount > 0 ? Colors.amber : Colors.grey.shade300,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            reviewCount > 0
                                ? "${avgRating.toStringAsFixed(1)} ($reviewCount)"
                                : "New",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: textSecTheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 30,
                        child: ElevatedButton(
                          onPressed: () => onTranslatorTapped(t),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "SELECT",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Avatar centered overlapping strip
            Positioned(
              top: 26, // 48 - 22
              left: 0,
              right: 0,
              child: Center(
                child: Hero(
                  tag: 'translator_avatar_${t['id']}',
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: (t['avatar_url'] != null)
                        ? NetworkImage(t['avatar_url'])
                        : null,
                    child: (t['avatar_url'] == null)
                        ? Text(
                            (t['full_name'] ?? "?")[0].toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          )
                        : null,
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
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: textMainTheme,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: recommendedTranslators.length,
            itemBuilder: (context, i) {
              final t = recommendedTranslators[i];

              // Real data
              final double avgRating = (t['avg_rating'] ?? 0.0).toDouble();
              final int reviewCount = (t['review_count'] ?? 0) as int;
              final List? cats = t['category'] as List?;
              final String primaryCategory = (cats != null && cats.isNotEmpty)
                  ? cats.first.toString().toUpperCase()
                  : 'GENERALIST';

              // Display rating: real value with 1 decimal, or "New" if no reviews
              final String ratingDisplay = reviewCount > 0
                  ? avgRating.toStringAsFixed(1)
                  : 'New';
              final String reviewLabel = reviewCount == 1
                  ? '1 review'
                  : reviewCount > 1
                      ? '$reviewCount reviews'
                      : 'No reviews yet';

              // Rank badge
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
                  width: 260,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [brandBrown, brandBrown.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: brandBrown.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -15,
                        top: -15,
                        child: Icon(Icons.verified_user_rounded,
                            size: 80, color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      Padding(
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
                                    backgroundColor: Colors.white24,
                                    backgroundImage: (t['avatar_url'] != null)
                                        ? NetworkImage(t['avatar_url'])
                                        : null,
                                    child: (t['avatar_url'] == null)
                                        ? Text(
                                            (t['full_name'] ?? "?")[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
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
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
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
                                                ? const Color(0xFFFCD34D)
                                                : Colors.white38,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "$ratingDisplay  •  $reviewLabel",
                                            style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.85),
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
                            // Category badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                rankLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              reviewCount > 0
                                  ? "Rated $ratingDisplay/5 by $reviewCount verified client${reviewCount == 1 ? '' : 's'}."
                                  : "Newly joined expert. Be the first to review!",
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
