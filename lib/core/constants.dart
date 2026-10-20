// CivilHand Core App Constants

class AppConstants {
  static const String appName = 'CivilHand';
  static const String appTagline = 'Verified Home Services on Demand';

  // Config defaults (in paise)
  static const int defaultCashLimitPaise = 500000; // ₹5,000
  static const int cashWarningThresholdPaise = 400000; // ₹4,000 (80%)
  static const int minAdvanceBookingMinutes = 30;

  // Supabase Config
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://behfkfciyftvbzvyxetbi.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlaGtmY2l5ZnR2Ynp2eXhldGJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxNjMwMzEsImV4cCI6MjEwNzczOTAzMX0.YmmTMYmiIZAXkrgKqNCPEJ-kQuk8Aggs9vXq7ZjfZWo',
  );

  // Cloudinary Storage Config (25GB Free Storage for images & docs)
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 't4b7frhl',
  );
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 't4b7frhl',
  );
}
