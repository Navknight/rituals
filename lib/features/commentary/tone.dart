/// How blunt the app is allowed to be.
enum CommentaryTone {
  /// No commentary at all.
  off('Off', 'Just the numbers.'),

  /// Warm and plain.
  kind('Kind', 'Encouraging, never sarcastic.'),

  /// Understated, a little amused.
  dry('Dry', 'Deadpan. Mild sarcasm.'),

  /// Openly mocking, but still on your side.
  brutal('Brutal', 'Dark humour. Insults you, not your worth.');

  const CommentaryTone(this.label, this.description);

  final String label;
  final String description;
}
