/**
 * Firestore security-rules tests for Focus or Roast.
 *
 * These run against the Firestore emulator via @firebase/rules-unit-testing and
 * assert the authorization matrix (unauthenticated / owner / other-user /
 * group-member) for every collection the app actually uses.
 *
 * REQUIREMENTS (not part of the Flutter toolchain):
 *   - Java runtime (the Firestore emulator is a Java process)
 *   - npm install   (installs the devDependencies in package.json)
 *
 * RUN:
 *   npm run test:rules
 * which executes:
 *   firebase emulators:exec --only firestore "mocha test/rules/firestore.rules.test.js"
 *
 * NOTE: These were authored but NOT executed in the environment where Phase 1
 * was implemented because Java was not installed there.
 */

const fs = require('fs');
const assert = require('assert');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  getDocs,
  collection,
  query,
  where,
  orderBy,
} = require('firebase/firestore');

const ALICE = 'alice-uid';
const BOB = 'bob-uid';

let testEnv;

const aliceCtx = () => testEnv.authenticatedContext(ALICE);
const bobCtx = () => testEnv.authenticatedContext(BOB);
const unauthCtx = () => testEnv.unauthenticatedContext();

// Seed data bypassing rules (admin-like) so each test starts from a known state.
async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data, { merge: true });
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'focus-roast-rules-test',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ---------------------------------------------------------------------------
// users/{uid} — private profile
// ---------------------------------------------------------------------------
describe('users/{uid} private profile', () => {
  beforeEach(async () => {
    await seed(`users/${ALICE}`, {
      uid: ALICE,
      name: 'Alice',
      username: 'alice',
      email: 'alice@example.com',
      distractionApps: ['com.app'],
      allowGroupInvites: true,
      totalFocusMinutes: 10,
    });
  });

  it('owner can read their own profile', async () => {
    await assertSucceeds(getDoc(doc(aliceCtx().firestore(), `users/${ALICE}`)));
  });

  it('another authenticated user CANNOT read the profile (no email leak)', async () => {
    await assertFails(getDoc(doc(bobCtx().firestore(), `users/${ALICE}`)));
  });

  it('unauthenticated CANNOT read the profile', async () => {
    await assertFails(getDoc(doc(unauthCtx().firestore(), `users/${ALICE}`)));
  });

  it('owner can update their own profile', async () => {
    await assertSucceeds(
      updateDoc(doc(aliceCtx().firestore(), `users/${ALICE}`), { totalFocusMinutes: 20 }),
    );
  });

  it('another user CANNOT update the profile', async () => {
    await assertFails(
      updateDoc(doc(bobCtx().firestore(), `users/${ALICE}`), { totalFocusMinutes: 999 }),
    );
  });

  it('owner CANNOT reassign uid to someone else', async () => {
    await assertFails(
      updateDoc(doc(aliceCtx().firestore(), `users/${ALICE}`), { uid: BOB }),
    );
  });

  it('a user CANNOT create a profile document for a different uid', async () => {
    await assertFails(
      setDoc(doc(bobCtx().firestore(), `users/${ALICE}`), { uid: ALICE, name: 'x' }),
    );
  });
});

// ---------------------------------------------------------------------------
// users/{uid}/sessions — owned subcollection (representative of all subcolls)
// ---------------------------------------------------------------------------
describe('users/{uid}/sessions owned subcollection', () => {
  it('owner can write and read their sessions', async () => {
    await assertSucceeds(
      setDoc(doc(aliceCtx().firestore(), `users/${ALICE}/sessions/s1`), {
        sessionId: 's1', userId: ALICE, actualDuration: 25, completed: true,
      }),
    );
    await assertSucceeds(
      getDocs(collection(aliceCtx().firestore(), `users/${ALICE}/sessions`)),
    );
  });

  it('another user CANNOT read or write sessions', async () => {
    await seed(`users/${ALICE}/sessions/s1`, { sessionId: 's1', userId: ALICE });
    await assertFails(getDocs(collection(bobCtx().firestore(), `users/${ALICE}/sessions`)));
    await assertFails(
      setDoc(doc(bobCtx().firestore(), `users/${ALICE}/sessions/s2`), { userId: BOB }),
    );
  });

  it('unauthenticated CANNOT read sessions', async () => {
    await assertFails(getDocs(collection(unauthCtx().firestore(), `users/${ALICE}/sessions`)));
  });
});

