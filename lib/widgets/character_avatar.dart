import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CharacterAvatar extends StatelessWidget {
  final String? avatarPath;
  final String name;
  final double radius;
  final VoidCallback? onTap;

  const CharacterAvatar({
    super.key,
    this.avatarPath,
    required this.name,
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValidImage = !kIsWeb &&
        avatarPath != null &&
        avatarPath!.isNotEmpty &&
        File(avatarPath!).existsSync();

    Widget avatarContent;
    if (hasValidImage) {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: FileImage(File(avatarPath!)),
      );
    } else if (kIsWeb && avatarPath != null && avatarPath!.isNotEmpty) {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(avatarPath!),
      );
    } else {
      final initial = name.isNotEmpty ? name.characters.first : '?';
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.9,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }
    return avatarContent;
  }
}
