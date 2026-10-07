class RecognizedText {
  const RecognizedText(this.text);

  final String text;

  bool get isEmpty => text.trim().isEmpty;
}

abstract interface class TextRecognizer {
  Future<RecognizedText> recognize(String imagePath);

  Future<void> dispose();
}
