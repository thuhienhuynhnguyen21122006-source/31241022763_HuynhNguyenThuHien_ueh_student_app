import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../helpers/student_api.dart';
import '../routers/app_router.dart';

const _primary = Color(0xFF005F69);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mssvController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _remember = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _mssvController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await StudentApi.login(
        _mssvController.text,
        _passwordController.text,
        remember: _remember,
      );
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  // API chỉ có đăng nhập bằng MSSV và mật khẩu.
  void _emailLogin() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập bằng email đang được phát triển.'),
        ),
      );
  }

  InputDecoration _decoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: const TextStyle(color: Colors.black38),
    floatingLabelStyle: const TextStyle(color: Colors.black38),
    hintStyle: const TextStyle(color: Colors.black26),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: _primary, width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Tài khoản'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ảnh gốc 1290x685
            AspectRatio(
              aspectRatio: 1290 / 685,
              child: Image.asset(
                'asset/image/ueh-campus.png',
                fit: BoxFit.cover,
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Chào mừng đến với UEH',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nơi đào tạo nhà quản lý và doanh nhân thành đạt',
                          style: TextStyle(fontSize: 17, color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        // Ô nhập thụt vào so với phần chữ phía trên.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _mssvController,
                                enabled: !_loading,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                textInputAction: TextInputAction.next,
                                cursorColor: _primary,
                                decoration: _decoration(
                                  'Tên đăng nhập',
                                  'Nhập tên đăng nhập',
                                ),
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty
                                    ? 'Vui lòng nhập tên đăng nhập'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_loading,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                cursorColor: _primary,
                                decoration:
                                    _decoration(
                                      'Mật khẩu',
                                      'Nhập mật khẩu',
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: _obscure
                                            ? 'Hiện mật khẩu'
                                            : 'Ẩn mật khẩu',
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: Colors.black38,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                      ),
                                    ),
                                validator: (value) => (value ?? '').isEmpty
                                    ? 'Vui lòng nhập mật khẩu'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                value: _remember,
                                onChanged: _loading
                                    ? null
                                    : (value) => setState(
                                        () => _remember = value ?? false,
                                      ),
                                title: const Text('Lưu phiên đăng nhập'),
                                activeColor: _primary,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                  disabledBackgroundColor: _primary.withValues(
                                    alpha: 0.6,
                                  ),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(52),
                                  shape: const StadiumBorder(),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'ĐĂNG NHẬP',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              _OutlinedPillButton(
                                label: 'ĐĂNG NHẬP BẰNG EMAIL UEH',
                                onPressed: _loading ? null : _emailLogin,
                              ),
                              const SizedBox(height: 16),
                              _OutlinedPillButton(
                                label: 'ĐĂNG NHẬP BẰNG EMAIL KHÁCH',
                                onPressed: _loading ? null : _emailLogin,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinedPillButton extends StatelessWidget {
  const _OutlinedPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _primary),
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
