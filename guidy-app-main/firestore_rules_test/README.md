# Firestore rules checks

Runs `../firestore.rules` in the local Firestore emulator (needs Java) and
checks who may read and write what. Run it after changing the rules:

    cd firestore_rules_test
    npm install
    npm test

It prints one line per check and "all rules checks passed" at the end.
