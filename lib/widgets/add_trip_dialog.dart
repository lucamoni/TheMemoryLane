import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';

class AddTripDialog extends StatefulWidget {
  final Function(Trip) onTripAdded;

  const AddTripDialog({required this.onTripAdded, super.key});

  @override
  State<AddTripDialog> createState() => _AddTripDialogState();
}

class _AddTripDialogState extends State<AddTripDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  TripType _selectedTripType = TripType.dayTrip;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuovo Viaggio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titolo del Viaggio',
              hintText: 'Es. Weekend a Roma',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descrizione (opzionale)',
              hintText: 'Es. Un bellissimo weekend con gli amici',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<TripType>(
            value: _selectedTripType,
            decoration: const InputDecoration(
              labelText: 'Tipo di Viaggio',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: TripType.localTrip,
                child: Row(
                  children: [
                    Icon(Icons.directions_walk, size: 20),
                    SizedBox(width: 8),
                    Text('Local Trip - Passeggiata'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: TripType.dayTrip,
                child: Row(
                  children: [
                    Icon(Icons.wb_sunny, size: 20),
                    SizedBox(width: 8),
                    Text('Day Trip - Gita di un giorno'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: TripType.multiDayTrip,
                child: Row(
                  children: [
                    Icon(Icons.luggage, size: 20),
                    SizedBox(width: 8),
                    Text('Multi-Day Trip - Vacanza'),
                  ],
                ),
              ),
            ],
            onChanged: (TripType? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedTripType = newValue;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              final trip = Trip(
                id: const Uuid().v4(),
                title: _titleController.text,
                description: _descriptionController.text.isEmpty
                    ? null
                    : _descriptionController.text,
                startDate: DateTime.now(),
                tripType: _selectedTripType,
              );
              widget.onTripAdded(trip);
              Navigator.pop(context);
            }
          },
          child: const Text('Crea'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