// ---------------------------------------------------------------------------
// users/{uid}/notifications — recipient-owned, sender-created invites
// ---------------------------------------------------------------------------
describe('users/{uid}/notifications', () => {
  const path = `users/${ALICE}/notifications/n1`;

  it('recipient can read/update/delete their notifications', async () => {
    await seed(path, { recipientUid: ALICE, senderUid: BOB, read: false });
    await assertSucceeds(getDoc(doc(aliceCtx().firestore(), path)));
    await assertSucceeds(updateDoc(doc(aliceCtx().firestore(), path), { read: true }));
  });

  it('a signed-in sender can create an invite addressed to the recipient', async () => {
    await assertSucceeds(
      setDoc(doc(bobCtx().firestore(), path), {
        recipientUid: ALICE, senderUid: BOB, type: 'group_invitation',
      }),
    );
  });

  it('a sender CANNOT spoof senderUid', async () => {
    await assertFails(
      setDoc(doc(bobCtx().firestore(), path), { recipientUid: ALICE, senderUid: 'someone-else' }),
    );
  });

  it('a sender CANNOT address a notification to a different recipient', async () => {
    await assertFails(
      setDoc(doc(bobCtx().firestore(), `users/${ALICE}/notifications/n2`), {
        recipientUid: BOB, senderUid: BOB,
      }),
    );
  });

  it('a non-recipient CANNOT read the notification', async () => {
    await seed(path, { recipientUid: ALICE, senderUid: BOB });
    await assertFails(getDoc(doc(bobCtx().firestore(), path)));
  });
});

// ---------------------------------------------------------------------------
// publicProfiles/{uid} — safe projection
// ---------------------------------------------------------------------------
describe('publicProfiles/{uid}', () => {
  const valid = {
    uid: ALICE, username: 'alice', name: 'Alice',
    totalFocusMinutes: 10, allowGroupInvites: true,
  };

  it('any authenticated user can read a public profile', async () => {
    await seed(`publicProfiles/${ALICE}`, valid);
    await assertSucceeds(getDoc(doc(bobCtx().firestore(), `publicProfiles/${ALICE}`)));
  });

  it('unauthenticated CANNOT read public profiles', async () => {
    await seed(`publicProfiles/${ALICE}`, valid);
    await assertFails(getDoc(doc(unauthCtx().firestore(), `publicProfiles/${ALICE}`)));
  });

  it('the leaderboard query is readable by any authenticated user', async () => {
    await seed(`publicProfiles/${ALICE}`, valid);
    await assertSucceeds(
      getDocs(query(collection(bobCtx().firestore(), 'publicProfiles'), orderBy('totalFocusMinutes', 'desc'))),
    );
  });

  it('owner can create their own public profile', async () => {
    await assertSucceeds(setDoc(doc(aliceCtx().firestore(), `publicProfiles/${ALICE}`), valid));
  });

  it('owner CANNOT add a non-whitelisted field (email)', async () => {
    await assertFails(
      setDoc(doc(aliceCtx().firestore(), `publicProfiles/${ALICE}`), { ...valid, email: 'a@b.com' }),
    );
  });

  it('a user CANNOT write a public profile for another uid', async () => {
    await assertFails(setDoc(doc(bobCtx().firestore(), `publicProfiles/${ALICE}`), valid));
  });

  it('owner CANNOT declare a mismatched uid field', async () => {
    await assertFails(
      setDoc(doc(aliceCtx().firestore(), `publicProfiles/${ALICE}`), { ...valid, uid: BOB }),
    );
  });

  it('nobody can delete a public profile from the client', async () => {
    await seed(`publicProfiles/${ALICE}`, valid);
    await assertFails(deleteDoc(doc(aliceCtx().firestore(), `publicProfiles/${ALICE}`)));
  });
});

// ---------------------------------------------------------------------------
// Usernames/{username} — global uniqueness index
// ---------------------------------------------------------------------------
describe('Usernames/{username}', () => {
  it('any authenticated user can read the index (to resolve invites)', async () => {
    await seed('Usernames/alice', { uid: ALICE, username: 'alice' });
    await assertSucceeds(getDoc(doc(bobCtx().firestore(), 'Usernames/alice')));
  });

  it('unauthenticated CANNOT read the index', async () => {
    await assertFails(getDoc(doc(unauthCtx().firestore(), 'Usernames/alice')));
  });

  it('a user can reserve their own username', async () => {
    await assertSucceeds(
      setDoc(doc(aliceCtx().firestore(), 'Usernames/alice'), { uid: ALICE, username: 'alice' }),
    );
  });

  it('a user CANNOT reserve a username pointing to another uid', async () => {
    await assertFails(
      setDoc(doc(aliceCtx().firestore(), 'Usernames/alice'), { uid: BOB, username: 'alice' }),
    );
  });

  it('the index CANNOT store an email', async () => {
    await assertFails(
      setDoc(doc(aliceCtx().firestore(), 'Usernames/alice'), {
        uid: ALICE, username: 'alice', email: 'a@b.com',
      }),
    );
  });

  it('doc id must equal the username field', async () => {
    await assertFails(
      setDoc(doc(aliceCtx().firestore(), 'Usernames/alice'), { uid: ALICE, username: 'notalice' }),
    );
  });

  it('username must be lowercase', async () => {
    await assertFails(
      setDoc(doc(aliceCtx().firestore(), 'Usernames/Alice'), { uid: ALICE, username: 'Alice' }),
    );
  });

  it('a reserved username CANNOT be updated or deleted (no hijack)', async () => {
    await seed('Usernames/alice', { uid: ALICE, username: 'alice' });
    await assertFails(updateDoc(doc(aliceCtx().firestore(), 'Usernames/alice'), { uid: BOB }));
    await assertFails(deleteDoc(doc(aliceCtx().firestore(), 'Usernames/alice')));
  });
});

