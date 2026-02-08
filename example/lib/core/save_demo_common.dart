import 'package:flutter/material.dart';

enum DemoInputSource { network, bytes, file }

class InputSourceSelector extends StatelessWidget {
  const InputSourceSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final DemoInputSource value;
  final ValueChanged<DemoInputSource> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DemoInputSource>(
      segments: const [
        ButtonSegment<DemoInputSource>(
          value: DemoInputSource.network,
          icon: Icon(Icons.link),
          label: Text('Network'),
        ),
        ButtonSegment<DemoInputSource>(
          value: DemoInputSource.bytes,
          icon: Icon(Icons.memory),
          label: Text('Bytes'),
        ),
        ButtonSegment<DemoInputSource>(
          value: DemoInputSource.file,
          icon: Icon(Icons.insert_drive_file),
          label: Text('File'),
        ),
      ],
      selected: {value},
      onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
      showSelectedIcon: false,
    );
  }
}

String fileNameWithoutExt(String name) {
  final idx = name.lastIndexOf('.');
  if (idx <= 0) return name;
  return name.substring(0, idx);
}

