import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class BreakActivitiesScreen extends StatelessWidget {
  const BreakActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Break Activities'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _buildActivityCard(
            context,
            title: 'Guided Breathing 🫁',
            subtitle: 'Inhale for 4s, Hold for 4s, Exhale for 4s',
            icon: Icons.air,
            color: Colors.teal,
            onTap: () => _showBreathingModal(context),
          ),
          const SizedBox(height: 16),

          _buildActivityCard(
            context,
            title: 'Stretching Routine 🧘‍♀️',
            subtitle: 'Neck rolls, shoulder shrugs, and wrist flexes',
            icon: Icons.accessibility_new,
            color: Colors.orange,
            onTap: () => _showStretchingModal(context),
          ),
          const SizedBox(height: 16),

          _buildActivityCard(
            context,
            title: 'Quick Walk 🚶',
            subtitle: 'Walk around your room or stretch your legs for 2 mins',
            icon: Icons.directions_walk,
            color: Colors.blue,
            onTap: () => _showWalkingModal(context),
          ),
          const SizedBox(height: 16),

          _buildActivityCard(
            context,
            title: '20-20-20 Eye Rest 👀',
            subtitle: 'Look at an object 20 feet away for 20 seconds',
            icon: Icons.remove_red_eye_outlined,
            color: Colors.purple,
            onTap: () => _showEyeRestModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          onPressed: onTap,
          child: const Text('Start'),
        ),
      ),
    );
  }

  // Interactive Guided Breathing Dialog
  void _showBreathingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _BreathingWidget(),
    );
  }

  // Interactive Stretching Instructions Dialog
  void _showStretchingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stretching Guide 🧘',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('1. Rotate your neck slowly clockwise 5 times.'),
            const SizedBox(height: 8),
            const Text('2. Roll your shoulders backwards 10 times.'),
            const SizedBox(height: 8),
            const Text('3. Extend your arms overhead and stretch upwards.'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stretching activity completed! Great job!')),
                  );
                },
                child: const Text('Mark Activity Complete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Interactive Walking Timer Modal
  void _showWalkingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ActivityTimerWidget(
        title: 'Walking Activity 🚶',
        seconds: 120,
      ),
    );
  }

  // Interactive Eye Rest Modal
  void _showEyeRestModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ActivityTimerWidget(
        title: '20-20-20 Eye Rest 👀',
        seconds: 20,
      ),
    );
  }
}

class _BreathingWidget extends StatefulWidget {
  const _BreathingWidget();

  @override
  State<_BreathingWidget> createState() => _BreathingWidgetState();
}

class _BreathingWidgetState extends State<_BreathingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _breathStep = 'Inhale...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.forward) {
        setState(() => _breathStep = 'Inhale...');
      } else {
        setState(() => _breathStep = 'Exhale...');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_breathStep, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
          const SizedBox(height: 32),
          ScaleTransition(
            scale: _animation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.teal, width: 4),
              ),
              child: const Center(
                child: Icon(Icons.air, size: 48, color: Colors.teal),
              ),
            ),
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () => Navigator.pop(context),
            child: const Text('Complete Breathing'),
          ),
        ],
      ),
    );
  }
}

class _ActivityTimerWidget extends StatefulWidget {
  final String title;
  final int seconds;

  const _ActivityTimerWidget({required this.title, required this.seconds});

  @override
  State<_ActivityTimerWidget> createState() => _ActivityTimerWidgetState();
}

class _ActivityTimerWidgetState extends State<_ActivityTimerWidget> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(
            '$_remaining sec',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_remaining == 0 ? 'Done' : 'Cancel'),
          ),
        ],
      ),
    );
  }
}
