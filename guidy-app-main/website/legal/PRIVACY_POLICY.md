<!--
  Drafted from what the app's code actually does (auth providers, ads,
  analytics, crash reporting, push notifications, location use, backend
  API calls) -- not a generic template. Still: this is a starting point,
  not legal advice, and you should have someone review it before you rely
  on it for App Store / Play Store submission, especially the sections on
  Egypt's Personal Data Protection Law (No. 151 of 2020) and, if you ever
  get users outside Egypt, GDPR/CCPA obligations neither store requires
  today but may later.

  Contact email and effective date are filled in. Still open: a
  company/developer legal name, if one is ever registered.

  THIS FILE IS THE SOURCE, NOT THE PUBLISHED PAGE. build_legal.py renders
  it (and DATA_DELETION.md) into public/, which Firebase Hosting serves
  at https://guidy-19e46.web.app/privacy. Edit the markdown, re-run the
  script, redeploy -- never hand-edit the HTML, the next build discards
  it. Both stores and AdMob all just need that URL to be stable and
  publicly reachable.
-->

# Privacy Policy for Guidy

**Effective date:** 22 October 2026

**Last updated:** 22 October 2026 ("Share my trips": trip logs and walking paths under one setting, on by default; reports that a walk is wrong)

Guidy ("we", "our", "the app") is a public transportation routing app for
Greater Cairo and Alexandria, and for the intercity microbuses between
them, covering the metro, monorail, light rail, buses, minibuses and
microbuses. This policy explains what data the app collects, why, and
who it's shared with.

## Data we collect

**Location.** Guidy uses your device's location, with your permission, to
find nearby stops and to calculate routes from where you are. We ask only
for foreground location: the app has no background-location permission on
either platform, so it cannot see where you are once you have left it.

**Live position while you are riding.** This one deserves more than a
line, because it is the least obvious thing the app does. Guidy has no
vehicle-tracking hardware and no feed from any operator: the only source
of real-time information about where a bus actually is, is the phones of
the people on it. So while you are actively riding a leg of a trip you
have started in the app, and only then, your phone sends its position to
our server about every eight seconds. Those reports are what let the app
tell the next rider which of several routes along the same corridor is
the one actually approaching.

What is sent is a coordinate, the route and direction you are on, and a
session identifier your phone generates for that one ride (plus the
install identifier every request carries). Your account
identifier is not attached and is never sent, and the install identifier
described below is not stored with the positions: the server has no way to
connect a stream of positions to a person, only to a ride in progress.
The positions are held in memory on the server, never written to disk,
and are discarded 90 seconds after they stop arriving; ending or
completing the leg clears the session immediately. Reporting stops the
moment you stop riding, and does not happen while you are walking, while
the app is in the background, or when you are not on a trip at all.

**Sharing your trip live with people you choose.** On the trip screen you
can tap Share to send someone a link that lets them follow your trip.
Nothing is shared unless you tap it. When you do, the app sends our
server a summary of the trip (where you are going from and to, the
destination's location, the planned route and its steps, the planned
duration, and your first name if your account has one), and then, about
every twelve seconds while the trip screen is open, your current
location, the direction you are heading, the step you are on and your
estimated arrival time. Anyone who has the link can see all of this in
the Guidy app until the share ends, so only send it to people you want
to see where you are.

The server keeps only your latest location, not a history of where you
have been, and the share is not linked to your account. It ends when you
tap Stop, when you leave the trip, or when you arrive (people following
it can still see that you arrived for 30 minutes), and in any case 8
hours after it started. After it ends, the link stops working, and the
share is deleted the next time our server clears out ended shares.

**Install identifier.** Every request the app makes to our server carries
a random identifier, created the first time you open the app and not
linked to your account or device. It is used only in the server's memory,
to share request limits fairly between riders who reach us from the same
internet address, and is never stored with your positions, trip logs or
anything else. Clearing the app's data creates a new one; reinstalling
usually does too, unless your phone restores the app's data from a
backup, which carries the old one over.

**"Share my trips": trip logs and walking paths, for fixing our maps.**
One setting, "Share my trips" in Settings, covers what the app records of
a trip you follow: the trip log and your walking paths, both described
below. It is on by default, and you can turn it off at any time (see Your
choices). With it off, the app records neither, and deletes any that were
still waiting to be sent.

*Trip logs.* Bus and microbus routes change, and our
maps can only be as right as the last time someone checked them. So when a
trip you navigated in the app ends -- whether you arrived or left it
early -- the app sends us a log of it: the route it gave you, when you
reached each step, any vehicle or route you switched to, and the path your
phone recorded (a point every few seconds, and only while the trip screen
was open). When enough riders show that a line now takes a different
street between two of its stops, that street becomes the line's route on
the map for everyone. No single rider's trip can change a line.

If you are signed in, the log carries a code derived from your account
identifier with a secret key held only on our server. It lets us count
each rider once; it does not contain your name, email or the account
identifier itself, and it cannot be reversed into them. Guest trips
carry no account code at all and never count towards changing a line.
If you delete your account, your logs are kept but unlinked:
the account code is replaced with a random one that can't be traced
back, and the place names you searched for and the walking parts at
each end of the trip (which start and finish at your door) are removed.

