import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:songhut/models/loop_section.dart';
import 'package:songhut/services/prefs_service.dart';

String _fmt(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Bottom sheet listing a song's saved practice sections ("Chorus", "Drop", …).
/// Tapping one applies it to the loop; the current range can be saved under a
/// new name. Sections persist per song.
void showLoopSectionsSheet(
  BuildContext context, {
  required int songId,
  required int currentStartSec,
  required int currentEndSec,
  required void Function(LoopSection) onApply,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final scheme = Theme.of(ctx).colorScheme;
        final sections = PrefsService.instance.getLoopSections(songId);

        Future<void> saveCurrent() async {
          final controller =
              TextEditingController(text: 'Section ${sections.length + 1}');
          final name = await showDialog<String>(
            context: ctx,
            builder: (dctx) => AlertDialog(
              title: const Text('Save section'),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Chorus, Drop, Verse 2…',
                  helperText:
                      '${_fmt(currentStartSec)} – ${_fmt(currentEndSec)}',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onSubmitted: (v) => Navigator.pop(dctx, v),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dctx),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dctx, controller.text),
                    child: const Text('Save')),
              ],
            ),
          );
          if (name == null || name.trim().isEmpty) return;
          final updated = [
            ...sections,
            LoopSection(
                name: name.trim(),
                startSec: currentStartSec,
                endSec: currentEndSec),
          ];
          await PrefsService.instance.setLoopSections(songId, updated);
          setSheet(() {});
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Practice sections',
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Save parts of this song and jump back to them.',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 10),
                if (sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text('No sections saved for this song yet.',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13)),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sections.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: scheme.outlineVariant
                              .withValues(alpha: 0.4)),
                      itemBuilder: (_, i) {
                        final s = sections[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(Icons.repeat_rounded,
                                size: 18, color: scheme.onPrimaryContainer),
                          ),
                          title: Text(s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle:
                              Text('${_fmt(s.startSec)} – ${_fmt(s.endSec)}'),
                          trailing: IconButton(
                            tooltip: 'Delete section',
                            icon: Icon(Icons.delete_outline_rounded,
                                color: scheme.onSurfaceVariant, size: 20),
                            onPressed: () async {
                              final updated = [...sections]..removeAt(i);
                              await PrefsService.instance
                                  .setLoopSections(songId, updated);
                              setSheet(() {});
                            },
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(ctx);
                            onApply(s);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: saveCurrent,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                    label: Text(
                        'Save current range (${_fmt(currentStartSec)} – ${_fmt(currentEndSec)})'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
