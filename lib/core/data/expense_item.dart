class ExpenseItem {
  final String id;
  final DateTime date;
  final DateTime? endDate; // null = 단일 날짜, non-null = 기간 지출
  final int amount;
  final String content;
  final String category;       // 지출 카테고리: 음식/배달, 교통 등
  final String paymentMethod;  // 결제수단: 신용카드 | 체크+현금 | 기타
  /// 사업경비 인정 여부 — 프리랜서·N잡러(사업소득) 대상. 카테고리와 별개인 독립 플래그.
  final bool isBusiness;

  /// 공제율이 다른 곳에서 썼는가 — `전통시장` | `대중교통` | `도서공연` | null.
  ///
  /// **결제수단도 카테고리도 아니다.** 어떻게 냈는지(신용/체크)와도, 무엇을
  /// 샀는지(음식/교통)와도 따로 논다. 세법이 이 셋만 따로 떼어 높은 공제율을
  /// 주기 때문에(조특법 §126의2) 별도 표식이 필요하다.
  ///
  /// 카테고리로 대신할 수 없다. `교통`에는 택시·주차가 섞여 있는데 대중교통
  /// 공제는 버스·지하철·기차만이다. 카테고리로 갈음하면 안 되는 것을 공제로
  /// 세게 된다.
  final String? deductionType;
  /// 기록 당시의 유형(직장인/N잡러/프리랜서). null = 유형 분리 이전 공통 기록.
  final String? userType;

  ExpenseItem({
    required this.id,
    required this.date,
    this.endDate,
    required this.amount,
    required this.content,
    required this.category,
    this.paymentMethod = '기타',
    this.isBusiness = false,
    this.deductionType,
    this.userType,
  });

  ExpenseItem copyWith({
    String? id,
    DateTime? date,
    DateTime? endDate,
    int? amount,
    String? content,
    String? category,
    String? paymentMethod,
    bool? isBusiness,
    String? deductionType,
    String? userType,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      content: content ?? this.content,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isBusiness: isBusiness ?? this.isBusiness,
      deductionType: deductionType ?? this.deductionType,
      userType: userType ?? this.userType,
    );
  }
}
