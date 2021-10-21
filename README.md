# How to find stale or default passwords


There comes a time when user access to CRDB needs to be tested for vulnerabilities.  Once such vulnerability is an old or default password.  If default passwords still exist for a period of time, they should be changed or removed.  

Using an admin user, you can see a list of user accounts by running:
```sql
SELECT username, password FROM system.users;
(paste output here)
```

This shows you users/roles (`users` is a synonym for `role` in CRDB, [see caveats here](https://www.cockroachlabs.com/docs/stable/create-role.html)), and a hashed password.

If the `password` field is populated, that indicates the user can use password authenticated.  You can optionally choose to [use certificate based authentication for users](https://www.cockroachlabs.com/docs/stable/authentication.html#client-authentication) and remove the password all together.  To remove password authentication for a user, you can run the following from an `admin` account:
```sql
ALTER USER username WITH PASSWORD NULL;
```

Once run - the user can no longer access CRDB with a password - so make sure you have your cluster properly configured first!  

## Finding old passwords
But let's say you instead want to check to see the last time a user has updated their password.  You can leverage a hidden column in CRDB called `crdb_internal_mvcc_timestamp` to determine when a row was last updated.  You can read more about that column [here](https://www.cockroachlabs.com/docs/releases/v20.2.0-alpha.3.html) and [here](https://github.com/cockroachdb/cockroach/pull/51494).  You can think of it as an under-the-hood proxy for a `last_updated_at` timestamp.  

You can convert the nanoseconds to a timestamp using `crdb_internal_mvcc_timestamp/1000000000)::int::timestamp`.

To see when passwords were last updated, you can run:
```sql
SELECT username, password, "isRole", ((crdb_internal_mvcc_timestamp/1000000000)::int::timestamp)-now() as "last_updated";
```

The `last_updated` column indicates when that row was last updated.  NOTE: there is no distinction between when the row was created or updated - so some discretion is needed to make that determination.  

### Using `VALID UNTIL`
If you are using password based authentication, you could optionally enforce password TTL.  The `VALID UNTIL` parameter sets the time until which the password is valid.  Once that lapses, the user can no longer access the database.  Read more about [VALID UNTIL here](https://www.cockroachlabs.com/docs/stable/create-user.html#parameters).

## Finding default passwords
Have you used default passwords for users in the past?  Do you know if they were ever changed?  

When run with a priviledged user, this script will go through and identify any users which match a configurable default password.  It can also generate the `ALTER` statement to remove password authentication altogether.  

You can find the script in this repo - [check_user_passwords.sh](./check_user_passwords.sh). 

example:
```bash
[michaelczabator@myhost test]$ bash check_user_passwords.sh
changing passwords
crdb-test-cluster
	 "admin" passes
	 "john" passes
	 "tim" passes
	 "michael.czabator" passes
	 "mike" passes
	 "miketest" matches default password
	 "miketest-app" matches default password
	 "miketest-dba" matches default password
	 "miketest1" matches default password
	 "miketest_app" matches default password
	 "miketest_dba" matches default password
	 skipping "root"
```

Once complete, the script will  create two files.  

`*_default_password_ALTER.sql` contains the `MESSAGE` contains messages that you can send to the users (via slack / email / etc) informing them of the changes. 
```bash
[michaelczabator@myhost test]$ cat test-crdb_default_password_MESSAGE.txt
-- crdb-test
-- ==================

##### START MESSAGE FOR miketest #####
Hello,
Your username `miketest` on CockroachDB cluster `test-prod-prod` was identified as still having a default password.

Your password will be changed for complaince purposes. New details can be found below.

username: `miketest`
password: `t1ygbvWfhOUk8qVrDvMwewuxN9OicQ`

Please ping us in #slack-channel with any issues.
##### END MESSAGE FOR miketest #####
...
...
```



`*_default_password_ALTER.sql` contains the `ALTER` commands for the password action.  
THIS NEEDS TO BE MANUALLY REVIEWED BEFORE EXECUTING TO AVOID BREAKING CHANGES
```
[michaelczabator@myhost test]$ cat test-crdb_default_password_ALTER.sql
-- test-prod-prod
-- ==================

ALTER USER "miketest" WITH PASSWORD "t1ygbvWfhOUk8qVrDvMwewuxN9OicQ";
ALTER USER "miketest-app" WITH PASSWORD "FJWUYMrFlb5wotrliaBSikuTml6qP1";
ALTER USER "miketest-dba" WITH PASSWORD "luuNz4p6cZkXJQS12VokttFxnwKOmK";
...
...
```

