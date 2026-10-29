/// Default API address. Override at build/run time:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
/// The address can also be changed in the app under Settings (saved on device).
const String kDefaultApiUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5000');
const String kAppVersion = '1.0.0';
