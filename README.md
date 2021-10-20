# crdb_check_user_passwords
script to check for default user passwords

There comes a time when user access to CRDB needs to be tested for vulnerabilities.  Once such vulnerability is default passwords.  If default passwords still exist for a period of time, they should be changed or removed.  

Using an admin user, you can see a list of user accounts by running:
```
SELECT * FROM system.users;
(paste output here)
```

This shows you users/roles (`users` is a synonym for `role` in CRDB, [see caveats here](https://www.cockroachlabs.com/docs/stable/create-role.html)), a hashed password, and `IsRole`, which indicates if the user is a role. 

If the `password` field is popualated, that indicates the user is password authenticated.  You can optionally choose to [use TLS authentication for users](https://www.cockroachlabs.com/docs/stable/authentication.html#client-authentication) and remove the password all together.  To remove password authentication for a user, you can run the following from an `admin` account:
```
ALTER USER username WITH PASSWORD NULL;
```

Once run - the user can no longer access CRDB with a password - so make sure you have your cluster properly configured first!  

But let's say you instead want to check to see the last time a user has updated their password.  You can leverage a hidden column in CRDB called `crdb_internal_mvcc_timestamp` to determine when a row was last updated.  You can read more about that column [here](https://www.cockroachlabs.com/docs/releases/v20.2.0-alpha.3.html) and [here](https://github.com/cockroachdb/cockroach/pull/51494).  You can think of it as an under-the-hood proxy for an `last_updated_at` timestamp.  You can convert the nanoseconds to a timestamp using `crdb_internal_mvcc_timestamp/1000000000)::int::timestamp`.

To see when passwords were last updated, you can run:
```
SELECT username, password, "isRole", ((crdb_internal_mvcc_timestamp/1000000000)::int::timestamp)-now() as "last_updated" 
```
