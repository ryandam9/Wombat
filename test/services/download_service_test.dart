import 'package:flutter_test/flutter_test.dart';
import 'package:route/services/download_service.dart';

void main() {
  group('DownloadService.extensionForMime', () {
    test('maps common MIME types to extensions', () {
      expect(DownloadService.extensionForMime('text/markdown'), 'md');
      expect(DownloadService.extensionForMime('image/png'), 'png');
      expect(DownloadService.extensionForMime('image/jpeg'), 'jpg');
      expect(DownloadService.extensionForMime('audio/wav'), 'wav');
      expect(DownloadService.extensionForMime('audio/mpeg'), 'mp3');
      expect(DownloadService.extensionForMime('application/pdf'), 'pdf');
    });

    test('falls back to the subtype, then bin/txt', () {
      expect(DownloadService.extensionForMime('application/zip'), 'zip');
      expect(DownloadService.extensionForMime(null), 'txt');
    });
  });

  group('DownloadService.sanitize', () {
    test('strips path-unsafe characters', () {
      expect(DownloadService.sanitize('a/b:c*?"<>|d'), 'a_b_c_d');
    });

    test('collapses repeats and falls back when empty', () {
      expect(DownloadService.sanitize('   '), 'route-output');
      expect(DownloadService.sanitize('//'), '_');
    });
  });

  group('DownloadService.buildFileName', () {
    test('combines a sanitized base with the inferred extension', () {
      expect(
        DownloadService.buildFileName('route-image', 'image/png'),
        'route-image.png',
      );
      expect(
        DownloadService.buildFileName('my reply', 'text/markdown'),
        'my reply.md',
      );
    });
  });
}
