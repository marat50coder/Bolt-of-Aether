import 'date_keys.dart';

/// Morning Charge content: one word and one quote per calendar day, chosen
/// deterministically so every device shows the exact same pair on the exact
/// same date — with no network call and nothing to keep in sync.
class RitualContent {
  const RitualContent._();

  static const List<String> words = [
    'Radiance', 'Momentum', 'Clarity', 'Grace', 'Courage', 'Wonder',
    'Renewal', 'Harmony', 'Spark', 'Devotion', 'Resolve', 'Serenity',
    'Vigor', 'Kindness', 'Purpose', 'Gratitude', 'Bloom', 'Anchor',
    'Luminous', 'Steady', 'Ignite', 'Wholeness', 'Presence', 'Trust',
    'Wander', 'Bravery', 'Ease', 'Sunrise', 'Abundance', 'Flow',
    'Awaken', 'Levity',
  ];

  static const List<String> quotes = [
    'Start where you stand, with whatever light you have.',
    'A calm morning is a quiet kind of courage.',
    'Small charges, kept up daily, become unstoppable currents.',
    'You do not need to see the whole staircase to take the first step.',
    'Let today be gentle with you, and you gentle with today.',
    'The bolt that moves the sky first moved the smallest cloud.',
    'Rest was not a delay. It was part of the work.',
    'Every sunrise is proof that dark does not get the last word.',
    'Show up soft. Show up steady. That is enough for now.',
    'What you water grows — choose your thoughts like seeds.',
    'You are allowed to begin again, as many times as you need.',
    'Progress hums quietly long before it ever shouts.',
    'The day has not asked anything of you yet. Breathe first.',
    'A single spark, tended well, can outlast a whole storm.',
    'You are not behind. You are exactly where today needed you.',
    'Momentum is just rest that finally stood up.',
    'Kindness to yourself this morning pays interest all day long.',
    'The horizon moves only for those who keep walking toward it.',
    'Today is unwritten — hold the pen loosely and begin.',
    'Even the quietest charge still lights the whole room.',
    'You have survived every morning so far. This one, too.',
    'Let your first thought be steady, not sharp.',
    'A slow start is still a start heading the right way.',
    'The storm remembers every bolt it ever let loose.',
    'Wake gently — the world can wait one more breath.',
    'What feels ordinary today is tomorrow\'s quiet foundation.',
    'You carry yesterday\'s lessons, not yesterday\'s weight.',
    'Every charge starts from stillness, never from noise.',
    'Trust the pace that lets you actually arrive.',
    'The sky was dark, and then it simply wasn\'t. So will this.',
    'Today only needs the next honest step, nothing more.',
    'You are the current running through your own good day.',
  ];

  static String wordOfDay(DateTime date) => words[_indexFor(date, words.length)];

  static String quoteOfDay(DateTime date) => quotes[_indexFor(date, quotes.length)];

  static int _indexFor(DateTime date, int length) =>
      stableHash(dayKeyFor(date)) % length;
}
