import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'correction_report.dart';

/// 공식 「과세표준 및 세액의 결정(경정)청구서」에 **앱이 아는 칸만** 찍는다.
///
/// 서식: 국세기본법 시행규칙 별지 제16호의2서식(1), 개정 2025.3.21.
/// 파일: `assets/forms/gyeongjeong_national.pdf` — A4 595×841pt, 회전 없음,
/// MediaBox·CropBox 모두 원점 (0,0)이라 좌표가 그대로 맞는다.
///
/// **비워 두는 칸이 있다. 일부러 그렇다.**
///
/// - ①~⑥ 청구인 인적사항 — 앱이 이름도 주민번호도 갖고 있지 않다. 갖지 않는
///   것이 이 앱의 약속이다(모든 계산이 기기 안에서 끝난다).
/// - ⑧ 최초신고일 — 사용자만 안다.
/// - ⑪ 과세표준금액 · ⑫ 산출세액 · ⑬ 가산세액 · ⑭ 공제 및 감면세액 —
///   **원천징수영수증에 적힌 실제 값**이라야 한다. 총급여로 추정할 수는 있지만
///   추정치를 세무서에 내는 문서에 찍는 건 다른 종류의 일이다.
/// - ⑮ 납부할 세액 — 결정세액에서 기납부세액을 뺀 값인데, 기납부세액을 앱이
///   받지 않는다. 0으로 찍으면 그럴듯하게 틀린다.
/// - ⑯ 환급 계좌 — 계좌번호는 앱이 받지 않는다.
///
/// 채우는 칸은 **앱이 정확히 아는 것**뿐이다: ⑦ 법정신고일(법이 정한 날),
/// ⑨ 청구이유(고른 항목), ⑩ 세목, ⑰ 환급받을 세액(계산 결과), 그리고 청구일.
/// 표의 세로 자 — PyMuPDF로 실측한 값이다.
/// 라벨 열은 ~171.9에서 끝나고, 최초신고/결정청구는 328.1에서 갈리며,
/// 표 오른쪽 끝은 538.0이다.
const double _colLeft = 171.9;
const double _colMid = 328.1;
const double _colRight = 538.0;

/// 행 경계(위쪽 가로줄) — 행 높이는 16.7pt로 일정하다.
const double _rowFiled = 210.4; // ⑦ 법정신고일 · ⑧ 최초신고일
const double _rowReason = 227.2; // ⑨ 결정(경정)청구이유
const double _rowTaxKind = 260.6; // ⑩ 세목
const double _rowRefund = 377.2; // ⑰ 환급받을 세액
/// 「년 월 일」 글자의 윗변이 424.9다. [put]이 4.5를 내리므로 그만큼 올려 둔다 —
/// 안 그러면 인쇄된 「년」보다 숫자가 한 줄 내려앉는다.
const double _rowClaimDate = 420.4;

