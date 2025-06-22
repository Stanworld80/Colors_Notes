// lib/widgets/notes_display_widget.dart
import 'package:colors_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';
import '../models/note.dart';
import '../models/journal.dart';
import '../models/color_data.dart';
import '../providers/active_journal_provider.dart';

/// Logger instance for this widget.
final _loggerDisplayWidget = Logger(printer: PrettyPrinter(methodCount: 0, printTime: false));

/// A reusable widget to display a list of notes in either a grid or list format.
///
/// This widget handles fetching, sorting, and displaying notes based on
/// configurable options. It does NOT handle deletion or complex filtering logic,
/// which should be managed by its parent widget if needed.
class NotesDisplayWidget extends StatefulWidget {
  /// The ID of the journal whose notes are to be displayed.
  final String journalId;
  /// The ID of the current authenticated user. This is crucial for Firestore queries
  /// to ensure proper data access based on security rules.
  final String userId;
  /// The [Journal] object containing the palette, used to resolve [ColorData] for notes.
  /// This should typically be the active journal if displaying notes for it.
  final Journal? journalForPalette;
  /// If `true`, sort controls (e.g., date, direction) will be displayed.
  /// Defaults to `true`.
  final bool showSortingControls;
  /// If `true`, a toggle button for switching between list and grid view will be displayed.
  /// Defaults to `true`.
  final bool showViewToggle;
  /// If `true`, individual note items will be tappable, and [onNoteTap] will be invoked.
  /// Defaults to `true`.
  final bool enableNoteTaps;
  /// Callback function invoked when a note item is tapped (only if [enableNoteTaps] is true).
  /// The [Note] object that was tapped is passed as an argument.
  final Function(Note note)? onNoteTap;
  /// If `true`, individual delete buttons will be shown on each note item.
  /// This is separate from "delete all notes" functionality, which should be in the parent.
  /// Defaults to `false` for this shared component (NoteListPage will override).
  final bool showDeleteButtons;
  /// Callback function invoked when the delete button on a note item is tapped (only if [showDeleteButtons] is true).
  /// The [Note] object to be deleted is passed as an argument.
  final Function(Note note)? onNoteDelete;


  /// External control for the view mode (grid/list).
  /// This is used when `showViewToggle` is `false`, meaning the parent manages the toggle.
  final bool? externalIsGridView;
  /// External control for the sort field.
  /// This is used when `showSortingControls` is `false`.
  final String? externalSortBy;
  /// External control for the sort direction.
  /// This is used when `showSortingControls` is `false`.
  final bool? externalSortDescending;
  /// Optional: if provided, filters notes to only show those with this paletteElementId.
  final String? filterByPaletteElementId;


  /// Creates a [NotesDisplayWidget].
  const NotesDisplayWidget({
    super.key,
    required this.journalId,
    required this.userId,
    this.journalForPalette,
    this.showSortingControls = true,
    this.showViewToggle = true,
    this.enableNoteTaps = true,
    this.onNoteTap,
    this.showDeleteButtons = false,
    this.onNoteDelete, // New parameter
    this.externalIsGridView,
    this.externalSortBy,
    this.externalSortDescending,
    this.filterByPaletteElementId,
  });

  @override
  _NotesDisplayWidgetState createState() => _NotesDisplayWidgetState();
}

class _NotesDisplayWidgetState extends State<NotesDisplayWidget> {
  // Internal state for sorting and view mode.
  // These will be overridden by external properties if `showViewToggle` or `showSortingControls` are false.
  late String _sortBy;
  late bool _sortDescending;
  late bool _isGridView;

  @override
  void initState() {
    super.initState();
    _initializeStateFromProps();
  }

