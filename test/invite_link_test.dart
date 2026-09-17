import 'package:flutter_test/flutter_test.dart';
import 'package:rituals/models/group.dart';

void main() {
  test('an invite link round trips back to its code', () {
    expect(inviteCodeFrom(inviteLinkFor('AB12CD')), 'AB12CD');
  });

  test('a code survives whatever it is wrapped in', () {
    expect(inviteCodeFrom('AB12CD'), 'AB12CD');
    expect(inviteCodeFrom('ab12cd'), 'AB12CD');
    expect(inviteCodeFrom(' ab12-cd '), 'AB12CD');
    expect(inviteCodeFrom('https://rituals-b3bed.web.app/join/ab12cd'), 'AB12CD');
  });

  test('nothing usable gives an empty code', () {
    expect(inviteCodeFrom('https://rituals-b3bed.web.app/'), '');
  });
}
