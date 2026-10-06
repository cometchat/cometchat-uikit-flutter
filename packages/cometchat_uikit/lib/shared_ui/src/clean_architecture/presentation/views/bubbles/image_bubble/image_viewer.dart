import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import "../../../../clean_architecture.dart";
import '../../../../core/utils/platform_utils/platform_image_utils.dart'
    as platform_image;
import 'package:cached_network_image/cached_network_image.dart';

///Gives Full Screen image view for passed image url
class ImageViewer extends StatefulWidget {
  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.placeholderImage,
    this.placeHolderImagePackageName,
  });

  ///[imageUrl] image url should be passed
  final String imageUrl;

  ///[placeholderImage] is shown temporarily for the duration when image is loading from url
  final String? placeholderImage;

  ///[placeHolderImagePackageName] is package path for the custom placeholder image
  final String? placeHolderImagePackageName;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  Key imageKey = UniqueKey();
  double _currentScale = 1.0;
  bool _isZoomed = false;
  bool _isLoading = true; // Track loading state

  late CometChatImageBubbleStyle imageBubbleStyle;
  late CometChatColorPalette colorPalette;
  late CometChatSpacing spacing;

  @override
  void initState() {
    super.initState();
    // Start with loading state for network images
    if (!_isLocalFile) {
      _isLoading = true;
      // Set a timer to hide loading after a reasonable time
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } else {
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    colorPalette = CometChatThemeHelper.getColorPalette(context);
    spacing = CometChatThemeHelper.getSpacing(context);
    super.didChangeDependencies();
  }

  bool get _isLocalFile {
    return FileUtils.isLocalFileAvailable(widget.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final colorPalette = CometChatThemeHelper.getColorPalette(context);
    return Scaffold(
      backgroundColor: colorPalette.background1,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorPalette.background1,
        iconTheme: IconThemeData(color: colorPalette.iconPrimary),
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.1,
              maxScale: 4.0,
              onInteractionEnd: (ScaleEndDetails details) {
                // Only update state when interaction ends for smoother performance
                final newZoomed = _currentScale > 1.1;
                if (_isZoomed != newZoomed) {
                  setState(() {
                    _isZoomed = newZoomed;
                  });
                }
              },
              onInteractionUpdate: (ScaleUpdateDetails details) {
                _currentScale = details.scale;
              },
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: _isLocalFile
                    ? platform_image.buildFileImage(
                        widget.imageUrl,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: 512,
                        cacheHeight: 512,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage();
                        },
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded || frame != null) {
                                // Image loaded successfully
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted && _isLoading) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                });
                              }
                              return child;
                            },
                      )
                    : kIsWeb
                    // On web, use Image.network (HTML <img> tag) to bypass CORS.
                    ? Image.network(
                        key: imageKey,
                        widget.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _isLoading) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            });
                            return child;
                          }
                          return Image(
                            fit: BoxFit.contain,
                            image: AssetImage(
                              widget.placeholderImage ??
                                  AssetConstants.imagePlaceholder,
                              package:
                                  widget.placeHolderImagePackageName ??
                                  UIConstants.packageName,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          if (_isLoading) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            });
                          }
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: Translations.of(context).retry,
                                  onPressed: () {
                                    setState(() {
                                      _isLoading = true;
                                      imageKey = ValueKey(
                                        widget.imageUrl +
                                            DateTime.now().toString(),
                                      );
                                    });
                                    Future.delayed(
                                      const Duration(seconds: 3),
                                      () {
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      },
                                    );
                                  },
                                  icon: Image.asset(
                                    excludeFromSemantics: true,
                                    AssetConstants.refreshIcon,
                                    height: 24,
                                    width: 24,
                                    package: UIConstants.packageName,
                                    color: colorPalette.iconPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : CachedNetworkImage(
                        key: imageKey,
                        imageUrl: widget.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Image(
                          fit: BoxFit.contain,
                          image: AssetImage(
                            widget.placeholderImage ??
                                AssetConstants.imagePlaceholder,
                            package:
                                widget.placeHolderImagePackageName ??
                                UIConstants.packageName,
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          // Set loading to false on error
                          if (_isLoading) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            });
                          }
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: Translations.of(context).retry,
                                  onPressed: () {
                                    setState(() {
                                      _isLoading = true;
                                      CachedNetworkImage.evictFromCache(
                                        widget.imageUrl,
                                      );
                                      imageKey = ValueKey(
                                        widget.imageUrl +
                                            DateTime.now().toString(),
                                      );
                                    });
                                    Future.delayed(
                                      const Duration(seconds: 3),
                                      () {
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      },
                                    );
                                  },
                                  icon: Image.asset(
                                    excludeFromSemantics: true,
                                    AssetConstants.refreshIcon,
                                    height: 24,
                                    width: 24,
                                    package: UIConstants.packageName,
                                    color: colorPalette.iconPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        fadeInDuration: const Duration(milliseconds: 300),
                        imageBuilder: (context, imageProvider) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _isLoading) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          });
                          return Image(
                            image: imageProvider,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
              ),
            ),
            // Circular progress indicator overlay
            if (_isLoading)
              Container(
                color: colorPalette.background1?.withValues(alpha: 0.8),
                child: Center(
                  child: CircularProgressIndicator(
                    color: colorPalette.iconSecondary ?? Colors.grey,
                    backgroundColor: colorPalette.neutral300?.withValues(
                      alpha: 0.3,
                    ),
                    strokeWidth: 3.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: colorPalette.background3,
      alignment: Alignment.center,
      child: Image(
        fit: BoxFit.contain,
        color: colorPalette.iconTertiary,
        image: AssetImage(
          widget.placeholderImage ?? AssetConstants.imagePlaceholder,
          package:
              widget.placeHolderImagePackageName ?? UIConstants.packageName,
        ),
      ),
    );
  }
}
