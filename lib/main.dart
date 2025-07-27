import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/validator_service.dart';
import 'widgets/connection_dialog.dart';
import 'widgets/validator_controls.dart';
import 'widgets/communication_log.dart';

void main() {
  runApp(const ESSPValidatorApp());
}

class ESSPValidatorApp extends StatelessWidget {
  const ESSPValidatorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ValidatorService(),
      child: MaterialApp(
        title: 'eSSP Validator Flutter Example',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const ValidatorHomePage(),
      ),
    );
  }
}

class ValidatorHomePage extends StatefulWidget {
  const ValidatorHomePage({Key? key}) : super(key: key);

  @override
  State<ValidatorHomePage> createState() => _ValidatorHomePageState();
}

class _ValidatorHomePageState extends State<ValidatorHomePage> {
  bool _showConnectionDialog = true;
  bool _showCommLog = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showCommLog = prefs.getBool('show_comm_log') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eSSP Validator Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _showConnectionDialog
          ? ConnectionDialog(
              onConnected: () {
                setState(() {
                  _showConnectionDialog = false;
                });
              },
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ValidatorControls(
                    onShowCommLog: () {
                      setState(() {
                        _showCommLog = !_showCommLog;
                      });
                    },
                    showCommLog: _showCommLog,
                  ),
                ),
                if (_showCommLog)
                  Expanded(flex: 1, child: const EnhancedCommunicationLog()),
              ],
            ),
    );
  }
}
