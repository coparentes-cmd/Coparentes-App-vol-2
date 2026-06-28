import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/local/pin_lock_store.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class PinLockGate extends StatelessWidget {
  final Widget child;

  const PinLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();

    return Stack(
      children: [
        child,
        if (ap.isPinLocked) const PinLockOverlay(),
      ],
    );
  }
}

class PinLockOverlay extends StatefulWidget {
  const PinLockOverlay({super.key});

  @override
  State<PinLockOverlay> createState() => _PinLockOverlayState();
}

class _PinLockOverlayState extends State<PinLockOverlay> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (!PinLockStore.isValidPin(pin)) {
      setState(() => _error = 'Wpisz 4-cyfrowy PIN');
      return;
    }

    final ok = await context.read<AppProvider>().verifyPinAndUnlock(pin);
    if (!mounted) {
      return;
    }

    if (ok) {
      setState(() {
        _error = null;
        _controller.clear();
      });
      return;
    }

    setState(() {
      _error = 'Nieprawidłowy PIN';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();
    final color = ap.primaryColor;

    return Material(
      color: ap.isDark ? const Color(0xFF121212) : Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 56, color: color),
              const SizedBox(height: 20),
              const Text(
                'Wprowadź PIN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aplikacja była w tle — potwierdź tożsamość',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w600,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Odblokuj',
                    style: TextStyle(color: Colors.white, fontSize: 16),
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
