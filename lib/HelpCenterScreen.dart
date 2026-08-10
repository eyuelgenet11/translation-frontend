import 'package:flutter/material.dart';

// Using the same brand colors from your HomeScreen
const Color brandColor = Color(0xFF8D5C3C);
const Color accentColor = Color(0xFFD8B88A);

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    final Color cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: textColor,
          ), // Airbnb uses 'X' to close help
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help Center',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Section ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Text(
                'How can we help\nyou today?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  height: 1.2,
                ),
              ),
            ),

            // --- Airbnb-style Search Bar ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for articles, help and more...',
                    prefixIcon: const Icon(Icons.search, color: brandColor),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- Recommended Quick Links (Grid) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Recommended for you',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 24, right: 10),
                children: [
                  _buildQuickCard(
                    context,
                    "Getting\nStarted",
                    Icons.rocket_launch,
                    cardColor,
                    textColor,
                  ),
                  _buildQuickCard(
                    context,
                    "Payment\nIssues",
                    Icons.payment,
                    cardColor,
                    textColor,
                  ),
                  _buildQuickCard(
                    context,
                    "Translation\nQuality",
                    Icons.g_translate,
                    cardColor,
                    textColor,
                  ),
                  _buildQuickCard(
                    context,
                    "Safety &\nPrivacy",
                    Icons.verified_user,
                    cardColor,
                    textColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- Category List ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse all topics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTopicTile(context, "Your Guide to Geez Translation", textColor),
                  _buildTopicTile(context, "Pricing and Fees", textColor),
                  _buildTopicTile(context, "Cancellation Policy", textColor),
                  _buildTopicTile(context, "Communicating with Translators", textColor),
                  _buildTopicTile(context, "Support Channel", textColor),
                  _buildTopicTile(context, "Account Types", textColor),
                  _buildTopicTile(context, "Business Accounts", textColor),
                ],
              ),
            ),

            // --- Footer Contact Section ---
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: brandColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.headset_mic, color: brandColor, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Need more support?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our support team is online and ready to help you with anything you need.',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => _openArticle(context, "Support Channel"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: brandColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Contact Us',
                      style: TextStyle(
                        color: brandColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helper to build the horizontal grid cards
  Widget _buildQuickCard(
    BuildContext context,
    String title,
    IconData icon,
    Color cardColor,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: () => _openArticle(context, title.replaceAll('\n', ' ')),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: brandColor, size: 28),
            Expanded(
              child: Container(
                alignment: Alignment.bottomLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build the list of topics
  Widget _buildTopicTile(BuildContext context, String title, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: TextStyle(color: textColor, fontSize: 15)),
        trailing: Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.5)),
        onTap: () => _openArticle(context, title),
      ),
    );
  }

  void _openArticle(BuildContext context, String title) {
    final String content = _helpContent[title] ??
        "Detailed information about $title will be available soon. Please contact support if you have urgent questions.";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HelpArticleDetailScreen(
          title: title,
          content: content,
        ),
      ),
    );
  }

  static const Map<String, String> _helpContent = {
    "Getting Started":
        "Welcome to the Geez Translation Marketplace! To begin your journey, simply browse our curated list of expert translators on the home screen. You can view their profiles, ratings, and specialties. Once you find a match, upload your document and specify the source and target languages. The translator will review your request and provide a price quote. Accept the quote to start the translation process!",
    "Payment Issues":
        "We currently support payments via Telebirr and CBE (Commercial Bank of Ethiopia). After accepting a quote, you will be prompted to provide a Transaction ID or upload a screenshot of your payment receipt. If your payment is rejected, please ensure the Transaction ID is correct and the screenshot is clear. For any persistent issues, our finance support team is available 24/7.",
    "Translation Quality":
        "Quality is our top priority. Every translator on our platform is a verified expert with deep knowledge of Geez and modern languages. All translations undergo a self-review process by the expert before delivery. If you are not completely satisfied with the result, you can use the feedback system to request refinements or contact our quality assurance team.",
    "Safety & Privacy":
        "Your documents and personal information are handled with the highest level of security. All uploads are stored in encrypted buckets, and access is strictly limited to you and your assigned translator. We never share your data with third parties. Once a job is completed and confirmed, you have full control over your document's visibility.",
    "Your Guide to Geez Translation":
        "Geez is an ancient South Semitic language that originated in the Horn of Africa. While it is no longer a primary spoken language, it remains the liturgical language of the Ethiopian Orthodox Tewahedo Church and is vital for historical research. Our specialists are trained to handle everything from religious texts to historical legal documents encoded in this beautiful script.",
    "Pricing and Fees":
        "Transaltion prices are determined by the complexity of the script, the length of the document, and the required turnaround time. Translators set their own rates, which you can see in the 'Quoted' stage of your order. A small platform service fee is included in the final price to help us maintain the marketplace and verify the experts.",
    "Cancellation Policy":
        "You can cancel a translation request at any time before you accept the quote and make a payment. Once the final payment is verified and processed, no partial refunds are available. However, in the rare event that a translator fails to deliver the final translation as promised, you will be eligible for a full refund of your payment.",
    "Communicating with Translators":
        "Effective communication ensures the best results. You can provide specific instructions during the upload process. Once a job is active, if you have additional requirements, you can reach out through our support channel to pass messages to your translator.",
    "Support Channel":
        "The Support Channel is your dedicated hub for any assistance you need during the translation process. If you have additional instructions for your expert, want to provide more context for a document, or have questions about your order status, our support team will relay your messages directly to the translator. This ensures all communication is documented and handled professionally to guarantee the highest quality result.",
    "Account Types":
        "We offer two distinct account types to suit your needs: Personal and Business. Personal Accounts are designed for individuals requiring occasional translations for legal, medical, or personal documents. Business Accounts are built for organizations that need professional translation at scale with professional auditing features.",
    "Business Accounts":
        "Our Business Account is tailored for organizations, NGOs, and academic institutions. It provides professional features including Official VAT Invoices for all transactions, Priority Support, Bulk Order Management, and direct access to our most senior translators. If your organization requires documented billing and dedicated account management, please contact us to upgrade your status.",
  };
}

class HelpArticleDetailScreen extends StatelessWidget {
  final String title;
  final String content;

  const HelpArticleDetailScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color bgColor = isDark ? const Color(0xFF1C1C1C) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Article',
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                color: textColor.withValues(alpha: 0.8),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              "Was this article helpful?",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _feedbackButton(Icons.thumb_up_alt_outlined, "Yes"),
                const SizedBox(width: 12),
                _feedbackButton(Icons.thumb_down_alt_outlined, "No"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}


