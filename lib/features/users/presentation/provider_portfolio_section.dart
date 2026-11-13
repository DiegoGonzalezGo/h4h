import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/cached_app_image.dart';
import '../../../core/widgets/loading_skeletons.dart';
import 'full_screen_image_viewer.dart';

class ProviderPortfolioSection extends StatelessWidget {
  final String providerUid;

  const ProviderPortfolioSection({super.key, required this.providerUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(providerUid)
          .collection('portafolio')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PortfolioStripSkeleton();
        }

        if (snapshot.hasError) {
          return const Text('No se pudo cargar el portafolio.');
        }

        final documents = snapshot.data?.docs;
        if (documents == null || documents.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portafolio y Evidencias',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final data = documents[index].data();
                  final imageUrl =
                      data['downloadURL'] as String? ??
                      data['imageUrl'] as String? ??
                      '';
                  final title = _titleFrom(data);

                  return Container(
                    width: 150,
                    margin: const EdgeInsets.only(right: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl.isEmpty)
                            Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 36,
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (context) => FullScreenImageViewer(
                                      imageUrl: imageUrl,
                                      title: title,
                                    ),
                                  ),
                                );
                              },
                              child: CachedAppImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: 150,
                                height: 150,
                                errorIconSize: 36,
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xD9000000),
                                  ],
                                ),
                              ),
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
      },
    );
  }

  String _titleFrom(Map<String, dynamic> data) {
    final title = data['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    final legacyDescription = data['description']?.toString().trim() ?? '';
    return legacyDescription.isNotEmpty
        ? legacyDescription
        : 'Evidencia de trabajo';
  }
}
