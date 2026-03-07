import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import '../../utils/custom_toast.dart';
import '../admin/daily_headcount_screen.dart';

class ExportService {
  static Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      return true;
    }
    return true;
  }

  static Future<String> _getDirectoryPath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/Entrixo');
    } else {
      directory = await getApplicationDocumentsDirectory();
      directory = Directory('${directory.path}/Entrixo');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static pw.Widget _buildCell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.center,
    bool isBold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      alignment: align,
      child: pw.Text(
        text,
        softWrap: false,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 9.5,
          fontWeight: (isHeader || isBold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static Future<void> generatePdf(
    BuildContext context,
    DateTime date,
    List<BatchHeadcountModel> batches,
    int grandTotal,
    int grandPre,
    int grandPost,
  ) async {
    if (!await _requestPermission()) return;

    final pdf = pw.Document();
    double prePercent = grandTotal == 0 ? 0 : (grandPre / grandTotal) * 100;
    double postPercent = grandTotal == 0 ? 0 : (grandPost / grandTotal) * 100;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                "SHOBHIT UNIVERSITY, GANGOH",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                "SCHOOL OF ENGINEERING & TECHNOLOGY",
                style: pw.TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(height: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "DAILY ATTENDANCE HEADCOUNT",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd-MMM-yyyy (EEEE)').format(date),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(25),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FixedColumnWidth(55),
                  5: const pw.FixedColumnWidth(35),
                  6: const pw.FixedColumnWidth(55),
                  7: const pw.FixedColumnWidth(35),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue900,
                    ),
                    children: [
                      _buildCell("S.No", isHeader: true),
                      _buildCell("Program", isHeader: true),
                      _buildCell("Semester", isHeader: true),
                      _buildCell("Total", isHeader: true),
                      _buildCell("Pre-Lunch", isHeader: true),
                      _buildCell("%", isHeader: true),
                      _buildCell("Post-Lunch", isHeader: true),
                      _buildCell("%", isHeader: true),
                    ],
                  ),
                  ...List.generate(batches.length, (index) {
                    final b = batches[index];
                    double p1 = b.totalStudents == 0
                        ? 0
                        : (b.preLunch / b.totalStudents) * 100;
                    double p2 = b.totalStudents == 0
                        ? 0
                        : (b.postLunch / b.totalStudents) * 100;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 != 0
                            ? PdfColors.grey50
                            : PdfColors.white,
                      ),
                      children: [
                        _buildCell("${index + 1}"),
                        _buildCell(
                          b.courseName,
                          align: pw.Alignment.centerLeft,
                        ),
                        _buildCell(b.semester),
                        _buildCell("${b.totalStudents}"),
                        _buildCell("${b.preLunch}"),
                        _buildCell("${p1.toStringAsFixed(0)}%"),
                        _buildCell("${b.postLunch}"),
                        _buildCell("${p2.toStringAsFixed(0)}%"),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildCell(""),
                      _buildCell(
                        "GRAND TOTAL",
                        align: pw.Alignment.centerLeft,
                        isBold: true,
                      ),
                      _buildCell(""),
                      _buildCell("$grandTotal", isBold: true),
                      _buildCell("$grandPre", isBold: true),
                      _buildCell(
                        "${prePercent.toStringAsFixed(0)}%",
                        isBold: true,
                      ),
                      _buildCell("$grandPost", isBold: true),
                      _buildCell(
                        "${postPercent.toStringAsFixed(0)}%",
                        isBold: true,
                      ),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Report ID: ENT-${date.millisecondsSinceEpoch.toString().substring(7)}",
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      "Generated via Entrixo Admin Suite",
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      final path = await _getDirectoryPath();
      final fileName = "Headcount_${DateFormat('ddMMMyyyy').format(date)}.pdf";
      final file = File("$path/$fileName");
      await file.writeAsBytes(await pdf.save());
      if (context.mounted) {
        CustomToast.show(
          context,
          "PDF Saved in Downloads/Entrixo",
          isError: false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(context, "Export Failed", isError: true);
      }
    }
  }

  static Future<void> generateExcel(
    BuildContext context,
    DateTime date,
    List<BatchHeadcountModel> batches,
    int gTotal,
    int gPre,
    int gPost,
  ) async {
    if (!await _requestPermission()) return;

    var xl = excel.Excel.createExcel();
    excel.Sheet sheet = xl['Sheet1'];

    excel.CellStyle headerStyle = excel.CellStyle(
      bold: true,
      fontColorHex: excel.ExcelColor.white,
      backgroundColorHex: excel.ExcelColor.blue,
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    excel.CellStyle dataStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    sheet.merge(
      excel.CellIndex.indexByString("A1"),
      excel.CellIndex.indexByString("H1"),
    );
    var titleCell = sheet.cell(excel.CellIndex.indexByString("A1"));
    titleCell.value = excel.TextCellValue(
      "SHOBHIT UNIVERSITY, GANGOH - Attendance Report",
    );
    titleCell.cellStyle = excel.CellStyle(
      bold: true,
      horizontalAlign: excel.HorizontalAlign.Center,
      fontSize: 14,
    );

    sheet.merge(
      excel.CellIndex.indexByString("A2"),
      excel.CellIndex.indexByString("H2"),
    );
    var dateCell = sheet.cell(excel.CellIndex.indexByString("A2"));
    dateCell.value = excel.TextCellValue(
      "Date: ${DateFormat('dd-MM-yyyy').format(date)}",
    );
    dateCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Center,
      italic: true,
    );

    List<String> headers = [
      'S.No.',
      'Program',
      'Semester',
      'Total',
      'Pre-Lunch',
      'Pre %',
      'Post-Lunch',
      'Post %',
    ];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
      );
      cell.value = excel.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < batches.length; i++) {
      final b = batches[i];
      double p1 = b.totalStudents == 0
          ? 0
          : (b.preLunch / b.totalStudents) * 100;
      double p2 = b.totalStudents == 0
          ? 0
          : (b.postLunch / b.totalStudents) * 100;

      List<dynamic> rowData = [
        i + 1,
        b.courseName,
        b.semester,
        b.totalStudents,
        b.preLunch,
        "${p1.toStringAsFixed(1)}%",
        b.postLunch,
        "${p2.toStringAsFixed(1)}%",
      ];

      for (int col = 0; col < rowData.length; col++) {
        var cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 4),
        );
        cell.value = rowData[col] is int
            ? excel.IntCellValue(rowData[col])
            : excel.TextCellValue(rowData[col].toString());
        cell.cellStyle = dataStyle;
      }
    }

    int footerRow = batches.length + 4;
    double avgP1 = gTotal == 0 ? 0 : (gPre / gTotal) * 100;
    double avgP2 = gTotal == 0 ? 0 : (gPost / gTotal) * 100;

    List<dynamic> footerData = [
      '',
      'TOTAL SUMMARY',
      '',
      gTotal,
      gPre,
      "${avgP1.toStringAsFixed(1)}%",
      gPost,
      "${avgP2.toStringAsFixed(1)}%",
    ];

    excel.CellStyle footerStyle = excel.CellStyle(
      bold: true,
      fontColorHex: excel.ExcelColor.white,
      backgroundColorHex: excel.ExcelColor.green,
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    for (int col = 0; col < footerData.length; col++) {
      var cell = sheet.cell(
        excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: footerRow),
      );
      cell.value = footerData[col] is int
          ? excel.IntCellValue(footerData[col])
          : excel.TextCellValue(footerData[col].toString());
      cell.cellStyle = footerStyle;
    }

    sheet.setColumnWidth(0, 8.0);
    sheet.setColumnWidth(1, 20.0);
    sheet.setColumnWidth(2, 15.0);
    sheet.setColumnWidth(3, 10.0);
    sheet.setColumnWidth(4, 12.0);
    sheet.setColumnWidth(5, 12.0);
    sheet.setColumnWidth(6, 12.0);
    sheet.setColumnWidth(7, 12.0);

    try {
      final path = await _getDirectoryPath();
      final fileName = "Headcount_${DateFormat('ddMMMyyyy').format(date)}.xlsx";
      final file = File("$path/$fileName");
      await file.writeAsBytes(xl.encode()!);

      if (context.mounted) {
        CustomToast.show(
          context,
          "Excel Saved in Downloads/Entrixo",
          isError: false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomToast.show(context, "Failed to save Excel", isError: true);
      }
    }
  }
}
