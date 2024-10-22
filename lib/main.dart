import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:file_picker/file_picker.dart'; // Import the file_picker package
import 'package:flutter/services.dart'; // For handling platform exceptions

void main() {
  runApp(LanguageLearningApp());
}

class LanguageLearningApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vtjr',
      home: LanguageLearningHomePage(),
    );
  }
}

/// The kind of input text that a user may introduce.
enum TextKind {
  word,
  sentence,
  translation;

  @override
  String toString() {
    return (this == TextKind.word)
        ? "Word"
        : (this == TextKind.sentence)
            ? "Sentence"
            : "Translation";
  }
}

/// Central class to hold language information in the app
/// that is de/serialize from a file.
class Word {
  String word;
  List<String> sentences;
  String translation;
  int score;
  int currentSentenceIndex;

  Word({
    required this.word,
    this.sentences = const [],
    this.translation = '',
    this.score = 0,
    this.currentSentenceIndex = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'sentences': sentences,
      'translation': translation,
      'score': score,
      'currentSentenceIndex': currentSentenceIndex,
    };
  }

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'],
      sentences: (json['sentences'] != null)
          ? List<String>.from(json['sentences'])
          : [],
      translation: json['translation'] ?? '',
      score: json['score'] ?? 0,
      currentSentenceIndex: json['currentSentenceIndex'] ?? 0,
    );
  }
}

class LanguageLearningHomePage extends StatefulWidget {
  @override
  _LanguageLearningHomePageState createState() =>
      _LanguageLearningHomePageState();
}

