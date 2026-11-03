import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/quiz_model.dart';
import '../core/config/gemini_config.dart';

class GeminiService {
  /// Generate a structured QuizModel using Gemini API or subject-based intelligent generator
  Future<QuizModel> generateQuiz({
    required String subject,
    String? topic,
    required String difficulty,
    required int count,
  }) async {
    final apiKey = GeminiConfig.apiKey;
    final topicStr = (topic != null && topic.trim().isNotEmpty) ? topic.trim() : '';

    debugPrint('\n================ [GEMINI SERVICE: GENERATE QUIZ] ================');
    debugPrint('INPUT VALUES -> Subject: "$subject" | Topic: "$topicStr" | Level: "$difficulty" | Count: $count');
    debugPrint('=================================================================\n');

    if (apiKey.isNotEmpty) {
      final prompt = '''
You are an educational question generator. Generate a quiz about the specified subject and topic.

SUBJECT: "$subject"
${topicStr.isNotEmpty ? 'TOPIC: "$topicStr"' : 'TOPIC: Not specified'}
DIFFICULTY: "$difficulty"
NUMBER OF QUESTIONS: $count

Return ONLY a valid JSON object, NO Markdown formatting, NO backticks:
{
  "subject": "$subject",
  "topic": "${topicStr.isNotEmpty ? topicStr : ''}",
  "level": "$difficulty",
  "questions": [
    {
      "question": "A real academic question strictly about ${topicStr.isNotEmpty ? topicStr : subject}",
      "options": ["Option A","Option B","Option C","Option D"],
      "correctAnswer": 0,
      "explanation": "Academic explanation for why this answer is correct."
    }
  ]
}

Constraints:
- "options" MUST contain exactly 4 options.
- "correctAnswer" MUST be an integer index (0-3).
- You MUST generate exactly $count questions.
''';

      // Iterate over working fallback models
      for (final modelName in GeminiConfig.fallbackModels) {
        debugPrint('[GEMINI API] Attempting generation with model: $modelName');
        debugPrint('[GEMINI VALUES PASSED] Subject: "$subject", Topic: "$topicStr", Level: "$difficulty", Count: $count');
        
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
          );

          final response = await model
              .generateContent([Content.text(prompt)])
              .timeout(const Duration(seconds: 20));

          final rawText = response.text?.trim() ?? '';
          debugPrint('--------------------------------------------------');
          debugPrint('[GEMINI RAW RESPONSE FROM $modelName]:\n$rawText');
          debugPrint('--------------------------------------------------');

          if (rawText.isNotEmpty) {
            String cleanJson = rawText;
            if (cleanJson.startsWith('```json')) {
              cleanJson = cleanJson.substring(7);
            } else if (cleanJson.startsWith('```')) {
              cleanJson = cleanJson.substring(3);
            }
            if (cleanJson.endsWith('```')) {
              cleanJson = cleanJson.substring(0, cleanJson.length - 3);
            }
            cleanJson = cleanJson.trim();

            try {
              final Map<String, dynamic> data = jsonDecode(cleanJson);
              final List<QuizQuestionModel> qList = (data['questions'] as List? ?? [])
                  .map((q) => QuizQuestionModel.fromMap(q))
                  .toList();

              debugPrint('[GEMINI PARSED QUESTION COUNT]: ${qList.length} (Requested: $count)');

              // Validate questions strictly
              final validQuestions = qList.where((q) =>
                q.question.trim().isNotEmpty &&
                q.options.length == 4 &&
                q.correctAnswer >= 0 &&
                q.correctAnswer < 4
              ).toList();

              debugPrint('[GEMINI VALID QUESTION COUNT]: ${validQuestions.length}');

              if (validQuestions.isNotEmpty) {
                final finalQuestions = validQuestions.take(count).toList();
                debugPrint('[GEMINI FINAL DISPLAYED QUESTION COUNT]: ${finalQuestions.length}');

                return QuizModel(
                  id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
                  subject: topicStr.isNotEmpty ? '$subject - $topicStr' : subject,
                  difficulty: difficulty,
                  questions: finalQuestions,
                );
              }
            } catch (jsonErr) {
              debugPrint('[GEMINI PARSE ERROR]: $jsonErr');
            }
          }
        } catch (apiErr) {
          debugPrint('[GEMINI REQUEST FAILED for $modelName]: $apiErr');
        }
      }
    }

    debugPrint('[GEMINI FALLBACK] Gemini API failed or unavailable. Falling back to subject-specific offline bank.');
    return _generateSubjectFallbackQuiz(
      subject: subject,
      topic: topicStr,
      difficulty: difficulty,
      count: count,
    );
  }

  QuizModel _generateSubjectFallbackQuiz({
    required String subject,
    String? topic,
    required String difficulty,
    required int count,
  }) {
    final s = subject.toLowerCase().trim();
    final t = (topic ?? '').toLowerCase().trim();
    final combined = '$s $t';
    final List<QuizQuestionModel> bank = [];

    debugPrint('[SUBJECT FALLBACK CHECK] Checking offline topic bank for "$combined"');

    if (combined.contains('statistic') || combined.contains('probability')) {
      bank.addAll([
        QuizQuestionModel(question: 'In a normal distribution, approximately what percentage of data falls within one standard deviation of the mean?', options: ['50%', '68%', '95%', '99.7%'], correctAnswer: 1, explanation: 'The empirical rule states ~68% falls within 1 standard deviation.'),
        QuizQuestionModel(question: 'What is the measure of central tendency that is most affected by extreme outliers?', options: ['Median', 'Mean', 'Mode', 'Interquartile Range'], correctAnswer: 1, explanation: 'The mean incorporates all values, making it highly sensitive to extreme outliers.'),
        QuizQuestionModel(question: 'If two events A and B are mutually exclusive, what is P(A and B)?', options: ['P(A) * P(B)', 'P(A) + P(B)', '0', '1'], correctAnswer: 2, explanation: 'Mutually exclusive events cannot occur simultaneously, so P(A and B) = 0.'),
        QuizQuestionModel(question: 'What does standard deviation measure in a dataset?', options: ['Central location', 'Dispersion / spread around the mean', 'Maximum value', 'Skewness'], correctAnswer: 1, explanation: 'Standard deviation quantifies the amount of variation or dispersion around the mean.'),
        QuizQuestionModel(question: 'What is the median of the following set: {3, 7, 8, 12, 14}?', options: ['7', '8', '8.8', '12'], correctAnswer: 1, explanation: 'In a sorted set of 5 numbers, the 3rd number (8) is the median.'),
        QuizQuestionModel(question: 'A p-value less than alpha (0.05) typically leads to which decision?', options: ['Accept the null hypothesis', 'Reject the null hypothesis', 'Prove the alternative hypothesis', 'Increase sample size'], correctAnswer: 1, explanation: 'A p-value < 0.05 indicates statistical significance, rejecting the null hypothesis.'),
      ]);
    } else if (combined.contains('math') || combined.contains('algebra') || combined.contains('calculus') ||
        combined.contains('trig') || combined.contains('geometry') || combined.contains('arithmetic')) {
      bank.addAll([
        QuizQuestionModel(question: 'What is the value of sin 30 degrees?', options: ['0', '1/2', '1', 'sqrt(3)/2'], correctAnswer: 1, explanation: 'sin(30) = 1/2.'),
        QuizQuestionModel(question: 'What is the derivative of x squared?', options: ['x', '2x', '2', 'x cubed / 3'], correctAnswer: 1, explanation: 'd/dx(x^2) = 2x by the power rule.'),
        QuizQuestionModel(question: 'What is log base 10 of 100?', options: ['1', '2', '10', '100'], correctAnswer: 1, explanation: '10^2=100, so log10(100)=2.'),
        QuizQuestionModel(question: 'What is the area of a circle with radius r?', options: ['2*pi*r', 'pi*r^2', '4/3*pi*r^3', 'pi*d'], correctAnswer: 1, explanation: 'Area = pi * r^2.'),
        QuizQuestionModel(question: 'What is the quadratic formula?', options: ['x=(-b +/- sqrt(b^2-4ac))/2a', 'x=(b +/- sqrt(b^2-4ac))/2a', 'x=-b/2a', 'x=(-b +/- sqrt(b^2+4ac))/2a'], correctAnswer: 0, explanation: 'x=(-b +/- sqrt(b^2-4ac))/2a.'),
        QuizQuestionModel(question: 'What is cos 60 degrees?', options: ['1', 'sqrt(3)/2', '1/2', '0'], correctAnswer: 2, explanation: 'cos(60) = 1/2.'),
      ]);
    } else if (combined.contains('physic') || combined.contains('mechanic') || combined.contains('electro') ||
        combined.contains('optic') || combined.contains('thermodynamic') || combined.contains('force') || combined.contains('motion')) {
      bank.addAll([
        QuizQuestionModel(question: "What is Newton's Second Law?", options: ['F=ma', 'E=mc^2', 'v=u+at', 'P=W/t'], correctAnswer: 0, explanation: 'F=ma.'),
        QuizQuestionModel(question: 'What is the SI unit of electric current?', options: ['Volt', 'Ohm', 'Ampere', 'Watt'], correctAnswer: 2, explanation: 'Ampere (A).'),
        QuizQuestionModel(question: 'What is the speed of light in vacuum?', options: ['3e8 m/s', '3e6 m/s', '300 m/s', '9.8 m/s^2'], correctAnswer: 0, explanation: 'Approximately 3.00e8 m/s.'),
        QuizQuestionModel(question: 'What does conservation of energy state?', options: ['Energy can be created not destroyed', 'Energy cannot be created or destroyed only transformed', 'Energy can be destroyed', 'Energy created from nothing'], correctAnswer: 1, explanation: 'Energy is conserved.'),
        QuizQuestionModel(question: 'What is the unit of electric resistance?', options: ['Farad', 'Henry', 'Ohm', 'Ampere'], correctAnswer: 2, explanation: 'Ohm.'),
        QuizQuestionModel(question: "What is Ohm's Law?", options: ['V=IR', 'P=IV', 'F=ma', 'E=mc^2'], correctAnswer: 0, explanation: 'Voltage = Current x Resistance.'),
      ]);
    } else if (combined.contains('java') || combined.contains('spring') || combined.contains('jvm')) {
      bank.addAll([
        QuizQuestionModel(question: 'Which keyword inherits a class in Java?', options: ['implements', 'extends', 'inherits', 'super'], correctAnswer: 1, explanation: 'extends is used for inheritance.'),
        QuizQuestionModel(question: 'Output of System.out.println(10/3) in Java?', options: ['3.33', '3', '4', '3.0'], correctAnswer: 1, explanation: 'Integer division: 10/3=3.'),
        QuizQuestionModel(question: 'Which is NOT a Java primitive type?', options: ['int', 'boolean', 'String', 'double'], correctAnswer: 2, explanation: 'String is a class, not primitive.'),
        QuizQuestionModel(question: 'What does final do in Java?', options: ['Makes method abstract', 'Prevents modification/overriding/subclassing', 'Makes class serializable', 'Forces garbage collection'], correctAnswer: 1, explanation: 'final = constant, cannot override, cannot extend.'),
        QuizQuestionModel(question: 'Purpose of static keyword in Java?', options: ['Makes variable immutable', 'Member belongs to class not instances', 'Speeds execution', 'Prevents method calls'], correctAnswer: 1, explanation: 'static = belongs to class itself.'),
        QuizQuestionModel(question: 'What does OOP stand for?', options: ['Object-Oriented Programming', 'Online Object Processing', 'Ordered Object Parsing', 'Open Object Protocol'], correctAnswer: 0, explanation: 'Object-Oriented Programming.'),
      ]);
    } else if (combined.contains('python')) {
      bank.addAll([
        QuizQuestionModel(question: 'Output of print(type([])) in Python?', options: ['class array', 'class list', 'class tuple', 'class dict'], correctAnswer: 1, explanation: '[] creates a list.'),
        QuizQuestionModel(question: 'Keyword to define a function in Python?', options: ['func', 'function', 'def', 'define'], correctAnswer: 2, explanation: 'def defines a function.'),
        QuizQuestionModel(question: 'What does len() return in Python?', options: ['The type', 'Number of items', 'Memory size', 'Last index'], correctAnswer: 1, explanation: 'len() returns number of items.'),
        QuizQuestionModel(question: 'How to start a comment in Python?', options: ['//', '#', '/*', '--'], correctAnswer: 1, explanation: '# starts a single-line comment.'),
        QuizQuestionModel(question: 'Which is mutable in Python?', options: ['tuple', 'string', 'list', 'frozenset'], correctAnswer: 2, explanation: 'Lists are mutable.'),
      ]);
    } else if (combined.contains('data struct') || combined.contains('algorithm') || combined.contains('dsa') ||
        combined.contains('algo') || combined.contains('sorting') || combined.contains('graph') || combined.contains('tree')) {
      bank.addAll([
        QuizQuestionModel(question: 'Average search complexity of Hash Table?', options: ['O(1)', 'O(log n)', 'O(n)', 'O(n^2)'], correctAnswer: 0, explanation: 'O(1) average.'),
        QuizQuestionModel(question: 'Which data structure is FIFO?', options: ['Stack', 'Queue', 'Tree', 'Graph'], correctAnswer: 1, explanation: 'Queue is FIFO.'),
        QuizQuestionModel(question: 'Worst case of QuickSort?', options: ['O(n)', 'O(n log n)', 'O(n^2)', 'O(log n)'], correctAnswer: 2, explanation: 'O(n^2) when pivot is always min/max.'),
        QuizQuestionModel(question: 'Where is the smallest element in a BST?', options: ['Root', 'Rightmost', 'Leftmost', 'Last level'], correctAnswer: 2, explanation: 'Leftmost node.'),
        QuizQuestionModel(question: 'Space complexity of Merge Sort?', options: ['O(1)', 'O(log n)', 'O(n)', 'O(n^2)'], correctAnswer: 2, explanation: 'O(n) auxiliary space.'),
        QuizQuestionModel(question: 'BST inorder traversal gives?', options: ['Random order', 'Sorted ascending', 'Sorted descending', 'Level order'], correctAnswer: 1, explanation: 'Inorder = sorted ascending.'),
      ]);
    } else if (combined.contains('dbms') || combined.contains('database') || combined.contains('sql')) {
      bank.addAll([
        QuizQuestionModel(question: 'What does DBMS stand for?', options: ['Database Management System', 'Data Base Main System', 'Data Business Management System', 'Data Backup Management System'], correctAnswer: 0, explanation: 'DBMS stands for Database Management System.'),
        QuizQuestionModel(question: 'Which of the following is a NoSQL database?', options: ['MySQL', 'PostgreSQL', 'MongoDB', 'Oracle'], correctAnswer: 2, explanation: 'MongoDB is a document-oriented NoSQL database.'),
        QuizQuestionModel(question: 'What is a primary key?', options: ['A key used to unlock a database', 'A unique identifier for a record in a table', 'A key used for encryption', 'A foreign key constraint'], correctAnswer: 1, explanation: 'A primary key uniquely identifies each record in a database table.'),
        QuizQuestionModel(question: 'Which SQL keyword is used to sort the result-set?', options: ['ORDER BY', 'SORT BY', 'GROUP BY', 'ALIGN BY'], correctAnswer: 0, explanation: 'ORDER BY is used to sort the result-set.'),
        QuizQuestionModel(question: 'What does ACID stand for in DBMS?', options: ['Atomicity, Consistency, Isolation, Durability', 'Accuracy, Completeness, Isolation, Durability', 'Atomicity, Concurrency, Isolation, Durability', 'Atomicity, Consistency, Integrity, Durability'], correctAnswer: 0, explanation: 'ACID properties ensure reliable processing of database transactions.'),
      ]);
    } else if (combined.contains('chemist') || combined.contains('organic') || combined.contains('periodic') ||
        combined.contains('molecule') || combined.contains('atom') || combined.contains('bond') || combined.contains('reaction')) {
      bank.addAll([
        QuizQuestionModel(question: 'Chemical formula for water?', options: ['H2O2', 'H2O', 'HO', 'H3O'], correctAnswer: 1, explanation: 'H2O.'),
        QuizQuestionModel(question: 'Atomic number of Carbon?', options: ['4', '6', '8', '12'], correctAnswer: 1, explanation: 'Carbon has 6 protons.'),
        QuizQuestionModel(question: 'Gas produced when acid reacts with metal?', options: ['Oxygen', 'Nitrogen', 'CO2', 'Hydrogen'], correctAnswer: 3, explanation: 'Acid + Metal = Salt + H2.'),
        QuizQuestionModel(question: 'pH of a neutral solution?', options: ['0', '7', '14', '1'], correctAnswer: 1, explanation: 'pH 7 = neutral.'),
        QuizQuestionModel(question: 'Element with symbol Na?', options: ['Nitrogen', 'Nickel', 'Sodium', 'Neon'], correctAnswer: 2, explanation: 'Na = Sodium (Natrium).'),
      ]);
    } else if (combined.contains('biolog') || combined.contains('cell') || combined.contains('dna') ||
        combined.contains('genetics') || combined.contains('ecology') || combined.contains('evolution')) {
      bank.addAll([
        QuizQuestionModel(question: 'Powerhouse of the cell?', options: ['Nucleus', 'Ribosome', 'Mitochondria', 'Golgi apparatus'], correctAnswer: 2, explanation: 'Mitochondria produce ATP.'),
        QuizQuestionModel(question: 'Full form of DNA?', options: ['Deoxyribonucleic Acid', 'Diribonucleic Acid', 'Deoxyribose Nucleic Acid', 'Dinucleic Acid'], correctAnswer: 0, explanation: 'Deoxyribonucleic Acid.'),
        QuizQuestionModel(question: 'How many chromosomes do humans have?', options: ['23', '44', '46', '48'], correctAnswer: 2, explanation: '46 chromosomes (23 pairs).'),
        QuizQuestionModel(question: 'Process plants use to make food?', options: ['Respiration', 'Photosynthesis', 'Fermentation', 'Digestion'], correctAnswer: 1, explanation: 'Photosynthesis.'),
        QuizQuestionModel(question: 'Basic unit of life?', options: ['Organ', 'Tissue', 'Cell', 'Atom'], correctAnswer: 2, explanation: 'Cell is the basic unit of life.'),
      ]);
    } else if (combined.contains('histor') || combined.contains('war') || combined.contains('ancient') ||
        combined.contains('revolution') || combined.contains('civilization') || combined.contains('empire')) {
      bank.addAll([
        QuizQuestionModel(question: 'Year World War II ended?', options: ['1943', '1944', '1945', '1946'], correctAnswer: 2, explanation: '1945.'),
        QuizQuestionModel(question: 'First US President?', options: ['Abraham Lincoln', 'Thomas Jefferson', 'George Washington', 'John Adams'], correctAnswer: 2, explanation: 'George Washington.'),
        QuizQuestionModel(question: 'When did the French Revolution begin?', options: ['1775', '1789', '1804', '1815'], correctAnswer: 1, explanation: '1789, storming of the Bastille.'),
        QuizQuestionModel(question: 'Julius Caesar ruled which empire?', options: ['Greek', 'Ottoman', 'Roman', 'Byzantine'], correctAnswer: 2, explanation: 'Roman Empire.'),
      ]);
    } else if (combined.contains('economics') || combined.contains('finance') || combined.contains('gdp') ||
        combined.contains('market') || combined.contains('supply') || combined.contains('demand')) {
      bank.addAll([
        QuizQuestionModel(question: 'What does GDP stand for?', options: ['Gross Domestic Product', 'General Demand Price', 'Global Development Plan', 'Gross Demand Percentage'], correctAnswer: 0, explanation: 'Gross Domestic Product.'),
        QuizQuestionModel(question: 'Law of demand states?', options: ['Price up demand up', 'Price up demand down', 'Unrelated', 'Demand sets price'], correctAnswer: 1, explanation: 'Higher price = lower quantity demanded.'),
        QuizQuestionModel(question: 'What is inflation?', options: ['Price decrease', 'Money supply increase only', 'General price increase over time', 'Gov spending reduction'], correctAnswer: 2, explanation: 'General rise in prices over time.'),
        QuizQuestionModel(question: 'What is opportunity cost?', options: ['Product price', 'Value of next best alternative foregone', 'Unit production cost', 'Government tax'], correctAnswer: 1, explanation: 'Value of what you give up when choosing.'),
      ]);
    } else if (combined.contains('english') || combined.contains('grammar') || combined.contains('literature') ||
        combined.contains('writing') || combined.contains('language')) {
      bank.addAll([
        QuizQuestionModel(question: 'What is a noun?', options: ['A doing word', 'A naming word', 'A describing word', 'A joining word'], correctAnswer: 1, explanation: 'A noun is a naming word for a person, place, thing, or idea.'),
        QuizQuestionModel(question: 'What is the past tense of "go"?', options: ['Goed', 'Gone', 'Went', 'Going'], correctAnswer: 2, explanation: 'The past tense of go is went.'),
        QuizQuestionModel(question: 'What is an antonym?', options: ['A word with the same meaning', 'A word with the opposite meaning', 'A word that sounds similar', 'A word with no meaning'], correctAnswer: 1, explanation: 'An antonym is a word with the opposite meaning.'),
        QuizQuestionModel(question: 'Identify the adjective: "The tall building"', options: ['The', 'tall', 'building', 'None'], correctAnswer: 1, explanation: 'Tall is the adjective describing the building.'),
        QuizQuestionModel(question: 'What is a simile?', options: ['Comparison without like/as', 'Comparison using like/as', 'Exaggeration', 'Sound words'], correctAnswer: 1, explanation: 'A simile compares two things using like or as.'),
      ]);
    } else if (combined.contains('comput') || combined.contains('programming') || combined.contains('software') ||
        combined.contains('coding') || combined.contains('c++') || combined.contains('javascript') || combined.contains('web')) {
      bank.addAll([
        QuizQuestionModel(question: 'What does CPU stand for?', options: ['Central Processing Unit', 'Computer Personal Unit', 'Central Program Utility', 'Core Processing Unit'], correctAnswer: 0, explanation: 'CPU stands for Central Processing Unit.'),
        QuizQuestionModel(question: 'What is RAM?', options: ['Read Access Memory', 'Random Access Memory', 'Run Application Memory', 'Rapid Access Module'], correctAnswer: 1, explanation: 'RAM stands for Random Access Memory.'),
        QuizQuestionModel(question: 'What is an operating system?', options: ['A hardware component', 'Software managing hardware and software resources', 'A programming language', 'A web browser'], correctAnswer: 1, explanation: 'An OS manages hardware and software resources.'),
        QuizQuestionModel(question: 'What does HTML stand for?', options: ['HyperText Markup Language', 'High Tech Machine Language', 'Home Tool Markup Language', 'Hyper Transfer Markup Language'], correctAnswer: 0, explanation: 'HTML = HyperText Markup Language.'),
        QuizQuestionModel(question: 'What is a compiler?', options: ['A type of memory', 'Converts source code to machine code', 'A hardware device', 'A web framework'], correctAnswer: 1, explanation: 'A compiler converts source code to machine code.'),
      ]);
    } else {
      // NEVER allow fallback to random/unrelated trivia (like Mars/Red Planet/World War)
      debugPrint('[FALLBACK REJECTED] No offline questions match "$combined". Forbidding unrelated questions.');
      throw Exception('Could not generate questions for "${topic != null && topic.isNotEmpty ? '$subject - $topic' : subject}". Please check your internet connection so Gemini can generate questions on this topic.');
    }

    final random = Random();
    bank.shuffle(random);
    final selectedQuestions = bank.take(count.clamp(1, bank.length)).toList();

    debugPrint('[SUBJECT FALLBACK SUCCESS] Generated ${selectedQuestions.length} offline questions for "$combined"');

    return QuizModel(
      id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
      subject: topic != null && topic.isNotEmpty ? '$subject - $topic' : subject,
      difficulty: difficulty,
      questions: selectedQuestions,
    );
  }
}
