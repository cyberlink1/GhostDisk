
@@UUID@@
@@VAR_MAX_FAIL@@
@@SHA512@@
@@BOOT_PROMPT@@ 
@@BOOT_METHOD@@ 
@@FAIL_ACTION@@
@@BOOT_AUTH@@ 
@@SIGNATURE@@


if $WIPE_ON_FAIL = true then @@FAIL_ACTION@@ = wipe_on_fail
if $WIPE_ON_FAIL = false then @@FAIL_ACTION@@ = reboot_on_fail
if $UNLOCK_BOOT = false then  @@BOOT_AUTH@@ = boot_noauth and use @@BOOT_PROMPT@@ = boot_noauth and @@BOOT_METHOD@@ = crypto_noauth
if $UNLOCK_BOOT = true then @@BOOT_AUTH@@ = boot_auth and the following
	if $KEY_STORE = keystore and crypto == openssl then  @@BOOT_PROMPT@@ = boot_keystore and @@BOOT_METHOD@@ = crypt_openssl
	if $KEY_STORE = keystore and crypto == pgp then @@BOOT_PROMPT@@ = boot_keystore and @@BOOT_METHOD@@ = crypt_pgp
	if $KEY_STORE = JCOP4 then @@BOOT_PROMPT@@ = boot_jcop4 and @@BOOT_METHOD@@ = crypto_jcop4
	if $KEY_STORE = AT24C64 then @@BOOT_PROMPT@@ = boot_at24c64 @@BOOT_METHOD@@ = crypto_AT24C64
	if $KEY_STORE = SLE4428 then @@BOOT_PROMPT@@ = boot_sle4428 @@BOOT_METHOD@@ = crypto_sle4428
	if $KEY_STORE = SLE4442 then @@BOOT_PROMPT@@ = boot_sle4442 @@BOOT_METHOD@@ = crypto_sle4442
if $CRYPTO = openssl then @@SIGNATURE@@ = openssl_signature
if $CRYPTO = pgp then @@SIGNATURE@@ = pgp_signature


