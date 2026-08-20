import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_handler/share_handler.dart';

class SharedStatement {
  const SharedStatement({
    required this.path,
    required this.name,
    this.mimeType,
  });

  final String path;
  final String name;
  final String? mimeType;
}

class IncomingShareService {
  static const supportedExtensions = <String>{
    'pdf',
    'xlsx',
    'xls',
    'csv',
    'jpg',
    'jpeg',
    'png',
  };

  final _controller = StreamController<SharedStatement>.broadcast();
  StreamSubscription<SharedMedia>? _subscription;
  SharedStatement? _pendingInitial;

  Stream<SharedStatement> get statements => _controller.stream;

  Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final handler = ShareHandlerPlatform.instance;
    _subscription = handler.sharedMediaStream.listen(
      (media) => _acceptMedia(media.attachments),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Incoming share stream failed: $error');
      },
    );

    try {
      final initial = await handler.getInitialSharedMedia();
      _pendingInitial = firstSupported(initial?.attachments);
    } catch (error) {
      debugPrint('Unable to read the initial share: $error');
    }
  }

  SharedStatement? takeInitialStatement() {
    final statement = _pendingInitial;
    _pendingInitial = null;
    return statement;
  }

  @visibleForTesting
  static SharedStatement? firstSupported(List<SharedAttachment?>? media) {
    for (final item in media ?? const <SharedAttachment?>[]) {
      final path = item?.path.trim() ?? '';
      if (path.isEmpty) continue;
      final name = Uri.tryParse(path)?.pathSegments.lastOrNull ?? path;
      final extension = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : '';
      if (supportedExtensions.contains(extension)) {
        return SharedStatement(
          path: path,
          name: name,
          mimeType: item?.type.name,
        );
      }
    }
    return null;
  }

  void _acceptMedia(List<SharedAttachment?>? media) {
    final statement = firstSupported(media);
    if (statement != null) _controller.add(statement);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}

final incomingShareServiceProvider = Provider<IncomingShareService>((ref) {
  throw StateError('IncomingShareService must be initialized at app startup.');
});
