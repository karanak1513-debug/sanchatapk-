import 'package:flutter/material.dart';
import '../models/sanchay_target.dart';
import 'configure_target_modal.dart';

/// Backward-compatible wrapper delegating to ConfigureTargetModal
class TargetOperationsModal extends StatelessWidget {
  final SanchayTarget? target;

  const TargetOperationsModal({super.key, this.target});

  static Future<void> show(BuildContext context, {SanchayTarget? target}) {
    return ConfigureTargetModal.show(context, target: target);
  }

  @override
  Widget build(BuildContext context) {
    return ConfigureTargetModal(target: target);
  }
}
