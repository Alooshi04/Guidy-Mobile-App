/// Whether [email] looks like an address: something@domain.tld, no spaces.
///
/// Only catches typos before a round trip; Firebase Auth does the real
/// check. Deliberately loose. The pattern the sign-in screens used before
/// allowed no hyphen in the domain, so riders at name@my-company.com could
/// neither sign up nor sign in.
bool isValidEmail(String email) => _email.hasMatch(email.trim());

final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
