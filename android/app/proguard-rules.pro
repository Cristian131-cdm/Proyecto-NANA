# Vosk («Oye NANA» sin bip) carga su librería nativa con JNA, que busca
# clases por nombre: no se deben recortar ni renombrar.
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**
