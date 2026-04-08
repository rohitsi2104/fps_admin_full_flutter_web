/// Base URL of your Django backend (must end with /api/)
///
/// Override at build time via:
///   flutter run  --dart-define=BASE_URL=http://192.168.1.x:8000/api/
///   flutter build apk --dart-define=BASE_URL=https://staging.example.com/api/
///
/// Production default: https://fps-dayalbagh-backend.vercel.app/api/
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://fps-dayalbagh-backend.vercel.app/api/',
);

const Duration kPollInterval = Duration(minutes: 2);
