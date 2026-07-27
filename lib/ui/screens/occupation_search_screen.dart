import 'package:flutter/material.dart';
import '../../core/data/occupation_data.dart';
import '../theme/app_theme.dart';
import '../theme/text_wrap.dart';

/// 업종코드 검색 — 풀스크린 push 화면.
///
/// 앱 하드 제약(바텀시트 금지 — fullscreen push / inline expand / AlertDialog만
/// 허용)에 맞춰 과거 바텀시트에서 전환됨. 검색 로직(동의어·관련도 점수)은 그대로.
class OccupationSearchScreen extends StatefulWidget {
  const OccupationSearchScreen({super.key});

  static Future<OccupationInfo?> show(BuildContext context) {
    return Navigator.of(context).push<OccupationInfo>(
      MaterialPageRoute(builder: (_) => const OccupationSearchScreen()),
    );
  }

  @override
  State<OccupationSearchScreen> createState() => _OccupationSearchScreenState();
}

class _OccupationSearchScreenState extends State<OccupationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<OccupationInfo> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = OccupationData.occupations.values.take(50).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 구어체 → 경비율 고시 공식 용어 동의어. 사용자가 흔히 치는 말이
  /// 공식 분류명과 달라(예: '카페'→고시엔 '커피숍') 검색이 빗나가는 걸 메운다.
  static const Map<String, List<String>> _synonyms = {
    '카페': ['커피', '커피숍'],
    '까페': ['커피', '커피숍'],
    '커피숍': ['커피'],
    '치킨': ['닭', '호프', '튀김'],
    '분식': ['김밥', '떡볶이', '음식점'],
    '식당': ['음식점', '한식'],
    '밥집': ['음식점', '한식'],
    '고깃집': ['육류', '구이', '음식점'],
    '술집': ['주점', '호프', '맥주'],
    '호프': ['주점', '맥주'],
    '피시방': ['컴퓨터게임', '게임'],
    'pc방': ['컴퓨터게임', '게임'],
    '노래방': ['노래연습장'],
    '헬스장': ['체력단련', '스포츠'],
    '헬스': ['체력단련'],
    '미용실': ['미용', '이용'],
    '네일': ['미용'],
    '옷가게': ['의류', '의복'],
    '편의점': ['종합소매', '체인화편의점'],
    '학원': ['교습', '강사'],
    '과외': ['교습', '강사'],
    '유튜버': ['미디어콘텐츠', '1인미디어', '크리에이터'],
    '유튜브': ['미디어콘텐츠', '1인미디어'],
    '쇼핑몰': ['전자상거래', '통신판매'],
    '스마트스토어': ['전자상거래', '통신판매'],
    '온라인판매': ['전자상거래', '통신판매'],
    '배달': ['배달', '퀵서비스'],
    '택배': ['배달', '화물', '퀵서비스'],
    '프리랜서': ['인적용역'],
    '개발자': ['소프트웨어', '프로그래'],
    '프로그래머': ['소프트웨어', '프로그래'],
    '디자이너': ['디자인'],
    '사진작가': ['사진', '촬영'],
    '블로거': ['미디어콘텐츠', '1인미디어'],
    '인플루언서': ['미디어콘텐츠', '1인미디어'],
  };

  /// 관련도 점수 — 이름 일치 > 부분일치 > 키워드 > 코드. 0이면 제외.
  int _score(OccupationInfo info, String t) {
    if (t.isEmpty) return 0;
    final name = info.name.toLowerCase().replaceAll(' ', '');
    final kw = info.keywords.toLowerCase().replaceAll(' ', '');
    if (name == t) return 100;
    if (name.startsWith(t)) return 85;
    if (name.contains(t)) return 70;
    if (info.code.startsWith(t)) return 50;
    if (kw.contains(t)) return 40;
    return 0;
  }

  void _onSearch(String keyword) {
    final q = keyword.trim().toLowerCase().replaceAll(' ', '');
    if (q.isEmpty) {
      setState(() => _filteredList = OccupationData.occupations.values.take(50).toList());
      return;
    }
    // term → 보너스. 원 검색어는 보너스 0, 동의어는 +20을 줘서 구어체 검색이
    // 우연한 부분일치(예: '카페'→'카페트')보다 위로 올라오게 한다.
    final terms = <String, double>{q: 0};
    _synonyms.forEach((k, syns) {
      if (q == k || q.contains(k)) {
        for (final s in syns) terms[s] = 20;
      }
    });

    final scored = <MapEntry<OccupationInfo, double>>[];
    for (final info in OccupationData.occupations.values) {
      double best = 0;
      terms.forEach((t, bonus) {
        final base = _score(info, t).toDouble();
        if (base > 0) {
          final s = (base + bonus).clamp(0, 100).toDouble();
          if (s > best) best = s;
        }
      });
      if (best > 0) scored.add(MapEntry(info, best));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    setState(() => _filteredList = scored.take(60).map((e) => e.key).toList());
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('업종코드 검색', style: AppTheme.serif(AppTheme.serifMD, ink)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤어라인 밑줄 검색창 — 필드 입력 스타일과 통일.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.lineStrong(context), width: 1.2)),
                ),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: AppTheme.inkTertiary(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearch,
                        autofocus: true,
                        style: AppTheme.sans(17, ink, weight: FontWeight.w600, spacing: -0.3),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: '업종명(예: 프리랜서, 카페) 또는 6자리 코드',
                          hintStyle: AppTheme.sans(15, AppTheme.inkTertiary(context)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _filteredList.isEmpty
                  ? Center(
                      child: Text('일치하는 업종이 없어요.\n다른 말로 검색해 보세요.'.keepWords,
                          textAlign: TextAlign.center, style: AppTheme.sans(14, sub, height: 1.5)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _filteredList.length,
                      separatorBuilder: (_, __) => AppTheme.hairline(context),
                      itemBuilder: (context, index) {
                        final item = _filteredList[index];
                        final nameParts = item.name.split(' / ');
                        final category = nameParts.length > 1 ? nameParts[0] : '';
                        final detailName = nameParts.length > 1 ? nameParts[1] : item.name;

                        return InkWell(
                          onTap: () => Navigator.pop(context, item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (category.isNotEmpty) ...[
                                        Text(category, style: AppTheme.label(context)),
                                        const SizedBox(height: 5),
                                      ],
                                      Text(detailName,
                                          style: AppTheme.sans(15, ink, weight: FontWeight.w600, spacing: -0.2)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 코드는 채운 pill 대신 도면식 테두리 태그.
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.lineStrong(context), width: 1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(item.code,
                                      style: AppTheme.sans(13, sub, weight: FontWeight.w700, spacing: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
