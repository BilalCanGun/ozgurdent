import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

import '../../core/theme/app_colors.dart';

/// Markalı, animasyonlu pull-to-refresh göstergesi.
///
/// Aşağı çekildikçe gösterge alanı açılır; bırakılınca (loading) gif bir kez
/// oynatılır ve [minVisible] süresi dolana kadar açık kalır. Mantık iku_puma
/// projesindeki [CustomRefreshIndicator] akışının sadeleştirilmiş halidir.
class GifRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Göstergenin en az açık kalacağı süre (gif'in oynaması için).
  final Duration minVisible;

  const GifRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.minVisible = const Duration(milliseconds: 1600),
  });

  @override
  State<GifRefreshIndicator> createState() => _GifRefreshIndicatorState();
}

class _GifRefreshIndicatorState extends State<GifRefreshIndicator> {
  static const _asset = AssetImage('assets/gif/w.gif');

  /// Gif katmanının görünürlüğü (yalnızca loading/finalizing anında 1).
  double _gifOpacity = 0.0;

  /// Yenileme her koşulda [minVisible] kadar açık kalsın ve hata fırlatmasın.
  Future<void> _runRefresh() async {
    try {
      await Future.wait([
        widget.onRefresh(),
        Future.delayed(widget.minVisible),
      ]);
    } catch (_) {
      // Yenileme başarısız olsa da gösterge düzgün kapansın.
      await Future.delayed(widget.minVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: _runRefresh,
      onStateChanged: (change) {
        if (change.didChange(to: IndicatorState.loading)) {
          setState(() => _gifOpacity = 1.0);
        } else if (change.didChange(to: IndicatorState.idle)) {
          setState(() => _gifOpacity = 0.0);
        }
      },
      builder: (context, child, controller) => AnimatedBuilder(
        animation: controller,
        child: child,
        builder: (context, child) {
          final areaHeight = 130 * controller.value;
          // Gif yalnızca gösterge kilitlendiğinde baştan bir kez oynasın.
          final autostart = controller.value == 1 && !controller.isDragging
              ? Autostart.once
              : Autostart.no;

          return Stack(
            children: [
              // Gif katmanı (üstte, açılan alanın içinde ortalı).
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _gifOpacity,
                  child: Container(
                    height: areaHeight,
                    decoration: BoxDecoration(color: AppColors.background),
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    child: Gif(
                      autostart: autostart,
                      fps: 30,
                      height: 96,
                      fit: BoxFit.contain,
                      image: _asset,
                    ),
                  ),
                ),
              ),
              // İçerik: aşağı itilir; opak zemin gif'in sızmasını engeller.
              Transform.translate(
                offset: Offset(0, areaHeight),
                child: Container(
                  color: AppColors.background,
                  child: IgnorePointer(
                    ignoring: controller.isLoading,
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      child: widget.child,
    );
  }
}
