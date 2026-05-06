import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';

void showHowToGuide(BuildContext context, Color textSecTheme) {
  final steps = [
    {
      'icon': Icons.search_rounded,
      'color': const Color(0xFF2563EB),
      'img': 'assets/ss/Screenshot_20260325_010321.jpg',
      'title': '1. Choose a Translator',
      'desc':
          'Browse our verified Ge\'ez experts and select the translator that best fits your project\'s needs.',
    },
    {
      'icon': Icons.upload_file_rounded,
      'color': const Color(0xFF895129),
      'img': 'assets/ss/Screenshot_20260325_004252.jpg',
      'title': '2. Upload Document',
      'desc':
          'Safely upload the document you want translated and send it directly to your chosen expert.',
    },
    {
      'icon': Icons.request_quote_outlined,
      'color': const Color(0xFFEA580C),
      'img': 'assets/ss/Screenshot_20260325_004431.jpg',
      'title': '3. Receive & Review Quote',
      'desc':
          'Your translator will review your file and send a custom price quote for your approval.',
    },
    {
      'icon': Icons.payments_outlined,
      'color': const Color(0xFF16A34A),
      'img': 'assets/ss/Screenshot_20260325_005124.jpg',
      'title': '4. Settle Payment',
      'desc':
          'Pay via Telebirr or CBE. Upload your receipt screenshot OR enter your transaction number to verify.',
    },
    {
      'icon': Icons.edit_note_rounded,
      'color': const Color(0xFF895129),
      'img': 'assets/ss/Screenshot_20260325_005656.jpg',
      'title': '5. Translation in Progress',
      'desc':
          'Sit back while your expert works! You can track the live status from the Tracker tab at any time.',
    },
    {
      'icon': Icons.cloud_download_rounded,
      'color': const Color(0xFFF59E0B),
      'img': 'assets/ss/Screenshot_20260325_010933.jpg',
      'title': '6. Download Completed File',
      'desc':
          'Once the translator is finished, you can instantly download your perfectly translated Ge\'ez document!',
    },
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context)!.translate('how_it_works'),
                style: GoogleFonts.philosopher(
                    fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text("Your step-by-step guide",
                style: TextStyle(fontSize: 13, color: textSecTheme)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: steps.length,
                itemBuilder: (context, i) {
                  final s = steps[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            child: Image.asset(
                              s['img'] as String,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                color: (s['color'] as Color).withOpacity(0.1),
                                child: Icon(s['icon'] as IconData,
                                    size: 60, color: s['color'] as Color),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color:
                                      (s['color'] as Color).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text("${i + 1}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: s['color'] as Color)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(s['title'] as String,
                                        style: GoogleFonts.philosopher(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(s['desc'] as String,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: textSecTheme,
                                            height: 1.5)),
                                  ],
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
            ),
          ],
        ),
      ),
    ),
  );
}
