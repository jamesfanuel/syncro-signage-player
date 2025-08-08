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
  bool _isChecking = true;
  final _apiService = ApiService();
  LicenseValidationResponse? _validatedLicense;

  @override
  void initState() {
    super.initState();
    // _checkLicenseCode();
  }

  Future<void> _checkLicenseCode() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseCode = prefs.getString('license_code');

    if (licenseCode == null) {
      Future.delayed(Duration.zero, () => _showLicenseDialog());
    } else {
      // Langsung validasi ulang untuk memastikan lisensi masih aktif
      final result = await _apiService.validateLicenseCode(licenseCode);

      if (result != null && result.status?.toUpperCase() != 'EXPIRED') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('license_code', licenseCode);
        setState(() => _isChecking = false);
      } else if (result?.status?.toUpperCase() == 'EXPIRED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('License sudah EXPIRED')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('License tidak valid')),
        );
      }
    }
  }

  Future<void> _showLicenseDialog() async {
    final controller = TextEditingController();
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
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
                        setState(() {
                          errorMessage = 'License sudah EXPIRED';
                        });
                        return;
                      } else {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('license_code', code);
                        await prefs.setInt('customer_id', result.data.customerId);
                        await prefs.setInt('outlet_id', result.data.outletId);
                        await prefs.setInt('screen_id', result.data.screenId);

                        _validatedLicense = result;

                        if (mounted) {
                          Navigator.pop(context); // Tutup dialog
                          this.setState(() => _isChecking = false); // <-- setState milik class utama
                        }
                      }
                    } else {
                      setState(() {
                        errorMessage = 'License tidak terdaftar';
                      });
                    }
                  } catch (e) {
                    setState(() {
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
        body: Center(child: CircularProgressIndicator()),
      );
    } else {
      return const PlaylistScreen();
    }
  }
}
