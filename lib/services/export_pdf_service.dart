import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/serializers/api_serializers.dart';
import '../models/models.dart';

class ExportPdfService {
  static final _dateFormat = DateFormat('dd.MM.yyyy');
  static final _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) {
      return _theme!;
    }

    final regularData =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    _regularFont = pw.Font.ttf(regularData);
    _boldFont = pw.Font.ttf(boldData);
    _theme = pw.ThemeData.withFont(
      base: _regularFont!,
      bold: _boldFont!,
    );
    return _theme!;
  }

  static pw.TextStyle _textStyle({
    double fontSize = 12,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.TextStyle(
      font: bold ? _boldFont : _regularFont,
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
  }

  static Future<Uint8List> buildPdf(Map<String, dynamic> downloadResponse) async {
    final theme = await _loadTheme();
    final payload = Map<String, dynamic>.from(
      downloadResponse['payload'] as Map? ?? const {},
    );
    final type = payload['type'] as String? ?? 'messages';
    final items = (payload['items'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final workspace = payload['workspace'] as Map<String, dynamic>?;
    final workspaceName =
        workspace?['name'] as String? ?? 'Rodzina Coparentes';

    final fromDate = _parseDate(payload['fromDate']);
    final toDate = _parseDate(payload['toDate']);
    final generatedAt = _parseDate(payload['generatedAt']) ?? DateTime.now();

    final pdf = pw.Document(
      title: 'Coparentes – ${_typeLabel(type)}',
      author: 'Coparentes',
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Coparentes',
                style: _textStyle(
                  fontSize: 22,
                  bold: true,
                  color: PdfColors.blue800,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _typeLabel(type),
              style: _textStyle(fontSize: 16, bold: true),
            ),
            pw.SizedBox(height: 12),
            _infoRow('Rodzina', workspaceName),
            _infoRow(
              'Okres',
              '${_formatDate(fromDate)} – ${_formatDate(toDate)}',
            ),
            _infoRow('Wygenerowano', _formatDateTime(generatedAt)),
            _infoRow('Liczba rekordów', '${items.length}'),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 12),
            ..._buildItems(type, items),
          ];
        },
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Strona ${context.pageNumber} / ${context.pagesCount}',
              style: _textStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static String fileNameForJob(ExportJob job) {
    final stamp = DateFormat('yyyy-MM-dd').format(job.createdAt);
    return 'coparentes_${exportTypeToApi(job.type)}_$stamp.pdf';
  }

  static Map<String, dynamic> demoDownloadPayload(ExportJob job) {
    final now = DateTime.now();
    return {
      'payload': {
        'type': exportTypeToApi(job.type),
        'fromDate': job.fromDate.toIso8601String(),
        'toDate': job.toDate.toIso8601String(),
        'generatedAt': now.toIso8601String(),
        'workspace': {'name': 'Rodzina Kowalska (demo)'},
        'items': _demoItems(job.type, job.fromDate, job.toDate),
      },
    };
  }

  static List<Map<String, dynamic>> _demoItems(
    ExportType type,
    DateTime from,
    DateTime to,
  ) {
    switch (type) {
      case ExportType.messages:
        return [
          {
            'recordType': 'messageThread',
            'subject': 'Szkoła',
            'category': 'school',
            'messages': [
              {
                'senderName': 'Anna Kowalska',
                'content': 'Przypomnienie o zebraniu w piątek o 18:00.',
                'sentAt': to.toIso8601String(),
              },
              {
                'senderName': 'Marek Kowalski',
                'content': 'Potwierdzam, będę.',
                'sentAt': to.toIso8601String(),
              },
            ],
          },
        ];
      case ExportType.calendar:
        return [
          {
            'recordType': 'calendarEvent',
            'title': 'Zebranie w szkole',
            'startDate': to.toIso8601String(),
            'location': 'Szkoła Podstawowa nr 12',
          },
          {
            'recordType': 'custodySlot',
            'date': from.toIso8601String(),
            'custodian': 'parentA',
            'handoverTime': '17:00',
          },
        ];
      case ExportType.finances:
        return [
          {
            'recordType': 'expense',
            'title': 'Książki szkolne',
            'amount': 128.50,
            'currency': 'PLN',
            'category': 'education',
            'date': to.toIso8601String(),
            'status': 'approved',
          },
        ];
      case ExportType.fullPack:
        return [
          ..._demoItems(ExportType.messages, from, to),
          ..._demoItems(ExportType.calendar, from, to),
          ..._demoItems(ExportType.finances, from, to),
        ];
    }
  }

  static List<pw.Widget> _buildItems(String type, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return [
        pw.Text(
          'Brak danych w wybranym okresie.',
          style: _textStyle(color: PdfColors.grey700),
        ),
      ];
    }

    if (type == 'messages') {
      return _buildMessageSections(items);
    }
    if (type == 'calendar') {
      return _buildCalendarSections(items);
    }
    if (type == 'finances') {
      return _buildFinanceSections(items);
    }
    if (type == 'fullPack') {
      final messages = items
          .where((item) => item['recordType'] == 'messageThread' || item.containsKey('messages'))
          .toList();
      final calendar = items.where((item) {
        final recordType = item['recordType'] as String?;
        return recordType == 'custodySlot' ||
            recordType == 'calendarEvent' ||
            recordType == 'swapRequest';
      }).toList();
      final finances = items
          .where((item) => item['recordType'] == 'expense' || item.containsKey('amount'))
          .toList();

      return [
        pw.Text(
          'Wiadomości',
          style: _textStyle(fontSize: 14, bold: true),
        ),
        pw.SizedBox(height: 8),
        ..._buildMessageSections(messages.isEmpty ? items : messages),
        pw.SizedBox(height: 16),
        pw.Text(
          'Kalendarz',
          style: _textStyle(fontSize: 14, bold: true),
        ),
        pw.SizedBox(height: 8),
        ..._buildCalendarSections(calendar),
        pw.SizedBox(height: 16),
        pw.Text(
          'Finanse',
          style: _textStyle(fontSize: 14, bold: true),
        ),
        pw.SizedBox(height: 8),
        ..._buildFinanceSections(finances),
      ];
    }

    return items.map(_genericItem).toList();
  }

  static List<pw.Widget> _buildMessageSections(List<Map<String, dynamic>> items) {
    final widgets = <pw.Widget>[];

    for (final item in items) {
      if (item.containsKey('messages')) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item['subject'] as String? ?? 'Wątek',
                  style: _textStyle(bold: true),
                ),
                if (item['category'] != null)
                  pw.Text(
                    'Kategoria: ${item['category']}',
                    style: _textStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                pw.SizedBox(height: 8),
                ...((item['messages'] as List<dynamic>? ?? const [])
                    .map((message) => _messageLine(message as Map))
                    .toList()),
              ],
            ),
          ),
        );
      } else {
        widgets.add(_genericItem(item));
      }
    }

    return widgets;
  }

  static pw.Widget _messageLine(Map message) {
    final sentAt = _parseDate(message['sentAt']);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${message['senderName'] ?? 'Nadawca'} • ${_formatDateTime(sentAt)}',
            style: _textStyle(
              fontSize: 10,
              bold: true,
              color: PdfColors.blue800,
            ),
          ),
          pw.Text(
            message['content'] as String? ?? '',
            style: _textStyle(fontSize: 10),
          ),
          if ((message['attachments'] as List<dynamic>? ?? const []).isNotEmpty)
            pw.Text(
              'Załączniki: ${(message['attachments'] as List).length}',
              style: _textStyle(fontSize: 9, color: PdfColors.grey700),
            ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildCalendarSections(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return [
        pw.Text(
          'Brak wpisów kalendarza.',
          style: _textStyle(color: PdfColors.grey700),
        ),
      ];
    }

    return items.map((item) {
      final recordType = item['recordType'] as String? ?? 'calendarEvent';
      switch (recordType) {
        case 'custodySlot':
          return _boxedItem(
            title: 'Opieka – ${_formatDate(_parseDate(item['date']))}',
            lines: [
              'Opiekun: ${_custodianLabel(item['custodian'] as String?)}',
              if (item['handoverTime'] != null)
                'Przekazanie: ${item['handoverTime']}',
              if (item['handoverLocation'] != null)
                'Miejsce: ${item['handoverLocation']}',
            ],
          );
        case 'swapRequest':
          return _boxedItem(
            title: 'Prośba o zamianę terminu',
            lines: [
              'Od: ${item['requesterName'] ?? 'Rodzic'}',
              'Data oryginalna: ${_formatDate(_parseDate(item['originalDate']))}',
              'Data proponowana: ${_formatDate(_parseDate(item['proposedDate']))}',
              'Status: ${_statusLabel(item['status'] as String?)}',
              if (item['reason'] != null) 'Powód: ${item['reason']}',
            ],
          );
        default:
          return _boxedItem(
            title: item['title'] as String? ?? 'Wydarzenie',
            lines: [
              'Początek: ${_formatDateTime(_parseDate(item['startDate']))}',
              if (item['endDate'] != null)
                'Koniec: ${_formatDateTime(_parseDate(item['endDate']))}',
              if (item['location'] != null) 'Miejsce: ${item['location']}',
              if (item['description'] != null) 'Opis: ${item['description']}',
            ],
          );
      }
    }).toList();
  }

  static List<pw.Widget> _buildFinanceSections(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return [
        pw.Text(
          'Brak wydatków.',
          style: _textStyle(color: PdfColors.grey700),
        ),
      ];
    }

    return [
      pw.TableHelper.fromTextArray(
        headers: ['Data', 'Tytuł', 'Kwota', 'Kategoria', 'Status'],
        headerStyle: _textStyle(bold: true, fontSize: 10),
        cellStyle: _textStyle(fontSize: 10),
        data: items.map((item) {
          final amount = item['amount'];
          final currency = item['currency'] as String? ?? 'PLN';
          return [
            _formatDate(_parseDate(item['date'])),
            item['title'] as String? ?? '—',
            amount == null ? '—' : '${amount.toString()} $currency',
            item['category'] as String? ?? '—',
            _statusLabel(item['status'] as String?),
          ];
        }).toList(),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      ),
    ];
  }

  static pw.Widget _boxedItem({
    required String title,
    required List<String> lines,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: _textStyle(bold: true)),
          ...lines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(line, style: _textStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _genericItem(Map<String, dynamic> item) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(item.toString(), style: _textStyle(fontSize: 10)),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: _textStyle(bold: true),
            ),
            pw.TextSpan(text: value, style: _textStyle()),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'messages':
        return 'Eksport wiadomości';
      case 'calendar':
        return 'Eksport kalendarza';
      case 'finances':
        return 'Eksport finansów';
      case 'fullPack':
        return 'Pełny pakiet';
      default:
        return 'Eksport';
    }
  }

  static String _custodianLabel(String? value) {
    switch (value) {
      case 'parentA':
        return 'Rodzic A';
      case 'parentB':
        return 'Rodzic B';
      default:
        return value ?? '—';
    }
  }

  static String _statusLabel(String? value) {
    switch (value) {
      case 'approved':
        return 'Zatwierdzony';
      case 'pending':
        return 'Oczekujący';
      case 'rejected':
        return 'Odrzucony';
      case 'completed':
        return 'Gotowy';
      default:
        return value ?? '—';
    }
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return _dateFormat.format(value.toLocal());
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return _dateTimeFormat.format(value.toLocal());
  }
}
