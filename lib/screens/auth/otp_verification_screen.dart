import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/login_challenge.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/layout_utils.dart';
import '../../widgets/brand_widgets.dart';

class OtpVerificationScreen extends StatefulWidget {
  final LoginChallenge challenge;
  final VoidCallback onCancel;

  const OtpVerificationScreen({
    super.key,
    required this.challenge,
    required this.onCancel,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const _boxCount = 6;

  final List<TextEditingController> _controllers =
      List.generate(_boxCount, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_boxCount, (_) => FocusNode());
  final _hiddenPasteController = TextEditingController();

  Timer? _timer;
  late DateTime _expiresAt;
  late DateTime _resendAvailableAt;
  bool _submitting = false;
  bool _trustDevice = false;
  bool _locked = false;
  int? _attemptsRemaining;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _expiresAt = widget.challenge.expiresAt.toLocal();
    _resendAvailableAt = widget.challenge.resendAvailableAt.toLocal();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    _hiddenPasteController.dispose();
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _canSubmit => _code.length == _boxCount && !_submitting && !_locked;

  bool get _canResend =>
      !_submitting && DateTime.now().isAfter(_resendAvailableAt);

  Duration get _remaining {
    final diff = _expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onDigitChanged(int index, String value) {
    final digit = value.replaceAll(RegExp(r'\D'), '');
    if (digit.length > 1) {
      _applyPastedCode(digit);
      return;
    }

    _controllers[index].text = digit;
    _controllers[index].selection = TextSelection.collapsed(offset: digit.length);

    if (digit.isNotEmpty && index < _boxCount - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {
      _inlineError = null;
    });
  }

  void _applyPastedCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return;
    }
    for (var i = 0; i < _boxCount; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }
    final focusIndex = digits.length >= _boxCount ? _boxCount - 1 : digits.length;
    _focusNodes[focusIndex.clamp(0, _boxCount - 1)].requestFocus();
    setState(() {
      _inlineError = null;
    });
  }

  KeyEventResult _onKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    setState(() => _submitting = true);
    final app = context.read<AppProvider>();
    final success = await app.verifyLoginOtp(
      code: _code,
      trustDevice: _trustDevice,
    );
    if (!mounted) {
      return;
    }

    if (!success) {
      final error = app.authError;
      setState(() {
        _submitting = false;
        _inlineError = error ?? 'Nieprawidłowy kod.';
        _attemptsRemaining = app.otpAttemptsRemaining;
        _locked = app.otpLocked;
        if (_locked) {
          _resendAvailableAt = DateTime.now();
        }
      });
      return;
    }

    setState(() => _submitting = false);
  }

  Future<void> _resend() async {
    if (!_canResend) {
      return;
    }

    setState(() {
      _submitting = true;
      _inlineError = null;
    });
    final app = context.read<AppProvider>();
    final success = await app.resendLoginOtp();
    if (!mounted) {
      return;
    }

    if (success && app.pendingLoginChallenge != null) {
      setState(() {
        _expiresAt = app.pendingLoginChallenge!.expiresAt.toLocal();
        _resendAvailableAt =
            app.pendingLoginChallenge!.resendAvailableAt.toLocal();
        _locked = false;
        _attemptsRemaining = null;
        _submitting = false;
      });
      return;
    }

    setState(() {
      _submitting = false;
      _inlineError = app.authError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: BrandBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: LayoutTokens.authFormMax,
                ),
                child: BrandCard(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandLogo(width: 112, height: 34)),
                      const SizedBox(height: 24),
                      const Text(
                        'Weryfikacja',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Wysłaliśmy 6-cyfrowy kod na adres ${widget.challenge.maskedEmail}. '
                        'Wpisz go poniżej. Kod jest ważny przez 10 minut.',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Offstage(
                        offstage: true,
                        child: TextField(
                          controller: _hiddenPasteController,
                          onChanged: _applyPastedCode,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_boxCount, (index) {
                          final focused = _focusNodes[index].hasFocus;
                          return SizedBox(
                            width: 46,
                            height: 52,
                            child: Focus(
                              onKeyEvent: (node, event) => _onKeyEvent(index, event),
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                enabled: !_locked && !_submitting,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  contentPadding: EdgeInsets.zero,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusMd),
                                    borderSide: BorderSide(
                                      color: focused
                                          ? primary
                                          : AppTheme.dividerColor,
                                      width: focused ? 1.8 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusMd),
                                    borderSide: BorderSide(
                                      color: primary,
                                      width: 1.8,
                                    ),
                                  ),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) => _onDigitChanged(index, value),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _remaining == Duration.zero
                            ? 'Kod wygasł'
                            : 'Kod wygasa za ${_formatDuration(_remaining)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                      ),
                      if (_inlineError != null || _locked) ...[
                        const SizedBox(height: 10),
                        Text(
                          _locked
                              ? 'Zbyt wiele prób. Poproś o nowy kod.'
                              : _attemptsRemaining != null
                                  ? 'Nieprawidłowy kod. Pozostało prób: $_attemptsRemaining'
                                  : (_inlineError ?? 'Nieprawidłowy kod.'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.coralColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      BrandGradientPill(
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _submit : null,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Potwierdź'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _canResend ? _resend : null,
                          child: Text(
                            'Nie otrzymałeś kodu? Wyślij ponownie',
                            style: TextStyle(
                              color: _canResend
                                  ? AppTheme.textSecondary
                                  : AppTheme.textHint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _trustDevice,
                        onChanged: _locked || _submitting
                            ? null
                            : (value) => setState(() => _trustDevice = value ?? false),
                        title: const Text(
                          'Zaufaj temu urządzeniu przez 30 dni',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: _submitting ? null : widget.onCancel,
                        child: const Text('Wróć do logowania'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