class _LanguageLearningHomePageState extends State<LanguageLearningHomePage> {
  List<Word> words = [];
  int currentIndex = 0;
  List<Color> backgroundColors = [
    Colors.red,
    Colors.yellow,
    Colors.blue,
    Colors.orange,
  ];
  Color currentBackgroundColor = Colors.red; // Initial background color
  bool showTranslation = false;
  bool showSentence = false;
  bool isBlackBackground = false;
  String learnedLanguage = 'ro'; // Romanian
  Map<String, bool> buttonVisibility = {
    'addWord': true,
    'addSentence': true,
    'addTranslation': true,
    'showSentence': true,
    'showTranslation': true,
  };

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    super.initState();
    _loadWords();
  }

  /// Export the current word data to a JSON file
  Future<void> _exportWordData() async {
    try {
      // Convert the words list to JSON
      String jsonContent =
          json.encode(words.map((word) => word.toJson()).toList());

      // Let the user choose where to save the file
      String? outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Word Data',
        fileName: 'word_data_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFilePath != null) {
        File file = File(outputFilePath);
        await file.writeAsString(jsonContent);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Word data exported successfully!')),
        );
      } else {
        // User canceled the picker
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export canceled.')),
        );
      }
    } catch (e) {
      // Handle any errors during export
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export word data: $e')),
      );
    }
  }

  /// Import word data from a JSON file
  Future<void> _importWordData() async {
    try {
      // Let the user select a JSON file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Word Data',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        String importFilePath = result.files.single.path!;
        File importFile = File(importFilePath);
        String fileContent = await importFile.readAsString();

        // Parse the JSON content
        List<dynamic> jsonData = json.decode(fileContent);

        // Convert JSON data to List<Word>
        List<Word> importedWords =
            jsonData.map((e) => Word.fromJson(e)).toList();

        // Confirm with the user before replacing existing data
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Confirm Import"),
              content: Text(
                  "Importing will replace your current word data. Continue?"),
              actions: <Widget>[
                TextButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text("Import"),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );

        if (confirm != null && confirm) {
          setState(() {
            words = importedWords;
            currentIndex = 0;
            currentBackgroundColor = _getBackgroundColor();
            showTranslation = false;
            showSentence = false;
            isBlackBackground = false;
          });
          _saveWords(); // Save the imported data
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Word data imported successfully!')),
          );
        } else {
          // User canceled the import
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import canceled.')),
          );
        }
      } else {
        // User canceled the picker
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import canceled.')),
        );
      }
    } on FormatException catch (e) {
      // Handle JSON format errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON format: $e')),
      );
    } on PlatformException catch (e) {
      // Handle platform-specific errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Platform error: $e')),
      );
    } catch (e) {
      // Handle any other errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import word data: $e')),
      );
    }
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/words.json');
  }

  Future<void> _loadWords() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        List<dynamic> jsonData = json.decode(contents);
        setState(() {
          words = jsonData.map((e) => Word.fromJson(e)).toList();
          currentBackgroundColor = _getBackgroundColor();
        });
      }
    } catch (e) {
      // If encountering an error, start with an empty list
      setState(() {
        words = [];
      });
    }
  }

  Future<void> _saveWords() async {
    final file = await _getLocalFile();
    List<Map<String, dynamic>> jsonData = words.map((e) => e.toJson()).toList();
    await file.writeAsString(json.encode(jsonData));
  }

  void _addNewWord(String newWord) {
    if (newWord.trim().isEmpty) return;
    if (words.any((w) => w.word == newWord.trim())) return;
    setState(() {
      words.add(Word(word: newWord.trim(), sentences: []));
      currentIndex = words.length - 1;
      showTranslation = false;
      showSentence = false;
      isBlackBackground = false;
      currentBackgroundColor = _getBackgroundColor();
      _saveWords();
    });
  }

  void _addSentence(String sentence) {
    if (sentence.trim().isEmpty) return;
    if (words[currentIndex].sentences.any((s) => s == sentence.trim())) return;
    setState(() {
      words[currentIndex].sentences.add(sentence.trim());
      _saveWords();
    });
  }

  void _addTranslation(String translation) {
    if (translation.trim().isEmpty) return;
    setState(() {
      words[currentIndex].translation = translation.trim();
      _saveWords();
    });
  }

  void _incrementScore(int increment) {
    setState(() {
      words[currentIndex].score += increment;
      _saveWords();
    });
  }

  Color _getBackgroundColor() {
    int colorIndex = (currentIndex ~/ 3) % backgroundColors.length;
    return backgroundColors[colorIndex];
  }

  void _toggleButtonVisibility(String buttonKey) {
    setState(() {
      buttonVisibility[buttonKey] = !buttonVisibility[buttonKey]!;
    });
  }

  void _resetView() {
    setState(() {
      showTranslation = false;
      showSentence = false;
      isBlackBackground = false;
    });
  }

  void _selectNextWord(int direction) {
    if (words.isEmpty) return;

    // Build a list of indices with weights proportional to their scores
    List<int> weightedIndices = [];
    for (int i = 0; i < words.length; i++) {
      int weight = words[i].score + 1; // Ensure minimum weight of 1
      for (int j = 0; j < weight; j++) {
        weightedIndices.add(i);
      }
    }

    // Remove the current index to avoid immediate repetition
    weightedIndices.removeWhere((index) => index == currentIndex);

    if (weightedIndices.isEmpty) {
      // If all words have zero score or only one word exists
      if (currentIndex < words.length - 1) {
        currentIndex++;
      } else if (currentIndex > 0) {
        currentIndex--;
      }
    } else {
      // Randomly select the next word based on weights
      Random random = Random();
      currentIndex = weightedIndices[random.nextInt(weightedIndices.length)];
    }

    // Reset the score and current sentence index of the current word
    words[currentIndex].score = min(words[currentIndex].score - 2, 1);
    words[currentIndex].currentSentenceIndex = 0;

    // Update the background color and reset views
    currentBackgroundColor = _getBackgroundColor();
    _resetView();
  }

  @override
  Widget build(BuildContext context) {
    String displayText = '';
    if (words.isNotEmpty) {
      if (showTranslation && words[currentIndex].translation.isNotEmpty) {
        displayText = words[currentIndex].translation;
      } else if (showSentence && words[currentIndex].sentences.isNotEmpty) {
        displayText = words[currentIndex]
            .sentences[words[currentIndex].currentSentenceIndex];
      } else {
        displayText = words[currentIndex].word;
      }
    }

    return Scaffold(
        backgroundColor:
            isBlackBackground ? Colors.black : currentBackgroundColor,
        body: Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (isBlackBackground) {
                  _resetView();
                }
              },
              onHorizontalDragEnd: (details) {
                setState(() {
                  if (details.primaryVelocity! != 0) {
                    _selectNextWord(1);
                  }
                });
              },
              child: Container(
                color: Colors.transparent, // Ensure it covers the full area
                child: Center(
                  child: Text(
                    displayText,
                    style: GoogleFonts.arima(
                      fontSize: 42,
                      color: isBlackBackground ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // Add Word Button
            if (buttonVisibility['addWord']!)
              Positioned(
                right: 20,
                bottom: 20,
                child: FloatingActionButton(
                  heroTag: 'addWord',
                  onPressed: () {
                    _showInputDialog(TextKind.word);
                  },
                  shape: CircleBorder(),
                  backgroundColor: Colors.black.withOpacity(0.6),
                  foregroundColor: Colors.white,
                  focusColor: Colors.black,
                  splashColor: Colors.black,
                  child: Icon(Icons.add),
                ),
              ),
            // Add Sentence Button
            if (buttonVisibility['addSentence']!)
              Positioned(
                right: 20,
                bottom: 90,
                child: FloatingActionButton(
                  heroTag: 'addSentence',
                  onPressed: () {
                    _showInputDialog(TextKind.sentence);
                  },
                  shape: CircleBorder(),
                  backgroundColor: Colors.black.withOpacity(0.6),
                  foregroundColor: Colors.white,
                  focusColor: Colors.black,
                  splashColor: Colors.black,
                  child: const Icon(Icons.edit),
                ),
              ),
            // Add Translation Button
            if (buttonVisibility['addTranslation']!)
              Positioned(
                right: 90,
                bottom: 20,
                child: FloatingActionButton(
                  heroTag: 'addTranslation',
                  onPressed: () {
                    _showInputDialog(TextKind.translation);
                  },
                  shape: CircleBorder(),
                  backgroundColor: Colors.black.withOpacity(0.6),
                  foregroundColor: Colors.white,
                  focusColor: Colors.black,
                  splashColor: Colors.black,
                  child: Icon(Icons.translate),
                ),
              ),
            // Show Translation Button
            if (buttonVisibility['showTranslation']!)
              Positioned(
                right: 20,
                top: 20,
                child: FloatingActionButton(
                  heroTag: 'showTranslation',
                  onPressed: () {
                    if (words[currentIndex].translation.isNotEmpty) {
                      setState(() {
                        showTranslation = true;
                        showSentence = false;
                        isBlackBackground = true;
                        _incrementScore(3); // Increment score by +3
                      });
                    }
                  },
                  shape: CircleBorder(),
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.black,
                  focusColor: Colors.pink,
                  splashColor: Colors.pink,
                  child: Icon(Icons.visibility),
                ),
              ),
            // Show Sentence Button
            if (buttonVisibility['showSentence']!)
              Positioned(
                right: 20,
                top: 90,
                child: FloatingActionButton(
                  heroTag: 'showSentence',
                  onPressed: () {
                    if (words[currentIndex].sentences.isNotEmpty) {
                      setState(() {
                        showSentence = true;
                        showTranslation = false;
                        isBlackBackground = true;
                        _incrementScore(1); // Increment score by +1
                        _advanceSentenceIndex();
                      });
                    }
                  },
                  shape: CircleBorder(),
                  backgroundColor: Colors.lime,
                  foregroundColor: Colors.black,
                  focusColor: Colors.pink,
                  splashColor: Colors.pink,
                  child: Icon(Icons.more_horiz),
                ),
              ),
            // Settings Button
            Positioned(
              left: 20,
              bottom: 20,
              child: FloatingActionButton(
                heroTag: 'settings',
                onPressed: () {
                  _showSettingsDialog();
                },
                shape: CircleBorder(),
                backgroundColor: Colors.black.withOpacity(0.6),
                foregroundColor: Colors.white,
                focusColor: Colors.black,
                splashColor: Colors.black,
                child: const Icon(Icons.settings),
              ),
            ),
          ],
        ),
        floatingActionButton: null);
  }

  void _advanceSentenceIndex() {
    Word currentWord = words[currentIndex];
    currentWord.currentSentenceIndex =
        (currentWord.currentSentenceIndex + 1) % currentWord.sentences.length;
    _saveWords();
  }

  Future<void> _showInputDialog(TextKind textKind) async {
    TextEditingController wordController = TextEditingController();
    await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Add ${textKind.toString()}"),
            content: TextField(
              controller: wordController,
              decoration: InputDecoration(
                  hintText:
                      "Enter ${textKind.toString().toLowerCase()} here..."),
            ),
            actions: <Widget>[
              TextButton(
                child: Text("Add"),
                onPressed: () {
                  textKind == TextKind.word
                      ? _addNewWord(wordController.text)
                      : textKind == TextKind.sentence
                          ? _addSentence(wordController.text)
                          : _addTranslation(wordController.text);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
    // Reapply immersive mode after dialog is closed
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Settings"),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateDialog) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Language selection (only Romanian supported)
                    ListTile(
                      title: Text('Learning Language'),
                      subtitle: Text('Romanian'),
                    ),
                    // Button toggles
                    SwitchListTile(
                      title: Text('Show Add Word Button'),
                      value: buttonVisibility['addWord']!,
                      onChanged: (value) {
                        setState(() {
                          _toggleButtonVisibility('addWord');
                        });
                        setStateDialog(() {}); // Update the dialog's UI
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show Add Sentence Button'),
                      value: buttonVisibility['addSentence']!,
                      onChanged: (value) {
                        setState(() {
                          _toggleButtonVisibility('addSentence');
                        });
                        setStateDialog(() {}); // Update the dialog's UI
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show Add Translation Button'),
                      value: buttonVisibility['addTranslation']!,
                      onChanged: (value) {
                        setState(() {
                          _toggleButtonVisibility('addTranslation');
                        });
                        setStateDialog(() {}); // Update the dialog's UI
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show Translation Button'),
                      value: buttonVisibility['showTranslation']!,
                      onChanged: (value) {
                        setState(() {
                          _toggleButtonVisibility('showTranslation');
                        });
                        setStateDialog(() {}); // Update the dialog's UI
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show Sentence Button'),
                      value: buttonVisibility['showSentence']!,
                      onChanged: (value) {
                        setState(() {
                          _toggleButtonVisibility('showSentence');
                        });
                        setStateDialog(() {}); // Update the dialog's UI
                      },
                    ),
                    Divider(), // Add a divider for separation
                    // per-user I/O word data
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Manage Word Data',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.file_upload),
                          label: Text("Export"),
                          onPressed: () async {
                            Navigator.of(context)
                                .pop(); // Close the settings dialog
                            await _exportWordData();
                          },
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.file_download),
                          label: Text("Import"),
                          onPressed: () async {
                            Navigator.of(context)
                                .pop(); // Close the settings dialog
                            await _importWordData();
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Close"),
              onPressed: () {
                _saveWords(); // Save settings if necessary
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
