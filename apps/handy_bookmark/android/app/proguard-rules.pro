# ML Kit text recognition: the plugin can ask for the Chinese, Devanagari,
# Japanese and Korean recognizers, which this app does not bundle (it reads
# Latin script only, which covers Vietnamese and English). Nothing calls them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
