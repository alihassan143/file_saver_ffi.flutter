import 'package:flutter/material.dart';

import 'utils.dart';

/// Info card displaying title, description and URL
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.description,
    required this.url,
    this.urlLabel = 'URL',
  });

  final String description;
  final String url;
  final String urlLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 8),
            Text(
              '$urlLabel: $url',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Download button with loading state
class DownloadButton extends StatelessWidget {
  const DownloadButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.label,
    this.loadingLabel = 'Downloading...',
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download),
      label: Text(isLoading ? loadingLabel : label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

/// Progress indicator section
class ProgressSection extends StatelessWidget {
  const ProgressSection({
    super.key,
    required this.progress,
    this.label = 'Saving',
  });

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        LinearProgressIndicator(value: progress / 100),
        const SizedBox(height: 8),
        Text(
          '$label: ${progress.toStringAsFixed(1)}%',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Card showing file/media size info
class FileSizeCard extends StatelessWidget {
  const FileSizeCard({super.key, required this.sizeInBytes, this.label});

  final int sizeInBytes;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              '${label ?? 'Size'}: ${formatBytes(sizeInBytes)}',
              style: TextStyle(color: Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card showing successful save path
class SuccessCard extends StatelessWidget {
  const SuccessCard({super.key, required this.savedPath});

  final String savedPath;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Saved: $savedPath',
                style: TextStyle(color: Colors.green.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented button for selecting media/file type
class MediaCategorySelector extends StatelessWidget {
  const MediaCategorySelector({
    super.key,
    required this.selected,
    required this.categories,
    required this.onChanged,
    this.enabled = true,
  });

  final dynamic selected;
  final List<({dynamic value, String label, IconData icon})> categories;
  final ValueChanged<dynamic> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: SegmentedButton<dynamic>(
        segments: categories
            .map(
              (c) => ButtonSegment<dynamic>(
                value: c.value,
                icon: Icon(c.icon),
                tooltip: c.label,
              ),
            )
            .toList(),
        selected: {selected},
        onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: Theme.of(
            context,
          ).colorScheme.primaryContainer,
        ),
      ),
    );
  }
}

/// Toggle between Async and Stream API modes
class ApiModeSelector extends StatelessWidget {
  const ApiModeSelector({
    super.key,
    required this.useStreamApi,
    required this.onChanged,
    this.enabled = true,
  });

  final bool useStreamApi;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('API Mode:', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text('Async'),
          selected: !useStreamApi,
          onSelected: enabled ? (_) => onChanged(false) : null,
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Stream'),
          selected: useStreamApi,
          onSelected: enabled ? (_) => onChanged(true) : null,
        ),
      ],
    );
  }
}

/// Cancel button for stream operations
class CancelButton extends StatelessWidget {
  const CancelButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.cancel),
      label: const Text('Cancel'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
    );
  }
}

/// Generic info card without URL (for file picker screens)
class SimpleInfoCard extends StatelessWidget {
  const SimpleInfoCard({
    super.key,
    required this.title,
    required this.description,
    this.subtitle,
  });

  final String title;
  final String description;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
