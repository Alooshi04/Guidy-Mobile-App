import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { doc, setDoc, getDoc, getDocs, deleteDoc, collection, serverTimestamp } from 'firebase/firestore';

const env = await initializeTestEnvironment({ projectId: 'guidy-rules-test',
  firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8085 } });
const alice = env.authenticatedContext('alice', { firebase: { sign_in_provider: 'google.com' } }).firestore();
const bob = env.authenticatedContext('bob', { firebase: { sign_in_provider: 'google.com' } }).firestore();
const guest = env.authenticatedContext('guest', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const anon = env.unauthenticatedContext().firestore();
let n = 0, fail = 0;
async function t(name, p) { n++; try { await p; console.log('ok  ', name); } catch (e) { fail++; console.log('FAIL', name, e.message); } }

await env.withSecurityRulesDisabled(async c => { await setDoc(doc(c.firestore(), 'users/alice'), { legacyField: 1 }); });

for (const coll of ['saved_trips', 'saved_places', 'trip_history']) {
  await t(`owner writes ${coll}`, assertSucceeds(setDoc(doc(alice, `users/alice/${coll}/x`), { a: 1 }, { merge: true })));
  await t(`owner reads ${coll}`, assertSucceeds(getDocs(collection(alice, `users/alice/${coll}`))));
  await t(`owner deletes ${coll}`, assertSucceeds(deleteDoc(doc(alice, `users/alice/${coll}/x`))));
  await t(`other user cannot read ${coll}`, assertFails(getDocs(collection(bob, `users/alice/${coll}`))));
  await t(`other user cannot write ${coll}`, assertFails(setDoc(doc(bob, `users/alice/${coll}/y`), { a: 1 })));
  await t(`guest cannot write own ${coll}`, assertFails(setDoc(doc(guest, `users/guest/${coll}/y`), { a: 1 })));
  await t(`unauth cannot read ${coll}`, assertFails(getDocs(collection(anon, `users/alice/${coll}`))));
}
await t('other subcollection denied', assertFails(setDoc(doc(alice, 'users/alice/secrets/x'), { a: 1 })));
await t('profile merge on legacy doc', assertSucceeds(setDoc(doc(alice, 'users/alice'), { displayName: 'Alice', updatedAt: serverTimestamp() }, { merge: true })));
await t('profile read', assertSucceeds(getDoc(doc(alice, 'users/alice'))));
await t('profile extra field rejected', assertFails(setDoc(doc(alice, 'users/alice'), { isAdmin: true }, { merge: true })));
await t('profile create for new user', assertSucceeds(setDoc(doc(bob, 'users/bob'), { displayName: 'Bob', updatedAt: serverTimestamp() }, { merge: true })));
await t('profile of other user unreadable', assertFails(getDoc(doc(bob, 'users/alice'))));
await t('profile delete by owner', assertSucceeds(deleteDoc(doc(alice, 'users/alice'))));

const base = (uid) => ({ schema: 1, status: 'new', created_at: serverTimestamp(), created_at_client: 'x', uid,
  reason: 'wrong_stop', comment: 'hi', scope: 'route', app_version: '1', platform: 'android', locale: 'en',
  trip: { start_name: 'a' }, steps: [], all_steps: [] });
await t('report create', assertSucceeds(setDoc(doc(alice, 'route_reports/r1'), base('alice'))));
await t('report as other uid rejected', assertFails(setDoc(doc(alice, 'route_reports/r2'), base('bob'))));
await t('report with extra field rejected', assertFails(setDoc(doc(alice, 'route_reports/r3'), { ...base('alice'), blob: 'x' })));
await t('line report fields accepted', assertSucceeds(setDoc(doc(alice, 'route_reports/r4'), {
  schema: 1, status: 'new', created_at: serverTimestamp(), created_at_client: 'x', uid: 'alice', user_email: null,
  scope: 'line', category: 'line_report', reason: 'r', reason_label: 'R', comment: '', app_version: '1', platform: 'android',
  locale: 'ar', line: { route_id: 'x' }, selected_stop: { stop_id: 's' }, stops_preview: [] })));
await t('guest may file a report', assertSucceeds(setDoc(doc(guest, 'route_reports/r5'), base('guest'))));
await t('report unreadable', assertFails(getDoc(doc(alice, 'route_reports/r1'))));
await t('legacy reports closed', assertFails(getDocs(collection(alice, 'reports'))));
console.log(`${n - fail}/${n} passed`);
await env.cleanup();
process.exit(fail ? 1 : 0);
