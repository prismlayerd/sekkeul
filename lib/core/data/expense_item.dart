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
      userType: userType ?? this.userType,
    );
  }
}
