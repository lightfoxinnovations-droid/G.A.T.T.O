import 'package:flutter_test/flutter_test.dart';

import 'package:gatto_app/main.dart';

void main() {
  testWidgets('avvio mostra la ricerca del robot', (WidgetTester tester) async {
    await tester.pumpWidget(const GattoApp());
    expect(find.text('Cerco G.A.T.T.O.'), findsOneWidget);
  });
}
