# LiteRT-LM (com.google.ai.edge.litertlm) JNI 표면 보존.
#
# 네이티브 .so가 SamplerConfig.getTopK() 등 Kotlin/Java 메서드를 JNI로
# 역호출한다. R8은 이 호출을 보지 못해 "직접 안 쓰이는" 접근자/생성자를
# 제거하고, 그러면 nativeCreateConversation 단계에서
# NoSuchMethodError: SamplerConfig.getTopK()I 로 release 빌드가 크래시한다.
# 패키지 전체와 그 멤버를 보존해 JNI 시그니처를 유지한다.
-keep class com.google.ai.edge.litertlm.** { *; }
-keepclassmembers class com.google.ai.edge.litertlm.** { *; }

# 네이티브에서 이름으로 찾는 JNI 메서드/필드는 항상 보존.
-keepclasseswithmembernames class com.google.ai.edge.litertlm.** {
    native <methods>;
}
