# ML Kit text recognition — suppress missing optional script models
# Only Latin script is used; Chinese/Devanagari/Japanese/Korean models are not included
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
