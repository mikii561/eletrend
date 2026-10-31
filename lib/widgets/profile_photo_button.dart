import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../square_image.dart';
import '../theme.dart';
import 'common.dart';

/// Profilkép választása: kamera vagy galéria (törlés is). Az új kép base64 JPEG;
/// üres szöveg = a kép törlése; null = mégsem.
Future<String?> chooseProfilePhoto(BuildContext context, {required bool hasPhoto}) async {
  final source = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Fotó készítése'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Kép a galériából'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (hasPhoto)
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Kép törlése', style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  if (source == 'delete') return '';
  try {
    final file = await ImagePicker().pickImage(
      source: source as ImageSource,
      maxWidth: 1000,
      maxHeight: 1000,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return null;
    return prepareProfilePhoto(await file.readAsBytes());
  } on FormatException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nem sikerült a képet megnyitni. Nézd meg, hogy az app használhatja-e a kamerát vagy a képeket.',
          ),
        ),
      );
    }
  }
  return null;
}

/// Nagy kerek profilkép kis kamera-jellel: koppintásra kamera vagy galéria.
class ProfilePhotoButton extends StatelessWidget {
  const ProfilePhotoButton({
    super.key,
    required this.name,
    required this.photo,
    required this.onChanged,
    this.radius = 48,
  });

  final String name;
  final String photo;
  final double radius;

  /// Az új kép (üres = törölve).
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profilkép módosítása',
      child: GestureDetector(
        onTap: () async {
          final picked = await chooseProfilePhoto(context, hasPhoto: photo.isNotEmpty);
          if (picked != null) onChanged(picked);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            photo.isEmpty && name.trim().isEmpty
                ? CircleAvatar(
                    radius: radius,
                    backgroundColor: AppColors.divider,
                    child: Icon(Icons.person_outline, size: radius, color: AppColors.textMuted),
                  )
                : NameAvatar(name.trim().isEmpty ? '?' : name.trim(), radius: radius, photo: photo),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: EdgeInsets.all(radius * 0.17),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Icon(Icons.photo_camera, size: radius * 0.38, color: AppColors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
