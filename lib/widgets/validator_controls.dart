import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/validator_service.dart';

class ValidatorControls extends StatelessWidget {
  final VoidCallback onShowCommLog;
  final bool showCommLog;

  const ValidatorControls({
    Key? key,
    required this.onShowCommLog,
    required this.showCommLog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ValidatorService>(
      builder: (context, validatorService, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Validator Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _StatusRow('Connected:', validatorService.isConnected ? 'Yes' : 'No'),
                      _StatusRow('Polling:', validatorService.isPolling ? 'Active' : 'Stopped'),
                      _StatusRow('Port:', validatorService.currentPort.isEmpty ? 'None' : validatorService.currentPort),
                      if (validatorService.isConnected) ...[
                        _StatusRow('Unit Type:', validatorService.unitType),
                        _StatusRow('Firmware:', validatorService.firmwareVersion),
                        _StatusRow('Serial:', validatorService.serialNumber),
                        _StatusRow('Protocol:', validatorService.protocolVersion.toString()),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Control Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: validatorService.isConnected && !validatorService.isPolling
                          ? validatorService.startPolling
                          : null,
                      child: const Text('Run'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: validatorService.isPolling
                          ? validatorService.stopPolling
                          : null,
                      child: const Text('Halt'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              ElevatedButton(
                onPressed: validatorService.isConnected
                    ? validatorService.resetValidator
                    : null,
                child: const Text('Reset Validator'),
              ),

              const SizedBox(height: 16),

              // Notes Counter
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Notes Accepted',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        validatorService.notesAccepted.toString(),
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: validatorService.clearNoteCount,
                        child: const Text('Clear Count'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Escrow Controls
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Escrow Control',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Hold in Escrow'),
                        value: validatorService.holdInEscrow,
                        onChanged: (value ) => validatorService.setHoldInEscrow,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: validatorService.noteHeld
                            ? validatorService.returnNote
                            : null,
                        child: const Text('Return Note'),
                      ),
                      if (validatorService.noteHeld)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Note is held in escrow',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Channel Information
              if (validatorService.channels.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supported Denominations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...validatorService.channels.map((channel) =>
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(channel.toString()),
                            ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Communication Log Toggle
              CheckboxListTile(
                title: const Text('Show Communication Log'),
                value: showCommLog,
                onChanged: (_) => onShowCommLog(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}