  @override
  void didUpdateWidget(covariant NotesDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize state if external properties change and controls are not shown.
    if (!widget.showViewToggle && widget.externalIsGridView != oldWidget.externalIsGridView) {
      _isGridView = widget.externalIsGridView ?? false;
    }
    if (!widget.showSortingControls && (widget.externalSortBy != oldWidget.externalSortBy || widget.externalSortDescending != oldWidget.externalSortDescending)) {
      _sortBy = widget.externalSortBy ?? 'eventTimestamp';
      _sortDescending = widget.externalSortDescending ?? true;
    }
    // No need to re-initialize if filterByPaletteElementId changes, as StreamBuilder handles it directly.
  }

  void _initializeStateFromProps() {
    _isGridView = widget.showViewToggle ? false : (widget.externalIsGridView ?? false);
    _sortBy = widget.showSortingControls ? 'eventTimestamp' : (widget.externalSortBy ?? 'eventTimestamp');
    _sortDescending = widget.showSortingControls ? true : (widget.externalSortDescending ?? true);
  }

  /// Retrieves [ColorData] for a given [paletteElementId] from the provided [journal]'s palette.
  ///
  /// Returns the [ColorData] if found, otherwise `null`.
  /// Logs a warning if the color is not found.
  ColorData? _getColorDataById(Journal? journal, String paletteElementId) {
    if (journal == null) return null;
    try {
      return journal.palette.colors.firstWhere((c) => c.paletteElementId == paletteElementId);
    } catch (e) {
      _loggerDisplayWidget.w("ColorData non trouvé pour paletteElementId: $paletteElementId dans le journal ${journal.name}");
      return null;
    }
  }

