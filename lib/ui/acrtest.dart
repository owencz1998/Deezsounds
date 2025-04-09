import 'package:alchemy/utils/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Nécessaire pour MethodChannel

// Widget pour tester la configuration ACRCloud
class AcrConfigureWidget extends StatefulWidget {
  const AcrConfigureWidget({super.key});

  @override
  State<AcrConfigureWidget> createState() => _AcrConfigureWidgetState();
}

class _AcrConfigureWidgetState extends State<AcrConfigureWidget> {
  // Définit le nom du canal exactement comme dans MainActivity.java
  static const platform = MethodChannel('definitely.not.deezer/native');

  String _status = 'Prêt à configurer ACRCloud';
  bool _isConfiguring = false; // Pour désactiver le bouton pendant l'appel

  // Fonction pour appeler la méthode native 'acrConfigure'
  Future<void> _configureAcrCloud() async {
    if (_isConfiguring) return; // Empêche les appels multiples

    setState(() {
      _status = 'Configuration en cours...';
      _isConfiguring = true;
    });

    // Remplacez par vos vraies clés ACRCloud
    String acrHost = Env.acrcloudHost; // Ex: identify-eu-west-1.acrcloud.com
    String acrAccessKey = Env.acrcloudSongApiKey;
    String acrAccessSecret = Env.acrcloudSongApiSecret;

    try {
      // Appelle la méthode native 'acrConfigure' avec les arguments
      final bool? result = await platform.invokeMethod<bool>('acrConfigure', {
        'host': acrHost,
        'accessKey': acrAccessKey,
        'accessSecret': acrAccessSecret,
      });

      // Met à jour le statut en fonction du résultat
      if (result == true) {
        _status =
            'Commande de configuration envoyée.\nÉcoutez les événements pour l\'état réel.';
        debugPrint('ACRCloud configure command sent successfully.');
      } else {
        _status = 'Échec de l\'envoi de la commande (service non lié ?).';
        debugPrint(
            'Failed to send ACRCloud configure command (service not bound?).');
      }
    } on PlatformException catch (e) {
      // Gère les erreurs potentielles de la plateforme
      _status = 'Erreur plateforme: ${e.message}';
      debugPrint('PlatformException configuring ACRCloud: ${e.message}');
    } catch (e) {
      // Gère toute autre erreur inattendue
      _status = 'Erreur inattendue: $e';
      debugPrint('Unexpected error configuring ACRCloud: $e');
    } finally {
      // Réactive le bouton et met à jour l'état final
      if (mounted) {
        // Vérifie si le widget est toujours monté avant d'appeler setState
        setState(() {
          _isConfiguring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retourne une simple colonne avec le statut et le bouton
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement
        crossAxisAlignment: CrossAxisAlignment.center, // Centre horizontalement
        children: <Widget>[
          Text(
            _status, // Affiche le statut actuel
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            // Désactive le bouton pendant la configuration
            onPressed: _isConfiguring ? null : _configureAcrCloud,
            child: _isConfiguring
                ? const SizedBox(
                    // Affiche un indicateur de chargement
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Configurer ACRCloud'),
          ),
        ],
      ),
    );
  }
}

// Exemple d'utilisation dans une page simple (si vous voulez le tester seul)
/*
void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test Widget ACR')),
        body: const Center(
          child: AcrConfigureWidget(), // Intègre le widget ici
        ),
      ),
    );
  }
}
*/