*Your walking paths.* While "Share my trips" is on, the app also records
where you walk, and only during the walking steps of a trip you are
following in the app: never before the trip starts or after it ends,
never during a ride, and never while the app is in the background or in
its floating window. It uses the location the trip screen already has,
so it asks your phone for nothing extra. Before anything leaves your
phone, the first and last 50 metres of each walk are cut off (so nothing
near your home, work or any door is sent), and the path is thinned out to
a few points. What we receive for each walk is those points with their
times, the identifier of the trip and step, how long the app said the walk
was, and the app version, with the same one-way account code as a trip log
if you are signed in. If a walk is shorter than about 100 metres, nothing
is sent. We use these paths only to find footpaths and crossings that are
missing from the map: when several riders walk the same way between the
same two places, a person at Guidy looks at it on aerial imagery and may
add that footpath to our own walking map and to OpenStreetMap. A path
added there is a line on a map; it carries no trip or rider data.

**Reports that a walk is wrong.** When a trip tells you to walk, you can
tap "This walk is wrong" and say why: it goes through buildings, it is too
long, the path does not exist, or something else, with a short note if you
like. This is separate from "Share my trips": nothing is sent unless you
tap it. We store the report with where that walk starts and ends (two
coordinates, which can be your own door if it is the first or last walk of
the trip), how long the app said it was, the reason and your note, the
identifier of the trip and step it was about, and the app version. If you
are signed in it carries the same one-way account code as a trip log, so
that we can count each rider once; guests send it without one. The report
is sent in the background and kept on your phone until it can be, so it
never holds up your trip. We use reports only to find footpaths that are
missing from the map and walks we draw wrongly. Please don't put personal
details in the note.

