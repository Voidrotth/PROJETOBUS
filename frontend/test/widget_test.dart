import 'package:flutter_test/flutter_test.dart';

import 'package:projetobus_frontend/main.dart';

void main() {
  testWidgets('Sem sessão o app abre na tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const AplicativoProjetoBus());

    expect(find.text('PROJETOBUS'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
