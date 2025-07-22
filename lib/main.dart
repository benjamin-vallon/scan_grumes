import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  print("👉 DÉBUT DE main()");
  WidgetsFlutterBinding.ensureInitialized();
  print("✅ WidgetsFlutterBinding.ensureInitialized()");
  runApp(const ScanApp());
  print("✅ runApp terminé");
}


class ScanApp extends StatelessWidget {
  const ScanApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scan_Grumes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.green[300],
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.light().textTheme,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFE0F2F1),
          border: OutlineInputBorder(),
          floatingLabelAlignment: FloatingLabelAlignment.center,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            elevation: 4,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({Key? key}) : super(key: key);

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  String? _transporteurMemoire;
  final _nomCtrl = TextEditingController();
  final _numChantier = TextEditingController();
  final _piedsCtrl = TextEditingController();
  final _steresCtrl = TextEditingController();

  List<String> _scannedCodes = [];
  String? _essence;
  String? _volumeCamion;
  bool _modeSteres = false;

  @override
  void initState() {
    super.initState();
    print("🔄 initState() de ScannerPage lancé");
    _loadTransporteur();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadTransporteur() async {
    print("📦 Chargement SharedPreferences...");
    final prefs = await SharedPreferences.getInstance();
    print("✅ SharedPreferences récupéré");
    setState(() {
      _transporteurMemoire = prefs.getString('transporteur') ?? '';
      print("📌 Transporteur mémorisé : $_transporteurMemoire");
    });
  }

  Future<String> _createCsvFile() async {
    final dateEnvoi = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final numCh = _numChantier.text;
    final annee = numCh.substring(0, 2);                    // ex : 26
    final nCoupe = numCh.substring(numCh.length - 3);      // ex : 001
    final chantier = _nomCtrl.text.toUpperCase();
    final essence = _essence ?? '';
    final volume = _volumeCamion ?? '';
    final pieds = _piedsCtrl.text;
    final steres = _modeSteres ? _steresCtrl.text : '';
    final transporteur = _transporteurMemoire ?? '';

    final codes = List<String>.from(_scannedCodes);
    codes.sort();

    final buffer = StringBuffer();
    buffer.writeln('N° DE CHANTIER;${numCh.substring(0, 2)} ${numCh.substring(2)};;;;;');
    buffer.writeln('CHANTIER;$chantier;;;;;');
    buffer.writeln('ESSENCE;$essence;;;;;');
    buffer.writeln('VOLUME;$volume;;;;;');
    buffer.writeln('NOMBRE DE PIEDS;${codes.length};;;;;');
    if (_modeSteres) {
      buffer.writeln('STÉRAGE;${_steresCtrl.text}');
    }
    buffer.writeln('DATE;$dateEnvoi;;;;;');
    buffer.writeln(';;;;;');
    buffer.writeln('DATE;ANNÉE;N° DE COUPE;TRANSPORTEUR;N° DE PLAQUETTE');

    for (final code in codes) {
      buffer.writeln('$dateEnvoi;$annee;$nCoupe;$transporteur;$code');
    }

    final fileName = 'bl_${dateEnvoi}_$numCh.csv';
    final dir = await getApplicationDocumentsDirectory();
    print("📂 Dossier documents récupéré : ${dir.path}");
    final path = '${dir.path}/$fileName';
    await File(path).writeAsString('\ufeff${buffer.toString()}', encoding: utf8);
    return path;
  }

  Future<void> _afficherHistoriqueEnvois() async {
    final dir = await getApplicationDocumentsDirectory();
    final fichiers = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv'))
        .toList();

    if (fichiers.length > 150) {
      fichiers.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      final fichiersASupprimer = fichiers.take(fichiers.length - 150);
      for (final fichier in fichiersASupprimer) {
        await fichier.delete();
      }
    }

    fichiers.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    List<File> fichiersFiltres = List.from(fichiers);
    TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.brown.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HISTORIQUE DES ENVOIS', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un fichier...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (query) {
                      setState(() {
                        fichiersFiltres = fichiers.where((f) => f.path.toLowerCase().contains(query.toLowerCase())).toList();
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: fichiersFiltres.length,
                  itemBuilder: (context, index) {
                    final file = fichiersFiltres[index];
                    final fileName = file.path.split('/').last;
                    final parts = fileName.replaceAll('.csv', '').split('_');
                    final date = parts.length >= 2 ? parts[1] : '??';
                    final numChantier = parts.length >= 3 ? parts[2] : '??';

                    return ListTile(
                      tileColor: index % 2 == 0 ? Colors.brown.shade100 : Colors.brown.shade200,
                      title: Text('Chantier $numChantier – $date', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(fileName),
                      trailing: IconButton(
                        icon: Icon(Icons.cloud_upload, color: Colors.green),
                        onPressed: () async {
                          try {
                            final nomFichier = file.path.split('/').last;
                            final dirExterne = Directory('/storage/emulated/0/Documents/Scan_Grumes');

                            if (!await dirExterne.exists()) {
                              await dirExterne.create(recursive: true);
                            }

                            final nouveauFichier = File('${dirExterne.path}/$nomFichier');
                            await file.copy(nouveauFichier.path);

                            final confirmer = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Confirmation'),
                                content: Text('Souhaitez-vous vraiment renvoyer le fichier "$nomFichier" à SDC ?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NON')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OUI')),
                                ],
                              ),
                            );

                            if (confirmer == true) {
                              // 🔍 Extraction du numéro et nom du chantier depuis le nom du fichier
                              final parts = nomFichier.replaceAll('.csv', '').split('_');
                              final date = parts.length >= 2 ? parts[1] : '??';
                              final numChantier = parts.length >= 3 ? parts[2] : '??';
                              final nomChantier = parts.length >= 4 ? parts.sublist(3).join('_') : '';

                              await Share.shareXFiles(
                                [XFile(file.path)],
                                subject: 'ATTENTION ENVOI EN DOUBLE',
                                text: 'Merci d’envoyer ce fichier à l’adresse suivante :\n\n📧 grumier@scierie-sdc.fr',
                              );

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'FICHIER ENVOYÉ AVEC SUCCÈS !',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Erreur'),
                                content: Text('Impossible de copier ou envoyer le fichier : $e'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('FERMER', style: TextStyle(color: Colors.brown.shade700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _validateAndExport() async {
    try {
      // Test rapide de DNS pour vérifier la connexion
      final result = await InternetAddress.lookup('8.8.8.8');
      if (result.isEmpty) throw const SocketException('No network');
    } on SocketException {
      // Pas de réseau : on alerte et on quitte
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erreur réseau'),
          content: const Text('Pas de connexion réseau. Impossible d’envoyer à SDC.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    final missing = <String>[];
    if (_nomCtrl.text.isEmpty) missing.add('Nom du chantier');
    if (_numChantier.text.isEmpty && !_modeSteres) missing.add('Numéro de chantier');
    if (_numChantier.text.length != 5 && !_modeSteres) {
      missing.add('Numéro de chantier (5 chiffres)');
    }
    if ((_transporteurMemoire ?? '').isEmpty) missing.add('Transporteur');
    if (_essence == null) missing.add('Essence');
    if (_volumeCamion == null) missing.add('Volume camion');
    if (!_modeSteres && _piedsCtrl.text.isEmpty) {
      missing.add('Pieds sans plaquette');
    }
    if (_scannedCodes.isEmpty && !_modeSteres) missing.add('Au moins un code');

    if (missing.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Champs manquants'),
          content: Text('Veuillez remplir :\n' + missing.join('\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Center(
            child: Text(
              'ENVOI À SDC',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CHANTIER ${_nomCtrl.text}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                'CHANTIER N° ${_numChantier.text}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Transporteur :', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(_transporteurMemoire ?? ''),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Essence :', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(_essence ?? ''),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Volume camion :', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(_volumeCamion ?? ''),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('Nb codes :', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('${_scannedCodes.length}'),
                ],
              ),
              if (_modeSteres)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const Text('Stérage :', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('${_steresCtrl.text} stères'),
                    ],
                  ),
                ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ANNULER'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context); // Ferme le popup
                final cheminFichierCsv = await _exportCsv();
                if (cheminFichierCsv != null) {
                  await Share.shareXFiles(
                    [XFile(cheminFichierCsv)],
                    subject: '$_numChantier.text - $_nomCtrl.text',
                    text: 'Merci d’envoyer ce fichier à l’adresse suivante :\n\n📧 grumier@scierie-sdc.fr',
                  );
                  setState(() {
                    _scannedCodes.clear();
                    _nomCtrl.clear();
                    _numChantier.clear();
                    _piedsCtrl.clear();
                    _steresCtrl.clear();
                    _essence = null;
                    _volumeCamion = null;
                    _modeSteres = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ENVOYER AVEC SUCCÈS !!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // ✅ dans Text()
                      ),
                      duration: Duration(seconds: 3),
                      backgroundColor: Colors.green,
                    ),
                  );

                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erreur : aucun fichier CSV trouvé.')),
                  );
                }
              },
              child: const Text('ENVOYER'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        _exportCsv();
      }
    }
  }

  Future<String?> _exportCsv() async {
    try {
      // Test rapide de DNS pour vérifier la connexion
      final result = await InternetAddress.lookup('8.8.8.8');
      if (result.isEmpty) throw const SocketException('No network');
    } on SocketException {
      // Pas de réseau : on alerte et on quitte
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erreur réseau'),
          content: const Text('Pas de connexion réseau. Impossible d’envoyer à SDC.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return null;
    }

    // Si on a du réseau, on poursuit…
    final path = await _createCsvFile();
    return path;
  }

  void _startRafaleScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ManualScanPage(onNewCode: _addCode)),
    );
  }

  void _addCode(String code) {
    if (!_scannedCodes.contains(code)) {
      setState(() => _scannedCodes.add(code));
    } else {
      _showDuplicate(code);
    }
  }

  void _showDuplicate(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Doublon détecté'),
        content: Text('Le code-barres "$code" a déjà été scanné.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _scannedCodes.clear();
      _nomCtrl.clear();
      _numChantier.clear();
      _piedsCtrl.clear();
      _steresCtrl.clear();
      _essence = null;
      _volumeCamion = null;
      _modeSteres = false;
    });
  }

  Future<void> _onTransporteur() async {
    final controller = TextEditingController(text: _transporteurMemoire);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Numéro du transporteur'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Entrez le numéro'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('VALIDER')),
        ],
      ),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('transporteur', result);
      setState(() => _transporteurMemoire = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan_Grumes'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.local_shipping), onPressed: _onTransporteur)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Image.asset('assets/images/logo.png', height: 120),
            const SizedBox(height: 24),

            // Nom du chantier
            TextField(
              controller: _nomCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                label: const Center(child: Text('NOM DU CHANTIER')),
                floatingLabelAlignment: FloatingLabelAlignment.center,
                filled: true,
                fillColor: const Color(0xFFE0F2F1),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Numéro de chantier
            TextField(
              controller: _numChantier,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // que des chiffres
                LengthLimitingTextInputFormatter(5),   // max 5 caractères
              ],
              decoration: InputDecoration(
                counterText: '', // masque le compteur
                label: const Center(child: Text('NUMÉRO DE CHANTIER')),
                floatingLabelAlignment: FloatingLabelAlignment.center,
                filled: true,
                fillColor: const Color(0xFFE0F2F1),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Essence
            DropdownButtonFormField<String>(
              value: _essence,
              decoration: InputDecoration(
                label: const Center(child: Text('ESSENCE')),
                filled: true,
                fillColor: const Color(0xFFE0F2F1),
                floatingLabelAlignment: FloatingLabelAlignment.center,
                border: const OutlineInputBorder(),
              ),
              items: ['SAPINS', 'DOUGLAS']
                  .map((e) => DropdownMenuItem(value: e, child: Center(child: Text(e))))
                  .toList(),
              onChanged: (v) => setState(() => _essence = v),
            ),
            const SizedBox(height: 12),

            // Volume camion
            DropdownButtonFormField<String>(
              value: _volumeCamion,
              decoration: InputDecoration(
                label: const Center(child: Text('VOLUME CAMION')),
                filled: true,
                fillColor: const Color(0xFFE0F2F1),
                floatingLabelAlignment: FloatingLabelAlignment.center,
                border: const OutlineInputBorder(),
              ),
              items: ['1V', '1/2V', '3/4V', '1/4V']
                  .map((v) => DropdownMenuItem(value: v, child: Center(child: Text(v))))
                  .toList(),
              onChanged: (v) => setState(() => _volumeCamion = v),
            ),
            const SizedBox(height: 12),

            // Pieds sans plaquette
            TextField(
              controller: _piedsCtrl,
              enabled: !_modeSteres,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                label: Center(child: Text('PIEDS SANS PLAQUETTE')),
                floatingLabelAlignment: FloatingLabelAlignment.center,
                filled: true,
                fillColor: Color(0xFFE0F2F1),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Mode stère
            SwitchListTile(
              title: const Text('Mode STÈRE'),
              value: _modeSteres,
              onChanged: (v) => setState(() => _modeSteres = v),
            ),

            if (_modeSteres) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _steresCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'VOLUME EN STÈRE'),
              ),
            ],

            const SizedBox(height: 12),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('SCANNER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                    ),
                    onPressed: _modeSteres ? null : _startRafaleScan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('ENVOYER SDC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                    ),
                    onPressed: _validateAndExport,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('TOUT EFFACER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: _clearAll,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                icon: Icon(Icons.history, size: 20),
                label: Text('HISTORIQUE', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown.shade300,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: _afficherHistoriqueEnvois,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              _modeSteres
                  ? 'Mode STÈRE activé'
                  : 'Nombre de codes scannés : ${_scannedCodes.length}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Liste des codes scannés
            // Partie « Liste des codes scannés »
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.all(12),
                height: 200,
                child: _scannedCodes.isEmpty
                    ? const Center(
                  child: Text(
                    'Aucun code scanné',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                )
                    : ListView.builder(
                  itemCount: _scannedCodes.length,
                  itemBuilder: (context, i) {
                    final code = _scannedCodes[i];
                    final bgColor = i.isEven ? Colors.white : Colors.grey.shade100;
                    return Container(
                      color: bgColor,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          Text(
                            '${i + 1}.',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              code,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                            onPressed: () async {
                              final del = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Confirmation'),
                                  content: Text('Supprimer le code "$code" ?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NON')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OUI')),
                                  ],
                                ),
                              );
                              if (del == true) setState(() => _scannedCodes.removeAt(i));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManualScanPage extends StatefulWidget {
  final void Function(String code) onNewCode;
  const ManualScanPage({Key? key, required this.onNewCode}) : super(key: key);

  @override
  State<ManualScanPage> createState() => _ManualScanPageState();
}

class _ManualScanPageState extends State<ManualScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrController;
  String? _lastDetected;
  String? _lastValidated;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _qrController?.dispose();
    super.dispose();
  }

  void _validateAndContinue() {
    HapticFeedback.vibrate();
    if (_lastDetected != null) {
      widget.onNewCode(_lastDetected!);
      _lastValidated = _lastDetected;
      setState(() => _lastDetected = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode Rafale'),
        leading: IconButton(icon: const Icon(Icons.checklist_rtl), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: (controller) {
              _qrController = controller;
              controller.scannedDataStream.listen((scanData) {
                final code = scanData.code;
                if (code != null && code != _lastValidated) {
                  setState(() => _lastDetected = code);
                  _resetTimer?.cancel();
                  _resetTimer = Timer(const Duration(seconds: 1), () {
                    setState(() => _lastDetected = null);
                  });
                }
              });
            },
            overlay: QrScannerOverlayShape(
              borderColor: Colors.white,
              borderRadius: 8,
              borderLength: 30,
              borderWidth: 5,
              cutOutSize: 250,
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Valider le code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _lastDetected != null ? Colors.green : Colors.grey,
              ),
              onPressed: _lastDetected != null ? _validateAndContinue : null,
            ),
          ),
        ],
      ),
    );
  }
}
