// SPIKE (branch spike/saf, never merged): a one-screen app that tests whether a file or
// folder picked once in Google Drive or OneDrive can be written again later, after a
// restart, with no INTERNET permission. See MainActivity.kt.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SpikeScreen()));

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  static const _saf = MethodChannel('spike/saf');
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    _run('status');
  }

  Future<void> _run(String method) async {
    final now = DateTime.now();
    final stamp = '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
    String out;
    try {
      out = '${await _saf.invokeMethod<String>(method, 'Kukira SAF test, written $stamp')}';
    } on PlatformException catch (e) {
      out = 'ERROR ${e.code}: ${e.message}';
    }
    if (mounted) setState(() => _log.insert(0, '$stamp  $method\n$out'));
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    Widget button(String label, String method) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FilledButton(onPressed: () => _run(method), child: Text(label)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Kukira SAF test')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('1. Pilih fail dalam Google Drive atau OneDrive.\n'
              '2. Tulis sekarang, kemudian semak masa dalam fail itu di Drive.\n'
              '3. Mulakan semula telefon, buka app ini, Tulis sekarang lagi.\n'
              'Ulang dengan Pilih folder (dua fail A dan B bergilir).'),
          const SizedBox(height: 12),
          button('Pilih fail', 'pickFile'),
          button('Tulis sekarang (fail)', 'writeFile'),
          button('Pilih folder', 'pickFolder'),
          button('Tulis sekarang (folder A/B)', 'writeFolder'),
          OutlinedButton(onPressed: () => _run('status'), child: const Text('Status')),
          const SizedBox(height: 12),
          for (final l in _log) Padding(padding: const EdgeInsets.only(bottom: 10), child: SelectableText(l, style: const TextStyle(fontSize: 12))),
        ]),
      ),
    );
  }
}
