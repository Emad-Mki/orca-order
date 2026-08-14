import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'screens.dart';
import 'nav_item.dart';

/// الشاشة الرئيسية للتطبيق
class HomePage extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onLogout;
  
  const HomePage({
    super.key, 
    required this.session, 
    required this.onLogout
  });

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  
  late final List<NavItem> navItems;
  
  @override
  void initState() {
    super.initState();
    navItems = [
      NavItem('الرئيسية', Icons.dashboard, DashboardScreen(session: widget.session)),
      NavItem('الطلبات', Icons.shopping_cart, OrdersScreen(session: widget.session)),
      NavItem('المخزون', Icons.inventory, InventoryScreen(session: widget.session)),
      NavItem('العملاء', Icons.people, CustomersScreen(session: widget.session)),
      NavItem('الإعدادات', Icons.settings, const SettingsScreen()),
    ];
  }
  
  void onItemTapped(int index) {
    setState(() => selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orca Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onLogout();
                      },
                      child: const Text('خروج'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: navItems[selectedIndex].screen,
      bottomNavigationBar: BottomNavigationBar(
        items: navItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.title,
        )).toList(),
        currentIndex: selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: onItemTapped,
      ),
    );
  }
}
