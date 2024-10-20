import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:math';

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
    Color(0xFF01a804), // Saturated green
    Colors.yellow,
    Colors.blue,
    Colors.orange,
  ];
  Color currentBackgroundColor = Color(0xFF01a804); // Initial background color
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
    super.initState();
    _loadWords();
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    print('${directory.path}/words.json');
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
    print(words[currentIndex].score);
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
                    style: GoogleFonts.sniglet(
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
                    _showAddWordDialog();
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
                    _showAddSentenceDialog();
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
                right: 20,
                bottom: 160,
                child: FloatingActionButton(
                  heroTag: 'addTranslation',
                  onPressed: () {
                    _showAddTranslationDialog();
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

  void _showAddWordDialog() {
    TextEditingController wordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add New Word"),
          content: TextField(
            controller: wordController,
            decoration: InputDecoration(hintText: "Enter a new word"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Add"),
              onPressed: () {
                _addNewWord(wordController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddSentenceDialog() {
    TextEditingController sentenceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Sentence"),
          content: TextField(
            controller: sentenceController,
            decoration: InputDecoration(hintText: "Enter a sentence"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Add"),
              onPressed: () {
                _addSentence(sentenceController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddTranslationDialog() {
    TextEditingController translationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Translation"),
          content: TextField(
            controller: translationController,
            decoration: InputDecoration(hintText: "Enter the translation"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Add"),
              onPressed: () {
                _addTranslation(translationController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Settings"),
          content: SingleChildScrollView(
            child: Column(
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
                    _toggleButtonVisibility('addWord');
                  },
                ),
                SwitchListTile(
                  title: Text('Show Add Sentence Button'),
                  value: buttonVisibility['addSentence']!,
                  onChanged: (value) {
                    _toggleButtonVisibility('addSentence');
                  },
                ),
                SwitchListTile(
                  title: Text('Show Add Translation Button'),
                  value: buttonVisibility['addTranslation']!,
                  onChanged: (value) {
                    _toggleButtonVisibility('addTranslation');
                  },
                ),
                SwitchListTile(
                  title: Text('Show Translation Button'),
                  value: buttonVisibility['showTranslation']!,
                  onChanged: (value) {
                    _toggleButtonVisibility('showTranslation');
                  },
                ),
                SwitchListTile(
                  title: Text('Show Sentence Button'),
                  value: buttonVisibility['showSentence']!,
                  onChanged: (value) {
                    _toggleButtonVisibility('showSentence');
                  },
                ),
              ],
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
