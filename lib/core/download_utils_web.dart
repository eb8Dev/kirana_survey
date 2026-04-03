import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

Future<bool> downloadCsv(String fileName, String csv) async {
  // Use utf8.encode to correctly handle non-ASCII characters (like emojis or Indian language characters)
  final encodedCsv = utf8.encode(csv);
  
  // Create a Uint8List starting with the BOM (0xEF, 0xBB, 0xBF)
  final bytes = Uint8List(3 + encodedCsv.length);
  bytes[0] = 0xEF;
  bytes[1] = 0xBB;
  bytes[2] = 0xBF;
  bytes.setRange(3, bytes.length, encodedCsv);

  final blob = Blob([bytes], 'text/csv;charset=utf-8;');
  final url = Url.createObjectUrlFromBlob(blob);
  
  final anchor = AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  
  // Revoke the URL after a small delay to ensure the browser has started the download
  Future.delayed(const Duration(milliseconds: 100), () {
    Url.revokeObjectUrl(url);
  });

  return true;
}