Future<Uint8List> fillCorrectionForm({
  required Uint8List formBytes,
  required Uint8List koreanFont,
  required CorrectionReport report,
  required List<String> itemNames,
  DateTime? claimedOn,
}) async {
  final doc = PdfDocument(inputBytes: formBytes);
  final page = doc.pages[0];
  final g = page.graphics;
  final font = PdfTrueTypeFont(koreanFont, 9.5);
  final black = PdfBrushes.black;
  final today = claimedOn ?? DateTime.now();

  /// 칸 안에 글자를 앉힌다. 칸 높이가 16.7이라 위에서 4.5 내리면 가운데다.
  void put(double x, double y, double w, String s,
      {PdfTextAlignment align = PdfTextAlignment.left}) {
    g.drawString(s, font,
        brush: black,
        bounds: Rect.fromLTWH(x + 5, y + 4.5, w - 10, 13),
        format: PdfStringFormat(alignment: align));
  }

  // ⑦ 법정신고일 — 종합소득세 확정신고 기한은 귀속연도 다음 해 5월 31일
  // (소득세법 §70①). 경정청구 기산점이라 이 칸이 비면 접수가 늦어진다.
  put(_colLeft, _rowFiled, _colMid - _colLeft,
      '${report.accrualYear + 1}. 5. 31.');

  // ⑨ 결정(경정)청구이유 — 고른 항목을 그대로 적는다. 「공제 누락」만 쓰면
  // 세무서가 무엇을 뺐는지 몰라 보정을 요구한다.
  put(_colLeft, _rowReason, _colRight - _colLeft,
      '${report.accrualYear}년 귀속 연말정산 시 ${itemNames.join(' · ')} 공제 누락');

  // ⑩ 세목 — 양쪽 열 모두 종합소득세다.
  put(_colLeft, _rowTaxKind, _colMid - _colLeft, '종합소득세');
  put(_colMid, _rowTaxKind, _colRight - _colMid, '종합소득세');

  // ⑰ 환급받을 세액 — 이 서식의 결론. 결정(경정)청구 열에 적는다.
  put(_colMid, _rowRefund, _colRight - _colMid,
      '${_comma(report.additionalRefund)} 원', align: PdfTextAlignment.right);

  // 청구일 — 「년 월 일」 글자 바로 앞에 숫자를 넣는다.
  // 네 자리가 들어갈 폭을 준다. 28로 잡았더니 2026이 「202」로 잘렸다.
  put(406, _rowClaimDate, 36, '${today.year}', align: PdfTextAlignment.right);
  put(447, _rowClaimDate, 26, '${today.month}', align: PdfTextAlignment.right);
  put(479, _rowClaimDate, 26, '${today.day}', align: PdfTextAlignment.right);

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

/// 지방세 「과세표준 및 세액 등의 결정 또는 경정 청구서」 — 지방세기본법
/// 시행규칙 별지 제14호서식, 개정 2019.12.31. 1쪽짜리다.
///
/// **금액 칸은 비운다.** 개인지방소득세를 「소득세 결정세액의 10%」로 안내하는
/// 곳이 많지만, 조문상 산출세액은 지방소득세율표로 따로 계산하고 세액공제도
/// 지방세법이 따로 정한다(§103의19 등). 그 대응을 확인하지 않은 채 근사치를
/// 찍는 건 국세 서식에서 과세표준·산출세액을 비워 둔 것과 같은 이유로 안 한다.
///
/// 청구 이유를 적을 칸도 없다 — 서식이 「내용이 많은 경우 별지 기재」라고만
/// 하고 입력란을 두지 않았다. 앱의 「작성 내역」이 그 별지 노릇을 한다.
///
/// 청구 기한은 국세와 같다 — 법정신고기한이 지난 후 5년 이내(지방세기본법 §50①).
Future<Uint8List> fillLocalCorrectionForm({
  required Uint8List formBytes,
  required Uint8List koreanFont,
  required int accrualYear,
  DateTime? claimedOn,
}) async {
  final doc = PdfDocument(inputBytes: formBytes);
  final g = doc.pages[0].graphics;
  final font = PdfTrueTypeFont(koreanFont, 9.5);
  final tiny = PdfTrueTypeFont(koreanFont, 7);
  final black = PdfBrushes.black;
  final today = claimedOn ?? DateTime.now();

  void put(double x, double y, double w, String s,
      {PdfFont? f, PdfTextAlignment align = PdfTextAlignment.left}) {
    g.drawString(s, f ?? font,
        brush: black,
        bounds: Rect.fromLTWH(x + 5, y + 4.5, w - 10, 13),
        format: PdfStringFormat(alignment: align));
  }

  // 법정신고일 — 개인지방소득세도 5월 31일까지다(지방세법 §95①).
  put(170, 228.3, 150, '${accrualYear + 1}. 5. 31.');

  // 경정청구 대상(과세물건)
  put(256.7, 243.9, 534.1 - 256.7, '개인지방소득세');

  // (  )세 — 괄호 사이가 24pt뿐이다. 「지방소득」 네 글자는 7pt로 줄여도
  // 「지방」에서 잘렸다(렌더링해서 확인). 지방세 서식의 ( )세는 「(취득)세」·
  // 「(재산)세」처럼 쓰므로 여기서는 「(소득)세」가 맞고, 바로 위 과세물건 칸에
  // 「개인지방소득세」가 적혀 있어 뜻이 흐려지지 않는다.
  put(118, 310.5, 28, '소득', f: tiny, align: PdfTextAlignment.center);

  // 청구일 — 「년 월 일」 글자 윗변이 435.4다.
  put(398, 430.9, 36, '${today.year}', align: PdfTextAlignment.right);
  put(439, 430.9, 26, '${today.month}', align: PdfTextAlignment.right);
  put(489, 430.9, 26, '${today.day}', align: PdfTextAlignment.right);

  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}
