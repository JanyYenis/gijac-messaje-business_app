# --- Escáner QR (mobile_scanner = CameraX + ML Kit) ---
# En release, R8 renombra/quita clases que ML Kit carga por reflexión -> "null object reference" al abrir la cámara.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode_bundled.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class androidx.camera.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn androidx.camera.**

# --- Otros plugins que usan reflexión / servicios ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class io.flutter.plugins.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod