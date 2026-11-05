import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, deleteDoc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { readFileSync } from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'demo-guidy',
  firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8085 },
});
const V = '2026-09-26';
const good = () => ({ version: V, lang: 'ar', app_version: '1.0.3+4', accepted_at: serverTimestamp() });
const as = (uid, provider) => env.authenticatedContext(uid, { firebase: { sign_in_provider: provider } }).firestore();
let failed = 0;
async function check(name, p) { try { await p; console.log('ok  ', name); } catch (e) { failed++; console.log('FAIL', name, e.message); } }

const google = as('alice', 'google.com'), guest = as('guest1', 'anonymous'), bob = as('bob', 'password');
const anon = env.unauthenticatedContext().firestore();
const ref = (db, uid) => doc(db, `users/${uid}/legal_consents/${V}`);

await check('owner records their agreement', assertSucceeds(setDoc(ref(google, 'alice'), good())));
await check('a guest records theirs', assertSucceeds(setDoc(ref(guest, 'guest1'), good())));
await check('owner reads it', assertSucceeds(getDoc(ref(google, 'alice'))));
await check('owner cannot change it', assertFails(updateDoc(ref(google, 'alice'), { lang: 'en' })));
await check('owner cannot overwrite it', assertFails(setDoc(ref(google, 'alice'), good())));
await check('someone else cannot read it', assertFails(getDoc(ref(bob, 'alice'))));
await check('someone else cannot write one for them', assertFails(setDoc(ref(bob, 'alice2'), good())));
await check('signed out: nothing', assertFails(setDoc(ref(anon, 'x'), good())));
await check('the client clock is refused', assertFails(setDoc(ref(bob, 'bob'), { ...good(), accepted_at: new Date() })));
await check('a mismatched version is refused', assertFails(setDoc(ref(bob, 'bob'), { ...good(), version: '2020-01-01' })));
await check('extra fields are refused', assertFails(setDoc(ref(bob, 'bob'), { ...good(), note: 'x' })));
await check('an unknown language is refused', assertFails(setDoc(ref(bob, 'bob'), { ...good(), lang: 'fr' })));
await check('owner deletes it (account deletion)', assertSucceeds(deleteDoc(ref(google, 'alice'))));
// The existing rules still hold: guests can't use the other collections.
await check('guests still cannot sync saved trips', assertFails(setDoc(doc(guest, 'users/guest1/saved_trips/t1'), { a: 1 })));
await check('owners still can', assertSucceeds(setDoc(doc(google, 'users/alice/saved_trips/t1'), { a: 1 })));

await env.cleanup();
console.log(failed ? `${failed} FAILED` : 'all rules checks passed');
process.exit(failed ? 1 : 0);
