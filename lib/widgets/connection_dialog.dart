import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/validator_service.dart';
import '../services/serial_service.dart';

class ConnectionDialog extends StatefulWidget {
  final VoidCallback onConnected;

  const ConnectionDialog({Key? key, required this.onConnected}) : super(key: key);

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  String? _selectedPort;
  final TextEditingController _addressController = TextEditingController(text: '0');
  final List<String> _availablePorts = SerialService.getAvailablePorts();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    if (_availablePorts.isNotEmpty) {
      _selectedPort = _availablePorts.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Connect to Validator',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // COM Port Selection
              DropdownButtonFormField<String>(
                value: _selectedPort,
                decoration: const InputDecoration(
                  labelText: 'COM Port',
                  border: OutlineInputBorder(),
                ),
                items: _availablePorts.map((port) {
                  return DropdownMenuItem(
                    value: port,
                    child: Text(port),
                  );
                }).toList(),
                onChanged: _isConnecting ? null : (value) {
                  setState(() {
                    _selectedPort = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // SSP Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'SSP Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !_isConnecting,
              ),

              const SizedBox(height: 24),

              // Connect Button
              ElevatedButton(
                onPressed: _isConnecting || _selectedPort == null
                    ? null
                    : _connect,
                child: _isConnecting
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Connecting...'),
                  ],
                )
                    : const Text('Connect'),
              ),

              if (_availablePorts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'No COM ports found. Please check your connections.',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    if (_selectedPort == null) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      final address = int.parse(_addressController.text);
      final validatorService = context.read<ValidatorService>();

      final success = await validatorService.connect(_selectedPort!, address);

      if (success) {
        widget.onConnected();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to validator'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
}