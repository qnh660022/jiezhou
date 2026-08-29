/// 原生 / 桌面：通过 dart:io 环境变量识别测试环境。
library;
import 'dart:io';

bool get isTestEnv => Platform.environment.containsKey('FLUTTER_TEST');