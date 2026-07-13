package com.sekkeul.app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth(S-3 앱 잠금)의 생체 인증(BiometricPrompt)이 AndroidX Fragment API를 사용해
// FlutterActivity가 아닌 FlutterFragmentActivity가 필요하다.
class MainActivity : FlutterFragmentActivity()
