import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Lecture d'un code QR ou d'un code barres.
///
/// Retourne le contenu lu via Navigator.pop, ou null si l'utilisateur
/// abandonne. Aucune logique metier ici : l'appelant decide quoi faire
/// du texte obtenu (ouvrir une adresse, remplir un champ du site...).
class EcranScannerQr extends StatefulWidget {
  const EcranScannerQr({super.key, required this.couleurAccent});

  final Color couleurAccent;

  @override
  State<EcranScannerQr> createState() => _EtatEcranScannerQr();
}

class _EtatEcranScannerQr extends State<EcranScannerQr> {
  final MobileScannerController _controleur = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _dejaRenvoye = false;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _traiterDetection(BarcodeCapture capture) {
    if (_dejaRenvoye || capture.barcodes.isEmpty) {
      return;
    }
    final String? valeur = capture.barcodes.first.rawValue;
    if (valeur == null || valeur.isEmpty) {
      return;
    }
    _dejaRenvoye = true;
    Navigator.of(context).pop(valeur);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanner un code'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Lampe',
            onPressed: () => _controleur.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _controleur,
            onDetect: _traiterDetection,
          ),
          Center(child: _cadreVisee()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 44,
            child: Text(
              'Placez le code dans le cadre',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(215),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cadreVisee() {
    return Container(
      width: 232,
      height: 232,
      decoration: BoxDecoration(
        border: Border.all(color: widget.couleurAccent, width: 3),
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}
