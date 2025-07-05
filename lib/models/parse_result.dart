class ParseResult {
  final String noteId;
  final String desc;
  final String title;
  XhsVideoInfo? video;
  List<XhsImageInfo>? images;

  ParseResult({
    required this.noteId,
    required this.desc,
    required this.title,
    this.video,
    this.images,
  });

  @override
  String toString() {
    return "noteId: $noteId, desc: $desc, title: $title, videoInfo: $video, images: $images";
  }
}

class XhsVideoInfo {
  final String url;
  final int size;
  final int duration;

  XhsVideoInfo({
    required this.url,
    required this.size,
    required this.duration,
  });

  @override
  String toString() {
    return "url: $url, size: $size, duration: $duration";
  }
}

class XhsImageInfo {
  final String url;
  final String highQualityUrl;
  final String rawUrl;
  final int width;
  final int height;
  final bool livePhoto;

  XhsImageInfo({
    required this.url,
    required this.highQualityUrl,
    required this.rawUrl,
    required this.width,
    required this.height,
    required this.livePhoto,
  });

  @override
  String toString() {
    return "url: $url, highQualityUrl: $highQualityUrl, rawUrl: $rawUrl, width: $width, height: $height, livePhoto: $livePhoto";
  }
}