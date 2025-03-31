class CommonUtil {
  // 格式化速度显示
  static String formatSpeed(double bytesPerSec) {
    return '${formatSize(bytesPerSec)}/s';
  }

  // 格式化大小显示
  static String formatSize(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(2)} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// 格式化时长显示
  static formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return "$minutes:${secs.toString().padLeft(2, '0')}";
  }

  static getAvailableFileName(String fileName) {
    // 仅移除不合法的文件名字符，保留中文、字母、数字、下划线和点
    String sanitizedFileName = fileName.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    return sanitizedFileName;
  }
}
