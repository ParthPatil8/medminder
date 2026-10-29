import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/common.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: PageBody(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const AppLogo(size: 96),
                const SizedBox(height: 24),
                Text('MedMinder', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 12),
                const Text(
                  'Keep your medicine schedule in one place, get reminders, '
                  'record each dose and review how consistently you take them.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'MedMinder is a reminder and record-keeping tool. It does not give '
                  'medical advice. Enter schedules exactly as your clinician instructs.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.read<AppState>().completeOnboarding(),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Get started'),
                ),
              ]),
            ),
          ),
        ),
      );
}
