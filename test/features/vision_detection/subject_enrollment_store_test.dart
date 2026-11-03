import 'package:flutter_test/flutter_test.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/subject_enrollment_store.dart';
import 'package:punch_detection_demo/features/vision_detection/domain/subject_lock/subject_lock.dart';

void main() {
  tearDown(SubjectEnrollmentStore.clear);

  test('nothing stored = the session takes the photo itself', () {
    expect(SubjectEnrollmentStore.take(), isNull);
  });

  test('a captured lock is handed over once', () {
    final SubjectLock lock = SubjectLock();
    SubjectEnrollmentStore.put(SubjectEnrollment.captured(lock, null));
    final SubjectEnrollment? taken = SubjectEnrollmentStore.take();
    expect(taken?.lock, same(lock));
    expect(taken?.skipped, isFalse);
    expect(SubjectEnrollmentStore.take(), isNull);
  });

  test('skip is handed over without a lock', () {
    SubjectEnrollmentStore.put(const SubjectEnrollment.skipped());
    final SubjectEnrollment? taken = SubjectEnrollmentStore.take();
    expect(taken?.skipped, isTrue);
    expect(taken?.lock, isNull);
  });

  test('clear forgets a result that was not taken', () {
    SubjectEnrollmentStore.put(const SubjectEnrollment.skipped());
    SubjectEnrollmentStore.clear();
    expect(SubjectEnrollmentStore.hasPending, isFalse);
  });
}
