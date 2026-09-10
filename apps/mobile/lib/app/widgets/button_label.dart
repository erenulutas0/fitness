import 'package:flutter/widgets.dart';

/// A button label that stays on one line.
///
/// Two buttons share a 360 dp row on the HUD and the rest timer. A label that
/// does not fit shrinks a little instead of breaking in two: "End / session"
/// over two lines reads like two buttons' worth of text in one.
class ButtonLabel extends StatelessWidget {
  /// A one-line label for [text].
  const ButtonLabel(this.text, {super.key});

  /// The label, already localised.
  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}
