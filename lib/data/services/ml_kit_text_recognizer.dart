import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as mlkit;

import '../../domain/services/text_recognizer.dart';

class MlKitTextRecognizer implements TextRecognizer {
  mlkit.TextRecognizer? _recognizer;

  mlkit.TextRecognizer get _engine => _recognizer ??= mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);

  @override
  Future<RecognizedText> recognize(String imagePath) async {
    final result = await _engine.processImage(mlkit.InputImage.fromFilePath(imagePath));
    return RecognizedText(result.text);
  }

  @override
  Future<void> dispose() async {
    final engine = _recognizer;
    _recognizer = null;
    await engine?.close();
  }
}
