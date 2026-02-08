import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';

/// Dialog per la creazione di un nuovo viaggio.
/// Permette di inserire il titolo e selezionare la tipologia di esperienza (Passeggiata, Gita, Vacanza).
class AddTripDialog extends StatefulWidget {
  final Function(Trip) onTripAdded;
  const AddTripDialog({required this.onTripAdded, super.key});

  @override
  State<AddTripDialog> createState() => _AddTripDialogState();
}

class _AddTripDialogState extends State<AddTripDialog> {
  final TextEditingController _titleController = TextEditingController();
  TripType _selectedTripType = TripType.dayTrip;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nuova Avventura',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  hintText: 'Dove stai andando?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tipo di Esperienza',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              _buildTypeSelector(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Inizia Esplorazione',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Annulla',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Costruisce il selettore orizzontale delle tipologie di viaggio.
  Widget _buildTypeSelector() {
    return Row(
      children: [
        _buildTypeOption(
          TripType.localTrip,
          Icons.directions_walk_rounded,
          'Passeggiata',
        ),
        const SizedBox(width: 8),
        _buildTypeOption(TripType.dayTrip, Icons.explore_rounded, 'Gita'),
        const SizedBox(width: 8),
        _buildTypeOption(
          TripType.multiDayTrip,
          Icons.flight_takeoff_rounded,
          'Vacanza',
        ),
      ],
    );
  }

  /// Opzione singola del selettore tipologia viaggio.
  Widget _buildTypeOption(TripType type, IconData icon, String label) {
    final isSelected = _selectedTripType == type;
    final color = isSelected ? Theme.of(context).primaryColor : Colors.white;
    final contentColor = isSelected ? Colors.white : Colors.grey.shade700;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTripType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade200,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: contentColor, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: contentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Valida e invia i dati del nuovo viaggio.
  void _submit() {
    if (_titleController.text.isNotEmpty) {
      final trip = Trip(
        id: const Uuid().v4(),
        title: _titleController.text,
        startDate: DateTime.now(),
        tripType: _selectedTripType,
        isActive: true, // Tutti i nuovi viaggi iniziano in stato attivo
      );
      widget.onTripAdded(trip);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}
