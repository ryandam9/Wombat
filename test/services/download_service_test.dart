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

  group('DownloadService.textForSave', () {
    test('unwraps a fenced SVG and saves as svg', () {
      const raw = '```xml\n<svg viewBox="0 0 1 1"><rect/></svg>\n```';
      final r = DownloadService.textForSave(raw);
      expect(r.mimeType, 'image/svg+xml');
      expect(r.text, '<svg viewBox="0 0 1 1"><rect/></svg>');
      expect(DownloadService.extensionForMime(r.mimeType), 'svg');
    });

    test('detects bare SVG without fences', () {
      const raw = '<svg><circle/></svg>';
      expect(DownloadService.textForSave(raw).mimeType, 'image/svg+xml');
    });

    test('keeps ordinary replies as markdown', () {
      const raw = '# Title\n\nSome **text**.';
      final r = DownloadService.textForSave(raw);
      expect(r.mimeType, 'text/markdown');
      expect(r.text, raw);
    });

    test('does not treat prose mentioning <svg> as an SVG file', () {
      const raw = 'You can use the `<svg>` tag like this.';
      expect(DownloadService.textForSave(raw).mimeType, 'text/markdown');
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
