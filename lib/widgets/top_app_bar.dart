import 'package:flutter/material.dart';
import '../widgets/find_people_popup.dart';
import '../widgets/notification_icon.dart';

class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const TopAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => showFindPeopleDialog(context),
        ),
        const NotificationIcon(),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
