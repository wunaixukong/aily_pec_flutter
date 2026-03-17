import 'package:flutter/material.dart';
import 'pages/today_workout_page.dart';
import 'pages/plan_management_page.dart';
import 'pages/profile_page.dart';
import 'widgets/toast_overlay.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '胸大鸡1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ToastOverlay(
        child: MainNavigationPage(),
      ),
    );
  }
}

/// 主导航页面
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  
  // 测试用户ID，实际应该从登录状态获取
  final int _userId = 1;

  void _switchToPlanPage() {
    setState(() {
      _currentIndex = 1; // 切换到计划管理页面
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayWorkoutPage(
        userId: _userId,
        onGoToPlan: _switchToPlanPage,
      ),
      PlanManagementPage(userId: _userId),
      ProfilePage(userId: _userId),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: '今日训练',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: '训练计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
