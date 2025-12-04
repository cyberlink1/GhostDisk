========================================================
                 PASSWORD CHECKER
========================================================

A small command-line C program to verify a password against
a hashed password using the standard Unix `crypt()` function.

Author: [Your Name]
Date: [YYYY-MM-DD]
========================================================

OVERVIEW
--------
This program takes a plaintext password and a hashed password
as input, and checks whether the plaintext password matches
the hash.

It uses the Unix `crypt()` function and supports hashes with
a salt in the standard $id$salt$hash format (such as those
used in /etc/shadow).

The program does not prompt for input; both the password and
hash must be supplied on the command line.

========================================================

USAGE
-----
Compile the program:

     gcc -static -o pwcheck pwcheck.c -lcrypt

Run the program:

    ./pwcheck <password> <hash>

Arguments:
    <password> : The plaintext password to verify
    <hash>     : The hashed password to check against

Exit codes:
    0 : Password matches the hash
    1 : Password does not match, or an error occurred

Example:

    $ ./pwcheck mysecret '$6$abcdef$kjsdf8...'
    $ echo $?
    0   <-- Password correct

========================================================

HOW IT WORKS
------------
1. Extracts the salt from the hash (everything up to the
   3rd '$' character, which includes the algorithm ID and
   salt).

2. Calls `crypt(password, salt)` to compute the hash.

3. Compares the resulting hash with the provided hash.

4. Returns 0 if they match, 1 if they do not.

========================================================

NOTES
-----
- The program requires `_XOPEN_SOURCE` to be defined for
  `crypt()`.

- The salt extraction assumes hashes of the form:

      $id$salt$hashed_value

  where `id` is the hash algorithm number (e.g., 1=MD5, 6=SHA-512).

- Do **not** supply your password on a public shell command
  history if security is a concern.

- This is used in the initramfs-mini to validate a supplied password is correct.

- build-it.sh will compile the program and copy it to the custom-scripts directory

========================================================

