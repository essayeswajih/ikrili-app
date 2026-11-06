import 'package:flutter/material.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/data/services/local_auth_service.dart';
import 'package:ikrili/presentation/pages/login.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = UserRoles.carRenter;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await LocalAuthService.instance.register(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
        role: _selectedRole,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AuthScaffold(
      title: strings.t('create_workspace'),
      subtitle: strings.t('register_subtitle'),
      footerText: strings.t('already_have_access'),
      footerActionText: strings.t('sign_in'),
      onFooterPressed: () => Navigator.pushReplacementNamed(context, 'login'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.t('full_name'),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 2) {
                  return strings.t('enter_name');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.t('work_email'),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
              validator: (value) => validateEmail(value, strings),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.t('phone_number'),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 8) {
                  return strings.t('enter_phone');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: strings.t('password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? strings.t('show_password')
                      : strings.t('hide_password'),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => validatePassword(value, strings),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: InputDecoration(
                labelText: strings.t('account_type'),
                prefixIcon: const Icon(Icons.manage_accounts_outlined),
              ),
              items: [
                DropdownMenuItem(
                  value: UserRoles.carRenter,
                  child: Text(strings.t('car_renter')),
                ),
                DropdownMenuItem(
                  value: UserRoles.carOwner,
                  child: Text(strings.t('car_owner')),
                ),
                DropdownMenuItem(
                  value: UserRoles.admin,
                  child: Text(strings.t('admin')),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedRole = value);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.t('create_account')),
            ),
          ],
        ),
      ),
    );
  }
}
