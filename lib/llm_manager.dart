// lib/llm_manager.dart

import 'dart:async'; // For Completer
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/src/chatml_format.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';

class LLMManager {
  static final LLMManager _instance = LLMManager._internal();

  factory LLMManager() {
    return _instance;
  }

  LLMManager._internal();

  bool _isInitialized = false;
  String? _modelPath;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Copy model from assets to documents directory
    _modelPath = await _copyModelFromAssets();

    _isInitialized = true;
  }

  Future<String> _copyModelFromAssets() async {
    // application documents directory to load the gguf from assets
    final directory = await getApplicationDocumentsDirectory();

    // application path for gguf file (to be initialized)
    final modelPath = '${directory.path}/some_model.gguf';

    // Write the bytes to a file
    final modelFile = File(modelPath);
    // If the file already exists, you might skip rewriting or decide to overwrite
    if (!await modelFile.exists()) {
      final byteData = await rootBundle
          .load('assets/models/tinyllama-2-1b-miniguanaco.Q3_K_L.gguf');
      await modelFile.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return modelPath;
  }

  Future<String> generateExplanation(String sentence, String word) async {
    await initialize();

    Completer<String> completer = Completer<String>();

    String prompt =
        'You are a linguistic assistant. Provide explanations for the usage of word "$word" '
        'in the following sentence, with its syntactic category, and a short'
        'explanation in English of the usage in the sentence. Sentence: "$sentence"';

    final LlamaLoad loadCommand = LlamaLoad(
      path: _modelPath!, // Use the copied local model file
      modelParams: ModelParams(),
      contextParams: ContextParams(),
      samplingParams: SamplerParams(),
      format: ChatMLFormat(),
    );

    final llamaParent = LlamaParent(loadCommand);
    await llamaParent.init();

    llamaParent.stream.listen((response) {
      if (!completer.isCompleted) {
        completer.complete(response);
      }
    });

    // TODO(carrascomj): profile memory comsumption.
    completer.future.then((_) {
      llamaParent.dispose();
    });

    llamaParent.sendPrompt(prompt);

    return completer.future;
  }
}
