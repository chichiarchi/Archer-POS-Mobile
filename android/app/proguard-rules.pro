# Proguard/R8 rules to keep mobile_scanner and Google ML Kit classes intact in release builds

# Keep ML Kit classes if they are being stripped/obfuscated
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep mobile_scanner specific classes
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**
