import 'package:flutter/material.dart';
import 'package:xhs_app/models/parse_result.dart';
import 'package:photo_view/photo_view.dart';
import 'package:xhs_app/utils/common_util.dart';

class ParseResultWidget extends StatelessWidget {
  final ParseResult result;
  final VoidCallback onCopy;
  final Function({String? singleImageUrl}) onDownload;

  const ParseResultWidget({
    Key? key,
    required this.result,
    required this.onCopy,
    required this.onDownload,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部固定区域
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SelectableText(
            result.title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: SizedBox(
            height: 60, // 描述 3 行高度
            child: SingleChildScrollView(
              child: SelectableText(result.desc, style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
        SizedBox(height: 10),

        // 中间自适应区域
        Expanded(
          child:
              result.video != null
                  ? _buildVideoSection()
                  : (result.images != null && result.images!.isNotEmpty)
                  ? _buildImageSection(context)
                  : SizedBox(),
        ),

        // 底部固定按钮区域
        SizedBox(height: 5),
        _buildActionButtons(),
        SizedBox(height: 5),
      ],
    );
  }

  Widget _buildVideoSection() {
    final cover =
        result.images?.isNotEmpty == true ? result.images!.first.url : null;
    final video = result.video!;
    return Column(
      children: [
        if (cover != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: Image.network(cover, fit: BoxFit.contain),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            "时长: ${CommonUtil.formatDuration(video.duration)}，大小: ${CommonUtil.formatSize(video.size.toDouble())}",
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: result.images!.length,
      itemBuilder: (context, index) {
        final img = result.images![index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context, img.url, img.highQualityUrl),
            onLongPress: () => _showImageMenu(context, img.highQualityUrl),
            child: Column(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: img.width / img.height,
                    child: Image.network(img.url, fit: BoxFit.contain),
                  ),
                ),
                SizedBox(height: 5),
                Text("${img.width} x ${img.height}"),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, String url, String hdUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Center(
                  child: PhotoView(
                    imageProvider: NetworkImage(url),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2.5,
                    backgroundDecoration: BoxDecoration(color: Colors.black),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  void _showImageMenu(BuildContext context, String hdUrl) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.hd),
                    title: Text("查看高清图片"),
                    onTap: () {
                      Navigator.pop(context);
                      _showFullScreenImage(context, hdUrl, hdUrl);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.download),
                    title: Text("保存高清图片"),
                    onTap: () {
                      Navigator.pop(context);
                      onDownload(singleImageUrl: hdUrl); // 下载单张图片
                    },
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildActionButtons() {
    String downloadText = "保存到相册";
    if (result.video != null) {
      downloadText = "下载视频";
    } else if (result.images != null && result.images!.isNotEmpty) {
      downloadText = "下载${result.images!.length}张图片";
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: onCopy,
            icon: Icon(Icons.copy),
            label: Text("复制链接"),
          ),
          ElevatedButton.icon(
            onPressed: () => onDownload(), // 下载全部内容
            icon: Icon(Icons.download),
            label: Text(downloadText),
          ),
        ],
      ),
    );
  }
}
