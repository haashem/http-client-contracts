import 'package:flutter/material.dart';

import 'auth_refresh_controller.dart';

class LoginRefreshScreen extends StatelessWidget {
  const LoginRefreshScreen({super.key, required this.controller});

  final AuthRefreshController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Scenario 1: Login + token refresh',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Server returns an expired token on login. The first protected '
                'request gets 401, auth decorator refreshes token, then retries.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: controller.busy ? null : controller.run,
                child: const Text('Run login + refresh flow'),
              ),
              const SizedBox(height: 16),
              SelectableText(controller.status),
            ],
          ),
        );
      },
    );
  }
}
