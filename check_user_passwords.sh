#!/bin/bash

admin_username="root"
admin_password="" #optional
hostname="my.cockroachcluster.com"
post="26257"

#This is your CockroachDB connection parms. Optional Adjust as necessary
cockroach_connection_params=$(cat <<EOF
 --certs-dir=/path/to/certs/
EOF
)
echo $cockroach_connection_string
get_user_query='select username, "isRole", now(),crdb_internal.cluster_name() from system.users;'
password_match='default-password'
new_password_length=30
tls_user_message=$(cat <<'EOF'
Hello, \\nYour username \`$username\` on CockroachDB cluster \`$cluster_name\` was identified as still having a default password.\\n\\nYour password will be removed since CockroachDB now authenticates from the CLI with TLS - you can learn how to connect via the CLI with TLS here: https://www.cockroachlabs.com/docs/stable/authentication.html#client-authentication\\n\\nPlease ping us in \#slack-channel if you have any questions!
EOF
)
new_password_user_message=$(cat <<'EOF'
Hello, \\nYour username \`$username\` on CockroachDB cluster \`$cluster_name\` was identified as still having a default password.\\n\\nYour password will be changed for complaince purposes.  New details can be found below.\\n\\nusername: \`$username\`\\npassword: \`$new_password\`\\n\\nPlease ping us in \#slack-channel with any issues.
EOF
)
alter_role_command=$(cat <<'EOF'
ALTER USER \"$username\" WITH PASSWORD NULL\;
EOF
)
alter_role_command_new_password=$(cat <<'EOF'
ALTER USER \"$username\" WITH PASSWORD \"$new_password\"\;
EOF
)


crdb_internal_cluster_name=$(crdb sql --url "postgresql://$admin_username:$admin_password@$hostname:$port" $cockroach_connection_params -e "SELECT crdb_internal.cluster_name()" | tail -1)

echo -ne "-- $crdb_internal_cluster_name\n-- ==================\n\n" > $crdb_internal_cluster_name\_default_password_MESSAGE.txt
echo -ne "-- $crdb_internal_cluster_name\n-- ==================\n\n" > $crdb_internal_cluster_name\_default_password_ALTER.sql

print_user_message () {
	username=$1
	cluster_name=$2

	echo -e "##### START MESSAGE FOR $username #####" | tee -a $2_default_password_MESSAGE.txt > /dev/null
	eval echo -e ${tls_user_message} | tee -a $2_default_password_MESSAGE.txt > /dev/null
	echo -e "##### END MESSAGE FOR $username #####\n\n\n" | tee -a $2_default_password_MESSAGE.txt > /dev/null
	eval echo -e ${alter_role_command} | tee -a $2_default_password_ALTER.sql > /dev/null
}

print_user_message_new_password () {
        username=$1
        cluster_name=$2

	new_password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $new_password_length ; echo '')

        echo -e "##### START MESSAGE FOR $username #####" | tee -a $2_default_password_MESSAGE.txt > /dev/null
        eval echo -e ${new_password_user_message} | tee -a $2_default_password_MESSAGE.txt > /dev/null
        echo -e "##### END MESSAGE FOR $username #####\n\n\n" | tee -a $2_default_password_MESSAGE.txt > /dev/null
        eval echo -e ${alter_role_command_new_password} | tee -a $2_default_password_ALTER.sql > /dev/null
}

IFS=$'\n'
echo "$crdb_internal_cluster_name"
for line in $(cockroach sql --url "postgresql://$admin_username:$admin_password@$hostname:$port" $cockroach_connection_params --format=csv -e "$get_user_query" | grep -v ^username )
do
	IFS="," read username is_role retrieved_ts cluster_name <<< "$line"
	if [[ "$username" =~ (root)$ ]]
        then
		echo -e "\t$(tput setaf 4) skipping \"$username\" $(tput sgr 0)"
		continue
        fi

	cockroach sql --url "postgresql://$username:$password_match@$hostname:$port" $cockroach_connection_params -e "select 1" >  /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		echo -e "\t$(tput setaf 1) \"$username\" matches default password $(tput sgr 0)"
		if [[ ! $username =~ .*"_app"  ]] #ignore app user!
		then
			# optionally remove password, or reset password.  Pick one.
			# print_user_message_new_password $username $cluster_name
			print_user_message $username $cluster_name
		else
			echo -e "\t$(tput setaf 1)app user $username matches, but skipping.$(tput setaf 1)"
		else
		fi
			echo -e "\t$(tput setaf 2) \"$username\" passes $(tput sgr 0)"
		continue
	fi
done
