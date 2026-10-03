import 'dart:typed_data';

Never _soNoPainelWeb() => throw UnsupportedError('Disponível só no painel web');

void baixarArquivo(String nome, String tipo, Uint8List bytes) => _soNoPainelWeb();

void abrirEmNovaAba(String tipo, Uint8List bytes) => _soNoPainelWeb();

Future<List<(String, Uint8List)>> escolherArquivos(String aceitar) async => _soNoPainelWeb();
