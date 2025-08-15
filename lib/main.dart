import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/playlist_screen.dart';
import 'services/api_service.dart';
import 'models/license_validate_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syncro Signage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  bool _isChecking = true; // tetap true sampai user submit license
  LicenseValidationResponse? _validatedLicense;

  @override
  void initState() {
    super.initState();
    // Panggil dialog langsung setelah build
    Future.delayed(Duration.zero, () => _showLicenseDialog());
  }

  Future<void> _showLicenseDialog() async {
    final controller = TextEditingController();
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false, // user wajib input
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Masukkan License Code'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Contoh: XXXX-XXXX-XXXX',
                errorText: errorMessage,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final code = controller.text.trim();

                  try {
                    final result = await _apiService.validateLicenseCode(code);

                    if (result != null) {
                      if (result.status?.toUpperCase() == 'EXPIRED') {
                        setStateDialog(() {
                          errorMessage = 'License sudah EXPIRED';
                        });
                        return;
                      } else {
                        // Simpan license & info ke SharedPreferences
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('license_code', code);
                        await prefs.setInt('customer_id', result.data.customerId);
                        await prefs.setInt('outlet_id', result.data.outletId);
                        await prefs.setInt('screen_id', result.data.screenId);

                        _validatedLicense = result;

                        if (mounted) {
                          Navigator.pop(context); // Tutup dialog
                          setState(() {
                            _isChecking = false; // masuk ke PlaylistScreen
                          });
                        }
                      }
                    } else {
                      setStateDialog(() {
                        errorMessage = 'License tidak terdaftar';
                      });
                    }
                  } catch (e) {
                    setStateDialog(() {
                      errorMessage = 'Terjadi kesalahan saat validasi';
                    });
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Setelah license valid → masuk ke PlaylistScreen
    return const PlaylistScreen();
  }
}
