import 'package:flutter/material.dart';

class AccountSignedOutView extends StatelessWidget {
  const AccountSignedOutView({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(onPressed: onSignIn, child: const Text('Sign in')),
    );
  }
}
