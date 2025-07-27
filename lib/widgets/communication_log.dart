import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/validator_service.dart';
import '../utils/helpers.dart';
import '../utils/commands.dart';

class EnhancedCommunicationLog extends StatefulWidget {
  const EnhancedCommunicationLog({Key? key}) : super(key: key);

  @override
  State<EnhancedCommunicationLog> createState() => _EnhancedCommunicationLogState();
}

class _EnhancedCommunicationLogState extends State<EnhancedCommunicationLog> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _showEncryptedPackets = false;
  bool _showPacketDetails = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ValidatorService>(
      builder: (context, validatorService, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Card(
          margin: const EdgeInsets.all(8),
          child: Column(
            children: [
              _buildHeader(context, validatorService),
              Expanded(
                child: _buildLogContent(context, validatorService),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ValidatorService validatorService) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Communication Log',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: validatorService.clearLog,
                tooltip: 'Clear Log',
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () => _saveLog(validatorService),
                tooltip: 'Save Log',
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: _autoScroll,
                onChanged: (value) {
                  setState(() {
                    _autoScroll = value ?? true;
                  });
                },
              ),
              const Text('Auto-scroll'),
              const SizedBox(width: 16),
              Checkbox(
                value: _showPacketDetails,
                onChanged: (value) {
                  setState(() {
                    _showPacketDetails = value ?? true;
                  });
                },
              ),
              const Text('Packet Details'),
              const SizedBox(width: 16),
              Checkbox(
                value: _showEncryptedPackets,
                onChanged: (value) {
                  setState(() {
                    _showEncryptedPackets = value ?? false;
                  });
                },
              ),
              const Text('Show Encrypted'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogContent(BuildContext context, ValidatorService validatorService) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: validatorService.logMessages.isEmpty && validatorService.commandHistory.isEmpty
          ? const Center(
        child: Text(
          'No communication data yet...',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      )
          : ListView.builder(
        controller: _scrollController,
        itemCount: _showPacketDetails
            ? validatorService.commandHistory.length + validatorService.logMessages.length
            : validatorService.logMessages.length,
        itemBuilder: (context, index) {
          if (_showPacketDetails) {
            // Interleave packet details and log messages
            if (index < validatorService.commandHistory.length * 2) {
              if (index % 2 == 0) {
                return _buildPacketWidget(validatorService.commandHistory[index ~/ 2]);
              } else {
                final logIndex = (index ~/ 2);
                if (logIndex < validatorService.logMessages.length) {
                  return _buildLogMessage(validatorService.logMessages[logIndex]);
                }
              }
            } else {
              final logIndex = index - validatorService.commandHistory.length;
              if (logIndex < validatorService.logMessages.length) {
                return _buildLogMessage(validatorService.logMessages[logIndex]);
              }
            }
            return const SizedBox.shrink();
          } else {
            return _buildLogMessage(validatorService.logMessages[index]);
          }
        },
      ),
    );
  }

  Widget _buildLogMessage(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SelectableText(
        message,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPacketWidget(dynamic commandInfo) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: Colors.blue.shade50,
      child: ExpansionTile(
        title: Text(
          'Packet #${commandInfo.hashCode % 10000} - ${Helpers.formatDateTime(commandInfo.timestamp)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transmitted Data
                if (commandInfo.transmittedLength > 0) ...[
                  const Text(
                    'Transmitted:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Length: ${commandInfo.transmittedLength}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  SelectableText(
                    'Data: ${Helpers.bytesToHex(commandInfo.transmittedData, length: commandInfo.transmittedLength)}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                ],

                // Received Data
                if (commandInfo.receivedLength > 0) ...[
                  const Text(
                    'Received:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Length: ${commandInfo.receivedLength}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  SelectableText(
                    'Data: ${Helpers.bytesToHex(commandInfo.receivedData, length: commandInfo.receivedLength)}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLog(ValidatorService validatorService) async {
    // In a real implementation, you would use file_picker or path_provider
    // to save the log to a file. For now, we'll just show a dialog.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Log'),
        content: const Text('Log saving functionality would be implemented here using file_picker or path_provider packages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}