**Searches you type.** When you search for a place, what you type is sent
to the Google Places API to fetch suggestions, along with a rough
location so the suggestions are nearby ones. This is Google's service and
is covered by [Google's Privacy Policy](https://policies.google.com/privacy).

**Account information.** If you create an account or sign in, we collect
what your chosen sign-in method provides:
- Email/password sign-in: your email address.
- Google Sign-In: your name, email, and profile photo, as permitted by
  your Google account settings.
- Guest mode: no personal information at all, just a temporary,
  anonymous account identifier so you can use the app without creating
  an account. This identifier isn't linked to your name or email.

Authentication is handled by Firebase Authentication (Google).

**Your agreement to our terms.** When you create an account (a guest
account included), and whenever we update our Terms and Conditions,
Privacy Policy or Data Deletion Policy, we ask you to agree to them. We
keep a record of each agreement with your account: which version you
agreed to, when (by our server's clock), the app's language and the app
version you used. It is stored in Firebase (Google), used only to show
that you agreed, and deleted when you delete your account.

**Usage and diagnostic data.** We use Firebase Analytics to understand
how the app is used (e.g. which screens are opened, which features are
used) and Firebase Crashlytics to collect crash reports and error logs
so we can fix bugs. Both are Google services and are subject to
[Google's Privacy Policy](https://policies.google.com/privacy).

**Push notification token.** If you allow notifications, we obtain a
device token (via Firebase Cloud Messaging) used to deliver
notifications to your device. We do not currently send any notification
content beyond what's needed for basic app functionality.

**Commute alerts.** Guidy can tell you when your usual trip between your
saved Home and Work places is easiest, and when the last ride leaves.
These alerts are planned and scheduled on your phone, as local
notifications, from the lines of that trip, which the app keeps on your
phone. To keep their timetables fresh, the app now and then asks our
server for the route between your Home and Work places, which is the same
request it makes when you plan that trip yourself. No alert content is
sent to us. They are on by default once you have saved Home and Work
places and allowed notifications; you can switch them off, or switch off
each kind separately, in Settings, or decline the notification
permission in your device settings.

**Preferences on your device.** Your language, light or dark theme,
Simple Mode, commute-alert and "Share my trips" switches are kept in the app's own storage
on your phone. They are not uploaded to us.

**Advertising data.** Guidy may show ads (banner ads, and an occasional ad
when the app is opened) served by Google AdMob. Ads are not shown in every
version of the app; the rest of this paragraph applies whenever they are.
Google and its partners may
collect and use data from your device to serve and measure ads: the
device's advertising identifier (IDFA on iOS, subject to your App
Tracking Transparency choice; AAID on Android), your IP address, your
approximate location (derived from your IP address) and information about
how you interact with ads and the app. Where you have agreed to it, ads
are personalized using this data; otherwise you'll still see ads, but
they won't be personalized to you. If you are in the European Economic
Area or the United Kingdom, the app asks for your consent to this in a
Google-provided consent form, and you can change your choice later in
the app. See
[How Google uses information from sites or apps that use our services](https://policies.google.com/technologies/partner-sites)
for how Google uses this data.

**Route corrections you send us.** If you report that a route is wrong,
or that you know a better one (trip details → "Something wrong with this
route?"), we store what you write along with the itinerary you were
looking at: the lines and stops in it, their coordinates, the start and
destination you searched for, and your account identifier (including
the anonymous one, if you are using the app as a guest). We use these
reports to correct the underlying transit data for everyone, which is
the only reason we ask for them. They are stored in Firebase Cloud
Firestore (Google) and are readable only by us; no other user of the app
can read, list or download them. Please don't put personal details in
the comment box: it is there to describe the route, not to contact us.

**Route and trip data.** Origin/destination coordinates and computed
routes are sent to our backend to calculate directions and fares. We do
not sell this data or use it for purposes beyond providing the route
you requested.

**Saved trips, saved places and trip history.** These are stored on
your device. If you are signed in with an account (not as a guest), they
are also backed up to your account in Firebase Cloud Firestore (Google),
so they come back when you sign in on another phone or reinstall the
app. No other user of the app can read them: our security rules allow
each account access to its own copies only. Removing an item removes the
backed-up copy, signing out removes them from the device, and deleting
your account deletes them from Firestore.

## Data that never leaves your phone

Your recent searches are stored only in your device's own app storage.
They are not uploaded to us, not synced between your devices, and not
readable by us. Signing out or uninstalling the app removes them.

## This website

The guidyapp.com website sets no cookies and loads no analytics,
advertising or third-party scripts, and its fonts are served from our own
host. If you choose light or dark mode with the switch in the header, that
one choice is saved in your browser's local storage so the site remembers
it; it is never sent to us. If you email us, we receive what you put in
the email.

## Data we don't collect

We don't access your contacts, photos, microphone, or camera. We don't
track your location when the app isn't in use, and we don't have the
permission that would let us.

## Who we share data with

- **Google** (Firebase services, AdMob, Google Sign-In, Google Maps):
  as described above, under Google's own privacy policy.
- **People you send a live trip link to**: your trip and your location
  while the share lasts, as described above. You choose who gets it.
- We do not sell your personal data to third parties.

## Your choices

- You can decline location permission; route search will require
  manually entering a starting point instead of using your current
  location.
- Live position reporting happens only while you are riding a leg of a
  trip you started in the app. Leaving the trip screen, or not starting
  navigation in the first place, stops it. There is no separate setting
  because there is no state to switch off: nothing is reported when you
  are not riding.
- Live trip sharing happens only when you tap Share on the trip screen,
  and you can stop it at any time with Stop.
- "Share my trips" is on by default. You can turn it off at any time in
  Settings (the info button next to it says what it covers); nothing more
  is recorded, and trip logs and walking paths not yet sent are deleted
  from your phone. In Simple Mode, turn Simple Mode off first to reach it.
  Turning it off doesn't stop the app from planning or guiding your trips.
- Reporting a walk is always your choice: nothing is sent unless you tap
  "This walk is wrong".
- You can decline notification permission at any time in your device
  settings.
- On iOS, you can decline App Tracking Transparency; if ads are shown,
  you'll still see them, just not personalized ones.
- On Android, you can opt out of ads personalization, or delete your
  advertising ID, in your device's Settings → Google → Ads. In the
  European Economic Area and the United Kingdom, you can also decline
  or change your consent to personalized ads in the app.
- You can delete your account and associated data at any time from the
  app: Settings → Account → Delete Account. This permanently deletes
  your Firebase account and can't be undone. Route corrections you sent
  us are the one thing this does not remove, see Data retention below.

## Children's privacy

Guidy is not directed at children under 13 (or the minimum age defined
by applicable local law), and we do not knowingly collect personal data
from children. If you believe a child has provided us with personal
data, contact us at the email below and we'll remove it.

## Data retention

We retain account data for as long as your account is active, and
diagnostic/analytics data for the retention periods set by Firebase
Analytics and Crashlytics (see Google's documentation for current
defaults). Deleting your account removes it from Firebase
Authentication immediately.

Live positions are the shortest-lived thing here: memory only, never
written to disk, and dropped 90 seconds after they stop arriving.

A live trip share stops being visible when it ends: 30 minutes after you
arrive or stop sharing, and never later than 8 hours after you started
it. Our server then deletes it the next time it clears out ended shares.

Trip logs, walking paths and walk reports (see above) are deleted from
our server 180 days after they arrive. Deleting your account unlinks the
walking paths and reports you sent in the same way as trip logs (the
account code is replaced with a random one, and the notes on reports are
removed). Deleting your account unlinks them from you but does not delete
them. A street learned
from many riders' logs stays part of the line's map data; it contains no
trip or rider data.

Route corrections are the exception, and we would rather say so plainly
than bury it: they are kept after account deletion, because a report
saying "this bus no longer stops here" is still true and still useful
once the person who sent it has gone, and we have no way to act on it
otherwise. If you want yours removed as well, email us at the address
below and we will delete them.

## Changes to this policy

We may update this policy as the app changes. We'll update the
effective date above when we do.

## Contact

Questions about this policy or your data: info@guidyapp.com
