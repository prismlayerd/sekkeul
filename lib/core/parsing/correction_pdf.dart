import 'dart:typed_data';
import 'dart:ui' show Rect, Offset;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../data/deduction_catalog.dart';
import 'correction_report.dart';

/// 경정청구 **작성 내역서** PDF.
///
/// 세무서에 낼 「경정청구서」(국세기본법 시행규칙 별지 제16호의2서식)는
/// `assets/forms/gyeongjeong_national.pdf`에 있는데, **입력 필드가 없는
/// 인쇄용 PDF다** — `/AcroForm`도 `/Widget`도 0건이다. 값을 넣으려면 좌표에
/// 글자를 얹어야 하고, 서식이 개정되면 숫자가 엉뚱한 칸에 찍힌다. 세무서에
/// 내는 문서라 그 위험은 감당할 게 못 된다.
///
/// 그래서 앱은 **옮겨 적을 것을 한 장에 정리해 준다.** 항목·금액·환급 예상액과
/// 첨부 서류가 순서대로 있어서, 공식 양식에 그대로 베끼면 된다. 공식 양식은
/// 같은 화면에서 같이 받는다.
///
/// ponytail: 좌표 기입은 렌더링해서 눈으로 확인할 수 있을 때 따로 한다.
Future<Uint8List> buildCorrectionPdf({
  required CorrectionReport report,
  required Map<String, int> amounts,
  required int grossSalary,
  required int decidedTax,
  required Uint8List koreanFont,
}) async {
  final doc = PdfDocument();
  final page = doc.pages.add();
  final g = page.graphics;
  final w = page.getClientSize().width;

  final title = PdfTrueTypeFont(koreanFont, 18);
  final head = PdfTrueTypeFont(koreanFont, 11);
  final body = PdfTrueTypeFont(koreanFont, 10);
  final small = PdfTrueTypeFont(koreanFont, 8.5);
  final black = PdfBrushes.black;
  final gray = PdfSolidBrush(PdfColor(110, 110, 110));
  final line = PdfPen(PdfColor(60, 60, 60), width: 0.8);

  double y = 0;

  void text(String s, PdfFont f, {PdfBrush? brush, double x = 0, double gap = 4}) {
    g.drawString(s, f, brush: brush ?? black, bounds: Rect.fromLTWH(x, y, w - x, f.height + 2));
    y += f.height + gap;
  }

  void rule({double gap = 8}) {
    g.drawLine(line, Offset(0, y), Offset(w, y));
    y += gap;
  }

  /// 라벨은 왼쪽, 금액은 오른쪽 끝. 자릿수가 세로로 맞아야 읽힌다.
  void row(String label, String value, {bool bold = false}) {
    g.drawString(label, body, brush: black, bounds: Rect.fromLTWH(0, y, w * 0.6, body.height + 2));
    g.drawString(value, bold ? head : body,
        brush: black,
        bounds: Rect.fromLTWH(w * 0.6, y, w * 0.4, head.height + 2),
        format: PdfStringFormat(alignment: PdfTextAlignment.right));
    y += (bold ? head.height : body.height) + 6;
  }

  text('경정청구 작성 내역', title, gap: 2);
  text('${report.accrualYear}년 귀속 · 종합소득세', body, brush: gray, gap: 10);
  rule();

  text('기준 금액', head, gap: 6);
  row('총급여', '${_comma(grossSalary)}원');
  row('결정세액 (이미 낸 세금)', '${_comma(decidedTax)}원');
  y += 6;
  rule();

  text('추가로 신청할 공제', head, gap: 6);
  for (final l in report.lines) {
    row('${l.category}  (지출 ${_comma(l.available)}원)', '+${_comma(l.missedCredit)}원');
  }
  rule(gap: 6);
  row('환급받을 세액', '${_comma(report.additionalRefund)}원', bold: true);
  y += 4;
  text('결정세액을 넘겨 돌려받을 수는 없어요 — 이미 낸 세금이 상한이에요.', small,
      brush: gray, gap: 12);
  rule();

  text('같이 낼 서류', head, gap: 6);
  final selected = kDeductionCatalog.where((c) => (amounts[c.id] ?? 0) > 0);
  var any = false;
  for (final c in selected) {
    for (final d in c.documents) {
      any = true;
      text('☐  $d', body, x: 4, gap: 5);
    }
  }
  if (!any) text('고른 항목이 없어요.', body, brush: gray);
  y += 8;
  rule();

  text(
      '이 장은 세끌이 만든 정리표예요. 세무서에 내는 서류는 「경정청구서」'
      '(국세기본법 시행규칙 별지 제16호의2서식)이고, 위 숫자를 그대로 옮겨 적으면 돼요.',
      small,
      brush: gray,
      gap: 3);
  text('경정청구는 법정신고기한이 지난 뒤 5년 안이면 아무 때나 할 수 있어요 (국세기본법 §45의2).',
      small,
      brush: gray);

  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

String _comma(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
