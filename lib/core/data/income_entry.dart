class IncomeEntry {
  final String id;
  final DateTime date;
  final DateTime? endDate; // null = 단일 날짜, non-null = 기간 수입
  final int amount;
  final String memo;
  final String incomeType; // '급여', '프리랜서', '부수입', '기타'
  /// 3.3% 원천징수 사업소득 여부. true면 [amount]는 실수령액(세후)이며,
  /// 세전 금액·원천징수세액은 화면에서 파생 계산만 하고 별도 저장하지 않는다.
  final bool isWithheld;
  /// 기록 당시의 유형(직장인/N잡러/프리랜서). null = 유형 분리 이전 공통 기록.
  final String? userType;

  IncomeEntry({
    required this.id,
    required this.date,
    this.endDate,
    required this.amount,
    required this.memo,
    required this.incomeType,
    this.isWithheld = false,
    this.userType,
  });

  IncomeEntry copyWith({
    String? id,
    DateTime? date,
    DateTime? endDate,
    int? amount,
    String? memo,
    String? incomeType,
    bool? isWithheld,
    String? userType,
  }) {
    return IncomeEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      incomeType: incomeType ?? this.incomeType,
      isWithheld: isWithheld ?? this.isWithheld,
      userType: userType ?? this.userType,
    );
  }
}