  /// Builds a sort button widget for the control row.
  ///
  /// [sortType] The field name to sort by (e.g., 'eventTimestamp').
  /// [mainIcon] The icon to display on the button.
  /// [tooltip] The tooltip text for the button.
  Widget _buildSortButton(BuildContext context, String sortType, IconData mainIcon, String tooltip) {
    final l10n = AppLocalizations.of(context)!;
    bool isActive = _sortBy == sortType;
    const double directionIconSize = 16.0;
    String currentSortDirectionTooltip = isActive
        ? (_sortDescending ? l10n.sortDirectionDescending : l10n.sortDirectionAscending)
        : "";

    return IconButton(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mainIcon),
          if (isActive)
            Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Icon(_sortDescending ? Icons.arrow_drop_down : Icons.arrow_drop_up, size: directionIconSize)
            ),
        ],
      ),
      tooltip: tooltip + currentSortDirectionTooltip,
      color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color,
      onPressed: () {
        if (mounted) {
          setState(() {
            if (isActive) {
              _sortDescending = !_sortDescending;
            } else {
              _sortBy = sortType;
              // Default sort direction for new sort type (descending for time, ascending for text)
              _sortDescending = (sortType == 'eventTimestamp' || sortType == 'createdAt');
            }
          });
        }
      },
    );
  }

  /// Builds a single grid item widget for displaying a note.
  ///
  /// [note] The [Note] object to display.
  /// [colorData] The [ColorData] associated with the note.
  Widget _buildNoteGridItem(BuildContext context, Note note, ColorData? colorData) {
    final l10n = AppLocalizations.of(context)!;
    final DateFormat dateFormat = DateFormat('dd/MM/yy HH:mm', l10n.localeName);
    final Color cardColor = colorData?.color ?? Colors.grey.shade100;
    final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final Color subtleTextColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;

    // Responsive font sizes for grid items.
    double titleFontSize = 10.0;
    double contentFontSize = 11.0;
    double dateFontSize = 9.0;
    int maxLinesForContent = 2;

    final screenWidth = MediaQuery.of(context).size.width;
    // Adjust font sizes for denser grids.
    if (screenWidth / 9 < 80) {
      titleFontSize = 8.0;
      contentFontSize = 9.0;
      dateFontSize = 7.0;
      maxLinesForContent = 1;
    }

    return Card(
      elevation: 2.0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        onTap: widget.enableNoteTaps && widget.onNoteTap != null
            ? () => widget.onNoteTap!(note)
            : null,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      colorData?.title ?? l10n.defaultColorTitle,
                      style: TextStyle(fontSize: titleFontSize, color: subtleTextColor, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.showDeleteButtons) // Conditionally show delete button
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: textColor.withOpacity(0.7), size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      tooltip: l10n.deleteNoteTooltipGrid,
                      onPressed: widget.onNoteDelete != null ? () => widget.onNoteDelete!(note) : null,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  note.content,
                  style: TextStyle(fontWeight: FontWeight.normal, fontSize: contentFontSize, color: textColor),
                  maxLines: maxLinesForContent,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(dateFormat.format(note.eventTimestamp.toDate().toLocal()), style: TextStyle(fontSize: dateFontSize, color: subtleTextColor)),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single list item widget for displaying a note.
  ///
  /// [note] The [Note] object to display.
  /// [colorData] The [ColorData] associated with the note.
  Widget _buildNoteListItem(BuildContext context, Note note, ColorData? colorData) {
    final l10n = AppLocalizations.of(context)!;
    final DateFormat dateFormat = DateFormat('EEEE d MMMM y HH:mm', l10n.localeName);

    final Color cardColor = colorData?.color ?? Theme.of(context).cardColor;
    final Color textColor = cardColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final Color subtleTextColor = cardColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70;

    return Card(
      elevation: 2.0,
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        leading: colorData != null
            ? const CircleAvatar(backgroundColor: Colors.transparent)
            : const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.help_outline, color: Colors.white)),
        title: Text(
            note.content,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: textColor),
            maxLines: 3,
            overflow: TextOverflow.ellipsis
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (colorData != null)
                Text(
                    colorData.title,
                    style: TextStyle(fontSize: 12, color: subtleTextColor, fontWeight: FontWeight.bold)
                ),
              Text(
                  l10n.noteDateLabel(dateFormat.format(note.eventTimestamp.toDate().toLocal())),
                  style: TextStyle(fontSize: 12, color: subtleTextColor)
              ),
              Text(
                l10n.noteCreatedOnLabel(DateFormat('dd/MM/yy HH:mm', l10n.localeName).format(note.createdAt.toDate().toLocal())),
                style: TextStyle(fontSize: 10, color: subtleTextColor.withOpacity(0.8)),
              ),
            ],
          ),
        ),
        trailing: widget.showDeleteButtons
            ? IconButton(
          icon: Icon(Icons.delete_forever_outlined, color: textColor.withOpacity(0.7)),
          tooltip: l10n.deleteThisNoteTooltipList,
          onPressed: widget.onNoteDelete != null ? () => widget.onNoteDelete!(note) : null,
        )
            : null,
        onTap: widget.enableNoteTaps && widget.onNoteTap != null
            ? () => widget.onNoteTap!(note)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    // Determine Firestore query parameters based on current sort state.
    // We only expose timestamp-based sorting directly to Firestore for now.
    String firestoreSortField = _sortBy;
    bool firestoreSortDescending = _sortDescending;

    // Determine grid column count based on screen width for responsiveness.
    final screenWidth = MediaQuery.of(context).size.width;
    int gridCrossAxisCount;
    if (screenWidth < 400) {
      gridCrossAxisCount = 3;
    } else if (screenWidth < 600) {
      gridCrossAxisCount = 4;
    } else if (screenWidth < 800) {
      gridCrossAxisCount = 5;
    } else if (screenWidth < 1000) {
      gridCrossAxisCount = 6;
    } else if (screenWidth < 1200) {
      gridCrossAxisCount = 7;
    } else if (screenWidth < 1400) {
      gridCrossAxisCount = 8;
    } else {
      gridCrossAxisCount = 9;
    }

    return Column(
      children: [
        // Control row for sorting and view toggle.
        if (widget.showSortingControls || widget.showViewToggle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.showViewToggle)
                  IconButton(
                    icon: Icon(_isGridView ? Icons.view_list_outlined : Icons.grid_view_outlined),
                    tooltip: _isGridView ? l10n.viewAsListTooltip : l10n.viewAsGridTooltip,
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      }
                    },
                  ),
                if (widget.showSortingControls)
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        // Only Event Date and Creation Date are exposed as sort options from this widget.
                        _buildSortButton(context, 'eventTimestamp', Icons.event_note_outlined, l10n.sortByEventDateTooltip),
                        _buildSortButton(context, 'createdAt', Icons.add_circle_outline, l10n.sortByCreationDateTooltip),
                        // Add other sort options here if this widget needs to handle them directly
                        // (e.g., if you decide to implement client-side sorting for 'content' or 'paletteOrder' within this widget).
                      ],
                    ),
                  ),
              ],
            ),
          ),
        // StreamBuilder to fetch notes from Firestore.
        StreamBuilder<List<Note>>(
          // Pass the filterByPaletteElementId to the Firestore service stream
          stream: firestoreService.getJournalNotesStream(
            widget.journalId,
            sortBy: firestoreSortField,
            descending: firestoreSortDescending,
            filterByPaletteElementId: widget.filterByPaletteElementId, // Pass the filter
          ),
          builder: (context, snapshot) {
            // Show loading indicator if active journal is loading (for palette info)
            // or if notes stream is waiting for initial data.
            final activeJournalNotifier = Provider.of<ActiveJournalNotifier>(context);
            if (activeJournalNotifier.isLoading && widget.journalForPalette == null && activeJournalNotifier.activeJournalId == widget.journalId) {
              return const Expanded(child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Expanded(child: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              _loggerDisplayWidget.e("Error loading notes: ${snapshot.error}");
              return Expanded(child: Center(child: Text(l10n.errorLoadingNotes(snapshot.error.toString()))));
            }

            List<Note> notes = snapshot.data ?? [];

            if (notes.isEmpty) {
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notes_outlined, size: 50, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                        const SizedBox(height: 10),
                        Text(l10n.noNotesInJournalMessage, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Client-side sorting for complex criteria not directly supported by Firestore.
            // If _sortBy is 'paletteOrder' or 'content', fetch from Firestore by a default field
            // and then apply these sorts client-side.
            if (_sortBy == 'paletteOrder' && widget.journalForPalette != null) {
              final paletteOrderMap = {
                for (var i = 0; i < widget.journalForPalette!.palette.colors.length; i++)
                  widget.journalForPalette!.palette.colors[i].paletteElementId: i
              };
              notes.sort((a, b) {
                final indexA = paletteOrderMap[a.paletteElementId] ?? double.maxFinite.toInt(); // Unmapped colors last
                final indexB = paletteOrderMap[b.paletteElementId] ?? double.maxFinite.toInt();
                int comparison = indexA.compareTo(indexB);
                return _sortDescending ? -comparison : comparison; // Apply sort direction
              });
            } else if (_sortBy == 'content') {
              notes.sort((a, b) {
                int comparison = a.content.toLowerCase().compareTo(b.content.toLowerCase());
                return _sortDescending ? -comparison : comparison; // Apply sort direction
              });
            }

            // Determine which view to use based on the internal _isGridView state.
            bool currentIsGridView = _isGridView; // Use internal state if controls are shown within this widget
            if (!widget.showViewToggle) { // If parent controls view, use external property
              currentIsGridView = widget.externalIsGridView ?? false;
            }

            return Expanded(
              child: currentIsGridView
                  ? GridView.builder(
                padding: const EdgeInsets.all(8.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCrossAxisCount,
                    crossAxisSpacing: 4.0,
                    mainAxisSpacing: 4.0,
                    childAspectRatio: 1.1 // Adjust for desired item shape
                ),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final colorData = _getColorDataById(widget.journalForPalette, note.paletteElementId);
                  return _buildNoteGridItem(context, note, colorData);
                },
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final colorData = _getColorDataById(widget.journalForPalette, note.paletteElementId);
                  return _buildNoteListItem(context, note, colorData);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

