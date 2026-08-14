import 'package:flutter/material.dart';

/// عنصر القائمة للتنقل بين الشاشات
class NavItem {
  final String title;
  final IconData icon;
  final Widget screen;
  
  NavItem(this.title, this.icon, this.screen);
}
