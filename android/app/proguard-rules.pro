# ============================================================
# 芥舟 V2.6 混淆保留规则（备用）。
# 当前 android/app/build.gradle 未开启 minify/isMinifyEnabled，本文件未激活；
# 若后续开启混淆，Supabase 及其传递库（gotrue/postgrest/storage/realtime）
# 的网络序列化模型需要以下 keep 规则，避免 JSON 字段被裁剪/改名。
# ============================================================

# Supabase 生态：模型字段名参与 JSON 序列化，禁止改名/裁剪
-keep class io.github.jan.supabase.** { *; }
-keep class io.github.jan.supabase.gotrue.** { *; }
-keep class io.github.jan.supabase.postgrest.** { *; }
-keep class io.github.jan.supabase.storage.** { *; }
-keep class io.github.jan.supabase.realtime.** { *; }
-keep class io.github.jan.supabase.functions.** { *; }

# kotlinx.serialization（gotrue/postgrest 模型序列化依赖）
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.jiezhou.**$$serializer { *; }
-keepclassmembers class com.jiezhou.** { *** Companion; }
-keepclasseswithmembers class com.jiezhou.** { kotlinx.serialization.KSerializer serializer(...); }
