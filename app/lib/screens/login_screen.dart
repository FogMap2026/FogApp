import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_error_messages.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

enum _AuthMode { login, signUp }

/// 온보딩 겸 로그인 화면. 로그인 성공 시 [AuthGate]가 자동으로 지도 화면으로 전환한다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_mode == _AuthMode.login) {
        await authService.signIn(email: email, password: password);
      } else {
        await authService.signUp(email: email, password: password);
      }
      // 로그인 상태 변화는 authStateChangesProvider가 감지해 AuthGate가 화면을 전환한다.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = authErrorMessage(e));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '알 수 없는 오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogin = _mode == _AuthMode.login;

    // 히어로가 상태 표시줄 뒤까지 남색이라 아이콘을 밝게 둔다.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _LoginHero(),
              // 카드를 히어로 아래로 살짝 겹쳐 올린다 — 밤에서 종이로 넘어가는 경계를 부드럽게.
              Transform.translate(
                offset: const Offset(0, -AppSpacing.lg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: AppColors.hairline),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(isLogin ? '로그인' : '회원가입', style: theme.textTheme.headlineSmall),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              isLogin ? '다시 오셨네요. 걷던 자리부터 이어갑니다.' : '안개 지도를 처음 펼칩니다.',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: '이메일'),
                              validator: (value) {
                                if (value == null || !value.contains('@')) {
                                  return '올바른 이메일을 입력해주세요.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: '비밀번호'),
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return '비밀번호는 6자 이상이어야 합니다.';
                                }
                                return null;
                              },
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(isLogin ? '로그인' : '회원가입'),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => setState(() {
                                        _mode = isLogin ? _AuthMode.signUp : _AuthMode.login;
                                        _errorMessage = null;
                                      }),
                              child: Text(
                                isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// 로그인 히어로 — 앱에서 유일한 남색 「밤」 띠(Notion `hero-band`).
///
/// 이 앱에서 밤은 **안개**다. 짙은 남색 위에 한 곳만 걷혀 밝아진 원과 핀을 그려,
/// 스토어 그래픽·런처 아이콘과 같은 그림으로 앱을 연다.
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.secondary,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _FogNightPainter())),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              topInset + AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl + AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeroBadge(label: '안개 지도 탐험'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'FogApp',
                  style: theme.textTheme.displayMedium?.copyWith(color: AppColors.surface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '안개 너머의 대한민국을\n발로 걸어 밝혀 나가는 여정',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xCCFFFFFF),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 흰 알약 배지 — 파란 글자(Notion `badge-pill`).
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(color: AppColors.surface, shape: StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}

/// 밤의 안개 — 걷힌 원 하나, 핀 하나, 스티커 색 점 몇 개.
///
/// 스티커 색은 **장식으로만** 쓴다(Notion 규칙). 점들은 아주 작게 둬서 제목을 방해하지 않는다.
class _FogNightPainter extends CustomPainter {
  const _FogNightPainter();

  /// 런처 아이콘·발자취 도형과 같은 앰버 — 스토어에서 본 핀이 앱에서도 그대로 보이게.
  static const _pinColor = Color(0xFFF2B84B);

  static const _dots = <(double, double, double, Color)>[
    (0.12, 0.18, 2.5, AppColors.accentSky),
    (0.86, 0.16, 2.0, AppColors.accentPurple),
    (0.62, 0.30, 1.6, AppColors.accentPink),
    (0.30, 0.78, 2.2, AppColors.accentTeal),
    (0.93, 0.44, 1.4, AppColors.accentSky),
    (0.48, 0.12, 1.2, Color(0xFFFFFFFF)),
    (0.20, 0.52, 1.2, Color(0xFFFFFFFF)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 걷힌 원 — 오른쪽 아래. 가장자리를 흐리게 해 「안개가 걷힌」 느낌을 낸다.
    final center = Offset(size.width * 0.74, size.height * 0.68);
    final radius = size.width * 0.28;
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x66FFFFFF), Color(0x1FFFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);

    // 핀 — 원 한가운데.
    final head = center.translate(0, -16);
    final pin = Path()
      ..moveTo(center.dx, center.dy + 12)
      ..quadraticBezierTo(center.dx - 12, head.dy + 8, center.dx - 11, head.dy)
      ..arcToPoint(Offset(center.dx + 11, head.dy), radius: const Radius.circular(11))
      ..quadraticBezierTo(center.dx + 12, head.dy + 8, center.dx, center.dy + 12)
      ..close();
    canvas.drawPath(pin, Paint()..color = _pinColor);
    canvas.drawCircle(head, 4, Paint()..color = AppColors.secondary);

    // 스티커 점 — 별자리처럼 흩어 둔다.
    for (final (x, y, r, color) in _dots) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
