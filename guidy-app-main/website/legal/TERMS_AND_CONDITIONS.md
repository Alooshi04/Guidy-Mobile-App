<!--
  Drafted from what the app actually does (routing, crowdsourced live
  positions, ads, accounts, route-correction reports) -- not a generic
  template. Still: this is a starting point, not legal advice, and you
  should have someone review it before you rely on it for App Store /
  Play Store submission.

  Governing law / jurisdiction and a company/developer legal name are
  left as an open question below, same as PRIVACY_POLICY.md flags --
  there's no registered entity yet as of this writing. Fill that in
  (and update the matching line in the Arabic file) once there is one;
  until then "Guidy" stands in for an entity that doesn't formally
  exist yet, which is honest but not really a substitute for one.

  THIS FILE IS THE SOURCE, NOT THE PUBLISHED PAGE. build_legal.py renders
  it into public/, which Firebase Hosting serves at
  https://guidy-19e46.web.app/terms. Edit the markdown, re-run the
  script, redeploy -- never hand-edit the HTML, the next build discards
  it.
-->

# Terms and Conditions for Guidy

**Effective date:** 22 October 2026

These terms are an agreement between you and Guidy ("we", "our", "the
app") governing your use of the Guidy mobile application, a public
transportation routing app for Greater Cairo and Alexandria, and for
the intercity microbuses between them, covering the metro, monorail,
light rail, buses, minibuses and microbuses. By downloading, installing
or using Guidy, you agree to these terms. If you don't agree, please
don't use the app.

## What Guidy is

Guidy helps you plan trips across the public transport networks of
Greater Cairo and Alexandria, and between the two cities: it finds routes, stops and fares, and, while you are actively
riding a leg of a trip, shows other riders on the same route roughly
where the vehicle is, based on phones already on board. Guidy is not
affiliated with, endorsed by, or operated on behalf of the Egyptian
National Authority for Tunnels, Cairo Metro, the Cairo Transport
Authority, the Alexandria Passenger Transport Authority, any governorate,
or any bus, microbus or rail operator. We aggregate and
present transit information; we do not operate any vehicle, station or
service shown in the app.

The app is free to use. It may be supported by ads (see "Advertising" below);
there is nothing to buy in the app itself, and we don't sell
subscriptions or in-app items.

## Accuracy of transit information

Please read this section before relying on the app for a trip you can't
afford to get wrong.

Guidy has no live feed from any transit operator. Fares, lines, stops,
schedules and frequencies come from published sources and from riders
like you correcting them over time, and they can be wrong, incomplete,
or out of date when an operator changes something without our
knowledge. Where no official fare is published we show our own
estimate, and a microbus fare depends on how far you ride, so the fare
you actually pay can differ from the one shown. The live position shown for a vehicle you're waiting for
is likewise an estimate built from other passengers' phones, not GPS
hardware on the vehicle: it can be delayed, missing, or absent if no
one else on that vehicle currently has the app open and riding.

Guidy is a planning aid, not a guarantee. Always allow extra time for
anything time-sensitive (a flight, an exam, an appointment) and treat
fares and schedules shown in the app as estimates to confirm with the
operator, a posted sign, or the conductor when it matters. We are not
responsible for missed connections, fares that differ from what's
shown, or any loss arising from relying on information in the app.

## Accounts

You can use Guidy without an account, as a guest: the app creates a
temporary, anonymous identifier so features like route corrections work
without asking who you are. If you choose to create an account
(by email and password or by signing in with Google), you're
responsible for keeping your credentials secure and for what happens
under your account. Tell us at the email below if you believe your
account has been accessed without your permission.

You can delete your account at any time from Settings → Account →
Delete Account. Your account and the personal data tied to it are
deleted; trip logs and walking paths you contributed stay, unlinked from
you (see "Sharing your trips" below and the Privacy Policy).

## Acceptable use

Please don't:

- try to disrupt, overload, or gain unauthorized access to Guidy's
  backend, app, or the data behind it;
- reverse-engineer, scrape, or bulk-extract the app's route, fare or
  live-position data to build a competing product or dataset;
- submit a live-position report while not actually riding, or a route
  correction that you know is false: these features work because
  riders report honestly, and false reports make the app worse for
  everyone else using the same line;
- use the app for any unlawful purpose, or in a way that infringes
  someone else's rights.

We may suspend or terminate access for accounts that violate this
section, at our discretion.

## Content you send us

If you submit a route-correction report (trip details → "Something
wrong with this route?"), you're giving us permission to use, store
and act on it to correct Guidy's transit data for all users. See the
Privacy Policy for what we store alongside it and how long we keep it.
Don't put personal information in the comment box; it's there to
describe the route, not to reach you, and we won't use it to contact
you back.

## Sharing your trips

Guidy's maps are kept accurate by the people who ride with it. The
"Share my trips" setting is on by default. While it is on, when a trip
you navigated in the app ends, the app sends us a log of it: the route it
suggested, the steps you reached, any vehicle or route you switched to,
and the path your phone recorded while the trip screen was open. It also
sends the paths you walked on the trip's walking steps, without the first
and last 50 metres of each. You can turn "Share my trips" off at any time
in Settings; the app then records and sends neither, and the rest of the
app works the same.

You grant us a perpetual, royalty-free right to store the trip logs and
walking paths you send and to use them, combined with other riders', to correct and improve Guidy's
transit data, for example to redraw a line when many riders show it now
takes a different street, or to add a footpath that is missing from
the map. If you delete your account, we delete your
account and the personal data tied to it, and remove from your trip
logs what connects them to you (your account code, the place names you
searched for and the walking parts at each end), but we keep the rest
of the logs and anything learned from them. See the Privacy Policy for
the details.

## Third-party services

Guidy relies on services we don't operate to work: Google Maps and
Places for search and mapping, Firebase (Authentication, Analytics,
Crashlytics, Cloud Firestore, Cloud Messaging) for accounts,
diagnostics and route-correction storage, and Google AdMob for the ads
the app may show to stay free. Your use of those services through the app is
also subject to Google's own terms and privacy policy. We aren't
responsible for outages, changes, or data handling on their end.

## Advertising

Guidy may show banner ads and an occasional ad when the app is opened,
served through Google AdMob. Ads are not shown in every version of the
app; when they are, see the Privacy Policy for what data that
involves and your choices around ad personalization.

## Intellectual property

The Guidy name, logo and app design are ours. Underlying transit
network data (routes, stops, line names) belongs to the relevant
transit authorities or is otherwise public information; we don't claim
ownership of the transit network itself, only of how the app presents
it. Some of that data comes from open sources we credit here:
Transport for Cairo's Alexandria public transport survey (CC BY 4.0,
data.transportforcairo.com), the Alexandria Passenger Transport
Authority's published line list, and map data © OpenStreetMap
contributors (ODbL). You may use the app for your own personal,
non-commercial trip planning. Don't copy, redistribute, or build another app or service
from Guidy's app, design or aggregated data without asking us first.

## Disclaimer of warranties

Guidy is provided "as is" and "as available." We don't promise the app
will be uninterrupted, error-free, or that the transit information in
it is accurate or current (see "Accuracy of transit information"
above). To the extent the law where you live allows it, we disclaim all
other warranties, express or implied.

## Limitation of liability

To the extent permitted by applicable law, Guidy and its developers
aren't liable for indirect, incidental, or consequential damages
arising from your use of the app, including missed trips or
connections, fare discrepancies, or reliance on route or live-position
information. Nothing here limits liability that can't be limited under
the law that applies to you.

## Changes to these terms

We may update these terms as the app changes. We'll update the
effective date above when we do, and continued use of the app after a
change means you accept the updated terms.

## Governing law

Guidy is developed for users in the Arab Republic of Egypt, and these
terms are intended to be governed by Egyptian law.

## Contact

Questions about these terms: info@guidyapp.com
