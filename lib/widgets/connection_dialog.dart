import 'package:flutter/material.dart';
import 'package:it_bill_acceptor/widgets/communication_log.dart';
import 'package:provider/provider.dart';

import '../services/serial_service.dart';
import '../services/validator_service.dart';

class ConnectionDialog extends StatefulWidget {
  final VoidCallback onConnected;

  const ConnectionDialog({Key? key, required this.onConnected})
    : super(key: key);

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

// In connection_dialog.dart
class _ConnectionDialogState extends State<ConnectionDialog> {
  String? _selectedPort;
  final TextEditingController _addressController = TextEditingController(
    text: '0',
  );
  List<PortInfo> _availablePorts = [];
  bool _isConnecting = false;
  bool _showAllPorts = false;

  @override
  void initState() {
    super.initState();
    _scanForPorts();
  }

  void _scanForPorts() {
    setState(() {
      final allPorts = SerialService.getAvailablePortsWithInfo();
      _availablePorts = _showAllPorts
          ? allPorts
          : allPorts.where((port) => port.isAvailable).toList();

      if (_availablePorts.isNotEmpty) {
        _selectedPort = _availablePorts.first.name;
      }
    });
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

              // Show all ports checkbox
              CheckboxListTile(
                title: const Text('Show all ports'),
                subtitle: const Text('Include unavailable ports'),
                value: _showAllPorts,
                onChanged: (value) {
                  setState(() {
                    _showAllPorts = value ?? false;
                    _scanForPorts();
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              // COM Port Selection
              DropdownButtonFormField<String>(
                value: _selectedPort,
                decoration: const InputDecoration(
                  labelText: 'COM Port',
                  border: OutlineInputBorder(),
                ),
                items: _availablePorts.map((portInfo) {
                  return DropdownMenuItem(
                    value: portInfo.name,
                    child: Row(
                      children: [
                        Text(portInfo.name),
                        const SizedBox(width: 8),
                        Icon(
                          portInfo.isAvailable
                              ? Icons.check_circle
                              : Icons.error,
                          color: portInfo.isAvailable
                              ? Colors.green
                              : Colors.red,
                          size: 16,
                        ),
                        if (portInfo.friendlyName != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              portInfo.friendlyName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _isConnecting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedPort = value;
                        });
                      },
              ),

              const SizedBox(height: 8),

              // Refresh button
              TextButton.icon(
                onPressed: _scanForPorts,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Ports'),
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

              Expanded(child: EnhancedCommunicationLog()),
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
