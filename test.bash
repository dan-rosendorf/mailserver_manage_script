#!/bin/bash

# filepath: h:\mailserver\test.bash

echo "Setting up test environment..."
mariadb -u root -e "CREATE DATABASE IF NOT EXISTS mailserver_test;"
mariadb -u root -e "USE mailserver_test; CREATE TABLE IF NOT EXISTS virtual_domains (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50) NOT NULL);"
mariadb -u root -e "USE mailserver_test; CREATE TABLE IF NOT EXISTS virtual_users (id INT AUTO_INCREMENT PRIMARY KEY, domain_id INT NOT NULL, password VARCHAR(106) NOT NULL, email VARCHAR(120) NOT NULL, UNIQUE KEY (email));"
mariadb -u root -e "USE mailserver_test; CREATE TABLE IF NOT EXISTS virtual_aliases (id INT AUTO_INCREMENT PRIMARY KEY, domain_id INT NOT NULL, source VARCHAR(100) NOT NULL, destination VARCHAR(100) NOT NULL);"
mariadb -u root -e "USE mailserver_test; INSERT INTO virtual_domains (id, name) VALUES (1, 'test.com');"

echo -e "\nRunning tests...\n"

# Function to run test and report result
run_test() {
  echo "TEST: $1"
  echo "COMMAND: $2"
  output=$(eval $2 2>&1)
  echo "OUTPUT: $output"
  if echo "$output" | grep -q -- "$3"; then
    echo "RESULT: PASS"
  else
    echo "RESULT: FAIL - Expected: $3"
  fi
  echo -e "-----------------------------------\n"
}

# Help test
run_test "Help command" "perl mailmanage.pl help" "Usage: perl"

# Add user tests
run_test "Add user" "perl mailmanage.pl add-user -name test1 -password pass123 -database mailserver_test -domain test.com" "added successfully"

# Remove user tests
run_test "Add user for removal" "perl mailmanage.pl add-user -name test2 -password pass123 -database mailserver_test -domain test.com" "added successfully"
run_test "Remove user" "perl mailmanage.pl remove-user -name test2 -database mailserver_test -domain test.com" "removed successfully"

# Change password test
run_test "Add user for password change" "perl mailmanage.pl add-user -name test3 -password pass123 -database mailserver_test -domain test.com" "added successfully"
run_test "Change password" "perl mailmanage.pl change-password -name test3 -password newpass -database mailserver_test -domain test.com" "changed successfully"

# Add alias test
run_test "Add alias" "perl mailmanage.pl add-alias -source alias@test.com -destination test1@test.com -database mailserver_test" "added successfully"

# Error handling tests
run_test "Invalid command" "perl mailmanage.pl invalid-command" "Unknown command"
run_test "Missing username" "perl mailmanage.pl add-user -password pass123 -database mailserver_test" "-name <username> is required"
run_test "Missing password" "perl mailmanage.pl add-user -name test5 -database mailserver_test" "-password <password> is required"
run_test "Invalid database" "perl mailmanage.pl add-user -name test6 -password pass123 -database nonexistent_db" "Couldn't connect to database"

echo "Cleaning up test environment..."
mariadb -u root -e "DROP DATABASE mailserver_test;"

echo "Tests completed."