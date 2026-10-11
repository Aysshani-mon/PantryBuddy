import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/app_state.dart';
import '../../data/repository.dart' show AuthException;
import '../../widgets/validated_text_field.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../onboarding/create_or_join_household_screen.dart';
import 'create_profile_screen.dart';
import 'forgot_password_screen.dart';

/// "Welcome back" sign-in screen from the prototype, plus a Forgot
/// password link (AC: password reset request — see [ForgotPasswordScreen]).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.appState.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final hasHousehold = widget.appState.currentHousehold != null;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => hasHousehold
            ? HomeScreen(appState: widget.appState)
            : CreateOrJoinHouseholdScreen(appState: widget.appState),
      ));
    } on AuthException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (e) {
      // Belt-and-braces: catch anything AuthException didn't anticipate
      // too, so a surprise error type can never leave this screen stuck
      // on its loading spinner forever.
      setState(() {
        _submitting = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Stack(
            children: [
              // Forest header behind the top of the form card.
              Container(
                width: double.infinity,
                height: top + 300,
                decoration: const BoxDecoration(
                  color: AppTheme.forest,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(22, top + 48, 22, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PANTRYSENTRY', style: AppTheme.kicker.copyWith(color: AppTheme.onForestKicker)),
                              const SizedBox(height: 10),
                              const Text(
                                'Welcome back.',
                                style: TextStyle(
                                  fontFamily: AppTheme.displayFont,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 38,
                                  height: 1.08,
                                  letterSpacing: -0.5,
                                  color: AppTheme.onForest,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Sign in to manage your household\'s food.',
                                style: TextStyle(color: AppTheme.onForestMuted, fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          decoration: AppTheme.panel(radius: 22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Image.asset('assets/images/logo_wordmark.png', height: 48),
                                ),
                                const SizedBox(height: 18),
                                ValidatedTextField(
                                  label: 'Email',
                                  controller: _emailController,
                                  autofocus: true,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: ValidatedTextField.email(),
                                ),
                                const SizedBox(height: 16),
                                ValidatedTextField(
                                  label: 'Password',
                                  controller: _passwordController,
                                  obscureText: true,
                                  validator: ValidatedTextField.required('your password'),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => Navigator.of(context).push(MaterialPageRoute(
                                              builder: (_) => ForgotPasswordScreen(appState: widget.appState),
                                            )),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                                if (_error != null) ...[
                                  Text(_error!, style: const TextStyle(color: AppTheme.paprika, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                ],
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _submitting ? null : _submit,
                                  child: _submitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Sign in'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                                      builder: (_) => CreateProfileScreen(appState: widget.appState),
                                    )),
                            child: const Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: 'New here? ', style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600)),
                                  TextSpan(text: 'Create an account'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
