import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/data/occupation_data.dart';

/// 업종코드 → 기장의무 그룹/전문직 판정 (0단계 선행 데이터) 검증.
void main() {
  OccupationInfo info(String code) {
    final o = OccupationData.occupations[code];
    expect(o, isNotNull, reason: '데이터셋에 $code 없음');
    return o!;
  }

  /// 접두어로 시작하는 실제 6자리 코드 중 첫 항목(테스트용 대표 코드).
  OccupationInfo firstWithPrefix(String prefix) {
    final code = OccupationData.occupations.keys.firstWhere(
      (c) => c.startsWith(prefix),
      orElse: () => throw StateError('접두어 $prefix 코드 없음'),
    );
    return info(code);
  }

  group('기장의무 그룹 판정 (A=3억 / B=1.5억 / C=7,500만)', () {
    test('그룹A — 농림어·광업·도소매·부동산매매', () {
      expect(info('011001').bookkeepingGroup, BookkeepingGroup.a); // 채소재배(농업)
      expect(info('020200').bookkeepingGroup, BookkeepingGroup.a); // 벌목(임업)
      expect(info('051102').bookkeepingGroup, BookkeepingGroup.a); // 연근해어업
      expect(info('101000').bookkeepingGroup, BookkeepingGroup.a); // 석탄광업
      expect(info('523111').bookkeepingGroup, BookkeepingGroup.a); // 의약품소매(그룹은 A, 단 전문직)
      expect(info('703011').bookkeepingGroup, BookkeepingGroup.a); // 부동산매매
      expect(info('011001').complexBookkeepingThreshold, 300000000);
    });

    test('그룹B — 제조·건설·숙박음식·운수·정보통신·금융보험·전기가스수도·폐기물', () {
      expect(info('151101').bookkeepingGroup, BookkeepingGroup.b); // 육류도축(제조)
      expect(firstWithPrefix('401').bookkeepingGroup, BookkeepingGroup.b); // 전기
      expect(firstWithPrefix('451').bookkeepingGroup, BookkeepingGroup.b); // 건설
      expect(firstWithPrefix('551').bookkeepingGroup, BookkeepingGroup.b); // 숙박
      expect(firstWithPrefix('552').bookkeepingGroup, BookkeepingGroup.b); // 음식
      expect(firstWithPrefix('601').bookkeepingGroup, BookkeepingGroup.b); // 운수
      expect(firstWithPrefix('641').bookkeepingGroup, BookkeepingGroup.b); // 통신
      expect(firstWithPrefix('659').bookkeepingGroup, BookkeepingGroup.b); // 금융
      expect(info('722000').bookkeepingGroup, BookkeepingGroup.b); // SW개발(정보통신)
      expect(firstWithPrefix('900').bookkeepingGroup, BookkeepingGroup.b); // 폐기물처리
      expect(info('151101').complexBookkeepingThreshold, 150000000);
    });

    test('그룹C — 부동산임대·전문과학기술·교육·보건·예술스포츠·개인서비스·인적용역', () {
      expect(info('701102').bookkeepingGroup, BookkeepingGroup.c); // 주택임대
      expect(info('702001').bookkeepingGroup, BookkeepingGroup.c); // 부동산중개
      expect(info('712100').bookkeepingGroup, BookkeepingGroup.c); // 임대(농기계)
      expect(info('725000').bookkeepingGroup, BookkeepingGroup.c); // 컴퓨터수리
      expect(info('730000').bookkeepingGroup, BookkeepingGroup.c); // 연구개발
      expect(info('743002').bookkeepingGroup, BookkeepingGroup.c); // 광고대행
      expect(info('809005').bookkeepingGroup, BookkeepingGroup.c); // 학원(교육)
      expect(info('851901').bookkeepingGroup, BookkeepingGroup.c); // 조산소(보건, 전문직 아님)
      expect(info('924303').bookkeepingGroup, BookkeepingGroup.c); // 골프장(스포츠)
      expect(info('930201').bookkeepingGroup, BookkeepingGroup.c); // 이용(개인서비스)
      expect(info('940306').bookkeepingGroup, BookkeepingGroup.c); // 1인미디어창작자(인적용역)
      expect(info('940100').complexBookkeepingThreshold, 75000000);
    });

    test('핵심 프리랜서(940xxx 인적용역)는 전부 그룹C', () {
      for (final code in OccupationData.occupations.keys.where((c) => c.startsWith('940'))) {
        expect(info(code).bookkeepingGroup, BookkeepingGroup.c, reason: '$code 인적용역');
      }
    });

    test('921 분기 — 영상·방송=B, 공연·여가=C', () {
      expect(info('921302').bookkeepingGroup, BookkeepingGroup.b); // 지상파방송
      expect(info('921502').bookkeepingGroup, BookkeepingGroup.b); // 영화제작
      expect(info('921401').bookkeepingGroup, BookkeepingGroup.c); // 공연기획
      expect(info('921903').bookkeepingGroup, BookkeepingGroup.c); // 유원지운영
    });
  });

  group('전문직 판정 (수입 무관 무조건 복식부기)', () {
    test('의료업(병원·의원) = 전문직', () {
      expect(info('851113').isProfessional, isTrue); // 종합병원
      expect(info('851201').isProfessional, isTrue); // 일반과의원
      expect(info('851211').isProfessional, isTrue); // 치과의원
      expect(info('851212').isProfessional, isTrue); // 한의원
      expect(info('852000').isProfessional, isTrue); // 수의업
    });

    test('의료유사·보건지원(8519)은 전문직 아님', () {
      expect(info('851903').isProfessional, isFalse); // 안마사
      expect(info('851906').isProfessional, isFalse); // 혈액원
      expect(info('851911').isProfessional, isFalse); // 앰뷸런스
    });

    test('법률·회계·기술·감정 전문직', () {
      expect(info('741101').isProfessional, isTrue); // 변호사
      expect(info('741104').isProfessional, isTrue); // 변리사
      expect(info('741107').isProfessional, isTrue); // 법무사
      expect(info('741110').isProfessional, isTrue); // 공인노무사
      expect(info('741201').isProfessional, isTrue); // 세무사
      expect(info('741202').isProfessional, isTrue); // 공인회계사
      expect(info('741401').isProfessional, isTrue); // 경영지도사
      expect(info('742101').isProfessional, isTrue); // 측량사
      expect(info('742105').isProfessional, isTrue); // 건축사
      expect(info('742106').isProfessional, isTrue); // 기술사
      expect(info('742202').isProfessional, isTrue); // 기술지도사
      expect(info('749904').isProfessional, isTrue); // 손해사정인
      expect(info('749906').isProfessional, isTrue); // 관세사
      expect(info('702002').isProfessional, isTrue); // 감정평가사
      expect(info('630403').isProfessional, isTrue); // 도선사
    });

    test('약사업 = 전문직', () {
      expect(info('523111').isProfessional, isTrue); // 약국(의약품소매)
      expect(info('523114').isProfessional, isTrue); // 한약
      expect(info('522105').isProfessional, isTrue); // 한약업사
    });

    test('비전문 유사업종은 전문직 아님', () {
      expect(info('513311').isProfessional, isFalse); // 의약품 도매(약사업 아님)
      expect(info('742103').isProfessional, isFalse); // 건축설계(건축사 코드 아님)
      expect(info('749912').isProfessional, isFalse); // 물품감정(감정평가사 아님)
      expect(info('741109').isProfessional, isFalse); // 행정사(열거 목록 외)
      expect(info('940306').isProfessional, isFalse); // 1인미디어창작자
    });
  });

  test('모든 코드가 3그룹 중 하나로 판정된다', () {
    for (final o in OccupationData.occupations.values) {
      expect(
        BookkeepingGroup.values.contains(o.bookkeepingGroup),
        isTrue,
        reason: '${o.code} 그룹 미판정',
      );
    }
  });
}
