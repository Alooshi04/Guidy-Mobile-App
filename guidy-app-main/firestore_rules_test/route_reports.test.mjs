import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, serverTimestamp } from 'firebase/firestore';
import { readFileSync } from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'demo-guidy',
  firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8085 },
});
const report = (uid, extra = {}) => ({
  schema: 1, status: 'new', created_at: serverTimestamp(), uid,
  reason: 'wrong_stop', comment: '', scope: 'route', ...extra,
});
const as = (uid, token) => env.authenticatedContext(uid, token).firestore();
let failed = 0, n = 0;
async function check(name, p) { try { await p; console.log('ok  ', name); } catch (e) { failed++; console.log('FAIL', name, e.message); } }
const file = (db, data) => setDoc(doc(db, `route_reports/r${++n}`), data);

const alice = as('alice', { email: 'alice@my-company.com', firebase: { sign_in_provider: 'google.com' } });
const guest = as('guest1', { firebase: { sign_in_provider: 'anonymous' } });

await check('a rider files with their own email', assertSucceeds(file(alice, report('alice', { user_email: 'alice@my-company.com' }))));
await check('a rider files with no email field', assertSucceeds(file(alice, report('alice'))));
await check('a guest files with a null email', assertSucceeds(file(guest, report('guest1', { user_email: null }))));
await check("a rider cannot file under someone else's email", assertFails(file(alice, report('alice', { user_email: 'bob@example.com' }))));
await check('a guest cannot invent an email', assertFails(file(guest, report('guest1', { user_email: 'bob@example.com' }))));
await check("a rider still cannot file as someone else's uid", assertFails(file(alice, report('bob'))));

// "Know a better route?": written (no legs) or built leg by leg.
const better = (extra = {}) => report('alice', {
  reason: 'better_route_known', scope: 'better_route', comment: 'minibus 66 then the metro',
  trip: { start_name: 'Nasr City', end_name: 'Attaba', start_lat: 30.05, start_lon: 31.33, end_lat: 30.05, end_lon: 31.25 },
  shown_options: [{ type: 'Recommended', time_min: 78, fare_egp: 17.5, legs: [{ mode: 'walk', distance_m: 376 }] }],
  ...extra,
});
const leg = { kind: 'ride', source: 'network', vehicle_type: 'minibus', route_id: 'MB_66', route_number: '66', fare_egp: 7.5 };
await check('a written better route', assertSucceeds(file(alice, better())));
await check('a built better route with its legs', assertSucceeds(file(alice, better({ legs: [{ kind: 'walk', distance_m: 300 }, leg] }))));
await check('a better route with too many legs', assertFails(file(alice, better({ legs: Array(21).fill(leg) }))));
await check('legs must be a list', assertFails(file(alice, better({ legs: 'walk then minibus' }))));
await check('a better route with too many shown routes', assertFails(file(alice, better({ shown_options: Array(11).fill({ type: 'Walk' }) }))));
await check('still no fields beyond the known ones', assertFails(file(alice, better({ photo: 'x' }))));

await env.cleanup();
console.log(failed ? `${failed} FAILED` : 'all rules checks passed');
process.exit(failed ? 1 : 0);
