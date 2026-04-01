import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'api/client.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'theme/ma3ak_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env optionnel : on garde l'URL par défaut
  }
  final auth = AuthProvider();
  final themeProvider = ThemeProvider();
  await Future.wait([auth.loadFromStorage(), themeProvider.loadFromStorage()]);
  initApiClient(
    getToken: () => auth.token,
    on401: () => auth.logout(),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: const Ma3akBackofficeApp(),
    ),
  );
}

class Ma3akBackofficeApp extends StatelessWidget {
  const Ma3akBackofficeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoaded) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Chargement…',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final theme = context.watch<ThemeProvider>();
    final router = createAppRouter(context, auth);
    return MaterialApp.router(
      title: 'Ma3ak – Administration',
      theme: ma3akLightThemeData,
      darkTheme: ma3akDarkThemeData,
      themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
