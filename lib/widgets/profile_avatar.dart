import 'package:flutter/material.dart';
import 'quest_ui.dart';

class ProfileAvatarOption {
  const ProfileAvatarOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const profileAvatarOptions = <ProfileAvatarOption>[
  ProfileAvatarOption(
    key: 'adventurer',
    label: '冒険者',
    icon: Icons.explore,
  ),
  ProfileAvatarOption(
    key: 'mountain',
    label: '山',
    icon: Icons.landscape,
  ),
  ProfileAvatarOption(
    key: 'shrine',
    label: '聖地',
    icon: Icons.temple_buddhist,
  ),
  ProfileAvatarOption(
    key: 'camera',
    label: '旅カメラ',
    icon: Icons.photo_camera,
  ),
  ProfileAvatarOption(
    key: 'train',
    label: '旅人',
    icon: Icons.train,
  ),
  ProfileAvatarOption(
    key: 'star',
    label: '達人',
    icon: Icons.auto_awesome,
  ),
];

ProfileAvatarOption profileAvatarOptionForKey(
  String? key,
) {
  for (final option in profileAvatarOptions) {
    if (option.key == key) {
      return option;
    }
  }

  return profileAvatarOptions.first;
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarKey,
    this.size = 96,
    this.iconSize,
    this.selected = false,
  });

  final String? avatarKey;
  final double size;
  final double? iconSize;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final option = profileAvatarOptionForKey(avatarKey);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: QuestUiTokens.primaryGradient,
        shape: BoxShape.circle,
        border: selected
            ? Border.all(
                color: Colors.amber,
                width: 4,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: QuestUiTokens.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        option.icon,
        color: Colors.white,
        size: iconSize ?? size * 0.5,
      ),
    );
  }
}