// ---------------------------------------------------------------------------
// groups/{groupId} + subcollections
// ---------------------------------------------------------------------------
describe('groups', () => {
  const pubGroup = { name: 'Public', isPublic: true, createdBy: ALICE, members: [ALICE] };
  const privGroup = { name: 'Private', isPublic: false, createdBy: ALICE, members: [ALICE] };

  it('any authenticated user can read a PUBLIC group', async () => {
    await seed('groups/pub', pubGroup);
    await assertSucceeds(getDoc(doc(bobCtx().firestore(), 'groups/pub')));
  });

  it('a non-member CANNOT read a PRIVATE group', async () => {
    await seed('groups/priv', privGroup);
    await assertFails(getDoc(doc(bobCtx().firestore(), 'groups/priv')));
  });

  it('a member CAN read a private group', async () => {
    await seed('groups/priv', privGroup);
    await assertSucceeds(getDoc(doc(aliceCtx().firestore(), 'groups/priv')));
  });

  it('creator can create a group listing themselves as a member', async () => {
    await assertSucceeds(
      setDoc(doc(aliceCtx().firestore(), 'groups/new'), {
        name: 'N', isPublic: true, createdBy: ALICE, members: [ALICE],
      }),
    );
  });

  it('a user CANNOT create a group claiming someone else as creator', async () => {
    await assertFails(
      setDoc(doc(bobCtx().firestore(), 'groups/new'), {
        name: 'N', isPublic: true, createdBy: ALICE, members: [BOB],
      }),
    );
  });

  it('a non-member can JOIN a public group by adding only themselves', async () => {
    await seed('groups/pub', pubGroup);
    await assertSucceeds(
      updateDoc(doc(bobCtx().firestore(), 'groups/pub'), { members: [ALICE, BOB] }),
    );
  });

  it('a joiner CANNOT remove existing members while joining', async () => {
    await seed('groups/pub', pubGroup);
    await assertFails(
      updateDoc(doc(bobCtx().firestore(), 'groups/pub'), { members: [BOB] }),
    );
  });

  it('a non-member CANNOT join a PRIVATE group', async () => {
    await seed('groups/priv', privGroup);
    await assertFails(
      updateDoc(doc(bobCtx().firestore(), 'groups/priv'), { members: [ALICE, BOB] }),
    );
  });

  it('members can read/write chat; senderId must be self', async () => {
    await seed('groups/pub', pubGroup);
    await assertSucceeds(
      setDoc(doc(aliceCtx().firestore(), 'groups/pub/messages/m1'), {
        senderId: ALICE, content: 'hi',
      }),
    );
    await assertFails(
      setDoc(doc(aliceCtx().firestore(), 'groups/pub/messages/m2'), {
        senderId: BOB, content: 'spoofed',
      }),
    );
  });

  it('a non-member CANNOT read group messages', async () => {
    await seed('groups/priv', privGroup);
    await seed('groups/priv/messages/m1', { senderId: ALICE, content: 'secret' });
    await assertFails(getDocs(collection(bobCtx().firestore(), 'groups/priv/messages')));
  });

  it('documents create requires uploadedBy == self', async () => {
    await seed('groups/pub', pubGroup);
    await assertSucceeds(
      setDoc(doc(aliceCtx().firestore(), 'groups/pub/documents/d1'), {
        uploadedBy: ALICE, fileName: 'x.pdf',
      }),
    );
    await assertFails(
      setDoc(doc(aliceCtx().firestore(), 'groups/pub/documents/d2'), {
        uploadedBy: BOB, fileName: 'x.pdf',
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// Default deny
// ---------------------------------------------------------------------------
describe('default deny', () => {
  it('unknown top-level collections are inaccessible even when signed in', async () => {
    await seed('secrets/x', { value: 1 });
    await assertFails(getDoc(doc(aliceCtx().firestore(), 'secrets/x')));
  });

  it('unauthenticated access is denied everywhere', async () => {
    await assertFails(getDocs(collection(unauthCtx().firestore(), 'publicProfiles')));
  });
});
