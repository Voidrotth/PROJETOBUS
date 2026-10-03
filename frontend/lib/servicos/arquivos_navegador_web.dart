import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

String _urlDe(String tipo, Uint8List bytes) =>
    web.URL.createObjectURL(web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: tipo)));

void baixarArquivo(String nome, String tipo, Uint8List bytes) {
  final url = _urlDe(tipo, bytes);
  web.HTMLAnchorElement()
    ..href = url
    ..download = nome
    ..click();
  web.URL.revokeObjectURL(url);
}

/// Abre o conteúdo em outra aba (o relatório de quilometragem, pronto para imprimir)
void abrirEmNovaAba(String tipo, Uint8List bytes) {
  web.window.open(_urlDe(tipo, bytes), '_blank');
}

/// Abre a janela de escolha de arquivos; devolve (nome, conteúdo) de cada um.
/// [aceitar] segue o atributo accept do HTML, ex.: ".html,.htm,.csv"
Future<List<(String, Uint8List)>> escolherArquivos(String aceitar) {
  final resultado = Completer<List<(String, Uint8List)>>();
  final entrada = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..accept = aceitar;

  Future<void> ler() async {
    final arquivos = <(String, Uint8List)>[];
    final escolhidos = entrada.files;
    for (var i = 0; escolhidos != null && i < escolhidos.length; i++) {
      final arquivo = escolhidos.item(i)!;
      arquivos.add((arquivo.name, (await arquivo.arrayBuffer().toDart).toDart.asUint8List()));
    }
    resultado.complete(arquivos);
  }

  entrada.addEventListener('change', ((web.Event _) {
        ler();
      }).toJS);
  entrada.addEventListener('cancel', ((web.Event _) {
        resultado.complete([]);
      }).toJS);
  entrada.click();
  return resultado.future;
}
