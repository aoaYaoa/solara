import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      _shakeController.forward(from: 0);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await ref.read(authStateProvider.notifier).login('', password);
    if (mounted) {
      setState(() {
        _loading = false;
        if (!ok) {
          _error = '密码错误';
          _shakeController.forward(from: 0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                      const Color(0xFF0F3460),
                    ]
                  : [
                      const Color(0xFFF8F0FF),
                      Colors.white,
                      const Color(0xFFF0E6FF),
                    ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: size.height * 0.08),
                    // App Icon
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFBB6BD9).withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF50AA), Color(0xFF7B50FF)],
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'S',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF50AA), Color(0xFF7B50FF)],
                      ).createShader(bounds),
                      child: const Text(
                        'Solara',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '音乐，无处不在',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Password field
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final dx = _shakeController.value < 1.0
                            ? ((_shakeController.value * 4 * 3.14159).clamp(0.0, 12.56) != 0
                                ? 8.0 *
                                    (1 - _shakeController.value) *
                                    _shakeOffset(_shakeController.value)
                                : 0.0)
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: TextField(
                        controller: _passwordController,
                        focusNode: _focusNode,
                        obscureText: _obscure,
                        onSubmitted: (_) => _login(),
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: '输入密码',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.grey.shade400,
                          ),
                          errorText: _error,
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.error.withValues(alpha: 0.6),
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.error.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: _loading
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFFFF50AA), Color(0xFF7B50FF)],
                                ),
                          color: _loading ? Colors.grey.shade400 : null,
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '登录',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _shakeOffset(double t) {
    // Damped sine wave for shake
    return (t * 12.56).clamp(0, 12.56) != 0
        ? ((t * 4 * 3.14159) % (2 * 3.14159) < 3.14159 ? 1.0 : -1.0)
        : 0.0;
  }
}
