import 'package:flutter/material.dart';
import '../services/profile_service.dart';

/// Legacy modal wrapper delegates directly to the robust ProfileService
class ProfileImagePickerModal extends StatelessWidget {
  const ProfileImagePickerModal({super.key});

  static Future<void> show(BuildContext context) {
    return ProfileService().showAvatarPickerModal(context);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
