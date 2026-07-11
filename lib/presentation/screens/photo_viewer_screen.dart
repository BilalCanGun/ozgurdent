import 'dart:io';

import 'package:flutter/material.dart';

/// Tam ekran fotoğraf görüntüleyici. Önceki / sonraki geçiş, yakınlaştırma,
/// ve isteğe bağlı silme.
class PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final void Function(int index)? onDelete;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.onDelete,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late PageController _controller;
  late int _index;
  late List<String> _photos;

  @override
  void initState() {
    super.initState();
    _photos = [...widget.photos];
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int dir) {
    final next = _index + dir;
    if (next < 0 || next >= _photos.length) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fotoğrafı sil'),
        content: const Text('Bu fotoğraf silinecek. Emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final removed = _index;
    widget.onDelete?.call(removed);
    setState(() {
      _photos.removeAt(removed);
      if (_photos.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      if (_index >= _photos.length) _index = _photos.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = _photos.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          hasPhotos ? '${_index + 1} / ${_photos.length}' : '',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (widget.onDelete != null && hasPhotos)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.file(File(_photos[i]), fit: BoxFit.contain),
              ),
            ),
          ),
          if (_photos.length > 1) ...[
            _navButton(Alignment.centerLeft, Icons.chevron_left, () => _go(-1),
                _index > 0),
            _navButton(Alignment.centerRight, Icons.chevron_right,
                () => _go(1), _index < _photos.length - 1),
          ],
        ],
      ),
      ),
    );
  }

  Widget _navButton(
      Alignment align, IconData icon, VoidCallback onTap, bool enabled) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Opacity(
          opacity: enabled ? 1 : 0.25,
          child: Material(
            color: Colors.white24,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
